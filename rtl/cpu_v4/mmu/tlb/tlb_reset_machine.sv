// This little machine sets up sixty-four entries in the TLB to point to the
// system RAM/ROM area.

import mmu_pkg::*;

module tlb_reset_machine(rst, clk, rstcnt, entry_no, entry);
parameter TLB_ENTRIES=512;
parameter WID=10;
input rst;
input clk;
output reg [WID:0] rstcnt;
output reg [WID-1:0] entry_no;
output tlb_entry_t entry;

always_ff @(posedge clk)
if (rst)
	rstcnt <= TLB_ENTRIES-64;
else begin
	if (!rstcnt[WID])
		rstcnt <= rstcnt + 12'd1;
end

always_comb
	entry_no = rstcnt[WID-1:0];

always_ff @(posedge clk)
if (rst) begin
	entry <= {$bits(tlb_entry_t){1'd0}};
	entry.pte.rwx <= 3'd7;
	entry.pte.v <= 1'b1;
	entry.pte.lvl <= 3'd0;
//	entry.vpn.vpn <= 48'h7FFC0;	// Bits 13 to 31 of address
//	entry.pte.ppn <= 43'h7FFC0;
	entry.vpn.vpn <= 48'hFFC0;	// Bits 16 to 31 of address
	entry.pte.ppn <= 43'hFFC0;
end
else begin
	if (!rstcnt[WID]) begin
		entry.pte.ppn <= entry.pte.ppn + 1;
		entry.vpn.vpn <= entry.vpn.vpn + 1;
	end
end

endmodule
