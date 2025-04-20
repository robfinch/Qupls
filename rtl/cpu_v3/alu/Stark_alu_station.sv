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
	argA, argB, argBI, argC, argI, argT, argCi, pc_o,
	argCi_tag, argA_tag, argB_tag, argC_tag, argT_tag,
	cpytgt,
	cs, aRtz, aRt, nRt, om, bank, instr, div, cap, cptgt, cp,
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
output value_t argCi;
output value_t argA;
output value_t argB;
output value_t argBI;
output value_t argC;
output value_t argI;
output value_t argT;
output pc_address_t pc_o;
output reg all_args_valid;
output reg argCi_tag;
output reg argA_tag;
output reg argB_tag;
output reg argC_tag;
output reg argT_tag;
output reg cs;
output reg aRtz;
output aregno_t aRt;
output pregno_t nRt;
output Stark_pkg::operating_mode_t om;
output reg bank;
output Stark_pkg::pipeline_reg_t instr;
output reg div;
output reg cap;
output reg [7:0] cptgt;
output checkpt_ndx_t cp;
output reg pred;
output reg predz;
output memsz_t prc;
output reg sc_done;
output reg idle_false;

integer nn;
reg [4:0] valid;
reg [7:0] next_cptgt;
always_comb
	next_cptgt <= {8{cpytgt|rob.decbus.cpytgt}} | ~rob.pred_bits;

always_comb
	all_args_valid = &valid;

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
	argCi <= value_zero;
	argCi_tag = 1'b0;
	argA_tag = 1'b0;
	argB_tag = 1'b0;
	argC_tag = 1'b0;
	argT_tag = 1'b0;
	cs <= 1'b0;
	nRt <= 11'd0;
	bank <= 1'b0;
	aRt <= 9'd0;
	aRtz <= TRUE;
	instr <= {41'd0,OP_NOP};
	div <= 1'b0;
	cptgt <= 8'h00;
	pc_o <= RSTPC;
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
		nRt <= rob.op.nRd;
		aRt <= rob.op.decbus.Rd;
		aRtz <= rob.op.decbus.Rd==8'd00;//rob.decbus.Rtz; <- this did not work
		om <= rob.om;
//		pred <= rob.op.decbus.pred;
//		predz <= rob.op.decbus.pred ? rob.op.decbus.predz : 1'b0;
		div <= rob.op.decbus.div;
//		cap <= rob.op.decbus.cap;
		cptgt <= next_cptgt;
		if (cpytgt|rob.op.decbus.cpytgt) begin
			instr.ins <= {26'd0,OP_NOP};
//			pred <= FALSE;
//			predz <= rob.op.decbus.cpytgt ? FALSE : rob.decbus.predz;
			div <= FALSE;
		end
		else
			instr <= rob.op;
		pc_o <= rob.op.pc.pc;
		cp <= rob.cndx;
		// Done even if multi-cycle if it is just a copy-target.
		if (!rob.op.decbus.multicycle || (&next_cptgt))
			sc_done <= TRUE;
		else
			idle_false <= TRUE;
	end
	tValidate(rob.op.pRci,argCi,argCi_tag,valid[0],valid[0]);
	if (rob.op.pRci==8'd0) begin
		argCi <= value_zero;
		argCi_tag <= 1'b0;
		valid[0] <= 1'b1;
	end
	tValidate(rob.op.pRs1,argA,argA_tag,valid[1],valid[1]);
	if (rob.op.pRs1==8'd0) begin
		argA <= value_zero;
		argA_tag <= 1'b0;
		valid[1] <= 1'b1;
	end
	tValidate(rob.op.pRs2,argB,argB_tag,valid[2],valid[2]);
	if (rob.op.pRs2==8'd0) begin
		argB <= value_zero;
		argB_tag <= 1'b0;
		valid[2] <= 1'b1;
	end
	tValidate(rob.op.pRs3,argC,argC_tag,valid[3],valid[3]);
	if (rob.op.pRs3==8'd0) begin
		argC <= value_zero;
		argC_tag <= 1'b0;
		valid[3] <= 1'b1;
	end
	tValidate(rob.op.pRd,argT,argT_tag,valid[4],valid[4]);
	if (rob.op.pRd==8'd0) begin
		argT <= value_zero;
		argT_tag <= 1'b0;
		valid[4] <= 1'b1;
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
