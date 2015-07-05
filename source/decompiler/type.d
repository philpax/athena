module decompiler.type;

import decompiler.ast : Structure;

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
		super(this.type.toString() ~ this.size.to!string);
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