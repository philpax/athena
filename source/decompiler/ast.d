module decompiler.ast;

import std.typetuple;

// AST nodes
mixin template ASTNodeBoilerplate()
{
	import std.traits : BaseTypeTuple;
	alias BaseType = BaseTypeTuple!(typeof(this))[$-1];

	override void accept(ASTVisitor visitor)
	{
		visitor.visit(this);
	}

	override string toString()
	{
		return typeof(this).stringof;
	}
}

interface ASTNode
{
	void accept(ASTVisitor visitor);
}

class ScopeNode : ASTNode
{
	mixin ASTNodeBoilerplate;

	ASTNode[] statements;
}

class BinaryExpr : ASTNode
{
	mixin ASTNodeBoilerplate;

	ASTNode lhs;
	ASTNode rhs;
}

// AST visitor
abstract class ASTVisitor
{
	void visit(ASTNode node)
	{
		assert(false);
	}

	mixin(generateVisitorMethods());
}

mixin("alias ASTNodes = " ~ getASTNodeTypeTupleString() ~ ";");

// Get all AST node classes
private string getASTNodeTypeTupleString()
{
	import std.typecons : Identity;
	import std.array : join;
	import std.traits : BaseTypeTuple;

	string[] classes;

	foreach (member; __traits(allMembers, decompiler.ast)) 
	{
		alias MemberType = Identity!(__traits(getMember, decompiler.ast, member));

		static if (is(MemberType : ASTNode) && is(MemberType == class)) 
			classes ~= member;
	}

	return `TypeTuple!(` ~ classes.join(", ") ~ `)`;
}

// Generate a series of methods that visit by converting to the base class
private string generateVisitorMethods()
{
	import std.typecons : Identity;
	import std.string : format;
	import std.typetuple : TypeTuple;

	string ret;

	foreach (NodeType; mixin(getASTNodeTypeTupleString())) 
	{
		immutable templateString = 
		`
		void visit(%s node) 
		{
			this.visit(cast(%s)node);
		}
		`;

		ret ~= templateString.format(NodeType.stringof, NodeType.BaseType.stringof);
	}

	return ret;
}