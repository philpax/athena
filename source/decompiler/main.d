module decompiler.main;

import decompiler.ast;

import sm4.program;

class Decompiler
{
	this(const(Program)* program)
	{
		this.program = program;
	}

	ScopeNode run()
	{
		auto scopeNode = new ScopeNode;
		return scopeNode;
	}

private:
	const(Program)* program;
}