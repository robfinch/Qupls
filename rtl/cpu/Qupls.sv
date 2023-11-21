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



integer nn;
genvar g,h;
rndx_t alu0_re;
reg [127:0] message;

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
pregno_t fcu_argT_reg;

pregno_t load_argA_reg;
pregno_t load_argB_reg;
pregno_t load_argC_reg;

pregno_t store_argA_reg;
pregno_t store_argB_reg;
pregno_t store_argC_reg;

pregno_t [26:0] rf_reg;
value_t [26:0] rfo;

rob_entry_t [ROB_ENTRIES-1:0] rob;

rob_ndx_t alu0_sndx;
rob_ndx_t alu1_sndx;
wire alu0_sv;
wire alu1_sv;

initial begin: Init
	integer i,j;

	for (i=0; i < ROB_QENTRIES; i=i+1) begin
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

assign rf_reg[5] = alu1_argA_reg;
assign rf_reg[6] = alu1_argB_reg;
assign rf_reg[7] = alu1_argC_reg;

assign rf_reg[10] = fpu0_argA_reg;
assign rf_reg[11] = fpu0_argB_reg;
assign rf_reg[12] = fpu0_argC_reg;

assign rf_reg[15] = fcu_argA_reg;
assign rf_reg[16] = fcu_argB_reg;
assign rf_reg[17] = fcu_argT_reg;

assign rf_reg[18] = load_argA_reg;
assign rf_reg[19] = load_argB_reg;
assign rf_reg[20] = load_argC_reg;

assign rf_reg[23] = store_argA_reg;
assign rf_reg[24] = store_argB_reg;
assign rf_reg[25] = store_argC_reg;

assign rfo_alu0_argA = rfo[0];
assign rfo_alu0_argB = rfo[1];
assign rfo_alu0_argC = rfo[2];

assign rfo_alu1_argA = rfo[5];
assign rfo_alu1_argB = rfo[6];
assign rfo_alu1_argC = rfo[7];

assign rfo_fpu0_argA = rfo[10];
assign rfo_fpu0_argB = rfo[11];
assign rfo_fpu0_argC = rfo[12];

assign rfo_fcu_argA = rfo[15];
assign rfo_fcu_argB = rfo[16];
assign rfo_fcu_argT = rfo[17];

assign rfo_load_argA = rfo[18];
assign rfo_load_argB = rfo[19];
assign rfo_load_argC = rfo[20];

assign rfo_store_argA = rfo[23];
assign rfo_store_argB = rfo[24];
assign rfo_store_argC = rfo[25];

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

pc_address_t pc0, pc1, pc2, pc3, pc4;
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
wire [4:0] len0, len1, len2, len3;
reg [255:0] ins0, ins1, ins2, ins3, ins4;
reg ins0_v, ins1_v, ins2_v, ins3_v;

Qupls_ins_length ul0 (ins0, len0);
Qupls_ins_length ul1 (ins1, len1);
Qupls_ins_length ul2 (ins2, len2);
Qupls_ins_length ul3 (ins3, len3);
  
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

//
// DECODE
//
decode_bus_t db0, db1, db2, db3;

Qupls_decoder udeci0
(
	.instr(ins0),
	.db(db0)
);

Qupls_decoder udeci1
(
	.instr(ins1),
	.db(db1)
);

Qupls_decoder udeci2
(
	.instr(ins2),
	.db(db2)
);

Qupls_decoder udeci3
(
	.instr(ins3),
	.db(db3)
);


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

Qupls_regfile4w18r urf1 (
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
// additional logic for ISSUE
//
// for the moment, we look at ALU-input buffers to allow back-to-back issue of 
// dependent instructions ... we do not, however, look ahead for DRAM requests 
// that will become valid in the next cycle.  instead, these have to propagate
// their results into the IQ entry directly, at which point it becomes issue-able
//

// note that, for all intents & purposes, iqentry_done == iqentry_agen ... no need to duplicate
rob_ndx_t [7:0] head;

Qupls_head uhd1
(
	.rst(rst),
	.clk(clk),
	.heads(head),
	.tail0(tail0),
	.tail1(tail1),
	.rob(rob),
	.panic_i(4'd0),
	.panic_o(),
	.I()
);

rob_bitmask_t args_valid;
rob_bitmask_t could_issue;

generate begin : issue_logic
for (g = 0; g < ROB_ENTRIES; g = g + 1) begin
	assign args_valid[g] = (rob[g].argA_v
						// Or forwarded
				    || (rob[g].decbus.Ra == alu0_Rt && alu0_v)
				    || (rob[g].decbus.Ra == alu1_Rt && alu1_v)
				    || (rob[g].decbus.Ra == fpu0_Rt && fpu0_v)
				    || (rob[g].decbus.Ra == fcu_Rt && fcu_v)
				    || (rob[g].decbus.Ra == load_Rt && load_v))
				    && (rob[g].argB_v
						// Or forwarded
				    || (rob[g].decbus.Rb == alu0_Rt && alu0_v)
				    || (rob[g].decbus.Rb == alu1_Rt && alu1_v)
				    || (rob[g].decbus.Rb == fpu0_Rt && fpu0_v)
				    || (rob[g].decbus.Rb == fcu_Rt && fcu_v)
				    || (rob[g].decbus.Rb == load_Rt && load_v))
				    && (rob[g].argC_v
						// Or forwarded
				    || (rob[g].decbus.Rc == alu0_Rt && alu0_v)
				    || (rob[g].decbus.Rc == alu1_Rt && alu1_v)
				    || (rob[g].decbus.Rc == fpu0_Rt && fpu0_v)
				    || (rob[g].decbus.Rc == fcu_Rt && fcu_v)
				    || (rob[g].decbus.Rc == load_Rt && load_v)
				    || (rob[g].mem & ~rob[g].agen))
				    ;
assign could_issue[g] = rob_v[g] && !rob[g].done 
												&& !rob[g].out
												&& args_valid[g]
                        && (rob[g].mem ? !rob[g].agen : 1'b1);
end                                 
end
end
endgenerate

Qupls_alu_sched uas1
(
	.alu0_idle(),
	.alu1_idle(),
	.robentry_islot(),
	.could_issue(could_issue), 
	.head(head),
	.rob(rob),
	.robentry_issue(),
	.entry0(alu0_sndx),
	.entry1(alu1_sndx),
	.entry0v(alu0_sv),
	.entry1v(alu1_sv)
);

assign alu0_argA_reg = rob[alu0_sndx].decbus.Ra;
assign alu0_argB_reg = rob[alu0_sndx].decbus.Rb;
assign alu0_argC_reg = rob[alu0_sndx].decbus.Rc;
assign alu0_argT_reg = rob[alu0_sndx].decbus.Rt;

always_ff @(posedge clk)
begin
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

		if (rob[nn].argA_v == INV && rob[nn].decbus.Ra == wrport0_Rt && rob_v[nn] == VAL && wrport0_v == VAL)
	    rob[nn].argA_v <= VAL;
		if (rob[nn].argB_v == INV && rob[nn].decbus.Rb == wrport0_Rt && rob_v[nn] == VAL && wrport0_v == VAL)
	    rob[nn].argB_v <= VAL;
		if (rob[nn].argC_v == INV && rob[nn].decbus.Rc == wrport0_Rt && rob_v[nn] == VAL && wrport0_v == VAL)
	    rob[nn].argC_v <= VAL;
		if (rob[nn].argT_v == INV && rob[nn].decbus.Rt == wrport0_Rt && rob_v[nn] == VAL && wrport0_v == VAL)
	    rob[nn].argT_v <= VAL;
		if (rob[nn].argP_v == INV && rob[nn].decbus.Rp == wrport0_Rt && rob_v[nn] == VAL && wrport0_v == VAL)
	    rob[nn].argP_v <= VAL;

		if (NALU > 1) begin
			if (rob[nn].argA_v == INV && rob[nn].decbus.Ra == wrport1_Rt && rob_v[nn] == VAL && wrport1_v == VAL)
		    rob[nn].argA_v <= VAL;
			if (rob[nn].argB_v == INV && rob[nn].decbus.Rb == wrport1_Rt && rob_v[nn] == VAL && wrport1_v == VAL)
		    rob[nn].argB_v <= VAL;
			if (rob[nn].argC_v == INV && rob[nn].decbus.Rc == wrport1_Rt && rob_v[nn] == VAL && wrport1_v == VAL)
		    rob[nn].argC_v <= VAL;
			if (rob[nn].argT_v == INV && rob[nn].decbus.Rt == wrport1_Rt && rob_v[nn] == VAL && wrport1_v == VAL)
		    rob[nn].argT_v <= VAL;
			if (rob[nn].argP_v == INV && rob[nn].decbus.Rp == wrport1_Rt && rob_v[nn] == VAL && wrport1_v == VAL)
		    rob[nn].argP_v <= VAL;
		end

		if (rob[nn].argA_v == INV && rob[nn].decbus.Ra == wrport2_Rt && rob_v[nn] == VAL && wrport2_v == VAL)
	    rob[nn].argA_v <= VAL;
		if (rob[nn].argB_v == INV && rob[nn].decbus.Rb == wrport2_Rt && rob_v[nn] == VAL && wrport2_v == VAL)
	    rob[nn].argB_v <= VAL;
		if (rob[nn].argC_v == INV && rob[nn].decbus.Rc == wrport2_Rt && rob_v[nn] == VAL && wrport2_v == VAL)
	    rob[nn].argC_v <= VAL;
		if (rob[nn].argT_v == INV && rob[nn].decbus.Rt == wrport2_Rt && rob_v[nn] == VAL && wrport2_v == VAL)
	    rob[nn].argT_v <= VAL;
		if (rob[nn].argP_v == INV && rob[nn].decbus.Rp == wrport2_Rt && rob_v[nn] == VAL && wrport2_v == VAL)
	    rob[nn].argP_v <= VAL;

	end


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

	//
	// enqueue fetchbuf0 and fetchbuf1, but only if there is room, 
	// and ignore fetchbuf1 if fetchbuf0 has a backwards branch in it.
	//
	// also, do some instruction-decode ... set the operand_valid bits in the IQ
	// appropriately so that the DATAINCOMING stage does not have to look at the opcode
	//
	if (!branchmiss) 	// don't bother doing anything if there's been a branch miss

		case ({ins0_v, ins1_v, ins2_v, ins3_v})

    4'b0000: ; // do nothing

    4'b0001:	tEnque(3'd1,db3,pc3,ins3,pt3,tail0);
    4'b0010:	tEnque(3'd1,db2,pc2,ins2,pt2,tail0);
    4'b0011:
    	begin
    		tEnque(3'd1,db2,pc2,ins2,pt2,tail0);
    		if (!pt2)
    			tEnque(3'd2,db3,pc3,ins3,pt3,tail1);
    	end
    4'b0100:	tEnque(3'd1,db1,pc1,ins1,pt1,tail0);
    4'b0101:
    	begin
    		tEnque(3'd1,db1,pc1,ins1,pt1,tail0);
    		if (!pt1)
    			tEnque(3'd2,db3,pc3,ins3,pt3,tail1);
    	end
    4'b0110:
    	begin
    		tEnque(3'd1,db1,pc1,ins1,pt1,tail0);
    		if (!pt1)
    			tEnque(3'd2,db2,pc2,ins2,pt2,tail1);
    	end
    4'b0111:
    	begin
    		tEnque(3'd1,db1,pc1,ins1,pt1,tail0);
    		if (!pt1) begin
    			tEnque(3'd2,db2,pc2,ins2,pt2,tail1);
    			if (!pt2)
    				tEnque(3'd3,db3,pc3,ins3,pt3,tail2);
    		end
    	end
    4'b1000:	tEnque(3'd1,db0,pc0,ins0,pt0,tail0);
    4'b1001:
    	begin
    		tEnque(3'd1,db0,pc0,ins0,pt0,tail0);
    		if (!pt0)
    			tEnque(3'd2,db3,pc3,ins3,pt3,tail1);
    	end
    4'b1010:
    	begin
    		tEnque(3'd1,db0,pc0,ins0,pt0,tail0);
    		if (!pt0)
    			tEnque(3'd2,db2,pc2,ins2,pt2,tail1);
    	end
    4'b1011:
    	begin
    		tEnque(3'd1,db0,pc0,ins0,pt0,tail0);
    		if (!pt0) begin
    			tEnque(3'd2,db2,pc2,ins2,pt2,tail1);
    			if (!pt2)
    				tEnque(3'd3,db3,pc3,ins3,pt3,tail2);
    		end
    	end
    4'b1100:
    	begin
    		tEnque(3'd1,db0,pc0,ins0,pt0,tail0);
    		if (!pt0)
    			tEnque(3'd2,db1,pc1,ins1,pt1,tail1);
    	end
    4'b1101:
    	begin
    		tEnque(3'd1,db0,pc0,ins0,pt0,tail0);
    		if (!pt0) begin
    			tEnque(3'd2,db1,pc1,ins1,pt1,tail1);
    			if (!pt1)
    				tEnque(3'd3,db3,pc3,ins3,pt3,tail2);
    		end
    	end
    4'b1110:
    	begin
    		tEnque(3'd1,db0,pc0,ins0,pt0,tail0);
    		if (!pt0) begin
    			tEnque(3'd2,db1,pc1,ins1,pt1,tail1);
    			if (!pt1)
    				tEnque(3'd3,db2,pc2,ins2,pt2,tail2);
    		end
    	end
    4'b1111:
    	begin
    		tEnque(3'd1,db0,pc0,ins0,pt0,tail0);
    		if (!pt0) begin
    			tEnque(3'd2,db1,pc1,ins1,pt1,tail1);
    			if (!pt1) begin
    				tEnque(3'd3,db2,pc2,ins2,pt2,tail2);
    				if (!pt2)
    					tEnque(3'd4,db3,pc3,ins3,pt3,tail3);
    			end
    		end
    	end
    endcase

/* 
    2'b11:
    	if (rob_v[tail0] == INV) begin

				//
				// if the first instruction is a backwards branch, enqueue it & stomp on all following instructions
				//
				if (pt0) begin
					did_branchback1 <= branchback & ~did_branchback;
					for (n12 = 0; n12 < ROB_ENTRIES; n12 = n12 + 1)
						rob[n12].sn <= rob[n12].sn - 2'd1;
//						rob[n12].sn <= |rob[n12].sn ? rob[n12].sn - 2'd1 : rob[n12].sn;
					rob[tail0].sn <= 6'h3F;
					rob[tail0].owner <= Thor2025pkg::NONE;
			    rob[tail0].done <= db0.nop;
			    rob[tail0].out <=	INV;
			    rob[tail0].op <=	fetchbuf0_instr[0]; 			// BEQ
			    rob[tail0].bt <= VAL;
			    rob[tail0].agen <= INV;
			    rob[tail0].pc <=	fetchbuf0_pc;
			    rob[tail0].decbus <= db0;
			    rob[tail0].exc    <=	FLT_NONE;
					rob[tail0].takb <= 1'b0;
					rob[tail0].brtgt <= 'd0;
					rob[tail0].argA_v <= fnSourceAv(fetchbuf0_instr[0]) || rf_v[ db0.Ra ];
					rob[tail0].argB_v <= fnSourceBv(fetchbuf0_instr[0]) || rf_v[ db0.Rb ];
					rob[tail0].argC_v <= fnSourceCv(fetchbuf0_instr[0]) || rf_v[ db0.Rc ];
					rob[tail0].argT_v <= fnSourceTv(fetchbuf0_instr[0]) || rf_v[ db0.Rt ];
					rob[tail0].argP_v <= fnSourcePv(fetchbuf0_instr[0]) || rf_v[ db0.Rp ];
					lastq0 <= {1'b0,tail0};
					lastq1 <= {1'b1,tail0};
					if (!db0.pfx) begin
						atom_mask <= atom_mask >> 4'd3;
						pred_mask <= {4'hF,pred_mask} >> 4'd4;
						postfix_mask <= 'd0;
					end
					else
						postfix_mask <= {postfix_mask[4:0],1'b1};
					if (postfix_mask[5])
						rob[tail0].exc <= FLT_PFX;
					if (fnIsPred(fetchbuf0_instr[0]))
						pred_mask <= fetchbuf0_instr[0][34:7];
					iqentry_issue_reg[tail0] <= 1'b0;
				end

				else begin	// fetchbuf0 doesn't contain a backwards branch
					if (!db0.pfx)
						pred_mask <= {8'hFF,pred_mask} >> 4'd8;
			    //
			    // so -- we can enqueue 1 or 2 instructions, depending on space in the IQ
			    // update tail0/tail1 separately (at top)
			    // update the rf_v and rf_source bits separately (at end)
			    //   the problem is that if we do have two instructions, 
			    //   they may interact with each other, so we have to be
			    //   careful about where things point.
			    //

			    //
			    // enqueue the first instruction ...
			    //
					did_branchback1 <= branchback & ~did_branchback;
					for (n12 = 0; n12 < ROB_ENTRIES; n12 = n12 + 1)
						rob[n12].sn <= rob[n12].sn - 2'd1;
//						rob[n12].sn <= |rob[n12].sn ? rob[n12].sn - 2'd1 : rob[n12].sn;
					rob[tail0].sn <= 6'h3F;
					rob[tail0].owner <= Thor2025pkg::NONE;
			    rob[tail0].done <= db0.nop;
			    rob[tail0].out <= INV;
			    rob[tail0].op <= fetchbuf0_instr[0]; 
			    rob[tail0].bt <= INV;//ptakb;
			    rob[tail0].agen <= INV;
			    rob[tail0].pc <= fetchbuf0_pc;
			    rob[tail0].exc    <=   FLT_NONE;
					rob[tail0].br <= db0.br;
					rob[tail0].bts <= db0.bts;
					rob[tail0].takb <= 1'b0;
					rob[tail0].brtgt <= 'd0;
					rob[tail0].argA_v <= fnSourceAv(fetchbuf0_instr[0]) || rf_v[ db0.Ra ];
					rob[tail0].argB_v <= fnSourceBv(fetchbuf0_instr[0]) || rf_v[ db0.Rb ];
					rob[tail0].argC_v <= fnSourceCv(fetchbuf0_instr[0]) || rf_v[ db0.Rc ];
					rob[tail0].argT_v <= fnSourceTv(fetchbuf0_instr[0]) || rf_v[ db0.Rt ];
					rob[tail0].argP_v <= fnSourcePv(fetchbuf0_instr[0]) || rf_v[ db0.Rp ];
					lastq0 <= {1'b0,tail0};
					lastq1 <= {1'b1,tail0};
					if (!db0.pfx) begin
						atom_mask <= atom_mask >> 4'd3;
						pred_mask <= {4'hF,pred_mask} >> 4'd4;
						postfix_mask <= 'd0;
					end
					else
						postfix_mask <= {postfix_mask[4:0],1'b1};
					if (postfix_mask[5])
						rob[tail0].exc <= FLT_PFX;
					if (fnIsPred(fetchbuf0_instr[0]))
						pred_mask <= fetchbuf0_instr[0][34:7];
					iqentry_issue_reg[tail0] <= 1'b0;

			    //
			    // if there is room for a second instruction, enqueue it
			    //
			    if (rob_v[tail1] == INV && SUPPORT_Q2) begin

						for (n12 = 0; n12 < ROB_ENTRIES; n12 = n12 + 1)
							rob[n12].sn <= rob[n12].sn - 2'd2;
//							rob[n12].sn <= |rob[n12].sn ? rob[n12].sn - 2'd2 : rob[n12].sn;
						rob[tail0].sn <= 6'h3E;	// <- this needs be done again here
						rob[tail1].sn <= 6'h3F;
						rob[tail1].owner <= Thor2025pkg::NONE;
						rob[tail1].done <= db1.nop;
						rob[tail1].out <= INV;
						rob[tail1].res <= `ZERO;
						rob[tail1].op <= fetchbuf1_instr[0]; 
						rob[tail1].bt <= pt1;
						rob[tail1].agen <= INV;
						rob[tail1].pc <= fetchbuf1_pc;
						rob[tail1].exc <= FLT_NONE;
						rob[tail1].br <= db1.br;
						rob[tail1].bts <= db1.bts;
						rob[tail1].takb <= 1'b0;
						rob[tail1].brtgt <= 'd0;
						lastq1 <= {1'b0,tail1};
						if (!db1.pfx) begin
							atom_mask <= atom_mask >> 4'd6;
							pred_mask <= {8'hFF,pred_mask} >> 4'd8;
							postfix_mask <= 'd0;
						end
						else if (!db0.pfx) begin
							postfix_mask <= 'd0;
						end
						else
							postfix_mask <= {postfix_mask[4:0],1'b1};
						if (postfix_mask[5])
							rob[tail1].exc <= FLT_PFX;
						if (fnIsPred(fetchbuf1_instr[0]))
							pred_mask <= fetchbuf1_instr[0][34:7];
						iqentry_issue_reg[tail1] <= 1'b0;

						// If the first instruction targets a register of the second, then
						// the register for the second instruction should be marked invalid.

						// if the argument is an immediate or not needed, we're done
						if (fnSourceAv(fetchbuf1_instr[0]))
					    rob[tail1].argA_v <= VAL;
						// otherwise, if previous instruction does write to RF ... see if overlap
						else if (db0.Rt != 'd0 && db1.Ra == db0.Rt)
					    rob[tail1].argA_v <= INV;
						// if no overlap, get info from rf_v and rf_source
						else
					    rob[tail1].argA_v <= rf_v [ db1.Ra ];

						// if the argument is an immediate or not needed, we're done
						if (fnSourceBv(fetchbuf1_instr[0]))
					    rob[tail1].argB_v <= VAL;
						// otherwise, if previous instruction does write to RF ... see if overlap
						else if (db0.Rt0 != 'd0 && db1.Rb == db0.Rt)
					    rob[tail1].argB_v <= INV;
						end
						// if no overlap, get info from rf_v and rf_source
						else
					    rob[tail1].argB_v <= rf_v [ db1.Rb ];

						//
						// SOURCE 3 ... 
						//
						// if the argument is an immediate or not needed, we're done
						if (fnSourceCv(fetchbuf1_instr[0]))
					    rob[tail1].argC_v <= VAL;
						// otherwise, previous instruction does write to RF ... see if overlap
						else if (db0.Rt != 'd0 && db1.Rc == db0.Rt)
					    rob[tail1].argC_v <= INV;
						// if no overlap, get info from rf_v and rf_source
						else
					    rob[tail1].argC_v <= rf_v [ db1.Rc ];

						//
						// SOURCE T ... 
						//
						// if the argument is an immediate or not needed, we're done
						if (fnSourceTv(fetchbuf1_instr[0]))
					    rob[tail1].argT_v <= VAL;
						// otherwise, if previous instruction does write to RF ... see if overlap
						else if (db0.Rt != 'd0 && db1.Rt == db0.Rt)
					    rob[tail1].argT_v <= INV;
						// if no overlap, get info from rf_v and rf_source
						else
					    rob[tail1].argT_v <= rf_v [ db1.Rt ];

						//
						// SOURCE P ... 
						//
						// if the argument is an immediate or not needed, we're done
						if (fnSourcePv(fetchbuf1_instr[0]))
					    rob[tail1].argP_v <= VAL;
						// otherwise, previous instruction does write to RF ... see if overlap
						else if (db0.Rt != 'd0 && db1.Rp == db0.Rt)
					    rob[tail1].argP_v <= INV;
						// if no overlap, get info from rf_v and rf_source
						else
					    rob[tail1].argP_v <= rf_v [ db1.Rp ];
					end	
	    	end// ends the "else fetchbuf0 doesn't have a backwards branch" clause
	    end
		endcase
*/

task tEnque;
input [2:0] qcnt;
input decode_bus_t db;
input pc_address_t pc;
input [255:0] ins;
input pt;
input rob_ndx_t tail;
begin
	if (rob_v[tail] == INV) begin
		did_branchback1 <= branchback & ~did_branchback;
		for (n12 = 0; n12 < ROB_ENTRIES; n12 = n12 + 1)
			rob[n12].sn <= rob[n12].sn - qcnt;
//					rob[n12].sn <= |rob[n12].sn ? rob[n12].sn - 2'd1 : rob[n12].sn;
		rob[tail].sn <= 6'h3F;
		if (qcnt > 1) begin
			rob[(tail-1) % ROB_ENTRIES] <= 6'h3E;
			if (qcnt > 2) begin
				rob[(tail-2) % ROB_ENTRIES] <= 6'h3D;
				if (qcnt > 3)
					rob[(tail-3) % ROB_ENTRIES] <= 6'h3C;
			end
		end
		rob[tail].owner <= QuplsPkg::NONE;
		rob[tail].done <= db.nop;
		rob[tail].out <= INV;
		rob[tail].op <= ins;
		rob[tail].bt <= pt;
		rob[tail].agen <= INV;
		rob[tail].pc <= pc;
		rob[tail].decbus <= db;
		rob[tail].exc <= FLT_NONE;
		rob[tail].takb <= 1'b0;
		rob[tail].brtgt <= 'd0;
		rob[tail].argA_v <= fnSourceAv(ins) || rf_v[ db.Ra ];
		rob[tail].argB_v <= fnSourceBv(ins) || rf_v[ db.Rb ];
		rob[tail].argC_v <= fnSourceCv(ins) || rf_v[ db.Rc ];
		rob[tail].argT_v <= fnSourceTv(ins) || rf_v[ db.Rt ];
		/*
		if (!db.pfx) begin
			atom_mask <= atom_mask >> 4'd3;
			pred_mask <= {4'hF,pred_mask} >> 4'd4;
			postfix_mask <= 'd0;
		end
		else
			postfix_mask <= {postfix_mask[4:0],1'b1};
		if (postfix_mask[5])
			rob[tail0].exc <= FLT_PFX;
		iqentry_issue_reg[tail0] <= 1'b0;
		*/
	end
end
endtask

endmodule
