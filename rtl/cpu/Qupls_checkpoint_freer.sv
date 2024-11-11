// ============================================================================
//        __
//   \\__/ o\    (C) 2024  Robert Finch, Waterloo
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
import QuplsPkg::*;

module Qupls_checkpoint_freer(rst, clk, rob, free, chkpt);
input rst;
input clk;
input rob_entry_t [ROB_ENTRIES-1:0] rob;
output reg free;
output checkpt_ndx_t chkpt;

integer n3,n33;
reg cond;

// Search for instructions groups that are done or invalid. If there are any
// branches in the group, then free the checkpoint. All the branches must have
// resolved if all instructions are done or invalid.
// Take care not to free the checkpoint more than once.

function fnCond;
input rob_ndx_t n3;
input rob_entry_t [ROB_ENTRIES-1:0] rob;
begin
	fnCond =
			!rob[n3+0].chkpt_freed &&
			(&rob[n3+0].done || !rob[n3+0].v) &&
			(&rob[n3+1].done || !rob[n3+1].v) &&
			(&rob[n3+2].done || !rob[n3+2].v) &&
			(&rob[n3+3].done || !rob[n3+3].v) &&
			(rob[n3+0].decbus.br || 
			rob[n3+1].decbus.br ||
			rob[n3+2].decbus.br ||
			rob[n3+3].decbus.br)
			;
end
endfunction

always_ff @(posedge clk)
if (rst)
	free <= FALSE;
else begin
	free <= FALSE;
	for (n3 = 0; n3 < ROB_ENTRIES; n3 = n3 + 4) begin
		if (fnCond(n3,rob))
			free <= TRUE;
	end
end

always_ff @(posedge clk)
if (rst)
	chkpt <= 4'd0;
else begin
	for (n33 = 0; n33 < ROB_ENTRIES; n33 = n33 + 4) begin
		if (fnCond(n33,rob))
			chkpt <= rob[(n33+4)%ROB_ENTRIES].cndx;
	end
end

endmodule
