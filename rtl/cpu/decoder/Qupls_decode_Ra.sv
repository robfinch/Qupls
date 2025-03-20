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

module Qupls_decode_Ra(om, ipl, instr, has_imma, Ra, Raz, Ran);
input operating_mode_t om;
input [2:0] ipl;
input ex_instruction_t instr;
input has_imma;
output aregno_t Ra;
output reg Raz;
output reg Ran;

function aregno_t fnRa;
input ex_instruction_t ir;
input has_imma;
begin
	if (has_imma)
		fnRa = 6'd0;
	else
		case(ir.ins.any.opcode)
		OP_RTD:
			fnRa = ir.ins.rtd.Ra;
		OP_FLT3H,OP_FLT3S,OP_FLT3D,OP_FLT3Q:
			fnRa = ir.ins.f3.Ra.num;
		OP_R3B,OP_R3W,OP_R3T,OP_R3O,OP_MOV:
			fnRa = ir.ins.r3.Ra.num;
		OP_CSR:
			fnRa = ir.ins.csr.Ra.num;
		OP_ADDI,OP_SUBFI,OP_CMPI,OP_CMPUI,
		OP_ANDI,OP_ORI,OP_EORI,
		OP_MULI,OP_MULUI,OP_DIVI,OP_DIVUI,
		OP_SEQI,OP_SNEI,OP_SLTI,OP_SLEI,OP_SGTI,OP_SGEI,OP_SLTUI,OP_SLEUI,OP_SGTUI,OP_SGEUI,
		OP_ADD2UI,OP_ADD4UI,OP_ADD8UI,OP_ADD16UI,
		OP_SHIFTB,OP_SHIFTW,OP_SHIFTT,OP_SHIFTO,
		OP_ZSEQI,OP_ZSNEI,OP_ZSLTI,OP_ZSLEI,OP_ZSGTI,OP_ZSGEI,OP_ZSLTUI,OP_ZSLEUI,OP_ZSGTUI,OP_ZSGEUI:
			fnRa = ir.ins.ri.Ra.num;
		OP_JSR,OP_CJSR:
			fnRa = 6'd0;
		OP_JSRI,OP_JSRR,OP_CJSRI,OP_CJSRR:
			fnRa = ir.ins.jsr.Ra.num;
		OP_Bcc,OP_BccU,OP_FBcc,OP_DFBcc,OP_PBcc,OP_IBcc,OP_DBcc,
    	OP_BccR,OP_BccUR,OP_FBccR,OP_DFBccR,OP_PBccR,OP_IBccR,OP_DBccR:
			fnRa = ir.ins.br.Ra.num;
		OP_LDxU,OP_LDx,OP_FLDx,OP_DFLDx,OP_PLDx,OP_LDCAPx,OP_CACHE,OP_LDA,OP_AMO,OP_CAS,
		OP_STx,OP_STIx,OP_FSTx,OP_DFSTx,OP_PSTx,OP_STCAPx,OP_STPTR:
			fnRa = ir.ins.ls.Ra.num;
		OP_ENTER,OP_LEAVE,OP_PUSH,OP_POP:
			fnRa = 6'd0;
		default:
			fnRa = 6'd0;
		endcase
end
endfunction

always_comb
begin
	Ra = fnRa(instr, has_imma);
	if (Ra==6'd31 && !(instr.ins.any.opcode==OP_MOV && instr.ins[23]))
		Ra = 6'd32|om;
	case(instr.ins.any.opcode)
	OP_FLT3H,OP_FLT3S,OP_FLT3D,OP_FLT3Q:
		Ran = instr.ins.f3.Ra.n;
	OP_R3B,OP_R3W,OP_R3T,OP_R3O,OP_MOV:
		Ran = instr.ins.r3.Ra.n;
	OP_CSR:
		Ran = instr.ins.csr.Ra.n;
	OP_ADDI,OP_SUBFI,OP_CMPI,OP_CMPUI,
	OP_ANDI,OP_ORI,OP_EORI,
	OP_MULI,OP_MULUI,OP_DIVI,OP_DIVUI,
	OP_SEQI,OP_SNEI,OP_SLTI,OP_SLEI,OP_SGTI,OP_SGEI,OP_SLTUI,OP_SLEUI,OP_SGTUI,OP_SGEUI,
	OP_ADD2UI,OP_ADD4UI,OP_ADD8UI,OP_ADD16UI,
	OP_SHIFTB,OP_SHIFTW,OP_SHIFTT,OP_SHIFTO,
	OP_ZSEQI,OP_ZSNEI,OP_ZSLTI,OP_ZSLEI,OP_ZSGTI,OP_ZSGEI,OP_ZSLTUI,OP_ZSLEUI,OP_ZSGTUI,OP_ZSGEUI:
		Ran = instr.ins.ri.Ra.n;
	OP_JSR,OP_JSRI,OP_JSRR,OP_CJSR,OP_CJSRI,OP_CJSRR:
		Ran = 1'b0;
	OP_Bcc,OP_BccU,OP_FBcc,OP_DFBcc,OP_PBcc,OP_IBcc,OP_DBcc,
	OP_BccR,OP_BccUR,OP_FBccR,OP_DFBccR,OP_PBccR,OP_IBccR,OP_DBccR:
		Ran = 1'b0;
	OP_LDxU,OP_LDx,OP_FLDx,OP_DFLDx,OP_PLDx,OP_LDCAPx,OP_CACHE,OP_LDA,OP_AMO,OP_CAS,
	OP_STx,OP_STIx,OP_FSTx,OP_DFSTx,OP_PSTx,OP_STCAPx,OP_STPTR:
		Ran = 1'b0;
	default:	Ran = 1'b0;
	endcase
	Raz = ~|Ra;
end

endmodule
