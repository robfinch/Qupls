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

module Stark_meta_sau(rst, clk, rse_i, rse_o, lane, cptgt, z, stomp,
	qres, cs, csr, cpl, canary, o, cp_o, we_o, exc);
parameter SAU0 = 1'b0;
parameter WID=$bits(cpu_types_pkg::value_t); 
input rst;
input clk;
input Stark_pkg::reservation_station_entry_t rse_i;
output Stark_pkg::reservation_station_entry_t rse_o;
input [2:0] lane;
input [7:0] cptgt;
input z;
input Stark_pkg::rob_bitmask_t stomp;
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
Stark_pkg::rob_bitmask_t stompo;
Stark_pkg::memsz_t prc;
cpu_types_pkg::pc_address_t pc;
checkpt_ndx_t cp_i;
aregno_t aRd_i;
Stark_pkg::instruction_t ir;
always_comb ir = rse_i.ins;
always_comb a = rse_i.argA;
always_comb b = rse_i.argB;
always_comb bi = rse_i.argB|rse_i.argI;
always_comb c = rse_i.argC;
always_comb t = rse_i.argD;
always_comb i = rse_i.argI;
always_comb pc = rse_i.pc;
always_comb cp_i = rse_i.cndx;
always_comb aRd_i = rse_i.aRd;
always_comb prc = Stark_pkg::memsz_t'(rse_i.prc);

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
end
endgenerate

generate begin : g32
	if (Stark_pkg::SUPPORT_PREC)
	for (g = 0; g < WID/32; g = g + 1)
		Stark_sau #(.WID(32), .SAU0(SAU0)) usau32
		(
			.rst(rst),
			.clk(clk),
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
end
endgenerate

generate begin : g64
	if (Stark_pkg::SUPPORT_PREC || WID==64)
	for (g = 0; g < WID/64; g = g + 1)
		Stark_sau #(.WID(64), .SAU0(SAU0)) usau64
		(
			.rst(rst),
			.clk(clk),
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

delay1 #(.WID($bits(checkpt_ndx_t))) udly3 (.clk(clk), .ce(1'b1), .i(cp_i), .o(cp_o));
delay1 #(.WID($bits(Stark_pkg::reservation_station_entry_t))) udly4 (.clk(clk), .ce(1'b1), .i(rse_i), .o(rse_o));
delay1 #(.WID($bits(Stark_pkg::rob_bitmask_t))) udly5 (.clk(clk), .ce(1'b1), .i(stomp), .o(stompo));

always_ff @(posedge clk)
	if (~rse_i.v)
		we_o <= 9'h000;
	else if (aRd_i >= 8'd56 && aRd_i <= 8'd63)
		case(rse_i.om)
		Stark_pkg::OM_APP:				we_o <= 9'h001;
		Stark_pkg::OM_SUPERVISOR:	we_o <= 9'h003;
		Stark_pkg::OM_HYPERVISOR:	we_o <= 9'h007;
		Stark_pkg::OM_SECURE:			we_o <= 9'h1FF;
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
        exc[xx*8+7:xx*8] = Stark_pkg::FLT_NONE;
      else
        exc[xx*8+7:xx*8] = exc1[xx*8+7:xx*8];
end
endgenerate

endmodule
