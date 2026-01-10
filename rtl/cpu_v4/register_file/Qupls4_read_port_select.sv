// ============================================================================
//        __
//   \\__/ o\    (C) 2025-2026  Robert Finch, Waterloo
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
// 1560 LUTs / 160 FFs
// ============================================================================
//
// This module used to pack the port requests to the minimum number of
// valid port requests, then select from among the valid ports. The port
// selection priority was rotated to ensure all valid ports would be selected.
// However, nice as it was the module was too slow.
// 	So, now it is just a 4:1 group selector regardless of the valid port
// requests. It is much faster, but ports may take more clock cycles to be
// selected. The much faster clock timing more than makes up for the
// difference.
//
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::aregno_t;
import cpu_types_pkg::pc_address_t;

module Qupls4_read_port_select(rst, clk, advance, pReg_i, pRegv_i, pReg_o, pRegv_o, regAck_o);
parameter FIXED_PORTS=0;
parameter NPORTI=64;
parameter NPORTO=16;
input rst;
input clk;
input advance;
input pregno_t [NPORTI-1:0] pReg_i;
input [NPORTI-1:0] pRegv_i;
output pregno_t [NPORTO-1:0] pReg_o;
output reg [NPORTO-1:0] pRegv_o;
output reg [NPORTI-1:0] regAck_o;

integer j,k;
genvar g;
pregno_t [NPORTO-1:0] pReg1_o;
reg [NPORTO-1:0] pRegv1_o;
reg [NPORTI-1:0] regAck1_o;
reg [NPORTI/NPORTO-1:0] bank_req;
wire [NPORTI/NPORTO-1:0] bank_grant_oh;

generate begin : gBankReq
for (g = 0; g < NPORTI/NPORTO; g = g + 1)
	always_comb
		if (g >= FIXED_PORTS/8)
			bank_req[g] = |pRegv_i[g*NPORTO+NPORTO-1:g*NPORTO];
		else
			bank_req[g] = 1'b0;
end
endgenerate

RoundRobinArbiter #(.NumRequests(NPORTI/NPORTO))
urr1
(
  .rst(rst),
  .clk(clk),
  .ce(1'b1),
  .hold(1'b0),
  .req(bank_req),
  .grant(bank_grant_oh),
  .grant_enc()
);

always_ff @(posedge clk)
if (rst) begin
	for (j = 0; j < NPORTO; j = j + 1) begin
		pRegv_o[j] <= INV;
		pReg_o[j] <= 10'd0;
		regAck_o[j] <= INV;
	end
end
else begin
	for (k = 0; k < NPORTI/NPORTO; k = k + 1) begin
		if (k < FIXED_PORTS/8) begin
			for (j = 0; j < 8; j = j + 1) begin
				pRegv_o[j+k*8] <= pRegv_i[j+k*8];
				pReg_o[j+k*8] <= pReg_i[j+k*8];
				regAck_o[j+k*8] <= pRegv_i[j+k*8];
			end
		end
		else if (bank_grant_oh[k]) begin
			for (j = 0; j < NPORTO-FIXED_PORTS; j = j + 1) begin
				pRegv_o[j+FIXED_PORTS] <= pRegv_i[j+k*NPORTO];
				pReg_o[j+FIXED_PORTS] <= pReg_i[j+k*NPORTO];
				regAck_o[j+FIXED_PORTS] <= pRegv_i[j+k*NPORTO];
			end
		end
	end
end

/* Too slow...
	for (j = 0; j < NPORTI; j = j + 1) begin
		regAck_o[j] <= 1'b0;
		if (k < NPORTO) begin
			if (pRegv_i[((j+m)%NPORTI)]) begin
				regAck_o[((j+m)%NPORTI)] <= 1'b1;
				pReg_o[k] <= pReg_i[((j+m)%NPORTI)];
				pRegv_o[k] <= VAL;
				k = k + 1;
			end
		end
	end
*/
/*
always_ff @(posedge clk)
	pReg_o <= pReg1_o;
always_ff @(posedge clk)
	pRegv_o <= pRegv1_o;
always_ff @(posedge clk)
	regAck_o <= regAck1_o;
*/

endmodule
