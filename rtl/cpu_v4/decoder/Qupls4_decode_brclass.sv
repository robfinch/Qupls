// ============================================================================
//        __
//   \\__/ o\    (C) 2025  Robert Finch, Waterloo
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

module Qupls4_decode_brclass(instr, brclass);
input Qupls4_pkg::micro_op_t instr;
output Qupls4_pkg::brclass_t brclass;

always_comb
	case(instr.any.opcode)
	Qupls4_pkg::OP_BCC8,Qupls4_pkg::OP_BCC16,Qupls4_pkg::OP_BCC32,Qupls4_pkg::OP_BCC64,
	Qupls4_pkg::OP_BCCU8,Qupls4_pkg::OP_BCCU16,Qupls4_pkg::OP_BCCU32,Qupls4_pkg::OP_BCCU64:
		begin
			if (instr.br.md)
				brclass = Qupls4_pkg::BRC_BCCR;
			else
				brclass = Qupls4_pkg::BRC_BCCD;
		end
	Qupls4_pkg::OP_JSR:
		brclass = Qupls4_pkg::BRC_JSR;
	Qupls4_pkg::OP_JSRN:
		brclass = Qupls4_pkg::BRC_JSRN;
	Qupls4_pkg::OP_RTD:
		brclass = Qupls4_pkg::BRC_RTD;
	Qupls4_pkg::OP_BRK:
		if (instr[28:18]==11'd1)
			brclass = Qupls4_pkg::BRC_ERET;
		else
			brclass = Qupls4_pkg::BRC_NONE;
	default:
		brclass = Qupls4_pkg::BRC_NONE;
	endcase
		
endmodule
