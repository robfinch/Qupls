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

import Stark_pkg::*;

module Stark_decode_sau(instr, sau);
input Stark_pkg::instruction_t instr;
output sau;

function fnIsSau;
input Stark_pkg::instruction_t ir;
begin
	case(ir.any.opcode)
	Stark_pkg::OP_FLT:
		case(ir.fpu.op4)
		Stark_pkg::FOP4_FADD:
			if (ir[31:29]==3'b001 && ir.fpu.Rs2==5'd1)	// FABS
				fnIsSau = 1'b1;
			else
				fnIsSau = 1'b0;
		Stark_pkg::FOP4_G8:	fnIsSau = 1'b1;
		default:	fnIsSau = 1'b0;
		endcase
	Stark_pkg::OP_CHK:	fnIsSau = 1'b1;
	Stark_pkg::OP_ADD:		fnIsSau = 1'b1;
	Stark_pkg::OP_SUBF:	fnIsSau = 1'b1;
	Stark_pkg::OP_CMP:		fnIsSau = 1'b1;
	Stark_pkg::OP_AND:		fnIsSau = 1'b1;
	Stark_pkg::OP_OR:		fnIsSau = 1'b1;
	Stark_pkg::OP_XOR:		fnIsSau = 1'b1;
	Stark_pkg::OP_ADB:		fnIsSau = 1'b1;
	Stark_pkg::OP_SHIFT:	fnIsSau = 1'b1;
	Stark_pkg::OP_CSR:		fnIsSau = 1'b1;
	Stark_pkg::OP_MOV:		fnIsSau = 1'b1;
	Stark_pkg::OP_LOADA:	fnIsSau = 1'b1;
	Stark_pkg::OP_NOP,Stark_pkg::OP_PUSH,Stark_pkg::OP_POP:
		fnIsSau = 1'b1;
	Stark_pkg::OP_FENCE:
		fnIsSau = 1'b1;
	default:
		fnIsSau = 1'b0;
	endcase
end
endfunction

assign sau = fnIsSau(instr);

endmodule
