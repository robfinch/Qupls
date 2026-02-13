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

import mmu_pkg::*;

module tlb_dina_mux(rstcnt, paging_en, lfsro, dinb, hold_entry, rst_entry, nru, nrun, dina, lock);
parameter TLB_ASSOC = 4;
parameter TLB_ABITS = 9;
parameter UPDATE_STRATEGY=2;
localparam LRU = UPDATE_STRATEGY==1;
localparam NRU = UPDATE_STRATEGY==2;
parameter LFSR_MASK = 16'h3;
input [TLB_ABITS:0] rstcnt;
input paging_en;
input [26:0] lfsro;
input tlb_entry_t [TLB_ASSOC-1:0] dinb;
input tlb_entry_t hold_entry;
input tlb_entry_t rst_entry;
input [TLB_ASSOC-1:0] nru;
output [3:0] nrun;
output tlb_entry_t [TLB_ASSOC-1:0] dina;
input lock;

genvar g;

ffz12 uffo61 (.i({12'hFFF,nru}), .o(nrun));

generate begin : gDinaMux
	for (g = 0; g < TLB_ASSOC; g = g + 1)
		always_comb
			if (rstcnt[TLB_ABITS]) begin
				if (paging_en)
					dina[g] = dinb[g];
				else begin
					if (NRU) begin
						dina[g] = dinb[g];
						if (nrun==4'hF || (lock && nrun==TLB_ASSOC-1)) begin
							dina[0] = hold_entry;
							dina[0].nru = 1'b1;
						end
						else if(g[3:0]==nrun) begin
							dina[g] = hold_entry;
							dina[g].nru = 1'b1;
						end
					end
					else if (LRU) begin
						case({g,lock})
						{TLB_ASSOC-1,1'b1}:	dina[g] = dinb[g];
						{TLB_ASSOC-2,1'b1}:	dina[g] = hold_entry;
						{TLB_ASSOC-1,1'b0}:	dina[g] = hold_entry;
						default:	dina[g] = dinb[g+1];
						endcase
					end
					else begin
						dina[g] = dinb[g];
						dina[(lfsro^(lock ? lfsro==TLB_ASSOC-1 : 0)) & LFSR_MASK] = hold_entry;
					end
				end
			end
			else
				dina[g] = rst_entry;
end
endgenerate

endmodule
