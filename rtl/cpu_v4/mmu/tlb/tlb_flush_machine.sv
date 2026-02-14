`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2026  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//
// BSD 3-Clause License
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// This little machine sets up entries in the TLB to point to the
// system RAM/ROM area.
// ============================================================================

import mmu_pkg::*;

module tlb_flush_machine(rst, clk, rstcnt, entry_no, way, entry,
	flush_trig, flush_en, flush_done);
parameter TLB_ENTRIES=512;
parameter TLB_ASSOC=4;
parameter LOG_PAGESIZE=13;
parameter LOG_PAGESIZE2=23;
parameter WID=$clog2(TLB_ENTRIES);
input rst;
input clk;
output reg [WID:0] rstcnt;
output reg [WID-1:0] entry_no;
output reg [TLB_ASSOC-1:0] way;
output tlb_entry_t entry;
input flush_trig;
input flush_en;
output flush_done;

tlb_entry_t prev_entry;
reg [WID-1:0] flush_count;
reg [$clog2(TLB_ASSOC)-1:0] way;
wire [WID-1:0] flush_entry_no;

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

// Counter used to loop through all the ways and entries.
counter #(.WID(WID+$clog2(TLB_ASSOC))) uflsh2
(
	.rst(rst),
	.clk(clk),
	.ce(flush_en),
	.ld(flush_trig),
	.d({WID{1'b0}}),
	.q({flush_entry_no,way}),
	.tc(flush_done)
);

always_comb
	entry_no = flush_en ? flush_entry_no : rstcnt[WID-1:0];

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
		casez(rstcnt)
		9'b111000000:
			begin
				entry.pte.v = 1'b1;
				entry.pte.lvl = 3'd0;
				entry.pte.ppn = 43'hFF800000 >> LOG_PAGESIZE;
				entry.vpn = 48'hFF800000 >> (LOG_PAGESIZE + WID);
			end
		9'b111??????:
			begin
				entry.pte.v = 1'b1;
				entry.pte.lvl = 3'd0;
				entry.pte.ppn = prev_entry.pte.ppn + 1;
				entry.vpn = prev_entry.vpn | rstcnt[5:0];
			end
		default:
			begin
				entry.pte.v = 1'b1;
				entry.pte.lvl = 3'd0;
				entry.pte.ppn = prev_entry.pte.ppn + 1;
				entry.vpn = prev_entry.vpn | rstcnt[5:0];
			end
		endcase
	23:
		casez(rstcnt)
		// Device discovery blocks are at $Dxxxxxxx
		8'b01_????_?:
			begin
				entry.lock = 1'b1;
				entry.pte.v = 1'b1;
				entry.pte.lvl = 3'd1;
				entry.pte.ppn = (43'hD0000000 >> LOG_PAGESIZE2) | rstcnt[4:0];
				entry.vpn = 48'hD0000000 >> (LOG_PAGESIZE2 + WID);	// Bits 16 to 31 of address
			end
		// Upper 8MB are locked
		8'b11_1111_1:
			begin
				entry.lock = 1'b1;
				entry.pte.v = 1'b1;
				entry.pte.lvl = 3'd1;
				entry.pte.ppn = (43'hFF800000 >> LOG_PAGESIZE2);
				entry.vpn = 48'hFF800000 >> (LOG_PAGESIZE2 + WID);	// Bits 16 to 31 of address
			end
		// Remaining pages are mapped to DRAM
		default:
			begin
				entry.pte.v = 1'b1;
				entry.pte.lvl = 3'd1;
				entry.pte.ppn = 43'h40000000 >> (LOG_PAGESIZE2)|rstcnt[6:0];
				entry.vpn = 48'h40000000 >> (LOG_PAGESIZE2 + WID);	// Bits 16 to 31 of address
			end
		endcase
	default:	;
	endcase
end

endmodule
