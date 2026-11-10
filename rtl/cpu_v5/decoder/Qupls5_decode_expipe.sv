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

import Qupls5_pkg::*;

module Qupls5_decode_expipe(instr, expipe);
input Qupls5_pkg::micro_op_t instr;
output [6:0] expipe;

function [6:0] fnExPipe;
input Qupls5_pkg::micro_op_t ir;
begin
	case(ir.opcode)
	Qupls5_pkg::OP_BFLD:
		fnExPipe = {5'b00000,Qupls5_pkg::SUPPORT_BFLD1[0],Qupls5_pkg::SUPPORT_BFLD0[0]};
	Qupls5_pkg::OP_R3B,Qupls5_pkg::OP_R3W,Qupls5_pkg::OP_R3T,Qupls5_pkg::OP_R3O,
	Qupls5_pkg::OP_VR3B,Qupls5_pkg::OP_VR3W,Qupls5_pkg::OP_VR3T,Qupls5_pkg::OP_VR3O,
	Qupls5_pkg::OP_VSR3B,Qupls5_pkg::OP_VSR3W,Qupls5_pkg::OP_VSR3T,Qupls5_pkg::OP_VSR3O:
		case(ir.func)
		Qupls5_pkg::FN_AND,Qupls5_pkg::FN_OR,Qupls5_pkg::FN_XOR,
		Qupls5_pkg::FN_NAND,Qupls5_pkg::FN_NOR,Qupls5_pkg::FN_XNOR,
		Qupls5_pkg::FN_CMP,Qupls5_pkg::FN_ADD,Qupls5_pkg::FN_SUB,Qupls5_pkg::FN_CMPU,
		Qupls5_pkg::FN_MOVE:
			fnExPipe = 7'b0111111;
		Qupls5_pkg::FN_MUL,Qupls5_pkg::FN_MULU,Qupls5_pkg::FN_MULSU:
			fnExPipe = 7'b0001100;
		Qupls5_pkg::FN_DIV,Qupls5_pkg::FN_DIVU,Qupls5_pkg::FN_DIVSU:
			fnExPipe = 7'b0110000;
		Qupls5_pkg::FN_NNA_MTWT,Qupls5_pkg::FN_NNA_MTIN,Qupls5_pkg::FN_NNA_MTBIAS,
		Qupls5_pkg::FN_NNA_MTFB,Qupls5_pkg::FN_NNA_MTMC,Qupls5_pkg::FN_NNA_MTBC:
			fnExPipe = 7'b0000100;
		Qupls5_pkg::FN_ROL,Qupls5_pkg::FN_ROR,Qupls5_pkg::FN_ASR,Qupls5_pkg::FN_ASL,Qupls5_pkg::FN_LSR:
			fnExPipe = 7'b0000011;
		Qupls5_pkg::FN_REDAND,Qupls5_pkg::FN_REDOR,Qupls5_pkg::FN_REDEOR,
		Qupls5_pkg::FN_REDMINU,Qupls5_pkg::FN_REDSUM,Qupls5_pkg::FN_REDMAXU,Qupls5_pkg::FN_REDMIN,Qupls5_pkg::FN_REDMAX:
			fnExPipe = 7'b0000001;
		Qupls5_pkg::FN_PEEKQ,Qupls5_pkg::FN_POPQ,Qupls5_pkg::FN_PUSHQ,Qupls5_pkg::FN_RESETQ,
		Qupls5_pkg::FN_STATQ,Qupls5_pkg::FN_READQ,Qupls5_pkg::FN_WRITEQ:
			fnExPipe = 7'b0001000;
		Qupls5_pkg::FN_SEQ,Qupls5_pkg::FN_SNE,Qupls5_pkg::FN_SLT,Qupls5_pkg::FN_SLE,Qupls5_pkg::FN_SLTU,Qupls5_pkg::FN_SLEU:
			fnExPipe = 7'b0111111;
		default:
			fnExPipe = 7'b0111111;
		endcase
	Qupls5_pkg::OP_FLTH,Qupls5_pkg::OP_FLTS,Qupls5_pkg::OP_FLTD,Qupls5_pkg::OP_FLTQ,
	Qupls5_pkg::OP_VFLTH,Qupls5_pkg::OP_VFLTS,Qupls5_pkg::OP_VFLTD,
	Qupls5_pkg::OP_VFLTSH,Qupls5_pkg::OP_VFLTSS,Qupls5_pkg::OP_VFLTSD:
		case(ir.func)
		Qupls5_pkg::FLT_FMA,Qupls5_pkg::FLT_FMS,Qupls5_pkg::FLT_FNMA,Qupls5_pkg::FLT_FNMS:
			fnExPipe = 7'b0111100;
		Qupls5_pkg::FLT_CMP,
		Qupls5_pkg::FLT_ABS,Qupls5_pkg::FLT_NEG:
			fnExPipe = 7'b0111111;
		default:	fnExPipe = 7'b000000;
		endcase
	Qupls5_pkg::OP_FADDI:
		fnExPipe = 7'b0111100;
	Qupls5_pkg::OP_CHK:
		fnExPipe = 7'b0000001;
	Qupls5_pkg::OP_ADDI,
	Qupls5_pkg::OP_SUBFI,
	Qupls5_pkg::OP_CMPI,
	Qupls5_pkg::OP_CMPUI,
	Qupls5_pkg::OP_LOADA,
	Qupls5_pkg::OP_ANDI,
	Qupls5_pkg::OP_ORI,
	Qupls5_pkg::OP_XORI:
		fnExPipe = 7'b0111111;
	Qupls5_pkg::OP_SHIFT:
		fnExPipe = {5'b00000,Qupls5_pkg::SUPPORT_SHIFT1[0],Qupls5_pkg::SUPPORT_SHIFT0[0]};
	Qupls5_pkg::OP_CSR:
		fnExPipe = {5'b00000,Qupls5_pkg::SUPPORT_CSR1[0],Qupls5_pkg::SUPPORT_CSR0[0]};
	Qupls5_pkg::OP_FENCE:
		fnExPipe = 7'b0000001;
	Qupls5_pkg::OP_LDB,Qupls5_pkg::OP_LDBZ,Qupls5_pkg::OP_LDW,Qupls5_pkg::OP_LDWZ,
	Qupls5_pkg::OP_LDT,Qupls5_pkg::OP_LDTZ,Qupls5_pkg::OP_LOAD,
	Qupls5_pkg::OP_STB,Qupls5_pkg::OP_STW,
	Qupls5_pkg::OP_STT,Qupls5_pkg::OP_STORE,Qupls5_pkg::OP_CSTORE,
	Qupls5_pkg::OP_STPTR,
	Qupls5_pkg::OP_V2P,
	Qupls5_pkg::OP_VV2P,
	Qupls5_pkg::OP_AMO:
		fnExPipe = 7'b0110000;
	// Branches must be supported on at least one pipe.
	Qupls5_pkg::OP_BCC,Qupls5_pkg::OP_BCCU,Qupls5_pkg::OP_FBCC,Qupls5_pkg::OP_MBCC,
	Qupls5_pkg::OP_BSR,Qupls5_pkg::OP_JSR,Qupls5_pkg::OP_JSRN,
	Qupls5_pkg::OP_SYS,
	Qupls5_pkg::OP_BRK,
	Qupls5_pkg::OP_RTD:
		fnExPipe = Qupls5_pkg::SUPPORT_BRANCH1 ? 7'b0000010 : 7'b0000001;
	Qupls5_pkg::OP_CAP:
		case(ir.func)
		// The following read one cap op and write to the GPR.
		Qupls5_pkg::CAP_GETBASE:		fnExPipe = 7'b0110000;
		Qupls5_pkg::CAP_GETFLAGS:		fnExPipe = 7'b0110000;
		Qupls5_pkg::CAP_GETTYPE:		fnExPipe = 7'b0110000;
		Qupls5_pkg::CAP_GETLENGTH:	fnExPipe = 7'b0110000;
		Qupls5_pkg::CAP_GETOFFSET:	fnExPipe = 7'b0110000;
		Qupls5_pkg::CAP_GETADDR:		fnExPipe = 7'b0110000;
		Qupls5_pkg::CAP_GETPERMS:		fnExPipe = 7'b0110000;
		Qupls5_pkg::CAP_GETTAG:			fnExPipe = 7'b0110000;
		Qupls5_pkg::CAP_GETTOP:			fnExPipe = 7'b0110000;
		Qupls5_pkg::CAP_GETHIGH:		fnExPipe = 7'b0110000;
		Qupls5_pkg::CAP_ALGNMASK:		fnExPipe = 7'b0110000;
		Qupls5_pkg::CAP_GETSEALED:	fnExPipe = 7'b0110000;
		// The following read two cap ops and write to the CAP file.
		Qupls5_pkg::CAP_SETEQUALSEXACT:	fnExPipe = 7'b1000000;
		Qupls5_pkg::CAP_TESTSUBSET:	fnExPipe = 7'b1000000;
		// Reads one cap writes to CAP file.
		Qupls5_pkg::CAP_MOVE:		fnExPipe = 7'b1000000;
		// Reads two caps no write, may exception.
		Qupls5_pkg::CAP_CHKINVOKE:	fnExPipe = 7'b1000000;
		Qupls5_pkg::CAP_CHKBOUNDS:	fnExPipe = 7'b1000000;
		
		Qupls5_pkg::CAP_INCOFFSET:	fnExPipe = 7'b1000000;
		Qupls5_pkg::CAP_INCOFFSETI:	fnExPipe = 7'b1000000;
		Qupls5_pkg::CAP_INVOKE:	fnExPipe = 7'b1000000;
		Qupls5_pkg::CAP_ANDPERM:	fnExPipe = 7'b1000000;
		Qupls5_pkg::CAP_BUILDCAP:	fnExPipe = 7'b1000000;
		Qupls5_pkg::CAP_COPYTYPE:	fnExPipe = 7'b1000000;
		Qupls5_pkg::CAP_SEAL:	fnExPipe = 7'b1000000;
		Qupls5_pkg::CAP_SETADDR:	fnExPipe = 7'b1000000;
		Qupls5_pkg::CAP_SETBOUNDS:	fnExPipe = 7'b1000000;
		Qupls5_pkg::CAP_SETFLAGS:	fnExPipe = 7'b1000000;
		Qupls5_pkg::CAP_SETHIGH:	fnExPipe = 7'b1000000;
		Qupls5_pkg::CAP_INCOFFSETI:	fnExPipe = 7'b1000000;
		Qupls5_pkg::CAP_CLEARTAG:	fnExPipe = 7'b1000000;
		Qupls5_pkg::CAP_LOADTAGS:	fnExPipe = 7'b0110000;
		Qupls5_pkg::CAP_SEALENTRY:	fnExPipe = 7'b1000000;
		default:
			fnExPipe = 7'b0000000;
		endcase
	default:
		fnExPipe = 7'b0000000;
	endcase
end
endfunction

assign expipe = fnExPipe(instr);

endmodule
