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
// 4000 LUTs / 70 FFs	SAU0
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_sau(rst, clk, clk2x, chunk, om, ld, ir, div, Ra, a, b, bi, c, i, t, qres,
	mask, cs, pc, pcc, csr, cpl, coreno, canary, velsz, o, exc_o);
parameter SAU0 = 1'b1;
parameter WID=64;
parameter LANE=0;
parameter NUM_LANES=1;
input rst;
input clk;
input clk2x;
input [2:0] chunk;
input Qupls4_pkg::operating_mode_t om;
input ld;
input Qupls4_pkg::instruction_t ir;
input div;
input [6:0] Ra;
input [WID-1:0] a;
input [WID-1:0] b;
input [WID-1:0] bi;
input [WID-1:0] c;
input [WID-1:0] i;
input [WID-1:0] t;
input [WID-1:0] qres;
input [63:0] mask;
input [2:0] cs;
input cpu_types_pkg::pc_address_ex_t pc;
input capability32_t pcc;
input [WID-1:0] csr;
input [7:0] cpl;
input [WID-1:0] coreno;
input [WID-1:0] canary;
input [2:0] velsz;
output reg [WID-1:0] o;
output Qupls4_pkg::cause_code_t exc_o;

genvar g;
integer nn,kk,jj;
integer element_number;
reg [7:0] cm;
reg [63:0] mask1;
reg [5:0] base_eleno;
reg [6:0] elesz;
Qupls4_pkg::cause_code_t exc;
wire [WID:0] zero = {WID+1{1'b0}};
wire [WID:0] dead = {1'b0,{WID/16{16'hdead}}};
wire cd_args;
value_t cc;
reg [WID*2-1:0] shl, shr, asr;
wire [WID-1:0] cmpo;
reg [WID:0] bus;
reg [WID-1:0] busx;
wire bus_nan;
reg [WID-1:0] blendo;
reg [WID-1:0] res;
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

function [WID-1:0] fnBitRev;
input [WID-1:0] i;
integer nn;
begin
	for (nn = 0; nn < WID/2; nn = nn + 1)
		fnBitRev[nn] = i[WID-1-nn];
end
endfunction

always_comb
	ii = {{6{i[WID-1]}},i};
always_comb
	sum_ab = a + b;
always_comb
	sum_gc = a + b + c;

always_comb
	shl = {{WID{1'b0}},a} << b[5:0];
always_comb
	shr = {a,{WID{1'b0}}} >> b[5:0];
always_comb
	asr = {{64{a[63]}},a,64'd0} >> b[5:0];

wire a_dn, b_dn;
wire az, bz;
wire aInf,bInf;
wire aNan,bNan;
wire asNan,bsNan;
wire aqNan,bqNan;
wire [WID-1:0] can_nan = {1'b0,{WID-1{1'b1}}};	// Quiet NaN as MSB of fract is set
reg [WID-1:0] fmin,fmax;

Qupls4_cmp #(.WID(WID)) ualu_cmp
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
			extzo[jj] = jj > c[5:0] ? 1'b0 : t1[jj];
		else if (ir[31:29]==3'b111)
			exto[jj] = jj > ir[28:23] ? t1[ir[28:23]] : t1[jj];
		else if (ir[31:25]==7'd7)	// extz
			exto[jj] = jj > c[5:0] ? t1[c[5:0]] : t1[jj];
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
		FP64 fa,fb;
  	wire [6:0] popcnt;
  	cntpop64 upopcnt64 (.i({a[WID-1:0]}),.o(popcnt));
 
		fpDecomp64 udc1a (
			.i(a),
			.sgn(fa.sign),
			.exp(fa.exp),
			.fract(fa.sig),
			.xz(a_dn),
			.vz(az),
			.inf(aInf),
			.nan(aNan),
			.snan(asNan),
			.qnan(aqNan)
		);

		fpDecomp64 udc1b (
			.i(b),
			.sgn(fb.sign),
			.exp(fb.exp),
			.fract(fb.sig),
			.xz(b_dn),
			.vz(bz),
			.inf(bInf),
			.nan(bNan),
			.snan(bsNan),
			.qnan(bqNan)
		);

		fpDecomp64 udc1bus (
			.i(bus),
			.sgn(),
			.exp(),
			.fract(),
			.xz(),
			.vz(),
			.inf(),
			.nan(bus_nan),
			.snan(),
			.qnan()
		);

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

// FMIN
always_comb
	if ((asNan|bsNan)||(aqNan&bqNan))
		fmin <= can_nan;	// canonical NaN
	else if (aqNan & !bNan)
		fmin <= b;
	else if (!aNan & bqNan)
		fmin <= a;
	else if (cmpo[1])
		fmin <= a;
	else
		fmin <= b;

// FMAX
always_comb
	if ((asNan|bsNan)||(aqNan&bqNan))
		fmax <= can_nan;	// canonical NaN
	else if (aqNan & !bNan)
		fmax <= b;
	else if (!aNan & bqNan)
		fmax <= a;
	else if (cmpo[1])
		fmax <= b;
	else
		fmax <= a;


generate begin : gInfoBlend
	if (WID != 64) begin
		assign blendo = {WID{1'b0}};
		assign info = {WID{1'b0}};
	end
	else begin
		if (SAU0) begin
			Qupls4_info uinfo1 (
				.ndx(a[4:0]+b[4:0]+ir[26:22]),
				.coreno(coreno),
				.o(info)
			);
		end
	end
end
endgenerate


generate begin : gElement
	for (g = 0; g < 64/WID; g = g + 1)
		always_comb begin
			case(Ra[1:0])
			2'd0:	cm[g] = c[g];
			2'd1:	cm[g] = c[g+64/WID*1];
			2'd2:	cm[g] = c[g+64/WID*2];
			2'd3:	cm[g] = c[g+64/WID*3];
			endcase
		end
end
endgenerate

always_comb
begin
	exc = Qupls4_pkg::FLT_NONE;
	bus = {(WID/16){16'h0000}};
	case(ir.any.opcode)
	Qupls4_pkg::OP_R3BP:
		begin
			elesz = 7'd8;
			base_eleno = {chunk,3'b0};
		end
	Qupls4_pkg::OP_R3WP:
		begin
			elesz = 7'd16;
			base_eleno = {chunk,2'b0};
		end
	Qupls4_pkg::OP_R3TP:
		begin
			elesz = 7'd32;
			base_eleno = {chunk,1'b0};
		end
	Qupls4_pkg::OP_R3OP:
		begin
			elesz = 7'd64;
			base_eleno = chunk;
		end
	default:
		mask1 = 64'd0;
	endcase
	mask1 = mask >> base_eleno;
	case(ir.any.opcode)
	Qupls4_pkg::OP_R3BP,Qupls4_pkg::OP_R3WP,Qupls4_pkg::OP_R3TP,Qupls4_pkg::OP_R3OP:
		case(ir.r3.func)
		Qupls4_pkg::FN_CMP,Qupls4_pkg::FN_CMPU:
			begin
				bus = t;
				case(ir.r3.op3)
				3'd0:	bus = cmpo & c;
				3'd1:	bus = cmpo | c;
				3'd2:	bus = cmpo ^ c;
				3'd6: bus = mask1[LANE] ? cmpo : t;
				default:	bus = zero;
				endcase
				bus = res;
			end

		Qupls4_pkg::FN_SEQ:
			begin
				bus = t;
				case(ir.r3.op3)
				3'd0:	bus = ($signed(a) == $signed(b)) & c;
				3'd1:	bus = ($signed(a) == $signed(b)) | c;
				3'd2:	bus = ($signed(a) == $signed(b)) ^ c;
				3'd3:	bus = ($signed(a) == $signed(b)) + c;
				3'd6:	bus[base_eleno + LANE] = mask1[LANE] ? $signed(a) == $signed(b) : t;
				default:	bus = zero;
				endcase
			end

		Qupls4_pkg::FN_SNE:
			begin
				bus = t;
				case(ir.r3.op3)
				3'd0:	bus = ($signed(a) != $signed(b)) & c;
				3'd1:	bus = ($signed(a) != $signed(b)) | c;
				3'd2:	bus = ($signed(a) != $signed(b)) ^ c;
				3'd3:	bus = ($signed(a) != $signed(b)) + c;
				3'd6:	bus[base_eleno + LANE] = mask1[LANE] ? $signed(a) != $signed(b) : t;
				default:	bus = zero;
				endcase
			end

		Qupls4_pkg::FN_SLT:
			begin
				bus = t;
				case(ir.r3.op3)
				3'd0:	bus = ($signed(a) < $signed(b)) & c;
				3'd1:	bus = ($signed(a) < $signed(b)) | c;
				3'd2:	bus = ($signed(a) < $signed(b)) ^ c;
				3'd3:	bus = ($signed(a) < $signed(b)) + c;
				3'd6:	bus[base_eleno + LANE] = mask1[LANE] ? $signed(a) < $signed(b) : t;
				default:	bus = zero;
				endcase
			end

		Qupls4_pkg::FN_SLE:
			begin
				bus = t;
				case(ir.r3.op3)
				3'd0:	bus = ($signed(a) <= $signed(b)) & c;
				3'd1:	bus = ($signed(a) <= $signed(b)) | c;
				3'd2:	bus = ($signed(a) <= $signed(b)) ^ c;
				3'd3:	bus = ($signed(a) <= $signed(b)) + c;
				3'd6:	bus[base_eleno + LANE] = mask1[LANE] ? $signed(a) <= $signed(b) : t;
				default:	bus = zero;
				endcase
			end

		Qupls4_pkg::FN_SLTU:
			begin
				bus = t;
				case(ir.r3.op3)
				3'd0:	bus = (a < b) & c;
				3'd1:	bus = (a < b) | c;
				3'd2:	bus = (a < b) ^ c;
				3'd3:	bus = (a < b) + c;
				3'd6:	bus[base_eleno + LANE] = mask1[LANE] ? a < b : t;
				default:	bus = zero;
				endcase
			end

		Qupls4_pkg::FN_SLEU:
			begin
				bus = t;
				case(ir.r3.op3)
				3'd0:	bus = (a <= b) & c;
				3'd1:	bus = (a <= b) | c;
				3'd2:	bus = (a <= b) ^ c;
				3'd3:	bus = (a <= b) + c;
				3'd6:	bus[base_eleno + LANE] = mask1[LANE] ? a <= b : t;
				default:	bus = zero;
				endcase
			end

		Qupls4_pkg::FN_ADD:
			begin
				case(ir.r3.op3)
				3'd0:	bus = (a + b) & c;
				3'd1:	bus = (a + b) | c;
				3'd2:	bus = (a + b) ^ c;
				3'd3:	bus = (a + b) + c;
				3'd6:	bus = mask1[LANE] ? a + b : t;
				default:	bus = zero;
				endcase
			end

		Qupls4_pkg::FN_SUB:
			begin
				case(ir.r3.op3)
				3'd0:	bus = (a - b) & c;
				3'd1:	bus = (a - b) | c;
				3'd2:	bus = (a - b) ^ c;
				3'd3:	bus = (a - b) - c;
				3'd6:	bus = mask1[LANE] ? a - b : t;
				default:	bus = zero;
				endcase
			end

		Qupls4_pkg::FN_AND:
			begin
				case(ir.r3.op3)
				3'd0:	bus = (a & b) & c;
				3'd1:	bus = (a & b) | c;
				3'd2:	bus = (a & b) ^ c;
				3'd3:	bus = (a & b) + c;
				3'd6:	bus = mask1[LANE] ? a & b : t;
				default:	bus = zero;
				endcase
			end

		Qupls4_pkg::FN_OR:
			begin
				case(ir.r3.op3)
				3'd0:	bus = (a | b) & c;
				3'd1:	bus = (a | b) | c;
				3'd2:	bus = (a | b) ^ c;
				3'd3:	bus = (a | b) + c;
				3'd6:	bus = mask1[LANE] ? a | b : t;
				default:	bus = zero;
				endcase
			end

		Qupls4_pkg::FN_XOR:
			begin
				case(ir.r3.op3)
				3'd0:	bus = (a ^ b) & c;
				3'd1:	bus = (a ^ b) | c;
				3'd2:	bus = (a ^ b) ^ c;
				3'd3:	bus = (a ^ b) + c;
				3'd6:	bus = mask1[LANE] ? a ^ b : t;
				default:	bus = zero;
				endcase
			end

		Qupls4_pkg::FN_ASL:
			begin
				case(ir.r3.op3)
				3'd0:	bus = shl & c;
				3'd1:	bus = shl | c;
				3'd2:	bus = shl ^ c;
				3'd3:	bus = shl + c;
				3'd6:	bus = mask1[LANE] ? shl : t;
				default:	bus = zero;
				endcase
			end

		Qupls4_pkg::FN_LSR:
			begin
				case(ir.r3.op3)
				3'd0:	bus = shr & c;
				3'd1:	bus = shr | c;
				3'd2:	bus = shr ^ c;
				3'd3:	bus = shr + c;
				3'd6:	bus = mask1[LANE] ? shr : t;
				default:	bus = zero;
				endcase
			end

		Qupls4_pkg::FN_ASR:
			case(ir.alu.op3)
			3'd0: bus = asr;
			3'd1:	bus = asr;
			3'd2:	bus = asr;
			3'd3:	bus = asr;
			3'd6:	bus = mask1[LANE] ? asr : t;
			default:	bus = zero;
			endcase

		Qupls4_pkg::FN_ROL:
			case(ir.alu.op3)
			3'd0: bus = (shl | shl[WID*2-1:WID]) & c;
			3'd1:	bus = (shl | shl[WID*2-1:WID]) | c;
			3'd2:	bus = (shl | shl[WID*2-1:WID]) ^ c;
			3'd3:	bus = (shl | shl[WID*2-1:WID]) + c;
			3'd6:	bus = mask1[LANE] ? (shl | shl[WID*2-1:WID]) : t;
			default:	bus = zero;
			endcase

		Qupls4_pkg::FN_ROR:
			case(ir.alu.op3)
			3'd0: bus = (shr | shr[WID*2-1:WID]) & c;
			3'd1:	bus = (shr | shr[WID*2-1:WID]) | c;
			3'd2:	bus = (shr | shr[WID*2-1:WID]) ^ c;
			3'd3:	bus = (shr | shr[WID*2-1:WID]) + c;
			3'd6:	bus = mask1[LANE] ? (shr | shr[WID*2-1:WID]) : t;
			default:	bus = zero;
			endcase
			
		Qupls4_pkg::FN_MOVE:
			bus = b;

		default:	bus = zero;
		endcase

	Qupls4_pkg::OP_R3B,Qupls4_pkg::OP_R3W,Qupls4_pkg::OP_R3T,Qupls4_pkg::OP_R3O:
		case(ir.r3.func)
		Qupls4_pkg::FN_R1:
			case(ir.r3.Rs3)
			Qupls4_pkg::R1_CNTLZ:	bus = lzcnt;
			Qupls4_pkg::R1_CNTPOP:	bus = popcnt;
			Qupls4_pkg::R1_CNTLO:	bus = locnt;
			Qupls4_pkg::R1_CNTTZ:	bus = tzcnt;
			default:	;
			endcase
		Qupls4_pkg::FN_CMP:	bus = cmpo;
		Qupls4_pkg::FN_CMPU:	bus = cmpo;
		Qupls4_pkg::FN_SEQ:	bus = a==b;
		Qupls4_pkg::FN_SNE:	bus = a != b;
		Qupls4_pkg::FN_SLT:	bus = $signed(a) < $signed(b);
		Qupls4_pkg::FN_SLE:	bus = $signed(a) <= $signed(b);
		Qupls4_pkg::FN_SLTU:	bus = a < b;
		Qupls4_pkg::FN_SLEU:	bus = a <= b;
		Qupls4_pkg::FN_ADD:
			case(ir.alu.op3)
			3'd0: bus = (a + b) & c;
			3'd1:	bus = (a + b) | c;
			3'd2:	bus = (a + b) ^ c;
			3'd3:	bus = a + b + c;
			default:	bus = zero;
			endcase
		Qupls4_pkg::FN_SUB:
			case(ir.alu.op3)
			3'd0: bus = (a - b) & c;
			3'd1:	bus = (a - b) | c;
			3'd2:	bus = (a - b) ^ c;
			3'd3:	bus = a - b - c;
			default:	bus = zero;
			endcase
		Qupls4_pkg::FN_AND:
			case(ir.alu.op3)
			3'd0: bus = (a & b) & c;
			3'd1:	bus = (a & b) | c;
			3'd2:	bus = (a & b) ^ c;
			3'd3:	bus = (a & b) + c;
			default:	bus = zero;
			endcase
		Qupls4_pkg::FN_OR:
			case(ir.alu.op3)
			3'd0: bus = (a | b) & c;
			3'd1:	bus = (a | b) | c;
			3'd2:	bus = (a | b) ^ c;
			3'd3:	bus = (a | b) + c;
			default:	bus = zero;
			endcase
		Qupls4_pkg::FN_XOR:
			case(ir.alu.op3)
			3'd0: bus = (a ^ b) & c;
			3'd1:	bus = (a ^ b) | c;
			3'd2:	bus = (a ^ b) ^ c;
			3'd3:	bus = (a ^ b) + c;
			default:	bus = zero;
			endcase
		Qupls4_pkg::FN_ASL:
			case(ir.alu.op3)
			3'd0: bus = shl & c;
			3'd1:	bus = shl | c;
			3'd2:	bus = shl ^ c;
			3'd3:	bus = shl + c;
			default:	bus = zero;
			endcase
		Qupls4_pkg::FN_ASR:
			case(ir.alu.op3)
			3'd0: bus = asr;
			3'd1:	bus = asr;
			3'd2:	bus = asr;
			3'd3:	bus = asr;
			default:	bus = zero;
			endcase
		Qupls4_pkg::FN_LSR:
			case(ir.alu.op3)
			3'd0: bus = shr & c;
			3'd1:	bus = shr | c;
			3'd2:	bus = shr ^ c;
			3'd3:	bus = shr + c;
			default:	bus = zero;
			endcase
		Qupls4_pkg::FN_ROL:
			case(ir.alu.op3)
			3'd0: bus = (shl | shl[WID*2-1:WID]) & c;
			3'd1:	bus = (shl | shl[WID*2-1:WID]) | c;
			3'd2:	bus = (shl | shl[WID*2-1:WID]) ^ c;
			3'd3:	bus = (shl | shl[WID*2-1:WID]) + c;
			default:	bus = zero;
			endcase
		Qupls4_pkg::FN_ROR:
			case(ir.alu.op3)
			3'd0: bus = (shr | shr[WID*2-1:WID]) & c;
			3'd1:	bus = (shr | shr[WID*2-1:WID]) | c;
			3'd2:	bus = (shr | shr[WID*2-1:WID]) ^ c;
			3'd3:	bus = (shr | shr[WID*2-1:WID]) + c;
			default:	bus = zero;
			endcase
		Qupls4_pkg::FN_MOVE:	bus = b;
		endcase

	Qupls4_pkg::OP_FLTH,Qupls4_pkg::OP_FLTS,Qupls4_pkg::OP_FLTD,Qupls4_pkg::OP_FLTQ:
		case(ir.f3.func)
		Qupls4_pkg::FLT_MIN:	bus = fmin;
		Qupls4_pkg::FLT_MAX:	bus = fmax;
		Qupls4_pkg::FLT_NEG:	bus = (aNan ? a : {~a[WID-1],a[WID-2:0]});
		Qupls4_pkg::FLT_SEQ:
			begin	
				bus = ((aNan|bNan) ? 1'b0 : cmpo[0]);
			end
		Qupls4_pkg::FLT_SNE:
			begin	
				bus = ((aNan|bNan) ? 1'b0 : cmpo[8]);
			end
		Qupls4_pkg::FLT_SLT:
			begin	
				bus = ((aNan|bNan) ? 1'b0 : cmpo[1]);
			end
		Qupls4_pkg::FLT_SGNJ:
			begin	
				bus = (aNan ? a : bNan ? b : {a[WID-1],b[WID-2:0]});
			end
		default:	bus = zero;
		endcase
	
	Qupls4_pkg::OP_FLTPH,Qupls4_pkg::OP_FLTPS,Qupls4_pkg::OP_FLTPD,Qupls4_pkg::OP_FLTPQ,
	Qupls4_pkg::OP_FLTP:
		case(ir.f3.func)
		Qupls4_pkg::FLT_MIN:	bus = mask1[LANE] ? fmin : t;
		Qupls4_pkg::FLT_MAX:	bus = mask1[LANE] ? fmax : t;
		Qupls4_pkg::FLT_NEG:	bus = mask1[LANE] ? (aNan ? a : {~a[WID-1],a[WID-2:0]}) : t;
		Qupls4_pkg::FLT_SEQ:
			begin	
				bus = t;
				bus[base_eleno + LANE] = mask1[LANE] ? ((aNan|bNan) ? 1'b0 : cmpo[0]) : t[LANE];
			end
		Qupls4_pkg::FLT_SNE:
			begin	
				bus = t;
				bus[base_eleno + LANE] = mask1[LANE] ? ((aNan|bNan) ? 1'b0 : cmpo[8]) : t[LANE];
			end
		Qupls4_pkg::FLT_SLT:
			begin	
				bus = t;
				bus[base_eleno + LANE] = mask1[LANE] ? ((aNan|bNan) ? 1'b0 : cmpo[1]) : t[LANE];
			end
		Qupls4_pkg::FLT_SGNJ:
			begin	
				bus = mask1[LANE] ? (aNan ? a : bNan ? b : {a[WID-1],b[WID-2:0]}) : t;
			end
		default:	bus = zero;
		endcase

	/*
	Qupls4_pkg::OP_FLTH,Qupls4_pkg::OP_FLTS,Qupls4_pkg::OP_FLTD,Qupls4_pkg::OP_FLTQ:
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
	*/
	Qupls4_pkg::OP_CHK:
		case(ir.chk.op4)
		4'd0:	if (!(a >= b && a < c)) exc = Qupls4_pkg::FLT_CHK;
		4'd1: if (!(a >= b && a <= c)) exc = Qupls4_pkg::FLT_CHK;
		4'd2: if (!(a > b && a < c)) exc = Qupls4_pkg::FLT_CHK;
		4'd3: if (!(a > b && a <= c)) exc = Qupls4_pkg::FLT_CHK;
		4'd4:	if (a >= b && a < c) exc = Qupls4_pkg::FLT_CHK;
		4'd5: if (a >= b && a <= c) exc = Qupls4_pkg::FLT_CHK;
		4'd6: if (a > b && a < c) exc = Qupls4_pkg::FLT_CHK;
		4'd7: if (a > b && a <= c) exc = Qupls4_pkg::FLT_CHK;
		4'd8:	if (!(a >= cpl)) exc = Qupls4_pkg::FLT_CHK;
		4'd9:	if (!(a <= cpl)) exc = Qupls4_pkg::FLT_CHK;
		4'd10:	if (!(a==canary)) exc = Qupls4_pkg::FLT_CHK;
		default:	exc = Qupls4_pkg::FLT_UNIMP;
		endcase
	Qupls4_pkg::OP_CSR:		bus = csr;

	Qupls4_pkg::OP_ADDI:	bus = a + i;
	Qupls4_pkg::OP_ADDIPI:	bus = a + i + pc.pc;
	Qupls4_pkg::OP_ANDI:	bus = a & i;
	Qupls4_pkg::OP_ORI:		bus = a | i;
	Qupls4_pkg::OP_XORI:	bus = a ^ i;
	Qupls4_pkg::OP_SUBFI:	bus = i - a;
	Qupls4_pkg::OP_CMPI:	bus = cmpo;
	Qupls4_pkg::OP_CMPUI:	bus = cmpo;
/*	
	Qupls4_pkg::OP_MOV:
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
*/
	Qupls4_pkg::OP_LOADA:	bus = a + i + (b << ir[47:45]);
	Qupls4_pkg::OP_NOP:		bus = t;	// in case of copy target
	default:	bus = {(WID/16){16'hDEAD}};
	endcase
end

always_ff @(posedge clk)
	case(WID)
	16:	o = bus;
	32:	o = bus_nan ? bus | (fnBitRev(pc) >> 6'd48) : bus;
	64:	o = bus_nan ? bus | (fnBitRev(pc) >> 6'd20) : bus;
	128:	o = bus_nan ? bus | fnBitRev(pc) : bus;
	default:	o = zero;
	endcase

always_ff @(posedge clk)
	exc_o = exc;

endmodule
