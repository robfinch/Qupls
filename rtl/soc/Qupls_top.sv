import fta_bus_pkg::*;

module Qupls_top(cpu_resetn, xclk, irq_i, vect_i, wr, adr, dati, dato, ack, tido, tidi);
input cpu_resetn;
input xclk;
input [31:0] irq_i;
input [8:0] vect_i;
output wr;
output [31:0] adr;
input [63:0] dati;
output [63:0] dato;
input ack;
output fta_tranid_t tido;
input fta_tranid_t tidi;

fta_cmd_request128_t fta_req;
fta_cmd_response128_t fta_resp;

assign wr = fta_req.we;
assign adr = fta_req.padr;
assign dato = fta_req.data1;
assign tido = fta_req.tid;
assign fta_resp.dat = dati;
assign fta_resp.ack = ack;
assign fta_resp.tid = tidi;

wire rst = ~cpu_resetn;

Qupls_mpu ucpu1 (
	.coreno_i(6'd1),
	.rst_i(rst),
	.clk_i(xclk),
	.clk2x_i(xclk),
	.irq_bus(irq_i),
	.fta_req(fta_req),
	.fta_resp(fta_resp),
	.clk0(1'b0),
	.gate0(1'b0),
	.out0(),
	.clk1(1'b0),
	.gate1(1'b0),
	.out1(),
	.clk2(1'b0),
	.gate2(1'b0),
	.out2(),
	.clk3(1'b0),
	.gate3(1'b0),
	.out3()
);	

endmodule
