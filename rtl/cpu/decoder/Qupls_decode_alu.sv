// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2024  Robert Finch, Waterloo
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

module Qupls_decode_alu(instr, alu);
input instruction_t instr;
output alu;

function fnIsAlu;
input instruction_t ir;
begin
	case(ir.r2.opcode)
	OP_SYS:	fnIsAlu = 1'b0;
	OP_R2:
		case(ir.r2.func)
		FN_ADD:	fnIsAlu = 1'b1;
		FN_CMP:	fnIsAlu = 1'b1;
		FN_MUL:	fnIsAlu = 1'b1;
		FN_MULW:	fnIsAlu = 1'b1;
		FN_DIV:	fnIsAlu = 1'b1;
		FN_SUB:	fnIsAlu = 1'b1;
		FN_MULU: fnIsAlu = 1'b1;
		FN_MULUW: fnIsAlu = 1'b1;
		FN_DIVU: fnIsAlu = 1'b1;
		FN_AND:	fnIsAlu = 1'b1;
		FN_OR:	fnIsAlu = 1'b1;
		FN_EOR:	fnIsAlu = 1'b1;
		FN_NAND:	fnIsAlu = 1'b1;
		FN_NOR:	fnIsAlu = 1'b1;
		FN_ENOR:	fnIsAlu = 1'b1;
		FN_SEQ:	fnIsAlu = 1'b1;
		FN_SNE:	fnIsAlu = 1'b1;
		FN_SLT:	fnIsAlu = 1'b1;
		FN_SLE:	fnIsAlu = 1'b1;
		FN_SLTU:	fnIsAlu = 1'b1;
		FN_SLEU:	fnIsAlu = 1'b1;
		FN_ZSEQ:	fnIsAlu = 1'b1;
		FN_ZSNE:	fnIsAlu = 1'b1;
		FN_ZSLT:	fnIsAlu = 1'b1;
		FN_ZSLE:	fnIsAlu = 1'b1;
		FN_ZSLTU:	fnIsAlu = 1'b1;
		FN_ZSLEU:	fnIsAlu = 1'b1;
		default:	fnIsAlu = 1'b0;
		endcase
	OP_ADDI,OP_VADDI:	
		fnIsAlu = 1'b1;
	OP_SUBFI:	fnIsAlu = 1'b1;
	OP_CMPI,OP_VCMPI:	
		fnIsAlu = 1'b1;
	OP_MULI,OP_VMULI:	
		fnIsAlu = 1'b1;
	OP_DIVI,OP_VDIVI:	
		fnIsAlu = 1'b1;
	OP_ANDI,OP_VANDI:	
		fnIsAlu = 1'b1;
	OP_ORI,OP_VORI:
		fnIsAlu = 1'b1;
	OP_EORI,OP_VEORI:
		fnIsAlu = 1'b1;
	OP_SLTI:	fnIsAlu = 1'b1;
	OP_AIPSI:	fnIsAlu = 1'b1;
	OP_VADDSI,OP_VORSI,OP_VANDSI,OP_VEORSI,
	OP_ADDSI,OP_ORSI,OP_ANDSI,OP_EORSI:
						fnIsAlu = 1'b1;
	OP_SHIFT:	fnIsAlu = 1'b1;
	OP_CSR:		fnIsAlu = 1'b1;
	OP_MOV:		fnIsAlu = 1'b1;
	OP_LDAX:	fnIsAlu = 1'b1;
	OP_PFXA32,OP_PFXB32,OP_PFXC32,
	OP_QFEXT,
	OP_REGC,
	OP_VEC,OP_VECZ,
	OP_NOP,OP_PUSH,OP_POP,OP_ENTER,OP_LEAVE,OP_ATOM:
		fnIsAlu = 1'b1;
	OP_FENCE:
		fnIsAlu = 1'b1;
	OP_BSR,OP_JSR:
		fnIsAlu = 1'b1;
	default:	fnIsAlu = 1'b0;
	endcase
end
endfunction

assign alu = fnIsAlu(instr);

endmodule
