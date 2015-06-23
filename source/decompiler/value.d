module decompiler.value;

import decompiler.type;

class Value
{
	Type type;
}

class Variable : Value
{
	Type type;
	string name;

	this(Type type, string name)
	{
		this.type = type;
		this.name = name;
	}
}

class Immediate(T) : Value
{
	Type type;
	T[] value;

	this(Type type)
	{
		this.type = type;
	}

	override string toString()
	{
		import std.string : format, join;
		return "%s(%s)".format(this.type, this.value.join(", "));
	}
}