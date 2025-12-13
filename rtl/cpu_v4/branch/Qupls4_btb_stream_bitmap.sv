// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2025  Robert Finch, Waterloo
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
//  2450 LUTs / 1075 FFs / 0 BRAMs                           
// ============================================================================

import Qupls4_pkg::*;

module Qupls4_btb_stream_bitmap(rst, clk, clk_en, ffz0, act_stream, free_stream,
	alloc_stream, new_stream, dep_stream, strm_bitmap, next_strm_bitmap);
input rst;
input clk;
input clk_en;
input [6:0] ffz0;
input pc_stream_t act_stream;
input alloc_stream;
input [127:0] free_stream;
output pc_stream_t [3:0] new_stream;
output reg [31:0] dep_stream [0:31];
output reg [127:0] strm_bitmap;
output reg [127:0] next_strm_bitmap;

integer n3;

always_ff @(posedge clk)
if (rst) begin
	new_stream <= 5'd1;
	strm_bitmap <= 128'd0;
	strm_bitmap[ 1: 0] <= 2'h3;
	strm_bitmap[33:32] <= 2'h3;
	strm_bitmap[65:64] <= 2'h3;
	strm_bitmap[97:96] <= 2'h3;
end
else begin
	next_strm_bitmap <= strm_bitmap;
	next_strm_bitmap[ 0] <= 1'b1;
	next_strm_bitmap[32] <= 1'b1;
	next_strm_bitmap[64] <= 1'b1;
	next_strm_bitmap[96] <= 1'b1;
	if (clk_en & alloc_stream) begin
		new_stream[act_stream.thread] <= ffz0;
		// The active stream has a new dependency.
		dep_stream[act_stream.stream][ffz0] <= 1'b1;
		// new stream inherits all dependencies of the current one.
		dep_stream[ffz0] <= dep_stream[act_stream.stream];
		dep_stream[ffz0][ffz0] <= 1'b1;
	end
	if (clk_en) begin
		for (n3 = 0; n3 < 32; n3 = n3 + 1) begin
			if (free_stream[n3])
				dep_stream[n3] = 32'd0;
			if (free_stream[n3+32])
				dep_stream[n3] = 32'd0;
			if (free_stream[n3+64])
				dep_stream[n3] = 32'd0;
			if (free_stream[n3+96])
				dep_stream[n3] = 32'd0;
		end
		strm_bitmap <= next_strm_bitmap & ~free_stream;
	end
end

endmodule
