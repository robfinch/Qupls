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
//  LUTs
// ============================================================================

import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_decode_Rs4(om, instr, instr_raw, has_immd, Rs4, Rs4z);
input Qupls4_pkg::operating_mode_t om;
input Qupls4_pkg::micro_op_t instr;
input [431:0] instr_raw;
input has_immd;
output aregno_t Rs4;
output reg Rs4z;

function aregno_t fnRs4;
input Qupls4_pkg::micro_op_t instr;
input [335:0] instr_raw;
input has_immd;
Qupls4_pkg::micro_op_t ir;
reg has_rext;
begin
	ir = instr;
	has_rext = instr_raw[54:48]==OP_REXT;
	if (has_immd)
		fnRs4 = 7'd0;
	else
		case(ir.opcode)
		Qupls4_pkg::OP_GRAPHICS:
			case(ir.func)
			Qupls4_pkg::GR_TEX0,Qupls4_pkg::GR_TEX1,
			Qupls4_pkg::GR_PACK64160,Qupls4_pkg::GR_PACK64161:
				fnRs4 = {2'b00,ir.Rs4};
			default:
				fnRs4 = 7'd0;
			endcase
		Qupls4_pkg::OP_PUSH,Qupls4_pkg::OP_POP,Qupls4_pkg::OP_MBCC:
			fnRs4 = has_rext ? instr_raw[48+41:48+35] : {2'b00,ir.Rs4};
		default:
			fnRs4 = 7'd0;
		endcase
end
endfunction

always_comb
begin
	Rs4 = fnRs4(instr, instr_raw, has_immd);
	Rs4z = ~|Rs4[6:0];
end

endmodule
