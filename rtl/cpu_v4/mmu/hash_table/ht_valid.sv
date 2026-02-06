import hash_table_pkg::*;
import wishbone_pkg::*;

module ht_valid(bus, state, vb);
parameter WID=32;
parameter DEP=256;
wb_bus_interface.slave bus;
input [1:0] state;
output reg [WID-1:0] vb [0:DEP-1];
hte_t hte;

integer n,n2;

initial begin
	for (n2 = 0; n2 < $size(vb); n2 = n2 + 1)
		vb[n2] = {WID{1'b0}};
end

always_comb
	hte = {bus.req.dat,32'd0};

always_ff @(posedge bus.clk)
if (bus.rst)
    ;
//	foreach (vb[n])
//		vb[n] <= {WID{1'd0}};
else begin
	if (state==2'd1 && bus.req.adr[2])
		vb[bus.req.adr[15:8]][bus.req.adr[7:3]] <= hte.v;
end

endmodule
