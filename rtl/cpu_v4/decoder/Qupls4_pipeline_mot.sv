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
// THI+S SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
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
// Micro-op Translation Stage
// Translate raw instructions to micro-ops.
// 4450 LUTs / 8200 FFs / 4 DSPs / 133 MHz
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_pipeline_mot(rst, clk, en, stomp, cline_ext, cline_mot,
    pg_ext, pg_mot, advance_ext, uop_buf, uop_mark, head);
parameter MWIDTH = Qupls4_pkg::MWIDTH;
parameter MICROOPS_PER_INSTR = 32;
parameter MAX_MICROOPS = 12;
parameter COMB = 1;
input rst;
input clk;
input en;
input stomp;
input [1023:0] cline_ext;
output reg [1023:0] cline_mot;
input Qupls4_pkg::pipeline_group_reg_t pg_ext;
output Qupls4_pkg::pipeline_group_reg_t pg_mot;
output reg advance_ext;
output Qupls4_pkg::micro_op_t [MAX_MICROOPS-1:0] uop_buf;
output [2:0] uop_mark [0:MAX_MICROOPS-1];
output [3:0] head [0:MWIDTH-1];

integer n1;
genvar g;
wire rd_more;
reg [5:0] uop_count [0:MWIDTH-1];
Qupls4_pkg::micro_op_t [MICROOPS_PER_INSTR-1:0] uop [0:MWIDTH-1];

generate begin : gComb
	if (FALSE & COMB) begin
		always_comb
			cline_mot = cline_ext;

		always_comb
		begin
			pg_mot = pg_ext;
			if (stomp)
				pg_mot.hdr.v = INV;
			foreach (pg_mot.pr[n1])
				if (stomp)
					pg_mot.pr[n1].v = INV;
		end
	end
	else begin
		always_ff @(posedge clk)
			if (en) cline_mot <= cline_ext;

		always_ff @(posedge clk)
		if (en) begin
			pg_mot <= pg_ext;
			if (stomp)
				pg_mot.hdr.v <= INV;
			foreach (pg_mot.pr[n1])
				if (stomp)
					pg_mot.pr[n1].v <= INV;
		end
	end
end
endgenerate

generate begin : gMicroopMem
	for (g = 0; g < MWIDTH; g = g + 1)
Qupls4_microop_mem #(.COMB(COMB)) uuop1
(
	.rst(rst),
  .clk(clk),
  .en(en),
	.om(pg_ext.pr[g].op.om),
	.ir(pg_ext.pr[g].op.uop),
	.num(5'd0), 
	.carry_reg(8'd0),
	.carry_out(1'b0),
	.carry_in(1'b0),
	.count(uop_count[g]),
	.uop(uop[g]),
	.thread(pg_ext.pr[g].ip_stream.thread)
);
end
endgenerate

Qupls4_micro_op_queue umoq1
(
	.rst(rst),
	.clk(clk),
	.en(en),
	.rd_more(rd_more),
	.uop(uop),
	.uop_count(uop_count),
	.uop_buf(uop_buf),
	.uop_mark(uop_mark),
	.head(head)
);

always_comb
	advance_ext = rd_more;

endmodule
