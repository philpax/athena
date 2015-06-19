module decompiler.recursivevisitor;

import decompiler.ast;

class RecursiveVisitor : ASTVisitor
{
	import std.algorithm : each;

	alias visit = ASTVisitor.visit;

	abstract void beforeVisit(ASTNode node);
	abstract void afterVisit(ASTNode node);

	mixin(generateRecursiveMethods());
}

// Generate methods that automatically visit every child node
private string generateRecursiveMethods()
{
	import std.typecons : Identity;
	import std.string : format;
	import std.array : join;
	string ret;

	foreach (NodeType; ASTNodes)
	{
		string[] statements;
		foreach (member; __traits(allMembers, NodeType)) 
		{
			alias Member = Identity!(__traits(getMember, NodeType, member));

			static if (is(typeof(Member) : ASTNode))
				statements ~= `node.%s.accept(this);`.format(Member.stringof);
			static if (is(typeof(Member) : ASTNode[]))
				statements ~= `node.%s.each!(a => a.accept(this));`.format(Member.stringof);
		}

		if (statements.length)
		{
			ret ~= `
override void visit(%s node) 
{ 
this.visit(cast(node.BaseType)node);
beforeVisit(node);
%s 
afterVisit(node);
}
			`.format(NodeType.stringof, statements.join("\n"));
		}
	}

	return ret;
}