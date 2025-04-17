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
import Stark_pkg::*;

module Stark_decode_Rs2(om, instr, has_immb, Rs2, Rs2z, exc);
input Stark_pkg::operating_mode_t om;
input Stark_pkg::ex_instruction_t instr;
input has_immb;
output aregno_t Rs2;
output reg Rs2z;
output exc;

function aregno_t fnRs2;
input Stark_pkg::ex_instruction_t ir;
input has_immb;
begin
	if (has_immb)
		fnRs2 = 8'd0;
	else
		case(ir.ins.any.opcode)
		Stark_pkg::OP_FLT:
			fnRs2 = {2'b01,ir.ins.fpu.Rs2};
		Stark_pkg::OP_CSR:
			fnRs2 = ir.ins[31:29]==3'd0 ? {2'b00,ir.ins.csrr.Rs2} : 7'd0;
		Stark_pkg::OP_B0,Stark_pkg::OP_B1,Stark_pkg::OP_BCC0,Stark_pkg::OP_BCC1:
			if (ir.ins[30:29]==2'b00 && ir.ins[8:6]!=3'd7)
				fnRs2 = {2'b00,ir.ins[15:11]};
			else
				fnRs2 = 7'd0;
		Stark_pkg::OP_ADD,Stark_pkg::OP_SUBF,Stark_pkg::OP_CMP,
		Stark_pkg::OP_AND,Stark_pkg::OP_OR,Stark_pkg::OP_XOR,
		Stark_pkg::OP_MUL,Stark_pkg::OP_DIV,
		Stark_pkg::OP_SHIFT:
			fnRs2 = {2'b00,ir.ins.alu.Rs2};
		Stark_pkg::OP_LDB,Stark_pkg::OP_LDBZ,Stark_pkg::OP_LDW,Stark_pkg::OP_LDWZ,
		Stark_pkg::OP_LDT,Stark_pkg::OP_LDTZ,Stark_pkg::OP_LOAD,Stark_pkg::OP_LOADA,
		Stark_pkg::OP_AMO,Stark_pkg::OP_CMPSWAP,
		Stark_pkg::OP_STB,Stark_pkg::OP_STBI,Stark_pkg::OP_STW,Stark_pkg::OP_STWI,
		Stark_pkg::OP_STT,Stark_pkg::OP_STTI,Stark_pkg::OP_STORE,Stark_pkg::OP_STOREI,
		Stark_pkg::OP_STPTR:
			fnRs2 = {2'b00,ir.ins.lsscn.Rs2};
		default:
			fnRs2 = 7'd0;
		endcase
end
endfunction

always_comb
begin
	Rs2 = fnRs2(instr, has_immb);
	Rs2z = ~|Rs2;
	tRegmap(om, Rs2, Rs2, exc);
end

endmodule
