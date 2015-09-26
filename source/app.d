import std.stdio;
import std.getopt;
import std.exception;
import std.file;

import sm4.program;

import decompiler.main;
import decompiler.dumpvisitor, decompiler.textvisitor;
import decompiler.pass.rewrite;

import disassembler.main;

enum Mode
{
	disassemble,
	decompile
}

void main(string[] args)
{
	bool process = true;
	Mode mode = Mode.decompile;
	bool dumpAST = false;

	args.getopt(
		"process", "Control whether to post-process the AST.", &process,
		"mode", "Control whether to disassemble or decompile.", &mode,
		"dump-ast", "Control whether to dump the AST.", &dumpAST);

	enforce(args.length > 1, "Expected a filename.");

	auto file = cast(ubyte[])args[1].read();
	auto program = Program.parse(file).enforce("Failed to parse SM4 program.");
	scope (exit) program.destroy();

	if (mode == Mode.decompile)
	{
		Pass[] passes;
		if (process)
		{
			passes ~= new Rewrite();
		}

		auto decompilerInstance = new Decompiler(program, passes);
		auto rootNode = decompilerInstance.run();

		if (dumpAST)
			rootNode.accept(new DumpVisitor());
		else
			rootNode.accept(new TextVisitor());
	}
	else
	{
		program.dump();
	}
}