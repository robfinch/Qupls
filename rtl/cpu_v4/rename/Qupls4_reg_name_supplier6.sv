// ============================================================================
//        __
//   \\__/ o\    (C) 2024-2026  Robert Finch, Waterloo
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
// 2600 LUTs / 520 FFs / 0 BRAMs (512 regs)
// ============================================================================
//
import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_reg_name_supplier6(rst,clk,en,tags2free,freevals,
	o, ov,
	ns_alloc_req, ns_whrndx, ns_cndx, ns_rndx, ns_dstreg, ns_dstregv,
	avail,stall,rst_busy
);
parameter NFTAGS = Qupls4_pkg::MWIDTH;	// Number of register freed per clock.
parameter NNAME = Qupls4_pkg::MWIDTH;
input rst;
input clk;
input en;
input cpu_types_pkg::pregno_t [NFTAGS-1:0] tags2free;		// register tags to free
input [NFTAGS-1:0] freevals;					// bitmnask indicating which tags to free
output pregno_t [NNAME-1:0] o;
output reg [NNAME-1:0] ov;
input [NNAME-1:0] ns_alloc_req;
input rob_ndx_t [NNAME-1:0] ns_whrndx;
input checkpt_ndx_t [NNAME-1:0] ns_cndx;
output rob_ndx_t [NNAME-1:0] ns_rndx;
output cpu_types_pkg::pregno_t [NNAME-1:0] ns_dstreg;
output reg [NNAME-1:0] ns_dstregv;
output reg [Qupls4_pkg::PREGS-1:0] avail = {Qupls4_pkg::PREGS{1'b1}};
output reg stall;											// stall enqueue while waiting for register availability
output reg rst_busy;									// not used

integer n1,n2,n3,n4,n5,n6;
genvar g;
cpu_types_pkg::pregno_t [NFTAGS-1:0] rtags2free;
reg [NNAME-1:0] fpop = 4'd0;
reg [NNAME-1:0] stalla = {NNAME{1'b0}};
reg [Qupls4_pkg::PREGS-1:0] next_avail;
reg [Qupls4_pkg::PREGS-1:0] availv;

reg [NNAME-1:0] fpush;
reg [NNAME-1:0] ovr;
reg vstall;

always_comb stall = |stalla|vstall;
always_comb rst_busy = 1'b0;

always_comb
if (Qupls4_pkg::PREGS != 512 && Qupls4_pkg::PREGS != 256) begin
	$display("Qupls4 CPU renamer: number of registers must be 256 or 512");
	$finish;
end

always_comb
begin
	foreach (stalla[n4]) begin
		// Not a stall if not allocating.
		stalla[n4] = ~avail[o[n4]] & ns_alloc_req[n4];
		ov[n4] = ((availv[n4] & ns_alloc_req[n4]) | (ovr[n4] & ~en)) && ns_cndx[n4]==ns_cndx[n4];
	end
end

// Do not do a pop if stalling on another slot.
// Do a pop only if allocating
always_comb
	foreach (fpop[n5])
		fpop[n5] = (ns_alloc_req[n5] & en & ~stall) | (ns_alloc_req[n5] & stalla[n5]);

reg [NNAME-1:0] freevals1;
reg [$clog2(Qupls4_pkg::PREGS)-3:0] freeCnt;
reg [2:0] ffreeCnt;
reg [Qupls4_pkg::PREGS-1:0] next_toFreeList;
reg [Qupls4_pkg::PREGS-1:0] toFreeList;
reg [NNAME-1:0] ffree;

always_ff @(posedge clk)
begin
	if (en) begin
		ovr <= 4'h0;
	end
	else begin
		ovr <= ov;
	end
end

generate begin : gAvail
case(Qupls4_pkg::PREGS)
/*
1024:
 begin
		wire [7:0] ffo [0:7];
		ffo144 uffo0 (.i({16'd0,avail[127:  0]}), .o(ffo[0]));
		ffo144 uffo1 (.i({16'd0,avail[255:128]}), .o(ffo[1]));
		ffo144 uffo2 (.i({16'd0,avail[383:256]}), .o(ffo[2]));
		ffo144 uffo3 (.i({16'd0,avail[511:384]}), .o(ffo[3]));
		ffo144 uffo4 (.i({16'd0,avail[639:512]}), .o(ffo[4]));
		ffo144 uffo5 (.i({16'd0,avail[767:640]}), .o(ffo[5]));
		ffo144 uffo6 (.i({16'd0,avail[895:768]}), .o(ffo[6]));
		ffo144 uffo7 (.i({16'd0,avail[1023:896]}), .o(ffo[7]));

		always_comb o[0] = ffo[0]==8'd255 ? {3'd4,ffo[4][6:0]}:{3'd0,ffo[0][6:0]};
		always_comb o[1] = ffo[1]==8'd255 ? {3'd5,ffo[5][6:0]}:{3'd1,ffo[1][6:0]};
		always_comb o[2] = ffo[2]==8'd255 ? {3'd6,ffo[6][6:0]}:{3'd2,ffo[2][6:0]};
		always_comb o[3] = ffo[3]==8'd255 ? {3'd7,ffo[7][6:0]}:{3'd3,ffo[3][6:0]};

		checkpt_ndx_t last_cndx;
		always_comb
		foreach (ns_dstreg[n1])
		begin
			last_cndx = ns_cndx[0];
			ns_dstregv[n1] = INV;
			ns_dstreg[n1] = 10'd0;
			ns_rndx[n1] = 6'd0;
			if (ns_alloc_req[n1]) begin
		//		if (last_cndx==ns_cndx[n1]) begin
					ns_rndx[n1] = ns_whrndx[n1];
					ns_dstreg[n1] = o[n1];
					ns_dstregv[n1] = ov[n1];
		//		end
			end
		end
	end
*/
512:
 begin
		wire [9:0] ffo [0:3];
		wire [511:0] navail0 = ~{512'd1 << ffo[0]};
		wire [511:0] navail1 = ~{512'd1 << ffo[1]};
		wire [511:0] navail2 = ~({512'd1 << ffo[0]}|{512'd1 << ffo[1]}|{512'd1 << ffo[2]});
		wire [511:0] navail3 = ~({512'd1 << ffo[0]}|{512'd1 << ffo[1]}|{512'd1 << ffo[2]}|{512'd1 << ffo[3]});
		wire [511:0] navail4 = ~({512'd1 << ffo[0]}|{512'd1 << ffo[1]}|{512'd1 << ffo[2]}|{512'd1 << ffo[3]}|{512'd1 << ffo[4]});
		case(NNAME)
		1:
			begin
				ffo576 u1 (.i({64'd0,avail}), .o(ffo[0]));
				always_comb o[0] = {ffo[0][8:0]};
				always_comb availv = {6'd0,ffo[0]!=10'd1023};
				always_comb vstall = 1'b0;
			end
		2:
			begin
				ffo576 (.i({64'd0,avail}), .o(ffo[0]));
				flo576 (.i({64'd0,avail}), .o(ffo[1]));
				always_comb o[0] = {ffo[0][8:0]};
				always_comb o[1] = {ffo[1][8:0]};
				always_comb availv = {5'd0,ffo[1]!=10'd1023,ffo[0]!=10'd1023};
				always_comb vstall = ffo[0]==ffo[1];
			end
		3:
			begin
				ffo576 (.i({64'd0,avail}), .o(ffo[0]));
				flo576 (.i({64'd0,avail}), .o(ffo[1]));
				ffo576 (.i({64'd0,avail & navail0}), .o(ffo[2]));
				always_comb o[0] = {ffo[0][8:0]};
				always_comb o[1] = {ffo[1][8:0]};
				always_comb o[2] = {ffo[2][8:0]};
				always_comb availv = {4'd0,ffo[2]!=10'd1023,ffo[1]!=10'd1023,ffo[0]!=10'd1023};
				always_comb vstall = ffo[0]==ffo[1] || ffo[2]==ffo[0] || ffo[2]==ffo[1];
			end
		4:
			begin
				ffo576 (.i({64'd0,avail}), .o(ffo[0]));
				flo576 (.i({64'd0,avail}), .o(ffo[1]));
				ffo576 (.i({64'd0,avail & navail0}), .o(ffo[2]));
				flo576 (.i({64'd0,avail & navail0}), .o(ffo[3]));
				always_comb o[0] = ffo[0][8:0];
				always_comb o[1] = ffo[1][8:0];
				always_comb o[2] = ffo[2][8:0];
				always_comb o[3] = ffo[3][8:0];
				always_comb availv = {3'd0,ffo[3]!=10'd1023,ffo[2]!=10'd1023,ffo[1]!=10'd1023,ffo[0]!=10'd1023};
				always_comb vstall = ffo[0]==ffo[1] || ffo[2]==ffo[3];
			end
		5:
			begin
				ffo576 (.i({64'd0,avail}), .o(ffo[0]));
				ffo576 (.i({64'd0,avail & navail0}), .o(ffo[1]));
				ffo576 (.i({64'd0,avail & navail0 & navail1}), .o(ffo[2]));
				ffo576 (.i({64'd0,avail & navail2}), .o(ffo[3]));
				ffo576 (.i({64'd0,avail & navail3}), .o(ffo[4]));
				always_comb o[0] = ffo[0][8:0];
				always_comb o[1] = ffo[1][8:0];
				always_comb o[2] = ffo[2][8:0];
				always_comb o[3] = ffo[3][8:0];
				always_comb o[4] = ffo[4][8:0];
				always_comb availv = {2'd0,ffo[4]!=10'd1023,ffo[3]!=10'd1023,ffo[2]!=10'd1023,ffo[1]!=10'd1023,ffo[0]!=10'd1023};
				always_comb vstall = 1'b0;
			end
		default:
			begin
				ffo576 (.i({64'd0,avail}), .o(ffo[0]));
				ffo576 (.i({64'd0,avail & navail1}), .o(ffo[1]));
				ffo576 (.i({64'd0,avail & navail2}), .o(ffo[2]));
				ffo576 (.i({64'd0,avail & navail3}), .o(ffo[3]));
				ffo576 (.i({64'd0,avail & navail4}), .o(ffo[4]));
				ffo576 (.i({64'd0,avail & navail5}), .o(ffo[5]));
				always_comb o[0] = ffo[0][8:0];
				always_comb o[1] = ffo[1][8:0];
				always_comb o[2] = ffo[2][8:0];
				always_comb o[3] = ffo[3][8:0];
				always_comb o[4] = ffo[4][8:0];
				always_comb o[5] = ffo[5][8:0];
				always_comb availv = {1'd0,ffo[5]!=10'd1023,ffo[4]!=10'd1023,ffo[3]!=10'd1023,ffo[2]!=10'd1023,ffo[1]!=10'd1023,ffo[0]!=10'd1023};
				always_comb vstall = 1'b0;
			end
		endcase

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
	end

256:
	begin
		wire [8:0] ffo [0:3];
		wire [255:0] navail1 = ~{256'd1 << ffo[0]};
		wire [255:0] navail2 = ~({256'd1 << ffo[0]}|{256'd1 << ffo[1]});
		wire [255:0] navail3 = ~({256'd1 << ffo[0]}|{256'd1 << ffo[1]}|{256'd1 << ffo[2]});
		wire [255:0] navail4 = ~({256'd1 << ffo[0]}|{256'd1 << ffo[1]}|{256'd1 << ffo[2]}|{256'd1 << ffo[3]});
		wire [255:0] navail5 = ~({256'd1 << ffo[0]}|{256'd1 << ffo[1]}|{256'd1 << ffo[2]}|{256'd1 << ffo[3]}|{256'd1 << ffo[4]});
		case(NNAME)
		1:
			begin
				ffo288 (.i({32'd0,avail}), .o(ffo[0]));
				always_comb o[0] = {ffo[0][7:0]};
				always_comb availv = {6'd0,ffo[0]!=9'd511};
			end
		2:
			begin
				ffo288 (.i({32'd0,avail}), .o(ffo[0]));
				ffo288 (.i({32'd0,avail & navail1}), .o(ffo[1]));
				always_comb o[0] = {ffo[0][7:0]};
				always_comb o[1] = {ffo[1][7:0]};
				always_comb availv = {5'd0,ffo[1]!=9'd511,ffo[0]!=9'd511};
			end
		3:
			begin
				ffo288 (.i({32'd0,avail}), .o(ffo[0]));
				ffo288 (.i({32'd0,avail & navail1}), .o(ffo[1]));
				ffo288 (.i({32'd0,avail & navail2}), .o(ffo[2]));
				always_comb o[0] = {ffo[0][7:0]};
				always_comb o[1] = {ffo[1][7:0]};
				always_comb o[2] = {ffo[2][7:0]};
				always_comb availv = {4'd0,ffo[2]!=9'd511,ffo[1]!=9'd511,ffo[0]!=9'd511};
			end
		4:
			begin
				ffo288 (.i({32'd0,avail}), .o(ffo[0]));
				ffo288 (.i({32'd0,avail & navail1}), .o(ffo[1]));
				ffo288 (.i({32'd0,avail & navail2}), .o(ffo[2]));
				ffo288 (.i({32'd0,avail & navail3}), .o(ffo[3]));
				always_comb o[0] = ffo[0][7:0];
				always_comb o[1] = ffo[1][7:0];
				always_comb o[2] = ffo[2][7:0];
				always_comb o[3] = ffo[3][7:0];
				always_comb availv = {3'd0,ffo[3]!=9'd511,ffo[2]!=9'd511,ffo[1]!=9'd511,ffo[0]!=9'd511};
			end
		5:
			begin
				ffo288 (.i({32'd0,avail}), .o(ffo[0]));
				ffo288 (.i({32'd0,avail & navail1}), .o(ffo[1]));
				ffo288 (.i({32'd0,avail & navail2}), .o(ffo[2]));
				ffo288 (.i({32'd0,avail & navail3}), .o(ffo[3]));
				ffo288 (.i({32'd0,avail & navail4}), .o(ffo[4]));
				always_comb o[0] = ffo[0][7:0];
				always_comb o[1] = ffo[1][7:0];
				always_comb o[2] = ffo[2][7:0];
				always_comb o[3] = ffo[3][7:0];
				always_comb o[4] = ffo[4][7:0];
				always_comb availv = {2'd0,ffo[4]!=9'd511,ffo[3]!=9'd511,ffo[2]!=9'd511,ffo[1]!=9'd511,ffo[0]!=9'd511};
			end
		default:
			begin
				ffo288 (.i({32'd0,avail}), .o(ffo[0]));
				ffo288 (.i({32'd0,avail & navail1}), .o(ffo[1]));
				ffo288 (.i({32'd0,avail & navail2}), .o(ffo[2]));
				ffo288 (.i({32'd0,avail & navail3}), .o(ffo[3]));
				ffo288 (.i({32'd0,avail & navail4}), .o(ffo[4]));
				ffo288 (.i({32'd0,avail & navail5}), .o(ffo[5]));
				always_comb o[0] = ffo[0][7:0];
				always_comb o[1] = ffo[1][7:0];
				always_comb o[2] = ffo[2][7:0];
				always_comb o[3] = ffo[3][7:0];
				always_comb o[4] = ffo[4][7:0];
				always_comb o[5] = ffo[5][7:0];
				always_comb availv = {1'd0,ffo[5]!=9'd511,ffo[4]!=9'd511,ffo[3]!=9'd511,ffo[2]!=9'd511,ffo[1]!=9'd511,ffo[0]!=9'd511};
			end
		endcase

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
	end
/*
128:
	begin
		wire [5:0] ffo [0:3];
		// ToDo: use 128 bit bitmap
		ffo48 uffo0 (.i({16'd0,avail[ 31:  0]}), .o(ffo[0]));
		ffo48 uffo1 (.i({16'd0,avail[ 63: 32]}), .o(ffo[1]));
		ffo48 uffo2 (.i({16'd0,avail[ 95: 64]}), .o(ffo[2]));
		ffo48 uffo3 (.i({16'd0,avail[127: 96]}), .o(ffo[3]));

		always_comb o[0] = {2'd0,ffo[0][4:0]};
		always_comb o[1] = {2'd1,ffo[1][4:0]};
		always_comb o[2] = {2'd2,ffo[2][4:0]};
		always_comb o[3] = {2'd3,ffo[3][4:0]};

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
	end
*/
endcase
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
	next_avail = avail;

	foreach(ov[n6])
		if (ov[n6] & en) next_avail[o[n6]] = 1'b0;
	foreach(fpush[n6])
		if (fpush[n6]) next_avail[rtags2free[n6]] = 1'b1;

end

always_ff @(posedge clk)
if (rst)
	avail <= {Qupls4_pkg::PREGS{1'b1}};
else
	avail <= next_avail;

// Freed tags cannot be reused for 15 clock cycles.
generate begin : gFree
	for (g = 0; g < NNAME; g = g + 1)
		vtdl #(.WID($bits(cpu_types_pkg::pregno_t)), .DEP(16)) uaramp1 (.clk(clk), .ce(1'b1), .a(15), .d(tags2free[g]), .q(rtags2free[g]));
end
endgenerate

endmodule
