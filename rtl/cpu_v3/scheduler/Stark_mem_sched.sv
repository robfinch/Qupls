// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2025  Robert Finch, Waterloo
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

import const_pkg::*;
import Stark_pkg::*;

module Stark_mem_sched(rst, clk, head, lsq_head, cancel, robentry_stomp, rob, lsq,
	memissue, ndx0, ndx1, ndx0v, ndx1v, islot_i, islot_o);
parameter WINDOW_SIZE = Stark_pkg::LSQ_ENTRIES;
parameter LSQ_WINDOW_SIZE = Stark_pkg::LSQ_ENTRIES;
input rst;
input clk;
input rob_ndx_t head;
input Stark_pkg::lsq_ndx_t lsq_head;
input Stark_pkg::rob_bitmask_t robentry_stomp;
input Stark_pkg::rob_bitmask_t cancel;
input Stark_pkg::rob_entry_t [Stark_pkg::ROB_ENTRIES-1:0] rob;
input Stark_pkg::lsq_entry_t [1:0] lsq [0:Stark_pkg::LSQ_ENTRIES-1];
input [1:0] islot_i [0:Stark_pkg::LSQ_ENTRIES*2-1];
output reg [1:0] islot_o [0:Stark_pkg::LSQ_ENTRIES*2-1];
output Stark_pkg::rob_bitmask_t memissue;
output Stark_pkg::lsq_ndx_t ndx0;
output Stark_pkg::lsq_ndx_t ndx1;
output reg ndx0v;
output reg ndx1v;

integer m,n9r,n10,col,row,q,i,n9c;
Stark_pkg::rob_bitmask_t memready;
rob_ndx_t [WINDOW_SIZE-1:0] heads;
Stark_pkg::lsq_bitmask_t [1:0] memopsvalid;
Stark_pkg::lsq_ndx_t [LSQ_WINDOW_SIZE-1:0] lsq_heads;
reg [1:0] issued, mem_ready;
reg no_issue, do_issue;
reg no_issue1, no_issue2, no_issue3;
reg [1:0] stores;

Stark_pkg::lsq_ndx_t next_ndx0;
Stark_pkg::lsq_ndx_t next_ndx1;
reg next_ndx0v;
reg next_ndx1v;
Stark_pkg::lsq_ndx_t tmp_ndx;
Stark_pkg::rob_bitmask_t next_memissue;
reg [1:0] next_islot_o [0:Stark_pkg::LSQ_ENTRIES*2-1];

always_comb
if (WINDOW_SIZE > Stark_pkg::LSQ_ENTRIES) begin
	$display("StarkCPU mem sched: bad WINDOW_SIZE %d > %d", WINDOW_SIZE, Stark_pkg::LSQ_ENTRIES);
	$finish;
end

// Detect if there is a previous flow control operation. Stores need to know
// this as they cannot be done until it is guarenteed that the program flow
// will not change.

function fnHasPreviousFc;
input rob_ndx_t id;
integer n;
begin
	fnHasPreviousFc = FALSE;
	for (n = 0; n < Stark_pkg::ROB_ENTRIES; n = n + 1)
		if (rob[n].v==VAL && rob[n].sn < rob[id].sn && rob[n].decbus.fc && rob[n].done!=2'b11)
			fnHasPreviousFc = TRUE;
end
endfunction

// Detect if there is a non finished memory operation outstanding previous to
// this one. If sequential consistency is not necessary then the memory op
// does not need to be completed.

function fnHasPreviousMem;
input rob_ndx_t id;
input seq;		// Sequential consistency.
integer n;
begin
	fnHasPreviousMem = FALSE;
	for (n = 0; n < Stark_pkg::ROB_ENTRIES; n = n + 1)
		if (rob[n].v==VAL && rob[n].sn < rob[id].sn && rob[n].decbus.mem && !rob[n].done[0] && (seq ? !rob[n].done[1]:1'b1))
			fnHasPreviousMem = TRUE;
end
endfunction

// Detect if a LSQ entry has an overlap with a previous LSQ entry. This need
// only check the LSQ where the addresses are located.
// First the load / store must be before the tested one.
// Then if the address is not generated yet, we do not know, so play it safe
// and assume it overlaps.
// Finally, check the physical address, this could be at cache-line alignment
// but for now, we use the alignment of the largest load / store, 16B.

function fnHasPreviousOverlap;
input Stark_pkg::lsq_ndx_t id;
integer n,c;
begin
	fnHasPreviousOverlap = FALSE;
	for (n = 0; n < Stark_pkg::LSQ_ENTRIES; n = n + 1) begin
		for (c = 0; c < 2; c = c + 1) begin
			if (lsq[n][c].sn < lsq[id.row][id.col].sn) begin
				if (!lsq[n][c].agen)
					fnHasPreviousOverlap = TRUE;
				if (lsq[n][c].adr[$bits(physical_address_t)-1:4]==lsq[id.row][id.col].adr[$bits(physical_address_t)-1:4])
					fnHasPreviousOverlap = TRUE;
			end
		end
	end
end
endfunction

always_ff @(posedge clk)
for (m = 0; m < WINDOW_SIZE; m = m + 1)
	heads[m] = (head + m) % Stark_pkg::ROB_ENTRIES;

always_ff @(posedge clk)
for (q = 0; q < LSQ_WINDOW_SIZE; q = q + 1) begin
	lsq_heads[q].row = (lsq_head.row + q) % Stark_pkg::LSQ_ENTRIES;
	lsq_heads[q].col = 'd0;
end

// We need only check the LSQ for valid operands.
// The A,B operands must have been valid for the entry to be placed in the LSQ.
// The C operand is only needed for stores.
always_comb
for (n9r = 0; n9r < Stark_pkg::LSQ_ENTRIES; n9r = n9r + 1)
	for (n9c = 0; n9c < 2; n9c = n9c + 1)
		memopsvalid[n9c][n9r] = lsq[n9r][n9c].v && lsq[n9r][n9c].agen && (lsq[n9r][n9c].load|lsq[n9r][n9c].datav);

always_ff @(posedge clk)
for (n10 = 0; n10 < Stark_pkg::ROB_ENTRIES; n10 = n10 + 1)
  memready[n10] = (rob[n10].v
  		&& memopsvalid[rob[n10].lsqndx.col][rob[n10].lsqndx.row] 
//  		& ~robentry_memissue[n10] 
  		&& (rob[n10].done==2'b01) 
//  		& ~rob[n10].out
  		&&  rob[n10].lsq
  		&& !cancel[n10]
  		&& !robentry_stomp[n10])
  		;

always_comb
begin
	issued = 2'd0;
	do_issue = 1'd0;
	mem_ready = 1'd0;
	next_memissue = 'd0;
	next_ndx0 = 5'd0;
	next_ndx1 = 5'd0;
	next_ndx0v = 1'd0;
	next_ndx1v = 1'd0;
	tmp_ndx = 5'd0;
	stores = 1'd0;
	no_issue = 1'd0;
	next_islot_o = islot_i;
	for (row = 0; row < LSQ_WINDOW_SIZE; row = row + 1) begin
		for (col = 0; col < 2; col = col + 1) begin
			no_issue1 = 1'd0;
			no_issue2 = 1'd0;
			no_issue3 = 1'd0;
			// Check for issued on port #0 only. Might not need this check here.
			if (issued < Stark_pkg::NDATA_PORTS && rob[lsq[lsq_heads[row].row][col].rndx].decbus.mem0 ? issued==2'd0 : 1'b1) begin
				if (row==0) begin
					if (memready[ lsq[lsq_heads[row].row][col].rndx ] &&
						lsq[lsq_heads[row].row][col].v==VAL &&
						lsq[lsq_heads[row].row][col].agen
					) begin
						do_issue = 1'b1;
						if (lsq[lsq_heads[row].row][col].store && fnHasPreviousFc(lsq[lsq_heads[row].row][col].rndx))
							no_issue1 = 1'b1;
						if (!no_issue1) begin
							mem_ready = mem_ready + 2'd1;
							next_memissue[ lsq[lsq_heads[row].row][col].rndx ] =	1'b1;
							issued = 2'd1;
							next_ndx0 = lsq_heads[row];
							next_ndx0.col = col;
							next_ndx0v = 1'b1;
							if (lsq[lsq_heads[row].row][col].store)
								stores = stores + 2'd1;
							next_islot_o[{row,col[0]}] = 2'd0;
						end
					end
				end
				// no preceding instruction is ready to go
				else if (mem_ready < Stark_pkg::NDATA_PORTS) begin
					if (memready[ lsq[lsq_heads[row].row][col].rndx ] &&
						lsq[lsq_heads[row].row][col].v==VAL
					)
						mem_ready = mem_ready + 2'd1;
					if (!robentry_stomp[lsq[lsq_heads[row].row][col].rndx] &&
						memready[ lsq[lsq_heads[row].row][col].rndx])
					begin
						// Check previous instructions.
						if (lsq[lsq_heads[row].row][col].v==VAL && lsq[lsq_heads[row].row][col].agen) begin // && rob[heads[phd]].sn < rob[lsq[lsq_heads[row].row][col].rndx].sn) begin
							do_issue = 1'b1;
							// ... and there is no fence
//							if (lsq[heads[phd]].fence && rob[heads[phd]].decbus.immb[15:0]==16'hFF00)
//								no_issue = 1'b1;
							// ... and, if it is a store, there is no chance of it being undone
							if (lsq[lsq_heads[row].row][col].store && fnHasPreviousFc(lsq[lsq_heads[row].row][col].rndx))
								no_issue1 = 1'b1;
							// ... and previous mem op without an address yet, or not done
							if (fnHasPreviousMem(lsq[lsq_heads[row].row][col].rndx,1))
								no_issue2 = 1'b1;
							// ... and there is no address-overlap with any preceding instruction
							tmp_ndx.row = row;
							tmp_ndx.col = col;
							if (fnHasPreviousOverlap(tmp_ndx))
								no_issue3 = 1'b1;
						end
					end
					
					if (stores > 2'd0 && lsq[lsq_heads[row].row][col].store)
						no_issue = 1'b1;
					if (do_issue && !no_issue && !no_issue1 && !no_issue2 && !no_issue3) begin
						next_memissue[ lsq[lsq_heads[row].row][col].rndx ] =	1'b1;
						if (issued==2'd1) begin
							next_ndx1 = lsq_heads[row];
							next_ndx1.col = col;
							next_ndx1v = 1'b1;
						end
						else begin
							next_ndx0 = lsq_heads[row];
							next_ndx0.col = col;
							next_ndx0v = 1'b1;
						end
						if (lsq[lsq_heads[row].row][col].store)
							stores = stores + 2'd1;
						next_islot_o[{row,col[0]}] = issued;
						issued = issued + 2'd1;
//						mem_ready = mem_ready + 2'd1;
					end
				end
			end
		end		
	end
end

always_ff @(posedge clk)
if (rst) begin
	memissue <= 'd0;
	ndx0 <= 'd0;
	ndx1 <= 'd0;
	ndx0v <= 'd0;
	ndx1v <= 'd0;
	for (i = 0; i < Stark_pkg::LSQ_ENTRIES*2; i = i + 1)
		islot_o[i] <= 'd0;
end
else begin
	memissue <= next_memissue;
	ndx0 <= next_ndx0;
	ndx1 <= next_ndx1;
	ndx0v <= next_ndx0v;
	ndx1v <= next_ndx1v;
	islot_o <= next_islot_o;
end

endmodule
