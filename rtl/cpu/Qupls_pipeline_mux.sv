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
// 1800 LUTs / 1200 FFs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import QuplsPkg::*;

module Qupls_pipeline_mux(rst_i, clk_i, rstcnt, advance_fet, ihit, en_i,
	stomp_bno, stomp_mux, nop_o, 
	nmi_i, irq_fet, irqf_fet, hirq_i, vect_i, sr, pt_mux, p_override, po_bno,
	branchmiss, misspc_fet,
	mipv_i, mip_i, ic_line_fet, reglist_active, grp_i, grp_o,
	takb_fet, mc_offs, pc_i, vl,
	pc0_fet, pc1_fet, pc2_fet, pc3_fet, pc4_fet,
	ls_bmf_i, pack_regs_i, scale_regs_i, regcnt_i, mc_adr,
	mc_ins0_i, mc_ins1_i, mc_ins2_i, mc_ins3_i,
	len0_i, len1_i, len2_i, len3_i,
	ins0_mux_o, ins1_mux_o, ins2_mux_o, ins3_mux_o, ins4_mux_o,
	mcip0_i, mcip1_i, mcip2_i, mcip3_i,
//	mcip0_o, mcip1_o, mcip2_o, mcip3_o,
	do_bsr, bsr_tgt, get, stall);
input rst_i;
input clk_i;
input [2:0] rstcnt;
input advance_fet;
input ihit;
input en_i;
input [4:0] stomp_bno;
input stomp_mux;
output reg nop_o;
input nmi_i;
input [2:0] irq_fet;
input irqf_fet;
input hirq_i;
input [7:0] vect_i;
input status_reg_t sr;
input reglist_active;
input branchmiss;
input cpu_types_pkg::pc_address_ex_t misspc_fet;
input mipv_i;
input [11:0] mip_i;
input cpu_types_pkg::pc_address_ex_t mc_adr;
input [1023:0] ic_line_fet;
input [2:0] grp_i;
output reg [2:0] grp_o;
input pc_address_ex_t pc0_fet;
input pc_address_ex_t pc1_fet;
input pc_address_ex_t pc2_fet;
input pc_address_ex_t pc3_fet;
input pc_address_ex_t pc4_fet;
input [3:0] takb_fet;
input [3:0] pt_mux;
output reg [3:0] p_override;
output reg [4:0] po_bno [0:3];
input cpu_types_pkg::pc_address_t mc_offs;
input cpu_types_pkg::pc_address_ex_t pc_i;
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
output pipeline_reg_t ins0_mux_o;
output pipeline_reg_t ins1_mux_o;
output pipeline_reg_t ins2_mux_o;
output pipeline_reg_t ins3_mux_o;
output pipeline_reg_t ins4_mux_o;
/*
output cpu_types_pkg::mc_address_t mcip0_o;
output cpu_types_pkg::mc_address_t mcip1_o;
output cpu_types_pkg::mc_address_t mcip2_o;
output cpu_types_pkg::mc_address_t mcip3_o;
*/
output reg do_bsr;
output cpu_types_pkg::pc_address_ex_t bsr_tgt;
input get;
output stall;

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
pipeline_reg_t ins0_mux;
pipeline_reg_t ins1_mux;
pipeline_reg_t ins2_mux;
pipeline_reg_t ins3_mux;
pipeline_reg_t ins4_mux;
pipeline_reg_t ins0_fet;
pipeline_reg_t ins1_fet;
pipeline_reg_t ins2_fet;
pipeline_reg_t ins3_fet;
pipeline_reg_t ins4_fet;
pipeline_reg_t mc_ins0;
pipeline_reg_t mc_ins1;
pipeline_reg_t mc_ins2;
pipeline_reg_t mc_ins3;
wire [11:0] mip = mip_i;
reg [319:0] ic_line_aligned;
reg [319:0] prev_ic_line_aligned;
cpu_types_pkg::mc_address_t mcip0;
cpu_types_pkg::mc_address_t mcip1;
cpu_types_pkg::mc_address_t mcip2;
cpu_types_pkg::mc_address_t mcip3;
reg ld;

wire hirq = ~reglist_active && hirq_i && mip[11:8]!=4'h1;
pipeline_reg_t nopi;

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

always_comb regcnt = regcnt_i;

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
	mc_ins0.pc = pc_i;
	mc_ins1.pc = pc_i;
	mc_ins2.pc = pc_i;
	mc_ins3.pc = pc_i;
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
	mc_ins0.decbus.mem = 1'b0;
	mc_ins1.decbus.mem = 1'b0;
	mc_ins2.decbus.mem = 1'b0;
	mc_ins3.decbus.mem = 1'b0;
	mc_ins0.decbus.fpu = 1'b0;
	mc_ins1.decbus.fpu = 1'b0;
	mc_ins2.decbus.fpu = 1'b0;
	mc_ins3.decbus.fpu = 1'b0;
	mc_ins0.element = 4'd0;
	mc_ins1.element = 4'd0;
	mc_ins2.element = 4'd0;
	mc_ins3.element = 4'd0;
	mc_ins0.takb = 1'b0;
	mc_ins1.takb = 1'b0;
	mc_ins2.takb = 1'b0;
	mc_ins3.takb = 1'b0;
	mc_ins0.excv = 1'b0;
	mc_ins1.excv = 1'b0;
	mc_ins2.excv = 1'b0;
	mc_ins3.excv = 1'b0;
	mc_ins0.exc = FLT_NONE;
	mc_ins1.exc = FLT_NONE;
	mc_ins2.exc = FLT_NONE;
	mc_ins3.exc = FLT_NONE;
	mc_ins0.bt = 1'b0;
	mc_ins1.bt = 1'b0;
	mc_ins2.bt = 1'b0;
	mc_ins3.bt = 1'b0;
	mc_ins0.cndx = 4'd0;
	mc_ins1.cndx = 4'd0;
	mc_ins2.cndx = 4'd0;
	mc_ins3.cndx = 4'd0;
end

always_comb 
	ic_line_aligned = {{64{1'b1,OP_NOP}},ic_line_fet} >> {pc0_fet.pc[5:3],6'd0};

pc_address_ex_t prev_pc0_fet;
always_ff @(posedge clk_i)
if (rst_i) begin
	prev_ic_line_aligned <= 320'd0;
	prev_pc0_fet <= {$bits(pc_address_ex_t){1'b0}};
end
else begin
	if (advance_fet) begin
		prev_ic_line_aligned <= ic_line_aligned;
		prev_pc0_fet <= pc0_fet;
	end
end

wire redundant_group = {prev_pc0_fet,prev_ic_line_aligned}=={pc0_fet,ic_line_aligned};

pipeline_reg_t pr0_mux;
pipeline_reg_t pr1_mux;
pipeline_reg_t pr2_mux;
pipeline_reg_t pr3_mux;
pipeline_reg_t pr4_mux;
always_comb
begin
	pr0_mux = nopi;
	pr1_mux = nopi;
	pr2_mux = nopi;
	pr3_mux = nopi;
	pr4_mux = nopi;
	if (!redundant_group) begin
		pr0_mux.ins = ic_line_aligned[ 63:  0];
		pr1_mux.ins = ic_line_aligned[127: 64];
		pr2_mux.ins = ic_line_aligned[191:128];
		pr3_mux.ins = ic_line_aligned[255:192];
		pr4_mux.ins = ic_line_aligned[319:256];
	end
	pr0_mux.hwi_level = irq_fet;
	pr1_mux.hwi_level = irq_fet;
	pr2_mux.hwi_level = irq_fet;
	pr3_mux.hwi_level = irq_fet;
	// If an NMI or IRQ is happening, invalidate instruction and mark as
	// interrupted by external hardware.
	pr0_mux.v = !(nmi_i || irqf_fet);
	pr1_mux.v = !(nmi_i || irqf_fet);
	pr2_mux.v = !(nmi_i || irqf_fet);
	pr3_mux.v = !(nmi_i || irqf_fet);
	pr0_mux.hwi = nmi_i||irqf_fet;
	pr1_mux.hwi = nmi_i||irqf_fet;
	pr2_mux.hwi = nmi_i||irqf_fet;
	pr3_mux.hwi = nmi_i||irqf_fet;
end

/* Under construction
reg [3:0] p_override1, p_override2;
reg [4:0] po_bno1 [0:3];
reg [4:0] po_bno2 [0:3];
*/
reg p_override_dummy;
reg [4:0] po_bno_dummy;

always_comb tExtractIns(pc0_fet, pt_mux[0], takb_fet[0], mip_i|2'd0, len0_i, pr0_mux, ins0_fet, p_override[0], po_bno[0]);
always_comb tExtractIns(pc1_fet, pt_mux[1], takb_fet[1], mip_i|2'd1, len1_i, pr1_mux, ins1_fet, p_override[1], po_bno[1]);
always_comb tExtractIns(pc2_fet, pt_mux[2], takb_fet[2], mip_i|2'd2, len2_i, pr2_mux, ins2_fet, p_override[2], po_bno[2]);
always_comb tExtractIns(pc3_fet, pt_mux[3], takb_fet[3], mip_i|2'd3, len3_i, pr3_mux, ins3_fet, p_override[3], po_bno[3]);
always_comb tExtractIns(pc4_fet, pt_mux[3], takb_fet[3], mip_i|2'd3, len3_i, pr4_mux, ins4_fet, p_override_dummy, po_bno_dummy);

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
/*
always_comb nop0 = (stomp_fet && pc0_fet.bno_t!=stomp_bno) || (branchmiss && misspc_fet.pc > pc0_fet.pc);
always_comb nop1 = (stomp_fet && pc1_fet.bno_t!=stomp_bno) || (branchmiss && misspc_fet.pc > pc1_fet.pc);
always_comb nop2 = (stomp_fet && pc2_fet.bno_t!=stomp_bno) || (branchmiss && misspc_fet.pc > pc2_fet.pc);
always_comb nop3 = (stomp_fet && pc3_fet.bno_t!=stomp_bno) || (branchmiss && misspc_fet.pc > pc3_fet.pc);
*/
always_comb nop0 = (branchmiss && misspc_fet.pc > pc0_fet.pc);
always_comb nop1 = (branchmiss && misspc_fet.pc > pc1_fet.pc);
always_comb nop2 = (branchmiss && misspc_fet.pc > pc2_fet.pc);
always_comb nop3 = (branchmiss && misspc_fet.pc > pc3_fet.pc);
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

always_comb bsr0 = ins0_mux.ins.any.opcode==OP_BSR;
always_comb bsr1 = ins1_mux.ins.any.opcode==OP_BSR;
always_comb bsr2 = ins2_mux.ins.any.opcode==OP_BSR;
always_comb bsr3 = ins3_mux.ins.any.opcode==OP_BSR;
always_comb jsr0 = ins0_mux.ins.any.opcode==OP_JSR;
always_comb jsr1 = ins1_mux.ins.any.opcode==OP_JSR;
always_comb jsr2 = ins2_mux.ins.any.opcode==OP_JSR;
always_comb jsr3 = ins3_mux.ins.any.opcode==OP_JSR;
always_comb 
begin
	bsr0_tgt = ins0_mux.pc;
	bsr0_tgt.pc = jsr0 ? {{10{ins0_mux.ins[63]}},ins0_mux.ins[63:10]} : ins0_mux.pc.pc + {{10{ins0_mux.ins[63]}},ins0_mux.ins[63:10]};
end
always_comb 
begin
	bsr1_tgt = ins1_mux.pc;
	bsr1_tgt.pc = jsr1 ? {{10{ins1_mux.ins[63]}},ins1_mux.ins[63:10]} : ins1_mux.pc.pc + {{10{ins1_mux.ins[63]}},ins1_mux.ins[63:10]};
end
always_comb
begin
	bsr2_tgt = ins2_mux.pc;
	bsr2_tgt.pc = jsr2 ? {{10{ins2_mux.ins[63]}},ins2_mux.ins[63:10]} : ins2_mux.pc.pc + {{10{ins2_mux.ins[63]}},ins2_mux.ins[63:10]};
end
always_comb
begin
	bsr3_tgt = ins3_mux.pc;
	bsr3_tgt.pc = jsr3 ? {{10{ins3_mux.ins[63]}},ins3_mux.ins[63:10]} : ins3_mux.pc.pc + {{10{ins3_mux.ins[63]}},ins3_mux.ins[63:10]};
end
always_comb
	do_bsr = (bsr0|bsr1|bsr2|bsr3|jsr0|jsr1|jsr2|jsr3) & ~stomp_mux;
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
	.irq_i(irq_fet),
	.vect_i(vect_i),
	.mipv(mipv_i),
	.mc_ins0(mc_ins0),
	.mc_ins(mc_ins0),
	.ins0(ins0_fet),
	.insi(ins0_fet),
	.reglist_active(reglist_active),
	.ls_bmf(ls_bmf_i),
	.scale_regs_i(scale_regs_i),
	.pack_regs(pack_regs_i),
	.ins(ins0_mux)
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
	.ins0(ins0_fet),
	.insi(ins1_fet),
	.reglist_active(reglist_active),
	.ls_bmf(ls_bmf_i),
	.scale_regs_i(scale_regs_i),
	.pack_regs(pack_regs_i),
	.ins(ins1_mux)
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
	.ins0(ins0_fet),
	.insi(ins2_fet),
	.reglist_active(reglist_active),
	.ls_bmf(ls_bmf_i),
	.scale_regs_i(scale_regs_i),
	.pack_regs(pack_regs_i),
	.ins(ins2_mux)
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
	.ins0(ins0_fet),
	.insi(ins3_fet),
	.reglist_active(reglist_active),
	.ls_bmf(ls_bmf_i),
	.scale_regs_i(scale_regs_i),
	.pack_regs(pack_regs_i),
	.ins(ins3_mux)
);

Qupls_ins_extract_mux umux4
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
	.ins0(ins0_fet),
	.insi(ins4_fet),
	.reglist_active(reglist_active),
	.ls_bmf(ls_bmf_i),
	.scale_regs_i(scale_regs_i),
	.pack_regs(pack_regs_i),
	.ins(ins4_mux)
);

assign stall = 1'b0;

always_comb ins0_mux_o = ins0_mux;
always_comb ins1_mux_o = ins1_mux;
always_comb ins2_mux_o = ins2_mux;
always_comb ins3_mux_o = ins3_mux;
always_comb ins4_mux_o = ins4_mux;

always_ff @(posedge clk) if (en) nop_o <= stomp_mux;
/*
always_comb mcip0_o <= mcip0;
always_comb mcip1_o <= |mcip0 ? mcip0 | 12'h001 : 12'h000;
always_comb mcip2_o <= |mcip1 ? mcip1 | 12'h002 : 12'h000;
always_comb mcip3_o <= |mcip2 ? mcip2 | 12'h003 : 12'h000;
*/
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
		ins_o.aRa = {ins_i.ins.r3.Ra.num};
		ins_o.aRb = {ins_i.ins.r3.Rb.num};
		ins_o.aRc = {ins_i.ins.r3.Rc.num};
		ins_o.aRt = {ins_i.ins.r3.Rt.num};
	end
	else begin
		ins_o.aRa = {ins_i.ins.r3.Ra.num};
		ins_o.aRb = {ins_i.ins.r3.Rb.num};
		ins_o.aRc = {ins_i.ins.r3.Rc.num};
		ins_o.aRt = {ins_i.ins.r3.Rt.num};
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