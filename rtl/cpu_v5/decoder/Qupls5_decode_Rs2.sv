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
// 50 LUTs
// ============================================================================

import cpu_types_pkg::*;
import Qupls5_pkg::*;

module Qupls5_decode_Rs2(om, instr, instr_raw, has_immb, Rs2, Rs2z, has_Rs2);
input Qupls5_pkg::operating_mode_t om;
input Qupls5_pkg::micro_op_t instr;
input [335:0] instr_raw;
input has_immb;
output aregno_t Rs2;
output reg Rs2z;
output reg has_Rs2;

function aregno_t fnHas_Rs2;
input Qupls5_pkg::micro_op_t instr;
input has_immb;
Qupls5_pkg::micro_op_t ir;
begin
	ir = instr;
	fnHas_Rs2 = 1'b0;
	if (has_immb)
		fnHas_Rs2 = 1'b0;
	else
		fnHas_Rs2 = ir.src[1];
end
endfunction

function aregno_t fnRs2;
input Qupls5_pkg::micro_op_t instr;
input [335:0] instr_raw;
input has_immb;
Qupls5_pkg::micro_op_t ir;
begin
	ir = instr;
	if (has_immb)
		fnRs2 = 8'd0;
	else
		fnRs2 = ir.Rs2;
end
endfunction

always_comb
begin
	has_Rs2 = fnHas_Rs2(instr, has_immb);
	Rs2 = fnRs2(instr, instr_raw, has_immb);
	Rs2z = ~|Rs2[4:0];
end

endmodule
