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
import QuplsPkg::*;

module Qupls_decode_Rb(om, ipl, instr, has_immb, has_Rb, Rb, Rbz, Rbn);
input operating_mode_t om;
input [2:0] ipl;
input ex_instruction_t instr;
input has_immb;
output reg has_Rb;
output cpu_types_pkg::aregno_t Rb;
output reg Rbz;
output reg Rbn;

function aregno_t fnRb;
input ex_instruction_t ir;
input has_immb;
begin
	case(ir.ins.any.opcode)
	OP_RTD:
		fnRb = 9'd31;
	OP_FLT3:
		fnRb = ir.aRb;
	// Loads and stores have has_immb=TRUE but also have an Rb.
	OP_LDx,OP_LDxU,OP_FLDx,OP_DFLDx,OP_PLDx,OP_CACHE,
	OP_STx,OP_FSTx,OP_DFSTx,OP_PSTx:
		fnRb = ir.aRb;
	default:
		if (has_immb)
			fnRb = 9'd0;
		else if (fnImmb(ir))
			fnRb = 9'd0;
		else
			fnRb = ir.aRb;
	endcase
end
endfunction

function fnHasRb;
input ex_instruction_t ir;
input has_immb;
begin
	fnHasRb = 1'b0;
	case(ir.ins.any.opcode)
	OP_RTD:	fnHasRb = 1'b1;
	OP_FLT3:	fnHasRb = 1'b1;
	// Loads and stores have has_immb=TRUE but also have an Rb.
	OP_LDx,OP_LDxU,OP_FLDx,OP_DFLDx,OP_PLDx,OP_CACHE,
	OP_STx,OP_FSTx,OP_DFSTx,OP_PSTx:
		fnHasRb = 1'b1;
	default:
		if (has_immb)
			fnHasRb = 1'd0;
		else if (fnImmb(ir))
			fnHasRb = 1'd0;
		else
			fnHasRb = 1'b1;
	endcase
end
endfunction

always_comb
begin
	Rb = fnRb(instr, has_immb);
	has_Rb = fnHasRb(instr, has_immb);
	if (Rb==9'd31)
		Rb = 9'd32|om;
	Rbn = instr.ins.r3.Rb.n;
	Rbz = ~|Rb;
end

endmodule

