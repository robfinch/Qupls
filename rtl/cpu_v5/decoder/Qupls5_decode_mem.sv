// ============================================================================
//        __
//   \\__/ o\    (C) 2026  Robert Finch, Waterloo
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

import Qupls5_pkg::*;

module Qupls5_decode_mem(instr, mem);
input Qupls5_pkg::micro_op_t instr;
output mem;

function fnIsMem;
input Qupls5_pkg::micro_op_t op;
begin
	case(op.opcode)
	Qupls5_pkg::OP_LDB,Qupls5_pkg::OP_LDBZ,Qupls5_pkg::OP_LDW,Qupls5_pkg::OP_LDWZ,
	Qupls5_pkg::OP_LDT,Qupls5_pkg::OP_LDTZ,Qupls5_pkg::OP_LOAD,Qupls5_pkg::OP_CLOAD,
	Qupls5_pkg::OP_FLDS,Qupls5_pkg::OP_FLDD,
	Qupls5_pkg::OP_LDV,Qupls5_pkg::OP_LDVN,
	Qupls5_pkg::OP_STB,Qupls5_pkg::OP_STW,Qupls5_pkg::OP_STT,Qupls5_pkg::OP_STORE,
	Qupls5_pkg::OP_STV,Qupls5_pkg::OP_STVN,Qupls5_pkg::OP_CSTORE,
	Qupls5_pkg::OP_STPTR,Qupls5_pkg::OP_V2P,Qupls5_pkg::OP_VV2P:
		fnIsMem = 1'b1;
	default:
		fnIsMem = 1'b0;
	endcase
end
endfunction

assign mem = fnIsMem(instr);

endmodule
