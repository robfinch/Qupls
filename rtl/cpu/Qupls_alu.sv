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
// 3600 LUTs / 1100 FFs	ALU0
// 3100 LUTs / 700 FFs	
// ============================================================================

import const_pkg::*;
import QuplsPkg::*;

module Qupls_alu(rst, clk, clk2x, ld, ir, div, a, b, bi, c, i, t, qres,
	cs, pc, csr, cpl, coreno, canary, o, mul_done, div_done, div_dbz, exc);
parameter ALU0 = 1'b0;
parameter WID=16;
parameter LANE=0;
input rst;
input clk;
input clk2x;
input ld;
input instruction_t ir;
input div;
input [WID-1:0] a;
input [WID-1:0] b;
input [WID-1:0] bi;
input [WID-1:0] c;
input [WID-1:0] i;
input [WID-1:0] t;
input [WID-1:0] qres;
input [2:0] cs;
input cpu_types_pkg::pc_address_t pc;
input [WID-1:0] csr;
input [7:0] cpl;
input [WID-1:0] coreno;
input [WID-1:0] canary;
output reg [WID-1:0] o;
output reg mul_done;
output div_done;
output div_dbz;
output cause_code_t exc;

genvar g;
integer nn,kk;
value_t zero = {WID{1'b0}};
value_t dead = {WID/16{16'hdead}};
wire cd_args;
value_t cc;
reg [3:0] mul_cnt;
reg [WID*2-1:0] prod, prod1, prod2;
reg [WID*2-1:0] produ, produ1, produ2;
reg [WID*2-1:0] shl, shr, asr;
wire [WID-1:0] div_q, div_r;
wire [WID-1:0] cmpo;
reg [WID-1:0] bus;
reg [WID-1:0] blendo;
reg [WID-1:0] immc8;
reg [22:0] ii;
reg [WID-1:0] sd;
reg [WID-1:0] sum_ab;
reg [WID-1:0] chndx;
reg [WID-1:0] chndx2;
reg [WID-1:0] chrndxv;
wire [WID-1:0] info;
wire [WID-1:0] vmasko;

always_comb
	ii = {{6{i[WID-1]}},i};
always_comb
	sum_ab = a + b;

always_comb
	immc8 = {{WID{ir[29]}},ir[29:22]};
always_comb
	shl = {b,ir[38] ? ~a : a} << (ir[37] ? ir[34:29] : c[5:0]);
always_comb
	shr = {ir[38] ? ~b : b,a} >> (ir[37] ? ir[34:29] : c[5:0]);
always_comb
	asr = {{64{a[63]}},a,64'd0} >> (ir[37] ? ir[34:29] : c[5:0]);

always_ff @(posedge clk)
begin
	prod2 <= $signed(a) * $signed(bi);
	prod1 <= prod2;
	prod <= prod1;
end
always_ff @(posedge clk)
begin
	produ2 <= a * bi;
	produ1 <= produ2;
	produ <= produ1;
end

always_ff @(posedge clk)
if (rst) begin
	mul_cnt <= 4'hF;
	mul_done <= 1'b0;
end
else begin
	mul_cnt <= {mul_cnt[2:0],1'b1};
	if (ld)
		mul_cnt <= 4'd0;
	mul_done <= mul_cnt[3];
end

Qupls_cmp #(.WID(WID)) ualu_cmp(ir, a, b, cmpo);

Qupls_divider #(.WID(WID)) udiv0(
	.rst(rst),
	.clk(clk2x),
	.ld(ld),
	.sgn(div),
	.sgnus(1'b0),
	.a(a),
	.b(bi),
	.qo(div_q),
	.ro(div_r),
	.dvByZr(div_dbz),
	.done(div_done),
	.idle()
);

generate begin : gInfoBlend
	if (WID != 64) begin
		assign blendo = {WID{1'b0}};
		assign info = {WID{1'b0}};
	end
	else begin
		if (ALU0) begin
			Qupls_info uinfo1 (
				.ndx(a[4:0]+b[4:0]+ir[26:22]),
				.coreno(coreno),
				.o(info)
			);
			Qupls_setvmask usm1 (
				.max_ele_sz($bits(value_t)),
				.numlanes(a[6:0]),
				.lanesz(b[5:0]|i[4:0]),
				.mask(vmasko)
			);
		end

		Qupls_blend ublend0
		(
			.a(c),
			.c0(a),
			.c1(bi),
			.o(blendo)
		);
	end
end
endgenerate

always_comb
	case(ir[32:31])
	2'd0:	chrndxv = a;
	2'd1:	chrndxv = {8{i[7:0]}} & a;
	2'd2:	chrndxv = {8{i[7:0]}} | a;
	2'd3:	chrndxv = {8{i[7:0]}} ^ a;
	endcase

generate begin : gChrndx
	for (g = WID/8-1; g >= 0; g = g - 1) begin
		always_comb
		begin
			if (g==WID/8-1)
				chndx[g] = 1'b0;
			if (b[g*8+7:g*8]==chrndxv[g*8+7:g*8])
				chndx[g] = 1'b1;
		end
	end
end
endgenerate

flo96 uflo1 (.i({96'd0,chndx[WID/8-1:0]}), .o(chndx2[6:0]));

always_comb
begin
	exc = FLT_NONE;
	bus = {(WID/16){16'h0000}};
	case(ir.any.opcode)
	OP_CHK:
		case(ir[47:44])
		4'd0:	if (!(a >= b && a < c)) exc = cause_code_t'(ir[34:27]);
		4'd1: if (!(a >= b && a <= c)) exc = cause_code_t'(ir[34:27]);
		4'd2: if (!(a > b && a < c)) exc = cause_code_t'(ir[34:27]);
		4'd3: if (!(a > b && a <= c)) exc = cause_code_t'(ir[34:27]);
		4'd4:	if (a >= b && a < c) exc = cause_code_t'(ir[34:27]);
		4'd5: if (a >= b && a <= c) exc = cause_code_t'(ir[34:27]);
		4'd6: if (a > b && a < c) exc = cause_code_t'(ir[34:27]);
		4'd7: if (a > b && a <= c) exc = cause_code_t'(ir[34:27]);
		4'd8:	if (!(a >= cpl)) exc = cause_code_t'(ir[34:27]);
		4'd9:	if (!(a <= cpl)) exc = cause_code_t'(ir[34:27]);
		4'd10:	if (!(a==canary)) exc = cause_code_t'(ir[34:27]);
		default:	exc = FLT_UNIMP;
		endcase
	OP_R2:
		case(ir.r2.func)
		FN_CPUID:	bus = ALU0 ? info : 64'd0;
		FN_ADD:
			case(ir.r2.op2)
			3'd0:	bus = (a + b) & c;
			3'd1: bus = (a + b) | c;
			3'd2: bus = (a + b) ^ c;
			3'd3:	bus = (a + b) + c;
			/*
			4'd9:	bus = (a + b) - c;
			4'd10: bus = (a + b) + c + 2'd1;
			4'd11: bus = (a + b) + c - 2'd1;
			4'd12:
				begin
					sd = (a + b) + c;
					bus = sd[WID-1] ? -sd : sd;
				end
			4'd13:
				begin
					sd = (a + b) - c;
					bus = sd[WID-1] ? -sd : sd;
				end
			*/
			default:	bus = {WID{1'd0}};
			endcase
		FN_SUB:	bus = a - b - c;
		FN_CMP,FN_CMPU:	
			case(ir.r2.op2)
			3'd1:	bus = cmpo & c;
			3'd2:	bus = cmpo | c;
			3'd3:	bus = cmpo ^ c;
			default:	bus = cmpo;
			endcase
		FN_MUL:	bus = prod[WID-1:0];
		FN_MULU:	bus = produ[WID-1:0];
		FN_MULW:	bus = ALU0 ? prod[WID-1:0] : prod[WID*2-1:WID];
		FN_MULUW:	bus = ALU0 ? produ[WID-1:0] : produ[WID*2-1:WID];
		FN_DIV: bus = ALU0 ? div_q : dead;
		FN_MOD: bus = ALU0 ? div_r : dead;
		FN_DIVU: bus = ALU0 ? div_q : dead;
		FN_MODU: bus = ALU0 ? div_r : dead;
		FN_AND:	
			case(ir.r2.op2)
			3'd0:	bus = (a & b) & c;
			3'd1: bus = (a & b) | c;
			3'd2: bus = (a & b) ^ c;
			default:	bus = {WID{1'd0}};
			endcase
		FN_OR:
			case(ir.r2.op2)
			3'd0:	bus = (a | b) & c;
			3'd1: bus = (a | b) | c;
			3'd2: bus = (a | b) ^ c;
			3'd7:	bus = (a & b) | (a & c) | (b & c);
			default:	bus = {WID{1'd0}};
			endcase
		FN_EOR:	
			case(ir.r2.op2)
			3'd0:	bus = (a ^ b) & c;
			3'd1: bus = (a ^ b) | c;
			3'd2: bus = (a ^ b) ^ c;
			3'd7:	bus = (^a) ^ (^b) ^ (^c);
			default:	bus = {WID{1'd0}};
			endcase
		FN_CMOVZ: bus = a ? c : b;
		FN_CMOVNZ:	bus = a ? b : c;
		FN_NAND:
			case(ir.r2.op2)
			3'd0:	bus = ~(a & b) & c;
			3'd1: bus = ~(a & b) | c;
			3'd2: bus = ~(a & b) ^ c;
			default:	bus = {WID{1'd0}};
			endcase
		FN_NOR:
			case(ir.r2.op2)
			3'd0:	bus = ~(a | b) & c;
			3'd1: bus = ~(a | b) | c;
			3'd2: bus = ~(a | b) ^ c;
			default:	bus = {WID{1'd0}};
			endcase
		FN_ENOR:
			case(ir.r2.op2)
			3'd0:	bus = ~(a ^ b) & c;
			3'd1: bus = ~(a ^ b) | c;
			3'd2: bus = ~(a ^ b) ^ c;
			default:	bus = {WID{1'd0}};
			endcase
			
		FN_BYTENDX:	bus = ALU0 ? chndx2 : dead;

		FN_SEQ:	bus = a==b ? c : t;
		FN_SNE:	bus = a!=b ? c : t;
		FN_SLT:	bus = $signed(a) < $signed(b) ? c : t;
		FN_SLE:	bus = $signed(a) <= $signed(b) ? c : t;
		FN_SLTU:	bus = a < b ? c : t;
		FN_SLEU: 	bus = a <= b ? c : t;

		FN_SEQI8:	bus = a == b ? immc8 : t;
		FN_SNEI8:	bus = a != b ? immc8 : t;
		FN_SLTI8:	bus = $signed(a) < $signed(b) ? immc8 : t;
		FN_SLEI8:	bus = $signed(a) <= $signed(b) ? immc8 : t;
		FN_SLTUI8:	bus = a < b ? immc8 : t;
		FN_SLEUI8:	bus = a <= b ? immc8 : t;

		FN_ZSEQ:	bus = a==b ? c : zero;
		FN_ZSNE:	bus = a!=b ? c : zero;
		FN_ZSLT:	bus = $signed(a) < $signed(b) ? c : zero;
		FN_ZSLE:	bus = $signed(a) <= $signed(b) ? c : zero;
		FN_ZSLTU:	bus = a < b ? c : zero;
		FN_ZSLEU:	bus = a <= b ? c : zero;

		FN_ZSEQI8: bus = a==b ? immc8 : zero;
		FN_ZSNEI8:	bus = a!=b ? immc8 : zero;
		FN_ZSLTI8:	bus = $signed(a) < $signed(b) ? immc8 : zero;
		FN_ZSLEI8:	bus = $signed(a) <= $signed(b) ? immc8 : zero;
		FN_ZSLTUI8:	bus = a < b ? immc8 : zero;
		FN_ZSLEUI8:	bus = a <= b ? immc8 : zero;

		FN_MINMAX:
			case(ir.r3.op2)
			3'd0:	// MIN
				begin
					if ($signed(a) < $signed(b) && $signed(a) < $signed(c))
						bus = a;
					else if ($signed(b) < $signed(c))
						bus = b;
					else
						bus = c;
				end
			3'd1:	// MAX
				begin
					if ($signed(a) > $signed(b) && $signed(a) > $signed(c))
						bus = a;
					else if ($signed(b) > $signed(c))
						bus = b;
					else
						bus = c;
				end
			3'd2:	// MID
				begin
					if ($signed(a) > $signed(b) && $signed(a) < $signed(c))
						bus = a;
					else if ($signed(b) > $signed(a) && $signed(b) < $signed(c))
						bus = b;
					else
						bus = c;
				end
			3'd4:	// MINU
				begin
					if (a < b && a < c)
						bus = a;
					else if (b < c)
						bus = b;
					else
						bus = c;
				end
			3'd5:	// MAXU
				begin
					if (a > b && a > c)
						bus = a;
					else if (b > c)
						bus = b;
					else
						bus = c;
				end
			3'd6:	// MIDU
				begin
					if (a > b && a < c)
						bus = a;
					else if (b > a && b < c)
						bus = b;
					else
						bus = c;
				end
			default:	bus = {4{32'hDEADBEEF}};
			endcase
		FN_MVVR:	bus = a;
		FN_VSETMASK:	bus = ALU0 ? vmasko : dead;
		default:	bus = {4{32'hDEADBEEF}};
		endcase
	OP_CSR:		bus = csr;
	OP_ADDI:
		bus = a + i;
	OP_SUBFI:	bus = i - a;
	OP_CMPI:
		bus = cmpo;
	OP_CMPUI:	bus = cmpo;
	OP_MULI:
		bus = prod[WID-1:0];
	OP_MULUI:	bus = produ[WID-1:0];
	OP_DIVI:
		begin
			bus = ALU0 ? div_q : dead;
			if (div_dbz)
				exc = FLT_DBZ;
		end
	OP_DIVUI:	bus = ALU0 ? div_q : dead;
	OP_ANDI:
		bus = a & i;
	OP_ORI:
		bus = a | i;
	OP_EORI:
		bus = a ^ i;
	OP_AIPSI:
		bus = pc + ({{WID{i[23]}},i[23:0]} << (ir[17:15]*24));
	OP_ADDSI:
		bus = c + ({{WID{i[23]}},i[23:0]} << (ir[17:15]*24));
	OP_ANDSI:
		bus = c & ({WID{1'b1}} & ~({{WID{1'b0}},24'hffffff} << (ir[17:15]*24)) | ({{WID{i[23]}},i[23:0]} << (ir[17:15]*24)));
	OP_ORSI:
		bus = c | (i << (ir[17:15]*24));
	OP_EORSI:
		bus = c ^ (i << (ir[17:15]*24));
	OP_SHIFT:
		case(ir.shifti.func)
		OP_ASL:	bus = shl[WID*2-1:WID];
		OP_LSR:	bus = shr[WID-1:0];
		OP_ASR:	
			case(ir[42:41])
			2'd0:	bus = asr[WID*2-1:WID];
			2'd1: bus = asr[WID*2-1] ? asr[WID*2-1:WID] + asr[WID-1] : asr[WID*2-1:WID];
			2'd2: bus = asr[WID*2-1:WID] + asr[WID-1];
			default:	bus = asr[WID*2-1:WID];
			endcase
		default:	bus = {(WID/16){16'hDEAD}};
		endcase

	OP_ZSEQI:	bus = a==i;
	OP_ZSNEI:	bus = a!=i;
	OP_ZSLTI:	bus = $signed(a) < $signed(i);
	OP_ZSLEI:	bus = $signed(a) <= $signed(i);
	OP_ZSLTUI:	bus = a < i;
	OP_ZSLEUI:	bus = a <= i;
	OP_ZSGTI: bus = $signed(a) > $signed(i);
	OP_ZSGEI: bus = $signed(a) >= $signed(i);
	OP_ZSGTUI: bus = a > i;
	OP_ZSGEUI: bus = a >= i;
	OP_SEQI:	bus = a==i ? 64'd1 : t;
	OP_SNEI:	bus = a!=i ? 64'd1 : t;
	OP_SLTI:	bus = $signed(a) < $signed(i) ? 64'd1 : t;
	OP_SLEI:	bus = $signed(a) <= $signed(i) ? 64'd1 : t;
	OP_SLTUI:	bus = a < i ? 64'd1 : t;
	OP_SLEUI:	bus = a <= i ? 64'd1 : t;
	OP_SGTI: bus = $signed(a) > $signed(i) ? 64'd1 : t;
	OP_SGEI: bus = $signed(a) >= $signed(i) ? 64'd1 : t;
	OP_SGTUI: bus = a > i ? 64'd1 : t;
	OP_SGEUI: bus = a >= i ? 64'd1 : t;

	OP_MOV:		bus = a;
	OP_LDAX:	bus = a + i + (b << ir[26:25]);
	OP_BLEND:	bus = ALU0 ? blendo : dead;
	OP_NOP:		bus = zero;
	OP_QFEXT:	bus = qres;
	// Write the next PC to the link register.
	OP_BSR,OP_JSR:
						bus = pc + 4'd6;
	OP_Bcc,OP_BccU:
		case(ir.br.inc)
		2'd0:	bus = a;
		2'd1:	bus = a + 2'd1;
		2'd3:	bus = a - 2'd1;
		2'd2:	bus = a;
		endcase
	OP_PRED:	bus = a;
	default:	bus = {(WID/16){16'hDEAD}};
	endcase
end

always_comb
	o = bus;

endmodule
