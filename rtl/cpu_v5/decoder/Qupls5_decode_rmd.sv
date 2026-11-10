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

module Qupls5_decode_rmd(instr, rmd);
input Qupls5_pkg::micro_op_t instr;
output rmd;

function fnRmd;
input Qupls5_pkg::micro_op_t ir;
begin
	case(ir.opcode)
	Qupls5_pkg::OP_FLTH,Qupls5_pkg::OP_FLTS,Qupls5_pkg::OP_FLTD,Qupls5_pkg::OP_FLTQ,
	Qupls5_pkg::OP_VFLTH,Qupls5_pkg::OP_VFLTS,Qupls5_pkg::OP_VFLTD,
	Qupls5_pkg::OP_VFLTSH,Qupls5_pkg::OP_VFLTSS,Qupls5_pkg::OP_VFLTSD:
		case(ir.func)
		// ToDo:fix trig
		Qupls5_pkg::FLT_SIN,Qupls5_pkg::FLT_COS,Qupls5_pkg::FLT_TAN,Qupls5_pkg::FLT_ATAN,
		Qupls5_pkg::FLT_STAT,Qupls5_pkg::FLT_SQRT,
//		Qupls5_pkg::FLT_CVTD2S,
		Qupls5_pkg::FLT_SIGMOID:
			fnRmd = ir.rmd;
		default:	fnRmd = ir.rmd;
		endcase
	default:	fnRmd = ir.rmd;
	endcase
end
endfunction

assign rmd = fnRmd(instr);

endmodule
