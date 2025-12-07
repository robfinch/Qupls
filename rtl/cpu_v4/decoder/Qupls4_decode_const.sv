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

module Qupls4_decode_const(instr_raw, ip, ins, imma, immb, immc, immd,
	has_imma, has_immb, has_immc, has_immd, pos, isz);
input cpu_types_pkg::pc_address_t ip;
input [335:0] instr_raw;
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

fpCvt16To64 ucvt16x64a(cnst1[15:0], imm16x64a);
fpCvt16To64 ucvt16x64b(cnst2[15:0], imm16x64b);
fpCvt16To64 ucvt16x64C(cnst3[15:0], imm16x64c);
fpCvt32To64 ucvt32x64a(cnst1[31:0], imm32x64a);
fpCvt32To64 ucvt32x64b(cnst2[31:0], imm32x64b);
fpCvt32To64 ucvt32x64C(cnst3[31:0], imm32x64c);

reg [239:0] czone;
wire [63:0] cnst1, cnst2, cnst3, cnst4;
reg [63:0] cnst1a;

always_comb pos = Qupls4_pkg::fnConstPos(ins);
always_comb isz = Qupls4_pkg::fnConstSize(ins);

// Aggregate constant zone
always_comb
	czone = {instr_raw[287:248],instr_raw[239:200],instr_raw[191:152],instr_raw[143:104],instr_raw[95:56],instr_raw[47:8]};

Qupls4_constant_decoder u1 (pos[3:0],isz[1:0],czone,cnst1);
Qupls4_constant_decoder u2 (pos[7:4],isz[3:2],czone,cnst2);
Qupls4_constant_decoder u3 (pos[11:8],isz[5:4],czone,cnst3);
// For store immediate
Qupls4_constant_decoder u4 (ins[10:7],ins[12:11],czone,cnst4);

always_comb
begin
	flt = 1'd0;
	imma = 32'd0;
	immb = 32'd0;
	immc = 32'd0;
	has_imma = 1'b0;
	has_immb = 1'b0;
	has_immc = 1'b0;
	finsA = 1'd0;
	finsB = 1'd0;
	finsC = 1'd0;

	case(ins.any.opcode)
	// Quick immediate mode		Rd=Rs1+imm
	Qupls4_pkg::OP_ADDI,Qupls4_pkg::OP_MULI,Qupls4_pkg::OP_DIVI,
	Qupls4_pkg::OP_SUBFI,Qupls4_pkg::OP_CMPI:
		begin
			immb = {{37{ins.alui.imm[26]}},ins.alui.imm};
			has_immb = TRUE;
			/*
			if (ins.alui.Rs1==8'd0) begin				
				imma = value_zero;
				has_imma = TRUE;
			end
			*/
		end
	Qupls4_pkg::OP_MULUI,Qupls4_pkg::OP_DIVUI,Qupls4_pkg::OP_CMPUI,
	Qupls4_pkg::OP_ORI,Qupls4_pkg::OP_XORI:
		begin
			immb = {{37{1'b0}},ins.alui.imm};
			has_immb = TRUE;
			/*
			if (ins.alui.Rs1==8'd0) begin				
				imma = value_zero;
				has_imma = TRUE;
			end
			*/
		end
	Qupls4_pkg::OP_ANDI:
		begin
			immb = {{37{1'b1}},ins.alui.imm};
			has_immb = TRUE;
			/*
			if (ins.alui.Rs1==8'd0) begin				
				imma = value_zero;
				has_imma = TRUE;
			end
			*/
		end

	Qupls4_pkg::OP_LOADI:
		begin
			immb = {{37{ins.alui.imm[26]}},ins.alui.imm};
			has_immb = TRUE;
			imma = value_zero;
			has_imma = TRUE;
			/*
			if (ins.alui.Rs1==8'd0) begin				
				imma = value_zero;
				has_imma = TRUE;
			end
			*/
		end

	// Register R3 forms	Rd = Rs1,Rs2,Rs3
	Qupls4_pkg::OP_R3B,Qupls4_pkg::OP_R3W,Qupls4_pkg::OP_R3T,Qupls4_pkg::OP_R3O,
	Qupls4_pkg::OP_R3BP,Qupls4_pkg::OP_R3WP,Qupls4_pkg::OP_R3TP,Qupls4_pkg::OP_R3OP,
	Qupls4_pkg::OP_R3P,
	Qupls4_pkg::OP_SHIFT:
		begin
			imma = cnst1;
			has_imma = Qupls4_pkg::fnHasConstRs1(ins);
			immb = cnst2;
			has_immb = Qupls4_pkg::fnHasConstRs2(ins);
			immc = cnst3;
			has_immc = Qupls4_pkg::fnHasConstRs3(ins);
			/*
			if (ins.r3.Rs1==8'd0 && !has_imma) begin
				imma = value_zero;
				has_imma = TRUE;
			end
			if (ins.r3.Rs2==8'd0 && !has_immb) begin				
				immb = value_zero;
				has_immb = TRUE;
			end
			if (ins.r3.Rs3==8'd0 && !has_immc) begin				
				immc = value_zero;
				has_immc = TRUE;
			end
			*/
		end

	// Register F3 forms	Rd = Rs1,Rs2,Rs3
	Qupls4_pkg::OP_FLTH,Qupls4_pkg::OP_FLTS,Qupls4_pkg::OP_FLTD,Qupls4_pkg::OP_FLTQ,
	Qupls4_pkg::OP_FLTPH,Qupls4_pkg::OP_FLTPS,Qupls4_pkg::OP_FLTPD,Qupls4_pkg::OP_FLTPQ:
		begin
			has_imma = Qupls4_pkg::fnHasConstRs1(ins);
			has_immb = Qupls4_pkg::fnHasConstRs2(ins);
			has_immc = Qupls4_pkg::fnHasConstRs3(ins);
			case(isz[1:0])
			2'd1:	imma = imm16x64a;
			2'd2:	imma = imm32x64a;
			default:	imma = cnst1;
			endcase
			case(isz[3:2])
			2'd1:	immb = imm16x64b;
			2'd2:	immb = imm32x64b;
			default:	immb = cnst2;
			endcase
			case(isz[5:4])
			2'd1:	immc = imm16x64c;
			2'd2:	immc = imm32x64c;
			default:	immc = cnst3;
			endcase
			/*
			if (ins.f3.Rs1==8'd0 && !has_imma) begin
				imma = value_zero;
				has_imma = TRUE;
			end
			if (ins.f3.Rs2==8'd0 && !has_immb) begin				
				immb = value_zero;
				has_immb = TRUE;
			end
			if (ins.f3.Rs3==8'd0 && !has_immc) begin				
				immc = value_zero;
				has_immc = TRUE;
			end
			*/
		end

	Qupls4_pkg::OP_CSR:
		begin
			// ToDo: fix
			immb = {57'd0,ins[22:16]};
			has_immb = 1'b0;
			/*
			if (ins.alui.Rs1==8'd0) begin
				imma = value_zero;
				has_imma = TRUE;
			end
			*/
		end
	Qupls4_pkg::OP_BCC8,Qupls4_pkg::OP_BCC16,Qupls4_pkg::OP_BCC32,Qupls4_pkg::OP_BCC64,
	Qupls4_pkg::OP_BCCU8,Qupls4_pkg::OP_BCCU16,Qupls4_pkg::OP_BCCU32,Qupls4_pkg::OP_BCCU64:
		begin
			/*
			if (ins.br.Rs1==8'd0) begin
				imma = value_zero;
				has_imma = TRUE;
			end
			if (ins.br.Rs2==8'd0) begin
				immb = value_zero;
				has_immb = TRUE;
			end
			*/
			if (ins.br.ms[1]) begin
				immb = cnst2;
				has_immb = TRUE;
			end
			if (ins.br.ms[0]) begin
				imma = cnst1;
				has_imma = TRUE;
			end
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
			if (ins.ls.Rs1==8'd0) begin
				imma = value_zero;
				has_imma = TRUE;
			end
			if (ins.ls.Rs2==8'd0) begin
				immb = value_zero;
				has_immb = TRUE;
			end
			has_immc = TRUE;
			if (ins.ls.ms)
				immc = cnst3;
			else
				immc = {{45{ins.ls.disp[18]}},ins.ls.disp};
		end
	Qupls4_pkg::OP_LDIP,Qupls4_pkg::OP_STIP:
		begin
			imma = ip;
			has_imma = TRUE;
			if (ins.ls.Rs2==8'd0) begin
				immb = value_zero;
				has_immb = TRUE;
			end
			has_immc = TRUE;
			if (ins.ls.ms)
				immc = cnst3;
			else
				immc = {{45{ins.ls.disp[18]}},ins.ls.disp};
		end
	Qupls4_pkg::OP_STI:
		begin
			if (ins.ls.Rs1==8'd0) begin
				imma = value_zero;
				has_imma = TRUE;
			end
			if (ins.ls.Rs2==8'd0) begin
				immb = value_zero;
				has_immb = TRUE;
			end
			has_immd = TRUE;
			immd = cnst4;
			has_immc = TRUE;
			if (ins.ls.ms)
				immc = cnst3;
			else
				immc = {{45{ins.ls.disp[18]}},ins.ls.disp};
		end
	Qupls4_pkg::OP_FENCE:
		begin
			immb = {112'h0,ins[23:8]};
			has_immb = 1'b1;
		end
	default:
		immb = 64'd0;
	endcase

end

endmodule
