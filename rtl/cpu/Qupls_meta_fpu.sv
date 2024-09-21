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

module Qupls_meta_fpu(rst, clk, clk3x, idle, prc, ir, rm, a, b, c, t, i, p,
	atag, btag, z, cptgt, o, otag, done, exc);
parameter WID=SUPPORT_QUAD_PRECISION|SUPPORT_CAPABILITIES ? 128 : 64;
input rst;
input clk;
input clk3x;
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
input atag;
input btag;
input z;
input [WID-1:0] cptgt;
output reg [WID-1:0] o;
output reg otag;
output reg done;
output cause_code_t exc;

cause_code_t exc128,exc64;
reg [WID-1:0] o1;
wire [WID-1:0] o16, o32, o64, o128;
wire [7:0] sr64, sr128;
wire done16, done32, done64, done128;
genvar g,mm;

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
end
if (SUPPORT_QUAD_PRECISION|SUPPORT_CAPABILITIES)
/*
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
*/
		
	Qupls_fpu128 ufpu128 (
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
		.atag(atag),
		.btag(btag),
		.o(o128),
		.otag(otag),
		.done(),
		.exc(exc128)
	);

end
if (NFPU > 0 && !(SUPPORT_QUAD_PRECISION|SUPPORT_CAPABILITIES))
    for (g = 0; g < WID/64; g = g + 1)
	Qupls_fpu64 ufpu64 (
		.rst(rst),
		.clk(clk),
		.clk3x(clk3x),
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
		.done(done64),
		.exc(exc64)
	);

endgenerate

always_comb
if (SUPPORT_PREC)
	case(prc)
	2'd0:	o1 = o16;
	2'd1:	o1 = o32;
	2'd2:	o1 = o64;
	2'd3:	o1 = o128;
	endcase
else if (SUPPORT_CAPABILITIES)
	o1 = o128;
else
	o1 = o64;

// Copy only the lanes specified in the mask to the target.

generate begin : gCptgt
	for (mm = 0; mm < WID/8; mm = mm + 1) begin
        always_comb
            if (cptgt[mm])
                o[mm*8+7:mm*8] = z ? 8'h00 : t[mm*8+7:mm*8];
            else
                o[mm*8+7:mm*8] = o1[mm*8+7:mm*8];
    end
end
endgenerate

always_comb
if (SUPPORT_PREC)
	case(prc)
	2'd0:	done = done16;
	2'd1:	done = done32;
	2'd2:	done = done64;
	2'd3: done = done128;
	endcase
else if (SUPPORT_CAPABILITIES)
	done = done128;
else
	done = done64;
//	done = ~sr64[6];
always_comb
	exc = exc64;

endmodule
