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

	Qupls4_pkg::OP_FLTH:
		begin
			if (has_cnsta) begin
				imma = {cnsta,ins.Rs1[6:0]};
				has_imma = TRUE;
			end
			else if (ins.ms[0]) begin
				imma = {ins.Rs1[6],47'h7FFFFFFFFFFF,ins.Rs1[6],5'h0F+ins.Rs1[5:3],ins.Rs1[2:0],7'b0};
				has_imma = TRUE;
			end
			if (has_cnstb) begin
				immb = {cnstb,ins.Rs1[6:0]};
				has_immb = TRUE;
			end
			else if (ins.ms[1]) begin
				immb = {ins.Rs2[6],47'h7FFFFFFFFFFF,ins.Rs2[6],5'h0F+ins.Rs2[5:3],ins.Rs2[2:0],7'b0};
				has_immb = TRUE;
			end
			if (has_cnstc) begin
				immc = {cnstc,ins.Rs1[6:0]};
				has_immc = TRUE;
			end
			else if (ins.ms[2]) begin
				immc = {ins.Rs3[6],47'h7FFFFFFFFFFF,ins.Rs3[6],5'h0F+ins.Rs3[5:3],ins.Rs3[2:0],7'b0};
				has_immc = TRUE;
			end
		end
	Qupls4_pkg::OP_FLTS:
		begin
			if (has_cnsta) begin
				imma = {cnsta,ins.Rs1[6:0]};
				has_imma = TRUE;
			end
			else if (ins.ms[0]) begin
				imma = {ins.Rs1[6],31'h7FFFFFFF,ins.Rs1[6],8'h7F+ins.Rs1[5:3],ins.Rs1[2:0],20'b0};
				has_imma = TRUE;
			end
			if (has_cnstb) begin
				immb = {cnstb,ins.Rs2[6:0]};
				has_immb = TRUE;
			end
			else if (ins.ms[1]) begin
				immb = {ins.Rs2[6],31'h7FFFFFFF,ins.Rs2[6],8'h7F+ins.Rs2[5:3],ins.Rs2[2:0],20'b0};
				has_immb = TRUE;
			end
			if (has_cnstc) begin
				immc = {cnstc,ins.Rs3[6:0]};
				has_immc = TRUE;
			end
			else if (ins.ms[2]) begin
				immc = {ins.Rs3[6],31'h7FFFFFFF,ins.Rs3[6],8'h7F+ins.Rs3[5:3],ins.Rs3[2:0],20'b0};
				has_immc = TRUE;
			end
		end
	Qupls4_pkg::OP_FLTD:
		begin
			if (has_cnsta & cnsta85) begin
				imma = {cnsta,ins.Rs1[6:0]};
				has_imma = TRUE;
			end
			else if (has_cnsta) begin
				imma = {cnsta,ins.Rs1[6:0],18'd0};
				has_imma = TRUE;
			end
			else if (ins.ms[0]) begin
				imma = {ins.Rs1[6],11'h3FF+ins.Rs1[5:3],ins.Rs1[2:0],49'b0};
				has_imma = TRUE;
			end
			if (has_cnstb & cnstb85) begin
				immb = {cnstb,ins.Rs2[6:0]};
				has_immb = TRUE;
			end
			else if (has_cnstb) begin
				immb = {cnstb,ins.Rs2[6:0],18'd0};
				has_immb = TRUE;
			end
			else if (ins.ms[1]) begin
				immb = {ins.Rs2[6],11'h3FF+ins.Rs2[5:3],ins.Rs2[2:0],49'b0};
				has_immb = TRUE;
			end
			if (has_cnstc & cnstc85) begin
				immc = {cnstc,ins.Rs3[6:0]};
				has_immc = TRUE;
			end
			else if (has_cnstc) begin
				immc = {cnstc,ins.Rs3[6:0],18'd0};
				has_immc = TRUE;
			end
			else if (ins.ms[2]) begin
				immc = {ins.Rs3[6],11'h3FF+ins.Rs3[5:3],ins.Rs3[2:0],49'b0};
				has_immc = TRUE;
			end
		end
	// ToDo: encoding for parallel and quad precision.
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

	// Quick immediate mode		Rd=Rs1+imm
	Qupls4_pkg::OP_ADDI,Qupls4_pkg::OP_MULI,Qupls4_pkg::OP_DIVI,
	Qupls4_pkg::OP_SUBFI,Qupls4_pkg::OP_CMPI,
	Qupls4_pkg::OP_MULUI,Qupls4_pkg::OP_DIVUI,Qupls4_pkg::OP_CMPUI,
	Qupls4_pkg::OP_ORI,Qupls4_pkg::OP_XORI,
	Qupls4_pkg::OP_ANDI:
		begin
			has_immb = TRUE;
			if (has_cnstb)
				immb = {cnstb,ins.imm[27:0]};
			else
				immb = {{36{ins.imm[27]}},ins.imm[27:0]};
		end

	Qupls4_pkg::OP_LOADI:
		begin
			if (has_cnstb)
				immb = {cnstb,ins.imm[27:0]};
			else
				immb = {{36{ins.imm[27]}},ins.imm[27:0]};
			has_immb = TRUE;
			imma = value_zero;
			has_imma = TRUE;
		end

	Qupls4_pkg::OP_CSR:
		begin
			// ToDo: fix
			if (has_cnstb)
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
			if (has_cnsta) begin
				imma = {cnsta,ins.Rs1[6:0]};
				has_imma = TRUE;
			end
			if (ins.Rs2==8'd63) begin
				immb = value_zero;
				has_immb = TRUE;
			end
			if (has_cnstb) begin
				immb = {cnstb,ins.Rs2[6:0]};
				has_immb = TRUE;
			end
			has_immc = TRUE;
			if (has_cnstc)
				immc = {cnstc,ins.imm[19:0]};
			else
				immc = {{44{ins.imm[19]}},ins.imm[19:0]};
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
			if (has_cnsta) begin
				imma = {cnsta,ins.Rs1[6:0]};
				has_imma = TRUE;
			end
			if (ins.Rs2==8'd63) begin
				immb = value_zero;
				has_immb = TRUE;
			end
			if (has_cnstb) begin
				immb = {cnstb,ins.Rs2[6:0]};
				has_immb = TRUE;
			end
			has_immc = TRUE;
			if (has_cnstc)
				immc = {cnstc,ins.imm[19:0]};
			else
				immc = {{44{ins.imm[19]}},ins.imm[19:0]};
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
			if (ins.Rs2==8'd0) begin
				immb = value_zero;
				has_immb = TRUE;
			end
			has_immc = TRUE;
			immc = {{44{ins.imm[19]}},ins.imm[19:0]};
			has_immd = TRUE;
			immd = {{60{ins.Rd[3]}},ins.Rd[3:0]};
		end

	Qupls4_pkg::OP_BCC,
	Qupls4_pkg::OP_BCCU,
	Qupls4_pkg::OP_FBCC:
		begin
			if (ins.Rs1==8'd0) begin
				imma = value_zero;
				has_imma = TRUE;
			end
			if (has_cnsta) begin
				imma = {cnsta,ins.Rs1[6:0]};
				has_imma = TRUE;
			end
			if (ins.Rs2==8'd127) begin
				immb = value_zero;
				has_immb = TRUE;
			end
			if (has_cnstb) begin
				immb = {cnstb,ins.Rs2[6:0]};
				has_immb = TRUE;
			end
		end

	Qupls4_pkg::OP_BSR,Qupls4_pkg::OP_JSR:
		begin
			has_imma = TRUE;
			imma = {{24{ins.imm[39]}},ins.imm};
			if (has_cnsta)
				imma = {cnsta,ins.imm[39:0]};
		end
		
	Qupls4_pkg::OP_RTD:
		begin
			has_immb = TRUE;
			if (has_cnstb)
				immb = {cnstb,ins.imm[24:3],3'd0};
			else
				immb = {{39{ins.imm[24]}},ins.imm[24:3],3'd0};
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
	if (cpfx[0][7:2]==6'd15) begin
		vpfx[0] = VAL;
	if (cpfx[1][7:2]==6'd15) begin
		vpfx[1] = VAL;
	if (cpfx[2][7:2]==6'd15) begin
		vpfx[2] = VAL;
	if (cpfx[3][7:2]==6'd15) begin
		vpfx[3] = VAL;
	if (cpfx[4][7:2]==6'd15) begin
		vpfx[4] = VAL;
	if (cpfx[5][7:2]==6'd15) begin
		vpfx[5] = VAL;
	end
	end
	end
	end
	end
	end

	foreach (cpfx[n])
		if (vpfx[n]) begin
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
