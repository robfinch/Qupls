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
// 25 LUTs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_decode_Rd2(om, regFPCSR, instr, instr_raw, Rd2, Rd2v, Rd2z);
input Qupls4_pkg::operating_mode_t om;
input aregno_t regFPCSR;
input Qupls4_pkg::micro_op_t instr;
input [431:0] instr_raw;
output aregno_t Rd2;
output reg Rd2v;
output reg Rd2z;

function aregno_t fnRd2;
input Qupls4_pkg::micro_op_t instr;
input [431:0] instr_raw;
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
	Qupls4_pkg::OP_FLTH,Qupls4_pkg::OP_FLTS,Qupls4_pkg::OP_FLTD,Qupls4_pkg::OP_FLTQ,
	Qupls4_pkg::OP_FLTVVV,Qupls4_pkg::OP_FLTVVS:
		fnRd2 = ir[47] ? regFPCSR : 7'd0;
	default:
		fnRd2 = 7'd0;
	endcase
end
endfunction

// ToDo: Fix these
function aregno_t fnRd2v;
input Qupls4_pkg::micro_op_t instr;
input [431:0] instr_raw;
Qupls4_pkg::micro_op_t ir;
begin
	fnRd2v = INV;
	ir = instr;
	case(ir.opcode)
/*
	Qupls4_pkg::OP_MOV:
		if (ir[28:26] < 3'd4)
			fnRd = {ir[18:17],ir[10:6]};
		else
			fnRd = {2'b00,ir[10:6]};
*/			
	Qupls4_pkg::OP_FLTH,Qupls4_pkg::OP_FLTS,Qupls4_pkg::OP_FLTD,Qupls4_pkg::OP_FLTQ,
	Qupls4_pkg::OP_FLTVVV,Qupls4_pkg::OP_FLTVVS:
		fnRd2v = VAL;
	default:
		fnRd2v = INV;
	endcase
end
endfunction

always_comb
begin
	Rd2 = fnRd2(instr, instr_raw);
	Rd2v = fnRd2v(instr, instr_raw);
	Rd2z = ~|Rd2[6:0];
end

endmodule
