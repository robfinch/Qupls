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
//
// Compute a new tail position after a stomp.
// ============================================================================

import const_pkg::*;
import Stark_pkg::*;

module Stark_stail(head0, tail0, robentry_stomp, rob, stail);
input rob_ndx_t head0;
input rob_ndx_t tail0;
input [Stark_pkg::ROB_ENTRIES-1:0] robentry_stomp;
input Stark_pkg::rob_entry_t [Stark_pkg::ROB_ENTRIES-1:0] rob;
output rob_ndx_t stail;											// stomp tail

integer n5,n6,n7;
reg okay_to_move_tail;

// Reset the ROB tail pointer, if there is a head <-> tail collision move the
// head pointer back a few entries. These will have been already committed
// entries, so they will be skipped over.
// If there is an interrupt pending in the ROB do not move the tail.
always_comb
begin
	okay_to_move_tail = TRUE;
	n7 = 1'd0;
	stail = tail0;
	for (n5 = 0; n5 < Stark_pkg::ROB_ENTRIES; n5 = n5 + 1) begin
		if (rob[n5].op.hwi)
			okay_to_move_tail = FALSE;
	end
	if (okay_to_move_tail) begin
		for (n5 = 0; n5 < Stark_pkg::ROB_ENTRIES; n5 = n5 + 1) begin
			if (n5==0)
				n6 = Stark_pkg::ROB_ENTRIES - 1;
			else
				n6 = n5 - 1;
			if (robentry_stomp[n5] && !robentry_stomp[n6] && !n7) begin
				stail = (n5 + 3) % Stark_pkg::ROB_ENTRIES;
				stail[1:0] = 2'b00;
				n7 = 1'b1;
			end
		end
	end
end

endmodule
