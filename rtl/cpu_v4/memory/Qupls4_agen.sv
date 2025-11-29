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
import Qupls4_pkg::*;

module Qupls4_agen(rst, clk, next, rse, out, tlb_v, virt2phys, 
	load, store, vload_ndx, vstore_ndx, amo, laneno,
	res, resv);
input rst;
input clk;
input next;								// calculate for next cache line
input Qupls4_pkg::reservation_station_entry_t rse;
input out;
input tlb_v;
input virt2phys;
input load;
input store;
input vload_ndx;
input vstore_ndx;
input amo;
input [7:0] laneno;
output cpu_types_pkg::address_t res;
output reg resv;

cpu_types_pkg::address_t as, bs;
cpu_types_pkg::address_t res1;

always_comb
	as = rse.argA;

always_comb
	bs = rse.argB << rse.uop.ls.sc;

always_comb
begin
	if (vload_ndx | vstore_ndx)
		res1 = as + bs * laneno + rse.argI;
	else if (amo)
		res1 = as;				// just [Rs1]
	else if (virt2phys | load | store)
		res1 = as + bs + rse.argI;
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
