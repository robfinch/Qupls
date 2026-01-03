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
// Compute the amount of space available in the queue.
// 160 LUTs
// ============================================================================

import Qupls4_pkg::*;

module Qupls4_lsq_queue_room(lsq, head, tail, room);
input lsq_entry_t [1:0] lsq [0:Qupls4_pkg::LSQ_ENTRIES-1];
input lsq_ndx_t head;
input lsq_ndx_t tail;
output reg [3:0] room;

integer n;
lsq_ndx_t t;
reg [3:0] enqueue_room;

always_comb
begin
	enqueue_room = 4'd0;
	t = tail;
	// Check to make sure queue at tail is possible.
	if (lsq[t.row][0].v==INV && lsq[t.row][1].v==INV) begin
		// If the head and tail are the same and pointing to invalid entries then
		// the queue must be empty.
		if (t.row==head.row)
			enqueue_room = Qupls4_pkg::LSQ_ENTRIES;
		else if (t.row > head.row)
			enqueue_room = t.row - head.row;
		else
			enqueue_room = Qupls4_pkg::LSQ_ENTRIES + t.row - head.row;
	end
end		

always_comb
	room = enqueue_room;

endmodule
