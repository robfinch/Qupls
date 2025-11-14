// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2025  Robert Finch, Waterloo
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

import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_decode_Rs1(om, instr, has_imma, Rs1, Rs1z, exc);
input Qupls4_pkg::operating_mode_t om;
input Qupls4_pkg::micro_op_t instr;
input has_imma;
output aregno_t Rs1;
output reg Rs1z;
output reg exc;

Qupls4_pkg::operating_mode_t om1;

function aregno_t fnRs1;
input Qupls4_pkg::micro_op_t ins;
input has_imma;
Qupls4_pkg::instruction_t ir;
begin
	ir = ins.ins;
	if (has_imma)
		fnRs1 = 8'd0;
	else
		case(ir.any.opcode)
		Qupls4_pkg::OP_MOV:
			if (ir[28:26] < 3'd4)
				fnRs1 = {ir[20:19],ir[15:11]};
			else
				fnRs1 = {2'b00,ir[15:11]};
		Qupls4_pkg::OP_FLT:
			fnRs1 = {2'b01,ir.fpu.Rs1};
		Qupls4_pkg::OP_CSR:
			fnRs1 = {ins.xRs1,ir.csr.Rs1};
		Qupls4_pkg::OP_ADD,Qupls4_pkg::OP_SUBF,Qupls4_pkg::OP_CMP,
		Qupls4_pkg::OP_AND,Qupls4_pkg::OP_OR,Qupls4_pkg::OP_XOR,
		Qupls4_pkg::OP_MUL,Qupls4_pkg::OP_DIV,
		Qupls4_pkg::OP_SHIFT:
			fnRs1 = {ins.xRs1,ir.alui.Rs1};
		Qupls4_pkg::OP_B0,Qupls4_pkg::OP_B1:
			fnRs1 = ir[31] || ir.blrlr.BRs==3'd0 ? 7'd0 : {4'b0100,ir.blrlr.BRs};
		Qupls4_pkg::OP_BCC0,Qupls4_pkg::OP_BCC1:
			fnRs1 = ir.bccld.BRs != 3'd7 && ir.bccld.BRs != 3'd0 ? {4'b0100,ir.bccld.BRs} : 7'd0;
		Qupls4_pkg::OP_LDB,Qupls4_pkg::OP_LDBZ,
		Qupls4_pkg::OP_LDW,Qupls4_pkg::OP_LDWZ,
		Qupls4_pkg::OP_LDT,Qupls4_pkg::OP_LDTZ,
		Qupls4_pkg::OP_LOAD,Qupls4_pkg::OP_LOADA,
		Qupls4_pkg::OP_AMO,Qupls4_pkg::OP_CMPSWAP,
		Qupls4_pkg::OP_STB,Qupls4_pkg::OP_STBI,
		Qupls4_pkg::OP_STW,Qupls4_pkg::OP_STWI,
		Qupls4_pkg::OP_STT,Qupls4_pkg::OP_STTI,
		Qupls4_pkg::OP_STORE,Qupls4_pkg::OP_STOREI,
		Qupls4_pkg::OP_STPTR:
			fnRs1 = {ins.xRs1,ir.lsd.Rs1};
		Qupls4_pkg::OP_PUSH,Qupls4_pkg::OP_POP:
			fnRs1 = 7'd0;
		default:
			fnRs1 = 7'd0;
		endcase
end
endfunction

always_comb
begin
	Rs1 = fnRs1(instr, has_imma);
	if (instr.ins.any.opcode==Qupls4_pkg::OP_MOV && instr.ins[28:26]==3'd1)	// MOVEMD?
		om1 = Qupls4_pkg::operating_mode_t'(instr.ins[24:23]);
    else
        om1 = om;
	Rs1z = ~|Rs1;
	tRegmap(om1, Rs1, Rs1, exc);
end

endmodule
