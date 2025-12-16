// ============================================================================
//        __
//   \\__/ o\    (C) 2024-2025  Robert Finch, Waterloo
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
// Qupls4 Register Alias Table
//
// Research shows having 16 checkpoints is almost as good as infinity.
//
// 17350 LUTs / 2250 FFs / 00 BRAMs (512p regs, 16 checkpoints)
// 48800 LUTs / 5710 FFs / 0 BRAMS (512p regs, 16 checkpoints)
// ============================================================================
//
import const_pkg::*;
import Qupls4_pkg::*;

module Qupls4_rat(rst, clk,
	// Pipeline control
	en, en2, stall,

	alloc_chkpt,	// allocate a new checkpoint - flow control encountered
	cndx,					// current checkpoint index
	miss_cp,			// checkpoint of miss location - to be restored
	avail_i,			// list of available registers from renamer
	tail, rob,

	// Which instructions being queued are branches
	nq, 
	qbr0, qbr1, qbr2, qbr3,
	
	// From reservation read requests: 
	rn,				// architectural register number
	rnv,			// reg number request valid
	rng,			// instruction number within group
	rn_cp, 		// checkpoint of requester
	st_prn,
	rd_cp,
	prn, 			// the mapped physical register number
	prv, 			// map valid indicator

	// From decode: destination register writes, one per instruction, four instructions.
	wr0, wr1, wr2, wr3, 								// which port is aactive 
	wra, wrb, wrc, wrd,							// architectural register number
	wrra, wrrb, wrrc, wrrd,					// physical register number
	wra_cp, wrb_cp, wrc_cp, wrd_cp,			// checkpoint in use

	// Register file write signals.
	wrport0_v, wrport1_v, wrport2_v, wrport3_v,		// which port is being written
	wrport0_aRt, wrport1_aRt, wrport2_aRt, wrport3_aRt,	// the architectural register used
	wrport0_Rt, wrport1_Rt, wrport2_Rt, wrport3_Rt,	// The physical register used
	wrport0_cp, wrport1_cp, wrport2_cp, wrport3_cp,	// The checkpoint
	wrport0_res, wrport1_res, wrport2_res, wrport3_res,	// and the value written
	
	// Commit stage signals
	cmtav, cmtbv, cmtcv, cmtdv,					// which commits are valid
	cmtaiv, cmtbiv, cmtciv, cmtdiv,			// committing invalid instruction
	cmta_cp, cmtb_cp, cmtc_cp, cmtd_cp,	// commit checkpoint
	cmtaa, cmtba, cmtca, cmtda,					// architectural register committed
	cmtap, cmtbp, cmtcp, cmtdp, 				// physical register committed.
	cmtaval, cmtbval, cmtcval, cmtdval,	// value committed
	cmtbr,															// committing a branch

	restore,			// signal to restore a checkpoint
	restore_list, restored, tags2free, freevals, backout,
	fcu_id,		// the ROB index of the instruction causing backout
	bo_wr, bo_areg, bo_preg, bo_nreg);
parameter MWIDTH = 4;
parameter NPORT = 12;
localparam RBIT=$clog2(Qupls4_pkg::PREGS);
input rst;
input clk;
//input clk5x;
//input [4:0] ph4;
input en;
input en2;
input nq;			// enqueue instruction
input alloc_chkpt;
input checkpt_ndx_t cndx;
input checkpt_ndx_t miss_cp;
output reg stall;
input rob_ndx_t tail;
input Qupls4_pkg::rob_entry_t [Qupls4_pkg::ROB_ENTRIES-1:0] rob;
input qbr0;		// enqueue branch, slot 0
input qbr1;
input qbr2;
input qbr3;
input [Qupls4_pkg::PREGS-1:0] avail_i;				// list of available registers from renamer
input restore;										// checkpoint restore

input wr0;
input wr1;
input wr2;
input wr3;
/*
input wr01;
input wr11;
input wr21;
input wr31;
*/
input checkpt_ndx_t wra_cp;
input checkpt_ndx_t wrb_cp;
input checkpt_ndx_t wrc_cp;
input checkpt_ndx_t wrd_cp;
input cpu_types_pkg::aregno_t wra;	// architectural register
input cpu_types_pkg::aregno_t wrb;
input cpu_types_pkg::aregno_t wrc;
input cpu_types_pkg::aregno_t wrd;
input cpu_types_pkg::pregno_t wrra;	// physical register
input cpu_types_pkg::pregno_t wrrb;
input cpu_types_pkg::pregno_t wrrc;
input cpu_types_pkg::pregno_t wrrd;
/*
input cpu_types_pkg::aregno_t wra1;	// architectural register
input cpu_types_pkg::aregno_t wrb1;
input cpu_types_pkg::aregno_t wrc1;
input cpu_types_pkg::aregno_t wrd1;
input cpu_types_pkg::pregno_t wrra1;	// physical register
input cpu_types_pkg::pregno_t wrrb1;
input cpu_types_pkg::pregno_t wrrc1;
input cpu_types_pkg::pregno_t wrrd1;
*/
input wrport0_v;
input wrport1_v;
input wrport2_v;
input wrport3_v;
input aregno_t wrport0_aRt;
input aregno_t wrport1_aRt;
input aregno_t wrport2_aRt;
input aregno_t wrport3_aRt;
input pregno_t wrport0_Rt;
input pregno_t wrport1_Rt;
input pregno_t wrport2_Rt;
input pregno_t wrport3_Rt;
input checkpt_ndx_t wrport0_cp;
input checkpt_ndx_t wrport1_cp;
input checkpt_ndx_t wrport2_cp;
input checkpt_ndx_t wrport3_cp;
input value_t wrport0_res;
input value_t wrport1_res;
input value_t wrport2_res;
input value_t wrport3_res;
input cmtav;							// commit valid
input cmtbv;
input cmtcv;
input cmtdv;
input cmtaiv;							// commit invalid instruction
input cmtbiv;
input cmtciv;
input cmtdiv;
input checkpt_ndx_t cmta_cp;
input checkpt_ndx_t cmtb_cp;
input checkpt_ndx_t cmtc_cp;
input checkpt_ndx_t cmtd_cp;
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
input cpu_types_pkg::aregno_t [NPORT-1:0] rn;		// architectural register
input cpu_types_pkg::pregno_t st_prn;
input [2:0] rng [0:NPORT-1];
input [NPORT-1:0] rnv;
input checkpt_ndx_t [NPORT-1:0] rn_cp;
input checkpt_ndx_t [3:0] rd_cp;
output cpu_types_pkg::pregno_t [NPORT-1:0] prn;	// physical register name
output /*reglookup_t*/ reg [NPORT-1:0] prv;											// physical register valid
output reg [Qupls4_pkg::PREGS-1:0] restore_list;	// bit vector of registers to free on branch miss
output reg restored;
output pregno_t [3:0] tags2free;
output reg [3:0] freevals;
input backout;
input rob_ndx_t fcu_id;
output bo_wr;
output aregno_t bo_areg;
output pregno_t bo_preg;
output pregno_t bo_nreg;

/*
integer n7,n8,n9,n10;
reg ren_stall, stall_cyc;
reg [3:0] iwr;
cpu_types_pkg::aregno_t [3:0] iwra;	// architectural register
cpu_types_pkg::pregno_t [3:0] iwrra;	// physical register

// The primary write port is selected first on the notion that two write ports
// are not used that often.
assign wr[0] = wr0;
assign wr[1] = wr1;
assign wr[2] = wr2;
assign wr[3] = wr3;
assign wr[4] = wr01;
assign wr[5] = wr11;
assign wr[6] = wr21;
assign wr[7] = wr31;

assign wra[0] = wra;
assign wra[1] = wrb;
assign wra[2] = wrc;
assign wra[3] = wrd;
assign wra[4] = wra1;
assign wra[5] = wrb1;
assign wra[6] = wrc1;
assign wra[7] = wrd1;

assign wrra[0] = wrra;
assign wrra[1] = wrrb;
assign wrra[2] = wrrc;
assign wrra[3] = wrrd;
assign wrra[4] = wrra1;
assign wrra[5] = wrrb1;
assign wrra[6] = wrrc1;
assign wrra[7] = wrrd1;

// Map as many write ports as possible onto four internal ports. If not all ports
// can be mapped, then stall the pipeline for a cycle to write the additional
// ports.

always_comb
begin
	n8 = 0;
	n9 = 0;
	n10 = 0;
	iwr = 4'd0;
	for (n7 = 0; n7 < 8; n7 = n7 + 1) begin
		if (wr[n7]) n10 = n10 + 1;
		if (wr[n7] && n8 < 4) begin
			iwr[n8] = 1'b1;
			iwra[n8] = wra[n7];
			iwrra[n8] = wrra[n7];
			n8 = n8 + 1
			n9 = n7;
		end
	end
	if (stall_cyc) begin
		n8 = 0;
		iwr = 4'd0;
		for (n7 = 0; n7 < 8; n7 = n7 + 1) begin
			if (wr[n7] && n7 > n9) begin
				iwr[n8] = 1'b1;
				iwra[n8] = wra[n7];
				iwrra[n8] = wrra[n7];
				n8 = n8 + 1
			end
		end
	end
	ren_stall = n10 > 4 && !stall_cyc;
end

// If the stall is longer than one clock, then stall_cyc will go false causing
// the write port logic to reset to the first ports. It will cause an update
// again, but this should be okay as it is the same as the first update.
always_ff @(posedge clk)
if (rst)
	stall_cyc <= FALSE;
else
	stall_cyc <= stall & ~stall_cyc;
*/

reg en2d;
reg [Qupls4_pkg::NCHECK-1:0] avail_chkpts;
checkpt_ndx_t [3:0] chkptn;
reg chkpt_stall;
reg backout_stall;
reg pbackout, pbackout2;
cpu_types_pkg::pregno_t [NPORT-1:0] next_prn;	// physical register name
cpu_types_pkg::pregno_t [NPORT-1:0] prnd;			// delayed physical register name
cpu_types_pkg::aregno_t [NPORT-1:0] prev_rn;
reg pwr00,p2wr0;
reg pwr10,p2wr1;
reg pwr20,p2wr2;
reg pwr30,p2wr3;
reg pwr01,p2wr01;
reg pwr11,p2wr11;
reg pwr21,p2wr21;
reg pwr31,p2wr31;
aregno_t pwra0,p2wra;
aregno_t pwrb0,p2wrb;
aregno_t pwrc0,p2wrc;
aregno_t pwrd0,p2wrd;
aregno_t pwra1,p2wra1;
aregno_t pwrb1,p2wrb1;
aregno_t pwrc1,p2wrc1;
aregno_t pwrd1,p2wrd1;
pregno_t pwrra0,p2wrra;
pregno_t pwrrb0,p2wrrb;
pregno_t pwrrc0,p2wrrc;
pregno_t pwrrd0,p2wrrd;
pregno_t pwrra1,p2wrra1;
pregno_t pwrrb1,p2wrrb1;
pregno_t pwrrc1,p2wrrc1;
pregno_t pwrrd1,p2wrrd1;
checkpt_ndx_t pwra_cp,p2wra_cp;
checkpt_ndx_t pwrb_cp,p2wrb_cp;
checkpt_ndx_t pwrc_cp,p2wrc_cp;
checkpt_ndx_t pwrd_cp,p2wrd_cp;

integer n,m,n1,n2,n3,n4,n5,n6;
reg [3:0] br;
always_comb br[0] = qbr0;
always_comb br[1] = qbr1;
always_comb br[2] = qbr2;
always_comb br[3] = qbr3;
reg cpram_we;
reg cpram_en;
reg cpram_en1;
reg new_chkpt1;
reg new_chkpt2;
localparam RAMWIDTH = Qupls4_pkg::AREGS*RBIT+Qupls4_pkg::PREGS;
//Qupls4_pkg::checkpoint_t currentMap;
//Qupls4_pkg::checkpoint_t nextCurrentMap;
Qupls4_pkg::reg_map_t currentMap;
Qupls4_pkg::reg_map_t nextCurrentMap;
Qupls4_pkg::reg_map_t historyMap;
Qupls4_pkg::reg_map_t nextHistoryMap;
Qupls4_pkg::reg_map_t reg_map_out;
Qupls4_pkg::reg_map_t reg_hist_out;
reg [Qupls4_pkg::PREGS-1:0] avail [0:Qupls4_pkg::NCHECK-1];	// available registers at time of queue (for rollback)
reg [Qupls4_pkg::PREGS-1:0] nextAvail,avail_out;
Qupls4_pkg::checkpoint_t currentMap0;
Qupls4_pkg::checkpoint_t currentMap1;
Qupls4_pkg::checkpoint_t currentMap2;
Qupls4_pkg::checkpoint_t currentMap3;
Qupls4_pkg::checkpoint_t cpram_out;
Qupls4_pkg::checkpoint_t cpram_out1;
Qupls4_pkg::checkpoint_t cpram_out2;
Qupls4_pkg::checkpoint_t cpram_outr;
Qupls4_pkg::checkpoint_t cpram_in;
reg [Qupls4_pkg::PREGS-1:0] currentRegvalid;
wire [Qupls4_pkg::PREGS-1:0] regvalid_ram_o;

reg cpvram_we;
reg [Qupls4_pkg::PREGS-1:0] cpvram_in;
wire [Qupls4_pkg::PREGS-1:0] cpvram_out;
wire [Qupls4_pkg::PREGS-1:0] cpvram_wout;

reg new_chkpt;							// new_chkpt map for current checkpoint
reg pe_alloc_chkpt;
wire pe_alloc_chkpt1;
reg [Qupls4_pkg::PREGS-1:0] valid [0:Qupls4_pkg::NCHECK-1];

/*
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
*/

// There are four "extra" bits in the data to make the size work out evenly.
// There is also an extra write bit. These are defaulted to prevent sim issues.

always_comb
	cpram_en = en2|pe_alloc_chkpt|cpram_we;
always_ff @(posedge clk)
	cpram_en1 <= cpram_en;
/*
Qupls4_checkpoint_ram 
# (.NRDPORTS(1))
cpram1
(
	.rst(rst),
	.clka(clk),
	.ena(1'b1),
	.wea(alloc_chkpt),
	.addra(cndx),
	.dina({4'd0,nextCurrentMap}),
	.douta(),
	.clkb(clk),
	.enb(1'b1),
	.addrb(miss_cp),
	.doutb(cpram_out)
);
*/
Qupls4_reg_map_ram #(.NRDPORTS(1)) rmr1
(
	.rst(rst),
	.clka(clk),
	.ena(1'b1),
	.wea(alloc_chkpt),
	.addra(cndx),
	.dina(nextCurrentMap),
	.douta(), 
	.clkb(clk),
	.enb(1'b1),
	.addrb(miss_cp),
	.doutb(reg_map_out)
);

Qupls4_reg_map_ram #(.NRDPORTS(1)) rmr2
(
	.rst(rst),
	.clka(clk),
	.ena(1'b1),
	.wea(alloc_chkpt),
	.addra(cndx),
	.dina(nextHistoryMap),
	.douta(), 
	.clkb(clk),
	.enb(1'b1),
	.addrb(miss_cp),
	.doutb(reg_hist_out)
);

always_ff @(posedge clk)
if (rst)
	avail_out <= {Qupls4_pkg::PREGS{1'b1}};
else begin
	if (alloc_chkpt)
		avail[cndx] <= nextAvail;
	avail_out <= avail[miss_cp];
end

reg [9:0] cpv_wr;
checkpt_ndx_t [9:0] cpv_wc;
cpu_types_pkg::pregno_t [9:0] cpv_wa;
cpu_types_pkg::aregno_t [9:0] cpv_awa;
reg [9:0] cpv_i;
wire [NPORT-1:0] cpv_o;
wire cdwr0;
wire cdwr1;
wire cdwr2;
wire cdwr3;
wire cdcmtav;
wire cdcmtbv;
wire cdcmtcv;
wire cdcmtdv;
reg pcdwr0;
reg pcdwr1;
reg pcdwr2;
reg pcdwr3;
reg p2cdwr0;
reg p2cdwr1;
reg p2cdwr2;
reg p2cdwr3;

always_comb cpv_wr[0] = cdcmtav;
always_comb cpv_wr[1] = cdcmtbv;
always_comb cpv_wr[2] = cdcmtcv;
always_comb cpv_wr[3] = cdcmtdv;
always_comb cpv_wr[4] = cdwr0;
always_comb cpv_wr[5] = cdwr1;
always_comb cpv_wr[6] = cdwr2;
always_comb cpv_wr[7] = cdwr3;
always_comb cpv_wr[8] = bo_wr;
always_comb cpv_wr[9] = 1'b0;
always_comb cpv_wc[0] = cmta_cp;
always_comb cpv_wc[1] = cmtb_cp;
always_comb cpv_wc[2] = cmtc_cp;
always_comb cpv_wc[3] = cmtd_cp;
always_comb cpv_wc[4] = wra_cp;
always_comb cpv_wc[5] = wrb_cp;
always_comb cpv_wc[6] = wrc_cp;
always_comb cpv_wc[7] = wrd_cp;
always_comb cpv_wc[8] = cndx;
always_comb cpv_wc[9] = cndx;
always_comb cpv_wa[0] = cmtap;
always_comb cpv_wa[1] = cmtbp;
always_comb cpv_wa[2] = cmtcp;
always_comb cpv_wa[3] = cmtdp;
always_comb cpv_wa[4] = wrra;
always_comb cpv_wa[5] = wrrb;
always_comb cpv_wa[6] = wrrc;
always_comb cpv_wa[7] = wrrd;
always_comb cpv_wa[8] = bo_preg;
always_comb cpv_wa[9] = bo_preg;
always_comb cpv_awa[0] = cmtaa;
always_comb cpv_awa[1] = cmtba;
always_comb cpv_awa[2] = cmtca;
always_comb cpv_awa[3] = cmtda;
always_comb cpv_awa[4] = wra;
always_comb cpv_awa[5] = wrb;
always_comb cpv_awa[6] = wrb;
always_comb cpv_awa[7] = wrd;
always_comb cpv_awa[8] = bo_areg;
always_comb cpv_awa[9] = bo_areg;
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
always_comb cpv_i[9] = VAL;

reg stall_same_reg;
always_comb
if (
	(wrport0_Rt==wrra && wrport0_v && wr0 && en2) ||
	(wrport0_Rt==wrrb && wrport0_v && wr1 && en2) ||
	(wrport0_Rt==wrrc && wrport0_v && wr2 && en2) ||
	(wrport0_Rt==wrrd && wrport0_v && wr3 && en2) ||
	(wrport1_Rt==wrra && wrport1_v && wr0 && en2) ||
	(wrport1_Rt==wrrb && wrport1_v && wr1 && en2) ||
	(wrport1_Rt==wrrc && wrport1_v && wr2 && en2) ||
	(wrport1_Rt==wrrd && wrport1_v && wr3 && en2) ||
	// ToDo: fix the following checks
	(cmtcp==wrra && cmtcv && wr0 && en2) ||
	(cmtcp==wrrb && cmtcv && wr1 && en2) ||
	(cmtcp==wrrc && cmtcv && wr2 && en2) ||
	(cmtcp==wrrd && cmtcv && wr3 && en2) ||
	(cmtdp==wrra && cmtdv && wr0 && en2) ||
	(cmtdp==wrrb && cmtdv && wr1 && en2) ||
	(cmtdp==wrrc && cmtdv && wr2 && en2) ||
	(cmtdp==wrrd && cmtdv && wr3 && en2)
	)
begin
//	$display("Qupls4CPU rat: register marked valid and invalid at same time");
//	$finish;
	stall_same_reg <= 1'b0;
end
else
	stall_same_reg <= 1'b0;

always_ff @(posedge clk)
if (rst)
	currentRegvalid <= {Qupls4_pkg::PREGS{1'b1}};
else begin

	if (restore)
		currentRegvalid = regvalid_ram_o;
//	else
	begin
		if (bo_wr) begin
//			currentRegvalid[bo_preg] <= VAL;
			currentRegvalid[bo_nreg] = VAL;
//			currentRegvalid[currentMap.regmap[bo_areg]] <= VAL;
		end
		if (wrport0_v)
			currentRegvalid[wrport0_Rt] = VAL;
		if (wrport1_v)
			currentRegvalid[wrport1_Rt] = VAL;
		if (wrport2_v)
			currentRegvalid[wrport2_Rt] = VAL;
		if (wrport3_v)
			currentRegvalid[wrport3_Rt] = VAL;

		if (en2 & ~stall_same_reg) begin
			if (pwr00)
				currentRegvalid[pwrra0] = INV;
			if (pwr10)
				currentRegvalid[pwrrb0] = INV;
			if (pwr20)
				currentRegvalid[pwrrc0] = INV;
			if (pwr30)
				currentRegvalid[pwrrd0] = INV;
			/*
			if (pwr01)
				currentRegvalid[pwrra1] = INV;
			if (pwr11)
				currentRegvalid[pwrrb1] = INV;
			if (pwr21)
				currentRegvalid[pwrrc1] = INV;
			if (pwr31)
				currentRegvalid[pwrrd1] = INV;
			*/
		end
		
		if (cmtaiv)
			currentRegvalid[cmtap] = VAL;
		if (cmtbiv)
			currentRegvalid[cmtbp] = VAL;
		if (cmtciv)
			currentRegvalid[cmtcp] = VAL;
		if (cmtdiv)
			currentRegvalid[cmtdp] = VAL;
	end
end

Qupls4_regvalid_ram urvram1
(
	.rst(rst),
	.clk(clk),
	.ena(1'b1),
	.wea(pe_alloc_chkpt),
	.addra(cndx),
	.dina(currentRegvalid),
	.enb(1'b1),
	.addrb(miss_cp),
	.doutb(regvalid_ram_o)
);

genvar g;
integer mndx,nn;

wire qbr = qbr0|qbr1|qbr2|qbr3;
// number of outstanding branches
reg [5:0] nob;
wire qbr_ok = nq && qbr && nob < 6'd15;
wire bypass_en = !pbackout;
reg [NPORT-1:0] bypass_pwrra00;
reg [NPORT-1:0] bypass_pwrrb00;
reg [NPORT-1:0] bypass_pwrrc00;
reg [NPORT-1:0] bypass_pwrrd00;
reg [NPORT-1:0] bypass_pwrra01;
reg [NPORT-1:0] bypass_pwrrb01;
reg [NPORT-1:0] bypass_pwrrc01;
reg [NPORT-1:0] bypass_pwrrd01;
reg [NPORT-1:0] bypass_p2wrra0;
reg [NPORT-1:0] bypass_p2wrrb0;
reg [NPORT-1:0] bypass_p2wrrc0;
reg [NPORT-1:0] bypass_p2wrrd0;
wire [NPORT-1:0] cdrn;

// Read register names from current checkpoint.
// Bypass new register mappings if reg selected.
generate begin : gRRN
	for (g = 0; g < NPORT-1; g = g + 1) begin
change_det #($bits(aregno_t)) ucdrn1 (.rst(rst), .clk(clk), .ce(1'b1), .i(rn[g]), .cd(cdrn[g]));

		always_comb
			if (rst)
				next_prn[g] = 10'd0;
			// If there is a pipeline bubble.
			else begin
				next_prn[g] = 10'd0;
				begin
					// Do we need the checkpoint to match?
					// Compute bypassing requirements.
					bypass_pwrra00[g] = (rn[g]==pwra0) && pwr00 /*&& rn_cp[g]==pwra_cp*/;
//					bypass_pwrra01[g] = (rn[g]==pwra1) && pwr01 /*&& rn_cp[g]==pwra_cp*/;
					bypass_pwrrb00[g] = (rn[g]==pwrb0) && pwr10 /*&& rn_cp[g]==pwrb_cp*/;
//					bypass_pwrrb01[g] = (rn[g]==pwrb1) && pwr11 /*&& rn_cp[g]==pwrb_cp*/;
					bypass_pwrrc00[g] = (rn[g]==pwrc0) && pwr20 /*&& rn_cp[g]==pwrc_cp*/;
//					bypass_pwrrc01[g] = (rn[g]==pwrc1) && pwr21 /*&& rn_cp[g]==pwrc_cp*/;
					bypass_pwrrd00[g] = (rn[g]==pwrd0) && pwr30 /*&& rn_cp[g]==pwrd_cp*/;
//					bypass_pwrrd01[g] = (rn[g]==pwrd1) && pwr31 /*&& rn_cp[g]==pwrd_cp*/;

					bypass_p2wrra0[g] =  (rn[g]==p2wrd) && p2wr3 /*&& rn_cp[g]==p2wrd_cp*/;
					bypass_p2wrrb0[g] =	(rn[g]==p2wrc) && p2wr2 /*&& rn_cp[g]==p2wrc_cp*/;
					bypass_p2wrrc0[g] =	(rn[g]==p2wrb) && p2wr1 /*&& rn_cp[g]==p2wrb_cp*/;
					bypass_p2wrrd0[g] =	(rn[g]==p2wra) && p2wr0 /*&& rn_cp[g]==p2wra_cp*/;
					
					// Bypass only for previous instruction in same group
					case(rng[g])
					3'd0:	
						begin
							next_prn[g] =
								// No intra-group bypass needed
								// Intergroup bypass, needed as the map RAM has not updated in
								// time for the next group of instructions.
								(bypass_pwrrd00[g] && bypass_en) ? pwrrd0 :
//								(bypass_pwrrd01[g] && bypass_en) ? pwrrd1 :
								(bypass_pwrrc00[g] && bypass_en) ? pwrrc0 :
//								(bypass_pwrrc01[g] && bypass_en) ? pwrrc1 :
								(bypass_pwrrb00[g] && bypass_en) ? pwrrb0 :
//								(bypass_pwrrb01[g] && bypass_en) ? pwrrb1 :
								(bypass_pwrra00[g] && bypass_en) ? pwrra0 :
//								(bypass_pwrra01[g] && bypass_en) ? pwrra1 :
								currentMap.regmap[rn[g]];
													/*
													(bypass_p2wrrd0[g] && bypass_en) ? p2wrrd :
													(bypass_p2wrrc0[g] && bypass_en) ? p2wrrc :
													(bypass_p2wrrb0[g] && bypass_en) ? p2wrrb :
													(bypass_p2wrra0[g] && bypass_en) ? p2wrra :
													*/
						end
					3'd1: 
						next_prn[g] = 
								// Intra group bypass
								(rn[g]==wra && wr0) ? wrra :
//								(rn[g]==wra1 && wr01) ? wrra1 :
								// Intergroup bypass, needed as the map RAM has not updated in
								// time for the next group of instructions.
								(bypass_pwrrd00[g] && bypass_en) ? pwrrd0 :
	//							(bypass_pwrrd01[g] && bypass_en) ? pwrrd1 :
								(bypass_pwrrc00[g] && bypass_en) ? pwrrc0 :
//								(bypass_pwrrc01[g] && bypass_en) ? pwrrc1 :
								(bypass_pwrrb00[g] && bypass_en) ? pwrrb0 :
//								(bypass_pwrrb01[g] && bypass_en) ? pwrrb1 :
								(bypass_pwrra00[g] && bypass_en) ? pwrra0 :
//								(bypass_pwrra01[g] && bypass_en) ? pwrra1 :
								currentMap.regmap[rn[g]];
													/*
													(rn[g]==wra && wr0 && rn_cp[g]==wra_cp) ? wrra :
													*/
													/*
													(bypass_pwrrd0[g] && bypass_en) ? pwrrd :
													(bypass_pwrrc0[g] && bypass_en) ? pwrrc :
													(bypass_pwrrb0[g] && bypass_en) ? pwrrb :
													(bypass_pwrra0[g] && bypass_en) ? pwrra :
													*/
													/*
													(bypass_p2wrrd0[g] && bypass_en) ? p2wrrd :
													(bypass_p2wrrc0[g] && bypass_en) ? p2wrrc :
													(bypass_p2wrrb0[g] && bypass_en) ? p2wrrb :
													(bypass_p2wrra0[g] && bypass_en) ? p2wrra :
													*/
													//rn[g]==wra && wr0 ? wrra :	// One previous target
													//qbr0 ? cpram_out1.regmap[rn[g]] :
					3'd2: next_prn[g] = 
								// Intra group bypass
								(rn[g]==wrb && wr1) ? wrrb :
//								(rn[g]==wrb1 && wr11) ? wrrb1 :
								(rn[g]==wra && wr0) ? wrra :
//								(rn[g]==wra1 && wr01) ? wrra1 :
								// Intergroup bypass, needed as the map RAM has not updated in
								// time for the next group of instructions.
								(bypass_pwrrd00[g] && bypass_en) ? pwrrd0 :
//								(bypass_pwrrd01[g] && bypass_en) ? pwrrd1 :
								(bypass_pwrrc00[g] && bypass_en) ? pwrrc0 :
//								(bypass_pwrrc01[g] && bypass_en) ? pwrrc1 :
								(bypass_pwrrb00[g] && bypass_en) ? pwrrb0 :
//								(bypass_pwrrb01[g] && bypass_en) ? pwrrb1 :
								(bypass_pwrra00[g] && bypass_en) ? pwrra0 :
//								(bypass_pwrra01[g] && bypass_en) ? pwrra1 :
								currentMap.regmap[rn[g]];
													/*
													(rn[g]==wrb && wr1 && rn_cp[g]==wrb_cp) ? wrrb :
													(rn[g]==wra && wr0 && rn_cp[g]==wra_cp) ? wrra :
													*/
													/*
													(bypass_pwrrd0[g] && bypass_en) ? pwrrd :
													(bypass_pwrrc0[g] && bypass_en) ? pwrrc :
													(bypass_pwrrb0[g] && bypass_en) ? pwrrb :
													(bypass_pwrra0[g] && bypass_en) ? pwrra :
													*/
													/*
													(bypass_p2wrrd0[g] && bypass_en) ? p2wrrd :
													(bypass_p2wrrc0[g] && bypass_en) ? p2wrrc :
													(bypass_p2wrrb0[g] && bypass_en) ? p2wrrb :
													(bypass_p2wrra0[g] && bypass_en) ? p2wrra :
													*/
												 	//rn[g]==wrb && wr1 ? wrrb :	// Two previous target
													//rn[g]==wra && wr0 ? wrra :
													//qbr0|qbr1 ? cpram_out1.regmap[rn[g]] :
					3'd3:
						next_prn[g] = 
							// Intra group bypass
							(rn[g]==wrc && wr2) ? wrrc :
//							(rn[g]==wrc1 && wr21) ? wrrc1 :
							(rn[g]==wrb && wr1) ? wrrb :
//							(rn[g]==wrb1 && wr11) ? wrrb1 :
							(rn[g]==wra && wr0) ? wrra :
//							(rn[g]==wra1 && wr01) ? wrra1 :
							// Intergroup bypass, needed as the map RAM has not updated in
							// time for the next group of instructions.
								(bypass_pwrrd00[g] && bypass_en) ? pwrrd0 :
//								(bypass_pwrrd01[g] && bypass_en) ? pwrrd1 :
								(bypass_pwrrc00[g] && bypass_en) ? pwrrc0 :
//								(bypass_pwrrc01[g] && bypass_en) ? pwrrc1 :
								(bypass_pwrrb00[g] && bypass_en) ? pwrrb0 :
//								(bypass_pwrrb01[g] && bypass_en) ? pwrrb1 :
								(bypass_pwrra00[g] && bypass_en) ? pwrra0 :
//								(bypass_pwrra01[g] && bypass_en) ? pwrra1 :
							currentMap.regmap[rn[g]];
													/*													
													(rn[g]==wrc && wr2 && rn_cp[g]==wrc_cp) ? wrrc :
													(rn[g]==wrb && wr1 && rn_cp[g]==wrb_cp) ? wrrb :
													(rn[g]==wra && wr0 && rn_cp[g]==wra_cp) ? wrra :
													*/
												  /*
													(bypass_pwrrd0[g] && bypass_en) ? pwrrd :
													(bypass_pwrrc0[g] && bypass_en) ? pwrrc :
													(bypass_pwrrb0[g] && bypass_en) ? pwrrb :
													(bypass_pwrra0[g] && bypass_en) ? pwrra :
													*/
													/*													
													(bypass_p2wrrd0[g] && bypass_en) ? p2wrrd :
													(bypass_p2wrrc0[g] && bypass_en) ? p2wrrc :
													(bypass_p2wrrb0[g] && bypass_en) ? p2wrrb :
													(bypass_p2wrra0[g] && bypass_en) ? p2wrra :
													*/
												 	//rn[g]==wrc && wr2 ? wrrc :	// Three previous target
													//rn[g]==wrb && wr1 ? wrrb :
													//rn[g]==wra && wr0 ? wrra :
													//qbr0|qbr1|qbr2 ? cpram_out1.regmap[rn[g]] :
					default: next_prn[g] = currentMap.regmap[rn[g]];
					endcase
				end
			end

		always_ff @(posedge clk)
			if (rst) begin
				prn[g] <= 9'd0;
				prev_rn[g] <= 8'd0;
			end
			// If there is a pipeline bubble.
			else begin
//				if (cdrn[g] || cpram_we) 
				if (en2)
				begin
					prn[g] <= next_prn[g];
					prev_rn[g] <= rn[g];
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
					begin
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
							if (prn[g]==cmtdp && cmtdv)
								prv[g] = VAL;
							else if (prn[g]==cmtcp && cmtcv)
								prv[g] = VAL;
							else if (prn[g]==cmtbp && cmtbv)
								prv[g] = VAL;
							else if (prn[g]==cmtap && cmtav)
								prv[g] = VAL;
							
							
							else if (prn[g]==pwrrd0 && pwr30)
								prv[g] = INV;
							else if (prn[g]==pwrrc0 && pwr20)
								prv[g] = INV;
							else if (prn[g]==pwrrb0 && pwr10)
								prv[g] = INV;
							else if (prn[g]==pwrra0 && pwr00)
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
														
								prv[g] = currentRegvalid[prn[g]];//cpv_o[g];
						// Second instruction of group, bypass only if first instruction target is same.
						3'd1:
						begin							
							if (prn[g]==bo_nreg && bo_wr)
								prv[g] = VAL;
							else if (prn[g]==wrport0_Rt && wrport0_v)
								prv[g] = VAL;					
								
							else if (prn[g]==cmtdp && cmtdv)
								prv[g] = VAL;
							else if (prn[g]==cmtcp && cmtcv)
								prv[g] = VAL;
							else if (prn[g]==cmtbp && cmtbv)
								prv[g] = VAL;
							else if (prn[g]==cmtap && cmtav)
								prv[g] = VAL;
							
							
							else if (prn[g]==pwrrd0 && pwr30)
								prv[g] = INV;
							else if (prn[g]==pwrrc0 && pwr20)
								prv[g] = INV;
							else if (prn[g]==pwrrb0 && pwr10)
								prv[g] = INV;
							else if (prn[g]==pwrra0 && pwr00)
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
//								prv[g] = cpv_o[g];
								prv[g] = currentRegvalid[prn[g]];//cpv_o[g];
						end
						// Third instruction, check two previous ones.
						3'd2:
						begin
							if (prn[g]==bo_nreg && bo_wr)
								prv[g] = VAL;
							else if (prn[g]==wrport1_Rt && wrport1_v)
								prv[g] = VAL;					
							else if (prn[g]==wrport0_Rt && wrport0_v)
								prv[g] = VAL;					
								
								
							else if (prn[g]==cmtdp && cmtdv)
								prv[g] = VAL;
							else if (prn[g]==cmtcp && cmtcv)
								prv[g] = VAL;
							else if (prn[g]==cmtbp && cmtbv)
								prv[g] = VAL;
							else if (prn[g]==cmtap && cmtav)
								prv[g] = VAL;
							
							
							else if (prn[g]==pwrrd0 && pwr30)
								prv[g] = INV;
							else if (prn[g]==pwrrc0 && pwr20)
								prv[g] = INV;
							else if (prn[g]==pwrrb0 && pwr10)
								prv[g] = INV;
							else if (prn[g]==pwrra0 && pwr00)
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
//							else
							
								prv[g] = currentRegvalid[prn[g]];//cpv_o[g];
//								prv[g] = cpv_o[g];
//								prv[g] = valid[cndx][prn[g]];
						end
					// Fourth instruction, check three previous ones.						
						3'd3:
							begin
							if (prn[g]==bo_nreg && bo_wr)
								prv[g] = VAL;
							else if (prn[g]==wrport2_Rt && wrport2_v)
								prv[g] = VAL;					
							else if (prn[g]==wrport1_Rt && wrport1_v)
								prv[g] = VAL;					
							else if (prn[g]==wrport0_Rt && wrport0_v)
								prv[g] = VAL;					
							
							else if (prn[g]==cmtdp && cmtdv)
								prv[g] = VAL;
							else if (prn[g]==cmtcp && cmtcv)
								prv[g] = VAL;
							else if (prn[g]==cmtbp && cmtbv)
								prv[g] = VAL;
							else if (prn[g]==cmtap && cmtav)
								prv[g] = VAL;
							
							
							else if (prn[g]==pwrrd0 && pwr30)
								prv[g] = INV;
							else if (prn[g]==pwrrc0 && pwr20)
								prv[g] = INV;
							else if (prn[g]==pwrrb0 && pwr10)
								prv[g] = INV;
							else if (prn[g]==pwrra0 && pwr00)
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
							
								prv[g] = currentRegvalid[prn[g]];//cpv_o[g];
//								prv[g] = cpv_o[g];
//								prv[g] = valid[cndx][next_prn[g]];
							end
						default:
							prv[g] = VAL;
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
		next_prn[NPORT-1] = st_prn;
	always_comb
		prn[NPORT-1] <= st_prn;
	always_comb//ff @(posedge clk)
		if (prn[NPORT-1]==cmtdp && cmtdv)
			prv[NPORT-1] = VAL;
		else if (prn[NPORT-1]==cmtcp && cmtcv)
			prv[NPORT-1] = VAL;
		else if (prn[NPORT-1]==cmtbp && cmtbv)
			prv[NPORT-1] = VAL;
		else if (prn[NPORT-1]==cmtap && cmtav)
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
			prv[NPORT-1] = currentRegvalid[prn[NPORT-1]];//cpv_o[g];
//			prv[NPORT-1] = cpv_o[NPORT-1];
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

// Set checkpoint for each instruction in the group. The machine will stall
// for checkpoint assignments.


// Backout state machine. For backing out RAT changes when a mispredict
// occurs. We go backwards to the mispredicted branch, updating the RAT with
// the old register mappings which are stored in the ROB.
// Note if a branch mispredict occurs and the checkpoint is being restored
// to an earlier one anyway, then this backout is cancelled.

wire [1:0] backout_state;

Qupls4_backout_machine ubomac1
(
	.rst(rst),
	.clk(clk),
	.backout(backout),
	.fcu_id(fcu_id),
	.rob(rob),
	.tail(tail),
	.restore(restore),
	.backout_state(backout_state),
	.bo_wr(bo_wr),
	.bo_areg(bo_areg),
	.bo_preg(bo_preg),
	.bo_nreg(bo_nreg),
	.stall(backout_stall)
);

// Stall the enqueue of instructions if there are too many outstanding branches.
// Also stall for a new checkpoint or a lack of available checkpoints.
// Stall the CPU pipeline for amt+1 cycles to allow checkpoint copying.
always_comb
	stall = /*pe_alloc_chkpt||*/backout_stall||stall_same_reg;//||(qbr && nob==NCHECK-1);


// Committing and queuing target physical register cannot be the same.
// Make use of the fact that other logic consumes lots of time, and implement
// time-multiplexed write ports, multiplexed at five times the CPU clock rate.
// Priorities are resolved by the time-multiplex so, priority logic is not 
// needed.

reg wr;
aregno_t aregno;
pregno_t pregno;
aregno_t cmtareg;
reg cdcmtv;
/*
always_comb
begin
	case(wcnt)
	3'd0:
		begin
			wr <= wr0;
			aregno <= wra;
			pregno <= wrra;
			cdcmtv <= cdcmtav;
			cmtareg <= cmtaa;
		end
	3'd1:
		begin
			wr <= wr1;
			aregno <= wrb;
			pregno <= wrrb;
			cdcmtv <= cdcmtbv;
			cmtareg <= cmtba;
		end
	3'd2:
		begin
			wr <= wr2;
			aregno <= wrc;
			pregno <= wrrc;
			cdcmtv <= cdcmtcv;
			cmtareg <= cmtca;
		end
	3'd3:
		begin
			wr <= wr3;
			aregno <= wrd;
			pregno <= wrrd;
			cdcmtv <= cdcmtdv;
			cmtareg <= cmtda;
		end
	default:
		begin
			wr <= wr3;
			aregno <= wrd;
			pregno <= wrrd;
			cdcmtv <= cdcmtdv;
			cmtareg <= cmtda;
		end
	endcase
end
*/
/*
always_ff @(posedge clk5x)
if (rst) begin
	cpram_in.avail = {{Qupls4_pkg::PREGS-1{1'b1}},1'b0};
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
			$display("Qupls4 RAT: tgta %d reg %d replaced with %d.", aregno, cpram_out.regmap[aregno], pregno);
		end
	end
	
	if (wr) begin
		if (aregno==8'd41)
			$finish;
		if (pregno==10'd0 && aregno != 8'd0) begin
			$display("Qupls4CPU RAT: mapping register to r0");
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
pregno_t cmtapA1;
pregno_t cmtbp1;
pregno_t cmtcp1;
pregno_t cmtdp1;
wire cd_cmtav;
wire cd_cmtbv;
wire cd_cmtcv;
wire cd_cmtdv;

// If the same value is going to the same register in two consecutive clock cycles,
// only do one update. Prevents a register from being released for use too soon.
change_det #($bits(aregno_t)+$bits(pregno_t)+$bits(value_t)+1) ucmta1 (.rst(rst), .clk(clk), .ce(1'b1), .i({cmtav|cmtaiv,cmtaa,cmtap,cmtaval}), .cd(cd_cmtav));
change_det #($bits(aregno_t)+$bits(pregno_t)+$bits(value_t)+1) ucmtb1 (.rst(rst), .clk(clk), .ce(1'b1), .i({cmtbv|cmtbiv,cmtba,cmtbp,cmtbval}), .cd(cd_cmtbv));
change_det #($bits(aregno_t)+$bits(pregno_t)+$bits(value_t)+1) ucmtc1 (.rst(rst), .clk(clk), .ce(1'b1), .i({cmtcv|cmtciv,cmtca,cmtcp,cmtcval}), .cd(cd_cmtcv));
change_det #($bits(aregno_t)+$bits(pregno_t)+$bits(value_t)+1) ucmtd1 (.rst(rst), .clk(clk), .ce(1'b1), .i({cmtdv|cmtdiv,cmtda,cmtdp,cmtdval}), .cd(cd_cmtdv));

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
change_det #($bits(aregno_t)+$bits(pregno_t)+1) uwrcda1 (.rst(rst), .clk(clk), .ce(en2d), .i({wr0,wra,wrra}), .cd(cd_wr0));
change_det #($bits(aregno_t)+$bits(pregno_t)+1) uwrcdb1 (.rst(rst), .clk(clk), .ce(en2d), .i({wr1,wrb,wrrb}), .cd(cd_wr1));
change_det #($bits(aregno_t)+$bits(pregno_t)+1) uwrcdc1 (.rst(rst), .clk(clk), .ce(en2d), .i({wr2,wrc,wrrc}), .cd(cd_wr2));
change_det #($bits(aregno_t)+$bits(pregno_t)+1) uwrcdd1 (.rst(rst), .clk(clk), .ce(en2d), .i({wr3,wrd,wrrd}), .cd(cd_wr3));

always_comb//ff @(posedge clk)
if (rst)
	en2d <= 1'b0;
else
	en2d <= en2;

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
	cmtapA1 <= 9'd0;
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
		cmtapA1 <= cmtap;
		cmtbp1 <= cmtbp;
		cmtcp1 <= cmtcp;
		cmtdp1 <= cmtdp;
	end
end

// Free tags come from the end of a two-entry shift register containing the
// physical register number.
// A backed out register mapping should be made available.
// Delay the tag free a few clock cycles.
// For invalid instructions at commit time, the register must also be freed.
// This does not require any more ports as the instruction cannot be valid and
// invalid at the same time.

always_ff @(posedge clk)
if (rst) begin
	tags2free[0] <= {$bits(pregno_t){1'b0}};
	tags2free[1] <= {$bits(pregno_t){1'b0}};
	tags2free[2] <= {$bits(pregno_t){1'b0}};
	tags2free[3] <= {$bits(pregno_t){1'b0}};
end
else begin
	tags2free[0] <= {$bits(pregno_t){1'b0}};
	tags2free[1] <= {$bits(pregno_t){1'b0}};
	tags2free[2] <= {$bits(pregno_t){1'b0}};
	tags2free[3] <= {$bits(pregno_t){1'b0}};
	
	// For invalid frees we do not want to push the free pipeline.
	if (bo_wr)
		tags2free[0] <= bo_nreg;
	else if (cdcmtav)
		tags2free[0] <= historyMap.regmap[cmtaa];
	if (cdcmtbv)
		tags2free[1] <= historyMap.regmap[cmtba];
	if (cdcmtcv)
		tags2free[2] <= historyMap.regmap[cmtca];
	if (cdcmtdv)
		tags2free[3] <= historyMap.regmap[cmtda];
end

always_ff @(posedge clk)
if (rst)
	freevals <= 4'd0;
else begin
	freevals[0] <= cdcmtav|bo_wr;
	freevals[1] <= cdcmtbv;
	freevals[2] <= cdcmtcv;
	freevals[3] <= cdcmtdv;
end

assign cdwr0 = cd_wr0 & wr0;
assign cdwr1 = cd_wr1 & wr1;
assign cdwr2 = cd_wr2 & wr2;
assign cdwr3 = cd_wr3 & wr3;
assign cdcmtav = cd_cmtav & (cmtav|cmtaiv);
assign cdcmtbv = cd_cmtbv & (cmtbv|cmtbiv);
assign cdcmtcv = cd_cmtcv & (cmtcv|cmtciv);
assign cdcmtdv = cd_cmtdv & (cmtdv|cmtdiv);

wire pe_bk, ne_bk;
edge_det uedbckout1 (.rst(rst), .clk(clk), .ce(1'b1), .i(backout_state==2'd1), .pe(pe_bk), .ne(ne_bk), .ee());
reg [Qupls4_pkg::PREGS-1:0] unavail;

// Set the checkpoint RAM input.
// For checkpoint establishment the current read value is desired.
// For normal operation the write output port is used.

// For input to the checkpoint ram the updated map before the end of the clock
// cycle is needed.

always_comb
if (rst) begin
	nextCurrentMap = {$bits(Qupls4_pkg::reg_map_t){1'b0}};
	nextHistoryMap = {$bits(Qupls4_pkg::reg_map_t){1'b0}};
	nextAvail = {Qupls4_pkg::PREGS{1'b1}};
end
else begin
	nextCurrentMap = currentMap;
	nextHistoryMap = historyMap;

	// The branch instruction itself might need to update the checkpoint info.
	// Even if a checkpoint is being allocated, we want to record new maps.
	if (en2) begin
		if (wr0)
			nextCurrentMap.regmap[wra] = wrra;
		if (wr1)
			nextCurrentMap.regmap[wrb] = wrrb;
		if (wr2)
			nextCurrentMap.regmap[wrc] = wrrc;
		if (wr3)
			nextCurrentMap.regmap[wrd] = wrrd;
	end

	// Shift the physical register into a second spot.
	// Note that .regmap[] ahould be the same as the physical register at commit.
	// It is a little less logic just to use the physical register at commit,
	// rather than referencing .regmap[]
	if (cdcmtav)
		nextHistoryMap.regmap[cmtaa] = cmtap;
	if (cdcmtbv)
		nextHistoryMap.regmap[cmtba] = cmtbp;
	if (cdcmtcv)
		nextHistoryMap.regmap[cmtca] = cmtcp;
	if (cdcmtdv)
		nextHistoryMap.regmap[cmtda] = cmtdp;

	// Available registers are recorded in the checkpoint as supplied by the
	// name supplier.
//	if (!pe_alloc_chkpt1)
	nextAvail = avail_i;
end

always_ff @(posedge clk)
begin
	if (restore)
		currentMap <= reg_map_out;
	else
		currentMap <= nextCurrentMap;
end

always_ff @(posedge clk)
begin
	if (restore)
		historyMap <= reg_hist_out;
	else
		historyMap <= nextHistoryMap;
end

always_ff @(posedge clk)
if (rst)
	unavail <= {Qupls4_pkg::PREGS{1'b0}};
else begin

	if (pe_bk)
		unavail <= {Qupls4_pkg::PREGS{1'b0}};

	// Backout update.
	if (bo_wr) begin
//	currentMap.regmap[bo_areg] <= bo_preg;
//	unavail[bo_preg] <= 1'b1;
	end
end

// Diags.
always_ff @(posedge clk)
if (Qupls4_pkg::SIM) begin
	if (TRUE||en2) begin
		if (bo_wr)
			$display("Qupls4 CPU RAT: backout %d restored to %d", currentMap.regmap[bo_areg], bo_preg);

		if (cd_wr0 & wr0) begin
			$display("Qupls4 CPU RAT: tgta %d reg %d replaced with %d.", wra, currentMap.regmap[wra], wrra);
		end
		if (cd_wr1 & wr1) begin
			$display("Qupls4 CPU RAT: tgtb %d reg %d replaced with %d.", wrb, currentMap.regmap[wrb], wrrb);
		end
		if (cd_wr2 & wr2) begin
			$display("Qupls4 CPU RAT: tgtc %d reg %d replaced with %d.", wrc, currentMap.regmap[wrc], wrrc);
		end
		if (cd_wr3 & wr3) begin
			$display("Qupls4 CPU RAT: tgtd %d reg %d replaced with %d.", wrd, currentMap.regmap[wrd], wrrd);
		end
	end
	
end

always_ff @(posedge clk) 
if (rst) begin
	pbackout <= FALSE;
	pbackout2 <= FALSE;
end
else begin
	begin
		pbackout2 <= backout_stall;
		pbackout <= backout_stall | pbackout2;
	end
end

always_ff @(posedge clk) 
if (rst) begin
	pwr00 <= 1'b0;
//	pwr01 <= 1'b0;
end
else begin
	if (en2d) begin
		pwr00 <= wr0 && !pbackout;
//		pwr01 <= wr01 && !pbackout;
    end
end
always_ff @(posedge clk) 
if (rst) begin
	pwr10 <= 1'b0;
//	pwr11 <= 1'b0;
end
else begin
	if (en2d) begin
		pwr10 <= wr1 && !pbackout;
//		pwr11 <= wr11 && !pbackout;
	end
end
always_ff @(posedge clk) 
if (rst) begin
	pwr20 <= 1'b0;
//	pwr21 <= 1'b0;
end
else begin
	if (en2d) begin
		pwr20 <= wr2 && !pbackout;
//		pwr21 <= wr21 && !pbackout;
	end
end
always_ff @(posedge clk) 
if (rst) begin
	pwr30 <= 1'b0;
//	pwr31 <= 1'b0;
end
else begin
	if (en2d) begin
		pwr30 <= wr3 && !pbackout;
//		pwr31 <= wr31 && !pbackout;
	end
end

always_ff @(posedge clk) 
if (rst) begin
	pwra0 <= 8'b0;
//	pwra1 <= 8'b0;
end
else begin
	if (en2d) begin
		pwra0 <= wra;
//		pwra1 <= wra1;
	end
end
always_ff @(posedge clk) 
if (rst) begin
	pwrb0 <= 8'b0;
//	pwrb1 <= 8'b0;
end
else begin
	if (en2d) begin
		pwrb0 <= wrb;
//		pwrb1 <= wrb1;
	end
end
always_ff @(posedge clk) 
if (rst) begin
	pwrc0 <= 8'b0;
//	pwrc1 <= 8'b0;
end
else begin
	if (en2d) begin
		pwrc0 <= wrc;
//		pwrc1 <= wrc1;
	end
end
always_ff @(posedge clk) 
if (rst) begin
	pwrd0 <= 8'b0;
//	pwrd1 <= 8'b0;
end
else begin
	if (en2d) begin
		pwrd0 <= wrd;
//		pwrd1 <= wrd1;
	end
end

always_ff @(posedge clk) 
if (rst) begin
	pcdwr0 <= 1'b0;
end
else begin
	if (en2d)
		pcdwr0 <= cdwr0;
end
always_ff @(posedge clk) 
if (rst) begin
	pcdwr1 <= 1'b0;
end
else begin
	if (en2d)
		pcdwr1 <= cdwr1;
end
always_ff @(posedge clk) 
if (rst) begin
	pcdwr2 <= 1'b0;
end
else begin
	if (en2d)
		pcdwr2 <= cdwr2;
end
always_ff @(posedge clk) 
if (rst) begin
	pcdwr3 <= 1'b0;
end
else begin
	if (en2d)
		pcdwr3 <= cdwr3;
end

always_ff @(posedge clk) 
if (rst) begin
	p2cdwr0 <= 1'b0;
end
else begin
	if (en2d)
		p2cdwr0 <= pcdwr0;
end
always_ff @(posedge clk) 
if (rst) begin
	p2cdwr1 <= 1'b0;
end
else begin
	if (en2d)
		p2cdwr1 <= pcdwr1;
end
always_ff @(posedge clk) 
if (rst) begin
	p2cdwr2 <= 1'b0;
end
else begin
	if (en2d)
		p2cdwr2 <= pcdwr2;
end
always_ff @(posedge clk) 
if (rst) begin
	p2cdwr3 <= 1'b0;
end
else begin
	if (en2d)
		p2cdwr3 <= pcdwr3;
end

always_ff @(posedge clk) 
if (rst) begin
	pwrra0 <= 10'b0;
//	pwrra1 <= 10'b0;
end
else begin
	if (en2d) begin
		pwrra0 <= wrra;
//		pwrra1 <= wrra1;
	end
end
always_ff @(posedge clk) 
if (rst) begin
	pwrrb0 <= 10'b0;
//	pwrrb1 <= 10'b0;
end
else begin
	if (en2d) begin
		pwrrb0 <= wrrb;
//		pwrrb1 <= wrrb1;
	end
end
always_ff @(posedge clk) 
if (rst) begin
	pwrrc0 <= 10'b0;
//	pwrrc1 <= 10'b0;
end
else begin
	if (en2d) begin
		pwrrc0 <= wrrc;
//		pwrrc1 <= wrrc1;
	end
end
always_ff @(posedge clk) 
if (rst) begin
	pwrrd0 <= 10'b0;
//	pwrrd1 <= 10'b0;
end
else begin
	if (en2d) begin
		pwrrd0 <= wrrd;
//		pwrrd1 <= wrrd1;
	end
end

always_ff @(posedge clk) 
if (rst) begin
	pwra_cp <= 4'b0;
end
else begin
	if (en2d)
		pwra_cp <= wra_cp;
end
always_ff @(posedge clk) 
if (rst) begin
	pwrb_cp <= 4'b0;
end
else begin
	if (en2d)
		pwrb_cp <= wrb_cp;
end
always_ff @(posedge clk) 
if (rst) begin
	pwrc_cp <= 4'b0;
end
else begin
	if (en2d)
		pwrc_cp <= wrc_cp;
end
always_ff @(posedge clk) 
if (rst) begin
	pwrd_cp <= 4'b0;
end
else begin
	if (en2d)
		pwrd_cp <= wrd_cp;
end

always_ff @(posedge clk) 
if (rst) begin
	p2wr0 <= 1'b0;
end
else begin
	if (en2d)
		p2wr0 <= pwr00;
end
always_ff @(posedge clk) 
if (rst) begin
	p2wr1 <= 1'b0;
end
else begin
	if (en2d)
		p2wr1 <= pwr10;
end
always_ff @(posedge clk) 
if (rst) begin
	p2wr2 <= 1'b0;
end
else begin
	if (en2d)
		p2wr2 <= pwr20;
end
always_ff @(posedge clk) 
if (rst) begin
	p2wr3 <= 1'b0;
end
else begin
	if (en2d)
		p2wr3 <= pwr30;
end

always_ff @(posedge clk) 
if (rst) begin
	p2wra <= 8'b0;
end
else begin
	if (en2d)
		p2wra <= pwra0;
end
always_ff @(posedge clk) 
if (rst) begin
	p2wrb <= 8'b0;
end
else begin
	if (en2d)
		p2wrb <= pwrb0;
end
always_ff @(posedge clk) 
if (rst) begin
	p2wrc <= 8'b0;
end
else begin
	if (en2d)
		p2wrc <= pwrc0;
end
always_ff @(posedge clk) 
if (rst) begin
	p2wrd <= 8'b0;
end
else begin
	if (en2d)
		p2wrd <= pwrd0;
end

always_ff @(posedge clk) 
if (rst) begin
	p2wrra <= 10'b0;
end
else begin
	if (en2d)
		p2wrra <= pwrra0;
end
always_ff @(posedge clk) 
if (rst) begin
	p2wrrb <= 10'b0;
end
else begin
	if (en2d)
		p2wrrb <= pwrrb0;
end
always_ff @(posedge clk) 
if (rst) begin
	p2wrrc <= 10'b0;
end
else begin
	if (en2d)
		p2wrrc <= pwrrc0;
end
always_ff @(posedge clk) 
if (rst) begin
	p2wrrd <= 10'b0;
end
else begin
	if (en2d)
		p2wrrd <= pwrrd0;
end

always_ff @(posedge clk) 
if (rst) begin
	p2wra_cp <= 4'b0;
end
else begin
	if (en2d)
		p2wra_cp <= pwra_cp;
end
always_ff @(posedge clk) 
if (rst) begin
	p2wrb_cp <= 4'b0;
end
else begin
	if (en2d)
		p2wrb_cp <= pwrb_cp;
end
always_ff @(posedge clk) 
if (rst) begin
	p2wrc_cp <= 4'b0;
end
else begin
	if (en2d)
		p2wrc_cp <= pwrc_cp;
end
always_ff @(posedge clk) 
if (rst) begin
	p2wrd_cp <= 4'b0;
end
else begin
	if (en2d)
		p2wrd_cp <= pwrd_cp;
end


// RAM gets updated if any port writes, or there is a new checkpoint.

always_ff @(posedge clk)
begin
	cpram_we = 1'b0;
	if (pe_alloc_chkpt1)
		cpram_we = 1'b1;
	/*
	else begin
		if (cdcmtav | cdcmtbv | cdcmtcv | cdcmtdv)
			cpram_we = TRUE;
		if (en2d & (cdwr0 | cdwr1 | cdwr2 | cdwr3))
			cpram_we = TRUE;
	end
	*/
end


// Add registers allocated since the branch miss instruction to the list of
// registers to be freed.

always_comb//ff @(posedge clk)
	restored = restore;

always_comb
begin
	// But not the registers allocated up to the branch miss
	if (restored) begin	//(restored) begin
		restore_list = avail_out;// & ~unavail;
//		restore_list = {Qupls4_pkg::PREGS{1'b0}};
	end
	else
		restore_list = {Qupls4_pkg::PREGS{1'b0}};
end

endmodule
