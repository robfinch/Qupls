// ============================================================================
//        __
//   \\__/ o\    (C) 22025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	victim_cache.sv
//	- fully associative victim cache
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
//
// The cache returns a hi/lo pair of cache lines. This is to allow instructions
// to span cache lines.
//
// ============================================================================

import cpu_types_pkg::*;
import cache_pkg::*;

module victim_cache(rst, clk, wr, line, snoop_v, snoop_tid, snoop_adr, ip, vce, vco, eline_o, oline_o);
parameter CORENO=6'd1;
parameter CHANNEL=6'd0;
parameter NVICTIM=4;
parameter LOBIT=7;
input rst;
input clk;
input wr;
input ICacheLine line;
input snoop_v;
input wb_tranid_t snoop_tid;
input cpu_types_pkg::address_t snoop_adr;
input cpu_types_pkg::pc_address_t ip;
output reg vce;
output reg vco;
output ICacheLine eline_o;
output ICacheLine oline_o;

integer n,g;		// assume NVICTIM < 15
reg [$clog2(NVICTIM)-1:0] count;
ICacheLine [NVICTIM-1:0] victim_cache;
reg [3:0] vcne, vcno;

always_comb
	if (NVICTIM > 14) begin
		$display("Qupls4 Icache: victim cache too large.");
		$finish;
	end

// Search the victim cache for the requested cache line.
always_comb
begin
	vcne = NVICTIM;
	vcno = NVICTIM;
	foreach (victim_cache[n]) begin
		if (victim_cache[n].vtag[$bits(cpu_types_pkg::address_t)-1:LOBIT-1]=={ip[$bits(cpu_types_pkg::address_t)-1:LOBIT]+ip[LOBIT-1],1'b0} && victim_cache[n].v==4'hF)
			vcne = n[3:0];
		if (victim_cache[n].vtag[$bits(cpu_types_pkg::address_t)-1:LOBIT-1]=={ip[$bits(cpu_types_pkg::address_t)-1:LOBIT],1'b1} && victim_cache[n].v==4'hF)
			vcno = n[3:0];
	end
end

always_comb
	vce <= vcne < NVICTIM;
always_comb
	vco <= vcno < NVICTIM;
always_comb
	eline_o <= victim_cache[vcne];
always_comb
	oline_o <= victim_cache[vcno];

// Used as a write index into the victim cache
always_ff @(posedge clk)
if (rst)
	count <= 'd0;
else begin
	if (wr) begin
		count <= count + 2'd1;
		if (count>=NVICTIM-1)
			count <= 3'd0;
	end
end

// Victim cache updates.
// Invalidate victim cache entries matching the snoop address
always_ff @(posedge clk)
if (rst)
	foreach(victim_cache[g])
		victim_cache[g] <= {$bits(ICacheLine){1'b0}};
else begin
	if (wr)
		victim_cache[count] <= line;
	if (snoop_v && (snoop_tid.core != CORENO || snoop_tid.channel != CHANNEL)) begin
		foreach (victim_cache[g]) begin
			if (snoop_adr[$bits(cpu_types_pkg::address_t)-1:LOBIT]==victim_cache[g].ptag[$bits(cpu_types_pkg::address_t)-1:LOBIT])
				victim_cache[g].v <= 4'h0;
		end
	end
end

endmodule
