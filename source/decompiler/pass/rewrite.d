module decompiler.pass.rewrite;
public import decompiler.pass.pass;

import decompiler.main;
import decompiler.ast;
import decompiler.recursivevisitor;
import decompiler.value;

import sm4.def;

import std.algorithm;

class Rewrite : Pass
{
	override void run(Decompiler decompiler, ASTNode node)
	{
		auto visitor = new Visitor(decompiler);
		node.accept(visitor);
	}
}

private:

class Visitor : RecursiveVisitor
{
	alias visit = RecursiveVisitor.visit;

	this(Decompiler decompiler)
	{
		this.decompiler = decompiler;
	}

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

	void rewriteBinaryExpression(ref ASTNode rhs)
	{
		if (auto addExpr = cast(AddExpr)rhs)
		{
			// BEFORE: a = -b + c
			// AFTER:  a = c - b
			if (auto negateExpr = cast(NegateExpr)addExpr.lhs)
			{
				// Swap!
				rhs = new SubtractExpr(addExpr.rhs, negateExpr.node);
				return;
			}

			// BEFORE: a = b + -c
			// AFTER:  a = b - c
			if (auto negateExpr = cast(NegateExpr)addExpr.rhs)
			{
				rhs = new SubtractExpr(addExpr.lhs, negateExpr.node);
				return;
			}

			// BEFORE: a = b + float4(-1, -1, -1, -0)
			// AFTER:  a = b - float4(1, 1, 1, 0)
			if (auto valueExpr = cast(ValueExpr)addExpr.rhs)
			{
				if (auto floatImmediate = cast(FloatImmediate)valueExpr.value)
				{
					if (floatImmediate.value.all!(a => a <= 0))
					{
						// Prevent negative zero
						foreach (ref a; floatImmediate.value)
							a = (a == 0) ? 0 : -a;

						rhs = new SubtractExpr(addExpr.lhs, addExpr.rhs);
						return;
					}
				}
				return;
			}

			// BEFORE: a = b + b
			// AFTER:  a = b * 2
			if (addExpr.lhs == addExpr.rhs)
			{
				auto immediate = new FloatImmediate(decompiler.types["float1"], 2);
				rhs = new MultiplyExpr(addExpr.lhs, new ValueExpr(immediate));
				return;
			}
		}
	}

	override void visit(AssignExpr node)
	{
		this.rewriteInstruction(node.rhs);
		this.rewriteBinaryExpression(node.rhs);
	}

	Decompiler decompiler;
}