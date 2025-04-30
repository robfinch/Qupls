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
// 2238 LUTs / 0 FFs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;

module Stark_validate_operand(prn, prnv, rfo, rfo_tag,
	pRn0,pRn1,pRn2,
	val0, val1, val2, val0_tag, val1_tag, val2_tag, 
	rfi_val, rfi_tag, rfi_pRd,
	valid0_i, valid1_i, valid2_i, valid0_o, valid1_o, valid2_o);
input pregno_t [15:0] prn;
input [15:0] prnv;
input value_t [15:0] rfo;
input [15:0] rfo_tag;
input pregno_t pRn0;
input pregno_t pRn1;
input pregno_t pRn2;
output value_t val0;
output value_t val1;
output value_t val2;
output reg val0_tag;
output reg val1_tag;
output reg val2_tag;
input value_t [3:0] rfi_val;
input [3:0] rfi_tag;
input pregno_t [3:0] rfi_pRd;
input valid0_i;
input valid1_i;
input valid2_i;
output reg valid0_o;
output reg valid1_o;
output reg valid2_o;

integer nn;
always_comb
begin
	valid0_o = valid0_i;
	valid1_o = valid1_i;
	valid2_o = valid2_i;
	val0 = value_zero;
	val1 = value_zero;
	val2 = value_zero;
	val0_tag = 1'b0;
	val1_tag = 1'b0;
	val2_tag = 1'b0;
	if (pRn0==9'd0) begin
		val0 = {$bits(value_t){1'b0}};
		val0_tag = 1'b0;
		valid0_o = VAL;
	end
	else
	for (nn = 0; nn < 16; nn = nn + 1) begin
		if (pRn0==prn[nn] && prnv[nn] && !valid0_i) begin
			val0 = rfo[nn];
			val0_tag = rfo_tag[nn];
			valid0_o = VAL;
		end
	end
	if (pRn1==9'd0) begin
		val1 = {$bits(value_t){1'b0}};
		val1_tag = 1'b0;
		valid1_o = VAL;
	end
	else
	for (nn = 0; nn < 16; nn = nn + 1) begin
		if (pRn1==prn[nn] && prnv[nn] && !valid1_i) begin
			val1 = rfo[nn];
			val1_tag = rfo_tag[nn];
			valid1_o = VAL;
		end
	end
	if (pRn2==9'd0) begin
		valid2_o = VAL;
		val2 = {$bits(value_t){1'b0}};
		val2_tag = 1'b0;
	end
	else
	for (nn = 0; nn < 16; nn = nn + 1) begin
		if (pRn2==prn[nn] && prnv[nn] && !valid2_i) begin
			val2 = rfo[nn];
			val2_tag = rfo_tag[nn];
			valid2_o = VAL;
		end
	end
	// Bypassing from the input to the register file trims a clock cycle off
	// latency.
	// We could also bypass directly from the outputs of the functional units.
	// This is not done here due to the size of the bypass network. There are
	// 11 functional units that could be bypassed.
	if (PERFORMANCE) begin
		for (nn = 0; nn < 4; nn = nn + 1) begin
			if (pRn0==rfi_pRd[nn] && !valid0_i) begin
				val0 = rfi_val[nn];
				val0_tag = rfi_tag[nn];
				valid0_o = VAL;
			end
		end
		for (nn = 0; nn < 4; nn = nn + 1) begin
			if (pRn1==rfi_pRd[nn] && !valid1_i) begin
				val1 = rfi_val[nn];
				val1_tag = rfi_tag[nn];
				valid1_o = VAL;
			end
		end
		for (nn = 0; nn < 4; nn = nn + 1) begin
			if (pRn2==rfi_pRd[nn] && !valid2_i) begin
				val2 = rfi_val[nn];
				val2_tag = rfi_tag[nn];
				valid2_o = VAL;
			end
		end
	end
end

endmodule
