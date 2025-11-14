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
// 3900 LUTs / 900 FFs  (1 station)
// 4800 LUTs / 950 FFs  (8 bypass inputs)
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_reservation_station(rst, clk, available, busy, issue, stall,
	rfo_tag, rse_i, rse_o, stomp,
	rfi_val, rfi_tag, rfi_pRd,
	prn, prnv, rfo, req_pRn
);
parameter NRSE = 1;
parameter FUNCUNIT = 4'd0;
parameter NBPI = 8;			// number of bypasssing inputs
input rst;
input clk;
input available;
input stall;
input reservation_station_entry_t [3:0] rse_i;
input Qupls4_pkg::rob_bitmask_t stomp;
input pregno_t [15:0] prn;
input [15:0] prnv;
input value_t [15:0] rfo;
input [15:0] rfo_tag;
input value_t [NBPI-1:0] rfi_val;
input pregno_t [NBPI-1:0] rfi_pRd;
input [NBPI-1:0] rfi_tag;
output reg busy;
output reg issue;
output reservation_station_entry_t rse_o;
output aregno_t [3:0] req_pRn;

integer nn,kk,jj;
reg idle;
reg dispatch;
reg pstall;
cpu_types_pkg::value_t argA0, argA1, argA2;
cpu_types_pkg::value_t argB0, argB1, argB2;
cpu_types_pkg::value_t argC0, argC1, argC2;
cpu_types_pkg::value_t argD0, argD1, argD2;
reg argA0_tag, argA1_tag, argA2_tag;
reg argB0_tag, argB1_tag, argB2_tag;
reg argC0_tag, argC1_tag, argC2_tag;
reg argD0_tag, argD1_tag, argD2_tag;
wire [3:0] valid0_o;
wire [3:0] valid1_o;
wire [3:0] valid2_o;
wire [16:0] lfsro;
reservation_station_entry_t [2:0] rse;
reservation_station_entry_t rsei;
always_comb
	busy = rse[0].busy & rse[1].busy & rse[2].busy;
always_comb
	idle = !busy;

//always_comb
//	next_cptgt <= {8{cpytgt|rob.decbus.cpytgt}} | ~{8{rob.pred_bit}};

lfsr17 ulfsr1
(
	.rst(rst),
	.clk(clk),
	.ce(1'b1), 
	.cyc(1'b0),
	.o(lfsro)
);

Qupls4_validate_operand #(.NBPI(NBPI)) uvsrcA
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
	.rfi_val(rfi_val),
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

Qupls4_validate_operand #(.NBPI(NBPI)) uvsrcB
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
	.rfi_val(rfi_val),
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

Qupls4_validate_operand #(.NBPI(NBPI)) uvsrcC
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
	.rfi_val(rfi_val),
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

Qupls4_validate_operand #(.NBPI(NBPI)) uvsrcD
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
	.rfi_val(rfi_val),
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
begin
	if (rse_i[0].funcunit==FUNCUNIT) begin
		rsei = rse_i[0];
		dispatch = TRUE;
	end
	else if (rse_i[1].funcunit==FUNCUNIT) begin
		rsei = rse_i[1];
		dispatch = TRUE;
	end
	else if (rse_i[2].funcunit==FUNCUNIT) begin
		rsei = rse_i[2];
		dispatch = TRUE;
	end
	else if (rse_i[3].funcunit==FUNCUNIT) begin
		rsei = rse_i[3];
		dispatch = TRUE;
	end
	else begin
		rsei = {$bits(reservation_station_entry_t){1'b0}};
		dispatch = FALSE;
	end
end

/*
		if (cpytgt) begin
			instr.uop.ins <= {26'd0,OP_NOP};
//			pred <= FALSE;
//			predz <= rob.op.decbus.cpytgt ? FALSE : rob.decbus.predz;
			div <= FALSE;
		end
		else
			instr <= rob.op;
		// Done even if multi-cycle if it is just a copy-target.
		if (!rob.op.decbus.multicycle || (&next_cptgt))
			sc_done <= TRUE;
		else
			idle_false <= TRUE;
*/			
always_ff @(posedge clk)
if (rst) begin
  rse[0] <= {$bits(reservation_station_entry_t){1'b0}};
  rse[1] <= {$bits(reservation_station_entry_t){1'b0}};
  rse[2] <= {$bits(reservation_station_entry_t){1'b0}};
end
else begin
	issue <= FALSE;
	pstall <= stall;
	if (available && dispatch && idle) begin
		// Load up the reservation stations.
		if (!rse[0].busy) begin
			rse[0] <= rsei;
			rse[0].busy <= TRUE;
			rse[0].ready <= rsei.argA_v && rsei.argB_v && (rsei.argC_v||rsei.store) && rsei.argD_v;
			if (stomp[rsei.rndx])
				rse[0].ins <= {26'd0,Qupls4_pkg::OP_NOP};
		end
		else if (!rse[1].busy) begin
			rse[1] <= rsei;
			rse[1].busy <= TRUE;
			rse[1].ready <= rsei.argA_v && rsei.argB_v && (rsei.argC_v||rsei.store) && rsei.argD_v;
			if (stomp[rsei.rndx])
				rse[1].ins <= {26'd0,Qupls4_pkg::OP_NOP};
		end
		else if (!rse[2].busy) begin
			rse[2] <= rsei;
			rse[2].busy <= TRUE;
			rse[2].ready <= rsei.argA_v && rsei.argB_v && (rsei.argC_v||rsei.store) && rsei.argD_v;
			if (stomp[rsei.rndx])
				rse[2].ins <= {26'd0,Qupls4_pkg::OP_NOP};
		end
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
	if (rse[0].argA_v && rse[0].argB_v && (rse[0].argC_v|rse[0].store) && rse[0].argD_v)
		rse[0].ready <= TRUE;
	if (rse[1].argA_v && rse[1].argB_v && (rse[1].argC_v|rse[1].store) && rse[1].argD_v)
		rse[1].ready <= TRUE;
	if (rse[2].argA_v && rse[2].argB_v && (rse[2].argC_v|rse[2].store) && rse[2].argD_v)
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
	4'b0001:
		begin
			issue <= TRUE;
			rse_o <= rse[0];
			rse[0].busy <= FALSE;
			if (stomp[rse[0].rndx])
				rse_o.ins <= {26'd0,Qupls4_pkg::OP_NOP};
		end
	4'b0010:
		begin
			issue <= !stomp[rse[1].rndx];
			rse_o <= rse[1];
			rse[1].busy <= FALSE;
			if (stomp[rse[1].rndx])
				rse_o.ins <= {26'd0,Qupls4_pkg::OP_NOP};
		end
	4'b0011:
		begin
			if (lfsro[0]) begin
				issue <= !stomp[rse[1].rndx];
				rse_o <= rse[1];
				rse[1].busy <= FALSE;
				if (stomp[rse[1].rndx])
					rse_o.ins <= {26'd0,Qupls4_pkg::OP_NOP};
			end
			else begin
				issue <= !stomp[rse[0].rndx];
				rse_o <= rse[0];
				rse[0].busy <= FALSE;
				if (stomp[rse[0].rndx])
					rse_o.ins <= {26'd0,Qupls4_pkg::OP_NOP};
			end
		end
	4'b0100:
		begin
			issue <= !stomp[rse[2].rndx];
			rse_o <= rse[2];
			rse[2].busy <= FALSE;
			if (stomp[rse[2].rndx])
				rse_o.ins <= {26'd0,Qupls4_pkg::OP_NOP};
		end
	4'b0101:
		begin
			if (lfsro[0]) begin
				issue <= !stomp[rse[2].rndx];
				rse_o <= rse[2];
				rse[2].busy <= FALSE;
				if (stomp[rse[2].rndx])
					rse_o.ins <= {26'd0,Qupls4_pkg::OP_NOP};
			end
			else begin
				issue <= !stomp[rse[0].rndx];
				rse_o <= rse[0];
				rse[0].busy <= FALSE;
				if (stomp[rse[0].rndx])
					rse_o.ins <= {26'd0,Qupls4_pkg::OP_NOP};
			end
		end
	4'b0110:
		begin
			if (lfsro[0]) begin
				issue <= !stomp[rse[2].rndx];
				rse_o <= rse[2];
				rse[2].busy <= FALSE;
				if (stomp[rse[2].rndx])
					rse_o.ins <= {26'd0,Qupls4_pkg::OP_NOP};
			end
			else begin
				issue <= !stomp[rse[1].rndx];
				rse_o <= rse[1];
				rse[1].busy <= FALSE;
				if (stomp[rse[1].rndx])
					rse_o.ins <= {26'd0,Qupls4_pkg::OP_NOP};
			end
		end
	4'b0111:
		begin
			if (lfsro[3:0] < 4'd5) begin
				issue <= !stomp[rse[0].rndx];
				rse_o <= rse[0];
				rse[0].busy <= FALSE;
				if (stomp[rse[0].rndx])
					rse_o.ins <= {26'd0,Qupls4_pkg::OP_NOP};
			end
			else if (lfsro[3:0] < 4'd10) begin
				issue <= !stomp[rse[1].rndx];
				rse_o <= rse[1];
				rse[1].busy <= FALSE;
				if (stomp[rse[1].rndx])
					rse_o.ins <= {26'd0,Qupls4_pkg::OP_NOP};
			end
			else begin
				issue <= !stomp[rse[2].rndx];
				rse_o <= rse[2];
				rse[2].busy <= FALSE;
				if (stomp[rse[2].rndx])
					rse_o.ins <= {26'd0,Qupls4_pkg::OP_NOP};
			end
		end
	endcase
end

always_comb
	rse_o.v = (pstall & ~stall) ? 1'b0 : issue;

// Request register reads for missing arguments.

always_comb
begin
	kk = 0;
	req_pRn[0] = 8'd0;
	req_pRn[1] = 8'd0;
	req_pRn[2] = 8'd0;
	req_pRn[3] = 8'd0;
	for (jj = 0; jj < NRSE; jj = jj  + 1) begin
		if (rse[jj].busy && !rse[jj].argA_v && kk < 4) begin
			req_pRn[kk] = rse[jj].argA[23:16];
			kk = kk + 1;
		end
		if (rse[jj].busy && !rse[jj].argB_v && kk < 4) begin
			req_pRn[kk] = rse[jj].argB[23:16];
			kk = kk + 1;
		end
		if (rse[jj].busy && !rse[jj].argC_v && kk < 4) begin
			req_pRn[kk] = rse[jj].argC[23:16];
			kk = kk + 1;
		end
		if (rse[jj].busy && !rse[jj].argD_v && kk < 4) begin
			req_pRn[kk] = rse[jj].argD[23:16];
			kk = kk + 1;
		end
	end
end

endmodule
