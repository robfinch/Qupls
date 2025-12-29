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
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_lsq_reg_read_req(rst, clk, lsq_head, lsq, aReg, pReg, cndx,
	id, id1, bRs, bRsv);
input rst;
input clk;
input Qupls4_pkg::lsq_ndx_t lsq_head;
input Qupls4_pkg::lsq_entry_t [1:0] lsq [0:Qupls4_pkg::LSQ_ENTRIES-1];
output aregno_t aReg;
output pregno_t pReg;
output cpu_types_pkg::checkpt_ndx_t cndx;
output Qupls4_pkg::lsq_ndx_t id;
output Qupls4_pkg::lsq_ndx_t id1;
output pregno_t [3:0] bRs;
output reg [3:0] bRsv;

always_ff @(posedge clk)
if (rst) begin
	aReg <= {$bits(aregno_t){1'b0}};
	pReg <= {$bits(pregno_t){1'b0}};
	cndx <= 5'd0;
	id <= 8'd0;
	id1 <= 8'd0;
	bRsv <= 4'd0;
end
else begin

	// Issue register read request for store operand. The register value will
	// appear on the prn bus and be picked up by the register validation module.
	if (lsq[lsq_head.row][lsq_head.col].v==VAL) begin
		aReg <= lsq[lsq_head.row][lsq_head.col].aRc;
		pReg <= lsq[lsq_head.row][lsq_head.col].pRc;
		cndx <= lsq[lsq_head.row][lsq_head.col].cndx;
		id <= lsq_head;
		id1 <= id;
		bRs[0] <= 9'd0;
		bRs[1] <= 9'd0;
		bRs[3] <= 9'd0;
		bRsv[0] <= INV;
		bRsv[1] <= INV;
		bRsv[3] <= INV;
		if (lsq[lsq_head.row][lsq_head.col].store) begin
			bRs[2] <= lsq[lsq_head.row][lsq_head.col].aRc;
			bRsv[2] <= VAL;
		end
		else begin
			bRs[2] <= 9'd0;
			bRsv[2] <= INV;
		end
	end
end

endmodule
