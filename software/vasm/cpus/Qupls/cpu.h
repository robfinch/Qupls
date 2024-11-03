/* (c) in 2021-2023 by Robert Finch */
#define BITSPERBYTE 8
#define FLOAT_PARSER 1
#include "hugeint.h"
//#define SYNTAX_STD_COMMENTCHAR_HASH

#define LITTLEENDIAN 1
#define BIGENDIAN 0
#define VASM_CPU_QUPLS 1
#define HAVE_INSTRUCTION_EXTENSION	1

/* maximum number of operands in one mnemonic */
#define MAX_OPERANDS 5

/* maximum number of mnemonic-qualifiers per mnemonic */
#define MAX_QUALIFIERS 2

/* maximum number of additional command-line-flags for this cpu */

/* data type to represent a target-address */
typedef int64_t taddr;
typedef uint64_t utaddr;

/* minimum instruction alignment */
#define INST_ALIGN 1

/* default alignment for n-bit data */
#define DATA_ALIGN(n) ((n)<=8?1:(n)<=16?2:(n)<=32?4:8)

/* operand class for n-bit data definitions */
#define DATA_OPERAND(n) qupls_data_operand(n)

#define REL_QUPLS_BRANCH (LAST_STANDARD_RELOC+1)

/* #define NEXT (-1)   use operand_type+1 for next operand */

/* type to store each operand */
typedef struct {
	unsigned char number;
  uint32_t type;
  unsigned char attr;   /* reloc attribute != REL_NONE when present */
  unsigned char format;
  unsigned char basereg;
  unsigned char ndxreg;
  char scale;
  expr *value;
  uint64_t mask;
} operand;

#define OPC_ADDS	49LL
#define OPC_ANDS	50LL
#define OPC_ORS		51LL
#define OPC_EORS	59LL

/* operand-types */
#define OP_REG						0x00000001L
#define OP_NEXT_VREG			0x00000002L
#define OP_IMM23					0x00000004L
#define OP_IMM30					0x00000008L
#define OP_IMM46					0x00000010L
#define OP_IMM64					0x00000020L
#define OP_VMSTR					0x00000040L
#define OP_PREDSTR				0x00000080L
#define OP_REG6						0x00000100L
#define OP_VMREG					0x00000200L
#define OP_UIMM6					0x00000400L
#define OP_REGIND					0x00000800L
#define OP_BRTGT					0x00001000L
#define OP_REG7						0x00001000L
#define OP_SCNDX					0x00020000L
#define OP_LK							0x00040000L
#define OP_CAREG					0x00080000L
#define OP_IND_SCNDX			0x00100000L
#define OP_BRTGT28				0x00200000L
#define OP_BRTGT34				0x00400000L
#define OP_DATA						0x00800000L
#define OP_SEL						0x01000000L
#define OP_VREG						0x02000000L
#define OP_IMM7						0x04000000L
#define OP_CAREGIND				0x08000000L
#define OP_REGIND_DISP		0x10000000L

#define OP_NEXT			0x20000000L
#define OP_NEXTREG	0x10000000L

/* supersets of other operands */
#define OP_IMM			(OP_IMM7|OP_IMM23|OP_IMM30|OP_IMM46|OP_IMM64)
#define OP_MEM      (OP_REGIND|OP_SCNDX)
#define OP_ALL      0x0fffffffL

#define OP_ISMEM(x) ((((x) & OP_MEM)!=0)

#define CPU_SMALL 1
#define CPU_LARGE 2
#define CPU_ALL  (-1)

#define EXT_BYTE	0
#define EXT_WYDE	1
#define EXT_TETRA	2
#define EXT_OCTA	3
#define EXT_HEXI	4
#define EXT_SINGLE	1
#define EXT_DOUBLE	2
#define EXT_QUAD		3

#define SZ_BYTE	0
#define SZ_WYDE	1
#define SZ_TETRA	2
#define SZ_OCTA	3
#define SZ_HEXI	4
#define SZ_SINGLE	2
#define SZ_DOUBLE 3
#define SZ_QUAD		4
#define SZ_UNSIZED	128

#define SZ_INTALL	(SZ_BYTE|SZ_WYDE|SZ_TETRA|SZ_OCTA|SZ_HEXI)
#define SZ_FLTALL	(SZ_SINGLE|SZ_DOUBLE|SZ_QUAD)

typedef struct {
	uint8_t size;
	uint64_t opcode;
	uint8_t opcode_size;
	thuge val;
} postfix_buf;

typedef struct {
	uint8_t size;
	uint8_t opcode_size;
	uint64_t opcode;
  uint64_t short_opcode;
	thuge val;
	postfix_buf pfxa;
	postfix_buf pfxb;
	postfix_buf pfxc;
	uint64_t imm0;
	uint64_t imm1;
	uint64_t imm2;
	uint64_t imm3;
} instruction_buf;

typedef struct {
	unsigned int format;
  unsigned int available;
  uint64_t prefix;
  uint64_t opcode;
  size_t len;
  uint8_t size;
  uint8_t defsize;
  unsigned int flags;
  uint64_t short_opcode;
  size_t short_len;
} mnemonic_extension;

typedef struct {
	int const_expr;		// in pass one
	int	size;
	int cache;
	int postfix_count;
} instruction_ext;

#define FLG_NEGIMM	1
#define FLG_FP			2
#define FLG_MASK		4
#define FLG_UI6			8

#define EXI8	0x46
#define EXI24	0x48
#define EXI40	0x4A
#define EXI56	0x4C
#define EXIM	0x50

// Instruction Formats
#define	R3		1
#define B			2
#define B2		3
#define BZ		4
#define J2		5
#define LS		6
#define MV		7
#define R2		8
#define BL		9
#define JL2		10
#define REGIND	11
#define SCNDX		12
#define J			13
#define JL		14
#define BL2		15
#define RI		16
#define RIL		17
#define RTS		18
#define R3RR	19
#define R3IR	20
#define R3RI	21
#define R3II	22
#define VR3		23
#define INT		24
#define BITS16	25
#define BITS40	26
#define REX		27
#define RTE		28
#define R1		29
#define DIRECT	30
#define CSR		31
#define B3		32
#define BL3		33
#define J3		34
#define JL3		35
#define RII		36
#define RTDR	37
#define RTDI	38
#define ENTER	39
#define LEAVE	40
#define EXI56F	41
#define R4 42
#define SHIFTI	43
#define BFR3RR	44
#define BFR3IR	45
#define BFR3RI	46
#define BFR3II	47
#define RI6			48
#define RI64		49
#define R3R			50
#define RI48		51
#define R2M			52
#define RIM			53
#define PRED		54
#define VMASK		55
#define CSRI		56
#define RIV			57
#define PFX			58
#define RIMV		59
#define RIS			60
#define JSCNDX	61
#define REP			62
#define RIA			63
#define RIB			64
#define SH			65
#define SI			66
#define ATOM		67
#define BI			68
#define LDI			69
#define SYNC		70
#define PADI		71
#define RISH		72
#define RISM		73
#define R5			74
#define J4			75
#define JL4			76

#define OPC(x)	(((x) & 0x7fLL))
#define RT(x)		(((x) & 0xffLL) << 7LL)
#define INCDEC(x)	(((x) & 3LL) << 11LL)
#define NRT(x)	(((x) & 1LL) << 15LL)
#define RA(x)		(((x) & 0xffLL) << 16LL)
#define NRA(x)	(((x) & 1LL) << 24LL)
#define RB(x)		(((x) & 0xffLL) << 25LL)
#define IPR(x)	(((x) & 3LL) << 22LL)
#define NRB(x)	(((x) & 1LL) << 33LL)
#define BRDISPL(x)	(((x) & 0x7ffffLL) << 34LL)
#define BRDISPH(x)	((((x) >> 19LL) & 0xFLL) << 60LL)
#define RC(x)		(((x) & 0xffLL) << 34LL)
#define NRC(x)	(((x) & 1LL) << 42LL)
#define LKT(x)	(((x) & 7LL) << 7LL)
#define LKS(x)	(((x) & 7LL) << 16LL)
#define CM(x)		(((x) & 3LL) << 8LL)
#define BFN(x)	(((x) & 15LL) << 7LL)
#define COND(x)	(((x) & 0xfLL) << 5LL)
#define CND3(x)	(((x) & 0x7LL) << 9LL)
#define IM2(x)		(((x) & 3LL) << 25LL)
#define S(x)			(((x) & 7LL) << 34LL)
#define SC(x)			(((x) & 3LL) << 22LL)
#define PREDF(x)		(((x) & 0xfLL) << 53LL)
#define PREDI(x)		(((x) & 0xfLL) << 25LL)
#define PREDSI(x)		(((x) & 0xfLL) << 25LL)
#define SHI(x)		(((x) & 1LL) << 43LL)
#define SHFUNC(x)	(((x) & 0xfLL) << 60LL)
#define R1FUNC(x)	(((x) & 0xffLL) << 32LL)
#define OP3(x)		(((x) & 0xfLL) << 43LL)
#define R2FUNC(x)	(((x) & 0x7fLL) << 57LL)
#define R3FUNC(x)	(((x) & 0x7fLL) << 57LL)
#define LSFUNC(x)	(((x) & 0xfLL) << 60LL)
#define FMT2(x)		(((x) & 3LL) << 38LL)
#define FMT3(x)		(((x) & 7LL) << 37LL)
#define FUNC2(x)	(((x) & 0x7LL) << 37LL)
#define FUNC3(x)	(((x) & 0x7LL) << 37LL)
#define FUNC5(x)	(((x) & 0x1fLL) << 35LL)
#define FLT1(x)	(((x) & 0x1fLL) << 22LL)
#define CA(x)		(((x) & 7LL) << 29LL)
#define CAB(x)		(((x) & 7LL) << 24LL)
#define BFOFFS(x)	(((x) & 0x1fLL) << 22LL)
#define BFWID(x)	(((x) & 0x1fLL) << 29LL)
#define BFMB(x)	((((x) & 0x1fLL) << 22LL)|((((x) >> 5LL) & 1LL) << 30LL))
#define BFME(x)	(((x) & 0x3fLL) << 29LL)
#define BFFUNC(x)	(((x) & 0xfLL) << 44LL)
#define RTYPE(x)	(((x) & 3LL) << 13LL)
#define RK(x)			(((x) & 0x3fLL) << 40LL)
#define SK(x)			(((x) & 1LL) << 46LL)

/* special data operand types: */
#define OP_D8  0x1001
#define OP_D16 0x1002
#define OP_D32 0x1003
#define OP_D64 0x1004
#define OP_D128 0x1005
#define OP_F32 0x1006
#define OP_F64 0x1007
#define OP_F128 0x1008

#define OP_DATAM(t) (t >= OP_D8 && t <= OP_F128)
#define OP_FLOAT(t) (t >= OP_F32 && t <= OP_F128)
