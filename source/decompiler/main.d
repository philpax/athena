module decompiler.main;

import decompiler.ast;
import decompiler.type;

import sm4.program;
import sm4.def;

import std.algorithm;
import std.stdio;
import std.string;
import std.traits;

class Decompiler
{
	this(const(Program)* program)
	{
		this.program = program;
		this.generateTypes();
	}

	Scope run()
	{
		auto rootNode = new Scope;
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

	void addDecls(Scope rootNode)
	{
		this.inputStruct = new Structure("ShaderInput");
		this.outputStruct = new Structure("ShaderOutput");

		rootNode.statements ~= this.inputStruct;
		rootNode.statements ~= this.outputStruct;

		foreach (const decl; this.program.declarations)
		{
			switch (decl.opcode)
			{
			case Opcode.DCL_TEMPS:
				foreach (i; 0..decl.num)
				{
					auto type = this.getVectorType("float", 4);
					auto name = "r%s".format(i);
					rootNode.addVariable(new Variable(type, name));
				}
				break;
			case Opcode.DCL_INPUT:
			case Opcode.DCL_INPUT_SIV:
			case Opcode.DCL_OUTPUT:
			case Opcode.DCL_OUTPUT_SIV:
				auto op = decl.op;
				auto type = this.getVectorType("float", op.staticIndex.length);

				string name;
				if (decl.opcode == Opcode.DCL_INPUT_SIV || decl.opcode == Opcode.DCL_OUTPUT_SIV)
					name = SystemValueNames[decl.sv];
				else
					name = "v%s".format(op.indices[0].disp);

				auto variable = new Variable(type, name);

				if (decl.opcode == Opcode.DCL_OUTPUT || decl.opcode == Opcode.DCL_OUTPUT_SIV)
					this.outputStruct.addVariable(variable);
				else
					this.inputStruct.addVariable(variable);
				break;
			default:
				break;
			}
		}
	}

	Type getVectorType(T)(string name, T size)
		if (isIntegral!T)
	{
		import std.conv : to;
		return this.types[name ~ size.to!string()];
	}

	const(Program)* program;
	Structure inputStruct;
	Structure outputStruct;
	Type[string] types;
}