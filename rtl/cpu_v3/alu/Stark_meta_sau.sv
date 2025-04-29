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
// 15300 LUTs / 570 FFs / 56 DSPs (64-bit)
// 5800 LUTs / 360 FFs / 32 DSPs (64-bit, no precision support)
// 6600 LUTs / 400 FFs / 32 DSPs (64-bit, no precision support - with caps.)
// ============================================================================

import const_pkg::*;
import Stark_pkg::*;

module Stark_meta_sau(rst, clk, om, lane, prc, ir, cptgt, z, a, b, bi,
	c, i, t, qres, cs, pc, csr, cpl, canary, o, 
	cp_i, cp_o, pRd_i, pRd_o, aRd_i, aRd_o, we_o, exc);
parameter SAU0 = 1'b0;
parameter WID=$bits(cpu_types_pkg::value_t); 
input rst;
input clk;
input Stark_pkg::operating_mode_t om;
input [2:0] lane;
input memsz_t prc;
input instruction_t ir;
input [7:0] cptgt;
input z;
input [WID-1:0] a;
input [WID-1:0] b;
input [WID-1:0] bi;
input [WID-1:0] c;
input [WID-1:0] i;
input [WID-1:0] t;
input [WID-1:0] qres;
input [2:0] cs;
input cpu_types_pkg::pc_address_t pc;
input [7:0] cpl;
input [WID-1:0] canary;
input [WID-1:0] csr;
output reg [WID-1:0] o;
input checkpt_ndx_t cp_i;
output checkpt_ndx_t cp_o;
input pregno_t pRd_i;
output pregno_t pRd_o;
input aregno_t aRd_i;
output aregno_t aRd_o;
output reg [WID/8:0] we_o;			// extra bit for tag update
output reg [WID-1:0] exc;

reg [WID-1:0] t1;
reg z1;
reg [7:0] cptgt1;
wire [WID-1:0] o16,o32,o64,o128;
wire o64_tag, o128_tag;
reg [WID-1:0] o1;
reg o1_tag;
wire [WID-1:0] exc16,exc32,exc64,exc128;
reg [WID-1:0] exc1;
integer n;
genvar g,mm,xx;

generate begin : g16
	if (Stark_pkg::SUPPORT_PREC)
	for (g = 0; g < WID/16; g = g + 1)
		Stark_sau #(.WID(16), .SAU0(SAU0)) ualu16
		(
			.rst(rst),
			.clk(clk),
			.om(om),
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
end
endgenerate

generate begin : g32
	if (Stark_pkg::SUPPORT_PREC)
	for (g = 0; g < WID/32; g = g + 1)
		Stark_sau #(.WID(32), .SAU0(SAU0)) usau32
		(
			.rst(rst),
			.clk(clk),
			.om(om),
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
end
endgenerate

generate begin : g64
	if (Stark_pkg::SUPPORT_PREC || WID==64)
	for (g = 0; g < WID/64; g = g + 1)
		Stark_sau #(.WID(64), .SAU0(SAU0)) usau64
		(
			.rst(rst),
			.clk(clk),
			.om(om),
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
end
endgenerate

// Always supported.
generate begin : g128
	if (WID==128)
	for (g = 0; g < WID/128; g = g + 1)
		Stark_sau #(.WID(128), .SAU0(SAU0)) usau128
		(
			.rst(rst),
			.clk(clk),
			.om(om),
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
	if (Stark_pkg::SUPPORT_PREC)
		case(prc)
		Stark_pkg::wyde:		begin o1 = o16; end
		Stark_pkg::tetra:	begin o1 = o32; end
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

delay1 #(.WID($bits(pregno_t)) udly1 (.clk(clk), .ce(1'b1), .i(pRd_i), .o(pRd_o));
delay1 #(.WID($bits(aregno_t)) udly2 (.clk(clk), .ce(1'b1), .i(aRd_i), .o(aRd_o));
delay1 #(.WID($bits(checkpt_ndx_t)) udly2 (.clk(clk), .ce(1'b1), .i(cp_i), .o(cp_o));

always_ff @(posedge clk)
	if (aRd_i >= 8'd56 && aRdi_i <= 8'd63)
		case(om)
		OM_USER:				we_o <= 9'h001;
		OM_SUPERVISOR:	we_o <= 9'h003;
		OM_HYPERVISOR:	we_o <= 9'h007;
		OM_SECURE:			we_o <= 9'h1FF;
		endcase
	else if (|aRd_i)
		we_o <= 9'h1FF;
	else
		we_o <= 9'h000;

generate begin : gCptgt
	for (mm = 0; mm < WID/8; mm = mm + 1) begin
    always_comb
    begin
      if (cptgt1[mm])
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
		Stark_pkg::wyde:		exc1 = exc16;
		Stark_pkg::tetra:		exc1 = exc32;
		Stark_pkg::octa:		exc1 = exc64;
		Stark_pkg::hexi:		exc1 = exc128;
		default:exc1 = exc64;
		endcase
	else
		exc1 = exc64;

// Exceptions are squashed for lanes that are not supposed to modify the target.

generate begin : gExc
	for (xx = 0; xx < WID/8; xx = xx + 1)
	    always_comb
            if (cptgt[xx])
                exc[xx*8+7:xx*8] = FLT_NONE;
            else
                exc[xx*8+7:xx*8] = exc1[xx*8+7:xx*8];
end
endgenerate

endmodule
