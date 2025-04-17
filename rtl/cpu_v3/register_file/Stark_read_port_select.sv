// The selector is organized around having seven functional units requesting
// up to five registers each, or 35 register selections. Since most of the
// time instructions will require 3 registers or less, it is wasteful to 
// have a separate register file port for every possible register an 
// instruction might need. Instead the selector goes with enough ports to
// keep everybody happy most of the time.
//
// The first seven port selections are fixed 1:1. This is to reduce the amount
// of logic required by the selector. Many instructions use a at least one
// source register, so they are simply allocated one all the time. Instead
// of requiring dynamic mapping for all 30 inputs, it is reduced to 24
// inputs. This cuts the size of the component in half (1900 LUTs instead
// of 4000) and likely helps with the timing as well.
//
// The port selection rotates for the 24 dynamically assigned ports to
// ensure that no port goes unserviced.
//

import cpu_types_pkg::pregno_t;

module Stark_read_port_select(rst, clk, aReg_i, aReg_o, regAck_o);
parameter NPORTI=32;
parameter NPORTO=16;
parameter FIXEDPORTS = 8;
input rst;
input clk;
input aregno_t [NPORTI-1:0] aReg_i;
output aregno_t [NPORTO-1:0] aReg_o;
output reg [NPORTO-1:0] regAck_o;

integer j,k,h;
reg [4:0] m;

// m used to rotate the port selections every clock cycle.
always_ff @(posedge clk)
if (rst)
	m <= 5'd0;
else begin
	if (m==NPORTI-FIXEDPORTS-1)
		m <= 5'd0;
	else
		m <= m + 5'd1;
end

always_ff @(posedge clk)
if (rst) begin
	for (j = 0; j < NPORTI; j = j + 1)
		regAck_o[j] = 1'b0;
end
else begin
	k = FIXEDPORTS;
	for (h = 0; h < FIXEDPORTS; h = h + 1) begin
		regAck_o[h] = 1'b1;
		aReg_o[h] = aReg_i[h];
	end
	for (j = 0; j < NPORTI-FIXEDPORTS; j = j + 1) begin
		regAck_o[j+FIXEDPORTS] = 1'b0;
		if (aReg_i[((j+m)%(NPORTI-FIXEDPORTS))+FIXEDPORTS]!=8'd0) begin
			if (k < NPORTO) begin
				regAck_o[((j+m)%(NPORTI-FIXEDPORTS))+FIXEDPORTS] = 1'b1;
				aReg_o[k] = aReg_i[((j+m)%(NPORTI-FIXEDPORTS))+FIXEDPORTS];
				k = k + 1;
			end
		end
	end
end

endmodule
