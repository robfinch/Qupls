// ============================================================================
//        __
//   \\__/ o\    (C) 2026  Robert Finch, Waterloo
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
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_capability_latency5(rst, clk, rse, pcc, pcch, o, flags);
input rst;
input clk;
input Qupls4_pkg::reservation_station_entry_t rse;
input Qupls4_pkg::micro_op_t ir;
input pc_address_t pcc;
input cpu_types_pkg::capability_high64_t pcch;
output cpu_types_pkg::[63:0] o;
output cpu_types_pkg::flags_t flags;

function fnIsSealed;
input [63:0] cap;
begin
	fnIsSealed = (cap[44:27]==18'h3fffe || cap[44:27] < 18'h3FFEF)
end
endfunction

function fnIsSealedOrReserved;
input [63:0] cap;
begin
	fnIsSealedOrReserved = cap[44:27]!=18'h3ffff;
end
endfunction

reg [63:0] a;
reg [63:0] b;
reg [63:0] c;
reg [63:0] d;
cpu_types_pkg::flags_t c_flags;
cpu_types_pkg::flags_t d_flags;
assign a = rse.arg[0].val;
assign b = rse.arg[1].val;
assign c = rse.arg[2].val;
assign d = rse.arg[4].val;
assign c_flags = rse.arg[2].flags;
assign d_flags = rse.arg[4].flags;

Qupls4_pkg::micro_op_t iro;
reg [63:0] ao,bo,co,do;
reg chg;
reg [11:0] donef;
wire [63:0] base;
wire [64:0] top;
reg [63:0] bus;
cpu_types_pkg::flags_t busf;
wire [7:0] E;
cpu_types_pkg::capability_high64_t c64 = capability_high64_t'(c);
cpu_types_pkg::capability_high64_t c64d4, higho, ch4, dh4;
wire done8;
wire invoke = ir.func==CAP_INVOKE;
wire setbounds = ir.func==CAP_SETBOUNDS;
reg isInvokeInBounds, isInBounds;
capability_pkg::uc64_capability_t ac,bc,cc,dc;
cpu_types_pkg::flags_t cc_flags;
cpu_types_pkg::flags_t dc_flags;

always_ff @(posedge clk) ao <= a;
always_ff @(posedge clk) bo <= b;
always_ff @(posedge clk) co <= c;
always_ff @(posedge clk) do <= d;
always_ff @(posedge clk) iro <= ir;

always_comb
	chg = {ir,a,b,c,d} != {iro,ao,bo,co,do};

// Create a delayed done signal.
always_ff @(posedge clk)
begin
	if (chg)
		donef <= {11'b0,1'b1};
	else
		donef <= {donef[10:0],1'b0};
end
	
always_ff @(posedge clk)
begin
	if (chg)
		done <= FALSE;
	else begin
		case(ir.func)
		CAP_GETBASE:		done <= donef[4];
		CAP_GETTOP:			done <= donef[4];
		CAP_GETLENGTH:	done <= donef[4];
		CAP_INCOFFSET:	done <= donef[8];
		CAP_INCOFFSETI:	done <= donef[8];
		CAP_SETBOUNDS:	done <= donef[4];
		default:	done <= TRUE;
		endcase
	end
end

delay4 #(.WID(64)) udly1 (.clk(clk), .ce(1'b1), .i(c64), .o(c64d));
delay4 #(.WID(64)) udly2 (.clk(clk), .ce(1'b1), .i(d), .o(dh4));
assign ch4 = c64d;


// Decompress the base field of a capability.
module modCalcBase(rst, clk, cap, adr, base, Eo);
input rst;
input clk;
input [63:0] cap;
input [63:0] adr;
output reg [63:0] base;
output reg [7:0] Eo;

reg Ie;
reg [7:0] E, E2, E3;
reg [16:0] B;
reg [63:0] amid,amid3;
reg [63:0] atop,atop3;
integer A3;
integer B3;
integer R;
reg [63:0] cb;
reg [63:0] adrd;

always_comb
	Ie = cap[26];		// convenience rename

always_ff @(posedge clk)
if (rst)
	base <= 64'd0;
else begin
	// Pipeline clock #1
	if (Ie) begin
		E <= {2'b00,cap[16:14],cap[2:0]};
		B[5:0] <= 6'b0;
	end
	else begin
		E <= 8'd0;
		B[5:0] <= {cap[2:0],3'b0};
	end
	B[16:6] <= cap[13:3];
	adrd <= adr;

	// Pipeline clock #2
	A3 <= (adr >> (E + 14)) & 7;
	B3 <= B[16:14];
	R <= B[16:14] - 1;
	amid <= {50'd0,B} << E;
	atop <= adr & ~((64'd1 << (E+17)) - 64'd1);
	E2 <= E;

	// Pipeline clock #3
	case ({A3 < R,B3 < R})
	2'b00:	cb <= 64'd0;
	2'b01:	cb <= 64'd1 << (E2+14);
	2'b10:	cb <= -64'd1 << (E2+14);
	2'b11:	cb <= 64'd0;
	endcase
	amid3 <= amid;
	atop3 <= atop;
	E3 <= E2;

	// Pipeline clock #4
	base <= (atop + cb) | amid;
	Eo <= E3;
end
endmodule

// Decompress the top field of a capability.
module modCalcTop(rst, clk, cap, adr, top, Eo);
input rst;
input clk;
input [63:0] cap;
input [63:0] adr;
output reg [64:0] top;
output reg [7:0] Eo;

reg Ie;
reg [7:0] E, E2, E3;
reg [16:0] B,T,T2;
reg [63:0] amid,amid3;
reg [63:0] atop,atop3;
integer A3;
integer B3,T3;
integer R;
reg [63:0] ct;
reg [63:0] adrd;
reg Lcarryout;
reg Lmsb;

always_comb
	Ie = cap[26];		// convenience rename

always_ff @(posedge clk)
if (rst)
	base <= 64'd0;
else begin
	// Pipeline clock #1
	if (Ie) begin
		E <= {2'b00,cap[16:14],cap[2:0]};
		B[5:0] <= 6'b0;
		T[5:0] <= 6'b0;
		Lcarryout <= cap[25:17] < cap[11:3];	// T[14:6] < B[14:6]
	end
	else begin
		E <= 8'd0;
		B[5:0] <= {cap[ 2: 0],3'b0};
		T[5:0] <= {cap[16:14],3'b0};
		Lcarryout <= cap[25:14] < cap[11:0];	// T[14:3] < B[14:3]
	end
	Lmsb <= Ie;
	B[16:6] <= cap[13: 3];
	T[14:6] <= cap[25:17];
	adrd <= adr;

	// Pipeline clock #2
	T2[14:0] <= T[14:0];
	T2[16:15] <= B[16:15] + Lcarryout + Lmsb;
	A3 <= (adr >> (E + 14)) & 7;
	B3 <= B[16:14];
	T3 <= (B[16:15] + Lcarryout + Lmsb,T[14]};
	R <= B[16:14] - 1;
	amid <= {50'd0,B} << E;
	atop <= adr & ~((64'd1 << (E+17)) - 64'd1);
	E2 <= E;

	// Pipeline clock #3
	case ({A3 < R,T3 < R})
	2'b00:	ct <= 64'd0;
	2'b01:	ct <= 64'd1 << (E2+14);
	2'b10:	ct <= -64'd1 << (E2+14);
	2'b11:	ct <= 64'd0;
	endcase
	amid3 <= amid;
	atop3 <= atop;
	E3 <= E2;
	
	// pipeline clock #4
	top <= (atop + ct) | amid;
	Eo <= E3;
	
end
endmodule

module modCalcHigh(base, length, otype, flag, perm, high);
input [63:0] base;
input [64:0] length;
input [17:0] otype;
input flag;
input [15:0] perm;
output [63:0] high;

reg [7:0] E, E2, E3;
reg [16:0] B, T, B3, T3;
reg [64:0] L2,L3,base1,base2,base3,length_rnd;
reg [17:0] otype1, otype2, otype3, otype4;
reg flag1,flag2,flag3,flag4;
reg [15:0] perm1,perm2,perm3,perm4;
reg Ie, Ie2, Ie3, Ie4;
reg exact;
wire [6:0] clzo,clzoL3,clzo1,clzo2,clzo3;
wire [64:0] top = base + length;
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
		
	// pipeline clock #2
	if (Ie==1'b0) begin
		B <= {base[16:3],3'b0};
		T <= {top[14:3],3'b0};
	end
	else begin
		B <= base[63:3] >> E;
		T <= top[64:3] >> E;
		Rnd <= {top[63:3],64'd0} >> E;
	end
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

modCalcBase ucb1
(
	.rst(rst),
	.clk(clk),
	.cap(invoke ? pcch : c),
	.adr(invoke ? pcc : a),
	.base(base),
	.Eo()
);

modCalcTop uct1
(
	.rst(rst),
	.clk(clk),
	.cap(invoke ? pcch : c),
	.adr(invoke ? pcc : a),
	.top(top),
	.Eo(E)
);

modCalcHigh uch1
(
	.base(setbounds ? a : base),
	.length(setbounds ? b : top-base),
	.otype(c64d4.otype),
	.flag(c64d4.flag),
	.perm(c64d4.perms),
	.high(higho)
);

always_comb
	isInvokeInBounds = pcc >= base && pcc <= top - 6;
always_comb
	isInBounds = b >= base && b <= top - 6;

always_ff @(posedge clk)
if (rst) begin
	ac <= uc64_capability_t'(256'd0);
	bc <= uc64_capability_t'(256'd0);
	cc <= uc64_capability_t'(256'd0);
	dc <= uc64_capability_t'(256'd0);
end
else begin
	case(ir.byteno)
	6'd1:
		begin
			ac[63:0] <= a;
			bc[63:0] <= b;
			cc[63:0] <= c;
			dc[63:0] <= d;
		end
	6'd2:
		begin
			ac[127:64] <= a;
			bc[127:64] <= b;
			cc[127:64] <= c;
			dc[127:64] <= d;
		end
	6'd3:
		begin
			ac[191:128] <= a;
			bc[191:128] <= b;
			cc[191:128] <= c;
			dc[191:128] <= d;
		end
	6'd4:
		begin
			ac[255:192] <= a;
			bc[255:192] <= b;
			cc[255:192] <= c;
			dc[255:192] <= d;
			cc_flags <= c_flags;
			dc_flags <= d_flags;
		end
	endcase
end

always_ff @(posedge clk)
if (rst) begin
	busf <= 8'h00;
	bus <= 64'd0;
end
else begin
	busf <= 8'h00;
	bus <= 64'd0;
	case(ir.func)
	CAP_GETBASE:
		begin
			busf <= 8'h00;
			bus <= ac.base;
		end
	CAP_GETTOP:
		begin
			busf <= 8'h00;
			bus <= ac.top;
		end
	CAP_GETLENGTH:
		begin
			busf <= 8'h00;
			bus = {ac.top - ac.base,3'b0};
			if ((E < 49) && ((top[64:63]-base[63]) > 1))
				bus <= {~top[64],top[63:0]} - base;
			else
				bus <= top-base;
		end
	CAP_INCOFFSET:
		if (ir.byteno==6'd1) begin
			busf <= 8'h00;
			if (fnIsSealed(c4))
				busf.cap <= FALSE;
			bus <= c;
		end
		else begin
			busf <= 8'h00;
			bus <= a + b;
		end
	CAP_CHKINVOKE:
		if (~ch4.tag|~dh4.tag) begin
			excv <= TRUE;
			exc <= FLT_CTAG;
		end
		else if (fnIsReserved(ch4) || fnIsReserved(dh4)) begin
			excv <= TRUE;
			exc <= FLT_CSEAL;
		end
		else if (ch4.otype != dh4.otype) begin
			excv <= TRUE;
			exc <= FLT_CTYPE;
		end
		else if (~ch4.perms[8]|~dh4.perms[8]) begin
			excv <= TRUE;
			exc <= FLT_CPINVOKE;
		end
		else if (~ch4.perms[1]|dh4.perms[1]) begin
			excv <= TRUE;
			exc <= FLT_CPEXEC;
		end
		else if (a4[0]) begin
			excv <= TRUE;
			exc <= FLT_CALGN;
		end 
		else if (!isInvokeInBounds) begin
			excv <= TRUE;
			exc <= FLT_CLENGTH;
		end
	CAP_CHKBOUNNDS:
		if (~ch4.tag) begin
			excv <= TRUE;
			exc <= FLT_CTAG;
		end
		else if (!isInBounds) begin
			excv <= TRUE;
			exc <= FLT_CLENGTH;
		end
	CAP_SETBOUNDS:
		if (ir.byteno==6'd1) begin
			busf <= c_flags;
			if (fnIsSealed(c4) || !fnIsRepresentable(c4,b4))
				busf.cap <= FALSE;
			bus <= c4;
			bus[26:0] <= higho[26:0];	// copy across base and length
		end
		else begin
			busf <= 8'h00;
			bus <= a4;
		end
	endcase
end

endmodule
