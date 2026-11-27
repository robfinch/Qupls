// ============================================================================
//        __
//   \\__/ o\    (C) 2024-2026  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
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
// 55900 LUTs / 11500 FFs / 0 BRAMs / 160 MHz
// 45100 LUTs / 11300 FFs / 0 BRAMS / 100 MHz (1312 phys. regs)
// 5200 LUTs / 8100 FFs / 0 BRAMS / 120 MHZ (160 phys. regs)
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls5_pkg::*;

//`define SUPPORT_RAT	1

module Qupls5_pipeline_ren(
	rst, clk, clk5x, ph4, en, nq, restore,
	unavail_list,
	chkpt_amt, tail0, rob, avail_reg, branch_resolved,
	stomp_ren, live_stream, flush_dec, flush_ren,
//	arn, arng, arnv,
	rn_cp, prn_i, prnv,
	Rt0_ren, Rt0_renv, 
	pg_dec, pg_ren,

	wrport0_v,
	wrport0_aRt,
	wrport0_Rt,
	wrport0_res,
	wrport0_cp,

	cmtav, cmtaa,
	cmtap, cmta_cp,
	cmtaiv, cmtaval,

	cmtbr,
	tags2free, freevals, backout, fcu_id,
	bo_wr, bo_areg, bo_preg, bo_nreg,
	rat_stallq,
	alloc_chkpt, cndx, rcndx, miss_cp,
	pwr00, pwrra0
);
parameter SUPPORT_RAT = Qupls5_pkg::SUPPORT_RAT;
parameter MWIDTH = Qupls5_pkg::MWIDTH;
parameter NREG_RPORT = Qupls5_pkg::NREG_RPORTS;
parameter NREG_WPORT = Qupls5_pkg::NREG_WPORTS;
localparam NRENAME = MWIDTH*6;
input rst;
input clk;
input clk5x;
input [4:0] ph4;
input en;
input flush_dec;
output reg flush_ren;
input nq;
input restore;
input [Qupls5_pkg::PREGS-1:0] unavail_list;
input [2:0] chkpt_amt;
input rob_ndx_t tail0;
input Qupls5_pkg::rob_entry_t [Qupls5_pkg::ROB_ENTRIES-1:0] rob;
input [Qupls5_pkg::PREGS-1:0] avail_reg;
input branch_resolved;
input stomp_ren;
input pc_stream_t live_stream;
//input aregno_t [NPORT-1:0] arn;
//input [2:0] arng [0:NPORT-1];
//input [NPORT-1:0] arnv;
input checkpt_ndx_t [NRENAME-1:0] rn_cp;
input pregno_t [NRENAME-1:0] prn_i;
output [NRENAME-1:0] prnv;
input Qupls5_pkg::pipeline_group_reg_t pg_dec;
output Qupls5_pkg::pipeline_group_reg_t pg_ren;
output pregno_t [MWIDTH-1:0] Rt0_ren;
output reg [MWIDTH-1:0] Rt0_renv;
input [NREG_WPORT-1:0] wrport0_v;
input aregno_t [NREG_WPORT-1:0] wrport0_aRt;
input pregno_t [NREG_WPORT-1:0] wrport0_Rt;
input value_t [NREG_WPORT-1:0] wrport0_res;
input checkpt_ndx_t [NREG_WPORT-1:0] wrport0_cp;
input [MWIDTH-1:0] cmtav;
input [MWIDTH-1:0] cmtaiv;
input aregno_t [MWIDTH-1:0] cmtaa;
input pregno_t [MWIDTH-1:0] cmtap;
input checkpt_ndx_t [MWIDTH-1:0] cmta_cp;
input value_t [MWIDTH-1:0] cmtaval;
input cmtbr;
output pregno_t [3:0] tags2free;
output [3:0] freevals;
input backout;
input rob_ndx_t fcu_id;
output bo_wr;
output aregno_t bo_areg;
output pregno_t bo_preg;
output pregno_t bo_nreg;
output rat_stallq;
input alloc_chkpt;
input checkpt_ndx_t cndx;
input checkpt_ndx_t [3:0] rcndx;
input checkpt_ndx_t miss_cp;
// Registers being made invalid
output [MWIDTH-1:0] pwr00;
output pregno_t [MWIDTH-1:0] pwrra0;

genvar g;
integer jj,n1,n2,n3,n5,n6,n7,n8,n9,nn,n10;
aregno_t [MWIDTH-1:0] aRd_dec;
pregno_t [MWIDTH-1:0] pRd_dec;
wire [MWIDTH-1:0] pRd_decv;
reg [MWIDTH-1:0] aRd_decv;
reg [MWIDTH-1:0] is_move;
aregno_t [MWIDTH-1:0] aRd_decr;
wire rat_stallq1;
wire ns_stall;
reg [MWIDTH-1:0] wr;
wire [MWIDTH-1:0] pwr;
assign rat_stallq = rat_stallq1|ns_stall;


always_comb
	foreach (pg_dec.pr[n1])
		aRd_dec[n1] = pg_dec.pr[n1].op.decbus.Rd;

// Instructions that have aleady been stomped on before the rename stage do
// not need register renames. They are already done.
// Disable renaming for non-dispatchable instructions at this point.
always_comb
	foreach (pg_dec.pr[n1])
		aRd_decv[n1] = pg_dec.pr[n1].op.decbus.Rdv & ~pg_dec.pr[n1].stomped;

always_comb
	foreach (pg_dec.pr[n1])
		is_move[n1] = pg_dec.pr[n1].op.decbus.move;

always_ff @(posedge clk)
if (rst)
	flush_ren <= 1'b0;
else begin
	if (en) 
		flush_ren <= flush_dec;
end

generate begin : gRt_ren
	for (g = 0; g < MWIDTH; g = g + 1) begin
		always_ff @(posedge clk)
		if (rst)
			Rt0_ren[g] <= 9'd0;
		else begin
			if (en) 
				Rt0_ren[g] <= pRd_dec[g];
		end
		always_ff @(posedge clk)
			if (rst)
				Rt0_renv[g] <= 1'b0;
			else if (en)
				Rt0_renv[g] <= pRd_decv[g] & aRd_decv[g];
	end
end
endgenerate

reg [NRENAME-1:0] arnv;
reg [2:0] arng [0:NRENAME-1];
aregno_t [NRENAME-1:0] arn;
pregno_t [NRENAME-1:0] prn;

always_comb
begin
	arnv = {MWIDTH*6{1'b1}};
	foreach (pg_dec.pr[n8]) begin
		arn[n8*6+0] = pg_dec.pr[n8].op.decbus.Rs1;
		arn[n8*6+1] = pg_dec.pr[n8].op.decbus.Rs2;
		arn[n8*6+2] = pg_dec.pr[n8].op.decbus.Rs3;
		arn[n8*6+3] = pg_dec.pr[n8].op.decbus.Rs4;
		arn[n8*6+4] = pg_dec.pr[n8].op.decbus.Rm;
		arn[n8*6+5] = pg_dec.pr[n8].op.decbus.Rd;
		arng[n8*6+0] = n8;
		arng[n8*6+1] = n8;
		arng[n8*6+2] = n8;
		arng[n8*6+3] = n8;
		arng[n8*6+4] = n8;
		arng[n8*6+5] = n8;
	end
end

always_comb//ff @(posedge clk)
if (rst)
	foreach(aRd_dec[n10])
		aRd_decr[n10] <= 9'd0;
else begin
	if (en) 
		foreach(aRd_dec[n10])
			aRd_decr[n10] <= aRd_dec[n10];
end

// ToDo: fix this.
// write for only a single cycle. But allow pipelined writes.
reg en3;
always_ff @(posedge clk)
	en3 <= en;
generate begin : gEd1
	for (g = 0; g < MWIDTH; g = g + 1)
edge_det ued1 (.rst(rst), .clk(clk), .ce(1'b1), .i(pRd_decv[g]), .pe(pwr[g]), .ne(), .ee());
end
endgenerate


checkpt_ndx_t cndx1, cndx2, cndx3;
assign cndx1 = cndx;
assign cndx2 = cndx;
assign cndx3 = cndx;

reg [MWIDTH-1:0] qbr;
always_comb
foreach (qbr[n6])
	qbr[n6] = pg_dec.pr[n6].op.decbus.br|pg_dec.pr[n6].op.decbus.cjb;

generate begin : gRAT
	if (SUPPORT_RAT) begin
Qupls5_reg_name_supplier9 uns4
(
	.rst(rst),
	.clk(clk),
	.en(en),
	.aregno(aRd_dec),
	.tags2free(tags2free),
	.freevals(freevals),
	.ns_alloc_req(aRd_decv & ~is_move),
	.ns_dstreg(pRd_dec),
	.ns_dstregv(pRd_decv),
	.avail(),							// available registers list
	.stall(ns_stall)
);

Qupls5_rat2
#(
	.MWIDTH(MWIDTH),
	.NRENAME(NRENAME),
	.NREG_RPORT(NREG_RPORT),
	.NREG_WPORT(NREG_WPORT)
)
urat1
(	
	.rst(rst),
	.clk(clk),
	.en(en),
	.en2(en),
	.nq(nq),
	.alloc_chkpt(alloc_chkpt),
	.cndx(cndx),
	.miss_cp(miss_cp),
	.stall(rat_stallq1),
	.tail(tail0),
	.rob(rob),
	.avail_i(avail_reg),
	.restore(restore),
	.qbr(qbr),
	.rn(arn),
	.rng(arng),
	.rnv(arnv),
	.rn_cp(rn_cp),
	.prn(prn),
	.prn_i(prn_i),
	.prv(prnv),
	.is_move(is_move),
	.wr(pwr),		// && !stomp0 && ~pg_ren.pr[0].decbus.Rtz),
	.wra(aRd_dec),
	.wrra(pRd_dec),
	.wra_cp(rcndx),
	.wrport_v(wrport0_v),
	.wrport_aRt(wrport0_aRt),
	.wrport_Rt(wrport0_Rt),
	.wrport_cp(wrport0_cp),
	.wrport_res(wrport0_res),
	.cmtav(cmtav),
	.cmtaiv(cmtaiv),
	.cmtaa(cmtaa),
	.cmtap(cmtap),
	.cmtaval(cmtaval),
	.cmta_cp(cmta_cp),
	.cmtbr(cmtbr),
	.tags2free(tags2free),
	.freevals(freevals),
	.backout(backout),
	.fcu_id(fcu_id),
	.bo_wr(bo_wr),
	.bo_areg(bo_areg),
	.bo_preg(bo_preg),
	.bo_nreg(bo_nreg),
	.pwr00(pwr00),
	.pwrra0(pwrra0)	
);
end
else begin
	assign rat_stallq = FALSE;
	assign cndx0 = 4'd0;
	assign bo_wr = FALSE;
	assign bo_areg = 8'd0;
	assign bo_preg = 9'd0;
	assign prnv = 24'hFFFFFF;
	always_ff @(posedge clk)
	if (rst) begin
		foreach (prn[n5])
			prn[n5] <= 9'd0;
	end
	else begin
		if (en)
		begin
			foreach (prn[n5])
				prn[n5] <= {1'b0,arn[n5]};
		end
	end
	/*
	always_comb
	if (rst) begin
		for (n6 = 0; n6 < 24; n6 = n6 + 1)
			prn[n6] = 9'd0;
	end
	else begin
		//if (advance_pipeline_seg2)
		begin
			for (n6 = 0; n6 < 24; n6 = n6 + 1)
				prn[n6] = prn1[n6];
		end
	end
	*/
end
end
endgenerate

always_ff @(posedge clk)
if (rst) begin
	pg_ren <= {$bits(Qupls5_pkg::pipeline_group_reg_t){1'b0}};
	pg_ren.hdr <= {$bits(Qupls5_pkg::pipeline_group_hdr_t){1'b0}};
	foreach (pg_ren.pr[n7]) begin
		pg_ren.pr[n7] <= {$bits(Qupls5_pkg::rob_entry_t){1'b0}};
		pg_ren.pr[n7].v <= VAL;
		pg_ren.pr[n7].ip_stream <= 7'd1;
		pg_ren.pr[n7].op <= Qupls5_pkg::fnPregNop();
		pg_ren.pr[n7].exc <= Qupls5_pkg::FLT_NONE;
		pg_ren.pr[n7].stomped <= TRUE;
		pg_ren.pr[n7].done <= 2'b11;
	end
end
else begin
	if (en) begin
		pg_ren <= pg_dec;
		pg_ren.hdr.cndx <= cndx;
		pg_ren.hdr.cndxv <= VAL;
		if (stomp_ren)
			pg_ren.hdr.v <= INV;
		pg_ren.pr[0] <= pg_dec.pr[0];
			// These still need to update the regfile.
//			if (pg_ren.pr[0].op.decbus.bsr|pg_ren.pr[0].op.decbus.jsr)
//				pg_ren.pr[0].done <= 2'b11;

		// Renaming has been done, so it is necessary to turn instructions into
		// copy-targets to preserve the register values. That means we still 
		// want to dispatch and execute the instruction. Therefore, the
		// instruction is not marked invalid.
		if (stomp_ren) begin
			pg_ren.pr[0].stomped <= TRUE;
			pg_ren.pr[0].op.decbus.cpytgt <= TRUE;
		end
		if (~pg_dec.pr[0].v)
			tStomp(0);
		// Even if stomped on, we want to retain the destination register for
		// copy purposes.
		pg_ren.pr[0].op.nRd <= pRd_dec[0];
		pg_ren.pr[0].op.pRs1 <= prn[0];
		pg_ren.pr[0].op.pRs2 <= prn[1];
		pg_ren.pr[0].op.pRs3 <= prn[2];
		pg_ren.pr[0].op.pRs4 <= prn[3];
		pg_ren.pr[0].op.pDRM <= prn[4];
		pg_ren.pr[0].op.pRd <= prn[5];
	/*
	if (bo_wr) begin
		if (pg_dec.pr[0].aRa==bo_areg)
			pg_ren.pr[0].pRa <= bo_preg;
		if (pg_dec.pr[0].aRb==bo_areg)
			pg_ren.pr[0].pRb <= bo_preg;
		if (pg_dec.pr[0].aRc==bo_areg)
			pg_ren.pr[0].pRc <= bo_preg;
		if (pg_dec.pr[0].aRt==bo_areg)
			pg_ren.pr[0].pRd <= bo_preg;
	end
	*/
		if (MWIDTH > 1) begin
			pg_ren.pr[1] <= pg_dec.pr[1];
			if (stomp_ren) begin
				pg_ren.pr[1].stomped <= TRUE;
				pg_ren.pr[1].op.decbus.cpytgt <= TRUE;
			end
			if (~pg_dec.pr[1].v)
				tStomp(1);
			if (pg_dec.pr[0].op.decbus.bsr|pg_dec.pr[0].op.decbus.jsr) begin
				pg_ren.pr[1].stomped <= TRUE;
				pg_ren.pr[1].op.decbus.cpytgt <= TRUE;
			end
			if (pg_ren.pr[1].op.decbus.bsr|pg_ren.pr[1].op.decbus.jsr) begin
				pg_ren.pr[1].stomped <= TRUE;
				pg_ren.pr[1].op.decbus.cpytgt <= TRUE;
			end
			pg_ren.pr[1].op.nRd <= pRd_dec[1];
			pg_ren.pr[1].op.pRs1 <= prn[6];
			pg_ren.pr[1].op.pRs2 <= prn[7];
			pg_ren.pr[1].op.pRs3 <= prn[8];
			pg_ren.pr[1].op.pRs4 <= prn[9];
			pg_ren.pr[1].op.pDRM <= prn[10];
			pg_ren.pr[1].op.pRd <= prn[11];
		end
	
		if (MWIDTH > 2) begin
			pg_ren.pr[2] <= pg_dec.pr[2];
			if (stomp_ren) begin
				pg_ren.pr[2].stomped <= TRUE;
				pg_ren.pr[2].op.decbus.cpytgt <= TRUE;
			end
			if (~pg_dec.pr[2].v)
				tStomp(2);
			if (pg_dec.pr[0].op.decbus.bsr || pg_dec.pr[1].op.decbus.bsr || pg_dec.pr[0].op.decbus.jsr || pg_dec.pr[1].op.decbus.jsr) begin
				pg_ren.pr[2].stomped <= TRUE;
				pg_ren.pr[2].op.decbus.cpytgt <= TRUE;
			end
			if (pg_ren.pr[2].op.decbus.bsr | pg_ren.pr[2].op.decbus.jsr) begin
				pg_ren.pr[2].stomped <= TRUE;
				pg_ren.pr[2].op.decbus.cpytgt <= TRUE;
			end
			pg_ren.pr[2].op.nRd <= pRd_dec[2];
			pg_ren.pr[2].op.pRs1 <= prn[12];
			pg_ren.pr[2].op.pRs2 <= prn[13];
			pg_ren.pr[2].op.pRs3 <= prn[14];
			pg_ren.pr[2].op.pRs4 <= prn[15];
			pg_ren.pr[2].op.pDRM <= prn[16];
//				pg_ren.pr[2].op.uop.Rs4 = prn[13];
			pg_ren.pr[2].op.pRd <= prn[17];
		end

		if (MWIDTH > 3) begin
			pg_ren.pr[3] <= pg_dec.pr[3];
			if (stomp_ren) begin
				pg_ren.pr[3].stomped <= TRUE;
				pg_ren.pr[3].op.decbus.cpytgt <= TRUE;
			end
			if (~pg_dec.pr[3].v)
				tStomp(3);
			if (pg_dec.pr[0].op.decbus.bsr || pg_dec.pr[1].op.decbus.bsr || pg_dec.pr[2].op.decbus.bsr ||
				pg_dec.pr[0].op.decbus.jsr || pg_dec.pr[1].op.decbus.jsr || pg_dec.pr[2].op.decbus.jsr) begin
				pg_ren.pr[3].stomped <= TRUE;
				pg_ren.pr[3].op.decbus.cpytgt <= TRUE;
			end
			if (pg_ren.pr[3].op.decbus.bsr | pg_ren.pr[3].op.decbus.jsr) begin
				pg_ren.pr[3].stomped <= TRUE;
				pg_ren.pr[3].op.decbus.cpytgt <= TRUE;
			end
			pg_ren.pr[3].op.nRd <= pRd_dec[3];
			pg_ren.pr[3].op.pRs1 <= prn[18];
			pg_ren.pr[3].op.pRs2 <= prn[19];
			pg_ren.pr[3].op.pRs3 <= prn[20];
			pg_ren.pr[3].op.pRs4 <= prn[21];
			pg_ren.pr[3].op.pDRM <= prn[22];
			pg_ren.pr[3].op.pRd <= prn[23];
		end
	end
	// At the rename stage destination rename registers have already been assigned
	// and dependencies determined. So, we do not want to mark the instruction as
	// stomped because we want to copy the destination register to the renamed one.
	if (branch_resolved)
//		tInvalidateRen(kept_stream);//misspc.bno_t);
		foreach (pg_ren.pr[nn]) begin
			if (pg_dec.pr[nn].ip_stream.stream!=live_stream.stream && live_stream.thread==pg_dec.pr[nn].ip_stream.thread) begin
				pg_ren.pr[nn].op.excv <= INV;
				if (Qupls5_pkg::SUPPORT_BACKOUT) begin
					pg_ren.pr[nn].stomped <= TRUE;
					pg_ren.pr[nn].op <= {$bits(Qupls5_pkg::pipeline_reg_t){1'b0}};
					pg_ren.pr[nn].op.v <= VAL;
					pg_ren.pr[nn].op.exc <= Qupls5_pkg::FLT_NONE;
					pg_ren.pr[nn].op.uop <= {$bits(Qupls5_pkg::micro_op_t){1'b0}};
					pg_ren.pr[nn].op.uop.opcode <= Qupls5_pkg::OP_NOP;
					pg_ren.pr[nn].op.uop.v <= VAL;
					pg_ren.pr[nn].op.uop.lead <= TRUE;
					pg_ren.pr[nn].op.decbus <= {$bits(Qupls5_pkg::decode_bus_t){1'b0}};
					pg_ren.pr[nn].op.decbus.v <= VAL;
					pg_ren.pr[nn].op.decbus.nop <= TRUE;
					pg_ren.pr[nn].op.decbus.sau <= TRUE;
					pg_ren.pr[nn].op.decbus.cause <= Qupls5_pkg::FLT_NONE;
					pg_ren.pr[nn].op.decbus.cpytgt <= TRUE;
				end
				else begin
					pg_ren.pr[nn].op.decbus.cpytgt <= TRUE;
					pg_ren.pr[nn].op.decbus.sau <= TRUE;
					pg_ren.pr[nn].op.decbus.fpu <= FALSE;
					pg_ren.pr[nn].op.decbus.fc <= FALSE;
					pg_ren.pr[nn].op.decbus.mem <= FALSE;
				end
			end
		end

end

// fet/mux/dec stages can be invalidated by turning the instruction in the
// pipeline into a NOP operation. That is handled in the pipeline_seg1
// module.
// Rename stage needs its own invalidation as registers have been renamed
// already, instructions must be turned into copy targets.

task tInvalidateRen;
input pc_stream_t bno;
integer nn;
begin
	foreach (pg_ren.pr[nn]) begin
		if (pg_ren.pr[nn].ip_stream!=bno) begin
			pg_ren.pr[nn].op.excv <= INV;
			if (Qupls5_pkg::SUPPORT_BACKOUT) begin
				pg_ren.pr[nn].stomped <= TRUE;
				pg_ren.pr[nn].op <= {$bits(Qupls5_pkg::pipeline_reg_t){1'b0}};
				pg_ren.pr[nn].op.v <= VAL;
				pg_ren.pr[nn].op.exc <= Qupls5_pkg::FLT_NONE;
				pg_ren.pr[nn].op.uop <= {$bits(Qupls5_pkg::micro_op_t){1'b0}};
				pg_ren.pr[nn].op.uop.opcode <= Qupls5_pkg::OP_NOP;
				pg_ren.pr[nn].op.uop.v <= VAL;
				pg_ren.pr[nn].op.uop.lead <= TRUE;
				pg_ren.pr[nn].op.decbus <= {$bits(Qupls5_pkg::decode_bus_t){1'b0}};
				pg_ren.pr[nn].op.decbus.v <= VAL;
				pg_ren.pr[nn].op.decbus.nop <= TRUE;
				pg_ren.pr[nn].op.decbus.sau <= TRUE;
				pg_ren.pr[nn].op.decbus.cause <= Qupls5_pkg::FLT_NONE;
				pg_ren.pr[nn].op.decbus.cpytgt <= TRUE;
			end
			else begin
				pg_ren.pr[nn].op.decbus.cpytgt <= TRUE;
				pg_ren.pr[nn].op.decbus.sau <= TRUE;
				pg_ren.pr[nn].op.decbus.fpu <= FALSE;
				pg_ren.pr[nn].op.decbus.fc <= FALSE;
				pg_ren.pr[nn].op.decbus.mem <= FALSE;
			end
		end
	end
end
endtask

// Rename does not take place for invalid instructions so they can just be
// stomped on if invalid.

task tStomp;
input integer n;
begin
	pg_ren.pr[n].excv <= INV;
	pg_ren.pr[n].stomped <= TRUE;
	pg_ren.pr[n].op.v <= INV;
	pg_ren.pr[n].op.decbus.cpytgt <= FALSE;
	pg_ren.pr[n].op.excv <= INV;
	pg_ren.pr[n].done <= 2'b11;
end
endtask

endmodule

