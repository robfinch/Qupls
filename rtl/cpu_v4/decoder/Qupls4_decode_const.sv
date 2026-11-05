// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2026  Robert Finch, Waterloo
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
	has_imma, has_immb, has_immc, has_immd);
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
reg [63:0] cnsta,cnstb,cnstc,cnstd,cnst;
reg has_cnsta;
reg has_cnstb;
reg has_cnstc;
reg has_cnstd;
reg cnsta85;
reg cnstb85;
reg cnstc85;
reg cnstd85;

/*
fpCvt16To64 ucvt16x64a(cnst1[15:0], imm16x64a);
fpCvt16To64 ucvt16x64b(cnst2[15:0], imm16x64b);
fpCvt16To64 ucvt16x64C(cnst3[15:0], imm16x64c);
fpCvt32To64 ucvt32x64a(cnst1[31:0], imm32x64a);
fpCvt32To64 ucvt32x64b(cnst2[31:0], imm32x64b);
fpCvt32To64 ucvt32x64C(cnst3[31:0], imm32x64c);
*/
FP64 c64Rs1,c64Rs2,c64Rs3;
FP32 c32Rs1,c32Rs2,c32Rs3;
// Design cannot route with constant ROMs
//fpConstROM64 ucr1 (.a(ins.Rs1), .o(c64Rs1));
//fpConstROM64 ucr2 (.a(ins.Rs2), .o(c64Rs2));
//fpConstROM64 ucr3 (.a(ins.Rs3), .o(c64Rs3));
//fpConstROM32 ucr4 (.a(ins.Rs1), .o(c32Rs1));
//fpConstROM32 ucr5 (.a(ins.Rs2), .o(c32Rs2));
//fpConstROM32 ucr6 (.a(ins.Rs3), .o(c32Rs3));

reg [47:0] cpfx [0:7];
reg [1:0] q;
reg [1:0] wh;
reg [7:0] vpfx;					// valid postfix indicator

genvar g;
generate begin : gCpfx
	for (g = 0; g < 8; g = g + 1)
	  always_comb
			cpfx[g] = instr_raw[g*48+47+48:g*48+48];
end
endgenerate

always_comb
begin
	flt = 1'd0;
	imma = 64'd0;
	immb = 64'd0;
	immc = 64'd0;
	immd = 64'd0;
	cnsta = 64'd0;
	cnstb = 64'd0;
	cnstc = 64'd0;
	cnstd = 64'd0;
	cnsta85 = FALSE;
	cnstb85 = FALSE;
	cnstc85 = FALSE;
	cnstd85 = FALSE;
	has_imma = 1'b0;
	has_immb = 1'b0;
	has_immc = 1'b0;
	has_immd = 1'b0;
	has_cnsta = 1'b0;
	has_cnstb = 1'b0;
	has_cnstc = 1'b0;
	has_cnstd = 1'b0;
	finsA = 1'd0;
	finsB = 1'd0;
	finsC = 1'd0;

	case(ins.opcode)
	Qupls4_pkg::OP_R3B,Qupls4_pkg::OP_R3W,Qupls4_pkg::OP_R3T,Qupls4_pkg::OP_R3O,
	Qupls4_pkg::OP_R3BP,Qupls4_pkg::OP_R3WP,Qupls4_pkg::OP_R3TP,Qupls4_pkg::OP_R3OP,
	Qupls4_pkg::OP_R3VVV,Qupls4_pkg::OP_R3VVS,
	Qupls4_pkg::OP_CHK:
		begin
			if (SUPPORT_POSTFIX & has_cnsta) begin
				imma = {cnsta,ins.Rs1[6:0]};
				has_imma = TRUE;
			end
			else if (ins.ms[0]) begin
				imma = {{57{ins.Rs1[6]}},ins.Rs1[6:0]};
				has_imma = TRUE;
			end
			if (SUPPORT_POSTFIX & has_cnstb) begin
				immb = {cnstb,ins.Rs2[6:0]};
				has_immb = TRUE;
			end
			else if (ins.ms[1]) begin
				immb = {{57{ins.Rs2[6]}},ins.Rs2[6:0]};
				has_immb = TRUE;
			end
			if (SUPPORT_POSTFIX & has_cnstc) begin
				immc = {cnstc,ins.Rs3[6:0]};
				has_immc = TRUE;
			end
			else if (ins.ms[2]) begin
				immc = {{57{ins.Rs3[6]}},ins.Rs3[6:0]};
				has_immc = TRUE;
			end
		end

	Qupls4_pkg::OP_FLTH:
		begin
			case(ins.Rs1[6:0])
			7'd0:
				begin
					imma = 64'd0;									// +0.0
					has_imma = TRUE;
				end
			7'd1:
				begin
					imma = 64'h7fffffffffff3c00;	// +1.0 Nan boxed
					has_imma = TRUE;
				end
			default:
				if (SUPPORT_POSTFIX & has_cnsta) begin
					imma = {cnsta,ins.Rs1[6:0]};
					has_imma = TRUE;
				end
			endcase
			/*
			else if (ins.ms[0]) begin
				if (ins.Rs1==7'd0)
					imma = 64'd0;
				else
					imma = {ins.Rs1[6],47'h7FFFFFFFFFFF,ins.Rs1[6],5'h0C+ins.Rs1[5:3],ins.Rs1[2:0],7'b0};
				has_imma = TRUE;
			end
			*/
			case(ins.Rs2[6:0])
			7'd0:
				begin
					immb = 64'd0;									// +0.0
					has_immb = TRUE;
				end
			7'd1:
				begin
					immb = 64'h7fffffffffff3c00;	// +1.0 Nan boxed
					has_immb = TRUE;
				end
			default:
				if (SUPPORT_POSTFIX & has_cnstb) begin
					immb = {cnstb,ins.Rs2[6:0]};
					has_immb = TRUE;
				end
			endcase
			/*
			else if (ins.ms[1]) begin
				if (ins.Rs2==7'd0)
					immb = 64'd0;
				else
					immb = {ins.Rs2[6],47'h7FFFFFFFFFFF,ins.Rs2[6],5'h0C+ins.Rs2[5:3],ins.Rs2[2:0],7'b0};
				has_immb = TRUE;
			end
			*/
			case(ins.Rs3[6:0])
			7'd0:
				begin
					immc = 64'd0;									// +0.0
					has_immc = TRUE;
				end
			7'd1:
				begin
					immc = 64'h7fffffffffff3c00;	// +1.0 Nan boxed
					has_immc = TRUE;
				end
			default:
				if (SUPPORT_POSTFIX & has_cnstc) begin
					immc = {cnstc,ins.Rs3[6:0]};
					has_immc = TRUE;
				end
			endcase
			/*
			else if (ins.ms[2]) begin
				if (ins.Rs3==7'd0)
					immc = 64'd0;
				else
					immc = {ins.Rs3[6],47'h7FFFFFFFFFFF,ins.Rs3[6],5'h0C+ins.Rs3[5:3],ins.Rs3[2:0],7'b0};
				has_immc = TRUE;
			end
			*/
		end

	Qupls4_pkg::OP_FLTS:
		begin
			case(ins.Rs1[6:0])
			7'd0:
				begin
					imma = 64'd0;									// +0.0
					has_imma = TRUE;
				end
			7'd1:
				begin
					imma = 64'h7fffffff3f800000;	// +1.0 Nan boxed
					has_imma = TRUE;
				end
			default:
				if (SUPPORT_POSTFIX & has_cnsta) begin
					imma = {cnsta,ins.Rs1[6:0]};
					has_imma = TRUE;
				end
			endcase
			/*
			else if (ins.ms[0]) begin
				imma = c32Rs1;
				has_imma = TRUE;
			end
			*/
			case(ins.Rs2[6:0])
			7'd0:
				begin
					immb = 64'd0;									// +0.0
					has_immb = TRUE;
				end
			7'd1:
				begin
					immb = 64'h7fffffff3f800000;	// +1.0 Nan boxed
					has_immb = TRUE;
				end
			default:
				if (SUPPORT_POSTFIX & has_cnstb) begin
					immb = {cnstb,ins.Rs2[6:0]};
					has_immb = TRUE;
				end
			endcase
			/*
			else if (ins.ms[1]) begin
				immb = c32Rs2;
				has_immb = TRUE;
			end
			*/
			case(ins.Rs3[6:0])
			7'd0:
				begin
					immc = 64'd0;									// +0.0
					has_immc = TRUE;
				end
			7'd1:
				begin
					immc = 64'h7fffffff3f800000;	// +1.0 Nan boxed
					has_immc = TRUE;
				end
			default:
				if (SUPPORT_POSTFIX & has_cnstc) begin
					immc = {cnstc,ins.Rs3[6:0]};
					has_immc = TRUE;
				end
			endcase
			/*
			else if (ins.ms[2]) begin
				immc = c32Rs3;
				has_immc = TRUE;
			end
			*/
		end

	Qupls4_pkg::OP_FLTD:
		begin
			case(ins.Rs1[6:0])
			7'd0:
				begin
					imma = 64'd0;									// +0.0
					has_imma = TRUE;
				end
			7'd1:
				begin
					imma = 64'h3ff0000000000000;	// +1.0
					has_imma = TRUE;
				end
			default:
				if (SUPPORT_POSTFIX & has_cnsta & cnsta85) begin
					imma = {cnsta,ins.Rs1[6:0]};
					has_imma = TRUE;
				end
			endcase
			/*
			else if (has_cnsta) begin
				imma = {cnsta,ins.Rs1[6:0],18'd0};
				has_imma = TRUE;
			end
			*/
			/*
			else if (ins.ms[0]) begin
				imma = c64Rs1;
				has_imma = TRUE;
			end
			*/
			case(ins.Rs2[6:0])
			7'd0:
				begin
					immb = 64'd0;									// +0.0
					has_immb = TRUE;
				end
			7'd1:
				begin
					immb = 64'h3ff0000000000000;	// +1.0
					has_immb = TRUE;
				end
			default:
				if (SUPPORT_POSTFIX & has_cnstb & cnstb85) begin
					immb = {cnstb,ins.Rs2[6:0]};
					has_immb = TRUE;
				end
			endcase
			/*
			else if (has_cnstb) begin
				immb = {cnstb,ins.Rs2[6:0],18'd0};
				has_immb = TRUE;
			end
			else if (ins.ms[1]) begin
				immb = c64Rs2;
				has_immb = TRUE;
			end
			*/
			case(ins.Rs3[6:0])
			7'd0:
				begin
					immc = 64'd0;									// +0.0
					has_immc = TRUE;
				end
			7'd1:
				begin
					immc = 64'h3ff0000000000000;	// +1.0
					has_immc = TRUE;
				end
			default:
				if (SUPPORT_POSTFIX & has_cnstc & cnstc85) begin
					immc = {cnstc,ins.Rs3[6:0]};
					has_immc = TRUE;
				end
			endcase
			/*
			else if (has_cnstc) begin
				immc = {cnstc,ins.Rs3[6:0],18'd0};
				has_immc = TRUE;
			end
			else if (ins.ms[2]) begin
				immc = c64Rs3;
				has_immc = TRUE;
			end
			*/
		end
/*
	Qupls4_pkg::OP_FADDI,Qupls4_pkg::OP_FMULI:
		begin
			case(ins.Rs1[6:0])
			7'd0:
				begin
					imma = 64'd0;									// +0.0
					has_imma = TRUE;
				end
			7'd1:
				begin
					imma = 64'h3ff0000000000000;	// +1.0
					has_imma = TRUE;
				end
			default:
				if (SUPPORT_POSTFIX & has_cnsta) begin
					imma = {ins.Rs1[6:0],cnsta[63:7]};
					has_imma = TRUE;
				end
			endcase
			has_immb = TRUE;
			if (SUPPORT_POSTFIX & has_cnstb) begin
				case(ins.prc[1:0])
				2'd0:	imma = ins.imm[15:0];
				2'd1:	imma = {ins.imm[24:0],cnstb[63:57]};	// single
				2'd2:	imma = {ins.imm[24:0],cnstb[63:25]};	// double
				//2'd3:	imma = {ins.imm[24:0],cnstb[]}
				default:	;
				endcase
			end
		end
*/
	// ToDo: encoding for parallel and quad precision.
/*
	Qupls4_pkg::OP_FLTQ,
	Qupls4_pkg::OP_FLTPH,Qupls4_pkg::OP_FLTPS,Qupls4_pkg::OP_FLTPD,Qupls4_pkg::OP_FLTPQ,
	Qupls4_pkg::OP_FLTVVV,Qupls4_pkg::OP_FLTVVS:
		begin
			if (has_cnsta) begin
				imma = {cnsta,ins.Rs1[6:0]};
				has_imma = TRUE;
			end
			if (has_cnstb) begin
				immb = {cnstb,ins.Rs2[6:0]};
				has_immb = TRUE;
			end
			if (has_cnstc) begin
				immc = {cnstc,ins.Rs3[6:0]};
				has_immc = TRUE;
			end
		end
*/
	// Quick immediate mode		Rd=Rs1+imm
	Qupls4_pkg::OP_ADDI,Qupls4_pkg::OP_MULI,Qupls4_pkg::OP_DIVI,
	Qupls4_pkg::OP_SUBFI,Qupls4_pkg::OP_CMPI,
	Qupls4_pkg::OP_MULUI,Qupls4_pkg::OP_DIVUI,Qupls4_pkg::OP_CMPUI,
	Qupls4_pkg::OP_ORI,Qupls4_pkg::OP_XORI,
	Qupls4_pkg::OP_ANDI:
		begin
			has_immb = TRUE;
			if (SUPPORT_POSTFIX & has_cnstb)
				immb = {cnstb,ins.imm[24:0]};
			else
				immb = ins.imm;//{{39{ins.imm[24]}},ins.imm[24:0]};
		end
/*
	Qupls4_pkg::OP_LOADI:
		begin
			if (SUPPORT_POSTFIX & has_cnstb)
				immb = {cnstb,ins.imm[24:0]};
			else
				immb = ins.imm;//{{39{ins.imm[24]}},ins.imm[24:0]};
			has_immb = TRUE;
			imma = value_zero;
			has_imma = TRUE;
		end
*/
	Qupls4_pkg::OP_CSR:
		begin
			// ToDo: fix
			if (SUPPORT_POSTFIX & has_cnstb)
				immb = cnstb;
			else
				immb = {57'd0,ins[22:16]};
			has_immb = 1'b0;
		end

	Qupls4_pkg::OP_LOADA,
	Qupls4_pkg::OP_LDB,Qupls4_pkg::OP_LDBZ,
	Qupls4_pkg::OP_LDW,Qupls4_pkg::OP_LDWZ,
	Qupls4_pkg::OP_LDT,Qupls4_pkg::OP_LDTZ,
	Qupls4_pkg::OP_LOAD:
		begin
			if (ins.Rs1==8'd0) begin
				imma = value_zero;
				has_imma = TRUE;
			end
			else if (ins.Rs1==8'd127) begin
				imma = ip;
				has_imma = TRUE;
			end
			if (SUPPORT_POSTFIX & has_cnsta) begin
				imma = {cnsta,ins.Rs1[6:0]};
				has_imma = TRUE;
			end
			if (ins.Rs2==8'd0) begin
				immb = value_zero;
				has_immb = TRUE;
			end
			if (SUPPORT_POSTFIX & has_cnstb) begin
				immb = {cnstb,ins.Rs2[6:0]};
				has_immb = TRUE;
			end
			has_immc = TRUE;
			if (SUPPORT_POSTFIX & has_cnstc)
				immc = {cnstc,ins.imm[14:0]};
			else
				immc = {{49{ins.imm[14]}},ins.imm[14:0]};
		end

	Qupls4_pkg::OP_STB,
	Qupls4_pkg::OP_STW,
	Qupls4_pkg::OP_STT,
	Qupls4_pkg::OP_STORE:
		begin
			if (ins.Rs1==8'd0) begin
				imma = value_zero;
				has_imma = TRUE;
			end
			else if (ins.Rs1==8'd127) begin
				imma = ip;
				has_imma = TRUE;
			end
			if (SUPPORT_POSTFIX & has_cnsta) begin
				imma = {cnsta,ins.Rs1[6:0]};
				has_imma = TRUE;
			end
			if (ins.Rs2==9'd0) begin
				immb = value_zero;
				has_immb = TRUE;
			end
			if (SUPPORT_POSTFIX & has_cnstb) begin
				immb = {cnstb,ins.Rs2[6:0]};
				has_immb = TRUE;
			end
			has_immc = TRUE;
			if (SUPPORT_POSTFIX & has_cnstc)
				immc = {cnstc,ins.imm[14:0]};
			else
				immc = {{45{ins.imm[14]}},ins.imm[14:0]};
			if (has_cnstd) begin
				has_immd = TRUE;
				immd = {cnstd,ins.Rd[6:0]};
			end
		end

	Qupls4_pkg::OP_STI:
		begin
			if (ins.Rs1==8'd0) begin
				imma = value_zero;
				has_imma = TRUE;
			end
			else if (ins.Rs1==8'd127) begin
				imma = ip;
				has_imma = TRUE;
			end
			if (ins.Rs2==8'd0) begin
				immb = value_zero;
				has_immb = TRUE;
			end
			has_immc = TRUE;
			if (SUPPORT_POSTFIX & has_cnstc)
				immc = {cnstc,ins.imm[14:0]};
			else
				immc = {{49{ins.imm[14]}},ins.imm[14:0]};
			has_immd = TRUE;
			immd = {{59{ins.Rd[4]}},ins.Rd[4:0]};
		end

	Qupls4_pkg::OP_BCC,
	Qupls4_pkg::OP_BCCU:
		begin
			if (SUPPORT_POSTFIX & has_cnsta) begin
				imma = {cnsta,ins.Rs1[6:0]};
				has_imma = TRUE;
			end
			else if (ins.ms[0]) begin
				imma = {{57{ins.Rs1[6]}},ins.Rs1[6:0]};
				has_imma = TRUE;
			end
			if (SUPPORT_POSTFIX & has_cnstb) begin
				immb = {cnstb,ins.Rs2[6:0]};
				has_immb = TRUE;
			end
			else if (ins.ms[1]) begin
				immb = {{57{ins.Rs2[6]}},ins.Rs2[6:0]};
				has_immb = TRUE;
			end
			if (SUPPORT_POSTFIX & has_cnstc) begin
				immc = {cnstc,ins.Rs3[6:0]};
				has_immc = TRUE;
			end
			else if (ins.ms[2]) begin
				immc = {{46{ins.imm[17]}},ins.imm[17:0]};
				has_immc = TRUE;
			end
		end

	Qupls4_pkg::OP_FBCC:
		begin
			if (SUPPORT_POSTFIX & has_cnsta & cnsta85) begin
				imma = {cnsta,ins.Rs1[6:0]};
				has_imma = TRUE;
			end
			/*
			else if (has_cnsta) begin
				imma = {cnsta,ins.Rs1[6:0],18'd0};
				has_imma = TRUE;
			end
			*/
			/*
			else if (ins.ms[0]) begin
				imma = c64Rs1;
				has_imma = TRUE;
			end
			*/
			if (SUPPORT_POSTFIX & has_cnstb & cnstb85) begin
				immb = {cnstb,ins.Rs2[6:0]};
				has_immb = TRUE;
			end
			/*
			else if (has_cnstb) begin
				immb = {cnstb,ins.Rs2[6:0],18'd0};
				has_immb = TRUE;
			end
			*/
			/*
			else if (ins.ms[1]) begin
				immb = c64Rs2;
				has_immb = TRUE;
			end
			*/
			if (SUPPORT_POSTFIX & has_cnstc) begin
				immc = {cnstc,ins.Rs3[6:0]};
				has_immc = TRUE;
			end
			else if (ins.ms[2]) begin
				immc = {{46{ins.imm[17]}},ins.imm[17:0]};
				has_immc = TRUE;
			end
		end

	Qupls4_pkg::OP_BSR,Qupls4_pkg::OP_JSR:
		begin
			has_imma = TRUE;
			imma = {{29{ins.imm[34]}},ins.imm[34:0]};
			if (SUPPORT_POSTFIX & has_cnsta)
				imma = {cnsta,ins.imm[34:0]};
		end
		
	Qupls4_pkg::OP_RTD:
		begin
			has_immb = TRUE;
			if (SUPPORT_POSTFIX & has_cnstb)
				immb = {cnstb,ins.imm[24:0]};
			else
				immb = {{39{ins.imm[24]}},ins.imm[24:0]};
		end

	Qupls4_pkg::OP_FENCE:
		begin
			immb = {112'h0,ins[23:8]};
			has_immb = 1'b1;
		end
	default:
		immb = 64'd0;
	endcase

	// Limit of six postfixes
	// A postfix is not valid unless there is a valid postfix before it.
	vpfx = 8'h00;
	if (SUPPORT_POSTFIX) begin
	if (cpfx[0][6:2]==5'd15) begin
		vpfx[0] = VAL;
	if (cpfx[1][6:2]==5'd15) begin
		vpfx[1] = VAL;
	if (cpfx[2][6:2]==5'd15) begin
		vpfx[2] = VAL;
	if (cpfx[3][6:2]==5'd15) begin
		vpfx[3] = VAL;
	if (cpfx[4][6:2]==5'd15) begin
		vpfx[4] = VAL;
	if (cpfx[5][6:2]==5'd15) begin
		vpfx[5] = VAL;
	end
	end
	end
	end
	end
	end
	end

	foreach (cpfx[n])
		if (SUPPORT_POSTFIX & vpfx[n]) begin
			wh = cpfx[n][1:0];
			q = cpfx[n][8:7];
			case({q,wh})
			4'b0000:	begin cnsta = {{32{cpfx[n][47]}},cpfx[n][47:9]}; has_cnsta = TRUE; end
			4'b0001:	begin cnstb = {{32{cpfx[n][47]}},cpfx[n][47:9]}; has_cnstb = TRUE; end
			4'b0010:	begin cnstc = {{32{cpfx[n][47]}},cpfx[n][47:9]}; has_cnstc = TRUE; end
			4'b0011:	begin cnstd = {{32{cpfx[n][47]}},cpfx[n][47:9]}; has_cnstd = TRUE; end
			4'b0100:	begin cnsta = {cpfx[n][47:9],cnsta[38:0]}; has_cnsta = TRUE; cnsta85 = TRUE; end
			4'b0101:	begin cnstb = {cpfx[n][47:9],cnstb[38:0]}; has_cnstb = TRUE; cnstb85 = TRUE;  end
			4'b0110:	begin cnstc = {cpfx[n][47:9],cnstc[38:0]}; has_cnstc = TRUE; cnstc85 = TRUE;  end
			4'b0111:	begin cnstd = {cpfx[n][47:9],cnstd[38:0]}; has_cnstd = TRUE; cnstd85 = TRUE;  end
			default:	;
			endcase
		end

end

endmodule
