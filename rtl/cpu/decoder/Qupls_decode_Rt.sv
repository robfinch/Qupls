// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2025  Robert Finch, Waterloo
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

import cpu_types_pkg::*;
import QuplsPkg::*;

module Qupls_decode_Rt(om, ipl, instr, Rt, Rtz, Rtn);
input operating_mode_t om;
input [2:0] ipl;
input ex_instruction_t instr;
output aregno_t Rt;
output reg Rtz;
output reg Rtn;

function aregno_t fnRt;
input ex_instruction_t ir;
begin
	case(ir.ins.any.opcode)
	OP_RTD:
		fnRt = 6'd31;
	OP_FLT3H,OP_FLT3S,OP_FLT3D,OP_FLT3Q:
		fnRt = ir.ins.f3.Rt.num;
	OP_R3B,OP_R3W,OP_R3T,OP_R3O,OP_MOV:
		fnRt = ir.ins.r3.Rt.num;
	OP_CSR:
		fnRt = ir.ins.csr.Rt.num;
	OP_ADDI,OP_SUBFI,OP_CMPI,OP_CMPUI,
	OP_ANDI,OP_ORI,OP_EORI,
	OP_MULI,OP_MULUI,OP_DIVI,OP_DIVUI,
	OP_SEQI,OP_SNEI,OP_SLTI,OP_SLEI,OP_SGTI,OP_SGEI,OP_SLTUI,OP_SLEUI,OP_SGTUI,OP_SGEUI,
	OP_ADD2UI,OP_ADD4UI,OP_ADD8UI,OP_ADD16UI,
	OP_SHIFTB,OP_SHIFTW,OP_SHIFTT,OP_SHIFTO,
	OP_ZSEQI,OP_ZSNEI,OP_ZSLTI,OP_ZSLEI,OP_ZSGTI,OP_ZSGEI,OP_ZSLTUI,OP_ZSLEUI,OP_ZSGTUI,OP_ZSGEUI:
		fnRt = ir.ins.ri.Rt.num;
	OP_JSR,OP_CJSR:
		fnRt = ir.ins.jsr.Rt.num;
	OP_JSRI,OP_JSRR,OP_CJSRI,OP_CJSRR:
		fnRt = ir.ins.jsr.Rt.num;
	OP_Bcc,OP_BccU,OP_FBcc,OP_DFBcc,OP_PBcc,
	OP_BccR,OP_BccUR,OP_FBccR,OP_DFBccR,OP_PBccR:
		fnRt = 6'd0;
	OP_IBcc,OP_DBcc,OP_IBccR,OP_DBccR:
		fnRt = ir.ins.br.Ra.num;
	OP_LDxU,OP_LDx,OP_FLDx,OP_DFLDx,OP_PLDx,OP_LDCAPx,OP_CACHE,OP_LDA,OP_AMO,OP_CAS:
		fnRt = ir.ins.ls.Rt.num;
	OP_STx,OP_STIx,OP_FSTx,OP_DFSTx,OP_PSTx,OP_STCAPx,OP_STPTR:
		fnRt = 6'd0;
	OP_ENTER,OP_LEAVE,OP_PUSH,OP_POP:
		fnRt = 6'd0;
/*
	OP_R2:
		case(ir.ins.r2.func)
		FN_ADD:	fnRt = ir.aRt;
		FN_CMP:	fnRt = ir.aRt;
		FN_MUL:	fnRt = ir.aRt;
		FN_DIV:	fnRt = ir.aRt;
		FN_SUB:	fnRt = ir.aRt;
		FN_MULU: fnRt = ir.aRt;
		FN_DIVU:	fnRt = ir.aRt;
		FN_MULW:	fnRt = ir.aRt;
		FN_MOD:	fnRt = ir.aRt;
		FN_MULUW:	fnRt = ir.aRt;
		FN_MODU:	fnRt = ir.aRt;
		FN_AND:	fnRt = ir.aRt;
		FN_OR:	fnRt = ir.aRt;
		FN_EOR:	fnRt = ir.aRt;
		FN_NAND:	fnRt = ir.aRt;
		FN_NOR:	fnRt = ir.aRt;
		FN_ENOR:	fnRt = ir.aRt;
		FN_SEQ:	fnRt = ir.aRt;
		FN_SNE:	fnRt = ir.aRt;
		FN_SLT:	fnRt = ir.aRt;
		FN_SLE:	fnRt = ir.aRt;
		FN_SLTU:	fnRt = ir.aRt;
		FN_SLEU:	fnRt = ir.aRt;
		FN_ZSEQ:	fnRt = ir.aRt;
		FN_ZSNE:	fnRt = ir.aRt;
		FN_ZSLT:	fnRt = ir.aRt;
		FN_ZSLE:	fnRt = ir.aRt;
		FN_ZSLTU:	fnRt = ir.aRt;
		FN_ZSLEU:	fnRt = ir.aRt;
		FN_SEQI8:	fnRt = ir.aRt;
		FN_SNEI8:	fnRt = ir.aRt;
		FN_SLTI8:	fnRt = ir.aRt;
		FN_SLEI8:	fnRt = ir.aRt;
		FN_SLTUI8:	fnRt = ir.aRt;
		FN_SLEUI8:	fnRt = ir.aRt;
		FN_ZSEQI8:	fnRt = ir.aRt;
		FN_ZSNEI8:	fnRt = ir.aRt;
		FN_ZSLTI8:	fnRt = ir.aRt;
		FN_ZSLEI8:	fnRt = ir.aRt;
		FN_ZSLTUI8:	fnRt = ir.aRt;
		FN_ZSLEUI8:	fnRt = ir.aRt;
		default:	fnRt = 9'd0;
		endcase
*/
	OP_BSR:	fnRt = ir.ins.bsr.Rt==2'b00 ? 6'd0 : 6'd40 + ir.ins.bsr.Rt;
	default:
		fnRt = 6'd0;
	endcase
end
endfunction

always_comb
begin
	Rt = fnRt(instr);
	if (Rt==6'd31 && !(instr.ins.any.opcode==OP_MOV && instr.ins[63]))
		Rt = 6'd32|om;
	case(instr.ins.any.opcode)
	OP_FLT3H,OP_FLT3S,OP_FLT3D,OP_FLT3Q:
		Rtn = instr.ins.f3.Rt.n;
	OP_R3B,OP_R3W,OP_R3T,OP_R3O,OP_MOV:
		Rtn = instr.ins.r3.Rt.n;
	OP_CSR:
		Rtn = instr.ins.csr.Rt.n;
	OP_ADDI,OP_SUBFI,OP_CMPI,OP_CMPUI,
	OP_ANDI,OP_ORI,OP_EORI,
	OP_MULI,OP_MULUI,OP_DIVI,OP_DIVUI,
	OP_SEQI,OP_SNEI,OP_SLTI,OP_SLEI,OP_SGTI,OP_SGEI,OP_SLTUI,OP_SLEUI,OP_SGTUI,OP_SGEUI,
	OP_ADD2UI,OP_ADD4UI,OP_ADD8UI,OP_ADD16UI,
	OP_SHIFTB,OP_SHIFTW,OP_SHIFTT,OP_SHIFTO,
	OP_ZSEQI,OP_ZSNEI,OP_ZSLTI,OP_ZSLEI,OP_ZSGTI,OP_ZSGEI,OP_ZSLTUI,OP_ZSLEUI,OP_ZSGTUI,OP_ZSGEUI:
		Rtn = instr.ins.ri.Rt.n;
	OP_JSR,OP_JSRI,OP_JSRR,OP_CJSR,OP_CJSRI,OP_CJSRR:
		Rtn = 1'b0;
	OP_Bcc,OP_BccU,OP_FBcc,OP_DFBcc,OP_PBcc,OP_IBcc,OP_DBcc,
	OP_BccR,OP_BccUR,OP_FBccR,OP_DFBccR,OP_PBccR,OP_IBccR,OP_DBccR:
		Rtn = 1'b0;
	OP_LDxU,OP_LDx,OP_FLDx,OP_DFLDx,OP_PLDx,OP_LDCAPx,OP_CACHE,OP_LDA,OP_AMO,OP_CAS,
	OP_STx,OP_STIx,OP_FSTx,OP_DFSTx,OP_PSTx,OP_STCAPx,OP_STPTR:
		Rtn = 1'b0;
	OP_BSR:
		Rtn = 1'b0;
	default:	Rtn = 1'b0;
	endcase
	Rtz = Rt==6'd0;
end

endmodule
