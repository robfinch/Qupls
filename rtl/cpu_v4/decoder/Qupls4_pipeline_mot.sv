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
	ihit_ext, ihit_mot,
    pg_ext, pg_mot, advance_ext, uop_buf, uop_mark, head);
parameter MWIDTH = Qupls4_pkg::MWIDTH;
parameter MICROOPS_PER_INSTR = 32;
parameter MAX_MICROOPS = 12;
parameter COMB = 1;
input rst;
input clk;
input en;
input ihit_ext;
output reg ihit_mot;
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
Qupls4_pkg::rob_entry_t nopi;

// Define a NOP instruction.
always_comb
begin
	nopi = {$bits(Qupls4_pkg::rob_entry_t){1'b0}};
	nopi.op.exc = Qupls4_pkg::FLT_NONE;
	nopi.op.uop = {41'd0,Qupls4_pkg::OP_NOP};
	nopi.op.decbus.nop = TRUE;
	nopi.op.decbus.cause = Qupls4_pkg::FLT_NONE;
	nopi.op.uop.lead = 1'd1;
	nopi.op.v = 1'b1;
	nopi.v = 5'd1;
	nopi.exc = Qupls4_pkg::FLT_NONE;
	nopi.excv = INV;
	nopi.done = 2'b11;
	/* NOP will be decoded later
	nopi.decbus.Rdz = 1'b1;
	nopi.decbus.nop = 1'b1;
	nopi.decbus.alu = 1'b1;
	*/
end

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
		if (rst) begin
			pg_mot <= {$bits(pipeline_group_reg_t){1'b0}};
			foreach(pg_mot.pr[n1])
				pg_mot.pr[n1] <= nopi;
		end
		else if (en) begin
			pg_mot <= pg_ext;
			if (stomp)
				pg_mot.hdr.v <= INV;
			foreach (pg_mot.pr[n1])
				if (stomp) begin
					pg_mot.pr[n1].stomped <= TRUE;
					pg_mot.pr[n1].done <= 2'b11;
				end
		end
	end
end
endgenerate

generate begin : gMicroopMem
	for (g = 0; g < $size(uop); g = g + 1)
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

always_ff @(posedge clk)
if (rst)
	ihit_mot <= FALSE;
else begin
	if (en)
		ihit_mot <= ihit_ext;
end

endmodule
