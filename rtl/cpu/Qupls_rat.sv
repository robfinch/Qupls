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
// 46.5k LUTs / 7.1k FFs / 0 BRAMs (256 regs, 8 checkpoints)
// ============================================================================
//
import const_pkg::*;
import QuplsPkg::*;

module Qupls_rat(rst, clk, clk5x, ph4, en, en2, nq, stallq,
	cndx_o, pcndx_o, avail_i, restore, rob,
	stomp, miss_cp, wr0, wr1, wr2, wr3, inc_chkpt, chkpt_inc_amt,
	wra_cp, wrb_cp, wrc_cp, wrd_cp, qbr0, qbr1, qbr2, qbr3,
	rn, rng, rnt, rnv, st_prn,
	prn, rn_cp, rd_cp,
	prv, 
	wrbanka, wrbankb, wrbankc, wrbankd, cmtbanka, cmtbankb, cmtbankc, cmtbankd, rnbank,
	wra, wrra, wrb, wrrb, wrc, wrrc, wrd, wrrd, cmtav, cmtbv, cmtcv, cmtdv,
	cmta_cp, cmtb_cp, cmtc_cp, cmtd_cp,
	cmtaa, cmtba, cmtca, cmtda, cmtap, cmtbp, cmtcp, cmtdp, cmtbr,
	cmtaval, cmtbval, cmtcval, cmtdval,
	restore_list, restored, tags2free, freevals, free_chkpt_i, fchkpt_i, backout, fcu_id);
parameter XWID = 4;
parameter NPORT = 20;
parameter BANKS = 1;
localparam RBIT=$clog2(PREGS);
localparam BBIT=0;//$clog2(BANKS)-1;
input rst;
input clk;
input clk5x;
input [4:0] ph4;
input en;
input en2;
input nq;			// enqueue instruction
input inc_chkpt;
input [2:0] chkpt_inc_amt;
output reg stallq;
input rob_entry_t [ROB_ENTRIES-1:0] rob;
input rob_bitmask_t stomp;
input qbr0;		// enqueue branch, slot 0
input qbr1;
input qbr2;
input qbr3;
output checkpt_ndx_t cndx_o;			// current checkpoint index
output checkpt_ndx_t pcndx_o;			// previous checkpoint index
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
input cpu_types_pkg::aregno_t wra;	// architectural register
input cpu_types_pkg::aregno_t wrb;
input cpu_types_pkg::aregno_t wrc;
input cpu_types_pkg::aregno_t wrd;
input cpu_types_pkg::pregno_t wrra;	// physical register
input cpu_types_pkg::pregno_t wrrb;
input cpu_types_pkg::pregno_t wrrc;
input cpu_types_pkg::pregno_t wrrd;
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
input cpu_types_pkg::aregno_t cmtaa;				// architectural register being committed
input cpu_types_pkg::aregno_t cmtba;
input cpu_types_pkg::aregno_t cmtca;
input cpu_types_pkg::aregno_t cmtda;
input cpu_types_pkg::pregno_t cmtap;				// physical register to commit
input cpu_types_pkg::pregno_t cmtbp;
input cpu_types_pkg::pregno_t cmtcp;
input cpu_types_pkg::pregno_t cmtdp;
input value_t cmtaval;
input value_t cmtbval;
input value_t cmtcval;
input value_t cmtdval;
input cmtbr;								// comitting a branch
input [BBIT:0] rnbank [NPORT-1:0];
input cpu_types_pkg::aregno_t [NPORT-1:0] rn;		// architectural register
input cpu_types_pkg::pregno_t st_prn;
input [2:0] rng [0:NPORT-1];
input [NPORT-1:0] rnt;
input [NPORT-1:0] rnv;
input checkpt_ndx_t [NPORT-1:0] rn_cp;
input checkpt_ndx_t [3:0] rd_cp;
output cpu_types_pkg::pregno_t [NPORT-1:0] prn;	// physical register name
output reg [NPORT-1:0] prv;											// physical register valid
output reg [PREGS-1:0] restore_list;	// bit vector of registers to free on branch miss
output reg restored;
output pregno_t [3:0] tags2free;
output reg [3:0] freevals;
input free_chkpt_i;
input checkpt_ndx_t fchkpt_i;
input backout;
input rob_ndx_t fcu_id;


reg [NCHECK-1:0] avail_chkpts;
reg chkpt_stall;
reg backout_stall;
reg bo_wr;
aregno_t bo_areg;
pregno_t bo_preg;
cpu_types_pkg::pregno_t [NPORT-1:0] next_prn;	// physical register name
cpu_types_pkg::pregno_t [NPORT-1:0] prnd;			// delayed physical register name
reg pwr0,p2wr0;
reg pwr1,p2wr1;
reg pwr2,p2wr2;
reg pwr3,p2wr3;
aregno_t pwra,p2wra;
aregno_t pwrb,p2wrb;
aregno_t pwrc,p2wrc;
aregno_t pwrd,p2wrd;
pregno_t pwrra,p2wrra;
pregno_t pwrrb,p2wrrb;
pregno_t pwrrc,p2wrrc;
pregno_t pwrrd,p2wrrd;
checkpt_ndx_t pwra_cp,p2wra_cp;
checkpt_ndx_t pwrb_cp,p2wrb_cp;
checkpt_ndx_t pwrc_cp,p2wrc_cp;
checkpt_ndx_t pwrd_cp,p2wrd_cp;

integer n,m,n1,n2,n3,n4,n5;
reg cpram_we;
reg cpram_en;
reg cpram_en1;
reg new_chkpt1;
reg new_chkpt2;
localparam RAMWIDTH = AREGS*BANKS*RBIT+PREGS;
checkpoint_t cpram_out;
checkpoint_t cpram_out1;
checkpoint_t cpram_wout;
checkpoint_t cpram_outr;
checkpoint_t cpram_in;

reg cpvram_we;
reg [PREGS-1:0] cpvram_in;
wire [PREGS-1:0] cpvram_out;
wire [PREGS-1:0] cpvram_wout;

reg new_chkpt;							// new_chkpt map for current checkpoint
checkpt_ndx_t cndx, wndx;
wire pe_inc_chkpt;
reg [PREGS-1:0] valid [0:NCHECK-1];

// There are four "extra" bits in the data to make the size work out evenly.
// There is also an extra write bit. These are defaulted to prevent sim issues.

always_comb
	cpram_en = en2|pe_inc_chkpt|cpram_we;
always_ff @(posedge clk)
	cpram_en1 <= cpram_en;

Qupls_checkpointRam 
# (.NRDPORTS(1))
cpram1
(
	.rst(rst),
	.clka(clk),
	.ena(cpram_we),
	.wea(cpram_we),
	.addra(wndx),
	.dina({4'd0,cpram_in}),
	.douta(cpram_wout),
	.clkb(clk),
	.enb(1'b1),
	.addrb(cndx),
	.doutb(cpram_out)
);

reg [8:0] cpv_wr;
checkpt_ndx_t [8:0] cpv_wc;
cpu_types_pkg::pregno_t [8:0] cpv_wa;
cpu_types_pkg::aregno_t [8:0] cpv_awa;
reg [8:0] cpv_i;
wire [NPORT-1:0] cpv_o;

always_comb cpv_wr[0] = cmtav;
always_comb cpv_wr[1] = cmtbv;
always_comb cpv_wr[2] = cmtcv;
always_comb cpv_wr[3] = cmtdv;
always_comb cpv_wr[4] = wr0;
always_comb cpv_wr[5] = wr1;
always_comb cpv_wr[6] = wr2;
always_comb cpv_wr[7] = wr3;
always_comb cpv_wr[8] = bo_wr;
always_comb cpv_wc[0] = cmta_cp;
always_comb cpv_wc[1] = cmtb_cp;
always_comb cpv_wc[2] = cmtc_cp;
always_comb cpv_wc[3] = cmtd_cp;
always_comb cpv_wc[4] = wra_cp;
always_comb cpv_wc[5] = wrb_cp;
always_comb cpv_wc[6] = wrc_cp;
always_comb cpv_wc[7] = wrd_cp;
always_comb cpv_wc[8] = wndx;
always_comb cpv_wa[0] = cmtap;
always_comb cpv_wa[1] = cmtbp;
always_comb cpv_wa[2] = cmtcp;
always_comb cpv_wa[3] = cmtdp;
always_comb cpv_wa[4] = wrra;
always_comb cpv_wa[5] = wrrb;
always_comb cpv_wa[6] = wrrc;
always_comb cpv_wa[7] = wrrd;
always_comb cpv_wa[8] = bo_preg;
always_comb cpv_awa[0] = cmtaa;
always_comb cpv_awa[1] = cmtba;
always_comb cpv_awa[2] = cmtca;
always_comb cpv_awa[3] = cmtda;
always_comb cpv_awa[4] = wra;
always_comb cpv_awa[5] = wrb;
always_comb cpv_awa[6] = wrc;
always_comb cpv_awa[7] = wrd;
always_comb cpv_awa[8] = bo_areg;
// Commit: write VAL for register
// Assign Tgt: write INV for register
always_comb cpv_i[0] = VAL;
always_comb cpv_i[1] = VAL;
always_comb cpv_i[2] = VAL;
always_comb cpv_i[3] = VAL;
always_comb cpv_i[4] = INV;//wra==8'd0;	// Usually works out to INV
always_comb cpv_i[5] = INV;//wrb==8'd0;
always_comb cpv_i[6] = INV;//wrc==8'd0;
always_comb cpv_i[7] = INV;//wrd==8'd0;
always_comb cpv_i[8] = VAL;

/*
Qupls_checkpoint_valid_ram4 #(.NRDPORT(NPORT)) ucpr2
(
	.rst(rst),
	.ph4(ph4),
	.clk5x(clk5x),
	.clka(clk),
	.wen(1'b1),
	.wr(cpv_wr),
	.wc(cpv_wc),
	.wa(cpv_wa),
	.awa(cpv_awa),
	.setall(1'b0),
	.i(cpv_i),
	.clkb(clk),
	.ren(en2),
	.rc(rn_cp),
	.ra(prn),
	.o(cpv_o)
);
*/
always_comb
begin
	if ((cpv_wa[4]==9'd85 && cpv_awa[4]==8'd35) ||
		(cpv_wa[5]==9'd85 && cpv_awa[5]==8'd35) ||
		(cpv_wa[6]==9'd85 && cpv_awa[6]==8'd35) ||
		(cpv_wa[7]==9'd85 && cpv_awa[7]==8'd35)
		)
		$finish;
end

Qupls_checkpoint_valid_ram6 #(.NWRPORTS(8), .NRDPORTS(NPORT)) ucpvram1
(
	.rst(rst),
	.clka(clk),
	.ena(1'b1),
	.wea(cpv_wr),
	.cpa(cpv_wc),
	.prega(cpv_wa),
	.dina(cpv_i),
	.clkb(~clk),
	.enb(1'b1),
	.pregb(prn),
	.cpb(rn_cp),
	.doutb(cpv_o),
	.ncp(new_chkpt),
	.ncp_ra(cndx),
	.ncp_wa(wndx)
);

genvar g;
integer mndx,nn;

wire qbr = qbr0|qbr1|qbr2|qbr3;
// number of outstanding branches
reg [5:0] nob;
wire qbr_ok = nq && qbr && nob < 6'd15;

// Read register names from current checkpoint.
// Bypass new register mappings if reg selected.
generate begin : gRRN
	for (g = 0; g < NPORT-1; g = g + 1) begin
		always_comb
			if (rst)
				next_prn[g] <= 10'd0;
			// If there is a pipeline bubble.
			else begin
				if (rnt[g] & 0) begin
					// Bypass only for previous instruction in same group
					case(rng[g])
					3'd0:	next_prn[g] = 
//														rn[g]==wra && wr0 && rn_cp[g]==wra_cp ? wrra :
													cpram_out.regmap[rn[g]];		// No bypasses needed here
					3'd1: next_prn[g] =
//														rn[g]==wrb && wr1 ? wrrb :	// One previous target
													cpram_out.regmap[rn[g]];
					3'd2: next_prn[g] =
//														rn[g]==wrc && wr2 ? wrrc :
												 	cpram_out.regmap[rn[g]];
					3'd3: next_prn[g] =
//														rn[g]==wrd && wr3 ? wrrd :
												 	cpram_out.regmap[rn[g]];
					default: next_prn[g] = cpram_out.regmap[rn[g]];
					endcase
					/*
						if (prn[g]==10'd0 && rn[g]!=8'd0 && !rnt[g] && rnv[g])
							$finish;
					*/
				end
				else begin
					// Bypass only for previous instruction in same group
					case(rng[g])
					3'd0:	
						begin
							next_prn[g] = 	// Do we need the checkpoint to match?
													(rn[g]==pwrd && pwr3 /*&& rn_cp[g]==pwrd_cp*/) ? pwrrd :
													(rn[g]==pwrc && pwr2 /*&& rn_cp[g]==pwrc_cp*/) ? pwrrc :
													(rn[g]==pwrb && pwr1 /*&& rn_cp[g]==pwrb_cp*/) ? pwrrb :
													(rn[g]==pwra && pwr0 /*&& rn_cp[g]==pwra_cp*/) ? pwrra :
													/*
													rn[g]==p2wrd && p2wr3 && rn_cp[g]==p2wrd_cp ? p2wrrd :
													rn[g]==p2wrc && p2wr2 && rn_cp[g]==p2wrc_cp ? p2wrrc :
													rn[g]==p2wrb && p2wr1 && rn_cp[g]==p2wrb_cp ? p2wrrb :
													rn[g]==p2wra && p2wr0 && rn_cp[g]==p2wra_cp ? p2wrra :
													*/
													cpram_out1.regmap[rn[g]];		// No bypasses needed here
						end
					3'd1: next_prn[g] = 
													(rn[g]==wra && wr0 /*&& rn_cp[g]==wra_cp*/) ? wrra :
													(rn[g]==pwrd && pwr3 /*&& rn_cp[g]==pwrd_cp*/) ? pwrrd :
													(rn[g]==pwrc && pwr2 /*&& rn_cp[g]==pwrc_cp*/) ? pwrrc :
													(rn[g]==pwrb && pwr1 /*&& rn_cp[g]==pwrb_cp*/) ? pwrrb :
													(rn[g]==pwra && pwr0 /*&& rn_cp[g]==pwra_cp*/) ? pwrra :
													/*
													rn[g]==p2wrd && p2wr3 && rn_cp[g]==p2wrd_cp ? p2wrrd :
													rn[g]==p2wrc && p2wr2 && rn_cp[g]==p2wrc_cp ? p2wrrc :
													rn[g]==p2wrb && p2wr1 && rn_cp[g]==p2wrb_cp ? p2wrrb :
													rn[g]==p2wra && p2wr0 && rn_cp[g]==p2wra_cp ? p2wrra :
													*/
													//rn[g]==wra && wr0 ? wrra :	// One previous target
													qbr0 ? cpram_out1.regmap[rn[g]] :
													cpram_out.regmap[rn[g]];
					3'd2: next_prn[g] = 
													(rn[g]==wrb && wr1 /*&& rn_cp[g]==wrb_cp*/) ? wrrb :
													(rn[g]==wra && wr0 /*&& rn_cp[g]==wra_cp*/) ? wrra :
													(rn[g]==pwrd && pwr3 /*&& rn_cp[g]==pwrd_cp*/) ? pwrrd :
													(rn[g]==pwrc && pwr2 /*&& rn_cp[g]==pwrc_cp*/) ? pwrrc :
													(rn[g]==pwrb && pwr1 /*&& rn_cp[g]==pwrb_cp*/) ? pwrrb :
													(rn[g]==pwra && pwr0 /*&& rn_cp[g]==pwra_cp*/) ? pwrra :
													/*
													rn[g]==p2wrd && p2wr3 && rn_cp[g]==p2wrd_cp ? p2wrrd :
													rn[g]==p2wrc && p2wr2 && rn_cp[g]==p2wrc_cp ? p2wrrc :
													rn[g]==p2wrb && p2wr1 && rn_cp[g]==p2wrb_cp ? p2wrrb :
													rn[g]==p2wra && p2wr0 && rn_cp[g]==p2wra_cp ? p2wrra :
													*/
												 	//rn[g]==wrb && wr1 ? wrrb :	// Two previous target
													//rn[g]==wra && wr0 ? wrra :
													qbr0|qbr1 ? cpram_out1.regmap[rn[g]] :
												 	cpram_out.regmap[rn[g]];
					3'd3: next_prn[g] = 
													(rn[g]==wrc && wr2 /*&& rn_cp[g]==wrc_cp*/) ? wrrc :
													(rn[g]==wrb && wr1 /*&& rn_cp[g]==wrb_cp*/) ? wrrb :
													(rn[g]==wra && wr0 /*&& rn_cp[g]==wra_cp*/) ? wrra :
													(rn[g]==pwrd && pwr3 /*&& rn_cp[g]==pwrd_cp*/) ? pwrrd :
													(rn[g]==pwrc && pwr2 /*&& rn_cp[g]==pwrc_cp*/) ? pwrrc :
													(rn[g]==pwrb && pwr1 /*&& rn_cp[g]==pwrb_cp*/) ? pwrrb :
													(rn[g]==pwra && pwr0 /*&& rn_cp[g]==pwra_cp*/) ? pwrra :
													/*
													rn[g]==p2wrd && p2wr3 && rn_cp[g]==p2wrd_cp ? p2wrrd :
													rn[g]==p2wrc && p2wr2 && rn_cp[g]==p2wrc_cp ? p2wrrc :
													rn[g]==p2wrb && p2wr1 && rn_cp[g]==p2wrb_cp ? p2wrrb :
													rn[g]==p2wra && p2wr0 && rn_cp[g]==p2wra_cp ? p2wrra :
													*/
												 	//rn[g]==wrc && wr2 ? wrrc :	// Three previous target
													//rn[g]==wrb && wr1 ? wrrb :
													//rn[g]==wra && wr0 ? wrra :
													qbr0|qbr1|qbr2 ? cpram_out1.regmap[rn[g]] :
												 	cpram_out.regmap[rn[g]];
					default: next_prn[g] = cpram_out.regmap[rn[g]];
					endcase
					/*
						if (prn[g]==10'd0 && rn[g]!=8'd0 && !rnt[g] && rnv[g])
							$finish;
					*/
				end
			end

		always_ff @(posedge clk)
			if (rst)
				prn[g] <= 9'd0;
			// If there is a pipeline bubble.
			else begin
				if (en2) begin
					prn[g] <= next_prn[g];
				end
			end

		always_ff @(posedge clk)
			if (rst)
				prnd[g] <= 9'd0;
			// If there is a pipeline bubble.
			else begin
				prnd[g] <= prn[g];
			end

		// Unless it us a target register, we want the old unbypassed value.
		always_comb//ff @(posedge clk)
			if (rst)
				prv[g] = INV;
			// If there is a pipeline bubble. The instruction will be a NOP. Mark all
			// register ports as valid.
			else begin
				//if (en2) 
				begin			
//					if (!rnv[g])
//						prv[g] = VAL;
//					else
					if (rnt[g] & 0) begin
						// If an incoming target register is being marked invalid and it matches
						// the target register the valid status is begin fetched for, then 
						// return an invalid status. Bypass order is important.
						/*
						if (rn[g]==wrd && wr3)
							prv[g] = INV;//cpv_i[7];
						else if (rn[g]==wrc && wr2)
							prv[g] = INV;
						else if (rn[g]==wrb && wr1)
							prv[g] = INV;
						else if (rn[g]==wra && wr0)
							prv[g] = INV;
						else
						*/
							prv[g] = cpv_o[g];
					end
					else begin
					// Need to bypass if the source register is the same as the previous
					// target register in the same group of instructions.
						
						// If an incoming target register is being marked invalid and it matches
						// the register the valid status is begin fetched for, then 
						// return an invalid status.
						/*
						if (prn[g]==wrrd && wr3 && rn_cp[g]==wrd_cp)
							prv[g] = INV;
						else if (prn[g]==wrrc && wr2 && rn_cp[g]==wrc_cp)
							prv[g] = INV;
						else if (prn[g]==wrrb && wr1 && rn_cp[g]==wrb_cp)
							prv[g] = INV;
						else if (prn[g]==wrra && wr0 && rn_cp[g]==wra_cp)
							prv[g] = INV;
						else
						*/
						case(rng[g])
						// First instruction of group, no bypass needed.
						3'd0:	
						
							if (prn[g]==9'd0 || prn[g]==PREGS-1)
								prv[g] = VAL;
							else if (prn[g]==cmtdp && cmtdv)
								prv[g] = VAL;
							else if (prn[g]==cmtcp && cmtcv)
								prv[g] = VAL;
							else if (prn[g]==cmtbp && cmtbv)
								prv[g] = VAL;
							else if (prn[g]==cmtap && cmtav)
								prv[g] = VAL;
							
							else if (prn[g]==pwrrd && pwr3)
								prv[g] = INV;
							else if (prn[g]==pwrrc && pwr2)
								prv[g] = INV;
							else if (prn[g]==pwrrb && pwr1)
								prv[g] = INV;
							else if (prn[g]==pwrra && pwr0)
								prv[g] = INV;
							
							/*
							else if (prn[g]==p2wrrd && p2wr3 && rn_cp[g]==p2wrd_cp)
								prv[g] = INV;
							else if (prn[g]==p2wrrc && p2wr2 && rn_cp[g]==p2wrc_cp)
								prv[g] = INV;
							else if (prn[g]==p2wrrb && p2wr1 && rn_cp[g]==p2wrb_cp)
								prv[g] = INV;
							else if (prn[g]==p2wrra && p2wr0 && rn_cp[g]==p2wra_cp)
								prv[g] = INV;
							*/
							/*
							else if (prn[g]==cmtdp && cmtdv && rn_cp[g]==cmtd_cp)
								prv[g] = INV;
							else if (prn[g]==cmtcp && cmtcv && rn_cp[g]==cmtc_cp)
								prv[g] = INV;
							else if (prn[g]==cmtbp && cmtbv && rn_cp[g]==cmtb_cp)
								prv[g] = INV;
							else if (prn[g]==cmtap && cmtav && rn_cp[g]==cmta_cp)
								prv[g] = INV;
							*/
							/*
							else if (prn[g]==cpv_wa[7] && cpv_wr[7] && rn_cp[g]==cpv_wc[7])
								prv[g] = INV;
							else if (prn[g]==cpv_wa[6] && cpv_wr[6] && rn_cp[g]==cpv_wc[6])
								prv[g] = INV;
							else if (prn[g]==cpv_wa[5] && cpv_wr[5] && rn_cp[g]==cpv_wc[5])
								prv[g] = INV;
							else if (prn[g]==cpv_wa[4] && cpv_wr[4] && rn_cp[g]==cpv_wc[4])
								prv[g] = INV;
							*/
							/*
							else if (prn[g]==cpv_wa[3] && cpv_wr[3] && rn_cp[g]==cpv_wc[3])
								prv[g] = VAL;
							else if (prn[g]==cpv_wa[2] && cpv_wr[2] && rn_cp[g]==cpv_wc[2])
								prv[g] = VAL;
							else if (prn[g]==cpv_wa[1] && cpv_wr[1] && rn_cp[g]==cpv_wc[1])
								prv[g] = VAL;
							else if (prn[g]==cpv_wa[0] && cpv_wr[0] && rn_cp[g]==cpv_wc[0])
								prv[g] = VAL;
							*/	
							else
														
								prv[g] = cpv_o[g];
						// Second instruction of group, bypass only if first instruction target is same.
						3'd1:
						begin							
							if (prn[g]==9'd0 || prn[g]==PREGS-1)
								prv[g] = VAL;
							else if (prn[g]==wrra && wr0)
								prv[g] = INV;
								
							else if (prn[g]==cmtdp && cmtdv)
								prv[g] = VAL;
							else if (prn[g]==cmtcp && cmtcv)
								prv[g] = VAL;
							else if (prn[g]==cmtbp && cmtbv)
								prv[g] = VAL;
							else if (prn[g]==cmtap && cmtav)
								prv[g] = VAL;

							
							else if (prn[g]==pwrrd && pwr3)
								prv[g] = INV;
							else if (prn[g]==pwrrc && pwr2)
								prv[g] = INV;
							else if (prn[g]==pwrrb && pwr1)
								prv[g] = INV;
							else if (prn[g]==pwrra && pwr0)
								prv[g] = INV;
							
							/*
							else if (prn[g]==p2wrrd && p2wr3 && rn_cp[g]==p2wrd_cp)
								prv[g] = INV;
							else if (prn[g]==p2wrrc && p2wr2 && rn_cp[g]==p2wrc_cp)
								prv[g] = INV;
							else if (prn[g]==p2wrrb && p2wr1 && rn_cp[g]==p2wrb_cp)
								prv[g] = INV;
							else if (prn[g]==p2wrra && p2wr0 && rn_cp[g]==p2wra_cp)
								prv[g] = INV;
							*/	
							/*
							if (prn[g]==prn[3] && rnv[3])
								prv[g] = INV;
							else
							*/
							/*
							else if (prn[g]==cmtdp && cmtdv && rn_cp[g]==cmtd_cp)
								prv[g] = INV;
							else if (prn[g]==cmtcp && cmtcv && rn_cp[g]==cmtc_cp)
								prv[g] = INV;
							else if (prn[g]==cmtbp && cmtbv && rn_cp[g]==cmtb_cp)
								prv[g] = INV;
							else if (prn[g]==cmtap && cmtav && rn_cp[g]==cmta_cp)
								prv[g] = INV;
							*/
							/*
							else if (prn[g]==cpv_wa[7] && cpv_wr[7] && rn_cp[g]==cpv_wc[7])
								prv[g] = INV;
							else if (prn[g]==cpv_wa[6] && cpv_wr[6] && rn_cp[g]==cpv_wc[6])
								prv[g] = INV;
							else if (prn[g]==cpv_wa[5] && cpv_wr[5] && rn_cp[g]==cpv_wc[5])
								prv[g] = INV;
							else if (prn[g]==cpv_wa[4] && cpv_wr[4] && rn_cp[g]==cpv_wc[4])
								prv[g] = INV;
							*/
							/*
							else if (prn[g]==cpv_wa[3] && cpv_wr[3] && rn_cp[g]==cpv_wc[3])
								prv[g] = VAL;
							else if (prn[g]==cpv_wa[2] && cpv_wr[2] && rn_cp[g]==cpv_wc[2])
								prv[g] = VAL;
							else if (prn[g]==cpv_wa[1] && cpv_wr[1] && rn_cp[g]==cpv_wc[1])
								prv[g] = VAL;
							else if (prn[g]==cpv_wa[0] && cpv_wr[0] && rn_cp[g]==cpv_wc[0])
								prv[g] = VAL;
							*/	
							else
							
//								prv[g] = valid[cndx][prn[g]];
								prv[g] = cpv_o[g];
						end
						// Third instruction, check two previous ones.
						3'd2:
						begin
							if (prn[g]==9'd0 || prn[g]==PREGS-1)
								prv[g] = VAL;
							else if (prn[g]==wrrb && wr1)
								prv[g] = INV;
							else if (prn[g]==wrra && wr0)
								prv[g] = INV;
								
							else if (prn[g]==cmtdp && cmtdv)
								prv[g] = VAL;
							else if (prn[g]==cmtcp && cmtcv)
								prv[g] = VAL;
							else if (prn[g]==cmtbp && cmtbv)
								prv[g] = VAL;
							else if (prn[g]==cmtap && cmtav)
								prv[g] = VAL;
							
							else if (prn[g]==pwrrd && pwr3 && rn_cp[g]==pwrd_cp)
								prv[g] = INV;
							else if (prn[g]==pwrrc && pwr2 && rn_cp[g]==pwrc_cp)
								prv[g] = INV;
							else if (prn[g]==pwrrb && pwr1 && rn_cp[g]==pwrb_cp)
								prv[g] = INV;
							else if (prn[g]==pwrra && pwr0 && rn_cp[g]==pwra_cp)
								prv[g] = INV;
							
							/*
							else if (rn[g]==p2wrd && p2wr3 && rn_cp[g]==p2wrd_cp)
								prv[g] = INV;
							else if (rn[g]==p2wrc && p2wr2 && rn_cp[g]==p2wrc_cp)
								prv[g] = INV;
							else if (rn[g]==p2wrb && p2wr1 && rn_cp[g]==p2wrb_cp)
								prv[g] = INV;
							else if (rn[g]==p2wra && p2wr0 && rn_cp[g]==p2wra_cp)
								prv[g] = INV;
							*/
							/*
							if (prn[g]==prn[3] && rnv[3])
								prv[g] = INV;
							else if (prn[g]==prn[7] && rnv[7])
								prv[g] = INV;
							else
							*/
														
							/*
							else if (prn[g]==cpv_wa[7] && cpv_wr[7] && rn_cp[g]==cpv_wc[7])
								prv[g] = INV;
							else if (prn[g]==cpv_wa[6] && cpv_wr[6] && rn_cp[g]==cpv_wc[6])
								prv[g] = INV;
							else if (prn[g]==cpv_wa[5] && cpv_wr[5] && rn_cp[g]==cpv_wc[5])
								prv[g] = INV;
							else if (prn[g]==cpv_wa[4] && cpv_wr[4] && rn_cp[g]==cpv_wc[4])
								prv[g] = INV;
							*/
							/*
							else if (prn[g]==cpv_wa[3] && cpv_wr[3] && rn_cp[g]==cpv_wc[3])
								prv[g] = VAL;
							else if (prn[g]==cpv_wa[2] && cpv_wr[2] && rn_cp[g]==cpv_wc[2])
								prv[g] = VAL;
							else if (prn[g]==cpv_wa[1] && cpv_wr[1] && rn_cp[g]==cpv_wc[1])
								prv[g] = VAL;
							else if (prn[g]==cpv_wa[0] && cpv_wr[0] && rn_cp[g]==cpv_wc[0])
								prv[g] = VAL;
							*/
							else
							
								prv[g] = cpv_o[g];
//								prv[g] = valid[cndx][prn[g]];
						end
					// Fourth instruction, check three previous ones.						
						3'd3:
							begin
							if (prn[g]==9'd0 || prn[g]==PREGS-1)
								prv[g] = VAL;
							else if (prn[g]==wrrc && wr2)
								prv[g] = INV;
							else if (prn[g]==wrrb && wr1)
								prv[g] = INV;
							else if (prn[g]==wrra && wr0)
								prv[g] = INV;
								
							else if (prn[g]==cmtdp && cmtdv)
								prv[g] = VAL;
							else if (prn[g]==cmtcp && cmtcv)
								prv[g] = VAL;
							else if (prn[g]==cmtbp && cmtbv)
								prv[g] = VAL;
							else if (prn[g]==cmtap && cmtav)
								prv[g] = VAL;

							
							else if (prn[g]==pwrrd && pwr3 && rn_cp[g]==pwrd_cp)
								prv[g] = INV;
							else if (prn[g]==pwrrc && pwr2 && rn_cp[g]==pwrc_cp)
								prv[g] = INV;
							else if (prn[g]==pwrrb && pwr1 && rn_cp[g]==pwrb_cp)
								prv[g] = INV;
							else if (prn[g]==pwrra && pwr0 && rn_cp[g]==pwra_cp)
								prv[g] = INV;
							
							/*
							else if (prn[g]==p2wrrd && p2wr3 && rn_cp[g]==p2wrd_cp)
								prv[g] = INV;
							else if (prn[g]==p2wrrc && p2wr2 && rn_cp[g]==p2wrc_cp)
								prv[g] = INV;
							else if (prn[g]==p2wrrb && p2wr1 && rn_cp[g]==p2wrb_cp)
								prv[g] = INV;
							else if (prn[g]==p2wrra && p2wr0 && rn_cp[g]==p2wra_cp)
								prv[g] = INV;
							*/
							/*
							if (prn[g]==prn[3] && rnv[3])
								prv[g] = INV;
							else if (prn[g]==prn[7] && rnv[7])
								prv[g] = INV;
							else if (prn[g]==prn[11] && rnv[11])
								prv[g] = INV;
							else 
							*/
							
							/*
							else if (prn[g]==cpv_wa[7] && cpv_wr[7] && rn_cp[g]==cpv_wc[7])
								prv[g] = INV;
							else if (prn[g]==cpv_wa[6] && cpv_wr[6] && rn_cp[g]==cpv_wc[6])
								prv[g] = INV;
							else if (prn[g]==cpv_wa[5] && cpv_wr[5] && rn_cp[g]==cpv_wc[5])
								prv[g] = INV;
							else if (prn[g]==cpv_wa[4] && cpv_wr[4] && rn_cp[g]==cpv_wc[4])
								prv[g] = INV;
							*/
							/*
							else if (prn[g]==cpv_wa[3] && cpv_wr[3] && rn_cp[g]==cpv_wc[3])
								prv[g] = VAL;
							else if (prn[g]==cpv_wa[2] && cpv_wr[2] && rn_cp[g]==cpv_wc[2])
								prv[g] = VAL;
							else if (prn[g]==cpv_wa[1] && cpv_wr[1] && rn_cp[g]==cpv_wc[1])
								prv[g] = VAL;
							else if (prn[g]==cpv_wa[0] && cpv_wr[0] && rn_cp[g]==cpv_wc[0])
								prv[g] = VAL;
							*/	
							else
							
								prv[g] = cpv_o[g];
//								prv[g] = valid[cndx][next_prn[g]];
							end
						endcase
					end
				end
			end
	end

	always_ff @(posedge clk)
		if (rst)
			prnd[NPORT-1] <= 9'd0;
		// If there is a pipeline bubble.
		else begin
			prnd[NPORT-1] <= prn[NPORT-1];
		end

	always_comb
		prn[NPORT-1] <= st_prn;
	always_ff @(posedge clk)
		if (prn[NPORT-1]==9'd0 || prn[NPORT-1]==PREGS-1)
			prv[NPORT-1] = VAL;
		/*
		else if (prnd[NPORT-1]==wrrc && wr2)
			prv[NPORT-1] = INV;
		else if (prnd[NPORT-1]==wrrb && wr1)
			prv[NPORT-1] = INV;
		else if (prnd[NPORT-1]==wrra && wr0)
			prv[NPORT-1] = INV;
			
		else if (prnd[NPORT-1==cmtdp && cmtdv)
			prv[NPORT-1] = VAL;
		else if (prnd[NPORT-1]==cmtcp && cmtcv)
			prv[NPORT-1] = VAL;
		else if (prnd[NPORT-1]==cmtbp && cmtbv)
			prv[NPORT-1] = VAL;
		else if (prnd[NPORT-1]==cmtap && cmtav)
			prv[NPORT-1] = VAL;

		
		else if (prnd[NPORT-1]==pwrrd && pwr3 && rn_cp[NPORT-1]==pwrd_cp)
			prv[NPORT-1] = INV;
		else if (prnd[NPORT-1]==pwrrc && pwr2 && rn_cp[NPORT-1]==pwrc_cp)
			prv[NPORT-1] = INV;
		else if (prnd[NPORT-1]==pwrrb && pwr1 && rn_cp[NPORT-1]==pwrb_cp)
			prv[NPORT-1] = INV;
		else if (prnd[NPORT-1]==pwrra && pwr0 && rn_cp[NPORT-1]==pwra_cp)
			prv[NPORT-1] = INV;
		else
		*/
		else
			prv[NPORT-1] = cpv_o[NPORT-1];
end
endgenerate


// Adjust the checkpoint index. The index decreases by the number of committed
// branches. The index increases if a branch is queued. Only one branch is
// allowed to queue per cycle.

always_ff @(posedge clk)
if (rst)
	nob <= 'd0;
else
	nob <= nob + qbr_ok - cmtbr;

reg qbr0_ren;
reg qbr1_ren;
reg qbr2_ren;
reg qbr3_ren;
always_ff @(posedge clk)
if (rst)
	qbr0_ren <= 1'b0;
else begin
	if (en2)
		qbr0_ren <= qbr0;
end
always_ff @(posedge clk)
if (rst)
	qbr1_ren <= 1'b0;
else begin
	if (en2)
		qbr1_ren <= qbr1;
end
always_ff @(posedge clk)
if (rst)
	qbr2_ren <= 1'b0;
else begin
	if (en2)
		qbr2_ren <= qbr2;
end
always_ff @(posedge clk)
if (rst)
	qbr3_ren <= 1'b0;
else begin
	if (en2)
		qbr3_ren <= qbr3;
end

wire pe_qbr0;
wire pe_qbr1;
wire pe_qbr2;
wire pe_qbr3;
edge_det uqbr0 (.rst(rst), .clk(clk), .ce(1'b1), .i(qbr0), .pe(pe_qbr0), .ne(), .ee());
edge_det uqbr1 (.rst(rst), .clk(clk), .ce(1'b1), .i(qbr1), .pe(pe_qbr1), .ne(), .ee());
edge_det uqbr2 (.rst(rst), .clk(clk), .ce(1'b1), .i(qbr2), .pe(pe_qbr2), .ne(), .ee());
edge_det uqbr3 (.rst(rst), .clk(clk), .ce(1'b1), .i(qbr3), .pe(pe_qbr3), .ne(), .ee());

assign pe_inc_chkpt = pe_qbr0|pe_qbr1|pe_qbr2|pe_qbr3|
											(qbr0 & qbr0_ren) | (qbr1 & qbr1_ren) |
											(qbr2 & qbr2_ren) | (qbr3 & qbr3_ren)
											;

// Checkpoint allocator / deallocator
// A bitmap is used indicating which checkpoints are available. When a branch
// is detected at decode stage a checkpoint is allocated for it. When the
// branch resolves during execution, the checkpoint is freed. Only on branch
// executes at a time so only a single checkpoint needs to be freed per clock.
// Multiple branches may be decoded in the same instruction group. If so, the
// machine stalls while allocating checkpoints.

wire [4:0] avail_chkpt;
flo24 uffo1 (.i({24'd0,avail_chkpts}), .o(avail_chkpt));

always_ff @(posedge clk)
if (rst)
	avail_chkpts <= {{NCHECK-1{1'b1}},1'b0};
else begin
	if (pe_inc_chkpt)
		avail_chkpts[avail_chkpt] <= 1'b0;
	else if (free_chkpt_i)
		avail_chkpts[fchkpt_i] <= 1'b1;
end

always_comb chkpt_stall = avail_chkpt==5'd31;

// Set checkpoint index
// Backup the checkpoint on a branch miss.
// Increment checkpoint on a branch queue
//edge_det uedichk1 (.rst(rst), .clk(clk), .ce(1'b1), .i(inc_chkpt), .pe(pe_inc_chkpt), .ne(), .ee());

// This is really just a two-bit ring counter.
always_ff @(posedge clk)
if (rst) begin
	new_chkpt <= 1'd0;
	new_chkpt1 <= 1'd0;
	new_chkpt2 <= 1'd0;
end
else begin
	new_chkpt <= 1'd0;
	new_chkpt1 <= 1'b0;
	new_chkpt2 <= 1'd0;
	if (pe_inc_chkpt)
		new_chkpt <= 1'b1;
	if (new_chkpt)
		new_chkpt1 <= 1'b1;
	if (new_chkpt1)
		new_chkpt2 <= 1'b1;
end

// Some diags.
always_ff @(posedge clk)
begin
	if (restore)
		$display("Restoring checkpint %d.", miss_cp);
	if (new_chkpt)
		$display("Setting checkpoint %d.", cndx_o);
end

// Maybe queing up to four branches in a row. There is only one checkpoint
// allowed per instruction group.

reg [4:0] chkpt_rc;
always_ff @(posedge clk)
if (rst)
	chkpt_rc <= 5'd0;
else begin
	if (restore)
		chkpt_rc <= 5'b00000;
	else if (pe_inc_chkpt)
		chkpt_rc <= 5'b00001;
	else if (!chkpt_stall)
		chkpt_rc <= {chkpt_rc[3:0],1'b0};
end

// Checkpoint index. Allocates with a new conditional branch. Future
// instructions will read from the checkpoint files at cndx.
// Checkpoints are allocated in succession to wndx. cndx follows wndx.
// This is the index used to read the checkpoint RAMs.
always_ff @(posedge clk)
if (rst)
	cndx <= 4'd0;
else begin
	if (restore)
		cndx <= miss_cp;
	else if (pe_inc_chkpt)
		cndx <= wndx;
end
always_comb cndx_o = cndx;

always_ff @(posedge clk)
if (rst)
	pcndx_o <= 4'd0;
else begin
	if (restore)
		pcndx_o <= cndx_o;
	else if (pe_inc_chkpt)
		pcndx_o <= cndx_o;
end

// Set checkpoint for each instruction in the group. The machine will stall
// for checkpoint assignments.


// Backout state machine. For backing out RAT changes when a mispredict
// occurs. We go backwards to the mispredicted branch, updating the RAT with
// the old register mappings which are stored in the ROB.
// Note if a branch mispredict occurs and the checkpoint is being restored
// to an earlier one anyway, then this backout is cancelled.

reg [1:0] backout_state;
rob_ndx_t backout_id;

always_ff @(posedge clk)
if (rst)
	backout_id <= {$bits(rob_ndx_t){1'b0}};
else begin
	case(backout_state)
	2'd0:
		if (backout) begin
			if (fcu_id[1:0]!=2'b11) begin
				backout_id <= fcu_id;
				backout_id[1:0] <= 2'b11;
				backout_state <= 2'd1;
			end
		end
	2'd1:
		if (restore)
			backout_state <= 2'd0;
		else if (backout_id != fcu_id)
			backout_id <= backout_id - 2'd1;
		else
			backout_state <= 2'd0;
	default:
		backout_state <= 2'd0;
	endcase
end

always_comb backout_stall = backout || backout_state != 2'd0;

// Checkpoint file write index. Allocates with a new conditional branch.
// The checkpoint file is read from cndx and written to wndx. The read
// data take a cycle to appear, so is timed with wndx.
always_ff @(posedge clk)
if (rst) begin
	wndx <= 4'd0;
end
else begin
	if (restore)
		wndx <= miss_cp;
	else if (pe_inc_chkpt)
		wndx <= avail_chkpt;
	else if (backout_state==2'd1)
		wndx <= rob[backout_id].cndx;
//	else
//		wndx <= cndx;
end

always_ff @(posedge clk)
if (rst) begin
	bo_wr <= FALSE;
	bo_areg <= {$bits(aregno_t){1'b0}};
	bo_preg <= {$bits(pregno_t){1'b0}};
end
else begin
	bo_wr <= FALSE;
	if (!restore && backout_state==2'd1) begin
		bo_wr <= TRUE;
		bo_areg <= rob[backout_id].op.aRt;
		bo_preg <= rob[backout_id].pRt;
	end
end

// Stall the enqueue of instructions if there are too many outstanding branches.
// Also stall for a new checkpoint or a lack of available checkpoints.
// Stall the CPU pipeline for amt+1 cycles to allow checkpoint copying.
always_comb
	stallq = pe_inc_chkpt||new_chkpt||new_chkpt1||chkpt_stall||backout_stall||(qbr && nob==NCHECK-1);


// Committing and queuing target physical register cannot be the same.
// Make use of the fact that other logic consumes lots of time, and implement
// time-multiplexed write ports, multiplexed at five times the CPU clock rate.
// Priorities are resolved by the time-multiplex so, priority logic is not 
// needed.

reg [2:0] wcnt;
always_ff @(posedge clk5x)
if (rst)
	wcnt <= 3'd0;
else begin
	if (ph4[1])
		wcnt <= 3'd0;
	else if (wcnt < 3'd4)
		wcnt <= wcnt + 2'd1;
end

cpu_types_pkg::aregno_t aregno;
cpu_types_pkg::pregno_t pregno;
reg wr;

always_comb
case(wcnt)
3'd0:	wr = wr0;
3'd1:	wr = wr1;
3'd2:	wr = wr2;
3'd3:	wr = wr3;
default:	wr = 1'b0;
endcase
always_comb
case(wcnt)
3'd0:	aregno = wra;
3'd1:	aregno = wrb;
3'd2:	aregno = wrc;
3'd3:	aregno = wrd;
default:	aregno = 8'd0;
endcase
always_comb
case(wcnt)
3'd0:	pregno = wrra;
3'd1:	pregno = wrrb;
3'd2:	pregno = wrrc;
3'd3:	pregno = wrrd;
default:	pregno = 10'd0;
endcase

/*
always_ff @(posedge clk5x)
if (rst) begin
	cpram_in.avail = {{PREGS-1{1'b1}},1'b0};
	cpram_in.regmap = {AREGS*10{1'b0}};
end
else begin
	if (new_chkpt1) begin
		if (wcnt==3'd0) begin
			cpram_in = cpram_out;
			cpram_in.avail = avail_i;
		end
	end
	else begin
		if (wcnt==3'd0)
			cpram_in = cpram_wout;
		if (wr) begin
			cpram_in.regmap[aregno] = pregno;
			$display("Qupls RAT: tgta %d reg %d replaced with %d.", aregno, cpram_out.regmap[aregno], pregno);
		end
	end
	
	if (wr) begin
		if (aregno==8'd41)
			$finish;
		if (pregno==10'd0 && aregno != 8'd0) begin
			$display("Q+ RAT: mapping register to r0");
			$finish;
		end
	end
	if (wr && aregno==8'd0) begin
		$display("RAT: writing zero register.");
		$finish;
	end

end
*/
reg cmtav1;
reg cmtbv1;
reg cmtcv1;
reg cmtdv1;
checkpt_ndx_t cndxa1;
checkpt_ndx_t cndxb1;
checkpt_ndx_t cndxc1;
checkpt_ndx_t cndxd1;
pregno_t cmtap1;
pregno_t cmtbp1;
pregno_t cmtcp1;
pregno_t cmtdp1;
wire cd_cmtav;
wire cd_cmtbv;
wire cd_cmtcv;
wire cd_cmtdv;

// If the same value is going to the same register in two consecutive clock cycles,
// only do one update. Prevents a register from being released for use too soon.
change_det #($bits(aregno_t)+$bits(value_t)+1) ucmta1 (.rst(rst), .clk(clk), .ce(1'b1), .i({cmtav,cmtaa,cmtaval}), .cd(cd_cmtav));
change_det #($bits(aregno_t)+$bits(value_t)+1) ucmtb1 (.rst(rst), .clk(clk), .ce(1'b1), .i({cmtbv,cmtba,cmtbval}), .cd(cd_cmtbv));
change_det #($bits(aregno_t)+$bits(value_t)+1) ucmtc1 (.rst(rst), .clk(clk), .ce(1'b1), .i({cmtcv,cmtca,cmtcval}), .cd(cd_cmtcv));
change_det #($bits(aregno_t)+$bits(value_t)+1) ucmtd1 (.rst(rst), .clk(clk), .ce(1'b1), .i({cmtdv,cmtda,cmtdval}), .cd(cd_cmtdv));

// Make the write inputs sticky until en2 occurs.
reg wr0r;
reg wr1r;
reg wr2r;
reg wr3r;
aregno_t wrar;
aregno_t wrbr;
aregno_t wrcr;
aregno_t wrdr;
pregno_t wrrar;
pregno_t wrrbr;
pregno_t wrrcr;
pregno_t wrrdr;
wire cd_wr0;
wire cd_wr1;
wire cd_wr2;
wire cd_wr3;

// We cannot have the same register tag being assigned to two different
// architectural registers at the same time. The same register cannot be
// assigned two clock cycles in a row. Only map once.
change_det #($bits(aregno_t)+$bits(pregno_t)+1) uwrcda1 (.rst(rst), .clk(clk), .ce(1'b1), .i({wr0,wra,wrra}), .cd(cd_wr0));
change_det #($bits(aregno_t)+$bits(pregno_t)+1) uwrcdb1 (.rst(rst), .clk(clk), .ce(1'b1), .i({wr1,wrb,wrrb}), .cd(cd_wr1));
change_det #($bits(aregno_t)+$bits(pregno_t)+1) uwrcdc1 (.rst(rst), .clk(clk), .ce(1'b1), .i({wr2,wrc,wrrc}), .cd(cd_wr2));
change_det #($bits(aregno_t)+$bits(pregno_t)+1) uwrcdd1 (.rst(rst), .clk(clk), .ce(1'b1), .i({wr3,wrd,wrrd}), .cd(cd_wr3));

always_ff @(posedge clk)
if (rst)
	wr0r <= FALSE;
else begin
	if (wr0)
		wr0r <= TRUE;
	else if (en2)
		wr0r <= FALSE;
end
always_ff @(posedge clk)
if (rst)
	wr1r <= FALSE;
else begin
	if (wr1)
		wr1r <= TRUE;
	else if (en2)
		wr1r <= FALSE;
end
always_ff @(posedge clk)
if (rst)
	wr2r <= FALSE;
else begin
	if (wr2)
		wr2r <= TRUE;
	else if (en2)
		wr2r <= FALSE;
end
always_ff @(posedge clk)
if (rst)
	wr3r <= FALSE;
else begin
	if (wr3)
		wr3r <= TRUE;
	else if (en2)
		wr3r <= FALSE;
end
always_ff @(posedge clk)
if (rst)
	wrar <= 8'd0;
else begin
	if (wr0)
		wrar <= wra;
	else if (en2)
		wrar <= 8'd0;
end
always_ff @(posedge clk)
if (rst)
	wrbr <= 8'd0;
else begin
	if (wr1)
		wrbr <= wrb;
	else if (en2)
		wrbr <= 8'd0;
end
always_ff @(posedge clk)
if (rst)
	wrcr <= 8'd0;
else begin
	if (wr2)
		wrcr <= wrc;
	else if (en2)
		wrcr <= 8'd0;
end
always_ff @(posedge clk)
if (rst)
	wrdr <= 8'd0;
else begin
	if (wr3)
		wrdr <= wrd;
	else if (en2)
		wrdr <= 8'd0;
end
always_ff @(posedge clk)
if (rst)
	wrrar <= 9'd0;
else begin
	if (wr0)
		wrrar <= wrra;
	else if (en2)
		wrrar <= 9'd0;
end
always_ff @(posedge clk)
if (rst)
	wrrbr <= 9'd0;
else begin
	if (wr1)
		wrrbr <= wrrb;
	else if (en2)
		wrrbr <= 9'd0;
end
always_ff @(posedge clk)
if (rst)
	wrrcr <= 9'd0;
else begin
	if (wr2)
		wrrcr <= wrrc;
	else if (en2)
		wrrcr <= 9'd0;
end
always_ff @(posedge clk)
if (rst)
	wrrdr <= 9'd0;
else begin
	if (wr3)
		wrrdr <= wrrd;
	else if (en2)
		wrrdr <= 9'd0;
end

always_ff @(posedge clk)
if (rst) begin
	cmtav1 <= FALSE;
	cmtbv1 <= FALSE;
	cmtcv1 <= FALSE;
	cmtdv1 <= FALSE;
	cndxa1 <= 4'd0;
	cndxb1 <= 4'd0;
	cndxc1 <= 4'd0;
	cndxd1 <= 4'd0;
	cmtap1 <= 9'd0;
	cmtbp1 <= 9'd0;
	cmtcp1 <= 9'd0;
	cmtdp1 <= 9'd0;
end
else begin
	begin
		cmtav1 <= cmtav;
		cmtbv1 <= cmtbv;
		cmtcv1 <= cmtcv;
		cmtdv1 <= cmtdv;
		cndxa1 <= cndx;
		cndxb1 <= cndx;
		cndxc1 <= cndx;
		cndxd1 <= cndx;
		cmtap1 <= cmtap;
		cmtbp1 <= cmtbp;
		cmtcp1 <= cmtcp;
		cmtdp1 <= cmtdp;
	end
end

// Free tags come from the end of a two-entry shift register containing the
// physical register number.

always_ff @(posedge clk)
if (rst) begin
	tags2free[0] <= 9'd0;
	tags2free[1] <= 9'd0;
	tags2free[2] <= 9'd0;
	tags2free[3] <= 9'd0;
end
else begin
	tags2free[0] <= 9'd0;
	tags2free[1] <= 9'd0;
	tags2free[2] <= 9'd0;
	tags2free[3] <= 9'd0;
	if (cd_cmtav & cmtav)
		tags2free[0] <= cpram_out.pregmap[cmtaa];
	if (cd_cmtbv & cmtbv)
		tags2free[1] <= cpram_out.pregmap[cmtba];
	if (cd_cmtcv & cmtcv)
		tags2free[2] <= cpram_out.pregmap[cmtca];
	if (cd_cmtdv & cmtdv)
		tags2free[3] <= cpram_out.pregmap[cmtda];
end

always_ff @(posedge clk)
if (rst)
	freevals <= 4'd0;
else begin
	freevals[0] <= cd_cmtav & cmtav;
	freevals[1] <= cd_cmtbv & cmtbv;
	freevals[2] <= cd_cmtcv & cmtcv;
	freevals[3] <= cd_cmtdv & cmtdv;
end

wire cdwr0 = cd_wr0 & wr0;
wire cdwr1 = cd_wr1 & wr1;
wire cdwr2 = cd_wr2 & wr2;
wire cdwr3 = cd_wr3 & wr3;

// Set the checkpoint RAM input.
// For checkpoint establishment the current read value is desired.
// For normal operation the write output port is used.
checkpoint_t cpram_in1;
checkpt_ndx_t wndx1;
always_ff @(posedge clk)
if (rst) begin
	cpram_in1 = {$bits(checkpoint_t){1'b0}};
	cpram_in.avail = {1'b0,{PREGS-2{1'b1}},1'b0};
	cpram_in.regmap = {AREGS*$bits(pregno_t){1'b0}};
	wndx1 = {$bits(checkpt_ndx_t){1'b0}};
end
else begin
	if (pe_inc_chkpt||new_chkpt) begin
		cpram_in = cpram_out;
		cpram_in.avail = avail_i;
	end
	if (((!(pe_inc_chkpt||new_chkpt)) || backout_state==2'd1))
		cpram_in = wndx==wndx1 ? cpram_in1 : cpram_wout;

	if (!(pe_inc_chkpt||new_chkpt)) begin
		// Backout update.
		if (bo_wr)
			cpram_in.regmap[bo_areg] = bo_preg;

		// The branch instruction itself might need to update the checkpoint info.
		if (cdwr0)
			cpram_in.regmap[wra] = wrra;
		if (cdwr1)
			cpram_in.regmap[wrb] = wrrb;
		if (cdwr2)
			cpram_in.regmap[wrc] = wrrc;
		if (cdwr3)
			cpram_in.regmap[wrd] = wrrd;

		// Shift the physical register into a second spot.
		if (cd_cmtav & cmtav)
			cpram_in.pregmap[cmtaa] = cpram_out.regmap[cmtaa];
		if (cd_cmtbv & cmtbv)
			cpram_in.pregmap[cmtba] = cpram_out.regmap[cmtba];
		if (cd_cmtcv & cmtcv)
			cpram_in.pregmap[cmtca] = cpram_out.regmap[cmtca];
		if (cd_cmtdv & cmtdv)
			cpram_in.pregmap[cmtda] = cpram_out.regmap[cmtda];
			
		cpram_in1 = cpram_in;
		wndx1 = wndx;
	end
end

// Diags.
always_ff @(posedge clk)
if (SIM) begin
	if (TRUE||en2) begin
		if (bo_wr)
			$display("Q+ RAT: backout %d restored to %d", cpram_wout.regmap[bo_areg], bo_preg);

		if (cd_wr0 & wr0) begin
			$display("Q+ RAT: tgta %d reg %d replaced with %d.", wra, cpram_out.regmap[wra], wrra);
		end
		if (cd_wr1 & wr1) begin
			$display("Q+ RAT: tgtb %d reg %d replaced with %d.", wrb, cpram_out.regmap[wrb], wrrb);
		end
		if (cd_wr2 & wr2) begin
			$display("Q+ RAT: tgtc %d reg %d replaced with %d.", wrc, cpram_out.regmap[wrc], wrrc);
		end
		if (cd_wr3 & wr3) begin
			$display("Q+ RAT: tgtd %d reg %d replaced with %d.", wrd, cpram_out.regmap[wrd], wrrd);
		end
	end
	
	if (wr0 && wrra==9'd0) begin
		$display("Q+ RAT: mapping register to zero %d->%d", wra, wrra);
		$finish;
	end
	if (wr1 && wrrb==9'd0) begin
		$display("Q+ RAT: mapping register to zero %d->%d", wrb, wrrb);
		$finish;
	end
	if (wr2 && wrrc==9'd0) begin
		$display("Q+ RAT: mapping register to zero %d->%d", wrc, wrrc);
		$finish;
	end
	if (wr3 && wrrd==9'd0) begin
		$display("Q+ RAT: mapping register to zero %d->%d", wrd, wrrd);
		$finish;
	end

	if (wr0 && wra==8'd0) begin
		$display("Q+ RAT: writing zero register.");
		$finish;
	end
	if (wr1 && wrb==8'd0) begin
		$display("Q+ RAT: writing zero register.");
		$finish;
	end
	if (wr2 && wrc==8'd0) begin
		$display("Q+ RAT: writing zero register.");
		$finish;
	end
	if (wr3 && wrd==8'd0) begin
		$display("Q+ RAT: writing zero register.");
		$finish;
	end
end

always_ff @(posedge clk)
	if (en2) cpram_out1 <= cpram_out;

always_ff @(posedge clk) 
if (rst) begin
	pwr0 <= 1'b0;
end
else begin
	if (en2)
		pwr0 <= wr0;
end
always_ff @(posedge clk) 
if (rst) begin
	pwr1 <= 1'b0;
end
else begin
	if (en2)
		pwr1 <= wr1;
end
always_ff @(posedge clk) 
if (rst) begin
	pwr2 <= 1'b0;
end
else begin
	if (en2)
		pwr2 <= wr2;
end
always_ff @(posedge clk) 
if (rst) begin
	pwr3 <= 1'b0;
end
else begin
	if (en2)
		pwr3 <= wr3;
end

always_ff @(posedge clk) 
if (rst) begin
	pwra <= 8'b0;
end
else begin
	if (en2)
		pwra <= wra;
end
always_ff @(posedge clk) 
if (rst) begin
	pwrb <= 8'b0;
end
else begin
	if (en2)
		pwrb <= wrb;
end
always_ff @(posedge clk) 
if (rst) begin
	pwrc <= 8'b0;
end
else begin
	if (en2)
		pwrc <= wrc;
end
always_ff @(posedge clk) 
if (rst) begin
	pwrd <= 8'b0;
end
else begin
	if (en2)
		pwrd <= wrd;
end

always_ff @(posedge clk) 
if (rst) begin
	pwrra <= 10'b0;
end
else begin
	if (en2)
		pwrra <= wrra;
end
always_ff @(posedge clk) 
if (rst) begin
	pwrrb <= 10'b0;
end
else begin
	if (en2)
		pwrrb <= wrrb;
end
always_ff @(posedge clk) 
if (rst) begin
	pwrrc <= 10'b0;
end
else begin
	if (en2)
		pwrrc <= wrrc;
end
always_ff @(posedge clk) 
if (rst) begin
	pwrrd <= 10'b0;
end
else begin
	if (en2)
		pwrrd <= wrrd;
end

always_ff @(posedge clk) 
if (rst) begin
	pwra_cp <= 4'b0;
end
else begin
	if (en2)
		pwra_cp <= wra_cp;
end
always_ff @(posedge clk) 
if (rst) begin
	pwrb_cp <= 4'b0;
end
else begin
	if (en2)
		pwrb_cp <= wrb_cp;
end
always_ff @(posedge clk) 
if (rst) begin
	pwrc_cp <= 4'b0;
end
else begin
	if (en2)
		pwrc_cp <= wrc_cp;
end
always_ff @(posedge clk) 
if (rst) begin
	pwrd_cp <= 4'b0;
end
else begin
	if (en2)
		pwrd_cp <= wrd_cp;
end

always_ff @(posedge clk) 
if (rst) begin
	p2wr0 <= 1'b0;
end
else begin
	if (en2 && !en)
		p2wr0 <= 1'b0;
	else if (en2)
		p2wr0 <= pwr0;
end
always_ff @(posedge clk) 
if (rst) begin
	p2wr1 <= 1'b0;
end
else begin
	if (en2 && !en)
		p2wr1 <= 1'b0;
	else if (en2)
		p2wr1 <= pwr1;
end
always_ff @(posedge clk) 
if (rst) begin
	p2wr2 <= 1'b0;
end
else begin
	if (en2 && !en)
		p2wr2 <= 1'b0;
	else if (en2)
		p2wr2 <= pwr2;
end
always_ff @(posedge clk) 
if (rst) begin
	p2wr3 <= 1'b0;
end
else begin
	if (en2 && !en)
		p2wr3 <= 1'b0;
	else if (en2)
		p2wr3 <= pwr3;
end

always_ff @(posedge clk) 
if (rst) begin
	p2wra <= 8'b0;
end
else begin
	if (en2 && !en)
		p2wra <= 8'b0;
	else if (en2)
		p2wra <= pwra;
end
always_ff @(posedge clk) 
if (rst) begin
	p2wrb <= 8'b0;
end
else begin
	if (en2 && !en)
		p2wrb <= 8'b0;
	else if (en2)
		p2wrb <= pwrb;
end
always_ff @(posedge clk) 
if (rst) begin
	p2wrc <= 8'b0;
end
else begin
	if (en2 && !en)
		p2wrc <= 8'b0;
	else if (en2)
		p2wrc <= pwrc;
end
always_ff @(posedge clk) 
if (rst) begin
	p2wrd <= 8'b0;
end
else begin
	if (en2 && !en)
		p2wrd <= 8'b0;
	else if (en2)
		p2wrd <= pwrd;
end

always_ff @(posedge clk) 
if (rst) begin
	p2wrra <= 10'b0;
end
else begin
	if (en2 && !en)
		p2wrra <= 10'b0;
	else if (en2)
		p2wrra <= pwrra;
end
always_ff @(posedge clk) 
if (rst) begin
	p2wrrb <= 10'b0;
end
else begin
	if (en2 && !en)
		p2wrrb <= 10'b0;
	else if (en2)
		p2wrrb <= pwrrb;
end
always_ff @(posedge clk) 
if (rst) begin
	p2wrrc <= 10'b0;
end
else begin
	if (en2 && !en)
		p2wrrc <= 10'b0;
	else if (en2)
		p2wrrc <= pwrrc;
end
always_ff @(posedge clk) 
if (rst) begin
	p2wrrd <= 10'b0;
end
else begin
	if (en2 && !en)
		p2wrrd <= 10'b0;
	else if (en2)
		p2wrrd <= pwrrd;
end

always_ff @(posedge clk) 
if (rst) begin
	p2wra_cp <= 4'b0;
end
else begin
	if (en2 && !en)
		p2wra_cp <= 4'b0;
	else if (en2)
		p2wra_cp <= pwra_cp;
end
always_ff @(posedge clk) 
if (rst) begin
	p2wrb_cp <= 4'b0;
end
else begin
	if (en2 && !en)
		p2wrb_cp <= 4'b0;
	else if (en2)
		p2wrb_cp <= pwrb_cp;
end
always_ff @(posedge clk) 
if (rst) begin
	p2wrc_cp <= 4'b0;
end
else begin
	if (en2 && !en)
		p2wrc_cp <= 4'b0;
	else if (en2)
		p2wrc_cp <= pwrc_cp;
end
always_ff @(posedge clk) 
if (rst) begin
	p2wrd_cp <= 4'b0;
end
else begin
	if (en2 && !en)
		p2wrd_cp <= 4'b0;
	else if (en2)
		p2wrd_cp <= pwrd_cp;
end


// RAM gets updated if any port writes, or there is a new checkpoint.
always_ff @(posedge clk)
begin
	cpram_we = 1'b0;
	if (pe_inc_chkpt||new_chkpt||bo_wr)
		cpram_we = 1'b1;
	else //if (en2)
	 	cpram_we =  cdwr0 | cdwr1 | cdwr2 | cdwr3 |
	 							(cd_cmtav & cmtav)|(cd_cmtbv & cmtbv)|(cd_cmtcv & cmtcv)|(cd_cmtdv & cmtdv);
end

// Add registers allocated since the branch miss instruction to the list of
// registers to be freed.
always_ff @(negedge clk)
	cpram_outr <= cpram_out;

always_ff @(posedge clk)
	restored <= restore;

always_comb
begin
	// But not the registers allocated up to the branch miss
	if (restored)
		restore_list = cpram_outr.avail;
	else
		restore_list = {PREGS{1'b0}};
end

endmodule
