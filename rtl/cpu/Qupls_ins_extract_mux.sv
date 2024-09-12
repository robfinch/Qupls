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
//
// Multiplex a hardware interrupt into the instruction stream.
// Multiplex micro-code instructions into the instruction stream.
// Modify instructions for register bit lists.
//
// ============================================================================

import QuplsPkg::*;

module Qupls_ins_extract_mux(rst, clk, en, nop, rgi, hirq, irq_i, vect_i, mipv, 
	mc_ins0, mc_ins, ins0, insi, reglist_active, ls_bmf, scale_regs_i, pack_regs,
	regcnt, ins);
input rst;
input clk;
input en;
input nop;
input hirq;
input [1:0] rgi;
input [2:0] irq_i;
input [7:0] vect_i;
input mipv;
input ex_instruction_t mc_ins;
input ex_instruction_t mc_ins0;
input ex_instruction_t ins0;
input ex_instruction_t insi;
input reglist_active;
input ls_bmf;
input [2:0] scale_regs_i;
input pack_regs;
input cpu_types_pkg::aregno_t regcnt;
output ex_instruction_t ins;

ex_instruction_t nopi;

// Define a NOP instruction.
always_comb
begin
	nopi.pc = 32'h0;
	nopi.mcip = 12'h000;
	nopi.len = 4'd6;
	nopi.ins = {41'd0,OP_NOP};
	nopi.pred_btst = 6'd0;
	nopi.element = 'd0;
	nopi.aRa = 8'd0;
	nopi.aRb = 8'd0;
	nopi.aRc = 8'd0;
	nopi.aRt = 8'd0;
end

always_ff @(posedge clk)
if (rst)
	ins <= nopi;
else begin
	if (en)
		ins <= hirq ? {4'd0,vect_i[7:0],2'b0,5'd0,2'b0,5'd0,2'b0,5'd0,irq_i,1'b0,3'b0,1'b0,OP_CHK} :
			mipv ? mc_ins : nop ? nopi : insi;
//	else
//		ins <= {41'd0,OP_NOP};
end

endmodule
