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
// 5000 LUTs / 32 FFs
// ============================================================================

import QuplsPkg::*;

module Qupls_mem_sched(rst, clk, head, robentry_stomp, rob_v, rob, robentry_memissue,
	ndx0, ndx1, ndx0v, ndx1v);
parameter WINDOW_SIZE = 12;
input rst;
input clk;
input rob_ndx_t head;
input rob_bitmask_t robentry_stomp;
input rob_bitmask_t rob_v;
input rob_entry_t [ROB_ENTRIES-1:0] rob;
output rob_bitmask_t robentry_memissue;
output rob_ndx_t ndx0;
output rob_ndx_t ndx1;
output reg ndx0v;
output reg ndx1v;

integer m,hd,phd,n9,n10;
rob_bitmask_t robentry_memready;
rob_bitmask_t robentry_memissue1;
rob_ndx_t [WINDOW_SIZE-1:0] heads;
rob_bitmask_t robentry_memopsvalid;
reg [1:0] issued, mem_ready;
reg no_issue;
reg [1:0] stores;

always_comb
for (m = 0; m < WINDOW_SIZE; m = m + 1)
	heads[m] = (head + m) % ROB_ENTRIES;

always_ff @(posedge clk)
	robentry_memissue <= robentry_memissue1;

always_comb
for (n9 = 0; n9 < ROB_ENTRIES; n9 = n9 + 1)
	robentry_memopsvalid[n9] = (rob[n9].argA_v & rob[n9].argB_v & (rob[n9].decbus.load|rob[n9].argC_v));

always_comb
for (n10 = 0; n10 < ROB_ENTRIES; n10 = n10 + 1)
  robentry_memready[n10] = (rob_v[n10]
  		& robentry_memopsvalid[n10] 
  		& ~robentry_memissue[n10] 
  		& ~rob[n10].done 
  		& ~rob[n10].out
  		&  rob[n10].tlb
  		& ~robentry_stomp[n10])
  		;

always_comb
begin
	issued = 'd0;
	no_issue = 'd0;
	mem_ready = 'd0;
	robentry_memissue1 = 'd0;
	ndx0 <= 'd0;
	ndx1 <= 'd0;
	ndx0v <= 'd0;
	ndx1v <= 'd0;
	stores = 'd0;
	for (hd = 0; hd < WINDOW_SIZE; hd = hd + 1) begin
		if (issued < 2'd2) begin
			if (hd==0) begin
				if (robentry_memready[ heads[hd] ]) begin
					mem_ready = 2'd1;
					robentry_memissue1[ heads[hd] ] =	1'b1;
					issued = 2'd1;
					ndx0 = heads[hd];
					ndx0v = 1'b1;
					if (rob[heads[hd]].decbus.store)
						stores = 2'd1;
				end
			end
			// no preceding instruction is ready to go
			else if (mem_ready < 2'd2) begin
				if (robentry_memready[ heads[hd] ])
					mem_ready = mem_ready + 2'd1;
				if (!robentry_stomp[heads[hd]] && robentry_memready[ heads[hd] ] ) begin
					// Check previous instructions.
					for (phd = 0; phd < WINDOW_SIZE; phd = phd + 1) begin
						if (rob[heads[phd]].v && rob[heads[phd]].sn < rob[heads[hd]].sn) begin
							// ... and there is no fence
							if (rob[heads[phd]].decbus.fence && rob[heads[phd]].decbus.immb[15:0]==16'hFF00)
								no_issue = 1'b1;
							// ... and, if it is a SW, there is no chance of it being undone
							if (rob[heads[hd]].decbus.store && rob[heads[phd]].decbus.fc)
								no_issue = 1'b1;
							// ... and previous mem op without an address yet,
							if ((rob[heads[phd]].decbus.load|rob[heads[phd]].decbus.store) && !rob[heads[phd]].agen)
								no_issue = 1'b1;
							// ... and there is no address-overlap with any preceding instruction
							if (rob[heads[phd]].padr[$bits(physical_address_t)-1:4]==rob[heads[hd]].padr[$bits(physical_address_t)-1:4])
								no_issue = 1'b1;
						end
					end
				end
				if (stores > 2'd0 && rob[heads[hd]].decbus.store)
					no_issue = 1'b1;
				if (!no_issue) begin
					mem_ready = mem_ready + 2'd1;
					robentry_memissue1[ heads[hd] ] =	1'b1;
					issued = issued + 2'd1;
					if (mem_ready==2'd1) begin
						ndx1 = heads[hd];
						ndx1v = 1'b1;
					end
					else begin
						ndx0 = heads[hd];
						ndx0v = 1'b1;
					end
					if (rob[heads[hd]].decbus.store)
						stores = stores + 2'd1;
				end
			end
		end		
	end
end

endmodule
