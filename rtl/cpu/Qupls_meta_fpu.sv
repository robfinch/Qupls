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
// 46500 LUTs / 11500 FFs / 210 DSPs (quad supported + prec)
// 10200 LUTs / 4020 FFs / 70 DSPs (no quad or prec, 64-bit fp only)
// ============================================================================

import const_pkg::*;
import QuplsPkg::*;

module Qupls_meta_fpu(rst, clk, idle, prc, ir, rm, a, b, c, t, i, p, o, done);
parameter WID=SUPPORT_QUAD_PRECISION ? 128 : 64;
input rst;
input clk;
input idle;
input [1:0] prc;
input instruction_t ir;
input [2:0] rm;
input [WID-1:0] a;
input [WID-1:0] b;
input [WID-1:0] c;
input [WID-1:0] t;
input [WID-1:0] i;
input [WID-1:0] p;
output reg [WID-1:0] o;
output reg done;

wire [WID-1:0] o16, o32, o64, o128;
wire [7:0] sr64, sr128;
genvar g;

generate begin : gPrec
if (SUPPORT_PREC) begin
for (g = 0; g < WID/16; g = g + 1)
	QuplsSeqFPU2c #(.PREC("H")) ufpu1
	(
		.rst(rst),
		.clk(clk),
		.op(ir[47:41]),
		.a(a[g*16+15:g*16]),
		.b(b[g*16+15:g*16]),
		.c(c[g*16+15:g*16]),
		.o(o16[g*16+15:g*16]),
		.sr()
	);
/*
	Qupls_fpu16(
		.rst(rst),
		.clk(clk),
		.idle(idle),
		.ir(ir),
		.rm(),
		.a(a[g*16+15:g*16]),
		.b(b[g*16+15:g*16]),
		.c(c[g*16+15:g*16]),
		.t(t[g*16+15:g*16]),
		.i(i),
		.p(p),
		.o(o16[g*16+15:g*16]),
		.done()
	);
*/
for (g = 0; g < WID/32; g = g + 1)
	QuplsSeqFPU2c #(.PREC("S")) ufpu1
	(
		.rst(rst),
		.clk(clk),
		.op(ir[47:41]),
		.a(a[g*32+31:g*32]),
		.b(b[g*32+31:g*32]),
		.c(c[g*32+31:g*32]),
		.o(o32[g*32+31:g*32]),
		.sr()
	);
/*
	Qupls_fpu32(
		.rst(rst),
		.clk(clk),
		.idle(idle),
		.ir(ir),
		.rm(),
		.a(a[g*32+31:g*32]),
		.b(b[g*32+31:g*32]),
		.c(c[g*32+31:g*32]),
		.t(t[g*32+31:g*32]),
		.i(i),
		.p(p),
		.o(o32[g*32+31:g*32]),
		.done()
	);
*/
for (g = 0; g < WID/64; g = g + 1)
	QuplsSeqFPU2c #(.PREC("D")) ufpu1
	(
		.rst(rst),
		.clk(clk),
		.a(a[g*64+63:g*64]),
		.b(b[g*64+63:g*64]),
		.c(c[g*64+63:g*64]),
		.o(o64[g*64+63:g*64]),
		.sr(sr64)
	);
/*
	Qupls_fpu64 (
		.rst(rst),
		.clk(clk),
		.idle(idle),
		.ir(ir),
		.rm(),
		.a(a[g*64+63:g*64]),
		.b(b[g*64+63:g*64]),
		.c(c[g*64+63:g*64]),
		.t(t[g*64+63:g*64]),
		.i(i),
		.p(p),
		.o(o64[g*64+63:g*64]),
		.done()
	);
*/
if (SUPPORT_QUAD_PRECISION)
	QuplsSeqFPU2c #(.PREC("Q")) ufpu1
	(
		.rst(rst),
		.clk(clk),
		.a(a),
		.b(b),
		.c(c),
		.o(o128),
		.sr(sr128)
	);
/*		
	Qupls_fpu128 (
		.rst(rst),
		.clk(clk),
		.idle(idle),
		.ir(ir),
		.rm(),
		.a(a),
		.b(b),
		.c(c),
		.t(t),
		.i(i),
		.p(p),
		.o(o128),
		.done()
	);
*/
end
end
endgenerate

always_comb
if (SUPPORT_PREC)
	case(prc)
	2'd0:	o = o16;
	2'd1:	o = o32;
	2'd2:	o = o64;
	2'd3:	o = o128;
	endcase
else
	o = o64;
always_comb
	done = ~sr64[6];

endmodule
