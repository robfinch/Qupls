// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2024  Robert Finch, Waterloo
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

import QuplsPkg::*;

module Qupls_decode_macro(instr, macro);
input instruction_t instr;
output macro;

function fnIsMacro;
input instruction_t ir;
begin
	case(ir.r2.opcode)
	OP_R3V,OP_R3VS:
		case(ir.r2.func)
		FN_ADD:	fnIsMacro = 1'b1;
		FN_CMP:	fnIsMacro = 1'b1;
		FN_MUL:	fnIsMacro = 1'b1;
		FN_MULW:	fnIsMacro = 1'b1;
		FN_DIV:	fnIsMacro = 1'b1;
		FN_SUB:	fnIsMacro = 1'b1;
		FN_MULU: fnIsMacro = 1'b1;
		FN_MULUW: fnIsMacro = 1'b1;
		FN_DIVU: fnIsMacro = 1'b1;
		FN_AND:	fnIsMacro = 1'b1;
		FN_OR:	fnIsMacro = 1'b1;
		FN_EOR:	fnIsMacro = 1'b1;
		FN_NAND:	fnIsMacro = 1'b1;
		FN_NOR:	fnIsMacro = 1'b1;
		FN_ENOR:	fnIsMacro = 1'b1;
		FN_SEQ:	fnIsMacro = 1'b1;
		FN_SNE:	fnIsMacro = 1'b1;
		FN_SLT:	fnIsMacro = 1'b1;
		FN_SLE:	fnIsMacro = 1'b1;
		FN_SLTU:	fnIsMacro = 1'b1;
		FN_SLEU:	fnIsMacro = 1'b1;
		FN_ZSEQ:	fnIsMacro = 1'b1;
		FN_ZSNE:	fnIsMacro = 1'b1;
		FN_ZSLT:	fnIsMacro = 1'b1;
		FN_ZSLE:	fnIsMacro = 1'b1;
		FN_ZSLTU:	fnIsMacro = 1'b1;
		FN_ZSLEU:	fnIsMacro = 1'b1;
		default:	fnIsMacro = 1'b0;
		endcase
	OP_VADDI:	
		fnIsMacro = 1'b1;
	OP_VCMPI:	
		fnIsMacro = 1'b1;
	OP_VMULI:	
		fnIsMacro = 1'b1;
	OP_VDIVI:	
		fnIsMacro = 1'b1;
	OP_VANDI:	
		fnIsMacro = 1'b1;
	OP_VORI:
		fnIsMacro = 1'b1;
	OP_VEORI:
		fnIsMacro = 1'b1;
	OP_VADDSI,OP_VORSI,OP_VANDSI,OP_VEORSI:
						fnIsMacro = 1'b1;
	OP_VSHIFT:
		fnIsMacro = 1'b1;
	OP_PUSH,OP_POP,OP_ENTER,OP_LEAVE:
		fnIsMacro = 1'b1;
	default:	fnIsMacro = 1'b0;
	endcase
end
endfunction

assign macro = fnIsMacro(instr);

endmodule
