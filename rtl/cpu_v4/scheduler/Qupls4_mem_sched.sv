// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2026  Robert Finch, Waterloo
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
// 1500 LUTs / 60 FFs / 145 MHz
// ============================================================================

import const_pkg::*;
import Qupls4_pkg::*;

module Qupls4_mem_sched(rst, clk, lsq_head, cancel, seq_consistency,
	robentry_stomp, rob, lsq,
	memissue, ndx0, ndx1, ndx0v, ndx1v);
parameter WINDOW_SIZE = Qupls4_pkg::LSQ_ENTRIES;
parameter LSQ_WINDOW_SIZE = Qupls4_pkg::LSQ_ENTRIES;
input rst;
input clk;
input Qupls4_pkg::lsq_ndx_t lsq_head;
input Qupls4_pkg::rob_bitmask_t robentry_stomp;
input Qupls4_pkg::rob_bitmask_t cancel;
input seq_consistency;
input Qupls4_pkg::rob_entry_t [Qupls4_pkg::ROB_ENTRIES-1:0] rob;
input Qupls4_pkg::lsq_entry_t [1:0] lsq [0:Qupls4_pkg::LSQ_ENTRIES-1];
output Qupls4_pkg::rob_bitmask_t memissue;
output Qupls4_pkg::lsq_ndx_t ndx0;
output Qupls4_pkg::lsq_ndx_t ndx1;
output reg ndx0v;
output reg ndx1v;

integer col,row,rw,co;
reg [3:0] q;

Qupls4_pkg::rob_bitmask_t memready;		// mask of ready to go instructions.
Qupls4_pkg::lsq_ndx_t [LSQ_ENTRIES-1:0] lsq_heads;
reg [7:0] issued;											// which data port instruction issued on.
reg [7:0] stores;											// counts the number of stores issued.
rob_ndx_t rn;
wire is_fenced_out;
wire has_previous_memop;
wire has_previous_fc;
wire has_overlap;

Qupls4_pkg::lsq_ndx_t next_ndx0;
Qupls4_pkg::lsq_ndx_t next_ndx1;
reg next_ndx0v;
reg next_ndx1v;
Qupls4_pkg::lsq_ndx_t tmp_ndx;
Qupls4_pkg::rob_bitmask_t next_memissue;
reg [1:0] islot [0:Qupls4_pkg::LSQ_ENTRIES*2-1];
reg [1:0] next_islot [0:Qupls4_pkg::LSQ_ENTRIES*2-1];
reg [1:0] can_issue [0:Qupls4_pkg::LSQ_ENTRIES-1];

always_comb
if (WINDOW_SIZE > Qupls4_pkg::LSQ_ENTRIES) begin
	$display("Qupls4 CPU mem sched: bad WINDOW_SIZE %d > %d", WINDOW_SIZE, Qupls4_pkg::LSQ_ENTRIES);
	$finish;
end

// Detect if there is a non finished memory operation outstanding previous to
// this one. If sequential consistency is not necessary then the memory op
// does not need to be completed.

Qupls4_has_previous_memop uhpm1
(
	.id(rn),
	.rob(rob),
	.seq(seq_consistency),
	.has_previous_memop(has_previous_memop)
);

// Detect if a LSQ entry has an overlap with a previous LSQ entry. This need
// only check the LSQ where the addresses are located.
// First the load / store must be before the tested one.
// Then if the address is not generated yet, we do not know, so play it safe
// and assume it overlaps.
// Finally, check the physical address, this could be at cache-line alignment
// but for now, we use the alignment of the largest load / store, 16B.

// Note: needs a separate test for each LSQ entry! The following does not work!
Qupls4_has_overlapped_adr uhoa1
(
	.rob(rob),
	.lsq(lsq),
	.id(tmp_ndx),
	.has_overlap(has_overlap)
);

// Detect if there is a previous fence.
Qupls4_is_fenced_out uifo1
(
	.id(rn),
	.rob(rob),
	.is_fenced_out(is_fenced_out)
);

always_ff @(posedge clk)
foreach (lsq_heads[q]) begin
	lsq_heads[q].row <= (lsq_head.row + q) % Qupls4_pkg::LSQ_ENTRIES;
	lsq_heads[q].col <= 1'd0;
end

// We need only check the LSQ for valid operands.
// The A,B operands must have been valid for the entry to be placed in the LSQ.
// The C operand is only needed for stores.

Qupls4_memready umr1
(
	.rst(rst),
	.clk(clk),
	.rob(rob),
	.lsq(lsq),
	.cancel(cancel),
	.stomp(robentry_stomp),
	.memready(memready)
);

always_ff @(posedge clk)
begin
	for (rw = 0; rw < Qupls4_pkg::LSQ_ENTRIES; rw = rw + 1)
		for (co = 0; co < 2; co = co + 1)
			can_issue[rw][co] <= FALSE;
	foreach (rob[rn]) begin
		if (rob[rn].lsq) begin
			if (
				// Instruction must be ready to go
				 memready[rn] &&
				// and not already issued in previous cycle (takes a cycle for ROB to update)
				!memissue[rn] &&
				// and not stomped on
				!robentry_stomp[rn] &&
				// ... and previous mem op without an address yet, or not done
				!has_previous_memop &&
				// ... and is not fenced out
				!is_fenced_out &&
				// ... and, if it is a store, there is no chance of it being undone
				(lsq[rob[rn].lsqndx.row][rob[rn].lsqndx.col].store ? !rob[rn].fc_dep : TRUE)
				)
			begin
				can_issue[rob[rn].lsqndx.row][rob[rn].lsqndx.col] <= TRUE;
			end
		end
	end
end

always_comb
begin
	issued = 2'd0;
	next_memissue = 'd0;
	next_ndx0 = 5'd0;
	next_ndx1 = 5'd0;
	next_ndx0v = INV;
	next_ndx1v = INV;
	stores = 2'd0;
	next_islot = islot;
	for (row = 0; row < Qupls4_pkg::LSQ_ENTRIES; row = row + 1) begin
		for (col = 0; col < 2; col = col + 1) begin
			if (
				can_issue[lsq_heads[row].row][col] &&
				// ... and there is no address-overlap with any preceding instruction
//				!has_overlap &&
				// not issued too many instructions.
				issued < Qupls4_pkg::NDATA_PORTS
			) begin
				// Check for issued on port #0 only. Might not need this check here.
				if (rob[lsq[lsq_heads[row].row][col].rndx].op.decbus.mem0 ? issued==2'd0 : TRUE) begin
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
						next_memissue[ lsq[lsq_heads[row].row][col].rndx ] = TRUE;
						case(issued)
						0:
							begin
								next_ndx0 = lsq_heads[row];
								next_ndx0.col = col;
								next_ndx0v = VAL;
							end
						1:
						 	begin
								next_ndx1 = lsq_heads[row];
								next_ndx1.col = col;
								next_ndx1v = VAL;
							end
						default:	;
						endcase
						if (lsq[lsq_heads[row].row][col].store)
							stores = stores + 2'd1;
						next_islot[{row,col[0]}] = issued;
						issued = issued + 2'd1;
					end
				end
			end
		end		
	end
end

always_ff @(posedge clk)
if (rst) begin
	memissue <= {$bits(rob_entry_t){1'b0}};
	
	ndx0 <= 'd0;
	ndx1 <= 'd0;
	ndx0v <= INV;
	ndx1v <= INV;
	
	foreach(islot[i])
		islot[i] <= 2'd0;
end
else
begin
	memissue <= next_memissue;
	ndx0 <= next_ndx0;
	ndx1 <= next_ndx1;
	ndx0v <= next_ndx0v;
	ndx1v <= next_ndx1v;
	islot <= next_islot;
end

endmodule
