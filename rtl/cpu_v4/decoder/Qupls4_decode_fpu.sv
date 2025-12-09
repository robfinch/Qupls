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

import Qupls4_pkg::*;

module Qupls4_decode_fpu(instr, fpu);
input Qupls4_pkg::micro_op_t instr;
output fpu;

function fnIsFpu;
input Qupls4_pkg::micro_op_t ir;
begin
	case(ir.any.opcode)
	Qupls4_pkg::OP_FLTH,Qupls4_pkg::OP_FLTS,Qupls4_pkg::OP_FLTD,Qupls4_pkg::OP_FLTQ,
	Qupls4_pkg::OP_FLTPH,Qupls4_pkg::OP_FLTPS,Qupls4_pkg::OP_FLTPD,Qupls4_pkg::OP_FLTPQ,
	Qupls4_pkg::OP_FLTP:
		fnIsFpu = 1'b1;
	Qupls4_pkg::OP_ADDI:	fnIsFpu = Qupls4_pkg::PERFORMANCE;
	Qupls4_pkg::OP_CMPI:	fnIsFpu = Qupls4_pkg::PERFORMANCE;
	Qupls4_pkg::OP_ANDI:	fnIsFpu = Qupls4_pkg::PERFORMANCE;
	Qupls4_pkg::OP_ORI:	fnIsFpu = Qupls4_pkg::PERFORMANCE;
	Qupls4_pkg::OP_XORI:	fnIsFpu = Qupls4_pkg::PERFORMANCE;
//	Qupls4_pkg::OP_MOV:	fnIsFpu = Qupls4_pkg::PERFORMANCE;
	Qupls4_pkg::OP_NOP:	fnIsFpu = 1'b1;
	default:	fnIsFpu = 1'b0;
	endcase
end
endfunction

assign fpu = fnIsFpu(instr);

endmodule
