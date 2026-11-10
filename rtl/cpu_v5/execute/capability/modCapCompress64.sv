// ============================================================================
//        __
//   \\__/ o\    (C) 2026  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//
//	modCapCompress64.sv
//		- compress a 256-bit register representation of capability down into
//			the 64-bit offset (128-bits).
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
// THI+S SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
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
// LUTs / FFs / 0 DSPs ( MHz) 
// ============================================================================

import const_pkg::*;
import capability_pkg::*;

module modCapCompress64(rst_i, clk_i, cap_i, cap_o);
input rst_i;
input clk_i;
input uc64_capability_t cap_i;
output capability64_t cap_o;

reg [23:0] otype;
reg [23:0] perms;
reg [3:0] flags;
reg [7:0] E, E2, E3;
reg [16:0] B, T, B3, T3;
reg [64:0] L2,L3,base,base1,base2,base3,length,length_rnd;
reg [17:0] otype1, otype2, otype3, otype4;
reg flag1,flag2,flag3,flag4;
reg [15:0] perm1,perm2,perm3,perm4;
reg Ie, Ie2, Ie3, Ie4;
reg exact;
wire [6:0] clzo,clzoL3,clzo1,clzo2,clzo3;
// Convenience renames
wire [63:0] base = cap_i.base;
wire [64:0] top = cap_i.top;
wire [64:0] length = top - base;
always_comb otype = cap_i.otype;
always_comb perms = cap_i.perms;
always_comb flags = cap_i.flags;

reg [64:0] top1,top2,top3,top3a;

cntlz64 uclz1 (.i(length[64:17]), .o(clzo));
cntlz64 uclz2 (.i(L3[64:17]), .o(clzoL3));

// Was a bit added to the length?
always_comb
	if (clzoL3 < clzo3) begin
		top3a = base3 + L3;
	else
		top3a = top3;
// Calc "extra" rounding bits for length alignment.
always_comb
	length_rnd = L2 & ((64'd1 << E2) - 64'd1);

always_comb
	if (Ie4)
		high = {perm4,flag4,2'b0,otype4,Ie4,T4[14:6],E4[5:3],B4[16:6],E4[2:0]};
always_comb
	L2 = ((top2 + (|Rnd[63:0] << E2)) - base2;

always_ff @(posedge clk)
begin
	// pipeline clock #1
	E <= 64'd48 - clzo;
	if (64'd48 - clzo == 64'd0 && length[16]==1'b0)
		Ie <= 1'b0;
	else
		Ie <= 1'b1;
	clzo1 <= clzo;
	base1 <= base;
	top1 <= top;
	otype1 <= otype;
	flag1 <= flag;
	perm1 <= perm;
		
	if (Ie==1'b0) begin
		B <= {base[16:3],3'b0};
		T <= {top[14:3],3'b0};
	end
	else begin
		B <= base[63:3] >> E;
		T <= top[64:3] >> E;
		Rnd <= {top[63:3],64'd0} >> E;
	end

	// pipeline clock #2
	Ie2 <= Ie;
	E2 <= E;
	// Mask off and round up length.
	clzo2 <= clzo1;
	base2 <= base1;
	top2 <= top1;
	otype2 <= otype1;
	flag2 <= flag1;
	perm2 <= perm1;
	
	// If any set bits round top up
	if (|Rnd[63:0])
		T3 <= T + 1'b1;
	else
		T3 <= T;
	T3[16:15] <= 2'b00;
	B3 <= B;
	E3 <= E2;
	L3 <= (L2 & ~((64'd1 << E2) - 64'd1)) + (|length_rnd << E2);
	Ie3 <= Ie2;
	clzo3 <= clzo2;
	base3 <= base2;
	top3 <= top2;
	otype3 <= otype2;
	flag3 <= flag2;
	perm3 <= perm2;

	// pipeline clock #4
	if (Ie3==1'b0) begin
		B4 <= {base3[16:3],3'b0};
		T4 <= {top3a[14:3],3'b0};
	end
	else begin
		B4 <= base3[63:3] >> E3;
		T4 <= top3a[64:3] >> E3;
	end
	T4[16:15] <= 2'b00;
	Ie4 <= Ie3;
	E4 <= E3;
	otype4 <= otype3;
	flag4 <= flag3;
	perm4 <= perm3;

end

endmodule

module 
