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

module Stark_decode_Rs3(om, instr, has_immc, Rs3, Rs3z, exc);
input Stark_pkg::operating_mode_t om;
input Stark_pkg::micro_op_t instr;
input has_immc;
output aregno_t Rs3;
output reg Rs3z;
output reg exc;

function aregno_t fnRs3;
input Stark_pkg::micro_op_t instr;
input has_immc;
Stark_pkg::instruction_t ir;
begin
	ir = instr.ins;
	if (has_immc)
		fnRs3 = 7'd0;
	else
		case(ir.any.opcode)
		Stark_pkg::OP_STB,Stark_pkg::OP_STBI,Stark_pkg::OP_STW,Stark_pkg::OP_STWI,
		Stark_pkg::OP_STT,Stark_pkg::OP_STTI,Stark_pkg::OP_STORE,Stark_pkg::OP_STOREI,
		Stark_pkg::OP_STPTR:
			fnRs3 = {2'b00,ir.lsscn.Rsd};
		default:
			fnRs3 = 7'd0;
		endcase
end
endfunction

always_comb
begin
	Rs3 = fnRs3(instr, has_immc);
	Rs3z = ~|Rs3;
	tRegmap(om, Rs3, Rs3, exc);
end

endmodule
