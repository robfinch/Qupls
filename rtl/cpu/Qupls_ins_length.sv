// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
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
// 10 LUTs
// ============================================================================

import QuplsPkg::*;

module Qupls_ins_length(op, len);
input opcode_t op;
output reg [4:0] len;					// length in bytes

always_comb
	casez(op)
	OP_BSR:	len = 5'd5;
	OP_JSR:	len = 5'd5;
	OP_BccU:	len = 5'd5;
	OP_Bcc:	len = 5'd5;
	OP_FBccH:	len = 5'd5;
	OP_FBccS:	len = 5'd5;
	OP_FBccD:	len = 5'd5;
	OP_FBccQ:	len = 5'd5;
	OP_CSR:		len = 5'd5;
	OP_FLT2:	len = 5'd5;
	OP_FLT3:	len = 5'd5;
//	OP_PFXA,OP_PFXB,OP_PFXC:
//					len = 5'd5;
	OP_PFXA32:	len = 5'd5;
	OP_PFXB32:	len = 5'd5;
	OP_PFXC32:	len = 5'd5;
	OP_PFXA64:	len = 5'd10;
	OP_PFXB64:	len = 5'd10;
	OP_PFXC64:	len = 5'd10;
	OP_PFXA128:	len = 5'd20;
	OP_PFXB128:	len = 5'd20;
	OP_PFXC128:	len = 5'd20;
	OP_VEC,OP_VECZ,OP_RTS:
					len = 5'd5;
	OP_NOP,OP_LSCTX:
					len = 5'd5;
	default:	len = 5'd5;
	endcase

endmodule
