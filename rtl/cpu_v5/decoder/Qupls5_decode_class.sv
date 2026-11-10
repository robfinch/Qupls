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

module Qupls5_decode_class(instr, fclass);
input Qupls5_pkg::micro_op_t instr;
output [2:0] fclass;

function [2:0] fnClass;
input Qupls5_pkg::micro_op_t ir;
begin
	case(ir.opcode)
	Qupls5_pkg::OP_LDB,Qupls5_pkg::OP_LDBZ,Qupls5_pkg::OP_LDW,Qupls5_pkg::OP_LDWZ,
	Qupls5_pkg::OP_LDT,Qupls5_pkg::OP_LDTZ,Qupls5_pkg::OP_LOAD,
	Qupls5_pkg::OP_STB,Qupls5_pkg::OP_STW,
	Qupls5_pkg::OP_STT,Qupls5_pkg::OP_STORE,
	Qupls5_pkg::OP_STPTR,
	Qupls5_pkg::OP_V2P,
	Qupls5_pkg::OP_VV2P,
	Qupls5_pkg::OP_AMO:
		fnClass = 3'd0;
	Qupls5_pkg::OP_BFLD:
		fnClass = 3'd1;
	Qupls5_pkg::OP_R3B,Qupls5_pkg::OP_R3W,Qupls5_pkg::OP_R3T,Qupls5_pkg::OP_R3O,
	Qupls5_pkg::OP_VR3B,Qupls5_pkg::OP_VR3W,Qupls5_pkg::OP_VR3T,Qupls5_pkg::OP_VR3O,
	Qupls5_pkg::OP_VSR3B,Qupls5_pkg::OP_VSR3W,Qupls5_pkg::OP_VSR3T,Qupls5_pkg::OP_VSR3O:
		fnClass = 3'd1;
	Qupls5_pkg::OP_FLTH,Qupls5_pkg::OP_FLTS,Qupls5_pkg::OP_FLTD,Qupls5_pkg::OP_FLTQ,
	Qupls5_pkg::OP_FLTPH,Qupls5_pkg::OP_FLTPS,Qupls5_pkg::OP_FLTPD,Qupls5_pkg::OP_FLTPQ,
	Qupls5_pkg::OP_FLTVVV,Qupls5_pkg::OP_FLTVVS:
		fnClass = 3'd2;
	Qupls5_pkg::OP_FADDI:		fnClass = 3'd2;
	Qupls5_pkg::OP_FMULI:		fnClass = 3'd2;
	Qupls5_pkg::OP_CHK:	fnClass = 3'd1;
	Qupls5_pkg::OP_ADDI:		fnClass = 3'd1;
	Qupls5_pkg::OP_SUBFI:	fnClass = 3'd1;
	Qupls5_pkg::OP_CMPI:		fnClass = 3'd1;
	Qupls5_pkg::OP_CMPUI:		fnClass = 3'd1;
	Qupls5_pkg::OP_ANDI:		fnClass = 3'd1;
	Qupls5_pkg::OP_ORI:		fnClass = 3'd1;
	Qupls5_pkg::OP_XORI:		fnClass = 3'd1;
	Qupls5_pkg::OP_SHIFT:	fnClass = 3'd1;
	Qupls5_pkg::OP_CSR:		fnClass = 3'd1;
	Qupls5_pkg::OP_LOADA:	fnClass = 3'd1;
	Qupls5_pkg::OP_FENCE:
		fnClass = 3'd1;
	Qupls5_pkg::OP_BCC,Qupls5_pkg::OP_BCCU,Qupls5_pkg::OP_FBCC,
	Qupls5_pkg::OP_BSR,Qupls5_pkg::OP_JSR,Qupls5_pkg::OP_JSRN,
	Qupls5_pkg::OP_SYS,
	Qupls5_pkg::OP_BRK,
	Qupls5_pkg::OP_RTD:
		fnClass = 3'd3;
	default:
		fnClass = 3'd7;
	endcase
end
endfunction

assign fclass = fnClass(instr);

endmodule
