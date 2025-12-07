`timescale 1ns / 10ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//
// BSD 3-Clause License
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// ============================================================================

`ifndef CPU_TYPES_PKG
import  cpu_types_pkg::*;
`endif

package Qupls4_pkg;
`define QUPLS4	1'b1
`define STARK_PKG 1'b1
`undef IS_SIM
parameter SIM = 1'b0;
//`define IS_SIM	1

// Comment out to remove the sigmoid approximate function
//`define SIGMOID	1

// Number of physical registers supporting the architectural ones and used in
// register renaming. There must be significantly more physical registers than
// architectural ones, or performance will suffer due to stalls.
// Must be a multiple of four. If it is not 512 or 256 then the renamer logic will
// need to be modified.
parameter PREGS = 512;

parameter IP_REG = 8'd31;

// Number of operands (including destination) a micro-op can have.
parameter NOPER = 4;

// Length of a vector register in bits.
parameter VLEN = 256;
parameter VREGS = (VLEN/$bits(cpu_types_pkg::value_t));

`define L1CacheLines	1024
`define L1CacheLineSize		256

`define L1ICacheLineSize	256
`define L1ICacheLines	1024
`define L1ICacheWays 4

`define L1DCacheWays 4

parameter SUPPORT_4B_PTE = 1'b0;
parameter SUPPORT_8B_PTE = 1'b1;
parameter SUPPORT_16B_PTE = 1'b0;
parameter SUPPORT_TLBLVL2	= 1'b0;

// =============================================================================
// Debugging Options
// =============================================================================
// Set the following parameter to one to serialize operation of the CPU.
// Meant for debugging purposes.
parameter SERIALIZE = 1;

// Set the following parameter to disable invocation of the single step
// routine. Meant for debugging purposes.
parameter SSM_DEBUG = 1;

// Enables register renaming to remove false dependencies.
parameter SUPPORT_RENAMER = 1;

// Register name supplier
// 3 = SRL based circular list, smaller less performant
// 4 = FIFO based, larger, does not work correctly yet
// 			(sometimes supplies the same register twice)
// 6 = FFO / Bitmap, a find-first-ones approach with a bitmap
parameter RENAMER = 4;

// Comment out the following to remove the RAT
`define SUPPORT_RAT 1;

// =============================================================================
// =============================================================================

// 1=move interrupt to the start of the instruction (recommended).
// 2=defer interrupts to the start of the next instruction.
// 3=record micro-op number for instruction restart (not recommended).
parameter UOP_STRATEGY = 1;	// micro-op strategy

// 1=no interrupts allowed when micro-code machine active
parameter UCM_STRATEGY = 1;	// micro-code machine strategy

// Set the following to one to support backout and restore branch handling.
// backout / restore is not 100% working yet. Supporting backout / restore
// makes the core larger.
parameter SUPPORT_BACKOUT = 1'b1;

// Select building for performance or size.
// If this is set to one extra logic will be included to improve performance.
// Allows simple ALU ops to be performed on the FPU and simple FPU ops to be
// performed on an ALU. 
parameter PERFORMANCE = 1'b0;

// Predictor
// This is for the late stage predicator. The branch-target-buffer is always
// present.
//		0 = none
//		1 = backwards branch predictor (accuracy < 60%)
//		2 = g select predictor
parameter BRANCH_PREDICTOR = 0;

// The following indicates whether to support postfix instructions or not.
// Supporting postfix instructions increases the size of the core and reduces
// the code density. (Deprecated - the core does not support POSTFIXES).
parameter SUPPORT_POSTFIX = 0;

// The following allows the core to process flow control ops in any order
// to reduce the size of the core. Set to zero to restrict flow control ops
// to be processed in order. If processed out of order a branch may 
// speculate incorrectly leading to lower performance.
parameter SUPPORT_OOOFC = 1'b0;

// The following parameter enables support for predicated logic in the core.
parameter SUPPORT_PRED = 1'b1;

// The PRED_SHADOW parameter controls the maximum number of instructions
// following the predicate that are affected by it. Increasing the shadow
// increases the amount of logic generated for the core in a more than
// linear fashion. The maximum is seven instructions as that is all that
// can be encoded in the instruction. The minimum is one.
parameter PRED_SHADOW = 4;

// Allowing unaligned memory access increases the size of the core.
parameter SUPPORT_UNALIGNED_MEMORY = 1'b0;
parameter SUPPORT_BUS_TO = 1'b0;

// This parameter enables support for quad (128-bit) precision operations.
parameter SUPPORT_QUAD_PRECISION = 1'b0;

// Supporting load bypassing may improve performance, but will also increase the
// size of the core and make it more vulnerable to security attacks.
// Loads are bypassed only when there is an exact match to a store.
parameter SUPPORT_LOAD_BYPASSING = 1'b0;

// Support mutiple precisions for SAU and FPU operations. If not supported only
// 64-bit precision will be supported. Suppporting multiple precisions adds
// considerable size to the SAU / FPU. Eg. 5x larger.
parameter SUPPORT_PREC = 1'b0;

// Support for NaN tracing
parameter SUPPORT_NAN_TRACE = 1'b0;

// Support insertion of IRQ polling instructions into the micro-op stream.
parameter SUPPORT_IRQ_POLLING = 1'b0;

// The following controls the size of the reordering buffer.
// Setting ROB_ENTRIES below 12 may not work. Setting the number of entries over
// 63 may require changing the sequence number type. For ideal construction 
// should be a multiple of four.
parameter ROB_ENTRIES = 16;

// Number of entries supporting block operate instructions.
parameter BEB_ENTRIES = 4;

// The following is the number of ROB entries that are examined by the 
// scheduler when determining what to issue. The schedule window is
// between the head of the queue and WINDOW_SIZE entries backwards.
// Decreasing the window size may reduce hardware but will cost performance.
parameter SCHED_WINDOW_SIZE = 8;

// The following is the number of branch checkpoints to support. 16 is the
// recommended maximum. Fewer checkpoints may reduce core performance as stalls
// will result if there are insufficient checkpoints for the number of
// outstanding branches. More checkpoints will only consume resources without
// improving performance significantly.
parameter NCHECK = 16;			// number of checkpoints

parameter LOADQ_ENTRIES = 8;
parameter STOREQ_ENTRIES = 8;
parameter LSQ_ENTRIES = 8;
parameter LSQ2 = 1'b0;			// Queue two LSQ entries at once?

// Number of architectural registers including registers to support vector
// operations. Each vector register needs four registers.
parameter NREGS = 64;
parameter AREGS = 64;
parameter REGFILE_LATENCY = 2;

parameter pL1CacheLines = `L1CacheLines;
parameter pL1LineSize = `L1CacheLineSize;
parameter pL1ICacheLines = `L1CacheLines;
// The following arrived at as 512+32 bits for word at end of cache line, plus
// 40 bits for a possible constant postfix
parameter pL1ICacheLineSize = `L1ICacheLineSize;
parameter pL1Imsb = $clog2(`L1ICacheLines-1)-1+6;
parameter pL1ICacheWays = `L1ICacheWays;
parameter pL1DCacheWays = `L1DCacheWays;

parameter INSN_LEN = 8'd4;

const cpu_types_pkg::pc_address_t RSTPC	= 32'hFFFFFD80;
const cpu_types_pkg::address_t RSTSP = 32'hFFFF9000;


// =============================================================================
// Instruction Support
// =============================================================================

// This parameter adds support for capabilities instructions. Increases the
// size of the core. An FPU must also be enabled.
parameter SUPPORT_CAPABILITIES = 1'b0;

// Support for vector operations.
parameter SUPPORT_VECTOR = 1'b0;

parameter SUPPORT_IDIV = 1;
parameter SUPPORT_TRIG = 0;
parameter SUPPORT_FDP = 0;

// =============================================================================
// Resources
// =============================================================================

// Number of register read ports. More ports allows more simultaneous reads
// (obvious) and may increase performance. However, most instructions will
// have two or fewer arguments, and allowing for four instructions at once
// means an average of eight ports per cycle.
parameter NREG_RPORTS = 12;

// Number of data ports should be 1 or 2. 2 ports will allow two simulataneous
// reads, but still only a single write.
parameter NDATA_PORTS = 1;
// Number of AGENs should be 1 or 2. There is little value in having more agens
// than there are data ports.
parameter NAGEN = 1;
// Increasing the number of SAUs will increase performance. There must be at
// least one SAU.
// Note that adding an FPU may also increase integer performance if PERFORMANCE
// is set to 1.
parameter NSAU = 2;			// 1 or 2
parameter NFPU = 1;			// 0 or 1
parameter NFMA = 1;			// 0, 1 or 2
parameter NDFPU = 0;		// 0 or 1
parameter NLSQ_PORTS = 1;

parameter RAS_DEPTH	= 4;

parameter SUPPORT_RSB = 0;


// =============================================================================
// define PANIC types
// =============================================================================

parameter PANIC_NONE		= 4'd0;
parameter PANIC_FETCHBUFBEQ	= 4'd1;
parameter PANIC_INVALIDISLOT	= 4'd2;
parameter PANIC_MEMORYRACE	= 4'd3;
parameter PANIC_IDENTICALDRAMS	= 4'd4;
parameter PANIC_OVERRUN		 = 4'd5;
parameter PANIC_HALTINSTRUCTION	= 4'd6;
parameter PANIC_INVALIDMEMOP	= 4'd7;
parameter PANIC_INVALIDFBSTATE = 4'd8;
parameter PANIC_INVALIDIQSTATE = 4'd9;
parameter PANIC_BRANCHBACK = 4'd10;
parameter PANIC_BADTARGETID	 = 4'd12;
parameter PANIC_COMMIT = 4'd13;
parameter PANIC_CHECKPOINT_INDEX = 4'd14;

// =============================================================================
// Constants
// =============================================================================

// Register accessibility
parameter REG_U = 4'h1;
parameter REG_S = 4'h2;
parameter REG_H = 4'h4;
parameter REG_M = 4'h8;
parameter REG_SHM = REG_S|REG_H|REG_M;
parameter REG_USHM = REG_U|REG_S|REG_H|REG_M;

// =============================================================================
// Type declarations
// =============================================================================

typedef enum logic [2:0] {
	DRAMSLOT_AVAIL = 3'd0,
	DRAMSLOT_READY = 3'd1,
	DRAMSLOT_ACTIVE = 3'd2,
	DRAMSLOT_DELAY = 3'd3,
	DRAMSLOT_ACTIVE2 = 3'd4,
	DRAMSLOT_DELAY2 = 3'd5
} dram_state_t;

typedef struct packed
{
	logic vb;									// valid bypass
	logic [2:0] row;
	logic col;
} lsq_ndx_t;

typedef enum logic [1:0] {
	OM_APP = 2'd0,
	OM_SUPERVISOR = 2'd1,
	OM_HYPERVISOR = 2'd2,
	OM_SECURE = 2'd3
} operating_mode_t;

typedef struct packed
{
	logic inv;
	logic [6:0] rg;
} regspec_t;

typedef logic [NREGS-1:1] reg_bitmask_t;
typedef logic [ROB_ENTRIES-1:0] rob_bitmask_t;
typedef logic [LSQ_ENTRIES-1:0] lsq_bitmask_t;
typedef logic [3:0] beb_ndx_t;

typedef struct packed
{
	logic [Qupls4_pkg::PREGS-1:0] avail;	// available registers at time of queue (for rollback)
//	cpu_types_pkg::pregno_t [AREGS-1:0] p2regmap;
	cpu_types_pkg::pregno_t [Qupls4_pkg::AREGS-1:0] pregmap;
	cpu_types_pkg::pregno_t [Qupls4_pkg::AREGS-1:0] regmap;
} checkpoint_t;

typedef struct packed
{
	logic [1:0] resv;
	logic gt;
	logic ge;
	logic le;
	logic lt;
	logic ne;
	logic eq;				// _xnor
} condition_byte_t;

typedef struct packed
{
	condition_byte_t _secure;
	condition_byte_t _hyper;
	condition_byte_t _super;
	condition_byte_t _app;
} condition_reg_t;

typedef struct packed
{
	logic [7:0] pl;			// privilege level
	logic [2:0] swstk;	// software stack
	logic [2:0] mprv;		// memory access priv indicator	
	logic dbg;					// debug mode indicator
	logic [1:0] ptrsz;	// pointer size 0=32,1=64,2=96
	operating_mode_t om;	// operating mode
	logic trace_en;			// instruction trace enable
	logic ssm;					// single step mode
	logic [5:0] ipl;		// interrupt privilege level
	logic die;					// debug interrupt enable
	logic mie;					// machine interrupt enable
	logic hie;					// hypervisor interrupt enable
	logic sie;					// supervisor interrupt enable
	logic uie;					// user interrupt enable
} status_reg_t;				// 32 bits

typedef enum logic [2:0] {
	RND_NE = 3'd0,		// nearest ties to even
	RND_ZR = 3'd1,		// round to zero (truncate)
	RND_PL = 3'd2,		// round to plus infinity
	RND_MI = 3'd3,		// round to minus infinity
	RND_MM = 3'd4,		// round to maxumum magnitude (nearest ties away from zero)
	RND_XG = 3'd5,		// externally guided
	RND_FL = 3'd7			// round according to flags register
} fround_t;

typedef struct packed
{
	fround_t rm;
	logic inexe;		// inexact exception enable
	logic dbzxe;		// divide by zero exception enable
	logic underxe;	// underflow exception enable
	logic overxe;		// overflow exception enable
	logic invopxe;	// invalid operation exception enable
	//- - - - - - - 
	logic ns;
	// Result status
	logic fractie;	// last instruction rounded intermediate result
	logic rawayz;		// rounded away from zero
	logic c;				// denormalized, negative zero, or quiet nan
	logic neg;			// result is negative
	logic pos;			// result is positive
	logic zero;			// result is zero
	logic inf;			// result is infinite
	// Exception occurrance
	logic swt;			// set this bit to trigger an invalid operation
	logic inerx;		// inexact result exception occurred (sticky)
	logic dbzx;			// divide by zero exception occurred
	logic underx;		// underflow exception occurred
	logic overx;		// overflow exception occurred
	logic giopx;		// global invalid operation exception
	logic gx;				// global exception indicator, set for any exception
	logic sumx;			// summary exception
	// Exception type resolution
	logic cvt;			// attempt to convert NaN or too large integer
	logic sqrtx;		// square root of non-zero negative
	logic nancmp;		// comparison of NaNs not using unordered comparisons
	logic infzero;	// multiply infinity by zero
	logic zerozero;	// divide zero by zero
	logic infdiv;		// division of infinities
	logic subinfx;	// subtraction of infinities
	logic snanx;		// signalling nan
} fp_status_reg_t;

typedef enum logic [2:0] {
	BTS_NONE = 3'd0,
	BTS_BCC = 3'd1,
	BTS_REG = 3'd2,
	BTS_BSR = 3'd3,
	BTS_JSR = 3'd4,
	BTS_CALL = 3'd5,
	BTS_RET = 3'd6,
	BTS_ERET = 3'd7
} bts_t;

typedef enum logic [9:0] {
	BRC_NONE = 10'h000,
	BRC_JSR = 10'h001,
	BRC_JSRN = 10'h002,
	BRC_BSR = 10'h004,
	BRC_BCCD = 10'h008,
	BRC_BCCR = 10'h010,
	BRC_RTD = 10'h040,
	BRC_ERET = 10'h100,
	BRC_ECALL = 10'h200
} brclass_t;

parameter BRC_BLR = 1'b0;
parameter BRC_BCC = BRC_BCCR|BRC_BCCD;
parameter BRC_RET = BRC_RTD;

typedef enum logic [2:0] {
	BS_IDLE = 3'd0,
	BS_CHKPT_RESTORE = 3'd1,
	BS_CHKPT_RESTORED = 3'd2,
	BS_STATE3 = 3'd3,
	BS_CAPTURE_MISSPC = 3'd4,
	BS_DONE = 3'd5,
	BS_DONE2 = 3'd6
} branch_state_t;

typedef enum logic [6:0] {
	OP_BRK = 7'd0,
	OP_R3H = 7'd2,
	OP_BFLD = 7'd3,
	OP_ADDI = 7'd4,
	OP_SUBFI = 7'd5,
	OP_MULI = 7'd6,
	OP_CSR = 7'd7,
	OP_ANDI = 7'd8,
	OP_ORI = 7'd9,
	OP_XORI = 7'd10,
	OP_CMPI = 7'd11,
	OP_EXTD = 7'd12,
	OP_DIVI = 7'd13,
	OP_MULUI = 7'd14,
	OP_ADDIPI = 7'd15,
	OP_SHIFT = 7'd16,
	OP_CMPUI = 7'd19,
	OP_LOADA = 7'd20,
	OP_DIVUI = 7'd21,
	OP_LOADI = 7'd22,
	OP_MOVMR = 7'd23,
//	OP_TRAP = 7'd28,

	OP_BCCU8 = 7'd24,
	OP_BCCU16 = 7'd25,
	OP_BCCU32 = 7'd26,
	OP_BCCU64 = 7'd27,
	OP_BCC8 = 7'd28,
	OP_BCC16 = 7'd29,
	OP_BCC32 = 7'd30,
	OP_BCC64 = 7'd31,
	
	OP_BSR = 7'd32,
	OP_JSR = 7'd33,
	OP_JSRN = 7'd36,
	OP_RTD = 7'd35,
	
	OP_CHK = 7'd47,

	OP_FLTPH = 7'd48,
	OP_FLTPS = 7'd49,
	OP_FLTPD = 7'd50,
	OP_FLTPQ = 7'd51,

	OP_ENTER = 7'd52,
	OP_EXIT = 7'd53,
	OP_PUSH = 7'd54,
	OP_POP = 7'd55,
	OP_FLTH = 7'd56,
	OP_FLTS = 7'd57,
	OP_FLTD = 7'd58,
	OP_FLTQ = 7'd59,

	OP_PFX = 7'd61,
	OP_MOD = 7'd62,

	OP_LDB = 7'd64,
	OP_LDBZ = 7'd65,
	OP_LDW = 7'd66,
	OP_LDWZ = 7'd67,
	OP_LDT = 7'd68,
	OP_LDTZ = 7'd69,
	OP_LOAD = 7'd70,
	OP_LDV = 7'd71,
	OP_LDIP = 7'd72,
	OP_CLOAD = 7'd73,
	OP_FLDH = 7'd74,
	OP_FLDS = 7'd76,
	OP_LDVN = 7'd79,
	
	OP_STB = 7'd80,
	OP_STW = 7'd81,
	OP_STT = 7'd82,
	OP_STORE = 7'd83,
	OP_STI = 7'd84,
	OP_CSTORE = 7'd85,
	OP_STIP = 7'd87,
	OP_STPTR = 7'd86,

	OP_STV = 7'd88,
	OP_STVN = 7'd89,
	OP_V2P = 7'd90,
	OP_VV2P = 7'd91,

	OP_AMO = 7'd92,
	OP_CMPSWAP = 7'd93,
	OP_FLDG = 7'd95,
	
	OP_R3VS = 7'd100,
	OP_FLTVS = 7'd101,

	OP_R3B = 7'd104,
	OP_R3W = 7'd105,
	OP_R3T = 7'd106,
	OP_R3O = 7'd107,
	OP_BLOCK = 7'd111,
	OP_R3BP = 7'd112,
	OP_R3WP = 7'd113,
	OP_R3TP = 7'd114,
	OP_R3OP = 7'd115,
	OP_R3P = 7'd116,
	OP_FLTP = 7'd117,

	OP_REXT = 7'd120,
	OP_FENCE = 7'd123,
	OP_NOP = 7'd127
} opcode_e;

typedef enum logic [6:0] {
	EX_ADC = 7'd0,
	EX_ASLC = 7'd1,
	EX_ASRC = 7'd2,
	EX_LSRC = 7'd3,
	EX_VSHLV = 7'd6,
	EX_VSHRV = 7'd7
} extdop_e;

typedef enum logic [6:0] {
	FN_AND = 7'd0,
	FN_OR = 7'd1,
	FN_XOR = 7'd2,
	FN_CMP = 7'd3,
	FN_ADD = 7'd4,
	FN_SUB = 7'd5,
	FN_CMPU = 7'd6,
	FN_NAND = 7'd8,
	FN_NOR = 7'd9,
	FN_XNOR = 7'd10,
	FN_MOVE = 7'd15,
	FN_MUL = 7'd16,
	FN_DIV = 7'd17,
	FN_MULU = 7'd19,
	FN_DIVU = 7'd20,
	FN_MULSU = 7'd21,
	FN_DIVSU = 7'd22,
	FN_MOD = 7'd25,
	FN_R1 = 7'd26,
	FN_MODU = 7'd28,
	FN_MUX = 7'd33,
	FN_ROL = 7'd80,
	FN_ROR = 7'd81,
	FN_ASR = 7'd82,
	FN_ASL = 7'd83,
	FN_LSR = 7'd84,
	FN_REDAND = 7'd96,
	FN_REDOR = 7'd97,
	FN_REDEOR = 7'd98,
	FN_REDMINU = 7'd99,
	FN_REDSUM = 7'd100,
	FN_REDMAXU = 7'd101,
	FN_REDMIN = 7'd102,
	FN_REDMAX = 7'd103,
	FN_PEEKQ = 7'd104,
	FN_POPQ = 7'd105,
	FN_PUSHQ = 7'd106,
	FN_RESETQ = 7'd107,
	FN_STATQ = 7'd108,
	FN_READQ = 7'd110,
	FN_WRITEQ = 7'd111,
	FN_SEQ = 7'd120,
	FN_SNE = 7'd121,
	FN_SLT = 7'd122,
	FN_SLE = 7'd123,
	FN_SLTU = 7'd124,
	FN_SLEU = 7'd125
} func_e;

typedef enum logic [6:0] {
	R1_CNTLZ = 7'd0,
	R1_CNTLO = 7'd1,
	R1_CNTPOP = 7'd2,
	R1_SQRT = 7'd4,
	R1_REVBIT = 7'd5,
	R1_CNTTZ = 7'd6,
	R1_NOT = 7'd7,
	// NNA
	R1_NNA_TRIG = 7'd8,
	R1_NNA_STAT = 7'd9,
	R1_NNA_MFACT = 7'd10,

	R1_MKBOOL = 7'd12,
	// Crypto
	R1_SM3P1 = 7'd14,
	R1_SM3PO = 7'd15
} r1_e;

typedef enum logic [6:0] {
	FLT_MIN = 7'd2,
	FLT_MAX = 7'd3,
	FLT_SEQ = 7'd8,
	FLT_SNE = 7'd9,
	FLT_SLT = 7'd10,
	FLT_CMP = 7'd13,
	FLT_SGNJ = 7'd16,
	FLT_ABS = 7'd32,
	FLT_NEG = 7'd33
} flt_e;

typedef enum logic [3:0] {
	FOP4_FADD = 4'd4,
	FOP4_FSUB = 4'd5,
	FOP4_FMUL = 4'd6,
	FOP4_FDIV = 4'd7,
	FOP4_G8 = 4'd8,
	FOP4_G10 = 4'd10,
	FOP4_TRIG = 4'd11
} float_t;

typedef enum logic [2:0] {
	FG8_FSGNJ = 3'd0,
	FG8_FSGNJN = 3'd1,
	FG8_FSGNJX = 3'd2,
	FG8_FSCALEB = 3'd3
} float_g8_t;

typedef enum logic [4:0] {
	FG10_FCVTF2I = 5'd0,
	FG10_FCVTI2F = 5'd1,
	FG10_FSIGN = 5'd16,
	FG10_FSQRT = 5'd17,
	FG10_FTRUNC = 5'd18
} float_g10_t;

typedef enum logic [4:0] {
	FTRIG_FCOS = 5'd0,
	FTRIG_FSIN = 5'd1
} float_trig_t;

typedef enum logic [3:0] {
	CND_EQ = 4'd0,
	CND_NE = 4'd1,
	CND_LT = 4'd2,
	CND_LE = 4'd3,
	CND_GE = 4'd4,
	CND_GT = 4'd5,
	CND_NAND = 4'd8,
	CND_AND = 4'd9,
	CND_NOR = 4'd10,
	CND_OR = 4'd11,
	CND_BOI = 4'd15
} cnd_e;

parameter NOP_INSN = {26'd0,OP_NOP};

typedef struct packed
{
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic [49:0] payload;
	logic [6:0] opcode;
} anyinst_t;

typedef struct packed
{
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic resv2;
	logic [1:0] prc;
	logic md;
	logic [3:0] resv;
	logic [19:0] disp;
	regspec_t Rs2;
	regspec_t Rs1;
	logic [1:0] ms;
	logic [3:0] cnd;
	opcode_e opcode;
} br_inst_t;

typedef struct packed
{
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic resv2;
	logic [1:0] prc;
	logic md;
	logic [15:0] resv;
	regspec_t Rs3;
	regspec_t Rs2;
	regspec_t Rs1;
	logic [1:0] ms;
	logic [3:0] cnd;
	opcode_e opcode;
} brr_inst_t;

typedef struct packed
{
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic resv2;
	logic [5:0] resv;
	logic [34:0] disp;
	regspec_t Rd;
	opcode_e opcode;
} bsr_inst_t;

typedef struct packed
{
/*
	logic [15:0] mor;
	logic zero;
	logic [1:0] maskhi;
	logic [2:0] one3;
	logic [5:0] ipl;
	logic [10:0] masklo;
	logic [2:0] seven;
	logic [4:0] opcode;
	logic m0;
*/
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic resv2;
	logic [48:0] resv;
	opcode_e opcode;
} atom_inst_t;

typedef struct packed
{
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic resv2;
	logic [2:0] sc;
	logic ms;
	logic [1:0] resv;
	logic [18:0] disp;
	regspec_t Rs2;
	regspec_t Rs1;
	regspec_t Rsd;
	opcode_e opcode;
} ls_inst_t;

typedef struct packed
{
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic resv2;
	logic [6:0] func;
	logic [2:0] ms;
	logic [2:0] ar;
	logic [3:0] vn;
	regspec_t Rs3;
	regspec_t Rs2;
	regspec_t Rs1;
	regspec_t Rd;
	opcode_e opcode;
} amo_inst_t;

typedef struct packed
{
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic resv2;
	logic [6:0] func;
	logic [2:0] ms;
	logic [2:0] ar;
	logic [3:0] vn;
	regspec_t Rs3;
	regspec_t Rs2;
	regspec_t Rs1;
	regspec_t Rd;
	opcode_e opcode;
} cas_inst_t;

typedef struct packed
{
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic resv2;
	logic [1:0] pr;
	logic [3:0] resv;
	logic [26:0] imm;
	regspec_t Rs1;
	regspec_t Rd;
	opcode_e opcode;
} alui_inst_t;

typedef struct packed
{
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic resv2;
	logic [6:0] func;
	logic [2:0] ms;
	logic [2:0] op3;
	logic [3:0] vn;
	regspec_t Rs3;
	regspec_t Rs2;
	regspec_t Rs1;
	regspec_t Rd;
	opcode_e opcode;
} alu_inst_t;

typedef struct packed
{
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic resv2;
	logic [6:0] func;
	logic [2:0] ms;
	logic [2:0] op3;
	logic [3:0] vn;
	regspec_t Rs3;
	regspec_t Rs2;
	regspec_t Rs1;
	regspec_t Rd;
	opcode_e opcode;
} r3_inst_t;

typedef struct packed
{
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic resv2;
	flt_e func;
	logic [2:0] ms;
	logic [2:0] rm;
	logic [3:0] vn;
	regspec_t Rs3;
	regspec_t Rs2;
	regspec_t Rs1;
	regspec_t Rd;
	opcode_e opcode;
} f3_inst_t;

typedef struct packed
{
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic resv2;
	logic [6:0] func;
	logic [2:0] ms;
	logic [2:0] op3;
	logic [3:0] vn;
	regspec_t Rs3;
	regspec_t Rs2;
	regspec_t Rs1;
	regspec_t Rd;
	opcode_e opcode;
} sh_inst_t;

typedef struct packed
{
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic resv2;
	logic [6:0] func;
	logic [2:0] ms;
	logic [2:0] rm;
	logic [3:0] vn;
	regspec_t Rs3;
	regspec_t Rs2;
	regspec_t Rs1;
	regspec_t Rd;
	opcode_e opcode;
} sra_inst_t;

typedef struct packed
{
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic resv2;
	logic [2:0] op3;
	logic [2:0] ms;
	logic [13:0] regno;
	logic [12:0] resv;
	regspec_t Rs1;
	regspec_t Rd;
	opcode_e opcode;
} csr_inst_t;

typedef struct packed
{
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic resv2;
	logic [2:0] op3;
	logic [2:0] immH;
	logic [13:0] regno;
	logic [5:0] resv;
	logic [14:0] imm;
	regspec_t Rd;
	opcode_e opcode;
} csri_inst_t;

typedef struct packed
{
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic resv2;
	logic [48:0] resv;
	opcode_e opcode;
} brk_inst_t;

typedef struct packed
{
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic resv2;
	logic [6:0] func;
	logic [2:0] ms;
	logic [2:0] op3;
	logic [3:0] vn;
	regspec_t Rs3;
	regspec_t Rs2;
	regspec_t Rs1;
	regspec_t Rd;
	opcode_e opcode;
} chk_inst_t;

typedef struct packed
{
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic resv2;
	logic [1:0] resv;
	logic [22:0] imm;
	regspec_t Rs2;
	regspec_t Rs1;
	regspec_t Rd;
	opcode_e opcode;
} enter_inst_t;

typedef struct packed
{
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic resv2;
	logic [6:0] func;
	logic [2:0] ms;
	logic [2:0] op3;
	logic [3:0] vn;
	regspec_t Rs3;
	regspec_t Rs2;
	regspec_t Rs1;
	regspec_t Rd;
	opcode_e opcode;
} cmov_inst_t;

typedef struct packed
{
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic resv2;
	logic [6:0] func;
	logic [2:0] ms;
	logic [2:0] op3;
	logic [3:0] vn;
	regspec_t Rs3;
	logic [3:0] resv;
	logic [1:0] Rs1h;
	logic [1:0] Rdh;
	regspec_t Rs1;
	regspec_t Rd;
	opcode_e opcode;
} move_inst_t;

typedef struct packed
{
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic resv2;
	logic [6:0] func;
	logic [2:0] ms;
	logic [2:0] op3;
	logic [3:0] vn;
	regspec_t Rs3;
	regspec_t Rs2;
	regspec_t Rs1;
	regspec_t Rd;
	opcode_e opcode;
} bmap_inst_t;

typedef struct packed
{
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic resv2;
	logic [6:0] func;
	logic [2:0] ms;
	fround_t rm;
	logic [3:0] vn;
	regspec_t Rs3;
	regspec_t Rs2;
	regspec_t Rs1;
	regspec_t Rd;
	opcode_e opcode;
} fpu_inst_t;

typedef struct packed
{
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	regspec_t Rs4;
	logic [2:0] ms;
	logic [2:0] op3;
	logic [3:0] vn;
	regspec_t Rs3;
	regspec_t Rs2;
	regspec_t Rs1;
	regspec_t Rd;
	opcode_e opcode;
} extd_inst_t;

typedef struct packed
{
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic resv2;
	logic [2:0] sc;
	logic ms;
	logic [9:0] disp;
	logic [2:0] dt;
	regspec_t Rs3;
	regspec_t Rs2;
	regspec_t Rs1;
	regspec_t Rd;
	opcode_e opcode;
} vls_inst_t;

typedef union packed
{
	alui_inst_t cmpi;
	alu_inst_t cmp;
	br_inst_t br;
	brr_inst_t brr;
	bsr_inst_t bsr;
	bsr_inst_t jsr;
	atom_inst_t atom;
	ls_inst_t ls;
	amo_inst_t amo;
	cas_inst_t cas;
	alui_inst_t alui;
	alu_inst_t alu;
	r3_inst_t r3;
	f3_inst_t f3;
	fpu_inst_t fpu;
	sh_inst_t sh;
	sra_inst_t sra;
	sh_inst_t rot;
	csri_inst_t csri;
	csr_inst_t csr;
	brk_inst_t brk;
	chk_inst_t chk;
	enter_inst_t enter;
	enter_inst_t leave;
	move_inst_t move;
	cmov_inst_t cmov;
	bmap_inst_t bmap;
	extd_inst_t extd;
	vls_inst_t vls;
	anyinst_t any;
} micro_op_t;

parameter CSR_SR		= 16'h?004;
parameter CSR_CAUSE	= 16'h?006;
parameter CSR_REPBUF = 16'h0008;
parameter CSR_MAXVL	= 16'h0200;
parameter CSR_MAXVLB= 16'h0201;
parameter CSR_SEMA	= 16'h?00C;
parameter CSR_PTBR	= 16'h1003;
parameter CSR_HMASK	= 16'h1005;
parameter CSR_FSTAT	= 16'h?014;
parameter CSR_ASID	= 16'h101F;
parameter CSR_KEYS	= 16'b00010000001000??;
parameter CSR_KEYTBL= 16'h1024;
parameter CSR_SCRATCH=16'h?041;
parameter CSR_MCR0	= 16'h3000;
parameter CSR_MHARTID = 16'h3001;
parameter CSR_MCORENO = 16'h3001;
parameter CSR_TICK	= 16'h3002;
parameter CSR_MBADADDR	= 16'h3007;
parameter CSR_MTVEC = 16'b00110000001100??;
parameter CSR_MDBAD	= 16'b00110000000110??;
parameter CSR_MDBAM	= 16'b00110000000111??;
parameter CSR_MDBCR	= 16'h3020;
parameter CSR_MDBSR	= 16'h3021;
parameter CSR_KVEC3 = 16'h3033;
parameter CSR_MPLSTACK	= 16'h303F;
parameter CSR_MPMSTACK	= 16'h3040;
parameter CSR_MSTUFF0	= 16'h3042;
parameter CSR_MSTUFF1	= 16'h3043;
parameter CSR_USTATUS	= 16'h0044;
parameter CSR_SSTATUS	= 16'h1044;
parameter CSR_HSTATUS	= 16'h2044;
parameter CSR_MSTATUS	= 16'h3044;
parameter CSR_MVSTEP= 16'h3046;
parameter CSR_MVTMP	= 16'h3047;
parameter CSR_MEIP	=	16'h3048;
parameter CSR_MECS	= 16'h3049;
parameter CSR_MPCS	= 16'h304A;
parameter CSR_UCA		=	16'b00000001000?????;
parameter CSR_SCA		=	16'b00010001000?????;
parameter CSR_HCA		=	16'b00100001000?????;
parameter CSR_MCA		=	16'b00110001000?????;
parameter CSR_MSEL	= 16'b0011010000100???;
parameter CSR_MTCBPTR=16'h3050;
parameter CSR_MGDT	= 16'h3051;
parameter CSR_MLDT	= 16'h3052;
parameter CSR_MTCB	= 16'h3054;
parameter CSR_CTX		= 16'h3053;
parameter CSR_MBVEC	= 16'b0011000001011???;
parameter CSR_MSP		= 16'h3060;
parameter CSR_SR_STACK		= 16'h308?;
parameter CSR_MCIR_STACK 	= 16'h309?;
parameter CSR_MEPC	= 16'h3108;
parameter CSR_TIME	= 16'h?FE0;
parameter CSR_MTIME	= 16'h3FE0;
parameter CSR_MTIMECMP	= 16'h3FE1;

/*
typedef struct packed {
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic [3:0] xop4;
	logic [7:0] Rs4;
	logic [2:0] ms;
	logic [2:0] op3;
	logic [3:0] vn;
	logic [7:0] Rs3;
	logic [7:0] Rs2;
	logic [7:0] Rs1;
	logic [7:0] Rd;
	logic [6:0] opcode;
} micro_op_t;

typedef struct packed {
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic [3:0] xop4;
	logic [2:0] sc;
	logic ms;
	logic [5:0] disp;
	logic [2:0] dt;
	logic [7:0] Rs3;
	logic [7:0] Rs2;
	logic [7:0] Rs1;
	logic [7:0] Rd;
	logic [6:0] opcode;
} vls_uop_t;
*/

typedef struct packed {
	cpu_types_pkg::pc_address_ex_t pc;
	logic [5:0] pred_btst;
	micro_op_t ins;
} ex_instruction_t;

typedef enum logic [7:0] {
	FLT_DBG		= 8'h00,
	FLT_SSM		= 8'h01,
	FLT_BERR	= 8'h02,
	FLT_ALN		= 8'h03,
	FLT_UNIMP	= 8'h04,
	FLT_PRIV	= 8'h05,
	FLT_PAGE	= 8'h06,
	FLT_TRACE	= 8'h07,
	FLT_CANARY= 8'h08,
	FLT_ABORT	= 8'h09,
	FLT_IRQ		= 8'h0A,
	FLT_NMI		= 8'h0B,
	FLT_RST		= 8'h0C,
	FLT_ALT		= 8'h0D,
	FLT_DBZ		= 8'h10,
	FLT_CHK		= 8'h43,
	FLT_PRED  = 8'hDE,
	FLT_BADREG = 8'hDF,
	FLT_CAPTAG = 8'hE0,
	FLT_CAPOTYPE = 8'hE1,
	FLT_CAPPERMS = 8'hE2,
	FLT_CAPBOUNDS = 8'hE4,
	FLT_CAPSEALED = 8'hE5,
	FLT_NONE 	= 8'hFF
} cause_code_t;

typedef enum logic [4:0] {
	MR_NOP = 5'd0,
	MR_LOAD = 5'd1,
	MR_LOADZ = 5'd2,
	MR_STORE = 5'd3,
	MR_STOREPTR = 5'd4,
//	MR_TLBRD = 5'd4,
//	MR_TLBRW = 5'd5,
	MR_TLB = 5'd6,
	MR_LEA = 5'd7,
	MR_MOVLD = 5'd8,
	MR_MOVST = 5'd9,
	MR_RGN = 5'd10,
	MR_ICACHE_LOAD = 5'd11,
	MR_PTG = 5'd12,
	MR_CACHE = 5'd13,
	MR_ADD = 5'd16,
	MR_AND = 5'd17,
	MR_OR	= 5'd18,
	MR_EOR = 5'd19,
	MR_ASL = 5'd20,
	MR_LSR = 5'd21,
	MR_MIN = 5'd22,
	MR_MAX = 5'd23,
	MR_CAS = 5'd24
} memop_t;

typedef enum logic [3:0] {
	nul = 4'd0,
	byt = 4'd1,
	wyde = 4'd2,
	tetra = 4'd3,
	penta = 4'd4,
	octa = 4'd5,
	hexi = 4'd6,
	dodeca = 4'd7,
	char = 4'd8,
	vect = 4'd10,
	mem72 = 4'd11
} memsz_t;

typedef struct packed
{
	logic v;
	logic [4:0] Rs4;
	logic [4:0] Rs3;
	logic [4:0] Rd2;
} regs_t;

typedef struct packed
{
	logic cap;		// capabilities tag
	logic ptr;		// register contains a pointer
	logic cry;		// carry
	logic ovf;		// overflow
	logic [3:0] user;
//	logic [7:0] ecc;	// error correcting bits
} flags_t;

typedef struct packed
{
	logic v;
	cpu_types_pkg::aregno_t aRn;
	logic aRnz;
	cpu_types_pkg::pregno_t pRn;
	flags_t flags;
	cpu_types_pkg::value_t val;
} operand_t;


// Holds the sizes of lanes for vector operations.

typedef struct packed
{
	logic [39:0] reserved;
	logic [4:0] resv3;
	logic [2:0] address_size;
	logic [4:0] resv2;
	logic [2:0] float_size;
	logic [4:0] resv1;
	logic [2:0] int_size;
} velsz_t;

typedef struct packed
{
	logic v;
	cpu_types_pkg::aregno_t Rci;		// carry input
	cpu_types_pkg::aregno_t Rs1;
	cpu_types_pkg::aregno_t Rs2;
	cpu_types_pkg::aregno_t Rs3;
	cpu_types_pkg::aregno_t Rs4;
	cpu_types_pkg::aregno_t Rd;
	cpu_types_pkg::aregno_t Rd2;
	cpu_types_pkg::aregno_t Rd3;
	cpu_types_pkg::aregno_t Rco;		// carry output
	logic Rs1z;
	logic Rs2z;
	logic Rs3z;
	logic Rs4z;
	logic Rdz;
	logic Rd2z;
	logic Rd3z;
	logic has_Rs2;
	logic has_imm;
	logic has_imma;
	logic has_immb;
	logic has_immc;
	logic has_immd;
	cpu_types_pkg::value_t imma;
	cpu_types_pkg::value_t immb;
	cpu_types_pkg::value_t immc;
	cpu_types_pkg::value_t immd;		// for store immediate
	logic csr;				// CSR instruction
	logic nop;				// NOP semantics
	logic fc;					// flow control op
	logic backbr;			// backwards target branch
	bts_t bts;				// branch target source
	logic macro;			// true if macro instruction
	logic alu;				// true if instruction must use alu (alu or mem)
	logic alu0;				// true if instruction must use only alu #0
	logic sau;
	logic sau0;
	logic sqrt;
	logic alu_pair;		// true if instruction requires pair of ALUs
	logic fpu;				// FPU op
	logic fpu0;				// true if instruction must use only fpu #0
	logic fma;
	logic trig;
	fround_t rm;
	memsz_t prc;			// precision of operation
	logic mul;
	logic mula;
	logic div;
	logic diva;
	logic bitwise;		// true if a bitwise operator (and, or, eor)
	logic multicycle;
	logic mem;
	logic mem0;				// true if instruction must use only port #0
	logic v2p;				// virtual to physical instruction
	logic vv2p;				// vector virtual to physical
	logic vvn2p;			// indexed vector virtual to physical
	logic amo;
	logic iprel;
	logic load;
	logic loadz;
	logic vload;				// vector load
	logic vload_ndx;		// indexed vector load
	logic store;
	logic stptr;
	logic vstore;				// vector store
	logic vstore_ndx;		// indexed vector store
	logic bstore;
	logic push;
	logic pop;
	logic [2:0] count;
	logic cls;
	logic loada;
	logic erc;
	logic fence;
	logic mcb;					// micro-code branch

	logic bcc;					// conditional branch
	logic cjb;					// call, jmp, or bra
	logic jsri;					// indirect subroutine call
	logic br;
	logic bsr;
	logic jsr;
	logic pbr;
	logic ret;
	logic boi;
	logic eret;
	
	logic brk;
	logic irq;
	logic rex;
	logic pfx;
	logic sync;
	logic oddball;
	logic pred;					// predicate instruction
	logic [11:0] pred_mask;
	logic [11:0] pred_atom_mask;
	logic [3:0] pred_shadow_size;
	logic carry;
	logic atom;
	logic regs;
	logic fregs;
	regs_t xregs;				// "extra" registers from fregs/regs instruction
	logic cpytgt;
	logic qfext;				// true if QFEXT modifier
	cause_code_t cause;
} decode_bus_t;

typedef struct packed {
	logic v;
	logic excv;								// 1=exception
	logic [5:0] handle;
	logic [1:0] nstate;				// number of states
	logic [1:0] state;				// current state
	decode_bus_t decbus;			// decoded instruction
	logic done;
	cpu_types_pkg::value_t argA;
	cpu_types_pkg::value_t argB;
	cpu_types_pkg::value_t argC;
	cpu_types_pkg::value_t argI;
	cpu_types_pkg::value_t argD;
	cpu_types_pkg::value_t argM;
	cpu_types_pkg::value_t res;
	cpu_types_pkg::pregno_t pRc;
	logic argC_v;
	cpu_types_pkg::checkpt_ndx_t cndx;				// checkpoint index
	ex_instruction_t op;			// original instruction
	cpu_types_pkg::pc_address_ex_t pc;			// PC of instruction
	cpu_types_pkg::mc_address_t mcip;				// Micro-code IP address
} beb_entry_t;

typedef struct packed {
	logic v;
	logic [1:0] state;		// 00=run first bus cycle, 01=run second bus cycle, 11=done
	cpu_types_pkg::seqnum_t sn;
	logic agen;						// address generated through to physical address
	cpu_types_pkg::rob_ndx_t rndx;				// reference to related ROB entry
	cpu_types_pkg::virtual_address_t vadr;
	cpu_types_pkg::physical_address_t padr;
	// micro-op decodes
	logic v2p;						// 1=doing a virtual to physical address translation
	logic load;						// 1=load
	logic loadz;
	logic cload;					// 1=cload
	logic cload_tags;
	logic store;
	logic stptr;
	logic cstore;
	logic vload;
	logic vload_ndx;
	logic vstore;
	logic vstore_ndx;

	cpu_types_pkg::pc_address_ex_t pc;
	memop_t func;					// operation to perform
	logic [3:0] func2;		// more resolution to function
	cause_code_t cause;
//	logic [3:0] cache_type;
	logic [63:0] sel;			// +16 for unaligned accesses
//	cpu_types_pkg::asid_t asid;
//	cpu_types_pkg::code_address_t vcadr;		// victim cache address
//	logic dchit;
	memsz_t memsz;				// indicates size of data
	logic [7:0] bytcnt;		// byte count of data to load/store
	logic [6:0] shift;		// amount to shift data
	cpu_types_pkg::pregno_t Rt;
	cpu_types_pkg::aregno_t aRt;					// reference for freeing
	logic aRtz;
	cpu_types_pkg::aregno_t aRc;
	cpu_types_pkg::pregno_t pRc;					// 'C' register for store
	cpu_types_pkg::checkpt_ndx_t cndx;
	operating_mode_t om;	// operating mode
	flags_t flags;	// capabilities tag / carry / overflow / parity
	logic datav;					// store data is valid
	logic [511:0] res;		// stores unaligned data as well (must be last field)
} lsq_entry_t;

typedef struct packed
{
	logic [1:0] state;
	operand_t oper;
	operating_mode_t om;
	cause_code_t exc;
	cpu_types_pkg::checkpt_ndx_t cndx;
	cpu_types_pkg::rob_ndx_t rndx;
} dram_oper_t;

typedef struct packed
{
	logic v;
	cause_code_t exc;
	operating_mode_t om;
	cpu_types_pkg::rob_ndx_t rndx;
	logic rndxv;
	cpu_types_pkg::checkpt_ndx_t cndx;
	cpu_types_pkg::aregno_t pRd;
	cpu_types_pkg::aregno_t aRd;
	logic aRdz;
	logic bank;
	micro_op_t op;
	cpu_types_pkg::pc_address_t pc;
	logic load;
	logic loadz;
	logic vload;
	logic vload_ndx;
	logic cload;
	logic cload_tags;
	logic store;
	logic stptr;
	logic vstore;
	logic vstore_ndx;
	logic cstore;
	logic erc;
	logic hi;
	logic [79:0] sel;
	logic [79:0] selh;
	cpu_types_pkg::virtual_address_t vaddr;
	cpu_types_pkg::virtual_address_t vaddrh;
	cpu_types_pkg::physical_address_t paddr;
	cpu_types_pkg::physical_address_t paddrh;
	logic [767:0] data;
	logic [767:0] datah;
	logic [8:0] shift;
	logic ctag;
	memsz_t memsz;
	fta_bus_pkg::fta_tranid_t tid;
	logic [11:0] tocnt;
}	dram_work_t;

typedef struct packed
{
	logic v;
	logic rstp;								// indicate physical register reset required
	cpu_types_pkg::pc_address_t brtgt;
	logic takb;								// 1=branch evaluated to taken
	logic ssm;								// 1=single step mode active
	logic hwi;
	logic [5:0] hwi_level;
	logic [2:0] hwi_swstk;		// software stack
	cause_code_t exc;					// non-0xFF indicate exception
	logic excv;								// 1=exception
	// The following fields are loaded at enqueue time, but otherwise do not change.
	logic bt;									// branch to be taken as predicted
	operating_mode_t om;			// operating mode
	reg [31:0] carry_mod;			// carry modifier remnant
	reg [11:0] atom_mask;			// interrupt masking by ATOM instruction
	cpu_types_pkg::pregno_t pRs1;							// physical registers (see decode bus for arch. regs)
	cpu_types_pkg::pregno_t pRs2;
	cpu_types_pkg::pregno_t pRs3;
	cpu_types_pkg::pregno_t pRs4;
	cpu_types_pkg::pregno_t pRd;						// current Rd value
	cpu_types_pkg::pregno_t nRd;						// new Rd
	logic pRs1v;
	logic pRs2v;
	logic pRs3v;
	logic pRs4v;
	logic pRdv;
	logic nRdv;
	logic [5:0] cli;												// 16-bit parcel cache line index of instruction
	cpu_types_pkg::pc_address_ex_t pc;			// PC of instruction
	cpu_types_pkg::pc_address_ex_t hwipc;		// PC of instruction
	micro_op_t uop;
	decode_bus_t decbus;
} pipeline_reg_t;

typedef struct packed
{
	logic [5:0] level;
	logic [2:0] om;
	logic [2:0] swstk;
	logic [63:0] vector;
} irq_info_packet_t;

typedef struct packed {
	logic v;
	logic busy;
	logic ready;
	logic [3:0] funcunit;							// functional unit dispatched to
	cpu_types_pkg::seqnum_t irq_sn;
	cpu_types_pkg::rob_ndx_t rndx;		// associated ROB entry
	cpu_types_pkg::checkpt_ndx_t cndx;
	micro_op_t uop;
	logic has_rext;
	cause_code_t exc;
	logic nan;
	// needed only for mem
	logic virt2phys;
	logic iprel;				// IP relative addressing Rs1 spec'd as r31
	logic load;
	logic store;
	logic amo;
	logic push;
	logic pop;
	logic [2:0] count;
	// decodes only needed for branch
	logic bcc;					// conditional branch
	logic cjb;					// call, jmp, or bra
	logic jsri;					// indirect subroutine call
	logic bsr;
	logic jsr;
	logic br;
	logic pbr;
	logic ret;
	logic boi;
	logic eret;

	logic bt;												
	// - - - - - - - - - - - - - - - - 
	memsz_t prc;
	logic [$bits(cpu_types_pkg::value_t)/8-1:0] copydst;
	logic aRdz;
	logic Rs1z;
	logic Rs2z;
	cpu_types_pkg::aregno_t aRd;
	cpu_types_pkg::pregno_t nRd;
	operating_mode_t om;						// needed for mem ops
	fround_t rm;										// needed for float-ops
	cpu_types_pkg::pc_address_t pc;
//	logic [63:0] pch;
	cpu_types_pkg::value_t argI;
	operand_t [NOPER-1:0] arg;
	operand_t [NOPER-1:0] argH;			// high order 64-bits of 128-bit arg
} reservation_station_entry_t;

typedef struct packed {
	// The following fields may change state while an instruction is processed.
	logic v;									// 1=entry is valid, in use
	cpu_types_pkg::seqnum_t sn;							// sequence number, decrements when instructions que
	logic flush;
	cpu_types_pkg::rob_ndx_t sync_dep;			// sync instruction dependency
	logic sync_depv;				// sync dependency valid
	cpu_types_pkg::rob_ndx_t fc_dep;				// flow control dependency - relevant only for mem ops
	logic fc_depv;					// flow control dependency valid
	logic [3:0] predino;			// predicated instruction number (1 to 8)
	cpu_types_pkg::rob_ndx_t predrndx;				// ROB index of associate PRED instruction
	cpu_types_pkg::rob_ndx_t orid;						// ROB id of originating macro-instruction
	logic lsq;								// 1=instruction has associated LSQ entry
	lsq_ndx_t lsqndx;					// index to LSQ entry
	logic [1:0] out;					// 1=instruction is being executed
	logic [1:0] done;					// 2'b11=instruction is finished executing
	logic rstp;								// indicate physical register reset required
	logic [1:0] vn;						// vector index
	logic chkpt_freed;
	cpu_types_pkg::pc_address_t brtgt;
//	cpu_types_pkg::mc_address_t mcbrtgt;			// micro-code branch target
	logic takb;								// 1=branch evaluated to taken
	cause_code_t exc;					// non-zero indicate exception
	logic excv;								// 1=exception
	logic nan;								// FP op generated a NaN
	cpu_types_pkg::value_t argC;	// for stores
`ifdef IS_SIM
	cpu_types_pkg::value_t argA;
	cpu_types_pkg::value_t argB;
	cpu_types_pkg::value_t argI;
	cpu_types_pkg::value_t argD;
	cpu_types_pkg::value_t res;
`endif
	/*
	logic updAv;
	logic updBv;
	logic updCv;
	cpu_types_pkg::value_t updA;
	cpu_types_pkg::value_t updB;
	cpu_types_pkg::value_t updC;
	cpu_types_pkg::value_t updD;
	cpu_types_pkg::pregno_t updAreg;
	cpu_types_pkg::pregno_t updBreg;
	cpu_types_pkg::pregno_t updCreg;
	cpu_types_pkg::pregno_t updDreg;
	*/
	logic [1:0] pred_tf;			// true(1)/false(2)/unknown(0)
	logic [5:0] pred_no;			// predicate number
	logic [3:0] pred_shadow_size;	// number of instructions in shadow
	logic [11:0] pred_mask;		// predicte mask bits for this instruction.
	logic pred_bit;						// 1 once previous predicate is true or ignored
	logic pred_bitv;					// 1 if predicate bitis valid
	logic all_args_valid;			// 1 if all args are valid
	logic could_issue;				// 1 if instruction ready to issue
	logic could_issue_nm;			// 1 if instruction ready to issue NOP
	logic prior_sync;					// 1 if instruction has sync prior to it
	logic prior_fc;						// 1 if instruction has fc prior to it
	/*
	logic argA_vp;						// 1=argument A valid pending
	logic argB_vp;
	logic argC_vp;
	logic argD_vp;
	logic argT_vp;
	*/
	logic argA_v;							// 1=argument A valid
	logic argB_v;
	logic argC_v;
	logic argD_v;
	logic argT_v;
	logic rat_v;							// 1=checked with RAT for valid reg arg.
	cpu_types_pkg::value_t arg;							// argument value for CSR instruction
	// The following fields are loaded at enqueue time, but otherwise do not change.
	logic last;								// 1=last instruction in group (not used)
	cpu_types_pkg::rob_ndx_t group_len;			// length of instruction group (not used)
	logic bt;									// branch to be taken as predicted
	logic [7:0] laneno;				// current lane number
	logic [5:0] data_bitpos;	// position of data to load / store
	operating_mode_t om;			// operating mode
	fround_t rm;							// float round mode
	cpu_types_pkg::checkpt_ndx_t cndx;				// checkpoint index
	cpu_types_pkg::checkpt_ndx_t br_cndx;		// checkpoint index branch owns
	cpu_types_pkg::seqnum_t grp;							// instruction group
	pipeline_reg_t op;			// original instruction
} rob_entry_t;

typedef struct packed
{
	logic v;														// group header is valid
	cpu_types_pkg::seqnum_t sn;					// sequence number, decrements when instructions que
	cpu_types_pkg::seqnum_t irq_sn;			// sequence number, increments for each interrupt
	reg [5:0] old_ipl;
	logic hwi;													// hardware interrupt occured during fetch
	irq_info_packet_t irq;							// the level of the hardware interrupt
	logic cndxv;												// checkpoint index is valid
	cpu_types_pkg::checkpt_ndx_t cndx;	// checkpoint index
	logic chkpt_freed;
	logic has_branch;
	logic done;
} pipeline_group_hdr_t;

typedef struct packed
{
	pipeline_group_hdr_t hdr;
	rob_entry_t pr0;
	rob_entry_t pr1;
	rob_entry_t pr2;
	rob_entry_t pr3;
} pipeline_group_reg_t;

// ============================================================================
// Support Functions
// ============================================================================

function cpu_types_pkg::pc_address_t fnAddToIP;
input cpu_types_pkg::pc_address_t ip;
input [5:0] amt;
begin
	case(amt)
	6'd6:
		case (ip[5:0])
		6'd54:	fnAddToIP = ip + 64'd10;
		default:	fnAddToIP = ip + amt;
		endcase
	6'd12:
		case (ip[5:0])
		6'd48:	fnAddToIP = ip + 64'd16;
		6'd54:	fnAddToIP = ip + 64'd22;
		default:	fnAddToIP = ip + amt;
		endcase
	6'd18:
		case (ip[5:0])
		6'd42:	fnAddToIP = ip + 64'd22;
		6'd48:	fnAddToIP = ip + 64'd28;
		6'd54:	fnAddToIP = ip + 64'd28;
		default:	fnAddToIP = ip + amt;
		endcase
	6'd24:
		case (ip[5:0])
		6'd36:	fnAddToIP = ip + 64'd28;
		6'd42:	fnAddToIP = ip + 64'd34;
		6'd48:	fnAddToIP = ip + 64'd34;
		6'd54:	fnAddToIP = ip + 64'd34;
		default:	fnAddToIP = ip + amt;
		endcase
	default:	fnAddToIP = ip;
	endcase
end
endfunction

function cpu_types_pkg::pc_address_t fnTargetIP;
input cpu_types_pkg::pc_address_t ip;
input cpu_types_pkg::value_t tgt;
begin
	fnTargetIP = ip+{tgt,1'b0};
end
endfunction

function fnHasExConst;
input micro_op_t ins;
begin
	case(ins.any.opcode)
	OP_BRK,OP_SHIFT,OP_CSR,OP_CHK,
	OP_PUSH,OP_POP,	// ENTER,LEAVE,PUSH,POP
	OP_FENCE,OP_BLOCK,OP_FLTD,
	OP_AMO:	// AMO
		fnHasExConst = 1'b0;
	default:	fnHasExConst = 1'b1;
	endcase
end
endfunction

function fnIsShift;
input micro_op_t ins;
begin
	fnIsShift = ins.any.opcode == OP_SHIFT;
end
endfunction

function [2:0] fnDecMs;
input micro_op_t ins;
begin
	if (fnIsShift(ins))
		fnDecMs = ins[41:39];
	else if (fnIsBranch(ins))
		fnDecMs = {1'b0,ins[12:11]};
	else
		fnDecMs = ins[40:38];
end
endfunction

function fnHasConstRs1;
input micro_op_t ins;
begin
	case(ins.any.opcode)
	OP_BRK,OP_SHIFT,OP_CSR,OP_CHK,
	OP_PUSH,OP_POP,	// ENTER,LEAVE,PUSH,POP
	OP_FENCE,OP_BLOCK,OP_FLTD,
	OP_AMO:	// AMO
		fnHasConstRs1 = 1'b0;
	default:	fnHasConstRs1 = 1'b1;
	endcase
end
endfunction

function fnHasConstRs2;
input micro_op_t ins;
begin
	case(ins.any.opcode)
	OP_BRK,OP_SHIFT,OP_CSR,OP_CHK,
	OP_PUSH,OP_POP,	// ENTER,LEAVE,PUSH,POP
	OP_FENCE,OP_BLOCK,OP_FLTD,
	OP_AMO:	// AMO
		fnHasConstRs2 = 1'b0;
	default:	fnHasConstRs2 = 1'b1;
	endcase
end
endfunction

function fnHasConstRs3;
input micro_op_t ins;
begin
	case(ins.any.opcode)
	OP_BRK,OP_SHIFT,OP_CSR,OP_CHK,
	OP_PUSH,OP_POP,	// ENTER,LEAVE,PUSH,POP
	OP_FENCE,OP_BLOCK,OP_FLTD,
	OP_AMO:	// AMO
		fnHasConstRs3 = 1'b0;
	default:	fnHasConstRs3 = 1'b1;
	endcase
end
endfunction

function fnIsStimm;
input micro_op_t ins;
begin
	case(ins.any.opcode)
	OP_STI:
		fnIsStimm = 1'b0;
	default:
		fnIsStimm = 1'b1;
	endcase
end
endfunction


// Decodes the constant position from an instruction.
// Three positions are returned. The lower four bits are the base constant
// position, and the upper four bits are the location of a store immediate
// constant.

function [11:0] fnConstPos;
input micro_op_t ins;
reg [2:0] ms;
begin
	ms = fnDecMs(ins);
	fnConstPos = 8'd0;
	if (Qupls4_pkg::fnHasConstRs1(ins)) begin	// does instruction have an extendable constant?
		if (ms[0])
			fnConstPos[3:0] = ins.alu.Rs1[3:0];
	end
	if (Qupls4_pkg::fnHasConstRs2(ins)) begin	// does instruction have an extendable constant?
		if (ms[1])
			fnConstPos[7:4] = ins.alu.Rs2[3:0];
	end
	if (Qupls4_pkg::fnHasConstRs3(ins)) begin	// does instruction have an extendable constant?
		if (ms[2])
			fnConstPos[11:8] = ins.alu.Rs3[3:0];
	end
	if (fnIsStimm(ins))
		fnConstPos[3:0] = ins.alu.Rd[3:0];
end
endfunction

function [5:0] fnConstSize;
input micro_op_t ins;
reg [2:0] ms;
begin
	ms = fnDecMs(ins);
	fnConstSize = 6'd0;
	if (Qupls4_pkg::fnHasConstRs1(ins)) begin	// does instruction have an extendable constant?
		if (ms[0])
			fnConstSize[1:0] = ins.alu.Rs1[5:4];
	end
	if (Qupls4_pkg::fnHasConstRs2(ins)) begin	// does instruction have an extendable constant?
		if (ms[1])
			fnConstSize[3:2] = ins.alu.Rs2[5:4];
	end
	if (Qupls4_pkg::fnHasConstRs3(ins)) begin	// does instruction have an extendable constant?
		if (ms[2])
			fnConstSize[5:4] = ins.alu.Rs3[5:4];
	end
	if (fnIsStimm(ins))
		fnConstSize[1:0] = ins.alu.Rd[5:4];
end
endfunction

// ATOM
function fnIsAtom;
input micro_op_t ir;
begin
	fnIsAtom = ir.any.opcode[5:1]==5'd12 && ir[8:6]==3'd7 && ir[31:29]==3'd0 && ir[28:26]==3'd1;
end
endfunction

function fnIsCarry;
input micro_op_t ir;
begin
	fnIsCarry = ir.any.opcode[5:1]==5'd12 && ir[8:6]==3'd7 && ir[31:29]==3'd0 && ir[28:26]==3'd2;
end
endfunction

// Sign or zero extend data as needed according to op.
function [63:0] fnDati;
input more;
input micro_op_t ins;
input cpu_types_pkg::value_t dat;
case(ins.any.opcode)
OP_LDB:		fnDati = {{56{dat[7]}},dat[7:0]};
OP_LDBZ:	fnDati = {{56{1'b0}},dat[7:0]};
OP_LDW:		fnDati = {{48{dat[15]}},dat[15:0]};
OP_LDWZ:	fnDati = {{48{1'b0}},dat[15:0]};
OP_LDT:		fnDati = {{32{dat[31]}},dat[31:0]};
OP_LDTZ:	fnDati = {{32{1'b0}},dat[31:0]};
OP_LOAD:	fnDati = dat[63:0];
default:    fnDati = dat;
endcase
endfunction

function memsz_t fnMemsz;
input micro_op_t ir;
begin
	case(ir.any.opcode)
	OP_LDB,OP_LDBZ,OP_STB:	fnMemsz = byt;
	OP_LDW,OP_LDWZ,OP_STW:	fnMemsz = wyde;
	OP_LDT,OP_LDTZ,OP_STT:	fnMemsz = tetra;
	OP_LOAD,OP_STORE:				fnMemsz = octa;
	OP_LDIP,OP_STIP:
		case(ir.ls.Rs1[5:4])
		2'd0:	fnMemsz = byt;
		2'd1:	fnMemsz = wyde;
		2'd2:	fnMemsz = tetra;
		2'd3:	fnMemsz = octa;
		endcase
	OP_STI:
		case(ir[12:11])
		2'd0:	fnMemsz = byt;
		2'd1:	fnMemsz = wyde;
		2'd2:	fnMemsz = tetra;
		2'd3:	fnMemsz = octa;
		endcase
	default:
		fnMemsz = octa;
	endcase
end
endfunction

function [31:0] fnSel;
input micro_op_t ir;
begin
	case(ir.any.opcode)
	OP_LDB,OP_LDBZ,OP_STB:	fnSel = 32'h01;
	OP_LDW,OP_LDWZ,OP_STW:	fnSel = 32'h03;
	OP_LDT,OP_LDTZ,OP_STT:	fnSel = 32'h0F;
	OP_LDIP,OP_STIP:
		case(ir.ls.Rs1[5:4])
		2'd0:	fnSel = 32'h01;
		2'd1:	fnSel = 32'h03;
		2'd2:	fnSel = 32'h0F;
		2'd3:	fnSel = 32'hFF;
		endcase
	OP_STI:
		case(ir[12:11])
		2'd0:	fnSel = 32'h01;
		2'd1:	fnSel = 32'h03;
		2'd2:	fnSel = 32'h0F;
		2'd3:	fnSel = 32'hFF;
		endcase
	default:	fnSel = 32'hFF;
	endcase
end
endfunction

function fnIsBranch;
input micro_op_t ir;
begin
	case(ir.any.opcode)
	OP_BCC8,OP_BCC16,OP_BCC32,OP_BCC64,
	OP_BCCU8,OP_BCCU16,OP_BCCU32,OP_BCCU64:
		fnIsBranch = 1'b1;
	default:
		fnIsBranch = 1'b0;
	endcase
end
endfunction

function fnDecBsr;
input Qupls4_pkg::pipeline_reg_t mux;
begin
	fnDecBsr = mux.uop.any.opcode == OP_BSR && mux.uop.bsr.Rd!=8'd0;
end
endfunction

function fnDecBra;
input Qupls4_pkg::pipeline_reg_t mux;
begin
	fnDecBra = mux.uop.any.opcode == OP_BSR && mux.uop.bsr.Rd==8'd0;
end
endfunction

function fnDecJmp;
input Qupls4_pkg::pipeline_reg_t mux;
begin
	fnDecJmp = mux.uop.any.opcode==OP_JSR && mux.uop.jsr.Rd==8'd0;
end
endfunction

function fnDecJmpr;
input Qupls4_pkg::pipeline_reg_t mux;
begin
	fnDecJmpr = 1'b0;
end
endfunction

function fnDecJsr;
input Qupls4_pkg::pipeline_reg_t mux;
begin
	fnDecJsr = mux.uop.any.opcode==OP_JSR && mux.uop.jsr.Rd!=8'd0;
end
endfunction

function fnDecJsrr;
input Qupls4_pkg::pipeline_reg_t mux;
begin
	fnDecJsrr = 1'b0;
end
endfunction

function fnDecBra2;
input Qupls4_pkg::pipeline_reg_t mux;
begin
	fnDecBra2 = 1'b0;
end
endfunction

function fnDecBsr2;
input Qupls4_pkg::pipeline_reg_t mux;
begin
	fnDecBsr2 = 1'b0;
end
endfunction

function fnDecRet;
input Qupls4_pkg::pipeline_reg_t mux;
begin
	fnDecRet =
		mux.uop.any.opcode==OP_RTD;
end
endfunction

function cpu_types_pkg::pc_address_ex_t fnDecDest;
input Qupls4_pkg::pipeline_reg_t pr;
reg jsr,bsr,bcc;
begin
	fnDecDest = pr.pc;
	jsr = fnDecJsr(pr);
	bsr = fnDecBsr(pr);
	bcc = fnIsBranch(pr.uop);
	case(1'b1)
	jsr:	fnDecDest.pc = {{23{pr.uop.jsr.disp[40]}},pr.uop.jsr.disp,1'b0};
	bsr: 	fnDecDest.pc = pr.pc.pc + {{23{pr.uop.jsr.disp[40]}},pr.uop.jsr.disp,1'b0};
	bcc:	fnDecDest.pc = pr.pc.pc + {{44{pr.uop.br.disp[19]}},pr.uop.br.disp,1'b0};
	default:	fnDecDest.pc = Qupls4_pkg::RSTPC;
	endcase
end
endfunction

function fnIsPredBranch;
input Qupls4_pkg::micro_op_t ir;
begin
	fnIsPredBranch = 1'b0;
end
endfunction

function fnIsBccR;
input micro_op_t ir;
begin
	fnIsBccR = fnIsBranch(ir) && 1'b0;//ir[39:36]==4'h7;
end
endfunction

function fnIsDBcc;
input micro_op_t ir;
begin
	fnIsDBcc = fnIsBranch(ir) && ir[25:23]!=3'd2 && ir[25:23]!=3'd5;
end
endfunction

function fnIsEret;
input micro_op_t ir;
begin
	fnIsEret = ir.any.opcode==OP_BRK &&  ir[28:18]==11'd1;	// eret or eret2
end
endfunction

function fnIsRet;
input micro_op_t ir;
begin
	fnIsRet = ir.any.opcode==OP_RTD;
end
endfunction

function fnImma;
input ex_instruction_t ir;
begin
	fnImma = 1'b0;
end
endfunction

function fnImmb;
input ex_instruction_t ir;
begin
	fnImmb = 1'b0;
	case(ir.ins.any.opcode)
	OP_ADDI,OP_CMPI,OP_MULI,OP_DIVI,OP_SUBFI:
		fnImmb = 1'b1;
	OP_R3B,OP_R3W,OP_R3T,OP_R3O:
		fnImmb = ir.ins.alu.ms[1] == 1'b1 && ir.ins.alu.Rs2[5] == 1'b1;
//	OP_RTD:
//		fnImmb = 1'b1;
	default:	fnImmb = 1'b0;
	endcase
end
endfunction

function fnImmc;
input ex_instruction_t ir;
begin
	fnImmc = 1'b0;
	case(ir.ins.any.opcode)
	OP_R3B,OP_R3W,OP_R3T,OP_R3O:
		fnImmc = ir.ins.alu.ms[2] == 1'b1 && ir.ins.alu.Rs3[5] == 1'b1;
	OP_STI:
		fnImmc = 1'b1;
	default:	fnImmc = 1'b0;
	endcase
end
endfunction

function fnImmd;
input ex_instruction_t ir;
begin
	fnImmd = 1'b0;
end
endfunction

// Registers that are essentially constant
// r0 and the PC alias
function fnConstReg;
input [7:0] Rn;
begin
	fnConstReg = Rn==8'd0 || Rn==8'd39 || Rn==8'd135 || Rn==8'd175 || Rn==8'd215;
end
endfunction

//
// 1 if the the operand is automatically valid, 
// 0 if we need a RF value
function fnSourceRs1v;
input ex_instruction_t ir;
begin
	case(ir.ins.any.opcode)
	OP_ADDI,OP_CMPI,OP_MULI,OP_DIVI,OP_SUBFI:	fnSourceRs1v = 1'b1;
	OP_CHK:	fnSourceRs1v = fnConstReg(ir.ins.chk.Rs1) || fnImma(ir);
//	OP_RTD:		fnSourceRs1v = fnConstReg(ir.ins.rtd.Ra.num) || fnImma(ir);
//	OP_JSR:		fnSourceRs1v = fnConstReg(ir.ins.jsr.Ra.num) || fnImma(ir);
	OP_R3B,OP_R3W,OP_R3T,OP_R3O:
			fnSourceRs1v = fnConstReg(ir.ins.alu.Rs1) || fnImma(ir);
	OP_SHIFT:	fnSourceRs1v = fnConstReg(ir.ins.sh.Rs1) || fnImma(ir);
//	OP_MOV:		fnSourceRs1v = fnConstReg({ir.ins.move.Rs1h,ir.ins.move.Rs1}) || fnImma(ir);
	OP_BCC8,OP_BCC16,OP_BCC32,OP_BCC64,
	OP_BCCU8,OP_BCCU16,OP_BCCU32,OP_BCCU64:
		fnSourceRs1v = fnConstReg(ir.ins.br.Rs1) || fnImma(ir);
	OP_LOADA,
	OP_LDB,,OP_LDBZ,OP_LDW,OP_LDWZ,OP_LDT,OP_LDTZ,OP_LOAD:
		fnSourceRs1v = fnConstReg(ir.ins.ls.Rs1);
	OP_STB,OP_STW,OP_STT,OP_STORE,OP_STI,OP_STPTR:
		fnSourceRs1v = fnConstReg(ir.ins.ls.Rs1);
	default:	fnSourceRs1v = 1'b1;
	endcase
end
endfunction

function fnSourceRs2v;
input ex_instruction_t ir;
begin
	case(ir.ins.any.opcode)
	OP_CHK:	fnSourceRs2v = fnConstReg(ir.ins.chk.Rs2) || fnImmb(ir);
//	OP_RTD:		fnSourceRs2v = 1'b0;
//	OP_JSR,OP_BSR,
	OP_ADDI,OP_CMPI,OP_MULI,OP_DIVI,OP_SUBFI:
		fnSourceRs2v = 1'b1;
	OP_R3B,OP_R3W,OP_R3T,OP_R3O:
			fnSourceRs2v = fnConstReg(ir.ins.alu.Rs2) || fnImmb(ir);
	OP_SHIFT:	fnSourceRs2v = fnConstReg(ir.ins.alu.Rs2) || ir.ins[31];
	OP_BCC8,OP_BCC16,OP_BCC32,OP_BCC64,
	OP_BCCU8,OP_BCCU16,OP_BCCU32,OP_BCCU64:
		fnSourceRs2v = fnConstReg(ir.ins.br.Rs2) || fnImmb(ir);
	OP_LOADA,
	OP_LDB,,OP_LDBZ,OP_LDW,OP_LDWZ,OP_LDT,OP_LDTZ,OP_LOAD:
		fnSourceRs2v = fnConstReg(ir.ins.ls.Rs2);
	OP_STB,OP_STW,OP_STT,OP_STORE,OP_STI,OP_STPTR:
		fnSourceRs2v = fnConstReg(ir.ins.ls.Rs2);
	default:	fnSourceRs2v = 1'b1;
	endcase
end
endfunction

function fnSourceRs3v;
input ex_instruction_t ir;
begin
	case(ir.ins.any.opcode)
	OP_R3B,OP_R3W,OP_R3T,OP_R3O:
			fnSourceRs3v = fnConstReg(ir.ins.alu.Rs3) || fnImmc(ir);
	OP_CHK:	fnSourceRs3v = fnConstReg(ir.ins.chk.Rs3);
//	OP_RTD:
//		fnSourceRs3v = 1'd0;
	OP_STI:
		fnSourceRs3v = 1'b1;
	default:
		fnSourceRs3v = 1'b1;
	endcase
end
endfunction

function fnSourceRs4v;
input ex_instruction_t ir;
begin
	case(ir.ins.any.opcode)
	OP_EXTD:
			fnSourceRs4v = fnConstReg(ir.ins.extd.Rs4) || fnImmd(ir);
	default:
		fnSourceRs4v = 1'b1;
	endcase
end
endfunction

function fnSourceRdv;
input ex_instruction_t ir;
begin
	fnSourceRdv = 1'b1;
end
endfunction

function fnSourceRciv;
input ex_instruction_t ir;
begin
	fnSourceRciv = 1'b1;
end
endfunction

function fnRegExc;
input operating_mode_t om;
input [6:0] a;
begin
	fnRegExc = 1'b0;
	case (om)
	OM_APP:	fnRegExc = a==7'd45 || (a >= 7'd50 && a <= 7'd55);
	OM_SUPERVISOR: fnRegExc = a > 7'd63;
	OM_HYPERVISOR: fnRegExc = a > 7'd63;
	OM_SECURE: fnRegExc = a > 7'd63;
	endcase
end
endfunction

// Not as complex as it looks. Mainly wires.
// Some routing as fields in the micro-op may be wider than the raw instruction.

function micro_op_t fnMapRawToUop;
input [47:0] raw;
begin
	fnMapRawToUop = {$bits(micro_op_t){1'b0}};
	case(raw[6:0])
	// Immediate operate
	Qupls4_pkg::OP_ADDI,Qupls4_pkg::OP_SUBFI,
	Qupls4_pkg::OP_CMPI,Qupls4_pkg::OP_CMPUI,
	Qupls4_pkg::OP_MULI,Qupls4_pkg::OP_MULUI,
	Qupls4_pkg::OP_DIVI,Qupls4_pkg::OP_DIVUI:
		begin
			fnMapRawToUop.any.opcode = Qupls4_pkg::opcode_e'(raw[6:0]);
			fnMapRawToUop.alui.Rd = {2'd0,raw[12:7]};
			fnMapRawToUop.alui.Rs1 = {2'd0,raw[18:13]};
			fnMapRawToUop.alui.imm = raw[45:19];
			fnMapRawToUop.alui.pr = raw[47:46];
		end
	// Loads and stores
	Qupls4_pkg::OP_LDB,Qupls4_pkg::OP_LDW,Qupls4_pkg::OP_LDT,Qupls4_pkg::OP_LOAD,
	Qupls4_pkg::OP_LDBZ,Qupls4_pkg::OP_LDWZ,Qupls4_pkg::OP_LDTZ,
	Qupls4_pkg::OP_STB,Qupls4_pkg::OP_STW,Qupls4_pkg::OP_STT,Qupls4_pkg::OP_STORE:
		begin
			fnMapRawToUop.any.opcode = Qupls4_pkg::opcode_e'(raw[6:0]);
			fnMapRawToUop.ls.Rsd = {2'd0,raw[12:7]};
			fnMapRawToUop.ls.Rs1 = {2'd0,raw[18:13]};
			fnMapRawToUop.ls.Rs2 = {2'd0,raw[24:19]};
			fnMapRawToUop.ls.disp = raw[43:25];
			fnMapRawToUop.ls.ms = raw[44];
			fnMapRawToUop.ls.sc = raw[47:45];
		end
	// Vector loads and stores
	Qupls4_pkg::OP_LDV,Qupls4_pkg::OP_LDVN,
	Qupls4_pkg::OP_STV,Qupls4_pkg::OP_STVN:
		begin
			fnMapRawToUop.vls.Rd = {2'd0,raw[12:7]};
			fnMapRawToUop.vls.Rs1 = {2'd0,raw[18:13]};
			fnMapRawToUop.vls.Rs2 = {2'd0,raw[24:19]};
			fnMapRawToUop.vls.Rs3 = {2'd0,raw[30:25]};
			fnMapRawToUop.vls.dt = raw[33:31];
			fnMapRawToUop.vls.disp = raw[43:34];
			fnMapRawToUop.vls.ms = raw[44];
			fnMapRawToUop.vls.sc = raw[47:45];
		end
	default:
		begin
			fnMapRawToUop.any.opcode = Qupls4_pkg::opcode_e'(raw[6:0]);
			fnMapRawToUop.r3.Rd = {2'd0,raw[12:7]};
			fnMapRawToUop.r3.Rs1 = {2'd0,raw[18:13]};
			fnMapRawToUop.r3.Rs2 = {2'd0,raw[24:19]};
			fnMapRawToUop.r3.Rs3 = {2'd0,raw[30:25]};
			fnMapRawToUop.r3.vn = raw[34:31];
			fnMapRawToUop.r3.op3 = raw[37:35];
			fnMapRawToUop.r3.ms = raw[40:38];
			fnMapRawToUop.r3.func = Qupls4_pkg::func_e'(raw[47:41]);
		end
	endcase
end
endfunction


// ============================================================================
// Support Tasks
// ============================================================================

// Maps a register spec to a logical register number depending on the mode and
// checks for register accessibility.

task tRegmap;
input operating_mode_t om;
input [6:0] a;
output reg [7:0] o;
output reg exc;
begin
	exc = 1'b0;
	case(om)
	OM_APP:	
		begin
			o = a;
		end
	OM_SUPERVISOR:
		begin
			if (a >= 7'd0 && a <= 7'd7)
				o = a;
			else if (a >= 7'd48) begin
				exc = 1'b1;
				o = 7'd0;
			end
			else
				o = 8'd96 + a;
		end
	OM_HYPERVISOR:
		begin
			if (a >= 7'd50 && a <= 7'd63 || a >= 7'd0 && a <= 7'd7)
				o = a;
			else if (a >= 7'd48) begin
				exc = 1'b1;
				o = 7'd0;
			end
			else
				o = 8'd136 + a;
		end
	OM_SECURE:
		begin
			if (a >= 7'd50 && a <= 7'd63 || a >= 7'd0 && a <= 7'd7)
				o = a;
			else if (a >= 7'd55) begin
				exc = 1'b1;
				o = 7'd0;
			end
			else
				o = 8'd176 + a;
		end
	endcase
end
endtask

endpackage
