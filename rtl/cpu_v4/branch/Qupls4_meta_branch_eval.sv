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
import const_pkg::*;
import Qupls4_pkg::*;

module Qupls4_meta_branch_eval(rst, clk, instr, a, b, c, takb);
parameter WID=64;
input rst;
input clk;
input Qupls4_pkg::micro_op_t instr;
input [WID-1:0] a;
input [WID-1:0] b;
input c;
output reg takb;

wire takb8, takb16, takb32, takb64;
Qupls4_branch_eval #(.WID( 8))  u8 (instr, a[7: 0], b[7: 0], c, takb8);
Qupls4_branch_eval #(.WID(16)) u16 (instr, a[15:0], b[15:0], c, takb16);
Qupls4_branch_eval #(.WID(32)) u32 (instr, a[31:0], b[31:0], c, takb32);
Qupls4_branch_eval #(.WID(64)) u64 (instr, a[63:0], b[63:0], c, takb64);

always_ff @(posedge clk)
if (rst) begin
	takb <= FALSE;
end
else begin
	case(instr.opcode)
	Qupls4_pkg::OP_BCCU8,Qupls4_pkg::OP_BCC8:
		takb <= takb8;
	Qupls4_pkg::OP_BCCU16,Qupls4_pkg::OP_BCC16:
		takb <= takb16;
	Qupls4_pkg::OP_BCCU32,Qupls4_pkg::OP_BCC32:
		takb <= takb32;
	Qupls4_pkg::OP_BCCU64,Qupls4_pkg::OP_BCC64:
		takb <= takb64;
	default:	takb <= FALSE;
	endcase
end

endmodule

