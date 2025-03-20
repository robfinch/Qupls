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
// 5800 LUTs / 4800 FFs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import QuplsPkg::*;

module Qupls_pipeline_dec(rst_i, rst, clk, en, clk5x, ph4,
	restored, restore_list, unavail_list, sr,
	tags2free, freevals, bo_wr, bo_preg,
	ins0_dec_inv, ins1_dec_inv, ins2_dec_inv, ins3_dec_inv,
	stomp_dec, stomp_mux, stomp_bno, ins0_mux, ins1_mux, ins2_mux, ins3_mux, ins4_mux,
	Rt0_dec, Rt1_dec, Rt2_dec, Rt3_dec, Rt0_decv, Rt1_decv, Rt2_decv, Rt3_decv,
	micro_code_active_mux, micro_code_active_dec,
	ins0_dec, ins1_dec, ins2_dec, ins3_dec, pc0_dec, pc1_dec, pc2_dec, pc3_dec,
	ren_stallq, ren_rst_busy, avail_reg
);
input rst_i;
input rst;
input clk;
input en;
input clk5x;
input [4:0] ph4;
input restored;
input [PREGS-1:0] restore_list;
input [PREGS-1:0] unavail_list;
input status_reg_t sr;
input stomp_dec;
input stomp_mux;
input [4:0] stomp_bno;
input pipeline_reg_t ins0_mux;
input pipeline_reg_t ins1_mux;
input pipeline_reg_t ins2_mux;
input pipeline_reg_t ins3_mux;
input pipeline_reg_t ins4_mux;
input pregno_t [3:0] tags2free;
input [3:0] freevals;
input bo_wr;
input pregno_t bo_preg;
input ins0_dec_inv;
input ins1_dec_inv;
input ins2_dec_inv;
input ins3_dec_inv;
output pregno_t Rt0_dec;
output pregno_t Rt1_dec;
output pregno_t Rt2_dec;
output pregno_t Rt3_dec;
output Rt0_decv;
output Rt1_decv;
output Rt2_decv;
output Rt3_decv;
output pipeline_reg_t ins0_dec;
output pipeline_reg_t ins1_dec;
output pipeline_reg_t ins2_dec;
output pipeline_reg_t ins3_dec;
output pc_address_ex_t pc0_dec;
output pc_address_ex_t pc1_dec;
output pc_address_ex_t pc2_dec;
output pc_address_ex_t pc3_dec;
output ren_stallq;
output ren_rst_busy;
input micro_code_active_mux;
output reg micro_code_active_dec;
output [PREGS-1:0] avail_reg;

pipeline_reg_t ins0m;
pipeline_reg_t ins1m;
pipeline_reg_t ins2m;
pipeline_reg_t ins3m;
pipeline_reg_t ins4d;
pipeline_reg_t nopi;
decode_bus_t dec0,dec1,dec2,dec3,dec4;
pipeline_reg_t pr_dec0,pr_dec1,pr_dec2,pr_dec3;
pipeline_reg_t [3:0] prd, inso;
pregno_t Rt0_dec1;
pregno_t Rt1_dec1;
pregno_t Rt2_dec1;
pregno_t Rt3_dec1;

//reg stomp_dec;

// Define a NOP instruction.
always_comb
begin
	nopi = {$bits(pipeline_reg_t){1'b0}};
	nopi.exc = FLT_NONE;
	nopi.pc.pc = RSTPC;
	nopi.mcip = 12'h1A0;
	nopi.len = 4'd8;
	nopi.ins = {57'd0,OP_NOP};
	nopi.pred_btst = 6'd0;
	nopi.element = 'd0;
	nopi.aRa = 8'd0;
	nopi.aRb = 8'd0;
	nopi.aRc = 8'd0;
	nopi.aRt = 8'd0;
	nopi.v = 1'b1;
	nopi.decbus.Rtz = 1'b1;
	nopi.decbus.nop = 1'b1;
	nopi.decbus.alu = 1'b1;
end

generate begin : gRenamer
	if (SUPPORT_RENAMER) begin
	if (RENAMER==3) begin
Qupls_reg_renamer3 utrn2
(
	.rst(rst_i),		// rst_i here not irst!
	.clk(clk),
	.clk5x(clk5x),
	.ph4(ph4),
	.en(en),
	.restore(restored),
	.restore_list(restore_list & ~unavail_list),
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
	.en(en),
	.restore(restored),
	.restore_list(restore_list & ~unavail_list),
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

Qupls_reg_name_supplier2 utrn1
(
	.rst(rst_i),		// rst_i here not irst!
	.clk(clk),
//	.clk5x(clk5x),
//	.ph4(ph4),
	.en(en),
	.restore(restored),
	.restore_list(restore_list & ~unavail_list),
	.tags2free(tags2free),
	.freevals(freevals),
	.bo_wr(bo_wr),
	.bo_preg(bo_preg),
	.alloc0(ins0_dec.aRt!=8'd0 && ins0_dec.v ),// & ~stomp0),
	.alloc1(ins1_dec.aRt!=8'd0 && ins1_dec.v && !ins0_dec.decbus.bsr),// & ~stomp1),
	.alloc2(ins2_dec.aRt!=8'd0 && ins2_dec.v && !ins0_dec.decbus.bsr && !ins1_dec.decbus.bsr),// & ~stomp2),
	.alloc3(ins3_dec.aRt!=8'd0 && ins3_dec.v && !ins0_dec.decbus.bsr && !ins1_dec.decbus.bsr && !ins2_dec.decbus.bsr),// & ~stomp3),
	.o0(Rt0_dec1),
	.o1(Rt1_dec1),
	.o2(Rt2_dec1),
	.o3(Rt3_dec1),
	.ov0(Rt0_decv),
	.ov1(Rt1_decv),
	.ov2(Rt2_decv),
	.ov3(Rt3_decv),
	.avail(avail_reg),
	.stall(ren_stallq),
	.rst_busy(ren_rst_busy)
);
assign Rt0_dec = ins0_dec.aRt==8'd0 ? 9'd0 : Rt0_dec1;
assign Rt1_dec = ins1_dec.aRt==8'd0 ? 9'd0 : Rt1_dec1;
assign Rt2_dec = ins2_dec.aRt==8'd0 ? 9'd0 : Rt2_dec1;
assign Rt3_dec = ins3_dec.aRt==8'd0 ? 9'd0 : Rt3_dec1;
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

/*
always_comb
	micro_code_active_x = micro_code_active;
*/
always_ff @(posedge clk)
if (rst)
	micro_code_active_dec <= FALSE;
else begin
	if (en)
		micro_code_active_dec <= micro_code_active_mux;
end

/*
always_ff @(posedge clk)
if (rst)
	stomp_dec <= FALSE;
else begin
	if (en)
		stomp_dec <= stomp_mux;
end
*/

always_ff @(posedge clk)
if (rst) begin
	ins0m <= {$bits(pipeline_reg_t){1'b0}};
end
else begin
	if (en)
	begin
		ins0m <= ins0_mux;
		if (stomp_mux && FALSE) begin
			if (ins0_mux.pc.bno_t!=stomp_bno) begin
				ins0m <= nopi;
				ins0m.pc.bno_t <= ins0_mux.pc.bno_t;
			end
		end
	end
end

always_ff @(posedge clk)
if (rst) begin
	ins1m <= {$bits(pipeline_reg_t){1'b0}};
end
else begin
	if (en)
	begin
		ins1m <= ins1_mux;
		if (stomp_mux && FALSE) begin
			if (ins1_mux.pc.bno_t!=stomp_bno) begin
				ins1m <= nopi;
				ins1m.pc.bno_t <= ins1_mux.pc.bno_t;
			end
		end
	end
end

always_ff @(posedge clk)
if (rst) begin
	ins2m <= {$bits(pipeline_reg_t){1'b0}};
end
else begin
	if (en)
	begin
		ins2m <= ins2_mux;
		if (stomp_mux && FALSE) begin
			if (ins2_mux.pc.bno_t!=stomp_bno) begin
				ins2m <= nopi;
				ins2m.pc.bno_t <= ins2_mux.pc.bno_t;
			end
		end
	end
end

always_ff @(posedge clk)
if (rst) begin
	ins3m <= {$bits(pipeline_reg_t){1'b0}};
end
else begin
	if (en)
	begin
		ins3m <= ins3_mux;
		if (stomp_mux && FALSE) begin
			if (ins3_mux.pc.bno_t!=stomp_bno) begin
				ins3m <= nopi;
				ins3m.pc.bno_t <= ins3_mux.pc.bno_t;
			end
		end
	end
end

Qupls_decoder udeci0
(
	.rst(rst),
	.clk(clk),
	.en(en),
	.om(sr.om),
	.ipl(sr.ipl),
	.instr(ins0_mux),
	.dbo(dec0)
);

Qupls_decoder udeci1
(
	.rst(rst),
	.clk(clk),
	.en(en),
	.om(sr.om),
	.ipl(sr.ipl),
	.instr(ins1_mux),
	.dbo(dec1)
);

Qupls_decoder udeci2
(
	.rst(rst),
	.clk(clk),
	.en(en),
	.om(sr.om),
	.ipl(sr.ipl),
	.instr(ins2_mux),
	.dbo(dec2)
);

Qupls_decoder udeci3
(
	.rst(rst),
	.clk(clk),
	.en(en),
	.om(sr.om),
	.ipl(sr.ipl),
	.instr(ins3_mux),
	.dbo(dec3)
);

Qupls_decoder udeci4
(
	.rst(rst),
	.clk(clk),
	.en(en),
	.om(sr.om),
	.ipl(sr.ipl),
	.instr(ins4_mux),
	.dbo(dec4)
);
/*
always_ff @(posedge clk)
if (rst_i) begin
	ins3m <= {$bits(pipeline_reg_t){1'b0}};
end
else begin
	if (en_i)
		ins2m <= (stomp_dec && ((ins0_mux.bt|ins1_mux.bt|ins2_mux.bt|ins3_mux.bt) && branchmiss ? ins3_mux.pc.bno_t==stomp_bno : ins3_mux.pc.bno_f==stomp_bno )) ? nopi : ins3_mux;
//		ins3m <= (stomp_dec && ins3_mux.pc.bno_t==stomp_bno) ? nopi : ins3_mux;
end
*/

always_comb
begin
	
	pr_dec0 = ins0m;
	pr_dec1 = ins1m;
	pr_dec2 = ins2m;
	pr_dec3 = ins3m;
	
	pr_dec0.v = !stomp_dec;
	pr_dec1.v = !stomp_dec;
	pr_dec2.v = !stomp_dec;
	pr_dec3.v = !stomp_dec;
	if (stomp_dec) begin
		// Clear the branch flags so that a new checkpoint is not assigned and
		// the checkpoint will not be freed.
		
		pr_dec0.decbus.br = FALSE;
		pr_dec0.decbus.cjb = FALSE;
		pr_dec1.decbus.br = FALSE;
		pr_dec1.decbus.cjb = FALSE;
		pr_dec2.decbus.br = FALSE;
		pr_dec2.decbus.cjb = FALSE;
		pr_dec3.decbus.br = FALSE;
		pr_dec3.decbus.cjb = FALSE;
		
		pr_dec0.aRa = dec0.Ra;
		pr_dec0.aRb = dec0.Rb;
		pr_dec0.aRc = dec0.Rc;
		pr_dec0.aRt = dec0.Rt;
		pr_dec0.aRm = dec0.Rm;
		pr_dec1.aRa = dec1.Ra;
		pr_dec1.aRb = dec1.Rb;
		pr_dec1.aRc = dec1.Rc;
		pr_dec1.aRt = dec1.Rt;
		pr_dec1.aRm = dec1.Rm;
		pr_dec2.aRa = dec2.Ra;
		pr_dec2.aRb = dec2.Rb;
		pr_dec2.aRc = dec2.Rc;
		pr_dec2.aRt = dec2.Rt;
		pr_dec2.aRm = dec2.Rm;
		pr_dec3.aRa = dec3.Ra;
		pr_dec3.aRb = dec3.Rb;
		pr_dec3.aRc = dec3.Rc;
		pr_dec3.aRt = dec3.Rt;
		pr_dec3.aRm = dec3.Rm;
	end
	else begin
		pr_dec0.aRa = dec0.Ra;
		pr_dec0.aRb = dec0.Rb;
		pr_dec0.aRc = dec0.Rc;
		pr_dec0.aRt = dec0.Rt;
		pr_dec0.aRm = dec0.Rm;
		pr_dec1.aRa = dec1.Ra;
		pr_dec1.aRb = dec1.Rb;
		pr_dec1.aRc = dec1.Rc;
		pr_dec1.aRt = dec1.Rt;
		pr_dec1.aRm = dec1.Rm;
		pr_dec2.aRa = dec2.Ra;
		pr_dec2.aRb = dec2.Rb;
		pr_dec2.aRc = dec2.Rc;
		pr_dec2.aRt = dec2.Rt;
		pr_dec2.aRm = dec2.Rm;
		pr_dec3.aRa = dec3.Ra;
		pr_dec3.aRb = dec3.Rb;
		pr_dec3.aRc = dec3.Rc;
		pr_dec3.aRt = dec3.Rt;
		pr_dec3.aRm = dec3.Rm;
	end
	pr_dec0.decbus = dec0;
	if (dec1.pfxa) begin pr_dec0.decbus.imma = {dec1.imma[63:5],dec0.Ra[4:0]}; pr_dec0.decbus.has_imma = 1'b1; end
	if (dec1.pfxb) begin 
		pr_dec0.decbus.immb = dec0.mem ? {dec1.immb[63:5],dec0.immb[4:0]} : {dec1.immb[63:5],dec0.Rb[4:0]};
		pr_dec0.decbus.has_immb = 1'b1;
	end
	if (dec1.pfxc) begin pr_dec0.decbus.immc = {dec1.immc[63:5],dec0.Rc[4:0]}; pr_dec0.decbus.has_immc = 1'b1; end
	pr_dec1.decbus = dec1;
	if (dec2.pfxa) begin 
		pr_dec1.decbus.imma = {dec2.imma[63:5],dec1.Ra[4:0]};
		pr_dec1.decbus.has_imma = 1'b1;
	end
	if (dec2.pfxb) begin
		pr_dec1.decbus.immb = dec1.mem ? {dec2.immb[63:5],dec1.immb[4:0]} : {dec2.immb[63:5],dec1.Rb[4:0]};
		pr_dec1.decbus.has_immb = 1'b1;
	end
	if (dec2.pfxc) begin pr_dec1.decbus.immc = {dec2.immc[63:5],dec1.Rc[4:0]}; pr_dec1.decbus.has_immc = 1'b1; end
	pr_dec2.decbus = dec2;
	if (dec3.pfxa) begin pr_dec2.decbus.imma = {dec3.imma[63:5],dec2.Ra[4:0]}; pr_dec2.decbus.has_imma = 1'b1; end
	if (dec3.pfxb) begin 
		pr_dec2.decbus.immb = dec2.mem ? {dec3.immb[63:5],dec2.immb[4:0]} : {dec3.immb[63:5],dec2.Rb[4:0]};
		pr_dec2.decbus.has_immb = 1'b1;
	end
	if (dec3.pfxc) begin pr_dec2.decbus.immc = {dec3.immc[63:5],dec2.Rc[4:0]}; pr_dec2.decbus.has_immc = 1'b1; end
	pr_dec3.decbus = dec3;
	if (dec4.pfxa) begin pr_dec3.decbus.imma = {dec4.imma[63:5],dec3.Ra[4:0]}; pr_dec3.decbus.has_imma = 1'b1; end
	if (dec4.pfxb) begin
		pr_dec3.decbus.immb = dec3.mem ? {dec4.immb[63:5],dec3.immb[4:0]} : {dec4.immb[63:5],dec3.Rb[4:0]};
		pr_dec3.decbus.has_immb = 1'b1;
	end
	if (dec4.pfxc) begin pr_dec3.decbus.immc = {dec4.immc[63:5],dec3.Rc[4:0]}; pr_dec3.decbus.has_immc = 1'b1; end
	
	pr_dec0.mcip = ins0m.mcip;
	pr_dec1.mcip = ins1m.mcip;
	pr_dec2.mcip = ins2m.mcip;
	pr_dec3.mcip = ins3m.mcip;
	
	if (ins1_dec_inv) pr_dec1.v = FALSE;
	if (ins2_dec_inv) pr_dec2.v = FALSE;
	if (ins3_dec_inv) pr_dec3.v = FALSE;
	pr_dec0.om = sr.om;
	pr_dec1.om = sr.om;
	pr_dec2.om = sr.om;
	pr_dec3.om = sr.om;
	pr_dec0.len = 4'd8;
	pr_dec1.len = 4'd8;
	pr_dec2.len = 4'd8;
	pr_dec3.len = 4'd8;
end

always_comb prd[0] = pr_dec0;
always_comb prd[1] = pr_dec1;
always_comb prd[2] = pr_dec2;
always_comb prd[3] = pr_dec3;

always_comb inso = prd;

/* under construction
Qupls_space_branches uspb1
(
	.rst(rst_i),
	.clk(clk),
	.en(en_i),
	.get(get),
	.ins_i(prd),
	.ins_o(inso),
	.stall(stall)
);
*/
always_comb ins0_dec = inso[0];
always_comb ins1_dec = inso[1];
always_comb ins2_dec = inso[2];
always_comb ins3_dec = inso[3];
always_comb pc0_dec = inso[0].pc;
always_comb pc1_dec = inso[1].pc;
always_comb pc2_dec = inso[2].pc;
always_comb pc3_dec = inso[3].pc;

always_comb
begin
/*
	if (pr_dec0.ins.any.opcode==OP_Bcc)
		$finish;
	if (pr_dec1.ins.any.opcode==OP_Bcc)
		$finish;
	if (pr_dec2.ins.any.opcode==OP_Bcc)
		$finish;
	if (pr_dec3.ins.any.opcode==OP_Bcc)
		$finish;
*/
end

always_comb
begin
/*
	if (ins0_dec_o.ins.any.opcode==OP_Bcc)
		$finish;
	if (ins1_dec_o.ins.any.opcode==OP_Bcc)
		$finish;
	if (ins2_dec_o.ins.any.opcode==OP_Bcc)
		$finish;
	if (ins3_dec_o.ins.any.opcode==OP_Bcc)
		$finish;
*/
end

endmodule

