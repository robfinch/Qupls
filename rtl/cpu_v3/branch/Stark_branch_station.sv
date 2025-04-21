// ============================================================================
//        __
//   \\__/ o\    (C) 2025  Robert Finch, Waterloo
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
// 1550 LUTs / 800 FFs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Stark_pkg::*;

module Stark_branch_station(rst, clk, idle_i, issue, rndx, rndxv, rob,
	rfo, rfo_tag, prn, prnv, all_args_valid, rfo_argC_tag,
	id, om, we, argA, argB, argBr, argC, argI, instr, bt, bts, cjb, bl,
	pc, op, bs_idle_oh, argA_tag, argB_tag, argC_tag, pRt, aRt,
	cp, excv, idle_o
);
input rst;
input clk;
input idle_i;
input issue;
input rob_ndx_t rndx;
input rndxv;
input Stark_pkg::rob_entry_t rob;
input value_t [15:0] rfo;
input [15:0] rfo_tag;
input pregno_t [15:0] prn;
input [15:0] prnv;
input pc_address_ex_t pc;
input bs_idle_oh;
input rfo_argC_tag;

output rob_ndx_t id;
output Stark_pkg::operating_mode_t om;
output reg we;
output address_t argA;
output address_t argB;
output address_t argBr;
output value_t argC;
output reg argA_tag;
output reg argB_tag;
output reg argC_tag;
output value_t argI;
output Stark_pkg::ex_instruction_t instr;
output reg all_args_valid;
output reg bt;
output Stark_pkg::bts_t bts;
output reg cjb;
output reg bl;
output Stark_pkg::pipeline_reg_t op;
output checkpt_ndx_t cp;
output reg excv;
output reg idle_o;
output pregno_t pRt;
output aregno_t aRt;

reg [2:0] valid;
always_comb
	all_args_valid = &valid;

Stark_pkg::pipeline_reg_t nopi;

// Define a NOP instruction.
always_comb
begin
	nopi = {$bits(Stark_pkg::pipeline_reg_t){1'b0}};
	nopi.pc = RSTPC;
	nopi.pc.bno_t = 6'd1;
	nopi.pc.bno_f = 6'd1;
	nopi.mcip = 12'h1A0;
	nopi.ins = {26'd0,OP_NOP};
	nopi.pred_btst = 6'd0;
	nopi.decbus.Rtz = 1'b1;
	nopi.decbus.nop = 1'b1;
	nopi.decbus.alu = 1'b1;
end

always_ff @(posedge clk)
if (rst) begin
	id <= 5'd0;
	argA <= {$bits(address_t){1'b0}};
	argB <= {$bits(address_t){1'b0}};
	argBr <= {$bits(address_t){1'b0}};
	argC <= {$bits(value_t){1'b0}};
	argI <= {$bits(address_t){1'b0}};
	instr <= nopi;
	pc.pc <= Stark_pkg::RSTPC;
	pc.bno_t <= 6'd1;
	pc.bno_f <= 6'd1;
	bt <= FALSE;
	bts <= Stark_pkg::BTS_NONE;
	cjb <= 1'b0;
	bl <= 1'b0;
	op <= {26'd0,OP_NOP};
	cp <= 4'd0;
	excv <= 1'b0;	
	idle_o <= 1'b0;
	valid <= 3'h0;
end
else begin
	idle_o <= idle_i;
	if (issue && rndxv && idle_i && bs_idle_oh) begin
		valid <= 4'd0;
		id <= rndx;
		om <= rob.om;
		we <= rob.op.decbus.store;
		argC_tag <= rfo_argC_tag;
		argI <= address_t'(rob.op.decbus.immb);
		pRt <= rob.op.nRd;
		aRt <= rob.op.decbus.Rd;
		instr <= rob.op;
		pc <= rob.pc;
		bt <= rob.bt;
		bts <= rob.op.decbus.bts;
		cjb <= rob.decbus.cjb;
		bl <= rob.decbus.bl;
		cp <= rob.cndx;
		excv <= rob.excv;
	end
	tValidate(rob.op.pRs1,argA,argA_tag,valid[0],valid[0]);
	if (rob.op.pRs1==8'd0) begin
		argA <= value_zero;
		valid[0] <= 1'b1;
	end
	tValidate(rob.op.pRs2,argB,argB_tag,valid[1],valid[1]);
	if (rob.op.pRs2==8'd0) begin
		argB <= value_zero;
		valid[1] <= 1'b1;
	end
	tValidate(rob.op.pRs3,argC,argC_tag,valid[2],valid[2]);
	if (rob.op.pRs3==8'd0) begin
		argC <= value_zero;
		valid[2] <= 1'b1;
	end
end

task tValidate;
input pregno_t pRn;
output value_t val;
output val_tag;
input valid_i;
output valid_o;
integer nn;
begin
	valid_o = valid_i;
	for (nn = 0; nn < 16; nn = nn + 1) begin
		if (pRn==prn[nn] && prnv[nn] && !valid_i) begin
			val = rfo[nn];
			val_tag = rfo_tag[nn];
			valid_o = 1'b1;
		end
	end
end
endtask

endmodule
