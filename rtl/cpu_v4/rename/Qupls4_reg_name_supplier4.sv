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
// registers are not reused too soon. This prevents pipelining issues.
// Freeing the register, a "push", is simple, the register is just marked
// available in the bitmap.
// For a checkpoint restore, the available register map is simply copied from
// the checkpoint.
// 
// 7200 LUTs / 550 FFs / 0 BRAMs (512 regs)
// ============================================================================
//
import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_reg_name_supplier4(rst,clk,en,restore,restore_list,tags2free,freevals,
	bo_wr, bo_preg, o, ov,
	ns_alloc_req, ns_whrndx, ns_cndx, ns_rndx, ns_dstreg, ns_dstregv,
	avail,stall,rst_busy
);
parameter NFTAGS = 4;			// Number of register freed per clock.
input rst;
input clk;
input en;
input restore;
input [Qupls4_pkg::PREGS-1:0] restore_list;				// from checkpoint memory, which regs were available
input cpu_types_pkg::pregno_t [NFTAGS-1:0] tags2free;		// register tags to free
input [NFTAGS-1:0] freevals;					// bitmnask indicating which tags to free
input bo_wr;
input pregno_t bo_preg;
output pregno_t [3:0] o;
output reg [3:0] ov;
input [3:0] ns_alloc_req;
input rob_ndx_t [3:0] ns_whrndx;
input checkpt_ndx_t [3:0] ns_cndx;
output rob_ndx_t [3:0] ns_rndx;
output cpu_types_pkg::pregno_t [3:0] ns_dstreg;
output reg [3:0] ns_dstregv;
output reg [Qupls4_pkg::PREGS-1:0] avail = {Qupls4_pkg::PREGS{1'b1}};
output reg stall;											// stall enqueue while waiting for register availability
output reg rst_busy;									// not used

integer n1,n2;

reg [Qupls4_pkg::PREGS-1:0] avail1 = {Qupls4_pkg::PREGS{1'b1}};
reg [3:0] fpop = 4'd0;
reg stalla0 = 1'b0;
reg stalla1 = 1'b0;
reg stalla2 = 1'b0;
reg stalla3 = 1'b0;
reg [Qupls4_pkg::PREGS-1:0] next_avail;

reg [3:0] fpush;
reg [3:0] ovr;

always_comb stall = stalla0|stalla1|stalla2|stalla3;
always_comb rst_busy = 1'b0;

always_comb
if (Qupls4_pkg::PREGS != 512 && Qupls4_pkg::PREGS != 256 && Qupls4_pkg::PREGS != 128) begin
	$display("Qupls4 CPU renamer: number of registers must be 128, 256, or 512");
	$finish;
end

always_comb
begin
	// Not a stall if not allocating.
	stalla0 = ~avail1[o[0]] & ns_alloc_req[0];
	stalla1 = ~avail1[o[1]] & ns_alloc_req[1];
	stalla2 = ~avail1[o[2]] & ns_alloc_req[2];
	stalla3 = ~avail1[o[3]] & ns_alloc_req[3];
	ov[0] = ((avail1[o[0]] & ns_alloc_req[0]) | (ovr[0] & ~en));
	ov[1] = ((avail1[o[1]] & ns_alloc_req[1]) | (ovr[1] & ~en)) && ns_cndx[1]==ns_cndx[0];
	ov[2] = ((avail1[o[2]] & ns_alloc_req[2]) | (ovr[2] & ~en)) && ns_cndx[2]==ns_cndx[0];
	ov[3] = ((avail1[o[3]] & ns_alloc_req[3]) | (ovr[3] & ~en)) && ns_cndx[3]==ns_cndx[0];
	if (o[0]==o[1]) begin stalla1 = TRUE; ov[1] = FALSE; end
	if (o[0]==o[2]) begin stalla2 = TRUE; ov[2] = FALSE; end
	if (o[0]==o[3]) begin stalla3 = TRUE; ov[3] = FALSE; end
	if (o[1]==o[2]) begin stalla2 = TRUE; ov[2] = FALSE; end
	if (o[1]==o[3]) begin stalla3 = TRUE; ov[3] = FALSE; end
	if (o[2]==o[3]) begin stalla3 = TRUE; ov[3] = FALSE; end
end

// Do not do a pop if stalling on another slot.
// Do a pop only if allocating
always_comb fpop[0] = (ns_alloc_req[0] & en & ~stall) | (ns_alloc_req[0] & stalla0);
always_comb fpop[1] = (ns_alloc_req[1] & en & ~stall) | (ns_alloc_req[1] & stalla1);
always_comb fpop[2] = (ns_alloc_req[2] & en & ~stall) | (ns_alloc_req[2] & stalla2);
always_comb fpop[3] = (ns_alloc_req[3] & en & ~stall) | (ns_alloc_req[3] & stalla3);

reg [3:0] freevals1;
reg [$clog2(Qupls4_pkg::PREGS)-3:0] freeCnt;
reg [2:0] ffreeCnt;
reg [Qupls4_pkg::PREGS-1:0] next_toFreeList;
reg [Qupls4_pkg::PREGS-1:0] toFreeList;
reg [3:0] ffree;
always_comb
	avail1 = restore ? restore_list : avail;

always_ff @(posedge clk)
begin
	if (en) begin
		ovr <= 4'h0;
	end
	else begin
		ovr <= ov;
	end
end

always_comb
begin
	fpush[0] = freevals[0];
	fpush[1] = freevals[1];
	fpush[2] = freevals[2];
	fpush[3] = freevals[3];
end

generate begin : gAvail
	if (Qupls4_pkg::PREGS==512) begin
reg [$clog2(Qupls4_pkg::PREGS)-3:0] rotcnt [0:3];
reg [511:0] avail_rot;
always_comb avail_rot[127:  0] = (avail[127:  0] << rotcnt[0]) | (avail[127:  0] >> (128-rotcnt[0]));
always_comb avail_rot[255:128] = (avail[255:128] << rotcnt[1]) | (avail[255:128] >> (128-rotcnt[1]));
always_comb avail_rot[383:356] = (avail[383:256] << rotcnt[2]) | (avail[383:256] >> (128-rotcnt[2]));
always_comb avail_rot[511:384] = (avail[511:384] << rotcnt[3]) | (avail[511:384] >> (128-rotcnt[3]));
wire [7:0] ffo [0:3];
ffo144 uffo0 (.i({16'd0,avail_rot[127:  0]}), .o(ffo[0]));
ffo144 uffo1 (.i({16'd0,avail_rot[255:128]}), .o(ffo[1]));
ffo144 uffo2 (.i({16'd0,avail_rot[383:256]}), .o(ffo[2]));
ffo144 uffo3 (.i({16'd0,avail_rot[511:384]}), .o(ffo[3]));

always_comb o[0] = {2'd0,ffo[0][6:0] + rotcnt[0][6:0]};
always_comb o[1] = {2'd1,ffo[1][6:0] + rotcnt[1][6:0]};
always_comb o[2] = {2'd2,ffo[2][6:0] + rotcnt[2][6:0]};
always_comb o[3] = {2'd3,ffo[3][6:0] + rotcnt[3][6:0]};

checkpt_ndx_t last_cndx;
always_comb
foreach (ns_dstreg[n1])
begin
	last_cndx = ns_cndx[0];
	ns_dstregv[n1] = INV;
	ns_dstreg[n1] = 9'd0;
	ns_rndx[n1] = 6'd0;
	if (ns_alloc_req[n1]) begin
//		if (last_cndx==ns_cndx[n1]) begin
			ns_rndx[n1] = ns_whrndx[n1];
			ns_dstreg[n1] = o[n1];
			ns_dstregv[n1] = ov[n1];
//		end
	end
end

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
	end

	else if (Qupls4_pkg::PREGS==256) begin
reg [$clog2(Qupls4_pkg::PREGS)-2:0] rotcnt [0:1];
reg [255:0] avail_rot;
always_comb avail_rot[127:  0] = (avail[127:  0] << rotcnt[0]) | (avail[127:  0] >> (128-rotcnt[0]));
always_comb avail_rot[255:128] = (avail[255:128] << rotcnt[1]) | (avail[255:128] >> (128-rotcnt[1]));

wire [7:0] ffo [0:3];
ffo144 uffo0 (.i({16'd0,avail_rot[127:  0]}), .o(ffo[0]));
ffo144 uffo1 (.i({16'd0,avail_rot[127:  0] & ~(128'd1 << ffo[0])}), .o(ffo[1]));
ffo144 uffo2 (.i({16'd0,avail_rot[255:128]}), .o(ffo[2]));
ffo144 uffo3 (.i({16'd0,avail_rot[255:128] & ~(128'd1 << ffo[2])}), .o(ffo[3]));

always_comb o[0] = {1'd0,ffo[0][6:0] + rotcnt[0][6:0]};
always_comb o[1] = {1'd0,ffo[1][6:0] + rotcnt[0][6:0]};
always_comb o[2] = {1'd1,ffo[2][6:0] + rotcnt[1][6:0]};
always_comb o[3] = {1'd1,ffo[3][6:0] + rotcnt[1][6:0]};

always_comb
for (n1 = 0; n1 < 4; n1 = n1 + 1)
begin
	ns_dstregv[n1] = INV;
	ns_dstreg[n1] = 8'd0;
	if (ns_alloc_req[n1]) begin
		ns_rndx[n1] = ns_whrndx[n1];
		ns_dstreg[n1] = o[n1];
		ns_dstregv[n1] = ov[n1];
	end
end

always_ff @(posedge clk)
if (rst) begin
	rotcnt[0] <= 7'd0;
	rotcnt[1] <= 7'd0;
end
else begin
	begin
		rotcnt[0] <= rotcnt[0] + fpop[0] + fpop[1];
		rotcnt[1] <= rotcnt[1] + fpop[2] + fpop[3];
	end
end
	end

	else if (Qupls4_pkg::PREGS==128) begin
reg [$clog2(Qupls4_pkg::PREGS)-3:0] rotcnt [0:3];
reg [127:0] avail_rot;
always_comb avail_rot[ 31:  0] = (avail[ 31:  0] << rotcnt[0]) | (avail[ 31:  0] >> (32-rotcnt[0]));
always_comb avail_rot[ 63: 32] = (avail[ 63: 32] << rotcnt[1]) | (avail[ 63: 32] >> (32-rotcnt[1]));
always_comb avail_rot[ 95: 64] = (avail[ 95: 64] << rotcnt[2]) | (avail[ 95: 64] >> (32-rotcnt[2]));
always_comb avail_rot[127: 96] = (avail[127: 96] << rotcnt[3]) | (avail[127: 96] >> (32-rotcnt[3]));

wire [5:0] ffo [0:3];
ffo48 uffo0 (.i({16'd0,avail_rot[ 31:  0]}), .o(ffo[0]));
ffo48 uffo1 (.i({16'd0,avail_rot[ 63: 32]}), .o(ffo[1]));
ffo48 uffo2 (.i({16'd0,avail_rot[ 95: 64]}), .o(ffo[2]));
ffo48 uffo3 (.i({16'd0,avail_rot[127: 96]}), .o(ffo[3]));

always_comb o[0] = {2'd0,ffo[0][4:0] + rotcnt[0][4:0]};
always_comb o[1] = {2'd1,ffo[1][4:0] + rotcnt[1][4:0]};
always_comb o[2] = {2'd2,ffo[2][4:0] + rotcnt[2][4:0]};
always_comb o[3] = {2'd3,ffo[3][4:0] + rotcnt[3][4:0]};

always_comb
for (n1 = 0; n1 < 4; n1 = n1 + 1)
begin
	ns_dstregv[n1] = INV;
	ns_dstreg[n1] = 7'd0;
	if (ns_alloc_req[n1]) begin
		ns_rndx[n1] = ns_whrndx[n1];
		ns_dstreg[n1] = o[n1];
		ns_dstregv[n1] = ov[n1];
	end
end

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
	end
end
endgenerate

// The following checks should always fail as it is not possible in properly
// running hardware to get the same register on a different port.
always_comb
if (0) begin
	if (o[0]==o[1] || o[0]==o[2] || o[0]==o[3]) begin
		$display("Qupls4CPU: matching rename registers");
		$finish;
	end
	if (o[1]==o[2] || o[1]==o[3]) begin
		$display("Qupls4CPU: matching rename registers");
		$finish;
	end
	if (o[2]==o[3]) begin
		$display("Qupls4CPU: matching rename registers");
		$finish;
	end
end

always_comb
begin
	if (restore)
		next_avail = restore_list;
	else
		next_avail = avail;

	if (ov[0] & en) next_avail[o[0]] = 1'b0;
	if (ov[1] & en) next_avail[o[1]] = 1'b0;
	if (ov[2] & en) next_avail[o[2]] = 1'b0;
	if (ov[3] & en) next_avail[o[3]] = 1'b0;

	if (fpush[0]) next_avail[tags2free[0]] = 1'b1;
	if (fpush[1]) next_avail[tags2free[1]] = 1'b1;
	if (fpush[2]) next_avail[tags2free[2]] = 1'b1;
	if (fpush[3]) next_avail[tags2free[3]] = 1'b1;

	if (bo_wr) next_avail[bo_preg] = 1'b0;

end

always_ff @(posedge clk)
if (rst)
	avail <= {Qupls4_pkg::PREGS{1'b1}};
else
	avail <= next_avail;

endmodule
