`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2026  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// Qupls4_rat_tb.v
//  - Test Bench for RAT
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
// ============================================================================
//
import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_RAT_tb();

integer n1;
reg clk;
reg rst;
reg [7:0] state;
reg [7:0] freestate;
reg [7:0] value;
reg [7:0] count;

reg alloc_chkpt = 1'b0;
cpu_types_pkg::checkpt_ndx_t miss_cp, cndx;
reg restore;
wire restored;
cpu_types_pkg::aregno_t [11:0] rn;
reg [11:0] rnv;
reg [2:0] rng [0:11];
cpu_types_pkg::pregno_t [11:0] prn;
wire [11:0] prnv;
reg [3:0] wr;
cpu_types_pkg::aregno_t [3:0] wra;
cpu_types_pkg::pregno_t [3:0] wrra;
reg [3:0] wrport_v;
cpu_types_pkg::aregno_t [3:0] wrport_aRt;
cpu_types_pkg::pregno_t [3:0] wrport_Rt;
cpu_types_pkg::value_t [3:0] wrport_res;
reg [3:0] cmtav, cmtiv;
cpu_types_pkg::aregno_t [3:0] cmtaa;
cpu_types_pkg::pregno_t [3:0] cmtap;
cpu_types_pkg::value_t [3:0] cmtaval;

cpu_types_pkg::pregno_t [3:0] tags2free;
reg [3:0] freevals;
wire stall;
wire rst_busy;

initial begin
	#1 clk <= 1'b0;
	#5 rst <= 1'b1;
	#100 rst <= 1'b0;
end

always #2.5 clk <= ~clk;

Qupls4_rat urat1
(
	.rst(rst),
	.clk(clk),
	// Pipeline control
	.en(1'b1),
	.en2(1'b1),
	.stall(),

	.alloc_chkpt(alloc_chkpt),	// allocate a new checkpoint - flow control encountered
	.cndx(cndx),					// current checkpoint index
	.miss_cp(miss_cp),			// checkpoint of miss location - to be restored
	.avail_i({256{1'b1}}),			// list of available registers from renamer
	.tail(),
	.rob(),

	// Which instructions being queued are branches
	.nq(), 
	.qbr(),
	
	// From reservation read requests: 
	.rn(rn),				// architectural register number
	.rnv(rnv),			// reg number request valid
	.rng(rng),			// instruction number within group
	.rn_cp(0), 		// checkpoint of requester
	.st_prn(),
	.rd_cp(),
	.prn(prn), 			// the mapped physical register number
	.prv(prnv), 			// map valid indicator
	.prn_i(),		// register for valid bit lookup

	// From decode: destination register writes, one per instruction, four instructions.
	.is_move(4'b0),
	.wr(wr), 							// which port is aactive 
	.wra(wra),					// architectural register number
	.wrra(wrra),							// physical register number
	.wra_cp(0),			// checkpoint in use

	// Register file write signals.
	.wrport0_v(wrport_v),		// which port is being written
	.wrport0_aRt(wrport_aRt),	// the architectural register used
	.wrport0_Rt(wrport_Rt),		// The physical register used
	.wrport0_cp(0),		// The checkpoint
	.wrport0_res(wrport_res),	// and the value written
	
	// Commit stage signals
	.cmtav(cmtav),			// which commits are valid
	.cmtaiv(cmtiv),			// committing invalid instruction
	.cmta_cp(0),		// commit checkpoint
	.cmtaa(cmtaa),			// architectural register committed
	.cmtap(cmtap), 			// physical register committed.
	.cmtaval(cmtaval),		// value committed
	.cmtbr(),						// committing a branch

	.restore(restore),			// signal to restore a checkpoint
	.restore_list(),
	.restored(restored),
	.tags2free(tags2free),
	.freevals(freevals),
	.backout(),
	.fcu_id(),		// the ROB index of the instruction causing backout
	.bo_wr(),
	.bo_areg(),
	.bo_preg(),
	.bo_nreg()
);

always @(posedge clk)
if (rst) begin
	state <= 8'h00;
	freestate <= 8'd0;
	value <= $urandom(0);
	count <= 8'd0;
end
else begin
// Just pulse the alloc signals.
if (TRUE) begin
	alloc_chkpt <= 1'b0;
	miss_cp <= 5'd0;
	restore <= 1'b0;
	wr <= 4'h0;
	wrport_v <= 4'h0;
	cmtav <= 4'h0;
	cmtiv <= 4'h0;
	if (($urandom() % 100)==1)
		alloc_chkpt <= 1'b1;
	if (($urandom() % 25)==1) begin
		miss_cp <= $urandom() % 32;
		restore <= 1'b1;
	end
	if (restore)
		cndx <= miss_cp;

case(state)
8'h00:
		if (TRUE)
			state <= state + 1;
8'h01:
		state <= state + 1;
8'h02:
	begin
		state <= state + 1;
	end
8'h03:
	begin
		state <= state + 1;
	end
8'h04:
	begin
		state <= state + 1;
	end
8'h05:
	begin
		state <= state + 1;
	end
8'h06:
	begin
		state <= state + 1;
	end
8'd7:
	begin
		for (n1 = 0; n1 < 12; n1 = n1 + 1) begin
			rn[n1] <= $urandom() % 256;
			rnv[n1] <= 1'b1;
			rng[n1] <= $urandom() % 4;
		end
		state <= state + 1;
	end
8'd8:
	begin
		if (state==($urandom() % 8) + 8) begin
			wr <= $urandom() % 16;
			for (n1 = 0; n1 < 4; n1 = n1 + 1) begin
				wra[n1] <= $urandom() % 256;
				wrra[n1] <= $urandom() % 1024;
			end
		end
		if (state==($urandom() % 8) + 8) begin
			wrport_v <= $urandom() % 16;
			for (n1 = 0; n1 < 4; n1 = n1 + 1) begin
				wrport_aRt[n1] <= $urandom() % 256;
				wrport_Rt[n1] <= $urandom() % 1024;
				wrport_res[n1] <= {$urandom(),$urandom()};
			end
		end
		if (state==($urandom() % 8) + 8) begin
			cmtav <= $urandom() % 16;
			cmtiv <= $urandom() % 16;
			for (n1 = 0; n1 < 4; n1 = n1 + 1) begin
				cmtaa[n1] <= $urandom() % 256;
				cmtap[n1] <= $urandom() % 1024;
				cmtaval[n1] <= {$urandom(),$urandom()};
			end
		end
		// Try and empty out the fifo to see what happens.
		if (count < 25) begin
			count <= count + 1;
		end
		else
			state <= state + 1;
	end
default:
	if (TRUE) begin
//		ns_cndx <= ns_cndx + 2'd1;
		state <= state + 1;
		if (state >= 140)
			state <= 8'd0;
	end
endcase
end

case(freestate)
8'd0:
	if (state > 8'd140 || stall) begin
	end
endcase

end

endmodule
