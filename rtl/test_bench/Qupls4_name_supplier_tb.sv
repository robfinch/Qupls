`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2025-2026  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// Qupls4_name_supplier_tb.v
//  - Test Bench for register name supplier
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

module Qupls4_name_supplier_tb();

reg clk;
reg rst;
reg [7:0] state;
reg [7:0] freestate;
reg [7:0] value;
reg [7:0] count;

cpu_types_pkg::pregno_t [3:0] tags2free;
reg [3:0] freevals;
reg alloc0;
reg alloc1;
reg alloc2;
reg alloc3;
cpu_types_pkg::pregno_t [3:0] ns_o;
wire [3:0] nsv_o;
cpu_types_pkg::pregno_t wo0;
cpu_types_pkg::pregno_t wo1;
cpu_types_pkg::pregno_t wo2;
cpu_types_pkg::pregno_t wo3;
wire wv0;
wire wv1;
wire wv2;
wire wv3;
wire stall;
wire rst_busy;
cpu_types_pkg::rob_ndx_t [3:0] ns_whrndx;
cpu_types_pkg::checkpt_ndx_t [3:0] ns_cndx;
cpu_types_pkg::rob_ndx_t [3:0] ns_rndx;
cpu_types_pkg::pregno_t [3:0] ns_dstreg;
wire [3:0] ns_dstregv;
wire [Qupls4_pkg::PREGS-1:0] avail;

initial begin
	#1 clk <= 1'b0;
	#5 rst <= 1'b1;
	#100 rst <= 1'b0;
end

always #2.5 clk <= ~clk;


Qupls4_reg_name_supplier5 #(.NFTAGS(4)) uns4 (
//parameter NFTAGS = 4;			// Number of register freed per clock.
	.rst(rst),
	.clk(clk),
	.en(!stall),
	.tags2free(tags2free),		// register tags to free
	.freevals(freevals),					// bitmnask indicating which tags to free
	.o(ns_o),
	.ov(nsv_o),
	.ns_alloc_req({alloc3,alloc2,alloc1,alloc0}),
	.ns_whrndx(ns_whrndx),
	.ns_cndx(ns_cndx),
	.ns_rndx(ns_rndx),
	.ns_dstreg(ns_dstreg),
	.ns_dstregv(ns_dstregv),
	.avail(avail),
	.stall(stall),		// stall enqueue while waiting for register availability
	.rst_busy(rst_busy)
);

always @(posedge clk)
if (rst) begin
	state <= 8'h00;
	freestate <= 8'd0;
	alloc0 <= 1'b0;
	alloc1 <= 1'b0;
	alloc2 <= 1'b0;
	alloc3 <= 1'b0;
	freevals <= 4'h0;
	tags2free[0] <= 9'd0;
	tags2free[1] <= 9'd0;
	tags2free[2] <= 9'd0;
	tags2free[3] <= 9'd0;
	value <= $urandom(0);
	count <= 8'd0;
	ns_cndx <= 4'd0;
end
else begin
// Just pulse the alloc signals.
if (!stall) begin
alloc0 <= 1'b0;
alloc1 <= 1'b0;
alloc2 <= 1'b0;
alloc3 <= 1'b0;
case(state)
8'h00:
		if (!rst_busy)
			state <= state + 1;
8'h01:
		state <= state + 1;
8'h02:
	begin
		alloc0 <= 1'b1;
		state <= state + 1;
	end
8'h03:
	begin
		alloc1 <= 1'b1;
		state <= state + 1;
	end
8'h04:
	begin
		alloc2 <= 1'b1;
		state <= state + 1;
	end
8'h05:
	begin
		alloc3 <= 1'b1;
		state <= state + 1;
	end
8'h06:
	begin
		state <= state + 1;
	end
8'd7:
	begin
		alloc0 <= 1'b1;
		alloc1 <= 1'b1;
		alloc2 <= 1'b1;
		alloc3 <= 1'b1;
		ns_whrndx[0] <= 0;
		ns_whrndx[0] <= 0;
		ns_whrndx[0] <= 0;
		ns_whrndx[0] <= 0;
		state <= state + 1;
	end
8'd8:
	begin
		// Try and empty out the fifo to see what happens.
		if (count < 25) begin
			alloc0 <= 1'b1;
			count <= count + 1;
		end
		else
			state <= state + 1;
	end
default:
	if (!stall) begin
		{alloc3,alloc2,alloc1,alloc0} <= $urandom();
		ns_whrndx[0] <= $urandom();
		ns_whrndx[1] <= $urandom();
		ns_whrndx[2] <= $urandom();
		ns_whrndx[3] <= $urandom();
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
		tags2free[0] <= $urandom() % 512;//ns_o[0];
		tags2free[1] <= $urandom() % 512;//ns_o[1];
		tags2free[2] <= $urandom() % 512;//ns_o[2];
		tags2free[3] <= $urandom() % 512;//ns_o[3];
		freevals[0] <= $urandom() % 2;//nsv_o[0];
		freevals[1] <= $urandom() % 2;//nsv_o[1];
		freevals[2] <= $urandom() % 2;//nsv_o[2];
		freevals[3] <= $urandom() % 2;//nsv_o[3];
	end
endcase

end

endmodule
