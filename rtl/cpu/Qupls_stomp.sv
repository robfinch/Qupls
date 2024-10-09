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
// ============================================================================

import const_pkg::*;
import QuplsPkg::*;

module Qupls_stomp(rst, clk, ihit, advance_pipeline, advance_pipeline_seg2, 
	micro_code_active, branchmiss, branch_state, do_bsr,
	stomp_fet, stomp_mux, stomp_dec, stomp_ren, stomp_que, stomp_quem
	);
input rst;
input clk;
input ihit;
input advance_pipeline;
input advance_pipeline_seg2;
input micro_code_active;
input branchmiss;
input branch_state_t branch_state;
input do_bsr;
output reg stomp_fet;
output reg stomp_mux;			// IRQ / micro-code Mux stage
output reg stomp_dec;
output reg stomp_ren;
output reg stomp_que;
output reg stomp_quem;

reg stomp_muxr;
reg stomp_decr;
reg stomp_renr;
reg stomp_quemr;

reg stomp_pipeline;
wire pe_stomp_pipeline;
always_comb
	stomp_pipeline = 
			 branchmiss
		|| (branch_state >= BS_CHKPT_RESTORE && branch_state <= BS_DONE2)
		;
wire next_stomp_mux = (stomp_fet && !micro_code_active) || stomp_pipeline || do_bsr;
wire next_stomp_dec = (stomp_mux && !micro_code_active) || stomp_pipeline;
wire next_stomp_ren = (stomp_dec && !micro_code_active) || stomp_pipeline;
wire next_stomp_quem = (stomp_ren && !micro_code_active) || stomp_pipeline;

edge_det ued1 (.rst(rst), .clk(clk), .ce(advance_pipeline), .i(stomp_pipeline), .pe(pe_stomp_pipeline), .ne(), .ee());	

reg do_bsr1;
always_ff @(posedge clk)
if (rst)
	do_bsr1 <= FALSE;
else begin
	if (advance_pipeline)
		do_bsr1 <= do_bsr;
end

// Instruction stomp waterfall.

// On a cache miss, the fetch stage is stomped on, but not if micro-code is
// active. Micro-code does not require the cache-line data.
// Invalidate the fetch stage on an unconditional subroutine call.

always_comb
begin
	stomp_fet = FALSE;
	if (stomp_pipeline)
//		|| do_bsr
//		||do_bsr1
		stomp_fet = TRUE;
end

always_ff @(posedge clk)
if (rst)
	stomp_muxr <= TRUE;
else begin
	if (advance_pipeline)
		stomp_muxr <= next_stomp_mux;
end
always_comb
	stomp_mux = pe_stomp_pipeline || stomp_muxr;

// If a micro-code instruction is decoded stomp on the next decode stage.
// An instruction group following the micro-code was at the fetch stage and
// would be propagated to decode before the micro-code becomes active.

always_ff @(posedge clk)
if (rst)
	stomp_decr <= TRUE;
else begin
	if (advance_pipeline)
		stomp_decr <= next_stomp_dec;
end
always_comb
	stomp_dec = pe_stomp_pipeline || stomp_decr;

always_ff @(posedge clk)
if (rst)
	stomp_renr <= TRUE;
else begin
	if (advance_pipeline_seg2 ||
		advance_pipeline)
		stomp_renr <= next_stomp_ren;
end
always_comb
	stomp_ren = pe_stomp_pipeline || stomp_renr;

// Q cannot be stomped on in the same manner as the other stages as rename
// has already taken place. Instead the instructions must be allowed to 
// queue and they are turned into copy targets. However if we know the 
// instruction was stomped on before the rename stage, it does not need to
// be queued.

always_ff @(posedge clk)
if (rst)
	stomp_que <= TRUE;
else begin
	if (advance_pipeline||advance_pipeline_seg2)
		stomp_que <= stomp_ren;
end	

always_ff @(posedge clk)
if (rst)
	stomp_quemr <= TRUE;
else begin
	if (advance_pipeline||advance_pipeline_seg2)
		stomp_quemr <= next_stomp_quem;
end	
always_comb
	stomp_quem = pe_stomp_pipeline || stomp_quemr;


endmodule
