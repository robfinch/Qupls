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
// ============================================================================

import const_pkg::*;
import Qupls4_pkg::*;

module Qupls4_checkpoint_freer(rst, clk, pgh, free, chkpt, chkpt_gndx);
input rst;
input clk;
input Qupls4_pkg::pipeline_group_hdr_t [Qupls4_pkg::ROB_ENTRIES/4-1:0] pgh;
output reg free;
output cpu_types_pkg::checkpt_ndx_t chkpt;
output reg [5:0] chkpt_gndx;

integer n3,n33,n333;
reg cond;

// Search for instructions groups that are done or invalid. If there are any
// branches in the group, then free the checkpoint. All the branches must have
// resolved if all instructions are done or invalid.
// Take care not to free the checkpoint more than once.

function fnCond;
input [5:0] n3;
input Qupls4_pkg::pipeline_group_hdr_t [Qupls4_pkg::ROB_ENTRIES/4-1:0] pgh;
begin
	fnCond =
			!pgh[n3].chkpt_freed &&
			(pgh[n3].done || !pgh[n3].v) &&
			pgh[n3].has_branch
			;
end
endfunction

always_ff @(posedge clk)
if (rst)
	free <= FALSE;
else begin
	free <= FALSE;
	for (n3 = 0; n3 < Qupls4_pkg::ROB_ENTRIES/4; n3 = n3 + 1) begin
		if (fnCond(n3,pgh))
			free <= TRUE;
	end
end

always_ff @(posedge clk)
if (rst)
	chkpt <= 5'd0;
else begin
	for (n33 = 0; n33 < Qupls4_pkg::ROB_ENTRIES/4; n33 = n33 + 1) begin
		if (fnCond(n33,pgh))
			chkpt <= pgh[n33].cndx;
	end
end

always_ff @(posedge clk)
if (rst)
	chkpt_gndx <= 6'd0;
else begin
	for (n333 = 0; n333 < Qupls4_pkg::ROB_ENTRIES/4; n333 = n333 + 1) begin
		if (fnCond(n333,pgh))
			chkpt_gndx <= n333;
	end
end

endmodule
