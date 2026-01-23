// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2026  Robert Finch, Waterloo
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
// 5101 LUTs / 1975 FFs (RL_STRATEGY 1)
// 5101 LUTs / 1975 FFs (RL_STRATEGY 0)
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_reservation_station(rst, clk, available, busy, issue, stall,
	rse_i, rse_o, stomp, rf_oper_i, bypass_i, wp_oper_tap_i, req_pRn, req_pRnv
);
parameter MWIDTH = 4;
parameter NRSE = 1;
parameter FUNCUNIT = 4'd0;
parameter NBPI = 4;			// number of bypasssing inputs
parameter NSARG = 3;		// number of source operands
parameter RL_STRATEGY = 0;	// register lookup strategy
parameter NREG_RPORTS = RL_STRATEGY==0 ? 0 : 16;
parameter RC = 1'b0;
parameter DISPATCH_COUNT=6;	// number of lanes of dispatching
// The following controls which lanes to look at. It depends on which lanes are
// setup in the instruction dispatcher. Specific lanes target specific functional
// unit types. For instance lane #4 is used for floating-point.
parameter DISPATCH_MAP=6'b100001;
input rst;
input clk;
input available;
input stall;
input Qupls4_pkg::reservation_station_entry_t [DISPATCH_COUNT-1:0] rse_i;
input Qupls4_pkg::rob_bitmask_t stomp;
input Qupls4_pkg::operand_t [NREG_RPORTS-1:0] rf_oper_i;
input Qupls4_pkg::operand_t [NBPI-1:0] bypass_i;
input Qupls4_pkg::operand_t [MWIDTH-1:0] wp_oper_tap_i [0:4];
output reg busy;
output reg issue;
output Qupls4_pkg::reservation_station_entry_t rse_o;
output pregno_t [3:0] req_pRn;
output reg [3:0] req_pRnv;

integer kk,jj,nn,mm,rdy,pp,qq,n1,n2,n3;
genvar g;
reg idle;
reg dispatch;
reg pstall;
Qupls4_pkg::operand_t [NRSE-1:0] arg [0:5];
pregno_t [3:0] req_pRnu;
reg [3:0] req_pRnuv;

wire [16:0] lfsro;
Qupls4_pkg::reservation_station_entry_t [NRSE-1:0] rse;
Qupls4_pkg::operand_t [NRSE-1:0] rse_argA;
Qupls4_pkg::operand_t [NRSE-1:0] rse_argB;
Qupls4_pkg::operand_t [NRSE-1:0] rse_argC;
Qupls4_pkg::operand_t [NRSE-1:0] rse_argD;
Qupls4_pkg::operand_t [NRSE-1:0] rse_argT;
Qupls4_pkg::operand_t [NRSE-1:0] rse_argS;		// status (for round mode)
Qupls4_pkg::reservation_station_entry_t rsei;

always_comb
for (nn = 0; nn < NRSE; nn = nn + 1)
begin
	rse_argA[nn] = rse[nn].arg[0];
	rse_argB[nn] = rse[nn].arg[1];
	rse_argC[nn] = rse[nn].arg[2];
	rse_argD[nn] = rse[nn].arg[3];
	rse_argT[nn] = rse[nn].arg[4];
	rse_argS[nn] = rse[nn].arg[5];
end

always_comb
begin
	busy = 1'b1;
	for (n2 = 0; n2 < NRSE; n2 = n2 + 1)
		busy = busy & rse[n2].busy;
end
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

Qupls4_validate_operand #(.RL_STRATEGY(RL_STRATEGY),
	.NBPI(NBPI), .NENTRY(NRSE), .NREG_PORTS(NREG_RPORTS)) uvsrcA
(
	.wp_hist_i(wp_oper_tap_i),
	.rf_oper_i(rf_oper_i),
	.oper_i(rse_argA),
	.oper_o(arg[0]),
	.bypass_i(bypass_i)
);

generate begin : gOperands

if (NSARG > 1)
Qupls4_validate_operand #(.RL_STRATEGY(RL_STRATEGY),
	.NBPI(NBPI), .NENTRY(NRSE), .NREG_PORTS(NREG_RPORTS)) uvsrcB
(
	.wp_hist_i(wp_oper_tap_i),
	.rf_oper_i(rf_oper_i),
	.oper_i(rse_argB),
	.oper_o(arg[1]),
	.bypass_i(bypass_i)
);
else begin
	for (g = 0; g < NRSE; g = g + 1) begin
		assign arg[1][g].v = VAL;
		assign arg[1][g].val = value_zero;
		assign arg[1][g].flags = 8'd0;
	end
end

if (NSARG > 2)
Qupls4_validate_operand #(.RL_STRATEGY(RL_STRATEGY),
	.NBPI(NBPI), .NENTRY(NRSE), .NREG_PORTS(NREG_RPORTS)) uvsrcC
(
	.wp_hist_i(wp_oper_tap_i),
	.rf_oper_i(rf_oper_i),
	.oper_i(rse_argC),
	.oper_o(arg[2]),
	.bypass_i(bypass_i)
);
else begin
	for (g = 0; g < NRSE; g = g + 1) begin
		assign arg[2][g].v = VAL;
		assign arg[2][g].val = value_zero;
		assign arg[2][g].flags = 8'd0;
	end
end

if (NSARG > 3)
Qupls4_validate_operand #(.RL_STRATEGY(RL_STRATEGY),
	.NBPI(NBPI), .NENTRY(NRSE), .NREG_PORTS(NREG_RPORTS)) uvsrcD
(
	.wp_hist_i(wp_oper_tap_i),
	.rf_oper_i(rf_oper_i),
	.oper_i(rse_argD),
	.oper_o(arg[3]),
	.bypass_i(bypass_i)
);
else begin
	for (g = 0; g < NRSE; g = g + 1) begin
		assign arg[3][g].v = VAL;
		assign arg[3][g].val = value_zero;
		assign arg[3][g].flags = 8'd0;
	end
end

end
endgenerate

// Destination operand which sometimes needs to be read.

Qupls4_validate_operand #(.RL_STRATEGY(RL_STRATEGY),
	.NBPI(NBPI), .NENTRY(NRSE), .NREG_PORTS(NREG_RPORTS)) uvsrcT
(
	.wp_hist_i(wp_oper_tap_i),
	.rf_oper_i(rf_oper_i),
	.oper_i(rse_argT),
	.oper_o(arg[4]),
	.bypass_i(bypass_i)
);

// Status operand which sometimes needs to be read.
generate begin : gStat
	if (RC > 0)
Qupls4_validate_operand #(.RL_STRATEGY(RL_STRATEGY),
	.NBPI(NBPI), .NENTRY(NRSE), .NREG_PORTS(NREG_RPORTS)) uvsrcS
(
	.wp_hist_i(wp_oper_tap_i),
	.rf_oper_i(rf_oper_i),
	.oper_i(rse_argS),
	.oper_o(arg[5]),
	.bypass_i(bypass_i)
);
end
endgenerate


// Check for instruction dispatches. Select dispatch input and set dispatch
// flags if dispatch is available.

always_comb
begin
	rsei = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	dispatch = FALSE;
	foreach (rse_i[n1])
		if (DISPATCH_MAP[n1] && rse_i[n1].funcunit==FUNCUNIT) begin
			rsei = rse_i[n1];
			dispatch = TRUE;
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
	foreach (rse[pp])
  	rse[pp] <= {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
  rse_o <= {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
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
			rse[qq].ready <= rsei.arg[0].v && rsei.arg[1].v && (rsei.arg[2].v||rsei.store) && rsei.arg[3].v && rsei.arg[4].v && rsei.arg[5].v;
			if (stomp[rsei.rndx])
				rse[qq].uop <= {26'd0,Qupls4_pkg::OP_NOP};
		end
	end
	for (pp = 0; pp < 6; pp = pp + 1) begin
		for (mm = 0; mm < NRSE; mm = mm + 1)
			if (arg[pp][mm].v) begin
				rse[mm].arg[pp] <= arg[pp][mm];
				rse[mm].arg[pp].v <= VAL;
			end
	end
	for (mm = 0; mm < NRSE; mm = mm + 1) begin
		rse[mm].ready <= FALSE;
		if (rse[mm].arg[0].v && rse[mm].arg[1].v && (rse[mm].arg[2].v|rse[mm].store) && rse[mm].arg[3].v && rse[mm].arg[4].v && rse[mm].arg[5].v)
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
				issue <= TRUE;
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
	req_pRnu[0] = 8'd0;
	req_pRnu[1] = 8'd0;
	req_pRnu[2] = 8'd0;
	req_pRnu[3] = 8'd0;
	req_pRnuv = 4'd0;
	for (jj = 0; jj < NRSE; jj = jj + 1) begin
		for (pp = 0; pp < 6; pp = pp + 1) begin
			if (fnSrc(rse[jj].uop,pp)) begin
				if (rse[jj].busy && !rse[jj].arg[pp].v && kk < 4) begin
					req_pRnu[kk] = rse[jj].arg[pp].pRn;
					req_pRnuv[kk] = VAL;
					kk = kk + 1;
				end
			end
		end
	end
end

always_ff @(posedge clk)
	req_pRn <= req_pRnu;
always_ff @(posedge clk)
	req_pRnv <= req_pRnuv;

function fnSrc;
input micro_op_t op;
input [2:0] n;
begin
	case(n)
	3'd0:	fnSrc = op.src[1];
	3'd1:	fnSrc = op.src[2];
	3'd2:	fnSrc = op.src[3];
	3'd3:	fnSrc = op.src[4];
	3'd4:	fnSrc = op.src[0];
	3'd5:	fnSrc = op.src[5];
	default:	fnSrc = 1'b0;
	endcase
end
endfunction

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
