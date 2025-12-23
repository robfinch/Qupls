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
// 3600 LUTs / 1100 FFs	ALU0
// 3100 LUTs / 700 FFs
// 13.5k LUTs	/ 710 FFs ALU0 with capabilities
//  7.5 kLUTs / 710 FFs ALU0 without capabilities
// 14.5k LUTs / 1420 FFs ALU0 128-bit without capabilities
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_imul(rst, clk, issue, ir, a, b, bi, c, i, t, o, mul_done);
parameter ALU0 = 1'b1;
parameter WID=64;
parameter LANE=0;
input rst;
input clk;
input issue;
input Qupls4_pkg::micro_op_t ir;
input [WID-1:0] a;
input [WID-1:0] b;
input [WID-1:0] bi;
input [WID-1:0] c;
input [WID-1:0] i;
input [WID-1:0] t;
output reg [WID-1:0] o;
output reg mul_done;

wire [WID:0] zero = {WID+1{1'b0}};
wire [WID:0] dead = {1'b0,{WID/16{16'hdead}}};
reg [3:0] mul_cnt;
reg [WID*2-1:0] prod, prod1, prod2;
reg [WID*2-1:0] produ, produ1, produ2;
reg [WID:0] bus;

always_ff @(posedge clk)
begin
	prod2 <= $signed(a) * $signed(bi);
	prod1 <= prod2;
	prod <= prod1;
end
always_ff @(posedge clk)
begin
	produ2 <= a * bi;
	produ1 <= produ2;
	produ <= produ1;
end

always_ff @(posedge clk)
if (rst) begin
	mul_cnt <= 4'hF;
	mul_done <= 1'b0;
end
else begin
	mul_cnt <= {mul_cnt[2:0],1'b1};
	if (issue)
		mul_cnt <= 4'd0;
	mul_done <= mul_cnt[3];
end

always_comb
begin
	bus = {(WID/16){16'h0000}};
	case(ir.opcode)
	Qupls4_pkg::OP_R3B,Qupls4_pkg::OP_R3W,Qupls4_pkg::OP_R3T,Qupls4_pkg::OP_R3O,
	Qupls4_pkg::OP_R3BP,Qupls4_pkg::OP_R3WP,Qupls4_pkg::OP_R3TP,Qupls4_pkg::OP_R3OP,
	Qupls4_pkg::OP_R3P:
		case(ir.func)
		Qupls4_pkg::FN_MUL: 	bus = prod[WID-1:0];
		Qupls4_pkg::FN_MULU:	bus = produ[WID-1:0];
		default:	bus = zero;
		endcase
	Qupls4_pkg::OP_MULI:	bus = prod[WID-1:0];
	Qupls4_pkg::OP_MULUI:	bus = produ[WID-1:0];
	default:	bus = zero;
	endcase
end

always_ff @(posedge clk)
	o = bus;

endmodule
