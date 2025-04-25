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
// Allocate up to four registers per clock.
// We need to be able to free many more registers than are allocated in the 
// event of a pipeline flush. Normally up to four register values will be
// committed to the register file.
//
// A bitmap of available registers is used, which is divided into four equal 
// parts. 
// One available register is selected "popped" from each part of the bitmap
// when needed using a find-first-one module.
// The parts of the bitmap are rotated after a register is "popped" so that
// registers are not reused too soon.
// Freeing the register, a "push", is simple, the register is just marked
// available in the bitmap.
// For a checkpoint restore, the available register map is simply copied from
// the checkpoint.
// 
// 3200 LUTs / 300 FFs / 0 BRAMs (256 regs)
// ============================================================================
//
import const_pkg::*;
import cpu_types_pkg::*;
import Stark_pkg::*;

module Stark_reg_name_supplier3(rst,clk,en,restore,restore_list,tags2free,freevals,
	bo_wr, bo_preg, alloc,o,ov,avail,stall,rst_busy
);
parameter NRENAME = 8;
parameter NFTAGS = 4;			// Number of register freed per clock.
input rst;
input clk;
input en;
input restore;
input [PREGS-1:0] restore_list;				// from checkpoint memory, which regs were available
input cpu_types_pkg::pregno_t [NFTAGS-1:0] tags2free;		// register tags to free
input [NFTAGS-1:0] freevals;					// bitmnask indicating which tags to free
input bo_wr;
input pregno_t bo_preg;
input [NRENAME-1:0] alloc;						// allocate target register 0
output cpu_types_pkg::pregno_t [NRENAME-1:0] o;	// target register tag
output reg [NRENAME-1:0] ov = {NRENAME{1'b0}};
output reg [PREGS-1:0] avail = {{PREGS-1{1'b1}},1'b0};
output reg stall;											// stall enqueue while waiting for register availability
output reg rst_busy;									// not used

integer n1,n2,n3,n4,n5,n6,n7;
reg [8:0] kk;
reg [PREGS-1:0] avail1 = {{PREGS-1{1'b1}},1'b0};
reg [NRENAME-1:0] fpop = {NRENAME{1'd0}};
reg [NRENAME-1:0] stalla = {NRENAME{1'b0}};
reg [PREGS-1:0] next_avail;
reg [9:0] rot;
reg [8:0] nam [0:NRENAME-1];
pregno_t [NFTAGS-1:0] tags;
reg [NFTAGS-1:0] fpush;
reg [NRENAME-1:0] oo;

always_comb stall = |stalla;
always_comb rst_busy = 1'b0;

always_comb
if (PREGS != 512 && PREGS != 256 && PREGS != 128) begin
	$display("StarkCPU renamer: number of registers must be 128, 256, or 512");
	$finish;
end

always_comb
	for (n7 = 0; n7 < NRENAME; n7 = n7 + 1)
		fpop[n7] = (alloc[n7] & en & ~stall) | (alloc[n7] & stalla[n7]);

always_comb
begin
	// Not a stall if not allocating.
	for (n1 = 0; n1 < NRENAME; n1 = n1 + 1) begin
		stalla[n1] = ~avail1[o[n1]] & alloc[n1];
		ov[n1] = (avail1[o[n1]] & alloc[n1]);
		// Do not do a pop if stalling on another slot.
		// Do a pop only if allocating
		fpop[n1] = (alloc[n1] & en & ~stall) | (alloc[n1] & stalla[n1]);
	end
	/*
	if (o0==o1) begin stalla1 = TRUE; ov1 = FALSE; end
	if (o0==o2) begin stalla2 = TRUE; ov2 = FALSE; end
	if (o0==o3) begin stalla3 = TRUE; ov3 = FALSE; end
	if (o1==o2) begin stalla2 = TRUE; ov2 = FALSE; end
	if (o1==o3) begin stalla3 = TRUE; ov3 = FALSE; end
	if (o2==o3) begin stalla3 = TRUE; ov3 = FALSE; end
	*/
end

reg [$clog2(PREGS)-3:0] freeCnt;
reg [PREGS-1:0] next_toFreeList;
reg [PREGS-1:0] toFreeList;
always_comb
	avail1 = restore ? restore_list : avail;

// Refuse to put 0 onto the stack. 0 is specially reserved.
always_comb
begin
	for (n5 = 0; n5 < NFTAGS; n5 = n5 + 1)
		fpush[n5] = tags2free[n5]==9'd0 ? 1'b0 : freevals[n5];
end

always_comb
begin
	for (n6 = 0; n6 < NFTAGS; n6 = n6 + 1)
		tags[n6] = fpush[n6] ? tags2free[n6] : 9'd0;
end

// The following checks should always fail as it is not possible in properly
// running hardware to get the same register on a different port.
always_comb
if (0) begin
	if (o[0]==o[1] || o[0]==o[2] || o[0]==o[3]) begin
		$display("StarkCPU: matching rename registers");
		$finish;
	end
	if (o[1]==o[2] || o[1]==o[3]) begin
		$display("StarkCPU: matching rename registers");
		$finish;
	end
	if (o[2]==o[3]) begin
		$display("StarkCPU: matching rename registers");
		$finish;
	end
end

wire [7:0] ffo [0:7];
reg [$clog2(PREGS)-3:0] rotcnt [0:7];
reg [511:0] avail_rot;

always_comb avail_rot[127:  0] = (avail[127:  0] << rotcnt[0]) | (avail[127:  0] >> (128-rotcnt[0]));
always_comb avail_rot[255:128] = (avail[255:128] << rotcnt[1]) | (avail[255:128] >> (128-rotcnt[1]));
always_comb avail_rot[383:356] = (avail[383:256] << rotcnt[2]) | (avail[383:256] >> (128-rotcnt[2]));
always_comb avail_rot[511:384] = (avail[511:384] << rotcnt[3]) | (avail[511:384] >> (128-rotcnt[3]));

ffo144 uffo0 (.i({16'd0,avail_rot[127:  0]}), .o(ffo[0]));
ffo144 uffo1 (.i({16'd0,avail_rot[127:  0] & ~(128'd1 << ffo[0])}), .o(ffo[1]));
ffo144 uffo2 (.i({16'd0,avail_rot[255:128]}), .o(ffo[2]));
ffo144 uffo3 (.i({16'd0,avail_rot[255:128]} & ~(128'd1 << ffo[2])), .o(ffo[3]));
ffo144 uffo4 (.i({16'd0,avail_rot[383:256]}), .o(ffo[4]));
ffo144 uffo5 (.i({16'd0,avail_rot[383:256]} & ~(128'd1 << ffo[4])), .o(ffo[5]));
ffo144 uffo6 (.i({16'd0,avail_rot[511:384]}), .o(ffo[6]));
ffo144 uffo7 (.i({16'd0,avail_rot[511:384]} & ~(128'd1 << ffo[6])), .o(ffo[7]));

always_comb nam[0] = {2'd0,ffo[0][6:0]+rotcnt[0][6:0]};
always_comb nam[1] = {2'd0,ffo[1][6:0]+rotcnt[0][6:0]};
always_comb nam[2] = {2'd1,ffo[2][6:0]+rotcnt[1][6:0]};
always_comb nam[3] = {2'd1,ffo[3][6:0]+rotcnt[1][6:0]};
always_comb nam[4] = {2'd2,ffo[3][6:0]+rotcnt[2][6:0]};
always_comb nam[5] = {2'd2,ffo[3][6:0]+rotcnt[2][6:0]};
always_comb nam[6] = {2'd3,ffo[3][6:0]+rotcnt[3][6:0]};
always_comb nam[7] = {2'd3,ffo[3][6:0]+rotcnt[3][6:0]};

always_ff @(posedge clk)
if (rst) begin
	rotcnt[0] <= 7'd0;
	rotcnt[1] <= 7'd0;
	rotcnt[2] <= 7'd0;
	rotcnt[3] <= 7'd0;
	rotcnt[4] <= 7'd0;
	rotcnt[5] <= 7'd0;
	rotcnt[6] <= 7'd0;
	rotcnt[7] <= 7'd0;
end
else begin
	rotcnt[0] <= rotcnt[0] + fpop[0] + fpop[1];
	rotcnt[1] <= rotcnt[1] + fpop[2] + fpop[3];
	rotcnt[2] <= rotcnt[2] + fpop[4] + fpop[5];
	rotcnt[3] <= rotcnt[3] + fpop[6] + fpop[7];
	rotcnt[4] <= rotcnt[4] + fpop[4];
	rotcnt[5] <= rotcnt[5] + fpop[5];
	rotcnt[6] <= rotcnt[6] + fpop[6];
	rotcnt[7] <= rotcnt[7] + fpop[7];
end

always_comb
begin
	if (restore)
		next_avail = restore_list;
	else
		next_avail = avail;

//	oo = {NRENAME{1'b0}};
	for (n3 = 0; n3 < NRENAME; n3 = n3 + 1) begin
		o[n3] = nam[n3];
		next_avail[nam[n3]] = 1'b0;
		/*
		if (alloc[n3] & en) begin
			for (n4 = 0; n4 < PREGS; n4 = n4 + 1) begin
				kk = (n4+rot)%PREGS;
				if (next_avail[kk] && oo[n3]==1'b0) begin
					o[n3] = kk;
					oo[n3] = 1'b1;
					next_avail[kk] = 1'b0;
				end
			end
		end
		*/
	end
	for (n3 = NRENAME; n3 < 8; n3 = n3 + 1)
		o[n3] = 9'd0;
		
	for (n3 = 0; n3 < NFTAGS; n3 = n3 + 1)
		if (fpush[n3]) next_avail[tags[n3]] = 1'b1;	

	if (bo_wr) next_avail[bo_preg] = 1'b0;

	next_avail[0] = 1'b0;
end

always_ff @(posedge clk)
if (rst)
	avail <= {{PREGS-1{1'b1}},1'b0};
else begin
	avail <= next_avail;
end

always_ff @(posedge clk)
if (rst)
	rot <= 9'd0;
else begin
	rot <= (rot + 3'd5) % PREGS;
end

endmodule
