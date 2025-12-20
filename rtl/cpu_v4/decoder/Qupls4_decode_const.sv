// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	decode_const.sv
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
// 890 LUTs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;
import fp16Pkg::*;
import fp32Pkg::*;
import fp64Pkg::*;

module Qupls4_decode_const(instr_raw, ip, ins, imma, immb, immc, immd,
	has_imma, has_immb, has_immc, has_immd, pos, isz);
input cpu_types_pkg::pc_address_t ip;
input [431:0] instr_raw;
input Qupls4_pkg::micro_op_t ins;
output reg [63:0] imma;
output reg [63:0] immb;
output reg [63:0] immc;
output reg [63:0] immd;
output reg has_imma;
output reg has_immb;
output reg has_immc;
output reg has_immd;
output reg [11:0] pos;
output reg [5:0] isz;

integer n;
Qupls4_pkg::micro_op_t insf;
wire [63:0] imm16x64a;
wire [63:0] imm16x64b;
wire [63:0] imm16x64c;
wire [63:0] imm32x64a;
wire [63:0] imm32x64b;
wire [63:0] imm32x64c;
reg [2:0] ndx;
reg flt;
reg [1:0] fltpr;
reg [47:0] finsA, finsB, finsC;

/*
fpCvt16To64 ucvt16x64a(cnst1[15:0], imm16x64a);
fpCvt16To64 ucvt16x64b(cnst2[15:0], imm16x64b);
fpCvt16To64 ucvt16x64C(cnst3[15:0], imm16x64c);
fpCvt32To64 ucvt32x64a(cnst1[31:0], imm32x64a);
fpCvt32To64 ucvt32x64b(cnst2[31:0], imm32x64b);
fpCvt32To64 ucvt32x64C(cnst3[31:0], imm32x64c);
*/
reg [47:0] cpfx [0:7];

genvar g;
generate begin : gCpfx
	for (g = 0; g < 8; g = g + 1)
		cpfx[g] = instr_raw[g*48+47:g*48];
end
endgenerate

always_comb
begin
	flt = 1'd0;
	imma = 64'd0;
	immb = 64'd0;
	immc = 64'd0;
	immd = 64'd0;
	has_imma = 1'b0;
	has_immb = 1'b0;
	has_immc = 1'b0;
	has_immd = 1'b0;
	finsA = 1'd0;
	finsB = 1'd0;
	finsC = 1'd0;

	case(ins.opcode)
	// Quick immediate mode		Rd=Rs1+imm
	Qupls4_pkg::OP_ADDI,Qupls4_pkg::OP_MULI,Qupls4_pkg::OP_DIVI,
	Qupls4_pkg::OP_SUBFI,Qupls4_pkg::OP_CMPI:
		begin
			immb = {{37{ins.imm[26]}},ins.imm};
			has_immb = TRUE;
		end
	Qupls4_pkg::OP_MULUI,Qupls4_pkg::OP_DIVUI,Qupls4_pkg::OP_CMPUI,
	Qupls4_pkg::OP_ORI,Qupls4_pkg::OP_XORI:
		begin
			immb = {{37{1'b0}},ins.imm};
			has_immb = TRUE;
		end
	Qupls4_pkg::OP_ANDI:
		begin
			immb = {{37{1'b1}},ins.imm};
			has_immb = TRUE;
		end

	Qupls4_pkg::OP_LOADI:
		begin
			immb = {{37{ins.imm[26]}},ins.imm};
			has_immb = TRUE;
			imma = value_zero;
			has_imma = TRUE;
		end

	Qupls4_pkg::OP_CSR:
		begin
			// ToDo: fix
			immb = {57'd0,ins[22:16]};
			has_immb = 1'b0;
		end

	Qupls4_pkg::OP_LOADA,
	Qupls4_pkg::OP_LDB,Qupls4_pkg::OP_LDBZ,
	Qupls4_pkg::OP_LDW,Qupls4_pkg::OP_LDWZ,
	Qupls4_pkg::OP_LDT,Qupls4_pkg::OP_LDTZ,
	Qupls4_pkg::OP_LOAD,
	Qupls4_pkg::OP_STB,
	Qupls4_pkg::OP_STW,
	Qupls4_pkg::OP_STT,
	Qupls4_pkg::OP_STORE:
		begin
			if (ins.Rs1==8'd0) begin
				imma = value_zero;
				has_imma = TRUE;
			end
			if (ins.Rs2==8'd0) begin
				immb = value_zero;
				has_immb = TRUE;
			end
			has_immc = TRUE;
			immc = {{45{ins.imm[18]}},ins.imm};
		end
	Qupls4_pkg::OP_LDIP,Qupls4_pkg::OP_STIP:
		begin
			imma = ip;
			has_imma = TRUE;
			if (ins.Rs2==8'd0) begin
				immb = value_zero;
				has_immb = TRUE;
			end
			has_immc = TRUE;
			immc = {{45{ins.imm[18]}},ins.imm};
		end
	Qupls4_pkg::OP_STI:
		begin
			if (ins.Rs1==8'd0) begin
				imma = value_zero;
				has_imma = TRUE;
			end
			if (ins.Rs2==8'd0) begin
				immb = value_zero;
				has_immb = TRUE;
			end
			has_immc = TRUE;
			immc = {{45{ins.imm[18]}},ins.imm};
		end
	Qupls4_pkg::OP_FENCE:
		begin
			immb = {112'h0,ins[23:8]};
			has_immb = 1'b1;
		end
	default:
		immb = 64'd0;
	endcase

	foreach (cpfx[n])
		if (cpfx[n][7:0]==8'h127) begin
			wh = cpfx[n][9:8];
			q = cpfx[n][11:10];
			case({q,wh})
			4'b0000:	begin imma = {32{cpfx[n][47]}},cpfx[n][47:16]}; has_imma = TRUE; end
			4'b0001:	begin immb = {32{cpfx[n][47]}},cpfx[n][47:16]}; has_immb = TRUE; end
			4'b0010:	begin immc = {32{cpfx[n][47]}},cpfx[n][47:16]}; has_immc = TRUE; end
			4'b0011:	begin immd = {32{cpfx[n][47]}},cpfx[n][47:16]}; has_immd = TRUE; end
			4'b0100:	begin imma = {cpfx[n][47:16],imma[31:0]}; has_imma = TRUE; end
			4'b0101:	begin immb = {cpfx[n][47:16],immb[31:0]}; has_immb = TRUE; end
			4'b0110:	begin immc = {cpfx[n][47:16],immc[31:0]}; has_immc = TRUE; end
			4'b0111:	begin immd = {cpfx[n][47:16],immd[31:0]}; has_immd = TRUE; end
			default:	;
			endcase

end

endmodule
