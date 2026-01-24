// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2026  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
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
// 1150 LUTs / 2100 FFs / 340 MHz
// ============================================================================

import Qupls4_pkg::*;

module Qupls4_func_result_queue(rst_i, clk_i, stomp_i, rd_i, we_i, rse_i,
	tag_i, res_i, cp_i, we_o, pRt_o, aRt_o, tag_o, res_o, cp_o, empty, full);
parameter DEP = 5'd12;
input rst_i;
input clk_i;
input Qupls4_pkg::rob_bitmask_t stomp_i;
input rd_i;
input [8:0] we_i;
input Qupls4_pkg::reservation_station_entry_t rse_i;
input [7:0] tag_i;
input value_t res_i;
input cpu_types_pkg::checkpt_ndx_t cp_i;
output reg [8:0] we_o;
output cpu_types_pkg::pregno_t pRt_o;
output cpu_types_pkg::aregno_t aRt_o;
output reg [7:0] tag_o;
output value_t res_o;
output cpu_types_pkg::checkpt_ndx_t cp_o;
output reg empty;
output reg full;

typedef struct packed
{
	logic [8:0] we;
	pregno_t pRd;
	aregno_t aRd;
	logic [7:0] tag;
	value_t argT;
	value_t res;
	cpu_types_pkg::rob_ndx_t rndx;
	cpu_types_pkg::checkpt_ndx_t cndx;
} frq_entry_t;

integer n1,n2;
reg [4:0] cnt;
reg [4:0] wr_ptr;
reg [4:0] rd_ptr;
frq_entry_t [DEP-1:0] mem;
rob_ndx_t rndx;
reg wr_en;
reg rd_en;
wire wr_clk = clk_i;
wire rst = rst_i;
value_t argT_o;					// dummy placeholder
frq_entry_t din;

initial begin
	foreach (mem[n2])
		mem[n2] = {$bits(frq_entry_t){1'b0}};
end

always_ff @(posedge clk_i)
	din <= {
		we_i,
		rse_i.nRd,
		rse_i.aRd,
		tag_i,
		rse_i.arg[NOPER-1],
		res_i,
		rse_i.rndx,
		rse_i.cndx
	};

frq_entry_t dout;

always_comb
	empty = cnt == 5'd0;
always_comb
	full = cnt > (DEP - 5);

always_comb
	{we_o,pRt_o,aRt_o,tag_o,argT_o,res_o,rndx,cp_o} = dout;
always_comb
	rd_en = rd_i & ~rst & ~empty;
always_ff @(posedge clk_i)
	wr_en <= |we_i & ~rst && cnt < DEP - 2;

always_ff @(posedge clk_i)
begin
	if (wr_en)
		mem[wr_ptr] <= din;
	for (n1 = 0; n1 < DEP; n1 = n1 + 1) begin
		if (stomp_i[mem[n1].rndx])
			mem[n1].res <= mem[n1].argT;
	end
end

always_ff @(posedge clk_i)
begin
	if (rst_i)
		wr_ptr <= 5'd0;
	else if (wr_en) begin
		wr_ptr <= wr_ptr + 5'd1;
		if (wr_ptr==DEP-1)
			wr_ptr <= 5'd0;
	end
end

always_ff @(posedge clk_i)
	if (rst_i)
		rd_ptr <= 5'd0;
	else if (rd_en) begin
		rd_ptr <= rd_ptr + 5'd1;
		if (rd_ptr==DEP-1)
			rd_ptr <= 5'd0;
	end

always_comb
begin
	dout = mem[rd_ptr];
	dout.res = stomp_i[mem[rd_ptr].rndx] ? mem[rd_ptr].argT : mem[rd_ptr].res;
end

always_comb
	if (rd_ptr > wr_ptr)
		cnt = wr_ptr + (DEP - rd_ptr);
	else
		cnt = wr_ptr - rd_ptr;
			
endmodule
