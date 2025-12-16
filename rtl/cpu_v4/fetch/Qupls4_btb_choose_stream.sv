// ============================================================================
//        __
//   \\__/ o\    (C) 2025  Robert Finch, Waterloo
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

import Qupls4_pkg::*;

module Qupls4_btb_choose_stream(rst, clk, thread_probability, is_buffered,
	act_stream, next_act_stream, strm_bitmap, pcs);
input rst;
input clk;
input [7:0] thread_probability [0:7];
input is_buffered;
input pc_stream_t act_stream;
output pc_stream_t next_act_stream;
input [Qupls4_pkg::XSTREAMS*Qupls4_pkg::THREADS-1:0] strm_bitmap;
input pc_address_ex_t [Qupls4_pkg::XSTREAMS*Qupls4_pkg::THREADS-1:0] pcs;

// Used to select streams "randomly"
wire [26:0] lfsro;
lfsr27 #(.WID(27)) ulfsr1(rst, clk, 1'b1, 1'b0, lfsro);

// Choose a fetch stream
// Threads may be disabled by setting the probability to zero.
integer n2;
reg [2:0] thrd;
always_comb
begin
	next_act_stream = {$bits(pc_stream_t){1'b0}};
	thrd = 0;
	for (n2 = 0; n2 < Qupls4_pkg::XSTREAMS*Qupls4_pkg::THREADS; n2 = n2 + 1) begin
		thrd = n2 >> $clog2(Qupls4_pkg::XSTREAMS);
		// Choose any stream of the thread at 1/8 probability to allow alternate
		// branch paths to be fetched. Happens only if the fetch is coming from a 
		// fetch buffer instead of the cache.
		if (is_buffered && strm_bitmap[n2] && (lfsro[7:0] < thread_probability[thrd] >> 3))
			next_act_stream = pc_stream_t'(n2);
		// Choose the primary stream of the thread according to probability,
		// this will override the selection of the alternate path.
		if (strm_bitmap[n2] && pcs[n2].stream==n2 &&
			(lfsro[7:0] < thread_probability[thrd]))
			next_act_stream = pc_stream_t'(n2);
	end
	// If nothing got choosen, keep with the same stream.
	if (next_act_stream=={$bits(pc_stream_t){1'b0}})
		next_act_stream = act_stream;
end

endmodule
