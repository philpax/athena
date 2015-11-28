module decompiler.ir;

import sm4.def;
import prog = sm4.program;
import decompiler.value;
import decompiler.main : Decompiler;

import std.string;
import std.algorithm;
import std.range;
import std.stdio;
import std.conv;
import std.typecons;

struct Operand
{
	Value value;
	const(ubyte)[] swizzle;

	string toString()
	{
		string s = to!string(this.value);
		if (cast(Variable)this.value)
			s = "%" ~ s;
		if (swizzle.length)
			s ~= "." ~ this.swizzle.map!(a => "xyzw"[a]).array();
		return s;
	}
}

struct Instruction
{
	Opcode opcode;
	Nullable!Operand destination;
	Operand[] operands;
}

class State
{
	this(Decompiler decompiler)
	{
		this.decompiler = decompiler;
	}

	Operand generateOperand(const(prog.Operand)* operand, OpcodeType type = OpcodeType.FLOAT)
	{
		switch (operand.file)
		{
		case FileType.TEMP:
			auto index = operand.indices[0].disp;
			return Operand(this.registers[index], operand.staticIndex);
		case FileType.INPUT:
			auto index = operand.indices[0].disp;
			return Operand(this.inputs[index], operand.staticIndex);
		case FileType.OUTPUT:
			auto index = operand.indices[0].disp;
			return Operand(this.outputs[index], operand.staticIndex);
		case FileType.IMMEDIATE32:	
			if (type == OpcodeType.INT)
			{
				auto values = operand.values.map!(a => a.i32).array();
				auto vectorType = this.decompiler.getType("int", values.length);
				return Operand(new IntImmediate(vectorType, values));
			}
			else if (type == OpcodeType.UINT)
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
			switch (decl.opcode)
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
					name = SystemValueNames[decl.sv];
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

		foreach (inst; this.decompiler.program.instructions)
		{
			switch (inst.opcode)
			{
			case Opcode.MUL:
			case Opcode.ADD:
			case Opcode.DP3:
			case Opcode.RSQ:
			case Opcode.EXP:
			case Opcode.FRC:
				auto operandType = OpcodeTypes[inst.opcode];
				Instruction instruction;
				instruction.opcode = inst.opcode;
				instruction.destination = this.generateOperand(inst.operands[0], operandType);
				instruction.operands = inst.operands[1..$].map!(a => this.generateOperand(a, operandType)).array();
				this.instructions ~= instruction;
				break;
			default:
				writeln("Unhandled opcode: ", inst.opcode);
				continue;
			}
		}
	}

	void print()
	{
		foreach (inst; this.instructions)
		{
			string s;

			if (!inst.destination.isNull)
				s ~= "%s = ".format(inst.destination);

			s ~= "%s %s".format(OpcodeNames[inst.opcode], inst.operands.map!(to!string).join(", "));

			writeln(s);
		}
	}

private:
	Decompiler decompiler;
	Variable[] registers;
	Variable[] inputs;
	Variable[] outputs;
	Variable[size_t] constantBuffers;
	Instruction[] instructions;
}