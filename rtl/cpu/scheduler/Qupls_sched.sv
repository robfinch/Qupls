// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2024  Robert Finch, Waterloo
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
import QuplsPkg::*;

module Qupls_sched(rst, clk, alu0_idle, alu1_idle, fpu0_idle ,fpu1_idle, fcu_idle,
	agen0_idle, agen1_idle, lsq0_idle, lsq1_idle,
	stomp_i, robentry_islot_i, robentry_islot_o,
	head, rob, robentry_issue, robentry_fpu_issue, robentry_fcu_issue,
	robentry_agen_issue,
	alu0_rndx, alu1_rndx, alu0_rndxv, alu1_rndxv,
	fpu0_rndx, fpu0_rndxv, fpu1_rndx, fpu1_rndxv, fcu_rndx, fcu_rndxv,
	agen0_rndx, agen1_rndx, cpytgt0, cpytgt1, agen0_rndxv, agen1_rndxv);
parameter WINDOW_SIZE = SCHED_WINDOW_SIZE;
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
input [1:0] robentry_islot_i [0:ROB_ENTRIES-1];
output reg [1:0] robentry_islot_o [0:ROB_ENTRIES-1];
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
output reg cpytgt0;
output reg cpytgt1;
output reg alu0_rndxv;
output reg alu1_rndxv;
output reg fpu0_rndxv;
output reg fpu1_rndxv;
output reg fcu_rndxv;
output reg agen0_rndxv;
output reg agen1_rndxv;

reg [1:0] next_robentry_islot_o [0:ROB_ENTRIES-1];
rob_bitmask_t next_robentry_issue;
rob_bitmask_t next_robentry_fpu_issue;
rob_bitmask_t next_robentry_fcu_issue;
rob_bitmask_t next_robentry_agen_issue;
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
reg next_cpytgt0;
reg next_cpytgt1;
rob_bitmask_t args_valid;
rob_bitmask_t could_issue, could_issue_nm;	//nm = no match

genvar g;
integer m,n,h,q;
rob_ndx_t [WINDOW_SIZE-1:0] heads;

always_ff @(posedge clk)
for (m = 0; m < WINDOW_SIZE; m = m + 1)
	heads[m] = (head + m) % ROB_ENTRIES;

// Search for a prior load or store. This forces the load / store to be performed
// in program order.

function fnNoPriorLS;
input rob_ndx_t ndx;
begin
	fnNoPriorLS = 1'b1;
	for (n = 0; n < ROB_ENTRIES; n = n + 1)
		if ((rob[n].v && rob[n].sn < rob[ndx].sn) && rob[n].decbus.mem && !(&rob[heads[n]].done))
			fnNoPriorLS = 1'b0;
end
endfunction

// Search for a prior flow control op. This forces flow control op to be performed
// in program order.

function fnPriorFC;
input rob_ndx_t ndx;
begin
	fnPriorFC = FALSE;
	for (n = 0; n < ROB_ENTRIES; n = n + 1)
		if (rob[n].v && rob[n].sn < rob[ndx].sn && rob[n].decbus.fc && !rob[n].done[1])
			fnPriorFC = TRUE;
end
endfunction

function fnPriorSync;
input rob_ndx_t ndx;
begin
	fnPriorSync = FALSE;
	for (n = 0; n < ROB_ENTRIES; n = n + 1)
		if (rob[n].v && rob[n].sn < rob[ndx].sn && rob[n].decbus.sync)
			fnPriorSync = TRUE;
end
endfunction

// fnPriorFalsePred prevents an instruction from being scheduled if the
// possibility of prior predicate that is false exists. If the predicate
// value is false or unknown then the instruction will not be scheduled.

function fnPriorFalsePred;
input rob_ndx_t ndx;
rob_ndx_t m1;
rob_ndx_t m2;
rob_ndx_t m3;
rob_ndx_t m4;
rob_ndx_t m5;
rob_ndx_t m6;
rob_ndx_t m7;
rob_ndx_t m8;
begin
	fnPriorFalsePred = FALSE;
	if (SUPPORT_PRED) begin
		m1 = (ndx + ROB_ENTRIES - 1) % ROB_ENTRIES;
		m2 = (ndx + ROB_ENTRIES - 2) % ROB_ENTRIES;
		m3 = (ndx + ROB_ENTRIES - 3) % ROB_ENTRIES;
		m4 = (ndx + ROB_ENTRIES - 4) % ROB_ENTRIES;
		m5 = (ndx + ROB_ENTRIES - 5) % ROB_ENTRIES;
		m6 = (ndx + ROB_ENTRIES - 6) % ROB_ENTRIES;
		m7 = (ndx + ROB_ENTRIES - 7) % ROB_ENTRIES;
		m8 = (ndx + ROB_ENTRIES - 8) % ROB_ENTRIES;
		if (rob[m1].v && rob[m1].sn < rob[ndx].sn && rob[m1].decbus.pred) begin
			fnPriorFalsePred = TRUE;
			if (rob[m1].done==2'b11)
				fnPriorFalsePred = rob[m1].pred_status[0];
		end
		else if (rob[m2].v && rob[m2].sn < rob[ndx].sn && rob[m2].decbus.pred) begin
			fnPriorFalsePred = TRUE;
			if (rob[m2].done==2'b11)
				fnPriorFalsePred = rob[m2].pred_status[1];
		end
		else if (rob[m3].v && rob[m3].sn < rob[ndx].sn && rob[m3].decbus.pred) begin
			fnPriorFalsePred = TRUE;
			if (rob[m3].done==2'b11)
				fnPriorFalsePred = rob[m3].pred_status[2];
		end
		else if (rob[m4].v && rob[m4].sn < rob[ndx].sn && rob[m4].decbus.pred) begin
			fnPriorFalsePred = TRUE;
			if (rob[m4].done==2'b11)
				fnPriorFalsePred = rob[m4].pred_status[3];
		end
		else if (rob[m5].v && rob[m5].sn < rob[ndx].sn && rob[m5].decbus.pred) begin
			fnPriorFalsePred = TRUE;
			if (rob[m5].done==2'b11)
				fnPriorFalsePred = rob[m5].pred_status[4];
		end
		else if (rob[m6].v && rob[m6].sn < rob[ndx].sn && rob[m6].decbus.pred) begin
			fnPriorFalsePred = TRUE;
			if (rob[m6].done==2'b11)
				fnPriorFalsePred = rob[m6].pred_status[5];
		end
		else if (rob[m7].v && rob[m7].sn < rob[ndx].sn && rob[m7].decbus.pred) begin
			fnPriorFalsePred = TRUE;
			if (rob[m7].done==2'b11)
				fnPriorFalsePred = rob[m7].pred_status[6];
		end
		else if (rob[m8].v && rob[m8].sn < rob[ndx].sn && rob[m8].decbus.pred) begin
			fnPriorFalsePred = TRUE;
			if (rob[m8].done==2'b11)
				fnPriorFalsePred = rob[m8].pred_status[7];
		end
	end
end
endfunction

// fnPredFalse signals that a truly false predicate was found for the
// instruction. The instruction will then be scheduled to execute on the NOP
// unit.

function fnPredFalse;
input rob_ndx_t ndx;
rob_ndx_t m1;
rob_ndx_t m2;
rob_ndx_t m3;
rob_ndx_t m4;
rob_ndx_t m5;
rob_ndx_t m6;
rob_ndx_t m7;
rob_ndx_t m8;
begin
	fnPredFalse = FALSE;
	if (SUPPORT_PRED) begin
		m1 = (ndx + ROB_ENTRIES - 1) % ROB_ENTRIES;
		m2 = (ndx + ROB_ENTRIES - 2) % ROB_ENTRIES;
		m3 = (ndx + ROB_ENTRIES - 3) % ROB_ENTRIES;
		m4 = (ndx + ROB_ENTRIES - 4) % ROB_ENTRIES;
		m5 = (ndx + ROB_ENTRIES - 5) % ROB_ENTRIES;
		m6 = (ndx + ROB_ENTRIES - 6) % ROB_ENTRIES;
		m7 = (ndx + ROB_ENTRIES - 7) % ROB_ENTRIES;
		m8 = (ndx + ROB_ENTRIES - 8) % ROB_ENTRIES;
		if (rob[m1].v && rob[m1].sn < rob[ndx].sn && rob[m1].decbus.pred) begin
			if (rob[m1].done==2'b11 && rob[m1].pred_status[0]==FALSE)
				fnPredFalse = TRUE;
		end
		else if (rob[m2].v && rob[m2].sn < rob[ndx].sn && rob[m2].decbus.pred) begin
			if (rob[m2].done==2'b11 && rob[m2].pred_status[1]==FALSE)
				fnPredFalse = TRUE;
		end
		else if (rob[m3].v && rob[m3].sn < rob[ndx].sn && rob[m3].decbus.pred) begin
			if (rob[m3].done==2'b11 && rob[m3].pred_status[2]==FALSE)
				fnPredFalse = TRUE;
		end
		else if (rob[m4].v && rob[m4].sn < rob[ndx].sn && rob[m4].decbus.pred) begin
			if (rob[m4].done==2'b11 && rob[m4].pred_status[3]==FALSE)
				fnPredFalse = TRUE;
		end
		else if (rob[m5].v && rob[m5].sn < rob[ndx].sn && rob[m5].decbus.pred) begin
			if (rob[m5].done==2'b11 && rob[m5].pred_status[4]==FALSE)
				fnPredFalse = TRUE;
		end
		else if (rob[m6].v && rob[m6].sn < rob[ndx].sn && rob[m6].decbus.pred) begin
			if (rob[m6].done==2'b11 && rob[m6].pred_status[5]==FALSE)
				fnPredFalse = TRUE;
		end
		else if (rob[m7].v && rob[m7].sn < rob[ndx].sn && rob[m7].decbus.pred) begin
			if (rob[m7].done==2'b11 && rob[m7].pred_status[6]==FALSE)
				fnPredFalse = TRUE;
		end
		else if (rob[m8].v && rob[m8].sn < rob[ndx].sn && rob[m8].decbus.pred) begin
			if (rob[m8].done==2'b11 && rob[m8].pred_status[7]==FALSE)
				fnPredFalse = TRUE;
		end
	end
end
endfunction

// We evaluate match logic once for the entire ROB so the logic resouce is O(n).

generate begin : issue_logic
for (g = 0; g < ROB_ENTRIES; g = g + 1) begin
	assign args_valid[g] = (rob[g].argA_v
						// Or forwarded
						/*
				    || (rob[g].decbus.Ra == alu0_Rt && alu0_v)
				    || (rob[g].decbus.Ra == alu1_Rt && alu1_v)
				    || (rob[g].decbus.Ra == fpu0_Rt && fpu0_v)
				    || (rob[g].decbus.Ra == fcu_Rt && fcu_v)
				    || (rob[g].decbus.Ra == load_Rt && load_v)
				    */
				    )
				    && (rob[g].argB_v
						// Or forwarded
						/*
				    || (rob[g].decbus.Rb == alu0_Rt && alu0_v)
				    || (rob[g].decbus.Rb == alu1_Rt && alu1_v)
				    || (rob[g].decbus.Rb == fpu0_Rt && fpu0_v)
				    || (rob[g].decbus.Rb == fcu_Rt && fcu_v)
				    || (rob[g].decbus.Rb == load_Rt && load_v)
				    */
				    )
				    && ((rob[g].argC_v)
						// Or forwarded
						/*
				    || (rob[g].decbus.Rc == alu0_Rt && alu0_v)
				    || (rob[g].decbus.Rc == alu1_Rt && alu1_v)
				    || (rob[g].decbus.Rc == fpu0_Rt && fpu0_v)
				    || (rob[g].decbus.Rc == fcu_Rt && fcu_v)
				    || (rob[g].decbus.Rc == load_Rt && load_v)
				    */
				    || (rob[g].decbus.mem))// & ~rob[g].agen))
				    ;
				    // If the predicate is known to be false, we do not care what the
				    // argument registers are, other than Rt. If the predicate is known
				    // to be true we do not need to wait for Rt.
				    // Do not issue to the same slot twice in a row, back-to-back. This
				    // could only happen when a new instruction happens to queue in the
				    // slot just finished executing. The new instruction would be
				    // incorrectly marked done, inheriting the status of the old one.
always_ff @(posedge clk) could_issue[g] =
													 rob[g].v
//												&& !stomp_i[g]
												&& !(&rob[g].done)
												&& (args_valid[g]||rob[g].decbus.cpytgt)
												&& !fnPriorFalsePred(g)
												&& !fnPriorSync(g)
												&& !robentry_issue[g]
												;
always_ff @(posedge clk) could_issue_nm[g] = 
													 rob[g].v
												&& !(&rob[g].done)
//												&& !stomp_i[g]
												&& rob[g].argT_v 
												&& fnPredFalse(g)
												&& !robentry_issue[g]
												&& SUPPORT_PRED
												;
                        //&& ((rob[g].decbus.load|rob[g].decbus.store) ? !rob[g].agen : 1'b1);
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
integer hd, synchd, shd, slot;

always_comb
begin
	issued_alu0 = 1'd0;
	issued_alu1 = 1'd0;
	issued_fpu0 = 1'd0;
	issued_fpu1 = 1'd0;
	issued_fcu = 1'd0;
	issued_agen0 = 1'd0;
	issued_agen1 = 1'd0;
	no_issue = 1'd0;
	no_issue_fc = 1'd0;
	next_robentry_issue = {$bits(rob_bitmask_t){1'd0}};
	next_robentry_fpu_issue = {$bits(rob_bitmask_t){1'd0}};
	next_robentry_fcu_issue = {$bits(rob_bitmask_t){1'd0}};
	next_robentry_agen_issue = {$bits(rob_bitmask_t){1'd0}};
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
	flag = 1'b0;
	for (h = 0; h < ROB_ENTRIES; h = h + 1)
		next_robentry_islot_o[h] = robentry_islot_i[h];
	for (hd = 0; hd < WINDOW_SIZE; hd = hd + 1) begin
		flag = could_issue[heads[hd]];
		// Search for a preceding sync instruction. If there is one then do
		// not issue.
		if (flag) begin
			if (!issued_alu0 && alu0_idle &&
				((rob[heads[hd]].decbus.alu && !rob[heads[hd]].done[0]) || rob[heads[hd]].decbus.cpytgt) &&
				!rob[heads[hd]].out[0]) begin
		  	next_robentry_issue[heads[hd]] = 1'b1;
		  	next_robentry_islot_o[heads[hd]] = 2'b00;
		  	issued_alu0 = 1'b1;
		  	next_alu0_rndx = heads[hd];
		  	next_alu0_rndxv = 1'b1;
			end
			if (NALU > 1) begin
				if (!issued_alu1 && alu1_idle &&
					((rob[heads[hd]].decbus.alu && !rob[heads[hd]].done[0]) || rob[heads[hd]].decbus.cpytgt) &&
					!rob[heads[hd]].out[0] && !rob[heads[hd]].decbus.alu0) begin
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
					if (!issued_fpu0 && fpu0_idle && rob[heads[hd]].decbus.fpu && rob[heads[hd]].out[0]==2'b00) begin
				  	next_robentry_fpu_issue[heads[hd]] = 1'b1;
				  	next_robentry_islot_o[heads[hd]] = 2'b00;
				  	issued_fpu0 = 1'b1;
				  	next_fpu0_rndx = heads[hd];
				  	next_fpu0_rndxv = 1'b1;
					end
				end
				if (NFPU > 1) begin
					if (!issued_fpu1 && fpu1_idle && rob[heads[hd]].decbus.fpu && rob[heads[hd]].out[0]==2'b00 && !rob[heads[hd]].decbus.fpu0) begin
						if (!next_robentry_fpu_issue[heads[hd]]) begin
					  	next_robentry_fpu_issue[heads[hd]] = 1'b1;
					  	next_robentry_islot_o[heads[hd]] = 2'b01;
					  	issued_fpu1 = 1'b1;
					  	next_fpu1_rndx = heads[hd];
					  	next_fpu1_rndxv = 1'b1;
				  	end
					end
				end
				// Issue flow controls in order, one at a time
				if (!issued_fcu && fcu_idle && rob[heads[hd]].decbus.fc && !rob[heads[hd]].done[1] && !rob[heads[hd]].out[1] &&
				 (SUPPORT_OOOFC ? 1'b1 : !fnPriorFC(heads[hd]))) begin
			  	next_robentry_fcu_issue[heads[hd]] = 1'b1;
			  	issued_fcu = 1'b1;
			  	next_fcu_rndx = heads[hd];
			  	next_fcu_rndxv = 1'b1;
				end

				if (!issued_agen0 && agen0_idle && rob[heads[hd]].decbus.mem && !rob[heads[hd]].done[0] && !rob[heads[hd]].out[0]) begin
					next_robentry_agen_issue[heads[hd]] = 1'b1;
			  	next_robentry_islot_o[heads[hd]] = 2'b00;
					issued_agen0 = 1'b1;
					next_agen0_rndx = heads[hd];
					next_agen0_rndxv = 1'b1;
				end
				if (NAGEN > 1) begin
					if (!issued_agen1 && agen1_idle && rob[heads[hd]].decbus.mem && !rob[heads[hd]].done[0] && !rob[heads[hd]].out[0]) begin
						if (!next_robentry_agen_issue[heads[hd]]) begin
							next_robentry_agen_issue[heads[hd]] = 1'b1;
					  	next_robentry_islot_o[heads[hd]] = 2'b01;
							issued_agen1 = 1'b1;
							next_agen1_rndx = heads[hd];
							next_agen1_rndxv = 1'b1;
						end
					end
				end
			end
		end
		flag = could_issue_nm[heads[hd]];
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
	for (q = 0; q < ROB_ENTRIES; q = q + 1)
		robentry_islot_o[q] <= 'd0;
	robentry_issue <= 'd0;
	robentry_fpu_issue <= 'd0;
	robentry_fcu_issue <= 'd0;
	robentry_agen_issue <= 'd0;
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
	robentry_fpu_issue <= 'd0;
	robentry_fcu_issue <= next_robentry_fcu_issue;
	robentry_agen_issue <= next_robentry_agen_issue;
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

endmodule
