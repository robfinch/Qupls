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

module Qupls_decode_fpu0(instr, fpu0);
input instruction_t instr;
output fpu0;

function fnIsFpu0;
input instruction_t ir;
begin
	case(ir.r2.opcode)
	OP_FLT3:
		case(ir.f3.func)
		FN_FLT2:	
			case(ir.f2.func)
			FN_FLT1:
				case(ir.f1.func)
				FN_FRES:	fnIsFpu0 = 1'b1;
				FN_FSIN:	fnIsFpu0 = 1'b1;
				FN_FCOS:	fnIsFpu0 = 1'b1;
				default:	fnIsFpu0 = 1'b0;
				endcase
			default:	fnIsFpu0 = 1'b0;
			endcase
		default:	fnIsFpu0 = 1'b0;
		endcase
	default:	fnIsFpu0 = 1'b0;
	endcase
end
endfunction

assign fpu0 = fnIsFpu0(instr);

endmodule