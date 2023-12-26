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
// Q+ Register Alias Table
//
// Research shows having 16 checkpoints is almost as good as infinity.
// Registers are marked valid on stomp at a rate of eight per clock cycle.
// There are a max of 32 regs to update (32 entries in ROB). While stomping
// is occurring other updates are not allowed.
//
// 7700 LUTs / 1800 FFs / 1 BRAM	for 1*69/256 (one bank of 69 arch. regs).
// ============================================================================
//
import QuplsPkg::*;

module Qupls_rat(rst, clk, nq, stallq, cndx_o, avail_i, restore, rob,
	stomp, miss_cp, wr0, wr1, wr2, wr3,
	wra_cp, wrb_cp, wrc_cp, wrd_cp, qbr0, qbr1, qbr2, qbr3,
	rn,
	rrn, rn_cp,
	vn, 
	wrbanka, wrbankb, wrbankc, wrbankd, cmtbanka, cmtbankb, cmtbankc, cmtbankd, rnbank,
	wra, wrra, wrb, wrrb, wrc, wrrc, wrd, wrrd, cmtav, cmtbv, cmtcv, cmtdv,
	cmta_cp, cmtb_cp, cmtc_cp, cmtd_cp,
	cmtaa, cmtba, cmtca, cmtda, cmtap, cmtbp, cmtcp, cmtdp, cmtbr,
	freea, freeb, freec, freed, free_bitlist);
parameter XWID = 4;
parameter NPORT = XWID*4;
parameter BANKS = 1;
localparam RBIT=$clog2(PREGS);
localparam BBIT=0;//$clog2(BANKS)-1;
input rst;
input clk;
input nq;			// enqueue instruction
output reg stallq;
input rob_entry_t [ROB_ENTRIES-1:0] rob;
input rob_bitmask_t stomp;
input qbr0;		// enqueue branch, slot 0
input qbr1;
input qbr2;
input qbr3;
output checkpt_ndx_t cndx_o;			// current checkpoint index
input [PREGS-1:0] avail_i;	// list of available registers from renamer
input restore;						// checkpoint restore
input [3:0] miss_cp;			// checkpoint map index of branch miss
input wr0;
input wr1;
input wr2;
input wr3;
input checkpt_ndx_t wra_cp;
input checkpt_ndx_t wrb_cp;
input checkpt_ndx_t wrc_cp;
input checkpt_ndx_t wrd_cp;
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
input checkpt_ndx_t cmta_cp;
input checkpt_ndx_t cmtb_cp;
input checkpt_ndx_t cmtc_cp;
input checkpt_ndx_t cmtd_cp;
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
input checkpt_ndx_t rn_cp [0:NPORT-1];
output pregno_t [NPORT-1:0] rrn;	// physical register
output reg [NPORT-1:0] vn;			// register valid
output pregno_t freea;	// previous register to free
output pregno_t freeb;
output pregno_t freec;
output pregno_t freed;
output reg [PREGS-1:0] free_bitlist;	// bit vector of registers to free on branch miss


integer n,m,n1,n2,n3;
localparam WE_WIDTH = $bits(checkpoint_t)/$bits(pregno_t);
reg [WE_WIDTH-1:0] cpram_we;
localparam RAMWIDTH = AREGS*BANKS*RBIT+PREGS;
checkpoint_t cpram_out;
checkpoint_t cpram_outr;
checkpoint_t cpram_in;
reg new_chkpt;							// new_chkpt map for current checkpoint
checkpt_ndx_t cndx, wndx;
assign cndx_o = cndx;
reg [PREGS-1:0] valid [0:BANKS-1][0:NCHECK-1];
reg [ROB_ENTRIES-1:0] stomp_r;
reg [1:0] stomp_cnt;
reg stomp_act;

Qupls_checkpointRam #(.BANKS(BANKS)) cpram1
(
	.clka(clk),
	.ena(1'b1),
	.wea(cpram_we),
	.addra(wndx),
	.dina(cpram_in),
	.clkb(clk),
	.enb(1'b1),
	.addrb(cndx),
	.doutb(cpram_out)
);

reg [7:0] cpv_wr;
checkpt_ndx_t cpv_wc [0:7];
pregno_t [7:0] cpv_wa;
reg [7:0] cpv_i;
wire [NPORT-1:0] cpv_o;

always_comb cpv_wr[0] = stomp_act ? stomp_r[{stomp_cnt,3'd0}] : cmtav;
always_comb cpv_wr[1] = stomp_act ? stomp_r[{stomp_cnt,3'd1}] : cmtbv;
always_comb cpv_wr[2] = stomp_act ? stomp_r[{stomp_cnt,3'd2}] : cmtcv;
always_comb cpv_wr[3] = stomp_act ? stomp_r[{stomp_cnt,3'd3}] : cmtdv;
always_comb cpv_wr[4] = stomp_act ? stomp_r[{stomp_cnt,3'd4}] : wra != 7'd0 && wr0;
always_comb cpv_wr[5] = stomp_act ? stomp_r[{stomp_cnt,3'd5}] : wrb != 7'd0 && wr1;
always_comb cpv_wr[6] = stomp_act ? stomp_r[{stomp_cnt,3'd6}] : wrc != 7'd0 && wr2;
always_comb cpv_wr[7] = stomp_act ? stomp_r[{stomp_cnt,3'd7}] : wrd != 7'd0 && wr3;
always_comb cpv_wc[0] = stomp_act ? rob[{stomp_cnt,3'd0}].cndx : cmta_cp;
always_comb cpv_wc[1] = stomp_act ? rob[{stomp_cnt,3'd1}].cndx : cmtb_cp;
always_comb cpv_wc[2] = stomp_act ? rob[{stomp_cnt,3'd2}].cndx : cmtc_cp;
always_comb cpv_wc[3] = stomp_act ? rob[{stomp_cnt,3'd3}].cndx : cmtd_cp;
always_comb cpv_wc[4] = stomp_act ? rob[{stomp_cnt,3'd4}].cndx : wra_cp;
always_comb cpv_wc[5] = stomp_act ? rob[{stomp_cnt,3'd5}].cndx : wrb_cp;
always_comb cpv_wc[6] = stomp_act ? rob[{stomp_cnt,3'd6}].cndx : wrc_cp;
always_comb cpv_wc[7] = stomp_act ? rob[{stomp_cnt,3'd7}].cndx : wrd_cp;
always_comb cpv_wa[0] = stomp_act ? rob[{stomp_cnt,3'd0}].nRt : cmtap;
always_comb cpv_wa[1] = stomp_act ? rob[{stomp_cnt,3'd1}].nRt : cmtbp;
always_comb cpv_wa[2] = stomp_act ? rob[{stomp_cnt,3'd2}].nRt : cmtcp;
always_comb cpv_wa[3] = stomp_act ? rob[{stomp_cnt,3'd3}].nRt : cmtdp;
always_comb cpv_wa[4] = stomp_act ? rob[{stomp_cnt,3'd4}].nRt : wrra;
always_comb cpv_wa[5] = stomp_act ? rob[{stomp_cnt,3'd5}].nRt : wrrb;
always_comb cpv_wa[6] = stomp_act ? rob[{stomp_cnt,3'd6}].nRt : wrrc;
always_comb cpv_wa[7] = stomp_act ? rob[{stomp_cnt,3'd7}].nRt : wrrd;
always_comb cpv_i[0] = VAL;
always_comb cpv_i[1] = VAL;
always_comb cpv_i[2] = VAL;
always_comb cpv_i[3] = VAL;
always_comb cpv_i[4] = stomp_act;
always_comb cpv_i[5] = stomp_act;
always_comb cpv_i[6] = stomp_act;
always_comb cpv_i[7] = stomp_act;

Qupls_checkpoint_valid_ram3 ucpr2
(
	.rst(rst),
	.clka(clk),
	.wr(cpv_wr),
	.wc(cpv_wc),
	.wa(cpv_wa),
	.setall(1'b0),
	.i(cpv_i),
	.clkb(~clk),
	.rc(rn_cp),
	.ra(rrn),
	.o(cpv_o)
);

genvar g;
integer mndx,nn;

wire qbr = qbr0|qbr1|qbr2|qbr3;
// number of outstanding branches
reg [5:0] nob;
wire qbr_ok = nq && qbr && nob < 6'd15;

// Read register names from current checkpoint.
// Bypass new register mappings if reg selected.
// ^^^I think bypassing not needed here.^^^
generate begin : gRRN
	for (g = 0; g < NPORT; g = g + 1) begin
		always_comb
			// Bypass target registers only.
			if ((g % 4)==3) begin
				if (rn[g]==7'd0)
					rrn[g] = 8'd0;
				else if (rn[g]==wrd && wr3)
					rrn[g] = wrrd;
				else if (BANKS < 2)
					rrn[g] = cpram_out.regmap[rn[g]].pregs[0];
				else
					rrn[g] = cpram_out.regmap[rn[g]].pregs[rnbank[g]];  
			end
			else
			rrn[g] = rn[g]==7'd0 ? 8'd0 :
							 /*wr0 && rn[g]==wra ? wrra :
							 wr1 && rn[g]==wrb ? wrrb :
							 wr2 && rn[g]==wrc ? wrrc :
							 wr3 && rn[g]==wrd ? wrrd :*/
							 	(BANKS < 2) ? cpram_out.regmap[rn[g]].pregs[0] :
							 								cpram_out.regmap[rn[g]].pregs[rnbank[g]];
//							 	 >> ((BANKS < 2) ? (rn[g] * RBIT) : {(rn[g] * RBIT),rnbank[g]});

		// Unless it us a target register, we want the old unbypassed value.
		always_comb
			
			if ((g % 4)==3) begin
				if (rn[g]==7'd0)
					vn[g] = 1'b1;
				else if (rn[g]==wrd && wr3)
					vn[g] = cpv_i[7];
				else
					vn[g] = cpv_o[g];//valid[0][cndx][rrn[g]];//cpram_out.regmap[rn[g]].pregs[0].v;
			end
			else
			begin
				if (rn[g]==7'd0)
					vn[g] = 1'b1;
				/*
				else if (wr0 && rn[g]==wra)
					vn[g] = cpv_i[4];
				else if (wr1 && rn[g]==wrb)
					vn[g] = cpv_i[5];
				else if (wr2 && rn[g]==wrc)
					vn[g] = cpv_i[6];
				else if (wr3 && rn[g]==wrd)
					vn[g] = cpv_i[7];
				*/
				else if (BANKS < 2)
					vn[g] = cpv_o[g];
				else
					vn[g] = cpv_o[g];
			end
	end
end
endgenerate
always_ff @(posedge clk)
begin
	for (nn = 0; nn < NPORT; nn = nn + 1)
		if (rrn[nn]==8'd74 && rn[nn]==7'd1) begin
			$display("RAT: pr74v=%d.", vn[nn]);
		end
end

/* Debugging.
   The register may be bypassed to a previous target register which is non-zero.
   This test will not detect this.
always_ff @(posedge clk)
begin
	for (nn = 0; nn < NPORT; nn = nn + 1)
		if (rrn[nn]==8'd0 && rn[nn]!=7'd0) begin
			$display("RAT: register mapped to zero.");
			$finish;
		end
end
*/

// If committing register, free previously mapped one, else if discarding the
// register add it to the free list.
/* Dead code
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
*/

// If committing register, free previously mapped one, else if discarding the
// register add it to the free list.
/*
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
*/
// If committing register, free previously mapped one, else if discarding the
// register add it to the free list.
/*
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
*/
// If committing register, free previously mapped one, else if discarding the
// register add it to the free list.
/*
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
*/
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
	if (restore) begin
		cndx <= miss_cp;
		$display("Restoring checkpint %d.", miss_cp);
	end
	else if (qbr_ok) begin
		new_chkpt <= 1'b1;
		$display("Setting checkpoint %d.", cndx + 1);
	end
	if (new_chkpt) begin
		cndx <= cndx + 1;
		if (cndx >= NCHECK-1)
			cndx <= 4'd0;
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
			stallq <= 1'b0;	// ToDo: Fix
end


always_ff @(negedge clk)
	cpram_outr <= cpram_out;

// Committing and queuing target physical register cannot be the same.
// The target register established during queue is marked invalid. It will not
// be valid until a value commits.
always_comb
begin
	cpram_in = cpram_out;
	if (new_chkpt) begin
		cpram_in.avail = avail_i;
	end
	if (BANKS < 2) begin
		
		if (wr0) begin
			cpram_in.regmap[wra].pregs[0] = wrra;
			$display("Qupls RAT: tgt reg %d replaced with %d.", cpram_out.regmap[wra].pregs[0], wrra);
		end
		if (wr1 && XWID > 1) begin
			cpram_in.regmap[wrb].pregs[0] = wrrb;
			$display("Qupls RAT: tgt reg %d replaced with %d.", cpram_out.regmap[wrb].pregs[0], wrrb);
		end
		if (wr2 && XWID > 2) begin
			cpram_in.regmap[wrc].pregs[0] = wrrc;
			$display("Qupls RAT: tgt reg %d replaced with %d.", cpram_out.regmap[wrc].pregs[0], wrrc);
		end
		if (wr3 && XWID > 3) begin
			cpram_in.regmap[wrd].pregs[0] = wrrd;
			$display("Qupls RAT: tgt reg %d replaced with %d.", cpram_out.regmap[wrd].pregs[0], wrrd);
		end
	
		if (wr0 && wrra==8'd0) begin
			$display("RAT: writing zero register.");
		end
		if (wr1 && wrrb==8'd0) begin
			$display("RAT: writing zero register.");
		end
		if (wr2 && wrrc==8'd0) begin
			$display("RAT: writing zero register.");
		end
		if (wr3 && wrrd==8'd0) begin
			$display("RAT: writing zero register.");
		end

	end
	// ToDo: for more than one bank
	else begin
		if (wr0) cpram_in.regmap[wra].pregs[wrbanka] = wrra;
		if (wr1) cpram_in.regmap[wrb].pregs[wrbankb] = wrrb;
		if (wr2) cpram_in.regmap[wrc].pregs[wrbankc] = wrrc;
		if (wr3) cpram_in.regmap[wrd].pregs[wrbankd] = wrrd;
	end

end

// Mark stomped on registers valid.	Thier old value is the true value, 
// pending updates are cancelled. If stomp is active, commmit and update are
// ignored.
// Eight write ports to the valid bits are shared between stomp logic,
// commit logic and update logic.
// Note: setting for r0 to valid is okay because r0 is always valid.

integer j,k;

always_ff @(posedge clk)
if (rst) begin
	for (j = 0; j < BANKS; j = j + 1)
		for (k = 0; k < NCHECK; k = k + 1)
			valid[j][k] <= {256{1'b1}};
	stomp_r <= {ROB_ENTRIES{1'b0}};
	stomp_cnt <= 2'd0;
	stomp_act <= FALSE;
end
else begin
	stomp_cnt <= stomp_cnt + 2'd1;
	stomp_r <= stomp_r | stomp;	
	stomp_act <= |stomp_r | stomp;
	for (j = 0; j < 8; j = j + 1)
		stomp_r[{stomp_cnt,j[2:0]}] <= 1'b0;
end

// Add registers to the checkpoint map.
always_comb
begin
	cpram_we = {WE_WIDTH{1'b1}};
end

always_comb
begin
	if (new_chkpt)
		wndx = cndx + 1;
	else
		wndx = cndx;
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
