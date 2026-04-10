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

import Qupls4_pkg::*;

module Qupls4_decode_class(instr, fclass);
input Qupls4_pkg::micro_op_t instr;
output [2:0] fclass;

function [2:0] fnClass;
input Qupls4_pkg::micro_op_t ir;
begin
	case(ir.opcode)
	Qupls4_pkg::OP_LDB,Qupls4_pkg::OP_LDBZ,Qupls4_pkg::OP_LDW,Qupls4_pkg::OP_LDWZ,
	Qupls4_pkg::OP_LDT,Qupls4_pkg::OP_LDTZ,Qupls4_pkg::OP_LOAD,
	Qupls4_pkg::OP_STB,Qupls4_pkg::OP_STW,
	Qupls4_pkg::OP_STT,Qupls4_pkg::OP_STORE,
	Qupls4_pkg::OP_STI,
	Qupls4_pkg::OP_STPTR,
	Qupls4_pkg::OP_V2P,
	Qupls4_pkg::OP_VV2P,
	Qupls4_pkg::OP_AMO:
		fnClass = 3'd0;
	Qupls4_pkg::OP_BFLD:
		fnClass = 3'd1;
	Qupls4_pkg::OP_R3B,Qupls4_pkg::OP_R3W,Qupls4_pkg::OP_R3T,Qupls4_pkg::OP_R3O,
	Qupls4_pkg::OP_R3BP,Qupls4_pkg::OP_R3WP,Qupls4_pkg::OP_R3TP,Qupls4_pkg::OP_R3OP,
	Qupls4_pkg::OP_R3VVV,Qupls4_pkg::OP_R3VVS:
		fnClass = 3'd1;
	Qupls4_pkg::OP_FLTH,Qupls4_pkg::OP_FLTS,Qupls4_pkg::OP_FLTD,Qupls4_pkg::OP_FLTQ,
	Qupls4_pkg::OP_FLTPH,Qupls4_pkg::OP_FLTPS,Qupls4_pkg::OP_FLTPD,Qupls4_pkg::OP_FLTPQ,
	Qupls4_pkg::OP_FLTVVV,Qupls4_pkg::OP_FLTVVS:
		fnClass = 3'd2;
	Qupls4_pkg::OP_CHK:	fnClass = 3'd1;
	Qupls4_pkg::OP_ADDI:		fnClass = 3'd1;
	Qupls4_pkg::OP_SUBFI:	fnClass = 3'd1;
	Qupls4_pkg::OP_CMPI:		fnClass = 3'd1;
	Qupls4_pkg::OP_CMPUI:		fnClass = 3'd1;
	Qupls4_pkg::OP_ANDI:		fnClass = 3'd1;
	Qupls4_pkg::OP_ORI:		fnClass = 3'd1;
	Qupls4_pkg::OP_XORI:		fnClass = 3'd1;
	Qupls4_pkg::OP_SHIFT:	fnClass = 3'd1;
	Qupls4_pkg::OP_CSR:		fnClass = 3'd1;
	Qupls4_pkg::OP_LOADI:		fnClass = 3'd1;
	Qupls4_pkg::OP_MOVMR:		fnClass = 3'd1;
	Qupls4_pkg::OP_LOADA:	fnClass = 3'd1;
	Qupls4_pkg::OP_FENCE:
		fnClass = 3'd1;
	Qupls4_pkg::OP_BCC,Qupls4_pkg::OP_BCCU,Qupls4_pkg::OP_FBCC,
	Qupls4_pkg::OP_BSR,Qupls4_pkg::OP_JSR,Qupls4_pkg::OP_JSRN,
	Qupls4_pkg::OP_SYS,
	Qupls4_pkg::OP_BRK,
	Qupls4_pkg::OP_RTD:
		fnClass = 3'd3;
	default:
		fnClass = 3'd7;
	endcase
end
endfunction

assign fclass = fnClass(instr);

endmodule
