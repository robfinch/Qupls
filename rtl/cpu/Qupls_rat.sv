// ============================================================================
//        __
//   \\__/ o\    (C) 2014-2023  Robert Finch, Waterloo
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
// Status: Untested, unused
//
// Q+ Register Alias Table
//
// ToDo: add a valid bit
// Research shows having 16 checkpoints is almost as good as infinity.
// ============================================================================
//
import QuplsPkg::*;

module Qupls_rat(rst, clk, nq, stallq, cndx, avail, flush, miss_cp, wr0, wr1, wr2, wr3,
	qbr0, qbr1, qbr2, qbr3,
	rn,
	rrn,
	vn,
	wra, wrra, wrb, wrrb, wrc, wrrc, wrd, wrrd, cmtav, cmtbv, cmtcv, cmtdv,
	cmtaa, cmtba, cmtca, cmtda, cmtap, cmtbp, cmtcp, cmtdp, cmtbr,
	freea, freeb, freec, freed, free_bitlist);
parameter NPORT = 16;
input rst;
input clk;
input nq;			// enqueue instruction
output reg stallq;
input qbr0;		// enqueue branch, slot 0
input qbr1;
input qbr2;
input qbr3;
output reg [3:0] cndx;		// current checkpoint index
input [PREGS-1:0] avail;	// list of available registers at checkpoint comes from ROB
input flush;							// pipeline flush
input [3:0] miss_cp;			// checkpoint map index of branch miss
input wr0;
input wr1;
input wr2;
input wr3;
input aregno_t wra;	// architectural register
input aregno_t wrb;
input aregno_t wrc;
input aregno_t wrd;
input pregno_t wrra;	// physical register
input pregno_t wrrb;
input pregno_t wrrc;
input pregno_t wrrd;
input cmtav;							// commit valid
input cmtbv;
input cmtcv;
input cmtdv;
input aregno_t cmtaa;				// architectural register being committed
input aregno_t cmtba;
input aregno_t cmtca;
input aregno_t cmtda;
input pregno_t cmtap;				// physical register to commit
input pregno_t cmtbp;
input pregno_t cmtcp;
input pregno_t cmtdp;
input cmtbr;								// comitting a branch
input aregno_t rn [NPORT-1:0];		// architectural register
output pregno_t rrn [NPORT-1:0];	// physical register
output reg [NPORT-1:0] vn;			// translation is valid for register
output pregno_t freea;	// previous register to free
output pregno_t freeb;
output pregno_t freec;
output pregno_t freed;
output reg [PREGS-1:0] free_bitlist;	// bit vector of registers to free on branch miss


integer n,m,n1,n2;
reg [AREGS-1:0] cpram_we;
wire [AREGS*8-1:0] cpram_out;
reg [AREGS*8-1:0] cpram_in;

Qupls_checkpointRam cpram1
(
	.clka(clk),
	.ena(1'b1),
	.wea(cpram_we),
	.addra(cndx),
	.dina(cpram_in),
	.clkb(clk),
	.enb(1'b1),
	.addrb(cndx),
	.doutb(cpram_out)
);

genvar g;
integer mndx;

wire qbr = qbr0|qbr1|qbr2|qbr3;
// number of outstanding branches
reg [5:0] nob;
wire qbr_ok = qbr && nob < 6'd15;

// Read register names from current checkpoint.

generate begin : gRRN
	for (g = 0; g < NPORT; g = g + 1) begin
		always_comb
			rrn[g] = cpram_out >> {rn[g],3'b0};
		always_comb
			vn[g] = 1'b1;//cpmv[cndx][rn[g]];
	end
end
endgenerate

// If committing register, free previously mapped one, else if discarding the
// register add it to the free list.
always_ff @(posedge clk)
if (rst)
	freea <= 'd0;
else begin
	if (cmtav)
		freea <= cpram_out >> {cmtaa,3'b0};
	else
	 	freea <= cmtap;
end

// If committing register, free previously mapped one, else if discarding the
// register add it to the free list.
always_ff @(posedge clk)
if (rst)
	freeb <= 'd0;
else begin
	if (cmtbv)
		freeb <= cpram_out >> {cmtba,3'b0};
	else
	 	freeb <= cmtbp;
end

// If committing register, free previously mapped one, else if discarding the
// register add it to the free list.
always_ff @(posedge clk)
if (rst)
	freec <= 'd0;
else begin
	if (cmtcv)
		freec <= cpram_out >> {cmtca,3'b0};
	else
	 	freec <= cmtcp;
end

// If committing register, free previously mapped one, else if discarding the
// register add it to the free list.
always_ff @(posedge clk)
if (rst)
	freed <= 'd0;
else begin
	if (cmtav)
		freed <= cpram_out >> {cmtda,3'b0};
	else
	 	freed <= cmtdp;
end

// Adjust the checkpoint index. The index decreases by the number of committed
// branches. The index increases if a branch is queued. Only one branch is
// allowed to queue per cycle.

always_ff @(posedge clk)
if (rst)
	nob <= 'd0;
else
	nob <= nob + qbr_ok - cmtbr;

// Set checkpoint index
// Backup the checkpoint on a branch miss.
// Increment checkpoint on a branch queue

always_ff @(posedge clk)
if (rst)
	cndx <= 'd0;
else begin
	if (flush)
		cndx <= miss_cp;
	else if (qbr_ok)
		cndx <= cndx + 1;
end

// Stall the enqueue of instructions if there are too many outstanding branches.
always_comb
if (rst)
	stallq <= 'd0;
else
	stallq <= qbr && nob==6'd15;

// Committing and queuing target register cannot be the same.
always_comb
begin
	cpram_in = 'd0;
	cpram_in = cpram_in | (({8{cmtav}} & cmtap) << {cmtaa,3'b0});
	cpram_in = cpram_in | (({8{cmtbv}} & cmtbp) << {cmtba,3'b0});
	cpram_in = cpram_in | (({8{cmtcv}} & cmtcp) << {cmtca,3'b0});
	cpram_in = cpram_in | (({8{cmtdv}} & cmtdp) << {cmtda,3'b0});
	cpram_in = cpram_in | (({8{nq & wr0}} & wrra) << {wra,3'b0});
	cpram_in = cpram_in | (({8{nq & wr1}} & wrrb) << {wrb,3'b0});
	cpram_in = cpram_in | (({8{nq & wr2}} & wrrc) << {wrc,3'b0});
	cpram_in = cpram_in | (({8{nq & wr3}} & wrrd) << {wrd,3'b0});
end

// Add registers to the checkpoint map.
always_comb
begin
	cpram_we = 'd0;
	cpram_we = cpram_we | (cmtav << cmtaa);
	cpram_we = cpram_we | (cmtbv << cmtba);
	cpram_we = cpram_we | (cmtcv << cmtca);
	cpram_we = cpram_we | (cmtdv << cmtda);

	cpram_we = cpram_we | ({nq & wr0} << wra);
	cpram_we = cpram_we | ({nq & wr1} << wrb);
	cpram_we = cpram_we | ({nq & wr2} << wrc);
	cpram_we = cpram_we | ({nq & wr3} << wrd);

end

// Add registers allocated since the branch miss instruction to the list of
// registers to be freed.
always_comb
begin
	// But not the registers allocated up to the branch miss
	if (flush)
		free_bitlist = avail;
	else
		free_bitlist = 'd0;
end

endmodule
