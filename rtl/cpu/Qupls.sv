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
parameter DRAMSLOT_AVAIL = 3'd0;
parameter DRAMSLOT_READY = 3'd1;
parameter DRAMSLOT_ACTIVE = 3'd2;
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
fta_cmd_request128_t [NDATA_PORTS-1:0] ftadm_req;
fta_cmd_response128_t [NDATA_PORTS-1:0] ftadm_resp;


integer nn,mm,n3,n4,m4,n5,n6,n7,n8,n9,n10,n12,n14,n15;
genvar g,h;
rndx_t alu0_re;
reg [127:0] message;
wire rst;
wire clk;
wire clk2x;
assign rst = rst_i;
reg [3:0] panic;
reg int_commit;		// IRQ committed
// hirq squashes the pc increment if there's an irq.
// Normally atom_mask is zero.
reg hirq;
pc_address_t misspc;
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
value_t rfo_fcu_argA;
value_t rfo_fcu_argB;
value_t rfo_agen0_argA;
value_t rfo_agen1_argA;
value_t rfo_agen0_argB;
value_t rfo_agen1_argB;
value_t rfo_store_argC;
value_t load_res;
value_t ma0,ma1;				// memory address

pregno_t alu0_argA_reg;
pregno_t alu0_argB_reg;
pregno_t alu0_argC_reg;

pregno_t alu1_argA_reg;
pregno_t alu1_argB_reg;
pregno_t alu1_argC_reg;

pregno_t fpu0_argA_reg;
pregno_t fpu0_argB_reg;
pregno_t fpu0_argC_reg;
pregno_t fpu_argA_reg;
pregno_t fpu_argB_reg;
pregno_t fpu_argC_reg;

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
rob_bitmask_t robentry_stomp;
rob_bitmask_t robentry_issue_reg;
rob_bitmask_t robentry_issue2;
rob_bitmask_t robentry_fcu_issue;
lsq_entry_t [7:0] loadq, storeq;
lsq_entry_t [15:0] lsq;
lsq_ndx_t lq_tail, lq_head;

rob_ndx_t tail0, tail1, tail2, tail3;
rob_ndx_t head0, head1, head2, head3;
rob_ndx_t store_tail;

always_comb tail1 = (tail0 + 1) % ROB_ENTRIES;
always_comb tail2 = (tail0 + 2) % ROB_ENTRIES;
always_comb tail3 = (tail0 + 3) % ROB_ENTRIES;
always_comb head1 = (head0 + 1) % ROB_ENTRIES;
always_comb head2 = (head0 + 2) % ROB_ENTRIES;
always_comb head3 = (head0 + 3) % ROB_ENTRIES;

rob_ndx_t alu0_sndx;
rob_ndx_t alu1_sndx;
wire alu0_sv;
wire alu1_sv;

reg flu0_idle = 1'b1;
reg agen0_idle = 1'b1;
reg agen1_idle = 1'b1;
reg alu0_idle = 1'b1;
reg        alu0_available;
reg        alu0_dataready;
reg  [4:0] alu0_sourceid;
instruction_t alu0_instr;
reg alu0_div;
value_t alu0_argA;
value_t alu0_argB;
value_t alu0_argC;
value_t alu0_argI;	// only used by BEQ
pregno_t alu0_Rt;
value_t alu0_cmpo;
pc_address_t alu0_pc;
value_t alu0_res;
rob_ndx_t alu0_id;
cause_code_t alu0_exc = FLT_NONE;
wire        alu0_v;
double_value_t alu0_prod,alu0_prod1,alu0_prod2;
double_value_t alu0_produ,alu0_produ1,alu0_produ2;
reg [3:0] mul0_cnt;
reg mul0_done;
value_t div0_q,div0_r;
wire div0_done,div0_dbz;
reg alu0_ld;
reg alu0_done;

reg alu1_idle = 1'b1;
reg        alu1_available;
reg        alu1_dataready;
reg  [4:0] alu1_sourceid;
instruction_t alu1_instr;
reg alu1_div;
value_t alu1_argA;
value_t alu1_argB;
value_t alu1_argC;
value_t alu1_argI;	// only used by BEQ
pregno_t alu1_Rt;
value_t alu1_cmpo;
pc_address_t alu1_pc;
value_t alu1_res;
wire  [4:0] alu1_id;
cause_code_t alu1_exc;
wire        alu1_v;
double_value_t alu1_prod,alu1_prod1,alu1_prod2;
double_value_t alu1_produ,alu1_produ1,alu1_produ2;
reg [3:0] mul1_cnt;
reg mul1_done;
value_t div1_q,div1_r;
wire div1_done,div1_dbz;
reg alu1_ld;
reg alu1_done;

reg fpu_idle = 1'b1;
reg        fpu_available;
reg        fpu_dataready;
reg  [4:0] fpu_sourceid;
instruction_t fpu_instr;
value_t fpu_argA;
value_t fpu_argB;
value_t fpu_argC;
value_t fpu_argT;
value_t fpu_argP;
value_t fpu_argI;	// only used by BEQ
pregno_t fpu_Rt;
pc_address_t fpu_pc;
value_t fpu_res;
rob_ndx_t fpu_id;
cause_code_t fpu_exc = FLT_NONE;
wire        fpu_v;
wire fpu_done1;
reg fpu_done;

reg fcu_idle = 1'b1;
reg        fcu_available;
reg        fcu_dataready;
reg  [4:0] fcu_sourceid;
instruction_t fcu_instr;
bts_t fcu_bts;
reg        fcu_bt;
value_t fcu_argA;
value_t fcu_argB;
value_t fcu_argC;
value_t fcu_argT;
value_t fcu_argP;
value_t fcu_argI;	// only used by BEQ
pc_address_t fcu_pc;
value_t fcu_res;
wire  [4:0] fcu_id;
cause_code_t fcu_exc;
wire        fcu_v;
reg fcu_branchmiss;
pc_address_t fcu_misspc;
instruction_t fcu_missir;
reg takb;
reg fcu_done;

value_t agen0_argA;
value_t agen0_argB;
value_t agen0_argI;
pc_address_t agen0_pc;

value_t agen1_argA;
value_t agen1_argB;
value_t agen1_argI;
pc_address_t agen1_pc;

address_t tlb0_res, tlb1_res;

reg [2:0] branchmiss_state;
reg [4:0] excid;
pc_address_t excmisspc;
reg excmiss;
instruction_t excir;

wire dram_avail;
reg	[2:0] dram0,dram0p;	// state of the DRAM request (latency = 4; can have three in pipeline)
reg	[2:0] dram1,dram1p;	// state of the DRAM request (latency = 4; can have three in pipeline)
//reg	 [1:0] dram2;	// state of the DRAM request (latency = 4; can have three in pipeline)
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

reg [639:0] dram0_data;
virtual_address_t dram0_vaddr;
physical_address_t dram0_paddr;
reg [79:0] dram0_sel;
instruction_t dram0_op;
memsz_t dram0_memsz;
rob_ndx_t dram0_id;
reg dram0_load;
reg dram0_loadz;
reg dram0_store;
pregno_t dram0_Rt, dram_Rt0;
cause_code_t dram0_exc;
reg dram0_ack;
reg [7:0] dram0_tid;
reg dram0_more;
reg dram0_hi;
reg dram0_erc;
reg [9:0] dram0_shift;
reg dram0_stomp;
reg [11:0] dram0_tocnt;

reg [639:0] dram1_data;
virtual_address_t dram1_vaddr;
physical_address_t dram1_paddr;
reg [79:0] dram1_sel;
instruction_t dram1_op;
memsz_t dram1_memsz;
rob_ndx_t dram1_id;
reg dram1_load;
reg dram1_loadz;
reg dram1_store;
pregno_t dram1_Rt, dram_Rt1;
cause_code_t dram1_exc;
reg dram1_ack;
reg [7:0] dram1_tid;
reg dram1_more;
reg dram1_erc;
reg dram1_hi;
reg [9:0] dram1_shift;
reg dram1_stomp;
reg [11:0] dram1_tocnt;

pc_address_t commit_pc0, commit_pc1, commit_pc2, commit_pc3;
pc_address_t commit_brtgt0;
pc_address_t commit_brtgt1;
pc_address_t commit_brtgt2;
pc_address_t commit_brtgt3;
reg commit_takb0;
reg commit_takb1;
reg commit_takb2;
reg commit_takb3;

// CSRs
reg [63:0] tick;
cause_code_t [3:0] cause;
status_reg_t sr_stack [0:8];
status_reg_t sr;
pc_address_t [8:0] pc_stack;
wire [2:0] im = sr.ipl;
reg [5:0] regset = 6'd0;
asid_t asid;
asid_t ip_asid;
pc_address_t [3:0] kvec;
pc_address_t avec;
reg ERC = 1'b0;

reg [2:0] atom_mask;

assign clk = clk_i;				// convenience
assign clk2x = clk2x_i;


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

/*
	alu0_argA_reg <= rob[alu0_re].Ra;
	alu0_argB_reg <= rob[alu0_re].Rb;
	alu0_argC_reg <= rob[alu0_re].Rc;

	alu1_argA_reg <= rob[alu1_re].Ra;
	alu1_argB_reg <= rob[alu1_re].Rb;
	alu1_argC_reg <= rob[alu1_re].Rc;

	fpu0_argA_reg <= rob[fpu0_re].Ra;
	fpu0_argB_reg <= rob[fpu0_re].Rb;
	fpu0_argC_reg <= rob[fpu0_re].Rc;

	fcu_argA_reg <= rob[fcu_re].Ra;
	fcu_argB_reg <= rob[fcu_re].Rb;
	fcu_argT_reg <= rob[fcu_re].Rt;

	load_argA_reg <= rob[load_re].Ra;
	load_argB_reg <= rob[load_re].Rb;
	load_argC_reg <= rob[load_re].Rc;

	store_argA_reg <= rob[store_re].Ra;
	store_argB_reg <= rob[store_re].Rb;
	store_argC_reg <= rob[store_re].Rc;
*/

ICacheLine ic_line_hi, ic_line_lo;

//
// FETCH
//

pc_address_t pc0, pc1, pc2, pc3, pc4, pc5, pc6;
pc_address_t pc0d, pc1d, pc2d, pc3d, pc4d, pc5d, pc6d;
pc_address_t pc0r, pc1r, pc2r, pc3r, pc4r, pc5r, pc6r;
pc_address_t next_pc;
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
reg [511:0] ins;
instruction_t ins0, ins1, ins2, ins3, ins4, ins5, ins6;
reg ins0_v, ins1_v, ins2_v, ins3_v;
reg [3:0] ins_v;
reg insnq0,insnq1,insnq2,insnq3;
reg [3:0] qd, cqd, qs;
reg [3:0] next_cqd;
wire pe_alldq;
reg fetch_new;
tlb_entry_t tlb_pc_entry;
address_t pc_tlb_res;
wire pc_tlb_v;

wire pt0, pt1, pt2, pt3;		// predict taken branches

reg branchmiss, branchmiss_next;
rob_ndx_t missid;

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
		ins2_v <= ins2_v & ~(qd[2]|qs[2]);
		ins3_v <= ins3_v & ~(qd[3]|qs[3]);
	end
end

wire ftaim_full, ftadm_full;

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
	.ip_asid(ip_asid),
	.ip(pc0[43:12]),
	.ip_o(),
	.ihit_o(ihito),
	.ihit(ihit),
	.ic_line_hi_o(ic_line_hi),
	.ic_line_lo_o(ic_line_lo),
	.ic_valid(ic_valid),
	.miss_adr(ic_miss_adr),
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
	.ftam_full(ftaim_full),
	.hit(ihit),
	.tlb_v(pc_tlb_v),
	.miss_adr({tlb_pc_entry.pte.ppn,pc_tlb_res[15:0]}),
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
	.rclk(~clk),
	.pc0(pc0),
	.pc1(pc1),
	.pc2(pc2),
	.pc3(pc3),
	.pc4(pc4),
	.next_pc(next_pc),
	.takb(ntakb),
	.commit_pc0(commit_pc0),
	.commit_brtgt0(commit_brtgt0),
	.commit_takb0(commit_takb0),
	.commit_pc1(commit_pc1),
	.commit_brtgt1(commit_brtgt1),
	.commit_takb1(commit_takb1),
	.commit_pc2(commit_pc2),
	.commit_brtgt2(commit_brtgt2),
	.commit_takb2(commit_takb2),
	.commit_pc3(commit_pc3),
	.commit_brtgt3(commit_brtgt3),
	.commit_takb3(commit_takb3)
);

always_comb pc1 = {pc0[43:12] + 6'd5,12'h0};
always_comb pc2 = {pc0[43:12] + 6'd10,12'h0};
always_comb pc3 = {pc0[43:12] + 6'd15,12'h0};
always_comb pc4 = {pc0[43:12] + 6'd20,12'h0};
always_comb pc5 = {pc0[43:12] + 6'd25,12'h0};
always_comb pc6 = {pc0[43:12] + 6'd30,12'h0};

// qd indicates which instructions will queue in a given cycle.
// qs indicates which instructions are stomped on.
always_comb
begin
	qd = 'd0;
	qs = 'd0;
	if (branchmiss)
		;
	else if (ihito || |pc0[11:0])
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
    		if (!pt2) begin
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
    		if (!pt1) begin
    			if (rob[tail1].v==INV)
	    			qd = qd | 4'b0001;
	    	end
	    	else
	    		qs = qs | 4'b0001;
    	end
    4'b0110:
    	if (rob[tail0].v==INV) begin
    		qd = qd | 4'b0100;
    		if (!pt1) begin
    			if (rob[tail1].v==INV)
    				qd = qd | 4'b0010;
    		end
    		else
	    		qs = qs | 4'b0010;
    	end
    4'b0111:
    	if (rob[tail0].v==INV) begin
    		qd = qd | 4'b0100;
    		if (!pt1) begin
	    		if (rob[tail1].v==INV) begin
	    			qd = qd  | 4'b0010;
	    			if (!pt2) begin
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
    		if (!pt0) begin
    			if (rob[tail1].v==INV)
	    			qd = qd | 4'b0001;
	    	end
	    	else
	    		qs = qs | 4'b0001;
    	end
    4'b1010:
    	if (rob[tail0].v==INV) begin
    		qd = qd | 4'b1000;
    		if (!pt0) begin
    			if (rob[tail1].v==INV)
	    			qd = qd | 4'b0010;
	    	end
	    	else
	    		qs = qs | 4'b0010;
    	end
    4'b1011:
    	if (rob[tail0].v==INV) begin
    		qd = qd | 4'b1000;
    		if (!pt0) begin
    			if (rob[tail1].v==INV) begin
	    			qd = qd | 4'b0010;
    				if (!pt2) begin
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
    		if (!pt0) begin
    			if (rob[tail1].v==INV)
	    			qd = qd | 4'b0100;
	    	end
	    	else
	    		qs = qs | 4'b0100;
    	end
    4'b1101:
    	if (rob[tail0].v==INV) begin
    		qd = qd | 4'b1000;
    		if (!pt0) begin
    			if (rob[tail1].v==INV) begin
		    		qd = qd | 4'b0100;
	    			if (!pt1) begin
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
    		if (!pt0) begin
    			if (rob[tail1].v==INV) begin
		    		qd = qd | 4'b0100;
	    			if (!pt1) begin
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
    		if (!pt0) begin
    			if (rob[tail1].v==INV) begin
	    			qd = qd | 4'b0100;
	    			if (!pt1) begin
	    				if (rob[tail2].v==INV) begin
			    			qd = qd | 4'b0010;
		    				if (!pt2) begin
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
	cqd <= 4'd0;
else begin
	cqd <= next_cqd;
	if (next_cqd == 4'b1111)
		cqd <= 'd0;
end

wire pe_allqd;
reg allqd;
edge_det ued1 (.rst(rst), .clk(clk), .ce(1'b1), .i(next_cqd==4'b1111), .pe(pe_alldq), .ne(), .ee());

always_comb
	fetch_new = (ihito & ~hirq & (pe_allqd|allqd) & ~(|pc0[11:0]) & ~branchmiss) |
							(|pc0[11:0] & ~hirq & (pe_allqd|allqd) & ~branchmiss);

always_ff @(posedge clk)
if (rst) begin
	pc0 <= RSTPC;
	allqd <= 1'b1;
end
else begin
	if (pe_allqd & ~(ihito & ~hirq))
		allqd <= 1'b1;
	if (branchmiss) begin
		allqd <= 1'b0;
   	pc0 <= misspc;
  end
  else begin
		if (|pc0[11:0]) begin
		  if (~hirq) begin
		  	if (~|next_micro_ip)
		  		pc0 <= pc0 + 16'h5000;
	  		pc0[11:0] <= next_micro_ip;
			end
		end
		else if (ihito) begin
		  if (~hirq) begin
		  	if (pe_allqd|allqd) begin
			  	pc0 <= next_pc;
			  	allqd <= 1'b0;
			  end
			end
		end
	end
end

always_comb
if ((fnIsAtom(ins0) || fnIsAtom(ins1)) && irq_i != 3'd7)
	hirq = 'd0;
else
	hirq = (irq_i > im) && ~int_commit && (irq_i > atom_mask[2:0]);

// Extract instructions
always_comb
	ic_line = {ic_line_hi.data,ic_line_lo.data};
always_ff @(posedge clk)
	ins0 <= hirq ? {FN_IRQ,1'b0,vect_i,5'd0,2'd0,irq_i,OP_SYS} : ic_line >> {pc0[17:12],3'd0};
always_ff @(posedge clk)
	ins1 <= hirq ? {FN_IRQ,1'b0,vect_i,5'd0,2'd0,irq_i,OP_SYS} : ic_line >> {pc1[17:12],3'd0};
always_ff @(posedge clk)
	ins2 <= hirq ? {FN_IRQ,1'b0,vect_i,5'd0,2'd0,irq_i,OP_SYS} : ic_line >> {pc2[17:12],3'd0};
always_ff @(posedge clk)
	ins3 <= hirq ? {FN_IRQ,1'b0,vect_i,5'd0,2'd0,irq_i,OP_SYS} : ic_line >> {pc3[17:12],3'd0};
always_ff @(posedge clk)
	ins4 <= hirq ? {FN_IRQ,1'b0,vect_i,5'd0,2'd0,irq_i,OP_SYS} : ic_line >> {pc4[17:12],3'd0};
always_ff @(posedge clk)
	ins5 <= hirq ? {FN_IRQ,1'b0,vect_i,5'd0,2'd0,irq_i,OP_SYS} : ic_line >> {pc5[17:12],3'd0};
always_ff @(posedge clk)
	ins6 <= hirq ? {FN_IRQ,1'b0,vect_i,5'd0,2'd0,irq_i,OP_SYS} : ic_line >> {pc6[17:12],3'd0};

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

reg [1:0] dramN [0:NDATA_PORTS-1];
reg [79:0] dramN_sel [0:NDATA_PORTS-1];
tid_t [NDATA_PORTS-1:0] dramN_tid;
wire [NDATA_PORTS-1:0] dramN_store, dramN_load, dramN_loadz;
wire [NDATA_PORTS-1:0] dramN_erc = 2'b00;
address_t [NDATA_PORTS-1:0] dramN_vaddr, dramN_paddr;
value_t [NDATA_PORTS-1:0] dramN_data;
memsz_t [NDATA_PORTS-1:0] dramN_memsz;
reg [NDATA_PORTS-1:0] dramN_ack;

generate begin : gDcache
for (g = 0; g < NDATA_PORTS; g = g + 1) begin

	always_comb
	begin
		cpu_request_i[g].cid = CID + g + 1;
		cpu_request_i[g].tid = dramN_tid[g];
		cpu_request_i[g].om = fta_bus_pkg::MACHINE;
		cpu_request_i[g].cmd = dramN_store[g] ? fta_bus_pkg::CMD_STORE : dramN_loadz[g] ? fta_bus_pkg::CMD_LOADZ : dramN_load[g] ? fta_bus_pkg::CMD_LOAD : fta_bus_pkg::CMD_NONE;
		cpu_request_i[g].bte = fta_bus_pkg::LINEAR;
		cpu_request_i[g].cti = (dramN_erc[g] || ERC) ? fta_bus_pkg::ERC : fta_bus_pkg::CLASSIC;
		cpu_request_i[g].blen = 'd0;
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
		.ftam_full(ftadm_full),
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


//
// DECODE
//
decode_bus_t db0, db1, db2, db3;
decode_bus_t db0r, db1r, db2r, db3r;
instruction_t [3:0] instr [0:3];
pregno_t pRa0, pRa1, pRa2, pRa3;
pregno_t pRb0, pRb1, pRb2, pRb3;
pregno_t pRc0, pRc1, pRc2, pRc3;
pregno_t pRt0, pRt1, pRt2, pRt3;
pregno_t nRt0, nRt1, nRt2, nRt3;
pregno_t [3:0] tags2free;
wire [PREGS-1:0] avail_reg;						// available registers
wire [3:0] cndx;											// checkpoint index

assign instr[0][0] = ins0;
assign instr[0][1] = ins1;
assign instr[0][2] = ins2;
assign instr[0][3] = ins3;

assign instr[1][0] = ins1;
assign instr[1][1] = ins2;
assign instr[1][2] = ins3;
assign instr[1][3] = ins4;

assign instr[2][0] = ins2;
assign instr[2][1] = ins3;
assign instr[2][2] = ins4;
assign instr[2][3] = ins5;

assign instr[3][0] = ins3;
assign instr[3][1] = ins4;
assign instr[3][2] = ins5;
assign instr[3][3] = ins6;

Qupls_decoder udeci0
(
	.clk(clk),
	.instr(instr[0]),
	.dbo(db0)
);

Qupls_decoder udeci1
(
	.clk(clk),
	.instr(instr[1]),
	.dbo(db1)
);

Qupls_decoder udeci2
(
	.clk(clk),
	.instr(instr[2]),
	.dbo(db2)
);

Qupls_decoder udeci3
(
	.clk(clk),
	.instr(instr[3]),
	.dbo(db3)
);

//
// RENAME
//
aregno_t [15:0] arn;
pregno_t [15:0] prn;
wire [0:0] arnbank [15:0];

assign arn[0] = db0.Ra;
assign arn[1] = db0.Rb;
assign arn[2] = db0.Rc;
assign arn[3] = db0.Rt;

assign arn[4] = db1.Ra;
assign arn[5] = db1.Rb;
assign arn[6] = db1.Rc;
assign arn[7] = db1.Rt;

assign arn[8] = db2.Ra;
assign arn[9] = db2.Rb;
assign arn[10] = db2.Rc;
assign arn[11] = db2.Rt;

assign arn[12] = db3.Ra;
assign arn[13] = db3.Rb;
assign arn[14] = db3.Rc;
assign arn[15] = db3.Rt;

assign arnbank[0] = sr.om & {2{|db0.Ra}};
assign arnbank[1] = sr.om & {2{|db0.Rb}};
assign arnbank[2] = sr.om & {2{|db0.Rc}};
assign arnbank[3] = sr.om & {2{|db0.Rt}};
assign arnbank[4] = sr.om & {2{|db1.Ra}};
assign arnbank[5] = sr.om & {2{|db1.Rb}};
assign arnbank[6] = sr.om & {2{|db1.Rc}};
assign arnbank[7] = sr.om & {2{|db1.Rt}};
assign arnbank[8] = sr.om & {2{|db2.Ra}};
assign arnbank[9] = sr.om & {2{|db2.Rb}};
assign arnbank[10] = sr.om & {2{|db2.Rc}};
assign arnbank[11] = sr.om & {2{|db2.Rt}};
assign arnbank[12] = sr.om & {2{|db3.Ra}};
assign arnbank[13] = sr.om & {2{|db3.Rb}};
assign arnbank[14] = sr.om & {2{|db3.Rc}};
assign arnbank[15] = sr.om & {2{|db3.Rt}};


wire stallq;
wire nq = !branchmiss && rob[tail0].v==INV;

wire do_commit =
	((
		((rob[head0].v && rob[head0].done) || !rob[head0].v) &&
		((rob[head1].v && rob[head1].done) || !rob[head1].v) &&
		((rob[head2].v && rob[head2].done) || !rob[head2].v) &&
		((rob[head3].v && rob[head3].done) || !rob[head3].v)
		) && head0 != tail0 && head0 != tail1 && head0 != tail2 && head0 != tail3)
	;

wire cmtbr = (
	(rob[head0].br & rob[head0].v) ||
	(rob[head1].br & rob[head1].v) ||
	(rob[head2].br & rob[head2].v) ||
	(rob[head3].br & rob[head3].v)) && do_commit
	;

always_comb
begin
	int_commit = 1'b0;
	if (rob[head0].v && rob[head0].done && fnIsIrq(rob[head0].op))
		int_commit = 1'b1;
	else if (((rob[head0].v && rob[head0].done) || !rob[head0].v) &&
					(rob[head1].v && rob[head1].done && fnIsIrq(rob[head1].op)))
		int_commit = 1'b1;
	else if (((rob[head0].v && rob[head0].done) || !rob[head0].v) &&
					 ((rob[head1].v && rob[head1].done) || !rob[head1].v) &&
					(rob[head2].v && rob[head2].done && fnIsIrq(rob[head2].op)))
		int_commit = 1'b1;
	else if (((rob[head0].v && rob[head0].done) || !rob[head0].v) &&
					 ((rob[head1].v && rob[head1].done) || !rob[head1].v) &&
					 ((rob[head2].v && rob[head2].done) || !rob[head2].v) &&
					(rob[head3].v && rob[head3].done && fnIsIrq(rob[head3].op)))
		int_commit = 1'b1;
end

wire restore_chkpt = branchmiss;
pregno_t freea;
pregno_t freeb;
pregno_t freec;
pregno_t freed;

Qupls_reg_renamer utrn1
(
	.rst(rst),
	.clk(clk),
	.list2free(free_bitlist),
	.tags2free(tags2free),
	.freevals(4'hF),
	.alloc0(|db0.Rt),
	.alloc1(|db1.Rt),
	.alloc2(|db2.Rt),
	.alloc3(|db3.Rt),
	.wo0(nRt0),
	.wo1(nRt1),
	.wo2(nRt2),
	.wo3(nRt3),
	.avail(avail_reg)
);

Qupls_rat urat1
(	
	.rst(rst),
	.clk(clk),
	.nq(nq),
	.stallq(stallq),
	.cndx_o(cndx),
	.avail(),
	.restore(restore_chkpt),
	.miss_cp(),
	.wr0(|db0r.Rt),
	.wr1(|db1r.Rt),
	.wr2(|db2r.Rt),
	.wr3(|db3r.Rt),
	.qbr0(pt0),
	.qbr1(pt1),
	.qbr2(pt2),
	.qbr3(pt3),
	.rnbank(arnbank),
	.rn(arn),
	.rrn(prn),
	.vn(),
	.wrbanka(sr.om & {2{|db0r.Rt[5:3]}}),
	.wrbankb(sr.om & {2{|db1r.Rt[5:3]}}),
	.wrbankc(sr.om & {2{|db2r.Rt[5:3]}}),
	.wrbankd(sr.om & {2{|db3r.Rt[5:3]}}),
	.wra(db0r.Rt),
	.wrra(nRt0),
	.wrb(db1r.Rt),
	.wrrb(nRt1),
	.wrc(db2r.Rt),
	.wrrc(nRt2),
	.wrd(db3r.Rt),
	.wrrd(nRt3),
	.cmtbanka(rob[head0].om & {2{|rob[head0].decbus.Rt[5:3]}}),
	.cmtbankb(rob[head1].om & {2{|rob[head1].decbus.Rt[5:3]}}),
	.cmtbankc(rob[head2].om & {2{|rob[head2].decbus.Rt[5:3]}}),
	.cmtbankd(rob[head3].om & {2{|rob[head3].decbus.Rt[5:3]}}),
	.cmtav(do_commit & rob[head0].v),
	.cmtbv(do_commit & rob[head1].v),
	.cmtcv(do_commit & rob[head2].v),
	.cmtdv(do_commit & rob[head3].v),
	.cmtaa(rob[head0].decbus.Rt),
	.cmtba(rob[head1].decbus.Rt),
	.cmtca(rob[head2].decbus.Rt),
	.cmtda(rob[head3].decbus.Rt),
	.cmtap(rob[head0].nRt),
	.cmtbp(rob[head1].nRt),
	.cmtcp(rob[head2].nRt),
	.cmtdp(rob[head3].nRt),
	.cmtbr(cmtbr),
	.freea(freea),
	.freeb(freeb),
	.freec(freec),
	.freed(freed),
	.free_bitlist(free_bitlist)
);

always_ff @(posedge clk)
	db0r <= db0;
always_ff @(posedge clk)
	db1r <= db1;
always_ff @(posedge clk)
	db2r <= db2;
always_ff @(posedge clk)
	db3r <= db3;

always_ff @(posedge clk)
	pc0r <= pc0d;
always_ff @(posedge clk)
	pc1r <= pc1d;
always_ff @(posedge clk)
	pc2r <= pc2d;
always_ff @(posedge clk)
	pc3r <= pc3d;
	
reg wrport0_v;
reg wrport1_v;
reg wrport2_v;
reg wrport3_v;
reg wrport4_v;
value_t wrport0_res;
value_t wrport1_res;
value_t wrport2_res;
value_t wrport3_res;
value_t wrport4_res;
pregno_t wrport0_Rt;
pregno_t wrport1_Rt;
pregno_t wrport2_Rt;
pregno_t wrport3_Rt;
pregno_t wrport4_Rt;

assign wrport0_v = alu0_v;
assign wrport1_v = alu1_v;
assign wrport2_v = dram_v0;
assign wrport3_v = fpu_v;
assign wrport0_Rt = alu0_Rt;
assign wrport1_Rt = alu1_Rt;
assign wrport2_Rt = dram0_Rt;
assign wrport3_Rt = fpu_Rt;
assign wrport0_res = alu0_res;
assign wrport1_res = alu1_res;
assign wrport2_res = dram_bus0;
assign wrport3_res = fpu_res;
//assign wrport4_res = dram1_res;

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
	.wa0(wrport0_Rt),
	.wa1(wrport1_Rt),
	.wa2(wrport2_Rt),
	.wa3(wrport3_Rt),
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
always_comb
for (n4 = 0; n4 < ROB_ENTRIES; n4 = n4 + 1) begin
		robentry_stomp[n4] =
			branchmiss
			&& rob[n4].sn > rob[missid].sn
			&& rob[n4].v
		;
end											

rob_ndx_t stail;	// stomp tail
always_comb
begin
	n7 = 'd0;
	stail = 'd0;
	for (n5 = 0; n5 < ROB_ENTRIES; n5 = n5 + 1) begin
		n6 = (n5 - 1) % ROB_ENTRIES;
		if (robentry_stomp[n5] && !robentry_stomp[n6] && !n7) begin
			stail = n5;
			n7 = 1'b1;
		end
	end
end

pc_address_t tgtpc;

always_comb
	case(fcu_bts)
	BTS_REG:
		tgtpc = fcu_argC;
	BTS_DISP:
		begin
			tgtpc = fcu_pc + {{{47{fcu_instr[39]}},fcu_instr[39:25],fcu_instr[12:11],2'b0} +
											  {{47{fcu_instr[39]}},fcu_instr[39:25],fcu_instr[12:11]},12'h000};
			tgtpc[11:0] = 'd0;
		end
	BTS_BSR:
		begin
			tgtpc = fcu_pc + {{33{fcu_instr[39]}},fcu_instr[39:9],12'h000};
			tgtpc[11:0] = 'd0;
		end
	BTS_CALL:
		begin
			tgtpc = fcu_argA + {fcu_argI,12'h000};
			tgtpc[11:0] = 'd0;
		end
	BTS_RTI:
		tgtpc = fcu_instr[8:7]==2'd1 ? pc_stack[1] : pc_stack[0];
	BTS_RET:
		begin
			tgtpc = fcu_argC + {fcu_instr[18:11],12'h000};
			tgtpc[11:0] = 'd0;
		end
	default:
		tgtpc = RSTPC;
	endcase

pc_address_t tpc;
always_comb
	tpc = fcu_pc + 16'h5000;

modFcuMissPC umisspc1
(
	.instr(fcu_instr),
	.bts(fcu_bts),
	.pc(fcu_pc),
	.pc_stack(pc_stack),
	.bt(fcu_bt),
	.argA(fcu_argA),
	.argC(fcu_argC),
	.argI(fcu_argI),
	.misspc(fcu_misspc)
);

always_comb
	fcu_missir <= fcu_instr;


Qupls_branch_eval ube1
(
	.instr(fcu_instr),
	.a(fcu_argA),
	.b(fcu_argB),
	.takb(takb)
);

always_comb
	case(fcu_bts)
	BTS_RET:
		fcu_res = fcu_argA + {fcu_argI,3'd0};
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

always_comb
if (fcu_dataready) begin
	case(fcu_bts)
	BTS_REG,BTS_DISP:
		fcu_branchmiss = TRUE;//((takb && ~fcu_bt) || (!takb && fcu_bt));
	BTS_BSR,BTS_CALL,BTS_RET:
		fcu_branchmiss = TRUE;//((takb && ~fcu_bt) || (!takb && fcu_bt));
	default:
		fcu_branchmiss = FALSE;		
	endcase
end
else begin
	fcu_branchmiss = FALSE;
end

// Registering the branch miss signals may allow a second miss directly after
// the first one to occur. We want to process only the first miss. Three in
// a row cannot happen as the stomp signal is active by then.
always_comb
	branchmiss_next = (excmiss | fcu_branchmiss);// & ~branchmiss;
always_comb	//ff @(posedge clk)
	branchmiss = branchmiss_next;
always_comb
	missid = excmiss ? excid : fcu_sourceid;
always_ff @(posedge clk)
	if (branchmiss_state==3'd1)
		misspc = excmiss ? excmisspc : fcu_misspc;
always_ff @(posedge clk)
	if (branchmiss_state==3'd1)
		missir = excmiss ? excir : fcu_missir;
always_ff @(posedge clk)
	if (branchmiss_state==3'd1)
		missid = excmiss ? excid : fcu_sourceid;

//
// additional logic for ISSUE
//
// for the moment, we look at ALU-input buffers to allow back-to-back issue of 
// dependent instructions ... we do not, however, look ahead for DRAM requests 
// that will become valid in the next cycle.  instead, these have to propagate
// their results into the IQ entry directly, at which point it becomes issue-able
//

// note that, for all intents & purposes, iqentry_done == iqentry_agen ... no need to duplicate

rob_bitmask_t args_valid;
rob_bitmask_t could_issue;

generate begin : issue_logic
for (g = 0; g < ROB_ENTRIES; g = g + 1) begin
	assign args_valid[g] = (rob[g].argA_v
						// Or forwarded
						/*
				    || (rob[g].decbus.Ra == alu0_Rt && alu0_v)
				    || (rob[g].decbus.Ra == alu1_Rt && alu1_v)
				    || (rob[g].decbus.Ra == fpu0_Rt && fpu0_v)
				    || (rob[g].decbus.Ra == fcu_Rt && fcu_v)
				    || (rob[g].decbus.Ra == load_Rt && load_v)
				    */
				    )
				    && (rob[g].argB_v
						// Or forwarded
						/*
				    || (rob[g].decbus.Rb == alu0_Rt && alu0_v)
				    || (rob[g].decbus.Rb == alu1_Rt && alu1_v)
				    || (rob[g].decbus.Rb == fpu0_Rt && fpu0_v)
				    || (rob[g].decbus.Rb == fcu_Rt && fcu_v)
				    || (rob[g].decbus.Rb == load_Rt && load_v)
				    */
				    )
				    && (rob[g].argC_v)
						// Or forwarded
						/*
				    || (rob[g].decbus.Rc == alu0_Rt && alu0_v)
				    || (rob[g].decbus.Rc == alu1_Rt && alu1_v)
				    || (rob[g].decbus.Rc == fpu0_Rt && fpu0_v)
				    || (rob[g].decbus.Rc == fcu_Rt && fcu_v)
				    || (rob[g].decbus.Rc == load_Rt && load_v)
				    */
				    //|| ((rob[g].decbus.load|rob[g].decbus.store) & ~rob[g].agen))
				    ;
assign could_issue[g] = rob[g].v && !rob[g].done 
												&& !rob[g].out
												&& args_valid[g]
												;
                        //&& ((rob[g].decbus.load|rob[g].decbus.store) ? !rob[g].agen : 1'b1);
end                                 
end
endgenerate

rob_ndx_t alu0_rndx;
rob_ndx_t alu1_rndx;
rob_ndx_t fpu0_rndx; 
rob_ndx_t fcu_rndx;
lsq_ndx_t mem0_lsndx, mem1_lsndx;
lsq_ndx_t mem0_lsndx2, mem1_lsndx2;
rob_ndx_t lsq0_rndx, lsq1_rndx;
wire mem0_lsndxv, mem1_lsndxv;
reg mem0_lsndxv2, mem1_lsndxv2;
wire lsq0_rndxv, lsq1_rndxv;
wire fpu0_rndxv, fcu_rndxv;
wire alu0_rndxv, alu1_rndxv;
wire agen0_rndxv, agen1_rndxv;

Qupls_sched uscd1
(
	.alu0_idle(alu0_idle),
	.alu1_idle(alu1_idle),
	.fpu0_idle(fpu0_idle),
	.fpu1_idle(1'b0),
	.fcu_idle(fcu_idle),
	.agen0_idle(agen0_idle),
	.agen1_idle(agen1_idle),
	.robentry_islot(robentry_islot),
	.could_issue(could_issue), 
	.head(head0),
	.rob(rob),
	.robentry_issue(),
	.robentry_fpu_issue(),
	.robentry_fcu_issue(),
	.robentry_agen_issue(),
	.robentry_lsq_issue(),
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
	.lsq0_rndx(lsq0_rndx),
	.lsq1_rndx(lsq1_rndx),
	.lsq0_rndxv(lsq0_rndxv),
	.lsq1_rndxv(lsq1_rndxv)
);

Qupls_mem_sched umems1
(
	.rst(rst),
	.clk(clk),
	.head(head),
	.robentry_stomp(robentry_stomp),
	.rob(rob),
	.lsq(lsq),
	.robentry_memissue(),
	.ndx0(mem0_lsndx),
	.ndx1(mem1_lsndx),
	.ndx0v(mem0_lsndxv),
	.ndx1v(mem1_lsndxv)
);

always_ff @(posedge clk)
	mem0_lsndx2 <= mem0_lsndx;
always_ff @(posedge clk)
	mem1_lsndx2 <= mem1_lsndx;
always_ff @(posedge clk)
	mem0_lsndxv2 <= mem0_lsndxv;
always_ff @(posedge clk)
	mem1_lsndxv2 <= mem1_lsndxv;

assign alu0_argA_reg = rob[alu0_rndx].decbus.Ra;
assign alu0_argB_reg = rob[alu0_rndx].decbus.Rb;
assign alu0_argC_reg = rob[alu0_rndx].decbus.Rc;

assign alu1_argA_reg = rob[alu1_rndx].decbus.Ra;
assign alu1_argB_reg = rob[alu1_rndx].decbus.Rb;
assign alu1_argC_reg = rob[alu1_rndx].decbus.Rc;

assign fpu_argA_reg = rob[fpu0_rndx].decbus.Ra;
assign fpu_argB_reg = rob[fpu0_rndx].decbus.Rb;
assign fpu_argC_reg = rob[fpu0_rndx].decbus.Rc;

assign fcu_argA_reg = rob[fcu_rndx].decbus.Ra;
assign fcu_argB_reg = rob[fcu_rndx].decbus.Rb;

assign agen0_argA_reg = rob[agen0_rndx].decbus.Ra;
assign agen0_argB_reg = rob[agen0_rndx].decbus.Rb;

assign agen1_argA_reg = rob[agen1_rndx].decbus.Ra;
assign agen1_argB_reg = rob[agen1_rndx].decbus.Rb;

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
		.csr('d0),
		.o(alu1_res),
		.mul_done(mul1_done),
		.div_done(),
		.div_dbz()
	);
end
end
endgenerate

    assign  alu0_v = alu0_dataready,
	    alu1_v = alu1_dataready;

    assign  alu0_id = alu0_rndx,
	    alu1_id = alu1_rndx;

    assign  fcu_v = fcu_dataready;
    assign  fcu_id = fcu_sourceid;

generate begin : gFpu
if (NFPU > 0) begin
	Qupls_fpu ufpu1
	(
		.rst(rst),
		.clk(clk),
		.ir(fpu_instr),
		.rm('d0),
		.a(fpu_argA),
		.b(fpu_argB),
		.c(fpu_argC),
		.i(fpu_argI),
		.o(fpu_res),
		.done(fpu_done)
	);
end
end
endgenerate

assign fpu_v = fpu_dataready;
assign fpu_id = fpu0_rndx;

value_t agen0_res, agen1_res;
wire tlb_miss0, tlb_miss1;
wire tlb0_v, tlb1_v;
wire tlb_missack;
wire tlb_wr;
wire tlb_way;
tlb_entry_t tlb_entry0, tlb_entry1, tlb_entry;
wire [6:0] tlb_entryno;
instruction_t agen0_op, agen1_op;
reg agen0_load, agen1_load;
reg agen0_store, agen1_store;
wire tlb0_load, tlb0_store;
wire tlb1_load, tlb1_store;
reg stall_load, stall_store;
reg stall_tlb0, stall_tlb1;

always_comb
	stall_load = (tlb0_v & tlb0_load & loadq[lq_tail]==VAL) ||
							(tlb1_v & tlb1_load & loadq[lq_tail]==VAL)
							;
always_comb
	stall_store = (tlb0_v & tlb0_store & storeq[lq_tail]==VAL) ||
							(tlb1_v & tlb1_store & storeq[lq_tail]==VAL)
							;
always_comb
	stall_tlb0 = (tlb0_v & tlb0_load & loadq[lq_tail]==VAL) ||
							(tlb0_v & tlb0_store & storeq[lq_tail]==VAL)
							;
always_comb
	stall_tlb1 = (tlb1_v & tlb1_load & loadq[lq_tail]==VAL) ||
							(tlb1_v & tlb1_store & storeq[lq_tail]==VAL)
							;

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
	agen0_op <= rob[agen0_rndx].op;
always_ff @(posedge clk)
	agen1_op <= rob[agen1_rndx].op;
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

Qupls_agen uag0
(
	.clk(clk),
	.ir(rob[agen0_rndx].op),
	.a(rfo_agen0_argA),
	.b(rfo_agen0_argB),
	.i(rob[agen0_rndx].decbus.immb),
	.res(agen0_res)
);

Qupls_agen uag1
(
	.clk(clk),
	.ir(rob[agen1_rndx].op),
	.a(rfo_agen1_argA),
	.b(rfo_agen1_argB),
	.i(rob[agen1_rndx].decbus.immb),
	.res(agen1_res)
);

always_ff @(posedge clk) agen0_rndx1 <= agen0_rndx;
always_ff @(posedge clk) agen1_rndx1 <= agen1_rndx;
always_ff @(posedge clk) agen0_rndxv1 <= agen0_rndxv;
always_ff @(posedge clk) agen1_rndxv1 <= agen1_rndxv;

reg cantlsq0, cantlsq1;
always_comb
begin
	cantlsq0 = 1'b0;
	cantlsq1 = 1'b0;
	for (n6 = 0; n6 < ROB_ENTRIES; n6 = n6 + 1) begin
		if ((rob[n6].decbus.load | rob[n6].decbus.store) && rob[n6].sn < rob[agen0_rndx].sn && !rob[n6].lsq)
			cantlsq0 = 1'b1;
		if ((rob[n6].decbus.load | rob[n6].decbus.store) && rob[n6].sn < rob[agen1_rndx].sn && !rob[n6].lsq)
			cantlsq1 = 1'b1;
	end
end

wire tlb_miss;
virtual_address_t tlb_missadr;
asid_t tlb_missasid;

Qupls_tlb utlb1
(
	.rst(rst),
	.clk(clk),
	.ftas_req(),
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
	.agen0_rndx_i(agen0_rndx1),
	.agen1_rndx_i(agen1_rndx1),
	.agen0_rndx_o(agen0_rndx2),
	.agen1_rndx_o(agen1_rndx2),
	.load0_i(agen_load0),
	.load1_i(agen_load1),
	.store0_i(agen_store0),
	.store1_i(agen_store1),
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
	.missack(tlb_missack)
);

Qupls_ptable_walker uptw1
(
	.rst(rst),
	.clk(clk),
	.tlbmiss(tlb_miss),
	.tlb_missadr(tlb_missadr),
	.tlb_missasid(tlb_missasid),
	.in_que(tlb_missack),
	.ftas_req(),
	.ftas_resp(),
	.ftam_req(ftatm_req),
	.ftam_resp(ftatm_resp),
	.fault_o(),
	.tlb_wr(tlb_wr),
	.tlb_way(tlb_way),
	.tlb_entryno(tlb_entryno),
	.tlb_entry(tlb_entry)
);

reg [3:0] lsq_tail, lsq_tail0, lsq_tail1;
reg [3:0] lsq_head;
reg [3:0] lsq_heads [0:LSQ_ENTRIES];
always_comb
begin
	lsq_tail0 = lsq_tail;
	lsq_tail1 = lsq_tail + 1;
	lsq_heads[0] = lsq_head;
	for (n5 = 1; n5 < LSQ_ENTRIES; n5 = n5 + 1)
		lsq_heads[n5] = lsq_heads[n5-1];	
end

always_comb
begin
	alu0_done = 'd0;
	for (n7 = 0; n7 < ROB_ENTRIES; n7 = n7 + 1)
		if (robentry_issue2[n7] && robentry_islot[n7] == 2'd0 && !robentry_stomp[n7] &&
			(rob[n7].decbus.div|rob[n7].decbus.divu ? div0_done : 1'b1) && (rob[n7].decbus.mul|rob[n7].decbus.mulu ? mul0_done : 1'b1))
				alu0_done = 1'b1;
end

always_comb
begin
	alu1_done = 'd0;
	for (n8 = 0; n8 < ROB_ENTRIES; n8 = n8 + 1)
		if (robentry_issue2[n8] && robentry_islot[n8] == 2'd1 && !robentry_stomp[n8] &&
			(rob[n8].decbus.div|rob[n8].decbus.divu ? 1'b1 : 1'b1) && (rob[n8].decbus.mul|rob[n8].decbus.mulu ? mul1_done : 1'b1))
				alu1_done = 1'b1;
end

/*
always_comb
begin
	fpu_done = 'd0;
	for (n9 = 0; n9 < ROB_ENTRIES; n9 = n9 + 1)
		if (robentry_fpu_issue[n9] && !robentry_stomp[n9])
				fpu_done = 1'b1;
end
*/

always_comb
begin
	fcu_done = 'd0;
	for (n10 = 0; n10 < ROB_ENTRIES; n10 = n10 + 1)
		if (robentry_fcu_issue[n10] && !robentry_stomp[n10])
				fcu_done = 1'b1;
end

function integer fnLoadBypassIndex;
input lsq_ndx_t lsndx;
integer n15;
seqnum_t stsn;
begin
	fnLoadBypassIndex = -1;
	stsn = 8'hFF;
	for (n15 = 0; n15 < LSQ_ENTRIES; n15 = n15 + 1) begin
		if (
			(lsq[lsndx].memsz==lsq[n15].memsz) &&		// memory size matches
			(lsq[lsndx].load && lsq[n15].store) &&	// and trying to load
			 lsq[lsndx].sn > lsq[n15].sn && lsq[n15].v && lsq[n15].datav &&
			 	stsn > lsq[n15].sn) begin
			 	stsn = lsq[n15].sn;
			 	fnLoadBypassIndex = n15;
			end
	end
end
endfunction

integer lbndx0, lbndx1;
always_comb	lbndx0 = fnLoadBypassIndex(mem0_lsndx);
always_comb lbndx1 = fnLoadBypassIndex(mem1_lsndx);

always_ff @(posedge clk)
if (rst) begin
	tReset();
end
else begin
//
// DATAINCOMING
//
// wait for operand/s to appear on alu busses and puts them into 
// the iqentry_a1 and iqentry_a2 slots (if appropriate)
// as well as the appropriate iqentry_res slots (and setting valid bits)
//
	//
	// put results into the appropriate instruction entries
	//
	if (alu0_v && rob[alu0_rndx].v && rob[alu0_rndx].owner==QuplsPkg::ALU0) begin
    rob[ alu0_rndx ].exc <= alu0_exc;
    rob[ alu0_rndx ].done <= !rob[ alu0_rndx ].decbus.multicycle;
    rob[ alu0_rndx ].out <= INV;
   	robentry_issue_reg[alu0_rndx] <= 1'b0;
    if ((rob[ alu0_rndx].decbus.mul || rob[ alu0_rndx].decbus.mulu) && mul0_done) begin
	    rob[ alu0_rndx ].done <= VAL;
	    rob[ alu0_rndx ].out <= INV;
  	end
    if ((rob[ alu0_rndx].decbus.div || rob[ alu0_rndx].decbus.divu) && div0_done) begin
	    rob[ alu0_rndx ].done <= VAL;
	    rob[ alu0_rndx ].out <= INV;
  	end
	end
	if (NALU > 1 && alu1_v && rob[alu1_rndx].v && rob[alu1_rndx].owner==QuplsPkg::ALU1) begin
    rob[ alu1_rndx ].exc <= alu1_exc;
    rob[ alu1_rndx ].done <= (!rob[ alu1_rndx ].decbus.load && !rob[ alu1_rndx ].decbus.store);
    rob[ alu1_rndx ].out <= INV;
	end
	if (NFPU > 0 && fpu_v && rob[fpu0_rndx].v && rob[fpu0_rndx].owner==QuplsPkg::FPU0) begin
    rob[ fpu0_rndx ].exc <= fpu_exc;
    rob[ fpu0_rndx ].done <= fpu_done;
    rob[ fpu0_rndx ].out <= INV;
	end
	if (fcu_v && rob[fcu_rndx].v && rob[fcu_rndx].out && rob[fcu_rndx].owner==QuplsPkg::FCU) begin
    rob[ fcu_rndx ].exc <= fcu_exc;
    rob[ fcu_rndx ].done <= VAL;
    rob[ fcu_rndx ].out <= INV;
    rob[ fcu_rndx ].takb <= takb;
    rob[ fcu_rndx ].brtgt <= tgtpc;
	end
	// If data for stomped instruction, ignore
	// dram_vn will be false for stomped data
	if (dram_v0 && rob[ dram_id0 ].v && (rob[ dram_id0 ].decbus.load||rob[ dram_id0 ].decbus.store) && rob[dram0_id].owner==QuplsPkg::DRAM0) begin
    rob[ dram_id0 ].exc <= dram_exc0;
    rob[ dram_id0 ].out <= INV;
    rob[ dram_id0 ].done <= VAL;
	end
	if (NDATA_PORTS > 1) begin
		if (dram_v1 && rob[ dram_id1 ].v && (rob[ dram_id1 ].decbus.load||rob[ dram_id1 ].decbus.store) && rob[dram1_id].owner==QuplsPkg::DRAM1) begin
	    rob[ dram_id1 ].exc <= dram_exc1;
	    rob[ dram_id1 ].out <= INV;
	    rob[ dram_id1 ].done <= VAL;
		end
	end

	// Set the IQ entry = DONE as soon as the SW is let loose to the memory system
	// If the store is unaligned, setting .out to INV will cause a second bus cycle.
	if (dram0 == DRAMSLOT_ACTIVE && dram0_ack && dram0_store && !dram0_stomp) begin
    rob[ dram0_id[2:0] ].done <= !dram0_more || !SUPPORT_UNALIGNED_MEMORY;
    rob[ dram0_id[2:0] ].out <= INV;
	end
	if (NDATA_PORTS > 1) begin
		if (dram1 == DRAMSLOT_ACTIVE && dram1_ack && dram1_store && !dram1_stomp) begin
	    rob[ dram1_id[2:0] ].done <= !dram1_more || !SUPPORT_UNALIGNED_MEMORY;
	    rob[ dram1_id[2:0] ].out <= INV;
		end
	end
	
	// Validate arguments

	for (nn = 0; nn < ROB_ENTRIES; nn = nn + 1) begin

		if (rob[nn].argA_v == INV && rob[nn].pRa == wrport0_Rt && rob[nn].v == VAL && wrport0_v == VAL)
	    rob[nn].argA_v <= VAL;
		if (rob[nn].argB_v == INV && rob[nn].pRb == wrport0_Rt && rob[nn].v == VAL && wrport0_v == VAL)
	    rob[nn].argB_v <= VAL;
		if (rob[nn].argC_v == INV && rob[nn].pRc == wrport0_Rt && rob[nn].v == VAL && wrport0_v == VAL)
	    rob[nn].argC_v <= VAL;

		if (NALU > 1) begin
			if (rob[nn].argA_v == INV && rob[nn].pRa == wrport1_Rt && rob[nn].v == VAL && wrport1_v == VAL)
		    rob[nn].argA_v <= VAL;
			if (rob[nn].argB_v == INV && rob[nn].pRb == wrport1_Rt && rob[nn].v == VAL && wrport1_v == VAL)
		    rob[nn].argB_v <= VAL;
			if (rob[nn].argC_v == INV && rob[nn].pRc == wrport1_Rt && rob[nn].v == VAL && wrport1_v == VAL)
		    rob[nn].argC_v <= VAL;
		end

		if (rob[nn].argA_v == INV && rob[nn].pRa == wrport2_Rt && rob[nn].v == VAL && wrport2_v == VAL)
	    rob[nn].argA_v <= VAL;
		if (rob[nn].argB_v == INV && rob[nn].pRb == wrport2_Rt && rob[nn].v == VAL && wrport2_v == VAL)
	    rob[nn].argB_v <= VAL;
		if (rob[nn].argC_v == INV && rob[nn].pRc == wrport2_Rt && rob[nn].v == VAL && wrport2_v == VAL)
	    rob[nn].argC_v <= VAL;

		if (rob[nn].argA_v == INV && rob[nn].pRa == wrport3_Rt && rob[nn].v == VAL && wrport3_v == VAL)
	    rob[nn].argA_v <= VAL;
		if (rob[nn].argB_v == INV && rob[nn].pRb == wrport3_Rt && rob[nn].v == VAL && wrport3_v == VAL)
	    rob[nn].argB_v <= VAL;
		if (rob[nn].argC_v == INV && rob[nn].pRc == wrport3_Rt && rob[nn].v == VAL && wrport3_v == VAL)
	    rob[nn].argC_v <= VAL;
	end

//
// ISSUE 
//
// determines what instructions are ready to go, then places them
// in the various ALU queues.  
// also invalidates instructions following a branch-miss BEQ or any JALR (STOMP logic)
//

	alu0_dataready <= alu0_available && alu0_done;
	alu1_dataready <= alu1_available && alu1_done && NALU > 1;
	fpu_dataready <= fpu_available && NFPU > 0 && fpu_done;
	fcu_dataready <= fcu_available && fcu_done;

	// Reservation stations

	if (alu0_available && alu0_rndxv) begin
		alu0_argA <= rob[alu0_rndx].decbus.imma | rfo_alu0_argA;
		alu0_argB <= rfo_alu0_argB;
		alu0_argC <= rob[alu0_rndx].decbus.immc | rfo_alu0_argC;
		alu0_argI	<= rob[alu0_rndx].decbus.immb;
		alu0_Rt <= rob[alu0_rndx].decbus.Rt;
		alu0_ld <= 1'b1;
		alu0_instr <= rob[alu0_rndx].op;
		alu0_div <= rob[alu0_rndx].decbus.div;
		alu0_pc <= rob[alu0_rndx].pc;
		rob[alu0_rndx].arg <= rob[alu0_rndx].decbus.immc | rfo_alu0_argC;
    rob[alu0_rndx].out <= VAL;
    rob[alu0_rndx].owner <= QuplsPkg::ALU0;
	end

	if (NALU > 1) begin
		if (alu1_available && alu1_rndxv) begin
			alu1_argA <= rob[alu1_rndx].decbus.imma | rfo_alu1_argA;
			alu1_argB <= rfo_alu1_argB;
			alu1_argI	<= rob[alu1_rndx].decbus.immb;
			alu1_Rt <= rob[alu1_rndx].decbus.Rt;
			alu1_ld <= 1'b1;
			alu1_instr <= rob[alu1_rndx].op;
			alu1_div <= rob[alu1_rndx].decbus.div;
			alu1_pc <= rob[alu1_rndx].pc;
	    rob[alu1_rndx].out <= VAL;
	    rob[alu1_rndx].owner <= QuplsPkg::ALU1;
		end
	end

	if (fpu_available && fpu0_rndxv) begin
		fpu_argA <= rob[fpu0_rndx].decbus.imma | rfo_fpu0_argA;
		fpu_argB <= rfo_fpu0_argB;
		fpu_argC <= rob[fpu0_rndx].decbus.immc | rfo_fpu0_argC;
		fpu_argI	<= rob[fpu0_rndx].decbus.immb;
		fpu_Rt <= rob[fpu0_rndx].decbus.Rt;
		fpu_instr <= rob[fpu0_rndx].op;
		fpu_pc <= rob[fpu0_rndx].pc;
    rob[fpu0_rndx].out <= VAL;
    rob[fpu0_rndx].owner <= QuplsPkg::FPU0;
	end

	if (fcu_rndxv) begin
		fcu_argA <= rob[fcu_rndx].decbus.imma | rfo_fcu_argA;
		fcu_argB <= rfo_fcu_argB;
		fcu_argI <= rob[fcu_rndx].decbus.immb;
		fcu_pc <= rob[fcu_rndx].pc;
	  rob[fcu_rndx].out <= VAL;
	  rob[fcu_rndx].owner <= QuplsPkg::FCU;
	end

	if (agen0_rndxv) begin
		agen0_argA <= rob[agen0_rndx].decbus.imma | rfo_agen0_argA;
		agen0_argB <= rfo_agen0_argB;
		agen0_argI <= rob[agen0_rndx].decbus.immb;
		agen0_pc <= rob[agen0_rndx].pc;
	  rob[agen0_rndx].out <= VAL;
	  rob[agen0_rndx].owner <= QuplsPkg::AGEN0;
	end

	if (NAGEN > 1 && agen1_rndxv) begin
		agen1_argA <= rob[agen1_rndx].decbus.imma | rfo_agen1_argA;
		agen1_argB <= rfo_agen1_argB;
		agen1_argI <= rob[agen1_rndx].decbus.immb;
		agen1_pc <= rob[agen1_rndx].pc;
    rob[agen1_rndx].out <= VAL;
    rob[agen1_rndx].owner <= QuplsPkg::AGEN1;
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
// ENQUE
//
//
// MEMORY
//
// update the memory queues and put data out on bus if appropriate
//

	//
	// dram0, dram1, dram2 are the "state machines" that keep track
	// of three pipelined DRAM requests.  if any has the value "00", 
	// then it can accept a request (which bumps it up to the value "01"
	// at the end of the cycle).  once it hits the value "11" the request
	// is finished and the dram_bus takes the value.  if it is a store, the 
	// dram_bus value is not used, but the dram_v value along with the
	// dram_id value signals the waiting memq entry that the store is
	// completed and the instruction can commit.
	//

	if (rst)
		dram0 <= DRAMSLOT_AVAIL;
	else
		case(dram0)
		DRAMSLOT_AVAIL:	;
		DRAMSLOT_READY:
			begin
				dram0 <= dram0 + 2'd1;
				if (|dram0_sel[79:64]) begin
					dram0_more <= SUPPORT_UNALIGNED_MEMORY;
				end
			end
		DRAMSLOT_ACTIVE:
			begin
				if (dram0_ack)
					dram0 <= DRAMSLOT_AVAIL;
				dram0_tocnt <= dram0_tocnt + 2'd1;
			end
		default:	;
		endcase

	if (NDATA_PORTS > 1) begin
		if (rst)
			dram1 <= DRAMSLOT_AVAIL;
		else
			case(dram1)
			DRAMSLOT_AVAIL:	;
			DRAMSLOT_READY:
				begin
					dram1 <= dram1 + 2'd1;
					if (|dram1_sel[79:64]) begin
						dram1_more <= SUPPORT_UNALIGNED_MEMORY;
					end
				end
			DRAMSLOT_ACTIVE:
				begin
					if (dram1_ack)
						dram1 <= DRAMSLOT_AVAIL;
					dram1_tocnt <= dram1_tocnt + 2'd1;
				end
			default:	;
			endcase
	end
	
	// Bus timeout logic
	// Reset out to trigger another access
	if (SUPPORT_BUS_TO) begin
		if (dram0_tocnt[10]) begin
			if (~|rob[dram0_id].exc)
				rob[dram0_id].exc <= FLT_BERR;
			rob[dram0_id].done <= VAL;
			rob[dram0_id].out <= INV;
			lsq[rob[dram0_id].lsqndx].v <= INV;
			dram0 <= DRAMSLOT_AVAIL;
			dram0_tocnt <= 'd0;
		end
		else if (dram0_tocnt[8]) begin
			dram0 <= DRAMSLOT_AVAIL;
			rob[dram0_id].out <= INV;
		end
		if (NDATA_PORTS > 1) begin
			if (dram1_tocnt[10]) begin
				if (~|rob[dram1_id].exc)
					rob[dram1_id].exc <= FLT_BERR;
				rob[dram1_id].done <= VAL;
				rob[dram1_id].out <= INV;
				lsq[rob[dram1_id].lsqndx].v <= INV;
				dram1 <= DRAMSLOT_AVAIL;
				dram1_tocnt <= 'd0;
			end
			else if (dram1_tocnt[8]) begin
				dram1 <= DRAMSLOT_AVAIL;
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
    	dram0_store <= 'd0;
    	dram0_sel <= 'd0;
  	end
    if (dram0_store)
    	$display("m[%h] <- %h", dram0_addr, dram0_data);
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
    	dram0_store <= 'd0;
    	dram0_sel <= 'd0;
  	end
    if (dram0_store)
    	$display("m[%h] <- %h", dram0_addr, dram0_data);
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
	    	dram1_sel <= 'd0;
	  	end
	    if (dram1_store)
	     	$display("m[%h] <- %h", dram1_addr, dram1_data);
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
	    	dram1_sel <= 'd0;
	  	end
	    if (dram1_store)
	     	$display("m[%h] <- %h", dram1_addr, dram1_data);
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
		dram_bus0 <= fnDati(1'b0,dram0_op,lsq[lbndx0].res);
		dram_Rt0 <= lsq[lbndx0].Rt;
		dram_v0 <= lsq[lbndx0].v;
		lsq[lbndx0].v <= INV;
		rob[lsq[lbndx0].rndx].done <= 1'b1;
	end
  else if (dram0 == DRAMSLOT_AVAIL && mem0_lsndxv) begin
		dram0 <= DRAMSLOT_READY;
		dram0_exc <= FLT_NONE;
		dram0_stomp <= 1'b0;
		dram0_id <= lsq[mem0_lsndx].rndx;
		dram0_op <= lsq[mem0_lsndx].op;
		dram0_load <= lsq[mem0_lsndx].load;
		dram0_loadz <= lsq[mem0_lsndx].loadz;
		dram0_store <= lsq[mem0_lsndx].store;
		dram0_erc <= rob[lsq[mem0_lsndx].rndx].decbus.erc;
		dram0_Rt	<= lsq[mem0_lsndx].Rt;
		if (dram0_more && SUPPORT_UNALIGNED_MEMORY) begin
			dram0_hi <= 1'b1;
			dram0_sel <= dram0_sel >> 8'd64;
			dram0_vaddr <= {lsq[mem0_lsndx].vadr[$bits(virtual_address_t)-1:6] + 2'd1,6'h0};
			dram0_paddr <= {lsq[mem0_lsndx].padr[$bits(physical_address_t)-1:6] + 2'd1,6'h0};
			dram0_data <= dram0_data >> 12'd512;
			dram0_shift <= {7'd64-lsq[mem0_lsndx].padr[5:0],3'b0};
		end
		else begin
			dram0_hi <= 1'b0;
			dram0_sel <= {64'h0,fnSel(rob[lsq[mem0_lsndx].rndx].op)} << lsq[mem0_lsndx].padr[5:0];
			dram0_vaddr <= lsq[mem0_lsndx].vadr;
			dram0_paddr <= lsq[mem0_lsndx].padr;
			dram0_data <= {448'h0,rfo_store_argC} << {lsq[mem0_lsndx].padr[5:0],3'b0};
			dram0_shift <= {lsq[mem0_lsndx].padr[5:0],3'd0};
		end
		dram0_memsz <= fnMemsz(rob[lsq[mem0_lsndx].rndx].op);
		dram0_tid[2:0] <= dram0_tid[2:0] + 2'd1;
		dram0_tid[7:3] <= {4'h1,1'b0};
		rob[lsq[mem0_lsndx].rndx].out <= VAL;
		rob[lsq[mem0_lsndx].rndx].owner <= QuplsPkg::DRAM0;
    dram0_tocnt <= 'd0;
  end
  if (NDATA_PORTS > 1) begin
		if (SUPPORT_LOAD_BYPASSING && lbndx1 > 0) begin
			dram_bus1 <= fnDati(1'b0,dram1_op,lsq[lbndx1].res);
			dram_Rt1 <= lsq[lbndx1].Rt;
			dram_v1 <= lsq[lbndx1].v;
			lsq[lbndx1].v <= INV;
			rob[lsq[lbndx1].rndx].done <= 1'b1;
		end
	  else if (dram1 == DRAMSLOT_AVAIL && NDATA_PORTS > 1 && mem1_lsndxv) begin
			dram1 <= DRAMSLOT_READY;
			dram1_exc <= FLT_NONE;
			dram1_stomp <= 1'b0;
			dram1_id <= lsq[mem1_lsndx].rndx;
			dram1_op <= lsq[mem1_lsndx].op;
			dram1_load <= lsq[mem1_lsndx].load;
			dram1_loadz <= lsq[mem1_lsndx].loadz;
			dram1_store <= lsq[mem1_lsndx].store;
			dram1_erc <= rob[lsq[mem1_lsndx].rndx].decbus.erc;
			dram1_Rt <= lsq[mem1_lsndx].Rt;
			if (dram1_more && SUPPORT_UNALIGNED_MEMORY) begin
				dram1_hi <= 1'b1;
				dram1_sel <= dram1_sel >> 8'd64;
				dram1_vaddr <= {lsq[mem1_lsndx].vadr[$bits(virtual_address_t)-1:6] + 2'd1,6'h0};
				dram1_paddr <= {lsq[mem1_lsndx].padr[$bits(physical_address_t)-1:6] + 2'd1,6'h0};
				dram1_data <= dram1_data >> 12'd512;
				dram1_shift <= {7'd64-lsq[mem1_lsndx].padr[5:0],3'b0};
			end
			else begin
				dram1_hi <= 1'b0;
				dram1_sel <= {64'h0,fnSel(lsq[mem1_lsndx].op)} << lsq[mem1_lsndx].padr[5:0];
				dram1_vaddr	<= lsq[mem1_lsndx].vadr;
				dram1_paddr	<= lsq[mem1_lsndx].padr;
				dram1_data	<= {448'h0,rfo_store_argC} << {lsq[mem1_lsndx].padr[5:0],3'b0};
				dram1_shift <= {lsq[mem1_lsndx].padr[5:0],3'd0};
			end
			dram1_memsz <= fnMemsz(lsq[mem1_lsndx].op);
			dram1_tid[2:0] <= dram1_tid[2:0] + 2'd1;
			dram1_tid[7:3] <= {4'h2,1'b0};
			rob[lsq[mem1_lsndx].rndx].out	<= VAL;
			rob[lsq[mem1_lsndx].rndx].owner <= QuplsPkg::DRAM1;
	    dram1_tocnt <= 'd0;
	  end
	end
 
  for (n3 = 0; n3 < ROB_ENTRIES; n3 = n3 + 1) begin
		if (robentry_stomp[n3] && rob[n3].lsqndx==mem0_lsndx)
			dram0_stomp <= 1'b1;
		if (robentry_stomp[n3] && rob[n3].lsqndx==mem1_lsndx)
			dram1_stomp <= 1'b1;
	end

	if (branchmiss)
		tail0 <= stail;		// computed above
	else if (!stallq) begin
		if (rob[tail0].v==INV &&
			rob[tail1].v==INV && 
			rob[tail2].v==INV && 
			rob[tail3].v==INV) begin
			rob[tail0].v <= VAL;
			rob[tail1].v <= VAL;
			rob[tail2].v <= VAL;
			rob[tail3].v <= VAL;
			for (n12 = 0; n12 < ROB_ENTRIES; n12 = n12 + 1)
				rob[n12].sn <= rob[n12].sn - 4;
			tEnque(8'hFC,db0r,pc0r,ins0,pt0,tail0, 1'b0, prn[0], prn[1], prn[2], prn[3], nRt0, avail_reg & ~(192'd1 << nRt0), cndx);
			tEnque(8'hFD,db1r,pc1r,ins1,pt1,tail1, pt0, prn[4], prn[5], prn[6], prn[7], nRt1, avail_reg & ~((192'd1 << nRt0) | (192'd1 << nRt1)), cndx);
			tEnque(8'hFE,db2r,pc2r,ins2,pt2,tail2, pt0|pt1, prn[8], prn[9], prn[10], prn[11], nRt2, avail_reg & ~((192'd1 << nRt0) | (192'd1 << nRt1) | (192'd1 << nRt2)), cndx);
			tEnque(8'hFF,db3r,pc3r,ins3,pt3,tail3, pt0|pt1|pt2, prn[12], prn[13], prn[14], prn[15], nRt3, avail_reg & ~((192'd1 << nRt0) | (192'd1 << nRt1) | (192'd1 << nRt2)| (192'd1 << nRt3)), cndx);
			tail0 <= (tail0 + 3'd4) % ROB_ENTRIES;
		end
	end

	// Place up to two instructions into the load/store queue in order.	

	if (lsq[lsq_tail0].v==INV && lsq0_rndxv) begin	// Can an entry be queued?
		lsq[lsq_tail0].rndx <= lsq0_rndx;
		lsq[lsq_tail0].agen <= 1'b0;
		lsq[lsq_tail0].tlb <= 1'b0;
		lsq[lsq_tail0].op <= rob[lsq0_rndx].op;
		lsq[lsq_tail0].load <= rob[lsq0_rndx].decbus.load;
		lsq[lsq_tail0].loadz <= rob[lsq0_rndx].decbus.loadz;
		lsq[lsq_tail0].store <= rob[lsq0_rndx].decbus.store;
		store_argC_reg <= rob[lsq0_rndx].pRc;
		//store_tail <= lsq_tail0;
		lsq[lsq_tail0].Rc <= rob[lsq0_rndx].pRc;
		lsq[lsq_tail0].Rt <= rob[lsq0_rndx].pRt;
		lsq[lsq_tail0].memsz <= fnMemsz(rob[lsq0_rndx].op);
		for (n12 = 0; n12 < LSQ_ENTRIES; n12 = n12 + 1)
			lsq[n12].sn <= lsq[n12].sn - 1;
		lsq[lsq_tail].sn <= 8'hFF;
		lsq_tail <= (lsq_tail + 2'd1) % LSQ_ENTRIES;
		rob[lsq0_rndx].lsq <= 1'b1;
		rob[lsq0_rndx].lsqndx <= lsq_tail0;
		if (LSQ2 && lsq[lsq_tail1].v==INV && lsq1_rndxv) begin	// Can a second entry be queued?
			lsq[lsq_tail1].v <= VAL;
			lsq[lsq_tail1].rndx <= lsq1_rndx;
			lsq[lsq_tail1].agen <= 1'b0;
			lsq[lsq_tail1].tlb <= 1'b0;
			lsq[lsq_tail1].op <= rob[lsq1_rndx].op;
			lsq[lsq_tail1].load <= rob[lsq1_rndx].decbus.load;
			lsq[lsq_tail1].loadz <= rob[lsq1_rndx].decbus.loadz;
			lsq[lsq_tail1].store <= rob[lsq1_rndx].decbus.store;
			lsq[lsq_tail1].Rc <= rob[lsq1_rndx].pRc;
			lsq[lsq_tail1].Rt <= rob[lsq1_rndx].pRt;
			lsq[lsq_tail1].memsz <= fnMemsz(rob[lsq1_rndx].op);
			for (n12 = 0; n12 < LSQ_ENTRIES; n12 = n12 + 1)
				lsq[n12].sn <= lsq[n12].sn - 2;
			lsq[lsq_tail0].sn <= 8'hFE;
			lsq[lsq_tail1].sn <= 8'hFF;
			lsq_tail <= (lsq_tail + 2'd2) % LSQ_ENTRIES;
			rob[lsq1_rndx].lsq <= 1'b1;
			rob[lsq1_rndx].lsqndx <= lsq_tail1;
		end
	end
	if (lsq[store_tail].store && lsq[store_tail].v && !lsq[store_tail].datav) begin
		lsq[store_tail].res <= rfo_store_argC;
		if (rob[lsq[store_tail].rndx].argC_v)
			lsq[store_tail].datav <= VAL;
	end

	// Store TLB translation in LSQ
	if (mem0_lsndxv) lsq[mem0_lsndx].agen <= 1'b1;
	if (mem0_lsndxv2) lsq[mem0_lsndx2].tlb <= 1'b1;
	if (mem0_lsndxv2) lsq[mem0_lsndx2].vadr <= tlb0_res;
	if (mem0_lsndxv2) lsq[mem0_lsndx2].padr <= {tlb_entry0.pte.ppn,tlb0_res[15:0]};
	if (NAGEN > 1) begin
		if (mem1_lsndxv) lsq[mem1_lsndx].agen <= 1'b1;
		if (mem1_lsndxv2) lsq[mem1_lsndx2].tlb <= 1'b1;
		if (mem1_lsndxv2) lsq[mem1_lsndx2].vadr <= tlb1_res;
		if (mem1_lsndxv2) lsq[mem1_lsndx2].padr <= {tlb_entry1.pte.ppn,tlb1_res[15:0]};
	end

//
// COMMIT
//
// The head pointer is advance only once all four ROB entries have committed.
// Only one oddball instruction is allowed to commit.
//
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
		if (rob[head0].exc != FLT_NONE)
			tProcessExc(head0,rob[head0].pc);
		rob[head0].v <= INV;
		rob[head0].lsq <= 'd0;
		tags2free[0] <= rob[head0].pRt;
		head0 <= (head0 + 3'd1) % ROB_ENTRIES;
		I <= I + rob[head0].v;
		if (rob[head0].decbus.oddball)
			tOddballCommit(1'b1, head0);
		else if (rob[head1].decbus.oddball && rob[head0].exc==FLT_NONE) begin
			if (rob[head1].exc != FLT_NONE)
				tProcessExc(head1,rob[head1].pc);
			rob[head1].v <= INV;
			rob[head1].lsq <= 'd0;
			tags2free[1] <= rob[head1].pRt;
			tOddballCommit(1'b1, head1);
			head0 <= (head0 + 3'd2) % ROB_ENTRIES;
			I <= I + rob[head0].v + rob[head1].v;
		end
		else if (rob[head2].decbus.oddball && rob[head0].exc==FLT_NONE && rob[head1].exc==FLT_NONE) begin
			if (rob[head2].exc != FLT_NONE)
				tProcessExc(head2,rob[head2].pc);
			rob[head1].v <= INV;
			rob[head2].v <= INV;
			rob[head1].lsq <= 'd0;
			rob[head2].lsq <= 'd0;
			tags2free[1] <= rob[head1].pRt;
			tags2free[2] <= rob[head2].pRt;
			tOddballCommit(1'b1, head2);
			head0 <= (head0 + 3'd3) % ROB_ENTRIES;
			I <= I + rob[head0].v + rob[head1].v + rob[head2].v;
		end
		else if (rob[head3].decbus.oddball && rob[head0].exc==FLT_NONE && rob[head1].exc==FLT_NONE && rob[head2].exc==FLT_NONE) begin
			if (rob[head3].exc != FLT_NONE)
				tProcessExc(head3,rob[head3].pc);
			rob[head1].v <= INV;
			rob[head2].v <= INV;
			rob[head3].v <= INV;
			rob[head1].lsq <= 'd0;
			rob[head2].lsq <= 'd0;
			rob[head3].lsq <= 'd0;
			tags2free[1] <= rob[head1].pRt;
			tags2free[2] <= rob[head2].pRt;
			tags2free[3] <= rob[head3].pRt;
			tOddballCommit(1'b1, head3);
			head0 <= (head0 + 3'd4) % ROB_ENTRIES;
			I <= I + rob[head0].v + rob[head1].v + rob[head2].v + rob[head3].v;
		end
		else begin
			if (rob[head0].exc==FLT_NONE) begin
				rob[head1].v <= INV;
				rob[head1].lsq <= 'd0;
				tags2free[1] <= rob[head1].pRt;
				head0 <= (head0 + 3'd2) % ROB_ENTRIES;
				I <= I + rob[head0].v + rob[head1].v;
				if (rob[head1].exc != FLT_NONE)
					tProcessExc(head1,rob[head1].pc);
				else begin
					rob[head2].v <= INV;
					rob[head2].lsq <= 'd0;
					tags2free[2] <= rob[head2].pRt;
					head0 <= (head0 + 3'd3) % ROB_ENTRIES;
					I <= I + rob[head0].v + rob[head1].v + rob[head2].v;
					if (rob[head2].exc != FLT_NONE)
						tProcessExc(head2,rob[head2].pc);
					else begin
						rob[head3].v <= INV;
						rob[head3].lsq <= 'd0;
						tags2free[3] <= rob[head3].pRt;
						if (rob[head3].exc != FLT_NONE)
							tProcessExc(head2,rob[head3].pc);
						head0 <= (head0 + 3'd4) % ROB_ENTRIES;
						I <= I + rob[head0].v + rob[head1].v + rob[head2].v + rob[head3].v;
					end
				end
			end
		end
	end
	else begin
		tags2free[0] <= 'd0;
		tags2free[1] <= 'd0;
		tags2free[2] <= 'd0;
		tags2free[3] <= 'd0;
	end
	
end

// External bus arbiter. Simple priority encoded.

always_ff @(posedge clk)
begin
	// Setup to retry.
	ftatm_resp.rty <= 1'b1;
	ftaim_resp.rty <= 1'b1;
	ftadm_resp[1].rty <= 1'b1;
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
		fta_req <= 'd0;

	// Route bus responses.
	case(fta_resp.cid)
	4'd0:	ftaim_resp <= fta_resp;
	4'd1:	ftadm_resp[0] <= fta_resp;
	4'd2:	ftadm_resp[1] <= fta_resp;
	4'd3:	ftatm_resp <= fta_resp;
	default:	;	// response was not for us
	endcase

end

task tReset;
begin
	for (n14 = 0; n14 < 4; n14 = n14 + 1) begin
		kvec[n14] <= RSTPC >> 12;
		avec[n14] <= RSTPC >> 12;
	end
	excir <= {33'd0,OP_NOP};
	excmiss <= 1'b0;
	excmisspc <= RSTPC;
	sr <= 'd0;
	sr.om <= OM_MACHINE;
	sr.ipl <= 3'd7;				// non-maskable interrupts only
	asid <= 'd0;
	ip_asid <= 'd0;
//	atom_mask <= 'd0;
//	postfix_mask <= 'd0;
	dram_exc0 <= FLT_NONE;
	dram_exc1 <= FLT_NONE;
	dram0 <= DRAMSLOT_AVAIL;
	dram0p <= DRAMSLOT_AVAIL;
	dram0_stomp <= 'd0;
	dram0_vaddr <= 'd0;
	dram0_paddr <= 'd0;
	dram0_data <= 'd0;
	dram0_exc <= FLT_NONE;
	dram0_id <= 'd0;
	dram0_load <= 'd0;
	dram0_loadz <= 'd0;
	dram0_store <= 'd0;
	dram0_erc <= 'd0;
	dram0_op <= OP_NOP;
	dram0_Rt <= 'd0;
	dram0_tid <= 'd0;
	dram0_more <= 'd0;
	dram0_hi <= 'd0;
	dram0_shift <= 'd0;
	dram0_tocnt <= 'd0;
	dram1 <= DRAMSLOT_AVAIL;
	dram1p <= DRAMSLOT_AVAIL;
	dram1_stomp <= 'd0;
	dram1_vaddr <= 'd0;
	dram1_paddr <= 'd0;
	dram1_data <= 'd0;
	dram1_exc <= FLT_NONE;
	dram1_id <= 'd0;
	dram1_load <= 'd0;
	dram1_loadz <= 'd0;
	dram1_store <= 'd0;
	dram1_erc <= 'd0;
	dram1_op <= OP_NOP;
	dram1_Rt <= 'd0;
	dram1_tid <= 8'h08;
	dram1_more <= 'd0;
	dram1_hi <= 'd0;
	dram1_shift <= 'd0;
	dram1_tocnt <= 'd0;
	dram_v0 <= 'd0;
	dram_v1 <= 'd0;
	panic <= `PANIC_NONE;
	robentry_issue_reg <= 'd0;
	for (n14 = 0; n14 < ROB_ENTRIES; n14 = n14 + 1) begin
		rob[n14].sn <= 'd0;
		rob[n14].owner <= NONE;
	end
	alu0_available <= 1;
	alu0_dataready <= 0;
	alu1_available <= 1;
	alu1_dataready <= 0;
	alu0_ld <= 1'b0;
	alu1_ld <= 1'b0;
	fcu_available <= 1;
	fcu_dataready <= 0;
	fcu_pc <= 'd0;
	fcu_sourceid <= 'd0;
	fcu_instr <= OP_NOP;
//	fcu_exc <= FLT_NONE;
	fcu_bt <= 'd0;
	fcu_argA <= 'd0;
	fcu_argB <= 'd0;
	fcu_argC <= 'd0;
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
end
endtask

task tEnque;
input seqnum_t sn;
input decode_bus_t db;
input pc_address_t pc;
input instruction_t ins;
input pt;
input rob_ndx_t tail;
input stomp;
input pregno_t pRa;
input pregno_t pRb;
input pregno_t pRc;
input pregno_t pRt;
input pregno_t nRt;
input [PREGS-1:0] avail;
input [3:0] cndx;
integer n12;
integer n13;
begin
	rob[tail].sn <= sn;
	rob[tail].done <= db.nop;
	rob[tail].out <= INV;
	rob[tail].lsq <= INV;
	rob[tail].takb <= 1'b0;
	rob[tail].exc <= FLT_NONE;
	rob[tail].argA_v <= fnSourceAv(ins);
	rob[tail].argB_v <= fnSourceBv(ins);
	rob[tail].argC_v <= fnSourceCv(ins);
	rob[tail].owner <= QuplsPkg::NONE;

	rob[tail].op <= ins;
	rob[tail].pc <= pc;
	rob[tail].bt <= pt;
	rob[tail].cndx <= cndx;
	rob[tail].decbus <= db;
	rob[tail].pRa <= pRa;
	rob[tail].pRb <= pRb;
	rob[tail].pRc <= pRc;
	rob[tail].pRt <= pRt;
	rob[tail].nRt <= nRt;
	rob[tail].brtgt <= 'd0;
	rob[tail].avail <= avail;
	rob[tail].v <= ~stomp;
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
		case(rob[head].op.any.opcode)
		OP_SYS:
			tProcessExc(head,fnPCInc(rob[head].pc));
		OP_CSR:	
			case(rob[head].op[39:38])
			2'd0:	;	// readCSR
			2'd1:	tWriteCSR(rob[head].arg,{2'b0,rob[head].op[32:19]});
			2'd2:	tSetbitCSR(rob[head].arg,{2'b0,rob[head].op[32:19]});
			2'd3:	tClrbitCSR(rob[head].arg,{2'b0,rob[head].op[32:19]});
			endcase
		OP_RTD:
			if (rob[head].op[10:9]==2'd1) // RTI
				tProcessRti(rob[head].op[8:7]==2'd1);
		OP_IRQ:
			case(rob[head].op[25:22])
			4'h7:	tRex(head,rob[head].op);
			default:	;
			endcase
		default:	;
		endcase
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
	sr.ipl <= 3'd7;
	excir <= rob[id].op;
	excid <= id;
	excmiss <= 1'b1;
	if (vecno < 9'd64)
		excmisspc <= {kvec[3][$bits(pc_address_t)-1:16] /*+ vecno*/,4'h0,12'h000};
	else
		excmisspc <= {avec[$bits(pc_address_t)-1:16] + vecno,4'h0,12'h000};
	free_bitlist <= rob[id].avail;
end
endtask

task tProcessRti;
input twoup;
integer nn;
begin
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

module modFcuMissPC(instr, bts, pc, pc_stack, bt, argA, argC, argI, misspc);
input instruction_t instr;
input bts_t bts;
input pc_address_t pc;
input pc_address_t [8:0] pc_stack;
input bt;
input value_t argA;
input value_t argC;
input value_t argI;
output pc_address_t misspc;

pc_address_t tpc;
always_comb
	tpc = pc + 16'h5000;

always_comb
	case(bts)
	BTS_REG:
		 begin
			misspc = bt ? tpc : argC + {{53{instr[39]}},instr[39:31],instr[12:11],12'h000};
			misspc[11:0] = 'd0;
		end
	BTS_DISP:
		begin
			misspc = bt ? tpc : pc + {{47{instr[39]}},instr[39:25],instr[12:11],12'h000};
			misspc[11:0] = 'd0;
		end
	BTS_BSR:
		begin
			misspc = pc + {{33{instr[39]}},instr[39:9],12'h000};
			misspc[11:0] = 'd0;
		end
	BTS_CALL:
		begin
			misspc = argA + {argI,12'h000};
			misspc[11:0] = 'd0;
		end
	// Must be tested before Ret
	BTS_RTI:
		misspc = instr[8:7]==2'd1 ? pc_stack[1] : pc_stack[0];
	BTS_RET:
		begin
			misspc = argC + {instr[18:11],12'h000};
			misspc[11:0] = 'd0;
		end
	default:
		misspc = RSTPC;
	endcase

endmodule
