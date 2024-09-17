// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2024  Robert Finch, Waterloo
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
import QuplsPkg::*;

module Qupls_meta_alu(rst, clk, clk2x, ld, lane, prc, ir, div, cptgt, z, a, b, bi,
	c, i, t, qres, cs, pc, csr, cpl, canary, o,
	mul_done, div_done, div_dbz, exc);
parameter ALU0 = 1'b0;
parameter WID=$bits(cpu_types_pkg::value_t); 
input rst;
input clk;
input clk2x;
input ld;
input [2:0] lane;
input memsz_t prc;
input instruction_t ir;
input div;
input [15:0] cptgt;
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
output reg mul_done;
output reg div_done;
output div_dbz;
output reg [WID-1:0] exc;

wire [WID-1:0] o16,o32,o64,o128;
wire o64_tag, o128_tag;
reg [WID-1:0] o1;
reg o1_tag;
wire [WID-1:0] exc16,exc32,exc64,exc128;
reg [WID-1:0] exc1;
wire [WID/16-1:0] div_done16;
wire [WID/16-1:0] mul_done16;
wire [WID/32-1:0] div_done32;
wire [WID/32-1:0] mul_done32;
wire [WID/64-1:0] div_done64;
wire [WID/64-1:0] mul_done64;
wire [WID/128-1:0] div_done128;
wire [WID/128-1:0] mul_done128;
integer n;
genvar g,mm,xx;

generate begin : g16
	if (SUPPORT_PREC)
	for (g = 0; g < WID/16; g = g + 1)
		Qupls_alu #(.WID(16), .ALU0(ALU0)) ualu16
		(
			.rst(rst),
			.clk(clk),
			.clk2x(clk2x),
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
			.cs(cs),
			.pc(pc),
			.csr(csr),
			.cpl(cpl),
			.canary(canary),
			.o(o16[g*16+15:g*16]),
			.mul_done(mul_done16[g]),
			.div_done(div_done16[g]),
			.div_dbz(),
			.exc_o(exc16[g*8+7:g*8])
		);
end
endgenerate

generate begin : g32
	if (SUPPORT_PREC)
	for (g = 0; g < WID/32; g = g + 1)
		Qupls_alu #(.WID(32), .ALU0(ALU0)) ualu32
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
			.qres(qres[g*32+31:g*32]),
			.cs(cs),
			.pc(pc),
			.csr(csr),
			.cpl(cpl),
			.canary(canary),
			.o(o32[g*32+31:g*32]),
			.mul_done(mul_done32[g]),
			.div_done(div_done32[g]),
			.div_dbz(),
			.exc_o(exc32[g*8+7:g*8])
		);
end
endgenerate

generate begin : g64
	if (SUPPORT_PREC || WID==64)
	for (g = 0; g < WID/64; g = g + 1)
		Qupls_alu #(.WID(64), .ALU0(ALU0)) ualu64
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
			.qres(qres[g*64+63:g*64]),
			.cs(cs),
			.pc(pc),
			.csr(csr),
			.cpl(cpl),
			.canary(canary),
			.o(o64[g*64+63:g*64]),
			.mul_done(mul_done64[g]),
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
		Qupls_alu #(.WID(128), .ALU0(ALU0)) ualu128
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
			.qres(qres[g*128+127:g*128]),
			.cs(cs),
			.pc(pc),
			.csr(csr),
			.cpl(cpl),
			.canary(canary),
			.o(o128[g*128+127:g*128]),
			.mul_done(mul_done128[g]),
			.div_done(div_done128[g]),
			.div_dbz(),
			.exc_o(exc128[g*8+7:g*8])
		);
end
endgenerate

/*
Qupls_alu #(.WID(128), .ALU0(ALU0)) ualu128
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
	if (SUPPORT_PREC)
		case(prc)
		QuplsPkg::wyde:		begin o1 = o16; end
		QuplsPkg::tetra:	begin o1 = o32; end
		QuplsPkg::octa:		begin o1 = o64; end
		QuplsPkg::hexi:		begin o1 = o128; end
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
	case(ir.any.opcode)
	OP_R2:
		case(ir.r3.func)
		FN_V2BITS:
			begin
				o1 = lane==3'd0 ? {WID{1'b0}} : t;
				if (SUPPORT_PREC)
					case(prc)
					QuplsPkg::wyde:	
						begin
							o1[{lane,2'd0}] = a[bi[3:0]+ 0];
							o1[{lane,2'd1}] = a[bi[3:0]+16];
							o1[{lane,2'd2}] = a[bi[3:0]+32];
							o1[{lane,2'd3}] = a[bi[3:0]+48];
						end
					QuplsPkg::tetra:
						begin
							o1[{lane,2'd0}] = a[bi[4:0]+ 0];
							o1[{lane,2'd1}] = a[bi[4:0]+32];
						end
					QuplsPkg::octa:
						begin
							o1[lane] = a[bi[5:0]];
						end
					default:	;
					endcase
				else
					o1[lane] = a[bi[5:0]];
			end
		default:	;
		endcase
	default:	;
	endcase
end

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
	if (SUPPORT_PREC)
		case(prc)
		QuplsPkg::wyde:		mul_done = &mul_done16;
		QuplsPkg::tetra:	mul_done = &mul_done32;
		QuplsPkg::octa:		mul_done = &mul_done64;
		QuplsPkg::hexi:		mul_done = &mul_done128;
		default:mul_done = &mul_done128;
		endcase
	else
		mul_done = &mul_done64;

always_comb
	if (SUPPORT_PREC)
		case(prc)
		QuplsPkg::wyde:		div_done = &div_done16;
		QuplsPkg::tetra:	div_done = &div_done32;
		QuplsPkg::octa:		div_done = &div_done64;
		QuplsPkg::hexi:		div_done = &div_done128;
		default:div_done = &div_done128;
		endcase
	else
		div_done = &div_done64;

always_comb
	if (SUPPORT_PREC)
		case(prc)
		QuplsPkg::wyde:		exc1 = exc16;
		QuplsPkg::tetra:	exc1 = exc32;
		QuplsPkg::octa:		exc1 = exc64;
		QuplsPkg::hexi:		exc1 = exc128;
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
