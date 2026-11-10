// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2026  Robert Finch, Waterloo
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

import Qupls5_pkg::*;

module Qupls5_decode_fpu(instr, fpu);
input Qupls5_pkg::micro_op_t instr;
output fpu;

function fnIsFpu;
input Qupls5_pkg::micro_op_t ir;
begin
	case(ir.opcode)
	Qupls5_pkg::OP_R3B,Qupls5_pkg::OP_R3W,Qupls5_pkg::OP_R3T,Qupls5_pkg::OP_R3O,
	Qupls5_pkg::OP_VR3B,Qupls5_pkg::OP_VR3W,Qupls5_pkg::OP_VR3T,Qupls5_pkg::OP_VR3O,
	Qupls5_pkg::OP_VSR3B,Qupls5_pkg::OP_VSR3W,Qupls5_pkg::OP_VSR3T,Qupls5_pkg::OP_VSR3O:
		case(ir.func)
		Qupls5_pkg::FN_MUL: 	fnIsFpu = 1'b1;
		Qupls5_pkg::FN_MULU:	fnIsFpu = 1'b1;
		default:	fnIsFpu = 1'b0;
		endcase
	Qupls5_pkg::OP_MULI:	fnIsFpu = 1'b1;
	Qupls5_pkg::OP_MULUI:	fnIsFpu = 1'b1;
	Qupls5_pkg::OP_FLTH,Qupls5_pkg::OP_FLTS,Qupls5_pkg::OP_FLTD,Qupls5_pkg::OP_FLTQ,
	Qupls5_pkg::OP_VFLTH,Qupls5_pkg::OP_VFLTS,Qupls5_pkg::OP_VFLTD,
	Qupls5_pkg::OP_VFLTSH,Qupls5_pkg::OP_VFLTSS,Qupls5_pkg::OP_VFLTSD:
		fnIsFpu = 1'b1;
	Qupls5_pkg::OP_ADDI:	fnIsFpu = Qupls5_pkg::PERFORMANCE;
	Qupls5_pkg::OP_CMPI:	fnIsFpu = Qupls5_pkg::PERFORMANCE;
	Qupls5_pkg::OP_ANDI:	fnIsFpu = Qupls5_pkg::PERFORMANCE;
	Qupls5_pkg::OP_ORI:	fnIsFpu = Qupls5_pkg::PERFORMANCE;
	Qupls5_pkg::OP_XORI:	fnIsFpu = Qupls5_pkg::PERFORMANCE;
	Qupls5_pkg::OP_FADDI:	fnIsFpu = 1'b1;
//	Qupls5_pkg::OP_MOV:	fnIsFpu = Qupls5_pkg::PERFORMANCE;
	Qupls5_pkg::OP_NOP:	fnIsFpu = 1'b1;
	default:	fnIsFpu = 1'b0;
	endcase
end
endfunction

assign fpu = fnIsFpu(instr);

endmodule
