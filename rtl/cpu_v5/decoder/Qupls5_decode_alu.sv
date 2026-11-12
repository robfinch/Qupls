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

module Qupls5_decode_alu(instr, alu);
input Qupls5_pkg::micro_op_t instr;
output alu;

function fnIsAlu;
input Qupls5_pkg::micro_op_t ir;
begin
	fnIsAlu = 1'b0;
	case(ir.opcode)
	Qupls5_pkg::OP_BFLD:
		fnIsAlu = 1'b1;
	Qupls5_pkg::OP_R3B,Qupls5_pkg::OP_R3W,Qupls5_pkg::OP_R3T,Qupls5_pkg::OP_R3O,
	Qupls5_pkg::OP_VR3B,Qupls5_pkg::OP_VR3W,Qupls5_pkg::OP_VR3T,Qupls5_pkg::OP_VR3O,
	Qupls5_pkg::OP_VSR3B,Qupls5_pkg::OP_VSR3W,Qupls5_pkg::OP_VSR3T,Qupls5_pkg::OP_VSR3O:
		fnIsAlu = 1'b1;
	Qupls5_pkg::OP_FLTH,Qupls5_pkg::OP_FLTS,Qupls5_pkg::OP_FLTD,Qupls5_pkg::OP_FLTQ,
	Qupls5_pkg::OP_VFLTH,Qupls5_pkg::OP_VFLTS,Qupls5_pkg::OP_VFLTD,
	Qupls5_pkg::OP_VSFLTH,Qupls5_pkg::OP_VSFLTS,Qupls5_pkg::OP_VSFLTD:
		case(ir.func)
		Qupls5_pkg::FLT_CMP,
		Qupls5_pkg::FLT_ABS,Qupls5_pkg::FLT_NEG:
			fnIsAlu = 1'b1;
		default:	fnIsAlu = 1'b0;
		endcase
	Qupls5_pkg::OP_CHK:	fnIsAlu = 1'b1;
	Qupls5_pkg::OP_ADDI:		fnIsAlu = 1'b1;
	Qupls5_pkg::OP_SUBFI:	fnIsAlu = 1'b1;
	Qupls5_pkg::OP_CMPI:		fnIsAlu = 1'b1;
	Qupls5_pkg::OP_CMPUI:		fnIsAlu = 1'b1;
	Qupls5_pkg::OP_ANDI:		fnIsAlu = 1'b1;
	Qupls5_pkg::OP_ORI:		fnIsAlu = 1'b1;
	Qupls5_pkg::OP_XORI:		fnIsAlu = 1'b1;
	Qupls5_pkg::OP_SHIFT:	fnIsAlu = 1'b1;
	Qupls5_pkg::OP_CSR:		fnIsAlu = 1'b1;
	Qupls5_pkg::OP_LOADA:	fnIsAlu = 1'b1;
	Qupls5_pkg::OP_FENCE:
		fnIsAlu = 1'b1;
	default:
		fnIsAlu = 1'b0;
	endcase
end
endfunction

assign alu = fnIsAlu(instr);

endmodule
