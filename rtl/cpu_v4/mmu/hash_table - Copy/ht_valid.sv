import hash_table_pkg::*;
import wishbone_pkg::*;

module ht_valid(rst, clk, state, req, vb);
input rst;
input clk;
input [2:0] state;
input wb_cmd_request64_t req;
output reg [8191:0] vb;
ptge_t ptge;

always_comb
	ptge = req.dat;

always_ff @(posedge clk)
if (rst)
	vb <= 8192'd0;
else begin
	if (state==3'd1)
		vb[req.adr[15:3]] <= ptge.v;
end

endmodule
