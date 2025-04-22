// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2025  Robert Finch, Waterloo
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
// 250 LUTs / 40 FFs
// ============================================================================

import const_pkg::*;
import Stark_pkg::*;

module Stark_agen(rst, clk, ir, next, out, tlb_v, virt2phys, load, store, amo,
	a, b, i, Ra, Rb, pc, res, resv);
input rst;
input clk;
input next;								// calculate for next cache line
input Stark_pkg::ex_instruction_t ir;
input out;
input tlb_v;
input virt2phys;
input load;
input store;
input amo;
input cpu_types_pkg::address_t a;
input cpu_types_pkg::address_t b;
input cpu_types_pkg::address_t i;
input cpu_types_pkg::aregno_t Ra;
input cpu_types_pkg::aregno_t Rb;
input cpu_types_pkg::pc_address_t pc;
output cpu_types_pkg::address_t res;
output reg resv;

cpu_types_pkg::address_t as, bs;
cpu_types_pkg::address_t res1;

always_comb
	as = a;

always_comb
	bs = b << ir.ins.lsscn.sc;

always_comb
begin
	if (virt2phys | load | store | amo) begin
		if (amo)					// just [Rs1]
			res1 = as;
		if (ir.ins[31])		// d[Rs1]
			res1 = as + i;
		else							// or d[Rs1+Rs2*Sc]
			res1 = as + bs + i;
	end
	else
		res1 <= 64'd0;
end

always_ff @(posedge clk)
	res = next ? {res1[$bits(cpu_types_pkg::address_t)-1:6] + 2'd1,6'd0} : res1;

// Make Agen valid sticky
// The agen takes a clock cycle to compute after the out signal is valid.
reg resv1;
always_ff @(posedge clk) 
if (rst) begin
	resv <= INV;
	resv1 <= INV;
end
else begin
	if (out)
		resv1 <= VAL;
	resv <= resv1;
	if (tlb_v) begin
		resv1 <= INV;
		resv <= INV;
	end
end


endmodule
