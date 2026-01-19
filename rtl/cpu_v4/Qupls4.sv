// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2026  Robert Finch, Waterloo
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
// 95400 LUTs / 41300 FFs / 119 BRAMs (2 ALU, 1 FPU, 16 checkpoints 32 ROB)
// 91k LUTs / 43.5k FFs / 90 BRAMs (14 vec registers - 1 ALU, 8 checkpoints)
// 103k LUTs / 44.5k FFs / 92 BRAMs / 64 DSPs (14 vec regs - 2 ALU, 8 checkpts)
// 117k LUTs / k FFs / 97 BRAMs / 64 DSPs (24 vec regs - 2 ALU, 8 checkpts)
// 107k LUTs / 41.5k FFs / 132 BRAMS / 72 DSP (14 vec regs - 1 ALU, 8 chkpts)
// 108k LUTs / 49k FFs / 90 BRAMS (2 ALU, 1 FPU, 16 checkpoints 32 ROB)
// ============================================================================

import const_pkg::*;
import wishbone_pkg::*;
import cpu_types_pkg::*;
import cache_pkg::*;
import mmu_pkg::*;
import Qupls4_pkg::*;

`undef ZERO
`define ZERO		64'd0

//
// define PANIC types
//
`define PANIC_NONE		4'd0
`define PANIC_FETCHBUFBEQ	4'd1
`define PANIC_INVALIDISLOT	4'd2
`define PANIC_MEMORYRACE	4'd3
`define PANIC_IDENTICALDRAMS	4'd4
`define PANIC_OVERRUN		4'd5
`define PANIC_HALTINSTRUCTION	4'd6
`define PANIC_INVALIDMEMOP	4'd7
`define PANIC_INVALIDFBSTATE 4'd8
`define PANIC_INVALIDIQSTATE 4'd9 
`define PANIC_BRANCHBACK 4'd10
`define PANIC_BADTARGETID	4'd12
`define PANIC_COMMIT 4'd13

module Qupls4(coreno_i, rst_i, clk_i, clk2x_i, clk3x_i, clk5x_i, ipl, irq, irq_ack,
	irq_i, ivect_i, swstk_i, om_i,
	wb_req, wb_resp, snoop_adr, snoop_v, snoop_tid);
parameter CORENO = 6'd1;
parameter CHANNEL = 6'd1;
parameter MWIDTH = Qupls4_pkg::MWIDTH;
parameter ISTACK_DEPTH = 16;
parameter DISPATCH_WIDTH = 6;
parameter RL_STRATEGY = Qupls4_pkg::RL_STRATEGY;
localparam NREG_RPORTS = Qupls4_pkg::NREG_RPORTS;
parameter NREG_WPORTS = Qupls4_pkg::NREG_WPORTS;
localparam RS_NREG_RPORTS = Qupls4_pkg::NREG_RPORTS;
parameter MICROOPS_PER_INSTR = 32;
parameter MAX_MICROOPS = 12;
parameter XSTREAMS = Qupls4_pkg::XSTREAMS;
input [63:0] coreno_i;
input rst_i;
input clk_i;
input clk2x_i;
input clk3x_i;
input clk5x_i;
output reg [5:0] ipl;
input irq;
output reg irq_ack;
input [5:0] irq_i;
input [96:0] ivect_i;
input [2:0] swstk_i;
input [2:0] om_i;
output wb_cmd_request256_t wb_req;
input wb_cmd_response256_t wb_resp;
input cpu_types_pkg::address_t snoop_adr;
input snoop_v;
input wb_tranid_t snoop_tid;

Qupls4_pkg::irq_info_packet_t irq_in = {irq_i,om_i,swstk_i,ivect_i};

wire ren_rst_busy;
reg irst;
always_comb irst = rst_i;//|ren_rst_busy;
wb_cmd_request256_t ftatm_req;
wb_cmd_response256_t ftatm_resp;
wb_cmd_request256_t ftaim_req;
wb_cmd_response256_t ftaim_resp;
wb_cmd_request256_t [1:0] ftadm_req;
wb_cmd_response256_t [1:0] ftadm_resp;
wb_cmd_response256_t fta_resp1;
wb_cmd_response256_t ptable_resp;
wb_cmd_request256_t [1:0] cap_tag_req;
wb_cmd_response256_t [1:0] cap_tag_resp;
wire [1:0] cap_tag_hit;

real IPC,PIPC;
integer nn,mm,n2,n3,n4,m4,n5,n6,n8,n9,n10,n11,n12,n13,n14,n15,n17;
integer n16r, n16c, n12r, n12c, n14r, n14c, n17r, n17c, n18r, n18c;
integer n19,n20,n21,n22,n23,n24,n25,n26,n27,n28,n29,i,n30,n31,n32,n33;
integer n34,n35,n36,n37,n38,n39,n40,n41,n42,n43,n44,n45,n46,n47,n48;
integer n49,n50,n51,n52,n53,n54,n55,n56,n57;
integer jj,kk;

genvar g,h,gvg;
reg [127:0] message;
reg [9*8-1:0] stompstr, no_stompstr;

// Clocks
wire clk;
wire clk2x, clk3x;
assign clk3x = clk3x_i;
wire clk5x = clk5x_i;
assign clk = clk_i;				// convenience
assign clk2x = clk2x_i;

reg [4:0] ph4;
reg [5:0] rstcnt;
reg [3:0] panic;
reg int_commit;		// IRQ committed
reg next_step;		// do next step for single stepping
reg ssm_flag;
// hirq squashes the pc increment if there's an irq.
// Normally atom_count is zero.
reg hirq;
pc_address_ex_t ret_pc;
pc_address_ex_t misspc;
wire [$bits(pc_address_t)-1:6] missblock;
reg [2:0] missgrp;
wire [2:0] missino;
reg restore_en = 1'b1;

wire [15:0] q_rst;
wire [15:0] q_trigger;
wire [15:0] q_rd;
wire [15:0] q_wr;
wire [15:0] q_addr;
wire [63:0] q_rd_data [15:0];
wire [63:0] q_wr_data;

Qupls4_pkg::ex_instruction_t missir;

reg [39:0] I;		// Committed instructions
reg [39:0] IV;	// Valid committed instructions

Qupls4_pkg::reg_bitmask_t livetarget;
Qupls4_pkg::reg_bitmask_t [Qupls4_pkg::ROB_ENTRIES-1:0] rob_livetarget;
Qupls4_pkg::reg_bitmask_t [Qupls4_pkg::ROB_ENTRIES-1:0] rob_latestID;
Qupls4_pkg::reg_bitmask_t [Qupls4_pkg::ROB_ENTRIES-1:0] rob_cumulative;
Qupls4_pkg::reg_bitmask_t [Qupls4_pkg::ROB_ENTRIES-1:0] rob_out;
wire [Qupls4_pkg::PREGS-1:0] unavail_list;			// list of registers made unavailable via copy-targets

wire inject_cl = 1'b0;

rob_ndx_t agen0_rndx, agen1_rndx;
reg [7:0] scan;
rob_ndx_t nonNop;		// ROB index of the next non-NOP instruction.

//op_src_t sau0_argA_src;
//op_src_t sau0_argB_src;
//op_src_t sau0_argC_src;

// prn looks up the register value and causes the value from the register file
// to be output within the same clock cycle.
// prn comes from the renamer. (prn = physical register number)
// rf_reg is an alias.
pregno_t [NREG_RPORTS-1:0] prn;		// ports from the rename stage / reservation station request

pregno_t [63:0] pRs = {10*128{1'b0}};
reg [63:0] pRsv;
pregno_t [3:0] bRs [0:15];// = {8*52{1'b0}};
wire [3:0] bRsv [0:15];
pregno_t [3:0] bRs1 [0:3];
pregno_t [3:0] bRs2 [0:3];
reg [3:0] bRsv1 [0:3];
reg [3:0] bRsv2 [0:3];

value_t rfo_sau0_argA;
value_t rfo_sau0_argB;
value_t rfo_sau0_argC;
value_t rfo_sau0_argD;
value_t rfo_sau0_argM;
value_t rfo_sau1_argA;
value_t rfo_sau1_argB;
value_t rfo_sau1_argC;
value_t rfo_sau1_argD;
value_t rfo_sau1_argM;
value_t rfo_fpu0_argA;
value_t rfo_fpu0_argB;
value_t rfo_fpu0_argC;
value_t rfo_fpu0_argM;
value_t rfo_fpu1_argA;
value_t rfo_fpu1_argB;
value_t rfo_fpu1_argC;
value_t rfo_fpu1_argD;
value_t rfo_fpu1_argM;
value_t rfo_fcu_argA;
value_t rfo_fcu_argB;
value_t rfo_agen0_argA;
value_t rfo_agen1_argA;
value_t rfo_agen0_argM;
value_t rfo_agen0_argB;
value_t rfo_agen0_argC;
value_t rfo_agen1_argB;
value_t rfo_agen1_argC;
value_t rfo_agen1_argM;
Qupls4_pkg::flags_t rfo_sau0_argA_flags;
Qupls4_pkg::flags_t rfo_sau0_argB_flags;
Qupls4_pkg::flags_t rfo_sau1_argA_flags;
Qupls4_pkg::flags_t rfo_sau1_argB_flags;
Qupls4_pkg::flags_t rfo_fpu0_argA_flags;
Qupls4_pkg::flags_t rfo_fpu0_argB_flags;
Qupls4_pkg::flags_t rfo_agen0_argA_flags;
Qupls4_pkg::flags_t rfo_agen0_argB_flags;
Qupls4_pkg::flags_t rfo_agen0_argC_flags;
Qupls4_pkg::flags_t rfo_agen1_argA_flags;
Qupls4_pkg::flags_t rfo_agen1_argB_flags;
Qupls4_pkg::flags_t rfo_store_argC_flags;
value_t store_argC;
value_t load_res;
value_t ma0,ma1;				// memory address
wire store_argC_v;

pregno_t sau0_argA_reg;
pregno_t sau0_argB_reg;
pregno_t sau0_argC_reg;
pregno_t sau0_argD_reg;
pregno_t sau0_argT_reg;
pregno_t sau0_argM_reg;

pregno_t sau1_argA_reg;
pregno_t sau1_argB_reg;
pregno_t sau1_argC_reg;
pregno_t sau1_argD_reg;
pregno_t sau1_argT_reg;
pregno_t sau1_argM_reg;

pregno_t fpu0_argA_reg;
pregno_t fpu0_argB_reg;
pregno_t fpu0_argC_reg;
pregno_t fpu0_argD_reg;
pregno_t fpu0_argT_reg;
pregno_t fpu0_argM_reg;

pregno_t fpu1_argA_reg;
pregno_t fpu1_argB_reg;
pregno_t fpu1_argC_reg;
pregno_t fpu1_argM_reg;

pregno_t fcu_argA_reg;
pregno_t fcu_argB_reg;

pregno_t agen0_argA_reg;
pregno_t agen0_argB_reg;
pregno_t agen0_argC_reg;
pregno_t agen0_argM_reg;
Qupls4_pkg::flags_t agen0_argC_flags;

pregno_t agen1_argA_reg;
pregno_t agen1_argB_reg;
pregno_t agen1_argC_reg;
pregno_t agen1_argM_reg;

reg store_aRegv;

Qupls4_pkg::lsq_ndx_t store_argC_id;
Qupls4_pkg::lsq_ndx_t store_argC_id1;

pregno_t [NREG_RPORTS-1:0] rf_reg;
pregno_t [NREG_RPORTS-1:0] rf_rego;
reg [NREG_RPORTS-1:0] rf_regv;
value_t [NREG_RPORTS-1:0] rfo;
Qupls4_pkg::flags_t [NREG_RPORTS-1:0] rfo_flags;

rob_ndx_t mc_orid;
pc_address_ex_t mc_adr;
pc_address_ex_t tgtpc;
(* keep *)
Qupls4_pkg::rob_entry_t [Qupls4_pkg::ROB_ENTRIES-1:0] rob;
(* keep *)
Qupls4_pkg::pipeline_group_hdr_t [Qupls4_pkg::ROB_ENTRIES/MWIDTH-1:0] pgh;
Qupls4_pkg::beb_entry_t beb_buf;
reg [1:0] beb_status [0:63];

Qupls4_pkg::ex_instruction_t [3:0] macro_ins_bus;
reg macro_queued;

reg [1:0] robentry_islot [0:Qupls4_pkg::ROB_ENTRIES-1];
wire [1:0] next_robentry_islot [0:Qupls4_pkg::ROB_ENTRIES-1];
Qupls4_pkg::rob_bitmask_t robentry_stomp;
Qupls4_pkg::rob_bitmask_t robentry_cpydst;
pc_stream_t kept_stream;
wire stomp_fet, stomp_ext, stomp_mot, stomp_x4;
wire stomp_dec, stomp_ren, stomp_que, stomp_quem;
Qupls4_pkg::rob_bitmask_t robentry_issue;
Qupls4_pkg::rob_bitmask_t robentry_fpu_issue;
Qupls4_pkg::rob_bitmask_t robentry_fcu_issue;
Qupls4_pkg::rob_bitmask_t robentry_agen_issue;
Qupls4_pkg::lsq_entry_t [1:0] lsq [0:Qupls4_pkg::LSQ_ENTRIES-1];
Qupls4_pkg::lsq_ndx_t lq_tail, lq_head;
integer lsq_cmd_ndx;
Qupls4_pkg::lsq_cmd_t [11:0] lsq_cmd;

wire nq;
reg [3:0] wnq;

reg brtgtv;
pc_address_ex_t pc0_f;
pc_address_ex_t brtgt;
reg pc_in_sync;
reg advance_pipeline, advance_pipeline_seg2;
reg advance_fetch;
reg advance_extract;
reg advance_decode;
reg advance_rename;
reg advance_enqueue;
reg do_bsr_h;
reg set_pending_ipl;
reg [5:0] next_pending_ipl;
wire rat_stallq, ren_stallq, stall_dsp;

rob_ndx_t [7:0] head;
rob_ndx_t [11:0] tails, reg_tails;
rob_ndx_t stail;
Qupls4_pkg::reg_bitmask_t reg_bitmask;
Qupls4_pkg::reg_bitmask_t Ra_bitmask;
Qupls4_pkg::reg_bitmask_t Rt_bitmask;
reg ls_bmf;		// load or store bitmask flag
Qupls4_pkg::ex_instruction_t hold_ir;
reg hold_ins;
reg pack_regs;
reg [2:0] scale_regs;
rob_ndx_t [MWIDTH-1:0] grplen;
reg [MWIDTH-1:0] last;
rob_ndx_t sync_ndx;
reg sync_ndxv;
rob_ndx_t fc_ndx;
reg fc_ndxv;

Qupls4_pkg::pipeline_reg_t pr_fet0,pr_fet1,pr_fet2,pr_fet3;
Qupls4_pkg::pipeline_reg_t pr_ext0,pr_ext1,pr_ext2,pr_ext3;
Qupls4_pkg::pipeline_reg_t pr_dec0,pr_dec1,pr_dec2,pr_dec3;
Qupls4_pkg::pipeline_reg_t pr_ren0,pr_ren1,pr_ren2,pr_ren3;
Qupls4_pkg::pipeline_reg_t pr_que0,pr_que1,pr_que2,pr_que3;

always_comb tails[1] = (tails[0] + 1) % Qupls4_pkg::ROB_ENTRIES;
always_comb tails[2] = (tails[0] + 2) % Qupls4_pkg::ROB_ENTRIES;
always_comb tails[3] = (tails[0] + 3) % Qupls4_pkg::ROB_ENTRIES;
always_comb tails[4] = (tails[0] + 4) % Qupls4_pkg::ROB_ENTRIES;
always_comb tails[5] = (tails[0] + 5) % Qupls4_pkg::ROB_ENTRIES;
always_comb tails[6] = (tails[0] + 6) % Qupls4_pkg::ROB_ENTRIES;
always_comb tails[7] = (tails[0] + 7) % Qupls4_pkg::ROB_ENTRIES;
always_comb tails[8] = (tails[0] + 8) % Qupls4_pkg::ROB_ENTRIES;
always_comb tails[9] = (tails[0] + 9) % Qupls4_pkg::ROB_ENTRIES;
always_comb tails[10] = (tails[0] + 10) % Qupls4_pkg::ROB_ENTRIES;
always_comb tails[11] = (tails[0] + 11) % Qupls4_pkg::ROB_ENTRIES;
always_comb head[1] = (head[0] + 1) % Qupls4_pkg::ROB_ENTRIES;
always_comb head[2] = (head[0] + 2) % Qupls4_pkg::ROB_ENTRIES;
always_comb head[3] = (head[0] + 3) % Qupls4_pkg::ROB_ENTRIES;
always_comb head[4] = (head[0] + 4) % Qupls4_pkg::ROB_ENTRIES;
always_comb head[5] = (head[0] + 5) % Qupls4_pkg::ROB_ENTRIES;
always_comb head[6] = (head[0] + 6) % Qupls4_pkg::ROB_ENTRIES;
always_comb head[7] = (head[0] + 7) % Qupls4_pkg::ROB_ENTRIES;

Qupls4_pkg::ex_instruction_t [7:0] ex_ins;

Qupls4_pkg::decode_bus_t db0_r, db1_r, db2_r, db3_r;				// Regfetch/rename stage inputs
Qupls4_pkg::pipeline_reg_t ins4_d, ins5_d, ins6_d, ins7_d, ins8_d;
Qupls4_pkg::pipeline_reg_t ins0_que, ins1_que, ins2_que, ins3_que;
Qupls4_pkg::pipeline_group_reg_t pg_ext, pg_mot, pg_dec, pg_ren, pg_dsp, pg_reg, pg_que;

reg backout;
wire bo_wr;
aregno_t bo_areg;
pregno_t bo_preg;
pregno_t bo_nreg;

reg [3:0] predino;
rob_ndx_t predrndx;
reg [1:0] pred_tf [0:XSTREAMS-1][0:31];	// predicate was true (1) or false (2), unassigned (0)
reg [31:0] pred_alloc_map;
wire [5:0] pred_no [0:3];
reg [63:0] pred_buf [0:XSTREAMS-1];			// holds the predicate value
reg [XSTREAMS-1:0] pred_done;						// tracks if predicate is done on stream
reg [7:0] pred_ins_done [0:XSTREAMS-1];	// tracks if predicated instruction is done
always_comb
	foreach (pred_tf[n56])
		for (n57 = 0; n57 < 32; n57 = n57 + 1)
			pred_tf[n56][n57] = pred_buf[n56] >> {n57[4:0],1'b0};

reg [3:0] regx0;
reg [3:0] regx1;
reg [3:0] regx2;
reg [3:0] regx3;
wire [3:0] mc_regx0;
wire [3:0] mc_regx1;
wire [3:0] mc_regx2;
wire [3:0] mc_regx3;
wire [15:0] rs_busy;
Qupls4_pkg::reservation_station_entry_t [DISPATCH_WIDTH-1:0] rse;

// ALU done and idle are almost the same, but idle is sticky and set
// if the ALU is not busy, whereas done pulses at the end of an ALU
// operation.
reg sau0_idle;
reg sau0_idle1;
wire sau0_issue;
wire sau0_idle_false = FALSE;
wire sau0_full;
always_comb
	if (sau0_idle_false)
		sau0_idle = FALSE;
	else
		sau0_idle = sau0_idle1;
reg sau0_done;
wire sau0_sc_done;		// single-cyle op done
wire sau0_sc_done2;		// pipeline delayed version of above
reg sau0_stomp;
reg sau0_available;
reg sau0_dataready;
Qupls4_pkg::ex_instruction_t sau0_instr;
wire sau0_div;
wire sau0_capA, sau0_capB, sau0_capC;
value_t sau0_argA;
value_t sau0_argB;
value_t sau0_argBI;
value_t sau0_argC;
value_t sau0_argT;
value_t sau0_argI;
value_t sau0_argD;
pregno_t sau0_Rt;
aregno_t sau0_aRdA, sau0_aRdB, sau0_aRdC;
pregno_t sau0_RdA;
pregno_t sau0_RtB;
pregno_t sau0_RtC;
Qupls4_pkg::operating_mode_t sau0_om;
Qupls4_pkg::flags_t sau0_argA_flags;
Qupls4_pkg::flags_t sau0_argB_flags;
reg sau0_aRdv;
checkpt_ndx_t sau0_cp;
reg sau0_bank;
value_t sau0_cmpo;
pc_address_ex_t sau0_pc;
value_t sau0_resA;
value_t sau0_resB;
value_t sau0_resC;
rob_ndx_t sau0_id;
reg sau0_idv;
wire [63:0] sau0_exc;
reg sau0_out;
wire sau0_ld;
reg sau0_ldd;
wire sau0_pred;
wire sau0_predz;
wire sau0_cpytgt;
wire [7:0] sau0_cptgt;
Qupls4_pkg::memsz_t sau0_prc;
Qupls4_pkg::flags_t sau0_flags;
wire sau0_args_valid;
Qupls4_pkg::reservation_station_entry_t sau0_rse, sau0_rse2;

reg sau1_idle;
reg sau1_idle1;
wire sau1_full;
wire sau1_idle_false = FALSE;
always_comb
	if (sau1_idle_false)
		sau1_idle = FALSE;
	else
		sau1_idle = sau1_idle1;
reg sau1_done;
reg sau1_sc_done1;
wire sau1_sc_done2;		// pipeline delayed version of above
wire sau1_sc_done;		// single-cyle op done
always_ff @(posedge clk) sau1_sc_done1 <= sau1_sc_done;
reg sau1_stomp;
reg sau1_available;
reg sau1_dataready;
Qupls4_pkg::ex_instruction_t sau1_instr;
wire sau1_div;
wire sau1_capA, sau1_capB, sau1_capC;
value_t sau1_argA;
value_t sau1_argB;
value_t sau1_argBI;
value_t sau1_argC;
value_t sau1_argD;
value_t sau1_argT;
value_t sau1_argI;
pregno_t sau1_Rt;
aregno_t sau1_aRdA;
aregno_t sau1_aRdB;
aregno_t sau1_aRdC;
pregno_t sau1_RdA;
pregno_t sau1_RtB;
pregno_t sau1_RtC;
Qupls4_pkg::operating_mode_t sau1_om;
reg sau1_aRdv;
checkpt_ndx_t sau1_cp;
reg sau1_bank;
value_t sau1_cmpo;
pc_address_ex_t sau1_pc;
value_t sau1_resA;
value_t sau1_resB;
value_t sau1_resC;
rob_ndx_t sau1_id;
reg sau1_idv;
wire [63:0] sau1_exc;
reg sau1_out;
wire mul1_done;
value_t div1_q,div1_r;
wire div1_done,div1_dbz;
wire sau1_ld;
reg sau1_ldd;
wire sau1_pred;
wire sau1_predz;
wire sau1_cpytgt;
wire [7:0] sau1_cptgt;
Qupls4_pkg::memsz_t sau1_prc;
Qupls4_pkg::flags_t sau1_flags;
wire sau1_args_valid;
Qupls4_pkg::reservation_station_entry_t sau1_rse, sau1_rse2;

reg imul0_idle;
reg imul0_idle1;
wire imul0_full;
wire imul0_idle_false;
always_comb
	if (imul0_idle_false)
		imul0_idle = FALSE;
	else
		imul0_idle = imul0_idle1;
wire imul0_sc_done;		// single-cyle op done
wire imul0_sc_done2;		// pipeline delayed version of above
reg imul0_stomp;
reg imul0_available = 1'b1;
reg imul0_dataready;
Qupls4_pkg::ex_instruction_t imul0_instr;
wire imul0_div;
wire imul0_capA, imul0_capB, imul0_capC;
pregno_t imul0_Rt;
aregno_t imul0_aRdA, imul0_aRdB, imul0_aRdC;
pregno_t imul0_RdA;
pregno_t imul0_RtB;
pregno_t imul0_RtC;
Qupls4_pkg::operating_mode_t imul0_om;
Qupls4_pkg::flags_t imul0_argA_flags;
Qupls4_pkg::flags_t imul0_argB_flags;
reg imul0_aRdv;
checkpt_ndx_t imul0_cp;
reg [2:0] imul0_cs;
reg imul0_bank;
value_t imul0_res;
rob_ndx_t imul0_id;
reg imul0_idv;
wire [63:0] imul0_exc;
reg imul0_out;
wire imul0_ld;
reg imul0_ldd;
wire imul0_pred;
wire imul0_predz;
wire imul0_cpytgt;
wire [7:0] imul0_cptgt;
Qupls4_pkg::memsz_t imul0_prc;
Qupls4_pkg::flags_t imul0_flags;
wire imul0_args_valid;
wire [8:0] imul0_we;
Qupls4_pkg::reservation_station_entry_t imul0_rse,imul0_rse2;
Qupls4_pkg::reservation_station_entry_t idiv0_rse,idiv0_rse2;

wire idiv0_full;
wire idiv0_ld;
wire idiv0_pred;
wire idiv0_predz;
wire [7:0] idiv0_cptgt;
wire [8:0] idiv0_we;
value_t idiv0_res;
wire idiv0_done;

reg fpu0_idle;
wire fpu0_full;
wire fpu0_iq_prog_full;
wire fpu0_done;
wire fpu0_sc_done;		// single-cycle done
wire fpu0_sc_done2;		// pipeline delayed version of above
reg fpu0_done1;
reg fpu0_stomp = 1'b0;
reg fpu0_available = 1'b1;
Qupls4_pkg::ex_instruction_t fpu0_instr;
reg [2:0] fpu0_rmd;
Qupls4_pkg::operating_mode_t fpu0_om;
value_t fpu0_argA;
value_t fpu0_argB;
value_t fpu0_argC;
value_t fpu0_argD;
value_t fpu0_argT;
value_t fpu0_argP;
value_t fpu0_argI;	// only used by BEQ
value_t fpu0_argM;
reg fpu0_argA_tag;
reg fpu0_argB_tag;
pregno_t fpu0_Rt;
aregno_t fpu0_aRdA;
aregno_t fpu0_aRdB;
aregno_t fpu0_aRdC;
pregno_t fpu0_RdA;
pregno_t fpu0_RdB;
pregno_t fpu0_RdC;
reg fpu0_aRdv;
pregno_t fpu0_Rt1;
aregno_t fpu0_aRd1;
reg fpu0_aRdv1;
checkpt_ndx_t fpu0_cp;
reg [2:0] fpu0_cs;
reg fpu0_bank;
pc_address_ex_t fpu0_pc;
value_t fpu0_resA, fpu0_resH;
value_t fpu0_resB;
value_t fpu0_resC;
double_value_t qdfpu0_res;
rob_ndx_t fpu0_id;
Qupls4_pkg::cause_code_t fpu0_exc;
reg fpu0_out;
wire fpu_done1;
reg fpu0_idv;
reg fpu0_qfext;
Qupls4_pkg::flags_t fpu0_flags;
reg [15:0] fpu0_cptgt;
wire fpu0_predz;
wire fpu0_args_valid;
Qupls4_pkg::reservation_station_entry_t fma0_rse,fma0_rse2;
Qupls4_pkg::reservation_station_entry_t fma1_rse,fma1_rse2;
Qupls4_pkg::reservation_station_entry_t fpu0_rse,fpu0_rse2;
Qupls4_pkg::reservation_station_entry_t fpu1_rse,fpu1_rse2;

reg fma0_available = 1'b1;
wire fma0_done;
wire fma0_full;
reg [8:0] fma0_we;
value_t fma0_res;
reg fma1_available = 1'b1;
wire fma1_done;
wire fma1_full;
value_t fma1_res;
reg [8:0] fma1_we;

reg fpu1_idle;
wire fpu1_full;
wire fpu1_done;
wire fpu1_sc_done;
reg fpu1_done1;
reg fpu1_stomp;
reg fpu1_available;
reg fpu1_dataready;
Qupls4_pkg::ex_instruction_t fpu1_instr;
reg [2:0] fpu1_rmd;
value_t fpu1_argA;
value_t fpu1_argB;
value_t fpu1_argC;
value_t fpu1_argD;
value_t fpu1_argT;
value_t fpu1_argP;
value_t fpu1_argI;	// only used by BEQ
value_t fpu1_argM;
Qupls4_pkg::flags_t fpu1_argA_flags;
Qupls4_pkg::flags_t fpu1_argB_flags;
pregno_t fpu1_Rt, fpu1_Rt1;
aregno_t fpu1_aRdA, fpu1_aRdB, fpu1_aRdC;
pregno_t fpu1_RdA, fpu1_RdB, fpu1_RdC;
reg fpu1_aRdv, fpu1_aRdv1;
reg [2:0] fpu1_cs;
reg fpu1_bank;
pc_address_ex_t fpu1_pc;
value_t fpu1_resA;
value_t fpu1_resB;
value_t fpu1_resC;
rob_ndx_t fpu1_id;
Qupls4_pkg::cause_code_t fpu1_exc = Qupls4_pkg::FLT_NONE;
wire        fpu1_v;
reg fpu1_idv;
wire fpu1_qfext;
reg [15:0] fpu1_cptgt;
wire fpu1_args_valid;

wire dfpu0_full;
Qupls4_pkg::reservation_station_entry_t dfpu0_rse;

reg fcu_idle;
wire fcu_full;
reg fcu_available;
Qupls4_pkg::pipeline_reg_t fcu_instr;
Qupls4_pkg::pipeline_reg_t fcu_missir;
wire fcu_bt;
wire fcu_cjb;
reg fcu_bl;
//Qupls4_pkg::bts_t fcu_bts;
Qupls4_pkg::brclass_t fcu_brclass;
value_t fcu_argA;
value_t fcu_argB;
value_t fcu_argBr;
value_t fcu_argI;
wire fcu_aRtzA,fcu_aRtzB;
reg fcu_done;
pc_address_ex_t fcu_pc;
reg fcu_wrA,fcu_wrB;
reg fcu_idv;
Qupls4_pkg::cause_code_t fcu_exc;
reg fcu_state1, fcu_branch_resolved, fcu_v3, fcu_v4, fcu_v5, fcu_v6;
wire fcu_branchmiss;
pc_address_ex_t fcu_misspc, fcu_misspc1;
mc_address_t fcu_miss_mcip, fcu_miss_mcip1;
reg [2:0] fcu_missgrp;
reg [2:0] fcu_missino;
reg takb;
rob_ndx_t fcu_rndx;
reg fcu_new;						// new FCU operation is taking place
reg fcu_found_destination;
Qupls4_pkg::rob_bitmask_t fcu_skip_list;
wire fcu_args_valid;
rob_ndx_t fcu_m1, fcu_dst;
Qupls4_pkg::reservation_station_entry_t fcu_rse,fcu_rse2,fcu_rser;
cpu_types_pkg::value_t fcu_res;

wire tlb0_v, tlb1_v;

wire agen0_full;
reg agen0_done = 1'b1;
Qupls4_pkg::ex_instruction_t agen0_op;
wire agen0_virt2phys;
reg agen0_load_store;
reg agen0_amo;
reg agen0_vlsndx;
rob_ndx_t agen0_id;
Qupls4_pkg::operating_mode_t agen0_om;
wire agen0_we;
value_t agen0_argA;
value_t agen0_argB;
value_t agen0_argC;
value_t agen0_argD;
value_t agen0_argC_v;
value_t agen0_argI;
value_t agen0_argM;
pc_address_t agen0_pc;
aregno_t agen0_aRa;
aregno_t agen0_aRb;
aregno_t agen0_aRc;
aregno_t agen0_aRt;
pregno_t agen0_Rc;
pregno_t agen0_Rt;
pregno_t agen0_pRc;
checkpt_ndx_t agen0_cp;
Qupls4_pkg::cause_code_t agen0_exc;
wire agen0_excv;
reg agen0_idv;
wire agen0_ldip;
wire agen0_args_valid;
Qupls4_pkg::ex_instruction_t agen0_instr;
Qupls4_pkg::reservation_station_entry_t agen0_rse,agen0_rse2;

reg agen1_done = 1'b1;
wire agen1_full;
Qupls4_pkg::ex_instruction_t agen1_op;
wire agen1_virt2phys;
reg agen1_load_store;
reg agen1_amo;
reg agen1_vlsndx;
rob_ndx_t agen1_id;
Qupls4_pkg::operating_mode_t agen1_om;
wire agen1_we;
value_t agen1_argA;
value_t agen1_argB;
value_t agen1_argI;
value_t agen1_argM;
pc_address_t agen1_pc;
aregno_t agen1_aRa;
aregno_t agen1_aRb;
aregno_t agen1_aRt;
pregno_t agen1_Ra;
pregno_t agen1_Rb;
pregno_t agen1_Rt;
checkpt_ndx_t agen1_cp;
Qupls4_pkg::cause_code_t agen1_exc;
wire agen1_excv;
reg agen1_idv;
wire agen1_ldip;
wire agen1_args_valid;
Qupls4_pkg::ex_instruction_t agen1_instr;
Qupls4_pkg::reservation_station_entry_t agen1_rse,agen1_rse2;

rob_ndx_t [3:0] regv_rndx;

reg lsq0_idle = 1'b1;
reg lsq1_idle = 1'b1;

address_t tlb0_res, tlb1_res;

pc_address_t icdp;
rob_ndx_t excid;
pc_address_ex_t excmisspc;
reg [4:0] excmissgrp;
reg excmiss;
Qupls4_pkg::ex_instruction_t excir;
reg excret;
pc_address_ex_t exc_ret_pc;
wire do_ret, do_call;
pc_address_ex_t bsr_tgt;
mc_address_t exc_ret_mcip;
Qupls4_pkg::micro_op_t exc_ret_mcir;
reg dc_get;

wire dram_avail;
Qupls4_pkg::dram_state_t dram0;	// state of the DRAM request
Qupls4_pkg::dram_state_t dram1;	// state of the DRAM request

reg [255:0] storeflags_buf;
reg [255:0] loadflags_buf;

Qupls4_pkg::dram_work_t dram0_work, dram1_work;
Qupls4_pkg::dram_oper_t dram0_oper, dram1_oper;

reg  [4:0] dram_id0;
reg  [4:0] dram_id1;
reg dram0_ack;
wire dram0_done;
reg dram0_ctag;
value_t dram0_argD;
reg dram0_ldip;
reg dram0_stomp;

reg dram1_ack;
wire dram1_done;
reg dram1_ctag;
value_t dram1_argD;
reg dram1_stomp;

reg [2:0] dramN [0:Qupls4_pkg::NDATA_PORTS-1];
reg [511:0] dramN_data [0:Qupls4_pkg::NDATA_PORTS-1];
reg [63:0] dramN_sel [0:Qupls4_pkg::NDATA_PORTS-1];
address_t dramN_addr [0:Qupls4_pkg::NDATA_PORTS-1];
address_t dramN_vaddr [0:Qupls4_pkg::NDATA_PORTS-1];
address_t dramN_paddr [0:Qupls4_pkg::NDATA_PORTS-1];
reg [Qupls4_pkg::NDATA_PORTS-1:0] dramN_load;
reg [Qupls4_pkg::NDATA_PORTS-1:0] dramN_vload;
reg [Qupls4_pkg::NDATA_PORTS-1:0] dramN_vload_ndx;
reg [Qupls4_pkg::NDATA_PORTS-1:0] dramN_loadz;
reg [Qupls4_pkg::NDATA_PORTS-1:0] dramN_cload;
reg [Qupls4_pkg::NDATA_PORTS-1:0] dramN_cload_tags;
reg [Qupls4_pkg::NDATA_PORTS-1:0] dramN_store;
reg [Qupls4_pkg::NDATA_PORTS-1:0] dramN_vstore;
reg [Qupls4_pkg::NDATA_PORTS-1:0] dramN_vstore_ndx;
reg [Qupls4_pkg::NDATA_PORTS-1:0] dramN_cstore;
reg [Qupls4_pkg::NDATA_PORTS-1:0] dramN_stptr;
reg [Qupls4_pkg::NDATA_PORTS-1:0] dramN_ack;
reg [Qupls4_pkg::NDATA_PORTS-1:0] dramN_erc;
wb_tranid_t dramN_tid [0:Qupls4_pkg::NDATA_PORTS-1];
Qupls4_pkg::memsz_t dramN_memsz;
reg [Qupls4_pkg::NDATA_PORTS-1:0] dramN_ctago;
wire [Qupls4_pkg::NDATA_PORTS-1:0] dramN_ctagi;
wire [63:0] dramN_tagsi [0:Qupls4_pkg::NDATA_PORTS-1];
rob_ndx_t [Qupls4_pkg::NDATA_PORTS-1:0] dramN_id;

wire [2:0] cmtcnt;
pc_address_ex_t commit_pc0, commit_pc1, commit_pc2, commit_pc3;
pc_address_ex_t commit_brtgt0;
pc_address_ex_t commit_brtgt1;
pc_address_ex_t commit_brtgt2;
pc_address_ex_t commit_brtgt3;
reg commit_br0;
reg commit_br1;
reg commit_br2;
reg commit_br3;
reg commit_ret0;
reg commit_ret1;
reg commit_ret2;
reg commit_ret3;
reg commit_jmp0;
reg commit_jmp1;
reg commit_jmp2;
reg commit_jmp3;
reg commit_call0;
reg commit_call1;
reg commit_call2;
reg commit_call3;
reg commit_takb0;
reg commit_takb1;
reg commit_takb2;
reg commit_takb3;
reg [2:0] commit_grp0;
reg [2:0] commit_grp1;
reg [2:0] commit_grp2;
reg [2:0] commit_grp3;
rob_ndx_t commit0_id;
rob_ndx_t commit1_id;
rob_ndx_t commit2_id;
rob_ndx_t commit3_id;
reg commit0_idv;
reg commit1_idv;
reg commit2_idv;
reg commit3_idv;

// CSRs
reg [63:0] tick;
reg [63:0] canary;
reg [39:0] ren_stalls, rat_stalls;
reg [39:0] cpytgts;
reg [39:0] marked_insn_count;
reg [39:0] stomped_insn;
Qupls4_pkg::cause_code_t [3:0] cause;
Qupls4_pkg::status_reg_t [ISTACK_DEPTH-1:0] sr_stack;
Qupls4_pkg::status_reg_t sr;
Qupls4_pkg::fp_status_reg_t fpcsr;
wire [2:0] swstk = sr.swstk;
wire paging_en = sr.page_en;
wire pebble_en = sr.pebble_en;
pc_address_t [ISTACK_DEPTH-1:0] pc_stack;
reg [5:0] pending_ipl;				// pending interrupt level.
wire [5:0] im = sr.ipl;
reg [7:0] thread_probability [0:7];
reg [63:0] asid_reg;
asid_t [3:0] asid;
assign asid[0] = asid_reg[15:0];
assign asid[1] = asid_reg[31:16];
assign asid[2] = asid_reg[47:32];
assign asid[3] = asid_reg[63:48];

always_comb
	ipl = sr.ipl;
reg [5:0] regset = 6'd0;
reg [63:0] vgm;									// vector global mask
value_t vrm [0:3];						// vector restart mask
value_t vex [0:3];						// vector exception
reg [1:0] vn;
asid_t ip_asid;
Qupls4_pkg::rob_bitmask_t err_mask;
reg ERC = 1'b0;
reg [39:0] icache_cnt;
reg [39:0] iact_cnt;
wire ihito,ihit,ic_dhit;
wire alt_ihit;
wire pe_bsdone;
reg [4:0] vl;
// 16 vectors for 5 operating modes (debug has its own set))
pc_address_t [4:0] kernel_vectors;
pc_address_t [4:0] syscall_vectors;

reg [31:0] carry_mod, csr_carry_mod, exc_ret_carry_mod, icarry_mod;
wire [6:0] carry_reg = 7'd92|carry_mod[25:24];

reg flush_pipeline;
wire copro_stall;
reg copro_stall1;
reg cp_stall;
Qupls4_pkg::pipeline_reg_t nopi;
reg [5:0] sync_no;
reg [5:0] fc_no;

always_ff @(posedge clk)
	fcu_branch_resolved = fcu_rse.v;

// Define a NOP instruction.
always_comb
begin
	nopi = {$bits(Qupls4_pkg::pipeline_reg_t){1'b0}};
	nopi.uop = {41'd0,Qupls4_pkg::OP_NOP};
	nopi.uop.lead = 1'd1;
	nopi.decbus.Rdv = 1'b0;
	nopi.decbus.nop = 1'b1;
	nopi.decbus.sau = 1'b1;
end


initial begin: Init
	integer i,j;

	foreach (rob[i]) begin
  	rob[i].v = 5'd0;
	end

//	dram2 = 0;

	//
	// set up panic messages
	message[ `PANIC_NONE ]			= "NONE            ";
	message[ `PANIC_FETCHBUFBEQ ]		= "FETCHBUFBEQ     ";
	message[ `PANIC_INVALIDISLOT ]		= "INVALIDISLOT    ";
	message[ `PANIC_IDENTICALDRAMS ]	= "IDENTICALDRAMS  ";
	message[ `PANIC_OVERRUN ]		= "OVERRUN         ";
	message[ `PANIC_HALTINSTRUCTION ]	= "HALTINSTRUCTION ";
	message[ `PANIC_INVALIDMEMOP ]		= "INVALIDMEMOP    ";
	message[ `PANIC_INVALIDFBSTATE ]	= "INVALIDFBSTATE  ";
	message[ `PANIC_INVALIDIQSTATE ]	= "INVALIDIQSTATE  ";
	message[ `PANIC_BRANCHBACK ]		= "BRANCHBACK      ";
	message[ `PANIC_MEMORYRACE ]		= "MEMORYRACE      ";

end

generate begin : gRf_reg
	if (RL_STRATEGY==1) begin
		always_comb
			rf_reg = prn;
	end
end
endgenerate

//
// FETCH
//

pc_address_ex_t pc, pc0, pc1, pc2, pc3, pc4, pc5, pc6, pc7, pc8;
reg [5:0] off0, off1, off2, off3, off4, off5, off6, off7;
pc_address_ex_t pc0_fet, pc1_fet, pc2_fet, pc3_fet, pc4_fet;
pc_address_ex_t next_pc;
mc_address_t mcip0_f;
mc_address_t mcip0_ext, mcip1_ext,mcip2_ext,mcip3_ext;
mc_address_t mcip0_ren, mcip1_ren,mcip2_ren,mcip3_ren;
mc_address_t mcip0_que, mcip1_que,mcip2_que,mcip3_que;
reg [2:0] grp_d, grp_q, grp_r;
wire [3:0] ntakb;
wire ptakb;
reg invce = 1'b0;
reg dc_invline = 1'b0;
reg dc_invall = 1'b0;
reg ic_invline = 1'b0;
reg ic_invall = 1'b0;
ICacheLine ic_clinel,ic_clineh;
ICacheLine ic_line_o;
ICacheLine ic_dline;

wire wr_ic;
wire ic_valid, ic_dvalid;
address_t ic_miss_adr;
asid_t ic_miss_asid;
wire [1:0] ic_wway;

wire [1023:0] ic_line;
reg insnq0,insnq1,insnq2,insnq3;
reg [MWIDTH-1:0] qd, cqd;
reg [MWIDTH-1:0] qd_x,qd_d,qd_r,qd_q;
reg [MWIDTH-1:0] next_cqd;
wire pe_allqd;
reg fetch_new;
reg fetch_new_block, fetch_new_block_x;
mmu_pkg::tlb_entry_t tlb_pc_entry;
pc_address_t pc_tlb_res;
wire pc_tlb_v;

wire [MWIDTH-1:0] pt_dec;	// predict taken branches
reg [MWIDTH-1:0] pt_q, pt_r;
reg regs;
reg [3:0] takb_pc;
reg [3:0] takb_f;
reg [3:0] takb_fet;

reg branchmiss, branchmiss_next;
reg branchmissd;
rob_ndx_t missid;
reg missid_v;

cpu_types_pkg::address_t agen0_res, agen1_res;
wire tlb_miss0, tlb_miss1;
wire tlb_missack;
tlb_entry_t tlb_entry1, tlb_entry;
wire tlb0_load, tlb0_store;
wire tlb1_load, tlb1_store;
reg stall_load, stall_store;
reg stall_tlb0 =1'd0, stall_tlb1=1'd0;

seqnum_t groupno;
wire ns_stall;
wire [Qupls4_pkg::PREGS-1:0] ns_avail;

// ----------------------------------------------------------------------------
// Config validations
// ----------------------------------------------------------------------------
always_comb
begin
	$display("Qupls4 Config");
	$display("---------------");
	$display("Number of ALUs: %d", Qupls4_pkg::NSAU);
	$display("Number of FPUs: %d", Qupls4_pkg::NFPU);
	$display("Number of data ports: %d", Qupls4_pkg::NDATA_PORTS);
	if (Qupls4_pkg::SUPPORT_RENAMER) begin
`ifdef SUPPORT_RAT
		$display("Qupls4: RAT available.");
`else
		$display("Qupls4: Error: RAT must be present if registers are renamed.");
		$finish;
`endif
	end
	if (Qupls4_pkg::NCHECK > 32) begin
		$display("Qupls4: Error: more than 32 checkpoints configured.");
		$finish;
	end
	if (Qupls4_pkg::NCHECK < 3) begin
		$display("Qupls4: Error: not enough checkpoints configured.");	
		$finish;
	end
	if (Qupls4_pkg::PREGS > 1024) begin
		$display("Qupls4: Error: too many physical registers configured.");
		$finish;
	end
	if (Qupls4_pkg::ROB_ENTRIES < 12) begin
		$display("Qupls4: Error: ROB has too few entries.");
		$finish;
	end
	if (Qupls4_pkg::THREADS < 1) begin
		$display("Qupls4: Error: Must be at least one thread.");
		$finish;
	end
	if (Qupls4_pkg::THREADS > 8) begin
		$display("Qupls4: Error: Too many threads configured.");
		$finish;
	end
	if (Qupls4_pkg::ROB_ENTRIES > 63) begin
		$display("Qupls4: Warning: may need to alter code to support number of ROB entries.");
	end
	if (Qupls4_pkg::SUPPORT_PRED) begin
		if (Qupls4_pkg::PRED_SHADOW < 1 || Qupls4_pkg::PRED_SHADOW > 7) begin
			$display("Qupls4: Error: predicate shadow must be between 1 and 7 inclusive.");
			$finish;
		end
	end
end

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

wire pe_clk;
edge_det uclked (.rst(irst), .clk(clk5x), .ce(1'b1), .i(clk), .pe(pe_clk), .ne(), .ee());

always_ff @(posedge clk5x)
if (irst)
	ph4 <= 5'b10000;
else begin
	if (pe_clk)
		ph4 <= 5'b10000;
	else
		ph4 <= {ph4[3:0],ph4[4]};
end


// ----------------------------------------------------------------------------
// cac stage
// ----------------------------------------------------------------------------

// IRQ fifo signals
wire irq_wr_clk = clk_i;
wire irq_rd_rst;
wire irq_wr_rst;
reg advance_irq_fifo, irq_rd_en2;
reg advance_msi;
reg irq_wr_en, irq_wr_en2;
wire irq_empty;
Qupls4_pkg::irq_info_packet_t irq2;
Qupls4_pkg::irq_info_packet_t irq2_dout;
Qupls4_pkg::irq_info_packet_t irq2_din;

always_comb
begin
	irq2 = irq2_dout;
end
always_comb
	irq_rd_en2 = advance_irq_fifo & ~irst & ~irq_rd_rst;
always_comb
	irq_wr_en2 = irq_wr_en & ~irst & ~irq_rd_rst & ~irq_wr_rst;


	// This fifo to record IRQs that got disabled after already being fetched.

   // xpm_fifo_sync: Synchronous FIFO
   // Xilinx Parameterized Macro, version 2024.1

   xpm_fifo_sync #(
      .CASCADE_HEIGHT(0),            // DECIMAL
      .DOUT_RESET_VALUE("0"),        // String
      .ECC_MODE("no_ecc"),           // String
      .EN_SIM_ASSERT_ERR("warning"), // String
      .FIFO_MEMORY_TYPE("distributed"),     // String
      .FIFO_READ_LATENCY(0),         // DECIMAL
      .FIFO_WRITE_DEPTH(32),       // DECIMAL
      .FULL_RESET_VALUE(0),          // DECIMAL
      .PROG_EMPTY_THRESH(10),        // DECIMAL
      .PROG_FULL_THRESH(10),         // DECIMAL
      .RD_DATA_COUNT_WIDTH(5),       // DECIMAL
      .READ_DATA_WIDTH($bits(Qupls4_pkg::irq_info_packet_t)),          // DECIMAL
      .READ_MODE("fwft"),             // String
      .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_ADV_FEATURES("0000"),     // String
      .WAKEUP_TIME(0),               // DECIMAL
      .WRITE_DATA_WIDTH($bits(Qupls4_pkg::irq_info_packet_t)),         // DECIMAL
      .WR_DATA_COUNT_WIDTH(5)        // DECIMAL
   )
   irq_victim_fifo (
      .almost_empty(),   // 1-bit output: Almost Empty : When asserted, this signal indicates that
                                     // only one more read can be performed before the FIFO goes to empty.

      .almost_full(),     // 1-bit output: Almost Full: When asserted, this signal indicates that
                                     // only one more write can be performed before the FIFO is full.

      .data_valid(),       // 1-bit output: Read Data Valid: When asserted, this signal indicates
                                     // that valid data is available on the output bus (dout).

      .dbiterr(),             // 1-bit output: Double Bit Error: Indicates that the ECC decoder detected
                                     // a double-bit error and data in the FIFO core is corrupted.

      .dout(irq2_dout),            // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
                                     // when reading the FIFO.

      .empty(irq_empty),             // 1-bit output: Empty Flag: When asserted, this signal indicates that the
                                     // FIFO is empty. Read requests are ignored when the FIFO is empty,
                                     // initiating a read while empty is not destructive to the FIFO.

      .full(),                   // 1-bit output: Full Flag: When asserted, this signal indicates that the
                                     // FIFO is full. Write requests are ignored when the FIFO is full,
                                     // initiating a write when the FIFO is full is not destructive to the
                                     // contents of the FIFO.

      .overflow(),           // 1-bit output: Overflow: This signal indicates that a write request
                                     // (wren) during the prior clock cycle was rejected, because the FIFO is
                                     // full. Overflowing the FIFO is not destructive to the contents of the
                                     // FIFO.

      .prog_empty(),       // 1-bit output: Programmable Empty: This signal is asserted when the
                                     // number of words in the FIFO is less than or equal to the programmable
                                     // empty threshold value. It is de-asserted when the number of words in
                                     // the FIFO exceeds the programmable empty threshold value.

      .prog_full(),         // 1-bit output: Programmable Full: This signal is asserted when the
                                     // number of words in the FIFO is greater than or equal to the
                                     // programmable full threshold value. It is de-asserted when the number of
                                     // words in the FIFO is less than the programmable full threshold value.

      .rd_data_count(), // RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates the
                                     // number of words read from the FIFO.

      .rd_rst_busy(irq_rd_rst),     // 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read
                                     // domain is currently in a reset state.

      .sbiterr(),             // 1-bit output: Single Bit Error: Indicates that the ECC decoder detected
                                     // and fixed a single-bit error.

      .underflow(),         // 1-bit output: Underflow: Indicates that the read request (rd_en) during
                                     // the previous clock cycle was rejected because the FIFO is empty. Under
                                     // flowing the FIFO is not destructive to the FIFO.

      .wr_ack(),               // 1-bit output: Write Acknowledge: This signal indicates that a write
                                     // request (wr_en) during the prior clock cycle is succeeded.

      .wr_data_count(), // WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates
                                     // the number of words written into the FIFO.

      .wr_rst_busy(irq_wr_rst),     // 1-bit output: Write Reset Busy: Active-High indicator that the FIFO
                                     // write domain is currently in a reset state.

      .din(irq2_din),                     // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
                                     // writing the FIFO.

      .injectdbiterr(), // 1-bit input: Double Bit Error Injection: Injects a double bit error if
                                     // the ECC feature is used on block RAMs or UltraRAM macros.

      .injectsbiterr(), // 1-bit input: Single Bit Error Injection: Injects a single bit error if
                                     // the ECC feature is used on block RAMs or UltraRAM macros.

      .rd_en(irq_rd_en2),                 // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
                                     // signal causes data (on dout) to be read from the FIFO. Must be held
                                     // active-low when rd_rst_busy is active high.

      .rst(irst),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
                                     // unstable at the time of applying reset, but reset must be released only
                                     // after the clock(s) is/are stable.

      .sleep(1'b0),                 // 1-bit input: Dynamic power saving- If sleep is High, the memory/fifo
                                     // block is in power saving mode.

      .wr_clk(irq_wr_clk),               // 1-bit input: Write clock: Used for write operation. wr_clk must be a
                                     // free running clock.

      .wr_en(irq_wr_en2)                  // 1-bit input: Write Enable: If the FIFO is not full, asserting this
                                     // signal causes data (on din) to be written to the FIFO Must be held
                                     // active-low when rst or wr_rst_busy or rd_rst_busy is active high

   );

	

pc_address_t nmi_addr, irq_addr, next_hwipc, hwipc;
reg nmi, ic_nmi, nmi_fet;
reg [5:0] ic_irq, ipl_ic, ipl_fet;
reg irq_trig;
wire pe_nmi;
reg exe_nmi, exe_irq;
reg ic_irqf;
reg [7:0] irq_downcount;
reg [7:0] irq_downcount_base;
reg irq_in_pipe;
reg irq_ack_ok;
cpu_types_pkg::seqnum_t irq_sn;
wire do_commit;

always_comb
	nmi = irq_i==6'd63;
always_comb
	irq_addr = irq ? ivect_i[63:0]  : kernel_vectors[sr.dbg ? 4 : fnNextOm(sr.om)];
always_comb
	nmi_addr = kernel_vectors[sr.dbg ? 4 : fnNextOm(sr.om)];

edge_det unmied1 (.clk(clk), .rst(irst), .ce(advance_fetch), .i(nmi), .pe(pe_nmi), .ne(), .ee());

always_ff @(posedge clk)
if (irst)
	irq_sn <= 8'h00;
else begin
	if (advance_pipeline) begin
		if (pe_nmi)
			irq_sn <= irq_sn + 2'd1;
		if (advance_msi|irq_rd_en2)
			irq_sn <= irq_sn + 2'd1;
	end
end

always_ff @(posedge clk)
if (irst)
	ic_nmi <= FALSE;
else begin
	if (advance_pipeline)
		ic_nmi <= pe_nmi;
end

always_ff @(posedge clk)
if (irst)
	ic_irqf <= FALSE;
else begin
	if (advance_pipeline) begin
		if (!irq_empty)
			ic_irqf <= irq2_dout.level > pending_ipl && sr.mie;
		else
			ic_irqf <= irq_i > pending_ipl && sr.mie;
	end
end

always_ff @(posedge clk)
if (irst)
	ic_irq <= 6'd0;
else begin
	if (advance_pipeline) begin
		if (!irq_empty)
			ic_irq <= irq2_dout.level;
		else
			ic_irq <= irq_i;
	end
end

// Set pending IPL to IPL of hardware interrupt. This is to disabled further
// interrupts.

always_ff @(posedge clk)
if (irst)
	pending_ipl <= 6'd63;
else begin
	// RTE and a write to the SR may reset the interrupt level.
	if (set_pending_ipl)
		pending_ipl <= next_pending_ipl;
//	if (advance_pipeline)
	else begin
		/*
		if (takb && fcu_instr.uop==Qupls4_pkg::OP_BCCU64 && fcu_instr.uop.cnd==Qupls4_pkg::CND_BOI)
			pending_ipl <= ic_irq;
		*/
		
		if (irq2_dout.level > pending_ipl && sr.mie && !irq_empty)
			pending_ipl <= irq2_dout.level;
		else if (irq_i > pending_ipl && sr.mie)
			pending_ipl <= irq_i;
		
	end
end

always_ff @(posedge clk)
if (irst) begin
	ipl_ic <= 6'd63;
	ipl_fet <= 6'd63;
end
else begin
	if (advance_pipeline) begin
		ipl_ic <= sr.ipl;
		ipl_fet <= ipl_ic;
	end
end

// Advance input from either the FIFO or the MSI controller.
// Read from the outstanding IRQ fifo first.

always_ff @(posedge clk)
if (irst) begin
	advance_msi <= FALSE;
	advance_irq_fifo <= FALSE;
end
else begin
	advance_msi <= FALSE;
	advance_irq_fifo <= FALSE;
	if (irq_downcount==8'h00) begin
		if (irq2_dout.level > pending_ipl && sr.mie && !irq_empty)
			advance_irq_fifo <= TRUE;
		else if (irq_i > pending_ipl && sr.mie)
			advance_msi <= TRUE;
	end
end

always_comb
	irq_ack = advance_msi;


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// NaN trace fifo
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
reg [8:0] nan_log_addr;
reg do_log_nan = 1'b0;
wire nan0 = |rob[head[0]].v && cmtcnt > 3'd0 && rob[head[0]].nan;
wire nan1 = |rob[head[1]].v && cmtcnt > 3'd1 && rob[head[1]].nan;
wire nan2 = |rob[head[2]].v && cmtcnt > 3'd2 && rob[head[2]].nan;
wire nan3 = |rob[head[3]].v && cmtcnt > 3'd3 && rob[head[3]].nan;
cpu_types_pkg::pc_address_t nan1e, nan2e;
wire log_nan = (nan0|nan1|nan2|nan3) && do_commit && cmtcnt > 3'd0 && do_log_nan;

generate begin : gNaNTrace
	if (Qupls4_pkg::SUPPORT_NAN_TRACE) begin
always_ff @(posedge clk)
if (irst|q_rst[14]) begin
	nan_log_addr <= 9'd0;;
end
else if (log_nan) begin
	case({nan3,nan2,nan1,nan0})
	4'b0000:	;
	4'b0001:
		begin
			nan1e <= rob[head[0]].op.pc;
			nan2e <= {$bits(cpu_types_pkg::pc_address_t){1'b0}};
			nan_log_addr <= nan_log_addr + 2'd1;
		end
	4'b0010:
		begin
			nan1e <= rob[head[1]].op.pc;
			nan2e <= {$bits(cpu_types_pkg::pc_address_t){1'b0}};
			nan_log_addr <= nan_log_addr + 2'd1;
		end
	4'b0011,4'b0111,4'b1011,4'b1111:
		begin
			nan1e <= rob[head[0]].op.pc;
			nan2e <= rob[head[1]].op.pc;
			nan_log_addr <= nan_log_addr + 2'd1;
		end
	4'b0100:
		begin
			nan1e <= rob[head[2]].op.pc;
			nan_log_addr <= nan_log_addr + 2'd1;
		end
	4'b0101,4'b1101:
		begin
			nan1e <= rob[head[0]].op.pc;
			nan2e <= rob[head[2]].op.pc;
			nan_log_addr <= nan_log_addr + 2'd1;
		end
	4'b0110,4'b1110:
		begin
			nan1e <= rob[head[1]].op.pc;
			nan2e <= rob[head[2]].op.pc;
			nan_log_addr <= nan_log_addr + 2'd1;
		end
	4'b1000:
		begin
			nan1e <= rob[head[3]].op.pc;
			nan_log_addr <= nan_log_addr + 2'd1;
		end
	4'b1001:
		begin
			nan1e <= rob[head[0]].op.pc;
			nan2e <= rob[head[3]].op.pc;
			nan_log_addr <= nan_log_addr + 2'd1;
		end
	4'b1010:
		begin
			nan1e <= rob[head[1]].op.pc;
			nan2e <= rob[head[3]].op.pc;
			nan_log_addr <= nan_log_addr + 2'd1;
		end
	4'b1100:
		begin
			nan1e <= rob[head[2]].op.pc;
			nan2e <= rob[head[3]].op.pc;
			nan_log_addr <= nan_log_addr + 2'd1;
		end
	endcase
end


   // xpm_memory_tdpram: True Dual Port RAM
   // Xilinx Parameterized Macro, version 2025.1

   xpm_memory_tdpram #(
      .ADDR_WIDTH_A(9),               // DECIMAL
      .ADDR_WIDTH_B(9),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A($bits(cpu_types_pkg::pc_address_t)*2),        // DECIMAL
      .BYTE_WRITE_WIDTH_B($bits(cpu_types_pkg::pc_address_t)),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_BIT_RANGE("7:0"),          // String
      .ECC_MODE("no_ecc"),            // String
      .ECC_TYPE("none"),              // String
      .IGNORE_INIT_SYNTH(0),          // DECIMAL
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("auto"),      // String
      .MEMORY_SIZE($bits(cpu_types_pkg::pc_address_t)*2*512),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .RAM_DECOMP("auto"),            // String
      .READ_DATA_WIDTH_A($bits(cpu_types_pkg::pc_address_t)*2),         // DECIMAL
      .READ_DATA_WIDTH_B($bits(cpu_types_pkg::pc_address_t)),         // DECIMAL
      .READ_LATENCY_A(2),             // DECIMAL
      .READ_LATENCY_B(2),             // DECIMAL
      .READ_RESET_VALUE_A("0"),       // String
      .READ_RESET_VALUE_B("0"),       // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WAKEUP_TIME("disable_sleep"),  // String
      .WRITE_DATA_WIDTH_A($bits(cpu_types_pkg::pc_address_t)*2),        // DECIMAL
      .WRITE_DATA_WIDTH_B($bits(cpu_types_pkg::pc_address_t)),        // DECIMAL
      .WRITE_MODE_A("no_change"),     // String
      .WRITE_MODE_B("no_change"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   unan_trace_ram (
      .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence on the data output of port A.
      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence on the data output of port A.
      .douta(),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(q_rd_data[14]),     // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence on the data output of port A.
      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence on the data output of port B.
      .addra(nan_log_addr),            // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .addrb(q_addr[8:0]), 	         // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
      .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when parameter CLOCKING_MODE is "common_clock".
      .clkb(clk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is "independent_clock". Unused when
                                       // parameter CLOCKING_MODE is "common_clock".

      .dina({nan2e,nan1e}),            // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .dinb(q_wr_data),                // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
      .ena(log_nan),                       // 1-bit input: Memory enable signal for port A. Must be high on clock cycles when read or write operations
                                       // are initiated. Pipelined internally.

      .enb(1'b1),                       // 1-bit input: Memory enable signal for port B. Must be high on clock cycles when read or write operations
                                       // are initiated. Pipelined internally.

      .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when ECC enabled (Error injection capability
                                       // is not available in "decode_only" mode).

      .injectdbiterrb(1'b0), // 1-bit input: Controls double bit error injection on input data when ECC enabled (Error injection capability
                                       // is not available in "decode_only" mode).

      .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when ECC enabled (Error injection capability
                                       // is not available in "decode_only" mode).

      .injectsbiterrb(1'b0), // 1-bit input: Controls single bit error injection on input data when ECC enabled (Error injection capability
                                       // is not available in "decode_only" mode).

      .regcea(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output data path.
      .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output data path.
      .rsta(irst),                     // 1-bit input: Reset signal for the final port A output register stage. Synchronously resets output port
                                       // douta to the value specified by parameter READ_RESET_VALUE_A.

      .rstb(irst),                     // 1-bit input: Reset signal for the final port B output register stage. Synchronously resets output port
                                       // doutb to the value specified by parameter READ_RESET_VALUE_B.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(log_nan),                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector for port A input data port dina. 1 bit
                                       // wide when word-wide writes are used. In byte-wide write configurations, each bit controls the writing one
                                       // byte of dina to address addra. For example, to synchronously write only bits [15-8] of dina when
                                       // WRITE_DATA_WIDTH_A is 32, wea would be 4'b0010.

      .web(q_wr[14])                   // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector for port B input data port dinb. 1 bit
                                       // wide when word-wide writes are used. In byte-wide write configurations, each bit controls the writing one
                                       // byte of dinb to address addrb. For example, to synchronously write only bits [15-8] of dinb when
                                       // WRITE_DATA_WIDTH_B is 32, web would be 4'b0010.

   );
end
else
	assign q_rd_data[14] = {$bits(cpu_types_pkg::pc_address_t){1'b0}};
end
endgenerate
						

wire predicted_correctly_dec;
cpu_types_pkg::pc_address_ex_t new_address_dec;
cpu_types_pkg::pc_address_ex_t new_address_ext;
wire ic_port;
wire ftaim_full, ftadm_full;
reg ihit_fet, ihit_ext, ihit_dec, ihit_ren, ihit_que;
reg fetch_alt;
wire icnop;
pc_address_ex_t icpc;
wire [2:0] igrp;
reg [7:0] length_byte;
reg [63:0] vec_dat;
always_comb vec_dat = ic_dline >> {icdp[4:0],3'd0};
reg [31:0] ic_carry_mod;
cpu_types_pkg::seqnum_t ic_irq_sn;
reg get_next_pc;

pc_stream_t [THREADS-1:0] new_stream;
wire alloc_stream;
reg [XSTREAMS*THREADS-1:0] used_streams;
pc_address_ex_t [XSTREAMS*THREADS-1:0] pcs;
pc_stream_t fet_stream;
// Buffers the instruction cache line to allow fetching along alternate paths.
wire is_buffered;
dep_stream_t [XSTREAMS-1:0] dep_stream;

// Choose a stream of execution. Give precedence to streams that have
// buffered cache lines.

icache
#(
	.CORENO(CORENO),
	.CHANNEL(0),
	// Opcode to fill an empty cache line with
	.NOP({2'b0,Qupls4_pkg::OP_NOP}))
uic1
(
	.rst(irst),
	.clk(clk),
	.ce(advance_fetch),
	.invce(invce),
	.snoop_adr(snoop_adr),
	.snoop_v(snoop_v),
	.snoop_tid(snoop_tid),
	.invall(ic_invall),
	.invline(ic_invline),
	.nop(brtgtv),
	.nop_o(icnop),
	.ip(pcs[fet_stream]),
	.ip_asid(asid[pcs[fet_stream].stream.thread]),
//	.ip(pc),
	.ip_o(icpc),
	.ihit_o(ihito),
	.ihit(ihit),
	.ic_line_lo_o(ic_clinel),
	.ic_line_hi_o(ic_clineh),
	.ic_valid(ic_valid),
	.miss_vadr(ic_miss_adr),
	.miss_asid(ic_miss_asid),
	.ic_line_i(ic_line_o),
	.wway(ic_wway),
	.wr_ic(wr_ic),
	.dp(icdp),
	.dhit_o(),//ic_dhit),
	.dc_line_o(ic_dline),
	.dc_valid(ic_dvalid),
	.port(ic_port),
	.port_i(1'b0)
);
assign ic_dhit = 1'b1;
always_ff @(posedge clk)
if (advance_fetch) begin
	ic_carry_mod <= icarry_mod;
end
else
	ic_carry_mod <= ic_carry_mod;
reg [2:0] uop_num_ic, iuop_num;
always_ff @(posedge clk)
if (advance_fetch) begin
	uop_num_ic <= iuop_num;
end
else
	iuop_num <= iuop_num;
always_ff @(posedge clk)
if (advance_fetch) begin
	ic_irq_sn <= irq_sn;
end

// ic_miss_adr is one clock in front of the translation pc_tlb_res.
// Add in a clock delay to line them up for the cache controller.
// Now registered in icache.
address_t ic_miss_adrd;
always_ff @(posedge clk)
	ic_miss_adrd <= ic_miss_adr;

wire p_override;
wire [6:0] po_bno [0:3];

icache_ctrl
#(.CORENO(CORENO),.CHANNEL(0))
icctrl1
(
	.rst(irst),
	.clk(clk),
	.wbm_req(ftaim_req),
	.wbm_resp(ftaim_resp),
	.ftam_full(ftaim_resp.rty),
	.hit(ihit),
	.tlb_v(pc_tlb_v),
	.miss_vadr(ic_miss_adr),
	.miss_padr(pc_tlb_res),
	.miss_asid(tlb_pc_entry.vpn.asid),
	.wr_ic(wr_ic),
	.way(ic_wway),
	.line_o(ic_line_o),
	.snoop_adr(snoop_adr),
	.snoop_v(snoop_v),
	.snoop_cid(snoop_cid)
);

// Executing NMI handler?
always_comb
	exe_nmi = pc.pc[$bits(pc_address_t)-1:8]==nmi_addr[$bits(pc_address_t)-1:8];
always_comb
	exe_irq = pc.pc[$bits(pc_address_t)-1:8]==irq_addr[$bits(pc_address_t)-1:8];

// Executing IRQ handler?
always_comb
	if (exe_irq)
		irq_trig = FALSE;
	else
		irq_trig = irq;

Qupls4_btb ubtb1
(
	.rst(irst),
	.clk(clk),
	.clk_en(advance_fetch),
	.en(1'b1),
	.rclk(clk),
	.advance_pc(advance_fetch),
	.get_next_pc(get_next_pc),
	.micro_machine_active(1'b0),
	.igrp(igrp),
	.p_override(p_override),
	.new_address_ext(new_address_ext),
	.predicted_correctly_dec(predicted_correctly_dec),
	.new_address_dec(new_address_dec),
	.pc(pc),
	.pc0(pc0),
	.next_pc(next_pc),
	.po_bno(po_bno),
	.takb0(ntakb[0]),
	.takb1(ntakb[1]),
	.takb2(ntakb[2]),
	.takb3(ntakb[3]),
	.branchmiss(branchmissd),//branch_state == Qupls4_pkg::BS_CHKPT_RESTORED),
	.misspc(misspc),
	.commit_pc0(commit_pc0),
	.commit_brtgt0(commit_brtgt0),
	.commit_takb0(commit_takb0),
	.commit_grp0(commit_grp0),
	.commit_br0(commit_br0),
	.commit_ret0(commit_ret0),
	.commit_jmp0(commit_jmp0),
	.commit_call0(commit_call0),
	.commit_pc1(commit_pc1),
	.commit_brtgt1(commit_brtgt1),
	.commit_takb1(commit_takb1),
	.commit_grp1(commit_grp1),
	.commit_br1(commit_br1),
	.commit_ret1(commit_ret1),
	.commit_jmp1(commit_jmp1),
	.commit_call1(commit_call1),
	.commit_pc2(commit_pc2),
	.commit_brtgt2(commit_brtgt2),
	.commit_takb2(commit_takb2),
	.commit_grp2(commit_grp2),
	.commit_br2(commit_br2),
	.commit_ret2(commit_ret2),
	.commit_jmp2(commit_jmp2),
	.commit_call2(commit_call2),
	.commit_pc3(commit_pc3),
	.commit_brtgt3(commit_brtgt3),
	.commit_takb3(commit_takb3),
	.commit_grp3(commit_grp3),
	.commit_br3(commit_br3),
	.commit_ret3(commit_ret3),
	.commit_jmp3(commit_jmp3),
	.commit_call3(commit_call3),
	.act_stream(fet_stream),
	.new_stream(new_stream),
	.alloc_stream(alloc_stream),
	.free_stream(~used_streams),
	.pcs(pcs),
	.thread_probability(thread_probability),
	.dep_stream(dep_stream),
	.is_buffered(is_buffered)
);

wire pt0_ext, pt1_ext, pt2_ext, pt3_ext;
reg [3:0] pt_ext;
always_comb
begin
	pt_ext[0] = pt0_ext;
	pt_ext[1] = pt1_ext;
	pt_ext[2] = pt2_ext;
	pt_ext[3] = pt3_ext;
end

gselectPredictor ugsp1
(
	.rst(irst),
	.clk(clk),
	.en(1'b1),
	.xbr0(commit_br0),
	.xbr1(commit_br1),
	.xbr2(commit_br2),
	.xbr3(commit_br3),
	.xip0(commit_pc0.pc), 
	.xip1(commit_pc1.pc),
	.xip2(commit_pc2.pc),
	.xip3(commit_pc3.pc),
	.takb0(commit_takb0),
	.takb1(commit_takb1),
	.takb2(commit_takb2),
	.takb3(commit_takb3),
	.ip0(pc0_f.pc),
	.predict_taken0(pt0_ext),
	.ip1(pc0_f.pc + 6'd6),
	.predict_taken1(pt1_ext),
	.ip2(pc0_f.pc + 6'd12),
	.predict_taken2(pt2_ext),
	.ip3(pc0_f.pc + 6'd18),
	.predict_taken3(pt3_ext)
);

always_ff @(posedge clk)
if (irst)
	ihit_fet <= FALSE;
else begin
	if (advance_fetch)
		ihit_fet <= ihito;
end
always_ff @(posedge clk)
if (irst)
	ihit_ext <= FALSE;
else begin
	if (advance_pipeline)
		ihit_ext <= ihit_fet;
end
always_ff @(posedge clk)
if (irst)
	ihit_dec <= FALSE;
else begin
	if (advance_pipeline)
		ihit_dec <= ihit_ext;
end
always_ff @(posedge clk)
if (irst)
	ihit_ren <= FALSE;
else begin
	if (advance_pipeline)
		ihit_ren <= ihit_dec;
end
always_ff @(posedge clk)
if (irst)
	ihit_que <= FALSE;
else begin
	if (advance_pipeline)
		ihit_que <= ihit_ren;
end

// Do not stomp on instructions is the PC matches the desired PC.
// The PC might be correct if the BTB picked the correct PC.

wire stomp_any = FALSE;//|robentry_stomp;
reg pcf, alt_pcf;
reg ihit3;
reg do_bsr2,do_bsr3,do_bsr4,do_bsr5,do_bsr6,do_bsr7;
always_ff @(posedge clk)
if (irst) begin
	ihit3 <= TRUE;
	do_bsr2 <= FALSE;
	do_bsr3 <= FALSE;		// only true while micro-code active
	do_bsr4 <= FALSE;		// only true while micro-code active
	do_bsr5 <= FALSE;		// only true while micro-code active
	do_bsr6 <= FALSE;		// only true while micro-code active
	do_bsr7 <= FALSE;		// only true while micro-code active
	do_bsr_h <= FALSE;
end
else begin
	if (advance_pipeline) begin
		ihit3 <= ihito;
		do_bsr2 <= do_ret;
		do_bsr3 <= FALSE;
		do_bsr4 <= do_bsr3;
		do_bsr5 <= do_bsr4;
		do_bsr6 <= do_bsr5;
		do_bsr7 <= do_bsr6;
		do_bsr_h <= ((do_ret) || do_bsr_h) && !ihit;
	end
end

reg branch_resolved;
always_ff @(posedge clk) branch_resolved <= fcu_branch_resolved;

Qupls4_stomp ustmp1
(
	.rst(irst),
	.clk(clk),
	.clk2x(clk),
	.ihit(ihito),
	.advance_pipeline(advance_pipeline),
	.advance_pipeline_seg2(advance_pipeline_seg2), // currently same as above
	.found_destination(fcu_found_destination),
	.destination_rndx(fcu_dst),
	.branch_resolved(branch_resolved),
	.branchmiss(branchmissd),
	.misspc(misspc),
	.predicted_match_ext(~p_override),
	.predicted_correctly_dec(predicted_correctly_dec),
	.pc(pc),
	.pc_f(pc0_f),
	.pc_fet(pc0_fet),
	.pc_ext(pg_ext.hdr.ip),
	.pc_mot(pg_mot.hdr.ip),
	.pc_dec(pg_dec.hdr.ip),
	.pc_ren(pg_ren.hdr.ip),
	.dep_stream(dep_stream),
	.stomp_fet(stomp_fet),
	.stomp_ext(stomp_ext),
	.stomp_mot(stomp_mot),
	.stomp_dec(stomp_dec),
	.stomp_ren(stomp_ren),
	.stomp_que(stomp_que),
	.stomp_quem(stomp_quem),
	.fcu_idv(fcu_rser.v),
	.fcu_id(fcu_rser.rndx),
	.missid(missid),
	.missid_v(missid_v),
	.kept_stream(kept_stream),
	.takb(takb),
	.rob(rob),
	.robentry_stomp(robentry_stomp)
);

// qd indicates which instructions will queue in a given cycle.
always_comb
begin
	qd = {MWIDTH{1'd0}};
	if (((branchmiss && !fcu_found_destination)) && |robentry_stomp)
		;
//	else if ((ihito || mipv || mipv2 || mipv3 || mipv4) && !stallq)
	else if (advance_pipeline_seg2)
		case (~cqd)

//    4'b0000: ; // do nothing

    4'b0001:	
    	panic <= Qupls4_pkg::PANIC_INVALIDIQSTATE;
    4'b0010:	
    	panic <= Qupls4_pkg::PANIC_INVALIDIQSTATE;
    4'b0011:
    	panic <= Qupls4_pkg::PANIC_INVALIDIQSTATE;
    4'b0100:	
    	panic <= Qupls4_pkg::PANIC_INVALIDIQSTATE;
    4'b0101:
    	panic <= Qupls4_pkg::PANIC_INVALIDIQSTATE;
    4'b0110:
    	panic <= Qupls4_pkg::PANIC_INVALIDIQSTATE;
    4'b0111:
    	panic <= Qupls4_pkg::PANIC_INVALIDIQSTATE;
    4'b1000:
    	if (rob[tails[3]].v==5'd0)
	   		qd = 4'b1000;
	  // Cannot have an instruction in the middle that has not queued.
    4'b1001:
    	panic <= Qupls4_pkg::PANIC_INVALIDIQSTATE;
    4'b1010:
    	panic <= Qupls4_pkg::PANIC_INVALIDIQSTATE;
    4'b1011:
    	panic <= Qupls4_pkg::PANIC_INVALIDIQSTATE;
    4'b1100:
    	if (rob[tails[2]].v==5'd0) begin
    		qd = 4'b0100;
    		if (!pt_q[2] && !pg_ren.pr[2].op.decbus.regs) begin
    			if (rob[tails[3]].v==5'd0) begin
	    			qd = 4'b1100;
	    		end
	    	end
    	end
    4'b1101:
    	panic <= Qupls4_pkg::PANIC_INVALIDIQSTATE;
    4'b1110:
    	if (rob[tails[1]].v==5'd0) begin
    		qd = 4'b0010;
    		if (!pt_q[1] && !pg_ren.pr[1].op.decbus.regs) begin
    			if (rob[tails[2]].v==5'd0) begin
		    		qd = 4'b0110;
	    			if (!pt_q[2] && !pg_ren.pr[2].op.decbus.regs) begin
	    				if (rob[tails[3]].v==5'd0) begin
			    			qd = 4'b1110;
			    		end
			    	end
		    	end
    		end
    	end
    default:
    	if (rob[tails[0]].v==5'd0) begin
    		qd = 4'b0001;
    		if (!pt_q[0] && !pg_ren.pr[0].op.decbus.regs) begin
    			if (rob[tails[1]].v==5'd0) begin
	    			qd = 4'b0011;
	    			if (!pt_q[1] && !pg_ren.pr[1].op.decbus.regs) begin
	    				if (rob[tails[2]].v==5'd0) begin
			    			qd = 4'b0111;
		    				if (!pt_q[2] && !pg_ren.pr[2].op.decbus.regs) begin
		    					if (rob[tails[3]].v==5'd0)
				    				qd = 4'b1111;
				    		end
			    		end
			    	end
    			end
    		end
    	end
    endcase
end

// cumulative queued.
always_comb
	next_cqd = cqd | qd;
always_ff @(posedge clk)
if (irst)
	cqd <= {MWIDTH{1'd0}};
else begin
	if (advance_pipeline_seg2) begin
		cqd <= next_cqd;
		if (next_cqd == {MWIDTH{1'b1}})
			cqd <= {MWIDTH{1'd0}};
	end
end

reg allqd;
edge_det ued1 (.rst(irst), .clk(clk), .ce(advance_pipeline_seg2), .i(next_cqd=={MWIDTH{1'b1}}), .pe(pe_allqd), .ne(), .ee());

always_comb
	fetch_new = (ihito & ~hirq & (pe_allqd|allqd));
							 
/*
always_comb
	fetch_new_block = pc.pc[$bits(pc_address_t)-1:6]!=icpc.pc[$bits(pc_address_t)-1:6];
always_ff @(posedge clk)
if (advance_pipeline)
	fetch_new_block_x <= fetch_new_block;
*/

always_comb
	hold_ins = |reg_bitmask;

always_comb
	get_next_pc = ((pe_allqd||allqd||&next_cqd) && !hold_ins) && ihit && ~hirq;

// All queued flag.

always_ff @(posedge clk)
if (irst)
	allqd <= 1'b1;
else if(advance_pipeline_seg2) begin
	if (pe_allqd & ~(ihito & ~hirq))
		allqd <= 1'b1;
	if (next_cqd=={MWIDTH{1'b1}})
		allqd <= 1'b1;
	if (branchmiss)
		allqd <= 1'b0;
	if (get_next_pc) begin
  	allqd <= &next_cqd;
	end
end

// Instruction pointer (program counter) (Now in BTB)
// Could use the lack of a IP change to fetch from an alternate path.
// The IP will not change while micro-code is running except when a branch
// instruction is performed. The branch instruction is used to exit the
// micro-code.
/*
always_ff @(posedge clk)
if (irst) begin
	pc.stream <= 6'd1;
	pc.bno_f <= 6'd1;
	pc.pc <= RSTPC;
	pcf <= FALSE;
	stomp_fet1 = FALSE;
	stomp_ext1 = FALSE;
	icarry_mod <= 32'd0;
	iuop_num <= 3'd0;
end
else begin
	if (advance_f & !ic_stallq) begin
		pcf <= FALSE;
		iuop_num <= 3'd0;
		icarry_mod <= 32'd0;
		if (get_next_pc) begin
			if (excret) begin
				pc.pc <= exc_ret_pc;
				icarry_mod <= exc_ret_carry_mod;
				iuop_num <= exc_uop_num;
			end
			else begin
				pc <= next_pc;			// early PC predictor from BTB logic
				hwipc <= next_hwipc;
			end
		end
		else if (!pcf && (bs_done_oh || ((do_bsr || do_ret) && !fcu_found_destination))) begin
			pc <= next_pc;
			hwipc <= next_hwipc;
		end
	end
	// Prevent hang when the pipeline cannot advance because there is no room 
	// to queue, yet the IP needs to change to get out of the branch miss state.
	else begin
		if (pe_bsdone || ((do_bsr || do_ret) && !fcu_found_destination)) begin
			pc <= next_pc;
			hwipc <= next_hwipc;
			pcf <= TRUE;
		end
	end
	// Re-route the PC in event of prediction miss.
	stomp_fet1 = FALSE;
	stomp_ext1 = FALSE;
	
	if (pt_dec[0]) begin
		if (pt_dec[0] != pg_dec.pr[0].bt) begin
			pc <= pt_dec[0] ? pg_dec.pr[0].brtgt : pg_dec.pr[0].pc + 5'd8;
			stomp_fet1 = TRUE;
			stomp_ext1 = TRUE;
			if (pt_dec[0]) begin
				ins1_d_inv = TRUE;
				ins2_d_inv = TRUE;
				ins3_d_inv = TRUE;
			end
		end
	end
	else if (pt_dec[1]) begin
		if (pt_dec[1] != pg_dec.pr[1].bt) begin
			pc <= pt_dec[1] ? pg_dec.pr[1].brtgt : pg_dec.pr[1].pc + 5'd8;
			stomp_fet1 = TRUE;
			stomp_ext1 = TRUE;
			if (pt_dec[1]) begin
				ins2_d_inv = TRUE;
				ins3_d_inv = TRUE;
			end
		end
	end
	else if (pt_dec[2]) begin
		if (pt_dec[2] != pg_dec.pr[2].bt) begin
			pc <= pt_dec[2] ? pg_dec.pr[2].brtgt : pg_dec.pr[2].pc + 5'd8;
			stomp_fet1 = TRUE;
			stomp_ext1 = TRUE;
			if (pt_dec[2]) begin
				ins3_d_inv = TRUE;
			end
		end
	end
	else if (pt_dec[3]) begin
		if (pt_dec[3] != pg_dec.pr[3].bt) begin
			pc <= pt_dec[3] ? pg_dec.pr[3].brtgt : pg_dec.pr[3].pc + 5'd8;
			stomp_fet1 = TRUE;
			stomp_ext1 = TRUE;
		end
	end

end
*/
always_comb
	hirq = irq && !int_commit && (irq_i > sr.ipl || irq_i==6'd63);	// NMI (63) is always recognized.

// -----------------------------------------------------------------------------
// PARSE stage (length decode)
// -----------------------------------------------------------------------------

wire [2:0] igrp2;

always_comb pc0 = pcs[fet_stream];
always_comb 
begin
	pc1 = pc0;
	pc1.pc = pc0.pc + 6'd6;
end
always_comb
begin
	pc2 = pc0;
	pc2.pc = pc0.pc + 6'd12;
end
always_comb
begin
	pc3 = pc0;
	pc3.pc = pc0.pc + 6'd18;
end
always_comb
begin
	pc4 = pc0;
	pc4.pc = pc0.pc + 6'd24;
end

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// "fet" stage
//
// ic_line is "raw" coming out of the cache. The cache output is not registered
// and has been muxed a couple of times. Rather than feed the output into 
// another set of multiplexors for the mux stage, it is registered at this
// point.
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

wire flush_fet;
pc_address_ex_t misspc_fet;
wire [1023:0] ic_line_fet;
pc_address_t ic_hwipc, hwipc_fet;
wire micro_machine_active_fet;
wire [31:0] carry_mod_fet;
wire [2:0] uop_num_fet;
reg [511:0] inj_cline;
reg irq_ic;
seqnum_t irq_sn_fet;
Qupls4_pkg::irq_info_packet_t irq_in_ic;
reg irq_fet;
Qupls4_pkg::irq_info_packet_t irq_in_fet;

always_ff @(posedge clk)
	ic_hwipc <= hwipc;
always_ff @(posedge clk)
	irq_ic <= hirq;
always_ff @(posedge clk)
	irq_in_ic <= irq_in;

pregno_t pred_reg;
pc_address_ex_t pc_fet;

Qupls4_instruction_buffer uib1
(
	.rst_i(irst),
	.clk_i(clk),
	.ihit_i(ihito),
	.stream_i(fet_stream),
	.ips_i(pcs),
	.ip_i(icpc),
	.line_i({ic_clineh.data,ic_clinel.data}),
	.line_o(ic_line),
	.ip_o(pc_fet),
	.is_buffered_o(is_buffered)
);

Qupls4_pipeline_fet ufet1
(
	.rst(irst),
	.clk(clk),
	.ihit(is_buffered),
	.irq_in_ic(irq_in_ic),
	.irq_ic(irq_ic),
	.irq_in_fet(irq_in_fet),
	.irq_fet(irq_fet),
	.irq_sn_ic(ic_irq_sn),
	.irq_sn_fet(irq_sn_fet),
	.en(advance_fetch),
	.uop_num_ic(uop_num_ic),
	.uop_num_fet(uop_num_fet),
	.pc_i(pc_fet),
	.misspc(misspc),
	.misspc_fet(misspc_fet),
	.ic_carry_mod(ic_carry_mod),
	.carry_mod_fet(carry_mod_fet),
//	.hwipc(ic_hwipc),
//	.hwipc_fet(hwipc_fet),
	.pc0_fet(pc0_fet),
	.stomp_fet(stomp_fet),
	.kept_stream(kept_stream),
	.inject_cl(1'b0),
	.ic_line_i(ic_line),
	.inj_line_i(inj_cline),
	.ic_line_fet(ic_line_fet),
	.nmi_i(pe_nmi),
	.flush_i(flush_pipeline),
	.flush_fet(flush_fet)
);

// -----------------------------------------------------------------------------
// Instruction extract stage
// -----------------------------------------------------------------------------

wire exti_nop;	
pc_address_ex_t pc0_f1;
pc_address_ex_t pc0_f2;
pc_address_ex_t pc0_f3;
wire new_cline_ext;
wire [1023:0] cline_ext;
wire [2:0] uop_num_ext;

always_comb
begin
	pc0_f1 = pc0_f;
	pc0_f1.pc = pc0_f.pc + 6'd6;
end
always_comb
begin
	pc0_f2 = pc0_f;
	pc0_f2.pc = pc0_f.pc + 6'd12;
end
always_comb
begin
	pc0_f3 = pc0_f;
	pc0_f3.pc = pc0_f.pc + 6'd18;
end

always_ff @(posedge clk)
	takb_pc = ntakb;
always_ff @(posedge clk)
if (advance_pipeline)
	takb_f <= takb_pc;
always_ff @(posedge clk)
if (advance_pipeline)
	takb_fet <= takb_f;

reg rob_hwi;
always_comb
begin
	rob_hwi = FALSE;
	foreach (pgh[n36])
		rob_hwi = rob_hwi | pgh[n36].hwi;
end

always_comb
	irq_in_pipe = 
		hirq | ic_irq | irq_fet | pg_ext.hdr.hwi | pg_dec.hdr.hwi | pg_ren.hdr.hwi | rob_hwi
		;

// Latency of one.
// pt_dec[0], etc. should be in line with pg_dec.pr[0], etc
Qupls4_pipeline_ext #(.MWIDTH(MWIDTH)) uiext1
(
	.rst_i(irst),
	.clk_i(clk),
	.flush_fet(flush_fet),
	.en_i(advance_extract & rstcnt[5]),
	.cline_fet(ic_line_fet),
	.new_cline_ext(new_cline_ext),
	.cline_ext(cline_ext),
	.ssm_flag(ssm_flag),
	.ihit(ihito),
	.sr(sr),
	.ipl_fet(ipl_fet),
	.uop_num_fet(uop_num_fet),
	.uop_num_ext(uop_num_ext),
	.carry_mod_fet(carry_mod_fet),
	.kept_stream(kept_stream),
	.stomp_ext(stomp_ext),/*icnop||brtgtv||fetch_new_block_x*/
	.nop_o(exti_nop),
//	.nmi_i(pe_nmi),
	.irq_sn_fet(irq_sn_fet),
	.irq_in_fet(irq_in_fet),
	.irq_fet(irq_fet),
	.reglist_active(1'b0),
	.grp_i(igrp2),
	.misspc_fet(misspc_fet),
	.pc0_fet(pc0_fet),
	.hwipc_fet(hwipc_fet),
	.micro_machine_active(1'b0),
	.branchmiss(branchmissd),//branch_state > Qupls4_pkg::BS_STATE3),
	.takb_fet(takb_fet),
	.pt_ext(pt_ext),
	.pt_dec(pt_dec),
	.p_override(p_override),
	.po_bno(po_bno),
	.vl(vl),
	.ls_bmf_i(ls_bmf),
	.pack_regs_i(pack_regs),
	.scale_regs_i(scale_regs),
	.regcnt_i(8'd0),
	.pg_ext(pg_ext),
	.grp_o(grp_d),
	.do_ret(do_ret),
	.do_call(do_call),
	.ret_pc(ret_pc),
	.new_address_o(new_address_ext),
	.get(dc_get),
	.new_stream(new_stream),
	.alloc_stream(alloc_stream)
);

// ----------------------------------------------------------------------------
// Micro-op translate and queue stage
// ----------------------------------------------------------------------------

wire [1023:0] cline_mot;
Qupls4_pkg::micro_op_t [MAX_MICROOPS-1:0] uop_buf;
wire [2:0] uop_mark [0:MAX_MICROOPS-1];
wire [3:0] uop_head [0:MWIDTH-1];

Qupls4_pipeline_mot #(
	.COMB(1),
	.MICROOPS_PER_INSTR(MICROOPS_PER_INSTR),
	.MAX_MICROOPS(MAX_MICROOPS)
)
umot1
(
	.rst(irst),
	.clk(clk),
	.en(advance_decode),
	.stomp(stomp_mot),
	.cline_ext(cline_ext),
	.cline_mot(cline_mot),
	.pg_ext(pg_ext),
	.pg_mot(pg_mot),
	.uop_buf(uop_buf),
	.uop_mark(uop_mark),
	.advance_ext(advance_extract),
	.head(uop_head)
);

// ----------------------------------------------------------------------------
// DECODE stage
// ----------------------------------------------------------------------------

Qupls4_pkg::ex_instruction_t [3:0] instr;
pregno_t [3:0] tags2free;
wire [3:0] freevals;
checkpt_ndx_t cndx0,cndx1,cndx2,cndx3,pcndx;		// checkpoint index for each queue slot
wire restore;		// = branch_state==BS_CHKPT_RESTORE && restore_en;// && !fcu_cjb;

Qupls4_pipeline_dec #(
	.MWIDTH(MWIDTH),
	.MICROOPS_PER_INSTR(MICROOPS_PER_INSTR),
	.MAX_MICROOPS(MAX_MICROOPS)
)
udecstg1
(
	.rst_i(rst_i),
	.rst(irst),
	.clk(clk),
	.en(advance_decode),
	.new_cline_ext(new_cline_ext),
	.cline(cline_mot),
	.sr(sr),
	.uop_num(uop_num_ext),
	.tags2free(tags2free),
	.freevals(freevals),
	.bo_wr(bo_wr),
	.bo_preg(bo_preg),
	.stomp_dec(stomp_dec),
	.stomp_ext(stomp_ext),
	.kept_stream(kept_stream),
	.pg_mot(pg_mot),
	.pg_dec(pg_dec),
	.ren_stallq(ren_stallq),
	.ren_rst_busy(ren_rst_busy),
	.predicted_correctly_o(predicted_correctly_dec),
	.new_address_o(new_address_dec),
	.uop_buf(uop_buf),
	.uop_mark(uop_mark),
	.uop_head(uop_head)
);

reg [MWIDTH-1:0] wrport0_v;
reg wrport4_v;
reg wrport5_v;
reg [8:0] wrport0_we [0:MWIDTH-1];
reg [8:0] wrport4_we;
reg [8:0] wrport5_we;
value_t [MWIDTH-1:0] wrport0_res;
value_t wrport4_res;
value_t wrport5_res;
pregno_t [MWIDTH-1:0] wrport0_Rt;
pregno_t wrport4_Rt;
pregno_t wrport5_Rt;
aregno_t [MWIDTH-1:0] wrport0_aRt;
aregno_t wrport4_aRt;
aregno_t wrport5_aRt;
checkpt_ndx_t [MWIDTH-1:0] wrport0_cp;
reg [MWIDTH-1:0] wrport0_tag;

wire [MWIDTH-1:0] stomps;

Qupls4_pkg::operand_t [NREG_RPORTS-1:0] rf_oper;
pregno_t [NREG_RPORTS-1:0] prn1,prnd;
checkpt_ndx_t [NREG_RPORTS-1:0] rn_cp;
wire [NREG_RPORTS-1:0] prnv;
wire [NREG_RPORTS-1:0] rf_regvo;
reg [NREG_RPORTS-1:0] prnvd;
wire [0:0] arnbank [NREG_RPORTS-1:0];
checkpt_ndx_t [3:0] cndx_ren;
checkpt_ndx_t pcndx_ren;

always_ff @(posedge clk)
	prnd <= prn;
always_ff @(posedge clk)
	prnvd <= prnv;

// Operand bus loading. Supplies the reservation stations.
always_ff @(posedge clk)
	foreach (rf_oper[n37]) begin
		rf_oper[n37].pRn <= rf_rego[n37];
		rf_oper[n37].val <= rfo[n37];
		rf_oper[n37].flags <= rfo_flags[n37];
		rf_oper[n37].v <= rf_regvo[n37];
	end
/*
always_comb
begin
	arn[0] = pg_dec.pr[0].aRa; arnt[0] = 1'b0; arng[0] = 3'd0;
	arn[1] = pg_dec.pr[0].aRb; arnt[1] = 1'b0; arng[1] = 3'd0;
	arn[2] = pg_dec.pr[0].aRc; arnt[2] = 1'b0; arng[2] = 3'd0;
	arn[3] = pg_dec.pr[0].aRt; arnt[3] = 1'b1; arng[3] = 3'd0;
	
	arn[4] = pg_dec.pr[1].aRa; arnt[4] = 1'b0; arng[4] = 3'd1;
	arn[5] = pg_dec.pr[1].aRb; arnt[5] = 1'b0; arng[5] = 3'd1;
	arn[6] = pg_dec.pr[1].aRc; arnt[6] = 1'b0; arng[6] = 3'd1;
	arn[7] = pg_dec.pr[1].aRt; arnt[7] = 1'b1; arng[7] = 3'd1;
	
	arn[8] = pg_dec.pr[2].aRa; arnt[8] = 1'b0; arng[8] = 3'd2;
	arn[9] = pg_dec.pr[2].aRb; arnt[9] = 1'b0; arng[9] = 3'd2;
	arn[10] = pg_dec.pr[2].aRc; arnt[10] = 1'b0; arng[10] = 3'd2;
	arn[11] = pg_dec.pr[2].aRt; arnt[11] = 1'b1; arng[11] = 3'd2;
	
	arn[12] = pg_dec.pr[3].aRa; arnt[12] = 1'b0; arng[12] = 3'd3;
	arn[13] = pg_dec.pr[3].aRb; arnt[13] = 1'b0; arng[13] = 3'd3;
	arn[14] = pg_dec.pr[3].aRc; arnt[14] = 1'b0; arng[14] = 3'd3;
	arn[15] = pg_dec.pr[3].aRt; arnt[15] = 1'b1; arng[15] = 3'd3;

 	arn[16] = 8'h00; arnt[16] = 1'b0; arng[16] = 3'd0;
	
	arn[17] = pg_dec.pr[0].decbus.Rm; arnt[17] = 1'b0; arng[17] = 3'd0;
	arn[18] = pg_dec.pr[1].decbus.Rm; arnt[18] = 1'b0; arng[18] = 3'd1;
	arn[19] = pg_dec.pr[2].decbus.Rm; arnt[19] = 1'b0; arng[19] = 3'd2;
	arn[20] = pg_dec.pr[3].decbus.Rm; arnt[20] = 1'b0; arng[20] = 3'd3;
 	arn[21] = 8'h00; arnt[21] = 1'b0; arng[21] = 3'd4;
 	arn[22] = 8'h00; arnt[22] = 1'b0; arng[22] = 3'd4;
	arn[23] = store_argC_aReg; arnt[23] = 1'b0; arng[23] = 3'd0;

	rn_cp[0] = cndx0;
	rn_cp[1] = cndx0;
	rn_cp[2] = cndx0;
	rn_cp[3] = cndx0;
	rn_cp[17] = cndx0;
	
	rn_cp[4] = cndx1;
	rn_cp[5] = cndx1;
	rn_cp[6] = cndx1;
	rn_cp[7] = cndx1;
	rn_cp[18] = cndx1;
	
	rn_cp[8] = cndx2;
	rn_cp[9] = cndx2;
	rn_cp[10] = cndx2;
	rn_cp[11] = cndx2;
	rn_cp[19] = cndx2;

	rn_cp[12] = cndx3;
	rn_cp[13] = cndx3;
	rn_cp[14] = cndx3;
	rn_cp[15] = cndx3;
	rn_cp[20] = cndx3;


	rn_cp[16] = 4'd0;
	rn_cp[21] = 4'd0;
	rn_cp[22] = 4'd0;
	rn_cp[23] = store_argC_cndx;

end
*/
Qupls4_pkg::operand_t [MWIDTH-1:0] wp;
Qupls4_pkg::operand_t [MWIDTH-1:0] wp_tap [0:4];

always_comb
begin
	foreach (wp[n49]) begin
		wp[n49].val = wrport0_res[n49];
		wp[n49].flags = wrport0_tag[n49];
		wp[n49].pRn = wrport0_Rt[n49];
		wp[n49].v = wrport0_v[n49];
		wp[n49].aRn = 8'd00;		// we don't know this one, but it is not needed
		wp[n49].aRnv = FALSE;
	end
end
Qupls4_wp_history_tap uwph1
(
	.clk(clk),
	.wp_i(wp),
	.wp_tap_o(wp_tap)
);

// Change 16 groups of four port requests into one big linear group. (Just wires).
always_comb
begin
	pRs = {64*10{1'b0}};
	pRsv = 64'd0;
	for (jj = 0; jj < 64; jj = jj + 1) begin
		pRs[jj] = bRs[jj[5:2]][jj[1:0]];
		pRsv[jj] = bRsv[jj[5:2]][jj[1:0]];
	end
end
// Dynamic port selection.
Qupls4_read_port_select #(.FIXED_PORTS(0), .NPORTO(NREG_RPORTS), .NPORTI(NREG_RPORTS*4)) urps1
(
	.rst(irst),
	.clk(clk),
	.pReg_i(pRs),
	.pRegv_i(pRsv),
	.pReg_o(prn),
	.regAck_o()
);

reg vec_stallq;
reg vec_stall2;
reg room_for_que;
reg room_for_lsq_queue;
Qupls4_pkg::lsq_ndx_t lsq_head;
Qupls4_pkg::lsq_ndx_t lsq_tail, lsq_tail0;

always_comb	advance_enqueue =
	 rstcnt[5] &&			// not resetting
	!sync_ndxv &&			// there is no sync instruction in the re-order buffer
	!rat_stallq &&		// not stalled on register alias
	room_for_que && 	// and there is room to queue
	(DISPATCH_STRATEGY==0 ? !stall_dsp : TRUE)	// not stalled dispatching
	;	

always_comb	advance_rename =
	 rstcnt[5] &&			// not resetting
	!sync_ndxv &&			// there is no sync instruction in the re-order buffer
	!rat_stallq &&		// not stalled on register alias
	(DISPATCH_STRATEGY==0 ? !stall_dsp : TRUE) && // not stalled dispatching
	advance_enqueue
	;	

always_comb	advance_decode =
	 rstcnt[5] &&			// not resetting
	!sync_ndxv &&			// there is no sync instruction in the re-order buffer
	!rat_stallq &&		// not stalled on register alias
	(DISPATCH_STRATEGY==0 ? !stall_dsp : TRUE) && // not stalled dispatching
	advance_rename
	;	

// advance_extract set by decode stage

always_comb advance_fetch =
	advance_extract &
	rstcnt[5]
	;

always_comb advance_pipeline =

	 rstcnt[5] &&			// not resetting
	!sync_ndxv &&			// there is no sync instruction in the re-order buffer
	!rat_stallq &&		// not stalled on register alias
//	!vec_stallq &&		// I think this was on vector lookup
//	!ns_stall &&			// not stalled supplying register names
	room_for_que && 	// and there is room to queue
	(DISPATCH_STRATEGY==0 ? !stall_dsp : TRUE);				// not stalled dispatching

always_comb advance_pipeline_seg2 = advance_pipeline;// || dc_get;//(!stallq && !vec_stallq) || dc_get;
always_comb vec_stallq = !ic_dhit || vec_stall2;
reg nq0,nq1,nq2,nq3;
always_comb nq0 = TRUE;
always_comb nq1 = TRUE;
always_comb nq2 = TRUE;
always_comb nq3 = TRUE;

always_ff @(posedge clk)
if (irst) begin
	cndx_ren[0] <= {$bits(checkpt_ndx_t){1'b0}};
	cndx_ren[1] <= {$bits(checkpt_ndx_t){1'b0}};
	cndx_ren[2] <= {$bits(checkpt_ndx_t){1'b0}};
	cndx_ren[3] <= {$bits(checkpt_ndx_t){1'b0}};
	pcndx_ren <= {$bits(checkpt_ndx_t){1'b0}};
end
else begin
	if (advance_pipeline) begin
		cndx_ren[0] <= cndx0;
		cndx_ren[1] <= cndx0;
		cndx_ren[2] <= cndx0;
		cndx_ren[3] <= cndx0;
		pcndx_ren <= pcndx;
	end
end

wire [7:0] enqueue_room;

Qupls4_queue_room uqroom1
(
	.rst(irst),
	.clk(clk),
	.rob(rob),
	.head0(head[0]),
	.tails(tails),
	.room(enqueue_room)
);

wire [3:0] lsq_enqueue_room;

Qupls4_lsq_queue_room uqroom2
(
	.lsq(lsq),
	.head(lsq_head),
	.tail(lsq_tail),
	.room(lsq_enqueue_room)
);

always_comb
	room_for_que = enqueue_room > 8'd3;
always_comb
	room_for_lsq_queue = lsq_enqueue_room > 4'd0;
assign nq = !(branchmiss) && advance_pipeline && room_for_que && (!stomp_que || stomp_quem);

reg signed [$clog2(Qupls4_pkg::ROB_ENTRIES):0] cmtlen;			// Will always be >= 0
reg signed [$clog2(Qupls4_pkg::ROB_ENTRIES):0] group_len;		// Commit group length

reg [MWIDTH-1:0] cmttlb;
reg htcolls;		// head <-> tail collision
reg cmtbr;

// When to stomp on instructions enqueuing.
// If the slot is not queuing then it is stomped on.
reg stomp0_q;
reg stomp1_q;
reg stomp2_q;
reg stomp3_q;
// Detect stomp on leading instructions due to a branch.
wire stomp0b_r = FALSE;//branch_state > Qupls4_pkg::BS_STATE3 && misspc.pc > pg_ren.pr[0].op.pc.pc;
wire stomp1b_r = FALSE;//branch_state > Qupls4_pkg::BS_STATE3 && misspc.pc > pg_ren.pr[1].op.pc.pc;
wire stomp2b_r = FALSE;//branch_state > Qupls4_pkg::BS_STATE3 && misspc.pc > pg_ren.pr[2].op.pc.pc;
wire stomp3b_r = FALSE;//branch_state > Qupls4_pkg::BS_STATE3 && misspc.pc > pg_ren.pr[3].op.pc.pc;
wire stomp0_r = /*~qd_r[0]||stomp_ren||stomp0b_r*/stomp_ren && pg_ren.pr[0].ip_stream!=kept_stream;
wire stomp1_r = /*~qd_r[1]||stomp_ren||stomp1b_r||*/(stomp_ren && pg_ren.pr[1].ip_stream!=kept_stream);// ||
//							 (pg_ren.pr[0].decbus.br && pg_ren.pr[0].bt);//pt_r[0]||MWIDTH < 2;
wire stomp2_r = /*~qd_r[2]||stomp_ren||stomp2b_r||*/(stomp_ren && pg_ren.pr[2].ip_stream!=kept_stream);// ||
//							 (pg_ren.pr[0].decbus.br && pg_ren.pr[0].bt) ||
//							 (pg_ren.pr[1].decbus.br && pg_ren.pr[1].bt)
//;//pt_r[0]||pt_r[1]||MWIDTH < 3;
wire stomp3_r = /*~qd_r[3]||stomp_ren||stomp3b_r||*/(stomp_ren && pg_ren.pr[3].ip_stream!=kept_stream);// ||
//							 (pg_ren.pr[0].decbus.br && pg_ren.pr[0].bt) ||
//							 (pg_ren.pr[1].decbus.br && pg_ren.pr[1].bt) ||
//							 (pg_ren.pr[2].decbus.br && pg_ren.pr[2].bt)
//							 ;
//;//pt_r[0]||pt_r[1]||pt_r[2]||MWIDTH < 4;
always_ff @(posedge clk)
if (irst)
	stomp0_q <= FALSE;
else begin
	if (advance_pipeline_seg2)
		stomp0_q <= stomp0_r;
end
always_ff @(posedge clk)
if (irst)
	stomp1_q <= FALSE;
else begin
	if (advance_pipeline_seg2)
		stomp1_q <= stomp1_r;
end
always_ff @(posedge clk) if (advance_pipeline) stomp2_q <= stomp2_r;
always_ff @(posedge clk) if (advance_pipeline) stomp3_q <= stomp3_r;
assign stomps[0] = ((stomp0_r|stomp_ren) /*&& pg_ren.pr[0].pc.stream!=kept_stream*/);
assign stomps[1] = ((stomp1_r|stomp_ren|pg_ren.pr[0].op.decbus.macro) /*&& pg_ren.pr[1].pc.stream!=kept_stream*/);
assign stomps[2] = ((stomp2_r|stomp_ren|pg_ren.pr[0].op.decbus.macro|pg_ren.pr[1].op.decbus.macro) /*&& pg_ren.pr[2].pc.stream!=kept_stream*/);
assign stomps[3] = ((stomp3_r|stomp_ren|pg_ren.pr[0].op.decbus.macro|pg_ren.pr[1].op.decbus.macro|pg_ren.pr[2].op.decbus.macro) /*&& pg_ren.pr[3].pc.stream!=kept_stream*/);

// Determine which instructions following a jsr/bsr should not be executed.
reg [MWIDTH-1:0] ornops;
reg [MWIDTH-1:0] jbsrnop;
wire [3:0] jbsr_pos;
flo12 unops1 (.i({11'd0,jbsrnop}), .o(jbsr_pos));	// find the first jsr/bsr

always_comb
begin
	jbsrnop = {MWIDTH{1'b0}};
	for (n38 = 0; n38 < MWIDTH; n38 = n38 + 1)
		jbsrnop[n38] = pg_ren.pr[n38].op.decbus.bsr | pg_ren.pr[n38].op.decbus.jsr;
end
// If a jsr/bsr not found, jbsr_pos will be 15 and the mask will shift off the
// end resulting in a zero.
always_comb
	ornops = ~{{8'd2 << jbsr_pos} - 1};

/*
wire ornops[0] = 1'b0;
wire ornops[1] = pg_ren.pr[0].op.decbus.bsr||pg_ren.pr[0].op.decbus.jsr;
wire ornops[2] = pg_ren.pr[0].op.decbus.bsr || pg_ren.pr[1].op.decbus.bsr || pg_ren.pr[0].op.decbus.jsr || pg_ren.pr[1].op.decbus.jsr;
wire ornops[3] = pg_ren.pr[0].op.decbus.bsr || pg_ren.pr[1].op.decbus.bsr || pg_ren.pr[2].op.decbus.bsr ||
	pg_ren.pr[0].op.decbus.jsr || pg_ren.pr[1].op.decbus.jsr || pg_ren.pr[2].op.decbus.jsr
	;
*/
/*
assign arnv[0] = !stomps[0];
assign arnv[1] = !stomps[0];
assign arnv[2] = !stomps[0];
assign arnv[3] = !stomps[0];
assign arnv[17] = !stomps[0];

assign arnv[4] = !stomps[1];
assign arnv[5] = !stomps[1];
assign arnv[6] = !stomps[1];
assign arnv[7] = !stomps[1];
assign arnv[18] = !stomps[1];

assign arnv[8] = !stomps[2];
assign arnv[9] = !stomps[2];
assign arnv[10] = !stomps[2];
assign arnv[11] = !stomps[2];
assign arnv[19] = !stomps[2];

assign arnv[12] = !stomps[3];
assign arnv[13] = !stomps[3];
assign arnv[14] = !stomps[3];
assign arnv[15] = !stomps[3];
assign arnv[20] = !stomps[3];

assign arnv[16] = 1'b1;
*/
assign arnv = 16'hFFFF;
wire [1:0] backout_st2;
pregno_t [MWIDTH-1:0] Rt0_ren;
wire [MWIDTH-1:0] Rt0_renv;

/*
always_ff @(posedge clk)
if (advance_pipeline) begin
	if (alloc0 && pg_ren.pr[0].decbus.Rt==0) begin
		$display("alloced r0");
		$finish;
	end
	if (alloc1 && pg_ren.pr[1].decbus.Rt==0) begin
		$display("alloced r0");
		$finish;
	end
	if (alloc2 && pg_ren.pr[2].decbus.Rt==0) begin
		$display("alloced r0");
		$finish;
	end
	if (alloc3 && pg_ren.pr[3].decbus.Rt==0) begin
		$display("alloced r0");
		$finish;
	end
end
*/

wire alloc_chkpt;
wire free_chkpt;
checkpt_ndx_t cndx;
checkpt_ndx_t fchkpt;
checkpt_ndx_t miss_cp;
rob_ndx_t chkpt_rndx;
always_comb
	miss_cp = rob[missid].cndx;
assign cndx1 = cndx0;
assign cndx2 = cndx0;
assign cndx3 = cndx0;

wire [3:0] ns_alloc_req;
rob_ndx_t [3:0] ns_whrndx;
rob_ndx_t [3:0] ns_rndx;
pregno_t [3:0] ns_dstreg;
wire [3:0] ns_dstregv;
aregno_t [3:0] ns_areg;
checkpt_ndx_t [3:0] ns_cndx;
reg [MWIDTH-1:0] cmtav,cmtaiv;
aregno_t [MWIDTH-1:0] cmtaa;
pregno_t [MWIDTH-1:0] cmtap;
checkpt_ndx_t [MWIDTH-1:0] cmta_cp;
always_comb
	for (n46 = 0; n46 < MWIDTH; n46 = n46 + 1) begin
		cmtav[n46] = do_commit && |rob[head[n46]].v && cmtcnt > n46;
		cmtaiv[n46] = do_commit && rob[head[n46]].v==5'd0 && cmtcnt > n46;
		cmtaa[n46] = rob[head[n46]].op.decbus.Rd;
		cmtap[n46] = rob[head[n46]].op.nRd;
		cmta_cp[n46] = rob[head[n46]].cndx;
	end

Qupls4_pipeline_ren #(.MWIDTH(MWIDTH), .NPORT(NREG_RPORTS)) uren1
(
	.rst(irst),
	.clk(clk),
	.clk5x(clk5x),
	.ph4(ph4),
	.en(advance_rename),
	.nq(nq),
	.restore(restore),
	.tail0(tails[0]),
	.rob(rob),
	.stomp_ren(stomp_ren),
	.kept_stream(kept_stream),
	.avail_reg(ns_avail),
	.sr(sr),
	.branch_resolved(fcu_branch_resolved),
//	.arn(arn),
//	.arng(arng),
//	.arnv(arnv),
	.rn_cp(rn_cp),
	.prn_i(prn),
	.prnv(prnv),
	.Rt0_ren(Rt0_ren),
	.Rt0_renv(Rt0_renv),
	.pg_dec(pg_dec),
	.pg_ren(pg_ren),
	
	.wrport0_v(wrport0_v),
	.wrport0_aRt(wrport0_aRt),
	.wrport0_Rt(wrport0_Rt),
	.wrport0_res(wrport0_res),
	.wrport0_cp(wrport0_cp),
	
	.cmtav(cmtav),
	.cmtaiv(cmtaiv),
	.cmtaa(amtaa),
	.cmtap(cmtap),
	.cmta_cp(cmta_cp),

	.cmtbr(cmtbr),
	.tags2free(tags2free),
	.freevals(freevals),
	.fcu_id(fcu_rse.rndx),
	.backout(backout),
	.bo_wr(bo_wr),
	.bo_areg(bo_areg),
	.bo_preg(bo_preg),
	.bo_nreg(bo_nreg),
	.rat_stallq(rat_stallq),
	.micro_machine_active_dec(1'b0),
	.micro_machine_active_ren(),
	
	.alloc_chkpt(alloc_chkpt),
	.cndx(cndx),
	.rcndx(ns_cndx),
	.miss_cp(miss_cp),

	.args(rfo)
);

/*
Qupls4_pipeline_reg #(.MWIDTH(MWIDTH)) uplreg1
(
	.rst(irst),
	.clk(clk),
	.pg_ren(pg_ren),
	.pg_reg(pg_reg),
//	.tails_i(tails),
//	.tails_o(reg_tails),
	.rf_reg(rf_reg),
	.rf_regv(rf_regv)
);
*/

wire pgh_setcp;
wire [5:0] pgh_setcp_grp;
wire [5:0] freecp_grp;

Qupls4_checkpoint_manager #(.MWIDTH(MWIDTH)) ucpm1
(
	.rst(irst),
	.clk(clk),
	.clk5x(clk5x),
	.ph4(ph4),
	.fcu_id(fcu_rse.rndx),
	.mux_hdr_cndx(pg_ext.hdr.cndx),
	.dec_hdr_cndx(pg_dec.hdr.cndx),
	.ren_hdr_cndx(pg_ren.hdr.cndx),
	.pgh(pgh),
	.setcp(pgh_setcp),
	.setcp_grp(pgh_setcp_grp),
	.freecp(free_chkpt),
	.freecp_grp(freecp_grp),
	.alloc_chkpt(alloc_chkpt),
	.cndx(cndx),
	.restore(restore),
	.miss_cp(miss_cp)
);

/* Rename is handled in the rename pipeline stage
Qupls4_map_dstreg_req umdr
(
	.pgh(pgh),
	.rob(rob),
	.ns_alloc_req(ns_alloc_req),
	.ns_whrndx(ns_whrndx),
	.ns_rndx(ns_rndx),
	.ns_areg(ns_areg),
	.ns_cndx(ns_cndx)
);

Qupls4_reg_name_supplier4 uns4
(
	.rst(irst),
	.clk(clk),
	.en(advance_pipeline),
	.restore(restore),
	.restore_list(restore_list & ~unavail_list),
	.tags2free(tags2free),
	.freevals(freevals),
	.bo_wr(bo_wr),
	.bo_preg(bo_preg),
	.ns_alloc_req(ns_alloc_req),
	.ns_whrndx(ns_whrndx),
	.ns_rndx(ns_rndx),
	.ns_dstreg(ns_dstreg),
	.ns_dstregv(ns_dstregv),
	.avail(ns_avail),
	.stall(ns_stall),
	.rst_busy()
);
*/

/*
always_ff @(posedge clk)
begin
	db0r <= db0;
	if (brtgtv)
		db0r.v <= FALSE;
end
always_ff @(posedge clk)
begin
	db1r <= db1;
	if (brtgtv)
		db1r.v <= FALSE;
end
always_ff @(posedge clk) begin
	db2r <= db2;
	if (brtgtv)
		db2r.v <= FALSE;
end
always_ff @(posedge clk) begin
	db3r <= db3;
	if (brtgtv)
		db3r.v <= FALSE;
end
*/
always_ff @(posedge clk)
if (irst) begin
	pc0_f.stream <= 7'd1;
	pc0_f.pc <= Qupls4_pkg::RSTPC;
end
else begin
//	if (advance_f)
	pc0_f <= pc_fet;//pc0;
end

rob_bitmask_t rob_dispatched;
Qupls4_pkg::rob_bitmask_t rob_dispatched_stomped;

// The cycle after the length is calculated
// instruction extract inputs
pc_address_ex_t pc0_x1;
always_ff @(posedge clk)
if (irst) begin
	pc0_x1.stream <= 7'd1;
	pc0_x1.pc <= Qupls4_pkg::RSTPC;
end
else begin
	if (advance_pipeline)
		pc0_x1 <= pc0_f;
end

always_ff @(posedge clk)
if (advance_pipeline)
	qd_x <= qd;
always_ff @(posedge clk)
if (advance_pipeline)
	qd_d <= qd_x;
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	qd_r <= qd_d;
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	qd_q <= qd_r;

always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pt_r[0] <= pt_dec[0];
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pt_r[1] <= pt_dec[1];
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pt_r[2] <= pt_dec[2];
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pt_r[3] <= pt_dec[3];

/*
Qupls4_pipeline_que uque1
(
	.rst(irst),
	.clk(clk),
	.en(advance_pipeline),
	.pg_reg(pg_reg),
	.pg_que(pg_que),
	.ins0_ren(pg_ren.pr[0].op),
	.ins1_ren(pg_ren.pr[1].op),
	.ins2_ren(pg_ren.pr[2].op),
	.ins3_ren(pg_ren.pr[3].op),
	.ins0_que(ins0_que),
	.ins1_que(ins1_que),
	.ins2_que(ins2_que),
	.ins3_que(ins3_que)
);
*/

always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pt_q[0] <= pt_r[0];
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pt_q[1] <= pt_r[1];
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pt_q[2] <= pt_r[2];
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pt_q[3] <= pt_r[3];

always_ff @(posedge clk)
if (advance_pipeline_seg2)
	grp_q <= grp_r;
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	grp_r <= grp_d;

reg sau0_wrA, sau0_wrB, sau0_wrC;
reg sau1_wrA, sau1_wrB, sau1_wrC;
reg fpu0_wrA, fpu0_wrB, fpu0_wrC;
reg fma0_wrA, fma1_wrA;
reg dram_wr0;
reg dram_wr1;
reg wt0A,wt1A,wt2A,wt4A,wt5A;
reg wt7A,wt8A,wt9A,wt10A,wt11A,wt12A;

// Do not update the register file if the architectural register is zero.
// A dud rename register is used for architectural register zero, and it
// should not be updated. The register file bypasses physical 
// register zero to zero.

// There are some pipeline delays to account for.
pregno_t sau0_pRdA2, sau0_pRdB2, sau0_pRdC2;
pregno_t sau1_pRdA2, sau1_pRdB2, sau1_pRdC2;
pregno_t imul0_pRdA2;
pregno_t fpu0_pRdA2, fpu0_pRdB2, fpu0_pRdC2;
pregno_t fpu1_pRdA2, fpu1_pRdB2, fpu1_pRdC2;
pregno_t sau0_Rt2, fpu0_Rt3, fpu1_Rt3, imul0_Rt2;
aregno_t sau0_aRdA2, fpu0_aRd3, fpu1_aRd3, imul0_aRdA2;
aregno_t sau1_aRdA2;
pregno_t sau1_Rt2;
aregno_t sau1_aRd2;
value_t sau0_resA2,sau1_resA2;
value_t fpu0_res3, fpu0_resA2;
value_t fpu1_resA2;
checkpt_ndx_t sau0_cp2, sau1_cp2, fpu0_cp2, fpu1_cp2, imul0_cp2;
wire sau0_aRdv1, sau0_aRdv2, sau1_aRdv1, sau1_aRdv2, fpu0_aRdv2;
rob_ndx_t sau0_id2, sau1_id2, fpu0_id2, imul0_id2;
Qupls4_pkg::operating_mode_t fpu0_om2, dram0_om2, dram1_om2;
Qupls4_pkg::operating_mode_t sau0_omA2, sau1_omA2, fpu0_omA2, fpu1_omA2, dram0_omA2, dram1_omA2, imul0_omA2;
Qupls4_pkg::operating_mode_t sau0_omB2, sau1_omB2, fpu0_omB2, fpu1_omB2, dram0_omB2, dram1_omB2;
Qupls4_pkg::operating_mode_t sau0_omC2, sau1_omC2, fpu0_omC2, fpu1_omC2;

// ALU #0 signals

vtdl #(1) 							udlyal5 (.clk(clk), .ce(1'b1), .a(4'd0), .d(sau0_sc_done), .q(sau0_sc_done2) );
vtdl #($bits(rob_ndx_t))	udlyal6 (.clk(clk), .ce(1'b1), .a(4'd0), .d(sau0_id), .q(sau0_id2) );
vtdl #($bits(checkpt_ndx_t)) udlyal7 (.clk(clk), .ce(1'b1), .a(4'd0), .d(sau0_cp), .q(sau0_cp2) );

// ALU #1 signals

vtdl #(1) 							udlyal15 (.clk(clk), .ce(1'b1), .a(4'd0), .d(sau1_sc_done), .q(sau1_sc_done2) );
vtdl #($bits(rob_ndx_t))	udlyal16 (.clk(clk), .ce(1'b1), .a(4'd0), .d(sau1_id), .q(sau1_id2) );
vtdl #($bits(checkpt_ndx_t)) udlyal17 (.clk(clk), .ce(1'b1), .a(4'd0), .d(sau1_cp), .q(sau1_cp2) );

//vtdl #($bits(value_t))  udlyal4 (.clk(clk), .ce(1'b1), .a(4'd0), .d(sau0_resA), .q(sau0_res2) );
// FPU #0 signals

vtdl #(1) 							udlyfp5 (.clk(clk), .ce(1'b1), .a(4'd0), .d(fpu0_sc_done), .q(fpu0_sc_done2) );
vtdl #($bits(rob_ndx_t))	udlyfp6 (.clk(clk), .ce(1'b1), .a(4'd0), .d(fpu0_id), .q(fpu0_id2) );
vtdl #($bits(checkpt_ndx_t)) udlyfp7 (.clk(clk), .ce(1'b1), .a(4'd0), .d(fpu0_cp), .q(fpu0_cp2) );
vtdl #($bits(Qupls4_pkg::operating_mode_t))	udlyfp8 (.clk(clk), .ce(1'b1), .a(4'd0), .d(fpu0_om), .q(fpu0_om2) );


// Compute write enable.
// When the unit is finished, and it is not architectural register zero.
always_comb fpu0_wrA = !fpu0_rse2.aRdv && Qupls4_pkg::NFPU > 0;
always_comb fma0_wrA = fma0_done && !fma0_rse2.aRdv && Qupls4_pkg::NFPU > 0;
always_comb fma1_wrA = fma1_done && !fma1_rse2.aRdv && Qupls4_pkg::NFPU > 1;
always_comb dram_wr0 = dram0_oper.oper.v && dram0_oper.oper.aRnv;
always_comb dram_wr1 = dram1_oper.oper.v && dram1_oper.oper.aRnv && Qupls4_pkg::NDATA_PORTS > 1;
always_comb fcu_wrA = 1'b0;

wire [8:0] sau0_we;
wire [8:0] sau1_we;
wire [8:0] fpu0_we;
wire [8:0] fpu1_we;
reg [8:0] dram0_we;
reg [8:0] dram1_we;
wire [8:0] fcu_we;

always_ff @(posedge clk) dram0_we = {wt10A,8'hFF} & {9{dram_wr0}};
always_ff @(posedge clk) dram1_we = {wt11A,8'hFF} & {9{dram_wr1}} & {9{Qupls4_pkg::NDATA_PORTS > 1}};

always_comb wt0A = !sau0_rse2.aRdv;
always_comb wt1A = !sau1_rse2.aRdv && Qupls4_pkg::NSAU > 1;
always_comb wt7A = fcu_done && !fcu_aRtzA;
always_comb wt10A = dram0_oper.oper.v && dram0_oper.oper.aRnv;
always_comb wt11A = dram1_oper.oper.v && dram1_oper.oper.aRnv && Qupls4_pkg::NDATA_PORTS > 1;
always_comb wt12A = !fpu0_rse2.aRdv && !fpu0_idle && Qupls4_pkg::NFPU > 0;


// Functional unit result queues management variables.
reg [12:0] fuq_empty;
wire [4:0] frq_upd [0:MWIDTH-1];
reg [12:0] fuq_rd;
wire [8:0] fuq_we [0:12];
pregno_t [12:0] fuq_pRt;
aregno_t [12:0] fuq_aRt;
wire [7:0] fuq_tag [0:12];
value_t [12:0] fuq_res;
cpu_types_pkg::checkpt_ndx_t fuq_cp [0:12];

// Look for queues containing values, and select from a queue using a rotating selector.
Qupls4_frq_select
#(
	.NFRQ(14),
	.NWRITE_PORTS(NREG_WPORTS)
)
ufrqsel1
(
	.rst(irst),
	.clk(clk),
	.frq_empty(fuq_empty),
	.upd(frq_upd),
	.upd_bitmap(fuq_rd)
);

// Read the next queue entry for the queue just used to update the register file.

// Queue the outputs of the functional units.
// Results that have been stomped on are not queued.

Qupls4_func_result_queue ufrq1
(
	.rst_i(irst),
	.clk_i(clk),
	.rd_i(fuq_rd[0]),
	.we_i(sau0_we),
	.rse_i(sau0_rse2),
	.tag_i(sau0_rse2.arg[3].flags),
	.res_i(sau0_resA),
	.we_o(fuq_we[0]),
	.pRt_o(fuq_pRt[0]),
	.aRt_o(fuq_aRt[0]),
	.tag_o(fuq_tag[0]),
	.res_o(fuq_res[0]),
	.cp_o(fuq_cp[0]),
	.empty(fuq_empty[0]),
	.full(sau0_full)
);

generate begin : gSAU1q
	if (Qupls4_pkg::NSAU > 1) begin
Qupls4_func_result_queue ufrq4
(
	.rst_i(irst),
	.clk_i(clk),
	.rd_i(fuq_rd[1]),
	.we_i(sau1_we),
	.rse_i(sau1_rse2),
	.tag_i(sau1_rse2.arg[3].flags),
	.res_i(sau1_resA),
	.we_o(fuq_we[1]),
	.pRt_o(fuq_pRt[1]),
	.aRt_o(fuq_aRt[1]),
	.tag_o(fuq_tag[1]),
	.res_o(fuq_res[1]),
	.cp_o(fuq_cp[1]),
	.empty(fuq_empty[1]),
	.full(sau1_full)
);
end
else begin
	assign fuq_we[1] = 9'd0;
	assign fuq_pRt[1] = 8'd0;
	assign fuq_aRt[1] = 7'd0;
	assign fuq_tag[1] = 8'b0;
	assign fuq_res[1] = 64'd0;
	assign fuq_cp[1] = 4'd0;
	assign fuq_empty[1] = 1'b1;
end
end
endgenerate

// IMUL
// When doing a multiply we know the result will not be a capability, so the
// tag is simply defaulted to zero.

Qupls4_func_result_queue ufrq2
(
	.rst_i(irst),
	.clk_i(clk),
	.rd_i(fuq_rd[2]),
	.we_i(imul0_we),
	.rse_i(imul0_rse2),
	.tag_i(8'h0),
	.res_i(imul0_res),
	.we_o(fuq_we[2]),
	.pRt_o(fuq_pRt[2]),
	.aRt_o(fuq_aRt[2]),
	.tag_o(fuq_tag[2]),
	.res_o(fuq_res[2]),
	.cp_o(fuq_cp[2]),
	.empty(fuq_empty[2]),
	.full(imul0_full)
);

// IDIV
// When doing a divide we know the result will not be a capability, so the
// tag is simply defaulted to zero.
generate begin : gDivFRQ
if (Qupls4_pkg::SUPPORT_IDIV) begin
Qupls4_func_result_queue ufrq3
(
	.rst_i(irst),
	.clk_i(clk),
	.rd_i(fuq_rd[3]),
	.we_i(idiv0_we),
	.rse_i(idiv0_rse2),
	.tag_i(8'h00),
	.res_i(idiv0_res),
	.we_o(fuq_we[3]),
	.pRt_o(fuq_pRt[3]),
	.aRt_o(fuq_aRt[3]),
	.tag_o(fuq_tag[3]),
	.res_o(fuq_res[3]),
	.cp_o(fuq_cp[3]),
	.empty(fuq_empty[3]),
	.full(idiv0_full)
);
end
else begin
	assign fuq_we[3] = 9'd0;
	assign fuq_pRt[3] = 8'd0;
	assign fuq_aRt[3] = 7'd0;
	assign fuq_tag[3] = 8'b0;
	assign fuq_res[3] = 64'd0;
	assign fuq_cp[3] = 4'd0;
	assign fuq_empty[3] = 1'b1;
end
end
endgenerate

// When doing a multiply we know the result will not be a capability, so the
// tag is simply defaulted to zero.

generate begin : gFMAFRQ
if (Qupls4_pkg::NFMA > 0) begin
Qupls4_func_result_queue ufrq4
(
	.rst_i(irst),
	.clk_i(clk),
	.rd_i(fuq_rd[4]),
	.we_i(fma0_we),
	.rse_i(fma0_rse2),
	.tag_i(8'h00),
	.res_i(fma0_res),
	.we_o(fuq_we[4]),
	.pRt_o(fuq_pRt[4]),
	.aRt_o(fuq_aRt[4]),
	.tag_o(fuq_tag[4]),
	.res_o(fuq_res[4]),
	.cp_o(fuq_cp[4]),
	.empty(fuq_empty[4]),
	.full(fma0_full)
);
end
else begin
	assign fuq_we[4] = 9'd0;
	assign fuq_pRt[4] = 8'd0;
	assign fuq_aRt[4] = 7'd0;
	assign fuq_tag[4] = 8'b0;
	assign fuq_res[4] = 64'd0;
	assign fuq_cp[4] = 4'd0;
	assign fuq_empty[4] = 1'b1;
end
if (Qupls4_pkg::NFMA > 1) begin
Qupls4_func_result_queue ufrq5
(
	.rst_i(irst),
	.clk_i(clk),
	.rd_i(fuq_rd[5]),
	.we_i(fma1_we),
	.rse_i(fma1_rse2),
	.tag_i(8'h00),
	.res_i(fma1_res),
	.we_o(fuq_we[5]),
	.pRt_o(fuq_pRt[5]),
	.aRt_o(fuq_aRt[5]),
	.tag_o(fuq_tag[5]),
	.res_o(fuq_res[5]),
	.cp_o(fuq_cp[5]),
	.empty(fuq_empty[5]),
	.full(fma1_full)
);
end
else begin
	assign fuq_we[5] = 9'd0;
	assign fuq_pRt[5] = 8'd0;
	assign fuq_aRt[5] = 7'd0;
	assign fuq_tag[5] = 8'b0;
	assign fuq_res[5] = 64'd0;
	assign fuq_cp[5] = 4'd0;
	assign fuq_empty[5] = 1'b1;
end
end
endgenerate

Qupls4_func_result_queue ufrq7
(
	.rst_i(irst),
	.clk_i(clk),
	.rd_i(fuq_rd[7]),
	.we_i(fcu_we),
	.rse_i(fcu_rse2),
	.tag_i({8'd0}),
	.res_i(fcu_res),//rse.arg[0].val),//resA2),
	.we_o(fuq_we[7]),
	.pRt_o(fuq_pRt[7]),
	.aRt_o(fuq_aRt[7]),
	.tag_o(fuq_tag[7]),
	.res_o(fuq_res[7]),
	.cp_o(fuq_cp[7]),
	.empty(fuq_empty[7]),
	.full(fcu_full)
);

Qupls4_pkg::reservation_station_entry_t dram0_rse;
always_comb
begin
	dram0_rse.aRd = dram0_oper.oper.aRn;
	dram0_rse.nRd = dram0_oper.oper.pRn;
	dram0_rse.rndx = dram0_oper.rndx;
	dram0_rse.cndx = dram0_oper.cndx;
end

Qupls4_pkg::reservation_station_entry_t dram1_rse;
always_comb
begin
	dram1_rse.aRd = dram1_oper.oper.aRn;
	dram1_rse.nRd = dram1_oper.oper.pRn;
	dram1_rse.rndx = dram1_oper.rndx;
	dram1_rse.cndx = dram1_oper.cndx;
end

wire dram0_full, dram1_full;

Qupls4_func_result_queue ufrq10
(
	.rst_i(irst),
	.clk_i(clk),
	.rd_i(fuq_rd[10]),
	.we_i(dram0_we & {9{dram0_oper.oper.v & dram0_oper.state==2'b11}}),
	.rse_i(dram0_rse),
	.tag_i(dram0_oper.oper.flags),
	.res_i(dram0_oper.oper.val),
	.we_o(fuq_we[10]),
	.pRt_o(fuq_pRt[10]),
	.aRt_o(fuq_aRt[10]),
	.tag_o(fuq_tag[10]),
	.res_o(fuq_res[10]),
	.cp_o(fuq_cp[10]),
	.empty(fuq_empty[10]),
	.full(dram0_full)
);

generate begin : gDRAM1q
	if (Qupls4_pkg::NDATA_PORTS > 1) begin
Qupls4_func_result_queue ufrq11
(
	.rst_i(irst),
	.clk_i(clk),
	.rd_i(fuq_rd[11]),
	.we_i(dram1_we & {9{dram1_oper.oper.v & dram1_oper.state==2'b11}}),
	.rse_i(dram1_rse),
	.tag_i(dram1_oper.oper.flags),
	.res_i(dram1_oper.oper.val),
	.we_o(fuq_we[11]),
	.pRt_o(fuq_pRt[11]),
	.aRt_o(fuq_aRt[11]),
	.tag_o(fuq_tag[11]),
	.res_o(fuq_res[11]),
	.cp_o(fuq_cp[11]),
	.empty(fuq_empty[11]),
	.full(dram1_full)
);
end
else begin
	assign fuq_we[11] = 9'd0;
	assign fuq_pRt[11] = 8'd0;
	assign fuq_aRt[11] = 7'd0;
	assign fuq_tag[11] = 8'b0;
	assign fuq_res[11] = 64'd0;
	assign fuq_cp[11] = 4'd0;
	assign fuq_empty[11] = 1'b1;
end
end
endgenerate

// When doing floating-point we know the result will not be a capability, so
// the tag is simply defaulted to zero.
generate begin : gFPU0q
	if (Qupls4_pkg::NFPU > 0) begin
Qupls4_func_result_queue ufrq12
(
	.rst_i(irst),
	.clk_i(clk),
	.rd_i(fuq_rd[12]),
	.we_i(fpu0_we),
	.rse_i(fpu0_rse2),
	.tag_i(8'd0),
	.res_i(fpu0_resA),
	.we_o(fuq_we[12]),
	.pRt_o(fuq_pRt[12]),
	.aRt_o(fuq_aRt[12]),
	.tag_o(fuq_tag[12]),
	.res_o(fuq_res[12]),
	.cp_o(fuq_cp[12]),
	.empty(fuq_empty[12]),
	.full(fpu0_full)
);
end
else begin
	assign fuq_we[12] = 9'd0;
	assign fuq_pRt[12] = 8'd0;
	assign fuq_aRt[12] = 7'd0;
	assign fuq_tag[12] = 8'b0;
	assign fuq_res[12] = 64'd0;
	assign fuq_cp[12] = 4'd0;
	assign fuq_empty[12] = 1'b1;
end
end
endgenerate


// Mux the queue outputs onto the register file inputs.
generate begin : gWrPort
	for (g = 0; g < $size(wrport0_v); g = g + 1) begin
		always_ff @(posedge clk) wrport0_v[g] <= !fuq_empty[frq_upd[g]];
		always_ff @(posedge clk) wrport0_we[g] <= fuq_we[frq_upd[g]]; 
		always_ff @(posedge clk) wrport0_Rt[g] <= fuq_pRt[frq_upd[g]]; 
		always_ff @(posedge clk) wrport0_aRt[g] <= fuq_aRt[frq_upd[g]]; 
		always_ff @(posedge clk) wrport0_res[g] <= fuq_res[frq_upd[g]]; 
		always_ff @(posedge clk) wrport0_cp[g] <= fuq_cp[frq_upd[g]]; 
		always_ff @(posedge clk) wrport0_tag[g] <= fuq_tag[frq_upd[g]]; 
	end
end 
endgenerate

Qupls4_regfileMwNr #(.RPORTS(NREG_RPORTS), .WPORTS(NREG_WPORTS)) urf1 (
	.rst(irst),
	.clk(clk), 
	.wr(wrport0_v),
	.we(wrport0_we),
	.wa(wrport0_Rt),
	.i(wrport0_res),
	.ti(wrport0_tag),
	.ra(prn),
	.rav(prnv),
	.o(rfo),
	.to(rfo_flags),
	.rao(rf_rego),
	.ravo(rf_regvo)
);

always_ff @(posedge clk)
begin
	for (n44 = 0; n44 < NREG_WPORTS; n44 = n44 + 1)
		$display("wr%d:%d Rt=%d/%d res=%x",// sc_done=%d Rtz2=%d",
			n44[2:0], wrport0_v[n44], wrport0_aRt[n44], wrport0_Rt[n44], wrport0_res[n44]);//, sau0_sc_done2[n44], sau0_aRdv2[n44]);
end

Qupls4_copydst ucpydst1
(
	.rst(irst),
	.clk(clk),
	.rob(rob),
	.fcu_branch_resolved(fcu_branch_resolved),
	.fcu_idv(fcu_rser.v),
	.fcu_id(fcu_rser.rndx),
	.skip_list(fcu_skip_list),
	.takb(takb),
	.stomp(robentry_stomp),
	.unavail_list(unavail_list),
	.copydst(robentry_cpydst)
);

// Calc the location of the ROB tail pointer after a stomp.
Qupls4_stail ustail1
(
	.head0(head[0]),
	.tail0(tails[0]),
	.robentry_stomp(robentry_stomp),
	.rob(rob),
	.stail(stail)
);

pc_address_t tpc;
always_comb
	tpc = fcu_pc + 4'd6;

Qupls4_branchmiss_pc umisspc1
(
	.clk(clk),
	.rse(fcu_rse),
	.pc_stack(pc_stack),
	.takb(takb),
	.misspc(fcu_misspc1),
	.vector(irq_in.vector),
	.syscall_vector(syscall_vectors),
	.kernel_vector(kernel_vectors),
	.missgrp(fcu_missgrp),
	.dstpc(tgtpc),
	.kept_stream(kept_stream)
);

always_comb
	fcu_missir <= fcu_instr;

Qupls4_meta_fcu umfcu1
(
	.rst(irst),
	.clk(clk),
	.rse_i(fcu_rse),
	.rse_o(fcu_rse2),
	.sr(sr),
	.ic_irq(ic_irq),
	.irq_sn(irq_sn),
	.takb(takb),
	.res(fcu_res),
	.we_o(fcu_we)
);

/*
Stark_branch_eval ube1
(
	.instr(fcu_instr.ins),
	.a(fcu_argA),
	.b(fcu_argBr),
	.takb(takb)
);
*/
wire cd_fcu_id;
reg takbr1;
reg takbr;
always_ff @(posedge clk) takbr1 <= takb;
always_ff @(posedge clk) if (fcu_new) takbr <= takb;
always_ff @(posedge clk) fcu_rser <= fcu_rse;

always_comb
begin
	fcu_exc = Qupls4_pkg::FLT_NONE;
	// ToDo: fix check
	if (fcu_rse.uop.opcode==Qupls4_pkg::OP_CHK) begin
//		fcu_exc = cause_code_t'(fcu_instr.ins[34:27]);
		fcu_exc = Qupls4_pkg::FLT_NONE;
	end
end

reg branchmiss_det;
always_comb
	branchmiss_det = ((takb && !fcu_rser.bt) || (!takb && fcu_rser.bt)) && fcu_rser.v;

// Branchmiss flag

Qupls4_branchmiss_flag ubmf1
(
	.rse(fcu_rser),
	.miss_det(branchmiss_det),
	.miss_flag(fcu_branchmiss)
);

Qupls4_backout_flag ubkoutf1
(
	.rst(irst),
	.clk(clk),
	.fcu_branch_resolved(fcu_branch_resolved),
	.fcu_rse(fcu_rser),
	.takb(takb),
	.fcu_found_destination(fcu_found_destination),
	.backout(backout)
);

Qupls4_restore_flag urstf1
(
	.rst(irst),
	.clk(clk),
	.fcu_branch_resolved(fcu_branch_resolved),
	.rse(fcu_rser),
	.fcu_found_destination(fcu_found_destination),
	.branchmiss_det(branchmiss_det),
	.restore(restore)
);

// Registering the branch miss signals may allow a second miss directly after
// the first one to occur. We want to process only the first miss. Three in
// a row cannot happen as the stomp signal is active by then.

reg brtgtvr;
always_comb
	branchmiss = irst ? FALSE: (excmiss | fcu_branchmiss);// & ~branchmiss;
always_ff @(posedge clk)
	branchmissd <= branchmiss;

always_ff @(posedge clk)
	missid = irst ? 8'd0 : excmiss ? excid : fcu_rse.rndx;
always_ff @(posedge clk)
	missid_v = irst ? 1'b0 : excmiss ? VAL : fcu_rse.v;


always_ff @(posedge clk)
	case(1'b1)
	excmiss: misspc <= excmisspc;
	default:	misspc <= fcu_misspc1;
	endcase

always_comb
if (irst)
	missgrp <= 5'd0;
else
	missgrp <= excmiss ? excmissgrp : fcu_missgrp;
/*
always_ff @(posedge clk)
if (irst)
	missir <= {26'd0,Qupls4_pkg::OP_NOP};
else begin
//	if (advance_pipeline)
	if (branch_state==Qupls4_pkg::BS_CHKPT_RESTORE)
		missir <= excmiss ? excir : fcu_missir;
end
*/
/*
wire s4s7 = (pc.pc==misspc.pc && ihito && brtgtvr) ||
	(robentry_stomp[fcu_rse.rndx] || (rob[fcu_rse.rndx].out[1] && !rob[fcu_rse.rndx].v))
	;
*/
/*
wire s5s7 = (next_pc.pc==misspc.pc && ihit && (rob[fcu_rse.rndx].done==2'b11 || fcu_idle)) ||
//wire s5s7 = (next_pc==misspc && get_next_pc && ihito && (rob[fcu_rse.rndx].done==2'b11 || fcu_idle)) ||
	(robentry_stomp[fcu_rse.rndx] || 
	(!rob[fcu_rse.rndx].v))
//	(rob[fcu_rse.rndx].out[1] && !rob[fcu_rse.rndx].v))
	;
*/
/*
always_ff @(posedge clk)
if (irst)
	branch_state <= Qupls4_pkg::BS_IDLE;
else begin
//		if (fcu_rndxv && fcu_idle && branch_state==BS_IDLE)
//			branch_state <= 3'd0;
	if (TRUE) begin
		case(branch_state)
		Qupls4_pkg::BS_IDLE:
			if (branchmiss)
				branch_state <= Qupls4_pkg::BS_CHKPT_RESTORE;
		Qupls4_pkg::BS_CHKPT_RESTORE:
			branch_state <= Qupls4_pkg::BS_CHKPT_RESTORED;
		Qupls4_pkg::BS_CHKPT_RESTORED:
		// if (restored)
			branch_state <= Qupls4_pkg::BS_STATE3;
		Qupls4_pkg::BS_STATE3:
			branch_state <= Qupls4_pkg::BS_CAPTURE_MISSPC;
		Qupls4_pkg::BS_CAPTURE_MISSPC:
//			if (s4s7)
//				branch_state <= BS_DONE2;
//			else
				branch_state <= Qupls4_pkg::BS_DONE;
		Qupls4_pkg::BS_DONE:
			if (s5s7)
				branch_state <= Qupls4_pkg::BS_DONE2;
		Qupls4_pkg::BS_DONE2:
			branch_state <= Qupls4_pkg::BS_IDLE;
		default:
			branch_state <= Qupls4_pkg::BS_IDLE;
		endcase
	end
end
*/
/*
always_ff @(posedge clk)
if (irst)
	bs_idle_oh <= TRUE;
else begin
	case(branch_state)
	Qupls4_pkg::BS_IDLE:
		if (branchmiss)
			bs_idle_oh <= FALSE;
	Qupls4_pkg::BS_DONE2:
		bs_idle_oh <= TRUE;
	default:	
		bs_idle_oh <= TRUE;
	endcase
end

always_ff @(posedge clk)
if (irst)
	bs_done_oh <= FALSE;
else begin
	case(branch_state)
	Qupls4_pkg::BS_CAPTURE_MISSPC:
		bs_done_oh <= TRUE;
	Qupls4_pkg::BS_DONE:
		if (s5s7)
			bs_done_oh <= FALSE;
	default:	;
	endcase
end
*/

// ----------------------------------------------------------------------------
// Predicate numbers
// ----------------------------------------------------------------------------
/*
ffz48 uffzprd0 (.i({16'hFFFF,pred_alloc_map}), .o(pred_no[0]));
ffz48 uffzprd1 (.i({16'hFFFF,pred_alloc_map} | (48'd1 << pred_no[0])), .o(pred_no[1]));
ffz48 uffzprd2 (.i({16'hFFFF,pred_alloc_map} | (48'd1 << pred_no[0])| (48'd1 << pred_no[1])), .o(pred_no[2]));
ffz48 uffzprd3 (.i({16'hFFFF,pred_alloc_map} | (48'd1 << pred_no[0])| (48'd1 << pred_no[1])| (48'd1 << pred_no[2])), .o(pred_no[3]));
*/
// ----------------------------------------------------------------------------
// ISSUE stage combo logic
// ----------------------------------------------------------------------------

rob_ndx_t sau0_rndx;
rob_ndx_t sau1_rndx;
rob_ndx_t fpu0_rndx; 
rob_ndx_t fpu1_rndx; 
Qupls4_pkg::lsq_ndx_t mem0_lsndx, mem1_lsndx;
Qupls4_pkg::beb_ndx_t beb_ndx;
wire mem0_lsndxv, mem1_lsndxv;
reg fpu0_rndxv, fpu1_rndxv, fcu_rndxv;
reg sau0_rndxv, sau1_rndxv;
reg agen0_rndxv, agen1_rndxv;
Qupls4_pkg::rob_bitmask_t rob_memissue;
wire [3:0] beb_issue;
wire ratv0_rndxv;
wire ratv1_rndxv;
wire ratv2_rndxv;
wire ratv3_rndxv;
rob_ndx_t ratv0_rndx;
rob_ndx_t ratv1_rndx;
rob_ndx_t ratv2_rndx;
rob_ndx_t ratv3_rndx;

// Convenience names
// ToDo: fix these duplicates
wire agen0_idle = tlb0_v;
wire agen1_idle = tlb1_v;
always_comb
	agen0_id = agen0_rse.rndx;
always_comb
	agen0_idv = agen0_rse.v;
always_comb
	agen0_rndx = agen0_rse.rndx;
always_comb
	agen0_rndxv = agen0_rse.v;
always_comb
	agen1_id = agen1_rse.rndx;
always_comb
	agen1_idv = agen1_rse.v;
always_comb
	sau0_id = sau0_rse.rndx;
always_comb
	sau0_rndx = sau0_rse.rndx;
always_comb
	sau0_rndxv = sau0_rse.v;
always_comb
	sau1_id = sau1_rse.rndx;
always_comb
	sau1_rndx = sau1_rse.rndx;
always_comb
	sau1_rndxv = sau1_rse.v;
always_comb
	fpu0_id = fpu0_rse.rndx;
always_comb
	fpu1_id = fpu1_rse.rndx;
	
/*
Stark_sched uscd1
(
	.rst(irst),
	.clk(clk),
	.sau0_idle(sau0_idle),
	.sau1_idle(Qupls4_pkg::NSAU > 1 ? sau1_idle : 1'd0),
	.fpu0_idle(Qupls4_pkg::NFPU > 0 ? !fpu0_iq_prog_full : 1'd0),
	.fpu1_idle(Qupls4_pkg::NFPU > 1 ? fpu1_idle : 1'd0),
	.fcu_idle(fcu_idle),
	.agen0_idle(agen0_idle1),
	.agen1_idle(1'b0),
	.lsq0_idle(lsq0_idle),
	.lsq1_idle(lsq1_idle),
	.stomp_i(robentry_stomp),
	.robentry_islot_i(robentry_islot),
	.robentry_islot_o(robentry_islot),
	.head(head[0]),
	.rob(rob),
	.robentry_issue(robentry_issue),
	.robentry_fpu_issue(robentry_fpu_issue),
	.robentry_fcu_issue(robentry_fcu_issue),
	.robentry_agen_issue(robentry_agen_issue),
	.sau0_rndx(sau0_rndx),
	.sau0_rndxv(sau0_rndxv),
	.sau1_rndx(sau1_rndx),
	.sau1_rndxv(sau1_rndxv),
	.fpu0_rndx(fpu0_rndx),
	.fpu0_rndxv(fpu0_rndxv),
	.fpu1_rndx(),
	.fpu1_rndxv(),
	.fcu_rndx(fcu_rndx),
	.fcu_rndxv(fcu_rndxv),
	.agen0_rndx(agen0_rndx),
	.agen0_rndxv(agen0_rndxv),
	.agen1_rndx(agen1_rndx),
	.agen1_rndxv(agen1_rndxv),
	.ratv0_rndx(ratv0_rndx),
	.ratv1_rndx(ratv1_rndx),
	.ratv2_rndx(ratv2_rndx),
	.ratv3_rndx(ratv3_rndx),
	.ratv0_rndxv(ratv0_rndxv),
	.ratv1_rndxv(ratv1_rndxv),
	.ratv2_rndxv(ratv2_rndxv),
	.ratv3_rndxv(ratv3_rndxv),
	.cpytgt0(sau0_cpytgt),
	.cpytgt1(sau1_cpytgt),
	.beb_buf(beb_buf),
	.beb_issue(beb_issue)
);
*/
Qupls4_pkg::rob_bitmask_t cpu_request_cancel;

Qupls4_mem_sched umems1
(
	.rst(irst),
	.clk(clk),
	.lsq_head(lsq_head),
	.cancel(cpu_request_cancel),
	.seq_consistency(1'b1),
	.robentry_stomp(robentry_stomp),
	.rob(rob),
	.lsq(lsq),
	.memissue(rob_memissue),
	.ndx0(mem0_lsndx),
	.ndx1(mem1_lsndx),
	.ndx0v(mem0_lsndxv),
	.ndx1v(mem1_lsndxv)
);

assign rs_busy[6] = FALSE;
assign rs_busy[10] = FALSE;
assign rs_busy[11] = FALSE;
assign rs_busy[15:14] = 2'b00;

// Out-of-order dispatch takes input from the ROB and dispatches to the 
// reservation stations.
Qupls4_instruction_dispatcher #(.MWIDTH(MWIDTH), .DISPATCH_COUNT(DISPATCH_WIDTH)) uid1
(
	.rst(irst),
	.clk(clk),
	.stomp(robentry_stomp),
	.pgh(pgh),
	.rob(rob),
	.busy(rs_busy),
	.rse_o(rse),
	.rob_dispatched_o(rob_dispatched)
);
assign stall_dsp = FALSE;

generate begin : gDispatcher
	if (DISPATCH_STRATEGY==0) begin
// In-order dispatch takes input from the pipeline and dispatches to the
// reservations stations.
Qupls4_pipeline_dsp #(.MWIDTH(MWIDTH), .DISPATCH_COUNT(DISPATCH_WIDTH))
udps1
(
	.rst(irst),
	.clk(clk),
	.ce(1'b1),//advance_pipeline), stall_dsp causes a timing loop
	.stomp(robentry_stomp),
	.tail(tails),
	.pg_ren(pg_ren),
	.pg_dsp(pg_dsp),		// not used
	.stall_dsp(stall_dsp),
	.busy(rs_busy),
	.rse_o(rse),
	.rob_dispatched_o(rob_dispatched),
	.rob_dispatched_v_o(rob_dispatched_v)
);
end
end
endgenerate

/*
assign sau0_argA_reg = rob[sau0_rndx].op.pRa;
assign sau0_argB_reg = rob[sau0_rndx].op.pRb;
assign sau0_argC_reg = rob[sau0_rndx].op.pRc;
assign sau0_argM_reg = rob[sau0_rndx].op.pRm;

assign sau1_argA_reg = rob[sau1_rndx].op.pRa;
assign sau1_argB_reg = rob[sau1_rndx].op.pRb;
assign sau1_argC_reg = rob[sau1_rndx].op.pRc;
assign sau1_argM_reg = rob[sau1_rndx].op.pRm;

assign fpu0_argA_reg = rob[fpu0_rndx].op.pRa;
assign fpu0_argB_reg = rob[fpu0_rndx].op.pRb;
assign fpu0_argC_reg = rob[fpu0_rndx].op.pRc;
assign fpu0_argM_reg = rob[fpu0_rndx].op.pRm;

assign fpu1_argA_reg = rob[fpu1_rndx].op.pRa;
assign fpu1_argB_reg = rob[fpu1_rndx].op.pRb;
assign fpu1_argC_reg = rob[fpu1_rndx].op.pRc;
assign fpu1_argM_reg = rob[fpu1_rndx].op.pRm;

assign fcu_argA_reg = rob[fcu_rndx].op.pRa;
assign fcu_argB_reg = rob[fcu_rndx].op.pRb;

assign agen0_argA_reg = rob[agen0_rndx].op.pRa;
assign agen0_argB_reg = rob[agen0_rndx].op.pRb;
assign agen0_argC_reg = rob[agen0_rndx].op.pRc;
assign agen0_argM_reg = rob[agen0_rndx].op.pRm;

assign agen1_argA_reg = rob[agen1_rndx].op.pRa;
assign agen1_argB_reg = rob[agen1_rndx].op.pRb;
assign agen1_argM_reg = rob[agen1_rndx].op.pRm;

assign sau0_argD_reg = rob[sau0_rndx].op.pRt;
assign sau1_argD_reg = rob[sau1_rndx].op.pRt;
assign fpu0_argD_reg = rob[fpu0_rndx].op.pRt;
*/
/*
assign aRs[0] = rob[sau0_rndx].op.decbus.Rs1;
assign aRs[7] = rob[sau0_rndx].op.decbus.Rs2;
assign aRs[3] = rob[sau0_rndx].op.decbus.Rs3;
assign aRs[4] = rob[sau0_rndx].op.decbus.Rd;

assign aRs[1] = rob[sau1_rndx].op.decbus.Rs1;
assign aRs[8] = rob[sau1_rndx].op.decbus.Rs2;
assign aRs[9] = rob[sau1_rndx].op.decbus.Rs3;
assign aRs[10] = rob[sau1_rndx].op.decbus.Rd;

assign aRs[2] = rob[fpu0_rndx].op.decbus.Rs1;
assign aRs[11] = rob[fpu0_rndx].op.decbus.Rs2;
assign aRs[12] = rob[fpu0_rndx].op.decbus.Rs3;
assign aRs[13] = rob[fpu0_rndx].op.decbus.Rd;

assign aRs[3] = rob[fpu1_rndx].op.decbus.Rs1;
assign aRs[14] = rob[fpu1_rndx].op.decbus.Rs2;
assign aRs[15] = rob[fpu1_rndx].op.decbus.Rs3;
assign aRs[16] = rob[fpu1_rndx].op.decbus.Rd;

assign aRs[4] = rob[fcu_rndx].op.decbus.Rs1;
assign aRs[17] = rob[fcu_rndx].op.decbus.Rs2;

assign aRs[5] = rob[agen0_rndx].op.decbus.Rs1;
assign aRs[18] = rob[agen0_rndx].op.decbus.Rs2;
assign aRs[19] = rob[agen0_rndx].op.decbus.Rs3;
assign aRs[20] = rob[agen0_rndx].op.decbus.Rd;

assign aRs[6] = rob[agen1_rndx].op.decbus.Rs1;
assign aRs[21] = rob[agen1_rndx].op.decbus.Rs2;
assign aRs[22] = rob[agen1_rndx].op.decbus.Rs3;
assign aRs[23] = rob[agen1_rndx].op.decbus.Rd;

assign aRs[24] = rob[sau0_rndx].op.decbus.Rci;
assign aRs[25] = rob[sau1_rndx].op.decbus.Rci;

assign aRs[26] = 8'd0;
assign aRs[27] = 8'd0;
assign aRs[28] = 8'd0;
assign aRs[29] = 8'd0;
assign aRs[30] = 8'd0;
assign aRs[31] = 8'd0;
*/

// ----------------------------------------------------------------------------
// EXECUTE stage combo logic
// ----------------------------------------------------------------------------

value_t csr_res;
wire div_dbz;

always_comb
	tReadCSR(csr_res,sau0_argI[15:0]);

Qupls4_meta_sau #(.SAU0(1'b1)) usau0
(
	.rst(irst),
	.clk(clk),
	.rse_i(sau0_rse),
	.rse_o(sau0_rse2),
	.cptgt(sau0_cptgt),
	.z(sau0_predz),
	.stomp(robentry_stomp),
	.csr(csr_res),
	.canary(canary),
	.cpl(sr.pl),
	.qres(fpu0_resH),
	.o(sau0_resA),
	.we_o(sau0_we),
	.exc(sau0_exc)
);

generate begin : gIMul
if (Qupls4_pkg::SUPPORT_IMUL)
	Qupls4_meta_imul uimul0
	(
		.rst(irst),
		.clk(clk),
		.stomp(robentry_stomp),
		.rse_i(imul0_rse),
		.rse_o(imul0_rse2),
		.lane(3'd0),
		.cptgt(imul0_cptgt),
		.z(imul0_predz),
		.o(imul0_res),
		.we_o(imul0_we),
		.mul_done()
	);
else begin
	assign imul0_res2 = {$bits(reservation_station_entry_t){1'b0}};
	assign imul0_we = FALSE;
	assign imul0_res = value_zero;
end
end
endgenerate

wire idiv0_dbz;
wire [63:0] div0_exc;

generate begin : gIDiv
if (Qupls4_pkg::SUPPORT_IDIV)
Qupls4_meta_idiv uidiv0
(
	.rst(irst),
	.clk(clk),
	.clk2x(clk2x_i),
	.ld(idiv0_ld),
	.rse_i(idiv0_rse),
	.rse_o(idiv0_rse2),
	.cptgt(idiv0_cptgt),
	.z(idiv0_predz),
	.o(idiv0_res),
	.we_o(idiv0_we),
	.div_done(idiv0_done),
	.div_dbz(idiv0_dbz),
	.exc(div0_exc),
	.q_rst(q_rst),
	.q_trigger(q_trigger),
	.q_rd(q_rd),
	.q_wr(q_wr),
	.q_addr(q_addr),
	.q_rd_data(q_rd_data),
	.q_wr_data(q_wr_data)
);
else begin
	assign idiv0_done = TRUE;
	assign idiv0_dbz = FALSE;
	assign idiv0_res = value_zero;
	assign q_rst = 16'd0;
	assign q_trigger = 16'd0;
	assign q_rd = 16'd0;
	assign q_wr = 16'd0;
	assign q_addr = 16'd0;
	assign q_wr_data = 64'd0;
end
end
endgenerate

generate begin : gSau1
if (Qupls4_pkg::NSAU > 1) begin
	Qupls4_meta_sau #(.SAU0(1'b0)) usau1
	(
		.rst(irst),
		.clk(clk),
		.rse_i(sau1_rse),
		.rse_o(sau1_rse2),
		.cptgt(sau1_cptgt),
		.z(sau1_predz),
		.stomp(robentry_stomp),
		.csr(14'd0),
		.canary(canary),
		.cpl(sr.pl),
		.qres(64'd0),
		.o(sau1_resA),
		.we_o(sau1_we),
		.exc(sau1_exc)
	);
end
end
endgenerate

//assign sau0_out = sau0_dataready;
//assign sau1_out = sau1_dataready;

//assign  fcu_state1 = fcu_dataready;

generate begin : gFMA
if (Qupls4_pkg::NFMA > 0) begin
	Qupls4_meta_fma umfma1
	(
		.rst(irst),
		.clk(clk),
		.idle(),
		.stomp(robentry_stomp),
		.rse_i(fma0_rse),
		.rse_o(fma0_rse2),
		.z(1'b0),
		.cptgt(8'h00),
		.o(fma0_res),
		.otag(),
		.we_o(fma0_we),
		.done(),
		.exc()
	);
end
else begin
	always_comb
	begin
		fma0_rse2 = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
		fma0_res = value_zero;
	end
end

if (Qupls4_pkg::NFMA > 1) begin
	Qupls4_meta_fma umfma2
	(
		.rst(irst),
		.clk(clk),
		.idle(),
		.stomp(robentry_stomp),
		.rse_i(fma1_rse),
		.rse_o(fma1_rse2),
		.z(1'b0),
		.cptgt(8'h00),
		.o(fma1_res),
		.otag(),
		.we_o(fma1_we),
		.done(),
		.exc()
	);
end
else begin
	always_comb
	begin
		fma1_rse2 = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
		fma1_res = value_zero;
	end
end
end
endgenerate

// ToDo: add result exception 
generate begin : gFpu
if (Qupls4_pkg::NFPU > 0) begin
	if (Qupls4_pkg::SUPPORT_QUAD_PRECISION||Qupls4_pkg::SUPPORT_CAPABILITIES) begin
		Qupls4_meta_fpu #(.WID(128)) ufpu1
		(
			.rst(irst),
			.clk(clk),
			.clk3x(clk3x),
			.rse_i(fpu0_rse),
			.rse_o(fpu0_rse2),
			.idle(fpu0_idle),
			.stomp(robentry_stomp),
			.rm(3'd0),
			.o({fpu0_resH,fpu0_resA}),
			.we_o(fpu0_we),
			.t({sau0_argD,fpu0_argD}),
			.z(fpu0_predz),
			.cptgt(fpu0_cptgt),
			.done(fpu0_done),
			.exc(fpu0_exc)
		);
	end
	else begin
		Qupls4_meta_fpu #(.WID(64)) ufpu1
		(
			.rst(irst),
			.clk(clk),
			.clk3x(clk3x),
			.rse_i(fpu0_rse),
			.rse_o(fpu0_rse2),
			.idle(fpu0_idle),
			.stomp(robentry_stomp),
			.rm(3'd0),
			.z(1'b0),
			.cptgt(fpu0_cptgt),
			.o(fpu0_resA),
			.otag(),
			.we_o(fpu0_we),
			.done(fpu0_done),
			.exc(fpu0_exc)
		);
	end
end
else begin
	assign fpu0_rse = {$bits(reservation_station_entry_t){1'b0}};
end
if (Qupls4_pkg::NFPU > 1) begin
	Qupls4_meta_fpu #(.WID(64)) ufpu2
	(
    .rst(irst),
    .clk(clk),
    .clk3x(clk3x),
		.stomp(robentry_stomp),
    .rse_i(fpu1_rse),
    .rse_o(fpu1_rse2),
    .idle(fpu1_idle),
    .rm(3'd0),
    .z(1'b0),
    .cptgt(fpu1_cptgt),
    .o(fpu1_resA),
		.we_o(fpu1_we),
    .otag(),
    .done(fpu1_done),
    .exc(fpu1_exc)
);
end
else begin
	assign fpu1_rse = {$bits(reservation_station_entry_t){1'b0}};
end
end
endgenerate

// =============================================================================
// MEMORY stage
// =============================================================================

wire agen0_v, agen1_v;
wire dram0_more,dram1_more;
wire tlb_miss;
virtual_address_t tlb_missadr;
asid_t tlb_missasid;
rob_ndx_t tlb_missid;
Qupls4_pkg::ex_instruction_t tlb0_op, tlb1_op;
wire [1:0] tlb_missqn;
wire [31:0] pg_fault;
wire [1:0] pg_faultq;
virtual_address_t ptw_vadr;
physical_address_t ptw_padr;
wire ptw_vv;
wire ptw_pv;
wire page_cross0, page_cross1;

Qupls4_pkg::lsq_ndx_t lsq_heads [0:Qupls4_pkg::LSQ_ENTRIES];

wire dram0_timeout;
wire dram1_timeout;

wire [Qupls4_pkg::NDATA_PORTS-1:0] dcache_load;
wire [Qupls4_pkg::NDATA_PORTS-1:0] dhit2;
reg [Qupls4_pkg::NDATA_PORTS-1:0] dhit;
wire [Qupls4_pkg::NDATA_PORTS-1:0] modified;
wire [1:0] uway [0:Qupls4_pkg::NDATA_PORTS-1];
wb_cmd_request512_t [Qupls4_pkg::NDATA_PORTS-1:0] cpu_request_i;
wb_cmd_request512_t [Qupls4_pkg::NDATA_PORTS-1:0] cpu_request_i2;
wb_cmd_response512_t [Qupls4_pkg::NDATA_PORTS-1:0] cpu_resp_o;
wb_cmd_response512_t [Qupls4_pkg::NDATA_PORTS-1:0] update_data_i;
rob_ndx_t [Qupls4_pkg::NDATA_PORTS-1:0] cpu_request_rndx;

cpu_types_pkg::virtual_address_t [Qupls4_pkg::NDATA_PORTS-1:0] cpu_request_vadr, cpu_request_vadr2;
wire [Qupls4_pkg::NDATA_PORTS-1:0] dump;
wire DCacheLine dump_o[0:Qupls4_pkg::NDATA_PORTS-1];
wire [Qupls4_pkg::NDATA_PORTS-1:0] dump_ack;
wire [Qupls4_pkg::NDATA_PORTS-1:0] dwr;
wire [1:0] dway [0:Qupls4_pkg::NDATA_PORTS-1];

always_comb
if (Qupls4_pkg::SUPPORT_CAPABILITIES) begin
	dhit[0] = dhit2[0] & cap_tag_hit[0];
	if (Qupls4_pkg::NDATA_PORTS > 1) dhit[1] = dhit2[1] & cap_tag_hit[1];
end
else begin
	dhit[0] = dhit2[0];
	if (Qupls4_pkg::NDATA_PORTS > 1) dhit[1] = dhit2[1];
end

Qupls4_lsq ulsq1
(
	.rst(irst),
	.clk(clk),
	.cmd(lsq_cmd),
	.pgh(pgh),
	.rob(rob),
	.lsq(lsq),
	.lsq_tail(lsq_tail)
);

generate begin : gDcache
for (g = 0; g < Qupls4_pkg::NDATA_PORTS; g = g + 1) begin

	always_comb
	begin
//		cpu_request_i[g].cid = g + 1;
		cpu_request_rndx[g] = dramN_id[g];
		cpu_request_i[g].tid = dramN_tid[g];
		cpu_request_i[g].om = wishbone_pkg::MACHINE;
		case(1'b1)
		dramN_store[g]:	cpu_request_i[g].cmd = wishbone_pkg::CMD_STORE;
		dramN_cstore[g]:	cpu_request_i[g].cmd = wishbone_pkg::CMD_STORE;
		dramN_stptr[g]:	cpu_request_i[g].cmd = wishbone_pkg::CMD_STORE;
		dramN_vstore[g]:	cpu_request_i[g].cmd = wishbone_pkg::CMD_STORE;
		dramN_vstore_ndx[g]:	cpu_request_i[g].cmd = wishbone_pkg::CMD_STORE;
		dramN_loadz[g]:	cpu_request_i[g].cmd = wishbone_pkg::CMD_LOADZ;
		dramN_load[g]:	cpu_request_i[g].cmd = wishbone_pkg::CMD_LOAD;
		dramN_vload[g]:	cpu_request_i[g].cmd = wishbone_pkg::CMD_LOAD;
		dramN_vload_ndx[g]:	cpu_request_i[g].cmd = wishbone_pkg::CMD_LOAD;
		dramN_cload[g]:	cpu_request_i[g].cmd = wishbone_pkg::CMD_LOAD;
		dramN_cload_tags[g]:	cpu_request_i[g].cmd = wishbone_pkg::CMD_LOAD;
		default:	cpu_request_i[g].cmd = wishbone_pkg::CMD_NONE;
		endcase
		cpu_request_i[g].bte = wishbone_pkg::LINEAR;
		cpu_request_i[g].cti = (dramN_erc[g] || ERC) ? wishbone_pkg::ERC : wishbone_pkg::CLASSIC;
		cpu_request_i[g].blen = 6'd0;
		cpu_request_i[g].seg = wishbone_pkg::DATA;
//		cpu_request_i[g].asid = asid;
		cpu_request_i[g].cyc = dramN[g]==Qupls4_pkg::DRAMSLOT_READY;
//		cpu_request_i[g].stb = dramN[g]==DRAMSLOT_READY;
		cpu_request_i[g].we = dramN_store[g];
//		cpu_request_i[g].vadr = dramN_vaddr[g];
    cpu_request_vadr[g] <= dramN_vaddr[g];
    cpu_request_i[g].pv = 1'b0;
		cpu_request_i[g].adr = dramN_paddr[g];
		cpu_request_i[g].sz = wishbone_pkg::wb_size_t'(dramN_memsz[g]);
		cpu_request_i[g].dat = dramN_data[g];
		cpu_request_i[g].sel = dramN_sel[g];
		cpu_request_i[g].pl = 8'h00;
		cpu_request_i[g].pri = 4'd7;
		if (dramN_load[g]|dramN_cload[g]|dramN_cload_tags|dramN_vload[g]|dramN_vload_ndx[g]) begin
			cpu_request_i[g].cache = wishbone_pkg::WT_READ_ALLOCATE;
			dramN_ack[g] = cpu_resp_o[g].ack & ~cpu_resp_o[g].rty;
		end
		else begin
			cpu_request_i[g].cache = wishbone_pkg::WT_NO_ALLOCATE;
			dramN_ack[g] = cpu_resp_o[g].ack;
		end
	end

	dcache
	#(.CORENO(CORENO), .CHANNEL(g+1))
	udc1
	(
		.rst(irst),
		.clk(clk),
		.dce(1'b1),
		.snoop_adr(snoop_adr),
		.snoop_v(snoop_v),
		.snoop_cid(snoop_cid),
		.cache_load(dcache_load[g]),
		.hit(dhit2[g]),
		.modified(modified[g]),
		.uway(uway[g]),
		.cpu_req_i(cpu_request_i2[g]),
		.cpu_resp_o(cpu_resp_o[g]),
		.cpu_req_vadr(cpu_request_vadr2[g]),
		.update_data_i(update_data_i[g]),
		.dump(dump[g]),
		.dump_o(dump_o[g]),
		.dump_ack_i(dump_ack[g]),
		.wr(dwr[g]),
		.way(dway[g]),
		.invce(invce),
		.dc_invline(dc_invline),
		.dc_invall(dc_invall)
	);

	dcache_ctrl
	#(.CORENO(CORENO), .CHANNEL(g+1))
	udcctrl1
	(
		.rst_i(irst),
		.clk_i(clk),
		.dce(1'b1),
		.ftam_req(ftadm_req[g]),
		.ftam_resp(ftadm_resp[g]),
		.ftam_full(ftadm_resp[g].rty),
		.acr(),
		.hit(dhit2[g]),
		.modified(modified[g]),
		.cache_load(dcache_load[g]),
		.cpu_request_cancel(cpu_request_cancel),
		.cpu_request_rndx(cpu_request_rndx[g]),
		.cpu_request_i(cpu_request_i[g]),
		.cpu_request_vadr(cpu_request_vadr[g]),
		.cpu_request_i2(cpu_request_i2[g]),
		.cpu_request_vadr2(cpu_request_vadr2[g]),
		.data_to_cache_o(update_data_i[g]),
		.response_from_cache_i(cpu_resp_o[g]),
		.wr(dwr[g]),
		.uway(uway[g]),
		.way(dway[g]),
		.dump(dump[g]),
		.dump_i(dump_o[g]),
		.dump_ack(dump_ack[g]),
		.snoop_adr(snoop_adr),
		.snoop_v(snoop_v),
		.snoop_cid(snoop_cid)
	);

	cap_cache ucapcache1
	(
		.rst(irst),
		.clk(clk),
		.wr(dramN_store[g]),
		.wr_tag(dramN_cstore[g]),
		.adr(dramN_paddr[g]),
		.hit(cap_tag_hit[g]),
		.tagi(dramN_ctago[g]),
		.tago(dramN_ctagi[g]),
		.tagso(dramN_tagsi[g]),
		.req(cap_tag_req[g]),
		.resp(cap_tag_resp[g])
	);

end
if (NDATA_PORTS < 2) begin
	always_comb ftadm_req[1] = {$bits(wb_cmd_request256_t){1'b0}};
	always_comb cap_tag_req[1] = {$bits(wb_cmd_request256_t){1'b0}};
end
end
endgenerate

always_comb
begin
	dramN[0] = dram0;
	dramN_id[0] = dram0_work.rndx;
	dramN_paddr[0] = dram0_work.paddr;
	dramN_vaddr[0] = dram0_work.vaddr;
	dramN_data[0] = dram0_work.data[511:0];
	dramN_ctago[0] = dram0_work.ctag;
	dramN_sel[0] = dram0_work.sel[63:0];
	dramN_store[0] = dram0_work.store;
	dramN_cstore[0] = dram0_work.cstore;
	dramN_stptr[0] = dram0_work.stptr;
	dramN_vstore[0] = dram0_work.vstore;
	dramN_vstore_ndx[0] = dram0_work.vstore_ndx;
	dramN_erc[0] = dram0_work.erc;
	dramN_load[0] = dram0_work.load;
	dramN_loadz[0] = dram0_work.loadz;
	dramN_vload[0] = dram0_work.vload;
	dramN_vload_ndx[0] = dram0_work.vload_ndx;
	dramN_cload[0] = dram0_work.cload;
	dramN_cload_tags[0] = dram0_work.cload_tags;
	dramN_memsz[0] = dram0_work.memsz;
	dramN_tid[0] = dram0_work.tid;
	dram0_ack = dramN_ack[0];
	dram0_ctag = dramN_ctago[0];

	if (Qupls4_pkg::NDATA_PORTS > 1) begin
		dramN[1] = dram1;
		dramN_id[1] = dram1_work.rndx;
		dramN_vaddr[1] = dram1_work.vaddr;
		dramN_paddr[1] = dram1_work.paddr;
		dramN_data[1] = dram1_work.data[511:0];
		dramN_ctago[1] = dram1_work.ctag;
		dramN_sel[1] = dram1_work.sel[63:0];
		dramN_store[1] = dram1_work.store;
		dramN_vstore[1] = dram1_work.vstore;
		dramN_vstore_ndx[1] = dram1_work.vstore_ndx;
		dramN_cstore[1] = dram1_work.cstore;
		dramN_stptr[1] = dram1_work.stptr;
		dramN_erc[1] = dram1_work.erc;
		dramN_load[1] = dram1_work.load;
		dramN_loadz[1] = dram1_work.loadz;
		dramN_vload[1] = dram1_work.vload;
		dramN_vload_ndx[1] = dram1_work.vload_ndx;
		dramN_cload[1] = dram1_work.cload;
		dramN_cload_tags[1] = dram1_work.cload_tags;
		dramN_memsz[1] = dram1_work.memsz;
		dramN_tid[1] = dram1_work.tid;
		dram1_ack = dramN_ack[1];
		dram1_ctag = dramN_ctago[1];
	end
	else
		dram1_ack = 1'b0;
end

always_comb
	stall_tlb0 = (tlb0_v && lsq[lsq_tail.row][lsq_tail.col]==VAL);
always_comb
	stall_tlb1 = (tlb1_v && lsq[lsq_tail.row][lsq_tail.col]==VAL);

/*
reg in_loadq0, in_storeq0;
reg in_loadq1, in_storeq1;
always_comb
begin
	in_loadq0 = 1'b0;
	in_storeq0 = 1'b0;
	in_loadq1 = 1'b0;
	in_storeq1 = 1'b0;
	for (n5 = 0; n5 < 8; n5 = n5 + 1) begin
		if (loadq[n5].sn==tlb0_sn) in_loadq0 = 1'b1;
		if (loadq[n5].sn==tlb1_sn) in_loadq1 = 1'b1;
		if (storeq[n5].sn==tlb0_sn) in_storeq0 = 1'b1;
		if (storeq[n5].sn==tlb1_sn) in_storeq1 = 1'b1;
	end
end
*/
always_ff @(posedge clk)
	agen0_load_store <=
		rob[agen0_rndx].op.decbus.load|
		rob[agen0_rndx].op.decbus.vload|
		rob[agen0_rndx].op.decbus.store|
		rob[agen0_rndx].op.decbus.vstore
		;
always_ff @(posedge clk)
	agen1_load_store <=
	 	rob[agen1_rndx].op.decbus.load|
		rob[agen1_rndx].op.decbus.vload|
		rob[agen1_rndx].op.decbus.store|
		rob[agen1_rndx].op.decbus.vstore
		;
always_ff @(posedge clk)
	agen0_vlsndx <=
		rob[agen0_rndx].op.decbus.vload_ndx|
		rob[agen0_rndx].op.decbus.vstore_ndx
		;
always_ff @(posedge clk)
	agen1_vlsndx <=
		rob[agen1_rndx].op.decbus.vload_ndx|
		rob[agen1_rndx].op.decbus.vstore_ndx
		;

Qupls4_agen uag0
(
	.rst(irst),
	.clk(clk),
	.rse_i(agen0_rse),
	.rse_o(agen0_rse2),
	.out(rob[agen0_id].out[0]),
	.tlb_v(tlb0_v),
	.page_fault(|pg_fault),
	.page_fault_v(pg_faultq==2'd0),
	.load_store(agen0_load_store),
	.vlsndx(agen0_vlsndx),
	.amo(agen0_amo),
	.res(agen0_res),
	.resv(agen0_v)
);

Qupls4_agen uag1
(
	.rst(irst),
	.clk(clk),
	.rse_i(agen1_rse),
	.rse_o(agen1_rse2),
	.out(rob[agen1_id].out[0]),
	.tlb_v(tlb1_v),
	.page_fault(|pg_fault),
	.page_fault_v(pg_faultq==2'd1),
	.load_store(agen1_load_store),
	.vlsndx(agen1_vlsndx),
	.amo(agen1_amo),
	.res(agen1_res),
	.resv(agen1_v)
);

reg cantlsq0, cantlsq1;
always_comb
begin
	cantlsq0 = 1'b0;
	cantlsq1 = 1'b0;
	foreach (rob[n11]) begin
		if (rob[n11].op.decbus.mem && rob[n11].sn < rob[agen0_id].sn && !rob[n11].lsq)
			cantlsq0 = 1'b1;
		if (rob[n11].op.decbus.mem && rob[n11].sn < rob[agen1_id].sn && !rob[n11].lsq)
			cantlsq1 = 1'b1;
	end
end

// ToDo: assign this to something
Qupls4_pkg::operating_mode_t ic_miss_om;

mmu #(.CORENO(CORENO), .CHANNEL(3)) ummu1
(
	.rst(irst),
	.clk(clk), 
	.paging_en(paging_en),
	.pebble_en(pebble_en),
	.tlb_pmt_base(32'hFFF80000),
	.ic_miss_adr(ic_miss_adr),
	.ic_miss_asid(ic_miss_asid),
	.ic_miss_om(ic_miss_om),
	.vadr_ir(agen0_op.ins),
	.vadr(agen0_res),
	.vadr_v(agen0_v),
	.vadr_asid(asid[0]),
	.vadr_id(agen0_id),
	.vadr_om(agen0_om),
	.vadr_we(agen0_we),
	.vadr2_ir(agen1_op.ins),
	.vadr2(agen1_res),
	.vadr2_v(agen1_v),
	.vadr2_asid(asid[0]),
	.vadr2_id(agen1_id),
	.vadr2_om(agen1_om),
	.vadr2_we(agen1_we),
	.padr(tlb0_res),
	.padr2(),
	.tlb_pc_entry(tlb_pc_entry),
	.tlb0_v(tlb0_v),
	.pc_padr_v(pc_tlb_v),
	.pc_padr(pc_tlb_res),
	.commit0_id(commit0_id),
	.commit0_idv(commit0_idv),
	.commit1_id(commit1_id),
	.commit1_idv(commit1_idv),
	.commit2_id(commit2_id),
	.commit2_idv(commit2_idv),
	.commit3_id(commit3_id),
	.commit3_idv(commit3_idv),
	.ftas_req(fta_req),
	.ftas_resp(ptable_resp),
	.ftam_req(ftatm_req),
	.ftam_resp(ftatm_resp),
	.fault_o(pg_fault),
	.faultq_o(pg_faultq),
	.pe_fault_o()
);


always_comb
begin
	lsq_tail0 = lsq_tail;
	lsq_heads[0] = lsq_head;
	for (n2 = 1; n2 < Qupls4_pkg::LSQ_ENTRIES; n2 = n2 + 1) begin
		lsq_heads[n2].vb = FALSE;
		lsq_heads[n2].row = (lsq_heads[n2-1].row+1) % Qupls4_pkg::LSQ_ENTRIES;
		lsq_heads[n2].col = 0;
	end
end

wire dram0_setready, dram0_setavail;
wire dram1_setready, dram1_setavail;
reg dram0_idv;
reg dram1_idv;
reg dram0_idv2;
reg dram1_idv2;
rob_ndx_t dram0_id;
rob_ndx_t dram1_id;
wire [79:0] dram0_sel;
wire [79:0] dram1_sel;

always_comb
	dram0_id = lsq[mem0_lsndx.row][mem0_lsndx.col].rndx;
always_comb
	dram1_id = lsq[mem1_lsndx.row][mem1_lsndx.col].rndx;
always_comb
	dram0_idv =	mem0_lsndxv && !robentry_stomp[dram0_id] && !dram0_idv2;
always_comb
	dram1_idv =	mem1_lsndxv && !robentry_stomp[dram1_id] && !dram1_idv2 && Qupls4_pkg::NDATA_PORTS > 1;

always_ff @(posedge clk)
if (irst)
	dram0_idv2 <= INV;
else
	dram0_idv2 <= dram0_idv;
always_ff @(posedge clk)
if (irst)
	dram1_idv2 <= INV;
else
	dram1_idv2 <= dram1_idv;

Qupls4_mem_done udrdn1
(
	.rst(irst),
	.clk(clk),
	.load(dram0_work.load|dram0_work.vload|dram0_work.vload_ndx),
	.store(dram0_work.store|dram0_work.vstore|dram0_work.vstore_ndx),
	.cload(dram0_work.cload),
	.cstore(dram0_work.cstore),
	.cload_tags(dram0_work.cload_tags),
	.dram_oper(dram0_oper),
	.dram_idv(dram0_idv),
	.dram_id(dram0_id), 
	.stomp(robentry_stomp),
	.dram_stomp(dram0_stomp),
	.done(dram0_done)
);

function fnVirt2PhysReady;
input Qupls4_pkg::lsq_ndx_t lsndx;
begin
	if (lsq[lsndx.row][lsndx.col].agen==1'b1)
		fnVirt2PhysReady = 1'b1;
	else
		fnVirt2PhysReady = 1'b0;
end
endfunction

Qupls4_mem_timeout_flag umtf0(dram0_work, dram0_timeout);

Qupls4_mem_set_state usms0
(
	.state_i(dram0),
	.lsndxv_i(mem0_lsndxv),
	.idv_i(dram0_idv),
	.setavail_o(dram0_setavail),
	.setready_o(dram0_setready)
);

Qupls4_mem_state udrst0
(
	.rst_i(irst),
	.clk_i(clk),
	.ack_i(dram0_ack),
	.more_i(dram0_more & ~page_cross0),
	.set_ready_i(dram0_setready),
	.set_avail_i(dram0_timeout|dram0_stomp|dram0_setavail),
	.state_o(dram0)
);

Qupls4_mem_more ummore0
(
	.rst_i(irst),
	.clk_i(clk),
	.state_i(dram0),
	.sel_i(dram0_sel),
	.more_o(dram0_more)
);

Qupls4_pkg::lsq_entry_t lsqe0,lsqe1;
always_comb
	lsqe0 = lsq[mem0_lsndx.row][mem0_lsndx.col];
always_comb
	lsqe1 = lsq[mem1_lsndx.row][mem1_lsndx.col];

Qupls4_set_dram_work #(.CORENO(CORENO), .LSQNO(0)) usdr1 (
	.rst_i(irst),
	.clk_i(clk),
	.rob_i(rob),
	.stomp_i(robentry_stomp),
	.lsndxv_i(mem0_lsndxv),
	.dram_state_i(dram0),
//	.dram_done_i(dram0_done),
	.dram_more_i(dram0_more),
	.dram_idv_i(dram0_idv),
	.dram_idv2_i(dram0_idv2),
	.dram_ack_i(dram0_ack),
	.dram_stomp_i(dram0_stomp),
	.cpu_dat_i(cpu_resp_o[0].dat),
	.lsq_i(lsqe0),
	.dram_oper_o(dram0_oper),
	.dram_work_o(dram0_work),
	.page_cross_o(page_cross0),
	.sel_o(dram0_sel)
);

// Modules for second memory port.

generate begin : gMemory2
	if (Qupls4_pkg::NDATA_PORTS > 1) begin

		Qupls4_mem_done udrdn1
		(
			.rst(irst),
			.clk(clk),
			.load(dram1_work.load|dram1_work.vload|dram1_work.vload_ndx),
			.store(dram1_work.store|dram1_work.vstore|dram1_work.vstore_ndx),
			.cload(dram1_work.cload),
			.cstore(dram1_work.cstore),
			.cload_tags(dram1_work.cload_tags),
			.dram_oper(dram1_oper),
			.dram_idv(dram1_idv),
			.dram_id(dram1_id), 
			.stomp(robentry_stomp),
			.dram_stomp(dram1_stomp),
			.done(dram1_done)
		);

		Qupls4_mem_timeout_flag umtf1(dram1_work, dram1_timeout);

		Qupls4_mem_set_state usms1
		(
			.state_i(dram1),
			.lsndxv_i(mem1_lsndxv),
			.idv_i(dram1_idv),
			.setavail_o(dram1_setavail),
			.setready_o(dram1_setready)
		);

		Qupls4_mem_state udrst1
		(
			.rst_i(irst),
			.clk_i(clk),
			.ack_i(dram1_ack),
			.more_i(dram1_more & ~page_cross1),
			.set_ready_i(dram1_setready),
			.set_avail_i(dram1_timeout|dram1_stomp|dram1_setavail),
			.state_o(dram1)
		);

		Qupls4_mem_more ummore1
		(
			.rst_i(irst),
			.clk_i(clk),
			.state_i(dram1),
			.sel_i(dram1_sel),
			.more_o(dram1_more)
		);

		Qupls4_set_dram_work #(.CORENO(CORENO), .LSQNO(1)) usdr2 (
			.rst_i(irst),
			.clk_i(clk),
			.rob_i(rob),
			.stomp_i(robentry_stomp),
			.lsndxv_i(mem1_lsndxv),
			.dram_state_i(dram1),
//			.dram_done_i(dram1_done),
			.dram_more_i(dram1_more),
			.dram_idv_i(dram1_idv),
			.dram_idv2_i(dram1_idv2),
			.dram_ack_i(dram1_ack),
			.dram_stomp_i(dram1_stomp),
			.cpu_dat_i(cpu_resp_o[1].dat),
			.lsq_i(lsqe1),
			.dram_oper_o(dram1_oper),
			.dram_work_o(dram1_work),
			.page_cross_o(page_cross1),
			.sel_o(dram1_sel)
		);

	end
	else begin
		assign dram1_done = TRUE;
		assign dram1_timeout = FALSE;
		assign dram1 = Qupls4_pkg::DRAMSLOT_AVAIL;
		assign dram1_more = FALSE;
		assign dram1_oper = {$bits(dram_oper_t){1'b0}};
		assign dram1_work = {$bits(dram_work_t){1'b0}};
	end
end
endgenerate


// =============================================================================
// Commit stage combo logic
// =============================================================================

Qupls4_pkg::rob_bitmask_t empty_bmp;
reg rob_empty;
always_comb
foreach (rob[n1])
	empty_bmp[n1] = ~|rob[n1].v;
always_comb
	rob_empty = &empty_bmp;


// Figure out how many instructions can be committed.
// If there is an oddball instruction (eg. CSR, RTE) then only commit up until
// the oddball. Also, if there is an exception, commit only up until the 
// exception. Otherwise commit instructions that are not valid or are valid
// and done. Do not commit invalid instructions at the tail of the queue.

always_comb
	if (head[0] > tails[0])
		cmtlen = head[0]-tails[0];
	else
		cmtlen = Qupls4_pkg::ROB_ENTRIES+head[0]-tails[0];

/*
										(
											head[0] == tails[0] || head[0] == tails[1] || head[0] == tails[2] || head[0] == tails[3] ||
											head[0] == tails[4] || head[0] == tails[5] || head[0] == tails[6] || head[0] == tails[7]);
*/
always_comb
	foreach(cmttlb[n51])
		cmttlb[n51] = (|rob[head[n51]].v && rob[head[n51]].lsq && !lsq[rob[head[n51]].lsqndx.row][rob[head[n51]].lsqndx.col].agen);

Qupls4_commit_count
#(.XWID(MWIDTH))
ucmtcnt1
(
	.rst(irst),
	.clk(clk),
	.next_cqd(next_cqd),
	.rob(rob),
	.head0(head[0]),
	.head1(head[1]),
	.head2(head[2]),
	.head3(head[3]),
	.head4(head[4]),
	.head5(head[5]),
	.tails(tails),
	.cmtcnt(cmtcnt),
	.do_commit(do_commit)
);

always_comb
begin
	cmtbr = FALSE;
	for (n52 = 0; n52 < MWIDTH; n52 = n52 + 1)
		cmtbr = cmtbr | (rob[head[n52]].op.decbus.br & rob[head[n52]].v);
	cmtbr = cmtbr & do_commit;
end

always_comb
begin
	int_commit = 1'b0;
	if (|rob[head[0]].v && &rob[head[0]].done && rob[head[0]].op.hwi_level > sr.ipl)//fnIsIrq(rob[head[0]].op.ins))
		int_commit = 1'b1;
	else if (((|rob[head[0]].v && &rob[head[0]].done) || ! (|rob[head[0]].v)) &&
					(|rob[head[1]].v && &rob[head[1]].done && rob[head[1]].op.hwi_level > sr.ipl /*fnIsIrq(rob[head[1]].op.ins*/))
		int_commit = MWIDTH > 1;
	else if (((|rob[head[0]].v && &rob[head[0]].done) || ! (|rob[head[0]].v)) &&
					 ((|rob[head[1]].v && &rob[head[1]].done) || ! (|rob[head[1]].v)) &&
					(|rob[head[2]].v && &rob[head[2]].done && rob[head[2]].op.hwi_level > sr.ipl /*fnIsIrq(rob[head[2]].op.ins*/))
		int_commit = MWIDTH > 2;
	else if (((|rob[head[0]].v && &rob[head[0]].done) || ! (|rob[head[0]].v)) &&
					 ((|rob[head[1]].v && &rob[head[1]].done) || ! (|rob[head[1]].v)) &&
					 ((|rob[head[2]].v && &rob[head[2]].done) || ! (|rob[head[2]].v)) &&
					(|rob[head[3]].v && &rob[head[3]].done && rob[head[3]].op.hwi_level > sr.ipl /*fnIsIrq(rob[head[3]].op.ins*/))
		int_commit = MWIDTH > 3;
end


// Stall for vector load.
wire pe_vec_stall;
edge_det edvs1 (
	.rst(irst),
	.clk(clk),
	.ce(advance_pipeline_seg2),
	.i(|rob[head[0]].v && (rob[head[0]].op.decbus.rex || rob[head[0]].excv)),
	.pe(pe_vec_stall),
	.ne(),
	.ee()
);

always_ff @(posedge clk)
if (irst)
	vec_stall2 <= FALSE;
else
	vec_stall2 <= pe_vec_stall;

reg anyout0;
always_comb
begin
	anyout0 = 1'b0;
	foreach (rob[n30]) begin
		if (rob[n30].out[0])
			anyout0 = 1'b1;
	end
end

// =============================================================================
// =============================================================================
// Registered Logic
// =============================================================================
// =============================================================================

reg load_lsq_argc;

Qupls4_reservation_station #(
	.MWIDTH(MWIDTH),
	.FUNCUNIT(4'd0),
	.NRSE(NRSE_SAU0),
	.NSARG(3),
	.NREG_RPORTS(RS_NREG_RPORTS),
	.RC(0),
	.DISPATCH_MAP(6'b100001),
	.RL_STRATEGY(RL_STRATEGY)
)
usaust0
(
	.rst(irst),
	.clk(clk),
	.available(1'b1),//sau0_available),
	.busy(rs_busy[0]),
	.stall(sau0_full),
	.stomp(robentry_stomp),
	.issue(),//sau0_issue),//robentry_issue[sau0_rndx]),
	.rse_i(rse),
	.rse_o(sau0_rse),
	.rf_oper_i(rf_oper),
	.bypass_i(),
	.wp_oper_tap_i(wp_tap),
	/*
	.arn(arn),
	.prnv(prnv),
	.rfo(rfo),
	.rfo_tag(rfo_tag),
	*/
	.req_pRn(bRs[0]),
	.req_pRnv(bRsv[0])
);

Qupls4_reservation_station #(
	.MWIDTH(MWIDTH),
	.FUNCUNIT(4'd2),
	.NRSE(NRSE_IMUL),
	.NSARG(3),
	.NREG_RPORTS(RS_NREG_RPORTS),
	.RC(0),
	.DISPATCH_MAP(6'b000010),
	.RL_STRATEGY(RL_STRATEGY)
)
uimulst0
(
	.rst(irst),
	.clk(clk),
	.available(imul0_available),
	.busy(rs_busy[2]),
	.stall(imul0_full),
	.stomp(robentry_stomp),
	.issue(),
	.rse_i(rse),
	.rse_o(imul0_rse),
	.rf_oper_i(rf_oper),
	.bypass_i(),
	.wp_oper_tap_i(wp_tap),
	.req_pRn(bRs[2]),
	.req_pRnv(bRsv[2])
);

always_ff @(posedge clk) sau0_ldd <= sau0_ld;

generate begin : gIDivStation
if (Qupls4_pkg::SUPPORT_IDIV)
Qupls4_reservation_station #(
	.MWIDTH(MWIDTH),
	.FUNCUNIT(4'd3),
	.NRSE(NRSE_IDIV),
	.NSARG(2),
	.NREG_RPORTS(RS_NREG_RPORTS),
	.RC(0),
	.DISPATCH_MAP(6'b000010),
	.RL_STRATEGY(RL_STRATEGY)
)
uidivst0
(
	.rst(irst),
	.clk(clk),
	.available(1'b1),
	.busy(rs_busy[3]),
	.stall(!idiv0_done||idiv0_full),
	.stomp(robentry_stomp),
	.issue(idiv0_ld),
	.rse_i(rse),
	.rse_o(idiv0_rse),
	.rf_oper_i(rf_oper),
	.bypass_i(),
	.wp_oper_tap_i(wp_tap),
	.req_pRn(bRs[3]),
	.req_pRnv(bRsv[3])
);
else begin
end
end
endgenerate

generate begin : gSauStation
	if (Qupls4_pkg::NSAU > 1) begin
		Qupls4_reservation_station #(
			.MWIDTH(MWIDTH),
			.FUNCUNIT(4'd1),
			.NRSE(NRSE_SAU),
			.NSARG(3),
			.NREG_RPORTS(RS_NREG_RPORTS),
			.RC(0),
			.DISPATCH_MAP(6'b100001),
			.RL_STRATEGY(RL_STRATEGY)
		)
		usaust1
		(
			.rst(irst),
			.clk(clk),
			.available(sau1_available),
			.busy(rs_busy[1]),
			.stall(sau1_full),
			.stomp(robentry_stomp),
			.issue(),//robentry_issue[sau0_rndx]),
			.rse_i(rse),
			.rse_o(sau1_rse),
			.rf_oper_i(rf_oper),
			.bypass_i(),
			.wp_oper_tap_i(wp_tap),
			.req_pRn(bRs[1]),
			.req_pRnv(bRsv[1])
		);
	end
end
endgenerate

always_ff @(posedge clk) sau1_ldd <= sau1_ld;

wire fpu0_iq_rd_rst_busy, fpu0_iq_wr_rst_busy;
wire fpu0_iq_data_valid;
wire fpu0_iq_underflow;
wire fpu0_iq_wr_en = fpu0_rndxv;
wire fpu0_iq_rd_en = fpu0_idle;

generate begin : gFpuStat
	for (g = 0; g < Qupls4_pkg::NFMA; g = g + 1) begin
		case (g)
		0:
			begin
				Qupls4_reservation_station #(
					.MWIDTH(MWIDTH),
					.FUNCUNIT(4'd4),
					.NRSE(NRSE_FMA),
					.NSARG(3+Qupls4_pkg::SUPPORT_FDP),
					.NREG_RPORTS(RS_NREG_RPORTS),
					.RC(1),
					.DISPATCH_MAP(6'b010000),
					.RL_STRATEGY(RL_STRATEGY)
				)
				ufmast1
				(
					.rst(irst),
					.clk(clk),
					.available(fma0_available),
					.busy(rs_busy[4]),
					.stall(fma0_full),
					.stomp(robentry_stomp),
					.issue(),//robentry_issue[sau0_rndx]),
					.rse_i(rse),
					.rse_o(fma0_rse),
					.rf_oper_i(rf_oper),
					.bypass_i(),
					.wp_oper_tap_i(wp_tap),
					.req_pRn(bRs[4]),
					.req_pRnv(bRsv[4])
				);
				Qupls4_reservation_station #(
					.MWIDTH(MWIDTH),
					.FUNCUNIT(4'd12),
					.NRSE(NRSE_FPU),
					.NSARG(3),
					.NREG_RPORTS(NREG_RPORTS),
					.RC(1),
					.DISPATCH_MAP(6'b010000),
					.RL_STRATEGY(RL_STRATEGY)
				)
				ufpust1
				(
					.rst(irst),
					.clk(clk),
					.available(fpu0_available),
					.busy(rs_busy[5]),
					.stall(fpu0_full),
					.stomp(robentry_stomp),
					.issue(),//robentry_issue[sau0_rndx]),
					.rse_i(rse),
					.rse_o(fpu0_rse),
					.rf_oper_i(rf_oper),
					.bypass_i(),
					.wp_oper_tap_i(wp_tap),
					.req_pRn(bRs[5]),
					.req_pRnv(bRsv[5])
				);
			end
		1:
				Qupls4_reservation_station #(
					.MWIDTH(MWIDTH),
					.FUNCUNIT(4'd5),
					.NRSE(NRSE_FMA),
					.NSARG(3+Qupls4_pkg::SUPPORT_FDP),
					.NREG_RPORTS(RS_NREG_RPORTS),
					.RC(1),
					.DISPATCH_MAP(6'b010000),
					.RL_STRATEGY(RL_STRATEGY)
				)
				ufmast2
				(
					.rst(irst),
					.clk(clk),
					.available(fma1_available),
					.busy(rs_busy[6]),
					.stall(fma1_full),
					.stomp(robentry_stomp),
					.issue(),//robentry_issue[sau0_rndx]),
					.rse_i(rse),
					.rse_o(fma1_rse),
					.rf_oper_i(rf_oper),
					.bypass_i(),
					.wp_oper_tap_i(wp_tap),
					.req_pRn(bRs[6]),
					.req_pRnv(bRsv[6])
				);
		endcase
	end
end
endgenerate

// 0 to 3 = reg read stage
// 4 to 6
// 7 to 10 = reg read stage
// 11 to 13
// 14 to 17 = reg read stage
// 18 to 20
// 21 to 24 = reg read stage
// 25 to 27

generate begin : gDecimalFloat
	if (NDFPU > 0) begin
		Qupls4_pair_reservation_station #(
			.MWIDTH(MWIDTH),
			.FUNCUNIT(4'd13),
			.NRSE(NRSE_DFLT),
			.NSARG(3),
			.NREG_RPORTS(RS_NREG_RPORTS),
			.RC(1),
			.DISPATCH_MAP(6'b010000),
			.RL_STRATEGY(RL_STRATEGY)
		)
		udfpust1
		(
			.rst(irst),
			.clk(clk),
			.available(fpu0_available),
			.busy(rs_busy[7]),
			.stall(dfpu0_full),
			.stomp(robentry_stomp),
			.issue(),//robentry_issue[sau0_rndx]),
			.rse_i(rse),
			.rse_o(dfpu0_rse),
			.rf_oper_i(rf_oper),
			.bypass_i(),
			.wp_oper_tap_i(wp_tap),
			.req_pRn(bRs[7]),
			.req_pRnv(bRsv[7])
		);
	end
end
endgenerate

Qupls4_reservation_station #(
	.MWIDTH(MWIDTH),
	.FUNCUNIT(4'd7),
	.NRSE(NRSE_FCU),
	.NSARG(3),
	.NREG_RPORTS(RS_NREG_RPORTS),
	.RC(0),
	.DISPATCH_MAP(6'b000100),
	.RL_STRATEGY(RL_STRATEGY)
)
ubrast1
(
	.rst(irst),
	.clk(clk),
	.available(1'b1),
	.busy(rs_busy[8]),
	.stall(fcu_full),
	.stomp(robentry_stomp),
	.issue(),//robentry_issue[sau0_rndx]),
	.rse_i(rse),
	.rse_o(fcu_rse),
	.rf_oper_i(rf_oper),
	.bypass_i(),
	.wp_oper_tap_i(wp_tap),
	.req_pRn(bRs[8]),
	.req_pRnv(bRsv[8])
);

Qupls4_reservation_station #(
	.MWIDTH(MWIDTH),
	.FUNCUNIT(4'd8),
	.NRSE(NRSE_AGEN),
	.NSARG(3),
	.NREG_RPORTS(RS_NREG_RPORTS),
	.RC(0),
	.DISPATCH_MAP(6'b001000),
	.RL_STRATEGY(RL_STRATEGY)
)
uagenst1
(
	.rst(irst),
	.clk(clk),
	.available(1'b1),
	.busy(rs_busy[9]),
	.stall(!agen0_idle),
	.stomp(robentry_stomp),
	.issue(),//robentry_issue[sau0_rndx]),
	.rse_i(rse),
	.rse_o(agen0_rse),
	.rf_oper_i(rf_oper),
	.bypass_i(),
	.wp_oper_tap_i(wp_tap),
	.req_pRn(bRs[9]),
	.req_pRnv(bRsv[9])
);

generate begin : gAgen
if (Qupls4_pkg::NDATA_PORTS > 1)
Qupls4_reservation_station #(
	.MWIDTH(MWIDTH),
	.FUNCUNIT(4'd9),
	.NRSE(NRSE_AGEN),
	.NSARG(3),
	.NREG_RPORTS(RS_NREG_RPORTS),
	.RC(0),
	.DISPATCH_MAP(6'b001000),
	.RL_STRATEGY(RL_STRATEGY)
)
uagenst2
(
	.rst(irst),
	.clk(clk),
	.available(1'b1),
	.busy(rs_busy[10]),
	.stall(!agen1_idle),
	.stomp(robentry_stomp),
	.issue(),//robentry_issue[sau0_rndx]),
	.rse_i(rse),
	.rse_o(agen1_rse),
	.rf_oper_i(rf_oper),
	.bypass_i(),
	.wp_oper_tap_i(wp_tap),
	.req_pRn(bRs[10]),
	.req_pRnv(bRsv[10])
);
else begin
	assign agen1_rse = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
end
end
endgenerate

/*
reg fcu_reset_state;
always_comb
	fcu_reset_state = fcu_state1 && rob[fcu_rse.rndx].v && fcu_v3 && !robentry_stomp[fcu_rse.rndx] 
		&& (bs_idle_oh||bs_done_oh||branch_state==Qupls4_pkg::BS_DONE2) && fcu_idv;
*/ 	
always_comb
	dc_get = !(branchmiss)// || (branch_state < Qupls4_pkg::BS_CAPTURE_MISSPC && !bs_idle_oh))
//		&& advance_pipeline
		&& room_for_que
//		&& (!stomp_que || stomp_quem)
		;

always_comb
	agen0_done = agen0_rse.v ? tlb0_v | (|pg_fault && pg_faultq==2'd1) : TRUE;
always_comb
	agen1_done = agen1_rse.v ? tlb1_v | (|pg_fault && pg_faultq==2'd2) : TRUE;

// Validation of the STORE source operand.

Qupls4_pkg::operand_t store_operi, store_opero, store_opero1;
always_comb
begin
	store_operi = {$bits(Qupls4_pkg::operand_t){1'b0}};
	store_operi.v = lsq[lsq_head.row][lsq_head.col].datav;
	store_operi.val = store_opero.val;
	store_operi.flags = 8'h00;
	store_operi.aRn = lsq[lsq_head.row][lsq_head.col].aRc;
	store_operi.pRn = lsq[lsq_head.row][lsq_head.col].pRc;
	store_operi.aRnv = lsq[lsq_head.row][lsq_head.col].v;	// ToDo: fix this detect aRegv
end

// Issue register read request for store operand. The register value will
// appear on the prn bus and be picked up by the register validation module.
Qupls4_lsq_reg_read_req ulrrr1
(
	.rst(irst),
	.clk(clk),
	.lsq_head(lsq_head),
	.lsqe(lsq[lsq_head.row][lsq_head.col]),
	.id(store_argC_id),
	.id1(store_argC_id1),
	.bRs(bRs[11]),
	.bRsv(bRsv[11])
);

Qupls4_validate_operand #(
	.MWIDTH(MWIDTH),
	.RL_STRATEGY(RL_STRATEGY),
	.NENTRY(1)
)
uvLSsrcC
(
	.rf_oper_i(rf_oper),
	.oper_i(store_operi),
	.oper_o(store_opero1),
	.bypass_i({$bits(Qupls4_pkg::operand_t){1'b0}}),
	.wp_hist_i(wp_tap)
);

always_ff @(posedge clk)
	store_opero <= store_opero1;

/*
	.arn(arn),
	.prnv(prnv),
	.rfo(rfo),
	.rfo_tag(rfo_tag),
	.val0(rfo_store_argC),
	.val1(),
	.val2(),
	.val0_tag(rfo_store_argC_tag),
	.val1_tag(),
	.val2_tag(),
	.aRn0(store_argC_aReg),
	.aRn1(8'd0),
	.aRn2(8'd0),
	.valid0_i(lsq[lsq_head.row][lsq_head.col].datav),
	.valid1_i(1'b1),
	.valid2_i(1'b1),
	.valid0_o(rfo_store_argC_valid),
	.valid1_o(),
	.valid2_o()
);
*/

// Compute which streams are in use, so that unused ones may be freed.
always_comb
begin
	used_streams = {XSTREAMS*THREADS{1'b0}};
	used_streams[0] = 1'b1;
	if (THREADS > 1) used_streams[XSTREAMS] = 1'b1;
	if (THREADS > 2) used_streams[XSTREAMS*2] = 1'b1;
	if (THREADS > 3) used_streams[XSTREAMS*3] = 1'b1;
	for (n40 = 0; n40 < Qupls4_pkg::ROB_ENTRIES; n40 = n40 + 1)
		used_streams[rob[n40].ip_stream] = 1'b1;
	foreach(pg_ext.pr[n50]) begin
		used_streams[pg_ext.pr[n50].ip_stream] = 1'b1;
		used_streams[pg_dec.pr[n50].ip_stream] = 1'b1;
		used_streams[pg_ren.pr[n50].ip_stream] = 1'b1;
	end
	foreach (pcs[n40])
		used_streams[pcs[n40].stream[4:0]] = 1'b1;
end

// The outputs should always be qualified with fcu_branch_resolved.
// No condition here to prevent latches.
always_ff @(posedge clk)
//	if (fcu_branch_resolved)
		tGetSkipList(fcu_rse.rndx, fcu_found_destination, fcu_skip_list, fcu_m1, fcu_dst);

reg resolved_takb;
always_ff @(posedge clk)
	resolved_takb <= fcu_branch_resolved && takb;

// ----------------------------------------------------------------------------
// fet/ext/dec/ren/que
// ----------------------------------------------------------------------------
// =============================================================================
// =============================================================================
// Clocked logic
// A lot of ROB updates in this logic.
// =============================================================================
// =============================================================================

always_ff @(posedge clk)
if (irst)
	rstcnt <= 6'd0;
else begin
	if (!rstcnt[5])
		rstcnt <= rstcnt + 2'd1;
end

// =============================================================================
// Pipeline group header updates.
// =============================================================================

reg [7:0] hwi_ndx;

always_ff @(posedge clk)
begin
	if (advance_enqueue) begin
		foreach (pgh[n55])
			pgh[n55].sn <= pgh[n55].sn - 1;
			// Enqeue the group header.
//			pgh[tails[0][5:2]] <= pg_ren.hdr;
			pgh[groupno] <= pg_ren.hdr;
			tEnqueGroupHdr(
				8'h7F,
				groupno,//tails[0],
				pg_ren
			);
	end

	// Set the checkpoint index in the PGH.	
	if (pgh_setcp) begin
		pgh[pgh_setcp_grp].cndx <= cndx;
		pgh[pgh_setcp_grp].cndxv <= VAL;
	end
	if (free_chkpt)
		pgh[freecp_grp].chkpt_freed <= TRUE;
		
end


// =============================================================================
// =============================================================================

always_ff @(posedge clk)
if (irst) begin
	tReset();
	sync_ndx = 6'd63;
	sync_ndxv = INV;
	fc_ndx = 6'd63;
	fc_ndxv = INV;
	lsq_cmd_ndx = 0;
end
else begin

	lsq_cmd_ndx = 8;
	foreach (lsq_cmd[n12])
		lsq_cmd[n12].cmd <= LSQ_CMD_NONE;

	/*
	advance_msi <= FALSE;
	advance_irq_fifo <= FALSE;
	if (takb & ~takb1) begin	// edge on takb
		if (!irq_empty)
			advance_irq_fifo <= TRUE;
		else
			advance_msi <= TRUE;
	end
	*/
	if (sr.ssm & advance_pipeline)
		ssm_flag <= TRUE;

	irq_wr_en <= FALSE;
	if (advance_pipeline && |irq_downcount)
		irq_downcount <= irq_downcount - 2'd1;

	// The reorder buffer is not updated with the argument values. This is done
	// just for debugging in SIM. All values come from the register file.
`ifdef IS_SIM
	if (sau0_available && sau0_issue) begin
		rob[sau0_rse.rndx].argA <= sau0_rse.arg[0].val;
		rob[sau0_rse.rndx].argB <= sau0_rse.arg[1].val;
		rob[sau0_rse.rndx].argT <= sau0_rse.arg[4].val;
	end
	if (Qupls4_pkg::NSAU > 1) begin
		if (sau1_available && sau1_rndxv && sau1_idle) begin
			rob[sau1_rse.rndx].argA <= sau1_rse.arg[0].val;
			rob[sau1_rse.rndx].argB <= sau1_rse.arg[1].val;
			rob[sau1_rse.rndx].argT <= sau1_rse.arg[4].val;
		end
	end
	if (Qupls4_pkg::NFPU > 0) begin
		if (fpu0_available && fpu0_rndxv && fpu0_idle) begin
			rob[fpu0_rndx].argA <= fpu0_rse.arg[0].val;
			rob[fpu0_rndx].argB <= fpu0_rse.arg[1].val;
			rob[fpu0_rndx].argT <= fpu0_rse.arg[4].val;
		end
	end
`endif

	set_pending_ipl <= FALSE;
	cpu_request_cancel <= {Qupls4_pkg::ROB_ENTRIES{1'b0}};
	sau0_done <= FALSE;
	sau1_done <= FALSE;
	if (fpu0_done1)
		fpu0_done1 <= FALSE;
	if (fpu1_done1)
		fpu1_done1 <= FALSE;
	// Fcu op may have been stomped on after issue, so check valid flag.
  if (~hirq) begin
  	if ((pe_allqd|allqd) && !hold_ins && advance_pipeline_seg2)
  		excret <= FALSE;
	end
	sau0_stomp <= FALSE;
	sau1_stomp <= FALSE;
	fpu0_stomp <= FALSE;
	fpu1_stomp <= FALSE;
	dram0_stomp <= FALSE;
	dram1_stomp <= FALSE;

	// This test in sync with PC update
	if (!branchmiss && ihito && !hirq && ((pe_allqd|allqd) && !hold_ins && advance_pipeline_seg2))
		brtgtv <= FALSE;	// PC has been updated

	load_lsq_argc <= FALSE;


// ----------------------------------------------------------------------------
// ENQUEUE
// ----------------------------------------------------------------------------

	// Do not queue while processing a branch miss. Once the queue has been
	// invalidated (state 2), quing new instructions can begin.
	// Only reset the tail if something was stomped on. It could be that there
	// are no valid instructions following the branch in the queue.
	if (branchmiss)// || (branch_state < Qupls4_pkg::BS_CAPTURE_MISSPC && !bs_idle_oh)) begin
		;
//		if (|robentry_stomp)
//			tails[0] <= stail;		// computed above
//	else
	if (advance_enqueue) begin
		//if (!stomp_que || stomp_quem) 
		begin
			// Decrement sequence numbers.
			foreach (rob[n12])
				rob[n12].sn <= rob[n12].sn - MWIDTH;

			// On a predicted taken branch the front end will continue to send
			// instructions to be queued, but they will be ignored as they are
			// treated as NOPs as the valid bit will not be set. They will however
			// occupy slots in the ROB. It takes extra logic to pack the ROB and
			// the logic budget is tight, so we do not bother. There should be
			// little impact on performance.
			foreach (pg_ren.pr[n39]) begin
				tEnque((8'h80|n39)-MWIDTH,groupno,pg_ren.pr[n39],pt_q[n39],tails[n39],pg_ren.flush,
					stomps[n39], ornops[n39], cndx_ren[n39], pcndx_ren, grplen[n39], last[n39]);

				if (pg_ren.pr[n39].op.decbus.sync) begin
					sync_ndx = tails[n39];
					sync_ndxv = VAL;
				end
				if (pg_ren.pr[n39].op.decbus.fc) begin
					fc_ndx = tails[n39];
					fc_ndxv = VAL;
				end
			end
//			tBypassRegnames(tails[3], pg_ren.pr[3], pg_ren.pr[0], pg_ren.pr[3].decbus.has_imma, pg_ren.pr[3].decbus.has_immb | prnv[3], pg_ren.pr[3].decbus.has_immc | prnv[3], prnv[3], prnv[3]);
//			tBypassRegnames(tails[3], pg_ren.pr[3], pg_ren.pr[1], pg_ren.pr[3].decbus.has_imma, pg_ren.pr[3].decbus.has_immb | prnv[7], pg_ren.pr[3].decbus.has_immc | prnv[7], prnv[7], prnv[7]);
//      tBypassRegnames(tails[3], pg_ren.pr[3], pg_ren.pr[2], pg_ren.pr[3].decbus.has_imma, pg_ren.pr[3].decbus.has_immb | prnv[11], pg_ren.pr[3].decbus.has_immc | prnv[11], prnv[11], prnv[11]);
//			tBypassValid(tails[3], pg_ren.pr[3], pg_ren.pr[0]);
//			tBypassValid(tails[3], pg_ren.pr[3], pg_ren.pr[1]);
//			tBypassValid(tails[3], pg_ren.pr[3], pg_ren.pr[2]);
		
			tails[0] <= (tails[0] + MWIDTH) % Qupls4_pkg::ROB_ENTRIES;
			groupno <= ((tails[0] + MWIDTH) % Qupls4_pkg::ROB_ENTRIES) / MWIDTH;//groupno + 2'd1;
//			if (groupno >= Qupls4_pkg::ROB_ENTRIES / MWIDTH - 1)
//				groupno <= 8'd0;
		end
	end

	// Set an interrupt occurring in the predicate shadow to return to the
	// branch destination. This is faster than trying to move the interrupt
	// to the next instruction.
	if (resolved_takb) begin
		if (fcu_found_destination) begin
			foreach (rob[n3]) begin
				if (fcu_skip_list[n3])
					rob[n3].eip <= fcu_misspc1;
			end
		end
	end

// ----------------------------------------------------------------------------
// Dispatch
// The dispatchability of an instruction is pre-computed.
// ----------------------------------------------------------------------------
	// Set the predicate bits for an instruction. The instruction must be queued
	// already. An instruction is queued with its predicate bits set FALSE. If
	// there is no prior predicate then the flag is automatically set TRUE.
	if (FALSE) begin
		// Check each stream to see if all predicated instructions are done.
		foreach (pred_done[nn])
			if (pred_ins_done[nn]==8'hFF)
				pred_done[nn] <= TRUE;
		foreach (rob[nn]) begin
			// Predicate resolved?
			if (|rob[nn].v && rob[nn].op.decbus.pred) begin
				if (rob[nn].out!=2'b00 && pred_done[rob[nn].ip_stream.stream]) begin
					pred_buf[rob[nn].ip_stream.stream] <= value_zero;
					pred_done[rob[nn].ip_stream.stream] <= FALSE;
					pred_ins_done[rob[nn].ip_stream.stream] <= 8'd0;
				end
			end
			// Track which predicated instructions are done.
			if (|rob[nn].v && rob[nn].done==2'b11)
				pred_ins_done[rob[nn].ip_stream.stream][rob[nn].op.decbus.pred_no] <= TRUE;

			for (mm = 0; mm < 32; mm = mm + 1) begin
				// If predication is ignored for this instruction, mark valid and true.
				if (rob[nn].op.pred_mask[1:0]==2'b00) begin
					rob[nn].pred_bit <= TRUE;
					rob[nn].pred_bitv <= VAL;
				end
				else if (pred_done[rob[nn].ip_stream.stream]==FALSE)
				case(pred_tf[rob[nn].ip_stream.stream][mm])
				2'b00:	;	// predicate not resolved yet, leave alone.
				2'b11:	; // reserved, not used
				2'b10,2'b01:
					if (rob[nn].op.decbus.pred_no==mm) begin
						// If predication matches result, mark valid and true.
						if (rob[nn].op.pred_mask[1:0] == pred_tf[rob[nn].ip_stream.stream][mm]) begin
							rob[nn].op.pred_mask[1:0] <= 2'b00;
							rob[nn].pred_bit <= TRUE;
							rob[nn].pred_bitv <= VAL;
						end
						// Otherwise, result not matched, instruction should not be executed.
						else begin
							rob[nn].pred_bit <= FALSE;
							rob[nn].pred_bitv <= VAL;
						end
					end
				endcase

			end
		end
		/*
		// Detect hardware fault if predicate is no longer active and there are
		// still outstanding ROB entries waiting for it to resolve.
		foreach (rob[nn]) begin
			for (mm = 0; mm < 32; mm = mm + 1) begin
				if (rob[nn].op.decbus.pred_no==mm && !pred_alloc_map[mm]) begin
					if (!rob[nn].pred_bitv) begin
						rob[nn].pred_bit <= 1'b0;
						rob[nn].pred_bitv <= VAL;
						if (!rob[nn].excv) begin
							rob[nn].exc <= Qupls4_pkg::FLT_PRED;
							rob[nn].excv <= VAL;
						end
					end
				end
			end
		end
		*/
	end

	// Compute dispatchability of instruction.
	foreach (rob[nn])
		rob[nn].dispatchable <= 
			// Valid stream
			|rob[nn].v &&
			// and checkpoint index valid...
			pgh[rob[nn].pghn].cndxv &&
			// and not done already...
		  !(&rob[nn].done) &&
			// and not out already...
			!(|rob[nn].out) &&
			// and predicate is valid...
			rob[nn].pred_bitv &&
			// and no sync dependency
			!rob[nn].sync_dep &&
			// if a store, then no previous flow control dependency
			(rob[nn].op.decbus.store ? !rob[nn].fc_depv : TRUE) &&
			// if serializing the previous instruction must be done...
			(Qupls4_pkg::SERIALIZE ? &rob[(nn + Qupls4_pkg::ROB_ENTRIES-1)%Qupls4_pkg::ROB_ENTRIES].done || ~|rob[(nn + Qupls4_pkg::ROB_ENTRIES-1)%Qupls4_pkg::ROB_ENTRIES].v : TRUE) &&
			// A REXT prefix must be done
			(rob[(nn + Qupls4_pkg::ROB_ENTRIES - 1) % Qupls4_pkg::ROB_ENTRIES].op.decbus.rext ? &rob[(nn + Qupls4_pkg::ROB_ENTRIES - 1) % Qupls4_pkg::ROB_ENTRIES].done : TRUE)
			;

	foreach (rob[nn])
		if (rob_dispatched[nn])
			rob[nn].out <= {2{VAL}};

	// ----------------------------------------------------------------------------
	// REXT Prefix
	// REXT physical registers will already have been looked up or assigned.
	// Copy the register specs to the micro-op following the REXT prefix then
	// mark the prefix done. This will most likely be immediately after the
	// following micro-op queues.
	// ----------------------------------------------------------------------------
	foreach (rob[nn]) begin
		if (!(&rob[nn].done) &&			// not done
			rob[nn].op.decbus.rext		// and an extended register prefix
		) begin
			if (|rob[(nn+1)%ROB_ENTRIES].v && rob[(nn+1)%ROB_ENTRIES].sn == (rob[nn].sn +1) % ROB_ENTRIES) begin	// valid and in sequence?
				rob[(nn+1)%ROB_ENTRIES].op.pRs4 <= rob[nn].op.pRs1;
				rob[(nn+1)%ROB_ENTRIES].op.Rs4z <= rob[nn].op.decbus.Rs1z;
				rob[(nn+1)%ROB_ENTRIES].op.pRd2 <= rob[nn].op.pRd;
				rob[(nn+1)%ROB_ENTRIES].op.pS <= rob[nn].op.pRs2;
				rob[(nn+1)%ROB_ENTRIES].op.pRs4v <= VAL;
				rob[(nn+1)%ROB_ENTRIES].op.pRd2v <= VAL;
				rob[(nn+1)%ROB_ENTRIES].op.pSv <= VAL;
				rob[nn].done <= 2'b11;
			end
			// The REXT was not followed by a valid instruction. Treat as a NOP.
			// Just mark it done. Note: the next instruction may not be queued yet,
			// so test for a following instruction before marking.
			else if (|rob[(nn+1)%ROB_ENTRIES].v && rob[(nn + 1) % Qupls4_pkg::ROB_ENTRIES].sn > rob[nn].sn)
				rob[nn].done <= 2'b11;
		end
	end


	// This is really a result of dispatch
	// Place up to two instructions into the load/store queue in order.	
/*
	if (lsq[lsq_tail0.row][0].v==INV && rob[agen0_id].out[0] && !rob[agen0_id].lsq && rob[agen0_id].op.decbus.mem && !rob[agen0_id].op.decbus.cpytgt ) begin	// Can an entry be queued?
		if (!fnIsInLSQ(agen0_id)) begin
			rob[agen0_id].lsq <= VAL;
			rob[agen0_id].lsqndx <= lsq_tail0;
		end
		if (LSQ2 && lsq[lsq_tail0.row][1].v==INV && rob[agen1_id].out[0] && !rob[agen1_id].lsq && rob[agen1_id].op.decbus.mem && !rob[agen1_id].op.decbus.cpytgt ) begin	// Can a second entry be queued?
			if (!fnIsInLSQ(agen1_id)) begin
				rob[agen1_id].lsq <= VAL;
				rob[agen1_id].lsqndx <= {lsq_tail0.row,1'b1};
			end
		end
	end
*/
	// There must be room in the queue.
	if (room_for_lsq_queue) begin
		// and agen dispatched
		if (agen0_idv &&
		// and the instruction is valid (double-check - it should be, it got dispatched)
		rob[agen0_id].v==VAL &&
		// and it is a memory op (double-check)
		rob[agen0_id].op.decbus.mem &&
		// double-check LSQ row must be invalid
		lsq[lsq_tail0.row][0].v==INV &&
		// and the instruction is out
		rob[agen0_id].out[0] &&
		// and the instruction is not done
		!(&rob[agen0_id].done) &&
		// and not stomping on the instruction
		!robentry_stomp[agen0_id] &&
		// and there is no entry assigned yet
		!rob[agen0_id].lsq &&
		// and it is not a copy-target
		!rob[agen0_id].op.decbus.cpytgt &&
		// and address is calculated
		agen0_v
		) begin
			if (!fnIsInLSQ(agen0_id)) begin
				rob[agen0_id].lsq <= VAL;
				rob[agen0_id].lsqndx <= lsq_tail0;
				tEnqueLSE(lsq_tail0, agen0_id, 4'd0, agen0_res);
			end
		end
		// It is allowed to queue two
		if (Qupls4_pkg::LSQ2 && 
			// and agen dispatched
			agen1_idv && 
			// and the instruction is valid (double-check - it should be, it got dispatched)
			rob[agen1_id].v==VAL &&
			// and it is a memory op (double-check)
			rob[agen1_id].op.decbus.mem &&
			// double-check LSQ row must be invalid
			lsq[lsq_tail0.row][1].v==INV &&
			// and the instruction is out
			rob[agen1_id].out[0] &&
			// and the instruction is not done
			!(&rob[agen1_id].done) &&
			// and not stomping on the instruction
			!robentry_stomp[agen1_id] &&
			// and there is no entry assigned yet
			!rob[agen1_id].lsq &&
			// and it is not a copy-target
			!rob[agen1_id].op.decbus.cpytgt &&
			// address is valid
			agen1_v
		) begin
			if (!fnIsInLSQ(agen1_id)) begin
				rob[agen1_id].lsq <= VAL;
				rob[agen1_id].lsqndx <= {lsq_tail0.row,1'b1};
				tEnqueLSE({lsq_tail0.row,lsq_tail0.col|1}, agen1_id, 4'd1, agen1_res);
//				lsq[lsq_tail0.row][0].sn <= 7'h7E;
			end
		end
	end


// ----------------------------------------------------------------------------
// Register file Read
// ----------------------------------------------------------------------------
	// For the first register lookup strategy which uses the register file write
	// port history to fill in unknown values.
	//
	// Populate the argument values with values from register file. These values
	// may not be the final values if the register was still invaiid. If the
	// register was not valid, then the register tag is stored in the argument
	// value so it may be validated later.
	// In the case of a REXT prefix the values will be populated into the
	// wrong values slots, but this will be corrected later.
	// ----------------------------------------------------------------------------
	/* Values are not stored in the ROB.
	if (RL_STRATEGY==0) begin
		for (nn = 0; nn < MWIDTH; nn = nn + 1) begin
			rob[reg_tails[nn]].argA <= (rf_regv[nn*4+0]) ? rfo[nn*4+0] : rf_reg[nn*4+0];
			rob[reg_tails[nn]].argB <= (rf_regv[nn*4+1]) ? rfo[nn*4+1] : rf_reg[nn*4+1];
			rob[reg_tails[nn]].argC <= (rf_regv[nn*4+2]) ? rfo[nn*4+2] : rf_reg[nn*4+2];
			rob[reg_tails[nn]].argT <= (rf_regv[nn*4+3]) ? rfo[nn*4+3] : rf_reg[nn*4+3];
			// Values may have already been marked as valid, sont set them invalid!
			if (rf_regv[nn*4+0]) rob[reg_tails[nn]].argA_v <= VAL;
			if (rf_regv[nn*4+1]) rob[reg_tails[nn]].argB_v <= VAL;
			if (rf_regv[nn*4+2]) rob[reg_tails[nn]].argC_v <= VAL;
			if (rf_regv[nn*4+3]) rob[reg_tails[nn]].argT_v <= VAL;
			rob[reg_tails[nn]].reg_read_done <= TRUE;
		end
	end
*/

// ----------------------------------------------------------------------------
// ISSUE 
// ----------------------------------------------------------------------------
// determines what instructions are ready to go, then places them
// in the various ALU queues.  
// also invalidates instructions following a branch-miss BEQ or any JALR (STOMP logic)
//
	/*
	for (nn = 0; nn < Qupls4_pkg::ROB_ENTRIES; nn = nn + 1) begin
		if (sau0_args_valid)
			rob[sau0_rndx].all_args_valid <= VAL;
		if (sau1_args_valid)
			rob[sau1_rndx].all_args_valid <= VAL;
		if (fpu0_args_valid)
			rob[fpu0_rndx].all_args_valid <= VAL;
		if (fpu1_args_valid)
			rob[fpu1_rndx].all_args_valid <= VAL;
		if (agen0_args_valid)
			rob[agen0_rndx].all_args_valid <= VAL;
		if (agen1_args_valid)
			rob[agen1_rndx].all_args_valid <= VAL;
		if (fcu_args_valid)
			rob[fcu_rndx].all_args_valid <= VAL;
	end
	*/

	// It takes a clock cycle for the register to be read once it is known to be
	// valid. A flag, load_lsq_argc, is set to delay by a clock. This flag pulses
	// for only a single clock cycle.
	if (lsq[store_argC_id1.row][store_argC_id1.col].v==VAL && lsq[store_argC_id1.row][store_argC_id1.col].store && lsq[store_argC_id1.row][store_argC_id1.col].datav==INV) begin
		if (store_opero.v|rob[lsq[store_argC_id1.row][store_argC_id1.col].rndx].argC_v)//|store_argC_v)
			load_lsq_argc <= TRUE;
	end
	if (lsq[store_argC_id1.row][store_argC_id1.col].v==VAL && lsq[store_argC_id1.row][store_argC_id1.col].store && lsq[store_argC_id1.row][store_argC_id1.col].datav==INV) begin
	if (store_opero.v) begin //load_lsq_argc) begin//prnv[23]) begin
		$display("Qupls4: LSQ Rc=%h from r%d/%d", store_opero.val, lsq[store_argC_id1.row][store_argC_id1.col].aRc, lsq[store_argC_id1.row][store_argC_id1.col].pRc);
		lsq_cmd[2].cmd <= LSQ_CMD_SETRES;
		lsq_cmd[2].lndx <= {store_argC_id1.row,store_argC_id1.col};
		lsq_cmd[2].rndx <= 0;
		lsq_cmd[2].n <= 0;
		lsq_cmd[2].data <= store_opero.z ? value_zero : store_opero.val;//rfo_store_argC;
		lsq_cmd[2].flags <= store_opero.flags;//rfo_store_argC_flags;
		lsq_cmd[2].datav <= store_opero.v;//rfo_store_argC_valid;
//		lsq[store_argC_id1.row][store_argC_id1.col].res <= {rfo_store_argC_flags,rfo_store_argC};//prnv[23] ? rfo_store_argC : rob[lsq[store_argC_id1.row][store_argC_id1.col].rndx].argC;
//		lsq[store_argC_id1.row][store_argC_id1.col].flags <= rfo_store_argC_flags;
//		lsq[store_argC_id1.row][store_argC_id1.col].datav <= rfo_store_argC_valid;
	end
	end

//
// DATAINCOMING
//
// Once the operation is done, flag the ROB entry as done and mark the unit
// as idle. Record any exceptions that may have occurred.
//
	// Debug

	// Handle single-cycle ops
	// Whenever a result would be written, update the exception and done/out status.
	// Although no result may be written, the done/out status still needs to be set.
	tSetROBDone(sau0_rse2,FALSE, sau0_resA);
	if (Qupls4_pkg::NSAU > 1)
		tSetROBDone(sau1_rse2,FALSE, sau1_resA);

  // Handle multi-cycle mul/div ops
	tSetROBDone(imul0_rse2,FALSE,value_zero);
	if (idiv0_done)
		tSetROBDone(idiv0_rse2,FALSE,value_zero);

	if (Qupls4_pkg::NFMA > 0)
		tSetROBDone(fma0_rse2,FALSE,value_zero);
	if (Qupls4_pkg::NFMA > 0)
		tSetROBDone(fma1_rse2,FALSE,value_zero);
	if (Qupls4_pkg::NFPU > 0)
		tSetROBDone(fpu0_rse2,FALSE,value_zero);

	if (fcu_rse.v)
		fcu_state1 <= VAL;
	tSetROBDone(fcu_rser,takb,value_zero);

	// Causes issues vvv
	// If the operation is not multi-cycle assume it will complete within one
	// clock cycle, in which case the ALU is still idle. This allows back-to-back
	// issue of ALU operations to the ALU.

	// If data for stomped instruction, ignore
	// dram_vn will be false for stomped data
	if (dram0_done && |rob[ dram0_work.rndx ].v && dram0_work.rndxv)
		tSetROBMemDone(6, dram0_work,dram0_oper,dram0_oper.exc,dram0_oper.state);

	if (Qupls4_pkg::NDATA_PORTS > 1) begin
		if (dram1_done && |rob[ dram1_work.rndx ].v && dram1_work.rndxv)
			tSetROBMemDone(7, dram1_work,dram1_oper,dram1_oper.exc,dram1_oper.state);
	end

	// Store TLB translation in LSQ
	// If there is a TLB miss it could be a number of cycles before output
	// becomes valid.
	if (tlb0_v && |rob[agen0_rse.rndx].v &&
		!rob[agen0_rse.rndx].done[0] &&
		rob[agen0_rse.rndx].op.decbus.mem &&
		agen0_rse.v) begin
		if (|pg_fault && pg_faultq==2'd1) begin
			if (!rob[agen0_rse.rndx].excv) begin
				rob[agen0_rse.rndx].exc <= Qupls4_pkg::FLT_PAGE;
				rob[agen0_rse.rndx].excv <= TRUE;
			end
			rob[agen0_rse.rndx].done <= 2'b11;
			rob[agen0_rse.rndx].out[0] <= 1'b0;
		end
		if (rob[agen0_id].op.decbus.bstore) begin
			/*
			beb[1] <= beb[0];
			beb[2] <= beb[1];
			beb[3] <= beb[2];
			beb[0].v <= VAL;
			beb[0].nstate <= 2'd0;
			beb[0].state <= 2'd0;
			beb[0].pc <= rob[agen0_id].pc;
			beb[0].mcip <= rob[agen0_id].mcip;
			beb[0].op <= rob[agen0_id].op;
			beb[0].op.decbus <= rob[agen0_id].op.decbus;
			beb[0].excv <= rob[agen0_id].excv;
			beb[0].argA <= agen0_argA;
			beb[0].argB <= agen0_argB;
			beb[0].argM <= agen0_argM;
			beb[0].pRc <= agen0_pRc;
			beb[0].argC_v <= rob[agen0_id].argC_v;
			beb[0].cndx <= rob[agen0_id].cndx;
			beb[0].done <= FALSE;
			*/
			rob[agen0_id].done <= {VAL,VAL};
			rob[agen0_id].out[0] <= {INV,INV};
			agen0_idv <= INV;
		end
		if (rob[agen0_rse.rndx].lsq) begin
			rob[agen0_rse.rndx].done[0] <= 1'b1;
			rob[agen0_rse.rndx].out[0] <= 1'b0;
			tSetLSQ(4, agen0_rse.rndx, tlb0_res);
		end
	end

	/*
	if (beb_issue[beb_ndx]) begin
		if (beb_buf.argC==64'd0) begin
			beb_buf.done <= TRUE;
			beb_buf.v <= INV;
			beb_status[beb_buf.handle][0] <= 1'b0;
			beb_status[beb_buf.handle][1] <= 1'b0;
		end
		if (beb_buf.state==beb_buf.nstate) begin
			beb_buf.argC <= beb_buf.argC - 2'd1;
			beb_buf.argA <= beb_buf.argA + {{57{beb_buf.op.ins[41]}},beb_buf.op.ins[63:57]};
			if (!beb_buf.decbus.bstore)
				beb_buf.argB <= beb_buf.argB + {{57{beb_buf.op.ins[47]}},beb_buf.op.ins[63:57]};
		end
		if (beb_buf.nstate > 2'd0) begin
			beb_buf.state <= beb_buf.state + 2'd1;
			if (beb_buf.state==beb_buf.nstate-1)
				beb_buf.state <= 2'd0;
		end
	end
	*/

	if (Qupls4_pkg::NAGEN > 1) begin
		if (tlb1_v && agen1_rse.v) begin
			if (|pg_fault && pg_faultq==2'd2) begin
				if (!rob[agen1_rse.rndx].excv) begin
					rob[agen1_rse.rndx].exc <= Qupls4_pkg::FLT_PAGE;
					rob[agen1_rse.rndx].excv <= TRUE;
				end
				rob[agen1_rse.rndx].done <= 2'b11;
				rob[agen1_rse.rndx].out[0] <= 1'b0;
			end
			if (rob[agen1_rse.rndx].lsq && !rob[agen1_rse.rndx].done[0]) begin
				rob[agen1_rse.rndx].done[0] <= 1'b1;
				rob[agen1_rse.rndx].out[0] <= 1'b0;
				tSetLSQ(5, agen1_rse.rndx, tlb1_res);
			end
		end
	end

	// Set LSQ register C, it may be waiting for data

  for (n3 = 0; n3 < Qupls4_pkg::LSQ_ENTRIES; n3 = n3 + 1) begin
  	for (n12 = 0; n12 < Qupls4_pkg::NDATA_PORTS; n12 = n12 + 1) begin
	  	if (lsq[n3][n12].v==VAL && lsq[n3][n12].datav==INV && lsq[n3][n12].store) begin
	  		// Make the store data value available one cycle earlier than can be 
	  		// read from the register file.
	  		foreach (wrport0_v[n45]) begin
		  		if (lsq[n3][n12].datav==INV && lsq[n3][n12].pRc==wrport0_Rt[n45] && wrport0_v[n45]==VAL) begin
		  			$display("Qupls4: LSQ bypass from wrport0=%h r%d", wrport0_res[n45], wrport0_Rt[n45]);
						lsq_cmd[3].cmd <= LSQ_CMD_SETRES;
						lsq_cmd[3].lndx <= {n3,n12[0]};
						lsq_cmd[3].rndx <= 0;
						lsq_cmd[3].n <= 0;
						lsq_cmd[3].data <= wrport0_res[n45];
						lsq_cmd[3].flags <= wrport0_tag[n45];
						lsq_cmd[3].datav <= VAL;
		  		end
	  		end
	  	end
  	end
  end

// -----------------------------------------------------------------------------
// MEMORY
// -----------------------------------------------------------------------------
// update the memory queues and put data out on bus if appropriate
//
	// Bus timeout logic.
	// If the memory access has taken too long, then it is retried. This applies
	// mainly to loads as stores will ack right away. Bit 8 of the counter is
	// used to indicate a retry so 256 clocks need to pass. Four retries are
	// allowed for by testing bit 10 of the counter. If the bus still has not
	// responded after 1024 clock cycles then a bus error exception is noted.

	if (Qupls4_pkg::SUPPORT_BUS_TO) begin
	
	// Bus timeout logic
	// Reset out to trigger another access
		if (dram0_work.tocnt[10]) begin
			tSetROBMemDone(6, dram0_work,dram0_oper,Qupls4_pkg::FLT_BERR,2'b11);
			$display("Q+ set dram0_work.rndxv=INV at timeout");
			//lsq[rob[dram0_work.rndx].lsqndx.row][rob[dram0_work.rndx].lsqndx.col].v <= INV;
		end
		else if (dram0_work.tocnt[8])
			rob[dram0_work.rndx].out <= {INV,INV};

		if (Qupls4_pkg::NDATA_PORTS > 1) begin
			if (dram1_work.tocnt[10])
				tSetROBMemDone(7, dram1_work,dram1_oper,Qupls4_pkg::FLT_BERR,2'b11);
			else if (dram1_work.tocnt[8])
				rob[dram1_work.rndx].out <= {INV,INV};
		end
	end

	// Take requests that are ready and put them into DRAM slots


	// For unaligned accesses the instruction will issue again. Unfortunately
	// the address will be calculated again in the ALU, and it will be incorrect
	// as it would be using the previous address in the calc. Fortunately the
	// correct address is already available for the second bus cycle in the
	// dramN_addr var. We can tell when to use it by the setting of the more
	// flag.
	

	if (lsq[mem0_lsndx.row][mem0_lsndx.col].v2p && lsq[mem0_lsndx.row][mem0_lsndx.col].v) begin
		if (lsq[mem0_lsndx.row][mem0_lsndx.col].agen) begin
			// Prevent multiple updates
//			tInvalidateLSQ(lsq[mem0_lsndx.row][mem0_lsndx.col].rndx,FALSE,FALSE,dram0_oper.oper.val);
			rob[lsq[mem0_lsndx.row][mem0_lsndx.col].rndx].done <= 2'b11;
			rob[lsq[mem0_lsndx.row][mem0_lsndx.col].rndx].load_data <= dram0_oper.oper.val;
		end
	end
  else if (dram0 == Qupls4_pkg::DRAMSLOT_AVAIL && mem0_lsndxv && !robentry_stomp[lsq[mem0_lsndx.row][mem0_lsndx.col].rndx] && !dram0_work.rndxv && !dram0_idv2) begin
		rob[lsq[mem0_lsndx.row][mem0_lsndx.col].rndx].out <= {VAL,VAL};
		dram0_stomp <= FALSE;
	end

  if (Qupls4_pkg::NDATA_PORTS > 1) begin
	  if (dram1 == Qupls4_pkg::DRAMSLOT_AVAIL && Qupls4_pkg::NDATA_PORTS > 1 && mem1_lsndxv && !robentry_stomp[lsq[mem1_lsndx.row][mem1_lsndx.col].rndx]) begin
			rob[lsq[mem1_lsndx.row][mem1_lsndx.col].rndx].out	<= {VAL,VAL};
			dram1_stomp <= FALSE;
		end
	end
 
  foreach (robentry_stomp[n3]) begin
		if (robentry_stomp[n3] && rob[n3].lsqndx==mem0_lsndx && lsq[mem0_lsndx.row][mem0_lsndx.col].v)
			dram0_stomp <= 1'b1;
		if (!rob[n3].lsq && dram0_work.rndx==n3 && dram0_work.rndxv) begin
			dram0_stomp <= TRUE;
		end
		if (Qupls4_pkg::NDATA_PORTS > 1) begin
			if (robentry_stomp[n3] && rob[n3].lsqndx==mem1_lsndx && lsq[mem1_lsndx.row][mem1_lsndx.col].v)
				dram1_stomp <= 1'b1;
			if (!rob[n3].lsq && dram1_work.rndx==n3 && dram1_work.rndxv) begin
				dram1_stomp <= TRUE;
			end
		end
	end


// ----------------------------------------------------------------------------
// COMMIT
// ----------------------------------------------------------------------------
//
// Only the first oddball instruction is allowed to commit.
// Only the first exception is processed.
// Trigger page walk TLB update for outstanding agen request. Must be done when
// the instruction is at the commit stage to mitigate Spectre attacks.
// Clear the sync dependencies for any instructions dependent on a sync.

	if (!htcolls) begin
		// This commit_id and commit_idv used only to update the MMU for TLB access.
		commit0_id <= head[0];
		commit1_id <= head[1];
		commit2_id <= head[2];
		commit3_id <= head[3];
		commit0_idv <= cmttlb[0];
		commit1_idv <= cmttlb[1];
		commit2_idv <= cmttlb[2];
		commit3_idv <= cmttlb[3];
	end
	if (do_commit) begin
		commit_pc0 <= pgh[rob[head[0]].pghn].ip.pc + {rob[head[0]].ip_offs,1'b0};
		commit_pc1 <= pgh[rob[head[1]].pghn].ip.pc + {rob[head[1]].ip_offs,1'b0};
		commit_pc2 <= pgh[rob[head[2]].pghn].ip.pc + {rob[head[2]].ip_offs,1'b0};
		commit_pc3 <= pgh[rob[head[3]].pghn].ip.pc + {rob[head[3]].ip_offs,1'b0};
		commit_brtgt0 <= rob[head[0]].brtgt;
		commit_brtgt1 <= rob[head[1]].brtgt;
		commit_brtgt2 <= rob[head[2]].brtgt;
		commit_brtgt3 <= rob[head[3]].brtgt;
		commit_takb0 <= rob[head[0]].takb & rob[head[0]].op.decbus.br;
		commit_takb1 <= rob[head[1]].takb & rob[head[1]].op.decbus.br;
		commit_takb2 <= rob[head[2]].takb & rob[head[2]].op.decbus.br;
		commit_takb3 <= rob[head[3]].takb & rob[head[3]].op.decbus.br;
		commit_br0 <= rob[head[0]].op.decbus.br;
		commit_br1 <= rob[head[1]].op.decbus.br && cmtcnt > 3'd1;
		commit_br2 <= rob[head[2]].op.decbus.br && cmtcnt > 3'd2;
		commit_br3 <= rob[head[3]].op.decbus.br && cmtcnt > 3'd3;
		commit_ret0 = rob[head[0]].op.decbus.ret|rob[head[0]].op.decbus.eret;
		commit_ret1 = (rob[head[1]].op.decbus.ret|rob[head[1]].op.decbus.eret) && cmtcnt > 3'd1;
		commit_ret2 = (rob[head[2]].op.decbus.ret|rob[head[2]].op.decbus.eret) && cmtcnt > 3'd2;
		commit_ret3 = (rob[head[3]].op.decbus.ret|rob[head[3]].op.decbus.eret) && cmtcnt > 3'd3;
		commit_call0 = rob[head[0]].op.decbus.bsr|rob[head[0]].op.decbus.jsr && !rob[head[0]].op.decbus.Rdz;
		commit_call1 = (rob[head[1]].op.decbus.bsr|rob[head[1]].op.decbus.jsr) && !rob[head[0]].op.decbus.Rdz && cmtcnt > 3'd1;
		commit_call2 = (rob[head[2]].op.decbus.bsr|rob[head[2]].op.decbus.jsr) && !rob[head[0]].op.decbus.Rdz && cmtcnt > 3'd2;
		commit_call3 = (rob[head[3]].op.decbus.bsr|rob[head[3]].op.decbus.jsr) && !rob[head[0]].op.decbus.Rdz && cmtcnt > 3'd3;
		commit_jmp0 = (rob[head[0]].op.decbus.bsr|rob[head[0]].op.decbus.jsr) && rob[head[0]].op.decbus.Rdz;
		commit_jmp1 = (rob[head[1]].op.decbus.bsr|rob[head[1]].op.decbus.jsr) && rob[head[0]].op.decbus.Rdz && cmtcnt > 3'd1;
		commit_jmp2 = (rob[head[2]].op.decbus.bsr|rob[head[2]].op.decbus.jsr) && rob[head[0]].op.decbus.Rdz && cmtcnt > 3'd2;
		commit_jmp3 = (rob[head[3]].op.decbus.bsr|rob[head[3]].op.decbus.jsr) && rob[head[0]].op.decbus.Rdz && cmtcnt > 3'd3;
		commit_grp0 = rob[head[0]].wh;
		commit_grp1 = rob[head[1]].wh;
		commit_grp2 = rob[head[2]].wh;
		commit_grp3 = rob[head[3]].wh;

		group_len <= group_len - 1;
		tCommits(8, head[0]);
		if (rob[head[0]].flush) begin
			cp_stall <= 1'b1;
			flush_pipeline <= 1'b0;
		end
		if (cmtcnt > 3'd1) begin
			tCommits(9, head[1]);
			group_len <= group_len - 2;
		end
		if (cmtcnt > 3'd2) begin
			tCommits(10, head[2]);
			group_len <= group_len - 3;
		end
		if (cmtcnt > 3'd3) begin
			tCommits(11, head[3]);
			group_len <= group_len - 4;
		end
		if (cmtcnt > 3'd4) begin
			tCommits(12, head[4]);
			group_len <= group_len - 5;
		end
		if (cmtcnt > 3'd5) begin
			tCommits(13, head[5]);
			group_len <= group_len - 6;
		end
		head[0] <= (head[0] + cmtcnt) % Qupls4_pkg::ROB_ENTRIES;	
//		head[0] <= (head[0] + 3'd4) % ROB_ENTRIES;	
		if (group_len <= 0)
			group_len <= rob[head[0]].group_len;
		// Commit oddball instructions
		if ((rob[head[0]].op.decbus.oddball && !rob[head[0]].excv) || rob[head[0]].op.hwi)
			tOddballCommit(rob[head[0]].v, head[0]);
		else if ((rob[head[1]].op.decbus.oddball && !rob[head[1]].excv && cmtcnt > 3'd1) || rob[head[1]].op.hwi)
			tOddballCommit(rob[head[1]].v, head[1]);
		else if ((rob[head[2]].op.decbus.oddball && !rob[head[2]].excv && cmtcnt > 3'd2) || rob[head[2]].op.hwi)
			tOddballCommit(rob[head[2]].v, head[2]);
		else if ((rob[head[3]].op.decbus.oddball && !rob[head[3]].excv && cmtcnt > 3'd3) || rob[head[3]].op.hwi)
			tOddballCommit(rob[head[3]].v, head[3]);
		// Trigger exception processing for last instruction in group.
		if (rob[head[0]].excv && rob[head[0]].v)
//			err_mask[head[0]] <= 1'b1;
//			if (rob[head[0]].last)
			tProcessExc(head[0],pgh[rob[head[0]].pghn].ip.pc+{rob[head[0]].ip_offs,1'b0},rob[head[0]].op.uop.num);
		else if (rob[head[1]].excv && cmtcnt > 3'd1 && rob[head[1]].v)
			tProcessExc(head[1],pgh[rob[head[1]].pghn].ip.pc+{rob[head[1]].ip_offs,1'b0},rob[head[1]].op.uop.num);
		else if (rob[head[2]].excv && cmtcnt > 3'd2 && rob[head[2]].v)
			tProcessExc(head[2],pgh[rob[head[2]].pghn].ip.pc+{rob[head[2]].ip_offs,1'b0},rob[head[2]].op.uop.num);
		else if (rob[head[3]].excv && cmtcnt > 3'd3 && rob[head[3]].v)
			tProcessExc(head[3],pgh[rob[head[3]].pghn].ip.pc+{rob[head[3]].ip_offs,1'b0},rob[head[3]].op.uop.num);
			
		if (rob[head[0]].op.ssm)
			tProcessExc(head[0],Qupls4_pkg::SSM_DEBUG ? pgh[rob[head[0]].pghn].ip.pc+{rob[head[0]].ip_offs,1'b0} : rob[head[0]].op.hwipc,rob[head[0]].op.uop.num);

		/*
		if (FALSE) begin
			if (rob[head[0]].op.decbus.sync)
				tZeroSyncDep(rob[head[0]].sync_no);
			if (rob[head[1]].op.decbus.sync)
				tZeroSyncDep(rob[head[1]].sync_no);
			if (rob[head[2]].op.decbus.sync)
				tZeroSyncDep(rob[head[2]].sync_no);
			if (rob[head[3]].op.decbus.sync)
				tZeroSyncDep(rob[head[3]].sync_no);
			if (rob[head[0]].op.decbus.fc)
				tZeroFcDep(rob[head[0]].fc_no);
			if (rob[head[1]].op.decbus.fc)
				tZeroFcDep(rob[head[1]].fc_no);
			if (rob[head[2]].op.decbus.fc)
				tZeroFcDep(rob[head[2]].fc_no);
			if (rob[head[3]].op.decbus.fc)
				tZeroFcDep(rob[head[3]].fc_no);
		end
		*/
		/*
		if (rob[head[0]].op.decbus.pred) begin
			pred_tf[rob[head[0]].ip_stream.stream][rob[head[0]].op.decbus.pred_no] <= 2'b00;
			pred_alloc_map[rob[head[0]].op.decbus.pred_no] <= 1'b0;
		end
		if (rob[head[1]].op.decbus.pred && cmtcnt > 3'd1) begin
			pred_tf[rob[head[1]].ip_stream.stream][rob[head[1]].op.decbus.pred_no] <= 2'b00;
			pred_alloc_map[rob[head[1]].op.decbus.pred_no] <= 1'b0;
		end
		if (rob[head[2]].op.decbus.pred && cmtcnt > 3'd2) begin
			pred_tf[rob[head[2]].ip_stream.stream][rob[head[2]].op.decbus.pred_no] <= 2'b00;
			pred_alloc_map[rob[head[2]].op.decbus.pred_no] <= 1'b0;
		end
		if (rob[head[3]].op.decbus.pred && cmtcnt > 3'd3) begin
			pred_tf[rob[head[3]].ip_stream.stream][rob[head[3]].op.decbus.pred_no] <= 2'b00;
			pred_alloc_map[rob[head[3]].op.decbus.pred_no] <= 1'b0;
		end
		if (rob[head[4]].op.decbus.pred && cmtcnt > 3'd4) begin
			pred_tf[rob[head[4]].ip_stream.stream][rob[head[4]].op.decbus.pred_no] <= 2'b00;
			pred_alloc_map[rob[head[4]].op.decbus.pred_no] <= 1'b0;
		end
		if (rob[head[5]].op.decbus.pred && cmtcnt > 3'd5) begin
			pred_tf[rob[head[5]].ip_stream.stream][rob[head[5]].op.decbus.pred_no] <= 2'b00;
			pred_alloc_map[rob[head[5]].op.decbus.pred_no] <= 1'b0;
		end
		*/
	end

	// If the re-order buffer is empty, the the commit pointer should remain
	// where it is until new instructions are queued. Otherwise, if the commit
	// pointer is not pointing at a valid instruction something must have gone
	// wrong with hardware.
	if (!rob_empty) begin
		if (rob[head[0]].v==5'd0)
			head[0] <= (head[0] + 4'd1) % Qupls4_pkg::ROB_ENTRIES;	
		if (rob[head[0]].v==5'd0 && rob[head[1]].v==5'd0)
			head[0] <= (head[0] + 4'd2) % Qupls4_pkg::ROB_ENTRIES;	
		if (rob[head[0]].v==5'd0 && rob[head[1]].v==5'd0 && rob[head[2]].v==5'd0)
			head[0] <= (head[0] + 4'd3) % Qupls4_pkg::ROB_ENTRIES;	
		if (rob[head[0]].v==5'd0 && rob[head[1]].v==5'd0 && rob[head[2]].v==5'd0 && rob[head[3]].v==5'd0)
			head[0] <= (head[0] + 4'd4) % Qupls4_pkg::ROB_ENTRIES;	
	end
	
	// ToDo: fix LSQ head update.
	if (lsq[lsq_head.row][lsq_head.col].v==INV && lsq_head != lsq_tail)
		lsq_head.row <= lsq_head.row + 1;

	if (Qupls4_pkg::SUPPORT_QUAD_PRECISION) begin
		tCheckQFExtDone(head[0]);	
		tCheckQFExtDone(head[1]);	
		tCheckQFExtDone(head[2]);	
		tCheckQFExtDone(head[3]);	
	end

	// Ivalidate load / store queue entries.	
	// This does just one per clock cycle.
	n54 = FALSE;
	foreach (rob[nn]) begin
		if (rob[nn].lsq && !n54) begin
			if (&rob[nn].done) begin
				tInvalidateLSQ(14, nn, FALSE, FALSE, rob[nn].load_data);
				n54 = TRUE;
			end
		end
	end

	// There is a bypassing issue in the RAT, where a register is being marked
	// valid at the same time an instruction is queuing that uses the register.
	// The fact the register is going to be valid gets missed, then the
	// instruction hangs the machine waiting for the argument to become valid.
	// So, for now, if an instruction makes it to the commit stage and there
	// seems to be no way for its arguments to be marked valid, then the args
	// are marked valid here. It prevents the machine from locking up.
	begin
		for (nn = 0; nn < Qupls4_pkg::ROB_ENTRIES; nn = nn + 1) begin
			if (rob[head[0]].v) begin
				if (!rob[head[0]].argA_v && !fnFindSource(head[0], rob[head[0]].op.decbus.Rs1)) begin
					rob[head[0]].argA_v <= VAL;
					tAllArgsValid(head[0], VAL, INV, INV, INV, INV);
					$display("Qupls4: rob[%d]: argument A not possible to validate.", head[0]);
				end		
				if (!rob[head[0]].argB_v && !fnFindSource(head[0], rob[head[0]].op.decbus.Rs2)) begin
					$display("Qupls4: rob[%d]: argument B not possible to validate.", head[0]);
					rob[head[0]].argB_v <= VAL;
					tAllArgsValid(head[0], INV, VAL, INV, INV, INV);
				end		
				if (!rob[head[0]].argC_v && !fnFindSource(head[0], rob[head[0]].op.decbus.Rs3)) begin
					$display("Qupls4: rob[%d]: argument C not possible to validate.", head[0]);
					rob[head[0]].argC_v <= VAL;
					tAllArgsValid(head[0], INV, INV, VAL, INV, INV);
				end		
				if (!rob[head[0]].argD_v && !fnFindSource(head[0], rob[head[0]].op.decbus.Rs4)) begin
					$display("Qupls4: rob[%d]: argument D not possible to validate.", head[0]);
					rob[head[0]].argD_v <= VAL;
					tAllArgsValid(head[0], INV, INV, INV, VAL, INV);
				end		
				if (!rob[head[0]].argT_v) begin
					if (!fnFindSource(head[0], rob[head[0]].op.decbus.Rd)) begin
						$display("Qupls4: rob[%d]: destination T not possible to validate.", head[0]);
						rob[head[0]].argT_v <= VAL;
						tAllArgsValid(head[0], INV, INV, INV, INV, VAL);
					end
				end
			end
		end
	end
	
	// Detect a "stuck out" situation. This occurs when the out flags are set but
	// there is no longer a functional unit associated with the ROB entry. This
	// causes the machine to hang. Try resetting the "out" status which should
	// cause the instruction to be scheduled again. This situation ha shown up
	// in simulation, but the cause has not been traced. I think it may be due
	// to bit errors. In any case we do not want the machine to hang.
	// This case should not be possible with properly performing hardware.
	foreach (rob[nn]) begin
		if (fnStuckOut(nn))
			rob[nn].out <= 2'b00;
	end

	// Unstick:
	// If the same physical register is valid in a later instruction, then it should
	// be valid for the earlier one. Sometimes the core is not marking a register valid
	// when it should, this causes the core to hang. ToDo: fix this issue and remove
	// the following code.
	/*
	for (nn = 0; nn < ROB_ENTRIES; nn = nn + 1) begin
		if (rob[nn].argA_v && rob[nn].pRa==rob[head[0]].pRa && rob[nn].sn > rob[head[0]].sn)
			rob[head[0]].argA_v <= VAL;
		if (rob[nn].argB_v && rob[nn].pRa==rob[head[0]].pRa && rob[nn].sn > rob[head[0]].sn)
			rob[head[0]].argB_v <= VAL;
		if (rob[nn].argC_v && rob[nn].pRa==rob[head[0]].pRa && rob[nn].sn > rob[head[0]].sn)
			rob[head[0]].argC_v <= VAL;
		if (rob[nn].argD_v && rob[nn].pRa==rob[head[0]].pRa && rob[nn].sn > rob[head[0]].sn)
			rob[head[0]].argD_v <= VAL;
		if (rob[nn].argM_v && rob[nn].pRa==rob[head[0]].pRa && rob[nn].sn > rob[head[0]].sn)
			rob[head[0]].argM_v <= VAL;
	end
	*/
	// Branchmiss stomping
	// Mark functional units stomped on idle.
	// Invalidate instructions newer than the branch in the ROB.
	// Free up load / store queue entries.
	// Set the stomp flag to update the RAT marking the register valid.
	/*
	if (robentry_stomp[sau0_id] || !rob[sau0_id].v) begin
		sau0_idle <= TRUE;
		sau0_stomp <= TRUE;
	end
	if (robentry_stomp[sau1_id] || !rob[sau1_id].v) begin
		sau1_idle <= TRUE;
		sau1_stomp <= TRUE;
	end
	*/
	if (robentry_stomp[fpu0_id]) begin
		fpu0_idle <= TRUE;
		fpu0_idv <= INV;
		fpu0_stomp <= TRUE;
	end
	if (robentry_stomp[fpu1_id]) begin
		fpu1_idle <= TRUE;
		fpu1_idv <= INV;
		fpu1_stomp <= TRUE;
	end
	if (robentry_stomp[dram0_work.rndx]) begin
		dram0_stomp <= TRUE;
		rob[dram0_work.rndx].done <= 2'b11;
		rob[dram0_work.rndx].out <= 2'b00;
	end
	if (robentry_stomp[dram1_work.rndx]) begin
		dram1_stomp <= TRUE;
		rob[dram1_work.rndx].done <= 2'b11;
		rob[dram1_work.rndx].out <= 2'b00;
	end
	/*
	if (robentry_stomp[agen0_id]) begin// || !rob[agen0_id].v) begin
		agen0_idle <= TRUE;
		agen0_idv <= INV;
		if (dram0_work.rndx==agen0_id)
			dram0_stomp <= TRUE;
	end
	if (Qupls4_pkg::NDATA_PORTS > 1) begin
		if (robentry_stomp[agen1_id]) begin// || !rob[agen1_id].v) begin
			agen1_idle <= TRUE;
			agen1_idv <= INV;
			if (dram1_work.rndx==agen1_id)
				dram1_stomp <= TRUE;
		end
	end
	*/
	// Terminate FCU operation on stomp.

	// Redo instruction as copy target.
	// Invalidate false paths.
	foreach (robentry_cpydst[n3]) begin
		if (robentry_stomp[n3]|robentry_cpydst[n3])	// || bno_bitmap[rob[n3].pc.stream]==1'b0)
			tBranchInvalidate(n3,robentry_cpydst[n3]);
	end

	// This bit to aid the scheduler. There are a lot of bits that must be true
	// before an instruction can issue. These are pre-computed here to reduce the
	// logic levels in the scheduler. It does add a cycle or two of latency, but 
	// is likely done before the instruction comes into consideration by the
	// scheduler. The latency is hidden.
	begin : gSchedPrecalc

		foreach (rob[n3]) begin
			rob[n3].could_issue <=
					rob[n3].v
				&& !robentry_stomp[n3]
				&& !(&rob[n3].done)
				&& (rob[n3].op.decbus.cpytgt ? (rob[n3].argT_v /*|| rob[g].op.nRt==9'd0*/) : rob[n3].all_args_valid && rob[n3].pred_bit)
				&& (rob[n3].op.decbus.mem ? !rob[n3].fc_depv : 1'b1)
				&& (Qupls4_pkg::SERIALIZE ? (rob[(n3+Qupls4_pkg::ROB_ENTRIES-1)%Qupls4_pkg::ROB_ENTRIES].done==2'b11 || rob[(n3+Qupls4_pkg::ROB_ENTRIES-1)%Qupls4_pkg::ROB_ENTRIES].v==INV) : 1'b1)
				//&& !fnPriorFalsePred(g)
				&& !rob[n3].sync_depv
	//			&& |rob[n3].pred_bits
//				&& rob[n3].pred_bitv
				;

			rob[n3].could_issue_nm <= 
					 rob[n3].v
				&& !(&rob[n3].done)
	//												&& !stomp_i[g]
				&& rob[n3].argT_v 
				//&& fnPredFalse(g)
				&& !robentry_issue[n3]
//				&& ~rob[n3].pred_bit
//		    && rob[n3].pred_bitv
				&& Qupls4_pkg::SUPPORT_PRED
				;
		end
	end

	//  Adjust interrupt position to first micro-op of instruction
	// Interrupts are not allowed in the middle of a micro-op stream for
	// instructions.
	
	foreach (rob[n3]) begin
		if (rob[n3].op.uop.lead==1'd0 && rob[n3].op.hwi)
			case(Qupls4_pkg::UOP_STRATEGY)
			1:	tMoveIRQToInstructionStart(n3);
			2:	tDeferToNextInstruction(n3);
			3:	;
			endcase
	end
	
	
	copro_stall1 <= copro_stall;
	if (inject_cl|(~copro_stall & copro_stall1))
		cp_stall <= 1'b0;
end

// ----------------------------------------------------------------------------
// External bus arbiter. mux is round-robin.
// ----------------------------------------------------------------------------

wishbone_pkg::wb_cmd_request256_t [5:0] cmds;
wishbone_pkg::wb_cmd_response256_t [5:0] resps;
always_comb cmds[0] = ftatm_req;
always_comb cmds[1] = ftaim_req;
always_comb cmds[2] = ftadm_req[0];
always_comb cmds[3] = cap_tag_req[0];
always_comb cmds[4] = ftadm_req[1];
always_comb cmds[5] = cap_tag_req[1];

always_comb begin ftatm_resp = resps[0]; end
always_comb begin ftaim_resp = resps[1]; end
always_comb begin ftadm_resp[0] = resps[2]; end
always_comb begin cap_tag_resp[0] = resps[3]; end
always_comb begin ftadm_resp[1] = resps[4]; end
always_comb begin cap_tag_resp[1] = resps[5]; end

wb_mux #(.NPORT(6)) utmrmux1
(
	.rst_i(irst),
	.clk_i(clk),
	.req_i(cmds),
	.req_o(wb_req),
	.resp_i(ptable_resp.ack ? ptable_resp : wb_resp),
	.resp_o(resps)
);

// ----------------------------------------------------------------------------
// Performance statistics
// ----------------------------------------------------------------------------

always_ff @(posedge clk)
if (irst)
	tick <= 64'd0;
else
	tick <= tick + 2'd1;

always_ff @(posedge clk)
if (irst)
	icache_cnt <= 64'd0;
else
	icache_cnt <= icache_cnt + ihito;

always_ff @(posedge clk)
if (irst)
	iact_cnt <= 40'd0;
else
	iact_cnt <= iact_cnt + ihito;

always_ff @(posedge clk)
if (irst)
	rat_stalls <= 0;
else
	rat_stalls <= rat_stalls + rat_stallq;

always_ff @(posedge clk)
if (irst)
	ren_stalls <= 0;
else
	ren_stalls <= ren_stalls + ren_stallq;

// Total instructions committed.
always_ff @(posedge clk)
if (irst)
	I <= 0;
else begin
	if (do_commit)
		I <= I + cmtcnt;
end

// Valid instructions committed.
always_ff @(posedge clk)
if (irst)
	IV <= 0;
else begin
	if (do_commit) begin
		if (cmtcnt > 3)
			IV <= IV + |rob[head[0]].v + |rob[head[1]].v + |rob[head[2]].v + |rob[head[3]].v;
		else if (cmtcnt > 2)
			IV <= IV + |rob[head[0]].v + |rob[head[1]].v + |rob[head[2]].v;
		else if (cmtcnt > 1)
			IV <= IV + |rob[head[0]].v + |rob[head[1]].v;
		else if (cmtcnt > 0)
			IV <= IV + |rob[head[0]].v;
	end
end

always_ff @(posedge clk)
if (irst)
	marked_insn_count = 64'd0;
else begin
	if (do_commit) begin
		case (cmtcnt)
		3'd4:
			marked_insn_count = marked_insn_count +
				(|rob[head[0]].v && rob[head[0]].op.decbus.nop) +
				(|rob[head[1]].v && rob[head[1]].op.decbus.nop) +
				(|rob[head[2]].v && rob[head[2]].op.decbus.nop) +
				(|rob[head[3]].v && rob[head[3]].op.decbus.nop)
				;
		3'd3:
			marked_insn_count = marked_insn_count +
				(|rob[head[0]].v && rob[head[0]].op.decbus.nop) +
				(|rob[head[1]].v && rob[head[1]].op.decbus.nop) +
				(|rob[head[2]].v && rob[head[2]].op.decbus.nop)
				;
		3'd2:
			marked_insn_count = marked_insn_count +
				(|rob[head[0]].v && rob[head[0]].op.decbus.nop) +
				(|rob[head[1]].v && rob[head[1]].op.decbus.nop)
				;
		3'd1:
			marked_insn_count = marked_insn_count +
				(|rob[head[0]].v && rob[head[0]].op.decbus.nop)
				;
		default:	;				
		endcase
	end
end

// How is this going to work? What if stomped is active for more than one
// cycle?
always_ff @(posedge clk)
if (irst)
	stomped_insn = 64'd0;
else begin
	for (n31 = 0; n31 < Qupls4_pkg::ROB_ENTRIES; n31 = n31 + 1)
		stomped_insn = stomped_insn + robentry_stomp[n31];
end

always_ff @(posedge clk)
if (irst)
	cpytgts <= 0;
else begin
	if (do_commit) begin
		if (cmtcnt > 3)
			cpytgts <= cpytgts 
				+ rob[head[0]].op.decbus.cpytgt 
				+ rob[head[1]].op.decbus.cpytgt
				+ rob[head[2]].op.decbus.cpytgt
				+ rob[head[3]].op.decbus.cpytgt
			;
		else if (cmtcnt > 2)
			cpytgts <= cpytgts 
				+ rob[head[0]].op.decbus.cpytgt 
				+ rob[head[1]].op.decbus.cpytgt
				+ rob[head[2]].op.decbus.cpytgt
			;
		else if (cmtcnt > 1)
			cpytgts <= cpytgts 
				+ rob[head[0]].op.decbus.cpytgt 
				+ rob[head[1]].op.decbus.cpytgt
			;
		else if (cmtcnt > 0)
			cpytgts <= cpytgts 
				+ rob[head[0]].op.decbus.cpytgt 
			;
	end
end

// ============================================================================
// DEBUG
// ============================================================================

// The following only works for simulation. The code needs to be commented
// out for synthesis.
`ifdef IS_SIM
// We only want the live value of the register for display.
function value_t fnRegVal;
input pregno_t regno;
begin
	fnRegVal = urf1.gRF.genblk1[0].genblk1[0].urf0.mem[regno];
	/*
	case (urf1.lvt[regno])
	2'd0:	fnRegVal = urf1.gRF.genblk1[0].urf0.mem[regno];
	2'd1:	fnRegVal = urf1.gRF.genblk1[0].urf1.mem[regno];
	2'd2:	fnRegVal = urf1.gRF.genblk1[0].urf2.mem[regno];
	2'd3:	fnRegVal = urf1.gRF.genblk1[0].urf3.mem[regno];
	endcase
	*/
end
endfunction

`ifdef SUPPORT_RAT
function fnPregv;
input pregno_t regno;
begin
	fnPregv = uren1.urat1.currentRegvalid[regno];
end
endfunction
function pregno_t fnPreg;
input aregno_t regno;
begin
	fnPreg = uren1.urat1.currentMap.regmap[regno];
end
endfunction
`else
function fnPregv;
input pregno_t regno;
begin
	fnPregv = VAL;
end
endfunction
function pregno_t fnPreg;
input aregno_t regno;
begin
	fnPreg = {1'b0,regno};
end
endfunction
`endif

function value_t fnArchRegV;
input aregno_t regno;
begin
	fnArchRegV = fnPregv(fnPreg(regno));
end
endfunction

function value_t fnArchRegVal;
input aregno_t regno;
begin
	fnArchRegVal = fnRegVal(fnPreg(regno));
end
endfunction


generate begin : gDisplay
begin
always_ff @(posedge clk) begin: clock_n_debug
	integer i;
	integer j;

	$display("\n\n\n\n\n\n\n\n");
	$display("TIME %0d", $time);
	$display("Instruction sequence");
	$display("--------------------");
	$display("FET:");
	$display("   cacheL: %x", ic_line[511:0]);
	$display("   cacheH: %x", ic_line[1023:512]);
	$display("EXT: 0:%h  1:%h  2:%h  3:%h", pg_ext.pr[0].op.uop, pg_ext.pr[1].op.uop, pg_ext.pr[2].op.uop, pg_ext.pr[3].op.uop);
	$display("MOT: 0:%h  1:%h  2:%h  3:%h", pg_mot.pr[0].op.uop, pg_mot.pr[1].op.uop, pg_mot.pr[2].op.uop, pg_mot.pr[3].op.uop);
	$display("DEC: 0:%h  1:%h  2:%h  3:%h", pg_dec.pr[0].op.uop, pg_dec.pr[1].op.uop, pg_dec.pr[2].op.uop, pg_dec.pr[3].op.uop);
	$display("REN: 0:%h  1:%h  2:%h  3:%h", pg_ren.pr[0].op.uop, pg_ren.pr[1].op.uop, pg_ren.pr[2].op.uop, pg_ren.pr[3].op.uop);
	$display("----- Fetch -----");
	$display("i$ pc input:  %h.%h stream:%d#", pcs[fet_stream].stream,pcs[fet_stream].pc, fet_stream);
	$display("i$ pc output: %h %s #", pc_fet.pc, ihito ? "ihit" : "    ");
	$display("cacheL: %x", ic_line[511:0]);
	$display("cacheH: %x", ic_line[1023:512]);
	$display("----- Instruction Extract %c ----- %s", ihit_fet ? "h":" ", stomp_fet ? stompstr : no_stompstr);
	$display("ip 0: %h.%h  1: %h.%h  2: %h.%h  3: %h.%h",
		uiext1.pc_fet[0].stream, uiext1.pc_fet[0].pc,
		uiext1.pc_fet[1].stream, uiext1.pc_fet[1].pc,
		uiext1.pc_fet[2].stream, uiext1.pc_fet[2].pc,
		uiext1.pc_fet[3].stream, uiext1.pc_fet[3].pc);
	$display("lineL: %h", ic_line_fet[511:0]);
	$display("lineH: %h", ic_line_fet[1023:512]);
	$display("align: %x", uiext1.ic_line_aligned);
	$display("----- Micro-op Translate ----- %s", stomp_mot ? stompstr : no_stompstr);
	$display("ip: %h.%h", pg_ext.hdr.ip.stream.stream, pg_ext.hdr.ip.pc);
	$display("Raw instructions");
	$display("0:%h  1:%h  2:%h  3:%h", pg_ext.pr[0].op.uop, pg_ext.pr[1].op.uop, pg_ext.pr[2].op.uop, pg_ext.pr[3].op.uop);
	$display("- - - - - - Multiplex %c - - - - - - %s", ihit_ext ? "h":" ", stomp_ext ? stompstr : no_stompstr);
	/*
	$display("pc0: %h.%h ins0: %h", uiext1.pg_ext.pr[0].pc.pc[23:0], uiext1.pg_ext.pr[0].mcip, uiext1.pg_ext.pr[0].uop[47:0]);
	$display("pc1: %h.%h ins1: %h", uiext1.pg_ext.pr[1].pc.pc[23:0], uiext1.pg_ext.pr[1].mcip, uiext1.pg_ext.pr[1].uop[47:0]);
	$display("pc2: %h.%h ins2: %h", uiext1.pg_ext.pr[2].pc.pc[23:0], uiext1.pg_ext.pr[2].mcip, uiext1.pg_ext.pr[2].uop[47:0]);
	$display("pc3: %h.%h ins3: %h", uiext1.pg_ext.pr[3].pc.pc[23:0], uiext1.pg_ext.pr[3].mcip, uiext1.pg_ext.pr[3].uop[47:0]);
	*/
	if (p_override)
		$display("BSR %h  pc0_fet=%h", new_address_ext, uiext1.pg_ext.hdr.ip.pc+{uiext1.pg_ext.pr[0].ip_offs,1'b0});
	$display("----- Decode %c ----- %s", ihit_dec ? "h":" ", stomp_dec ? stompstr : no_stompstr);
	$display("ip:%h.%h", pg_mot.hdr.ip.stream.stream,pg_mot.hdr.ip.pc);
	$display("0:%h  1:%h  2:%h  3:%h", pg_mot.pr[0].op.uop, pg_mot.pr[1].op.uop, pg_mot.pr[2].op.uop, pg_mot.pr[3].op.uop);
	/*
	$display("pc0: %h.%h ins0: %h", pg_dec.pr[0].pc.pc[23:0], pg_dec.pr[0].mcip, pg_dec.pr[0].uop[47:0]);
	$display("pc1: %h.%h ins1: %h", pg_dec.pr[1].pc.pc[23:0], pg_dec.pr[1].mcip, pg_dec.pr[1].uop[47:0]);
	$display("pc2: %h.%h ins2: %h", pg_dec.pr[2].pc.pc[23:0], pg_dec.pr[2].mcip, pg_dec.pr[2].uop[47:0]);
	$display("pc3: %h.%h ins3: %h", pg_dec.pr[3].pc.pc[23:0], pg_dec.pr[3].mcip, pg_dec.pr[3].uop[47:0]);
	*/
	if (1) begin	
	$display("----- Physical Registers -----");
	for (i=0; i< 16; i=i+8)
	    $display("%d: %h %d: %h %d: %h %d: %h %d: %h %d: %h %d: %h %d: %h #",
	    	i[9:0]+10'd0, fnRegVal(i+0), i[9:0]+10'd1, fnRegVal(i+1), i[9:0]+10'd2, fnRegVal(i+2), i[9:0]+10'd3, fnRegVal(i+3),
	    	i[9:0]+10'd4, fnRegVal(i+4), i[9:0]+10'd5, fnRegVal(i+5), i[9:0]+10'd6, fnRegVal(i+6), i[9:0]+10'd7, fnRegVal(i+7)
	    );
	end

	$display("----- Architectural Registers -----");
	for (i = 0; i < AREGS; i = i + 8)
		/*
		if (i > 48)
			$display("v%d -> %d: %h %d: %h %d: %h %d: %h %d: %h %d: %h %d: %h %d: %h #",
			i[7:0] >> 3'd3,
			8'd0, fnArchRegVal(i+0), 8'd1, fnArchRegVal(i+1), 8'd2, fnArchRegVal(i+2), 8'd3,  fnArchRegVal(i+3), 
			8'd4, fnArchRegVal(i+4), 8'd5, fnArchRegVal(i+5), 8'd6, fnArchRegVal(i+6), 8'd7,  fnArchRegVal(i+7)
			);
		else
		*/
			$display("v%d -> %d/%d: %h%c %d/%d: %h%c %d/%d: %h%c %d/%d: %h%c %d/%d: %h%c %d/%d: %h%c %d/%d: %h%c %d/%d: %h%c #",
			i[7:0] >> 3'd3,
			i[7:0]+8'd0, fnPreg(i+0), fnArchRegVal(i+0), fnArchRegV(i+0)?"v":" ",
			i[7:0]+8'd1, fnPreg(i+1), fnArchRegVal(i+1), fnArchRegV(i+1)?"v":" ",
			i[7:0]+8'd2, fnPreg(i+2), fnArchRegVal(i+2), fnArchRegV(i+2)?"v":" ",
			i[7:0]+8'd3, fnPreg(i+3), fnArchRegVal(i+3), fnArchRegV(i+3)?"v":" ",
			i[7:0]+8'd4, fnPreg(i+4), fnArchRegVal(i+4), fnArchRegV(i+4)?"v":" ",
			i[7:0]+8'd5, fnPreg(i+5), fnArchRegVal(i+5), fnArchRegV(i+5)?"v":" ",
			i[7:0]+8'd6, fnPreg(i+6), fnArchRegVal(i+6), fnArchRegV(i+6)?"v":" ",
			i[7:0]+8'd7, fnPreg(i+7), fnArchRegVal(i+7), fnArchRegV(i+7)?"v":" "
			);

	$display("----- Rename %c ----- %s", ihit_ren ? "h":" ", stomp_ren ? stompstr : no_stompstr);
	$display("ip:%h.%h", pg_ren.hdr.ip.stream.stream,pg_ren.hdr.ip.pc);
	$display("REN: 0:%h  1:%h  2:%h  3:%h", pg_ren.pr[0].op.uop, pg_ren.pr[1].op.uop, pg_ren.pr[2].op.uop, pg_ren.pr[3].op.uop);
	/*
	$display("pc0: %x.%x ins0: %x  Rt: %d->%d%c  Rs: %d->%d%c  Ra: %d->%d%c  Rb: %d->%d%c  Rc: %d->%d%c",
		pg_ren.pr[0].pc.pc[23:0], pg_ren.pr[0].mcip, pg_ren.pr[0].uop[63:0],
		pg_ren.pr[0].nRt, Rt0_ren, Rt0_renv?"v":" ",
		pg_ren.pr[0].aRt, prn[3], prnv[3]?"v":" ",
		pg_ren.pr[0].aRa, prn[0], prnv[0]?"v": " ",
		pg_ren.pr[0].aRb, prn[1], prnv[1]?"v":" ",
		pg_ren.pr[0].aRc, prn[2], prnv[2]?"v":" ");
	$display("pc1: %x.%x ins1: %x  Rt: %d->%d%c  Rs: %d->%d%c  Ra: %d->%d%c  Rb: %d->%d%c  Rc: %d->%d%c", pg_ren.pr[1].pc.pc[23:0], pg_ren.pr[1].mcip, pg_ren.pr[1].uop[63:0], 
		pg_ren.pr[1].nRt, Rt1_ren, Rt1_renv?"v":" ",
		pg_ren.pr[1].aRt, prn[7], prnv[7]?"v":" ",
		pg_ren.pr[1].aRa, prn[4], prnv[4]?"v":" ",
		pg_ren.pr[1].aRb, prn[5], prnv[5]?"v":" ",
		pg_ren.pr[1].aRc, prn[6], prnv[6]?"v":" ");
	$display("pc2: %x.%x ins2: %x  Rt: %d->%d%c  Rs: %d->%d%c  Ra: %d->%d%c  Rb: %d->%d%c  Rc: %d->%d%c", pg_ren.pr[2].pc.pc[23:0], pg_ren.pr[2].mcip, pg_ren.pr[2].uop[63:0],
		pg_ren.pr[2].nRt, Rt2_ren, Rt2_renv?"v":" ",
		pg_ren.pr[2].aRt, prn[11], prnv[11]?"v":" ",
		pg_ren.pr[2].aRa, prn[8], prnv[8]?"v":" ",
		pg_ren.pr[2].aRb, prn[9], prnv[9]?"v":" ",
		pg_ren.pr[2].aRc, prn[10], prnv[10]?"v":" ");
	$display("pc3: %x.%x ins3: %x  Rt: %d->%d%c  Rs: %d->%d%c  Ra: %d->%d%c  Rb: %d->%d%c  Rc: %d->%d%c", pg_ren.pr[3].pc.pc[23:0], pg_ren.pr[3].mcip, pg_ren.pr[3].uop[63:0],
		pg_ren.pr[3].nRt, Rt3_ren, Rt3_renv?"v":" ",
		pg_ren.pr[3].aRt, prn[15], prnv[15]?"v":" ",
		pg_ren.pr[3].aRa, prn[12], prnv[12]?"v":" ",
		pg_ren.pr[3].aRb, prn[13], prnv[13]?"v":" ",
		pg_ren.pr[3].aRc, prn[14], prnv[14]?"v":" ");
	*/
//	$display("----- Queue Time ----- %s", (stomp_que && !stomp_quem) ? stompstr : no_stompstr);
	$display("----- Queue %c ----- %h", ihit_que ? "h":" ", qd);
	for (i = 0; i < Qupls4_pkg::ROB_ENTRIES; i = i + 1) begin
    $display("%c%c%c sn:%h %d: %c%c%c%c%c%c %c %c%c %d %c %c%d Rd%d/%d %h Rs%d/%d %h%c Rs1%d/%d=%h %c Rs2%d/%d=%h %c Rs3%d/%d=%h %c I=%h %h.%h cp:%h ins=%h #",
			(i[4:0]==head[0])?67:46, (i[4:0]==tails[0])?81:46, rob[i].rstp ? "r" : " ", rob[i].sn, i[5:0],
			rob[i].v?"v":"-", rob[i].done[0]?"d":"-", rob[i].done[1]?"d":"-", rob[i].out[0]?"o":"-", rob[i].out[1]?"o":"-", rob[i].bt?"t":"-", rob_memissue[i]?"i":"-", rob[i].lsq?"q":"-", (robentry_issue[i]|robentry_agen_issue[i])?"i":"-",
			robentry_islot[i], robentry_stomp[i]?"s":"-",
			(rob[i].op.decbus.cpytgt ? "c" : rob[i].op.decbus.fc ? "b" : rob[i].op.decbus.mem ? "m" : "a"),
			rob[i].op.uop.opcode, 
			rob[i].op.decbus.Rd, rob[i].op.nRd, rob[i].exc,
			rob[i].op.decbus.Rd, rob[i].op.pRd, rob[i].argT, rob[i].argT_v?"v":" ",
			rob[i].op.decbus.Rs1, rob[i].op.pRs1, rob[i].argA, rob[i].argA_v?"v":" ",
			rob[i].op.decbus.Rs2, rob[i].op.pRs2, rob[i].argB, rob[i].argB_v?"v":" ",
			rob[i].op.decbus.Rs3, rob[i].op.pRs3, rob[i].argC, rob[i].argC_v?"v":" ",
			rob[i].argI,
			rob[i].ip_stream, pgh[rob[i].pghn].ip.pc + {rob[i].ip_offs,1'b0},
			rob[i].cndx, rob[i].op.uop[63:0]);
	end
	$display("----- LSQ -----");
	for (i = 0; i < Qupls4_pkg::LSQ_ENTRIES; i = i + 1) begin
		$display("%c%c sn:%h %d: %d %c%c%c v%h p%h data:%h %c #", (i[2:0]==lsq_head.row)?72:46,(i[2:0]==lsq_tail.row)?84:46,
			lsq[i][0].sn, i[2:0],
			lsq[i][0].rndx,lsq[i][0].store ? "S": lsq[i][0].load ? "L" : "-",
			lsq[i][0].v?"v":" ",lsq[i][0].agen?"a":" ",lsq[i][0].vadr,lsq[i][0].padr,
			lsq[i][0].res[511:0],lsq[i][0].datav?"v":" "
		);
	end
	$display("----- AGEN -----");
	$display(" I=%h A=%h B=%h %c%h pc:%h #",
		agen0_rse.argI, agen0_rse.arg[0].val, agen0_rse.arg[1].val,
		 ((fnIsLoad(agen0_rse.uop) || fnIsStore(agen0_rse.uop)) ? 109 : 97),
		agen0_op, agen0_pc);
	$display("idle:%d res:%h rid:%d #", agen0_idle, agen0_res, agen0_rse.rndx);
	if (Qupls4_pkg::NAGEN > 1) begin
		$display(" I=%h A=%h B=%h %c%h pc:%h #",
			agen1_rse.argI, agen1_rse.arg[0].val, agen1_rse.arg[1].val,
			 ((fnIsLoad(agen1_rse.uop) || fnIsStore(agen1_rse.uop)) ? 109 : 97),
			agen1_op, agen1_pc);
		$display("idle:%d res:%h rid:%d #", agen1_idle, agen1_res, agen1_rse.rndx);
	end
	$display("----- Memory -----");
	$display("%d%c v%h p%h, %h %c%d %o #",
	    dram0, dram0_ack?"A":" ", dram0_work.vaddr, dram0_work.paddr, dram0_work.data, ((dram0_work.load || dram0_work.cload || dram0_work.cload_tags || dram0_work.store || dram0_work.cstore) ? 109 : 97), dram0_work.op, dram0_work.rndx);
	if (Qupls4_pkg::NDATA_PORTS > 1) begin
	$display("%d v%h p%h %h %c%d %o #",
	    dram1, dram1_work.vaddr, dram1_work.paddr, dram1_work.data, ((dram1_work.load || dram1_work.cload || dram1_work.cload_tags || dram1_work.store || dram1_work.cstore) ? 109 : 97), dram1_work.op, dram1_work.rndx);
	end
//	$display("%d %h %h %c%d %o #",
//	    dram2, dram2_addr, dram2_data, (fnIsFlowCtrl(dram2_op) ? 98 : (dram2_load || dram2_store) ? 109 : 97), 
//	    dram2_op, dram2_id);
	$display("%d %h %o %h #", dram0_oper.oper.v, dram0_work.data, dram0_work.rndx, dram0_oper.exc);
	$display("%d %h %o %h #", dram1_oper.oper.v, dram1_work.data, dram1_work.rndx, dram1_oper.exc);

	$display("----- FCU -----");
	$display("eval:%c A=%h B=%h I=%h", takb?"T":"F", fcu_rse.arg[0].val, fcu_rse.arg[1].val, fcu_rse.argI);
	$display("bt:%c pc=%h id=%d ", fcu_bt ? "T":"F", fcu_rse.pc, fcu_rse.rndx);
	$display("miss: %c misspc=%h.%h instr=%h disp=%h", branchmiss_det?"T":"F",fcu_misspc1.stream,fcu_misspc1.pc, fcu_rse.uop[63:0],
		{{37{fcu_instr.uop[63]}},fcu_instr.uop[63:44],3'd0}
	);

	$display("----- ALU -----");
	$display("%d I=%h T=%h A=%h B=%h C=%h %c%d pc:%h #",
		sau0_dataready, sau0_rse.argI, sau0_rse.arg[4].val, sau0_rse.arg[0].val, sau0_rse.arg[1].val, sau0_rse.arg[2].val,
		 ((fnIsLoad(sau0_rse.uop) || fnIsStore(sau0_rse.uop)) ? 109 : 97),
		sau0_instr, sau0_pc);
	$display("idle:%d res:%h rid:%d #", sau0_idle, sau0_resA, sau0_rse.rndx);

	if (Qupls4_pkg::NSAU > 1) begin
		$display("%d I=%h T=%h A=%h B=%h C=%h %c%d pc:%h #",
			sau1_dataready, sau1_rse.argI, sau1_rse.arg[4].val, sau1_rse.arg[0].val, sau1_rse.arg[1].val, sau1_rse.arg[2].val, 
			 ((fnIsLoad(sau1_rse.uop) || fnIsStore(sau1_rse.uop)) ? 109 : 97),
			sau1_rse.uop, sau1_rse.pc);
		$display("idle:%d res:%h rid:%d #", sau1_idle, sau1_resA, sau1_rse.rndx);
	end

	$display("----- Commit -----");
	$display("0: %h #", commit0_id);
	$display("1: %h #", commit1_id);
	$display("2: %h #", commit2_id);
	$display("3: %h #", commit3_id);

	$display("----- Stats -----");	
	IPC = real'(I)/real'(/*iact_cnt*/tick);
	PIPC = PIPC > IPC ? PIPC : IPC;
	$display("Clock ticks: %d Instructions: %d:%d IPC: %f Peak: %f", tick, I, IV, IPC, PIPC);
	$display("Copy targets: %d", cpytgts);
	$display("Stomped instructions: %d", stomped_insn);
	$display("Stalls for checkpoints: %d", rat_stalls);
	$display("Stalls due to renamer: %d", ren_stalls);
	$display("Stalls due to I-Cache miss: %d", tick - icache_cnt);
end
end
end
endgenerate
`endif

// ============================================================================
// Support functions and tasks
// ============================================================================

// Search for a prior flow control op. This forces flow control op to be performed
// in program order.

function fnPriorFC;
input rob_ndx_t ndx;
integer n;
begin
	fnPriorFC = FALSE;
	foreach (rob[n])
		if (rob[n].v==rob[ndx].v && rob[n].sn < rob[ndx].sn && rob[n].op.decbus.fc && !(&rob[n].done))
			fnPriorFC = TRUE;
end
endfunction

function fnPriorMem;
input rob_ndx_t ndx;
integer n;
begin
	fnPriorMem = FALSE;
	foreach (rob[n])
		if (rob[n].v==rob[ndx].v && rob[n].sn < rob[ndx].sn && rob[n].op.decbus.mem && !(&rob[n].done))
			fnPriorMem = TRUE;
end
endfunction

function fnPriorSync;
input rob_ndx_t ndx;
integer n;
begin
	fnPriorSync = FALSE;
	foreach (rob[n])
		if (rob[n].v==rob[ndx].v && rob[n].sn < rob[ndx].sn && rob[n].op.decbus.sync)
			fnPriorSync = TRUE;
end
endfunction

/*
task tZeroSyncDep;
input [5:0] syncno;
integer n3;
begin
	for (n3 = 0; n3 < ROB_ENTRIES; n3 = n3 + 1)
		if (rob[n3].sync_no==syncno)
			rob[n3].sync_no <= 6'd0;
end
endtask

task tZeroFcDep;
input [5:0] fcno;
integer n3;
begin
	for (n3 = 0; n3 < ROB_ENTRIES; n3 = n3 + 1)
		if (rob[n3].fc_no==fcno)
			rob[n3].fc_no <= 6'd0;
end
endtask
*/

task tInvalidateDependents;
input rob_ndx_t ndx;
input rob_ndx_t dndx;
begin
	if (rob[dndx].sn > rob[ndx].sn) begin
		if (rob[dndx].op.pRd==rob[ndx].op.nRd && 
			rob[dndx].op.pRd!=9'd0) begin
			rob[dndx].argT_v <= INV;
		end
	end
end
endtask

// Test if a predicate's IP is one instruction prior to an instruction. Only
// the least significant eight bits of the IP is checked since there are only
// a small number of instructions in the queue.

function fnPredPCMatch;
input [7:0] pc1;
input [7:0] pc2;
begin
	fnPredPCMatch = pc1==(pc2 - 8'd06);
end
endfunction

// Detect if an instruction has a predicate. Done by checking the IP values.
// A predicate will always have a IP value that is one instructions
// prior to the predicated one.

function fnHasPred;
input rob_ndx_t ndx;
integer n32;
begin
	fnHasPred = FALSE;
	fnHasPred = rob[ndx].predino > 4'd0;
	/*
	for (n32 = 0; n32 < ROB_ENTRIES; n32 = n32 + 1) begin
		if (rob[n32].v && rob[n32].op.decbus.pred 
		&& fnPredPCMatch(rob[n32].pc[7:0],rob[ndx].pc[7:0])
		&& !rob[ndx].op.decbus.vec
		&& rob[ndx].v)
			return (TRUE);
	end
	*/
end
endfunction

// Detect "stuck out" situation. Stuck out occurs if an instruction is marked
// out, but no-longer has a functional unit associated with it. Not sure why
// this happens but it hangs the machine when it does. So, the situation is
// detected and the machine set back to a prior to out state.

function fnStuckOut;
input rob_ndx_t n;
begin
	fnStuckOut = FALSE;
	if (|rob[n].out && rob[n].done==2'b00 && |rob[n].v && 
		!((n==sau0_id && !sau0_idle)
			|| (n==sau1_id && !sau1_idle)
			|| (n==fpu0_id && !fpu0_idle)
			|| (n==fpu1_id && !fpu1_idle)
			|| n==agen0_id
			|| n==agen1_id
			|| (n==fcu_rse.rndx && fcu_rse.v)
			))
	fnStuckOut = TRUE;
	if ((&rob[n].out) && (&rob[n].done) && rob[n].v)
		fnStuckOut = TRUE;
end
endfunction

// Set predicate status bits according to mask. Predicate status bits are set
// in groups of eight, since there may be a maximum of eight lanes in a 
// register if the lanes are byte sized.

function [7:0] fnPredStatus;
input [2:0] mask;
input [7:0] argA;
input [7:0] argB;
input [7:0] argC;
input [7:0] argD;
integer n30;
begin
	for (n30 = 0; n30 < 8; n30 = n30 + 1)
		case(mask)
		3'd0:	fnPredStatus[n30] = 1'b1;
		3'd1:	fnPredStatus[n30] = argA[n30];
		3'd2:	fnPredStatus[n30] = argB[n30];
		3'd3:	fnPredStatus[n30] = argC[n30];
		3'd3:	fnPredStatus[n30] = argD[n30];
		default:	fnPredStatus[n30] = 8'h00;
		endcase
end
endfunction

function fnValidate;
input pregno_t rg;
integer n;
begin
	fnValidate = FALSE;
	foreach (rob[n])
		if (rob[n].op.nRd==rg && rob[n].done==2'b11)
			fnValidate = TRUE;
end
endfunction

// Find the next non-NOP. Used to skip over constant zones.

function rob_ndx_t fnFindNextNonNop;
input rob_ndx_t st;
integer p1,p2,p3,p4,p5,p6;
begin
	p1 = (st + 1) % Qupls4_pkg::ROB_ENTRIES;
	p2 = (st + 2) % Qupls4_pkg::ROB_ENTRIES;
	p3 = (st + 3) % Qupls4_pkg::ROB_ENTRIES;
	p4 = (st + 4) % Qupls4_pkg::ROB_ENTRIES;
	p5 = (st + 5) % Qupls4_pkg::ROB_ENTRIES;
	p6 = (st + 6) % Qupls4_pkg::ROB_ENTRIES;
	if (!rob[p1].op.decbus.nop)
		fnFindNextNonNop = p1;
	else if (!rob[p2].op.decbus.nop)
		fnFindNextNonNop = p2;
	else if (!rob[p3].op.decbus.nop)
		fnFindNextNonNop = p3;
	else if (!rob[p4].op.decbus.nop)
		fnFindNextNonNop = p4;
	else if (!rob[p5].op.decbus.nop)
		fnFindNextNonNop = p5;
	else
		fnFindNextNonNop = p6;
end
endfunction


// Detect if there is a target register assignment acting as a source of data
// for the specified register. Used at commit time to verify that it is possible
// to supply data to all outstanding source operands.

function fnFindSource;
input rob_ndx_t ndx;
input aregno_t rg;
integer n;
begin
	fnFindSource = FALSE;
	foreach (rob[n]) begin
		if (rob[n].op.decbus.Rd==rg && rob[n].sn < rob[ndx].sn)
			fnFindSource = TRUE;
	end
end
endfunction

// Detect if a ROB entry already has an LSQ entry. Used at queue time to prevent
// the same ROB entry from using multiple LSQ entries.

function fnIsInLSQ;
input rob_ndx_t id;
integer n18r, n18c;
begin
	fnIsInLSQ = FALSE;
	for (n18r = 0; n18r < Qupls4_pkg::LSQ_ENTRIES; n18r = n18r + 1) begin
		for (n18c = 0; n18c < 2; n18c = n18c + 1) begin
			if (lsq[n18r][n18c].rndx==id && lsq[n18r][n18c].v==VAL) begin
				fnIsInLSQ = TRUE;
			end
		end
	end
end
endfunction

// Register name bypassing logic. The target register for the previous clock
// cycle will not have been updated in the RAT in time for it to be used in
// source register renames for the instructions queuing in the clock. So, the
// regnames are bypassed.
/*
task tBypassRegnames;
input rob_ndx_t ndx;
input Qupls4_pkg::pipeline_reg_t db;
input Qupls4_pkg::pipeline_reg_t pdb;
input Av;
input Bv;
input Cv;
input Tv;
input Mv;
begin
	if (pdb.v) begin
		if (db.decbus.Ra == pdb.decbus.Rt && !db.decbus.Raz) begin
			rob[ndx].op.pRa <= pdb.nRt;
			if (fnSourceAv(db) | db.decbus.has_imma | Av)
				rob[ndx].argA_v <= VAL;
			tAllArgsValid(ndx, fnSourceAv(db) | db.decbus.has_imma | Av, 1'b0, 1'b0, 1'b0, 1'b0);
		end
		if (db.decbus.Rb == pdb.decbus.Rt && !db.decbus.Rbz) begin
			rob[ndx].op.pRb <= pdb.nRt;
			if (fnSourceBv(db) | (db.decbus.has_Rb ? 1'b0 : db.decbus.has_immb) | Bv)
				rob[ndx].argB_v <= VAL;
			tAllArgsValid(ndx, 1'b0, fnSourceBv(db) | db.decbus.has_immb | Bv, 1'b0, 1'b0, 1'b0);
		end
		if (db.decbus.Rc == pdb.decbus.Rt && !db.decbus.Rcz) begin
			rob[ndx].op.pRc <= pdb.nRt;
			if (fnSourceCv(db) | db.decbus.has_immc | Cv)
				rob[ndx].argC_v <= VAL;
			tAllArgsValid(ndx, 1'b0, 1'b0, fnSourceCv(db) | db.decbus.has_immc | Cv, 1'b0, 1'b0);
		end
		if (db.decbus.Rt == pdb.decbus.Rt && !db.decbus.Rtz) begin
			rob[ndx].op.pRt <= pdb.nRt;
			if (fnSourceTv(db) | Tv)
				rob[ndx].argD_v <= VAL;
			tAllArgsValid(ndx, 1'b0, 1'b0, 1'b0, fnSourceTv(db) | Tv, 1'b0);
		end
		if (db.decbus.Rm == pdb.decbus.Rt) begin
			rob[ndx].op.pRm <= pdb.nRt;
			if (fnSourceMv(db) | Mv)
				rob[ndx].argM_v <= VAL;
			tAllArgsValid(ndx, 1'b0, 1'b0, 1'b0, 1'b0, fnSourceMv(db) | Mv);
		end
	end
end
endtask
*/

// It takes a clock cycle for the register file to update. An update matching
// the physical regno will not be valid until a cycle later. So, a pending
// valid flag is set. This flag is set to allow the real valid flag to be
// updated in the next cycle.
/*
task tValidateArg;
input rob_ndx_t nn;
input pregno_t Rt;
input v;
input value_t val;
begin
	if (rob[nn].argA_v == INV && rob[nn].op.pRa == Rt && rob[nn].v == VAL && v == VAL)
    rob[nn].argA_vp <= VAL;
	if (rob[nn].argB_v == INV && rob[nn].op.pRb == Rt && rob[nn].v == VAL && v == VAL)
    rob[nn].argB_vp <= VAL;
	if (rob[nn].argC_v == INV && rob[nn].op.pRc == Rt && rob[nn].v == VAL && v == VAL)
    rob[nn].argC_vp <= VAL;
	if (rob[nn].argD_v == INV && rob[nn].op.pRt == Rt && rob[nn].v == VAL && v == VAL)
    rob[nn].argD_vp <= VAL;
	if (rob[nn].argM_v == INV && rob[nn].op.pRm == Rt && rob[nn].v == VAL && v == VAL)
    rob[nn].argM_vp <= VAL;
`ifdef IS_SIM
	if (rob[nn].argA_v == INV && rob[nn].op.pRa == Rt && rob[nn].v == VAL && v == VAL)
    rob[nn].argA <= val;
	if (rob[nn].argB_v == INV && rob[nn].op.pRb == Rt && rob[nn].v == VAL && v == VAL)
    rob[nn].argB <= val;
	if (rob[nn].argD_v == INV && rob[nn].op.pRt == Rt && rob[nn].v == VAL && v == VAL)
    rob[nn].argD <= val;
	if (rob[nn].argM_v == INV && rob[nn].op.pRm == Rt && rob[nn].v == VAL && v == VAL)
    rob[nn].argM <= val;
`endif    
	if (rob[nn].argC_v == INV && rob[nn].op.pRc == Rt && rob[nn].v == VAL && v == VAL)
    rob[nn].argC <= val;
end
endtask	    
*/

// Called to invalidate ROB entries after a branch miss.

task tBranchInvalidate;
input rob_ndx_t ndx;
input cpytgt;
integer nn;
begin
//	rob[ndx].v <= cpytgt ? rob[ndx].v : 5'd0;
	rob[ndx].excv <= INV;
	rob[ndx].op.decbus.cpytgt <= cpytgt;
	if (cpytgt) begin
		rob[ndx].op.decbus.sau <= TRUE;
		rob[ndx].op.decbus.fpu <= FALSE;
		rob[ndx].op.decbus.fc <= FALSE;
		rob[ndx].op.decbus.mem <= FALSE;
		rob[ndx].op.uop.opcode <= Qupls4_pkg::OP_NOP;
		rob[ndx].done <= {FALSE,FALSE};
		rob[ndx].out <= {FALSE,FALSE};
	end
	else begin
		rob[ndx].done <= {TRUE,TRUE};
		rob[ndx].out <= {FALSE,FALSE};
	end
//		rob[ndx].cndx <= miss_cp;
	if (ndx==agen0_rse.rndx) begin
		if (dram0_work.rndx==agen0_rse.rndx)
			dram0_stomp <= TRUE;
	end
	if (Qupls4_pkg::NDATA_PORTS > 1) begin
		if (ndx==agen1_rse.rndx) begin
			if (dram1_work.rndx==agen1_rse.rndx)
				dram1_stomp <= TRUE;
		end
	end
	for (nn = 0; nn < Qupls4_pkg::ROB_ENTRIES; nn = nn + 1) begin
		if (robentry_stomp[nn] && rob[nn].sn < rob[ndx].sn && rob[nn].op.nRd==rob[ndx].op.pRd) begin
			if (rob[ndx].op.pRd!=9'd0)
				rob[ndx].argT_v <= INV;
		end
	end
end
endtask


// Used at commit time when the queue entry is no longer needed.

task tInvalidateQE;
input rob_ndx_t ndx;
begin
	rob[ndx].v <= 5'd0;
	rob[ndx].done <= {INV,INV};
	rob[ndx].out <= {INV,INV};
//	rob[ndx].lsq <= INV;
end
endtask

// Check if a QFEXT modifier made it to commit without having a following FPU
// operation. This should generally not happen, but if it does it would stall
// the machine. So, we just treat the QFEXT like a NOP and release the ALU so
// the machine can be on its way. Note that the QFEXT would block execution of
// other ALU ops, so it may act a bit like a SYNC instruction. Another option
// may be to exception.

task tCheckQFExtDone;
input rob_ndx_t head;
begin
	if (|rob[head].v && rob[head].op.decbus.qfext && !rob[(head+1)%Qupls4_pkg::ROB_ENTRIES].op.decbus.fpu && sau0_id==head) begin
		if (rob[head].done!=2'b11) begin
			sau0_idle1 <= TRUE;
			sau0_idv <= INV;
			sau0_done <= TRUE;
	    rob[sau0_id].done <= 2'b11;
			rob[sau0_id].out <= {INV,INV};
		end
	end
end
endtask


// Invalidate LSQ entries associated with a ROB entry.
// Note that only valid entries are invalidated as invalid entries may be
// about to be used by enqueue logic.

task tInvalidateLSQ;
input integer n;
input rob_ndx_t id;
input can;
input cmt;
input value_t data;
integer n18r, n18c;
begin
	n18r = rob[id].lsqndx.row;
	n18c = rob[id].lsqndx.col;
	rob[id].lsq <= FALSE;
//	if (lsq[n18r][n18c].v==VAL) begin
		lsq_cmd[n].cmd <= LSQ_CMD_INV;
		lsq_cmd[n].lndx <= rob[id].lsqndx;
		lsq_cmd[n].rndx <= id;
		lsq_cmd[n].n <= 0;
		lsq_cmd[n].cmt <= cmt;
		lsq_cmd[n].can <= can;
		lsq_cmd[n].data <= data;
		lsq_cmd[n].flags <= 0;
		lsq_cmd[n].datav <= INV;
//				lsq_cmd_ndx = lsq_cmd_ndx + 2'd1;
		// It is possible that a load operation already in progress got
		// cancelled.
		if (dram0_work.rndx==id)
			dram0_stomp <= TRUE;
		if (Qupls4_pkg::NDATA_PORTS > 1 && dram1_work.rndx==id)
			dram1_stomp <= TRUE;
		if (can)
			cpu_request_cancel[id] <= 1'b1;
//	end
end
endtask


// Increment LSQ virtual address to next page and trigger agen again.

task tIncLSQAddr;
input integer n;
input rob_ndx_t id;
begin
	lsq_cmd[n].cmd <= LSQ_CMD_INCADR;
	lsq_cmd[n].lndx <= rob[id].lsqndx;
	lsq_cmd[n].rndx <= id;
	lsq_cmd[n].n <= 0;
	lsq_cmd[n].cmt <= FALSE;
	lsq_cmd[n].can <= FALSE;
	lsq_cmd[n].data <= 0;
	lsq_cmd[n].flags <= 0;
	lsq_cmd[n].datav <= INV;
//				lsq[n18r][n18c].shift <= lsq[n18r][n18c].shift2;
end
endtask


// Update the address fields in the LSQ entries.
// Invoked once the address has been translated.

task tSetLSQ;
input integer n;
input rob_ndx_t id;
input address_t padr;
begin
	lsq_cmd[n].cmd <= LSQ_CMD_SETADR;
	lsq_cmd[n].lndx <= rob[id].lsqndx;
	lsq_cmd[n].rndx <= id;
	lsq_cmd[n].n <= 0;
	lsq_cmd[n].cmt <= FALSE;
	lsq_cmd[n].can <= FALSE;
	lsq_cmd[n].data <= padr;
	lsq_cmd[n].flags <= 0;
	lsq_cmd[n].datav <= INV;
end
endtask


// Reset.
// A lot of resets to keep simulation happy.

task tReset;
begin
	I <= 0;
	IV <= 0;
	vl <= 5'd8;
	macro_queued <= FALSE;
	for (n14 = 0; n14 < 5; n14 = n14 + 1) begin
		kernel_vectors[n14] <= 32'hFFFFFC00;
		syscall_vectors[n14] <= 32'hFFFFFC00;
	end
	next_pending_ipl <= 6'd63;
	err_mask <= 64'd0;
	excir <= {26'd0,Qupls4_pkg::OP_NOP};
	excmiss <= FALSE;
	excmisspc.stream <= 5'd1;
	excmisspc.pc <= 32'hFFFFFFC0;
	excret <= FALSE;
	exc_ret_pc <= 32'hFFFFFFC0;
	exc_ret_pc.stream <= 5'd1;
	exc_ret_carry_mod <= 32'd0;
	sr <= 64'd0;
	sr.pl <= 8'hFF;					// highest priority
	sr.om <= Qupls4_pkg::OM_SECURE;
	sr.dbg <= TRUE;
	sr.ipl <= 6'd63;				// non-maskable interrupts only
	/* This must be setup by software
	sr_stack[0] <= 64'd0;
	sr_stack[0].pl <= 8'hFF;
	sr_stack[0].om <= OM_SECURE;
	sr_stack[0].dbg <= FALSE;
	sr_stack[0].ipl <= 6'd63;
	pc_stack[0] <= 
	*/
	asid_reg <= 64'd0;
	ip_asid <= 16'd0;
//	postfix_mask <= 'd0;
	dram0_stomp <= 32'd0;
	dram0_ldip <= FALSE;
	dram1_stomp <= 32'd0;
	panic <= `PANIC_NONE;
	foreach (rob[n14]) begin
		rob[n14] <= {$bits(Qupls4_pkg::rob_entry_t){1'd0}};
		rob[n14].sn <= 8'd0;
		rob[n14].exc <= Qupls4_pkg::FLT_NONE;
		rob[n14].op.decbus.cause <= Qupls4_pkg::FLT_NONE;
		rob[n14].op.exc <= Qupls4_pkg::FLT_NONE;
	end
	/*
	for (n14 = 0; n14 < BEB_ENTRIES; n14 = n14 + 1) begin
		beb[n14] <= {$bits(beb_entry_t){1'd0}};
	end
	*/
	sau0_available <= 1;
	sau0_dataready <= 0;
	sau1_available <= 1;
	sau1_dataready <= 0;
	sau0_out <= INV;
	sau1_out <= INV;
	fpu0_out <= INV;
	fpu0_idle <= TRUE;
	fpu0_available <= 1;
	fpu0_idv <= INV;
	fpu0_done1 <= FALSE;
	fpu1_idle <= TRUE;
	fpu1_idv <= INV;
	fpu1_done1 <= FALSE;
	fcu_available <= 1;
//	fcu_exc <= FLT_NONE;
	fcu_state1 <= INV;
//	fcu_branch_resolved <= INV;
	fcu_v3 <= INV;
	fcu_v4 <= INV;
	fcu_v5 <= INV;
	fcu_v6 <= INV;
//	fcu_idle <= TRUE;
//	fcu_idv <= INV;
	fcu_bl <= FALSE;
	fcu_new <= FALSE;
	brtgtv <= INV;
	brtgtvr <= INV;
//	fcu_argC <= 'd0;
	/*
	for (n11 = 0; n11 < Qupls4_pkg::NDATA_PORTS; n11 = n11 + 1) begin
		dramN[n11] <= 'd0;
		dramN_load[n11] <= 'd0;
		dramN_loadz[n11] <= 'd0;
		dramN_store[n11] <= 'd0;
		dramN_addr[n11] <= 'd0;
		dramN_data[n11] <= 'd0;
		dramN_sel[n11] <= 'd0;
		dramN_ack[n11] <= 'd0;
		dramN_memsz[n11] <= Thor2024pkg::nul;
		dramN_tid[n11] = {4'd0,n11[0],3'd0};
	end
	*/
	grplen[0] <= 6'd0;
	grplen[1] <= 6'd0;
	grplen[2] <= 6'd0;
	grplen[3] <= 6'd0;
	group_len <= 6'd0;
	last[0] <= 1'b1;
	last[1] <= 1'b1;
	last[2] <= 1'b1;
	last[3] <= 1'b1;
	tails[0] <= 5'd0;
	head[0] <= 5'd0;
	lsq_head <= 3'd0;
	sau0_idle1 <= TRUE;
	sau1_idle1 <= TRUE;
	sau0_done <= TRUE;
	sau1_done <= TRUE;
	sau0_idv <= INV;
	sau1_idv <= INV;
	brtgtv <= FALSE;
	pc_in_sync <= TRUE;
	ls_bmf <= 1'd0;
	reg_bitmask <= 64'd0;
	commit0_id <= Qupls4_pkg::ROB_ENTRIES-4;
	commit1_id <= Qupls4_pkg::ROB_ENTRIES-3;
	commit2_id <= Qupls4_pkg::ROB_ENTRIES-2;
	commit3_id <= Qupls4_pkg::ROB_ENTRIES-1;
	commit_br0 <= FALSE;
	commit_call0 <= FALSE;
	commit_ret0 <= FALSE;
	commit_jmp0 <= FALSE;
	commit_br1 <= FALSE;
	commit_call1 <= FALSE;
	commit_ret1 <= FALSE;
	commit_jmp1 <= FALSE;
	commit_br2 <= FALSE;
	commit_call2 <= FALSE;
	commit_ret2 <= FALSE;
	commit_jmp2 <= FALSE;
	commit_br3 <= FALSE;
	commit_call3 <= FALSE;
	commit_ret3 <= FALSE;
	commit_jmp3 <= FALSE;
	pack_regs <= FALSE;
	scale_regs <= 3'd4;
	sau0_stomp <= FALSE;
	sau1_stomp <= FALSE;
	fpu0_stomp <= FALSE;
	fpu1_stomp <= FALSE;
	dram0_stomp <= FALSE;
	dram1_stomp <= FALSE;
	agen0_idv <= INV;
	agen1_idv <= INV;
	stompstr <= "(stomped)";
	no_stompstr <= "         ";
	vgm <= 64'hFFFFFFFFFFFFFFFF;
	for (n14 = 0; n14 < 4; n14 = n14 + 1) begin
		vrm[n14] <= 64'hFFFFFFFFFFFFFFFF;
		vex[n14] <= 64'h0;
	end
	vn <= 2'd0;
	mc_orid <= 5'd0;
	icdp <= 32'hFFFFFBC0;
	predino = 4'd0;
	predrndx = 5'd0;
	cpu_request_cancel <= {Qupls4_pkg::ROB_ENTRIES{1'b0}};
	groupno <= {$bits(seqnum_t){1'b0}};
	sync_no <= 6'd0;
	fc_no <= 6'd0;
	/*
	advance_msi <= FALSE;
	advance_irq_fifo <= FALSE;
	*/
	irq_wr_en <= FALSE;
	
	irq_downcount <= 8'd00;
	irq_downcount_base <= 8'd10;
	
	ssm_flag <= FALSE;
	pred_alloc_map <= 32'h0;
	flush_pipeline <= 1'b0;
	cp_stall <= 1'b0;
	loadflags_buf <= 256'd0;
	storeflags_buf <= 256'd0;
	thread_probability[0] <= 8'hFF;
	thread_probability[1] <= 8'h00;
	thread_probability[2] <= 8'h00;
	thread_probability[3] <= 8'h00;
	thread_probability[4] <= 8'h00;
	thread_probability[5] <= 8'h00;
	thread_probability[6] <= 8'h00;
	thread_probability[7] <= 8'h00;
	foreach (pred_done[n14])
		pred_done[n14] <= TRUE;
	foreach (pred_ins_done[n14])
		pred_ins_done[n14] <= 8'hFF;
	foreach (pred_buf[n14])
		pred_buf[n14] <= value_zero;
end
endtask

task tEnqueGroupHdr;
input seqnum_t sn;
input [7:0] tail;
input Qupls4_pkg::pipeline_group_reg_t pg;
begin
	pgh[tail].v <= VAL;
	pgh[tail].cndxv <= INV;
	pgh[tail].chkpt_freed <= FALSE;
	pgh[tail].sn <= sn;
	/*
	pgh[tail>>2].has_branch <= |(
		db0.brclass|
		db1.brclass|
		db2.brclass|
		db3.brclass
		);
	*/
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Queue instruction.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tEnque;
input seqnum_t sn;
input seqnum_t grp;
input Qupls4_pkg::rob_entry_t robe;
input pt;
input rob_ndx_t tail;
input flush;
input stomp;
input ornop;
input checkpt_ndx_t cndxq;
input checkpt_ndx_t pndxq;
input rob_ndx_t grplen;
input last;
integer n12;
integer n13;
Qupls4_pkg::decode_bus_t db;
Qupls4_pkg::rob_entry_t next_robe;
reg [5:0] next_sync_no;
reg [5:0] next_fc_no;
reg [2:0] dtail;
cpu_types_pkg::pc_address_ex_t next_brtgt;
reg next_brtgtv;
begin
	dtail = {1'b0,tail[1:0]};
	db = robe.op.decbus;

	/*
	if (FALSE) begin
		next_sync_no = sync_no + 2'd1;
		if (next_sync_no==6'd0)
			next_sync_no = 6'd1;
		if (db.sync)
			sync_no <= next_sync_no;

		next_fc_no = fc_no + 2'd1;
		if (next_fc_no==6'd0)
			next_fc_no = 6'd1;
		if (db.fc)
			fc_no <= next_fc_no;

		rob[tail].sync_no <= db.sync ? next_sync_no : 6'd0;
		rob[tail].sync_dep <= sync_no;
		rob[tail].fc_no <= db.fc ? next_fc_no : 6'd0;
		rob[tail].fc_dep <= fc_no;
	end
	*/
	// Drop the in-order pipeline register onto the queue.
	next_robe = robe;
	next_robe.this_ndx = tail;
	next_robe.pghn = tail/MWIDTH;
	next_robe.pghn_irq = tail/MWIDTH;
	next_robe.flush = flush;
	next_robe.sync_dep = sync_ndx;
	next_robe.sync_depv = sync_ndxv;
	next_robe.fc_dep = fc_ndx;
	next_robe.fc_depv = fc_ndxv;

	// "dynamic" fields, these fields may change after enqueue
	next_robe.sn = sn;
	next_robe.pred_tf = 2'b00;	// unknown
//	next_robe.pred_shadow_size = db.pred_shadow_size;
	// NOPs are valid regardless of predicate status
	next_robe.pred_bitv = db.nop;
	next_robe.pred_bit = db.nop;
//	if (db.pred)
//		pred_tf[db.pred_no] <= 2'b00;
	
	next_robe.orid = mc_orid;
	next_robe.br_cndx = cndxq;

//		else
//			next_robe.done = {VAL,INV};
	next_robe.out = {INV,INV};
	next_robe.lsq = INV;
	next_robe.takb = 1'b0;

	// Check for decode exception, but not if it is being stomped on.
	// If it is stomped on, we do not care.
	if (!(ornop|stomp)) begin
		next_robe.exc = db.cause;
		next_robe.excv = db.cause != Qupls4_pkg::FLT_NONE;
	end
	else begin
		next_robe.exc = Qupls4_pkg::FLT_NONE;
		next_robe.excv = FALSE;
	end
	next_robe.argA_v = Qupls4_pkg::fnSourceRs1v(robe.op) | db.has_imma;
	next_robe.argB_v = Qupls4_pkg::fnSourceRs2v(robe.op) | (db.has_Rs2 ? 1'b0 : db.has_immb);
	next_robe.argC_v = Qupls4_pkg::fnSourceRs3v(robe.op) | db.has_immc;
	next_robe.argD_v = Qupls4_pkg::fnSourceRs4v(robe.op);
	next_robe.argS_v = Qupls4_pkg::fnSourceArgSv(robe.op);
	next_robe.argT_v = Qupls4_pkg::fnSourceRdv(robe.op);
	if (db.Rs1z)
		next_robe.argA_v = VAL;
	if (db.Rs2z)
		next_robe.argB_v = VAL;
	if (db.Rs3z)
		next_robe.argC_v = VAL;
	// In some cases all the register values are essentially valid already, so
	// indicate that the register read is done. This lets dispatch dispatch the
	// instruction sooner.
	next_robe.reg_read_done = RL_STRATEGY == 1 ? TRUE : 
		(Qupls4_pkg::fnSourceRs1v(robe.op) | db.has_imma) && 
		(Qupls4_pkg::fnSourceRs2v(robe.op) | (db.has_Rs2 ? 1'b0 : db.has_immb)) && 
		(Qupls4_pkg::fnSourceRs3v(robe.op) | db.has_immc) &&
		Qupls4_pkg::fnSourceRs4v(robe.op) && 
		Qupls4_pkg::fnSourceArgSv(robe.op) &&
		Qupls4_pkg::fnSourceRdv(robe.op)
		;
	next_robe.all_args_valid = FALSE;
	/*
		(fnSourceRs1v(ins) | db.has_imma) &&
		(fnSourceRs2v(ins) | (db.has_Rb ? 1'b0 : db.has_immb)) &&
		(fnSourceRs3v(ins) | db.has_immc) &&
		(fnSourceRdv(ins)) &&
		(fnSourceCiv(ins))
		;
	*/
	next_robe.could_issue = FALSE;
	next_robe.could_issue_nm = FALSE;
	// "static" fields, these fields remain constant after enqueue
	next_robe.grp = grp;
	next_robe.brtgt = Qupls4_pkg::fnTargetIP(pgh[robe.pghn].ip.pc + {robe.ip_offs,1'b0},db.immc);
	// Set the interrupt return address to this instruction.
	next_robe.eip = pgh[robe.pghn].ip.pc + {robe.ip_offs,1'b0};
	next_robe.om = sr.om;
	next_robe.rm = db.rm==3'd7 ? fpcsr.rm : db.rm;
`ifdef IS_SIM
	next_robe.argI = db.immb;
`endif	
//	next_robe.rmd = fpscr.rmd;
//	next_robe.op = ins;
	next_robe.cndx = cndxq;//db.br ? pndxq : cndxq;
	// Architectural register zero is not renamed, physical register zero is
	// used which will always read as zero. The renamer will not assign
	// physical register zero when registers are being renamed.
//	next_robe.op.nRt = nRt;//db.Rtz ? 10'd0 : nRt;
	next_robe.group_len = grplen;
	next_robe.last = last;
//	next_robe.v = Qupls4_pkg::SUPPORT_BACKOUT ? (robe.op.v ? robe.ip_stream : 5'd0): (robe.op.v ? robe.ip_stream & ~{8{stomp}} : 5'd0);
	next_robe.v = robe.v;
//	next_robe.v = 5'd1;
	if (!stomp && db.v && !brtgtv) begin
		if (db.br & pt) begin
			next_brtgt = Qupls4_pkg::fnTargetIP(pgh[robe.pghn].ip.pc,db.immc);
			next_brtgtv = VAL;	// ToDo: Fix
		end
	end
	// Vector instructions are treated as NOPs as they expand into scalar ops.
	// Should not see any vector instructions at queue time.
	// If the instruction enqueues it must have been through the renamer.
	// Propagate the target register to the new target by turning the instruction
	// into a copy-target.
	if (db.nop) begin
		next_robe.op.decbus.sau = FALSE;
		next_robe.op.decbus.fpu = FALSE;
		next_robe.op.decbus.fc = FALSE;
		next_robe.op.decbus.load = FALSE;
		next_robe.op.decbus.vload = FALSE;
		next_robe.op.decbus.vload_ndx = FALSE;
		next_robe.op.decbus.store = FALSE;
		next_robe.op.decbus.vstore = FALSE;
		next_robe.op.decbus.vstore_ndx = FALSE;
		next_robe.op.decbus.mem = FALSE;
		// Instructions with NOP semantics are already done, they do not need to be
		// processed further.
		next_robe.done = {VAL,VAL};
	end

	if (ornop|(Qupls4_pkg::SUPPORT_BACKOUT ? 1'b0 : stomp)) begin
		next_robe.op.decbus.cpytgt = TRUE;
		next_robe.op.decbus.sau = TRUE;
		next_robe.op.decbus.fpu = FALSE;
		next_robe.op.decbus.fc = FALSE;
		next_robe.op.decbus.load = FALSE;
		next_robe.op.decbus.vload = FALSE;
		next_robe.op.decbus.vload_ndx = FALSE;
		next_robe.op.decbus.store = FALSE;
		next_robe.op.decbus.vstore = FALSE;
		next_robe.op.decbus.vstore_ndx = FALSE;
		next_robe.op.decbus.mem = FALSE;
//		next_robe.op.ins = {57'd0,OP_NOP};
//		next_robe.argA_v = VAL;
		next_robe.argB_v = VAL;
		next_robe.argC_v = VAL;
		next_robe.argD_v = VAL;
		next_robe.argT_v = VAL;
//		next_robe.argD_v = VAL;
//		next_robe.argM_v = VAL;
//		next_robe.done = {TRUE,TRUE};
	end
	
	// In the shadow of a BSR a target register may be assigned by the renamer.
	// There is not an easy way to undo this assignment, so we keep it and modify
	// the instruction to be a NOP operation.
//	else if (stomp)
//		next_robe.op.decbus.cpytgt = TRUE;
	next_robe.rat_v = INV;
	rob[tail] <= next_robe;
	brtgt <= next_brtgt;
	brtgtv <= next_brtgtv;
	// under construction
	// What gets put into the ROB gets put into the dispatch buffer.
//	dbf[dtail] <= next_robe;
end
endtask

task tAllArgsValid;
input rob_ndx_t ndx;
input Av;
input Bv;
input Cv;
input Dv;
input Tv;
begin
	
	if (Av) rob[ndx].argA_v <= VAL;
	if (Bv) rob[ndx].argB_v <= VAL;
	if (Cv) rob[ndx].argC_v <= VAL;
	if (Dv) rob[ndx].argD_v <= VAL;
	if (Tv) rob[ndx].argT_v <= VAL;
	rob[ndx].all_args_valid <=
		(rob[ndx].argA_v | Av) &&
		(rob[ndx].argB_v | Bv) &&
		(rob[ndx].argC_v | Cv) &&
		(rob[ndx].argD_v | Dv) &&
		(rob[ndx].argT_v | Tv) &&
		(rob[ndx].pred_bit)
	;
	
end
endtask

// Queue to the load / store queue.

task tEnqueLSE;
input Qupls4_pkg::lsq_ndx_t ndx;
input rob_ndx_t id;
input [3:0] n;
input cpu_types_pkg::virtual_address_t vadr;
integer n1;
begin
	lsq_cmd[n].cmd <= LSQ_CMD_ENQ;
	lsq_cmd[n].lndx <= ndx;
	lsq_cmd[n].rndx <= id;
	lsq_cmd[n].n <= n;
	lsq_cmd[n].data <= vadr;
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Commit miscellaneous instructions to machine state.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tOddballCommit;
input v;
input rob_ndx_t head;
begin
	/*
	if (rob[head].op.decbus.boi) begin
		if (rob[head].bt) begin
			if (rob[head].v) begin
				// Ensure interrupts are still enabled.
				if (sr.mie || pgh[head[5:2]].irq.level==6'd63)
					tProcessExc(head,rob[head].op.pc,rob[head].op.uop.num,TRUE,FALSE);
				// The IRQ processing should not have been taken, it is a branch miss.
				else begin
					excir <= rob[head].op;
					excid <= head;
					excmissgrp <= head>>2;
					excmisspc.pc <= rob[head].op.pc;
					excmiss <= TRUE;
					irq_wr_en <= TRUE;
					irq2_din <= pgh[head[5:2]].irq;
				end
			// If instruction got invalidated, write the IRQ to the FIFO so it may
			// be picked up again.
			else begin
				excir <= rob[head].op;
				excid <= head;
				excmissgrp <= head>>2;
				excmisspc.pc <= rob[head].op.pc;
				excmiss <= TRUE;
				irq_wr_en <= TRUE;
				irq2_din <= pgh[head[5:2]].irq;
			end
		end
		// else: Here there was no interrupt, nothing to do.
	end
	*/
	if (v) begin
		if (!rob[head].op.decbus.cpytgt) begin
			if (rob[head].op.decbus.csr) begin
				case(rob[head].op.uop.op3[1:0])
				2'd0:	;	// readCSR
				2'd1:	tWriteCSR(rob[head].arg,{2'b0,rob[head].op.uop.imm2[13:0]});
				2'd2:	tSetbitCSR(rob[head].arg,{2'b0,rob[head].op.uop.imm2[13:0]});
				2'd3:	tClrbitCSR(rob[head].arg,{2'b0,rob[head].op.uop.imm2[13:0]});
				endcase
			end
			else if (rob[head].op.decbus.irq)
				;
			else if (rob[head].op.decbus.brk)
				tProcessExc(head,pgh[rob[head].pghn].ip.pc+{rob[head].ip_offs,1'b0}+32'd6,rob[head].op.uop.num);
			else if (rob[head].op.decbus.sys)
				tProcessExc(head,pgh[rob[head].pghn].ip.pc+{rob[head].ip_offs,1'b0}+32'd6,rob[head].op.uop.num);
			else if (rob[head].op.decbus.eret)
				tProcessEret(rob[head].op[22:19]==5'd2,rob[head].op[23]==1'b1);
			else if (rob[head].op.decbus.rex)
				tRex(head,rob[head].op);
		end
		// If interrupts are still enabled at commit, go do interrupt processing.
		if (rob[head].op.hwi && pgh[rob[head].pghn_irq].hwi && pgh[rob[head].pghn_irq].irq.level == 6'd63)	// NMI
			tProcessHwi(head,rob[head].op.uop.num,FALSE,TRUE);
		else if (rob[head].op.hwi && pgh[rob[head].pghn_irq].hwi && pgh[rob[head].pghn_irq].irq.level > sr.ipl && sr.mie)
			tProcessHwi(head,rob[head].op.uop.num,TRUE,FALSE);
		// If interrupt turned out to be disabled reload the IRQ at the fetch stage,
		// but only after loading some other instructions. Put the irq on a queue for
		// later processing. Note that the interrupt enable level has been set to
		// disable further interrupts. So, instruction fetch should be able to 
		// continue with the desired stream.
		// Instruction was valid, but interrupts were disabled.
		else if (pgh[rob[head].pghn_irq].hwi) begin
			irq_wr_en <= TRUE;
			irq2_din <= pgh[rob[head].pghn_irq].irq;
			irq_downcount <= irq_downcount_base;
			irq_downcount_base <= {irq_downcount_base,1'b0} | 8'd8;
			excir <= rob[head].op;
			excid <= head;
			excmissgrp <= rob[head].pghn;
			excmisspc.pc <= rob[head].eip;
			excmiss <= TRUE;
			set_pending_ipl <= TRUE;
			next_pending_ipl <= pgh[rob[head].pghn_irq].old_ipl;	// restore IPL
			sr.ipl <= pgh[rob[head].pghn_irq].old_ipl;
			if (irq_downcount_base[7])
				tProcessExc(head,rob[head].eip,rob[head].op.uop.num);
		end
	end
	// If the instruction got invalidated (eg branch) there is not an easy way to
	// know what address a hardware interrupt should change flow to. So,
	// just put the interrupt into a FIFO to be redone later.
	// The branch will have already reset the fetch pointer.
	else if (pgh[rob[head].pghn_irq].hwi) begin
		irq_wr_en <= TRUE;
		irq2_din <= pgh[rob[head].pghn_irq].irq;
		irq_downcount <= irq_downcount_base;
		irq_downcount_base <= {irq_downcount_base,1'b0} | 8'd8;
		if (irq_downcount_base[7])
			tProcessExc(head,rob[head].eip,rob[head].op.uop.num);
		set_pending_ipl <= TRUE;
		next_pending_ipl <= pgh[rob[head].pghn_irq].old_ipl;	// restore IPL
		sr.ipl <= pgh[rob[head].pghn_irq].old_ipl;
	end
	
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// CSR Read / Update tasks
//
// Important to use the correct assignment type for the following, otherwise
// The read won't happen until the clock cycle.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tReadCSR;
output value_t res;
input [15:0] regno;
begin
	if (Qupls4_pkg::operating_mode_t'(regno[13:12]) <= sr.om) begin
		$display("regno: %h, om=%d", regno, sr.om);
		casez(regno[15:0])
		Qupls4_pkg::CSR_MCORENO:	res = coreno_i;
		Qupls4_pkg::CSR_SR:		res = sr;
		Qupls4_pkg::CSR_TICK:	res = tick;
		Qupls4_pkg::CSR_ASID:	res = asid_reg;
		Qupls4_pkg::CSR_THREAD_WEIGHT:	
			res = {thread_probability[7],thread_probability[6],thread_probability[5],thread_probability[4],
						thread_probability[3],thread_probability[2],thread_probability[1],thread_probability[0]};
		16'h3080:	res = sr_stack[0];
		(Qupls4_pkg::CSR_MEPC+0):	res = pc_stack[0];
		16'b0011000000110???:	res = kernel_vectors[regno[2:0]];
		16'b0010000000110???:	res = kernel_vectors[regno[2:0]];
		16'b0001000000110???:	res = kernel_vectors[regno[2:0]];
		16'b0011000000111???:	res = syscall_vectors[regno[2:0]];
		16'b0010000000111???:	res = syscall_vectors[regno[2:0]];
		16'b0001000000111???:	res = syscall_vectors[regno[2:0]];
		/*
		CSR_SCRATCH:	res = scratch[regno[13:12]];
		CSR_MHARTID: res = hartid_i;
		CSR_MCR0:	res = cr0|(dce << 5'd30);
		CSR_PTBR:	res = ptbr;
		CSR_HMASK:	res = hmask;
		CSR_KEYS:	res = keys2[regno[0]];
		CSR_SEMA: res = sema;
//		CSR_FSTAT:	res = fpscr;
		CSR_MBADADDR:	res = badaddr[regno[13:12]];
		CSR_CAUSE:	res = cause[regno[13:12]];
		CSR_MTVEC:	res = tvec[regno[1:0]];
		CSR_UCA:
			if (regno[3:0]==4'd7)
				res = xip.offs;
			else if (regno[3:0] < 4'd8)
				res = xca.offs;
			else
				res = 64'd0;
		CSR_MCA,CSR_HCA,CSR_SCA:
			if (regno[3:0]==4'd7)
				res = xip.offs;
			else
				res = xca.offs;
		CSR_MPLSTACK:	res = plStack;
		CSR_MPMSTACK:	res = pmStack;
		CSR_MVSTEP:	res = estep;
		CSR_MVTMP:	res = vtmp;
		CSR_TIME:	res = wc_time;
		CSR_MSTATUS:	res = status[3];
		CSR_MTCB:	res = tcbptr;
//		CSR_DSTUFF0:	res = stuff0;
//		CSR_DSTUFF1:	res = stuff1;
		*/
		default:	res = 64'd0;
		endcase
	end
	else
		res = 64'd0;
end
endtask

task tWriteCSR;
input value_t val;
input [15:0] regno;
begin
	if (Qupls4_pkg::operating_mode_t'(regno[13:12]) <= sr.om) begin
		casez(regno[15:0])
		Qupls4_pkg::CSR_SR:		
			begin
				sr <= val;
				set_pending_ipl <= TRUE;
				next_pending_ipl <= val[10:5];
				irq_downcount_base <= 4'd8;
			end
		Qupls4_pkg::CSR_ASID: 	asid_reg <= val;
		Qupls4_pkg::CSR_THREAD_WEIGHT:
			begin
				if (val[31:0]==32'd0) begin
					thread_probability[0] <= 8'h1F;
					thread_probability[1] <= 8'h1F;
					thread_probability[2] <= 8'h1F;
					thread_probability[3] <= 8'h1F;
					thread_probability[4] <= 8'h1F;
					thread_probability[5] <= 8'h1F;
					thread_probability[6] <= 8'h1F;
					thread_probability[7] <= 8'h1F;
				end
				else begin
					thread_probability[0] <= val[7:4];
					thread_probability[1] <= val[15:8];
					thread_probability[2] <= val[23:16];
					thread_probability[3] <= val[31:24];
					thread_probability[4] <= val[39:32];
					thread_probability[5] <= val[47:40];
					thread_probability[6] <= val[55:48];
					thread_probability[7] <= val[63:56];
				end
			end
		16'h3080: sr_stack[0] <= val[31:0];
		Qupls4_pkg::CSR_MEPC:	pc_stack[0] <= val;
		16'b0011000000110???:	kernel_vectors[regno[2:0]] <= val;
		16'b0010000000110???:	kernel_vectors[regno[2:0]] <= val;
		16'b0001000000110???:	kernel_vectors[regno[2:0]] <= val;
		16'b0011000000111???:	syscall_vectors[regno[2:0]] <= val;
		16'b0010000000111???:	syscall_vectors[regno[2:0]] <= val;
		16'b0001000000111???:	syscall_vectors[regno[2:0]] <= val;
		/*
		CSR_SCRATCH:	scratch[regno[13:12]] <= val;
		CSR_MCR0:		cr0 <= val;
		CSR_PTBR:		ptbr <= val;
		CSR_HMASK:	hmask <= val;
		CSR_SEMA:		sema <= val;
		CSR_KEYS:		keys2[regno[0]] <= val;
//		CSR_FSTAT:	fpscr <= val;
		CSR_MBADADDR:	badaddr[regno[13:12]] <= val;
		CSR_CAUSE:	cause[regno[13:12]] <= val[11:0];
		CSR_MTVEC:	tvec[regno[1:0]] <= val;
		CSR_MPLSTACK:	plStack <= val;
		CSR_MPMSTACK:	pmStack <= val;
		CSR_MVSTEP:	estep <= val;
		CSR_MVTMP:	begin new_vtmp <= val; ld_vtmp <= TRUE; end
//		CSR_DSP:	dsp <= val;
		CSR_MTIME:	begin wc_time_dat <= val; ld_time <= TRUE; end
		CSR_MTIMECMP:	begin clr_wc_time_irq <= TRUE; mtimecmp <= val; end
		CSR_MSTATUS:	status[3] <= val;
		CSR_MTCB:	tcbptr <= val;
//		CSR_DSTUFF0:	stuff0 <= val;
//		CSR_DSTUFF1:	stuff1 <= val;
		*/
		default:	;
		endcase
	end
end
endtask

task tSetbitCSR;
input value_t val;
input [15:0] regno;
begin
	if (Qupls4_pkg::operating_mode_t'(regno[13:12]) <= sr.om) begin
		casez(regno[15:0])
		Qupls4_pkg::CSR_SR:
			begin
				sr <= sr | val;
				irq_downcount_base <= 4'd8;
			end
		/*
		CSR_MCR0:			cr0[val[5:0]] <= 1'b1;
		CSR_SEMA:			sema[val[5:0]] <= 1'b1;
		CSR_MPMSTACK:	pmStack <= pmStack | val;
		CSR_MSTATUS:	status[3] <= status[3] | val;
		*/
		default:	;
		endcase
	end
end
endtask

task tClrbitCSR;
input value_t val;
input [15:0] regno;
begin
	if (Qupls4_pkg::operating_mode_t'(regno[13:12]) <= sr.om) begin
		casez(regno[15:0])
		Qupls4_pkg::CSR_SR:
			begin
				sr <= sr & ~val;
				irq_downcount_base <= 4'd8;
			end
		/*
		CSR_MCR0:			cr0[val[5:0]] <= 1'b0;
		CSR_SEMA:			sema[val[5:0]] <= 1'b0;
		CSR_MPMSTACK:	pmStack <= pmStack & ~val;
		CSR_MSTATUS:	status[3] <= status[3] & ~val;
		*/
		default:	;
		endcase
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Exception processing tasks.
//
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tProcessExc;
input rob_ndx_t id;
input pc_address_t retpc;
input [2:0] uop_num;
integer nn;
reg [7:0] vecno;
begin
	//vecno = rob[id].imm ? rob[id].a0[8:0] : rob[id].a1[8:0];
	//vecno <= rob[id].exc;
	for (nn = 1; nn < ISTACK_DEPTH; nn = nn + 1)
		sr_stack[nn] <= sr_stack[nn-1];
	sr_stack[0] <= sr;
	for (nn = 1; nn < ISTACK_DEPTH; nn = nn + 1)
		pc_stack[nn] <= pc_stack[nn-1];
	pc_stack[0] <= retpc;
	sr.pl <= 8'hFF;
	sr.om <= fnNextOm(sr.om);
	excir <= rob[id].op;
	excid <= id;
	excmissgrp <= rob[id].pghn;
	excmiss <= FALSE;
	csr_carry_mod <= rob[id].op.carry_mod;
	// excmisspc.pc <= {kvec[sr.dbg ? 4 : 3][$bits(pc_address_t)-1:8] + 4'd10,8'h0};
	if (rob[id].op.ssm) begin
		sr.ssm <= FALSE;
		ssm_flag <= FALSE;
		excmisspc.pc <= kernel_vectors[sr.dbg ? 3'd4:{1'b0,fnNextOm(sr.om)}];
		excmiss <= TRUE;
//		excmisspc.pc <= {kvec[sr.dbg ? 4 : nom][$bits(pc_address_t)-1:8] + 4'd1,8'h0};
//		excmiss <= TRUE;
	end
	else if (rob[id].op.decbus.sys) begin
		case(rob[id].op.decbus.Rd)
		6'h00,6'h20: excmisspc.pc <= rob[id].brtgt;
		6'h01,6'h21: excmisspc.pc <= rob[id].brtgt;
		6'h02,6'h22:	excmisspc.pc <= syscall_vectors[{1'b0,fnNextOm(sr.om)}];
		6'h03,6'h23:	excmisspc.pc <= kernel_vectors[{1'b0,fnNextOm(sr.om)}];
		default:	excmisspc.pc <= kernel_vectors[{1'b0,fnNextOm(sr.om)}];
		endcase
		excmiss <= TRUE;
	end
	else begin
		excmisspc.pc <= kernel_vectors[{1'b0,fnNextOm(sr.om)}];
		excmiss <= TRUE;
		//excmisspc.pc <= {kvec[sr.dbg ? 4 : nom][$bits(pc_address_t)-1:8] + 4'd13,8'h0};
		//excmiss <= TRUE;
	end
//		excmisspc <= {avec[$bits(pc_address_t)-1:16] + vecno,3'h0};
end
endtask

// HWI processing
// Since interrupts immediately change the IP at the fetch stage there is no
// need to vector here.

task tProcessHwi;
input rob_ndx_t id;
input [2:0] uop_num;
input irq;
input nmi;
integer nn;
begin
	for (nn = 1; nn < ISTACK_DEPTH; nn = nn + 1)
		sr_stack[nn] <= sr_stack[nn-1];
	sr_stack[0] <= sr;
	for (nn = 1; nn < ISTACK_DEPTH; nn = nn + 1)
		pc_stack[nn] <= pc_stack[nn-1];
	pc_stack[0] <= rob[id].eip;
	sr.pl <= 8'hFF;
	sr.om <= fnNextOm(sr.om);
	csr_carry_mod <= rob[id].op.carry_mod;
	if (nmi) begin
		sr.ipl <= pgh[rob[id].pghn_irq].irq.level;
		sr.ssm <= FALSE;
		ssm_flag <= FALSE;
		excmiss <= TRUE;
		excmisspc.pc <= kernel_vectors[sr.dbg ? 3'd4 : {1'b0,fnNextOm(sr.om)}];//[$bits(pc_address_t)-1:8] + 4'd11,8'h0};
	end
	else if (irq) begin
		sr.ipl <= pgh[rob[id].pghn_irq].irq.level;
		sr.ssm <= FALSE;
		ssm_flag <= FALSE;
		excmiss <= TRUE;
		excmisspc.pc <= kernel_vectors[sr.dbg ? 3'd4 : {1'b0,fnNextOm(sr.om)}];//[$bits(pc_address_t)-1:8] + 4'd11,8'h0};
	end
end
endtask

// tRex needs updates, sb micro_op not instruction.
task tRex;
input rob_ndx_t id;
input Qupls4_pkg::ex_instruction_t ir;
begin
	if (sr.om > ir.ins[9:8]) begin
		sr.om <= Qupls4_pkg::operating_mode_t'(ir.ins[9:8]);
		excid <= id;
		excmissgrp <= rob[id].pghn;
		excmiss <= TRUE;
		/*
		if (cause[3][7:0] < 8'd16)
			excmisspc.pc <= {kvec[ir.ins[9:8]][$bits(pc_address_t)-1:4] + cause[3][3:0],4'h0};
		else
			excmisspc.pc <= {kvec[ir.ins[9:8]][$bits(pc_address_t)-1:4] + 4'd13,4'h0};
		*/
	end
end
endtask

task tProcessEret;
input twoup;
input restore_ssm;
integer nn;
begin
	excret <= TRUE;
	err_mask <= 64'd0;
	sr <= sr_stack[0];
	irq_downcount_base <= 8'd8;
	if (!restore_ssm)
		sr.ssm <= 1'b0;
	for (nn = 0; nn < ISTACK_DEPTH-1; nn = nn + 1)
		sr_stack[nn] <= sr_stack[nn+1];
	set_pending_ipl <= TRUE;
	next_pending_ipl <= sr_stack[0].ipl;
	for (nn = 0; nn < ISTACK_DEPTH-1; nn = nn + 1)
		pc_stack[nn] <=	pc_stack[nn+1];
	exc_ret_pc <= pc_stack[0];
	exc_ret_carry_mod <= csr_carry_mod;
	csr_carry_mod <= 32'd0;
end
endtask


// Search for the branch destination following the branch (forward search). If
// the branch destination is found in the ROB within six instructions, then
// predicate: mark the instructions as copy targets (done above)

task tGetSkipList;
input rob_ndx_t ndx;
output reg fnd;
output Qupls4_pkg::rob_bitmask_t skip_list;
output rob_ndx_t m1;
output rob_ndx_t dst;
rob_ndx_t p1;
rob_ndx_t m2;
rob_ndx_t m3;
rob_ndx_t m4;
rob_ndx_t m5;
rob_ndx_t m6;
rob_ndx_t m7;
reg [2:0] found;
integer nn;
begin
	skip_list <= {Qupls4_pkg::ROB_ENTRIES{1'b0}};
	found = 3'd0;
	p1 = (ndx + Qupls4_pkg::ROB_ENTRIES - 1) % Qupls4_pkg::ROB_ENTRIES;
	m1 = (ndx + Qupls4_pkg::ROB_ENTRIES + 1) % Qupls4_pkg::ROB_ENTRIES;
	m2 = (ndx + Qupls4_pkg::ROB_ENTRIES + 2) % Qupls4_pkg::ROB_ENTRIES;
	m3 = (ndx + Qupls4_pkg::ROB_ENTRIES + 3) % Qupls4_pkg::ROB_ENTRIES;
	m4 = (ndx + Qupls4_pkg::ROB_ENTRIES + 4) % Qupls4_pkg::ROB_ENTRIES;
	m5 = (ndx + Qupls4_pkg::ROB_ENTRIES + 5) % Qupls4_pkg::ROB_ENTRIES;
	m6 = (ndx + Qupls4_pkg::ROB_ENTRIES + 6) % Qupls4_pkg::ROB_ENTRIES;
	m7 = (ndx + Qupls4_pkg::ROB_ENTRIES + 7) % Qupls4_pkg::ROB_ENTRIES;
	dst <= p1;	// the last ROB entry it could be
	if (rob[m1].sn > rob[ndx].sn && rob[m1].v==rob[ndx].v && pgh[rob[m1].pghn].ip.pc + {rob[m1].ip_offs,1'b0} == rob[ndx].brtgt)
		found = 3'd1;
	else if (rob[m2].sn > rob[ndx].sn && rob[m2].v==rob[ndx].v && pgh[rob[m2].pghn].ip.pc + {rob[m2].ip_offs,1'b0} == rob[ndx].brtgt)
		found = 3'd2;
	else if (rob[m3].sn > rob[ndx].sn && rob[m3].v==rob[ndx].v && pgh[rob[m3].pghn].ip.pc + {rob[m3].ip_offs,1'b0} == rob[ndx].brtgt)
		found = 3'd3;
	else if (rob[m4].sn > rob[ndx].sn && rob[m4].v==rob[ndx].v && pgh[rob[m4].pghn].ip.pc + {rob[m4].ip_offs,1'b0} == rob[ndx].brtgt)
		found = 3'd4;
	else if (rob[m5].sn > rob[ndx].sn && rob[m5].v==rob[ndx].v && pgh[rob[m5].pghn].ip.pc + {rob[m5].ip_offs,1'b0} == rob[ndx].brtgt)
		found = 3'd5;
	else if (rob[m6].sn > rob[ndx].sn && rob[m6].v==rob[ndx].v && pgh[rob[m6].pghn].ip.pc + {rob[m6].ip_offs,1'b0} == rob[ndx].brtgt)
		found = 3'd6;

	case(found)
	3'd1:	dst <= m2;
	3'd2:	dst <= m3;
	3'd3:	dst <= m4;
	3'd4:	dst <= m5;
	3'd5:	dst <= m6;
	3'd6:	dst <= m7;
	default:	;
	endcase
	fnd <= |found;
	foreach (rob[nn])
		if (rob[nn].sn > rob[ndx].sn && rob[nn].v==rob[ndx].v && rob[nn].sn < rob[dst].sn)
			skip_list[nn] <= 1'b1;
end
endtask

task tMoveIRQToInstructionStart;
input rob_ndx_t ndx;
integer kk;
rob_ndx_t ih;
begin
	ih = (ndx + Qupls4_pkg::ROB_ENTRIES - rob[ndx].op.uop.num) % Qupls4_pkg::ROB_ENTRIES;
	if (ih != ndx && rob[ih].sn < rob[ndx].sn) begin
//		rob[ih].v <= 5'd0;							// instruction is no longer valid.
		rob[ih].done <= 2'b11;
		rob[ih].op.hwi <= TRUE;
		rob[ih].pghn_irq <= rob[ndx].pghn_irq;
		rob[ndx].op.hwi <= FALSE;
	end
end
endtask

// A look-back is made for only up to six micro-ops. Most instructions have
// fewer micro-ops and searching cost LUTs. If the lead micro-op has not been
// found, the last micro-op searched is marked as interrupted. The interrupt
// will be deferred again later until finally the first micro-op of an
// instruction is found.

task tDeferToNextInstruction;
input rob_ndx_t ndx;
integer kk;
rob_ndx_t m1;
rob_ndx_t m2;
rob_ndx_t m3;
rob_ndx_t m4;
rob_ndx_t m5;
rob_ndx_t m6;
rob_ndx_t ih;
reg inv;
begin
	inv = FALSE;
	m1 = (ndx + Qupls4_pkg::ROB_ENTRIES + 1) % Qupls4_pkg::ROB_ENTRIES;
	m2 = (ndx + Qupls4_pkg::ROB_ENTRIES + 2) % Qupls4_pkg::ROB_ENTRIES;
	m3 = (ndx + Qupls4_pkg::ROB_ENTRIES + 3) % Qupls4_pkg::ROB_ENTRIES;
	m4 = (ndx + Qupls4_pkg::ROB_ENTRIES + 4) % Qupls4_pkg::ROB_ENTRIES;
	m5 = (ndx + Qupls4_pkg::ROB_ENTRIES + 5) % Qupls4_pkg::ROB_ENTRIES;
	m6 = (ndx + Qupls4_pkg::ROB_ENTRIES + 6) % Qupls4_pkg::ROB_ENTRIES;
	//m7 = (ndx + Qupls4_pkg::ROB_ENTRIES + 7) % Qupls4_pkg::ROB_ENTRIES;
	if (rob[m1].op.uop.lead && rob[m1].sn > rob[ndx].sn) begin
		ih = m1;
		inv = TRUE;
	end
	else if (rob[m2].op.uop.lead && rob[m2].sn > rob[ndx].sn) begin
		ih = m2;
		inv = TRUE;
	end
	else if (rob[m3].op.uop.lead && rob[m3].sn > rob[ndx].sn) begin
		ih = m3;
		inv = TRUE;
	end
	else if (rob[m4].op.uop.lead && rob[m4].sn > rob[ndx].sn) begin
		ih = m4;
		inv = TRUE;
	end
	else if (rob[m5].op.uop.lead && rob[m5].sn > rob[ndx].sn) begin
		ih = m5;
		inv = TRUE;
	end
	// Cannot find lead micro-op, must not be queued yet. Select tail position as
	// place for interrupt. It may be moved again later.
	else
		ih = m6;//(tails[0] + Qupls4_pkg::ROB_ENTRIES - 1) % Qupls4_pkg::ROB_ENTRIES;
	if (ih != ndx) begin
		rob[ih].op.hwi <= TRUE;
		// If the lead instruction was found, invalidate it.
		if (inv) begin
//			rob[ih].v <= 5'd0;
			rob[ih].done <= 2'b11;
		end
		rob[ndx].op.hwi <= FALSE;
		rob[ih].pghn_irq <= rob[ndx].pghn_irq;
	end
end
endtask

// Clear any sync dependencies, used when a sync instruction commits.

task tClearSyncDep;
input rob_ndx_t ndx;
integer nn;
begin
	foreach (rob[nn]) begin
		if (rob[nn].sync_depv && rob[nn].sync_dep==ndx)
			rob[nn].sync_depv <= INV;
	end
end
endtask

// Clear any sync dependencies, used when a sync instruction commits.

task tClearFcDep;
input rob_ndx_t ndx;
integer nn;
begin
	foreach (rob[nn]) begin
		if (rob[nn].fc_depv && rob[nn].fc_dep==ndx)
			rob[nn].fc_depv <= INV;
	end
end
endtask

// Commit logic the same for every head.

task tCommits;
input integer head;
input rob_ndx_t ndx;
begin
	tInvalidateQE(ndx);
	if (sync_ndx==ndx)
		sync_ndxv = INV;
	if (fc_ndx==ndx)
		fc_ndxv = INV;
	if (rob[ndx].op.decbus.sync)
		tClearSyncDep(ndx);
	if (rob[ndx].op.decbus.fc)
		tClearFcDep(ndx);
	rob[ndx].cmt <= |rob[ndx].v;
	tInvalidateLSQ(head, ndx, FALSE, |rob[ndx].v, value_zero);
end
endtask

task tSetROBDone;
input Qupls4_pkg::reservation_station_entry_t rse;
input takb;
input cpu_types_pkg::value_t val;
begin
	if (rse.v) begin
		if (!rob[rse.rndx].excv) begin
	  	rob[ rse.rndx ].exc <= rse.exc;
	  	rob[ rse.rndx ].excv <= rse.exc != Qupls4_pkg::FLT_NONE;
		end
    rob[ rse.rndx ].nan <= rse.nan;
		rob[ rse.rndx ].done <= {TRUE,TRUE};
		rob[ rse.rndx ].out <= {FALSE,FALSE};
    rob[ rse.rndx ].takb <= takb;
//    if (rob[rse.rndx].op.decbus.pred)
//    	pred_buf[rob[rse.rndx].ip_stream.stream] <= val;
	end
end
endtask

task tSetROBMemDone;
input integer n;
input dram_work_t dram_work;
input dram_oper_t dram_oper;
input Qupls4_pkg::cause_code_t cause;
input [1:0] done;
begin
	if (!rob[ dram_work.rndx ].excv) begin
  	rob[ dram_work.rndx ].exc <= cause;
  	rob[ dram_work.rndx ].excv <= cause!=Qupls4_pkg::FLT_NONE;
	end
  rob[ dram_work.rndx ].out <= {INV,INV};
  rob[ dram_work.rndx ].done <= done;
	if (done==2'b11)
		rob[dram_work.rndx].load_data <= dram_oper.oper.val;
  else
  	tIncLSQAddr(n, dram_work.rndx);
end
endtask

endmodule
