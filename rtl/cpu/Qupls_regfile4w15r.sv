`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2013-2023  Robert Finch, Waterloo
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
// ============================================================================
//
import QuplsPkg::*;

module Qupls_regfile4w15r(rst, clk, 
	wr0, wr1, wr2, wr3, we0, we1, we2, we3,
	wa0, wa1, wa2, wa3, i0, i1, i2, i3,
	rclk, ra, o);
parameter WID=64;
parameter RBIT = 8;
parameter RPORTS = 15;
input rst;
input clk;
input wr0;
input wr1;
input wr2;
input wr3;
input we0;
input we1;
input we2;
input we3;
input [RBIT:0] wa0;
input [RBIT:0] wa1;
input [RBIT:0] wa2;
input [RBIT:0] wa3;
input [WID-1:0] i0;
input [WID-1:0] i1;
input [WID-1:0] i2;
input [WID-1:0] i3;
input rclk;
input pregno_t [RPORTS-1:0] ra;
output value_t [RPORTS-1:0] o;

value_t [RPORTS-1:0] o0;
value_t [RPORTS-1:0] o1;
value_t [RPORTS-1:0] o2;
value_t [RPORTS-1:0] o3;

genvar g;

generate begin : gRF
	for (g = 0; g < RPORTS; g = g + 1) begin
		Qupls_regfileRam urf0 (
		  .clka(clk),
		  .ena(wr0),
		  .wea(we0),
		  .addra(wa0),
		  .dina(i0),
		  .clkb(rclk),
		  .enb(1'b1),
		  .addrb(ra[g]),
		  .doutb(o0[g])
		);
		Qupls_regfileRam urf1 (
		  .clka(clk),
		  .ena(wr1),
		  .wea(we1),
		  .addra(wa1),
		  .dina(i1),
		  .clkb(rclk),
		  .enb(1'b1),
		  .addrb(ra[g]),
		  .doutb(o1[g])
		);
		Qupls_regfileRam urf2 (
		  .clka(clk),
		  .ena(wr2),
		  .wea(we2),
		  .addra(wa2),
		  .dina(i2),
		  .clkb(rclk),
		  .enb(1'b1),
		  .addrb(ra[g]),
		  .doutb(o2[g])
		);
		Qupls_regfileRam urf3 (
		  .clka(clk),
		  .ena(wr3),
		  .wea(we3),
		  .addra(wa3),
		  .dina(i3),
		  .clkb(rclk),
		  .enb(1'b1),
		  .addrb(ra[g]),
		  .doutb(o3[g])
		);
	end
end
endgenerate

integer n;
// Live value table
reg [1:0] lvt [QuplsPkg::PREGS-1:0];

always_ff @(posedge clk, posedge rst)
if (rst) begin
	for (n = 0; n < QuplsPkg::PREGS; n = n + 1)
		lvt[n] <= 'd0;
end
else begin
	if (wr0) lvt[wa0] <= 2'd0;
	if (wr1) lvt[wa1] <= 2'd1;
	if (wr2) lvt[wa2] <= 2'd2;
	if (wr3) lvt[wa3] <= 2'd3;
end

generate begin : gRFO
	for (g = 0; g < RPORTS; g = g + 1) begin
		always_comb
			o[g] = ra[g][5:0]==6'd0 ? {WID{1'b0}} :
				(wr3 && (ra[g]==wa3)) ? i3 :
				(wr2 && (ra[g]==wa2)) ? i2 :
				(wr1 && (ra[g]==wa1)) ? i1 :
				(wr0 && (ra[g]==wa0)) ? i0 :
					lvt[ra[g]]==2'd3 ? o3[g] :
					lvt[ra[g]]==2'd2 ? o2[g] :
					lvt[ra[g]]==2'd1 ? o1[g] :
					o0[g];
	end
end
endgenerate

endmodule
