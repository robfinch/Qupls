// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2024  Robert Finch, Waterloo
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
// LUTs / FFs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import QuplsPkg::*;

module Qupls_fpu_station(rst, clk, id, argA, argB, argC, argT, argM, argI,
	Rt, Rt1, aRt, aRtz, aRt1, aRtz1, argA_tag, argB_tag, cs, bank,
	instr, pc, cp, qfext, cptgt,
	available, rndx, rndxv, idle, rfo_argA, rfo_argB, rfo_argC, rfo_argT,
	rfo_argM, rfo_argA_ctag, rfo_argB_ctag, rob, sc_done);
input rst;
input clk;
output rob_ndx_t id;
output value_t argA;
output value_t argB;
output value_t argC;
output value_t argT;
output value_t argM;
output value_t argI;
output pregno_t Rt;
output pregno_t Rt1;
output aregno_t aRt;
output reg aRtz;
output aregno_t aRt1;
output reg aRtz1;
output reg argA_tag;
output reg argB_tag;
output reg cs;
output reg bank;
output instruction_t instr;
output pc_address_t pc;
output checkpt_ndx_t cp;
output reg qfext;
output reg [7:0] cptgt;
input available;
input rob_ndx_t rndx;
input rndxv;
input idle;
input value_t rfo_argA;
input value_t rfo_argB;
input value_t rfo_argC;
input value_t rfo_argT;
input value_t rfo_argM;
input rfo_argA_ctag;
input rfo_argB_ctag;
input rob_entry_t rob;
output reg sc_done;

// For a vector instruction we got the entire mask register, only the bits
// relevant to the current element are needed. So, they are extracted.
reg [7:0] next_cptgt;
always_comb
	if (rob.decbus.vec)
		next_cptgt <= {8{rob.decbus.cpytgt}} | ~(rfo_argM >> {rob.decbus.Ra[2:0],3'h0});
	else
		next_cptgt <= {8{rob.decbus.cpytgt}};
		

always_ff @(posedge clk)
if (rst) begin
	id <= 5'd0;
	argA <= value_zero;
	argB <= value_zero;
	argC <= value_zero;
	argT <= value_zero;
	argM <= value_zero;
	argI <= value_zero;
	Rt <= 11'd0;
	Rt1 <= 11'd0;
	aRt <= 7'd0;
	aRtz <= TRUE;
	aRt1 <= 7'd0;
	aRtz1 <= TRUE;
	argA_tag <= 1'b0;
	argB_tag <= 1'b0;
	cs <= 1'b0;
	bank <= 1'b0;
	instr <= {41'd0,OP_NOP};
	pc <= RSTPC;
	cp <= 4'd0;
	qfext <= FALSE;
	cptgt <= 16'h0;
	sc_done <= FALSE;
end
else begin
	sc_done <= FALSE;
	if (available && rndxv && idle) begin
		id <= rndx;
		argA <= rfo_argA;
		argB <= rfo_argB;
		argC <= rfo_argC;
		argT <= rfo_argT;
		argM <= rfo_argM;
		argA_tag <= rfo_argA_ctag;
		argB_tag <= rfo_argB_ctag;
		if (rob.decbus.qfext) begin
			qfext <= TRUE;
			Rt1 <= rob.nRt;
			aRt1 <= rob.decbus.Rt;
			aRtz1 <= rob.decbus.Rtz;
		end
		else begin
			qfext <= FALSE;
		end
		cptgt <= next_cptgt;
		argI <= rob.decbus.immb;
		Rt <= rob.nRt;
		aRt <= rob.decbus.Rt;
		aRtz <= rob.decbus.Rtz;
		cs <= rob.decbus.Rcc;
		bank <= rob.om==2'd0 ? 1'b0 : 1'b1;
		instr <= rob.op;
		pc <= rob.pc;
		cp <= rob.cndx;
		if (!rob.decbus.multicycle || (&next_cptgt))
			sc_done <= TRUE;
	end
end

endmodule
