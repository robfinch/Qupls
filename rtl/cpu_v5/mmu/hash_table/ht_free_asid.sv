import const_pkg::*;

module ht_free_asid(rst, clk, state, max_count, free_asid);
input rst;
input clk;
input [2:0] state;
input [9:0] max_count;
output reg free_asid;

reg [9:0] count;

always_ff @(posedge clk)
if (rst)
	count <= 10'd0;
else begin
	if (!free_asid) begin
		count <= count + 10'd1;
		if (count==max_count)
			count <= 10'd0;
	end
end

always_ff @(posedge clk)
if (rst)
	free_asid <= FALSE;
else begin
	if (count==max_count)
		free_asid <= TRUE;
	if (free_asid && state==3'd5)
		free_asid <= FALSE;
end

endmodule
