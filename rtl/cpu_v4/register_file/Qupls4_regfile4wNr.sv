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
// 7000 LUTs / 520 FFs / 96 BRAMs (4w16r) - 64 bit
// 9275 LUTs / 1050 FFs / 72 BRAMs (4wr12) - 64 bit
// ============================================================================
//
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_regfile4wNr(rst, clk, ip,
	wr0, wr1, wr2, wr3, we0, we1, we2, we3,
	wa0, wa1, wa2, wa3,
	i0, i1, i2, i3,
	ti0, ti1, ti2, ti3,
	ra, o, to);
parameter WID = $bits(cpu_types_pkg::value_t)+$bits(Qupls4_pkg::flags_t);
parameter DEP = Qupls4_pkg::PREGS;
parameter BWW = 8;
parameter RBIT = $clog2(DEP)-1;
parameter RPORTS = 12;
input rst;
input clk;
input cpu_types_pkg::pc_address_t ip;
input wr0;
input wr1;
input wr2;
input wr3;
input [WID/BWW:0] we0;
input [WID/BWW:0] we1;
input [WID/BWW:0] we2;
input [WID/BWW:0] we3;
input cpu_types_pkg::pregno_t wa0;
input cpu_types_pkg::pregno_t wa1;
input cpu_types_pkg::pregno_t wa2;
input cpu_types_pkg::pregno_t wa3;
input cpu_types_pkg::value_t i0;
input cpu_types_pkg::value_t i1;
input cpu_types_pkg::value_t i2;
input cpu_types_pkg::value_t i3;
input Qupls4_pkg::flags_t ti0;
input Qupls4_pkg::flags_t ti1;
input Qupls4_pkg::flags_t ti2;
input Qupls4_pkg::flags_t ti3;
input cpu_types_pkg::pregno_t [RPORTS-1:0] ra;
output cpu_types_pkg::value_t [RPORTS-1:0] o;
output Qupls4_pkg::flags_t [RPORTS-1:0] to;

cpu_types_pkg::value_t [RPORTS-1:0] o0 [0:3];
Qupls4_pkg::flags_t [RPORTS-1:0] to0 [0:3];

reg [3:0] wr;
reg [WID/BWW-1:0] we [0:3];
reg [RBIT:0] wa [0:3];
cpu_types_pkg::value_t [3:0] i;
reg [3:0] wt;
flags_t [3:0] ti;

always_comb wr[0] = wr0;
always_comb wr[1] = wr1;
always_comb wr[2] = wr2;
always_comb wr[3] = wr3;
always_comb we[0] = we0;
always_comb we[1] = we1;
always_comb we[2] = we2;
always_comb we[3] = we3;
always_comb wa[0] = wa0;
always_comb wa[1] = wa1;
always_comb wa[2] = wa2;
always_comb wa[3] = wa3;
always_comb i[0] = i0;
always_comb i[1] = i1;
always_comb i[2] = i2;
always_comb i[3] = i3;
always_comb ti[0] = ti0;
always_comb ti[1] = ti1;
always_comb ti[2] = ti2;
always_comb ti[3] = ti3;

integer n;
genvar g;

// Live value table
reg [1:0] lvt [Qupls4_pkg::PREGS-1:0];

always_ff @(posedge clk)
if (rst) begin
	for (n = 0; n < Qupls4_pkg::PREGS; n = n + 1)
		lvt[n] <= 2'd0;
end
else begin
	if (wr0) lvt[wa0] <= 2'd0;
	if (wr1) lvt[wa1] <= 2'd1;
	if (wr2) lvt[wa2] <= 2'd2;
	if (wr3) lvt[wa3] <= 2'd3;
end


generate begin : gRF
	for (g = 0; g < RPORTS; g = g + 1) begin
		Qupls4_regfileRam #(.WID(WID)) urf0 (
		  .clka(clk),
		  .ena(wr[0]),
		  .wea(we[0]),
		  .addra(wa[0]),
		  .dina({ti[0],i[0]}),
		  .clkb(~clk),
		  .rstb(1'b0),
		  .enb(1'b1),
		  .addrb(ra[g]),
		  .doutb({to0[0][g],o0[0][g]})
		);

		Qupls4_regfileRam #(.WID(WID)) urf1 (
		  .clka(clk),
		  .ena(wr[1]),
		  .wea(we[1]),
		  .addra(wa[1]),
		  .dina({ti[1],i[1]}),
		  .rstb(1'b0),
		  .clkb(~clk),
		  .enb(1'b1),
		  .addrb(ra[g]),
		  .doutb({to0[1][g],o0[1][g]})
		);

		Qupls4_regfileRam #(.WID(WID)) urf2 (
		  .clka(clk),
		  .ena(wr[2]),
		  .wea(we[2]),
		  .addra(wa[2]),
		  .dina({ti[2],i[2]}),
		  .rstb(1'b0),
		  .clkb(~clk),
		  .enb(1'b1),
		  .addrb(ra[g]),
		  .doutb({to0[2][g],o0[2][g]})
		);

		Qupls4_regfileRam #(.WID(WID)) urf3 (
		  .clka(clk),
		  .ena(wr[3]),
		  .wea(we[3]),
		  .addra(wa[3]),
		  .dina({ti[3],i[3]}),
		  .rstb(1'b0),
		  .clkb(~clk),
		  .enb(1'b1),
		  .addrb(ra[g]),
		  .doutb({to0[3][g],o0[3][g]})
		);
	end
end
endgenerate

generate begin : gRFO
	for (g = 0; g < RPORTS; g = g + 1) begin
		always_comb
			o[g] =
				// Physical register zero is zero, unless it is a predicate register
				// spec, in which case it is -1.
//				ara[g]==8'd0 ? value_zero :
				(wr3 && &we3[WID/BWW-1:0] && wa3 != 10'd0 && (ra[g]==wa3)) ? i3 :
				(wr2 && &we2[WID/BWW-1:0] && wa2 != 10'd0 && (ra[g]==wa2)) ? i2 :
				(wr1 && &we1[WID/BWW-1:0] && wa1 != 10'd0 && (ra[g]==wa1)) ? i1 :
				(wr0 && &we0[WID/BWW-1:0] && wa0 != 10'd0 && (ra[g]==wa0)) ? i0 :
				lvt[ra[g]]==3'd0 ? o0[0][g] :
				lvt[ra[g]]==3'd1 ? o0[1][g] :
				lvt[ra[g]]==3'd2 ? o0[2][g] :
				o0[3][g];
		always_comb
			to[g] =
//				ara[g]==8'd0 ? 1'b0 :
				(wr3 && &we3[WID/BWW-1:WID/BWW-2] && wa3 != 10'd0 && (ra[g]==wa3)) ? ti3 :
				(wr2 && &we2[WID/BWW-1:WID/BWW-2] && wa2 != 10'd0 && (ra[g]==wa2)) ? ti2 :
				(wr1 && &we1[WID/BWW-1:WID/BWW-2] && wa1 != 10'd0 && (ra[g]==wa1)) ? ti1 :
				(wr0 && &we0[WID/BWW-1:WID/BWW-2] && wa0 != 10'd0 && (ra[g]==wa0)) ? ti0 :
				lvt[ra[g]]==3'd0 ? to0[0][g] :
				lvt[ra[g]]==3'd1 ? to0[1][g] :
				lvt[ra[g]]==3'd2 ? to0[2][g] :
				to0[3][g];
		/*
		always_ff @(posedge clk)
			if (o[g] != cpu_types_pkg::value_zero && ra[g]==10'd0) begin
				$display("Qupls4 CPU: r0 is not zero.");
				$finish;
			end
		*/
	end
end
endgenerate

endmodule
