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
import Stark_pkg::*;

module Stark_pipeline_que(rst, clk, en,
	ins0_ren, ins1_ren, ins2_ren, ins3_ren, 
	ins0_que, ins1_que, ins2_que, ins3_que,
	micro_code_active_ren, micro_code_active_que 
);
input rst;
input clk;
input en;
input Stark_pkg::pipeline_reg_t ins0_ren;
input Stark_pkg::pipeline_reg_t ins1_ren;
input Stark_pkg::pipeline_reg_t ins2_ren;
input Stark_pkg::pipeline_reg_t ins3_ren;
output Stark_pkg::pipeline_reg_t ins0_que;
output Stark_pkg::pipeline_reg_t ins1_que;
output Stark_pkg::pipeline_reg_t ins2_que;
output Stark_pkg::pipeline_reg_t ins3_que;
input micro_code_active_ren;
output reg micro_code_active_que;

Stark_pkg::pipeline_reg_t nopi;

// Define a NOP instruction.
always_comb
begin
	nopi = {$bits(Stark_pkg::pipeline_reg_t){1'b0}};
	nopi.pc = Stark_pkg::RSTPC;
	nopi.pc.bno_t = 6'd1;
	nopi.pc.bno_f = 6'd1;
	nopi.mcip = 12'h1A0;
	nopi.len = 4'd6;
	nopi.ins = {26'd0,Stark_pkg::OP_NOP};
	nopi.pred_btst = 6'd0;
	nopi.element = 'd0;
	nopi.aRa = 8'd0;
	nopi.aRb = 8'd0;
	nopi.aRc = 8'd0;
	nopi.aRt = 8'd0;
	nopi.decbus.Rtz = 1'b1;
	nopi.decbus.nop = 1'b1;
	nopi.decbus.alu = 1'b1;
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

always_ff @(posedge clk)
if (rst)
	micro_code_active_que <= FALSE;
else begin
	if (en)
		micro_code_active_que <= micro_code_active_ren;
end

endmodule
