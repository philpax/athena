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

// Scopes
class Scope : ASTNode
{
	mixin ASTNodeBoilerplate;

	@("NoRecursiveVisit") Scope parent;
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

	final Variable getVariable(string name)
	{
		auto variablePtr = name in variables;
		if (variablePtr)
			return *variablePtr;

		if (this.parent)
			return this.parent.getVariable(name);
		else
			return null;
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
		return typeof(this).stringof ~ ": " ~ this.name;
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

	override string toString()
	{
		return typeof(this).stringof ~ ": " ~ this.name;
	}
}

// Statements
class Statement : ASTNode
{
	mixin ASTNodeBoilerplate;

	ASTNode expr;

	this(ASTNode expr)
	{
		this.expr = expr;
	}
}

class ReturnStatement : Statement
{
	mixin ASTNodeBoilerplate;

	this(ASTNode expr)
	{
		super(expr);
	}
}

class IfStatement : Scope
{
	mixin ASTNodeBoilerplate;

	ASTNode expr;

	this(Scope parent, ASTNode expr)
	{
		this.parent = parent;
		this.expr = expr;
	}
}

class ElseStatement : Scope
{
	mixin ASTNodeBoilerplate;

	this(Scope parent)
	{
		this.parent = parent;
	}
}

// Expressions
// UnaryExpr
mixin template UnaryExprConstructor()
{
	this()
	{
	}

	this(ASTNode node)
	{
		this.node = node;
	}
}

class UnaryExpr : ASTNode
{
	mixin ASTNodeBoilerplate;

	ASTNode node;

	mixin UnaryExprConstructor;
}

class NegateExpr : UnaryExpr
{
	mixin ASTNodeBoilerplate;
	mixin UnaryExprConstructor;
}

// BinaryExpr
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

class EqualExpr : BinaryExpr
{
	mixin ASTNodeBoilerplate;
	mixin BinaryExprConstructor;
}

class NotEqualExpr : BinaryExpr
{
	mixin ASTNodeBoilerplate;
	mixin BinaryExprConstructor;
}

// Other expressions
class SwizzleExpr : ASTNode
{
	mixin ASTNodeBoilerplate;

	const(ubyte)[] indices;

	this(const(ubyte)[] indices)
	{
		this.indices = indices;
	}

	override string toString()
	{
		import std.algorithm : map;
		import std.array : array;

		return typeof(this).stringof ~ ": " ~ 
			this.indices.map!(a => "xyzw"[a]).array();
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

	override string toString()
	{
		return typeof(this).stringof ~ ": " ~ this.variable.name;
	}
}

class VariableDeclExpr : VariableAccessExpr
{
	mixin ASTNodeBoilerplate;

	this(Variable variable)
	{
		super(variable);
	}

	override string toString()
	{
		return typeof(this).stringof ~ ": " ~ this.variable.name;	
	}
}

class ValueExpr : ASTNode
{
	mixin ASTNodeBoilerplate;

	Value value;

	this(Value value)
	{
		this.value = value;
	}

	override string toString()
	{
		return typeof(this).stringof ~ ": " ~ this.value.toString();
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

	this(Function func, ASTNode[] arguments...)
	{
		this.func = func;
		this.arguments = arguments.dup;
	}

	override string toString()
	{
		return typeof(this).stringof ~ ": " ~ this.func.name;
	}
}

class InstructionCallExpr : CallExpr
{
	mixin ASTNodeBoilerplate;

	Opcode opcode;

	this(Opcode opcode, ASTNode[] arguments...)
	{
		this.opcode = opcode;
		this.arguments = arguments.dup;
	}

	override string toString()
	{
		import sm4.def : OpcodeNames;
		return typeof(this).stringof ~ ": " ~ OpcodeNames[opcode];
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