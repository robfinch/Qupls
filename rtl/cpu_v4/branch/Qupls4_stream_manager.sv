// ============================================================================
//        __
//   \\__/ o\    (C) 2026  Robert Finch, Waterloo
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

import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_stream_manager(rst, clk, alloc, kept_stream, new_stream, dead_streams, stream_states);
input rst;
input clk;
input alloc;
input cpu_types_pkg::pc_stream_t kept_stream;
input cpu_types_pkg::pc_stream_t [THREADS-1:0] new_stream;
input [XSTREAMS-1:0] dead_streams;
output Qupls4_pkg::stream_state_t [XSTREAMS-1:0] stream_states;

integer n58;

// Stream state manager
always_ff @(posedge clk)
if (rst) begin
	foreach(stream_states[n58])
		stream_states[n58] <= Qupls4_pkg::STR_UNKNOWN;
	stream_states[5'd0] <= Qupls4_pkg::STR_DEAD;
	stream_states[5'd1] <= Qupls4_pkg::STR_ALIVE;
end
else begin
	foreach (dead_streams[n58])
		stream_states[n58] <= Qupls4_pkg::STR_DEAD;
	stream_states[kept_stream] <= Qupls4_pkg::STR_ALIVE;
	foreach (new_stream[n58])
		if (alloc)
			stream_states[new_stream[n58].stream] <= Qupls4_pkg::STR_UNKNOWN;
	foreach (stream_states[n58])
		if (stream_states[n58]==Qupls4_pkg::STR_DEAD)
			stream_states[n58] <= Qupls4_pkg::STR_UNKNOWN;
	stream_states[5'd0] <= Qupls4_pkg::STR_DEAD;
end


endmodule
