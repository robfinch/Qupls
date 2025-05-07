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
// 3600 LUTs / 1100 FFs	SAU0
// 3100 LUTs / 700 FFs
// 13.5k LUTs	/ 710 FFs SAU0 with capabilities
//  7.5 kLUTs / 710 FFs SAU0 without capabilities
// 14.5k LUTs / 1420 FFs SAU0 128-bit without capabilities
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Stark_pkg::*;

module Stark_sau(rst, clk, clk2x, om, ld, ir, div, a, b, bi, c, i, t, qres,
	cs, pc, pcc, csr, cpl, coreno, canary, o, exc_o);
parameter SAU0 = 1'b1;
parameter WID=64;
parameter LANE=0;
input rst;
input clk;
input clk2x;
input Stark_pkg::operating_mode_t om;
input ld;
input Stark_pkg::instruction_t ir;
input div;
input [WID-1:0] a;
input [WID-1:0] b;
input [WID-1:0] bi;
input [WID-1:0] c;
input [WID-1:0] i;
input [WID-1:0] t;
input [WID-1:0] qres;
input [2:0] cs;
input cpu_types_pkg::pc_address_ex_t pc;
input capability32_t pcc;
input [WID-1:0] csr;
input [7:0] cpl;
input [WID-1:0] coreno;
input [WID-1:0] canary;
output reg [WID-1:0] o;
output Stark_pkg::cause_code_t exc_o;

genvar g;
integer nn,kk,jj;
Stark_pkg::cause_code_t exc;
wire [WID:0] zero = {WID+1{1'b0}};
wire [WID:0] dead = {1'b0,{WID/16{16'hdead}}};
wire cd_args;
value_t cc;
reg [WID*2-1:0] shl, shr, asr;
wire [WID-1:0] cmpo;
reg [WID:0] bus;
reg [WID-1:0] busx;
reg [WID-1:0] blendo;
reg [22:0] ii;
reg [WID-1:0] sd;
reg [WID-1:0] sum_ab;
reg [WID+1:0] sum_gc;
reg [WID-1:0] chndx;
reg [WID-1:0] chndx2;
reg [WID-1:0] chrndxv;
wire [WID-1:0] info;
wire [WID-1:0] vmasko;
reg [WID-1:0] tmp;

always_comb
	ii = {{6{i[WID-1]}},i};
always_comb
	sum_ab = a + b;
always_comb
	sum_gc = a + b + c;

always_comb
	shl = {{WID{1'b0}},a} << (ir[31] ? ir.shi.amt : b[5:0]);
always_comb
	shr = {a,{WID{1'b0}}} >> (ir[31] ? ir.shi.amt : b[5:0]);
always_comb
	asr = {{64{a[63]}},a,64'd0} >> (ir[31] ? ir.srai.amt : b[5:0]);

Stark_cmp #(.WID(WID)) ualu_cmp
(
	.ir(ir),
	.om(om),
	.cr(t),
	.a(a),
	.b(b),
	.i(i),
	.o(cmpo)
);

reg [WID-1:0] locnt,lzcnt,popcnt,tzcnt;
reg loz, lzz, tzz;
reg [WID-1:0] t1;
reg [WID-1:0] exto, extzo;

// Handle ext, extz
always_comb
begin
	t1 = a >> (ir[31] ? ir[22:17] : b[5:0]);	// srl
	for (jj = 0; jj < WID; jj = jj + 1)
		if (ir[31:29]==3'b110)		// extz
			extzo[jj] = jj > ir[28:23] ? 1'b0 : t1[jj];
		else if (ir[31:25]==7'd6)	// extz
			extzo[jj] = jj > b[13:8] ? 1'b0 : t1[jj];
		else if (ir[31:29]==3'b111)
			exto[jj] = jj > ir[28:23] ? t1[ir[28:23]] : t1[jj];
		else if (ir[31:25]==7'd7)	// extz
			exto[jj] = jj > b[13:8] ? t1[b[13:8]] : t1[jj];
		else
			exto[jj] = zero;
end

	
generate begin : gffz
	for (g = WID-1; g >= 0; g = g - 1)
  case(WID)
  16:	
  	begin
  	wire [4:0] popcnt;
  	cntpop16 upopcnt16 (.i({a[WID-1:0]}),.o(popcnt));
  	end
  32:
  	begin
  	wire [5:0] popcnt;
  	cntpop32 upopcnt32 (.i({a[WID-1:0]}),.o(popcnt));
  	end
  64:
  	begin
  	wire [6:0] popcnt;
  	cntpop64 upopcnt64 (.i({a[WID-1:0]}),.o(popcnt));
  	end
  128:
  	begin
  	wire [7:0] popcnt;
  	cntpop128 upopcnt128 (.i({a[WID-1:0]}),.o(popcnt));
  	end
	endcase
  case(WID)
  16:	
  	begin
  	wire [4:0] locnt;
  	ffz24 uffz16 (.i({8'hFF,a[WID-1:0]}),.o(locnt));
  	end
  32:
  	begin
  	wire [5:0] locnt;
  	ffz48 uffz32 (.i({16'hFFFF,a[WID-1:0]}),.o(locnt));
  	end
  64:
  	begin
  	wire [6:0] locnt;
  	ffz96 uffo64 (.i({32'hFFFFFFFF,a[WID-1:0]}),.o(locnt));
  	end
  128:
  	begin
  	wire [7:0] locnt;
  	ffz144 uffo128 (.i({16'hFFFF,a[WID-1:0]}),.o(locnt));
  	end
	endcase
  case(WID)
  16:	
  	begin
  	wire [4:0] lzcnt;
  	ffo24 uffo16 (.i({8'h00,a[WID-1:0]}),.o(lzcnt));
  	end
  32:
  	begin
  	wire [5:0] lzcnt;
  	ffo48 uffo32 (.i({16'h0000,a[WID-1:0]}),.o(lzcnt));
  	end
  64:
  	begin
  	wire [6:0] lzcnt;
  	ffo96 uffo64 (.i({32'h00000000,a[WID-1:0]}),.o(lzcnt));
  	end
  128:
  	begin
  	wire [7:0] lzcnt;
  	ffo144 uffo128 (.i({16'h0000,a[WID-1:0]}),.o(lzcnt));
  	end
	endcase
  case(WID)
  16:	
  	begin
  	wire [4:0] tzcnt;
  	flo24 uflo16 (.i({8'hFF,a[WID-1:0]}),.o(tzcnt));
  	end
  32:
  	begin
  	wire [5:0] tzcnt;
  	flo48 uflo32 (.i({16'hFFFF,a[WID-1:0]}),.o(tzcnt));
  	end
  64:
  	begin
  	wire [6:0] tzcnt;
  	flo96 uflo64 (.i({32'hFFFFFFFF,a[WID-1:0]}),.o(tzcnt));
  	end
  128:
  	begin
  	wire [7:0] tzcnt;
  	flo144 uflo128 (.i({16'hFFFF,a[WID-1:0]}),.o(tzcnt));
  	end
	endcase
end
endgenerate

generate begin : gInfoBlend
	if (WID != 64) begin
		assign blendo = {WID{1'b0}};
		assign info = {WID{1'b0}};
	end
	else begin
		if (SAU0) begin
			Stark_info uinfo1 (
				.ndx(a[4:0]+b[4:0]+ir[26:22]),
				.coreno(coreno),
				.o(info)
			);
		end
	end
end
endgenerate


always_comb
begin
	exc = Stark_pkg::FLT_NONE;
	bus = {(WID/16){16'h0000}};
	case(ir.any.opcode)
	Stark_pkg::OP_FLT:
		case(ir.fpu.op4)
		FOP4_G8:	
			case (ir.fpu.op3)
			FG8_FSGNJ:	bus = {b[WID-1],a[WID-2:0]};
			FG8_FSGNJN:	bus = {~b[WID-1],a[WID-2:0]};
			FG8_FSGNJX:	bus = {b[WID-1]^a[WID-1],a[WID-2:0]};
			default:	 bus = zero;
			endcase
		default:	bus = zero;
		endcase
	Stark_pkg::OP_CHK:
		case(ir.chk.op4)
		4'd0:	if (!(a >= b && a < c)) exc = Stark_pkg::FLT_CHK;
		4'd1: if (!(a >= b && a <= c)) exc = Stark_pkg::FLT_CHK;
		4'd2: if (!(a > b && a < c)) exc = Stark_pkg::FLT_CHK;
		4'd3: if (!(a > b && a <= c)) exc = Stark_pkg::FLT_CHK;
		4'd4:	if (a >= b && a < c) exc = Stark_pkg::FLT_CHK;
		4'd5: if (a >= b && a <= c) exc = Stark_pkg::FLT_CHK;
		4'd6: if (a > b && a < c) exc = Stark_pkg::FLT_CHK;
		4'd7: if (a > b && a <= c) exc = Stark_pkg::FLT_CHK;
		4'd8:	if (!(a >= cpl)) exc = Stark_pkg::FLT_CHK;
		4'd9:	if (!(a <= cpl)) exc = Stark_pkg::FLT_CHK;
		4'd10:	if (!(a==canary)) exc = Stark_pkg::FLT_CHK;
		default:	exc = Stark_pkg::FLT_UNIMP;
		endcase
	Stark_pkg::OP_CSR:		bus = csr;

	Stark_pkg::OP_ADD:
		begin
			if (ir[31])
				bus = a + i;
			else
				case(ir.alu.op3)
				3'd0:		// ADD
					case(ir.alu.lx)
					2'd0:	bus = a + b;
					default:	bus = a + i;
					endcase
				3'd2:		// ABS
					case(ir.alu.lx)
					2'd0:
						begin
							tmp = a + b;
							bus = tmp[WID-1] ? -tmp : tmp;
						end
					default:
						begin
							tmp = a + i;
							bus = tmp[WID-1] ? -tmp : tmp;
						end
					endcase
				3'd3:	bus = &locnt ? WID : locnt;
				3'd4:	bus = &lzcnt ? WID : lzcnt;
				3'd5:	bus = popcnt;
				3'd6:	bus = &tzcnt ? WID : tzcnt;
				default:	bus = zero;
				endcase
		end
	Stark_pkg::OP_ADB:
		if (ir[31])
			bus = a + i;
		else
			case(ir.alu.lx)
			2'd0:	bus = a + b;
			default:	bus = a + i;
			endcase
	Stark_pkg::OP_AND:
		if (ir[31])
			bus = a & i;
		else
			case(ir.alu.op3)
			3'd0:	bus = a & bi;
			3'd1:	bus = ~(a & bi);
			3'd2:	bus = a & ~bi;
			default:	bus = zero;	
			endcase
	Stark_pkg::OP_OR:
		if (ir[31])
			bus = a | i;
		else
			case(ir.alu.op3)
			3'd0:	bus = a | bi;
			3'd1:	bus = ~(a | bi);
			3'd2:	bus = a | ~bi;
			default:	bus = zero;	
			endcase
	Stark_pkg::OP_XOR:
		if (ir[31])
			bus = a ^ i;
		else
			case(ir.alu.op3)
			3'd0:	bus = a ^ bi;
			3'd1:	bus = ~(a ^ bi);
			3'd2:	bus = a ^ ~bi;
			default:	bus = zero;	
			endcase
	Stark_pkg::OP_SUBF:
		if (ir[31])
			bus = i - a;
		else
			case(ir.alu.op3)
			3'd0:	bus = bi - a;
			3'd2:									// PTRDIF
				begin
					tmp = bi - a;
					tmp = tmp[WID-1] ? -tmp : tmp;
					bus = tmp >> ir[25:22];
				end
			default:	bus = zero;	
			endcase
	Stark_pkg::OP_CMP:	bus = cmpo;
	Stark_pkg::OP_SHIFT:
		if (SAU0) begin
			if (ir[31])
				case(ir.shi.op2)
				2'd0:	
					case(ir[28:26])
					3'd0:	bus = ir.shi.h ? shl[WID*2-1:WID] : shl[WID-1:0];
					3'd1:	bus = ir.shi.h ? shr[WID-1:0] : shr[WID*2-1:WID];
					3'd2:	
						case(ir.srai.rm)
						default:
							bus = asr[WID*2-1:WID];
						endcase
					3'd3:	bus = ir[25] ? exto : extzo;
					3'd4:	
						if (ir[25])	// ROL?
							bus = shl[WID*2-1:WID]|shl[WID-1:0];
						else
							bus = shr[WID*2-1:WID]|shr[WID-1:0];
					default:	bus = zero;
					endcase
				3'd2:	bus = extzo;
				3'd3: bus = exto;
				default: bus = zero;
				endcase
			else
				case(ir.shi.op2)
				2'd0:	
					case(ir[28:26])
					3'd0:	bus = ir.shi.h ? shl[WID*2-1:WID] : shl[WID-1:0];
					3'd1:	bus = ir.shi.h ? shr[WID-1:0] : shr[WID*2-1:WID];
					3'd2:	
						case(ir.srai.rm)
						default:
							bus = asr[WID*2-1:WID];
						endcase
					3'd3:	bus = ir[25] ? exto : extzo;
					3'd4:	
						if (ir[25])	// ROL?
							bus = shl[WID*2-1:WID]|shl[WID-1:0];
						else
							bus = shr[WID*2-1:WID]|shr[WID-1:0];
					default:	bus = zero;
					endcase
				3'd2:	bus = extzo;
				3'd3: bus = exto;
				default: bus = zero;
				endcase
		end
		else
			bus = zero;
	Stark_pkg::OP_MOV:
		if (ir[31]) begin
			case(ir.move.op3)
			3'd0:	// MOVE / XCHG
				begin
					bus = a;	// MOVE
				end
			3'd1:	// XCHGMD / MOVEMD
				begin	
					bus = a;
				end
			3'd2:	bus = zero;		// MOVSX
			3'd3:	bus = zero;		// MOVZX
			3'd4:	bus = ~|a ? i : t;	// CMOVZ
			3'd5:	bus =  |a ? i : t;	// CMOVNZ
			3'd6:	bus = zero;		// BMAP
			default:
				begin
					bus = zero;
				end
			endcase
		end
		else
			case(ir.move.op3)
			3'd4:	bus = ~|a ? b : t;	// CMOVZ
			3'd5:	bus =  |a ? b : t;	// CMOVNZ
			default:
				begin
					bus = zero;
				end
			endcase
	Stark_pkg::OP_LOADA:	bus = a + i + (b << ir[23:22]);
	Stark_pkg::OP_NOP:		bus = t;	// in case of copy target
	default:	bus = {(WID/16){16'hDEAD}};
	endcase
end

always_ff @(posedge clk)
	o = bus;
always_ff @(posedge clk)
	exc_o = exc;

endmodule
