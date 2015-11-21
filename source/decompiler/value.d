module decompiler.value;

import decompiler.type;

class Value
{
	Type type;

	this(Type type)
	{
		this.type = type;
	}
}

class Variable : Value
{
	string name;
	size_t count = 1;

	this(Type type, string name, size_t count = 1)
	{
		super(type);
		this.name = name;
		this.count = count;
	}

	override string toString()
	{
		return this.name;
	}
}

class Immediate(T) : Value
{
	T[] value;

	this(Type type, const(T)[] value...)
	{
		super(type);
		this.value = value.dup;
	}

	override string toString()
	{
		import std.string : format, join;
		import std.conv : to;
		import std.algorithm : map;

		if (this.value.length > 1)
			return "%s(%s)".format(this.type, this.value.map!(to!string).join(", "));
		else
			return this.value[0].to!string;
	}
}

alias FloatImmediate = Immediate!float;
alias IntImmediate = Immediate!int;
alias UIntImmediate = Immediate!uint;