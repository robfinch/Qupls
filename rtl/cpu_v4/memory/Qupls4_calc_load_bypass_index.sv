// ============================================================================
//        __
//   \\__/ o\    (C) 2025  Robert Finch, Waterloo
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
//
import Qupls4_pkg::*;

module Qupls4_calc_load_bypass_index(lsq_i, lsndx_i, ndx_o);
input Qupls4_pkg::lsq_entry_t [1:0] lsq_i [0:7];
input Qupls4_pkg::lsq_ndx_t lsndx_i;
output Qupls4_pkg::lsq_ndx_t ndx_o;

integer n15r,n15c;
seqnum_t stsn;

always_comb
begin
	ndx_o = 0;
	stsn = 8'hFF;
	for (n15r = 0; n15r < Qupls4_pkg::LSQ_ENTRIES; n15r = n15r + 1) begin
		for (n15c = 0; n15c < 2; n15c = n15c + 1) begin
		if (
			(lsq[lsndx.row][lsndx.col].memsz==lsq[n15r][n15c].memsz) &&		// memory size matches
			(lsq[lsndx.row][lsndx.col].load && lsq[n15r][n15c].store) &&	// and trying to load
			// The load must come after the store and the store data should be valid.
			lsq[lsndx.row][lsndx.col].sn > lsq[n15r][n15c].sn && lsq[n15r][n15c].v && lsq[n15r][n15c].datav && 
			// And it should be the store closest to the load.
			stsn > lsq[n15r][n15c].sn &&
			// And the address should match.
			lsq[lsndx.row][lsndx.col].agen==1'b1 && lsq[n15r][n15c].agen==1'b1 &&	// must be physical addresses
			lsq[lsndx.row][lsndx.col].padr == lsq[n15r][n15c].padr
			) begin
			 	stsn = lsq[n15r][n15c].sn;
			 	ndx_o.row = n15r;
			 	ndx_o.col = n15c;
			 	ndx_o.vb = VAL;
			end
		end
	end
end

endmodule

