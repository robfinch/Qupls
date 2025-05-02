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

module Stark_meta_fma(rst, clk, idle, stomp, rse_i, rse_o, z, cptgt, o, otag, we_o, done, exc);
parameter WID=Stark_pkg::SUPPORT_QUAD_PRECISION||Stark_pkg::SUPPORT_CAPABILITIES ? 128 : 64;
parameter LATENCY = 8;
input rst;
input clk;
input idle;
input Stark_pkg::rob_bitmask_t stomp;
input Stark_pkg::reservation_station_entry_t rse_i;
output Stark_pkg::reservation_station_entry_t rse_o;
input z;
input [WID-1:0] cptgt;
output reg [WID-1:0] o;
output reg otag;
output reg [WID/8:0] we_o;
output reg done;
output Stark_pkg::cause_code_t exc;

integer n1,n2;
wire ce = 1'b1;
Stark_pkg::reservation_station_entry_t [LATENCY-2:0] rse;
reg [LATENCY-1:0] stomp_con;
Stark_pkg::operating_mode_t om;
reg [1:0] prc;
Stark_pkg::instruction_t ir;
reg [WID-1:0] a;
reg [WID-1:0] b;
reg [WID-1:0] c;
reg [WID-1:0] t;
reg [WID-1:0] i;
always_comb om = rse_i.om;
always_comb ir = rse_i.ins;
always_comb a = rse_i.argA;
always_comb b = rse_i.argB;
always_comb c = rse_i.argC;
always_comb t = rse_i.argD;
always_comb i = rse_i.argI;

always_comb
begin
	if (WID != 64 && WID != 128) begin
		$display("StarkCPU: FMA width must be either 64 or 128");
	end
	if (LATENCY < 2) begin
		$display("StarkCPU: FMA latency must be at least 2");
		$finish;
	end
end

Stark_pkg::cause_code_t exc128,exc64;
reg [WID-1:0] o1;
wire [WID-1:0] o16, o32, o64, o128;
wire [7:0] sr64, sr128;
wire done16, done32, done64, done128;
genvar g,mm;

generate begin : gPrec
if (Stark_pkg::SUPPORT_PREC) begin
for (g = 0; g < WID/16; g = g + 1)
	fpFMA16nrL8 ufma16 (
		.clk(clk),
		.ce(ce),
		.op(ir[30]),		// 0=add,1=sub c
		.rm(rse_i.rm),
		.a(a[g*16+15:g*16]),
		.b(b[g*16+15:g*16]),
		.c(c[g*16+15:g*16]),
		.o(o16[g*16+15:g*16]),
		.inf(),
		.zero(), 
		.overflow(),
		.underflow(),
		.inexact()
	);
for (g = 0; g < WID/32; g = g + 1)
	fpFMA32nrL8 ufma32 (
		.clk(clk),
		.ce(ce),
		.op(ir[30]),		// 0=add,1=sub c
		.rm(rse_i.rm),
		.a(a[g*32+31:g*32]),
		.b(b[g*32+31:g*32]),
		.c(c[g*32+31:g*32]),
		.o(o32[g*32+31:g*32]),
		.inf(),
		.zero(), 
		.overflow(),
		.underflow(),
		.inexact()
	);
for (g = 0; g < WID/64; g = g + 1)
	fpFMA64nrL8 ufma64 (
		.clk(clk),
		.ce(ce),
		.op(ir[30]),		// 0=add,1=sub c
		.rm(rse_i.rm),
		.a(a[g*64+63:g*64]),
		.b(b[g*64+63:g*64]),
		.c(c[g*64+63:g*64]),
		.o(o64[g*64+63:g*64]),
		.inf(),
		.zero(), 
		.overflow(),
		.underflow(),
		.inexact()
	);
end
if (Stark_pkg::SUPPORT_QUAD_PRECISION||Stark_pkg::SUPPORT_CAPABILITIES)
	fpFMA128nrL8 ufma128 (
		.clk(clk),
		.ce(1'b1),
		.op(ir[30]),		// 0=add,1=sub c
		.rm(rse_i.rm),
		.a(a),
		.b(b),
		.c(c),
		.o(o128),
		.inf(),
		.zero(), 
		.overflow(),
		.underflow(),
		.inexact()
	);
	
end
if (Stark_pkg::NFPU > 0 && !(Stark_pkg::SUPPORT_QUAD_PRECISION|Stark_pkg::SUPPORT_CAPABILITIES))
    for (g = 0; g < WID/64; g = g + 1)
	fpFMA64nrL8 ufma64 (
		.clk(clk),
		.ce(1'b1),
		.op(ir[30]),		// 0=add,1=sub c
		.rm(rse_i.rm),
		.a(a[g*64+63:g*64]),
		.b(b[g*64+63:g*64]),
		.c(c[g*64+63:g*64]),
		.o(o64[g*64+63:g*64]),
		.inf(),
		.zero(), 
		.overflow(),
		.underflow(),
		.inexact()
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
      if (cptgt[mm])
        o[mm*8+7:mm*8] = z ? 8'h00 : t[mm*8+7:mm*8];
      else
        o[mm*8+7:mm*8] = o1[mm*8+7:mm*8];
  end
end
endgenerate

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

always_ff @(posedge clk)
begin
	rse[0] <= rse_i;
	for (n1 = 1; n1 < 7; n1 = n1 + 1)
		rse[n1] <= rse[n1-1];
	rse_o <= rse[6];
end

always_ff @(posedge clk)
begin
	if (rse_i.aRd==8'h00 || !rse_i.v || stomp[rse_i.rndx])
		stomp_con[0] = TRUE;
	else
		stomp_con[0] = FALSE;
	for (n2 = 1; n2 < 8; n2 = n2 + 1) begin
		if (stomp[rse[n2].rndx])
			stomp_con[n2] = TRUE;
		else
			stomp_con[n2] = stomp_con[n2-1];
	end
end		

always_comb
	we_o = stomp_con[7] ? 9'h000 : 9'h1FF;

endmodule
