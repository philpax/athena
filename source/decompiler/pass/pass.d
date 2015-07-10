module decompiler.pass.pass;

import decompiler.main;
import decompiler.ast;

interface Pass
{
	void run(Decompiler decompiler, ASTNode node);
}