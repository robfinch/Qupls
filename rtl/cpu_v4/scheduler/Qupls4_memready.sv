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
//
// ============================================================================
//
import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_memready(rst, clk, rob, lsq, cancel, stomp, memready);
input rst;
input clk;
input Qupls4_pkg::rob_entry_t [Qupls4_pkg::ROB_ENTRIES-1:0] rob;
input Qupls4_pkg::lsq_entry_t [1:0] lsq [0:Qupls4_pkg::LSQ_ENTRIES-1];
input [Qupls4_pkg::ROB_ENTRIES-1:0] cancel;
input [Qupls4_pkg::ROB_ENTRIES-1:0] stomp;
output reg [Qupls4_pkg::ROB_ENTRIES-1:0] memready;

integer n9r,n9c;
Qupls4_pkg::lsq_bitmask_t [1:0] memopsvalid;

// We need only check the LSQ for valid operands.
// The A,B operands must have been valid for the entry to be placed in the LSQ.
// The C operand is only needed for stores.
always_comb
foreach (lsq[n9r])
	for (n9c = 0; n9c < 2; n9c = n9c + 1)
		memopsvalid[n9c][n9r] = lsq[n9r][n9c].v && lsq[n9r][n9c].agen && (lsq[n9r][n9c].load|lsq[n9r][n9c].datav);

always_ff @(posedge clk)
if (rst)
	memready <= {Qupls4_pkg::ROB_ENTRIES{1'b0}};
else begin
	foreach (memready[n10])
  	memready[n10] = (rob[n10].v
  		&& memopsvalid[rob[n10].lsqndx.col][rob[n10].lsqndx.row] 
//  		& ~robentry_memissue[n10] 
  		&& (rob[n10].done==2'b01) 
//  		& ~rob[n10].out
  		&&  rob[n10].lsq
  		&& !cancel[n10]
  		&& !stomp[n10])
  		;
end

endmodule
