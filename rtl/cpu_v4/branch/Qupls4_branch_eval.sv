// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2025  Robert Finch, Waterloo
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
// 60 LUTs
// ============================================================================
//
import Qupls4_pkg::*;

module Qupls4_branch_eval(instr, a, b, c, takb);
parameter WID=64;
input Qupls4_pkg::micro_op_t instr;
input [WID-1:0] a;
input [WID-1:0] b;
input c;
output reg takb;

always_comb
	case(instr.opcode)
	Qupls4_pkg::OP_BCCU8,Qupls4_pkg::OP_BCCU16,Qupls4_pkg::OP_BCCU32,Qupls4_pkg::OP_BCCU64:	// integer unsigned branches
		case(instr.cnd)
		CND_EQ:	takb = a == b;
		CND_NE:	takb = a != b;
		CND_LT:	takb = a < b;
		CND_LE:	takb = a <= b;
		CND_GE: takb = a >= b;
		CND_GT:	takb = a > b;
		// Logical 0 or 1
		CND_NAND:	takb = ~(|a & |b);
		CND_AND:	takb = |a & |b;
		CND_NOR:	takb = ~(|a | |b);
		CND_OR:	takb = |a | |b;
		CND_BOI:	takb = c;
		default:	takb = 1'b0;
		endcase
	Qupls4_pkg::OP_BCC8,Qupls4_pkg::OP_BCC16,Qupls4_pkg::OP_BCC32,Qupls4_pkg::OP_BCC64:	// integer signed branches
		case(instr.cnd)
		CND_EQ:	takb = a == b;
		CND_NE:	takb = a != b;
		CND_LT:	takb = $signed(a) < $signed(b);
		CND_LE:	takb = $signed(a) <= $signed(b);
		CND_GE: takb = $signed(a) >= $signed(b);
		CND_GT:	takb = $signed(a) > $signed(b);
		// Bitwise 0 or 1
		CND_NAND:	takb = ~|(a & b);
		CND_AND:	takb = |(a & b);
		CND_NOR:	takb = ~|(a | b);
		CND_OR:	takb = |(a | b);
		default:	takb = 1'b0;
		endcase
	default:	takb = 1'b0;
	endcase

endmodule

