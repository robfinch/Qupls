// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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
//
import Stark_pkg::*;

module Stark_mem_state(rst_i, clk_i, ack_i, set_ready_i, set_avail_i, state_o);
input rst_i;
input clk_i;
input ack_i;
input set_ready_i;
input set_avail_i;
output Stark_pkg::dram_state_t state_o;

always_ff @(posedge clk_i)
if (rst_i)
	state_o <= Stark_pkg::DRAMSLOT_AVAIL;
else begin
	case(state_o)
	Stark_pkg::DRAMSLOT_AVAIL:	;
	Stark_pkg::DRAMSLOT_READY:
		state_o <= Stark_pkg::DRAMSLOT_ACTIVE;
	Stark_pkg::DRAMSLOT_ACTIVE:
		if (ack_i)
			state_o <= Stark_pkg::DRAMSLOT_DELAY;
	Stark_pkg::DRAMSLOT_DELAY:
		state_o <= Stark_pkg::DRAMSLOT_AVAIL;
	endcase
	if (set_ready_i)
		state_o <= Stark_pkg::DRAMSLOT_READY;
	if (set_avail_i)
		state_o <= Stark_pkg::DRAMSLOT_AVAIL;
end

endmodule
