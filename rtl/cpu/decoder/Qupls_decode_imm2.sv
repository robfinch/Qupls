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
	OP_R3B,OP_R3W,OP_R3T,OP_R3O:
		case(ins.ins.r3.func)
		FN_BYTENDX:
			begin
				immb = {{56{ins.ins[37]}},ins.ins[37:30]};
				has_immb = 1'b1;
			end
		default:	immb = 64'd0;
		endcase
	OP_ADDI,OP_CMPI,OP_MULI,OP_DIVI,OP_SUBFI,
	OP_AIPUI,OP_RTD:
		begin
			case(ins.ins.any.sz)
			2'd0:	immb = {{59{ins.ins[23]}},ins.ins[23:19]};
			2'd1:	immb = {{41{ins.ins.ins.ri.imm[22]}},ins.ins.ri.imm[22:0]};
			2'd2:	immb = {{17{ins.ins.ins.ri.imm[46]}},ins.ins.ri.imm[46:0]};
			2'd3:	immb = ins.ins.ri.imm[63:0];
			endcase
			has_immb = 1'b1;
		end
	OP_ANDI:
		begin
			case(ins.ins.any.sz)
			2'd0:	immb = {{59{1'b1}},ins.ins[23:19]};
			2'd1:	immb = {{41{1'b1}},ins.ins.ri.imm[22:0]};
			2'd2:	immb = {{17{1'b1}},ins.ins.ri.imm[46:0]};
			2'd3:	immb = ins.ins.ri.imm[63:0];
			endcase
			has_immb = 1'b1;
		end
	OP_ORI,OP_EORI,OP_MULUI,OP_DIVUI:
		begin
			case(ins.ins.any.sz)
			2'd0:	immb = {{59{1'b0}},ins.ins[23:19]};
			2'd1:	immb = {{41{1'b0}},ins.ins.ri.imm[22:0]};
			2'd2:	immb = {{17{1'b0}},ins.ins.ri.imm[46:0]};
			2'd3:	immb = ins.ins.ri.imm[63:0];
			endcase
			has_immb = 1'b1;
		end
	OP_SHIFTB,OP_SHIFTW,OP_SHIFTT,OP_SHIFTO:
		begin
			immc = ins.ins.lshifti.imm;
			has_immc = ins.ins.lshifti.func[3];
		end
	OP_CSR:
		begin
			// ToDo: fix
			immb = {57'd0,ins.ins[22:16]};
			has_immb = 1'b1;
		end
	OP_JSRR,OP_JSRI:
		begin
			case(ins.ins.any.sz)
			2'd0:	immb = {{59{ins.ins[23]}},ins.ins[23:19]};
			2'd1:	immb = {{48{ins.ins.ins.jsr.disp[15]}},ins.ins.jsr.disp[15:0]};
			2'd2:	immb = {{24{ins.ins.ins.jsr.disp[39]}},ins.ins.jsr.disp[39:0]};
			2'd3:	immb = ins.ins.jsr.disp[63:0];
			endcase
			has_immb = 1'b1;
		end
	OP_LDA,
	OP_LDx,OP_FLDx,OP_DFLDx,OP_PLDx,OP_LDxU,OP_CACHE,
	OP_STx,OP_FSTx,OP_DFSTx,OP_PSTx:
		begin
			case(ins.ins.any.sz)
			2'd0:	immb = {{59{ins.ins[23]}},ins.ins[23:19]};
			2'd1:	immb = {{48{ins.ins.ins.ls.disp[15]}},ins.ins.ls.disp[15:0]};
			2'd2:	immb = {{24{ins.ins.ins.ls.disp[39]}},ins.ins.ls.disp[39:0]};
			2'd3:	immb = ins.ins.ls.disp[63:0];
			endcase
			has_immb = 1'b1;
		end
	OP_FENCE:
		begin
			immb = {112'h0,ins.ins[23:8]};
			has_immb = 1'b1;
		end
	OP_Bcc,OP_BccU,OP_FBcc,OP_DFBcc,OP_PBcc:OP_IBcc,OP_DBcc:
		begin
			case(ins.ins.any.sz)
			2'd0:	immc = {{59{ins.ins[23]}},ins.ins[23:19]};
			2'd1:	immc = {{43{ins.ins.ins.ls.dispLo[20]}},ins.ins.br.dispLo};
			2'd2:	immc = {{20{ins.ins.ins.br.dispHi[23]}},ins.ins.br.dispHi,ins.ins.br.dispLo};
			2'd3:	immc = {ins.ins.br.dispHi,ins.ins.br.dispLo};
			endcase
			has_immc = 1'b1;
		end
	OP_PFX:
		begin
			case(ins.ins.pfx.sw)
			2'b00:
				begin
					case(ins.ins.any.sz)
					2'd0:	imma = {{46{ins.ins.pfx.imm[12]}},ins.ins.pfx.imm[12:0],5'd0};
					2'd1:	imma = {{22{ins.ins.pfx.imm[36]}},ins.ins.pfx.imm[36:0],5'd0};
					2'd2:	imma = {ins.ins.pfx.imm[60:0],5'd0};
					2'd3:	imma = {ins.ins.pfx.imm,5'd0};
					endcase
					has_imma = 1'b1;
					pfxa = 1'b1;
				end
			2'b01:
				begin
					case(ins.ins.any.sz)
					2'd0:	immb = {{46{ins.ins.pfx.imm[12]}},ins.ins.pfx.imm[12:0],5'd0};
					2'd1:	immb = {{22{ins.ins.pfx.imm[36]}},ins.ins.pfx.imm[36:0],5'd0};
					2'd2:	immb = {ins.ins.pfx.imm[60:0],5'd0};
					2'd3:	immb = {ins.ins.pfx.imm,5'd0};
					endcase
					has_immb = 1'b1;
					pfxb = 1'b1;
				end
			2'b10:
				begin
					case(ins.ins.any.sz)
					2'd0:	immc = {{46{ins.ins.pfx.imm[12]}},ins.ins.pfx.imm[12:0],5'd0};
					2'd1:	immc = {{22{ins.ins.pfx.imm[36]}},ins.ins.pfx.imm[36:0],5'd0};
					2'd2:	immc = {ins.ins.pfx.imm[60:0],5'd0};
					2'd3:	immc = {ins.ins.pfx.imm,5'd0};
					endcase
					has_immc = 1'b1;
					pfxc = 1'b1;
				end
			default:
				begin
				end
			endcase
		end
	default:
		immb = cpu_types_pkg::value_zero;
	endcase

	ndx = 1;
	flt = ins.ins.any.opcode==OP_FLT3H
	   || ins.ins.any.opcode==OP_FLT3S
	   || ins.ins.any.opcode==OP_FLT3D
	   || ins.ins.any.opcode==OP_FLT3Q;
	fltpr = ins.ins[40:39];

end

endmodule
