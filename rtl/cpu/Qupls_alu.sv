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

module Qupls_alu(rst, clk, clk2x, ld, ir, div, cptgt, z, a, b, bi, c, i, t, qres,
	cs, pc, csr, o, mul_done, div_done, div_dbz);
parameter ALU0 = 1'b0;
parameter WID=16;
parameter LANE=0;
input rst;
input clk;
input clk2x;
input ld;
input instruction_t ir;
input div;
input cptgt;
input z;
input [WID-1:0] a;
input [WID-1:0] b;
input [WID-1:0] bi;
input [WID-1:0] c;
input [WID-1:0] i;
input [WID-1:0] t;
input [WID-1:0] qres;
input [2:0] cs;
input pc_address_t pc;
input [WID-1:0] csr;
output reg [WID-1:0] o;
output reg mul_done;
output div_done;
output div_dbz;

value_t zero = {WID{1'b0}};
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
reg [WID-1:0] immc6;
reg [22:0] ii;
reg [WID-1:0] sd;
reg [WID-1:0] sum_ab;

always_comb
	ii = {{6{i[WID-1]}},i};
always_comb
	sum_ab = a + b;

always_comb
	immc6 = {{WID{ir[26]}},ir[27:22]};
always_comb
	shl = {b,ir[33] ? ~a : a} << (ir[32] ? ir[27:22] : c[5:0]);
always_comb
	shr = {ir[33] ? ~b : b,a} >> (ir[32] ? ir[27:22] : c[5:0]);
always_comb
	asr = {{64{a[63]}},a,64'd0} >> (ir[32] ? ir[27:22] : c[5:0]);

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
begin
	mul_cnt <= {mul_cnt[2:0],1'b1};
	if (ld)
		mul_cnt <= 'd0;
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

generate begin : gBlend
	if (WID != 64) begin
		assign blendo = {WID{1'b0}};
	end
	else begin
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
begin
	bus = {(WID/16){16'h0000}};
	case(ir.any.opcode)
	OP_R2,OP_R3V,OP_R3VS:
		case(ir.r2.func)
		FN_ADD:
			case(ir[30:27])
			4'd0:	bus = (a + b) & c;
			4'd1:	bus = (a + b) & ~c;
			4'd2: bus = (a + b) | c;
			4'd3: bus = (a + b) | ~c;
			4'd4: bus = (a + b) ^ c;
			4'd5:	bus = (a + b) ^ ~c;
			4'd8:	bus = (a + b) + c;
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
			default:	bus = {WID{1'd0}};
			endcase
		FN_SUB:	bus = a - b - c;
		FN_CMP,FN_CMPU:	
			case(ir[30:27])
			4'd1:			bus = cmpo | c;
			default:	bus = cmpo;
			endcase
		FN_MUL:	bus = prod[WID-1:0];
		FN_MULU:	bus = produ[WID-1:0];
		FN_MULW:	bus = ALU0 ? prod[WID-1:0] : prod[WID*2-1:WID];
		FN_MULUW:	bus = ALU0 ? produ[WID-1:0] : produ[WID*2-1:WID];
		FN_DIV: bus = ALU0 ? div_q : zero;
		FN_MOD: bus = ALU0 ? div_r : zero;
		FN_DIVU: bus = ALU0 ? div_q : zero;
		FN_MODU: bus = ALU0 ? div_r : zero;
		FN_AND:	
			case(ir[30:27])
			4'd0:	bus = (a & b) & c;
			4'd1:	bus = (a & b) & ~c;
			4'd2: bus = (a & b) | c;
			4'd3: bus = (a & b) | ~c;
			4'd4: bus = (a & b) ^ c;
			4'd5:	bus = (a & b) ^ ~c;
			default:	bus = {WID{1'd0}};
			endcase
		FN_OR:
			case(ir[30:27])
			4'd0:	bus = (a | b) & c;
			4'd1:	bus = (a | b) & ~c;
			4'd2: bus = (a | b) | c;
			4'd3: bus = (a | b) | ~c;
			4'd4: bus = (a | b) ^ c;
			4'd5:	bus = (a | b) ^ ~c;
			default:	bus = {WID{1'd0}};
			endcase
		FN_EOR:	
			case(ir[30:27])
			4'd0:	bus = (a ^ b) & c;
			4'd1:	bus = (a ^ b) & ~c;
			4'd2: bus = (a ^ b) | c;
			4'd3: bus = (a ^ b) | ~c;
			4'd4: bus = (a ^ b) ^ c;
			4'd5:	bus = (a ^ b) ^ ~c;
			default:	bus = {WID{1'd0}};
			endcase
		FN_CMOVZ: bus = a ? c : b;
		FN_CMOVNZ:	bus = a ? b : c;
		FN_NAND:
			case(ir[30:27])
			4'd0:	bus = ~((a & b) & c);
			4'd1:	bus = ~((a & b) & ~c);
			4'd2: bus = ~((a & b) | c);
			4'd3: bus = ~((a & b) | ~c);
			4'd4: bus = ~((a & b) ^ c);
			4'd5:	bus = ~((a & b) ^ ~c);
			default:	bus = {WID{1'd0}};
			endcase
		FN_NOR:
			case(ir[30:27])
			4'd0:	bus = ~((a | b) & c);
			4'd1:	bus = ~((a | b) & ~c);
			4'd2: bus = ~((a | b) | c);
			4'd3: bus = ~((a | b) | ~c);
			4'd4: bus = ~((a | b) ^ c);
			4'd5:	bus = ~((a | b) ^ ~c);
			default:	bus = {WID{1'd0}};
			endcase
		FN_ENOR:
			case(ir[30:27])
			4'd0:	bus = ~((a ^ b) & c);
			4'd1:	bus = ~((a ^ b) & ~c);
			4'd2: bus = ~((a ^ b) | c);
			4'd3: bus = ~((a ^ b) | ~c);
			4'd4: bus = ~((a ^ b) ^ c);
			4'd5:	bus = ~((a ^ b) ^ ~c);
			default:	bus = {WID{1'd0}};
			endcase

		FN_SEQ:	bus = a==b ? c : t;
		FN_SNE:	bus = a!=b ? c : t;
		FN_SLT:	bus = $signed(a) < $signed(b) ? c : t;
		FN_SLE:	bus = $signed(a) <= $signed(b) ? c : t;
		FN_SLTU:	bus = a < b ? c : t;
		FN_SLEU: 	bus = a <= b ? c : t;

		FN_SEQI:	bus = a == b ? immc6 : t;
		FN_SNEI:	bus = a != b ? immc6 : t;
		FN_SLTI:	bus = $signed(a) < $signed(b) ? immc6 : t;
		FN_SLEI:	bus = $signed(a) <= $signed(b) ? immc6 : t;
		FN_SLTUI:	bus = a < b ? immc6 : t;
		FN_SLEUI:	bus = a <= b ? immc6 : t;

		FN_ZSEQ:	bus = a==b ? c : zero;
		FN_ZSNE:	bus = a!=b ? c : zero;
		FN_ZSLT:	bus = $signed(a) < $signed(b) ? c : zero;
		FN_ZSLE:	bus = $signed(a) <= $signed(b) ? c : zero;
		FN_ZSLTU:	bus = a < b ? c : zero;
		FN_ZSLEU:	bus = a <= b ? c : zero;

		FN_ZSEQI: bus = a==b ? immc6 : zero;
		FN_ZSNEI:	bus = a!=b ? immc6 : zero;
		FN_ZSLTI:	bus = $signed(a) < $signed(b) ? immc6 : zero;
		FN_ZSLEI:	bus = $signed(a) <= $signed(b) ? immc6 : zero;
		FN_ZSLTUI:	bus = a < b ? immc6 : zero;
		FN_ZSLEUI:	bus = a <= b ? immc6 : zero;

		FN_MAX3:
			begin
				if ($signed(a) > $signed(b) && $signed(a) > $signed(c))
					bus = a;
				else if ($signed(b) > $signed(c))
					bus = b;
				else
					bus = c;
			end
		FN_MIN3:
			begin
				if ($signed(a) < $signed(b) && $signed(a) < $signed(c))
					bus = a;
				else if ($signed(b) < $signed(c))
					bus = b;
				else
					bus = c;
			end
		FN_MID3:
			begin
				if ($signed(a) > $signed(b) && $signed(a) < $signed(c))
					bus = a;
				else if ($signed(b) > $signed(a) && $signed(b) < $signed(c))
					bus = b;
				else
					bus = c;
			end
		FN_MIDU3:
			begin
				if (a > b && a < c)
					bus = a;
				else if (b > a && b < c)
					bus = b;
				else
					bus = c;
			end
		FN_MAXU3:
			begin
				if (a > b && a > c)
					bus = a;
				else if (b > c)
					bus = b;
				else
					bus = c;
			end
		FN_MINU3:
			begin
				if (a < b && a < c)
					bus = a;
				else if (b < c)
					bus = b;
				else
					bus = c;
			end
		default:	bus = {4{32'hDEADBEEF}};
		endcase
	OP_CSR:		bus = csr;
	OP_ADDI,OP_VADDI:
		bus = a + i;
	OP_SUBFI:	bus = i - a;
	OP_CMPI,OP_VCMPI:
		bus = cmpo;
	OP_CMPUI:	bus = cmpo;
	OP_MULI,OP_VMULI:
		bus = prod[WID-1:0];
	OP_MULUI:	bus = produ[WID-1:0];
	OP_DIVI,OP_VDIVI:
		bus = ALU0 ? div_q : 0;
	OP_DIVUI:	bus = ALU0 ? div_q : 0;
	OP_ANDI,OP_VANDI:
		bus = a & i;
	OP_ORI,OP_VORI:
		bus = a | i;
	OP_EORI,OP_VEORI:
		bus = a ^ i;
	OP_SLTI:	bus = $signed(a) < $signed(i);
	OP_ADDSI,OP_VADDSI:
		bus = a + ({{WID{ii[22]}},ii[22:0]} << (ir[14:12]*20));
	OP_ANDSI,OP_VANDSI:
		bus = a & ({WID{1'b1}} & ~({{WID{1'b0}},23'h7fffff} << (ir[14:12]*20)) | ({{WID{ii[22]}},ii[22:0]} << (ir[14:12]*20)));
	OP_ORSI,OP_VORSI:
		bus = a | (i << (ir[14:12]*20));
	OP_EORSI,OP_VEORSI:
		bus = a ^ (i << (ir[14:12]*20));
	OP_SHIFT,OP_VSHIFT:
		case(ir.shifti.func)
		OP_ASL:	bus = shl[WID*2-1:WID];
		OP_LSR:	bus = shr[WID-1:0];
		OP_ASR:	
			case(ir[31:30])
			2'd0:	bus = asr[WID*2-1:WID];
			2'd1: bus = asr[WID*2-1] ? asr[WID*2-1:WID] + asr[WID-1] : asr[WID*2-1:WID];
			2'd2: bus = asr[WID*2-1:WID] + asr[WID-1];
			default:	bus = asr[WID*2-1:WID];
			endcase
		default:	bus = {(WID/16){16'hDEAD}};
		endcase
	OP_MOV:		bus = a;
	OP_LDAX:	bus = a + i + (b << ir[26:25]);
	OP_BLEND:	bus = ALU0 ? blendo : 0;
	OP_NOP:		bus = 0;
	OP_QFEXT:	bus = qres;
	OP_PFXA32:	bus = 0;
	OP_PFXB32:	bus = 0;
	OP_PFXC32:	bus = 0;
	// Write the next PC to the link register.
	OP_BSR,OP_JSR:
						bus = pc + 4'd5;
	default:	bus = {(WID/16){16'hDEAD}};
	endcase
end

always_comb
	o = cptgt ? (z ? zero : t) : bus;

endmodule
