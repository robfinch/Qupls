// ============================================================================
//        __
//   \\__/ o\    (C) 2026  Robert Finch, Waterloo
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
import Qupls5_pkg::*;

module Qupls5_micro_op_queue(rst, clk, en, rd_more, uop, uop_count,
	uop_buf, uop_mark, head);
parameter MWIDTH = Qupls5_pkg::MWIDTH;
parameter MAX_MICROOPS = 12;
parameter MICROOPS_PER_INSTR = 16;
input rst;
input clk;
input en;
output reg rd_more;
input Qupls5_pkg::micro_op_t [MICROOPS_PER_INSTR-1:0] uop [0:MWIDTH-1];
input [5:0] uop_count [0:MWIDTH-1];
output Qupls5_pkg::micro_op_t [MAX_MICROOPS-1:0] uop_buf;
output reg [2:0] uop_mark [0:4*MAX_MICROOPS-1];
output reg [3:0] head [0:MWIDTH-1];

typedef struct packed {
	logic [2:0] wh_isa;
	logic [4:0] wh_uop;
} uop_ndx_t;

integer jj,kk,n1,n5,n11,n12,n13;
integer ul;		// use upper or lower half of buf4
integer rul;
integer k0,k1,k2,k3;
uop_ndx_t uop_ndx [0:4*MAX_MICROOPS-1];
reg [2:0] isa0,isa1,isa2,isa3;
reg [4:0] ndx0,ndx1,ndx2,ndx3;
reg [3:0] tail;
reg [6:0] uop_lead [MICROOPS_PER_INSTR*4-1:0];
reg [6:0] uop_tail [MICROOPS_PER_INSTR*4-1:0];
reg [5:0] uop_count1 [0:MWIDTH-1];
reg [7:0] uop_count3;
//Qupls5_pkg::micro_op_t [MAX_MICROOPS-1:0] uop_buf4;
reg [2:0] uop_mark4 [0:MWIDTH-1][0:MICROOPS_PER_INSTR-1];
reg [5:0] room;

always_comb
	if (head[0] > tail)
		room = head[0] - tail;
	else
		room = MAX_MICROOPS + head[0] - tail;

always_comb
	uop_count3 = uop_count[0] + uop_count[1] + uop_count[2] + uop_count[3];

always_comb
begin
	n12 = 0;
	for (n11 = 0; n11 < MICROOPS_PER_INSTR*4; n11 = n11 + 1) begin
		if (n11 < uop_count[0]) begin
			uop_lead[n12] = n11 == 0;
			uop_ndx[n12].wh_isa = 3'd0;
			uop_ndx[n12].wh_uop = n11;
			uop_mark4[3'd0][n11] = 3'd0;
			n12 = n12 + 1;
		end
		else if (n11 < uop_count[0] + uop_count[1]) begin
			uop_lead[n12] = n11 == uop_count[0];
			uop_ndx[n12].wh_isa = 3'd1;
			uop_ndx[n12].wh_uop = n11 - uop_count[0];
			uop_mark4[3'd1][n11-uop_count[0]] = 3'd1;
			n12 = n12 + 1;
		end
		else if (n11 < uop_count[0] + uop_count[1] + uop_count[2]) begin
			uop_lead[n12] = n11 == uop_count[0] + uop_count[1];
			uop_ndx[n12].wh_isa = 3'd2;
			uop_ndx[n12].wh_uop = n11 - uop_count[0] - uop_count[1];
			uop_mark4[3'd2][n11-uop_count[0]-uop_count[1]] = 3'd2;
			n12 = n12 + 1;
		end
		else if (n11 < uop_count[0] + uop_count[1] + uop_count[2] + uop_count[3]) begin
			uop_lead[n12] = n11 == uop_count[0] + uop_count[1] + uop_count[2];
			uop_ndx[n12].wh_isa = 3'd3;
			uop_ndx[n12].wh_uop = n11 - uop_count[0] - uop_count[1] - uop_count[2];
			uop_mark4[3'd3][n11-uop_count[0]-uop_count[1]-uop_count[2]] = 3'd3;
			n12 = n12 + 1;
		end
		else begin
			uop_lead[n12] = n11 == uop_count[0] + uop_count[1] + uop_count[2] + uop_count[3];
			uop_ndx[n12].wh_isa = 3'd4;
			uop_ndx[n12].wh_uop = n11 - uop_count[0] - uop_count[1] - uop_count[2] - uop_count[3];
			uop_mark4[3'd4][n11-uop_count[0]-uop_count[1]-uop_count[2]-uop_count[3]] = 3'd4;
			n12 = n12 + 1;
		end
	end
end

// Copy micro-ops from the micro-op decoders into a buffer for further
// processing. The micro-ops are in program order in the buffer. Which
// instruction the micro-op belongs to is stored in an array called uop_mark.

always_ff @(posedge clk)
if (rst)
	kk <= 0;
else begin
	if (en) begin
		if (kk+4 < uop_count3)
			kk <= kk + 4;
		else
			kk <= 0;
	end
end

always_comb
begin
	if (kk+4 < uop_count[0])
		isa0 <= 3'd0;
	else if (kk+4 < uop_count[0] + uop_count[1])
		isa0 <= 3'd1;
	else if (kk+4 < uop_count[0] + uop_count[1] + uop_count[2])
		isa0 <= 3'd2;
	else if (kk+4 < uop_count[0] + uop_count[1] + uop_count[2] + uop_count[3])
		isa0 <= 3'd3;
	else
		isa0 <= 3'd4;
end

always_comb
begin
	if (kk+5 < uop_count[0])
		isa1 <= 3'd0;
	else if (kk+5 < uop_count[0] + uop_count[1])
		isa1 <= 3'd1;
	else if (kk+5 < uop_count[0] + uop_count[1] + uop_count[2])
		isa1 <= 3'd2;
	else if (kk+5 < uop_count[0] + uop_count[1] + uop_count[2] + uop_count[3])
		isa1 <= 3'd3;
	else
		isa1 <= 3'd4;
end

always_comb
begin
	if (kk+6 < uop_count[0])
		isa2 <= 3'd0;
	else if (kk+6 < uop_count[0] + uop_count[1])
		isa2 <= 3'd1;
	else if (kk+6 < uop_count[0] + uop_count[1] + uop_count[2])
		isa2 <= 3'd2;
	else if (kk+6 < uop_count[0] + uop_count[1] + uop_count[2] + uop_count[3])
		isa2 <= 3'd3;
	else
		isa2 <= 3'd4;
end

always_comb
begin
	if (kk+7 < uop_count[0])
		isa3 <= 3'd0;
	else if (kk+7 < uop_count[0] + uop_count[1])
		isa3 <= 3'd1;
	else if (kk+7 < uop_count[0] + uop_count[1] + uop_count[2])
		isa3 <= 3'd2;
	else if (kk+7 < uop_count[0] + uop_count[1] + uop_count[2] + uop_count[3])
		isa3 <= 3'd3;
	else
		isa3 <= 3'd4;
end

always_comb
begin
	if (kk+4 < uop_count[0])
		ndx0 <= kk;
	else if (kk+4 < uop_count[0] + uop_count[1])
		ndx0 <= kk - uop_count[0];
	else if (kk+4 < uop_count[0] + uop_count[1] + uop_count[2])
		ndx0 <= kk - uop_count[0] - uop_count[1];
	else if (kk+4 < uop_count[0] + uop_count[1] + uop_count[2] + uop_count[3])
		ndx0 <= kk - uop_count[0] - uop_count[1] - uop_count[2];
	else
		ndx0 <= kk - uop_count[0] - uop_count[1] - uop_count[2] - uop_count[3];
end

always_comb
begin
	if (kk+5 < uop_count[0])
		ndx1 <= kk;
	else if (kk+5 < uop_count[0] + uop_count[1])
		ndx1 <= kk - uop_count[0];
	else if (kk+5 < uop_count[0] + uop_count[1] + uop_count[2])
		ndx1 <= kk - uop_count[0] - uop_count[1];
	else if (kk+5 < uop_count[0] + uop_count[1] + uop_count[2] + uop_count[3])
		ndx1 <= kk - uop_count[0] - uop_count[1] - uop_count[2];
	else
		ndx1 <= kk - uop_count[0] - uop_count[1] - uop_count[2] - uop_count[3];
end

always_comb
begin
	if (kk+6 < uop_count[0])
		ndx2 <= kk;
	else if (kk+6 < uop_count[0] + uop_count[1])
		ndx2 <= kk - uop_count[0];
	else if (kk+6 < uop_count[0] + uop_count[1] + uop_count[2])
		ndx2 <= kk - uop_count[0] - uop_count[1];
	else if (kk+6 < uop_count[0] + uop_count[1] + uop_count[2] + uop_count[3])
		ndx2 <= kk - uop_count[0] - uop_count[1] - uop_count[2];
	else
		ndx2 <= kk - uop_count[0] - uop_count[1] - uop_count[2] - uop_count[3];
end

always_comb
begin
	if (kk+7 < uop_count[0])
		ndx3 <= kk;
	else if (kk+7 < uop_count[0] + uop_count[1])
		ndx3 <= kk - uop_count[0];
	else if (kk+7 < uop_count[0] + uop_count[1] + uop_count[2])
		ndx3 <= kk - uop_count[0] - uop_count[1];
	else if (kk+7 < uop_count[0] + uop_count[1] + uop_count[2] + uop_count[3])
		ndx3 <= kk - uop_count[0] - uop_count[1] - uop_count[2];
	else
		ndx3 <= kk - uop_count[0] - uop_count[1] - uop_count[2] - uop_count[3];
end

always_ff @(posedge clk)
if (rst) begin
	ul <= 0;
	rul <= 64;
end
else begin
	if (en) begin
		if (kk+4 >= uop_count3) begin
			ul <= ul > 0 ? 0 : 64;
			rul <= ul > 0 ? 64 : 0;
		end
	end
end

always_ff @(posedge clk)
if (rst) begin
  for (n5 = 0; n5 < MAX_MICROOPS; n5 = n5 + 1) begin
    uop_mark[n5] <= 2'b00;
    uop_buf[n5] <= {$bits(Qupls5_pkg::micro_op_t){1'b0}};
    uop_buf[n5].v <= VAL;
    uop_buf[n5].lead <= 1'b1;
		uop_buf[n5].opcode <= Qupls5_pkg::OP_NOP;
  end
   // On reset fill buffer with NOPs (0xff).
	for (n13 = 0; n13 < MWIDTH; n13 = n13 + 1)
		head[n13] <= n13;
	tail <= 0;
end
else begin
	if (en) begin
		uop_buf[0] <= uop[isa0][ndx0];
		uop_buf[1] <= uop[isa1][ndx1];
		uop_buf[2] <= uop[isa2][ndx2];
		uop_buf[3] <= uop[isa3][ndx3];
		uop_mark[0] <= uop_mark4[isa0][ndx0];//[kk+rul+0];
		uop_mark[1] <= uop_mark4[isa1][ndx1];//uop_mark4[kk+rul+1];
		uop_mark[2] <= uop_mark4[isa2][ndx2];//[kk+rul+2];
		uop_mark[3] <= uop_mark4[isa3][ndx3];//[kk+rul+3];
	end
end

always_ff @(posedge clk)
if (rst)
	rd_more <= FALSE;
else begin
	rd_more <= FALSE;
	if (en) begin
		if (kk+4 >= uop_count3)
			rd_more <= TRUE;
	end
end

endmodule

