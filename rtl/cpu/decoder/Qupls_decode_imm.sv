// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
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
// 400 LUTs
// ============================================================================

import QuplsPkg::*;

module Qupls_decode_imm(ins, imma, immb, immc);
parameter WID=32;
input instruction_t [3:0] ins;
output reg [63:0] imma;
output reg [63:0] immb;
output reg [63:0] immc;

instruction_t insf;
wire [63:0] imm32x64a;
wire [63:0] imm32x64b;
wire [63:0] imm32x64c;
reg [2:0] ndx;
reg flt;
reg [47:0] finsA, finsB, finsC;

fpCvt32To64 ucvt32x64a(finsA[40:9], imm32x64a);
fpCvt32To64 ucvt32x64b(finsB[40:9], imm32x64b);
fpCvt32To64 ucvt32x64C(finsC[40:9], imm32x64c);

always_comb
begin
	flt = 'd0;
	imma = 'd0;
	immb = 'd0;
	immc = 'd0;
	case(ins[0].any.opcode)
	OP_ADDI,OP_CMPI,OP_MULI,OP_DIVI,OP_SUBFI,OP_SLTI:
		immb = {{51{ins[0][31]}},ins[0][31:19]};
	OP_ANDI:	immb = {51'h7FFFFFFFFFFFF,ins[0][31:19]};
	OP_ORI,OP_EORI:
		immb = {51'h0000,ins[0][31:19]};
	OP_CSR:	immb = {53'd0,ins[0][29:19]};
	OP_RTD:	immb = {{43{ins[0][39]}},ins[0][39:19]};
	OP_JSR: immb = {{43{ins[0][39]}},ins[0][39:19]};
	OP_LDB,OP_LDBU,OP_LDW,OP_LDWU,OP_LDT,OP_LDTU,OP_LDO,OP_LDA,OP_CACHE,
	OP_STB,OP_STW,OP_STT,OP_STO:
		immb = {{51{ins[0][31]}},ins[0][31:19]};
	OP_FENCE:
		immb = {48'h0,ins[0][23:8]};
	default:
		immb = 'd0;
	endcase

	ndx = 1;
	flt = ins[0].any.opcode==OP_FLT2 || ins[0].any.opcode==OP_FLT3;

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
	if (ins[ndx].any.opcode==OP_PFXA) tOPFXA;
	if (ins[ndx].any.opcode==OP_PFXB) tOPFXB;
	if (ins[ndx].any.opcode==OP_PFXC) tOPFXC;
end

task tOPFXA;
begin
	if (flt) begin
		finsA = ins[ndx][40:9];
		case(ins[ndx].pfx.len)
		2'd0:	imma = 0;
		2'd1: imma = imm32x64a;
		2'd2:	imma = ins[ndx][72:9];
		default:	imma = 0;
		endcase
	end
	else begin
		case(ins[ndx].pfx.len)
		2'd0:	imma = {{41{ins[ndx][31]}},ins[ndx][31:9]};
		2'd1:	imma = {{25{ins[ndx][47]}},ins[ndx][47:9]};
		2'd2:	imma = ins[ndx][72:9];
		2'd3:	imma = ins[ndx][72:9];
		endcase
	end
	ndx = ndx + 1;
end
endtask

task tOPFXB;
begin
	if (flt) begin
		finsB = ins[ndx][40:9];
		case(ins[ndx].pfx.len)
		2'd0:	immb = 0;
		2'd1: immb = imm32x64b;
		2'd2:	immb = ins[ndx][72:9];
		default:	immb = 0;
		endcase
	end
	else begin
		case(ins[ndx].pfx.len)
		2'd0:	immb = {{41{ins[ndx][31]}},ins[ndx][31:9]};
		2'd1:	immb = {{25{ins[ndx][47]}},ins[ndx][47:9]};
		2'd2:	immb = ins[ndx][72:9];
		2'd3:	immb = ins[ndx][72:9];
		endcase
	end
	ndx = ndx + 1;
end
endtask

task tOPFXC;
begin
	if (flt) begin
		finsC = ins[ndx][40:9];
		case(ins[ndx].pfx.len)
		2'd0:	immc = 0;
		2'd1: immc = imm32x64c;
		2'd2:	immc = ins[ndx][72:9];
		default:	immc = 0;
		endcase
	end
	else begin
		case(ins[ndx].pfx.len)
		2'd0:	immc = {{41{ins[ndx][31]}},ins[ndx][31:9]};
		2'd1:	immc = {{25{ins[ndx][47]}},ins[ndx][47:9]};
		2'd2:	immc = ins[ndx][72:9];
		2'd3:	immc = ins[ndx][72:9];
		endcase
	end
	ndx = ndx + 1;
end
endtask

endmodule
