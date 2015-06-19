module decompiler.dumpvisitor;

import decompiler.ast;
import decompiler.recursivevisitor;

class DumpVisitor : RecursiveVisitor
{
public:
	alias visit = RecursiveVisitor.visit;

	override void visit(ASTNode node)
	{
		import std.range : iota;
		import std.algorithm : map;
		import std.stdio;

		(depth * 2).iota.map!(a => ' ').write();
		node.writeln();
	}

	override void beforeVisit(ASTNode node)
	{
		this.depth++;
	}

	override void afterVisit(ASTNode node)
	{
		this.depth--;
	}

private:
	uint depth = 0;
}