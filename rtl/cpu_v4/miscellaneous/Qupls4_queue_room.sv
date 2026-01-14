// ============================================================================
//        __
//   \\__/ o\    (C) 2024-2026  Robert Finch, Waterloo
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

module Qupls4_queue_room(rob, head0, tails, room);
input Qupls4_pkg::rob_entry_t [Qupls4_pkg::ROB_ENTRIES-1:0] rob;
input rob_ndx_t head0;
input rob_ndx_t [11:0] tails;
output reg [3:0] room;

reg [3:0] enqueue_room;

always_comb
begin
	enqueue_room = 4'd0;
	/*
	if (rob[tails[0]].v==INV && !rob[tails[0]].op.hwi &&
	 		rob[tails[1]].v==INV && !rob[tails[1]].op.hwi &&
	 		rob[tails[2]].v==INV && !rob[tails[2]].op.hwi &&
	 		rob[tails[3]].v==INV && !rob[tails[3]].op.hwi &&
	 		rob[tails[4]].v==INV && !rob[tails[4]].op.hwi)
		enqueue_room = 4'd4;
	if (tails[0]==head0) begin
		enqueue_room = 4'd0;
		if (rob[tails[0]].v==INV && !rob[tails[0]].op.hwi &&
		 		rob[tails[1]].v==INV && !rob[tails[1]].op.hwi &&
		 		rob[tails[2]].v==INV && !rob[tails[2]].op.hwi &&
		 		rob[tails[3]].v==INV && !rob[tails[3]].op.hwi &&
		 		rob[tails[4]].v==INV && !rob[tails[4]].op.hwi)
			enqueue_room = 4'd4;
	end
	if (tails[1]==head0 && 
		rob[tails[0]].v==INV && !rob[tails[0]].op.hwi &&
		rob[tails[1]].v==INV && !rob[tails[1]].op.hwi)
		enqueue_room = 4'd1;
	if (tails[2]==head0 &&
		rob[tails[0]].v==INV && !rob[tails[0]].op.hwi &&
		rob[tails[1]].v==INV && !rob[tails[1]].op.hwi &&
		rob[tails[2]].v==INV && !rob[tails[2]].op.hwi)
		enqueue_room = 4'd2;
	if (tails[3]==head0 &&
		rob[tails[0]].v==INV && !rob[tails[0]].op.hwi &&
		rob[tails[1]].v==INV && !rob[tails[1]].op.hwi &&
		rob[tails[2]].v==INV && !rob[tails[2]].op.hwi &&
		rob[tails[3]].v==INV && !rob[tails[3]].op.hwi)
		enqueue_room = 4'd3;
	*/
	if (
			rob[tails[0]].v==INV && !rob[tails[0]].op.hwi &&
			rob[tails[1]].v==INV && !rob[tails[1]].op.hwi &&
			rob[tails[2]].v==INV && !rob[tails[2]].op.hwi &&
			rob[tails[3]].v==INV && !rob[tails[3]].op.hwi
		) begin
		if (!(tails[0]==head0
			|| tails[1]==head0
			|| tails[2]==head0
			|| tails[3]==head0
			))
			enqueue_room = 4'd4;
	end
	if (
			rob[tails[0]].v==INV && !rob[tails[0]].op.hwi &&
			rob[tails[1]].v==INV && !rob[tails[1]].op.hwi &&
			rob[tails[2]].v==INV && !rob[tails[2]].op.hwi &&
			rob[tails[3]].v==INV && !rob[tails[3]].op.hwi &&
			rob[tails[4]].v==INV && !rob[tails[4]].op.hwi &&
			rob[tails[5]].v==INV && !rob[tails[5]].op.hwi &&
			rob[tails[6]].v==INV && !rob[tails[6]].op.hwi &&
			rob[tails[7]].v==INV && !rob[tails[7]].op.hwi
		) begin
		if (!(tails[0]==head0
			|| tails[1]==head0
			|| tails[2]==head0
			|| tails[3]==head0
			|| tails[4]==head0
			|| tails[5]==head0
			|| tails[6]==head0
			|| tails[7]==head0
			))
			enqueue_room = 4'd8;
	end
	/*
	if (
			rob[tails[0]].v==INV && !rob[tails[0]].op.hwi &&
			rob[tails[1]].v==INV && !rob[tails[1]].op.hwi &&
			rob[tails[2]].v==INV && !rob[tails[2]].op.hwi &&
			rob[tails[3]].v==INV && !rob[tails[3]].op.hwi &&
			rob[tails[4]].v==INV && !rob[tails[4]].op.hwi &&
			rob[tails[5]].v==INV && !rob[tails[5]].op.hwi &&
			rob[tails[6]].v==INV && !rob[tails[6]].op.hwi &&
			rob[tails[7]].v==INV && !rob[tails[7]].op.hwi &&
			rob[tails[8]].v==INV && !rob[tails[8]].op.hwi
		) begin
		if (!(tails[0]==head0
			|| tails[1]==head0
			|| tails[2]==head0
			|| tails[3]==head0
			|| tails[4]==head0
			|| tails[5]==head0
			|| tails[6]==head0
			|| tails[7]==head0
			|| tails[8]==head0
			))
			enqueue_room = 4'd9;
	end
	if (
			rob[tails[0]].v==INV && !rob[tails[0]].op.hwi &&
			rob[tails[1]].v==INV && !rob[tails[1]].op.hwi &&
			rob[tails[2]].v==INV && !rob[tails[2]].op.hwi &&
			rob[tails[3]].v==INV && !rob[tails[3]].op.hwi &&
			rob[tails[4]].v==INV && !rob[tails[4]].op.hwi &&
			rob[tails[5]].v==INV && !rob[tails[5]].op.hwi &&
			rob[tails[6]].v==INV && !rob[tails[6]].op.hwi &&
			rob[tails[7]].v==INV && !rob[tails[7]].op.hwi &&
			rob[tails[8]].v==INV && !rob[tails[8]].op.hwi &&
			rob[tails[9]].v==INV && !rob[tails[9]].op.hwi
			) begin
		if (!(tails[0]==head0
			|| tails[1]==head0
			|| tails[2]==head0
			|| tails[3]==head0
			|| tails[4]==head0
			|| tails[5]==head0
			|| tails[6]==head0
			|| tails[7]==head0
			|| tails[8]==head0
			|| tails[9]==head0
			))
			enqueue_room = 4'd10;
	end
	if (
			rob[tails[0]].v==INV && !rob[tails[0]].op.hwi &&
			rob[tails[1]].v==INV && !rob[tails[1]].op.hwi &&
			rob[tails[2]].v==INV && !rob[tails[2]].op.hwi &&
			rob[tails[3]].v==INV && !rob[tails[3]].op.hwi &&
			rob[tails[4]].v==INV && !rob[tails[4]].op.hwi &&
			rob[tails[5]].v==INV && !rob[tails[5]].op.hwi &&
			rob[tails[6]].v==INV && !rob[tails[6]].op.hwi &&
			rob[tails[7]].v==INV && !rob[tails[7]].op.hwi &&
			rob[tails[8]].v==INV && !rob[tails[8]].op.hwi &&
			rob[tails[9]].v==INV && !rob[tails[9]].op.hwi &&
			rob[tails[10]].v==INV && !rob[tails[10]].op.hwi
		) begin
		if (!(tails[0]==head0
			|| tails[1]==head0
			|| tails[2]==head0
			|| tails[3]==head0
			|| tails[4]==head0
			|| tails[5]==head0
			|| tails[6]==head0
			|| tails[7]==head0
			|| tails[8]==head0
			|| tails[9]==head0
			|| tails[10]==head0
			))
			enqueue_room = 4'd11;
	end
	*/
	if (
			rob[tails[0]].v==INV && !rob[tails[0]].op.hwi &&
			rob[tails[1]].v==INV && !rob[tails[1]].op.hwi &&
			rob[tails[2]].v==INV && !rob[tails[2]].op.hwi &&
			rob[tails[3]].v==INV && !rob[tails[3]].op.hwi &&
			rob[tails[4]].v==INV && !rob[tails[4]].op.hwi &&
			rob[tails[5]].v==INV && !rob[tails[5]].op.hwi &&
			rob[tails[6]].v==INV && !rob[tails[6]].op.hwi &&
			rob[tails[7]].v==INV && !rob[tails[7]].op.hwi &&
			rob[tails[8]].v==INV && !rob[tails[8]].op.hwi &&
			rob[tails[9]].v==INV && !rob[tails[9]].op.hwi &&
			rob[tails[10]].v==INV && !rob[tails[10]].op.hwi &&
			rob[tails[11]].v==INV && !rob[tails[11]].op.hwi
		) begin
		if (!(tails[0]==head0
			|| tails[1]==head0
			|| tails[2]==head0
			|| tails[3]==head0
			|| tails[4]==head0
			|| tails[5]==head0
			|| tails[6]==head0
			|| tails[7]==head0
			|| tails[8]==head0
			|| tails[9]==head0
			|| tails[10]==head0
			|| tails[11]==head0
			))
			enqueue_room = 4'd12;
	end
end

always_comb
	room = enqueue_room;

endmodule
