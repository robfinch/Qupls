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
// ============================================================================

import const_pkg::*;
import Qupls5_pkg::*;

module Qupls5_ext_decode(ip, instr, bsr, jsr, bra, jmp, bcc, bcc_reg, rtd, nop,
	bsr_tgt, jsr_tgt, bcc_tgt);
input Qupls5_pkg::pc_address_ex_t ip;
input [31:0] instr;
output reg bsr;
output reg jsr;
output reg bra;
output reg jmp;
output reg bcc;
output reg bcc_reg;
output reg rtd;
output reg nop;
output Qupls5_pkg::pc_address_ex_t bsr_tgt;
output Qupls5_pkg::pc_address_ex_t jsr_tgt;
output Qupls5_pkg::pc_address_ex_t bcc_tgt;

always_comb nop = instr[31:26]==Qupls5_pkg::OP_PPC_ORI && instr[25:0]==26'd0;
always_comb bsr = instr[31:26]==Qupls5_pkg::OP_PPC_B && !instr[1] && instr[0];
always_comb bra = instr[31:26]==Qupls5_pkg::OP_PPC_B && !instr[1] && !instr[0];
always_comb jsr = instr[31:26]==Qupls5_pkg::OP_PPC_B && instr[1] && instr[0];
always_comb jmp = instr[31:26]==Qupls5_pkg::OP_PPC_B && instr[1] && !instr[0];

// For conditional branches we have to detect if it is a branch-to-register
// value. If so, the address cannot be predicted at this stage. It will
// need to wait until it resolves.
always_comb bcc = instr[31:26]==Qupls5_pkg::OP_PPC_BC;
always_comb bcc_reg = instr[31:26]==Qupls5_pkg::OP_19;
always_comb rtd = instr[6:0]==Qupls5_pkg::OP_CAP && instr[31:25]==Qupls5_pkg::CAP_RET;
// To compute the virtual address the offset is added to the base, so it needs
// to be subtracted off when set.
always_comb begin bsr_tgt = ip; bsr_tgt.cap.offset = ip.cap.offset + {{38{instr[25]}},instr[25:2],2'b0}; end
always_comb begin jsr_tgt = ip; jsr_tgt.cap.offset = {{38{instr[25]}},instr[25:2],2'b0} - ip.cap.base; end
always_comb begin bcc_tgt = ip; bcc_tgt.cap.offset = ip.cap.offset + {{48{instr[15]}},instr[15:2],2'b0}; end

endmodule
