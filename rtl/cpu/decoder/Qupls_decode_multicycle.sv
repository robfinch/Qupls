// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2025  Robert Finch, Waterloo
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

module Qupls_decode_multicycle(instr, multicycle);
input instruction_t instr;
output multicycle;

function fnIsMC;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_FLT3H,OP_FLT3S,OP_FLT3D,OP_FLT3Q:
		case(ir.f3.func)
		FN_FLT1:
			case(ir.f1.func)
			FN_FTOI: fnIsMC = 1'b1;
			FN_ITOF: fnIsMC = 1'b1;
			FN_FSIN:	fnIsMC = 1'b1;
			FN_FCOS:	fnIsMC = 1'b1;
//			FN_FSQRT: done = sqrt_done;
			FN_FRES:	fnIsMC = 1'b1;
			FN_FTRUNC:	fnIsMC = 1'b1;
			default:	fnIsMC = 1'b0;
			endcase
		FN_FSCALEB: fnIsMC = 1'b1;
		FN_FADD,FN_FSUB,FN_FMUL:
			fnIsMC = 1'b1;
		default:	fnIsMC = 1'b0;
		endcase
	FN_FMA,FN_FMS,FN_FNMA,FN_FNMS:
		fnIsMC = 1'b1;
	OP_R3B,OP_R3W,OP_R3T,OP_R3O:
		case(ir.r3.func)
		FN_MUL,FN_MULU,FN_MULSU,FN_MULW,FN_MULUW,FN_MULSUW,
		FN_DIV,FN_DIVU,FN_DIVSU,FN_MOD,FN_MODU,FN_MODSU:
			fnIsMC = 1'b1;
		default:
			fnIsMC = 1'b0;
		endcase
	OP_MULI,OP_MULUI:
			fnIsMC = 1'b1;
	OP_DIVI,OP_DIVUI:
		 	fnIsMC = 1'b1;
	default:	fnIsMC = 1'b0;
	endcase
end
endfunction

assign multicycle = fnIsMC(instr);

endmodule
