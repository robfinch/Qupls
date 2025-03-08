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
//
// This module is not currently in use. It would add a cycle of latency to
// the register file update.
//
// This module routes the output of the function units to the register file.
// There may be more functional units than register file ports. Updates
// requiring more than the available number of ports are split across
// multiple clock cycles.
//
// 1410 LUTs / 1350 FFs
// ============================================================================

import cpu_types_pkg::*;
import QuplsPkg::*;

module Qupls_regfile_rout(
	input rst,
	input clk,
	input aregno_t [11:0] aRt,
	input pregno_t [11:0] Rt,
	input value_t [11:0] res,
	input [11:0] tag,
	input [11:0] val,
	output aregno_t rfport0_aRt,
	output aregno_t rfport1_aRt,
	output aregno_t rfport2_aRt,
	output aregno_t rfport3_aRt,
	output pregno_t rfport0_Rt,
	output pregno_t rfport1_Rt,
	output pregno_t rfport2_Rt,
	output pregno_t rfport3_Rt,
	output value_t rfport0_res,
	output value_t rfport1_res,
	output value_t rfport2_res,
	output value_t rfport3_res,
	output reg rfport0_tag,
	output reg rfport1_tag,
	output reg rfport2_tag,
	output reg rfport3_tag,
	output reg rfport0_v,
	output reg rfport1_v,
	output reg rfport2_v,
	output reg rfport3_v,
	output reg stall
);

integer nn;

typedef enum logic [1:0] {
	RFROUT_RESET = 2'd0,
	RFROUT_WRFIRST4,
	RFROUT_WRMID4,
	RFROUT_WRLAST4
} state_t;
state_t state;

typedef struct packed
{
	logic val;				// result valid
	aregno_t aReg;		// architectural register number
	pregno_t pReg;		// physical register number
	value_t res;			// result value
	logic tag;
} result_t;

result_t [11:0] wq;

wire [3:0] rout0, rout1, rout2, rout3;
wire [11:0] wq_emptyw;
reg [11:0] wq_empty;
assign wq_emptyw = ~{wq[11].val,wq[10].val,wq[9].val,wq[8].val,wq[7].val,wq[6].val,
	wq[5].val,wq[4].val,wq[3].val,wq[2].val,wq[1].val,wq[0].val};

ffz12 ureffz0 (wq_empty,rout0);
ffz12 ureffz1 (wq_empty|(12'd1 << rout0),rout1);
ffz12 ureffz2 (wq_empty|(12'd1 << rout0)|(12'd1 << rout1),rout2);
ffz12 ureffz3 (wq_empty|(12'd1 << rout0)|(12'd1 << rout1)|(12'd1 << rout2),rout3);

always_comb
begin
	for (nn = 0; nn < 12; nn = nn + 1) begin
		wq[nn].pReg <= Rt[nn];
		wq[nn].aReg <= aRt[nn];
		wq[nn].res <= res[nn];
		wq[nn].tag <= tag[nn];
		wq[nn].val <= val[nn];
	end
end

always_ff @(posedge clk)
begin
if (rst)
	state <= RFROUT_RESET;

case(state)
RFROUT_RESET:
	begin
		stall <= 1'b0;
		wq_empty <= wq_emptyw;
		state <= RFROUT_WRFIRST4;
	end
RFROUT_WRFIRST4:
	// Find out if there are more than four results ready.
	if (wq_emptyw[7:4]!=4'hF) begin
		wq_empty <= {4'hF,wq_emptyw[7:4],4'hF};
		stall <= 1'b1;
		state <= RFROUT_WRMID4;
	end
	else
		wq_empty <= wq_emptyw;
RFROUT_WRMID4:
	// Find out if there are more than eight results ready.
	if (wq_emptyw[11:8]!=4'hF) begin
		wq_empty <= {wq_emptyw[11:8],8'hFF};
		stall <= 1'b1;
		state <= RFROUT_WRLAST4;
	end
	else
		wq_empty <= wq_emptyw;
RFROUT_WRLAST4:
	begin
		wq_empty <= wq_emptyw;
		stall <= 1'b0;
		state <= RFROUT_WRFIRST4;
	end
default:
	state <= RFROUT_RESET;
endcase
end


always_ff @(posedge clk)
begin
	rfport0_Rt <= wq[rout0].pReg;
	rfport1_Rt <= wq[rout1].pReg;
	rfport2_Rt <= wq[rout2].pReg;
	rfport3_Rt <= wq[rout3].pReg;
	rfport0_aRt <= wq[rout0].aReg;
	rfport1_aRt <= wq[rout1].aReg;
	rfport2_aRt <= wq[rout2].aReg;
	rfport3_aRt <= wq[rout3].aReg;
	rfport0_res <= wq[rout0].res;
	rfport1_res <= wq[rout1].res;
	rfport2_res <= wq[rout2].res;
	rfport3_res <= wq[rout3].res;
	rfport0_tag <= wq[rout0].tag;
	rfport1_tag <= wq[rout1].tag;
	rfport2_tag <= wq[rout2].tag;
	rfport3_tag <= wq[rout3].tag;
	rfport0_v <= rout0 < 4'd12;
	rfport1_v <= rout1 < 4'd12;
	rfport2_v <= rout2 < 4'd12;
	rfport3_v <= rout3 < 4'd12;
end

endmodule
