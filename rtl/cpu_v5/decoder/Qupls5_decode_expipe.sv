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

module Qupls5_decode_expipe(instr, expipe);
input Qupls5_pkg::micro_op_t instr;
output [6:0] expipe;

function [6:0] fnExPipe;
input Qupls5_pkg::micro_op_t ir;
begin
	case(ir.opcode)
	Qupls5_pkg::OP_PPC_ADDI,
	Qupls5_pkg::OP_PPC_ADDIS,
	Qupls5_pkg::OP_PPC_SUBFIC,
	Qupls5_pkg::OP_PPC_CMPI,
	Qupls5_pkg::OP_PPC_CMPLI,
	Qupls5_pkg::OP_PPC_ANDI,
	Qupls5_pkg::OP_PPC_ANDIS,
	Qupls5_pkg::OP_PPC_ORI,
	Qupls5_pkg::OP_PPC_ORIS,
	Qupls5_pkg::OP_PPC_XORI,
	Qupls5_pkg::OP_PPC_XORIS,
	Qupls5_pkg::OP_31:
		fnExPipe = 7'b0111111;
	Qupls5_pkg::OP_PPC_RLWINM,
	Qupls5_pkg::OP_PPC_RLWNM,
	Qupls5_pkg::OP_PPC_RLWIMI,
	Qupls5_pkg::OP_PPC_RLDIC:
		fnExPipe = 7'b0000011;
	Qupls5_pkg::OP_PPC_LBZ,Qupls5_pkg::OP_PPC_LWZ,Qupls5_pkg::OP_PPC_LWA,
	Qupls5_pkg::OP_PPC_LHZ,Qupls5_pkg::OP_PPC_LHA,Qupls5_pkg::OP_PPC_LHZU,
	Qupls5_pkg::OP_PPC_LBZU,Qupls5_pkg::OP_PPC_LWZU,
	Qupls5_pkg::OP_PPC_STB,Qupls5_pkg::OP_PPC_STH,Qupls5_pkg::OP_PPC_STW,Qupls5_pkg::OP_PPC_STD,
	Qupls5_pkg::OP_PPC_STBU,Qupls5_pkg::OP_PPC_STHU,Qupls5_pkg::OP_PPC_STWU:
		fnExPipe = 7'b0110000;
	// Branches must be supported on at least one pipe.
	Qupls5_pkg::OP_B,Qupls5_pkg::OP_19:
		fnExPipe = 7'b0000011;
	default:
		fnExPipe = 7'b0000000;
	endcase
end
endfunction

assign expipe = fnExPipe(instr);

endmodule
