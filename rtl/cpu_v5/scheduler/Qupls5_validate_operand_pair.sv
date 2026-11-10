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
// 1860 LUTs / 0 FFs (0 bypassing inputs)
// 5010 LUTs / 0 FFs (8 bypassing inputs) performance
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls5_pkg::*;

module Qupls5_validate_operand_pair(rf_oper_i, operL_i, operH_i, operL_o, operH_o, wp_hist_i, bypass_i);
parameter MWIDTH = 4;
parameter NBPI = 6;					// number of bypassing inputs
parameter NENTRY = 3;
parameter NREG_PORTS = 12;
parameter NREG_WPORTS = 6;
parameter pFPCSR = FALSE;
input Qupls5_pkg::operand_t [NREG_WPORTS-1:0] wp_hist_i [0:4];
input Qupls5_pkg::operand_t [NREG_PORTS-1:0] rf_oper_i;
input Qupls5_pkg::operand_t [NENTRY-1:0] operL_i;
input Qupls5_pkg::operand_t [NENTRY-1:0] operH_i;
output Qupls5_pkg::operand_t [NENTRY-1:0] operL_o;
output Qupls5_pkg::operand_t [NENTRY-1:0] operH_o;
input Qupls5_pkg::operand_t [NBPI-1:0] bypass_i;

integer nn,jj,kk;

always_comb
begin
	foreach (operL_o[nn]) begin
		operL_o[nn] = operL_i[nn];
		operL_o[nn].val = value_zero;
		operL_o[nn].flags = {$bits(flags_t){1'b0}};
		operH_o[nn] = operH_i[nn];
		operH_o[nn].val = value_zero;
		operH_o[nn].flags = {$bits(flags_t){1'b0}};

		if (operL_i[nn].z)
			operL_o[nn].v = VAL;
		else if (operL_i[nn].is_const) begin
			operL_o[nn].v = VAL;
			operL_o[nn].val = operL_i[nn].val;
		end
		if (operH_i[nn].z)
			operH_o[nn].v = VAL;
		else if (operH_i[nn].is_const) begin
			operH_o[nn].v = VAL;
			operH_o[nn].val = operH_i[nn].val;
		end

		foreach (rf_oper_i[jj]) begin
			if (operL_i[nn].pRn==rf_oper_i[jj].pRn && rf_oper_i[jj].v && !operL_i[nn].v) begin
				operL_o[nn] = rf_oper_i[jj];
				operL_o[nn].v = VAL;
			end
			else if ((pFPCSR & rf_oper_i[jj].fpcsr) && rf_oper_i[jj].v && !operL_i[nn].v) begin
				operL_o[nn] = rf_oper_i[jj];
				operL_o[nn].v = VAL;
			end
		end
		foreach (rf_oper_i[jj]) begin
			if ((operH_i[nn].pRn+9'd1)==rf_oper_i[jj].pRn && rf_oper_i[jj].v && !operH_i[nn].v) begin
				operH_o[nn] = rf_oper_i[jj];
				operH_o[nn].v = VAL;
			end
			else if ((pFPCSR & rf_oper_i[jj].fpcsr) && rf_oper_i[jj].v && !operH_i[nn].v) begin
				operH_o[nn] = rf_oper_i[jj];
				operH_o[nn].v = VAL;
			end
		end

		// Check if operand matches incoming write port history.
		foreach (wp_hist_i[jj]) begin
			for (kk = 0; kk < 4; kk = kk + 1) begin
				if (operL_i[nn].pRn==wp_hist_i[jj][kk].pRn && wp_hist_i[jj][kk].v && !operL_i[nn].v) begin
					operL_o[nn] = wp_hist_i[jj][kk];
					operL_o[nn].v = VAL;
				end
			end
		end
		foreach (wp_hist_i[jj]) begin
			for (kk = 0; kk < 4; kk = kk + 1) begin
				if ((operH_i[nn].pRn+9'd1)==wp_hist_i[jj][kk].pRn && wp_hist_i[jj][kk].v && !operH_i[nn].v) begin
					operH_o[nn] = wp_hist_i[jj][kk];
					operH_o[nn].v = VAL;
				end
			end
		end
	end
	// Bypassing from the input to the register file trims a clock cycle off
	// latency.
	// We could also bypass directly from the outputs of the functional units.
	// This is not done here due to the size of the bypass network. There are
	// 14 functional units that could be bypassed.
	// However, there is bypassing from the output of the first SAU.
	if (Qupls5_pkg::PERFORMANCE) begin
		for (nn = 0; nn < NENTRY; nn = nn + 1) begin
			for (jj = 0; jj < NBPI; jj = jj + 1) begin //check phys reg???
				if (operL_i[nn].pRn==bypass_i[jj].pRn && bypass_i[jj].v && !operL_i[nn].v) begin
					operL_o[nn] = bypass_i[jj];
					operL_o[nn].v = VAL;
				end
			end
			for (jj = 0; jj < NBPI; jj = jj + 1) begin //check phys reg???
				if ((operH_i[nn].pRn+9'd1)==bypass_i[jj].pRn && bypass_i[jj].v && !operH_i[nn].v) begin
					operH_o[nn] = bypass_i[jj];
					operH_o[nn].v = VAL;
				end
			end
		end
	end
end

endmodule
