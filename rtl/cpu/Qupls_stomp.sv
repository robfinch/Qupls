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
	micro_code_active, branchmiss, branch_state, 
	stomp_f, stomp_x1, stomp_x2, stomp_x3, stomp_d, stomp_r, stomp_q, stomp_qm
	);
input rst;
input clk;
input ihit;
input advance_pipeline;
input advance_pipeline_seg2;
input micro_code_active;
input branchmiss;
input branch_state_t branch_state;
output reg stomp_f;
output reg stomp_x1;
output reg stomp_x2;
output reg stomp_x3;
output reg stomp_d;
output reg stomp_r;
output reg stomp_q;
output reg stomp_qm;

// Instruction stomp waterfall.

// On a cache miss, the fetch stage is stomped on, but not if micro-code is
// active. Micro-code does not require the cache-line data.
// Invalidate the fetch stage on an unconditional subroutine call.

always_comb
begin
	stomp_f = FALSE;
	if ((!ihit)// && !micro_code_active)
//		|| branchmiss
//		|| (branch_state >= BS_CHKPT_RESTORE && branch_state <= BS_DONE2)
//		|| (do_bsr && !stomp_x1)
//		|| stomp_f1a
		)
		stomp_f = TRUE;
end

wire next_stomp_x1 = (stomp_f && !micro_code_active)
								|| branchmiss
								|| (branch_state >= BS_CHKPT_RESTORE && branch_state <= BS_DONE2)
//								|| (do_bsr && !stomp_x1)
//								|| do_bsr2
								;
always_ff @(posedge clk)
if (rst)
	stomp_x1 <= TRUE;
else begin
	if (advance_pipeline)
		stomp_x1 <= next_stomp_x1;
end

wire next_stomp_x2 = stomp_x1
								|| branchmiss
								|| (branch_state >= BS_CHKPT_RESTORE && branch_state <= BS_DONE2)
//								|| (do_bsr && !stomp_x1)
//								|| do_bsr2
								;
always_ff @(posedge clk)
if (rst)
	stomp_x2 <= TRUE;
else begin
	if (advance_pipeline)
		stomp_x2 <= next_stomp_x2;
end

wire next_stomp_x3 = stomp_x2
								|| branchmiss
								|| (branch_state >= BS_CHKPT_RESTORE && branch_state <= BS_DONE2)
//								|| (do_bsr && !stomp_x1)
//								|| do_bsr2
								;
always_ff @(posedge clk)
if (rst)
	stomp_x3 <= TRUE;
else begin
	if (advance_pipeline)
		stomp_x3 <= next_stomp_x3;
end

// If a micro-code instruction is decoded stomp on the next decode stage.
// An instruction group following the micro-code was at the fetch stage and
// would be propagated to decode before the micro-code becomes active.

wire next_stomp_d = stomp_x3
								|| branchmiss
								|| (branch_state >= BS_CHKPT_RESTORE && branch_state <= BS_DONE2)
//								|| (do_bsr && !stomp_x1)
								;
always_ff @(posedge clk)
if (rst)
	stomp_d <= TRUE;
else begin
	if (advance_pipeline)
		stomp_d <= next_stomp_d;
end
// pe_mca is delayed a cycle. A stomp is needed at decode stage.
always_comb
	stomp_d = stomp_d;// && !micro_code_active_x;// || pe_mca;

wire next_stomp_r = stomp_d
								|| branchmiss
								|| (branch_state >= BS_CHKPT_RESTORE && branch_state <= BS_DONE2)
								;
always_ff @(posedge clk)
if (rst)
	stomp_r <= TRUE;
else begin
	if (advance_pipeline_seg2)
		stomp_r <= next_stomp_r;
end

// Q cannot be stomped on in the same manner as the other stages as rename
// has already taken place. Instead the instructions must be allowed to 
// queue and they are turned into copy targets. However if we know the 
// instruction was stomped on before the rename stage, it does not need to
// be queued.

always_ff @(posedge clk)
if (rst)
	stomp_q <= TRUE;
else begin
	if (advance_pipeline_seg2)
		stomp_q <= stomp_r;
end	

wire next_stomp_qm = 	 branchmiss
								|| (branch_state >= BS_CHKPT_RESTORE && branch_state <= BS_DONE2)
								;
always_ff @(posedge clk)
if (rst)
	stomp_qm <= TRUE;
else begin
	if (advance_pipeline_seg2)
		stomp_qm <= next_stomp_qm;
end	


endmodule
