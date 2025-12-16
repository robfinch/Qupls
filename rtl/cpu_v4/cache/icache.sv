// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	icache.sv
//	- instruction cache 32kB, 8kB 4 way
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
// The icache returns a hi/lo pair of cache lines. This is to allow instructions
// to span cache lines.
//
// 2700 LUTs / 650 FFs / 22.5 BRAMs
//
//  5624 LUTs / 11213 FFs / 8 BRAMs   16kB cache
//  6136 LUTs / 11469 FFs / 15 BRAMs  32kB cache
// 10373 LUTs / 21699 FFs / 15 BRAMs  64kB cache
//
//  7720 LUTs / 14511 FFs / 29 BRAMs  32kB cache + victim cache
// ============================================================================

import const_pkg::*;
import fta_bus_pkg::*;
import cache_pkg::*;

module icache(rst,clk,ce,invce,snoop_adr,snoop_v,snoop_cid,invall,invline,
	nop,nop_o,ip_asid,fetch_alt,
	ip,ip_o,ihit_o,ihit,alt_ihit_o,ic_line_hi_o,ic_line_lo_o,ic_valid,
	miss_vadr,miss_asid,
	ic_line_i,wway,wr_ic,
	dp, dp_asid, dhit_o, dc_line_o, dc_valid, port, port_i
	);
parameter CORENO = 6'd1;
parameter CHANNEL = 6'd0;
parameter FALSE = 1'b0;
parameter WAYS = 4;
parameter LINES = 64;
parameter LOBIT = 7;
parameter NVICTIM = 0;
localparam HIBIT=$clog2(LINES)-1+LOBIT;
localparam TAGBIT = HIBIT+2;	//14	+1 more for odd/even lines
localparam LOG_WAYS = $clog2(WAYS)-1;
// What to fill an empty cache line with.
parameter NOP = 8'd127;

input rst;
input clk;
input ce;
input invce;
input cpu_types_pkg::address_t snoop_adr;
input snoop_v;
input [5:0] snoop_cid;
input invall;
input invline;
input cpu_types_pkg::asid_t ip_asid;
input cpu_types_pkg::pc_address_ex_t ip;
output cpu_types_pkg::pc_address_ex_t ip_o;
output reg ihit_o;
output reg ihit;
input fetch_alt;
output reg alt_ihit_o;
output ICacheLine ic_line_hi_o;
output ICacheLine ic_line_lo_o;
output reg ic_valid;
output cpu_types_pkg::asid_t miss_asid;
output cpu_types_pkg::code_address_t miss_vadr;
input ICacheLine ic_line_i;
input [LOG_WAYS:0] wway;
input wr_ic;
input nop;
output nop_o;
input cpu_types_pkg::code_address_t dp;
input cpu_types_pkg::asid_t dp_asid;
output reg dhit_o;
output ICacheLine dc_line_o;
output reg dc_valid;
output reg port;
input port_i;

integer n, m;
integer g, j;

reg victim_wr;
ICacheLine victim_line;

reg icache_wre;
reg icache_wro;
reg icache_wrd;
ICacheLine ic_eline, ic_oline, dc_line;
reg [LOG_WAYS:0] ic_rwaye,ic_rwayo,wway;
always_comb icache_wre = wr_ic && !ic_line_i.vtag[LOBIT-1] && !port_i;
always_comb icache_wro = wr_ic &&  ic_line_i.vtag[LOBIT-1] && !port_i;
always_comb icache_wrd = wr_ic && port_i;
cpu_types_pkg::pc_address_ex_t ip2;
cpu_types_pkg::code_address_t dp2;
cache_tag_t [WAYS-1:0] victage;
cache_tag_t [WAYS-1:0] victago;
cache_tag_t victagd;
reg [LINES-1:0] valide [0:WAYS-1];
reg [LINES-1:0] valido [0:WAYS-1];
reg [LINES-1:0] validd [0:0];
wire [1:0] snoop_waye, snoop_wayo;
cache_tag_t [WAYS-1:0] ptagse;
cache_tag_t [WAYS-1:0] ptagso;
cache_tag_t ptagsd;
reg [2:0] victim_count, vcne, vcno;
ICacheLine [NVICTIM-1:0] victim_cache;
ICacheLine victim_eline, victim_oline;
ICacheLine victim_cache_eline, victim_cache_oline;
reg icache_wre2;
reg icache_wrd2;
reg vce,vco;
reg iel,iel2;		// increment even line

wire ihit1e, ihit1o;
wire dhit1;
reg ihit2e, ihit2o;
reg dhit2;
wire ihit2;
wire valid2e, valid2o, valid2d;
reg nop2;

always_ff @(posedge clk)
if (ce)
	nop2 <= nop;
assign nop_o = nop2;
always_ff @(posedge clk)
if (rst) begin
	ip2.stream <= 7'd1;
	ip2.pc <= RSTPC;
end
else begin
	if (ce)
		ip2 <= ip;
end
always_ff @(posedge clk)
if (ce)
	dp2 <= dp;
always_comb
begin
	/*
	if (ip[9]==1'b0 && ip[8:0] < {3'd5,6'd0} && ihit1e && PERFORMANCE)
		ihit = TRUE;
	else
	if (ip[9]==1'b1 && ip[8:0] < {3'd5,6'd0} && ihit1o && PERFORMANCE)
		ihit = TRUE;
	else
	*/
		ihit = ihit1e&ihit1o;
end
always_ff @(posedge clk)
if (rst)
	ihit2e <= 1'b0;
else begin
	if (ce)
		ihit2e <= ihit1e;
end
always_ff @(posedge clk)
if (rst)
	ihit2o <= 1'b0;
else begin
	if (ce)
		ihit2o <= ihit1o;
end
always_ff @(posedge clk)
if (rst)
	ihit_o <= 1'b0;
else begin
	if(ce)
		ihit_o <= ihit;
end
always_ff @(posedge clk)
if (rst)
	dhit2 <= 1'b0;
else begin
	if (ce)
		dhit2 <= dhit1;
end
always_ff @(posedge clk)
if (rst)
	dhit_o <= 1'b0;
else begin
	if (ce)
		dhit_o <= dhit1;
end

/*	
always_comb
	// *** The following causes the hit to tend to oscillate between hit
	//     and miss.
	// If cannot cross cache line can match on either odd or even.
	if (FALSE && ip2[5:0] < 6'd54)
		ihit_o <= ip2[LOBIT-1] ? ihit2o : ihit2e;
	// Might span lines, need hit on both even and odd lines
	else
		ihit_o <= ihit2e&ihit2o;
*/
assign ip_o = ip2;

always_comb	//ff @(posedge clk)
	// If cannot cross cache line can match on either odd or even.
	if (FALSE && ip2.pc[5:0] < 6'd54)
		ic_valid <= ip2.pc[LOBIT-1] ? valid2o : valid2e;
	else
		ic_valid <= valid2o & valid2e;

always_comb	//ff @(posedge clk)
	// If cannot cross cache line can match on either odd or even.
	dc_valid <= valid2d;

generate begin : gCacheRam
if (NVICTIM > 0) begin
// 512 wide x 256 deep, 1 cycle read latency.
sram_512x256_1rw1r uicme
(
	.rst(rst),
	.clk(clk),
	.ce(ce),
	.wr(icache_wre),
	.wadr({wway,ic_line_i.vadr[HIBIT:LOBIT]}),
	.radr({ic_rwaye,ip.pc[HIBIT:LOBIT]+ip.pc[LOBIT-1]}),
	.i(ic_line_i.data),
	.o(ic_eline.data),
	.wo(victim_eline.data)
);

sram_512x256_1rw1r uicmo
(
	.rst(rst),
	.clk(clk),
	.ce(ce),
	.wr(icache_wro),
	.wadr({wway,ic_line_i.vadr[HIBIT:LOBIT]}),
	.radr({ic_rwayo,ip.pc[HIBIT:LOBIT]}),
	.i(ic_line_i.data),
	.o(ic_oline.data),
	.wo(victim_oline.data)
);
end
else begin
//icache_sram_1r1w
sram_1r1w
#(
	.WID(cache_pkg::ICacheLineWidth),
	.DEP(LINES*WAYS)
)
uicme
(
	.rst(rst),
	.clk(clk),
	.ce(ce),
	.wr(icache_wre),
	.wadr({wway,ic_line_i.vtag[HIBIT:LOBIT]}),
	.radr({ic_rwaye,ip.pc[HIBIT:LOBIT]+ip.pc[LOBIT-1]}),
	.i(ic_line_i.data),
	.o(ic_eline.data)
);

sram_1r1w
#(
	.WID(cache_pkg::ICacheLineWidth),
	.DEP(LINES*WAYS)
)
uicmo
(
	.rst(rst),
	.clk(clk),
	.ce(ce),
	.wr(icache_wro),
	.wadr({wway,ic_line_i.vtag[HIBIT:LOBIT]}),
	.radr({ic_rwayo,ip.pc[HIBIT:LOBIT]}),
	.i(ic_line_i.data),
	.o(ic_oline.data)
);

sram_1r1w
#(
	.WID(cache_pkg::ICacheLineWidth),
	.DEP(LINES)
)
uicmd
(
	.rst(rst),
	.clk(clk),
	.ce(ce),
	.wr(icache_wrd),
	.wadr(ic_line_i.vtag[HIBIT-1:LOBIT-1]),
	.radr(dp[HIBIT-1:LOBIT-1]),
	.i(ic_line_i.data),
	.o(dc_line.data)
);

end
end
endgenerate

always_ff @(posedge clk)
	icache_wre2 <= icache_wre;
always_ff @(posedge clk)
	icache_wrd2 <= icache_wrd;

// Address of the victim line is the address of the update line.
// Write the victim cache if updating the cache and the victim line is valid.
always_ff @(posedge clk)
if ((icache_wre|icache_wro) && NVICTIM > 0) begin
	victim_line.vtag <= ic_line_i.vtag;
	victim_line.ptag <= ic_line_i.ptag;
	if (icache_wre) begin
		victim_line.v <= {4{valide[{wway,ic_line_i.vtag[HIBIT:LOBIT]}]}};
		victim_wr <= valide[{wway,ic_line_i.vtag[HIBIT:LOBIT]}];
	end
	else begin
		victim_line.v <= {4{valido[{wway,ic_line_i.vtag[HIBIT:LOBIT]}]}};
		victim_wr <= valido[{wway,ic_line_i.vtag[HIBIT:LOBIT]}];
	end
end
else
	victim_wr <= 'd0;

// Victim data comes from old data in the line that is being updated.
always_ff @(posedge clk)
if (NVICTIM > 0) begin
	if (icache_wre2)
		victim_line.data <= victim_eline.data;
	else
		victim_line.data <= victim_oline.data;
end

// Search the victim cache for the requested cache line.
always_comb
begin
	vcne = NVICTIM;
	vcno = NVICTIM;
	for (n = 0; n < NVICTIM; n = n + 1) begin
		if (victim_cache[n].vtag[$bits(cpu_types_pkg::address_t)-1:LOBIT-1]=={ip[$bits(cpu_types_pkg::address_t)-1:LOBIT]+ip[LOBIT-1],1'b0} && victim_cache[n].v==4'hF)
			vcne = n;
		if (victim_cache[n].vtag[$bits(cpu_types_pkg::address_t)-1:LOBIT-1]=={ip[$bits(cpu_types_pkg::address_t)-1:LOBIT],1'b1} && victim_cache[n].v==4'hF)
			vcno = n;
	end
end
always_comb//ff @(posedge clk)
	vce <= vcne < NVICTIM;
always_comb//ff @(posedge clk)
	vco <= vcno < NVICTIM;
always_comb//ff @(posedge clk)
	victim_cache_eline <= victim_cache[vce];
always_comb//ff @(posedge clk)
	victim_cache_oline <= victim_cache[vco];
always_comb
	iel <= ip2[LOBIT-1];
always_comb//ff @(posedge clk)
	iel2 <= iel;

// Get even/odd lines and swap them into hi,lo based on address.
always_comb
if (rst) begin
	ic_line_hi_o.data = {128{NOP}};
	ic_line_hi_o.v = 4'hF;
	ic_line_hi_o.m = 1'b0;
	ic_line_hi_o.vtag = RSTPC;
	ic_line_hi_o.ptag = RSTPC;
	ic_line_hi_o.asid = 16'd0;
	ic_line_lo_o.data = {128{NOP}};
	ic_line_lo_o.v = 4'hF;
	ic_line_lo_o.m = 1'b0;
	ic_line_lo_o.vtag = RSTPC;
	ic_line_lo_o.ptag = RSTPC;
	ic_line_lo_o.asid = 16'd0;
end
else begin
	ic_line_hi_o.data = {128{NOP}};
	ic_line_hi_o.v = 4'hF;
	ic_line_hi_o.m = 1'b0;
	ic_line_hi_o.vtag = RSTPC;
	ic_line_hi_o.ptag = RSTPC;
	ic_line_hi_o.asid = 16'd0;
	ic_line_lo_o.data = {128{NOP}};
	ic_line_lo_o.v = 4'hF;
	ic_line_lo_o.m = 1'b0;
	ic_line_lo_o.vtag = RSTPC;
	ic_line_lo_o.ptag = RSTPC;
	ic_line_lo_o.asid = 16'd0;
	case(iel2)
	1'b0:	
		begin
			if (vco) begin
				ic_line_hi_o = victim_cache_oline;
				ic_line_hi_o.v = 4'hF;
			end
			else begin
				ic_line_hi_o = 'd0;
				ic_line_hi_o.v = {4{ihit2o}};
				ic_line_hi_o.vtag = {ip2[$bits(cpu_types_pkg::address_t)-1:LOBIT],1'b1,{LOBIT-1{1'b0}}};
				ic_line_hi_o.data = ic_oline.data;
			end
			if (vce) begin
				ic_line_lo_o = victim_cache_eline;
				ic_line_lo_o.v = 4'hF;
			end
			else begin
				ic_line_lo_o = 'd0;
				ic_line_lo_o.v = {4{ihit2e}};
				ic_line_lo_o.vtag = {ip2[$bits(cpu_types_pkg::address_t)-1:LOBIT],{LOBIT{1'b0}}};
				ic_line_lo_o.data = ic_eline.data;
			end
		end
	1'b1:
		begin
			if (vce) begin
				ic_line_hi_o.v = 4'hF;
				ic_line_hi_o = victim_cache_eline;
			end
			else begin
				ic_line_hi_o = 'd0;
				ic_line_hi_o.v = {4{ihit2e}};
				ic_line_hi_o.vtag = {ip2[$bits(cpu_types_pkg::address_t)-1:LOBIT]+1'b1,{LOBIT{1'b0}}};
				ic_line_hi_o.data = ic_eline.data;
			end
			if (vco) begin
				ic_line_lo_o = victim_cache_oline;
				ic_line_lo_o.v = 4'hF;
			end
			else begin
				ic_line_lo_o = 'd0;
				ic_line_lo_o.v = {4{ihit2o}};
				ic_line_lo_o.vtag = {ip2[$bits(cpu_types_pkg::address_t)-1:LOBIT],1'b1,{LOBIT-1{1'b0}}};
				ic_line_lo_o.data = ic_oline.data;
			end
		end
	endcase
end

always_comb
begin
	dc_line_o.v = {4{dhit2}};
	dc_line_o.m = 1'b0;
	dc_line_o.vtag = {dp2[$bits(cpu_types_pkg::address_t)-1:LOBIT-1],{LOBIT-1{1'b0}}};
	dc_line_o.ptag = {dp2[$bits(cpu_types_pkg::address_t)-1:LOBIT-1],{LOBIT-1{1'b0}}};
	dc_line_o.data = dc_line.data;
	dc_line_o.asid = 16'h0;	// ToDo: remove asid
end

cache_tag
#(
	.LINES(LINES),
	.WAYS(WAYS),
	.TAGBIT(TAGBIT),
	.HIBIT(HIBIT),
	.LOBIT(LOBIT)
)
uictage
(
	.rst(rst),
	.clk(clk),
	.wr(icache_wre),
	.vadr_i(ic_line_i.vtag),
	.padr_i(ic_line_i.ptag),
	.way(wway),
	.rclk(clk),
	.ndx(ip.pc[HIBIT:LOBIT]+ip.pc[LOBIT-1]),	// virtual index (same bits as physical address)
	.tag(victage),
	.sndx(snoop_adr[HIBIT:LOBIT]),
	.ptag(ptagse)
);

cache_tag 
#(
	.LINES(LINES),
	.WAYS(WAYS),
	.TAGBIT(TAGBIT),
	.HIBIT(HIBIT),
	.LOBIT(LOBIT)
)
uictago
(
	.rst(rst),
	.clk(clk),
	.wr(icache_wro),
	.vadr_i(ic_line_i.vtag),
	.padr_i(ic_line_i.ptag),
	.way(wway),
	.rclk(clk),
	.ndx(ip.pc[HIBIT:LOBIT]),		// virtual index (same bits as physical address)
	.tag(victago),
	.sndx(snoop_adr[HIBIT:LOBIT]),
	.ptag(ptagso)
);

cache_tag
#(
	.LINES(LINES),
	.WAYS(1),
	.TAGBIT(TAGBIT),
	.HIBIT(HIBIT),
	.LOBIT(LOBIT)
)
uictagd
(
	.rst(rst),
	.clk(clk),
	.wr(icache_wrd),
	.vadr_i(ic_line_i.vtag),
	.padr_i(ic_line_i.ptag),
	.way(),
	.rclk(clk),
	.ndx(dp[HIBIT-1:LOBIT-1]),	// virtual index (same bits as physical address)
	.tag(victagd),
	.sndx(snoop_adr[HIBIT-1:LOBIT-1]),
	.ptag(ptagsd)
);

cache_hit
#(
	.LINES(LINES),
	.TAGBIT(TAGBIT),
	.WAYS(WAYS)
)
uichite
(
	.clk(clk),
	.adr(ip.pc),
	.ndx(ip.pc[HIBIT:LOBIT]+ip.pc[LOBIT-1]),
	.tag(victage),
	.valid(valide),
	.hit(ihit1e),
	.rway(ic_rwaye),
	.cv(valid2e)
);

cache_hit
#(
	.LINES(LINES),
	.TAGBIT(TAGBIT),
	.WAYS(WAYS)
)
uichito
(
	.clk(clk),
	.adr(ip.pc),
	.ndx(ip.pc[HIBIT:LOBIT]),
	.tag(victago),
	.valid(valido),
	.hit(ihit1o),
	.rway(ic_rwayo),
	.cv(valid2o)
);

cache_hit
#(
	.LINES(LINES),
	.TAGBIT(TAGBIT),
	.WAYS(1)
)
uichitd
(
	.clk(clk),
	.adr(dp),
	.ndx(dp[HIBIT-1:LOBIT-1]),
	.tag(victagd),
	.valid(validd),
	.hit(dhit1),
	.rway(),
	.cv(valid2d)
);

initial begin
for (m = 0; m < WAYS; m = m + 1) begin
  valide[m] = 'd0;
  valido[m] = 'd0;
end
validd[0] = 'd0;
end

always_ff @(posedge clk)
if (rst) begin
	victim_count <= 'd0;
	for (g = 0; g < WAYS; g = g + 1) begin
		valide[g] <= 'd0;
		valido[g] <= 'd0;
	end
end
else begin
	if (victim_wr) begin
		victim_count <= victim_count + 2'd1;
		if (victim_count>=NVICTIM-1)
			victim_count <= 3'd0;
		victim_cache[victim_count] <= victim_line;
	end
	if (icache_wre)
		valide[wway][ic_line_i.vtag[HIBIT:LOBIT]] <= 1'b1;
	else if (invce) begin
		for (g = 0; g < WAYS; g = g + 1) begin
			if (invline)
				valide[g][ic_line_i.vtag[HIBIT:LOBIT]] <= 1'b0;
			else if (invall)
				valide[g] <= 'd0;
		end
	end
	if (icache_wro)
		valido[wway][ic_line_i.vtag[HIBIT:LOBIT]] <= 1'b1;
	else if (invce) begin
		for (g = 0; g < WAYS; g = g + 1) begin
			if (invline)
				valido[g][ic_line_i.vtag[HIBIT:LOBIT]] <= 1'b0;
			else if (invall)
				valido[g] <= 'd0;
		end
	end
	if (icache_wrd)
		validd[0][ic_line_i.vtag[HIBIT-1:LOBIT-1]] <= 1'b1;
	else if (invce) begin
		if (invline)
			validd[0][ic_line_i.vtag[HIBIT-1:LOBIT-1]] <= 1'b0;
		else if (invall)
			validd[0] <= 'd0;
	end
	// Two different virtual addresses pointing to the same physical address will
	// end up in the same set as long as the cache is smaller than a memory page
	// in size. So, there is no need to compare every physical address, just every
	// address in a set will do.
	if (snoop_v && snoop_cid != CHANNEL) begin
		if (snoop_adr[$bits(cpu_types_pkg::address_t)-1:TAGBIT]==ptagse[0])
			valide[0][snoop_adr[HIBIT:LOBIT]] <= 1'b0;
		if (snoop_adr[$bits(cpu_types_pkg::address_t)-1:TAGBIT]==ptagse[1])
			valide[1][snoop_adr[HIBIT:LOBIT]] <= 1'b0;
		if (snoop_adr[$bits(cpu_types_pkg::address_t)-1:TAGBIT]==ptagse[2])
			valide[2][snoop_adr[HIBIT:LOBIT]] <= 1'b0;
		if (snoop_adr[$bits(cpu_types_pkg::address_t)-1:TAGBIT]==ptagse[3])
			valide[3][snoop_adr[HIBIT:LOBIT]] <= 1'b0;

		if (snoop_adr[$bits(cpu_types_pkg::address_t)-1:TAGBIT]==ptagso[0])
			valido[0][snoop_adr[HIBIT:LOBIT]] <= 1'b0;
		if (snoop_adr[$bits(cpu_types_pkg::address_t)-1:TAGBIT]==ptagso[1])
			valido[1][snoop_adr[HIBIT:LOBIT]] <= 1'b0;
		if (snoop_adr[$bits(cpu_types_pkg::address_t)-1:TAGBIT]==ptagso[2])
			valido[2][snoop_adr[HIBIT:LOBIT]] <= 1'b0;
		if (snoop_adr[$bits(cpu_types_pkg::address_t)-1:TAGBIT]==ptagso[3])
			valido[3][snoop_adr[HIBIT:LOBIT]] <= 1'b0;

		/*
		if (snoop_adr[$bits(cpu_types_pkg::address_t)-1:TAGBIT]==ptagsd)
			validd[0][snoop_adr[HIBIT:LOBIT]] <= 1'b0;
		*/
	// Invalidate victim cache entries matching the snoop address
		for (g = 0; g < NVICTIM; g = g + 1) begin
			if (snoop_adr[$bits(cpu_types_pkg::address_t)-1:LOBIT]==victim_cache[g].ptag[$bits(cpu_types_pkg::address_t)-1:LOBIT])
				victim_cache[g].v <= 4'h0;
		end
	end
end

// Set miss address

always_comb
	if (!ihit1e)
		miss_asid = ip_asid;
	else if (!ihit1o)
		miss_asid = ip_asid;
	else if (!dhit1)
		miss_asid = dp_asid;
	else
		miss_asid = 'd0;

always_comb
	if (!ihit1e)
		miss_vadr = {ip.pc[$bits(cpu_types_pkg::address_t)-1:LOBIT]+ip.pc[LOBIT-1],1'b0,{LOBIT-1{1'b0}}};
	else if (!ihit1o)
		miss_vadr = {ip.pc[$bits(cpu_types_pkg::address_t)-1:LOBIT],1'b1,{LOBIT-1{1'b0}}};
//	else if (!dhit1)
//		miss_vadr = {dp[$bits(cpu_types_pkg::address_t)-1:LOBIT-1],{LOBIT-1{1'b0}}};
	else
		miss_vadr = 32'hFFFD0000;

always_comb
	if (!ihit1e)
		port = 1'b0;
	else if (!ihit1o)
		port = 1'b0;
//	else if (!dhit1)
//		port = 1'b1;
	else
		port = 1'b0;

endmodule
