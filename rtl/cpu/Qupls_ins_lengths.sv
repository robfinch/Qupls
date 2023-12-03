// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
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
// Instruction Length Decode
// - pipelined into two clocks
//
// 1300 LUTs / 2500 FFs
// ============================================================================

import QuplsPkg::*;

module Qupls_ins_lengths(clk_i, line_i, line_o, pc_i, pc_o,
	len0_o, len1_o, len2_o, len3_o, len4_o, len5_o);
input clk_i;
input [1023:0] line_i;
output reg [1023:0] line_o;
input pc_address_t pc_i;
output pc_address_t pc_o;
output reg [4:0] len0_o;
output reg [4:0] len1_o;
output reg [4:0] len2_o;
output reg [4:0] len3_o;
output reg [4:0] len4_o;
output reg [4:0] len5_o;

genvar g;

wire clk = clk_i;
pc_address_t pcr, pcr2;
reg [1023:0] liner, liner2;
reg [4:0] len0, len0r2;
reg [4:0] len1, len1r2;
reg [4:0] len2, len2r2;
reg [4:0] len3;
reg [4:0] len4;
reg [4:0] len5;
reg [5:0] len012r2;
wire [4:0] len [0:63];
reg [4:0] lenr [0:63];
reg [4:0] lenr2 [0:63];
generate begin : gInsLen
	for (g = 0; g < 64; g = g + 1) begin
		Qupls_ins_length uiln0 (line_i[g*8+7:g*8], len[g]);
		always_ff @(posedge clk)
			lenr[g] <= len[g];
		always_ff @(posedge clk)
			lenr2[g] <= lenr[g];
	end
end
endgenerate

always_ff @(posedge clk)
	liner <= line_i;
always_ff @(posedge clk)
	liner2 <= liner;
always_ff @(posedge clk)
	pcr <= pc_i;
always_ff @(posedge clk)
	pcr2 <= pcr;

always_comb len0 = lenr[pcr[17:12]];
always_comb len1 = lenr[pcr[17:12]+len0];
always_comb len2 = lenr[pcr[17:12]+len0+len1];
always_ff @(posedge clk) len0r2 <= len0;
always_ff @(posedge clk) len1r2 <= len1;
always_ff @(posedge clk) len2r2 <= len2;
always_ff @(posedge clk) len012r2 <= len0 + len1 + len2;
always_comb len3 = lenr2[pcr2[17:12]+len012r2];
always_comb len4 = lenr2[pcr2[17:12]+len012r2+len3];
always_comb len5 = lenr2[pcr2[17:12]+len012r2+len3+len4];

always_ff @(posedge clk) pc_o <= pcr2;
always_ff @(posedge clk) line_o <= liner2;
always_ff @(posedge clk) len0_o <= len0r2;
always_ff @(posedge clk) len1_o <= len1r2;
always_ff @(posedge clk) len2_o <= len2r2;
always_ff @(posedge clk) len3_o <= len3;
always_ff @(posedge clk) len4_o <= len4;
always_ff @(posedge clk) len5_o <= len5;

endmodule
