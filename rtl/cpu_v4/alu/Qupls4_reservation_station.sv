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
// 4650 LUTs / 900 FFs  (8 bypass inputs) - 48-bit operands
// 5700 LUTs / 1900 FFs  (8 bypass inputs)	- 64 bit operands, 4 source args
// 19200 LUTs / 1800 FFs  (8 bypass inputs) - 128 bit operands
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_reservation_station(rst, clk, available, busy, issue, stall,
	rse_i, rse_o, stomp, rf_oper_i, bypass_i req_aRn
);
parameter NRSE = 1;
parameter FUNCUNIT = 4'd0;
parameter NBPI = 8;			// number of bypasssing inputs
parameter NSARG = 3;		// number of source operands
input rst;
input clk;
input available;
input stall;
input Qupls4_pkg::reservation_station_entry_t [3:0] rse_i;
input Qupls4_pkg::rob_bitmask_t stomp;
input Qupls4_pkg::operand_t [NREG_RPORTS-1:0] rf_oper_i;
input Qupls4_pkg::operand_t [NBPI-1:0] bypass_i;
output reg busy;
output reg issue;
output Qupls4_pkg::reservation_station_entry_t rse_o;
output aregno_t [3:0] req_aRn;

integer kk,jj,nn,mm,rdy,pp,qq;
genvar g;
reg idle;
reg dispatch;
reg pstall;
Qupls4_pkg::operand_t [NRSE-1:0] arg [0:NSARG-1];

wire [16:0] lfsro;
Qupls4_pkg::reservation_station_entry_t [NRSE-1:0] rse;
Qupls4_pkg::operand_t [NRSE-1:0] rse_argA;
Qupls4_pkg::operand_t [NRSE-1:0] rse_argB;
Qupls4_pkg::operand_t [NRSE-1:0] rse_argC;
Qupls4_pkg::operand_t [NRSE-1:0] rse_argD;
Qupls4_pkg::operand_t [NRSE-1:0] rse_argT;
Qupls4_pkg::reservation_station_entry_t rsei;

always_comb
for (nn = 0; nn < NRSE; nn = nn + 1)
begin
	rse_argA[nn] = rse[nn].argA;
	rse_argB[nn] = rse[nn].argB;
	rse_argC[nn] = rse[nn].argC;
	rse_argD[nn] = rse[nn].argD;
	rse_argT[nn] = rse[nn].argT;
end

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

// Always assume at least one source operand.

Qupls4_validate_operand #(.NBPI(NBPI), .NENTRY(NRSE)) uvsrcA
(
	.rf_oper_i(rf_oper_i),
	.oper_i(rse_argA),
	.oper_o(arg[0]),
	.bypass_i(bypass_i)
);

generate begin : gOperands

if (NSARG > 1)
Qupls4_validate_operand #(.NBPI(NBPI), .NENTRY(NRSE)) uvsrcB
(
	.rf_oper_i(rf_oper_i),
	.oper_i(rse_argB),
	.oper_o(arg[1]),
	.bypass_i(bypass_i)
);
else begin
	for (g = 0; g < NRSE; g = g + 1) begin
		arg[1][g].v = VAL;
		arg[1][g].val = value_zero;
		arg[1][g].flags = 8'd0;
	end
end

if (NSARG > 2)
Qupls4_validate_operand #(.NBPI(NBPI), .NENTRY(NRSE)) uvsrcC
(
	.rf_oper_i(rf_oper_i),
	.oper_i(rse_argC),
	.oper_o(arg[2]),
	.bypass_i(bypass_i)
);
else begin
	for (g = 0; g < NRSE; g = g + 1) begin
		arg[2][g].v = VAL;
		arg[2][g].val = value_zero;
		arg[2][g].flags = 8'd0;
	end
end

if (NSARG > 3)
Qupls4_validate_operand #(.NBPI(NBPI), .NENTRY(NRSE)) uvsrcD
(
	.rf_oper_i(rf_oper_i),
	.oper_i(rse_argD),
	.oper_o(arg[3]),
	.bypass_i(bypass_i)
);
else begin
	for (g = 0; g < NRSE; g = g + 1) begin
		arg[3][g].v = VAL;
		arg[3][g].val = value_zero;
		arg[3][g].flags = 8'd0;
	end
end

end
endgenerate

// Destination operand which sometimes needs to be read.

Qupls4_validate_operand #(.NBPI(NBPI), .NENTRY(NRSE)) uvsrcT
(
	.rf_oper_i(rf_oper_i),
	.oper_i(rse_argT),
	.oper_o(arg[4]),
	.bypass_i(bypass_i)
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
  rse_o <= {$bits(reservation_station_entry_t){1'b0}};
	issue <= FALSE;
  pstall <= FALSE;
end
else begin
	issue <= FALSE;
	pstall <= stall;
	if (available && dispatch && idle) begin
		// Load up the reservation stations.
		qq = fnChooseIdle(rse);
		if (qq >= 0) begin
			rse[qq] <= rsei;
			rse[qq].busy <= TRUE;
			rse[qq].ready <= rsei.arg[0].v && rsei.arg[1].v && (rsei.arg[2].v||rsei.store) && rsei.arg[3].v && rsei.arg[4].v;
			if (stomp[rsei.rndx])
				rse[qq].uop <= {26'd0,Qupls4_pkg::OP_NOP};
		end
	end
	for (pp = 0; pp < 5; pp = pp + 1) begin
		for (mm = 0; mm < NRSE; mm = mm + 1)
			if (arg[pp][mm].v) begin
				rse[mm].arg[pp] <= arg[pp][mm];
				rse[mm].arg[pp].v <= VAL;
			end
	end
	for (mm = 0; mm < NRSE; mm = mm + 1) begin
		rse[mm].ready <= FALSE;
		if (rse[mm].arg[0].v && rse[mm].arg[1].v && (rse[mm].arg[2].v|rse[mm].store) && rse[mm].arg[3].v && rse[mm].arg[4].v)
			rse[mm].ready <= TRUE;
	end

	// Unused stations are never ready.
	/*
	if (NRSE < 2) begin
		rse[1].busy <= TRUE;
		rse[2].busy <= TRUE;
		rse[1].ready <= FALSE;
		rse[2].ready <= FALSE;
		rse[1].argA_v <= VAL;
		rse[1].argB_v <= VAL;
		rse[1].argC_v <= VAL;
		rse[1].argD_v <= VAL;
		rse[1].argT_v <= VAL;
		rse[2].argA_v <= VAL;
		rse[2].argB_v <= VAL;
		rse[2].argC_v <= VAL;
		rse[2].argD_v <= VAL;
		rse[2].argT_v <= VAL;
	end
	if (NRSE < 3) begin
		rse[2].busy <= TRUE;
		rse[2].ready <= FALSE;
		rse[2].argA_v <= VAL;
		rse[2].argB_v <= VAL;
		rse[2].argC_v <= VAL;
		rse[2].argD_v <= VAL;
		rse[2].argT_v <= VAL;
	end
	*/
	// Issue scheduling: if there is only one ready easy: pick the ready one.
	// If there are ties: pick one at random.
	rse_o.v <= INV;
	casez({pstall,stall})
	2'b10:	;
	2'b01:	;
	2'b11:	;
	default:
		begin
			rdy = fnChooseReady(rse);
			if (rdy >= 0) begin
				issue <= TRUE:
				rse_o <= rse[rdy];
				rse_o.v <= !stomp[rse[rdy].rndx] & rse[rdy].v;
				rse[rdy].busy <= FALSE;
				if (stomp[rse[rdy].rndx])
					rse_o.uop <= {26'd0,Qupls4_pkg::OP_NOP};
			end
		end
	endcase
end

// Request register reads for missing arguments.

always_comb
begin
	kk = 0;
	req_pRn[0] = 8'd0;
	req_pRn[1] = 8'd0;
	req_pRn[2] = 8'd0;
	req_pRn[3] = 8'd0;
	for (jj = 0; jj < NRSE; jj = jj + 1) begin
		for (pp = 0; pp < NSARG; pp = pp + 1) begin
			if (rse[jj].busy && !rse[jj].arg[pp].v && kk < 4) begin
				req_aRn[kk] = rse[jj].arg[pp].Rn;
				kk = kk + 1;
			end
		end
	end
end

function integer fnChooseReady;
input Qupls4_pkg::reservation_station_entry_t [NRSE-1:0] rse;
integer nn;
begin
	fnChooseReady = -1;
	for (nn = 0; nn < NRSE; nn = nn + 1) begin
		if (rse[nn].ready)
			fnChooseReady = nn;
	end
end
endfunction

function integer fnChooseIdle;
input Qupls4_pkg::reservation_station_entry_t [NRSE-1:0] rse;
integer nn;
begin
	fnChooseIdle = -1;
	for (nn = 0; nn < NRSE; nn = nn + 1) begin
		if (!rse[nn].busy)
			fnChooseIdle = nn;
	end
end
endfunction

endmodule
