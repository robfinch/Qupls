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
//
// 6683 LUTs / 590 FFs for 68/192
// 10010 LUTs / 860 FFs for 2*64/192 (two banks of 64 arch. regs).
// 13000 LUTs / 1100 FFs for 4*64/192 (four banks of 64 arch. regs).
// 18500 LUTs / 1410 FFs for 8*64/192 (eight banks of 64 arch. regs).
// ============================================================================
//
import QuplsPkg::*;

module Qupls_rat(rst, clk, nq, stallq, cndx_o, avail_i, restore, miss_cp, wr0, wr1, wr2, wr3,
	qbr0, qbr1, qbr2, qbr3,
	rn,
	rrn,
	vn, 
	wrbanka, wrbankb, wrbankc, wrbankd, cmtbanka, cmtbankb, cmtbankc, cmtbankd, rnbank,
	wra, wrra, wrb, wrrb, wrc, wrrc, wrd, wrrd, cmtav, cmtbv, cmtcv, cmtdv,
	cmtaa, cmtba, cmtca, cmtda, cmtap, cmtbp, cmtcp, cmtdp, cmtbr,
	freea, freeb, freec, freed, free_bitlist);
parameter NPORT = 16;
parameter BANKS = 1;
localparam RBIT=$clog2(PREGS);
localparam BBIT=0;//$clog2(BANKS)-1;
input rst;
input clk;
input nq;			// enqueue instruction
output reg stallq;
input qbr0;		// enqueue branch, slot 0
input qbr1;
input qbr2;
input qbr3;
output [3:0] cndx_o;			// current checkpoint index
input [PREGS-1:0] avail_i;	// list of available registers from renamer
input restore;						// checkpoint restore
input [3:0] miss_cp;			// checkpoint map index of branch miss
input wr0;
input wr1;
input wr2;
input wr3;
input [BBIT:0] wrbanka;
input [BBIT:0] wrbankb;
input [BBIT:0] wrbankc;
input [BBIT:0] wrbankd;
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
input [BBIT:0] cmtbanka;
input [BBIT:0] cmtbankb;
input [BBIT:0] cmtbankc;
input [BBIT:0] cmtbankd;
input aregno_t cmtaa;				// architectural register being committed
input aregno_t cmtba;
input aregno_t cmtca;
input aregno_t cmtda;
input pregno_t cmtap;				// physical register to commit
input pregno_t cmtbp;
input pregno_t cmtcp;
input pregno_t cmtdp;
input cmtbr;								// comitting a branch
input [BBIT:0] rnbank [NPORT-1:0];
input aregno_t [NPORT-1:0] rn;		// architectural register
output pregno_t [NPORT-1:0] rrn;	// physical register
output reg [NPORT-1:0] vn;			// register valid
output pregno_t freea;	// previous register to free
output pregno_t freeb;
output pregno_t freec;
output pregno_t freed;
output reg [PREGS-1:0] free_bitlist;	// bit vector of registers to free on branch miss


integer n,m,n1,n2,n3;
localparam WE_WIDTH = $bits(checkpoint_t)/$bits(vpregno_t);
reg [WE_WIDTH-1:0] cpram_we;
localparam RAMWIDTH = AREGS*BANKS*RBIT+PREGS;
checkpoint_t cpram_out;
checkpoint_t cpram_outr;
checkpoint_t cpram_in;
reg new_chkpt;							// new_chkpt map for current checkpoint
reg [3:0] cndx;
assign cndx_o = cndx;

Qupls_checkpointRam #(.BANKS(BANKS)) cpram1
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
// Bypass new register mappings if reg selected.
generate begin : gRRN
	for (g = 0; g < NPORT; g = g + 1) begin
		always_comb
			rrn[g] = rn[g]==7'd0 ? 8'd0 :
							 wr0 && rn[g]==wra ? wrra :
							 wr1 && rn[g]==wrb ? wrrb :
							 wr2 && rn[g]==wrc ? wrrc :
							 wr3 && rn[g]==wrd ? wrrd :
							 	(BANKS < 2) ? cpram_out.regmap[rn[g]].pregs[0].rg :
							 								cpram_out.regmap[rn[g]].pregs[rnbank[g]].rg;
//							 	 >> ((BANKS < 2) ? (rn[g] * RBIT) : {(rn[g] * RBIT),rnbank[g]});
		always_comb
			vn[g] = rn[g]==7'd0 ? 1'b1 :
							wr0 && rn[g]==wra ? 1'b1 :
							wr1 && rn[g]==wrb ? 1'b1 :
							wr2 && rn[g]==wrc ? 1'b1 :
							wr3 && rn[g]==wrd ? 1'b1 :
							(BANKS < 2) ? cpram_out.regmap[rn[g]].pregs[0].v :
							 								cpram_out.regmap[rn[g]].pregs[rnbank[g]].v;
	end
end
endgenerate

// If committing register, free previously mapped one, else if discarding the
// register add it to the free list.
always_ff @(posedge clk)
if (rst)
	freea <= 'd0;
else begin
	if (cmtav) begin
		if (BANKS < 2)
			freea <= cpram_out.regmap[cmtaa].pregs[0].rg;// >> (cmtaa * RBIT);
		else
			freea <= cpram_out.regmap[cmtaa].pregs[cmtbanka].rg;// >> {(cmtaa * RBIT),cmtbanka};
	end
	else
	 	freea <= cmtap;
end

// If committing register, free previously mapped one, else if discarding the
// register add it to the free list.
always_ff @(posedge clk)
if (rst)
	freeb <= 'd0;
else begin
	if (cmtbv) begin
		if (BANKS < 2)
			freeb <= cpram_out.regmap[cmtba].pregs[0].rg;// >> (cmtaa * RBIT);
		else
			freeb <= cpram_out.regmap[cmtba].pregs[cmtbankb].rg;// >> {(cmtaa * RBIT),cmtbanka};
	end
	else
	 	freeb <= cmtbp;
end

// If committing register, free previously mapped one, else if discarding the
// register add it to the free list.
always_ff @(posedge clk)
if (rst)
	freec <= 'd0;
else begin
	if (cmtcv) begin
		if (BANKS < 2)
			freec <= cpram_out.regmap[cmtca].pregs[0].rg;// >> (cmtaa * RBIT);
		else
			freec <= cpram_out.regmap[cmtca].pregs[cmtbankc].rg;// >> {(cmtaa * RBIT),cmtbanka};
	end
	else
	 	freec <= cmtcp;
end

// If committing register, free previously mapped one, else if discarding the
// register add it to the free list.
always_ff @(posedge clk)
if (rst)
	freed <= 'd0;
else begin
	if (cmtav) begin
		if (BANKS < 2)
			freed <= cpram_out.regmap[cmtda].pregs[0].rg;// >> (cmtaa * RBIT);
		else
			freed <= cpram_out.regmap[cmtda].pregs[cmtbankd].rg;// >> {(cmtaa * RBIT),cmtbanka};
	end
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
if (rst) begin
	cndx <= 'd0;
	new_chkpt <= 'd0;
end
else begin
	new_chkpt <= 'd0;
	if (restore)
		cndx <= miss_cp;
	else if (qbr_ok) begin
		cndx <= cndx + 1;
		new_chkpt <= 1'b1;
	end
end

// Stall the enqueue of instructions if there are too many outstanding branches.
always_comb
if (rst)
	stallq <= 'd0;
else begin
	stallq <= 1'b0;
	for (n3 = 0; n3 < AREGS; n3 = n3 + 1)
		if (/*(rrn[n3]==8'd0 && rn[n3]!=7'd0) || */ qbr && nob==6'd15)
			stallq <= 1'b1;
end


always_ff @(posedge clk)
	cpram_outr <= cpram_out;

// Committing and queuing target register cannot be the same.
// The target register established during queue is marked invalid. It will not
// be valid until a value commits.
always_comb
begin
	cpram_in = 'd0;
	if (BANKS < 2) begin
		
		if (cmtav) begin cpram_in.regmap[cmtaa].pregs[0].rg = cmtap; cpram_in.regmap[cmtaa].pregs[0].v = VAL; end
		if (cmtbv) begin cpram_in.regmap[cmtba].pregs[0].rg = cmtbp; cpram_in.regmap[cmtba].pregs[0].v = VAL; end
		if (cmtcv) begin cpram_in.regmap[cmtca].pregs[0].rg = cmtcp; cpram_in.regmap[cmtca].pregs[0].v = VAL; end
		if (cmtdv) begin cpram_in.regmap[cmtda].pregs[0].rg = cmtdp; cpram_in.regmap[cmtda].pregs[0].v = VAL; end
		
		if (wr0) begin cpram_in.regmap[wra].pregs[0].rg = wrra; cpram_in.regmap[wra].pregs[0].v = INV; end
		if (wr1) begin cpram_in.regmap[wrb].pregs[0].rg = wrrb; cpram_in.regmap[wrb].pregs[0].v = INV; end
		if (wr2) begin cpram_in.regmap[wrc].pregs[0].rg = wrrc; cpram_in.regmap[wrc].pregs[0].v = INV; end
		if (wr3) begin cpram_in.regmap[wrd].pregs[0].rg = wrrd; cpram_in.regmap[wrd].pregs[0].v = INV; end
		/*
		cpram_in = cpram_in | (({RBIT{cmtav}} & cmtap) << {(cmtaa * RBIT)});
		cpram_in = cpram_in | (({RBIT{cmtbv}} & cmtbp) << {(cmtba * RBIT)});
		cpram_in = cpram_in | (({RBIT{cmtcv}} & cmtcp) << {(cmtca * RBIT)});
		cpram_in = cpram_in | (({RBIT{cmtdv}} & cmtdp) << {(cmtda * RBIT)});
		cpram_in = cpram_in | (({RBIT{wr0}} & wrra) << {(wra * RBIT)});
		cpram_in = cpram_in | (({RBIT{wr1}} & wrrb) << {(wrb * RBIT)});
		cpram_in = cpram_in | (({RBIT{wr2}} & wrrc) << {(wrc * RBIT)});
		cpram_in = cpram_in | (({RBIT{wr3}} & wrrd) << {(wrd * RBIT)});
		*/
	end
	// ToDo: for more than one bank
	else begin
		/*
		if (cmtav) cpram_in.regmap[cmtaa].pregs[cmtbanka].rg = cmtap;
		if (cmtbv) cpram_in.regmap[cmtba].pregs[cmtbankb].rg = cmtbp;
		if (cmtcv) cpram_in.regmap[cmtca].pregs[cmtbankc].rg = cmtcp;
		if (cmtdv) cpram_in.regmap[cmtda].pregs[cmtbankd].rg = cmtdp;
		*/
		if (wr0) cpram_in.regmap[wra].pregs[wrbanka].rg = wrra;
		if (wr1) cpram_in.regmap[wrb].pregs[wrbankb].rg = wrrb;
		if (wr2) cpram_in.regmap[wrc].pregs[wrbankc].rg = wrrc;
		if (wr3) cpram_in.regmap[wrd].pregs[wrbankd].rg = wrrd;
		/*
		cpram_in = cpram_in | (({RBIT{cmtav}} & cmtap) << {(cmtaa * RBIT),cmtbanka});
		cpram_in = cpram_in | (({RBIT{cmtbv}} & cmtbp) << {(cmtba * RBIT),cmtbankb});
		cpram_in = cpram_in | (({RBIT{cmtcv}} & cmtcp) << {(cmtca * RBIT),cmtbankc});
		cpram_in = cpram_in | (({RBIT{cmtdv}} & cmtdp) << {(cmtda * RBIT),cmtbankd});
		cpram_in = cpram_in | (({RBIT{wr0}} & wrra) << {(wra * RBIT),wrbanka});
		cpram_in = cpram_in | (({RBIT{wr1}} & wrrb) << {(wrb * RBIT),wrbankb});
		cpram_in = cpram_in | (({RBIT{wr2}} & wrrc) << {(wrc * RBIT),wrbankc});
		cpram_in = cpram_in | (({RBIT{wr3}} & wrrd) << {(wrd * RBIT),wrbankd});
		*/
	end
	if (new_chkpt) begin
		cpram_in.avail = avail_i;
		cpram_in.regmap = cpram_outr.regmap;
	end
end

// Add registers to the checkpoint map.
always_comb
begin
	cpram_we = 'd0;
	if (BANKS < 2) begin
		cpram_we = cpram_we | (cmtav << {cmtaa});
		cpram_we = cpram_we | (cmtbv << {cmtba});
		cpram_we = cpram_we | (cmtcv << {cmtca});
		cpram_we = cpram_we | (cmtdv << {cmtda});

		cpram_we = cpram_we | ({wr0} << {wra});
		cpram_we = cpram_we | ({wr1} << {wrb});
		cpram_we = cpram_we | ({wr2} << {wrc});
		cpram_we = cpram_we | ({wr3} << {wrd});
	end
	else begin
		cpram_we = cpram_we | (cmtav << {cmtaa,cmtbanka});
		cpram_we = cpram_we | (cmtbv << {cmtba,cmtbankb});
		cpram_we = cpram_we | (cmtcv << {cmtca,cmtbankc});
		cpram_we = cpram_we | (cmtdv << {cmtda,cmtbankd});

		cpram_we = cpram_we | ({wr0} << {wra,wrbanka});
		cpram_we = cpram_we | ({wr1} << {wrb,wrbankb});
		cpram_we = cpram_we | ({wr2} << {wrc,wrbankc});
		cpram_we = cpram_we | ({wr3} << {wrd,wrbankd});
	end
	if (new_chkpt)
		cpram_we = {WE_WIDTH{1'b1}};
end

// Add registers allocated since the branch miss instruction to the list of
// registers to be freed.
always_comb
begin
	// But not the registers allocated up to the branch miss
	if (restore)
		free_bitlist = cpram_outr.avail;
	else
		free_bitlist = {PREGS{1'b0}};
end

endmodule
