`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2024-2025  Robert Finch, Waterloo
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
// 14100 LUTs / 512 FFs / 96 BRAMs (2w6r) - 512 x 512 bit
// ============================================================================
//
import Qupls5_pkg::*;

module Qupls5_regfile2wNr(rst, clk,
	wr0, wr1, we0, we1,
	wa0, wa1,
	i0, i1,
	ra, o);
parameter WID = $bits(cpu_types_pkg::octa_value_t);
parameter DEP = Qupls5_pkg::PREGS;
parameter BWW = 8;
parameter RBIT = $clog2(DEP)-1;
parameter RPORTS = 6;
input rst;
input clk;
input wr0;
input wr1;
input [WID/BWW:0] we0;
input [WID/BWW:0] we1;
input [RBIT:0] wa0;
input [RBIT:0] wa1;
input cpu_types_pkg::octa_value_t i0;
input cpu_types_pkg::octa_value_t i1;
input cpu_types_pkg::pregno_t [RPORTS-1:0] ra;
output cpu_types_pkg::octa_value_t [RPORTS-1:0] o;

cpu_types_pkg::octa_value_t [RPORTS-1:0] o0 [0:3];

reg [3:0] wr;
reg [WID/BWW-1:0] we [0:1];
reg [RBIT:0] wa [0:1];
cpu_types_pkg::octa_value_t [1:0] i;
reg [3:0] wt;
flags_t [3:0] ti;

always_comb wr[0] = wr0;
always_comb wr[1] = wr1;
always_comb we[0] = we0;
always_comb we[1] = we1;
always_comb wa[0] = wa0;
always_comb wa[1] = wa1;
always_comb i[0] = i0;
always_comb i[1] = i1;

integer n;
genvar g;

// Live value table
reg [Qupls5_pkg::PREGS-1:0] lvt;

always_ff @(posedge clk)
if (rst) begin
	for (n = 0; n < Qupls5_pkg::PREGS; n = n + 1)
		lvt[n] <= 2'd0;
end
else begin
	if (wr0) lvt[wa0] <= 1'd0;
	if (wr1) lvt[wa1] <= 1'd1;
end


generate begin : gRF
	for (g = 0; g < RPORTS; g = g + 1) begin
		Qupls5_regfile_ram #(.WID(WID)) urf0 (
		  .clka(clk),
		  .ena(wr[0]),
		  .wea(we[0]),
		  .addra(wa[0]),
		  .dina(i[0]),
		  .clkb(~clk),
		  .enb(1'b1),
		  .addrb(ra[g]),
		  .doutb(o0[0][g])
		);

		Qupls5_regfile_ram #(.WID(WID)) urf1 (
		  .clka(clk),
		  .ena(wr[1]),
		  .wea(we[1]),
		  .addra(wa[1]),
		  .dina(i[1]),
		  .clkb(~clk),
		  .enb(1'b1),
		  .addrb(ra[g]),
		  .doutb(o0[1][g])
		);
	end
end
endgenerate

generate begin : gRFO
	for (g = 0; g < RPORTS; g = g + 1) begin
		always_comb
			o[g] =
				(wr1 && &we1[WID/BWW-1:0] && wa1 != 10'd0 && (ra[g]==wa1)) ? i1 :
				(wr0 && &we0[WID/BWW-1:0] && wa0 != 10'd0 && (ra[g]==wa0)) ? i0 :
				lvt[ra[g]]==1'd0 ? o0[0][g] :
				o0[1][g];
	end
end
endgenerate

endmodule
