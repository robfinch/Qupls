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
//	  Tracks the history of writes to the register file and outputs five
// tap points.
//	  Note that the write port history can be used only for a few cycles
// as registers will be renamed. Periodically the same register tag could
// be reused. We do not want stale data in the write port history to be
// used. The renamer prevents the reuse of the same register tag too soon,
// by rotating the register selection.
// ============================================================================

import Qupls4_pkg::*;

module Qupls4_wp_history_tap(clk, wp_i, wp_tap_o);
input clk;
input Qupls4_pkg::operand_t [3:0] wp_i;
output Qupls4_pkg::operand_t [3:0] wp_tap_o [0:4];

integer n3;
Qupls4_pkg::operand_t [3:0] wp_oper_hist [0:15];
Qupls4_pkg::operand_t [3:0] wp_oper_tap [0:4];

always_ff @(posedge clk)
begin
	wp_oper_hist[0] <= wp_i;
	for (n3 = 1; n3 < 127; n3 = n3 + 1)
		wp_oper_hist[n3] <= wp_oper_hist[n3-1];
end

always_comb
begin
	wp_tap_o[0] = wp_oper_hist[2];
	wp_tap_o[1] = wp_oper_hist[3];
	wp_tap_o[2] = wp_oper_hist[5];
	wp_tap_o[3] = wp_oper_hist[8];
	wp_tap_o[4] = wp_oper_hist[13];
end

endmodule
