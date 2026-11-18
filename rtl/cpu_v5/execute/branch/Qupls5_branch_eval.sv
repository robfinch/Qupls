// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2026  Robert Finch, Waterloo
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
import Qupls5_pkg::*;

module Qupls5_branch_eval(instr, a, b, c, irq, takb);
parameter WID=64;
input Qupls5_pkg::micro_op_t instr;
input [WID-1+8:0] a;
input [WID-1:0] b;
input [WID-1:0] c;
input irq;
output reg takb;

wire [WID-1:0] ac = a[WID-1:0] & c;
wire [WID-1:0] bc = b & c;
wire ctrok = instr.bo[2] || ((b!=64'd0)^instr.bo[1]);
wire condok = instr.bo[4] || a[instr.bi]==instr.bo[3];

always_comb
	case(instr.opcode)
`ifdef PowerISA
	Qupls5_pkg::OP_BC:	takb = ctrok & condok;
`else
	Qupls5_pkg::OP_BCCU:	// integer unsigned branches
		case(instr.func)
		Qupls5_pkg::CND_EQ:	takb = a[WID-1:0] == b;
		Qupls5_pkg::CND_NE:	takb = a[WID-1:0] != b;
		Qupls5_pkg::CND_LT:	takb = a[WID-1:0] < b;
		Qupls5_pkg::CND_LE:	takb = a[WID-1:0] <= b;
		Qupls5_pkg::CND_GE: takb = a[WID-1:0] >= b;
		Qupls5_pkg::CND_GT:	takb = a[WID-1:0] > b;
		// Bit set or clear
		Qupls5_pkg::CND_BBC:	takb = ~a[b[6:0]];
		Qupls5_pkg::CND_BBS:	takb =  a[b[6:0]];
		// Logical 0 or 1
		Qupls5_pkg::CND_NAND:	takb = ~(|a[WID-1:0] & |b);
		Qupls5_pkg::CND_AND:	takb = |a[WID-1:0] & |b;
		Qupls5_pkg::CND_NOR:	takb = ~(|a[WID-1:0] | |b);
		Qupls5_pkg::CND_OR:	takb = |a[WID-1:0] | |b;
		Qupls5_pkg::CND_BOI:	takb = irq;
		default:	takb = 1'b0;
		endcase
	Qupls5_pkg::OP_BCC:	// integer signed branches
		case(instr.func)
		Qupls5_pkg::CND_EQ:	takb = a[WID-1:0] == b;
		Qupls5_pkg::CND_NE:	takb = a[WID-1:0] != b;
		Qupls5_pkg::CND_LT:	takb = $signed(a[WID-1:0]) < $signed(b);
		Qupls5_pkg::CND_LE:	takb = $signed(a[WID-1:0]) <= $signed(b);
		Qupls5_pkg::CND_GE: takb = $signed(a[WID-1:0]) >= $signed(b);
		Qupls5_pkg::CND_GT:	takb = $signed(a[WID-1:0]) > $signed(b);
		// Bitwise 0 or 1
		Qupls5_pkg::CND_NAND:	takb = ~|(a[WID-1:0] & b);
		Qupls5_pkg::CND_AND:	takb = |(a[WID-1:0] & b);
		Qupls5_pkg::CND_NOR:	takb = ~|(a[WID-1:0] | b);
		Qupls5_pkg::CND_OR:	takb = |(a[WID-1:0] | b);
		default:	takb = 1'b0;
		endcase
	Qupls5_pkg::OP_MBCC:
		case(instr.func)
		Qupls5_pkg::CND_EQ:	takb = (ac[WID-1:0] & c) == bc;
		Qupls5_pkg::CND_NE:	takb = (ac[WID-1:0] & c) != bc;
		Qupls5_pkg::CND_LT:	takb = $signed(ac[WID-1:0]) < $signed(bc);
		Qupls5_pkg::CND_LE:	takb = $signed(ac[WID-1:0]) <= $signed(bc);
		Qupls5_pkg::CND_GE: takb = $signed(ac[WID-1:0]) >= $signed(bc);
		Qupls5_pkg::CND_GT:	takb = $signed(ac[WID-1:0]) > $signed(bc);
		// Bit set or clear
		Qupls5_pkg::CND_BBC:	takb = ~ac[b[6:0]];
		Qupls5_pkg::CND_BBS:	takb =  ac[b[6:0]];
		// Bitwise 0 or 1
		Qupls5_pkg::CND_NAND:	takb = ~|(ac[WID-1:0] & bc);
		Qupls5_pkg::CND_AND:	takb = |(ac[WID-1:0] & bc);
		Qupls5_pkg::CND_NOR:	takb = ~|(ac[WID-1:0] | bc);
		Qupls5_pkg::CND_OR:	takb = |(ac[WID-1:0] | bc);
		default:	takb = 1'b0;
		endcase
`endif		
	default:	takb = 1'b0;
	endcase

endmodule

