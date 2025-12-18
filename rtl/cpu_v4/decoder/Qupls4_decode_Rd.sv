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
// 25 LUTs
// ============================================================================

import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_decode_Rd(om, instr, instr_raw, Rd, Rdz, exc);
input Qupls4_pkg::operating_mode_t om;
input Qupls4_pkg::micro_op_t instr;
input [335:0] instr_raw;
output aregno_t Rd;
output reg Rdz;
output reg exc;

function aregno_t fnRd;
input Qupls4_pkg::micro_op_t instr;
input [335:0] instr_raw;
Qupls4_pkg::micro_op_t ir;
begin
	ir = instr;
	case(ir.opcode)
/*
	Qupls4_pkg::OP_MOV:
		if (ir[28:26] < 3'd4)
			fnRd = {ir[18:17],ir[10:6]};
		else
			fnRd = {2'b00,ir[10:6]};
*/			
	Qupls4_pkg::OP_FLTH,Qupls4_pkg::OP_FLTS,Qupls4_pkg::OP_FLTD,Qupls4_pkg::OP_FLTQ:
		fnRd = ir.Rd;
	Qupls4_pkg::OP_CSR:
		fnRd = ir.Rd;
	Qupls4_pkg::OP_ADDI,Qupls4_pkg::OP_SUBFI,Qupls4_pkg::OP_CMPI,Qupls4_pkg::OP_CMPUI,
	Qupls4_pkg::OP_ANDI,Qupls4_pkg::OP_ORI,Qupls4_pkg::OP_XORI,
	Qupls4_pkg::OP_MULI,Qupls4_pkg::OP_MULUI,Qupls4_pkg::OP_DIVI,Qupls4_pkg::OP_DIVUI,
	Qupls4_pkg::OP_SHIFT:
		fnRd = ir.Rd;
	Qupls4_pkg::OP_BSR,Qupls4_pkg::OP_JSR:
		fnRd = ir.Rd;
	Qupls4_pkg::OP_LDB,Qupls4_pkg::OP_LDBZ,Qupls4_pkg::OP_LDW,Qupls4_pkg::OP_LDWZ,
	Qupls4_pkg::OP_LDT,Qupls4_pkg::OP_LDTZ,Qupls4_pkg::OP_LOAD,Qupls4_pkg::OP_LOADA,
	Qupls4_pkg::OP_LDV,
	Qupls4_pkg::OP_AMO,Qupls4_pkg::OP_CMPSWAP:
		fnRd = ir.Rd;
	default:
		fnRd = 7'd0;
	endcase
end
endfunction

always_comb
begin
	Rd = fnRd(instr, instr_raw);
	Rdz = ~|Rd;
//	tRegmap(om1, Rd, Rd, exc);
end

endmodule
