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
// 41000 LUTs / 2000 FFs / 239 DSPs	-	ALU0 (128-bit)
// 15300 LUTs / 570 FFs / 56 DSPs (64-bit)
// 5800 LUTs / 360 FFs / 32 DSPs (64-bit, no precision support)
// 6600 LUTs / 400 FFs / 32 DSPs (64-bit, no precision support - with caps.)
// ============================================================================

import const_pkg::*;
import Stark_pkg::*;

module Stark_meta_idiv(rst, clk, clk2x, stomp, rse_i, rse_o, ld, lane, prc, ir, div,
	cptgt, z, qres, o, we_o, div_done, div_dbz, exc);
parameter ALU0 = 1'b0;
parameter WID=$bits(cpu_types_pkg::value_t); 
input rst;
input clk;
input clk2x;
input Stark_pkg::rob_bitmask_t stomp;
input Stark_pkg::reservation_station_entry_t rse_i;
output Stark_pkg::reservation_station_entry_t rse_o;
input ld;
input [2:0] lane;
input Stark_pkg::memsz_t prc;
input Stark_pkg::instruction_t ir;
input div;
input [7:0] cptgt;
input z;
input [WID-1:0] qres;
output reg [WID-1:0] o;
output [WID/8:0] we_o;
output reg div_done;
output div_dbz;
output reg [WID-1:0] exc;

Stark_pkg::operating_mode_t om;
reg [WID-1:0] a;
reg [WID-1:0] b;
reg [WID-1:0] bi;
reg [WID-1:0] c;
reg [WID-1:0] i;
reg [WID-1:0] t;
reg div_done1,div_done2;
aregno_t aRd_i;
always_comb om = rse_i.om;
always_comb a = rse_i.argA;
always_comb b = rse_i.argB;
always_comb bi = rse_i.argB|rse_i.argI;
always_comb c = rse_i.argC;
always_comb i = rse_i.argI;
always_comb t = rse_i.argD;
always_comb aRd_i = rse_i.aRd;

reg [WID/8:0] we;
reg [WID-1:0] t1;
reg z1;
reg [7:0] cptgt1;
wire [WID-1:0] o16,o32,o64,o128;
wire o64_tag, o128_tag;
reg [WID-1:0] o1;
reg o1_tag;
wire [WID-1:0] exc16,exc32,exc64,exc128;
reg [WID-1:0] exc1;
wire [WID/16-1:0] div_done16;
wire [WID/32-1:0] div_done32;
wire [WID/64-1:0] div_done64;
wire [WID/128-1:0] div_done128;
integer n;
genvar g,mm,xx;

generate begin : g16
	if (Stark_pkg::SUPPORT_PREC)
	for (g = 0; g < WID/16; g = g + 1)
		Stark_idiv #(.WID(16)) ualu16
		(
			.rst(rst),
			.clk(clk),
			.clk2x(clk2x),
			.om(om),
			.ld(ld),
			.ir(ir),
			.div(div),
			.a(a[g*16+15:g*16]),
			.b(b[g*16+15:g*16]),
			.bi(bi[g*16+15:g*16]),
			.c(c[g*16+15:g*16]),
			.i(i),
			.t(t[g*16+15:g*16]),
			.qres(qres[g*16+15:g*16]),
			.o(o16[g*16+15:g*16]),
			.div_done(div_done16[g]),
			.div_dbz(),
			.exc_o(exc16[g*8+7:g*8])
		);
end
endgenerate

generate begin : g32
	if (Stark_pkg::SUPPORT_PREC)
	for (g = 0; g < WID/32; g = g + 1)
		Stark_idiv #(.WID(32)) ualu32
		(
			.rst(rst),
			.clk(clk),
			.clk2x(clk2x),
			.ld(ld),
			.ir(ir),
			.div(div),
			.a(a[g*32+31:g*32]),
			.b(b[g*32+31:g*32]),
			.bi(bi[g*32+31:g*32]),
			.c(c[g*32+31:g*32]),
			.i(i),
			.t(t[g*32+31:g*32]),
			.o(o32[g*32+31:g*32]),
			.div_done(div_done32[g]),
			.div_dbz(),
			.exc_o(exc32[g*8+7:g*8])
		);
end
endgenerate

generate begin : g64
	if (Stark_pkg::SUPPORT_PREC || WID==64)
	for (g = 0; g < WID/64; g = g + 1)
		Stark_idiv #(.WID(64)) ualu64
		(
			.rst(rst),
			.clk(clk),
			.clk2x(clk2x),
			.ld(ld),
			.ir(ir),
			.div(div),
			.a(a[g*64+63:g*64]),
			.b(b[g*64+63:g*64]),
			.bi(bi[g*64+63:g*64]),
			.c(c[g*64+63:g*64]),
			.i(i),
			.t(t[g*64+63:g*64]),
			.o(o64[g*64+63:g*64]),
			.div_done(div_done64[g]),
			.div_dbz(),
			.exc_o(exc64[g*8+7:g*8])
		);
end
endgenerate

// Always supported.
generate begin : g128
	if (WID==128)
	for (g = 0; g < WID/128; g = g + 1)
		Stark_idiv #(.WID(128)) ualu128
		(
			.rst(rst),
			.clk(clk),
			.clk2x(clk2x),
			.ld(ld),
			.ir(ir),
			.div(div),
			.a(a[g*128+127:g*128]),
			.b(b[g*128+127:g*128]),
			.bi(bi[g*128+127:g*128]),
			.c(c[g*128+127:g*128]),
			.i(i),
			.t(t[g*128+127:g*128]),
			.o(o128[g*128+127:g*128]),
			.div_done(div_done128[g]),
			.div_dbz(),
			.exc_o(exc128[g*8+7:g*8])
		);
end
endgenerate

/*
Stark_alu #(.WID(128), .ALU0(ALU0)) ualu128
(
	.rst(rst),
	.clk(clk),
	.clk2x(clk2x),
	.ld(ld),
	.ir(ir),
	.div(div),
	.cptgt(cptgt[0]),
	.z(z),
	.a(a),
	.b(b),
	.bi(bi),
	.c(c),
	.i(i),
	.t(t),
	.cs(cs),
	.pc(pc),
	.csr(csr),
	.o(o128),
	.mul_done(),
	.div_done(),
	.div_dbz()
);
*/

always_comb
begin
	if (Stark_pkg::SUPPORT_PREC)
		case(prc)
		Stark_pkg::wyde:		begin o1 = o16; end
		Stark_pkg::tetra:		begin o1 = o32; end
		Stark_pkg::octa:		begin o1 = o64; end
		Stark_pkg::hexi:		begin o1 = o128; end
		default:	begin o1 = o128; end
		endcase
	else begin
		if (WID==64) begin
			o1 = o64;
		end
		else begin
			o1 = o128;
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
generate begin : gCptgt
	for (mm = 0; mm < WID/8; mm = mm + 1) begin
    always_comb
    begin
    	if (rse_o.ins.any.opcode==Stark_pkg::OP_NOP)
        o[mm*8+7:mm*8] = t1[mm*8+7:mm*8];
      else if (cptgt1[mm])
        o[mm*8+7:mm*8] = z1 ? 8'h00 : t1[mm*8+7:mm*8];
      else
        o[mm*8+7:mm*8] = o1[mm*8+7:mm*8];
    end
  end
end
endgenerate

always_comb
	if (Stark_pkg::SUPPORT_PREC)
		case(prc)
		Stark_pkg::wyde:		div_done1 = &div_done16;
		Stark_pkg::tetra:		div_done1 = &div_done32;
		Stark_pkg::octa:		div_done1 = &div_done64;
		Stark_pkg::hexi:		div_done1 = &div_done128;
		default:	div_done1 = &div_done128;
		endcase
	else
		div_done1 = &div_done64;

always_comb
	if (Stark_pkg::SUPPORT_PREC)
		case(prc)
		Stark_pkg::wyde:		exc1 = exc16;
		Stark_pkg::tetra:		exc1 = exc32;
		Stark_pkg::octa:		exc1 = exc64;
		Stark_pkg::hexi:		exc1 = exc128;
		default:	exc1 = exc64;
		endcase
	else
		exc1 = exc64;

// Exceptions are squashed for lanes that are not supposed to modify the target.

generate begin : gExc
	for (xx = 0; xx < WID/8; xx = xx + 1)
    always_comb
      if (cptgt[xx]||rse_o.ins.any.opcode==Stark_pkg::OP_NOP)
        exc[xx*8+7:xx*8] = Stark_pkg::FLT_NONE;
      else
        exc[xx*8+7:xx*8] = exc1[xx*8+7:xx*8];
end
endgenerate

assign div_dbz = |exc;

// div_done pulses for only a single cycle.
assign rse_o = div_done1 ? rse_i : {$bits(Stark_pkg::reservation_station_entry_t){1'b0}};

always_ff @(posedge clk)
if (rst)
	div_done2 <= TRUE;
else begin
	if (ld)
		div_done2 <= FALSE;
	else if (div_done1)
		div_done2 <= TRUE;
end

assign div_done = ld ? 1'b0 : div_done1 | div_done2;

always_ff @(posedge clk)
	if (aRd_i >= 8'd56 && aRd_i <= 8'd63)
		case(rse_i.om)
		Stark_pkg::OM_APP:				we <= 9'h001;
		Stark_pkg::OM_SUPERVISOR:	we <= 9'h003;
		Stark_pkg::OM_HYPERVISOR:	we <= 9'h007;
		Stark_pkg::OM_SECURE:			we <= 9'h1FF;
		endcase
	else if (|aRd_i)
		we <= 9'h1FF;
	else
		we <= 9'h000;

assign we_o = ld ? 9'd0 : div_done1 ? we : 9'd0;

endmodule
