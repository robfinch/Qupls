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
// 1350 LUTs / 1200 FFs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import QuplsPkg::*;

module Qupls_alu_station(rst, clk, available, idle, issue, rndx, rndxv, rob,
	rfo_argA, rfo_argB, rfo_argC, rfo_argT, rfo_argM, rfo_argA_ctag, rfo_argB_ctag,
	vrm, vex, ld, id, 
	argA, argB, argBI, argC, argI, argT, argM, argA_ctag, argB_ctag, cpytgt,
	cs, aRtz, aRt, nRt, bank, instr, div, cap, cptgt, pc, cp,
	pred, predz, prc, sc_done, idle_false
);
input rst;
input clk;
input available;
input idle;
input issue;
input rob_ndx_t rndx;
input rndxv;
input rob_entry_t rob;
input value_t rfo_argA;
input value_t rfo_argB;
input value_t rfo_argC;
input value_t rfo_argT;
input value_t rfo_argM;
input rfo_argA_ctag;
input rfo_argB_ctag;
input cpytgt;
input value_t vrm [0:3];						// vector restart mask
input value_t vex [0:3];						// vector exception
output reg ld;
output rob_ndx_t id;
output value_t argA;
output value_t argB;
output value_t argBI;
output value_t argC;
output value_t argI;
output value_t argT;
output value_t argM;
output reg argA_ctag;
output reg argB_ctag;
output reg cs;
output reg aRtz;
output aregno_t aRt;
output pregno_t nRt;
output reg bank;
output ex_instruction_t instr;
output reg div;
output reg cap;
output reg [7:0] cptgt;
output pc_address_t pc;
output checkpt_ndx_t cp;
output reg pred;
output reg predz;
output memsz_t prc;
output reg sc_done;
output reg idle_false;

// For a vector instruction we got the entire mask register, only the bits
// relevant to the current element are needed. So, they are extracted.
reg [7:0] next_cptgt;
always_comb
	if (rob.decbus.vec)
		next_cptgt <= {8{cpytgt|rob.decbus.cpytgt}} | ~(rfo_argM >> {rob.decbus.Ra[2:0],3'h0});
	else
		next_cptgt <= {8{cpytgt|rob.decbus.cpytgt}} | ~rob.pred_bits;

always_ff @(posedge clk)
if (rst) begin
	ld <= 1'd0;
	id <= 5'd0;
	argA <= value_zero;
	argB <= value_zero;
	argBI <= value_zero;
	argC <= value_zero;
	argI <= value_zero;
	argT <= value_zero;
	argM <= value_zero;
	argA_ctag = 1'b0;
	argB_ctag = 1'b0;
	cs <= 1'b0;
	nRt <= 11'd0;
	bank <= 1'b0;
	aRt <= 9'd0;
	aRtz <= TRUE;
	instr <= {41'd0,OP_NOP};
	div <= 1'b0;
	cptgt <= 8'h00;
	pc <= RSTPC;
	cp <= 4'd0;
	pred <= FALSE;
	predz <= FALSE;
	prc <= QuplsPkg::octa;
	sc_done <= FALSE;
	idle_false <= FALSE;
end
else begin
	ld <= 1'd0;
	sc_done <= FALSE;
	idle_false <= FALSE;
	if (available && issue && rndxv && idle) begin
		ld <= 1'd1;
		id <= rndx;
		if (rob.decbus.mvvr)
			case(rob.op.aRt)
			9'd54: argA <= vrm[rob.vn];
			9'd55: argA <= vex[rob.vn];
			default:	argA <= {2{32'hDEADBEEF}};
			endcase
		else
			case({rob.decbus.bitwise,rob.decbus.Ran})
			2'd0:	argA <= rfo_argA;
			2'd1:	argA <= -rfo_argA;
			2'd2:	argA <= rfo_argA;
			2'd3:	argA <= ~rfo_argA;
			endcase
		case({rob.decbus.bitwise,rob.decbus.Rbn})
		2'd0:	argB <= rfo_argB;
		2'd1:	argB <= -rfo_argB;
		2'd2:	argB <= rfo_argB;
		2'd3:	argB <= ~rfo_argB;
		endcase
		argBI <= rob.decbus.immb | rfo_argB;
		case({rob.decbus.bitwise,rob.decbus.Rcn})
		2'd0:	argC <= rfo_argC;
		2'd1:	argC <= -rfo_argC;
		2'd2:	argC <= rfo_argC;
		2'd3:	argC <= ~rfo_argC;
		endcase
		argT <= rfo_argT;
		argM <= rfo_argM;
		argI	<= rob.decbus.immb;
		argA_ctag <= rfo_argA_ctag;
		argB_ctag <= rfo_argB_ctag;
		cs <= rob.decbus.Rcc;
		nRt <= rob.nRt;
		aRt <= rob.decbus.Rt;
		aRtz <= rob.decbus.Rtz;
		pred <= rob.decbus.pred;
		predz <= rob.decbus.predz;
		div <= rob.decbus.div;
		cap <= rob.decbus.cap;
		cptgt <= next_cptgt;
		prc <= rob.decbus.prc;
		if (cpytgt|rob.decbus.cpytgt) begin
			instr.ins <= {41'd0,OP_NOP};
			pred <= FALSE;
			predz <= rob.decbus.cpytgt ? FALSE : rob.decbus.predz;
			div <= FALSE;
		end
		else
			instr <= rob.op;
		pc <= rob.pc;
		cp <= rob.cndx;
		// Done even if multi-cycle if it is just a copy-target.
		if (!rob.decbus.multicycle || (&next_cptgt))
			sc_done <= TRUE;
		else
			idle_false <= TRUE;
	end
end

endmodule
