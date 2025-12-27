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

// Comment out to remove the sigmoid approximate function
//`define SIGMOID	1

// 4 is the only setting (under construction)
parameter MWIDTH = 4;

// Number of threads supported. (Under construction < 5)
parameter THREADS = 2;

// Number of streams of execution. Alternate branch paths create streams.
parameter XSTREAMS = 8;

// Number of levels of branches that can be speculated across.
parameter BRANCH_LEVELS = 8;

// Number of physical registers supporting the architectural ones and used in
// register renaming. There must be significantly more physical registers than
// architectural ones, or performance will suffer due to stalls.
// Must be a multiple of four. If it is not 512 or 256 then the renamer logic will
// need to be modified.
parameter PREGS = 512;

parameter IP_REG = 8'd31;

// Number of operands (including destination) a micro-op can have.
parameter NOPER = 5;

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
parameter SERIALIZE = 0;

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

// 1=out of order dispatch, maybe better performance, but huge size
// 0=in-order pipeline unit, much smaller but may stall
parameter DISPATCH_STRATEGY = 0;

// Register lookup strategy used by the reservation stations for missing data.
// 0=use register file write port history
// 1=use extra register file read ports
parameter RL_STRATEGY = 1;

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

// =============================================================================
// Instruction Modifier Support
// =============================================================================
// The following parameter enables support for predicated logic in the core.
parameter SUPPORT_PRED = 1'b1;
parameter SUPPORT_ATOM = 1'b1;
parameter SUPPORT_CARRY = 1'b0;

// The PRED_SHADOW parameter controls the maximum number of instructions
// following the predicate that are affected by it. Increasing the shadow
// increases the amount of logic generated for the core in a more than
// linear fashion. The maximum is seven instructions as that is all that
// can be encoded in the instruction. The minimum is one.
parameter PRED_SHADOW = 4;

// =============================================================================
// =============================================================================
// Allowing unaligned memory access increases the size of the core.
parameter SUPPORT_UNALIGNED_MEMORY = 1'b1;
parameter SUPPORT_BUS_TO = 1'b1;

// This parameter enables support for quad (128-bit) precision operations.
parameter SUPPORT_QUAD_PRECISION = 1'b0;

// Supporting load bypassing may improve performance, but will also increase the
// size of the core and make it more vulnerable to security attacks.
// Loads are bypassed only when there is an exact match to a store.
parameter SUPPORT_LOAD_BYPASSING = 1;

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
// should be a multiple of the machine width (4).
parameter ROB_ENTRIES = 16;

// Number of entries in dispatch buffer. Must be a multiple of machine width (4).
parameter DBF_ENTRIES = 4 * MWIDTH;

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

parameter pL1CacheLines = `L1CacheLines;
parameter pL1LineSize = `L1CacheLineSize;
parameter pL1ICacheLines = `L1CacheLines;
// The following arrived at as 512+32 bits for word at end of cache line, plus
// 40 bits for a possible constant postfix
parameter pL1ICacheLineSize = `L1ICacheLineSize;
parameter pL1Imsb = $clog2(`L1ICacheLines-1)-1+6;
parameter pL1ICacheWays = `L1ICacheWays;
parameter pL1DCacheWays = `L1DCacheWays;

parameter INSN_LEN = 8'd6;

const cpu_types_pkg::pc_address_t RSTPC	= 32'hFFFFFD80;
const cpu_types_pkg::address_t RSTSP = 32'hFFFF9000;


// =============================================================================
// Instruction Support
// =============================================================================

// This parameter adds support for capabilities instructions. Increases the
// size of the core. An FPU must also be enabled.
parameter SUPPORT_CAPABILITIES = 1'b0;

// Support for vector operations.
parameter SUPPORT_VECTOR = 1'b1;

parameter SUPPORT_IMUL = 1;
parameter SUPPORT_IDIV = 1;
parameter SUPPORT_TRIG = 0;
parameter SUPPORT_FDP = 0;
parameter SUPPORT_FLOAT = 1;

// =============================================================================
// Resources
// =============================================================================

// Number of architectural registers including registers to support vector
// operations. Each vector register needs four registers.
parameter NREGS = 40*THREADS+(SUPPORT_VECTOR ? 128 : 0);
parameter AREGS = 40*THREADS+(SUPPORT_VECTOR ? 128 : 0);
parameter REGFILE_LATENCY = 2;


// Number of register read ports. More ports allows more simultaneous reads
// (obvious) and may increase performance. However, most instructions will
// have two or fewer arguments, and allowing for four instructions at once
// means an average of eight ports per cycle.
parameter NREG_RPORTS = MWIDTH*5;

// Number of register write ports. Mort ports allows more simultabeous writes
// and may increase performance. The default is set to the machine width.
// Note: not all instruction write the register file so it may be possible
// to use fewer write ports without losing too much performance.
parameter NREG_WPORTS = MWIDTH;

// Number of data ports should be 1 or 2. 2 ports will allow two simulataneous
// reads, but still only a single write.
parameter NDATA_PORTS = 1;
// Number of AGENs should be 1 or 2. There is little value in having more agens
// than there are data ports.
parameter NAGEN = 1;

parameter LSQ_ENTRIES = 8;
parameter LSQ2 = NDATA_PORTS > 1;		// Queue two LSQ entries at once?

// Increasing the number of SAUs will increase performance. There must be at
// least one SAU.
// Note that adding an FPU may also increase integer performance if PERFORMANCE
// is set to 1.
parameter NSAU = 2;			// 1 or 2
parameter NFPU = 0;			// 0 or 1
parameter NFMA = 0;			// 0, 1 or 2
parameter NDFPU = 0;		// 0 or 1
parameter NLSQ_PORTS = 1;

parameter RAS_DEPTH	= 4;

parameter SUPPORT_RSB = 0;

// Depth of internal stack for exceptionb processing.
parameter ISTACK_DEPTH = 16;

parameter NRSE_SAU0 = 1;
parameter NRSE_SAU = 1;
parameter NRSE_IMUL = 1;
parameter NRSE_IDIV = 1;
parameter NRSE_FMA = 1;
parameter NRSE_FPU = 1;
parameter NRSE_DFLT = 1;
parameter NRSE_FCU = 1;
parameter NRSE_AGEN = 1;

