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

import cpu_types_pkg::*;
import Qupls5_pkg::*;

module Qupls5_decode_Rs1(om, instr, instr_raw, has_imma, Rs1, Rs1z, Rs1ip);
input Qupls5_pkg::operating_mode_t om;
input Qupls5_pkg::micro_op_t instr;
input [335:0] instr_raw;
input has_imma;
output aregno_t Rs1;
output reg Rs1z;
output reg Rs1ip;

Qupls5_pkg::operating_mode_t om1;

function aregno_t fnRs1;
input Qupls5_pkg::micro_op_t ins;
input [335:0] instr_raw;
input has_imma;
Qupls5_pkg::micro_op_t ir;
reg has_rext;
begin
	ir = ins;
	has_rext = FALSE;
	if (has_imma)
		fnRs1 = 8'd0;
	// Will have been set by fnMapRawToUop()
	else
		fnRs1 = ir.Rs1;
end
endfunction

always_comb
begin
	Rs1 = fnRs1(instr, instr_raw, has_imma);
	/*
	if (instr.ins.opcode==Qupls5_pkg::OP_MOV && instr.ins[28:26]==3'd1)	// MOVEMD?
		om1 = Qupls5_pkg::operating_mode_t'(instr.ins[24:23]);
    else
        om1 = om;
  */
	Rs1z = ~|Rs1[4:0];
	Rs1ip = Rs1==Qupls5_pkg::IP_REG;
end

endmodule
