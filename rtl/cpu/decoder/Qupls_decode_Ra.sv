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
// ============================================================================

import cpu_types_pkg::*;
import QuplsPkg::*;

module Qupls_decode_Ra(om, ipl, instr, has_imma, Ra, Raz, Ran);
input operating_mode_t om;
input [2:0] ipl;
input ex_instruction_t instr;
input has_imma;
output aregno_t Ra;
output reg Raz;
output reg Ran;

function aregno_t fnRa;
input ex_instruction_t ir;
input has_imma;
begin
	if (has_imma)
		fnRa = 9'd0;
	else
		case(ir.ins.any.opcode)
		OP_RTD:
			fnRa = ir.aRa[2:0]<3'd1 ? 9'd0 : {6'b000101,ir.aRa[2:0]};
		OP_DBRA:
			fnRa = 9'd55;
		OP_FLT3:
			fnRa = ir.aRa;
		OP_ADDSI,OP_ANDSI,OP_ORSI,OP_EORSI:
			fnRa = ir.aRt;
		default:
			if (fnImma(ir))
				fnRa = 9'd0;
			else
				fnRa = ir.aRa;
		endcase
end
endfunction

always_comb
begin
	Ra = fnRa(instr, has_imma);
	if (Ra==8'd31 && !(instr.ins.any.opcode==OP_MOV && instr.ins[63]))
		Ra = 8'd32|om;
	Ran = instr.ins.r2.Ra.n;
	Raz = ~|Ra;
end

endmodule
