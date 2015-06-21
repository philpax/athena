module decompiler.type;

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