// ============================================================================
//        __
//   \\__/ o\    (C) 2024-2026  Robert Finch, Waterloo
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
// 52000 LUTs / 5400 FFs / 0 BRAMS / 165 MHz (512p regs, 16 checkpoints)
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
	qbr,
	
	// From reservation read requests: 
	rn,				// architectural register number
	rnv,			// reg number request valid
	rng,			// instruction number within group
	rn_cp, 		// checkpoint of requester
	st_prn,
	rd_cp,
	prn, 			// the mapped physical register number
	prv, 			// map valid indicator
	prn_i,		// register for valid bit lookup

	// From decode: destination register writes, one per instruction, four instructions.
	is_move,
	wr, 							// which port is aactive 
	wra,							// architectural register number
	wrra,							// physical register number
	wra_cp,			// checkpoint in use

	// Register file write signals.
	wrport0_v,		// which port is being written
	wrport0_aRt,	// the architectural register used
	wrport0_Rt,		// The physical register used
	wrport0_cp,		// The checkpoint
	wrport0_res,	// and the value written
	
	// Commit stage signals
	cmtav,			// which commits are valid
	cmtaiv,			// committing invalid instruction
	cmta_cp,		// commit checkpoint
	cmtaa,			// architectural register committed
	cmtap, 			// physical register committed.
	cmtaval,		// value committed
	cmtbr,															// committing a branch

	restore,			// signal to restore a checkpoint
	tags2free, freevals, backout,
	fcu_id,		// the ROB index of the instruction causing backout
	bo_wr, bo_areg, bo_preg, bo_nreg);
parameter MWIDTH = Qupls4_pkg::MWIDTH;
parameter NPORT = MWIDTH*4;
parameter NREG_RPORT = MWIDTH*4;
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
input [MWIDTH-1:0] qbr;		// enqueue branch, slot 0
input [Qupls4_pkg::PREGS-1:0] avail_i;				// list of available registers from renamer
input restore;										// checkpoint restore

input [MWIDTH-1:0] wr;

input [MWIDTH-1:0] is_move;
input checkpt_ndx_t [MWIDTH-1:0] wra_cp;
input cpu_types_pkg::aregno_t [MWIDTH-1:0] wra;		// architectural register
input cpu_types_pkg::pregno_t [MWIDTH-1:0] wrra;	// physical register
input [MWIDTH-1:0] wrport0_v;
input aregno_t [MWIDTH-1:0] wrport0_aRt;
input pregno_t [MWIDTH-1:0] wrport0_Rt;
input checkpt_ndx_t [MWIDTH-1:0] wrport0_cp;
input value_t [MWIDTH-1:0] wrport0_res;
input [MWIDTH-1:0] cmtav;							// commit valid
input [MWIDTH-1:0] cmtaiv;							// commit invalid instruction
input checkpt_ndx_t [MWIDTH-1:0] cmta_cp;
input cpu_types_pkg::aregno_t [MWIDTH-1:0] cmtaa;				// architectural register being committed
input cpu_types_pkg::pregno_t [MWIDTH-1:0] cmtap;				// physical register to commit
input value_t [MWIDTH-1:0] cmtaval;
input cmtbr;								// comitting a branch
input cpu_types_pkg::aregno_t [NPORT-1:0] rn;		// architectural register
input cpu_types_pkg::pregno_t st_prn;
input [2:0] rng [0:NPORT-1];
input [NPORT-1:0] rnv;
input checkpt_ndx_t [NPORT-1:0] rn_cp;
input checkpt_ndx_t [3:0] rd_cp;
output cpu_types_pkg::pregno_t [NPORT-1:0] prn;	// physical register name
input cpu_types_pkg::pregno_t [NREG_RPORT-1:0] prn_i;	// physical register name
output /*reglookup_t*/ reg [NREG_RPORT-1:0] prv;											// physical register valid
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

reg restored;
reg en2d;
reg [Qupls4_pkg::NCHECK-1:0] avail_chkpts;
checkpt_ndx_t [3:0] chkptn;
reg chkpt_stall;
reg backout_stall;
reg pbackout, pbackout2;
cpu_types_pkg::pregno_t [NPORT-1:0] next_prn;	// physical register name
cpu_types_pkg::pregno_t [NPORT-1:0] prnd;			// delayed physical register name
cpu_types_pkg::aregno_t [NPORT-1:0] prev_rn;
reg [MWIDTH-1:0] pwr00,p2wr0;
reg [MWIDTH-1:0] pwr01,p2wr01;
aregno_t [MWIDTH-1:0] pwra0,p2wra;
aregno_t [MWIDTH-1:0] pwra1,p2wra1;
pregno_t [MWIDTH-1:0] pwrra0,p2wrra;
pregno_t [MWIDTH-1:0] pwrra1,p2wrra1;
checkpt_ndx_t [MWIDTH-1:0] pwra_cp,p2wra_cp;

integer n,m,n1,n2,n3,n4,n5,n6,n7,n8,n9,n10,n11,n12,n13,kk,n14,n15,n16,n17;
reg [MWIDTH-1:0] br;
always_comb br = qbr;
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
Qupls4_pkg::checkpoint_t [MWIDTH-1:0] currentMap0;
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


// There are four "extra" bits in the data to make the size work out evenly.
// There is also an extra write bit. These are defaulted to prevent sim issues.

always_comb
	cpram_en = en2|pe_alloc_chkpt|cpram_we;
always_ff @(posedge clk)
	cpram_en1 <= cpram_en;

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

reg [MWIDTH*2+2-1:0] cpv_wr;
checkpt_ndx_t [MWIDTH*2+2-1:0] cpv_wc;
cpu_types_pkg::pregno_t [MWIDTH*2+2-1:0] cpv_wa;
cpu_types_pkg::aregno_t [MWIDTH*2+2-1:0] cpv_awa;
reg [MWIDTH*2+2-1:0] cpv_i;
wire [NPORT-1:0] cpv_o;
reg [MWIDTH-1:0] cdwr;
wire [MWIDTH-1:0] cdcmtav;
reg [MWIDTH-1:0] pcdwr0;
reg [MWIDTH-1:0] p2cdwr0;

always_comb
begin
	kk = 0;
	for (n13 = 0; n13 < MWIDTH; n13 = n13 + 1) begin
		cpv_wr[kk] = cdcmtav[n13];
		cpv_wc[kk] = cmta_cp[n13];
		cpv_wa[kk] = cmtap[n13];
		cpv_awa[kk] = cmtaa[n13];
		cpv_i[kk] = VAL;							// Commit: write VAL for register
		kk = kk + 1;
		cpv_wr[kk] = cdwr[n13];
		cpv_wc[kk] = wra_cp[n13];
		cpv_wa[kk] = wrra[n13];
		cpv_awa[kk] = wra[n13];				// Assign destination: write INV for register
		cpv_i[kk] = INV;
		kk = kk + 1;
	end
	cpv_wr[kk] = bo_wr;
	cpv_wc[kk] = cndx;
	cpv_wa[kk] = bo_preg;
	cpv_awa[kk] = bo_areg;
	cpv_i[kk] = VAL;
	kk = kk + 1;
	cpv_wr[kk] = 1'b0;
	cpv_wc[kk] = cndx;
	cpv_wa[kk] = bo_preg;
	cpv_awa[kk] = bo_areg;
	cpv_i[kk] = VAL;
end

reg stall_same_reg = 1'b0;	// same register marked valid and invalid at same time.

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
		foreach (wrport0_v[n14])
			if (wrport0_v[n14])
				currentRegvalid[wrport0_Rt[n14]] = VAL;

		if (en2 & ~stall_same_reg) begin
			for (n14 = 0; n14 < MWIDTH; n14 = n14 + 1)
				if (pwr00[n14])
					currentRegvalid[pwrra0[n14]] = INV;
		end
		
		foreach (cmtap[n14])
			if (cmtaiv[n14])
				currentRegvalid[cmtap[n14]] = VAL;
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

// number of outstanding branches
reg [5:0] nob;
wire qbr_ok = nq && |qbr && nob < 6'd15;
wire bypass_en = !pbackout;
reg [NPORT-1:0] bypass_pwrra00 [0:MWIDTH-1];
reg [NPORT-1:0] bypass_pwrra01 [0:MWIDTH-1];
reg [NPORT-1:0] bypass_p2wrra0 [0:MWIDTH-1];
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
					bypass_pwrra00[0][g] = (rn[g]==pwra0[0]) && pwr00[0] /*&& rn_cp[g]==pwra_cp*/;
//					bypass_pwrra01[g] = (rn[g]==pwra1) && pwr01 /*&& rn_cp[g]==pwra_cp*/;
					bypass_pwrra00[1][g] = (rn[g]==pwra0[1]) && pwr00[1] /*&& rn_cp[g]==pwrb_cp*/;
//					bypass_pwrrb01[g] = (rn[g]==pwrb1) && pwr11 /*&& rn_cp[g]==pwrb_cp*/;
					bypass_pwrra00[2][g] = (rn[g]==pwra0[2]) && pwr00[2] /*&& rn_cp[g]==pwrc_cp*/;
//					bypass_pwrrc01[g] = (rn[g]==pwrc1) && pwr21 /*&& rn_cp[g]==pwrc_cp*/;
					bypass_pwrra00[3][g] = (rn[g]==pwra0[3]) && pwr00[3] /*&& rn_cp[g]==pwrd_cp*/;
//					bypass_pwrrd01[g] = (rn[g]==pwrd1) && pwr31 /*&& rn_cp[g]==pwrd_cp*/;

					bypass_p2wrra0[1][g] =  (rn[g]==p2wra[3]) && p2wr0[3] /*&& rn_cp[g]==p2wrd_cp*/;
					bypass_p2wrra0[1][g] =	(rn[g]==p2wra[2]) && p2wr0[2] /*&& rn_cp[g]==p2wrc_cp*/;
					bypass_p2wrra0[1][g] =	(rn[g]==p2wra[1]) && p2wr0[1] /*&& rn_cp[g]==p2wrb_cp*/;
					bypass_p2wrra0[1][g] =	(rn[g]==p2wra[0]) && p2wr0[0] /*&& rn_cp[g]==p2wra_cp*/;
					
					// Bypass only for previous instruction in same group
					case(rng[g])
					3'd0:	
						begin
							next_prn[g] =
								// No intra-group bypass needed
								// Intergroup bypass, needed as the map RAM has not updated in
								// time for the next group of instructions.
								(bypass_pwrra00[3][g] && bypass_en) ? pwrra0[3] :
//								(bypass_pwrrd01[g] && bypass_en) ? pwrrd1 :
								(bypass_pwrra00[2][g] && bypass_en) ? pwrra0[2] :
//								(bypass_pwrrc01[g] && bypass_en) ? pwrrc1 :
								(bypass_pwrra00[1][g] && bypass_en) ? pwrra0[1] :
//								(bypass_pwrrb01[g] && bypass_en) ? pwrrb1 :
								(bypass_pwrra00[0][g] && bypass_en) ? pwrra0[0] :
//								(bypass_pwrra01[g] && bypass_en) ? pwrra1 :
								currentMap.regmap[rn[g]];
													/*
													(bypass_p2wrrd0[g] && bypass_en) ? p2wrrd :
													(bypass_p2wrrc0[g] && bypass_en) ? p2wrrc :
													(bypass_p2wrrb0[g] && bypass_en) ? p2wrrb :
													(bypass_p2wrra0[g] && bypass_en) ? p2wrra :
													*/
						end
					3'd1: if (MWIDTH > 1)
							next_prn[g] = 
								// Intra group bypass
								(rn[g]==wra && wr[0]) ? wrra :
//								(rn[g]==wra1 && wr01) ? wrra1 :
								// Intergroup bypass, needed as the map RAM has not updated in
								// time for the next group of instructions.
								(bypass_pwrra00[3][g] && bypass_en) ? pwrra0[3] :
//								(bypass_pwrrd01[g] && bypass_en) ? pwrrd1 :
								(bypass_pwrra00[2][g] && bypass_en) ? pwrra0[2] :
//								(bypass_pwrrc01[g] && bypass_en) ? pwrrc1 :
								(bypass_pwrra00[1][g] && bypass_en) ? pwrra0[1] :
//								(bypass_pwrrb01[g] && bypass_en) ? pwrrb1 :
								(bypass_pwrra00[0][g] && bypass_en) ? pwrra0[0] :
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
					3'd2: 	if (MWIDTH > 2)
							next_prn[g] = 
								// Intra group bypass
								(rn[g]==wra[1] && wr[1]) ? wrra[1] :
//								(rn[g]==wrb1 && wr11) ? wrrb1 :
								(rn[g]==wra[0] && wr[0]) ? wrra[0] :
//								(rn[g]==wra1 && wr01) ? wrra1 :
								// Intergroup bypass, needed as the map RAM has not updated in
								// time for the next group of instructions.
								(bypass_pwrra00[3][g] && bypass_en) ? pwrra0[3] :
//								(bypass_pwrrd01[g] && bypass_en) ? pwrrd1 :
								(bypass_pwrra00[2][g] && bypass_en) ? pwrra0[2] :
//								(bypass_pwrrc01[g] && bypass_en) ? pwrrc1 :
								(bypass_pwrra00[1][g] && bypass_en) ? pwrra0[1] :
//								(bypass_pwrrb01[g] && bypass_en) ? pwrrb1 :
								(bypass_pwrra00[0][g] && bypass_en) ? pwrra0[0] :
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
					3'd3:	if (MWIDTH > 3)
						next_prn[g] = 
							// Intra group bypass
							(rn[g]==wra[2] && wr[2]) ? wrra[2] :
//							(rn[g]==wrc1 && wr21) ? wrrc1 :
							(rn[g]==wra[1] && wr[1]) ? wrra[1] :
//							(rn[g]==wrb1 && wr11) ? wrrb1 :
							(rn[g]==wra[0] && wr[0]) ? wrra[0] :
//							(rn[g]==wra1 && wr01) ? wrra1 :
							// Intergroup bypass, needed as the map RAM has not updated in
							// time for the next group of instructions.
								(bypass_pwrra00[3][g] && bypass_en) ? pwrra0[3] :
//								(bypass_pwrrd01[g] && bypass_en) ? pwrrd1 :
								(bypass_pwrra00[2][g] && bypass_en) ? pwrra0[2] :
//								(bypass_pwrrc01[g] && bypass_en) ? pwrrc1 :
								(bypass_pwrra00[1][g] && bypass_en) ? pwrra0[1] :
//								(bypass_pwrrb01[g] && bypass_en) ? pwrrb1 :
								(bypass_pwrra00[0][g] && bypass_en) ? pwrra0[0] :
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
			// If there is a pipeline bubble. The instruction will be a NOP. Mark all
			// register ports as valid.
			begin
				prv[g] = currentRegvalid[prn_i[g]];
				//if (en2) 
				if (1) begin			
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
							prv[g] = currentRegvalid[prn[g]];
						*/
						
						case(rng[g])
						// First instruction of group, no bypass needed.
						3'd0:	
						
							if (prn[g]==cmtap[3] && cmtav[3])
								prv[g] = VAL;
							else if (prn[g]==cmtap[2] && cmtav[2])
								prv[g] = VAL;
							else if (prn[g]==cmtap[1] && cmtav[1])
								prv[g] = VAL;
							else if (prn[g]==cmtap[0] && cmtav[0])
								prv[g] = VAL;
							
							
							else if (prn[g]==pwrra0[3] && pwr00[3])
								prv[g] = INV;
							else if (prn[g]==pwrra0[2] && pwr00[2])
								prv[g] = INV;
							else if (prn[g]==pwrra0[1] && pwr00[1])
								prv[g] = INV;
							else if (prn[g]==pwrra0[0] && pwr00[0])
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
														
								prv[g] = currentRegvalid[prn_i[g]];//cpv_o[g];
						// Second instruction of group, bypass only if first instruction target is same.
						3'd1:
						if (MWIDTH > 1) begin							
							if (prn[g]==bo_nreg && bo_wr)
								prv[g] = VAL;
							else if (prn[g]==wrport0_Rt[0] && wrport0_v[0])
								prv[g] = VAL;					
								
							else if (prn[g]==cmtap[3] && cmtav[3])
								prv[g] = VAL;
							else if (prn[g]==cmtap[2] && cmtav[2])
								prv[g] = VAL;
							else if (prn[g]==cmtap[1] && cmtav[1])
								prv[g] = VAL;
							else if (prn[g]==cmtap[0] && cmtav[0])
								prv[g] = VAL;
							
							
							else if (prn[g]==pwrra0[3] && pwr00[3])
								prv[g] = INV;
							else if (prn[g]==pwrra0[2] && pwr00[2])
								prv[g] = INV;
							else if (prn[g]==pwrra0[1] && pwr00[1])
								prv[g] = INV;
							else if (prn[g]==pwrra0[0] && pwr00[0])
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
						if (MWIDTH > 2) begin
							if (prn[g]==bo_nreg && bo_wr)
								prv[g] = VAL;
							else if (prn[g]==wrport0_Rt[1] && wrport0_v[1])
								prv[g] = VAL;					
							else if (prn[g]==wrport0_Rt[0] && wrport0_v[0])
								prv[g] = VAL;					
								
								
							else if (prn[g]==cmtap[3] && cmtav[3])
								prv[g] = VAL;
							else if (prn[g]==cmtap[2] && cmtav[2])
								prv[g] = VAL;
							else if (prn[g]==cmtap[1] && cmtav[1])
								prv[g] = VAL;
							else if (prn[g]==cmtap[0] && cmtav[0])
								prv[g] = VAL;
							
							
							else if (prn[g]==pwrra0[3] && pwr00[3])
								prv[g] = INV;
							else if (prn[g]==pwrra0[2] && pwr00[2])
								prv[g] = INV;
							else if (prn[g]==pwrra0[1] && pwr00[1])
								prv[g] = INV;
							else if (prn[g]==pwrra0[0] && pwr00[0])
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
						if (MWIDTH > 3) begin
							if (prn[g]==bo_nreg && bo_wr)
								prv[g] = VAL;
							else if (prn[g]==wrport0_Rt[2] && wrport0_v[2])
								prv[g] = VAL;					
							else if (prn[g]==wrport0_Rt[1] && wrport0_v[1])
								prv[g] = VAL;					
							else if (prn[g]==wrport0_Rt[0] && wrport0_v[0])
								prv[g] = VAL;					
							
							else if (prn[g]==cmtap[3] && cmtav[3])
								prv[g] = VAL;
							else if (prn[g]==cmtap[2] && cmtav[2])
								prv[g] = VAL;
							else if (prn[g]==cmtap[1] && cmtav[1])
								prv[g] = VAL;
							else if (prn[g]==cmtap[0] && cmtav[0])
								prv[g] = VAL;
							
							else if (prn[g]==pwrra0[3] && pwr00[3])
								prv[g] = INV;
							else if (prn[g]==pwrra0[2] && pwr00[2])
								prv[g] = INV;
							else if (prn[g]==pwrra0[1] && pwr00[1])
								prv[g] = INV;
							else if (prn[g]==pwrra0[0] && pwr00[0])
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
		case(MWIDTH)
		1:
			if (prn[NPORT-1]==cmtap[0] && cmtav[0])
				prv[NPORT-1] = VAL;
			else
				prv[NPORT-1] = currentRegvalid[prn[NPORT-1]];//cpv_o[g];
		2:
			if (prn[NPORT-1]==cmtap[1] && cmtav[1])
				prv[NPORT-1] = VAL;
			else if (prn[NPORT-1]==cmtap[1] && cmtav[0])
				prv[NPORT-1] = VAL;
			else
				prv[NPORT-1] = currentRegvalid[prn[NPORT-1]];//cpv_o[g];
		3:
			if (prn[NPORT-1]==cmtap[2] && cmtav[2])
				prv[NPORT-1] = VAL;
			else if (prn[NPORT-1]==cmtap[1] && cmtav[1])
				prv[NPORT-1] = VAL;
			else if (prn[NPORT-1]==cmtap[1] && cmtav[0])
				prv[NPORT-1] = VAL;
			else
				prv[NPORT-1] = currentRegvalid[prn[NPORT-1]];//cpv_o[g];
		default:
			if (prn[NPORT-1]==cmtap[3] && cmtav[3])
				prv[NPORT-1] = VAL;
			else if (prn[NPORT-1]==cmtap[2] && cmtav[2])
				prv[NPORT-1] = VAL;
			else if (prn[NPORT-1]==cmtap[1] && cmtav[1])
				prv[NPORT-1] = VAL;
			else if (prn[NPORT-1]==cmtap[1] && cmtav[0])
				prv[NPORT-1] = VAL;
			else
				prv[NPORT-1] = currentRegvalid[prn[NPORT-1]];//cpv_o[g];
		endcase
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
reg [MWIDTH-1:0] cmtav1;
checkpt_ndx_t [MWIDTH-1:0]cndxa1;
pregno_t [MWIDTH-1:0] cmtap1;
wire [MWIDTH-1:0] cd_cmtav;

// If the same value is going to the same register in two consecutive clock cycles,
// only do one update. Prevents a register from being released for use too soon.
generate begin : gChangeDet1
	for (g = 0; g < MWIDTH; g = g + 1)
		change_det #($bits(aregno_t)+$bits(pregno_t)+$bits(value_t)+1) ucmta1 (.rst(rst), .clk(clk), .ce(1'b1), .i({cmtav[g]|cmtaiv[g],cmtaa[g],cmtap[g],cmtaval[g]}), .cd(cd_cmtav[g]));
end
endgenerate

// Make the write inputs sticky until en2 occurs.
wire [MWIDTH-1:0] cd_wr;

// We cannot have the same register tag being assigned to two different
// architectural registers at the same time. The same register cannot be
// assigned two clock cycles in a row. Only map once.
generate begin : gChangeDet
	for (g = 0; g < MWIDTH; g = g + 1)
		change_det #($bits(aregno_t)+$bits(pregno_t)+1) uwrcda1 (.rst(rst), .clk(clk), .ce(en2d), .i({wr[0],wra[0],wrra[0]}), .cd(cd_wr[0]));
end
endgenerate

//change_det #($bits(aregno_t)+$bits(pregno_t)+1) uwrcdb1 (.rst(rst), .clk(clk), .ce(en2d), .i({wr[1],wrb,wrrb}), .cd(cd_wr1));
//change_det #($bits(aregno_t)+$bits(pregno_t)+1) uwrcdc1 (.rst(rst), .clk(clk), .ce(en2d), .i({wr[2],wrc,wrrc}), .cd(cd_wr2));
//change_det #($bits(aregno_t)+$bits(pregno_t)+1) uwrcdd1 (.rst(rst), .clk(clk), .ce(en2d), .i({wr[3],wrd,wrrd}), .cd(cd_wr3));

always_comb//ff @(posedge clk)
if (rst)
	en2d = 1'b0;
else
	en2d = en2;

always_ff @(posedge clk)
if (rst) begin
	for (n15 = 0; n15 < MWIDTH; n15 = n15 + 1) begin
		cmtav1[n15] <= FALSE;
		cndxa1[n15] <= 4'd0;
		cmtap1[n15] <= 9'd0;
	end
end
else begin
	for (n15 = 0; n15 < MWIDTH; n15 = n15 + 1) begin
		cmtav1[n15] <= cmtav[n15];
		cndxa1[n15] <= cndx[n15];
		cmtap1[n15] <= cmtap[n15];
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
	for (n16 = 0; n16 < MWIDTH; n16 = n16 + 1)
		tags2free[n16] <= {$bits(pregno_t){1'b0}};
end
else begin
	for (n16 = 0; n16 < MWIDTH; n16 = n16 + 1)
		tags2free[n16] <= {$bits(pregno_t){1'b0}};
	
	// For invalid frees we do not want to push the free pipeline.
	for (n16 = 0; n16 < MWIDTH; n16 = n16 + 1)
		if (cdcmtav[n16])
			tags2free[n16] <= historyMap.regmap[cmtaa[n16]];
	if (bo_wr)
		tags2free[0] <= bo_nreg;
end

always_ff @(posedge clk)
if (rst)
	freevals <= 4'd0;
else begin
	for (n17 = 1; n17 < MWIDTH; n17 = n17 + 1)
		freevals[n17] <= cdcmtav[n17];
	freevals[0] <= cdcmtav[0]|bo_wr;
end

always_comb
for (n9 = 0; n9 < MWIDTH; n9 = n9 + 1)
	cdwr[n9] = cd_wr[n9] & wr[n9];

generate begin : gCdCmt
	for (g = 0; g < MWIDTH; g = g + 1)
assign cdcmtav[g] = cd_cmtav[g] & (cmtav[g]|cmtaiv[g]);
end
endgenerate

wire pe_bk, ne_bk;
edge_det uedbckout1 (.rst(rst), .clk(clk), .ce(1'b1), .i(backout_state==2'd1), .pe(pe_bk), .ne(ne_bk), .ee());

// Set the checkpoint RAM input.
// For checkpoint establishment the current read value is desired.
// For normal operation the write output port is used.

// For input to the checkpoint ram the updated map before the end of the clock
// cycle is needed.

always_comb
if (rst) begin
	nextCurrentMap = {$bits(Qupls4_pkg::reg_map_t){1'b0}};
	nextHistoryMap = {$bits(Qupls4_pkg::reg_map_t){1'b0}};
end
else begin
	nextCurrentMap = currentMap;
	nextHistoryMap = historyMap;

	// The branch instruction itself might need to update the checkpoint info.
	// Even if a checkpoint is being allocated, we want to record new maps.
	if (en2) begin
		foreach (wrra[n10])
			if (wr[n10]) begin
				if (is_move[n10])
					nextCurrentMap.regmap[wra[n10]] = next_prn[n10*4+1];
				else
					nextCurrentMap.regmap[wra[n10]] = wrra[n10];
			end
	end

	// Shift the physical register into a second spot.
	// Note that .regmap[] ahould be the same as the physical register at commit.
	// It is a little less logic just to use the physical register at commit,
	// rather than referencing .regmap[]
	foreach (cmtap[n10])
		if (cdcmtav[n10])
			nextHistoryMap.regmap[cmtaa[n10]] = cmtap[n10];

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

// Diags.
always_ff @(posedge clk)
if (Qupls4_pkg::SIM) begin
	if (TRUE||en2) begin
		if (bo_wr)
			$display("Qupls4 CPU RAT: backout %d restored to %d", currentMap.regmap[bo_areg], bo_preg);

		for (n11 = 0; n11 < MWIDTH; n11 = n11 + 1)
			if (cd_wr[n11] & wr[n11])
				$display("Qupls4 CPU RAT: tgta %d reg %d replaced with %d.", wra[n11], currentMap.regmap[wra[n11]], wrra[n11]);
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

generate begin : gPwr
	for (g = 0; g < MWIDTH; g = g + 1) begin
		always_ff @(posedge clk) 
			if (rst)
				pwr00[g] <= 1'b0;
			else begin
				if (en2d)
					pwr00[g] <= wr[g] && !pbackout;
			end
		always_ff @(posedge clk) 
		if (rst)
			pwra0[g] <= 8'b0;
		else begin
			if (en2d)
				pwra0[g] <= wra[g];
		end
		always_ff @(posedge clk) 
		if (rst)
			pcdwr0[g] <= 1'b0;
		else begin
			if (en2d)
				pcdwr0[g] <= cdwr[g];
		end
		always_ff @(posedge clk) 
		if (rst)
			p2cdwr0[g] <= 1'b0;
		else begin
			if (en2d)
				p2cdwr0[g] <= pcdwr0[g];
		end
		always_ff @(posedge clk) 
		if (rst)
			pwrra0[g] <= 10'b0;
		else begin
			if (en2d) begin
				pwrra0[g] <= wrra[g];
			end
		end
		always_ff @(posedge clk) 
		if (rst)
			pwra_cp[g] <= 4'b0;
		else begin
			if (en2d)
				pwra_cp[g] <= wra_cp[g];
		end
		always_ff @(posedge clk) 
		if (rst)
			p2wr0[g] <= 1'b0;
		else begin
			if (en2d)
				p2wr0[g] <= pwr00[g];
		end
		always_ff @(posedge clk) 
		if (rst)
			p2wra[g] <= 8'b0;
		else begin
			if (en2d)
				p2wra[g] <= pwra0[g];
		end
		always_ff @(posedge clk) 
		if (rst)
			p2wrra[g] <= 10'b0;
		else begin
			if (en2d)
				p2wrra[g] <= pwrra0[g];
		end
		always_ff @(posedge clk) 
		if (rst)
			p2wra_cp[g] <= 4'b0;
		else begin
			if (en2d)
				p2wra_cp[g] <= pwra_cp[g];
		end
	end
end
endgenerate


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

always_ff @(posedge clk)
	restored <= restore;

endmodule
