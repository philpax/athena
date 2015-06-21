module disassembler.main;

import std.stdio;
import std.conv : to;
import std.array;
import std.algorithm : map, canFind, filter;
import std.range : enumerate, iota;
import std.uni : toLower;

import sm4.program;
import sm4.def;

void dump(const(Operand)* operand, OpcodeType type = OpcodeType.FLOAT)
{
	if (operand.neg) write("-");
	if (operand.abs) write("|");
	scope (exit) if (operand.abs) write("|");

	if (operand.file == FileType.IMMEDIATE32)
	{
		write('(');
		operand.values
			.map!(
				(value) {
					if (type == OpcodeType.INT)
						return value.i32.to!string();
					else if (type == OpcodeType.UINT)
						return value.u32.to!string();
					else
						return value.f32.to!string();
				})
			.join(", ")
			.write();
		write(')');
	}
	else if (operand.file == FileType.IMMEDIATE64)
	{
		write('(');
		operand.values
			.map!(
				(value) {
					if (type == OpcodeType.INT)
						return value.i64.to!string();
					else if (type == OpcodeType.UINT)
						return value.u64.to!string();
					else
						return value.f64.to!string();
				})
			.join(", ")
			.write();
		write(')');
	}
	else
	{
		write(ShortFileTypeNames[operand.file]);

		immutable indexableFiles = 
			[FileType.TEMP, FileType.INPUT, FileType.OUTPUT, 
			FileType.CONSTANT_BUFFER, FileType.INDEXABLE_TEMP, 
			FileType.UNORDERED_ACCESS_VIEW, FileType.THREAD_GROUP_SHARED_MEMORY];

		bool naked = indexableFiles.canFind(operand.file);

		if (operand.indices[0].reg)
			naked = false;

		foreach (i, index; operand.indices.enumerate())
		{
			if (!naked || i)
				write('[');

			if (index.reg)
			{
				index.reg.dump(type);
				if (index.disp)
					write('+', index.disp);
			}
			else
			{
				write(index.disp);
			}

			if (!naked || i)
				write(']');
		}

		if (operand.comps)
		{
			write('.');
			operand.staticIndex.map!(a => "xyzw"[a]).write();
		}
	}
}

void dump(const(Declaration)* declaration)
{
	OpcodeNames[declaration.opcode].write();

	switch (declaration.opcode)
	{
	case Opcode.DCL_TEMPS:
		write(' ', declaration.num);
		break;
	default:
		break;
	}
	
	if (declaration.op)
	{
		write(' ');
		declaration.op.dump();
	}

	writeln();
}

void dump(const(Instruction)* instruction)
{
	OpcodeNames[instruction.opcode].write();

	if (instruction.instruction.sat)
		write("_sat");

	immutable conditionalOpcodes = 
		[Opcode.BREAKC, Opcode.CALLC, Opcode.CONTINUEC, 
		Opcode.RETC, Opcode.DISCARD, Opcode.IF];

	if (conditionalOpcodes.canFind(instruction.opcode))
		write(instruction.instruction.testNz ? "_nz" : "_z");

	foreach (index, operand; instruction.operands.enumerate())
	{
		if (index)
			write(',');

		write(' ');
		operand.dump(OpcodeTypes[instruction.opcode]);
	}

	writeln();
}

void dump(Program* program)
{
	foreach (declaration; program.declarations)
		declaration.dump();

	foreach (instruction; program.instructions)
		instruction.dump();
}