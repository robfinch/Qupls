// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2026  Robert Finch, Waterloo
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
//
// Keeps track of the cache lines, tags, and victim cache.
// Detects a miss
//
// The icache returns a hi/lo pair of cache lines. This is to allow instructions
// to span cache lines.
//
// 3700 LUTs / 1700 FFs / 37 BRAMs		32kB cache
//
// ============================================================================

import const_pkg::*;
import wishbone_pkg::*;
import cache_pkg::*;

module icache(rst,clk,ce,invce,snoop_adr,snoop_v,snoop_tid,invall,invline,
	nop,nop_o,
	ip,ip_asid,ip_o,ihit_o,ihit,ic_line_hi_o,ic_line_lo_o,ic_valid,
	miss_vadr,miss_asid,miss_v,
	ic_line_i,wway,wr_ic,
	dp, dhit_o, dc_line_o, dc_valid, port, port_i
	);
parameter CORENO = 6'd1;
parameter CHANNEL = 6'd0;
parameter WAYS = 4;
parameter LINES = 64;
parameter LOBIT = 7;
parameter NVICTIM = 4;
localparam HIBIT=$clog2(LINES)-1+LOBIT;
localparam TAGBIT = HIBIT+2;	//14	+1 more for odd/even lines
localparam LOG_WAYS = $clog2(WAYS)-1;
// What to fill an empty cache line with.
parameter NOP = 8'd255;

input rst;
input clk;
input ce;
input invce;
input cpu_types_pkg::address_t snoop_adr;
input snoop_v;
input wishbone_pkg::wb_tranid_t snoop_tid;
input invall;
input invline;
input cpu_types_pkg::pc_address_ex_t ip;
input cpu_types_pkg::asid_t ip_asid;
output cpu_types_pkg::pc_address_ex_t ip_o;
output reg ihit_o;
output reg ihit;
output ICacheLine ic_line_hi_o;
output ICacheLine ic_line_lo_o;
output reg ic_valid;
output cpu_types_pkg::code_address_t miss_vadr;
output cpu_types_pkg::asid_t miss_asid;
output reg miss_v;
input ICacheLine ic_line_i;
input [LOG_WAYS:0] wway;
input wr_ic;
input nop;
output nop_o;
// Data port I/Os
input cpu_types_pkg::code_address_t dp;
output reg dhit_o;
output ICacheLine dc_line_o;
output reg dc_valid;
output reg port;
input port_i;


reg icache_wre;			// write the even line
reg icache_wro;			// write the odd line
reg icache_wrd;			// write the data port
reg icache_wre2;
ICacheLine ic_eline, ic_oline, dc_line;
reg [LOG_WAYS:0] ic_rwaye,ic_rwayo,wway;
cpu_types_pkg::code_address_t dp2;
cache_tag_t [WAYS-1:0] victage;
cache_tag_t [WAYS-1:0] victago;
cache_tag_t victagd;
wire [LINES-1:0] valide [0:WAYS-1];
wire [LINES-1:0] valido [0:WAYS-1];
reg [LINES-1:0] validd [0:0];
cache_tag_t [WAYS-1:0] ptagse;
cache_tag_t [WAYS-1:0] ptagso;
cache_tag_t ptagsd;

// Victim cache signals
reg victim_wr;
ICacheLine victim_line;
wire vce, vco;													// even, odd output is valid
ICacheLine victim_eline, victim_oline;
ICacheLine victim_cache_eline, victim_cache_oline;	// output lines from cache

reg icache_wrd2;
reg iel;					// increment even line

wire ihit1e, ihit1o;
wire dhit1;
reg ihit2e, ihit2o;
reg dhit2;
wire ihit2;
wire valid2e, valid2o, valid2d;
reg nop2;

// Write controls
always_comb icache_wre = wr_ic && !ic_line_i.vtag[LOBIT-1] && !port_i;
always_comb icache_wro = wr_ic &&  ic_line_i.vtag[LOBIT-1] && !port_i;
always_comb icache_wrd = wr_ic && port_i;

always_ff @(posedge clk)
	icache_wre2 <= icache_wre;
always_ff @(posedge clk)
	icache_wrd2 <= icache_wrd;


always_ff @(posedge clk)
if (ce)
	nop2 <= nop;
assign nop_o = nop2;

// Pipeline address inputs
always_ff @(posedge clk)
if (rst) begin
	ip_o.stream <= 7'd1;
	ip_o.pc <= RSTPC;
end
else begin
	if (ce)
		ip_o <= ip;
end

always_ff @(posedge clk)
if (ce)
	dp2 <= dp;

// Cache hit signals
// Valid hit only if both even and odd lines are hit.
always_comb
	ihit = ihit1e&ihit1o;

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

always_comb
	ic_valid = valid2o & valid2e;

always_comb
	dc_valid = valid2d;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Cache RAMs
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

// 512 wide x 256 deep, 1 cycle read latency.
sram_512x256_1rw1r uicme
(
	.rst(rst),
	.clk(clk),
	.ce(ce),
	.wr(icache_wre),
	.wadr({wway,ic_line_i.vtag[HIBIT:LOBIT]}),
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
	.wadr({wway,ic_line_i.vtag[HIBIT:LOBIT]}),
	.radr({ic_rwayo,ip.pc[HIBIT:LOBIT]}),
	.i(ic_line_i.data),
	.o(ic_oline.data),
	.wo(victim_oline.data)
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

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Victim Cache
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Address of the victim line is the address of the update line.
// Write the victim cache if updating the cache and the victim line is valid.
always_ff @(posedge clk)
if (icache_wre|icache_wro) begin
	victim_line.vtag <= ic_line_i.vtag;
	victim_line.ptag <= ic_line_i.ptag;
end

always_ff @(posedge clk)
if (icache_wre|icache_wro) begin
	if (icache_wre)
		victim_line.v <= {4{valide[{wway,ic_line_i.vtag[HIBIT:LOBIT]}]}};
	else
		victim_line.v <= {4{valido[{wway,ic_line_i.vtag[HIBIT:LOBIT]}]}};
end

always_ff @(posedge clk)
if ((icache_wre|icache_wro) && NVICTIM > 0) begin
	if (icache_wre)
		victim_wr <= valide[{wway,ic_line_i.vtag[HIBIT:LOBIT]}];
	else
		victim_wr <= valido[{wway,ic_line_i.vtag[HIBIT:LOBIT]}];
end
else
	victim_wr <= 1'b0;

// Victim data comes from old data in the line that is being updated.
always_ff @(posedge clk)
begin
	if (icache_wre2)
		victim_line.data <= victim_eline.data;
	else
		victim_line.data <= victim_oline.data;
end

always_ff @(posedge clk)
begin
	if (icache_wre2)
		victim_line.m <= FALSE;
	else
		victim_line.m <= FALSE;
end

victim_cache
#(
	.CORENO(CORENO),
	.CHANNEL(CHANNEL),
	.NVICTIM(NVICTIM),
	.LOBIT(LOBIT)
)
uvc1
(
	.rst(rst),
	.clk(clk),
	.wr(victim_wr),
	.line(victim_line),
	.snoop_v(snoop_v),
	.snoop_tid(snoop_tid),
	.snoop_adr(snoop_adr),
	.ip(ip.pc),
	.vce(vce),
	.vco(vco),
	.eline_o(victim_cache_eline),
	.oline_o(victim_cache_oline)
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Cache line outputs
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

always_comb
	iel <= ip_o[LOBIT-1];

// Get even/odd lines and swap them into hi,lo based on address.
always_comb
if (rst) begin
	ic_line_hi_o.data = {64{NOP}};
	ic_line_hi_o.v = 4'hF;
	ic_line_hi_o.m = 1'b0;
	ic_line_hi_o.vtag = RSTPC;
	ic_line_hi_o.ptag = RSTPC;
	ic_line_lo_o.data = {64{NOP}};
	ic_line_lo_o.v = 4'hF;
	ic_line_lo_o.m = 1'b0;
	ic_line_lo_o.vtag = RSTPC;
	ic_line_lo_o.ptag = RSTPC;
end
else begin
	ic_line_hi_o.data = {64{NOP}};
	ic_line_hi_o.v = 4'hF;
	ic_line_hi_o.m = 1'b0;
	ic_line_hi_o.vtag = RSTPC;
	ic_line_hi_o.ptag = RSTPC;
	ic_line_lo_o.data = {64{NOP}};
	ic_line_lo_o.v = 4'hF;
	ic_line_lo_o.m = 1'b0;
	ic_line_lo_o.vtag = RSTPC;
	ic_line_lo_o.ptag = RSTPC;
	case(iel)
	1'b0:	
		begin
			if (vco) begin
				ic_line_hi_o = victim_cache_oline;
				ic_line_hi_o.v = 4'hF;
			end
			else begin
				ic_line_hi_o = {$bits(ICacheLine){1'b0}};
				ic_line_hi_o.v = {4{ihit2o}};
				ic_line_hi_o.vtag = {ip_o[$bits(cpu_types_pkg::address_t)-1:LOBIT],1'b1,{LOBIT-1{1'b0}}};
				ic_line_hi_o.data = ic_oline.data;
			end
			if (vce) begin
				ic_line_lo_o = victim_cache_eline;
				ic_line_lo_o.v = 4'hF;
			end
			else begin
				ic_line_lo_o = {$bits(ICacheLine){1'b0}};
				ic_line_lo_o.v = {4{ihit2e}};
				ic_line_lo_o.vtag = {ip_o[$bits(cpu_types_pkg::address_t)-1:LOBIT],{LOBIT{1'b0}}};
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
				ic_line_hi_o = {$bits(ICacheLine){1'b0}};
				ic_line_hi_o.v = {4{ihit2e}};
				ic_line_hi_o.vtag = {ip_o[$bits(cpu_types_pkg::address_t)-1:LOBIT]+1'b1,{LOBIT{1'b0}}};
				ic_line_hi_o.data = ic_eline.data;
			end
			if (vco) begin
				ic_line_lo_o = victim_cache_oline;
				ic_line_lo_o.v = 4'hF;
			end
			else begin
				ic_line_lo_o = {$bits(ICacheLine){1'b0}};
				ic_line_lo_o.v = {4{ihit2o}};
				ic_line_lo_o.vtag = {ip_o[$bits(cpu_types_pkg::address_t)-1:LOBIT],1'b1,{LOBIT-1{1'b0}}};
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
	.way(1'b0),
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

icache_valid_bits
#(
	.CORENO(CORENO),
	.CHANNEL(CHANNEL),
	.LINES(LINES),
	.WAYS(WAYS),
	.HIBIT(HIBIT),
	.LOBIT(LOBIT),
	.TAGBIT(TAGBIT)
)
uicvbe 
(
	.rst(rst),
	.clk(clk),
	.invce(invce),
	.invline(invline),
	.invall(invall),
	.wr(icache_wre),
	.wway(wway),
	.line(ic_line_i),
	.ptags(ptagse),
	.snoop_v(snoop_v),
	.snoop_tid(snoop_tid),
	.snoop_adr(snoop_adr),
	.valid(valide)
);

icache_valid_bits
#(
	.CORENO(CORENO),
	.CHANNEL(CHANNEL),
	.LINES(LINES),
	.WAYS(WAYS),
	.HIBIT(HIBIT),
	.LOBIT(LOBIT),
	.TAGBIT(TAGBIT)
)
uicvbo
(
	.rst(rst),
	.clk(clk),
	.invce(invce),
	.invline(invline),
	.invall(invall),
	.wr(icache_wro),
	.wway(wway),
	.line(ic_line_i),
	.ptags(ptagso),
	.snoop_v(snoop_v),
	.snoop_tid(snoop_tid),
	.snoop_adr(snoop_adr),
	.valid(valido)
);

initial begin
validd[0] = 'd0;
end

always_ff @(posedge clk)
if (rst) begin
end
else begin
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
	if (snoop_v && (snoop_tid.core!=CORENO || snoop_tid.channel != CHANNEL)) begin
		/*
		if (snoop_adr[$bits(cpu_types_pkg::address_t)-1:TAGBIT]==ptagsd)
			validd[0][snoop_adr[HIBIT:LOBIT]] <= 1'b0;
		*/
	end
end

// Set miss address

always_ff @(posedge clk)
begin
	if (!ihit1e)
		miss_vadr <= {ip.pc[$bits(cpu_types_pkg::address_t)-1:LOBIT]+ip.pc[LOBIT-1],1'b0,{LOBIT-1{1'b0}}};
	else if (!ihit1o)
		miss_vadr <= {ip.pc[$bits(cpu_types_pkg::address_t)-1:LOBIT],1'b1,{LOBIT-1{1'b0}}};
//	else if (!dhit1)
//		miss_vadr = {dp[$bits(cpu_types_pkg::address_t)-1:LOBIT-1],{LOBIT-1{1'b0}}};
	else
		miss_vadr <= 32'hFFFD0000;
end

always_ff @(posedge clk)
begin
	if (!ihit1e)
		miss_v <= VAL;
	else if (!ihit1o)
		miss_v <= VAL;
//	else if (!dhit1)
//		miss_v = VAL;
	else
		miss_v <= INV;
end

always_ff @(posedge clk)
	miss_asid <= ip_asid;

always_ff @(posedge clk)
begin
	if (!ihit1e)
		port = 1'b0;
	else if (!ihit1o)
		port = 1'b0;
//	else if (!dhit1)
//		port = 1'b1;
	else
		port = 1'b0;
end

endmodule
