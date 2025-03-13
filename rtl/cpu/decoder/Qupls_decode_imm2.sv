// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Qupls_decode_imm.sv
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
// 502 LUTs
// ============================================================================

import QuplsPkg::*;

module Qupls_decode_imm(ins, imma, immb, immc, has_imma, has_immb, has_immc,
	pfxa, pfxb, pfxc);
input ex_instruction_t ins;
output cpu_types_pkg::value_t imma;
output cpu_types_pkg::value_t immb;
output cpu_types_pkg::value_t immc;
output reg has_imma;
output reg has_immb;
output reg has_immc;
output reg pfxa;
output reg pfxb;
output reg pfxc;

instruction_t insf;
wire [63:0] imm32x64a;
wire [63:0] imm32x64b;
wire [63:0] imm32x64c;
reg [2:0] ndx;
reg flt;
reg [1:0] fltpr;
reg [47:0] finsA, finsB, finsC;

fpCvt32To64 ucvt32x64a(finsA[39:8], imm32x64a);
fpCvt32To64 ucvt32x64b(finsB[39:8], imm32x64b);
fpCvt32To64 ucvt32x64C(finsC[39:8], imm32x64c);

always_comb
begin
	flt = 1'd0;
	imma = cpu_types_pkg::value_zero;
	immb = cpu_types_pkg::value_zero;
	immc = cpu_types_pkg::value_zero;
	has_imma = 1'b0;
	has_immb = 1'b0;
	has_immc = 1'b0;
	pfxa = 1'b0;
	pfxb = 1'b0;
	pfxc = 1'b0;
	finsA = 1'd0;
	finsB = 1'd0;
	finsC = 1'd0;
	case(ins.ins.any.opcode)
	OP_R2,OP_R3V,OP_R3VS:
		case(ins.ins.r3.func)
		FN_BYTENDX:
			begin
				immb = {{118{ins.ins[38]}},ins.ins[38:29]};
				has_immb = 1'b1;
			end
		default:	immb = 64'd0;
		endcase
	OP_ADDI,OP_CMPI,OP_MULI,OP_DIVI,OP_SUBFI:
		begin
			immb = {{32{ins.ins[63]}},ins.ins[63:32]};
			has_immb = 1'b1;
		end
	OP_ANDI:
		begin
			immb = {{32{1'b1}},ins.ins[63:32]};
			has_immb = 1'b1;
		end
	OP_ORI,OP_EORI,OP_MULUI,OP_DIVUI:
		begin
			immb = {32'h0000,ins.ins[63:32]};
			has_immb = 1'b1;
		end
	OP_AIPSI,OP_ADDSI:
		begin
			immb = {{27{ins.ins[63]}},ins.ins[63:27]};
			has_immb = 1'b1;
		end
	OP_ANDSI:
		begin
			immb = {27'h7FFFFFF,ins.ins[63:27]};
			has_immb = 1'b1;
		end
	OP_ORSI,OP_EORSI:
		begin
			immb = {27'h0,ins.ins[63:27]};
			has_immb = 1'b1;
		end
	OP_SHIFT:
		begin
			immc = ins.ins.shifti.imm;
			has_immc = ins.ins.shifti.i;
		end
	OP_CSR:
		begin
			// ToDo: fix
			immb = {114'd0,ins.ins[35:22]};
			has_immb = 1'b1;
		end
	OP_RTD:
		begin
			immb = {{32{ins.ins[63]}},ins.ins[63:32]};
			has_immb = 1'b1;
		end
	OP_JSRR,OP_JSRI:
		begin
			immb = {{32{ins.ins[63]}},ins.ins[63:32]};
			has_immb = 1'b1;
		end
	OP_LDA,
	OP_LDx,OP_FLDx,OP_DFLDx,OP_PLDx,OP_LDxU,OP_CACHE,
	OP_STx,OP_FSTx,OP_DFSTx,OP_PSTx:
		begin
			immb = {{40{ins.ins.ls.disp[23]}},ins.ins.ls.disp};
			has_immb = 1'b1;
		end
	OP_FENCE:
		begin
			immb = {112'h0,ins.ins[23:8]};
			has_immb = 1'b1;
		end
	OP_Bcc,OP_BccU,OP_FBcc:
		begin
			immc = {{38{ins.ins.br.dispHi[3]}},ins.ins.br.dispHi,ins.ins.br.dispLo};
//			immc = {{44{ins.ins[63]}},ins.ins[63:44]};
			has_immc = 1'b1;
		end
	OP_PFXAB:
		begin
			if (ins.ins.pfx.sw) begin
				immb = {ins.ins.pfx.imm,8'h00};
				has_immb = 1'b1;
				pfxb = 1'b1;
			end
			else begin
				imma = {ins.ins.pfx.imm,8'h00};
				has_imma = 1'b1;
				pfxa = 1'b1;
			end
		end
	OP_PFXC:
		begin
				immc = {ins.ins.pfx.imm,8'h00};
				has_immc = 1'b1;
				pfxc = 1'b1;
		end
	default:
		immb = cpu_types_pkg::value_zero;
	endcase

	ndx = 1;
	flt = ins.ins.any.opcode==OP_FLT3;
	fltpr = ins.ins[40:39];

end

endmodule
