// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
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
// Multiplex a hardware interrupt into the instruction stream.
// Multiplex micro-code instructions into the instruction stream.
// Modify instructions for register bit lists.
//
// 5500 LUTs / 1020 FFs
// ============================================================================

import QuplsPkg::*;

module Qupls_extract_ins(rst_i, clk_i, en_i, nop_i, nop_o, irq_i, hirq_i, vect_i,
	branchmiss, misspc, mipv_i, mip_i, ic_line_i,reglist_active, grp_i, grp_o,
	pc0_i, pc1_i, pc2_i, pc3_i, pc4_i, pc5_i, pc6_i,
	ls_bmf_i, pack_regs_i, scale_regs_i, regcnt_i,
	mc_ins0_i, mc_ins1_i, mc_ins2_i, mc_ins3_i, mc_ins4_i, mc_ins5_i, mc_ins6_i,
	iRn0_i, iRn1_i, iRn2_i, iRn3_i,
	ins0_o, ins1_o, ins2_o, ins3_o, ins4_o, ins5_o, ins6_o,
	pc0_o, pc1_o, pc2_o, pc3_o, pc4_o, pc5_o, pc6_o);
input rst_i;
input clk_i;
input en_i;
input nop_i;
output reg nop_o;
input [2:0] irq_i;
input hirq_i;
input [8:0] vect_i;
input reglist_active;
input branchmiss;
input pc_address_t misspc;
input mipv_i;
input [11:0] mip_i;
input [1023:0] ic_line_i;
input [2:0] grp_i;
output reg [2:0] grp_o;
input pc_address_t pc0_i;
input pc_address_t pc1_i;
input pc_address_t pc2_i;
input pc_address_t pc3_i;
input pc_address_t pc4_i;
input pc_address_t pc5_i;
input pc_address_t pc6_i;
input ls_bmf_i;
input pack_regs_i;
input [2:0] scale_regs_i;
input aregno_t regcnt_i;
input instruction_t mc_ins0_i;
input instruction_t mc_ins1_i;
input instruction_t mc_ins2_i;
input instruction_t mc_ins3_i;
input instruction_t mc_ins4_i;
input instruction_t mc_ins5_i;
input instruction_t mc_ins6_i;
input [6:0] iRn0_i;
input [6:0] iRn1_i;
input [6:0] iRn2_i;
input [6:0] iRn3_i;
output instruction_t ins0_o;
output instruction_t ins1_o;
output instruction_t ins2_o;
output instruction_t ins3_o;
output instruction_t ins4_o;
output instruction_t ins5_o;
output instruction_t ins6_o;
output pc_address_t pc0_o;
output pc_address_t pc1_o;
output pc_address_t pc2_o;
output pc_address_t pc3_o;
output pc_address_t pc4_o;
output pc_address_t pc5_o;
output pc_address_t pc6_o;

wire clk = clk_i;
wire en = en_i;
wire mipv = mipv_i;
wire ls_bmf = ls_bmf_i;
wire pack_regs = pack_regs_i;
aregno_t regcnt;
pc_address_t pc0;
pc_address_t pc1;
pc_address_t pc2;
pc_address_t pc3;
pc_address_t pc4;
pc_address_t pc5;
pc_address_t pc6;
instruction_t ins0;
instruction_t ins1;
instruction_t ins2;
instruction_t ins3;
instruction_t ins4;
instruction_t ins5;
instruction_t ins6;
instruction_t ins0_;
instruction_t ins1_;
instruction_t ins2_;
instruction_t ins3_;
instruction_t mc_ins0;
instruction_t mc_ins1;
instruction_t mc_ins2;
instruction_t mc_ins3;
instruction_t mc_ins4;
instruction_t mc_ins5;
instruction_t mc_ins6;
wire [6:0] iRn0 = iRn0_i;
wire [6:0] iRn1 = iRn1_i;
wire [6:0] iRn2 = iRn2_i;
wire [6:0] iRn3 = iRn3_i;
wire [511:0] ic_line2 = ic_line_i;
wire [11:0] mip = mip_i;

wire hirq = ~reglist_active && hirq_i && mip[11:8]!=4'h1;

always_comb regcnt = regcnt_i;
always_comb pc0 = pc0_i;
always_comb pc1 = pc1_i;
always_comb pc2 = pc2_i;
always_comb pc3 = pc3_i;
always_comb pc4 = pc4_i;
always_comb pc5 = pc5_i;
always_comb pc6 = pc6_i;
always_comb mc_ins0 = mc_ins0_i;
always_comb mc_ins1 = mc_ins1_i;
always_comb mc_ins2 = mc_ins2_i;
always_comb mc_ins3 = mc_ins3_i;
always_comb mc_ins4 = mc_ins4_i;
always_comb mc_ins5 = mc_ins5_i;
always_comb mc_ins6 = mc_ins6_i;

always_comb ins0_ = ic_line2 >> {pc0[5:0],3'd0};
always_comb ins1_ = ic_line2 >> {pc1[5:0],3'd0};
always_comb ins2_ = ic_line2 >> {pc2[5:0],3'd0};
always_comb ins3_ = ic_line2 >> {pc3[5:0],3'd0};

// If there was a branch miss, one of the PCs must match the miss PC or an
// illegal instruction address was targeted. Instructions before the miss PC
// should not be executed.

reg nop0,nop1,nop2,nop3;
always_comb nop0 = nop_i || (branchmiss && misspc[5:0] > pc0_i[5:0]);
always_comb nop1 = nop_i || (branchmiss && misspc[5:0] > pc1_i[5:0]);
always_comb nop2 = nop_i || (branchmiss && misspc[5:0] > pc2_i[5:0]);
always_comb nop3 = nop_i;

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
	.iRn(iRn0),
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
	.iRn(iRn1),
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
	.iRn(iRn2),
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
	.iRn(iRn3),
	.ls_bmf(ls_bmf_i),
	.scale_regs_i(scale_regs_i),
	.pack_regs(pack_regs_i),
	.ins(ins3)
);

always_ff @(posedge clk)
if (en)
	ins4 <= hirq ? {'d0,FN_IRQ,1'b0,vect_i,5'd0,2'd0,irq_i,OP_SYS} : 
		nop_i ? {33'd0,OP_NOP} :
		mipv ? mc_ins4 : ic_line2 >> {pc4[5:0],3'd0};
always_ff @(posedge clk)
if (en)
	ins5 <= hirq ? {'d0,FN_IRQ,1'b0,vect_i,5'd0,2'd0,irq_i,OP_SYS} :
		nop_i ? {33'd0,OP_NOP} :
		mipv ? mc_ins5 : ic_line2 >> {pc5[5:0],3'd0};
always_ff @(posedge clk)
if (en)
	ins6 <= hirq ? {'d0,FN_IRQ,1'b0,vect_i,5'd0,2'd0,irq_i,OP_SYS} :
		nop_i ? {33'd0,OP_NOP} :
		mipv ? mc_ins6 : ic_line2 >> {pc6[5:0],3'd0};

always_ff @(posedge clk) if (en) nop_o <= nop_i;

always_comb ins0_o = ins0;
always_comb ins1_o = ins1;
always_comb ins2_o = ins2;
always_comb ins3_o = ins3;
always_comb ins4_o = ins4;
always_comb ins5_o = ins5;
always_comb ins6_o = ins6;

always_ff @(posedge clk) if (en) pc0_o <= pc0;
always_ff @(posedge clk) if (en) pc1_o <= pc1;
always_ff @(posedge clk) if (en) pc2_o <= pc2;
always_ff @(posedge clk) if (en) pc3_o <= pc3;
always_ff @(posedge clk) if (en) pc4_o <= pc4;
always_ff @(posedge clk) if (en) pc5_o <= pc5;
always_ff @(posedge clk) if (en) pc6_o <= pc6;
always_ff @(posedge clk) if (en) grp_o <= grp_i;

endmodule
