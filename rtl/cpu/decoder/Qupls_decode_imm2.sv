// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2024  Robert Finch, Waterloo
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

module Qupls_decode_imm(ins, imma, immb, immc, has_imma, has_immb, has_immc);
input ex_instruction_t ins;
output cpu_types_pkg::value_t imma;
output cpu_types_pkg::value_t immb;
output cpu_types_pkg::value_t immc;
output reg has_imma;
output reg has_immb;
output reg has_immc;

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
			immb = {{104{ins.ins[47]}},ins.ins[47:24]};
			has_immb = 1'b1;
		end
	OP_ANDI:
		begin
			immb = {{104{1'b1}},ins.ins[47:24]};
			has_immb = 1'b1;
		end
	OP_ORI,OP_EORI,OP_MULUI,OP_DIVUI:
		begin
			immb = {104'h0000,ins.ins[47:24]};
			has_immb = 1'b1;
		end
	OP_ADDSI:
		begin
			immb = {{100{ins.ins[47]}},ins.ins[47:20]};
			has_immb = 1'b1;
		end
	OP_ANDSI:
		begin
			immb = {100'hFFFFFFFFFFFFFFFFFFFFFFFFF,ins.ins[47:20]};
			has_immb = 1'b1;
		end
	OP_ORSI,OP_EORSI:
		begin
			immb = {100'h0,ins.ins[47:20]};
			has_immb = 1'b1;
		end
	OP_CSR:
		begin
			immb = {114'd0,ins.ins[35:22]};
			has_immb = 1'b1;
		end
	OP_RTD:
		begin
			immb = {{104{ins.ins[47]}},ins.ins[47:24]};
			has_immb = 1'b1;
		end
	OP_JSR:
		begin
			immb = {{104{ins.ins[47]}},ins.ins[47:24]};
			has_immb = 1'b1;
		end
	OP_LDB,OP_LDBU,OP_LDW,OP_LDWU,OP_LDT,OP_LDTU,OP_LDO,OP_CACHE,
	OP_STB,OP_STW,OP_STT,OP_STO:
		begin
			immb = {{104{ins.ins[47]}},ins.ins[47:24]};
			has_immb = 1'b1;
		end
	OP_LDAX:
		begin
			immb = {{116{ins.ins[42]}},ins.ins[42:31]};
			has_immb = 1'b1;
		end
	OP_FENCE:
		begin
			immb = {112'h0,ins.ins[23:8]};
			has_immb = 1'b1;
		end
	OP_LDX:
		begin
			case(ins.ins.lsn.func)
			FN_LDCTX:	immb = {{53{ins.aRa[2]}},ins.aRa[2:0],ins.aRt[4:0],3'b0};
			default:
				immb = {{116{ins.ins[42]}},ins.ins[42:31]};
			endcase
			has_immb = 1'b0;
		end
	OP_STX:
		begin
			case(ins.ins.lsn.func)
			FN_STCTX:	immb = {{53{ins.aRa[2]}},ins.aRa[2:0],ins.aRt[4:0],3'b0};
			default:
				immb = {{116{ins.ins[42]}},ins.ins[42:31]};
			endcase
			has_immb = 1'b0;
		end
	OP_Bcc,OP_BccU,OP_FBcc:
		begin
			immc = {{108{ins.ins[47]}},ins.ins[47:31],ins.ins[27],ins.ins[20],ins.ins[14]};
			has_immc = 1'b1;
		end
	default:
		immb = cpu_types_pkg::value_zero;
	endcase

	ndx = 1;
	flt = ins.ins.any.opcode==OP_FLT3;
	fltpr = ins.ins[40:39];

end

endmodule
