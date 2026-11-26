// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2026  Robert Finch, Waterloo
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

module Qupls5_decode_class(instr, fclass);
input Qupls5_pkg::micro_op_t instr;
output [2:0] fclass;

function [2:0] fnClass;
input Qupls5_pkg::micro_op_t ir;
begin
	case(ir.opcode)
	// Load / store
	Qupls5_pkg::OP_PPC_LBZ,Qupls5_pkg::OP_PPC_LHZ,Qupls5_pkg::OP_PPC_LHA,Qupls5_pkg::OP_PPC_LWZ,
	Qupls5_pkg::OP_PPC_STB,Qupls5_pkg::OP_PPC_STH,Qupls5_pkg::OP_PPC_STW:
		fnClass = 3'd0;
	// Shift / rotate / bitfield
	Qupls5_pkg::OP_PPC_RLWINM,
	Qupls5_pkg::OP_PPC_RLWNM,
	Qupls5_pkg::OP_PPC_RLWIMI,
	Qupls5_pkg::OP_PPC_RLDIC:
		fnClass = 3'd1;
	// Floating point
//		fnClass = 3'd2;
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
	Qupls5_pkg::OP_PPC_XORIS:
		fnClass = 3'd1;
	/*
  Qupls5_pkg::OP_CAP:
      case(ir.func)
      Qupls5_pkg::CAP_RET:    fnClass = 3'd3;
      default:    fnClass = 3'd7;
      endcase
  */
	Qupls5_pkg::OP_PPC_SC,
	Qupls5_pkg::OP_PPC_B,
	Qupls5_pkg::OP_PPC_BC:
		fnClass = 3'd3;
	Qupls5_pkg::OP_19:
		case(ir.func)
		Qupls5_pkg::FN19_BCLR,
		Qupls5_pkg::FN19_BCCTR,
		Qupls5_pkg::FN19_BCTAR:
			fnClass = 3'd3;
		default:
			fnClass = 3'd7;
		endcase
	default:
		fnClass = 3'd7;
	endcase
end
endfunction

assign fclass = fnClass(instr);

endmodule
