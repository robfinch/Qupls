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

module Qupls_decode_prec(instr, prec);
input instruction_t instr;
output [1:0] prec;

function [1:0] fnPrec;
input instruction_t ir;
begin
	case(ir.r2.opcode)
	OP_CHK:	fnPrec = 2'b11;
	OP_R2:	fnPrec = ir[32:31];
	OP_ADDI,OP_VADDI:	
		fnPrec = ir[20:19];
	OP_SUBFI:	fnPrec = ir[20:19];
	OP_CMPI,OP_VCMPI:	
		fnPrec = ir[20:19];
	OP_MULI,OP_VMULI:	
		fnPrec = ir[20:19];
	OP_DIVI,OP_VDIVI:	
		fnPrec = ir[20:19];
	OP_ANDI,OP_VANDI:	
		fnPrec = ir[20:19];
	OP_ORI,OP_VORI:
		fnPrec = ir[20:19];
	OP_EORI,OP_VEORI:
		fnPrec = ir[20:19];
	OP_VADDSI,OP_VORSI,OP_VANDSI,OP_VEORSI,
	OP_ADDSI,OP_ORSI,OP_ANDSI,OP_EORSI:
						fnPrec = ir[17:16];
	OP_SHIFT,OP_VSHIFT:
		fnPrec = ir[35:34];
	OP_FLT3:	fnPrec = ir[35:34];
	OP_CSR:		fnPrec = 2'b11;
	OP_MOV:		fnPrec = 2'b11;
	OP_LDAX:	fnPrec = 2'b11;
	OP_PFXA32,OP_PFXB32,OP_PFXC32,
	OP_QFEXT,
	OP_REGC,
	OP_VEC,OP_VECZ,
	OP_NOP,OP_PUSH,OP_POP,OP_ENTER,OP_LEAVE,OP_ATOM:
		fnPrec = 2'b11;
	OP_FENCE:
		fnPrec = 2'b11;
	OP_BSR,OP_JSR:
		fnPrec = 2'b11;
	default:	fnPrec = 2'b11;
	endcase
end
endfunction

assign prec = fnPrec(instr);

endmodule
