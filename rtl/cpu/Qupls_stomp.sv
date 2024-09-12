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
	stomp_fet, stomp_mux, stomp_vec, stomp_pck, stomp_dec, stomp_ren, stomp_que, stomp_quem
	);
input rst;
input clk;
input ihit;
input advance_pipeline;
input advance_pipeline_seg2;
input micro_code_active;
input branchmiss;
input branch_state_t branch_state;
output reg stomp_fet;
output reg stomp_mux;			// IRQ / micro-code Mux stage
output reg stomp_vec;			// Vector expand stage
output reg stomp_pck;			// instruction Pack stage.
output reg stomp_dec;
output reg stomp_ren;
output reg stomp_que;
output reg stomp_quem;

// Instruction stomp waterfall.

// On a cache miss, the fetch stage is stomped on, but not if micro-code is
// active. Micro-code does not require the cache-line data.
// Invalidate the fetch stage on an unconditional subroutine call.

always_comb
begin
	stomp_fet = FALSE;
	if ((!ihit)// && !micro_code_active)
//		|| branchmiss
//		|| (branch_state >= BS_CHKPT_RESTORE && branch_state <= BS_DONE2)
//		|| (do_bsr && !stomp_mux)
//		|| stomp_fet1a
		)
		stomp_fet = TRUE;
end

wire next_stomp_mux = (stomp_fet && !micro_code_active)
								|| branchmiss
								|| (branch_state >= BS_CHKPT_RESTORE && branch_state <= BS_DONE2)
//								|| (do_bsr && !stomp_mux)
//								|| do_bsr2
								;
always_ff @(posedge clk)
if (rst)
	stomp_mux <= TRUE;
else begin
	if (advance_pipeline)
		stomp_mux <= next_stomp_mux;
end

wire next_stomp_vec = stomp_mux
								|| branchmiss
								|| (branch_state >= BS_CHKPT_RESTORE && branch_state <= BS_DONE2)
//								|| (do_bsr && !stomp_mux)
//								|| do_bsr2
								;
always_ff @(posedge clk)
if (rst)
	stomp_vec <= TRUE;
else begin
	if (advance_pipeline)
		stomp_vec <= next_stomp_vec;
end

wire next_stomp_pck = stomp_vec
								|| branchmiss
								|| (branch_state >= BS_CHKPT_RESTORE && branch_state <= BS_DONE2)
//								|| (do_bsr && !stomp_mux)
//								|| do_bsr2
								;
always_ff @(posedge clk)
if (rst)
	stomp_pck <= TRUE;
else begin
	if (advance_pipeline)
		stomp_pck <= next_stomp_pck;
end

// If a micro-code instruction is decoded stomp on the next decode stage.
// An instruction group following the micro-code was at the fetch stage and
// would be propagated to decode before the micro-code becomes active.

wire next_stomp_dec = stomp_pck
								|| branchmiss
								|| (branch_state >= BS_CHKPT_RESTORE && branch_state <= BS_DONE2)
//								|| (do_bsr && !stomp_mux)
								;
always_ff @(posedge clk)
if (rst)
	stomp_dec <= TRUE;
else begin
	if (advance_pipeline)
		stomp_dec <= next_stomp_dec;
end

wire next_stomp_ren = stomp_dec
								|| branchmiss
								|| (branch_state >= BS_CHKPT_RESTORE && branch_state <= BS_DONE2)
								;
always_ff @(posedge clk)
if (rst)
	stomp_ren <= TRUE;
else begin
	if (advance_pipeline_seg2)
		stomp_ren <= next_stomp_ren;
end

// Q cannot be stomped on in the same manner as the other stages as rename
// has already taken place. Instead the instructions must be allowed to 
// queue and they are turned into copy targets. However if we know the 
// instruction was stomped on before the rename stage, it does not need to
// be queued.

always_ff @(posedge clk)
if (rst)
	stomp_que <= TRUE;
else begin
	if (advance_pipeline_seg2)
		stomp_que <= stomp_ren;
end	

wire next_stomp_quem = 	 branchmiss
								|| (branch_state >= BS_CHKPT_RESTORE && branch_state <= BS_DONE2)
								;
always_ff @(posedge clk)
if (rst)
	stomp_quem <= TRUE;
else begin
	if (advance_pipeline_seg2)
		stomp_quem <= next_stomp_quem;
end	


endmodule
