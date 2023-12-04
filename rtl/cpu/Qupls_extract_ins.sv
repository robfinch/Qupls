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

module Qupls_extract_ins(clk_i, en_i, irq_i, hirq_i, vect_i, mipv_i, ic_line_i,
	pc0_i, pc1_i, pc2_i, pc3_i, pc4_i, pc5_i, pc6_i,
	ls_bmf_i, pack_regs_i, scale_regs_i, regcnt_i,
	mc_ins0_i, mc_ins1_i, mc_ins2_i, mc_ins3_i, mc_ins4_i, mc_ins5_i, mc_ins6_i,
	iRn0_i, iRn1_i, iRn2_i, iRn3_i,
	ins0_o, ins1_o, ins2_o, ins3_o, ins4_o, ins5_o, ins6_o);
input clk_i;
input en_i;
input [2:0] irq_i;
input hirq_i;
input [8:0] vect_i;
input mipv_i;
input [1023:0] ic_line_i;
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

wire clk = clk_i;
wire en = en_i;
wire mipv = mipv_i;
wire ls_bmf = ls_bmf_i;
wire pack_regs = pack_regs_i;
aregno_t regcnt = regcnt_i;
pc_address_t pc0 = pc0_i;
pc_address_t pc1 = pc1_i;
pc_address_t pc2 = pc2_i;
pc_address_t pc3 = pc3_i;
pc_address_t pc4 = pc4_i;
pc_address_t pc5 = pc5_i;
pc_address_t pc6 = pc6_i;
instruction_t ins0;
instruction_t ins1;
instruction_t ins2;
instruction_t ins3;
instruction_t ins4;
instruction_t ins5;
instruction_t ins6;
instruction_t ins0_;
instruction_t mc_ins0 = mc_ins0_i;
instruction_t mc_ins1 = mc_ins1_i;
instruction_t mc_ins2 = mc_ins2_i;
instruction_t mc_ins3 = mc_ins3_i;
instruction_t mc_ins4 = mc_ins4_i;
instruction_t mc_ins5 = mc_ins5_i;
instruction_t mc_ins6 = mc_ins6_i;
wire [6:0] iRn0 = iRn0_i;
wire [6:0] iRn1 = iRn1_i;
wire [6:0] iRn2 = iRn2_i;
wire [6:0] iRn3 = iRn3_i;
wire [511:0] ic_line2 = ic_line_i;

wire hirq = &iRn0 & hirq_i;

always_comb
	ins0_ = ic_line2 >> {pc0[17:12],3'd0};

always_ff @(posedge clk) if (en_i) begin
	ins0 <= hirq ? {'d0,FN_IRQ,1'b0,vect_i,5'd0,2'd0,irq_i,OP_SYS} : mipv ? mc_ins0 : ins0_;
	if (~&iRn0 && ls_bmf) begin
		ins0 <= ins0_;
		ins0[12:7] <= iRn0;
		ins0[31:19] <= {pack_regs ? regcnt : iRn0} << scale_regs_i;
	end
	if (~&iRn0) begin
		ins0 <= ins0_;
		ins0[18:13] <= iRn0;
		ins0[31:19] <= {pack_regs ? regcnt : iRn0} << scale_regs_i;
	end
end

always_ff @(posedge clk) if (en_i) begin
	if (~&iRn0)
		ins1 <= hirq ? {'d0,FN_IRQ,1'b0,vect_i,5'd0,2'd0,irq_i,OP_SYS} : mipv ? mc_ins0 : ins0_;
	else
		ins1 <= hirq ? {'d0,FN_IRQ,1'b0,vect_i,5'd0,2'd0,irq_i,OP_SYS} : mipv ? mc_ins1 : ic_line2 >> {pc1[17:12],3'd0};
	if (&iRn1 && ~&iRn0) ins1 <= {'d0,OP_NOP};
	if (~&iRn1 && ls_bmf) begin
		ins1 <= ins0_;
		ins1[12:7] <= iRn1;
		ins1[31:19] <= {pack_regs ? regcnt+1 : iRn1} << scale_regs_i;
	end
	if (~&iRn1) begin
		ins1 <= ins0_;
		ins1[18:13] <= iRn1; 
		ins1[31:19] <= {pack_regs ? regcnt+1 : iRn1} << scale_regs_i;
	end
end

always_ff @(posedge clk) if (en_i) begin
	if (~&iRn0)
		ins2 <= hirq ? {'d0,FN_IRQ,1'b0,vect_i,5'd0,2'd0,irq_i,OP_SYS} : mipv ? mc_ins0 : ins0_;
	else
		ins2 <= hirq ? {'d0,FN_IRQ,1'b0,vect_i,5'd0,2'd0,irq_i,OP_SYS} : mipv ? mc_ins2 : ic_line2 >> {pc2[17:12],3'd0};
	if (&iRn2 && ~&iRn0) ins2 <= {'d0,OP_NOP};
	if (~&iRn2 && ls_bmf) begin 
		ins2 <= ins0_;
		ins2[12:7] <= iRn2;
		ins2[31:19] <= {pack_regs ? regcnt+2 : iRn2} << scale_regs_i;
	end
	if (~&iRn2) begin
		ins2 <= ins0_;
		ins2[18:13] <= iRn2; 
		ins2[31:19] <= {pack_regs ? regcnt+2 : iRn2} << scale_regs_i;
	end
end

always_ff @(posedge clk) begin
	if (~&iRn0)
		ins3 <= hirq ? {'d0,FN_IRQ,1'b0,vect_i,5'd0,2'd0,irq_i,OP_SYS} : mipv ? mc_ins0 : ins0_;
	else
		ins3 <= hirq ? {'d0,FN_IRQ,1'b0,vect_i,5'd0,2'd0,irq_i,OP_SYS} : mipv ? mc_ins3 : ic_line2 >> {pc3[17:12],3'd0};
	if (&iRn3 && ~&iRn0) ins3 <= {'d0,OP_NOP};
	if (~&iRn3 && ls_bmf) begin
		ins3 <= ins0_;
		ins3[12:7] <= iRn3;
		ins3[31:19] <= {pack_regs ? regcnt+3 : iRn3} << scale_regs_i;
	end
	if (~&iRn3) begin
		ins3 <= ins0_;
		ins3[18:13] <= iRn3;
		ins3[31:19] <= {pack_regs ? regcnt+3 : iRn3} << scale_regs_i;
	end
end

always_ff @(posedge clk)
if (en_i)
	ins4 <= hirq ? {'d0,FN_IRQ,1'b0,vect_i,5'd0,2'd0,irq_i,OP_SYS} : mipv ? mc_ins4 : ic_line2 >> {pc4[17:12],3'd0};
always_ff @(posedge clk)
if (en_i)
	ins5 <= hirq ? {'d0,FN_IRQ,1'b0,vect_i,5'd0,2'd0,irq_i,OP_SYS} : mipv ? mc_ins5 : ic_line2 >> {pc5[17:12],3'd0};
always_ff @(posedge clk)
if (en_i)
	ins6 <= hirq ? {'d0,FN_IRQ,1'b0,vect_i,5'd0,2'd0,irq_i,OP_SYS} : mipv ? mc_ins6 : ic_line2 >> {pc6[17:12],3'd0};

always_comb ins0_o = ins0;
always_comb ins1_o = ins1;
always_comb ins2_o = ins2;
always_comb ins3_o = ins3;
always_comb ins4_o = ins4;
always_comb ins5_o = ins5;
always_comb ins6_o = ins6;

endmodule
