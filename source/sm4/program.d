module sm4.program;

import std.bitmanip;
import sm4.def;

union TokenInstruction
{
	static struct InstructionBitfield
	{
		mixin(bitfields!(
			Opcode, "opcode", 11,
			uint, "resinfoReturnType", 2,
			bool, "sat", 1,
			uint, "", 4,
			bool, "testNz", 1,
			uint, "preciseMask", 4,
			uint, "", 1,
			uint, "length", 7,
			bool, "extended", 1
		));
	};

	mixin(bitfields!(
		Opcode, "opcode", 11,
		uint, "", 13,
		uint, "length", 7,
		bool, "extended", 1
	));

	InstructionBitfield instruction;
}

static assert(TokenInstruction.sizeof == 4);

struct TokenOperand
{
	mixin(bitfields!(
		uint, "compsEnum", 2,
		uint, "mode", 2,
		uint, "sel", 8,
		uint, "file", 8,
		uint, "numIndices", 2,
		uint, "index0Repr", 3,	
		uint, "index1Repr", 3,	
		uint, "index2Repr", 3,
		bool, "extended", 1
	));
}

static assert(TokenOperand.sizeof == 4);

struct TokenOperandExtended
{
	mixin(bitfields!(
		uint, "type", 6,
		bool, "neg", 1,
		bool, "abs", 1,
		uint, "", 24
	));
}

static assert(TokenOperandExtended.sizeof == 4);

union Any
{
	double f64;
	float f32;

	long i64;
	int i32;

	ulong u64;
	uint u32;
}

struct Operand
{
	TokenOperand token;
	TokenOperandExtended extendedToken;
	bool hasExtendedToken;

	ubyte mode;
	ubyte comps;
	ubyte mask;
	ubyte numIndices;
	ubyte[4] swizzle;
	FileType file;
	Any[4] immValues;
	bool neg;
	bool abs;

	struct Index
	{
		long disp;
		Operand* reg;
	}

	Index[3] rawIndices;

	@property Any[] values()
	{
		return this.immValues[0..this.comps];
	}

	@property Index[] indices()
	{
		return this.rawIndices[0..this.numIndices];
	}
}

static assert(Operand.sizeof == 112);

struct Instruction
{
	TokenInstruction tokenInstruction;
	alias tokenInstruction this;

	byte[3] sampleOffset;
	ubyte resourceTarget;
	ubyte[4] resourceReturnType;

	uint num;
	uint numOps;
	Operand*[6] ops;

	@property Operand*[] operands()
	{
		return this.ops[0..this.numOps];
	}
}

static assert(Instruction.sizeof == 72);

struct Declaration
{
	TokenInstruction tokenInstruction;
	alias tokenInstruction this;

	Operand* op;
	union
	{
		uint num;
		float f32;
		SystemValue sv;

		static struct Intf
		{
			uint id;
			uint expectedFunctionTableLength;
			uint tableLength;
			uint arrayLength;
		}

		Intf intf;
	}

	void* data;
}

static assert(Declaration.sizeof == 40);

struct Program
{
	static Program* parse(ubyte[] data)
	{
		return cast(Program*)sm4_parse_file(data.ptr, cast(uint)data.length);
	}

	void destroy()
	{
		sm4_destroy_program(&this);
	}

	@property Declaration*[] declarations()
	{
		auto view = sm4_program_get_dcls(&this);
		return (cast(Declaration**)view.data)[0..view.size];
	}

	@property Instruction*[] instructions()
	{
		auto view = sm4_program_get_insns(&this);
		return (cast(Instruction**)view.data)[0..view.size];
	}
}

private:
extern (C++):
struct array_view
{
	void* data;
	uint size;
}

void* sm4_parse_file(ubyte* data, uint size);
void sm4_destroy_program(void* program);
array_view sm4_program_get_dcls(void* program);
array_view sm4_program_get_insns(void* program);