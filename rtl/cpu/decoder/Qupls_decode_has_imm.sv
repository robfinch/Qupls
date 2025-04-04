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

module Qupls_decode_has_imm(instr, has_imm);
input instruction_t instr;
output has_imm;

function fnIsImm;
input instruction_t op;
begin
	fnIsImm = 1'b0;
	case(op.any.opcode)
	OP_ADDI,OP_CMPI,OP_MULI,OP_DIVI,OP_SUBFI,OP_DIVUI,OP_MULUI,
	OP_ANDI,OP_ORI,OP_EORI:
		fnIsImm = 1'b1;
	OP_SEQI,OP_SNEI,OP_SLTI,OP_SLEI,OP_SGTI,OP_SGEI,OP_SLTUI,OP_SLEUI,OP_SGTUI,OP_SGEUI,
	OP_ZSEQI,OP_ZSNEI,OP_ZSLTI,OP_ZSLEI,OP_ZSGTI,OP_ZSGEI,OP_ZSLTUI,OP_ZSLEUI,OP_ZSGTUI,OP_ZSGEUI:
		fnIsImm = 1'b1;
	OP_RTD,OP_JSR:
		fnIsImm = 1'b1;
	OP_LDx,OP_FLDx,OP_DFLDx,OP_PLDx,OP_LDxU,OP_CACHE,
	OP_STx,OP_FSTx,OP_DFSTx,OP_PSTx:
		fnIsImm = 1'b1;
	default:
		fnIsImm = 1'b0;	
	endcase
end
endfunction

assign has_imm = fnIsImm(instr);

endmodule
