module decompiler.textvisitor;

import decompiler.ast;
import decompiler.recursivevisitor;

import std.stdio;
import std.algorithm;
import std.range;

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

	override void visit(Structure node)
	{
		writeSpaces();
		writefln("struct %s", node.name);

		writeSpaces();
		writefln("{");

		depth++;
		this.visit((cast(Structure.BaseType)node));
		depth--;

		writeSpaces();
		writefln("};");
	}

	override void visit(Statement node)
	{
		writeSpaces();
		node.expr.accept(this);
		writeln(";");
	}

	// Expressions
	override void visit(VariableDecl node)
	{
		writef("%s %s", node.variable.type.toString(), node.variable.name);
	}

private:
	void writeSpaces()
	{
		(depth * 4).iota.map!(a => ' ').write();
	}

	uint depth = 0;
}