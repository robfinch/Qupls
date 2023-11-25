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

// JALR and EXTENDED are synonyms
`define EXTEND	3'd7

// system-call subclasses:
`define SYS_NONE	3'd0
`define SYS_CALL	3'd1
`define SYS_MFSR	3'd2
`define SYS_MTSR	3'd3
`define SYS_RFU1	3'd4
`define SYS_RFU2	3'd5
`define SYS_RFU3	3'd6
`define SYS_EXC		3'd7	// doesn't need to be last, but what the heck

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
	ftaim_req, ftaim_resp, ftaim_full, ftadm_req, ftadm_resp, ftadm_full,
	snoop_adr, snoop_v, snoop_cid);
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
output fta_cmd_request128_t [NDATA_PORTS-1:0] ftadm_req;
input fta_cmd_response128_t [NDATA_PORTS-1:0] ftadm_resp;
input ftadm_full;
output fta_cmd_request128_t ftaim_req;
input fta_cmd_response128_t ftaim_resp;
input ftaim_full;
input QuplsPkg::address_t snoop_adr;
input snoop_v;
input [5:0] snoop_cid;



integer nn,mm,n4,m4;
genvar g,h;
rndx_t alu0_re;
reg [127:0] message;

reg [39:0] I;	// Committed instructions

rob_ndx_t agen0_rndx, agen1_rndx;

// CSRs
asid_t asid;

op_src_t alu0_argA_src;
op_src_t alu0_argB_src;
op_src_t alu0_argC_src;

value_t rfo_alu0_argA;
value_t rfo_alu0_argB;
value_t rfo_alu0_argC;
value_t alu0_res;
value_t alu1_res;
value_t fpu0_res;
value_t fcu_res;
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

pregno_t fcu_argA_reg;
pregno_t fcu_argB_reg;

pregno_t agen0_argA_reg;
pregno_t agen0_argB_reg;

pregno_t agen1_argA_reg;
pregno_t agen1_argB_reg;

pregno_t store_argC_reg;

pregno_t [26:0] rf_reg;
value_t [26:0] rfo;

rob_entry_t [3:0] rob [0:ROB_ENTRIES-1];
reg [ROB_ENTRIES-1:0] rob_v, robentry_stomp;
reg [3:0] robentry_stomp [0:ROB_ENTRIES-1];
load_entry_t [7:0] loadq;
reg [2:0] lq_tail, lq_head;

rob_ndx_t tail0, tail1, tail2, tail3;
rob_ndx_t head0, head1, head2, head3;

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

initial begin: Init
	integer i,j;

	for (i=0; i < ROB_QENTRIES; i=i+1) begin
	  	rob_v[i] = INV;
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
assign rf_reg[5] = alu1_argC_reg;

assign rf_reg[6] = fpu0_argA_reg;
assign rf_reg[7] = fpu0_argB_reg;
assign rf_reg[8] = fpu0_argC_reg;

assign rf_reg[9] = fcu_argA_reg;
assign rf_reg[10] = fcu_argB_reg;

assign rf_reg[11] = agen0_argA_reg;
assign rf_reg[12] = agen0_argB_reg;

assign rf_reg[13] = agen1_argA_reg;
assign rf_reg[14] = agen1_argB_reg;

assign rf_reg[15] = store_argC_reg;

assign rfo_alu0_argA = rfo[0];
assign rfo_alu0_argB = rfo[1];
assign rfo_alu0_argC = rfo[2];

assign rfo_alu1_argA = rfo[3];
assign rfo_alu1_argB = rfo[4];
assign rfo_alu1_argC = rfo[5];

assign rfo_fpu0_argA = rfo[6];
assign rfo_fpu0_argB = rfo[7];
assign rfo_fpu0_argC = rfo[8];

assign rfo_fcu_argA = rfo[9];
assign rfo_fcu_argB = rfo[10];

assign rfo_agen0_argA = rfo[11];
assign rfo_agen0_argB = rfo[12];

assign rfo_agen1_argA = rfo[13];
assign rfo_agen1_argB = rfo[14];

assign rfo_store_argC = rfo[15];

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
wire [4:0] len0, len1, len2, len3, len4, len5;
instruction_t ins0, ins1, ins2, ins3, ins4, ins5, ins6;
reg ins0_v, ins1_v, ins2_v, ins3_v;
reg [3:0] ins_v;
reg insnq0,insnq1,insnq2,insnq3;
reg [3:0] qd, cqd, qs;
reg [3:0] next_cqd;
wire pe_alldq;
reg fetch_new;

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
		ins0_v = ins0_v & ~(qd[0]|qs[0]);
		ins1_v = ins1_v & ~(qd[1]|qs[1]);
		ins2_v = ins2_v & ~(qd[2]|qs[2]);
		ins3_v = ins3_v & ~(qd[3]|qs[3]);
	end
end

Qupls_ins_length ul0 (ins0, len0);
Qupls_ins_length ul1 (ins1, len1);
Qupls_ins_length ul2 (ins2, len2);
Qupls_ins_length ul3 (ins3, len3);
Qupls_ins_length ul4 (ins4, len4);
Qupls_ins_length ul5 (ins5, len5);
  
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
	.ip_o(pco),
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
	.miss_adr(ic_miss_adr),
	.miss_asid(ic_miss_asid),
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
	.commit_takb2(commit_takb2)
	.commit_pc3(commit_pc3),
	.commit_brtgt3(commit_brtgt3),
	.commit_takb3(commit_takb3),
	.len3(len3)
);

always_comb pc1 = {pc0[43:12] + len0,12'h0};
always_comb pc2 = {pc1[43:12] + len1,12'h0};
always_comb pc3 = {pc2[43:12] + len2,12'h0};
always_comb pc4 = {pc3[43:12] + len3,12'h0};
always_comb pc5 = {pc4[43:12] + len4,12'h0};
always_comb pc6 = {pc5[43:12] + len5,12'h0};

// qd indicates which instructions will queue in a given cycle.
// qs indicates which instructions are stomped on.
always_comb
begin
	qd = 'd0;
	qs = 'd0;
	if (branchmiss)
	else if (ihit || |pc[11:0])
		case (~cqd)

    4'b0000: ; // do nothing

    4'b0001:	
    	if (rob_v[tail0]==INV)
    		qd = qd | 4'b0001;
    4'b0010:	
    	if (rob_v[tail0]==INV)
    		qd = qd | 4'b0010;
    4'b0011:
    	if (rob_v[tail0]==INV) begin
    		qd = qd | 4'b0010;
    		if (!pt2) begin
    			if (rob_v[tail1]==INV)
    				qd = qd | 4'b0001;
    		end
    		else
    			qs = qs | 4'b0001;
    	end
    4'b0100:	
    	if (rob_v[tail0]==INV)
    		qd = qd | 4'b0100;
    4'b0101:
    	if (rob_v[tail0]==INV) begin
    		qd = qd | 4'b0100;
    		if (!pt1) begin
    			if (rob_v[tail1]==INV)
	    			qd = qd | 4'b0001;
	    	end
	    	else
	    		qs = qs | 4'b0001;
    	end
    4'b0110:
    	if (rob_v[tail0]==INV) begin
    		qd = qd | 4'b0100;
    		if (!pt1) begin
    			if (rob_v[tail1]==INV)
    				qd = qd | 4'b0010;
    		end
    		else
	    		qs = qs | 4'b0010;
    	end
    4'b0111:
    	if (rob_v[tail0]==INV) begin
    		qd = qd | 4'b0100;
    		if (!pt1) begin
	    		if (rob_v[tail1]==INV) begin
	    			qd = qd  | 4'b0010;
	    			if (!pt2) begin
	    				if (rob_v[tail2]==INV)
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
    	if (rob_v[tail0]==INV)
	   		qd = qd | 4'b1000;
    4'b1001:
    	if (rob_v[tail0]==INV) begin
    		qd = qd | 4'b1000;
    		if (!pt0) begin
    			if (rob_v[tail1]==INV)
	    			qd = qd | 4'b0001;
	    	end
	    	else
	    		qs = qs | 4'b0001;
    	end
    4'b1010:
    	if (rob_v[tail0]==INV) begin
    		qd = qd | 4'b1000;
    		if (!pt0) begin
    			if (rob_v[tail1]==INV)
	    			qd = qd | 4'b0010;
	    	end
	    	else
	    		qs = qs | 4'b0010;
    	end
    4'b1011:
    	if (rob_v[tail0]==INV) begin
    		qd = qd | 4'b1000;
    		if (!pt0) begin
    			if (rob_v[tail1]==INV) begin
	    			qd = qd | 4'b0010;
    				if (!pt2) begin
    					if (rob_v[tail2]==INV)
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
    	if (rob_v[tail0]==INV) begin
    		qd = qd | 4'b1000;
    		if (!pt0) begin
    			if (rob_v[tail1]==INV)
	    			qd = qd | 4'b0100;
	    	end
	    	else
	    		qs = qs | 4'b0100;
    	end
    4'b1101:
    	if (rob_v[tail0]==INV) begin
    		qd = qd | 4'b1000;
    		if (!pt0) begin
    			if (rob_v[tail1]==INV) begin
		    		qd = qd | 4'b0100;
	    			if (!pt1) begin
	    				if (rob_v[tail2]==INV)
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
    	if (rob_v[tail0]==INV) begin
    		qd = qd | 4'b1000;
    		if (!pt0) begin
    			if (rob_v[tail1]==INV) begin
		    		qd = qd | 4'b0100;
	    			if (!pt1) begin
	    				if (rob_v[tail2]==INV)
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
    	if (rob_v[tail0]==INV) begin
    		qd = qd | 4'b1000;
    		if (!pt0) begin
    			if (rob_v[tail1]==INV) begin
	    			qd = qd | 4'b0100;
	    			if (!pt1) begin
	    				if (rob_v[tail2]==INV) begin
			    			qd = qd | 4'b0010;
		    				if (!pt2) begin
		    					if (rob_v[tail3]==INV)
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

edge_det ued1 (.rst(rst), .clk(clk), .ce(1'b1), .i(next_cqd==4'b1111), .pe(pe_alldq), .ne(), .ee());

always_comb
	fetch_new = (ihit & ~irq & (pe_allqd|allqd) & ~(|pc[11:0]) & ~branchmiss) |
							(|pc[11:0] & ~irq & (pe_allqd|allqd) & ~branchmiss);

always_ff @(posedge clk)
if (rst) begin
	pc0 <= RST_PC;
	allqd <= 1'b1;
end
else begin
	if (pe_allqd & ~(ihit & ~irq))
		allqd <= 1'b1;
	if (branchmiss) begin
		allqd <= 1'b0;
   	pc0 <= misspc;
  end
  else begin
		if (|pc0[11:0]) begin
		  if (~irq) begin
		  	if (~|next_micro_ip)
		  		pc0 <= pc0 + 16'h5000;
	  		pc0[11:0] <= next_micro_ip;
			end
		end
		else if (ihit) begin
		  if (~irq) begin
		  	if (pe_allqd|allqd) begin
			  	pc0 <= next_pc;
			  	allqd <= 1'b0;
			  end
			end
		end
	end
end

always_comb
	ic_line = {ic_line_hi.data,ic_line_lo.data};
always_comb
	ins0 = ic_line >> {pc0[17:12],3'd0};
always_comb
	ins1 = ic_line >> {pc1[17:12],3'd0};
always_comb
	ins2 = ic_line >> {pc2[17:12],3'd0};
always_comb
	ins3 = ic_line >> {pc3[17:12],3'd0};
always_comb
	ins4 = ic_line >> {pc4[17:12],3'd0};
always_comb
	ins5 = ic_line >> {pc5[17:12],3'd0};
always_comb
	ins6 = ic_line >> {pc6[17:12],3'd0};

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
	.db(db0)
);

Qupls_decoder udeci1
(
	.clk(clk),
	.instr(instr[1]),
	.db(db1)
);

Qupls_decoder udeci2
(
	.clk(clk),
	.instr(instr[2]),
	.db(db2)
);

Qupls_decoder udeci3
(
	.clk(clk),
	.instr(instr[3]),
	.db(db3)
);

//
// RENAME
//
aregno_t [15:0] arn;
pregno_t [15:0] prn;

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

wire stallq;
wire nq = !branchmiss && rob_v[tail]==INV;

wire do_commit =
	(((
		((rob[head][0].v && rob[head][0].done) || !rob[head][0].v) &&
		((rob[head][1].v && rob[head][1].done) || !rob[head][1].v) &&
		((rob[head][2].v && rob[head][2].done) || !rob[head][2].v) &&
		((rob[head][3].v && rob[head][3].done) || !rob[head][3].v)
		) || !rob_v[head]) && head != tail)
	;

wire cmtbr =
	(rob[head][0].br & rob[head][0].v) ||
	(rob[head][1].br & rob[head][1].v) ||
	(rob[head][2].br & rob[head][2].v) ||
	(rob[head][3].br & rob[head][3].v)
	;
	
Qupls_reg_renamer utrn1
(
	.rst(rst),
	.clk(clk),
	.list2free(),
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
	.cndx(cndx),
	.avail(),
	.flush(branchmiss),
	.miss_cp(),
	.wr0(|db0r.Rt),
	.wr1(|db1r.Rt),
	.wr2(|db2r.Rt),
	.wr3(|db3r.Rt),
	.qbr0(pt0),
	.qbr1(pt1),
	.qbr2(pt2),
	.qbr3(pt3),
	.rn(arn),
	.rrn(prn),
	.vn(),
	.wra(db0r.Rt),
	.wrra(nRt0),
	.wrb(db1r.Rt),
	.wrrb(nRt1),
	.wrc(db2r.Rt),
	.wrrc(nRt2),
	.wrd(db3r.Rt),
	.wrrd(nRt3),
	.cmtav(do_commit & rob[head][0].v),
	.cmtbv(do_commit & rob[head][1].v),
	.cmtcv(do_commit & rob[head][2].v),
	.cmtdv(do_commit & rob[head][3].v),
	.cmtaa(rob[head][0].decbus.Rt),
	.cmtba(rob[head][1].decbus.Rt),
	.cmtca(rob[head][2].decbus.Rt),
	.cmtda(rob[head][3].decbus.Rt),
	.cmtap(rob[head][0].nRt),
	.cmtbp(rob[head][1].nRt),
	.cmtcp(rob[head][2].nRt),
	.cmtdp(rob[head][3].nRt),
	.cmtbr(cmtbr),
	.freea(rob[head][0].pRt),
	.freeb(rob[head][1].pRt),
	.freec(rob[head][2].pRt),
	.freed(rob[head][3].pRt),
	.free_bitlist()
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
value_t wrport0_res;
value_t wrport1_res;
value_t wrport2_res;
value_t wrport3_res;
pregno_t wrport0_Rt;
pregno_t wrport1_Rt;
pregno_t wrport2_Rt;
pregno_t wrport3_Rt;

assign wrport0_res = alu0_res;
assign wrport1_res = alu1_res;
assign wrport2_res = load_res;
assign wrport3_res = fpu_res;

Qupls_regfile4w16r urf1 (
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
	for (m4 = 0; m4 < 4; m4 = m4 + 1) begin
		robentry_stomp[n4][m4] =
			branchmiss
			&& rob[n4][m4].sn > rob[missid.entry][missid.slot].sn
			&& rob[n4][m4].v
		;
	end
end											

rob_ndx_t stail;	// stomp tail
integer n5;
integer n7;
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
	if (branchmiss_state==3'd1) begin
		missid0 = (excmiss ? excid : fcu_sourceid)==3'd0;
		missid1 = (excmiss ? excid : fcu_sourceid)==3'd1;
		missid2 = (excmiss ? excid : fcu_sourceid)==3'd2;
		missid3 = (excmiss ? excid : fcu_sourceid)==3'd3;
		missid4 = (excmiss ? excid : fcu_sourceid)==3'd4;
		missid5 = (excmiss ? excid : fcu_sourceid)==3'd5;
		missid6 = (excmiss ? excid : fcu_sourceid)==3'd6;
		missid7 = (excmiss ? excid : fcu_sourceid)==3'd7;
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
				    && (rob[g].argC_v
						// Or forwarded
						/*
				    || (rob[g].decbus.Rc == alu0_Rt && alu0_v)
				    || (rob[g].decbus.Rc == alu1_Rt && alu1_v)
				    || (rob[g].decbus.Rc == fpu0_Rt && fpu0_v)
				    || (rob[g].decbus.Rc == fcu_Rt && fcu_v)
				    || (rob[g].decbus.Rc == load_Rt && load_v)
				    */
				    || (rob[g].mem & ~rob[g].agen))
				    ;
assign could_issue[g] = rob[g].v && !rob[g].done 
												&& !rob[g].out
												&& args_valid[g]
                        && (rob[g].mem ? !rob[g].agen : 1'b1);
end                                 
end
end
endgenerate

Qupls_sched uscd1
(
	.alu0_idle(),
	.alu1_idle(),
	.fpu0_idle(),
	.fpu1_idle(),
	.fcu_idle(),
	.agen0_idle(),
	.agen1_idle(),
	.robentry_islot(),
	.could_issue(could_issue), 
	.head(head),
	.rob(rob),
	.robentry_issue(),
	.robentry_fpu_issue(),
	.robentry_fcu_issue(),
	.robentry_agen_issue(),
	.alu0_rndx(alu0_rndx),
	.alu1_rndx(alu1_rndx),
	.alu0_rndxv(alu0_rndxv),
	.alu1_rndxv(alu1_rndxv),
	.fpu0_rndx(),
	.fpu0_rndxv(),
	.fpu1_rndx(),
	.fpu1_rndxv(),
	.fcu_rndx(),
	.fcu_rndxv(),
	.agen0_rndx(agen0_rndx),
	.agen1_rndx(agen1_rndx),
	.agen0_rndxv(agen0_rndxv),
	.agen1_rndxv(agen1_rndxv)
);

assign alu0_argA_reg = rob[alu0_rndx].decbus.Ra;
assign alu0_argB_reg = rob[alu0_rndx].decbus.Rb;
assign alu0_argC_reg = rob[alu0_rndx].decbus.Rc;

assign agen0_argA_reg = rob[agen0_rndx].decbus.Ra;
assign agen0_argB_reg = rob[agen0_rndx].decbus.Rb;

assign agen1_argA_reg = rob[agen1_rndx].decbus.Ra;
assign agen1_argB_reg = rob[agen1_rndx].decbus.Rb;

value_t agen0_res, agen1_res;
wire tlb_miss0, tlb_miss1;
wire tlb_wr;
wire tlb_way;
tlb_entry_t tlb_entry0, tlb_entry1, tlb_entry;
wire [6:0] tlb_entryno;
instruction_t agen0_op, agen1_op;
reg agen0_load, agen1_load;
reg agen0_store, agen1_store;

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

Qupls_agen uag0
(
	.clk(clk),
	.ir(rob[agen0_rndx].op),
	.a(rfo_agen0_argA),
	.b(rfo_agen0_argB),
	.i(rob[agen0_rndx].immb),
	.res(agen0_res)
);

Qupls_agen uag1
(
	.clk(clk),
	.ir(rob[agen1_rndx].op),
	.a(rfo_agen1_argA),
	.b(rfo_agen1_argB),
	.i(rob[agen1_rndx].immb),
	.res(agen1_res)
);

Qupls_tlb utlb1
(
	.clk(clk),
	.wr(tlb_wr),
	.way(tlb_way),
	.entry_no(tlb_entryno),
	.entry_i(tlb_entry),
	.entry_o(),
	.vadr0(agen0_res),
	.vadr1(agen1_res),
	.asid0(asid),
	.asid1(asid),
	.entry0(tlb_entry0),
	.entry1(tlb_entry1),
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
	.ftam_req(),
	.ftam_resp(),
	.fault_o(),
	.tlb_wr(tlb_wr),
	.tlb_way(tlb_way),
	.tlb_entryno(tlb_entryno),
	.tlb_entry(tlb_entry)
);

always_ff @(posedge clk)
begin
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
	if (alu0_v && rob[alu0_sndx].v && rob[alu0_sndx].owner==QuplsPkg::ALU0) begin
    rob[ alu0_sndx ].exc <= alu0_exc;
    rob[ alu0_sndx ].done <= (!rob[ alu0_sndx ].decbus.load
    	&& !rob[ alu0_sndx ].decbus.store
    	&& !rob[ alu0_sndx ].decbus.multicycle
    	);
    rob[ alu0_sndx ].out <= INV;
    rob[ alu0_sndx ].agen <= VAL;
    if (!rob[ alu0_sndx ].decbus.load && !rob[ alu0_sndx ].decbus.store)
    	iqentry_issue_reg[alu0_sndx] <= 1'b0;
    if ((rob[ alu0_sndx].decbus.mul || rob[ alu0_sndx].decbus.mulu) && mul0_done) begin
	    rob[ alu0_sndx ].done <= VAL;
	    rob[ alu0_sndx ].out <= INV;
  	end
    if ((rob[ alu0_sndx].decbus.div || rob[ alu0_sndx].decbus.divu) && div0_done) begin
	    rob[ alu0_sndx ].done <= VAL;
	    rob[ alu0_sndx ].out <= INV;
  	end
	end
	if (NALU > 1 && alu1_v && rob[alu1_sndx].v && rob[alu1_sndx].owner==QuplsPkg::ALU1) begin
    rob[ alu1_sndx ].exc <= alu1_exc;
    rob[ alu1_sndx ].done <= (!rob[ alu1_sndx ].decbus.load && !rob[ alu1_sndx ].decbus.store);
    rob[ alu1_sndx ].out <= INV;
    rob[ alu1_sndx ].agen <= VAL;
	end
	if (NFPU > 0 && fpu_v && rob[fpu_sndx].v && rob[fpu_sndx].owner==QuplsPkg::FPU0) begin
    rob[ fpu_sndx ].exc <= fpu_exc;
    rob[ fpu_sndx ].done <= fpu_done;
    rob[ fpu_sndx ].out <= INV;
    rob[ fpu_sndx ].agen <= VAL;
	end
	if (fcu_v && rob[fcu_sndx].v && rob[fcu_sndx].out && rob[fcu_sndx].owner==QuplsPkg::FCU) begin
    rob[ fcu_sndx ].exc <= fcu_exc;
    rob[ fcu_sndx ].done <= VAL;
    rob[ fcu_sndx ].out <= INV;
    rob[ fcu_sndx ].agen <= VAL;
    rob[ fcu_sndx ].takb <= takb;
    rob[ fcu_sndx ].brtgt <= tgtpc;
	end
	if (load_v && rob[load_sndx].v && rob[load_sndx].owner==QuplsPkg::LOAD) begin
    rob[ load_sndx ].exc <= load_exc;
    rob[ load_sndx ].done <= load_done;
    rob[ load_sndx ].out <= INV;
    rob[ load_sndx ].agen <= VAL;
	end
	// If data for stomped instruction, ignore
	// dram_vn will be false for stomped data
	if (dram_v0 && iq_v[ dram_id0[2:0] ] && rob[ dram_id0[2:0] ].mem  && rob[dram0_id[2:0]].owner==Thor2024pkg::DRAM0) begin
    rob[ dram_id0[2:0] ].res <= dram_bus0;
    rob[ dram_id0[2:0] ].exc <= dram_exc0;
    rob[ dram_id0[2:0] ].out <= INV;
    rob[ dram_id0[2:0] ].done <= VAL;
	end
	if (NDATA_PORTS > 1) begin
		if (dram_v1 && iq_v[ dram_id1[2:0] ] && rob[ dram_id1[2:0] ].mem  && rob[dram1_id[2:0]].owner==Thor2024pkg::DRAM1) begin
	    rob[ dram_id1[2:0] ].res <= dram_bus1;
	    rob[ dram_id1[2:0] ].exc <= dram_exc1;
	    rob[ dram_id1[2:0] ].out <= INV;
	    rob[ dram_id1[2:0] ].done <= VAL;
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
	
	//
	// see if anybody wants the results ... look at lots of buses:
	//  - alu0_bus
	//  - alu1_bus
	//  - fpu bus
	//	- fcu_bus
	//  - dram_bus0
	//  - dram_bus1
	//

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


	// Reservation stations

	if (alu0_available) begin
		alu0_argA <= rob[alu0_sndx].imma | rfo_alu0_argA;
		alu0_argB <= rfo_alu0_argB;
		alu0_argC <= rob[alu0_sndx].immc | rfo_alu0_argC;
		alu0_argI	<= rob[alu0_sndx].decbus.immb;
		alu0_ld <= 1'b1;
		alu0_instr <= rob[alu0_sndx].op;
		alu0_div <= rob[alu0_sndx].decbus.div;
		alu0_pc <= rob[alu0_sndx].pc;
    rob[alu0_sndx].out <= VAL;
    rob[alu0_sndx].owner <= QuplsPkg::ALU0;
	end

	if (alu1_available) begin
		alu1_argA <= rob[alu1_sndx].imma | rfo_alu1_argA;
		alu1_argB <= rfo_alu1_argB;
		alu1_argC <= rob[alu1_sndx].immc | rfo_alu1_argC;
		alu1_argI	<= rob[alu1_sndx].decbus.immb;
		alu1_ld <= 1'b1;
		alu1_instr <= rob[alu1_sndx].op;
		alu1_div <= rob[alu1_sndx].decbus.div;
		alu1_pc <= rob[alu1_sndx].pc;
    rob[alu1_sndx].out <= VAL;
    rob[alu1_sndx].owner <= QuplsPkg::ALU1;
	end

	if (fpu0_available) begin
		fpu0_argA <= rob[fpu0_sndx].imma | rfo_fpu0_argA;
		fpu0_argB <= rfo_fpu0_argB;
		fpu0_argC <= rob[fpu0_sndx].immc | rfo_fpu0_argC;
		fpu0_argI	<= rob[fpu0_sndx].decbus.immb;
		fpu0_ld <= 1'b1;
		fpu0_instr <= rob[fpu0_sndx].op;
		fpu0_div <= rob[fpu0_sndx].decbus.div;
		fpu0_pc <= rob[fpu0_sndx].pc;
    rob[fpu0_sndx].out <= VAL;
    rob[fpu0_sndx].owner <= QuplsPkg::FPU0;
	end

	fcu_argA <= rob[fcu_sndx].imma | rfo_fcu_argA;
	fcu_argB <= rfo_fcu_argB;
	fcu_argC <= rob[fcu_sndx].immc | rfo_fcu_argC;
	fcu_argI <= rob[fcu_sndx].decbus.immb;
	fcu_ld <= 1'b1;
	fcu_instr <= rob[fcu_sndx].op;
	fcu_div <= rob[fcu_sndx].decbus.div;
	fcu_pc <= rob[fcu_sndx].pc;
  rob[fcu_sndx].out <= VAL;
  rob[fcu_sndx].owner <= QuplsPkg::FCU;

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
	if (branchmiss)
		tail <= stail;		// computed above
	else if (!stallq) begin
		if (rob_v[tail0]==INV &&
			rob_v[tail1]==INV && 
			rob_v[tail2]==INV && 
			rob_v[tail3]==INV) begin
			for (n12 = 0; n12 < ROB_ENTRIES; n12 = n12 + 1)
				rob[n12].sn <= rob[n12].sn - 4;
			tEnque(8'hFC,db0r,pc0r,ins0r,pt0,tail0, 1'b0, prn[0], prn[1], prn[2], prn[3], nRt0, avail_reg | (192'd1 << nRt0), cndx);
			tEnque(8'hFD,db1r,pc1r,ins1r,pt1,tail1, pt0, prn[4], prn[5], prn[6], prn[7], nRt1, avail_reg | (192'd1 << nRt0) | (192'd1 << nRt1), cndx);
			tEnque(8'hFE,db2r,pc2r,ins2r,pt2,tail2, pt0|pt1, prn[8], prn[9], prn[10], prn[11], nRt2, avail_reg | (192'd1 << nRt0) | (192'd1 << nRt1) | (192'd1 << nRt2), cndx);
			tEnque(8'hFF,db3r,pc3r,ins3r,pt3,tail3, pt0|pt1|pt2, prn[12], prn[13], prn[14], prn[15], nRt3, avail_reg | (192'd1 << nRt0) | (192'd1 << nRt1) | (192'd1 << nRt2)| (192'd1 << nRt3), cndx);
			rob_v[tail0] <= VAL;
			rob_v[tail1] <= VAL;
			rob_v[tail2] <= VAL;
			rob_v[tail3] <= VAL;
			tail0 <= (tail0 + 2'd4) % ROB_ENTRIES;
		end
	end

	if (agen0_v && agen0_load) begin
		if (loadq[lq_tail].v==INV) begin
			loadq[lq_tail].v <= VAL;
			loadq[lq_tail].vadr <= agen0_res;
			loadq[lq_tail].padr <= {tlb_entry0.pte.ppn,agen0_res[15:0]};
			loadq[lq_tail].memsz <= fnMemsz(agen0_op);
			lq_tail <= (lq_tail + 2'd1) % LOADQ_ENTRIES;
		end
	end
	else if (agen1_v && agen1_load) begin
		if (loadq[lq_tail].v==INV) begin
			loadq[lq_tail].v <= VAL;
			loadq[lq_tail].vadr <= agen1_res;
			loadq[lq_tail].padr <= {tlb_entry1.pte.ppn,agen1_res[15:0]};
			loadq[lq_tail].memsz <= fnMemsz(agen1_op);
			lq_tail <= (lq_tail + 2'd1) % LOADQ_ENTRIES;
		end
	end

	if (agen0_v && agen0_store) begin
		if (storeq[sq_tail].v==INV) begin
			storeq[sq_tail].v <= VAL;
			storeq[sq_tail].vadr <= agen0_res;
			storeq[sq_tail].padr <= {tlb_entry0.pte.ppn,agen0_res[15:0]};
			storeq[sq_tail].memsz <= fnMemsz(agen0_op);
			sq_tail <= (sq_tail + 2'd1) % STOREQ_ENTRIES;
		end
	end
	else if (agen1_v && agen1_store) begin
		if (storeq[sq_tail].v==INV) begin
			storeq[sq_tail].v <= VAL;
			storeq[sq_tail].vadr <= agen1_res;
			storeq[sq_tail].padr <= {tlb_entry1.pte.ppn,agen1_res[15:0]};
			storeq[sq_tail].memsz <= fnMemsz(agen1_op);
			sq_tail <= (sq_tail + 2'd1) % STOREQ_ENTRIES;
		end
	end

//
// COMMIT
//
// The head pointer is advance only once all four ROB entries have committed.
//
	if (do_commit) begin
		rob_v[head0] <= INV;
		rob_v[head1] <= INV;
		rob_v[head2] <= INV;
		rob_v[head3] <= INV;
		tags2free[0] <= rob[head0].pRt;
		tags2free[1] <= rob[head1].pRt;
		tags2free[2] <= rob[head2].pRt;
		tags2free[3] <= rob[head3].pRt;
		head0 <= (head0 + 3'd4) % ROB_ENTRIES;
		I <= I + rob[head0].v + rob[head1].v + rob[head2].v + rob[head3].v;
	end
	else begin
		tags2free[0] <= 'd0;
		tags2free[1] <= 'd0;
		tags2free[2] <= 'd0;
		tags2free[3] <= 'd0;
	end
	
end

task tEnque;
input [7:0] sn;
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
	rob[tail].agen <= INV;
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

endmodule
