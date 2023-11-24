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

module Qupls_sched(alu0_idle, alu1_idle, fpu0_idle ,fpu1_idle, fcu_idle,
	agen0_idle, agen1_idle,
	robentry_islot, could_issue, 
	head, rob, robentry_issue, robentry_fpu_issue, robentry_fcu_issue,
	robentry_agen_issue,
	alu0_rndx, alu1_rndx, alu0_rndxv, alu1_rndxv,
	fpu0_rndx, fpu0_rndxv, fpu1_rndx, fpu1_rndxv, fcu_rndx, fcu_rndxv,
	agen0_rndx, agen1_rndx, agen0_rndxv, agen1_rndxv);
parameter WINDOW_SIZE = 16;
input alu0_idle;
input alu1_idle;
input fpu0_idle;
input fpu1_idle;
input fcu_idle;
input agen0_idle;
input agen1_idle;
output reg [1:0] robentry_islot [0:ROB_ENTRIES-1];
input rob_bitmask_t could_issue;
input rob_ndx_t head;
input rob_entry_t [ROB_ENTRIES-1:0] rob;
output rob_bitmask_t robentry_issue;
output rob_bitmask_t robentry_fpu_issue;
output rob_bitmask_t robentry_fcu_issue;
output rob_bitmask_t robentry_agen_issue;
output rob_ndx_t alu0_rndx;
output rob_ndx_t alu1_rndx;
output rob_ndx_t fpu0_rndx;
output rob_ndx_t fpu1_rndx;
output rob_ndx_t fcu_rndx;
output rob_ndx_t agen0_rndx;
output rob_ndx_t agen1_rndx;
output reg alu0_rndxv;
output reg alu1_rndxv;
output reg fpu0_rndxv;
output reg fpu1_rndxv;
output reg fcu_rndxv;
output reg agen0_rndxv;
output reg agen1_rndxv;

integer m;
rob_ndx_t [WINDOW_SIZE-1:0] heads;

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

reg issued_alu0, issued_alu1, issued_fpu0, issued_fpu1, issued_fcu, no_issue;
reg issued_agen0, issued_agen1;
integer hd, synchd, shd, slot;

always_comb
begin
	issued_alu0 = 'd0;
	issued_alu1 = 'd0;
	issued_fpu0 = 'd0;
	issued_fpu1 = 'd0;
	issued_fcu = 'd0;
	issued_agen0 = 'd0;
	issued_agen1 = 'd0;
	no_issue = 'd0;
	robentry_issue = 'd0;
	robentry_fpu_issue = 'd0;
	robentry_fcu_issue = 'd0;
	robentry_agen_issue = 'd0;
	alu0_rndx = 'd0;
	alu1_rndx = 'd0;
	fpu0_rndx = 'd0;
	fpu1_rndx = 'd0;
	fcu_rndx = 'd0;
	agen0_rndx = 'd0;
	agen1_rndx = 'd0;
	alu0_rndxv = 'd0;
	alu1_rndxv = 'd0;
	fpu0_rndxv = 'd0;
	fpu1_rndxv = 'd0;
	fcu_rndxv = 'd0;
	agen0_rndxv = 'd0;
	agen1_rndxv = 'd0;
	for (hd = 0; hd < WINDOW_SIZE; hd = hd + 1) begin
		robentry_islot[heads[hd]] = 2'b00;
		// Search for a preceding sync instruction. If there is one then do
		// not issue.
		for (shd = 0; shd < ROB_ENTRIES; shd = shd + 1) begin
			if (rob[shd].v & rob[shd].decbus.sync && rob[shd].sn < rob[heads[hd]].sn)
				no_issue = 1'b1;
		end
		if (!no_issue) begin
			if (could_issue[heads[hd]]) begin
				if (!issued_alu0 && alu0_idle && rob[heads[hd]].decbus.alu) begin
			  	robentry_issue[heads[hd]] = 1'b1;
			  	robentry_islot[heads[hd]] = 2'b00;
			  	issued_alu0 = 1'b1;
			  	alu0_rndx = heads[hd];
			  	alu0_rndxv = 1'b1;
				end
				if (NALU > 1) begin
					if (!issued_alu1 && alu1_idle && rob[heads[hd]].decbus.alu && !rob[heads[hd]].decbus.alu0) begin
				  	robentry_issue[heads[hd]] = 1'b1;
				  	robentry_islot[heads[hd]] = 2'b01;
				  	issued_alu1 = 1'b1;
				  	alu1_rndx = heads[hd];
				  	alu1_rndxv = 1'b1;
					end
				end
				if (NFPU > 0) begin
					if (!issued_fpu0 && fpu0_idle && rob[heads[hd]].decbus.fpu) begin
				  	robentry_fpu_issue[heads[hd]] = 1'b1;
				  	robentry_islot[heads[hd]] = 2'b00;
				  	issued_fpu0 = 1'b1;
				  	fpu0_rndx = heads[hd];
				  	fpu0_rndxv = 1'b1;
					end
				end
				if (NFPU > 1) begin
					if (!issued_fpu1 && fpu1_idle && rob[heads[hd]].decbus.fpu && !rob[heads[hd]].decbus.fpu0) begin
				  	robentry_fpu_issue[heads[hd]] = 1'b1;
				  	robentry_islot[heads[hd]] = 2'b01;
				  	issued_fpu1 = 1'b1;
				  	fpu1_rndx = heads[hd];
				  	fpu1_rndxv = 1'b1;
					end
				end
				if (!issued_fcu && fcu_idle && rob[heads[hd]].decbus.fc) begin
			  	robentry_fcu_issue[heads[hd]] = 1'b1;
			  	robentry_islot[heads[hd]] = 2'b00;
			  	issued_fcu = 1'b1;
			  	fcu_rndx = heads[hd];
			  	fcu_rndxv = 1'b1;
				end
				if (!issued_agen0 && agen0_idle && (rob[heads[hd]].decbus.load | rob[heads[hd]].decbus.store)) begin
					robentry_agen_issue[heads[hd]] = 1'b1;
			  	robentry_islot[heads[hd]] = 2'b00;
					issued_agen0 = 1'b1;
					agen0_rndx = heads[hd];
					agen0_rndxv = 1'b1;
				end
				if (NAGEN > 1) begin
					if (!issued_agen1 && agen1_idle && (rob[heads[hd]].decbus.load | rob[heads[hd]].decbus.store)) begin
						robentry_agen_issue[heads[hd]] = 1'b1;
				  	robentry_islot[heads[hd]] = 2'b01;
						issued_agen1 = 1'b1;
						agen1_rndx = heads[hd];
						agen1_rndxv = 1'b1;
					end
				end
			end
		end
	end

end

endmodule
