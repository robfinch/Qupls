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

package QuplsPkg;

`undef IS_SIM
parameter SIM = 1'b0;
//`define IS_SIM	1

// Comment out to remove the sigmoid approximate function
//`define SIGMOID	1

//`define SUPPORT_16BIT_OPS		1
//`define SUPPORT_64BIT_OPS		1
//`define SUPPORT_128BIT_OPS	1
`define NLANES	4
`define NTHREADS	4

// Number of architectural registers there are in the core, including registers
// not visible in the programming model. This number should be <= 256 and >= 64.
`define NREGS	128

// Number of physical registers supporting the architectural ones and used in
// register renaming. There must be significantly more physical registers than
// architectural ones, or performance will suffer due to stalls.
// Must be a multiple of four. If it is not 512 or 256 then the renamer logic will
// need to be modified.
parameter PREGS = 256;	// 512

// Number of elements per vector. Changing this requires changing logic in the
// core specific to vector register numbers.
parameter VEC_ELEMENTS = 8;

`define L1CacheLines	1024
`define L1CacheLineSize		256

`define L1ICacheLineSize	256
`define L1ICacheLines	1024
`define L1ICacheWays 4

`define L1DCacheWays 4

// Not fully implemented yet. The following parameter controls the width of the
// core in terms of number of instructions. The only working value is 4.
parameter XWID = 4;

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

// Enables register renaming to remove false dependencies.
parameter SUPPORT_RENAMER = 1;

// Register name supplier
// 3 = SRL based circular list, smaller less performant
// 4 = FIFO based, larger, does not work correctly yet
// 			(sometimes supplies the same register twice)
// 6 = FFO / Bitmap, a find-first-ones approach with a bitmap
parameter RENAMER = 6;

// Comment out the following to remove the RAT
`define SUPPORT_RAT 1;

// =============================================================================
// =============================================================================

// Set the following to one to support backout and restore branch handling.
// backout / restore is not 100% working yet. Supporting backout / restore
// makes the core larger.
parameter SUPPORT_BACKOUT = 1'b1;

// Select building for performance or size.
// If this is set to one extra logic will be included to improve performance.
parameter PERFORMANCE = 1'b0;

// Predictor
//		0 = none
//		1 = backwards branch predictor (accuracy < 60%)
//		2 = g select predictor
parameter BRANCH_PREDICTOR = 0;

// The following indicates whether to support postfix instructions or not.
// Supporting postfix instructions increases the size of the core and reduces
// the code density.
parameter SUPPORT_POSTFIX = 0;

// The following allows the core to process flow control ops in any order
// to reduce the size of the core. Set to zero to restrict flow control ops
// to be processed in order. If processed out of order a branch may 
// speculate incorrectly leading to lower performance.
parameter SUPPORT_OOOFC = 1'b0;

// Allowing unaligned memory access increases the size of the core.
parameter SUPPORT_UNALIGNED_MEMORY = 1'b0;
parameter SUPPORT_BUS_TO = 1'b0;

// The following parameter indicates to support variable length instructions.
// If variable length instructions are not supported, then all instructions
// are assumed to be six bytes long.
parameter SUPPORT_VLI = 1'b0;
// The following indicates to support the variable length instruction
// accelerator byte.
parameter SUPPORT_VLIB = 1'b0;
// The following parameter indicates to use instruction block headers.
parameter SUPPORT_IBH = 1'b0;
parameter SUPPORT_REGLIST = 1'b0;
parameter SUPPORT_PGREL	= 1'b0;	// Page relative branching, must be zero
parameter SUPPORT_REP = 1'b0;
parameter REP_BIT = 31;

// (Dead) This parameter indicates if to support vector instructions.
parameter SUPPORT_VEC = 1'b1;

// This parameter adds support for capabilities. Increases the size of the core.
// An FPU must also be enabled.
parameter SUPPORT_CAPABILITIES = 1'b0;

// This parameter indicates to support the PRED modifier and predicates.
parameter SUPPORT_PRED = 1'b1;

// This parameter indicates to support the precision field of instructions.
// If enabled, registers will be treated as SIMD, 4x16, 2x32, or 1x64 bits.
// If the precision field is not supported, registers are 64-bit without
// support for 4x16, or 2x32 bit ops.
parameter SUPPORT_PREC = 1'b0;

// This parameter enables support for quad (128-bit) precision operations.
parameter SUPPORT_QUAD_PRECISION = 1'b0;

// Supporting load bypassing may improve performance, but will also increase the
// size of the core and make it more vulnerable to security attacks.
parameter SUPPORT_LOAD_BYPASSING = 1'b0;

// The following controls the size of the reordering buffer.
// Setting ROB_ENTRIES below 12 may not work. Setting the number of entries over
// 63 may require changing the sequence number type. For ideal construction 
// should be a multiple of four.
parameter ROB_ENTRIES = 16;

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
parameter NCHECK = 32;			// number of checkpoints

parameter LOADQ_ENTRIES = 8;
parameter STOREQ_ENTRIES = 8;
parameter LSQ_ENTRIES = 8;
parameter LSQ2 = 1'b0;			// Queue two LSQ entries at once?

// Uncomment to have page relative branches.
//`define PGREL 1

parameter  NLANES = `NLANES;
// The following thread count carefully choosen.
// It cannot be over 13 as that makes the vector register file too big for
// synthesis to handle.
parameter NTHREADS = `NTHREADS;
parameter NREGS = `NREGS;

parameter pL1CacheLines = `L1CacheLines;
parameter pL1LineSize = `L1CacheLineSize;
parameter pL1ICacheLines = `L1CacheLines;
// The following arrived at as 512+32 bits for word at end of cache line, plus
// 40 bits for a possible constant postfix
parameter pL1ICacheLineSize = `L1ICacheLineSize;
parameter pL1Imsb = $clog2(`L1ICacheLines-1)-1+6;
parameter pL1ICacheWays = `L1ICacheWays;
parameter pL1DCacheWays = `L1DCacheWays;
parameter TidMSB = $clog2(`NTHREADS)-1;

parameter AREGS = `NREGS;
parameter REGFILE_LATENCY = 2;
parameter INSN_LEN = 8'd8;

// Number of data ports should be 1 or 2. 2 ports will allow two simulataneous
// reads, but still only a single write.
parameter NDATA_PORTS = 1;
parameter NAGEN = 1;
// Increasing the number of ALUs will increase performance of vector operations.
// Note that adding an FPU may also increase integer performance.
parameter NALU = 2;			// 1 or 2
parameter NFPU = 1;			// 0, 1, or 2
parameter FPU0_IQ_DEPTH = 32;
parameter FPU1_IQ_DEPTH = 32;
parameter NLSQ_PORTS = 1;
// Number of banks of registers (not implemented).)
parameter BANKS = 1;

parameter RAS_DEPTH	= 4;

parameter SUPPORT_RSB = 0;

//
// define PANIC types
//
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

// States for sequential machine

typedef enum logic [4:0] {
	RESET = 5'd0,
	IFETCH = 5'd1,
	EXTRACT = 5'd2,
	DECODE1 = 5'd3,
	EXECUTE = 5'd4,
	MEMORY = 5'd5,
	MEMORY_ACK = 5'd6,
	MEMORY2 = 5'd7,
	MEMORY2_ACK = 5'd8,
	WRITEBACK = 5'd9,
	REGREAD1 = 5'd10,
	REGREAD2 = 5'd11,
	DECODE2 = 5'd12,
	PMTACCESS1 = 5'd13,
	PMTACCESS2 = 5'd14
} e_seq_state;

typedef enum logic [1:0] {
	DRAMSLOT_AVAIL = 2'd0,
	DRAMSLOT_READY = 2'd1,
	DRAMSLOT_ACTIVE = 2'd2,
	DRAMSLOT_DELAY = 2'd3
} dram_state_t;

typedef logic [$clog2(NCHECK)-1:0] checkpt_ndx_t;
typedef logic [$clog2(ROB_ENTRIES)-1:0] rob_ndx_t;
typedef logic [$clog2(BEB_ENTRIES)-1:0] beb_ndx_t;
typedef struct packed
{
	logic [2:0] row;
	logic col;
} lsq_ndx_t;

typedef logic [NREGS-1:1] reg_bitmask_t;
typedef logic [5:0] ibh_offset_t;

typedef enum logic [2:0] {
	BS_IDLE = 3'd0,
	BS_CHKPT_RESTORE = 3'd1,
	BS_CHKPT_RESTORED = 3'd2,
	BS_STATE3 = 3'd3,
	BS_CAPTURE_MISSPC = 3'd4,
	BS_DONE = 3'd5,
	BS_DONE2 = 3'd6
} branch_state_t;

// The following enumeration not currently used.
typedef enum logic [2:0] {
	OP_SRC_REG = 3'd0,
	OP_SRC_ALU0 = 3'd1,
	OP_SRC_ALU1 = 3'd2,
	OP_SRC_FPU0 = 3'd3,
	OP_SRC_FCU = 3'd4,
	OP_SRC_LOAD = 3'd5,
	OP_SRC_IMM = 3'd6,
	OP_SRC_DEF = 3'd7
} op_src_t;

typedef enum logic [1:0] {
	WP2_SRC_LOAD = 2'd0,
	WP2_SRC_FPU = 2'd1,
	WP2_SRC_FCU = 2'd2,
	WP2_SRC_DEF = 2'd3
} wp2_src_t;

typedef enum logic [3:0] {
	ST_RST = 4'd0,
	ST_RUN = 4'd1,
	ST_INVALL1 = 4'd7,
	ST_INVALL2 = 4'd8,
	ST_INVALL3 = 4'd9,
	ST_INVALL4 = 4'd10,
	ST_UPD1 = 4'd11,
	ST_UPD2 = 4'd12,
	ST_UPD3 = 4'd13,
	ST_LOOKUP = 4'd14
} tlb_state_t;

typedef enum logic [6:0] {
	OP_CHK			= 7'd00,
	OP_CAP			= 7'd01,
	OP_R2				= 7'd02,
	OP_BFI			= 7'd03,
	OP_ADDI			= 7'd04,
	OP_SUBFI		= 7'd05,
	OP_MULI			= 7'd06,
	OP_CSR			= 7'd07,
	OP_ANDI			= 7'd08,
	OP_ORI			= 7'd09,
	OP_EORI			= 7'd10,
	OP_CMPI			= 7'd11,
	OP_DIVI			= 7'd13,
	OP_MULUI		= 7'd14,
	OP_MOV			= 7'd15,
	OP_FLT3			= 7'd16,
	OP_CMPUI		= 7'd19,
	OP_DIVUI		= 7'd21,

	OP_SEQI			= 7'd22,
	OP_SNEI			= 7'd23,
	OP_SLTI			= 7'd24,
	OP_SLEI			= 7'd25,
	OP_SGTI			= 7'd26,
	OP_SGEI			= 7'd27,
	OP_SLTUI		= 7'd28,
	OP_SLEUI		= 7'd29,
	OP_SGTUI		= 7'd30,
	OP_SGEUI		= 7'd31,

	OP_BSR			= 7'd32,
	OP_JSR			= 7'd33,
	OP_CJSR			= 7'd34,
	OP_RTD			= 7'd35,
	OP_JSRI			= 7'd36,
	OP_CJSRI		= 7'd37,
	OP_JSRR			= 7'd38,
	OP_CJSRR		= 7'd39,

	OP_R3V			= 7'd77,
	OP_R3VS			= 7'd78,

	OP_BccU			= 7'd40,
	OP_Bcc			= 7'd41,
	OP_DFBcc		= 7'd43,
	OP_FBcc			= 7'd44,
	OP_DBRA			= 7'd45,
	OP_MCB			= 7'd46,
/*
	OP_BEQ			= 7'd38,
	OP_BNE			= 7'd39,
	OP_BLT			= 7'd40,
	OP_BGE			= 7'd41,
	OP_BLE			= 7'd42,
	OP_BGT			= 7'd43,
	OP_BBC			= 7'd44,
	OP_BBS			= 7'd45,
	OP_BBCI			= 7'd46,
	OP_BBSI			= 7'd47,
*/
	OP_VADDSI		= 7'd48,
	OP_ADDSI		= 7'd49,
	OP_ANDSI		= 7'd50,
	OP_ORSI			= 7'd51,
	OP_ENTER		= 7'd52,
	OP_LEAVE		= 7'd53,
	OP_PUSH			= 7'd54,
	OP_POP			= 7'd55,
	OP_VANDSI		= 7'd56,
	OP_LDA			= 7'd57,
	OP_AIPSI		= 7'd58,
	OP_EORSI		= 7'd59,
	OP_VORSI		= 7'd60,
	OP_VEORSI		= 7'd61,
	OP_PUSHI		= 7'd62,
	OP_LDx			= 7'd64,
	OP_FLDx			= 7'd65,
	OP_DFLDx		= 7'd66,
	OP_PLDx			= 7'd67,
	OP_CLOADx		= 7'd68,
	OP_LDxU			= 7'd69,
	OP_CACHE		= 7'd70,
	OP_STx			= 7'd80,
	OP_FSTx			= 7'd81,
	OP_DFSTx		= 7'd82,
	OP_PSTx			= 7'd83,
	OP_CSTOREx	= 7'd84,
	OP_STPTR		= 7'd86,
	OP_SHIFT		= 7'd88,
	OP_BLEND		= 7'd89,
	OP_VSHIFT		= 7'd90,
	OP_AMO			= 7'd92,
	OP_CAS			= 7'd93,
	OP_ZSEQI		= 7'd94,
	OP_ZSNEI	 	= 7'd95,
	OP_ZSLTI		= 7'd96,
	OP_ZSLEI		= 7'd97,
	OP_ZSGTI		= 7'd98,
	OP_ZSGEI		= 7'd99,
	OP_ZSLTUI		= 7'd100,
	OP_ZSLEUI		= 7'd101,
	OP_ZSGTUI		= 7'd102,
	OP_ZSGEUI		= 7'd103,
	OP_BFND			= 7'd108,
	OP_BCMP			= 7'd109,
//	OP_BSTORE		= 7'd110,
	OP_BLOCK		= 7'd111,
	OP_IRQ			= 7'd112,
	OP_FENCE		= 7'd114,
	OP_REGS			= 7'd117,
	OP_VECZ			= 7'd118,
	OP_VEC			= 7'd119,
	OP_QFEXT		= 7'd120,
	OP_PRED			= 7'd121,
	OP_ATOM			= 7'd122,
	OP_PFXAB		= 7'd124,
	OP_PFXC			= 7'd125,
	OP_NOP			= 7'd127
} opcode_t;

typedef enum logic [3:0] {
	BLK_STAT = 4'd0,
	BLK_COUNT = 4'd1,
	BLK_CANCEL = 4'd2,
	BLK_STORE = 4'd3,
	BLK_MOVE = 4'd4
} block_t;
/*
typedef enum logic [2:0] {
	OP_CLR = 3'd0,
	OP_SET = 3'd1,
	OP_COM = 3'd2,
	OP_SBX = 3'd3,
	OP_EXTU = 3'd4,
	OP_EXTS = 3'd5,
	OP_DEP = 3'd6,
	OP_FFO = 3'd7
} bitfld_t;
*/
typedef enum logic [3:0] {
	OP_CMP_EQ	= 4'h0,
	OP_CMP_NE	= 4'd1,
	OP_CMP_LT	= 4'd2,
	OP_CMP_LE	= 4'd3,
	OP_CMP_GE	= 4'd4,
	OP_CMP_GT	= 4'd5,
	OP_CMP_LTU	= 4'd10,
	OP_CMP_LEU	= 4'd11,
	OP_CMP_GEU	= 4'd12,
	OP_CMP_GTU = 4'd13
} cmp_t;

typedef enum logic [1:0] {
	CM_INT = 2'd0,
	CM_UINT = 2'd1,
	CM_FLOAT = 2'd2,
	CM_DECFLOAT = 2'd3
} branch_cm_t;
/*
typedef enum logic [3:0] {
	EQ = 4'd0,
	NE = 4'd1,
	LT = 4'd2,
	LE = 4'd3,
	GE = 4'd4,
	GT = 4'd5,
	BC = 4'd6,
	BS = 4'd7,
	
	BCI = 4'd8,
	BSI = 4'd9,
	LO = 4'd10,
	LS = 4'd11,
	HS = 4'd12,
	HI = 4'd13,
	
	RA = 4'd14,
	SR = 4'd15
} branch_cnd_t;
*/
typedef enum logic [3:0] {
	EQ = 4'd0,
	NE = 4'd1,
	LT = 4'd2,
	LE = 4'd3,
	GE = 4'd4,
	GT = 4'd5,
	BC = 4'd6,
	BS = 4'd7,
	
	BCI = 4'd8,
	BSI = 4'd9,
	NAND = 4'd10,
	AND = 4'd11,
	NOR = 4'd12,
	OR = 4'd13,
	OV = 4'd15		// overflow
} branch_fn_t;

typedef enum logic [3:0] {
	FEQ = 4'd0,
	FNE = 4'd1,
	FGT = 4'd2,
	FUGT = 4'd3,
	FGE = 4'd4,
	FUGE = 4'd5,
	FLT = 4'd6,
	FULT = 4'd7,
	
	FLE = 4'd8,
	FULE = 4'd9,
	FGL = 4'd10,
	FUGL = 4'd11,
	FORD = 4'd12,
	FUN = 4'd13
	
} fbranch_fn_t;

typedef enum logic [2:0] {
	MCB_EQ = 3'd0,
	MCB_NE = 3'd1,
	MCB_LT = 3'd2,
	MCB_GE = 3'd3,
	MCB_LE = 3'd4,
	MCB_GT = 3'd5,
	MCB_BC = 3'd6,
	MCB_BS = 3'd7
} mcb_cond_t;

typedef enum logic [2:0] {
	BTS_NONE = 3'd0,
	BTS_DISP = 3'd1,
	BTS_REG = 3'd2,
	BTS_BSR = 3'd3,
	BTS_JSR = 3'd4,
	BTS_CALL = 3'd5,
	BTS_RET = 3'd6,
	BTS_RTI = 3'd7
} bts_t;

/*
typedef enum logic [3:0] {
	FEQ = 4'd0,
	FNE = 4'd1,
	FGT = 4'd2,
	FGE = 4'd3,
	FLT = 4'd4,
	FLE = 4'd5,
	FORD = 4'd6,
	FUN = 4'd7
} fbranch_cnd_t;
*/
// R3 ops
typedef enum logic [6:0] {
	FN_AND			= 7'd00,
	FN_OR				= 7'd01,
	FN_EOR			= 7'd02,
	FN_CMP			= 7'd03,
	FN_ADD			= 7'd04,
	FN_SUB			= 7'd05,
	FN_CMPU			= 7'd06,
	FN_CPUID		= 7'd07,
	FN_NAND			= 7'd08,
	FN_NOR			= 7'd09,
	FN_ENOR			= 7'd10,
	FN_CMOVZ		= 7'd11,
	FN_CMOVNZ		= 7'd12,
	FN_MUL			= 7'd16,
	FN_DIV			= 7'd17,
	FN_MINMAX		= 7'd18,
	FN_MULU			= 7'd19,
	FN_DIVU			= 7'd20,
	FN_MULSU		= 7'd21,
	FN_DIVSU		= 7'd22,
	FN_MULW			= 7'd24,
	FN_MOD			= 7'd25,
	FN_R1				= 7'd26,
	FN_MULUW		= 7'd27,
	FN_MODU			= 7'd28,
	FN_MULSUW		= 7'd29,
	FN_MODSU		= 7'd30,
	FN_PTRDIF		= 7'd32,
	FN_BYTENDX	= 7'd37,
	NNA_MTWT		= 7'd40,
	NNA_MTIN		= 7'd41,
	NNA_MTBIAS	= 7'd42,
	NNA_MTFB		= 7'd43,
	NNA_MTMC		= 7'd44,
	NNA_MTBC		= 7'd45,
	FN_V2BITS		= 7'd48,
	FN_VSETMASK	= 7'd58,
	FN_SEQ			= 7'd80,
	FN_SNE			= 7'd81,
	FN_SLT			= 7'd82,
	FN_SLE			= 7'd83,
	FN_SLTU			= 7'd84,
	FN_SLEU			= 7'd85,
	FN_SEQI8		= 7'd96,
	FN_SNEI8		= 7'd97,
	FN_SLTI8		= 7'd98,
	FN_SLEI8		= 7'd99,
	FN_SLTUI8		= 7'd100,
	FN_SLEUI8		= 7'd101,
	FN_ZSEQ			= 7'd112,
	FN_ZSNE			= 7'd113,
	FN_ZSLT			= 7'd114,
	FN_ZSLE			= 7'd115,
	FN_ZSLTU		= 7'd116,
	FN_ZSLEU		= 7'd117,
	FN_ZSEQI8		= 7'd120,
	FN_ZSNEI8		= 7'd121,
	FN_ZSLTI8		= 7'd122,
	FN_ZSLEI8		= 7'd123,
	FN_ZSLTUI8	= 7'd124,
	FN_ZSLEUI8	= 7'd125,
	FN_MVVR			= 7'd127
} r3func_t;

typedef enum logic [4:0] {
	FNS_AND			= 5'd00,
	FNS_OR			= 5'd01,
	FNS_EOR			= 5'd02,
	FNS_CMP			= 5'd03,
	FNS_ADD			= 5'd04,
	FNS_SUBF		= 5'd05,
	FNS_CMPU		= 5'd06,
	FNS_SLT			= 5'd07,
	FNS_NAND		= 5'd08,
	FNS_NOR			= 5'd09,
	FNS_ENOR		= 5'd10,
	FNS_ANDC		= 5'd11,
	FNS_ORC			= 5'd12,
	FNS_MUL			= 5'd16,
	FNS_DIV			= 5'd17,
	FNS_MULU		= 5'd19,
	FNS_DIVU		= 5'd20,
	FNS_MULSU		= 5'd21,
	FNS_DIVSU		= 5'd22,
	FNS_MULH		= 5'd24,
	FNS_MOD			= 5'd25,
	FNS_MULUH		= 5'd27,
	FNS_MODU		= 5'd28,
	FNS_MULSUH	= 5'd29,
	FNS_MODSU		= 5'd30
} risfunc_t;

typedef enum logic [2:0] {
	RND_NE = 3'd0,		// nearest ties to even
	RND_ZR = 3'd1,		// round to zero (truncate)
	RND_PL = 3'd2,		// round to plus infinity
	RND_MI = 3'd3,		// round to minus infinity
	RND_MM = 3'd4,		// round to maxumum magnitude (nearest ties away from zero)
	RND_FL = 3'd7			// round according to flags register
} fround_t;

typedef enum logic [3:0] {
	FN_LDBX = 4'd0,
	FN_LDBUX = 4'd1,
	FN_LDWX = 4'd2,
	FN_LDWUX = 4'd3,
	FN_LDTX = 4'd4,
	FN_LDTUX = 4'd5,
	FN_LDOX = 4'd6,
	FN_LDOUX = 4'd7,
	FN_LDHX = 4'd8,
	FN_CLOADX = 4'd9,
	FN_LDAX = 4'd10,
	FN_LDCTX = 4'd15
} ldn_func_t;

typedef enum logic [3:0] {
	FN_STBX = 4'd0,
	FN_STWX = 4'd1,
	FN_STTX = 4'd2,
	FN_STOX = 4'd3,
	FN_STHX = 4'd4,
	FN_CSTOREX = 4'd5,
	FN_STCTX = 4'd7
} stn_func_t;

typedef union packed {
	ldn_func_t ldn;
	stn_func_t stn;
} lsn_func_t;

typedef enum logic [6:0]
{
	FN_BRK = 7'd0,
	FN_IRQ = 7'd1,
	FN_SYS = 7'd2,
	FN_RTS = 7'd3,
	FN_RTI = 7'd4
} sys_func_t;

// R1 ops
typedef enum logic [7:0] {
	NNA_TRIG 		=	8'd8,
	NNA_STAT 		= 8'd9,
	NNA_MFACT 	= 8'd10,
	OP_RTI			= 8'h19,
	OP_REX			= 8'h1A,
	OP_FFINITE 	= 8'h20,
	OP_FNEG			= 8'h23,
	OP_FRSQRTE	= 8'h24,
	OP_FRES			= 8'h25,
	OP_FSIGMOID	= 8'h26,
	OP_I2F			= 8'h28,
	OP_F2I			= 8'h29,
	OP_FABS			= 8'h2A,
	OP_FNABS		= 8'h2B,
	OP_FCLASS		= 8'h2C,
	OP_FMAN			= 8'h2D,
	OP_FSIGN		= 8'h2E,
	OP_FTRUNC		= 8'h2F,
	OP_SEXTB		= 8'h38,
	OP_SEXTW		= 8'h39
} r1func_t;

typedef enum logic [6:0] {
	FN_FSCALEB = 7'd0,
	FN_FLT1 = 7'd1,
	FN_FMIN = 7'd2,
	FN_FMAX = 7'd3,
	FN_FADD = 7'd4,
	FN_FSUB = 7'd5,
	FN_FMUL = 7'd6,
	FN_FDIV = 7'd7,
	FN_FSEQ = 7'd8,
	FN_FSNE = 7'd9,
	FN_FSLT = 7'd10,
	FN_FSLE = 7'd11,
	FN_FCMP = 7'd13,
	FN_FNXT = 7'd14,
	FN_FREM = 7'd15,
	FN_SGNJ = 7'd16,
	FN_SGNJN = 7'd17,
	FN_SGNJX = 7'd18,
	FN_FMA = 7'd24,
	FN_FMS = 7'd25,
	FN_FNMA = 7'd26,
	FN_FNMS = 7'd27,

	FN_FABS = 7'd32,
	FN_FNEG = 7'd33,
	FN_FTOI = 7'd34,
	FN_ITOF = 7'd35,
	FN_FCONST = 7'd36,
	FN_FSIGN = 7'd37,
	FN_FSIG = 7'd38,
	FN_FSQRT = 7'd39,
	FN_FCVTS2D = 7'd40,
	FN_FCVTS2Q = 7'd41,
	FN_FCVTD2Q = 7'd42,
	FN_FCVTH2S = 7'd43,
	FN_FCVTH2D = 7'd44,
	FN_ISNAN = 7'd45,
	FN_FINITE = 7'd46,
	FN_FCVTQ2H = 7'd47,
	FN_FCVTQ2S = 7'd48,
	FN_FCVTQ2D = 7'd49,
	FN_FCVTH2Q = 7'd50,
	FN_FTRUNC = 7'd51,
	FN_RSQRTE = 7'd52,
	FN_FRES = 7'd53,
	FN_FCVTD2S = 7'd54,
	FN_FCLASS = 7'd55,
	FN_FSIN = 7'd56,
	FN_FCOS = 7'd57
} f3func_t;

typedef enum logic [3:0] {
	OP_ASL 	= 4'd0,
	OP_LSR	= 4'd1,	
	OP_ASR	= 4'd2,
	OP_ROL	= 4'd3,
	OP_ROR	= 4'd4,
	OP_ASLI	= 4'd8,
	OP_LSRI	= 4'd9,
	OP_ASRI	= 4'd10,
	OP_ROLI	= 4'd11,
	OP_RORI	= 4'd12
} shift_t;

typedef enum logic [6:0] {
	FN_CRETD = 7'd8,
	FN_CANDPERMS = 7'd32,
	FN_CBUILDCAP = 7'd33,
	FN_CCOPYTYPE = 7'd34,
	FN_CINCOFFS = 7'd35,
	FN_CSEAL = 7'd36,
	FN_CSETADDR = 7'd37,
	FN_CSETBOUNDS = 7'd38,
	FN_CSETFLAGS = 7'd39,
	FN_CSETHIGH = 7'd40,
	FN_CSETOFFS = 7'd41,
	FN_CSPECIALRW = 7'd42,
	FN_CUNSEAL = 7'd43,
	FN_CCMP = 7'd44,
	FN_CINCOFFSIMM = 7'd45,
	FN_CSETBOUNDSEXACT = 7'd46,
	FN_CCLEARTAG = 7'd64,
	FN_CGETFLAGS = 7'd65,
	FN_CGETHIGH = 7'd66,
	FN_CGETLEN = 7'd67,
	FN_CGETOFFS = 7'd68,
	FN_CGETPERMS = 7'd69,
	FN_CGETTAG = 7'd70,
	FN_CGETTOP = 7'd71,
	FN_CGETTYPE = 7'd72,
	FN_CLOADTAGS = 7'd73,
	FN_CALIGNMSK = 7'd74,
	FN_CROUNDLEN = 7'd75,
	FN_CSEALENTRY = 7'd76,
	FN_CGETBASE = 7'd77,
	FN_CMOVE = 7'd78,
	FN_CINVOKE = 7'd124
} cap_func_t;

typedef enum logic [2:0] {
	OP3_ADD = 3'd0,
	OP3_ADDGC = 3'd1
} add_op3_t;

parameter GLOBAL 					= 14'b00000000000001;
parameter PERMIT_EXECUTE 	= 14'b00000000000010;
parameter PERMIT_LOAD 		= 14'b00000000000100;
parameter PERMIT_STORE		= 14'b00000000001000;
parameter PERMIT_LOAD_CAP = 14'b00000000010000;
parameter PERMIT_STORE_CAP= 14'b00000000100000;
parameter PERMIT_STORE_LOCAL_CAP= 14'b00000001000000;
parameter PERMIT_SEAL			= 14'b00000010000000;
parameter PERMIT_INVOKE		= 14'b00000100000000;
parameter PERMIT_UNSEAL		= 14'b00001000000000;
parameter PERMIT_ACCESS_SYSREGS = 14'b00010000000000;
parameter PERMIT_SET_CID	= 14'b00100000000000;

typedef enum logic [2:0] {
	PRC8 = 3'd0,
	PRC16 = 3'd1,
	PRC32 = 3'd2,
	PRC64 = 3'd3,
	PRC128 = 3'd4,
	PRC512 = 3'd6,
	PRCNDX = 3'd7
} prec_t;

parameter NOP_INSN	= {41'h1FFFFFFFFFF,OP_NOP};

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
	NONE = 4'd0,
	ALU0 = 4'd1,
	ALU1 = 4'd2,
	FPU0 = 4'd3,
	FPU1 = 4'd4,
	AGEN0 = 4'd5,
	AGEN1 = 4'd6,
	FCU = 4'd7,
	DRAM0 = 4'd8,
	DRAM1 = 4'd9
} rob_owner_t;

// Instruction block header.
// The offset is the low order six bits of the PC needed for an instruction
// group. This is needed to advance the PC in the branch-target buffer. Only
// the offset of the first instruction in the group is needed. If the offset
// is zero the PC will advance to the next cache line, otherwise the PC will
// advance to the next cache line once all the offsets are used.

typedef struct packed
{
	logic [9:0] resv;
	logic [5:0] lastip;
	logic [8:0] callno;
	opcode_t opcode;
} ibh_t;	// 24-bits

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

typedef enum logic [2:0] {
	csrRead = 3'd0,
	csrWrite = 3'd1,
	csrAndNot = 3'd2,
	csrOr = 3'd3,
	csrEor = 3'd4
} csrop_t;

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
/*
	FLT_EXV		= 8'h03,
	FLT_DCM		= 8'h05,
	FLT_IADR	= 8'h22,
	FLT_CHK		= 8'h27,
	FLT_DBZ		= 8'h28,
	FLT_OFL		= 8'h29,
	FLT_KEY		= 8'h31,
	FLT_WRV		= 8'h32,
	FLT_RDV		= 8'h33,
	FLT_SGB		= 8'h34,
	FLT_WD		= 8'h36,
	FLT_CPF		= 8'h39,
	FLT_DPF		= 8'h3A,
	FLT_LVL		= 8'h3B,
	FLT_PMA		= 8'h3D,
	FLT_BRK		= 8'h3F,
	FLT_TBL		= 8'h41,
	FLT_PFX		= 8'hC8,
	FLT_TMR		= 8'hE2,
	FLT_CSR		= 8'hEC,
	FLT_RTI		= 8'hED,
*/
	FLT_DBZ		= 8'h10,
	FLT_BADREG = 8'hDF,
	FLT_CAPTAG = 8'hE0,
	FLT_CAPOTYPE = 8'hE1,
	FLT_CAPPERMS = 8'hE2,
	FLT_CAPBOUNDS = 8'hE4,
	FLT_CAPSEALED = 8'hE5,
	FLT_NONE 	= 8'hFF
} cause_code_t;

typedef enum logic [1:0] {
	OM_APP = 2'd0,
	OM_SUPERVISOR = 2'd1,
	OM_HYPERVISOR = 2'd2,
	OM_MACHINE = 2'd3
} operating_mode_t;

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
	vect = 4'd10
} memsz_t;

typedef enum logic [1:0] {
	non = 2'd0,
	postinc = 2'd1,
	predec = 2'd2,
	memi = 2'd3
} addr_upd_t;

typedef enum logic [1:0] {
	AMD_REL = 0,
	AMD_ABS = 1,
	AMD_REG = 3
} br_amode_t;

typedef logic [ROB_ENTRIES-1:0] rob_bitmask_t;
typedef logic [LSQ_ENTRIES-1:0] lsq_bitmask_t;
typedef logic [TidMSB:0] Tid;
typedef logic [TidMSB:0] tid_t;
typedef logic [11:0] order_tag_t;
typedef logic [11:0] ASID;
/*
struct packed {
	logic [31:0] pc;
	logic [11:0] micro_ip;
} pc_address_t;
*/
typedef logic [5:0] Func;
typedef logic [127:0] regs_bitmap_t;

typedef struct packed
{
	logic n;
	logic resv;
	logic [6:0] num;
} regspec_t;

typedef logic [3:0] rndx_t;			// ROB index
typedef logic [9:0] tregno_t;

typedef struct packed
{
	logic [11:0] ip;
	logic [51:0] ir;
} mc_stack_t;

typedef struct packed
{
	logic [19:0] resv4;	// padding to 64-bits
	logic [11:0] mcip;	// micro-code instruction pointer
	logic [7:0] pl;			// privilege level
	logic [3:0] resv3;
	logic mprv;					// memory access priv indicator	
	logic dbg;					// debug mode indicator
	logic resv2;
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
} status_reg_t;				// 64 bits

// Instruction types, makes decoding easier

typedef struct packed
{
	logic [55:0] imm;
	logic sw;
	opcode_t opcode;
} postfix_t;

typedef struct packed
{
	logic [55:0] imm;
	logic sw;
	opcode_t opcode;
} prefix_t;

typedef struct packed
{
	logic [56:0] payload;
	opcode_t opcode;
} anyinst_t;


typedef struct packed
{
	f3func_t func;			// 7 bits
	logic [2:0] Pr;			// 3
	logic resv2;
	fround_t rmd;				// 3 bits
	logic [6:0] resv;		// 7
	regspec_t Rc;				// 9
	regspec_t Rb;				// 9
	regspec_t Ra;				// 9
	regspec_t Rt;				// 9
	opcode_t opcode;		// 7
} f3inst_t;						// 64

typedef struct packed
{
	f3func_t func;			// 7 bits
	logic [2:0] Pr;			// 3
	logic resv2;
	fround_t rmd;				// 3 bits
	logic [6:0] resv;		// 7
	regspec_t Rc;
	regspec_t Rb;
	regspec_t Ra;
	regspec_t Rt;
	opcode_t opcode;
} f2inst_t;

typedef struct packed
{
	f3func_t func;			// 7 bits
	logic [2:0] Pr;			// 3
	logic resv2;
	fround_t rmd;				// 3 bits
	logic [6:0] resv;		// 7
	regspec_t Rc;
	regspec_t Rb;
	regspec_t Ra;
	regspec_t Rt;
	opcode_t opcode;
} f1inst_t;

typedef struct packed
{
	r3func_t func;			// 7 bits
	logic [2:0] Pr;			// 4
	logic [3:0] resv;		// 3
	logic [2:0] op3;		// 3
	logic [3:0] op4;		// 4
	regspec_t Rc;				// 9
	regspec_t Rb;				// 9
	regspec_t Ra;				// 9
	regspec_t Rt;				// 9
	opcode_t opcode;		// 7
} r3inst_t;						// 64

typedef struct packed
{
	cap_func_t func;		// 7 bits
	logic [2:0] Pr;			// 4
	logic [6:0] resv;		// 6
	logic [3:0] op4;
	regspec_t Rc;
	regspec_t Rb;
	regspec_t Ra;
	regspec_t Rt;
	opcode_t opcode;
} cap_inst_t;

typedef struct packed
{
	r3func_t func;			// 7 bits
	logic [2:0] Pr;			// 4
	logic [3:0] resv;		// 3
	logic [2:0] op3;		// 3
	logic [3:0] op4;		// 4
	regspec_t Rc;				// 9
	regspec_t Rb;				// 9
	regspec_t Ra;				// 9
	regspec_t Rt;				// 9
	opcode_t opcode;		// 7
} r2inst_t;						// 64

typedef struct packed
{
	r3func_t r3func;		// 7 bits
	logic [2:0] Pr;			// 4
	logic [6:0] resv2;	// 6
	logic [3:0] op2;		// 4
	logic resv;					// 1
	r1func_t func;			// 8
	regspec_t Rb;				// 9
	regspec_t Ra;				// 9
	regspec_t Rt;				// 9
	opcode_t opcode;		// 7
} r1inst_t;						// 64

typedef struct packed
{
	logic [3:0] func;		// 4
	logic [2:0] resv2;	// 3
	logic [2:0] Pr;			// 3
	logic [2:0] resv;		// 3
	cause_code_t cause;	// 8
	regspec_t Rc;				// 9	
	regspec_t Rb;				// 9
	regspec_t Ra;				// 9
	logic [2:0] ipl;		// 3
	logic s;						// 1
	logic [4:0] offs;		// 5
	opcode_t opcode;		// 7
} chk_inst_t;					// 64

typedef struct packed
{
	logic [31:0] imm;		// 32
	prec_t prc;					// 3
	logic resv;					// 1
	logic [2:0] Pr;			// 3
	regspec_t Ra;				// 9
	regspec_t Rt;				// 9
	opcode_t opcode;		// 7
} imminst_t;					// 64

typedef struct packed
{
	logic [38:0] imm;		// 39
	prec_t prc;					// 3
	logic [1:0] sc;			// 2
	logic resv;					// 1
	logic [2:0] Pr;			// 3
	regspec_t Rt;				// 9
	opcode_t opcode;		// 7
} simminst_t;					// 64

typedef struct packed
{
	shift_t func;				// 4
	prec_t prc;					// 3
	logic [2:0] Pr;			// 3
	logic [6:0] resv;		// 7
	logic [2:0] Rm;			// 3
	logic i;						// 1
	logic [2:0] resv2;	// 3
	logic [5:0] imm;		// 6
	regspec_t Rb;				// 9
	regspec_t Ra;				// 9
	regspec_t Rt;				// 9
	opcode_t opcode;		// 7
} shiftiinst_t;				// 64

typedef struct packed
{
	logic [2:0] op;			// 3
	logic [3:0] resv3;	// 4
	logic [2:0] Pr;			// 3
	logic [5:0] resv2;	// 6
	logic [13:0] regno;	// 14
	logic [8:0] resv1;	// 9
	regspec_t Ra;				// 9
	regspec_t Rt;				// 9
	opcode_t opcode;		// 7
} csrinst_t;					// 64

typedef struct packed
{
	logic [23:0] disp;		// 24
	logic resv;						// 1
	logic [1:0] prc;			// 2
	logic [2:0] sc;				// 3
	regspec_t Rb;					// 9
	regspec_t Ra;					// 9
	regspec_t Rt;					// 9
	opcode_t opcode;			// 7
} lsinst_t;							// 64

typedef struct packed
{
	logic [23:0] disp;		// 24
	logic resv;						// 1
	logic [1:0] prc;			// 2
	logic [2:0] sc;				// 3
	regspec_t Rb;					// 9
	regspec_t Ra;					// 9
	regspec_t Rt;					// 9
	opcode_t opcode;			// 7
} lsninst_t;						// 64

typedef struct packed
{
	logic [6:0] dispHi;		// 7
	prec_t prc;						// 3
	logic resv2;					// 1
	logic [18:0] dispLo;	// 19
	regspec_t Rb;					// 9
	regspec_t	Ra;					// 9
	logic resv;						// 1
	br_amode_t md;				// 2
	logic [1:0] inc;			// 2
	branch_fn_t fn;				// 4
	opcode_t opcode;			// 7
} brinst_t;							// 64

typedef struct packed
{
	logic [6:0] dispHi;		// 7
	prec_t prc;						// 3
	logic resv2;					// 1
	logic [18:0] dispLo;	// 19
	regspec_t Rb;					// 9
	regspec_t	Ra;					// 9
	logic resv;						// 1
	br_amode_t md;				// 2
	logic [1:0] inc;			// 2
	fbranch_fn_t fn;			// 4
	opcode_t opcode;			// 7
} fbrinst_t;						// 64

typedef struct packed
{
	logic [21:0] disp;		// 22
	prec_t prc;						// 3
	logic [2:0] Pr;				// 3
	logic resv2;					// 1
	logic i;							// 1
	regspec_t Rb;					// 9
	regspec_t	Ra;					// 9
	logic [1:0] resv;			// 2
	logic lk;							// 1
	logic [1:0] inc;			// 2
	logic [3:0] fn;				// 4
	opcode_t opcode;			// 7
} mcb_inst_t;						// 64

typedef struct packed
{
	logic [9:0] dispHi;		// 10
	logic resv;						// 1
	logic [15:0] dispLo;	//16
	logic [2:0] Sc;				// 3
	regspec_t Rb;					// 9
	regspec_t Ra;					// 9
	regspec_t Rt;					// 9
	opcode_t opcode;			// 7
} jsrinst_t;						// 64

typedef struct packed
{
	logic [47:0] disp;		// 48
	regspec_t Rt;					// 9
	opcode_t opcode;			// 7
} bsrinst_t;						// 64

typedef struct packed
{
	logic [31:0] cnst;		// 32
	logic [3:0] resv3;		// 4
	logic [2:0] Pr;				// 3
	logic [5:0] resv2;		// 6
	logic [2:0] lk;				// 3
	logic resv4;					// 1
	logic [1:0] typ;			// 2
	logic [2:0] resv;			// 6
	logic [2:0] offs;			// 3
	opcode_t opcode;			// 7
} rtdinst_t;						// 64

typedef struct packed
{
	logic [6:0] amt;		// 7 bits
	logic [2:0] Pr;			// 3
	logic [1:0] resv;		// 2
	prec_t prc;					// 3
	logic [1:0] id;			// 2
	logic [3:0] op;			// 4
	regspec_t Rc;				// 9
	regspec_t Rb;				// 9
	regspec_t Ra;				// 9
	regspec_t Rt;				// 9
	opcode_t opcode;		// 7
} block_inst_t;				// 64

typedef union packed
{
	chk_inst_t chk;
	chk_inst_t sys;
	f1inst_t	f1;
	f2inst_t	f2;
	f3inst_t	f3;
	r1inst_t	r1;
	r2inst_t	r2;
	r2inst_t	r3;
	cap_inst_t	cap;
	brinst_t	br;
	fbrinst_t	fbr;
	mcb_inst_t mcb;
	jsrinst_t	jsr;
	jsrinst_t	jmp;
	bsrinst_t bsr;
	rtdinst_t rtd;
	imminst_t	imm;
	imminst_t	ri;
	simminst_t ris;
	shiftiinst_t shifti;
	csrinst_t	csr;
	lsinst_t	ls;
	lsninst_t	lsn;
	block_inst_t block;
	postfix_t	pfx;
	anyinst_t any;
} instruction_t;

typedef struct packed {
	cpu_types_pkg::pc_address_ex_t pc;
	cpu_types_pkg::mc_address_t mcip;
	logic [3:0] len;
	logic [2:0] element;
	logic [2:0] eno;
	cpu_types_pkg::aregno_t aRa;
	cpu_types_pkg::aregno_t aRb;
	cpu_types_pkg::aregno_t aRc;
	cpu_types_pkg::aregno_t aRt;
	cpu_types_pkg::aregno_t aRm;
	logic [5:0] pred_btst;
	instruction_t ins;
} ex_instruction_t;

typedef struct packed {
	cpu_types_pkg::pc_address_t adr;
	logic v;
	logic [2:0] icnt;
	logic [25:0] imm;
	logic [13:7] ins;
} rep_buffer_t;

typedef struct packed
{
	tid_t thread;
	logic v;
	order_tag_t tag;
	cpu_types_pkg::address_t pc;
	instruction_t insn;
	postfix_t pfx;
	postfix_t pfx2;
	postfix_t pfx3;
//	postfix_t pfx4;
	cause_code_t cause;
	logic [2:0] sp_sel;
} instruction_fetchbuf_t;

typedef struct packed
{
	logic v;
	cpu_types_pkg::aregno_t Ra;
	cpu_types_pkg::aregno_t Rb;
	cpu_types_pkg::aregno_t Rc;
	cpu_types_pkg::aregno_t Rt;
	cpu_types_pkg::aregno_t Rm;
	logic Rav;
	logic Rbv;
	logic Rcv;
	logic Rtv;
	logic Ran;
	logic Rbn;
	logic Rcn;
	logic Rtn;
	logic Raz;
	logic Rbz;
	logic Rcz;
	logic Rtz;
	logic [2:0] Rcc;	// Rc complement status
	logic regexc;			// reg exception - illegal register selection
	logic has_Rb;
	logic has_imm;
	logic has_imma;
	logic has_immb;
	logic has_immc;
	cpu_types_pkg::value_t imma;
	cpu_types_pkg::value_t immb;
	cpu_types_pkg::value_t immc;
	logic pfxa;
	logic pfxb;
	logic pfxc;
	logic csr;
	logic nop;				// NOP semantics
	logic fc;					// flow control op
	logic backbr;			// backwards target branch
	bts_t bts;				// branch target source
	logic r2;					// true if r1/r2 format instruction
	logic macro;			// true if macro instruction
	logic vec;				// true if vector instruction
	logic vec2;				// true if vector instruction
	logic mvvr;				// true if VR move (VEX / VRM)
	logic alu;				// true if instruction must use alu (alu or mem)
	logic alu0;				// true if instruction must use only alu #0
	logic alu_pair;		// true if instruction requires pair of ALUs
	logic fpu;				// FPU op
	logic fpu0;				// true if instruction must use only fpu #0
	memsz_t prc;			// precision of operation
	logic mul;
	logic mulu;
	logic div;
	logic divu;
	logic cap;
	logic bitwise;		// true if a bitwise operator (and, or, eor)
	logic multicycle;
	logic mem;
	logic load;
	logic loadz;
	logic cload;
	logic cload_tags;
	logic store;
	logic cstore;
	logic bstore;
	logic pushi;
	logic cls;
	logic lda;
	logic erc;
	logic fence;
	logic mcb;					// micro-code branch
	logic br;						// conditional branch
	logic cjb;					// call, jmp, or bra
	logic bsr;					// bra or bsr
	logic jsri;					// indirect subroutine call
	logic ret;
	logic brk;
	logic irq;
	logic rti;
	logic rex;
	logic pfx;
	logic sync;
	logic oddball;
	logic regs;					// register list modifier
	logic pred;					// is predicate instruction modifier
	logic predz;				// 1=zero out when predicate is false
	logic cpytgt;
	logic qfext;				// true if QFEXT modifier
} decode_bus_t;

/*
typedef struct packed
{
	logic v;
	logic regfetched;
	logic out;
	logic agen;
	logic executed;
	logic memory;
	logic imiss;
	tid_t thread;
	instruction_fetchbuf_t ifb;
	decode_bus_t	dec;
	logic [3:0] count;
	logic [3:0] step;
	logic [2:0] retry;		// retry count
	cause_code_t cause;
	cpu_types_pkg::address_t badAddr;
	cpu_types_pkg::quad_value_t a;
	cpu_types_pkg::quad_value_t b;
	cpu_types_pkg::quad_value_t c;
	cpu_types_pkg::quad_value_t t;
	cpu_types_pkg::value_t mask;
	cpu_types_pkg::quad_value_t res;
} pipeline_reg_t;
*/
typedef struct packed
{
	// The following fields may change state while an instruction is processed.
	logic v;									// 1=entry is valid, in use
	logic rstp;								// indicate physical register reset required
	cpu_types_pkg::pc_address_t brtgt;
	cpu_types_pkg::mc_address_t mcbrtgt;			// micro-code branch target
	logic takb;								// 1=branch evaluated to taken
	logic hwi;								// hardware interrupt occured during fetch
	logic [2:0] hwi_level;		// the level of the hardware interrupt
	logic [2:0] irq_mask;			// irq mask from sr.ipl or atom
	cause_code_t exc;					// non-zero indicate exception
	logic excv;								// 1=exception
	// The following fields are loaded at enqueue time, but otherwise do not change.
	logic bt;									// branch to be taken as predicted
	operating_mode_t om;			// operating mode
	decode_bus_t decbus;			// decoded instruction
	cpu_types_pkg::pregno_t pRa;							// physical registers (see decode bus for arch. regs)
	cpu_types_pkg::pregno_t pRb;
	cpu_types_pkg::pregno_t pRc;
	cpu_types_pkg::pregno_t pRt;							// current Rt value
	cpu_types_pkg::pregno_t nRt;							// new Rt
	cpu_types_pkg::pregno_t pRm;							// current Rt value
	checkpt_ndx_t cndx;					// checkpoint index
	// The following matches the ex_instruction_t
	cpu_types_pkg::pc_address_ex_t pc;			// PC of instruction
	cpu_types_pkg::mc_address_t mcip;				// Micro-code IP address
	logic [3:0] len;
	logic [2:0] element;
	logic [2:0] eno;
	cpu_types_pkg::aregno_t aRa;
	cpu_types_pkg::aregno_t aRb;
	cpu_types_pkg::aregno_t aRc;
	cpu_types_pkg::aregno_t aRt;
	cpu_types_pkg::aregno_t aRm;
	logic [5:0] pred_btst;
	instruction_t ins;				// original instruction
} pipeline_reg_t;


typedef struct packed {
	logic [4:0] imiss;
	logic sleep;
	cpu_types_pkg::address_t pc;				// current instruction pointer
	cpu_types_pkg::address_t miss_pc;	// I$ miss address
} ThreadInfo_t;

typedef struct packed {
	logic loaded;						// 1=loaded internally
	logic stored;						// 1=stored externally
	cpu_types_pkg::address_t pc;						// return address
	cpu_types_pkg::address_t sp;						// Stack pointer location
} return_stack_t;

// No unsigned codes!
parameter MR_LDB	= 4'd0;
parameter MR_LDW	= 4'd1;
parameter MR_LDT	= 4'd2;
parameter MR_LDO	= 4'd3;
parameter MR_LDH 	= 4'd4;
parameter MR_LDP	= 4'd5;
parameter MR_LDN	= 4'd6;
parameter MR_LDSR	= 4'd7;
parameter MR_LDV	= 4'd9;
parameter MR_LDG	= 4'd10;
parameter MR_LDPTG = 4'd0;
parameter MR_STPTG = 4'd1;
parameter MR_RAS 	= 4'd12;
parameter MR_STB	= 4'd0;
parameter MR_STW	= 4'd1;
parameter MR_STT	= 4'd2;
parameter MR_STO	= 4'd3;
parameter MR_STH	= 4'd4;
parameter MR_STP 	= 4'd5;
parameter MR_STN	= 4'd6;
parameter MR_STCR	= 4'd7;
parameter MR_STPTR	= 4'd9;

// All the fields in this structure are *output* back to the system.
typedef struct packed
{
	logic [7:0] tid;		// tran id
	order_tag_t tag;
	tid_t thread;
	logic [1:0] omode;	// operating mode
	cpu_types_pkg::pc_address_t ip;			// Debugging aid
	logic [5:0] step;		// vector step number
	logic [5:0] count;	// vector operation count
	logic wr;						// fifo write control
	memop_t func;				// operation to perform
	logic [3:0] func2;	// more resolution to function
	logic load;					// needed to place results
	logic store;
	logic group;
	logic need_steps;
	logic v;
	logic empty;
	cause_code_t cause;
	logic [3:0] cache_type;
	logic [63:0] sel;		// +16 for unaligned accesses
	cpu_types_pkg::asid_t asid;
	cpu_types_pkg::address_t adr;
	cpu_types_pkg::code_address_t vcadr;		// victim cache address
	logic dchit;
	logic cmt;
	memsz_t sz;					// indicates size of data
	logic [7:0] bytcnt;	// byte count of data to load/store
	logic [1:0] hit;
	logic [1:0] mod;		// line modified indicators
	logic [3:0] acr;		// acr bits from TLB lookup
	logic tlb_access;
	logic ptgram_en;
	logic rgn_en;
	logic pde_en;
	logic pmtram_ena;
	logic wr_tgt;
	regspec_t tgt;				// target register
	logic [511:0] res;		// stores unaligned data as well (must be last field)
} memory_arg_t;		//

// The full pipeline structure is not needed for writeback. The writeback fifos
// can be made smaller using a smaller structure.
// Ah, but it appears that writeback needs some of the instruction buffer.
// To support a few instructions like RTI and REX.
/*
typedef struct packed
{
	logic v;
	order_tag_t tag;
	cause_code_t cause;		// cause code
	code_address_t ip;		// address of instruction
	address_t adr;					// bad load/store address
	logic [5:0] step;			// vector step number
	logic [1023:0] res;		// instruction results
	logic wr_tgt;					// target register needs updating
	regspec_t tgt;				// target register
} writeback_info_t;
*/

const cpu_types_pkg::pc_address_t RSTPC	= 32'hFFFFFD80;
const cpu_types_pkg::address_t RSTSP = 32'hFFFF9000;

typedef logic [6:0] seqnum_t;

typedef struct packed
{
	logic [PREGS-1:0] avail;	// available registers at time of queue (for rollback)
//	cpu_types_pkg::pregno_t [AREGS-1:0] p2regmap;
	cpu_types_pkg::pregno_t [AREGS-1:0] pregmap;
	cpu_types_pkg::pregno_t [AREGS-1:0] regmap;
} checkpoint_t;

typedef struct packed {
	// The following fields may change state while an instruction is processed.
	logic v;									// 1=entry is valid, in use
	seqnum_t sn;							// sequence number, decrements when instructions que
//	logic [5:0] sync_dep;			// sync instruction dependency
//	logic [5:0] fc_dep;				// flow control dependency
//	logic [5:0] sync_no;
//	logic [5:0] fc_no;
	logic [3:0] predino;			// predicated instruction number (1 to 8)
	rob_ndx_t predrndx;				// ROB index of associate PRED instruction
	rob_ndx_t orid;						// ROB id of originating macro-instruction
	logic lsq;								// 1=instruction has associated LSQ entry
	lsq_ndx_t lsqndx;					// index to LSQ entry
	logic [1:0] out;					// 1=instruction is being executed
	logic [1:0] done;					// 2'b11=instruction is finished executing
	logic rstp;								// indicate physical register reset required
	logic [63:0] pred_status;	// predicate status for the next eight instructions.
	logic [7:0] pred_bits;		// predicte bits for this instruction.
	logic pred_bitv;					// 1=predicate bit is valid
	logic [1:0] vn;						// vector index
	logic chkpt_freed;
	cpu_types_pkg::pc_address_t brtgt;
	cpu_types_pkg::mc_address_t mcbrtgt;			// micro-code branch target
	logic takb;								// 1=branch evaluated to taken
	cause_code_t exc;					// non-zero indicate exception
	logic excv;								// 1=exception
	cpu_types_pkg::value_t argC;	// for stores
`ifdef IS_SIM
	cpu_types_pkg::value_t argA;
	cpu_types_pkg::value_t argB;
	cpu_types_pkg::value_t argI;
	cpu_types_pkg::value_t argT;
	cpu_types_pkg::value_t argM;
	cpu_types_pkg::value_t res;
`endif
	logic all_args_valid;			// 1 if all args are valid
	logic could_issue;				// 1 if instruction ready to issue
	logic could_issue_nm;			// 1 if instruction ready to issue NOP
	logic prior_sync;					// 1 if instruction has sync prior to it
	logic prior_fc;						// 1 if instruction has fc prior to it
	logic argA_vp;						// 1=argument A valid pending
	logic argB_vp;
	logic argC_vp;
	logic argT_vp;
	logic argM_vp;
	logic argA_v;							// 1=argument A valid
	logic argB_v;
	logic argC_v;
	logic argT_v;
	logic argM_v;
	logic rat_v;							// 1=checked with RAT for valid reg arg.
	cpu_types_pkg::value_t arg;							// argument value for CSR instruction
	// The following fields are loaded at enqueue time, but otherwise do not change.
	logic last;								// 1=last instruction in group (not used)
	rob_ndx_t group_len;			// length of instruction group (not used)
	logic bt;									// branch to be taken as predicted
	operating_mode_t om;			// operating mode
	decode_bus_t decbus;			// decoded instruction
	checkpt_ndx_t cndx;				// checkpoint index
	checkpt_ndx_t br_cndx;		// checkpoint index branch owns
	pipeline_reg_t op;			// original instruction
	cpu_types_pkg::pc_address_ex_t pc;			// PC of instruction
	cpu_types_pkg::mc_address_t mcip;				// Micro-code IP address
	seqnum_t grp;							// instruction group
} rob_entry_t;

typedef struct packed
{
	checkpt_ndx_t cndx;				// checkpoint index
	cpu_types_pkg::pc_address_ex_t pc;			// PC of instruction
	cpu_types_pkg::mc_address_t mcip;				// Micro-code IP address
	seqnum_t grp;							// instruction group
} rob_row_entry_t;

typedef struct packed
{
	rob_ndx_t rndx;
	rob_entry_t rob;
	cpu_types_pkg::value_t argA;
	cpu_types_pkg::value_t argB;
	cpu_types_pkg::value_t argC;
	cpu_types_pkg::value_t argT;
	cpu_types_pkg::value_t argM;
	logic argA_ctag;
	logic argB_ctag;
} fpu_iq_t;

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
	cpu_types_pkg::value_t argT;
	cpu_types_pkg::value_t argM;
	cpu_types_pkg::value_t res;
	cpu_types_pkg::pregno_t pRc;
	logic argC_v;
	checkpt_ndx_t cndx;				// checkpoint index
	ex_instruction_t op;			// original instruction
	cpu_types_pkg::pc_address_ex_t pc;			// PC of instruction
	cpu_types_pkg::mc_address_t mcip;				// Micro-code IP address
} beb_entry_t;

typedef struct packed {
	logic v;
	seqnum_t sn;
	logic agen;						// address generated through to physical address
	rob_ndx_t rndx;				// reference to related ROB entry
	cpu_types_pkg::virtual_address_t vadr;
	cpu_types_pkg::physical_address_t padr;
	operating_mode_t omode;	// operating mode
	logic load;						// 1=load
	logic loadz;
	logic cload;					// 1=cload
	logic cload_tags;
	logic store;
	logic cstore;
	ex_instruction_t op;
	cpu_types_pkg::pc_address_ex_t pc;
	memop_t func;					// operation to perform
	logic [3:0] func2;		// more resolution to function
	cause_code_t cause;
	logic [3:0] cache_type;
	logic [63:0] sel;			// +16 for unaligned accesses
	cpu_types_pkg::asid_t asid;
	cpu_types_pkg::code_address_t vcadr;		// victim cache address
	logic dchit;
	memsz_t memsz;				// indicates size of data
	logic [7:0] bytcnt;		// byte count of data to load/store
	cpu_types_pkg::pregno_t Rt;
	cpu_types_pkg::aregno_t aRt;					// reference for freeing
	logic aRtz;
	cpu_types_pkg::aregno_t aRc;
	cpu_types_pkg::pregno_t pRc;					// 'C' register for store
	checkpt_ndx_t cndx;
	operating_mode_t om;	// operating mode
	logic ctag;						// capabilities tag
	logic datav;					// store data is valid
	logic [511:0] res;		// stores unaligned data as well (must be last field)
} lsq_entry_t;

typedef struct packed {
	logic [15:0] pid;
	logic [7:0] pl;
	cpu_types_pkg::pc_address_t pc;
} mvec_entry_t;

// =============================================================================
// Support Functionss
// =============================================================================

function cpu_types_pkg::pc_address_t fnTargetIP;
input cpu_types_pkg::pc_address_t ip;
input cpu_types_pkg::value_t tgt;
reg [5:0] lo;
begin
	if (SUPPORT_IBH) begin
		case(tgt[3:0])
		4'd0:	lo = 6'd00;
		4'd1:	lo = 6'd05;
		4'd2:	lo = 6'd10;
		4'd3:	lo = 6'd15;
		4'd5:	lo = 6'd20;
		4'd6:	lo = 6'd25;
		4'd7:	lo = 6'd30;
		4'd8:	lo = 6'd35;
		4'd9:	lo = 6'd40;
		4'd11:	lo = 6'd45;
		4'd12:	lo = 6'd50;
		4'd13:	lo = 6'd55;
		default:	lo = 6'd60;
		endcase
		fnTargetIP = {ip[$bits(cpu_types_pkg::pc_address_t)-1:6]+tgt[$bits(cpu_types_pkg::value_t)-1:4],lo};
	end
	else
		fnTargetIP = ip+{tgt,3'b0};	// tgt*8
end
endfunction


/*
function pc_address_t fnTgtIP;
input pc_address_t ip;
input bts_t bts;
input instruction_t instr;
reg [5:0] ino;
reg [5:0] ino5;
value_t disp;
mc_address_t miss_mcip;
begin
	ino = {2'd0,instr[26:25],instr[12:11]};
	ino5 = {ino,2'd0} + ino;
	disp = {{47{instr[39]}},instr[39:25],instr[12:11]};
	miss_mcip = 12'h1A0;
	case (bts)
	BTS_DISP:
		begin
			fnTgtIP = fnTargetIP(ip,disp);
		end
	BTS_BSR:
		begin
			if (SUPPORT_IBH) begin
				ino = {2'd0,instr[16:13]};
				case(ino[3:0])
				4'd0:	ino5 = 6'd00;
				4'd1:	ino5 = 6'd05;
				4'd2:	ino5 = 6'd10;
				4'd3:	ino5 = 6'd15;
				4'd5:	ino5 = 6'd20;
				4'd6:	ino5 = 6'd25;
				4'd7:	ino5 = 6'd30;
				4'd8:	ino5 = 6'd35;
				4'd9:	ino5 = 6'd40;
				4'd11:	ino5 = 6'd45;
				4'd12:	ino5 = 6'd50;
				4'd13:	ino5 = 6'd55;
				default:	ino5 = 6'd60;
				endcase
				fnTgtIP = {ip[$bits(pc_address_t)-1:6] + {{37{instr[39]}},instr[39:17]},ino5};
			end
			else
				fnTgtIP = ip + {{37{instr[39]}},instr[39:13]};
		end
	BTS_CALL:
		begin
			fnTgtIP = argA + argI;
		end
	// Must be tested before Ret
	BTS_RTI:
		begin
			fnTgtIP = (instr[8:7]==2'd1 ? pc_stack[1] : pc_stack[0]) + instr[12:7];
		end
	BTS_RET:
		begin
			tgtpc = argA + instr[10:7];
		end
	default:
		tgtpc = RSTPC;
	endcase
end
endfunction
*/

function fnIsBranch;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_DBRA,
	OP_Bcc,OP_BccU,OP_FBcc:
		fnIsBranch = 1'b1;
	default:
		fnIsBranch = 1'b0;
	endcase
end
endfunction

function fnIsBccR;
input instruction_t ir;
begin
	fnIsBccR = fnIsBranch(ir) && ir[39:36]==4'h7;
end
endfunction

function fnBranchDispSign;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_BSR,OP_DBRA:
		fnBranchDispSign = ir[63];
	OP_Bcc,OP_BccU,OP_FBcc:
		fnBranchDispSign = ir[63];
	default:	fnBranchDispSign = 1'b0;
	endcase	
end
endfunction

function [63:0] fnBranchDisp;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_DBRA,
	OP_Bcc,OP_BccU,OP_FBcc:
		fnBranchDisp = {{41{ir[63]}},ir[63:44]};
	OP_BSR:	fnBranchDisp = {{11{ir.bsr.disp[49]}},ir.bsr.disp};
	default:	fnBranchDisp = 'd0;
	endcase
end
endfunction

function fnIsJsr;
input instruction_t ir;
begin
	fnIsJsr = ir.any.opcode==OP_JSR;
end
endfunction

function fnIsCall;
input instruction_t ir;
begin
	fnIsCall = ir.any.opcode==OP_JSR;
end
endfunction

function fnIsBsr;
input instruction_t ir;
begin
	fnIsBsr = ir.any.opcode==OP_BSR;
end
endfunction

function fnIsCallType;
input instruction_t ir;
begin
	if (ir.any.opcode==OP_JSR && ir.jsr.Rt.num!=8'd0)
		fnIsCallType = 1'b1;
	else if (ir.any.opcode==OP_BSR && ir.bsr.Rt!=3'd0)
		fnIsCallType = 1'b1;
	else
		fnIsCallType = 1'b0;
end
endfunction

function fnIsRet;
input instruction_t ir;
begin
	fnIsRet = 1'b0;
	case(ir.any.opcode)
	OP_RTD:
		fnIsRet = ir[11:10]==2'd0;
	default:
		fnIsRet = 1'b0;
	endcase
end
endfunction

function fnIsRti;
input instruction_t ir;
begin
	fnIsRti = 1'b0;
	case(ir.any.opcode)
	OP_RTD:
		fnIsRti = ir[11:10]==3'd1 || ir[11:10]==3'd2;	
	default:
		fnIsRti = 1'b0;
	endcase
end
endfunction
/*
function fnIsRti;
input instruction_t ir;
begin
	fnIsRti = (fnIsRet(ir) && ir[10:9]==2'd1);
end
endfunction
*/
function fnIsFlowCtrl;
input instruction_t ir;
begin
	fnIsFlowCtrl = 1'b0;
	case(ir.any.opcode)
	OP_CHK:	fnIsFlowCtrl = 1'b1;
	OP_JSR:
		fnIsFlowCtrl = 1'b1;
	OP_DBRA,
	OP_Bcc,OP_BccU,OP_FBcc:
		fnIsFlowCtrl = 1'b1;	
	OP_BSR,OP_RTD:
		fnIsFlowCtrl = 1'b1;	
	default:
		fnIsFlowCtrl = 1'b0;
	endcase
end
endfunction

function fnConstReg;
input [7:0] Rn;
begin
	fnConstReg = Rn==8'd0 || Rn==8'd255;	// reg zero
end
endfunction

//
// 1 if the the operand is automatically valid, 
// 0 if we need a RF value
function fnSourceAv;
input ex_instruction_t ir;
begin
	case(ir.ins.r2.opcode)
	OP_CHK:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_R2,OP_R3V,OP_R3VS:
		case(ir.ins.r2.func)
		FN_ADD:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
		FN_CMP:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
		FN_MUL:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
		FN_MULW:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
		FN_DIV:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
		FN_SUB:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
		FN_MULU: fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
		FN_MULUW: fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
		FN_DIVU:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
		FN_AND:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
		FN_OR:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
		FN_EOR:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
		FN_NAND:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
		FN_NOR:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
		FN_ENOR:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
		FN_MINMAX:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
		FN_MVVR:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
		default:	fnSourceAv = 1'b1;
		endcase
	OP_RTD:		fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_JSR,
	OP_ADDI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_SUBFI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_CMPI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_MULI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_DIVI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_ANDI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_ORI:		fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_EORI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_AIPSI:	fnSourceAv = 1'b1;
	OP_ADDSI:	fnSourceAv = fnConstReg(ir.aRt) || fnImma(ir);
	OP_ANDSI:	fnSourceAv = fnConstReg(ir.aRt) || fnImma(ir);
	OP_ORSI:	fnSourceAv = fnConstReg(ir.aRt) || fnImma(ir);
	OP_EORSI:	fnSourceAv = fnConstReg(ir.aRt) || fnImma(ir);
	OP_SHIFT:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_SEQI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_SNEI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_SLTI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_SLEI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_SGTI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_SGEI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_SLTUI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_SLEUI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_SGTUI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_SGEUI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_ZSEQI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_ZSNEI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_ZSLTI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_ZSLEI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_ZSGTI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_ZSGEI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_ZSLTUI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_ZSLEUI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_ZSGTUI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_ZSGEUI:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_MOV:		fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_DBRA:	fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_Bcc,OP_BccU,OP_FBcc:
		fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_LDA,
	OP_LDx,OP_FLDx,OP_DFLDx,OP_PLDx,OP_LDxU:
		fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_STx,OP_FSTx,OP_DFSTx,OP_PSTx:
		fnSourceAv = fnConstReg(ir.aRa) || fnImma(ir);
	OP_PRED:
		fnSourceAv = fnConstReg(ir.aRa);
	default:	fnSourceAv = 1'b1;
	endcase
end
endfunction

function fnSourceBv;
input ex_instruction_t ir;
begin
	case(ir.ins.r2.opcode)
	OP_CHK:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
	OP_R2,OP_R3V,OP_R3VS:
		case(ir.ins.r2.func)
		FN_ADD:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_CMP:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_MUL:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_MULW:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_DIV:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_SUB:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_MULU: fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_MULUW: fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_DIVU: fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_AND:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_OR:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_EOR:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_NAND:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_NOR:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_ENOR:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_MINMAX:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_SEQ:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_SNE:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_SLT:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_SLE:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_SLTU:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_SLEU:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_ZSEQ:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_ZSNE:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_ZSLT:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_ZSLE:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_ZSLTU:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		FN_ZSLEU:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		default:	fnSourceBv = 1'b1;
		endcase
	OP_RTD:		fnSourceBv = 1'b0;
	OP_JSR,OP_BSR,
	OP_ADDI:	fnSourceBv = 1'b1;
	OP_SUBFI:	fnSourceBv = 1'b1;
	OP_CMPI:	fnSourceBv = 1'b1;
	OP_MULI:	fnSourceBv = 1'b1;
	OP_DIVI:	fnSourceBv = 1'b1;
	OP_ANDI:	fnSourceBv = 1'b1;
	OP_ORI:		fnSourceBv = 1'b1;
	OP_EORI:	fnSourceBv = 1'b1;
	OP_SHIFT,OP_VSHIFT:
		case(ir.ins.shifti.func[3])
		1'b0:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
		1'b1: fnSourceBv = 1'b1;
		endcase
	OP_DBRA:	fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
	OP_DBRA,
	OP_Bcc,OP_BccU,OP_FBcc:
		fnSourceBv = fnConstReg(ir.aRb) || fnImmb(ir);
	OP_LDA,
	OP_LDx,OP_FLDx,OP_DFLDx,OP_PLDx,OP_LDxU:
		fnSourceBv = fnConstReg(ir.aRb);
	OP_STx,OP_FSTx,OP_DFSTx,OP_PSTx:
		fnSourceBv = fnConstReg(ir.aRb);
	default:	fnSourceBv = 1'b1;
	endcase
end
endfunction

function fnSourceCv;
input ex_instruction_t ir;
begin
	case(ir.ins.r2.opcode)
	OP_CHK:	fnSourceCv = fnConstReg(ir.aRc);
	OP_R2,OP_R3V,OP_R3VS:
		case(ir.ins.r2.func)
		FN_ADD:	fnSourceCv = fnConstReg(ir.aRc);
		FN_CMP:	fnSourceCv = fnConstReg(ir.aRc);
		FN_MUL:	fnSourceCv = fnConstReg(ir.aRc);
		FN_MULW:	fnSourceCv = fnConstReg(ir.aRc);
		FN_DIV:	fnSourceCv = fnConstReg(ir.aRc);
		FN_SUB:	fnSourceCv = fnConstReg(ir.aRc);
		FN_MULU: fnSourceCv = fnConstReg(ir.aRc);
		FN_MULUW: fnSourceCv = fnConstReg(ir.aRc);
		FN_DIVU: fnSourceCv = fnConstReg(ir.aRc);
		FN_AND:	fnSourceCv = fnConstReg(ir.aRc);
		FN_OR:	fnSourceCv = fnConstReg(ir.aRc);
		FN_EOR:	fnSourceCv = fnConstReg(ir.aRc);
		FN_NAND:	fnSourceCv = fnConstReg(ir.aRc);
		FN_NOR:	fnSourceCv = fnConstReg(ir.aRc);
		FN_ENOR:	fnSourceCv = fnConstReg(ir.aRc);
		FN_MINMAX:	fnSourceCv = fnConstReg(ir.aRc);
		FN_SEQ:	fnSourceCv = fnConstReg(ir.aRc);
		FN_SNE:	fnSourceCv = fnConstReg(ir.aRc);
		FN_SLT:	fnSourceCv = fnConstReg(ir.aRc);
		FN_SLE:	fnSourceCv = fnConstReg(ir.aRc);
		FN_SLTU:	fnSourceCv = fnConstReg(ir.aRc);
		FN_SLEU:	fnSourceCv = fnConstReg(ir.aRc);
		FN_ZSEQ:	fnSourceCv = fnConstReg(ir.aRc);
		FN_ZSNE:	fnSourceCv = fnConstReg(ir.aRc);
		FN_ZSLT:	fnSourceCv = fnConstReg(ir.aRc);
		FN_ZSLE:	fnSourceCv = fnConstReg(ir.aRc);
		FN_ZSLTU:	fnSourceCv = fnConstReg(ir.aRc);
		FN_ZSLEU:	fnSourceCv = fnConstReg(ir.aRc);
		default:	fnSourceCv = 1'b1;
		endcase
	OP_ADDSI,OP_ANDSI,OP_ORSI,OP_EORSI:
		fnSourceCv = fnConstReg(ir.aRc);
	OP_STx,OP_FSTx,OP_DFSTx,OP_PSTx:
		fnSourceCv = fnConstReg(ir.aRc);
	OP_DBRA,OP_JSR,OP_BSR,
	OP_Bcc,OP_BccU,OP_FBcc:
		fnSourceCv = 1'b1;	
	OP_RTD:
		fnSourceCv = 1'd0;
	default:
		fnSourceCv = 1'b1;
	endcase
end
endfunction

function fnSourceTv;
input ex_instruction_t ir;
begin
	casez(ir.ins.r2.opcode)
	OP_CHK:	fnSourceTv = 1'b1;
	OP_R2,OP_R3V,OP_R3VS:
		case(ir.ins.r2.func)
		FN_ADD:	fnSourceTv = fnConstReg(ir.aRt);
		FN_CMP:	fnSourceTv = fnConstReg(ir.aRt);
		FN_MUL:	fnSourceTv = fnConstReg(ir.aRt);
		FN_MULW:	fnSourceTv = fnConstReg(ir.aRt);
		FN_DIV:	fnSourceTv = fnConstReg(ir.aRt);
		FN_SUB:	fnSourceTv = fnConstReg(ir.aRt);
		FN_MULU: fnSourceTv = fnConstReg(ir.aRt);
		FN_MULUW: fnSourceTv = fnConstReg(ir.aRt);
		FN_DIVU: fnSourceTv = fnConstReg(ir.aRt);
		FN_AND:	fnSourceTv = fnConstReg(ir.aRt);
		FN_OR:	fnSourceTv = fnConstReg(ir.aRt);
		FN_EOR:	fnSourceTv = fnConstReg(ir.aRt);
		FN_NAND:	fnSourceTv = fnConstReg(ir.aRt);
		FN_NOR:	fnSourceTv = fnConstReg(ir.aRt);
		FN_ENOR:	fnSourceTv = fnConstReg(ir.aRt);
		FN_MINMAX:	fnSourceTv = fnConstReg(ir.aRt);
		FN_SEQ:	fnSourceTv = fnConstReg(ir.aRt);
		FN_SNE:	fnSourceTv = fnConstReg(ir.aRt);
		FN_SLT:	fnSourceTv = fnConstReg(ir.aRt);
		FN_SLE:	fnSourceTv = fnConstReg(ir.aRt);
		FN_SLEU:	fnSourceTv = fnConstReg(ir.aRt);
		FN_SLTU:	fnSourceTv = fnConstReg(ir.aRt);
		FN_ZSEQ:	fnSourceTv = fnConstReg(ir.aRt);
		FN_ZSNE:	fnSourceTv = fnConstReg(ir.aRt);
		FN_ZSLT:	fnSourceTv = fnConstReg(ir.aRt);
		FN_ZSLE:	fnSourceTv = fnConstReg(ir.aRt);
		FN_ZSLEU:	fnSourceTv = fnConstReg(ir.aRt);
		FN_ZSLTU:	fnSourceTv = fnConstReg(ir.aRt);
		default:	fnSourceTv = 1'b1;
		endcase
	OP_JSR,
	OP_ADDI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_SUBFI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_CMPI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_MULI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_DIVI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_ANDI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_ORI:		fnSourceTv = fnConstReg(ir.aRt);
	OP_EORI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_AIPSI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_ADDSI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_ANDSI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_ORSI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_EORSI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_SHIFT:	fnSourceTv = fnConstReg(ir.aRt);

	OP_SEQI:	fnSourceTv = fnConstReg(ir.aRa);
	OP_SNEI:	fnSourceTv = fnConstReg(ir.aRa);
	OP_SLTI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_SLEI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_SGTI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_SGEI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_SLTUI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_SLEUI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_SGTUI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_SGEUI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_ZSEQI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_ZSNEI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_ZSLTI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_ZSLEI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_ZSGTI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_ZSGEI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_ZSLTUI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_ZSLEUI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_ZSGTUI:	fnSourceTv = fnConstReg(ir.aRt);
	OP_ZSGEUI:	fnSourceTv = fnConstReg(ir.aRt);

	OP_MOV:		fnSourceTv = fnConstReg(ir.aRt);
	OP_LDA,
	OP_LDx,OP_FLDx,OP_DFLDx,OP_PLDx,OP_LDxU:
		fnSourceTv = fnConstReg(ir.aRt);
	OP_STx,OP_FSTx,OP_DFSTx,OP_PSTx:
		fnSourceTv = 1'b1;
	OP_DBRA: fnSourceTv = 1'b1;
	OP_Bcc,OP_BccU,OP_FBcc:
		fnSourceTv = fnConstReg(ir.aRt);//ir.ins.br.inc==2'b00||ir.ins.br.inc==2'd2;
	OP_RTD:	fnSourceTv = 1'b0;
	OP_PRED:
		fnSourceTv = 1'b1;
	default:
		fnSourceTv = 1'b1;
	endcase
end
endfunction

function fnSourceMv;
input ex_instruction_t ir;
begin
	fnSourceMv = 1'b1;
end
endfunction

// If the instruction is followed by a vector postfix then it
// uses a mask register, otherwise it does not.
function fnSourcePv;
input ex_instruction_t ir;
reg vec,veci,vecf;
begin
	// ToDo: fix for vector instructions
	vec = 1'b0;//ir.r2.pfx_opcode==OP_VEC || ir.r2.pfx_opcode==OP_VECZ;
	veci = 1'b0;//ir.ri.pfx_opcode==OP_VEC || ir.ri.pfx_opcode==OP_VECZ;
	vecf = 1'b0;//ir.f2.pfx_opcode==OP_VEC || ir.f2.pfx_opcode==OP_VECZ;
	casez(ir.ins.r2.opcode)
	OP_CHK:	fnSourcePv = ~vec;
	OP_R2,OP_R3V,OP_R3VS:
		case(ir.ins.r2.func)
		FN_ADD:	fnSourcePv = ~vec;
		FN_CMP:	fnSourcePv = ~vec;
		FN_MUL:	fnSourcePv = ~vec;
		FN_DIV:	fnSourcePv = ~vec;
		FN_SUB:	fnSourcePv = ~vec;
		FN_MULU: fnSourcePv = ~vec;
		FN_DIVU: fnSourcePv = ~vec;
		FN_AND:	fnSourcePv = ~vec;
		FN_OR:	fnSourcePv = ~vec;
		FN_EOR:	fnSourcePv = ~vec;
		FN_NAND:	fnSourcePv = ~vec;
		FN_NOR:	fnSourcePv = ~vec;
		FN_ENOR:	fnSourcePv = ~vec;
		FN_MINMAX:	fnSourcePv = ~vec;
		FN_SEQ:	fnSourcePv = ~vec;
		FN_SNE:	fnSourcePv = ~vec;
		FN_SLT:	fnSourcePv = ~vec;
		FN_SLE:	fnSourcePv = ~vec;
		FN_SLTU:	fnSourcePv = ~vec;
		FN_SLEU:	fnSourcePv = ~vec;
		FN_ZSEQ:	fnSourcePv = ~vec;
		FN_ZSNE:	fnSourcePv = ~vec;
		FN_ZSLT:	fnSourcePv = ~vec;
		FN_ZSLE:	fnSourcePv = ~vec;
		FN_ZSLTU:	fnSourcePv = ~vec;
		FN_ZSLEU:	fnSourcePv = ~vec;
		default:	fnSourcePv = 1'b1;
		endcase
	OP_JSR,
	OP_ADDI:	fnSourcePv = ~veci;
	OP_CMPI:	fnSourcePv = ~veci;
	OP_MULI:	fnSourcePv = ~veci;
	OP_DIVI:	fnSourcePv = ~veci;
	OP_ANDI:	fnSourcePv = ~veci;
	OP_ORI:		fnSourcePv = ~veci;
	OP_EORI:	fnSourcePv = ~veci;
	OP_SHIFT:	fnSourcePv = ~vec;
	OP_FLT3:	fnSourcePv = ~vecf;	
	OP_MOV:		fnSourcePv = ~vec;
	OP_LDx,OP_FLDx,OP_DFLDx,OP_PLDx,OP_LDxU:
		fnSourcePv = ~veci;
	OP_STx,OP_FSTx,OP_DFSTx,OP_PSTx:
		fnSourcePv = ~veci;
	OP_DBRA,
	8'b00101???:
		fnSourcePv = 1'b1;
	default:
		fnSourcePv = 1'b1;
	endcase
end
endfunction

function fnIsLoad;
input instruction_t op;
begin
	case(op.any.opcode)
	OP_LDx,OP_FLDx,OP_DFLDx,OP_PLDx,OP_LDxU:
		fnIsLoad = 1'b1;
	default:
		fnIsLoad = 1'b0;
	endcase
end
endfunction

function fnIsLoadz;
input instruction_t op;
begin
	case(op.any.opcode)
	OP_LDxU:
		fnIsLoadz = 1'b1;
	default:
		fnIsLoadz = 1'b0;
	endcase
end
endfunction

function fnIsStore;
input instruction_t op;
begin
	case(op.any.opcode)
	OP_STx,OP_FSTx,OP_DFSTx,OP_PSTx:
		fnIsStore = 1'b1;
	default:
		fnIsStore = 1'b0;
	endcase
end
endfunction

function fnIsMem;
input instruction_t ir;
begin
	fnIsMem = fnIsLoad(ir) || fnIsStore(ir);
end
endfunction
/*
function [63:0] fnImm;
input instruction_t [4:0] ins;
reg [1:0] sz;
begin
	fnImm = 'd0;
	case(ins[0].any.opcode)
	OP_ADDI,OP_CMPI,OP_MULI,OP_DIVI,OP_SUBFI:
		fnImm = {{48{ins[0][34]}},ins[0][34:19]};
	OP_ANDI:	fnImm = {48'hFFFFFFFFFFFF,ins[0][34:19]};
	OP_ORI,OP_EORI:
		fnImm = {48'h0000,ins[0][34:19]};
	OP_RTD:	fnImm = {{16{ins[0][34]}},ins[0][34:19]};
	OP_LDB,OP_LDBU,OP_LDW,OP_LDWU,OP_LDT,OP_LDTU,OP_LDO,OP_CACHE,
	OP_STB,OP_STW,OP_STT,OP_STO:
		fnImm = {{52{ins[0][34]}},ins[0][34:23]};
	default:
		fnImm = 'd0;
	endcase
	if (ins[1].any.opcode==OP_PFX) begin
		fnImm = {{32{ins[1][39]}},ins[1][39:8]};
		if (ins[2].any.opcode==OP_PFX)
			fnImm[63:32] = ins[2][39:8];
	end
end
endfunction
*/
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
	OP_RTD:
		fnImmb = 1'b1;
	OP_LDx,OP_FLDx,OP_DFLDx,OP_PLDx,OP_LDxU,OP_CACHE,
	OP_STx,OP_FSTx,OP_DFSTx,OP_PSTx:
		fnImmb = 1'b1;
//	OP_LDX,OP_STX:
//		fnImmb = &ir.ins.lsn.Rb;
	default:	fnImmb = 1'b0;
	endcase
end
endfunction

function fnImmc;
input ex_instruction_t ir;
begin
	fnImmc = 1'b0;
end
endfunction

function [5:0] fnInsLen;
input [45:0] ins;
begin
	fnInsLen = 6'd5;
end
endfunction

function fnIsNop;
input instruction_t ir;
begin
	fnIsNop = ir.any.opcode==OP_NOP ||
		ir.any.opcode==OP_PFXAB ||
		ir.any.opcode==OP_PFXC
		;
		/*
		ir.any.opcode==OP_PFXA ||
		ir.any.opcode==OP_PFXB ||
		ir.any.opcode==OP_PFXC
		;
		*/
end
endfunction

/*
function fnIsDiv;
input instruction_t ir;
begin
	fnIsDiv = fnIsDivs(ir) || fnIsDivu(ir);
end
endfunction
*/

function fnIsIrq;
input instruction_t ir;
begin
	fnIsIrq = 1'b0;//ir.any.opcode==OP_CHK && ir.sys.func==FN_IRQ;
end
endfunction

function fnIsAtom;
input instruction_t ir;
begin
	fnIsAtom = ir.any.opcode==OP_ATOM;
end
endfunction

function fnIsPred;
input instruction_t ir;
begin
	fnIsPred = ir.any.opcode==OP_PRED;
end
endfunction

function fnIsPostfix;
input instruction_t ir;
begin
	fnIsPostfix = //ir.any.opcode==OP_PFXA || ir.any.opcode==OP_PFXB || ir.any.opcode==OP_PFXC;
		ir.any.opcode==OP_PFXAB ||
		ir.any.opcode==OP_PFXC;
		;
end
endfunction

// Sign or zero extend data as needed according to op.
function [63:0] fnDati;
input more;
input instruction_t ins;
input cpu_types_pkg::value_t dat;
input cpu_types_pkg::pc_address_t pc;
case(ins.any.opcode)
OP_LDx,OP_FLDx,OP_DFLDx,OP_PLDx,OP_LDxU:
	case(ins.ls.prc)
	2'd0:	fnDati = {{56{dat[7]}},dat[7:0]};
	2'd1:
		if (more)
			fnDati = {48'd0,dat[15:0]};
		else
	  	fnDati = {{48{dat[15]}},dat[15:0]};
	2'd2:
		if (more)
			fnDati = {32'd0,dat[31:0]};
		else
			fnDati = {{32{dat[31]}},dat[31:0]};
	2'd3:	fnDati = dat[63:0];
	endcase
OP_LDxU:
	case(ins.ls.prc)
	2'd0:	fnDati = {{56{1'b0}},dat[7:0]};
	2'd1:	fnDati = {{48{1'b0}},dat[15:0]};
	2'd2: fnDati = {{32{1'b0}},dat[31:0]};
	2'd3: fnDati = dat[63:0];
	endcase
OP_JSRI:
	case(ins[18:17])
	2'd0:	fnDati = {pc[$bits(cpu_types_pkg::pc_address_t)-1:16],dat[15:0]};
	2'd1:	fnDati = {dat[31:0]};
	2'd2:	fnDati = dat[63:0];
	default:	fnDati = dat[63:0];
	endcase
default:    fnDati = dat;
endcase
endfunction

function memsz_t fnMemsz;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_LDx,OP_LDxU,OP_STx:
		case(ir.ls.prc)
		2'd0:	fnMemsz = byt;
		2'd1:	fnMemsz = wyde;
		2'd2:	fnMemsz = tetra;
		2'd3: fnMemsz = octa;
		endcase
	OP_FLDx,OP_FSTx:
		case(ir.ls.prc)
		2'd0:	fnMemsz = hexi;
		2'd1:	fnMemsz = wyde;
		2'd2:	fnMemsz = tetra;
		2'd3: fnMemsz = octa;
		endcase
	OP_DFLDx,OP_DFSTx:
		case(ir.ls.prc)
		2'd0:	fnMemsz = hexi;
		2'd1:	fnMemsz = hexi;
		2'd2:	fnMemsz = hexi;
		2'd3: fnMemsz = octa;
		endcase
	OP_PLDx,OP_PSTx:
		case(ir.ls.prc)
		2'd0:	fnMemsz = hexi;
		2'd1:	fnMemsz = wyde;
		2'd2:	fnMemsz = tetra;
		2'd3: fnMemsz = octa;
		endcase
	OP_JSRI:
		case(ir[31])
		1'd0: fnMemsz = tetra;
		1'd1:	fnMemsz = octa;
		endcase
	default:
		fnMemsz = octa;
	endcase
end
endfunction

function [15:0] fnSel;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_LDx,OP_LDxU,OP_STx:
		case(ir.ls.prc)
		2'd0:	fnSel = 16'h0001;
		2'd1:	fnSel = 16'h0003;
		2'd2:	fnSel = 16'h000F;
		2'd3: fnSel = 16'h00FF;
		endcase
	OP_FLDx,OP_FSTx:
		case(ir.ls.prc)
		2'd0:	fnSel = 16'hFFFF;
		2'd1:	fnSel = 16'h0003;
		2'd2:	fnSel = 16'h000F;
		2'd3: fnSel = 16'h00FF;
		endcase
	OP_DFLDx,OP_DFSTx:
		case(ir.ls.prc)
		2'd0:	fnSel = 16'hFFFF;
		2'd1:	fnSel = 16'hFFFF;
		2'd2:	fnSel = 16'hFFFF;
		2'd3: fnSel = 16'h00FF;
		endcase
	OP_PLDx,OP_PSTx:
		case(ir.ls.prc)
		2'd0:	fnSel = 16'h0001;
		2'd1:	fnSel = 16'h0003;
		2'd2:	fnSel = 16'h000F;
		2'd3: fnSel = 16'h00FF;
		endcase
	OP_JSRI:
		case(ir[31])
		1'd0: fnSel = 16'h000F;
		1'd1:	fnSel = 16'h00FF;
		default:	fnSel = 16'h00FF;
		endcase
	default:
		fnSel = 16'h00FF;
	endcase
end
endfunction

function fnIsMacroInstr;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_ENTER,OP_LEAVE,OP_PUSH,OP_POP:
		fnIsMacroInstr = 1'b1;
	default:
		fnIsMacroInstr = 1'b0;
	endcase
end
endfunction

function fnIsBackBranch;
input instruction_t ir;
begin
	fnIsBackBranch = (fnIsBranch(ir) && fnBranchDispSign(ir))|fnIsMacroInstr(ir);
end
endfunction

function cpu_types_pkg::pc_address_t fnPCInc;
input cpu_types_pkg::pc_address_t pc;
begin
	if (0) begin	//ICacheBundleWidth==120) begin
		case(pc[3:0])
		4'h0:	fnPCInc = pc + 4'h5;
		4'h5:	fnPCInc = pc + 4'h5;
		4'hA:	fnPCInc = pc + 4'h6;
		default:	fnPCInc = pc + 4'h5;
		endcase
	end
	else begin
		fnPCInc = pc + 4'h8;
	end
end
endfunction

endpackage
