// ============================================================================
//        __
//   \\__/ o\    (C) 2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	icache_valid_bits.sv
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
// FOR ANY DIRECT, INDIRECT, INCHANNELENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// ============================================================================

import cache_pkg::*;
import cpu_types_pkg::*;
import wishbone_pkg::*;

module icache_valid_bits(rst, clk, invce, invline, invall, wr, wway, line, ptags,
	snoop_v, snoop_tid, snoop_adr, valid);
parameter CORENO=6'd1;
parameter CHANNEL=3'd0;
parameter LINES=256;
parameter WAYS=4;
parameter HIBIT=15;
parameter LOBIT=7;
parameter TAGBIT=15;
input rst;
input clk;
input invce;
input invline;
input invall;
input wr;
input [$clog2(WAYS)-1:0] wway;
input ICacheLine line;
input cache_tag_t [WAYS-1:0] ptags;
input snoop_v;
input wishbone_pkg::wb_tranid_t snoop_tid;
input cpu_types_pkg::address_t snoop_adr;
output reg [LINES-1:0] valid [0:WAYS-1];

integer g;

always_ff @(posedge clk)
if (rst) begin
	foreach (valid[g])
		valid[g] <= 'd0;
end
else begin
	if (wr)
		valid[wway][line.vtag[HIBIT:LOBIT]] <= 1'b1;
	else if (invce) begin
		foreach (valid[g]) begin
			if (invline)
				valid[g][line.vtag[HIBIT:LOBIT]] <= 1'b0;
			else if (invall)
				valid[g] <= 'd0;
		end
	end
	// Two different virtual addresses pointing to the same physical address will
	// end up in the same set as long as the cache is smaller than a memory page
	// in size. So, there is no need to compare every physical address, just every
	// address in a set will do.
	if (snoop_v && (snoop_tid.core!=CORENO || snoop_tid.channel != CHANNEL)) begin
		foreach (valid[g])
			if (snoop_adr[$bits(cpu_types_pkg::address_t)-1:TAGBIT]==ptags[g])
				valid[g][snoop_adr[HIBIT:LOBIT]] <= 1'b0;
	end
end


endmodule