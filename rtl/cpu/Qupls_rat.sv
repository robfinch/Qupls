// ============================================================================
//        __
//   \\__/ o\    (C) 2014-2024  Robert Finch, Waterloo
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
import const_pkg::*;
import QuplsPkg::*;

module Qupls_rat(rst, clk, en, nq, stallq, cndx_o, avail_i, restore, rob,
	stomp, miss_cp, wr0, wr1, wr2, wr3, inc_chkpt,
	wra_cp, wrb_cp, wrc_cp, wrd_cp, qbr0, qbr1, qbr2, qbr3,
	rn, rnv,
	rrn, rn_cp,
	vn, 
	wrbanka, wrbankb, wrbankc, wrbankd, cmtbanka, cmtbankb, cmtbankc, cmtbankd, rnbank,
	wra, wrra, wrb, wrrb, wrc, wrrc, wrd, wrrd, cmtav, cmtbv, cmtcv, cmtdv,
	cmta_cp, cmtb_cp, cmtc_cp, cmtd_cp,
	cmtaa, cmtba, cmtca, cmtda, cmtap, cmtbp, cmtcp, cmtdp, cmtbr,
	freea, freeb, freec, freed, free_bitlist);
parameter XWID = 4;
parameter NPORT = 17;
parameter BANKS = 1;
localparam RBIT=$clog2(PREGS);
localparam BBIT=0;//$clog2(BANKS)-1;
input rst;
input clk;
input en;
input nq;			// enqueue instruction
input inc_chkpt;
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
input [NPORT-1:0] rnv;
input checkpt_ndx_t rn_cp [0:NPORT-1];
output pregno_t [NPORT-1:0] rrn;	// physical register
output reg [NPORT-1:0] vn;			// register valid
output pregno_t freea;	// previous register to free
output pregno_t freeb;
output pregno_t freec;
output pregno_t freed;
output reg [PREGS-1:0] free_bitlist;	// bit vector of registers to free on branch miss


integer n,m,n1,n2,n3;
reg cpram_we;
localparam RAMWIDTH = AREGS*BANKS*RBIT+PREGS;
checkpoint_t cpram_out;
checkpoint_t cpram_outr;
checkpoint_t cpram_outrp;
checkpoint_t cpram_in;
reg new_chkpt;							// new_chkpt map for current checkpoint
checkpt_ndx_t cndx, wndx;
assign cndx_o = cndx;
reg [PREGS-1:0] valid [0:BANKS-1][0:NCHECK-1];
reg [ROB_ENTRIES-1:0] stomp_r;
reg [1:0] stomp_cnt;
reg stomp_act;

// There are four "extra" bits in the data to make the size work out evenly.
// There is also an extra write bit. These are defaulted to prevent sim issues.

Qupls_checkpointRam #(.BANKS(BANKS)) cpram1
(
	.clka(clk),
	.ena(en),
	.wea({1'b1,cpram_we}),
	.addra(wndx),
	.dina({4'd0,cpram_in}),
	.clkb(clk),
	.enb(en),
	.addrb(cndx),
	.doutb(cpram_out)
);

reg [7:0] cpv_wr;
checkpt_ndx_t [7:0] cpv_wc;
pregno_t [7:0] cpv_wa;
aregno_t [7:0] cpv_awa;
reg [7:0] cpv_i;
wire [NPORT-1:0] cpv_o;
/*
always_comb cpv_wr[0] = stomp_act ? stomp_r[{stomp_cnt,3'd0}] : cmtav;
always_comb cpv_wr[1] = stomp_act ? stomp_r[{stomp_cnt,3'd1}] : cmtbv;
always_comb cpv_wr[2] = stomp_act ? stomp_r[{stomp_cnt,3'd2}] : cmtcv;
always_comb cpv_wr[3] = stomp_act ? stomp_r[{stomp_cnt,3'd3}] : cmtdv;
always_comb cpv_wr[4] = stomp_act ? stomp_r[{stomp_cnt,3'd4}] : wra != 9'd0 && wr0;
always_comb cpv_wr[5] = stomp_act ? stomp_r[{stomp_cnt,3'd5}] : wrb != 9'd0 && wr1;
always_comb cpv_wr[6] = stomp_act ? stomp_r[{stomp_cnt,3'd6}] : wrc != 9'd0 && wr2;
always_comb cpv_wr[7] = stomp_act ? stomp_r[{stomp_cnt,3'd7}] : wrd != 9'd0 && wr3;
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
*/
always_comb cpv_wr[0] = cmtav;
always_comb cpv_wr[1] = cmtbv;
always_comb cpv_wr[2] = cmtcv;
always_comb cpv_wr[3] = cmtdv;
always_comb cpv_wr[4] = wra != 9'd0 && wr0;
always_comb cpv_wr[5] = wrb != 9'd0 && wr1;
always_comb cpv_wr[6] = wrc != 9'd0 && wr2;
always_comb cpv_wr[7] = wrd != 9'd0 && wr3;
always_comb cpv_wc[0] = cmta_cp;
always_comb cpv_wc[1] = cmtb_cp;
always_comb cpv_wc[2] = cmtc_cp;
always_comb cpv_wc[3] = cmtd_cp;
always_comb cpv_wc[4] = wra_cp;
always_comb cpv_wc[5] = wrb_cp;
always_comb cpv_wc[6] = wrc_cp;
always_comb cpv_wc[7] = wrd_cp;
always_comb cpv_wa[0] = cmtap;
always_comb cpv_wa[1] = cmtbp;
always_comb cpv_wa[2] = cmtcp;
always_comb cpv_wa[3] = cmtdp;
always_comb cpv_wa[4] = wrra;
always_comb cpv_wa[5] = wrrb;
always_comb cpv_wa[6] = wrrc;
always_comb cpv_wa[7] = wrrd;
always_comb cpv_awa[0] = cmtaa;
always_comb cpv_awa[1] = cmtba;
always_comb cpv_awa[2] = cmtca;
always_comb cpv_awa[3] = cmtda;
always_comb cpv_awa[4] = wra;
always_comb cpv_awa[5] = wrb;
always_comb cpv_awa[6] = wrc;
always_comb cpv_awa[7] = wrd;
always_comb cpv_i[0] = VAL;
always_comb cpv_i[1] = VAL;
always_comb cpv_i[2] = VAL;
always_comb cpv_i[3] = VAL;
always_comb cpv_i[4] = INV;
always_comb cpv_i[5] = INV;
always_comb cpv_i[6] = INV;
always_comb cpv_i[7] = INV;

Qupls_checkpoint_valid_ram3 #(.NRDPORT(NPORT)) ucpr2
(
	.rst(rst),
	.clka(clk),
	.en(en),
	.wr(cpv_wr),
	.wc(cpv_wc),
	.wa(cpv_wa),
	.awa(cpv_awa),
	.setall(1'b0),
	.i(cpv_i),
	.clkb(~clk),
	.rc(rn_cp),
	.ra(rrn),
	.o(cpv_o)
);

always_ff @(posedge clk)
if (cpv_wr && cpv_wa==9'd65)
	$display("Q+ CPV65=%d, wc[3]=%d, wc[7]=%d", cpv_i, cpv_wc[3], cpv_wc[7]);

pregno_t prev_rn0;
pregno_t prev_rn1;
pregno_t prev_rn2;
pregno_t prev_rn3;
reg prev_vn0;
reg prev_vn1;
reg prev_vn2;
reg prev_vn3;

always_ff @(posedge clk)
if (rst) begin
	prev_rn0 <= 11'd0;
	prev_rn1 <= 11'd0;
	prev_rn2 <= 11'd0;
	prev_rn3 <= 11'd0;
	prev_vn0 <= 1'b0;
	prev_vn1 <= 1'b0;
	prev_vn2 <= 1'b0;
	prev_vn3 <= 1'b0;
end
else if (en) begin
	prev_rn0 <= rrn[3];
	prev_rn1 <= rrn[7];
	prev_rn2 <= rrn[11];
	prev_rn3 <= rrn[15];
	prev_vn0 <= rnv[3];
	prev_vn1 <= rnv[7];
	prev_vn2 <= rnv[11];
	prev_vn3 <= rnv[15];
end

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
				if (rn[g]==9'd0)
					rrn[g] = 11'd0;
				/* bypass all or none
				else if (rn[g]==wrd && wr3)
					rrn[g] = wrrd;
				*/
				else
					rrn[g] = cpram_out.regmap[rn[g]];
			end
			else
				rrn[g] = (rn[g]==9'd0 ? 11'd0 :
							/*
							 wr0 && rn[g]==wra ? wrra :
							 wr1 && rn[g]==wrb ? wrrb :
							 wr2 && rn[g]==wrc ? wrrc :
							 wr3 && rn[g]==wrd ? wrrd :
							 */
							 	cpram_out.regmap[rn[g]]);

		// Unless it us a target register, we want the old unbypassed value.
		always_comb
			
			if ((g % 4)==3) begin
				if (rn[g]==9'd0)
					vn[g] = 1'b1;
				/*
				else if (rn[g]==wrd && wr3)
					vn[g] = cpv_i[7];
				*/
				else
					vn[g] = cpv_o[g];//valid[0][cndx][rrn[g]];//cpram_out.regmap[rn[g]].pregs[0].v;
			end
			else
			// Need to bypass if the source register is the same as the previous
			// target register in the same group of instructions.
			begin
				
				case(g)
				// First instruction of group, no bypass needed.
				4'd0,4'd1,4'd2,5'd16:
					begin
						if (rn[g]==9'd0)
							vn[g] = 1'b1;
						else if (rrn[g]==10'd1023)
							vn[g] = 1'b1;
						else
							vn[g] = cpv_o[g];
					end
				// Second instruction of group, bypass only if first instruction target is same.
				4'd4,4'd5,4'd6:
					if (rn[g]==9'd0)
						vn[g] = 1'b1;
					else if (rrn[g]==10'd1023)
						vn[g] = 1'b1;
					else if (rrn[g]==cpv_wa[0] && cpv_wr[0] && cpv_wc[0]==rn_cp[g])
						vn[g] = cpv_i[0];
					else if (rrn[g]==cpv_wa[4] && cpv_wr[4] && cpv_wc[4]==rn_cp[g])
						vn[g] = cpv_i[4];
					else
						vn[g] = cpv_o[g];
				// Third instruction, check two previous ones.
				4'd8,4'd9,4'd10:
					if (rn[g]==9'd0)
						vn[g] = 1'b1;
					else if (rrn[g]==10'd1023)
						vn[g] = 1'b1;
					else if (rrn[g]==cpv_wa[1] && cpv_wr[1] && cpv_wc[1]==rn_cp[g])
						vn[g] = cpv_i[1];
					else if (rrn[g]==cpv_wa[5] && cpv_wr[5] && cpv_wc[5]==rn_cp[g])
						vn[g] = cpv_i[5];
					else if (rrn[g]==cpv_wa[0] && cpv_wr[0] && cpv_wc[0]==rn_cp[g])
						vn[g] = cpv_i[0];
					else if (rrn[g]==cpv_wa[4] && cpv_wr[4] && cpv_wc[4]==rn_cp[g])
						vn[g] = cpv_i[4];
					else
						vn[g] = cpv_o[g];
				// Fourth instruction, check three previous ones.						
				4'd12,4'd13,4'd14:
					begin
						if (rn[g]==9'd0)
							vn[g] = 1'b1;
						else if (rrn[g]==10'd1023)
							vn[g] = 1'b1;
						else if (rrn[g]==cpv_wa[2] && cpv_wr[2] && cpv_wc[2]==rn_cp[g])
							vn[g] = cpv_i[2];
						else if (rrn[g]==cpv_wa[6] && cpv_wr[6] && cpv_wc[6]==rn_cp[g])
							vn[g] = cpv_i[6];
						else if (rrn[g]==cpv_wa[1] && cpv_wr[1] && cpv_wc[1]==rn_cp[g])
							vn[g] = cpv_i[1];
						else if (rrn[g]==cpv_wa[5] && cpv_wr[5] && cpv_wc[5]==rn_cp[g])
							vn[g] = cpv_i[5];
						else if (rrn[g]==cpv_wa[0] && cpv_wr[0] && cpv_wc[0]==rn_cp[g])
							vn[g] = cpv_i[0];
						else if (rrn[g]==cpv_wa[4] && cpv_wr[4] && cpv_wc[4]==rn_cp[g])
							vn[g] = cpv_i[4];
						else
							vn[g] = cpv_o[g];
					end
				endcase
				/*
				if (rrn[g]==prev_rn0 && prev_vn0)
					vn[g] <= 1'b0;
				if (rrn[g]==prev_rn1 && prev_vn1)
					vn[g] <= 1'b0;
				if (rrn[g]==prev_rn2 && prev_vn2)
					vn[g] <= 1'b0;
				if (rrn[g]==prev_rn3 && prev_vn3)
					vn[g] <= 1'b0;
				*/
			end
	end
end
endgenerate

always_ff @(posedge clk)
begin
	if (rn[0]==rn[2] && rn[0]==9'd68) begin
		$display("Q+ RAT: r68/%d %d vn= %d %d", rrn[0], rrn[2], vn[0], vn[2]);
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
reg new_chkpt1;
always_ff @(posedge clk)
if (rst) begin
	cndx <= 4'd0;
	new_chkpt <= 1'd0;
	new_chkpt1 <= 1'd0;
end
else begin
	if (en)
		new_chkpt <= 'd0;
	if (restore) begin
		cndx <= miss_cp;
		$display("Restoring checkpint %d.", miss_cp);
	end
	else if (inc_chkpt) begin
		new_chkpt <= 1'b1;
		$display("Setting checkpoint %d.", (cndx + 1) % NCHECK);
	end
	if (en & new_chkpt) begin
		cndx <= (cndx + 1) % NCHECK;
	end
	if (en)
		new_chkpt1 <= new_chkpt;
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
always_ff @(posedge clk)
if (rst)
	cpram_outrp <= {$bits(cpram_out){1'b1}};
else begin
	if (en)
		if (new_chkpt)
			cpram_outrp <= cpram_out;
end

reg wr0a,wr1a,wr2a,wr3a;
pregno_t wrra1;
pregno_t wrrb1;
pregno_t wrrc1;
pregno_t wrrd1;
aregno_t wra1;
aregno_t wrb1;
aregno_t wrc1;
aregno_t wrd1;
always_ff @(posedge clk) if (en) wr0a <= wr0;
always_ff @(posedge clk) if (en) wr1a <= wr1;
always_ff @(posedge clk) if (en) wr2a <= wr2;
always_ff @(posedge clk) if (en) wr3a <= wr3;
always_ff @(posedge clk) if (en) wrra1 <= wrra;
always_ff @(posedge clk) if (en) wrrb1 <= wrrb;
always_ff @(posedge clk) if (en) wrrc1 <= wrrc;
always_ff @(posedge clk) if (en) wrrd1 <= wrrd;
always_ff @(posedge clk) if (en) wra1 <= wra;
always_ff @(posedge clk) if (en) wrb1 <= wrb;
always_ff @(posedge clk) if (en) wrc1 <= wrc;
always_ff @(posedge clk) if (en) wrd1 <= wrd;

// Committing and queuing target physical register cannot be the same.
// The target register established during queue is marked invalid. It will not
// be valid until a value commits.
always_ff @(posedge clk)
if (rst)
	cpram_in <= {$bits(cpram_in){1'b1}};
else if (en) begin
	cpram_in <= (new_chkpt|new_chkpt1) ? cpram_outrp : cpram_out;
	if (new_chkpt|new_chkpt1) begin
		cpram_in.avail <= avail_i;
	end
		
	if (wr0) begin
		cpram_in.regmap[wra] <= wrra;
		$display("Qupls RAT: tgt reg %d replaced with %d.", cpram_out.regmap[wra], wrra);
	end
	if (wr1 && XWID > 1) begin
		cpram_in.regmap[wrb] <= wrrb;
		$display("Qupls RAT: tgt reg %d replaced with %d.", cpram_out.regmap[wrb], wrrb);
	end
	if (wr2 && XWID > 2) begin
		cpram_in.regmap[wrc] <= wrrc;
		$display("Qupls RAT: tgt reg %d replaced with %d.", cpram_out.regmap[wrc], wrrc);
	end
	if (wr3 && XWID > 3) begin
		cpram_in.regmap[wrd] <= wrrd;
		$display("Qupls RAT: tgt reg %d replaced with %d.", cpram_out.regmap[wrd], wrrd);
	end
	if (wr0a) begin
		cpram_in.regmap[wra1] <= wrra1;
		$display("Qupls RAT: tgt reg %d replaced with %d.", cpram_out.regmap[wra], wrra);
	end
	if (wr1a && XWID > 1) begin
		cpram_in.regmap[wrb1] <= wrrb1;
		$display("Qupls RAT: tgt reg %d replaced with %d.", cpram_out.regmap[wrb], wrrb);
	end
	if (wr2a && XWID > 2) begin
		cpram_in.regmap[wrc1] <= wrrc1;
		$display("Qupls RAT: tgt reg %d replaced with %d.", cpram_out.regmap[wrc], wrrc);
	end
	if (wr3a && XWID > 3) begin
		cpram_in.regmap[wrd1] <= wrrd1;
		$display("Qupls RAT: tgt reg %d replaced with %d.", cpram_out.regmap[wrd], wrrd);
	end

	if (wr0 && wrra==11'd0) begin
		$display("RAT: writing zero register.");
	end
	if (wr1 && wrrb==11'd0) begin
		$display("RAT: writing zero register.");
	end
	if (wr2 && wrrc==11'd0) begin
		$display("RAT: writing zero register.");
	end
	if (wr3 && wrrd==11'd0) begin
		$display("RAT: writing zero register.");
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
always_ff @(posedge clk)
if (en) begin
 	cpram_we <= wr0|wr1|wr2|wr3|new_chkpt;
end

always_ff @(posedge clk)
if (rst)
	wndx <= 6'd0;
else begin
	if (en) begin
		if (new_chkpt)
			wndx = (cndx + 1) % NCHECK;
		else
			wndx = cndx;
	end
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
