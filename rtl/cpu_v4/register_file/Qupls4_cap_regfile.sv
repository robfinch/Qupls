import cpu_types_pkg::*;
import capability_pkg::*;
import Qupls4_pkg::*;

module Qupls4_cap_regfile(rst, clk, wr, we, wa, i, ti, ra, rav, o, to, rao, ravo);
parameter WID = $bits(uc64_capability_t);
parameter DEP = 128;
parameter BWW = 8;
parameter RBIT = $clog2(DEP)-1;
parameter RPORTS = 4;
parameter WPORTS = 1;
input rst;
input clk;
input [WPORTS-1:0] wr;
input [WID/BWW-1:0] we [0:WPORTS-1];
input cpu_types_pkg::pregno_t [WPORTS-1:0] wa;
input uc64_capability_t [WPORTS-1:0] i;
input cpu_types_pkg::flags_t [WPORTS-1:0] ti;
input cpu_types_pkg::pregno_t [RPORTS-1:0] ra;
input [RPORTS-1:0] rav;
output uc64_capability_t [RPORTS-1:0] o;
output cpu_types_pkg::flags_t [RPORTS-1:0] to;
output cpu_types_pkg::pregno_t [RPORTS-1:0] rao;
output [RPORTS-1:0] ravo;

Qupls4_regfileMwNr #(
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
