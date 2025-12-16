// ============================================================================
//        __
//   \\__/ o\    (C) 2024-2025  Robert Finch, Waterloo
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
//
// ============================================================================
//
import const_pkg::*;
import Qupls4_pkg::*;

module Qupls4_checkpoint_allocator(rst, clk, clk5x, ph4, alloc_chkpt, br, chkptn,
	free_chkpt_i, fchkpt_i, free_chkpt2, fchkpt2, chkpts_to_free, stall);
// GROUP_ALLOC if (TRUE) allocates a single checkpoint for the instruction group.
parameter GROUP_ALLOC = 1'b1;
input rst;
input clk;
input clk5x;
input [4:0] ph4;
input alloc_chkpt;
input [3:0] br;
output checkpt_ndx_t [3:0] chkptn;
input [3:0] free_chkpt_i;
input checkpt_ndx_t [3:0] fchkpt_i;
input [3:0] free_chkpt2;
input checkpt_ndx_t [3:0] fchkpt2;
input [Qupls4_pkg::NCHECK-1:0] chkpts_to_free;
output reg stall;

reg [Qupls4_pkg::NCHECK-1:0] avail_chkpts [0:3];
reg [$clog2(Qupls4_pkg::NCHECK):0] avail_chkpt [0:3];
reg [2:0] wcnt;
checkpt_ndx_t head_chkpt;

always_ff @(posedge clk5x)
if (rst)
	wcnt <= 3'd0;
else begin
	if (ph4[1])
		wcnt <= 3'd0;
	else if (wcnt < 3'd4)
		wcnt <= wcnt + 2'd1;
end

// Checkpoint allocator / deallocator
// A bitmap is used indicating which checkpoints are available. When a branch
// is detected at decode stage a checkpoint is allocated for it. When the
// branch resolves during execution, the checkpoint is freed. Only on branch
// executes at a time so only a single checkpoint needs to be freed per clock.
// Multiple branches may be decoded in the same instruction group.

generate begin : gAvail
if (Qupls4_pkg::NCHECK==16)
flo24 uflo0 (.i(avail_chkpts[0]), .o(avail_chkpt[0]));
else if (Qupls4_pkg::NCHECK==32)
flo48 uflo0 (.i(avail_chkpts[0]), .o(avail_chkpt[0]));
end
endgenerate

always_comb
begin
	avail_chkpts[1] = avail_chkpts[0];
	avail_chkpts[1][avail_chkpt[0]] = 1'b0;	
end
flo24 uflo1 (.i({8'd0,avail_chkpts[1]}), .o(avail_chkpt[1]));
always_comb
begin
	avail_chkpts[2] = avail_chkpts[1];
	avail_chkpts[2][avail_chkpt[1]] = 1'b0;	
end
flo24 uflo2 (.i({8'd0,avail_chkpts[2]}), .o(avail_chkpt[2]));
always_comb
begin
	avail_chkpts[3] = avail_chkpts[2];
	avail_chkpts[3][avail_chkpt[2]] = 1'b0;	
end
flo24 uflo3 (.i({8'd0,avail_chkpts[3]}), .o(avail_chkpt[3]));

generate begin : gAlloc
if (GROUP_ALLOC) begin
	always_ff @(posedge clk)
	if (rst) begin
		avail_chkpts[0] <= {{Qupls4_pkg::NCHECK-1{1'b1}},1'b0};
		head_chkpt <= 4'd1;
		chkptn[0] <= 4'd0;
	end
	else begin
		if (alloc_chkpt) begin
			chkptn[0] <= avail_chkpt[0];
			avail_chkpts[avail_chkpt[0]] <= 1'b0;
			/*
			chkptn[0] <= head_chkpt;
			avail_chkpts[0][head_chkpt] <= 1'b0;
			head_chkpt <= head_chkpt + 2'd1;
			*/
		end
		// Try and find a free checkpoint
//		else if (stall)
//			head_chkpt <= head_chkpt + 2'd1;
//		if (free_chkpt_i[0])
//			avail_chkpts[0][fchkpt_i[0]] <= 1'b1;
//		if (free_chkpt2[0])
//			avail_chkpts[0][fchkpt2[0]] <= 1'b1;
		avail_chkpts[0] <= avail_chkpts[0] | chkpts_to_free;
		avail_chkpts[0][0] <= 1'b0;
	end
	always_comb chkptn[1] = chkptn[0];
	always_comb chkptn[2] = chkptn[0];
	always_comb chkptn[3] = chkptn[0];
	// Stall if no checkpoint available
	always_comb stall = &avail_chkpt[0];//[head_chkpt]==1'b0;
/*
	always_ff @(posedge clk)
	if (rst)
		avail_chkpts[0] <= {{NCHECK-1{1'b1}},1'b0};
	else begin
		if (alloc_chkpt)
			avail_chkpts[0][avail_chkpt[0]] <= 1'b0;
		else begin
			if (free_chkpt_i[0])
				avail_chkpts[0][fchkpt_i[0]] <= 1'b1;
			if (free_chkpt2[0])
				avail_chkpts[0][fchkpt2[0]] <= 1'b1;
		end
	end
	always_comb chkptn[0] = avail_chkpt[0];
	always_comb chkptn[1] = avail_chkpt[0];
	always_comb chkptn[2] = avail_chkpt[0];
	always_comb chkptn[3] = avail_chkpt[0];
	always_comb stall = avail_chkpt[0]==5'd31;
*/
end
else begin
	always_ff @(posedge clk5x)
	if (rst)
		avail_chkpts[0] <= {{Qupls4_pkg::NCHECK-1{1'b1}},1'b0};
	else begin
		if (alloc_chkpt) begin
			if (wcnt < 3'd4) begin
				if (br[wcnt]) begin
					chkptn[wcnt] <= avail_chkpt[wcnt];
					avail_chkpts[0][avail_chkpt[wcnt]] <= 1'b0;
				end
			end
		end
		else begin
			if (wcnt < 3'd4) begin
				if (free_chkpt_i[wcnt])
					avail_chkpts[0][fchkpt_i[wcnt]] <= 1'b1;
				if (free_chkpt2[wcnt])
					avail_chkpts[0][fchkpt2[wcnt]] <= 1'b1;
			end
		end
	end
	always_comb chkptn[0] = avail_chkpt[0];
	always_comb chkptn[1] = avail_chkpt[1];
	always_comb chkptn[2] = avail_chkpt[2];
	always_comb chkptn[3] = avail_chkpt[3];
	always_comb stall = &avail_chkpt[3];
end
end
endgenerate

endmodule
