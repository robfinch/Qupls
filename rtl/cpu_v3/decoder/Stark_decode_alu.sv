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

module Stark_decode_alu(instr, alu);
input Stark_pkg::instruction_t instr;
output alu;

function fnIsAlu;
input Stark_pkg::instruction_t ir;
begin
	case(ir.any.opcode)
	Stark_pkg::OP_FLT:
		case(ir.fpu.op4)
		Stark_pkg::FOP4_ADD:
			if (ir[31:29]==3'b001 && ir.fpu.Rs2==5'd1)	// FABS
				fnIsAlu = 1'b1;
			else
				fnIsAlu = 1'b0;
		Stark_pkg::FOP4_G8:	fnIsAlu = 1'b1;
		default:	fnIsAlu = 1'b0;
		endcase
	Stark_pkg::OP_CHK:	fnIsAlu = 1'b1;
	Stark_pkg::OP_ADD:		fnIsAlu = 1'b1;
	Stark_pkg::OP_SUBF:	fnIsAlu = 1'b1;
	Stark_pkg::OP_CMP:		fnIsAlu = 1'b1;
	Stark_pkg::OP_MUL:		fnIsAlu = 1'b1;
	Stark_pkg::OP_DIV:		fnIsAlu = 1'b1;
	Stark_pkg::OP_AND:		fnIsAlu = 1'b1;
	Stark_pkg::OP_OR:		fnIsAlu = 1'b1;
	Stark_pkg::OP_XOR:		fnIsAlu = 1'b1;
	Stark_pkg::OP_ADB:		fnIsAlu = 1'b1;
	Stark_pkg::OP_SHIFT:	fnIsAlu = 1'b1;
	Stark_pkg::OP_CSR:		fnIsAlu = 1'b1;
	Stark_pkg::OP_MOV:		fnIsAlu = 1'b1;
	Stark_pkg::OP_LOADA:	fnIsAlu = 1'b1;
	Stark_pkg::OP_PFX,
	Stark_pkg::OP_NOP,Stark_pkg::OP_PUSH,Stark_pkg::OP_POP:
		fnIsAlu = 1'b1;
	Stark_pkg::OP_FENCE:
		fnIsAlu = 1'b1;
	default:
		if (Stark_pkg::fnIsDBcc(ir))
			fnIsAlu = 1'b1;
		else
			fnIsAlu = 1'b0;
	endcase
end
endfunction

assign alu = fnIsAlu(instr);

endmodule
