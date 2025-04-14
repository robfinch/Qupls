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
parameter SIM = 1'b0;
//`define IS_SIM	1

// Comment out to remove the sigmoid approximate function
//`define SIGMOID	1

// Number of architectural registers there are in the core, including registers
// not visible in the programming model.
`define NREGS	96

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
parameter SUPPORT_POSTFIX = 1;

// The following allows the core to process flow control ops in any order
// to reduce the size of the core. Set to zero to restrict flow control ops
// to be processed in order. If processed out of order a branch may 
// speculate incorrectly leading to lower performance.
parameter SUPPORT_OOOFC = 1'b0;

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
parameter INSN_LEN = 8'd4;

// =============================================================================
// Resources
// =============================================================================

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

typedef struct packed
{
	logic [Stark_pkg::PREGS-1:0] avail;	// available registers at time of queue (for rollback)
//	cpu_types_pkg::pregno_t [AREGS-1:0] p2regmap;
	cpu_types_pkg::pregno_t [Stark_pkg::AREGS-1:0] pregmap;
	cpu_types_pkg::pregno_t [Stark_pkg::AREGS-1:0] regmap;
} checkpoint_t;

typedef struct packed
{
	logic resv1;
	logic so;				// summary overflow
	logic resv;
	logic le;
	logic lt;
	logic _nor;
	logic _nand;
	logic eq;
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
	logic swstk;				// software stack
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
	BTS_DISP = 3'd1,
	BTS_REG = 3'd2,
	BTS_BSR = 3'd3,
	BTS_JSR = 3'd4,
	BTS_CALL = 3'd5,
	BTS_RET = 3'd6,
	BTS_RTI = 3'd7
} bts_t;

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
	OP_BLOCK = 6'd53,
	OP_FLOAT = 6'd54,
	OP_AMO = 6'd59,
	OP_CMPSWAP = 6'd60,
	OP_PFX = 6'd61,
	OP_NOP = 6'd63
} opcode_e;

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
	logic [4:0] Rs1;
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
	logic [4:0] Rs1;
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
	logic [2:0] resv;
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
	logic [3:0] resv1a;
	logic [2:0] cl;
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
	logic [2:0] Br;
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
	logic [2:0] Br;
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
	logic [2:0] Br;
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
	logic [1:0] op2;
	logic [2:0] cl;
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
	bcclr_inst_t bcclr;
	bcclcl_inst_t bcclcl;
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

typedef enum logic [2:0] {
	BTS_NONE = 3'd0,
	BTS_DISP = 3'd1,
	BTS_REG = 3'd2,
	BTS_BSR = 3'd3,
	BTS_JSR = 3'd4,
	BTS_CALL = 3'd5,
	BTS_RET = 3'd6,
	BTS_RTI = 3'd7
} bts_e;

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
	checkpt_ndx_t cndx;
	operating_mode_t om;	// operating mode
	logic ctag;						// capabilities tag
	logic datav;					// store data is valid
	logic [511:0] res;		// stores unaligned data as well (must be last field)
} lsq_entry_t;

typedef struct packed
{
	logic v;
	logic pfxa;
	logic pfxb;
	logic pfxc;
	logic pfxd;
	cpu_types_pkg::aregno_t Rs1;
	cpu_types_pkg::aregno_t Rs2;
	cpu_types_pkg::aregno_t Rs3;
	cpu_types_pkg::aregno_t Rd;
	logic has_imma;
	logic has_immb;
	logic has_immc;
	logic [31:0] imma;
	logic [31:0] immb;
	logic [31:0] immc;		// for store immediate
	logic csr;				// CSR instruction
	logic nop;				// NOP semantics
	logic fc;					// flow control op
	logic backbr;			// backwards target branch
	bts_e bts;				// branch target source
	logic macro;			// true if macro instruction
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
	logic bitwise;		// true if a bitwise operator (and, or, eor)
	logic multicycle;
	logic mem;
	logic mem0;				// true if instruction must use only port #0
	logic v2p;				// virtual to physical instruction
	logic load;
	logic loadz;
	logic store;
	logic bstore;
	logic cls;
	logic lda;
	logic erc;
	logic fence;
	logic mcb;					// micro-code branch
	logic bcc;					// conditional branch
	logic cjb;					// call, jmp, or bra
	logic bl;						// branch and link to subroutine
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
	logic cpytgt;
	logic qfext;				// true if QFEXT modifier
} decode_bus_t;

typedef struct packed
{
	logic v;
	logic rstp;								// indicate physical register reset required
	cpu_types_pkg::pc_address_t brtgt;
	logic takb;								// 1=branch evaluated to taken
	logic ssm;								// 1=single step mode active
	logic hwi;								// hardware interrupt occured during fetch
	logic [5:0] hwi_level;		// the level of the hardware interrupt
	logic [5:0] irq_mask;			// irq mask from sr.ipl or atom
	logic [2:0] hwi_swstk;		// software stack
	cause_code_t exc;					// non-zero indicate exception
	logic excv;								// 1=exception
	// The following fields are loaded at enqueue time, but otherwise do not change.
	logic bt;									// branch to be taken as predicted
	operating_mode_t om;			// operating mode
	cpu_types_pkg::pregno_t pRs1;							// physical registers (see decode bus for arch. regs)
	cpu_types_pkg::pregno_t pRs2;
	cpu_types_pkg::pregno_t pRs3;
	cpu_types_pkg::pregno_t pRd;							// current Rt value
	cpu_types_pkg::pregno_t nRd;							// new Rt
	checkpt_ndx_t cndx;											// checkpoint index
	cpu_types_pkg::pc_address_ex_t pc;			// PC of instruction
	cpu_types_pkg::mc_address_t mcip;				// Micro-code IP address
	cpu_types_pkg::pc_address_ex_t hwipc;		// PC of instruction
	cpu_types_pkg::mc_address_t hwi_mcip;		// Micro-code IP address
	cpu_types_pkg::aregno_t aRs1;
	cpu_types_pkg::aregno_t aRs2;
	cpu_types_pkg::aregno_t aRs3;
	cpu_types_pkg::aregno_t aRd;
	instruction_t ins;
	decode_bus_t db;
} pipeline_reg_t;

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
	logic updAv;
	logic updBv;
	logic updCv;
	cpu_types_pkg::value_t updA;
	cpu_types_pkg::value_t updB;
	cpu_types_pkg::value_t updC;
	cpu_types_pkg::pregno_t updAreg;
	cpu_types_pkg::pregno_t updBreg;
	cpu_types_pkg::pregno_t updCreg;
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

// ============================================================================
// Support Functions
// ============================================================================

function fnHasExConst;
input instruction_t ins;
begin
	case(ins.any.opcode)
	OP_BRK,OP_SHIFT,OP_CSR,OP_CR,OP_CHK,
	OP_PUSH,OP_POP,	// ENTER,LEAVE,PUSH,POP
	OP_FENCE,OP_BLOCK,OP_FLOAT,
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
			fnConstPos[3:0] = {1'b1,ins[14:12]};
		else
			fnConstPos[3:0] = {1'b1,ins[20:18]};
	end
	if (fnIsStimm(ins))
		fnConstPos[7:4] = {1'b1,ins[8:6]};
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
		fnConstSize[3:2] = 2'b01;
end
endfunction

// ATOM or ACARRY
function fnIsAtom;
input instruction_t ir;
begin
	fnIsAtom = ir.any.opcode[5:1]==5'd12 && ir[8:6]==3'd7 && ir[31:29]==3'd0 && (ir[28:26]==3'd1 || ir[28:16]==3'd3);
end
endfunction


endpackage
