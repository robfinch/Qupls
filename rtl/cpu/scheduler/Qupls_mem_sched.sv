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

module Qupls_mem_sched(rst, clk, head, robentry_stomp, rob, lsq, memissue,
	ndx0, ndx1, ndx0v, ndx1v, islot_i, islot_o);
parameter WINDOW_SIZE = 12;
parameter LSQ_WINDOW_SIZE = 16;
input rst;
input clk;
input rob_ndx_t head;
input rob_bitmask_t robentry_stomp;
input rob_entry_t [ROB_ENTRIES-1:0] rob;
input lsq_entry_t [15:0] lsq;
input [1:0] islot_i [0:LSQ_ENTRIES-1];
input reg [1:0] islot_o [0:LSQ_ENTRIES-1];
output lsq_bitmask_t memissue;
output lsq_ndx_t ndx0;
output lsq_ndx_t ndx1;
output reg ndx0v;
output reg ndx1v;

integer m,hd,phd,n9,n10,n11;
rob_bitmask_t robentry_memready;
rob_ndx_t [WINDOW_SIZE-1:0] heads;
rob_bitmask_t robentry_memopsvalid;
reg [1:0] issued, mem_ready;
reg no_issue;
reg [1:0] stores;

always_comb
for (m = 0; m < WINDOW_SIZE; m = m + 1)
	heads[m] = (head + m) % ROB_ENTRIES;

always_comb
for (n9 = 0; n9 < ROB_ENTRIES; n9 = n9 + 1)
	robentry_memopsvalid[n9] = (rob[n9].argA_v & rob[n9].argB_v & (rob[n9].decbus.load|rob[n9].argC_v));

always_comb
for (n10 = 0; n10 < ROB_ENTRIES; n10 = n10 + 1)
  robentry_memready[n10] = (rob[n10].v
  		& robentry_memopsvalid[n10] 
//  		& ~robentry_memissue[n10] 
  		& ~rob[n10].done 
  		& lsq[rob[n10].lsqndx].tlb
//  		& ~rob[n10].out
  		&  rob[n10].lsq
  		& ~robentry_stomp[n10])
  		;

always_comb
begin
	issued = 'd0;
	no_issue = 'd0;
	mem_ready = 'd0;
	memissue = 'd0;
	ndx0 = 'd0;
	ndx1 = 'd0;
	ndx0v = 'd0;
	ndx1v = 'd0;
	stores = 'd0;
	islot_o = islot_i;
	for (hd = 0; hd < LSQ_WINDOW_SIZE; hd = hd + 1) begin
		if (issued < NDATA_PORTS) begin
			if (hd==0) begin
				if (robentry_memready[ lsq[hd].rndx ]) begin
					mem_ready = 2'd1;
					memissue[ lsq[hd].rndx ] =	1'b1;
					issued = 2'd1;
					ndx0 = hd;
					ndx0v = 1'b1;
					if (lsq[hd].store)
						stores = 2'd1;
					islot_o[hd] = 2'd0;
				end
			end
			// no preceding instruction is ready to go
			else if (mem_ready < NDATA_PORTS) begin
				if (robentry_memready[ lsq[hd].rndx ])
					mem_ready = mem_ready + 2'd1;
				if (!robentry_stomp[lsq[hd].rndx] && robentry_memready[ lsq[hd ].rndx] ) begin
					// Check previous instructions.
					for (phd = 0; phd < WINDOW_SIZE; phd = phd + 1) begin
						if (rob[heads[phd]].v && rob[heads[phd]].sn < rob[lsq[hd ].rndx].sn) begin
							// ... and there is no fence
//							if (lsq[heads[phd]].fence && rob[heads[phd]].decbus.immb[15:0]==16'hFF00)
//								no_issue = 1'b1;
							// ... and, if it is a SW, there is no chance of it being undone
							if (rob[heads[phd]].decbus.store && rob[heads[phd]].decbus.fc)
								no_issue = 1'b1;
							// ... and previous mem op without an address yet,
							if ((rob[heads[phd]].decbus.load|rob[heads[phd]].decbus.store) && !lsq[rob[heads[phd]].lsqndx].tlb)
								no_issue = 1'b1;
							// ... and there is no address-overlap with any preceding instruction
							if (lsq[rob[heads[phd]].lsqndx].padr[$bits(physical_address_t)-1:4]==lsq[hd].padr[$bits(physical_address_t)-1:4])
								no_issue = 1'b1;
						end
					end
				end
				if (stores > 2'd0 && lsq[hd].store)
					no_issue = 1'b1;
				if (!no_issue) begin
					mem_ready = mem_ready + 2'd1;
					memissue[ hd ] =	1'b1;
					issued = issued + 2'd1;
					if (mem_ready==2'd1) begin
						ndx1 = hd;
						ndx1v = 1'b1;
					end
					else begin
						ndx0 = hd;
						ndx0v = 1'b1;
					end
					if (lsq[hd].store)
						stores = stores + 2'd1;
					islot_o[hd] = mem_ready;
				end
			end
		end		
	end
end

endmodule
