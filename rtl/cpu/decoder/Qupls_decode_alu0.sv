// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2023  Robert Finch, Waterloo
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

// Instructions specific to ALU #0

module Qupls_decode_alu0(instr, alu0);
input instruction_t instr;
output alu0;

function fnIsAlu0;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_CAP:	fnIsAlu0 = 1'b1;
	OP_R2,OP_R3V,OP_R3VS:
		case(ir.r2.func)
		FN_CPUID,
		FN_BYTENDX,
		FN_MUL,FN_MULU,FN_MULSU,FN_MULW,FN_MULUW,FN_MULSUW,
		FN_DIV,FN_DIVU,FN_DIVSU,FN_MOD,FN_MODU,FN_MODSU,
		FN_VSETMASK:
			fnIsAlu0 = 1'b1;
		default:
			fnIsAlu0 = 1'b0;
		endcase
	OP_CSR:	fnIsAlu0 = 1'b1;
	OP_BSR,OP_JSR:	fnIsAlu0 = 1'b1;
	OP_MULI,OP_MULUI,
	OP_DIVI,OP_DIVUI: 	fnIsAlu0 = 1'b1;
	OP_PRED:	fnIsAlu0 = 1'b1;
	default:	fnIsAlu0 = 1'b0;
	endcase
end
endfunction

assign alu0 = fnIsAlu0(instr);

endmodule
