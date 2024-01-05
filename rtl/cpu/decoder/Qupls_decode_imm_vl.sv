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
parameter WID=32;
input ex_instruction_t [5:0] ins;
output reg [63:0] imma;
output reg [63:0] immb;
output reg [63:0] immc;
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
	flt = 'd0;
	imma = 'd0;
	immb = 'd0;
	immc = 'd0;
	has_imma = 1'b0;
	has_immb = 1'b0;
	has_immc = 1'b0;
	finsA = 'd0;
	finsB = 'd0;
	finsC = 'd0;
	case(ins[0].ins.any.opcode)
	OP_ADDI,OP_CMPI,OP_MULI,OP_DIVI,OP_SUBFI,OP_SLTI:
		begin
			immb = {{43{ins[0].ins[39]}},ins[0].ins[39:19]};
			has_immb = 1'b1;
		end
	OP_ANDI:
		begin
			immb = {64{1'b1}} & ins[0].ins[39:19];
			has_immb = 1'b1;
		end
	OP_ORI,OP_EORI,OP_MULUI,OP_DIVUI:
		begin
			immb = {43'h0000,ins[0].ins[31:19]};
			has_immb = 1'b1;
		end
	OP_ADDSI:
		begin
			immb = {{40{ins[0].ins[39]}},ins[0].ins[39:16]};
			has_immb = 1'b1;
		end
	OP_ANDSI:
		begin
			immb = {40'hFFFFFFFFFF,ins[0].ins[39:16]};
			has_immb = 1'b1;
		end
	OP_ORSI,OP_EORSI:
		begin
			immb = {40'h0,ins[0].ins[39:16]};
			has_immb = 1'b1;
		end
	OP_CSR:
		begin
			immb = {53'd0,ins[0].ins[29:19]};
			has_immb = 1'b1;
		end
	OP_RTD:
		begin
			immb = {{43{ins[0].ins[39]}},ins[0].ins[39:19]};
			has_immb = 1'b1;
		end
	OP_JSR:
		begin
			immb = {{43{ins[0].ins[39]}},ins[0].ins[39:19]};
			has_immb = 1'b1;
		end
	OP_LDBIP,OP_LDBUIP,OP_LDWIP,OP_LDWUIP,OP_LDTIP,OP_LDTUIP,OP_LDOIP,
	OP_LDB,OP_LDBU,OP_LDW,OP_LDWU,OP_LDT,OP_LDTU,OP_LDO,OP_CACHE,
	OP_STB,OP_STW,OP_STT,OP_STO:
		begin
			immb = {{43{ins[0].ins[39]}},ins[0].ins[39:19]};
			has_immb = 1'b1;
		end
	OP_LDAX:
		begin
			immb = {{56{ins[0].ins[34]}},ins[0].ins[34:27]};
			has_immb = 1'b1;
		end
	OP_FENCE:
		begin
			immb = {48'h0,ins[0].ins[23:8]};
			has_immb = 1'b1;
		end
	OP_Bcc,OP_BccU,OP_FBccH,OP_FBccS,OP_FBccD,OP_FBccQ:
		begin
			immc = {{47{ins[0].ins[39]}},ins[0].ins[39:25],ins[0].ins[12:11]};
			has_immc = 1'b1;
		end
	default:
		immb = 'd0;
	endcase

	ndx = 1;
	flt = ins[0].ins.any.opcode==OP_FLT3;
	fltpr = ins[0].ins[26:25];
	// Skip over vector qualifier.
	if (ins[ndx].ins.any.opcode==OP_VEC || ins[ndx].ins.any.opcode==OP_VECZ)
		ndx = ndx + 1;

	// The following allows three postfixes in any order. But needs more hardware.
	/*
	case(ins[ndx].any.opcode)
	OP_PFXA:	tOPFXA;
	OP_PFXB:	tOPFXB;
	OP_PFXC:	tOPFXC;
	default:	;
	endcase

	case(ins[ndx].any.opcode)
	OP_PFXA:	tOPFXA;
	OP_PFXB:	tOPFXB;
	OP_PFXC:	tOPFXC;
	default:	;
	endcase

	case(ins[ndx].any.opcode)
	OP_PFXA:	tOPFXA;
	OP_PFXB:	tOPFXB;
	OP_PFXC:	tOPFXC;
	default:	;
	endcase
	*/
	// The following uses less hardware but require postfixes to be in order.
	if (SUPPORT_POSTFIX) begin
		if (ins[ndx].ins.any.opcode==OP_PFXA32) begin
			has_imma = 1'b1;
			imma = {{32{ins[ndx].ins[39]}},ins[ndx].ins[39:8]};
			if (flt && fltpr==2'd2)
				imma = imm32x64a;
			ndx = ndx + 1;
			if (ins[ndx].ins.any.opcode==OP_PFXA32) begin
				imma[63:32] = ins[ndx].ins[39:8];
				ndx = ndx + 1;
			end
		end
		if (ins[ndx].ins.any.opcode==OP_PFXB32) begin
			has_immb = 1'b1;
			immb = {{32{ins[ndx].ins[39]}},ins[ndx].ins[39:8]};
			if (flt && fltpr==2'd2)
				immb = imm32x64b;
			ndx = ndx + 1;
			if (ins[ndx].ins.any.opcode==OP_PFXB32) begin
				immb[63:32] = ins[ndx].ins[39:8];
				ndx = ndx + 1;
			end
		end
		if (ins[ndx].ins.any.opcode==OP_PFXC32) begin
			has_immc = 1'b1;
			immc = {{32{ins[ndx].ins[39]}},ins[ndx].ins[39:8]};
			if (flt && fltpr==2'd2)
				immc = imm32x64c;
			ndx = ndx + 1;
			if (ins[ndx].ins.any.opcode==OP_PFXC32) begin
				immc[63:32] = ins[ndx].ins[39:8];
				ndx = ndx + 1;
			end
		end
	end
	
	/*
	if ((ins[ndx].any.opcode==OP_PFXA32)||
		(ins[ndx].any.opcode==OP_PFXA64)||
		(ins[ndx].any.opcode==OP_PFXA128))
		tOPFXA;
	if ((ins[ndx].any.opcode==OP_PFXB32)||
		(ins[ndx].any.opcode==OP_PFXB64)||
		(ins[ndx].any.opcode==OP_PFXB128))
		tOPFXB;
	if ((ins[ndx].any.opcode==OP_PFXC32)||
		(ins[ndx].any.opcode==OP_PFXC64)||
		(ins[ndx].any.opcode==OP_PFXC128))
		tOPFXC;
	*/
end

/*
task tOPFXA;
begin
	if (flt) begin
		finsA = ins[ndx][39:8];
		case(ins[ndx].any.opcode[1:0])
		2'd0: imma = imm32x64a;
		2'd1: imma = ins[ndx][71:8];
		default:	imma = 0;
		endcase
	end
	else begin
		case(ins[ndx].any.opcode[1:0])
		2'd0:	imma = {{32{ins[ndx][39]}},ins[ndx][39:8]};
		2'd1:	imma = ins[ndx][71:8];
		default:	imma = 0;
		endcase
	end
	ndx = ndx + 1;
end
endtask

task tOPFXB;
begin
	if (flt) begin
		finsB = ins[ndx][39:8];
		case(ins[ndx].any.opcode[1:0])
		2'd0: immb = imm32x64b;
		2'd1: immb = ins[ndx][71:8];
		default:	immb = 0;
		endcase
	end
	else begin
		case(ins[ndx].any.opcode[1:0])
		2'd0:	immb = {{32{ins[ndx][39]}},ins[ndx][39:8]};
		2'd1:	immb = ins[ndx][71:8];
		default:	immb = 0;
		endcase
	end
	ndx = ndx + 1;
end
endtask

task tOPFXC;
begin
	if (flt) begin
		finsC = ins[ndx][39:8];
		case(ins[ndx].any.opcode[1:0])
		2'd0: immc = imm32x64c;
		2'd1: immc = ins[ndx][71:8];
		default:	immc = 0;
		endcase
	end
	else begin
		case(ins[ndx].any.opcode[1:0])
		2'd0:	immc = {{32{ins[ndx][39]}},ins[ndx][39:8]};
		2'd1:	immc = ins[ndx][71:8];
		default:	immc = 0;
		endcase
	end
	ndx = ndx + 1;
end
endtask
*/
endmodule
