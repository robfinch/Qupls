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
// 3000 LUTs / 1000 FFs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Stark_pkg::*;

module Stark_alu_station(rst, clk, available, idle, issue, rndx, rndxv, rob,
	rfo_tag, ld, id, 
	argA, argB, argBI, argC, argI, argD, pc_o,
	argA_tag, argB_tag, argC_tag, argD_tag,
	cpytgt,
	cs, aRdz, aRd, nRd, aRd2, aRd2z, nRd2, aRd3, aRd3z, nRd3, om, bank, instr, div, cap, cptgt, cp, pc,
	pred, predz, prc, sc_done, idle_false,
	prn, prnv, rfo, all_args_valid
);
input rst;
input clk;
input available;
input idle;
input issue;
input rob_ndx_t rndx;
input rndxv;
input Stark_pkg::rob_entry_t rob;
input pregno_t [15:0] prn;
input [15:0] prnv;
input value_t [15:0] rfo;
input [15:0] rfo_tag;
input cpytgt;
output reg ld;
output rob_ndx_t id;
output value_t argA;
output value_t argB;
output value_t argBI;
output value_t argC;
output value_t argI;
output value_t argD;
output pc_address_t pc_o;
output reg all_args_valid;
output reg argA_tag;
output reg argB_tag;
output reg argC_tag;
output reg argD_tag;
output reg cs;
output reg aRdz;
output reg aRd2z;
output reg aRd3z;
output aregno_t aRd;
output pregno_t nRd;
output aregno_t aRd2;
output pregno_t nRd2;
output aregno_t aRd3;
output pregno_t nRd3;
output Stark_pkg::operating_mode_t om;
output reg bank;
output Stark_pkg::pipeline_reg_t instr;
output reg div;
output reg cap;
output reg [7:0] cptgt;
output checkpt_ndx_t cp;
output cpu_types_pkg::pc_address_t pc;
output reg pred;
output reg predz;
output memsz_t prc;
output reg sc_done;
output reg idle_false;

integer nn;
reg [3:0] valid;
wire [3:0] valid_o;
reg [7:0] next_cptgt;
always_comb
	next_cptgt <= {8{cpytgt|rob.decbus.cpytgt}} | ~{8{rob.pred_bit}};

always_comb
	all_args_valid = &valid;

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

always_comb
	argBI <= rob.op.decbus.immb | argB;

always_ff @(posedge clk)
if (rst) begin
	ld <= 1'd0;
	id <= 5'd0;
	argA <= value_zero;
	argB <= value_zero;
	argBI <= value_zero;
	argC <= value_zero;
	argI <= value_zero;
	argD <= value_zero;
	argA_tag = 1'b0;
	argB_tag = 1'b0;
	argC_tag = 1'b0;
	argD_tag = 1'b0;
	cs <= 1'b0;
	nRd <= 9'd0;
	nRd2 <= 9'd0;
	nRd3 <= 9'd0;
	bank <= 1'b0;
	aRd <= 9'd0;
	aRdz <= TRUE;
	aRd2z <= TRUE;
	aRd3 <= 9'd0;
	aRd3z <= TRUE;
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
	valid <= 5'd0;
end
else begin
	ld <= 1'd0;
	sc_done <= FALSE;
	idle_false <= FALSE;
	if (available && issue && rndxv && idle) begin
		valid <= 5'd0;
		ld <= 1'd1;
		id <= rndx;
		// Could bypass all the register args to improve performance as
		// follows:
		/*			
		if (PERFORMANCE && wrport0_v && wrport0_Rt==rob.op.pRa)
			argA <= wrport0_res;
		else
			argA <= rfo_argA;
		*/
		argI <= rob.op.decbus.has_immb ? rob.op.decbus.immb : rob.op.decbus.immc;
		nRd <= rob.op.nRd;
		nRd2 <= rob.op.nRd2;
		nRd3 <= rob.op.nRco;
		aRd <= rob.op.decbus.Rd;
		aRdz <= rob.op.decbus.Rd==8'd00;//rob.decbus.Rtz; <- this did not work
		aRd2 <= rob.op.decbus.Rd2;
		aRd2z <= rob.op.decbus.Rd2==8'd00;//rob.decbus.Rtz; <- this did not work
		aRd3 <= rob.op.decbus.Rco;
		aRd3z <= rob.op.decbus.Rco==9'd0;
		om <= rob.om;
//		pred <= rob.op.decbus.pred;
//		predz <= rob.op.decbus.pred ? rob.op.decbus.predz : 1'b0;
		div <= rob.op.decbus.div;
//		cap <= rob.op.decbus.cap;
		cptgt <= next_cptgt;
		if (cpytgt|rob.op.decbus.cpytgt) begin
			instr.uop.ins <= {26'd0,OP_NOP};
//			pred <= FALSE;
//			predz <= rob.op.decbus.cpytgt ? FALSE : rob.decbus.predz;
			div <= FALSE;
		end
		else
			instr <= rob.op;
		pc <= rob.op.pc.pc;
		cp <= rob.cndx;
		// Done even if multi-cycle if it is just a copy-target.
		if (!rob.op.decbus.multicycle || (&next_cptgt))
			sc_done <= TRUE;
		else
			idle_false <= TRUE;
	end
	valid <= valid_o;
end

endmodule
