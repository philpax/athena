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

	this(Type type, string name)
	{
		super(type);
		this.name = name;
	}
}

class Immediate(T) : Value
{
	T[] value;

	this(Type type)
	{
		super(type);
	}

	override string toString()
	{
		import std.string : format, join;
		return "%s(%s)".format(this.type, this.value.join(", "));
	}
}