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

module Qupls_decode_alu(instr, alu);
input instruction_t instr;
output alu;

function fnIsAlu;
input instruction_t ir;
begin
	case(ir.r2.opcode)
	OP_FLT3:
		case(ir.f3.opcode)
		FN_FCMP:	fnIsAlu = 1'b1;
		FN_FLT1:
			case(ir.f1.func)
			FN_FABS:	fnIsAlu = 1'b1;
			FN_FNEG:	fnIsAlu = 1'b1;
			default:	fnIsAlu = 1'b0;
			endcase
		default:	fnIsAlu = 1'b0;
		endcase
	OP_CAP:	fnIsAlu = 1'b1;
	OP_CHK:	fnIsAlu = 1'b1;
	OP_R3B,OP_R3W,OP_R3T,OP_R3O:
		case(ir.r3.func)
		FN_CPUID:	fnIsAlu = 1'b1;
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
		FN_MINMAX:	fnIsAlu = 1'b1;
		FN_BYTENDX:	fnIsAlu = 1'b1;
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
		FN_SEQI8:	fnIsAlu = 1'b1;
		FN_SNEI8:	fnIsAlu = 1'b1;
		FN_SLTI8:	fnIsAlu = 1'b1;
		FN_SLEI8:	fnIsAlu = 1'b1;
		FN_SLTUI8:	fnIsAlu = 1'b1;
		FN_SLEUI8:	fnIsAlu = 1'b1;
		FN_ZSEQI8:	fnIsAlu = 1'b1;
		FN_ZSNEI8:	fnIsAlu = 1'b1;
		FN_ZSLTI8:	fnIsAlu = 1'b1;
		FN_ZSLEI8:	fnIsAlu = 1'b1;
		FN_ZSLTUI8:	fnIsAlu = 1'b1;
		FN_ZSLEUI8:	fnIsAlu = 1'b1;
		FN_MVVR: 	fnIsAlu = 1'b1;
		FN_VSETMASK: fnIsAlu = 1'b1;
		default:	fnIsAlu = 1'b0;
		endcase
	OP_ADDI:	
		fnIsAlu = 1'b1;
	OP_SUBFI:	fnIsAlu = 1'b1;
	OP_CMPI:	
		fnIsAlu = 1'b1;
	OP_MULI:	
		fnIsAlu = 1'b1;
	OP_MULUI:
		fnIsAlu = 1'b1;
	OP_DIVI:	
		fnIsAlu = 1'b1;
	OP_ANDI:	
		fnIsAlu = 1'b1;
	OP_ORI:
		fnIsAlu = 1'b1;
	OP_EORI:
		fnIsAlu = 1'b1;
	OP_AIPUI:	fnIsAlu = 1'b1;
	OP_SHIFTB,OP_SHIFTW,OP_SHIFTT,OP_SHIFTO:
		fnIsAlu = 1'b1;
	OP_SEQI:	fnIsAlu = 1'b1;
	OP_SNEI:	fnIsAlu = 1'b1;
	OP_SLTI:	fnIsAlu = 1'b1;
	OP_SLEI:	fnIsAlu = 1'b1;
	OP_SGTI:	fnIsAlu = 1'b1;
	OP_SGEI:	fnIsAlu = 1'b1;
	OP_SLTUI:	fnIsAlu = 1'b1;
	OP_SLEUI:	fnIsAlu = 1'b1;
	OP_SGTUI:	fnIsAlu = 1'b1;
	OP_SGEUI:	fnIsAlu = 1'b1;
	OP_ZSEQI:	fnIsAlu = 1'b1;
	OP_ZSNEI:	fnIsAlu = 1'b1;
	OP_ZSLTI:	fnIsAlu = 1'b1;
	OP_ZSLEI:	fnIsAlu = 1'b1;
	OP_ZSGTI:	fnIsAlu = 1'b1;
	OP_ZSGEI:	fnIsAlu = 1'b1;
	OP_ZSLTUI:	fnIsAlu = 1'b1;
	OP_ZSLEUI:	fnIsAlu = 1'b1;
	OP_ZSGTUI:	fnIsAlu = 1'b1;
	OP_ZSGEUI:	fnIsAlu = 1'b1;
	OP_CSR:		fnIsAlu = 1'b1;
	OP_MOV:		fnIsAlu = 1'b1;
	OP_LDA:	fnIsAlu = 1'b1;
	OP_QFEXT,OP_PFX,
	OP_NOP,OP_PUSH,OP_POP,OP_ENTER,OP_LEAVE,OP_ATOM:
		fnIsAlu = 1'b1;
	OP_FENCE:
		fnIsAlu = 1'b1;
	OP_BSR,OP_JSR:
		fnIsAlu = 1'b1;
	OP_RTD:
		fnIsAlu = 1'b1;
	OP_IBcc,OP_DBcc:
		fnIsAlu = 1'b1;
	OP_PRED:
		fnIsAlu = 1'b1;
	default:	fnIsAlu = 1'b0;
	endcase
end
endfunction

assign alu = fnIsAlu(instr);

endmodule
