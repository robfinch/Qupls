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
// 502 LUTs
// ============================================================================

import Stark_pkg::*;

module Stark_decode_const(cline, ins, imma, immb, immc, has_imma, has_immb, has_immc,
	pfxa, pfxb, pfxc, pos, isz);
input [511:0] cline;
input Stark_pkg::instruction_t ins;
output reg [31:0] imma;
output reg [31:0] immb;
output reg [31:0] immc;
output reg has_imma;
output reg has_immb;
output reg has_immc;
output reg pfxa;
output reg pfxb;
output reg pfxc;
output reg [7:0] pos;
output reg [3:0] isz;

Stark_pkg::instruction_t insf;
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

wire [31:0] cnst1, cnst2;
reg [31:0] cnst1a;

always_comb pos = Stark_pkg::fnConstPos(ins);
always_comb isz = Stark_pkg::fnConstSize(ins);

Stark_constant_decoder u1 (pos[3:0],isz[1:0],cline,cnst1);
Stark_constant_decoder u2 (pos[7:4],isz[3:2],cline,cnst2);

always_comb
begin
	flt = 1'd0;
	imma = 32'd0;
	immb = 32'd0;
	immc = 32'd0;
	has_imma = 1'b0;
	has_immb = 1'b0;
	has_immc = 1'b0;
	pfxa = 1'b0;
	pfxb = 1'b0;
	pfxc = 1'b0;
	finsA = 1'd0;
	finsB = 1'd0;
	finsC = 1'd0;
	case(ins.any.opcode)
	Stark_pkg::OP_ADD,Stark_pkg::OP_MUL,Stark_pkg::OP_DIV,Stark_pkg::OP_SUBF,Stark_pkg::OP_ADB:
		begin
			immb = Stark_pkg::fnHasExConst(ins) ? cnst1 : {{18{ins[30]}},ins[30:17]};
			has_immb = ins[31:29]!=3'b100;
		end
	Stark_pkg::OP_CMP:
		begin
			immb = Stark_pkg::fnHasExConst(ins) ? cnst1 :
				ins[10:9]==2'b01 ? {{18{1'b0}},ins[30:17]} :	// CMPA?
				{{18{ins[30]}},ins[30:17]};
			has_immb = ins[31:29]!=3'b100;
		end
	Stark_pkg::OP_AND:
		begin
			immb = Stark_pkg::fnHasExConst(ins) ? cnst1 : {{18{1'b1}},ins[30:17]};
			has_immb = ins[31:29]!=3'b100;
		end
	Stark_pkg::OP_OR,Stark_pkg::OP_XOR:
		begin
			immb = Stark_pkg::fnHasExConst(ins) ? cnst1 : {{18{1'b0}},ins[30:17]};
			has_immb = ins[31:29]!=3'b100;
		end
	Stark_pkg::OP_SHIFT:
		begin
			immb = ins[22:17];
			has_immb = ins[31]==1'b0;
		end
	Stark_pkg::OP_CSR:
		begin
			// ToDo: fix
			immb = {57'd0,ins[22:16]};
			has_immb = 1'b0;
		end
	Stark_pkg::OP_B0,Stark_pkg::OP_B1:
		begin
			immb = Stark_pkg::fnHasExConst(ins) ? cnst1 : ins[31] ? {{12{ins[25]}},ins[25:9],ins[0],2'b00} : {{7{ins[30]}},ins[30:9],ins[0],2'b00};
			has_immb = 1'b1;
		end
	Stark_pkg::OP_BCC0,Stark_pkg::OP_BCC1:
		begin
			immb = Stark_pkg::fnHasExConst(ins) ? cnst1 : {{19{ins[30]}},ins[30:29],ins[16:9],ins[0],2'b00};
			has_immb = ins[31:29]!=3'b100;
		end
	Stark_pkg::OP_LOADA,
	Stark_pkg::OP_LDB,Stark_pkg::OP_LDBZ,
	Stark_pkg::OP_LDW,Stark_pkg::OP_LDWZ,
	Stark_pkg::OP_LDT,Stark_pkg::OP_LDTZ,
	Stark_pkg::OP_LOAD,
	Stark_pkg::OP_STB,
	Stark_pkg::OP_STW,
	Stark_pkg::OP_STT,
	Stark_pkg::OP_STORE:
		begin
			immb = Stark_pkg::fnHasExConst(ins) ? cnst1 : {{18{ins[30]}},ins[30:17]};
			has_immb = ins[31:29]!=3'b100;
		end
	Stark_pkg::OP_STBI,Stark_pkg::OP_STWI,Stark_pkg::OP_STTI,Stark_pkg::OP_STOREI:
		begin
			immb = Stark_pkg::fnHasExConst(ins) ? cnst1 : {{18{ins[30]}},ins[30:17]};
			immc = cnst2;
			has_immb = ins[31:29]!=3'b100;
			has_immc = 1'b1;
		end
	OP_FENCE:
		begin
			immb = {112'h0,ins[23:8]};
			has_immb = 1'b1;
		end
	OP_PFX:
		begin
			case(ins[7:6])
			2'b00:
				begin
					imma = Stark_pkg::fnHasExConst(ins) ? cnst1 : {{4{ins[30]}},ins[30:8],5'd0};
					has_imma = 1'b1;
					pfxa = 1'b1;
				end
			2'b01:
				begin
					immb = Stark_pkg::fnHasExConst(ins) ? cnst1 : {{4{ins[30]}},ins[30:8],5'd0};
					has_immb = 1'b1;
					pfxb = 1'b1;
				end
			2'b10:
				begin
					immc = Stark_pkg::fnHasExConst(ins) ? cnst1 : {{4{ins[30]}},ins[30:8],5'd0};
					has_immc = 1'b1;
					pfxc = 1'b1;
				end
			default:
				begin
				end
			endcase
		end
	default:
		immb = 32'd0;
	endcase

end

endmodule
