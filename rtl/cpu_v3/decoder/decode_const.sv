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

import Qupls3_pkg::*;

module decode_const(cline, ins, imma, immb, immc, has_imma, has_immb, has_immc,
	pfxa, pfxb, pfxc);
input [511:0] cline;
input Qupls3_pkg::instruction_t ins;
output reg [31:0] imma;
output reg [31:0] immb;
output reg [31:0] immc;
output reg has_imma;
output reg has_immb;
output reg has_immc;
output reg pfxa;
output reg pfxb;
output reg pfxc;

Qupls3_pkg::instruction_t insf;
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

reg [7:0] pos;
reg [3:0] isz;
wire [31:0] cnst1, cnst2;
reg [31:0] cnst1a;

always_comb pos = fnConstPos(ins);
always_comb isz = fnConstSize(ins);

constant_decoder u1 (pos[3:0],isz[1:0],cline,cnst1);
constant_decoder u2 (pos[7:4],isz[3:2],cline,cnst2);

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
	OP_ADD,OP_MUL,OP_DIV,OP_SUBF,OP_ADB:
		begin
			immb = fnHasExConst(ins) ? cnst1 : {{18{ins[30]}},ins[30:17]};
			has_immb = ins[31:29]!=3'b100;
		end
	OP_CMP:
		begin
			immb = fnHasExConst(ins) ? cnst1 :
				ins[10:9]==2'b01 ? {{18{1'b0}},ins[30:17]} :	// CMPA?
				{{18{ins[30]}},ins[30:17]};
			has_immb = ins[31:29]!=3'b100;
		end
	OP_AND:
		begin
			immb = fnHasExConst(ins) ? cnst1 : {{18{1'b1}},ins[30:17]};
			has_immb = ins[31:29]!=3'b100;
		end
	OP_OR,OP_XOR:
		begin
			immb = fnHasExConst(ins) ? cnst1 : {{18{1'b0}},ins[30:17]};
			has_immb = ins[31:29]!=3'b100;
		end
	OP_SHIFT:
		begin
			immb = ins[22:17];
			has_immb = ins[31]==1'b0;
		end
	OP_CSR:
		begin
			// ToDo: fix
			immb = {57'd0,ins[22:16]};
			has_immb = 1'b0;
		end
	OP_B0,OP_B1:
		begin
			immb = fnHasExConst(ins) ? cnst1 : ins[31] ? {{12{ins[25]}},ins[25:9],ins[0],2'b00} : {{7{ins[30]}},ins[30:9],ins[0],2'b00};
			has_immb = 1'b1;
		end
	OP_BCC0,OP_BCC1:
		begin
			immb = fnHasExConst(ins) ? cnst1 : {{19{ins[30]}},ins[30:29],ins[16:9],ins[0],2'b00};
			has_immb = ins[31:29]!=3'b100;
		end
	OP_LDA,
	OP_LDB,OP_LDBZ,OP_LDW,OP_LDWZ,OP_LDT,OP_LDTZ,OP_LOAD,
	OP_STB,OP_STW,OP_STT,OP_STORE:
		begin
			immb = fnHasExConst(ins) ? cnst1 : {{18{ins[30]}},ins[30:17]};
			has_immb = ins[31:29]!=3'b100;
		end
	OP_STBI,OP_STWI,OP_STTI,OP_STOREI:
		begin
			immb = fnHasExConst(ins) ? cnst1 : {{18{ins[30]}},ins[30:17]};
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
					imma = fnHasExConst(ins) ? cnst1 : {{4{ins[30]}},ins[30:8],5'd0};
					has_imma = 1'b1;
					pfxa = 1'b1;
				end
			2'b01:
				begin
					immb = fnHasExConst(ins) ? cnst1 : {{4{ins[30]}},ins[30:8],5'd0};
					has_immb = 1'b1;
					pfxb = 1'b1;
				end
			2'b10:
				begin
					immc = fnHasExConst(ins) ? cnst1 : {{4{ins[30]}},ins[30:8],5'd0};
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
