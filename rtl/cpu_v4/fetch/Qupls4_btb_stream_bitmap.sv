// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2026  Robert Finch, Waterloo
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

import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_btb_stream_bitmap(rst, clk, clk_en, ffz0, act_stream, free_stream,
	alloc_stream, new_stream, dep_stream, strm_bitmap, next_strm_bitmap);
parameter THREADS = Qupls4_pkg::THREADS;
parameter XSTREAMS = Qupls4_pkg::XSTREAMS;
input rst;
input clk;
input clk_en;
input [6:0] ffz0;
input cpu_types_pkg::pc_stream_t act_stream;
input alloc_stream;
input [XSTREAMS*THREADS-1:0] free_stream;
output cpu_types_pkg::pc_stream_t [THREADS-1:0] new_stream;
output reg [XSTREAMS-1:0] dep_stream [0:XSTREAMS-1];
output reg [XSTREAMS*THREADS-1:0] strm_bitmap;
output reg [XSTREAMS*THREADS-1:0] next_strm_bitmap;

integer n3,n4,n6;

generate begin : gStrmBitmap

always_ff @(posedge clk)
	if (rst)
		next_strm_bitmap <= {XSTREAMS*THREADS{1'b0}};
	else begin
		next_strm_bitmap <= strm_bitmap;
		for (n4 = 0; n4 < THREADS; n4 = n4 + 1)
			next_strm_bitmap[XSTREAMS*n4] <= 1'b1;
	end

always_ff @(posedge clk)
	if (rst) begin
		strm_bitmap <= {XSTREAMS*THREADS{1'b0}};
		strm_bitmap[1:0] <= 2'h3;
		if (THREADS>1) strm_bitmap[XSTREAMS*1+1:XSTREAMS*1] <= 2'h3;
		if (THREADS>2) strm_bitmap[XSTREAMS*2+1:XSTREAMS*2] <= 2'h3;
		if (THREADS>3) strm_bitmap[XSTREAMS*3+1:XSTREAMS*3] <= 2'h3;
	end
	else
		strm_bitmap <= next_strm_bitmap & ~free_stream;

always_ff @(posedge clk)
	if (rst)
		new_stream <= 5'd1;
	else begin
		if (clk_en & alloc_stream)
			new_stream[act_stream.thread] <= ffz0;
	end

always_ff @(posedge clk)
	if (clk_en) begin
		if (alloc_stream) begin
			// The active stream has a new dependency.
			dep_stream[act_stream.stream][ffz0] <= 1'b1;
			// new stream inherits all dependencies of the current one.
			dep_stream[ffz0] <= dep_stream[act_stream.stream];
			dep_stream[ffz0][ffz0] <= 1'b1;
		end
		foreach (dep_stream[n3]) begin
			for (n6 = 0; n6 < THREADS; n6 = n6 + 1)
				if (free_stream[n3+XSTREAMS*n6])
					dep_stream[n3] <= {XSTREAMS{1'b0}};
		end
	end
end
endgenerate

endmodule
