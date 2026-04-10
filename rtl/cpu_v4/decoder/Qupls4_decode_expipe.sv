// ============================================================================
//        __
//   \\__/ o\    (C) 2026  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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
// ============================================================================

import Qupls4_pkg::*;

module Qupls4_decode_expipe(instr, expipe);
input Qupls4_pkg::micro_op_t instr;
output [5:0] expipe;

function fnExPipe;
input Qupls4_pkg::micro_op_t ir;
begin
	case(ir.opcode)
	Qupls4_pkg::OP_BFLD:
		fnExPipe = 6'b000001;
	Qupls4_pkg::OP_R3B,Qupls4_pkg::OP_R3W,Qupls4_pkg::OP_R3T,Qupls4_pkg::OP_R3O,
	Qupls4_pkg::OP_R3BP,Qupls4_pkg::OP_R3WP,Qupls4_pkg::OP_R3TP,Qupls4_pkg::OP_R3OP,
	Qupls4_pkg::OP_R3VVV,Qupls4_pkg::OP_R3VVS:
		case(ir.func)
		FN_AND,FN_OR,FN_XOR,
		FN_NAND,FN_NOR,FN_XNOR,
		FN_CMP,FN_ADD,FN_SUB,FN_CMPU,
		FN_MOVE:
			fnExPipe = 6'b111111;
		FN_MUL,FN_MULU,FN_MULSU:
			fnExPipe = 6'b001100;
		FN_DIV,FN_DIVU,FN_DIVSU:
			fnExPipe = 6'b010000;
		FN_NNA_MTWT,FN_NNA_MTIN,FN_NNA_MTBIAS,
		FN_NNA_MTFB,FN_NNA_MTMC,FN_NNA_MTBC:
			fnExPipe = 6'b000100;
		FN_ROL,FN_ROR,FN_ASR,FN_ASL,FN_LSR:
			fnExPipe = 6'b000001;
		FN_REDAND,FN_REDOR,FN_REDEOR,
		FN_REDMINU,FN_REDSUM,FN_REDMAXU,FN_REDMIN,FN_REDMAX:
			fnExPipe = 6'b000001;
		FN_PEEKQ,FN_POPQ,FN_PUSHQ,FN_RESETQ,
		FN_STATQ,FN_READQ,FN_WRITEQ:
			fnExPipe = 6'b001000;
		FN_SEQ,FN_SNE,FN_SLT,FN_SLE,FN_SLTU,FN_SLEU:
			fnExPipe = 6'b111111;
		default:
			fnExPipe = 6'b111111;
		endcase
	Qupls4_pkg::OP_FLTH,Qupls4_pkg::OP_FLTS,Qupls4_pkg::OP_FLTD,Qupls4_pkg::OP_FLTQ,
	Qupls4_pkg::OP_FLTPH,Qupls4_pkg::OP_FLTPS,Qupls4_pkg::OP_FLTPD,Qupls4_pkg::OP_FLTPQ,
	Qupls4_pkg::OP_FLTVVV,Qupls4_pkg::OP_FLTVVS:
		case(ir.func)
		Qupls4_pkg::FLT_FMA,Qupls4_pkg::FLT_FMS,Qupls4_pkg::FLT_FNMA,Qupls4_pkg::FLT_FNMS:
			fnExPipe = 6'b011000;
		Qupls4_pkg::FLT_CMP,
		Qupls4_pkg::FLT_ABS,Qupls4_pkg::FLT_NEG:
			fnExPipe = 6'b111111;
		default:	fnExPipe = 6'b000000;
		endcase
	Qupls4_pkg::OP_CHK:
		fnExPipe = 6'b000001;
	Qupls4_pkg::OP_ADDI,
	Qupls4_pkg::OP_SUBFI,
	Qupls4_pkg::OP_CMPI,
	Qupls4_pkg::OP_CMPUI,
	Qupls4_pkg::OP_LOADI,
	Qupls4_pkg::OP_LOADA,
	Qupls4_pkg::OP_ANDI,
	Qupls4_pkg::OP_ORI,
	Qupls4_pkg::OP_XORI:
		fnExPipe = 6'b111111;
	Qupls4_pkg::OP_SHIFT,
	Qupls4_pkg::OP_CSR:
		fnExPipe = 6'b000001;
	Qupls4_pkg::OP_FENCE:
		fnExPipe = 6'b000001;
	Qupls4_pkg::OP_LDB,Qupls4_pkg::OP_LDBZ,Qupls4_pkg::OP_LDW,Qupls4_pkg::OP_LDWZ,
	Qupls4_pkg::OP_LDT,Qupls4_pkg::OP_LDTZ,Qupls4_pkg::OP_LOAD,
	Qupls4_pkg::OP_STB,Qupls4_pkg::OP_STW,
	Qupls4_pkg::OP_STT,Qupls4_pkg::OP_STORE,
	Qupls4_pkg::OP_STI,
	Qupls4_pkg::OP_STPTR,
	Qupls4_pkg::OP_V2P,
	Qupls4_pkg::OP_VV2P,
	Qupls4_pkg::OP_AMO:
		fnExPipe = 6'b110000;
	Qupls4_pkg::OP_BCC,Qupls4_pkg::OP_BCCU,Qupls4_pkg::OP_FBCC,
	Qupls4_pkg::OP_BSR,Qupls4_pkg::OP_JSR,Qupls4_pkg::OP_JSRN,
	Qupls4_pkg::OP_SYS,
	Qupls4_pkg::OP_BRK,
	Qupls4_pkg::OP_RTD:
		fnExPipe = 6'b000010;
	default:
		fnExPipe = 6'b000000;
	endcase
end
endfunction

assign expipe = fnExPipe(instr);

endmodule
