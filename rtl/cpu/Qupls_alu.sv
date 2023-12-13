// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
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

module Qupls_alu(rst, clk, clk2x, ld, ir, div, a, b, c, i, cs, pc, csr,
	o, mul_done, div_done, div_dbz);
parameter ALU0 = 1'b0;
input rst;
input clk;
input clk2x;
input ld;
input instruction_t ir;
input div;
input value_t a;
input value_t b;
input value_t c;
input value_t i;
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
reg [191:0] shl, shr, asr;
value_t div_q, div_r;
value_t cmpo;
value_t bus;
value_t blendo;
always_comb
	shl = {64'd0,a,{64{ir[33]}}} << (ir[32] ? ir[24:19] : b[5:0]);
always_comb
	shr = {{64{ir[33]}},a,64'd0} >> (ir[32] ? ir[24:19] : b[5:0]);
always_comb
	asr = {{64{a[63]}},a,64'd0} >> (ir[32] ? ir[24:19] : b[5:0]);

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
	prod2 <= $signed(a) * $signed(b);
	prod1 <= prod2;
	prod <= prod1;
end
always_ff @(posedge clk)
begin
	produ2 <= a * b;
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
	.b(b),
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
	.c1(b),
	.o(blendo)
);

always_comb
begin
	case(ir.any.opcode)
	OP_R2:
		case(ir.r2.func)
		FN_ADD:	bus = a + b + cc;
		FN_SUB:	bus = a - b - cc;
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
		default:	bus = {2{32'hDEADBEEF}};
		endcase
	OP_R2B:
		case(ir.r2b.func)
		FN_SEQ:	bus = a == b;
		FN_SNE:	bus = a != b;
		FN_SLT:	bus = $signed(a) < $signed(b);
		FN_SLE:	bus = $signed(a) <= $signed(b);
		FN_SLTU:	bus = a < b;
		FN_SLEU:	bus = a <= b;
		default:	bus = {2{32'hDEADBEEF}};
		endcase
	OP_RIS:
		case(ir.ris.func)
		FNS_ADD:	bus = a + b;
		FNS_SUBF:	bus = b - a;
		FNS_CMP:	bus = cmpo;
		FNS_CMPU:	bus = cmpo;
		FNS_MUL:	bus = prod[63:0];
		FNS_MULU:	bus = produ[63:0];
		FNS_MULH:	bus = prod[127:64];
		FNS_MULUH:	bus = produ[127:64];
		FNS_DIV: bus = ALU0 ? div_q : 0;
		FNS_MOD: bus = ALU0 ? div_r : 0;
		FNS_DIVU: bus = ALU0 ? div_q : 0;
		FNS_MODU: bus = ALU0 ? div_r : 0;
		FNS_AND:	bus = a & b;
		FNS_OR:	bus = a | b;
		FNS_EOR:	bus = a ^ b;
		FNS_ANDC:	bus = a & ~b;
		FNS_NAND:	bus = ~(a & b);
		FNS_NOR:	bus = ~(a | b);
		FNS_ENOR:	bus = ~(a ^ b);
		FNS_ORC:	bus = a | ~b;
		default:	bus = {2{32'hDEADBEEF}};
		endcase
	OP_CSR:		bus = csr;
	OP_ADDI:	bus = a + b;
	OP_SUBFI:	bus = b - a;
	OP_CMPI:	bus = cmpo;
	OP_CMPUI:	bus = cmpo;
	OP_MULI:	bus = prod[63:0];
	OP_MULUI:	bus = produ[63:0];
	OP_DIVI:	bus = ALU0 ? div_q : 0;
	OP_DIVUI:	bus = ALU0 ? div_q : 0;
	OP_ANDI:	bus = a & b;
	OP_ORI:		bus = a | b;
	OP_EORI:	bus = a ^ b;
	OP_SLTI:	bus = $signed(a) < $signed(b);
	OP_SHIFT:
		case(ir.shifti.func)
		OP_ASL:	bus = shl[127:64];
		OP_LSR:	bus = shr[127:64];
		OP_ROL:	bus = shl[127:64]|shl[191:128];
		OP_ROR:	bus = shr[127:64]|shr[63:0];
		OP_ASR:	bus = asr[127:64];
		OP_ASLI:	bus = shl[127:64];
		OP_LSRI:	bus = shr[127:64];
		OP_ROLI:	bus = shl[127:64]|shl[191:128];
		OP_RORI:	bus = shr[127:64]|shr[63:0];
		OP_ASRI:	bus = asr[127:64];
		default:	bus = {2{32'hDEADBEEF}};
		endcase
	OP_LDI:		bus = b;
	OP_MOV:		bus = a;
	OP_LDA:		bus = a + i;
	OP_LDAX:	bus = a + i + (b << ir[26:25]);
	OP_BLEND:	bus = ALU0 ? blendo : 0;
	OP_NOP:		bus = 0;
	OP_PFXA32:	bus = 0;
	OP_PFXB32:	bus = 0;
	OP_PFXC32:	bus = 0;
	OP_PFXA64:	bus = 0;
	OP_PFXB64:	bus = 0;
	OP_PFXC64:	bus = 0;
	OP_PFXA128:	bus = 0;
	OP_PFXB128:	bus = 0;
	OP_PFXC128:	bus = 0;
	OP_VEC:	bus = 0;
	OP_VECZ:	bus = 0;
	// Write the next PC to the link register.
	OP_BSR,OP_JSR:
						bus = pc + 4'd5;
	default:	bus = {2{32'hDEADBEEF}};
	endcase
end

always_comb
	o = bus;

endmodule
