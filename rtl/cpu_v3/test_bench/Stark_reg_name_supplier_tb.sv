`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Stark_reg_name_supplier_tb.v
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
// ============================================================================

import Stark_pkg::*;

module Stark_reg_name_supplier_tb();
parameter NRENAME = 8;

integer n1,count=0;
reg rst;
reg clk;
reg restore;
reg [Stark_pkg::PREGS-1:0] avail, avail_r;
reg [NRENAME-1:0] alloc, alloc_r;
reg [31:0] a;
pregno_t [NRENAME-1:0] o;
pregno_t [3:0] tags2free;
reg [3:0] freevals;
reg [NRENAME-1:0] ov;

initial begin
	rst = 1'b0;
	clk = 1'b0;
	a = $urandom(1);
	#20 rst = 1;
	#50 rst = 0;
end

always #5
	clk = ~clk;

always_ff @(posedge clk)
begin
	if (rst) begin
		count <= 0;
		for (n1 = 0; n1 < NRENAME; n1 = n1 + 1)
			tags2free[n1] <= 9'd0;
		freevals <= 12'h000;
		$display("Reset");
		$display("************************************************");
	end
	$display("count:%d", count);
	if (stall)
		$display("**** stall ****");
	count <= count + 2'd1;
	alloc <= $urandom();
	alloc_r <= alloc;
	avail_r <= avail;
	$display("avail: %h", avail_r);
	$display("   alloc    ");
	$display("%b", alloc);
	$display("   stalla   ");
	$display("%b", uns3.stalla);
	for (n1 = 0; n1 < NRENAME; n1 = n1 + 1) begin
		$display("%d%c", o[n1], ov[n1]?"v": " ");
	end
	if (count > 10) begin
		for (n1 = 0; n1 < 4; n1 = n1 + 1)
			tags2free[n1] <= $urandom() % Stark_pkg::PREGS;
		freevals <= 4'hF;
	end
	restore = (count % 20) == 0;
	$display("freevals:%b", freevals);
	for (n1 = 0; n1 < NRENAME; n1 = n1 + 1)
		$display("free tag: %d", tags2free[n1]);
end

Stark_reg_name_supplier3 #(NRENAME) uns3
(
	.rst(rst),
	.clk(clk),
	.en(1'b1),
	.restore(restore),
	.restore_list({512{count[6]}}),
	.tags2free(tags2free),
	.freevals(freevals),
	.bo_wr(1'b0),
	.bo_preg(8'd0),
	.alloc(alloc),
	.o(o),
	.ov(ov),
	.avail(avail),
	.stall(stall),
	.rst_busy()
);

endmodule
