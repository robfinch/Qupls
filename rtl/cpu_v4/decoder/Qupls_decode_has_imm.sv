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
// Detect if the instruction has a 27-bit immediate eg. ADDI 
// ============================================================================

import Qupls4_pkg::*;

module Qupls4_decode_has_imm(instr, has_imm);
input Qupls4_pkg::micro_op_t instr;
output has_imm;

function fnHasImm;
input Qupls4_pkg::micro_op_t op;
begin
	case(op.any.opcode)
	Qupls4_pkg::OP_ADDI,Qupls4_pkg::OP_SUBFI,Qupls4_pkg::OP_CMPI,Qupls4_pkg::OP_CMPUI,
	Qupls4_pkg::OP_MULI,Qupls4_pkg::OP_MULUI,Qupls4_pkg::OP_DIVI,Qupls4_pkg::OP_DIVUI,
	Qupls4_pkg::OP_ADDIPI,
	Qupls4_pkg::OP_ANDI,Qupls4_pkg::OP_ORI,Qupls4_pkg::OP_XORI:
		fnHasImm = 1'b1;
	default:	fnHasImm = 1'b0;
	endcase
end
endfunction

assign has_imm = fnHasImm(instr);

endmodule
