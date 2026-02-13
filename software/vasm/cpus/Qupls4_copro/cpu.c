#include "vasm.h"

// The following generates code to support postfix immediates.
#define SUPPORT_PFX_IMM	1

// The following uses code supporting the shifted immediate instruction set.
// Where there are no immediate postfixes. It should not be defined when
// SUPPORT_PFX_IMM is defined.
//#define SUPPORT_SI_IMM 1

// The following enables code to support memory page (64kB) relative branching.
// Generally not used.
//#define BRANCH_PGREL 1

// The following enables code to use instruction block slot numbers as the low
// order four bits of a branch target. It effectively gives branch displacements
// two more bits as the instruction slot number encodes into four bits instead of
// six bits. However, it does mean that code needs to be block (64 byte)
// relative.
//#define BRANCH_INO 1

// Ordinary PC relative branches
#define BRANCH_PCREL	1
#define NREG	16

#define TRACE(x)		/*printf(x)*/
#define TRACE2(x,y)	/*printf((x),(y))*/

const char *cpu_copyright="vasm Qupls4_copro cpu backend v0.10 (c) in 2026 Robert Finch";

const char *cpuname="Qupls4_copro";
int bitsperbyte=8;
int bytespertaddr=4;
int abits=16;
static taddr sdreg = 29;
static taddr sd2reg = 60;
static taddr sd3reg = 51;
static taddr pcreg = 53;
static __int64 regmask = 0x3fLL;

static int qupls_insn_count = 0;
static int qupls_byte_count = 0;
static int qupls_padding_bytes = 0;
static int qupls_header_bytes = 0;

static insn_sizes1[20000];
static insn_sizes2[20000];
static int sz1ndx = 0;
static int sz2ndx = 0;
static short int argregs[11] = {1,2,3,4,0,0,0,0,0,0,0};
static short int tmpregs[12] = {5,6,7,8,0,0,0,0,0,0,0,0};
static short int saved_regs[16] = {9,10,11,12,13,0,0,0,0,0,0,0,0,0,0};

static char *regnames[16] = {
	"r0", "r1", "r2", "r3", "r4", "r5", "r6", "r7", 
	"r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15"
};

static int regop[16] = {
	OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, 
	OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG, OP_REG
};

mnemonic mnemonics[]={
	"add", 		{OP_REG,OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,0,OPC(22LL),4,SZ_UNSIZED},
	"add64", 	{OP_REG,OP_REG,OP_REG,OP_IMM,0,0}, {RI64,CPU_ALL,0,0,OPC(5LL),4,SZ_UNSIZED},
	"and", 		{OP_REG,OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,0,OPC(24LL),4,SZ_UNSIZED},
	"and64", 	{OP_REG,OP_REG,OP_REG,OP_IMM,0,0}, {RI64,CPU_ALL,0,0,OPC(23LL),4,SZ_UNSIZED},
	"and", 		{OP_REG,OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,0,OPC(24LL),4,SZ_UNSIZED},
	"build_entry_no", 	{OP_REG,OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,0,OPC(14LL),4,SZ_UNSIZED},
	"build_vpn", 	{OP_REG,0,0,0,0,0}, {R3,CPU_ALL,0,0,OPC(15LL),4,SZ_UNSIZED},
	"calc_adr",		{OP_REG,OP_REG,OP_REG,0,0,0}, {R3,CPU_ALL,0,0,OPC(13LL),4,SZ_UNSIZED},
	"calc_index",	{OP_REG,OP_REG,0,0,0,0}, {RI,CPU_ALL,0,0,OPC(12LL),4,SZ_UNSIZED},
	"com", 		{OP_REG,OP_REG,0,0,0,0}, {R3,CPU_ALL,0,0,0xFFFE0000LL|OPC(26LL),4,SZ_UNSIZED},
	"djne", 	{OP_REG,OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,0,COND(6LL)|OPC(4LL),4,SZ_UNSIZED,0,FLG_BRANCH},
	"djnez", 	{OP_REG,OP_IMM,0,0,0,0}, {DIRECT,CPU_ALL,0,0,COND(6LL)|OPC(4LL),4,SZ_UNSIZED,0,FLG_BRANCH},
	"jeq", 		{OP_REG,OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,0,OPC(4LL),4,SZ_UNSIZED,0,FLG_BRANCH},
	"jeqz",		{OP_REG,OP_IMM,0,0,0,0}, {DIRECT,CPU_ALL,0,0,OPC(4LL),4,SZ_UNSIZED,0,FLG_BRANCH},
	"jge", 		{OP_REG,OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,0,COND(4LL)|OPC(4LL),4,SZ_UNSIZED,0,FLG_BRANCH},
	"jgez",		{OP_REG,OP_IMM,0,0,0,0}, {DIRECT,CPU_ALL,0,0,COND(4LL)|OPC(4LL),4,SZ_UNSIZED,0,FLG_BRANCH},
	"jgep",		{OP_REG,OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,0,COND(9LL)|OPC(4LL),4,SZ_UNSIZED,0,FLG_BRANCH},
	"jgqe",		{OP_REG,OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,0,COND(10LL)|OPC(4LL),4,SZ_UNSIZED,0,FLG_BRANCH},
	"jgqne",	{OP_REG,OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,0,COND(11LL)|OPC(4LL),4,SZ_UNSIZED,0,FLG_BRANCH},
	"jgt", 		{OP_REG,OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,0,COND(5LL)|OPC(4LL),4,SZ_UNSIZED,0,FLG_BRANCH},
	"jgtz", 	{OP_REG,OP_IMM,0,0,0,0}, {DIRECT,CPU_ALL,0,0,COND(5LL)|OPC(4LL),4,SZ_UNSIZED,0,FLG_BRANCH},
	"jle", 		{OP_REG,OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,0,COND(3LL)|OPC(4LL),4,SZ_UNSIZED,0,FLG_BRANCH},
	"jlez",		{OP_REG,OP_IMM,0,0,0,0}, {DIRECT,CPU_ALL,0,0,COND(3LL)|OPC(4LL),4,SZ_UNSIZED,0,FLG_BRANCH},
	"jlep",		{OP_REG,OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,0,COND(8LL)|OPC(4LL),4,SZ_UNSIZED,0,FLG_BRANCH},
	"jlt", 		{OP_REG,OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,0,COND(2LL)|OPC(4LL),4,SZ_UNSIZED,0,FLG_BRANCH},
	"jltz",		{OP_REG,OP_IMM,0,0,0,0}, {DIRECT,CPU_ALL,0,0,COND(2LL)|OPC(4LL),4,SZ_UNSIZED,0,FLG_BRANCH},
	"jmp", 		{OP_IMM,0,0,0,0,0}, {DIRECT,CPU_ALL,0,0,OPC(9LL),4,SZ_UNSIZED},
	"jmp", 		{OP_REGIND,0,0,0,0,0}, {REGIND,CPU_ALL,0,0,OPC(9LL),4,SZ_UNSIZED},
	"jne", 		{OP_REG,OP_REG,OP_IMM,0,0,0}, {DIRECT,CPU_ALL,0,0,COND(1LL)|OPC(4LL),4,SZ_UNSIZED,0,FLG_BRANCH},
	"jnez",		{OP_REG,OP_IMM,0,0,0,0}, {DIRECT,CPU_ALL,0,0,COND(1LL)|OPC(4LL),4,SZ_UNSIZED,0,FLG_BRANCH},
	"jsr", 		{OP_IMM,0,0,0,0,0}, {DIRECT,CPU_ALL,0,0,RD(1LL)|OPC(9LL),4,SZ_UNSIZED},
	"jsr", 		{OP_IMM,0,0,0,0,0}, {REGIND,CPU_ALL,0,0,RD(1LL)|OPC(9LL),4,SZ_UNSIZED},
	"load", 	{OP_REG,OP_IMM,0,0,0,0}, {DIRECT,CPU_ALL,0,0,OPC(16LL),4,SZ_UNSIZED},
	"load", 	{OP_REG,OP_REGIND,0,0,0,0}, {REGIND,CPU_ALL,0,0,OPC(16LL),4,SZ_UNSIZED},
	"load_config", 	{OP_IMM,0,0,0,0,0}, {RI,CPU_ALL,0,0,OPC(3LL),4,SZ_UNSIZED},
	"load_config", 	{OP_REG,0,0,0,0,0}, {R3,CPU_ALL,0,0,OPC(3LL),4,SZ_UNSIZED},
	"load_config", 	{OP_REG,OP_IMM,0,0,0,0}, {RI,CPU_ALL,0,0,OPC(3LL),4,SZ_UNSIZED},
	"loada", 	{OP_REG,OP_IMM,0,0,0,0}, {DIRECT,CPU_ALL,0,0,OPC(22LL),4,SZ_UNSIZED},
	"loada", 	{OP_REG,OP_REGIND,0,0,0,0}, {REGIND,CPU_ALL,0,0,OPC(22LL),4,SZ_UNSIZED},
	"loada64", 	{OP_REG,OP_IMM,0,0,0,0}, {DIRECT,CPU_ALL,0,0,OPC(5LL),4,SZ_UNSIZED},
	"loada64",	{OP_REG,OP_REGIND,0,0,0,0}, {REGIND,CPU_ALL,0,0,OPC(5LL),4,SZ_UNSIZED},
	"loadi", 	{OP_REG,OP_IMM,0,0,0,0}, {RI,CPU_ALL,0,0,OPC(22LL),4,SZ_UNSIZED},
	"loadi64",{OP_REG,OP_IMM,0,0,0,0}, {RI64,CPU_ALL,0,0,OPC(5LL),4,SZ_UNSIZED},
	"mov", 		{OP_REG,OP_REG,OP_REG,0,0,0}, {R3,CPU_ALL,0,0,OPC(22LL),4,SZ_UNSIZED},
	"move",		{OP_REG,OP_REG,OP_REG,0,0,0}, {R3,CPU_ALL,0,0,OPC(22LL),4,SZ_UNSIZED},
	"nop",		{0,0,0,0,0,0}, {BITS16,CPU_ALL,0,0,0x0LL,4, SZ_UNSIZED, 0},
	"or", 		{OP_REG,OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,0,OPC(25LL),4,SZ_UNSIZED},
	"ret", 		{OP_IMM,0,0,0,0,0}, {RI,CPU_ALL,0,0,RD(2LL)|OPC(9LL),4,SZ_UNSIZED},
	"shl", 		{OP_REG,OP_REG,OP_REG,0,0,0}, {R3,CPU_ALL,0,0,OPC(20LL),4,SZ_UNSIZED},
	"shl", 		{OP_REG,OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,0,OPC(20LL),4,SZ_UNSIZED},
	"shl", 		{OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,0,OPC(20LL),4,SZ_UNSIZED},
	"shr", 		{OP_REG,OP_REG,OP_REG,0,0,0}, {R3,CPU_ALL,0,0,OPC(21LL),4,SZ_UNSIZED},
	"shr", 		{OP_REG,OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,0,OPC(21LL),4,SZ_UNSIZED},
	"shr", 		{OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,0,OPC(21LL),4,SZ_UNSIZED},
	"sll", 		{OP_REG,OP_REG,OP_REG,0,0,0}, {R3,CPU_ALL,0,0,OPC(20LL),4,SZ_UNSIZED},
	"sll", 		{OP_REG,OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,0,OPC(20LL),4,SZ_UNSIZED},
	"sll", 		{OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,0,OPC(20LL),4,SZ_UNSIZED},
	"srl", 		{OP_REG,OP_REG,OP_REG,0,0,0}, {R3,CPU_ALL,0,0,OPC(21LL),4,SZ_UNSIZED},
	"srl", 		{OP_REG,OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,0,OPC(21LL),4,SZ_UNSIZED},
	"srl", 		{OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,0,OPC(21LL),4,SZ_UNSIZED},
	"store", 	{OP_REG,OP_IMM,0,0,0,0}, {DIRECT,CPU_ALL,0,0,OPC(17LL),4,SZ_UNSIZED,0,FLG_STORE},
	"store", 	{OP_REG,OP_REGIND,0,0,0,0}, {REGIND,CPU_ALL,0,0,OPC(17LL),4,SZ_UNSIZED,0,FLG_STORE},
	"storei",	{OP_IMM,OP_IMM,0,0,0,0}, {STOREI,CPU_ALL,0,0,OPC(18LL),4,SZ_UNSIZED,0,FLG_STORE},
	"storei",	{OP_IMM,OP_REGIND,0,0,0,0}, {STOREI,CPU_ALL,0,0,OPC(18LL),4,SZ_UNSIZED,0,FLG_STORE},
	"wait", 	{OP_REG,OP_IMM,0,0,0,0}, {WAIT,CPU_ALL,0,0,WCOND(10LL)|OPC(1LL),4,SZ_UNSIZED},
	"waitgep",{OP_REG,OP_REG,OP_REG,OP_REGIND_DISP,0,0}, {WAIT,CPU_ALL,0,0,WCOND(9LL)|OPC(1LL),4,SZ_UNSIZED},
	"xor", 		{OP_REG,OP_REG,OP_REG,OP_IMM,0,0}, {RI,CPU_ALL,0,0,OPC(26LL),4,SZ_UNSIZED}
};

static unsigned char* encode_pfx(unsigned char *d, postfix_buf* pfx, uint8_t which);
static void encode_cpfx(instruction_buf* insn, int64_t val);

const int mnemonic_cnt = sizeof(mnemonics)/sizeof(mnemonics[0]);

int set_default_qualifiers(char **q,int *q_len)
{
	TRACE("setdq ");
  q_len[0] = 0;
  return (1);
}

int qupls_data_operand(int n)
{
  if (n&OPSZ_FLOAT) return OPSZ_BITS(n)>64?OP_F128:OPSZ_BITS(n)>32?OP_F64:OP_F32;
  if (OPSZ_BITS(n)<=8) return OP_D8;
  if (OPSZ_BITS(n)<=16) return OP_D16;
  if (OPSZ_BITS(n)<=32) return OP_D32;
  if (OPSZ_BITS(n)<=64) return OP_D64;
  return OP_D128;
}

/* parse instruction and save extension locations */
char *parse_instruction(char *s,int *inst_len,char **ext,int *ext_len,
                        int *ext_cnt)
{
  char *inst = s;

	TRACE("pi ");
  while (*s && *s!='.' && !isspace((unsigned char)*s))
    s++;
  *inst_len = s - inst;
//  printf("inslen: %d\n", *inst_len);
  return (s);
}

static int huge_chkrange2(thuge h,int bits)
{
  uint64_t v,mask;

  if (bits >= HUGEBITS)
    return 1;

  if (bits >= HUGEBITS/2) {
    mask = ~0LL << (bits - HUGEBITS/2);
    v = h.hi & mask;
    return (v & (1LL << (bits - HUGEBITS/2))) ? (v ^ mask) == 0 : v == 0;
  }    

  mask = ~0LL << bits;
  v = h.lo & mask;
  if (v & (1LL << bits))
    return h.hi == ~0 && (v ^ mask) == 0;
  return h.hi == 0 && v == 0;
}



/* check if a given value fits within a certain number of bits */
static int is_nbit(thuge val, int n)
{
	thuge low, high;
	return (huge_chkrange2(val, n));
  if (n > 95LL)
    return (1);
  low = hneg(hshl(huge_from_int(1LL), n-1LL));
  high = hshl(huge_from_int(1LL), n-1LL);
	return (hcmp(val,low) >= 0 && hcmp(val,high) < 0);
}
/*
static int is_nbit(thuge val, int64_t n)
{
	int r1, r2;
	thuge low, high;
//  if (n > 63)
//    return (1);
	low.lo = 1;
	low.hi = 0;
	low = hshl(low,(n-1LL));
	high = low;
	low = tsub(huge_zero(),low);
	low = -(1LL << (n - 1LL));
	high = (1LL << (n - 1LL));
	r1 = hcmp(val, low);
	r2 = hcmp(val, high);
	return (r1 >= 0 && r2 < 0);
}
*/
static int is_identchar(unsigned char ch)
{
	return (isalnum(ch) || ch == '_');
}

/* parse a general purpose register, r0 to r31 */
static int is_reg(char *p, char **ep)
{
	int rg = -1;
	int sgn = 0;
	int n = 0;

	TRACE("is_reg ");
	*ep = p;
	if (p[n]!='%')
		return(-1);
	n++;
	/* IP */
	if ((p[n]=='i' || p[n]=='I') && (p[n+1]=='p' || p[n+1]=='P') && !ISIDCHAR((unsigned char)p[n+2])) {
		*ep = &p[n+2];
		return (53);
	}
	/* FP */
	if ((p[n]=='f' || p[n]=='F') && (p[n+1]=='p' || p[n+1]=='P') && !ISIDCHAR((unsigned char)p[n+2])) {
		*ep = &p[n+2];
		return (15);
	}
	/* GP */
	if ((p[n]=='g' || p[n]=='G') && (p[n+1]=='p' || p[n+1]=='P') && !ISIDCHAR((unsigned char)p[n+2])) {
		*ep = &p[n+2];
		return (14);
	}
	/* Argument registers 0 to 7 */
	if (p[n] == 'a' || p[n]=='A') {
		if (isdigit((unsigned char)p[n+1]) && !ISIDCHAR((unsigned char)p[n+2])) {
			rg = p[n+1]-'0';
			rg = argregs[rg];	
			*ep = &p[n+2];
			return (rg);
		}
	}
	/* Temporary registers 0 to 8 */
	if (p[n] == 't' || p[n]=='T') {
		if (isdigit((unsigned char)p[n+1]) && !ISIDCHAR((unsigned char)p[n+2])) {
			rg = p[n+1]-'0';
			rg = tmpregs[rg];
			*ep = &p[n+2];
			return (rg);
		}
	}
	if (p[n] == 't' || p[n]=='T') {
		if (isdigit((unsigned char)p[n+1]) && isdigit((unsigned char)p[n+2]) && !ISIDCHAR((unsigned char)p[n+3])) {
			rg = (p[n+1]-'0') * 10 + p[n+2]-'0';	
			if (rg < 9) {
				rg = tmpregs[rg];
				*ep = &p[n+3];
				return (rg);
			}
		}
	}
	/* Register vars 0 to 8 */
	if (p[n] == 's' || p[n]=='S') {
		if (isdigit((unsigned char)p[n+1]) && !ISIDCHAR((unsigned char)p[n+2])) {
			rg = p[n+1]-'0';	
			rg = saved_regs[rg];
			*ep = &p[n+2];
			return (rg);
		}
	}
	if (p[n] == 's' || p[n]=='S') {
		if (isdigit((unsigned char)p[n+1]) && isdigit((unsigned char)p[n+2]) && !ISIDCHAR((unsigned char)p[n+3])) {
			rg = (p[n+1]-'0') * 10 + p[n+2]-'0';	
			if (rg < 9) {
				rg = saved_regs[rg];
				*ep = &p[n+3];
				return (rg);
			}
		}
	}
	if (p[n] != 'r' && p[n] != 'R') {
		return (-1);
	}
	if (isdigit((unsigned char)p[n+1]) && isdigit((unsigned char)p[n+2]) && isdigit((unsigned char)p[n+3]) && !ISIDCHAR((unsigned char)p[n+4])) {
		rg = (p[n+2]-'0') * 100 + (p[n+1]-'0')*10 + p[n+2]-'0';
		if (rg < 256) {
			*ep = &p[n+4];
			return (rg);
		}
		return (-1);
	}
	if (isdigit((unsigned char)p[n+1]) && isdigit((unsigned char)p[n+2]) && !ISIDCHAR((unsigned char)p[n+3])) {
		rg = (p[n+1]-'0')*10 + p[n+2]-'0';
		if (rg < 100) {
			*ep = &p[n+3];
			return (rg);
		}
		return (-1);
	}
	if (isdigit((unsigned char)p[n+1]) && !ISIDCHAR((unsigned char)p[n+2])) {
		rg = p[n+1]-'0';
		*ep = &p[n+2];
		return (rg);
	}
	return (-1);
}

static int is_branch(mnemonic* mnemo)
{
	switch(mnemo->ext.format) {
	case B:
	case BI:
	case BZ:
	case BL:
	case B2:
	case BL2:
	case J2:
	case JL2:
	case J3:
	case JL3:
	case J4:
	case JL4:
	case J:
		return (1);
	}
	return (0);	
}

static char *parse_reloc_attr(char *p,operand *op)
{
	TRACE("prs_rel_attr");
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
    if (chk!=REL_NONE && chk!=op->attr)
      cpu_error(7);  /* multiple relocation attributes */
  }

  return p;
}

// Parses the indexing for memory operand:
//	lw Rt,d[Ra]

static char *parse_idx(char* p,operand* op, int* match)
{
	int rg, rg2, nrg, nrg2;
	int dmm;
	char *pp = p;

	TRACE("pndx ");
	if (match)
		*match = 0;	
	if ((rg = is_reg(p, &p)) >= 0) {
		op->basereg = rg >= 0 ? rg : 0;
		p = skip(p);
		op->scale = 0;
		op->ndxreg = 0;
		op->type = OP_REGIND;
		if (match)
			*match = pp!=p;
	}
	return (p);
}

int parse_operand(char *p,int len,operand *op,int optype)
{
	int rg, nrg, rg2, nrg2;
	int rv = PO_NOMATCH;
	char ch;
	int dmm,mtch;

	TRACE("PO ");
	op->attr = REL_NONE;
	op->mask = 0xffffffffffffffffLL;

  if (!OP_DATAM(optype)) {
    p = parse_reloc_attr(p,op);

		if (optype==OP_NEXTREG) {
	    op->type = OP_REG;
	    op->basereg = 0;
	    op->value = number_expr((taddr)0);
			return (PO_NEXT);
		}
		if (optype==OP_NEXT) {
	    op->value = number_expr((taddr)0);
			return (PO_NEXT);
		}

	  p=skip(p);
	  if ((rg = is_reg(p, &p)) >= 0) {
	    op->type=OP_REG;
	    op->basereg=rg;
	    op->value = number_expr((taddr)rg);
	  }
	  else if(p[0]=='#'){
	    op->type=OP_IMM;
	    p=skip(p+1);
	    op->value=parse_expr(&p);
	  }
	  else if(p[0]=='<'){
	    op->type=OP_IMM;
	    p=skip(p+1);
	    op->value=parse_expr(&p);
	    op->mask = 0xfffffLL;
	  }
	  else if(p[0]=='?'){
	    op->type=OP_IMM;
	    p=skip(p+1);
	    op->value=parse_expr(&p);
	    op->mask = 0xffffff00000LL;
	  }
	  else if(p[0]=='>'){
	    op->type=OP_IMM;
	    p=skip(p+1);
	    op->value=parse_expr(&p);
	    op->mask = 0xfffff00000000000LL;
	  }
	  else if(p[0]=='$'){
	    op->type=OP_IMM;
	    p=skip(p+1);
	    op->value=parse_expr(&p);
			op->mask = 0xffffffffffffffffLL;
	  }
	  else{
	    int parent=0;
	    expr *tree;
	    op->type=-1;
	    if (*p == '[') {
	    	tree = number_expr((taddr)0);
	    	op->type = OP_REGIND;
	    }
	    else {
	    	tree=parse_expr(&p);
	    	while (is_identchar(*p)) p++;
	    	op->type = OP_REGIND_DISP;
	    }
	    if(!tree)
	      return (PO_NOMATCH);
	   	op->type = OP_IMM;
	    if(*p=='['){
	      parent=1;
	      p=skip(p+1);
	    }
	    p=skip(p);
	    if(parent){
	    	p = parse_idx(p, op, &mtch);
	    	if (!mtch) {
		    	tree=parse_expr(&p);
				  p = parse_reloc_attr(p,op);
	    		if (*p=='[') {
			      p=skip(p+1);
	    			p = parse_idx(p, op, &mtch);
	    			if (mtch) {
	    				op->type = OP_IND_SCNDX;
	    			}
			      if(*p!=']'){
							cpu_error(5);
							return (0);
						}
			      p=skip(p+1);
	    		}
	    	}
	      if(*p!=']'){
					cpu_error(5);
					return (0);
	      }
	      else
					p=skip(p+1);
	    }
	    op->value=tree;
	  }
		TRACE("p");
  	if(optype & op->type) {
    	return (PO_MATCH);
  	}
	}
	else {
	  op->value = OP_FLOAT(optype) ? parse_expr_float(&p) : parse_expr(&p);
		op->type = optype;
		return (PO_MATCH);
	}
  return (PO_NOMATCH);
}

operand *new_operand()
{
	TRACE("newo ");
  operand *nw=mymalloc(sizeof(*nw));
  nw->type=-1;
  return (nw);
}

static void fix_reloctype(dblock *db,int rtype)
{
  rlist *rl;

	TRACE("fixrel ");
  for (rl=db->relocs; rl!=NULL; rl=rl->next)
    rl->type = rtype;
}


static int get_reloc_type(operand *op)
{
  int rtype = REL_NONE;

	TRACE("grel ");
  if (OP_DATAM(op->type)) {  /* data relocs */
    return (REL_ABS);
  }

  else {  /* handle instruction relocs */
  	switch(op->format) {

		case J:
 			rtype = REL_ABS;
			break;
  	
  	/* BEQ r1,r2,target */
  	case B:
  	case BI:
  		if (op->number==0) {
  			rtype = REL_ABS;
  			break;
  		}
  		if (op->number==1) {
  			rtype = REL_ABS;
  			break;
  		}
 			rtype = REL_PC;
      break;

		/* BEQZ r2,.target */
		/* BRA	LR1,target */
  	case BZ:
  	case BL2:
	    if (op->number==0)
	    	rtype = REL_NONE;
	    else
 				rtype = REL_PC;
      break;

		/* BRA target */		
  	case B2:
    	rtype = REL_PC;
      break;
  		
		/* JMP target */
    case J2:
    	rtype = op->attr;
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
      break;

    default:
      switch (op->attr) {
        case REL_NONE:
          rtype = REL_ABS;
          break;
        case REL_GOT:
        case REL_PLT:
        case REL_SD:
          rtype = op->attr;
          break;
        default:
          cpu_error(11); /* reloc attribute not supported by operand */
          break;
      }
  	}
  }
  return (rtype);
}

/* Compute branch target field value using one of three different
  methods.
*/
static thuge calc_branch_disp(thuge val, taddr pc, int opt)
{
	uint64_t ino;
	uint64_t pg_offs;
	thuge pcx2;
	thuge valx2;

#ifdef BRANCH_PGREL        	
	ino = (val.lo & 0x3fLL) >> 2LL;
	pg_offs = ((val.lo >> 6LL) & 0x3ffLL;
	val.lo &= 0xffffffffffff0000LL;
	val = hsub(val,huge_from_int(pc & 0xffffffffffff0000LL));
	val = hshr(val,2);
	val.lo &= 0xffffffffffffc000LL;
	val.lo |= ino;
	val.lo |= pg_offs << 4LL;
#endif
#ifdef BRANCH_INO
	ino = (val.lo & 0x3fLL) >> 2LL;
	val.lo &= 0xffffffffffffffc0LL;
	val = hsub(val,huge_from_int(pc & 0xffffffffffffffc0LL));
	val = hshr(val,2);
	val.lo &= 0xfffffffffffffff0LL;
	val.lo |= ino;
#endif
#ifdef BRANCH_PCREL
/*
	valx2 = hmul(val,huge_from_int(2LL));
	pcx2 = hmul(huge_from_int(pc),huge_from_int(2LL));
	val = hsub(valx2,pcx2);
	if (opt)
		val = hdiv(val,huge_from_int(9LL));
	else
		val = hdiv(val,huge_from_int(2LL));
*/
	val = hsub(val,huge_from_int(pc));
	if (opt)
		val = hdiv(val,huge_from_int(2LL));
#endif
	return (val);
}

/* create a reloc-entry when operand contains a non-constant expression */
static thuge make_reloc(int reloctype,operand *op,section *sec,
                        taddr pc,rlist **reloclist, int *constexpr)
{
  thuge val;
  thuge shl64;
	uint64_t ino;
	char pc_is_odd = pc & 1LL;

	TRACE("M ");
	*constexpr = 1;
	val.lo = val.hi = 0LL;
  if (!eval_expr(op->value,&val.lo,sec,pc)) {
	  if (val.lo & 0x8000000000000000LL)
	  	val.hi = 0xFFFFFFFFFFFFFFFFLL;
//  if (!eval_expr_huge(op->value,&val)) {
  	*constexpr = 0;
    /* non-constant expression requires a relocation entry */
    symbol *base;
    int btype,pos,size,disp;
    thuge addend;
    taddr mask;

		base = NULL;
    btype = find_base(op->value,&base,sec,pc);
    pos = disp = 0;

    if (btype > BASE_ILLEGAL) {
      if (btype == BASE_PCREL) {
        if (reloctype == REL_ABS)
          reloctype = REL_PC;
        else
          goto illreloc;
      }

      if ((reloctype == REL_PC) && !is_pc_reloc(base,sec)) {
        /* a relative branch - reloc is only needed for external reference */
				TRACE("m");
				switch(op->format) {
				case BI:
					if (op->number > 1) {
			 			val = calc_branch_disp(val, pc, 4);
						return (val);
					}
					break;
				case BZ:
				case B:
		 			val = calc_branch_disp(val, pc, 0);
					return (val);
				case B2:
				case BL2:
		 			val = calc_branch_disp(val, pc, 0);
					return (val);
				}
      }

			eval_expr(op->value,&val.lo,sec,pc);
		  if (val.lo & 0x8000000000000000LL)
		  	val.hi = 0xFFFFFFFFFFFFFFFFLL;

      /* determine reloc size, offset and mask */
      if (OP_DATAM(op->type)) {  /* data operand */
        switch (op->type) {
          case OP_D8:
            size = 8;
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
          case OP_D128:
          case OP_F128:
            size = 128;
            break;
          default:
            ierror(0);
            break;
        }
        reloctype = REL_ABS;
        addend = val;
        mask = -1;
      		add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
                           pos,size,disp,mask);
      }
      else {  /* instruction operand */
      	if (op->format != B2 && op->format != BL2)
        	addend = (btype == BASE_PCREL) ? hadd(val, huge_from_int(disp)) : val;
        else
        	addend = val;
      	switch(op->format) {
      	case J:
		      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
                         17,15,0,0x1fffcLL);
      		break;
      	case B:
      	case BZ:
      	case BI:	/* ToDo: fix for branch to external, REL_QUPLS_BRANCH */
		      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
                         8,32,5,0xffffffffLL);
      		if (!is_nbit(addend,32)) {
			      add_extnreloc_masked(reloclist,base,addend.lo>>32LL,reloctype,
                         8,32,10,0xffffffffLL);
      			
      		}
      		break;
      	case B2:
      	case BL2:
	      	add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
                         13,35,0,0xffffffffeLL);
          break;
      	/* Unconditional jump */
        case J2:
		      add_extnreloc_masked(reloclist,base,val.lo,reloctype,
                           17,15,0,0x7fffLL);
          break;
          
        case J4:
		      add_extnreloc_masked(reloclist,base,val.lo,reloctype,
                           13,35,0,0xffffffffeLL);
          break;
				/* Short conditional jump */
      	case J3:
		      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
                           9,5,0,0x3eLL);
		      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
                           19,13,0,0x7ffc0LL);
          break;

        case RI:
	      	add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
                        17,15,0,0x7fffLL);
        	break;

        case WAIT:
	      	add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
                        21,11,0,0x1ffcLL);
        	break;

        case RI64:
	      	add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
                        0,64,4,0xffffffffffffffffLL);
        	break;

        case DIRECT:
	      	add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
                        17,15,0,0x1ffffcLL);
          // Assume a postfix is present.
        	break;

				case STOREI:
        case REGIND:
        	if (op->basereg==sdreg)
        		reloctype = REL_SD;
	      	add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
                      17,15,0,0x1fffcLL);
        	break;

        default:
        		/* relocation of address as data */
			      add_extnreloc_masked(reloclist,base,addend.lo,reloctype,
                          0,64,0,0xffffffffffffffffLL);
					;
      	}
      }
    }
/*
    else if (btype != BASE_NONE) {
    }
*/
  }
  else {
  	val.lo = val.hi = 0;
	  eval_expr(op->value,&val.lo,sec,pc);
	  if (val.lo & 0x8000000000000000LL)
	  	val.hi = 0xFFFFFFFFFFFFFFFFLL;
//		eval_expr_huge(op->value,&val);
		switch(op->format) {
		case BI:
			if (op->number > 1) {
	 			val = calc_branch_disp(val, pc, 4);
				return (val);
			}
			break;
		case BZ:
			if (op->number==1)
 				val = calc_branch_disp(val, pc, 0);
			return (val);
		case B:
			if (op->number==2)
 				val = calc_branch_disp(val, pc, 0);
			return (val);
		case B2:
		case BL2:
 			val = calc_branch_disp(val, pc, 0);
			return (val);
		}
  }

	TRACE("m");
  return (val);
illreloc:
  general_error(38);  /* illegal relocation */
  return (val);
}


static void encode_reg(instruction_buf* insn, operand *op, mnemonic* mnemo, int i)
{
	TRACE("enr ");
	if (insn) {
		switch(mnemo->ext.format) {
		case PRED:
			insn->opcode = insn->opcode | RS1(op->basereg);
			break;

		case R2:
			if (i==0)
				insn->opcode |= RD(op->basereg);
			else if (i==1)
				insn->opcode |= RS1(op->basereg);
			else if (i==2)
				insn->opcode |= RS2(op->basereg);
			break;

		case R3:
			if (i==0)
				insn->opcode |= RD(op->basereg);
			else if (i==1)
				insn->opcode |= RS1(op->basereg);
			else if (i==2)
				insn->opcode |= RS2(op->basereg);
			break;

		case RI64:
		case RI:
			if (i==0)
				insn->opcode |= RD(op->basereg);
			else if (i==1)
				insn->opcode = insn->opcode | RS1(op->basereg);
			else if (i==2)
				insn->opcode = insn->opcode | RS2(op->basereg);
			break;
		case WAIT:
			if (i==0)
				insn->opcode |= RS1(op->basereg);
			else if (i==1)
				insn->opcode = insn->opcode | RS2(op->basereg);
			break;

		case STOREI:
		case REGIND:
			if (i==0) {
				if (mnemo->ext.flags & FLG_STORE)
					insn->opcode |= RS2(op->basereg);
				else
					insn->opcode |= RD(op->basereg);
			}
			else if (i==1)
				insn->opcode = insn->opcode | RS1(op->basereg);
			else if (i==2)
				insn->opcode = insn->opcode | RS2(op->basereg);
			break;

		case DIRECT:
			if (i==0) {
				if (mnemo->ext.flags & FLG_STORE)
					insn->opcode |= RS2(op->basereg);
				else if (mnemo->ext.flags & FLG_BRANCH)
					insn->opcode |= RS1(op->basereg);
				else
					insn->opcode |= RD(op->basereg);
			}
			else if (i==1) {
				if (mnemo->ext.flags & FLG_STORE)
					insn->opcode |= RS1(op->basereg);
				else if (mnemo->ext.flags & FLG_BRANCH)
					insn->opcode |= RS2(op->basereg);
			}
			break;
		}				
	}
}

// Encode a typical root opcode immediate mode
// ADDI Rt,Ra,$12345678

static size_t encode_immed_RI(instruction_buf* insn, thuge hval, int i, taddr pc, section* sec, instruction *ip)
{
  mnemonic *mnemo = &mnemonics[ip->code];
	size_t isize = insn->opcode_size;
	int64_t sc;
	int64_t reg = (insn->opcode >> 7LL) & 0x3fLL;
	int is_s = 0;

//	if ((insn->opcode & 0x3FLL)==0x4LL)
//		printf("In: opcode:%I64x, Prc=%I64d\r\n", insn->opcode, (insn->opcode>>22LL) & 3LL);

	if (hval.lo & 0x8000000000000000LL)
		hval.hi = 0xffffffffffffffffLL;

	if (i==0) {
		if (insn) {
			insn->pfxb.size = 0;
//			insn->opcodeH = 0;
			if (mnemo->ext.flags & FLG_LSDISP) {
				insn->opcode = insn->opcode | ((hval.lo & 0x7fffLL) << 17LL);
			}
			else {
				insn->opcode = insn->opcode | ((hval.lo & 0x7fffLL) << 17LL);
			}
		}
	}
	else if (i==1) {
		if (insn) {
			insn->pfxb.size = 0;
//			insn->opcodeH = 0;
			if (mnemo->ext.flags & FLG_LSDISP) {
				insn->opcode = insn->opcode | ((hval.lo & 0x7fffLL) << 17LL);
			}
			else {
				insn->opcode = insn->opcode | ((hval.lo & 0x7fffLL) << 17LL);
			}
		}
	}
	else if (i==2) {
		if (insn) {
			insn->pfxb.size = 0;
//			insn->opcodeH = 0;
			if (mnemo->ext.flags & FLG_LSDISP) {
				insn->opcode = insn->opcode | ((hval.lo & 0x7fffLL) << 17LL);
			}
			else {
				insn->opcode = insn->opcode | ((hval.lo & 0x7fffLL) << 17LL);
			}
		}
	}
	else if (i==3) {
		if (insn) {
			insn->pfxb.size = 0;
//			insn->opcodeH = 0;
			if (mnemo->ext.flags & FLG_LSDISP) {
				insn->opcode = insn->opcode | ((hval.lo & 0x7fffLL) << 17LL);
			}
			else {
				insn->opcode = insn->opcode | ((hval.lo & 0x7fffLL) << 17LL);
			}
		}
	}
	/*
	if (((insn->opcode >> 2LL) & 0x3FLL)==0x4LL) {
		printf("opcode:%I64x, Prc=%I64d\r\n", (insn->opcode >> 2LL) & 0x7fLL, (insn->opcode>>23LL) & 3LL);
		printf("opcode:%I64x, opcodeH=%I32d\r\n", insn->opcode, insn->opcodeH);
		printf("hval.lo=%I64x hval.hi=%I64x\n", hval.lo, hval.hi);
	}
	*/
	return (isize);
}

static size_t encode_immed_WAIT(instruction_buf* insn, thuge hval, int i, taddr pc, section* sec, instruction *ip)
{
  mnemonic *mnemo = &mnemonics[ip->code];
	size_t isize = insn->opcode_size;
	int64_t sc;
	int64_t reg = (insn->opcode >> 7LL) & 0x3fLL;
	int is_s = 0;

//	if ((insn->opcode & 0x3FLL)==0x4LL)
//		printf("In: opcode:%I64x, Prc=%I64d\r\n", insn->opcode, (insn->opcode>>22LL) & 3LL);

	if (hval.lo & 0x8000000000000000LL)
		hval.hi = 0xffffffffffffffffLL;

	if (i==0) {
		if (insn) {
			insn->pfxb.size = 0;
//			insn->opcodeH = 0;
			if (mnemo->ext.flags & FLG_LSDISP) {
				insn->opcode = insn->opcode | ((hval.lo & 0xeffLL) << 21LL);
			}
			else {
				insn->opcode = insn->opcode | ((hval.lo & 0xeffLL) << 21LL);
			}
		}
	}
	else if (i==1) {
		if (insn) {
			insn->pfxb.size = 0;
//			insn->opcodeH = 0;
			if (mnemo->ext.flags & FLG_LSDISP) {
				insn->opcode = insn->opcode | ((hval.lo & 0xeffLL) << 21LL);
			}
			else {
				insn->opcode = insn->opcode | ((hval.lo & 0xeffLL) << 21LL);
			}
		}
	}
	else if (i==2) {
		if (insn) {
			insn->pfxb.size = 0;
//			insn->opcodeH = 0;
			if (mnemo->ext.flags & FLG_LSDISP) {
				insn->opcode = insn->opcode | ((hval.lo & 0xeffLL) << 21LL);
			}
			else {
				insn->opcode = insn->opcode | ((hval.lo & 0xeffLL) << 21LL);
			}
		}
	}
	/*
	if (((insn->opcode >> 2LL) & 0x3FLL)==0x4LL) {
		printf("opcode:%I64x, Prc=%I64d\r\n", (insn->opcode >> 2LL) & 0x7fLL, (insn->opcode>>23LL) & 3LL);
		printf("opcode:%I64x, opcodeH=%I32d\r\n", insn->opcode, insn->opcodeH);
		printf("hval.lo=%I64x hval.hi=%I64x\n", hval.lo, hval.hi);
	}
	*/
	return (isize);
}

static size_t encode_immed_RI64(instruction_buf* insn, thuge hval, int i, taddr pc, section* sec, instruction *ip)
{
  mnemonic *mnemo = &mnemonics[ip->code];
	size_t isize = insn->opcode_size;

//	if ((insn->opcode & 0x3FLL)==0x4LL)
//		printf("In: opcode:%I64x, Prc=%I64d\r\n", insn->opcode, (insn->opcode>>22LL) & 3LL);

	if (hval.lo & 0x8000000000000000LL)
		hval.hi = 0xffffffffffffffffLL;

	if (i==1) {
		if (insn) {
			insn->pfx1v = 1;
			insn->pfx1 = hval.lo;
			insn->pfxb.size = 0;
		}
	}
	else if (i==2) {
		if (insn) {
			insn->pfxb.size = 0;
//			insn->opcodeH = 0;
			insn->pfx1v = 1;
			insn->pfx1 = hval.lo;
		}
	}
	else if (i==3) {
		if (insn) {
			insn->pfxb.size = 0;
//			insn->opcodeH = 0;
			insn->pfx1v = 1;
			insn->pfx1 = hval.lo;
		}
	}
	/*
	if (((insn->opcode >> 2LL) & 0x3FLL)==0x4LL) {
		printf("opcode:%I64x, Prc=%I64d\r\n", (insn->opcode >> 2LL) & 0x7fLL, (insn->opcode>>23LL) & 3LL);
		printf("opcode:%I64x, opcodeH=%I32d\r\n", insn->opcode, insn->opcodeH);
		printf("hval.lo=%I64x hval.hi=%I64x\n", hval.lo, hval.hi);
	}
	*/
	return (isize);
}
// Encode a direct address for a load / store
// LDB Rt,1234

static size_t encode_direct(instruction* ip, instruction_buf* insn, thuge val, int i)
{
	size_t isize = insn->opcode_size;
  mnemonic *mnemo = &mnemonics[ip->code];

	TRACE("endir ");
	insn->opcode = insn->opcode | (((val.lo) & 0x7fffLL) << 17LL);
	return (isize);
}

static size_t encode_immed_LDI(instruction_buf* insn, thuge hval, int i)
{
	size_t isize = 4;
	int minbits = 32LL;

	if (insn) {
		insn->opcode = insn->opcode | ((hval.lo & 0x7fffLL) << 17LL);
	}
	if (i==1) {
		if (insn) {
			insn->opcode = insn->opcode | ((hval.lo & 0x7fffLL) << 17LL);
		}
	}
	return (isize);
}

static size_t encode_immed (
	instruction_buf* insn, mnemonic* mnemo,
	operand *op, thuge hval, int constexpr, int i, char vector,
	taddr pc, section* sec, instruction* ip)
{
	size_t isize = 4;
	thuge val;

	TRACE("enimm ");
	/*
	if (mnemo->ext.format==PFX) {
		encode_ipfx(insn->postfix, hval, i);
		*pfxsize = 4;
		if (insn) *insn = *insn |	((hval.lo  & 0x7fffffLL) << 8LL);
		return (isize);
	}
	*/
//	hval.lo &= op->mask;

//	if (hval.hi & 0x80000000LL)
//		hval.hi |= 0xFFFFFFFF00000000LL;

	if (mnemo->ext.flags & FLG_NEGIMM) {
		if (mnemo->ext.flags & FLG_FP)
			hval.hi ^= 0x8000000000000000LL;
		else
			hval = hneg(hval);	/* ToDo: check here for value overflow */
	}

	val = hval;
	if (constexpr) {
		switch(mnemo->ext.format) {
		case STOREI:
			if (i==0) {
				if (is_nbit(hval,4)) {
					insn->opcode = insn->opcode | RD(val.lo);
					isize = 4;
				}
				else {
					isize = encode_immed_RI64(insn, val, i, pc, sec, ip);
					insn->opcode = (insn->opcode & 0xffffffe0LL) | 6LL;
				}
			}
			else if (i==1) {
				isize = encode_immed_RI(insn, val, i, pc, sec, ip);
			}
			return (isize);
		case REGIND:
			if (i==0)
				isize = encode_immed_RI(insn, val, i, pc, sec, ip);
			return (isize);
		case RI:
			isize = encode_immed_RI(insn, val, i, pc, sec, ip);
			return (isize);
		case WAIT:
			isize = encode_immed_WAIT(insn, val, i, pc, sec, ip);
			return (isize);
		case RI64:
			isize = encode_immed_RI64(insn, val, i, pc, sec, ip);
			return (isize);
		default:
		if (mnemo->ext.format==LDI) {
			isize = encode_immed_LDI(insn, val, i);
		}
		else if (mnemo->ext.format==DIRECT) {
			isize = encode_direct(ip, insn, hval, i);
		}
		else if (mnemo->ext.format==R2) {
			if (insn) {
				insn->opcode = insn->opcode | RS2(val.lo);
			}
		}
		else if (mnemo->ext.format==R3) {
			if (i==2) {
				if (insn)
					insn->opcode = insn->opcode | RS2(val.lo);
			}
		}
		else if (mnemo->ext.format==J2) {
			if (insn)
				insn->opcode = insn->opcode | (((val.lo) & 0x7fffLL) << 17LL);
		}
		else {
			if (insn)
				insn->opcode = insn->opcode | ((val.lo & 0xffLL) << 23LL) | (((val.lo >> 8LL) & 0x7fLL) << 33LL);
		}
	}
	}
	else {
		if (mnemo->ext.format==DIRECT) {
			isize = encode_direct(ip, insn, hval, i);
		}
		else if (mnemo->ext.format==J2) {
			if (insn)
				insn->opcode = insn->opcode | ((val.lo & 0x7fffLL) << 17LL);
		}
		else if (mnemo->ext.format==J4) {
			if (insn)
				insn->opcode = insn->opcode | (((val.lo >> 1LL) & 0x7ffffffffLL) << 13LL);
		}
		else if (mnemo->ext.format==R2) {
			if (insn)
				insn->opcode = insn->opcode | RS2(val.lo);
		}
		else if (mnemo->ext.format==RI) {
			isize = encode_immed_RI(insn, val, i, pc, sec, ip);
			return(isize);
		}
		else if (mnemo->ext.format==WAIT) {
			isize = encode_immed_WAIT(insn, val, i, pc, sec, ip);
			return(isize);
		}
		else if (mnemo->ext.format==RI64) {
			isize = encode_immed_RI64(insn, val, i, pc, sec, ip);
			return(isize);
		}
		else if (mnemo->ext.format==LDI) {
			isize = encode_immed_LDI(insn, val, i);
		}
		else {
			if (op->type & OP_IMM) {
				if (!is_nbit(val,15LL))
					goto j2;
				if (insn)
					insn->opcode = insn->opcode | ((val.lo & 0x7fffLL) << 17LL);
				return (isize);
			}
			else {
j2:
				if (insn)
					insn->opcode = insn->opcode | ((val.lo & 0xffLL) << 8LL);
			}
		}
	}
	return (isize);
}

/* Encode conditional branch. */

/* The value passed into encode_branch_B is pre-cooked for ordinary relative
   branches, or split target branches using an instruction block number and
   block relative displacement. These have been calculated by
   encode_qupls_instruction.
   Registers are already encoded by a generic function, what's left to encode
   is constant values.
*/
static size_t encode_branch_B(instruction_buf* insn, operand* op, int64_t val, int i, unsigned int flags)
{
	uint64_t tgt;
	thuge hg;
	size_t isize = 4;
	int opcode = (insn->opcode & 0x1fLL);
	
	if (op->type == OP_IMM) {
		switch(i) {
		case 1:
	  	if (flags & FLG_BZ) {
  			insn->opcode |= ((val & 0x7fffLL) << 17LL);
	  	}
	  	else {
  			insn->opcode |= ((val & 0x7fffLL) << 17LL);
			}
			break;

			/* For BRANCH_INO the target field is split in two, one containing the
			   instruction slot number, 4 bits, and a second field containing the
			   block relative displacement. The value is already composed properly.
			*/
#ifdef BRANCH_PGREL
		case 2:
	  	if (insn) {
  			tgt = (((val & 0x1fffLL) >> 1LL) << 25LL);
  			insn->opcode |= tgt;
				tgt = ((pc + val) >> 13LL) & 0x3ffLL;
  			insn->opcode |= (tgt << 38LL);
			}
			break;
#endif
#ifdef BRANCH_INO
		case 2:
	  	if (insn) {
  			tgt = (((val & 0x1fff0LL) >> 4LL) << 27LL);
  			insn->opcode |= tgt;
  			tgt = ((val & 3LL) << 11LL);
  			insn->opcode |= tgt;
  			tgt = (((val & 0xfLL) >> 2LL) << 25LL);
  			insn->opcode |= tgt;
			}
			break;
#endif
#ifdef BRANCH_PCREL		
		case 2:
	  	if (insn) {
				// BNEZ / BEQZ shortcuts have a maximum of nine-bits displacement
				// If displacement is too large convert to larger branch format
  			insn->opcode |= ((val & 0x7fffLL) << 17LL);
  		}
			break;
#endif			
		}
	}
	return (isize);
}

/* Encode uncondional branch, has wider target field. 
*/

static size_t encode_branch_BL2(instruction_buf* insn, operand* op, int64_t val, int i)
{
	uint64_t tgt;
	size_t isize = insn->opcode_size;
	thuge hval;

	hval.lo = val;
	if (val < 0)
		hval.hi = 0xffffffffffffffffLL;
	else
		hval.hi = 0LL;
	if (op->type == OP_IMM) {
		if (insn) {
			switch(i) {
			case 1:
  			tgt = ((0x7fffLL) << 17LL);
  			insn->opcode |= tgt;
		  	break;
			}
		}
	}
	return (isize);
}

static int encode_J2(instruction_buf* insn, operand* op, int64_t val, int i, int* isize)
{
	thuge hg;
	*isize = 6;

	hg = huge_from_int(val);
  if (op->type==OP_IMM) {
  	if (insn) {
  		uint64_t tgt;
  		//*insn |= CA(mnemo->ext.format==B2 ? 0x7 : 0x0);
    	//tgt = ((val & 0xffffffLL) << 24LL) | (2LL << 22LL);
 			tgt = (((val >> 2LL) & 0x7fffLL) << 17LL);
  		insn->opcode |= tgt;
  	}
  	return (1);
	}
  if (op->type==OP_REGIND) {
  	if (insn) {
  		uint64_t tgt;
  		insn->opcode |= RS1(op->basereg);
    	tgt = (((val >> 2LL) & 0x7fffLL) << 17LL);
  		insn->opcode |= tgt;
  	}
  	return (1);
  }
  return (0);
}

/* Evaluate branch operands excepting GPRs which are handled earlier.
	Returns 1 if the branch was processed, 0 if illegal branch format.
*/
static int encode_branch(instruction_buf* insn, mnemonic* mnemo, operand* op, int64_t val, int* isize, int i)
{
	uint64_t tgt;
	*isize = 4;

	TRACE("encb:");
	switch(mnemo->ext.format) {

	case J:
		*isize = encode_branch_B(insn, op, val, i, mnemo->ext.flags);
  	return (1);

  }
  TRACE("ebv0:");
  return (0);
}

static size_t encode_regind(
	instruction *ip,
	instruction_buf* insn,
	operand* op,
	thuge val,
	int constexpr,
	int i,
	int pass
)
{
	size_t isize = insn->opcode_size;

	TRACE("Etho5:");
	if (insn) {
		if (isize==3) {
			if (i==0)
				insn->opcode |= RD(op->basereg);
			else if (i==1) {
				insn->opcode |= RS1(op->basereg);
				if (val.lo != 0LL)
					isize = encode_direct(ip, insn, val, (int)1);
			}
		}
		else {
			if (i==0)
				insn->opcode |= RD(op->basereg);
			else if (i==1) {
				insn->opcode |= RS1(op->basereg);
				if (val.lo != 0LL)
					isize = encode_direct(ip, insn, val, (int)1);
			}
		}
	}
	return (isize);
}

static size_t encode_regind_disp(
	instruction *ip,
	instruction_buf* insn,
	operand* op,
	thuge val,
	int constexpr,
	int i,
	int pass
)
{
	size_t isize = insn->opcode_size;

	TRACE("Etho5:");

	if (pass)
		ip->ext.const_expr = constexpr;
	if (insn) {
		if (i==0)
			insn->opcode |= RD(op->basereg);
		else if (i==1) {
			insn->opcode |= RS1(op->basereg);
			isize = encode_direct(ip, insn, val, (int)1);
		}
	}
	
	/*
	if ((constexpr && pass==1) || ip->ext.const_expr) {
		if (op->value || val.lo != 0LL || val.hi != 0LL) {
			encode_ipfx(&insn->pfxb,val,1);
		}
	}
	else {
		if (op->value)
			encode_ipfx(&insn->pfxb,val,1);
	}
	*/
	return (isize);
}

/* Create additional operand for split target branches. Needed for either
	 memory page relative addressing or instruction block relative addressing.
*/

static void create_split_target_operands(instruction* ip, mnemonic* mnemo)
{
	return;
	/* dead code */
	switch(mnemo->ext.format) {
	case B:
	case BI:
		TRACE("Fmtb:");
		if (ip->op[2]) {
			ip->op[3] = new_operand();
			memcpy(ip->op[3], ip->op[2], sizeof(operand));
			ip->op[3]->number = 3;
			ip->op[3]->attr = REL_PC;
			ip->op[3]->value = copy_tree(ip->op[2]->value);
		}
		break;
	case BZ:
	case BL2:
		TRACE("Fmtb:");
		if (ip->op[1]) {
			ip->op[2] = new_operand();
			memcpy(ip->op[2], ip->op[1], sizeof(operand));
			ip->op[2]->number = 2;
			ip->op[2]->attr = REL_PC;
			ip->op[2]->value = copy_tree(ip->op[1]->value);
		}
		break;
	case B2:
		TRACE("Fmtb:");
		if (ip->op[0]) {
			ip->op[1] = new_operand();
			memcpy(ip->op[1], ip->op[0], sizeof(operand));
			ip->op[1]->number = 1;
			ip->op[1]->attr = REL_PC;
			ip->op[1]->value = copy_tree(ip->op[0]->value);
		}
		break;
	}
}

/* Detect if the target operand of a branch is being processed.
*/
static int is_branch_target_oper(mnemonic *mnemo, int i, int* opt)
{
	if (!is_branch(mnemo))
		return (0);
	if (opt==NULL)
		return (0);
	*opt = 0;
	switch(mnemo->ext.format) {
	case J:
		*opt = 0;
		return (i==2 || i==3);
	}
	return (0);
}

// Return 1 if the instruction has a 64-bit constant following, otherwise
// return 0.

static int has_const64(uint64_t opcode)
{
	switch(opcode & 0x1fLL) {
	case 5:		return (1);	// ADD64
	case 6:		return (1);	// STOREI64
	case 23:	return (1);	// AND64
	default:	return (0);
	}
}

/* evaluate expressions and try to optimize instruction,
   return size of instruction 

   Since the instruction may contain a modifier which varies in size, both the
   size of the instruction and the size of the modifier is returned. The size
   of the instruction is in the return value, the size of the 
   modifier is passed back in the modifier constant. The total size may be 
   calculated using a simple shift and sum.
*/
size_t encode_qupls_instruction(instruction *ip,section *sec,taddr pc,
  uint64_t *modifier1, uint64_t *modifier2, instruction_buf* insn, dblock *db)
{
  mnemonic *mnemo = &mnemonics[ip->code];
  size_t isize = 4;
  static taddr prev_pc = 0;
  int i;
  operand op;
	int constexpr;
	int reg = 0;
	char vector_insn = 0;
	char has_vector_mask = mnemo->ext.flags & FLG_MASK;
	thuge op1val, wval;
	int ext;
	uint64_t szcode;
	int setsz = 0;
	int called_makereloc = 0;
	int bropt = 0;
	int64_t prc = 0;

	TRACE("Eto:");
	if (modifier1)
		*modifier1 = 0;
	if (modifier2)
		*modifier2 = 0;

//  ext = ip->qualifiers[0] ?
//             tolower((unsigned char)ip->qualifiers[0][0]) : '\0';
//  szcode = 
//	  ((mnemo->ext.size) == SZ_UNSIZED) ?
//    0 : lc_ext_to_size(ext) < 0 ? mnemo->ext.defsize : lc_ext_to_size(ext);

	//isize = mnemo->ext.len;
	/*
  if (insn != NULL) {
    *insn = mnemo->ext.opcode;
    *insn |= SZ(szcode);
   }
	*/
	memset(insn,0,sizeof(instruction_buf));

	isize = mnemo->ext.len;
  if (insn != NULL) {
  	insn->opcode_size = mnemo->ext.len;
    insn->opcode = mnemo->ext.opcode;
//    insn->opcodeH = mnemo->ext.opcodeH;
  	insn->short_opcode = mnemo->ext.short_opcode;
  }

//	if (((insn->opcode >> 2LL) &0x3fLL)==0x4LL)
//		printf("enc: opcode=%I64x, prc=%I64d\r\n", (insn->opcode>>2LL) & 0x7fLL, (insn->opcode>> 22LL) & 3LL);
//	encode_qualifiers(ip, insn);


	if (modifier1)
		*modifier1 = 0;

	/* Create additional operand for split target branches */
#ifdef BRANCH_PGREL
	create_split_target_operands(ip, mnemo);
#endif
#ifdef BRANCH_INO
	create_split_target_operands(ip, mnemo);
#else
	create_split_target_operands(ip, mnemo);
#endif

  for (i=0; i<MAX_OPERANDS && ip->op[i]!=NULL; i++) {
    operand *pop;
    int reloctype;
    taddr hval;
    thuge val;

		TRACE("F");
    op = *(ip->op[i]);	/* convenience */
    /* reflect the format back into the operand */
    ip->op[i]->number = i;
    op.number = i;
    op.format = mnemo->ext.format;
    if (insn)
    	op.isize = insn->opcode_size;
    else 
    	op.isize = 4;
    
    /* special case: operand omitted and use this operand's type + 1
         for the next operand */
    /*
    if (op.type == NEXT) {
      op = *(ip->op[++i]);
      op.type = mnemo->operand_type[i-1] + 1;
    }
	*/
		constexpr = 1;
		called_makereloc = 0;
    if ((reloctype = get_reloc_type(&op)) != REL_NONE) {
      if (db != NULL) {
        val = make_reloc(reloctype,&op,sec,pc,&db->relocs,&constexpr);
        called_makereloc = 1;
      }
      else {
      	val.lo = val.hi = 0;
        if (!eval_expr(op.value,&val.lo,sec,pc)) {
        	if (val.lo & 0x8000000000000000LL)
        		val.hi = 0xFFFFFFFFFFFFFFFFLL;
        	if (is_branch_target_oper(mnemo, i, &bropt))
        	{
	          if (reloctype == REL_PC)
	          	val = calc_branch_disp(val, pc, bropt);
		 			}
        }
        else {
        	if (val.lo & 0x8000000000000000LL)
        		val.hi = 0xFFFFFFFFFFFFFFFFLL;
        }
      }
    }
    else {
//      if (!eval_expr(op.value,&val,sec,pc))
      if (!eval_expr(op.value,&val.lo,sec,pc)) {
      	if (val.lo & 0x8000000000000000LL)
      		val.hi = 0xFFFFFFFFFFFFFFFFLL;
        if (insn != NULL) {
/*	    	printf("***A4 val:%lld****", val);
          cpu_error(2);  */ /* constant integer expression required */
        }
      }
    }
  	if (is_branch_target_oper(mnemo, i, &bropt)) {
//						eval_expr_huge(op.value,&val);
			//val = hsub(val,huge_from_int(pc));
      if (reloctype == REL_PC && !called_makereloc)
      	val = calc_branch_disp(val, pc, bropt);
//			val = hsub(wval,huge_from_int(pc));
		}

		if (i==1) {
			op1val = val;
		}

		TRACE("Ethof:");
    if (db!=NULL && op.type==OP_REGIND && op.attr==REL_NONE) {
			TRACE("Ethof1:");
      if (op.basereg == sdreg) {  /* is it a small data reference? */
				TRACE("Ethof3:");
        fix_reloctype(db,REL_SD);
/*        else if (reg == sd2reg)*/  /* EABI small data 2 */
/*          fix_reloctype(db,REL_PPCEABI_SDA2); */
			}
    }

		TRACE("Etho2:");
		if (op.type==OP_REG || op.type==OP_VREG) {
			encode_reg(insn, &op, mnemo, i);
		}
		else if (mnemo->operand_type[i]==OP_REG) {
			if (insn) {
 				switch(mnemo->ext.format) {
 				case JL3:
 				case BL:
 				case RTS:
 					if (i==0)
 						insn->opcode = insn->opcode | RS1(op.basereg);
 					break;
 				case JSCNDX:
 				case JL2:
 				case JL4:
 				case BL2:
 					if (i==0)
 						insn->opcode = insn->opcode | RD(op.basereg);
 					break;
				default:
 					cpu_error(18);
				}				
			}
		}
		/*
    else if ((mnemo->operand_type[i]&OP_IMM7) && op.type==OP_IMM) {
 			if (!is_nbit(val, 7)) {
 				cpu_error(12,val,-64,64);
 			}
 			if (insn) {
 				switch(mnemo->ext.format) {
 				case R2:
 					if (i==2)
 						*insn = *insn| (TB(2|((val>>6) & 1))) | (RB(val & 0x3f));
 					break;
 				case R3:
 					if (i==2)
 						*insn = *insn| (TB(2|((val>>6) & 1))) | (RB(val & 0x3f));
 					else if (i==3)
 						*insn = *insn| (TC(2|((val>>6) & 1))) | (RC(val & 0x3f));
 					break;
 				case BL:
 					if (i==2)
 						*insn = *insn| (TB(2|((val>>6) & 1))) | (RB(val & 0x3f));
 					break;
 				case B:
 				}
 			}
    }
    */
    else if (((mnemo->operand_type[i])&OP_IMM) && (op.type==OP_IMM) && !is_branch(mnemo)) {
			TRACE("Etho3:");
			isize = encode_immed(insn, mnemo, &op, val, constexpr, i, vector_insn, pc, sec, ip);
			/*
			printf("pfx1=%I64x",insn->pfx1);
			printf("pfx2=%I64x",insn->pfx2);
			printf("pfx3=%I64x",insn->pfx3);
			printf("pfx4=%I64x",insn->pfx4);
			*/
    }
    else if (encode_branch(insn, mnemo, &op, val.lo, &isize, i)) {
    	/*
			printf("pfx1=%I64x",insn->pfx1);
			printf("pfx2=%I64x",insn->pfx2);
			printf("pfx3=%I64x",insn->pfx3);
			printf("pfx4=%I64x",insn->pfx4);
			*/
			TRACE("Etho4:");
  		;
  	}
    else if ((mnemo->operand_type[i]&OP_REGIND)==OP_REGIND && op.type==OP_REGIND)
			isize = encode_regind(ip, insn, &op, val, constexpr, i, db==NULL);
    else if ((mnemo->operand_type[i]&OP_REGIND_DISP)==OP_REGIND_DISP && op.type==OP_REGIND_DISP)
			isize = encode_regind_disp(ip, insn, &op, val, constexpr, i, db==NULL);
	}
	
	// See if a subtract from SP??
	TRACE("G");
//	encode_size_bits(insn, isize);
	// Adjust the instruction to be aligned at an odd address.
	if (has_const64(insn->opcode & 0x1fLL)) {
		if (!(pc & 4)) {
			isize += 4;
			insn->opcode_size = 8;
			insn->opcode = insn->opcode << 32LL;
			// low order opcode is zero for a NOP
		}
	}
	return (isize);
}

/* Calculate the size of the current instruction; must be identical
   to the data created by eval_instruction. */
size_t instruction_size(instruction *ip,section *sec,taddr pc)
{
  mnemonic *mnemo = &mnemonics[ip->code];
  uint64_t modifier1, modifier2;
  instruction_buf insn;
	taddr apc;

	TRACE("is "); 
	modifier1 = 0;
	modifier2 = 0;
	size_t sz = 0;

	memset(&insn,0,sizeof(insn));
	sz = encode_qupls_instruction(ip,sec,pc,&modifier1,&modifier2,&insn,NULL);
	sz = sz + (modifier1 >> 48LL) + (modifier2 >> 48LL);
	if (insn.pfx1v) sz = sz + 8;
	insn_sizes1[sz1ndx++] = sz;
	TRACE2("isize=%d ", sz);
  return (sz);
}

static unsigned char* encode_pfx(unsigned char *d, postfix_buf* pfx, uint8_t which)
{
	thuge val = pfx->val;
	int size = pfx->size;
	uint64_t op;

	op = val.lo;
	switch(size) {
	case 8:
    d = setval(0,d,8LL,op);
    qupls_insn_count++;
		break;
	default:
		printf("unsupported postfix size.\n");
	}
	return (d);
}

/* Convert an instruction into a DATA atom including relocations,
   when necessary. */
dblock *eval_instruction(instruction *ip,section *sec,taddr pc)
{
  mnemonic *mnemo = &mnemonics[ip->code];
  dblock *db = new_dblock();
  uint64_t modifier1, modifier2, pfxndx;
  int64_t opcodeH;
  instruction_buf insn;
  size_t sz, pfxsize, szd, szop;
  size_t final_sz;
  size_t to_allocate;
  int bytes_remaining;
	// Trailer val records the position of the last instruction in the cache
	// line (instruction block).
  static int trailer_val = 0;
  taddr pcd, npc, last_pc;
  char* trailer = NULL;
	static int icnt = 0;
	static int grpcnt = 0;
	static taddr prev_pc = 0;
	static uint64_t prev_insn;
	int will_fit = 1;
	int has_imm = 0;
	int pc_wrapped = 0;
	int block_changed = 0;

	TRACE("ei ");
	modifier1 = 0;
	modifier2 = 0;
	memset(&insn,0,sizeof(insn));
	sz = encode_qupls_instruction(ip,sec,pc,&modifier1,&modifier2,&insn,NULL);
	if (insn.pfx1v) sz = sz + 8;

	final_sz = sz;
  if (db) {
    uint8_t *d;
    unsigned char *d2;
    int i;

		d = db->data = mymalloc(sz);
		db->size = sz;
		memset(&insn,0,sizeof(insn));
		encode_qupls_instruction(ip,sec,pc,&modifier1,&modifier2,&insn,db);
		insn_sizes2[sz2ndx] = db->size;

		// Output the code bytes.
   	d = setval(0,d,(int64_t)4LL,insn.opcode);
   	if (insn.opcode >> 32LL)
	   	d = setval(0,d,(int64_t)4LL,insn.opcode >> 32LL);
		if (insn.pfx1v)
    	d = setval(0,d,(int64_t)8LL,insn.pfx1);
    
   	qupls_insn_count++;
	  /* Debugging
		while (db->size < insn_sizes1[sz2ndx]) {
	    d = setval(0,d,8,0x9fLL);	// NOP
	    db->size += 8;
	    insn_count++;
		}	
		*/
		sz2ndx++;
    qupls_byte_count += db->size;	/* and more stats */
  }
  return (db);
}


/* Create a dblock (with relocs, if necessary) for size bits of data. */
dblock *eval_data(operand *op,size_t bitsize,section *sec,taddr pc)
{
  dblock *db = new_dblock();
  thuge val;
  tfloat flt;
  int constexpr = 1;

	TRACE("ed ");
  if ((bitsize & 7) || bitsize > 64)
    cpu_error(9,bitsize);  /* data size not supported */
  /*
	if (!OP_DATAM(op->type))
  	ierror(0);
	*/
  db->size = bitsize >> 3;
  db->data = mymalloc(db->size);

  if (type_of_expr(op->value) == FLT) {
    if (!eval_expr_float(op->value,&flt))
      general_error(60);  /* cannot evaluate floating point */
/*
    switch (bitsize) {
      case 32:
        conv2ieee32(0,db->data,flt);
        break;
      case 64:
        conv2ieee64(0,db->data,flt);
        break;
      default:
        cpu_error(10);
        break;
    }
*/
  }
  else {
    val = make_reloc(get_reloc_type(op),op,sec,pc,&db->relocs,&constexpr);

    switch (db->size) {
      case 1:
        db->data[0] = val.lo & 0xff;
        break;
      case 2:
      case 4:
      case 8:
        setval(0,db->data,db->size,val.lo);
        break;
      default:
        ierror(0);
        break;
    }
  }

  return (db);
}

/* To be inserted at the end of main() for debugging */

void at_end()
{
	int lmt = sz1ndx > sz2ndx ? sz2ndx : sz1ndx;
	int ndx;

	printf("Instructions: %d\n", qupls_insn_count);
	printf("Bytes: %d\n", qupls_byte_count);
	printf("Padding Bytes: %d\n", qupls_padding_bytes);
	printf("Header bytes: %d\n", qupls_header_bytes);
	printf("%f bytes per instruction\n", (double)(qupls_byte_count)/(double)(qupls_insn_count));
	/*
	for (ndx = 0; ndx < lmt; ndx++) {
		printf("%csz1=%d, sz2=%d\n", insn_sizes1[ndx]!=insn_sizes2[ndx] ? '*' : ' ', insn_sizes1[ndx], insn_sizes2[ndx]);
	}
	*/
}
/* return true, if initialization was successfull */
int init_cpu()
{
	TRACE("icpu ");
	qupls_insn_count = 0;
	qupls_byte_count = 0;
	qupls_padding_bytes = 0;
	qupls_header_bytes = 0;
	atexit(at_end);
  return (1);
}

/* return true, if the passed argument is understood */
int cpu_args(char *p)
{
//	atexit(at_end);
  abits = 32;
  if (strncmp(p, "-abits=", 7)==0) {
  	abits = atoi(&p[7]);
  	if (abits < 16)
  		abits = 16;
  	else if (abits > 64)
  		abits = 64;
  	return (1);
  }
  return (0);
}

static taddr read_sdreg(char **s,taddr def)
{
  expr *tree;
  taddr val = def;

	TRACE("rdsd ");
  *s = skip(*s);
  tree = parse_expr(s);
  simplify_expr(tree);
  if (tree->type==NUM && tree->c.val>=0 && tree->c.val<=63)
    val = tree->c.val;
  else
    cpu_error(13);  /* not a valid register */
  free_expr(tree);
  return val;
}


/* parse cpu-specific directives; return pointer to end of
   cpu-specific text */
char *parse_cpu_special(char *start)
{
	TRACE("pcs ");
  char *name=start,*s=start;

  if (ISIDSTART(*s)) {
    s++;
    while (ISIDCHAR(*s))
      s++;
    if (s-name==6 && !strncmp(name,".sdreg",6)) {
      sdreg = read_sdreg(&s,sdreg);
      return s;
    }
    else if (s-name==7 && !strncmp(name,".sd2reg",7)) {
      sd2reg = read_sdreg(&s,sd2reg);
      return s;
    }
    else if (s-name==7 && !strncmp(name,".sd3reg",7)) {
      sd3reg = read_sdreg(&s,sd3reg);
      return s;
    }
  }
  return start;
}

void init_instruction_ext(instruction_ext *ext)
{
	TRACE("iie ");
	if (ext) {
		ext->size = 0;
		ext->postfix_count = 0;
		ext->const_expr = 0;
	}
}