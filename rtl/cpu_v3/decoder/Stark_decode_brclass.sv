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

import Stark_pkg::*;

module Stark_decode_brclass(instr, brclass);
input Stark_pkg::instruction_t instr;
output Stark_pkg::brclass_t brclass;

always_comb
	case(instr.any.opcode)
	Stark_pkg::OP_B0,Stark_pkg::OP_B1:
		begin
			if (instr[31])
				brclass = Stark_pkg::BRC_BL;
			else if (instr[30:29]==2'b00)
				brclass = Stark_pkg::BRC_BLRLR;
			else
				brclass = Stark_pkg::BRC_BLRLC;
		end
	Stark_pkg::OP_BCC0,Stark_pkg::OP_BCC1:
		begin
			if (instr[31])
				brclass = Stark_pkg::BRC_BCCD;
			else if (instr[8:6]==3'b00) begin	// RETcc
				if (instr[30:29]==2'b00)
					brclass = Stark_pkg::BRC_BCCR;
				else if (instr[30:29]==2'b01)
					brclass = Stark_pkg::BRC_BCCC;
				else
					brclass = Stark_pkg::BRC_NONE;
			end
			else begin
				if (instr[30:29]==2'b00)
					brclass = Stark_pkg::BRC_RETR;
				else if (instr[30:29]==2'b01)
					brclass = Stark_pkg::BRC_RETC;
				else
					brclass = Stark_pkg::BRC_NONE;
			end
		end
	Stark_pkg::OP_BRK:
		if (instr[28:18]==11'd1)
			brclass = Stark_pkg::BRC_ERET;
		else
			brclass = Stark_pkg::BRC_NONE;
	Stark_pkg::OP_TRAP:
		if (instr[10:6]==5'd31)
			brclass = Stark_pkg::BRC_ECALL;
		else
			brclass = Stark_pkg::BRC_NONE;
	default:
		brclass = Stark_pkg::BRC_NONE;
	endcase
		
endmodule
