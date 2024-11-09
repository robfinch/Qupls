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
// 7150 LUTs / 1300 FFs / 2 BRAMs
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
output reg [PREGS-1:0] avail = {1'b0,{PREGS-2{1'b1}},1'b0};				// recorded in ROB
output reg stall;			// stall enqueue while waiting for register availability
output reg rst_busy;

reg pop0 = 1'b0;
reg pop1 = 1'b0;
reg pop2 = 1'b0;
reg pop3 = 1'b0;
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
reg wv0r;
reg wv1r;
reg wv2r;
reg wv3r;
reg stallwo0;
reg stallwo1;
reg stallwo2;
reg stallwo3;

always_comb rst_busy = rst_busy0|rst_busy1|rst_busy2|rst_busy3;
always_comb stall = stalla0|stalla1|stalla2|stalla3;

always_comb
begin
	// Not a stall if not allocating.
	stalla0 = ~avail[wo0] | (empty0 & alloc0);
	stalla1 = ~avail[wo1] | (empty1 & alloc1);
	stalla2 = ~avail[wo2] | (empty2 & alloc2);
	stalla3 = ~avail[wo3] | (empty3 & alloc3);
	wv0 = (avail[wo0] & alloc0) | wv0r;// & ~empty0;
	wv1 = (avail[wo1] & alloc1) | wv1r;// & ~empty1;
	wv2 = (avail[wo2] & alloc2) | wv2r;// & ~empty2;
	wv3 = (avail[wo3] & alloc3) | wv3r;// & ~empty3;
	if (wo0==wo1) begin stalla1 = TRUE; wv1 = FALSE; end
	if (wo0==wo2) begin stalla2 = TRUE; wv2 = FALSE; end
	if (wo0==wo3) begin stalla3 = TRUE; wv3 = FALSE; end
	if (wo1==wo2) begin stalla2 = TRUE; wv2 = FALSE; end
	if (wo1==wo3) begin stalla3 = TRUE; wv3 = FALSE; end
	if (wo2==wo3) begin stalla3 = TRUE; wv3 = FALSE; end
end

// Do not do a pop if stalling on another slot.
always_comb pop0 = (alloc0 & en & ~stall) | (stalla0|empty0);
always_comb pop1 = (alloc1 & en & ~stall) | (stalla1|empty1);
always_comb pop2 = (alloc2 & en & ~stall) | (stalla2|empty2);
always_comb pop3 = (alloc3 & en & ~stall) | (stalla3|empty3);

reg [3:0] freevals1;
reg [$clog2(PREGS)-3:0] freeCnt;
reg [2:0] ffreeCnt;
reg [PREGS-1:0] next_toFreeList;
reg [PREGS-1:0] toFreeList;
reg [3:0] ffree;

always_ff @(posedge clk)
begin
	if (en) begin
		wv0r <= 1'b0;
		wv1r <= 1'b0;
		wv2r <= 1'b0;
		wv3r <= 1'b0;
	end
	else begin
		wv0r <= wv0;
		wv1r <= wv1;
		wv2r <= wv2;
		wv3r <= wv3;
	end
end

generate begin : gRenamer
if (PREGS==512) begin
	// Refuse to put 0 onto the stack. 0 is specially reserved.
	// If the tag is already free, refuse to place on stack.
	always_comb
	begin
		freevals1[0] = tags2free[0]==9'd0 ? 1'b0 : freevals[0];
		freevals1[1] = tags2free[1]==9'd0 ? 1'b0 : freevals[1];
		freevals1[2] = tags2free[2]==9'd0 ? 1'b0 : freevals[2];
		freevals1[3] = tags2free[3]==9'd0 ? 1'b0 : freevals[3];
	end

	always_comb
	begin
		tags[0] = 9'd0;
		tags[1] = 9'd0;
		tags[2] = 9'd0;
		tags[3] = 9'd0;
		if (freevals1[0]) begin
			if (tags2free[0][8:7]==2'd0) tags[0] = tags2free[0];
			if (tags2free[0][8:7]==2'd1) tags[1] = tags2free[0];
			if (tags2free[0][8:7]==2'd2) tags[2] = tags2free[0];
			if (tags2free[0][8:7]==2'd3) tags[3] = tags2free[0];
		end
		if (freevals1[1]) begin
			if (tags2free[1][8:7]==2'd0) tags[0] = tags2free[1];
			if (tags2free[1][8:7]==2'd1) tags[1] = tags2free[1];
			if (tags2free[1][8:7]==2'd2) tags[2] = tags2free[1];
			if (tags2free[1][8:7]==2'd3) tags[3] = tags2free[1];
		end
		if (freevals1[2]) begin
			if (tags2free[2][8:7]==2'd0) tags[0] = tags2free[2];
			if (tags2free[2][8:7]==2'd1) tags[1] = tags2free[2];
			if (tags2free[2][8:7]==2'd2) tags[2] = tags2free[2];
			if (tags2free[2][8:7]==2'd3) tags[3] = tags2free[2];
		end
		if (freevals1[3]) begin
			if (tags2free[3][8:7]==2'd0) tags[0] = tags2free[3];
			if (tags2free[3][8:7]==2'd1) tags[1] = tags2free[3];
			if (tags2free[3][8:7]==2'd2) tags[2] = tags2free[3];
			if (tags2free[3][8:7]==2'd3) tags[3] = tags2free[3];
		end
		if (tags[0]==9'd0 && ffree[0])
			tags[0] = freeCnt + 000;
		if (tags[1]==9'd0 && ffree[1])
			tags[1] = freeCnt + 128;
		if (tags[2]==9'd0 && ffree[2])
			tags[2] = freeCnt + 256;
		if (tags[3]==9'd0 && ffree[3])
			tags[3] = freeCnt + 384;
		fpush[0] = |tags[0] ? ~avail[tags[0]] : 1'b0;
		fpush[1] = |tags[1] ? ~avail[tags[1]] : 1'b0;
		fpush[2] = |tags[2] ? ~avail[tags[2]] : 1'b0;
		fpush[3] = |tags[3] ? ~avail[tags[3]] : 1'b0;
	end
	always_comb
	if (rst) begin
		ffree[0] <= 1'b0;
		ffree[1] <= 1'b0;
		ffree[2] <= 1'b0;
		ffree[3] <= 1'b0;
	end
	else begin
		ffree[0] <= freeCnt!=9'd0 ? toFreeList[freeCnt] : 1'b0;
		ffree[1] <= toFreeList[9'd128+freeCnt];
		ffree[2] <= toFreeList[9'd256+freeCnt];
		ffree[3] <= toFreeList[9'd384+freeCnt];
	end

end
else begin
	// Refuse to put 0 onto the stack. 0 is specially reserved.
	// If the tag is already free, refuse to place on stack.
	always_comb
	begin
		freevals1[0] = tags2free[0]==8'd0 ? 1'b0 : freevals[0];
		freevals1[1] = tags2free[1]==8'd0 ? 1'b0 : freevals[1];
		freevals1[2] = tags2free[2]==8'd0 ? 1'b0 : freevals[2];
		freevals1[3] = tags2free[3]==8'd0 ? 1'b0 : freevals[3];
	end
	always_comb
	begin
		tags[0] = 8'd0;
		tags[1] = 8'd0;
		tags[2] = 8'd0;
		tags[3] = 8'd0;
		if (freevals1[0]) begin
			if (tags2free[0][8:7]==2'd0) tags[0] = tags2free[0];
			if (tags2free[0][8:7]==2'd1) tags[1] = tags2free[0];
			if (tags2free[0][8:7]==2'd2) tags[2] = tags2free[0];
			if (tags2free[0][8:7]==2'd3) tags[3] = tags2free[0];
		end
		if (freevals1[1]) begin
			if (tags2free[1][8:7]==2'd0) tags[0] = tags2free[1];
			if (tags2free[1][8:7]==2'd1) tags[1] = tags2free[1];
			if (tags2free[1][8:7]==2'd2) tags[2] = tags2free[1];
			if (tags2free[1][8:7]==2'd3) tags[3] = tags2free[1];
		end
		if (freevals1[2]) begin
			if (tags2free[2][8:7]==2'd0) tags[0] = tags2free[2];
			if (tags2free[2][8:7]==2'd1) tags[1] = tags2free[2];
			if (tags2free[2][8:7]==2'd2) tags[2] = tags2free[2];
			if (tags2free[2][8:7]==2'd3) tags[3] = tags2free[2];
		end
		if (freevals1[3]) begin
			if (tags2free[3][8:7]==2'd0) tags[0] = tags2free[3];
			if (tags2free[3][8:7]==2'd1) tags[1] = tags2free[3];
			if (tags2free[3][8:7]==2'd2) tags[2] = tags2free[3];
			if (tags2free[3][8:7]==2'd3) tags[3] = tags2free[3];
		end
		if (tags[0]==8'd0 && ffree[0])
			tags[0] = freeCnt;
		if (tags[1]==8'd0 && ffree[1])
			tags[1] = freeCnt + 64;
		if (tags[2]==8'd0 && ffree[2])
			tags[2] = freeCnt + 128;
		if (tags[3]==8'd0 && ffree[3])
			tags[3] = freeCnt + 192;
		fpush[0] = |tags[0] ? ~avail[tags[0]] : 1'b0;
		fpush[1] = |tags[1] ? ~avail[tags[1]] : 1'b0;
		fpush[2] = |tags[2] ? ~avail[tags[2]] : 1'b0;
		fpush[3] = |tags[3] ? ~avail[tags[3]] : 1'b0;
	end
	always_comb
	if (rst) begin
		ffree[0] <= 1'b0;
		ffree[1] <= 1'b0;
		ffree[2] <= 1'b0;
		ffree[3] <= 1'b0;
	end
	else begin
		ffree[0] <= freeCnt!=9'd0 ? toFreeList[freeCnt] : 1'b0;
		ffree[1] <= toFreeList[8'd64+freeCnt];
		ffree[2] <= toFreeList[8'd128+freeCnt];
		ffree[3] <= toFreeList[8'd192+freeCnt];
	end
end
end
endgenerate


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
	next_avail = {{PREGS-1{1'b0}},1'b0};
	next_avail[0] = 1'b0;
	next_avail[PREGS-1] = 1'b0;
end
else begin

	if (restore)
		next_avail = restore_list;
	else	
		next_avail = avail;

	if (wv0 & en) next_avail[wo0] = 1'b0;
	if (wv1 & en) next_avail[wo1] = 1'b0;
	if (wv2 & en) next_avail[wo2] = 1'b0;
	if (wv3 & en) next_avail[wo3] = 1'b0;

	if (fpush[0]) next_avail[tags[0]] = 1'b1;// | (512'd1 << tags[0]);//((freeCnt + 3'd0) % 512));
	if (fpush[1]) next_avail[tags[1]] = 1'b1;// | (512'd1 << tags[1]);//((freeCnt + 3'd1) % 512));
	if (fpush[2]) next_avail[tags[2]] = 1'b1;// | (512'd1 << tags[2]);//((freeCnt + 3'd2) % 512));
	if (fpush[3]) next_avail[tags[3]] = 1'b1;// | (512'd1 << tags[3]);//((freeCnt + 3'd3) % 512));

	next_avail[0] = 1'b0;
end

always_ff @(posedge clk)
	avail <= next_avail;

reg [2:0] pushCnt, nFree;
always_comb
	pushCnt = fpush[0] + fpush[1] + fpush[2] + fpush[3];
always_comb
	ffreeCnt = (ffree[0] & ~(freevals1[0])) +
						 (ffree[1] & ~(freevals1[1])) +
						 (ffree[2] & ~(freevals1[2])) +
						 (ffree[3] & ~(freevals1[3]))
						 ;

always_ff @(posedge clk) if (rst) alloc0d <= 1'b0; else if(en) alloc0d <= alloc0;
always_ff @(posedge clk) if (rst) alloc1d <= 1'b0; else if(en) alloc1d <= alloc1;
always_ff @(posedge clk) if (rst) alloc2d <= 1'b0; else if(en) alloc2d <= alloc2;
always_ff @(posedge clk) if (rst) alloc3d <= 1'b0; else if(en) alloc3d <= alloc3;

always_ff @(posedge clk)
if (rst)
	freeCnt <= 7'd0;
else
	freeCnt <= freeCnt + 7'd1;

always_comb
begin
	next_toFreeList = toFreeList;
	if (restore)
		next_toFreeList = restore_list;//next_toFreeList;// | (restore_list & ~avail);
	if (empty0) next_toFreeList = next_toFreeList | avail[PREGS/4-1:0];
	if (empty1) next_toFreeList = next_toFreeList | avail[PREGS/2-1:PREGS/4];
	if (empty2) next_toFreeList = next_toFreeList | avail[PREGS*3/4-1:PREGS/2];
	if (empty3) next_toFreeList = next_toFreeList | avail[PREGS-1:PREGS*3/4];
	if (fpush[0])	next_toFreeList[tags[0]] = 1'b0;
 	if (fpush[1])	next_toFreeList[tags[1]] = 1'b0;
 	if (fpush[2])	next_toFreeList[tags[2]] = 1'b0;
 	if (fpush[3])	next_toFreeList[tags[3]] = 1'b0;
end

always_ff @(posedge clk)
if (rst) begin
	toFreeList <= {PREGS{1'b1}};
	toFreeList[0] <= 1'b0;
	toFreeList[PREGS-1] <= 1'b0;
end
else
	toFreeList <= next_toFreeList;

endmodule
