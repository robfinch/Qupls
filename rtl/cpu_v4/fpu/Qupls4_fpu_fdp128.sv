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
import fp128Pkg::*;

module Qupls4_fpu_fdp128(rst, clk, clk3x, om, idle, ir, rm, a, b, c, d, t, i, p, o, done, exc);
parameter WID=128;
input rst;
input clk;
input clk3x;
input Qupls4_pkg::operating_mode_t om;
input idle;
input Qupls4_pkg::instruction_t ir;
input [2:0] rm;
input [63:0] a;
input [63:0] b;
input [63:0] c;
input [63:0] d;
input [63:0] t;
input [63:0] i;
input [63:0] p;
output reg [127:0] o;
output reg done;
output Qupls4_pkg::cause_code_t exc;

wire [127:0] bus;
wire ce = 1'b1;

reg fdpop, fdp_done;
FP128 fdpa,fdpb,fdpc,fdpd;
/*
always_comb
	if (ir.f3.func==FN_FMS || ir.f3.func==FN_FNMS)
		fmaop = 1'b1;
	else
		fmaop = 1'b0;
*/
always_comb
	case(ir.fpu.func)
	Qupls4_pkg::FN_FADD,Qupls4_pkg::FN_FSUB:
		begin
			fdpa <= {a,b};
			fdpb <= `ONEQ;	// 1,0
			fdpc <= {c,d};
			fdpd <= `ONEQ;	// 1,0
			fdpop <= 1'b0;
		end
	Qupls4_pkg::FN_FSUB:
		begin
			fdpa <= {a,b};
			fdpb <= `ONEQ;	// 1,0
			fdpc <= {c,d};
			fdpd <= `ONEQ;	// 1,0
			fdpop <= 1'b1;
		end
	Qupls4_pkg::FN_FMUL:
		begin
			fdpa <= {a,b};
			fdpb <= {c,d};
			fdpc <= `ZEROQ;
			fdpd <= `ZEROQ;
			fdpop <= 1'b0;
		end
	default:
		begin
			fdpa <= `ZEROQ;
			fdpb <= `ZEROQ;
			fdpc <= `ZEROQ;
			fdpd <= `ZEROQ;
			fdpop <= 1'b0;
		end
	endcase


fpFDP128nrL8 ufma1
(
	.clk(clk),
	.ce(ce),
	.op(fdpop),
	.rm(rm),
	.a(fdpa),
	.b(fdpb),
	.c(fdpc),
	.d(fdpd),
	.o(bus),
	.inf(),
	.zero(),
	.overflow(),
	.underflow(),
	.inexact()
);

always_ff @(posedge clk)
if (rst) begin
	fdp_done <= 1'b0;
end
else begin
	fdp_done <= cnt>=12'h8;
end

always_ff @(posedge clk)
	o = bus;
always_comb
	exc = Qupls4_pkg::FLT_NONE;

endmodule
