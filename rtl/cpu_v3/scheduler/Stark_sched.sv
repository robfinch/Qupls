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
// 9100 LUTs / 300 FFs (without PRED) WINDOW_SIZE = 12
// 9700 LUTs / 310 FFs (with PRED)
// ============================================================================

import const_pkg::*;
import Stark_pkg::*;

module Stark_sched(rst, clk, alu0_idle, alu1_idle, fpu0_idle ,fpu1_idle, fcu_idle,
	agen0_idle, agen1_idle, lsq0_idle, lsq1_idle,
	stomp_i, robentry_islot_i, robentry_islot_o,
	head, rob, robentry_issue, robentry_fpu_issue, robentry_fcu_issue,
	robentry_agen_issue,
	alu0_rndx, alu1_rndx, alu0_rndxv, alu1_rndxv,
	fpu0_rndx, fpu0_rndxv, fpu1_rndx, fpu1_rndxv,
	fcu_rndx, fcu_rndxv,
	agen0_rndx, agen1_rndx, cpytgt0, cpytgt1,
	agen0_rndxv, agen1_rndxv,
	ratv0_rndxv, ratv1_rndxv, ratv2_rndxv, ratv3_rndxv, 
	ratv0_rndx, ratv1_rndx, ratv2_rndx, ratv3_rndx,
	beb_buf, beb_issue
);
parameter WINDOW_SIZE = Stark_pkg::SCHED_WINDOW_SIZE;
input rst;
input clk;
input alu0_idle;
input alu1_idle;
input fpu0_idle;
input fpu1_idle;
input fcu_idle;
input agen0_idle;
input agen1_idle;
input lsq0_idle;
input lsq1_idle;
input [ROB_ENTRIES-1:0] stomp_i;
input [1:0] robentry_islot_i [0:Stark_pkg::ROB_ENTRIES-1];
output reg [1:0] robentry_islot_o [0:Stark_pkg::ROB_ENTRIES-1];
input rob_ndx_t head;
input Stark_pkg::rob_entry_t [Stark_pkg::ROB_ENTRIES-1:0] rob;
output Stark_pkg::rob_bitmask_t robentry_issue;
output Stark_pkg::rob_bitmask_t robentry_fpu_issue;
output Stark_pkg::rob_bitmask_t robentry_fcu_issue;
output Stark_pkg::rob_bitmask_t robentry_agen_issue;
output rob_ndx_t alu0_rndx;
output rob_ndx_t alu1_rndx;
output rob_ndx_t fpu0_rndx;
output rob_ndx_t fpu1_rndx;
output rob_ndx_t fcu_rndx;
output rob_ndx_t agen0_rndx;
output rob_ndx_t agen1_rndx;
output reg cpytgt0;
output reg cpytgt1;
output reg alu0_rndxv;
output reg alu1_rndxv;
output reg fpu0_rndxv;
output reg fpu1_rndxv;
output reg fcu_rndxv;
output reg agen0_rndxv;
output reg agen1_rndxv;
output rob_ndx_t ratv0_rndx;
output rob_ndx_t ratv1_rndx;
output rob_ndx_t ratv2_rndx;
output rob_ndx_t ratv3_rndx;
output reg ratv0_rndxv;
output reg ratv1_rndxv;
output reg ratv2_rndxv;
output reg ratv3_rndxv;
input Stark_pkg::beb_entry_t beb_buf;
output reg beb_issue;

reg [1:0] next_robentry_islot_o [0:Stark_pkg::ROB_ENTRIES-1];
Stark_pkg::rob_bitmask_t next_robentry_issue;
Stark_pkg::rob_bitmask_t next_robentry_fpu_issue;
Stark_pkg::rob_bitmask_t next_robentry_fcu_issue;
Stark_pkg::rob_bitmask_t next_robentry_agen_issue;
Stark_pkg::rob_bitmask_t next_multicycle_issue;
Stark_pkg::rob_bitmask_t multicycle_issue;
Stark_pkg::rob_bitmask_t next_prev_issue;
Stark_pkg::rob_bitmask_t prev_issue;
Stark_pkg::rob_bitmask_t prev_issue2;
Stark_pkg::rob_bitmask_t next_ratv_issue;
Stark_pkg::rob_bitmask_t ratv_issue;
Stark_pkg::rob_bitmask_t ratv_issue2;
reg next_beb_issue;

rob_ndx_t next_alu0_rndx;
rob_ndx_t next_alu1_rndx;
rob_ndx_t next_fpu0_rndx;
rob_ndx_t next_fpu1_rndx;
rob_ndx_t next_fcu_rndx;
rob_ndx_t next_agen0_rndx;
rob_ndx_t next_agen1_rndx;
reg next_alu0_rndxv;
reg next_alu1_rndxv;
reg next_fpu0_rndxv;
reg next_fpu1_rndxv;
reg next_fcu_rndxv;
reg next_agen0_rndxv;
reg next_agen1_rndxv;
rob_ndx_t next_ratv0_rndx;
rob_ndx_t next_ratv1_rndx;
rob_ndx_t next_ratv2_rndx;
rob_ndx_t next_ratv3_rndx;
reg next_ratv0_rndxv;
reg next_ratv1_rndxv;
reg next_ratv2_rndxv;
reg next_ratv3_rndxv;
reg next_cpytgt0;
reg next_cpytgt1;
Stark_pkg::rob_bitmask_t args_valid;
Stark_pkg::rob_bitmask_t could_issue, could_issue_nm;	//nm = no match
Stark_pkg::rob_bitmask_t next_could_issue;
Stark_pkg::beb_ndx_t next_beb_ndx;

genvar g;
integer m,n,h,q;
rob_ndx_t [WINDOW_SIZE-1:0] heads;

always_ff @(posedge clk)
for (m = 0; m < WINDOW_SIZE; m = m + 1)
	heads[m] = (head + m) % Stark_pkg::ROB_ENTRIES;

// Search for a prior load or store. This forces the load / store to be performed
// in program order.

function fnNoPriorLS;
input rob_ndx_t ndx;
begin
	fnNoPriorLS = 1'b1;
	for (n = 0; n < Stark_pkg::ROB_ENTRIES; n = n + 1)
		if ((rob[n].v && rob[n].sn < rob[ndx].sn) && rob[n].decbus.mem && !(&rob[heads[n]].done))
			fnNoPriorLS = 1'b0;
end
endfunction

function fnPriorPred;
input rob_ndx_t ndx;
begin
	fnPriorPred = FALSE;
	for (n = 0; n < Stark_pkg::ROB_ENTRIES; n = n + 1)
		if (rob[n].v && rob[n].sn < rob[ndx].sn && rob[n].decbus.pred && rob[n].done!=2'b11)
			fnPriorPred = TRUE;
end
endfunction

// Search for a prior flow control op. This forces flow control op to be performed
// in program order.

function fnPriorFC;
input rob_ndx_t ndx;
begin
	fnPriorFC = FALSE;
	for (n = 0; n < Stark_pkg::ROB_ENTRIES; n = n + 1)
		if (rob[n].v && rob[n].sn < rob[ndx].sn && rob[n].decbus.fc && !(&rob[n].done))
			fnPriorFC = TRUE;
end
endfunction

function fnPriorMem;
input rob_ndx_t ndx;
begin
	fnPriorMem = FALSE;
	for (n = 0; n < Stark_pkg::ROB_ENTRIES; n = n + 1)
		if (rob[n].v && rob[n].sn < rob[ndx].sn && rob[n].decbus.mem && !(&rob[n].done))
			fnPriorMem = TRUE;
end
endfunction

function fnPriorSync;
input rob_ndx_t ndx;
begin
	fnPriorSync = FALSE;
	for (n = 0; n < Stark_pkg::ROB_ENTRIES; n = n + 1)
		if (rob[n].v && rob[n].sn < rob[ndx].sn && rob[n].decbus.sync)
			fnPriorSync = TRUE;
end
endfunction

function fnPriorQFExt;
input rob_ndx_t id;
rob_ndx_t idm1;
begin
	fnPriorQFExt = FALSE;
	idm1 = (id + Stark_pkg::ROB_ENTRIES - 1) % Stark_pkg::ROB_ENTRIES;
	if (rob[idm1].decbus.qfext)
		fnPriorQFExt = TRUE;
end
endfunction

function fnPriorQFExtOut;
input rob_ndx_t id;
rob_ndx_t idm1;
begin
	fnPriorQFExtOut = FALSE;
	idm1 = (id + Stark_pkg::ROB_ENTRIES - 1) % Stark_pkg::ROB_ENTRIES;
	if (rob[idm1].out[0])
		fnPriorQFExtOut = fnPriorQFExt(id);
end
endfunction

// We evaluate match logic once for the entire ROB so the logic resouce is O(n).
// This code has been moved to Stark where it is pre-calculated and stored in
// the ROB.
// For a memory op arg C does not have to be valid before issue.
generate begin : issue_logic
for (g = 0; g < Stark_pkg::ROB_ENTRIES; g = g + 1) begin
/* Code moved to Stark
	assign args_valid[g] =
	 						 rob[g].argA_v
				    && rob[g].argB_v
				    && ((rob[g].argC_v) || (rob[g].decbus.mem)) // & ~rob[g].agen))
				    && rob[g].argT_v
				    && rob[g].argM_v
				    ;
*/				    
				    // If the predicate is known to be false, we do not care what the
				    // argument registers are, other than Rt. If the predicate is known
				    // to be true we do not need to wait for Rt.
				    // Do not issue to the same slot twice in a row, back-to-back. This
				    // could only happen when a new instruction happens to queue in the
				    // slot just finished executing. The new instruction would be
				    // incorrectly marked done, inheriting the status of the old one.
/* Code moved to Stark				    
always_comb
	next_could_issue[g] = rob[g].v
												&& !stomp_i[g]
												&& !(&rob[g].done)
												&& (rob[g].decbus.cpytgt ? (rob[g].argT_v) : args_valid[g])
												&& (rob[g].decbus.mem ? !fnPriorFC(g) : 1'b1)
												&& (SERIALIZE ? (rob[(g+ROB_ENTRIES-1)%ROB_ENTRIES].done==2'b11 || rob[(g+ROB_ENTRIES-1)%ROB_ENTRIES].v==INV) : 1'b1)
												//&& !fnPriorFalsePred(g)
												&& !fnPriorSync(g)
												&& |rob[g].pred_bits
										    && rob[g].pred_bitv
//												&& !robentry_issue[g]
												;
*/												
/* This code moved to mainline (Stark).
always_ff @(posedge clk)
if (rst)
	could_issue[g] = {ROB_ENTRIES{1'd0}};
else
	could_issue[g] = next_could_issue[g];
*/
/* This code moved to mainline (Stark).
always_ff @(posedge clk)
if (rst)
	could_issue_nm[g] = {ROB_ENTRIES{1'd0}};
else 
	could_issue_nm[g] = 
													 rob[g].v
												&& !(&rob[g].done)
//												&& !stomp_i[g]
												&& rob[g].argT_v 
												//&& fnPredFalse(g)
												&& !robentry_issue[g]
												&& ~|rob[g].pred_bits
										    && rob[g].pred_bitv
												&& SUPPORT_PRED
												;
                        //&& ((rob[g].decbus.load|rob[g].decbus.store) ? !rob[g].agen : 1'b1);
*/                        
end                                 
end
endgenerate


// FPGAs do not handle race loops very well.
// The (old) simulator didn't handle the asynchronous race loop properly in the 
// original code. It would issue two instructions to the same islot. So the
// issue logic has been re-written to eliminate the asynchronous loop.
// Can't issue to the ALU if it's busy doing a long running operation like a 
// divide.
// ToDo: fix the memory synchronization, see fp_issue below

reg issued_alu0, issued_alu1, issued_fpu0, issued_fpu1, issued_fcu, no_issue;
reg issued_beb;
reg no_issue_fc;
reg issued_agen0, issued_agen1;
reg issued_lsq0, issued_lsq1;
reg can_issue_alu0;
reg can_issue_alu1;
reg can_issue_fpu0;
reg can_issue_fpu1;
reg can_issue_fcu;
reg can_issue_agen0;
reg can_issue_agen1;
reg flag;
integer hd, hd1, synchd, shd, slot;

always_comb//ff @(negedge clk)
if (rst) begin
	issued_alu0 = 1'd0;
	issued_alu1 = 1'd0;
	issued_fpu0 = 1'd0;
	issued_fpu1 = 1'd0;
	issued_fcu = 1'd0;
	issued_agen0 = 1'd0;
	issued_agen1 = 1'd0;
	no_issue = 1'd0;
	no_issue_fc = 1'd0;
	next_robentry_issue = {$bits(Stark_pkg::rob_bitmask_t){1'd0}};
	next_robentry_fpu_issue = {$bits(Stark_pkg::rob_bitmask_t){1'd0}};
	next_robentry_fcu_issue = {$bits(Stark_pkg::rob_bitmask_t){1'd0}};
	next_robentry_agen_issue = {$bits(Stark_pkg::rob_bitmask_t){1'd0}};
	next_multicycle_issue = {$bits(Stark_pkg::rob_bitmask_t){1'd0}};
	next_prev_issue = {$bits(Stark_pkg::rob_bitmask_t){1'd0}};
	next_alu0_rndx = 5'd0;
	next_alu1_rndx = 5'd0;
	next_fpu0_rndx = 5'd0;
	next_fpu1_rndx = 5'd0;
	next_fcu_rndx = 5'd0;
	next_agen0_rndx = 5'd0;
	next_agen1_rndx = 5'd0;
	next_alu0_rndxv = INV;
	next_alu1_rndxv = INV;
	next_fpu0_rndxv = INV;
	next_fpu1_rndxv = INV;
	next_fcu_rndxv = INV;
	next_agen0_rndxv = INV;
	next_agen1_rndxv = INV;
	next_cpytgt0 = INV;
	next_cpytgt1 = INV;
	issued_beb = 1'b0;
	next_beb_issue = 1'd0;
	for (h = 0; h < Stark_pkg::ROB_ENTRIES; h = h + 1)
		next_robentry_islot_o[h] = 2'd0;
	flag = 1'b0;
end
else begin
	issued_alu0 = 1'd0;
	issued_alu1 = 1'd0;
	issued_fpu0 = 1'd0;
	issued_fpu1 = 1'd0;
	issued_fcu = 1'd0;
	issued_agen0 = 1'd0;
	issued_agen1 = 1'd0;
	issued_beb = 1'b0;
	no_issue = 1'd0;
	no_issue_fc = 1'd0;
	next_robentry_issue = {$bits(Stark_pkg::rob_bitmask_t){1'd0}};
	next_robentry_fpu_issue = {$bits(Stark_pkg::rob_bitmask_t){1'd0}};
	next_robentry_fcu_issue = {$bits(Stark_pkg::rob_bitmask_t){1'd0}};
	next_robentry_agen_issue = {$bits(Stark_pkg::rob_bitmask_t){1'd0}};
	next_multicycle_issue = {$bits(Stark_pkg::rob_bitmask_t){1'd0}};
	next_prev_issue = prev_issue;
	next_beb_issue = 1'd0;
	next_alu0_rndx = 5'd0;
	next_alu1_rndx = 5'd0;
	next_fpu0_rndx = 5'd0;
	next_fpu1_rndx = 5'd0;
	next_fcu_rndx = 5'd0;
	next_agen0_rndx = 5'd0;
	next_agen1_rndx = 5'd0;
	next_alu0_rndxv = INV;
	next_alu1_rndxv = INV;
	next_fpu0_rndxv = INV;
	next_fpu1_rndxv = INV;
	next_fcu_rndxv = INV;
	next_agen0_rndxv = INV;
	next_agen1_rndxv = INV;
	next_cpytgt0 = INV;
	next_cpytgt1 = INV;
	for (h = 0; h < Stark_pkg::ROB_ENTRIES; h = h + 1)
		next_robentry_islot_o[h] = 2'd0;
	flag = 1'b0;
	for (h = 0; h < Stark_pkg::ROB_ENTRIES; h = h + 1)
		next_robentry_islot_o[h] = robentry_islot_i[h];
	for (hd = 0; hd < WINDOW_SIZE; hd = hd + 1) begin
		flag = rob[heads[hd]].could_issue;	// & next_could_issue[heads[hd]];
		// Search for a preceding sync instruction. If there is one then do
		// not issue.
		if (flag) begin
			// Look for ALU pair instructions, issue to both ALUs when possible.
			if (!issued_alu0 && !issued_alu1 && alu0_idle
				&& !prev_issue[heads[hd]]
//				&& !prev_issue2[heads[hd]]
				&&  rob[heads[hd]].decbus.alu_pair
				&& !robentry_issue[heads[hd]]
				&& !rob[heads[hd]].done[0]
				&& !rob[heads[hd]].out[0])
			begin
		  	next_robentry_issue[heads[hd]] = 1'b1;
		  	next_robentry_islot_o[heads[hd]] = 2'b00;
		  	issued_alu0 = 1'b1;
		  	issued_alu1 = 1'b1;
		  	next_alu0_rndx = heads[hd];
		  	next_alu0_rndxv = 1'b1;
		  	next_alu1_rndx = heads[hd];
		  	next_alu1_rndxv = 1'b1;
			end
			if (!issued_alu0 && alu0_idle
				&& !prev_issue[heads[hd]]
//				&& !prev_issue2[heads[hd]]
				&& !robentry_issue[heads[hd]]
				&& ((rob[heads[hd]].decbus.alu && !rob[heads[hd]].done[0]) || (rob[heads[hd]].decbus.cpytgt && rob[heads[hd]].done!=2'b11))
//				&& (rob[heads[hd]].decbus.fc ? next_robentry_fcu_issue[heads[hd]] || robentry_fcu_issue[heads[hd]] || |rob[heads[hd]].out : 1'b1)
				&& !rob[heads[hd]].out[0]) begin
		  	next_robentry_issue[heads[hd]] = 1'b1;
		  	next_robentry_islot_o[heads[hd]] = 2'b00;
		  	issued_alu0 = 1'b1;
		  	next_alu0_rndx = heads[hd];
		  	next_alu0_rndxv = 1'b1;
			end
			if (NALU > 1) begin
				if (!issued_alu1 && alu1_idle
					&& !prev_issue[heads[hd]]
//					&& !prev_issue2[heads[hd]]
					&& !robentry_issue[heads[hd]]
					&& ((rob[heads[hd]].decbus.alu && !rob[heads[hd]].done[0]) || (rob[heads[hd]].decbus.cpytgt && rob[heads[hd]].done!=2'b11))
//					&& (rob[heads[hd]].decbus.fc ? next_robentry_fcu_issue[heads[hd]] || robentry_fcu_issue[heads[hd]] || |rob[heads[hd]].out : 1'b1)
					&& !rob[heads[hd]].out[0]
					&& !rob[heads[hd]].decbus.alu0) begin
					if (!next_robentry_issue[heads[hd]]) begin	// Did ALU #0 already grab it?
				  	next_robentry_issue[heads[hd]] = 1'b1;
				  	next_robentry_islot_o[heads[hd]] = 2'b01;
				  	issued_alu1 = 1'b1;
				  	next_alu1_rndx = heads[hd];
				  	next_alu1_rndxv = 1'b1;
			  	end
				end
			end
			if (!rob[heads[hd]].decbus.cpytgt) begin
				if (NFPU > 0) begin
					if (!issued_fpu0 && fpu0_idle && rob[heads[hd]].decbus.fpu && rob[heads[hd]].out[0]==2'b00
					&& !prev_issue[heads[hd]]
//					&& !prev_issue2[heads[hd]]
					) begin
						if (rob[heads[hd]].decbus.prc==Stark_pkg::hexi && Stark_pkg::SUPPORT_QUAD_PRECISION) begin
							if (fnPriorQFExtOut(heads[hd])) begin
						  	next_robentry_fpu_issue[heads[hd]] = 1'b1;
						  	next_robentry_islot_o[heads[hd]] = 2'b00;
						  	issued_fpu0 = 1'b1;
						  	next_fpu0_rndx = heads[hd];
						  	next_fpu0_rndxv = 1'b1;
							end
							// If there was no QFEXT schedule the instruction to execute. It
							// will exception when it sees that the ALU port is unavailable.
							// Otherwise wait until the ALU has been scheduled for the op.
							else if (!fnPriorQFExt(heads[hd])) begin
						  	next_robentry_fpu_issue[heads[hd]] = 1'b1;
						  	next_robentry_islot_o[heads[hd]] = 2'b00;
						  	issued_fpu0 = 1'b1;
						  	next_fpu0_rndx = heads[hd];
						  	next_fpu0_rndxv = 1'b1;
							end
						end
						// Might be an ALU type op that could be issued on the FPU or ALU. 
						// Check that it was not issued on the ALU.
						else if (!next_robentry_issue[heads[hd]]) begin
					  	next_robentry_fpu_issue[heads[hd]] = 1'b1;
					  	next_robentry_islot_o[heads[hd]] = 2'b00;
					  	issued_fpu0 = 1'b1;
					  	next_fpu0_rndx = heads[hd];
					  	next_fpu0_rndxv = 1'b1;
				  	end
					end
				end
				if (NFPU > 1) begin
					if (!issued_fpu1 && fpu1_idle && rob[heads[hd]].decbus.fpu && rob[heads[hd]].out[0]==2'b00
					&& !prev_issue[heads[hd]]
//					&& !prev_issue2[heads[hd]]
					&& !rob[heads[hd]].decbus.fpu0) begin
						if (!next_robentry_fpu_issue[heads[hd]]&&!next_robentry_issue[heads[hd]]
						) begin
					  	next_robentry_fpu_issue[heads[hd]] = 1'b1;
					  	next_robentry_islot_o[heads[hd]] = 2'b01;
					  	issued_fpu1 = 1'b1;
					  	next_fpu1_rndx = heads[hd];
					  	next_fpu1_rndxv = 1'b1;
				  	end
					end
				end
				// Issue flow controls in order, one at a time
				if (!issued_fcu && fcu_idle && rob[heads[hd]].decbus.fc && !rob[heads[hd]].done[1] && !rob[heads[hd]].out[1]
					&& !prev_issue[heads[hd]]	//???
					// The following line makes flow control wait until at least six other
					// instructions are in the ROB. This is for the benefit of predication.
					// Note it is only 1 or 2 instruction groups, so this is likely true
					// already. (Sequence numbers decrement from 0x7f downwards.)
					&& rob[heads[hd]].sn < 7'd79
					&& !(|robentry_fcu_issue)
					&& !(|next_robentry_fcu_issue)
//					&& !prev_issue2[heads[hd]]
					&& (SUPPORT_OOOFC ? 1'b1 : !fnPriorFC(heads[hd]))) begin
			  	next_robentry_fcu_issue[heads[hd]] = 1'b1;
			  	issued_fcu = 1'b1;
			  	next_fcu_rndx = heads[hd];
			  	next_fcu_rndxv = 1'b1;
				end

				if (!issued_agen0 && !issued_beb && agen0_idle &&
					!fnPriorMem(heads[hd]) &&
					!prev_issue[heads[hd]] &&
//					!prev_issue2[heads[hd]] &&
					!robentry_agen_issue[heads[hd]] &&
					 rob[heads[hd]].decbus.mem &&
					!rob[heads[hd]].done[0] && !rob[heads[hd]].out[0]) begin
					next_robentry_agen_issue[heads[hd]] = 1'b1;
			  	next_robentry_islot_o[heads[hd]] = 2'b00;
					issued_agen0 = 1'b1;
					next_agen0_rndx = heads[hd];
					next_agen0_rndxv = 1'b1;
				end
				// Schedule exception to MEM
				if (!issued_agen0 && agen0_idle 
					&& hd==5'd0	// must be at head
					&& rob[heads[hd]].excv
					&& rob[heads[hd]].done==2'b11
					) begin
					next_robentry_agen_issue[heads[hd]] = 1'b1;
			  	next_robentry_islot_o[heads[hd]] = 2'b00;
					issued_agen0 = 1'b1;
					next_agen0_rndx = heads[hd];
					next_agen0_rndxv = 1'b1;
				end
				if (NAGEN > 1) begin
					if (!issued_agen1 && agen1_idle &&
						!fnPriorMem(heads[hd]) &&
						!prev_issue[heads[hd]] &&
//						!prev_issue2[heads[hd]] &&
						!robentry_agen_issue[heads[hd]] &&
						 rob[heads[hd]].decbus.mem &&
						!rob[heads[hd]].decbus.mem0 &&
						!rob[heads[hd]].done[0] && !rob[heads[hd]].out[0]) begin
						if (!next_robentry_agen_issue[heads[hd]]) begin
							next_robentry_agen_issue[heads[hd]] = 1'b1;
					  	next_robentry_islot_o[heads[hd]] = 2'b01;
							issued_agen1 = 1'b1;
							next_agen1_rndx = heads[hd];
							next_agen1_rndxv = 1'b1;
						end
					end
				end
				// Background execution buffer issue
				if (!issued_beb && !issued_agen0 && agen0_idle) begin
					if (!beb_issue) begin
						if (!beb_buf.done && beb_buf.v) begin
							issued_beb = 1'b1;
							next_beb_issue = 1'b1;
						end
					end
				end
			end
		end
		flag = rob[heads[hd]].could_issue_nm;
		if (flag) begin
			if (!issued_alu0 && alu0_idle && !rob[heads[hd]].done[0]) begin
		  	next_robentry_issue[heads[hd]] = 1'b1;
		  	next_robentry_islot_o[heads[hd]] = 2'b00;
		  	issued_alu0 = 1'b1;
		  	next_alu0_rndx = heads[hd];
		  	next_alu0_rndxv = 1'b1;
		  	next_cpytgt0 = 1'b1;
			end
			if (NALU > 1) begin
				if (!issued_alu1 && alu1_idle && !rob[heads[hd]].done[0]) begin
					if (!next_robentry_issue[heads[hd]]) begin	// Did ALU #0 already grab it?
				  	next_robentry_issue[heads[hd]] = 1'b1;
				  	next_robentry_islot_o[heads[hd]] = 2'b01;
				  	issued_alu1 = 1'b1;
				  	next_alu1_rndx = heads[hd];
				  	next_alu1_rndxv = 1'b1;
				  	next_cpytgt1 = 1'b1;
			  	end
				end
			end
		end
	end

end

always_ff @(posedge clk)
if (rst) begin
	for (q = 0; q < Stark_pkg::ROB_ENTRIES; q = q + 1)
		robentry_islot_o[q] <= 2'd0;
	robentry_issue <= {$bits(Stark_pkg::rob_bitmask_t){1'd0}};
	robentry_fpu_issue <= {$bits(Stark_pkg::rob_bitmask_t){1'd0}};
	robentry_fcu_issue <= {$bits(Stark_pkg::rob_bitmask_t){1'd0}};
	robentry_agen_issue <= {$bits(Stark_pkg::rob_bitmask_t){1'd0}};
	multicycle_issue <= {$bits(Stark_pkg::rob_bitmask_t){1'd0}};
	prev_issue <= {$bits(Stark_pkg::rob_bitmask_t){1'd0}};
	prev_issue2 <= {$bits(Stark_pkg::rob_bitmask_t){1'd0}};
	beb_issue <= 1'b0;
	alu0_rndx <= 5'd0;
	alu1_rndx <= 5'd0;
	fpu0_rndx <= 5'd0;
	fpu1_rndx <= 5'd0;
	fcu_rndx <= 5'd0;
	agen0_rndx <= 1'd0;
	agen1_rndx <= 1'd0;
	alu0_rndxv <= 1'd0;
	alu1_rndxv <= 1'd0;
	fpu0_rndxv <= 1'd0;
	fpu1_rndxv <= 1'd0;
	fcu_rndxv <= 1'd0;
	agen0_rndxv <= 1'd0;
	agen1_rndxv <= 1'd0;
	cpytgt0 <= 1'b0;
	cpytgt1 <= 1'b0;
end
else begin
	robentry_islot_o <= next_robentry_islot_o;
	robentry_issue <= next_robentry_issue;
	robentry_fpu_issue <= next_robentry_fpu_issue;
	robentry_fcu_issue <= next_robentry_fcu_issue;
	robentry_agen_issue <= next_robentry_agen_issue;
	multicycle_issue <= next_multicycle_issue;
	prev_issue <= (next_prev_issue & ~prev_issue2) |
		next_robentry_issue | next_robentry_fpu_issue | next_robentry_fcu_issue |
		next_robentry_agen_issue;
	prev_issue2 <= prev_issue;
	beb_issue <= next_beb_issue;
	alu0_rndx <= next_alu0_rndx;
	alu1_rndx <= next_alu1_rndx;
	fpu0_rndx <= next_fpu0_rndx;
	fpu1_rndx <= next_fpu1_rndx;
	fcu_rndx <= next_fcu_rndx;
	agen0_rndx <= next_agen0_rndx;
	agen1_rndx <= next_agen1_rndx;
	alu0_rndxv <= next_alu0_rndxv;
	alu1_rndxv <= next_alu1_rndxv;
	fpu0_rndxv <= next_fpu0_rndxv;
	fpu1_rndxv <= next_fpu1_rndxv;
	fcu_rndxv <= next_fcu_rndxv;
	agen0_rndxv <= next_agen0_rndxv;
	agen1_rndxv <= next_agen1_rndxv;
	cpytgt0 <= next_cpytgt0;
	cpytgt1 <= next_cpytgt1;
end

always_comb//ff @(negedge clk)
if (rst) begin
	next_ratv0_rndx = 5'd0;
	next_ratv1_rndx = 5'd0;
	next_ratv2_rndx = 5'd0;
	next_ratv3_rndx = 5'd0;
	next_ratv0_rndxv = INV;
	next_ratv1_rndxv = INV;
	next_ratv2_rndxv = INV;
	next_ratv3_rndxv = INV;
	next_ratv_issue <= {$bits(Stark_pkg::rob_bitmask_t){1'd0}};
end
else begin
	next_ratv0_rndx = 5'd0;
	next_ratv1_rndx = 5'd0;
	next_ratv2_rndx = 5'd0;
	next_ratv3_rndx = 5'd0;
	next_ratv0_rndxv = INV;
	next_ratv1_rndxv = INV;
	next_ratv2_rndxv = INV;
	next_ratv3_rndxv = INV;
	next_ratv_issue <= {$bits(Stark_pkg::rob_bitmask_t){1'd0}};
	for (hd1 = 0; hd1 < WINDOW_SIZE; hd1 = hd1 + 1) begin
		if (rob[heads[hd1]].v && !rob[heads[hd1]].rat_v &&
			!ratv_issue[heads[hd1]]) begin
			next_ratv0_rndxv = 1'b1;
			next_ratv0_rndx = heads[hd1];
			next_ratv_issue[heads[hd1]] = 1'b1;
		end
		if (rob[heads[hd1]].v && !rob[heads[hd1]].rat_v && 
			!ratv_issue[heads[hd1]] && 
			!next_ratv_issue[heads[hd1]]) begin
			next_ratv1_rndxv = 1'b1;
			next_ratv1_rndx = heads[hd1];
			next_ratv_issue[heads[hd1]] = 1'b1;
		end
		if (rob[heads[hd1]].v && !rob[heads[hd1]].rat_v &&
		 !ratv_issue[heads[hd1]] &&
		 !next_ratv_issue[heads[hd1]]) begin
			next_ratv2_rndxv = 1'b1;
			next_ratv2_rndx = heads[hd1];
			next_ratv_issue[heads[hd1]] = 1'b1;
		end
		if (rob[heads[hd1]].v && !rob[heads[hd1]].rat_v &&
		 !ratv_issue[heads[hd1]] &&
		 !next_ratv_issue[heads[hd1]]) begin
			next_ratv3_rndxv = 1'b1;
			next_ratv3_rndx = heads[hd1];
			next_ratv_issue[heads[hd1]] = 1'b1;
		end
	end
end

always_ff @(posedge clk)
if (rst) begin
	ratv0_rndx = 5'd0;
	ratv1_rndx = 5'd0;
	ratv2_rndx = 5'd0;
	ratv3_rndx = 5'd0;
	ratv0_rndxv = INV;
	ratv1_rndxv = INV;
	ratv2_rndxv = INV;
	ratv3_rndxv = INV;
	ratv_issue <= {$bits(Stark_pkg::rob_bitmask_t){1'd0}};
	ratv_issue2 <= {$bits(Stark_pkg::rob_bitmask_t){1'd0}};
end
else begin
	ratv0_rndxv <= next_ratv0_rndxv;
	ratv1_rndxv <= next_ratv1_rndxv;
	ratv2_rndxv <= next_ratv2_rndxv;
	ratv3_rndxv <= next_ratv3_rndxv;
	ratv0_rndx <= next_ratv0_rndx;
	ratv1_rndx <= next_ratv1_rndx;
	ratv2_rndx <= next_ratv2_rndx;
	ratv3_rndx <= next_ratv3_rndx;
	ratv_issue <= next_ratv_issue & ~ratv_issue2;
	ratv_issue2 <= ratv_issue;
end

endmodule
