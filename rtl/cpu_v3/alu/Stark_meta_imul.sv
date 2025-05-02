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

module Stark_meta_imul(rst, clk, stomp, rse_i, rse_o, lane, cptgt, z, o, we_o, mul_done);
parameter WID=$bits(cpu_types_pkg::value_t); 
input rst;
input clk;
input Stark_pkg::rob_bitmask_t stomp;
input Stark_pkg::reservation_station_entry_t rse_i;
output Stark_pkg::reservation_station_entry_t rse_o;
input [2:0] lane;
input [7:0] cptgt;
input z;
output reg [WID-1:0] o;
output reg [WID/8:0] we_o;
output reg mul_done;

Stark_pkg::reservation_station_entry_t rse1,rse2,rse3;
Stark_pkg::memsz_t prc;
Stark_pkg::instruction_t ir;
reg [WID-1:0] a;
reg [WID-1:0] b;
reg [WID-1:0] bi;
reg [WID-1:0] c;
reg [WID-1:0] i;
reg [WID-1:0] t;
aregno_t aRd_i;
always_comb prc = rse_i.prc;
always_comb ir = rse_i.ins;
always_comb a = rse_i.argA;
always_comb b = rse_i.argB;
always_comb c = rse_i.argC;
always_comb t = rse_i.argD;
always_comb bi = rse_i.argB|rse_i.argI;
always_comb i = rse_i.argI;
always_comb aRd_i = rse_i.aRd;
reg [2:0] stomp_con;	// stomp conveyor
reg [WID/8:0] we,we1,we2,we3;
reg [WID-1:0] t1;
reg z1;
reg [7:0] cptgt1;
wire [WID-1:0] o16,o32,o64,o128;
wire o64_tag, o128_tag;
reg [WID-1:0] o1;
reg o1_tag;
wire [WID-1:0] exc16,exc32,exc64,exc128;
integer n;
genvar g,mm,xx;

generate begin : g16
	if (Stark_pkg::SUPPORT_PREC)
	for (g = 0; g < WID/16; g = g + 1)
		Stark_imul #(.WID(16)) uimul16
		(
			.rst(rst),
			.clk(clk),
			.ir(ir),
			.a(a[g*16+15:g*16]),
			.b(b[g*16+15:g*16]),
			.bi(bi[g*16+15:g*16]),
			.c(c[g*16+15:g*16]),
			.i(i),
			.t(t[g*16+15:g*16]),
			.o(o16[g*16+15:g*16]),
			.mul_done()
		);
end
endgenerate

generate begin : g32
	if (Stark_pkg::SUPPORT_PREC)
	for (g = 0; g < WID/32; g = g + 1)
		Stark_imul #(.WID(32)) uimul32
		(
			.rst(rst),
			.clk(clk),
			.ir(ir),
			.a(a[g*32+31:g*32]),
			.b(b[g*32+31:g*32]),
			.bi(bi[g*32+31:g*32]),
			.c(c[g*32+31:g*32]),
			.i(i),
			.t(t[g*32+31:g*32]),
			.o(o32[g*32+31:g*32]),
			.mul_done()
		);
end
endgenerate

generate begin : g64
	if (Stark_pkg::SUPPORT_PREC || WID==64)
	for (g = 0; g < WID/64; g = g + 1)
		Stark_imul #(.WID(64)) uimul64
		(
			.rst(rst),
			.clk(clk),
			.ir(ir),
			.a(a[g*64+63:g*64]),
			.b(b[g*64+63:g*64]),
			.bi(bi[g*64+63:g*64]),
			.c(c[g*64+63:g*64]),
			.i(i),
			.t(t[g*64+63:g*64]),
			.o(o64[g*64+63:g*64]),
			.mul_done()
		);
end
endgenerate

// Always supported.
generate begin : g128
	if (WID==128)
	for (g = 0; g < WID/128; g = g + 1)
		Stark_imul #(.WID(128)) uimul128
		(
			.rst(rst),
			.clk(clk),
			.ir(ir),
			.a(a[g*128+127:g*128]),
			.b(b[g*128+127:g*128]),
			.bi(bi[g*128+127:g*128]),
			.c(c[g*128+127:g*128]),
			.i(i),
			.t(t[g*128+127:g*128]),
			.o(o128[g*128+127:g*128]),
			.mul_done()
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
delay3 #(.WID(WID)) udly1 (.clk(clk), .ce(1'b1), .i(t), .o(t1));
delay3 #(.WID(1)) udly2 (.clk(clk), .ce(1'b1), .i(z), .o(z1));
delay3 #(.WID(WID/8)) udly3 (.clk(clk), .ce(1'b1), .i(cptgt), .o(cptgt1));
delay3 #(.WID($bits(pregno_t))) udly4 (.clk(clk), .ce(1'b1), .i(pRd_i), .o(pRd_o));
delay3 #(.WID($bits(aregno_t))) udly5 (.clk(clk), .ce(1'b1), .i(aRd_i), .o(aRd_o));
delay3 #(.WID(WID/8+1)) udly6 (.clk(clk), .ce(1'b1), .i(we), .o(we3));
delay3 #(.WID($bits(checkpt_ndx_t))) udly7 (.clk(clk), .ce(1'b1), .i(cp_i), .o(cp_o));

always_ff @(posedge clk)
	rse1 <= rse_i;
always_ff @(posedge clk)
	rse2 <= rse1;
always_ff @(posedge clk)
	rse3 <= rse2;

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
	if (stomp[rse2.rndx])
		stomp_con[2] <= 1'b1;
	else
		stomp_con[2] <= stomp_con[1];
end

always_comb
	we_o = stomp_con[2] ? 9'h000 : we3;

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

endmodule
