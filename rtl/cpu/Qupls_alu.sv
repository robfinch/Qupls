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

module Qupls_alu(rst, clk, clk2x, ld, ir, div, cptgt, z, a, b, bi, c, i, t, qres, cs, pc, csr,
	o, mul_done, div_done, div_dbz);
parameter ALU0 = 1'b0;
input rst;
input clk;
input clk2x;
input ld;
input instruction_t ir;
input div;
input cptgt;
input z;
input value_t a;
input value_t b;
input value_t bi;
input value_t c;
input value_t i;
input value_t t;
input value_t qres;			// quad precision result from fpu
input [2:0] cs;
input pc_address_t pc;
input value_t csr;
output value_t o;
output reg mul_done;
output div_done;
output div_dbz;

wire cd_args;
value_t cc;
reg [3:0] mul_cnt;
double_value_t prod, prod1, prod2;
double_value_t produ, produ1, produ2;
reg [127:0] shl, shr, asr;
value_t div_q, div_r;
value_t cmpo;
value_t bus;
value_t blendo;
value_t immc6;

always_comb
	immc6 = {{58{ir[30]}},ir[30:25]};
always_comb
	shl = {b,ir[33] ? ~a : a} << (ir[32] ? ir[31:25] : c[5:0]);
always_comb
	shr = {ir[33] ? ~b : b,a} >> (ir[32] ? ir[31:25] : c[5:0]);
always_comb
	asr = {{64{a[63]}},a,64'd0} >> (ir[32] ? ir[31:25] : c[5:0]);

always_comb
	case(cs)
	3'd0:	cc = c;			// As is
	3'd1:	cc = -c;		// Two's complement
	3'd2:	cc = ~c;		// One's complement
	3'd3:	cc = {~c[$bits(value_t)-1],c[$bits(value_t)-2:0]};	// Float negate
	default:	cc = c;
	endcase

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

Qupls_cmp ualu_cmp(ir, a, b, cmpo);

Qupls_divider udiv0(
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

Qupls_blend ublend0
(
	.a(c),
	.c0(a),
	.c1(bi),
	.o(blendo)
);

always_comb
begin
	case(ir.any.opcode)
	OP_R2:
		case(ir.r2.func)
		FN_ADD:	
			case(ir[32:31])
			2'd0:	bus = a + b + c;
			2'd2:	bus = a + b + c + 2'd1;
			2'd3: bus = a + b + c - 2'd1;
			default:	bus = 64'd0;
			endcase
		FN_SUB:	
			case(ir[32:31])
			2'd0:	bus = a - b - c;
			2'd2: bus = a - b - c - 2'd1;
			2'd3: bus = a - b - c + 2'd1;
			default:	bus = 64'd0;
			endcase
		FN_CMP:	bus = cmpo;
		FN_CMPU:	bus = cmpo;
		FN_MUL:	bus = prod[63:0];
		FN_MULU:	bus = produ[63:0];
		FN_MULH:	bus = prod[127:64];
		FN_MULUH:	bus = produ[127:64];
		FN_DIV: bus = ALU0 ? div_q : 0;
		FN_MOD: bus = ALU0 ? div_r : 0;
		FN_DIVU: bus = ALU0 ? div_q : 0;
		FN_MODU: bus = ALU0 ? div_r : 0;
		FN_AND:	bus = a & b & ~cc;
		FN_OR:	bus = a | b | cc;
		FN_EOR:	bus = a ^ b ^ cc;
		FN_ANDC:	bus = a & ~b & ~cc;
		FN_NAND:	bus = ~(a & b & ~cc);
		FN_NOR:	bus = ~(a | b | cc);
		FN_ENOR:	bus = ~(a ^ b ^ cc);
		FN_ORC:	bus = a | ~b | cc;
		FN_SEQ:	
			case(ir[32:31])
			2'd1:	bus = a == b ? immc6 : t;
			default:	bus = a == b ? immc6 : 64'd0;
			endcase
		FN_SNE:
			case(ir[32:31])
			2'd1:	bus = a != b ? immc6 : t;
			default:	bus = a != b ? immc6 : 64'd0;
			endcase
		FN_SLT:
			case(ir[32:31])
			2'd1:	bus = $signed(a) < $signed(b) ? immc6 : t;
			default: bus = $signed(a) < $signed(b) ? immc6 : 64'd0;
			endcase
		FN_SLE:	
			case(ir[32:31])
			2'd1: bus = $signed(a) <= $signed(b) ? immc6 : t;
			default: bus = $signed(a) <= $signed(b) ? immc6 : 64'd0;
			endcase
		FN_SLTU:
			case(ir[32:31])
			2'd1:	bus = a < b ? immc6 : t;
			default: bus = a < b ? immc6 : 64'd0;
			endcase
		FN_SLEU:
			case(ir[32:31])
			2'd1: bus = a <= b ? immc6 : t;
			default: bus = a <= b ? immc6 : 64'd0;
			endcase
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
		default:	bus = {2{32'hDEADBEEF}};
		endcase
	OP_CSR:		bus = csr;
	OP_ADDI,OP_VADDI:
		bus = a + i;
	OP_SUBFI:	bus = i - a;
	OP_CMPI,OP_VCMPI:
		bus = cmpo;
	OP_CMPUI:	bus = cmpo;
	OP_MULI,OP_VMULI:
		bus = prod[63:0];
	OP_MULUI:	bus = produ[63:0];
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
	OP_AIPSI:	bus = pc + ({{40{i[23]}},i[23:0]} << (ir[15:13]*20));
	OP_ADDSI,OP_VADDSI:
		bus = a + ({{40{i[23]}},i[23:0]} << (ir[15:13]*20));
	OP_ANDSI,OP_VANDSI:
		bus = a & (64'hffffffffffffffff & ~(64'hffffff << (ir[15:13]*20)) | ({{40{i[23]}},i[23:0]} << (ir[15:13]*20)));
	OP_ORSI,OP_VORSI:
		bus = a | (i << (ir[15:13]*20));
	OP_EORSI,OP_VEORSI:
		bus = a ^ (i << (ir[15:13]*20));
	OP_SHIFT:
		case(ir.shifti.func)
		OP_ASL:	bus = shl[127:64];
		OP_LSR:	bus = shr[63:0];
		OP_ASR:	bus = asr[127:64];
		default:	bus = {2{32'hDEADBEEF}};
		endcase
	OP_MOV:		bus = a;
	OP_LDAX:	bus = a + i + (b << ir[26:25]);
	OP_BLEND:	bus = ALU0 ? blendo : 0;
	OP_NOP:		bus = 0;
	OP_QFEXT:	bus = qres;
	OP_PFXA32:	bus = 0;
	OP_PFXB32:	bus = 0;
	OP_PFXC32:	bus = 0;
	OP_VEC:	bus = 0;
	OP_VECZ:	bus = 0;
	// Write the next PC to the link register.
	OP_BSR,OP_JSR:
						bus = pc + 4'd5;
	default:	bus = {2{32'hDEADBEEF}};
	endcase
end

always_comb
	o = cptgt ? (z ? 64'd0 : t) : bus;

endmodule
