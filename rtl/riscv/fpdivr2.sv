`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2006-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpdivr2.sv
//    Radix 2 floating point divider primitive
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

module fpdivr2(clk_div, ld, a, b, q, r, done, lzcnt);
parameter FPWID = 112;
parameter RADIX = 2;
localparam FPWID1 = FPWID;//((FPWID+2)/3)*3;    // make FPWIDth a multiple of three
localparam DMSB = FPWID1-1;
input clk_div;
input ld;
input [FPWID1-1:0] a;
input [FPWID1-1:0] b;
output reg [FPWID1*2-1:0] q = 0;
output reg [FPWID1-1:0] r = 0;
output reg done = 1'b0;
output reg [8:0] lzcnt;


reg [9:0] cnt;				// iteration count
reg [FPWID1*2-1:0] qi = 0;
reg [DMSB+1:0] ri = 0; 
wire b0;
reg gotnz;					// got a non-zero bit

reg done1;
wire [8:0] maxcnt;
assign b0 = b <= ri;
wire [DMSB+1:0] r1 = b0 ? ri - b : ri;
assign maxcnt = FPWID1*2;

// Done pulse for external circuit. Must span over 1 1x clock so that it's
// recognized.
always_ff @(posedge clk_div)
if (ld)
	done <= 1'b0;
else if (cnt==10'h3FE)
	done <= 1'b1;
else if (cnt==10'h3F7)
	done <= 1'b0;

// Internal done pulse
always_ff @(posedge clk_div)
begin
	done1 <= 1'b0;
	if (ld)
		done1 <= 1'b0;
	else if (cnt==10'h3FF)
		done1 <= 1'b1;
end

always_ff @(posedge clk_div)
if (ld)
	cnt <= {1'b0,maxcnt};
else if (cnt != 10'h3F7)
	cnt <= cnt - 2'd1;

always_ff @(posedge clk_div)
if (ld)
	gotnz <= 1'b0;
else if (!cnt[9]) begin
	if (b0)
		gotnz <= 1'b1;
end

wire cnt81;
delay1 #(1) u1 (clk_div, 1'b1, cnt[9], cnt81);

always_ff @(posedge clk_div)
if (ld)
	lzcnt <= 9'h00;
else if (!cnt81) begin
	if (b0==1'b0 && !gotnz)
		lzcnt <= lzcnt + 1'd1;
end

always_ff @(posedge clk_div)
if (ld)
  qi <= {3'b0,a,{FPWID1{1'b0}}};
else if (!cnt81)
  qi[FPWID1*2-1:0] <= {qi[FPWID1*2-1-1:0],b0};

always_ff @(posedge clk_div)
if (ld)
	ri <= 0;
else if (!cnt81)
  ri <= {r1[DMSB:0],qi[FPWID1*2-1]};

always_ff @(posedge clk_div)
if (done1)
	q <= qi;
always_ff @(posedge clk_div)
if (done1)
	r <= ri;

endmodule


