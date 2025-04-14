// ============================================================================
//        __
//   \\__/ o\    (C) 2024-2025  Robert Finch, Waterloo
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
// 5800 LUTs / 4800 FFs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Stark_pkg::*;

module Stark_pipeline_fet(rst, clk, rstcnt, ihit, en, pc_i, misspc, misspc_fet,
	pc0_fet, pc1_fet, pc2_fet, pc3_fet, pc4_fet, stomp_fet, stomp_bno, ic_carry_mod,
	ic_line_i, ic_line_fet, nmi_i, irq_i, irq_fet, irqf_i, irqf_fet, carry_mod_fet,
	micro_code_active, mc_adr
);
input rst;
input clk;
input [2:0] rstcnt;
input ihit;
input en;
input pc_address_ex_t pc_i;
input pc_address_ex_t misspc;
output pc_address_ex_t misspc_fet;
output pc_address_ex_t pc0_fet;
output pc_address_ex_t pc1_fet;
output pc_address_ex_t pc2_fet;
output pc_address_ex_t pc3_fet;
output pc_address_ex_t pc4_fet;
input stomp_fet;
input [4:0] stomp_bno;
input [31:0] ic_carry_mod;
input [1023:0] ic_line_i;
output reg [1023:0] ic_line_fet;
input nmi_i;
input [5:0] irq_i;
output reg [5:0] irq_fet;
input irqf_i;
output reg irqf_fet;
output reg [31:0] carry_mod_fet;
input micro_code_active;
input pc_address_ex_t mc_adr;

pc_address_ex_t pc0_f;
pc_address_ex_t pc1_f;
pc_address_ex_t pc2_f;
pc_address_ex_t pc3_f;
pc_address_ex_t pc4_f;

always_comb
begin
 	pc0_f = micro_code_active ? mc_adr : pc_i;
end
always_comb 
begin
	pc1_f = pc0_f;
	pc1_f.pc = micro_code_active ? pc0_f.pc : pc0_f.pc + 6'd4;
end
always_comb
begin
	pc2_f = pc0_f;
	pc2_f.pc = micro_code_active ? pc0_f.pc : pc0_f.pc + 6'd8;
end
always_comb
begin
	pc3_f = pc0_f;
	pc3_f.pc = micro_code_active ? pc0_f.pc : pc0_f.pc + 6'd12;
end
always_comb
begin
	pc4_f = pc0_f;
	pc4_f.pc = micro_code_active ? pc0_f.pc : pc0_f.pc + 6'd16;
end

always_ff @(posedge clk)
if (rst) begin
	pc0_fet.bno_t <= 6'd1;
	pc0_fet.bno_f <= 6'd1;
	pc0_fet.pc <= RSTPC;
end
else begin
	if (en)
		pc0_fet <= pc0_f;
end
always_ff @(posedge clk)
if (rst) begin
	pc1_fet.bno_t <= 6'd1;
	pc1_fet.bno_f <= 6'd1;
	pc1_fet.pc <= RSTPC + 6'd8;
end
else begin
	if (en) begin
		pc1_fet <= pc_i;
		pc1_fet.pc <= pc1_f;
	end
end
always_ff @(posedge clk)
if (rst) begin
	pc2_fet.bno_t <= 6'd1;
	pc2_fet.bno_f <= 6'd1;
	pc2_fet.pc <= RSTPC + 6'd16;
end
else begin
	if (en) begin
		pc2_fet <= pc_i;
		pc2_fet.pc <= pc2_f;
	end
end
always_ff @(posedge clk)
if (rst) begin
	pc3_fet.bno_t <= 6'd1;
	pc3_fet.bno_f <= 6'd1;
	pc3_fet.pc <= RSTPC + 6'd24;
end
else begin
	if (en) begin
		pc3_fet <= pc_i;
		pc3_fet.pc <= pc3_f;
	end
end
always_ff @(posedge clk)
if (rst) begin
	pc4_fet.bno_t <= 6'd1;
	pc4_fet.bno_f <= 6'd1;
	pc4_fet.pc <= RSTPC + 6'd32;
end
else begin
	if (en)
		pc4_fet.pc <= pc4_f;
end

always_ff @(posedge clk)
if (rst) begin
	misspc_fet.bno_t <= 6'd1;
	misspc_fet.bno_f <= 6'd1;
	misspc_fet <= RSTPC;
end
else begin
	if (en)
		misspc_fet <= misspc;
end

always_ff @(posedge clk)
if (rst)
	ic_line_fet <= {128{2'd3,OP_NOP}};
else begin
	if (!rstcnt[2])
		ic_line_fet <= {128{2'd3,OP_NOP}};
	else if (en) begin 
		if (!ihit || (stomp_fet && pc_i.bno_t!=stomp_bno) || nmi_i)
			ic_line_fet <= {128{2'd3,OP_NOP}};
		else
			ic_line_fet <= ic_line_i;
	end
end

always_ff @(posedge clk)
if (rst)
	irq_fet <= 6'b0;
else begin
	if (en)
		irq_fet <= irq_i;
end

always_ff @(posedge clk)
if (rst)
	irqf_fet <= 1'b0;
else begin
	if (en)
		irqf_fet <= irqf_i;
end

always_ff @(posedge clk)
if (rst)
	carry_mod_fet <= 32'd0;
else begin
	if (en)
		carry_mod_fet <= ic_carry_mod;
end

endmodule
