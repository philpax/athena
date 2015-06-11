# Athena
## Introduction
Athena is a [fxdis-d3d11](https://github.com/Philpax/fxdis-d3d1x)-based Shader Model 4 decompiler. It was originally written in C++ as a [fork](https://github.com/Philpax/fxdis-d3d1x/tree/variable-support) of fxdis-d3d11, but the decision was made to port it to D in order to facilitate rapid development through D features such as compile-time metaprogramming and fast compile times.

## Design
fxdis-d3d1x serves as the "front-end" to the decompiler; it is compiled as a static library and linked in. Athena passes input binary files to the fxdis backend, which disassembles the binary files in memory and returns the resulting disassembled program as a structure. In this form, the declarations and instructions are represented as [data](source/sm4/program.d).

After this, Athena is free to manipulate the program data as required. Athena is designed to handle two modes: `disassemble`, which [generates a disassembly listing](source/sm4/dump.d) (similar to that of fxdis), and `decompile`, which produces a HLSL-like textual representation of the code. Currently, `decompile` is unimplemented, but will be ported from the C++ version summarily.

`decompile` functions by constructing an Abstract Syntax Tree from the declarations and instructions. Each instruction is decomposed into its constituent nodes; for example, `rsq r3.z, r3.z` will become `AssignExpr(DotExpr(Variable, StaticIndex), InstructionCall(DotExpr(Variable, StaticIndex)))`. When in this form, a basic decompilation listing can be generated from the AST - however, it will not be much of an improvement over the disassembly.

This AST is then processed through multiple passes which clean it up and provide semantic information. The design and implementation of these are still in flux, but a C++ example can be found [here](https://github.com/Philpax/fxdis-d3d1x/blob/variable-support/src/sm4_rewrite_visitor.cpp).

## Building
Athena currently only works with DMD 64-bit on Windows. This is due to the dependence on fxdis; in future, fxdis may be ported to work on other platforms/compilers.

1. Build fxdis-d3d11 in 64-bit mode as a library in Release mode.
2. Copy the resulting library to the root of the fxdis folder (i.e. fxdis-d3d1x/fxdis.lib).
3. Build Athena using `dub build --arch=x86_64`.

## Running
If running separately:

    athena --mode=decompile|disassemble file

If running through dub:

    dub run --arch=x86_64 -- --mode=decompile|disassemble file