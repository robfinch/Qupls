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
// 1100 LUTs / 1100 FFs / 2 DSPs / 200 MHz	 / Lat23 (Float)
// 250 LUTs / 200 FFs / 20 DSPs	/ 130 MHz / Lat5	(16.16 fixed point)
// ============================================================================

/*

	txu = a * itof(c[15:0])
	txy = b * itof(c[39:24])
	
*/

import cpu_types_pkg::*;
import fp32Pkg::*;

module Qupls5_tex(clk, ce, a, b, c, d, o);
input clk;
input ce;
input [63:0] a;
input [63:0] b;
input [63:0] c;
input [63:0] d;
output reg [63:0] o;
parameter FLOAT = 1'b0;
parameter point_width = 16;
parameter subpixel_width = 16;

integer n;
FP32 txu,txv,txw,txuvw;
reg [63:0] ixu,ixv,ixw,ixuvw,ixuvw1,ixuvw2,ixuvw3;

wire [31:0] txi;
reg [3:0] cd [31:0];
reg [31:0] dx;
reg [31:0] dy;
reg [31:0] dz;

generate begin : gFloatFixed
	if (FLOAT) begin
always_comb
	dx = d[3:0];
always_comb
	dy = d[11:8] + d[3:0];
always_comb
	dz = d[19:16] + d[11:8] + d[3:0];

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
	.a(b[31:0]),
	.b(dy),
	.o(txv)
);

fpScaleb32 u5
(
	.clk(clk),
	.ce(ce),
	.a(c[31:0]),
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
	cd[0] <= d[63:60];
	for (n = 1; n < 31; n = n + 1)
		cd[n] <= cd[n-1];
end

always_ff @(posedge clk)
	if (ce) o <= {32'b0,txi} * cd[23];
end
else begin
always_comb dx = 32'b1 << d[ 3: 0];
always_comb dy = 32'b1 << d[11: 8];
always_comb dz = 32'b1 << d[19:16];
always_ff @(posedge clk) if (ce) ixu <= (a[point_width+subpixel_width-1:0] * dx);
always_ff @(posedge clk) if (ce) ixv <= (b[point_width+subpixel_width-1:0] * dx * dy);
always_ff @(posedge clk) if (ce) ixw <= (c[point_width+subpixel_width-1:0] * dx * dy * dz);
// We want the index to point to a whole byte, so trim off fractional bits.
always_ff @(posedge clk) if (ce) ixuvw1 <= ((ixu + ixv + ixw) * d[63:60]) >> subpixel_width;
always_ff @(posedge clk) if (ce) ixuvw2 <= ixuvw1;
//always_ff @(posedge clk) if (ce) ixuvw3 <= ixuvw2;
always_ff @(posedge clk) if (ce) ixuvw <= ixuvw2;
always_ff @(posedge clk) if (ce) o <= ixuvw;
end
end
endgenerate

endmodule

