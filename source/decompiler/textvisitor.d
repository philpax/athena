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

	// Scopes
	override void visit(Scope node)
	{
		foreach (statement; node.statements)
		{
			statement.accept(this);
			writeln();
		}
	}

	override void visit(Structure node)
	{
		writeSpaces();
		writefln("struct %s", node.name);

		writeSpaces();
		writefln("{");

		depth++;
		foreach (statement; node.statements)
			statement.accept(this);
		depth--;

		writeSpaces();
		writefln("};");
	}

	override void visit(Function node)
	{
		// Write signature
		writeSpaces();
		writef("%s %s(", node.returnType, node.name);
		bool first = true;
		foreach (argument; node.arguments)
		{
			if (!first)
				write(", ");

			argument.accept(this);
			first = false;
		}
		writeln(")");

		// Write body
		writeSpaces();
		writefln("{");

		depth++;
		foreach (statement; node.statements)
			statement.accept(this);
		depth--;

		writeSpaces();
		writefln("}");
	}

	// Statements
	override void visit(Statement node)
	{
		writeSpaces();
		node.expr.accept(this);
		writeln(";");
	}

	// Expressions
	override void visit(AssignExpr node)
	{
		node.lhs.accept(this);
		write(" = ");
		node.rhs.accept(this);
	}

	override void visit(DotExpr node)
	{
		node.lhs.accept(this);
		write(".");
		node.rhs.accept(this);
	}

	override void visit(SwizzleExpr node)
	{
		write(node.indices.map!(a => "xyzw"[a]));
	}

	override void visit(VariableAccessExpr node)
	{
		write(node.variable.name);
	}

	override void visit(VariableDeclExpr node)
	{
		writef("%s %s", node.variable.type.toString(), node.variable.name);
	}

	override void visit(CallExpr node)
	{
		bool first = true;

		writef("(");
		foreach (argument; node.arguments)
		{
			if (!first)
				write(", ");

			if (argument)
				argument.accept(this);
			else
				write("UNHANDLED");
			
			first = false;
		}
		writef(")");
	}

	override void visit(InstructionCallExpr node)
	{
		import sm4.def : OpcodeNames;

		write(OpcodeNames[node.opcode]);
		this.visit(cast(node.BaseType)node);
	}

private:
	void writeSpaces()
	{
		(depth * 4).iota.map!(a => ' ').write();
	}

	uint depth = 0;
}