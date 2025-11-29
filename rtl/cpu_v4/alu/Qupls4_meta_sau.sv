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
// 41000 LUTs / 2000 FFs / 239 DSPs	-	SAU0 (128-bit)
// 21900 LUTs / 810 FFs / 0 DSPs (64-bit, full precision support)
// 7200 LUTs / 650 FFs / 0 DSPs (64-bit, no precision support)
// ============================================================================

import const_pkg::*;
import Qupls4_pkg::*;

module Qupls4_meta_sau(rst, clk, rse_i, rse_o, lane, cptgt, z, stomp,
	qres, cs, csr, cpl, canary, o, cp_o, we_o, exc);
parameter SAU0 = 1'b0;
parameter WID=$bits(cpu_types_pkg::value_t); 
input rst;
input clk;
input Qupls4_pkg::reservation_station_entry_t rse_i;
output Qupls4_pkg::reservation_station_entry_t rse_o;
input [2:0] lane;
input [7:0] cptgt;
input z;
input Qupls4_pkg::rob_bitmask_t stomp;
input [WID-1:0] qres;
input [2:0] cs;
input [7:0] cpl;
input [WID-1:0] canary;
input [WID-1:0] csr;
output reg [WID-1:0] o;
output checkpt_ndx_t cp_o;
output reg [WID/8:0] we_o;			// extra bit for tag update
output reg [WID-1:0] exc;

reg [WID-1:0] a;
reg [WID-1:0] b;
reg [WID-1:0] bi;
reg [WID-1:0] c;
reg [WID-1:0] i;
reg [WID-1:0] t;
reg [2:0] chunk;
Qupls4_pkg::rob_bitmask_t stompo;
Qupls4_pkg::memsz_t prc;
cpu_types_pkg::pc_address_t pc;
checkpt_ndx_t cp_i;
aregno_t aRd_i;
Qupls4_pkg::micro_op_t ir;
always_comb ir = rse_i.uop;
always_comb a = rse_i.argA;
always_comb b = rse_i.argB;
always_comb bi = rse_i.argB|rse_i.argI;
always_comb c = rse_i.argC;
always_comb t = rse_i.argD;
always_comb i = rse_i.argI;
always_comb pc = rse_i.pc;
always_comb cp_i = rse_i.cndx;
always_comb aRd_i = rse_i.aRd;
always_comb prc = Qupls4_pkg::memsz_t'(rse_i.prc);
reg isflt,issimd;
wire [WID-1:0] zero = {WID{1'b0}};

function [7:0] tmaxu8;
input [7:0] a;
input [7:0] b;
input [7:0] c;
begin
	tmaxu8 = a > b && a > c ? a : b > c ? b : c;
end
endfunction

function [7:0] tminu8;
input [7:0] a;
input [7:0] b;
input [7:0] c;
begin
	tminu8 = a < b && a < c ? a : b < c ? b : c;
end
endfunction

function [7:0] tmax8;
input [7:0] a;
input [7:0] b;
input [7:0] c;
begin
	tmax8 = $signed(a) > $signed(b) && $signed(a) > $signed(c) ? a : $signed(b) > $signed (c) ? b : c;
end
endfunction

function [7:0] tmin8;
input [7:0] a;
input [7:0] b;
input [7:0] c;
begin
	tmin8 = $signed(a) < $signed(b) && $signed(a) < $signed(c) ? a : $signed(b) < $signed (c) ? b : c;
end
endfunction

function [15:0] tmaxu16;
input [15:0] a;
input [15:0] b;
input [15:0] c;
begin
	tmaxu16 = a > b && a > c ? a : b > c ? b : c;
end
endfunction

function [15:0] tminu16;
input [15:0] a;
input [15:0] b;
input [15:0] c;
begin
	tminu16 = a < b && a < c ? a : b < c ? b : c;
end
endfunction

function [15:0] tmax16;
input [15:0] a;
input [15:0] b;
input [15:0] c;
begin
	tmax16 = $signed(a) > $signed(b) && $signed(a) > $signed(c) ? a : $signed(b) > $signed (c) ? b : c;
end
endfunction

function [15:0] tmin16;
input [15:0] a;
input [15:0] b;
input [15:0] c;
begin
	tmin16 = $signed(a) < $signed(b) && $signed(a) < $signed(c) ? a : $signed(b) < $signed (c) ? b : c;
end
endfunction

function [31:0] tmaxu32;
input [31:0] a;
input [31:0] b;
input [31:0] c;
begin
	tmaxu32 = a > b && a > c ? a : b > c ? b : c;
end
endfunction

function [31:0] tminu32;
input [31:0] a;
input [31:0] b;
input [31:0] c;
begin
	tminu32 = a < b && a < c ? a : b < c ? b : c;
end
endfunction

function [31:0] tmax32;
input [31:0] a;
input [31:0] b;
input [31:0] c;
begin
	tmax32 = $signed(a) > $signed(b) && $signed(a) > $signed(c) ? a : $signed(b) > $signed (c) ? b : c;
end
endfunction

function [31:0] tmin32;
input [31:0] a;
input [31:0] b;
input [31:0] c;
begin
	tmin32 = $signed(a) < $signed(b) && $signed(a) < $signed(c) ? a : $signed(b) < $signed (c) ? b : c;
end
endfunction

function [7:0] mask8;
input [7:0] a;
input c;
begin
	mask8 = c ? a : 8'h00;
end
endfunction

always_comb
	chunk = rse_i.uop.any.num;

always_comb
	isflt = ir.any.opcode==Qupls4_pkg::OP_FLTH||
		ir.any.opcode==Qupls4_pkg::OP_FLTS||
		ir.any.opcode==Qupls4_pkg::OP_FLTD||
		ir.any.opcode==Qupls4_pkg::OP_FLTQ ||
		ir.any.opcode==Qupls4_pkg::OP_FLTPH ||
		ir.any.opcode==Qupls4_pkg::OP_FLTPS ||
		ir.any.opcode==Qupls4_pkg::OP_FLTPD ||
		ir.any.opcode==Qupls4_pkg::OP_FLTPQ
		;
always_comb
	issimd = ir.any.opcode==Qupls4_pkg::OP_R3BP ||
		ir.any.opcode==Qupls4_pkg::OP_R3WP ||
		ir.any.opcode==Qupls4_pkg::OP_R3TP ||
		ir.any.opcode==Qupls4_pkg::OP_R3OP ||
		ir.any.opcode==Qupls4_pkg::OP_FLTPH ||
		ir.any.opcode==Qupls4_pkg::OP_FLTPS ||
		ir.any.opcode==Qupls4_pkg::OP_FLTPD ||
		ir.any.opcode==Qupls4_pkg::OP_FLTPQ
		;
reg [WID-1:0] t1;
reg z1;
reg [7:0] cptgt1;
wire [WID-1:0] o8,o16,o32,o64,o128;
reg [WID-1:0] ro8,ro16,ro32,ro64,ro128;
wire o64_tag, o128_tag;
reg [WID-1:0] o1;
reg o1_tag;
wire [WID-1:0] exc8, exc16,exc32,exc64,exc128;
reg [WID-1:0] exc1;
integer n;
genvar g,mm,xx;

generate begin : g8
reg [WID-1:0] c1;
	if (Qupls4_pkg::SUPPORT_PREC)
	for (g = 0; g < WID/8; g = g + 1)
		Qupls4_sau #(.WID(8), .SAU0(SAU0), .LANE(g)) ualu8
		(
			.rst(rst),
			.clk(clk),
			.chunk(chunk),
			.mask(c),
			.om(rse_i.om),
			.ir(ir),
			.a(a[g*8+7:g*8]),
			.b(b[g*8+7:g*8]),
			.bi(bi[g*8+7:g*8]),
			.c(c[g*8+7:g*8]),
			.i(i),
			.t(t[g*8+7:g*8]),
			.qres(qres[g*8+7:g*8]),
			.cs(cs),
			.pc(pc),
			.csr(csr),
			.cpl(cpl),
			.canary(canary),
			.o(o8[g*8+7:g*8]),
			.exc_o(exc8[g*8+7:g*8])
		);
	always_comb
	begin
		c1 = zero;
		case(ir.any.opcode)
			// ToDo: finish these off
		Qupls4_pkg::OP_R3B:
			begin
			c1 = c >> {lane,3'b0};
			case(ir.r3.func)
			Qupls4_pkg::FN_REDSUM:	ro8 =
				(c1[0] ? a[7:0] : 8'h00) +
				(c1[1] ? a[15:8] : 8'h00) +
				(c1[2] ? a[23:16] : 8'h00) +
				(c1[3] ? a[31:24] : 8'h00) +
				(c1[4] ? a[39:32] : 8'h00) +
				(c1[5] ? a[47:40] : 8'h00) +
				(c1[6] ? a[55:48] : 8'h00) +
				(c1[7] ? a[63:56] : 8'h00) +
				b[7:0];
			Qupls4_pkg::FN_REDAND:	ro8 = 
				(c1[0] ? a[7:0] : 8'hFF) &
				(c1[1] ? a[15:8] : 8'hFF) &
				(c1[2] ? a[23:16] : 8'hFF) &
				(c1[3] ? a[31:24] : 8'hFF) &
				(c1[4] ? a[39:32] : 8'hFF) &
				(c1[5] ? a[47:40] : 8'hFF) &
				(c1[6] ? a[55:48] : 8'hFF) &
				(c1[7] ? a[63:56] : 8'hFF) &
				b[7:0];
			Qupls4_pkg::FN_REDOR:		ro8 =
				(c1[0] ? a[7:0] : 8'h00) |
				(c1[1] ? a[15:8] : 8'h00) |
				(c1[2] ? a[23:16] : 8'h00) |
				(c1[3] ? a[31:24] : 8'h00) |
				(c1[4] ? a[39:32] : 8'h00) |
				(c1[5] ? a[47:40] : 8'h00) |
				(c1[6] ? a[55:48] : 8'h00) |
				(c1[7] ? a[63:56] : 8'h00) |
				b[7:0];
			Qupls4_pkg::FN_REDEOR:		ro8 =
				(c1[0] ? a[7:0] : 8'h00) ^
				(c1[1] ? a[15:8] : 8'h00) ^
				(c1[2] ? a[23:16] : 8'h00) ^
				(c1[3] ? a[31:24] : 8'h00) ^
				(c1[4] ? a[39:32] : 8'h00) ^
				(c1[5] ? a[47:40] : 8'h00) ^
				(c1[6] ? a[55:48] : 8'h00) ^
				(c1[7] ? a[63:56] : 8'h00) ^
				b[7:0];
			Qupls4_pkg::FN_REDMAXU:	ro8 = 
				tmaxu8(tmaxu8(
					c1[0] ? a[7:0] : 8'h00,c1[1] ? a[15:8] : 8'h00, c1[2] ? a[23:16] : 8'h00),
					tmaxu8(c1[3] ? a[31:24] : 8'h00, c1[4] ? a[39:32] : 8'h00, c1[5] ? a[47:40] : 8'h00),
					tmaxu8(c1[6] ? a[55:48] : 8'h00, c1[7] ? a[63:56] : 8'h00,b[7:0]));
			Qupls4_pkg::FN_REDMINU:	ro8 = 
				tminu8(tminu8(c1[0] ? a[7:0] : 8'hFF,c1[1] ? a[15:8] : 8'hFF,c1[2] ? a[23:16] : 8'hFF),
				tminu8(c1[3] ? a[31:24] : 8'hFF, c1[4] ? a[39:32] : 8'hFF, c1[5] ? a[47:40] : 8'hFF),
				tminu8(c1[6] ? a[55:48] : 8'hFF, c1[7] ? a[63:56] : 8'hFF,b[7:0]));
			Qupls4_pkg::FN_REDMAX:	ro8 = 
				tmax8(tmax8(
					c1[0] ? a[7:0] : 8'h00,c1[1] ? a[15:8] : 8'h00, c1[2] ? a[23:16] : 8'h00),
					tmax8(c1[3] ? a[31:24] : 8'h00, c1[4] ? a[39:32] : 8'h00, c1[5] ? a[47:40] : 8'h00),
					tmax8(c1[6] ? a[55:48] : 8'h00, c1[7] ? a[63:56] : 8'h00,b[7:0]));
			Qupls4_pkg::FN_REDMIN:	ro8 = 
				tmin8(tmin8(c1[0] ? a[7:0] : 8'h7F,c1[1] ? a[15:8] : 8'h7F,c1[2] ? a[23:16] : 8'h7F),
				tmin8(c1[3] ? a[31:24] : 8'h7F, c1[4] ? a[39:32] : 8'h7F, c1[5] ? a[47:40] : 8'h7F),
				tmin8(c1[6] ? a[55:48] : 8'h7F, c1[7] ? a[63:56] : 8'h7F,b[7:0]));
			default:	ro8 = zero;
			endcase
			end
		endcase
	end
end
endgenerate

generate begin : g16
reg [WID-1:0] c1;
	if (Qupls4_pkg::SUPPORT_PREC)
	for (g = 0; g < WID/16; g = g + 1)
		Qupls4_sau #(.WID(16), .SAU0(SAU0), .LANE(g)) ualu16
		(
			.rst(rst),
			.clk(clk),
			.chunk(chunk),
			.mask(c),
			.om(rse_i.om),
			.ir(ir),
			.a(a[g*16+15:g*16]),
			.b(b[g*16+15:g*16]),
			.bi(bi[g*16+15:g*16]),
			.c(c[g*16+15:g*16]),
			.i(i),
			.t(t[g*16+15:g*16]),
			.qres(qres[g*16+15:g*16]),
			.cs(cs),
			.pc(pc),
			.csr(csr),
			.cpl(cpl),
			.canary(canary),
			.o(o16[g*16+15:g*16]),
			.exc_o(exc16[g*8+7:g*8])
		);
	always_comb
	begin
		c1 = zero;
		case(ir.any.opcode)
		Qupls4_pkg::OP_R3W:
			begin
			c1 = c >> {lane,2'd0};
			case(ir.r3.func)
			Qupls4_pkg::FN_REDSUM:	ro16 =
				(c1[0] ? a[15:0] : 16'h00) +
				(c1[1] ? a[31:16] : 16'h00) +
				(c1[2] ? a[47:32] : 16'h00) +
				(c1[3] ? a[63:48] : 16'h00) +
				b[15:0];
			Qupls4_pkg::FN_REDAND:	ro16 = 
				(c1[0] ? a[15:0] : 16'hFFFF) &
				(c1[1] ? a[31:16] : 16'hFFFF) &
				(c1[2] ? a[47:32] : 16'hFFFF) &
				(c1[3] ? a[63:48] : 16'hFFFF) &
				b[15:0];
			Qupls4_pkg::FN_REDOR:		ro16 =
				(c1[0] ? a[15:0] : 16'h00) |
				(c1[1] ? a[31:16] : 16'h00) |
				(c1[2] ? a[47:32] : 16'h00) |
				(c1[3] ? a[63:48] : 16'h00) |
				b[15:0];
			Qupls4_pkg::FN_REDEOR:		ro16 =
				(c1[0] ? a[15:0] : 16'h00) ^
				(c1[1] ? a[31:16] : 16'h00) ^
				(c1[2] ? a[47:32] : 16'h00) ^
				(c1[3] ? a[63:48] : 16'h00) ^
				b[15:0];
			Qupls4_pkg::FN_REDMAXU:	ro16 = 
				tmaxu16(tmaxu16(c1[0] ? a[15:0] : 16'h0000,c1[1] ? a[31:16] : 16'h0000, c1[2] ? a[47:32] : 16'h0000),
					c1[3] ? a[63:48] : 16'h0000,b[15:0]);
			Qupls4_pkg::FN_REDMINU:	ro16 = 
				tminu16(tminu16(c1[0] ? a[15:0] : 16'hFFFF, c1[1] ? a[31:16] : 16'hFFFF, c1[2] ? a[47:32] : 16'hFFFF),
					c1[3] ? a[63:48] : 16'hFFFF,b[15:0]);
			Qupls4_pkg::FN_REDMAX:	ro16 = 
				tmax16(tmax16(c1[0] ? a[15:0] : 16'h0, c1[1] ? a[31:16] : 16'h0, c1[2] ? a[47:32]: 16'h0),
					c1[3] ? a[63:48] : 16'h0,b[15:0]);
			Qupls4_pkg::FN_REDMIN:	ro16 = 
				tmin16(tmin16(c1[0] ? a[15:0] : 16'h7FFF, c1[1] ? a[31:16] : 16'h7FFF, c1[2] ? a[47:32] : 16'h7FFF),
					c1[3] ? a[63:48] : 16'h7FFF,b[15:0]);
			default:	ro16 = zero;
			endcase
			end
		endcase
		end
	end
endgenerate

generate begin : g32
reg [WID-1:0] c1;
	if (Qupls4_pkg::SUPPORT_PREC)
	for (g = 0; g < WID/32; g = g + 1)
		Qupls4_sau #(.WID(32), .SAU0(SAU0), .LANE(g)) usau32
		(
			.rst(rst),
			.clk(clk),
			.chunk(chunk),
			.mask(c),
			.om(rse_i.om),
			.ir(ir),
			.a(a[g*32+31:g*32]),
			.b(b[g*32+31:g*32]),
			.bi(bi[g*32+31:g*32]),
			.c(c[g*32+31:g*32]),
			.i(i),
			.t(t[g*32+31:g*32]),
			.qres(qres[g*32+31:g*32]),
			.cs(cs),
			.pc(pc),
			.csr(csr),
			.cpl(cpl),
			.canary(canary),
			.o(o32[g*32+31:g*32]),
			.exc_o(exc32[g*8+7:g*8])
		);
	always_comb
	begin
		c1 = zero;
		case(ir.any.opcode)
		Qupls4_pkg::OP_R3T:
			begin
			c1 = c >> {lane,1'b0};
			case(ir.r3.func)
			Qupls4_pkg::FN_REDSUM:
				case(ir.r3.op3)
				3'd0:	ro32 = (c1[0] ? a[31:0] : 32'd0)+ (c1[1] ? a[63:32] : 32'd0) + b[31:0];
				3'd1:	ro32 = (c1[0] ? {{32{a[31]}},a[31:0]} : 64'd0)+(c1[1] ? {{32{a[63]}},a[63:32]} : 64'd0) + {{32{b[31]}},b[31:0]};
				3'd2:	ro32 = (c1[0] ? {32'd0,a[31:0]} : 64'd0)+(c1[1] ? {32'd0,a[63:32]} : 64'd0) + {32'd0,b[31:0]};
				default:	ro32 = zero;
				endcase
			Qupls4_pkg::FN_REDAND:	ro32 = (c1[0] ? a[31:0] : 32'hFFFFFFFF) & (c1[1] ? a[63:32] : 32'hFFFFFFFF) & b[31:0];
			Qupls4_pkg::FN_REDOR:		ro32 = (c1[0] ? a[31:0] : 32'd0)|(c1[1] ?a[63:32] : 32'd0)|b[31:0];
			Qupls4_pkg::FN_REDEOR:	ro32 = (c1[0] ? a[31:0] : 32'd0)^(c1[1] ?a[63:32] : 32'd0)^b[31:0];
			Qupls4_pkg::FN_REDMAXU:	ro32 = tmaxu32(c1[0] ? a[31:0] : 32'd0,c1[1] ? a[63:32] : 32'd0,b[31:0]);
			Qupls4_pkg::FN_REDMINU:	ro32 = tminu32(c1[0] ? a[31:0] : 32'hFFFFFFFF,c1[1] ? a[63:32]: 32'hFFFFFFFF,b[31:0]);
			Qupls4_pkg::FN_REDMAX:	ro32 = tmax32(c1[0] ? a[31:0] : 32'd0,c1[1] ? a[63:32] : 32'd0,b[31:0]);
			Qupls4_pkg::FN_REDMIN:	ro32 = tmin32(c1[0] ? a[31:0] : 32'h7FFFFFFF,c1[1] ? a[63:32]: 32'h7FFFFFFF,b[31:0]);
			default:	ro32 = zero;
			endcase
			end
		endcase
		end
	end
endgenerate

generate begin : g64
reg [WID-1:0] c1;
	if (Qupls4_pkg::SUPPORT_PREC || WID==64)
	for (g = 0; g < WID/64; g = g + 1)
		Qupls4_sau #(.WID(64), .SAU0(SAU0), .LANE(g)) usau64
		(
			.rst(rst),
			.clk(clk),
			.chunk(chunk),
			.mask(c),
			.om(rse_i.om),
			.ir(ir),
			.a(a[g*64+63:g*64]),
			.b(b[g*64+63:g*64]),
			.bi(bi[g*64+63:g*64]),
			.c(c[g*64+63:g*64]),
			.i(i),
			.t(t[g*64+63:g*64]),
			.qres(qres[g*64+63:g*64]),
			.cs(cs),
			.pc(pc),
			.csr(csr),
			.cpl(cpl),
			.canary(canary),
			.o(o64[g*64+63:g*64]),
			.exc_o(exc64[g*8+7:g*8])
		);
	always_comb
	begin
		c1 = zero;
		case(ir.any.opcode)
		Qupls4_pkg::OP_R3T:
			begin
			c1 = c >> lane;
			case(ir.r3.func)
			Qupls4_pkg::FN_REDSUM:
				case(ir.r3.op3)
				3'd0:	ro64 = (c1[0] ? a[63:0] : 64'd0) + b[63:0];
				3'd1:	ro64 = (c1[0] ? a[63:0] : 64'd0) + b[63:0];
				3'd2:	ro64 = (c1[0] ? a[63:0] : 64'd0) + b[63:0];
				default:	ro64 = zero;
				endcase
			Qupls4_pkg::FN_REDAND:	ro64 = (c1[0] ? a[63:0] : 64'hFFFFFFFFFFFFFFFF) & b[63:0];
			Qupls4_pkg::FN_REDOR:		ro64 = (c1[0] ? a[63:0] : 64'd0)|b[63:0];
			Qupls4_pkg::FN_REDEOR:	ro64 = (c1[0] ? a[63:0] : 64'd0)^b[63:0];
			Qupls4_pkg::FN_REDMAXU:	ro64 = tmaxu32(c1[0] ? a[63:0] : 64'd0,b[63:0],b[63:0]);
			Qupls4_pkg::FN_REDMINU:	ro64 = tminu32(c1[0] ? a[63:0] : 64'hFFFFFFFFFFFFFFFF,b[63:0],b[63:0]);
			Qupls4_pkg::FN_REDMAX:	ro64 = tmax32(c1[0] ? a[63:0] : 64'd0,c1[1] ? a[63:32] : 64'd0, b[63:0]);
			Qupls4_pkg::FN_REDMIN:	ro64 = tmin32(c1[0] ? a[63:0] : 64'h7FFFFFFFFFFFFFFF,c1[1] ? a[63:0]: 64'h7FFFFFFFFFFFFFFF,b[63:0]);
			default:	ro64 = zero;
			endcase
			end
		endcase
		end
	end
endgenerate

// Always supported.
generate begin : g128
	if (WID==128)
	for (g = 0; g < WID/128; g = g + 1)
		Qupls4_sau #(.WID(128), .SAU0(SAU0), .LANE(g)) usau128
		(
			.rst(rst),
			.clk(clk),
			.chunk(chunk),
			.mask(c),
			.om(rse_i.om),
			.ir(ir),
			.a(a[g*128+127:g*128]),
			.b(b[g*128+127:g*128]),
			.bi(bi[g*128+127:g*128]),
			.c(c[g*128+127:g*128]),
			.i(i),
			.t(t[g*128+127:g*128]),
			.qres(qres[g*128+127:g*128]),
			.cs(cs),
			.pc(pc),
			.csr(csr),
			.cpl(cpl),
			.canary(canary),
			.o(o128[g*128+127:g*128]),
			.exc_o(exc128[g*8+7:g*8])
		);
end
endgenerate

always_comb
begin
	if (Qupls4_pkg::SUPPORT_PREC) begin
		case({isflt,issimd})
		2'b00:
			case(prc)
			Qupls4_pkg::byt:		begin o1 = {56'd0,o8[ 7: 0]}; exc1 = exc8; end
			Qupls4_pkg::wyde:		begin o1 = {48'd0,o16[15:0]}; exc1 = exc16; end
			Qupls4_pkg::tetra:	begin o1 = {32'd0,o32[31:0]}; exc1 = exc32; end
			Qupls4_pkg::octa:		begin o1 = o64; exc1 = exc64; end
			default:	begin o1 = o128; exc1 = exc128; end
			endcase
		2'b01:
			case(prc)
			Qupls4_pkg::byt:		begin o1 = o8|ro8; exc1 = exc8; end
			Qupls4_pkg::wyde:	begin o1 = o16|ro16; exc1 = exc16; end
			Qupls4_pkg::tetra:		begin o1 = o32|ro32; exc1 = exc32; end
			Qupls4_pkg::octa:		begin o1 = o64; exc1 = exc64; end
			default:	begin o1 = o128; exc1 = exc128; end
			endcase
		2'b10:
			case(prc)
			Qupls4_pkg::wyde:		begin o1 = {48'd0,o16[15:0]}; exc1 = exc16; end
			Qupls4_pkg::tetra:	begin o1 = {32'd0,o32[31:0]}; exc1 = exc32; end
			Qupls4_pkg::octa:		begin o1 = o64; exc1 = exc64; end
			Qupls4_pkg::hexi:		begin o1 = o128; exc1 = exc128; end
			default:	begin o1 = o128; exc1 = exc128; end
			endcase
		2'b11:
			case(prc)
			Qupls4_pkg::wyde:		begin o1 = o16; exc1 = exc16; end
			Qupls4_pkg::tetra:	begin o1 = o32; exc1 = exc32; end
			Qupls4_pkg::octa:		begin o1 = o64; exc1 = exc64; end
			Qupls4_pkg::hexi:		begin o1 = o128; exc1 = exc128; end
			default:	begin o1 = o128; exc1 = exc128; end
			endcase
		endcase
	end
	else begin
		if (WID==64) begin
			o1 = o64;
			exc1 = exc64;
		end
		else begin
			o1 = o128;
			exc1 = exc128;
		end
	end
end

// Copy only the lanes specified in the mask to the target.
always_ff @(posedge clk)
begin
	t1 <= t;
end
always_ff @(posedge clk)
	z1 <= z;
always_ff @(posedge clk)
	cptgt1 <= cptgt;

delay1 #(.WID($bits(checkpt_ndx_t))) udly3 (.clk(clk), .ce(1'b1), .i(cp_i), .o(cp_o));
delay1 #(.WID($bits(Qupls4_pkg::reservation_station_entry_t))) udly4 (.clk(clk), .ce(1'b1), .i(rse_i), .o(rse_o));
delay1 #(.WID($bits(Qupls4_pkg::rob_bitmask_t))) udly5 (.clk(clk), .ce(1'b1), .i(stomp), .o(stompo));

always_ff @(posedge clk)
	if (~rse_i.v)
		we_o <= 9'h000;
	else if (aRd_i >= 8'd56 && aRd_i <= 8'd63)
		case(rse_i.om)
		Qupls4_pkg::OM_APP:				we_o <= 9'h001;
		Qupls4_pkg::OM_SUPERVISOR:	we_o <= 9'h003;
		Qupls4_pkg::OM_HYPERVISOR:	we_o <= 9'h007;
		Qupls4_pkg::OM_SECURE:			we_o <= 9'h1FF;
		endcase
	else if (|aRd_i)
		we_o <= 9'h1FF;
	else
		we_o <= 9'h000;

generate begin : gCptgt
	for (mm = 0; mm < WID/8; mm = mm + 1) begin
    always_comb
    begin
    	if (stompo[rse_o.rndx])
    		o[mm*8+7:mm*8] = t1[mm*8+7:mm*8];
      else if (cptgt1[mm])
        o[mm*8+7:mm*8] = z1 ? 8'h00 : t1[mm*8+7:mm*8];
      else
        o[mm*8+7:mm*8] = o1[mm*8+7:mm*8];
    end
  end
end
endgenerate

// Exceptions are squashed for lanes that are not supposed to modify the target.

generate begin : gExc
	for (xx = 0; xx < WID/8; xx = xx + 1)
    always_comb
      if (cptgt[xx])
        exc[xx*8+7:xx*8] = Qupls4_pkg::FLT_NONE;
      else
        exc[xx*8+7:xx*8] = exc1[xx*8+7:xx*8];
end
endgenerate

endmodule
