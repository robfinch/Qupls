// ============================================================================
//        __
//   \\__/ o\    (C) 2025-2026  Robert Finch, Waterloo
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
// Placeholder stage to capture the register rename outputs and use them to
// index into the register file.
//
// LUTs /FFs / 0 BRAMs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_pipeline_reg(rst, clk, pg_ren, tails_i, tails_o, rf_reg, rf_regv);
parameter MWIDTH = 4;
input rst;
input clk;
input en;
input Qupls4_pkg::pipeline_group_reg_t pg_ren;

// Tails keeps track of which ROB entries are to be updated.
input rob_ndx_t [11:0] tails_i;
output rob_ndx_t [11:0] tails_o;
output cpu_types_pkg::pregno_t [3:0] rf_reg [0:MWIDTH-1];
output reg [3:0] rf_regv [0:MWIDTH-1];

integer nn,n2,n3;
Qupls4_pkg::pipeline_reg_t nopi;
Qupls4_pkg::pipeline_group_reg_t pg_reg;

// Define a NOP instruction.
always_comb
begin
	nopi = {$bits(Qupls4_pkg::pipeline_reg_t){1'b0}};
	nopi.pc = Qupls4_pkg::RSTPC;
	nopi.pc.stream = 7'd1;
	nopi.uop = {26'd0,Qupls4_pkg::OP_NOP};
	nopi.uop.lead = 1'd1;
	nopi.decbus.Rdz = 1'b1;
	nopi.decbus.nop = 1'b1;
	nopi.decbus.alu = 1'b1;
end

// Load the output pipeline register
always_ff @(posedge clk)
if (rst) begin
	pg_reg <= {$bits(pipeline_group_reg_t){1'b0}};
	foreach (pg_reg.pr[n3]) begin
		pg_reg.pr[n3].op = nopi;
	end
end
else begin
	if (en)
		pg_reg <= pg_ren;
end

always_ff @(posedge clk)
	if (en)
		tails_o <= tails_i;

// Submit register file read requests
always_comb
begin
	foreach (pg_ren.pr[nn]) begin
		rf_reg[nn][0] = pg_ren.pr[nn].op.pRs1;
		rf_reg[nn][1] = pg_ren.pr[nn].op.pRs2;
		rf_reg[nn][2] = pg_ren.pr[nn].op.pRs3;
		rf_reg[nn][3] = pg_ren.pr[nn].op.pRd;
		rf_regv[nn][0] = pg_ren.pr[nn].op.pRs1v;
		rf_regv[nn][1] = pg_ren.pr[nn].op.pRs2v;
		rf_regv[nn][2] = pg_ren.pr[nn].op.pRs3v;
		rf_regv[nn][3] = pg_ren.pr[nn].op.pRdv;
	end
end

endmodule
