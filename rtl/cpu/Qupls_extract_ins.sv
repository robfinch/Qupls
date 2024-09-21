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

module Qupls_extract_ins(rst_i, clk_i, en_i, nop_i, stomp_vec, stomp_pac, nop_o, 
	irq_i, hirq_i, vect_i,
	branchmiss, misspc, mipv_i, mip_i, ic_line_i,reglist_active, grp_i, grp_o,
	mc_offs, pc0_i, pc1_i, pc2_i, pc3_i, vl,
	ls_bmf_i, pack_regs_i, scale_regs_i, regcnt_i, mc_adr,
	mc_ins0_i, mc_ins1_i, mc_ins2_i, mc_ins3_i,
	len0_i, len1_i, len2_i, len3_i,
	ins0_o, ins1_o, ins2_o, ins3_o,
	pc0_o, pc1_o, pc2_o, pc3_o,
	mcip0_o, mcip1_o, mcip2_o, mcip3_o,
	do_bsr, bsr_tgt, get, stall);
input rst_i;
input clk_i;
input en_i;
input nop_i;
input stomp_vec;
input stomp_pac;
output reg nop_o;
input [2:0] irq_i;
input hirq_i;
input [7:0] vect_i;
input reglist_active;
input branchmiss;
input cpu_types_pkg::pc_address_t misspc;
input mipv_i;
input [11:0] mip_i;
input cpu_types_pkg::pc_address_t mc_adr;
input [1023:0] ic_line_i;
input [2:0] grp_i;
output reg [2:0] grp_o;
input cpu_types_pkg::pc_address_t mc_offs;
input cpu_types_pkg::pc_address_t pc0_i;
input cpu_types_pkg::pc_address_t pc1_i;
input cpu_types_pkg::pc_address_t pc2_i;
input cpu_types_pkg::pc_address_t pc3_i;
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
output ex_instruction_t ins0_o;
output ex_instruction_t ins1_o;
output ex_instruction_t ins2_o;
output ex_instruction_t ins3_o;
output cpu_types_pkg::pc_address_t pc0_o;
output cpu_types_pkg::pc_address_t pc1_o;
output cpu_types_pkg::pc_address_t pc2_o;
output cpu_types_pkg::pc_address_t pc3_o;
output cpu_types_pkg::mc_address_t mcip0_o;
output cpu_types_pkg::mc_address_t mcip1_o;
output cpu_types_pkg::mc_address_t mcip2_o;
output cpu_types_pkg::mc_address_t mcip3_o;
output reg do_bsr;
output cpu_types_pkg::pc_address_t bsr_tgt;
input get;
output reg stall;

integer nn,hh;
wire [5:0] jj;
reg [5:0] kk;
wire clk = clk_i;
wire en = en_i;
wire mipv = mipv_i;
wire ls_bmf = ls_bmf_i;
wire pack_regs = pack_regs_i;
cpu_types_pkg::aregno_t regcnt;
cpu_types_pkg::pc_address_t pc0;
cpu_types_pkg::pc_address_t pc1;
cpu_types_pkg::pc_address_t pc2;
cpu_types_pkg::pc_address_t pc3;
cpu_types_pkg::pc_address_t pc0d;
cpu_types_pkg::pc_address_t pc1d;
cpu_types_pkg::pc_address_t pc2d;
cpu_types_pkg::pc_address_t pc3d;
ex_instruction_t ins0;
ex_instruction_t ins1;
ex_instruction_t ins2;
ex_instruction_t ins3;
ex_instruction_t ins0_;
ex_instruction_t ins1_;
ex_instruction_t ins2_;
ex_instruction_t ins3_;
ex_instruction_t mc_ins0;
ex_instruction_t mc_ins1;
ex_instruction_t mc_ins2;
ex_instruction_t mc_ins3;
wire [11:0] mip = mip_i;
reg [255:0] ic_line_aligned;
cpu_types_pkg::mc_address_t mcip0;
cpu_types_pkg::mc_address_t mcip1;
cpu_types_pkg::mc_address_t mcip2;
cpu_types_pkg::mc_address_t mcip3;
reg ld;

wire hirq = ~reglist_active && hirq_i && mip[11:8]!=4'h1;
ex_instruction_t [31:0] expbuf;
ex_instruction_t [31:0] expbuf2;
cpu_types_pkg::pc_address_t [31:0] pcbuf;
cpu_types_pkg::pc_address_t [31:0] pcbuf2;
cpu_types_pkg::mc_address_t [31:0] mipbuf;
cpu_types_pkg::mc_address_t [31:0] mipbuf2;
ex_instruction_t nopi;

// Define a NOP instruction.
always_comb
begin
	nopi.pc = RSTPC;
	nopi.mcip = 12'h1A0;
	nopi.len = 4'd6;
	nopi.ins = {41'd0,OP_NOP};
	nopi.pred_btst = 6'd0;
	nopi.element = 'd0;
	nopi.aRa = 8'd0;
	nopi.aRb = 8'd0;
	nopi.aRc = 8'd0;
	nopi.aRt = 8'd0;
end

always_comb regcnt = regcnt_i;
always_comb pc0 = pc0_i;
always_comb pc1 = pc1_i;
always_comb pc2 = pc2_i;
always_comb pc3 = pc3_i;
always_comb mc_ins0 = mc_ins0_i;
always_comb mc_ins1 = mc_ins1_i;
always_comb mc_ins2 = mc_ins2_i;
always_comb mc_ins3 = mc_ins3_i;

always_comb 
	ic_line_aligned = ic_line_i >> {pc0[5:1],4'd0};

always_comb tExtractIns(pc0, mip_i|2'd0, len0_i, ic_line_aligned[ 47:  0], ins0_);
always_comb tExtractIns(pc1, mip_i|2'd1, len1_i, ic_line_aligned[ 95: 48], ins1_);
always_comb tExtractIns(pc2, mip_i|2'd2, len2_i, ic_line_aligned[143: 96], ins2_);
always_comb tExtractIns(pc3, mip_i|2'd3, len3_i, ic_line_aligned[191:144], ins3_);

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
reg do_bsr1;
cpu_types_pkg::pc_address_t bsr0_tgt;
cpu_types_pkg::pc_address_t bsr1_tgt;
cpu_types_pkg::pc_address_t bsr2_tgt;
cpu_types_pkg::pc_address_t bsr3_tgt;

always_ff @(posedge clk)
if (rst_i) begin
	pc0d <= RSTPC;
	pc1d <= RSTPC;
	pc2d <= RSTPC;
	pc3d <= RSTPC;
end
else begin
	if (en_i) begin
		pc0d <= pc0;
		pc1d <= pc1;
		pc2d <= pc2;
		pc3d <= pc3;
	end
end

always_comb bsr0 = ins0.ins.any.opcode==OP_BSR;
always_comb bsr1 = ins1.ins.any.opcode==OP_BSR;
always_comb bsr2 = ins2.ins.any.opcode==OP_BSR;
always_comb bsr3 = ins3.ins.any.opcode==OP_BSR;
always_comb bsr0_tgt = pc0d + {{27{ins0.ins[47]}},ins0.ins[47:11]};
always_comb bsr1_tgt = pc1d + {{27{ins1.ins[47]}},ins1.ins[47:11]};
always_comb bsr2_tgt = pc2d + {{27{ins2.ins[47]}},ins2.ins[47:11]};
always_comb bsr3_tgt = pc3d + {{27{ins3.ins[47]}},ins3.ins[47:11]};
always_comb
	do_bsr = bsr0|bsr1|bsr2|bsr3;
//edge_det ued1 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(do_bsr1), .pe(do_bsr), .ne(), .ee());
always_comb
begin
	if (bsr0)
		bsr_tgt = bsr0_tgt;
	else if (bsr1)
		bsr_tgt = bsr1_tgt;
	else if (bsr2)
		bsr_tgt = bsr2_tgt;
	else if (bsr3)
		bsr_tgt = bsr3_tgt;
	else
		bsr_tgt = RSTPC;
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
	.mc_ins0(mc_ins0_i),
	.mc_ins(mc_ins0_i),
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
	.mc_ins0(mc_ins0_i),
	.mc_ins(mc_ins1_i),
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
	.mc_ins0(mc_ins0_i),
	.mc_ins(mc_ins2_i),
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
	.mc_ins0(mc_ins0_i),
	.mc_ins(mc_ins3_i),
	.ins0(ins0_),
	.insi(ins3_),
	.reglist_active(reglist_active),
	.ls_bmf(ls_bmf_i),
	.scale_regs_i(scale_regs_i),
	.pack_regs(pack_regs_i),
	.ins(ins3)
);

reg [31:0] kkmask;
wire [4:0] ndxsa [0:31];
reg [4:0] ndxs [0:31];
wire [31:0] vim;

Qupls_vec_expand uxvec1
(
	.rst(rst_i),
	.clk(clk),
	.en(en_i & ld),
	.stomp_vec(stomp_vec),
	.mip(mip_i),
	.pc0(pc0d),
	.pc1(pc1d),
	.pc2(pc2d),
	.pc3(pc3d),
	.ins0(ins0),
	.ins1(ins1),
	.ins2(ins2),
	.ins3(ins3),
	.expbuf(expbuf),
	.pcbuf(pcbuf),
	.mipbuf(mipbuf),
	.vim(vim),
	.ndxs(ndxsa)
);

always_ff @(posedge clk)
if (rst_i) begin
	kk <= 6'd0;
	kkmask <= 32'd0;
	ins0_o <= nopi;
	ins1_o <= nopi;
	ins2_o <= nopi;
	ins3_o <= nopi;
	ins0_o.ins <= {41'hFA000,OP_NOP};
	ins1_o.ins <= {41'hFA010,OP_NOP};
	ins2_o.ins <= {41'hFA020,OP_NOP};
	ins3_o.ins <= {41'hFA030,OP_NOP};
	pc0_o <= RSTPC;
	pc1_o <= RSTPC;
	pc2_o <= RSTPC;
	pc3_o <= RSTPC;
	mcip0 <= 12'h1A0;
	mcip1 <= 12'h1A1;
	mcip2 <= 12'h1A2;
	mcip3 <= 12'h1A3;
	for (hh = 0; hh < 32; hh = hh + 1) begin
		expbuf2[hh].ins <= {41'hFF00,OP_NOP};
		ndxs[hh] = hh;
	end
	pcbuf2 <= {32{RSTPC}};
	mipbuf2 <= {32{12'h1A0}};
end
else begin
	ins0_o.pc <= RSTPC;
	ins1_o.pc <= RSTPC;
	ins2_o.pc <= RSTPC;
	ins3_o.pc <= RSTPC;
	if (en||get) begin
		if (get) begin
			if (stomp_pac) begin
				ins0_o <= nopi;
				ins1_o <= nopi;
				ins2_o <= nopi;
				ins3_o <= nopi;
				pc0_o <= RSTPC;
				pc1_o <= RSTPC;
				pc2_o <= RSTPC;
				pc3_o <= RSTPC;
				mcip0 <= 12'h1A0;
				mcip1 <= 12'h1A0;
				mcip2 <= 12'h1A0;
				mcip3 <= 12'h1A0;
				kkmask <= 32'h0;
			end
			else begin
				ins0_o <= expbuf2[ndxs[0]];
				ins1_o <= expbuf2[ndxs[1]];
				ins2_o <= expbuf2[ndxs[2]];
				ins3_o <= expbuf2[ndxs[3]];
				
				pc0_o <= expbuf2[ndxs[0]].pc;
				pc1_o <= expbuf2[ndxs[1]].pc;
				pc2_o <= expbuf2[ndxs[2]].pc;
				pc3_o <= expbuf2[ndxs[3]].pc;
				/*
				pc0_o <= pcbuf2[ndxs[0]];
				pc1_o <= pcbuf2[ndxs[1]];
				pc2_o <= pcbuf2[ndxs[2]];
				pc3_o <= pcbuf2[ndxs[3]];
				*/
				mcip0 <= expbuf2[ndxs[0]].mcip;
				mcip1 <= expbuf2[ndxs[1]].mcip;
				mcip2 <= expbuf2[ndxs[2]].mcip;
				mcip3 <= expbuf2[ndxs[3]].mcip;
			end
			for (hh = 0; hh < 28; hh = hh + 1)
				ndxs[hh] <= ndxs[hh+4];
			kkmask <= kkmask >> 4'd4;
		end
		if (ld) begin
			kkmask <= vim;
			ndxs <= ndxsa;
			expbuf2 <= expbuf;
			pcbuf2 <= pcbuf;
			mipbuf2 <= mipbuf;
		end
	end
	ins0_o.len <= 4'd6;
	ins1_o.len <= 4'd6;
	ins2_o.len <= 4'd6;
	ins3_o.len <= 4'd6;
end

always_comb
//	ld = kk <= 6'd4;
	ld = kkmask[31:4]==28'd0;
always_comb
	stall = !ld;

always_ff @(posedge clk) if (en) nop_o <= nop_i;

always_comb mcip0_o <= mcip0;
always_comb mcip1_o <= |mcip0 ? mcip0 | 12'h001 : 12'h000;
always_comb mcip2_o <= |mcip1 ? mcip1 | 12'h002 : 12'h000;
always_comb mcip3_o <= |mcip2 ? mcip2 | 12'h003 : 12'h000;

task tExtractIns;
input pc_address_t pc;
input mc_address_t mcip;
input [3:0] len;
input instruction_t ins_i;
output ex_instruction_t ins_o;
begin
	ins_o.pc = pc;
	ins_o.mcip = mcip;
	ins_o.len = len;
	ins_o.ins = ins_i;
	if (ins_o.ins.any.opcode==OP_QFEXT) begin
		ins_o.aRa = {ins_o.ins[41:39],ins_o.ins.r3.Ra.num};
		ins_o.aRb = {ins_o.ins[44:42],ins_o.ins.r3.Rb.num};
		ins_o.aRc = {ins_o.ins[47:45],ins_o.ins.r3.Rc.num};
		ins_o.aRt = {ins_o.ins[38:36],ins_o.ins.r3.Rt.num};
	end
	else begin
		ins_o.aRa = {3'd0,ins_o.ins.r3.Ra.num};
		ins_o.aRb = {3'd0,ins_o.ins.r3.Rb.num};
		ins_o.aRc = {3'd0,ins_o.ins.r3.Rc.num};
		ins_o.aRt = {3'd0,ins_o.ins.r3.Rt.num};
	end
	ins_o.pred_btst = 6'd0;
	ins_o.element = 'd0;
end
endtask

endmodule
