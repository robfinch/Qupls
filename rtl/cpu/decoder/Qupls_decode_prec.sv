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
output memsz_t prec;

function memsz_t fnPrec;
input instruction_t ir;
begin
	case(ir.r2.opcode)
	OP_CHK:	fnPrec = QuplsPkg::hexi;
	OP_R2:	fnPrec = QuplsPkg::hexi;
	OP_ADDI:	
		fnPrec = QuplsPkg::hexi;
	OP_SUBFI:	fnPrec = QuplsPkg::hexi;
	OP_CMPI:	
		fnPrec = QuplsPkg::hexi;
	OP_MULI:	
		fnPrec = QuplsPkg::hexi;
	OP_DIVI:	
		fnPrec = QuplsPkg::hexi;
	OP_ANDI:	
		fnPrec = QuplsPkg::hexi;
	OP_ORI:
		fnPrec = QuplsPkg::hexi;
	OP_EORI:
		fnPrec = QuplsPkg::hexi;
	OP_ADDSI,OP_ORSI,OP_ANDSI,OP_EORSI:
						fnPrec = QuplsPkg::hexi;
	OP_SHIFT:
		case(ir[43:41])
		3'd0:	fnPrec = QuplsPkg::byt;
		3'd1:	fnPrec = QuplsPkg::wyde;
		3'd2:	fnPrec = QuplsPkg::tetra;
		3'd3:	fnPrec = QuplsPkg::octa;
		3'd4: fnPrec = QuplsPkg::hexi;
		default:	fnPrec = QuplsPkg::hexi;
		endcase
	OP_FLT3:	fnPrec = QuplsPkg::octa;
	OP_CSR:		fnPrec = QuplsPkg::octa;
	OP_MOV:		fnPrec = QuplsPkg::hexi;
	OP_LDAX:	fnPrec = QuplsPkg::octa;
	OP_QFEXT,
	OP_VEC,OP_VECZ,
	OP_NOP,OP_PUSH,OP_POP,OP_ENTER,OP_LEAVE,OP_ATOM:
		fnPrec = QuplsPkg::hexi;
	OP_FENCE:
		fnPrec = QuplsPkg::hexi;
	OP_BSR,OP_JSR:
		fnPrec = QuplsPkg::octa;
	default:	fnPrec = QuplsPkg::hexi;
	endcase
end
endfunction

assign prec = fnPrec(instr);

endmodule
