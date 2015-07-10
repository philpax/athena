module decompiler.textvisitor;

import decompiler.ast;
import decompiler.recursivevisitor;

import std.stdio;
import std.algorithm;
import std.range;

void tryAccept(ASTNode node, RecursiveVisitor visitor)
{
	if (node)
		node.accept(visitor);
	else
		write("UNHANDLED");
}

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
			statement.tryAccept(this);
			writeln();
		}
	}

	final void visitScope(Scope node, bool forceWriteBraces = false)
	{
		auto writeBraces = forceWriteBraces || node.statements.length > 1;

		if (writeBraces)
		{
			writeSpaces();
			writefln("{");			
		}

		depth++;
		foreach (statement; node.statements)
			statement.tryAccept(this);
		depth--;

		if (writeBraces)
		{
			writeSpaces();
			writefln("}");			
		}
	}

	override void visit(Structure node)
	{
		writeSpaces();
		writefln("struct %s", node.name);

		this.visitScope(node, true);
	}

	override void visit(ConstantBuffer node)
	{
		writeSpaces();
		writefln("cbuffer %s : register(b%s)", node.name, node.index);

		this.visitScope(node, true);
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

			argument.tryAccept(this);
			first = false;
		}
		writeln(")");

		this.visitScope(node, true);
	}

	// Statements
	override void visit(Statement node)
	{
		writeSpaces();
		node.expr.tryAccept(this);
		writeln(";");
	}

	override void visit(IfStatement node)
	{
		writeSpaces();
		write("if (");
		node.expr.tryAccept(this);
		writeln(")");

		this.visitScope(node);
	}

	override void visit(ElseStatement node)
	{
		writeSpaces();
		writeln("else");

		this.visitScope(node);
	}

	override void visit(ReturnStatement node)
	{
		writeSpaces();
		write("return");
		if (node.expr)
		{
			write(" ");
			node.expr.tryAccept(this);
		}
		writeln(";");
	}

	// Expressions
	// UnaryExpr
	override void visit(NegateExpr node)
	{
		write("-");
		node.node.tryAccept(this);
	}

	// BinaryExpr
	override void visit(AssignExpr node)
	{
		node.lhs.tryAccept(this);
		write(" = ");
		node.rhs.tryAccept(this);
	}

	override void visit(AddExpr node)
	{
		node.lhs.tryAccept(this);
		write(" + ");
		node.rhs.tryAccept(this);
	}
	
	override void visit(MultiplyExpr node)
	{
		node.lhs.tryAccept(this);
		write(" * ");
		node.rhs.tryAccept(this);
	}
	
	override void visit(SubtractExpr node)
	{
		node.lhs.tryAccept(this);
		write(" - ");
		node.rhs.tryAccept(this);
	}
	
	override void visit(DivideExpr node)
	{
		node.lhs.tryAccept(this);
		write(" / ");
		node.rhs.tryAccept(this);
	}

	override void visit(DotExpr node)
	{
		node.lhs.tryAccept(this);
		write(".");
		node.rhs.tryAccept(this);
	}

	override void visit(EqualExpr node)
	{
		node.lhs.tryAccept(this);
		write(" == ");
		node.rhs.tryAccept(this);
	}

	override void visit(NotEqualExpr node)
	{
		node.lhs.tryAccept(this);
		write(" != ");
		node.rhs.tryAccept(this);
	}

	// Other expressions
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
		if (node.variable.count > 1)
			writef("[%s]", node.variable.count);
	}

	override void visit(DynamicIndexExpr node)
	{
		node.base.tryAccept(this);
		write("[");
		node.index.tryAccept(this);
		write("]");
	}

	override void visit(ValueExpr node)
	{
		write(node.value.toString());
	}

	override void visit(CallExpr node)
	{
		bool first = true;

		writef("(");
		foreach (argument; node.arguments)
		{
			if (!first)
				write(", ");

			argument.tryAccept(this);			
			first = false;
		}
		writef(")");
	}

	override void visit(FunctionCallExpr node)
	{
		write(node.func.name);
		this.visit(cast(node.BaseType)node);
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