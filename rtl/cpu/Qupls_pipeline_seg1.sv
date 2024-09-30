// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2024  Robert Finch, Waterloo
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
//
// Multiplex a hardware interrupt into the instruction stream.s
// Multiplex micro-code instructions into the instruction stream.
// Modify instructions for register bit lists.
//
// 5900 LUTs / 4900 FFs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import QuplsPkg::*;

module Qupls_pipeline_seg1(rst_i, clk_i, rstcnt, advance_fet, ihit, en_i, nop_i, nop_o, 
	irq_i, hirq_i, vect_i, sr, pt_mux, p_override, po_bno,
	branchmiss, misspc, mipv_i, mip_i, ic_line_i,reglist_active, grp_i, grp_o,
	takb_fet, mc_offs, pc0_i, pc1_i, pc2_i, pc3_i, vl,
	ls_bmf_i, pack_regs_i, scale_regs_i, regcnt_i, mc_adr,
	mc_ins0_i, mc_ins1_i, mc_ins2_i, mc_ins3_i,
	len0_i, len1_i, len2_i, len3_i,
	ins0_d_inv,ins1_d_inv,ins2_d_inv,ins3_d_inv,
	ins0_dec_o, ins1_dec_o, ins2_dec_o, ins3_dec_o,
	pc0_o, pc1_o, pc2_o, pc3_o,
	mcip0_i, mcip1_i, mcip2_i, mcip3_i,
	mcip0_o, mcip1_o, mcip2_o, mcip3_o,
	do_bsr, bsr_tgt, get, stall);
input rst_i;
input clk_i;
input [2:0] rstcnt;
input advance_fet;
input ihit;
input en_i;
input nop_i;
output reg nop_o;
input [2:0] irq_i;
input hirq_i;
input [7:0] vect_i;
input status_reg_t sr;
input reglist_active;
input branchmiss;
input cpu_types_pkg::pc_address_t misspc;
input mipv_i;
input [11:0] mip_i;
input cpu_types_pkg::pc_address_t mc_adr;
input [1023:0] ic_line_i;
input [2:0] grp_i;
output reg [2:0] grp_o;
input [3:0] takb_fet;
input [3:0] pt_mux;
output reg [3:0] p_override;
output reg [4:0] po_bno [0:3];
input cpu_types_pkg::pc_address_t mc_offs;
input cpu_types_pkg::pc_address_ex_t pc0_i;
input cpu_types_pkg::pc_address_ex_t pc1_i;
input cpu_types_pkg::pc_address_ex_t pc2_i;
input cpu_types_pkg::pc_address_ex_t pc3_i;
input cpu_types_pkg::mc_address_t mcip0_i;
input cpu_types_pkg::mc_address_t mcip1_i;
input cpu_types_pkg::mc_address_t mcip2_i;
input cpu_types_pkg::mc_address_t mcip3_i;
input [4:0] vl;
input ls_bmf_i;
input pack_regs_i;
input [2:0] scale_regs_i;
input cpu_types_pkg::aregno_t regcnt_i;
input ex_instruction_t mc_ins0_i;
input ex_instruction_t mc_ins1_i;
input ex_instruction_t mc_ins2_i;
input ex_instruction_t mc_ins3_i;
input [4:0] len0_i;
input [4:0] len1_i;
input [4:0] len2_i;
input [4:0] len3_i;
input ins0_d_inv;
input ins1_d_inv;
input ins2_d_inv;
input ins3_d_inv;
output pipeline_reg_t ins0_dec_o;
output pipeline_reg_t ins1_dec_o;
output pipeline_reg_t ins2_dec_o;
output pipeline_reg_t ins3_dec_o;
output cpu_types_pkg::pc_address_ex_t pc0_o;
output cpu_types_pkg::pc_address_ex_t pc1_o;
output cpu_types_pkg::pc_address_ex_t pc2_o;
output cpu_types_pkg::pc_address_ex_t pc3_o;
output cpu_types_pkg::mc_address_t mcip0_o;
output cpu_types_pkg::mc_address_t mcip1_o;
output cpu_types_pkg::mc_address_t mcip2_o;
output cpu_types_pkg::mc_address_t mcip3_o;
output reg do_bsr;
output cpu_types_pkg::pc_address_ex_t bsr_tgt;
input get;
output reg stall;

integer nn,hh;
reg [1023:0] ic_line_fet;
wire [5:0] jj;
reg [5:0] kk;
wire clk = clk_i;
wire en = en_i;
wire mipv = mipv_i;
wire ls_bmf = ls_bmf_i;
wire pack_regs = pack_regs_i;
cpu_types_pkg::aregno_t regcnt;
cpu_types_pkg::pc_address_ex_t pc0;
cpu_types_pkg::pc_address_ex_t pc1;
cpu_types_pkg::pc_address_ex_t pc2;
cpu_types_pkg::pc_address_ex_t pc3;
cpu_types_pkg::pc_address_ex_t pc0d;
cpu_types_pkg::pc_address_ex_t pc1d;
cpu_types_pkg::pc_address_ex_t pc2d;
cpu_types_pkg::pc_address_ex_t pc3d;
cpu_types_pkg::pc_address_ex_t pc0dd;
cpu_types_pkg::pc_address_ex_t pc1dd;
cpu_types_pkg::pc_address_ex_t pc2dd;
cpu_types_pkg::pc_address_ex_t pc3dd;
ex_instruction_t ins0;
ex_instruction_t ins1;
ex_instruction_t ins2;
ex_instruction_t ins3;
ex_instruction_t ins0d;
ex_instruction_t ins1d;
ex_instruction_t ins2d;
ex_instruction_t ins3d;
pipeline_reg_t ins0_;
pipeline_reg_t ins1_;
pipeline_reg_t ins2_;
pipeline_reg_t ins3_;
pipeline_reg_t mc_ins0;
pipeline_reg_t mc_ins1;
pipeline_reg_t mc_ins2;
pipeline_reg_t mc_ins3;
wire [11:0] mip = mip_i;
reg [255:0] ic_line_aligned;
cpu_types_pkg::mc_address_t mcip0;
cpu_types_pkg::mc_address_t mcip1;
cpu_types_pkg::mc_address_t mcip2;
cpu_types_pkg::mc_address_t mcip3;
cpu_types_pkg::mc_address_t mcip0d;
cpu_types_pkg::mc_address_t mcip1d;
cpu_types_pkg::mc_address_t mcip2d;
cpu_types_pkg::mc_address_t mcip3d;
cpu_types_pkg::mc_address_t mcip0dd;
cpu_types_pkg::mc_address_t mcip1dd;
cpu_types_pkg::mc_address_t mcip2dd;
cpu_types_pkg::mc_address_t mcip3dd;
reg ld;

wire hirq = ~reglist_active && hirq_i && mip[11:8]!=4'h1;
pipeline_reg_t [31:0] expbuf;
pipeline_reg_t [31:0] expbuf2;
cpu_types_pkg::pc_address_t [31:0] pcbuf;
cpu_types_pkg::pc_address_t [31:0] pcbuf2;
cpu_types_pkg::mc_address_t [31:0] mipbuf;
cpu_types_pkg::mc_address_t [31:0] mipbuf2;
pipeline_reg_t nopi;

// Define a NOP instruction.
always_comb
begin
	nopi = {$bits(pipeline_reg_t){1'b0}};
	nopi.pc.pc = RSTPC;
	nopi.mcip = 12'h1A0;
	nopi.len = 4'd8;
	nopi.ins = {41'd0,OP_NOP};
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

always_comb regcnt = regcnt_i;
always_comb pc0 = pc0_i;
always_comb pc1 = pc1_i;
always_comb pc2 = pc2_i;
always_comb pc3 = pc3_i;
always_comb 
begin
	mc_ins0 = mc_ins0_i;
	mc_ins1 = mc_ins1_i;
	mc_ins2 = mc_ins2_i;
	mc_ins3 = mc_ins3_i;
	mc_ins0.v = 1'b1;
	mc_ins1.v = 1'b1;
	mc_ins2.v = 1'b1;
	mc_ins3.v = 1'b1;
	mc_ins0.pc = pc0_i;
	mc_ins1.pc = pc1_i;
	mc_ins2.pc = pc2_i;
	mc_ins3.pc = pc3_i;
	mc_ins0.mcip = mcip0_i;
	mc_ins1.mcip = mcip1_i;
	mc_ins2.mcip = mcip2_i;
	mc_ins3.mcip = mcip3_i;
	mc_ins0.decbus.Rtz = mc_ins0_i.aRt==8'd0;
	mc_ins1.decbus.Rtz = mc_ins1_i.aRt==8'd0;
	mc_ins2.decbus.Rtz = mc_ins2_i.aRt==8'd0;
	mc_ins3.decbus.Rtz = mc_ins3_i.aRt==8'd0;
	mc_ins0.decbus.nop = 1'b1;
	mc_ins1.decbus.nop = 1'b1;
	mc_ins2.decbus.nop = 1'b1;
	mc_ins3.decbus.nop = 1'b1;
	mc_ins0.decbus.alu = 1'b1;
	mc_ins1.decbus.alu = 1'b1;
	mc_ins2.decbus.alu = 1'b1;
	mc_ins3.decbus.alu = 1'b1;
	mc_ins0.element = 4'd0;
	mc_ins1.element = 4'd0;
	mc_ins2.element = 4'd0;
	mc_ins3.element = 4'd0;
	mc_ins0.takb = 1'b0;
	mc_ins1.takb = 1'b0;
	mc_ins2.takb = 1'b0;
	mc_ins3.takb = 1'b0;
	mc_ins0.excv <= 1'b0;
	mc_ins1.excv <= 1'b0;
	mc_ins2.excv <= 1'b0;
	mc_ins3.excv <= 1'b0;
	mc_ins0.exc <= FLT_NONE;
	mc_ins1.exc <= FLT_NONE;
	mc_ins2.exc <= FLT_NONE;
	mc_ins3.exc <= FLT_NONE;
	mc_ins0.bt = 1'b0;
	mc_ins1.bt = 1'b0;
	mc_ins2.bt = 1'b0;
	mc_ins3.bt = 1'b0;
	mc_ins0.cndx = 4'd0;
	mc_ins1.cndx = 4'd0;
	mc_ins2.cndx = 4'd0;
	mc_ins3.cndx = 4'd0;
end

always_ff @(posedge clk_i)
if (rst_i)
	ic_line_fet <= {128{1'd1,OP_NOP}};
else begin
	if (!rstcnt[2])
		ic_line_fet <= {128{1'd1,OP_NOP}};
	else if (advance_fet) begin 
		if (!ihit)
			ic_line_fet <= {128{1'd1,OP_NOP}};
		else
			ic_line_fet <= ic_line_i;
	end
end

always_comb 
	ic_line_aligned = {{64{1'b1,OP_NOP}},ic_line_fet} >> {pc0_i.pc[5:3],6'd0};
	
pipeline_reg_t pr0_mux;
pipeline_reg_t pr1_mux;
pipeline_reg_t pr2_mux;
pipeline_reg_t pr3_mux;
always_comb
begin
	pr0_mux = nopi;
	pr1_mux = nopi;
	pr2_mux = nopi;
	pr3_mux = nopi;
	pr0_mux.ins = ic_line_aligned[ 63:  0];
	pr1_mux.ins = ic_line_aligned[127: 64];
	pr2_mux.ins = ic_line_aligned[191:128];
	pr3_mux.ins = ic_line_aligned[255:192];
end

/* Under construction
reg [3:0] p_override1, p_override2;
reg [4:0] po_bno1 [0:3];
reg [4:0] po_bno2 [0:3];
*/

always_comb tExtractIns(pc0, pt_mux[0], takb_fet[0], mip_i|2'd0, len0_i, pr0_mux, ins0_, p_override[0], po_bno[0]);
always_comb tExtractIns(pc1, pt_mux[1], takb_fet[1], mip_i|2'd1, len1_i, pr1_mux, ins1_, p_override[1], po_bno[1]);
always_comb tExtractIns(pc2, pt_mux[2], takb_fet[2], mip_i|2'd2, len2_i, pr2_mux, ins2_, p_override[2], po_bno[2]);
always_comb tExtractIns(pc3, pt_mux[3], takb_fet[3], mip_i|2'd3, len3_i, pr3_mux, ins3_, p_override[3], po_bno[3]);

/* under construction
always_ff @(posedge clk_i)
if (rst_i)
else begin
	if (en_i) begin
		p_override1 <= p_override && ;
		p_override2 <= p_override1;
		po_bno1 <= po_bno;
		po_bno2 <= po_bno1;
	end
end
*/

// If there was a branch miss, instructions before the miss PC should not be
// executed.
reg nop0,nop1,nop2,nop3;

always_comb nop0 = nop_i || (branchmiss && misspc > pc0_i);
always_comb nop1 = nop_i || (branchmiss && misspc > pc1_i);
always_comb nop2 = nop_i || (branchmiss && misspc > pc2_i);
always_comb nop3 = nop_i || (branchmiss && misspc > pc3_i);
/*
always_comb nop0 = FALSE;
always_comb nop1 = FALSE;
always_comb nop2 = FALSE;
always_comb nop3 = FALSE;
*/
reg bsr0,bsr1,bsr2,bsr3;
reg jsr0,jsr1,jsr2,jsr3;
reg do_bsr1;
cpu_types_pkg::pc_address_ex_t bsr0_tgt;
cpu_types_pkg::pc_address_ex_t bsr1_tgt;
cpu_types_pkg::pc_address_ex_t bsr2_tgt;
cpu_types_pkg::pc_address_ex_t bsr3_tgt;

always_ff @(posedge clk)
if (rst_i) begin
	pc0d.pc <= RSTPC;
	pc1d.pc <= RSTPC;
	pc2d.pc <= RSTPC;
	pc3d.pc <= RSTPC;
	pc0d.bno_t <= 6'd0;
	pc1d.bno_t <= 6'd0;
	pc2d.bno_t <= 6'd0;
	pc3d.bno_t <= 6'd0;
	pc0d.bno_f <= 6'd0;
	pc1d.bno_f <= 6'd0;
	pc2d.bno_f <= 6'd0;
	pc3d.bno_f <= 6'd0;
end
else begin
	if (en_i) begin
		pc0d <= pc0;
		pc1d <= pc1;
		pc2d <= pc2;
		pc3d <= pc3;
	end
end
always_ff @(posedge clk)
if (rst_i) begin
	mcip0d <= 12'h1A0;
	mcip1d <= 12'h1A1;
	mcip2d <= 12'h1A2;
	mcip3d <= 12'h1A3;
end
else begin
	if (en_i) begin
		mcip0d <= mcip0_i;
		mcip1d <= mcip1_i;
		mcip2d <= mcip2_i;
		mcip3d <= mcip3_i;
	end
end

always_comb bsr0 = ins0.ins.any.opcode==OP_BSR;
always_comb bsr1 = ins1.ins.any.opcode==OP_BSR;
always_comb bsr2 = ins2.ins.any.opcode==OP_BSR;
always_comb bsr3 = ins3.ins.any.opcode==OP_BSR;
always_comb jsr0 = ins0.ins.any.opcode==OP_JSR;
always_comb jsr1 = ins1.ins.any.opcode==OP_JSR;
always_comb jsr2 = ins2.ins.any.opcode==OP_JSR;
always_comb jsr3 = ins3.ins.any.opcode==OP_JSR;
always_comb 
begin
	bsr0_tgt = ins0.pc;
	bsr0_tgt.pc = jsr0 ? {{10{ins0.ins[63]}},ins0.ins[63:10]} : ins0.pc.pc + {{10{ins0.ins[63]}},ins0.ins[63:10]};
end
always_comb 
begin
	bsr1_tgt = ins1.pc;
	bsr1_tgt.pc = jsr1 ? {{10{ins1.ins[63]}},ins1.ins[63:10]} : ins1.pc.pc + {{10{ins1.ins[63]}},ins1.ins[63:10]};
end
always_comb
begin
	bsr2_tgt = ins2.pc;
	bsr2_tgt.pc = jsr2 ? {{10{ins2.ins[63]}},ins2.ins[63:10]} : ins2.pc.pc + {{10{ins2.ins[63]}},ins2.ins[63:10]};
end
always_comb
begin
	bsr3_tgt = ins3.pc;
	bsr3_tgt.pc = jsr3 ? {{10{ins3.ins[63]}},ins3.ins[63:10]} : ins3.pc.pc + {{10{ins3.ins[63]}},ins3.ins[63:10]};
end
always_comb
	do_bsr = bsr0|bsr1|bsr2|bsr3|jsr0|jsr1|jsr2|jsr3;
//edge_det ued1 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(do_bsr1), .pe(do_bsr), .ne(), .ee());

always_comb
begin
	if (bsr0|jsr0)
		bsr_tgt = bsr0_tgt;
	else if (bsr1|jsr1)
		bsr_tgt = bsr1_tgt;
	else if (bsr2|jsr2)
		bsr_tgt = bsr2_tgt;
	else if (bsr3|jsr3)
		bsr_tgt = bsr3_tgt;
	else
		bsr_tgt.pc = RSTPC;
end

Qupls_ins_extract_mux umux0
(
	.rst(rst_i),
	.clk(clk_i),
	.en(en_i),
	.nop(nop0),
	.rgi(2'd0),
	.regcnt(regcnt_i),
	.hirq(hirq),
	.irq_i(irq_i),
	.vect_i(vect_i),
	.mipv(mipv_i),
	.mc_ins0(mc_ins0),
	.mc_ins(mc_ins0),
	.ins0(ins0_),
	.insi(ins0_),
	.reglist_active(reglist_active),
	.ls_bmf(ls_bmf_i),
	.scale_regs_i(scale_regs_i),
	.pack_regs(pack_regs_i),
	.ins(ins0)
);

Qupls_ins_extract_mux umux1
(
	.rst(rst_i),
	.clk(clk_i),
	.en(en_i),
	.nop(nop1),
	.rgi(2'd1),
	.regcnt(regcnt_i),
	.hirq(hirq),
	.irq_i(irq_i),
	.vect_i(vect_i),
	.mipv(mipv_i),
	.mc_ins0(mc_ins0),
	.mc_ins(mc_ins1),
	.ins0(ins0_),
	.insi(ins1_),
	.reglist_active(reglist_active),
	.ls_bmf(ls_bmf_i),
	.scale_regs_i(scale_regs_i),
	.pack_regs(pack_regs_i),
	.ins(ins1)
);

Qupls_ins_extract_mux umux2
(
	.rst(rst_i),
	.clk(clk_i),
	.en(en_i),
	.nop(nop2),
	.rgi(2'd2),
	.regcnt(regcnt_i),
	.hirq(hirq),
	.irq_i(irq_i),
	.vect_i(vect_i),
	.mipv(mipv_i),
	.mc_ins0(mc_ins0),
	.mc_ins(mc_ins2),
	.ins0(ins0_),
	.insi(ins2_),
	.reglist_active(reglist_active),
	.ls_bmf(ls_bmf_i),
	.scale_regs_i(scale_regs_i),
	.pack_regs(pack_regs_i),
	.ins(ins2)
);

Qupls_ins_extract_mux umux3
(
	.rst(rst_i),
	.clk(clk_i),
	.en(en_i),
	.nop(nop3),
	.rgi(2'd3),
	.regcnt(regcnt_i),
	.hirq(hirq),
	.irq_i(irq_i),
	.vect_i(vect_i),
	.mipv(mipv_i),
	.mc_ins0(mc_ins0),
	.mc_ins(mc_ins3),
	.ins0(ins0_),
	.insi(ins3_),
	.reglist_active(reglist_active),
	.ls_bmf(ls_bmf_i),
	.scale_regs_i(scale_regs_i),
	.pack_regs(pack_regs_i),
	.ins(ins3)
);

decode_bus_t dec0,dec1,dec2,dec3;

Qupls_decoder udeci0
(
	.rst(rst_i),
	.clk(clk),
	.en(en_i),
	.om(sr.om),
	.ipl(sr.ipl),
	.instr(ins0),
	.dbo(dec0)
);

Qupls_decoder udeci1
(
	.rst(rst_i),
	.clk(clk),
	.en(en_i),
	.om(sr.om),
	.ipl(sr.ipl),
	.instr(ins1),
	.dbo(dec1)
);

Qupls_decoder udeci2
(
	.rst(rst_i),
	.clk(clk),
	.en(en_i),
	.om(sr.om),
	.ipl(sr.ipl),
	.instr(ins2),
	.dbo(dec2)
);

Qupls_decoder udeci3
(
	.rst(rst_i),
	.clk(clk),
	.en(en_i),
	.om(sr.om),
	.ipl(sr.ipl),
	.instr(ins3),
	.dbo(dec3)
);

always_ff @(posedge clk)
if (rst_i) begin
	ins0d <= {$bits(ex_instruction_t){1'b0}};
end
else begin
	if (en_i)
		ins0d <= ins0;
end
always_ff @(posedge clk)
if (rst_i) begin
	ins1d <= {$bits(ex_instruction_t){1'b0}};
end
else begin
	if (en_i)
		ins1d <= ins1;
end
always_ff @(posedge clk)
if (rst_i) begin
	ins2d <= {$bits(ex_instruction_t){1'b0}};
end
else begin
	if (en_i)
		ins2d <= ins2;
end
always_ff @(posedge clk)
if (rst_i) begin
	ins3d <= {$bits(ex_instruction_t){1'b0}};
end
else begin
	if (en_i)
		ins3d <= ins3;
end
always_ff @(posedge clk) if (en_i) pc0dd <= pc0d;
always_ff @(posedge clk) if (en_i) pc1dd <= pc1d;
always_ff @(posedge clk) if (en_i) pc2dd <= pc2d;
always_ff @(posedge clk) if (en_i) pc3dd <= pc3d;
always_ff @(posedge clk) if (en_i) mcip0dd <= mcip0d;
always_ff @(posedge clk) if (en_i) mcip1dd <= mcip1d;
always_ff @(posedge clk) if (en_i) mcip2dd <= mcip2d;
always_ff @(posedge clk) if (en_i) mcip3dd <= mcip3d;

pipeline_reg_t pr_dec0,pr_dec1,pr_dec2,pr_dec3;
always_comb
begin
	pr_dec0 = {$bits(pipeline_reg_t){1'b0}};
	pr_dec1 = {$bits(pipeline_reg_t){1'b0}};
	pr_dec2 = {$bits(pipeline_reg_t){1'b0}};
	pr_dec3 = {$bits(pipeline_reg_t){1'b0}};
	pr_dec0.v = TRUE;
	pr_dec1.v = TRUE;
	pr_dec2.v = TRUE;
	pr_dec3.v = TRUE;
	pr_dec0.aRa = dec0.Ra;
	pr_dec0.aRb = dec0.Rb;
	pr_dec0.aRc = dec0.Rc;
	pr_dec0.aRt = dec0.Rt;
	pr_dec1.aRa = dec1.Ra;
	pr_dec1.aRb = dec1.Rb;
	pr_dec1.aRc = dec1.Rc;
	pr_dec1.aRt = dec1.Rt;
	pr_dec2.aRa = dec2.Ra;
	pr_dec2.aRb = dec2.Rb;
	pr_dec2.aRc = dec2.Rc;
	pr_dec2.aRt = dec2.Rt;
	pr_dec3.aRa = dec3.Ra;
	pr_dec3.aRb = dec3.Rb;
	pr_dec3.aRc = dec3.Rc;
	pr_dec3.aRt = dec3.Rt;
	pr_dec0.ins = ins0d.ins;
	pr_dec1.ins = ins1d.ins;
	pr_dec2.ins = ins2d.ins;
	pr_dec3.ins = ins3d.ins;
	pr_dec0.decbus = dec0;
	pr_dec1.decbus = dec1;
	pr_dec2.decbus = dec2;
	pr_dec3.decbus = dec3;
	pr_dec0.pc = ins0d.pc;
	pr_dec1.pc = ins1d.pc;
	pr_dec2.pc = ins2d.pc;
	pr_dec3.pc = ins3d.pc;
	pr_dec0.mcip = ins0d.mcip;
	pr_dec1.mcip = ins1d.mcip;
	pr_dec2.mcip = ins2d.mcip;
	pr_dec3.mcip = ins3d.mcip;
	if (ins1_d_inv) pr_dec1.v = FALSE;
	if (ins2_d_inv) pr_dec2.v = FALSE;
	if (ins3_d_inv) pr_dec3.v = FALSE;
	pr_dec0.om = sr.om;
	pr_dec1.om = sr.om;
	pr_dec2.om = sr.om;
	pr_dec3.om = sr.om;
	pr_dec0.len = 4'd8;
	pr_dec1.len = 4'd8;
	pr_dec2.len = 4'd8;
	pr_dec3.len = 4'd8;
end

always_comb ins0_dec_o = pr_dec0;
always_comb ins1_dec_o = pr_dec1;
always_comb ins2_dec_o = pr_dec2;
always_comb ins3_dec_o = pr_dec3;


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
	stall = 1'b0;

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
		

always_ff @(posedge clk) if (en) nop_o <= nop_i;

always_comb mcip0_o <= mcip0;
always_comb mcip1_o <= |mcip0 ? mcip0 | 12'h001 : 12'h000;
always_comb mcip2_o <= |mcip1 ? mcip1 | 12'h002 : 12'h000;
always_comb mcip3_o <= |mcip2 ? mcip2 | 12'h003 : 12'h000;

task tExtractIns;
input pc_address_ex_t pc;
input pt_mux;
input takb;
input mc_address_t mcip;
input [3:0] len;
input pipeline_reg_t ins_i;
output pipeline_reg_t ins_o;
output p_override;
output [4:0] bno;
begin
	p_override = 1'b0;
	ins_o = ins_i;
	ins_o.pc = pc;
	ins_o.bt = takb;
	ins_o.mcip = mcip;
	ins_o.len = len;
	if (ins_o.ins.any.opcode==OP_QFEXT) begin
		ins_o.aRa = {ins_o.ins[41:39],ins_i.ins.r3.Ra.num};
		ins_o.aRb = {ins_o.ins[44:42],ins_i.ins.r3.Rb.num};
		ins_o.aRc = {ins_o.ins[47:45],ins_i.ins.r3.Rc.num};
		ins_o.aRt = {ins_o.ins[38:36],ins_i.ins.r3.Rt.num};
	end
	else begin
		ins_o.aRa = {3'd0,ins_i.ins.r3.Ra.num};
		ins_o.aRb = {3'd0,ins_i.ins.r3.Rb.num};
		ins_o.aRc = {3'd0,ins_i.ins.r3.Rc.num};
		ins_o.aRt = {3'd0,ins_i.ins.r3.Rt.num};
	end
//	ins_o.decbus.Rtz = ins_o.aRt==8'd0;
	ins_o.pred_btst = 6'd0;
	ins_o.element = 'd0;
	// Under construction
	// If BTB did not match next predictor, invalidate instruction.
	/*
	if (pt_mux != takb) begin
		ins_o.v = 1'b0;
		ins_o.aRt = 8'd0;
		ins_o.ins.any.opcode = OP_NOP;
		p_override = 1'b1;
	end
	*/
	bno = takb ? ins_o.pc.bno_t : ins_o.pc.bno_f;
end
endtask

endmodule
