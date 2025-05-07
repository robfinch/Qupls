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
// 46500 LUTs / 11500 FFs / 210 DSPs (quad supported + prec)
// 10200 LUTs / 4020 FFs / 70 DSPs (no quad or prec, 64-bit fp only)
// ============================================================================

import const_pkg::*;
import Stark_pkg::*;

module Stark_meta_fpu(rst, clk, clk3x, idle, stomp, rse_i, rse_o, rm,
	z, cptgt, o, otag, we_o, done, exc);
parameter WID=Stark_pkg::SUPPORT_QUAD_PRECISION|Stark_pkg::SUPPORT_CAPABILITIES ? 128 : 64;
input rst;
input clk;
input clk3x;
input idle;
input Stark_pkg::rob_bitmask_t stomp;
input Stark_pkg::reservation_station_entry_t rse_i;
output Stark_pkg::reservation_station_entry_t rse_o;
input [2:0] rm;
input z;
input [WID-1:0] cptgt;
output reg [WID-1:0] o;
output reg otag;
output reg [WID/8:0] we_o;
output reg done;
output Stark_pkg::cause_code_t exc;

Stark_pkg::reservation_station_entry_t rse1,rse2;
Stark_pkg::operating_mode_t om;
reg [1:0] prc;
Stark_pkg::instruction_t ir;
reg [WID-1:0] a;
reg [WID-1:0] b;
reg [WID-1:0] c;
reg [WID-1:0] t;
reg [WID-1:0] i;
aregno_t aRd_i;
reg [1:0] stomp_con;	// stomp conveyor
reg [WID/8:0] we,we1,we2;
always_comb om = rse_i.om;
always_comb ir = rse_i.ins;
always_comb a = rse_i.argA;
always_comb b = rse_i.argB;
always_comb c = rse_i.argC;
always_comb t = rse_i.argD;
always_comb i = rse_i.argI;
always_comb aRd_i = rse_i.aRd;

Stark_pkg::cause_code_t exc128,exc64;
reg [WID-1:0] o1;
wire [WID-1:0] o16, o32, o64, o128;
wire [7:0] sr64, sr128;
wire done16, done32, done64, done128;
genvar g,mm;

generate begin : gPrec
if (Stark_pkg::SUPPORT_PREC) begin
for (g = 0; g < WID/16; g = g + 1)
	Stark_seqFPU2c #(.PREC("H")) ufpu1
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
	Stark_fpu16(
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
	Stark_seqFPU2c #(.PREC("S")) ufpu1
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
	Stark_fpu32(
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
	Stark_seqFPU2c #(.PREC("D")) ufpu1
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
	Stark_fpu64 (
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
if (Stark_pkg::SUPPORT_QUAD_PRECISION|Stark_pkg::SUPPORT_CAPABILITIES)
/*
	StarkSeqFPU2c #(.PREC("Q")) ufpu1
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
		
	Stark_fpu128 ufpu128 (
		.rst(rst),
		.clk(clk),
		.idle(idle),
		.om(om),
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
if (Stark_pkg::NFPU > 0 && !(Stark_pkg::SUPPORT_QUAD_PRECISION|Stark_pkg::SUPPORT_CAPABILITIES))
    for (g = 0; g < WID/64; g = g + 1)
	Stark_fpu64 ufpu64 (
		.rst(rst),
		.clk(clk),
		.clk3x(clk3x),
		.idle(idle),
		.om(om),
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
if (Stark_pkg::SUPPORT_PREC)
	case(prc)
	2'd0:	o1 = o16;
	2'd1:	o1 = o32;
	2'd2:	o1 = o64;
	2'd3:	o1 = o128;
	endcase
else if (Stark_pkg::SUPPORT_CAPABILITIES)
	o1 = o128;
else
	o1 = o64;

// Copy only the lanes specified in the mask to the target.

generate begin : gCptgt
	for (mm = 0; mm < WID/8; mm = mm + 1) begin
    always_comb
    	if (stomp_con[1]||rse2.ins.any.opcode==Stark_pkg::OP_NOP)
        o[mm*8+7:mm*8] = t[mm*8+7:mm*8];
      else if (cptgt[mm])
        o[mm*8+7:mm*8] = z ? 8'h00 : t[mm*8+7:mm*8];
      else
        o[mm*8+7:mm*8] = o1[mm*8+7:mm*8];
    end
end
endgenerate

delay2 #(.WID(WID/8+1)) udly6 (.clk(clk), .ce(1'b1), .i(we), .o(we2));

always_ff @(posedge clk)
	rse1 <= rse_i;
always_ff @(posedge clk)
	rse2 <= rse1;
always_comb
	rse_o = rse2;

always_comb
	we = 9'h1FF;

always_ff @(posedge clk)
begin
	if (~|aRd_i || stomp[rse_i.rndx])
		stomp_con[0] <= 1'b1;
	else
		stomp_con[0] <= 1'b0;
	if (stomp[rse1.rndx])
		stomp_con[1] <= 1'b1;
	else
		stomp_con[1] <= stomp_con[0];
end

always_comb
	we_o = rse_o.v ? we2 : 9'h000;


always_comb
if (Stark_pkg::SUPPORT_PREC)
	case(prc)
	2'd0:	done = done16;
	2'd1:	done = done32;
	2'd2:	done = done64;
	2'd3: done = done128;
	endcase
else if (Stark_pkg::SUPPORT_CAPABILITIES)
	done = done128;
else
	done = done64;
//	done = ~sr64[6];
always_comb
	exc = exc64;

endmodule
