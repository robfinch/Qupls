// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
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

module Qupls_ins_extract_mux(clk, en, rgi, hirq, irq_i, vect_i, mipv, mc_ins0, mc_ins, ins0, insi, iRn0, iRn, ls_bmf, scale_regs_i, ins);
input clk;
input en;
input hirq;
input [1:0] rgi;
input [2:0] irq_i;
input [8:0] vect_i;
input mipv;
input instruction_t mc_ins;
input instruction_t mc_ins0;
input instruction_t ins0;
input instruction_t insi;
input aregno_t iRn0;
input aregno_t iRn;
input [2:0] scale_regs_i;
input pack_regs;
input aregno_t regcnt;
output instruction_t ins;

always_ff @(posedge clk)
if (en) begin
	if (~&iRn0)
		ins <= hirq ? {'d0,FN_IRQ,1'b0,vect_i,5'd0,2'd0,irq_i,OP_SYS} : mipv ? mc_ins0 : ins0;
	else
		ins <= hirq ? {'d0,FN_IRQ,1'b0,vect_i,5'd0,2'd0,irq_i,OP_SYS} : mipv ? mc_ins : insi;
	if (&iRn && ~&iRn0) ins <= {'d0,OP_NOP};
	if (~&iRn && ls_bmf) begin
		ins <= ins0;
		ins[12:7] <= iRn;
		ins[31:19] <= {pack_regs ? regcnt + rgi: iRn} << scale_regs_i;
	end
	if (~&iRn) begin
		ins <= ins0;
		ins[18:13] <= iRn;
		ins[31:19] <= {pack_regs ? regcnt + rgi: iRn} << scale_regs_i;
	end
end

endmodule

