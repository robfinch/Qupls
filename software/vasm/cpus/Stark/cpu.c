/*
** cpu.c PowerPC cpu-description file
** (c) in 2002-2019,2024 by Frank Wille
*/

#include "vasm.h"
#include "operands.h"

#define TRACE(x)	//{ printf(x); printf("\n"); }

mnemonic mnemonics[] = {
#include "opcodes.h"
};

const int mnemonic_cnt=sizeof(mnemonics)/sizeof(mnemonics[0]);

const char *cpu_copyright="vasm StarkCPU backend 0.l (c) 2025 Robert Finch derived from:\nPowerPC cpu backend 3.2 (c) 2002-2019,2024 Frank Wille";
const char *cpuname = "StarkCPU";
int bytespertaddr = 4;
int ppc_endianess = 1;

static uint64_t cpu_type = CPU_TYPE_STARK | CPU_TYPE_ALTIVEC | CPU_TYPE_32 | CPU_TYPE_ANY | CPU_TYPE_64;
static int regnames = 1;
static taddr sdreg = 28;
static taddr sd2reg = 2;
static unsigned char opt_branch = 0;
#define NREG	93

static char *regnamestr[93] = {
	"r0", "a0", "a1", "a2", "a3", "a4", "a5", "a6", 
	"a7", "t0", "t1", "t2", "t3", "t4", "t5", "t6",
	"t7", "t8", "t9", "s0", "s1", "s2", "s3", "s4",
	"s5", "s6", "s7", "s8",	"s9", "gp", "fp", "sp",
	
	"f0","f1","f2","f3","f4","f5","f6","f7",
	"f8","f9","f10","f11","f12","f13","f14","f15",
	"f16","f17","f18","f19","f20","f21","f22","f23",
	"f24","f25","f26","f27","f28","f29","f30","f31",
	
	"usp","ssp","hsp","msp","mc0","mc1","mc2","mc3",
	"br0","br1","br2","br3","br4","br5","br6","br7",
	"cr0","cr1","cr2","cr3","cr4","cr5","cr6","cr7",
	"lc","mlr","cb","mpc", "xh"
};

static int regop[93] = {
	OPER_GPR, OPER_GPR, OPER_GPR, OPER_GPR, OPER_GPR, OPER_GPR, OPER_GPR, OPER_GPR, 
	OPER_GPR, OPER_GPR, OPER_GPR, OPER_GPR, OPER_GPR, OPER_GPR, OPER_GPR, OPER_GPR, 
	OPER_GPR, OPER_GPR, OPER_GPR, OPER_GPR, OPER_GPR, OPER_GPR, OPER_GPR, OPER_GPR, 
	OPER_GPR, OPER_GPR, OPER_GPR, OPER_GPR, OPER_GPR, OPER_GPR, OPER_GPR, OPER_GPR,
	
	OPER_FPR, OPER_FPR, OPER_FPR, OPER_FPR, OPER_FPR, OPER_FPR, OPER_FPR, OPER_FPR, 
	OPER_FPR, OPER_FPR, OPER_FPR, OPER_FPR, OPER_FPR, OPER_FPR, OPER_FPR, OPER_FPR, 
	OPER_FPR, OPER_FPR, OPER_FPR, OPER_FPR, OPER_FPR, OPER_FPR, OPER_FPR, OPER_FPR, 
	OPER_FPR, OPER_FPR, OPER_FPR, OPER_FPR, OPER_FPR, OPER_FPR, OPER_FPR, OPER_FPR, 

	OPER_GPR, OPER_GPR, OPER_GPR, OPER_GPR, OPER_GPR, OPER_GPR, OPER_GPR, OPER_GPR, 
	OPER_BR, OPER_BR, OPER_BR, OPER_BR, OPER_BR, OPER_BR, OPER_BR, OPER_BR,
	OPER_CR, OPER_CR, OPER_CR, OPER_CR, OPER_CR, OPER_CR, OPER_CR, OPER_CR,
	OPER_GPR, OPER_GPR, OPER_CB, OPER_MPC, OPER_GPR
};

static char* condstr[7] = {
	"eq  ", "nand", "nor ", "lt  ", "le  ", "ca  ", "so  "
};

uint8_t value_bucketno;
value_bucket_t value_bucket[32];
uint32_t instr[32];
uint8_t instrno;

static int is_reg(char *p, char **ep, int* typ)
{
	int nn, jj, rr = -1;
	int sgn = 0;
	int n = 0;

	TRACE("is_reg ");
	if (ep)	
		*ep = p;
//	if (p[n]!='%')
//		return(-1);
	if (p[n]=='%')
	n++;
	
	do {
		if (p[n]=='r') {
			if (isdigit(p[n+1]) && isdigit(p[n+2]) && !ISIDCHAR(p[n+3])) {
				nn = (p[n+1]-'0')*10 + (p[n+2]-'0');
				if (ep)
					*ep = &p[n+3];
				*typ = OPER_GPR;
				rr = 1;
				goto j1;
			}
			else if (isdigit(p[n+1]) && !ISIDCHAR(p[n+2])) {
				nn = (p[n+1]-'0');
				if (ep)
					*ep = &p[n+2];
				*typ = OPER_GPR;
				rr = 1;
				goto j1;
			}
		}
		
		for (nn = 0; nn < NREG; nn++) {
			// Look for longest match first
			/*
			if (p[n] == regnamestr[nn][0] && p[n+1] == regnamestr[nn][1] && p[n+2] == regnamestr[nn][2]) {
				if (!ISIDCHAR((unsigned char)p[n+3])) {
					if (regnamestr[nn][3]=='\0') {
						*typ = regop[nn];
						if (ep)
							*ep = &p[n+3];
						return (nn);
					}
					return (-1);
				}
			}
			*/
			if (p[n] == regnamestr[nn][0] && p[n+1] == regnamestr[nn][1]) {
				if (!ISIDCHAR((unsigned char)p[n+2])) {
					if (regnamestr[nn][2]=='\0') {
						if (ep)
							*ep = &p[n+2];
						*typ = regop[nn];
						rr = 1;
						goto j1;
					}
					return (-1);
				}
	//			if (regnamestr[nn][2]=='\0')
	//				return (-1);
				if (regnamestr[nn][2]==p[n+2]) {
					if (!ISIDCHAR((unsigned char)p[n+3])) {
						if (regnamestr[nn][3]=='\0') {
							*typ = regop[nn];
							if (ep)
								*ep = &p[n+3];
							rr = 1;
							goto j1;
						}
						return (-1);
					}
	//				if (regnamestr[nn][3]=='\0')
	//					return (-1);
					if (regnamestr[nn][3]==p[n+3]) {
						if (!ISIDCHAR((unsigned char)p[n+4])) {
							if (regnamestr[nn][4]=='\0') {
								if (ep)
									*ep = &p[n+4];
								*typ = regop[nn];
								rr = 1;
								goto j1;
							}
							return (-1);
						}
					}
				}
			}
		}
	} while (0);
j1:
	// Look for a suffix, place suffix index in bits 8 to 10 of return value.
	if (rr > 0) {
		p = *ep;
		if (*p=='?') {
			p++;
			for (jj = 0; jj < 7; jj++) {
				if (p[0]==condstr[jj][0] && p[1]==condstr[jj][1] && p[2]==condstr[jj][2] && p[3]==condstr[jj][3] && !ISIDCHAR(p[4])) {
					if (ep) *ep = &p[4];
					return (nn | (jj << 8));
				}
				if (p[0]==condstr[jj][0] && p[1]==condstr[jj][1] && p[2]==condstr[jj][2] && !ISIDCHAR(p[3])) {
					if (ep) *ep = &p[3];
					return (nn | (jj << 8));
				}
				if (p[0]==condstr[jj][0] && p[1]==condstr[jj][1] && !ISIDCHAR(p[2])) {
					if (ep) *ep = &p[2];
					return (nn | (jj << 8));
				}
			}
		}
		return (nn);
	}
	return (-1);	
}


int ppc_data_align(int n)
{
  if (n<=8) return 1;
  if (n<=16) return 2;
  if (n<=32) return 4;
  return 8;
}


int ppc_data_operand(int n)
{
  if (n&OPSZ_FLOAT) return OPSZ_BITS(n)>32?OP_F64:OP_F32;
  if (OPSZ_BITS(n)<=8) return OP_D8;
  if (OPSZ_BITS(n)<=10) return OP_D10;
  if (OPSZ_BITS(n)<=14) return OP_D14;
  if (OPSZ_BITS(n)<=16) return OP_D16;
  if (OPSZ_BITS(n)<=32) return OP_D32;
  return OP_D64;
}


int ppc_operand_optional(operand *op,int type)
{
  if (powerpc_operands[type].flags & OPER_OPTIONAL) {
    op->attr = REL_NONE;
    op->mode = OPM_NONE;
    op->basereg = NULL;
    op->ndxreg = 0;
    op->value = number_expr(0);  /* default value 0 */

    if (powerpc_operands[type].flags & OPER_NEXT)
      op->type = NEXT;
    else
      op->type = type;
    return 1;
  }
  else if (powerpc_operands[type].flags & OPER_FAKE) {
    op->type = type;
    op->value = NULL;
    return 1;
  }

  return 0;
}


int ppc_available(int idx)
/* Check if mnemonic is available for selected cpu_type. */
{
  uint64_t avail = mnemonics[idx].ext.available;
  uint64_t datawidth = CPU_TYPE_32 | CPU_TYPE_64;

  if ((avail & cpu_type) != 0) {
    if ((avail & cpu_type & ~datawidth)!=0 || (cpu_type & CPU_TYPE_ANY)!=0) {
      if (avail & datawidth)
        return (avail & datawidth) == (cpu_type & datawidth)
               || (cpu_type & CPU_TYPE_64_BRIDGE) != 0;
      else
        return 1;
    }
  }
  return 0;
}


static char *parse_reloc_attr(char *p,operand *op)
{
	TRACE("parse_reloc_attr");
  p = skip(p);
  while (*p == '@') {
    unsigned char chk;

    p++;
    chk = op->attr;
    if (!strncmp(p,"got",3)) {
      op->attr = REL_GOT;
      p += 3;
    }
    else if (!strncmp(p,"plt",3)) {
      op->attr = REL_PLT;
      p += 3;
    }
    else if (!strncmp(p,"sdax",4)) {
      op->attr = REL_SD;
      p += 4;
    }
    else if (!strncmp(p,"sdarx",5)) {
      op->attr = REL_SD;
      p += 5;
    }
    else if (!strncmp(p,"sdarel",6)) {
      op->attr = REL_SD;
      p += 6;
    }
    else if (!strncmp(p,"sectoff",7)) {
      op->attr = REL_SECOFF;
      p += 7;
    }
    else if (!strncmp(p,"local",5)) {
      op->attr = REL_LOCALPC;
      p += 5;
    }
    else if (!strncmp(p,"globdat",7)) {
      op->attr = REL_GLOBDAT;
      p += 7;
    }
    else if (!strncmp(p,"sda2rel",7)) {
      op->attr = REL_PPCEABI_SDA2;
      p += 7;
    }
    else if (!strncmp(p,"sda21",5)) {
      op->attr = REL_PPCEABI_SDA21;
      p += 5;
    }
    else if (!strncmp(p,"sdai16",6)) {
      op->attr = REL_PPCEABI_SDAI16;
      p += 6;
    }
    else if (!strncmp(p,"sda2i16",7)) {
      op->attr = REL_PPCEABI_SDA2I16;
      p += 7;
    }
    else if (!strncmp(p,"drel",4)) {
      op->attr = REL_MORPHOS_DREL;
      p += 4;
    }
    else if (!strncmp(p,"brel",4)) {
      op->attr = REL_AMIGAOS_BREL;
      p += 4;
    }
    if (chk!=REL_NONE && chk!=op->attr)
      cpu_error(7);  /* multiple relocation attributes */

    chk = op->mode;
    if (chk!=OPM_NONE && chk!=op->mode)
      cpu_error(8);  /* multiple hi/lo modifiers */
  }

  return (p);
}


int parse_operand(char *p,int len,operand *op,int optype)
/* Parses operands, reads expressions and assigns relocation types. */
{
  char *start = p;
  int rc = PO_MATCH;
  char *q, *q2;
  char *plus_pos;
  int regtype;
  int regno = 0,pregno;
  int isnum = 0;
  unsigned int regpat;
  int rgcount = 0;
  int islist = 0;
  int range = 0;

	TRACE("parse_operand");
	if (p == NULL || op == NULL) {
		cpu_error(4);
		return (PO_NOMATCH);
	}
	plus_pos = NULL;
  op->attr = REL_NONE;
  op->mode = OPM_NONE;
  op->basereg = NULL;
  op->bsereg = 0;
  op->ndxreg = 0;
  op->scale = 0;
  regpat = 0;

  p = skip(p);
  /* This first chunk of code parses a register list, which may include
  	only a single register.
  */
  while(1) {
  	pregno = regno;
  	regno = is_reg(p, &p, &regtype);
	  if (regno >= 0) {
	  	rgcount++;
	  	if (range) {
	  		do {
	  			regpat |= 1 << (pregno & 15);
	  			regpat |= (((pregno >> 4) & 15) << 28);
	  			if (pregno < regno)
	  				pregno++;
	  			else
	  				pregno--; 
	  		} while (pregno != regno);
	  		range = 0;
	  	}
	  	else {
	  		regpat |= 1 << (regno & 15);
	  		regpat |= (((regno >> 4) & 15) << 28);
	  	}
	  	if (*p=='/') {
	  		p = skip(p+1);
	  		continue;
	  	}
	  	if (*p=='-') {
	  		range = 1;
	  		p = skip(p+1);
	  		continue;
	  	}
	  	break;
	  }
	  else 
	  	break;
	}
	if (regpat) {
  	op->type = optype;
		if (rgcount > 1 || (optype == RL)) {
			regtype = OPER_REGLIST;
	    op->value = number_expr(regpat);
		}
		else
	    op->value = number_expr(regno);
  	if ((powerpc_operands[optype].flags & (regtype|OPER_REGLIST)) != 0)
  		return (PO_MATCH);
		return (PO_NOMATCH);
	}

	/* With register detection out of the way, we look for other operands. */
  if (*p=='$') {
  	isnum = 1;
  	p++;
  }
  TRACE("past $\n");
  if (*p=='[')
  	op->value = number_expr(0);
  else {
	  op->value = OP_FLOAT(optype) ? parse_expr_float(&p) : parse_expr(&p);
	}
  if (op->value->type==NUM) {
  	if (powerpc_operands[optype].flags & OPER_U14) {
			if (!is_uint14(op->value->c.val))
				op->attr = REL_CLRIMM;
  	}
		else if (!is_int14(op->value->c.val)) {
			op->attr = REL_CLRIMM;
		}
  }
  else if (op->value->type==SYM && !(powerpc_operands[optype].flags & OPER_RELATIVE))
  	op->attr = REL_CLRIMM;
//  if (powerpc_operands[optype].flags & OPER_REG) {
//  	return (PO_NOMATCH);
//  }

  if (1||!OP_DATA(optype)) {
    p = parse_reloc_attr(p,op);
    p = skip(p);

    if (p-start < len && *p=='[') {
      /* parse d(Rn) load/store addressing mode */
      if (powerpc_operands[optype].flags & OPER_PARENS) {
        p++;
        q = p;
        op->bsereg = is_reg(p, &p, &regtype);
			  if (op->bsereg < 0 || regtype != OPER_GPR) {
			  	TRACE("no base reg in []\n");
	        cpu_error(4);  /* illegal operand type */
  	      rc = PO_CORRUPT;
    	    goto leave;
			  }
        op->basereg = number_expr(op->bsereg);
			  regtype = OPER_PARENS;
//			  q++;
        p = skip(p);
        if (*p=='+') {
        	plus_pos = p;
        	*p=',';
          p = skip(p+1);
				  if ((op->ndxreg = is_reg(p, &p, &regtype)) < 0) {
				  	TRACE("no index reg in [Rm+Rn]\n");
		        cpu_error(4);  /* illegal operand type */
	  	      rc = PO_CORRUPT;
	    	    goto leave;
				  }
				  regtype = OPER_SCNDX;
				  if (*p=='*') {
	          p = skip(p+1);
						switch(*p) {
						case ']': op->scale = op->mne->ext.size; break;
						case '1': op->scale = 1; p = skip(p+1); break;
						case '2': op->scale = 2; p = skip(p+1); break;
						case '4': op->scale = 4; p = skip(p+1); break;
						case '8': op->scale = 8; p = skip(p+1); break;
						}			  	
				  }
        }
        if (*p == ']') {
          p = skip(p+1);
//          rc = PO_SKIP;
        }
        else {
          cpu_error(5);  /* missing closing parenthesis */
          rc = PO_CORRUPT;
          goto leave;
        }
			  if ((powerpc_operands[optype].flags & regtype)==0) {
			  	TRACE("[] or [+] not allowed\n");
          rc = PO_NOMATCH;
          goto leave;
				}			  	
      }
      else {
//        cpu_error(4);  /* illegal operand type */
//        rc = PO_CORRUPT;
				TRACE("[ not allowed\n");
        rc = PO_NOMATCH;
        goto leave;
      }
    }
   	rc=PO_MATCH;
  }

  if (p-start < len)
    cpu_error(3);  /* trailing garbage in operand */
leave:
	if (plus_pos)
		*plus_pos = '+';
  op->type = optype;
  return (rc);
}


static taddr read_sdreg(char **s,taddr def)
{
  expr *tree;
  taddr val = def;

  *s = skip(*s);
  tree = parse_expr(s);
  simplify_expr(tree);
  if (tree->type==NUM && tree->c.val>=0 && tree->c.val<=31)
    val = tree->c.val;
  else
    cpu_error(13);  /* not a valid register */
  free_expr(tree);
  return val;
}


char *parse_cpu_special(char *start)
/* parse cpu-specific directives; return pointer to end of
   cpu-specific text */
{
  char *name=start,*s=start;

  if (ISIDSTART(*s)) {
    s++;
    while (ISIDCHAR(*s))
      s++;
    if (dotdirs && *name=='.')
      name++;
    if (s-name==5 && !strncmp(name,"sdreg",5)) {
      sdreg = read_sdreg(&s,sdreg);
      return s;
    }
    else if (s-name==6 && !strncmp(name,"sd2reg",6)) {
      sd2reg = read_sdreg(&s,sd2reg);
      return s;
    }
  }
  return start;
}


static int get_reloc_type(operand *op)
{
  int rtype = REL_NONE;

	TRACE("get_reloc_type");
  if (OP_DATA(op->type)) {  /* data relocs */
    return REL_ABS;
  }

  else {  /* handle instruction relocs */
    const struct powerpc_operand *ppcop = &powerpc_operands[op->type];

    if (ppcop->shift == 0 || (ppcop->shift==17 && ppcop->bits==14) || op->type==BD) {
      if (ppcop->bits == 16 || ppcop->bits == 26 || ppcop->bits==14 || op->type==BD) {

        if (ppcop->flags & OPER_RELATIVE) {  /* a relative branch */
          switch (op->attr) {
            case REL_NONE:
              rtype = REL_PC;
              break;
            case REL_PLT:
              rtype = REL_PLTPC;
              break;
            case REL_LOCALPC:
              rtype = REL_LOCALPC;
              break;
            default:
              cpu_error(11); /* reloc attribute not supported by operand */
              break;
          }
        }

        else if (ppcop->flags & OPER_ABSOLUTE) { /* absolute branch */
          switch (op->attr) {
            case REL_NONE:
              rtype = REL_ABS;
              break;
            case REL_PLT:
            case REL_GLOBDAT:
            case REL_SECOFF:
              rtype = op->attr;
              break;
            default:
              cpu_error(11); /* reloc attribute not supported by operand */
              break;
          }
        }

        else {  /* immediate 16 bit or load/store d16(Rn) instruction */
          switch (op->attr) {
            case REL_NONE:
              rtype = REL_ABS;
              break;
            case REL_GOT:
            case REL_PLT:
            case REL_SD:
            case REL_PPCEABI_SDA2:
            case REL_PPCEABI_SDA21:
            case REL_PPCEABI_SDAI16:
            case REL_PPCEABI_SDA2I16:
            case REL_MORPHOS_DREL:
            case REL_AMIGAOS_BREL:
              rtype = op->attr;
              break;
            case REL_CLRIMM:
              rtype = op->attr;
              break;
            default:
              cpu_error(11); /* reloc attribute not supported by operand */
              break;
          }
        }
      }
    }
  }

  return (rtype);
}


static int valid_hiloreloc(int type)
/* checks if this relocation type allows a @l/@h/@ha modifier */
{
  switch (type) {
  	case REL_CLRIMM:
    case REL_ABS:
    case REL_GOT:
    case REL_PLT:
    case REL_MORPHOS_DREL:
    case REL_AMIGAOS_BREL:
      return 1;
  }
  cpu_error(6);  /* relocation does not allow hi/lo modifier */
  return 0;
}


static taddr make_reloc(int reloctype,operand *op,section *sec,
                        taddr pc,rlist **reloclist)
/* create a reloc-entry when operand contains a non-constant expression */
{
  taddr val;
 	symbol *base;
 	int btype;

	TRACE("make_reloc");
  btype = find_base(op->value,&base,sec,pc);
  TRACE("found base");
  if (!eval_expr(op->value,&val,sec,pc)) {
	  TRACE("after eval_expr");
    /* non-constant expression requires a relocation entry */
    int pos,size,offset;
    taddr addend,mask;

    pos = offset = 0;

    if (btype > BASE_ILLEGAL) {
      if (btype == BASE_PCREL) {
        if (reloctype == REL_ABS)
          reloctype = REL_PC;
        else
          goto illreloc;
      }

     	TRACE("mrelo 1");
      if (op->mode != OPM_NONE) {
        /* check if reloc allows @ha/@h/@l */
        if (!valid_hiloreloc(reloctype))
          op->mode = OPM_NONE;
      }

      if (reloctype == REL_PC && !is_pc_reloc(base,sec)) {
        /* a relative branch - reloc is only needed for external reference */
        return val-pc;
      }

      /* determine reloc size, offset and mask */
      if (OP_DATA(op->type)) {  /* data operand */
        switch (op->type) {
          case OP_D8:
            size = 8;
            break;
          case OP_D10:
          	size = 10;
          	break;
          case OP_D16:
            size = 16;
            break;
          case OP_D32:
          case OP_F32:
            size = 32;
            break;
          case OP_D64:
          case OP_F64:
            size = 64;
            break;
          default:
            ierror(0);
            break;
        }
        addend = val;
        mask = -1;
      }
      else {  /* instruction operand */
        const struct powerpc_operand *ppcop = &powerpc_operands[op->type];

        if (ppcop->flags & (OPER_RELATIVE|OPER_ABSOLUTE)) {
          addend = (btype == BASE_PCREL) ? val + offset : val;
          /* branch instruction */
          if (ppcop->bits == 25) {
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           0,1,0,4L);
            size = 22;
            offset = 6;
            mask = 0x1fffff8LL;
          }
          else {
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           0,1,0,4L);
			      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           6,8,0,0x7f8LL);
            size = 2;
            offset = 29;
            mask = 0x1800LL;
          }
        }
        else {
          /* load/store or immediate */
          size = 16;
          offset = 2;
          addend = (btype == BASE_PCREL) ? val + offset : val;
          switch (op->mode) {
            case OPM_LO:
              mask = 0xffff;
              break;
            case OPM_HI:
              mask = 0xffff0000;
              break;
            case OPM_HA:
              add_extnreloc_masked(reloclist,base,addend,reloctype,
                                   pos,size,offset,0x8000);
              mask = 0xffff0000;
              break;
            case OPM_CLR:
							if (!is_int14(val)) {

     						TRACE("add_4");
								add_extnreloc_masked(reloclist,base,0,REL_CLRIMM,
								                     17,5,0,0x1fL);
								value_bucket[value_bucketno].relocs = reloclist;
								return (val);
							}
              mask = -1;
            	break;
            default:
							if (!is_int14(val)) {

     						TRACE("add_3");
								add_extnreloc_masked(reloclist,base,0,REL_CLRIMM,
								                     17,5,0,0x1fL);
								value_bucket[value_bucketno].relocs = reloclist;
								return (val);
							}
              mask = -1;
              break;
          }
        }
      }

     	TRACE("add_2");
      add_extnreloc_masked(reloclist,base,addend,reloctype,
                           pos,size,offset,mask);
    }
    else {
illreloc:
      general_error(38);  /* illegal relocation */
    }
  }
  else {
     if (reloctype == REL_PC) {
       /* a relative reference to an absolute label */
       return val-pc;
     }
     if (!is_int14(val)) {
     	if (base==NULL) {
     		base = new_tmplabel(sec);
     	}
     	TRACE("add_1");
	     add_extnreloc_masked(reloclist,base,(taddr)0,REL_CLRIMM,
	                           17,5,0,0x1fL);
	     value_bucket[value_bucketno].relocs = reloclist;
     }
  }

	TRACE("mreloc ret val");
  return (val);
}


static void fix_reloctype(dblock *db,int rtype)
{
  rlist *rl;

  for (rl=db->relocs; rl!=NULL; rl=rl->next)
    rl->type = rtype;
}


static void range_check(taddr val,const struct powerpc_operand *o,dblock *db)
/* checks if a value fits the allowed range for this operand field */
{
  int32_t v = (int32_t)val;
  int32_t minv = 0;
  int32_t maxv = (1L << o->bits) - 1;
  int force_signopt = 0;

	return;
	TRACE("range_check");
	if (o->flags & OPER_U14) {
		return;
	}
	else if (o->flags & OPER_S14) {
		return;
	}

  if (db) {
    if (db->relocs) {
      switch (db->relocs->type) {
        case REL_SD:
        case REL_PPCEABI_SDA2:
        case REL_PPCEABI_SDA21:
          force_signopt = 1;  /* relocation allows full positive range */
          break;
      }
    }
  }

  if (o->flags & OPER_SIGNED) {
    minv = ~(maxv >> 1);

    /* @@@ Only recognize this flag in 32-bit mode! Don't care for now */
    if (!(o->flags & OPER_SIGNOPT) && !force_signopt)
      maxv >>= 1;
  }
  if (o->flags & OPER_NEGATIVE)
    v = -v;
    
  if (o->flags & OPER_CR)
  	v &= 7;
  if (o->flags & OPER_FPR)
  	v &= 31;
  	
  if (o->flags & OPER_REGLIST) {
  	minv = 0L;
  	maxv = 0x7fffffffL;
  }

  if (v<minv || v>maxv)
    cpu_error(12,v,minv,maxv);  /* operand out of range */
}


static void negate_bo_cond(uint32_t *p)
/* negates all conditions in a branch instruction's BO field */
{
  if (!(*p & 0x02000000))
    *p ^= 0x01000000;
  if (!(*p & 0x00800000))
    *p ^= 0x00400000;
}


static uint32_t insertcode(uint32_t i,taddr val,
                           const struct powerpc_operand *o)
{
  if (o->insert) {
    const char *errmsg = NULL;

    i = (o->insert)(i,(int32_t)val,&errmsg);
    if (errmsg)
      cpu_error(0,errmsg);
  }
  else
    i |= ((int32_t)val & ((1<<o->bits)-1)) << o->shift;

  return i;
}


size_t eval_operands(instruction *ip,section *sec,taddr pc,
                     uint32_t *insn,dblock *db)
/* evaluate expressions and try to optimize instruction,
   return size of instruction */
{
  mnemonic *mnemo = &mnemonics[ip->code];
  size_t isize = 4;
  int i;
  operand op;

	TRACE("eval_operands");
  if (insn != NULL)
    *insn = mnemo->ext.opcode;

  for (i=0; i<MAX_OPERANDS && ip->op[i]!=NULL; i++) {
    const struct powerpc_operand *ppcop;
    int reloctype;
    taddr val;

    op = *(ip->op[i]);
    op.mne = mnemo;

    if (op.type == NEXT) {
      /* special case: operand omitted and use this operand's type + 1
         for the next operand */
      op = *(ip->op[++i]);
      op.type = mnemo->operand_type[i-1] + 1;
    }

    ppcop = &powerpc_operands[op.type];

    if (ppcop->flags & OPER_FAKE) {
      if (insn != NULL) {
        if (op.value != NULL)
          cpu_error(16);  /* ignoring fake operand */
        *insn = insertcode(*insn,0,ppcop);
      }
      continue;
    }

		reloctype = get_reloc_type(&op);
    if (reloctype != REL_NONE) {
      if (db != NULL) {
        val = make_reloc(reloctype,&op,sec,pc,&db->relocs);
      }
      else {
        if (!eval_expr(op.value,&val,sec,pc)) {
          if (reloctype == REL_PC)
            val -= pc;
        }
      }
    }
    else {
      if (!eval_expr(op.value,&val,sec,pc))
        if (insn != NULL) {
        	TRACE("error 2 1");
          cpu_error(2);  /* constant integer expression required */
        }
    }

    /* execute modifier on val */
    if (op.mode) {
      switch (op.mode) {
        case OPM_LO:
          val &= 0xffff;
          break;
        case OPM_HI:
          val = (val>>16) & 0xffff;
          break;
        case OPM_HA:
          val = ((val>>16) + ((val & 0x8000) ? 1 : 0) & 0xffff);
          break;
        case OPM_CLR:
        	value_bucket[value_bucketno].value = val;
        	val = value_bucketno;
        	break;
      }
      /*
      if ((ppcop->flags & OPER_SIGNED) && (val & 0x8000))
        val -= 0x10000;
      */
    }

    /* do optimizations here: */

    if (opt_branch) {
      if (reloctype==REL_PC &&
          (op.type==BD || op.type==BDM || op.type==BDP)) {
        if (val<-0x1000 || val>0xfff) {
          /* "B<cc>" branch destination out of range, convert into
             a "B<!cc> ; B" combination */
          if (insn != NULL) {
            negate_bo_cond(insn);
            *insn = insertcode(*insn,8,ppcop);  /* B<!cc> $+8 */
            insn++;
            *insn = B(18,0,0);  /* set B instruction opcode */
            val -= 4;
          }
          ppcop = &powerpc_operands[LI];  /* set oper. for B instruction */
          isize = 8;
        }
      }
    }

    if (ppcop->flags & OPER_PARENS) {
    	if (op.basereg==NULL)
    		op.basereg = number_expr(0);
      if (op.basereg) {
        /* a load/store instruction d(Rn) carries basereg in current op */
        taddr reg;

        if (db!=NULL && op.mode==OPM_NONE && (op.attr==REL_NONE || op.attr==REL_CLRIMM)) {
        	op.attr = REL_NONE;
          if (eval_expr(op.basereg,&reg,sec,pc)) {
            if (reg == sdreg)  /* is it a small data reference? */
              fix_reloctype(db,REL_SD);
            else if (reg == sd2reg)  /* EABI small data 2 */
              fix_reloctype(db,REL_PPCEABI_SDA2);
          }
        }

        /* write displacement */
        if (insn != NULL) {
          range_check(val,ppcop,db);
          *insn = insertcode(*insn,val,ppcop);
        }

        /* move to next operand type to handle base register */
        op.type = RA;//mnemo->operand_type[++i];
        ppcop = &powerpc_operands[op.type];
        op.attr = REL_NONE;
        op.mode = OPM_NONE;
        op.value = op.basereg;
        if (op.value) {
	        if (!eval_expr(op.value,&val,sec,pc))
	          if (insn != NULL) {
	          	TRACE("error2 2");
	            cpu_error(2);  /* constant integer expression required */
	          }
        }
        else
        	val = 0; 
      }
      else if (insn != NULL)
        cpu_error(14);  /* missing base register */
    }

    /* write val (register, immediate, etc.) */
    if (insn != NULL) {
      range_check(val,ppcop,db);
      *insn = insertcode(*insn,val,ppcop);
    }
    /* move to next operand type to handle base register */
    
  	if (op.ndxreg) {
      op.type = RB;
      ppcop = &powerpc_operands[RB];
      op.attr = REL_NONE;
      op.mode = OPM_NONE;
      val = op.ndxreg;
	    if (insn != NULL) {
	      range_check(val,ppcop,db);
	      *insn = insertcode(*insn,val,ppcop);
	    }
  	}
  	
  }

  return isize;
}

int will_fit(taddr pc)
{
	uint32_t ndx = pc & 0x3f;
	
	return (ndx < 64-totsz);
}


size_t instruction_size(instruction *ip,section *sec,taddr pc)
/* Calculate the size of the current instruction; must be identical
   to the data created by eval_instruction. */
{
  /* determine optimized size, when needed */
  if (opt_branch)
    return eval_operands(ip,sec,pc,NULL,NULL);

  /* otherwise an instruction is always 4 bytes */
  return 4;
}


dblock *eval_instruction(instruction *ip,section *sec,taddr pc)
/* Convert an instruction into a DATA atom including relocations,
   when necessary. */
{
  dblock *db = new_dblock();
  uint32_t insn[2];

	TRACE("eval_instruction");
	uint32_t isize = eval_operands(ip,sec,pc,insn,db);

	/* start of cache line? */
	if (!will_fit(pc+isize)) {
		int space;
		
		space = (64 - totsz - ((pc+isize) & 0x3fL));
		db->size = totsz + space + isize;
		{
  		unsigned char *d = db->data = mymalloc(db->size);
	    int i;
			int pos;
			rlist* p;

			// Fixup the reloc entries
			pos = 64 - totsz;
			for (i=0; i < value_bucketno; i++) {
				if (value_bucket[i].relocs) {
					for (p = *value_bucket[i].relocs; p; p = p->next) {
						if (p->type == REL_CLRIMM) {
							p->type = REL_ABS;
							((nreloc*)p->reloc)->addend = pos;
						}
					}
				}
			}
			// Copy last instructions to fit on cache line to output	
	    for (i=0; i<isize/4; i++)
  		  d = setval(0,d,4,insn[i]);
  		// Copy zeros to output for the space between the last instruction
  		// and the constant values.
	    for (i=0; i<space; i++)
  		  d = setval(0,d,1,0);
  		// Copy the constant values to output
			for (i=0; i < value_bucketno; i++) {
				switch(value_bucket[i].size) {
				case 16:	d = setval(0,d,2,value_bucket[i].value);	break;
				case 32:	d = setval(0,d,4,value_bucket[i].value);	break;
				}
			}
		}
		// Reset value buckets
		totsz = 0;
		value_bucketno = 0;
		return (db);
	}
  if (db->size = isize) {
    unsigned char *d = db->data = mymalloc(db->size);
    int i;

    for (i=0; i<db->size/4; i++)
      d = setval(0,d,4,insn[i]);
  }

  return (db);
}


dblock *eval_data(operand *op,size_t bitsize,section *sec,taddr pc)
/* Create a dblock (with relocs, if necessary) for size bits of data. */
{
  dblock *db = new_dblock();
  taddr val;
  tfloat flt;

	TRACE("eval_data");
  if ((bitsize & 7) || bitsize > 64)
    cpu_error(9,bitsize);  /* data size not supported */
  if (!OP_DATA(op->type))
    ierror(0);

  db->size = bitsize >> 3;
  db->data = mymalloc(db->size);

  if (type_of_expr(op->value) == FLT) {
    if (!eval_expr_float(op->value,&flt))
      general_error(60);  /* cannot evaluate floating point */

    switch (bitsize) {
      case 32:
        conv2ieee32(1,db->data,flt);
        break;
      case 64:
        conv2ieee64(1,db->data,flt);
        break;
      default:
        cpu_error(10);  /* data has illegal type */
        break;
    }
  }
  else {
    val = make_reloc(get_reloc_type(op),op,sec,pc,&db->relocs);

    switch (db->size) {
      case 1:
        db->data[0] = val & 0xff;
        break;
      case 2:
      case 4:
      case 8:
        setval(ppc_endianess,db->data,db->size,val);
        break;
      default:
        ierror(0);
        break;
    }
  }

  return db;
}

void patch_section(section* sec)
{
	atom* p;
	for (p = sec->first; p; p = p->next) {
		
	}
}

operand *new_operand(void)
{
  operand *new = mymalloc(sizeof(*new));
  new->type = -1;
  new->mode = OPM_NONE;
  return new;
}


size_t cpu_reloc_size(rlist *rl)
{
  return 0;  /* no special cpu relocs, all are nreloc */
}


void cpu_reloc_print(FILE *f,rlist *rl)
{
  static const char *rname[(LAST_CPU_RELOC+1)-FIRST_CPU_RELOC] = {
    "sd2","sd21","sdi16","drel","brel"
  };
  fprintf(f,"r%s",rname[rl->type-FIRST_CPU_RELOC]);
  print_nreloc(f,rl->reloc,1);
}


void cpu_reloc_write(FILE *f,rlist *rl)
{
  /* nothing to do, all are nreloc */
}


static void define_regnames(void)
{
  char r[10];
  int i;

  for (i=0; i<32; i++) {
    sprintf(r,"%%r%d",i);
  	if (i > 0)
	    set_internal_abs(r,i);
    r[1] = 'f';
    set_internal_abs(r,i);
    r[1] = 'v';
    set_internal_abs(r,i);
    sprintf(r,"r%d",i);
    set_internal_abs(r,i);
  }
  for (i=0; i<8; i++) {
    sprintf(r,"%%br%d",i);
    set_internal_abs(r,i);
    sprintf(r,"br%d",i);
    set_internal_abs(r,i);
  }
  /*
  for (i=0; i<8; i++) {
    sprintf(r,"%%cr%d.eq",i);
    set_internal_abs(r,i|(0<<8));
    sprintf(r,"%%cr%d.lt",i);
    set_internal_abs(r,i|(3<<8));
    sprintf(r,"%%cr%d.le",i);
    set_internal_abs(r,i|(4<<8));
    sprintf(r,"%%cr%d.ca",i);
    set_internal_abs(r,i|(5 << 8));
    sprintf(r,"%%cr%d.so",i);
    set_internal_abs(r,i|(6 << 8));
    sprintf(r,"%%cr%d",i);
    set_internal_abs(r,i);
    sprintf(r,"cr%d",i);
    set_internal_abs(r,i);
  }
  */
  set_internal_abs("vrsave",256);
  set_internal_abs("lt",0);
  set_internal_abs("gt",1);
  set_internal_abs("eq",2);
  set_internal_abs("so",3);
  set_internal_abs("un",3);
  set_internal_abs("%%sp",31);
  set_internal_abs("sp",31);
  set_internal_abs("rtoc",2);
  set_internal_abs("%%fp",30);
  set_internal_abs("%%fpscr",0);
  set_internal_abs("%%xer",1);
  set_internal_abs("%%br0",8);
  set_internal_abs("%%ctr",9);
  set_internal_abs("%%a0",1);
  set_internal_abs("%%a1",2);
  set_internal_abs("%%a2",3);
  set_internal_abs("%%a3",4);
  set_internal_abs("%%a4",5);
  set_internal_abs("%%a5",6);
  set_internal_abs("%%a6",7);
  set_internal_abs("%%a7",8);
  set_internal_abs("%%t0",9);
  set_internal_abs("%%t1",10);
  set_internal_abs("%%t2",11);
  set_internal_abs("%%t3",12);
  set_internal_abs("%%t4",13);
  set_internal_abs("%%t5",14);
  set_internal_abs("%%t6",15);
  set_internal_abs("%%t7",16);
  set_internal_abs("%%t8",17);
  set_internal_abs("%%t9",18);
  set_internal_abs("%%s0",19);
  set_internal_abs("%%s1",20);
  set_internal_abs("%%s2",21);
  set_internal_abs("%%s3",22);
  set_internal_abs("%%s4",23);
  set_internal_abs("%%s5",24);
  set_internal_abs("%%s6",25);
  set_internal_abs("%%s7",26);
  set_internal_abs("%%s8",27);
  set_internal_abs("%%s9",28);
  set_internal_abs("%%gp",29);
  set_internal_abs("fp",30);
  set_internal_abs("fpscr",0);
  set_internal_abs("xer",1);
  set_internal_abs("br0",8);
  set_internal_abs("ctr",9);
  set_internal_abs("a0",1);
  set_internal_abs("a1",2);
  set_internal_abs("a2",3);
  set_internal_abs("a3",4);
  set_internal_abs("a4",5);
  set_internal_abs("a5",6);
  set_internal_abs("a6",7);
  set_internal_abs("a7",8);
  set_internal_abs("t0",9);
  set_internal_abs("t1",10);
  set_internal_abs("t2",11);
  set_internal_abs("t3",12);
  set_internal_abs("t4",13);
  set_internal_abs("t5",14);
  set_internal_abs("t6",15);
  set_internal_abs("t7",16);
  set_internal_abs("t8",17);
  set_internal_abs("t9",18);
  set_internal_abs("s0",19);
  set_internal_abs("s1",20);
  set_internal_abs("s2",21);
  set_internal_abs("s3",22);
  set_internal_abs("s4",23);
  set_internal_abs("s5",24);
  set_internal_abs("s6",25);
  set_internal_abs("s7",26);
  set_internal_abs("s8",27);
  set_internal_abs("s9",28);
  set_internal_abs("gp",29);
}


int init_cpu(void)
{
  if (regnames)
    define_regnames();
  value_bucketno = 0;
  return 1;
}


int cpu_args(char *p)
{
  int i;

  if (!strncmp(p,"-m",2)) {
    p += 2;
    if (!strcmp(p,"pwrx") || !strcmp(p,"pwr2"))
      cpu_type = CPU_TYPE_POWER | CPU_TYPE_POWER2 | CPU_TYPE_32;
    else if (!strcmp(p,"pwr"))
      cpu_type = CPU_TYPE_POWER | CPU_TYPE_32;
    else if (!strcmp(p,"601"))
      cpu_type = CPU_TYPE_601 | CPU_TYPE_PPC | CPU_TYPE_32;
    else if (!strcmp(p,"ppc") || !strcmp(p,"ppc32") || !strncmp(p,"60",2) ||
             !strncmp(p,"75",2) || !strncmp(p,"85",2))
      cpu_type = CPU_TYPE_PPC | CPU_TYPE_32;
    else if (!strcmp(p,"ppc64") || !strcmp(p,"620"))
      cpu_type = CPU_TYPE_PPC | CPU_TYPE_64;
    else if (!strcmp(p,"7450"))
      cpu_type = CPU_TYPE_PPC | CPU_TYPE_7450 | CPU_TYPE_32 | CPU_TYPE_ALTIVEC;
    else if (!strncmp(p,"74",2) || !strcmp(p,"avec") || !strcmp(p,"altivec"))
      cpu_type = CPU_TYPE_PPC | CPU_TYPE_32 | CPU_TYPE_ALTIVEC;
    else if (!strcmp(p,"403"))
      cpu_type = CPU_TYPE_PPC | CPU_TYPE_403 | CPU_TYPE_32;
    else if (!strcmp(p,"405"))
      cpu_type = CPU_TYPE_PPC | CPU_TYPE_403 | CPU_TYPE_405 | CPU_TYPE_32;
    else if (!strncmp(p,"44",2) || !strncmp(p,"46",2))
      cpu_type = CPU_TYPE_PPC | CPU_TYPE_440 | CPU_TYPE_BOOKE | CPU_TYPE_ISEL
                 | CPU_TYPE_RFMCI | CPU_TYPE_32;
    else if (!strcmp(p,"821") || !strcmp(p,"850") || !strcmp(p,"860"))
      cpu_type = CPU_TYPE_PPC | CPU_TYPE_860 | CPU_TYPE_32;
    else if (!strcmp(p,"e300"))
      cpu_type = CPU_TYPE_PPC | CPU_TYPE_E300 | CPU_TYPE_32;
    else if (!strcmp(p,"e500"))
      cpu_type = CPU_TYPE_PPC | CPU_TYPE_E500 | CPU_TYPE_BOOKE | CPU_TYPE_ISEL
                 | CPU_TYPE_SPE | CPU_TYPE_EFS | CPU_TYPE_PMR | CPU_TYPE_RFMCI
                 | CPU_TYPE_32;
    else if (!strcmp(p,"booke"))
      cpu_type = CPU_TYPE_PPC | CPU_TYPE_BOOKE;
    else if (!strcmp(p,"com"))
      cpu_type = CPU_TYPE_COMMON | CPU_TYPE_32;
    else if (!strcmp(p,"any"))
      cpu_type |= CPU_TYPE_ANY;
    else
      return 0;
  }
  else if (!strcmp(p,"-no-regnamestr"))
    regnames = 0;
  else if (!strcmp(p,"-little"))
    ppc_endianess = 0;
  else if (!strcmp(p,"-big"))
    ppc_endianess = 1;
  else if (!strncmp(p,"-sdreg=",7)) {
    i = atoi(p+7);
    if (i>=0 && i<=31)
      sdreg = i;
    else
      cpu_error(13);  /* not a valid register */
  }
  else if (!strncmp(p,"-sd2reg=",8)) {
    i = atoi(p+8);
    if (i>=0 && i<=31)
      sd2reg = i;
    else
      cpu_error(13);  /* not a valid register */
  }
  else if (!strcmp(p,"-opt-branch"))
    opt_branch = 1;
  else
    return 0;

  return 1;
}
