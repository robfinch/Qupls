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

module Stark_sau_station(rst, clk, available, idle, issue, stall, rndx, rndxv, rob,
	rfo_tag, ld, id, 
	argA, argB, argBI, argC, argI, argD, pc_o,
	argA_tag, argB_tag, argC_tag, argD_tag,
	cpytgt, rfi_val, rfi_tag, rfi_pRd,
	cs, aRdz, aRd, nRd, om, bank, instr, div, cap, cptgt, cp, pc,
	pred, predz, prc, sc_done, idle_false,
	prn, prnv, rfo, all_args_valid
);
parameter NRSE = 3;
parameter FUNCUNIT = 4'd0;
input rst;
input clk;
input available;
output reg busy;
input dispatch;
input stall;
output reg issue;
input reservation_station_entry_t [3:0] rse_i;
input pregno_t [15:0] prn;
input [15:0] prnv;
input value_t [15:0] rfo;
input [15:0] rfo_tag;
input [3:0] rfi_val;
input pregno_t [3:0] rfi_pRd;
input [3:0] rfi_tag;
input cpytgt;
input reservation_station_entry_t rse_o;
output rob_ndx_t id;
output value_t argBI;
output value_t argI;
output pc_address_t pc_o;
output reg all_args_valid;
output reg argA_tag;
output reg argB_tag;
output reg argC_tag;
output reg argD_tag;
output reg cs;
output reg aRdz;
output aregno_t aRd;
output pregno_t nRd;
output Stark_pkg::operating_mode_t om;
output reg bank;
output Stark_pkg::pipeline_reg_t instr;
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
reg idle;
reg [3:0] valid;
wire [3:0] valid_o;
reg [7:0] next_cptgt;
wire [16:0] lfsro;
reservation_station_entry_t [2:0] rse;
reservation_station_entry_t rsei;
always_comb
	busy = rse[0].busy & rse[1].busy & rse[2].busy;
always_comb
	idle = !busy;

always_comb
	next_cptgt <= {8{cpytgt|rob.decbus.cpytgt}} | ~{8{rob.pred_bit}};

always_comb
	all_args_valid = &valid;

lfsr17 ulfsr1
(
	.rst(rst),
	.clk(clk),
	.ce(1'b1), 
	.cyc(1'b0),
	.o(lfsro)
);

Stark_validate_operand uvsrcA
(
	.prn(prn),
	.prnv(prnv),
	.rfo(rfo),
	.rfo_tag(rfo_tag),
	.val0(argA0),
	.val1(argA1),
	.val2(argA2),
	.val0_tag(argA0_tag),
	.val1_tag(argA1_tag),
	.val2_tag(argA2_tag),
	.rfi(rfi),
	.rfi_tag(rfi_tag),
	.rfi_pRd(rfi_pRd),
	.pRn0(pregno_t'(rse[0].argA[8:0])),
	.pRn1(pregno_t'(rse[1].argA[8:0])),
	.pRn2(pregno_t'(rse[2].argA[8:0])),
	.valid0_i(rse[0].argA_v),
	.valid1_i(rse[1].argA_v),
	.valid2_i(rse[2].argA_v),
	.valid0_o(valid0_o[0]),
	.valid1_o(valid1_o[0]),
	.valid2_o(valid2_o[0])
);

Stark_validate_operand uvsrcB
(
	.prn(prn),
	.prnv(prnv),
	.rfo(rfo),
	.rfo_tag(rfo_tag),
	.val0(argB0),
	.val1(argB1),
	.val2(argB2),
	.val0_tag(argB0_tag),
	.val1_tag(argB1_tag),
	.val2_tag(argB2_tag),
	.rfi(rfi),
	.rfi_tag(rfi_tag),
	.rfi_pRd(rfi_pRd),
	.pRn0(pregno_t'(rse[0].argB[8:0])),
	.pRn1(pregno_t'(rse[1].argB[8:0])),
	.pRn2(pregno_t'(rse[2].argB[8:0])),
	.valid0_i(rse[0].argB_v),
	.valid1_i(rse[1].argB_v),
	.valid2_i(rse[2].argB_v),
	.valid0_o(valid0_o[1]),
	.valid1_o(valid1_o[1]),
	.valid2_o(valid2_o[1])
);

Stark_validate_operand uvsrcC
(
	.prn(prn),
	.prnv(prnv),
	.rfo(rfo),
	.rfo_tag(rfo_tag),
	.val0(argC0),
	.val1(argC1),
	.val2(argC2),
	.val0_tag(argC0_tag),
	.val1_tag(argC1_tag),
	.val2_tag(argC2_tag),
	.rfi(rfi),
	.rfi_tag(rfi_tag),
	.rfi_pRd(rfi_pRd),
	.pRn0(pregno_t'(rse[0].argC[8:0])),
	.pRn1(pregno_t'(rse[1].argC[8:0])),
	.pRn2(pregno_t'(rse[2].argC[8:0])),
	.valid0_i(rse[0].argC_v),
	.valid1_i(rse[1].argC_v),
	.valid2_i(rse[2].argC_v),
	.valid0_o(valid0_o[2]),
	.valid1_o(valid1_o[2]),
	.valid2_o(valid2_o[2])
);

Stark_validate_operand uvsrcD
(
	.prn(prn),
	.prnv(prnv),
	.rfo(rfo),
	.rfo_tag(rfo_tag),
	.val0(argD0),
	.val1(argD1),
	.val2(argD2),
	.val0_tag(argD0_tag),
	.val1_tag(argD1_tag),
	.val2_tag(argD2_tag),
	.rfi(rfi),
	.rfi_tag(rfi_tag),
	.rfi_pRd(rfi_pRd),
	.pRn0(pregno_t'(rse[0].argD[8:0])),
	.pRn1(pregno_t'(rse[1].argD[8:0])),
	.pRn2(pregno_t'(rse[2].argD[8:0])),
	.valid0_i(rse[0].argD_v),
	.valid1_i(rse[1].argD_v),
	.valid2_i(rse[2].argD_v),
	.valid0_o(valid0_o[3]),
	.valid1_o(valid1_o[3]),
	.valid2_o(valid2_o[3])
);

always_comb
	argBI <= rob.op.decbus.immb | argB;

always_comb
begin
	if (rse_i[0].funcunit==FUNCUNIT)
		rsei = rse_i[0];
	else if (rse_i[1].funcunit==FUNCUNIT)
		rsei = rse_i[1];
	else if (rse_i[2].funcunit==FUNCUNIT)
		rsei = rse_i[2];
	else if (rse_i[3].funcunit==FUNCUNIT)
		rsei = rse_i[3];
	else
		rsei = {$bits(reservation_station_entry_t){1'b0}};
end

always_ff @(posedge clk)
if (rst) begin
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
	bank <= 1'b0;
	aRd <= 9'd0;
	aRdz <= TRUE;
	instr <= {41'd0,OP_NOP};
	cptgt <= 8'h00;
	pc <= RSTPC;
	cp <= 4'd0;
	pred <= FALSE;
	predz <= FALSE;
	prc <= QuplsPkg::octa;
	sc_done <= FALSE;
	idle_false <= FALSE;
	issue <= FALSE;
	valid <= 5'd0;
end
else begin
	issue <= FALSE;
	sc_done <= FALSE;
	idle_false <= FALSE;
	if (available && dispatch && idle) begin
		// Load up the reservation stations.
		if (!rse[0].busy) begin
			rse[0] <= rsei;
			rse[0].busy <= TRUE;
			rse[0].ready <= rse_i.argA_v && rse_i.argB_v && rse_i.argC_v && rse_i.aargD_v;
		end
		else if (!rse[1].busy) begin
			rse[1] <= rsei;
			rse[1].busy <= TRUE;
			rse[1].ready <= rse_i.argA_v && rse_i.argB_v && rse_i.argC_v && rse_i.aargD_v;
		end
		else if (!rse[2].busy) begin
			rse[2] <= rsei;
			rse[2].busy <= TRUE;
			rse[2].ready <= rse_i.argA_v && rse_i.argB_v && rse_i.argC_v && rse_i.aargD_v;
		end

		valid <= 5'd0;
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
		aRd <= rob.op.decbus.Rd;
		aRdz <= rob.op.decbus.Rd==8'd00;//rob.decbus.Rtz; <- this did not work
		om <= rob.om;
//		pred <= rob.op.decbus.pred;
//		predz <= rob.op.decbus.pred ? rob.op.decbus.predz : 1'b0;
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
	if (valid0_o[0]) begin rse[0].argA_v <= VAL; rse[0].argA <= argA0; rse[0].tagA <= argA0_tag; end
	if (valid1_o[0]) begin rse[1].argA_v <= VAL; rse[1].argA <= argA1; rse[1].tagA <= argA1_tag; end
	if (valid2_o[0]) begin rse[2].argA_v <= VAL; rse[2].argA <= argA2; rse[2].tagA <= argA2_tag; end
	if (valid0_o[1]) begin rse[0].argB_v <= VAL; rse[0].argB <= argB0; rse[0].tagB <= argB0_tag; end
	if (valid1_o[1]) begin rse[1].argB_v <= VAL; rse[1].argB <= argB1; rse[1].tagB <= argB1_tag; end
	if (valid2_o[1]) begin rse[2].argB_v <= VAL; rse[2].argB <= argB2; rse[2].tagB <= argB2_tag; end
	if (valid0_o[2]) begin rse[0].argC_v <= VAL; rse[0].argC <= argC0; rse[0].tagC <= argC0_tag; end
	if (valid1_o[2]) begin rse[1].argC_v <= VAL; rse[1].argC <= argC1; rse[1].tagC <= argC1_tag; end
	if (valid2_o[2]) begin rse[2].argC_v <= VAL; rse[2].argC <= argC2; rse[2].tagC <= argC2_tag; end
	if (valid0_o[3]) begin rse[0].argD_v <= VAL; rse[0].argD <= argD0; rse[0].tagD <= argD0_tag; end
	if (valid1_o[3]) begin rse[1].argD_v <= VAL; rse[1].argD <= argD1; rse[1].tagD <= argD1_tag; end
	if (valid2_o[3]) begin rse[2].argD_v <= VAL; rse[2].argD <= argD2; rse[0].tagD <= argD2_tag; end
	if (rse[0].argA_v && rse[0].argB_v && rse[0].argC_v && rse[0].argD_v)
		rse[0].ready <= TRUE;
	if (rse[1].argA_v && rse[1].argB_v && rse[1].argC_v && rse[1].argD_v)
		rse[1].ready <= TRUE;
	if (rse[2].argA_v && rse[2].argB_v && rse[2].argC_v && rse[2].argD_v)
		rse[2].ready <= TRUE;

	// Unused stations are never ready.
	if (NRSE < 2) begin
		rse[1].busy <= TRUE;
		rse[2].busy <= TRUE;
		rse[1].ready <= FALSE;
		rse[2].ready <= FALSE;
		rse[1].argA_v <= VAL;
		rse[1].argB_v <= VAL;
		rse[1].argC_v <= VAL;
		rse[1].argD_v <= VAL;
		rse[2].argA_v <= VAL;
		rse[2].argB_v <= VAL;
		rse[2].argC_v <= VAL;
		rse[2].argD_v <= VAL;
	end
	if (NRSE < 3) begin
		rse[2].busy <= TRUE;
		rse[2].ready <= FALSE;
		rse[2].argA_v <= VAL;
		rse[2].argB_v <= VAL;
		rse[2].argC_v <= VAL;
		rse[2].argD_v <= VAL;
	end

	// Issue scheduling: if there is only one ready easy: pick the ready one.
	// If there are ties: pick one at random.
	casez({stall,rse[2].ready,rse[1].ready,rse[0].ready})
	4'b1???:	;
	4'b0000:	;
	4'b0001: begin issue <= TRUE; rse_o <= rse[0]; rse[0].busy <= FALSE; end
	4'b0010: begin issue <= TRUE; rse_o <= rse[1]; rse[1].busy <= FALSE; end
	4'b0011: begin issue <= TRUE; rse_o <= lfsro[0] ? rse[1] : rse[0]; rse[0].busy <= lfsro[0]; rse[1].busy <= ~lfsro[0]; end
	4'b0100: begin issue <= TRUE; rse_o <= rse[2]; rse[2].busy <= FALSE; end
	4'b0101: begin issue <= TRUE; rse_o <= lfsro[0] ? rse[2] : rse[0]; rse[0].busy <= lfsro[0]; rse[2].busy <= ~lfsro[0]; end
	4'b0110: begin issue <= TRUE; rse_o <= lfsro[0] ? rse[2] : rse[1]; rse[1].busy <= lfsro[0]; rse[2].busy <= ~lfsro[0]; end
	4'b0111:
		begin
			issue <= TRUE;
			if (lfsro[3:0] < 4'd5) begin
				rse_o <= rse[0];
				rse[0].busy <= FALSE;
			end
			else if (lfsro[3:0] < 4'd10) begin
				rse_o <= rse[1];
				rse[1].busy <= FALSE;
			end
			else begin
				rse_o <= rse[2];
				rse[2].busy <= FALSE;
			end
		end
	endcase
end

endmodule
