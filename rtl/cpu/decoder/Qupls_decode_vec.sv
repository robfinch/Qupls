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

module Qupls_decode_vec(instr, vec);
input instruction_t instr;
output vec;

function fnIsVec;
input instruction_t ir;
begin
	case(ir.r2.opcode)
	OP_SYS:	fnIsVec = 1'b0;
	OP_R3V,OP_R3VS:
		case(ir.r2.func)
		FN_ADD:	fnIsVec = 1'b1;
		FN_CMP:	fnIsVec = 1'b1;
		FN_MUL:	fnIsVec = 1'b1;
		FN_MULW:	fnIsVec = 1'b1;
		FN_DIV:	fnIsVec = 1'b1;
		FN_SUB:	fnIsVec = 1'b1;
		FN_MULU: fnIsVec = 1'b1;
		FN_MULUW: fnIsVec = 1'b1;
		FN_DIVU: fnIsVec = 1'b1;
		FN_AND:	fnIsVec = 1'b1;
		FN_OR:	fnIsVec = 1'b1;
		FN_EOR:	fnIsVec = 1'b1;
		FN_NAND:	fnIsVec = 1'b1;
		FN_NOR:	fnIsVec = 1'b1;
		FN_ENOR:	fnIsVec = 1'b1;
		FN_SEQ:	fnIsVec = 1'b1;
		FN_SNE:	fnIsVec = 1'b1;
		FN_SLT:	fnIsVec = 1'b1;
		FN_SLE:	fnIsVec = 1'b1;
		FN_SLTU:	fnIsVec = 1'b1;
		FN_SLEU:	fnIsVec = 1'b1;
		FN_ZSEQ:	fnIsVec = 1'b1;
		FN_ZSNE:	fnIsVec = 1'b1;
		FN_ZSLT:	fnIsVec = 1'b1;
		FN_ZSLE:	fnIsVec = 1'b1;
		FN_ZSLTU:	fnIsVec = 1'b1;
		FN_ZSLEU:	fnIsVec = 1'b1;
		default:	fnIsVec = 1'b0;
		endcase
	OP_VADDI:	
		fnIsVec = 1'b1;
	OP_VCMPI:	
		fnIsVec = 1'b1;
	OP_VMULI:	
		fnIsVec = 1'b1;
	OP_VDIVI:	
		fnIsVec = 1'b1;
	OP_VANDI:	
		fnIsVec = 1'b1;
	OP_VORI:
		fnIsVec = 1'b1;
	OP_VEORI:
		fnIsVec = 1'b1;
	OP_VADDSI,OP_VORSI,OP_VANDSI,OP_VEORSI:
						fnIsVec = 1'b1;
	OP_VSHIFT:
		fnIsVec = 1'b1;
	default:	fnIsVec = 1'b0;
	endcase
end
endfunction

assign vec = fnIsVec(instr);

endmodule
