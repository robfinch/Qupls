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
// 97500 LUTs / 33000 FFs / 50 BRAMs
// 91k LUTs / 43.5k FFs / 90 BRAMs (14 vec registers - 1 ALU, 8 checkpoints)
// 103k LUTs / 44.5k FFs / 92 BRAMs / 64 DSPs (14 vec regs - 2 ALU, 8 checkpts)
// 117k LUTs / k FFs / 97 BRAMs / 64 DSPs (24 vec regs - 2 ALU, 8 checkpts)
// 107k LUTs / 41.5k FFs / 132 BRAMS / 72 DSP (14 vec regs - 1 ALU, 8 chkpts)
// ============================================================================

import const_pkg::*;
import fta_bus_pkg::*;
import cpu_types_pkg::*;
import Qupls_cache_pkg::*;
import mmu_pkg::*;
import QuplsPkg::*;

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

module Qupls3(coreno_i, rst_i, clk_i, clk2x_i, clk3x_i, clk5x_i, ipl, irq, irq_ack, irq_i, ivect_i, swstk_i,
	fta_req, fta_resp, snoop_adr, snoop_v, snoop_cid);
parameter CORENO = 6'd1;
parameter CID = 6'd1;
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
output fta_cmd_request256_t fta_req;
input fta_cmd_response256_t fta_resp;
input cpu_types_pkg::address_t snoop_adr;
input snoop_v;
input [5:0] snoop_cid;

wire ren_rst_busy;
reg irst;
always_comb irst = rst_i|ren_rst_busy;
fta_cmd_request256_t ftatm_req;
fta_cmd_response256_t ftatm_resp;
fta_cmd_request256_t ftaim_req;
fta_cmd_response256_t ftaim_resp;
fta_cmd_request256_t [1:0] ftadm_req;
fta_cmd_response256_t [1:0] ftadm_resp;
fta_cmd_response256_t fta_resp1;
fta_cmd_response256_t ptable_resp;
fta_cmd_request256_t [1:0] cap_tag_req;
fta_cmd_response256_t [1:0] cap_tag_resp;
wire [1:0] cap_tag_hit;

real IPC,PIPC;
integer nn,mm,n2,n3,n4,m4,n5,n6,n8,n9,n10,n11,n12,n13,n14,n15,n17;
integer n16r, n16c, n12r, n12c, n14r, n14c, n17r, n17c, n18r, n18c;
integer n19,n20,n21,n22,n23,n24,n25,n26,n27,n28,n29,i,n30,n31,n32,n33;
genvar g,h,gvg;
reg [127:0] message;
reg [9*8-1:0] stompstr, no_stompstr;
wire clk;
wire clk2x, clk3x;
assign clk3x = clk3x_i;
wire clk5x = clk5x_i;
reg [4:0] ph4;
reg [3:0] rstcnt;
reg [3:0] panic;
reg int_commit;		// IRQ committed
reg next_step;		// do next step for single stepping
reg ssm_flag;
// hirq squashes the pc increment if there's an irq.
// Normally atom_mask is zero.
reg hirq;
pc_address_t ret_pc;
pc_address_ex_t misspc;
mc_address_t miss_mcip, mcbrtgt, excmiss_mcip;
wire [$bits(pc_address_t)-1:6] missblock;
reg [2:0] missgrp;
wire [2:0] missino;
reg restore_en = 1'b1;

ex_instruction_t missir;
mc_address_t next_micro_ip, next_mip;

reg [39:0] I;		// Committed instructions
reg [39:0] IV;	// Valid committed instructions

reg_bitmask_t livetarget;
reg_bitmask_t [ROB_ENTRIES-1:0] rob_livetarget;
reg_bitmask_t [ROB_ENTRIES-1:0] rob_latestID;
reg_bitmask_t [ROB_ENTRIES-1:0] rob_cumulative;
reg_bitmask_t [ROB_ENTRIES-1:0] rob_out;
reg [PREGS-1:0] unavail_list;			// list of registers made unavailable via copy-targets

reg [ROB_ENTRIES-1:0] missidb;

mvec_entry_t [255:0] mvec_tbl;

wire [PREGS-1:0] restore_list;
rob_ndx_t agen0_rndx, agen1_rndx;
reg [7:0] scan;

//op_src_t alu0_argA_src;
//op_src_t alu0_argB_src;
//op_src_t alu0_argC_src;

value_t rfo_alu0_argA;
value_t rfo_alu0_argB;
value_t rfo_alu0_argC;
value_t rfo_alu0_argT;
value_t rfo_alu0_argM;
value_t rfo_alu1_argA;
value_t rfo_alu1_argB;
value_t rfo_alu1_argC;
value_t rfo_alu1_argT;
value_t rfo_alu1_argM;
value_t rfo_fpu0_argA;
value_t rfo_fpu0_argB;
value_t rfo_fpu0_argC;
value_t rfo_fpu0_argM;
value_t rfo_fpu1_argA;
value_t rfo_fpu1_argB;
value_t rfo_fpu1_argC;
value_t rfo_fpu1_argT;
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
value_t rfo_store_argC;
wire rfo_alu0_argA_ctag;
wire rfo_alu0_argB_ctag;
wire rfo_alu1_argA_ctag;
wire rfo_alu1_argB_ctag;
wire rfo_fpu0_argA_ctag;
wire rfo_fpu0_argB_ctag;
wire rfo_agen0_argA_ctag;
wire rfo_agen0_argB_ctag;
wire rfo_agen0_argC_ctag;
wire rfo_agen1_argA_ctag;
wire rfo_agen1_argB_ctag;
wire rfo_store_argC_ctag;
value_t store_argC;
value_t rfo_cpytgt0_argT;
value_t load_res;
value_t ma0,ma1;				// memory address
wire store_argC_v;

pregno_t alu0_argA_reg;
pregno_t alu0_argB_reg;
pregno_t alu0_argC_reg;
pregno_t alu0_argT_reg;
pregno_t alu0_argM_reg;

pregno_t alu1_argA_reg;
pregno_t alu1_argB_reg;
pregno_t alu1_argC_reg;
pregno_t alu1_argT_reg;
pregno_t alu1_argM_reg;

pregno_t fpu0_argA_reg;
pregno_t fpu0_argB_reg;
pregno_t fpu0_argC_reg;
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
wire agen0_argC_ctag;

pregno_t agen1_argA_reg;
pregno_t agen1_argB_reg;
pregno_t agen1_argC_reg;
pregno_t agen1_argM_reg;

checkpt_ndx_t store_argC_cndx;
aregno_t store_argC_aReg;
pregno_t store_argC_pReg;

lsq_ndx_t store_argC_id;
lsq_ndx_t store_argC_id1;

pregno_t [23:0] rf_reg;
value_t [23:0] rfo;
wire [23:0] rfo_ctag;

rob_ndx_t mc_orid;
pc_address_ex_t mc_adr;
pc_address_ex_t tgtpc;
rob_entry_t [ROB_ENTRIES-1:0] rob;
beb_entry_t beb_buf;
reg [1:0] beb_status [0:63];

ex_instruction_t [3:0] macro_ins_bus;
reg macro_queued;

reg [1:0] robentry_islot [0:ROB_ENTRIES-1];
wire [1:0] next_robentry_islot [0:ROB_ENTRIES-1];
reg [1:0] lsq_islot [0:LSQ_ENTRIES*2-1];
rob_bitmask_t robentry_stomp;
rob_bitmask_t robentry_cpytgt;
wire [4:0] stomp_bno;
wire stomp_fet, stomp_mux, stomp_x4;
wire stomp_dec, stomp_ren, stomp_que, stomp_quem;
reg stomp_fet1,stomp_mux1,stomp_mux2;
rob_bitmask_t robentry_issue;
rob_bitmask_t robentry_fpu_issue;
rob_bitmask_t robentry_fcu_issue;
rob_bitmask_t robentry_agen_issue;
lsq_entry_t [1:0] lsq [0:7];
lsq_ndx_t lq_tail, lq_head;
wire nq;
reg [3:0] wnq;

reg brtgtv, mcbrtgtv;
pc_address_ex_t pc0_f;
pc_address_ex_t brtgt;
reg pc_in_sync;
reg advance_pipeline, advance_pipeline_seg2;
reg advance_f;
reg inc_chkpt;
reg [2:0] chkpt_inc_amt;
reg do_bsr_h;
reg set_pending_ipl;
reg [2:0] next_pending_ipl;
wire stallq, rat_stallq, ren_stallq;

rob_ndx_t tail0, tail1, tail2, tail3, tail4, tail5, tail6, tail7, tail8, tail9, tail10, tail11;
rob_ndx_t head0, head1, head2, head3, head4, head5;
rob_ndx_t [11:0] tails;
rob_ndx_t stail;
always_comb tails[0] = tail0;
always_comb tails[1] = tail1;
always_comb tails[2] = tail2;
always_comb tails[3] = tail3;
always_comb tails[4] = tail4;
always_comb tails[5] = tail5;
always_comb tails[6] = tail6;
always_comb tails[7] = tail7;
always_comb tails[8] = tail8;
always_comb tails[9] = tail9;
always_comb tails[10] = tail10;
always_comb tails[11] = tail11;
reg_bitmask_t reg_bitmask;
reg_bitmask_t Ra_bitmask;
reg_bitmask_t Rt_bitmask;
reg ls_bmf;		// load or store bitmask flag
ex_instruction_t hold_ir;
reg hold_ins;
reg pack_regs;
reg [2:0] scale_regs;
rob_ndx_t grplen0;
rob_ndx_t grplen1;
rob_ndx_t grplen2;
rob_ndx_t grplen3;
reg last0;
reg last1;
reg last2;
reg last3;

pipeline_reg_t pr_fet0,pr_fet1,pr_fet2,pr_fet3;
pipeline_reg_t pr_mux0,pr_mux1,pr_mux2,pr_mux3;
pipeline_reg_t pr_dec0,pr_dec1,pr_dec2,pr_dec3;
pipeline_reg_t pr_ren0,pr_ren1,pr_ren2,pr_ren3;
pipeline_reg_t pr_que0,pr_que1,pr_que2,pr_que3;

always_comb tail1 = (tail0 + 1) % ROB_ENTRIES;
always_comb tail2 = (tail0 + 2) % ROB_ENTRIES;
always_comb tail3 = (tail0 + 3) % ROB_ENTRIES;
always_comb tail4 = (tail0 + 4) % ROB_ENTRIES;
always_comb tail5 = (tail0 + 5) % ROB_ENTRIES;
always_comb tail6 = (tail0 + 6) % ROB_ENTRIES;
always_comb tail7 = (tail0 + 7) % ROB_ENTRIES;
always_comb tail8 = (tail0 + 8) % ROB_ENTRIES;
always_comb tail9 = (tail0 + 9) % ROB_ENTRIES;
always_comb tail10 = (tail0 + 10) % ROB_ENTRIES;
always_comb tail11 = (tail0 + 11) % ROB_ENTRIES;
always_comb head1 = (head0 + 1) % ROB_ENTRIES;
always_comb head2 = (head0 + 2) % ROB_ENTRIES;
always_comb head3 = (head0 + 3) % ROB_ENTRIES;
always_comb head4 = (head0 + 4) % ROB_ENTRIES;
always_comb head5 = (head0 + 5) % ROB_ENTRIES;

ex_instruction_t [7:0] ex_ins;

decode_bus_t db0_r, db1_r, db2_r, db3_r;				// Regfetch/rename stage inputs
pipeline_reg_t ins0_mux, ins1_mux, ins2_mux, ins3_mux, ins4_mux;
pipeline_reg_t ins0_dec, ins1_dec, ins2_dec, ins3_dec, ins4_d, ins5_d, ins6_d, ins7_d, ins8_d;
pipeline_reg_t ins0_ren, ins1_ren, ins2_ren, ins3_ren;
pipeline_reg_t ins0_que, ins1_que, ins2_que, ins3_que;

reg backout;
wire bo_wr;
aregno_t bo_areg;
pregno_t bo_preg;
pregno_t bo_nreg;

reg [3:0] predino;
rob_ndx_t predrndx;
reg [3:0] regx0;
reg [3:0] regx1;
reg [3:0] regx2;
reg [3:0] regx3;
wire [3:0] mc_regx0;
wire [3:0] mc_regx1;
wire [3:0] mc_regx2;
wire [3:0] mc_regx3;

// ALU done and idle are almost the same, but idle is sticky and set
// if the ALU is not busy, whereas done pulses at the end of an ALU
// operation.
reg alu0_idle;
reg alu0_idle1;
wire alu0_idle_false;
always_comb
	if (alu0_idle_false)
		alu0_idle = FALSE;
	else
		alu0_idle = alu0_idle1;
reg alu0_done;
wire alu0_sc_done;		// single-cyle op done
wire alu0_sc_done2;		// pipeline delayed version of above
reg alu0_stomp;
reg alu0_available;
reg alu0_dataready;
ex_instruction_t alu0_instr;
wire alu0_div;
wire alu0_cap;
value_t alu0_argA;
value_t alu0_argB;
value_t alu0_argBI;
value_t alu0_argC;
value_t alu0_argI;
value_t alu0_argT;
value_t alu0_argM;
pregno_t alu0_Rt;
aregno_t alu0_aRt;
reg alu0_argA_ctag;
reg alu0_argB_ctag;
reg alu0_aRtz;
checkpt_ndx_t alu0_cp;
reg [2:0] alu0_cs;
reg alu0_bank;
value_t alu0_cmpo;
pc_address_ex_t alu0_pc;
value_t alu0_res;
rob_ndx_t alu0_id;
reg alu0_idv;
wire [63:0] alu0_exc;
reg alu0_out;
wire mul0_done;
value_t div0_q,div0_r;
wire div0_done,div0_dbz;
wire alu0_ld;
reg alu0_ldd;
wire alu0_pred;
wire alu0_predz;
wire alu0_cpytgt;
wire [7:0] alu0_cptgt;
memsz_t alu0_prc;
wire alu0_ctag;

reg alu1_idle;
reg alu1_idle1;
wire alu1_idle_false;
always_comb
	if (alu1_idle_false)
		alu1_idle = FALSE;
	else
		alu1_idle = alu1_idle1;
reg alu1_done;
reg alu1_sc_done1;
wire alu1_sc_done2;		// pipeline delayed version of above
wire alu1_sc_done;		// single-cyle op done
always_ff @(posedge clk) alu1_sc_done1 <= alu1_sc_done;
reg alu1_stomp;
reg alu1_available;
reg alu1_dataready;
ex_instruction_t alu1_instr;
wire alu1_div;
value_t alu1_argA;
value_t alu1_argB;
value_t alu1_argBI;
value_t alu1_argC;
value_t alu1_argT;
value_t alu1_argI;
value_t alu1_argM;
reg [2:0] alu1_cs;
pregno_t alu1_Rt;
aregno_t alu1_aRt;
reg alu1_aRtz;
checkpt_ndx_t alu1_cp;
reg alu1_bank;
value_t alu1_cmpo;
pc_address_ex_t alu1_pc;
value_t alu1_res;
rob_ndx_t alu1_id;
reg alu1_idv;
wire [63:0] alu1_exc;
reg alu1_out;
wire mul1_done;
value_t div1_q,div1_r;
wire div1_done,div1_dbz;
wire alu1_ld;
reg alu1_ldd;
wire alu1_pred;
wire alu1_predz;
wire alu1_cpytgt;
wire [7:0] alu1_cptgt;
memsz_t alu1_prc;
wire alu1_ctag;

reg fpu0_idle;
wire fpu0_iq_prog_full;
wire fpu0_done;
wire fpu0_sc_done;		// single-cycle done
wire fpu0_sc_done2;		// pipeline delayed version of above
reg fpu0_done1;
reg fpu0_stomp = 1'b0;
reg fpu0_available;
ex_instruction_t fpu0_instr;
reg [2:0] fpu0_rmd;
value_t fpu0_argA;
value_t fpu0_argB;
value_t fpu0_argC;
value_t fpu0_argT;
value_t fpu0_argP;
value_t fpu0_argI;	// only used by BEQ
value_t fpu0_argM;
reg fpu0_argA_tag;
reg fpu0_argB_tag;
pregno_t fpu0_Rt;
aregno_t fpu0_aRt;
reg fpu0_aRtz;
pregno_t fpu0_Rt1;
aregno_t fpu0_aRt1;
reg fpu0_aRtz1;
checkpt_ndx_t fpu0_cp;
reg [2:0] fpu0_cs;
reg fpu0_bank;
pc_address_ex_t fpu0_pc;
value_t fpu0_res, fpu0_resH;
double_value_t qdfpu0_res;
rob_ndx_t fpu0_id;
cause_code_t fpu0_exc;
reg fpu0_out;
wire fpu_done1;
reg fpu0_idv;
reg fpu0_qfext;
wire fpu0_ctag;
reg [15:0] fpu0_cptgt;
wire fpu0_predz;

reg fpu1_idle;
wire fpu1_done;
wire fpu1_sc_done;
reg fpu1_done1;
reg fpu1_stomp;
reg fpu1_available;
reg fpu1_dataready;
ex_instruction_t fpu1_instr;
reg [2:0] fpu1_rmd;
value_t fpu1_argA;
value_t fpu1_argB;
value_t fpu1_argC;
value_t fpu1_argD;
value_t fpu1_argT;
value_t fpu1_argP;
value_t fpu1_argI;	// only used by BEQ
value_t fpu1_argM;
wire fpu1_argA_ctag;
wire fpu1_argB_ctag;
pregno_t fpu1_Rt, fpu1_Rt1;
aregno_t fpu1_aRt, fpu1_aRt1;
reg fpu1_aRtz, fpu1_aRtz1;
checkpt_ndx_t fpu1_cp;
reg [2:0] fpu1_cs;
reg fpu1_bank;
pc_address_ex_t fpu1_pc;
value_t fpu1_res;
rob_ndx_t fpu1_id;
cause_code_t fpu1_exc = FLT_NONE;
wire        fpu1_v;
reg fpu1_idv;
wire fpu1_qfext;
reg [15:0] fpu1_cptgt;

reg fcu_idle;
reg fcu_available;
pipeline_reg_t fcu_instr;
pipeline_reg_t fcu_missir;
reg fcu_bt;
reg fcu_cjb;
reg fcu_bsr;
bts_t fcu_bts;
value_t fcu_argA;
value_t fcu_argB;
value_t fcu_argBr;
value_t fcu_argI;	// only used by BEQ
pc_address_ex_t fcu_pc;
rob_ndx_t fcu_id;
reg fcu_idv;
cause_code_t fcu_exc;
reg fcu_v, fcu_v2, fcu_v3, fcu_v4, fcu_v5, fcu_v6;
wire fcu_branchmiss;
pc_address_ex_t fcu_misspc, fcu_misspc1;
mc_address_t fcu_miss_mcip, fcu_miss_mcip1;
reg [2:0] fcu_missgrp;
reg [2:0] fcu_missino;
checkpt_ndx_t fcu_cp;
reg takb;
rob_ndx_t fcu_rndx;
reg fcu_new;						// new FCU operation is taking place
wire pe_bsidle;
reg [2:0] bsi;

wire tlb0_v, tlb1_v;

reg agen0_idle;
wire agen0_idle1;
ex_instruction_t agen0_op;
rob_ndx_t agen0_id;
value_t agen0_argA;
value_t agen0_argB;
value_t agen0_argC;
value_t agen0_argC_v;
value_t agen0_argI;
value_t agen0_argM;
pc_address_t agen0_pc;
aregno_t agen0_aRa;
aregno_t agen0_aRb;
aregno_t agen0_aRc;
aregno_t agen0_aRt;
pregno_t agen0_Ra;
pregno_t agen0_Rb;
pregno_t agen0_Rc;
pregno_t agen0_Rt;
pregno_t agen0_pRc;
checkpt_ndx_t agen0_cp;
cause_code_t agen0_exc;
wire agen0_excv;
reg agen0_idv;
wire agen0_ldip;

reg agen1_idle = 1'b1;
wire agen1_idle1;
ex_instruction_t agen1_op;
rob_ndx_t agen1_id;
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
cause_code_t agen1_exc;
wire agen1_excv;
reg agen1_idv;
wire agen1_ldip;

rob_ndx_t [3:0] regv_rndx;

reg lsq0_idle = 1'b1;
reg lsq1_idle = 1'b1;

address_t tlb0_res, tlb1_res;

pc_address_t icdp;
branch_state_t branch_state;
reg bs_done_oh;
reg bs_idle_oh;
reg [4:0] excid;
pc_address_ex_t excmisspc;
reg [2:0] excmissgrp;
reg excmiss;
ex_instruction_t excir;
reg excret;
pc_address_ex_t exc_ret_pc;
wire do_bsr, do_ret, do_call;
pc_address_ex_t bsr_tgt;
mc_address_t exc_ret_mcip;
instruction_t exc_ret_mcir;
reg dc_get;
wire [31:0] bno_bitmap;

wire dram_avail;
dram_state_t dram0;	// state of the DRAM request
dram_state_t dram1;	// state of the DRAM request

value_t dram_bus0;
reg dram_ctag0;
regspec_t dram_tgt0;
reg  [4:0] dram_id0;
cause_code_t dram_exc0;
reg        dram_v0;
value_t dram_bus1;
reg dram_ctag1;
regspec_t dram_tgt1;
reg  [4:0] dram_id1;
cause_code_t dram_exc1;
reg        dram_v1;

reg [639:0] dram0_data, dram0_datah;
reg dram0_ctag;
reg dram0_ctago;
virtual_address_t dram0_vaddr, dram0_vaddrh;
physical_address_t dram0_paddr, dram0_paddrh;
reg [79:0] dram0_sel, dram0_selh;
ex_instruction_t dram0_op;
memsz_t dram0_memsz;
rob_ndx_t dram0_id;
reg dram0_stomp;
reg dram0_load;
reg dram0_loadz;
reg dram0_cload;
reg dram0_cload_tags;
reg dram0_store;
reg dram0_cstore;
pregno_t dram0_Rt, dram_Rt0;
aregno_t dram0_aRt, dram_aRt0;
reg dram0_aRtz, dram_aRtz0;
reg dram0_bank;
cause_code_t dram0_exc;
reg dram0_ack;
fta_tranid_t dram0_tid;
wire dram0_more;
reg dram0_hi;
reg dram0_erc;
reg [9:0] dram0_shift;
reg [11:0] dram0_tocnt;
reg dram0_done;
reg dram0_idv;
checkpt_ndx_t dram0_cp;
value_t dram0_argT;
pc_address_t dram0_pc;
reg dram0_ldip;

reg [639:0] dram1_data, dram1_datah;
reg dram1_ctag;
reg dram1_ctago;
virtual_address_t dram1_vaddr, dram1_vaddrh;
physical_address_t dram1_paddr, dram1_paddrh;
reg [79:0] dram1_sel, dram1_selh;
ex_instruction_t dram1_op;
memsz_t dram1_memsz;
rob_ndx_t dram1_id;
reg dram1_stomp;
reg dram1_load;
reg dram1_loadz;
reg dram1_cload;
reg dram1_cload_tags;
reg dram1_store;
reg dram1_cstore;
pregno_t dram1_Rt, dram_Rt1;
aregno_t dram1_aRt, dram_aRt1;
reg dram1_aRtz, dram_aRtz1;
reg dram1_bank;
cause_code_t dram1_exc;
reg dram1_ack;
fta_tranid_t dram1_tid;
wire dram1_more;
reg dram1_erc;
reg dram1_hi;
reg [9:0] dram1_shift;
reg [11:0] dram1_tocnt;
reg dram1_done;
reg dram1_idv;
checkpt_ndx_t dram1_cp;
value_t dram1_argT;
pc_address_t dram1_pc;

reg [2:0] dramN [0:NDATA_PORTS-1];
reg [511:0] dramN_data [0:NDATA_PORTS-1];
reg [63:0] dramN_sel [0:NDATA_PORTS-1];
address_t dramN_addr [0:NDATA_PORTS-1];
address_t dramN_vaddr [0:NDATA_PORTS-1];
address_t dramN_paddr [0:NDATA_PORTS-1];
reg [NDATA_PORTS-1:0] dramN_load;
reg [NDATA_PORTS-1:0] dramN_loadz;
reg [NDATA_PORTS-1:0] dramN_cload;
reg [NDATA_PORTS-1:0] dramN_cload_tags;
reg [NDATA_PORTS-1:0] dramN_store;
reg [NDATA_PORTS-1:0] dramN_cstore;
reg [NDATA_PORTS-1:0] dramN_ack;
reg [NDATA_PORTS-1:0] dramN_erc;
fta_tranid_t dramN_tid [0:NDATA_PORTS-1];
memsz_t dramN_memsz;
reg [NDATA_PORTS-1:0] dramN_ctago;
wire [NDATA_PORTS-1:0] dramN_ctagi;
wire [15:0] dramN_tagsi [0:NDATA_PORTS-1];
rob_ndx_t [NDATA_PORTS-1:0] dramN_id;

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
reg [39:0] stomped_insn;
cause_code_t [3:0] cause;
status_reg_t sr_stack [0:8];
status_reg_t sr;
wire [2:0] swstk = sr.swstk;
pc_address_t [8:0] pc_stack;
mc_stack_t [8:0] mc_stack;			// micro-code exception stack
reg micro_code_active;
reg micro_code_active_f;
reg micro_code_active_x;
wire micro_code_active_d;
wire micro_code_active_r;
wire micro_code_active_q;
reg [5:0] pending_ipl;				// pending interrupt level.
wire [5:0] im = sr.ipl;
always_comb
	ipl = sr.ipl;
reg [5:0] regset = 6'd0;
reg [63:0] vgm;									// vector global mask
value_t vrm [0:3];						// vector restart mask
value_t vex [0:3];						// vector exception
reg [1:0] vn;
asid_t asid;
asid_t ip_asid;
pc_address_t [4:0] kvec;
pc_address_t avec;
rob_bitmask_t err_mask;
reg ERC = 1'b0;
reg [39:0] icache_cnt;
reg [39:0] iact_cnt;
wire ihito,ihit,ihit_f,ic_dhit;
wire alt_ihit;
wire pe_bsdone;
reg [4:0] vl;

reg [32:0] atom_mask;

assign clk = clk_i;				// convenience
assign clk2x = clk2x_i;

pipeline_reg_t nopi;
reg [5:0] sync_no;
reg [5:0] fc_no;

// Define a NOP instruction.
always_comb
begin
	nopi = {$bits(pipeline_reg_t){1'b0}};
	nopi.pc = RSTPC;
	nopi.pc.bno_t = 6'd1;
	nopi.pc.bno_f = 6'd1;
	nopi.mcip = 12'h1A0;
	nopi.len = 4'd6;
	nopi.ins = {57'd0,OP_NOP};
	nopi.pred_btst = 6'd0;
	nopi.element = 'd0;
	nopi.aRa = 8'd0;
	nopi.aRb = 8'd0;
	nopi.aRc = 8'd0;
	nopi.aRt = 8'd0;
	nopi.decbus.Rtz = 1'b1;
	nopi.decbus.nop = 1'b1;
	nopi.decbus.alu = 1'b1;
end


initial begin: Init
	integer i,j;

	for (i=0; i < ROB_ENTRIES; i=i+1) begin
	  	rob[i].v = INV;
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


assign rf_reg[0] = alu0_argA_reg;
assign rf_reg[1] = alu0_argB_reg;
assign rf_reg[2] = alu0_argC_reg;

assign rf_reg[3] = alu1_argA_reg;
assign rf_reg[4] = alu1_argB_reg;

assign rf_reg[5] = fpu0_argA_reg;
assign rf_reg[6] = fpu0_argB_reg;
assign rf_reg[7] = fpu0_argC_reg;

assign rf_reg[8] = fcu_argA_reg;
assign rf_reg[9] = fcu_argB_reg;

assign rf_reg[10] = agen0_argA_reg;
assign rf_reg[11] = agen0_argB_reg;

assign rf_reg[12] = agen1_argA_reg;
assign rf_reg[13] = agen1_argB_reg;

assign rf_reg[14] = store_argC_pReg;

assign rf_reg[15] = alu0_argT_reg;
assign rf_reg[16] = alu1_argC_reg;
assign rf_reg[17] = alu1_argT_reg;

assign rf_reg[18] = alu0_argM_reg;
assign rf_reg[19] = agen0_argM_reg;
assign rf_reg[20] = fpu0_argM_reg;
assign rf_reg[21] = fpu0_argT_reg;
assign rf_reg[22] = agen0_argC_reg;

assign rfo_alu0_argA = rfo[0];
assign rfo_alu0_argA_ctag = rfo_ctag[0];
assign rfo_alu0_argB = rfo[1];
assign rfo_alu0_argB_ctag = rfo_ctag[1];
assign rfo_alu0_argC = rfo[2];
assign rfo_alu0_argM = rfo[18];

assign rfo_alu1_argA = rfo[3];
assign rfo_alu1_argA_ctag = rfo_ctag[3];
assign rfo_alu1_argB = rfo[4];
assign rfo_alu1_argB_ctag = rfo_ctag[4];
assign rfo_alu1_argM = rfo[19];

assign rfo_fpu0_argA = rfo[5];
assign rfo_fpu0_argA_ctag = rfo_ctag[5];
assign rfo_fpu0_argB = rfo[6];
assign rfo_fpu0_argB_ctag = rfo_ctag[6];
assign rfo_fpu0_argC = rfo[7];
assign rfo_fpu0_argM = rfo[20];

assign rfo_fcu_argA = rfo[8];
assign rfo_fcu_argB = rfo[9];

assign rfo_agen0_argA = rfo[10];
assign rfo_agen0_argA_ctag = rfo_ctag[10];
assign rfo_agen0_argB = rfo[11];
assign rfo_agen0_argB_ctag = rfo_ctag[11];
assign rfo_agen0_argC = rfo[22];
assign rfo_agen0_argC_ctag = rfo_ctag[22];
assign rfo_agen0_argM = rfo[19];

assign rfo_agen1_argA = rfo[12];
assign rfo_agen1_argA_ctag = rfo_ctag[12];
assign rfo_agen1_argB = rfo[13];
assign rfo_agen1_argB_ctag = rfo_ctag[13];

assign rfo_store_argC = rfo[14];
assign rfo_store_argC_ctag = rfo_ctag[14];

assign rfo_alu0_argT = rfo[15];
assign rfo_alu1_argC = rfo[16];
assign rfo_alu1_argT = rfo[17];
assign rfo_fpu0_argT = rfo[21];

ICacheLine ic_dline;

//
// FETCH
//

pc_address_ex_t pc, pc0, pc1, pc2, pc3, pc4, pc5, pc6, pc7, pc8;
reg [5:0] off0, off1, off2, off3, off4, off5, off6, off7;
pc_address_ex_t pc0_d, pc1_d, pc2_d, pc3_d, pc4_d, pc5_d, pc6_d, pc7_d, pc8_d;
pc_address_ex_t pc0_fet, pc1_fet, pc2_fet, pc3_fet, pc4_fet;
pc_address_ex_t next_pc;
mc_address_t mcip0_f;
mc_address_t mcip0_mux, mcip1_mux,mcip2_mux,mcip3_mux;
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

wire wr_ic;
wire ic_valid, ic_dvalid;
address_t ic_miss_adr;
asid_t ic_miss_asid;
wire [1:0] ic_wway;

reg [1023:0] ic_line;
reg ins0_d_inv;
reg ins1_d_inv;
reg ins2_d_inv;
reg ins3_d_inv;
reg ins0_v, ins1_v, ins2_v, ins3_v;
reg [XWID-1:0] ins_v;
reg insnq0,insnq1,insnq2,insnq3;
reg [XWID-1:0] qd, cqd;
reg [XWID-1:0] qd_x,qd_d,qd_r,qd_q;
reg [XWID-1:0] next_cqd;
wire pe_allqd;
reg fetch_new;
reg fetch_new_block, fetch_new_block_x;
mmu_pkg::tlb_entry_t tlb_pc_entry;
pc_address_t pc_tlb_res;
wire pc_tlb_v;

wire pt0_dec, pt1_dec, pt2_dec, pt3_dec;		// predict taken branches
reg pt0_r, pt1_r, pt2_r, pt3_r;
reg pt0_q, pt1_q, pt2_q, pt3_q;
reg regs;
reg [3:0] takb_pc;
reg [3:0] takb_f;
reg [3:0] takb_fet;

reg branchmiss, branchmiss_next;
reg branchmiss_h;
rob_ndx_t missid;

mc_address_t micro_ip;
mc_address_t mip0;
mc_address_t mip1;
mc_address_t mip2;
mc_address_t mip3;
reg mip0v;
reg mip1v;
reg mip2v;
reg mip3v;
reg mip0v_r;
reg mip1v_r;
reg mip2v_r;
reg mip3v_r;
reg mip0v_q;
reg mip1v_q;
reg mip2v_q;
reg mip3v_q;
reg nmip;
reg mipv, mipv2, mipv3, mipv4;

pipeline_reg_t micro_ir;
ex_instruction_t mc_ins0;
ex_instruction_t mc_ins1;
ex_instruction_t mc_ins2;
ex_instruction_t mc_ins3;
ex_instruction_t mc_ins4;
ex_instruction_t mc_ins5;
ex_instruction_t mc_ins6;
ex_instruction_t mc_ins7;
ex_instruction_t mc_ins8;

wire mc_last0;
wire mc_last1;
wire mc_last2;
wire mc_last3;

value_t agen0_res, agen1_res;
wire tlb_miss0, tlb_miss1;
wire tlb_missack;
tlb_entry_t tlb_entry1, tlb_entry;
reg agen0_load, agen1_load;
reg agen0_store, agen1_store;
wire tlb0_load, tlb0_store;
wire tlb1_load, tlb1_store;
reg stall_load, stall_store;
reg stall_tlb0 =1'd0, stall_tlb1=1'd0;

seqnum_t groupno;

// ----------------------------------------------------------------------------
// Config validations
// ----------------------------------------------------------------------------
always_comb
begin
	if (SUPPORT_RENAMER) begin
`ifdef SUPPORT_RAT
		$display("Q+: RAT available.");
`else
		$display("Q+: Error: RAT must be present if registers are renamed.");
		$finish;
`endif
	end
	if (NCHECK > 32) begin
		$display("Q+: Error: more than 32 checkpoints configured.");
		$finish;
	end
	if (NCHECK < 3) begin
		$display("Q+: Error: not enough checkpoints configured.");	
		$finish;
	end
	if (PREGS > 1024) begin
		$display("Q+: Error: too many physical registers configured.");
		$finish;
	end
	if (PREGS < NREGS * 3) begin
		$display("Q+: Warning: physical registers below threshold for good performance.");
	end
	if (PREGS < NREGS * 1.25) begin
		$display("Q+: Error: not enough physical registers.");
		$finish;
	end
	if (ROB_ENTRIES < 12) begin
		$display("Q+: Error: ROB has too few entries.");
		$finish;
	end
	if (ROB_ENTRIES > 63) begin
		$display("Q+: Warning: may need to alter code to support number of ROB entries.");
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
reg irq_rd_en, irq_rd_en2;
reg irq_wr_en, irq_wr_en2;
wire irq_empty;
reg [5:0] irq2_i;
reg [96:0] irq2_vect_i;
reg [2:0] irq2_swstk_i;
wire [105:0] irq2_dout;
reg [105:0] irq2_din;

always_comb
begin
	{irq2_swstk_i,irq2_i,irq2_vect_i} = irq2_dout;
end
always_comb
	irq_rd_en2 = irq_rd_en & ~irst & ~irq_rd_rst;
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
      .READ_DATA_WIDTH(106),          // DECIMAL
      .READ_MODE("fwft"),             // String
      .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_ADV_FEATURES("0707"),     // String
      .WAKEUP_TIME(0),               // DECIMAL
      .WRITE_DATA_WIDTH(106),         // DECIMAL
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

      .dout(irq_dout),            // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
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

      .din(irq_din),                     // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
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
reg [5:0] ic_irq;
reg irq_trig;
wire pe_nmi;
reg exe_nmi, exe_irq;
reg ic_irqf;

always_comb
	ins_v = {ins0_v,ins1_v,ins2_v,ins3_v};

// Track which instructions are valid. Instructions will be valid right after a
// cache line has been fetched. As instructions are queued they are marked
// invalid. insx_v really only applies when instruction queuing takes more than
// one clock.

always_ff @(posedge clk)
if (irst) begin
	ins0_v <= 1'b0;
	ins1_v <= 1'b0;
	ins2_v <= 1'b0;
	ins3_v <= 1'b0;
end
else begin
	if (fetch_new) begin
		ins0_v <= 1'b1;
		ins1_v <= 1'b1;
		ins2_v <= 1'b1;
		ins3_v <= 1'b1;
	end
	else begin
		ins0_v <= ins0_v & ~(qd[0]);
		ins1_v <= ins1_v & ~(qd[1]);
		if (XWID==3)
			ins2_v <= ins2_v & ~(qd[2]);
		else
			ins2_v <= TRUE;
		if (XWID==4)
			ins3_v <= ins3_v & ~(qd[3]);
		else
			ins3_v <= TRUE;
	end
end

always_comb
	nmi = irq_i==6'd63;
always_comb
	irq_addr = irq ? ivect_i  : {kvec[sr.dbg ? 4 : 3][$bits(pc_address_t)-1:8] + 4'd10,8'h0};
always_comb
	nmi_addr = {kvec[sr.dbg ? 4 : 3][$bits(pc_address_t)-1:8] + 4'd11,8'h0};

edge_det unmied1 (.clk(clk), .rst(irst), .ce(advance_f), .i(nmi), .pe(pe_nmi), .ne(), .ee());
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
			ic_irqf <= irq2_i > pending_ipl && sr.mie;
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
			ic_irq <= irq2_i;
		else
			ic_irq <= irq_i;
	end
end

// Set pending IPL to IPL of hardware interrupt.
always_ff @(posedge clk)
if (irst)
	pending_ipl <= 6'd63;
else begin
	if (set_pending_ipl)
		pending_ipl <= next_pending_ipl;
	if (advance_pipeline) begin
		if (irq2_i > pending_ipl && sr.mie && !irq_empty)
			pending_ipl <= irq2_i;
		else if (irq_i > pending_ipl && sr.mie)
			pending_ipl <= irq_i;
	end
end

// Read from the outstanding IRQ fifo first.
always_ff @(posedge clk)
if (irst) begin
	irq_ack <= FALSE;
	irq_rd_en <= FALSE;
end
else begin
	irq_ack <= FALSE;
	irq_rd_en <= FALSE;
	if (irq2_i > pending_ipl && irq2_swstk_i==swstk && sr.mie && !irq_empty)
		irq_rd_en <= TRUE;
	else if (irq_i > pending_ipl && swstk_i==swstk && sr.mie)
		irq_ack <= TRUE;
end

wire ic_port;
wire ftaim_full, ftadm_full;
reg ihit_fet, ihit_mux, ihit_dec, ihit_ren, ihit_que;
reg fetch_alt;
wire icnop;
pc_address_ex_t icpc;
wire [2:0] igrp;
reg [7:0] length_byte;
reg [63:0] vec_dat;
always_comb length_byte = ic_line >> {icpc.pc[4:0],3'd0};
always_comb vec_dat = ic_dline >> {icdp[4:0],3'd0};

Qupls_icache
#(.CORENO(CORENO),.CID(0))
uic1
(
	.rst(irst),
	.clk(clk),
	.ce(advance_f),
	.invce(invce),
	.snoop_adr(snoop_adr),
	.snoop_v(snoop_v),
	.snoop_cid(snoop_cid),
	.invall(ic_invall),
	.invline(ic_invline),
	.nop(brtgtv),
	.nop_o(icnop),
	.fetch_alt(fetch_alt & ~alt_ihit),
	.ip_asid(ip_asid),
//	.ip(fetch_alt ? alt_pc : pc),
	.ip(pc),
	.ip_o(icpc),
	.ihit_o(ihito),
	.ihit(ihit),
	.alt_ihit_o(alt_ihit),
	.ic_line_lo_o(ic_clinel),
	.ic_line_hi_o(ic_clineh),
	.ic_valid(ic_valid),
	.miss_vadr(ic_miss_adr),
	.miss_asid(ic_miss_asid),
	.ic_line_i(ic_line_o),
	.wway(ic_wway),
	.wr_ic(wr_ic),
	.dp(icdp),
	.dp_asid(ip_asid),
	.dhit_o(),//ic_dhit),
	.dc_line_o(ic_dline),
	.dc_valid(ic_dvalid),
	.port(ic_port),
	.port_i(1'b0)
);
assign ic_dhit = 1'b1;

// ic_miss_adr is one clock in front of the translation pc_tlb_res.
// Add in a clock delay to line them up for the cache controller.
address_t ic_miss_adrd;
always_ff @(posedge clk)
	ic_miss_adrd <= ic_miss_adr;

wire [3:0] p_override;
wire [4:0] po_bno [0:3];

Qupls_icache_ctrl
#(.CORENO(CORENO),.CID(0))
icctrl1
(
	.rst(irst),
	.clk(clk),
	.wbm_req(ftaim_req),
	.wbm_resp(ftaim_resp),
	.ftam_full(ftaim_resp.rty),
	.hit(ihit),
	.tlb_v(pc_tlb_v),
	.miss_vadr(ic_miss_adrd),
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

Qupls_btb ubtb1
(
	.rst(irst),
	.clk(clk),
	.clk_en(advance_f),
	.en(1'b1),
	.rclk(clk),
	.nmi(pe_nmi),
	.nmi_addr(nmi_addr),
	.irq(irq),
	.irq_addr(irq_addr),
	.next_hwipc(next_hwipc),
	.micro_code_active(micro_code_active),
	.block_header(ibh_t'(ic_line[511:480])),
	.igrp(igrp),
	.length_byte(length_byte),
	.pe_bsdone(pe_bsdone),
	.bs_done_oh(bs_done_oh),
	.do_bsr(do_bsr),
	.do_ret(do_ret),
	.do_call(do_call),
	.ret_pc(ret_pc),
	.bsr_tgt(bsr_tgt),
	.mip0v(mip0v),
	.mip1v(mip1v),
	.mip2v(mip2v),
	.mip3v(mip3v),
	.pc(pc),
	.pc0(pc0),
	.pc1(pc1),
	.pc2(pc2),
	.pc3(pc3),
	.pc4(XWID==2 ? pc2:XWID==3 ? pc3:pc4),
	.next_pc(next_pc),
	.p_override(p_override),
	.po_bno(po_bno),
	.takb0(ntakb[0]),
	.takb1(ntakb[1]),
	.takb2(ntakb[2]),
	.takb3(ntakb[3]),
	.branchmiss(branch_state == BS_CHKPT_RESTORED),
	.misspc(misspc),
	.commit_pc0(commit_pc0),
	.commit_brtgt0(commit_brtgt0),
	.commit_takb0(commit_takb0),
	.commit_grp0(commit_grp0),
	.commit_pc1(commit_pc1),
	.commit_brtgt1(commit_brtgt1),
	.commit_takb1(commit_takb1),
	.commit_grp1(commit_grp1),
	.commit_pc2(commit_pc2),
	.commit_brtgt2(commit_brtgt2),
	.commit_takb2(commit_takb2),
	.commit_grp2(commit_grp2),
	.commit_pc3(commit_pc3),
	.commit_brtgt3(commit_brtgt3),
	.commit_takb3(commit_takb3),
	.commit_grp3(commit_grp3),
	.bno_bitmap(bno_bitmap),
	.act_bno()
);

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
	.ip0(pc0_f),
	.predict_taken0(pt0_mux),
	.ip1(pc1_f1),
	.predict_taken1(pt1_mux),
	.ip2(pc2_f2),
	.predict_taken2(pt2_mux),
	.ip3(pc3_f3),
	.predict_taken3(pt3_mux)
);

wire micro_code_active_v;
wire ne_mca, pe_mca, ee_mca;
reg ne_mca_f, ne_mca_x, pe_mca_x, ee_mca_x;
reg pe_mca_f, ee_mca_f;
edge_det ed4 (
	.rst(irst),
	.clk(clk),
	.ce(advance_pipeline),
	.i(micro_code_active),
	.pe(pe_mca),
	.ne(ne_mca),
	.ee(ee_mca)
);
always_ff @(posedge clk) if (advance_pipeline) pe_mca_f <= pe_mca;
always_ff @(posedge clk) if (advance_pipeline) ee_mca_f <= ee_mca;
always_ff @(posedge clk) if (advance_pipeline) ee_mca_x <= ee_mca_f;

always_ff @(posedge clk)
if (irst)
	ihit_fet <= FALSE;
else begin
	if (advance_f)
		ihit_fet <= ihito;
end
always_ff @(posedge clk)
if (irst)
	ihit_mux <= FALSE;
else begin
	if (advance_pipeline)
		ihit_mux <= ihit_fet;
end
always_ff @(posedge clk)
if (irst)
	ihit_dec <= FALSE;
else begin
	if (advance_pipeline)
		ihit_dec <= ihit_mux;
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

edge_det ued3 (
	.rst(irst),
	.clk(clk),
	.ce(1'b1),
	.i(bs_done_oh),
	.pe(pe_bsdone),
	.ne(),
	.ee()
);

// Do not stomp on instructions is the PC matches the desired PC.
// The PC might be correct if the BTB picked the correct PC.

wire stomp_any = FALSE;//|robentry_stomp;
reg pcf, alt_pcf;
reg bms, bms2, ihit3, bms3, bms4;
reg do_bsr2,do_bsr3,do_bsr4,do_bsr5,do_bsr6,do_bsr7;
always_ff @(posedge clk)
if (irst) begin
	bms <= FALSE;
	bms2 <= FALSE;
	bms3 <= FALSE;
	bms4 <= FALSE;
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
		if (pcf && branch_state==BS_CHKPT_RESTORE)
			bms <= TRUE;
		if (bms3)
			bms <= FALSE;
		bms <= (branch_state >= BS_CHKPT_RESTORE && branch_state <= BS_DONE2);
		bms2 <= bms;
		bms3 <= bms2;
		ihit3 <= ihit_f;
		do_bsr2 <= do_bsr|do_ret;
		if (micro_code_active) begin
			do_bsr3 <= do_bsr2;
		end
		else if (!micro_code_active) begin
			do_bsr3 <= FALSE;
		end
		bms4 <= bms3;
		do_bsr4 <= do_bsr3;
		do_bsr5 <= do_bsr4;
		do_bsr6 <= do_bsr5;
		do_bsr7 <= do_bsr6;
		do_bsr_h <= ((do_bsr|do_ret) || do_bsr_h) && !ihit;
	end
end

always_ff @(posedge clk) stomp_mux2 <= stomp_fet1;

Qupls_stomp ustmp1
(
	.rst(irst),
	.clk(clk),
	.ihit(ihit_f),
	.advance_pipeline(advance_pipeline),
	.advance_pipeline_seg2(advance_pipeline_seg2), 
	.micro_code_active(micro_code_active),
	.branchmiss(branchmiss),
	.branch_state(branch_state), 
	.do_bsr(do_bsr|do_ret),
	.misspc(misspc),
	.pc(pc),
	.pc_f(pc0_f),
	.pc_fet(pc0_fet),
	.pc_mux(ins0_mux.pc),
	.pc_dec(ins0_dec.pc),
	.pc_ren(ins0_ren.pc),
	.stomp_fet(stomp_fet),
	.stomp_mux(stomp_mux),
	.stomp_dec(stomp_dec),
	.stomp_ren(stomp_ren),
	.stomp_que(stomp_que),
	.stomp_quem(stomp_quem),
	.fcu_idv(fcu_idv),
	.fcu_id(fcu_id),
	.missid(missid),
	.stomp_bno(stomp_bno),
	.takb(takb),
	.rob(rob),
	.robentry_stomp(robentry_stomp)
);

// Stomp on all pipeline stages rename and prior on a branch miss.
assign micro_code_active_v = (micro_code_active_x || mip0v || mip1v || mip2v || mip3v) && mipv;
// qd indicates which instructions will queue in a given cycle.
always_comb
begin
	qd = {XWID{1'd0}};
	if ((branchmiss || branch_state < BS_CAPTURE_MISSPC) && |robentry_stomp)
		;
//	else if ((ihito || mipv || mipv2 || mipv3 || mipv4) && !stallq)
	else if (advance_pipeline_seg2)
		if (XWID==2)
			case (~cqd[1:0])

	    2'b00: ; // do nothing

	    2'b01:
	    	panic <= PANIC_INVALIDIQSTATE;
	    // Queued on zero in previous cycle, but not on one.
	    2'b10:	
	    	if (rob[tail1].v==INV)
	    		qd = 2'b10;
	    2'b11:
	    	if (rob[tail0].v==INV) begin
	    		qd = 2'b01;
	    		if (!pt0_q && !mip0v && !ins0_ren.decbus.regs) begin
	    			if (rob[tail1].v==INV)
	    				qd = 2'b11;
	    		end
	    	end
	    endcase
	  // ToDo: fix 3-wide
	  else if (XWID==3)
			case (~cqd)

	    3'b000: ; // do nothing

	    3'b001:	
	    	if (rob[tail0].v==INV)
	    		qd = qd | 3'b001;
	    3'b010:	
	    	if (rob[tail0].v==INV)
	    		qd = qd | 3'b010;
	    3'b011:
	    	if (rob[tail0].v==INV) begin
	    		qd = qd | 3'b010;
	    		if (!pt2_q && !mip2v && !ins2_ren.decbus.regs) begin
	    			if (rob[tail1].v==INV)
	    				qd = qd | 3'b001;
	    		end
	    	end
	    3'b100:	
	    	if (rob[tail0].v==INV)
	    		qd = qd | 3'b100;
	    3'b101:
	    	if (rob[tail0].v==INV) begin
	    		qd = qd | 3'b100;
	    		if (!pt1_q && !mip1v && !ins1_ren.decbus.regs) begin
	    			if (rob[tail1].v==INV)
		    			qd = qd | 3'b001;
		    	end
	    	end
	    3'b110:
	    	if (rob[tail0].v==INV) begin
	    		qd = qd | 3'b100;
	    		if (!pt1_q && !mip1v && !ins1_ren.decbus.regs) begin
	    			if (rob[tail1].v==INV)
	    				qd = qd | 3'b10;
	    		end
	    	end
	    3'b111:
	    	if (rob[tail0].v==INV) begin
	    		qd = qd | 3'b100;
	    		if (!pt1_q && !mip1v && !ins1_ren.decbus.regs) begin
		    		if (rob[tail1].v==INV) begin
		    			qd = qd  | 3'b010;
		    			if (!pt2_q && !mip2v && !ins2_ren.decbus.regs) begin
		    				if (rob[tail2].v==INV)
			    				qd = qd  | 3'b001;
			    		end
			    	end
	    		end
	    	end
	    endcase
		else
		case (~cqd)

//    4'b0000: ; // do nothing

    4'b0001:	
    	panic <= PANIC_INVALIDIQSTATE;
    4'b0010:	
    	panic <= PANIC_INVALIDIQSTATE;
    4'b0011:
    	panic <= PANIC_INVALIDIQSTATE;
    4'b0100:	
    	panic <= PANIC_INVALIDIQSTATE;
    4'b0101:
    	panic <= PANIC_INVALIDIQSTATE;
    4'b0110:
    	panic <= PANIC_INVALIDIQSTATE;
    4'b0111:
    	panic <= PANIC_INVALIDIQSTATE;
    4'b1000:
    	if (rob[tail3].v==INV)
	   		qd = 4'b1000;
	  // Cannot have an instruction in the middle that has not queued.
    4'b1001:
    	panic <= PANIC_INVALIDIQSTATE;
    4'b1010:
    	panic <= PANIC_INVALIDIQSTATE;
    4'b1011:
    	panic <= PANIC_INVALIDIQSTATE;
    4'b1100:
    	if (rob[tail2].v==INV) begin
    		qd = 4'b0100;
    		if (!pt2_q && !ins2_ren.decbus.regs) begin
    			if (rob[tail3].v==INV) begin
	    			qd = 4'b1100;
	    		end
	    	end
    	end
    4'b1101:
    	panic <= PANIC_INVALIDIQSTATE;
    4'b1110:
    	if (rob[tail1].v==INV) begin
    		qd = 4'b0010;
    		if (!pt1_q && !ins1_ren.decbus.regs) begin
    			if (rob[tail2].v==INV) begin
		    		qd = 4'b0110;
	    			if (!pt2_q && !ins2_ren.decbus.regs) begin
	    				if (rob[tail3].v==INV) begin
			    			qd = 4'b1110;
			    		end
			    	end
		    	end
    		end
    	end
    default:
    	if (rob[tail0].v==INV) begin
    		qd = 4'b0001;
    		if (!pt0_q && !ins0_ren.decbus.regs) begin
    			if (rob[tail1].v==INV) begin
	    			qd = 4'b0011;
	    			if (!pt1_q && !ins1_ren.decbus.regs) begin
	    				if (rob[tail2].v==INV) begin
			    			qd = 4'b0111;
		    				if (!pt2_q && !ins2_ren.decbus.regs) begin
		    					if (rob[tail3].v==INV)
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
	cqd <= {XWID{1'd0}};
else begin
	if (advance_pipeline_seg2) begin
		cqd <= next_cqd;
		if (next_cqd == {XWID{1'b1}})
			cqd <= {XWID{1'd0}};
	end
end

reg allqd;
edge_det ued1 (.rst(irst), .clk(clk), .ce(advance_pipeline_seg2), .i(next_cqd=={XWID{1'b1}}), .pe(pe_allqd), .ne(), .ee());

always_comb
	fetch_new = (ihito & ~hirq & (pe_allqd|allqd) & ~mipv) |
							(mipv & ~hirq & (pe_allqd|allqd));

always_comb
	fetch_new_block = pc.pc[$bits(pc_address_t)-1:6]!=icpc.pc[$bits(pc_address_t)-1:6];
always_ff @(posedge clk)
if (advance_pipeline)
	fetch_new_block_x <= fetch_new_block;

always_comb
	hold_ins = |reg_bitmask || micro_code_active;

reg get_next_pc;
always_comb
	get_next_pc = ((pe_allqd||allqd||&next_cqd) && !hold_ins) && ihit && ~hirq;

// All queued flag.

always_ff @(posedge clk)
if (irst)
	allqd <= 1'b1;
else if(advance_pipeline_seg2) begin
	if (pe_allqd & ~(ihito & ~hirq))
		allqd <= 1'b1;
	if (next_cqd=={XWID{1'b1}})
		allqd <= 1'b1;
	if (branchmiss)
		allqd <= 1'b0;
	if (get_next_pc) begin
  	allqd <= &next_cqd;
	end
end

// Instruction pointer (program counter)
// Could use the lack of a IP change to fetch from an alternate path.
// The IP will not change while micro-code is running except when a branch
// instruction is performed. The branch instruction is used to exit the
// micro-code.

always_ff @(posedge clk)
if (irst) begin
	pc.bno_t <= 6'd1;
	pc.bno_f <= 6'd1;
	pc.pc <= RSTPC;
	pcf <= FALSE;
	stomp_fet1 = FALSE;
	stomp_mux1 = FALSE;
	ins0_d_inv = FALSE;
	ins1_d_inv = FALSE;
	ins2_d_inv = FALSE;
	ins3_d_inv = FALSE;
end
else begin
	if (advance_f) begin
		pcf <= FALSE;
		if (get_next_pc) begin
			if (excret)
				pc.pc <= exc_ret_pc;
			else begin
				pc <= next_pc;			// early PC predictor from BTB logic
				hwipc <= next_hwipc;
			end
		end
		else if (!pcf && (bs_done_oh || do_bsr || do_ret)) begin
			pc <= next_pc;
			hwipc <= next_hwipc;
		end
	end
	// Prevent hang when the pipeline cannot advance because there is no room 
	// to queue, yet the IP needs to change to get out of the branch miss state.
	else begin
		if (pe_bsdone || do_bsr || do_ret) begin
			pc <= next_pc;
			hwipc <= next_hwipc;
			pcf <= TRUE;
		end
	end
	// Re-route the PC in event of prediction miss.
	stomp_fet1 = FALSE;
	stomp_mux1 = FALSE;
	ins0_d_inv = FALSE;
	ins1_d_inv = FALSE;
	ins2_d_inv = FALSE;
	ins3_d_inv = FALSE;
	/*
	if (pt0_dec) begin
		if (pt0_dec != ins0_dec.bt) begin
			pc <= pt0_dec ? ins0_dec.brtgt : ins0_dec.pc + 5'd8;
			stomp_fet1 = TRUE;
			stomp_mux1 = TRUE;
			if (pt0_dec) begin
				ins1_d_inv = TRUE;
				ins2_d_inv = TRUE;
				ins3_d_inv = TRUE;
			end
		end
	end
	else if (pt1_dec) begin
		if (pt1_dec != ins1_dec.bt) begin
			pc <= pt1_dec ? ins1_dec.brtgt : ins1_dec.pc + 5'd8;
			stomp_fet1 = TRUE;
			stomp_mux1 = TRUE;
			if (pt1_dec) begin
				ins2_d_inv = TRUE;
				ins3_d_inv = TRUE;
			end
		end
	end
	else if (pt2_dec) begin
		if (pt2_dec != ins2_dec.bt) begin
			pc <= pt2_dec ? ins2_dec.brtgt : ins2_dec.pc + 5'd8;
			stomp_fet1 = TRUE;
			stomp_mux1 = TRUE;
			if (pt2_dec) begin
				ins3_d_inv = TRUE;
			end
		end
	end
	else if (pt3_dec) begin
		if (pt3_dec != ins3_dec.bt) begin
			pc <= pt3_dec ? ins3_dec.brtgt : ins3_dec.pc + 5'd8;
			stomp_fet1 = TRUE;
			stomp_mux1 = TRUE;
		end
	end
	*/
end

// Micro instruction pointer.
// Unless micro-code is running this pointer will be zero. It is set to a non-
// zero value when a macro-instruction is decoded. The first macro instruction
// encountered out of the group of four fetched instructions sets the micro
// instruction pointer. If there is another macro instruction in the fetch
// group then it will become the first instruction of a group once the micro
// code for the previous instruction completes and branches back to the next
// instruction address.
// The next value of the micro instruction pointer is simply loaded from the
// micro-code.

always_ff @(posedge clk)
if (irst)
	micro_ip <= 12'h1A0;
else begin
	if (advance_pipeline) begin
		if (excret)
			micro_ip <= exc_ret_mcip;
		else begin
		  if (~hirq) begin
		  	if ((pe_allqd||allqd||&next_cqd)) begin
					micro_ip <= (mcbrtgtv & mipv) ? mcbrtgt : next_micro_ip;
				end
			end
			if (micro_ip==12'h000) begin
						 if (mip0v) micro_ip <= mip0;
				else if (mip1v) micro_ip <= mip1;
				else if (mip2v) micro_ip <= mip2;
				else if (mip3v) micro_ip <= mip3;
			end
		end
	end
end

// Micro code originating instruction address.
// The micro-code for a vector instruction inherits the address of the vector
// instruction.
// The originating instruction address is used during predicate processing.
// The pred instruction will always be the instruction immediately before the
// vector instruction, so, the address is five less.

always_ff @(posedge clk)
if (irst) begin
	mc_adr.bno_t <= 6'd1;
	mc_adr.bno_f <= 6'd1;
	mc_adr.pc <= RSTPC;
end
else begin
	if (advance_pipeline) begin
		if (excret)
			mc_adr <= exc_ret_pc;
		else begin
			if (micro_ip==12'h000) begin
						 if (mip0v) mc_adr <= ins0_dec.pc;//pc0_d;
				else if (mip1v) mc_adr <= ins1_dec.pc;//pc1_d;
				else if (mip2v) mc_adr <= ins2_dec.pc;//pc2_d;
				else if (mip3v) mc_adr <= ins3_dec.pc;//pc3_d;
			end
		end
	end
end

// Micro instruction register.
// The micro-ir is loaded only when a macro-instruction is decoded.
// Vector instructions are converted to the equivalent scalar instruction.

always_ff @(posedge clk)
if (irst)
	micro_ir.ins <= {57'd0,OP_NOP};
else begin
	if (advance_pipeline) begin
		if (excret)
			micro_ir <= exc_ret_mcir;
		else begin
			if (micro_ip==12'h000) begin
				if (mip0v) begin micro_ir <= ins0_dec; end
				else if (mip1v) begin micro_ir <= ins1_dec; end
				else if (mip2v) begin micro_ir <= ins2_dec; end
				else if (mip3v) begin micro_ir <= ins3_dec; end
			end
		end
	end
end

// Micro-code active flag.
// Micro-code becomes active when the micro-ip is set to a non-zero value and
// inactive once the micro-ip is set to zero.

always_ff @(posedge clk)
if (irst)
	micro_code_active <= TRUE;
else begin
	if (advance_pipeline) begin
		if (excret) begin
			if (|exc_ret_mcip)
				micro_code_active <= TRUE;
		end
		else begin
		  if (~hirq) begin
		  	if ((pe_allqd||allqd||&next_cqd)) begin
					if (((mcbrtgtv & mipv) ? mcbrtgt : next_micro_ip) == 12'h000)
						micro_code_active <= FALSE;
				end
			end
			if (micro_ip==12'h000) begin
				if (mip0v|mip1v|mip2v|mip3v)
					micro_code_active <= TRUE;
			end
		end
	end
end

always_ff @(posedge clk) if (irst) mip0v_r <= FALSE; else if (advance_pipeline_seg2) mip0v_r <= mip0v;
always_ff @(posedge clk) if (irst) mip1v_r <= FALSE; else if (advance_pipeline_seg2) mip1v_r <= mip1v;
always_ff @(posedge clk) if (irst) mip2v_r <= FALSE; else if (advance_pipeline_seg2) mip2v_r <= mip2v;
always_ff @(posedge clk) if (irst) mip3v_r <= FALSE; else if (advance_pipeline_seg2) mip3v_r <= mip3v;
always_ff @(posedge clk) if (irst) mip0v_q <= FALSE; else if (advance_pipeline_seg2) mip0v_q <= mip0v_r;
always_ff @(posedge clk) if (irst) mip1v_q <= FALSE; else if (advance_pipeline_seg2) mip1v_q <= mip1v_r;
always_ff @(posedge clk) if (irst) mip2v_q <= FALSE; else if (advance_pipeline_seg2) mip2v_q <= mip2v_r;
always_ff @(posedge clk) if (irst) mip3v_q <= FALSE; else if (advance_pipeline_seg2) mip3v_q <= mip3v_r;

always_comb
if ((fnIsAtom(ins0_dec.ins) || fnIsAtom(ins1_dec.ins) || fnIsAtom(ins2_dec.ins) || fnIsAtom(ins3_dec.ins)) && irq_i != 6'd63)
	hirq = 1'd0;
else
	hirq = irq && !int_commit && (irq_i > atom_mask[5:0]);

/* ToDo: fix micro-code for XWID other than four */
generate begin : gMicroCode
	case(XWID)
	1:
		begin
			Qupls_micro_code umc0 (
				.om(sr.om),
				.ipl(sr.ipl),
				.micro_ip(micro_ip),
				.micro_ir(micro_ir),
				.next_ip(next_micro_ip),
				.instr(mc_ins0),
				.regx(mc_regx0)
			);
		end
	2:
		begin
			Qupls_micro_code umc0 (
				.om(sr.om),
				.ipl(sr.ipl),
				.micro_ip({micro_ip[11:1],1'd0}),
				.micro_ir(micro_ir),
				.next_ip(),
				.instr(mc_ins0),
				.regx(mc_regx0)
			);

			Qupls_micro_code umc1 (
				.om(sr.om),
				.ipl(sr.ipl),
				.micro_ip({micro_ip[11:1],1'd1}),
				.micro_ir(micro_ir),
				.next_ip(next_mip),
				.instr(mc_ins1),
				.regx(mc_regx1)
			);
			always_comb next_micro_ip = next_mip & 12'hffe;
		end
	3:	
		begin
			Qupls_micro_code umc0 (
				.om(sr.om),
				.ipl(sr.ipl),
				.micro_ip(micro_ip),
				.micro_ir(micro_ir),
				.next_ip(next_micro_ip),
				.instr(mc_ins0),
				.regx(mc_regx0)
			);

			Qupls_micro_code umc1 (
				.om(sr.om),
				.ipl(sr.ipl),
				.micro_ip(micro_ip+1),
				.micro_ir(micro_ir),
				.next_ip(),
				.instr(mc_ins1),
				.regx(mc_regx1)
			);

			Qupls_micro_code umc2 (
				.om(sr.om),
				.ipl(sr.ipl),
				.micro_ip(micro_ip+2),
				.micro_ir(micro_ir),
				.next_ip(),
				.instr(mc_ins2),
				.regx(mc_regx2)
			);
		end
	4:
		begin
			Qupls_micro_code umc0 (
				.om(sr.om),
				.ipl(sr.ipl),
				.micro_ip({micro_ip[11:2],2'd0}),
				.micro_ir(micro_ir),
				.next_ip(),
				.instr(mc_ins0),
				.regx(mc_regx0)
			);

			Qupls_micro_code umc1 (
				.om(sr.om),
				.ipl(sr.ipl),
				.micro_ip({micro_ip[11:2],2'd1}),
				.micro_ir(micro_ir),
				.next_ip(),
				.instr(mc_ins1),
				.regx(mc_regx1)
			);

			Qupls_micro_code umc2 (
				.om(sr.om),
				.ipl(sr.ipl),
				.micro_ip({micro_ip[11:2],2'd2}),
				.micro_ir(micro_ir),
				.next_ip(),
				.instr(mc_ins2),
				.regx(mc_regx2)
			);

			Qupls_micro_code umc3 (
				.om(sr.om),
				.ipl(sr.ipl),
				.micro_ip({micro_ip[11:2],2'd3}),
				.micro_ir(micro_ir),
				.next_ip(next_mip),
				.instr(mc_ins3),
				.regx(mc_regx3)
			);
			always_comb next_micro_ip = next_mip & 12'hffc;
		end
	endcase
end
endgenerate

// No longer useful.
always_comb mc_ins4.ins = {57'd0,OP_NOP};
always_comb mc_ins5.ins = {57'd0,OP_NOP};
always_comb mc_ins6.ins = {57'd0,OP_NOP};
always_comb mc_ins7.ins = {57'd0,OP_NOP};
always_comb mc_ins8.ins = {57'd0,OP_NOP};

always_ff @(posedge clk)
if (irst)
	mipv2 <= 1'd0;
else begin
	if (advance_pipeline) 
		mipv2 <= mipv;
end
always_ff @(posedge clk)
if (irst)
	mipv3 <= 1'd0;
else begin
	if (advance_pipeline) 
		mipv3 <= mipv2;
end
always_ff @(posedge clk)
if (irst)
	mipv4 <= 1'd0;
else begin
	if (advance_pipeline) 
		mipv4 <= mipv3;
end

// A missed cache line comes back as all zeros. Unfortunately this matches with
// the SYS macro instruction. So, we test to ensure there was a cache hit before
// setting the micro-code address.
Qupls_mcat umcat0(stomp_dec|(!ihit_mux && !micro_code_active_d), ins0_dec, mip0);
Qupls_mcat umcat1(stomp_dec|(!ihit_mux && !micro_code_active_d), ins1_dec, mip1);
Qupls_mcat umcat2(stomp_dec|(!ihit_mux && !micro_code_active_d), ins2_dec, mip2);
Qupls_mcat umcat3(stomp_dec|(!ihit_mux && !micro_code_active_d), ins3_dec, mip3);

always_comb mip0v = |mip0;
always_comb mip1v = |mip1;
always_comb mip2v = |mip2;
always_comb mip3v = |mip3;
always_comb nmip = |next_micro_ip;
always_comb mipv = |micro_ip;

// -----------------------------------------------------------------------------
// PARSE stage (length decode)
// -----------------------------------------------------------------------------

pc_address_ex_t pco;
wire [4:0] len0, len1, len2, len3, len4, len5, len6, len7;
wire [2:0] igrp2;

assign ihit_f = ihito;
assign pco = pc;
assign len0 = 5'd8;
assign len1 = 5'd8;
assign len2 = 5'd8;
assign len3 = 5'd8;
assign len4 = 5'd8;
assign len5 = 5'd8;
assign len6 = 5'd8;
assign len7 = 5'd8;

always_comb pc0 = pc + (SUPPORT_VLIB ? 5'd1 : 5'd0);
always_comb 
begin
	pc1 = pc0;
	pc1.pc = micro_code_active ? pc0.pc : pc0.pc + len0;
end
always_comb
begin
	pc2 = pc0;
	pc2.pc = micro_code_active ? pc0.pc : pc1.pc + len1;
end
always_comb
begin
	pc3 = pc0;
	pc3.pc = micro_code_active ? pc0.pc : pc2.pc + len2;
end
always_comb
begin
	pc4 = pc0;
	pc4.pc = micro_code_active ? pc0.pc : pc3.pc + len3;
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

wire [2:0] irq_fet;
wire irqf_fet;
pc_address_ex_t misspc_fet;
wire [1023:0] ic_line_fet;
pc_address_t ic_hwipc, hwipc_fet;
wire micro_code_active_fet;

always_ff @(posedge clk)
	ic_hwipc <= hwipc;

pregno_t pred_reg;
always_comb
	ic_line = {ic_clineh.data,ic_clinel.data};

Qupls_pipeline_fet ufet1
(
	.rst(irst),
	.clk(clk),
	.rstcnt(rstcnt),
	.ihit(ihito),
	.en(advance_f),
	.pc_i(icpc),
	.misspc(misspc),
	.misspc_fet(misspc_fet),
	.hwipc(ic_hwipc),
	.hwipc_fet(hwipc_fet),
	.pc0_fet(pc0_fet),
	.stomp_fet(stomp_fet),
	.stomp_bno(stomp_bno),
	.ic_line_i(ic_line),
	.ic_line_fet(ic_line_fet),
	.nmi_i(pe_nmi),
	.irq_i(ic_irq),
	.irq_fet(irq_fet),
	.irqf_i(ic_irqf),
	.irqf_fet(irqf_fet),
	.micro_code_active(micro_code_active),
	.micro_code_active_fet(micro_code_active_fet),
	.mc_adr(mc_adr)
);

// -----------------------------------------------------------------------------
// mux stage
// -----------------------------------------------------------------------------

wire exti_nop;	
wire ext_stall;
pc_address_ex_t pc0_f1;
pc_address_ex_t pc0_f2;
pc_address_ex_t pc0_f3;

always_comb
begin
	pc0_f1 = pc0_f;
	pc0_f1.pc = pc0_f.pc + 6'd8;
end
always_comb
begin
	pc0_f2 = pc0_f;
	pc0_f2.pc = pc0_f.pc + 6'd16;
end
always_comb
begin
	pc0_f3 = pc0_f;
	pc0_f3.pc = pc0_f.pc + 6'd24;
end

always_ff @(posedge clk)
	takb_pc = ntakb;
always_ff @(posedge clk)
if (advance_pipeline)
	takb_f <= takb_pc;
always_ff @(posedge clk)
if (advance_pipeline)
	takb_fet <= takb_f;

always_comb mcip0_mux = micro_ip;
always_comb mcip1_mux = micro_ip|4'd1;
always_comb mcip2_mux = micro_ip|4'd2;
always_comb mcip3_mux = micro_ip|4'd3;

// Latency of one.
// pt0_dec, etc. should be in line with ins0_dec, etc
Qupls_pipeline_mux uiext1
(
	.rst_i(irst),
	.clk_i(clk),
	.rstcnt(rstcnt[2:0]),
	.advance_fet(advance_f),
	.en_i(advance_pipeline),
	.ssm_flag(ssm_flag),
	.ihit(ihito),
	.sr(sr),
	.stomp_bno(stomp_bno),
	.stomp_mux(stomp_mux|stomp_mux1|stomp_mux2/*icnop||brtgtv||fetch_new_block_x*/),
	.nop_o(exti_nop),
	.nmi_i(pe_nmi),
	.irq_fet(irq_fet),
	.irqf_fet(irqf_fet),
	.hirq_i(hirq),
	.vect_i(vect_i),
	.reglist_active(1'b0),
	.mipv_i(micro_code_active),
	.mip_i(micro_ip),
	.ic_line_fet(ic_line_fet),
	.grp_i(igrp2),
	.misspc_fet(misspc_fet),
	.pc0_fet(pc0_fet),
	.hwipc_fet(hwipc_fet),
	.micro_code_active(micro_code_active_fet),
	.branchmiss(branch_state > BS_STATE3),
	.mc_offs(32'd0),//mc_offs),
	.mc_adr(mc_adr),
	.takb_fet(takb_fet),
	.pt_mux(pt_mux),
	.p_override(p_override),
	.po_bno(po_bno),
	.pc_i(icpc),
	.mcip0_i(mcip0_mux),
	.mcip1_i(mcip1_mux),
	.mcip2_i(mcip2_mux),
	.mcip3_i(mcip3_mux),
	.vl(vl),
	.ls_bmf_i(ls_bmf),
	.pack_regs_i(pack_regs),
	.scale_regs_i(scale_regs),
	.regcnt_i(8'd0),
	.mc_ins0_i(mc_ins0),
	.mc_ins1_i(mc_ins1),
	.mc_ins2_i(mc_ins2),
	.mc_ins3_i(mc_ins3),
	.ins0_mux_o(ins0_mux),
	.ins1_mux_o(ins1_mux),
	.ins2_mux_o(ins2_mux),
	.ins3_mux_o(ins3_mux),
	.ins4_mux_o(ins4_mux),
	.len0_i(len0),
	.len1_i(len1),
	.len2_i(len2),
	.len3_i(len3),
	.grp_o(grp_d),
	.do_bsr(do_bsr),
	.do_ret(do_ret),
	.do_call(do_call),
	.ret_pc(ret_pc),
	.bsr_tgt(bsr_tgt),
	.stall(ext_stall),
	.get(dc_get)
);

// ----------------------------------------------------------------------------
// DECODE stage
// ----------------------------------------------------------------------------

ex_instruction_t [3:0] instr;
pregno_t Rt0_dec, Rt1_dec, Rt2_dec, Rt3_dec;
pregno_t [3:0] tags2free;
wire [3:0] freevals;
wire [PREGS-1:0] avail_reg;						// available registers
checkpt_ndx_t cndx0,cndx1,cndx2,cndx3,pcndx;		// checkpoint index for each queue slot
reg restore;		// = branch_state==BS_CHKPT_RESTORE && restore_en;// && !fcu_cjb;
wire restored;	// restore_chkpt delayed one clock.
wire Rt0_decv;
wire Rt1_decv;
wire Rt2_decv;
wire Rt3_decv;

Qupls_pipeline_dec udecstg1
(
	.rst_i(rst_i),
	.rst(irst),
	.clk(clk),
	.en(advance_pipeline),
	.clk5x(clk5x),
	.ph4(ph4),
	.restored(restored),
	.restore_list(restore_list),
	.unavail_list(unavail_list),
	.sr(sr),
	.tags2free(tags2free),
	.freevals(freevals),
	.bo_wr(bo_wr),
	.bo_preg(bo_preg),
	.stomp_dec(stomp_dec),
	.stomp_mux(stomp_mux),
	.stomp_bno(stomp_bno),
	.ins0_mux(ins0_mux), 
	.ins1_mux(ins1_mux),
	.ins2_mux(ins2_mux),
	.ins3_mux(ins3_mux),
	.ins4_mux(ins4_mux),
	.ins0_dec_inv(ins0_d_inv),
	.ins1_dec_inv(ins1_d_inv),
	.ins2_dec_inv(ins2_d_inv),
	.ins3_dec_inv(ins3_d_inv),
	.Rt0_dec(Rt0_dec),
	.Rt1_dec(Rt1_dec),
	.Rt2_dec(Rt2_dec),
	.Rt3_dec(Rt3_dec),
	.Rt0_decv(Rt0_decv),
	.Rt1_decv(Rt1_decv),
	.Rt2_decv(Rt2_decv),
	.Rt3_decv(Rt3_decv),
	.micro_code_active_mux(micro_code_active_x),
	.micro_code_active_dec(micro_code_active_d),
	.ins0_dec(ins0_dec),
	.ins1_dec(ins1_dec),
	.ins2_dec(ins2_dec),
	.ins3_dec(ins3_dec),
	.pc0_dec(pc0_d),
	.pc1_dec(pc1_d),
	.pc2_dec(pc2_d),
	.pc3_dec(pc3_d),
	.ren_stallq(ren_stallq),
	.ren_rst_busy(ren_rst_busy),
	.avail_reg(avail_reg)
);

reg wrport0_v;
reg wrport1_v;
reg wrport2_v;
reg wrport3_v;
reg wrport4_v;
reg wrport5_v;
reg wt0;
reg wt1;
reg wt2;
reg wt3;
reg wt4;
value_t wrport0_res;
value_t wrport1_res;
value_t wrport2_res;
value_t wrport3_res;
value_t wrport4_res;
value_t wrport5_res;
pregno_t wrport0_Rt;
pregno_t wrport1_Rt;
pregno_t wrport2_Rt;
pregno_t wrport3_Rt;
pregno_t wrport4_Rt;
pregno_t wrport5_Rt;
aregno_t wrport0_aRt;
aregno_t wrport1_aRt;
aregno_t wrport2_aRt;
aregno_t wrport3_aRt;
aregno_t wrport4_aRt;
aregno_t wrport5_aRt;
reg wrport0_aRtz;
reg wrport1_aRtz;
reg wrport2_aRtz;
reg wrport3_aRtz;
reg wrport4_aRtz;
reg wrport5_aRtz;
checkpt_ndx_t wrport0_cp;
checkpt_ndx_t wrport1_cp;
checkpt_ndx_t wrport2_cp;
checkpt_ndx_t wrport3_cp;

wire stomp0;
wire stomp1;
wire stomp2;
wire stomp3;

aregno_t [23:0] arn;
reg [23:0] arnt;
reg [2:0] arng [0:23];
wire [23:0] arnv;
pregno_t [23:0] prn;
pregno_t [23:0] prn1;
checkpt_ndx_t [23:0] rn_cp;
wire [23:0] prnv;
wire [0:0] arnbank [23:0];
checkpt_ndx_t [3:0] cndx_ren;
checkpt_ndx_t pcndx_ren;

always_comb
begin
	arn[0] = ins0_dec.aRa; arnt[0] = 1'b0; arng[0] = 3'd0;
	arn[1] = ins0_dec.aRb; arnt[1] = 1'b0; arng[1] = 3'd0;
	arn[2] = ins0_dec.aRc; arnt[2] = 1'b0; arng[2] = 3'd0;
	arn[3] = ins0_dec.aRt; arnt[3] = 1'b1; arng[3] = 3'd0;
	
	arn[4] = ins1_dec.aRa; arnt[4] = 1'b0; arng[4] = 3'd1;
	arn[5] = ins1_dec.aRb; arnt[5] = 1'b0; arng[5] = 3'd1;
	arn[6] = ins1_dec.aRc; arnt[6] = 1'b0; arng[6] = 3'd1;
	arn[7] = ins1_dec.aRt; arnt[7] = 1'b1; arng[7] = 3'd1;
	
	arn[8] = ins2_dec.aRa; arnt[8] = 1'b0; arng[8] = 3'd2;
	arn[9] = ins2_dec.aRb; arnt[9] = 1'b0; arng[9] = 3'd2;
	arn[10] = ins2_dec.aRc; arnt[10] = 1'b0; arng[10] = 3'd2;
	arn[11] = ins2_dec.aRt; arnt[11] = 1'b1; arng[11] = 3'd2;
	
	arn[12] = ins3_dec.aRa; arnt[12] = 1'b0; arng[12] = 3'd3;
	arn[13] = ins3_dec.aRb; arnt[13] = 1'b0; arng[13] = 3'd3;
	arn[14] = ins3_dec.aRc; arnt[14] = 1'b0; arng[14] = 3'd3;
	arn[15] = ins3_dec.aRt; arnt[15] = 1'b1; arng[15] = 3'd3;

 	arn[16] = 8'h00; arnt[16] = 1'b0; arng[16] = 3'd0;
	
	arn[17] = ins0_dec.decbus.Rm; arnt[17] = 1'b0; arng[17] = 3'd0;
	arn[18] = ins1_dec.decbus.Rm; arnt[18] = 1'b0; arng[18] = 3'd1;
	arn[19] = ins2_dec.decbus.Rm; arnt[19] = 1'b0; arng[19] = 3'd2;
	arn[20] = ins3_dec.decbus.Rm; arnt[20] = 1'b0; arng[20] = 3'd3;
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

assign arnbank[0] = sr.om & {2{|ins0_dec.decbus.Ra}} & 0;
assign arnbank[1] = sr.om & {2{|ins0_dec.decbus.Rb}} & 0;
assign arnbank[2] = sr.om & {2{|ins0_dec.decbus.Rc}} & 0;
assign arnbank[3] = sr.om & {2{|ins0_dec.decbus.Rt}} & 0;
assign arnbank[4] = sr.om & {2{|ins1_dec.decbus.Ra}} & 0;
assign arnbank[5] = sr.om & {2{|ins1_dec.decbus.Rb}} & 0;
assign arnbank[6] = sr.om & {2{|ins1_dec.decbus.Rc}} & 0;
assign arnbank[7] = sr.om & {2{|ins1_dec.decbus.Rt}} & 0;
assign arnbank[8] = sr.om & {2{|ins2_dec.decbus.Ra}} & 0;
assign arnbank[9] = sr.om & {2{|ins2_dec.decbus.Rb}} & 0;
assign arnbank[10] = sr.om & {2{|ins2_dec.decbus.Rc}} & 0;
assign arnbank[11] = sr.om & {2{|ins2_dec.decbus.Rt}} & 0;
assign arnbank[12] = sr.om & {2{|ins3_dec.decbus.Ra}} & 0;
assign arnbank[13] = sr.om & {2{|ins3_dec.decbus.Rb}} & 0;
assign arnbank[14] = sr.om & {2{|ins3_dec.decbus.Rc}} & 0;
assign arnbank[15] = sr.om & {2{|ins3_dec.decbus.Rt}} & 0;
assign arnbank[16] = 1'b0;
assign arnbank[17] = 1'b0;
assign arnbank[18] = 1'b0;
assign arnbank[19] = 1'b0;
assign arnbank[20] = 1'b0;
assign arnbank[21] = 1'b0;
assign arnbank[22] = 1'b0;
assign arnbank[23] = 1'b0;


reg vec_stallq;
reg vec_stall2;
always_comb advance_pipeline = !stallq && !vec_stallq && !ext_stall;
always_comb advance_pipeline_seg2 = advance_pipeline;// || dc_get;//(!stallq && !vec_stallq) || dc_get;
always_comb vec_stallq = !ic_dhit || vec_stall2;
always_comb advance_f = advance_pipeline && !micro_code_active;
reg nq0,nq1,nq2,nq3;
ibh_t ibh;
always_comb
	ibh = ibh_t'(ic_line[511:480]);
always_comb nq0 = TRUE;
always_comb nq1 = pc1[5:0] <= ibh.lastip;
always_comb nq2 = pc2[5:0] <= ibh.lastip;
always_comb nq3 = pc3[5:0] <= ibh.lastip;

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

reg room_for_que;
wire [3:0] enqueue_room;

Qupls_queue_room uqroom1
(
	.rob(rob),
	.head0(head0),
	.tails(tails),
	.room(enqueue_room)
);

always_comb
	room_for_que = enqueue_room > 4'd3;
assign nq = !(branchmiss || (!bs_idle_oh && branch_state < BS_CAPTURE_MISSPC)) && advance_pipeline && room_for_que && (!stomp_que || stomp_quem);

assign stallq = !rstcnt[2] || rat_stallq || ren_stallq || !room_for_que || !bs_idle_oh;


reg signed [$clog2(ROB_ENTRIES):0] cmtlen;			// Will always be >= 0
reg signed [$clog2(ROB_ENTRIES):0] group_len;		// Commit group length

wire do_commit;
reg cmttlb0, cmttlb1,cmttlb2,cmttlb3;
reg htcolls;		// head <-> tail collision
reg cmtbr;

// When to stomp on instructions enqueuing.
// If the slot is not queuing then it is stomped on.
reg stomp0_q;
reg stomp1_q;
reg stomp2_q;
reg stomp3_q;
// Detect stomp on leading instructions due to a branch.
wire stomp0b_r = branch_state > BS_STATE3 && misspc.pc > ins0_ren.pc.pc;
wire stomp1b_r = branch_state > BS_STATE3 && misspc.pc > ins1_ren.pc.pc;
wire stomp2b_r = branch_state > BS_STATE3 && misspc.pc > ins2_ren.pc.pc;
wire stomp3b_r = branch_state > BS_STATE3 && misspc.pc > ins3_ren.pc.pc;
wire stomp0_r = /*~qd_r[0]||stomp_ren||stomp0b_r*/stomp_ren && ins0_ren.pc.bno_t!=stomp_bno;
wire stomp1_r = /*~qd_r[1]||stomp_ren||stomp1b_r||*/(stomp_ren && ins1_ren.pc.bno_t!=stomp_bno);// ||
//							 (ins0_ren.decbus.br && ins0_ren.bt);//pt0_r||XWID < 2;
wire stomp2_r = /*~qd_r[2]||stomp_ren||stomp2b_r||*/(stomp_ren && ins2_ren.pc.bno_t!=stomp_bno);// ||
//							 (ins0_ren.decbus.br && ins0_ren.bt) ||
//							 (ins1_ren.decbus.br && ins1_ren.bt)
//;//pt0_r||pt1_r||XWID < 3;
wire stomp3_r = /*~qd_r[3]||stomp_ren||stomp3b_r||*/(stomp_ren && ins3_ren.pc.bno_t!=stomp_bno);// ||
//							 (ins0_ren.decbus.br && ins0_ren.bt) ||
//							 (ins1_ren.decbus.br && ins1_ren.bt) ||
//							 (ins2_ren.decbus.br && ins2_ren.bt)
//							 ;
//;//pt0_r||pt1_r||pt2_r||XWID < 4;
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
always_ff @(posedge clk) if (advance_pipeline) bsi <= {bsi[1:0],pe_bsidle};
always_ff @(posedge clk) if (advance_pipeline) stomp2_q <= stomp2_r;
always_ff @(posedge clk) if (advance_pipeline) stomp3_q <= stomp3_r;
assign stomp0 = ((stomp0_r|stomp_ren) /*&& ins0_ren.pc.bno_t!=stomp_bno*/);
assign stomp1 = ((stomp1_r|stomp_ren|ins0_ren.decbus.macro) /*&& ins1_ren.pc.bno_t!=stomp_bno*/);
assign stomp2 = ((stomp2_r|stomp_ren|ins0_ren.decbus.macro|ins1_ren.decbus.macro) /*&& ins2_ren.pc.bno_t!=stomp_bno*/);
assign stomp3 = ((stomp3_r|stomp_ren|ins0_ren.decbus.macro|ins1_ren.decbus.macro|ins2_ren.decbus.macro) /*&& ins3_ren.pc.bno_t!=stomp_bno*/);
wire ornop0 = 1'b0;
wire ornop1 = ins0_ren.decbus.bsr;
wire ornop2 = ins0_ren.decbus.bsr || ins1_ren.decbus.bsr;
wire ornop3 = ins0_ren.decbus.bsr || ins1_ren.decbus.bsr || ins2_ren.decbus.bsr;

/*
assign arnv[0] = !stomp0;
assign arnv[1] = !stomp0;
assign arnv[2] = !stomp0;
assign arnv[3] = !stomp0;
assign arnv[17] = !stomp0;

assign arnv[4] = !stomp1;
assign arnv[5] = !stomp1;
assign arnv[6] = !stomp1;
assign arnv[7] = !stomp1;
assign arnv[18] = !stomp1;

assign arnv[8] = !stomp2;
assign arnv[9] = !stomp2;
assign arnv[10] = !stomp2;
assign arnv[11] = !stomp2;
assign arnv[19] = !stomp2;

assign arnv[12] = !stomp3;
assign arnv[13] = !stomp3;
assign arnv[14] = !stomp3;
assign arnv[15] = !stomp3;
assign arnv[20] = !stomp3;

assign arnv[16] = 1'b1;
*/
assign arnv = 24'hFFFFFF;

pregno_t Rt0_ren;
pregno_t Rt1_ren;
pregno_t Rt2_ren;
pregno_t Rt3_ren;
wire Rt0_renv;
wire Rt1_renv;
wire Rt2_renv;
wire Rt3_renv;

/*
always_ff @(posedge clk)
if (advance_pipeline) begin
	if (alloc0 && ins0_ren.decbus.Rt==0) begin
		$display("alloced r0");
		$finish;
	end
	if (alloc1 && ins1_ren.decbus.Rt==0) begin
		$display("alloced r0");
		$finish;
	end
	if (alloc2 && ins2_ren.decbus.Rt==0) begin
		$display("alloced r0");
		$finish;
	end
	if (alloc3 && ins3_ren.decbus.Rt==0) begin
		$display("alloced r0");
		$finish;
	end
end
*/

wire free_chkpt;
checkpt_ndx_t fchkpt;
checkpt_ndx_t miss_cp;
rob_ndx_t chkpt_rndx;
always_comb
	miss_cp = rob[missid].cndx;
assign cndx1 = cndx0;
assign cndx2 = cndx0;
assign cndx3 = cndx0;

Qupls_pipeline_ren uren1
(
	.rst(irst),
	.clk(clk),
	.clk5x(clk5x),
	.ph4(ph4),
	.en(advance_pipeline),
	.nq(nq),
	.restore(restore),
	.restored(restored),
	.restore_list(restore_list),
	.miss_cp(miss_cp),
	.new_chkpt(inc_chkpt),
	.chkpt_amt(chkpt_inc_amt),
	.tail0(tail0),
	.rob(rob),
	.robentry_stomp(robentry_stomp),
	.stomp_ren(stomp_ren),
	.stomp_bno(stomp_bno),
	.branch_state(branch_state),
	.avail_reg(avail_reg),
	.sr(sr),
	.arn(arn),
	.arng(arng),
	.arnt(arnt),
	.arnv(arnv),
	.rn_cp(rn_cp),
	.store_argC_pReg(store_argC_pReg),
	.prn(prn),
	.prnv(prnv),
	.Rt0_dec(Rt0_dec),
	.Rt1_dec(Rt1_dec),
	.Rt2_dec(Rt2_dec),
	.Rt3_dec(Rt3_dec),
	.Rt0_decv(Rt0_decv),
	.Rt1_decv(Rt1_decv),
	.Rt2_decv(Rt2_decv),
	.Rt3_decv(Rt3_decv),
	.Rt0_ren(Rt0_ren),
	.Rt1_ren(Rt1_ren),
	.Rt2_ren(Rt2_ren),
	.Rt3_ren(Rt3_ren),
	.Rt0_renv(Rt0_renv),
	.Rt1_renv(Rt1_renv),
	.Rt2_renv(Rt2_renv),
	.Rt3_renv(Rt3_renv),
	.ins0_dec(ins0_dec),
	.ins1_dec(ins1_dec),
	.ins2_dec(ins2_dec),
	.ins3_dec(ins3_dec),
	.ins0_ren(ins0_ren),
	.ins1_ren(ins1_ren),
	.ins2_ren(ins2_ren),
	.ins3_ren(ins3_ren),
	
	.wrport0_v(wrport0_v),
	.wrport1_v(wrport1_v),
	.wrport2_v(wrport2_v),
	.wrport3_v(wrport3_v),
	.wrport0_aRt(wrport0_aRt),
	.wrport1_aRt(wrport1_aRt),
	.wrport2_aRt(wrport2_aRt),
	.wrport3_aRt(wrport3_aRt),
	.wrport0_Rt(wrport0_Rt),
	.wrport1_Rt(wrport1_Rt),
	.wrport2_Rt(wrport2_Rt),
	.wrport3_Rt(wrport3_Rt),
	.wrport0_res(wrport0_res),
	.wrport1_res(wrport1_res),
	.wrport2_res(wrport2_res),
	.wrport3_res(wrport3_res),
	.wrport0_cp(wrport0_cp),
	.wrport1_cp(wrport1_cp),
	.wrport2_cp(wrport2_cp),
	.wrport3_cp(wrport3_cp),
	
	.cmtav(do_commit && rob[head0].v && cmtcnt > 0),
	.cmtbv(do_commit && rob[head1].v && cmtcnt > 1),
	.cmtcv(do_commit && rob[head2].v && cmtcnt > 2),
	.cmtdv(do_commit && rob[head3].v && cmtcnt > 3),
	.cmtaiv(do_commit && !rob[head0].v && cmtcnt > 0),
	.cmtbiv(do_commit && !rob[head1].v && cmtcnt > 1),
	.cmtciv(do_commit && !rob[head2].v && cmtcnt > 2),
	.cmtdiv(do_commit && !rob[head3].v && cmtcnt > 3),
	.cmtaa(rob[head0].op.aRt),
	.cmtba(rob[head1].op.aRt),
	.cmtca(rob[head2].op.aRt),
	.cmtda(rob[head3].op.aRt),
	.cmtap(rob[head0].op.nRt),
	.cmtbp(rob[head1].op.nRt),
	.cmtcp(rob[head2].op.nRt),
	.cmtdp(rob[head3].op.nRt),
	.cmta_cp(rob[head0].cndx),
	.cmtb_cp(rob[head1].cndx),
	.cmtc_cp(rob[head2].cndx),
	.cmtd_cp(rob[head3].cndx),

	.cmtbr(cmtbr),
	.tags2free(tags2free),
	.freevals(freevals),
	.free_chkpt(free_chkpt),
	.fchkpt(fchkpt),
	.fcu_id(fcu_id),
	.backout(backout),
	.bo_wr(bo_wr),
	.bo_areg(bo_areg),
	.bo_preg(bo_preg),
	.bo_nreg(bo_nreg),
	.cndx(cndx0),
	.pcndx(pcndx),
	.rat_stallq(rat_stallq),
	.micro_code_active_dec(micro_code_active_d),
	.micro_code_active_ren(micro_code_active_r)
);


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
	pc0_f.bno_t <= 6'd1;
	pc0_f.bno_f <= 6'd1;
	pc0_f.pc <= RSTPC;
end
else begin
//	if (advance_f)
	pc0_f <= icpc;//pc0;
end

/*
always_ff @(posedge clk)
if (irst)
	micro_code_active_f <= TRUE;
else begin
	if (advance_pipeline)
		micro_code_active_f <= micro_code_active;
end
*/
always_ff @(posedge clk)
if (irst)
	micro_code_active_x <= FALSE;
else begin
	if (advance_pipeline)
		micro_code_active_x <= micro_code_active;
end
/*
always_comb
	micro_code_active_x = micro_code_active;
*/

// The cycle after the length is calculated
// instruction extract inputs
pc_address_ex_t pc0_x1;
always_ff @(posedge clk)
if (irst) begin
	pc0_x1.bno_t <= 6'd1;
	pc0_x1.bno_f <= 6'd1;
	pc0_x1.pc <= RSTPC;
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
	pt0_r <= pt0_dec;
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pt1_r <= pt1_dec;
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pt2_r <= pt2_dec;
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pt3_r <= pt3_dec;

Qupls_pipeline_que uque1
(
	.rst(irst),
	.clk(clk),
	.en(advance_pipeline),
	.ins0_ren(ins0_ren),
	.ins1_ren(ins1_ren),
	.ins2_ren(ins2_ren),
	.ins3_ren(ins3_ren),
	.ins0_que(ins0_que),
	.ins1_que(ins1_que),
	.ins2_que(ins2_que),
	.ins3_que(ins3_que),
	.micro_code_active_ren(micro_code_active_r),
	.micro_code_active_que(micro_code_active_q)
);

always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pt0_q <= pt0_r;
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pt1_q <= pt1_r;
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pt2_q <= pt2_r;
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pt3_q <= pt3_r;

always_ff @(posedge clk)
if (advance_pipeline_seg2)
	grp_q <= grp_r;
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	grp_r <= grp_d;

// Do not update the register file if the architectural register is zero.
// A dud rename register is used for architectural register zero, and it
// should not be updated. The register file bypasses physical 
// register zero to zero.

// There are some pipeline delays to account for.
pregno_t alu0_Rt2, fpu0_Rt3;
aregno_t alu0_aRt2, fpu0_aRt3;
pregno_t alu1_Rt2;
aregno_t alu1_aRt2;
value_t fpu0_res3;
checkpt_ndx_t alu0_cp2, alu1_cp2, fpu0_cp2;
wire alu0_aRtz1, alu0_aRtz2, alu1_aRtz1, alu1_aRtz2, fpu0_aRtz2;
rob_ndx_t alu0_id2, alu1_id2, fpu0_id2;
vtdl #($bits(pregno_t)) udlyal1 (.clk(clk), .ce(1'b1), .a(4'd0), .d(alu0_Rt), .q(alu0_Rt2) );
vtdl #($bits(aregno_t)) udlyal2 (.clk(clk), .ce(1'b1), .a(4'd0), .d(alu0_aRt), .q(alu0_aRt2) );
vtdl #(1) 							udlyal3 (.clk(clk), .ce(1'b1), .a(4'd0), .d(alu0_aRtz), .q(alu0_aRtz2) );
vtdl #(1) 							udlyal5 (.clk(clk), .ce(1'b1), .a(4'd0), .d(alu0_sc_done), .q(alu0_sc_done2) );
vtdl #($bits(rob_ndx_t))	udlyal6 (.clk(clk), .ce(1'b1), .a(4'd0), .d(alu0_id), .q(alu0_id2) );
vtdl #($bits(checkpt_ndx_t)) udlyal7 (.clk(clk), .ce(1'b1), .a(4'd0), .d(alu0_cp), .q(alu0_cp2) );
vtdl #($bits(pregno_t)) udlyal1b (.clk(clk), .ce(1'b1), .a(4'd0), .d(alu1_Rt), .q(alu1_Rt2) );
vtdl #($bits(aregno_t)) udlyal2b (.clk(clk), .ce(1'b1), .a(4'd0), .d(alu1_aRt), .q(alu1_aRt2) );
vtdl #(1) 							udlyal3b (.clk(clk), .ce(1'b1), .a(4'd0), .d(alu1_aRtz), .q(alu1_aRtz2) );
vtdl #(1) 							udlyal5b (.clk(clk), .ce(1'b1), .a(4'd0), .d(alu1_sc_done), .q(alu1_sc_done2) );
vtdl #($bits(rob_ndx_t))	udlyal6b (.clk(clk), .ce(1'b1), .a(4'd0), .d(alu1_id), .q(alu1_id2) );
vtdl #($bits(checkpt_ndx_t)) udlyal7b (.clk(clk), .ce(1'b1), .a(4'd0), .d(alu1_cp), .q(alu1_cp2) );
//vtdl #($bits(value_t))  udlyal4 (.clk(clk), .ce(1'b1), .a(4'd0), .d(alu0_res), .q(alu0_res2) );
vtdl #($bits(pregno_t)) udlyfp1 (.clk(clk), .ce(1'b1), .a(4'd0), .d(fpu0_Rt), .q(fpu0_Rt3) );
vtdl #($bits(aregno_t)) udlyfp2 (.clk(clk), .ce(1'b1), .a(4'd0), .d(fpu0_aRt), .q(fpu0_aRt3) );
vtdl #(1) 							udlyfp3 (.clk(clk), .ce(1'b1), .a(4'd0), .d(fpu0_aRtz), .q(fpu0_aRtz2) );
vtdl #(1) 							udlyfp5 (.clk(clk), .ce(1'b1), .a(4'd0), .d(fpu0_sc_done), .q(fpu0_sc_done2) );
vtdl #($bits(rob_ndx_t))	udlyfp6 (.clk(clk), .ce(1'b1), .a(4'd0), .d(fpu0_id), .q(fpu0_id2) );
vtdl #($bits(checkpt_ndx_t)) udlyfp7b (.clk(clk), .ce(1'b1), .a(4'd0), .d(fpu0_cp), .q(fpu0_cp2) );
//vtdl #($bits(value_t))  udlyfp4 (.clk(clk), .ce(1'b1), .a(4'd0), .d(fpu0_res), .q(fpu0_res3) );

always_comb wrport0_aRtz = alu0_aRtz2;
always_comb wrport1_aRtz = alu1_aRtz;
always_comb wrport2_aRtz = dram_aRtz0;
always_comb wrport3_aRtz = fpu0_aRtz2;
always_comb wrport4_aRtz = dram_aRtz1;
always_comb wrport5_aRtz = fpu1_aRtz;
always_comb wrport0_v = (alu0_sc_done2|alu0_done) && !alu0_aRtz2;
always_comb wrport1_v = (alu1_sc_done2|alu1_done) && !alu1_aRtz2 && NALU > 1;
always_comb wrport2_v = dram_v0 && !dram_aRtz0;
always_comb wrport3_v = (fpu0_sc_done2|fpu0_done1) && !fpu0_aRtz2 && NFPU > 0;
always_comb wrport4_v = dram_v1 && !dram_aRtz1 && NDATA_PORTS > 1;
always_comb wrport5_v = (fpu1_sc_done|fpu1_done1) && !fpu1_aRtz && NFPU > 1;
always_comb wt0 = (alu0_sc_done|alu0_done) && !alu0_aRtz2 && alu0_cap;
always_comb wt2 = dram_v0 && !dram_aRtz0;
always_comb wt3 = fpu0_done && !fpu0_aRtz && !fpu0_idle && NFPU > 0;
always_comb wt4 = dram_v1 && !dram_aRtz1 && NDATA_PORTS > 1;
assign wrport0_Rt = alu0_Rt2;
assign wrport0_aRt = alu0_aRt2;
assign wrport1_Rt = NALU > 1 ? alu1_Rt2 : 9'd0;
assign wrport1_aRt = NALU > 1 ? alu1_aRt2 : 7'd0;
assign wrport2_Rt = dram_Rt0;
assign wrport2_aRt = dram_aRt0;
assign wrport3_Rt = NFPU > 0 ? fpu0_Rt3 : 9'd0;
assign wrport3_aRt = NFPU > 0 ? fpu0_aRt3 : 7'd0;
assign wrport4_Rt = NDATA_PORTS > 1 ? dram_Rt1 : 9'd0;
assign wrport4_aRt = NDATA_PORTS > 1 ? dram_aRt1 : 7'd0;
assign wrport5_Rt = NFPU > 1 ? fpu1_Rt : 9'd0;
assign wrport5_aRt = NFPU > 1 ? fpu1_aRt : 7'd0;
assign wrport0_res = alu0_res;
assign wrport1_res = NALU > 1 ? alu1_res : value_zero;
assign wrport2_res = dram_bus0;
assign wrport3_res = NFPU > 0 ? fpu0_res : value_zero;
assign wrport4_res = NDATA_PORTS > 1 ? dram_bus1 : value_zero;
assign wrport5_res = NFPU > 1 ? fpu1_res : value_zero;
assign wrport0_cp = alu0_cp2;
assign wrport1_cp = alu1_cp2;
assign wrport2_cp = dram0_cp;
assign wrport3_cp = fpu0_cp2;

Qupls_regfile6wNr #(.RPORTS(24)) urf1 (
	.rst(irst),
	.clk(clk), 
//	.clk5x(clk5x),
//	.ph4(ph4),
	.wr0(wrport0_v),
	.wr1(wrport1_v),
	.wr2(wrport2_v),
	.wr3(wrport3_v),
	.wr4(wrport4_v),
	.wr5(wrport5_v),
	.we0(1'b1),
	.we1(1'b1),
	.we2(1'b1),
	.we3(1'b1),
	.we4(1'b1),
	.we5(1'b1),
	.wt0(wt0),
	.wt1(1'b0),
	.wt2(wt2),
	.wt3(wt3),
	.wt4(wt4),
	.wt5(1'b0),
	.wa0(wrport0_Rt),
	.wa1(wrport1_Rt),
	.wa2(wrport2_Rt),
	.wa3(wrport3_Rt),
	.wa4(wrport4_Rt),
	.wa5(wrport5_Rt),
	.i0(wrport0_res),
	.i1(wrport1_res),
	.i2(wrport2_res),
	.i3(wrport3_res),
	.i4(wrport4_res),
	.i5(wrport5_res),
	.ti0(alu0_ctag),
	.ti1(1'b0),
	.ti2(dram0_cload ? dram_ctag0 : 1'b0),
	.ti3(fpu0_ctag),
	.ti4(dram1_cload ? dram_ctag1 : 1'b0),
	.ti5(1'b0),
	.ra(rf_reg),
	.o(rfo),
	.to(rfo_ctag)
);

always_ff @(posedge clk)
begin
	$display("wr0:%d Rt=%d/%d res=%x sc_done=%d Rtz2=%d", wrport0_v, wrport0_aRt, wrport0_Rt, wrport0_res, alu0_sc_done2, alu0_aRtz2);
	$display("wr1:%d Rt=%d/%d res=%x sc_done=%d Rtz2=%d", wrport1_v, wrport1_aRt, wrport1_Rt, wrport1_res, alu1_sc_done2, alu1_aRtz2);
	$display("wr2:%d Rt=%d/%d res=%x", wrport2_v, wrport2_aRt, wrport2_Rt, wrport2_res);
	$display("wr3:%d Rt=%d/%d res=%x", wrport3_v, wrport3_aRt, wrport3_Rt, wrport3_res);
end


// Copy-targets for when backout is not supported.
// additional logic for handling a branch miss (STOMP logic)
//
always_ff @(posedge clk)
begin
	unavail_list = {PREGS{1'b0}};
for (n4 = 0; n4 < ROB_ENTRIES; n4 = n4 + 1) begin
	robentry_cpytgt[n4] = FALSE;
	if (!SUPPORT_BACKOUT)
		robentry_cpytgt[n4] = robentry_stomp[n4];

	if (SUPPORT_BACKOUT) begin
		if (fcu_idv && ((rob[fcu_id].decbus.br && takb) || rob[fcu_id].decbus.cjb)) begin
	 		if (rob[n4].grp==rob[fcu_id].grp && rob[n4].sn > rob[fcu_id].sn) begin
				robentry_cpytgt[n4] = TRUE;
				unavail_list[rob[n4].op.nRt] = TRUE;
	 		end
		end
	end

	if (!SUPPORT_BACKOUT) begin
		if (fcu_idv && ((rob[fcu_id].decbus.br && takb))) begin
	 		if (rob[n4].grp==rob[fcu_id].grp && rob[n4].sn > rob[fcu_id].sn) begin
				robentry_cpytgt[n4] = TRUE;
	 		end
		end
		if (fcu_idv && rob[fcu_id].decbus.br && !takb) begin
	 		if (rob[n4].grp==rob[fcu_id].grp && rob[n4].sn > rob[fcu_id].sn) begin
				robentry_cpytgt[n4] = FALSE;
	 		end
		end
	end
end
end

// Calc the location of the ROB tail pointer after a stomp.
Qupls_stail ustail1
(
	.head0(head0),
	.tail0(tail0),
	.robentry_stomp(robentry_stomp),
	.rob(rob),
	.stail(stail)
);

pc_address_t tpc;
always_comb
	tpc = fcu_pc + 4'd8;

modFcuMissPC umisspc1
(
	.instr(fcu_instr),
	.bts(fcu_bts),
	.micro_ip(micro_ip),
	.pc(fcu_pc),
	.pc_stack(pc_stack),
	.bt(fcu_bt),
	.takb(takb),
	.argA(fcu_argA),
	.argB(fcu_argB),
	.argI(fcu_argI),
	.ibh(ibh_t'(ic_line[511:480])),
	.misspc(fcu_misspc1),
	.missgrp(fcu_missgrp),
	.miss_mcip(fcu_miss_mcip1),
	.tgtpc(tgtpc),
	.stomp_bno(stomp_bno)
);

always_comb
	fcu_missir <= fcu_instr;


Qupls_branch_eval ube1
(
	.instr(fcu_instr.ins),
	.a(fcu_argA),
	.b(fcu_argBr),
	.takb(takb)
);

wire cd_fcu_id;
reg takbr1;
reg takbr;
always_ff @(posedge clk) takbr1 <= takb;
always_ff @(posedge clk) if (fcu_new) takbr <= takb;

always_comb
begin
	fcu_exc = FLT_NONE;
	// ToDo: fix check
	if (fcu_instr.ins.any.opcode==OP_CHK) begin
		fcu_exc = cause_code_t'(fcu_instr.ins[34:27]);
		fcu_exc = FLT_NONE;
	end
end

reg branchmiss_det;
always_comb
	branchmiss_det = ((takb && !fcu_bt) || (!takb && fcu_bt));

// Branchmiss flag

Qupls_branchmiss_flag ubmf1
(
	.rst(irst),
	.clk(clk),
	.bts(fcu_bts),
	.trig(fcu_v2),
	.miss_det(branchmiss_det),
	.miss_flag(fcu_branchmiss)
);

// Backout flag
// If taking a branch, any following register mappings in the same group need
// to be backed out. This is regardless of whether a prediction was true or not.
// If there is a branch incorrectly predicted as taken, then the register
// mappings also need to be backed out.

always_ff @(posedge clk)
if (irst)
	backout <= FALSE;
else begin
	backout <= FALSE;
	if (fcu_v2) begin
		case(fcu_bts)
		BTS_REG,BTS_DISP:
			// backout when !fcu_bt will be handled below, triggerred by restore
			if (takb && fcu_bt)
				backout <= TRUE;
		BTS_CALL,BTS_RET:
			backout <= TRUE;
		default:
			;		
		endcase
	end
end

// Restore flag.
// A restore will trigger a backout.
// Almost the same as backout except a restore is not needed for correctly
// predicated branches.

always_ff @(posedge clk)
if (irst)
	restore <= FALSE;
else begin
	restore <= FALSE;
	if (fcu_v2) begin
		case(fcu_bts)
		BTS_REG,BTS_DISP:
			if (branchmiss_det)
				restore <= TRUE;
		default:
			;		
		endcase
	end
end

Qupls_checkpoint_freer uchkptfree1
(
	.rst(irst),
	.clk(clk),
	.rob(rob),
	.free(free_chkpt),
	.chkpt(fchkpt),
	.chkpt_rndx(chkpt_rndx)
);

// Registering the branch miss signals may allow a second miss directly after
// the first one to occur. We want to process only the first miss. Three in
// a row cannot happen as the stomp signal is active by then.

reg brtgtvr;
always_comb
	branchmiss_next = (excmiss | fcu_branchmiss);// & ~branchmiss;
always_comb//ff @(posedge clk)
if (irst)
	branchmiss <= FALSE;
else begin
//	if (advance_pipeline)
		branchmiss = branchmiss_next;
end
always_ff @(posedge clk)
if (irst)
	branchmiss_h <= FALSE;
else begin
//	if (advance_pipeline)
	branchmiss_h <= branchmiss_next | branchmiss_h;
	if (advance_pipeline)
		branchmiss_h <= FALSE;
end
always_comb//ff @(posedge clk)
if (irst)
	missid <= 5'd0;
else begin
//	if (advance_pipeline)
		missid <= excmiss ? excid : fcu_id;
end
/*
always_ff @(posedge clk)
	if (branch_state==BS_CHKPT_RESTORE) begin
		for (n24 = 0; n24 < ROB_ENTRIES; n24 = n24 + 1)
			missidb[n24] = (excmiss ? excid : fcu_id)==n24;
	end
*/
always_ff @(posedge clk)
if (irst) begin
	fcu_misspc.bno_t <= 6'd1;
	fcu_misspc.bno_f <= 6'd1;
	fcu_misspc.pc <= next_pc.pc;
end
else begin
	if (do_bsr)
		fcu_misspc <= bsr_tgt;
	else// if (fcu_v6)
		fcu_misspc <= fcu_misspc1;
end		
always_ff @(posedge clk)
if (irst)
	fcu_miss_mcip <= 12'h1A0;
else begin
	if (fcu_v6)
		fcu_miss_mcip <= fcu_miss_mcip1;
end
always_ff @(posedge clk)
if (irst) begin
	misspc.bno_t <= 6'd1;
	misspc.bno_f <= 6'd1;
	misspc.pc <= RSTPC;
end
else begin
//	if (advance_pipeline)
	if (branch_state==BS_CAPTURE_MISSPC)
		misspc = excmiss ? excmisspc : fcu_misspc;
//		misspc <= excmiss ? {dram0_bus[$bits(pc_address_t)-1:8],8'h00} : brtgtvr ? brtgt : fcu_misspc;
end
always_ff @(posedge clk)
if (irst)
	miss_mcip <= 12'h1A0;
else begin
//	if (advance_pipeline)
	if (branch_state==BS_CAPTURE_MISSPC)
		miss_mcip <= excmiss ? excmiss_mcip : fcu_miss_mcip;
end
always_ff @(posedge clk)
if (irst)
	missgrp <= 4'd0;
else begin
//	if (advance_pipeline)
	if (branch_state==BS_CHKPT_RESTORE)
		missgrp <= excmiss ? excmissgrp : fcu_missgrp;
end
always_ff @(posedge clk)
if (irst)
	missir <= {57'd0,OP_NOP};
else begin
//	if (advance_pipeline)
	if (branch_state==BS_CHKPT_RESTORE)
		missir <= excmiss ? excir : fcu_missir;
end

wire s4s7 = (pc.pc==misspc.pc && ihito && brtgtvr) ||
	(robentry_stomp[fcu_id] || (rob[fcu_id].out[1] && !rob[fcu_id].v))
	;
wire s5s7 = (next_pc.pc==misspc.pc && ihit && (rob[fcu_id].done==2'b11 || fcu_idle)) ||
//wire s5s7 = (next_pc==misspc && get_next_pc && ihito && (rob[fcu_id].done==2'b11 || fcu_idle)) ||
	(robentry_stomp[fcu_id] || 
	(!rob[fcu_id].v))
//	(rob[fcu_id].out[1] && !rob[fcu_id].v))
	;

always_ff @(posedge clk)
if (irst)
	branch_state <= BS_IDLE;
else begin
//		if (fcu_rndxv && fcu_idle && branch_state==BS_IDLE)
//			branch_state <= 3'd0;
	if (TRUE) begin
		case(branch_state)
		BS_IDLE:
			if (branchmiss)
				branch_state <= BS_CHKPT_RESTORE;
		BS_CHKPT_RESTORE:
			branch_state <= BS_CHKPT_RESTORED;
		BS_CHKPT_RESTORED:
		// if (restored)
			branch_state <= BS_STATE3;
		BS_STATE3:
			branch_state <= BS_CAPTURE_MISSPC;
		BS_CAPTURE_MISSPC:
//			if (s4s7)
//				branch_state <= BS_DONE2;
//			else
				branch_state <= BS_DONE;
		BS_DONE:
			if (s5s7)
				branch_state <= BS_DONE2;
		BS_DONE2:
			branch_state <= BS_IDLE;
		default:
			branch_state <= BS_IDLE;
		endcase
	end
end

always_ff @(posedge clk)
if (irst)
	bs_idle_oh <= TRUE;
else begin
	case(branch_state)
	BS_IDLE:
		if (branchmiss)
			bs_idle_oh <= FALSE;
	BS_DONE2:
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
	BS_CAPTURE_MISSPC:
		bs_done_oh <= TRUE;
	BS_DONE:
		if (s5s7)
			bs_done_oh <= FALSE;
	default:	;
	endcase
end


// ----------------------------------------------------------------------------
// ISSUE stage combo logic
// ----------------------------------------------------------------------------

rob_ndx_t alu0_rndx;
rob_ndx_t alu1_rndx;
rob_ndx_t fpu0_rndx; 
rob_ndx_t fpu1_rndx; 
lsq_ndx_t mem0_lsndx, mem1_lsndx;
beb_ndx_t beb_ndx;
wire mem0_lsndxv, mem1_lsndxv;
wire fpu0_rndxv, fpu1_rndxv, fcu_rndxv;
wire alu0_rndxv, alu1_rndxv;
wire agen0_rndxv, agen1_rndxv;
rob_bitmask_t rob_memissue;
wire [3:0] beb_issue;
lsq_ndx_t lsq_head;
wire ratv0_rndxv;
wire ratv1_rndxv;
wire ratv2_rndxv;
wire ratv3_rndxv;
rob_ndx_t ratv0_rndx;
rob_ndx_t ratv1_rndx;
rob_ndx_t ratv2_rndx;
rob_ndx_t ratv3_rndx;

Qupls_sched uscd1
(
	.rst(irst),
	.clk(clk),
	.alu0_idle(alu0_idle),
	.alu1_idle(NALU > 1 ? alu1_idle : 1'd0),
	.fpu0_idle(NFPU > 0 ? !fpu0_iq_prog_full : 1'd0),
	.fpu1_idle(NFPU > 1 ? fpu1_idle : 1'd0),
	.fcu_idle(fcu_idle),
	.agen0_idle(agen0_idle1),
	.agen1_idle(1'b0),
	.lsq0_idle(lsq0_idle),
	.lsq1_idle(lsq1_idle),
	.stomp_i(robentry_stomp),
	.robentry_islot_i(robentry_islot),
	.robentry_islot_o(robentry_islot),
	.head(head0),
	.rob(rob),
	.robentry_issue(robentry_issue),
	.robentry_fpu_issue(robentry_fpu_issue),
	.robentry_fcu_issue(robentry_fcu_issue),
	.robentry_agen_issue(robentry_agen_issue),
	.alu0_rndx(alu0_rndx),
	.alu1_rndx(alu1_rndx),
	.alu0_rndxv(alu0_rndxv),
	.alu1_rndxv(alu1_rndxv),
	.fpu0_rndx(fpu0_rndx),
	.fpu0_rndxv(fpu0_rndxv),
	.fpu1_rndx(),
	.fpu1_rndxv(),
	.fcu_rndx(fcu_rndx),
	.fcu_rndxv(fcu_rndxv),
	.agen0_rndx(agen0_rndx),
	.agen1_rndx(agen1_rndx),
	.agen0_rndxv(agen0_rndxv),
	.agen1_rndxv(agen1_rndxv),
	.ratv0_rndx(ratv0_rndx),
	.ratv1_rndx(ratv1_rndx),
	.ratv2_rndx(ratv2_rndx),
	.ratv3_rndx(ratv3_rndx),
	.ratv0_rndxv(ratv0_rndxv),
	.ratv1_rndxv(ratv1_rndxv),
	.ratv2_rndxv(ratv2_rndxv),
	.ratv3_rndxv(ratv3_rndxv),
	.cpytgt0(alu0_cpytgt),
	.cpytgt1(alu1_cpytgt),
	.beb_buf(beb_buf),
	.beb_issue(beb_issue)
);

rob_bitmask_t cpu_request_cancel;

Qupls_mem_sched umems1
(
	.rst(irst),
	.clk(clk),
	.head(head0),
	.lsq_head(lsq_head),
	.cancel(cpu_request_cancel),
	.robentry_stomp(robentry_stomp),
	.rob(rob),
	.lsq(lsq),
	.islot_i(lsq_islot),
	.islot_o(lsq_islot),
	.memissue(rob_memissue),
	.ndx0(mem0_lsndx),
	.ndx1(mem1_lsndx),
	.ndx0v(mem0_lsndxv),
	.ndx1v(mem1_lsndxv)
);

assign alu0_argA_reg = rob[alu0_rndx].op.pRa;
assign alu0_argB_reg = rob[alu0_rndx].op.pRb;
assign alu0_argC_reg = rob[alu0_rndx].op.pRc;
assign alu0_argM_reg = rob[alu0_rndx].op.pRm;

assign alu1_argA_reg = rob[alu1_rndx].op.pRa;
assign alu1_argB_reg = rob[alu1_rndx].op.pRb;
assign alu1_argC_reg = rob[alu1_rndx].op.pRc;
assign alu1_argM_reg = rob[alu1_rndx].op.pRm;

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

assign alu0_argT_reg = rob[alu0_rndx].op.pRt;
assign alu1_argT_reg = rob[alu1_rndx].op.pRt;
assign fpu0_argT_reg = rob[fpu0_rndx].op.pRt;

// ----------------------------------------------------------------------------
// EXECUTE stage combo logic
// ----------------------------------------------------------------------------

value_t csr_res;
wire div_dbz;

always_comb
	tReadCSR(csr_res,alu0_argI[15:0]);

Qupls_meta_alu #(.ALU0(1'b1)) ualu0
(
	.rst(irst),
	.clk(clk),
	.clk2x(clk2x_i),
	.ld(alu0_ld),
	.prc(alu0_prc),
	.ir(alu0_instr.ins),
	.div(alu0_div),
	.cptgt(alu0_cptgt),
	.z(alu0_predz),
	.a(alu0_argA),
	.b(alu0_argB),
	.bi(alu0_argBI),
	.c(alu0_argC),
	.i(alu0_argI),
	.t(alu0_argT),
	.cs(alu0_cs),
	.pc(alu0_pc),
	.csr(csr_res),
	.canary(canary),
	.cpl(sr.pl),
	.qres(fpu0_resH),
	.o(alu0_res),
	.mul_done(mul0_done),
	.div_done(div0_done),
	.div_dbz(div_dbz),
	.exc(alu0_exc)
);

generate begin : gAlu1
if (NALU > 1) begin
	Qupls_meta_alu #(.ALU0(1'b0)) ualu1
	(
		.rst(irst),
		.clk(clk),
		.clk2x(clk2x_i),
		.ld(alu1_ld),
		.prc(alu1_prc),
		.ir(alu1_instr.ins),
		.div(alu1_div),
		.cptgt(alu1_cptgt),
		.z(alu1_predz),
		.a(alu1_argA),
		.b(alu1_argB),
		.bi(alu1_argBI),
		.c(alu1_argC),
		.i(alu1_argI),
		.t(alu1_argT),
		.cs(alu1_cs),
		.pc(alu1_pc),
		.csr(14'd0),
		.canary(canary),
		.cpl(sr.pl),
		.qres(64'd0),
		.o(alu1_res),
		.mul_done(mul1_done),
		.div_done(),
		.div_dbz(),
		.exc(alu1_exc)
	);
end
/*
if (VALU) begin
	for (g = 0; g < 8; g = g + 1)
		Qupls_alu #(.ALU0(1'b0)) ualuv1
		(
			.rst(irst),
			.clk(clk),
			.clk2x(clk2x_i),
			.ld(valu_ld),
			.ir(valu_instr),
			.div(valu_div),
			.cptgt(valu_cptgt),
			.z(valu_predz),
			.a(valu_argA[g]),
			.b(valu_argB[g]),
			.bi(valu_argBI),
			.c(valu1_argC[g]),
			.i(valu_argI),
			.t(64'd0),
			.qres(64'd0),
			.cs(alu1_cs),
			.pc(alu1_pc),
			.csr(14'd0),
			.o(valu_res[g]),
			.mul_done(vmul_done[g]),
			.div_done(),
			.div_dbz()
		);
end
*/
end
endgenerate

//assign alu0_out = alu0_dataready;
//assign alu1_out = alu1_dataready;

//assign  fcu_v = fcu_dataready;

// ToDo: add result exception 
generate begin : gFpu
if (NFPU > 0) begin
	if (SUPPORT_QUAD_PRECISION|SUPPORT_CAPABILITIES) begin
		Qupls_meta_fpu #(.WID(128)) ufpu1
		(
			.rst(irst),
			.clk(clk),
			.clk3x(clk3x),
			.idle(fpu0_idle),
			.ir(fpu0_instr.ins),
			.rm(3'd0),
			.a({alu0_argA,fpu0_argA}),
			.b({alu0_argB,fpu0_argB}),
			.c({alu0_argC,fpu0_argC}),
			.i(fpu0_argI),
			.o({fpu0_resH,fpu0_res}),
			.p(~64'd0),
			.t({alu0_argT,fpu0_argT}),
			.z(fpu0_predz),
			.cptgt(fpu0_cptgt),
			.atag(fpu0_argA_tag),
			.btag(fpu0_argB_tag),
			.otag(alu0_ctag),
			.done(fpu0_done),
			.exc(fpu0_exc)
		);
	end
	else begin
		Qupls_meta_fpu #(.WID(64)) ufpu1
		(
			.rst(irst),
			.clk(clk),
			.clk3x(clk3x),
			.idle(fpu0_idle),
			.ir(fpu0_instr.ins),
			.rm(3'd0),
			.a(fpu0_argA),
			.b(fpu0_argB),
			.c(fpu0_argC),
			.i(fpu0_argI),
			.z(1'b0),
			.cptgt(fpu0_cptgt),
			.atag(1'b0),
			.btag(1'b0),
			.o(fpu0_res),
			.otag(),
			.p(~64'd0),
			.t(64'd0),
			.done(fpu0_done),
			.exc(fpu0_exc)
		);
	end
end
if (NFPU > 1) begin
	Qupls_meta_fpu #(.WID(64)) ufpu2
	(
		.rst(irst),
		.clk(clk),
		.clk3x(clk3x),
		.idle(fpu1_idle),
		.ir(fpu1_instr.ins),
		.rm(3'd0),
		.a(fpu1_argA),
		.b(fpu1_argB),
		.c(fpu1_argC),
		.i(fpu1_argI),
		.z(1'b0),
		.cptgt(fpu1_cptgt),
		.atag(1'b0),
		.btag(1'b0),
		.o(fpu1_res),
		.otag(),
		.p(~64'd0),
		.t(64'd0),
		.done(fpu1_done),
		.exc(fpu1_exc)
	);
end
end
endgenerate

// ----------------------------------------------------------------------------
// MEMORY stage
// ----------------------------------------------------------------------------

wire agen0_v, agen1_v;

wire tlb_miss;
virtual_address_t tlb_missadr;
asid_t tlb_missasid;
rob_ndx_t tlb_missid;
ex_instruction_t tlb0_op, tlb1_op;
wire [1:0] tlb_missqn;
wire [31:0] pg_fault;
wire [1:0] pg_faultq;
virtual_address_t ptw_vadr;
physical_address_t ptw_padr;
wire ptw_vv;
wire ptw_pv;

lsq_ndx_t lsq_tail, lsq_tail0;
lsq_ndx_t lsq_heads [0:LSQ_ENTRIES];

lsq_ndx_t lbndx0, lbndx1;

reg dram0_timeout;
reg dram1_timeout;

wire [NDATA_PORTS-1:0] dcache_load;
wire [NDATA_PORTS-1:0] dhit2;
reg [NDATA_PORTS-1:0] dhit;
wire [NDATA_PORTS-1:0] modified;
wire [1:0] uway [0:NDATA_PORTS-1];
fta_cmd_request512_t [NDATA_PORTS-1:0] cpu_request_i;
fta_cmd_request512_t [NDATA_PORTS-1:0] cpu_request_i2;
fta_cmd_response512_t [NDATA_PORTS-1:0] cpu_resp_o;
fta_cmd_response512_t [NDATA_PORTS-1:0] update_data_i;
rob_ndx_t [NDATA_PORTS-1:0] cpu_request_rndx;

wire [NDATA_PORTS-1:0] dump;
wire DCacheLine dump_o[0:NDATA_PORTS-1];
wire [NDATA_PORTS-1:0] dump_ack;
wire [NDATA_PORTS-1:0] dwr;
wire [1:0] dway [0:NDATA_PORTS-1];

always_comb
if (SUPPORT_CAPABILITIES) begin
	dhit[0] = dhit2[0] & cap_tag_hit[0];
	dhit[1] = dhit2[1] & cap_tag_hit[1];
end
else begin
	dhit[0] = dhit2[0];
	dhit[1] = dhit2[1];
end

generate begin : gDcache
for (g = 0; g < NDATA_PORTS; g = g + 1) begin

	always_comb
	begin
//		cpu_request_i[g].cid = g + 1;
		cpu_request_rndx[g] = dramN_id[g];
		cpu_request_i[g].tid = dramN_tid[g];
		cpu_request_i[g].om = fta_bus_pkg::MACHINE;
		cpu_request_i[g].cmd = dramN_store[g] ? fta_bus_pkg::CMD_STORE : dramN_loadz[g] ? fta_bus_pkg::CMD_LOADZ :
			dramN_load[g]|dramN_cload[g]|dramN_cload_tags ? fta_bus_pkg::CMD_LOAD : fta_bus_pkg::CMD_NONE;
		cpu_request_i[g].bte = fta_bus_pkg::LINEAR;
		cpu_request_i[g].cti = (dramN_erc[g] || ERC) ? fta_bus_pkg::ERC : fta_bus_pkg::CLASSIC;
		cpu_request_i[g].blen = 6'd0;
		cpu_request_i[g].seg = fta_bus_pkg::DATA;
		cpu_request_i[g].asid = asid;
		cpu_request_i[g].cyc = dramN[g]==DRAMSLOT_READY;
		cpu_request_i[g].stb = dramN[g]==DRAMSLOT_READY;
		cpu_request_i[g].we = dramN_store[g];
		cpu_request_i[g].vadr = dramN_vaddr[g];
		cpu_request_i[g].padr = dramN_paddr[g];
		cpu_request_i[g].sz = fta_bus_pkg::fta_size_t'(dramN_memsz[g]);
		cpu_request_i[g].dat = dramN_data[g];
		cpu_request_i[g].sel = dramN_sel[g];
		cpu_request_i[g].pl = 8'h00;
		cpu_request_i[g].pri = 4'd7;
		if (dramN_load[g]|dramN_cload[g]|dramN_cload_tags) begin
			cpu_request_i[g].cache = fta_bus_pkg::WT_READ_ALLOCATE;
			dramN_ack[g] = cpu_resp_o[g].ack & ~cpu_resp_o[g].rty;
		end
		else begin
			cpu_request_i[g].cache = fta_bus_pkg::WT_NO_ALLOCATE;
			dramN_ack[g] = cpu_resp_o[g].ack;
		end
	end

	Qupls_dcache
	#(.CORENO(CORENO), .CID(g+1))
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

	Qupls_dcache_ctrl
	#(.CORENO(CORENO), .CID(g+1))
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
		.cpu_request_i2(cpu_request_i2[g]),
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

	cap_tag_cache ucapcache1
	(
		.rst(irst),
		.clk(clk),
		.wr(dramN_store[g]),
		.wr_cap(dramN_cstore[g]),
		.adr(dramN_paddr[g]),
		.hit(cap_tag_hit[g]),
		.tagi(dramN_ctago[g]),
		.tago(dramN_ctagi[g]),
		.tagso(dramN_tagsi[g]),
		.req(cap_tag_req[g]),
		.resp(cap_tag_resp[g])
	);

end
end
endgenerate

always_comb
begin
	dramN[0] = dram0;
	dramN_id[0] = dram0_id;
	dramN_paddr[0] = dram0_paddr;
	dramN_vaddr[0] = dram0_vaddr;
	dramN_data[0] = dram0_data[511:0];
	dramN_ctago[0] = dram0_ctago;
	dramN_sel[0] = dram0_sel[63:0];
	dramN_store[0] = dram0_store;
	dramN_cstore[0] = dram0_cstore;
	dramN_erc[0] = dram0_erc;
	dramN_load[0] = dram0_load;
	dramN_loadz[0] = dram0_loadz;
	dramN_cload[0] = dram0_cload;
	dramN_cload_tags[0] = dram0_cload_tags;
	dramN_memsz[0] = dram0_memsz;
	dramN_tid[0] = dram0_tid;
	dram0_ack = dramN_ack[0];
	dram0_ctag = dramN_ctago[0];

	if (NDATA_PORTS > 1) begin
		dramN[1] = dram1;
		dramN_id[1] = dram1_id;
		dramN_vaddr[1] = dram1_vaddr;
		dramN_paddr[1] = dram1_paddr;
		dramN_data[1] = dram1_data[511:0];
		dramN_ctago[1] = dram1_ctag;
		dramN_sel[1] = dram1_sel[63:0];
		dramN_store[1] = dram1_store;
		dramN_cstore[1] = dram1_cstore;
		dramN_erc[1] = dram1_erc;
		dramN_load[1] = dram1_load;
		dramN_loadz[1] = dram1_loadz;
		dramN_cload[1] = dram1_cload;
		dramN_cload_tags[1] = dram1_cload_tags;
		dramN_memsz[1] = dram1_memsz;
		dramN_tid[1] = dram1_tid;
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
	agen0_load <= rob[agen0_rndx].decbus.load;
always_ff @(posedge clk)
	agen1_load <= rob[agen1_rndx].decbus.load;
always_ff @(posedge clk)
	agen0_store <= rob[agen0_rndx].decbus.store;
always_ff @(posedge clk)
	agen1_store <= rob[agen1_rndx].decbus.store;

Qupls_agen uag0
(
	.rst(irst),
	.clk(clk),
	.next(1'b0),
	.out(rob[agen0_id].out[0]),
	.tlb_v(tlb0_v),
	.ir(agen0_op.ins),
	.Ra(agen0_aRa),
	.Rb(agen0_aRb),
	.pc(agen0_pc),
	.a(agen0_argA),
	.b(agen0_argB),
	.i(agen0_argI),
	.res(agen0_res),
	.resv(agen0_v)
);

Qupls_agen uag1
(
	.rst(irst),
	.clk(clk),
	.next(1'b0),
	.out(rob[agen1_id].out[0]),
	.tlb_v(tlb1_v),
	.ir(agen1_op.ins),
	.Ra(agen1_aRa),
	.Rb(agen1_aRb),
	.pc(agen1_pc),
	.a(agen1_argA),
	.b(agen1_argB),
	.i(agen1_argI),
	.res(agen1_res),
	.resv(agen1_v)
);

reg cantlsq0, cantlsq1;
always_comb
begin
	cantlsq0 = 1'b0;
	cantlsq1 = 1'b0;
	for (n11 = 0; n11 < ROB_ENTRIES; n11 = n11 + 1) begin
		if (rob[n11].decbus.mem && rob[n11].sn < rob[agen0_id].sn && !rob[n11].lsq)
			cantlsq0 = 1'b1;
		if (rob[n11].decbus.mem && rob[n11].sn < rob[agen1_id].sn && !rob[n11].lsq)
			cantlsq1 = 1'b1;
	end
end

mmu #(.CID(3)) ummu1
(
	.rst(irst),
	.clk(clk), 
	.paging_en(1'b0),
	.tlb_pmt_base(32'hFFF80000),
	.ic_miss_adr(ic_miss_adr),
	.ic_miss_asid(ic_miss_asid),
	.vadr_ir(agen0_op.ins),
	.vadr(agen0_res),
	.vadr_v(agen0_v),
	.vadr_asid(asid),
	.vadr_id(agen0_id),
	.vadr2_ir(agen1_op.ins),
	.vadr2(agen1_res),
	.vadr2_v(agen1_v),
	.vadr2_asid(asid),
	.vadr2_id(agen1_id),
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
	.ftas_req(ftadm_req),
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
	for (n2 = 1; n2 < LSQ_ENTRIES; n2 = n2 + 1) begin
		lsq_heads[n2].row = (lsq_heads[n2-1].row+1) % LSQ_ENTRIES;
		lsq_heads[n2].col = 0;
	end
end

// Stores are done as soon as they issue.
// Loads are done when there is an ack back from the memory system.
always_ff @(posedge clk)
if (irst)
	dram0_done <= FALSE;
else begin
	dram0_done <= FALSE;
	if (!(dram0_store|dram0_cstore|dram0_load|dram0_cload) && dram0_idv)
		dram0_done <= TRUE;
	else if ((dram0_store|dram0_cstore) ? !robentry_stomp[dram0_id] && dram0_idv :
		(dram0 == DRAMSLOT_ACTIVE && dram0_ack &&
			(dram0_hi ? ((dram0_load|dram0_cload) & ~dram0_stomp) :
			((dram0_load|dram0_cload|dram0_cload_tags) & ~dram0_more & ~dram0_stomp)))
		)
		dram0_done <= TRUE;
end

always_ff @(posedge clk)
if (irst)
	dram1_done <= FALSE;
else begin
	dram1_done <= FALSE;
	if (NDATA_PORTS > 1) begin
		if (!(dram1_store|dram1_cstore|dram1_load|dram1_cload))
			dram1_done <= TRUE;
		else if (dram1_store ? !robentry_stomp[dram1_id] && dram1_idv :
			(dram1 == DRAMSLOT_ACTIVE && dram1_ack &&
				(dram1_hi ? ((dram1_load|dram1_cload) & ~dram1_stomp) : ((dram1_load|dram1_cload|dram1_cload_tags) & ~dram1_more & ~dram1_stomp)))
			)
			dram1_done <= TRUE;
	end
end

function lsq_ndx_t fnLoadBypassIndex;
input lsq_ndx_t lsndx;
integer n15r,n15c;
seqnum_t stsn;
begin
	fnLoadBypassIndex = -1;
	stsn = 8'hFF;
	for (n15r = 0; n15r < LSQ_ENTRIES; n15r = n15r + 1) begin
		for (n15c = 0; n15c < 2; n15c = n15c + 1) begin
		if (
			(lsq[lsndx.row][lsndx.col].memsz==lsq[n15r][n15c].memsz) &&		// memory size matches
			(lsq[lsndx.row][lsndx.col].load && lsq[n15r][n15c].store) &&	// and trying to load
			 lsq[lsndx.row][lsndx.col].sn > lsq[n15r][n15c].sn && lsq[n15r][n15c].v && lsq[n15r][n15c].datav &&
			 	stsn > lsq[n15r][n15c].sn) begin
			 	stsn = lsq[n15r][n15c].sn;
			 	fnLoadBypassIndex.row = n15r;
			 	fnLoadBypassIndex.col = n15c;
			end
		end
	end
end
endfunction

always_comb	lbndx0 = fnLoadBypassIndex(mem0_lsndx);
always_comb lbndx1 = fnLoadBypassIndex(mem1_lsndx);

reg dram0_setready;
always_comb
begin
	dram0_setready = FALSE;
	if (SUPPORT_LOAD_BYPASSING && lbndx0 > 0)
		;
	else if (dram0 == DRAMSLOT_AVAIL && mem0_lsndxv && dram0_idv)
		dram0_setready = TRUE;
end

reg dram1_setready;
always_comb
begin
	dram1_setready = FALSE;
	if (NDATA_PORTS > 1) begin
		if (SUPPORT_LOAD_BYPASSING && lbndx1 > 0)
			;
		else if (dram1 == DRAMSLOT_AVAIL && mem1_lsndxv && dram1_idv)
			dram1_setready = TRUE;
	end
end

always_comb
begin
	dram0_timeout <= FALSE;
	if (SUPPORT_BUS_TO) begin
		if (dram0_tocnt[10])
			dram0_timeout = TRUE;
		else if (dram0_tocnt[8])
			dram0_timeout = TRUE;
	end
end

always_comb
begin
	dram1_timeout <= FALSE;
	if (SUPPORT_BUS_TO && NDATA_PORTS > 1) begin
		if (dram1_tocnt[10])
			dram1_timeout = TRUE;
		else if (dram1_tocnt[8])
			dram1_timeout = TRUE;
	end
end

Qupls_mem_state udrst0
(
	.rst_i(irst),
	.clk_i(clk),
	.ack_i(dram0_ack),
	.set_ready_i(dram0_setready),
	.set_avail_i(dram0_timeout|dram0_stomp),
	.state_o(dram0)
);

Qupls_mem_state udrst1
(
	.rst_i(irst),
	.clk_i(clk),
	.ack_i(dram1_ack),
	.set_ready_i(dram1_setready),
	.set_avail_i(dram1_timeout|dram1_stomp),
	.state_o(dram1)
);

Qupls_mem_more ummore0
(
	.rst_i(irst),
	.clk_i(clk),
	.state_i(dram0),
	.sel_i(dram0_sel),
	.more_o(dram0_more)
);

Qupls_mem_more ummore1
(
	.rst_i(irst),
	.clk_i(clk),
	.state_i(dram1),
	.sel_i(dram1_sel),
	.more_o(dram1_more)
);

// -----------------------------------------------------------------------------
// Commit stage combo logic
// -----------------------------------------------------------------------------

// Figure out how many instructions can be committed.
// If there is an oddball instruction (eg. CSR, RTE) then only commit up until
// the oddball. Also, if there is an exception, commit only up until the 
// exception. Otherwise commit instructions that are not valid or are valid
// and done. Do not commit invalid instructions at the tail of the queue.

always_comb
	if (head0 > tail0)
		cmtlen = head0-tail0;
	else
		cmtlen = ROB_ENTRIES+head0-tail0;

/*
										(
											head0 == tail0 || head0 == tail1 || head0 == tail2 || head0 == tail3 ||
											head0 == tail4 || head0 == tail5 || head0 == tail6 || head0 == tail7);
*/
always_comb cmttlb0 = (rob[head0].v && rob[head0].lsq && !lsq[rob[head0].lsqndx.row][rob[head0].lsqndx.col].agen);
always_comb cmttlb1 = XWID > 1 && (rob[head1].v && rob[head1].lsq && !lsq[rob[head1].lsqndx.row][rob[head1].lsqndx.col].agen);
always_comb cmttlb2 = XWID > 2 && (rob[head2].v && rob[head2].lsq && !lsq[rob[head2].lsqndx.row][rob[head2].lsqndx.col].agen);
always_comb cmttlb3 = XWID > 3 && (rob[head3].v && rob[head3].lsq && !lsq[rob[head3].lsqndx.row][rob[head3].lsqndx.col].agen);

Qupls_commit_count
#(.XWID(XWID))
ucmtcnt1
(
	.rst(irst),
	.next_cqd(next_cqd),
	.rob(rob),
	.head0(head0),
	.head1(head1),
	.head2(head2),
	.head3(head3),
	.head4(head4),
	.head5(head5),
	.tail0(tail0),
	.tail1(tail1),
	.tail2(tail2),
	.tail3(tail3),
	.tail4(tail4),
	.tail5(tail5),
	.cmtcnt(cmtcnt),
	.do_commit(do_commit)
);

always_comb
cmtbr = (
	(rob[head0].decbus.br & rob[head0].v) ||
	(XWID > 1 && (rob[head1].decbus.br & rob[head1].v)) ||
	(XWID > 2 && (rob[head2].decbus.br & rob[head2].v)) ||
	(XWID > 3 && (rob[head3].decbus.br & rob[head3].v))) && do_commit
	;

always_comb
begin
	int_commit = 1'b0;
	if (rob[head0].v && &rob[head0].done && rob[head0].op.hwi_level > sr.ipl)//fnIsIrq(rob[head0].op.ins))
		int_commit = 1'b1;
	else if (((rob[head0].v && &rob[head0].done) || !rob[head0].v) &&
					(rob[head1].v && &rob[head1].done && rob[head1].op.hwi_level > sr.ipl /*fnIsIrq(rob[head1].op.ins*/))
		int_commit = XWID > 1;
	else if (((rob[head0].v && &rob[head0].done) || !rob[head0].v) &&
					 ((rob[head1].v && &rob[head1].done) || !rob[head1].v) &&
					(rob[head2].v && &rob[head2].done && rob[head2].op.hwi_level > sr.ipl /*fnIsIrq(rob[head2].op.ins*/))
		int_commit = XWID > 2;
	else if (((rob[head0].v && &rob[head0].done) || !rob[head0].v) &&
					 ((rob[head1].v && &rob[head1].done) || !rob[head1].v) &&
					 ((rob[head2].v && &rob[head2].done) || !rob[head2].v) &&
					(rob[head3].v && &rob[head3].done && rob[head3].op.hwi_level > sr.ipl /*fnIsIrq(rob[head3].op.ins*/))
		int_commit = XWID > 3;
end


// Stall for vector load.
wire pe_vec_stall;
edge_det edvs1 (
	.rst(irst),
	.clk(clk),
	.ce(advance_pipeline_seg2),
	.i(rob[head0].v && (rob[head0].decbus.rex || rob[head0].excv)),
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
	for (n30 = 0; n30 < ROB_ENTRIES; n30 = n30 + 1) begin
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

Qupls_alu_station ualust0
(
	.rst(irst),
	.clk(clk),
	.available(alu0_available),
	.idle(alu0_idle),
	.issue(robentry_issue[alu0_rndx]),
	.rndx(alu0_rndx),
	.rndxv(alu0_rndxv),
	.rob(rob[alu0_rndx]),
	.rfo_argA(rfo_alu0_argA),
	.rfo_argB(rfo_alu0_argB),
	.rfo_argC(rfo_alu0_argC),
	.rfo_argT(rfo_alu0_argT),
	.rfo_argM(rfo_alu0_argM),
	.rfo_argA_ctag(rfo_alu0_argA_ctag),
	.rfo_argB_ctag(rfo_alu0_argB_ctag),
	.vrm(vrm),
	.vex(vex),
	.wrport0_v(wrport0_v),
	.wrport0_Rt(wrport0_Rt),
	.wrport0_res(wrport0_res),
	.ld(alu0_ld),
	.id(alu0_id), 
	.argA(alu0_argA),
	.argB(alu0_argB),
	.argBI(alu0_argBI),
	.argC(alu0_argC),
	.argI(alu0_argI),
	.argT(alu0_argT),
	.argM(alu0_argM),
	.argA_ctag(alu0_argA_ctag),
	.argB_ctag(alu0_argB_ctag),
	.cpytgt(alu0_cpytgt),
	.cs(alu0_cs),
	.aRtz(alu0_aRtz),
	.aRt(alu0_aRt),
	.nRt(alu0_Rt),
	.bank(alu0_bank),
	.instr(alu0_instr),
	.div(alu0_div),
	.cap(alu0_cap),
	.cptgt(alu0_cptgt),
	.pc(alu0_pc),
	.cp(alu0_cp),
	.pred(alu0_pred),
	.predz(alu0_predz),
	.prc(alu0_prc),
	.sc_done(alu0_sc_done),
	.idle_false(alu0_idle_false)
);

always_ff @(posedge clk) alu0_ldd <= alu0_ld;

generate begin : gAluStation
	if (NALU > 1) begin
		Qupls_alu_station ualust1
		(
			.rst(irst),
			.clk(clk),
			.available(alu1_available),
			.idle(alu1_idle),
			.issue(robentry_issue[alu1_rndx]),
			.rndx(alu1_rndx),
			.rndxv(alu1_rndxv),
			.rob(rob[alu1_rndx]),
			.rfo_argA(rfo_alu1_argA),
			.rfo_argB(rfo_alu1_argB),
			.rfo_argC(rfo_alu1_argC),
			.rfo_argT(rfo_alu1_argT),
			.rfo_argM(rfo_alu1_argM),
			.rfo_argA_ctag(rfo_alu1_argA_ctag),
			.rfo_argB_ctag(rfo_alu1_argB_ctag),
			.vrm(vrm),
			.vex(vex),
			.wrport0_v(wrport0_v),
			.wrport0_Rt(wrport0_Rt),
			.wrport0_res(wrport0_res),
			.ld(alu1_ld),
			.id(alu1_id), 
			.argA(alu1_argA),
			.argB(alu1_argB),
			.argBI(alu1_argBI),
			.argC(alu1_argC),
			.argI(alu1_argI),
			.argT(alu1_argT),
			.argM(alu1_argM),
			.argA_ctag(alu1_argA_ctag),
			.argB_ctag(alu1_argB_ctag),
			.cpytgt(alu1_cpytgt),
			.cs(alu1_cs),
			.aRtz(alu1_aRtz),
			.aRt(alu1_aRt),
			.nRt(alu1_Rt),
			.bank(alu1_bank),
			.instr(alu1_instr),
			.div(alu1_div),
			.cap(),
			.cptgt(alu1_cptgt),
			.pc(alu1_pc),
			.cp(alu1_cp),
			.pred(alu1_pred),
			.predz(alu1_predz),
			.prc(alu1_prc),
			.sc_done(alu1_sc_done),
			.idle_false(alu1_idle_false)
		);
	end
end
endgenerate

always_ff @(posedge clk) alu1_ldd <= alu1_ld;

genvar gNFPU;
wire fpu0_iq_rd_rst_busy, fpu0_iq_wr_rst_busy;
wire fpu0_iq_data_valid;
wire fpu0_iq_underflow;
wire fpu0_iq_wr_en = fpu0_rndxv;
wire fpu0_iq_rd_en = fpu0_idle;
fpu_iq_t fpu0_iq_i, fpu0_iq_o;

generate begin : gFpuStat
	for (gNFPU = 0; gNFPU < NFPU; gNFPU = gNFPU + 1) begin
		case (gNFPU)
		0:
			begin
			Qupls_fpu_station ufpustat0
			(
				.rst(irst),
				.clk(clk),
				// outputs
				.id(fpu0_id),
				.argA(fpu0_argA),
				.argB(fpu0_argB),
				.argC(fpu0_argC),
				.argT(fpu0_argT),
				.argM(fpu0_argM),
				.argI(fpu0_argI),
				.Rt(fpu0_Rt),
				.Rt1(fpu0_Rt1),
				.aRt(fpu0_aRt),
				.aRtz(fpu0_aRtz),
				.aRt1(fpu0_aRt1),
				.aRtz1(fpu0_aRtz1),
				.argA_tag(fpu0_argA_tag),
				.argB_tag(fpu0_argB_tag),
				.cs(fpu0_cs),
				.bank(fpu0_bank),
				.instr(fpu0_instr),
				.pc(fpu0_pc),
				.cp(fpu0_cp),
				.qfext(fpu0_qfext),
				.cptgt(fpu0_cptgt),
				.sc_done(fpu0_sc_done),
				// inputs
				.available(fpu0_available),
				.rndx(fpu0_iq_o.rndx),
				.rndxv(fpu0_iq_data_valid & ~fpu0_iq_underflow),
				.idle(fpu0_idle),
				.rfo_argA(fpu0_iq_o.argA),
				.rfo_argB(fpu0_iq_o.argB),
				.rfo_argC(fpu0_iq_o.argC),
				.rfo_argT(fpu0_iq_o.argT),
				.rfo_argM(fpu0_iq_o.argM),
				.rfo_argA_ctag(fpu0_iq_o.argA_ctag),
				.rfo_argB_ctag(fpu0_iq_o.argB_ctag),
				.rob(fpu0_iq_o.rob)
			);

			assign fpu0_iq_i.rndx = fpu0_rndx;
			assign fpu0_iq_i.rob = rob[fpu0_rndx];
			assign fpu0_iq_i.argA = rfo_fpu0_argA;
			assign fpu0_iq_i.argB = rfo_fpu0_argB;
			assign fpu0_iq_i.argC = rfo_fpu0_argC;
			assign fpu0_iq_i.argT = rfo_fpu0_argT;
			assign fpu0_iq_i.argM = rfo_fpu0_argM;
			assign fpu0_iq_i.argA_ctag = rfo_fpu0_argA_ctag;
			assign fpu0_iq_i.argB_ctag = rfo_fpu0_argB_ctag;

	   // xpm_fifo_sync: Synchronous FIFO
	   // Xilinx Parameterized Macro, version 2024.1

	   xpm_fifo_sync #(
	      .CASCADE_HEIGHT(0),            // DECIMAL
	      .DOUT_RESET_VALUE("0"),        // String
	      .ECC_MODE("no_ecc"),           // String
	      .EN_SIM_ASSERT_ERR("warning"), // String
	      .FIFO_MEMORY_TYPE("distributed"),	// String
	      .FIFO_READ_LATENCY(0),         // DECIMAL
	      .FIFO_WRITE_DEPTH(FPU0_IQ_DEPTH),	// DECIMAL
	      .FULL_RESET_VALUE(0),          // DECIMAL
	      .PROG_EMPTY_THRESH(5),         // DECIMAL
	      .PROG_FULL_THRESH(FPU0_IQ_DEPTH-5),	// DECIMAL
	      .RD_DATA_COUNT_WIDTH($clog2(FPU0_IQ_DEPTH)+1),	// DECIMAL
	      .READ_DATA_WIDTH($bits(fpu_iq_t)),          // DECIMAL
	      .READ_MODE("fwft"),            // String
	      .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
	      .USE_ADV_FEATURES("1707"),     // String
	      .WAKEUP_TIME(0),               // DECIMAL
	      .WRITE_DATA_WIDTH($bits(fpu_iq_t)),	// DECIMAL
	      .WR_DATA_COUNT_WIDTH($clog2(FPU0_IQ_DEPTH)+1)	// DECIMAL
	   )
	   fpu0_iq1 (
	      .almost_empty(),
	      .almost_full(),

	      // 1-bit output: Read Data Valid: When asserted, this signal indicates
				// that valid data is available on the output bus (dout).
	      .data_valid(fpu0_iq_data_valid),

	      .dbiterr(),

	      // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
	      // when reading the FIFO.
	      .dout(fpu0_iq_o),

	      .empty(),
	      .full(),
	      .overflow(),
	      .prog_empty(),

	      // 1-bit output: Programmable Full: This signal is asserted when the
				// number of words in the FIFO is greater than or equal to the
				// programmable full threshold value. It is de-asserted when the number of
				// words in the FIFO is less than the programmable full threshold value.
	      .prog_full(fpu0_iq_prog_full),

	      .rd_data_count(),
	      .rd_rst_busy(fpu0_iq_rd_rst_busy),	// 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read
	                                     			// domain is currently in a reset state.

	      .sbiterr(),
	      // 1-bit output: Underflow: Indicates that the read request (rd_en) during
				// the previous clock cycle was rejected because the FIFO is empty. Under
				// flowing the FIFO is not destructive to the FIFO.
	      .underflow(fpu0_iq_underflow),

	      .wr_ack(),
	      .wr_data_count(),

	      .wr_rst_busy(fpu0_iq_wr_rst_busy),    // 1-bit output: Write Reset Busy: Active-High indicator that the FIFO
	                           				          // write domain is currently in a reset state.

	      .din(fpu0_iq_i),	             // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
	                                     // writing the FIFO.

	      .injectdbiterr(1'b0),
	      .injectsbiterr(1'b0),

				// 1-bit input: Read Enable: If the FIFO is not empty, asserting this
				// signal causes data (on dout) to be read from the FIFO. Must be held
				// active-low when rd_rst_busy is active high.
	      .rd_en(fpu0_iq_rd_en & ~fpu0_iq_rd_rst_busy),

	      .rst(irst),                    // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
	                                     // unstable at the time of applying reset, but reset must be released only
	                                     // after the clock(s) is/are stable.

	      .sleep(1'b0),
	      .wr_clk(clk),               		// 1-bit input: Write clock: Used for write operation. wr_clk must be a
	                                     // free running clock.

				// 1-bit input: Write Enable: If the FIFO is not full, asserting this
				// signal causes data (on din) to be written to the FIFO Must be held
				// active-low when rst or wr_rst_busy or rd_rst_busy is active high
	      .wr_en(fpu0_iq_wr_en & ~fpu0_wr_rst_busy & ~fpu0_rd_rst_busy & ~irst)
	   );

	   // End of xpm_fifo_sync_inst instantiation
				
			end
		1:
			Qupls_fpu_station ufpustat1
			(
				.rst(irst),
				.clk(clk),
				// outputs
				.id(fpu1_id),
				.argA(fpu1_argA),
				.argB(fpu1_argB),
				.argC(fpu1_argC),
				.argT(fpu1_argT),
				.argM(fpu1_argM),
				.argI(fpu1_argI),
				.Rt(fpu1_Rt),
				.Rt1(fpu1_Rt1),
				.aRt(fpu1_aRt),
				.aRtz(fpu1_aRtz),
				.aRt1(fpu1_aRt1),
				.aRtz1(fpu1_aRtz1),
				.argA_tag(fpu1_argA_ctag),
				.argB_tag(fpu1_argB_ctag),
				.cs(fpu1_cs),
				.bank(fpu1_bank),
				.instr(fpu1_instr),
				.pc(fpu1_pc),
				.cp(fpu1_cp),
				.qfext(fpu1_qfext),
				.cptgt(fpu1_cptgt),
				.sc_done(fpu1_sc_done),
				// inputs
				.available(fpu1_available),
				.rndx(fpu1_rndx),
				.rndxv(fpu1_rndxv),
				.idle(fpu1_idle),
				.rfo_argA(rfo_fpu1_argA),
				.rfo_argB(rfo_fpu1_argB),
				.rfo_argC(rfo_fpu1_argC),
				.rfo_argT(rfo_fpu1_argT),
				.rfo_argM(rfo_fpu1_argM),
				.rfo_argA_ctag(rfo_fpu1_argA_ctag),
				.rfo_argB_ctag(rfo_fpu1_argB_ctag),
				.rob(rob[fpu1_rndx])
			);
		endcase
	end
end
endgenerate

always_ff @(posedge clk)
if (irst) begin
	fcu_argA <= 64'd0;
	fcu_argB <= 64'd0;
	fcu_argBr <= 64'd0;
	fcu_argI <= 64'd0;
	fcu_instr <= nopi;
	fcu_pc.bno_t <= 6'd1;
	fcu_pc.bno_f <= 6'd1;
	fcu_pc.pc <= RSTPC;
	fcu_bt <= FALSE;
	fcu_bts <= BTS_NONE;
	fcu_id <= 5'd0;
	fcu_cjb <= 1'b0;
	fcu_cp <= 4'd0;
end
else begin
	if (robentry_fcu_issue[fcu_rndx] && fcu_rndxv && fcu_idle && bs_idle_oh) begin
		if (rob[fcu_rndx].op.ins.any.opcode==OP_BccU) begin
			if (rob[fcu_rndx].decbus.Ran)
				fcu_argA <= rob[fcu_rndx].decbus.Ra;
			else
				fcu_argA <= rfo_fcu_argA;
			if (rob[fcu_rndx].decbus.Rbn)
				fcu_argB <= rob[fcu_rndx].decbus.Rb;
			else
				fcu_argB <= rfo_fcu_argB;
		end
		else begin
			if (rob[fcu_rndx].decbus.Ran)
				fcu_argA <= {{56{rob[fcu_rndx].decbus.Ra[7]}},rob[fcu_rndx].decbus.Ra};
			else
				fcu_argA <= rfo_fcu_argA;
			if (rob[fcu_rndx].decbus.Rbn)
				fcu_argB <= {{56{rob[fcu_rndx].decbus.Rb[7]}},rob[fcu_rndx].decbus.Rb};
			else
				fcu_argB <= rfo_fcu_argB;
		end
		fcu_argBr <= rob[fcu_rndx].decbus.immb | rfo_fcu_argB;
		fcu_argI <= rob[fcu_rndx].decbus.immb;
		fcu_instr <= rob[fcu_rndx].op;
		fcu_pc <= rob[fcu_rndx].pc;
		fcu_bt <= rob[fcu_rndx].bt;
		fcu_bts <= rob[fcu_rndx].decbus.bts;
		fcu_id <= fcu_rndx;
		fcu_cjb <= rob[fcu_rndx].decbus.cjb;
		fcu_bsr <= rob[fcu_rndx].decbus.bsr;
		fcu_cp <= rob[fcu_rndx].cndx;
	end
end

Qupls_agen_station uagen0stn
(
	.rst(irst),
	.clk(clk),
	.idle_i(agen0_idle),
	.issue(robentry_agen_issue[agen0_rndx]),
	.rndx(agen0_rndx),
	.rndxv(agen0_rndxv),
	.rob(rob[agen0_rndx]),
	.rfo_argA(rfo_agen0_argA),
	.rfo_argB(rfo_agen0_argB),
	.rfo_argC(rfo_agen0_argC),
	.rfo_argM(rfo_agen0_argM),
	.rfo_argC_ctag(rfo_agen0_argC_ctag),
	.argC_v(agen0_argC_v),
	.id(agen0_id),
	.argA(agen0_argA),
	.argB(agen0_argB),
	.argC(agen0_argC),
	.argI(agen0_argI),
	.argM(agen0_argM),
	.argC_ctag(agen0_argC_ctag),
	.aRa(agen0_aRa),
	.aRb(agen0_aRb),
	.aRc(agen0_aRc),
	.aRt(agen0_aRt),
	.pRa(agen0_Ra),
	.pRb(agen0_Rb),
	.pRc(agen0_Rc),
	.pRt(agen0_Rt),
	.pc(agen0_pc),
	.op(agen0_op),
	.cp(agen0_cp),
	.excv(agen0_excv),
	.ldip(agen0_ldip),
	.idle_o(agen0_idle1),
	.store_argC_v(),
	.store_argI(),
	.store_argC_aReg(),
	.store_argC_pReg(agen0_pRc),
	.store_argC_cndx(),
	.beb_issue(beb_issue),
	.bndx(beb_ndx),
	.beb(beb_buf)
);

Qupls_agen_station uagen1stn
(
	.rst(irst),
	.clk(clk),
	.idle_i(agen1_idle),
	.issue(robentry_agen_issue[agen1_rndx]),
	.rndx(agen1_rndx),
	.rndxv(agen1_rndxv),
	.rob(rob[agen1_rndx]),
	.rfo_argA(rfo_agen1_argA),
	.rfo_argB(rfo_agen1_argB),
	.rfo_argC('d0),
	.rfo_argM(rfo_agen1_argM),
	.rfo_argC_ctag(1'b0),
	.id(agen1_id),
	.argA(agen1_argA),
	.argB(agen1_argB),
	.argC(),
	.argI(agen1_argI),
	.argM(agen1_argM),
	.argC_ctag(),
	.argC_v(),
	.aRa(agen1_aRa),
	.aRb(agen1_aRb),
	.aRc(),
	.aRt(agen1_aRt),
	.pRa(agen1_Ra),
	.pRb(agen1_Rb),
	.pRc(),
	.pRt(agen1_Rt),
	.pc(agen1_pc),
	.op(agen1_op),
	.cp(agen1_cp),
	.excv(agen1_excv),
	.ldip(agen1_ldip),
	.idle_o(agen1_idle1),
	.store_argC_v(),
	.store_argI(),
	.store_argC_aReg(),
	.store_argC_pReg(),
	.store_argC_cndx(),
	.beb_issue(1'b0),
	.bndx(2'd0),
	.beb()
);


reg dram0_idv2;
reg fcu_setflags;
always_comb
	fcu_setflags = fcu_v && rob[fcu_id].v && fcu_v3 && !robentry_stomp[fcu_id] 
		&& (bs_idle_oh||bs_done_oh||branch_state==BS_DONE2) && fcu_idv;
 	
always_comb
	dc_get = !(branchmiss || (branch_state < BS_CAPTURE_MISSPC && !bs_idle_oh))
//		&& advance_pipeline
		&& room_for_que
//		&& (!stomp_que || stomp_quem)
		;

always_comb
	inc_chkpt = (
		(ins0_dec.decbus.br && !stomp0) ||
		(ins1_dec.decbus.br && !stomp1) ||
		(ins2_dec.decbus.br && !stomp2) ||
		(ins3_dec.decbus.br && !stomp3) 
		)
		;
always_comb
	chkpt_inc_amt =
		(ins0_dec.decbus.br && !stomp0) +
		(ins1_dec.decbus.br && !stomp1) +
		(ins2_dec.decbus.br && !stomp2) +
		(ins3_dec.decbus.br && !stomp3) 
		;

edge_det uedbsi1 (.rst(irst), .clk(clk), .ce(1'b1), .i(bs_idle_oh), .pe(pe_bsidle), .ne(), .ee());

			
// ----------------------------------------------------------------------------
// fet/mux/dec/ren/que
// ----------------------------------------------------------------------------
// =============================================================================
// =============================================================================
// Clocked logic
// =============================================================================
// =============================================================================

always_ff @(posedge clk)
if (irst) begin
	tReset();
end
else begin
	irq_wr_en <= FALSE;
	if (sr.ssm & advance_pipeline)
		ssm_flag <= TRUE;

	// Check if all instruciton arguments are valid.
	for (n3 = 0; n3 < ROB_ENTRIES; n3 = n3 + 1)
		tAllArgsValid(n3, INV, INV, INV, INV, INV);

	// The reorder buffer is not updated with the argument values. This is done
	// just for debugging in SIM. All values come from the register file.
`ifdef IS_SIM
	if (alu0_available && alu0_rndxv && alu0_idle) begin
		rob[alu0_rndx].argA <= rfo_alu0_argA;
		rob[alu0_rndx].argB <= rfo_alu0_argB;
		rob[alu0_rndx].argT <= rfo_alu0_argT;
	end
	if (NALU > 1) begin
		if (alu1_available && alu1_rndxv && alu1_idle) begin
			rob[alu1_rndx].argA <= rfo_alu1_argA;
			rob[alu1_rndx].argB <= rfo_alu1_argB;
			rob[alu1_rndx].argT <= rfo_alu1_argT;
		end
	end
	if (NFPU > 0) begin
		if (fpu0_available && fpu0_rndxv && fpu0_idle) begin
			rob[fpu0_rndx].argA <= rfo_fpu0_argA;
			rob[fpu0_rndx].argB <= rfo_fpu0_argB;
			rob[fpu0_rndx].argT <= rfo_fpu0_argT;
		end
	end
	if (agen0_rndxv && agen0_idle && robentry_agen_issue[agen0_rndx]) begin
		rob[agen0_rndx].argA <= rfo_agen0_argA;
		rob[agen0_rndx].argB <= rfo_agen0_argB;
	end
	if (NAGEN > 1) begin
		if (agen1_rndxv && agen1_idle) begin
			rob[agen1_rndx].argA <= rfo_agen1_argA;
			rob[agen1_rndx].argB <= rfo_agen1_argB;
		end
	end
	if (fcu_rndxv && fcu_idle) begin
		rob[fcu_rndx].argA <= rfo_fcu_argA;
		rob[fcu_rndx].argB <= rfo_fcu_argB;
	end
`endif
	if (alu0_available && alu0_rndxv && alu0_idle) begin
		rob[alu0_rndx].argC <= rfo_alu0_argC;
	end
	if (NALU > 1) begin
		if (alu1_available && alu1_rndxv && alu1_idle) begin
			rob[alu1_rndx].argC <= rfo_alu1_argC;
		end
	end
	if (NFPU > 0) begin
		if (fpu0_available && fpu0_rndxv && fpu0_idle) begin
			rob[fpu0_rndx].argC <= rfo_fpu0_argC;
		end
	end
	if (agen0_rndxv && agen0_idle && robentry_agen_issue[agen0_rndx]) begin
		rob[agen0_rndx].argC <= rfo_agen0_argC;
	end

	if (!rstcnt[2])
		rstcnt <= rstcnt + 1;

	set_pending_ipl <= FALSE;
	cpu_request_cancel <= {ROB_ENTRIES{1'b0}};
	alu0_done <= FALSE;
	alu1_done <= FALSE;
	if (fpu0_done1)
		fpu0_done1 <= FALSE;
	if (fpu1_done1)
		fpu1_done1 <= FALSE;
	// Fcu op may have been stomped on after issue, so check valid flag.
	if (TRUE) begin
		fcu_v2 <= fcu_v && (rob[fcu_id].v|brtgtvr);
		fcu_v3 <= fcu_v2 && (rob[fcu_id].v|brtgtvr);
		fcu_v4 <= fcu_v3 && (rob[fcu_id].v|brtgtvr);
		fcu_v5 <= fcu_v4 && (rob[fcu_id].v|brtgtvr);
		fcu_v6 <= fcu_v5;
		fcu_new <= FALSE;
		brtgtv <= INV;
		if (fcu_v6)
			brtgtvr <= INV;
	  if (~hirq) begin
	  	if ((pe_allqd|allqd) && !hold_ins && advance_pipeline_seg2)
	  		excret <= FALSE;
		end
	end
	alu0_stomp <= FALSE;
	alu1_stomp <= FALSE;
	fpu0_stomp <= FALSE;
	fpu1_stomp <= FALSE;
	dram0_stomp <= FALSE;
	dram1_stomp <= FALSE;
	dram0_idv2 <= dram0_idv;
//	inc_chkpt <= FALSE;

	// Set atom mask
	if (fnIsAtom(ins0_dec))
		atom_mask <= ins0_dec.ins[40:8];
	if (fnIsAtom(ins1_dec))
		atom_mask <= ins1_dec.ins[40:8];
	if (fnIsAtom(ins2_dec))
		atom_mask <= ins2_dec.ins[40:8];
	if (fnIsAtom(ins3_dec))
		atom_mask <= ins3_dec.ins[40:8];

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
	if (branchmiss || (branch_state < BS_CAPTURE_MISSPC && !bs_idle_oh)) begin
		;
//		if (|robentry_stomp)
//			tail0 <= stail;		// computed above
	end
	else if (advance_pipeline) begin
		//if (!stomp_que || stomp_quem) 
		begin
			// On a predicted taken branch the front end will continue to send
			// instructions to be queued, but they will be ignored as they are
			// treated as NOPs as the valid bit will not be set. They will however
			// occupy slots in the ROB. It takes extra logic to pack the ROB and
			// the logic budget is tight, so we do not bother. There should be
			// little impact on performance.
			for (n12 = 0; n12 < ROB_ENTRIES; n12 = n12 + 1)
				rob[n12].sn <= rob[n12].sn - 4;
			tEnque(8'h80-XWID,groupno,predino,predrndx,ins0_ren,pt0_q,tail0,
				stomp0, ornop0,
				prn[0], prn[1], prn[2], prn[3], Rt0_ren, prn[17],
				prnv[0], prnv[1], prnv[2], prnv[3], prnv[17],
				cndx_ren[0], pcndx_ren, grplen0, last0);
			if (ins0_ren.decbus.pred) begin
				predino = 3'd1;
				predrndx = tail0;
			end
			else if (predino > 4'd0) begin
				predino = predino + 2'd1;
				if (predino==4'd9)
					predino = 4'd0;
			end
			/*
			tBypassRegnames(tail0, ins0_ren, ins0_que, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
			tBypassRegnames(tail0, ins0_ren, ins1_que, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
			tBypassRegnames(tail0, ins0_ren, ins2_que, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
			tBypassRegnames(tail0, ins0_ren, ins3_que, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
			*/
			/*
			if (prn[0]==11'd0 && ins0_ren.decbus.Ra!=9'd0) begin
				$display("Enque0: Ra mapped to zero.");
				$finish;
			end
			*/
			atom_mask <= atom_mask[32:3];
			
			if (XWID > 1) begin
				tEnque(8'h81-XWID,groupno,predino,predrndx,ins1_ren,pt1_q,tail1,
					stomp1, ornop1, prn[4], prn[5], prn[6], prn[7], Rt1_ren, prn[18],
					prnv[4], prnv[5], prnv[6], prnv[7], prnv[18],
					cndx_ren[1], pcndx_ren, grplen1, last1);
				if (ins1_ren.decbus.pred) begin
					predino = 3'd1;
					predrndx = tail1;
				end
				else if (predino > 4'd0) begin
					predino = predino + 2'd1;
					if (predino==4'd9)
						predino = 4'd0;
				end
				/*
				if (prn[4]==11'd0 && ins1_ren.decbus.Ra!=9'd0) begin
					$display("Enque1: Ra mapped to zero.");
					$finish;
				end
				*/
					// If the instruction's source register is the same as a previous target
					// register, use the register mapping of the previous target register.
					// The register mapping will not have been updated in the RAT yet in
					// time to be available for the source register.
				/*
				tBypassRegnames(tail1, ins1_ren, ins0_que, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
				tBypassRegnames(tail1, ins1_ren, ins1_que, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
				tBypassRegnames(tail1, ins1_ren, ins2_que, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
				tBypassRegnames(tail1, ins1_ren, ins3_que, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
				*/
				tBypassRegnames(tail1, ins1_ren, ins0_ren, 1'b0, ins1_ren.decbus.has_immb | prnv[3], ins1_ren.decbus.has_immc | prnv[3], prnv[3], prnv[3]);
				tBypassValid(tail1, ins1_ren, ins0_ren);
				
				atom_mask <= atom_mask[32:6];
			end
			
			if (XWID > 2) begin
				tEnque(8'h82-XWID,groupno,predino,predrndx,ins2_ren,pt2_q,tail2,
					stomp2, ornop2, prn[8], prn[9], prn[10], prn[11], Rt2_ren, prn[19],
					prnv[8], prnv[9], prnv[10], prnv[11], prnv[19],
					cndx_ren[2], pcndx_ren,
					grplen2, last3);
				if (ins2_ren.decbus.pred) begin
					predino = 3'd1;
					predrndx = tail2;
				end
				else if (predino > 4'd0) begin
					predino = predino + 2'd1;
					if (predino==4'd9)
						predino = 4'd0;
				end
				/*
				if (prn[8]==11'd0 && ins2_ren.decbus.Ra!=9'd0) begin
					$display("Enque2: Ra mapped to zero.");
					$finish;
				end
				*/
				/*
				tBypassRegnames(tail2, ins2_ren, ins0_que, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
				tBypassRegnames(tail2, ins2_ren, ins1_que, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
				tBypassRegnames(tail2, ins2_ren, ins2_que, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
				tBypassRegnames(tail2, ins2_ren, ins3_que, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
				*/
				tBypassRegnames(tail2, ins2_ren, ins0_ren, ins2_que.decbus.has_imma, ins2_ren.decbus.has_immb | prnv[3], ins2_ren.decbus.has_immc | prnv[3], prnv[3], prnv[3]);
				tBypassRegnames(tail2, ins2_ren, ins1_ren, ins2_que.decbus.has_imma, ins2_ren.decbus.has_immb | prnv[7], ins2_ren.decbus.has_immc | prnv[7], prnv[7], prnv[7]);
				tBypassValid(tail2, ins2_ren, ins0_ren);
				tBypassValid(tail2, ins2_ren, ins1_ren);
				
				atom_mask <= atom_mask[32:9];
			end

			if (XWID > 3) begin
				tEnque(8'h83-XWID,groupno,predino,predrndx,ins3_ren,pt3_q,tail3,
					stomp3, ornop3, prn[12], prn[13], prn[14], prn[15], Rt3_ren, prn[20],
					prnv[12], prnv[13], prnv[14], prnv[15], prnv[20],
					cndx_ren[3], pcndx_ren,
					grplen3,last3);
				if (ins3_ren.decbus.pred) begin
					predino = 3'd1;
					predrndx = tail3;
				end
				else if (predino > 4'd0) begin
					predino = predino + 2'd1;
					if (predino==4'd9)
						predino = 4'd0;
				end
				/*
				if (prn[12]==11'd0 && !ins3_ren.decbus.Raz) begin
					$display("Enque3: Ra mapped to zero.");
					$finish;
				end
				*/
				/*
				tBypassRegnames(tail3, ins3_ren, ins0_que, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
				tBypassRegnames(tail3, ins3_ren, ins1_que, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
				tBypassRegnames(tail3, ins3_ren, ins2_que, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
				tBypassRegnames(tail3, ins3_ren, ins3_que, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
				*/
				tBypassRegnames(tail3, ins3_ren, ins0_ren, ins3_ren.decbus.has_imma, ins3_ren.decbus.has_immb | prnv[3], ins3_ren.decbus.has_immc | prnv[3], prnv[3], prnv[3]);
				tBypassRegnames(tail3, ins3_ren, ins1_ren, ins3_ren.decbus.has_imma, ins3_ren.decbus.has_immb | prnv[7], ins3_ren.decbus.has_immc | prnv[7], prnv[7], prnv[7]);
        tBypassRegnames(tail3, ins3_ren, ins2_ren, ins3_ren.decbus.has_imma, ins3_ren.decbus.has_immb | prnv[11], ins3_ren.decbus.has_immc | prnv[11], prnv[11], prnv[11]);
				tBypassValid(tail3, ins3_ren, ins0_ren);
				tBypassValid(tail3, ins3_ren, ins1_ren);
				tBypassValid(tail3, ins3_ren, ins2_ren);
				
				atom_mask <= atom_mask[32:12];
			end
			tail0 <= (tail0 + 3'd4) % ROB_ENTRIES;
			groupno <= groupno + 2'd1;
		end
	end

	// Place up to two instructions into the load/store queue in order.	
/*
	if (lsq[lsq_tail0.row][0].v==INV && rob[agen0_id].out[0] && !rob[agen0_id].lsq && rob[agen0_id].decbus.mem && !rob[agen0_id].decbus.cpytgt ) begin	// Can an entry be queued?
		if (!fnIsInLSQ(agen0_id)) begin
			rob[agen0_id].lsq <= VAL;
			rob[agen0_id].lsqndx <= lsq_tail0;
		end
		if (LSQ2 && lsq[lsq_tail0.row][1].v==INV && rob[agen1_id].out[0] && !rob[agen1_id].lsq && rob[agen1_id].decbus.mem && !rob[agen1_id].decbus.cpytgt ) begin	// Can a second entry be queued?
			if (!fnIsInLSQ(agen1_id)) begin
				rob[agen1_id].lsq <= VAL;
				rob[agen1_id].lsqndx <= {lsq_tail0.row,1'b1};
			end
		end
	end
*/
	if (lsq[lsq_tail0.row][0].v==INV && rob[agen0_id].out[0] && !rob[agen0_id].lsq && rob[agen0_id].decbus.mem && !rob[agen0_id].decbus.cpytgt && !(&rob[agen0_id].done)) begin	// Can an entry be queued?
		if (!fnIsInLSQ(agen0_id)) begin
			if (!robentry_stomp[agen0_id] && rob[agen0_id].v==VAL) begin
				rob[agen0_id].lsq <= VAL;
				rob[agen0_id].lsqndx <= lsq_tail0;
				tEnqueLSE(7'h7F, lsq_tail0, agen0_id, rob[agen0_id], 2'd1);
				lsq_tail.row <= (lsq_tail.row + 2'd1) % LSQ_ENTRIES;
				lsq_tail.col <= 3'd0;
			end
		end
		if (LSQ2 && lsq[lsq_tail0.row][1].v==INV && rob[agen1_id].out[0] && !rob[agen1_id].lsq && rob[agen1_id].decbus.mem && !rob[agen1_id].decbus.cpytgt && !(&rob[agen1_id].done)) begin	// Can a second entry be queued?
			if (!fnIsInLSQ(agen1_id)) begin
				if (!robentry_stomp[agen1_id] && rob[agen1_id].v==VAL) begin
					rob[agen1_id].lsq <= VAL;
					rob[agen1_id].lsqndx <= {lsq_tail0.row,1'b1};
					tEnqueLSE(7'h7F, {lsq_tail0.row,lsq_tail0.col|1}, agen1_id, rob[agen1_id], 2'd2);
					lsq[lsq_tail0.row][0].sn <= 7'h7E;
				end
			end
		end
	end

// ----------------------------------------------------------------------------
// ISSUE 
// ----------------------------------------------------------------------------
// determines what instructions are ready to go, then places them
// in the various ALU queues.  
// also invalidates instructions following a branch-miss BEQ or any JALR (STOMP logic)
//

	if (lsq[lsq_head.row][lsq_head.col].v==VAL) begin
		store_argC_aReg <= lsq[lsq_head.row][lsq_head.col].aRc;
		store_argC_pReg <= lsq[lsq_head.row][lsq_head.col].pRc;
		store_argC_cndx <= lsq[lsq_head.row][lsq_head.col].cndx;
		store_argC_id <= lsq_head;
		store_argC_id1 <= store_argC_id;
	end

	// It takes a clock cycle for the register to be read once it is known to be
	// valid. A flag, load_lsq_argc, is set to delay by a clock. This flag pulses
	// for only a single clock cycle.
	if (lsq[store_argC_id1.row][store_argC_id1.col].v==VAL && lsq[store_argC_id1.row][store_argC_id1.col].store && lsq[store_argC_id1.row][store_argC_id1.col].datav==INV) begin
		if (prnv[23]|rob[lsq[store_argC_id1.row][store_argC_id1.col].rndx].argC_v)//|store_argC_v)
			load_lsq_argc <= TRUE;
	end
	if (lsq[store_argC_id1.row][store_argC_id1.col].v==VAL && lsq[store_argC_id1.row][store_argC_id1.col].store && lsq[store_argC_id1.row][store_argC_id1.col].datav==INV) begin
	if (load_lsq_argc) begin//prnv[23]) begin
		$display("Q+ CPU: LSQ Rc=%h from r%d/%d", rfo_store_argC, store_argC_aReg, store_argC_pReg);
		lsq[store_argC_id1.row][store_argC_id1.col].res <= prnv[23] ? rfo_store_argC : rob[lsq[store_argC_id1.row][store_argC_id1.col].rndx].argC;
		lsq[store_argC_id1.row][store_argC_id1.col].ctag <= rfo_store_argC_ctag;
		lsq[store_argC_id1.row][store_argC_id1.col].datav <= VAL;
	end
	end

/*
	// Operand source muxes
	if (alu0_available) begin
		case(alu0_argA_src)
		OP_SRC_REG:	alu0_argA <= rfo_alu0_argA;
		OP_SRC_ALU0: alu0_argA <= alu0_res;
		OP_SRC_ALU1: alu0_argA <= alu1_res;
		OP_SRC_FPU0: alu0_argA <= fpu0_res;
		OP_SRC_FCU:	alu0_argA <= fcu_res;
		OP_SRC_LOAD:	alu0_argA <= load_res;
		OP_SRC_IMM:	alu0_argA <= rob[alu0_sndx].imma;
		default:	alu0_argA <= {2{32'hDEADBEEF}};
		endcase
		case(alu0_argB_src)
		OP_SRC_REG:	alu0_argB <= rfo_alu0_argB;
		OP_SRC_ALU0: alu0_argB <= alu0_res;
		OP_SRC_ALU1: alu0_argB <= alu1_res;
		OP_SRC_FPU0: alu0_argB <= fpu0_res;
		OP_SRC_FCU:	alu0_argB <= fcu_res;
		OP_SRC_LOAD:	alu0_argB <= load_res;
		OP_SRC_IMM:	alu0_argB <= rob[alu0_sndx].immb;
		default:	alu0_arga <= {2{32'hDEADBEEF}};
		endcase
		case(alu0_argC_src)
		OP_SRC_REG:	alu0_argC <= rfo_alu0_argC;
		OP_SRC_ALU0: alu0_argC <= alu0_res;
		OP_SRC_ALU1: alu0_argC <= alu1_res;
		OP_SRC_FPU0: alu0_argC <= fpu0_res;
		OP_SRC_FCU:	alu0_argC <= fcu_res;
		OP_SRC_LOAD:	alu0_argC <= load_res;
		OP_SRC_IMM:	alu0_argC <= rob[alu0_sndx].immc;
		default:	alu0_argC <= {2{32'hDEADBEEF}};
		endcase
		alu0_argI	<= rob[alu0_sndx].decbus.immb;
		alu0_ld <= 1'b1;
		alu0_instr <= rob[alu0_sndx].op;
		alu0_div <= rob[alu0_sndx].decbus.div;
		alu0_pc <= rob[alu0_sndx].pc;
    rob[alu0_sndx].out <= VAL;
    rob[alu0_sndx].owner <= QuplsPkg::ALU0;
  end

	if (alu1_available) begin
		case(alu1_argA_src)
		OP_SRC_REG:	alu1_argA <= rfo_alu1_argA;
		OP_SRC_alu1: alu1_argA <= alu1_res;
		OP_SRC_ALU1: alu1_argA <= alu1_res;
		OP_SRC_FPU0: alu1_argA <= fpu0_res;
		OP_SRC_FCU:	alu1_argA <= fcu_res;
		OP_SRC_LOAD:	alu1_argA <= load_res;
		OP_SRC_IMM:	alu1_argA <= rob[alu1_sndx].imma;
		default:	alu1_argA <= {2{32'hDEADBEEF}};
		endcase
		case(alu1_argB_src)
		OP_SRC_REG:	alu1_argB <= rfo_alu1_argB;
		OP_SRC_alu1: alu1_argB <= alu1_res;
		OP_SRC_ALU1: alu1_argB <= alu1_res;
		OP_SRC_FPU0: alu1_argB <= fpu0_res;
		OP_SRC_FCU:	alu1_argB <= fcu_res;
		OP_SRC_LOAD:	alu1_argB <= load_res;
		OP_SRC_IMM:	alu1_argB <= rob[alu1_sndx].immb;
		default:	alu1_arga <= {2{32'hDEADBEEF}};
		endcase
		case(alu1_argC_src)
		OP_SRC_REG:	alu1_argC <= rfo_alu1_argC;
		OP_SRC_alu1: alu1_argC <= alu1_res;
		OP_SRC_ALU1: alu1_argC <= alu1_res;
		OP_SRC_FPU0: alu1_argC <= fpu0_res;
		OP_SRC_FCU:	alu1_argC <= fcu_res;
		OP_SRC_LOAD:	alu1_argC <= load_res;
		OP_SRC_IMM:	alu1_argC <= rob[alu1_sndx].immc;
		default:	alu1_argC <= {2{32'hDEADBEEF}};
		endcase
		alu1_argI	<= rob[alu1_sndx].decbus.immb;
		alu1_ld <= 1'b1;
		alu1_instr <= rob[alu1_sndx].op;
		alu1_div <= rob[alu1_sndx].decbus.div;
		alu1_pc <= rob[alu1_sndx].pc;
    rob[alu1_sndx].out <= VAL;
    rob[alu1_sndx].owner <= QuplsPkg::alu1;
  end
*/

//
// DATAINCOMING
//
// Once the operation is done, flag the ROB entry as done and mark the unit
// as idle. Record any exceptions that may have occurred.
//
	// Debug
`ifdef IS_SIM	    
	if (alu0_sc_done2|alu0_done)
  		rob[alu0_id].res <= wrport0_v ? alu0_res : value_zero;
	if (alu1_sc_done2|alu1_done)
  		rob[alu1_id].res <= wrport1_v ? alu1_res : value_zero;
	if (fpu0_sc_done2|fpu0_done)
  		rob[alu0_id].res <= wrport3_v ? fpu0_res : value_zero;
`endif

	// idle flag
  if (rob[alu0_id].v && alu0_idv) begin
		// Handle single-cycle ops
  	if (!rob[ alu0_id ].decbus.multicycle || (&alu0_cptgt))
	   	alu0_idle1 <= TRUE;
	  // Handle multi-cycle ops
		else begin
			alu0_idle1 <= FALSE;
			if ((!rob[alu0_id].done[0] || (|alu0_cptgt && rob[alu0_id].done!=2'b11))) begin
		    if (rob[ alu0_id ].decbus.fc || rob[ alu0_id ].decbus.pushi)
		    	alu0_idle1 <= TRUE;
		    if ((rob[ alu0_id ].decbus.mul || rob[ alu0_id ].decbus.mulu) && mul0_done)
			    alu0_idle1 <= TRUE;
		    if ((rob[ alu0_id ].decbus.div || rob[ alu0_id ].decbus.divu) && div0_done)
			    alu0_idle1 <= TRUE;
			end
		end
	end

	// idle flag
  if (rob[alu1_id].v && alu1_idv) begin
		// Handle single-cycle ops
  	if (!rob[ alu1_id ].decbus.multicycle || (&alu1_cptgt))
	   	alu1_idle1 <= TRUE;
	  // Handle multi-cycle ops
		else begin
			alu1_idle1 <= FALSE;
			if ((!rob[alu1_id].done[0] || (|alu1_cptgt && rob[alu1_id].done!=2'b11))) begin
		    if (rob[ alu1_id ].decbus.fc || rob[ alu1_id ].decbus.pushi)
		    	alu1_idle1 <= TRUE;
		    if ((rob[ alu1_id ].decbus.mul || rob[ alu1_id ].decbus.mulu) && mul1_done)
			    alu1_idle1 <= TRUE;
		    if ((rob[ alu1_id ].decbus.div || rob[ alu1_id ].decbus.divu) && div1_done)
			    alu1_idle1 <= TRUE;
			end
		end
	end

	// Handle single-cycle ops
	// Whenever a result would be written, update the exception and done/out status.
	// Although no result may be written, the done/out status still needs to be set.
	if (alu0_sc_done2) begin
    rob[ alu0_id2 ].exc <= cause_code_t'(alu0_exc[7:0]);
    rob[ alu0_id2 ].excv <= ~&alu0_exc[7:0];
		rob[ alu0_id2 ].done[0] <= TRUE;
		rob[ alu0_id2 ].out[0] <= FALSE;
//		if (rob[alu0_id2].decbus.fc && rob[alu0_id2].op.ins.any.opcode==OP_Bcc)
//			$finish;
    if (((!rob[ alu0_id2 ].decbus.fc||rob[alu0_id2].decbus.cjb) && !rob[ alu0_id2 ].decbus.pushi) || rob[alu0_id2].decbus.cpytgt) begin
			rob[ alu0_id2 ].done[1] <= TRUE;
			rob[ alu0_id2 ].out[1] <= FALSE;
		end
		alu0_idv <= INV;
	end

  if (rob[alu0_id].v && alu0_idv) begin
	  // Handle multi-cycle ops
  	if (rob[ alu0_id ].decbus.multicycle &&
			(!rob[alu0_id].done[0] || (|alu0_cptgt && rob[alu0_id].done!=2'b11))) begin
	    rob[ alu0_id ].exc <= cause_code_t'(alu0_exc[7:0]);
	    rob[ alu0_id ].excv <= ~&alu0_exc[7:0];
	    if (!rob[ alu0_id ].decbus.pushi) begin
	    	rob[ alu0_id ].done[1] <= TRUE;
		    rob[ alu0_id ].out[1] <= INV;
	    end
	    rob[ alu0_id ].out[0] <= INV;

	    if ((rob[ alu0_id ].decbus.mul || rob[ alu0_id ].decbus.mulu) && mul0_done) begin
	    	alu0_done <= TRUE;
		    alu0_idv <= INV;
		    rob[ alu0_id ].done <= {VAL,VAL};
		    rob[ alu0_id ].out <= {INV,INV};
  		end

	    if ((rob[ alu0_id ].decbus.div || rob[ alu0_id ].decbus.divu) && div0_done) begin
	    	alu0_done <= TRUE;
		    alu0_idv <= INV;
		    rob[ alu0_id ].done <= {VAL,VAL};
		    rob[ alu0_id ].out <= {INV,INV};
	  	end
	  	if (alu0_pred) begin
	  		begin
		  		alu0_idv <= INV;
			    rob[ alu0_id ].done <= 2'b11;
			    rob[ alu0_id ].out <= {INV,INV};
			    rob[alu0_id].pred_status[ 7: 0] <= fnPredStatus(alu0_instr[45:44], alu0_argA[ 7: 0], alu0_argB[ 7: 0], alu0_argC[ 7: 0]);
			    rob[alu0_id].pred_status[15: 8] <= fnPredStatus(alu0_instr[47:46], alu0_argA[15: 8], alu0_argB[15: 8], alu0_argC[15: 8]);
			    rob[alu0_id].pred_status[23:16] <= fnPredStatus(alu0_instr[49:48], alu0_argA[23:16], alu0_argB[23:16], alu0_argC[23:16]);
			    rob[alu0_id].pred_status[31:24] <= fnPredStatus(alu0_instr[51:50], alu0_argA[31:24], alu0_argB[31:24], alu0_argC[31:24]);
			    rob[alu0_id].pred_status[39:32] <= fnPredStatus(alu0_instr[53:52], alu0_argA[39:32], alu0_argB[39:32], alu0_argC[39:32]);
			    rob[alu0_id].pred_status[47:40] <= fnPredStatus(alu0_instr[55:54], alu0_argA[47:40], alu0_argB[47:40], alu0_argC[47:40]);
			    rob[alu0_id].pred_status[55:48] <= fnPredStatus(alu0_instr[57:56], alu0_argA[55:48], alu0_argB[55:48], alu0_argC[55:48]);
			    rob[alu0_id].pred_status[63:56] <= fnPredStatus(alu0_instr[59:58], alu0_argA[63:56], alu0_argB[63:56], alu0_argC[63:56]);
		  	end
	  	end
	  	if (&alu0_cptgt) begin
		    begin
			    alu0_idv <= INV;
		    	rob[ alu0_id ].done <= 2'b11;
		    	rob[ alu0_id ].out <= {INV,INV};
		  	end
			end
			if (~|alu0_exc[7:0])
				vrm[rob[alu0_id].vn] <= vrm[rob[alu0_id].vn] & ~(64'hFF << {rob[alu0_id].op.element,3'b0});
			if (|alu0_exc[7:0])
				vex[rob[alu0_id].vn] <= vex[rob[alu0_id].vn] | (alu0_exc[7:0] << {rob[alu0_id].op.element,3'b0});
		end
	end

	// Handle single-cycle ops
	if (NALU > 1) begin
		if (alu1_sc_done2) begin
	    rob[ alu1_id2 ].exc <= cause_code_t'(alu1_exc[7:0]);
	    rob[ alu1_id2 ].excv <= ~&alu1_exc[7:0];
			rob[ alu1_id2 ].done[0] <= TRUE;
			rob[ alu1_id2 ].out[0] <= FALSE;
	//		if (rob[alu0_id2].decbus.fc && rob[alu0_id2].op.ins.any.opcode==OP_Bcc)
	//			$finish;
	    if (((!rob[ alu1_id2 ].decbus.fc||rob[alu1_id2].decbus.cjb) && !rob[ alu1_id2 ].decbus.pushi) || rob[alu1_id2].decbus.cpytgt) begin
				rob[ alu1_id2 ].done[1] <= TRUE;
				rob[ alu1_id2 ].out[1] <= FALSE;
			end
			alu1_idv <= INV;
		end
	  // Handle multi-cycle ops
	  if (rob[alu1_id].v && alu1_idv) begin
			if (rob[ alu1_id ].decbus.multicycle && !rob[alu1_id].done[0]||(|alu1_cptgt&&rob[alu1_id].done!=2'b11)) begin
		    rob[ alu1_id ].exc <= cause_code_t'(alu1_exc[7:0]);
		    rob[ alu1_id ].excv <= ~&alu1_exc[7:0];
		    if (!rob[ alu1_id ].decbus.pushi) begin
		    	rob[ alu1_id ].done[1] <= TRUE;
			    rob[ alu1_id ].out[1] <= INV;
		    end
		    rob[ alu1_id ].out[0] <= INV;
		    if ((rob[ alu1_id ].decbus.mul || rob[ alu1_id ].decbus.mulu) && mul1_done) begin
		    	alu1_done <= TRUE;
			    alu1_idv <= INV;
			    rob[ alu1_id ].done <= {VAL,VAL};
			    rob[ alu1_id ].out <= {INV,INV};
		  	end
		  	if (&alu1_cptgt) begin
		    	alu1_done <= TRUE;
			    alu1_idv <= INV;
			    rob[ alu1_id ].done <= {VAL,VAL};
			    rob[ alu1_id ].out <= {INV,INV};
				end
				if (~|alu1_exc[7:0])  		
					vrm[rob[alu1_id].vn] <= vrm[rob[alu1_id].vn] & ~(64'hFF << {rob[alu1_id].op.element,3'b0});
				if (|alu1_exc[7:0])
					vex[rob[alu1_id].vn] <= vex[rob[alu1_id].vn] | (alu1_exc[7:0] << {rob[alu1_id].op.element,3'b0});
			end
		end
	end
	
	if (NFPU > 0) begin
		if (fpu0_sc_done2) begin// && !fpu0_aRtz2) begin
	    rob[ fpu0_id2 ].exc <= cause_code_t'(fpu0_exc[7:0]);
	    rob[ fpu0_id2 ].excv <= ~&fpu0_exc[7:0];
			rob[ fpu0_id2 ].done[0] <= TRUE;
			rob[ fpu0_id2 ].out[0] <= FALSE;
			rob[ fpu0_id2 ].done[1] <= TRUE;
			rob[ fpu0_id2 ].out[1] <= FALSE;
		end
	  if ((rob[fpu0_id].v && fpu0_idv && rob[ fpu0_id ].decbus.multicycle)
		&& (!fpu0_idle && (!rob[fpu0_id].done[0]||(|fpu0_cptgt&&rob[fpu0_id].done!=2'b11)))) begin
			if (fpu0_done) begin
				fpu0_idle <= TRUE;
		   	fpu0_done1 <= TRUE;
				fpu0_idv <= INV;
				rob[fpu0_id].done <= {VAL,VAL};
				rob[fpu0_id].out <= {INV,INV};
				// If a quad precision op is performed, release the ALU
				if (rob[fpu0_id].decbus.prc==QuplsPkg::hexi) begin
					if (rob[alu0_id].v && alu0_id==(fpu0_id+ROB_ENTRIES-1)%ROB_ENTRIES) begin
			    	alu0_done <= TRUE;
				    alu0_idle1 <= TRUE;
				    alu0_idv <= INV;
				    rob[ alu0_id ].done <= 2'b11;
				    rob[ alu0_id ].out <= {INV,INV};
					end
				end
			end
			if (!rob[fpu0_id].excv)
	    	rob[ fpu0_id ].exc <= cause_code_t'(fpu0_exc[7:0]);
	    if (~&fpu0_exc)
	    	rob[ fpu0_id ].excv <= TRUE;
	//    rob[ fpu0_id ].out <= {INV,INV};
		end
	end

	if (NFPU > 1) begin
	  if (rob[fpu1_id].v && fpu1_idv && !rob[ fpu1_id ].decbus.multicycle) begin
`ifdef IS_SIM	    
	  	rob[fpu1_id].res <= fpu1_res;
`endif
	   	fpu1_done1 <= TRUE;
	    fpu1_idle <= TRUE;
	    rob[ fpu1_id ].exc <= cause_code_t'(fpu1_exc[7:0]);
	    rob[ fpu1_id ].excv <= ~&fpu1_exc[7:0];
			rob[ fpu1_id ].done[0] <= TRUE;
			rob[ fpu1_id ].out[0] <= FALSE;
			rob[ fpu1_id ].done[1] <= TRUE;
			rob[ fpu1_id ].out[1] <= FALSE;
			fpu1_idv <= INV;
		end
		else if (!fpu1_idle && rob[fpu1_id].v && fpu1_idv) begin
			if (fpu1_done) begin
				fpu1_idle <= TRUE;
				fpu1_idv <= INV;
		   	fpu1_done1 <= TRUE;
			end
	    rob[ fpu1_id ].exc <= fpu1_exc;
	    rob[ fpu1_id ].excv <= ~&fpu1_exc;
	    rob[ fpu1_id ].done[0] <= fpu1_done;
	    rob[ fpu1_id ].done[1] <= 1'b1;
	    rob[ fpu1_id ].out <= {INV,INV};
		end
	end
	
	if (fcu_setflags) begin
		fcu_v <= INV;
		fcu_v2 <= INV;
		fcu_v3 <= INV;
		if (fcu_v3) begin
			if (branch_state==BS_DONE2)
				fcu_idle <= TRUE;
		end
    rob[ fcu_id ].exc <= fcu_exc;
    rob[ fcu_id ].excv <= ~&fcu_exc;
    if (!rob[ fcu_id ].decbus.alu) begin
    	rob[ fcu_id ].done[0] <= VAL;
	    rob[ fcu_id ].out[0] <= INV;
    end
    rob[ fcu_id ].done[1] <= VAL;
    rob[ fcu_id ].out[1] <= INV;
    rob[ fcu_id ].takb <= takbr;	// could maybe just use takb
    fcu_idv <= INV;
//    fcu_bts <= BTS_NONE;
	end
	if (branch_state==BS_DONE2)
		fcu_idle <= TRUE;

	// If data for stomped instruction, ignore
	// dram_vn will be false for stomped data
	if (dram0_done && rob[ dram0_id ].v && dram0_idv) begin
    rob[ dram0_id ].exc <= dram_exc0;
    rob[ dram0_id ].excv <= ~&dram_exc0;
    rob[ dram0_id ].out <= {INV,INV};
    rob[ dram0_id ].done <= 2'b11;
		dram0_idv <= INV;
		$display("Q+ set dram0_idv=INV at done");
    tInvalidateLSQ(dram0_id,FALSE);
	end
	if (NDATA_PORTS > 1) begin
		if (dram1_done && rob[ dram1_id ].v && dram1_idv) begin
	    rob[ dram1_id ].exc <= dram_exc1;
	    rob[ dram1_id ].excv <= ~&dram_exc1;
	    rob[ dram1_id ].out <= {INV,INV};
	    rob[ dram1_id ].done <= 2'b11;
			dram1_idv <= INV;
	    tInvalidateLSQ(dram1_id,FALSE);
		end
	end
	// Store TLB translation in LSQ
	// If there is a TLB miss it could be a number of cycles before output
	// becomes valid.
	if (tlb0_v && agen0_idv)
		agen0_idle <= TRUE;
	if (tlb1_v && agen1_idv)
		agen0_idle <= TRUE;
	if (tlb0_v && rob[agen0_id].v && !rob[agen0_id].done[0] && rob[agen0_id].decbus.mem && agen0_idv) begin
		if (|pg_fault && pg_faultq==2'd1) begin
			agen0_idle <= TRUE;
			rob[agen0_id].exc <= FLT_PAGE;
			rob[agen0_id].excv <= TRUE;
			rob[agen0_id].done <= 2'b11;
			rob[agen0_id].out[0] <= 1'b0;
			agen0_idv <= INV;
		end
		if (rob[agen0_id].decbus.bstore) begin
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
			beb[0].decbus <= rob[agen0_id].decbus;
			beb[0].excv <= rob[agen0_id].excv;
			beb[0].argA <= agen0_argA;
			beb[0].argB <= agen0_argB;
			beb[0].argM <= agen0_argM;
			beb[0].pRc <= agen0_pRc;
			beb[0].argC_v <= rob[agen0_id].argC_v;
			beb[0].cndx <= rob[agen0_id].cndx;
			beb[0].done <= FALSE;
			*/
			agen0_idle <= TRUE;
			rob[agen0_id].done <= {VAL,VAL};
			rob[agen0_id].out[0] <= {INV,INV};
			agen0_idv <= INV;
		end
		if (rob[agen0_id].lsq) begin
			agen0_idle <= TRUE;
			rob[agen0_id].done[0] <= 1'b1;
			rob[agen0_id].out[0] <= 1'b0;
			agen0_idv <= INV;
			tSetLSQ(agen0_id, agen0_res, tlb0_res);
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

	if (NAGEN > 1) begin
		if (tlb1_v && !agen1_idle) begin
			if (|pg_fault && pg_faultq==2'd2) begin
				agen1_idle <= TRUE;
				rob[agen1_id].exc <= FLT_PAGE;
				rob[agen1_id].excv <= TRUE;
				rob[agen1_id].done <= 2'b11;
				rob[agen1_id].out[0] <= 1'b0;
				agen1_idv <= INV;
			end
			if (rob[agen1_id].lsq && !rob[agen1_id].done[0]) begin
				agen1_idle <= TRUE;
				rob[agen1_id].done[0] <= 1'b1;
				rob[agen1_id].out[0] <= 1'b0;
				agen1_idv <= INV;
				tSetLSQ(agen1_id, agen1_res, tlb1_res);
			end
		end
	end

	// Reservation stations - flags bits

	// Causes issues vvv
	// If the operation is not multi-cycle assume it will complete within one
	// clock cycle, in which case the ALU is still idle. This allows back-to-back
	// issue of ALU operations to the ALU.
	if (alu0_available && robentry_issue[alu0_rndx] && alu0_rndxv && alu0_idle) begin
		alu0_idle1 <= !rob[alu0_rndx].decbus.multicycle;	// Needs work yet.
		alu0_idv <= VAL;
		rob[alu0_rndx].arg <= rob[alu0_rndx].decbus.immc | rfo_alu0_argC;
    rob[alu0_rndx].out[0] <= VAL;
    rob[alu0_rndx].out[1] <= !(rob[alu0_rndx].decbus.fc && !rob[alu0_rndx].decbus.cjb);
	end

	if (NALU > 1) begin
		if (alu1_available && robentry_issue[alu1_rndx]&& alu1_rndxv && alu1_idle) begin
			alu1_idle1 <= !rob[alu1_rndx].decbus.multicycle;
			alu1_idv <= VAL;
	    rob[alu1_rndx].out[0] <= VAL;
	    rob[alu1_rndx].out[1] <= !(rob[alu1_rndx].decbus.fc && !rob[alu1_rndx].decbus.cjb);
		end
	end

	if (NFPU > 0) begin
		if (fpu0_available && robentry_fpu_issue[fpu0_rndx] && fpu0_rndxv && fpu0_idle) begin
			fpu0_idle <= !rob[fpu0_rndx].decbus.multicycle;
			fpu0_idv <= VAL;
	    rob[fpu0_rndx].out <= {VAL,VAL};
		end
	end

	if (NFPU > 1) begin
		if (fpu1_available && fpu1_rndxv && fpu1_idle) begin
			fpu1_idle <= !rob[fpu1_rndx].decbus.multicycle;
			fpu1_idv <= VAL;
	    rob[fpu1_rndx].out <= {VAL,VAL};
		end
	end

	fcu_idle <= TRUE;
	if (robentry_fcu_issue[fcu_rndx] && fcu_rndxv && fcu_idle && bs_idle_oh) begin
		fcu_idle <= FALSE;
		fcu_v <= VAL;
		fcu_idv <= VAL;
	  rob[fcu_rndx].out[1] <= VAL;
	  fcu_new <= TRUE;
	end

	if (brtgtv && bs_idle_oh) begin
		fcu_v <= VAL;
	end

	if (robentry_agen_issue[agen0_rndx] && agen0_rndxv && agen0_idle) begin
		agen0_idle <= FALSE;
		agen0_idv <= VAL;
	  rob[agen0_rndx].out[0] <= VAL;
	end

	if (NAGEN > 1) begin
		if (agen1_rndxv && agen1_idle) begin
			agen1_idle <= FALSE;
			agen1_idv <= VAL;
			/*
			store_argC_aReg <= rob[agen1_rndx].decbus.Rc;
			store_argC_pReg <= rob[agen1_rndx].pRc;
			store_argC_cndx <= rob[agen1_rndx].cndx;
			store_argC_v <= rob[agen1_rndx].argC_v;
			*/
	    rob[agen1_rndx].out[0] <= VAL;
		end
	end

	
	// Validate arguments

	for (nn = 0; nn < ROB_ENTRIES; nn = nn + 1) begin
		
		// ALU0
		tValidateArg(nn, wrport0_Rt, wrport0_v, wrport0_res);
	    
		// ALU1
		if (NALU > 1)
			tValidateArg(nn, wrport1_Rt, wrport1_v, wrport1_res);

		// DRAM0
		tValidateArg(nn, wrport2_Rt, wrport2_v, wrport2_res);

		// FPU0
		if (NFPU > 0)
			tValidateArg(nn, wrport3_Rt, wrport3_v, wrport3_res);

		// DRAM1
		if (NDATA_PORTS > 1)
			tValidateArg(nn, wrport4_Rt, wrport4_v, wrport4_res);

		// FPU1
		if (NFPU > 1)
			tValidateArg(nn, wrport5_Rt, wrport5_v, wrport5_res);
	end
	
	// Move pending to real.	
	for (nn = 0; nn < ROB_ENTRIES; nn = nn + 1) begin
		if (rob[nn].argA_vp) begin
			rob[nn].argA_v <= VAL;
			tAllArgsValid(nn, VAL, INV, INV, INV, INV);
			rob[nn].argA_vp <= INV;
		end
		if (rob[nn].argB_vp) begin
			rob[nn].argB_v <= VAL;
			tAllArgsValid(nn, INV, VAL, INV, INV, INV);
			rob[nn].argB_vp <= INV;
		end
		if (rob[nn].argC_vp) begin
			rob[nn].argC_v <= VAL;
			tAllArgsValid(nn, INV, INV, VAL, INV, INV);
			rob[nn].argC_vp <= INV;
		end
		if (rob[nn].argT_vp) begin
			rob[nn].argT_v <= VAL;
			tAllArgsValid(nn, INV, INV, INV, VAL, INV);
			rob[nn].argT_vp <= INV;
		end
		if (rob[nn].argM_vp) begin
			rob[nn].argM_v <= VAL;
			tAllArgsValid(nn, INV, INV, INV, INV, VAL);
			rob[nn].argM_vp <= INV;
		end
	end
	
	// Set LSQ register C, it may be waiting for data

  for (n3 = 0; n3 < LSQ_ENTRIES; n3 = n3 + 1) begin
  	for (n12 = 0; n12 < NDATA_PORTS; n12 = n12 + 1) begin
	  	if (lsq[n3][n12].v==VAL && lsq[n3][n12].datav==INV && lsq[n3][n12].store) begin
	  		/*
	  		if (prnv[23]==VAL) begin
	  			$display("Q+ CPU: LSQ bypass from regfile=%h r%d", rfo_store_argC, store_argC_pReg);
	  			lsq[n3][n12].datav <= VAL;
	  			lsq[n3][n12].res <= rfo_store_argC;
	  			lsq[n3][n12].ctag <= rfo_store_argC_ctag;
	  		end
	  		*/
	  		// Make the store data value available one cycle earlier than can be 
	  		// read from the register file.
	  		if (PERFORMANCE) begin
		  		if (lsq[n3][n12].pRc==wrport0_Rt && wrport0_v==VAL) begin
		  			$display("Q+ CPU: LSQ bypass from ALU0=%h r%d", alu0_res, wrport0_Rt);
		  			lsq[n3][n12].datav <= VAL;
		  			lsq[n3][n12].res <= alu0_res;
		  			lsq[n3][n12].ctag <= 1'b0;
		  		end
		  		if (NALU > 1 && lsq[n3][n12].pRc==wrport1_Rt && wrport1_v==VAL) begin
		  			$display("Q+ CPU: LSQ bypass from ALU1=%h r%d", alu1_res, wrport1_Rt);
		  			lsq[n3][n12].datav <= VAL;
		  			lsq[n3][n12].res <= alu1_res;
		  			lsq[n3][n12].ctag <= 1'b0;
		  		end
		  		if (lsq[n3][n12].pRc==wrport2_Rt && wrport2_v==VAL) begin
		  			$display("Q+ CPU: LSQ bypass from MEM0=%h r%d", dram_bus0, wrport2_Rt);
		  			lsq[n3][n12].datav <= VAL;
		  			lsq[n3][n12].res <= dram_bus0;
		  			lsq[n3][n12].ctag <= dram_ctag0;
		  		end
		  		if (NFPU > 0 && lsq[n3][n12].pRc==wrport3_Rt && wrport3_v==VAL) begin
		  			$display("Q+ CPU: LSQ bypass from FPU0=%h r%d", fpu0_res, wrport3_Rt);
		  			lsq[n3][n12].datav <= VAL;
		  			lsq[n3][n12].res <= fpu0_res;
		  			lsq[n3][n12].ctag <= fpu0_ctag;
		  		end
		  		if (NDATA_PORTS > 1 && lsq[n3][n12].pRc==wrport4_Rt && wrport4_v==VAL) begin
		  			lsq[n3][n12].datav <= VAL;
		  			lsq[n3][n12].res <= dram_bus1;
		  			lsq[n3][n12].ctag <= dram_ctag1;
		  		end
		  		if (NFPU > 1 && lsq[n3][n12].pRc==wrport5_Rt && wrport5_v==VAL) begin
		  			lsq[n3][n12].datav <= VAL;
		  			lsq[n3][n12].res <= fpu1_res;
		  			lsq[n3][n12].ctag <= 1'b0;
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
	if (dram0_done) begin
		dram0_load <= FALSE;
		dram0_loadz <= FALSE;
		dram0_cload <= FALSE;
	end
	if (NDATA_PORTS > 1) begin
		if (dram1_done) begin
			dram1_load <= FALSE;
			dram1_loadz <= FALSE;
			dram1_cload <= FALSE;
		end
	end

	// Bus timeout logic.
	// If the memory access has taken too long, then it is retried. This applies
	// mainly to loads as stores will ack right away. Bit 8 of the counter is
	// used to indicate a retry so 256 clocks need to pass. Four retries are
	// allowed for by testing bit 10 of the counter. If the bus still has not
	// responded after 1024 clock cycles then a bus error exception is noted.

	if (SUPPORT_BUS_TO) begin
		// Increment timeout counters while memory access is taking place.
		if (dram0==DRAMSLOT_ACTIVE)
			dram0_tocnt <= dram0_tocnt + 2'd1;

		if (NDATA_PORTS > 1) begin
			if (dram1==DRAMSLOT_ACTIVE)
				dram1_tocnt <= dram1_tocnt + 2'd1;
		end
	
	// Bus timeout logic
	// Reset out to trigger another access
		if (dram0_tocnt[10]) begin
			if (!rob[dram0_id].excv) begin
				rob[dram0_id].exc <= FLT_BERR;
				rob[dram0_id].excv <= TRUE;
			end
			rob[dram0_id].done <= 2'b11;
			rob[dram0_id].out <= {INV,INV};
			dram0_idv <= INV;
			$display("Q+ set dram0_idv=INV at timeout");
			tInvalidateLSQ(dram0_id,TRUE);
			//lsq[rob[dram0_id].lsqndx.row][rob[dram0_id].lsqndx.col].v <= INV;
			dram0_tocnt <= 12'd0;
		end
		else if (dram0_tocnt[8]) begin
			rob[dram0_id].out <= {INV,INV};
		end
		if (NDATA_PORTS > 1) begin
			if (dram1_tocnt[10]) begin
				if (!rob[dram1_id].excv) begin
					rob[dram1_id].exc <= FLT_BERR;
					rob[dram1_id].excv <= TRUE;
				end
				rob[dram1_id].done <= 2'b11;
				rob[dram1_id].out <= {INV,INV};
				dram1_idv <= INV;
				tInvalidateLSQ(dram1_id,TRUE);
//				lsq[rob[dram1_id].lsqndx.row][rob[dram1_id].lsqndx.col].v <= INV;
				dram1_tocnt <= 12'd0;
			end
			else if (dram1_tocnt[8]) begin
				rob[dram1_id].out <= {INV,INV};
			end
		end
	end

	// grab requests that have finished and put them on the dram_bus
	if (dram0 == DRAMSLOT_ACTIVE && dram0_ack && dram0_hi && SUPPORT_UNALIGNED_MEMORY) begin
		dram0_hi <= 1'b0;
    dram_v0 <= (dram0_load|dram0_cload|dram0_cload_tags) & ~dram0_stomp;
    dram_id0 <= dram0_id;
    dram_Rt0 <= dram0_Rt;
    dram_aRt0 <= dram0_aRt;
    dram_aRtz0 <= dram0_aRtz;
    dram_exc0 <= dram0_exc;
  	dram_bus0 <= fnDati(1'b0,dram0_op,(cpu_resp_o[0].dat << dram0_shift)|dram_bus0, dram0_pc);
  	dram_ctag0 <= dram0_ctag;
    if (dram0_store) begin
    	dram0_store <= 1'd0;
    	dram0_sel <= 80'd0;
  	end
    if (dram0_cstore) begin
    	dram0_cstore <= 1'd0;
    	dram0_sel <= 80'd0;
  	end
    if (dram0_store)
    	$display("m[%h] <- %h", dram0_vaddr, dram0_data);
	end
	else if (dram0 == DRAMSLOT_ACTIVE && dram0_ack) begin
		// If there is more to do, trigger a second instruction issue.
		if (dram0_more && !dram0_stomp)
			rob[dram0_id].out <= {INV,INV};
    dram_v0 <= (dram0_load|dram0_cload|dram0_cload_tags) & ~dram0_more & ~dram0_stomp;
    dram_id0 <= dram0_id;
    dram_Rt0 <= dram0_Rt;
    dram_aRt0 <= dram0_aRt;
    dram_aRtz0 <= dram0_aRtz;
    dram_exc0 <= dram0_exc;
  	dram_bus0 <= fnDati(dram0_more,dram0_op,cpu_resp_o[0].dat >> dram0_shift, dram0_pc);
    if (dram0_store) begin
    	dram0_store <= 1'd0;
    	dram0_sel <= 80'd0;
  	end
    if (dram0_cstore) begin
    	dram0_cstore <= 1'd0;
    	dram0_sel <= 80'd0;
  	end
    if (dram0_store)
    	$display("m[%h] <- %h", dram0_vaddr, dram0_data);
	end
	else
		dram_v0 <= INV;

	if (NDATA_PORTS > 1) begin
		if (dram1 == DRAMSLOT_ACTIVE && dram1_ack && dram1_hi && SUPPORT_UNALIGNED_MEMORY) begin
			dram1_hi <= 1'b0;
	    dram_v1 <= (dram1_load|dram1_cload|dram1_cload_tags) & ~dram1_stomp;
	    dram_id1 <= dram1_id;
	    dram_Rt1 <= dram1_Rt;
	    dram_aRt1 <= dram1_aRt;
	    dram_aRtz1 <= dram1_aRtz;
	    dram_exc1 <= dram1_exc;
    	dram_bus1 <= fnDati(1'b0,dram1_op,(cpu_resp_o[1].dat << dram1_shift)|dram_bus1, dram1_pc);
    	dram_ctag1 <= dram1_ctag;
	    if (dram1_store) begin
	    	dram1_store <= 1'b0;
	    	dram1_sel <= 80'd0;
	  	end
	    if (dram1_store)
	     	$display("m[%h] <- %h", dram1_vaddr, dram1_data);
		end
		else if (dram1 == DRAMSLOT_ACTIVE && dram1_ack) begin
			// If there is more to do, trigger a second instruction issue.
			if (dram1_more && !dram1_stomp)
				rob[dram1_id].out <= {INV,INV};
	    dram_v1 <= (dram1_load|dram1_cload|dram1_cload_tags) & ~dram1_more & ~dram1_stomp;
	    dram_id1 <= dram1_id;
	    dram_Rt1 <= dram1_Rt;
	    dram_aRt1 <= dram1_aRt;
	    dram_aRtz1 <= dram1_aRtz;
	    dram_exc1 <= dram1_exc;
    	dram_bus1 <= fnDati(dram1_more,dram1_op,cpu_resp_o[1].dat >> dram1_shift, dram1_pc);
	    if (dram1_store) begin
	    	dram1_store <= 1'b0;
	    	dram1_sel <= 80'd0;
	  	end
	    if (dram1_store)
	     	$display("m[%h] <- %h", dram1_vaddr, dram1_data);
		end
		else
			dram_v1 <= INV;
	end

	// Take requests that are ready and put them into DRAM slots


	// For unaligned accesses the instruction will issue again. Unfortunately
	// the address will be calculated again in the ALU, and it will be incorrect
	// as it would be using the previous address in the calc. Fortunately the
	// correct address is already available for the second bus cycle in the
	// dramN_addr var. We can tell when to use it by the setting of the more
	// flag.
	if (SUPPORT_LOAD_BYPASSING && lbndx0 > 0) begin
		dram_bus0 <= fnDati(1'b0,dram0_op,lsq[lbndx0.row][lbndx0.col].res,dram0_pc);
		dram_ctag0 <= lsq[lbndx0.row][lbndx0.col].ctag;
		dram_Rt0 <= lsq[lbndx0.row][lbndx0.col].Rt;
		dram_v0 <= lsq[lbndx0.row][lbndx0.col].v;
		lsq[lbndx0.row][lbndx0.col].v <= INV;
		rob[lsq[lbndx0.row][lbndx0.col].rndx].done <= 2'b11;
	end
  else if (dram0 == DRAMSLOT_AVAIL && mem0_lsndxv && !robentry_stomp[lsq[mem0_lsndx.row][mem0_lsndx.col].rndx] && !dram0_idv && !dram0_idv2) begin
		dram0_exc <= FLT_NONE;
		dram0_stomp <= 1'b0;
		dram0_id <= lsq[mem0_lsndx.row][mem0_lsndx.col].rndx;
		dram0_idv <= VAL;
		dram0_op <= lsq[mem0_lsndx.row][mem0_lsndx.col].op;
		dram0_ldip <= rob[lsq[mem0_lsndx.row][mem0_lsndx.col].rndx].excv;
		dram0_pc <= lsq[mem0_lsndx.row][mem0_lsndx.col].pc;
		dram0_load <= lsq[mem0_lsndx.row][mem0_lsndx.col].load;
		dram0_loadz <= lsq[mem0_lsndx.row][mem0_lsndx.col].loadz;
		dram0_cload <= lsq[mem0_lsndx.row][mem0_lsndx.col].cload;
		dram0_cload_tags <= lsq[mem0_lsndx.row][mem0_lsndx.col].cload_tags;
		dram0_store <= lsq[mem0_lsndx.row][mem0_lsndx.col].store;
		dram0_cstore <= lsq[mem0_lsndx.row][mem0_lsndx.col].cstore;
		dram0_erc <= rob[lsq[mem0_lsndx.row][mem0_lsndx.col].rndx].decbus.erc;
		dram0_Rt	<= lsq[mem0_lsndx.row][mem0_lsndx.col].Rt;
		dram0_aRt	<= lsq[mem0_lsndx.row][mem0_lsndx.col].aRt;
		dram0_aRtz <= lsq[mem0_lsndx.row][mem0_lsndx.col].aRtz;
		dram0_bank <= lsq[mem0_lsndx.row][mem0_lsndx.col].om==2'd0 ? 1'b0 : 1'b1;
		dram0_cp <= rob[lsq[mem0_lsndx.row][mem0_lsndx.col].rndx].cndx;
		if (dram0_more && SUPPORT_UNALIGNED_MEMORY) begin
			dram0_hi <= 1'b1;
			dram0_sel <= dram0_selh >> 8'd64;
			dram0_vaddr <= {dram0_vaddrh[$bits(virtual_address_t)-1:6] + 2'd1,6'h0};
			dram0_paddr <= {dram0_paddrh[$bits(physical_address_t)-1:6] + 2'd1,6'h0};
			dram0_data <= dram0_datah >> 12'd512;
			dram0_shift <= {7'd64-dram0_paddrh[5:0],3'b0};
		end
		else begin
			dram0_hi <= 1'b0;
			dram0_sel <= {64'h0,fnSel(rob[lsq[mem0_lsndx.row][mem0_lsndx.col].rndx].op)} << lsq[mem0_lsndx.row][mem0_lsndx.col].padr[5:0];
			dram0_selh <= {64'h0,fnSel(rob[lsq[mem0_lsndx.row][mem0_lsndx.col].rndx].op)} << lsq[mem0_lsndx.row][mem0_lsndx.col].padr[5:0];
			dram0_vaddr <= lsq[mem0_lsndx.row][mem0_lsndx.col].vadr;
			dram0_paddr <= lsq[mem0_lsndx.row][mem0_lsndx.col].padr;
			dram0_vaddrh <= lsq[mem0_lsndx.row][mem0_lsndx.col].vadr;
			dram0_paddrh <= lsq[mem0_lsndx.row][mem0_lsndx.col].padr;
			dram0_data <= lsq[mem0_lsndx.row][mem0_lsndx.col].res << {lsq[mem0_lsndx.row][mem0_lsndx.col].padr[5:0],3'b0};
			dram0_datah <= lsq[mem0_lsndx.row][mem0_lsndx.col].res << {lsq[mem0_lsndx.row][mem0_lsndx.col].padr[5:0],3'b0};
			dram0_ctago <= lsq[mem0_lsndx.row][mem0_lsndx.col].ctag;
			dram0_shift <= {lsq[mem0_lsndx.row][mem0_lsndx.col].padr[5:0],3'd0};
		end
		dram0_memsz <= fnMemsz(rob[lsq[mem0_lsndx.row][mem0_lsndx.col].rndx].op);
		dram0_tid.core <= CORENO;
		dram0_tid.channel <= 3'd1;
		dram0_tid.tranid <= dram0_tid.tranid + 2'd1;
		rob[lsq[mem0_lsndx.row][mem0_lsndx.col].rndx].out <= {VAL,VAL};
    dram0_tocnt <= 12'd0;
  end

  if (NDATA_PORTS > 1) begin
		if (SUPPORT_LOAD_BYPASSING && lbndx1 > 0) begin
			dram_bus1 <= fnDati(1'b0,dram1_op,lsq[lbndx1.row][lbndx1.col].res,dram1_pc);
			dram_Rt1 <= lsq[lbndx1.row][lbndx1.col].Rt;
			dram_v1 <= lsq[lbndx1.row][lbndx1.col].v;
			lsq[lbndx1.row][lbndx1.col].v <= INV;
			rob[lsq[lbndx1.row][lbndx1.col].rndx].done <= 2'b11;
		end
	  else if (dram1 == DRAMSLOT_AVAIL && NDATA_PORTS > 1 && mem1_lsndxv && !robentry_stomp[lsq[mem1_lsndx.row][mem1_lsndx.col].rndx]) begin
			dram1_exc <= FLT_NONE;
			dram1_stomp <= 1'b0;
			dram1_id <= lsq[mem1_lsndx.row][mem1_lsndx.col].rndx;
			dram1_idv <= VAL;
			dram1_op <= lsq[mem1_lsndx.row][mem1_lsndx.col].op;
			dram1_pc <= lsq[mem1_lsndx.row][mem1_lsndx.col].pc;
			dram1_load <= lsq[mem1_lsndx.row][mem1_lsndx.col].load;
			dram1_loadz <= lsq[mem1_lsndx.row][mem1_lsndx.col].loadz;
			dram1_cload <= lsq[mem1_lsndx.row][mem1_lsndx.col].cload;
			dram1_cload_tags <= lsq[mem1_lsndx.row][mem1_lsndx.col].cload_tags;
			dram1_store <= lsq[mem1_lsndx.row][mem1_lsndx.col].store;
			dram1_cstore <= lsq[mem1_lsndx.row][mem1_lsndx.col].cstore;
			dram1_erc <= rob[lsq[mem1_lsndx.row][mem1_lsndx.col].rndx].decbus.erc;
			dram1_Rt <= lsq[mem1_lsndx.row][mem1_lsndx.col].Rt;
			dram1_aRt	<= lsq[mem1_lsndx.row][mem1_lsndx.col].aRt;
			dram1_aRtz <= lsq[mem1_lsndx.row][mem1_lsndx.col].aRtz;
			dram1_bank <= lsq[mem1_lsndx.row][mem1_lsndx.col].om==2'd0 ? 1'b0 : 1'b1;
			dram1_cp <= rob[lsq[mem1_lsndx.row][mem1_lsndx.col].rndx].cndx;
			if (dram1_more && SUPPORT_UNALIGNED_MEMORY) begin
				dram1_hi <= 1'b1;
				dram1_sel <= dram1_selh >> 8'd64;
				dram1_vaddr <= {dram1_vaddrh[$bits(virtual_address_t)-1:6] + 2'd1,6'h0};
				dram1_paddr <= {dram1_paddrh[$bits(physical_address_t)-1:6] + 2'd1,6'h0};
				dram1_data <= dram1_datah >> 12'd512;
				dram1_shift <= {7'd64-dram1_paddrh[5:0],3'b0};
			end
			else begin
				dram1_hi <= 1'b0;
				dram1_sel <= {64'h0,fnSel(lsq[mem1_lsndx.row][mem1_lsndx.col].op)} << lsq[mem1_lsndx.row][mem1_lsndx.col].padr[5:0];
				dram1_selh <= {64'h0,fnSel(lsq[mem1_lsndx.row][mem1_lsndx.col].op)} << lsq[mem1_lsndx.row][mem1_lsndx.col].padr[5:0];
				dram1_vaddr	<= lsq[mem1_lsndx.row][mem1_lsndx.col].vadr;
				dram1_paddr	<= lsq[mem1_lsndx.row][mem1_lsndx.col].padr;
				dram1_vaddrh	<= lsq[mem1_lsndx.row][mem1_lsndx.col].vadr;
				dram1_paddrh	<= lsq[mem1_lsndx.row][mem1_lsndx.col].padr;
				dram1_data	<= lsq[mem1_lsndx.row][mem1_lsndx.col].res << {lsq[mem1_lsndx.row][mem1_lsndx.col].padr[5:0],3'b0};
				dram1_datah	<= lsq[mem1_lsndx.row][mem1_lsndx.col].res << {lsq[mem1_lsndx.row][mem1_lsndx.col].padr[5:0],3'b0};
				dram1_ctago <= lsq[mem1_lsndx.row][mem1_lsndx.col].ctag;
				dram1_shift <= {lsq[mem1_lsndx.row][mem1_lsndx.col].padr[5:0],3'd0};
			end
			dram1_memsz <= fnMemsz(lsq[mem1_lsndx.row][mem1_lsndx.col].op);
			dram1_tid.core <= CORENO;
			dram1_tid.channel <= 3'd2;
			dram1_tid.tranid <= dram1_tid.tranid + 2'd1;
			rob[lsq[mem1_lsndx.row][mem1_lsndx.col].rndx].out	<= {VAL,VAL};
	    dram1_tocnt <= 12'd0;
	  end
	end
 
  for (n3 = 0; n3 < ROB_ENTRIES; n3 = n3 + 1) begin
		if (robentry_stomp[n3] && rob[n3].lsqndx==mem0_lsndx && lsq[mem0_lsndx.row][mem0_lsndx.col].v)
			dram0_stomp <= 1'b1;
		if (!rob[n3].lsq && dram0_id==n3 && dram0_idv) begin
			dram0_stomp <= TRUE;
			dram0_idv <= INV;
		end
		if (NDATA_PORTS > 1) begin
			if (robentry_stomp[n3] && rob[n3].lsqndx==mem1_lsndx && lsq[mem1_lsndx.row][mem1_lsndx.col].v)
				dram1_stomp <= 1'b1;
			if (!rob[n3].lsq && dram1_id==n3 && dram1_idv) begin
				dram1_stomp <= TRUE;
				dram1_idv <= INV;
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

	if (!htcolls) begin
		commit0_id <= head0;
		commit1_id <= head1;
		commit2_id <= head2;
		commit3_id <= head3;
		commit0_idv <= cmttlb0;
		commit1_idv <= cmttlb1;
		commit2_idv <= cmttlb2;
		commit3_idv <= cmttlb3;
	end
	if (do_commit) begin
		commit_pc0 <= rob[head0].pc;
		commit_pc1 <= rob[head1].pc;
		commit_pc2 <= rob[head2].pc;
		commit_pc3 <= rob[head3].pc;
		commit_brtgt0 <= rob[head0].brtgt;
		commit_brtgt1 <= rob[head1].brtgt;
		commit_brtgt2 <= rob[head2].brtgt;
		commit_brtgt3 <= rob[head3].brtgt;
		commit_takb0 <= rob[head0].takb & rob[head0].decbus.br;
		commit_takb1 <= rob[head1].takb & rob[head1].decbus.br;
		commit_takb2 <= rob[head2].takb & rob[head2].decbus.br;
		commit_takb3 <= rob[head3].takb & rob[head3].decbus.br;
		commit_br0 <= rob[head0].decbus.br;
		commit_br1 <= rob[head1].decbus.br && cmtcnt > 3'd1;
		commit_br2 <= rob[head2].decbus.br && cmtcnt > 3'd2;
		commit_br3 <= rob[head3].decbus.br && cmtcnt > 3'd3;
		if (SUPPORT_IBH) begin
			commit_grp0 <= rob[head0].grp;
			commit_grp1 <= rob[head1].grp;
			commit_grp2 <= rob[head2].grp;
			commit_grp3 <= rob[head3].grp;
		end
		group_len <= group_len - 1;
		tInvalidateQE(head0);
		if (cmtcnt > 3'd1) begin
			tInvalidateQE(head1);
			group_len <= group_len - 2;
		end
		if (cmtcnt > 3'd2) begin
			tInvalidateQE(head2);
			group_len <= group_len - 3;
		end
		if (cmtcnt > 3'd3) begin
			tInvalidateQE(head3);
			group_len <= group_len - 4;
		end
		if (cmtcnt > 3'd4) begin
			tInvalidateQE(head4);
			group_len <= group_len - 5;
		end
		if (cmtcnt > 3'd5) begin
			tInvalidateQE(head5);
			group_len <= group_len - 6;
		end
		head0 <= (head0 + cmtcnt) % ROB_ENTRIES;	
//		head0 <= (head0 + 3'd4) % ROB_ENTRIES;	
		if (group_len <= 0)
			group_len <= rob[head0].group_len;
		// Commit oddball instructions
		if ((rob[head0].decbus.oddball && !rob[head0].excv) || rob[head0].op.hwi)
			tOddballCommit(rob[head0].v, head0);
		else if ((rob[head1].decbus.oddball && !rob[head1].excv && cmtcnt > 3'd1) || rob[head1].op.hwi)
			tOddballCommit(rob[head1].v, head1);
		else if ((rob[head2].decbus.oddball && !rob[head2].excv && cmtcnt > 3'd2) || rob[head2].op.hwi)
			tOddballCommit(rob[head2].v, head2);
		else if ((rob[head3].decbus.oddball && !rob[head3].excv && cmtcnt > 3'd3) || rob[head3].op.hwi)
			tOddballCommit(rob[head3].v, head3);
		// Trigger exception processing for last instruction in group.
		if (rob[head0].excv && rob[head0].v)
//			err_mask[head0] <= 1'b1;
//			if (rob[head0].last)
			tProcessExc(head0,rob[head0].pc,FALSE,FALSE);
		else if (rob[head1].excv && cmtcnt > 3'd1 && rob[head1].v)
			tProcessExc(head1,rob[head1].pc,FALSE,FALSE);
		else if (rob[head2].excv && cmtcnt > 3'd2 && rob[head2].v)
			tProcessExc(head2,rob[head2].pc,FALSE,FALSE);
		else if (rob[head3].excv && cmtcnt > 3'd3 && rob[head3].v)
			tProcessExc(head3,rob[head3].pc,FALSE,FALSE);
			
		if (rob[head0].op.ssm)
			tProcessExc(head0,SSM_DEBUG ? rob[head0].pc : rob[head0].op.hwipc,FALSE,FALSE);

		/*
		if (FALSE) begin
			if (rob[head0].decbus.sync)
				tZeroSyncDep(rob[head0].sync_no);
			if (rob[head1].decbus.sync)
				tZeroSyncDep(rob[head1].sync_no);
			if (rob[head2].decbus.sync)
				tZeroSyncDep(rob[head2].sync_no);
			if (rob[head3].decbus.sync)
				tZeroSyncDep(rob[head3].sync_no);
			if (rob[head0].decbus.fc)
				tZeroFcDep(rob[head0].fc_no);
			if (rob[head1].decbus.fc)
				tZeroFcDep(rob[head1].fc_no);
			if (rob[head2].decbus.fc)
				tZeroFcDep(rob[head2].fc_no);
			if (rob[head3].decbus.fc)
				tZeroFcDep(rob[head3].fc_no);
		end
		*/
	end
	// ToDo: fix LSQ head update.
	if (lsq[lsq_head.row][lsq_head.col].v==INV && lsq_head != lsq_tail)
		lsq_head.row <= lsq_head.row + 1;

	if (SUPPORT_QUAD_PRECISION) begin
		tCheckQFExtDone(head0);	
		tCheckQFExtDone(head1);	
		tCheckQFExtDone(head2);	
		tCheckQFExtDone(head3);	
	end
	
	// There is a bypassing issue in the RAT, where a register is being marked
	// valid at the same time an instruction is queuing that uses the register.
	// The fact the register is going to be valid gets missed, then the
	// instruction hangs the machine waiting for the argument to become valid.
	// So, for now, if an instruction makes it to the commit stage and there
	// seems to be no way for its arguments to be marked valid, then the args
	// are marked valid here. It prevents the machine from locking up.
	begin
		for (nn = 0; nn < ROB_ENTRIES; nn = nn + 1) begin
			if (rob[head0].v) begin
				if (!rob[head0].argA_v && !fnFindSource(head0, rob[head0].decbus.Ra)) begin
					rob[head0].argA_v <= VAL;
					tAllArgsValid(head0, VAL, INV, INV, INV, INV);
					$display("Q+: rob[%d]: argument A not possible to validate.", head0);
				end		
				if (!rob[head0].argB_v && !fnFindSource(head0, rob[head0].decbus.Rb)) begin
					$display("Q+: rob[%d]: argument B not possible to validate.", head0);
					rob[head0].argB_v <= VAL;
					tAllArgsValid(head0, INV, VAL, INV, INV, INV);
				end		
				if (!rob[head0].argC_v && !fnFindSource(head0, rob[head0].decbus.Rc)) begin
					$display("Q+: rob[%d]: argument C not possible to validate.", head0);
					rob[head0].argC_v <= VAL;
					tAllArgsValid(head0, INV, INV, VAL, INV, INV);
				end		
				if (!rob[head0].argT_v) begin
					if (!fnFindSource(head0, rob[head0].decbus.Rt)) begin
						$display("Q+: rob[%d]: argument T not possible to validate.", head0);
						rob[head0].argT_v <= VAL;
						tAllArgsValid(head0, INV, INV, INV, VAL, INV);
					end
					/*
					else begin
						if (fnSourceValid(head0, rob[head0].decbus.Rt) begin
							rob[head0].argT_v <= VAL;
							tAllArgsValid(head0, INV, INV, INV, VAL, INV);
						end
					end
					*/
				end
				if (!rob[head0].argM_v && !fnFindSource(head0, rob[head0].decbus.Rm)) begin
					$display("Q+: rob[%d]: argument M not possible to validate.", head0);
					rob[head0].argM_v <= VAL;
					tAllArgsValid(head0, INV, INV, INV, INV, VAL);
				end		
			end
		end
	end
	
	// Set the predicate bits for an instruction. The instruction must be queued
	// already. An instruction is queued with its predicate bits set FALSE. If
	// there is no prior predicate then the flag is automatically set TRUE.
	begin
		for (nn = 0; nn < ROB_ENTRIES; nn = nn + 1) begin
			if (!rob[nn].pred_bitv && !fnHasPred(nn)) begin
				rob[nn].pred_bitv <= TRUE;
				rob[nn].pred_bits <= 8'hFF;
 			end
			if (rob[nn].v && rob[nn].decbus.pred && rob[nn].done==2'b11) begin
				for (mm = 0; mm < ROB_ENTRIES; mm = mm + 1) begin
					if (rob[mm].v 
					&& rob[mm].predrndx == nn
//					&& fnPredPCMatch(rob[nn].pc[7:0], rob[mm].pc[7:0])
					&& !rob[mm].pred_bitv
//					&& !rob[mm].decbus.vec
					) begin
						rob[mm].pred_bits <= fnPredSet(rob[mm].predino,rob[mm].decbus.vec2,rob[nn],rob[mm]);
						rob[mm].pred_bitv <= TRUE;
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
	begin
		for (nn = 0; nn < ROB_ENTRIES; nn = nn + 1) begin
			if (fnStuckOut(nn))
				rob[nn].out <= 2'b00;
		end
	end

	// For some reason, agen_idle gets stuck FALSE. It should only be false if
	// there is a memory operation 'out'.	If there are no 'out' rob entries then
	// agen_idle should be true.
	/*
	if (!anyout0) begin
		agen0_idle <= TRUE;
		agen0_idv <= INV;
		if (dram0_id==agen0_id)
			dram0_stomp <= TRUE;
		if (NDATA_PORTS > 1) begin
			agen1_idle <= TRUE;
			agen1_idv <= INV;
			if (dram1_id==agen1_id)
				dram1_stomp <= TRUE;
		end
	end
	*/

	// Unstick:
	// If the same physical register is valid in a later instruction, then it should
	// be valid for the earlier one. Sometimes the core is not marking a register valid
	// when it should, this causes the core to hang. ToDo: fix this issue and remove
	// the following code.
	/*
	for (nn = 0; nn < ROB_ENTRIES; nn = nn + 1) begin
		if (rob[nn].argA_v && rob[nn].pRa==rob[head0].pRa && rob[nn].sn > rob[head0].sn)
			rob[head0].argA_v <= VAL;
		if (rob[nn].argB_v && rob[nn].pRa==rob[head0].pRa && rob[nn].sn > rob[head0].sn)
			rob[head0].argB_v <= VAL;
		if (rob[nn].argC_v && rob[nn].pRa==rob[head0].pRa && rob[nn].sn > rob[head0].sn)
			rob[head0].argC_v <= VAL;
		if (rob[nn].argT_v && rob[nn].pRa==rob[head0].pRa && rob[nn].sn > rob[head0].sn)
			rob[head0].argT_v <= VAL;
		if (rob[nn].argM_v && rob[nn].pRa==rob[head0].pRa && rob[nn].sn > rob[head0].sn)
			rob[head0].argM_v <= VAL;
	end
	*/
	// Branchmiss stomping
	// Mark functional units stomped on idle.
	// Invalidate instructions newer than the branch in the ROB.
	// Free up load / store queue entries.
	// Set the stomp flag to update the RAT marking the register valid.
	/*
	if (robentry_stomp[alu0_id] || !rob[alu0_id].v) begin
		alu0_idle <= TRUE;
		alu0_stomp <= TRUE;
	end
	if (robentry_stomp[alu1_id] || !rob[alu1_id].v) begin
		alu1_idle <= TRUE;
		alu1_stomp <= TRUE;
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
	if (robentry_stomp[dram0_id]) begin
		dram0_stomp <= TRUE;
		dram0_idv <= INV;
		rob[dram0_id].done <= 2'b11;
		rob[dram0_id].out <= 2'b00;
	end
	if (robentry_stomp[dram1_id]) begin
		dram1_stomp <= TRUE;
		dram1_idv <= INV;
		rob[dram1_id].done <= 2'b11;
		rob[dram1_id].out <= 2'b00;
	end
	/*
	if (robentry_stomp[agen0_id]) begin// || !rob[agen0_id].v) begin
		agen0_idle <= TRUE;
		agen0_idv <= INV;
		if (dram0_id==agen0_id)
			dram0_stomp <= TRUE;
	end
	if (NDATA_PORTS > 1) begin
		if (robentry_stomp[agen1_id]) begin// || !rob[agen1_id].v) begin
			agen1_idle <= TRUE;
			agen1_idv <= INV;
			if (dram1_id==agen1_id)
				dram1_stomp <= TRUE;
		end
	end
	*/
	// Terminate FCU operation on stomp.
	if (robentry_stomp[fcu_id] & fcu_idv) begin
		fcu_v <= INV;
		fcu_v2 <= INV;
		fcu_v3 <= INV;
		fcu_idle <= TRUE;
		fcu_idv <= INV;
	end

	// Redo instruction as copy target.
	// Invalidate false paths.
	if (free_chkpt)
		rob[chkpt_rndx].chkpt_freed <= TRUE;
	for (n3 = 0; n3 < ROB_ENTRIES; n3 = n3 + 1) begin
		if (robentry_stomp[n3]|robentry_cpytgt[n3])	// || bno_bitmap[rob[n3].pc.bno_t]==1'b0)
			tBranchInvalidate(n3,robentry_cpytgt[n3]);
	end

	// This bit to aid the scheduler. There are a lot of bits that must be true
	// before an instruction can issue. These are pre-computed here to reduce the
	// logic levels in the scheduler. It does add a cycle or two of latency, but 
	// is likely done before the instruction comes into consideration by the
	// scheduler. The latency is hidden.
	begin : gSchedPrecalc
		for (n3 = 0; n3 < ROB_ENTRIES; n3 = n3 + 1) begin
			if (rob[n3].v) begin
				if (!fnPriorSync(n3))
					rob[n3].prior_sync <= FALSE; 
				if (!fnPriorFC(n3))
					rob[n3].prior_fc <= FALSE;
			end
		end

		for (n3 = 0; n3 < ROB_ENTRIES; n3 = n3 + 1) begin
			rob[n3].could_issue <=
					rob[n3].v
				&& !robentry_stomp[n3]
				&& !(&rob[n3].done)
				&& (rob[n3].decbus.cpytgt ? (rob[n3].argT_v /*|| rob[g].op.nRt==9'd0*/) : rob[n3].all_args_valid)
				&& (rob[n3].decbus.mem ? !rob[n3].prior_fc : 1'b1)
				&& (SERIALIZE ? (rob[(n3+ROB_ENTRIES-1)%ROB_ENTRIES].done==2'b11 || rob[(n3+ROB_ENTRIES-1)%ROB_ENTRIES].v==INV) : 1'b1)
				//&& !fnPriorFalsePred(g)
				&& !rob[n3].prior_sync
	//			&& |rob[n3].pred_bits
				&& rob[n3].pred_bitv
				;

			rob[n3].could_issue_nm <= 
					 rob[n3].v
				&& !(&rob[n3].done)
	//												&& !stomp_i[g]
				&& rob[n3].argT_v 
				//&& fnPredFalse(g)
				&& !robentry_issue[n3]
				&& ~|rob[n3].pred_bits
		    && rob[n3].pred_bitv
				&& SUPPORT_PRED
				;
		end
	end

end

// External bus arbiter. Simple priority encoded.

always_comb
begin
	
	ftatm_resp = {$bits(fta_cmd_response256_t){1'd0}};
	ftaim_resp = {$bits(fta_cmd_response256_t){1'd0}};
	ftadm_resp[0] = {$bits(fta_cmd_response256_t){1'd0}};
	ftadm_resp[1] = {$bits(fta_cmd_response256_t){1'd0}};
	cap_tag_resp[0] = {$bits(fta_cmd_response256_t){1'd0}};
	cap_tag_resp[1] = {$bits(fta_cmd_response256_t){1'd0}};

	// Setup to retry.
	ftatm_resp.rty = 1'b1;
	ftaim_resp.rty = 1'b1;
	ftadm_resp[0].rty = 1'b1;
	ftadm_resp[1].rty = 1'b1;
	ftadm_resp[0].tid = ftadm_req[0].tid;
	ftadm_resp[1].tid = ftadm_req[1].tid;
	cap_tag_resp[0].rty = 1'b1;
	cap_tag_resp[1].rty = 1'b1;
	cap_tag_resp[0].tid = cap_tag_req[0].tid;
	cap_tag_resp[1].tid = cap_tag_req[1].tid;
		
	// Cancel retry if bus aquired.
	if (ftatm_req.cyc)
		ftatm_resp.rty = 1'b0;
	else if (ftaim_req.cyc)
		ftaim_resp.rty = 1'b0;
	else if (ftadm_req[0].cyc)
		ftadm_resp[0].rty = 1'b0;
	else if (ftadm_req[1].cyc)
		ftadm_resp[1].rty = 1'b0;
	else if (cap_tag_req[0].cyc)
		cap_tag_resp[0].rty = 1'b0;
	else if (cap_tag_req[1].cyc)
		cap_tag_resp[1].rty = 1'b0;

	// Route bus responses.
	case(fta_resp1.tid.channel)
	3'd0:	ftaim_resp = fta_resp1;
	3'd1:	ftadm_resp[0] = fta_resp1;
//	3'd2:	ftadm_resp[1] <= fta_resp1;
	3'd3:	ftatm_resp = fta_resp1;
	3'd4:	cap_tag_resp[0] = fta_resp1;
//	3'd5:	cap_tag_resp[1] = fta_resp1;
	default:	;	// response was not for us
	endcase
	
end

always_ff @(posedge clk)
	if (ftatm_req.cyc)
		fta_req <= ftatm_req;
	else if (ftaim_req.cyc)
		fta_req <= ftaim_req;
	else if (ftadm_req[0].cyc)
		fta_req <= ftadm_req[0];
	else if (ftadm_req[1].cyc)
		fta_req <= ftadm_req[1];
	else if (cap_tag_req[0].cyc)
		fta_req <= cap_tag_req[0];
	else if (cap_tag_req[1].cyc)
		fta_req <= cap_tag_req[1];
	else
		fta_req <= {$bits(fta_cmd_request256_t){1'd0}};


fta_cmd_response256_t [1:0] resp_ch;

fta_respbuf256 #(.CHANNELS(2))
urb1
(
	.rst(irst),
	.clk(clk),
	.clk5x(clk5x),
	.resp(resp_ch),
	.resp_o(fta_resp1)
);

assign resp_ch[0] = fta_resp;
assign resp_ch[1] = ptable_resp;

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
	iact_cnt <= iact_cnt + (ihito|micro_code_active);

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
			IV <= IV + rob[head0].v + rob[head1].v + rob[head2].v + rob[head3].v;
		else if (cmtcnt > 2)
			IV <= IV + rob[head0].v + rob[head1].v + rob[head2].v;
		else if (cmtcnt > 1)
			IV <= IV + rob[head0].v + rob[head1].v;
		else if (cmtcnt > 0)
			IV <= IV + rob[head0].v;
	end
end

always_ff @(posedge clk)
if (irst)
	stomped_insn = 64'd0;
else begin
	for (n31 = 0; n31 < ROB_ENTRIES; n31 = n31 + 1)
		stomped_insn = stomped_insn + robentry_stomp[n31];
end

always_ff @(posedge clk)
if (irst)
	cpytgts <= 0;
else begin
	if (do_commit) begin
		if (cmtcnt > 3)
			cpytgts <= cpytgts 
				+ rob[head0].decbus.cpytgt 
				+ rob[head1].decbus.cpytgt
				+ rob[head2].decbus.cpytgt
				+ rob[head3].decbus.cpytgt
			;
		else if (cmtcnt > 2)
			cpytgts <= cpytgts 
				+ rob[head0].decbus.cpytgt 
				+ rob[head1].decbus.cpytgt
				+ rob[head2].decbus.cpytgt
			;
		else if (cmtcnt > 1)
			cpytgts <= cpytgts 
				+ rob[head0].decbus.cpytgt 
				+ rob[head1].decbus.cpytgt
			;
		else if (cmtcnt > 0)
			cpytgts <= cpytgts 
				+ rob[head0].decbus.cpytgt 
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
	fnRegVal = urf1.gRF.genblk1[0].urf0.mem[regno];
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
	$display("----- Fetch -----");
	$display("i$ pc input:  %h.%h #", pc.bno_t,pc.pc);
	$display("i$ pc output: %h %s #", icpc.pc, ihito ? "ihit" : "    ");
	$display("cacheL: %x", ic_line[511:0]);
	$display("cacheH: %x", ic_line[1023:512]);
	$display("----- Instruction Extract %c%c ----- %s", ihit_fet ? "h":" ", micro_code_active_x ? "a": " ", stomp_fet ? stompstr : no_stompstr);
	$display("pc 0: %h.%h.%h  1: %h.%h.%h  2: %h.%h.%x  3: %h.%h.%x",
		uiext1.pc0_fet.bno_t, uiext1.pc0_fet.pc, mcip0_mux,
		uiext1.pc1_fet.bno_t, uiext1.pc1_fet.pc, mcip1_mux,
		uiext1.pc2_fet.bno_t, uiext1.pc2_fet.pc, mcip2_mux,
		uiext1.pc3_fet.bno_t, uiext1.pc3_fet.pc, mcip3_mux);
	$display("lineL: %h", uiext1.ic_line_fet[511:0]);
	$display("lineH: %h", uiext1.ic_line_fet[1023:512]);
	$display("align: %x", uiext1.ic_line_aligned);
	$display("- - - - - - Multiplex %c - - - - - - %s", ihit_mux ? "h":" ", stomp_mux ? stompstr : no_stompstr);
	$display("pc0: %h.%h ins0: %h", uiext1.ins0_mux.pc.pc[23:0], uiext1.ins0_mux.mcip, uiext1.ins0_mux.ins[47:0]);
	$display("pc1: %h.%h ins1: %h", uiext1.ins1_mux.pc.pc[23:0], uiext1.ins1_mux.mcip, uiext1.ins1_mux.ins[47:0]);
	$display("pc2: %h.%h ins2: %h", uiext1.ins2_mux.pc.pc[23:0], uiext1.ins2_mux.mcip, uiext1.ins2_mux.ins[47:0]);
	$display("pc3: %h.%h ins3: %h", uiext1.ins3_mux.pc.pc[23:0], uiext1.ins3_mux.mcip, uiext1.ins3_mux.ins[47:0]);
	$display("micro_ip: %h", micro_ip);
	if (do_bsr)
		$display("BSR %h  pc0_fet=%h", bsr_tgt.pc, uiext1.ins0_mux.pc.pc[31:0]);
	$display("----- Decode %c%c ----- %s", ihit_dec ? "h":" ", micro_code_active_d ? "a": " ", stomp_dec ? stompstr : no_stompstr);
	$display("pc0: %h.%h ins0: %h", ins0_dec.pc.pc[23:0], ins0_dec.mcip, ins0_dec.ins[47:0]);
	$display("pc1: %h.%h ins1: %h", ins1_dec.pc.pc[23:0], ins1_dec.mcip, ins1_dec.ins[47:0]);
	$display("pc2: %h.%h ins2: %h", ins2_dec.pc.pc[23:0], ins2_dec.mcip, ins2_dec.ins[47:0]);
	$display("pc3: %h.%h ins3: %h", ins3_dec.pc.pc[23:0], ins3_dec.mcip, ins3_dec.ins[47:0]);

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

	$display("----- Rename %c%c ----- %s", ihit_ren ? "h":" ", micro_code_active_r ? "a": " ", stomp_ren ? stompstr : no_stompstr);
	$display("pc0: %x.%x ins0: %x  Rt: %d->%d%c  Rs: %d->%d%c  Ra: %d->%d%c  Rb: %d->%d%c  Rc: %d->%d%c",
		ins0_ren.pc.pc[23:0], ins0_ren.mcip, ins0_ren.ins[63:0],
		ins0_ren.nRt, Rt0_ren, Rt0_renv?"v":" ",
		ins0_ren.aRt, prn[3], prnv[3]?"v":" ",
		ins0_ren.aRa, prn[0], prnv[0]?"v": " ",
		ins0_ren.aRb, prn[1], prnv[1]?"v":" ",
		ins0_ren.aRc, prn[2], prnv[2]?"v":" ");
	$display("pc1: %x.%x ins1: %x  Rt: %d->%d%c  Rs: %d->%d%c  Ra: %d->%d%c  Rb: %d->%d%c  Rc: %d->%d%c", ins1_ren.pc.pc[23:0], ins1_ren.mcip, ins1_ren.ins[63:0], 
		ins1_ren.nRt, Rt1_ren, Rt1_renv?"v":" ",
		ins1_ren.aRt, prn[7], prnv[7]?"v":" ",
		ins1_ren.aRa, prn[4], prnv[4]?"v":" ",
		ins1_ren.aRb, prn[5], prnv[5]?"v":" ",
		ins1_ren.aRc, prn[6], prnv[6]?"v":" ");
	$display("pc2: %x.%x ins2: %x  Rt: %d->%d%c  Rs: %d->%d%c  Ra: %d->%d%c  Rb: %d->%d%c  Rc: %d->%d%c", ins2_ren.pc.pc[23:0], ins2_ren.mcip, ins2_ren.ins[63:0],
		ins2_ren.nRt, Rt2_ren, Rt2_renv?"v":" ",
		ins2_ren.aRt, prn[11], prnv[11]?"v":" ",
		ins2_ren.aRa, prn[8], prnv[8]?"v":" ",
		ins2_ren.aRb, prn[9], prnv[9]?"v":" ",
		ins2_ren.aRc, prn[10], prnv[10]?"v":" ");
	$display("pc3: %x.%x ins3: %x  Rt: %d->%d%c  Rs: %d->%d%c  Ra: %d->%d%c  Rb: %d->%d%c  Rc: %d->%d%c", ins3_ren.pc.pc[23:0], ins3_ren.mcip, ins3_ren.ins[63:0],
		ins3_ren.nRt, Rt3_ren, Rt3_renv?"v":" ",
		ins3_ren.aRt, prn[15], prnv[15]?"v":" ",
		ins3_ren.aRa, prn[12], prnv[12]?"v":" ",
		ins3_ren.aRb, prn[13], prnv[13]?"v":" ",
		ins3_ren.aRc, prn[14], prnv[14]?"v":" ");
//	$display("----- Queue Time ----- %s", (stomp_que && !stomp_quem) ? stompstr : no_stompstr);
	$display("----- Queue %c%c ----- %h", ihit_que ? "h":" ", micro_code_active_q ? "a": " ", qd);
	for (i = 0; i < ROB_ENTRIES; i = i + 1) begin
    $display("%c%c%c sn:%h %d: %c%c%c%c%c%c %c %c%c %d %c %c%d Rt%d/%d=%h %h Rs%d/%d %h%c Ra%d/%d=%h %c Rb%d/%d=%h %c Rc%d/%d=%h %c I=%h %h.%h.%h cp:%h ins=%h #",
			(i[4:0]==head0)?67:46, (i[4:0]==tail0)?81:46, rob[i].rstp ? "r" : " ", rob[i].sn, i[5:0],
			rob[i].v?"v":"-", rob[i].done[0]?"d":"-", rob[i].done[1]?"d":"-", rob[i].out[0]?"o":"-", rob[i].out[1]?"o":"-", rob[i].bt?"t":"-", rob_memissue[i]?"i":"-", rob[i].lsq?"q":"-", (robentry_issue[i]|robentry_agen_issue[i])?"i":"-",
			robentry_islot[i], robentry_stomp[i]?"s":"-",
			(rob[i].decbus.cpytgt ? "c" : rob[i].decbus.fc ? "b" : rob[i].decbus.mem ? "m" : "a"),
			rob[i].op.ins.any.opcode, 
			rob[i].decbus.Rt, rob[i].op.nRt, rob[i].res, rob[i].exc,
			rob[i].decbus.Rt, rob[i].op.pRt, rob[i].argT, rob[i].argT_v?"v":" ",
			rob[i].decbus.Ra, rob[i].op.pRa, rob[i].argA, rob[i].argA_v?"v":" ",
			rob[i].decbus.Rb, rob[i].op.pRb, rob[i].argB, rob[i].argB_v?"v":" ",
			rob[i].decbus.Rc, rob[i].op.pRc, rob[i].argC, rob[i].argC_v?"v":" ",
			rob[i].argI,
			rob[i].pc.bno_t, rob[i].pc.pc, rob[i].mcip,
			rob[i].cndx, rob[i].op.ins[63:0]);
	end
	$display("----- LSQ -----");
	for (i = 0; i < LSQ_ENTRIES; i = i + 1) begin
		$display("%c%c sn:%h %d: %d %c%c%c v%h p%h data:%h %c #", (i[2:0]==lsq_head.row)?72:46,(i[2:0]==lsq_tail.row)?84:46,
			lsq[i][0].sn, i[2:0],
			lsq[i][0].rndx,lsq[i][0].store ? "S": lsq[i][0].load ? "L" : "-",
			lsq[i][0].v?"v":" ",lsq[i][0].agen?"a":" ",lsq[i][0].vadr,lsq[i][0].padr,
			lsq[i][0].res[511:0],lsq[i][0].datav?"v":" "
		);
	end
	$display("----- AGEN -----");
	$display(" I=%h A=%h B=%h %c%h pc:%h #",
		agen0_argI, agen0_argA, agen0_argB,
		 ((fnIsLoad(agen0_op) || fnIsStore(agen0_op)) ? 109 : 97),
		agen0_op, agen0_pc);
	$display("idle:%d res:%h rid:%d #", agen0_idle, agen0_res, agen0_id);
	if (NAGEN > 1) begin
		$display(" I=%h A=%h B=%h %c%h pc:%h #",
			agen1_argI, agen1_argA, agen1_argB,
			 ((fnIsLoad(agen1_op) || fnIsStore(agen1_op)) ? 109 : 97),
			agen1_op, agen1_pc);
		$display("idle:%d res:%h rid:%d #", agen1_idle, agen1_res, agen1_id);
	end
	$display("----- Memory -----");
	$display("%d%c v%h p%h, %h %c%d %o #",
	    dram0, dram0_ack?"A":" ", dram0_vaddr, dram0_paddr, dram0_data, ((dram0_load || dram0_cload || dram0_cload_tags || dram0_store || dram0_cstore) ? 109 : 97), dram0_op, dram0_id);
	if (NDATA_PORTS > 1) begin
	$display("%d v%h p%h %h %c%d %o #",
	    dram1, dram1_vaddr, dram1_paddr, dram1_data, ((dram1_load || dram1_cload || dram1_cload_tags || dram1_store || dram1_cstore) ? 109 : 97), dram1_op, dram1_id);
	end
//	$display("%d %h %h %c%d %o #",
//	    dram2, dram2_addr, dram2_data, (fnIsFlowCtrl(dram2_op) ? 98 : (dram2_load || dram2_store) ? 109 : 97), 
//	    dram2_op, dram2_id);
	$display("%d %h %o %h #", dram_v0, dram_bus0, dram_id0, dram_exc0);
	$display("%d %h %o %h #", dram_v1, dram_bus1, dram_id1, dram_exc1);

	$display("----- FCU -----");
	$display("eval:%c A=%h B=%h BI=%h I=%h", takb?"T":"F", fcu_argA, fcu_argB, fcu_argBr, fcu_argI);
	$display("bt:%c pc=%h id=%d bts:%d", fcu_bt ? "T":"F", fcu_pc, fcu_id, fcu_bts);
	$display("miss: %c misspc=%h.%h instr=%h disp=%h", (takb&~fcu_bt)|(~takb&fcu_bt)?"T":"F",fcu_misspc1.bno_t,fcu_misspc1.pc, fcu_instr.ins[63:0],
		{{37{fcu_instr.ins[63]}},fcu_instr.ins[63:44],3'd0}
	);

	$display("----- ALU -----");
	$display("%d I=%h T=%h A=%h B=%h C=%h %c%d pc:%h #",
		alu0_dataready, alu0_argI, alu0_argT, alu0_argA, alu0_argB, alu0_argC,
		 ((fnIsLoad(alu0_instr) || fnIsStore(alu0_instr)) ? 109 : 97),
		alu0_instr, alu0_pc);
	$display("idle:%d res:%h rid:%d #", alu0_idle, alu0_res, alu0_id);

	if (NALU > 1) begin
		$display("%d I=%h T=%h A=%h B=%h C=%h %c%d pc:%h #",
			alu1_dataready, alu1_argI, alu1_argT, alu1_argA, alu1_argB, alu1_argC, 
			 ((fnIsLoad(alu1_instr) || fnIsStore(alu1_instr)) ? 109 : 97),
			alu1_instr, alu1_pc);
		$display("idle:%d res:%h rid:%d #", alu1_idle, alu1_res, alu1_id);
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
	for (n = 0; n < ROB_ENTRIES; n = n + 1)
		if (rob[n].v && rob[n].sn < rob[ndx].sn && rob[n].decbus.fc && !(&rob[n].done))
			fnPriorFC = TRUE;
end
endfunction

function fnPriorMem;
input rob_ndx_t ndx;
integer n;
begin
	fnPriorMem = FALSE;
	for (n = 0; n < ROB_ENTRIES; n = n + 1)
		if (rob[n].v && rob[n].sn < rob[ndx].sn && rob[n].decbus.mem && !(&rob[n].done))
			fnPriorMem = TRUE;
end
endfunction

function fnPriorSync;
input rob_ndx_t ndx;
integer n;
begin
	fnPriorSync = FALSE;
	for (n = 0; n < ROB_ENTRIES; n = n + 1)
		if (rob[n].v && rob[n].sn < rob[ndx].sn && rob[n].decbus.sync)
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
		if (rob[dndx].op.pRt==rob[ndx].op.nRt && 
			rob[dndx].op.pRt!=9'd0 && rob[dndx].op.pRt!=PREGS-1) begin
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
	fnPredPCMatch = pc1==(pc2 - 8'd08);
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
		if (rob[n32].v && rob[n32].decbus.pred 
		&& fnPredPCMatch(rob[n32].pc[7:0],rob[ndx].pc[7:0])
		&& !rob[ndx].decbus.vec
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
	if (|rob[n].out && rob[n].done==2'b00 && rob[n].v && 
		!((n==alu0_id && !alu0_idle)
			|| (n==alu1_id && !alu1_idle)
			|| (n==fpu0_id && !fpu0_idle)
			|| (n==fpu1_id && !fpu1_idle)
			|| n==agen0_id
			|| n==agen1_id
			|| n==fcu_id
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
input [1:0] mask;
input [7:0] argA;
input [7:0] argB;
input [7:0] argC;
integer n30;
begin
	for (n30 = 0; n30 < 8; n30 = n30 + 1)
		case(mask)
		2'd0:	fnPredStatus[n30] = 1'b1;
		2'd1:	fnPredStatus[n30] = argA[n30];
		2'd2:	fnPredStatus[n30] = argB[n30];
		2'd3:	fnPredStatus[n30] = argC[n30];
		endcase
end
endfunction

function fnValidate;
input pregno_t rg;
integer n;
begin
	fnValidate = FALSE;
	for (n = 0; n < ROB_ENTRIES; n = n + 1)
		if (rob[n].op.nRt==rg && rob[n].done==2'b11)
			fnValidate = TRUE;
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
	for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
		if (rob[n].decbus.Rt==rg && rob[n].sn < rob[ndx].sn)
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
	for (n18r = 0; n18r < LSQ_ENTRIES; n18r = n18r + 1) begin
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

task tBypassRegnames;
input rob_ndx_t ndx;
input pipeline_reg_t db;
input pipeline_reg_t pdb;
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
				rob[ndx].argT_v <= VAL;
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

task tBypassValid;
input rob_ndx_t ndx;
input pipeline_reg_t db;
input pipeline_reg_t db2;
begin
	if (db.decbus.Ra == db2.decbus.Rt && !db.decbus.Raz) begin
		rob[ndx].argA_v <= INV;
		rob[ndx].all_args_valid <= INV;
	end
	if (db.decbus.Rb == db2.decbus.Rt && !db.decbus.Rbz) begin
		rob[ndx].argB_v <= INV;
		rob[ndx].all_args_valid <= INV;
	end
	if (db.decbus.Rc == db2.decbus.Rt && !db.decbus.Rcz) begin
		rob[ndx].argC_v <= INV;
		rob[ndx].all_args_valid <= INV;
	end
	if (db.decbus.Rt == db2.decbus.Rt && !db.decbus.Rtz) begin
		rob[ndx].argT_v <= INV;
		rob[ndx].all_args_valid <= INV;
	end
	if (db.decbus.Rm == db2.decbus.Rt) begin
		rob[ndx].argM_v <= INV;
		rob[ndx].all_args_valid <= INV;
	end
end
endtask

// Get the predicate bitmask for the instruction.
// For scalar instructions this comes from the predicate modifier associated
// with the instruction.

function [7:0] fnPredSet;
input [3:0] btst;
input vec;
input rob_entry_t pred_rob;
input rob_entry_t rob;
integer jj;
reg [3:0] btstm1;
begin
	btstm1 = btst - 2'd1;
	fnPredSet = 8'h00;
	for (jj = 0; jj < 8; jj = jj + 1) begin
		if (vec)
			fnPredSet[jj] = pred_rob.pred_status[{btstm1,jj[2:0]}];
		else
			fnPredSet[jj] = pred_rob.pred_status[{btstm1,jj[2:0]}];
	end
end
endfunction

// It takes a clock cycle for the register file to update. An update matching
// the physical regno will not be valid until a cycle later. So, a pending
// valid flag is set. This flag is set to allow the real valid flag to be
// updated in the next cycle.

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
	if (rob[nn].argT_v == INV && rob[nn].op.pRt == Rt && rob[nn].v == VAL && v == VAL)
    rob[nn].argT_vp <= VAL;
	if (rob[nn].argM_v == INV && rob[nn].op.pRm == Rt && rob[nn].v == VAL && v == VAL)
    rob[nn].argM_vp <= VAL;
`ifdef IS_SIM
	if (rob[nn].argA_v == INV && rob[nn].op.pRa == Rt && rob[nn].v == VAL && v == VAL)
    rob[nn].argA <= val;
	if (rob[nn].argB_v == INV && rob[nn].op.pRb == Rt && rob[nn].v == VAL && v == VAL)
    rob[nn].argB <= val;
	if (rob[nn].argT_v == INV && rob[nn].op.pRt == Rt && rob[nn].v == VAL && v == VAL)
    rob[nn].argT <= val;
	if (rob[nn].argM_v == INV && rob[nn].op.pRm == Rt && rob[nn].v == VAL && v == VAL)
    rob[nn].argM <= val;
`endif    
	if (rob[nn].argC_v == INV && rob[nn].op.pRc == Rt && rob[nn].v == VAL && v == VAL)
    rob[nn].argC <= val;
end
endtask	    

// Called to invalidate ROB entries after a branch miss.

task tBranchInvalidate;
input rob_ndx_t ndx;
input cpytgt;
integer nn;
begin
	rob[ndx].v <= cpytgt;
	rob[ndx].excv <= INV;
	rob[ndx].decbus.cpytgt <= cpytgt;
	if (cpytgt) begin
		rob[ndx].decbus.alu <= TRUE;
		rob[ndx].decbus.fpu <= FALSE;
		rob[ndx].decbus.fc <= FALSE;
		rob[ndx].decbus.mem <= FALSE;
		rob[ndx].op.ins <= {57'd0,OP_NOP};
		//rob[n3].decbus.Rtz <= TRUE;
		rob[ndx].done <= {FALSE,FALSE};
		rob[ndx].out <= {FALSE,FALSE};
	end
	else begin
		rob[ndx].done <= {TRUE,TRUE};
		rob[ndx].out <= {FALSE,FALSE};
	end
//		rob[ndx].cndx <= miss_cp;
	rob[ndx].lsq <= INV;
	// Clear corresponding LSQ entries.
	if (rob[ndx].lsq)
		tInvalidateLSQ(ndx,TRUE);
	if (ndx==agen0_id) begin
		agen0_idle <= TRUE;
		agen0_idv <= INV;
		if (dram0_id==agen0_id)
			dram0_stomp <= TRUE;
	end
	if (NDATA_PORTS > 1) begin
		if (ndx==agen1_id) begin
			agen1_idle <= TRUE;
			agen1_idv <= INV;
			if (dram1_id==agen1_id)
				dram1_stomp <= TRUE;
		end
	end
	for (nn = 0; nn < ROB_ENTRIES; nn = nn + 1) begin
		if (robentry_stomp[nn] && rob[nn].sn < rob[ndx].sn && rob[nn].op.nRt==rob[ndx].op.pRt) begin
			if (rob[ndx].op.pRt!=9'd0)
				rob[ndx].argT_v <= INV;
		end
	end
end
endtask


// Used at commit time when the queue entry is no longer needed.

task tInvalidateQE;
input rob_ndx_t ndx;
begin
	rob[ndx].v <= INV;
	rob[ndx].done <= {INV,INV};
	rob[ndx].out <= {INV,INV};
	if (rob[ndx].lsq)
		tInvalidateLSQ(ndx,FALSE);
	rob[ndx].lsq <= INV;
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
	if (rob[head].v && rob[head].decbus.qfext && !rob[(head+1)%ROB_ENTRIES].decbus.fpu && alu0_id==head) begin
		if (rob[head].done!=2'b11) begin
			alu0_idle1 <= TRUE;
			alu0_idv <= INV;
			alu0_done <= TRUE;
	    rob[alu0_id].done <= 2'b11;
			rob[alu0_id].out <= {INV,INV};
		end
	end
end
endtask

// Invalidate LSQ entries associated with a ROB entry. This searches the LSQ
// which is small in case multiple LSQ entries are associated. This is an
// issue in the core's current operation.
// Note that only valid entries are invalidated as invalid entries may be
// about to be used by enqueue logic.

task tInvalidateLSQ;
input rob_ndx_t id;
input can;
integer n18r, n18c;
begin
	for (n18r = 0; n18r < LSQ_ENTRIES; n18r = n18r + 1) begin
		for (n18c = 0; n18c < 2; n18c = n18c + 1) begin
			if (lsq[n18r][n18c].rndx==id && lsq[n18r][n18c].v==VAL) begin
				lsq[n18r][n18c].v <= INV;
				lsq[n18r][n18c].agen <= FALSE;
				lsq[n18r][n18c].datav <= INV;
				lsq[n18r][n18c].store <= FALSE;
				lsq[n18r][n18c].load <= FALSE;
				if (agen0_id==lsq[n18r][n18c].rndx)
					agen0_idle <= TRUE;
				if (NAGEN > 1 && agen1_id==lsq[n18r][n18c].rndx)
					agen1_idle <= TRUE;
				// It is possible that a load operation already in progress got
				// cancelled.
				if (dram0_id==lsq[n18r][n18c].rndx)
					dram0_stomp <= TRUE;
				if (NDATA_PORTS > 1 && dram0_id==lsq[n18r][n18c].rndx)
					dram1_stomp <= TRUE;
				if (can)
					cpu_request_cancel[lsq[n18r][n18c].rndx] <= 1'b1;
			end
		end
	end
end
endtask

// Update the address fields in the LSQ entries.

task tSetLSQ;
input rob_ndx_t id;
input address_t vadr;
input address_t padr;
integer n18r, n18c;
begin
	for (n18r = 0; n18r < LSQ_ENTRIES; n18r = n18r + 1) begin
		for (n18c = 0; n18c < 2; n18c = n18c + 1) begin
			if (lsq[n18r][n18c].rndx==id && lsq[n18r][n18c].v) begin
				lsq[n18r][n18c].agen <= TRUE;
				lsq[n18r][n18c].vadr <= vadr;
				lsq[n18r][n18c].padr <= padr;//{tlbe.pte.ppn,adr[12:0]};
			end
		end
	end
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
		kvec[n14] <= 32'hFFFFFC00;
		avec[n14] <= 32'hFFFFFC00;
	end
	next_pending_ipl <= 6'd63;
	err_mask <= 64'd0;
	excir <= {41'd0,OP_NOP};
	excmiss <= FALSE;
	excmisspc.bno_t <= 6'd1;
	excmisspc.bno_f <= 6'd1;
	excmisspc.pc <= 32'hFFFFFFC0;
	excmiss_mcip <= 12'h0;
	excret <= FALSE;
	exc_ret_pc <= 32'hFFFFFFC0;
	exc_ret_pc.bno_t <= 6'd1;
	exc_ret_pc.bno_f <= 6'd1;
	sr <= 64'd0;
	sr.pl <= 8'hFF;				// highest priority
	sr.om <= OM_MACHINE;
	sr.dbg <= TRUE;
	sr.ipl <= 6'd0;				// non-maskable interrupts only
	asid <= 16'd0;
	ip_asid <= 16'd0;
	atom_mask <= 32'd0;
//	postfix_mask <= 'd0;
	dram_exc0 <= FLT_NONE;
	dram_exc1 <= FLT_NONE;
	dram0_stomp <= 32'd0;
	dram0_vaddr <= 64'd0;
	dram0_paddr <= 64'd0;
	dram0_data <= 512'd0;
	dram0_ctago <= 1'b0;
	dram0_exc <= FLT_NONE;
	dram0_id <= 5'd0;
	dram0_load <= 1'd0;
	dram0_loadz <= 1'd0;
	dram0_cload <= 1'd0;
	dram0_cload_tags <= 1'd0;
	dram0_store <= 1'd0;
	dram0_cstore <= 1'd0;
	dram0_erc <= 1'd0;
	dram0_op <= OP_NOP;
	dram0_pc <= RSTPC;
	dram0_Rt <= 8'd0;
	dram0_tid <= 13'd0;
	dram0_hi <= 1'd0;
	dram0_shift <= 1'd0;
	dram0_tocnt <= 12'd0;
	dram0_idv <= INV;
	dram0_idv2 <= INV;
	dram0_cp <= 4'd0;
	dram0_ldip <= FALSE;
	dram1_stomp <= 32'd0;
	dram1_vaddr <= 64'd0;
	dram1_paddr <= 64'd0;
	dram1_data <= 512'd0;
	dram1_ctago <= 1'b0;
	dram1_exc <= FLT_NONE;
	dram1_id <= 5'd0;
	dram1_load <= 1'd0;
	dram1_loadz <= 1'd0;
	dram1_cload <= 1'd0;
	dram1_cload_tags <= 1'd0;
	dram1_store <= 1'd0;
	dram1_cstore <= 1'd0;
	dram1_erc <= 1'd0;
	dram1_op <= OP_NOP;
	dram1_pc <= RSTPC;
	dram1_Rt <= 8'd0;
	dram1_tid <= 8'h08;
	dram1_hi <= 1'd0;
	dram1_shift <= 1'd0;
	dram1_tocnt <= 12'd0;
	dram1_idv <= INV;
	dram1_cp <= 4'd0;
	dram_v0 <= 1'd0;
	dram_v1 <= 1'd0;
	dram_Rt0 <= 9'd0;
	dram_Rt1 <= 9'd0;
	dram_bus0 <= 64'd0;
	dram_bus1 <= 64'd0;
	dram_ctag0 <= 1'b0;
	dram_ctag1 <= 1'b0;
	dram0_argT <= 64'd0;
	dram1_argT <= 64'd0;
	panic <= `PANIC_NONE;
	for (n14 = 0; n14 < ROB_ENTRIES; n14 = n14 + 1) begin
		rob[n14] <= {$bits(rob_entry_t){1'd0}};
		rob[n14].sn <= 8'd0;
	end
	for (n14r = 0; n14r < LSQ_ENTRIES; n14r = n14r + 1) begin
		for (n14c = 0; n14c < 2; n14c = n14c + 1) begin
			lsq[n14r][n14c] <= {$bits(lsq_entry_t){1'd0}};
		end
	end
	/*
	for (n14 = 0; n14 < BEB_ENTRIES; n14 = n14 + 1) begin
		beb[n14] <= {$bits(beb_entry_t){1'd0}};
	end
	*/
	alu0_available <= 1;
	alu0_dataready <= 0;
	alu1_available <= 1;
	alu1_dataready <= 0;
	alu0_out <= INV;
	alu1_out <= INV;
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
	fcu_v <= INV;
	fcu_v2 <= INV;
	fcu_v3 <= INV;
	fcu_v4 <= INV;
	fcu_v5 <= INV;
	fcu_v6 <= INV;
	fcu_idle <= TRUE;
	fcu_idv <= INV;
	fcu_bsr <= FALSE;
	fcu_new <= FALSE;
	brtgtv <= INV;
	brtgtvr <= INV;
	mcbrtgtv <= INV;
	dram0_aRt <= 7'd0;
	dram1_aRt <= 7'd0;
	dram0_aRtz <= TRUE;
	dram1_aRtz <= TRUE;
//	fcu_argC <= 'd0;
	/*
	for (n11 = 0; n11 < NDATA_PORTS; n11 = n11 + 1) begin
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
	grplen0 <= 6'd0;
	grplen1 <= 6'd0;
	grplen2 <= 6'd0;
	grplen3 <= 6'd0;
	group_len <= 6'd0;
	last0 <= 1'b1;
	last1 <= 1'b1;
	last2 <= 1'b1;
	last3 <= 1'b1;
	tail0 <= 5'd0;
	head0 <= 5'd0;
	rstcnt <= 4'd0;
	lsq_head <= 3'd0;
	lsq_tail <= 3'd0;
	alu0_idle1 <= TRUE;
	alu1_idle1 <= TRUE;
	alu0_done <= TRUE;
	alu1_done <= TRUE;
	alu0_idv <= INV;
	alu1_idv <= INV;
	agen0_idle <= TRUE;
	agen1_idle <= TRUE;
	brtgtv <= FALSE;
	pc_in_sync <= TRUE;
	ls_bmf <= 1'd0;
	reg_bitmask <= 64'd0;
	commit0_id <= ROB_ENTRIES-4;
	commit1_id <= ROB_ENTRIES-3;
	commit2_id <= ROB_ENTRIES-2;
	commit3_id <= ROB_ENTRIES-1;
	pack_regs <= FALSE;
	scale_regs <= 3'd4;
	store_argC_id <= 5'd0;
	store_argC_id1 <= 5'd0;
	alu0_stomp <= FALSE;
	alu1_stomp <= FALSE;
	fpu0_stomp <= FALSE;
	fpu1_stomp <= FALSE;
	dram0_stomp <= FALSE;
	dram1_stomp <= FALSE;
	agen0_idv <= INV;
	agen1_idv <= INV;
	stompstr <= "(stomped)";
	no_stompstr <= "         ";
//	inc_chkpt <= FALSE;
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
	store_argC_aReg <= 8'd0;
	store_argC_pReg <= 9'd0;
	store_argC_cndx <= 4'd0;
	cpu_request_cancel <= {ROB_ENTRIES{1'b0}};
	groupno <= {$bits(seqnum_t){1'b0}};
	sync_no <= 6'd0;
	fc_no <= 6'd0;
	irq_wr_en <= FALSE;
	ssm_flag <= FALSE;
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Queue instruction.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tEnque;
input seqnum_t sn;
input seqnum_t grp;
input [2:0] predino;
input rob_ndx_t predrndx;
input pipeline_reg_t ins;
input pt;
input rob_ndx_t tail;
input stomp;
input ornop;
input pregno_t pRa;
input pregno_t pRb;
input pregno_t pRc;
input pregno_t pRt;
input pregno_t nRt;
input pregno_t pRm;
input pRav;
input pRbv;
input pRcv;
input pRtv;
input pRmv;
input checkpt_ndx_t cndxq;
input checkpt_ndx_t pndxq;
input rob_ndx_t grplen;
input last;
integer n12;
integer n13;
decode_bus_t db;
reg [5:0] next_sync_no;
reg [5:0] next_fc_no;
begin
	db = ins.decbus;

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

	// "dynamic" fields, these fields may change after enqueue
	rob[tail].sn <= sn;
	rob[tail].pred_bitv <= FALSE;
	rob[tail].pred_bits <= 8'h00;
	rob[tail].orid <= mc_orid;
	rob[tail].chkpt_freed <= FALSE;
	rob[tail].br_cndx <= cndxq;

	// NOP type instructions appear in the queue but they do not get scheduled or
	// execute. They are marked done immediately.
	rob[tail].done <= {2{db.nop}};
	// Unconditional branches and jumps are done already in the mux stage.
	// Unconditional subroutine calls only need the target register updated.
	if (db.bsr) begin
		if (db.Rtz)
			rob[tail].done <= {VAL,VAL};
		else
			rob[tail].done <= {VAL,INV};
	end
	rob[tail].out <= {INV,INV};
	rob[tail].lsq <= INV;
	rob[tail].takb <= 1'b0;

	// Check for unimplemented instruction, but not if it is being stomped on.
	// If it is stomped on, we do not care.
	if (!(db.nop|db.alu|db.fpu|db.fc|db.mem|db.macro
		|db.csr|db.lda|db.fence
		|db.rex|db.oddball|db.pred|db.qfext
		|ornop|stomp
		|db.vec
		)) begin
		rob[tail].exc <= FLT_UNIMP;
		rob[tail].excv <= TRUE;
	end
	// Check for illegal register selection.
	else if (db.regexc) begin
		rob[tail].exc <= FLT_BADREG;
		rob[tail].excv <= TRUE;
	end
	else begin
		rob[tail].exc <= FLT_NONE;
		rob[tail].excv <= FALSE;
	end
	rob[tail].argA_v <= fnSourceAv(ins) | pRav | db.has_imma;
	rob[tail].argB_v <= fnSourceBv(ins) | pRbv | (db.has_Rb ? 1'b0 : db.has_immb);
	rob[tail].argC_v <= fnSourceCv(ins) | pRcv | db.has_immc;
	rob[tail].argT_v <= fnSourceTv(ins) | pRtv;
	rob[tail].argM_v <= fnSourceMv(ins) | pRmv;
	rob[tail].all_args_valid <= 
		(fnSourceAv(ins) | pRav | db.has_imma) &&
		(fnSourceBv(ins) | pRbv | (db.has_Rb ? 1'b0 : db.has_immb)) &&
		(fnSourceCv(ins) | pRcv | db.has_immc) &&
		(fnSourceTv(ins) | pRtv) &&
		(fnSourceMv(ins) | pRmv)
		;
	rob[tail].could_issue <= FALSE;
	rob[tail].could_issue_nm <= FALSE;
`ifdef IS_SIM
	rob[tail].argA <= fnRegVal(pRa);
	rob[tail].argB <= fnRegVal(pRb);
	rob[tail].argC <= fnRegVal(pRc);
	rob[tail].argT <= fnRegVal(pRt);
	rob[tail].argM <= fnRegVal(pRm);
`endif
	// Assume these two are TRUE. They will be set FALSE later.
	rob[tail].prior_sync <= TRUE;
	rob[tail].prior_fc <= TRUE;
	// "static" fields, these fields remain constant after enqueue
	rob[tail].grp <= grp;
	rob[tail].predino <= predino;
	rob[tail].predrndx <= predrndx;
	rob[tail].brtgt <= fnTargetIP(ins.pc,db.immc);
	rob[tail].mcbrtgt <= db.immc[11:0];
	rob[tail].om <= sr.om;
`ifdef IS_SIM
	rob[tail].argI <= db.immb;
`endif	
//	rob[tail].rmd <= fpscr.rmd;
	rob[tail].op <= ins;
	rob[tail].pc <= ins.pc;
	rob[tail].mcip <= ins.mcip;
	rob[tail].bt <= ins.bt;//pt;
	rob[tail].cndx <= cndxq;//db.br ? pndxq : cndxq;
	rob[tail].decbus <= db;
	if (db.Ra==9'd0) rob[tail].op.aRa <= 9'd0;
	if (db.Rb==9'd0) rob[tail].op.aRb <= 9'd0;
	if (db.Rc==9'd0) rob[tail].op.aRc <= 9'd0;
	if (db.Rt==9'd0) rob[tail].op.aRt <= 9'd0;
	rob[tail].op.pRa <= pRa;	
	rob[tail].op.pRb <= pRb;
	rob[tail].op.pRc <= pRc;
	rob[tail].op.pRt <= pRt;
	rob[tail].op.pRm <= pRm;
	// Architectural register zero is not renamed, physical register zero is
	// used which will always read as zero. The renamer will not assign
	// physical register zero when registers are being renamed.
//	rob[tail].op.nRt <= nRt;//db.Rtz ? 10'd0 : nRt;
	rob[tail].group_len <= grplen;
	rob[tail].last <= last;
	rob[tail].v <= SUPPORT_BACKOUT ? ins.v : ins.v & ~stomp;
	if (!stomp && db.v && !brtgtv) begin
		if (db.br & pt) begin
			brtgt <= fnTargetIP(pc,db.immc);
			mcbrtgt <= db.immc[11:0];
			brtgtv <= VAL;	// ToDo: Fix
			mcbrtgtv <= mipv4;
		end
	end
	/*
	if (db.br && !stomp)
		inc_chkpt <= TRUE;
	*/
	// Vector instructions are treated as NOPs as they expand into scalar ops.
	// Should not see any vector instructions at queue time.
	// If the instruction enqueues it must have been through the renamer.
	// Propagate the target register to the new target by turning the instruction
	// into a copy-target.
	if (ins.ins.any.opcode==OP_NOP) begin
		rob[tail].decbus.alu <= TRUE;
		rob[tail].decbus.fpu <= FALSE;
		rob[tail].decbus.fc <= FALSE;
		rob[tail].decbus.load <= FALSE;
		rob[tail].decbus.store <= FALSE;
		rob[tail].decbus.mem <= FALSE;
		rob[tail].op <= nopi;
		rob[tail].argA_v <= VAL;
		rob[tail].argB_v <= VAL;
		rob[tail].argC_v <= VAL;
	end
	
	if (ornop|(SUPPORT_BACKOUT ? 1'b0 : stomp)) begin
		rob[tail].decbus.cpytgt <= TRUE;
		rob[tail].decbus.alu <= TRUE;
		rob[tail].decbus.fpu <= FALSE;
		rob[tail].decbus.fc <= FALSE;
		rob[tail].decbus.load <= FALSE;
		rob[tail].decbus.store <= FALSE;
		rob[tail].decbus.mem <= FALSE;
		rob[tail].op.pred_btst <= 6'd0;
//		rob[tail].op.ins <= {57'd0,OP_NOP};
//		rob[tail].argA_v <= VAL;
		rob[tail].argB_v <= VAL;
		rob[tail].argC_v <= VAL;
//		rob[tail].argT_v <= VAL;
//		rob[tail].argM_v <= VAL;
//		rob[tail].done <= {TRUE,TRUE};
	end
	
	// In the shadow of a BSR a target register may be assigned by the renamer.
	// There is not an easy way to undo this assignment, so we keep it and modify
	// the instruction to be a NOP operation.
//	else if (stomp)
//		rob[tail].decbus.cpytgt <= TRUE;
	if (db.vec) begin
		vrm[vn] <= 64'hFFFFFFFFFFFFFFFF;
		vex[vn] <= 64'h0;
		vn <= vn + 2'd1;
		rob[tail].vn <= vn;
	end
	if (!stomp && !ornop && db.vec)
		mc_orid <= tail;
	rob[tail].rat_v <= INV;
end
endtask

task tAllArgsValid;
input rob_ndx_t ndx;
input Av;
input Bv;
input Cv;
input Tv;
input Mv;
begin
	
	if (Av) rob[ndx].argA_v <= VAL;
	if (Bv) rob[ndx].argB_v <= VAL;
	if (Cv) rob[ndx].argC_v <= VAL;
	if (Tv) rob[ndx].argT_v <= VAL;
	if (Mv) rob[ndx].argM_v <= VAL;
	rob[ndx].all_args_valid <=
		(rob[ndx].argA_v | Av) &&
		(rob[ndx].argB_v | Bv) &&
		(rob[ndx].argC_v | Cv) &&
		(rob[ndx].argT_v | Tv) &&
		(rob[ndx].argM_v | Mv)
	;
	
end
endtask

// Queue to the load / store queue.

task tEnqueLSE;
input seqnum_t sn;
input lsq_ndx_t ndx;
input rob_ndx_t id;
input rob_entry_t rob;
input [1:0] n;
begin
	lsq[ndx.row][ndx.col] <= {$bits(lsq_entry_t){1'b0}};
	lsq[ndx.row][ndx.col].rndx <= id;
	lsq[ndx.row][ndx.col].v <= VAL;
	lsq[ndx.row][ndx.col].agen <= FALSE;
	lsq[ndx.row][ndx.col].op <= rob.op;
	lsq[ndx.row][ndx.col].pc <= rob.pc;
	lsq[ndx.row][ndx.col].load <= rob.decbus.load|rob.excv;
	lsq[ndx.row][ndx.col].loadz <= rob.decbus.loadz|rob.excv;
	lsq[ndx.row][ndx.col].cload <= rob.decbus.cload|rob.excv;
	lsq[ndx.row][ndx.col].cload_tags <= rob.decbus.cload_tags|rob.excv;
	lsq[ndx.row][ndx.col].store <= rob.decbus.store;
	lsq[ndx.row][ndx.col].cstore <= rob.decbus.cstore;
	lsq[ndx.row][ndx.col].vadr <= 32'd0;
	lsq[ndx.row][ndx.col].padr <= 32'd0;
//	store_argC_reg <= rob.pRc;
	lsq[ndx.row][ndx.col].aRc <= rob.decbus.Rc;
	lsq[ndx.row][ndx.col].pRc <= rob.op.pRc;
	lsq[ndx.row][ndx.col].cndx <= rob.cndx;
	lsq[ndx.row][ndx.col].Rt <= rob.op.nRt;
	lsq[ndx.row][ndx.col].aRt <= rob.decbus.Rt;
	lsq[ndx.row][ndx.col].aRtz <= rob.decbus.Rtz;
	lsq[ndx.row][ndx.col].om <= rob.om;
	lsq[ndx.row][ndx.col].memsz <= fnMemsz(rob.op);
	for (n12r = 0; n12r < LSQ_ENTRIES; n12r = n12r + 1)
		for (n12c = 0; n12c < 2; n12c = n12c + 1)
			lsq[n12r][n12c].sn <= lsq[n12r][n12c].sn - n;
	lsq[ndx.row][ndx.col].sn <= sn;
	if (PERFORMANCE) begin
		/* This seems not to work */
		if (agen0_argC_v) begin
			lsq[ndx.row][ndx.col].res <= agen0_argC;
			lsq[ndx.row][ndx.col].ctag <= agen0_argC_ctag;
			lsq[ndx.row][ndx.col].datav <= VAL;
		end
	end
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Commit miscellaneous instructions to machine state.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tOddballCommit;
input v;
input rob_ndx_t head;
begin
	if (v) begin
		if (!rob[head].decbus.cpytgt) begin
			if (rob[head].decbus.csr)
				case(rob[head].op.ins.csr.op[1:0])
				2'd0:	;	// readCSR
				2'd1:	tWriteCSR(rob[head].arg,{2'b0,rob[head].op.ins.csr.regno});
				2'd2:	tSetbitCSR(rob[head].arg,{2'b0,rob[head].op.ins.csr.regno});
				2'd3:	tClrbitCSR(rob[head].arg,{2'b0,rob[head].op.ins.csr.regno});
				endcase
			else if (rob[head].decbus.irq)
				;
			else if (rob[head].decbus.brk)
				tProcessExc(head,fnPCInc(rob[head].pc),FALSE,FALSE);
			else if (rob[head].decbus.rti)
				tProcessEret(rob[head].op[22:19]==5'd2,rob[head].op[23]==1'b1);
			else if (rob[head].decbus.rex)
				tRex(head,rob[head].op);
		end
	end
	else if (rob[head].op.hwi && rob[head].op.hwi_level == 6'd63)	// NMI
		tProcessExc(head,rob[head].pc,FALSE,TRUE);
	else if (rob[head].op.hwi && rob[head].op.hwi_level > sr.ipl && sr.mie)
		tProcessExc(head,rob[head].pc,TRUE,FALSE);
	// If interrupt turned out to be disabled, treat like a branch miss. The
	// pipeline needs to be flushed, and instructions fetched from the 
	// original stream.
	else if (rob[head].op.hwi) begin
		irq_wr_en <= TRUE;
		irq2_din <= {rob[head].op.hwi_swstk,rob[head].op.hwi_level,33'd0,rob[head].pc};
		excmisspc <= rob[head].op.hwipc;
		excmiss_mcip <= rob[head].op.hwi_mcip;
		excmiss <= TRUE;
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
	if (operating_mode_t'(regno[13:12]) <= sr.om) begin
		$display("regno: %h, om=%d", regno, sr.om);
		casez(regno[15:0])
		CSR_MCORENO:	res = coreno_i;
		CSR_SR:		res = sr;
		CSR_TICK:	res = tick;
		CSR_ASID:	res = asid;
		CSR_KVEC3: res = kvec[3];
		16'h3080:	res = sr_stack[0];
		(CSR_MEPC+0):	res = pc_stack[0];
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
	if (operating_mode_t'(regno[13:12]) <= sr.om) begin
		casez(regno[15:0])
		CSR_SR:		
			begin
				sr <= val;
				set_pending_ipl <= TRUE;
				next_pending_ipl <= val[7:5];
			end
		CSR_ASID: 	asid <= val;
		CSR_KVEC3:	kvec[3] <= val;
		16'h3080: sr_stack[0] <= val[31:0];
		CSR_MEPC:	pc_stack[0] <= val;
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
	if (operating_mode_t'(regno[13:12]) <= sr.om) begin
		casez(regno[15:0])
		CSR_SR:				sr <= sr | val;
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
	if (operating_mode_t'(regno[13:12]) <= sr.om) begin
		casez(regno[15:0])
		CSR_SR:				sr <= sr & ~val;
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
input irq;
input nmi;
integer nn;
reg [7:0] vecno;
reg [1:0] nom;			// next operating mode
begin
	//vecno = rob[id].imm ? rob[id].a0[8:0] : rob[id].a1[8:0];
	//vecno <= rob[id].exc;
	for (nn = 1; nn < 16; nn = nn + 1)
		sr_stack[nn] <= sr_stack[nn-1];
	sr_stack[0] <= sr;
	for (nn = 1; nn < 16; nn = nn + 1)
		pc_stack[nn] <= pc_stack[nn-1];
	pc_stack[0] <= retpc;
	sr.pl <= 8'hFF;
	if (sr.om != 2'd3)
		nom = sr.om + 2'd1;
	sr.om = nom;
	excir <= rob[id].op;
	excid <= id;
	excmiss <= FALSE;
	// Hardware interrupts automatically vector at the next_pc stage. There is no
	// need to vector here.
	if (nmi) begin
		sr.ipl <= 6'd63;
		sr.ssm <= FALSE;
		ssm_flag <= FALSE;
	end
		//	excmisspc.pc <= {kvec[sr.dbg ? 4 : 3][$bits(pc_address_t)-1:8] + 4'd11,8'h0};
	else if (irq) begin
		sr.ipl <= 6'd63;
		sr.ssm <= FALSE;
		ssm_flag <= FALSE;
	end
		// excmisspc.pc <= {kvec[sr.dbg ? 4 : 3][$bits(pc_address_t)-1:8] + 4'd10,8'h0};
	else if (rob[id].op.ssm) begin
		sr.ssm <= FALSE;
		ssm_flag <= FALSE;
		excmisspc.pc <= {kvec[sr.dbg ? 4 : nom][$bits(pc_address_t)-1:8] + 4'd1,8'h0};
		excmiss <= TRUE;
	end
	else if (vecno < 8'd16) begin
		excmisspc.pc <= {kvec[sr.dbg ? 4 : nom][$bits(pc_address_t)-1:8] + vecno,8'h0};
		excmiss <= TRUE;
	end
	else begin
		excmisspc.pc <= {kvec[sr.dbg ? 4 : nom][$bits(pc_address_t)-1:8] + 4'd13,8'h0};
		excmiss <= TRUE;
	end
//		excmisspc <= {avec[$bits(pc_address_t)-1:16] + vecno,3'h0};
end
endtask

task tRex;
input rob_ndx_t id;
input ex_instruction_t ir;
begin
	if (sr.om > ir.ins[9:8]) begin
		sr.om <= operating_mode_t'(ir.ins[9:8]);
		excid <= id;
		excmiss <= TRUE;
		if (cause[3][7:0] < 8'd16)
			excmisspc.pc <= {kvec[ir.ins[9:8]][$bits(pc_address_t)-1:4] + cause[3][3:0],4'h0};
		else
			excmisspc.pc <= {kvec[ir.ins[9:8]][$bits(pc_address_t)-1:4] + 4'd13,4'h0};
	end
	excmiss_mcip <= 12'h0;
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
	if (!restore_ssm)
		sr.ssm <= 1'b0;
	for (nn = 0; nn < 15; nn = nn + 1)
		sr_stack[nn] <= sr_stack[nn+1];
	set_pending_ipl <= TRUE;
	next_pending_ipl <= sr_stack[0].ipl;
	for (nn = 0; nn < 15; nn = nn + 1)
		pc_stack[nn] <=	pc_stack[nn+1];
	exc_ret_pc <= pc_stack[0];
end
endtask

endmodule

module modFcuMissPC(instr, bts, pc, pc_stack, micro_ip, bt, takb, argA, argB, argI, ibh, misspc, missgrp, miss_mcip, tgtpc, stomp_bno);
input pipeline_reg_t instr;
input bts_t bts;
input pc_address_ex_t pc;
input mc_address_t micro_ip;
input pc_address_ex_t [8:0] pc_stack;
input bt;
input takb;
input value_t argA;
input value_t argB;
input value_t argI;
input ibh_t ibh;
output pc_address_ex_t misspc;
output reg [2:0] missgrp;
output mc_address_t miss_mcip;
output pc_address_ex_t tgtpc;
output reg [4:0] stomp_bno;

reg [5:0] ino;
reg [5:0] ino5;
reg [63:0] disp;
always_comb
begin
//	disp = {{38{instr.ins.br.dispHi[3]}},instr.ins.br.dispHi,instr.ins.br.dispLo};
	disp = {{43{instr.ins.br.dispLo[20]}},instr.ins.br.dispLo};
	miss_mcip = 12'h1A0;
	misspc.pc = RSTPC;
	misspc.bno_t = 6'd1;
	misspc.bno_f = 6'd1;
	tgtpc = pc;
	stomp_bno = 6'd0;

	case (bts)
	BTS_DISP:
		begin
			tgtpc.pc = fnTargetIP(pc.pc,disp);
		end
	BTS_BSR:
		begin
			if (SUPPORT_IBH) begin
				ino = {2'd0,instr.ins[18:15]};
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
				tgtpc.pc = {pc[$bits(pc_address_t)-1:6] + {{37{instr.ins[39]}},instr.ins[39:17]},ino5};
			end
			else
				tgtpc.pc = pc.pc + {{27{instr.ins.bsr.disp[36]}},instr.ins.bsr.disp};
		end
	BTS_JSR:	tgtpc.pc = {{27{instr.ins.bsr.disp[36]}},instr.ins.bsr.disp};
	BTS_CALL:
		begin
			case(instr[23:22])	//??
//			2'd0:	tgtpc.pc = {pc.pc[$bits(pc_address_t)-1:16],argA[15:0]+argI[15:0]};
//			2'd1:	tgtpc = {pc[$bits(pc_address_t)-1:32],argA[31:0]+argI[31:0]};
			default: tgtpc.pc = argA + argI;
			endcase
		end
	// Must be tested before Ret
	BTS_RTI:
		begin
			tgtpc.pc = (instr.ins.rtd.typ==2'd1 ? pc_stack[1].pc : pc_stack[0].pc) + (instr.ins.rtd.offs * 2'd3);
		end
	BTS_RET:
		begin
			tgtpc.pc = argA + (instr.ins.rtd.offs * 2'd3);
		end
	default:
		tgtpc.pc = RSTPC;
	endcase

	case(bts)
	/*
	BTS_REG:
		 begin
			misspc = bt ? tpc : argC + {{53{instr[39]}},instr[39:31],instr[12:11]};
		end
	*/
	BTS_DISP:
		begin
			case({bt,takb})
			2'b00:
				begin
					misspc = tgtpc;
					miss_mcip = instr.ins.mcb.disp;
					stomp_bno = pc.bno_t;
					stomp_bno = 5'd0;
				end
			2'b01:
				begin
					misspc = tgtpc;
					miss_mcip = instr.ins.mcb.disp;
					stomp_bno = pc.bno_t;
					stomp_bno = 5'd0;
				end
			2'b10:
				begin
					misspc = pc + 4'd8;
					miss_mcip = micro_ip + 3'd4;
					stomp_bno = tgtpc.bno_t;
					stomp_bno = 5'd0;
				end
			2'b11:
				begin
					misspc = pc + 4'd8;
					miss_mcip = micro_ip + 3'd4;
					stomp_bno = tgtpc.bno_t;
					stomp_bno = 5'd0;
				end
			endcase
//			misspc = bt ? pc + 4'd5 : pc + {{47{instr[39]}},instr[39:25],instr[12:11]};
		end
	BTS_JSR,BTS_BSR:
		begin
			misspc = tgtpc;
			stomp_bno = tgtpc.bno_t;
			stomp_bno = 5'd0;
		end
	BTS_CALL:
		begin
			misspc = tgtpc;
			stomp_bno = tgtpc.bno_t;
			stomp_bno = 5'd0;
		end
	// Must be tested before Ret
	BTS_RTI:
		begin
			misspc = tgtpc;
			stomp_bno = tgtpc.bno_t;
			stomp_bno = 5'd0;
		end
	BTS_RET:
		begin
			misspc = tgtpc;
			stomp_bno = tgtpc.bno_t;
			stomp_bno = 5'd0;
		end
	default:
		misspc = tgtpc;
	endcase
end

always_comb
begin
	/*
	if (misspc[5:0] >= ibh.offs[3])
		missgrp = 3'd4;
	else if (misspc[5:0] >= ibh.offs[2])
		missgrp = 3'd3;
	else if (misspc[5:0] >= ibh.offs[1])
		missgrp = 3'd2;
	else if (misspc[5:0] >= ibh.offs[0])
		missgrp = 3'd1;
	else
	*/
		missgrp = 3'd0;
end

endmodule
