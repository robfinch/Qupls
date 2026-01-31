// Valid instructions committed.

import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_tot_valid_insn(rst, clk, ce, head, rob, cmtcnt, count);
parameter WID=40;
input rst;
input clk;
input ce;
input cpu_types_pkg::rob_ndx_t [7:0] head;
input Qupls4_pkg::rob_entry_t [Qupls4_pkg::ROB_ENTRIES-1:0] rob;
input [2:0] cmtcnt;
(* keep *)
output reg [WID-1:0] count;

integer n1;
genvar g;
reg [3:0] sum [0:7];

generate begin : gSums
	always_comb
		sum[0] = 4'd0;
	for (g = 1; g < 8; g = g + 1)
		always_comb
			for (n1 = 0; n1 < g; n1 = n1 + 1)
				if (n1==0)
					sum[g] = |rob[head[n1]].v;
				else
					sum[g] = sum[g] + |rob[head[n1]].v;
end
endgenerate

always_ff @(posedge clk)
if (rst)
	count <= {WID{1'b0}};
else begin
	if (ce)
		count <= count + sum[cmtcnt];
end

endmodule
