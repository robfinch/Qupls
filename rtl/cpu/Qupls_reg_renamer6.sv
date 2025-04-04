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
// 3200 LUTs / 1040 FFs / 0 BRAMs
// ============================================================================
//
import const_pkg::*;
import cpu_types_pkg::*;
import QuplsPkg::*;

module Qupls_reg_renamer6(rst,clk,en,restore,restore_list,tags2free,freevals,
	bo_wr, bo_preg,
	alloc0,alloc1,alloc2,alloc3,wo0,wo1,wo2,wo3,wv0,wv1,wv2,wv3,avail,stall,rst_busy
);
parameter NFTAGS = 4;
input rst;
input clk;
input en;
input restore;
input [PREGS-1:0] restore_list;
input cpu_types_pkg::pregno_t [NFTAGS-1:0] tags2free;		// register tags to free
input [NFTAGS-1:0] freevals;					// bitmnask indicating which tags to free
input bo_wr;
input pregno_t bo_preg;
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

reg [PREGS-1:0] avail1 = {{PREGS-1{1'b1}},1'b0};
reg [PREGS-1:0] pavail = {{PREGS-1{1'b1}},1'b0};				// recorded in ROB
reg [PREGS-1:0] pavail2 = {{PREGS-1{1'b1}},1'b0};				// recorded in ROB
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

pregno_t [3:0] tags;
reg [3:0] fpush;
reg wv0r;
reg wv1r;
reg wv2r;
reg wv3r;

always_comb stall = stalla0|stalla1|stalla2|stalla3;
always_comb rst_busy = 1'b0;

always_comb
begin
	// Not a stall if not allocating.
	stalla0 = ~avail1[wo0] & alloc0;
	stalla1 = ~avail1[wo1] & alloc1;
	stalla2 = ~avail1[wo2] & alloc2;
	stalla3 = ~avail1[wo3] & alloc3;
	wv0 = (avail1[wo0] & alloc0) | (wv0r & ~en);// & ~empty0;
	wv1 = (avail1[wo1] & alloc1) | (wv1r & ~en);// & ~empty1;
	wv2 = (avail1[wo2] & alloc2) | (wv2r & ~en);// & ~empty2;
	wv3 = (avail1[wo3] & alloc3) | (wv3r & ~en);// & ~empty3;
	if (wo0==wo1) begin stalla1 = TRUE; wv1 = FALSE; end
	if (wo0==wo2) begin stalla2 = TRUE; wv2 = FALSE; end
	if (wo0==wo3) begin stalla3 = TRUE; wv3 = FALSE; end
	if (wo1==wo2) begin stalla2 = TRUE; wv2 = FALSE; end
	if (wo1==wo3) begin stalla3 = TRUE; wv3 = FALSE; end
	if (wo2==wo3) begin stalla3 = TRUE; wv3 = FALSE; end
end

// Do not do a pop if stalling on another slot.
// Do a pop only if allocating
always_comb pop0 = (alloc0 & en & ~stall) | (alloc0 & stalla0);
always_comb pop1 = (alloc1 & en & ~stall) | (alloc1 & stalla1);
always_comb pop2 = (alloc2 & en & ~stall) | (alloc2 & stalla2);
always_comb pop3 = (alloc3 & en & ~stall) | (alloc3 & stalla3);

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

// Refuse to put 0 onto the stack. 0 is specially reserved.
// If the tag is already free, refuse to place on stack.
always_comb
begin
	freevals1[0] = tags2free[0]==9'd0 ? 1'b0 : freevals[0];
	freevals1[1] = tags2free[1]==9'd0 ? 1'b0 : freevals[1];
	freevals1[2] = tags2free[2]==9'd0 ? 1'b0 : freevals[2];
	freevals1[3] = tags2free[3]==9'd0 ? 1'b0 : freevals[3];
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
always_comb wo0 = {2'd0,ffo0[6:0]+rotcnt[0][6:0]};
always_comb wo1 = {2'd1,ffo1[6:0]+rotcnt[1][6:0]};
always_comb wo2 = {2'd2,ffo2[6:0]+rotcnt[2][6:0]};
always_comb wo3 = {2'd3,ffo3[6:0]+rotcnt[3][6:0]};
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
/*
ffo96 uffo0 (.i({32'd0,avail[ 63:  0]&pavail[ 63:  0]&pavail2[ 63:  0]}), .o(ffo0));
ffo96 uffo1 (.i({32'd0,avail[127: 64]&pavail[127: 64]&pavail2[127: 64]}), .o(ffo1));
ffo96 uffo2 (.i({32'd0,avail[191:128]&pavail[191:128]&pavail2[191:128]}), .o(ffo2));
ffo96 uffo3 (.i({32'd0,avail[255:192]&pavail[255:192]&pavail2[255:192]}), .o(ffo3));
*/
always_comb wo0 = {2'd0,ffo0[5:0] + rotcnt[0][5:0]};
always_comb wo1 = {2'd1,ffo1[5:0] + rotcnt[1][5:0]};
always_comb wo2 = {2'd2,ffo2[5:0] + rotcnt[2][5:0]};
always_comb wo3 = {2'd3,ffo3[5:0] + rotcnt[3][5:0]};
	end
end
endgenerate

always_comb
begin
	tags[0] = 9'd0;
	tags[1] = 9'd0;
	tags[2] = 9'd0;
	tags[3] = 9'd0;
	if (freevals1[0]) tags[0] = tags2free[0];
	if (freevals1[1]) tags[1] = tags2free[1];
	if (freevals1[2]) tags[2] = tags2free[2];
	if (freevals1[3]) tags[3] = tags2free[3];
	if (tags[0]==9'd0 && ffree[0])
		tags[0] = freeCnt;
	if (tags[1]==9'd0 && ffree[1])
		tags[1] = freeCnt + PREGS/4;
	if (tags[2]==9'd0 && ffree[2])
		tags[2] = freeCnt + PREGS/2;
	if (tags[3]==9'd0 && ffree[3])
		tags[3] = freeCnt + PREGS*3/4;
end

always_comb
begin
	fpush[0] = avail[tags[0]] ? 1'b0 : |tags[0];//(freevals1[0] | ffree[0]);
	fpush[1] = avail[tags[1]] ? 1'b0 : |tags[1];//(freevals1[1] | ffree[1]);
	fpush[2] = avail[tags[2]] ? 1'b0 : |tags[2];//(freevals1[2] | ffree[2]);
	fpush[3] = avail[tags[3]] ? 1'b0 : |tags[3];//(freevals1[3] | ffree[3]);
end

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
begin
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

	if (bo_wr) next_avail[bo_preg] = 1'b0;

	next_avail[0] = 1'b0;
end

wire cd_avail;
change_det #(PREGS) ucdavail1 (.rst(rst), .clk(clk), .ce(1'b1), .i(avail), .cd(cd_avail));

always_ff @(posedge clk)
if (rst) begin
	rotcnt[0] <= 6'd0;
	rotcnt[1] <= 6'd0;
	rotcnt[2] <= 6'd0;
	rotcnt[3] <= 6'd0;
end
else begin
		
	begin
		rotcnt[0] <= rotcnt[0] + pop0;
		rotcnt[1] <= rotcnt[1] + pop1;
		rotcnt[2] <= rotcnt[2] + pop2;
		rotcnt[3] <= rotcnt[3] + pop3;
	end
	
end
	
always_ff @(posedge clk)
if (rst)
	avail = {{PREGS-1{1'b1}},1'b0};
else
	avail <= next_avail;

always_ff @(posedge clk)
if (rst) begin
	pavail = {{PREGS-1{1'b1}},1'b0};
	pavail[0] = 1'b0;
end
else if (cd_avail) begin
	pavail <= avail;
	if (wv0 & en) pavail[wo0] <= 1'b0;
	if (wv1 & en) pavail[wo1] <= 1'b0;
	if (wv2 & en) pavail[wo2] <= 1'b0;
	if (wv3 & en) pavail[wo3] <= 1'b0;
end
always_ff @(posedge clk)
if (rst) begin
	pavail2 = {{PREGS-1{1'b1}},1'b0};
	pavail2[0] = 1'b0;
end
else if (cd_avail) begin
	pavail2 <= pavail;
	if (wv0 & en) pavail2[wo0] <= 1'b0;
	if (wv1 & en) pavail2[wo1] <= 1'b0;
	if (wv2 & en) pavail2[wo2] <= 1'b0;
	if (wv3 & en) pavail2[wo3] <= 1'b0;
end

reg [2:0] pushCnt, nFree;
always_comb
	pushCnt = fpush[0] + fpush[1] + fpush[2] + fpush[3];
always_comb
	ffreeCnt = (ffree[0] & ~(freevals1[0])) +
						 (ffree[1] & ~(freevals1[1])) +
						 (ffree[2] & ~(freevals1[2])) +
						 (ffree[3] & ~(freevals1[3]))
						 ;
/*
always_ff @(posedge clk)
if (rst)
	fifo_order <= 2'd0;
else
	fifo_order <= (pushCnt + fifo_order) % 4;
*/
always_ff @(posedge clk) if (rst) alloc0d <= 1'b0; else if(en) alloc0d <= alloc0;
always_ff @(posedge clk) if (rst) alloc1d <= 1'b0; else if(en) alloc1d <= alloc1;
always_ff @(posedge clk) if (rst) alloc2d <= 1'b0; else if(en) alloc2d <= alloc2;
always_ff @(posedge clk) if (rst) alloc3d <= 1'b0; else if(en) alloc3d <= alloc3;

/*
always_comb
casez(
{toFreeList[freeCnt+4'd0],
toFreeList[freeCnt+4'd1],
toFreeList[freeCnt+4'd2],
toFreeList[freeCnt+4'd3],
toFreeList[freeCnt+4'd4],
toFreeList[freeCnt+4'd5],
toFreeList[freeCnt+4'd6],
toFreeList[freeCnt+4'd7]
})
8'b00000000:	nFree = 4'd8;
8'b00000001:	nFree = 4'd7;
8'b0000001?:	nFree = 4'd6;
8'b000001??:	nFree = 4'd5;
8'b00001???:	nFree = 4'd4;
default:	nFree = 3'd4 - ffreeCnt;
endcase	
*/
always_ff @(posedge clk)
if (rst)
	freeCnt <= 7'd0;
else
	freeCnt <= freeCnt + 7'd1;

always_ff @(posedge clk)
if (rst) begin
	ffree[0] <= 1'b0;
	ffree[1] <= 1'b0;
	ffree[2] <= 1'b0;
	ffree[3] <= 1'b0;
end
else begin
	ffree[0] <= (freeCnt!=7'd0) ? toFreeList[freeCnt] : 1'b0;
	ffree[1] <= toFreeList[PREGS/4+freeCnt];
	ffree[2] <= toFreeList[PREGS/2+freeCnt];
	ffree[3] <= toFreeList[PREGS*3/4+freeCnt];
end

always_comb
begin
	next_toFreeList = toFreeList;
	if (restore)
		next_toFreeList = next_toFreeList;// | (restore_list & ~avail);
	if (fpush[0])	next_toFreeList[tags[0]] = 1'b0;
 	if (fpush[1])	next_toFreeList[tags[1]] = 1'b0;
 	if (fpush[2])	next_toFreeList[tags[2]] = 1'b0;
 	if (fpush[3])	next_toFreeList[tags[3]] = 1'b0;
 	next_toFreeList[0] = 1'b0;
end

always_ff @(posedge clk)
if (rst)
	toFreeList <= {PREGS{1'b0}};
else
	toFreeList <= next_toFreeList;

endmodule
