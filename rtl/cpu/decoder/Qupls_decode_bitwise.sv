// ============================================================================
//        __
//   \\__/ o\    (C) 2024  Robert Finch, Waterloo
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

module Qupls_decode_bitwise(instr, bitwise);
input instruction_t instr;
output bitwise;

function fnIsBitwise;
input instruction_t ir;
begin
	case(ir.r2.opcode)
	OP_R2:
		case(ir.r2.func)
		FN_CPUID:	fnIsBitwise = 1'b1;
		FN_AND:	fnIsBitwise = 1'b1;
		FN_OR:	fnIsBitwise = 1'b1;
		FN_EOR:	fnIsBitwise = 1'b1;
		FN_NAND:	fnIsBitwise = 1'b1;
		FN_NOR:	fnIsBitwise = 1'b1;
		FN_ENOR:	fnIsBitwise = 1'b1;
		default:	fnIsBitwise = 1'b0;
		endcase
	OP_ANDI:	
		fnIsBitwise = 1'b1;
	OP_ORI:
		fnIsBitwise = 1'b1;
	OP_EORI:
		fnIsBitwise = 1'b1;
	OP_ORSI,OP_ANDSI,OP_EORSI:
						fnIsBitwise = 1'b1;
	default:	fnIsBitwise = 1'b0;
	endcase
end
endfunction

assign bitwise = fnIsBitwise(instr);

endmodule