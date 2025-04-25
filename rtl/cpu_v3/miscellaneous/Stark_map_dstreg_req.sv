// ============================================================================
//        __
//   \\__/ o\    (C) 2025  Robert Finch, Waterloo
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
//  2500 LUTs /  0 FFs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Stark_pkg::*;

module Stark_map_dstreg_req(pgh, rob, ns_alloc_req, ns_whrndx, ns_whreg, ns_rndx,
	ns_reg, ns_areg, ns_cndx);
input Stark_pkg::pipeline_group_hdr_t [ROB_ENTRIES/4-1:0] pgh;
input Stark_pkg::rob_entry_t [ROB_ENTRIES-1:0] rob;
output reg [3:0] ns_alloc_req;
output rob_ndx_t [3:0] ns_whrndx;
output reg [1:0] ns_whreg [0:3];
input rob_ndx_t [3:0] ns_rndx;
input [1:0] ns_reg [0:3];
output aregno_t [3:0] ns_areg;
output checkpt_ndx_t [3:0] ns_cndx;

integer n1,kk;
integer m1,m2,m3,m4;

always_comb
begin
kk = 0;
for (n1 = 0; n1 < 4; n1 = n1 + 1)
	ns_whreg[n1] = 2'd0;
for (n1 = 0; n1 < ROB_ENTRIES; n1 = n1 + 1) begin
	if (rob[n1].v && kk < 4) begin
		m1 = (n1==ns_rndx[0] && ns_reg[0]==2'd1);
		m2 = (n1==ns_rndx[1] && ns_reg[0]==2'd1);
		m3 = (n1==ns_rndx[2] && ns_reg[0]==2'd1);
		m4 = (n1==ns_rndx[3] && ns_reg[0]==2'd1);
		if (!rob[n1].op.pRdv && kk < 4 && !m1 && !m2 && !m3 && !m4) begin
			ns_alloc_req[kk] = 1'b1;
			ns_whrndx[kk] = n1;
			ns_whreg[kk] = 2'd1;
			ns_areg[kk] = rob[n1].op.decbus.Rd;
			ns_cndx[kk] = pgh[n1>>2].cndx;
			kk = kk + 1;
		end
		m1 = (n1==ns_rndx[0] && ns_reg[1]==2'd2);
		m2 = (n1==ns_rndx[1] && ns_reg[1]==2'd2);
		m3 = (n1==ns_rndx[2] && ns_reg[1]==2'd2);
		m4 = (n1==ns_rndx[3] && ns_reg[1]==2'd2);
		if (!rob[n1].op.pRd2v && kk < 4 && !m1 && !m2 && !m3 && !m4) begin
			ns_alloc_req[kk] = 1'b1;
			ns_whrndx[kk] = n1;
			ns_whreg[kk] = 2'd2;
			ns_areg[kk] = rob[n1].op.decbus.Rd2;
			ns_cndx[kk] = pgh[n1>>2].cndx;
			kk = kk + 1;
		end
		m1 = (n1==ns_rndx[0] && ns_reg[2]==2'd3);
		m2 = (n1==ns_rndx[1] && ns_reg[2]==2'd3);
		m3 = (n1==ns_rndx[2] && ns_reg[2]==2'd3);
		m4 = (n1==ns_rndx[3] && ns_reg[2]==2'd3);
		if (!rob[n1].op.pRcov && kk < 4 && !m1 && !m2 && !m3 && !m4) begin
			ns_alloc_req[kk] = 1'b1;
			ns_whrndx[kk] = n1;
			ns_whreg[kk] = 2'd3;
			ns_areg[kk] = rob[n1].op.decbus.Rco;
			ns_cndx[kk] = pgh[n1>>2].cndx;
			kk = kk + 1;
		end
	end
end
end

endmodule
