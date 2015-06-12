import std.stdio;
import std.getopt;
import std.exception;
import std.file;
import std.array;
import std.range;

import sm4.program;

enum Mode
{
	disassemble,
	decompile
}

void main(string[] args)
{
	bool process = true;
	Mode mode = Mode.decompile;

	args.getopt(
		"process", "Control whether to post-process the AST.", &process,
		"mode", "Control whether to disassemble or decompile.", &mode);

	enforce(args.length > 1, "Expected a filename.");

	auto file = cast(ubyte[])args[1].read();
	auto program = Program.parse(file).enforce("Failed to parse SM4 program.");
	scope (exit) program.destroy();

	if (mode == Mode.decompile)
	{
		enforce(false, "Unimplemented");
	}
	else
	{
		import disassembler.main;
		program.dump();
	}
}
