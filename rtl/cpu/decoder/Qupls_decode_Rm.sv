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

module Qupls_decode_Rm(instr, Rm);
input ex_instruction_t instr;
output cpu_types_pkg::aregno_t Rm;

always_comb
begin
	Rm = 8'd48;
	case(instr.ins.any.opcode)
	OP_ADDI,OP_CMPI,OP_MULI,OP_DIVI,OP_SUBFI,
	OP_ANDI,
	OP_ORI,OP_EORI,OP_MULUI,OP_DIVUI:
		begin
			Rm = 8'd48 | instr.ins.imm.Pr;
		end
	OP_SHIFTB,OP_SHIFTW,OP_SHIFTT,OP_SHIFTO:
		begin
			Rm = 8'd48 | instr.ins.shifti.Pr;
		end
	OP_R3B,OP_R3W,OP_R3T,OP_R3O:
		begin
			Rm = 8'd48 | instr.ins.r2.Pr;
		end
	OP_LDx,OP_LDxU,OP_FLDx,OP_DFLDx,OP_PLDx,OP_CACHE,
	OP_STx,OP_FSTx,OP_DFSTx,OP_PSTx:
		Rm = 8'd48 | instr.ins.lsn.Pr;
	OP_FLT3:
		Rm = 8'd48 | instr.ins.f3.Pr;
	OP_MCB:	Rm = 8'd48;
	OP_BSR:	Rm = 8'd48 | instr.ins.bsr.Pr;
	OP_JSR:	Rm = 8'd48 | instr.ins.jsr.Pr;
	OP_RTD:	Rm = 8'd48 | instr.ins.rtd.Pr;
	OP_AIPUI:
		Rm = 8'd48 | instr.ins.ris.Pr;
	OP_CSR:	Rm = 8'd48 | instr.ins.csr.Pr;
	OP_MOV:	Rm = 8'd48 | instr.ins.r2.Pr;
	OP_Bcc,OP_BccU:	Rm = 8'd48 | instr.ins.br.Pr;
	default:
		Rm = 8'd48;
	endcase
end

endmodule

