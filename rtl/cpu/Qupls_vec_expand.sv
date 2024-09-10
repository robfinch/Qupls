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
//
// Expand a vector instruction out.
// 1.5kLUTs / 6000 FFs
// ============================================================================

import QuplsPkg::*;

module Qupls_vec_expand(rst, clk, en, vl, mip, pc0, pc1, pc2, pc3,
	ins0, ins1, ins2, ins3, expbuf, pcbuf, mipbuf, vim, ndxs);
input rst;
input clk;
input en;
input [4:0] vl;
input QuplsPkg::mc_address_t mip;
input QuplsPkg::pc_address_t pc0;
input QuplsPkg::pc_address_t pc1;
input QuplsPkg::pc_address_t pc2;
input QuplsPkg::pc_address_t pc3;
input ex_instruction_t ins0;
input ex_instruction_t ins1;
input ex_instruction_t ins2;
input ex_instruction_t ins3;
output ex_instruction_t [31:0] expbuf;
output QuplsPkg::pc_address_t [31:0] pcbuf;
output QuplsPkg::mc_address_t [31:0] mipbuf;
output reg [31:0] vim;		// valid instruction mask
output reg [4:0] ndxs [0:31];

integer nn, jj, kk;
ex_instruction_t nopi;

// Detect a vector instruction.
wire ins0vec = ins0.ins.r3.vec;
wire ins1vec = ins1.ins.r3.vec;
wire ins2vec = ins2.ins.r3.vec;
wire ins3vec = ins3.ins.r3.vec;

wire [15:0] i0pfx =	{4'h0,ins0.ins.r3.Rc.v,ins0.ins.r3.Rb.v,ins0.ins.r3.Ra.v,ins0.ins.r3.Rt.v,8'h00};
wire [15:0] i1pfx =	{4'h0,ins1.ins.r3.Rc.v,ins1.ins.r3.Rb.v,ins1.ins.r3.Ra.v,ins1.ins.r3.Rt.v,8'h00};
wire [15:0] i2pfx =	{4'h0,ins2.ins.r3.Rc.v,ins2.ins.r3.Rb.v,ins2.ins.r3.Ra.v,ins2.ins.r3.Rt.v,8'h00};
wire [15:0] i3pfx =	{4'h0,ins3.ins.r3.Rc.v,ins3.ins.r3.Rb.v,ins3.ins.r3.Ra.v,ins3.ins.r3.Rt.v,8'h00};
	
always_ff @(posedge clk)
if (rst) begin
	nopi.pc = RSTPC;
	nopi.mcip = 12'h1A0;
	nopi.ins[7:0] = OP_NOP;
	nopi.aRa = 'd0;
	nopi.aRb = 'd0;
	nopi.aRc = 'd0;
	nopi.aRt = 'd0;
	nopi.element = 'd0;
	nopi.len = 8'd1;
	vim = 32'd0;
	for (nn = 0; nn < 32; nn = nn + 1) begin
		pcbuf[nn] = RSTPC;
		expbuf[nn] = nopi;
		mipbuf[nn] = 12'h1A0;
		ndxs[nn] = nn;
	end	
end
else begin
	if (en) begin
		// Are there any vector instructions present?
		if (!ins0vec && !ins1vec && !ins2vec && !ins3vec) begin
			mipbuf[0] = mip;
			pcbuf[0] = pc0;
			expbuf[0] = ins0;
			vim[0] = 1'b1;
			mipbuf[1] = mip|2'd1;
			pcbuf[1] = pc1;
			expbuf[1] = ins1;
			vim[1] = 1'b1;
			mipbuf[2] = mip|2'd2;
			pcbuf[2] = pc2;
			expbuf[2] = ins2;
			vim[2] = 1'b1;
			mipbuf[3] = mip|2'd3;
			pcbuf[3] = pc3;
			expbuf[3] = ins3;
			vim[3] = 1'b1;
			for (nn = 0; nn < 32; nn = nn + 1)
				ndxs[nn] = nn;
			vim[31:4] = 28'd0;
		end
		else begin
			if(ins0vec) begin
				for (nn = 0; nn < QuplsPkg::VEC_ELEMENTS; nn = nn + 1) begin
					if (nn < vl) begin
						tExpand(nn,pc0,mip,ins0,i0pfx);
						vim[nn] = 1'b1;
						ndxs[nn] = nn;
					end
				end
				jj = vl;
			end
			else begin
				mipbuf[0] = mip;
				pcbuf[0] = pc0;
				expbuf[0] = ins0;
				vim[0] = 1'b1;
				ndxs[0] = 5'd0;
				jj = 1;
			end
			if (ins1vec) begin
				for (nn = 0; nn < QuplsPkg::VEC_ELEMENTS; nn = nn + 1) begin
					if (nn < vl) begin
						tExpand(nn+8,pc1,mip|2'd1,ins1,i1pfx);
						vim[nn+8] = 1'b1;
						ndxs[nn+jj] = nn+8+jj;
					end
				end
				jj = jj + vl;
			end
			else begin
				mipbuf[8] = mip|2'd1;
				pcbuf[8] = pc1;
				expbuf[8] = ins1;
				vim[8] = 1'b1;
				ndxs[jj] = 5'd8;
				jj = jj + 1;
			end
			if (ins2vec) begin
				for (nn = 0; nn < QuplsPkg::VEC_ELEMENTS; nn = nn + 1) begin
					if (nn < vl) begin
						tExpand(nn+16,pc2,mip|2'd2,ins2,i2pfx);
						vim[nn+16] = 1'b1;
						ndxs[nn+jj] = nn+16+jj;
					end
				end
				jj = jj + vl;
			end
	 		else begin
				mipbuf[16] = mip|2'd2;
				pcbuf[16] = pc2;
				expbuf[16] = ins2;
				vim[16] = 1'b1;
				ndxs[jj] = 5'd16;
				jj = jj + 1;
			end
			if (ins3vec) begin
				for (nn = 0; nn < QuplsPkg::VEC_ELEMENTS; nn = nn + 1) begin
					if (nn < vl) begin
						tExpand(nn+24,pc3,mip|2'd3,ins3,i3pfx);
						vim[nn+24] = 1'b1;
						ndxs[nn+jj] = nn+24+jj;
					end
				end
				jj = jj + vl;
			end 
			else begin
				mipbuf[24] = mip|2'd3;
				pcbuf[24] = pc3;
				expbuf[24] = ins3;
				vim[24] = 1'b1;
				ndxs[jj] = 5'd24;
				jj = jj + 1;
			end
		end
	end
end

task tExpand;
input [5:0] nn;
input QuplsPkg::pc_address_t pc;
input QuplsPkg::mc_address_t mip;
input ex_instruction_t ins;
input [15:0] pfx;
begin
	mipbuf[nn] = mip;
	pcbuf[nn] = pc;
	expbuf[nn] = ins0;
	if (pfx[8])
		expbuf[nn].aRt = {ins.aRt,nn[2:0]};
	if (pfx[9])
		expbuf[nn].aRa = {ins.aRa,nn[2:0]};
	if (pfx[10])
		expbuf[nn].aRb = {ins.aRb,nn[2:0]};
	if (pfx[11])
		expbuf[nn].aRc = {ins.aRc,nn[2:0]};
end
endtask

endmodule
