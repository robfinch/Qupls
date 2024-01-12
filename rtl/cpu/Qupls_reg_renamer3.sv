// ============================================================================
//        __
//   \\__/ o\    (C) 2014-2024  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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
// Allocate up to four registers per clock.
// We need to be able to free many more registers than are allocated in the 
// event of a pipeline flush. Normally up to four register values will be
// committed to the register file.
//
// 3700 LUTs / 600 FFs
// ============================================================================
//
import QuplsPkg::*;

module Qupls_reg_renamer3(rst,clk,en,list2free,tags2free,freevals,
	alloc0,alloc1,alloc2,alloc3,wo0,wo1,wo2,wo3,wv0,wv1,wv2,wv3,avail,stall);
parameter NFTAGS = 4;
parameter PREGS = 256;
input rst;
input clk;
input en;
input [PREGS-1:0] list2free;
input pregno_t [NFTAGS-1:0] tags2free;		// register tags to free
input [NFTAGS-1:0] freevals;					// bitmnask indicating which tags to free
input alloc0;					// allocate target register 0
input alloc1;
input alloc2;
input alloc3;
output pregno_t wo0;	// target register tag
output pregno_t wo1;
output pregno_t wo2;
output pregno_t wo3;
output reg wv0;
output reg wv1;
output reg wv2;
output reg wv3;
output reg [PREGS-1:0] avail;				// recorded in ROB
output reg stall;			// stall enqueue while waiting for register availability

wire [7:0] o0,o1,o2,o3;
wire [6:0] s0, s1, s2, s3;
wire v0, v1, v2, v3;
reg stalla0;
reg stalla1;
reg stalla2;
reg stalla3;
always_comb stall = stalla0|stalla1|stalla2|stalla3;

always_comb stalla0 = !avail[wo0];
always_comb stalla1 = !avail[wo1];
always_comb stalla2 = !avail[wo2];
always_comb stalla3 = !avail[wo3];
always_comb wv0 = avail[wo0];
always_comb wv1 = avail[wo1];
always_comb wv2 = avail[wo2];
always_comb wv3 = avail[wo3];

Qupls_renamer_srl #(0) usrl0 (
	.rst(rst),
	.clk(clk),
	.en(en),
	.rot(alloc0|stalla0), 
	.o(wo0[7:0])
);

Qupls_renamer_srl #(1) usrl1 (
	.rst(rst),
	.clk(clk),
	.en(en),
	.rot(alloc1|stalla1), 
	.o(wo1[7:0])
);

Qupls_renamer_srl #(2) usrl2 (
	.rst(rst),
	.clk(clk),
	.en(en),
	.rot(alloc2|stalla2), 
	.o(wo2[7:0])
);

Qupls_renamer_srl #(3) usrl3 (
	.rst(rst),
	.clk(clk),
	.en(en),
	.rot(alloc3|stalla3), 
	.o(wo3[7:0])
);

always_comb wo0[9:8] = 2'b00;
always_comb wo1[9:8] = 2'b00;
always_comb wo2[9:8] = 2'b00;
always_comb wo3[9:8] = 2'b00;

always_ff @(posedge clk)
if (rst)
	avail <= {{PREGS-1{1'b1}},1'b0};
else begin
	if (en) begin

		if (alloc0 & ~stalla0)
			avail[wo0] <= 1'b0;
		if (freevals[0])
			avail[tags2free[0]] <= 1'b1;
		
		if (alloc1 & ~stalla1)
			avail[wo1] <= 1'b0;
		if (freevals[1])
			avail[tags2free[1]] <= 1'b1;

		if (alloc2 & ~stalla2)
			avail[wo2] <= 1'b0;
		if (freevals[2])
			avail[tags2free[2]] <= 1'b1;

		if (alloc3 & ~stalla3)
			avail[wo3] <= 1'b0;
		if (freevals[3])
			avail[tags2free[3]] <= 1'b1;
			
		avail <= avail | list2free;
		avail[0] <= 1'b0;
	end
end

endmodule
