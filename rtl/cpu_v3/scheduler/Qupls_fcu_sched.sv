// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
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

import QuplsPkg::*;

module Qupls_fcu_sched(fcu_idle, robentry_islot, could_issue, 
	head, rob, robentry_fcu_issue, entry0, entry0v);
parameter WINDOW_SIZE = 16;
input fcu_idle;
output reg [1:0] robentry_islot [0:ROB_ENTRIES-1];
input rob_bitmask_t could_issue;
input rob_ndx_t head;
input rob_entry_t [ROB_ENTRIES-1:0] rob;
output rob_bitmask_t robentry_fcu_issue;
output rob_ndx_t entry0;
output reg entry0v;

integer n,m;
rob_ndx_t [WINDOWS_SIZE-1:0] heads;

always_comb
for (m = 0; m < WINDOW_SIZE; m = m + 1)
	heads[m] = (head + m) % ROB_ENTRIES;

// FPGAs do not handle race loops very well.
// The (old) simulator didn't handle the asynchronous race loop properly in the 
// original code. It would issue two instructions to the same islot. So the
// issue logic has been re-written to eliminate the asynchronous loop.
// Can't issue to the ALU if it's busy doing a long running operation like a 
// divide.
// ToDo: fix the memory synchronization, see fp_issue below

reg issued0, no_issue0;
integer hd, synchd, shd, slot;

always_comb
begin
	issued0 = 'd0;
	no_issue0 = 'd0;
	robentry_fcu_issue = 'd0;
	entry0 = 'd0;
	entry0v = 'd0;
	for (n = 0; n < ROB_ENTRIES; n = n + 1) begin
		robentry_islot[n] = 2'b00;
		if (fcu_idle) begin
			for (hd = 0; hd < WINDOW_SIZE; hd = hd + 1) begin
				if (!issued0 && could_issue[heads[hd]] && rob[heads[hd]].decbus.fc) begin
					// Search for a preceding sync instruction. If there is one then do
					// not issue.
					for (shd = 0; shd < ROB_ENTRIES; shd = shd + 1) begin
						if (rob[shd].v & rob[shd].decbus.sync && rob[shd].sn < rob[heads[hd]].sn)
							no_issue0 = 1'b1;
					end
					if (!no_issue0) begin
				  	robentry_fcu_issue[heads[hd]] = 1'b1;
				  	robentry_islot[heads[hd]] = 2'b00;
				  	issued0 = 1'b1;
				  	entry0 = heads[hd];
				  	entry0v = 1'b1;
					end
				end
			end
		end
	end

end

endmodule