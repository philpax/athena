module decompiler.ir;

import sm4.def : Opcode, FileType, OpcodeNames, SystemValueNames;
import prog = sm4.program;
import decompiler.value;
import decompiler.main : Decompiler;

import std.string;
import std.algorithm;
import std.range;
import std.stdio;
import std.conv;

struct Operand
{
	Variable variable;
	const(ubyte)[] swizzle;

	string toString()
	{
		return "%s.%s".format(variable ? variable.name : "null", this.swizzle.map!(a => "xyzw"[a]).array());
	}
}

struct Instruction
{
	Opcode opcode;
	Operand[] operands;
}

class State
{
	this(Decompiler decompiler)
	{
		this.decompiler = decompiler;
	}

	Operand generateOperand(const(prog.Operand)* operand)
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
				Instruction instruction;
				instruction.opcode = inst.opcode;
				instruction.operands = inst.operands.map!(a => this.generateOperand(a)).array();
				this.instructions ~= instruction;
				break;
			default:
				continue;
			}
		}
	}

	void print()
	{
		foreach (inst; this.instructions)
		{
			writefln("%s %s", OpcodeNames[inst.opcode], inst.operands.map!(to!string).join(", "));
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