module decompiler.type;

import decompiler.ast : Structure;
import std.typecons;

class Type
{
	string name;

	this(string name)
	{
		this.name = name;
	}

	override string toString()
	{
		return name;
	}
}

class VectorType : Type
{
	Type type;
	uint size;

	this(Type type, uint size)
	{
		this.type = type;
		this.size = size;

		import std.conv : to;
		if (this.size > 1)
			super(this.type.toString() ~ this.size.to!string);
		else
			super(this.type.toString());
	}
}

class StructureType : Type
{
	Structure type;

	this(Structure type)
	{
		this.type = type;
		super(type.name);
	}
}

class Function : Type
{
	Type returnType;
	Tuple!(Type, string)[] arguments;

	this(Type returnType, string name, Tuple!(Type, string)[] arguments...)
	{
		this.returnType = returnType;
		this.arguments = arguments.dup;
		super(name);
	}
}