# Athena
## Introduction
Athena is a [fxdis-d3d11](https://github.com/Philpax/fxdis-d3d1x)-based Shader Model 4 decompiler. It was originally written in C++ as a [fork](https://github.com/Philpax/fxdis-d3d1x/tree/variable-support) of fxdis-d3d11, but the decision was made to port it to D in order to facilitate rapid development through D features such as compile-time metaprogramming and fast compile times.

## Design
fxdis-d3d1x serves as the "front-end" to the decompiler; it is compiled as a static library and linked in. Athena passes input binary files to the fxdis backend, which disassembles the binary files in memory and returns the resulting disassembled program as a structure. In this form, the declarations and instructions are represented as [data](source/sm4/program.d).

After this, Athena is free to manipulate the program data as required. Athena is designed to handle two modes: `disassemble`, which [generates a disassembly listing](source/disassembler/main.d) (similar to that of fxdis), and `decompile`, which produces a HLSL-like textual representation of the code. 

`decompile` functions by constructing an [Abstract Syntax Tree](#abstract-syntax-tree) from the declarations and instructions. Each instruction is decomposed into its constituent nodes; for example, `rsq r3.z, r3.z` will become `AssignExpr(DotExpr(VariableAccessExpr, SwizzleExpr), InstructionCall(DotExpr(VariableAccessExpr, SwizzleExpr)))`. When in this form, a basic decompilation listing can be generated from the AST - however, it will not be much of an improvement over the disassembly.

This AST is then processed through multiple passes which clean it up and provide semantic information. The design and implementation of these are still in flux, but a C++ example can be found [here](https://github.com/Philpax/fxdis-d3d1x/blob/variable-support/src/sm4_rewrite_visitor.cpp).

### Abstract Syntax Tree
The AST is made up of several different classes, some of which only exist in intermediate stages.

* `ASTNode`: Root node, which all other nodes derive from.
	* `Scope`: Represents a scope of any kind. Contains an array of statements, an associative array of variables, and an array of variables by index.
		* `Structure`: Represents a structure.
		* `Function`: Represents a function. Contains return type, as well as arguments.
	* `Statement`: Represents a statement of any kind. Stores an arbitrary `ASTNode`.
	* `UnaryExpr`: Represents any expression with one operand.
		* `NegateExpr`: Represents a negation (`-a`)
	* `BinaryExpr`: Represents any expression with two operands.
		* `AssignExpr`: Represents an assignment (`a = b`)
		* `DotExpr`: Represents a variable internal access (`a.b`)
	* `SwizzleExpr`: Represents a swizzling operation. Contains an array of indices.
	* `VariableAccessExpr`: Represents a variable being accessed. Contains a `Variable`.
		* `VariableDeclExpr`: Represents a declaration of a variable.
	* `CallExpr`: Represents a function call of any kind. Contains arguments.
		* `FunctionCallExpr`: Represents a known function call. Contains a `Function`.
		* `InstructionCallExpr`: Represents an instruction. Contains an `Opcode`.

## Building
Athena currently works on 64-bit Windows and Linux. It should be possible to make it build on 32-bit, but using DMD to link with MSCOFF32 objects (as emitted by the Visual Studio compiler) is not a simple process.

1. Pull down fxdis-d3d11 with `git submodule init` and `git submodule update`.
2. Go into the fxdis-d3d11 directory, and use premake5 to create the requisite build files.
3. Build fxdis-d3d11 in 64-bit mode. If on Windows, build as Release mode (due to DMD linking against libcmt.lib).
4. Build Athena using `dub build --arch=x86_64`.

## Running
If running separately:

    athena [--mode=decompile|disassemble] [--dump-ast] file

If running through dub:

    dub run --arch=x86_64 -- [--mode=decompile|disassemble] [--dump-ast] file

By default, Athena defaults to decompilation. `--dump-ast` dumps the final AST, and thus will only work in decompilation mode.