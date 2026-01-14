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
// Compute stomps
// 1) figure stomps in the front end pipeline
// 2) figure stomps in the re-order buffer
// 5525 LUTs / 220 FFs / 340 MHz
// ============================================================================

import const_pkg::*;
import Qupls4_pkg::*;

module Qupls4_stomp(rst, clk, clk2x, ihit, advance_pipeline, advance_pipeline_seg2, 
//	irq_in_pipe, di_inst,
	dep_stream,
	branch_resolved, branchmiss, found_destination, destination_rndx,
	misspc, predicted_correctly_dec, predicted_match_ext,
	pc, pc_f, pc_fet, pc_ext, pc_mot, pc_dec, pc_ren,
	stomp_fet, stomp_ext, stomp_mot, stomp_dec, stomp_ren, stomp_que, stomp_quem,
	fcu_idv, fcu_id, missid, missid_v, kept_stream, takb, rob, robentry_stomp
	);
parameter MWIDTH = Qupls4_pkg::MWIDTH;
input rst;
input clk;
input clk2x;
input ihit;
//input irq_in_pipe;
//input di_inst;
input advance_pipeline;
input advance_pipeline_seg2;
input found_destination;	// true if destination was found in ROB
input rob_ndx_t destination_rndx;
input branch_resolved;
input branchmiss;
input pc_address_ex_t misspc;
input predicted_correctly_dec;
input predicted_match_ext;
input pc_address_ex_t pc;
input pc_address_ex_t pc_f;
input pc_address_ex_t pc_fet;
input pc_address_ex_t pc_ext;
input pc_address_ex_t pc_mot;
input pc_address_ex_t pc_dec;
input pc_address_ex_t pc_ren;
input dep_stream_t [XSTREAMS-1:0] dep_stream;
output reg stomp_fet;
output reg stomp_ext;			// IRQ / micro-code Mux stage
output reg stomp_mot;
output reg stomp_dec;
output reg stomp_ren;
output reg stomp_que;
output reg stomp_quem;
input fcu_idv;
input rob_ndx_t fcu_id;
input rob_ndx_t missid;
input missid_v;
input pc_stream_t kept_stream;
input takb;
input Qupls4_pkg::rob_entry_t [Qupls4_pkg::ROB_ENTRIES-1:0] rob;
output Qupls4_pkg::rob_bitmask_t robentry_stomp;

integer nn, n4;
pc_address_ex_t [5:0] misspcr;
reg stomp_aln;
reg stomp_alnr;
reg stomp_fetr;
reg stomp_extr;
reg stomp_motr;
reg stomp_decr;
reg stomp_renr;
reg stomp_quer;
reg stomp_rrr;
reg stomp_quemr;
reg [XSTREAMS-1:0] stomped;

reg stomp_pipeline;
reg [3:0] spl;
wire pe_stomp_pipeline;

//------------------------------------------------------------------------------
// Front-end stomps
//------------------------------------------------------------------------------
always_comb
	stomp_pipeline = (branchmiss && !found_destination);
wire next_stomp_ext = (stomp_fet) || stomp_pipeline;
wire next_stomp_mot = (stomp_ext) || stomp_pipeline;
wire next_stomp_dec = (stomp_mot) || stomp_pipeline;
wire next_stomp_ren = (stomp_dec) || stomp_pipeline;
wire next_stomp_quem = (stomp_ren) || stomp_pipeline;

edge_det ued1 (.rst(rst), .clk(clk2x), .ce(advance_pipeline), .i(stomp_pipeline), .pe(pe_stomp_pipeline), .ne(), .ee());	

integer n5;
reg [XSTREAMS-1:0] list;
always_ff @(posedge clk)
	// Compute dependencies to stomp.
	stomped <= fnComputeBranchDependencies(kept_stream.stream);

always_ff @(posedge clk2x)
if (rst) begin
	foreach (misspcr[nn]) begin
		misspcr[nn].stream <= pc_stream_t'(7'd1);
		misspcr[nn].pc <= RSTPC;
	end
end
else begin
	if (pe_stomp_pipeline)
		misspcr[0] <= misspc;
	if (advance_pipeline|pe_stomp_pipeline) begin
		misspcr[1] <= misspcr[0];
		misspcr[2] <= misspcr[1];
		misspcr[3] <= misspcr[2];
		misspcr[4] <= misspcr[3];
		misspcr[5] <= misspcr[4];
	end
end

always_ff @(posedge clk2x)
if (rst)
	spl <= 4'b0000;
else begin
	spl <= {spl[2:0],stomp_pipeline};
//	if (advance_pipeline)
//		spl <= 4'b0000;
end

// Instruction stomp waterfall.
/*
wire hwi_at_ren = di_inst && pg_ren.hwi;
wire hwi_at_dec = di_inst && pg_dec.hwi;
wire hwi_at_ext = di_inst && pg_ext.hwi;
wire hwi_at_fet = di_inst && ic_irq;
wire hwi_at_aln = di_inst && hirq;
*/
// kept_stream is the stream we want to keep.
always_comb
	stomp_aln = stomped[pc.stream] ||
		(pe_stomp_pipeline || stomp_alnr || !predicted_match_ext || !predicted_correctly_dec) && (pc.pc != misspcr[0].pc);// && !hwi_at_ren && !hwi_at_dec && !hwi_at_fet && !hwi_at_aln;
always_comb
	stomp_fet = stomped[pc_f.stream] ||
		(pe_stomp_pipeline || stomp_fetr || !predicted_match_ext || !predicted_correctly_dec) && (pc_f.pc != misspcr[1].pc);// && !hwi_at_ren && !hwi_at_dec && !hwi_at_fet;
always_comb
	stomp_ext = stomped[pc_fet.stream] ||
		(pe_stomp_pipeline || stomp_extr || !predicted_match_ext || !predicted_correctly_dec) && (pc_fet.pc != misspcr[2].pc);// && !hwi_at_ren && !hwi_at_dec && !hwi_at_ext;
always_comb
	stomp_mot = stomped[pc_ext.stream] ||
		(pe_stomp_pipeline || stomp_motr || !predicted_match_ext || !predicted_correctly_dec) && (pc_ext.pc != misspcr[3].pc);// && !hwi_at_ren && !hwi_at_dec && !hwi_at_ext;
always_comb
	stomp_dec = stomped[pc_mot.stream] ||
	 (pe_stomp_pipeline || stomp_decr || !predicted_correctly_dec) && (pc_mot.pc != misspcr[4].pc);// && !hwi_at_ren && !hwi_at_dec;
always_comb
	stomp_ren = stomped[pc_dec.stream] ||
		(pe_stomp_pipeline || stomp_renr) && (pc_dec.pc != misspcr[5].pc);// && !hwi_at_ren;

// On a cache miss, the fetch stage is stomped on, but not if micro-code is
// active. Micro-code does not require the cache-line data.
// Invalidate the fetch stage on an unconditional subroutine call.

reg ff1;
pc_address_ex_t prev_pc;
always_ff @(posedge clk2x)
if (rst) begin
	stomp_alnr <= FALSE;
	stomp_fetr <= TRUE;
	stomp_extr <= TRUE;
	stomp_motr <= TRUE;
	stomp_decr <= TRUE;
	stomp_renr <= TRUE;
	ff1 <= FALSE;
end
else begin
	
	if (advance_pipeline|pe_stomp_pipeline) begin
		if (pe_stomp_pipeline) begin
//			stomp_alnr <= TRUE;
			ff1 <= TRUE;
		end
		else if (pc.pc == misspcr[0].pc)
			stomp_alnr <= FALSE;
		else if (!ff1)
			stomp_alnr <= FALSE;
	end

	if (advance_pipeline|pe_stomp_pipeline) begin
		if (pe_stomp_pipeline)
			stomp_fetr <= TRUE;
		else if (pc_f.pc == misspcr[1].pc || !stomp_aln)
			stomp_fetr <= FALSE;
		else if (!ff1)
			stomp_fetr <= stomp_aln;
	end

	if (advance_pipeline|pe_stomp_pipeline) begin
		if (pe_stomp_pipeline)
			stomp_extr <= TRUE;
		else if (pc_fet.pc == misspcr[2].pc || !stomp_fet) // (next_stomp_ext)
			stomp_extr <= FALSE;
//		else
//			stomp_extr <= stomp_fet;
		if (!ff1)
			stomp_extr <= stomp_fet;
	end

// If a micro-code instruction is decoded stomp on the next decode stage.
// An instruction group following the micro-code was at the fetch stage and
// would be propagated to decode before the micro-code becomes active.

	if (advance_pipeline|pe_stomp_pipeline) begin
		if (pe_stomp_pipeline)
			stomp_motr <= TRUE;
		else if (pc_ext.pc == misspcr[3].pc || !stomp_ext)
			stomp_motr <= FALSE;
		if (!ff1)
			stomp_motr <= stomp_ext;
	end

	if (advance_pipeline|pe_stomp_pipeline) begin
		if (pe_stomp_pipeline)
			stomp_decr <= TRUE;
		else if (pc_mot.pc == misspcr[4].pc || !stomp_mot)
			stomp_decr <= FALSE;
		if (!ff1)
			stomp_decr <= stomp_mot;
	end

	if (advance_pipeline_seg2|pe_stomp_pipeline) begin
		if (pe_stomp_pipeline)
			stomp_renr <= TRUE;
		else if (pc_dec.pc == misspcr[5].pc || !stomp_dec) begin
			stomp_renr <= FALSE;
			ff1 <= FALSE;
		end
		if (!ff1)
			stomp_renr <= stomp_dec;
	end
end

// Q cannot be stomped on in the same manner as the other stages as rename
// has already taken place. Instead the instructions must be allowed to 
// queue and they are turned into copy targets. However if we know the 
// instruction was stomped on before the rename stage, it does not need to
// be queued.

always_ff @(posedge clk2x)
if (rst)
	stomp_quer <= TRUE;
else begin
	if (advance_pipeline_seg2|pe_stomp_pipeline) begin
		if (stomp_ren)
			stomp_quer <= TRUE;
		else
			stomp_quer <= stomp_ren;
	end
end	

always_ff @(posedge clk2x)
if (rst)
	stomp_quemr <= TRUE;
else begin
	if (advance_pipeline_seg2|pe_stomp_pipeline) begin
		if (next_stomp_quem)
			stomp_quemr <= TRUE;
		else
			stomp_quemr <= stomp_ren;
	end
end	
always_comb
	stomp_quem = pe_stomp_pipeline || stomp_quemr;

always_ff @(posedge clk2x)
if (rst)
	stomp_rrr <= TRUE;
else begin
	if (advance_pipeline_seg2|pe_stomp_pipeline) begin
		if (stomp_que)
			stomp_rrr <= TRUE;
		else
			stomp_rrr <= stomp_que;
	end
end

always_comb stomp_que = stomp_quer;


//------------------------------------------------------------------------------
// Back-end stomps
//------------------------------------------------------------------------------
// additional logic for handling a branch miss (STOMP logic)
//
// The kept_stream is the stream we want to keep.
// stomp drives a lot of logic, so it's registered.
// The bitmap is fed to the RAT among other things.

// If the instruction is in the same group as the one with a branch, and 
// it comes after it, stomp on it. This is always done for a taken branch
// even if it is a branch hit. The instructions will have been fetched as
// a group and are not at the target of the branch.
// Somewhat complicated as backout of the target register mappings is
// required.
always_ff @(posedge clk)
begin

	foreach (robentry_stomp[n4]) begin
		robentry_stomp[n4] <= FALSE;
		// Stomp on instructions between the branch and the destination.
		if (branch_resolved) begin
			if (found_destination) begin
				if (rob[n4].sn < rob[destination_rndx].sn && rob[n4].sn > rob[missid].sn)
					robentry_stomp[n4] <= TRUE;
			end
			else begin
				// The first three groups of instructions after miss needs to be stomped on 
				// with no target copies. After that copy targets are in effect.
		//	((branchmiss/*||((takb&~rob[fcu_id].bt) && (fcu_v2|fcu_v3|fcu_v4))*/) || (branch_state<Qupls4_pkg::BS_DONE2 && branch_state!=Qupls4_pkg::BS_IDLE))
				if (
					branchmiss &&
					missid_v &&
					rob[n4].sn > rob[missid].sn &&
					rob[n4].ip_stream!=kept_stream
				)
					robentry_stomp[n4] <= TRUE;
			end

			if (Qupls4_pkg::SUPPORT_BACKOUT) begin
				// These (3) instructions must be turned into copy-targets because even if
				// they should not execute, following instructions from the target address
				// may have registers depending on the mappings.
				if (fcu_idv && (rob[fcu_id].op.decbus.br || rob[fcu_id].op.decbus.cjb)) begin
			 		if (rob[n4].grp==rob[fcu_id].grp && rob[n4].sn > rob[fcu_id].sn)
			 			robentry_stomp[n4] <= FALSE;
				end
			end
			else begin
				if (fcu_idv && rob[fcu_id].op.decbus.br && !takb) begin
			 		if (rob[n4].grp==rob[fcu_id].grp && rob[n4].sn > rob[fcu_id].sn)
			 			robentry_stomp[n4] <= FALSE;
				end
			end
		end

		// Stomp on any dependent instructions.
		if (stomped[rob[n4].ip_stream])
			robentry_stomp[n4] <= TRUE;
	end
end

function [XSTREAMS-1:0] fnComputeBranchDependencies;
input [4:0] ks;
//integer nn, jj, kk, kj;
//reg [XSTREAMS-1:0] list [0:BRANCH_LEVELS];
begin
/*	
    kj = ks;
    for (jj = 0; jj < BRANCH_LEVELS; jj = jj + 1)
        list[jj] = 0;
		for (jj = 0; jj < BRANCH_LEVELS; jj = jj + 1) begin
	    for (nn = 1; nn < XSTREAMS; nn = nn + 1)
	      if (dep_stream[kj][nn] && (nn != kj))
	        list[jj][nn] = list[jj][nn] | dep_stream[kj][nn];
	    for (nn = 1; nn < XSTREAMS; nn = nn + 1) begin
	    	kj = list[jj][nn]?nn:5'd0;
	    	for (kk = 1; kk < XSTREAMS; kk = kk + 1)
	      	if (dep_stream[kj][kk] && (kk != kj))
		    		list[jj+1][kk] = list[jj][kk] | list[jj+1][kk] | dep_stream[kj][kk];
	    end
  	end
*/
  	fnComputeBranchDependencies = |ks ? dep_stream[ks].deps & ~(32'd1 << ks) : 32'd0;
end
endfunction


endmodule
