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

module Qupls_reg_renamer2(rst,clk,en,list2free,tags2free,freevals,
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
output wv0;
output wv1;
output wv2;
output wv3;
output reg [PREGS-1:0] avail;				// recorded in ROB
output reg stall;			// stall enqueue while waiting for register availability

reg [PREGS-1:0] wlist2free;
pregno_t head0, head1, head2, head3;
wire [7:0] o0,o1,o2,o3;
wire [6:0] s0, s1, s2, s3;
wire v0, v1, v2, v3;
wire stalla0;
wire stalla1;
wire stalla2;
wire stalla3;
always_comb stall = stalla0|stalla1|stalla2|stalla3;

Qupls_reg_renamer_fifo #(.FIFONO(0)) ufifo0
(
	.rst(rst),
	.clk(clk),
	.en(en),
	.wlist2free(wlist2free[63:0]),
	.alloc(alloc0),
	.freeval(freevals[0]),// & ~avail[tags2free[0]]), 
	.tag2free(tags2free[0]),
	.o(wo0),
	.ov(wv0),
	.wo(o0),
	.o0(s0),
	.v(v0),
	.stall(stalla0),
	.headreg(head0[7:0])
);

Qupls_reg_renamer_fifo #(.FIFONO(1)) ufifo1
(
	.rst(rst),
	.clk(clk),
	.en(en),
	.wlist2free(wlist2free[127:64]),
	.alloc(alloc1),
	.freeval(freevals[1]),// & ~avail[tags2free[1]]), 
	.tag2free(tags2free[1]),
	.o(wo1),
	.ov(wv1),
	.wo(o1),
	.o0(s1),
	.v(v1),
	.stall(stalla1),
	.headreg(head1[7:0])
);

Qupls_reg_renamer_fifo #(.FIFONO(2)) ufifo2
(
	.rst(rst),
	.clk(clk),
	.en(en),
	.wlist2free(wlist2free[191:128]),
	.alloc(alloc2),
	.freeval(freevals[2]),// & ~avail[tags2free[2]]), 
	.tag2free(tags2free[2]),
	.o(wo2),
	.ov(wv2),
	.wo(o2),
	.o0(s2),
	.v(v2),
	.stall(stalla2),
	.headreg(head2[7:0])
);

Qupls_reg_renamer_fifo #(.FIFONO(3)) ufifo3
(
	.rst(rst),
	.clk(clk),
	.en(en),
	.wlist2free(wlist2free[255:192]),
	.alloc(alloc3),
	.freeval(freevals[3]),// & ~avail[tags2free[3]]), 
	.tag2free(tags2free[3]),
	.o(wo3),
	.ov(wv3),
	.wo(o3),
	.o0(s3),
	.v(v3),
	.stall(stalla3),
	.headreg(head3[7:0])
);

assign head0[9:8] = 2'b0;
assign head1[9:8] = 2'b0;
assign head2[9:8] = 2'b0;
assign head3[9:8] = 2'b0;

always_ff @(posedge clk)
if (rst)
	avail <= {PREGS{1'b0}};
else begin
	if (en) begin

		if (alloc0 & ~stalla0)
			avail[head0] <= 1'b0;
		if (freevals[0])
			avail[tags2free[0]] <= 1'b1;
		else if (v0)
			avail[o0] <= 1'b1;
		
		if (alloc1 & ~stalla1)
			avail[head1] <= 1'b0;
		if (freevals[1])
			avail[tags2free[1]] <= 1'b1;
		else if (v1)
			avail[o1] <= 1'b1;

		if (alloc2 & ~stalla2)
			avail[head2] <= 1'b0;
		if (freevals[2])
			avail[tags2free[2]] <= 1'b1;
		else if (v2)
			avail[o2] <= 1'b1;

		if (alloc3 & ~stalla3)
			avail[head3] <= 1'b0;
		if (freevals[3])
			avail[tags2free[3]] <= 1'b1;
		else if (v3)
			avail[o3] <= 1'b1;
	end
end

// On reset, the fifo is preset full of registers with a mem file.
// Up to four registers may be freed per clock cycle which is okay since only
// four registers may be allocated per clock cycle.

always_ff @(posedge clk)
if (rst)
	wlist2free <= {PREGS{1'b0}};
else begin
	if (en) begin

		wlist2free <= (wlist2free | list2free) & 
			~avail &	// Cannot free available registers
			~({192'd0,{63'd0,v0 & ~freevals[0]} << s0[5:0]}) &
			~({128'd0,{63'd0,v1 & ~freevals[1]} << s1[5:0], 64'd0}) &
			~({64'd0,{63'd0,v2 & ~freevals[2]} << s2[5:0],128'd0}) &
			~({{63'd0,v3 & ~freevals[3]} << s3[5:0],192'd0})
			;
		wlist2free[0] <= 1'b0;
	end
end

endmodule
