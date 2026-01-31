// Accumulate a sideways add of stomp.

// How is this going to work? What if stomped is active for more than one
// cycle?

import Qupls4_pkg::*;

module Qupls4_count_stomped(rst, clk, ce, cmtcnt, head, rob, stomp, count);
parameter WID=40;
input rst;
input clk;
input ce;
input [2:0] cmtcnt;
input cpu_types_pkg::rob_ndx_t [7:0] head;
input Qupls4_pkg::rob_entry_t [ROB_ENTRIES-1:0] rob;
input [Qupls4_pkg::ROB_ENTRIES-1:0] stomp;
output reg [WID-1:0] count;

integer n31;



always_ff @(posedge clk)
if (rst)
	count = {WID{1'b0}};
else begin
	foreach (stomp[n31])
		count = count + stomp[n31];
	if (ce) begin
		if (cmtcnt > 3)
			count = count 
				+ rob[head[0]].stomped 
				+ rob[head[1]].stomped 
				+ rob[head[2]].stomped 
				+ rob[head[3]].stomped 
			;
		else if (cmtcnt > 2)
			count = count 
				+ rob[head[0]].stomped 
				+ rob[head[1]].stomped 
				+ rob[head[2]].stomped 
			;
		else if (cmtcnt > 1)
			count = count 
				+ rob[head[0]].stomped 
				+ rob[head[1]].stomped 
			;
		else if (cmtcnt > 0)
			count = count 
				+ rob[head[0]].stomped 
			;
	end
end

endmodule
