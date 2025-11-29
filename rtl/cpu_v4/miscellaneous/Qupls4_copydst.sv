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

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_copydst(rst, clk, rob, fcu_branch_resolved, fcu_idv, fcu_id, skip_list, takb,
	stomp, unavail_list, copydst);
input rst;		// not used
input clk;
input Qupls4_pkg::rob_entry_t [Qupls4_pkg::ROB_ENTRIES-1:0] rob;
input fcu_branch_resolved;
input fcu_idv;
input rob_ndx_t fcu_id;
input [Qupls4_pkg::ROB_ENTRIES-1:0] skip_list;
input takb;
input [Qupls4_pkg::ROB_ENTRIES-1:0] stomp;
output reg [Qupls4_pkg::PREGS-1:0] unavail_list;
output reg [Qupls4_pkg::ROB_ENTRIES-1:0] copydst;

integer n4;

// Copy-targets for when backout is not supported.
// additional logic for handling a branch miss (STOMP logic)
//
always_ff @(posedge clk)
begin
	unavail_list = {Qupls4_pkg::PREGS{1'b0}};
	for (n4 = 0; n4 < Qupls4_pkg::ROB_ENTRIES; n4 = n4 + 1) begin
		copydst[n4] = FALSE;
		if (!Qupls4_pkg::SUPPORT_BACKOUT) begin
			copydst[n4] = stomp[n4];
			if (fcu_idv && fcu_branch_resolved && skip_list[n4]) begin
				copydst[n4] = TRUE;
				unavail_list[rob[n4].op.nRd] = TRUE;
			end
		end

		if (Qupls4_pkg::SUPPORT_BACKOUT) begin
			if (fcu_idv && ((rob[fcu_id].decbus.br && takb) || rob[fcu_id].decbus.cjb)) begin
		 		if (rob[n4].grp==rob[fcu_id].grp && rob[n4].sn > rob[fcu_id].sn) begin
					copydst[n4] = TRUE;
					unavail_list[rob[n4].op.nRd] = TRUE;
		 		end
			end
			if (fcu_idv && fcu_branch_resolved && skip_list[n4]) begin
				copydst[n4] = TRUE;
				unavail_list[rob[n4].op.nRd] = TRUE;
			end
		end
		else begin
			if (fcu_idv && ((rob[fcu_id].decbus.br && takb))) begin
		 		if (rob[n4].grp==rob[fcu_id].grp && rob[n4].sn > rob[fcu_id].sn) begin
					copydst[n4] = TRUE;
		 		end
			end
			if (fcu_idv && rob[fcu_id].decbus.br && !takb) begin
		 		if (rob[n4].grp==rob[fcu_id].grp && rob[n4].sn > rob[fcu_id].sn) begin
					copydst[n4] = FALSE;
		 		end
			end
		end
	end
end

endmodule
