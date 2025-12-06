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
import fta_bus_pkg::*;
import QuplsMmupkg::*;
import QuplsPkg::*;
import Qupls_ptable_walker_pkg::*;

module Qupls_ptw_miss_queue(rst, clk, state, ptbr,
	commit0_id, commit0_idv, commit1_id, commit1_idv, commit2_id, commit2_idv,
	commit3_id, commit3_idv,
	tlb_miss, tlb_missadr, tlb_missasid, tlb_missid, tlb_missqn,
	in_que, ptw_vv, ptw_pv, ptw_ppv, tranbuf, miss_queue, sel_tran, sel_qe);

input rst;
input clk;
input Qupls_ptable_walker_pkg::ptw_state_t state;
input ptbr_t ptbr;
input rob_ndx_t commit0_id;
input commit0_idv;
input rob_ndx_t commit1_id;
input commit1_idv;
input rob_ndx_t commit2_id;
input commit2_idv;
input rob_ndx_t commit3_id;
input commit3_idv;
input tlb_miss;
input cpu_types_pkg::address_t tlb_missadr;
input cpu_types_pkg::asid_t tlb_missasid;
input rob_ndx_t tlb_missid;
input [1:0] tlb_missqn;
output reg in_que;
input ptw_vv;
input ptw_pv;
input ptw_ppv;
input ptw_tran_buf_t [15:0] tranbuf;
output ptw_miss_queue_t [MISSQ_SIZE-1:0] miss_queue;
input [5:0] sel_tran;
output reg [5:0] sel_qe;

integer nn,n1,n2,n3,n4,n5;
reg [2:0] lvla;
reg [12:0] pindex;
reg in_que1;
integer empty_qe;
integer dump_qe;

// Find out if the tlb miss is already in the miss queue.
always_comb
begin
	in_que1 = 1'b0;
	for (n1 = 0; n1 < MISSQ_SIZE; n1 = n1 + 1) begin
		if (miss_queue[n1].v) begin
			if (tlb_missasid==miss_queue[n1].asid && tlb_missadr==miss_queue[n1].adr)
				in_que1 = 1'b1;
		end
	end
end

// Find an empty queue entry.
always_comb
begin
	empty_qe = -1;
	if (tlb_miss && !in_que1) begin
		for (n2 = 0; n2 < MISSQ_SIZE; n2 = n2 + 1)
			if (~miss_queue[n2].v && empty_qe < 0)
				empty_qe = n2;
	end
end

// Select a miss queue entry to process.
always_comb
begin
	sel_qe = 6'h3f;
	for (n3 = 0; n3 < MISSQ_SIZE; n3 = n3 + 1)
		if (miss_queue[n3].v && |miss_queue[n3].bc && sel_qe[5] &&
			(miss_queue[n3].id==commit0_id && commit0_idv) ||
			(miss_queue[n3].id==commit1_id && commit1_idv) ||
			(miss_queue[n3].id==commit2_id && commit2_idv) ||
			(miss_queue[n3].id==commit3_id && commit3_idv)
		)	
			sel_qe = n3;
end

// Select a miss queue entry to remove.
always_comb
begin
	dump_qe = -1;
	for (n5 = 0; n5 < MISSQ_SIZE; n5 = n5 + 1)
		if (miss_queue[n5].v && |miss_queue[n5].bc && dump_qe < 0 &&
			(miss_queue[n5].id==commit0_id && !commit0_idv) ||
			(miss_queue[n5].id==commit1_id && !commit1_idv) ||
			(miss_queue[n5].id==commit2_id && !commit2_idv) ||
			(miss_queue[n5].id==commit3_id && !commit3_idv)
		)	
			dump_qe = n5;
end

// Computer page index for a given page level.

always_comb
if (~sel_tran[5])
	lvla = miss_queue[tranbuf[sel_tran].stk].lvl+3'd1;
else
	lvla = 3'd0;

always_comb
if (~sel_tran[5])
	pindex = miss_queue[tranbuf[sel_tran].stk].adr[31:16] >> (lvla * 4'd13);
else
	pindex = 13'd0;


always_ff @(posedge clk)
if (rst) begin
	for (nn = 0; nn < MISSQ_SIZE; nn = nn + 1)
		miss_queue[nn] <= 'd0;
	in_que <= FALSE;
end
else begin

	in_que <= FALSE;
	if (in_que1 && !in_que && tlb_miss)
		in_que <= 1'b1;

	// Capture miss
	if (empty_qe >= 0) begin
		if (!in_que1) begin
			$display("PTW: miss queue loaded, adr=%h", tlb_missadr);
			miss_queue[empty_qe].v <= 1'b1;
			miss_queue[empty_qe].o <= 1'b0;
			miss_queue[empty_qe].bc <= 1'b1;
			miss_queue[empty_qe].lvl <= ptbr.level;
			miss_queue[empty_qe].asid <= tlb_missasid;
			miss_queue[empty_qe].id <= tlb_missid;
			miss_queue[empty_qe].adr <= tlb_missadr;
			miss_queue[empty_qe].qn <= tlb_missqn;
			
			case(ptbr.level)
			3'd0:	miss_queue[empty_qe].tadr <= {ptbr.adr,3'd0} + {tlb_missadr[28:16],3'h0};
			3'd1:	miss_queue[empty_qe].tadr <= {ptbr.adr,3'd0} + {tlb_missadr[31:29],3'h0};
			default:	miss_queue[empty_qe].tadr <= 'd0;
			endcase
		end
	end

	case(state)
	Qupls_ptable_walker_pkg::IDLE:
		begin
			if (dump_qe >= 0) begin
				miss_queue[dump_qe].v <= 1'b0;
				miss_queue[dump_qe].o <= 1'b0;
				miss_queue[dump_qe].bc <= 1'b0;
			end
			if (ptw_pv & ~ptw_ppv && ~sel_qe[5]) begin
				if (miss_queue[sel_qe].lvl != 3'd7) begin
					$display("PTW: walk level=%d", miss_queue[sel_qe].lvl);
					miss_queue[sel_qe].bc <= 1'b0;
					miss_queue[sel_qe].o <= 1'b1;
					miss_queue[sel_qe].lvl <= miss_queue[sel_qe].lvl - 1;
				end
			end
		end
	default:
		;
	endcase

	// Search for ready translations and update the TLB.
	if (~sel_tran[5]) begin
		$display("PTW: selected tran:%d", sel_tran[4:0]);
		miss_queue[tranbuf[sel_tran].stk].bc <= 1'b1;
		// We're done if level zero processed.
		if (miss_queue[tranbuf[sel_tran].stk].lvl==3'd7) begin
			// Allow capture of new TLB misses.
			miss_queue[tranbuf[sel_tran].stk].v <= 1'b0;
			miss_queue[tranbuf[sel_tran].stk].o <= 1'b0;
			miss_queue[tranbuf[sel_tran].stk].bc <= 1'b0;
		end
		else
			miss_queue[tranbuf[sel_tran].stk].tadr <= {tranbuf[sel_tran].pte.ppn,pindex,3'b0};
	end
end

endmodule
