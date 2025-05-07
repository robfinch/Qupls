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
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Stark_pkg::*;

`define SUPPORT_RAT	1

module Stark_pipeline_ren(
	rst, clk, clk5x, ph4, en, nq, restore, restored, restore_list,
	chkpt_amt, tail0, rob, robentry_stomp, avail_reg, sr,
	stomp_ren, stomp_bno, branch_state, flush_dec, flush_ren,
	arn, arng, arnt, arnv, rn_cp, store_argC_pReg, prn, prnv,
	ns_areg,
	Rt0_dec, Rt1_dec, Rt2_dec, Rt3_dec, Rt0_decv, Rt1_decv, Rt2_decv, Rt3_decv, 
	Rt0_ren, Rt1_ren, Rt2_ren, Rt3_ren, Rt0_renv, Rt1_renv, Rt2_renv, Rt3_renv, 
	pg_dec, pg_ren,

	wrport0_v, wrport1_v, wrport2_v, wrport3_v, 
	wrport0_aRt, wrport1_aRt, wrport2_aRt, wrport3_aRt, 
	wrport0_Rt, wrport1_Rt, wrport2_Rt, wrport3_Rt, 
	wrport0_res, wrport1_res, wrport2_res, wrport3_res, 
	wrport0_cp, wrport1_cp, wrport2_cp, wrport3_cp, 

	cmtav, cmtbv, cmtcv, cmtdv, cmtaa, cmtba, cmtca, cmtda,
	cmtap, cmtbp, cmtcp, cmtdp, cmta_cp, cmtb_cp, cmtc_cp, cmtd_cp,
	cmtaiv, cmtbiv, cmtciv, cmtdiv,

	cmtbr,
	tags2free, freevals, backout, backout_st2, fcu_id,
	bo_wr, bo_areg, bo_preg, bo_nreg,
	rat_stallq,
	micro_machine_active_dec, micro_machine_active_ren,
	alloc_chkpt, cndx, rcndx, miss_cp
);
parameter NPORT = 16;
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
output [Stark_pkg::PREGS-1:0] restore_list;
input [2:0] chkpt_amt;
input rob_ndx_t tail0;
input Stark_pkg::rob_entry_t [Stark_pkg::ROB_ENTRIES-1:0] rob;
input [Stark_pkg::ROB_ENTRIES-1:0] robentry_stomp;
input [Stark_pkg::PREGS-1:0] avail_reg;
input Stark_pkg::status_reg_t sr;
input stomp_ren;
input [4:0] stomp_bno;
input Stark_pkg::branch_state_t branch_state;
input aregno_t [NPORT-1:0] arn;
input [2:0] arng [0:NPORT-1];
input [NPORT-1:0] arnt;
input [NPORT-1:0] arnv;
input checkpt_ndx_t [NPORT-1:0] rn_cp;
output pregno_t [NPORT-1:0] prn;
output [NPORT-1:0] prnv;
input pregno_t store_argC_pReg;
input aregno_t [3:0] ns_areg;
input pregno_t Rt0_dec;
input pregno_t Rt1_dec;
input pregno_t Rt2_dec;
input pregno_t Rt3_dec;
input Rt0_decv;
input Rt1_decv;
input Rt2_decv;
input Rt3_decv;
input Stark_pkg::pipeline_group_reg_t pg_dec;
output Stark_pkg::pipeline_group_reg_t pg_ren;
output pregno_t Rt0_ren;
output pregno_t Rt1_ren;
output pregno_t Rt2_ren;
output pregno_t Rt3_ren;
output reg Rt0_renv;
output reg Rt1_renv;
output reg Rt2_renv;
output reg Rt3_renv;
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
input value_t wrport0_res;
input value_t wrport1_res;
input value_t wrport2_res;
input value_t wrport3_res;
input checkpt_ndx_t wrport0_cp;
input checkpt_ndx_t wrport1_cp;
input checkpt_ndx_t wrport2_cp;
input checkpt_ndx_t wrport3_cp;
input cmtav;
input cmtbv;
input cmtcv;
input cmtdv;
input cmtaiv;
input cmtbiv;
input cmtciv;
input cmtdiv;
input aregno_t cmtaa;
input aregno_t cmtba;
input aregno_t cmtca;
input aregno_t cmtda;
input pregno_t cmtap;
input pregno_t cmtbp;
input pregno_t cmtcp;
input pregno_t cmtdp;
input checkpt_ndx_t cmta_cp;
input checkpt_ndx_t cmtb_cp;
input checkpt_ndx_t cmtc_cp;
input checkpt_ndx_t cmtd_cp;
input cmtbr;
output pregno_t [3:0] tags2free;
output [3:0] freevals;
input backout;
output [1:0] backout_st2;
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

integer jj,n5;

reg [0:0] arnbank [NPORT-1:0];
initial begin
	for (jj = 0; jj < NPORT; jj = jj + 1)
		arnbank[jj] = 1'b0;
end

Stark_pkg::pipeline_reg_t nopi;

// Define a NOP instruction.
always_comb
begin
	nopi = {$bits(Stark_pkg::pipeline_reg_t){1'b0}};
	nopi.pc = RSTPC;
	nopi.pc.bno_t = 6'd1;
	nopi.pc.bno_f = 6'd1;
	nopi.mcip = 12'h1A0;
	nopi.uop.ins = {26'd0,Stark_pkg::OP_NOP};
	nopi.aRs1 = 8'd0;
	nopi.aRs2 = 8'd0;
	nopi.aRs3 = 8'd0;
	nopi.aRd = 8'd0;
	nopi.decbus.Rdz = 1'b1;
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

always_ff @(posedge clk)
if (rst)
	Rt0_ren <= 9'd0;
else begin
	if (en) 
		Rt0_ren <= Rt0_decv ? Rt0_dec : 9'd0;
end
always_ff @(posedge clk)
if (rst)
	Rt1_ren <= 10'd0;
else begin
	if (en) 
		Rt1_ren <= Rt1_decv ? Rt1_dec : 9'd0;
end
always_ff @(posedge clk)
if (rst)
	Rt2_ren <= 10'd0;
else begin
	if (en) 
		Rt2_ren <= Rt2_decv ? Rt2_dec : 9'd0;
end
always_ff @(posedge clk)
if (rst)
	Rt3_ren <= 10'd0;
else begin
	if (en) 
		Rt3_ren <= Rt3_decv ? Rt3_dec : 9'd0;
end

always_ff @(posedge clk) if (rst) Rt0_renv <= 1'b0; else if (en) Rt0_renv <= Rt0_decv;
always_ff @(posedge clk) if (rst) Rt1_renv <= 1'b0; else if (en) Rt1_renv <= Rt1_decv;
always_ff @(posedge clk) if (rst) Rt2_renv <= 1'b0; else if (en) Rt2_renv <= Rt2_decv;
always_ff @(posedge clk) if (rst) Rt3_renv <= 1'b0; else if (en) Rt3_renv <= Rt3_decv;

/*
always_comb Rt0_q1 = Rt0_ren;// & {10{~pg_ren.pr0.decbus.Rtz & ~stomp0}};
always_comb Rt1_q1 = Rt1_ren;// & {10{~pg_ren.pr1.decbus.Rtz & ~stomp1}};
always_comb Rt2_q1 = Rt2_ren;// & {10{~pg_ren.pr2.decbus.Rtz & ~stomp2}};
always_comb Rt3_q1 = Rt3_ren;// & {10{~pg_ren.pr3.decbus.Rtz & ~stomp3}};
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
	if (alloc0 && pg_ren.pr0.decbus.Rt==0) begin
		$display("alloced r0");
		$finish;
	end
	if (alloc1 && pg_ren.pr1.decbus.Rt==0) begin
		$display("alloced r0");
		$finish;
	end
	if (alloc2 && pg_ren.pr2.decbus.Rt==0) begin
		$display("alloced r0");
		$finish;
	end
	if (alloc3 && pg_ren.pr3.decbus.Rt==0) begin
		$display("alloced r0");
		$finish;
	end
end
*/
/*
always_ff @(posedge clk)
begin
	if (!stallq && (pg_ren.pr0.decbus.Rt==7'd63 ||
		pg_ren.pr1.decbus.Rt==7'd63 ||
		pg_ren.pr2.decbus.Rt==7'd63 ||
		pg_ren.pr3.decbus.Rt==7'd63
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

`ifdef SUPPORT_RAT
Stark_rat #(.NPORT(NPORT)) urat1
(	
	.rst(rst),
	.clk(clk),
	.clk5x(clk5x),
	.ph4(ph4),
	.en(en),
	.en2(en),
	.nq(nq),
	.alloc_chkpt(alloc_chkpt),
	.cndx(cndx),
	.miss_cp(miss_cp),
	.chkpt_inc_amt(chkpt_amt),
	.stallq(rat_stallq),
	.tail(tail0),
	.rob(rob),
	.stomp(robentry_stomp),// & {32{branch_state==BS_CAPTURE_MISSPC}}),
	.avail_i(avail_reg),
	.restore(restore),
	.qbr0(pg_dec.pr0.decbus.br|pg_dec.pr0.decbus.cjb),
	.qbr1(pg_dec.pr1.decbus.br|pg_dec.pr1.decbus.cjb),
	.qbr2(pg_dec.pr2.decbus.br|pg_dec.pr2.decbus.cjb),
	.qbr3(pg_dec.pr3.decbus.br|pg_dec.pr3.decbus.cjb),
	.rnbank(arnbank),
	.rn(arn),
	.rng(arng),
	.rnt(arnt),
	.rnv(arnv),
	.rn_cp(rn_cp),
	.st_prn(store_argC_pReg),
	.prn(prn),
	.prv(prnv),
	.wrbanka(sr.om==2'd0 ? 1'b0 : 1'b0),	// For now, only 1 bank
	.wrbankb(sr.om==2'd0 ? 1'b0 : 1'b0),
	.wrbankc(sr.om==2'd0 ? 1'b0 : 1'b0),
	.wrbankd(sr.om==2'd0 ? 1'b0 : 1'b0),
	.wr0(Rt0_decv && ns_areg[0]!=8'd0),// && !stomp0 && ~pg_ren.pr0.decbus.Rtz),
	.wr1(Rt1_decv && ns_areg[1]!=8'd0),// && !stomp1 && ~pg_ren.pr1.decbus.Rtz),
	.wr2(Rt2_decv && ns_areg[2]!=8'd0),// && !stomp2 && ~pg_ren.pr2.decbus.Rtz),
	.wr3(Rt3_decv && ns_areg[3]!=8'd0),// && !stomp3 && ~pg_ren.pr3.decbus.Rtz),
	.wra(ns_areg[0]),
	.wrb(ns_areg[1]),
	.wrc(ns_areg[2]),
	.wrd(ns_areg[3]),
	.wrra(Rt0_dec),
	.wrrb(Rt1_dec),
	.wrrc(Rt2_dec),
	.wrrd(Rt3_dec),
	.wra_cp(rcndx[0]),
	.wrb_cp(rcndx[1]),
	.wrc_cp(rcndx[2]),
	.wrd_cp(rcndx[3]),
	.cmtbanka(1'b0),
	.cmtbankb(1'b0),
	.cmtbankc(1'b0),
	.cmtbankd(1'b0),
	.wrport0_v(wrport0_v),
	.wrport1_v(wrport1_v),
	.wrport2_v(wrport2_v),
	.wrport3_v(wrport3_v),
	.wrport0_aRt(wrport0_aRt),
	.wrport1_aRt(wrport1_aRt),
	.wrport2_aRt(wrport2_aRt),
	.wrport3_aRt(wrport3_aRt),
	.wrport0_Rt(wrport0_Rt),
	.wrport1_Rt(wrport1_Rt),
	.wrport2_Rt(wrport2_Rt),
	.wrport3_Rt(wrport3_Rt),
	.wrport0_cp(wrport0_cp),
	.wrport1_cp(wrport1_cp),
	.wrport2_cp(wrport2_cp),
	.wrport3_cp(wrport3_cp),
	.cmtav(cmtav),
	.cmtbv(cmtbv),
	.cmtcv(cmtcv),
	.cmtdv(cmtdv),
	.cmtaiv(cmtaiv),
	.cmtbiv(cmtbiv),
	.cmtciv(cmtciv),
	.cmtdiv(cmtdiv),
	.cmtaa(cmtaa),
	.cmtba(cmtba),
	.cmtca(cmtca),
	.cmtda(cmtda),
	.cmtap(cmtap),
	.cmtbp(cmtbp),
	.cmtcp(cmtcp),
	.cmtdp(cmtdp),
	.cmtaval(64'd0),
	.cmtbval(64'd0),
	.cmtcval(64'd0),
	.cmtdval(64'd0),
	.cmta_cp(cmta_cp),
	.cmtb_cp(cmtb_cp),
	.cmtc_cp(cmtc_cp),
	.cmtd_cp(cmtd_cp),
	.cmtbr(cmtbr),
	.restore_list(restore_list),
	.restored(restored),
	.tags2free(tags2free),
	.freevals(freevals),
	.backout(backout),
	.backout_st2(backout_st2),
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
		for (n5 = 0; n5 < 24; n5 = n5 + 1)
			prn[n5] <= 9'd0;
	end
	else begin
		if (en)
		begin
			for (n5 = 0; n5 < 24; n5 = n5 + 1)
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
always_ff @(posedge clk) if (advance_pipeline_seg2) mcip0_ren <= mcip0_dec;
always_ff @(posedge clk) if (advance_pipeline_seg2) mcip1_ren <= mcip1_dec;
always_ff @(posedge clk) if (advance_pipeline_seg2) mcip2_ren <= mcip2_dec;
always_ff @(posedge clk) if (advance_pipeline_seg2) mcip3_ren <= mcip3_dec;
always_ff @(posedge clk) if (advance_pipeline_seg2) mcip0_que <= mcip0_ren;
always_ff @(posedge clk) if (advance_pipeline_seg2) mcip1_que <= mcip1_ren;
always_ff @(posedge clk) if (advance_pipeline_seg2) mcip2_que <= mcip2_ren;
always_ff @(posedge clk) if (advance_pipeline_seg2) mcip3_que <= mcip3_ren;
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
always_comb mcip0_mux = micro_ip;
always_comb mcip1_mux = micro_ip|4'd1;
always_comb mcip2_mux = micro_ip|4'd2;
always_comb mcip3_mux = micro_ip|4'd3;
*/
/*
always_ff @(posedge clk)
if (rst)
	micro_machine_active_f <= TRUE;
else begin
	if (advance_pipeline)
		micro_machine_active_f <= micro_machine_active;
end
*/
/*
always_ff @(posedge clk)
if (rst)
	micro_machine_active_x <= FALSE;
else begin
	if (advance_pipeline)
		micro_machine_active_x <= micro_machine_active;
end
*/
/*
always_comb
	micro_machine_active_x = micro_machine_active;
*/
always_ff @(posedge clk)
if (rst)
	micro_machine_active_ren <= FALSE;
else begin
	if (en)
		micro_machine_active_ren <= micro_machine_active_dec;
end
/*
always_ff @(posedge clk)
if (rst)
	micro_machine_active_q <= FALSE;
else begin
	if (advance_pipeline_seg2)
		micro_machine_active_q <= micro_machine_active_r;
end
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
	pc0_r <= pg_dec.pr0.pc;//pc0_d;
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pc1_r <= pg_dec.pr1.pc;//pc1_d;
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pc2_r <= pg_dec.pr2.pc;//pc2_d;
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pc3_r <= pg_dec.pr3.pc;//pc3_d;
*/
always_ff @(posedge clk)
if (rst) begin
	pg_ren.pr0 <= nopi;
	pg_ren.pr1 <= nopi;
	pg_ren.pr2 <= nopi;
	pg_ren.pr3 <= nopi;
end
else begin
	if (en) begin
		pg_ren.hdr.cndx <= cndx;
		pg_ren.pr0 <= pg_dec.pr0;
		if (pg_dec.pr0.v & ~stomp_ren) begin
			pg_ren.pr0.nRd <= Rt0_dec;
			if (pg_ren.pr3.decbus.bl)
				pg_ren.pr0.v <= INV;
		end
		else begin
//			pg_ren.pr0 <= nopi;
			pg_ren.pr0.v <= INV;
//			pg_ren.pr0.decbus.Rt <= pg_ren.pr0.decbus.Rt;
//			pg_ren.pr0.decbus.Rtn <= pg_ren.pr0.decbus.Rtn;
//			pg_ren.pr0.decbus.Rtz <= pg_ren.pr0.decbus.Rtz;
//			pg_ren.pr0.aRt <= pg_ren.pr0.aRt;
			if (Stark_pkg::SUPPORT_BACKOUT)
				pg_ren.pr0.nRd <= 9'd0;//pg_ren.pr0.nRt;
			else
				pg_ren.pr0.nRd <= Rt0_dec;
		end
	/*
	if (bo_wr) begin
		if (pg_dec.pr0.aRa==bo_areg)
			pg_ren.pr0.pRa <= bo_preg;
		if (pg_dec.pr0.aRb==bo_areg)
			pg_ren.pr0.pRb <= bo_preg;
		if (pg_dec.pr0.aRc==bo_areg)
			pg_ren.pr0.pRc <= bo_preg;
		if (pg_dec.pr0.aRt==bo_areg)
			pg_ren.pr0.pRt <= bo_preg;
	end
	*/
		pg_ren.pr1 <= pg_dec.pr1;
		if (pg_dec.pr1.v & ~stomp_ren) begin
			pg_ren.pr1.nRd <= Rt1_dec;
			if (pg_dec.pr0.decbus.bl)
				pg_ren.pr1.v <= INV;
			if (pg_ren.pr3.decbus.bl)
				pg_ren.pr1.v <= INV;
		end
		else begin
//			pg_ren.pr1 <= nopi;
			pg_ren.pr1.v <= INV;
//			pg_ren.pr1.decbus.Rt <= pg_ren.pr1.decbus.Rt;
//			pg_ren.pr1.decbus.Rtn <= pg_ren.pr1.decbus.Rtn;
//			pg_ren.pr1.decbus.Rtz <= pg_ren.pr1.decbus.Rtz;
//			pg_ren.pr1.aRt <= pg_ren.pr1.aRt;
			if (Stark_pkg::SUPPORT_BACKOUT)
				pg_ren.pr1.nRd <= 9'd0;//pg_ren.pr1.nRt;
			else
				pg_ren.pr1.nRd <= Rt1_dec;
		end
		pg_ren.pr2 <= pg_dec.pr2;
		if (pg_dec.pr2.v & ~stomp_ren) begin
			pg_ren.pr2.nRd <= Rt2_dec;
			if (pg_dec.pr0.decbus.bl || pg_dec.pr1.decbus.bl)
				pg_ren.pr2.v <= INV;
			if (pg_ren.pr3.decbus.bl)
				pg_ren.pr2.v <= INV;
		end
		else begin
//			pg_ren.pr2 <= nopi;
			pg_ren.pr2.v <= INV;
//			pg_ren.pr2.decbus.Rt <= pg_ren.pr2.decbus.Rt;
//			pg_ren.pr2.decbus.Rtn <= pg_ren.pr2.decbus.Rtn;
//			pg_ren.pr2.decbus.Rtz <= pg_ren.pr2.decbus.Rtz;
//			pg_ren.pr2.aRt <= pg_ren.pr2.aRt;
			if (Stark_pkg::SUPPORT_BACKOUT)
				pg_ren.pr2.nRd <= 9'd0;//pg_ren.pr2.nRt;
			else
				pg_ren.pr2.nRd <= Rt2_dec;
		end
		pg_ren.pr3 <= pg_dec.pr3;
		if (pg_dec.pr3.v & ~stomp_ren) begin
			pg_ren.pr3.nRd <= Rt3_dec;
			if (pg_dec.pr0.decbus.bl || pg_dec.pr1.decbus.bl || pg_dec.pr2.decbus.bl)
				pg_ren.pr3.v <= INV;
			if (pg_ren.pr3.decbus.bl)
				pg_ren.pr3.v <= INV;
		end
		else begin
//			pg_ren.pr3 <= nopi;
			pg_ren.pr3.v <= INV;
//			pg_ren.pr3.decbus.Rt <= pg_ren.pr3.decbus.Rt;
//			pg_ren.pr3.decbus.Rtn <= pg_ren.pr3.decbus.Rtn;
//			pg_ren.pr3.decbus.Rtz <= pg_ren.pr3.decbus.Rtz;
//			pg_ren.pr3.aRt <= pg_ren.pr3.aRt;
			if (Stark_pkg::SUPPORT_BACKOUT)
				pg_ren.pr3.nRd <= 9'd0;//pg_ren.pr3.nRt;
			else
				pg_ren.pr3.nRd <= Rt3_dec;
		end
	end
	if (branch_state==Stark_pkg::BS_DONE)
		tInvalidateRen(stomp_bno);//misspc.bno_t);
end

// fet/mux/dec stages can be invalidated by turning the instruction in the
// pipeline into a NOP operation. That is handled in the pipeline_seg1
// module.
// Rename stage needs its own invalidation as registers have been renamed
// already, instructions must be turned into copy targets.

task tInvalidateRen;
input [4:0] bno;
begin
	if (pg_ren.pr0.pc.bno_t!=bno) begin
		pg_ren.pr0.excv <= INV;
		if (Stark_pkg::SUPPORT_BACKOUT)
			pg_ren.pr0.v <= INV;
		else begin
			pg_ren.pr0.decbus.cpytgt <= TRUE;
			pg_ren.pr0.decbus.alu <= TRUE;
			pg_ren.pr0.decbus.fpu <= FALSE;
			pg_ren.pr0.decbus.fc <= FALSE;
			pg_ren.pr0.decbus.mem <= FALSE;
		end
	end
	if (pg_ren.pr1.pc.bno_t!=bno) begin
		pg_ren.pr1.v <= INV;
		if (Stark_pkg::SUPPORT_BACKOUT)
			pg_ren.pr1.excv <= INV;
		else begin
			pg_ren.pr1.decbus.cpytgt <= TRUE;
			pg_ren.pr1.decbus.alu <= TRUE;
			pg_ren.pr1.decbus.fpu <= FALSE;
			pg_ren.pr1.decbus.fc <= FALSE;
			pg_ren.pr1.decbus.mem <= FALSE;
		end
	end
	if (pg_ren.pr2.pc.bno_t!=bno) begin
		pg_ren.pr2.excv <= INV;
		if (Stark_pkg::SUPPORT_BACKOUT)
			pg_ren.pr2.v <= INV;
		else begin
			pg_ren.pr2.decbus.cpytgt <= TRUE;
			pg_ren.pr2.decbus.alu <= TRUE;
			pg_ren.pr2.decbus.fpu <= FALSE;
			pg_ren.pr2.decbus.fc <= FALSE;
			pg_ren.pr2.decbus.mem <= FALSE;
		end
	end
	if (pg_ren.pr3.pc.bno_t!=bno) begin
		pg_ren.pr3.excv <= INV;
		if (Stark_pkg::SUPPORT_BACKOUT)
			pg_ren.pr3.v <= INV;
		else begin
			pg_ren.pr3.decbus.cpytgt <= TRUE;
			pg_ren.pr3.decbus.alu <= TRUE;
			pg_ren.pr3.decbus.fpu <= FALSE;
			pg_ren.pr3.decbus.fc <= FALSE;
			pg_ren.pr3.decbus.mem <= FALSE;
		end
	end
end
endtask

endmodule

