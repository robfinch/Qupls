#include "stdafx.h"

extern int defaultcc;

int Declaration::depth = 0;

Declaration::Declaration(Statement* st)
{
	head = (TYP*)nullptr;
	tail = (TYP*)nullptr;
	next = nullptr;
	bit_max = 64;
	bit_offset = 0;
	bit_width = 64;
	bit_next = 0;
	funcdecl = 0;
	decl_level = 0;
	pa_level = 0;
	isTypedef = false;
	inline_threshold = compiler.autoInline;
	stmt = st;
}

Function* Declaration::MakeFunction(int symnum, Symbol* sym, bool isPascal, bool isInline) {
	Function* fn = compiler.ff.MakeFunction(symnum, sym, isPascal);
	fn->IsInline = isInline;
	return (fn);
};

void Declaration::MakeFunction(Symbol* sp, Symbol* sp1)
{
	dfs.printf("<MakeFunction>");
	if (sp->tp->IsFunc())
	sp1->SetType(sp->tp);
	sp1->tp->btpp = sp->tp->btpp;
	sp1->storage_class = sp->storage_class;
	sp1->value.i = sp->value.i;
	if (!sp1->fi) {
		sp1->fi = MakeFunction(sp1->id, sp1, defaultcc==1, false);
		//sp1->fi = newFunction(sp1->id);
		sp1->fi->sym = sp1;
	}
	sp1->IsExternal = sp->IsExternal;
	sp1->fi->IsPascal = sp->fi->IsPascal;
	sp1->fi->IsPrototype = sp->fi->IsPrototype;
	sp1->fi->IsVirtual = sp->fi->IsVirtual;
	sp1->parent = sp->parent;
	sp->fi->params.CopyTo(&sp1->fi->params);
	sp->fi->proto.CopyTo(&sp1->fi->proto);
	sp1->lsyms = sp->lsyms;
	sp = sp1;
	dfs.printf("</MakeFunction>\n");
}

int Declaration::GenerateStorage(txtoStream& tfs, int nbytes, int al, int ilc)
{
	static long old_nbytes;
	int bcnt;

	if (bit_width > 0 && bit_offset > 0) {
		// share the storage word with the previously defined field
		nbytes = old_nbytes - ilc;
	}
	old_nbytes = ilc + nbytes;
	dfs.printf("E");
	if ((ilc + nbytes) % head->roundAlignment()) {
		if (al == sc_thread)
			tseg(tfs);
		else
			dseg(tfs);
	}
	bcnt = 0;
	while ((ilc + nbytes) % head->roundAlignment()) {
		++nbytes;
		bcnt++;
	}
	if (al != sc_member && al != sc_external && al != sc_auto) {
		if (bcnt > 0)
			genstorage(tfs, bcnt);
	}
	return (nbytes);
}


