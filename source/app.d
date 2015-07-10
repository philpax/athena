import std.stdio;
import std.getopt;
import std.exception;
import std.file;

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
		import decompiler.main;
		import decompiler.pass.rewrite;

		Pass[] passes;
		if (process)
		{
			passes ~= new Rewrite();
		}

		auto decompilerInstance = new Decompiler(program, passes);
		auto rootNode = decompilerInstance.run();

		if (dumpAST)
		{
			import decompiler.dumpvisitor;
			auto dumpVisitor = new DumpVisitor;
			rootNode.accept(dumpVisitor);
		}
		else
		{
			import decompiler.textvisitor;
			auto textVisitor = new TextVisitor;
			rootNode.accept(textVisitor);
		}
	}
	else
	{
		import disassembler.main;
		program.dump();
	}
}