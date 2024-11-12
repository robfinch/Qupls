// ============================================================================
//        __
//   \\__/ o\    (C) 2024  Robert Finch, Waterloo
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
import QuplsPkg::*;

module Qupls_reg_name_supplier(rst,clk,en,restore,restore_list,tags2free,freevals,
	bo_wr, bo_preg,
	alloc0,alloc1,alloc2,alloc3,o0,o1,o2,o3,ov0,ov1,ov2,ov3,avail,stall,rst_busy
);
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
input alloc0;													// allocate target register 0
input alloc1;
input alloc2;
input alloc3;
output cpu_types_pkg::pregno_t o0;		// target register tag
output cpu_types_pkg::pregno_t o1;
output cpu_types_pkg::pregno_t o2;
output cpu_types_pkg::pregno_t o3;
output reg ov0 = 1'b0;
output reg ov1 = 1'b0;
output reg ov2 = 1'b0;
output reg ov3 = 1'b0;
output reg [PREGS-1:0] avail = {{PREGS-1{1'b1}},1'b0};
output reg stall;											// stall enqueue while waiting for register availability
output reg rst_busy;									// not used

reg [PREGS-1:0] avail1 = {{PREGS-1{1'b1}},1'b0};
reg [3:0] fpop = 4'd0;
reg stalla0 = 1'b0;
reg stalla1 = 1'b0;
reg stalla2 = 1'b0;
reg stalla3 = 1'b0;
reg [PREGS-1:0] next_avail;

pregno_t [3:0] tags;
reg [3:0] fpush;
reg ov0r;
reg ov1r;
reg ov2r;
reg ov3r;

always_comb stall = stalla0|stalla1|stalla2|stalla3;
always_comb rst_busy = 1'b0;

always_comb
if (PREGS != 512 && PREGS != 256 && PREGS != 128) begin
	$display("Q+ renamer: number of registers must be 128, 256, or 512");
	$finish;
end

always_comb
begin
	// Not a stall if not allocating.
	stalla0 = ~avail1[o0] & alloc0;
	stalla1 = ~avail1[o1] & alloc1;
	stalla2 = ~avail1[o2] & alloc2;
	stalla3 = ~avail1[o3] & alloc3;
	ov0 = (avail1[o0] & alloc0) | (ov0r & ~en);
	ov1 = (avail1[o1] & alloc1) | (ov1r & ~en);
	ov2 = (avail1[o2] & alloc2) | (ov2r & ~en);
	ov3 = (avail1[o3] & alloc3) | (ov3r & ~en);
	if (o0==o1) begin stalla1 = TRUE; ov1 = FALSE; end
	if (o0==o2) begin stalla2 = TRUE; ov2 = FALSE; end
	if (o0==o3) begin stalla3 = TRUE; ov3 = FALSE; end
	if (o1==o2) begin stalla2 = TRUE; ov2 = FALSE; end
	if (o1==o3) begin stalla3 = TRUE; ov3 = FALSE; end
	if (o2==o3) begin stalla3 = TRUE; ov3 = FALSE; end
end

// Do not do a pop if stalling on another slot.
// Do a pop only if allocating
always_comb fpop[0] = (alloc0 & en & ~stall) | (alloc0 & stalla0);
always_comb fpop[1] = (alloc1 & en & ~stall) | (alloc1 & stalla1);
always_comb fpop[2] = (alloc2 & en & ~stall) | (alloc2 & stalla2);
always_comb fpop[3] = (alloc3 & en & ~stall) | (alloc3 & stalla3);

reg [3:0] freevals1;
reg [$clog2(PREGS)-3:0] rotcnt [0:3];
reg [$clog2(PREGS)-3:0] freeCnt;
reg [2:0] ffreeCnt;
reg [PREGS-1:0] next_toFreeList;
reg [PREGS-1:0] toFreeList;
reg [3:0] ffree;
always_comb
	avail1 = restore ? restore_list : avail;

always_ff @(posedge clk)
begin
	if (en) begin
		ov0r <= 1'b0;
		ov1r <= 1'b0;
		ov2r <= 1'b0;
		ov3r <= 1'b0;
	end
	else begin
		ov0r <= ov0;
		ov1r <= ov1;
		ov2r <= ov2;
		ov3r <= ov3;
	end
end

// Refuse to put 0 onto the stack. 0 is specially reserved.
always_comb
begin
	fpush[0] = tags2free[0]==9'd0 ? 1'b0 : freevals[0];
	fpush[1] = tags2free[1]==9'd0 ? 1'b0 : freevals[1];
	fpush[2] = tags2free[2]==9'd0 ? 1'b0 : freevals[2];
	fpush[3] = tags2free[3]==9'd0 ? 1'b0 : freevals[3];
end

always_comb
begin
	tags[0] = fpush[0] ? tags2free[0] : 9'd0;
	tags[1] = fpush[1] ? tags2free[1] : 9'd0;
	tags[2] = fpush[2] ? tags2free[2] : 9'd0;
	tags[3] = fpush[3] ? tags2free[3] : 9'd0;
end

generate begin : gAvail
	if (PREGS==512) begin
reg [511:0] avail_rot;
always_comb avail_rot[127:  0] = (avail[127:  0] << rotcnt[0]) | (avail[127:  0] >> (128-rotcnt[0]));
always_comb avail_rot[255:128] = (avail[255:128] << rotcnt[1]) | (avail[255:128] >> (128-rotcnt[1]));
always_comb avail_rot[383:356] = (avail[383:256] << rotcnt[2]) | (avail[383:256] >> (128-rotcnt[2]));
always_comb avail_rot[511:384] = (avail[511:384] << rotcnt[3]) | (avail[511:384] >> (128-rotcnt[3]));
wire [7:0] ffo0;
wire [7:0] ffo1;
wire [7:0] ffo2;
wire [7:0] ffo3;
ffo144 uffo0 (.i({16'd0,avail_rot[127:  0]}), .o(ffo0));
ffo144 uffo1 (.i({16'd0,avail_rot[255:128]}), .o(ffo1));
ffo144 uffo2 (.i({16'd0,avail_rot[383:256]}), .o(ffo2));
ffo144 uffo3 (.i({16'd0,avail_rot[511:384]}), .o(ffo3));
always_comb o0 = {2'd0,ffo0[6:0]+rotcnt[0][6:0]};
always_comb o1 = {2'd1,ffo1[6:0]+rotcnt[1][6:0]};
always_comb o2 = {2'd2,ffo2[6:0]+rotcnt[2][6:0]};
always_comb o3 = {2'd3,ffo3[6:0]+rotcnt[3][6:0]};
	end

	else if (PREGS==256) begin
reg [255:0] avail_rot;
always_comb avail_rot[ 63:  0] = (avail[ 63:  0] << rotcnt[0]) | (avail[ 63:  0] >> (64-rotcnt[0]));
always_comb avail_rot[127: 64] = (avail[127: 64] << rotcnt[1]) | (avail[127: 64] >> (64-rotcnt[1]));
always_comb avail_rot[191:128] = (avail[191:128] << rotcnt[2]) | (avail[191:128] >> (64-rotcnt[2]));
always_comb avail_rot[255:192] = (avail[255:192] << rotcnt[3]) | (avail[255:192] >> (64-rotcnt[3]));

wire [6:0] ffo0;
wire [6:0] ffo1;
wire [6:0] ffo2;
wire [6:0] ffo3;
ffo96 uffo0 (.i({32'd0,avail_rot[ 63:  0]}), .o(ffo0));
ffo96 uffo1 (.i({32'd0,avail_rot[127: 64]}), .o(ffo1));
ffo96 uffo2 (.i({32'd0,avail_rot[191:128]}), .o(ffo2));
ffo96 uffo3 (.i({32'd0,avail_rot[255:192]}), .o(ffo3));

always_comb o0 = {2'd0,ffo0[5:0] + rotcnt[0][5:0]};
always_comb o1 = {2'd1,ffo1[5:0] + rotcnt[1][5:0]};
always_comb o2 = {2'd2,ffo2[5:0] + rotcnt[2][5:0]};
always_comb o3 = {2'd3,ffo3[5:0] + rotcnt[3][5:0]};
	end

	else if (PREGS==128) begin
reg [127:0] avail_rot;
always_comb avail_rot[ 31:  0] = (avail[ 31:  0] << rotcnt[0]) | (avail[ 31:  0] >> (32-rotcnt[0]));
always_comb avail_rot[ 63: 32] = (avail[ 63: 32] << rotcnt[1]) | (avail[ 63: 32] >> (32-rotcnt[1]));
always_comb avail_rot[ 95: 64] = (avail[ 95: 64] << rotcnt[2]) | (avail[ 95: 64] >> (32-rotcnt[2]));
always_comb avail_rot[127: 96] = (avail[127: 96] << rotcnt[3]) | (avail[127: 96] >> (32-rotcnt[3]));

wire [5:0] ffo0;
wire [5:0] ffo1;
wire [5:0] ffo2;
wire [5:0] ffo3;
ffo48 uffo0 (.i({16'd0,avail_rot[ 31:  0]}), .o(ffo0));
ffo48 uffo1 (.i({16'd0,avail_rot[ 63: 32]}), .o(ffo1));
ffo48 uffo2 (.i({16'd0,avail_rot[ 95: 64]}), .o(ffo2));
ffo48 uffo3 (.i({16'd0,avail_rot[127: 96]}), .o(ffo3));

always_comb o0 = {2'd0,ffo0[4:0] + rotcnt[0][4:0]};
always_comb o1 = {2'd1,ffo1[4:0] + rotcnt[1][4:0]};
always_comb o2 = {2'd2,ffo2[4:0] + rotcnt[2][4:0]};
always_comb o3 = {2'd3,ffo3[4:0] + rotcnt[3][4:0]};
	end
end
endgenerate

always_ff @(posedge clk)
if (rst) begin
	rotcnt[0] <= 7'd0;
	rotcnt[1] <= 7'd0;
	rotcnt[2] <= 7'd0;
	rotcnt[3] <= 7'd0;
end
else begin
		
	begin
		rotcnt[0] <= rotcnt[0] + fpop[0];
		rotcnt[1] <= rotcnt[1] + fpop[1];
		rotcnt[2] <= rotcnt[2] + fpop[2];
		rotcnt[3] <= rotcnt[3] + fpop[3];
	end
	
end
	
// The following checks should always fail as it is not possible in properly
// running hardware to get the same register on a different port.
always_comb
if (0) begin
	if (o0==o1 || o0==o2 || o0==o3) begin
		$display("Q+: matching rename registers");
		$finish;
	end
	if (o1==o2 || o1==o3) begin
		$display("Q+: matching rename registers");
		$finish;
	end
	if (o2==o3) begin
		$display("Q+: matching rename registers");
		$finish;
	end
end

always_comb
begin
	if (restore)
		next_avail = restore_list;
	else
		next_avail = avail;

	if (ov0 & en) next_avail[o0] = 1'b0;
	if (ov1 & en) next_avail[o1] = 1'b0;
	if (ov2 & en) next_avail[o2] = 1'b0;
	if (ov3 & en) next_avail[o3] = 1'b0;

	if (fpush[0]) next_avail[tags[0]] = 1'b1;
	if (fpush[1]) next_avail[tags[1]] = 1'b1;
	if (fpush[2]) next_avail[tags[2]] = 1'b1;
	if (fpush[3]) next_avail[tags[3]] = 1'b1;

	if (bo_wr) next_avail[bo_preg] = 1'b0;

	next_avail[0] = 1'b0;
end

always_ff @(posedge clk)
if (rst)
	avail = {{PREGS-1{1'b1}},1'b0};
else
	avail <= next_avail;

endmodule
