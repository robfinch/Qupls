// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2024  Robert Finch, Waterloo
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

module Qupls_cmp(ir, a, b, o);
parameter WID=128;
input instruction_t ir;
input [WID-1:0] a;
input [WID-1:0] b;
output reg [WID-1:0] o;

always_comb
begin
	o = {WID{1'd0}};
	case(ir.any.opcode)
	OP_R2:
		case(ir.r2.func)
		FN_CMP:
			begin
				o[0] = a == b;
				o[1] = a != b;
				o[2] = $signed(a) < $signed(b);
				o[3] = $signed(a) <= $signed(b);
				o[4] = $signed(a) >= $signed(b);
				o[5] = $signed(a) > $signed(b);
				o[6] = ~a[b[6:0]];
				o[7] =  a[b[6:0]];
			end
		FN_CMPU:
			begin
				o[2] = a < b;
				o[3] = a <= b;
				o[4] = a >= b;
				o[5] = a > b;
			end
		default:
			o = 'd0;
		endcase
	OP_CMPI:
		begin
			o[0] = a == b;
			o[1] = a != b;
			o[2] = $signed(a) < $signed(b);
			o[3] = $signed(a) <= $signed(b);
			o[4] = $signed(a) >= $signed(b);
			o[5] = $signed(a) > $signed(b);
			o[6] = ~a[b[6:0]];
			o[7] =  a[b[6:0]];
		end
	OP_CMPUI:
		begin
			o[2] = a < b;
			o[3] = a <= b;
			o[4] = a >= b;
			o[5] = a > b;
		end
	endcase
end

endmodule
