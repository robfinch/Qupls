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
// 15 LUTs
// ============================================================================

import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_decode_Rs3(om, instr, instr_raw, has_immc, Rs3, Rs3z);
input Qupls4_pkg::operating_mode_t om;
input Qupls4_pkg::micro_op_t instr;
input [431:0] instr_raw;
input has_immc;
output aregno_t Rs3;
output reg Rs3z;

function aregno_t fnRs3;
input Qupls4_pkg::micro_op_t instr;
input [335:0] instr_raw;
input has_immc;
Qupls4_pkg::micro_op_t ir;
reg has_rext;
begin
	ir = instr;
	has_rext = instr_raw[54:48]==OP_REXT;
	if (has_immc)
		fnRs3 = 7'd0;
	else
		case(ir.opcode)
		Qupls4_pkg::OP_STB,Qupls4_pkg::OP_STW,
		Qupls4_pkg::OP_STT,Qupls4_pkg::OP_STORE,Qupls4_pkg::OP_STI,
		Qupls4_pkg::OP_STPTR:
			fnRs3 = has_rext ? instr_raw[48+34:48+28] : {2'b00,ir.Rd};
		Qupls4_pkg::OP_R3B,Qupls4_pkg::OP_R3W,Qupls4_pkg::OP_R3T,Qupls4_pkg::OP_R3O:
			fnRs3 = has_rext ? instr_raw[48+34:48+28] : {2'b00,ir.Rs3};
		default:
			fnRs3 = 7'd0;
		endcase
end
endfunction

always_comb
begin
	Rs3 = fnRs3(instr, instr_raw, has_immc);
	Rs3z = ~|Rs3;
end

endmodule
