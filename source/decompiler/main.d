module decompiler.main;

import decompiler.ast;
import decompiler.type;

import sm4.program;
import sm4.def;

import std.algorithm;
import std.stdio;
import std.string;

class Decompiler
{
	this(const(Program)* program)
	{
		this.program = program;
		this.generateTypes();
	}

	ScopeNode run()
	{
		auto rootNode = new ScopeNode;
		this.addDecls(rootNode);
		return rootNode;
	}

private:
	void generateTypes()
	{
		void generateSetOfTypes(string typeName)
		{
			auto type = new Type(typeName);
			this.types[type.toString()] = type;

			foreach (i; 1..5)
			{
				auto vectorType = new VectorType(type, i);
				this.types[vectorType.toString()] = vectorType;
			}
		}

		generateSetOfTypes("double");
		generateSetOfTypes("float");
		generateSetOfTypes("int");
		generateSetOfTypes("uint");
	}

	void addDecls(ScopeNode rootNode)
	{
		foreach (const decl; this.program.declarations)
		{
			switch (decl.opcode)
			{
			case Opcode.DCL_TEMPS:
				foreach (i; 0..decl.num)
				{
					auto type = this.types["float4"];
					auto name = "r%s".format(i);
					rootNode.addVariable(new Variable(type, name));
				}
				break;
			default:
				break;
			}
		}
	}

	const(Program)* program;
	Type[string] types;
}