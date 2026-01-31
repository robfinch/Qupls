import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_cpytgt_count(rst, clk, ce, cmtcnt, head, rob, count);
parameter WID=40;
input rst;
input clk;
input ce;
input [2:0] cmtcnt;
input cpu_types_pkg::rob_ndx_t [7:0] head;
input Qupls4_pkg::rob_entry_t [ROB_ENTRIES-1:0] rob;
output reg [WID-1:0] count;

always_ff @(posedge clk)
if (rst)
	count <= {WID{1'b0}};
else begin
	if (ce) begin
		if (cmtcnt > 3)
			count <= count 
				+ rob[head[0]].op.decbus.cpytgt 
				+ rob[head[1]].op.decbus.cpytgt
				+ rob[head[2]].op.decbus.cpytgt
				+ rob[head[3]].op.decbus.cpytgt
			;
		else if (cmtcnt > 2)
			count <= count 
				+ rob[head[0]].op.decbus.cpytgt 
				+ rob[head[1]].op.decbus.cpytgt
				+ rob[head[2]].op.decbus.cpytgt
			;
		else if (cmtcnt > 1)
			count <= count 
				+ rob[head[0]].op.decbus.cpytgt 
				+ rob[head[1]].op.decbus.cpytgt
			;
		else if (cmtcnt > 0)
			count <= count 
				+ rob[head[0]].op.decbus.cpytgt 
			;
	end
end

endmodule
