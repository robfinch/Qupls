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
import Qupls5_pkg::*;
import fp16Pkg::*;
import fp32Pkg::*;
import fp64Pkg::*;

module Qupls5_decode_const(instr_raw, ip, ins, imma, immb, immc, immd,
	has_imma, has_immb, has_immc, has_immd);
parameter SUPPORT_POSTFIX = Qupls5_pkg::SUPPORT_POSTFIX;
input cpu_types_pkg::pc_address_t ip;
input [335:0] instr_raw;
input Qupls5_pkg::micro_op_t ins;
output reg [63:0] imma;
output reg [63:0] immb;
output reg [63:0] immc;
output reg [63:0] immd;
output reg has_imma;
output reg has_immb;
output reg has_immc;
output reg has_immd;

integer n;
Qupls5_pkg::micro_op_t insf;
wire [63:0] imm16x64a;
wire [63:0] imm16x64b;
wire [63:0] imm16x64c;
wire [63:0] imm32x64a;
wire [63:0] imm32x64b;
wire [63:0] imm32x64c;
reg [2:0] ndx;
reg flt;
reg [1:0] fltpr;
reg [31:0] finsA, finsB, finsC;
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

reg [31:0] cpfx [0:7];
reg [1:0] q;
reg [1:0] wh;
reg [7:0] vpfx;					// valid postfix indicator

genvar g;
generate begin : gCpfx
	for (g = 0; g < 6; g = g + 1)
	  always_comb
			cpfx[g] = instr_raw[g*32+31+32:g*32+32];
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
	Qupls5_pkg::OP_PPC_ADDI,Qupls5_pkg::OP_PPC_ANDI,Qupls5_pkg::OP_PPC_ORI,Qupls5_pkg::OP_PPC_XORI,
	Qupls5_pkg::OP_PPC_SUBFIC,Qupls5_pkg::OP_PPC_CMPI,Qupls5_pkg::OP_PPC_CMPLI,
	Qupls5_pkg::OP_PPC_ADDIS,Qupls5_pkg::OP_PPC_ANDIS,Qupls5_pkg::OP_PPC_ORIS,Qupls5_pkg::OP_PPC_XORIS:
		begin
			if (ins.R) begin
				imma = ip;
				has_imma = TRUE;
			end
			immb = {{30{ins.imm[33]}},ins.imm[33:0]};
			has_immb = TRUE;
		end
	default:	;
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
			4'b0000:	begin cnsta = {{39{cpfx[n][31]}},cpfx[n][31:9]}; has_cnsta = TRUE; end
			4'b0001:	begin cnstb = {{39{cpfx[n][31]}},cpfx[n][31:9]}; has_cnstb = TRUE; end
			4'b0010:	begin cnstc = {{39{cpfx[n][31]}},cpfx[n][31:9]}; has_cnstc = TRUE; end
			4'b0011:	begin cnstd = {{39{cpfx[n][31]}},cpfx[n][31:9]}; has_cnstd = TRUE; end
			4'b0100:	begin cnsta = {{18{cpfx[n][31]}},cpfx[n][31:9],cnsta[22:0]}; has_cnsta = TRUE; end
			4'b0101:	begin cnstb = {{18{cpfx[n][31]}},cpfx[n][31:9],cnstb[22:0]}; has_cnstb = TRUE; end
			4'b0110:	begin cnstc = {{18{cpfx[n][31]}},cpfx[n][31:9],cnstc[22:0]}; has_cnstc = TRUE; end
			4'b0111:	begin cnstd = {{18{cpfx[n][31]}},cpfx[n][31:9],cnstd[22:0]}; has_cnstd = TRUE; end
			4'b1000:	begin cnsta = {cpfx[n][31:9],cnsta[45:0]}; has_cnsta = TRUE; cnsta85 = TRUE; end
			4'b1001:	begin cnstb = {cpfx[n][31:9],cnstb[45:0]}; has_cnstb = TRUE; cnstb85 = TRUE; end
			4'b1010:	begin cnstc = {cpfx[n][31:9],cnstc[45:0]}; has_cnstc = TRUE; cnstc85 = TRUE; end
			4'b1011:	begin cnstd = {cpfx[n][31:9],cnstd[45:0]}; has_cnstd = TRUE; cnstd85 = TRUE; end
			default:	;
			endcase
		end

end

endmodule
