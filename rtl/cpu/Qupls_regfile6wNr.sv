`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2024  Robert Finch, Waterloo
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
// 6kLUTs / 3kFFs / 23 BRAMs (4w20r)
// The register file is time multiplexed and accessed four times using a five
// times CPU clock.
// ============================================================================
//
import QuplsPkg::*;

module Qupls_regfile6wNr(rst, clk,
	wr0, wr1, wr2, wr3, wr4, wr5, we0, we1, we2, we3, we4, we5,
	wa0, wa1, wa2, wa3, wa4, wa5,
	i0, i1, i2, i3, i4, i5,
	wt0, wt1, wt2, wt3, wt4, wt5, ti0, ti1, ti2, ti3, ti4, ti5,
	ra, o, to);
parameter WID = $bits(cpu_types_pkg::value_t);
parameter DEP = PREGS;
parameter RBIT = $clog2(DEP)-1;
parameter RPORTS = 20;
input rst;
input clk;
input wr0;
input wr1;
input wr2;
input wr3;
input wr4;
input wr5;
input we0;
input we1;
input we2;
input we3;
input we4;
input we5;
input [RBIT:0] wa0;
input [RBIT:0] wa1;
input [RBIT:0] wa2;
input [RBIT:0] wa3;
input [RBIT:0] wa4;
input [RBIT:0] wa5;
input cpu_types_pkg::value_t i0;
input cpu_types_pkg::value_t i1;
input cpu_types_pkg::value_t i2;
input cpu_types_pkg::value_t i3;
input cpu_types_pkg::value_t i4;
input cpu_types_pkg::value_t i5;
input wt0;
input wt1;
input wt2;
input wt3;
input wt4;
input wt5;
input ti0;
input ti1;
input ti2;
input ti3;
input ti4;
input ti5;
input cpu_types_pkg::pregno_t [RPORTS-1:0] ra;
output cpu_types_pkg::value_t [RPORTS-1:0] o;
output reg [RPORTS-1:0] to;

cpu_types_pkg::value_t [RPORTS-1:0] o0 [0:5];
reg [RPORTS-1:0] to0 [0:5];

reg [5:0] wr;
reg [5:0] we;
reg [RBIT:0] wa [0:5];
cpu_types_pkg::value_t [5:0] i;
reg [5:0] wt;
reg [5:0] ti;

always_comb wr[0] = wr0;
always_comb wr[1] = wr1;
always_comb wr[2] = wr2;
always_comb wr[3] = wr3;
always_comb wr[4] = wr4;
always_comb wr[5] = wr5;
always_comb we[0] = we0;
always_comb we[1] = we1;
always_comb we[2] = we2;
always_comb we[3] = we3;
always_comb we[4] = we4;
always_comb we[5] = we5;
always_comb wa[0] = wa0;
always_comb wa[1] = wa1;
always_comb wa[2] = wa2;
always_comb wa[3] = wa3;
always_comb wa[4] = wa4;
always_comb wa[5] = wa5;
always_comb i[0] = i0;
always_comb i[1] = i1;
always_comb i[2] = i2;
always_comb i[3] = i3;
always_comb i[4] = i4;
always_comb i[5] = i5;
always_comb wt[0] = wt0;
always_comb wt[1] = wt1;
always_comb wt[2] = wt2;
always_comb wt[3] = wt3;
always_comb wt[4] = wt4;
always_comb wt[5] = wt5;
always_comb ti[0] = ti0;
always_comb ti[1] = ti1;
always_comb ti[2] = ti2;
always_comb ti[3] = ti3;
always_comb ti[4] = ti4;
always_comb ti[5] = ti5;

genvar g;

// Live value table
reg [2:0] lvt [QuplsPkg::PREGS-1:0];

always_ff @(posedge clk)
if (rst) begin
	for (n = 0; n < QuplsPkg::PREGS; n = n + 1)
		lvt[n] <= 3'd0;
end
else begin
	if (wr0) lvt[wa0] <= 3'd0;
	if (wr1) lvt[wa1] <= 3'd1;
	if (wr2) lvt[wa2] <= 3'd2;
	if (wr3) lvt[wa3] <= 3'd3;
	if (wr4) lvt[wa4] <= 3'd4;
	if (wr5) lvt[wa5] <= 3'd5;
end


generate begin : gRF
	for (g = 0; g < RPORTS; g = g + 1) begin
		Qupls_regfileRam #(.WID(WID+1)) urf0 (
		  .clka(clk),
		  .ena(wr[0]),
		  .wea(we[0]),
		  .addra(wa[0]),
		  .dina({ti[0],i[0]}),
		  .clkb(~clk),
		  .enb(1'b1),
		  .addrb(ra[g]),
		  .doutb({to0[0][g],o0[0][g]})
		);
		Qupls_regfileRam #(.WID(WID+1)) urf1 (
		  .clka(clk),
		  .ena(wr[1]),
		  .wea(we[1]),
		  .addra(wa[1]),
		  .dina({ti[1],i[1]}),
		  .clkb(~clk),
		  .enb(1'b1),
		  .addrb(ra[g]),
		  .doutb({to0[1][g],o0[1][g]})
		);
		Qupls_regfileRam #(.WID(WID+1)) urf2 (
		  .clka(clk),
		  .ena(wr[2]),
		  .wea(we[2]),
		  .addra(wa[2]),
		  .dina({ti[2],i[2]}),
		  .clkb(~clk),
		  .enb(1'b1),
		  .addrb(ra[g]),
		  .doutb({to0[2][g],o0[2][g]})
		);
		Qupls_regfileRam #(.WID(WID+1)) urf3 (
		  .clka(clk),
		  .ena(wr[3]),
		  .wea(we[3]),
		  .addra(wa[3]),
		  .dina({ti[3],i[3]}),
		  .clkb(~clk),
		  .enb(1'b1),
		  .addrb(ra[g]),
		  .doutb({to0[3][g],o0[3][g]})
		);
		Qupls_regfileRam #(.WID(WID+1)) urf4 (
		  .clka(clk),
		  .ena(wr[4]),
		  .wea(we[4]),
		  .addra(wa[4]),
		  .dina({ti[4],i[4]}),
		  .clkb(~clk),
		  .enb(1'b1),
		  .addrb(ra[g]),
		  .doutb({to0[4][g],o0[4][g]})
		);
		Qupls_regfileRam #(.WID(WID+1)) urf5 (
		  .clka(clk),
		  .ena(wr[5]),
		  .wea(we[5]),
		  .addra(wa[5]),
		  .dina({ti[5],i[5]}),
		  .clkb(~clk),
		  .enb(1'b1),
		  .addrb(ra[g]),
		  .doutb({to0[5][g],o0[5][g]})
		);
	end
end
endgenerate

integer n;

generate begin : gRFO
	for (g = 0; g < RPORTS; g = g + 1) begin
		always_comb
			o[g] =
				(wr5 && we5 && wa5 != 10'd0 && (ra[g]==wa5)) ? i5 :
				(wr4 && we4 && wa4 != 10'd0 && (ra[g]==wa4)) ? i4 :
				(wr3 && we3 && wa3 != 10'd0 && (ra[g]==wa3)) ? i3 :
				(wr2 && we2 && wa2 != 10'd0 && (ra[g]==wa2)) ? i2 :
				(wr1 && we1 && wa1 != 10'd0 && (ra[g]==wa1)) ? i1 :
				(wr0 && we0 && wa0 != 10'd0 && (ra[g]==wa0)) ? i0 :
				lvt[ra[g]]==3'd0 ? o0[0][g] :
				lvt[ra[g]]==3'd1 ? o0[1][g] :
				lvt[ra[g]]==3'd2 ? o0[2][g] :
				lvt[ra[g]]==3'd3 ? o0[3][g] :
				lvt[ra[g]]==3'd4 ? o0[4][g] :
					o0[5][g];
		always_comb
			to[g] =
				(wt5 && we5 && wa5 != 10'd0 && (ra[g]==wa5)) ? ti5 :
				(wt4 && we4 && wa4 != 10'd0 && (ra[g]==wa4)) ? ti4 :
				(wt3 && we3 && wa3 != 10'd0 && (ra[g]==wa3)) ? ti3 :
				(wt2 && we2 && wa2 != 10'd0 && (ra[g]==wa2)) ? ti2 :
				(wt1 && we1 && wa1 != 10'd0 && (ra[g]==wa1)) ? ti1 :
				(wt0 && we0 && wa0 != 10'd0 && (ra[g]==wa0)) ? ti0 :
				lvt[ra[g]]==3'd0 ? to0[0][g] :
				lvt[ra[g]]==3'd1 ? to0[1][g] :
				lvt[ra[g]]==3'd2 ? to0[2][g] :
				lvt[ra[g]]==3'd3 ? to0[3][g] :
				lvt[ra[g]]==3'd4 ? to0[4][g] :
					to0[5][g];
		always_ff @(posedge clk)
			if (o[g] != cpu_types_pkg::value_zero && ra[g]==10'd0) begin
				$display("Q+: r0 is not zero.");
				$finish;
			end
	end
end
endgenerate

endmodule
