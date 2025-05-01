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

package Stark_pkg;
`define STARK_PKG 1'b1
`undef IS_SIM
parameter SIM = 1'b1;
`define IS_SIM	1

// Comment out to remove the sigmoid approximate function
//`define SIGMOID	1

// Number of architectural registers there are in the core, including registers
// not visible in the programming model. Includes all operating modes.
`define NREGS	224

// Number of physical registers supporting the architectural ones and used in
// register renaming. There must be significantly more physical registers than
// architectural ones, or performance will suffer due to stalls.
// Must be a multiple of four. If it is not 512 or 256 then the renamer logic will
// need to be modified.
parameter PREGS = 512;

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
parameter RENAMER = 6;

// Comment out the following to remove the RAT
`define SUPPORT_RAT 1;

// =============================================================================
// =============================================================================

// 1=defer interrupts to the start of the next instruction.
// 2=record micro-op number for instruction restart (not recommended).
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
parameter PERFORMANCE = 1'b1;

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

// This parameter adds support for capabilities. Increases the size of the core.
// An FPU must also be enabled.
parameter SUPPORT_CAPABILITIES = 1'b0;

// This parameter enables support for quad (128-bit) precision operations.
parameter SUPPORT_QUAD_PRECISION = 1'b0;

// Supporting load bypassing may improve performance, but will also increase the
// size of the core and make it more vulnerable to security attacks.
parameter SUPPORT_LOAD_BYPASSING = 1'b0;

parameter SUPPORT_PREC = 1'b0;

// The following controls the size of the reordering buffer.
// Setting ROB_ENTRIES below 12 may not work. Setting the number of entries over
// 63 may require changing the sequence number type. For ideal construction 
// should be a multiple of four.
parameter ROB_ENTRIES = 32;

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

parameter AREGS = `NREGS;
parameter REGFILE_LATENCY = 2;
parameter INSN_LEN = 8'd4;

const cpu_types_pkg::pc_address_t RSTPC	= 32'hFFFFFD80;
const cpu_types_pkg::address_t RSTSP = 32'hFFFF9000;

// =============================================================================
// Resources
// =============================================================================

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
parameter FPU0_IQ_DEPTH = 32;
parameter FPU1_IQ_DEPTH = 32;
parameter NLSQ_PORTS = 1;
parameter SUPPORT_IDIV = 1;
parameter SUPPORT_TRIG = 1;

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

typedef struct packed
{
	logic [2:0] row;
	logic col;
} lsq_ndx_t;

typedef enum logic [1:0] {
	OM_APP = 2'd0,
	OM_SUPERVISOR = 2'd1,
	OM_HYPERVISOR = 2'd2,
	OM_SECURE = 2'd3
} operating_mode_t;

typedef logic [4:0] regspec_t;
typedef logic [NREGS-1:1] reg_bitmask_t;
typedef logic [ROB_ENTRIES-1:0] rob_bitmask_t;
typedef logic [LSQ_ENTRIES-1:0] lsq_bitmask_t;
typedef logic [3:0] beb_ndx_t;

typedef struct packed
{
	logic [Stark_pkg::PREGS-1:0] avail;	// available registers at time of queue (for rollback)
//	cpu_types_pkg::pregno_t [AREGS-1:0] p2regmap;
	cpu_types_pkg::pregno_t [Stark_pkg::AREGS-1:0] pregmap;
	cpu_types_pkg::pregno_t [Stark_pkg::AREGS-1:0] regmap;
} checkpoint_t;

typedef struct packed
{
	logic resv;
	logic so;				// summary overflow / unordered
	logic ca;				// carry / infinite
	logic le;
	logic lt;
	logic _nor;
	logic _nand;
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
	BRC_BL = 10'h001,
	BRC_BLRLR = 10'h002,
	BRC_BLRLC = 10'h004,
	BRC_BCCD = 10'h008,
	BRC_BCCR = 10'h010,
	BRC_BCCC = 10'h020,
	BRC_RETR = 10'h040,
	BRC_RETC = 10'h080,
	BRC_ERET = 10'h100,
	BRC_ECALL = 10'h200
} brclass_t;

parameter BRC_BLR = BRC_BLRLR|BRC_BLRLC;
parameter BRC_BCC = BRC_BCCR|BRC_BCCD|BRC_BCCC;
parameter BRC_RET = BRC_RETR|BRC_RETC;

typedef enum logic [2:0] {
	BS_IDLE = 3'd0,
	BS_CHKPT_RESTORE = 3'd1,
	BS_CHKPT_RESTORED = 3'd2,
	BS_STATE3 = 3'd3,
	BS_CAPTURE_MISSPC = 3'd4,
	BS_DONE = 3'd5,
	BS_DONE2 = 3'd6
} branch_state_t;

typedef enum logic [5:0] {
	OP_BRK = 6'd0,
	OP_SHIFT = 6'd2,
	OP_CMP = 6'd3,
	OP_ADD = 6'd4,
	OP_ADB = 6'd5,
	OP_MUL = 6'd6,
	OP_CSR = 6'd7,
	OP_AND = 6'd8,
	OP_OR = 6'd9,
	OP_XOR = 6'd10,
	OP_CR = 6'd11,
	OP_SUBF = 6'd12,
	OP_DIV = 6'd14,
	OP_MOV = 6'd15,
	OP_BCC0 = 6'd24,
	OP_BCC1 = 6'd25,
	OP_B0 = 6'd26,
	OP_B1 = 6'd27,
	OP_TRAP = 6'd28,
	OP_CHK = 6'd29,
	OP_PUSH = 6'd30,
	OP_POP = 6'd31,
	OP_LDB = 6'd32,
	OP_LDBZ = 6'd33,
	OP_LDW = 6'd34,
	OP_LDWZ = 6'd35,
	OP_LDT = 6'd36,
	OP_LDTZ = 6'd37,
	OP_LOAD = 6'd38,
	OP_LOADA = 6'd39,
	OP_STB = 6'd40,
	OP_STBI = 6'd41,
	OP_STW = 6'd42,
	OP_STWI = 6'd43,
	OP_STT = 6'd44,
	OP_STTI = 6'd45,
	OP_STORE = 6'd46,
	OP_STOREI = 6'd47,
	OP_FENCE = 6'd51,
	OP_STPTR = 6'd52,
	OP_BLOCK = 6'd53,
	OP_FLT = 6'd54,
	OP_AMO = 6'd59,
	OP_CMPSWAP = 6'd60,
	OP_PFX = 6'd61,
	OP_MOD = 6'd62,
	OP_NOP = 6'd63
} opcode_e;

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

parameter NOP_INSN = {26'd0,OP_NOP};

typedef struct packed
{
	logic [25:0] payload;
	logic [5:0] opcode;
} anyinst_t;

typedef struct packed
{
	logic one;
	logic [13:0] imm;
	logic Cr;
	logic [4:0] Rs1;
	logic [1:0] op2;
	logic [2:0] CRd;
	logic [5:0] opcode;
} cmpi_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] op2a;
	logic [6:0] resv;
	logic [4:0] Rs2;
	logic Cr;
	logic [4:0] Rs1;
	logic [1:0] op2;
	logic [2:0] CRd;
	logic [5:0] opcode;
} cmp_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] op2a;
	logic [7:0] resv;
	logic [2:0] cl;
	logic resv1;
	logic Cr;
	logic [4:0] Rs1;
	logic [1:0] op2;
	logic [2:0] CRd;
	logic [5:0] opcode;
} cmpcl_inst_t;

typedef struct packed
{
	logic one;
	logic [21:0] disp;
	logic [2:0] BRd;
	logic [4:0] opcode;
	logic d0;
} bl_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] op2a;
	logic [2:0] BRs;
	logic [8:0] lmt;
	logic resv1;
	logic [4:0] Rs2;
	logic [1:0] resv2;
	logic [2:0] BRd;
	logic [4:0] opcode;
	logic l0;
} blrlr_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] op2a;
	logic [2:0] BRs;
	logic [8:0] lmt;
	logic [3:0] resv4;
	logic [2:0] cl;
	logic resv2;
	logic [2:0] BRd;
	logic [4:0] opcode;
	logic l0;
} blrlcl_inst_t;

typedef struct packed
{
	logic one;
	logic [1:0] disphi;
	logic [2:0] BRs;
	logic [2:0] cnd;
	logic [5:0] CRs;
	logic [7:0] displo;
	logic [2:0] BRd;
	logic [4:0] opcode;
	logic d0;
} bccld_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] op2a;
	logic [2:0] BRs;
	logic [2:0] cnd;
	logic [5:0] CRs;
	logic resv1;
	logic [4:0] Rs2;
	logic [1:0] resv2;
	logic [2:0] BRd;
	logic [5:0] opcode;
} bcclr_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] op2a;
	logic [2:0] BRs;
	logic [2:0] cnd;
	logic [5:0] CRs;
	logic [3:0] resv4;
	logic [2:0] cl;
	logic resv1;
	logic [2:0] BRd;
	logic [5:0] opcode;
} bcclcl_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] maskhi;
	logic [2:0] zero3;
	logic [2:0] cnd;
	logic [5:0] CRs;
	logic [7:0] masklo;
	logic [2:0] seven;
	logic [4:0] opcode;
	logic m0;
} pcc_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] maskhi;
	logic [2:0] one3;
	logic [5:0] ipl;
	logic [10:0] masklo;
	logic [2:0] seven;
	logic [4:0] opcode;
	logic m0;
} atom_inst_t;

typedef struct packed
{
	logic one;
	logic [13:0] disp;
	logic cr;
	logic [4:0] Rs1;
	logic [4:0] Rsd;
	logic [5:0] opcode;
} lsd_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] zero1a;
	logic [4:0] disp;
	logic [1:0] sc;
	logic [4:0] Rs2;
	logic cr;
	logic [4:0] Rs1;
	logic [4:0] Rsd;
	logic [5:0] opcode;
} lsscn_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] lx;
	logic resv1a;
	logic [2:0] cl;
	logic resv1;
	logic [1:0] sc;
	logic [4:0] Rs2;
	logic cr;
	logic [4:0] Rs1;
	logic [4:0] Rsd;
	logic [5:0] opcode;
} lsscncl_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] zero2;
	logic [4:0] op5;
	logic [1:0] sz;
	logic [4:0] Rs2;
	logic cr;
	logic [4:0] Rs1;
	logic [4:0] Rd;
	logic [5:0] opcode;
} amo_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] zero2;
	logic [1:0] resv;
	logic [4:0] Rs3;
	logic [4:0] Rs2;
	logic cr;
	logic [4:0] Rs1;
	logic [4:0] Rd;
	logic [5:0] opcode;
} cas_inst_t;

typedef struct packed
{
	logic one;
	logic [13:0] imm;
	logic cr;
	logic [4:0] Rs1;
	logic [4:0] Rd;
	logic [5:0] opcode;
} alui_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] lx;
	logic [3:0] op4;
	logic [2:0] op3;
	logic [4:0] Rs2;
	logic cr;
	logic [4:0] Rs1;
	logic [4:0] Rd;
	logic [5:0] opcode;
} alu_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] lx;
	logic [3:0] op4;
	logic [2:0] op3;
	logic [3:0] cl;
	logic resv;
	logic cr;
	logic [4:0] Rs1;
	logic [4:0] Rd;
	logic [5:0] opcode;
} alucli_inst_t;

typedef struct packed
{
	logic one;
	logic [13:0] imm;
	logic cr;
	logic [1:0] resv;
	logic [2:0] BRs;
	logic [4:0] Rd;
	logic [5:0] opcode;
} adbi_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] lx;
	logic [3:0] op4;
	logic [2:0] resv1a;
	logic [4:0] Rs2;
	logic cr;
	logic [1:0] resv;
	logic [2:0] BRs;
	logic [4:0] Rd;
	logic [5:0] opcode;
} adb_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] lx;
	logic [3:0] op4;
	logic [3:0] resv1a;
	logic [2:0] cl;
	logic resv;
	logic cr;
	logic [1:0] resv1b;
	logic [2:0] BRs;
	logic [4:0] Rd;
	logic [5:0] opcode;
} adbcli_inst_t;

typedef struct packed
{
	logic one;
	logic [1:0] op2;
	logic [2:0] op3;
	logic h;
	logic [1:0] resv;
	logic [5:0] amt;
	logic cr;
	logic [4:0] Rs1;
	logic [4:0] Rd;
	logic [5:0] opcode;
} shi_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] op2;
	logic [2:0] op3;
	logic h;
	logic [2:0] resv;
	logic [4:0] Rs2;
	logic cr;
	logic [4:0] Rs1;
	logic [4:0] Rd;
	logic [5:0] opcode;
} sh_inst_t;

typedef struct packed
{
	logic one;
	logic [1:0] op2;
	logic [2:0] op3;
	logic [1:0] rm;
	logic resv;
	logic [5:0] amt;
	logic cr;
	logic [4:0] Rs1;
	logic [4:0] Rd;
	logic [5:0] opcode;
} srai_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] op2;
	logic [2:0] op3;
	logic [1:0] rm;
	logic [1:0] resv;
	logic [4:0] Rs2;
	logic cr;
	logic [4:0] Rs1;
	logic [4:0] Rd;
	logic [5:0] opcode;
} sra_inst_t;

typedef struct packed
{
	logic one;
	logic [1:0] op2;
	logic [2:0] op3;
	logic l;
	logic [1:0] resv;
	logic [5:0] amt;
	logic cr;
	logic [4:0] Rs1;
	logic [4:0] Rd;
	logic [5:0] opcode;
} roti_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] op2;
	logic [2:0] op3;
	logic l;
	logic [2:0] resv;
	logic [4:0] Rs2;
	logic cr;
	logic [4:0] Rs1;
	logic [4:0] Rd;
	logic [5:0] opcode;
} rot_inst_t;

typedef struct packed
{
	logic one;
	logic [1:0] op2;
	logic [5:0] me;
	logic [5:0] mb;
	logic cr;
	logic [4:0] Rs1;
	logic [4:0] Rd;
	logic [5:0] opcode;
} exti_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] op2;
	logic [2:0] op3;
	logic z;
	logic [2:0] resv;
	logic [4:0] Rs2;
	logic cr;
	logic [4:0] Rs1;
	logic [4:0] Rd;
	logic [5:0] opcode;
} ext_inst_t;

typedef struct packed
{
	logic one;
	logic [1:0] op2;
	logic [11:0] regno;
	logic cr;
	logic [4:0] Rs1;
	logic [4:0] Rd;
	logic [5:0] opcode;
} csr_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] zero1a;
	logic [1:0] op2;
	logic [4:0] resv;
	logic [4:0] Rs2;
	logic cr;
	logic [4:0] Rs1;
	logic [4:0] Rd;
	logic [5:0] opcode;
} csrr_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] one;
	logic [11:0] regno;
	logic cr;
	logic [3:0] cl;
	logic op;
	logic [4:0] Rd;
	logic [5:0] opcode;
} csrcl_inst_t;

typedef struct packed
{
	logic one;
	logic [1:0] zero;
	logic [11:0] op12;
	logic cr;
	logic [4:0] Rs1;
	logic [4:0] cnst;
	logic [5:0] opcode;
} brk_inst_t;

typedef struct packed
{
	logic zero;
	logic [3:0] op4;
	logic [4:0] Rs3;
	logic [4:0] Rs2;
	logic cr;
	logic [4:0] Rs1;
	logic [4:0] offs;
	logic [5:0] opcode;
} chk_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] op2;
	logic [1:0] grphi;
	logic [9:0] lsthi;
	logic cr;
	logic [1:0] grplo;
	logic [7:0] lstlo;
	logic [5:0] opcode;
} push_inst_t;

typedef struct packed
{
	logic one;
	logic [1:0] op2;
	logic [11:0] imm;
	logic cr;
	logic [5:0] resv;
	logic [3:0] ns4;
	logic [5:0] opcode;
} enter_inst_t;

typedef struct packed
{
	logic one;
	logic [1:0] lx;
	logic [2:0] op3;
	logic [4:0] resv;
	logic [1:0] Rs1h;
	logic [1:0] Rdh;
	logic cr;
	logic [4:0] Rs1;
	logic [4:0] Rd;
	logic [5:0] opcode;
} move_inst_t;

typedef struct packed
{
	logic one;
	logic [1:0] immhi;
	logic [2:0] op3;
	logic [8:0] immlo;
	logic cr;
	logic [4:0] Rs1;
	logic [4:0] Rd;
	logic [5:0] opcode;
} cmovi_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] lx;
	logic [2:0] op3;
	logic [3:0] resv;
	logic [4:0] Rs2;
	logic cr;
	logic [4:0] Rs1;
	logic [4:0] Rd;
	logic [5:0] opcode;
} cmov_inst_t;

typedef struct packed
{
	logic one;
	logic [1:0] immhi;
	logic [2:0] op3;
	logic [4:0] immlo;
	logic [1:0] Rs1h;
	logic [1:0] Rdh;
	logic cr;
	logic [4:0] Rs1;
	logic [4:0] Rd;
	logic [5:0] opcode;
} movx_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] sz;
	logic [2:0] op3a;
	logic [3:0] op4;
	logic [4:0] Rs2;
	logic cr;
	logic [4:0] Rs1;
	logic [4:0] Rd;
	logic [5:0] opcode;
} bmap_inst_t;

typedef struct packed
{
	logic one;
	logic [22:0] imm;
	logic [1:0] wh;
	logic [5:0] opcode;
} pfx_inst_t;

typedef struct packed
{
	logic one;
	logic [1:0] zero;
	logic [3:0] op4;
	logic [5:0] resv;
	logic i;
	logic [5:0] CRs1;
	logic [5:0] CRd;
	logic [5:0] opcode;
} cri_inst_t;

typedef struct packed
{
	logic zero;
	logic [1:0] zero1a;
	logic [3:0] op4;
	logic resv;
	logic [5:0] CRs2;
	logic [5:0] CRs1;
	logic [5:0] CRd;
	logic [5:0] opcode;
} cr_inst_t;

typedef union packed
{
	cmpi_inst_t cmpi;
	cmp_inst_t cmp;
	cmpcl_inst_t cmpcl;
	bl_inst_t bl;
	blrlr_inst_t blrlr;
	blrlcl_inst_t blrlcl;
	bccld_inst_t bccld;
	bccld_inst_t retd;
	bccld_inst_t mcb;
	bcclr_inst_t bcclr;
	bcclr_inst_t retr;
	bcclcl_inst_t bcclcl;
	bcclcl_inst_t retcl;
	pcc_inst_t pcc;
	atom_inst_t atom;
	lsd_inst_t lsd;
	lsscn_inst_t lsscn;
	lsscncl_inst_t lsscncl;
	amo_inst_t amo;
	cas_inst_t cas;
	alui_inst_t alui;
	alu_inst_t alu;
	alucli_inst_t alucli;
	alu_inst_t fpu;
	adbi_inst_t adbi;
	adb_inst_t adb;
	adbcli_inst_t adbcli;
	shi_inst_t shi;
	sh_inst_t sh;
	srai_inst_t srai;
	sra_inst_t sra;
	roti_inst_t roti;
	rot_inst_t rot;
	exti_inst_t exti;
	ext_inst_t ext;
	csr_inst_t csr;
	csrr_inst_t csrr;
	csrcl_inst_t csrcl;
	brk_inst_t brk;
	chk_inst_t chk;
	push_inst_t push;
	push_inst_t pop;
	enter_inst_t enter;
	enter_inst_t leave;
	move_inst_t move;
	cmovi_inst_t cmovi;
	cmov_inst_t cmov;
	movx_inst_t movx;
	bmap_inst_t bmap;
	pfx_inst_t pfx;
	cri_inst_t cri;
	cr_inst_t cr;
	anyinst_t any;
} instruction_t;

typedef struct packed {
	logic v;
	logic exc;
	logic [2:0] count;
	logic [2:0] num;
	logic [1:0] xRs2;
	logic [1:0] xRs1;
	logic [1:0] xRd;
	logic [3:0] xop4;
	instruction_t ins;
} micro_op_t;

typedef struct packed {
	cpu_types_pkg::pc_address_ex_t pc;
	cpu_types_pkg::mc_address_t mcip;
	logic [5:0] pred_btst;
	instruction_t ins;
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
	vect = 4'd10
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
	logic v;
	logic pfxa;
	logic pfxb;
	logic pfxc;
	logic pfxd;
	cpu_types_pkg::aregno_t Rci;		// carry input
	cpu_types_pkg::aregno_t Rs1;
	cpu_types_pkg::aregno_t Rs2;
	cpu_types_pkg::aregno_t Rs3;
	cpu_types_pkg::aregno_t Rd;
	cpu_types_pkg::aregno_t Rd2;
	cpu_types_pkg::aregno_t Rd3;
	cpu_types_pkg::aregno_t Rco;		// carry output
	logic Rs1z;
	logic Rs2z;
	logic Rs3z;
	logic Rdz;
	logic Rd2z;
	logic Rd3z;
	logic has_Rs2;
	logic has_imm;
	logic has_imma;
	logic has_immb;
	logic has_immc;
	cpu_types_pkg::value_t imma;
	cpu_types_pkg::value_t immb;
	cpu_types_pkg::value_t immc;		// for store immediate
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
	logic amo;
	logic load;
	logic loadz;
	logic store;
	logic bstore;
	logic cls;
	logic loada;
	logic erc;
	logic fence;
	logic mcb;					// micro-code branch
	brclass_t brclass;
	logic bcc;					// conditional branch
	logic cjb;					// call, jmp, or bra
	logic bl;						// branch and link to subroutine
	logic jsri;					// indirect subroutine call
	logic br;
	logic pbr;
	logic ret;
	logic brk;
	logic irq;
	logic eret;
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
	cpu_types_pkg::seqnum_t sn;
	logic agen;						// address generated through to physical address
	cpu_types_pkg::rob_ndx_t rndx;				// reference to related ROB entry
	logic vpa;						// virtual or physical address
	cpu_types_pkg::physical_address_t adr;
	operating_mode_t omode;	// operating mode
	logic v2p;						// 1=doing a virtual to physical address translation
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
	cpu_types_pkg::checkpt_ndx_t cndx;
	operating_mode_t om;	// operating mode
	logic ctag;						// capabilities tag
	logic datav;					// store data is valid
	logic [511:0] res;		// stores unaligned data as well (must be last field)
} lsq_entry_t;

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
	cause_code_t exc;					// non-zero indicate exception
	logic excv;								// 1=exception
	// The following fields are loaded at enqueue time, but otherwise do not change.
	logic bt;									// branch to be taken as predicted
	operating_mode_t om;			// operating mode
	reg [31:0] carry_mod;			// carry modifier remnant
	reg [11:0] atom_mask;			// interrupt masking by ATOM instruction
	cpu_types_pkg::pregno_t pRs1;							// physical registers (see decode bus for arch. regs)
	cpu_types_pkg::pregno_t pRs2;
	cpu_types_pkg::pregno_t pRs3;
	cpu_types_pkg::pregno_t pRd;						// current Rd value
	cpu_types_pkg::pregno_t nRd;						// new Rd
	logic pRs1v;
	logic pRs2v;
	logic pRs3v;
	logic pRdv;
	logic nRdv;
	cpu_types_pkg::pc_address_ex_t pc;			// PC of instruction
	cpu_types_pkg::mc_address_t mcip;				// Micro-code IP address
	cpu_types_pkg::pc_address_ex_t hwipc;		// PC of instruction
	cpu_types_pkg::mc_address_t hwi_mcip;		// Micro-code IP address
	cpu_types_pkg::aregno_t aRs1;
	cpu_types_pkg::aregno_t aRs2;
	cpu_types_pkg::aregno_t aRs3;
	cpu_types_pkg::aregno_t aRd;
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

typedef struct packed
{
	logic v;														// group header is valid
	cpu_types_pkg::seqnum_t sn;					// sequence number, decrements when instructions que
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
	pipeline_reg_t pr0;
	pipeline_reg_t pr1;
	pipeline_reg_t pr2;
	pipeline_reg_t pr3;
} pipeline_group_reg_t;

typedef struct packed {
	logic v;
	logic busy;
	logic ready;
	logic [3:0] funcunit;						// functional unit dispatched to
	cpu_types_pkg::rob_ndx_t rndx;
	cpu_types_pkg::checkpt_ndx_t cndx;
	instruction_t ins;
	// needed only for mem
	logic virt2phys;
	logic load;
	logic store;
	logic amo;
	// decodes only needed for branch
	logic bt;												
	brclass_t brclass;
	logic cjb;
	logic bl;
	// - - - - - - - - - - - - - - - - 
	memsz_t prc;
	logic [$bits(cpu_types_pkg::value_t)/8-1:0] copydst;
	logic aRdz;
	cpu_types_pkg::aregno_t aRd;
	cpu_types_pkg::pregno_t nRd;
	operating_mode_t om;						// needed for mem ops
	cpu_types_pkg::pc_address_t pc;
	cpu_types_pkg::value_t argA;
	cpu_types_pkg::value_t argB;
	cpu_types_pkg::value_t argC;
	cpu_types_pkg::value_t argD;
	cpu_types_pkg::value_t argI;
	logic tagA;
	logic tagB;
	logic tagC;
	logic tagD;
	logic argA_v;
	logic argB_v;
	logic argC_v;
	logic argD_v;
} reservation_station_entry_t;

typedef struct packed {
	// The following fields may change state while an instruction is processed.
	logic v;									// 1=entry is valid, in use
	cpu_types_pkg::seqnum_t sn;							// sequence number, decrements when instructions que
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
	cpu_types_pkg::mc_address_t mcbrtgt;			// micro-code branch target
	logic takb;								// 1=branch evaluated to taken
	cause_code_t exc;					// non-zero indicate exception
	logic excv;								// 1=exception
	cpu_types_pkg::value_t argC;	// for stores
`ifdef IS_SIM
	cpu_types_pkg::value_t argA;
	cpu_types_pkg::value_t argB;
	cpu_types_pkg::value_t argI;
	cpu_types_pkg::value_t argD;
	cpu_types_pkg::value_t res;
`endif
	logic updAv;
	logic updBv;
	logic updCv;
	cpu_types_pkg::value_t updA;
	cpu_types_pkg::value_t updB;
	cpu_types_pkg::value_t updC;
	cpu_types_pkg::pregno_t updAreg;
	cpu_types_pkg::pregno_t updBreg;
	cpu_types_pkg::pregno_t updCreg;
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
	logic argA_vp;						// 1=argument A valid pending
	logic argB_vp;
	logic argC_vp;
	logic argD_vp;
	logic argA_v;							// 1=argument A valid
	logic argB_v;
	logic argC_v;
	logic argD_v;
	logic rat_v;							// 1=checked with RAT for valid reg arg.
	cpu_types_pkg::value_t arg;							// argument value for CSR instruction
	// The following fields are loaded at enqueue time, but otherwise do not change.
	logic last;								// 1=last instruction in group (not used)
	cpu_types_pkg::rob_ndx_t group_len;			// length of instruction group (not used)
	logic bt;									// branch to be taken as predicted
	operating_mode_t om;			// operating mode
	decode_bus_t decbus;			// decoded instruction
	cpu_types_pkg::checkpt_ndx_t cndx;				// checkpoint index
	cpu_types_pkg::checkpt_ndx_t br_cndx;		// checkpoint index branch owns
	pipeline_reg_t op;			// original instruction
	cpu_types_pkg::seqnum_t grp;							// instruction group
} rob_entry_t;

// ============================================================================
// Support Functions
// ============================================================================

function fnHasExConst;
input instruction_t ins;
begin
	case(ins.any.opcode)
	OP_BRK,OP_SHIFT,OP_CSR,OP_CR,OP_CHK,
	OP_PUSH,OP_POP,	// ENTER,LEAVE,PUSH,POP
	OP_FENCE,OP_BLOCK,OP_FLT,
	OP_AMO:	// AMO
		fnHasExConst = 1'b0;
	default:	fnHasExConst = 1'b1;
	endcase
end
endfunction

function fnIsStimm;
input instruction_t ins;
begin
	case(ins.any.opcode)
	OP_STBI,OP_STWI,OP_STTI,OP_STOREI:
		fnIsStimm = 1'b0;
	default:
		fnIsStimm = 1'b1;
	endcase
end
endfunction

function fnIsBccCsr;
input instruction_t ins;
begin
	fnIsBccCsr = ins.any.opcode==OP_BCC0 || ins.any.opcode==OP_BCC1 || ins.any.opcode==OP_CSR;
end
endfunction


// Decodes the constant position from an instruction.
// Two positions are returned. The lower four bits are the base constant
// position, and the upper four bits are the location of a store immediate
// constant.

function [7:0] fnConstPos;
input instruction_t ins;
begin
	fnConstPos = 8'd0;
	if (fnHasExConst(ins))					// does instruction have an extendable constant?
	if (ins[31]!=1'b1)							// and is the constant extended on the cache line?
	if (ins[30:29]!=2'b00) begin		// and it is not a register spec
		if (fnIsBccCsr(ins))
			fnConstPos[3:0] = ins[15:12];
		else
			fnConstPos[3:0] = ins[21:18];
	end
	if (fnIsStimm(ins))
		fnConstPos[7:4] = ins[10:7];
end
endfunction

// Only 32-bit extended constants are supported.

function [3:0] fnConstSize;
input instruction_t ins;
begin
	fnConstSize = 4'd0;
	if (fnHasExConst(ins))					// does instruction have an extendable constant?
	if (ins[31]!=1'b1)							// and is the constant extended on the cache line?
		fnConstSize[1:0] = ins[30:29];
	if (fnIsStimm(ins))
		fnConstSize[3:2] = ins.any.opcode[2:1];	// store instructions are in size order
end
endfunction

// ATOM
function fnIsAtom;
input instruction_t ir;
begin
	fnIsAtom = ir.any.opcode[5:1]==5'd12 && ir[8:6]==3'd7 && ir[31:29]==3'd0 && ir[28:26]==3'd1;
end
endfunction

function fnIsCarry;
input instruction_t ir;
begin
	fnIsCarry = ir.any.opcode[5:1]==5'd12 && ir[8:6]==3'd7 && ir[31:29]==3'd0 && ir[28:26]==3'd2;
end
endfunction

function memsz_t fnMemsz;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_LDB,OP_LDBZ,OP_STB,OP_STBI:	fnMemsz = byt;
	OP_LDW,OP_LDWZ,OP_STW,OP_STWI:	fnMemsz = wyde;
	OP_LDT,OP_LDTZ,OP_STT,OP_STTI:	fnMemsz = tetra;
	OP_LOAD,OP_STORE,OP_STOREI:			fnMemsz = octa;
	default:
		fnMemsz = octa;
	endcase
end
endfunction

function fnIsBl;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_B0,OP_B1:
		fnIsBl = ir[31];	
	default:
		fnIsBl = 1'b0;
	endcase
end
endfunction

function fnIsBranch;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_BCC0,OP_BCC1:
		fnIsBranch = ir[8:6]!=3'd7;
	default:
		fnIsBranch = 1'b0;
	endcase
end
endfunction

function fnDecBsr;
input Stark_pkg::pipeline_reg_t mux;
begin
	fnDecBsr =
		mux.uop.ins[31]==1'b1 &&
		mux.uop.ins.any.opcode==5'd13 &&
		mux.uop.ins.bl.BRd!=3'd0 &&
		mux.uop.ins.bl.BRd!=3'd7;
end
endfunction

function fnDecBra;
input Stark_pkg::pipeline_reg_t mux;
begin
	fnDecBra =
		mux.uop.ins[31]==1'b1 &&
		mux.uop.ins.any.opcode==5'd13 &&
		mux.uop.ins.bl.BRd==3'd0;
end
endfunction

function fnDecJmp;
input Stark_pkg::pipeline_reg_t mux;
begin
	fnDecJmp =
		mux.uop.ins[31]==1'b0 && |mux.uop.ins[30:29] &&
		mux.uop.ins.any.opcode==5'd13 &&
		mux.uop.ins.blrlr.BRs==3'd0 &&
		mux.uop.ins.blrlr.BRd==3'd0;
end
endfunction

function fnDecJmpr;
input Stark_pkg::pipeline_reg_t mux;
begin
	fnDecJmpr =
		mux.uop.ins[31]==1'b0 && |mux.uop.ins[30:29] &&
		mux.uop.ins.any.opcode==5'd12 &&
		mux.uop.ins.bcclr.BRd==3'd0;
end
endfunction

function fnDecJsr;
input Stark_pkg::pipeline_reg_t mux;
begin
	fnDecJsr =
		mux.uop.ins[31]==1'b0 && |mux.uop.ins[30:29] &&
		mux.uop.ins.any.opcode==5'd13 &&
		mux.uop.ins.blrlr.BRs==3'd0 &&
		mux.uop.ins.blrlr.BRd!=3'd0 &&
		mux.uop.ins.blrlr.BRd!=3'd7;
end
endfunction

function fnDecJsrr;
input Stark_pkg::pipeline_reg_t mux;
begin
	fnDecJsrr =
		mux.uop.ins[31]==1'b0 && |mux.uop.ins[30:29] &&
		mux.uop.ins.any.opcode==5'd12 &&
		mux.uop.ins.bcclr.BRd!=3'd0 &&
		mux.uop.ins.bcclr.BRd!=3'd7;
end
endfunction

function fnDecBra2;
input Stark_pkg::pipeline_reg_t mux;
begin
	fnDecBra2 =
		mux.uop.ins[31]==1'b0 && |mux.uop.ins[30:29] &&
		mux.uop.ins.any.opcode==5'd13 &&
		mux.uop.ins[0]==1'b0 &&
		mux.uop.ins.blrlr.BRs==3'd7 &&
		mux.uop.ins.blrlr.BRd==3'd0;
end
endfunction

function fnDecBsr2;
input Stark_pkg::pipeline_reg_t mux;
begin
	fnDecBsr2 =
		mux.uop.ins[31]==1'b0 && |mux.uop.ins[30:29] &&
		mux.uop.ins.any.opcode==5'd13 &&
		mux.uop.ins[0]==1'b0 &&
		mux.uop.ins.blrlr.BRs==3'd7 &&
		mux.uop.ins.blrlr.BRd!=3'd0 &&
		mux.uop.ins.blrlr.BRd!=3'd7;
end
endfunction

function fnDecRet;
input Stark_pkg::pipeline_reg_t mux;
begin
	fnDecRet =
		mux.uop.ins[31]==1'b0 &&
		mux.uop.ins.any.opcode==5'd13 &&
		mux.uop.ins[0]==1'b1 &&
		mux.uop.ins.blrlr.BRs==3'd7 &&
		mux.uop.ins.blrlr.BRd!=3'd0 &&
		mux.uop.ins.blrlr.BRd!=3'd7;
end
endfunction

function [63:0] fnDecConst;
input Stark_pkg::instruction_t ins;
input [511:0] cline;
reg [3:0] cnstpos1;
reg [8:0] cnstpos;
reg [1:0] cnstsize;
reg [63:0] cnst1;
begin
	cnstsize = fnConstSize(ins);
	cnstpos1 = fnConstPos(ins);
	cnstpos = {cnstpos1,2'b0,3'b0};
	cnst1 = cline >> cnstpos1;
	case(cnstsize)
	2'd0:	fnDecConst = 64'd0;
	2'd1:	fnDecConst = {{32{cnst1[31]}},cnst1[31:0]};
	2'd2:	fnDecConst = cnst1;
	2'd3:	fnDecConst = cnst1;
	endcase
end
endfunction

function cpu_types_pkg::pc_address_ex_t fnDecDest;
input Stark_pkg::pipeline_reg_t pr;
input [511:0] cline;
reg jsr,jmp,bsr,bra,bsr2,bra2;
begin
	fnDecDest = pr.pc;
	jsr = fnDecJsr(pr.uop.ins);
	jmp = fnDecJmp(pr.uop.ins);
	bsr = fnDecBsr(pr.uop.ins);
	bra = fnDecBra(pr.uop.ins);
	bsr2 = fnDecBsr2(pr.uop.ins);
	bra2 = fnDecBra2(pr.uop.ins);
	case(1'b1)
	jsr:	fnDecDest.pc = fnDecConst(pr.uop.ins,cline);
	jmp:	fnDecDest.pc = fnDecConst(pr.uop.ins,cline);
	bsr: 	fnDecDest.pc = pr.pc.pc + {{39{pr.uop.ins.bl.disp[21]}},pr.uop.ins.bl.disp,pr.uop.ins.bl.d0};
	bra: 	fnDecDest.pc = pr.pc.pc + {{39{pr.uop.ins.bl.disp[21]}},pr.uop.ins.bl.disp,pr.uop.ins.bl.d0};
	bsr2:	fnDecDest.pc = pr.pc.pc + fnDecConst(pr.uop.ins,cline);
	bra2:	fnDecDest.pc = pr.pc.pc + fnDecConst(pr.uop.ins,cline);
	endcase
end
endfunction

function fnIsPredBranch;
input Stark_pkg::instruction_t ir;
begin
	case(ir.any.opcode)
	OP_BCC0,OP_BCC1:
		fnIsPredBranch = ir[8:6]==3'd7 && ir[31];
	default:
		fnIsPredBranch = 1'b0;
	endcase
end
endfunction

function fnIsBccR;
input instruction_t ir;
begin
	fnIsBccR = fnIsBranch(ir) && ir[39:36]==4'h7;
end
endfunction

function fnIsDBcc;
input instruction_t ir;
begin
	fnIsDBcc = fnIsBranch(ir) && ir[25:23]!=3'd2 && ir[25:23]!=3'd5;
end
endfunction

function fnIsEret;
input instruction_t ir;
begin
	fnIsEret = ir.any.opcode==OP_BRK &&  ir[28:18]==11'd1;	// eret or eret2
end
endfunction

function fnIsRet;
input instruction_t ir;
begin
	fnIsRet = (ir.any.opcode==OP_B0||ir.any.opcode==OP_B1) && 
		ir[31:29]==3'd1 && ir[28:26]==3'd1 && ir[8:6]==3'd0;	// eret or eret2
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
	OP_ADD,OP_CMP,OP_MUL,OP_DIV,OP_SUBF:
		fnImmb = ir.ins[31] || ir.ins[30:29] >= 2'd1;
//	OP_RTD:
//		fnImmb = 1'b1;
	OP_LOADA,
	OP_LDB,,OP_LDBZ,OP_LDW,OP_LDWZ,OP_LDT,OP_LDTZ,OP_LOAD:
		fnImmb = ir.ins[31] || ir.ins[30:29] >= 2'd1;
	OP_STB,OP_STW,OP_STT,OP_STORE,OP_STBI,OP_STWI,OP_STTI,OP_STOREI,OP_STPTR:
		fnImmb = ir.ins[31] || ir.ins[30:29] >= 2'd1;
	default:	fnImmb = 1'b0;
	endcase
end
endfunction

function fnImmc;
input ex_instruction_t ir;
begin
	fnImmc = 1'b0;
	case(ir.ins.any.opcode)
	OP_STBI,OP_STWI,OP_STTI,OP_STOREI:
		fnImmc = 1'b1;
	default:	fnImmc = 1'b0;
	endcase
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
	OP_CHK:	fnSourceRs1v = fnConstReg(ir.ins.chk.Rs1) || fnImma(ir);
//	OP_RTD:		fnSourceRs1v = fnConstReg(ir.ins.rtd.Ra.num) || fnImma(ir);
//	OP_JSR:		fnSourceRs1v = fnConstReg(ir.ins.jsr.Ra.num) || fnImma(ir);
	OP_ADD:		fnSourceRs1v = fnConstReg(ir.ins.alu.Rs1) || fnImma(ir);
	OP_SUBF:	fnSourceRs1v = fnConstReg(ir.ins.alu.Rs1) || fnImma(ir);
	OP_CMP:		fnSourceRs1v = fnConstReg(ir.ins.alu.Rs1) || fnImma(ir);
	OP_MUL:		fnSourceRs1v = fnConstReg(ir.ins.alu.Rs1) || fnImma(ir);
	OP_DIV:		fnSourceRs1v = fnConstReg(ir.ins.alu.Rs1) || fnImma(ir);
	OP_AND:		fnSourceRs1v = fnConstReg(ir.ins.alu.Rs1) || fnImma(ir);
	OP_OR:		fnSourceRs1v = fnConstReg(ir.ins.alu.Rs1) || fnImma(ir);
	OP_XOR:		fnSourceRs1v = fnConstReg(ir.ins.alu.Rs1) || fnImma(ir);
	OP_ADB:		fnSourceRs1v = ir.ins.adb.BRs == 3'd0 || ir.ins.adb.BRs == 3'd7;
	OP_SHIFT:	fnSourceRs1v = fnConstReg(ir.ins.sh.Rs1) || fnImma(ir);
	OP_MOV:		fnSourceRs1v = fnConstReg({ir.ins.move.Rs1h,ir.ins.move.Rs1}) || fnImma(ir);
	OP_BCC0,OP_BCC1:
		fnSourceRs1v = fnConstReg(ir.ins.bccld.BRs) || fnImma(ir);
	OP_LOADA,
	OP_LDB,,OP_LDBZ,OP_LDW,OP_LDWZ,OP_LDT,OP_LDTZ,OP_LOAD:
		fnSourceRs1v = fnConstReg(ir.ins.lsd.Rs1) || fnImma(ir);
	OP_STB,OP_STW,OP_STT,OP_STORE,OP_STBI,OP_STWI,OP_STTI,OP_STOREI,OP_STPTR:
		fnSourceRs1v = fnConstReg(ir.ins.lsd.Rs1) || fnImma(ir);
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
	OP_ADD:		fnSourceRs2v = fnConstReg(ir.ins.alu.Rs2) || fnImmb(ir);
	OP_SUBF:	fnSourceRs2v = fnConstReg(ir.ins.alu.Rs2) || fnImmb(ir);
	OP_CMP:	fnSourceRs2v = fnConstReg(ir.ins.alu.Rs2) || fnImmb(ir);
	OP_MUL:	fnSourceRs2v = fnConstReg(ir.ins.alu.Rs2) || fnImmb(ir);
	OP_DIV:	fnSourceRs2v = fnConstReg(ir.ins.alu.Rs2) || fnImmb(ir);
	OP_AND:	fnSourceRs2v = fnConstReg(ir.ins.alu.Rs2) || fnImmb(ir);
	OP_OR:		fnSourceRs2v = fnConstReg(ir.ins.alu.Rs2) || fnImmb(ir);
	OP_XOR:	fnSourceRs2v = fnConstReg(ir.ins.alu.Rs2) || fnImmb(ir);
	OP_SHIFT:	fnSourceRs2v = fnConstReg(ir.ins.alu.Rs2) || ir.ins[31];
	OP_BCC0,OP_BCC1:
		fnSourceRs2v = fnConstReg(ir.ins.bcclr.Rs2) || fnImmb(ir);
	OP_LOADA,
	OP_LDB,,OP_LDBZ,OP_LDW,OP_LDWZ,OP_LDT,OP_LDTZ,OP_LOAD:
		fnSourceRs2v = fnConstReg(ir.ins.lsscn.Rs2) || fnImmb(ir);
	OP_STB,OP_STW,OP_STT,OP_STORE,OP_STBI,OP_STWI,OP_STTI,OP_STOREI,OP_STPTR:
		fnSourceRs2v = fnConstReg(ir.ins.lsscn.Rs2) || fnImmb(ir);
	default:	fnSourceRs2v = 1'b1;
	endcase
end
endfunction

function fnSourceRs3v;
input ex_instruction_t ir;
begin
	case(ir.ins.any.opcode)
	OP_CHK:	fnSourceRs3v = fnConstReg(ir.ins.chk.Rs3);
//	OP_RTD:
//		fnSourceRs3v = 1'd0;
	default:
		fnSourceRs3v = 1'b1;
	endcase
end
endfunction

function fnSourceRdv;
input ex_instruction_t ir;
begin
	casez(ir.ins.any.opcode)
	OP_CHK:	fnSourceRdv = 1'b1;
//	OP_JSR:		fnSourceRdv = fnConstReg(ir.ins.jsr.Rt.num);
	OP_ADD:		fnSourceRdv = fnConstReg(ir.ins.alu.Rd);
	OP_SUBF:	fnSourceRdv = fnConstReg(ir.ins.alu.Rd);
	OP_CMP:		fnSourceRdv = fnConstReg(ir.ins.alu.Rd);
	OP_MUL:	fnSourceRdv = fnConstReg(ir.ins.alu.Rd);
	OP_DIV:	fnSourceRdv = fnConstReg(ir.ins.alu.Rd);
	OP_AND:	fnSourceRdv = fnConstReg(ir.ins.alu.Rd);
	OP_OR:		fnSourceRdv = fnConstReg(ir.ins.alu.Rd);
	OP_XOR:	fnSourceRdv = fnConstReg(ir.ins.alu.Rd);
	OP_ADB:		fnSourceRdv = fnConstReg(ir.ins.adb.Rd);
	OP_SHIFT:	fnSourceRdv = fnConstReg(ir.ins.sh.Rd);
	OP_MOV:		fnSourceRdv = fnConstReg({ir.ins.move.Rdh,ir.ins.move.Rd});
	OP_LOADA,
	OP_LDB,,OP_LDBZ,OP_LDW,OP_LDWZ,OP_LDT,OP_LDTZ,OP_LOAD:
		fnSourceRdv = fnConstReg(ir.ins.lsd.Rsd);
	OP_STB,OP_STW,OP_STT,OP_STORE,OP_STBI,OP_STWI,OP_STTI,OP_STOREI,OP_STPTR:
		fnSourceRdv = fnConstReg(ir.ins.lsscn.Rsd) || fnImmc(ir);
	OP_BCC0,OP_BCC1:
		fnSourceRdv = ir.ins.bccld.BRd==3'd0 || ir.ins.bccld.BRd==3'd7;
//	OP_RTD:	fnSourceRdv = 1'b0;
	default:
		fnSourceRdv = 1'b1;
	endcase
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
			if (a== 7'd45/* || (a >= 7'd50 && a <= 7'd55)*/) begin
				exc = 1'b1;
				o = 7'd0;
			end
			else
				o = a;
		end
	OM_SUPERVISOR:
		begin
			if (a >= 7'd50 && a <= 7'd63 || a >= 7'd0 && a <= 7'd7)
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
