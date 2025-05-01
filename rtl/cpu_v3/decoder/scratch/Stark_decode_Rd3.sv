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
import Stark_pkg::*;

module Stark_decode_Rd3(om, instr, Rd3, Rd3z, exc);
input Stark_pkg::operating_mode_t om;
input Stark_pkg::ex_instruction_t instr;
output aregno_t Rd3;
output reg Rd3z;
output reg exc;

Stark_pkg::operating_mode_t om1;

function aregno_t fnRd3;
input Stark_pkg::ex_instruction_t ir;
begin
	case(ir.ins.any.opcode)
	Stark_pkg::OP_MOV:	fnRd3 = ir.ins[16] ? 8'd56 : 8'd0;
	Stark_pkg::OP_FLT:	fnRd3 = ir.ins[16] ? 8'd57 : 8'd0;
	Stark_pkg::OP_CSR:	fnRd3 = ir.ins[16] ? 8'd56 : 8'd0;
	Stark_pkg::OP_CMP:	fnRd3 = 8'd0;
	Stark_pkg::OP_ADD,Stark_pkg::OP_SUBF,
	Stark_pkg::OP_AND,Stark_pkg::OP_OR,Stark_pkg::OP_XOR,
	Stark_pkg::OP_MUL,Stark_pkg::OP_DIV,
	Stark_pkg::OP_SHIFT:	fnRd3 = ir.ins[16] ? 8'd56 : 8'd0;
	Stark_pkg::OP_B0,Stark_pkg::OP_B1,Stark_pkg::OP_BCC0,Stark_pkg::OP_BCC1:
		fnRd3 = 8'd0;
	Stark_pkg::OP_LDB,Stark_pkg::OP_LDBZ,Stark_pkg::OP_LDW,Stark_pkg::OP_LDWZ,
	Stark_pkg::OP_LDT,Stark_pkg::OP_LDTZ,Stark_pkg::OP_LOAD,Stark_pkg::OP_LOADA,
	Stark_pkg::OP_AMO,Stark_pkg::OP_CMPSWAP:
		fnRd3 = ir.ins[16] ? 8'd56 : 8'd0;
	default:
		fnRd3 = 8'd0;
	endcase
end
endfunction

always_comb
begin
	Rd3 = fnRd3(instr);
	if (instr.ins.any.opcode==OP_MOV && instr.ins[28:26]==3'd1)	// MOVEMD / XCHGMD?
		om1 = Stark_pkg::operating_mode_t'(instr.ins[22:21]);
	else
	  om1 = om;
	Rd3z = ~|Rd3;
	tRegmap(om1, Rd3, Rd3, exc);
end

endmodule
