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
// LUTs / FFs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_idiv(rst, clk, clk2x, ld, ir, div, a, b, bi, c, i, t, o,
	div_done, div_dbz, exc_o);
parameter ALU0 = 1'b1;
parameter WID=64;
parameter LANE=0;
input rst;
input clk;
input clk2x;
input ld;
input Qupls4_pkg::instruction_t ir;
input div;
input [WID-1:0] a;
input [WID-1:0] b;
input [WID-1:0] bi;
input [WID-1:0] c;
input [WID-1:0] i;
input [WID-1:0] t;
output reg [WID-1:0] o;
output reg div_done;
output div_dbz;
output Qupls4_pkg::cause_code_t exc_o;

genvar g;
integer nn,kk,jj;
Qupls4_pkg::cause_code_t exc;
wire [WID:0] zero = {WID+1{1'b0}};
wire [WID:0] dead = {1'b0,{WID/16{16'hdead}}};
wire [WID-1:0] div_q, div_r;
wire div_done1;
reg [WID:0] bus;

Qupls4_divider #(.WID(WID)) udiv0(
	.rst(rst),
	.clk(clk2x),
	.ld(ld),
	.sgn(div),
	.sgnus(1'b0),
	.a(a),
	.b(ir[31] ? i : bi),
	.qo(div_q),
	.ro(div_r),
	.dvByZr(div_dbz),
	.done(div_done1),
	.idle()
);

always_comb
begin
	exc = Qupls4_pkg::FLT_NONE;
	bus = {(WID/16){16'h0000}};
	case(ir.any.opcode)
	Qupls4_pkg::OP_DIV:
		if (ir[31])
			bus = div_q[WID-1:0];
		else
			case (ir.alu.op3)
			3'd0:	bus = div_q[WID-1:0];
			3'd1: bus = div_q[WID-1:0];
			3'd4:	bus = div_r[WID-1:0];
			default:	bus = zero;
			endcase
	default:	bus = {(WID/16){16'hDEAD}};
	endcase
end

always_ff @(posedge clk)
	div_done <= div_done1;
always_ff @(posedge clk)
	o <= bus;
always_ff @(posedge clk)
	exc_o <= exc;

endmodule
