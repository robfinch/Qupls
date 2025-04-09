extern uint8_t value_bucketno;
extern value_bucket_t value_bucket[32];
extern uint16_t totsz;
extern uint32_t count32, count64;

/* Operand description structure */
struct powerpc_operand
{
  int bits;
  int shift;
  uint32_t (*insert)(uint32_t,int64_t,const char **);
  uint32_t flags;
};

/* powerpc_operand flags */
#define OPER_SIGNED   (1)        /* signed values */
#define OPER_SIGNOPT  (2)        /* signed values up to 0xffff */
#define OPER_FAKE     (4)        /* just reuse last read operand */
#define OPER_PARENS   (8)        /* operand is in parentheses */
#define OPER_CR       (0x10)     /* CR field */
#define OPER_GPR      (0x20)     /* GPR field */
#define OPER_FPR      (0x40)     /* FPR field */
#define OPER_RELATIVE (0x80)     /* relative branch displacement */
#define OPER_ABSOLUTE (0x100)    /* absolute branch address */
#define OPER_OPTIONAL (0x200)    /* optional, zero if omitted */
#define OPER_NEXT     (0x400)    /* hack for rotate instructions */
#define OPER_NEGATIVE (0x800)    /* range check on negative value */
#define OPER_VR       (0x1000)   /* Altivec register field */
#define OPER_U14			(0x2000)
#define OPER_S14			(0x4000)
#define OPER_BR				(0x8000)	/* branch register */
#define OPER_MPC			(0x10000)
#define OPER_CB				(0x20000)
#define OPER_SCNDX		(0x40000)	/* scaled indexed addressing mode */
#define OPER_XH				(0x80000)
#define OPER_DISP			(0x100000)
#define OPER_REGLIST	(0x200000)
#define OPER_REG			(0x40000000)

/* Operand types. */
enum {
  UNUSED,BA,CSRUI,BB,BBA,BD,BS,BDA,BDM,BDMA,BDP,BDPA,BF,OBF,BFA,BI,BO,BOE,CRS,CSRNO,
  BT,CR,D,DS,DX,E,FL1,FL2,FLM,FRA,FRB,FRC,FRS,FXM,L,LEV,LI,LIA,MB,ME,XH,BR,BRS,RL,
  MBE,MBE_,MB6,NB,NSI,RA,RAL,RAM,RAS,RB,RC,RBS,RS,SH,SH6,SI,SISIGNOPT,PM,BLR,BLRL,LMT,
  SPR,SPRBAT,SPRG,SR,SV,TBR,TO,U,UI,VA,VB,VC,VD,SIMM,UIMM,SHB,SCNDX,/*JA,JAB,JOM,JSWS,*/
  SLWI,SRWI,EXTLWI,EXTRWI,EXTWIB,INSLWI,INSRWI,ROTRWI,CLRRWI,CLRLSL,DBRS,
  STRM,AT,LS,RSOPT,RAOPT,RBOPT,CT,SHO,CRFS,EVUIMM_2,EVUIMM_4,EVUIMM_8,
  MOVRD,MOVRS
};

#define FRT FRS
#define ME6 MB6
#define RT RS
#define RTOPT RSOPT
#define VS VD
#define CRB MB
#define PMR SPR
#define TMR SPR
#define CRFD BF
#define EVUIMM SH

#define NEXT (-1)  /* use operand_type+1 for next operand */


/* The functions used to insert complex operands. */

static int is_int5(int64_t value)
{
	return (value >= -16LL && value < 16LL);
}

static int is_uint10(uint64_t value)
{
	return (value < 1024LL);
}

static int is_int10(int64_t value)
{
	return (value >= -512LL && value < 512LL);
}

static int is_uint14(uint64_t value)
{
	return (value < 16384LL);
}

static int is_int14(int64_t value)
{
	return (value >= -8192LL && value < 8192LL);
}

static int is_int13(int64_t value)
{
	return (value >= -4096LL && value < 4096LL);
}

static int is_uint16(uint64_t value)
{
	return (value < 65536LL);
}

static int is_int16(int64_t value)
{
	return (value >= -32768LL && value < 32768LL);
}

static int is_int25(int64_t value)
{
	return (value >= -16777216LL && value < 16777216LL);
}

static int is_int32(int64_t value)
{
	return (value >= -2147483648LL && value < 2147483648LL);
}

static int is_uint32(uint64_t value)
{
	return (value < 4294967296LL);
}

/* The functions used to insert complex operands. */

static uint32_t insert_ui(uint32_t insn,int64_t value,const char ** errmsg)
{
	int i;

	if (value >= 0 && is_uint14((uint64_t)value)) {
		insn |= (value & 0x3fffL) << 17L;
		return (insn);
	}
	/*
	if (value >= 0 && is_uint16((uint32_t)value)) {
		insn |= 0xA0000000L;
		value_bucket[value_bucketno].insn = insn;
		value_bucket[value_bucketno].value = value;
		value_bucket[value_bucketno].size = 16;
		totsz += 2;
		value_bucketno++;
		if (totsz > 23*4)
	    *errmsg = "too many value encountered";
	  return (insn);
	}
	*/
#if 0
	for (i = 0; i < value_bucketno; i++) {
		if (value_bucket[i].value == value) {
			insn |= ((i & 0x7) << 18);
			return (insn);
		}
	}	
#endif
	if (value >= 0 && is_uint32((uint64_t)value)) {
		insn |= 0x20000000L;
		value_bucket[value_bucketno].insn = insn;
		value_bucket[value_bucketno].value = value;
		value_bucket[value_bucketno].size = 32;
		insn |= ((value_bucketno & 0x7) << 18);
		totsz += 4;
		value_bucketno++;
		count32++;
	}
	else {
		insn |= 0x40000000L;
		value_bucket[value_bucketno].insn = insn;
		value_bucket[value_bucketno].value = value;
		value_bucket[value_bucketno].size = 64;
		insn |= ((value_bucketno & 0x7) << 18);
		totsz += 8;
		value_bucketno++;
		count64++;
	}
	if (totsz > 7*4)
    *errmsg = "too many value encountered";
  return (insn);
}

static uint32_t insert_blr(uint32_t insn,int64_t value,const char ** errmsg)
{
	int i;

	/*
	if (is_int16(value)) {
		insn |= 0xA0000000L;
		value_bucket[value_bucketno].insn = insn;
		value_bucket[value_bucketno].value = value;
		value_bucket[value_bucketno].size = 16;
		totsz += 2;
		value_bucketno++;
		if (totsz > 23*4)
	    *errmsg = "too many value encountered";
	  return (insn);
	}
	*/
#if 0	
	for (i = 0; i < value_bucketno; i++) {
		if (value_bucket[i].value == value) {
			insn |= ((i & 0x7) << 10);
			return (insn);
		}
	}	
#endif
	if (is_int32(value)) {
		insn |= 0x20000000L;
		value_bucket[value_bucketno].insn = insn;
		value_bucket[value_bucketno].value = value;
		value_bucket[value_bucketno].size = 32;
		insn |= ((value_bucketno & 0x7) << 10);
		totsz += 4;
		value_bucketno++;
		count32++;
	}
	else {
		insn |= 0x40000000L;
		value_bucket[value_bucketno].insn = insn;
		value_bucket[value_bucketno].value = value;
		value_bucket[value_bucketno].size = 64;
		insn |= ((value_bucketno & 0x7) << 10);
		totsz += 8;
		value_bucketno++;
		count64++;
	}
	if (totsz > 7*4)
    *errmsg = "too many value encountered";
  return (insn);
}

static uint32_t insert_si(uint32_t insn,int64_t value,const char ** errmsg)
{
	int i;

	if (is_int14(value)) {
		insn |= (value & 0x3fffL) << 17L;
		return (insn);
	}
	/*
	if (is_int16(value)) {
		insn |= 0xA0000000L;
		value_bucket[value_bucketno].insn = insn;
		value_bucket[value_bucketno].value = value;
		value_bucket[value_bucketno].size = 16;
		totsz += 2;
		value_bucketno++;
		if (totsz > 23*4)
	    *errmsg = "too many value encountered";
	  return (insn);
	}
	*/
#if 0
	for (i = 0; i < value_bucketno; i++) {
		if (value_bucket[i].value == value) {
			insn |= ((i & 0x7) << 18);
			return (insn);
		}
	}	
#endif
	if (is_int32(value)) {
		insn |= 0x20000000L;
		value_bucket[value_bucketno].insn = insn;
		value_bucket[value_bucketno].value = value;
		value_bucket[value_bucketno].size = 32;
		insn |= ((value_bucketno & 0x7) << 18);
		totsz += 4;
		value_bucketno++;
		count32++;
	}
	else {
		insn |= 0x40000000L;
		value_bucket[value_bucketno].insn = insn;
		value_bucket[value_bucketno].value = value;
		value_bucket[value_bucketno].size = 64;
		insn |= ((value_bucketno & 0x7) << 18);
		totsz += 8;
		value_bucketno++;
		count64++;
	}
	if (totsz > 7*4)
    *errmsg = "too many value encountered";
  return (insn);
}

static uint32_t insert_xsi(uint32_t insn,int64_t value,const char ** errmsg)
{
	int i;

	insn |= 0x80000000L;
	if (value != 0)
		*errmsg = "AMO ops cannot have a displacement";
	/*
	for (i = 0; i < value_bucketno; i++) {
		if (value_bucket[i].value == value) {
			insn |= ((value_bucketno & 0x7) << 18);
			return (insn);
		}
	}	
	value_bucket[value_bucketno].insn = insn;
	value_bucket[value_bucketno].value = value;
	value_bucket[value_bucketno].size = 32;
	totsz += 4;
	value_bucketno++;
	if (totsz > 23*4)
    *errmsg = "too many value encountered";
   */
  return (insn);
}

static uint32_t insert_csrui(uint32_t insn,int64_t value,const char **errmsg)
{
	if (value >= 0 && is_uint32(value)) {
		insn |= 0x20000000L;
		value_bucket[value_bucketno].insn = insn;
		value_bucket[value_bucketno].value = value;
		value_bucket[value_bucketno].size = 32;
		insn |= ((value_bucketno & 0x7) << 11);
		totsz += 4;
		value_bucketno++;
		count32++;
	}
	else {
		insn |= 0x40000000L;
		value_bucket[value_bucketno].insn = insn;
		value_bucket[value_bucketno].value = value;
		value_bucket[value_bucketno].size = 64;
		insn |= ((value_bucketno & 0x7) << 11);
		totsz += 8;
		value_bucketno++;
		count64++;
	}
	if (totsz > 7*4)
    *errmsg = "too many value encountered";
  return (insn);
}

static uint32_t insert_bba(uint32_t insn,int64_t value,const char **errmsg)
{
  return insn | (((insn >> 16) & 0x1f) << 11);
}

static uint32_t insert_bd(uint32_t insn,int64_t value,const char **errmsg)
{
	int i;

	if (is_int13(value)) {
		insn |= (value >> 2) & 1;
		insn |= ((value >> 3) & 0xff) << 6;
		insn |= ((value >> 11) << 29);
	  return (insn);
	}
#if 0
	for (i = 0; i < value_bucketno; i++) {
		if (value_bucket[i].value == value) {
			insn |= ((i & 0x7) << 10);
			return (insn);
		}
	}	
#endif
	if (is_int32(value)) {
		insn |= 0x20000000L;
		value_bucket[value_bucketno].insn = insn;
		value_bucket[value_bucketno].value = value;
		value_bucket[value_bucketno].size = 32;
		insn |= ((value_bucketno & 0x7) << 10);
		totsz += 4;
		value_bucketno++;
		count32++;
	}
	else {
		insn |= 0x40000000L;
		value_bucket[value_bucketno].insn = insn;
		value_bucket[value_bucketno].value = value;
		value_bucket[value_bucketno].size = 64;
		insn |= ((value_bucketno & 0x7) << 10);
		totsz += 8;
		value_bucketno++;
		count64++;
	}
	if (totsz > 7*4)
    *errmsg = "too many value encountered";
  return (insn);
}

#if 0
static uint32_t insert_ja(uint32_t insn,int64_t value,const char **errmsg)
{
	insn |= ((value >> 3) & 0x3fffff << 9) | ((value >> 2) & 1);
	return (insn);
}

static uint32_t insert_jom(uint32_t insn,int64_t value,const char **errmsg)
{
	if (value < 0 || value > 7)
		*errmsg = "illegal operating mode";
	insn |= value << 10;
	return (insn);
}

static uint32_t insert_jsws(uint32_t insn,int64_t value,const char **errmsg)
{
	if (value < 0 || value > 7)
		*errmsg = "illegal software stack";
	insn |= value << 6;
	return (insn);
}

static uint32_t insert_jab(uint32_t insn,int64_t value,const char **errmsg)
{
	insn |= ((value >> 25) << 14) | 0x3f;	// 3f = NOP
	return (insn);
}
#endif

static uint32_t insert_bdm(uint32_t insn,int64_t value,const char **errmsg)
{
  if ((value & 0x8000) != 0)
    insn |= 1 << 21;
  return insn | (value & 0xfffc);
}

static uint32_t insert_bdp(uint32_t insn,int64_t value,const char **errmsg)
{
  if ((value & 0x8000) == 0)
    insn |= 1 << 21;
  return insn | (value & 0xfffc);
}

static int valid_bo(int64_t value)
{
  switch (value & 0x14) {
    default:
    case 0:
      return 1;
    case 0x4:
      return (value & 0x2) == 0;
    case 0x10:
      return (value & 0x8) == 0;
    case 0x14:
      return value == 0x14;
  }
}

static uint32_t insert_bo(uint32_t insn,int64_t value,const char **errmsg)
{
  if (!valid_bo (value))
    *errmsg = "invalid conditional option";
  return insn | ((value & 0x1f) << 21);
}

static uint32_t insert_boe(uint32_t insn,int64_t value,const char **errmsg)
{
  if (!valid_bo (value))
    *errmsg = "invalid conditional option";
  else if ((value & 1) != 0)
    *errmsg = "attempt to set y bit when using + or - modifier";
  return insn | ((value & 0x1f) << 21);
}

static uint32_t insert_ds(uint32_t insn,int64_t value,const char **errmsg)
{
  return insn | (value & 0xfffc);
}

static uint32_t insert_li(uint32_t insn,int64_t value,const char **errmsg)
{
  if ((value & 3) != 0)
    *errmsg = "ignoring least significant bits in branch offset";
  if (is_int25(value)) {
  	insn |= (value >> 2) & 1;
  	insn |= (((value & 0x1ffffff) >> 3) << 9);
  	return (insn);
	}
  *errmsg = "branch out of range";
	return (insn);
}

static uint32_t insert_mbe(uint32_t insn,int64_t value,const char **errmsg)
{
  uint32_t uval, mask;
  int mb, me, mx, count, last;

  uval = value;

  if (uval == 0) {
      *errmsg = "illegal bitmask";
      return insn;
  }

  mb = 0;
  me = 32;
  if ((uval & 1) != 0)
    last = 1;
  else
    last = 0;
  count = 0;

  for (mx = 0, mask = (int64_t) 1 << 31; mx < 32; ++mx, mask >>= 1) {
    if ((uval & mask) && !last) {
      ++count;
      mb = mx;
      last = 1;
    }
    else if (!(uval & mask) && last) {
      ++count;
      me = mx;
      last = 0;
    }
  }
  if (me == 0)
    me = 32;

  if (count != 2 && (count != 0 || ! last)) {
    *errmsg = "illegal bitmask";
  }

  return insn | (mb << 6) | ((me - 1) << 1);
}

static uint32_t insert_mb6(uint32_t insn,int64_t value,const char **errmsg)
{
  return insn | ((value & 0x1f) << 6) | (value & 0x20);
}

static uint32_t insert_nb(uint32_t insn,int64_t value,const char **errmsg)
{
  if (value < 0 || value > 32)
    *errmsg = "value out of range";
  if (value == 32)
    value = 0;
  return insn | ((value & 0x1f) << 11);
}

static uint32_t insert_nsi(uint32_t insn,int64_t value,const char **errmsg)
{
	return (insert_si(insn,-value,errmsg));
}

static uint32_t insert_ral(uint32_t insn,int64_t value,const char **errmsg)
{
  if (value == 0
      || (uint32_t) value == ((insn >> 21) & 0x1f))
    *errmsg = "invalid register operand when updating";
  return insn | ((value & 0x1f) << 16);
}

static uint32_t insert_ram(uint32_t insn,int64_t value,const char **errmsg)
{
  if ((uint32_t) value >= ((insn >> 21) & 0x1f))
    *errmsg = "index register in load range";
  return insn | ((value & 0x1f) << 16);
}

static uint32_t insert_ras(uint32_t insn,int64_t value,const char **errmsg)
{
  if (value == 0)
    *errmsg = "invalid register operand when updating";
  return insn | ((value & 0x1f) << 16);
}

static uint32_t insert_rbs(uint32_t insn,int64_t value,const char **errmsg)
{
  return insn | (((insn >> 21) & 0x1f) << 11);
}

static uint32_t insert_sh6(uint32_t insn,int64_t value,const char **errmsg)
{
  return insn | ((value & 0x3f) << 17);
}

static uint32_t insert_spr(uint32_t insn,int64_t value,const char **errmsg)
{
  return insn | ((value & 0x1f) << 16) | ((value & 0x3e0) << 6);
}

static uint32_t insert_sprg(uint32_t insn,int64_t value,const char **errmsg)
{
  /* @@@ only BOOKE, VLE and 405 have 8 SPRGs */
  if (value & ~7)
    *errmsg = "illegal SPRG number";
  if ((insn & 0x100)!=0 || value<=3)
    value |= 0x10;  /* mfsprg 4..7 use SPR260..263 */
  return insn | ((value & 17) << 16);
}

static uint32_t insert_tbr(uint32_t insn,int64_t value,const char **errmsg)
{
  if (value == 0)
    value = 268;
  return insn | ((value & 0x1f) << 16) | ((value & 0x3e0) << 6);
}

static uint32_t insert_slwi(uint32_t insn,int64_t value,const char **errmsg)
{
  return insn | ((value&0x1f)<<11) | ((31-(value&0x1f))<<1);
}

static uint32_t insert_srwi(uint32_t insn,int64_t value,const char **errmsg)
{
  return insn | (((32-value)&0x1f)<<11) | ((value&0x1f)<<6) | (31<<1);
}

static uint32_t insert_extlwi(uint32_t insn,int64_t value,const char **errmsg)
{
  if (value<1 || value>32)
    *errmsg = "value out of range (1-32)";
  return insn | (((value-1)&0x1f)<<1);
}

static uint32_t insert_extrwi(uint32_t insn,int64_t value,const char **errmsg)
{
  if (value<1 || value>32)
    *errmsg = "value out of range (1-32)";
  return insn | ((value&0x1f)<<11) | (((32-value)&0x1f)<<6) | (31<<1);
}

static uint32_t insert_extwib(uint32_t insn,int64_t value,const char **errmsg)
{
  value += (insn>>11) & 0x1f;
  if (value > 32)
    *errmsg = "sum of last two operands out of range (0-32)";
  return (insn&~0xf800) | ((value&0x1f)<<11);
}

static uint32_t insert_inslwi(uint32_t insn,int64_t value,const char **errmsg)
{
  int64_t n = ((insn>>1) & 0x1f) + 1;
  if (value+n > 32)
    *errmsg = "sum of last two operands out of range (1-32)";
  return (insn&~0xfffe) | (((32-value)&0x1f)<<11) | ((value&0x1f)<<6)
                        | ((((value+n)-1)&0x1f)<<1);
}

static uint32_t insert_insrwi(uint32_t insn,int64_t value,const char **errmsg)
{
  int32_t n = ((insn>>1) & 0x1f) + 1;
  if (value+n > 32)
    *errmsg = "sum of last two operands out of range (1-32)";
  return (insn&~0xfffe) | (((32-(value+n))&0x1f)<<11) | ((value&0x1f)<<6)
                        | ((((value+n)-1)&0x1f)<<1);
}

static uint32_t insert_rotrwi(uint32_t insn,int64_t value,const char **errmsg)
{
  return insn | (((32-value)&0x1f)<<11);
}

static uint32_t insert_clrrwi(uint32_t insn,int64_t value,const char **errmsg)
{
  return insn | (((31-value)&0x1f)<<1);
}

static uint32_t insert_clrlslwi(uint32_t insn,int64_t value,const char **errmsg)
{
  int64_t b = (insn>>6) & 0x1f;
  if (value > b)
    *errmsg = "n (4th oper) must be less or equal to b (3rd oper)";
  return (insn&~0x7c0) | ((value&0x1f)<<11) | (((b-value)&0x1f)<<6)
                       | (((31-value)&0x1f)<<1);
}

static uint32_t insert_ls(uint32_t insn,int64_t value,const char **errmsg)
{
  /* @@@ check for POWER4 */
  return insn | ((value&3)<<21);
}

static uint32_t insert_scndx(uint32_t insn, int64_t value, const char** errmsg)
{
	int i;

	if (is_int5(value)) {
		insn |= (value & 0x1fL) << 24L;
		return (insn);
	}
	/*
	if (is_int16(value)) {
		insn |= 0xA0000000L;
		value_bucket[value_bucketno].insn = insn;
		value_bucket[value_bucketno].value = value;
		value_bucket[value_bucketno].size = 16;
		totsz += 2;
		value_bucketno++;
		if (totsz > 23*4)
	    *errmsg = "too many value encountered";
	  return (insn);
	}
	*/
#if 0
	for (i = 0; i < value_bucketno; i++) {
		if (value_bucket[i].value == value && value != 0) {
			insn |= ((i & 0x7) << 24);
			return (insn);
		}
	}	
#endif
	if (is_int32(value)) {
		insn |= 0x20000000L;
		value_bucket[value_bucketno].insn = insn;
		value_bucket[value_bucketno].value = value;
		value_bucket[value_bucketno].size = 32;
		insn |= ((value_bucketno & 0x7) << 24);
		totsz += 4;
		value_bucketno++;
		count32++;
	}
	else {
		insn |= 0x40000000L;
		value_bucket[value_bucketno].insn = insn;
		value_bucket[value_bucketno].value = value;
		value_bucket[value_bucketno].size = 64;
		insn |= ((value_bucketno & 0x7) << 24);
		totsz += 8;
		value_bucketno++;
		count64++;
	}
	if (totsz > 7*4)
    *errmsg = "too many value encountered";
  return (insn);
}

static uint32_t insert_dbrs(uint32_t insn, int64_t value, const char** errmsg)
{
	int i;

#if 0
	for (i = 0; i < value_bucketno; i++) {
		if (value_bucket[i].value == value && value != 0) {
			insn |= ((i & 0x7) << 10);
			return (insn);
		}
	}	
#endif
	if (is_int32(value)) {
		insn |= 0x20000000L;
		value_bucket[value_bucketno].insn = insn;
		value_bucket[value_bucketno].value = value;
		value_bucket[value_bucketno].size = 32;
		insn |= ((value_bucketno & 0x7) << 10);
		totsz += 4;
		value_bucketno++;
		count32++;
	}
	else {
		insn |= 0x40000000L;
		value_bucket[value_bucketno].insn = insn;
		value_bucket[value_bucketno].value = value;
		value_bucket[value_bucketno].size = 64;
		insn |= ((value_bucketno & 0x7) << 10);
		totsz += 8;
		value_bucketno++;
		count64++;
	}
	if (totsz > 7*4)
    *errmsg = "too many value encountered";
  return (insn);
}

static uint32_t insert_movrd(uint32_t insn,int64_t value,const char **errmsg)
{
  return insn | ((value&31)<<6) | (((value & 0x7f) >> 5) <<17);
}

static uint32_t insert_movrs(uint32_t insn,int64_t value,const char **errmsg)
{
  return insn | ((value&31)<<11) | (((value & 0x7f) >> 5) <<19);
}

static uint32_t insert_reglist(uint32_t insn,int64_t value,const char **errmsg)
{
  return insn | ((value&0xff)<<6) | (((value & 0x1ff00) >> 8) << 17)
  	| (((value >> 28) & 3) << 14) | (((value >> 30) & 3) << 27);
}


static uint32_t insert_crs(uint32_t insn,int64_t value,const char **errmsg)
{
  return insn | ((value&3)<<20);
}

static uint32_t insert_bt(uint32_t insn,int64_t value,const char **errmsg)
{
  return insn | ((value&7)<<9) | (((value >> 8) & 7) << 6);
}

static uint32_t insert_ba(uint32_t insn,int64_t value,const char **errmsg)
{
  return insn | ((value&7)<<15) | (((value >> 8) & 7) << 12);
}

static uint32_t insert_bb(uint32_t insn,int64_t value,const char **errmsg)
{
  return insn | ((value&7)<<21) | (((value >> 8) & 7) << 18);
}

static uint32_t insert_pm(uint32_t insn,int64_t value,const char **errmsg)
{
	int i;
	
	if (value < 0) {
		*errmsg = "predicate window must be after predicate instruction";
		i = 0;
	}
	else
		i = (1 << (value >> 2)) -1;
	return (insert_bd(insn,i,errmsg));
}


/* The operands table.
   The fields are: bits, shift, insert, flags. */

const struct powerpc_operand powerpc_operands[] =
{
  /* UNUSED */
  { 0, 0, 0, 0 },

  /* BA */
  { 11, 12, insert_ba, OPER_CR|OPER_REG },

  /* BAT */
  { 31, 0, insert_csrui, 0 },

  /* BB */
  { 11, 18, insert_bb, OPER_CR|OPER_REG },

  /* BBA */
  { 5, 11, insert_bba, OPER_FAKE },

  /* BD */
  { 31, 0, insert_bd, OPER_RELATIVE | OPER_SIGNED },

  /* BS */
  { 3, 26, 0, OPER_BR|OPER_REG },

  /* BDA */
  { 16, 0, insert_bd, OPER_ABSOLUTE | OPER_SIGNED },

  /* BDM */
  { 16, 0, insert_bdm, OPER_RELATIVE | OPER_SIGNED },

  /* BDMA */
  { 16, 0, insert_bdm, OPER_ABSOLUTE | OPER_SIGNED },

  /* BDP */
  { 16, 0, insert_bdp, OPER_RELATIVE | OPER_SIGNED },

  /* BDPA */
  { 16, 0, insert_bdp, OPER_ABSOLUTE | OPER_SIGNED },

  /* BF */
  { 3, 6, 0, OPER_CR|OPER_REG },

  /* OBF */
  { 3, 6, 0, OPER_CR|OPER_REG | OPER_OPTIONAL },

  /* BFA */
  { 3, 18, 0, OPER_CR|OPER_REG },

  /* BI */
  { 5, 16, 0, OPER_CR|OPER_REG },

  /* BO */
  { 5, 21, insert_bo, 0 },

  /* BOE */
  { 5, 21, insert_boe, 0 },

  /* CRS */
  { 7, 20, insert_crs, OPER_CR|OPER_REG },

  /* CSRNO */
  { 12, 17, 0, OPER_U14 },

  /* BT */
  { 11, 6, insert_bt, OPER_CR|OPER_REG },

  /* CR */
  { 3, 18, 0, OPER_CR|OPER_REG | OPER_OPTIONAL },

  /* D */
  { 14, 17, insert_si, OPER_PARENS | OPER_SIGNED },

  /* DS */
  { 16, 0, insert_ds, OPER_PARENS | OPER_SIGNED },

  /* DX */
  { 14, 17, insert_xsi, OPER_PARENS | OPER_SIGNED },

  /* E */
  { 1, 15, 0, 0 },

  /* FL1 */
  { 4, 12, 0, 0 },

  /* FL2 */
  { 3, 2, 0, 0 },

  /* FLM */
  { 8, 17, 0, 0 },

  /* FRA */
  { 5, 11, 0, OPER_FPR|OPER_REG },

  /* FRB */
  { 5, 17, 0, OPER_FPR|OPER_REG },

  /* FRC */
  { 5, 22, 0, OPER_FPR|OPER_REG },

  /* FRS */
  { 5, 6, 0, OPER_FPR|OPER_REG },

  /* FXM */
  { 8, 12, 0, 0 },

  /* L */
  { 1, 21, 0, OPER_OPTIONAL },

  /* LEV */
  { 7, 5, 0, 0 },

  /* LI */
  { 26, 0, insert_li, OPER_RELATIVE | OPER_SIGNED },

  /* LIA */
  { 26, 0, insert_li, OPER_ABSOLUTE | OPER_SIGNED },

  /* MB */
  { 5, 6, 0, 0 },

  /* ME */
  { 5, 1, 0, 0 },

  /* XH */
  { 5, 1, 0, OPER_XH|OPER_REG },

  /* BR */
  { 3, 6, 0, OPER_BR|OPER_REG },

  /* BRS */
  { 3, 26, 0, OPER_BR|OPER_REG },

  /* RL */
  { 23, 6, insert_reglist, OPER_REGLIST },

  /* MBE */
  { 5, 6, 0, OPER_OPTIONAL | OPER_NEXT },
  /* MBE_ (NEXT) */
  { 31, 1, insert_mbe, 0 },

  /* MB6 */
  { 6, 5, insert_mb6, 0 },

  /* NB */
  { 6, 11, insert_nb, 0 },

  /* NSI */
  { 14, 17, insert_nsi, OPER_NEGATIVE | OPER_S14 | OPER_SIGNED },

  /* RA */
  { 5, 11, 0, OPER_GPR|OPER_REG },

  /* RAL */
  { 5, 16, insert_ral, OPER_GPR|OPER_REG },

  /* RAM */
  { 5, 16, insert_ram, OPER_GPR|OPER_REG },

  /* RAS */
  { 5, 16, insert_ras, OPER_GPR|OPER_REG },

  /* RB */
  { 5, 17, 0, OPER_GPR|OPER_REG },

  /* RC */
  { 5, 22, 0, OPER_GPR|OPER_REG },

  /* RBS */
  { 5, 1, insert_rbs, OPER_FAKE },

  /* RS */
  { 5, 6, 0, OPER_GPR|OPER_REG },

  /* SH */
  { 5, 11, 0, 0 },

  /* SH6 */
  { 6, 17, insert_sh6, 0 },

  /* SI */
  { 14, 17, insert_si, OPER_SIGNED | OPER_S14 },

  /* SISIGNOPT */
  { 16, 0, 0, OPER_SIGNED | OPER_SIGNOPT },

  /* PM */
  { 31, 0, insert_pm, OPER_SIGNED },

  /* BLR */
  { 31, 0, insert_blr, OPER_SIGNED },

  /* BLRL */
  { 31, 0, insert_blr, OPER_SIGNED },

  /* LMT */
  { 9, 17, 0, OPER_SIGNED },

  /* SPR */
  { 10, 11, insert_spr, 0 },

  /* SPRBAT */
  { 2, 17, 0, 0 },

  /* SPRG */
  { 3, 16, insert_sprg, 0 },

  /* SR */
  { 4, 16, 0, 0 },

  /* SV */
  { 14, 2, 0, 0 },

  /* TBR */
  { 10, 11, insert_tbr, OPER_OPTIONAL },

  /* TO */
  { 5, 21, 0, 0 },

  /* U */
  { 4, 12, 0, 0 },

  /* UI */
  { 14, 17, insert_ui, OPER_U14 },

  /* VA */
  { 5, 16, 0, OPER_VR },

  /* VB */
  { 5, 11, 0, OPER_VR }, 

  /* VC */
  { 5, 6, 0, OPER_VR },

  /* VD */
  { 5, 21, 0, OPER_VR },

  /* SIMM */
  { 5, 16, 0, OPER_SIGNED},

  /* UIMM */
  { 5, 16, 0, 0 },

  /* SHB */
  { 4, 6, 0, 0 },

  /* SCNDX */
  { 5, 24, insert_scndx, OPER_PARENS | OPER_SCNDX },
#if 0
  /* JA */
  { 31, 0, insert_ja, OPER_ABSOLUTE },

  /* JAB */
  { 31, 0, insert_jab, OPER_ABSOLUTE },

  /* JOM */
  { 3, 10, insert_jom, OPER_SIGNED },

  /* JSWS */
  { 4, 6, insert_jsws, OPER_SIGNED },
#endif
  /* SLWI */
  { 5, 11, insert_slwi, 0 },

  /* SRWI */
  { 5, 11, insert_srwi, 0 },

  /* EXTLWI */
  { 31, 1, insert_extlwi, 0 },

  /* EXTRWI */
  { 31, 1, insert_extrwi, 0 },

  /* EXTWIB */
  { 5, 11, insert_extwib, 0 },

  /* INSLWI */
  { 5, 11, insert_inslwi, 0 },

  /* INSRWI */
  { 5, 11, insert_insrwi, 0 },

  /* ROTRWI */
  { 5, 11, insert_rotrwi, 0 },

  /* CLRRWI */
  { 5, 1, insert_clrrwi, 0 },

  /* CLRLSL */
  { 5, 11, insert_clrlslwi, 0 },

  /* DBRS */
  { 31, 0, insert_dbrs, OPER_PARENS | OPER_SIGNED },

  /* STRM */
  { 2, 21, 0, 0 },

  /* AT */
  { 1, 25, 0, OPER_OPTIONAL },

  /* LS */
  { 2, 21, insert_ls, OPER_OPTIONAL },

  /* RSOPT */
  { 5, 21, 0, OPER_GPR|OPER_REG | OPER_OPTIONAL },

  /* RAOPT */
  { 5, 16, 0, OPER_GPR|OPER_REG | OPER_OPTIONAL },

  /* RBOPT */
  { 5, 11, 0, OPER_GPR|OPER_REG | OPER_OPTIONAL },

  /* CT */
  { 5, 21, 0, OPER_OPTIONAL },

  /* SHO */
  { 5, 11, 0, OPER_OPTIONAL },
  
  /* CRFS */
  { 3, 0, 0, OPER_CR|OPER_REG },

  /* EVUIMM_2 */
  { 5, 10, 0, OPER_PARENS },

  /* EVUIMM_4 */
  { 5, 9, 0, OPER_PARENS },

  /* EVUIMM_8 */
  { 5, 8, 0, OPER_PARENS },

  /* MOVRD */
  { 5, 8, insert_movrd, OPER_GPR|OPER_FPR|OPER_CR|OPER_BR },

  /* MOVRS */
  { 5, 8, insert_movrs, OPER_GPR|OPER_FPR|OPER_CR|OPER_BR },
};
