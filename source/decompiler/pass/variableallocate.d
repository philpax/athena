module decompiler.pass.variableallocate;
public import decompiler.pass.pass;

import decompiler.main;
import decompiler.ast;
import decompiler.recursivevisitor;
import decompiler.value;
import decompiler.type;

import std.string;

class VariableAllocate : Pass
{
	override bool run(Decompiler decompiler, ASTNode node)
	{
		auto visitor = new Visitor(decompiler);
		node.accept(visitor);
		return visitor.madeChanges;
	}

	override string getName()
	{
		return typeof(this).stringof;
	}
}

private:

class Visitor : RecursiveVisitor
{
	alias visit = RecursiveVisitor.visit;
	bool madeChanges = false;

	this(Decompiler decompiler)
	{
		this.decompiler = decompiler;
	}

	override void visit(AssignExpr node)
	{
		scope (exit) super.visit(node);

		if (auto dotExpr = cast(DotExpr)node.lhs)
		{
			auto swizzleExpr = cast(SwizzleExpr)dotExpr.rhs;

			if (!swizzleExpr)
				return;

			auto type = decompiler.getType("float", swizzleExpr.indices.length);
			auto variable = new Variable(type, "v%s".format(index++));
			node.lhs = new VariableDeclExpr(variable);
		}
	}

	override void visit(Scope node)
	{
		for (size_t i = 0; i < node.statements.length; ++i)
		{
			auto stmt = node.statements[i];

			if (auto statement = cast(Statement)stmt)
			{
				if (auto assignExpr = cast(AssignExpr)statement.expr)
					this.visit(assignExpr);
			}
			else if (auto scopeNode = cast(Scope)stmt)
			{
				this.visit(scopeNode);
			}
		}
	}

	Decompiler decompiler;
	uint index = 0;
}