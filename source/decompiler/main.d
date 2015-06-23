module decompiler.main;

import decompiler.ast;
import decompiler.type;
import decompiler.value;

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
		this.addMainFunction(rootNode);
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

		this.addStructureType(this.inputStruct);
		this.addStructureType(this.outputStruct);

		foreach (const decl; this.program.declarations)
		{
			switch (decl.opcode)
			{
			case Opcode.DCL_TEMPS:
				this.registerCount = decl.num;
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

	void addMainFunction(Scope rootNode)
	{
		auto mainFn = new Function(this.types["ShaderOutput"], "main");
		mainFn.addArgument(new Variable(this.types["ShaderInput"], "input"));
		
		foreach (i; 0..this.registerCount)
		{
			auto type = this.getVectorType("float", 4);
			auto name = "r%s".format(i);
			mainFn.addVariable(new Variable(type, name));
		}

		foreach (instruction; program.instructions)
		{
			auto instructionCall = new InstructionCallExpr(instruction.opcode);
			ASTNode node = instructionCall;

			if (instruction.operands.length)
			{
				auto returnOperand = instruction.operands[0];
				auto returnExpr = this.decompileOperand(mainFn, returnOperand);
				if (returnExpr)
				{
					auto assignExpr = new AssignExpr(returnExpr, instructionCall);
					node = assignExpr;
				}
			}
			mainFn.statements ~= new Statement(node);
		}

		rootNode.statements ~= mainFn;
	}

	ASTNode decompileOperand(Scope currentScope, const(Operand*) operand)
	{
		switch (operand.file)
		{
		case FileType.TEMP:
			auto variable = currentScope.variablesByIndex[operand.indices[0].disp];
			auto register = new VariableAccessExpr(variable);
			if (operand.comps)
			{	
				auto swizzle = new SwizzleExpr(operand.staticIndex);
				auto dotExpr = new DotExpr(register, swizzle);
				return dotExpr;
			}
			return register;
		default:
			return null;
		}
	}

	void addStructureType(Structure structure)
	{
		this.types[structure.name] = new StructureType(structure);
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
	uint registerCount = 0;
}