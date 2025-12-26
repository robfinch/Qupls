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
import Qupls4_pkg::*;

module Qupls4_mem_sched(rst, clk, head, lsq_head, cancel, seq_consistency,
	robentry_stomp, rob, lsq,
	memissue, ndx0, ndx1, ndx0v, ndx1v, islot_i, islot_o);
parameter WINDOW_SIZE = Qupls4_pkg::LSQ_ENTRIES;
parameter LSQ_WINDOW_SIZE = Qupls4_pkg::LSQ_ENTRIES;
input rst;
input clk;
input cpu_types_pkg::rob_ndx_t head;
input Qupls4_pkg::lsq_ndx_t lsq_head;
input Qupls4_pkg::rob_bitmask_t robentry_stomp;
input Qupls4_pkg::rob_bitmask_t cancel;
input seq_consistency;
input Qupls4_pkg::rob_entry_t [Qupls4_pkg::ROB_ENTRIES-1:0] rob;
input Qupls4_pkg::lsq_entry_t [1:0] lsq [0:Qupls4_pkg::LSQ_ENTRIES-1];
input [1:0] islot_i [0:Qupls4_pkg::LSQ_ENTRIES*2-1];
output reg [1:0] islot_o [0:Qupls4_pkg::LSQ_ENTRIES*2-1];
output Qupls4_pkg::rob_bitmask_t memissue;
output Qupls4_pkg::lsq_ndx_t ndx0;
output Qupls4_pkg::lsq_ndx_t ndx1;
output reg ndx0v;
output reg ndx1v;

integer m,n9r,n10,col,row,i,n9c;
reg [3:0] q;

Qupls4_pkg::rob_bitmask_t memready;		// mask of ready to go instructions.
rob_ndx_t [WINDOW_SIZE-1:0] heads;
Qupls4_pkg::lsq_bitmask_t [1:0] memopsvalid;
Qupls4_pkg::lsq_ndx_t [LSQ_WINDOW_SIZE-1:0] lsq_heads;
reg [1:0] issued;											// which data port instruction issued on.
reg [1:0] stores;		// counts the number of stores issued.

Qupls4_pkg::lsq_ndx_t next_ndx0;
Qupls4_pkg::lsq_ndx_t next_ndx1;
reg next_ndx0v;
reg next_ndx1v;
Qupls4_pkg::lsq_ndx_t tmp_ndx;
Qupls4_pkg::rob_bitmask_t next_memissue;
reg [1:0] next_islot_o [0:Qupls4_pkg::LSQ_ENTRIES*2-1];

always_comb
if (WINDOW_SIZE > Qupls4_pkg::LSQ_ENTRIES) begin
	$display("Qupls4 CPU mem sched: bad WINDOW_SIZE %d > %d", WINDOW_SIZE, Qupls4_pkg::LSQ_ENTRIES);
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
	foreach (rob[n])
		if (rob[n].v==VAL && rob[n].sn < rob[id].sn && rob[n].op.decbus.fc && rob[n].done!=2'b11)
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
	foreach (rob[n])
		if (rob[n].v==VAL && rob[n].sn < rob[id].sn && rob[n].op.decbus.mem && !rob[n].done[0] && (seq ? !rob[n].done[1]:1'b1))
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
// Two loads are allowed to overlap.

function fnHasPreviousOverlap;
input Qupls4_pkg::lsq_ndx_t id;
integer n,c;
begin
	fnHasPreviousOverlap = FALSE;
	for (n = 0; n < Qupls4_pkg::LSQ_ENTRIES; n = n + 1) begin
		for (c = 0; c < 2; c = c + 1) begin
			// If the instruction is done already, we do not care if a new one overlaps.
			if (!(&rob[lsq[n][c].rndx].done)) begin
				// We do not care about instructions coming after the one checked.
				if (lsq[n][c].sn < lsq[id.row][id.col].sn) begin
					// If the address is not generated, play safe.
					if (!lsq[n][c].agen)
						fnHasPreviousOverlap = TRUE;
					if (lsq[n][c].padr[$bits(physical_address_t)-1:4]==lsq[id.row][id.col].padr[$bits(physical_address_t)-1:4]) begin
						// Two loads can overlap
						if (!(lsq[n][c].load && lsq[id.row][id.col].load))
							fnHasPreviousOverlap = TRUE;
					end
				end
			end
		end
	end
end
endfunction

// Detect if there is a previous fence.
function fnHasPreviousFence;
input rob_ndx_t id;
integer n;
begin
	fnHasPreviousFence = FALSE;
	foreach(rob[n])
		if (rob[n].v==VAL && rob[n].sn < rob[id].sn && rob[n].op.decbus.fence && rob[n].op.decbus.immb[15:0]==16'hFF00)
			fnHasPreviousFence = TRUE;
end			
endfunction


always_ff @(posedge clk)
for (m = 0; m < WINDOW_SIZE; m = m + 1)
	heads[m] = (head + m) % Qupls4_pkg::ROB_ENTRIES;

always_ff @(posedge clk)
for (q = 0; q < LSQ_WINDOW_SIZE; q = q + 1) begin
	lsq_heads[q].row = (lsq_head.row + q) % Qupls4_pkg::LSQ_ENTRIES;
	lsq_heads[q].col = 'd0;
end

// We need only check the LSQ for valid operands.
// The A,B operands must have been valid for the entry to be placed in the LSQ.
// The C operand is only needed for stores.
always_comb
for (n9r = 0; n9r < Qupls4_pkg::LSQ_ENTRIES; n9r = n9r + 1)
	for (n9c = 0; n9c < 2; n9c = n9c + 1)
		memopsvalid[n9c][n9r] = lsq[n9r][n9c].v && lsq[n9r][n9c].agen && (lsq[n9r][n9c].load|lsq[n9r][n9c].datav);

always_ff @(posedge clk)
foreach (memready[n10])
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
	next_memissue = 'd0;
	next_ndx0 = 5'd0;
	next_ndx1 = 5'd0;
	next_ndx0v = 1'd0;
	next_ndx1v = 1'd0;
	tmp_ndx = 5'd0;
	stores = 2'd0;
	next_islot_o = islot_i;
	for (row = 0; row < LSQ_WINDOW_SIZE; row = row + 1) begin
		for (col = 0; col < 2; col = col + 1) begin
			tmp_ndx.row = row;
			tmp_ndx.col = col;
			if (
				// Instruction must be ready to go
				memready[lsq[lsq_heads[row].row][col].rndx] &&
				// and not already issued in previous cycle (takes a cycle for ROB to update)
				!memissue[lsq[lsq_heads[row].row][col].rndx] && 
				// and a valid entry
				lsq[lsq_heads[row].row][col].v==VAL &&
				// and not stomped on
				!robentry_stomp[lsq[lsq_heads[row].row][col].rndx] &&
				// The address must be generated
				lsq[lsq_heads[row].row][col].agen &&
				/*
				// ... and, if it is a store, there is no chance of it being undone
				(lsq[lsq_heads[row].row][col].store ? !fnHasPreviousFc(lsq[lsq_heads[row].row][col].rndx) : TRUE) && 
				// ... and previous mem op without an address yet, or not done
				!fnHasPreviousMem(lsq[lsq_heads[row].row][col].rndx,seq_consistency) &&
				// ... and there is no address-overlap with any preceding instruction
				!fnHasPreviousOverlap(tmp_ndx) &&
				*/
				// ... and is not fenced out
				!fnHasPreviousFence(lsq[lsq_heads[row].row][col].rndx) &&
				// not issued too many instructions.
				issued < Qupls4_pkg::NDATA_PORTS
			) begin
				// Check for issued on port #0 only. Might not need this check here.
				if (rob[lsq[lsq_heads[row].row][col].rndx].op.decbus.mem0 ? issued==2'd0 : 1'b1) begin
					/* Why the row 0 check?
					if (row==0) begin
						if (memready[ lsq[lsq_heads[row].row][col].rndx ] &&
							|lsq[lsq_heads[row].row][col].state &&
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
					*/
					if (lsq[lsq_heads[row].row][col].store ? stores < 2'd1 : TRUE) begin
						next_memissue[ lsq[lsq_heads[row].row][col].rndx ] = 1'b1;
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
	ndx0v <= 1'd0;
	ndx1v <= 1'd0;
	foreach(islot_o[i])
		islot_o[i] <= 2'd0;
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
