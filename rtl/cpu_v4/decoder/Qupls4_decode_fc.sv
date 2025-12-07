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

import Qupls4_pkg::*;

module Qupls4_decode_fc(instr, fc);
input Qupls4_pkg::instruction_t instr;
output fc;

function fnIsFlowCtrl;
input Qupls4_pkg::instruction_t ir;
begin
	case(ir.any.opcode)
	Qupls4_pkg::OP_BRK,
	Qupls4_pkg::OP_CHK:	fnIsFlowCtrl = 1'b1;
	Qupls4_pkg::OP_BCC8,Qupls4_pkg::OP_BCC16,Qupls4_pkg::OP_BCC32,Qupls4_pkg::OP_BCC64,
	Qupls4_pkg::OP_BCCU8,Qupls4_pkg::OP_BCCU16,Qupls4_pkg::OP_BCCU32,Qupls4_pkg::OP_BCCU64:
//	Qupls4_pkg::OP_TRAP:
		fnIsFlowCtrl = 1'b1;	
	Qupls4_pkg::OP_BSR,Qupls4_pkg::OP_JSR,
	Qupls4_pkg::OP_JSRN:
		fnIsFlowCtrl = 1'b1;	
	default:
		fnIsFlowCtrl = 1'b0;
	endcase
end
endfunction

assign fc = fnIsFlowCtrl(instr);

endmodule
