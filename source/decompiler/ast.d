module decompiler.ast;

import std.typetuple;

import sm4.def : Opcode;

import decompiler.type;
import decompiler.value;

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
	string toString();
}

class Scope : ASTNode
{
	mixin ASTNodeBoilerplate;

	ASTNode[] statements;
	Variable[string] variables;
	Variable[] variablesByIndex;

	final void addVariable(Variable variable, bool addIndex = true, bool addDecl = true)
	{
		this.variables[variable.name] = variable;
		if (addIndex)
			this.variablesByIndex ~= variable;
		if (addDecl)
			this.statements ~= new Statement(new VariableDeclExpr(variable));
	}
}

class Structure : Scope
{
	mixin ASTNodeBoilerplate;

	string name;

	this(string name)
	{
		this.name = name;
	}

	override string toString()
	{
		return this.name;
	}
}

class Function : Scope
{
	mixin ASTNodeBoilerplate;

	Type returnType;
	string name;
	ASTNode[] arguments;

	this(Type returnType, string name)
	{
		this.returnType = returnType;
		this.name = name;
	}

	final void addArgument(Variable variable)
	{
		this.arguments ~= new VariableDeclExpr(variable);
		this.addVariable(variable, false, false);
	}
}

class Statement : ASTNode
{
	mixin ASTNodeBoilerplate;

	ASTNode expr;

	this(ASTNode expr)
	{
		this.expr = expr;
	}
}

mixin template BinaryExprConstructor()
{
	this()
	{
	}

	this(ASTNode lhs, ASTNode rhs)
	{
		this.lhs = lhs;
		this.rhs = rhs;
	}
}

class BinaryExpr : ASTNode
{
	mixin ASTNodeBoilerplate;

	ASTNode lhs;
	ASTNode rhs;

	mixin BinaryExprConstructor;
}

class AssignExpr : BinaryExpr
{
	mixin ASTNodeBoilerplate;
	mixin BinaryExprConstructor;
}

class DotExpr : BinaryExpr
{
	mixin ASTNodeBoilerplate;
	mixin BinaryExprConstructor;
}

class SwizzleExpr : ASTNode
{
	mixin ASTNodeBoilerplate;

	const(ubyte)[] indices;

	this(const(ubyte)[] indices)
	{
		this.indices = indices;
	}
}

class VariableAccessExpr : ASTNode
{
	mixin ASTNodeBoilerplate;

	Variable variable;

	this(Variable variable)
	{
		this.variable = variable;
	}
}

class VariableDeclExpr : VariableAccessExpr
{
	mixin ASTNodeBoilerplate;

	this(Variable variable)
	{
		super(variable);
	}
}

class CallExpr : ASTNode
{
	mixin ASTNodeBoilerplate;

	ASTNode[] arguments;
}

class FunctionCallExpr : CallExpr
{
	mixin ASTNodeBoilerplate;

	Function func;
}

class InstructionCallExpr : CallExpr
{
	mixin ASTNodeBoilerplate;

	Opcode opcode;

	this(Opcode opcode)
	{
		this.opcode = opcode;
	}
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