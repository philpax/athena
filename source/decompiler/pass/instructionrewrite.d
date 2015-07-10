module decompiler.pass.instructionrewrite;
public import decompiler.pass.pass;

import decompiler.ast;
import decompiler.recursivevisitor;

import sm4.def;

class InstructionRewrite : Pass
{
	override void run(ASTNode node)
	{
		import std.typecons : scoped;

		auto visitor = new Visitor;
		node.accept(visitor);
	}
}

class Visitor : RecursiveVisitor
{
	alias visit = RecursiveVisitor.visit;

	override void visit(ASTNode node)
	{
	}

	override void beforeVisit(ASTNode node)
	{
	}

	override void afterVisit(ASTNode node)
	{
	}

	void rewriteInstruction(ref ASTNode rhs)
	{
		auto instructionCallExpr = cast(InstructionCallExpr)rhs;

		if (!instructionCallExpr)
			return;

		auto args = instructionCallExpr.arguments;

		// BEFORE: a = mov(b)
		// AFTER:  a = b
		if (instructionCallExpr.opcode == Opcode.MOV)
		{
			rhs = args[0];
			return;
		}

		// BEFORE: a = add(b, c)
		// AFTER:  a = b + c
		if (instructionCallExpr.opcode == Opcode.ADD)
		{
			rhs = new AddExpr(args[0], args[1]);
			return;
		}

		// BEFORE: a = mul(b, c)
		// AFTER:  a = b * c
		if (instructionCallExpr.opcode == Opcode.MUL)
		{
			rhs = new MultiplyExpr(args[0], args[1]);
			return;
		}

		// BEFORE: a = mad(b, c, d)
		// AFTER:  a = b * c + d
		if (instructionCallExpr.opcode == Opcode.MAD)
		{
			rhs = new AddExpr(new MultiplyExpr(args[0], args[1]), args[2]);
			return;
		}
	}

	override void visit(AssignExpr node)
	{
		this.rewriteInstruction(node.rhs);
	}
}