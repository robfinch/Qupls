// 450 LUTs / 1200 FFs

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
	value_t argD;
	value_t res;
	cpu_types_pkg::rob_ndx_t rndx;
	cpu_types_pkg::checkpt_ndx_t cndx;
} frq_entry_t;

integer n1;
reg [4:0] cnt;
reg [4:0] wr_ptr;
reg [4:0] rd_ptr;
frq_entry_t [DEP-1:0] mem;
wire data_valid;
wire rd_rst_busy;
wire wr_rst_busy;
wire wr_clk = clk_i;
wire rst = rst_i;
value_t argD_o;					// dummy placeholder
frq_entry_t din = {
	we_i,
	rse_i.nRd,
	rse_i.aRd,
	tag_i,
	rse_i.argD,
	res_i,
	rse_i.rndx,
	rse_i.cndx
};
frq_entry_t dout;

reg wr_en1, wr_en;
reg rd_en;

always_comb
	empty = cnt == 5'd0;
always_comb
	full = cnt > (DEP - 5);

always_comb
	{we_o,pRt_o,aRt_o,tag_o,argD_o,res_o,cp_o} = dout;
always_comb
	rd_en = rd_i & ~rst;
always_comb
	wr_en1 = |we_i;
always_comb
	wr_en = wr_en1 & ~rst && cnt < DEP - 2;

always @(posedge clk_i)
begin
	if (rst_i)
		wr_ptr <= 5'd0;
	else if (wr_en) begin
		mem[wr_ptr] <= din;
		wr_ptr <= wr_ptr + 5'd1;
	end
	for (n1 = 0; n1 < DEP; n1 = n1 + 1) begin
		if (stomp_i[mem[n1].rndx])
			mem[n1].res <= mem[n1].argD;
	end
end

always @(posedge clk_i)
	if (rst_i)
		rd_ptr <= 5'd0;
	else if (rd_en)
		rd_ptr <= rd_ptr + 5'd1;

always_comb
begin
	dout = mem[rd_ptr];
	dout.res = stomp_i[mem[rd_ptr].rndx] ? mem[rd_ptr].argD : mem[rd_ptr].res;
end

always_comb
	if (rd_ptr > wr_ptr)
		cnt <= wr_ptr + (DEP - rd_ptr);
	else
		cnt <= wr_ptr - rd_ptr;
			
endmodule
