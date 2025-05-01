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
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;

module Stark_validate_Rn(prn, prnv, rfo, rfo_tag, pRn, val, val_tag, 
	rfi_val, rfi_tag, rfi_pRd, valid_i, valid_o);
input pregno_t [15:0] prn;
input [15:0] prnv;
input value_t [15:0] rfo;
input [15:0] rfo_tag;
input pregno_t pRn;
output value_t val;
output reg val_tag;
input value_t [3:0] rfi_val;
input [3:0] rfi_tag;
input pregno_t [3:0] rfi_pRd;
input valid_i;
output reg valid_o;

integer nn;
always_comb
begin
	valid_o = valid_i;
	val = value_zero;
	val_tag = 1'b0;
	if (pRn==9'd0)
		valid_o = VAL;
	else
	for (nn = 0; nn < 16; nn = nn + 1) begin
		if (pRn==prn[nn] && prnv[nn] && !valid_i) begin
			val = rfo[nn];
			val_tag = rfo_tag[nn];
			valid_o = VAL;
		end
	end
	// Bypassing from the input to the register file trims a clock cycle off
	// latency.
	if (Stark_pkg::PERFORMANCE) begin
		for (nn = 0; nn < 4; nn = nn + 1) begin
			if (pRn==rfi_pRd[nn] && !valid_i) begin
				val = rfi_val[nn];
				val_tag = rfi_tag[nn];
				valid_o = VAL;
			end
		end
	end
end

endmodule
