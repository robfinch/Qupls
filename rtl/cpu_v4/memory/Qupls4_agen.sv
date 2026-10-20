// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2026  Robert Finch, Waterloo
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
// Note this is the only place register codes are bypassed for r0 and r31 to
// allow the use of zero and the instruction pointer.
//
// 105 LUTs / 2300 FFs / 
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_agen(rst, clk, rse_i, rse_o, out,
	tlb_v, page_fault, page_fault_v,
	load_store, vlsndx, amo,
	res, resv);
input rst;
input clk;
input Qupls4_pkg::reservation_station_entry_t rse_i;
output Qupls4_pkg::reservation_station_entry_t rse_o;
input out;
input tlb_v;
input page_fault;
input page_fault_v;
input load_store;
input vlsndx;
input amo;
output cpu_types_pkg::address_t res;
output reg resv;

cpu_types_pkg::address_t as, bs, bsv;
cpu_types_pkg::address_t res1;
Qupls4_pkg::reservation_station_entry_t rse1;
reg [5:0] shift;

always_ff @(posedge clk) 
begin
	rse1 <= rse_i;
	if (page_fault && !rse_i.excv) begin
		rse1.exc <= Qupls4_pkg::FLT_PAGE;
		rse1.excv <= page_fault_v;
	end
end
always_ff @(posedge clk) 
	rse_o <= rse1;

always_ff @(posedge clk)
	as = rse_i.Rs1z ? value_zero : rse_i.Rs1ip ? rse_i.pc : rse_i.arg[0].val;

always_ff @(posedge clk)
	bs = rse_i.Rs2z ? value_zero : (rse_i.arg[1].val * ({rse_i.uop.sc==3'd0,rse_i.uop.sc}));

always_ff @(posedge clk)
	bsv = rse_i.Rs2z ? value_zero : (rse_i.arg[1].val * rse_i.uop.vlen);

always_comb
	case(rse_i.velesz)
	2'd0:	shift = {rse_i.laneno,3'd0};
	2'd1:	shift = {rse_i.laneno,4'd0};
	2'd2:	shift = {rse_i.laneno,5'd0};
	2'd3:	shift = 6'd0;
	endcase

always_comb
begin
	// Vector indexed vector load / store.
	if (rse_i.vlsndx)
		res1 = as + (bs >> shift) + rse_i.argI;
	// A vector load/store address is calculated almost the same way as an
	// ordinary load/store except that the offset associated with the set
	// of lanes to load/store must be added in. This is done when the 
	// micro-op is built by modifying the immediate constant.
	else if (rse_i.vls)
		res1 = as + bsv + rse_i.argI;
	else if (amo)
		res1 = as;				// just [Rs1]
	// Lane number is 1 for non-vector load/store
	else if (load_store)
		res1 = as + bs + rse_i.argI;
	else
		res1 = 64'd0;
end

always_ff @(posedge clk)
	res <= res1;

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
