// This little machine sets up sixty-four entries in the TLB to point to the
// system RAM/ROM area.

import mmu_pkg::*;

module tlb_reset_machine(rst, clk, rstcnt, entry_no, entry);
parameter TLB_ENTRIES=512;
parameter LOG_PAGESIZE=13;
parameter WID=$clog2(TLB_ENTRIES);
input rst;
input clk;
output reg [WID:0] rstcnt;
output reg [WID-1:0] entry_no;
output tlb_entry_t entry;

tlb_entry_t prev_entry;

always_ff @(posedge clk)
if (rst)
	case(LOG_PAGESIZE)
	13:	rstcnt <= TLB_ENTRIES-64;
	23:	rstcnt <= 8'd0;
	default:	;
	endcase
else begin
	if (!rstcnt[WID])
		rstcnt <= rstcnt + 12'd1;
end

always_comb
	entry_no = rstcnt[WID-1:0];

always_ff @(posedge clk)
if (rst)
	prev_entry <= {$bits(tlb_entry_t){1'b0}};
else
	prev_entry <= entry;

// Note VPN is not incremented, rather it should be incremented by a
// fraction 1 >> WID. This works out to always zero.

always_comb
begin
	entry = {$bits(tlb_entry_t){1'd0}};
	entry.pte.rwx = 3'd7;
	case(LOG_PAGESIZE)
	13:
		begin
			entry.pte.v = 1'b1;
			entry.pte.lvl = 3'd2;
			entry.pte.ppn = prev_entry.pte.ppn + 1;
			entry.vpn.vpn = prev_entry.vpn.vpn;
		end
	23:
		case(rstcnt)
		8'b00_0010_0:
			begin
				entry.pte.v = 1'b1;
				entry.pte.lvl = 3'd2;
				entry.vpn.vpn = 48'h40000000 >> (LOG_PAGESIZE+WID);	// Bits 16 to 31 of address
				entry.pte.ppn = 43'h40000000 >> LOG_PAGESIZE;
			end
		8'b01_0000_0:
			begin
				entry.pte.v = 1'b1;
				entry.pte.lvl = 3'd2;
				entry.vpn.vpn = 48'hD0000000 >> (LOG_PAGESIZE+WID);	// Bits 16 to 31 of address
				entry.pte.ppn = 43'hD0000000 >> LOG_PAGESIZE;
			end
		8'b10_0000_0:
			begin
				entry.pte.v = 1'b1;
				entry.pte.lvl = 3'd2;
				entry.vpn.vpn = 48'hE0000000 >> (LOG_PAGESIZE+WID);	// Bits 16 to 31 of address
				entry.pte.ppn = 43'hE0000000 >> LOG_PAGESIZE;
			end
		8'b11_0000_0:
			begin
				entry.pte.v = 1'b1;
				entry.pte.lvl = 3'd2;
				entry.vpn.vpn = 48'hF0000000 >> (LOG_PAGESIZE+WID);	// Bits 16 to 31 of address
				entry.pte.ppn = 43'hF0000000 >> LOG_PAGESIZE;
			end
		default:
			begin
				entry.pte.v = 1'b1;
				entry.pte.lvl = 3'd2;
				entry.pte.ppn = prev_entry.pte.ppn + 1;
				entry.vpn.vpn = prev_entry.vpn.vpn;
			end
		endcase
	default:	;
	endcase
end

endmodule
