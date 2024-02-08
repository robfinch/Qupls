// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2024  Robert Finch, Waterloo
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

import QuplsPkg::*;

module Qupls_decode_Rc(om, ipl, instr, has_immc, Rc, Rcz, Rcc);
input operating_mode_t om;
input [2:0] ipl;
input ex_instruction_t [5:0] instr;
input has_immc;
output aregno_t Rc;
output reg Rcz;
output reg [2:0] Rcc;

always_comb
begin
	Rc = 9'd0;
	Rcc = 3'd0;
	if (has_immc) begin
		Rc = 9'd0;
		Rcc = 3'd0;
	end
	else
		case(instr[0].ins.any.opcode)
		OP_STB,OP_STW,OP_STT,OP_STO,OP_STH,OP_STX:
			Rc = instr[0].aRt;
		OP_SHIFT,OP_VSHIFT:
			Rc = instr[0].aRc;
		OP_R2:
			Rc = instr[0].aRc;
		OP_STX:
			case(instr[0].ins.lsn.func)
			FN_STCTX:
				Rc = {1'b0,instr[0].aRa[2:0],instr[0].aRc[4:0]};
			default:
				Rc = instr[0].aRc;
			endcase
		default:
			if (fnImmc(instr[0]))
				Rc = 9'd0;
			else
				Rc = instr[0].aRc;
		endcase
	if (Rc==9'd31)
		Rc = 9'd32|om;
	Rcz = ~|Rc;
end

endmodule

