// ============================================================================
//        __
//   \\__/ o\    (C) 2025  Robert Finch, Waterloo
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
//
// Detect if a LSQ entry has an overlap with a previous LSQ entry. This need
// only check the LSQ where the addresses are located.
// First the load / store must be before the tested one.
// Then if the address is not generated yet, we do not know, so play it safe
// and assume it overlaps.
// Finally, check the physical address, this could be at cache-line alignment
// but for now, we use the alignment of the largest load / store, 16B.
// Two loads are allowed to overlap.
//
// ============================================================================

import const_pkg::*;
import Qupls4_pkg::*;

module Qupls4_has_overlapped_adr(rob, lsq, id, has_overlap);
input Qupls4_pkg::rob_entry_t [Qupls4_pkg::ROB_ENTRIES-1:0] rob;
input Qupls4_pkg::lsq_entry_t [1:0] lsq [0:Qupls4_pkg::LSQ_ENTRIES-1];
input Qupls4_pkg::lsq_ndx_t id;
output reg has_overlap;

integer n,c;

always_comb
begin
	has_overlap = FALSE;
	foreach (lsq[n]) begin
		for (c = 0; c < 2; c = c + 1) begin
			// If the instruction is done already, we do not care if a new one overlaps.
			if (!(&rob[lsq[n][c].rndx].done)) begin
				// We do not care about instructions coming after the one checked.
				if (lsq[n][c].sn < lsq[id.row][id.col].sn) begin
					// If the address is not generated, play safe.
					if (!lsq[n][c].agen)
						has_overlap = TRUE;
					if (lsq[n][c].padr[$bits(physical_address_t)-1:4]==lsq[id.row][id.col].padr[$bits(physical_address_t)-1:4]) begin
						// Two loads can overlap
						if (!(lsq[n][c].load && lsq[id.row][id.col].load))
							has_overlap = TRUE;
					end
				end
			end
		end
	end
end

endmodule
