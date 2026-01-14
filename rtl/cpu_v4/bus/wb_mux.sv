import wishbone_pkg::*;

module wb_mux(rst_i, clk_i, req_i, req_o, resp_o, resp_i);
parameter NPORT = 8;
input rst_i;
input clk_i;
input wishbone_pkg::wb_cmd_request256_t [NPORT-1:0] req_i;
output wishbone_pkg::wb_cmd_request256_t req_o;
output wishbone_pkg::wb_cmd_response256_t [NPORT-1:0] resp_o;
input wishbone_pkg::wb_cmd_response256_t resp_i;

integer n1,n2;
reg [NPORT-1:0] req_cyc;
wire [NPORT-1:0] req_grant;
wire [$clog2(NPORT):0] req_grant_enc;
reg [NPORT-1:0] req_grant1;
reg [$clog2(NPORT):0] req_grant_enc1;
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
	holdn = req_cyc & req_grant1;
always_comb
	hold = |holdn;
always_comb
	lock = lockn[req_grant_enc1];

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
always_ff @(posedge clk_i)
	req_grant1 <= req_grant;
always_ff @(posedge clk_i)
	req_grant_enc1 <= req_grant_enc;

always_ff @(posedge clk_i)
	req_o <= req_i[req_grant_enc];
always_ff @(posedge clk_i)
begin
	// Endure all responses are set to something, otherwise a latch
	// will be inferred.
	for (n2 = 0; n2 < NPORT; n2 = n2 + 1)
		resp_o[n2] <= {$bits(wb_cmd_response256_t){1'b0}};
	resp_o[req_grant_enc] <= resp_i;
end
	
endmodule
