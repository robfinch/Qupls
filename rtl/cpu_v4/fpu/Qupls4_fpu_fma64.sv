// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2025 Robert Finch, Waterloo
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

import Qupls4_pkg::*;
//import fp64Pkg::*;

module Qupls4_fpu_fma64(rst, clk, clk3x, om, idle, ir, rm, a, b, c, t, i, p, o, done, exc);
parameter WID=64;
input rst;
input clk;
input clk3x;
input Qupls4_pkg::operating_mode_t om;
input idle;
input Qupls4_pkg::instruction_t ir;
input [2:0] rm;
input [WID-1:0] a;
input [WID-1:0] b;
input [WID-1:0] c;
input [WID-1:0] t;
input [WID-1:0] i;
input [WID-1:0] p;
output reg [WID-1:0] o;
output reg done;
output Qupls4_pkg::cause_code_t exc;

wire [WID-1:0] bus;
wire ce = 1'b1;

reg fmaop, fma_done;
reg [WID-1:0] fmac;
reg [WID-1:0] fmab;
/*
always_comb
	if (ir.func==FN_FMS || ir.func==FN_FNMS)
		fmaop = 1'b1;
	else
		fmaop = 1'b0;
*/
always_comb
	if (ir.op4==Qupls4_pkg::FOP4_FADD || ir.op4==Qupls4_pkg::FOP4_FSUB)
		fmab <= 64'h3FF0000000000000;	// 1,0
	else
		fmab <= b;

always_comb
	if (ir.op4==FOP4_FMUL || ir.op4==FOP4_FDIV)
		fmac = 64'd0;
	else
		fmac = c;

fpFMA64nrL8 ufma1
(
	.clk(clk),
	.ce(ce),
	.op(fmaop),
	.rm(rm),
	.a(a),
	.b(fmab),
	.c(fmac),
	.o(bus),
	.inf(),
	.zero(),
	.overflow(),
	.underflow(),
	.inexact()
);

always_ff @(posedge clk)
if (rst) begin
	fma_done <= 1'b0;
end
else begin
	fma_done <= cnt>=12'h8;
end

always_ff @(posedge clk)
	o = bus;
always_comb
	exc = Qupls4_pkg::FLT_NONE;

endmodule
