// ============================================================================
//        __
//   \\__/ o\    (C) 2026  Robert Finch, Waterloo
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
// 15 LUTs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls5_pkg::*;

module Qupls5_decode_Rmd(instr, Rmd, Rmd_used);
input Qupls5_pkg::micro_op_t instr;
output aregno_t Rmd;
output reg Rmd_used;

function aregno_t fnRmd_used;
input Qupls5_pkg::micro_op_t instr;
Qupls5_pkg::micro_op_t ir;
reg has_rext;
begin
	ir = instr;
	case(ir.opcode)
	Qupls5_pkg::OP_FLTH,Qupls5_pkg::OP_FLTS,Qupls5_pkg::OP_FLTD,Qupls5_pkg::OP_FLTQ,
	Qupls5_pkg::OP_FLTPH,Qupls5_pkg::OP_FLTPS,Qupls5_pkg::OP_FLTPD,Qupls5_pkg::OP_FLTPQ,
	Qupls5_pkg::OP_VFLTH,Qupls5_pkg::OP_VFLTS,Qupls5_pkg::OP_VFLTD,
	Qupls5_pkg::OP_VSFLTH,Qupls5_pkg::OP_VSFLTS,Qupls5_pkg::OP_VSFLTD:
		case(ir.func)
		Qupls5_pkg::FLT_FMA,Qupls5_pkg::FLT_FNMA,Qupls5_pkg::FLT_FMS,Qupls5_pkg::FLT_FNMS,
		Qupls5_pkg::FLT_ADD,Qupls5_pkg::FLT_SUB,
//		Qupls5_pkg::FLT_CVTQ2D,Qupls5_pkg::FLT_CVTQ2H,Qupls5_pkg::FLT_CVTQ2S,
		Qupls5_pkg::FLT_DIV,Qupls5_pkg::FLT_MUL,Qupls5_pkg::FLT_POLY,Qupls5_pkg::FLT_REDADD,
		Qupls5_pkg::FLT_SQRT,Qupls5_pkg::FLT_TRUNC:	
			fnRmd_used = TRUE;
		endcase
	// ToDo: ASR round mode
	default:
		fnRmd_used = FALSE;
	endcase
end
endfunction

always_comb
begin
	Rmd = 8'b11111111;
	Rmd_used = fnRmd_used(instr);
end

endmodule
