module decompiler.pass.pass;

import decompiler.ast;

interface Pass
{
	void run(ASTNode node);
}