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
import Stark_pkg::*;

module Stark_branch_eval(instr, om, cr, lc, takb);
input Stark_pkg::instruction_t instr;
input Stark_pkg::operating_mode_t om;
input Stark_pkg::condition_reg_t cr;
input value_t lc;
output reg takb;

wire [4:0] crbit = {om,instr[19:17]};

always_comb
	case(instr.any.opcode)
	Stark_pkg::OP_BCC0,Stark_pkg::OP_BCC1:	// integer unsigned branches
		case(instr.bccld.cnd)
		3'd0:	takb = lc != 64'd0 && cr[crbit]==1'b0;
		3'd1:	takb = lc == 64'd0 && cr[crbit]==1'b0;
		3'd2:	takb = cr[crbit]==1'b0;
		3'd3: takb = lc != 64'd0 && cr[crbit]==1'b1;
		3'd4: takb = lc == 64'd0 && cr[crbit]==1'b1;
		3'd5:	takb = cr[crbit]==1'b1;
		3'd6:	takb = lc != 64'd0;
		3'd7:	takb = lc == 64'd0;
		endcase
	Stark_pkg::OP_B0,Stark_pkg::OP_B1:	takb = 1'b1;
	default:	takb = 1'b0;
	endcase

endmodule
