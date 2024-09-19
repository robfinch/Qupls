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
// 18500 LUTs / 3900 FFs / 12 BRAM for (128 arch. 384 phys. regs 16 checkpoints)
// 24k LUTs /1.4k FFs / 17 BRAMs (184 a regs 512 phys 8 checkpoints)
// ============================================================================
//
import const_pkg::*;
import QuplsPkg::*;

module Qupls_rat(rst, clk, clk6x, ph4, en, nq, stallq, cndx_o, avail_i, restore, rob,
	stomp, miss_cp, wr0, wr1, wr2, wr3, inc_chkpt,
	wra_cp, wrb_cp, wrc_cp, wrd_cp, qbr0, qbr1, qbr2, qbr3,
	rn, rng, rnt, rnv,
	rrn, rn_cp,
	vn, 
	wrbanka, wrbankb, wrbankc, wrbankd, cmtbanka, cmtbankb, cmtbankc, cmtbankd, rnbank,
	wra, wrra, wrb, wrrb, wrc, wrrc, wrd, wrrd, cmtav, cmtbv, cmtcv, cmtdv,
	cmta_cp, cmtb_cp, cmtc_cp, cmtd_cp,
	cmtaa, cmtba, cmtca, cmtda, cmtap, cmtbp, cmtcp, cmtdp, cmtbr,
	restore_list, restored);
parameter XWID = 4;
parameter NPORT = 20;
parameter BANKS = 1;
localparam RBIT=$clog2(PREGS);
localparam BBIT=0;//$clog2(BANKS)-1;
input rst;
input clk;
input clk6x;
input ph4;
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
input cmtbr;								// comitting a branch
input [BBIT:0] rnbank [NPORT-1:0];
input cpu_types_pkg::aregno_t [NPORT-1:0] rn;		// architectural register
input [2:0] rng [0:NPORT-1];
input [NPORT-1:0] rnt;
input [NPORT-1:0] rnv;
input checkpt_ndx_t [NPORT-1:0] rn_cp;
output cpu_types_pkg::pregno_t [NPORT-1:0] rrn;	// physical register
output reg [NPORT-1:0] vn;			// register valid
output reg [PREGS-1:0] restore_list;	// bit vector of registers to free on branch miss
output reg restored;


integer n,m,n1,n2,n3,n4;
reg cpram_we;
reg cpram_en;
reg cpram_en1;
reg new_chkpt1;
reg new_chkpt2;
reg wr0a,wr1a,wr2a,wr3a;
localparam RAMWIDTH = AREGS*BANKS*RBIT+PREGS;
checkpoint_t cpram_out;
checkpoint_t cpram_wout;
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

always_comb
	cpram_en = en|new_chkpt1|cpram_we;
always_ff @(posedge clk)
	cpram_en1 <= cpram_en;

Qupls_checkpointRam cpram1
(
	.clka(clk),
	.ena(cpram_we),
	.wea(cpram_we),
	.addra(wndx),
	.dina({4'd0,cpram_in}),
	.douta(cpram_wout),
	.clkb(clk),
	.enb(cpram_en),
	.addrb(cndx),
	.doutb(cpram_out)
);

reg [7:0] cpv_wr;
checkpt_ndx_t [7:0] cpv_wc;
cpu_types_pkg::pregno_t [7:0] cpv_wa;
cpu_types_pkg::aregno_t [7:0] cpv_awa;
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
always_comb cpv_wr[4] = wr0;
always_comb cpv_wr[5] = wr1;
always_comb cpv_wr[6] = wr2;
always_comb cpv_wr[7] = wr3;
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
// Commit: write VAL for register
// Assign Tgt: write INV for register
always_comb cpv_i[0] = VAL;
always_comb cpv_i[1] = VAL;
always_comb cpv_i[2] = VAL;
always_comb cpv_i[3] = VAL;
always_comb cpv_i[4] = wra==8'd0;	// Usually works out to INV
always_comb cpv_i[5] = wrb==8'd0;
always_comb cpv_i[6] = wrc==8'd0;
always_comb cpv_i[7] = wrd==8'd0;

// Setup for bypassing
reg [13:0] prev_cpv [0:7];
reg [7:0] prev_cpv_i;
always_ff @(posedge clk)
if (en)
	for (n4 = 0; n4 < 8; n4 = n4 + 1) begin
		prev_cpv[n4] <= {cpv_wa[n4],cpv_wc[n4]};
		prev_cpv_i[n4] <= cpv_i[n4];
	end


Qupls_checkpoint_valid_ram4 #(.NRDPORT(NPORT)) ucpr2
(
	.rst(rst),
	.ph4(ph4),
	.clk6x(clk6x),
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
if (cpv_wr[6] && cpv_wa[6]==9'd263)
	$display("Q+ CPV263=%d, wc[6]=%d, wc[6]=%d", cpv_i, cpv_wc[6], cpv_wc[6]);

cpu_types_pkg::pregno_t prev_rn0;
cpu_types_pkg::pregno_t prev_rn1;
cpu_types_pkg::pregno_t prev_rn2;
cpu_types_pkg::pregno_t prev_rn3;
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
			if (rnt[g]) begin
				/*
				if (rn[g]==8'd0)
					rrn[g] = 10'd0;
				*/
				/* bypass all or none
				else if (rn[g]==wrd && wr3)
					rrn[g] = wrrd;
				*/
				//else
					rrn[g] = cpram_out.regmap[rn[g]];
			end
			else
				rrn[g] = //(rn[g]==8'd0 ? 10'd0 :
							/*
							 wr0 && rn[g]==wra ? wrra :
							 wr1 && rn[g]==wrb ? wrrb :
							 wr2 && rn[g]==wrc ? wrrc :
							 wr3 && rn[g]==wrd ? wrrd :
							 */
							 	cpram_out.regmap[rn[g]];

		// Unless it us a target register, we want the old unbypassed value.
		always_comb
			
			if (rnt[g]) begin
				// If an incoming target register is being marked invalid and it matches
				// the target register the valid status is begin fetched for, then 
				// return an invalid status. Bypass order is important.
				if (rn[g]==wrd && wr3)
					vn[g] = INV;//cpv_i[7];
				else if (rn[g]==wrc && wr2)
					vn[g] = INV;
				else if (rn[g]==wrb && wr1)
					vn[g] = INV;
				else if (rn[g]==wra && wr0)
					vn[g] = INV;
				else
					vn[g] = cpv_o[g];//valid[0][cndx][rrn[g]];//cpram_out.regmap[rn[g]].pregs[0].v;
			end
			else
			// Need to bypass if the source register is the same as the previous
			// target register in the same group of instructions.
			begin
				
				// If an incoming target register is being marked invalid and it matches
				// the register the valid status is begin fetched for, then 
				// return an invalid status.
				if (rn[g]==wrd && wr3)
					vn[g] = INV;//cpv_i[7];
				else if (rn[g]==wrc && wr2)
					vn[g] = INV;
				else if (rn[g]==wrb && wr1)
					vn[g] = INV;
				else if (rn[g]==wra && wr0)
					vn[g] = INV;
				else
				case(rng[g])
				// First instruction of group, no bypass needed.
				3'd0:
					begin
						/*
						if ({rrn[g],rn_cp[g]}==prev_cpv[0])
							vn[g] = prev_cpv_i[0];
						else if ({rrn[g],rn_cp[g]}==prev_cpv[4])
							vn[g] = prev_cpv_i[4];
						else if ({rrn[g],rn_cp[g]}==prev_cpv[1])
							vn[g] = prev_cpv_i[1];
						else if ({rrn[g],rn_cp[g]}==prev_cpv[5])
							vn[g] = prev_cpv_i[5];
						else if ({rrn[g],rn_cp[g]}==prev_cpv[2])
							vn[g] = prev_cpv_i[2];
						else if ({rrn[g],rn_cp[g]}==prev_cpv[6])
							vn[g] = prev_cpv_i[6];
						else if ({rrn[g],rn_cp[g]}==prev_cpv[3])
							vn[g] = prev_cpv_i[3];
						else if ({rrn[g],rn_cp[g]}==prev_cpv[7])
							vn[g] = prev_cpv_i[7];
						else
						*/
							vn[g] = cpv_o[g];
					end
				// Second instruction of group, bypass only if first instruction target is same.
				3'd1:
					if (rn[g]==rn[3] && rnv[3])
						vn[g] = INV;
					/*
					else if ({rrn[g],rn_cp[g]}==prev_cpv[0])
						vn[g] = prev_cpv_i[0];
					else if ({rrn[g],rn_cp[g]}==prev_cpv[4])
						vn[g] = prev_cpv_i[4];
					else if ({rrn[g],rn_cp[g]}==prev_cpv[1])
						vn[g] = prev_cpv_i[1];
					else if ({rrn[g],rn_cp[g]}==prev_cpv[5])
						vn[g] = prev_cpv_i[5];
					else if ({rrn[g],rn_cp[g]}==prev_cpv[2])
						vn[g] = prev_cpv_i[2];
					else if ({rrn[g],rn_cp[g]}==prev_cpv[6])
						vn[g] = prev_cpv_i[6];
					else if ({rrn[g],rn_cp[g]}==prev_cpv[3])
						vn[g] = prev_cpv_i[3];
					else if ({rrn[g],rn_cp[g]}==prev_cpv[7])
						vn[g] = prev_cpv_i[7];
					else if (rrn[g]==cpv_wa[0] && cpv_wr[0] && cpv_wc[0]==rn_cp[g])
						vn[g] = cpv_i[0];
					else if (rrn[g]==cpv_wa[4] && cpv_wr[4] && cpv_wc[4]==rn_cp[g])
						vn[g] = cpv_i[4];
					*/
					else
						vn[g] = cpv_o[g];
				// Third instruction, check two previous ones.
				3'd2:
					if (rn[g]==rn[3] && rnv[3])
						vn[g] = INV;
					else if (rn[g]==rn[7] && rnv[7])
						vn[g] = INV;
					/*
					else if ({rrn[g],rn_cp[g]}==prev_cpv[0])
						vn[g] = prev_cpv_i[0];
					else if ({rrn[g],rn_cp[g]}==prev_cpv[4])
						vn[g] = prev_cpv_i[4];
					else if ({rrn[g],rn_cp[g]}==prev_cpv[1])
						vn[g] = prev_cpv_i[1];
					else if ({rrn[g],rn_cp[g]}==prev_cpv[5])
						vn[g] = prev_cpv_i[5];
					else if ({rrn[g],rn_cp[g]}==prev_cpv[2])
						vn[g] = prev_cpv_i[2];
					else if ({rrn[g],rn_cp[g]}==prev_cpv[6])
						vn[g] = prev_cpv_i[6];
					else if ({rrn[g],rn_cp[g]}==prev_cpv[3])
						vn[g] = prev_cpv_i[3];
					else if ({rrn[g],rn_cp[g]}==prev_cpv[7])
						vn[g] = prev_cpv_i[7];
					else if (rrn[g]==cpv_wa[1] && cpv_wr[1] && cpv_wc[1]==rn_cp[g])
						vn[g] = cpv_i[1];
					else if (rrn[g]==cpv_wa[5] && cpv_wr[5] && cpv_wc[5]==rn_cp[g])
						vn[g] = cpv_i[5];
					else if (rrn[g]==cpv_wa[0] && cpv_wr[0] && cpv_wc[0]==rn_cp[g])
						vn[g] = cpv_i[0];
					else if (rrn[g]==cpv_wa[4] && cpv_wr[4] && cpv_wc[4]==rn_cp[g])
						vn[g] = cpv_i[4];
					*/
					else
						vn[g] = cpv_o[g];
				// Fourth instruction, check three previous ones.						
				3'd3:
					begin
						if (rn[g]==rn[3] && rnv[3])
							vn[g] = INV;
						else if (rn[g]==rn[7] && rnv[7])
							vn[g] = INV;
						else if (rn[g]==rn[11] && rnv[11])
							vn[g] = INV;
						/*
						else if ({rrn[g],rn_cp[g]}==prev_cpv[0])
							vn[g] = prev_cpv_i[0];
						else if ({rrn[g],rn_cp[g]}==prev_cpv[4])
							vn[g] = prev_cpv_i[4];
						else if ({rrn[g],rn_cp[g]}==prev_cpv[1])
							vn[g] = prev_cpv_i[1];
						else if ({rrn[g],rn_cp[g]}==prev_cpv[5])
							vn[g] = prev_cpv_i[5];
						else if ({rrn[g],rn_cp[g]}==prev_cpv[2])
							vn[g] = prev_cpv_i[2];
						else if ({rrn[g],rn_cp[g]}==prev_cpv[6])
							vn[g] = prev_cpv_i[6];
						else if ({rrn[g],rn_cp[g]}==prev_cpv[3])
							vn[g] = prev_cpv_i[3];
						else if ({rrn[g],rn_cp[g]}==prev_cpv[7])
							vn[g] = prev_cpv_i[7];
						else if (rrn[g]==cpv_wa[2] && cpv_wr[2] && cpv_wc[2]==rn_cp[g]) begin
							$display("2matched:%d=%d",rrn[g],cpv_i[2]);
							vn[g] = cpv_i[2];
						end
						else if (rrn[g]==cpv_wa[6] && cpv_wr[6] && cpv_wc[6]==rn_cp[g]) begin
							$display("6matched:%d=%d",rrn[g],cpv_i[6]);
							vn[g] = cpv_i[6];
						end
						else if (rrn[g]==cpv_wa[1] && cpv_wr[1] && cpv_wc[1]==rn_cp[g]) begin
							$display("1matched:%d=%d",rrn[g],cpv_i[1]);
							vn[g] = cpv_i[1];
						end
						else if (rrn[g]==cpv_wa[5] && cpv_wr[5] && cpv_wc[5]==rn_cp[g]) begin
							$display("5matched:%d=%d",rrn[g],cpv_i[5]);
							vn[g] = cpv_i[5];
						end
						else if (rrn[g]==cpv_wa[0] && cpv_wr[0] && cpv_wc[0]==rn_cp[g]) begin
							$display("0matched:%d=%d",rrn[g],cpv_i[0]);
							vn[g] = cpv_i[0];
						end
						else if (rrn[g]==cpv_wa[4] && cpv_wr[4] && cpv_wc[4]==rn_cp[g]) begin
							$display("4matched:%d=%d",rrn[g],cpv_i[4]);
							vn[g] = cpv_i[4];
						end
						*/
						else begin
							vn[g] = cpv_o[g];
						end
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
	if (wrrc==10'd263) begin
		$display("write w263 with %d", INV);
	end
	if (cmtcp==10'd263) begin
		$display("write c263 with %d", VAL);
	end
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

// Adjust the checkpoint index. The index decreases by the number of committed
// branches. The index increases if a branch is queued. Only one branch is
// allowed to queue per cycle.

always_ff @(posedge clk)
if (rst)
	nob <= 'd0;
else
	nob <= nob + qbr_ok - cmtbr;

always_ff @(posedge clk)
	restored <= restore;

// Set checkpoint index
// Backup the checkpoint on a branch miss.
// Increment checkpoint on a branch queue
always_ff @(posedge clk)
if (rst) begin
	cndx <= 4'd0;
	wndx <= 4'd0;
	new_chkpt <= 1'd0;
	new_chkpt1 <= 1'd0;
	new_chkpt2 <= 1'd0;
end
else begin
	new_chkpt2 <= new_chkpt1;
	new_chkpt1 <= 1'd0;
	if (restore) begin
		cndx <= miss_cp;
		$display("Restoring checkpint %d.", miss_cp);
	end
	else if (inc_chkpt) begin
		new_chkpt <= 1'b1;
	end
	if (new_chkpt) begin
		$display("Setting checkpoint %d.", (cndx + 1) % NCHECK);
		new_chkpt <= 1'd0;
		wndx <= (cndx + 1) % NCHECK;
		new_chkpt1 <= new_chkpt;
	end
	if (new_chkpt2)
		cndx <= (cndx + 1) % NCHECK;
end

// Stall the enqueue of instructions if there are too many outstanding branches.
// Also stall for a new checkpoint.
always_comb
if (rst)
	stallq <= 1'd0;
else begin
	for (n3 = 0; n3 < AREGS; n3 = n3 + 1)
		if (/*(rrn[n3]==8'd0 && rn[n3]!=7'd0) || */ qbr && nob==6'd15)
			stallq <= 1'b0;	// ToDo: Fix
	if (inc_chkpt|new_chkpt)
		stallq <= 1'b1;
	if (new_chkpt1)
		stallq <= 1'b0;
end


always_ff @(negedge clk)
	cpram_outr <= cpram_out;
always_ff @(posedge clk)
if (rst)
	cpram_outrp <= {$bits(cpram_out){1'b1}};
else begin
	if (new_chkpt)
		cpram_outrp <= cpram_out;
end

/*
reg [2:0] wcnt;
always_ff @(posedge clk6x)
if (rst)
	wcnt <= 3'd0;
else begin
	if (ph4)
		wcnt <= 3'd0;
	else if (wcnt < 3'd3)
		wcnt <= wcnt + 2'd1;
end
*/

cpu_types_pkg::pregno_t wrra1, pregno0;
cpu_types_pkg::pregno_t wrrb1, pregno1;
cpu_types_pkg::pregno_t wrrc1, pregno2;
cpu_types_pkg::pregno_t wrrd1, pregno3;
cpu_types_pkg::aregno_t wra1, aregno0;
cpu_types_pkg::aregno_t wrb1, aregno1;
cpu_types_pkg::aregno_t wrc1, aregno2;
cpu_types_pkg::aregno_t wrd1, aregno3;
cpu_types_pkg::aregno_t aregno;
cpu_types_pkg::pregno_t pregno;
reg wr;
/*
always_ff @(posedge clk6x)
case(wcnt)
3'd0:	wr <= wr0;
3'd1:	wr <= wr1;
3'd2:	wr <= wr2;
3'd3:	wr <= wr3;
default:	wr <= 1'b0;
endcase
always_ff @(posedge clk6x)
case(wcnt)
3'd0:	aregno <= wra;
3'd1:	aregno <= wrb;
3'd2:	aregno <= wrc;
3'd3:	aregno <= wrd;
default:	aregno <= 8'd0;
endcase
always_ff @(posedge clk6x)
case(wcnt)
3'd0:	pregno <= wrra;
3'd1:	pregno <= wrrb;
3'd2:	pregno <= wrrc;
3'd3:	pregno <= wrrd;
default:	pregno <= 10'd0;
endcase
*/
always_comb pregno0 = wrra;
always_comb pregno1 = wrrb;
always_comb pregno2 = wrrc;
always_comb pregno3 = wrrd;
always_comb aregno0 = wra;
always_comb aregno1 = wrb;
always_comb aregno2 = wrc;
always_comb aregno3 = wrd;

always_ff @(posedge clk) if (wr0a) wr0a <= 1'b0; else if (en) wr0a <= wr0;
always_ff @(posedge clk) if (wr1a) wr1a <= 1'b0; else if (en) wr1a <= wr1;
always_ff @(posedge clk) if (wr2a) wr2a <= 1'b0; else if (en) wr2a <= wr2;
always_ff @(posedge clk) if (wr3a) wr3a <= 1'b0; else if (en) wr3a <= wr3;
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
always_comb
if (rst)
	cpram_in = {$bits(cpram_in){1'b1}};
else begin
	if (new_chkpt1) begin
		cpram_in = cpram_out;
		cpram_in.avail = avail_i;
	end
	else begin
		cpram_in = cpram_wout;
		if (wr0) begin
			cpram_in.regmap[aregno0] = pregno0;
			//cpram_in.val[pregno0] = INV;
			$display("Qupls RAT: tgta %d reg %d replaced with %d.", wra, cpram_out.regmap[aregno0], pregno0);
		end
		if (wr1) begin
			cpram_in.regmap[aregno1] = pregno1;
			//cpram_in.val[pregno1] = INV;
			$display("Qupls RAT: tgta %d reg %d replaced with %d.", wrb, cpram_out.regmap[aregno1], pregno1);
		end
		if (wr2) begin
			cpram_in.regmap[aregno2] = pregno2;
			//cpram_in.val[pregno2] = INV;
			$display("Qupls RAT: tgta %d reg %d replaced with %d.", wrc, cpram_out.regmap[aregno2], pregno2);
		end
		if (wr3) begin
			cpram_in.regmap[aregno3] = pregno3;
			//cpram_in.val[pregno3] = INV;
			$display("Qupls RAT: tgta %d reg %d replaced with %d.", wrd, cpram_out.regmap[aregno3], pregno3);
		end
		/*
		if (cmtav)
			cpram_in.val[cmtap] = VAL;
		if (cmtbv)
			cpram_in.val[cmtbp] = VAL;
		if (cmtcv)
			cpram_in.val[cmtcp] = VAL;
		if (cmtdv)
			cpram_in.val[cmtdp] = VAL;
		*/
	end
	/*
	if (wr) begin
		if (pregno==10'd0 && aregno != 8'd0) begin
			$display("Q+ RAT: mapping register to r0");
			$finish;
		end
	end
	if (wr && pregno==10'd0) begin
		$display("RAT: writing zero register.");
	end
	*/

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
 	cpram_we <= wr0|wr1|wr2|wr3|
 							cmtav|cmtbv|cmtcv|cmtdv|
 							new_chkpt1;
end

// Add registers allocated since the branch miss instruction to the list of
// registers to be freed.
always_comb
begin
	// But not the registers allocated up to the branch miss
	if (restored)
		restore_list = cpram_outr.avail;
	else
		restore_list = {PREGS{1'b0}};
end

endmodule
