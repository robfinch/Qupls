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
// 3. Neither the name of the copyright ener nor the names of its
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
// - zero latency
//
// 1650 LUTs
// ============================================================================

import QuplsPkg::*;

module Qupls_ins_lengths_L0(rst_i, hit_i, hit_o, line_i, line_o,
	pc_i, pc_o, grp_i, grp_o, len0_o, len1_o, len2_o, len3_o, len4_o, len5_o, len6_o);
input rst_i;
input hit_i;
output reg hit_o;
input [1023:0] line_i;
output reg [1023:0] line_o;
input pc_address_t pc_i;
output pc_address_t pc_o;
input [2:0] grp_i;
output reg [2:0] grp_o;
output reg [4:0] len0_o;
output reg [4:0] len1_o;
output reg [4:0] len2_o;
output reg [4:0] len3_o;
output reg [4:0] len4_o;
output reg [4:0] len5_o;
output reg [4:0] len6_o;

genvar g;

wire [4:0] len [0:11];

generate begin : gInsLen
	for (g = 0; g < 12; g = g + 1)
		Qupls_ins_length uiln0 (opcode_t'(line_i[g*40+6:g*40]), len[g]);
end
endgenerate

always_comb if (rst_i) hit_o = 1'b0; else hit_o = hit_i;
always_comb if (rst_i) grp_o = 'd0; else grp_o = grp_i;

always_comb if (rst_i) pc_o = RSTPC; else pc_o = pc_i;
always_comb if (rst_i) line_o = {1024{1'b1}}; else line_o = line_i;
always_comb if (rst_i) len0_o = 5'd1; else len0_o = len[pc_i[5:0]];
always_comb if (rst_i) len1_o = 5'd1; else len1_o = len[pc_i[5:0] + len0_o];
always_comb if (rst_i) len2_o = 5'd1; else len2_o = len[pc_i[5:0] + len0_o + len1_o];
always_comb if (rst_i) len3_o = 5'd1; else len3_o = len[pc_i[5:0] + len0_o + len1_o + len2_o];
always_comb if (rst_i) len4_o = 5'd1; else len4_o = len[pc_i[5:0] + len0_o + len1_o + len2_o + len3_o];
always_comb if (rst_i) len5_o = 5'd1; else len5_o = len[pc_i[5:0] + len0_o + len1_o + len2_o + len3_o + len4_o];
always_comb if (rst_i) len6_o = 5'd1; else len6_o = len[pc_i[5:0] + len0_o + len1_o + len2_o + len3_o + len4_o + len5_o];

endmodule
