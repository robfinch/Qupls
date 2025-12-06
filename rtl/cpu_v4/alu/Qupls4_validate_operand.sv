// ============================================================================
//        __
//   \\__/ o\    (C) 2025  Robert Finch, Waterloo
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
// 1850 LUTs / 0 FFs (0 bypassing inputs)
// 5010 LUTs / 0 FFs (8 bypassing inputs) performance
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_validate_operand(rf_oper_i, oper_i, oper_o, bypass_i);
parameter NBPI = 8;					// number of bypassing inputs
parameter NENTRY = 3;
input Qupls4_pkg::operand_t [NREG_RPORTS-1:0] rf_oper_i;
input Qupls4_pkg::operand_t [NENTRY-1:0] oper_i;
output Qupls4_pkg::operand_t [NENTRY-1:0] oper_o;
input Qupls4_pkg::operand_t [NBPI-1:0] bypass_i;

integer nn,jj;

always_comb
begin
	for (nn = 0; nn < NENTRY; nn = nn + 1) begin
		oper_o[nn] = oper_i[nn];
		oper_o[nn].val = value_zero;
		oper_o[nn].flags = {$bits(flags_t){1'b0}};
		for (jj = 0; jj < 16; jj = jj + 1) begin
			if (oper_i[nn].aRn==rf_oper_i[jj].aRn && rf_oper_i[jj].v && !oper_i[nn].v) begin
				oper_o[nn] = rf_oper_i[jj];
				oper_o[nn].v = VAL;
			end
		end
	end
	// Bypassing from the input to the register file trims a clock cycle off
	// latency.
	// We could also bypass directly from the outputs of the functional units.
	// This is not done here due to the size of the bypass network. There are
	// 14 functional units that could be bypassed.
	// However, there is bypassing from the output of the first SAU.
	if (Qupls4_pkg::PERFORMANCE) begin
		for (nn = 0; nn < NENTRY; nn = nn + 1) begin
			for (jj = 0; jj < NBPI; jj = jj + 1) begin //check phys reg???
				if (oper_i[nn].aRn==bypass_i[jj].aRn && bypass_i[jj].v && !oper_i[nn].v) begin
					oper_o[nn] = bypass_i[jj];
					oper_o[nn].v = VAL;
				end
			end
		end
	end
end

endmodule
