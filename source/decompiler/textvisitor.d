module decompiler.textvisitor;

import decompiler.ast;
import decompiler.recursivevisitor;

import std.stdio;

class TextVisitor : RecursiveVisitor
{
	alias visit = RecursiveVisitor.visit;

	override void beforeVisit(ASTNode node) {}
	override void afterVisit(ASTNode node) {}

	override void visit(ASTNode node)
	{
	}

	override void visit(Scope node)
	{
		foreach (statement; node.statements)
			statement.accept(this);
	}

	override void visit(VariableDecl node)
	{
		writef("%s %s", node.variable.type.toString(), node.variable.name);
	}

	override void visit(Statement node)
	{
		node.expr.accept(this);
		writeln(";");
	}
}