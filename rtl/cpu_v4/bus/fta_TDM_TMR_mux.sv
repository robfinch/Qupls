// 2900 LUTs / 10600 FFs

import const_pkg::*;
import fta_bus_pkg::*;

module fta_TDM_TMR_mux(rst_i, clk_i, cmd_i, cmd_o, resp_i, resp_o, busy_o);
parameter NPORT = 8;
input rst_i;
input clk_i;
input fta_bus_pkg::fta_cmd_request256_t [NPORT-1:0] cmd_i;
output fta_bus_pkg::fta_cmd_request256_t cmd_o;
input fta_bus_pkg::fta_cmd_response256_t resp_i;
output fta_bus_pkg::fta_cmd_response256_t [NPORT-1:0] resp_o;
output reg [NPORT-1:0] busy_o;

integer n1,n2,n3,n4,n5,n6;
wire [$clog2(NPORT)-1:0] sel;
reg [NPORT-1:0] cmd_cyc;
wire [NPORT-1:0] cmd_grant;
wire [$clog2(NPORT):0] cmd_grant_enc, cmd_grant_enc_r;

fta_bus_pkg::fta_cmd_response256_t [0:2] resp [0:NPORT-1];
fta_bus_pkg::fta_cmd_request256_t [0:2] req [0:NPORT-1];
reg [2:0] reqv [NPORT-1:0];
reg [2:0] respv [NPORT-1:0];

RoundRobinArbiter #(
  .NumRequests(NPORT)
) 
urrcmd1
(
  .rst(rst_i),
  .clk(clk_i),
  .ce(1'b1),
  .hold(1'b0),
  .req(cmd_cyc),
  .grant(cmd_grant),
  .grant_enc(cmd_grant_enc)
);

// If any request is valid, submit as a choice
always_comb
begin
	for (n5 = 0; n5 < NPORT; n5 = n5 + 1)
		cmd_cyc[n5] = reqv[n5][0] | reqv[n5][1] | reqv[n5][2];
end

// Select request to output.

always_ff @(posedge clk_i)
begin
	for (n4 = 0; n4 < NPORT; n4 = n4 + 1) begin
		req[n4][0] <= cmd_i[n4];
		req[n4][1] <= cmd_i[n4];
		req[n4][2] <= cmd_i[n4];
		req[n4][0].tid.tranid=4'd0;
		req[n4][1].tid.tranid=4'd1;
		req[n4][2].tid.tranid=4'd2;
		reqv[n4][0] <= VAL;
		reqv[n4][1] <= VAL;
		reqv[n4][2] <= VAL;
	end
	if (reqv[cmd_grant_enc][0]) begin
		cmd_o = req[cmd_grant_enc][0];
		reqv[cmd_grant_enc][0] <= INV;
	end
	else if ((reqv[cmd_grant_enc][1])) begin
		cmd_o = req[cmd_grant_enc][1];
		reqv[cmd_grant_enc][1] <= INV;
	end
	else if ((reqv[cmd_grant_enc][2])) begin
		cmd_o = req[cmd_grant_enc][2];
		reqv[cmd_grant_enc][2] <= INV;
	end
end

// Detect when input port is busy.
always_comb
begin
	for (n6 = 0; n6 < NPORT; n6 = n6 + 1)
		busy_o[n6] = FALSE;
	for (n6 = 0; n6 < NPORT; n6 = n6 + 1)
		if (|reqv[n6])
			busy_o[n6] = TRUE;
end

// Compute TMR response
always_comb
	for (n2 = 0; n2 < NPORT; n2 = n2 + 1)
		resp_o[n2] = &respv[n2] ?
			(resp[n2][0] & resp[n2][1]) |
			(resp[n2][0] & resp[n2][2]) |
			(resp[n2][1] & resp[n2][2]) :
			{$bits(fta_cmd_response256_t){1'b0}};
			;

always_ff @(posedge clk_i)
begin
	resp[resp_i.tid.tranid[1:0]][resp_i.tid.channel] <= resp_i;
	respv[resp_i.tid.channel][resp_i.tid.tranid[1:0]] <= VAL;
	// Check for complete responses.
	for (n3 = 0; n3 < NPORT; n3 = n3 + 1)
		if (respv[n3][0] & respv[n3][1] & respv[n3][2]) begin
			respv[n3] <= 3'b000;
			resp[n3][0] <= {$bits(fta_cmd_response256_t){1'b0}};
		end
end

endmodule
