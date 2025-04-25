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
// ============================================================================

import Stark_pkg::*;

module Stark_branchmiss_flag(rst, clk, brclass, trig, miss_det, miss_flag);
input rst;
input clk;
input Stark_pkg::brclass_t brclass;
input trig;
input miss_det;
output reg miss_flag;

// Branchmiss flag

always_ff @(posedge clk)
if (rst)
	miss_flag <= FALSE;
else begin
	miss_flag <= FALSE;		// pulse for only 1 cycle.
	if (trig) begin
		case(brclass)
		Stark_pkg::BRC_BCCR,
		Stark_pkg::BRC_BCCD,
		Stark_pkg::BRC_BCCC:
			miss_flag <= miss_det;
//		Stark_pkg::BRC_BL,
		Stark_pkg::BRC_BLRLR,
		Stark_pkg::BRC_BLRLC,
		Stark_pkg::BRC_RETR,
		Stark_pkg::BRC_RETC:
			miss_flag <= TRUE;
		default:
			miss_flag <= FALSE;
		endcase
	end
end

endmodule
