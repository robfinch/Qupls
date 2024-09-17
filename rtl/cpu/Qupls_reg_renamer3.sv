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

module Qupls_reg_renamer3(rst,clk,clk5x,en,restore,restore_list,tags2free,freevals,
	alloc0,alloc1,alloc2,alloc3,wo0,wo1,wo2,wo3,wv0,wv1,wv2,wv3,avail,stall);
parameter NFTAGS = 4;
input rst;
input clk;
input clk5x;
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

wire pe_alloc0;
wire pe_alloc1;
wire pe_alloc2;
wire pe_alloc3;
reg rot0 = 1'b0;
reg rot1 = 1'b0;
reg rot2 = 1'b0;
reg rot3 = 1'b0;
reg stalla0 = 1'b0;
reg stalla1 = 1'b0;
reg stalla2 = 1'b0;
reg stalla3 = 1'b0;
reg [PREGS-1:0] next_avail;
always_comb stall = stalla0|stalla1|stalla2|stalla3;

always_comb stalla0 = ~avail[wo0];
always_comb stalla1 = ~avail[wo1];
always_comb stalla2 = ~avail[wo2];
always_comb stalla3 = ~avail[wo3];
always_comb wv0 = avail[wo0];
always_comb wv1 = avail[wo1];
always_comb wv2 = avail[wo2];
always_comb wv3 = avail[wo3];

always_comb rot0 = alloc0;
always_comb rot1 = alloc1;
always_comb rot2 = alloc2;
always_comb rot3 = alloc3;

edge_det ued0 (.rst(rst), .clk(clk5x), .ce(1'b1), .i(alloc0&clk&en), .pe(pe_alloc0), .ne(), .ee());
edge_det ued1 (.rst(rst), .clk(clk5x), .ce(1'b1), .i(alloc1&clk&en), .pe(pe_alloc1), .ne(), .ee());
edge_det ued2 (.rst(rst), .clk(clk5x), .ce(1'b1), .i(alloc2&clk&en), .pe(pe_alloc2), .ne(), .ee());
edge_det ued3 (.rst(rst), .clk(clk5x), .ce(1'b1), .i(alloc3&clk&en), .pe(pe_alloc3), .ne(), .ee());

Qupls_renamer_srl #(0) usrl0 (
	.rst(rst),
	.clk(clk),
	.en(en),
	.rot(rot0), 
	.o(wo0)
);

Qupls_renamer_srl #(1) usrl1 (
	.rst(rst),
	.clk(clk),
	.en(en),
	.rot(rot1), 
	.o(wo1)
);

Qupls_renamer_srl #(2) usrl2 (
	.rst(rst),
	.clk(clk),
	.en(en),
	.rot(rot2), 
	.o(wo2)
);

Qupls_renamer_srl #(3) usrl3 (
	.rst(rst),
	.clk(clk),
	.en(en),
	.rot(rot3), 
	.o(wo3)
);

always_comb
begin
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
	avail <= next_avail;
else begin
	if (en)
		avail <= next_avail;
end

endmodule
