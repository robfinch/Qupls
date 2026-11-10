import cpu_types_pkg::*;
import capability_pkg::*;
import Qupls5_pkg::*;

module Qupls5_ext_regfile(rst, clk, wr, we, wa, i, ti, ra, rav, o, to, rao, ravo);
parameter WID = $bits(cpu_types_pkg::quad_value_t);
parameter DEP = 512;
parameter BWW = 8;
parameter RBIT = $clog2(DEP)-1;
parameter RPORTS = 12;
parameter WPORTS = 1;
input rst;
input clk;
input [WPORTS-1:0] wr;
input [WID/BWW-1:0] we [0:WPORTS-1];
input cpu_types_pkg::pregno_t [WPORTS-1:0] wa;
input cpu_types_pkg::quad_value_t [WPORTS-1:0] i;
input cpu_types_pkg::flags_t [WPORTS-1:0] ti;
input cpu_types_pkg::pregno_t [RPORTS-1:0] ra;
input [RPORTS-1:0] rav;
output cpu_types_pkg::quad_value_t [RPORTS-1:0] o;
output cpu_types_pkg::flags_t [RPORTS-1:0] to;
output cpu_types_pkg::pregno_t [RPORTS-1:0] rao;
output [RPORTS-1:0] ravo;

Qupls5_quad_regfileMwNr #(
	.WID(WID),
	.DEP(DEP),
	.RPORTS(RPORTS),
	.WPORTS(WPORTS)
)
(
	.rst(rst),
	.clk(clk),
	.wr(wr),
	.we(we),
	.wa(wa),
	.i(i),
	.ti(ti),
	.ra(ra),
	.rav(rav),
	.o(o),
	.to(to),
	.rao(rao),
	.ravo(ravo)
);

endmodule
