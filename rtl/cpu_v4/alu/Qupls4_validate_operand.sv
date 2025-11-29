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
// 3500 LUTs / 0 FFs (0 bypassing inputs)
// 5010 LUTs / 0 FFs (8 bypassing inputs) performance
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_validate_operand(arn, prnv, rfo, rfo_tag,
	aRn0,aRn1,aRn2,
	val0, val1, val2, val0_tag, val1_tag, val2_tag, 
	rfi_val, rfi_tag, rfi_aRd,
	valid0_i, valid1_i, valid2_i, valid0_o, valid1_o, valid2_o);
parameter NBPI = 8;					// number of bypassing inputs
input aregno_t [15:0] arn;	// arn for corresponding prn
input [15:0] prnv;
input value_t [15:0] rfo;
input Qupls4_pkg::flags_t [15:0] rfo_tag;
input aregno_t aRn0;
input aregno_t aRn1;
input aregno_t aRn2;
output value_t val0;
output value_t val1;
output value_t val2;
output flags_t val0_tag;
output flags_t val1_tag;
output flags_t val2_tag;
input value_t [NBPI-1:0] rfi_val;
input Qupls4_pkg::flags_t [NBPI-1:0] rfi_tag;
input aregno_t [NBPI-1:0] rfi_aRd;
input valid0_i;
input valid1_i;
input valid2_i;
output reg valid0_o;
output reg valid1_o;
output reg valid2_o;

integer nn;
/*
pregno_t pRn0;
pregno_t pRn1;
pregno_t pRn2;
reg pRn0v, pRn1v, pRn2v;

integer nn,mm;

// Find the physical registers matching the architectural ones.
always_comb
begin
	pRn0 = 9'd0;
	pRn1 = 9'd0;
	pRn2 = 9'd0;
	pRn0v = INV;
	pRn1v = INV;
	pRn2v = INV;
	for (mm = 0; mm < 16; mm = mm + 1) begin
		if (aRn0 == arn[mm] && prnv[mm]) begin
			pRn0 = prn[mm];
			pRn0v = VAL;
		end
		if (aRn1 == arn[mm] && prnv[mm]) begin
			pRn1 = prn[mm];
			pRn1v = VAL;
		end
		if (aRn2 == arn[mm] && prnv[mm]) begin
			pRn2 = prn[mm];
			pRn2v = VAL;
		end
	end
end
*/

always_comb
begin
	valid0_o = valid0_i;
	valid1_o = valid1_i;
	valid2_o = valid2_i;
	val0 = value_zero;
	val1 = value_zero;
	val2 = value_zero;
	val0_tag = {$bits(flags_t){1'b0}};
	val1_tag = {$bits(flags_t){1'b0}};
	val2_tag = {$bits(flags_t){1'b0}};
	if (aRn0==8'd0) begin
		val0 = {$bits(value_t){1'b0}};
		val0_tag = {$bits(flags_t){1'b0}};
		valid0_o = VAL;
	end
	else
	for (nn = 0; nn < 16; nn = nn + 1) begin
		if (aRn0==arn[nn] && prnv[nn] && !valid0_i) begin
			val0 = rfo[nn];
			val0_tag = rfo_tag[nn];
			valid0_o = VAL;
		end
	end
	if (aRn1==8'd0) begin
		val1 = {$bits(value_t){1'b0}};
		val1_tag = {$bits(flags_t){1'b0}};
		valid1_o = VAL;
	end
	else
	for (nn = 0; nn < 16; nn = nn + 1) begin
		if (aRn1==arn[nn] && prnv[nn] && !valid1_i) begin
			val1 = rfo[nn];
			val1_tag = rfo_tag[nn];
			valid1_o = VAL;
		end
	end
	if (aRn2==8'd0) begin
		valid2_o = VAL;
		val2 = {$bits(value_t){1'b0}};
		val2_tag = {$bits(flags_t){1'b0}};
	end
	else
	for (nn = 0; nn < 16; nn = nn + 1) begin
		if (aRn2==arn[nn] && prnv[nn] && !valid2_i) begin
			val2 = rfo[nn];
			val2_tag = rfo_tag[nn];
			valid2_o = VAL;
		end
	end
	// Bypassing from the input to the register file trims a clock cycle off
	// latency.
	// We could also bypass directly from the outputs of the functional units.
	// This is not done here due to the size of the bypass network. There are
	// 14 functional units that could be bypassed.
	// However, there is bypassing from the output of the first SAU.
	if (Qupls4_pkg::PERFORMANCE) begin
		for (nn = 0; nn < NBPI; nn = nn + 1) begin
			if (aRn0==rfi_aRd[nn] && !valid0_i) begin
				val0 = rfi_val[nn];
				val0_tag = rfi_tag[nn];
				valid0_o = VAL;
			end
		end
		for (nn = 0; nn < NBPI; nn = nn + 1) begin
			if (aRn1==rfi_aRd[nn] && !valid1_i) begin
				val1 = rfi_val[nn];
				val1_tag = rfi_tag[nn];
				valid1_o = VAL;
			end
		end
		for (nn = 0; nn < NBPI; nn = nn + 1) begin
			if (aRn2==rfi_aRd[nn] && !valid2_i) begin
				val2 = rfi_val[nn];
				val2_tag = rfi_tag[nn];
				valid2_o = VAL;
			end
		end
	end
end

endmodule
