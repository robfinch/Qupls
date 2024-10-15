// ============================================================================
//        __
//   \\__/ o\    (C) 2024  Robert Finch, Waterloo
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
import QuplsPkg::*;

module Qupls_pipeline_ren(rst, clk, clk5x, ph4, restore, );
input rst;
input clk;
input clk5x;
input [4:0] ph4;
input restore;

wire restored;
wire [PREGS-1:0] restore_list;
pregno_t [3:0] tags2free;
wire [3:0] freevals;

generate begin : gRenamer
	if (SUPPORT_RENAMER) begin
	if (RENAMER==3) begin
Qupls_reg_renamer3 utrn2
(
	.rst(rst_i),		// rst_i here not irst!
	.clk(clk),
	.clk5x(clk5x),
	.ph4(ph4),
	.en(advance_pipeline_seg2),
	.restore(restored),
	.restore_list(restore_list),
	.tags2free(tags2free),
	.freevals(freevals),
	.alloc0(ins0_dec.aRt!=8'd0 && ins0_dec.v),// & ~stomp0),
	.alloc1(ins1_dec.aRt!=8'd0 && ins1_dec.v),// & ~stomp1),
	.alloc2(ins2_dec.aRt!=8'd0 && ins2_dec.v),// & ~stomp2),
	.alloc3(ins3_dec.aRt!=8'd0 && ins3_dec.v),// & ~stomp3),
	.wo0(Rt0_dec),
	.wo1(Rt1_dec),
	.wo2(Rt2_dec),
	.wo3(Rt3_dec),
	.wv0(Rt0_decv),
	.wv1(Rt1_decv),
	.wv2(Rt2_decv),
	.wv3(Rt3_decv),
	.avail(avail_reg),
	.stall(ren_stallq)
);
assign ren_rst_busy = FALSE;
end
else if (RENAMER==4)
Qupls_reg_renamer4 utrn1
(
	.rst(rst_i),		// rst_i here not irst!
	.clk(clk),
//	.clk5x(clk5x),
//	.ph4(ph4),
	.en(advance_pipeline_seg2),
	.restore(restored),
	.restore_list(restore_list),
	.tags2free(tags2free),
	.freevals(freevals),
	.alloc0(ins0_dec.aRt!=8'd0 && ins0_dec.v),// & ~stomp0),
	.alloc1(ins1_dec.aRt!=8'd0 && ins1_dec.v),// & ~stomp1),
	.alloc2(ins2_dec.aRt!=8'd0 && ins2_dec.v),// & ~stomp2),
	.alloc3(ins3_dec.aRt!=8'd0 && ins3_dec.v),// & ~stomp3),
	.wo0(Rt0_dec),
	.wo1(Rt1_dec),
	.wo2(Rt2_dec),
	.wo3(Rt3_dec),
	.wv0(Rt0_decv),
	.wv1(Rt1_decv),
	.wv2(Rt2_decv),
	.wv3(Rt3_decv),
	.avail(avail_reg),
	.stall(ren_stallq),
	.rst_busy(ren_rst_busy)
);
else
Qupls_reg_renamer6 utrn1
(
	.rst(rst_i),		// rst_i here not irst!
	.clk(clk),
//	.clk5x(clk5x),
//	.ph4(ph4),
	.en(advance_pipeline_seg2),
	.restore(restored),
	.restore_list(restore_list),
	.tags2free(tags2free),
	.freevals(freevals),
	.alloc0(ins0_dec.aRt!=8'd0 && ins0_dec.v && !ins3_ren.decbus.bsr),// & ~stomp0),
	.alloc1(ins1_dec.aRt!=8'd0 && ins1_dec.v && !ins3_ren.decbus.bsr&& !ins0_dec.decbus.bsr),// & ~stomp1),
	.alloc2(ins2_dec.aRt!=8'd0 && ins2_dec.v && !ins3_ren.decbus.bsr&& !ins0_dec.decbus.bsr && !ins1_dec.decbus.bsr),// & ~stomp2),
	.alloc3(ins3_dec.aRt!=8'd0 && ins3_dec.v && !ins3_ren.decbus.bsr&& !ins0_dec.decbus.bsr && !ins1_dec.decbus.bsr && !ins2_dec.decbus.bsr),// & ~stomp3),
	.wo0(Rt0_dec),
	.wo1(Rt1_dec),
	.wo2(Rt2_dec),
	.wo3(Rt3_dec),
	.wv0(Rt0_decv),
	.wv1(Rt1_decv),
	.wv2(Rt2_decv),
	.wv3(Rt3_decv),
	.avail(avail_reg),
	.stall(ren_stallq),
	.rst_busy(ren_rst_busy)
);
end
else begin
	assign Rt0_dec = ins0_dec.aRt;
	assign Rt1_dec = ins1_dec.aRt;
	assign Rt2_dec = ins2_dec.aRt;
	assign Rt3_dec = ins3_dec.aRt;
	assign Rt0_decv = TRUE;
	assign Rt1_decv = TRUE;
	assign Rt2_decv = TRUE;
	assign Rt3_decv = TRUE;
	assign ren_stallq = FALSE;
	assign ren_rst_busy = FALSE;
end
//assign ren_rst_busy = 1'b0;
end
endgenerate

always_ff @(posedge clk)
if (irst)
	Rt0_ren <= 9'd0;
else begin
	if (advance_pipeline_seg2) 
		Rt0_ren <= Rt0_decv ? Rt0_dec : 9'd0;
end
always_ff @(posedge clk)
if (irst)
	Rt1_ren <= 10'd0;
else begin
	if (advance_pipeline_seg2) 
		Rt1_ren <= Rt1_decv ? Rt1_dec : 9'd0;
end
always_ff @(posedge clk)
if (irst)
	Rt2_ren <= 10'd0;
else begin
	if (advance_pipeline_seg2) 
		Rt2_ren <= Rt2_decv ? Rt2_dec : 9'd0;
end
always_ff @(posedge clk)
if (irst)
	Rt3_ren <= 10'd0;
else begin
	if (advance_pipeline_seg2) 
		Rt3_ren <= Rt3_decv ? Rt3_dec : 9'd0;
end

always_ff @(posedge clk) if (irst) Rt0_renv <= 1'b0; else if (advance_pipeline_seg2) Rt0_renv <= Rt0_decv;
always_ff @(posedge clk) if (irst) Rt1_renv <= 1'b0; else if (advance_pipeline_seg2) Rt1_renv <= Rt1_decv;
always_ff @(posedge clk) if (irst) Rt2_renv <= 1'b0; else if (advance_pipeline_seg2) Rt2_renv <= Rt2_decv;
always_ff @(posedge clk) if (irst) Rt3_renv <= 1'b0; else if (advance_pipeline_seg2) Rt3_renv <= Rt3_decv;

always_comb Rt0_q1 = Rt0_ren;// & {10{~ins0_ren.decbus.Rtz & ~stomp0}};
always_comb Rt1_q1 = Rt1_ren;// & {10{~ins1_ren.decbus.Rtz & ~stomp1}};
always_comb Rt2_q1 = Rt2_ren;// & {10{~ins2_ren.decbus.Rtz & ~stomp2}};
always_comb Rt3_q1 = Rt3_ren;// & {10{~ins3_ren.decbus.Rtz & ~stomp3}};
always_comb Rt0_que = Rt0_ren;
always_comb Rt1_que = Rt1_ren;
always_comb Rt2_que = Rt2_ren;
always_comb Rt3_que = Rt3_ren;
/*
always_ff @(posedge clk)
if (irst)
	Rt0_que <= 8'd0;
else begin
	if (advance_pipeline_seg2)
		Rt0_que <= Rt0_ren;
end
always_ff @(posedge clk)
if (irst)
	Rt1_que <= 8'd0;
else begin
	if (advance_pipeline_seg2)
		Rt1_que <= Rt1_ren;
end
always_ff @(posedge clk)
if (irst)
	Rt2_que <= 8'd0;
else begin
	if (advance_pipeline_seg2)
		Rt2_que <= Rt2_ren;
end
always_ff @(posedge clk)
if (irst)
	Rt3_que <= 8'd0;
else begin
	if (advance_pipeline_seg2)
		Rt3_que <= Rt3_ren;
end
always_ff @(posedge clk)
if (irst)
	Rt0_q1 <= 8'd0;
else begin
	if (advance_pipeline_seg2)
		Rt0_q1 <= Rt0_ren;
end
always_ff @(posedge clk)
if (irst)
	Rt1_q1 <= 8'd0;
else begin
	if (advance_pipeline_seg2)
		Rt1_q1 <= Rt1_ren;
end
always_ff @(posedge clk)
if (irst)
	Rt2_q1 <= 8'd0;
else begin
	if (advance_pipeline_seg2)
		Rt2_q1 <= Rt2_ren;
end
always_ff @(posedge clk)
if (irst)
	Rt3_q1 <= 8'd0;
else begin
	if (advance_pipeline_seg2)
		Rt3_q1 <= Rt3_ren;
end
*/

always_ff @(posedge clk)
if (irst)
	Rt0_pq <= 11'd0;
else begin
	if (advance_pipeline_seg2)
		Rt0_pq <= Rt0_ren;
end
always_ff @(posedge clk)
if (irst)
	Rt1_pq <= 11'd0;
else begin
	if (advance_pipeline_seg2)
		Rt1_pq <= Rt1_ren;
end
always_ff @(posedge clk)
if (irst)
	Rt2_pq <= 11'd0;
else begin
	if (advance_pipeline_seg2)
		Rt2_pq <= Rt2_ren;
end
always_ff @(posedge clk)
if (irst)
	Rt3_pq <= 11'd0;
else begin
	if (advance_pipeline_seg2)
		Rt3_pq <= Rt3_ren;
end

/*
always_ff @(posedge clk)
if (advance_pipeline) begin
	if (alloc0 && ins0_ren.decbus.Rt==0) begin
		$display("alloced r0");
		$finish;
	end
	if (alloc1 && ins1_ren.decbus.Rt==0) begin
		$display("alloced r0");
		$finish;
	end
	if (alloc2 && ins2_ren.decbus.Rt==0) begin
		$display("alloced r0");
		$finish;
	end
	if (alloc3 && ins3_ren.decbus.Rt==0) begin
		$display("alloced r0");
		$finish;
	end
end
*/
/*
always_ff @(posedge clk)
begin
	if (!stallq && (ins0_ren.decbus.Rt==7'd63 ||
		ins1_ren.decbus.Rt==7'd63 ||
		ins2_ren.decbus.Rt==7'd63 ||
		ins3_ren.decbus.Rt==7'd63
	))
		$finish;
	for (n19 = 0; n19 < 16; n19 = n19 + 1)
		if (arn[n19]==7'd63)
			$finish;
end
*/

reg free_chkpt;
checkpt_ndx_t fchkpt;
checkpt_ndx_t miss_cp;
always_comb
	miss_cp = rob[missid].cndx;
assign cndx1 = cndx0;
assign cndx2 = cndx0;
assign cndx3 = cndx0;

`ifdef SUPPORT_RAT
Qupls_rat #(.NPORT(24)) urat1
(	
	.rst(irst),
	.clk(clk),
	.clk5x(clk5x),
	.ph4(ph4),
	.en(advance_pipeline),
	.en2(advance_pipeline_seg2),
	.nq(nq),
	.inc_chkpt(inc_chkpt),
	.chkpt_inc_amt(chkpt_inc_amt),
	.stallq(rat_stallq),
	.cndx_o(cndx0),
	.pcndx_o(),
	.tail(tail0),
	.rob(rob),
	.stomp(robentry_stomp),// & {32{branch_state==BS_CAPTURE_MISSPC}}),
	.avail_i(avail_reg),
	.restore(restore_chkpt),
	.miss_cp(miss_cp),
	.qbr0(ins0_dec.decbus.br),
	.qbr1(ins1_dec.decbus.br),
	.qbr2(ins2_dec.decbus.br),
	.qbr3(ins3_dec.decbus.br),
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
	.wr0(Rt0_decv && ins0_dec.aRt!=8'd0),// && !stomp0 && ~ins0_ren.decbus.Rtz),
	.wr1(Rt1_decv && ins1_dec.aRt!=8'd0),// && !stomp1 && ~ins1_ren.decbus.Rtz),
	.wr2(Rt2_decv && ins2_dec.aRt!=8'd0),// && !stomp2 && ~ins2_ren.decbus.Rtz),
	.wr3(Rt3_decv && ins3_dec.aRt!=8'd0),// && !stomp3 && ~ins3_ren.decbus.Rtz),
	.wra(ins0_dec.aRt),
	.wrb(ins1_dec.aRt),
	.wrc(ins2_dec.aRt),
	.wrd(ins3_dec.aRt),
	.wrra(Rt0_dec),
	.wrrb(Rt1_dec),
	.wrrc(Rt2_dec),
	.wrrd(Rt3_dec),
	.wra_cp(cndx0),
	.wrb_cp(cndx0),
	.wrc_cp(cndx0),
	.wrd_cp(cndx0),
	.cmtbanka(1'b0),
	.cmtbankb(1'b0),
	.cmtbankc(1'b0),
	.cmtbankd(1'b0),
	.cmtav(wrport0_v),
	.cmtbv(wrport1_v),
	.cmtcv(wrport2_v),
	.cmtdv(wrport3_v),
	.cmtaa(wrport0_aRt),
	.cmtba(wrport1_aRt),
	.cmtca(wrport2_aRt),
	.cmtda(wrport3_aRt),
	.cmtap(wrport0_Rt),
	.cmtbp(wrport1_Rt),
	.cmtcp(wrport2_Rt),
	.cmtdp(wrport3_Rt),
	.cmtaval(wrport0_res),
	.cmtbval(wrport1_res),
	.cmtcval(wrport2_res),
	.cmtdval(wrport3_res),
	.cmta_cp(wrport0_cp),
	.cmtb_cp(wrport1_cp),
	.cmtc_cp(wrport2_cp),
	.cmtd_cp(wrport3_cp),
	.cmtbr(cmtbr),
	.restore_list(restore_list),
	.restored(restored),
	.tags2free(tags2free),
	.freevals(freevals),
	.free_chkpt_i(free_chkpt),
	.fchkpt_i(fchkpt),
	.backout(backout),
	.fcu_id(fcu_id),
	.bo_wr(bo_wr),
	.bo_areg(bo_areg),
	.bo_preg(bo_preg)	
);
`else
	assign rat_stallq = FALSE;
	assign cndx0 = 4'd0;
	assign bo_wr = FALSE;
	assign bo_areg = 8'd0;
	assign bo_preg = 9'd0;
	assign prnv = 24'hFFFFFF;
	always_ff @(posedge clk)
	if (irst) begin
		for (n5 = 0; n5 < 24; n5 = n5 + 1)
			prn[n5] <= 9'd0;
	end
	else begin
		if (advance_pipeline_seg2)
		begin
			for (n5 = 0; n5 < 24; n5 = n5 + 1)
				prn[n5] <= {1'b0,arn[n5]};
		end
	end
	/*
	always_comb
	if (irst) begin
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
always_ff @(posedge clk) if (advance_pipeline_seg2) mcip0_ren <= mcip0_dec;
always_ff @(posedge clk) if (advance_pipeline_seg2) mcip1_ren <= mcip1_dec;
always_ff @(posedge clk) if (advance_pipeline_seg2) mcip2_ren <= mcip2_dec;
always_ff @(posedge clk) if (advance_pipeline_seg2) mcip3_ren <= mcip3_dec;
always_ff @(posedge clk) if (advance_pipeline_seg2) mcip0_que <= mcip0_ren;
always_ff @(posedge clk) if (advance_pipeline_seg2) mcip1_que <= mcip1_ren;
always_ff @(posedge clk) if (advance_pipeline_seg2) mcip2_que <= mcip2_ren;
always_ff @(posedge clk) if (advance_pipeline_seg2) mcip3_que <= mcip3_ren;

always_ff @(posedge clk)
if (irst) begin
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

/*
always_ff @(posedge clk)
if (irst)
	micro_code_active_f <= TRUE;
else begin
	if (advance_pipeline)
		micro_code_active_f <= micro_code_active;
end
*/
always_ff @(posedge clk)
if (irst)
	micro_code_active_x <= FALSE;
else begin
	if (advance_pipeline)
		micro_code_active_x <= micro_code_active;
end
/*
always_comb
	micro_code_active_x = micro_code_active;
*/
always_ff @(posedge clk)
if (irst)
	micro_code_active_d <= FALSE;
else begin
	if (advance_pipeline)
		micro_code_active_d <= micro_code_active_x;
end
always_ff @(posedge clk)
if (irst)
	micro_code_active_r <= FALSE;
else begin
	if (advance_pipeline_seg2)
		micro_code_active_r <= micro_code_active_d;
end
always_ff @(posedge clk)
if (irst)
	micro_code_active_q <= FALSE;
else begin
	if (advance_pipeline_seg2)
		micro_code_active_q <= micro_code_active_r;
end

// The cycle after the length is calculated
// instruction extract inputs
pc_address_ex_t pc0_x1;
always_ff @(posedge clk)
if (irst) begin
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
 	pc0_fet = micro_code_active ? mc_adr : pc0_x1;
end
always_comb 
begin
	pc1_fet = pc0_fet;
	pc1_fet.pc = micro_code_active ? pc0_fet.pc : pc0_fet.pc + 6'd8;
end
always_comb
begin
	pc2_fet = pc0_fet;
	pc2_fet.pc = micro_code_active ? pc0_fet.pc : pc0_fet.pc + 6'd16;
end
always_comb
begin
	pc3_fet = pc0_fet;
	pc3_fet.pc = micro_code_active ? pc0_fet.pc : pc0_fet.pc + 6'd24;
end

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

// Register fetch/rename stage inputs
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pc0_r <= ins0_dec.pc;//pc0_d;
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pc1_r <= ins1_dec.pc;//pc1_d;
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pc2_r <= ins2_dec.pc;//pc2_d;
always_ff @(posedge clk)
if (advance_pipeline_seg2)
	pc3_r <= ins3_dec.pc;//pc3_d;

always_ff @(posedge clk)
if (irst) begin
	ins0_ren <= nopi;
	ins1_ren <= nopi;
	ins2_ren <= nopi;
	ins3_ren <= nopi;
end
else begin
	if (advance_pipeline_seg2) begin
		if (ins0_dec.v) begin
			ins0_ren <= ins0_dec;
			ins0_ren.nRt <= Rt0_dec;
			if (ins3_ren.decbus.bsr)
				ins0_ren.v <= INV;
		end
		else begin
			ins0_ren <= nopi;
			ins0_ren.decbus.Rt <= ins0_ren.decbus.Rt;
			ins0_ren.decbus.Rtn <= ins0_ren.decbus.Rtn;
			ins0_ren.decbus.Rtz <= ins0_ren.decbus.Rtz;
			ins0_ren.aRt <= ins0_ren.aRt;
			ins0_ren.nRt <= ins0_ren.nRt;
		end
	end
	/*
	if (bo_wr) begin
		if (ins0_dec.aRa==bo_areg)
			ins0_ren.pRa <= bo_preg;
		if (ins0_dec.aRb==bo_areg)
			ins0_ren.pRb <= bo_preg;
		if (ins0_dec.aRc==bo_areg)
			ins0_ren.pRc <= bo_preg;
		if (ins0_dec.aRt==bo_areg)
			ins0_ren.pRt <= bo_preg;
	end
	*/
	if (advance_pipeline_seg2) begin
		if (ins1_dec.v) begin
			ins1_ren <= ins1_dec;
			ins1_ren.nRt <= Rt1_dec;
			if (ins0_dec.decbus.bsr)
				ins1_ren.v <= INV;
			if (ins3_ren.decbus.bsr)
				ins1_ren.v <= INV;
		end
		else begin
			ins1_ren <= nopi;
			ins1_ren.decbus.Rt <= ins1_ren.decbus.Rt;
			ins1_ren.decbus.Rtn <= ins1_ren.decbus.Rtn;
			ins1_ren.decbus.Rtz <= ins1_ren.decbus.Rtz;
			ins1_ren.aRt <= ins1_ren.aRt;
			ins1_ren.nRt <= ins1_ren.nRt;
		end
	end
	if (advance_pipeline_seg2) begin
		if (ins2_dec.v) begin
			ins2_ren <= ins2_dec;
			ins2_ren.nRt <= Rt2_dec;
			if (ins0_dec.decbus.bsr || ins1_dec.decbus.bsr)
				ins2_ren.v <= INV;
			if (ins3_ren.decbus.bsr)
				ins2_ren.v <= INV;
		end
		else begin
			ins2_ren <= nopi;
			ins2_ren.decbus.Rt <= ins2_ren.decbus.Rt;
			ins2_ren.decbus.Rtn <= ins2_ren.decbus.Rtn;
			ins2_ren.decbus.Rtz <= ins2_ren.decbus.Rtz;
			ins2_ren.aRt <= ins2_ren.aRt;
			ins2_ren.nRt <= ins2_ren.nRt;
		end
	end
	if (advance_pipeline_seg2) begin
		if (ins3_dec.v) begin
			ins3_ren <= ins3_dec;
			ins3_ren.nRt <= Rt3_dec;
			if (ins0_dec.decbus.bsr || ins1_dec.decbus.bsr || ins2_dec.decbus.bsr)
				ins3_ren.v <= INV;
			if (ins3_ren.decbus.bsr)
				ins3_ren.v <= INV;
		end
		else begin
			ins3_ren <= nopi;
			ins3_ren.decbus.Rt <= ins3_ren.decbus.Rt;
			ins3_ren.decbus.Rtn <= ins3_ren.decbus.Rtn;
			ins3_ren.decbus.Rtz <= ins3_ren.decbus.Rtz;
			ins3_ren.aRt <= ins3_ren.aRt;
			ins3_ren.nRt <= ins3_ren.nRt;
		end
	end
	if (branch_state==BS_DONE)
		tInvalidateRen(stomp_bno);//misspc.bno_t);
end

endmodule

