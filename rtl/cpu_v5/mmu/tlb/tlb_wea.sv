`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2026  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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
// ============================================================================

import wishbone_pkg::*;

module tlb_wea(rstcnt, g, paging_en, cs_tlb, req, web, lock_map, hold_entry_no, 
	flush_en, flush_by_asid, asid_hit, count_hit, wea);
parameter TLB_ABITS = 9;
parameter TLB_ASSOC = 4;
input [TLB_ABITS:0] rstcnt;
input integer g;
input paging_en;
input cs_tlb;
input wb_cmd_request64_t req;
input [15:0] web;
input [63:0] lock_map;
input [TLB_ABITS-1:0] hold_entry_no;
input flush_en;
input flush_by_asid;
input asid_hit;
input count_hit;
output reg [15:0] wea;


always_comb
// On reset the TLB is initialized, so enable writing.
if (~rstcnt[TLB_ABITS])
	wea <= {16{1'b1}};
else begin
	// If paging is enabled, the TLB entry is copied verbatim except for the
	// modified and accessed bits, which need to be updated.
	if (paging_en)
		wea <= {16{web}};
	else begin
		// The entry must not be locked.
		if (!(lock_map[hold_entry_no[TLB_ABITS-1:TLB_ABITS-6 < 0 ? 0 : TLB_ABITS-6]] && g==TLB_ASSOC-1)) begin
			// If the TLB is being updated by external process
			if (cs_tlb & req.we && req.adr[5:3]==3'd4 && req.dat[31])
				wea <= {16{1'b1}};
			else if (flush_by_asid && asid_hit)
				wea <= {16{1'b1}};
			else if (flush_en & ~count_hit)
				wea <= {16{1'b1}};
		end
	end
end

endmodule
