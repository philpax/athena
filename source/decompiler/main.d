module decompiler.main;

import decompiler.ast;
import decompiler.type;
import decompiler.value;

import sm4.program;
import sm4.def;

import std.algorithm;
import std.range;
import std.stdio;
import std.string;
import std.traits;

class Decompiler
{
	this(const(Program)* program)
	{
		this.program = program;
		this.generateTypes();
		this.generateFunctions();
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

		// TODO: Automated checking for this type.
		// It acts as a glue type for AST construction.
		this.types["Any"] = new Type("Any");
	}

	void generateFunctions()
	{
		auto any = this.types["Any"];
		void makeUnaryFunction(string name)
		{
			this.globalFunctions[name] = new Function(any, name);
		}

		makeUnaryFunction("abs");
		makeUnaryFunction("saturate");
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

		mainFn.addVariable(new Variable(this.types["ShaderOutput"], "output"));
		this.addInstructions(mainFn);
		rootNode.statements ~= mainFn;
	}

	void addInstructions(Function fn)
	{
		Scope currentScope = fn;

		foreach (instruction; this.program.instructions)
		{
			switch (instruction.opcode)
			{
			case Opcode.RET:
				auto variableAccessExpr = 
					new VariableAccessExpr(currentScope.getVariable("output"));

				currentScope.statements ~= 
					new Statement(new ReturnExpr(variableAccessExpr));

				break;
			case Opcode.IF:
				auto operand = this.decompileOperand(currentScope, instruction.operands[0]);
				auto zero = new IntImmediate(this.types["int1"], 0);
				auto valueExpr = new ValueExpr(zero);

				if (instruction.instruction.testNz)
					operand = new NotEqualExpr(operand, valueExpr);
				else
					operand = new EqualExpr(operand, valueExpr);

				auto ifScope = new IfStatement(currentScope, operand);

				currentScope.statements ~= ifScope;
				currentScope = ifScope;

				break;
			case Opcode.ELSE:
				currentScope = currentScope.parent;
				auto elseScope = new ElseStatement(currentScope);

				currentScope.statements ~= elseScope;
				currentScope = elseScope;

				break;
			case Opcode.ENDIF:
				currentScope = currentScope.parent;

				break;
			default:
				currentScope.statements ~= new Statement(
					this.decompileInstruction(currentScope, instruction));
			}
		}
	}

	ASTNode decompileInstruction(Scope currentScope, const(Instruction*) instruction)
	{
		auto opcode = instruction.opcode;
		auto instructionCall = new InstructionCallExpr(opcode);
		ASTNode node = instructionCall;

		if (instruction.instruction.sat)
			node = new FunctionCallExpr(this.globalFunctions["saturate"], node);

		if (instruction.operands.length)
		{
			auto operandType = OpcodeTypes[opcode];
			auto returnOperand = instruction.operands[0];
			auto returnExpr = this.decompileOperand(currentScope, returnOperand, operandType);

			if (returnExpr)
				node = new AssignExpr(returnExpr, node);

			foreach (operand; instruction.operands[1..$])
			{
				auto operandNode = this.decompileOperand(currentScope, operand, operandType);
				instructionCall.arguments ~= operandNode;
			}
		}

		return node;
	}

	ASTNode decompileOperand(
		Scope currentScope, const(Operand*) operand, OpcodeType type = OpcodeType.FLOAT)
	{
		ASTNode generateVariableExpr(Variable variable)
		{
			auto variableExpr = new VariableAccessExpr(variable);
			if (operand.comps)
			{	
				auto swizzle = new SwizzleExpr(operand.staticIndex);
				auto dotExpr = new DotExpr(variableExpr, swizzle);
				return dotExpr;
			}
			return variableExpr;
		}

		ASTNode addModifiers(ASTNode node)
		{
			if (operand.abs)
				node = new FunctionCallExpr(this.globalFunctions["abs"], node);

			if (operand.neg)
				node = new NegateExpr(node);

			return node;
		}

		ASTNode newExpr;

		switch (operand.file)
		{
		case FileType.TEMP:
			auto index = operand.indices[0].disp;
			auto variable = currentScope.getVariable("r%s".format(index));

			newExpr = generateVariableExpr(variable);
			break;
		case FileType.INPUT:
			auto inputVariableExpr = new VariableAccessExpr(
				currentScope.getVariable("input"));

			auto memberVariableExpr = generateVariableExpr(
				this.inputStruct.variablesByIndex[operand.indices[0].disp]);

			newExpr = new DotExpr(inputVariableExpr, memberVariableExpr);
			break;
		case FileType.OUTPUT:
			auto outputVariableExpr = new VariableAccessExpr(
				currentScope.getVariable("output"));
			
			auto memberVariableExpr = generateVariableExpr(
				this.outputStruct.variablesByIndex[operand.indices[0].disp]);

			newExpr = new DotExpr(outputVariableExpr, memberVariableExpr);
			break;
		case FileType.IMMEDIATE32:	
			if (type == OpcodeType.INT)
			{
				auto values = operand.values.map!(a => a.i32).array();
				auto vectorType = this.getVectorType("int", values.length);
				newExpr = new ValueExpr(new IntImmediate(vectorType, values));
			}
			else if (type == OpcodeType.UINT)
			{
				auto values = operand.values.map!(a => a.u32).array();
				auto vectorType = this.getVectorType("uint", values.length);
				newExpr = new ValueExpr(new UIntImmediate(vectorType, values));
			}
			else
			{
				auto values = operand.values.map!(a => a.f32).array();
				auto vectorType = this.getVectorType("float", values.length);
				newExpr = new ValueExpr(new FloatImmediate(vectorType, values));				
			}
			break;
		default:
			return null;
		}

		return addModifiers(newExpr);
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
	Function[string] globalFunctions;
	uint registerCount = 0;
}