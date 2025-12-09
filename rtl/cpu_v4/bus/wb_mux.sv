import wishbone_pkg::*;

module wb_mux(rst_i, clk_i, req_i, req_o, resp_o, resp_i);
parameter NPORT = 8;
input rst_i;
input clk_i;
input wishbone_pkg::wb_cmd_request256_t [NPORT-1:0] req_i;
output wishbone_pkg::wb_cmd_request256_t req_o;
output wishbone_pkg::wb_cmd_response256_t [NPORT-1:0] resp_o;
input wishbone_pkg::wb_cmd_response256_t [NPORT-1:0] resp_i;

integer n1;
reg [NPORT-1:0] req_cyc;
wire [NPORT-1:0] req_grant;
reg [$clog2(NPORT):0] req_grant_enc;
reg hold, lock;
reg [NPORT-1:0] holdn;
reg [NPORT-1:0] lockn;


// Strip out cyc signal from requests.
always_comb
	for (n1 = 0; n1 < NPORT; n1 = n1 + 1) begin
		req_cyc[n1] = req_i[n1].cyc;
		lockn[n1] = req_i[n1].lock;
	end

always_comb
	holdn = req_cyc & req_grant;
always_comb
	hold = |holdn;
always_comb
	lock = lockn[req_grant_enc];

RoundRobinArbiter #(
  .NumRequests(NPORT)
) 
urrreq1
(
  .rst(rst_i),
  .clk(clk_i),
  .ce(1'b1),
  .hold(hold|lock),
  .req(req_cyc),
  .grant(req_grant),
  .grant_enc(req_grant_enc)
);

always_comb
	req_o = req_i[req_grant_enc];
always_comb
	resp_o[req_grant_enc] = resp_i;
	
endmodule
