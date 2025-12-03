// ============================================================================
//        __
//   \\__/ o\    (C) 2025 Robert Finch, Waterloo
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
// Backout flag:
//
// If taking a branch, any following register mappings in the same group need
// to be backed out. This is regardless of whether a prediction was true or not.
// If there is a branch incorrectly predicted as taken, then the register
// mappings also need to be backed out.
// ============================================================================

import const_pkg::*;
import Qupls4_pkg::*;

module Qupls4_backout_flag(rst, clk, fcu_branch_resolved, fcu_rse, takb, 
	fcu_found_destination, backout);
input rst;
input clk;
input fcu_branch_resolved;
input Qupls4_pkg::reservation_station_entry_t fcu_rse;
input takb;
input fcu_found_destination;
output reg backout;

always_ff @(posedge clk)
if (rst)
	backout <= FALSE;
else begin
	backout <= FALSE;
	if (fcu_branch_resolved) begin
		case(1'b1)
		fcu_rse.bcc:
			// backout when !fcu_bt will be handled below, triggerred by restore
			if (takb && fcu_rse.bt)
				backout <= !fcu_found_destination;
		fcu_rse.ret,
		fcu_rse.eret,
		fcu_rse.bsr,
		fcu_rse.jsr:
			backout <= TRUE;
		default:
			;		
		endcase
	end
end

endmodule
