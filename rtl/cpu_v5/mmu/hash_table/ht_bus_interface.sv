import wishbone_pkg::*;

module ht_bus_interface(cs, bus, asid, max_bounce);
input cs;
wb_bus_interface.slave bus;
output reg [9:0] asid;
output reg [7:0] max_bounce;

always_ff @(posedge bus.clk)
if (bus.rst) begin
	max_bounce <= 8'd63;
	asid <= 10'd0;
end
else begin
	if (cs) begin
		if (bus.req.cyc & bus.req.stb) begin
			casez(bus.req.adr[16:0])
			17'b10000010000001100:	asid <= bus.req.dat[9:0];
			17'b10000010000010000:	max_bounce <= bus.req.dat[7:0];
			default:	;
			endcase
		end
	end
end

endmodule
