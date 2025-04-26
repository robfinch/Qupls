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
	id, om, we, argA, argB, argBr, argC, argI, instr, bt, brclass, cjb, bl,
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
output pc_address_ex_t pc;
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
output Stark_pkg::brclass_t brclass;
output reg cjb;
output reg bl;
output Stark_pkg::pipeline_reg_t op;
output checkpt_ndx_t cp;
output reg excv;
output reg idle_o;
output pregno_t pRt;
output aregno_t aRt;

reg [2:0] valid;
wire [2:0] valid_o;

always_comb
	all_args_valid = &valid;

Stark_pkg::pipeline_reg_t nopi;

Stark_validate_Rn uvRs1
(
	.prn(prn),
	.prnv(prnv),
	.rfo(rfo),
	.rfo_tag(rfo_tag),
	.pRn(rob.op.pRs1),
	.val(argA),
	.val_tag(argA_tag),
	.valid_i(valid[0]),
	.valid_o(valid_o[0])
);

Stark_validate_Rn uvRs2
(
	.prn(prn),
	.prnv(prnv),
	.rfo(rfo),
	.rfo_tag(rfo_tag),
	.pRn(rob.op.pRs2),
	.val(argB),
	.val_tag(argB_tag),
	.valid_i(valid[1]),
	.valid_o(valid_o[1])
);

Stark_validate_Rn uvRs3
(
	.prn(prn),
	.prnv(prnv),
	.rfo(rfo),
	.rfo_tag(rfo_tag),
	.pRn(rob.op.pRs3),
	.val(argC),
	.val_tag(argC_tag),
	.valid_i(valid[2]),
	.valid_o(valid_o[2])
);

// Define a NOP instruction.
always_comb
begin
	nopi = {$bits(Stark_pkg::pipeline_reg_t){1'b0}};
	nopi.pc = RSTPC;
	nopi.pc.bno_t = 6'd1;
	nopi.pc.bno_f = 6'd1;
	nopi.mcip = 12'h1A0;
	nopi.uop.count = 3'd1;
	nopi.uop.ins = {26'd0,OP_NOP};
	nopi.decbus.Rdz = 1'b1;
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
	brclass <= Stark_pkg::BRC_NONE;
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
		pc <= rob.op.pc;
		bt <= rob.bt;
		brclass <= rob.op.decbus.brclass;
		cjb <= rob.decbus.cjb;
		bl <= rob.decbus.bl;
		cp <= rob.cndx;
		excv <= rob.excv;
	end
	valid <= valid_o;
end

endmodule
