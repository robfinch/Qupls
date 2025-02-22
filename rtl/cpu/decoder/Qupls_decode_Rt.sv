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
	OP_FLT3:
		fnRt = ir.aRt;
	OP_MCB:	fnRt = {ir.ins.mcb.lk ? 9'd59 : 9'd00};
	OP_BSR:	fnRt = ir.aRt;
	OP_JSR:	fnRt = ir.aRt;
	OP_RTD:	fnRt = 9'd31;
	OP_DBRA: fnRt = 9'd55;
	OP_ADDI,OP_SUBFI,OP_CMPI:
		fnRt = ir.aRt;
	OP_MULI,OP_DIVI:
		fnRt = ir.aRt;
	OP_MULUI,OP_DIVUI,OP_ANDI,OP_ORI,OP_EORI:
		fnRt = ir.aRt;
	OP_ADDSI,OP_ANDSI,OP_ORSI,OP_EORSI,OP_AIPSI:
		fnRt = ir.aRt;
	OP_SHIFT:
		fnRt = ir.aRt;
	OP_CSR:
		fnRt = ir.aRt;
	OP_MOV:
		fnRt = ir.aRt;
	OP_Bcc,OP_BccU:
		fnRt = |ir.ins.br.inc ? ir.aRa : 8'd0;
	OP_LDA,
	OP_LDB,OP_LDBU,OP_LDW,OP_LDWU,OP_LDT,OP_LDTU,OP_LDO,OP_LDOU,OP_LDH:
		fnRt = ir.aRt;
	default:
		fnRt = 9'd0;
	endcase
end
endfunction

always_comb
begin
	Rt = fnRt(instr);
	if (Rt==8'd31 && !(instr.ins.any.opcode==OP_MOV && instr.ins[63]))
		Rt = 8'd32|om;
	if (instr.ins.any.opcode==OP_BSR)
		Rtn = 1'b0;
	else
		Rtn = instr.ins.r3.Rt.n;
	Rtz = Rt==8'd0;
end

endmodule

