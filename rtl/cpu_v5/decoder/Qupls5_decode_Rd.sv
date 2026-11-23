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
// 25 LUTs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls5_pkg::*;

module Qupls5_decode_Rd(om, instr, instr_raw, Rd, Rdv, Rdz, we);
input Qupls5_pkg::operating_mode_t om;
input Qupls5_pkg::micro_op_t instr;
input [335:0] instr_raw;
output aregno_t Rd;
output reg Rdv;
output reg Rdz;
output reg we;

function aregno_t fnRd;
input Qupls5_pkg::micro_op_t instr;
input [335:0] instr_raw;
Qupls5_pkg::micro_op_t ir;
begin
	ir = instr;
	fnRd = 6'd0;
	case(ir.opcode)
	Qupls5_pkg::OP_PPC_ADDI,Qupls5_pkg::OP_PPC_ADDIS,
	Qupls5_pkg::OP_PPC_ANDI,Qupls5_pkg::OP_PPC_ANDIS,
	Qupls5_pkg::OP_PPC_ORI,Qupls5_pkg::OP_PPC_ORIS,
	Qupls5_pkg::OP_PPC_XORI,Qupls5_pkg::OP_PPC_XORIS:
		fnRd = {2'd0,ir.Rd};
	Qupls5_pkg::OP_PPC_CMPI,Qupls5_pkg::OP_PPC_CMPLI:
		fnRd = {2'd0,6'd32};
	Qupls5_pkg::OP_PPC_RLWINM,
	Qupls5_pkg::OP_PPC_RLWNM,
	Qupls5_pkg::OP_PPC_RLWIMI,
	Qupls5_pkg::OP_PPC_RLDIC:
		fnRd = {2'd0,ir.Rd};
	// Branch instructions
	Qupls5_pkg::OP_B:
		fnRd = 6'd33;
	// Load / store instructions
	Qupls5_pkg::OP_31:
		case(ir.func)
		Qupls5_pkg::FN31_MTSPR:
			case(ir.spr)
			10'd8:	fnRd = 6'd33;		// LR
			10'd9:	fnRd = 6'd34;		// CTR
			10'd815:	fnRd = 6'd35;	// TAR
			endcase
		default:;
		endcase
	default:
		fnRd = 8'd0;
	endcase
end
endfunction

// ToDo: Fix these
function aregno_t fnRdv;
input Qupls5_pkg::micro_op_t instr;
input [335:0] instr_raw;
Qupls5_pkg::micro_op_t ir;
begin
	fnRdv = INV;
	ir = instr;
	case(ir.opcode)
	// Integer instructions
	Qupls5_pkg::OP_PPC_ADDI,Qupls5_pkg::OP_PPC_ADDIS,
	Qupls5_pkg::OP_PPC_ANDI,Qupls5_pkg::OP_PPC_ANDIS,
	Qupls5_pkg::OP_PPC_ORI,Qupls5_pkg::OP_PPC_ORIS,
	Qupls5_pkg::OP_PPC_XORI,Qupls5_pkg::OP_PPC_XORIS:
		fnRdv = VAL;
	Qupls5_pkg::OP_PPC_CMPI,Qupls5_pkg::OP_PPC_CMPLI:
		fnRdv = VAL;
	Qupls5_pkg::OP_PPC_RLWINM,
	Qupls5_pkg::OP_PPC_RLWNM,
	Qupls5_pkg::OP_PPC_RLWIMI,
	Qupls5_pkg::OP_PPC_RLDIC:
		fnRdv = VAL;
	// Load / store instructions
	Qupls5_pkg::OP_31:
		case(ir.func)
		Qupls5_pkg::FN31_MTSPR:
			case(ir.spr)
			10'd8:	fnRdv = VAL;		// LR
			10'd9:	fnRdv = VAL;		// CTR
			10'd815:	fnRdv = VAL;	// TAR
			endcase
		default:;
		endcase
	// Branch instructions
	Qupls5_pkg::OP_B:
		fnRdv = ir.lk;
	default:
		fnRdv = INV;
	endcase
end
endfunction

always_comb
begin
	Rd = fnRd(instr, instr_raw);
	Rdv = fnRdv(instr, instr_raw);
	Rdz = ~|Rd[4:0];
	we = Rdv;
end

endmodule
