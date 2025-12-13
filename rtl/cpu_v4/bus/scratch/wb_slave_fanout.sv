import wishbone_pkg::*;

module wb_slave_fanout(rst_i, clk_i, wb_req, wb_resp, fan32_req, fan32_resp, fan64_req, fan64_resp, fan256_req, fan256_resp);
parameter FANOUT32 = 2;
parameter FANOUT64 = 2;
parameter FANOUT256 = 1;
input rst_i;
input clk_i;
input wb_cmd_request256_t wb_req;
output wb_cmd_response256_t wb_resp;
output wb_cmd_request32_t [FANOUT64-1:0] fan32_req;
input wb_cmd_response32_t [FANOUT64-1:0] fan32_resp;
output wb_cmd_request64_t [FANOUT64-1:0] fan64_req;
input wb_cmd_response64_t [FANOUT64-1:0] fan64_resp;
output wb_cmd_request256_t [FANOUT64-1:0] fan256_req;
input wb_cmd_response256_t [FANOUT64-1:0] fan256_resp;

integer n1,n2;
reg [FANOUT32-1:0] fan32_ack;
reg [FANOUT64-1:0] fan64_ack;
reg [FANOUT256-1:0] fan256_ack;
reg [FANOUT32+FANOUT64+FANOUT256-1:0] fan_ack, holdn;
wire [FANOUT32+FANOUT64+FANOUT256-1:0] req_grant;
reg hold;

always_ff @(posedge clk_i)
if (rst_i) begin
	fan32_ack <= {FANOUT32{1'b0}};
	fan64_ack <= {FANOUT64{1'b0}};
	fan256_ack <= {FANOUT256{1'b0}};
end
else begin
	for (n2 = 0; n2 < FANOUT32; n2 = n2 + 1)
		fan32_ack[n2] <= fan32_resp[n2].ack;
	for (n2 = 0; n2 < FANOUT64; n2 = n2 + 1)
		fan64_ack[n2] <= fan64_resp[n2].ack;
	for (n2 = 0; n2 < FANOUT256; n2 = n2 + 1)
		fan256_ack[n2] <= fan256_resp[n2].ack;
end

always_comb
	fan_ack = {fan256_ack,fan64_ack,fan32_ack};

always_comb
	holdn = fan_ack & req_grant;
always_comb
	hold = |holdn;

RoundRobinArbiter #(
  .NumRequests(FANOUT32+FANOUT64+FANOUT256)
) 
urrreq1
(
  .rst(rst_i),
  .clk(clk_i),
  .ce(1'b1),
  .hold(hold),
  .req(fan_ack),
  .grant(req_grant),
  .grant_enc(req_grant_enc)
);

always_comb
	for (n1 = 0; n1 < FANOUT256; n1 = n1 + 1)
		fan256_req[n1] <= wb_req;

// Fanout master request to slaves.
always_comb
	for (n1 = 0; n1 < FANOUT64; n1 = n1 + 1) begin
		fan64_req[n1].blen = wb_req.blen;
		fan64_req[n1].tid = wb_req.tid;
		fan64_req[n1].cmd = wb_req.cmd;
		fan64_req[n1].cti = wb_req.cti;
		fan64_req[n1].cyc = wb_req.cyc;
		fan64_req[n1].stb = wb_req.stb;
		fan64_req[n1].we = wb_req.we;
		fan64_req[n1].sel = wb_req.sel[7:0]|wb_req.sel[15:8]|wb_req.sel[23:16]|wb_req.sel[31:24];
		fan64_req[n1].adr = wb_req.adr;
		fan64_req[n1].adr[4] = |wb_req.sel[31:16];
		fan64_req[n1].adr[3] = |wb_req.sel[31:24]| |wb_req.sel[15:8];
		case(wb_req.sel)
		32'b00000000000000000000000000000001: fan64_req[n1].dat = {8{wb_req.dat[7:0]}};
		32'b00000000000000000000000000000010: fan64_req[n1].dat = {8{wb_req.dat[15:8]}};
		32'b00000000000000000000000000000100: fan64_req[n1].dat = {8{wb_req.dat[23:16]}};
		32'b00000000000000000000000000001000: fan64_req[n1].dat = {8{wb_req.dat[31:24]}};
		32'b00000000000000000000000000010000: fan64_req[n1].dat = {8{wb_req.dat[39:32]}};
		32'b00000000000000000000000000100000: fan64_req[n1].dat = {8{wb_req.dat[47:40]}};
		32'b00000000000000000000000001000000: fan64_req[n1].dat = {8{wb_req.dat[55:48]}};
		32'b00000000000000000000000010000000: fan64_req[n1].dat = {8{wb_req.dat[63:56]}};
		32'b00000000000000000000000100000000: fan64_req[n1].dat = {8{wb_req.dat[71:64]}};
		32'b00000000000000000000001000000000: fan64_req[n1].dat = {8{wb_req.dat[79:72]}};
		32'b00000000000000000000010000000000: fan64_req[n1].dat = {8{wb_req.dat[87:80]}};
		32'b00000000000000000000100000000000: fan64_req[n1].dat = {8{wb_req.dat[95:88]}};
		32'b00000000000000000001000000000000: fan64_req[n1].dat = {8{wb_req.dat[103:96]}};
		32'b00000000000000000010000000000000: fan64_req[n1].dat = {8{wb_req.dat[111:104]}};
		32'b00000000000000000100000000000000: fan64_req[n1].dat = {8{wb_req.dat[119:112]}};
		32'b00000000000000001000000000000000: fan64_req[n1].dat = {8{wb_req.dat[127:120]}};
		32'b00000000000000010000000000000000: fan64_req[n1].dat = {8{wb_req.dat[135:128]}};
		32'b00000000000000100000000000000000: fan64_req[n1].dat = {8{wb_req.dat[143:136]}};
		32'b00000000000001000000000000000000: fan64_req[n1].dat = {8{wb_req.dat[151:144]}};
		32'b00000000000010000000000000000000: fan64_req[n1].dat = {8{wb_req.dat[159:152]}};
		32'b00000000000100000000000000000000: fan64_req[n1].dat = {8{wb_req.dat[167:160]}};
		32'b00000000001000000000000000000000: fan64_req[n1].dat = {8{wb_req.dat[175:168]}};
		32'b00000000010000000000000000000000: fan64_req[n1].dat = {8{wb_req.dat[183:176]}};
		32'b00000000100000000000000000000000: fan64_req[n1].dat = {8{wb_req.dat[191:184]}};
		32'b00000001000000000000000000000000: fan64_req[n1].dat = {8{wb_req.dat[199:192]}};
		32'b00000010000000000000000000000000: fan64_req[n1].dat = {8{wb_req.dat[207:200]}};
		32'b00000100000000000000000000000000: fan64_req[n1].dat = {8{wb_req.dat[215:208]}};
		32'b00001000000000000000000000000000: fan64_req[n1].dat = {8{wb_req.dat[223:216]}};
		32'b00010000000000000000000000000000: fan64_req[n1].dat = {8{wb_req.dat[231:224]}};
		32'b00100000000000000000000000000000: fan64_req[n1].dat = {8{wb_req.dat[239:232]}};
		32'b01000000000000000000000000000000: fan64_req[n1].dat = {8{wb_req.dat[247:240]}};
		32'b10000000000000000000000000000000: fan64_req[n1].dat = {8{wb_req.dat[255:248]}};
		32'b00000000000000000000000000000011: fan64_req[n1].dat = {4{wb_req.dat[15:0]}};
		32'b00000000000000000000000000001100: fan64_req[n1].dat = {4{wb_req.dat[31:16]}};
		32'b00000000000000000000000000110000: fan64_req[n1].dat = {4{wb_req.dat[47:32]}};
		32'b00000000000000000000000011000000: fan64_req[n1].dat = {4{wb_req.dat[63:48]}};
		32'b00000000000000000000001100000000: fan64_req[n1].dat = {4{wb_req.dat[79:64]}};
		32'b00000000000000000000110000000000: fan64_req[n1].dat = {4{wb_req.dat[95:80]}};
		32'b00000000000000000011000000000000: fan64_req[n1].dat = {4{wb_req.dat[111:96]}};
		32'b00000000000000001100000000000000: fan64_req[n1].dat = {4{wb_req.dat[127:112]}};
		32'b00000000000000110000000000000000: fan64_req[n1].dat = {4{wb_req.dat[143:128]}};
		32'b00000000000011000000000000000000: fan64_req[n1].dat = {4{wb_req.dat[159:144]}};
		32'b00000000001100000000000000000000: fan64_req[n1].dat = {4{wb_req.dat[175:160]}};
		32'b00000000110000000000000000000000: fan64_req[n1].dat = {4{wb_req.dat[191:176]}};
		32'b00000011000000000000000000000000: fan64_req[n1].dat = {4{wb_req.dat[207:192]}};
		32'b00001100000000000000000000000000: fan64_req[n1].dat = {4{wb_req.dat[223:208]}};
		32'b00110000000000000000000000000000: fan64_req[n1].dat = {4{wb_req.dat[239:224]}};
		32'b11000000000000000000000000000000: fan64_req[n1].dat = {4{wb_req.dat[255:240]}};
		32'b00000000000000000000000000001111: fan64_req[n1].dat = {2{wb_req.dat[31:0]}};
		32'b00000000000000000000000011110000: fan64_req[n1].dat = {2{wb_req.dat[63:32]}};
		32'b00000000000000000000111100000000: fan64_req[n1].dat = {2{wb_req.dat[95:64]}};
		32'b00000000000000001111000000000000: fan64_req[n1].dat = {2{wb_req.dat[127:96]}};
		32'b00000000000011110000000000000000: fan64_req[n1].dat = {2{wb_req.dat[159:128]}};
		32'b00000000111100000000000000000000: fan64_req[n1].dat = {2{wb_req.dat[191:160]}};
		32'b00001111000000000000000000000000: fan64_req[n1].dat = {2{wb_req.dat[223:192]}};
		32'b11110000000000000000000000000000: fan64_req[n1].dat = {2{wb_req.dat[255:224]}};
		32'b00000000000000000000000011111111: fan64_req[n1].dat = wb_req.dat[63:0];
		32'b00000000000000001111111100000000: fan64_req[n1].dat = wb_req.dat[127:64];
		32'b00000000111111110000000000000000: fan64_req[n1].dat = wb_req.dat[191:128];
		32'b11111111000000000000000000000000: fan64_req[n1].dat = wb_req.dat[255:192];
		default:	fan64_req[n1].dat = 64'hDEADBEEFDEADBEEF;
		endcase
	end

always_comb
	for (n1 = 0; n1 < FANOUT32; n1 = n1 + 1) begin
		fan32_req[n1].blen = wb_req.blen;
		fan32_req[n1].tid = wb_req.tid;
		fan32_req[n1].cmd = wb_req.cmd;
		fan32_req[n1].cti = wb_req.cti;
		fan32_req[n1].cyc = wb_req.cyc;
		fan32_req[n1].stb = wb_req.stb;
		fan32_req[n1].we = wb_req.we;
		fan32_req[n1].sel = 
			wb_req.sel[3:0]|
			wb_req.sel[7:4]|
			wb_req.sel[11:8]|
			wb_req.sel[15:12]|
			wb_req.sel[19:16]|
			wb_req.sel[23:20]|
			wb_req.sel[27:24]|
			wb_req.sel[31:28]
			;
		fan32_req[n1].adr = wb_req.adr;
		fan32_req[n1].adr[4] = |wb_req.sel[31:16];
		fan32_req[n1].adr[3] = |wb_req.sel[31:24]| |wb_req.sel[15:8];
		fan32_req[n1].adr[2] = |wb_req.sel[31:28]| |wb_req.sel[23:20]| |wb_req.sel[15:12]| |wb_req.sel[7:4];
		case(wb_req.sel)
		32'b00000000000000000000000000000001: fan32_req[n1].dat = {4{wb_req.dat[7:0]}};
		32'b00000000000000000000000000000010: fan32_req[n1].dat = {4{wb_req.dat[15:8]}};
		32'b00000000000000000000000000000100: fan32_req[n1].dat = {4{wb_req.dat[23:16]}};
		32'b00000000000000000000000000001000: fan32_req[n1].dat = {4{wb_req.dat[31:24]}};
		32'b00000000000000000000000000010000: fan32_req[n1].dat = {4{wb_req.dat[39:32]}};
		32'b00000000000000000000000000100000: fan32_req[n1].dat = {4{wb_req.dat[47:40]}};
		32'b00000000000000000000000001000000: fan32_req[n1].dat = {4{wb_req.dat[55:48]}};
		32'b00000000000000000000000010000000: fan32_req[n1].dat = {4{wb_req.dat[63:56]}};
		32'b00000000000000000000000100000000: fan32_req[n1].dat = {4{wb_req.dat[71:64]}};
		32'b00000000000000000000001000000000: fan32_req[n1].dat = {4{wb_req.dat[79:72]}};
		32'b00000000000000000000010000000000: fan32_req[n1].dat = {4{wb_req.dat[87:80]}};
		32'b00000000000000000000100000000000: fan32_req[n1].dat = {4{wb_req.dat[95:88]}};
		32'b00000000000000000001000000000000: fan32_req[n1].dat = {4{wb_req.dat[103:96]}};
		32'b00000000000000000010000000000000: fan32_req[n1].dat = {4{wb_req.dat[111:104]}};
		32'b00000000000000000100000000000000: fan32_req[n1].dat = {4{wb_req.dat[119:112]}};
		32'b00000000000000001000000000000000: fan32_req[n1].dat = {4{wb_req.dat[127:120]}};
		32'b00000000000000010000000000000000: fan32_req[n1].dat = {4{wb_req.dat[135:128]}};
		32'b00000000000000100000000000000000: fan32_req[n1].dat = {4{wb_req.dat[143:136]}};
		32'b00000000000001000000000000000000: fan32_req[n1].dat = {4{wb_req.dat[151:144]}};
		32'b00000000000010000000000000000000: fan32_req[n1].dat = {4{wb_req.dat[159:152]}};
		32'b00000000000100000000000000000000: fan32_req[n1].dat = {4{wb_req.dat[167:160]}};
		32'b00000000001000000000000000000000: fan32_req[n1].dat = {4{wb_req.dat[175:168]}};
		32'b00000000010000000000000000000000: fan32_req[n1].dat = {4{wb_req.dat[183:176]}};
		32'b00000000100000000000000000000000: fan32_req[n1].dat = {4{wb_req.dat[191:184]}};
		32'b00000001000000000000000000000000: fan32_req[n1].dat = {4{wb_req.dat[199:192]}};
		32'b00000010000000000000000000000000: fan32_req[n1].dat = {4{wb_req.dat[207:200]}};
		32'b00000100000000000000000000000000: fan32_req[n1].dat = {4{wb_req.dat[215:208]}};
		32'b00001000000000000000000000000000: fan32_req[n1].dat = {4{wb_req.dat[223:216]}};
		32'b00010000000000000000000000000000: fan32_req[n1].dat = {4{wb_req.dat[231:224]}};
		32'b00100000000000000000000000000000: fan32_req[n1].dat = {4{wb_req.dat[239:232]}};
		32'b01000000000000000000000000000000: fan32_req[n1].dat = {4{wb_req.dat[247:240]}};
		32'b10000000000000000000000000000000: fan32_req[n1].dat = {4{wb_req.dat[255:248]}};
		32'b00000000000000000000000000000011: fan32_req[n1].dat = {2{wb_req.dat[15:0]}};
		32'b00000000000000000000000000001100: fan32_req[n1].dat = {2{wb_req.dat[31:16]}};
		32'b00000000000000000000000000110000: fan32_req[n1].dat = {2{wb_req.dat[47:32]}};
		32'b00000000000000000000000011000000: fan32_req[n1].dat = {2{wb_req.dat[63:48]}};
		32'b00000000000000000000001100000000: fan32_req[n1].dat = {2{wb_req.dat[79:64]}};
		32'b00000000000000000000110000000000: fan32_req[n1].dat = {2{wb_req.dat[95:80]}};
		32'b00000000000000000011000000000000: fan32_req[n1].dat = {2{wb_req.dat[111:96]}};
		32'b00000000000000001100000000000000: fan32_req[n1].dat = {2{wb_req.dat[127:112]}};
		32'b00000000000000110000000000000000: fan32_req[n1].dat = {2{wb_req.dat[143:128]}};
		32'b00000000000011000000000000000000: fan32_req[n1].dat = {2{wb_req.dat[159:144]}};
		32'b00000000001100000000000000000000: fan32_req[n1].dat = {2{wb_req.dat[175:160]}};
		32'b00000000110000000000000000000000: fan32_req[n1].dat = {2{wb_req.dat[191:176]}};
		32'b00000011000000000000000000000000: fan32_req[n1].dat = {2{wb_req.dat[207:192]}};
		32'b00001100000000000000000000000000: fan32_req[n1].dat = {2{wb_req.dat[223:208]}};
		32'b00110000000000000000000000000000: fan32_req[n1].dat = {2{wb_req.dat[239:224]}};
		32'b11000000000000000000000000000000: fan32_req[n1].dat = {2{wb_req.dat[255:240]}};
		32'b00000000000000000000000000001111: fan32_req[n1].dat = {1{wb_req.dat[31:0]}};
		32'b00000000000000000000000011110000: fan32_req[n1].dat = {1{wb_req.dat[63:32]}};
		32'b00000000000000000000111100000000: fan32_req[n1].dat = {1{wb_req.dat[95:64]}};
		32'b00000000000000001111000000000000: fan32_req[n1].dat = {1{wb_req.dat[127:96]}};
		32'b00000000000011110000000000000000: fan32_req[n1].dat = {1{wb_req.dat[159:128]}};
		32'b00000000111100000000000000000000: fan32_req[n1].dat = {1{wb_req.dat[191:160]}};
		32'b00001111000000000000000000000000: fan32_req[n1].dat = {1{wb_req.dat[223:192]}};
		32'b11110000000000000000000000000000: fan32_req[n1].dat = {1{wb_req.dat[255:224]}};
		default:	fan32_req[n1].dat = 32'hDEADBEEF;
		endcase
	end

// Select response going back to master.
always_comb
	if (req_grant_enc < FANOUT32) begin
		wb_resp.tid = fan32_resp[req_grant_enc].tid;
		wb_resp.ack = fan32_resp[req_grant_enc].ack;
		wb_resp.dat = {256'd0,fan32_resp[req_grant_enc].dat} << {fan32_req[req_grant_enc].adr[4:2],5'd0};
	end
	else if (req_grant_enc < FANOUT64+FANOUT32) begin
		wb_resp.tid = fan64_resp[req_grant_enc].tid;
		wb_resp.ack = fan64_resp[req_grant_enc].ack;
		wb_resp.dat = {256'd0,fan64_resp[req_grant_enc].dat} << {fan64_req[req_grant_enc].adr[4:3],6'd0};
	end
	else
		wb_resp = fan256_resp[req_grant_enc];

endmodule
