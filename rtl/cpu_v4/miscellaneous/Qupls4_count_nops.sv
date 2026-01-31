import Qupls4_pkg::*;

module Qupls4_count_nops(rst, clk, ce, cmtcnt, head, rob, count);
parameter WID=40;
input rst;
input clk;
input ce;
input cpu_types_pkg::rob_ndx_t [7:0] head;
input Qupls4_pkg::rob_entry_t [Qupls4_pkg::ROB_ENTRIES-1:0] rob;
input [2:0] cmtcnt;
output reg [WID-1:0] count;

always @(posedge clk)
if (rst)
	count <= 64'd0;
else begin
	if (ce) begin
		case (cmtcnt)
		3'd4:
			count <= count +
				(|rob[head[0]].v && rob[head[0]].op.decbus.nop) +
				(|rob[head[1]].v && rob[head[1]].op.decbus.nop) +
				(|rob[head[2]].v && rob[head[2]].op.decbus.nop) +
				(|rob[head[3]].v && rob[head[3]].op.decbus.nop)
				;
		3'd3:
			count <= count +
				(|rob[head[0]].v && rob[head[0]].op.decbus.nop) +
				(|rob[head[1]].v && rob[head[1]].op.decbus.nop) +
				(|rob[head[2]].v && rob[head[2]].op.decbus.nop)
				;
		3'd2:
			count <= count +
				(|rob[head[0]].v && rob[head[0]].op.decbus.nop) +
				(|rob[head[1]].v && rob[head[1]].op.decbus.nop)
				;
		3'd1:
			count <= count +
				(|rob[head[0]].v && rob[head[0]].op.decbus.nop)
				;
		default:	;				
		endcase
	end
end

endmodule
