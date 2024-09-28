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
// 8500 LUTs / 800 FFs / 2 BRAMs
// ============================================================================
//
import QuplsPkg::*;

module Qupls_reg_renamer4(rst,clk,en,restore,restore_list,tags2free,freevals,
	alloc0,alloc1,alloc2,alloc3,wo0,wo1,wo2,wo3,wv0,wv1,wv2,wv3,avail,stall,rst_busy);
parameter NFTAGS = 4;
input rst;
input clk;
input en;
input restore;
input [PREGS-1:0] restore_list;
input cpu_types_pkg::pregno_t [NFTAGS-1:0] tags2free;		// register tags to free
input [NFTAGS-1:0] freevals;					// bitmnask indicating which tags to free
input alloc0;					// allocate target register 0
input alloc1;
input alloc2;
input alloc3;
output cpu_types_pkg::pregno_t wo0;	// target register tag
output cpu_types_pkg::pregno_t wo1;
output cpu_types_pkg::pregno_t wo2;
output cpu_types_pkg::pregno_t wo3;
output reg wv0 = 1'b0;
output reg wv1 = 1'b0;
output reg wv2 = 1'b0;
output reg wv3 = 1'b0;
output reg [PREGS-1:0] avail = {{PREGS-1{1'b1}},1'b0};				// recorded in ROB
output reg stall;			// stall enqueue while waiting for register availability
output reg rst_busy;

reg pop0 = 1'b0;
reg pop1 = 1'b0;
reg pop2 = 1'b0;
reg pop3 = 1'b0;
reg push0 = 1'b0;
reg push1 = 1'b0;
reg push2 = 1'b0;
reg push3 = 1'b0;
reg stalla0 = 1'b0;
reg stalla1 = 1'b0;
reg stalla2 = 1'b0;
reg stalla3 = 1'b0;
reg alloc0d;
reg alloc1d;
reg alloc2d;
reg alloc3d;
reg [PREGS-1:0] next_avail;

wire rst_busy0;
wire rst_busy1;
wire rst_busy2;
wire rst_busy3;
wire empty0;
wire empty1;
wire empty2;
wire empty3;
pregno_t [3:0] tags;
reg [3:0] fpush;

always_comb rst_busy = rst_busy0|rst_busy1|rst_busy2|rst_busy3;
always_comb stall = stalla0|stalla1|stalla2|stalla3;

// Not a stall if not allocating.
always_comb stalla0 = ~avail[wo0] & alloc0;
always_comb stalla1 = ~avail[wo1] & alloc1;
always_comb stalla2 = ~avail[wo2] & alloc2;
always_comb stalla3 = ~avail[wo3] & alloc3;
always_comb wv0 = avail[wo0] & alloc0;
always_comb wv1 = avail[wo1] & alloc1;
always_comb wv2 = avail[wo2] & alloc2;
always_comb wv3 = avail[wo3] & alloc3;

always_comb pop0 = alloc0 & en;
always_comb pop1 = alloc1 & en;
always_comb pop2 = alloc2 & en;
always_comb pop3 = alloc3 & en;

reg [1:0] fifo_order;

always_comb
case(fifo_order)
2'd0:
	begin
		fpush[0] = freevals[0] & en;
		fpush[1] = freevals[1] & en;
		fpush[2] = freevals[2] & en;
		fpush[3] = freevals[3] & en;
		tags[0] = tags2free[0];
		tags[1] = tags2free[1];
		tags[2] = tags2free[2];
		tags[3] = tags2free[3];
	end
2'd1:
	begin
		fpush[0] = freevals[1] & en;
		fpush[1] = freevals[2] & en;
		fpush[2] = freevals[3] & en;
		fpush[3] = freevals[0] & en;
		tags[0] = tags2free[1];
		tags[1] = tags2free[2];
		tags[2] = tags2free[3];
		tags[3] = tags2free[0];
	end
2'd2:
	begin
		fpush[0] = freevals[2] & en;
		fpush[1] = freevals[3] & en;
		fpush[2] = freevals[0] & en;
		fpush[3] = freevals[1] & en;
		tags[0] = tags2free[2];
		tags[1] = tags2free[3];
		tags[2] = tags2free[0];
		tags[3] = tags2free[1];
	end
2'd3:
	begin
		fpush[0] = freevals[3] & en;
		fpush[1] = freevals[0] & en;
		fpush[2] = freevals[1] & en;
		fpush[3] = freevals[2] & en;
		tags[0] = tags2free[3];
		tags[1] = tags2free[0];
		tags[2] = tags2free[1];
		tags[3] = tags2free[2];
	end
endcase

Qupls_renamer_fifo #(0) ufifo0 (
	.rst(rst),
	.clk(clk),
	.push(fpush[0]), 
	.pop(pop0),
	.o(wo0),
	.i(tags[0]),
	.empty(empty0),
	.rst_busy(rst_busy0)
);

Qupls_renamer_fifo #(1) ufifo1 (
	.rst(rst),
	.clk(clk),
	.push(fpush[1]), 
	.pop(pop1),
	.i(tags[1]),
	.o(wo1),
	.empty(empty1),
	.rst_busy(rst_busy1)
);

Qupls_renamer_fifo #(2) ufifo2 (
	.rst(rst),
	.clk(clk),
	.push(fpush[2]), 
	.pop(pop2),
	.i(tags[2]),
	.o(wo2),
	.empty(empty2),
	.rst_busy(rst_busy2)
);

Qupls_renamer_fifo #(3) ufifo3 (
	.rst(rst),
	.clk(clk),
	.push(fpush[3]), 
	.pop(pop3),
	.i(tags[3]),
	.o(wo3),
	.empty(empty3),
	.rst_busy(rst_busy3)
);

always_comb
if (0) begin
	if (wo0==wo1 || wo0==wo2 || wo0==wo3) begin
		$display("Q+: matching rename registers");
		$finish;
	end
	if (wo1==wo2 || wo1==wo3) begin
		$display("Q+: matching rename registers");
		$finish;
	end
	if (wo2==wo3) begin
		$display("Q+: matching rename registers");
		$finish;
	end
end

always_comb
if (rst) begin
	next_avail = {{PREGS-1{1'b1}},1'b0};
	next_avail[0] = 1'b0;
	next_avail[PREGS/4] = 1'b0;
	next_avail[PREGS/2] = 1'b0;
	next_avail[PREGS*3/4] = 1'b0;
end
else begin
	
	next_avail = avail;

	if (alloc0 & avail[wo0])
		next_avail[wo0] = 1'b0;
	if (freevals[0])
		next_avail[tags2free[0]] = 1'b1;
	
	if (alloc1 & avail[wo1])
		next_avail[wo1] = 1'b0;
	if (freevals[1])
		next_avail[tags2free[1]] = 1'b1;

	if (alloc2 & avail[wo2])
		next_avail[wo2] = 1'b0;
	if (freevals[2])
		next_avail[tags2free[2]] = 1'b1;

	if (alloc3 & avail[wo3])
		next_avail[wo3] = 1'b0;
	if (freevals[3])
		next_avail[tags2free[3]] = 1'b1;

	if (restore)
		next_avail = restore_list;
	next_avail[0] = 1'b0;
	next_avail[PREGS/4] = 1'b0;
	next_avail[PREGS/2] = 1'b0;
	next_avail[PREGS*3/4] = 1'b0;
end

always_ff @(posedge clk)
if (rst)
	fifo_order <= 2'd0;
else
	fifo_order <= fifo_order + push0 + push1 + push2 + push3;

always_ff @(posedge clk) if (rst) alloc0d <= 1'b0; else if(en) alloc0d <= alloc0;
always_ff @(posedge clk) if (rst) alloc1d <= 1'b0; else if(en) alloc1d <= alloc1;
always_ff @(posedge clk) if (rst) alloc2d <= 1'b0; else if(en) alloc2d <= alloc2;
always_ff @(posedge clk) if (rst) alloc3d <= 1'b0; else if(en) alloc3d <= alloc3;

always_ff @(posedge clk)
if (rst)
	avail <= next_avail;
else begin
	if (en)
		avail <= next_avail;
end

endmodule
