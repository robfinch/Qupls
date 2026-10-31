// ============================================================================
//        __
//   \\__/ o\    (C) 2026  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	capability_pkg.sv
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

package capability_pkg;

typedef struct packed
{
	logic [7:0] priv_lvl;
	logic [23:0] perms;
	logic [3:0] flags;
	logic [23:0] otype;
	logic [2:0] resv;
	logic [64:0] top;
	logic [63:0] base;
	logic [63:0] offset;
} uc64_capability_t;


function fnIsSealed;
input [63:0] cap;
begin
	fnIsSealed = (cap[44:27]==18'h3fffe || cap[44:27] < 18'h3FFEF);
end
endfunction

function fnUcIsSealed;
input uc64_capability_t cap;
begin
	fnUcIsSealed = (cap.otype==18'h3fffe || cap.otype < 18'h3FFEF);
end
endfunction

function fnIsSealedOrReserved;
input [63:0] cap;
begin
	fnIsSealedOrReserved = cap[44:27]!=18'h3ffff;
end
endfunction

function fnIsReserved;
input [63:0] cap;
begin
	fnIsReserved = cap[44:27]<=18'h3fffd && cap[44:27] >= 18'h3fff0;
end
endfunction

function fnUcIsReserved;
input uc64_capability_t cap;
begin
	fnUcIsReserved = cap.otype<=18'h3fffd && cap.otype >= 18'h3fff0;
end
endfunction

function [63:0] fnGetOtype;
input [63:0] cap;
begin
	if (fnIsReserved(cap))
		fnGetOtype = {{46{cap[44]}},cap[44:27]};
	else
		fnGetOtype = {46'd0,cap[44:27]};
end
endfunction

function [63:0] fnAlignMask;
input cpu_types_pkg::capability_high64_t cap;
reg [7:0] E;
begin
	if (cap.Ie)
		E = {2'b00,cap.Te,cap.Be};
	else
		E = 8'd0;
	fnAlignMask = ~((64'd1 << (E+3)) - 64'd1);
end
endfunction

function [63:0] fnUcAlignMask;
input uc64_capability_t cap;
begin
	fnUcAlignMask = -64'd1 << 3;
end
endfunction

function fnIsInRange;
input cpu_types_pkg::capability_high64_t cap;
input [63:0] inc;
reg [7:0] E;
reg [63:0] mask;
begin
	if (cap.Ie)
		E = {2'b00,cap.Te,cap.Be};
	else
		E = 8'd0;
	mask = ~((64'd1 << (E+17)) - 64'd1);
	// To be in range all the upper bits of the increment must be the same.
	// They are either all zeroes or all ones.
	fnIsInRange = (inc & mask) == mask || (inc & mask) == 64'd0;
end
endfunction

function fnIsInLimit;
input cpu_types_pkg::capability_high64_t cap;
input [63:0] adr;
input [63:0] inc;
reg [7:0] E;
reg [63:0] mask;
reg [16:0] amid, imid;
reg [16:0] B;
reg [16:0] R;
begin
	if (cap.Ie) begin
		E = {2'b00,cap.Te,cap.Be};
		B[5:0] = 6'b0;
	end
	else begin
		E = 8'd0;
		B[5:0] = {cap.Be,3'b0};
	end
	B[16:6] = cap.B;
	imid = (inc >> (E+3));
	amid = (adr >> (E+3));
	R = {B[16:14]-3'd1,14'd0};
	if (inc[63])
		fnIsInLimit = imid >= (R - amid) && (R != amid);
	else
		fnIsInLimit = imid < (R - amid - 1);
end
endfunction

function fnIsRepresentable;
input cpu_types_pkg::capability_high64_t cap;
input [63:0] adr;
input [63:0] inc;
reg [7:0] E;
begin
	if (cap.Ie)
		E = {2'b00,cap.Te,cap.Be};
	else
		E = 8'd0;
	fnIsRepresentable = (fnIsInLimit(cap,adr,inc) && fnIsInRange(cap,inc)) || (E >= 47);
end
endfunction

endpackage
