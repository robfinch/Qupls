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
import Qupls4_pkg::*;

module Qupls4_micro_op_queue3(rst, clk, en, rd_more, uop, uop_count,
	uop_buf, uop_mark, head);
parameter MWIDTH = Qupls4_pkg::MWIDTH;
parameter MAX_MICROOPS = 12;
parameter MICROOPS_PER_INSTR = 16;
input rst;
input clk;
input en;
output reg rd_more;
input Qupls4_pkg::micro_op_t [MICROOPS_PER_INSTR-1:0] uop [0:MWIDTH-1];
input [5:0] uop_count [0:MWIDTH-1];
output Qupls4_pkg::micro_op_t [MAX_MICROOPS-1:0] uop_buf;
output reg [2:0] uop_mark [0:MAX_MICROOPS-1];
output reg [3:0] head [0:MWIDTH-1];

integer jj,kk,n1,n2,n3,n4,n5,n11,n12,n13;
integer ul;		// use upper or lower half of buf4
integer rul;
integer k0,k1,k2,k3;
reg [3:0] tail;
reg [5:0] uop_count1 [0:MWIDTH-1];
reg [7:0] uop_count3;
Qupls4_pkg::micro_op_t [MICROOPS_PER_INSTR*4-1:0] uop_buf2;
reg [6:0] uop_ndx2 [0:MICROOPS_PER_INSTR*4-1];
reg [6:0] uop_ndx4 [0:MICROOPS_PER_INSTR*8-1];
Qupls4_pkg::micro_op_t [MICROOPS_PER_INSTR*8-1:0] uop_buf4;
reg [2:0] uop_mark2 [0:MICROOPS_PER_INSTR*4-1];
reg [2:0] uop_mark4 [0:MICROOPS_PER_INSTR*8-1];
//Qupls4_pkg::micro_op_t [MAX_MICROOPS-1:0] uop_buf4;
//reg [2:0] uop_mark4 [0:MAX_MICROOPS-1];
reg [5:0] room;

always_comb
	if (head[0] > tail)
		room = head[0] - tail;
	else
		room = MAX_MICROOPS + head[0] - tail;

// Generate linear index into the micro-op buffer. The index points to valid
// micro-ops. Referencing via the index will pack the micro-op stream.

always_ff @(posedge clk)
if (rst) begin
	foreach (uop_ndx2[n11])
		uop_ndx2[n11] <= 64;
	foreach (uop_mark2[n11])
		uop_mark2[n11] <= 3'd4;
end
else begin
	if (en) begin
		n2 = 0;
		n3 = 0;
		n4 = 0;
		for (n12 = 0; n12 < 4; n12 = n12 + 1) begin
			for (n11 = 0; n11 < MICROOPS_PER_INSTR; n11 = n11 + 1)
				uop_buf2[n12*MICROOPS_PER_INSTR + n11] <= uop[n12][n11];
		end

		for (n11 = 0; n11 < MICROOPS_PER_INSTR*4; n11 = n11 + 1) begin
			if (n11 < uop_count[0]) begin
				uop_ndx2[n11] <= n11;
				uop_mark2[n11] <= 3'd0;
			end
			else if (n11 < uop_count[0] + uop_count[1]) begin
				uop_ndx2[n11] <= n2 + 16;
				uop_mark2[n11] <= 3'd1;
				n2 = n2 + 3'd1;
			end
			else if (n11 < uop_count[0] + uop_count[1] + uop_count[2]) begin
				uop_ndx2[n11] <= n3 + 32;
				uop_mark2[n11] <= 3'd2;
				n3 = n3 + 3'd1;
			end
			else if (n11 < uop_count[0] + uop_count[1] + uop_count[2] + uop_count[3]) begin
				uop_ndx2[n11] <= n4 + 48;
				uop_mark2[n11] <= 3'd3;
				n4 = n4 + 3'd1;
			end
		end
	end
end

// Convert two streams into one packed stream.
always_comb
//if (rd_more)
	uop_count1 = uop_count;
always_ff @(posedge clk)
//if (rd_more)
	uop_count3 = {2'b0,uop_count1[0]} + {2'b0,uop_count1[1]} + {2'b0,uop_count1[2]} + {2'b0,uop_count1[3]};

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
    uop_buf[n5] <= {$bits(Qupls4_pkg::micro_op_t){1'b0}};
    uop_buf[n5].v <= VAL;
    uop_buf[n5].lead <= 1'b1;
		uop_buf[n5].opcode <= Qupls4_pkg::OP_NOP;
  end
	for (n5 = 0; n5 < 128; n5 = n5 + 1) begin
		uop_buf4[n5] <= {$bits(Qupls4_pkg::micro_op_t){1'b0}};
    uop_buf4[n5].lead <= 1'b1;
		uop_buf4[n5].opcode <= Qupls4_pkg::OP_NOP;
		uop_mark4[n5] <= 2'b00;
	end
   // On reset fill buffer with NOPs (0xff).
	for (n13 = 0; n13 < MWIDTH; n13 = n13 + 1)
		head[n13] <= n13;
	tail <= 0;
end
else begin
	if (en) begin
		for (n5 = 0; n5 < 64; n5 = n5 + 1) begin
			uop_buf4[n5+ul] <= uop_buf2[n5];
			uop_mark4[n5+ul] <= uop_mark2[n5];
			uop_ndx4[n5+ul] <= uop_ndx2[n5];
		end
		uop_buf[0] <= uop_buf4[uop_ndx4[kk+rul+0]];
		uop_buf[1] <= uop_buf4[uop_ndx4[kk+rul+1]];
		uop_buf[2] <= uop_buf4[uop_ndx4[kk+rul+2]];
		uop_buf[3] <= uop_buf4[uop_ndx4[kk+rul+3]];
		uop_mark[0] <= uop_mark4[uop_ndx4[kk+rul+0]];
		uop_mark[1] <= uop_mark4[uop_ndx4[kk+rul+1]];
		uop_mark[2] <= uop_mark4[uop_ndx4[kk+rul+2]];
		uop_mark[3] <= uop_mark4[uop_ndx4[kk+rul+3]];
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

