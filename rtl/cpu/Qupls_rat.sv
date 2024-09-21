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

module Qupls_rat(rst, clk, clk5x, ph4, en, nq, stallq, cndx_o, avail_i, restore, rob,
	stomp, miss_cp, wr0, wr1, wr2, wr3, inc_chkpt,
	wra_cp, wrb_cp, wrc_cp, wrd_cp, qbr0, qbr1, qbr2, qbr3,
	rn, rng, rnt, rnv,
	prn, rn_cp,
	prv, 
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
input clk5x;
input [4:0] ph4;
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
output cpu_types_pkg::pregno_t [NPORT-1:0] prn;	// physical register name
output reg [NPORT-1:0] prv;										// physical register valid
output reg [PREGS-1:0] restore_list;	// bit vector of registers to free on branch miss
output reg restored;


integer n,m,n1,n2,n3,n4;
reg cpram_we;
reg cpram_en;
reg cpram_en1;
reg new_chkpt1;
reg new_chkpt2;
localparam RAMWIDTH = AREGS*BANKS*RBIT+PREGS;
checkpoint_t cpram_out;
checkpoint_t cpram_wout;
checkpoint_t cpram_outr;
checkpoint_t cpram_in;
reg new_chkpt;							// new_chkpt map for current checkpoint
checkpt_ndx_t cndx, wndx;
assign cndx_o = cndx;
reg [PREGS-1:0] valid [0:BANKS-1][0:NCHECK-1];

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
	.enb(1'b1),
	.addrb(cndx),
	.doutb(cpram_out)
);

reg [7:0] cpv_wr;
checkpt_ndx_t [7:0] cpv_wc;
cpu_types_pkg::pregno_t [7:0] cpv_wa;
cpu_types_pkg::aregno_t [7:0] cpv_awa;
reg [7:0] cpv_i;
wire [NPORT-1:0] cpv_o;

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


Qupls_checkpoint_valid_ram4 #(.NRDPORT(NPORT)) ucpr2
(
	.rst(rst),
	.ph4(ph4),
	.clk5x(clk5x),
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
	.ra(prn),
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
generate begin : gRRN
	for (g = 0; g < NPORT; g = g + 1) begin
		always_comb
			prn[g] = rn[g]==wrd && wr3 ? wrrd :
							rn[g]==wrc && wr2 ? wrrc :
							rn[g]==wrb && wr1 ? wrrb :
							rn[g]==wra && wr0 ? wrra :
							cpram_out.regmap[rn[g]];

		// Unless it us a target register, we want the old unbypassed value.
		always_comb
			
			if (rnt[g]) begin
				// If an incoming target register is being marked invalid and it matches
				// the target register the valid status is begin fetched for, then 
				// return an invalid status. Bypass order is important.
				if (rn[g]==wrd && wr3)
					prv[g] = INV;//cpv_i[7];
				else if (rn[g]==wrc && wr2)
					prv[g] = INV;
				else if (rn[g]==wrb && wr1)
					prv[g] = INV;
				else if (rn[g]==wra && wr0)
					prv[g] = INV;
				else
					prv[g] = cpv_o[g];
			end
			else begin
			// Need to bypass if the source register is the same as the previous
			// target register in the same group of instructions.
				
				// If an incoming target register is being marked invalid and it matches
				// the register the valid status is begin fetched for, then 
				// return an invalid status.
				if (rn[g]==wrd && wr3)
					prv[g] = INV;
				else if (rn[g]==wrc && wr2)
					prv[g] = INV;
				else if (rn[g]==wrb && wr1)
					prv[g] = INV;
				else if (rn[g]==wra && wr0)
					prv[g] = INV;
				else
				case(rng[g])
				// First instruction of group, no bypass needed.
				3'd0:	prv[g] = cpv_o[g];
				// Second instruction of group, bypass only if first instruction target is same.
				3'd1:
					if (rn[g]==rn[3] && rnv[3])
						prv[g] = INV;
					else
						prv[g] = cpv_o[g];
				// Third instruction, check two previous ones.
				3'd2:
					if (rn[g]==rn[3] && rnv[3])
						prv[g] = INV;
					else if (rn[g]==rn[7] && rnv[7])
						prv[g] = INV;
					else
						prv[g] = cpv_o[g];
				// Fourth instruction, check three previous ones.						
				3'd3:
					begin
						if (rn[g]==rn[3] && rnv[3])
							prv[g] = INV;
						else if (rn[g]==rn[7] && rnv[7])
							prv[g] = INV;
						else if (rn[g]==rn[11] && rnv[11])
							prv[g] = INV;
						else
							prv[g] = cpv_o[g];
					end
				endcase
			end
	end
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
		if (/*(prn[n3]==8'd0 && rn[n3]!=7'd0) || */ qbr && nob==6'd15)
			stallq <= 1'b0;	// ToDo: Fix
	if (inc_chkpt|new_chkpt)
		stallq <= 1'b1;
	if (new_chkpt1)
		stallq <= 1'b0;
end


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
3'd0:	wr <= wr0;
3'd1:	wr <= wr1;
3'd2:	wr <= wr2;
3'd3:	wr <= wr3;
default:	wr <= 1'b0;
endcase
always_comb
case(wcnt)
3'd0:	aregno <= wra;
3'd1:	aregno <= wrb;
3'd2:	aregno <= wrc;
3'd3:	aregno <= wrd;
default:	aregno <= 8'd0;
endcase
always_comb
case(wcnt)
3'd0:	pregno <= wrra;
3'd1:	pregno <= wrrb;
3'd2:	pregno <= wrrc;
3'd3:	pregno <= wrrd;
default:	pregno <= 10'd0;
endcase

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
			$display("Qupls RAT: tgta %d reg %d replaced with %d.", wra, cpram_out.regmap[aregno], pregno);
		end
	end
	
	if (wr) begin
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

// RAM gets updated if any port writes, or there is a new checkpoint.
always_comb
 	cpram_we <= wr0|wr1|wr2|wr3|new_chkpt1;

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
