// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2026  Robert Finch, Waterloo
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
// 4000 LUTs / 70 FFs	ALU
// ============================================================================

import const_pkg::*;
import fp64Pkg::*;
import cpu_types_pkg::*;
import capability_pkg::*;
import Qupls5_pkg::*;

module Qupls5_alu(rst, clk, clk2x, chunk, cr0, ld, ir, div, Ra, a, b, bi, c,
	a_flags, b_flags, c_flags, t_flags, i, t, qres, capa, capa_flags,
	mask, cs, pc, pcc, csr, cpl, coreno, canary, velsz, o, o_flags, exc_o, did_op);
parameter PIPE = 3'd0;
parameter SUPPORT_CAPABILITIES = Qupls5_pkg::SUPPORT_CAPABILITIES;
parameter SUPPORT_SHIFT0 = Qupls5_pkg::SUPPORT_SHIFT0;
parameter SUPPORT_SHIFT1 = Qupls5_pkg::SUPPORT_SHIFT1;
parameter SUPPORT_COUNT0 = Qupls5_pkg::SUPPORT_COUNT0;
parameter SUPPORT_COUNT1 = Qupls5_pkg::SUPPORT_COUNT1;
parameter SUPPORT_CRYPTO0 = Qupls5_pkg::SUPPORT_CRYPTO0;
parameter SUPPORT_CRYPTO1 = Qupls5_pkg::SUPPORT_CRYPTO1;
parameter SUPPORT_INFO0 = Qupls5_pkg::SUPPORT_INFO0;
parameter SUPPORT_INFO1 = Qupls5_pkg::SUPPORT_INFO1;
parameter SUPPORT_CSR0 = Qupls5_pkg::SUPPORT_CSR0;
parameter SUPPORT_CSR1 = Qupls5_pkg::SUPPORT_CSR1;
parameter SUPPORT_BFLD0 = Qupls5_pkg::SUPPORT_BFLD0;
parameter SUPPORT_BFLD1 = Qupls5_pkg::SUPPORT_BFLD1;
parameter SUPPORT_VECTOR = Qupls5_pkg::SUPPORT_VECTOR;
parameter SUPPORT_GRAPHICS = Qupls5_pkg::SUPPORT_GRAPHICS;
parameter SUPPORT_SHIFT = (PIPE==3'd0 && SUPPORT_SHIFT0) || (PIPE==3'd1 && SUPPORT_SHIFT1);
parameter SUPPORT_COUNT = (PIPE==3'd0 && SUPPORT_COUNT0) || (PIPE==3'd1 && SUPPORT_COUNT1);
parameter SUPPORT_CRYPTO = (PIPE==3'd1 && SUPPORT_CRYPTO1) || (PIPE==3'd0 && SUPPORT_CRYPTO0);
parameter SUPPORT_INFO = (PIPE==3'd0 && SUPPORT_INFO0) || (PIPE==3'd1 && SUPPORT_INFO1);
parameter SUPPORT_CSR = (PIPE==3'd0 && SUPPORT_CSR0) || (PIPE==3'd1 && SUPPORT_CSR1);
parameter SUPPORT_BFLD = (PIPE==3'd0 && SUPPORT_BFLD0) || (PIPE==3'd1 && SUPPORT_BFLD1);
parameter SUPPORT_BRANCH = PIPE==3'd1;
parameter WID=64;
parameter LANE=0;
parameter NUM_LANES=1;
input rst;
input clk;
input clk2x;
input [2:0] chunk;
input Qupls5_pkg::status_reg_t cr0;
input ld;
input Qupls5_pkg::micro_op_t ir;
input div;
input [6:0] Ra;
input uc64_capability_t capa;
input cpu_types_pkg::flags_t capa_flags;
input [WID-1:0] a;
input [WID-1:0] b;
input [WID-1:0] bi;
input [WID-1:0] c;
input [WID-1:0] i;
input [WID-1:0] t;
input flags_t a_flags;
input flags_t b_flags;
input flags_t c_flags;
input flags_t t_flags;
input [WID-1:0] qres;
input [63:0] mask;
input [2:0] cs;
input Qupls5_pkg::pc_address_ex_t pc;
input capability32_t pcc;
input [WID-1:0] csr;
input [7:0] cpl;
input [WID-1:0] coreno;
input [WID-1:0] canary;
input [63:0] velsz;
output reg [WID-1:0] o;
output flags_t o_flags;
output Qupls5_pkg::cause_code_t exc_o;
output reg did_op;

genvar g;
integer nn,kk,jj,n1;
integer element_number;
wire [5:0] lane = LANE;
reg [63:0] c1;
reg [7:0] cm;
reg [63:0] mask1;
reg [WID-1:0] mask2;
reg [5:0] base_eleno;
reg [6:0] elesz;
Qupls5_pkg::cause_code_t exc;
wire [WID:0] zero = {WID+1{1'b0}};
wire [WID:0] dead = {1'b0,{WID/16{16'hdead}}};
wire cd_args;
value_t cc;
reg [WID*2-1:0] shl, shr, asr;
wire [WID-1:0] cmpo;
reg [WID:0] bus;
reg [WID-1:0] busx;
wire bus_nan;
reg [22:0] ii;
reg [WID-1:0] aa,bb;
reg [WID-1:0] sd;
reg [WID-1:0] sum_ab;
reg [WID+1:0] sum_gc;
reg [WID-1:0] chndx;
reg [WID-1:0] chndx2;
reg [WID-1:0] chrndxv;
reg [WID-1:0] bmap;
wire [WID-1:0] info;
wire [WID-1:0] vmasko;
wire [WID-1:0] blendo;
reg [WID-1:0] tmp;
reg [WID-1:0] bmask;
reg [6:0] y;
wire [63:0] cryptoo;
reg [3:0] ele_per_reg;
reg [2:0] cr;
reg cy,ov;				// carry and overflow bit

/*
wire [63:0] txu = (a[35:0] * c[17:0]) >> 18;
wire [63:0] txv = (b[35:0] * c[41:24]) >> 18;
wire [63:0] txv1 = txv * c[17:0];
wire [63:0] txn = (txu+txv1) * c[63:60];
*/
function [WID-1:0] fnBitRev;
input [WID-1:0] i;
integer nn;
begin
	for (nn = 0; nn < WID/2; nn = nn + 1)
		fnBitRev[nn] = i[WID-1-nn];
end
endfunction

// If the signs of the operands are the same, and the sign of the result does
// not match the operands sign.
function fnAddOverflow;
input r;
input a;
input b;
	fnAddOverflow = (r ^ b) & (1'b1 ^ a ^ b);
endfunction

// If the signs of the operands are different and sign of the result does not
// match the first operand.
function fnSubOverflow;
input r;
input a;
input b;
	fnSubOverflow = (r ^ a) & (a ^ b);
endfunction

reg ibranch;
reg dbranch;

always_comb
begin
	ibranch = FALSE;
	dbranch = FALSE;
	case(ir.func)
	Qupls5_pkg::CND_NE:	dbranch = ir.inc;
	Qupls5_pkg::CND_LT:	ibranch = ir.inc;
	Qupls5_pkg::CND_LE:	ibranch = ir.inc;
	default:	;
	endcase
end


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

always_comb
if (elesz < 6'd9)
	ele_per_reg = 4'd8;
else if (elesz < 6'd17)
	ele_per_reg = 4'd4;
else if (elesz < 6'd33)
	ele_per_reg = 4'd2;
else
	ele_per_reg = 4'd1;

reg [WID+8-1:0] t1;
reg [WID+8-1:0] bfldo;
reg [6:0] bflen;
reg [6:0] bfst,bfnd;
reg [WID+8-1:0] af;
reg [WID+8-1:0] op3;
reg [5:0] sh;

// Handle clr, set, com, ext, extz, dep
generate begin : gBlfd
	if (WID==64) begin
		always_comb
		begin
			if (ir.opcode==Qupls5_pkg::OP_PPC_RLDIC) begin
				case(ir.func[3:1])
				3'd0:
					begin
						bfst = ir.func[10:4];
						bfnd = 6'd63;
						sh = {ir.Rs2,ir.func[0]};
					end
				3'd1:	
					begin
						bfnd = ir.func[10:4];
						bfst = 6'd0;
						sh = {ir.Rs2,ir.func[0]};
					end
				3'd2:
					begin
						bfst = ir.func[10:4];
						bfnd = 7'd63 - {ir.Rs2,ir.func[0]};
						sh = {ir.Rs2,ir.func[0]};
					end
				3'd3:
					begin
						bfst = ir.func[10:4];
						bfnd = 7'd63 - {ir.Rs2,ir.func[0]};
						sh = {ir.Rs2,ir.func[0]};
					end
				3'd4:
					begin
						if (ir.func[0]) begin
							bfst = 7'd0;
							bfnd = ir.func[10:4];
							sh = b[5:0];
						end
						else begin
							bfst = ir.func[10:4];
							bfnd = 7'd63;
							sh = b[5:0];
						end
					end
				default:
					begin
						bfst = ir.func[10:4];
						bfnd = 6'd63;
					end
				endcase
			end
			else begin
				bfst = ir.func[10:5];
				bfnd = ir.func[ 4:0];
			end
			bmask = 64'd0;
			for (jj = 0; jj < 64; jj = jj + 1)
				if (bfst <= bfnd) begin
					if (jj >= bfst && jj <= bfnd)
						bmask[jj] = 1'b1;
				end
				else begin
					if (jj >= bfst || jj <= bfnd)
						bmask[jj] = 1'b1;
				end
			case(ir.opcode)
			Qupls5_pkg::OP_PPC_RLWIMI:
				begin
					sh = ir.Rs2;
					bfldo = (a[31:0] << sh) | (a[31:0] >> (7'd32-sh));
					foreach (bfldo[jj])
						bfldo[jj] = bmask[jj] ? bfldo[jj] : t[jj];
					bfldo[63:32] = 32'd0;
				end
			Qupls5_pkg::OP_PPC_RLWINM:
				begin
					sh = ir.Rs2;
					bfldo = (a[31:0] << sh) | (a[31:0] >> (7'd32-sh));
					bfldo = bfldo & bmask;
					bfldo[63:32] = 32'd0;
				end
			Qupls5_pkg::OP_PPC_RLWNM:
				begin
					sh = b[4:0];
					bfldo = (a[31:0] << sh) | (a[31:0] >> (7'd32-sh));
					bfldo = bfldo & bmask;
					bfldo[63:32] = 32'd0;
				end
			Qupls5_pkg::OP_PPC_RLDIC:
				begin
					bfldo = (a << sh) | (a >> (7'd64-sh));
					if (ir.func[3:1]==3'd3) begin
						foreach (bfldo[jj])
							bfldo[jj] = bmask[jj] ? bfldo[jj] : t[jj];
					end
					else
						bfldo = bfldo & bmask;
				end			
			endcase
		end
	end
	else begin
		always_comb
		begin
			bfst = 7'd0;
			bfnd = 7'd0;	
			bflen = 7'd0;
			af = {WID+8{1'b0}};
			t1 = {WID+8{1'b0}};
			bfldo = {WID+8{1'b0}};
			op3 = {WID+8{1'b0}};
		end
	end
end
endgenerate

// Make sure to always find a one.
reg [6:0] ffoa, ffob;
ffo96 uffoa1 (.i({95'd0,a,1'b1}), .o(ffoa));
ffo96 uffob1 (.i({95'd0,b,1'b1}), .o(ffob));

wire a_dn, b_dn;
wire az, bz;
wire aInf,bInf;
wire aNan,bNan;
wire asNan,bsNan;
wire aqNan,bqNan;
wire [WID-1:0] can_nan = {1'b0,{WID-1{1'b1}}};	// Quiet NaN as MSB of fract is set
reg [WID-1:0] fmin,fmax;

Qupls5_cmp #(.WID(WID)) ualu_cmp
(
	.ir(ir),
	.om(cr0.om),
	.cr(t),
	.a(a),
	.b(b),
	.i(i),
	.o(cmpo)
);

generate begin : gBlend
	if (WID==64) begin
Qupls5_blend ublend1
(
	.a(a),
	.b(b),
	.c(c),
	.o(blendo)
);
	end
	else begin
		assign blendo = zero;
	end
end
endgenerate

reg [$clog2(WID):0] locnt,lzcnt,popcnt,tzcnt;
reg loz, lzz, tzz;

	
generate begin : gffz
//	for (g = WID-1; g >= 0; g = g - 1)
  case(WID)
  16:	
  	begin
  	cntpop16 upopcnt16 (.i({a[WID-1:0]}),.o(popcnt));
		assign cryptoo = 64'd0;
  	end
  32:
  	begin
  	cntpop32 upopcnt32 (.i({a[WID-1:0]}),.o(popcnt));
		assign cryptoo = 64'd0;
  	end
  64:
  	begin
		FP64 fa,fb;
  	wire fasig_hidden,fbsig_hidden;
  	cntpop64 upopcnt64 (.i({a[WID-1:0]}),.o(popcnt));

		if (SUPPORT_CRYPTO) begin
			Qupls5_crypto uCrypto1
			(
				.ir(ir),
				.a(a),
				.b(b),
				.c(c),
				.o(cryptoo)
			);
		end
		else
			assign cryptoo = 64'd0;
 
		fpDecomp64 udc1a (
			.i(a),
			.sgn(fa.sign),
			.exp(fa.exp),
			.fract({fasig_hidden,fa.sig}),
			.xz(a_dn),
			.xinf(),
			.vz(az),
			.man(),
			.mz(),
			.inf(aInf),
			.nan(aNan),
			.snan(asNan),
			.qnan(aqNan)
		);

		fpDecomp64 udc1b (
			.i(b),
			.sgn(fb.sign),
			.exp(fb.exp),
			.fract({fbsig_hidden,fb.sig}),
			.xz(b_dn),
			.xinf(),
			.vz(bz),
			.man(),
			.mz(),
			.inf(bInf),
			.nan(bNan),
			.snan(bsNan),
			.qnan(bqNan)
		);

		fpDecomp64 udc1bus (
			.i(bus[63:0]),
			.sgn(),
			.exp(),
			.fract(),
			.xz(),
			.xinf(),
			.vz(),
			.man(),
			.mz(),
			.inf(),
			.nan(bus_nan),
			.snan(),
			.qnan()
		);

  	end
  128:
  	begin
  	cntpop128 upopcnt128 (.i({a[WID-1:0]}),.o(popcnt));
		assign cryptoo = 64'd0;
  	end
	endcase
  case(WID)
  16:	
  	begin
  	ffz24 uffz16 (.i({8'hFF,a[WID-1:0]}),.o(locnt));
  	end
  32:
  	begin
  	ffz48 uffz32 (.i({16'hFFFF,a[WID-1:0]}),.o(locnt));
  	end
  64:
  	begin
  	ffz96 uffo64 (.i({32'hFFFFFFFF,a[WID-1:0]}),.o(locnt));
  	end
  128:
  	begin
  	ffz144 uffo128 (.i({16'hFFFF,a[WID-1:0]}),.o(locnt));
  	end
  default:
  	begin
  	ffz96 uffo64 (.i({32'hFFFFFFFF,a[WID-1:0]}),.o(locnt));
  	end
	endcase
  case(WID)
  16:	
  	begin
  	ffo24 uffo16 (.i({8'h00,a[WID-1:0]}),.o(lzcnt));
  	end
  32:
  	begin
  	ffo48 uffo32 (.i({16'h0000,a[WID-1:0]}),.o(lzcnt));
  	end
  64:
  	begin
  	ffo96 uffo64 (.i({32'h00000000,a[WID-1:0]}),.o(lzcnt));
  	end
  128:
  	begin
  	ffo144 uffo128 (.i({16'h0000,a[WID-1:0]}),.o(lzcnt));
  	end
  default:
  	begin
  	ffo96 uffo64 (.i({32'h00000000,a[WID-1:0]}),.o(lzcnt));
  	end
	endcase
  case(WID)
  16:	
  	begin
  	flo24 uflo16 (.i({8'hFF,a[WID-1:0]}),.o(tzcnt));
  	end
  32:
  	begin
  	flo48 uflo32 (.i({16'hFFFF,a[WID-1:0]}),.o(tzcnt));
  	end
  64:
  	begin
  	flo96 uflo64 (.i({32'hFFFFFFFF,a[WID-1:0]}),.o(tzcnt));
  	end
  128:
  	begin
  	flo144 uflo128 (.i({16'hFFFF,a[WID-1:0]}),.o(tzcnt));
  	end
  default:
  	begin
  	flo96 uflo64 (.i({32'hFFFFFFFF,a[WID-1:0]}),.o(tzcnt));
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
		assign info = {WID{1'b0}};
	end
	else begin
		if (SUPPORT_INFO) begin
			Qupls5_info uinfo1 (
				.ndx(a[4:0]+b[4:0]+ir[26:22]),
				.coreno(coreno),
				.thread(pc.stream.thread),
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

reg [2:0] dt;

always_comb
begin
	did_op = FALSE;
	exc = Qupls5_pkg::FLT_NONE;
	bus = {(WID/16){16'h0000}};
	o_flags = t_flags;
	dt = 3'd0;
	elesz = (velsz >> {dt,3'b0}) & 8'hff;
	cr = 3'b0;
	case(elesz)
	8'd8:	base_eleno = {chunk,3'd0};
	8'd16:base_eleno = {chunk,2'd0};
	8'd32:base_eleno = {chunk,1'd0};
	8'd64:base_eleno = chunk;
	endcase
	mask1 = c >> base_eleno;
	case(ir.opcode)
	Qupls5_pkg::OP_PPC_CMPI:
		begin
			aa = ir.l ? a : {{32{a[31]}},a[31:0]};
			if ($signed(aa) < $signed({{48{i[15]}},i[15:0]})) cr = 3'b100;
			else if ($signed(aa) > $signed({{48{i[15]}},i[15:0]})) cr = 3'b010;
			else cr = 3'b001;
			bus = t;
			casez(ir.bo)
			5'b000??:	bus[31:28] = {cr,b[31]};	// b[31]=XER.SO
			5'b001??:	bus[27:24] = {cr,b[31]};	// b[31]=XER.SO
			5'b010??:	bus[23:20] = {cr,b[31]};	// b[31]=XER.SO
			5'b011??:	bus[19:16] = {cr,b[31]};	// b[31]=XER.SO
			5'b100??:	bus[15:12] = {cr,b[31]};	// b[31]=XER.SO
			5'b101??:	bus[11: 8] = {cr,b[31]};	// b[31]=XER.SO
			5'b110??:	bus[ 7: 4] = {cr,b[31]};	// b[31]=XER.SO
			5'b111??:	bus[ 3: 0] = {cr,b[31]};	// b[31]=XER.SO
			endcase
		end
	Qupls5_pkg::OP_PPC_CMPLI:
		begin
			aa = ir.l ? a : {{32{1'b0}},a[31:0]};
			if (aa < {{48{1'b0}},i[15:0]}) cr = 3'b100;
			else if (aa > {{{1'b0}},i[15:0]}) cr = 3'b010;
			else cr = 3'b001;
			bus = t;
			casez(ir.bo)
			5'b000??:	bus[31:28] = {cr,b[31]};	// b[31]=XER.SO
			5'b001??:	bus[27:24] = {cr,b[31]};
			5'b010??:	bus[23:20] = {cr,b[31]};
			5'b011??:	bus[19:16] = {cr,b[31]};
			5'b100??:	bus[15:12] = {cr,b[31]};
			5'b101??:	bus[11: 8] = {cr,b[31]};
			5'b110??:	bus[ 7: 4] = {cr,b[31]};
			5'b111??:	bus[ 3: 0] = {cr,b[31]};
			endcase
		end
	Qupls5_pkg::OP_PPC_ADDI:
		begin
			bus = a + {{48{i[15]}},i[15:0]};
			cy = bus[WID];
			did_op = TRUE;
		end
	Qupls5_pkg::OP_PPC_ADDIS:
		begin
			bus = a + {{32{i[15]}},i[15:0],16'd0};
			cy = bus[WID];
			did_op = TRUE;
		end
	Qupls5_pkg::OP_PPC_ADDIC,
	Qupls5_pkg::OP_PPC_ADDICR:
		begin
			bus = a + {{48{i[15]}},i[15:0]};
			cy = bus[WID];
			if (ir.bo==5'd1) begin
				bus = b;
				if (fnAddOverflow(a + {{48{i[15]}},i[15:0]},a,{{48{i[15]}},i[15:0]}))
					bus[31] = 1'b1;
				bus[30] = fnAddOverflow(a + {{48{i[15]}},i[15:0]},a,{{48{i[15]}},i[15:0]});
				bus[29] = cy;
				bus[20] = bus[31];	// 32-bit overflow flag
				bus[19] = bus[30];	
				bus[18] = cy;				// 32-bit carry flag
			end
			did_op = TRUE;
		end
	Qupls5_pkg::OP_PPC_SUBFIC:
		begin
			bus = {{48{i[15]}},i[15:0]} - a;
			cy = bus[WID];
			if (ir.bo==5'd1) begin
				bus = b;
				if (fnSubOverflow({{48{i[15]}},i[15:0]} - a,{{48{i[15]}},i[15:0]},a))
					bus[31] = 1'b1;
				bus[30] = fnSubOverflow({{48{i[15]}},i[15:0]} - a,{{48{i[15]}},i[15:0]},a);
				bus[29] = cy;
				bus[20] = bus[31];	// 32-bit overflow flag
				bus[19] = bus[30];	
				bus[18] = cy;				// 32-bit carry flag
			end
			did_op = TRUE;
		end
	Qupls5_pkg::OP_PPC_ANDI:
		begin
			bus = a & {{48{1'b0}},i[15:0]};
			did_op = TRUE;
		end
	Qupls5_pkg::OP_PPC_ANDIS:
		begin
			bus = a & {{48{1'b0}},i[15:0],16'd0};
			did_op = TRUE;
		end
	Qupls5_pkg::OP_PPC_ORI:
		begin
			bus = a | i[15:0];
			did_op = TRUE;
		end
	Qupls5_pkg::OP_PPC_ORIS:
		begin
			bus = a | {{48{1'b0}},i[15:0],16'd0};
			did_op = TRUE;
		end
	Qupls5_pkg::OP_PPC_XORI:
		begin
			bus = a ^ i[15:0];
			did_op = TRUE;
		end
	Qupls5_pkg::OP_PPC_XORIS:
		begin
			bus = a ^ {{48{1'b0}},i[15:0],16'd0};
			did_op = TRUE;
		end
	Qupls5_pkg::OP_PPC_RLWINM,
	Qupls5_pkg::OP_PPC_RLWNM,
	Qupls5_pkg::OP_PPC_RLWIMI,
	Qupls5_pkg::OP_PPC_RLDIC:
		begin
			bus = bfldo;
			did_op = TRUE;
		end
	Qupls5_pkg::OP_31:
		casez(ir.func)
		Qupls5_pkg::FN31_MTSPR:
			begin
				bus = a;
				did_op = TRUE;
			end
		Qupls5_pkg::FN31_ADD,Qupls5_pkg::FN31_ADDO:
			begin
				if (ir.l) begin
					aa = a;
					bb = b;
					bus = a + b;
				end
				else begin
					aa = {{32{a[31]}},a[31:0]};
					bb = {{32{b[31]}},b[31:0]};
				end
				bus = aa + bb;
				cy = bus[WID];
				if (ir.l)
					ov = fnAddOverflow(aa + bb,aa,bb);
				else
					ov = fnAddOverflow(aa + bb,aa[31:0],bb[31:0]);
				if (ir.bo==5'd1) begin
					bus = c;
					if (ov)
						bus[31] = 1'b1;
					bus[30] = ov;
					bus[29] = cy;
					bus[20] = bus[31];	// 32-bit overflow flag
					bus[19] = bus[30];	
					bus[18] = cy;				// 32-bit carry flag
				end
				did_op = TRUE;
			end
		Qupls5_pkg::FN31_NEG,Qupls5_pkg::FN31_NEGO:
			begin
				if (ir.l)
					aa = a;
				else
					aa = {{32{a[31]}},a[31:0]};
				cy = 1'b0;
				if (ir.l) begin
					ov = aa==64'h8000000000000000;
					bus = ~aa + 1;
				end
				else begin
					ov = aa==32'h80000000;
					bus = ~aa + 1;
					bus[63:32] = 32'd0;
				end
				if (ir.bo==5'd1) begin
					bus = b;
					if (ov)
						bus[31] = 1'b1;
					bus[30] = ov;
					bus[20] = bus[31];	// 32-bit overflow flag
					bus[19] = bus[30];	
				end
				did_op = TRUE;
			end
		Qupls5_pkg::FN31_CMP:
			begin
				aa = ir.l ? a : {{32{a[31]}},a[31:0]};
				bb = ir.l ? b : {{32{b[31]}},b[31:0]};
				if ($signed(aa) < $signed(bb)) cr = 3'b100;
				else if ($signed(aa) > $signed(bb)) cr = 3'b010;
				else cr = 3'b001;
				bus = t;
				casez(ir.bo)
				5'b000??:	bus[31:28] = {cr,c[31]};	// b[31]=XER.SO
				5'b001??:	bus[27:24] = {cr,c[31]};
				5'b010??:	bus[23:20] = {cr,c[31]};
				5'b011??:	bus[19:16] = {cr,c[31]};
				5'b100??:	bus[15:12] = {cr,c[31]};
				5'b101??:	bus[11: 8] = {cr,c[31]};
				5'b110??:	bus[ 7: 4] = {cr,c[31]};
				5'b111??:	bus[ 3: 0] = {cr,c[31]};
				endcase
				did_op = TRUE;
			end
		Qupls5_pkg::FN31_CMPL:
			begin
				aa = ir.l ? a : {32'd0,a[31:0]};
				bb = ir.l ? b : {32'd0,b[31:0]};
				if (aa < bb) cr = 3'b100;
				else if (aa > bb) cr = 3'b010;
				else cr = 3'b001;
				bus = t;
				casez(ir.bo)
				5'b000??:	bus[31:28] = {cr,c[31]};	// b[31]=XER.SO
				5'b001??:	bus[27:24] = {cr,c[31]};
				5'b010??:	bus[23:20] = {cr,c[31]};
				5'b011??:	bus[19:16] = {cr,c[31]};
				5'b100??:	bus[15:12] = {cr,c[31]};
				5'b101??:	bus[11: 8] = {cr,c[31]};
				5'b110??:	bus[ 7: 4] = {cr,c[31]};
				5'b111??:	bus[ 3: 0] = {cr,c[31]};
				endcase
				did_op = TRUE;
			end
		Qupls5_pkg::FN31_AND:
			begin
				bus = a & b;
				did_op = TRUE;
			end
		Qupls5_pkg::FN31_ANDC:
			begin
				bus = a & ~b;
				did_op = TRUE;
			end
		Qupls5_pkg::FN31_OR:
			begin
				bus = a | b;
				did_op = TRUE;
			end
		Qupls5_pkg::FN31_ORC:
			begin
				bus = a | ~b;
				did_op = TRUE;
			end
		Qupls5_pkg::FN31_XOR:
			begin
				bus = a ^ b;
				did_op = TRUE;
			end
		Qupls5_pkg::FN31_EQV:
			begin
				bus = ~(a ^ b);
				did_op = TRUE;
			end
		Qupls5_pkg::FN31_NAND:
			begin
				bus = ~(a & b);
				did_op = TRUE;
			end
		Qupls5_pkg::FN31_NOR:
			begin
				bus = ~(a | b);
				did_op = TRUE;
			end
		10'b??????1111:	// ISEL
			begin
				bus = c[ir.func[10:5]] ? a : b;
				did_op = TRUE;
			end
		endcase
/*
				did_op = TRUE;
				o_flags.inx = FALSE;
				o_flags.unf = FALSE;
				o_flags.ovf = FALSE;
				o_flags.dbz = FALSE;
				o_flags.inv = FALSE;
				o_flags.cry = FALSE;
				o_flags.ptr = FALSE;
				o_flags.cap = FALSE;
			end
*/			
	default:	bus = {(WID/16){16'hDEAD}};
	endcase
end

always_ff @(posedge clk)
	case(WID)
	8: o = bus;
	16:	o = bus;
	32:	o = bus_nan ? bus | (fnBitRev({64'd0,pc.cap.offset}) >> 6'd48) : bus;
	64:	o = bus_nan ? bus | (fnBitRev({64'd0,pc.cap.offset}) >> 6'd20) : bus;
	128:	o = bus_nan ? bus | fnBitRev({64'd0,pc.cap.offset}) : bus;
	default:	o = zero;
	endcase

always_ff @(posedge clk)
	if (!did_op)
		exc_o = Qupls5_pkg::FLT_UNIMP;
	else
		exc_o = exc;

endmodule
