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

import QuplsPkg::*;

module Qupls_decode_prec(instr, prec);
input instruction_t instr;
output memsz_t prec;

function memsz_t fnPrec2;
input [2:0] cd;
	case(cd)
	QuplsPkg::PRC8:		fnPrec2 = QuplsPkg::byt;
	QuplsPkg::PRC16:	fnPrec2 = QuplsPkg::wyde;
	QuplsPkg::PRC32:	fnPrec2 = QuplsPkg::tetra;
	QuplsPkg::PRC64:	fnPrec2 = QuplsPkg::octa;
	QuplsPkg::PRC128: fnPrec2 = QuplsPkg::hexi;
	default:	fnPrec2 = QuplsPkg::octa;
	endcase
endfunction

function memsz_t fnPrec;
input instruction_t ir;
begin
	case(ir.r2.opcode)
	OP_CHK:	fnPrec = QuplsPkg::octa;
	OP_R3B:	fnPrec = QuplsPkg::byt;
	OP_R3W:	fnPrec = QuplsPkg::wyde;
	OP_R3T:	fnPrec = QuplsPkg::tetra;
	OP_R3O:	fnPrec = QuplsPkg::octa;
	OP_ADDI,OP_SUBFI,OP_CMPI,
	OP_MULI,OP_MULUI,OP_DIVI,OP_DIVUI,
	OP_ANDI,OP_ORI,OP_EORI:	fnPrec = fnPrec2(ir.ri.prc);
	OP_SHIFTB:	fnPrec = QuplsPkg::byt;
	OP_SHIFTW:	fnPrec = QuplsPkg::wyde;
	OP_SHIFTT:	fnPrec = QuplsPkg::tetra;
	OP_SHIFTO:	fnPrec = QuplsPkg::octa;
	OP_FLT3H:	fnPrec = QuplsPkg::wyde;
	OP_FLT3S:	fnPrec = QuplsPkg::tetra;
	OP_FLT3D:	fnPrec = QuplsPkg::octa;
	OP_FLT3Q:	fnPrec = QuplsPkg::hexi;
	OP_CSR:		fnPrec = QuplsPkg::octa;
	OP_MOV:		fnPrec = QuplsPkg::octa;
	OP_LDA:	fnPrec = QuplsPkg::octa;
	OP_QFEXT,
	OP_VEC,OP_VECZ,
	OP_NOP,OP_PUSH,OP_POP,OP_ENTER,OP_LEAVE,OP_ATOM:
		fnPrec = QuplsPkg::octa;
	OP_FENCE:
		fnPrec = QuplsPkg::octa;
	OP_BSR,OP_JSR:
		fnPrec = QuplsPkg::octa;
	default:	fnPrec = QuplsPkg::octa;
	endcase
end
endfunction

assign prec = fnPrec(instr);

endmodule
