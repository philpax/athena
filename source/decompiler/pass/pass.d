module decompiler.pass.pass;

import decompiler.main;
import decompiler.ast;

interface Pass
{
	bool run(Decompiler decompiler, ASTNode node);
	string getName();
}