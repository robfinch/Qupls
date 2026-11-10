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
// Decode the constant from the cache line given the position.
// 130 LUTs
// ============================================================================

import const_pkg::*;
import Qupls5_pkg::*;

module Qupls5_constant_decoder(pos,sz,cline,cnst);
input [3:0] pos;
input [1:0] sz;
input [239:0] cline;
output reg [63:0] cnst;

reg [63:0] cnst1;
reg [159:0] cline1;

always_comb
begin
	cline1 = {cline[191:168],cline[160:152],cline[143:104],cline[95:56]};
	case(sz)
	2'd0:
		begin
			cnst1 = cline1 >> ({5'd0,pos} * 5'd16);
			cnst = {{32{cnst1[15]}},cnst1[15:0]};
		end
	2'd1:
		begin
			cnst1 = cline1 >> ({5'd0,pos} * 5'd16);
			cnst = {{32{cnst1[31]}},cnst1[31:0]};
		end
	2'd2:
		begin
			cnst1 = cline1 >> ({5'd0,pos} * 5'd16);
			cnst = {{16{cnst1[47]}},cnst1[47:0]};
		end
	2'd3: cnst = cline1 >> ({5'd0,pos} * 5'd16);
	endcase
end

endmodule
