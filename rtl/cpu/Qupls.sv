// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
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
// ============================================================================

import const_pkg::*;
import fta_bus_pkg::*;
import Qupls_cache_pkg::*;
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

module Qupls(coreno_i, rst_i, clk_i, clk2x_i, irq_i, vect_i,
	fta_req, fta_resp, snoop_adr, snoop_v, snoop_cid);
parameter CORENO = 6'd1;
parameter CID = 6'd1;
input [63:0] coreno_i;
input rst_i;
input clk_i;
input clk2x_i;
input [2:0] irq_i;
input [8:0] vect_i;
output fta_cmd_request128_t fta_req;
input fta_cmd_response128_t fta_resp;
input QuplsPkg::address_t snoop_adr;
input snoop_v;
input [5:0] snoop_cid;

fta_cmd_request128_t ftatm_req;
fta_cmd_response128_t ftatm_resp;
fta_cmd_request128_t ftaim_req;
fta_cmd_response128_t ftaim_resp;
fta_cmd_request128_t [1:0] ftadm_req;
fta_cmd_response128_t [1:0] ftadm_resp;


integer nn,mm,n2,n3,n4,m4,n5,n6,n7,n8,n9,n10,n11,n12,n13,n14,n15,n17;
integer n16r, n16c, n12r, n12c, n14r, n14c, n17r, n17c, n18r, n18c;
integer n19;
genvar g,h;
rndx_t alu0_re;
reg [127:0] message;
wire rst;
wire clk;
wire clk2x;
assign rst = rst_i;
reg [3:0] rstcnt;
reg [3:0] panic;
reg int_commit;		// IRQ committed
// hirq squashes the pc increment if there's an irq.
// Normally atom_mask is zero.
reg hirq;
pc_address_t misspc;
wire [$bits(pc_address_t)-1:6] missblock;
reg [2:0] missgrp;
wire [2:0] missino;

instruction_t missir;
wire [11:0] next_micro_ip;

reg [39:0] I;	// Committed instructions

reg [PREGS-1:0] free_bitlist;
rob_ndx_t agen0_rndx, agen1_rndx;

op_src_t alu0_argA_src;
op_src_t alu0_argB_src;
op_src_t alu0_argC_src;

value_t rfo_alu0_argA;
value_t rfo_alu0_argB;
value_t rfo_alu0_argC;
value_t rfo_alu1_argA;
value_t rfo_alu1_argB;
value_t rfo_fpu0_argA;
value_t rfo_fpu0_argB;
value_t rfo_fpu0_argC;
value_t rfo_fpu1_argA;
value_t rfo_fpu1_argB;
value_t rfo_fpu1_argC;
value_t rfo_fcu_argA;
value_t rfo_fcu_argB;
value_t rfo_agen0_argA;
value_t rfo_agen1_argA;
value_t rfo_agen0_argB;
value_t rfo_agen1_argB;
value_t rfo_store_argC;
value_t store_argC;
value_t load_res;
value_t ma0,ma1;				// memory address

pregno_t alu0_argA_reg;
pregno_t alu0_argB_reg;
pregno_t alu0_argC_reg;

pregno_t alu1_argA_reg;
pregno_t alu1_argB_reg;

pregno_t fpu0_argA_reg;
pregno_t fpu0_argB_reg;
pregno_t fpu0_argC_reg;

pregno_t fpu1_argA_reg;
pregno_t fpu1_argB_reg;
pregno_t fpu1_argC_reg;

pregno_t fcu_argA_reg;
pregno_t fcu_argB_reg;

pregno_t agen0_argA_reg;
pregno_t agen0_argB_reg;

pregno_t agen1_argA_reg;
pregno_t agen1_argB_reg;

pregno_t store_argC_reg;

pregno_t [14:0] rf_reg;
value_t [14:0] rfo;

rob_entry_t [ROB_ENTRIES-1:0] rob;
reg [1:0] robentry_islot [0:ROB_ENTRIES-1];
wire [1:0] next_robentry_islot [0:ROB_ENTRIES-1];
reg [1:0] lsq_islot [0:LSQ_ENTRIES*2-1];
rob_bitmask_t robentry_stomp;
rob_bitmask_t robentry_issue;
rob_bitmask_t robentry_fpu_issue;
rob_bitmask_t robentry_fcu_issue;
rob_bitmask_t robentry_agen_issue;
lsq_entry_t [1:0] lsq [0:7];
lsq_ndx_t lq_tail, lq_head;
wire nq;

reg brtgtv;
pc_address_t brtgt;
reg pc_in_sync;

rob_ndx_t tail0, tail1, tail2, tail3, tail4, tail5, tail6, tail7;
rob_ndx_t head0, head1, head2, head3;
lsq_ndx_t store_tail;
reg_bitmask_t reg_bitmask;
reg_bitmask_t Ra_bitmask;
reg_bitmask_t Rt_bitmask;
reg ls_bmf;		// load or store bitmask flag
instruction_t hold_ir;
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

always_comb tail1 = (tail0 + 1) % ROB_ENTRIES;
always_comb tail2 = (tail0 + 2) % ROB_ENTRIES;
always_comb tail3 = (tail0 + 3) % ROB_ENTRIES;
always_comb tail4 = (tail0 + 4) % ROB_ENTRIES;
always_comb tail5 = (tail0 + 5) % ROB_ENTRIES;
always_comb tail6 = (tail0 + 6) % ROB_ENTRIES;
always_comb tail7 = (tail0 + 7) % ROB_ENTRIES;
always_comb head1 = (head0 + 1) % ROB_ENTRIES;
always_comb head2 = (head0 + 2) % ROB_ENTRIES;
always_comb head3 = (head0 + 3) % ROB_ENTRIES;

decode_bus_t db0_q, db1_q, db2_q, db3_q;				// Queue stage inputs
instruction_t ins0_q, ins1_q, ins2_q, ins3_q;
decode_bus_t db0_r, db1_r, db2_r, db3_r;				// Regfetch/rename stage inputs
instruction_t ins0_r, ins1_r, ins2_r, ins3_r;

reg [3:0] regx0;
reg [3:0] regx1;
reg [3:0] regx2;
reg [3:0] regx3;
wire [3:0] mc_regx0;
wire [3:0] mc_regx1;
wire [3:0] mc_regx2;
wire [3:0] mc_regx3;
rob_ndx_t alu0_sndx;
rob_ndx_t alu1_sndx;
wire alu0_sv;
wire alu1_sv;

// ALU done and idle are almost the same, but idle is sticky and set
// if the ALU is not busy, whereas done pulses at the end of an ALU
// operation.
reg alu0_idle;
reg alu0_done;
reg alu0_available;
reg alu0_dataready;
instruction_t alu0_instr;
reg alu0_div;
value_t alu0_argA;
value_t alu0_argB;
value_t alu0_argC;
value_t alu0_argI;
pregno_t alu0_Rt;
aregno_t alu0_aRt;
reg [2:0] alu0_cs;
reg alu0_bank;
value_t alu0_cmpo;
pc_address_t alu0_pc;
value_t alu0_res;
rob_ndx_t alu0_id;
cause_code_t alu0_exc = FLT_NONE;
reg alu0_out;
wire mul0_done;
value_t div0_q,div0_r;
wire div0_done,div0_dbz;
reg alu0_ld;

reg alu1_idle;
reg alu1_done;
reg alu1_available;
reg alu1_dataready;
instruction_t alu1_instr;
reg alu1_div;
value_t alu1_argA;
value_t alu1_argB;
value_t alu1_argC;
value_t alu1_argI;
reg [2:0] alu1_cs;
pregno_t alu1_Rt;
aregno_t alu1_aRt;
reg alu1_bank;
value_t alu1_cmpo;
bts_t alu1_bts;
pc_address_t alu1_pc;
value_t alu1_res;
rob_ndx_t alu1_id;
cause_code_t alu1_exc;
reg alu1_out;
wire mul1_done;
value_t div1_q,div1_r;
wire div1_done,div1_dbz;
reg alu1_ld;

reg fpu0_idle;
reg fpu0_done;
reg fpu0_available;
instruction_t fpu0_instr;
reg [2:0] fpu0_rmd;
value_t fpu0_argA;
value_t fpu0_argB;
value_t fpu0_argC;
value_t fpu0_argD;
value_t fpu0_argT;
value_t fpu0_argP;
value_t fpu0_argI;	// only used by BEQ
pregno_t fpu0_Rt;
aregno_t fpu0_aRt;
reg [2:0] fpu0_cs;
reg fpu0_bank;
pc_address_t fpu0_pc;
value_t fpu0_res;
rob_ndx_t fpu0_id;
cause_code_t fpu0_exc = FLT_NONE;
reg fpu0_out;
wire fpu_done1;

reg fpu1_idle;
reg fpu1_done;
reg fpu1_available;
reg fpu1_dataready;
instruction_t fpu1_instr;
reg [2:0] fpu1_rmd;
value_t fpu1_argA;
value_t fpu1_argB;
value_t fpu1_argC;
value_t fpu1_argD;
value_t fpu1_argT;
value_t fpu1_argP;
value_t fpu1_argI;	// only used by BEQ
pregno_t fpu1_Rt;
aregno_t fpu1_aRt;
reg [2:0] fpu1_cs;
reg fpu1_bank;
pc_address_t fpu1_pc;
value_t fpu1_res;
rob_ndx_t fpu1_id;
cause_code_t fpu1_exc = FLT_NONE;
wire        fpu1_v;
wire fpu1_done1;

reg fcu_idle;
reg fcu_available;
instruction_t fcu_instr;
instruction_t fcu_missir;
reg        fcu_bt;
bts_t fcu_bts;
value_t fcu_argA;
value_t fcu_argB;
value_t fcu_argBr;
value_t fcu_argI;	// only used by BEQ
pc_address_t fcu_pc;
value_t fcu_res;
rob_ndx_t fcu_id;
cause_code_t fcu_exc;
reg fcu_v, fcu_v2, fcu_v3, fcu_v4, fcu_v5, fcu_v6;
reg fcu_branchmiss;
pc_address_t fcu_misspc, fcu_misspc1;
reg [2:0] fcu_missgrp;
reg [2:0] fcu_missino;
reg takb;
reg fcu_done;
rob_ndx_t fcu_rndx;

wire tlb0_v, tlb1_v;

reg agen0_idle;
instruction_t agen0_op;
rob_ndx_t agen0_id;
value_t agen0_argA;
value_t agen0_argB;
value_t agen0_argI;
pc_address_t agen0_pc;
cause_code_t agen0_exc;

reg agen1_idle = 1'b1;
instruction_t agen1_op;
rob_ndx_t agen1_id;
value_t agen1_argA;
value_t agen1_argB;
value_t agen1_argI;
pc_address_t agen1_pc;
cause_code_t agen1_exc;

reg lsq0_idle = 1'b1;
reg lsq1_idle = 1'b1;

address_t tlb0_res, tlb1_res;

reg [2:0] branchmiss_state;
reg [4:0] excid;
pc_address_t excmisspc;
reg [2:0] excmissgrp;
reg excmiss;
instruction_t excir;

wire dram_avail;
wire [1:0] dram0;	// state of the DRAM request
wire [1:0] dram1;	// state of the DRAM request

value_t dram_bus0;
regspec_t dram_tgt0;
reg  [4:0] dram_id0;
cause_code_t dram_exc0;
reg        dram_v0;
value_t dram_bus1;
regspec_t dram_tgt1;
reg  [4:0] dram_id1;
cause_code_t dram_exc1;
reg        dram_v1;

reg [639:0] dram0_data, dram0_datah;
virtual_address_t dram0_vaddr, dram0_vaddrh;
physical_address_t dram0_paddr, dram0_paddrh;
reg [79:0] dram0_sel, dram0_selh;
instruction_t dram0_op;
memsz_t dram0_memsz;
rob_ndx_t dram0_id;
reg dram0_load;
reg dram0_loadz;
reg dram0_store;
pregno_t dram0_Rt, dram_Rt0;
aregno_t dram0_aRt;
reg dram0_bank;
cause_code_t dram0_exc;
reg dram0_ack;
fta_tranid_t dram0_tid;
wire dram0_more;
reg dram0_hi;
reg dram0_erc;
reg [9:0] dram0_shift;
reg dram0_stomp;
reg [11:0] dram0_tocnt;
reg dram0_done;

reg [639:0] dram1_data, dram1_datah;
virtual_address_t dram1_vaddr, dram1_vaddrh;
physical_address_t dram1_paddr, dram1_paddrh;
reg [79:0] dram1_sel, dram1_selh;
instruction_t dram1_op;
memsz_t dram1_memsz;
rob_ndx_t dram1_id;
reg dram1_load;
reg dram1_loadz;
reg dram1_store;
pregno_t dram1_Rt, dram_Rt1;
aregno_t dram1_aRt;
reg dram1_bank;
cause_code_t dram1_exc;
reg dram1_ack;
fta_tranid_t dram1_tid;
wire dram1_more;
reg dram1_erc;
reg dram1_hi;
reg [9:0] dram1_shift;
reg dram1_stomp;
reg [11:0] dram1_tocnt;
reg dram1_done;

reg [2:0] dramN [0:NDATA_PORTS-1];
reg [511:0] dramN_data [0:NDATA_PORTS-1];
reg [63:0] dramN_sel [0:NDATA_PORTS-1];
address_t dramN_addr [0:NDATA_PORTS-1];
address_t dramN_vaddr [0:NDATA_PORTS-1];
address_t dramN_paddr [0:NDATA_PORTS-1];
reg [NDATA_PORTS-1:0] dramN_load;
reg [NDATA_PORTS-1:0] dramN_loadz;
reg [NDATA_PORTS-1:0] dramN_store;
reg [NDATA_PORTS-1:0] dramN_ack;
reg [NDATA_PORTS-1:0] dramN_erc;
fta_tranid_t dramN_tid [0:NDATA_PORTS-1];
memsz_t dramN_memsz;

reg [2:0] cmtcnt;
pc_address_t commit_pc0, commit_pc1, commit_pc2, commit_pc3;
pc_address_t commit_brtgt0;
pc_address_t commit_brtgt1;
pc_address_t commit_brtgt2;
pc_address_t commit_brtgt3;
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
cause_code_t [3:0] cause;
status_reg_t sr_stack [0:8];
status_reg_t sr;
pc_address_t [8:0] pc_stack;
mc_stack_t [8:0] mc_stack;			// micro-code exception stack
wire [2:0] im = sr.ipl;
reg [5:0] regset = 6'd0;
asid_t asid;
asid_t ip_asid;
pc_address_t [3:0] kvec;
pc_address_t avec;
rob_bitmask_t err_mask;
reg ERC = 1'b0;

reg [2:0] atom_mask;

assign clk = clk_i;				// convenience
assign clk2x = clk2x_i;

function pc_address_t fnTargetIP;
input pc_address_t ip;
input value_t tgt;
reg [5:0] lo;
begin
	lo = {tgt[3:0],2'b0} + tgt[3:0];
	fnTargetIP = {ip[$bits(pc_address_t)-1:6]+tgt[$bits(value_t)-1:4],lo};
end
endfunction

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

assign rf_reg[14] = store_argC_reg;

assign rfo_alu0_argA = rfo[0];
assign rfo_alu0_argB = rfo[1];
assign rfo_alu0_argC = rfo[2];

assign rfo_alu1_argA = rfo[3];
assign rfo_alu1_argB = rfo[4];

assign rfo_fpu0_argA = rfo[5];
assign rfo_fpu0_argB = rfo[6];
assign rfo_fpu0_argC = rfo[7];

assign rfo_fcu_argA = rfo[8];
assign rfo_fcu_argB = rfo[9];

assign rfo_agen0_argA = rfo[10];
assign rfo_agen0_argB = rfo[11];

assign rfo_agen1_argA = rfo[12];
assign rfo_agen1_argB = rfo[13];

assign rfo_store_argC = rfo[14];

ICacheLine ic_line_hi, ic_line_lo;

//
// FETCH
//

pc_address_t pc, pc0, pc1, pc2, pc3, pc4, pc5, pc6, pc7, pc8;
reg [5:0] off0, off1, off2, off3, off4, off5, off6, off7;
pc_address_t pc0_d, pc1_d, pc2_d, pc3_d, pc4_d, pc5_d, pc6_d, pc7_d, pc8_d;
pc_address_t pc0_q, pc1_q, pc2_q, pc3_q, pc4_q, pc5_q, pc6_q, pc7_q, pc8_q;
pc_address_t pc0_r, pc1_r, pc2_r, pc3_r, pc4_r, pc5_r, pc6_r, pc7_r, pc8_r;
pc_address_t pc0_x, pc1_x, pc2_x, pc3_x, pc4_x, pc5_x, pc6_x, pc7_x, pc8_x;
pc_address_t next_pc;
reg [2:0] grp_d, grp_q, grp_r;
wire ntakb,ptakb;
reg invce = 1'b0;
reg dc_invline = 1'b0;
reg dc_invall = 1'b0;
reg ic_invline = 1'b0;
reg ic_invall = 1'b0;
ICacheLine ic_line_o;

wire wr_ic;
wire ic_valid;
address_t ic_miss_adr;
asid_t ic_miss_asid;
wire [1:0] ic_wway;

reg [1023:0] ic_line;
wire [1023:0] ic_line2;
reg [1023:0] ic_line_x;
instruction_t ins0_d, ins1_d, ins2_d, ins3_d, ins4_d, ins5_d, ins6_d, ins7_d, ins8_d;
reg ins0_v, ins1_v, ins2_v, ins3_v;
reg [XWID-1:0] ins_v;
reg insnq0,insnq1,insnq2,insnq3;
reg [XWID-1:0] qd, cqd, qs;
reg [XWID-1:0] next_cqd;
wire pe_allqd;
reg fetch_new;
tlb_entry_t tlb_pc_entry;
pc_address_t pc_tlb_res;
wire pc_tlb_v;

wire pt0_d, pt1_d, pt2_d, pt3_d;		// predict taken branches
reg pt0_r, pt1_r, pt2_r, pt3_r;
reg pt0_q, pt1_q, pt2_q, pt3_q;
reg regs;

reg branchmiss, branchmiss_next;
rob_ndx_t missid;

reg [11:0] micro_ip;
reg [11:0] mip0;
reg [11:0] mip1;
reg [11:0] mip2;
reg [11:0] mip3;
reg mip0v;
reg mip1v;
reg mip2v;
reg mip3v;
reg nmip;
reg mipv, mipv2, mipv3, mipv4;

instruction_t micro_ir;
instruction_t mc_ins0;
instruction_t mc_ins1;
instruction_t mc_ins2;
instruction_t mc_ins3;
instruction_t mc_ins4;
instruction_t mc_ins5;
instruction_t mc_ins6;
instruction_t mc_ins7;
instruction_t mc_ins8;

wire mc_last0;
wire mc_last1;
wire mc_last2;
wire mc_last3;

value_t agen0_res, agen1_res;
wire tlb_miss0, tlb_miss1;
wire tlb_missack;
wire tlb_wr;
wire tlb_way;
tlb_entry_t tlb_entry0, tlb_entry1, tlb_entry;
wire [6:0] tlb_entryno;
reg agen0_load, agen1_load;
reg agen0_store, agen1_store;
wire tlb0_load, tlb0_store;
wire tlb1_load, tlb1_store;
reg stall_load, stall_store;
reg stall_tlb0 =1'd0, stall_tlb1=1'd0;


always_comb
	ins_v = {ins0_v,ins1_v,ins2_v,ins3_v};

// Track which instructions are valid. Instructions will be valid right after a
// cache line has been fetched. As instructions are queued they are marked
// invalid. insx_v really only applies when instruction queuing takes more than
// one clock.

always_ff @(posedge clk)
if (rst) begin
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
		ins0_v <= ins0_v & ~(qd[0]|qs[0]);
		ins1_v <= ins1_v & ~(qd[1]|qs[1]);
		if (XWID==3)
			ins2_v <= ins2_v & ~(qd[2]|qs[2]);
		else
			ins2_v <= TRUE;
		if (XWID==4)
			ins3_v <= ins3_v & ~(qd[3]|qs[3]);
		else
			ins3_v <= TRUE;
	end
end


wire ftaim_full, ftadm_full;
wire ihito,ihit,ihit2;
reg ihit_x, ihit_d, ihit_r, ihit_q;
wire icnop;
pc_address_t icpc;
wire [2:0] igrp;
reg [7:0] length_byte;
always_comb length_byte = ic_line >> {icpc[5:0],3'd0};

Qupls_icache
#(.CORENO(CORENO),.CID(0))
uic1
(
	.rst(rst),
	.clk(clk),
	.invce(invce),
	.snoop_adr(snoop_adr),
	.snoop_v(snoop_v),
	.snoop_cid(snoop_cid),
	.invall(ic_invall),
	.invline(ic_invline),
	.nop(brtgtv),
	.nop_o(icnop),
	.ip_asid(ip_asid),
	.ip(pc),
	.ip_o(icpc),
	.ihit_o(ihito),
	.ihit(ihit),
	.ic_line_hi_o(ic_line_hi),
	.ic_line_lo_o(ic_line_lo),
	.ic_valid(ic_valid),
	.miss_vadr(ic_miss_adr),
	.miss_asid(ic_miss_asid),
	.ic_line_i(ic_line_o),
	.wway(ic_wway),
	.wr_ic(wr_ic)
);

Qupls_icache_ctrl
#(.CORENO(CORENO),.CID(0))
icctrl1
(
	.rst(rst),
	.clk(clk),
	.wbm_req(ftaim_req),
	.wbm_resp(ftaim_resp),
	.ftam_full(ftaim_resp.rty),
	.hit(ihit),
	.tlb_v(pc_tlb_v),
	.miss_vadr(ic_miss_adr),
	.miss_padr({tlb_pc_entry.pte.ppn,pc_tlb_res[15:0]}),
	.miss_asid(tlb_pc_entry.vpn.asid),
	.wr_ic(wr_ic),
	.way(ic_wway),
	.line_o(ic_line_o),
	.snoop_adr(snoop_adr),
	.snoop_v(snoop_v),
	.snoop_cid(snoop_cid)
);

Qupls_btb ubtb1
(
	.rst(rst),
	.clk(clk),
	.en(!hold_ins),
	.rclk(~clk),
	.block_header(ibh_t'(ic_line[511:480])),
	.igrp(igrp),
	.length_byte(length_byte),
	.pc(icpc),
	.pc0(pc0),
	.pc1(pc1),
	.pc2(pc2),
	.pc3(pc3),
	.pc4(XWID==2 ? PC2:XWID==3 ? pc3:pc4),
	.next_pc(next_pc),
	.takb(ntakb),
	.branchmiss(branchmiss_state == 3'd2),
	.branchmiss_state(branchmiss_state),
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
	.commit_grp3(commit_grp3)
);

gselectPredictor ugsp1
(
	.rst(rst),
	.clk(clk),
	.en(1'b1),
	.xbr0(commit_br0),
	.xbr1(commit_br1),
	.xbr2(commit_br2),
	.xbr3(commit_br3),
	.xip0(commit_pc0), 
	.xip1(commit_pc1),
	.xip2(commit_pc2),
	.xip3(commit_pc3),
	.takb0(commit_takb0),
	.takb1(commit_takb1),
	.takb2(commit_takb2),
	.takb3(commit_takb3),
	.ip0(pc0_x),
	.predict_taken0(pt0_d),
	.ip1(pc1_x),
	.predict_taken1(pt1_d),
	.ip2(pc2_x),
	.predict_taken2(pt2_d),
	.ip3(pc3_x),
	.predict_taken3(pt3_d)
);

pc_address_t pco;
wire [4:0] len0, len1, len2, len3, len4, len5, len6, len7;
wire [2:0] igrp2;

/*
// missblock is known right away.
// miss group and instruction number are not known until after the lengths are
// calculated.

generate begin : gNormAddr
	if (SUPPORT_IBH) begin
		Qupls_norm_addr uan1
		(
			.misspc(misspc),
			.ibh(ibh_t'(ic_line2[511:488])),
			.len0(len0),
			.len1(len1),
			.len2(len2),
			.missblock(missblock),
			.missgrp(fcu_missgrp),
			.missinsn(fcu_missino)
		);
	end
end
endgenerate
*/

// 3 cycle latency
// If not supporting variable lengths the latency is reduced.
generate begin : gInsLengths
	if (SUPPORT_VLI) begin
		Qupls_ins_lengths_L0 uils1
		(
			.rst_i(rst),
			.line_i(ic_line),
			.line_o(ic_line2),
			.hit_i(ihito),
			.hit_o(ihit2),
			.pc_i(icpc),
			.pc_o(pco),
			.grp_i(igrp),
			.grp_o(igrp2),
			.len0_o(len0),
			.len1_o(len1),
			.len2_o(len2),
			.len3_o(len3),
			.len4_o(len4),
			.len5_o(len5),
			.len6_o(len6),
			.len7_o(len7)
		);
	end
	else if (SUPPORT_IBH) begin
		Qupls_ins_lengths uils1
		(
			.rst_i(rst),
			.clk_i(clk),
			.en_i(!hold_ins),
			.line_i(ic_line),
			.line_o(ic_line2),
			.hit_i(ihito),
			.hit_o(ihit2),
			.pc_i(icpc),
			.pc_o(pco),
			.grp_i(igrp),
			.grp_o(igrp2),
			.len0_o(len0),
			.len1_o(len1),
			.len2_o(len2),
			.len3_o(len3),
			.len4_o(len4),
			.len5_o(len5),
			.len6_o(len6),
			.len7_o(len7)
		);
	end
	else begin
		assign ic_line2 = ic_line;
		assign ihit2 = ihito;
		assign pco = icpc;
		assign len0 = 4'd5;
		assign len1 = 4'd5;
		assign len2 = 4'd5;
		assign len3 = 4'd5;
		assign len4 = 4'd5;
		assign len5 = 4'd5;
		assign len6 = 4'd5;
		assign len7 = 4'd5;
	end
end
endgenerate

always_comb pc0 = pco + (SUPPORT_VLIB ? 5'd1 : 5'd0);
always_comb pc1 = pc0 + len0;
always_comb pc2 = pc1 + len1;
always_comb pc3 = pc2 + len2;
always_comb pc4 = pc3 + len3;
/*
always_comb pc5 = pc4 + len4;
always_comb pc6 = pc5 + len5;
always_comb pc7 = pc6 + len6;
always_comb pc8 = pc7 + len7;
*/
//always_comb pc7 = {pc6[43:12] + len6,12'h0};

// qd indicates which instructions will queue in a given cycle.
// qs indicates which instructions are stomped on.
always_comb
begin
	qd = {XWID{1'd0}};
	qs = {XWID{1'd0}};
	if ((branchmiss || branchmiss_state < 3'd4) && |robentry_stomp)
		;
	else if ((ihito || mipv) && !stallq && 
		rob[tail0].v==INV && rob[tail1].v==INV && rob[tail2].v==INV && rob[tail3].v==INV)
		if (XWID==2)
			case (~cqd[1:0])

	    2'b00: ; // do nothing

	    2'b01:	
	    	if (rob[tail0].v==INV)
	    		qd = qd | 2'b01;
	    2'b10:	
	    	if (rob[tail0].v==INV)
	    		qd = qd | 2'b10;
	    2'b11:
	    	if (rob[tail0].v==INV) begin
	    		qd = qd | 2'b10;
	    		if (!pt2_q && !mip2v && !db2_q.regs) begin
	    			if (rob[tail1].v==INV)
	    				qd = qd | 2'b01;
	    		end
	    		else
	    			qs = qs | 2'b01;
	    	end
	    endcase
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
	    		if (!pt2_q && !mip2v && !db2_q.regs) begin
	    			if (rob[tail1].v==INV)
	    				qd = qd | 3'b001;
	    		end
	    		else
	    			qs = qs | 3'b001;
	    	end
	    3'b100:	
	    	if (rob[tail0].v==INV)
	    		qd = qd | 3'b100;
	    3'b101:
	    	if (rob[tail0].v==INV) begin
	    		qd = qd | 3'b100;
	    		if (!pt1_q && !mip1v && !db1_q.regs) begin
	    			if (rob[tail1].v==INV)
		    			qd = qd | 3'b001;
		    	end
		    	else
		    		qs = qs | 3'b001;
	    	end
	    3'b110:
	    	if (rob[tail0].v==INV) begin
	    		qd = qd | 3'b100;
	    		if (!pt1_q && !mip1v && !db1_q.regs) begin
	    			if (rob[tail1].v==INV)
	    				qd = qd | 3'b10;
	    		end
	    		else
		    		qs = qs | 3'b010;
	    	end
	    3'b111:
	    	if (rob[tail0].v==INV) begin
	    		qd = qd | 3'b100;
	    		if (!pt1_q && !mip1v && !db1_q.regs) begin
		    		if (rob[tail1].v==INV) begin
		    			qd = qd  | 3'b010;
		    			if (!pt2_q && !mip2v && !db2_q.regs) begin
		    				if (rob[tail2].v==INV)
			    				qd = qd  | 3'b001;
			    		end
			    		else
			    			qs = qs | 3'b001;
			    	end
	    		end
	    		else
	    			qs = qs | 3'b011;
	    	end
	    endcase
		else
		case (~cqd)

    4'b0000: ; // do nothing

    4'b0001:	
    	if (rob[tail0].v==INV)
    		qd = qd | 4'b0001;
    4'b0010:	
    	if (rob[tail0].v==INV)
    		qd = qd | 4'b0010;
    4'b0011:
    	if (rob[tail0].v==INV) begin
    		qd = qd | 4'b0010;
    		if (!pt2_q && !mip2v && !db2_q.regs) begin
    			if (rob[tail1].v==INV)
    				qd = qd | 4'b0001;
    		end
    		else
    			qs = qs | 4'b0001;
    	end
    4'b0100:	
    	if (rob[tail0].v==INV)
    		qd = qd | 4'b0100;
    4'b0101:
    	if (rob[tail0].v==INV) begin
    		qd = qd | 4'b0100;
    		if (!pt1_q && !mip1v && !db1_q.regs) begin
    			if (rob[tail1].v==INV)
	    			qd = qd | 4'b0001;
	    	end
	    	else
	    		qs = qs | 4'b0001;
    	end
    4'b0110:
    	if (rob[tail0].v==INV) begin
    		qd = qd | 4'b0100;
    		if (!pt1_q && !mip1v && !db1_q.regs) begin
    			if (rob[tail1].v==INV)
    				qd = qd | 4'b0010;
    		end
    		else
	    		qs = qs | 4'b0010;
    	end
    4'b0111:
    	if (rob[tail0].v==INV) begin
    		qd = qd | 4'b0100;
    		if (!pt1_q && !mip1v && !db1_q.regs) begin
	    		if (rob[tail1].v==INV) begin
	    			qd = qd  | 4'b0010;
	    			if (!pt2_q && !mip2v && !db2_q.regs) begin
	    				if (rob[tail2].v==INV)
		    				qd = qd  | 4'b0001;
		    		end
		    		else
		    			qs = qs | 4'b0001;
		    	end
    		end
    		else
    			qs = qs | 4'b0011;
    	end
    4'b1000:
    	if (rob[tail0].v==INV)
	   		qd = qd | 4'b1000;
    4'b1001:
    	if (rob[tail0].v==INV) begin
    		qd = qd | 4'b1000;
    		if (!pt0_q && !mip0v && !db0_q.regs) begin
    			if (rob[tail1].v==INV)
	    			qd = qd | 4'b0001;
	    	end
	    	else
	    		qs = qs | 4'b0001;
    	end
    4'b1010:
    	if (rob[tail0].v==INV) begin
    		qd = qd | 4'b1000;
    		if (!pt0_q && !mip0v && !db0_q.regs) begin
    			if (rob[tail1].v==INV)
	    			qd = qd | 4'b0010;
	    	end
	    	else
	    		qs = qs | 4'b0010;
    	end
    4'b1011:
    	if (rob[tail0].v==INV) begin
    		qd = qd | 4'b1000;
    		if (!pt0_q && !mip0v && !db0_q.regs) begin
    			if (rob[tail1].v==INV) begin
	    			qd = qd | 4'b0010;
    				if (!pt2_q && !mip2v && !db2_q.regs) begin
    					if (rob[tail2].v==INV)
		    				qd = qd | 4'b0001;
		    		end
		    		else
		    			qs = qs | 4'b0001;
		    	end
		    	else
		    		qs = qs | 4'b0011;
    		end
    	end
    4'b1100:
    	if (rob[tail0].v==INV) begin
    		qd = qd | 4'b1000;
    		if (!pt0_q && !mip0v && !db0_q.regs) begin
    			if (rob[tail1].v==INV)
	    			qd = qd | 4'b0100;
	    	end
	    	else
	    		qs = qs | 4'b0100;
    	end
    4'b1101:
    	if (rob[tail0].v==INV) begin
    		qd = qd | 4'b1000;
    		if (!pt0_q && !mip0v && !db0_q.regs) begin
    			if (rob[tail1].v==INV) begin
		    		qd = qd | 4'b0100;
	    			if (!pt1_q && !mip1v && !db1_q.regs) begin
	    				if (rob[tail2].v==INV)
			    			qd = qd | 4'b0001;
			    	end
			    	else
			    		qs = qs | 4'b0001;
			    end
    		end
    		else
    			qs = qs | 4'b0101;
    	end
    4'b1110:
    	if (rob[tail0].v==INV) begin
    		qd = qd | 4'b1000;
    		if (!pt0_q && !mip0v && !db0_q.regs) begin
    			if (rob[tail1].v==INV) begin
		    		qd = qd | 4'b0100;
	    			if (!pt1_q && !mip1v && !db1_q.regs) begin
	    				if (rob[tail2].v==INV)
			    			qd = qd | 4'b0010;
			    	end
			    	else
			    		qs = qs | 4'b0010;
		    	end
    		end
    		else
    			qs = qs | 4'b0110;
    	end
    4'b1111:
    	if (rob[tail0].v==INV) begin
    		qd = qd | 4'b1000;
    		if (!pt0_q && !mip0v && !db0_q.regs) begin
    			if (rob[tail1].v==INV) begin
	    			qd = qd | 4'b0100;
	    			if (!pt1_q && !mip1v && !db1_q.regs) begin
	    				if (rob[tail2].v==INV) begin
			    			qd = qd | 4'b0010;
		    				if (!pt2_q && !mip2v && !db2_q.regs) begin
		    					if (rob[tail3].v==INV)
				    				qd = qd | 4'b0001;
				    		end
				    		else
				    			qs = qs | 4'b0001;
			    		end
			    	end
			    	else
			    		qs = qs | 4'b0011;
    			end
    		end
    		else
    			qs = qs | 4'b0111;
    	end
    endcase
end

// cumulative queued.
always_comb
	next_cqd = cqd | qd | qs;
always_ff @(posedge clk)
if (rst)
	cqd <= {XWID{1'd0}};
else begin
	cqd <= next_cqd;
	if (next_cqd == {XWID{1'b1}})
		cqd <= {XWID{1'd0}};
end

reg allqd;
edge_det ued1 (.rst(rst), .clk(clk), .ce(1'b1), .i(next_cqd=={XWID{1'b1}}), .pe(pe_allqd), .ne(), .ee());

always_comb
	fetch_new = (ihito & ~hirq & (pe_allqd|allqd) & ~mipv & ~branchmiss) |
							(mipv & ~hirq & (pe_allqd|allqd) & ~branchmiss);

always_comb
	hold_ins = |reg_bitmask || mipv;

always_ff @(posedge clk)
if (rst) begin
	pc <= RSTPC;
	allqd <= 1'b1;
end
else begin
	if (pe_allqd & ~(ihito & ~hirq))
		allqd <= 1'b1;
	if (next_cqd=={XWID{1'b1}})
		allqd <= 1'b1;
	if (branchmiss)
		allqd <= 1'b0;
	if (ihito) begin
	  if (~hirq) begin
	  	//... If all queued and the register bitmask is empty
	  	// Chenge PC to branch target if late branch predictor indicates such.
	  	if ((pe_allqd|allqd) && !hold_ins) begin
		  	pc <= brtgtv ? brtgt : next_pc;
		  	allqd <= 1'b0;
		  end
		end
	end
end

always_comb
if ((fnIsAtom(ins0_d) || fnIsAtom(ins1_d) || fnIsAtom(ins2_d) || fnIsAtom(ins3_d)) && irq_i != 3'd7)
	hirq = 1'd0;
else
	hirq = (irq_i > sr.ipl) && !int_commit && (irq_i > atom_mask[2:0]);

generate begin : gMicroCode
	case(XWID)
	1:
		begin
			Qupls_micro_code umc0 (
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
				.micro_ip({micro_ip[11:1],1'd0}),
				.micro_ir(micro_ir),
				.next_ip(next_micro_ip),
				.instr(mc_ins0),
				.regx(mc_regx0)
			);

			Qupls_micro_code umc1 (
				.micro_ip({micro_ip[11:1],1'd1}),
				.micro_ir(micro_ir),
				.next_ip(),
				.instr(mc_ins1),
				.regx(mc_regx1)
			);
		end
	3:	
		begin
			Qupls_micro_code umc0 (
				.micro_ip(micro_ip),
				.micro_ir(micro_ir),
				.next_ip(next_micro_ip),
				.instr(mc_ins0),
				.regx(mc_regx0)
			);

			Qupls_micro_code umc1 (
				.micro_ip(micro_ip+1),
				.micro_ir(micro_ir),
				.next_ip(),
				.instr(mc_ins1),
				.regx(mc_regx1)
			);

			Qupls_micro_code umc2 (
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
				.micro_ip({micro_ip[11:2],2'd0}),
				.micro_ir(micro_ir),
				.next_ip(next_micro_ip),
				.instr(mc_ins0),
				.regx(mc_regx0)
			);

			Qupls_micro_code umc1 (
				.micro_ip({micro_ip[11:2],2'd1}),
				.micro_ir(micro_ir),
				.next_ip(),
				.instr(mc_ins1),
				.regx(mc_regx1)
			);

			Qupls_micro_code umc2 (
				.micro_ip({micro_ip[11:2],2'd2}),
				.micro_ir(micro_ir),
				.next_ip(),
				.instr(mc_ins2),
				.regx(mc_regx2)
			);

			Qupls_micro_code umc3 (
				.micro_ip({micro_ip[11:2],2'd3}),
				.micro_ir(micro_ir),
				.next_ip(),
				.instr(mc_ins3),
				.regx(mc_regx3)
			);
		end
	endcase
end
endgenerate

always_comb mc_ins4 = {33'd0,OP_NOP};
always_comb mc_ins5 = {33'd0,OP_NOP};
always_comb mc_ins6 = {33'd0,OP_NOP};
always_comb mc_ins7 = {33'd0,OP_NOP};
always_comb mc_ins8 = {33'd0,OP_NOP};

always_ff @(posedge clk) regx0 <= mipv2|~rstcnt[2] ? mc_regx0 : 4'd0;
always_ff @(posedge clk) regx1 <= mipv2|~rstcnt[2] ? mc_regx1 : 4'd0;
always_ff @(posedge clk) regx2 <= mipv2|~rstcnt[2] ? mc_regx2 : 4'd0;
always_ff @(posedge clk) regx3 <= mipv2|~rstcnt[2] ? mc_regx3 : 4'd0;

always_ff @(posedge clk)
if (rst)
	mipv2 <= 1'd0;
else begin
	mipv2 <= mipv;
end
always_ff @(posedge clk)
if (rst)
	mipv3 <= 1'd0;
else begin
	mipv3 <= mipv2;
end
always_ff @(posedge clk)
if (rst)
	mipv4 <= 1'd0;
else begin
	mipv4 <= mipv3;
end


function [11:0] fnMip;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_ENTER:	fnMip = 12'h004;
	OP_LEAVE:	fnMip = 12'h010;
	OP_PUSH:	fnMip = 12'h020;
	OP_POP:		fnMip = 12'h030;
	OP_FLT2:
		case(ir.f2.func)
		FN_FLT1:
			case(ir.f1.func)
			FN_FRES:
				case(ir[26:25])
				2'd0: fnMip = 12'h0C0;
				2'd1:	fnMip = 12'h0D0;
				2'd2:	fnMip = 12'h0E0;
				2'd3: fnMip = 12'h0E0;
				endcase
			FN_RSQRTE:
				case(ir[26:25])
				2'd0:	fnMip = 12'h050;
				2'd1:	fnMip = 12'h0A0;
				2'd2:	fnMip = 12'h080;
				2'd3: fnMip = 12'h070;
				endcase
			default:	fnMip = 12'h000;			
			endcase
		FN_FDIV:	fnMip = 12'h040;
		default:	fnMip = 12'h000;
		endcase
	OP_LSCTX:	fnMip = ir[7] ? 12'h100 : 12'h150;
	default:	fnMip = 12'h000;
	endcase
end
endfunction

always_comb	mip0 = fnMip(ins0_d);
always_comb	mip1 = fnMip(ins1_d);
always_comb	mip2 = fnMip(ins2_d);
always_comb	mip3 = fnMip(ins3_d);
always_comb mip0v = |mip0;
always_comb mip1v = |mip1;
always_comb mip2v = |mip2;
always_comb mip3v = |mip3;
always_comb nmip = |next_micro_ip;
always_comb mipv = |micro_ip;

/*
always_ff @(posedge clk)
if (rst) begin
	micro_ip <= 12'h0F0;
end
else begin
  if (~hirq) begin
  	if (pe_allqd|allqd)
			micro_ip <= next_micro_ip;
	end
			 if (mip0v) begin micro_ip <= mip0; end
	else if (mip1v) begin micro_ip <= mip1; end
	else if (mip2v) begin micro_ip <= mip2; end
	else if (mip3v) begin micro_ip <= mip3; end
end
*/

// Extract instructions
always_comb
	ic_line = {ic_line_hi.data,ic_line_lo.data};
always_ff @(posedge clk)
	ic_line_x <= ic_line2;

// <signal>_x	: instruction extract stage input
// <signal>_d	: instruction extract stage output

wire exti_nop;	
// Latency of one.
// pt0_d, etc. should be in line with ins0_d, etc
Qupls_extract_ins uiext1
(
	.rst_i(rst),
	.clk_i(clk),
	.en_i(1'b1),
	.nop_i(icnop|brtgtv),
	.nop_o(exti_nop),
	.irq_i(irq_i),
	.hirq_i(hirq),
	.vect_i(vect_i),
	.reglist_active(1'b0),
	.mipv_i(mipv),
	.mip_i(micro_ip),
	.ic_line_i(ic_line_x),
	.grp_i(igrp2),
	.misspc(misspc),
	.branchmiss(branchmiss_state!=3'd7),
	.pc0_i(pc0_x),
	.pc1_i(pc1_x),
	.pc2_i(pc2_x),
	.pc3_i(pc3_x),
	.pc4_i(pc4_x),
	.pc5_i(pc5_x),
	.pc6_i(pc6_x),
	.pc7_i(pc7_x),
	.pc8_i(pc8_x),
	.ls_bmf_i(ls_bmf),
	.pack_regs_i(pack_regs),
	.scale_regs_i(scale_regs),
	.regcnt_i('d0),
	.mc_ins0_i(mc_ins0),
	.mc_ins1_i(mc_ins1),
	.mc_ins2_i(mc_ins2),
	.mc_ins3_i(mc_ins3),
	.mc_ins4_i(mc_ins4),
	.mc_ins5_i(mc_ins5),
	.mc_ins6_i(mc_ins6),
	.mc_ins7_i(mc_ins7),
	.mc_ins8_i(mc_ins8),
	.iRn0_i(iRn0r),
	.iRn1_i(iRn1r),
	.iRn2_i(iRn2r),
	.iRn3_i(iRn3r),
	.ins0_o(ins0_d),
	.ins1_o(ins1_d),
	.ins2_o(ins2_d),
	.ins3_o(ins3_d),
	.ins4_o(ins4_d),
	.ins5_o(ins5_d),
	.ins6_o(ins6_d),
	.ins7_o(ins7_d),
	.ins8_o(ins8_d),
	.grp_o(grpd),
	.pc0_o(pc0_d),
	.pc1_o(pc1_d),
	.pc2_o(pc2_d),
	.pc3_o(pc3_d),
	.pc4_o(pc4_d),
	.pc5_o(pc5_d),
	.pc6_o(pc6_d),
	.pc7_o(pc7_d),
	.pc8_o(pc8_d)
);

wire [NDATA_PORTS-1:0] dcache_load;
wire [NDATA_PORTS-1:0] dhit;
wire [NDATA_PORTS-1:0] modified;
wire [1:0] uway [0:NDATA_PORTS-1];
fta_cmd_request512_t [NDATA_PORTS-1:0] cpu_request_i;
fta_cmd_request512_t [NDATA_PORTS-1:0] cpu_request_i2;
fta_cmd_response512_t [NDATA_PORTS-1:0] cpu_resp_o;
fta_cmd_response512_t [NDATA_PORTS-1:0] update_data_i;
wire [NDATA_PORTS-1:0] dump;
wire DCacheLine dump_o[0:NDATA_PORTS-1];
wire [NDATA_PORTS-1:0] dump_ack;
wire [NDATA_PORTS-1:0] dwr;
wire [1:0] dway [0:NDATA_PORTS-1];

generate begin : gDcache
for (g = 0; g < NDATA_PORTS; g = g + 1) begin

	always_comb
	begin
		cpu_request_i[g].cid = g + 1;
		cpu_request_i[g].tid = dramN_tid[g];
		cpu_request_i[g].om = fta_bus_pkg::MACHINE;
		cpu_request_i[g].cmd = dramN_store[g] ? fta_bus_pkg::CMD_STORE : dramN_loadz[g] ? fta_bus_pkg::CMD_LOADZ : dramN_load[g] ? fta_bus_pkg::CMD_LOAD : fta_bus_pkg::CMD_NONE;
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
		cpu_request_i[g].cache = fta_bus_pkg::WT_NO_ALLOCATE;
		dramN_ack[g] = cpu_resp_o[g].ack;
	end

	Qupls_dcache
	#(.CORENO(CORENO), .CID(g+1))
	udc1
	(
		.rst(rst),
		.clk(clk),
		.dce(1'b1),
		.snoop_adr(snoop_adr),
		.snoop_v(snoop_v),
		.snoop_cid(snoop_cid),
		.cache_load(dcache_load[g]),
		.hit(dhit[g]),
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
		.rst_i(rst),
		.clk_i(clk),
		.dce(1'b1),
		.ftam_req(ftadm_req[g]),
		.ftam_resp(ftadm_resp[g]),
		.ftam_full(ftadm_resp[g].rty),
		.acr(),
		.hit(dhit[g]),
		.modified(modified[g]),
		.cache_load(dcache_load[g]),
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

end
end
endgenerate

always_comb
begin
	dramN[0] = dram0;
	dramN_paddr[0] = dram0_paddr;
	dramN_vaddr[0] = dram0_vaddr;
	dramN_data[0] = dram0_data[511:0];
	dramN_sel[0] = dram0_sel[63:0];
	dramN_store[0] = dram0_store;
	dramN_erc[0] = dram0_erc;
	dramN_load[0] = dram0_load;
	dramN_loadz[0] = dram0_loadz;
	dramN_memsz[0] = dram0_memsz;
	dramN_tid[0] = dram0_tid;
	dram0_ack = dramN_ack[0];

	if (NDATA_PORTS > 1) begin
		dramN[1] = dram1;
		dramN_vaddr[1] = dram1_vaddr;
		dramN_paddr[1] = dram1_paddr;
		dramN_data[1] = dram1_data[511:0];
		dramN_sel[1] = dram1_sel[63:0];
		dramN_store[1] = dram1_store;
		dramN_erc[1] = dram1_erc;
		dramN_load[1] = dram1_load;
		dramN_loadz[1] = dram1_loadz;
		dramN_memsz[1] = dram1_memsz;
		dramN_tid[1] = dram1_tid;
		dram1_ack = dramN_ack[1];
	end
	else
		dram1_ack = 1'b0;
end

//
// DECODE
//
instruction_t [5:0] instr [0:3];
pregno_t pRa0, pRa1, pRa2, pRa3;
pregno_t pRb0, pRb1, pRb2, pRb3;
pregno_t pRc0, pRc1, pRc2, pRc3;
pregno_t pRt0, pRt1, pRt2, pRt3;
pregno_t Rt0_q, Rt1_q, Rt2_q, Rt3_q;
pregno_t [3:0] tags2free;
reg [3:0] freevals;
wire [PREGS-1:0] avail_reg;						// available registers
wire [3:0] cndx;											// checkpoint index

assign instr[0][0] = ins0_d;
assign instr[0][1] = ins1_d;
assign instr[0][2] = ins2_d;
assign instr[0][3] = ins3_d;
assign instr[0][4] = ins4_d;
assign instr[0][5] = ins5_d;

assign instr[1][0] = ins1_d;
assign instr[1][1] = ins2_d;
assign instr[1][2] = ins3_d;
assign instr[1][3] = ins4_d;
assign instr[1][4] = ins5_d;
assign instr[1][5] = ins6_d;

assign instr[2][0] = ins2_d;
assign instr[2][1] = ins3_d;
assign instr[2][2] = ins4_d;
assign instr[2][3] = ins5_d;
assign instr[2][4] = ins6_d;
assign instr[2][5] = ins7_d;

assign instr[3][0] = ins3_d;
assign instr[3][1] = ins4_d;
assign instr[3][2] = ins5_d;
assign instr[3][3] = ins6_d;
assign instr[3][4] = ins7_d;
assign instr[3][5] = ins8_d;

generate begin : gDecoders
	case(XWID)
	1:
		begin
			Qupls_decoder udeci0
			(
				.clk(clk),
				.en(1'b1),
				.instr(instr[0]),
				.regx(regx0),
				.dbo(db0_r)
			);
		end
	2:
		begin
			Qupls_decoder udeci0
			(
				.clk(clk),
				.en(1'b1),
				.instr(instr[0]),
				.regx(regx0),
				.dbo(db0_r)
			);

			Qupls_decoder udeci1
			(
				.clk(clk),
				.en(1'b1),
				.instr(instr[1]),
				.regx(regx1),
				.dbo(db1_r)
			);
		end
	3:
		begin
			Qupls_decoder udeci0
			(
				.clk(clk),
				.en(1'b1),
				.instr(instr[0]),
				.regx(regx0),
				.dbo(db0_r)
			);

			Qupls_decoder udeci1
			(
				.clk(clk),
				.en(1'b1),
				.instr(instr[1]),
				.regx(regx1),
				.dbo(db1_r)
			);

			Qupls_decoder udeci2
			(
				.clk(clk),
				.en(1'b1),
				.instr(instr[2]),
				.regx(regx2),
				.dbo(db2_r)
			);
		end
	4:
		begin
			Qupls_decoder udeci0
			(
				.clk(clk),
				.en(1'b1),
				.instr(instr[0]),
				.regx(regx0),
				.dbo(db0_r)
			);

			Qupls_decoder udeci1
			(
				.clk(clk),
				.en(1'b1),
				.instr(instr[1]),
				.regx(regx1),
				.dbo(db1_r)
			);

			Qupls_decoder udeci2
			(
				.clk(clk),
				.en(1'b1),
				.instr(instr[2]),
				.regx(regx2),
				.dbo(db2_r)
			);

			Qupls_decoder udeci3
			(
				.clk(clk),
				.en(1'b1),
				.instr(instr[3]),
				.regx(regx3),
				.dbo(db3_r)
			);
		end
	endcase
end
endgenerate

//
// RENAME
//
aregno_t [15:0] arn;
pregno_t [15:0] prn;
wire [15:0] prnv;
wire [0:0] arnbank [15:0];

assign arn[0] = db0_q.Ra;
assign arn[1] = db0_q.Rb;
assign arn[2] = db0_q.Rc;
assign arn[3] = db0_q.Rt;

assign arn[4] = db1_q.Ra;
assign arn[5] = db1_q.Rb;
assign arn[6] = db1_q.Rc;
assign arn[7] = db1_q.Rt;

assign arn[8] = db2_q.Ra;
assign arn[9] = db2_q.Rb;
assign arn[10] = db2_q.Rc;
assign arn[11] = db2_q.Rt;

assign arn[12] = db3_q.Ra;
assign arn[13] = db3_q.Rb;
assign arn[14] = db3_q.Rc;
assign arn[15] = db3_q.Rt;

assign arnbank[0] = sr.om & {2{|db0_q.Ra}} & 0;
assign arnbank[1] = sr.om & {2{|db0_q.Rb}} & 0;
assign arnbank[2] = sr.om & {2{|db0_q.Rc}} & 0;
assign arnbank[3] = sr.om & {2{|db0_q.Rt}} & 0;
assign arnbank[4] = sr.om & {2{|db1_q.Ra}} & 0;
assign arnbank[5] = sr.om & {2{|db1_q.Rb}} & 0;
assign arnbank[6] = sr.om & {2{|db1_q.Rc}} & 0;
assign arnbank[7] = sr.om & {2{|db1_q.Rt}} & 0;
assign arnbank[8] = sr.om & {2{|db2_q.Ra}} & 0;
assign arnbank[9] = sr.om & {2{|db2_q.Rb}} & 0;
assign arnbank[10] = sr.om & {2{|db2_q.Rc}} & 0;
assign arnbank[11] = sr.om & {2{|db2_q.Rt}} & 0;
assign arnbank[12] = sr.om & {2{|db3_q.Ra}} & 0;
assign arnbank[13] = sr.om & {2{|db3_q.Rb}} & 0;
assign arnbank[14] = sr.om & {2{|db3_q.Rc}} & 0;
assign arnbank[15] = sr.om & {2{|db3_q.Rt}} & 0;


wire stallq, rat_stallq;
assign nq = !branchmiss && rob[tail0].v==INV;
assign stallq = !(ihit_q || mipv || mipv2 || mipv3 || mipv4 || !rstcnt[2]) || rat_stallq;

reg signed [$clog2(ROB_ENTRIES):0] cmtlen;			// Will always be >= 0
reg signed [$clog2(ROB_ENTRIES):0] group_len;		// Commit group length

always_comb
	if (head0 > tail0)
		cmtlen = head0-tail0;
	else
		cmtlen = ROB_ENTRIES+head0-tail0;

// Figure out how many instructions can be committed.
// If there is an oddball instruction (eg. CSR, RTE) then only commit up until
// the oddball. Also, if there is an exception, commit only up until the 
// exception. Otherwise commit instructions that are not valid or are valid
// and done. Do not commit invalid instructions at the tail of the queue.
reg do_commit;
reg cmt0,cmt1,cmt2,cmt3;
reg cmttlb0, cmttlb1,cmttlb2,cmttlb3;
reg htcolls;		// head <-> tail collision
always_comb cmt0 = ((rob[head0].v && &rob[head0].done) || !rob[head0].v);// && head0 != tail0;
always_comb cmt1 = XWID > 1 && (((rob[head1].v && &rob[head1].done) || !rob[head1].v) && !rob[head0].decbus.oddball && !rob[head0].excv);// && head0 != tail0 && head0 != tail1;
always_comb cmt2 = XWID > 2 && (((rob[head2].v && &rob[head2].done) || !rob[head2].v) &&
										!rob[head0].decbus.oddball && !rob[head1].decbus.oddball &&
										!rob[head0].excv && !rob[head1].excv);// &&
										//head0 != tail0 && head0 != tail1 && head0 != tail2;
always_comb cmt3 = XWID > 3 && (((rob[head3].v && &rob[head3].done) || !rob[head3].v) &&
										!rob[head0].decbus.oddball && !rob[head1].decbus.oddball && !rob[head2].decbus.oddball &&
										!rob[head0].excv && !rob[head1].excv && !rob[head2].excv);// &&
										//head0 != tail0 && head0 != tail1 && head0 != tail2 && head0 != tail3;

function fnColls;
input rob_ndx_t head;
input rob_ndx_t tail;
begin
	case(XWID)
	1:
		if (head >= tail)
			fnColls = head - tail > 30;
		else
			fnColls = tail - head < 1;
	2:
		if (head >= tail)
			fnColls = head - tail > 28;
		else
			fnColls = tail - head < 3;
	3:
		if (head >= tail)
			fnColls = head - tail > 26;
		else
			fnColls = tail - head < 5;
	4:
		if (head >= tail)
			fnColls = head - tail > 24;
		else
			fnColls = tail - head < 7;
	default:
			fnColls = FALSE;
	endcase
end
endfunction

always_comb htcolls = fnColls(head0, tail0);
/*
										(
											head0 == tail0 || head0 == tail1 || head0 == tail2 || head0 == tail3 ||
											head0 == tail4 || head0 == tail5 || head0 == tail6 || head0 == tail7);
*/
always_comb cmttlb0 = (rob[head0].v && rob[head0].lsq && !lsq[rob[head0].lsqndx.row][rob[head0].lsqndx.col].agen);
always_comb cmttlb1 = XWID > 1 && (rob[head1].v && rob[head1].lsq && !lsq[rob[head1].lsqndx.row][rob[head1].lsqndx.col].agen);
always_comb cmttlb2 = XWID > 2 && (rob[head2].v && rob[head2].lsq && !lsq[rob[head2].lsqndx.row][rob[head2].lsqndx.col].agen);
always_comb cmttlb3 = XWID > 3 && (rob[head3].v && rob[head3].lsq && !lsq[rob[head3].lsqndx.row][rob[head3].lsqndx.col].agen);

always_ff @(posedge clk)
if (rst)
	cmtcnt <= 3'd0;
else begin
	if (!htcolls) begin
		casez({cmt0,cmt1,cmt2,cmt3})
		4'b1111:	cmtcnt <= 3'd4;
		4'b1110:	cmtcnt <= 3'd3;
		4'b110?:	cmtcnt <= 3'd2;
		4'b10??:	cmtcnt <= 3'd1;
		default:	cmtcnt <= 3'd0;
		endcase
		do_commit <= cmt0;
	end
	else
		do_commit <= FALSE;
end

wire cmtbr = (
	(rob[head0].decbus.br & rob[head0].v) ||
	(XWID > 1 && (rob[head1].decbus.br & rob[head1].v)) ||
	(XWID > 2 && (rob[head2].decbus.br & rob[head2].v)) ||
	(XWID > 3 && (rob[head3].decbus.br & rob[head3].v))) && do_commit
	;

always_comb
begin
	int_commit = 1'b0;
	if (rob[head0].v && &rob[head0].done && fnIsIrq(rob[head0].op))
		int_commit = 1'b1;
	else if (((rob[head0].v && &rob[head0].done) || !rob[head0].v) &&
					(rob[head1].v && &rob[head1].done && fnIsIrq(rob[head1].op)))
		int_commit = XWID > 1;
	else if (((rob[head0].v && &rob[head0].done) || !rob[head0].v) &&
					 ((rob[head1].v && &rob[head1].done) || !rob[head1].v) &&
					(rob[head2].v && &rob[head2].done && fnIsIrq(rob[head2].op)))
		int_commit = XWID > 2;
	else if (((rob[head0].v && &rob[head0].done) || !rob[head0].v) &&
					 ((rob[head1].v && &rob[head1].done) || !rob[head1].v) &&
					 ((rob[head2].v && &rob[head2].done) || !rob[head2].v) &&
					(rob[head3].v && &rob[head3].done && fnIsIrq(rob[head3].op)))
		int_commit = XWID > 3;
end

wire restore_chkpt = branchmiss_state==3'd1;
pregno_t freea;
pregno_t freeb;
pregno_t freec;
pregno_t freed;

Qupls_reg_renamer2 utrn1
(
	.rst(rst),
	.clk(clk),
	.en(!((branchmiss || branchmiss_state < 3'd4) && |robentry_stomp) && !stallq),
	.list2free(free_bitlist),
	.tags2free(tags2free),
	.freevals(freevals),
	.alloc0(|db0_r.Rt && !stallq),
	.alloc1(|db1_r.Rt && !stallq && XWID > 1),
	.alloc2(|db2_r.Rt && !stallq && XWID > 2),
	.alloc3(|db3_r.Rt && !stallq && XWID > 3),
	.wo0(Rt0_q),
	.wo1(Rt1_q),
	.wo2(Rt2_q),
	.wo3(Rt3_q),
	.avail(avail_reg)
);
/*
always_ff @(posedge clk)
begin
	if (!stallq && (db0_q.Rt==7'd63 ||
		db1_q.Rt==7'd63 ||
		db2_q.Rt==7'd63 ||
		db3_q.Rt==7'd63
	))
		$finish;
	for (n19 = 0; n19 < 16; n19 = n19 + 1)
		if (arn[n19]==7'd63)
			$finish;
end
*/
pregno_t Rt0_r;
pregno_t Rt1_r;
pregno_t Rt2_r;
pregno_t Rt3_r;
always_ff @(posedge clk) Rt0_r <= Rt0_q;
always_ff @(posedge clk) Rt1_r <= Rt1_q;
always_ff @(posedge clk) Rt2_r <= Rt2_q;
always_ff @(posedge clk) Rt3_r <= Rt3_q;

Qupls_rat urat1
(	
	.rst(rst),
	.clk(clk),
	.nq(nq),
	.stallq(rat_stallq),
	.cndx_o(cndx),
	.avail_i(avail_reg),
	.restore(restore_chkpt),
	.miss_cp(rob[missid].cndx),
	.wr0(|db0_q.Rt),
	.wr1(|db1_q.Rt && XWID > 1),
	.wr2(|db2_q.Rt && XWID > 2),
	.wr3(|db3_q.Rt && XWID > 3),
	.qbr0(pt0_r),
	.qbr1(pt1_r),
	.qbr2(pt2_r),
	.qbr3(pt3_r),
	.rnbank(arnbank),
	.rn(arn),
	.rrn(prn),
	.vn(prnv),
	.wrbanka(sr.om==2'd0 ? 1'b0 : 1'b0),	// For now, only 1 bank
	.wrbankb(sr.om==2'd0 ? 1'b0 : 1'b0),
	.wrbankc(sr.om==2'd0 ? 1'b0 : 1'b0),
	.wrbankd(sr.om==2'd0 ? 1'b0 : 1'b0),
	.wra(db0_q.Rt),
	.wrra(Rt0_r),
	.wrb(db1_q.Rt),
	.wrrb(Rt1_r),
	.wrc(db2_q.Rt),
	.wrrc(Rt2_r),
	.wrd(db3_q.Rt),
	.wrrd(Rt3_r),
	.cmtbanka(alu0_bank),
	.cmtbankb(alu1_bank),
	.cmtbankc(dram0_bank),
	.cmtbankd(fpu0_bank),
	.cmtav(alu0_done & ~alu0_idle),
	.cmtbv(alu1_done & ~alu1_idle),
	.cmtcv(dram0_done & ~dram0_idle),
	.cmtdv(fpu0_done & ~fpu0_idle),
	.cmtaa(alu0_aRt),
	.cmtba(alu1_aRt),
	.cmtca(dram0_aRt),
	.cmtda(fpu0_aRt),
	.cmtap(alu0_Rt),
	.cmtbp(alu1_Rt),
	.cmtcp(dram0_Rt),
	.cmtdp(fpu0_Rt),
	.cmtbr(cmtbr),
	.freea(freea),
	.freeb(freeb),
	.freec(freec),
	.freed(freed),
	.free_bitlist(free_bitlist)
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

// The cycle after the length is calculated
// instruction extract inputs
always_ff @(posedge clk)
	ihit_x <= ihit2;
always_ff @(posedge clk)
	pc0_x <= pc0;
always_ff @(posedge clk)
	pc1_x <= pc1;
always_ff @(posedge clk)
	pc2_x <= pc2;
always_ff @(posedge clk)
	pc3_x <= pc3;
always_ff @(posedge clk)
	pc4_x <= pc4;
always_ff @(posedge clk)
	pc5_x <= pc4 + len4;
always_ff @(posedge clk)
	pc6_x <= pc4 + len4 + len5;
always_ff @(posedge clk)
	pc7_x <= pc4 + len4 + len5 + len6;
always_ff @(posedge clk)
	pc8_x <= pc4 + len4 + len5 + len6 + len7;

always_ff @(posedge clk)
	ihit_d <= ihit_x;
always_ff @(posedge clk)
	ihit_r <= ihit_d;
always_ff @(posedge clk)
	ihit_q <= ihit_r;

// Register fetch/rename stage inputs
always_ff @(posedge clk)
	pc0_r <= pc0_d;
always_ff @(posedge clk)
	pc1_r <= pc1_d;
always_ff @(posedge clk)
	pc2_r <= pc2_d;
always_ff @(posedge clk)
	pc3_r <= pc3_d;
always_ff @(posedge clk)
	ins0_r <= ins0_d;
always_ff @(posedge clk)
	ins1_r <= ins1_d;
always_ff @(posedge clk)
	ins2_r <= ins2_d;
always_ff @(posedge clk)
	ins3_r <= ins3_d;
always_ff @(posedge clk)
	pt0_r <= pt0_d;
always_ff @(posedge clk)
	pt1_r <= pt1_d;
always_ff @(posedge clk)
	pt2_r <= pt2_d;
always_ff @(posedge clk)
	pt3_r <= pt3_d;

// Instruction queue inputs
always_ff @(posedge clk)
	pc0_q <= pc0_r;
always_ff @(posedge clk)
	pc1_q <= pc1_r;
always_ff @(posedge clk)
	pc2_q <= pc2_r;
always_ff @(posedge clk)
	pc3_q <= pc3_r;
always_ff @(posedge clk)
	ins0_q <= ins0_r;
always_ff @(posedge clk)
	ins1_q <= ins1_r;
always_ff @(posedge clk)
	ins2_q <= ins2_r;
always_ff @(posedge clk)
	ins3_q <= ins3_r;
always_ff @(posedge clk)
	pt0_q <= pt0_r;
always_ff @(posedge clk)
	pt1_q <= pt1_r;
always_ff @(posedge clk)
	pt2_q <= pt2_r;
always_ff @(posedge clk)
	pt3_q <= pt3_r;
always_ff @(posedge clk)
	db0_q <= db0_r;
always_ff @(posedge clk)
	db1_q <= db1_r;
always_ff @(posedge clk)
	db2_q <= db2_r;
always_ff @(posedge clk)
	db3_q <= db3_r;

always_ff @(posedge clk)
	grp_q <= grp_r;
always_ff @(posedge clk)
	grp_r <= grp_d;

reg wrport0_v;
reg wrport1_v;
reg wrport2_v;
reg wrport3_v;
reg wrport4_v;
reg wrport5_v;
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

always_comb wrport0_v = alu0_done;
always_comb wrport1_v = alu1_done && NALU > 1;
always_comb wrport2_v = dram_v0;
always_comb wrport3_v = fpu0_done && !fpu0_idle && NFPU > 0;
always_comb wrport4_v = dram_v1 && NDATA_PORTS > 1;
always_comb wrport5_v = fpu1_done && !fpu1_idle && NFPU > 1;
assign wrport0_Rt = alu0_Rt;
assign wrport1_Rt = NALU > 1 ? alu1_Rt : 9'd0;
assign wrport2_Rt = dram0_Rt;
assign wrport3_Rt = NFPU > 0 ? fpu0_Rt : 9'd0;
assign wrport4_Rt = NDATA_PORTS > 1 ? dram1_Rt : 9'd0;
assign wrport5_Rt = NFPU > 1 ? fpu1_Rt : 9'd0;
assign wrport0_res = alu0_res;
assign wrport1_res = alu1_res;
assign wrport2_res = dram_bus0;
assign wrport3_res = fpu0_res;
assign wrport4_res = dram_bus1;
assign wrport5_res = fpu1_res;

Qupls_regfile4w15r urf1 (
	.rst(rst),
	.clk(clk), 
	.wr0(wrport0_v),
	.wr1(wrport1_v),
	.wr2(wrport2_v),
	.wr3(wrport3_v),
	.we0(1'b1),
	.we1(1'b1),
	.we2(1'b1),
	.we3(1'b1),
	.wa0({2'd0,wrport0_Rt}),
	.wa1({2'd0,wrport1_Rt}),
	.wa2({2'd0,wrport2_Rt}),
	.wa3({2'd0,wrport3_Rt}),
	.i0(wrport0_res),
	.i1(wrport1_res),
	.i2(wrport2_res),
	.i3(wrport3_res),
	.rclk(clk),
	.ra(rf_reg),
	.o(rfo)
);


// 
// additional logic for handling a branch miss (STOMP logic)
//
// stomp drives a lot of logic, so it's registered.

always_ff @(posedge clk)
for (n4 = 0; n4 < ROB_ENTRIES; n4 = n4 + 1) begin
		robentry_stomp[n4] <=
			(branchmiss || branchmiss_state!=3'd7)
			&& rob[n4].sn > rob[missid].sn
			&& rob[n4].v
		;
end											

rob_ndx_t stail;	// stomp tail
always_comb
begin
	n7 = 1'd0;
	stail = 5'd0;
	for (n5 = 0; n5 < ROB_ENTRIES; n5 = n5 + 1) begin
		if (n5==0)
			n6 = ROB_ENTRIES - 1;
		else
			n6 = n5 - 1;
		if (robentry_stomp[n5] && !robentry_stomp[n6] && !n7) begin
			stail = n5;
			n7 = 1'b1;
		end
	end
end
/*
pc_address_t tgtpc;

always_ff @(posedge clk)
	case(fcu_bts)
	BTS_DISP:
		begin
			tgtpc = fcu_pc + {{47{fcu_instr[39]}},fcu_instr[39:25],fcu_instr[12:11]};
		end
	BTS_BSR:
		begin
			tgtpc = alu0_pc + {{33{alu0_instr[39]}},alu0_instr[39:9]};
		end
	BTS_CALL:
		begin
			tgtpc = alu0_argA + {alu0_argI};
		end
	BTS_RTI:
		tgtpc = fcu_instr[8:7]==2'd1 ? pc_stack[1] : pc_stack[0];
	BTS_RET:
		begin
			tgtpc = fcu_argA + fcu_instr[11:7];
		end
	default:
		tgtpc = RSTPC;
	endcase
*/
pc_address_t tpc;
always_comb
	tpc = fcu_pc + 4'd5;

modFcuMissPC umisspc1
(
	.instr(fcu_instr),
	.bts(fcu_bts),
	.pc(fcu_pc),
	.pc_stack(pc_stack),
	.bt(fcu_bt),
	.argA(fcu_argA),
	.argI(fcu_argI),
	.ibh(ibh_t'(ic_line2[511:480])),
	.misspc(fcu_misspc1),
	.missgrp(fcu_missgrp)
);

always_comb
	fcu_missir <= fcu_instr;


Qupls_branch_eval ube1
(
	.instr(fcu_instr),
	.a(fcu_argA),
	.b(fcu_argBr),
	.takb(takb)
);

reg takbr;
always_ff @(posedge clk) takbr <= takb;

always_comb
	case(fcu_bts)
	BTS_RET:
		fcu_res = fcu_argA;
	/* Under construction.
	else if (fcu_instr.any.opcode==OP_DBRA)
		fcu_bus = fcu_argA - 2'd1;
	*/
	default:
		fcu_res = tpc;
	endcase

always_comb
begin
	fcu_exc = FLT_NONE;
	if (fcu_instr.any.opcode==OP_SYS) begin
		case(fcu_instr.sys.func)
		FN_BRK:	fcu_exc = FLT_DBG;
		FN_SYS:	fcu_exc = cause_code_t'(fcu_instr[24:16]);
		default:	fcu_exc = FLT_NONE;
		endcase
	end
end

rob_ndx_t fcu_branchmiss_id;
always_ff @(posedge clk)
if (rst) begin
	fcu_branchmiss <= FALSE;
	fcu_branchmiss_id <= 5'd0;
end
else begin
	if (fcu_v2) begin
		fcu_branchmiss_id <= fcu_id;
		case(fcu_bts)
		BTS_REG,BTS_DISP:
			fcu_branchmiss <= ((takbr && ~fcu_bt) || (!takbr && fcu_bt));
		BTS_BSR,BTS_CALL,BTS_RET:
			fcu_branchmiss <= TRUE;//((takb && ~fcu_bt) || (!takb && fcu_bt));
		default:
			fcu_branchmiss <= FALSE;		
		endcase
	end
	else
		fcu_branchmiss <= FALSE;
	if (fcu_v3)
		fcu_branchmiss <= FALSE;
end

// Registering the branch miss signals may allow a second miss directly after
// the first one to occur. We want to process only the first miss. Three in
// a row cannot happen as the stomp signal is active by then.
always_comb
	branchmiss_next = (excmiss | fcu_branchmiss);// & ~branchmiss;
always_comb	//ff @(posedge clk)
	branchmiss = branchmiss_next;
always_comb
	missid = excmiss ? excid : fcu_branchmiss_id;
always_ff @(posedge clk)
	if (fcu_v6)
		fcu_misspc <= fcu_misspc1;
always_ff @(posedge clk)
	if (branchmiss_state==3'd4)
		misspc = excmiss ? excmisspc : fcu_misspc;
always_ff @(posedge clk)
	if (branchmiss_state==3'd1)
		missgrp = excmiss ? excmissgrp : fcu_missgrp;
always_ff @(posedge clk)
	if (branchmiss_state==3'd1)
		missir = excmiss ? excir : fcu_missir;

wire s4s7 = (pc==misspc && ihito && (rob[fcu_id].done==2'b11 || fcu_idle)) ||
	(robentry_stomp[fcu_id] || (rob[fcu_id].out && !rob[fcu_id].v))
	;

always_ff @(posedge clk)
if (rst)
	branchmiss_state <= 3'd7;
else begin
	case(branchmiss_state)
	3'd7:
		if (branchmiss)
			branchmiss_state <= 3'd1;
	3'd1:
		branchmiss_state <= 3'd2;
	3'd2:
		branchmiss_state <= 3'd3;
	3'd3:
		branchmiss_state <= 3'd4;
	3'd4:
		branchmiss_state <= 3'd5;
	3'd5:
		begin
			if (s4s7)
				branchmiss_state <= 3'd7;
		end
	default:
		branchmiss_state <= 3'd7;
	endcase
end

//
// additional logic for ISSUE
//
// for the moment, we look at ALU-input buffers to allow back-to-back issue of 
// dependent instructions ... we do not, however, look ahead for DRAM requests 
// that will become valid in the next cycle.  instead, these have to propagate
// their results into the IQ entry directly, at which point it becomes issue-able
//

// note that, for all intents & purposes, iqentry_done == iqentry_agen ... no need to duplicate

rob_ndx_t alu0_rndx;
rob_ndx_t alu1_rndx;
rob_ndx_t fpu0_rndx; 
rob_ndx_t fpu1_rndx; 
lsq_ndx_t mem0_lsndx, mem1_lsndx;
wire mem0_lsndxv, mem1_lsndxv;
wire fpu0_rndxv, fpu1_rndxv, fcu_rndxv;
wire alu0_rndxv, alu1_rndxv;
wire agen0_rndxv, agen1_rndxv;
rob_bitmask_t rob_memissue;


Qupls_sched uscd1
(
	.rst(rst),
	.clk(clk),
	.alu0_idle(alu0_idle),
	.alu1_idle(NALU > 1 ? alu1_idle : 1'd0),
	.fpu0_idle(NFPU > 0 ? fpu0_idle : 1'd0),
	.fpu1_idle(NFPU > 1 ? fpu1_idle : 1'd0),
	.fcu_idle(fcu_idle),
	.agen0_idle(agen0_idle),
	.agen1_idle(1'b0),
	.lsq0_idle(lsq0_idle),
	.lsq1_idle(lsq1_idle),
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
	.agen1_rndxv(agen1_rndxv)
);

Qupls_mem_sched umems1
(
	.rst(rst),
	.clk(clk),
	.head(head0),
	.lsq_head(lsq_head),
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

assign alu0_argA_reg = rob[alu0_rndx].pRa;
assign alu0_argB_reg = rob[alu0_rndx].pRb;
assign alu0_argC_reg = rob[alu0_rndx].pRc;

assign alu1_argA_reg = rob[alu1_rndx].pRa;
assign alu1_argB_reg = rob[alu1_rndx].pRb;

assign fpu0_argA_reg = rob[fpu0_rndx].pRa;
assign fpu0_argB_reg = rob[fpu0_rndx].pRb;
assign fpu0_argC_reg = rob[fpu0_rndx].pRc;

assign fpu1_argA_reg = rob[fpu1_rndx].pRa;
assign fpu1_argB_reg = rob[fpu1_rndx].pRb;
assign fpu1_argC_reg = rob[fpu1_rndx].pRc;

assign fcu_argA_reg = rob[fcu_rndx].pRa;
assign fcu_argB_reg = rob[fcu_rndx].pRb;

assign agen0_argA_reg = rob[agen0_rndx].pRa;
assign agen0_argB_reg = rob[agen0_rndx].pRb;

assign agen1_argA_reg = rob[agen1_rndx].pRa;
assign agen1_argB_reg = rob[agen1_rndx].pRb;

//
// EXECUTE
//
value_t csr_res;
always_comb
	tReadCSR(csr_res,alu0_argI[15:0]);

Qupls_alu #(.ALU0(1'b1)) ualu0
(
	.rst(rst),
	.clk(clk),
	.clk2x(clk2x_i),
	.ld(alu0_ld),
	.ir(alu0_instr),
	.div(alu0_div),
	.a(alu0_argA),
	.b(alu0_argB),
	.c(alu0_argC),
	.i(alu0_argI),
	.cs(alu0_cs),
	.pc(alu0_pc),
	.csr(csr_res),
	.o(alu0_res),
	.mul_done(mul0_done),
	.div_done(div0_done),
	.div_dbz()
);

generate begin : gAlu1
if (NALU > 1) begin
	Qupls_alu #(.ALU0(1'b0)) ualu1
	(
		.rst(rst),
		.clk(clk),
		.clk2x(clk2x_i),
		.ld(alu1_ld),
		.ir(alu1_instr),
		.div(alu1_div),
		.a(alu1_argA),
		.b(alu1_argB),
		.c(alu1_argC),
		.i(alu1_argI),
		.cs(alu1_cs),
		.pc(alu1_pc),
		.csr(14'd0),
		.o(alu1_res),
		.mul_done(mul1_done),
		.div_done(),
		.div_dbz()
	);
end
end
endgenerate

//assign alu0_out = alu0_dataready;
//assign alu1_out = alu1_dataready;

//assign  fcu_v = fcu_dataready;

generate begin : gFpu
if (NFPU > 0) begin
	Qupls_fpu ufpu1
	(
		.rst(rst),
		.clk(clk),
		.idle(fpu0_idle),
		.ir(fpu0_instr),
		.rm(3'd0),
		.a(fpu0_argA),
		.b(fpu0_argB),
		.c(fpu0_argC),
		.i(fpu0_argI),
		.o(fpu0_res),
		.p(~64'd0),
		.t(64'd0),
		.done(fpu0_done)
	);
end
if (NFPU > 1) begin
	Qupls_fpu ufpu2
	(
		.rst(rst),
		.clk(clk),
		.idle(fpu1_idle),
		.ir(fpu1_instr),
		.rm(3'd0),
		.a(fpu1_argA),
		.b(fpu1_argB),
		.c(fpu1_argC),
		.i(fpu1_argI),
		.o(fpu1_res),
		.p(~64'd0),
		.t(64'd0),
		.done(fpu1_done)
	);
end
end
endgenerate

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

rob_ndx_t agen0_rndx1, agen1_rndx1;
rob_ndx_t agen0_rndx2, agen1_rndx2;
reg agen0_rndxv1, agen1_rndxv1;
wire agen0_rndxv2, agen1_rndxv2;
reg agen0_v, agen1_v;

Qupls_agen uag0
(
	.clk(clk),
	.ir(agen0_op),
	.a(agen0_argA),
	.b(agen0_argB),
	.i(agen0_argI),
	.res(agen0_res)
);

Qupls_agen uag1
(
	.clk(clk),
	.ir(agen1_op),
	.a(agen1_argA),
	.b(agen1_argB),
	.i(agen1_argI),
	.res(agen1_res)
);

always_ff @(posedge clk) agen0_rndx1 <= agen0_rndx;
always_ff @(posedge clk) agen1_rndx1 <= agen1_rndx;
always_ff @(posedge clk) agen0_rndxv1 <= agen0_rndxv;
always_ff @(posedge clk) agen1_rndxv1 <= agen1_rndxv;
// Make Agen valid sticky
always_ff @(posedge clk) 
if (rst)
	agen0_v <= FALSE;
else begin
	if (rob[agen0_id].out)
		agen0_v <= TRUE;
	if (tlb0_v)
		agen0_v <= FALSE;
end
always_ff @(posedge clk) 
if (rst)
	agen1_v <= FALSE;
else begin
	if (rob[agen1_id].out)
		agen1_v <= TRUE;
	if (tlb1_v)
		agen1_v <= FALSE;
end

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

wire tlb_miss;
virtual_address_t tlb_missadr;
asid_t tlb_missasid;
rob_ndx_t tlb_missid;
instruction_t tlb0_op, tlb1_op;
wire [1:0] tlb_missqn;
wire [31:0] pg_fault;
wire [1:0] pg_faultq;

Qupls_tlb utlb1
(
	.rst(rst),
	.clk(clk),
	.ftas_req(fta_req),
	.ftas_resp(),
	.wr(tlb_wr),
	.way(tlb_way),
	.entry_no(tlb_entryno),
	.entry_i(tlb_entry),
	.entry_o(),
	.stall_tlb0(stall_tlb0),
	.stall_tlb1(stall_tlb1),
	.vadr0(agen0_res),
	.vadr1(agen1_res),
	.pc_vadr(ic_miss_adr),
	.op0(agen0_op),
	.op1(agen1_op),
	.agen0_rndx_i(agen0_id),
	.agen1_rndx_i(agen1_id),
	.agen0_rndx_o(agen0_rndx2),
	.agen1_rndx_o(agen1_rndx2),
	.agen0_v(agen0_v),
	.agen1_v(agen1_v),
	.load0_i(),
	.load1_i(),
	.store0_i(),
	.store1_i(),
	.asid0(asid),
	.asid1(asid),
	.pc_asid(ic_miss_asid),
	.entry0_o(tlb_entry0),
	.entry1_o(tlb_entry1),
	.pc_entry_o(tlb_pc_entry),
	.tlb0_v(tlb0_v),
	.tlb1_v(tlb1_v),
	.pc_tlb_v(pc_tlb_v),
	.tlb0_res(tlb0_res),
	.tlb1_res(tlb1_res),
	.pc_tlb_res(pc_tlb_res),
	.tlb0_op(tlb0_op),
	.tlb1_op(tlb1_op),
	.load0_o(tlb0_load),
	.load1_o(tlb1_load),
	.store0_o(tlb0_store),
	.store1_o(tlb1_store),
	.miss_o(tlb_miss),
	.missadr_o(tlb_missadr),
	.missasid_o(tlb_missasid),
	.missid_o(tlb_missid),
	.missqn_o(tlb_missqn),
	.missack(tlb_missack)
);

Qupls_ptable_walker #(.CID(3)) uptw1
(
	.rst(rst),
	.clk(clk),
	.tlbmiss(tlb_miss),
	.tlb_missadr(tlb_missadr),
	.tlb_missasid(tlb_missasid),
	.tlb_missqn(tlb_missqn),
	.tlb_missid(tlb_missid),
	.commit0_id(commit0_id),
	.commit0_idv(commit0_idv),
	.commit1_id(commit1_id),
	.commit1_idv(commit1_idv),
	.commit2_id(commit2_id),
	.commit2_idv(commit2_idv),
	.commit3_id(commit3_id),
	.commit3_idv(commit3_idv),
	.in_que(tlb_missack),
	.ftas_req(),
	.ftas_resp(),
	.ftam_req(ftatm_req),
	.ftam_resp(ftatm_resp),
	.fault_o(pg_fault),
	.faultq_o(pg_faultq),
	.tlb_wr(tlb_wr),
	.tlb_way(tlb_way),
	.tlb_entryno(tlb_entryno),
	.tlb_entry(tlb_entry)
);

lsq_ndx_t lsq_tail, lsq_tail0;
lsq_ndx_t lsq_head;
lsq_ndx_t lsq_heads [0:LSQ_ENTRIES];
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
always_comb
begin
	dram0_done = 1'd0;
	if (dram0_store ? !robentry_stomp[dram0_id] :
		(dram0 == DRAMSLOT_ACTIVE && dram0_ack &&
			(dram0_hi ? (dram0_load & ~dram0_stomp) : (dram0_load & ~dram0_more & ~dram0_stomp)))
		)
		dram0_done = 1'b1;
end

always_comb
begin
	dram1_done = 1'd0;
	if (NDATA_PORTS > 1) begin
		if (dram1_store ? !robentry_stomp[dram1_id] :
			(dram1 == DRAMSLOT_ACTIVE && dram1_ack &&
				(dram1_hi ? (dram1_load & ~dram1_stomp) : (dram1_load & ~dram1_more & ~dram1_stomp)))
			)
			dram1_done = 1'b1;
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

lsq_ndx_t lbndx0, lbndx1;
always_comb	lbndx0 = fnLoadBypassIndex(mem0_lsndx);
always_comb lbndx1 = fnLoadBypassIndex(mem1_lsndx);

reg dram0_setready;
always_comb
begin
	dram0_setready = FALSE;
	if (SUPPORT_LOAD_BYPASSING && lbndx0 > 0)
		;
	else if (dram0 == DRAMSLOT_AVAIL && mem0_lsndxv)
		dram0_setready = TRUE;
end

reg dram1_setready;
always_comb
begin
	dram1_setready = FALSE;
	if (NDATA_PORTS > 1) begin
		if (SUPPORT_LOAD_BYPASSING && lbndx1 > 0)
			;
		else if (dram1 == DRAMSLOT_AVAIL && mem1_lsndxv)
			dram1_setready = TRUE;
	end
end

reg dram0_timeout;
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

reg dram1_timeout;
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
	.rst_i(rst),
	.clk_i(clk),
	.ack_i(dram0_ack),
	.set_ready_i(dram0_setready),
	.set_avail_i(dram0_timeout),
	.state_o(dram0)
);

Qupls_mem_state udrst1
(
	.rst_i(rst),
	.clk_i(clk),
	.ack_i(dram1_ack),
	.set_ready_i(dram1_setready),
	.set_avail_i(dram1_timeout),
	.state_o(dram1)
);

Qupls_mem_more ummore0
(
	.rst_i(rst),
	.clk_i(clk),
	.state_i(dram0),
	.sel_i(dram0_sel),
	.more_o(dram0_more)
);

Qupls_mem_more ummore1
(
	.rst_i(rst),
	.clk_i(clk),
	.state_i(dram1),
	.sel_i(dram1_sel),
	.more_o(dram1_more)
);

// When to stomp on instructions enqueuing.
wire stomp0 = 1'b0;
wire stomp1 = pt0_q||mip0v||XWID < 2;
wire stomp2 = pt0_q||pt1_q||mip0v||mip1v || XWID < 3;
wire stomp3 = pt0_q||pt1_q||pt2_q||mip0v||mip1v||mip2v || XWID < 4;


always_ff @(posedge clk)
if (rst) begin
	tReset();
end
else begin
	if (!rstcnt[2])
		rstcnt <= rstcnt + 1;
	freevals <= 4'd0;
	alu0_ld <= 1'd0;
	alu1_ld <= 1'd0;
	alu0_done <= FALSE;
	alu1_done <= FALSE;
	fpu0_done <= FALSE;
	fpu1_done <= FALSE;
	fcu_v2 <= fcu_v;
	fcu_v3 <= fcu_v2;
	fcu_v4 <= fcu_v3;
	fcu_v5 <= fcu_v4;
	fcu_v6 <= fcu_v5;
			 if (mip0v) begin micro_ir <= ins0_d; end
	else if (mip1v) begin micro_ir <= ins1_d; end
	else if (mip2v) begin micro_ir <= ins2_d; end
	else if (mip3v) begin micro_ir <= ins3_d; end
  if (~hirq) begin
  	if (pe_allqd|allqd)
			micro_ip <= next_micro_ip;
	end
			 if (mip0v) begin micro_ip <= mip0; end
	else if (mip1v) begin micro_ip <= mip1; end
	else if (mip2v) begin micro_ip <= mip2; end
	else if (mip3v) begin micro_ip <= mip3; end

	// This test in sync with PC update
	if (!branchmiss && ihito && !hirq && ((pe_allqd|allqd) && !hold_ins))
		brtgtv <= FALSE;	// PC has been updated

//
// DATAINCOMING
//
// Once the operation is done, flag the ROB entry as done and mark the unit
// as idle. Record any exceptions that may have occurred.
//
	if (!alu0_idle && rob[alu0_id].v && !robentry_stomp[alu0_id]) begin
    rob[ alu0_id ].exc <= alu0_exc;
    rob[ alu0_id ].excv <= |alu0_exc;
    rob[ alu0_id ].done[0] <= !rob[ alu0_id ].decbus.multicycle;
    if (!rob[ alu0_id ].decbus.fc)
    	rob[ alu0_id ].done[1] <= VAL;
    rob[ alu0_id ].out <= INV;
    if (!rob[ alu0_id ].decbus.multicycle) begin
    	alu0_done <= TRUE;
	    alu0_idle <= TRUE;
	  end
    if ((rob[ alu0_id ].decbus.mul || rob[ alu0_id ].decbus.mulu) && mul0_done) begin
    	alu0_done <= TRUE;
	    alu0_idle <= TRUE;
	    rob[ alu0_id ].done <= 2'b11;
	    rob[ alu0_id ].out <= INV;
  	end
    if ((rob[ alu0_id ].decbus.div || rob[ alu0_id ].decbus.divu) && div0_done) begin
    	alu0_done <= TRUE;
	    alu0_idle <= TRUE;
	    rob[ alu0_id ].done <= 2'b11;
	    rob[ alu0_id ].out <= INV;
  	end
	end
	if (robentry_stomp[alu0_id])
		alu0_idle <= TRUE;

	if (NALU > 1 && !alu1_idle && rob[alu1_id].v && !robentry_stomp[alu1_id]) begin
   	alu1_done <= TRUE;
    alu1_idle <= TRUE;
    rob[ alu1_id ].exc <= alu1_exc;
    rob[ alu1_id ].excv <= |alu1_exc;
    rob[ alu1_id ].done[0] <= 1'b1;
    rob[ alu1_id ].done[1] <= 1'b1;
    rob[ alu1_id ].out <= INV;
	end
	if (robentry_stomp[alu1_id])
		alu1_idle <= TRUE;

	if (NFPU > 0 && !fpu0_idle && rob[fpu0_id].v && !robentry_stomp[fpu0_id]) begin
		if (fpu0_done) begin
			fpu0_idle <= TRUE;
			/*
			if (fpu0_pfx) begin
				fpu0_argC <= fpu0_argA;
				fpu0_argD <= fpu0_argB;
			end
			else begin
				fpu0_argC <= 'd0;
				fpu0_argD <= 'd0;
			end
			*/
		end
    rob[ fpu0_id ].exc <= fpu0_exc;
    rob[ fpu0_id ].excv <= |fpu0_exc;
    rob[ fpu0_id ].done[0] <= fpu0_done;
    rob[ fpu0_id ].done[1] <= 1'b1;
    rob[ fpu0_id ].out <= INV;
	end
	if (robentry_stomp[fpu0_id])
		fpu0_idle <= TRUE;
	
	if (NFPU > 1 && !fpu1_idle && rob[fpu1_id].v && !robentry_stomp[fpu1_id]) begin
		if (fpu1_done)
			fpu1_idle <= TRUE;
    rob[ fpu1_id ].exc <= fpu1_exc;
    rob[ fpu1_id ].excv <= |fpu1_exc;
    rob[ fpu1_id ].done[0] <= fpu1_done;
    rob[ fpu1_id ].done[1] <= 1'b1;
    rob[ fpu1_id ].out <= INV;
	end
	if (robentry_stomp[fpu1_id])
		fpu1_idle <= TRUE;
	
	if (fcu_v && rob[fcu_id].v && fcu_v3 && !robentry_stomp[fcu_id] && branchmiss_state==3'd7) begin
		fcu_v <= INV;
		fcu_v2 <= INV;
		fcu_v3 <= INV;
		if (fcu_v3)
			fcu_idle <= TRUE;
    rob[ fcu_id ].exc <= fcu_exc;
    rob[ fcu_id ].excv <= |fcu_exc;
    if (!rob[ fcu_id ].decbus.alu)
    	rob[ fcu_id ].done[0] <= VAL;
    rob[ fcu_id ].done[1] <= VAL;
    rob[ fcu_id ].out <= INV;
    rob[ fcu_id ].takb <= takbr;	// could maybe just use takb
//    fcu_bts <= BTS_NONE;
	end
	// Terminate FCU operation on stomp.
	if (robentry_stomp[fcu_id] || (rob[fcu_id].out && !rob[fcu_id].v)) begin
		fcu_v <= INV;
		fcu_v2 <= INV;
		fcu_v3 <= INV;
		fcu_idle <= TRUE;
	end
	// If data for stomped instruction, ignore
	// dram_vn will be false for stomped data
	if (dram0_done && rob[ dram0_id ].v) begin
    rob[ dram0_id ].exc <= dram_exc0;
    rob[ dram0_id ].excv <= |dram_exc0;
    rob[ dram0_id ].out <= INV;
    rob[ dram0_id ].done <= 2'b11;
		for (n18r = 0; n18r < LSQ_ENTRIES; n18r = n18r + 1) begin
			for (n18c = 0; n18c < LSQ_ENTRIES; n18c = n18c + 1) begin
				if (lsq[n18r][n18c].rndx==dram0_id) begin
					lsq[n18r][n18c].v <= INV;
					lsq[n18r][n18c].agen <= FALSE;
				end
			end
		end
	end
	if (NDATA_PORTS > 1) begin
		if (dram1_done && rob[ dram1_id ].v) begin
	    rob[ dram1_id ].exc <= dram_exc1;
	    rob[ dram1_id ].excv <= |dram_exc1;
	    rob[ dram1_id ].out <= INV;
	    rob[ dram1_id ].done <= 2'b11;
			for (n18r = 0; n18r < LSQ_ENTRIES; n18r = n18r + 1) begin
				for (n18c = 0; n18c < LSQ_ENTRIES; n18c = n18c + 1) begin
					if (lsq[n18r][n18c].rndx==dram1_id) begin
						lsq[n18r][n18c].v <= INV;
						lsq[n18r][n18c].agen <= FALSE;
					end
				end
			end
		end
	end
	// Store TLB translation in LSQ
	// If there is a TLB miss it could be a number of cycles before output
	// becomes valid.
	if (tlb0_v && !agen0_idle) begin
		if (|pg_fault && pg_faultq==2'd1) begin
			agen0_idle <= TRUE;
			rob[agen0_id].exc <= FLT_PAGE;
			rob[agen0_id].excv <= TRUE;
			rob[agen0_id].done[1] <= 1'b1;
		end
		if (rob[agen0_id].lsq && !rob[agen0_id].done[0]) begin
			agen0_idle <= TRUE;
			rob[agen0_id].done[0] <= 1'b1;
			rob[agen0_id].out <= 1'b0;
			for (n18r = 0; n18r < LSQ_ENTRIES; n18r = n18r + 1) begin
				for (n18c = 0; n18c < LSQ_ENTRIES; n18c = n18c + 1) begin
					if (lsq[n18r][n18c].rndx==agen0_id) begin
						lsq[n18r][n18c].agen <= TRUE;
						lsq[n18r][n18c].vadr <= tlb0_res;
						lsq[n18r][n18c].padr <= {tlb_entry0.pte.ppn,tlb0_res[15:0]};
					end
				end
			end
		end
	end
	if (robentry_stomp[agen0_id] && rob[agen0_id].lsq) begin
		for (n18r = 0; n18r < LSQ_ENTRIES; n18r = n18r + 1) begin
			for (n18c = 0; n18c < LSQ_ENTRIES; n18c = n18c + 1) begin
				if (lsq[n18r][n18c].rndx==agen0_id) begin
					lsq[n18r][n18c].v <= INV;
					lsq[n18r][n18c].agen <= FALSE;
				end
			end
		end
	end

	if (NAGEN > 1) begin
		if (tlb1_v && !agen1_idle) begin
			if (|pg_fault && pg_faultq==2'd2) begin
				agen1_idle <= TRUE;
				rob[agen1_id].exc <= FLT_PAGE;
				rob[agen1_id].excv <= TRUE;
				rob[agen1_id].done[1] <= 1'b1;
			end
			if (rob[agen1_id].lsq && !rob[agen1_id].done[0]) begin
				agen1_idle <= TRUE;
				rob[agen1_id].done[0] <= 1'b1;
				rob[agen1_id].out <= 1'b0;
				for (n18r = 0; n18r < LSQ_ENTRIES; n18r = n18r + 1) begin
					for (n18c = 0; n18c < LSQ_ENTRIES; n18c = n18c + 1) begin
						if (lsq[n18r][n18c].rndx==agen1_id) begin
							lsq[n18r][n18c].agen <= TRUE;
							lsq[n18r][n18c].vadr <= tlb1_res;
							lsq[n18r][n18c].padr <= {tlb_entry1.pte.ppn,tlb1_res[15:0]};
						end
					end
				end
			end
		end
		if (robentry_stomp[agen1_id] && rob[agen1_id].lsq) begin
			for (n18r = 0; n18r < LSQ_ENTRIES; n18r = n18r + 1) begin
				for (n18c = 0; n18c < LSQ_ENTRIES; n18c = n18c + 1) begin
					if (lsq[n18r][n18c].rndx==agen1_id) begin
						lsq[n18r][n18c].v <= INV;
						lsq[n18r][n18c].agen <= FALSE;
					end
				end
			end
		end
	end
	
	// Validate arguments

	for (nn = 0; nn < ROB_ENTRIES; nn = nn + 1) begin

		// ALU0
		if (rob[nn].argA_v == INV && rob[nn].pRa == wrport0_Rt && rob[nn].v == VAL && wrport0_v == VAL)
	    rob[nn].argA_v <= VAL;
		if (rob[nn].argB_v == INV && rob[nn].pRb == wrport0_Rt && rob[nn].v == VAL && wrport0_v == VAL)
	    rob[nn].argB_v <= VAL;
		if (rob[nn].argC_v == INV && rob[nn].pRc == wrport0_Rt && rob[nn].v == VAL && wrport0_v == VAL)
	    rob[nn].argC_v <= VAL;

		// ALU1
		if (NALU > 1) begin
			if (rob[nn].argA_v == INV && rob[nn].pRa == wrport1_Rt && rob[nn].v == VAL && wrport1_v == VAL)
		    rob[nn].argA_v <= VAL;
			if (rob[nn].argB_v == INV && rob[nn].pRb == wrport1_Rt && rob[nn].v == VAL && wrport1_v == VAL)
		    rob[nn].argB_v <= VAL;
			if (rob[nn].argC_v == INV && rob[nn].pRc == wrport1_Rt && rob[nn].v == VAL && wrport1_v == VAL)
		    rob[nn].argC_v <= VAL;
		end

		// DRAM0
		if (rob[nn].argA_v == INV && rob[nn].pRa == wrport2_Rt && rob[nn].v == VAL && wrport2_v == VAL)
	    rob[nn].argA_v <= VAL;
		if (rob[nn].argB_v == INV && rob[nn].pRb == wrport2_Rt && rob[nn].v == VAL && wrport2_v == VAL)
	    rob[nn].argB_v <= VAL;
		if (rob[nn].argC_v == INV && rob[nn].pRc == wrport2_Rt && rob[nn].v == VAL && wrport2_v == VAL)
	    rob[nn].argC_v <= VAL;

		// FPU0
		if (NFPU > 0) begin
			if (rob[nn].argA_v == INV && rob[nn].pRa == wrport3_Rt && rob[nn].v == VAL && wrport3_v == VAL)
		    rob[nn].argA_v <= VAL;
			if (rob[nn].argB_v == INV && rob[nn].pRb == wrport3_Rt && rob[nn].v == VAL && wrport3_v == VAL)
		    rob[nn].argB_v <= VAL;
			if (rob[nn].argC_v == INV && rob[nn].pRc == wrport3_Rt && rob[nn].v == VAL && wrport3_v == VAL)
		    rob[nn].argC_v <= VAL;
	  end

		// DRAM1
		if (NDATA_PORTS > 1) begin
			if (rob[nn].argA_v == INV && rob[nn].pRa == wrport4_Rt && rob[nn].v == VAL && wrport4_v == VAL)
		    rob[nn].argA_v <= VAL;
			if (rob[nn].argB_v == INV && rob[nn].pRb == wrport4_Rt && rob[nn].v == VAL && wrport4_v == VAL)
		    rob[nn].argB_v <= VAL;
			if (rob[nn].argC_v == INV && rob[nn].pRc == wrport4_Rt && rob[nn].v == VAL && wrport4_v == VAL)
		    rob[nn].argC_v <= VAL;
	  end

		// FPU1
		if (NFPU > 1) begin
			if (rob[nn].argA_v == INV && rob[nn].pRa == wrport5_Rt && rob[nn].v == VAL && wrport5_v == VAL)
		    rob[nn].argA_v <= VAL;
			if (rob[nn].argB_v == INV && rob[nn].pRb == wrport5_Rt && rob[nn].v == VAL && wrport5_v == VAL)
		    rob[nn].argB_v <= VAL;
			if (rob[nn].argC_v == INV && rob[nn].pRc == wrport5_Rt && rob[nn].v == VAL && wrport5_v == VAL)
		    rob[nn].argC_v <= VAL;
	  end
	  
	end

//
// ISSUE 
//
// determines what instructions are ready to go, then places them
// in the various ALU queues.  
// also invalidates instructions following a branch-miss BEQ or any JALR (STOMP logic)
//

	// Reservation stations

	if (alu0_available && alu0_rndxv && alu0_idle) begin
		alu0_idle <= FALSE;
		alu0_id <= alu0_rndx;
		alu0_argA <= rob[alu0_rndx].decbus.imma | rfo_alu0_argA;
		alu0_argB <= rfo_alu0_argB;
		alu0_argC <= rob[alu0_rndx].decbus.immc | rfo_alu0_argC;
		alu0_argI	<= rob[alu0_rndx].decbus.immb;
		alu0_cs <= rob[alu0_rndx].decbus.Rcc;
		alu0_Rt <= rob[alu0_rndx].nRt;
		alu0_bank <= rob[alu0_rndx].om==2'd0 ? 1'b0 : 1'b1;
		alu0_aRt <= rob[alu0_rndx].decbus.Rt;
		alu0_ld <= 1'b1;
		alu0_instr <= rob[alu0_rndx].op;
		alu0_div <= rob[alu0_rndx].decbus.div;
		alu0_pc <= rob[alu0_rndx].pc;
		rob[alu0_rndx].arg <= rob[alu0_rndx].decbus.immc | rfo_alu0_argC;
    rob[alu0_rndx].out <= VAL;
	end

	if (NALU > 1) begin
		if (alu1_available && alu1_rndxv && alu1_idle) begin
			alu1_idle <= FALSE;
			alu1_id <= alu1_rndx;
			alu1_argA <= rob[alu1_rndx].decbus.imma | rfo_alu1_argA;
			alu1_argB <= rfo_alu1_argB;
			alu1_argI	<= rob[alu1_rndx].decbus.immb;
			alu1_cs <= rob[alu1_rndx].decbus.Rcc;
			alu1_Rt <= rob[alu1_rndx].nRt;
			alu1_aRt <= rob[alu1_rndx].decbus.Rt;
			alu1_bank <= rob[alu1_rndx].om==2'd0 ? 1'b0 : 1'b1;
			alu1_ld <= 1'b1;
			alu1_instr <= rob[alu1_rndx].op;
			alu1_div <= rob[alu1_rndx].decbus.div;
			alu1_pc <= rob[alu1_rndx].pc;
	    rob[alu1_rndx].out <= VAL;
		end
	end

	if (NFPU > 0) begin
		if (fpu0_available && fpu0_rndxv && fpu0_idle) begin
			fpu0_idle <= FALSE;
			fpu0_id <= fpu0_rndx;
			fpu0_argA <= rob[fpu0_rndx].decbus.imma | rfo_fpu0_argA;
			fpu0_argB <= rfo_fpu0_argB;
			fpu0_argC <= rob[fpu0_rndx].decbus.immc | rfo_fpu0_argC;
			fpu0_argI	<= rob[fpu0_rndx].decbus.immb;
			fpu0_Rt <= rob[fpu0_rndx].pRt;
			fpu0_aRt <= rob[fpu0_rndx].decbus.Rt;
			fpu0_cs <= rob[fpu0_rndx].decbus.Rcc;
			fpu0_bank <= rob[fpu0_rndx].om==2'd0 ? 1'b0 : 1'b1;
			fpu0_instr <= rob[fpu0_rndx].op;
			fpu0_pc <= rob[fpu0_rndx].pc;
	    rob[fpu0_rndx].out <= VAL;
		end
	end

	if (NFPU > 1) begin
		if (fpu1_available && fpu1_rndxv && fpu1_idle) begin
			fpu1_idle <= FALSE;
			fpu1_id <= fpu1_rndx;
			fpu1_argA <= rob[fpu1_rndx].decbus.imma | rfo_fpu1_argA;
			fpu1_argB <= rfo_fpu1_argB;
			fpu1_argC <= rob[fpu1_rndx].decbus.immc | rfo_fpu1_argC;
			fpu1_argI	<= rob[fpu1_rndx].decbus.immb;
			fpu1_Rt <= rob[fpu1_rndx].pRt;
			fpu1_aRt <= rob[fpu1_rndx].decbus.Rt;
			fpu1_cs <= rob[fpu1_rndx].decbus.Rcc;
			fpu1_bank <= rob[fpu1_rndx].om==2'd0 ? 1'b0 : 1'b1;
			fpu1_instr <= rob[fpu1_rndx].op;
			fpu1_pc <= rob[fpu1_rndx].pc;
	    rob[fpu1_rndx].out <= VAL;
		end
	end

	if (fcu_rndxv && fcu_idle && (branchmiss_state==3'd7)) begin
		fcu_idle <= FALSE;
		fcu_v <= VAL;
		fcu_id <= fcu_rndx;
		fcu_argA <= rob[fcu_rndx].decbus.imma | rfo_fcu_argA;
		fcu_argB <= rfo_fcu_argB;
		fcu_argBr <= rob[fcu_rndx].decbus.immb | rfo_fcu_argB;
		fcu_argI <= rob[fcu_rndx].decbus.immb;
		fcu_instr <= rob[fcu_rndx].op;
		fcu_pc <= rob[fcu_rndx].pc;
		fcu_bt <= rob[fcu_rndx].bt;
		fcu_bts <= rob[fcu_rndx].decbus.bts;
		fcu_id <= fcu_rndx;
	  rob[fcu_rndx].out <= VAL;
	end

	if (agen0_rndxv && agen0_idle) begin
		agen0_idle <= FALSE;
		agen0_id <= agen0_rndx;
		agen0_argA <= rob[agen0_rndx].decbus.imma | rfo_agen0_argA;
		agen0_argB <= rfo_agen0_argB;
		agen0_argI <= rob[agen0_rndx].decbus.immb;
		agen0_pc <= rob[agen0_rndx].pc;
		agen0_op <= rob[agen0_rndx].op;
	  rob[agen0_rndx].out <= VAL;
	end

	if (NAGEN > 1) begin
		if (agen1_rndxv && agen1_idle) begin
			agen1_idle <= FALSE;
			agen1_id <= agen1_rndx;
			agen1_argA <= rob[agen1_rndx].decbus.imma | rfo_agen1_argA;
			agen1_argB <= rfo_agen1_argB;
			agen1_argI <= rob[agen1_rndx].decbus.immb;
			agen1_pc <= rob[agen1_rndx].pc;
			agen1_op <= rob[agen1_rndx].op;
	    rob[agen1_rndx].out <= VAL;
		end
	end
	
	if (lsq[rob[dram0_id].lsqndx.row][rob[dram0_id].lsqndx.col].v &&
		lsq[rob[dram0_id].lsqndx.row][rob[dram0_id].lsqndx.col].store) begin
		store_argC <= rfo_store_argC;
	end
	if (lsq[rob[dram1_id].lsqndx.row][rob[dram1_id].lsqndx.col].v &&
		lsq[rob[dram1_id].lsqndx.row][rob[dram1_id].lsqndx.col].store) begin
		store_argC <= rfo_store_argC;
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
// MEMORY
//
// update the memory queues and put data out on bus if appropriate
//

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
			rob[dram0_id].out <= INV;
			lsq[rob[dram0_id].lsqndx.row][rob[dram0_id].lsqndx.col].v <= INV;
			dram0_tocnt <= 12'd0;
		end
		else if (dram0_tocnt[8]) begin
			rob[dram0_id].out <= INV;
		end
		if (NDATA_PORTS > 1) begin
			if (dram1_tocnt[10]) begin
				if (!rob[dram1_id].excv) begin
					rob[dram1_id].exc <= FLT_BERR;
					rob[dram1_id].excv <= TRUE;
				end
				rob[dram1_id].done <= 2'b11;
				rob[dram1_id].out <= INV;
				lsq[rob[dram1_id].lsqndx.row][rob[dram1_id].lsqndx.col].v <= INV;
				dram1_tocnt <= 12'd0;
			end
			else if (dram1_tocnt[8]) begin
				rob[dram1_id].out <= INV;
			end
		end
	end

	// grab requests that have finished and put them on the dram_bus
	if (dram0 == DRAMSLOT_ACTIVE && dram0_ack && dram0_hi && SUPPORT_UNALIGNED_MEMORY) begin
		dram0_hi <= 1'b0;
    dram_v0 <= dram0_load & ~dram0_stomp;
    dram_id0 <= dram0_id;
    dram_Rt0 <= dram0_Rt;
    dram_exc0 <= dram0_exc;
  	dram_bus0 <= fnDati(1'b0,dram0_op,(cpu_resp_o[0].dat << dram0_shift)|dram_bus0);
    if (dram0_store) begin
    	dram0_store <= 1'd0;
    	dram0_sel <= 80'd0;
  	end
    if (dram0_store)
    	$display("m[%h] <- %h", dram0_vaddr, dram0_data);
	end
	else if (dram0 == DRAMSLOT_ACTIVE && dram0_ack) begin
		// If there is more to do, trigger a second instruction issue.
		if (dram0_more && !dram0_stomp)
			rob[dram0_id].out <= INV;
    dram_v0 <= dram0_load & ~dram0_more & ~dram0_stomp;
    dram_id0 <= dram0_id;
    dram_Rt0 <= dram0_Rt;
    dram_exc0 <= dram0_exc;
  	dram_bus0 <= fnDati(dram0_more,dram0_op,cpu_resp_o[0].dat >> dram0_shift);
    if (dram0_store) begin
    	dram0_store <= 1'd0;
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
	    dram_v1 <= dram1_load & ~dram1_stomp;
	    dram_id1 <= dram1_id;
	    dram_Rt1 <= dram1_Rt;
	    dram_exc1 <= dram1_exc;
    	dram_bus1 <= fnDati(1'b0,dram1_op,(cpu_resp_o[1].dat << dram1_shift)|dram_bus1);
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
				rob[dram1_id].out <= INV;
	    dram_v1 <= dram1_load & ~dram1_more & ~dram1_stomp;
	    dram_id1 <= dram1_id;
	    dram_Rt1 <= dram1_Rt;
	    dram_exc1 <= dram1_exc;
    	dram_bus1 <= fnDati(dram1_more,dram1_op,cpu_resp_o[1].dat >> dram1_shift);
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
		dram_bus0 <= fnDati(1'b0,dram0_op,lsq[lbndx0.row][lbndx0.col].res);
		dram_Rt0 <= lsq[lbndx0.row][lbndx0.col].Rt;
		dram_v0 <= lsq[lbndx0.row][lbndx0.col].v;
		lsq[lbndx0.row][lbndx0.col].v <= INV;
		rob[lsq[lbndx0.row][lbndx0.col].rndx].done <= 2'b11;
	end
  else if (dram0 == DRAMSLOT_AVAIL && mem0_lsndxv) begin
		dram0_exc <= FLT_NONE;
		dram0_stomp <= 1'b0;
		dram0_id <= lsq[mem0_lsndx.row][mem0_lsndx.col].rndx;
		dram0_op <= lsq[mem0_lsndx.row][mem0_lsndx.col].op;
		dram0_load <= lsq[mem0_lsndx.row][mem0_lsndx.col].load;
		dram0_loadz <= lsq[mem0_lsndx.row][mem0_lsndx.col].loadz;
		dram0_store <= lsq[mem0_lsndx.row][mem0_lsndx.col].store;
		dram0_erc <= rob[lsq[mem0_lsndx.row][mem0_lsndx.col].rndx].decbus.erc;
		dram0_Rt	<= lsq[mem0_lsndx.row][mem0_lsndx.col].Rt;
		dram0_aRt	<= lsq[mem0_lsndx.row][mem0_lsndx.col].aRt;
		dram0_bank <= lsq[mem0_lsndx.row][mem0_lsndx.col].om==2'd0 ? 1'b0 : 1'b1;
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
			dram0_data <= {448'h0,store_argC} << {lsq[mem0_lsndx.row][mem0_lsndx.col].padr[5:0],3'b0};
			dram0_datah <= {448'h0,store_argC} << {lsq[mem0_lsndx.row][mem0_lsndx.col].padr[5:0],3'b0};
			dram0_shift <= {lsq[mem0_lsndx.row][mem0_lsndx.col].padr[5:0],3'd0};
		end
		dram0_memsz <= fnMemsz(rob[lsq[mem0_lsndx.row][mem0_lsndx.col].rndx].op);
		dram0_tid.core <= CORENO;
		dram0_tid.channel <= 3'd1;
		dram0_tid.tranid <= dram0_tid.tranid + 2'd1;
		rob[lsq[mem0_lsndx.row][mem0_lsndx.col].rndx].out <= VAL;
    dram0_tocnt <= 12'd0;
  end
  if (NDATA_PORTS > 1) begin
		if (SUPPORT_LOAD_BYPASSING && lbndx1 > 0) begin
			dram_bus1 <= fnDati(1'b0,dram1_op,lsq[lbndx1.row][lbndx1.col].res);
			dram_Rt1 <= lsq[lbndx1.row][lbndx1.col].Rt;
			dram_v1 <= lsq[lbndx1.row][lbndx1.col].v;
			lsq[lbndx1.row][lbndx1.col].v <= INV;
			rob[lsq[lbndx1.row][lbndx1.col].rndx].done <= 2'b11;
		end
	  else if (dram1 == DRAMSLOT_AVAIL && NDATA_PORTS > 1 && mem1_lsndxv) begin
			dram1_exc <= FLT_NONE;
			dram1_stomp <= 1'b0;
			dram1_id <= lsq[mem1_lsndx.row][mem1_lsndx.col].rndx;
			dram1_op <= lsq[mem1_lsndx.row][mem1_lsndx.col].op;
			dram1_load <= lsq[mem1_lsndx.row][mem1_lsndx.col].load;
			dram1_loadz <= lsq[mem1_lsndx.row][mem1_lsndx.col].loadz;
			dram1_store <= lsq[mem1_lsndx.row][mem1_lsndx.col].store;
			dram1_erc <= rob[lsq[mem1_lsndx.row][mem1_lsndx.col].rndx].decbus.erc;
			dram1_Rt <= lsq[mem1_lsndx.row][mem1_lsndx.col].Rt;
			dram1_aRt	<= lsq[mem1_lsndx.row][mem1_lsndx.col].aRt;
			dram1_bank <= lsq[mem1_lsndx.row][mem1_lsndx.col].om==2'd0 ? 1'b0 : 1'b1;
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
				dram1_data	<= {448'h0,store_argC} << {lsq[mem1_lsndx.row][mem1_lsndx.col].padr[5:0],3'b0};
				dram1_datah	<= {448'h0,store_argC} << {lsq[mem1_lsndx.row][mem1_lsndx.col].padr[5:0],3'b0};
				dram1_shift <= {lsq[mem1_lsndx.row][mem1_lsndx.col].padr[5:0],3'd0};
			end
			dram1_memsz <= fnMemsz(lsq[mem1_lsndx.row][mem1_lsndx.col].op);
			dram1_tid.core <= CORENO;
			dram1_tid.channel <= 3'd2;
			dram1_tid.tranid <= dram1_tid.tranid + 2'd1;
			rob[lsq[mem1_lsndx.row][mem1_lsndx.col].rndx].out	<= VAL;
	    dram1_tocnt <= 12'd0;
	  end
	end
 
  for (n3 = 0; n3 < ROB_ENTRIES; n3 = n3 + 1) begin
		if (robentry_stomp[n3] && rob[n3].lsqndx==mem0_lsndx)
			dram0_stomp <= 1'b1;
		if (robentry_stomp[n3] && rob[n3].lsqndx==mem1_lsndx)
			dram1_stomp <= 1'b1;
	end

//
// ENQUEUE
//
	// Do not queue while processing a branch miss. Once the queue has been
	// invalidated (state 2), quing new instructions can begin.
	// Only reset the tail if something was stomped on. It could be that there
	// are no valid instructions following the branch in the queue.
	if ((branchmiss || branchmiss_state < 3'd4) && |robentry_stomp)
		tail0 <= stail;		// computed above
	else if (!stallq) begin
		if (rob[tail0].v==INV &&
			rob[tail1].v==INV && 
			rob[tail2].v==INV && 
			rob[tail3].v==INV) begin
			// On a predicted taken branch the front end will continue to send
			// instructions to be queued, but they will be ignored as they are
			// treated as NOPs as the valid bit will not be set. They will however
			// occupy slots in the ROB. It takes extra logic to pack the ROB and
			// the logic budget is tight, so we do not bother. There should be
			// little impact on performance.
			for (n12 = 0; n12 < ROB_ENTRIES; n12 = n12 + 1)
				rob[n12].sn <= rob[n12].sn - 4;
			tEnque(9'h100-XWID,db0_q,pc0_q,grp_q,ins0_q,pt0_q,tail0,
				stomp0, prn[0], prn[1], prn[2], prn[3], prnv[0], prnv[1], prnv[2],
				Rt0_q, cndx, grplen0, last0);
			if (XWID > 1) begin
				tEnque(9'h101-XWID,db1_q,pc1_q,grp_q,ins1_q,pt1_q,tail1,
				stomp1, prn[4], prn[5], prn[6], prn[7], prnv[4], prnv[5], prnv[6],
				Rt1_q, cndx, grplen1, last1);
					// If the instruction's source register is the same as a previous target
					// register, use the register mapping of the previous target register.
					// The register mapping will not have been updated in the RAT yet in
					// time to be available for the source register.
				if (db1_q.Ra==db0_q.Rt && db1_q.Ra!=7'd0) begin $display("bypass: ar%d to pr%d", db1_q.Ra, Rt0_q); rob[tail1].pRa <= Rt0_q; rob[tail1].argA_v <= fnSourceAv(ins1_q); end
				if (db1_q.Rb==db0_q.Rt && db1_q.Rb!=7'd0) begin rob[tail1].pRb <= Rt0_q; rob[tail1].argB_v <= fnSourceBv(ins1_q); end
				if (db1_q.Rc==db0_q.Rt && db1_q.Rc!=7'd0) begin rob[tail1].pRc <= Rt0_q; rob[tail1].argC_v <= fnSourceCv(ins1_q); end
			end
			if (XWID > 2) begin
				tEnque(9'h102-XWID,db2_q,pc2_q,grp_q,ins2_q,pt2_q,tail2,
				stomp2, prn[8], prn[9], prn[10], prn[11], prnv[8], prnv[9], prnv[10], 
				Rt2_q, cndx, grplen2, last3);
				if (db2_q.Ra==db0_q.Rt && db2_q.Ra!=7'd0) begin $display("bypass: ar%d to pr%d", db2_q.Ra, Rt0_q); rob[tail2].pRa <= Rt0_q; rob[tail2].argA_v <= fnSourceAv(ins2_q); end
				if (db2_q.Rb==db0_q.Rt && db2_q.Rb!=7'd0) begin rob[tail2].pRb <= Rt0_q; rob[tail2].argB_v <= fnSourceBv(ins2_q); end
				if (db2_q.Rc==db0_q.Rt && db2_q.Rc!=7'd0) begin rob[tail2].pRc <= Rt0_q; rob[tail2].argC_v <= fnSourceCv(ins2_q); end
				if (db2_q.Ra==db1_q.Rt && db2_q.Ra!=7'd0) begin $display("bypass: ar%d to pr%d", db2_q.Ra, Rt1_q); rob[tail2].pRa <= Rt1_q; rob[tail2].argA_v <= fnSourceAv(ins2_q); end
				if (db2_q.Rb==db1_q.Rt && db2_q.Rb!=7'd0) begin rob[tail2].pRb <= Rt1_q; rob[tail2].argB_v <= fnSourceBv(ins2_q); end
				if (db2_q.Rc==db1_q.Rt && db2_q.Rc!=7'd0) begin rob[tail2].pRc <= Rt1_q; rob[tail2].argC_v <= fnSourceCv(ins2_q); end
			end
			if (XWID > 3) begin
				tEnque(9'h103-XWID,db3_q,pc3_q,grp_q,ins3_q,pt3_q,tail3,
				stomp3, prn[12], prn[13], prn[14], prn[15], prnv[12], prnv[13], prnv[14],
				Rt3_q, cndx,grplen3,last3);
				if (db3_q.Ra==db0_q.Rt && db3_q.Ra!=7'd0) begin $display("bypass: ar%d to pr%d", db3_q.Ra, Rt0_q); rob[tail3].pRa <= Rt0_q; rob[tail3].argA_v <= fnSourceAv(ins3_q); end
				if (db3_q.Rb==db0_q.Rt && db3_q.Rb!=7'd0) begin rob[tail3].pRb <= Rt0_q; rob[tail3].argB_v <= fnSourceBv(ins3_q); end
				if (db3_q.Rc==db0_q.Rt && db3_q.Rc!=7'd0) begin rob[tail3].pRc <= Rt0_q; rob[tail3].argC_v <= fnSourceCv(ins3_q); end
				if (db3_q.Ra==db1_q.Rt && db3_q.Ra!=7'd0) begin $display("bypass: ar%d to pr%d", db3_q.Ra, Rt1_q); rob[tail3].pRa <= Rt1_q; rob[tail3].argA_v <= fnSourceAv(ins3_q); end
				if (db3_q.Rb==db1_q.Rt && db3_q.Rb!=7'd0) begin rob[tail3].pRb <= Rt1_q; rob[tail3].argB_v <= fnSourceBv(ins3_q); end
				if (db3_q.Rc==db1_q.Rt && db3_q.Rc!=7'd0) begin rob[tail3].pRc <= Rt1_q; rob[tail3].argC_v <= fnSourceCv(ins3_q); end
				if (db3_q.Ra==db2_q.Rt && db3_q.Ra!=7'd0) begin $display("bypass: ar%d to pr%d", db3_q.Ra, Rt2_q); rob[tail3].pRa <= Rt2_q; rob[tail3].argA_v <= fnSourceAv(ins3_q); end
				if (db3_q.Rb==db2_q.Rt && db3_q.Rb!=7'd0) begin rob[tail3].pRb <= Rt2_q; rob[tail3].argB_v <= fnSourceBv(ins3_q); end
				if (db3_q.Rc==db2_q.Rt && db3_q.Rc!=7'd0) begin rob[tail3].pRc <= Rt2_q; rob[tail3].argC_v <= fnSourceCv(ins3_q); end
			end
			tail0 <= (tail0 + 3'd4) % ROB_ENTRIES;
		end
	end

	// Place up to two instructions into the load/store queue in order.	

	if (lsq[lsq_tail0.row][0].v==INV && rob[agen0_id].out) begin	// Can an entry be queued?
		rob[agen0_id].out <= FALSE;
		rob[agen0_id].lsq <= 1'b1;
		rob[agen0_id].lsqndx <= lsq_tail0;
		if (LSQ2 && lsq[lsq_tail0.row][1].v==INV && rob[agen1_id].out) begin	// Can a second entry be queued?
			rob[agen1_id].out <= FALSE;
			rob[agen1_id].lsq <= 1'b1;
			rob[agen1_id].lsqndx <= {lsq_tail0.row,1'b1};
		end
	end

	if (lsq[lsq_tail0.row][0].v==INV && rob[agen0_id].out) begin	// Can an entry be queued?
		lsq[lsq_tail0.row][0].rndx <= agen0_id;
		lsq[lsq_tail0.row][0].v <= VAL;
		lsq[lsq_tail0.row][0].agen <= FALSE;
		lsq[lsq_tail0.row][0].op <= rob[agen0_id].op;
		lsq[lsq_tail0.row][0].pc <= rob[agen0_id].pc;
		lsq[lsq_tail0.row][0].load <= rob[agen0_id].decbus.load;
		lsq[lsq_tail0.row][0].loadz <= rob[agen0_id].decbus.loadz;
		lsq[lsq_tail0.row][0].store <= rob[agen0_id].decbus.store;
		store_argC_reg <= rob[agen0_id].pRc;
		//store_tail <= lsq_tail0;
		lsq[lsq_tail0.row][0].Rc <= rob[agen0_id].pRc;
		lsq[lsq_tail0.row][0].Rt <= rob[agen0_id].nRt;
		lsq[lsq_tail0.row][0].aRt <= rob[agen0_id].decbus.Rt;
		lsq[lsq_tail0.row][0].om <= rob[agen0_id].om;
		lsq[lsq_tail0.row][0].memsz <= fnMemsz(rob[agen0_id].op);
		for (n12r = 0; n12r < LSQ_ENTRIES; n12r = n12r + 1)
			for (n12c = 0; n12c < 2; n12c = n12c + 1)
				lsq[n12r][n12c].sn <= lsq[n12r][n12c].sn - 1;
		lsq[lsq_tail0.row][0].sn <= 8'hFF;
		lsq_tail.row <= (lsq_tail.row + 2'd1) % LSQ_ENTRIES;
		lsq_tail.col <= 3'd0;
		if (LSQ2 && lsq[lsq_tail0.row][1].v==INV && rob[agen1_id].out) begin	// Can a second entry be queued?
			lsq[lsq_tail0.row][1].rndx <= agen1_id;
			lsq[lsq_tail0.row][1].v <= VAL;
			lsq[lsq_tail0.row][1].agen <= FALSE;
			lsq[lsq_tail0.row][1].op <= rob[agen1_id].op;
			lsq[lsq_tail0.row][1].pc <= rob[agen1_id].pc;
			lsq[lsq_tail0.row][1].load <= rob[agen1_id].decbus.load;
			lsq[lsq_tail0.row][1].loadz <= rob[agen1_id].decbus.loadz;
			lsq[lsq_tail0.row][1].store <= rob[agen1_id].decbus.store;
			lsq[lsq_tail0.row][1].Rc <= rob[agen1_id].pRc;
			lsq[lsq_tail0.row][1].Rt <= rob[agen1_id].nRt;
			lsq[lsq_tail0.row][1].aRt <= rob[agen1_id].decbus.Rt;
			lsq[lsq_tail0.row][1].om <= rob[agen1_id].om;
			lsq[lsq_tail0.row][1].memsz <= fnMemsz(rob[agen1_id].op);
			for (n12r = 0; n12r < LSQ_ENTRIES; n12r = n12r + 1)
				for (n12c = 0; n12c < 2; n12c = n12c + 1)
					lsq[n12r][n12c].sn <= lsq[n12r][n12c].sn - 2;
			lsq[lsq_tail0.row][0].sn <= 8'hFE;
			lsq[lsq_tail0.row][1].sn <= 8'hFF;
		end
	end
	if (lsq[store_tail.row][store_tail.col].store &&
	 	lsq[store_tail.row][store_tail.col].v && !lsq[store_tail.row][store_tail.col].datav) begin
		lsq[store_tail.row][store_tail.col].res <= rfo_store_argC;
		if (rob[lsq[store_tail.row][store_tail.col].rndx].argC_v)
			lsq[store_tail.row][store_tail.col].datav <= VAL;
	end
	if (lsq[mem0_lsndx.row][mem0_lsndx.col].store)
		store_argC_reg <= lsq[mem0_lsndx.row][mem0_lsndx.col].Rc;
	if (lsq[mem1_lsndx.row][mem1_lsndx.col].store)
		store_argC_reg <= lsq[mem1_lsndx.row][mem1_lsndx.col].Rc;

//
// COMMIT
//
// Only the first oddball instruction is allowed to commit.
// Only the first exception is processed.
// Trigger page walk TLB update for outstanding agen request. Must be done when
// the instruction is at the commit stage to mitigate Spectre attacks.
	commit0_id <= head0;
	commit1_id <= head1;
	commit2_id <= head2;
	commit3_id <= head3;
	commit0_idv <= cmttlb0;
	commit1_idv <= cmttlb1;
	commit2_idv <= cmttlb2;
	commit3_idv <= cmttlb3;
	if (do_commit) begin
		commit_pc0 <= rob[head0].pc;
		commit_pc1 <= rob[head1].pc;
		commit_pc2 <= rob[head2].pc;
		commit_pc3 <= rob[head3].pc;
		commit_brtgt0 <= rob[head0].brtgt;
		commit_brtgt1 <= rob[head1].brtgt;
		commit_brtgt2 <= rob[head2].brtgt;
		commit_brtgt3 <= rob[head3].brtgt;
		commit_takb0 <= rob[head0].takb;
		commit_takb1 <= rob[head1].takb;
		commit_takb2 <= rob[head2].takb;
		commit_takb3 <= rob[head3].takb;
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
		I <= I + rob[head0].v;
		group_len <= group_len - 1;
		rob[head0].v <= INV;
		rob[head0].lsq <= 1'd0;
		if (cmtcnt > 3'd1) begin
			I <= I + rob[head0].v + rob[head1].v;
			rob[head1].v <= INV;
			rob[head1].lsq <= 1'd0;
			if (rob[head1].lsq)
				lsq[rob[head1].lsqndx.row][rob[head1].lsqndx.col].v <= INV;
			tags2free[1] <= rob[head1].pRt;
			freevals[1] <= |rob[head1].pRt;
			group_len <= group_len - 2;
		end
		if (cmtcnt > 3'd2) begin
			I <= I + rob[head0].v + rob[head1].v + rob[head2].v;
			rob[head2].v <= INV;
			rob[head2].lsq <= 1'd0;
			if (rob[head2].lsq)
				lsq[rob[head2].lsqndx.row][rob[head2].lsqndx.col].v <= INV;
			tags2free[2] <= rob[head2].pRt;
			freevals[2] <= |rob[head2].pRt;
			group_len <= group_len - 3;
		end
		if (cmtcnt > 3'd3) begin
			I <= I + rob[head0].v + rob[head1].v + rob[head2].v + rob[head3].v;
			rob[head3].v <= INV;
			rob[head3].lsq <= 1'd0;
			if (rob[head3].lsq)
				lsq[rob[head3].lsqndx.row][rob[head3].lsqndx.col].v <= INV;
			tags2free[3] <= rob[head3].pRt;
			freevals[3] <= |rob[head3].pRt;
			group_len <= group_len - 4;
		end
		if (rob[head0].lsq)
			lsq[rob[head0].lsqndx.row][rob[head0].lsqndx.col].v <= INV;
		tags2free[0] <= rob[head0].pRt;
		freevals[0] <= |rob[head0].pRt;
		head0 <= (head0 + cmtcnt) % ROB_ENTRIES;
		if (group_len <= 0)
			group_len <= rob[head0].group_len;
		// Commit oddball instructions
		if (rob[head0].decbus.oddball && !rob[head0].excv)
			tOddballCommit(1'b1, head0);
		else if (rob[head1].decbus.oddball && !rob[head1].excv && cmtcnt > 3'd1)
			tOddballCommit(1'b1, head1);
		else if (rob[head2].decbus.oddball && !rob[head2].excv && cmtcnt > 3'd2)
			tOddballCommit(1'b1, head2);
		else if (rob[head3].decbus.oddball && !rob[head3].excv && cmtcnt > 3'd3)
			tOddballCommit(1'b1, head3);
		// Trigger exception processing for last instruction in group.
		if (rob[head0].excv) begin
//			err_mask[head0] <= 1'b1;
//			if (rob[head0].last)
			tProcessExc(head0,rob[head0].pc);
		end
		else if (rob[head1].excv && XWID > 1) begin
			tProcessExc(head1,rob[head1].pc);
		end
		else if (rob[head2].excv && XWID > 2) begin
			tProcessExc(head2,rob[head2].pc);
		end
		else if (rob[head3].excv && XWID > 3) begin
			tProcessExc(head3,rob[head3].pc);
		end
	end
	else begin
		tags2free[0] <= 8'd0;
		tags2free[1] <= 8'd0;
		tags2free[2] <= 8'd0;
		tags2free[3] <= 8'd0;
	end
	
	// Branchmiss
	// Invalidate instructions newer than the branch in the ROB.
	for (n3 = 0; n3 < ROB_ENTRIES; n3 = n3 + 1) begin
		if (robentry_stomp[n3]) begin
			rob[n3].v <= INV;
			rob[n3].out <= FALSE;
			// Clear corresponding LSQ entry.
			if (rob[n3].lsq) begin
				lsq[rob[n3].lsqndx.row][rob[n3].lsqndx.col].v <= INV;
				lsq[rob[n3].lsqndx.row][rob[n3].lsqndx.col].agen <= FALSE;
			end
			rob[n3].lsq <= 1'd0;
		end
	end
	
end

// External bus arbiter. Simple priority encoded.

always_comb
begin
	
	ftatm_resp <= {$bits(fta_cmd_response128_t){1'd0}};
	ftaim_resp <= {$bits(fta_cmd_response128_t){1'd0}};
	ftadm_resp[0] <= {$bits(fta_cmd_response128_t){1'd0}};
	ftadm_resp[1] <= {$bits(fta_cmd_response128_t){1'd0}};

	// Setup to retry.
	ftatm_resp.rty <= 1'b1;
	ftaim_resp.rty <= 1'b1;
	ftadm_resp[0].rty <= 1'b1;
	ftadm_resp[1].rty <= 1'b1;
		
	// Cancel retry if bus aquired.
	if (ftatm_req.cyc) begin
		fta_req <= ftatm_req;
		ftatm_resp.rty <= 1'b0;
	end
	else if (ftaim_req.cyc) begin
		fta_req <= ftaim_req;
		ftaim_resp.rty <= 1'b0;
	end
	else if (ftadm_req[0].cyc) begin
		fta_req <= ftadm_req[0];
		ftadm_resp[0].rty <= 1'b0;
	end
	else if (ftadm_req[1].cyc) begin
		fta_req <= ftadm_req[1];
		ftadm_resp[1].rty <= 1'b0;
	end
	else
		fta_req <= {$bits(fta_cmd_request128_t){1'd0}};

	// Route bus responses.
	/*
	if (fta_resp.cid==ftatm_req.cid)
		ftatm_resp <= fta_resp;
	else if (fta_resp.cid==ftaim_req.cid)
		ftaim_resp <= fta_resp;
	else if (fta_resp.cid==ftadm_req[0].cid)
		ftadm_resp[0] <= fta_resp;
	else if (fta_resp.cid==ftadm_req[1].cid)
		ftadm_resp[1] <= fta_resp;
	*/
	case(fta_resp.tid.channel)
	3'd0:	ftaim_resp <= fta_resp;
	3'd1:	ftadm_resp[0] <= fta_resp;
//	3'd2:	ftadm_resp[1] <= fta_resp;
	3'd3:	ftatm_resp <= fta_resp;
	default:	;	// response was not for us
	endcase
	
end
/*
function value_t fnRegVal;
input pregno_t regno;
begin
	case (urf1.lvt[regno])
	2'd0:	fnRegVal = urf1.gRF.genblk1[0].urf0.mem[regno];
	2'd1:	fnRegVal = urf1.gRF.genblk1[0].urf1.mem[regno];
	2'd2:	fnRegVal = urf1.gRF.genblk1[0].urf2.mem[regno];
	2'd3:	fnRegVal = urf1.gRF.genblk1[0].urf3.mem[regno];
	endcase
end
endfunction

generate begin : gDisplay
if (SIM) begin
always_ff @(posedge clk) begin: clock_n_debug
	integer i;
	integer j;

	$display("\n\n\n\n\n\n\n\n");
	$display("TIME %0d", $time);
	$display("%h #", pc);
	$display("----- Physical Registers -----");
	for (i=0; i< PREGS; i=i+8)
	    $display("%d: %h %d: %h %d: %h %d: %h %d: %h %d: %h %d: %h %d: %h #",
	    	i+0, fnRegVal(i+0), i+1, fnRegVal(i+1), i+2, fnRegVal(i+2), i+3, fnRegVal(i+3),
	    	i+4, fnRegVal(i+4), i+5, fnRegVal(i+5), i+6, fnRegVal(i+6), i+7, fnRegVal(i+7)
	    );
end
end
end
endgenerate
*/
task tReset;
begin
	micro_ir <= {33'd0,OP_NOP};
	micro_ip <= 12'h1A0;
	for (n14 = 0; n14 < 4; n14 = n14 + 1) begin
		kvec[n14] <= RSTPC;
		avec[n14] <= RSTPC;
	end
	err_mask <= 64'd0;
	excir <= {33'd0,OP_NOP};
	excmiss <= 1'b0;
	excmisspc <= RSTPC;
	sr <= 64'd0;
	sr.om <= OM_MACHINE;
	sr.ipl <= 3'd7;				// non-maskable interrupts only
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
	dram0_exc <= FLT_NONE;
	dram0_id <= 5'd0;
	dram0_load <= 1'd0;
	dram0_loadz <= 1'd0;
	dram0_store <= 1'd0;
	dram0_erc <= 1'd0;
	dram0_op <= OP_NOP;
	dram0_Rt <= 8'd0;
	dram0_tid <= 13'd0;
	dram0_hi <= 1'd0;
	dram0_shift <= 1'd0;
	dram0_tocnt <= 12'd0;
	dram1_stomp <= 32'd0;
	dram1_vaddr <= 64'd0;
	dram1_paddr <= 64'd0;
	dram1_data <= 512'd0;
	dram1_exc <= FLT_NONE;
	dram1_id <= 5'd0;
	dram1_load <= 1'd0;
	dram1_loadz <= 1'd0;
	dram1_store <= 1'd0;
	dram1_erc <= 1'd0;
	dram1_op <= OP_NOP;
	dram1_Rt <= 8'd0;
	dram1_tid <= 8'h08;
	dram1_hi <= 1'd0;
	dram1_shift <= 1'd0;
	dram1_tocnt <= 12'd0;
	dram_v0 <= 1'd0;
	dram_v1 <= 1'd0;
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
	alu0_available <= 1;
	alu0_dataready <= 0;
	alu1_available <= 1;
	alu1_dataready <= 0;
	alu0_ld <= 1'b0;
	alu1_ld <= 1'b0;
	alu0_out <= INV;
	alu1_out <= INV;
	alu0_aRt <= 7'd0;
	alu1_aRt <= 7'd0;
	alu0_Rt <= 7'd0;
	alu1_Rt <= 7'd0;
	fpu0_Rt <= 7'd0;
	fpu1_Rt <= 7'd0;
	dram0_Rt <= 7'd0;
	dram1_Rt <= 7'd0;
	alu0_bank <= 2'd0;
	alu1_bank <= 2'd0;
	fpu0_bank <= 2'd0;
	fpu1_bank <= 2'd0;
	dram0_bank <= 2'd0;
	dram1_bank <= 2'd0;
	fpu0_out <= INV;
	fpu0_idle <= TRUE;
	fpu0_available <= 1;
	fpu0_aRt <= 7'd0;
	fpu1_idle <= TRUE;
	fpu1_aRt <= 7'd0;
	fcu_available <= 1;
	fcu_pc <= 64'd0;
	fcu_instr <= OP_NOP;
//	fcu_exc <= FLT_NONE;
	fcu_bt <= 1'd0;
	fcu_bts <= BTS_NONE;
	fcu_argA <= 64'd0;
	fcu_argB <= 64'd0;
	fcu_v <= INV;
	fcu_v2 <= INV;
	fcu_v3 <= INV;
	fcu_v4 <= INV;
	fcu_v5 <= INV;
	fcu_v6 <= INV;
	fcu_idle <= TRUE;
	dram0_aRt <= 7'd0;
	dram1_aRt <= 7'd0;
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
	alu0_idle <= TRUE;
	alu1_idle <= TRUE;
	alu0_done <= TRUE;
	alu1_done <= TRUE;
	agen0_id <= 5'd0;
	agen1_id <= 5'd0;
	agen0_idle <= TRUE;
	agen1_idle <= TRUE;
	brtgtv <= FALSE;
	pc_in_sync <= TRUE;
	freevals <= 4'd0;
	ls_bmf <= 1'd0;
	reg_bitmask <= 64'd0;
end
endtask

task tEnque;
input seqnum_t sn;
input decode_bus_t db;
input pc_address_t pc;
input [2:0] grp;
input instruction_t ins;
input pt;
input rob_ndx_t tail;
input stomp;
input pregno_t pRa;
input pregno_t pRb;
input pregno_t pRc;
input pregno_t pRt;
input pregno_t nRt;
input pRav;
input pRbv;
input pRcv;
input [3:0] cndx;
input rob_ndx_t grplen;
input last;
integer n12;
integer n13;
begin
	// "dynamic" fields, these fields may change after enqueue
	rob[tail].sn <= sn;
	// NOP type instructions appear in the queue but they do not get scheduled or
	// execute. They are marked done immediately.
	rob[tail].done <= {2{db.nop}};
	rob[tail].out <= INV;
	rob[tail].lsq <= INV;
	rob[tail].takb <= 1'b0;
	rob[tail].exc <= FLT_NONE;
	rob[tail].excv <= FALSE;
	rob[tail].argA_v <= fnSourceAv(ins) | pRav;
	rob[tail].argB_v <= fnSourceBv(ins) | pRbv;
	rob[tail].argC_v <= fnSourceCv(ins) | pRcv;
	// "static" fields, these fields remain constant after enqueue
	rob[tail].brtgt <= db.mcb ? db.immc[10:0] : fnTargetIP(pc,db.immc);
	rob[tail].om <= sr.om;
//	rob[tail].rmd <= fpscr.rmd;
	rob[tail].op <= ins;
	rob[tail].pc <= pc;
	if (SUPPORT_IBH)
		rob[tail].grp <= grp;
	rob[tail].bt <= pt;
	rob[tail].cndx <= cndx;
	rob[tail].decbus <= db;
	rob[tail].pRa <= pRa;
	rob[tail].pRb <= pRb;
	rob[tail].pRc <= pRc;
	rob[tail].pRt <= pRt;
	rob[tail].nRt <= nRt;
	rob[tail].group_len <= grplen;
	rob[tail].last <= last;
	rob[tail].v <= !stomp && db.v && !brtgtv;
	if (!stomp && db.v && !brtgtv) begin
		brtgt <= db.mcb ? db.immc[10:0] : fnTargetIP(pc,db.immc);
		brtgtv <= db.br & pt;
	end
	$display("mapped A: ar%d to pr%d", db.Ra, pRa);
	if (pRa==8'd0 && db.Ra != 7'd0) begin
		$display("tail: %d", tail);
		$finish;
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
		if (rob[head].decbus.csr)
			case(rob[head].op[39:38])
			2'd0:	;	// readCSR
			2'd1:	tWriteCSR(rob[head].arg,{2'b0,rob[head].op[32:19]});
			2'd2:	tSetbitCSR(rob[head].arg,{2'b0,rob[head].op[32:19]});
			2'd3:	tClrbitCSR(rob[head].arg,{2'b0,rob[head].op[32:19]});
			endcase
		else if (rob[head].decbus.irq)
			;
		else if (rob[head].decbus.brk)
			tProcessExc(head,fnPCInc(rob[head].pc));
		else if (rob[head].decbus.rti)
			tProcessRti(rob[head].op[15:13]==3'd2);
		else if (rob[head].decbus.rex)
			tRex(head,rob[head].op);
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
		16'h303C:	res = {sr_stack[1],sr_stack[0]};
		16'h303D:	res = {sr_stack[3],sr_stack[2]};
		16'h303E:	res = {sr_stack[5],sr_stack[4]};
		16'h303F:	res = {sr_stack[7],sr_stack[6]};
		(CSR_MEPC+0):	res = pc_stack[0];
		(CSR_MEPC+1):	res = pc_stack[1];
		(CSR_MEPC+2):	res = pc_stack[2];
		(CSR_MEPC+3):	res = pc_stack[3];
		(CSR_MEPC+4):	res = pc_stack[4];
		(CSR_MEPC+5):	res = pc_stack[5];
		(CSR_MEPC+6):	res = pc_stack[6];
		(CSR_MEPC+7):	res = pc_stack[7];
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
		CSR_SR:		sr <= val;
		CSR_ASID: 	asid <= val;
		CSR_KVEC3:	kvec[3] <= val;
		16'h303C: {sr_stack[1],sr_stack[0]} <= val;
		16'h303D:	{sr_stack[3],sr_stack[2]} <= val;
		16'h303E:	{sr_stack[5],sr_stack[4]} <= val;
		16'h303F:	{sr_stack[7],sr_stack[6]} <= val;
		CSR_MEPC+0:	pc_stack[0] <= val;
		CSR_MEPC+1:	pc_stack[1] <= val;
		CSR_MEPC+2:	pc_stack[2] <= val;
		CSR_MEPC+3:	pc_stack[3] <= val;
		CSR_MEPC+4:	pc_stack[4] <= val;
		CSR_MEPC+5:	pc_stack[5] <= val;
		CSR_MEPC+6:	pc_stack[6] <= val;
		CSR_MEPC+7:	pc_stack[7] <= val;
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
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tProcessExc;
input rob_ndx_t id;
input pc_address_t retpc;
integer nn;
reg [8:0] vecno;
begin
	//vecno = rob[id].imm ? rob[id].a0[8:0] : rob[id].a1[8:0];
	vecno = rob[id].exc;
	for (nn = 1; nn < 8; nn = nn + 1)
		sr_stack[nn] <= sr_stack[nn-1];
	sr_stack[0] <= sr;
	for (nn = 1; nn < 8; nn = nn + 1)
		pc_stack[nn] <= pc_stack[nn-1];
	pc_stack[0] <= retpc;
	for (nn = 1; nn < 8; nn = nn + 1)
		mc_stack[nn] <= mc_stack[nn-1];
	mc_stack[0].ir <= micro_ir;
	mc_stack[0].ip <= micro_ip;
	sr.ipl <= 3'd7;
	sr.mcip <= micro_ip;
	excir <= rob[id].op;
	excid <= id;
	excmiss <= 1'b1;
	if (vecno < 9'd64)
		excmisspc <= {kvec[3][$bits(pc_address_t)-1:16] /*+ vecno*/,4'h0,12'h000};
	else
		excmisspc <= {avec[$bits(pc_address_t)-1:16] + vecno,4'h0,12'h000};
end
endtask

task tProcessRti;
input twoup;
integer nn;
begin
	err_mask <= 64'd0;
	sr <= twoup ? sr_stack[1] : sr_stack[0];
	for (nn = 0; nn < 7; nn = nn + 1)
		sr_stack[nn] <= sr_stack[nn+1+twoup];
	sr_stack[7].ipl <= 3'd7;
	sr_stack[8].ipl <= 3'd7;
	sr_stack[7].om <= OM_MACHINE;
	sr_stack[8].om <= OM_MACHINE;
	for (nn = 0; nn < 7; nn = nn + 1)
		pc_stack[nn] <=	pc_stack[nn+1+twoup];
	pc_stack[7] <= RSTPC;
	pc_stack[8] <= RSTPC;
	// Unstack the micro-code instruction register
	micro_ir <= twoup ? mc_stack[1].ir : mc_stack[0].ir;
	micro_ip <= twoup ? mc_stack[1].ip : mc_stack[0].ip;
	for (nn = 0; nn < 7; nn = nn + 1)
		mc_stack[nn] <=	mc_stack[nn+1+twoup];
	mc_stack[7].ir <= {33'd0,OP_NOP};
	mc_stack[8].ir <= {33'd0,OP_NOP};
	mc_stack[7].ip <= 12'h0;
	mc_stack[8].ip <= 12'h0;
end
endtask

task tRex;
input rob_ndx_t id;
input instruction_t ir;
reg [8:0] vecno;
begin
	vecno = cause[3][8:0];
	if (sr.om > ir[8:7]) begin
		sr.om <= operating_mode_t'(ir[8:7]);
		excid <= id;
		excmiss <= 1'b1;
		if (vecno < 9'd64)
			excmisspc <= {kvec[ir[8:7]][$bits(pc_address_t)-1:16] + vecno,4'h0,12'h000};
		else
			excmisspc <= {avec[$bits(pc_address_t)-1:16] + vecno,4'h0,12'h000};
	end
end
endtask

endmodule

module modFcuMissPC(instr, bts, pc, pc_stack, bt, argA, argI, ibh, misspc, missgrp);
input instruction_t instr;
input bts_t bts;
input pc_address_t pc;
input pc_address_t [8:0] pc_stack;
input bt;
input value_t argA;
input value_t argI;
input ibh_t ibh;
output pc_address_t misspc;
output reg [2:0] missgrp;

reg [5:0] ino;
reg [5:0] ino5;
reg [63:0] disp;
always_comb
begin
	ino = {2'd0,instr[26:25],instr[12:11]};
	ino5 = {ino,2'd0} + ino;
	disp = {{47{instr[39]}},instr[39:25],instr[12:11]};
	case(bts)
	/*
	BTS_REG:
		 begin
			misspc = bt ? tpc : argC + {{53{instr[39]}},instr[39:31],instr[12:11]};
		end
	*/
	BTS_DISP:
		begin
			misspc = bt ? pc + 4'd5 : fnTargetIP(pc,disp);
//			misspc = bt ? pc + 4'd5 : pc + {{47{instr[39]}},instr[39:25],instr[12:11]};
		end
	BTS_BSR:
		begin
			ino = {2'd0,instr[16:13]};
			ino5 = {ino,2'd0} + ino;
			misspc = {pc[$bits(pc_address_t)-1:6] + {{37{instr[39]}},instr[39:17]},ino5};
		end
	BTS_CALL:
		begin
			misspc = argA + argI;
		end
	// Must be tested before Ret
	BTS_RTI:
		begin
			misspc = (instr[8:7]==2'd1 ? pc_stack[1] : pc_stack[0]) + instr[12:7];
		end
	BTS_RET:
		begin
			misspc = argA;
		end
	default:
		misspc = RSTPC;
	endcase
end

always_comb
begin
	if (misspc[5:0] >= ibh.offs[3])
		missgrp = 3'd4;
	else if (misspc[5:0] >= ibh.offs[2])
		missgrp = 3'd3;
	else if (misspc[5:0] >= ibh.offs[1])
		missgrp = 3'd2;
	else if (misspc[5:0] >= ibh.offs[0])
		missgrp = 3'd1;
	else
		missgrp = 3'd0;
end

endmodule
