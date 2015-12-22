module decompiler.ir;

import def = sm4.def;
import prog = sm4.program;
import decompiler.value;
import decompiler.main : Decompiler;
import decompiler.type;
import util;

import std.string;
import std.algorithm;
import std.range;
import std.stdio;
import std.conv;
import std.typecons;
import std.traits;
import std.variant;

mixin ExtendEnum!("Opcode", def.Opcode, "JMP", "BRANCH", "SATURATE");
immutable OpcodeNames = def.OpcodeNames ~ ["", "jmp", "branch", "saturate"];

struct Operand
{
	struct ValueOperand
	{
		Value value;
		const(ubyte)[] swizzle;
		Type forcedType;

		@property Type type()
		{
			if (this.forcedType)
				return this.forcedType;
			else
				return this.value.type;
		}
	}
	Algebraic!(ValueOperand, BasicBlock*) value;

	this(Value value, const(ubyte)[] swizzle = null, Type type = null)
	{
		ValueOperand operand;
		operand.value = value;
		operand.swizzle = swizzle.dup;
		operand.forcedType = type;
		this.value = operand;
	}

	this(BasicBlock* block)
	{
		this.value = block;
	}

	@property Nullable!ValueOperand valueOperand()
	{
		if (this.value.hasValue && this.value.convertsTo!ValueOperand)
			return Nullable!ValueOperand(this.value.get!ValueOperand);
		else
			return Nullable!ValueOperand();
	}

	string toString()
	{
		if (!this.value.hasValue)
			return "null";

		string s;
		if (this.value.convertsTo!ValueOperand)
		{
			auto value = this.value.get!ValueOperand;
			s = to!string(value.value);
			if (cast(Variable)value.value)
				s = "%" ~ s;
			if (value.swizzle.length)
				s ~= "." ~ value.swizzle.map!(a => "xyzw"[a]).array();
		}
		else if (this.value.convertsTo!(BasicBlock*))
		{
			s = this.value.get!(BasicBlock*).name;
		}
		return s;
	}
}

struct Instruction
{
	Opcode opcode;
	Nullable!Operand destination;
	Operand[] operands;

	string toString()
	{
		string s = "";

		if (!this.destination.isNull)
			s ~= "%s: %s = ".format(this.destination, this.destination.valueOperand.type);

		s ~= "%s %s".format(OpcodeNames[this.opcode], this.operands.map!(to!string).join(", "));

		return s;
	}
}

struct BasicBlock
{
	string name;
	Instruction[] instructions;

	void print()
	{
		writeln(this.name, ":");
		foreach (ref inst; this.instructions)
			writeln("  ", inst);
	}
}

class State
{
	this(Decompiler decompiler)
	{
		this.decompiler = decompiler;
	}

	Operand generateOperand(const(prog.Operand)* operand, def.OpcodeType opcodeType = def.OpcodeType.FLOAT)
	{
		auto staticIndex = operand.staticIndex;
		switch (operand.file)
		{
		case def.FileType.TEMP:
			auto index = operand.indices[0].disp;
			auto variable = this.registers[index];
			auto type = this.decompiler.getTruncatedType(variable.type, staticIndex.length);
			return Operand(variable, staticIndex, type);
		case def.FileType.INPUT:
			auto index = operand.indices[0].disp;
			auto variable = this.inputs[index];
			auto type = this.decompiler.getTruncatedType(variable.type, staticIndex.length);
			return Operand(variable, staticIndex, type);
		case def.FileType.OUTPUT:
			auto index = operand.indices[0].disp;
			auto variable = this.outputs[index];
			auto type = this.decompiler.getTruncatedType(variable.type, staticIndex.length);
			return Operand(variable, staticIndex, type);
		case def.FileType.IMMEDIATE32:
			if (opcodeType == def.OpcodeType.INT)
			{
				auto values = operand.values.map!(a => a.i32).array();
				auto vectorType = this.decompiler.getType("int", values.length);
				return Operand(new IntImmediate(vectorType, values));
			}
			else if (opcodeType == def.OpcodeType.UINT)
			{
				auto values = operand.values.map!(a => a.u32).array();
				auto vectorType = this.decompiler.getType("uint", values.length);
				return Operand(new UIntImmediate(vectorType, values));
			}
			else
			{
				auto values = operand.values.map!(a => a.f32).array();
				auto vectorType = this.decompiler.getType("float", values.length);
				return Operand(new FloatImmediate(vectorType, values));
			}
		default:
			return Operand.init;
		}
	}

	void generate()
	{
		foreach (const decl; this.decompiler.program.declarations)
		{
			switch (cast(Opcode)decl.opcode)
			{
			case Opcode.DCL_TEMPS:
				foreach (i; 0..decl.num)
				{
					this.registers ~= new Variable(
						this.decompiler.getType("float", 4),
						"r%s".format(i));
				}
				break;
			case Opcode.DCL_INPUT:
			case Opcode.DCL_INPUT_SIV:
			case Opcode.DCL_OUTPUT:
			case Opcode.DCL_OUTPUT_SIV:
				auto op = decl.op;
				auto type = this.decompiler.getType("float", op.staticIndex.length);

				string name;
				if (decl.opcode == Opcode.DCL_INPUT_SIV || decl.opcode == Opcode.DCL_OUTPUT_SIV)
					name = def.SystemValueNames[decl.sv];
				else
					name = "v%s".format(op.indices[0].disp);

				auto variable = new Variable(type, name);

				if (decl.opcode == Opcode.DCL_OUTPUT || decl.opcode == Opcode.DCL_OUTPUT_SIV)
					this.outputs ~= variable;
				else
					this.inputs ~= variable;
				break;
			case Opcode.DCL_CONSTANT_BUFFER:
				auto op = decl.op;
				auto index = op.indices[0].disp;
				auto count = op.indices[1].disp;
				auto variable = new Variable(this.decompiler.getType("float", 4), "cb" ~ index.to!string(), count);

				this.constantBuffers[index] = variable;
				break;
			default:
				continue;
			}
		}

		this.basicBlocks ~= new BasicBlock("entrypoint");
		auto ifCounter = 0;
		auto variableCounter = 0;
		auto boolType = this.decompiler.getType("bool");
		auto zeroImmediate = new IntImmediate(this.decompiler.getType("int"), 0);

		Variable makeTemporaryVariable(Type type)
		{
			++variableCounter;
			return new Variable(type, "temp" ~ variableCounter.to!string());
		}

		foreach (inst; this.decompiler.program.instructions)
		{
			switch (cast(Opcode)inst.opcode)
			{
			default:
				auto operandType = def.OpcodeTypes[inst.opcode];
				Instruction instruction;
				instruction.opcode = cast(Opcode)inst.opcode;
				if (inst.operands.length > 1)
				{
					instruction.destination = this.generateOperand(inst.operands[0], operandType);
					instruction.operands = inst.operands[1..$].map!(a => this.generateOperand(a, operandType)).array();
				}
				this.basicBlocks[$-1].instructions ~= instruction;
				break;
			case Opcode.MAD:
				auto operandType = def.OpcodeTypes[inst.opcode];

				auto destination = this.generateOperand(inst.operands[0], operandType);
				auto tempVariable = makeTemporaryVariable(destination.valueOperand.value.type);

				Instruction mul;
				mul.opcode = Opcode.MUL;
				mul.destination = Operand(tempVariable);
				mul.operands = inst.operands[1..$-1].map!(a => this.generateOperand(a, operandType)).array();
				this.basicBlocks[$-1].instructions ~= mul;

				Instruction add;
				add.opcode = Opcode.ADD;
				add.destination = destination;
				add.operands = [mul.destination, this.generateOperand(inst.operands[$-1], operandType)];
				this.basicBlocks[$-1].instructions ~= add;
				break;
			case Opcode.IF:
				this.basicBlocks ~= new BasicBlock("if" ~ ifCounter.to!string());

				ConditionalBranch branch;
				branch.index = ifCounter;
				branch.notEqual = inst.instruction.testNz;
				branch.condition = this.generateOperand(inst.operands[0]);
				branch.precedingBlock = this.basicBlocks[$-2];
				branch.ifBlock = this.basicBlocks[$-1];
				this.branches ~= branch;

				++ifCounter;
				break;
			case Opcode.ELSE:
				auto branch = this.branches[$-1];
				this.basicBlocks ~= new BasicBlock("else" ~ branch.index.to!string());
				this.branches[$-1].elseBlock = this.basicBlocks[$-1];
				break;
			case Opcode.ENDIF:
				auto branch = this.branches[$-1];
				this.basicBlocks ~= new BasicBlock("then" ~ branch.index.to!string());

				auto tempVariable = makeTemporaryVariable(boolType);
				Instruction cmpInst;
				cmpInst.opcode = branch.notEqual ? Opcode.NE : Opcode.EQ;
				cmpInst.destination = Operand(tempVariable);
				cmpInst.operands = [branch.condition, Operand(zeroImmediate)];
				branch.precedingBlock.instructions ~= cmpInst;

				Instruction branchInst;
				branchInst.opcode = Opcode.BRANCH;
				branchInst.operands = [Operand(tempVariable), 
					Operand(branch.ifBlock), Operand(branch.elseBlock)];
				branch.precedingBlock.instructions ~= branchInst;

				Instruction jmpInst;
				jmpInst.opcode = Opcode.JMP;
				jmpInst.operands = [Operand(this.basicBlocks[$-1])];
				branch.ifBlock.instructions ~= jmpInst;
				branch.elseBlock.instructions ~= jmpInst;

				this.branches = this.branches[0..$-1];
				break;
			}

			auto lastBlock = this.basicBlocks[$-1];
			if (lastBlock.instructions.empty)
				continue;

			auto lastInstruction = lastBlock.instructions[$-1];
			if (inst.instruction.sat && !lastInstruction.destination.isNull)
			{
				auto destination = lastInstruction.destination.get;

				Instruction saturate;
				saturate.opcode = Opcode.SATURATE;
				saturate.destination = destination;
				saturate.operands = [destination];
				this.basicBlocks[$-1].instructions ~= saturate;
			}
		}
	}

	void print()
	{
		foreach (basicBlock; this.basicBlocks)
		{
			basicBlock.print();
			writeln();
		}
	}

private:
	Decompiler decompiler;
	Variable[] registers;
	Variable[] inputs;
	Variable[] outputs;
	Variable[size_t] constantBuffers;
	BasicBlock*[] basicBlocks;
	Instruction[] instructions;

	struct ConditionalBranch
	{
		int index;
		bool notEqual;
		Operand condition;
		BasicBlock* precedingBlock;
		BasicBlock* ifBlock;
		BasicBlock* elseBlock;
	}

	ConditionalBranch[] branches;
}