// ============================================================================
//        __
//   \\__/ o\    (C) 2024  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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
//
import QuplsPkg::*;

module Qupls_renamer_srl(rst, clk, en, rot, o);
parameter N=0;
localparam SIZE = $clog2(PREGS/4);
localparam TOPBIT = $clog2(PREGS/4)-1;
input rst;
input clk;
input en;
input rot;
output reg [9:0] o = 10'd0;

reg [TOPBIT:0] mem [0:PREGS/4-1];
integer nn,mm;

initial begin
	for (nn = 0; nn < PREGS/4; nn = nn + 1)
		mem[nn] = nn;
end

always_ff @(posedge clk)
if (rst)
	o <= {8'b0,N[1:0],{SIZE{1'd0}}};
else begin
	if (rot & en) begin
		for (mm = 1; mm < PREGS/4-2; mm = mm + 1)
			mem[mm] <= mem[mm+1];
		mem[PREGS/4-2] <= mem[1];
	end
	if (rot & en)
		o <= {8'b0,N[1:0],mem[1]};
end

endmodule
