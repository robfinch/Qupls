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

module Qupls_decode_fc(instr, fc);
input instruction_t instr;
output fc;

function fnIsFlowCtrl;
input instruction_t ir;
begin
	fnIsFlowCtrl = 1'b0;
	case(ir.any.opcode)
	OP_R3B,OP_R3W,OP_R3T,OP_R3O:
		case(ir.r3.func)
		FN_R1:
			case(ir.r3.Rb)
			OP_REX:	fnIsFlowCtrl = 1'b1;
			default:
				fnIsFlowCtrl = 1'b0;
			endcase
		default:
			fnIsFlowCtrl = 1'b0;
		endcase
	OP_CHK:	fnIsFlowCtrl = 1'b1;
	OP_JSR,OP_JSRI:
		fnIsFlowCtrl = 1'b1;
	OP_Bcc,OP_BccU,OP_FBcc,OP_DFBcc,OP_PBcc,OP_IBcc,OP_DBcc,
	OP_BccR,OP_BccUR,OP_FBccR,OP_DFBccR,OP_PBccR,OP_IBccR,OP_DBccR:
		fnIsFlowCtrl = 1'b1;	
	OP_BSR,OP_RTD:
		fnIsFlowCtrl = 1'b1;	
	default:
		fnIsFlowCtrl = 1'b0;
	endcase
end
endfunction

assign fc = fnIsFlowCtrl(instr);

endmodule
