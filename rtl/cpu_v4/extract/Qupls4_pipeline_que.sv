// ============================================================================
//        __
//   \\__/ o\    (C) 2024-2025  Robert Finch, Waterloo
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
//
// This stage overlaps with the enqueue to the ROB from the rename stage. It
// reflects the values placed in the ROB. Its purpose is to allow access to 
// those values without having to mux them out of the ROB.
// Note that this stage holds onto the last valid rename stage output. This is
// for purposes of bypassing. Invalid stages are ignored.
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_pipeline_que(rst, clk, en,
	ins0_ren, ins1_ren, ins2_ren, ins3_ren, 
	ins0_que, ins1_que, ins2_que, ins3_que
);
input rst;
input clk;
input en;
input Qupls4_pkg::pipeline_group_reg_t pg_reg;
output Qupls4_pkg::pipeline_group_reg_t pg_que;

input Qupls4_pkg::pipeline_reg_t ins0_ren;
input Qupls4_pkg::pipeline_reg_t ins1_ren;
input Qupls4_pkg::pipeline_reg_t ins2_ren;
input Qupls4_pkg::pipeline_reg_t ins3_ren;
output Qupls4_pkg::pipeline_reg_t ins0_que;
output Qupls4_pkg::pipeline_reg_t ins1_que;
output Qupls4_pkg::pipeline_reg_t ins2_que;
output Qupls4_pkg::pipeline_reg_t ins3_que;

Qupls4_pkg::pipeline_reg_t nopi;

// Define a NOP instruction.
always_comb
begin
	nopi = {$bits(Qupls4_pkg::pipeline_reg_t){1'b0}};
	nopi.pc = Qupls4_pkg::RSTPC;
	nopi.pc.stream = 7'd1;
	nopi.uop = {26'd0,Qupls4_pkg::OP_NOP};
	nopi.uop.lead = 1'd1;
	nopi.decbus.Rdz = 1'b1;
	nopi.decbus.nop = 1'b1;
	nopi.decbus.alu = 1'b1;
end

integer nn;

always_ff @(posedge clk)
if (rst)
	foreach (pg_reg[nn])
else begin
	if (en) begin
		foreach (pg_reg[nn])
			pg_que[nn] <= pg_reg[nn];
	end
end
		
always_ff @(posedge clk)
if (rst)
	ins0_que <= nopi;
else begin
	if (en) begin
		if (ins0_ren.v)
			ins0_que <= ins0_ren;
	end
end
always_ff @(posedge clk)
if (rst)
	ins1_que <= nopi;
else begin
	if (en) begin
		if (ins1_ren.v)
			ins1_que <= ins1_ren;
	end
end
always_ff @(posedge clk)
if (rst)
	ins2_que <= nopi;
else begin
	if (en) begin
		if (ins2_ren.v)
			ins2_que <= ins2_ren;
	end
end
always_ff @(posedge clk)
if (rst)
	ins3_que <= nopi;
else begin
	if (en) begin
		if (ins3_ren.v)
			ins3_que <= ins3_ren;
	end
end

endmodule
