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
// 2400 LUTs / 420 FFs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Stark_pkg::*;

module Stark_fpu_station(rst, clk, id, argA, argB, argC, argD, argI,
	Rt, Rt1, aRt, aRtz, aRt1, aRtz1, om,
	argA_tag, argB_tag, argC_tag, argD_tag, cs, bank,
	instr, pc, cp, qfext, cptgt, all_args_valid,
	available, rndx, rndxv, idle, prn, prnv, rfo,
	rfo_tag, rob, sc_done);
input rst;
input clk;
output rob_ndx_t id;
output value_t argA;
output value_t argB;
output value_t argC;
output value_t argD;
output value_t argI;
output pregno_t Rt;
output pregno_t Rt1;
output aregno_t aRt;
output reg aRtz;
output aregno_t aRt1;
output reg aRtz1;
output reg argA_tag;
output reg argB_tag;
output reg argC_tag;
output reg argD_tag;
output reg cs;
output reg bank;
output instruction_t instr;
output pc_address_ex_t pc;
output checkpt_ndx_t cp;
output reg qfext;
output reg [7:0] cptgt;
output reg all_args_valid;
output Stark_pkg::operating_mode_t om;
input available;
input rob_ndx_t rndx;
input rndxv;
input idle;
input pregno_t [15:0] prn;
input [15:0] prnv;
input value_t [15:0] rfo;
input [15:0] rfo_tag;
input Stark_pkg::rob_entry_t rob;
output reg sc_done;

integer nn;
reg [3:0] valid;
wire [3:0] valid_o;

always_comb
	all_args_valid = &valid;


// For a vector instruction we got the entire mask register, only the bits
// relevant to the current element are needed. So, they are extracted.
reg [7:0] next_cptgt;
always_comb
	next_cptgt <= {8{rob.op.decbus.cpytgt}};
		
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

Stark_validate_Rn uvRd
(
	.prn(prn),
	.prnv(prnv),
	.rfo(rfo),
	.rfo_tag(rfo_tag),
	.pRn(rob.op.pRd),
	.val(argD),
	.val_tag(argD_tag),
	.valid_i(valid[3]),
	.valid_o(valid_o[3])
);

always_ff @(posedge clk)
if (rst) begin
	id <= 5'd0;
	argA <= value_zero;
	argB <= value_zero;
	argC <= value_zero;
	argD <= value_zero;
	argI <= value_zero;
	Rt <= 11'd0;
	Rt1 <= 11'd0;
	aRt <= 7'd0;
	aRtz <= TRUE;
	aRt1 <= 7'd0;
	aRtz1 <= TRUE;
	argA_tag <= 1'b0;
	argB_tag <= 1'b0;
	argC_tag <= 1'b0;
	argD_tag <= 1'b0;
	cs <= 1'b0;
	bank <= 1'b0;
	instr <= {26'd0,OP_NOP};
	pc <= RSTPC;
	pc.bno_t <= 6'd1;
	pc.bno_f <= 6'd1;
	cp <= 4'd0;
	qfext <= FALSE;
	cptgt <= 16'h0;
	sc_done <= FALSE;
	valid <= 4'd0;
	om <= Stark_pkg::OM_SECURE;
end
else begin
	sc_done <= FALSE;
	if (available && rndxv && idle) begin
		valid <= 4'd0;
		id <= rndx;
		if (rob.op.decbus.qfext) begin
			qfext <= TRUE;
			Rt1 <= rob.op.nRd;
			aRt1 <= rob.op.decbus.Rd;
			aRtz1 <= rob.op.decbus.Rdz;
		end
		else begin
			qfext <= FALSE;
		end
		cptgt <= next_cptgt;
		argI <= rob.op.decbus.immb;
		Rt <= rob.op.nRd;
		aRt <= rob.op.decbus.Rd;
		aRtz <= rob.op.decbus.Rd==8'd0;//rob.decbus.Rtz;
		if (rob.op.decbus.cpytgt) begin
			instr <= {26'd0,OP_NOP};
//			pred <= FALSE;
//			predz <= rob.decbus.cpytgt ? FALSE : rob.decbus.predz;
		end
		else
			instr <= rob.op.uop.ins;
		om <= rob.op.om;
		pc <= rob.op.pc;
		cp <= rob.cndx;
		if (!rob.op.decbus.multicycle || (&next_cptgt) || rob.op.decbus.cpytgt)
			sc_done <= TRUE;
	end
	valid <= valid_o;
end

endmodule
