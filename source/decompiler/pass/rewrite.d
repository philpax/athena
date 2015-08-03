module decompiler.pass.rewrite;
public import decompiler.pass.pass;

import decompiler.main;
import decompiler.ast;
import decompiler.recursivevisitor;
import decompiler.value;
import decompiler.type;

import sm4.def;

import std.algorithm;
import std.range;

class Rewrite : Pass
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
			this.madeChanges = true;
			return;
		}

		// BEFORE: a = add(b, c)
		// AFTER:  a = b + c
		if (instructionCallExpr.opcode == Opcode.ADD)
		{
			rhs = new AddExpr(args[0], args[1]);
			this.madeChanges = true;
			return;
		}

		// BEFORE: a = mul(b, c)
		// AFTER:  a = b * c
		if (instructionCallExpr.opcode == Opcode.MUL)
		{
			rhs = new MultiplyExpr(args[0], args[1]);
			this.madeChanges = true;
			return;
		}

		// BEFORE: a = div(b, c)
		// AFTER:  a = b / c
		if (instructionCallExpr.opcode == Opcode.DIV)
		{
			rhs = new DivideExpr(args[0], args[1]);
			this.madeChanges = true;
			return;
		}

		// BEFORE: a = mad(b, c, d)
		// AFTER:  a = b * c + d
		if (instructionCallExpr.opcode == Opcode.MAD)
		{
			rhs = new AddExpr(new MultiplyExpr(args[0], args[1]), args[2]);
			this.madeChanges = true;
			return;
		}
	}

	void rewriteBinaryExpression(ref ASTNode rhs)
	{
		auto binaryExpr = cast(BinaryExpr)rhs;
		if (!binaryExpr)
			return;

		if (auto addExpr = cast(AddExpr)rhs)
		{
			// BEFORE: a = -b + c
			// AFTER:  a = c - b
			if (auto negateExpr = cast(NegateExpr)addExpr.lhs)
			{
				// Swap!
				rhs = new SubtractExpr(addExpr.rhs, negateExpr.node);
				this.madeChanges = true;
			}

			// BEFORE: a = b + -c
			// AFTER:  a = b - c
			if (auto negateExpr = cast(NegateExpr)addExpr.rhs)
			{
				rhs = new SubtractExpr(addExpr.lhs, negateExpr.node);
				this.madeChanges = true;
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
						this.madeChanges = true;
					}
				}
			}

			// BEFORE: a = b + b
			// AFTER:  a = b * 2
			if (addExpr.lhs == addExpr.rhs)
			{
				auto immediate = new FloatImmediate(decompiler.types["float1"], 2);
				rhs = new MultiplyExpr(addExpr.lhs, new ValueExpr(immediate));
				this.madeChanges = true;
			}
		}

		// BEFORE: a = b * float4(5, 5, 5, 5)
		// AFTER:  a = b * 5
		void applyCollapseValueTransform(ASTNode node)
		{
			auto valueExpr = cast(ValueExpr)node;

			if (!valueExpr)
				return;

			auto floatImmediate = cast(FloatImmediate)valueExpr.value;

			if (!floatImmediate)
				return;

			auto value = floatImmediate.value;
			if (value.length > 1 && value.uniq.walkLength == 1)
			{
				floatImmediate.value = value[0..1];
				floatImmediate.type = this.decompiler.getVectorType("float", 1);
				this.madeChanges = true;
			}
		}			

		applyCollapseValueTransform(binaryExpr.lhs);
		applyCollapseValueTransform(binaryExpr.rhs);

		// BEFORE: a = b * 0.25
		// AFTER:  a = b / 4
		if (auto multiplyExpr = cast(MultiplyExpr)rhs)
		{
			if (auto valueExpr = cast(ValueExpr)multiplyExpr.rhs)
			{
				auto floatImmediate = cast(FloatImmediate)valueExpr.value;

				if (!floatImmediate)
					return;
				
				auto value = floatImmediate.value;
				if (value.length == 1 && value[0] > 0.0f && value[0] < 1.0f)
				{
					value[0] = 1 / value[0];
					rhs = new DivideExpr(multiplyExpr.lhs, multiplyExpr.rhs);
					this.madeChanges = true;
				}
			}
		}

		this.rewriteBinaryExpression(binaryExpr.lhs);
		this.rewriteBinaryExpression(binaryExpr.rhs);
	}

	void normalizeSwizzleSize(AssignExpr node)
	{
		class UpdateSwizzle : RecursiveVisitor
		{
			ubyte[] swizzle = null;

			alias visit = RecursiveVisitor.visit;
			final T[] remapSwizzle(T)(T[] values)
			{
				return values
						.enumerate
						.filter!(a => this.swizzle.canFind(cast(ubyte)a[0]))
						.map!(a => a[1])
						.array();
			}

			// BEFORE: a.xyz = b.xyzx
			// AFTER:  a.xyz = b.xyz
			override void visit(SwizzleExpr node)
			{
				if (this.swizzle is null)
					this.swizzle = node.indices.dup;
				else if (node.indices.length != this.swizzle.length)
					node.indices = this.remapSwizzle(node.indices);
			}

			// BEFORE: a.xyz = float4(1, 1, 1, 0)
			// AFTER:  a.xyz = float3(1, 1, 1)
			override void visit(ValueExpr node)
			{
				auto floatImmediate = cast(FloatImmediate)node.value;
				if (!floatImmediate)
					return;

				auto vectorType = cast(VectorType)floatImmediate.type;
				auto value = floatImmediate.value;

				if (this.swizzle.length < value.length)
				{
					auto type = this.outer.decompiler.getVectorType(
						vectorType.type.name, this.swizzle.length);

					floatImmediate.type = type;
					floatImmediate.value = 
						this.remapSwizzle(floatImmediate.value);
				}
			}
		}

		auto visitor = new UpdateSwizzle();
		node.lhs.accept(visitor);

		if (visitor.swizzle !is null)
			node.rhs.accept(visitor);
	}

	override void visit(AssignExpr node)
	{
		this.rewriteInstruction(node.rhs);
		this.rewriteBinaryExpression(node.rhs);
		this.normalizeSwizzleSize(node);

		super.visit(node);
	}

	override void visit(SwizzleExpr node)
	{
		// BEFORE: a.xxxx
		// AFTER:  a.x
		if (node.indices.length > 1 && node.indices.uniq.walkLength == 1)
			node.indices = node.indices[0..1];
	}

	Decompiler decompiler;
}