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
// ============================================================================

import QuplsPkg::*;

module Qupls_vec_expand(rst, clk, en, vl, mip, pc0, pc1, pc2, pc3,
	ins0, ins1, ins2, ins3, expbuf, pcbuf, mipbuf, jj);
input rst;
input clk;
input en;
input [4:0] vl;
input mc_address_t mip;
input pc_address_t pc0;
input pc_address_t pc1;
input pc_address_t pc2;
input pc_address_t pc3;
input ex_instruction_t ins0;
input ex_instruction_t ins1;
input ex_instruction_t ins2;
input ex_instruction_t ins3;
output ex_instruction_t [31:0] expbuf;
output pc_address_t [31:0] pcbuf;
output mc_address_t [31:0] mipbuf;
output reg [5:0] jj;

integer nn;
wire ins0vec =
	 ins0.ins.r3.Ra.v
	|ins0.ins.r3.Rb.v
	|ins0.ins.r3.Rc.v
	|ins0.ins.r3.Rt.v
	;
wire ins1vec =
	 ins1.ins.r3.Ra.v
	|ins1.ins.r3.Rb.v
	|ins1.ins.r3.Rc.v
	|ins1.ins.r3.Rt.v
	;
wire ins2vec =
	 ins2.ins.r3.Ra.v
	|ins2.ins.r3.Rb.v
	|ins2.ins.r3.Rc.v
	|ins2.ins.r3.Rt.v
	;
wire ins3vec =
	 ins3.ins.r3.Ra.v
	|ins3.ins.r3.Rb.v
	|ins3.ins.r3.Rc.v
	|ins3.ins.r3.Rt.v
	;

always_ff @(posedge clk)
if (rst) begin
	jj = 6'd0;
	for (nn = 0; nn < 32; nn = nn + 1) begin
		pcbuf[nn] = RSTPC;
		expbuf[nn] = ins0;
		mipbuf[nn] = 12'h1A0;
	end	
end
else begin
	if (en) begin
		jj = 6'd0;
		case(ins0vec)
		2'd1,2'd2:
			for (nn = 0; nn < 8; nn = nn + 1) begin
				if (nn < vl) begin
					mipbuf[jj] = mip;
					pcbuf[jj] = pc0;
					expbuf[jj] = ins0;
					if (ins0.ins.r3.Rt.v)
						expbuf[jj].aRt = {ins0.aRt,nn[2:0]};
					if (ins0.ins.r3.Ra.v)
						expbuf[jj].aRa = {ins0.aRa,nn[2:0]};
					if (ins0.ins.r3.Rb.v)
						expbuf[jj].aRb = {ins0.aRb,nn[2:0]};
					if (ins0.ins.r3.Rc.v)
						expbuf[jj].aRc = {ins0.aRc,nn[2:0]};
					jj = jj + 2'd1;
				end
			end
		default:
			begin
				mipbuf[jj] = mip;
				pcbuf[jj] = pc0;
				expbuf[jj] = ins0;
				jj = jj + 2'd1;
			end
		endcase
		case(ins1vec)
		2'd1,2'd2:
			for (nn = 0; nn < 8; nn = nn + 1) begin
				if (nn < vl) begin
					mipbuf[jj] = mip|2'd1;
					pcbuf[jj] = pc1;
					expbuf[jj] = ins1;
					if (ins1.ins.r3.Rt.v)
						expbuf[jj].aRt = {ins1.aRt,nn[2:0]};
					if (ins1.ins.r3.Ra.v)
						expbuf[jj].aRa = {ins1.aRa,nn[2:0]};
					if (ins1.ins.r3.Rb.v)
						expbuf[jj].aRb = {ins1.aRb,nn[2:0]};
					if (ins1.ins.r3.Rc.v)
						expbuf[jj].aRc = {ins1.aRc,nn[2:0]};
					jj = jj + 2'd1;
				end
			end
		default:
			begin
				mipbuf[jj] = mip|2'd1;
				pcbuf[jj] = pc1;
				expbuf[jj] = ins1;
				jj = jj + 2'd1;
			end
		endcase
		case(ins2vec)
		2'd1,2'd2:
			for (nn = 0; nn < 8; nn = nn + 1) begin
				if (nn < vl) begin
					mipbuf[jj] = mip|2'd2;
					pcbuf[jj] = pc2;
					expbuf[jj] = ins2;
					if (ins2.ins.r3.Rt.v)
						expbuf[jj].aRt = {ins2.aRt,nn[2:0]};
					if (ins2.ins.r3.Ra.v)
						expbuf[jj].aRa = {ins2.aRa,nn[2:0]};
					if (ins2.ins.r3.Rb.v)
						expbuf[jj].aRb = {ins2.aRb,nn[2:0]};
					if (ins2.ins.r3.Rc.v)
						expbuf[jj].aRc = {ins2.aRc,nn[2:0]};
					jj = jj + 2'd1;
				end
			end
		default:
			begin
				mipbuf[jj] = mip|2'd2;
				pcbuf[jj] = pc2;
				expbuf[jj] = ins2;
				jj = jj + 2'd1;
			end
		endcase
		case(ins3vec)
		2'd1,2'd2:
			for (nn = 0; nn < 8; nn = nn + 1) begin
				if (nn < vl) begin
					mipbuf[jj] = mip|2'd3;
					pcbuf[jj] = pc3;
					expbuf[jj] = ins3;
					if (ins3.ins.r3.Rt.v)
						expbuf[jj].aRt = {ins3.aRt,nn[2:0]};
					if (ins3.ins.r3.Ra.v)
						expbuf[jj].aRa = {ins3.aRa,nn[2:0]};
					if (ins3.ins.r3.Rb.v)
						expbuf[jj].aRb = {ins3.aRb,nn[2:0]};
					if (ins3.ins.r3.Rc.v)
						expbuf[jj].aRc = {ins3.aRc,nn[2:0]};
					jj = jj + 2'd1;
				end
			end
		default:
			begin
				mipbuf[jj] = mip|2'd3;
				pcbuf[jj] = pc3;
				expbuf[jj] = ins3;
				jj = jj + 2'd1;
			end
		endcase
	end
end

endmodule
