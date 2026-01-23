// ============================================================================
//        __
//   \\__/ o\    (C) 2025-2026  Robert Finch, Waterloo
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
//
// Decoding that takes place at the extract stage must be simple and fast.
// It is using the output of the instruction aligned which is itself a mux.
// The extract stage does not have micro-ops to work with, it must work with
// raw instruction data. Fortunately all the instructions needing decoding
// map 1:1 with micro-ops. Only jumps and branches are decoded as shown
// below. These instructions are needed to feed the fetch stage.
// Note the sign inversion bit is repurposed to indicate a call or jump.
// Inverting the IP value to store as the return address has no use.
// ============================================================================

import const_pkg::*;
import Qupls4_pkg::*;

module Qupls4_ext_decode(ip, instr, bsr, jsr, bra, jmp, bcc, rtd, nop,
	bsr_tgt, jsr_tgt, bcc_tgt);
input cpu_types_pkg::pc_address_ex_t ip;
input [47:0] instr;
output reg bsr;
output reg jsr;
output reg bra;
output reg jmp;
output reg bcc;
output reg rtd;
output reg nop;
output cpu_types_pkg::pc_address_ex_t bsr_tgt;
output cpu_types_pkg::pc_address_ex_t jsr_tgt;
output cpu_types_pkg::pc_address_ex_t bcc_tgt;

always_comb nop = instr[6:0]==Qupls4_pkg::OP_NOP;
always_comb bsr = instr[6:0]==Qupls4_pkg::OP_BSR && ~&instr[12:7];
always_comb bra = instr[6:0]==Qupls4_pkg::OP_BSR &&  &instr[12:7];
always_comb jsr = instr[6:0]==Qupls4_pkg::OP_JSR && ~&instr[12:7];
always_comb jmp = instr[6:0]==Qupls4_pkg::OP_JSR &&  &instr[12:7];
always_comb
	case(instr[6:0])
	Qupls4_pkg::OP_BCC8,Qupls4_pkg::OP_BCC16,Qupls4_pkg::OP_BCC32,Qupls4_pkg::OP_BCC64,
	Qupls4_pkg::OP_BCCU8,Qupls4_pkg::OP_BCCU16,Qupls4_pkg::OP_BCCU32,Qupls4_pkg::OP_BCCU64,
	Qupls4_pkg::OP_FBCC16,Qupls4_pkg::OP_FBCC32,Qupls4_pkg::OP_FBCC64,Qupls4_pkg::OP_FBCC128:
		bcc = TRUE;
	default:
		bcc = FALSE;
	endcase
always_comb rtd = instr[6:0]==Qupls4_pkg::OP_RTD;
always_comb begin bsr_tgt = ip; bsr_tgt.pc = ip.pc + {{29{instr[47]}},instr[47:13],1'b0}; end
always_comb begin jsr_tgt = ip; jsr_tgt.pc = {{29{instr[47]}},instr[47:13],1'b0}; end
always_comb begin bcc_tgt = ip; bcc_tgt.pc = ip.pc + {{41{instr[46]}},instr[46:25],1'b0}; end

endmodule
