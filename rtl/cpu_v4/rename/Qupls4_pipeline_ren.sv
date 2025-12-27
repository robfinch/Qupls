// ============================================================================
//        __
//   \\__/ o\    (C) 2024-2025  Robert Finch, Waterloo
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
// 16800 LUTs / 5325 FFs / 0 BRAMs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

`define SUPPORT_RAT	1

module Qupls4_pipeline_ren(
	rst, clk, clk5x, ph4, en, nq, restore, restored, restore_list,
	unavail_list,
	chkpt_amt, tail0, rob, avail_reg, sr, branch_resolved,
	stomp_ren, kept_stream, flush_dec, flush_ren,
//	arn, arng, arnv,
	rn_cp, store_argC_pReg, prn_i, prnv,
	Rt0_ren, Rt0_renv, 
	pg_dec, pg_ren,

	wrport0_v,
	wrport0_aRt,
	wrport0_Rt,
	wrport0_res,
	wrport0_cp,

	cmtav, cmtaa,
	cmtap, cmta_cp,
	cmtaiv,

	cmtbr,
	tags2free, freevals, backout, fcu_id,
	bo_wr, bo_areg, bo_preg, bo_nreg,
	rat_stallq,
	micro_machine_active_dec, micro_machine_active_ren,
	alloc_chkpt, cndx, rcndx, miss_cp,
	
	args
);
parameter MWIDTH = Qupls4_pkg::MWIDTH;
localparam NPORT = MWIDTH*4;
input rst;
input clk;
input clk5x;
input [4:0] ph4;
input en;
input flush_dec;
output reg flush_ren;
input nq;
input restore;
output restored;
output [Qupls4_pkg::PREGS-1:0] restore_list;
input [Qupls4_pkg::PREGS-1:0] unavail_list;
input [2:0] chkpt_amt;
input rob_ndx_t tail0;
input Qupls4_pkg::rob_entry_t [Qupls4_pkg::ROB_ENTRIES-1:0] rob;
input [Qupls4_pkg::PREGS-1:0] avail_reg;
input Qupls4_pkg::status_reg_t sr;
input branch_resolved;
input stomp_ren;
input pc_stream_t kept_stream;
//input aregno_t [NPORT-1:0] arn;
//input [2:0] arng [0:NPORT-1];
//input [NPORT-1:0] arnv;
input checkpt_ndx_t [NPORT-1:0] rn_cp;
input pregno_t [NPORT-1:0] prn_i;
output [NPORT-1:0] prnv;
input pregno_t store_argC_pReg;
input Qupls4_pkg::pipeline_group_reg_t pg_dec;
output Qupls4_pkg::pipeline_group_reg_t pg_ren;
output pregno_t [MWIDTH-1:0] Rt0_ren;
output reg [MWIDTH-1:0] Rt0_renv;
input [MWIDTH-1:0] wrport0_v;
input aregno_t [MWIDTH-1:0] wrport0_aRt;
input pregno_t [MWIDTH-1:0] wrport0_Rt;
input value_t [MWIDTH-1:0] wrport0_res;
input checkpt_ndx_t [MWIDTH-1:0] wrport0_cp;
input [MWIDTH-1:0] cmtav;
input [MWIDTH-1:0] cmtaiv;
input aregno_t [MWIDTH-1:0] cmtaa;
input pregno_t [MWIDTH-1:0] cmtap;
input checkpt_ndx_t [MWIDTH-1:0] cmta_cp;
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
input micro_machine_active_dec;
output reg micro_machine_active_ren;
input alloc_chkpt;
input checkpt_ndx_t cndx;
input checkpt_ndx_t [3:0] rcndx;
input checkpt_ndx_t miss_cp;
input value_t [NPORT-1:0] args; 


genvar g;
integer jj,n1,n5,n6,n7,n8,n9;
aregno_t [MWIDTH-1:0] aRd_dec;
pregno_t [MWIDTH-1:0] pRd_dec;
wire [MWIDTH-1:0] pRd_decv;
reg [MWIDTH-1:0] aRd_decv;
wire rat_stallq1;
wire ns_stall;
assign rat_stallq = rat_stallq1|ns_stall;

Qupls4_pkg::pipeline_reg_t nopi;

always_comb
	foreach (pg_dec.pr[n1])
		aRd_dec[n1] = pg_dec.pr[n1].op.decbus.Rd;

always_comb
	foreach (pg_dec.pr[n1])
		aRd_decv[n1] = pg_dec.pr[n1].op.decbus.Rdv;

// Define a NOP instruction.
always_comb
begin
	nopi = {$bits(Qupls4_pkg::pipeline_reg_t){1'b0}};
	nopi.uop = {41'd0,Qupls4_pkg::OP_NOP};
	nopi.uop.lead = 1'd1;
	nopi.uop.Rs1 = 8'd0;
	nopi.uop.Rs2 = 8'd0;
	nopi.uop.Rs3 = 8'd0;
	nopi.uop.Rs4 = 8'd0;
	nopi.uop.Rd = 8'd0;
	nopi.uop.Rd2 = 8'd0;
	nopi.decbus.Rs1 = 8'd0;
	nopi.decbus.Rs2 = 8'd0;
	nopi.decbus.Rs3 = 8'd0;
	nopi.decbus.Rs1z = 1'd0;
	nopi.decbus.Rs2z = 1'd0;
	nopi.decbus.Rs3z = 1'd0;
	nopi.decbus.Rdv = 1'b0;
	nopi.decbus.nop = 1'b1;
	nopi.decbus.alu = 1'b1;
end

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

reg [MWIDTH*4-1:0] arnv;
reg [2:0] arng [0:MWIDTH*5-1];
aregno_t [MWIDTH*4-1:0] arn;
pregno_t [MWIDTH*4-1:0] prn;

always_comb
begin
	arnv = {MWIDTH*4{1'b1}};
	for (n8 = 0; n8 < MWIDTH; n8 = n8 + 1) begin
		arn[n8*4+0] = pg_dec.pr[n8].op.decbus.Rs1;
		arn[n8*4+1] = pg_dec.pr[n8].op.decbus.Rs2;
		arn[n8*4+2] = pg_dec.pr[n8].op.decbus.Rs3;
		arn[n8*4+3] = pg_dec.pr[n8].op.decbus.Rd;
		arng[n8*4+0] = n8;
		arng[n8*4+1] = n8;
		arng[n8*4+2] = n8;
		arng[n8*4+3] = n8;
	end
end

/*
always_comb Rt0_q1 = Rt0_ren;// & {10{~pg_ren.pr[0].decbus.Rtz & ~stomp0}};
always_comb Rt1_q1 = Rt1_ren;// & {10{~pg_ren.pr[1].decbus.Rtz & ~stomp1}};
always_comb Rt2_q1 = Rt2_ren;// & {10{~pg_ren.pr[2].decbus.Rtz & ~stomp2}};
always_comb Rt3_q1 = Rt3_ren;// & {10{~pg_ren.pr[3].decbus.Rtz & ~stomp3}};
always_comb Rt0_que = Rt0_ren;
always_comb Rt1_que = Rt1_ren;
always_comb Rt2_que = Rt2_ren;
always_comb Rt3_que = Rt3_ren;
*/
/*
always_ff @(posedge clk)
if (rst)
	Rt0_que <= 8'd0;
else begin
	if (advance_pipeline_seg2)
		Rt0_que <= Rt0_ren;
end
always_ff @(posedge clk)
if (rst)
	Rt1_que <= 8'd0;
else begin
	if (advance_pipeline_seg2)
		Rt1_que <= Rt1_ren;
end
always_ff @(posedge clk)
if (rst)
	Rt2_que <= 8'd0;
else begin
	if (advance_pipeline_seg2)
		Rt2_que <= Rt2_ren;
end
always_ff @(posedge clk)
if (rst)
	Rt3_que <= 8'd0;
else begin
	if (advance_pipeline_seg2)
		Rt3_que <= Rt3_ren;
end
always_ff @(posedge clk)
if (rst)
	Rt0_q1 <= 8'd0;
else begin
	if (advance_pipeline_seg2)
		Rt0_q1 <= Rt0_ren;
end
always_ff @(posedge clk)
if (rst)
	Rt1_q1 <= 8'd0;
else begin
	if (advance_pipeline_seg2)
		Rt1_q1 <= Rt1_ren;
end
always_ff @(posedge clk)
if (rst)
	Rt2_q1 <= 8'd0;
else begin
	if (advance_pipeline_seg2)
		Rt2_q1 <= Rt2_ren;
end
always_ff @(posedge clk)
if (rst)
	Rt3_q1 <= 8'd0;
else begin
	if (advance_pipeline_seg2)
		Rt3_q1 <= Rt3_ren;
end
*/
/*
always_ff @(posedge clk)
if (rst)
	Rt0_pq <= 11'd0;
else begin
	if (advance_pipeline_seg2)
		Rt0_pq <= Rt0_ren;
end
always_ff @(posedge clk)
if (rst)
	Rt1_pq <= 11'd0;
else begin
	if (advance_pipeline_seg2)
		Rt1_pq <= Rt1_ren;
end
always_ff @(posedge clk)
if (rst)
	Rt2_pq <= 11'd0;
else begin
	if (advance_pipeline_seg2)
		Rt2_pq <= Rt2_ren;
end
always_ff @(posedge clk)
if (rst)
	Rt3_pq <= 11'd0;
else begin
	if (advance_pipeline_seg2)
		Rt3_pq <= Rt3_ren;
end
*/
/*
always_ff @(posedge clk)
if (advance_pipeline) begin
	if (alloc0 && pg_ren.pr[0].decbus.Rt==0) begin
		$display("alloced r0");
		$finish;
	end
	if (alloc1 && pg_ren.pr[1].decbus.Rt==0) begin
		$display("alloced r0");
		$finish;
	end
	if (alloc2 && pg_ren.pr[2].decbus.Rt==0) begin
		$display("alloced r0");
		$finish;
	end
	if (alloc3 && pg_ren.pr[3].decbus.Rt==0) begin
		$display("alloced r0");
		$finish;
	end
end
*/
/*
always_ff @(posedge clk)
begin
	if (!stallq && (pg_ren.pr[0].decbus.Rt==7'd63 ||
		pg_ren.pr[1].decbus.Rt==7'd63 ||
		pg_ren.pr[2].decbus.Rt==7'd63 ||
		pg_ren.pr[3].decbus.Rt==7'd63
	))
		$finish;
	for (n19 = 0; n19 < 16; n19 = n19 + 1)
		if (arn[n19]==7'd63)
			$finish;
end
*/
checkpt_ndx_t cndx1, cndx2, cndx3;
assign cndx1 = cndx;
assign cndx2 = cndx;
assign cndx3 = cndx;

reg [MWIDTH-1:0] qbr;
always_comb
foreach (qbr[n6])
	qbr[n6] = pg_dec.pr[n6].op.decbus.br|pg_dec.pr[n6].op.decbus.cjb;


`ifdef SUPPORT_RAT
Qupls4_reg_name_supplier4 uns4
(
	.rst(rst),
	.clk(clk),
	.en(en),
	.restore(restore),
	.restore_list(restore_list & ~unavail_list),
	.tags2free(tags2free),
	.freevals(freevals),
	.bo_wr(bo_wr),
	.bo_preg(bo_preg),
	.ns_alloc_req(aRd_decv),
	.ns_whrndx(6'd0),			// not used
	.ns_rndx(),						// not used
	.ns_dstreg(pRd_dec),
	.ns_dstregv(pRd_decv),
	.avail(),							// available registers list
	.stall(ns_stall),
	.rst_busy()
);

Qupls4_rat
#(
	.MWIDTH(MWIDTH),
	.NPORT(NPORT),
	.NREG_RPORT(NPORT)
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
	.st_prn(store_argC_pReg),
	.prn(prn),
	.prn_i(prn_i),
	.prv(prnv),
	.wr(pRd_decv & aRd_decv),// && !stomp0 && ~pg_ren.pr[0].decbus.Rtz),
	.wra(aRd_dec),
	.wrra(pRd_dec),
	.wra_cp(rcndx),
	.wrport0_v(wrport0_v),
	.wrport0_aRt(wrport0_aRt),
	.wrport0_Rt(wrport0_Rt),
	.wrport0_cp(wrport0_cp),
	.wrport0_res(wrport0_res),
	.cmtav(cmtav),
	.cmtaiv(cmtaiv),
	.cmtaa(cmtaa),
	.cmtap(cmtap),
	.cmtaval(64'd0),
	.cmta_cp(cmta_cp),
	.cmtbr(cmtbr),
	.restore_list(restore_list),
	.restored(restored),
	.tags2free(tags2free),
	.freevals(freevals),
	.backout(backout),
	.fcu_id(fcu_id),
	.bo_wr(bo_wr),
	.bo_areg(bo_areg),
	.bo_preg(bo_preg),
	.bo_nreg(bo_nreg)	
);
`else
	assign rat_stallq = FALSE;
	assign cndx0 = 4'd0;
	assign bo_wr = FALSE;
	assign bo_areg = 8'd0;
	assign bo_preg = 9'd0;
	assign prnv = 24'hFFFFFF;
	always_ff @(posedge clk)
	if (rst) begin
		for (n5 = 0; n5 < NPORT; n5 = n5 + 1)
			prn[n5] <= 9'd0;
	end
	else begin
		if (en)
		begin
			for (n5 = 0; n5 < NPORT; n5 = n5 + 1)
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
`endif

/*
always_ff @(posedge clk)
begin
	db0r <= db0;
	if (brtgtv)
		db0r.v <= FALSE;
end
always_ff @(posedge clk)
begin
	db1r <= db1;
	if (brtgtv)
		db1r.v <= FALSE;
end
always_ff @(posedge clk) begin
	db2r <= db2;
	if (brtgtv)
		db2r.v <= FALSE;
end
always_ff @(posedge clk) begin
	db3r <= db3;
	if (brtgtv)
		db3r.v <= FALSE;
end
*/
/*
always_ff @(posedge clk)
if (rst) begin
	pc0_f.bno_t <= 6'd1;
	pc0_f.bno_f <= 6'd1;
	pc0_f.pc <= RSTPC;
end
else begin
//	if (advance_f)
	pc0_f <= icpc;//pc0;
end
*/
/*
always_comb
	micro_machine_active_x = micro_machine_active;
*/
// The cycle after the length is calculated
// instruction extract inputs
/*
pc_address_ex_t pc0_x1;
always_ff @(posedge clk)
if (rst) begin
	pc0_x1.bno_t <= 6'd1;
	pc0_x1.bno_f <= 6'd1;
	pc0_x1.pc <= RSTPC;
end
else begin
	if (advance_pipeline)
		pc0_x1 <= pc0_f;
end

always_comb
begin
 	pc0_fet = micro_machine_active ? mc_adr : pc0_x1;
end
always_comb 
begin
	pc1_fet = pc0_fet;
	pc1_fet.pc = micro_machine_active ? pc0_fet.pc : pc0_fet.pc + 6'd8;
end
always_comb
begin
	pc2_fet = pc0_fet;
	pc2_fet.pc = micro_machine_active ? pc0_fet.pc : pc0_fet.pc + 6'd16;
end
always_comb
begin
	pc3_fet = pc0_fet;
	pc3_fet.pc = micro_machine_active ? pc0_fet.pc : pc0_fet.pc + 6'd24;
end
*/
/*
always_ff @(posedge clk)
if (advance_pipeline)
	qd_x <= qd;
always_ff @(posedge clk)
if (advance_pipeline)
	qd_d <= qd_x;
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	qd_r <= qd_d;
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	qd_q <= qd_r;
*/
// Register fetch/rename stage inputs
/*
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pc0_r <= pg_dec.pr[0].pc;//pc0_d;
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pc1_r <= pg_dec.pr[1].pc;//pc1_d;
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pc2_r <= pg_dec.pr[2].pc;//pc2_d;
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pc3_r <= pg_dec.pr[3].pc;//pc3_d;
*/
generate begin : gPg_ren
always_ff @(posedge clk)
if (rst) begin
	foreach (pg_ren.pr[n7]) begin
		pg_ren.hdr <= {$bits(Qupls4_pkg::pipeline_group_hdr_t){1'b0}};
		pg_ren.pr[n7] <= {$bits(Qupls4_pkg::rob_entry_t){1'b0}};
		pg_ren.pr[n7].op <= nopi;
	end
end
else begin
	if (en) begin
		pg_ren.hdr <= pg_dec.hdr;
		pg_ren.hdr.cndx <= cndx;
		pg_ren.hdr.cndxv <= VAL;
		if (stomp_ren)
			pg_ren.hdr.v <= INV;
		pg_ren.pr[0] <= pg_dec.pr[0];
		if (pg_dec.pr[0].v & ~stomp_ren) begin
			pg_ren.pr[0].op.nRd <= pRd_dec[0];
			pg_ren.pr[0].op.pRs1 <= prn[0];
			pg_ren.pr[0].op.pRs2 <= prn[1];
			pg_ren.pr[0].op.pRs3 <= prn[2];
//			pg_ren.pr[0].op.uop.Rs4 = prn[3];
			pg_ren.pr[0].op.pRd <= prn[3];
			case(MWIDTH)
			1:
				if (pg_ren.pr[0].op.decbus.bsr|pg_ren.pr[0].op.decbus.jsr)
					pg_ren.pr[0].v <= INV;
			2:
				if (pg_ren.pr[1].op.decbus.bsr|pg_ren.pr[1].op.decbus.jsr)
					pg_ren.pr[0].v <= INV;
			3:
				if (pg_ren.pr[2].op.decbus.bsr|pg_ren.pr[2].op.decbus.jsr)
					pg_ren.pr[0].v <= INV;
			default:
				if (pg_ren.pr[3].op.decbus.bsr|pg_ren.pr[3].op.decbus.jsr)
					pg_ren.pr[0].v <= INV;
		    endcase
		end
		else begin
			// Even if stomped on, we want to retain the destination register for
			// copy purposes.
//			pg_ren.pr[0] <= nopi;
			pg_ren.pr[0].v <= INV;
//			pg_ren.pr[0].decbus.Rt <= pg_ren.pr[0].decbus.Rt;
//			pg_ren.pr[0].decbus.Rtn <= pg_ren.pr[0].decbus.Rtn;
//			pg_ren.pr[0].decbus.Rtz <= pg_ren.pr[0].decbus.Rtz;
//			pg_ren.pr[0].aRt <= pg_ren.pr[0].aRt;
			if (Qupls4_pkg::SUPPORT_BACKOUT)
				pg_ren.pr[0].op.nRd <= 9'd0;//pg_ren.pr[0].nRt;
			else
				pg_ren.pr[0].op.nRd <= pRd_dec[0];
		end
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
			if (pg_dec.pr[1].v & ~stomp_ren) begin
				pg_ren.pr[1].op.nRd <= pRd_dec[1];
				pg_ren.pr[1].op.pRs1 <= prn[4];
				pg_ren.pr[1].op.pRs2 <= prn[5];
				pg_ren.pr[1].op.pRs3 <= prn[6];
//				pg_ren.pr[1].op.uop.Rs4 = prn[8];
				pg_ren.pr[1].op.pRd <= prn[7];
				if (pg_dec.pr[0].op.decbus.bsr|pg_dec.pr[0].op.decbus.jsr)
					pg_ren.pr[1].v <= INV;
				if (pg_ren.pr[3].op.decbus.bsr|pg_ren.pr[3].op.decbus.jsr)
					pg_ren.pr[1].v <= INV;
			end
			else begin
	//			pg_ren.pr[1] <= nopi;
				pg_ren.pr[1].v <= INV;
	//			pg_ren.pr[1].decbus.Rt <= pg_ren.pr[1].decbus.Rt;
	//			pg_ren.pr[1].decbus.Rtn <= pg_ren.pr[1].decbus.Rtn;
	//			pg_ren.pr[1].decbus.Rtz <= pg_ren.pr[1].decbus.Rtz;
	//			pg_ren.pr[1].aRt <= pg_ren.pr[1].aRt;
				if (Qupls4_pkg::SUPPORT_BACKOUT)
					pg_ren.pr[1].op.nRd <= 9'd0;//pg_ren.pr[1].nRt;
				else
					pg_ren.pr[1].op.nRd <= pRd_dec[1];
			end
		end
	
		if (MWIDTH > 2) begin
			pg_ren.pr[2] <= pg_dec.pr[2];
			if (pg_dec.pr[2].v & ~stomp_ren) begin
				pg_ren.pr[2].op.nRd <= pRd_dec[2];
				pg_ren.pr[2].op.pRs1 <= prn[8];
				pg_ren.pr[2].op.pRs2 <= prn[9];
				pg_ren.pr[2].op.pRs3 <= prn[10];
//				pg_ren.pr[2].op.uop.Rs4 = prn[13];
				pg_ren.pr[2].op.pRd <= prn[11];
				if (pg_dec.pr[0].op.decbus.bsr || pg_dec.pr[1].op.decbus.bsr || pg_dec.pr[0].op.decbus.jsr || pg_dec.pr[1].op.decbus.jsr)
					pg_ren.pr[2].v <= INV;
				if (pg_ren.pr[3].op.decbus.bsr | pg_ren.pr[3].op.decbus.jsr)
					pg_ren.pr[2].v <= INV;
			end
			else begin
	//			pg_ren.pr[2] <= nopi;
				pg_ren.pr[2].v <= INV;
	//			pg_ren.pr[2].decbus.Rt <= pg_ren.pr[2].decbus.Rt;
	//			pg_ren.pr[2].decbus.Rtn <= pg_ren.pr[2].decbus.Rtn;
	//			pg_ren.pr[2].decbus.Rtz <= pg_ren.pr[2].decbus.Rtz;
	//			pg_ren.pr[2].aRt <= pg_ren.pr[2].aRt;
				if (Qupls4_pkg::SUPPORT_BACKOUT)
					pg_ren.pr[2].op.nRd <= 9'd0;//pg_ren.pr[2].nRt;
				else
					pg_ren.pr[2].op.nRd <= pRd_dec[2];
			end
		end

		if (MWIDTH > 3) begin
			pg_ren.pr[3] <= pg_dec.pr[3];
			if (pg_dec.pr[3].v & ~stomp_ren) begin
				pg_ren.pr[3].op.nRd <= pRd_dec[3];
				pg_ren.pr[3].op.pRs1 <= prn[12];
				pg_ren.pr[3].op.pRs2 <= prn[13];
				pg_ren.pr[3].op.pRs3 <= prn[14];
//				pg_ren.pr[3].op.uop.Rs4 = prn[18];
				pg_ren.pr[3].op.pRd <= prn[15];
				if (pg_dec.pr[0].op.decbus.bsr || pg_dec.pr[1].op.decbus.bsr || pg_dec.pr[2].op.decbus.bsr ||
					pg_dec.pr[0].op.decbus.jsr || pg_dec.pr[1].op.decbus.jsr || pg_dec.pr[2].op.decbus.jsr
				)
					pg_ren.pr[3].v <= INV;
				if (pg_ren.pr[3].op.decbus.bsr | pg_ren.pr[3].op.decbus.jsr)
					pg_ren.pr[3].v <= INV;
			end
			else begin
	//			pg_ren.pr[3] <= nopi;
				pg_ren.pr[3].v <= INV;
	//			pg_ren.pr[3].decbus.Rt <= pg_ren.pr[3].decbus.Rt;
	//			pg_ren.pr[3].decbus.Rtn <= pg_ren.pr[3].decbus.Rtn;
	//			pg_ren.pr[3].decbus.Rtz <= pg_ren.pr[3].decbus.Rtz;
	//			pg_ren.pr[3].aRt <= pg_ren.pr[3].aRt;
				if (Qupls4_pkg::SUPPORT_BACKOUT)
					pg_ren.pr[3].op.nRd <= 9'd0;//pg_ren.pr[3].nRt;
				else
					pg_ren.pr[3].op.nRd <= pRd_dec[3];
			end
		end
	end
	if (branch_resolved)
		tInvalidateRen(kept_stream);//misspc.bno_t);

end
end
endgenerate

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
			if (Qupls4_pkg::SUPPORT_BACKOUT)
				pg_ren.pr[nn].v <= INV;
			else begin
				pg_ren.pr[nn].op.decbus.cpytgt <= TRUE;
				pg_ren.pr[nn].op.decbus.alu <= TRUE;
				pg_ren.pr[nn].op.decbus.fpu <= FALSE;
				pg_ren.pr[nn].op.decbus.fc <= FALSE;
				pg_ren.pr[nn].op.decbus.mem <= FALSE;
			end
		end
	end
end
endtask

endmodule

