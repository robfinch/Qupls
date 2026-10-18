// ============================================================================
//        __
//   \\__/ o\    (C) 2026  Robert Finch, Waterloo
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
// 3200 LUTs / 2000 FFs / 14 DSPs
// ============================================================================

/*

	txu = a * itof(c[15:0])
	txy = b * itof(c[39:24])
	
*/

import cpu_types_pkg::*;
import fp32Pkg::*;

module Qupls4_tex(clk, ce, a, b, c, o);
input clk;
input ce;
input [63:0] a;
input [63:0] b;
input [63:0] c;
output reg [63:0] o;

integer n;
FP32 txu,txv,txw,txuvw;
wire [31:0] txi;
reg [3:0] cd [31:0];
wire [31:0] dx = c[3:0];
wire [31:0] dy = c[11:8] + c[3:0];
wire [31:0] dz = c[19:16] + c[11:8] + c[3:0];

fpScaleb32 u3
(
	.clk(clk),
	.ce(ce),
	.a(a[31:0]),
	.b(dx),
	.o(txu)
);

fpScaleb32 u4
(
	.clk(clk),
	.ce(ce),
	.a(a[63:32]),
	.b(dy),
	.o(txv)
);

fpScaleb32 u5
(
	.clk(clk),
	.ce(ce),
	.a(b[31:0]),
	.b(dz),
	.o(txw)
);

fpAdd32x3nr u6
(
	.clk(clk),
	.ce(ce),
	.rm(3'b0),
	.a(txu),
	.b(txv),
	.c(txw),
	.o(txuvw)
);

fpCvt32ToI32 u8
(
	.clk(clk),
	.ce(ce),
	.op(1'b0),	// unsigned
	.i(txuvw),
	.o(txi),
	.overflow()
);

// Delay c to sync with multiplier-sum output
always_ff @(posedge clk)
if (ce) begin
	cd[0] <= c[63:60];
	for (n = 1; n < 31; n = n + 1)
		cd[n] <= cd[n-1];
end

always_ff @(posedge clk)
	if (ce) o <= txi * cd[23];

endmodule

