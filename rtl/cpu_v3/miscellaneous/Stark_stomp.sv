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
// Compute stomps
// 1) figure stomps in the front end pipeline
// 2) figure stomps in the re-order buffer
// ============================================================================

import const_pkg::*;
import Stark_pkg::*;

module Stark_stomp(rst, clk, ihit, advance_pipeline, advance_pipeline_seg2, 
	micro_machine_active, branchmiss, found_destination, destination_rndx,
	branch_state, do_bsr, misspc,
	pc, pc_f, pc_fet, pc_mux, pc_dec, pc_ren,
	stomp_fet, stomp_mux, stomp_dec, stomp_ren, stomp_que, stomp_quem,
	fcu_idv, fcu_id, missid, stomp_bno, takb, rob, robentry_stomp
	);
input rst;
input clk;
input ihit;
input advance_pipeline;
input advance_pipeline_seg2;
input micro_machine_active;
input found_destination;	// true if destination was found in ROB
input destination_rndx;
input branchmiss;
input Stark_pkg::branch_state_t branch_state;
input do_bsr;
input pc_address_ex_t misspc;
input pc_address_ex_t pc;
input pc_address_ex_t pc_f;
input pc_address_ex_t pc_fet;
input pc_address_ex_t pc_mux;
input pc_address_ex_t pc_dec;
input pc_address_ex_t pc_ren;
output reg stomp_fet;
output reg stomp_mux;			// IRQ / micro-code Mux stage
output reg stomp_dec;
output reg stomp_ren;
output reg stomp_que;
output reg stomp_quem;
input fcu_idv;
input rob_ndx_t fcu_id;
input rob_ndx_t missid;
input [4:0] stomp_bno;
input takb;
input Stark_pkg::rob_entry_t [Stark_pkg::ROB_ENTRIES-1:0] rob;
output reg [Stark_pkg::ROB_ENTRIES-1:0] robentry_stomp;

integer nn, n4;
pc_address_ex_t [4:0] misspcr;
reg stomp_aln;
reg stomp_alnr;
reg stomp_fetr;
reg stomp_muxr;
reg stomp_decr;
reg stomp_renr;
reg stomp_quer;
reg stomp_rrr;
reg stomp_quemr;
reg do_bsr_mux;
reg do_bsr_dec;
reg do_bsr_ren;
reg do_bsr_que;
reg do_bsr_rrr;

reg stomp_pipeline;
reg [3:0] spl;
wire pe_stomp_pipeline;
always_comb
	stomp_pipeline = 
			 (branchmiss && !found_destination)
		|| (branch_state >= Stark_pkg::BS_CHKPT_RESTORE && branch_state <= Stark_pkg::BS_DONE2)
		;
wire next_stomp_mux = (stomp_fet && !micro_machine_active) || stomp_pipeline || (do_bsr && !found_destination);
wire next_stomp_dec = (stomp_mux && !micro_machine_active) || stomp_pipeline;
wire next_stomp_ren = (stomp_dec && !micro_machine_active) || stomp_pipeline;
wire next_stomp_quem = (stomp_ren && !micro_machine_active) || stomp_pipeline;

reg [2:0] bsi;
wire pe_bsidle;
edge_det uedbsi1 (.rst(irst), .clk(clk), .ce(1'b1), .i(branch_state==Stark_pkg::BS_IDLE), .pe(pe_bsidle), .ne(), .ee());
edge_det ued1 (.rst(rst), .clk(clk), .ce(advance_pipeline), .i(stomp_pipeline), .pe(pe_stomp_pipeline), .ne(), .ee());	
always_ff @(posedge clk) if (advance_pipeline_seg2) bsi <= {bsi[1:0],pe_bsidle};

always_ff @(posedge clk)
if (rst) begin
	for (nn = 0; nn < 5; nn = nn + 1) begin
		misspcr[nn].bno_t <= 5'd1;
		misspcr[nn].bno_f <= 5'd0;
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
	end
end

always_ff @(posedge clk)
if (rst)
	spl <= 4'b0000;
else begin
	spl <= {spl[2:0],stomp_pipeline};
//	if (advance_pipeline)
//		spl <= 4'b0000;
end

reg do_bsr1;
always_ff @(posedge clk)
if (rst)
	do_bsr1 <= 3'b000;
else begin
	if (advance_pipeline)
		do_bsr1 <= do_bsr;
end

// Instruction stomp waterfall.

always_comb
	stomp_aln = (stomp_alnr || pe_stomp_pipeline) && (pc.pc != misspcr[0].pc);
always_comb
	stomp_fet = (stomp_fetr || pe_stomp_pipeline) && (pc_f.pc != misspcr[1].pc);
always_comb
	stomp_mux = (pe_stomp_pipeline || stomp_muxr) && (pc_fet.pc != misspcr[2].pc);
always_comb
	stomp_dec = (pe_stomp_pipeline || stomp_decr) && (pc_mux.pc != misspcr[3].pc);
always_comb
	stomp_ren = (pe_stomp_pipeline || stomp_renr) && (pc_dec.pc != misspcr[4].pc);

// On a cache miss, the fetch stage is stomped on, but not if micro-code is
// active. Micro-code does not require the cache-line data.
// Invalidate the fetch stage on an unconditional subroutine call.

reg ff1;
pc_address_ex_t prev_pc;
always_ff @(posedge clk)
if (rst) begin
	stomp_alnr <= FALSE;
	stomp_fetr <= TRUE;
	stomp_muxr <= TRUE;
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
			stomp_alnr <= (do_bsr & ~found_destination);
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
		do_bsr_mux <= (do_bsr & ~found_destination);
		if (pe_stomp_pipeline)
			stomp_muxr <= TRUE;
		else if (pc_fet.pc == misspcr[2].pc || !stomp_fet) // (next_stomp_mux)
			stomp_muxr <= FALSE;
//		else
//			stomp_muxr <= stomp_fet;
		if (!ff1)
			stomp_muxr <= stomp_fet;
	end

// If a micro-code instruction is decoded stomp on the next decode stage.
// An instruction group following the micro-code was at the fetch stage and
// would be propagated to decode before the micro-code becomes active.

	if (advance_pipeline|pe_stomp_pipeline) begin
		do_bsr_dec <= do_bsr_mux;
		if (pe_stomp_pipeline)
			stomp_decr <= TRUE;
		else if (pc_mux.pc == misspcr[3].pc || !stomp_mux)
			stomp_decr <= FALSE;
		if (!ff1)
			stomp_decr <= stomp_mux;
	end

	if (advance_pipeline_seg2|pe_stomp_pipeline) begin
		do_bsr_ren <= do_bsr_dec;
		if (pe_stomp_pipeline)
			stomp_renr <= TRUE;
		else if (pc_dec.pc == misspcr[4].pc || !stomp_dec) begin
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

always_ff @(posedge clk)
if (rst)
	stomp_quer <= TRUE;
else begin
	if (advance_pipeline_seg2|pe_stomp_pipeline) begin
		do_bsr_que <= do_bsr_ren;
		if (stomp_ren)
			stomp_quer <= TRUE;
		else
			stomp_quer <= stomp_ren;
	end
end	

always_ff @(posedge clk)
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

always_ff @(posedge clk)
if (rst)
	stomp_rrr <= TRUE;
else begin
	if (advance_pipeline_seg2|pe_stomp_pipeline) begin
		do_bsr_rrr <= do_bsr_que;
		if (stomp_que)
			stomp_rrr <= TRUE;
		else
			stomp_rrr <= stomp_que;
	end
end

always_comb stomp_que = do_bsr_rrr ? stomp_quer | stomp_rrr : stomp_quer;

// 
// additional logic for handling a branch miss (STOMP logic)
//
// stomp drives a lot of logic, so it's registered.
// The bitmap is fed to the RAT among other things.

// If the instruction is in the same group as the one with a branch, and 
// it comes after it, stomp on it. This is always done for a taken branch
// even if it is a branch hit. The instructions will have been fetched as
// a group and are not at the target of the branch.
// Somewhat complicated as backout of the target register mappings is
// required.
always_ff @(posedge clk)
for (n4 = 0; n4 < Stark_pkg::ROB_ENTRIES; n4 = n4 + 1) begin
	robentry_stomp[n4] = FALSE;
	// Stomp on instructions between the branch and the destination.
	if (found_destination) begin
		if (rob[n4].sn < rob[destination_rndx].sn && rob[n4].sn > rob[missid].sn)
			robentry_stomp[n4] = TRUE;
	end
	else begin
		// The first three groups of instructions after miss needs to be stomped on 
		// with no target copies. After that copy targets are in effect.
//	((branchmiss/*||((takb&~rob[fcu_id].bt) && (fcu_v2|fcu_v3|fcu_v4))*/) || (branch_state<Stark_pkg::BS_DONE2 && branch_state!=Stark_pkg::BS_IDLE))
		if ((branchmiss || (branch_state<Stark_pkg::BS_DONE2 && branch_state!=Stark_pkg::BS_IDLE)) &&
			rob[n4].sn > rob[missid].sn &&
			fcu_idv	&& // miss_idv
			rob[n4].op.pc.bno_t!=stomp_bno
		)
			robentry_stomp[n4] = TRUE;
	end
	
	if (Stark_pkg::SUPPORT_BACKOUT) begin
		// These (3) instructions must be turned into copy-targets because even if
		// they should not execute, following instructions from the target address
		// may have registers depending on the mappings.
		if (fcu_idv && (rob[fcu_id].decbus.br || rob[fcu_id].decbus.cjb)) begin
	 		if (rob[n4].grp==rob[fcu_id].grp && rob[n4].sn > rob[fcu_id].sn)
	 			robentry_stomp[n4] = FALSE;
		end
	end
	else begin
		if (fcu_idv && rob[fcu_id].decbus.br && !takb) begin
	 		if (rob[n4].grp==rob[fcu_id].grp && rob[n4].sn > rob[fcu_id].sn)
	 			robentry_stomp[n4] = FALSE;
		end
	end
	
end


endmodule
