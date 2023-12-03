import fta_bus_pkg::*;

module Qupls_top(cpu_resetn, xclk, irq_i, vect_i, wr, adr, dati, dato, ack);
input cpu_resetn;
input xclk;
input [2:0] irq_i;
input [8:0] vect_i;
output wr;
output [31:0] adr;
input [63:0] dati;
output [63:0] dato;
input ack;

fta_cmd_request128_t fta_req;
fta_cmd_response128_t fta_resp;

assign wr = fta_req.we;
assign adr = fta_req.padr;
assign dato = fta_req.data1;
assign fta_resp.dat = dati;
assign fta_resp.ack = ack;

wire rst = ~cpu_resetn;

Qupls ucpu1 (
	.coreno_i(6'd1),
	.rst_i(rst),
	.clk_i(xclk),
	.clk2x_i(xclk),
	.irq_i(irq_i),
	.vect_i(vect_i),
	.fta_req(fta_req),
	.fta_resp(fta_resp),
	.snoop_adr(),
	.snoop_v(),
	.snoop_cid()
);	

endmodule
