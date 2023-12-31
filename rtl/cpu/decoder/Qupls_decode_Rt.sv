// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2023  Robert Finch, Waterloo
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

module Qupls_decode_Rt(instr, regx, Rt);
input instruction_t instr;
input regx;
output aregno_t Rt;

function aregno_t fnRt;
input instruction_t ir;
begin
	case(ir.any.opcode)
	OP_R2:
		case(ir.r2.func)
		FN_ADD:	fnRt = {regx,ir.r2.Rt};
		FN_CMP:	fnRt = {regx,ir.r2.Rt};
		FN_MUL:	fnRt = {regx,ir.r2.Rt};
		FN_DIV:	fnRt = {regx,ir.r2.Rt};
		FN_SUB:	fnRt = {regx,ir.r2.Rt};
		FN_MULU: fnRt = {regx,ir.r2.Rt};
		FN_DIVU:	fnRt = {regx,ir.r2.Rt};
		FN_MULH:	fnRt = {regx,ir.r2.Rt};
		FN_MOD:	fnRt = {regx,ir.r2.Rt};
		FN_MULUH:	fnRt = {regx,ir.r2.Rt};
		FN_MODU:	fnRt = {regx,ir.r2.Rt};
		FN_AND:	fnRt = {regx,ir.r2.Rt};
		FN_OR:	fnRt = {regx,ir.r2.Rt};
		FN_EOR:	fnRt = {regx,ir.r2.Rt};
		FN_ANDC:	fnRt = {regx,ir.r2.Rt};
		FN_NAND:	fnRt = {regx,ir.r2.Rt};
		FN_NOR:	fnRt = {regx,ir.r2.Rt};
		FN_ENOR:	fnRt = {regx,ir.r2.Rt};
		FN_ORC:	fnRt = {regx,ir.r2.Rt};
		FN_SEQ:	fnRt = {regx,ir.r2.Rt};
		FN_SNE:	fnRt = {regx,ir.r2.Rt};
		FN_SLT:	fnRt = {regx,ir.r2.Rt};
		FN_SLE:	fnRt = {regx,ir.r2.Rt};
		FN_SLTU:	fnRt = {regx,ir.r2.Rt};
		FN_SLEU:	fnRt = {regx,ir.r2.Rt};
		default:	fnRt = 7'd0;
		endcase
	OP_FLT2,OP_FLT3:
		fnRt = {regx,1'b0,ir[11:7]};
	OP_MCB:	fnRt = {ir.mcb.lk ? 7'd59 : 7'd00};
	OP_BSR:	fnRt = {regx,ir.bsr.Rt};
	OP_JSR:	fnRt = {regx,ir.jsr.Rt};
	OP_RTD:	fnRt = 7'd63;
	OP_DBRA: fnRt = 7'd55;
	OP_ADDI,OP_SUBFI,OP_CMPI:
		fnRt = {regx,ir.ri.Rt};
	OP_MULI,OP_DIVI:
		fnRt = {regx,ir.ri.Rt};
	OP_SLTI,OP_MULUI,OP_DIVUI,OP_ANDI,OP_ORI,OP_EORI:
		fnRt = {regx,ir.ri.Rt};
	OP_ADDSI,OP_ANDSI,OP_ORSI,OP_EORSI:
		fnRt = {regx,ir.ri.Rt};
	OP_SHIFT:
		fnRt = {regx,ir.r2.Rt};
	OP_CSR:
		fnRt = {regx,ir.csr.Rt};
	OP_MOV:
		fnRt = {regx,ir.r2.Rt};
	OP_LDB,OP_LDBU,OP_LDW,OP_LDWU,OP_LDT,OP_LDTU,OP_LDO,OP_LDOU,OP_LDH,
	OP_LDX:
		fnRt = {regx,ir.ls.Rt};
	default:
		fnRt = 7'd0;
	endcase
end
endfunction

assign Rt = fnRt(instr);

endmodule

