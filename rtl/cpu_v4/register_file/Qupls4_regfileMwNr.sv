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

module Qupls4_regfileMwNr(rst, clk, wr, we, wa, i, ti, ra, o, to);
parameter WID = $bits(cpu_types_pkg::value_t)+$bits(Qupls4_pkg::flags_t);
parameter DEP = Qupls4_pkg::PREGS;
parameter BWW = 8;
parameter RBIT = $clog2(DEP)-1;
parameter RPORTS = 12;
parameter WPORTS = 4;
input rst;
input clk;
input [WPORTS-1:0] wr;
input [WID/BWW:0] we [0:WPORTS-1];
input cpu_types_pkg::pregno_t [WPORTS-1:0] wa;
input cpu_types_pkg::value_t [WPORTS-1:0] i;
input Qupls4_pkg::flags_t [WPORTS-1:0] ti;
input cpu_types_pkg::pregno_t [RPORTS-1:0] ra;
output cpu_types_pkg::value_t [RPORTS-1:0] o;
output Qupls4_pkg::flags_t [RPORTS-1:0] to;

cpu_types_pkg::value_t [RPORTS-1:0] o0 [0:WPORTS-1];
Qupls4_pkg::flags_t [RPORTS-1:0] to0 [0:WPORTS-1];

integer n,n1;
genvar g,gv;

// Live value table
reg [2:0] lvt [Qupls4_pkg::PREGS-1:0];

always_ff @(posedge clk)
if (rst) begin
	for (n = 0; n < Qupls4_pkg::PREGS; n = n + 1)
		lvt[n] <= 2'd0;
end
else begin
	for (n = 0; n < WPORTS; n = n + 1)
		if (wr[n])
			lvt[wa[n]] <= n;
end

generate begin : gRF
	for (g = 0; g < RPORTS; g = g + 1) begin
		for (gv = 0; gv < WPORTS; gv = gv + 1) begin
			Qupls4_regfileRam #(.WID(WID)) urf0 (
			  .clka(clk),
			  .ena(wr[gv]),
			  .wea(we[gv]),
			  .addra(wa[gv]),
			  .dina({ti[gv],i[gv]}),
			  .clkb(~clk),
			  .rstb(1'b0),
			  .enb(1'b1),
			  .addrb(ra[g]),
			  .doutb({to0[gv][g],o0[gv][g]})
			);
		end
	end
end
endgenerate

generate begin : gRFO
	reg [WPORTS*2-1:0] cnd;
	value_t [RPORTS-1:0] val [0:WPORTS*2-1];
	flags_t [RPORTS-1:0] tag [0:WPORTS*2-1];

	for (g = 0; g < RPORTS; g = g + 1) begin
		for (gv = 0; gv < WPORTS*2; gv = gv + 1) begin
		always_comb
		begin
			if (gv >= WPORTS) begin
				cnd[gv] = wr[gv-WPORTS] && we[gv-WPORTS][WID/BWW-1:0] && ra[g]==wa[gv-WPORTS];
				val[gv][g] = i[gv-WPORTS];
				tag[gv][g] = ti[gv-WPORTS];
			end
			else begin
				cnd[gv] = lvt[ra[g]]==gv;
				val[gv][g] = o0[gv][g];
				tag[gv][g] = to0[gv][g];
			end
		end
		always_comb
		begin
			o[g] = o0[WPORTS-1][g];
			to[g] = to0[WPORTS-1][g];
			for (n1 = 0; n1 < WPORTS*2-1; n1 = n1 + 1)
				if (cnd[n1]) begin
					o[g] = val[n1][g];
					to[g] = tag[n1][g];
				end
			end
		end
	end
end
endgenerate

endmodule
