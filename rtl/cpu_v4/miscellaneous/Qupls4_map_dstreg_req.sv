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
//  1475 LUTs /  0 FFs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_map_dstreg_req(pgh, rob, ns_alloc_req, ns_whrndx, ns_rndx,
	ns_areg, ns_cndx);
input Qupls4_pkg::pipeline_group_hdr_t [Qupls4_pkg::ROB_ENTRIES/4-1:0] pgh;
input Qupls4_pkg::rob_entry_t [Qupls4_pkg::ROB_ENTRIES-1:0] rob;
output reg [3:0] ns_alloc_req;
output rob_ndx_t [3:0] ns_whrndx;
input rob_ndx_t [3:0] ns_rndx;
output aregno_t [3:0] ns_areg;
output checkpt_ndx_t [3:0] ns_cndx;

integer n1,kk;
integer m1,m2,m3,m4;

always_comb
begin
kk = 0;
for (n1 = 0; n1 < 4; n1 = n1 + 1) begin
	ns_alloc_req[n1] = 1'b0;
	ns_areg[n1] = 8'd0;
	ns_whrndx[n1] = 8'd0;
	ns_cndx[n1] = 5'd0;
end
for (n1 = 0; n1 < Qupls4_pkg::ROB_ENTRIES; n1 = n1 + 1) begin
	if (rob[n1].v && kk < 4) begin
		m1 = (n1==ns_rndx[0]);
		m2 = (n1==ns_rndx[1]);
		m3 = (n1==ns_rndx[2]);
		m4 = (n1==ns_rndx[3]);
		if (!rob[n1].op.pRdv && kk < 4 && !m1 && !m2 && !m3 && !m4) begin
			ns_alloc_req[kk] = 1'b1;
			ns_whrndx[kk] = n1;
			ns_areg[kk] = rob[n1].op.decbus.Rd;
			ns_cndx[kk] = pgh[n1>>2].cndx;
			kk = kk + 1;
		end
		if (!rob[n1].op.pRd2v && kk < 4 && !m1 && !m2 && !m3 && !m4) begin
			ns_alloc_req[kk] = 1'b1;
			ns_whrndx[kk] = n1;
			ns_areg[kk] = rob[n1].op.decbus.Rd2;
			ns_cndx[kk] = pgh[n1>>2].cndx;
			kk = kk + 1;
		end
	end
end
end

endmodule
