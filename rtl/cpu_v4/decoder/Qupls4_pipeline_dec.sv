// ============================================================================
//        __
//   \\__/ o\    (C) 2024-2026  Robert Finch, Waterloo
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
// 7700 LUTs / 8800 FFs / 0 DSPs (210 MHz) 
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_pipeline_dec(rst_i, rst, clk, en, new_cline_ext, cline,
	sr, uop_num,
	tags2free, freevals, bo_wr, bo_preg,
	stomp_dec, stomp_ext, kept_stream, pg_mot,
	pg_dec,
	ren_stallq, dec_stall, ren_rst_busy,
	predicted_correctly_o, new_address_o,
	uop_buf, uop_mark, uop_head
);
parameter MWIDTH = 4;		// Machine width, under construction
parameter MAX_MICROOPS = 12;
parameter MICROOPS_PER_INSTR = 32;
input rst_i;
input rst;
input clk;
input en;
input new_cline_ext;
input [1023:0] cline;
input Qupls4_pkg::status_reg_t sr;
input [4:0] uop_num;
input stomp_dec;
input stomp_ext;
input pc_stream_t kept_stream;
input Qupls4_pkg::pipeline_group_reg_t pg_mot;
input pregno_t [3:0] tags2free;
input [3:0] freevals;
input bo_wr;
input pregno_t bo_preg;
output Qupls4_pkg::pipeline_group_reg_t pg_dec;
output ren_stallq;
output reg dec_stall;
output ren_rst_busy;
output reg predicted_correctly_o;
output reg [63:0] new_address_o;
input Qupls4_pkg::micro_op_t [MAX_MICROOPS-1:0] uop_buf;
input [2:0] uop_mark [0:MAX_MICROOPS-1];
input [3:0] uop_head [0:MWIDTH-1];

genvar g;
integer n1,n2,n3,n4,n5,n6,n7,n8,n9,n10,n11,n12,n13,n14;
Qupls4_pkg::pipeline_group_reg_t pg_ext_r;
reg [31:0] carry_mod_i;
reg [31:0] carry_mod_o;
reg [3:0] atom_count_i;
reg [3:0] atom_count_o;
reg [15:0] pred_mask_i;
reg [15:0] pred_mask_o;
reg [4:0] pred_no_i;
reg [4:0] pred_no_o;
reg hwi_ignore;
Qupls4_pkg::regs_t fregs_i;
Qupls4_pkg::regs_t fregs_o;
Qupls4_pkg::pipeline_group_reg_t pg_dec1,pg_dec2,pg_dec3,pg_dec4;
reg [1023:0] cline1,cline2,cline3,cline4;

always @(posedge clk)
if (rst)
	carry_mod_i <= 32'h0;
else begin
	if (en)
		carry_mod_i <= carry_mod_o;
end
always @(posedge clk)
if (rst)
	atom_count_i <= 4'd0;
else begin
	if (en)
		atom_count_i <= atom_count_o;
end
always @(posedge clk)
if (rst)
	pred_mask_i <= 12'h000;
else begin
	if (en)
		pred_mask_i <= pred_mask_o;
end
always @(posedge clk)
if (rst)
	pred_no_i <= 5'h0;
else begin
	if (en)
		pred_no_i <= pred_no_o;
end
always @(posedge clk)
if (rst)
	fregs_i <= 15'h0;
else begin
	if (en)
		fregs_i <= fregs_o;
end

Qupls4_pkg::rob_entry_t [MWIDTH-1:0] insm;
Qupls4_pkg::pipeline_reg_t ins4d;
Qupls4_pkg::pipeline_reg_t nopi;
Qupls4_pkg::rob_entry_t nopi2;
Qupls4_pkg::decode_bus_t [MWIDTH-1:0] dec;
Qupls4_pkg::pipeline_reg_t [MWIDTH-1:0] pr_dec;
Qupls4_pkg::pipeline_reg_t [MWIDTH-1:0] prd, inso;
Qupls4_pkg::rob_entry_t [MWIDTH-1:0] tpr;

always_ff @(posedge clk)
	if (en) pg_dec1 <= pg_mot;
always_ff @(posedge clk)
	if (en) pg_dec2 <= pg_dec1;
always_ff @(posedge clk)
	if (en) cline1 <= cline;
always_ff @(posedge clk)
	if (en) cline2 <= cline1;

reg rd_ext;
reg [2:0] uop_mark1 [0:MAX_MICROOPS-1];
reg [2:0] uop_mark2 [0:MAX_MICROOPS-1];

// Just wires, make linear buffer of micro-ops
/*
always_comb
begin
	for (n12 = 0; n12 < MICROOPS_PER_INSTR; n12 = n12 + 1) begin
		uop_buf1[n12] = uop[0][n12];
		uop_buf1[MICROOPS_PER_INSTR+n12] = uop[1][n12];
		uop_buf1[MICROOPS_PER_INSTR*2+n12] = uop[2][n12];
		uop_buf1[MICROOPS_PER_INSTR*3+n12] = uop[3][n12];
	end
end
*/
/*
always_ff @(posedge clk)
if (rst) begin
  for (n5 = 0; n5 < MAX_MICROOPS; n5 = n5 + 1)
    uop_mark[n5] = 2'b00;
   // On reset fill buffer with NOPs (0xff).
	uop_buf = {$bits(Qupls4_pkg::micro_op_t)*16{8'hFF}};
	for (n5 = 0; n5 < MWIDTH; n5 = n5 + 1)
		rc_uop_count[n5] = 8'd0;
	rd_more = TRUE;
	head[0] = 4'd0;
	tail = 4'd0;
	kk = 0;
end
else if (en) begin

	rd_more = FALSE;
	jj = tail;
	if (rc_uop_count[kk] < uop_count[kk] && kk < MWIDTH) begin
		uop_buf[jj] = uop[kk][rc_uop_count[kk]];
		uop_mark[jj] = jj;
		jj = jj + 1;
		rc_uop_count[kk] = rc_uop_count[kk] + 4'd1;
	end
	else if (kk < MWIDTH)
		kk = kk + 1;
	if (rc_uop_count[kk] < uop_count[kk] && kk < MWIDTH) begin
		uop_buf[jj] = uop[kk][rc_uop_count[kk]];
		uop_mark[jj] = jj;
		jj = jj + 1;
		rc_uop_count[kk] = rc_uop_count[kk] + 4'd1;
	end
	else if (kk < MWIDTH)
		kk = kk + 1;
	if (rc_uop_count[kk] < uop_count[kk] && kk < MWIDTH) begin
		uop_buf[jj] = uop[kk][rc_uop_count[kk]];
		uop_mark[jj] = jj;
		jj = jj + 1;
		rc_uop_count[kk] = rc_uop_count[kk] + 4'd1;
	end
	else if (kk < MWIDTH)
		kk = kk + 1;
	if (rc_uop_count[kk] < uop_count[kk] && kk < MWIDTH) begin
		uop_buf[jj] = uop[kk][rc_uop_count[kk]];
		uop_mark[jj] = jj;
		jj = jj + 1;
		rc_uop_count[kk] = rc_uop_count[kk] + 4'd1;
	end
	else if (kk < MWIDTH)
		kk = kk + 1;
	if (rc_uop_count[kk] < uop_count[kk] && kk < MWIDTH) begin
		uop_buf[jj] = uop[kk][rc_uop_count[kk]];
		uop_mark[jj] = jj;
		jj = jj + 1;
		rc_uop_count[kk] = rc_uop_count[kk] + 4'd1;
	end
	else if (kk < MWIDTH)
		kk = kk + 1;
	if (rc_uop_count[kk] < uop_count[kk] && kk < MWIDTH) begin
		uop_buf[jj] = uop[kk][rc_uop_count[kk]];
		uop_mark[jj] = jj;
		jj = jj + 1;
		rc_uop_count[kk] = rc_uop_count[kk] + 4'd1;
	end
	else if (kk < MWIDTH)
		kk = kk + 1;
	tail = tail + jj;
	head[0] = head[0] + MWIDTH;
	if (kk >= MWIDTH) begin
		kk = 0;
		for (n5 = 0; n5 < MWIDTH; n5 = n5 + 1)
			rc_uop_count[n5] = 8'd0;
		rd_more = TRUE;//room > 3;
	end


end
*/

// rd_more is a flag set when there is room in the buffer.
always_comb
begin
	foreach (tpr[n7]) begin
		tpr[n7] = pg_mot.pr[uop_mark[uop_head[n7]]];
		tpr[n7].op.uop = uop_buf[uop_head[n7]];
	end
end

//reg stomp_dec;

// Define a NOP instruction.
always_comb
begin
	nopi = {$bits(Qupls4_pkg::pipeline_reg_t){1'b0}};
	nopi.uop = {41'd0,Qupls4_pkg::OP_NOP};
	nopi.uop.lead = 3'd1;
	nopi.v = 1'b1;
	nopi.decbus.Rdv = 1'b0;
	nopi.decbus.nop = 1'b1;
	nopi.decbus.sau = 1'b1;
	nopi.decbus.cause = Qupls4_pkg::FLT_NONE;
	nopi.exc = Qupls4_pkg::FLT_NONE;
	nopi.excv = INV;
end

// Define a NOP instruction.
always_comb
begin
	nopi2 = {$bits(Qupls4_pkg::rob_entry_t){1'b0}};
	nopi2.op.exc = Qupls4_pkg::FLT_NONE;
	nopi2.op.uop = {41'd0,Qupls4_pkg::OP_NOP};
	nopi2.op.decbus.nop = TRUE;
	nopi2.op.decbus.cause = Qupls4_pkg::FLT_NONE;
	nopi2.op.uop.lead = 1'd1;
	nopi2.op.v = 1'b1;
	nopi2.v = 5'd1;
	nopi2.exc = Qupls4_pkg::FLT_NONE;
	nopi2.excv = INV;
	nopi2.done = 2'b11;
end


/*
	Renaming has moved to Qupls4 mainline as asynch process.
*/

/*
always_ff @(posedge clk)
if (advance_pipeline) begin
	if (alloc0 && ins0_ren.decbus.Rt==0) begin
		$display("alloced r0");
		$finish;
	end
	if (alloc1 && ins1_ren.decbus.Rt==0) begin
		$display("alloced r0");
		$finish;
	end
	if (alloc2 && ins2_ren.decbus.Rt==0) begin
		$display("alloced r0");
		$finish;
	end
	if (alloc3 && ins3_ren.decbus.Rt==0) begin
		$display("alloced r0");
		$finish;
	end
end
*/
/*
always_ff @(posedge clk)
begin
	if (!stallq && (ins0_ren.decbus.Rt==7'd63 ||
		ins1_ren.decbus.Rt==7'd63 ||
		ins2_ren.decbus.Rt==7'd63 ||
		ins3_ren.decbus.Rt==7'd63
	))
		$finish;
	for (n19 = 0; n19 < 16; n19 = n19 + 1)
		if (arn[n19]==7'd63)
			$finish;
end
*/

/*
always_comb
	micro_machine_active_x = micro_machine_active;
*/

/*
always_ff @(posedge clk)
if (rst)
	stomp_dec <= FALSE;
else begin
	if (en)
		stomp_dec <= stomp_ext;
end
*/

always_comb//ff @(posedge clk)
if (rst) begin
	for (n9 = 0; n9 < MWIDTH; n9 = n9 + 1) begin
		insm[n9] = {$bits(Qupls4_pkg::rob_entry_t){1'b0}};
		insm[n9].op = nopi;
		insm[n9].done = 2'b11;
		insm[n9].stomped = TRUE;
	end
end
else begin
	for (n9 = 0; n9 < MWIDTH; n9 = n9 + 1) begin
		insm[n9] = tpr[n9];
		if (stomp_ext && FALSE) begin
			if (tpr[n9].ip_stream!=kept_stream) begin
				insm[n9].op = nopi;
				insm[n9].done = 2'b11;
				insm[n9].stomped = TRUE;
			end
		end
	end
end

generate begin : gDecoders
	for (g = 0; g < MWIDTH; g = g + 1)
Qupls4_decoder udeci0
(
	.rst(rst),
	.clk(clk),
	.en(en),
	.ip(pg_mot.hdr.ip.pc + {pg_mot.pr[g].ip_offs,1'b0}),
	.om(sr.om),
	.ipl(sr.ipl),
	.instr(tpr[g].op.uop),
	.instr_raw(432'(cline >> {tpr[g].op.cli,4'b0})),
	.dbo(dec[g])
);
end
endgenerate
/*
always_ff @(posedge clk)
if (rst_i) begin
	insm[3] <= {$bits(pipeline_reg_t){1'b0}};
end
else begin
	if (en_i)
		insm[2] <= (stomp_dec && ((pg_mot.pr[0].bt|pg_mot.pr[1].bt|pg_mot.pr[2].bt|pg_mot.pr[3].bt) && branchmiss ? pg_mot.pr[3].pc.bno_t==stomp_bno : pg_mot.pr[3].pc.bno_f==stomp_bno )) ? nopi : pg_mot.pr[3];
//		insm[3] <= (stomp_dec && pg_mot.pr[3].pc.bno_t==stomp_bno) ? nopi : pg_mot.pr[3];
end
*/

always_comb
begin
	fregs_o = 15'd0;
	
	pr_dec[0] = insm[0].op;
	pr_dec[1] = insm[1].op;
	pr_dec[2] = insm[2].op;
	pr_dec[3] = insm[3].op;
	
	pr_dec[0].v = !stomp_dec;
	pr_dec[1].v = !stomp_dec;
	pr_dec[2].v = !stomp_dec;
	pr_dec[3].v = !stomp_dec;

	pr_dec[0].decbus = dec[0];
	pr_dec[1].decbus = dec[1];
	pr_dec[2].decbus = dec[2];
	pr_dec[3].decbus = dec[3];

	if (stomp_dec) begin
		// Clear the branch flags so that a new checkpoint is not assigned and
		// the checkpoint will not be freed.
		/*
		pr_dec[0].decbus.br = FALSE;
		pr_dec[0].decbus.cjb = FALSE;
		pr_dec[1].decbus.br = FALSE;
		pr_dec[1].decbus.cjb = FALSE;
		pr_dec[2].decbus.br = FALSE;
		pr_dec[2].decbus.cjb = FALSE;
		pr_dec[3].decbus.br = FALSE;
		pr_dec[3].decbus.cjb = FALSE;
		*/
		pr_dec[0].decbus.Rci = dec[0].Rci;
		pr_dec[1].decbus.Rci = dec[1].Rci;
		pr_dec[2].decbus.Rci = dec[2].Rci;
		pr_dec[3].decbus.Rci = dec[3].Rci;
	end
	else begin
		pr_dec[0].decbus.Rci = dec[0].Rci;
		pr_dec[1].decbus.Rci = dec[1].Rci;
		pr_dec[2].decbus.Rci = dec[2].Rci;
		pr_dec[3].decbus.Rci = dec[3].Rci;
	end

	// Apply interrupt masking.
	// Done by clearing the hardware interrupt flag.
	// Hardware interrupts are recognized only for a group since all instructions 
	// in the group are processed in the same clock cycle. An interrupt cannot
	// happen in the middle of a group. This means we only need check the masking
	// of the first instruction of the group. If the first instruction was not
	// masked, and a later one was, then the interrupt will still occur, but the
	// later instructions will not be executed.

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// ATOM modifier support
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	if (SUPPORT_ATOM) begin
		pr_dec[0].atom_count = atom_count_i;
		hwi_ignore = FALSE;
		if ((|pr_dec[0].atom_count|fregs_i.v) && pr_dec[0].v) begin
			hwi_ignore = TRUE;
		end

		if (dec[0].atom && pr_dec[0].v)
			pr_dec[1].atom_count = insm[0].op.uop.imm[3:0];
		// Note to mask instructions not micro-ops, by detecting the lead micro-op
		// of the instruction.
		else if (!pr_dec[0].ssm && pr_dec[0].uop.lead && |pr_dec[0].atom_count)
			pr_dec[1].atom_count = pr_dec[0].atom_count - 4'd1;
		else
			pr_dec[1].atom_count = pr_dec[0].atom_count;
		if (pr_dec[0].hwi & ~hwi_ignore)
			pr_dec[1].v = INV;

		if (dec[1].atom && pr_dec[1].v)
			pr_dec[2].atom_count = insm[1].op.uop.imm[3:0];
		else if (!pr_dec[1].ssm && pr_dec[1].uop.lead && |pr_dec[1].atom_count)
			pr_dec[2].atom_count = pr_dec[1].atom_count - 4'd1;
		else
			pr_dec[2].atom_count = pr_dec[1].atom_count;
		if (pr_dec[0].hwi & ~hwi_ignore)
			pr_dec[2].v = INV;

		if (dec[2].atom && pr_dec[2].v)
			pr_dec[3].atom_count = insm[2].op.uop.imm[3:0];
		else if (!pr_dec[2].ssm && pr_dec[2].uop.lead && |pr_dec[2].atom_count)
			pr_dec[3].atom_count = pr_dec[2].atom_count - 4'd1;
		else
			pr_dec[3].atom_count = pr_dec[2].atom_count;
		if (pr_dec[0].hwi & ~hwi_ignore)
			pr_dec[3].v = INV;

		if (dec[3].atom && pr_dec[3].v)
			atom_count_o = insm[3].op.uop.imm[3:0];
		else if (!pr_dec[3].ssm && pr_dec[3].uop.lead && |pr_dec[3].atom_count)
			atom_count_o = pr_dec[3].atom_count - 4'd1;
		else
			atom_count_o = pr_dec[3].atom_count;
	end
	
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// PRED modifier support
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	if (SUPPORT_PRED) begin
		pr_dec[0].decbus.pred_mask = pred_mask_i;
		pr_dec[0].decbus.pred_no = pred_no_i;
		if (dec[0].pred && pr_dec[0].v) begin
			pr_dec[0].decbus.pred_no = pr_dec[0].decbus.pred_no + 5'd1;
			pr_dec[1].decbus.pred_mask = insm[0].op.uop.imm[15:0];
			pr_dec[1].decbus.pred_no = pr_dec[0].decbus.pred_no;
		end
		else if (!pr_dec[0].ssm && pr_dec[0].uop.lead && |pr_dec[0].pred_mask) begin
			pr_dec[1].decbus.pred_mask = pr_dec[0].uop.imm[15:0] >> 2'd2;
			pr_dec[1].decbus.pred_no = pr_dec[0].decbus.pred_no;
		end
		else begin
			pr_dec[1].decbus.pred_mask = pr_dec[0].uop.imm[15:0];
			pr_dec[1].decbus.pred_no = pr_dec[0].decbus.pred_no;
		end

		if (dec[1].pred && pr_dec[1].v) begin
			pr_dec[1].decbus.pred_no = pr_dec[1].decbus.pred_no + 5'd1;
			pr_dec[2].decbus.pred_mask = insm[1].op.uop.imm[15:0];
			pr_dec[2].decbus.pred_no = pr_dec[1].decbus.pred_no;
		end
		else if (!pr_dec[1].ssm && pr_dec[1].uop.lead && |pr_dec[1].pred_mask) begin
			pr_dec[2].decbus.pred_mask = pr_dec[1].uop.imm[15:0] >> 2'd2;
			pr_dec[2].decbus.pred_no = pr_dec[1].decbus.pred_no;
		end
		else begin
			pr_dec[2].decbus.pred_mask = pr_dec[1].decbus.pred_mask;
			pr_dec[2].decbus.pred_no = pr_dec[1].decbus.pred_no;
		end

		if (dec[2].pred && pr_dec[2].v) begin
			pr_dec[2].decbus.pred_no = pr_dec[2].decbus.pred_no + 5'd1;
			pr_dec[3].decbus.pred_mask = insm[2].op.uop.imm[15:0];
			pr_dec[3].decbus.pred_no = pr_dec[2].decbus.pred_no;
		end
		else if (!pr_dec[2].ssm && pr_dec[2].uop.lead && |pr_dec[2].pred_mask) begin
			pr_dec[3].decbus.pred_mask = pr_dec[2].uop.imm[15:0] >> 2'd2;
			pr_dec[3].decbus.pred_no = pr_dec[2].decbus.pred_no;
		end
		else begin
			pr_dec[3].decbus.pred_mask = pr_dec[2].uop.imm[15:0];
			pr_dec[3].decbus.pred_no = pr_dec[2].decbus.pred_no;
		end

		if (dec[3].pred && pr_dec[3].v) begin
			pred_no_o = pr_dec[3].decbus.pred_no + 5'd1;
			pred_mask_o = insm[3].op.uop.imm[15:0];
		end
		else if (!pr_dec[3].ssm && pr_dec[3].uop.lead && |pr_dec[3].pred_mask) begin
			pred_mask_o = pr_dec[3].decbus.pred_mask >> 2'd2;
			pred_no_o = pr_dec[3].decbus.pred_no;
		end
		else begin
			pred_mask_o = pr_dec[3].decbus.pred_mask;
			pred_no_o = pr_dec[3].decbus.pred_no;
		end
	end

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	// Apply carry mod to instructions in same group, and adjust
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	if (SUPPORT_CARRY) begin
		pr_dec[0].carry_mod = carry_mod_i;
		if (pr_dec[0].v)
		case ({pr_dec[0].carry_mod[9],pr_dec[0].carry_mod[0]})
		2'd0:	;
		2'd1:	pr_dec[0].decbus.Rci = pr_dec[0].carry_mod[25:24]|7'd40;
		2'd2:	pr_dec[0].decbus.Rco = pr_dec[0].carry_mod[25:24]|7'd40;
		2'd3:
			begin
				pr_dec[0].decbus.Rci = pr_dec[0].carry_mod[25:24]|7'd40;
				pr_dec[0].decbus.Rco = pr_dec[0].carry_mod[25:24]|7'd40;
			end
		endcase
		if (dec[0].carry && pr_dec[0].v) begin
			pr_dec[1].carry_mod = insm[0].op.uop;
		end
		else begin
			pr_dec[1].carry_mod = pr_dec[0].carry_mod;
			if (!pr_dec[0].ssm) begin
				pr_dec[1].carry_mod[0] = pr_dec[0].carry_mod[10];
				pr_dec[1].carry_mod[23:9] = {2'd0,pr_dec[0].carry_mod[23:11]};
			end
		end
		if (pr_dec[1].v)
		case ({pr_dec[1].carry_mod[9],pr_dec[1].carry_mod[0]})
		2'd0:	;
		2'd1:	pr_dec[1].decbus.Rci = pr_dec[1].carry_mod[25:24]|7'd40;
		2'd2:	pr_dec[1].decbus.Rco = pr_dec[1].carry_mod[25:24]|7'd40;
		2'd3:
			begin
				pr_dec[1].decbus.Rci = pr_dec[1].carry_mod[25:24]|7'd40;
				pr_dec[1].decbus.Rco = pr_dec[1].carry_mod[25:24]|7'd40;
			end
		endcase
		if (dec[1].carry && pr_dec[1].v) begin
			pr_dec[2].carry_mod = insm[1].op.uop;
		end
		else begin
			pr_dec[2].carry_mod = pr_dec[1].carry_mod;
			if (!pr_dec[1].ssm) begin
				pr_dec[2].carry_mod[0] = pr_dec[1].carry_mod[10];
				pr_dec[2].carry_mod[23:9] = {2'd0,pr_dec[1].carry_mod[23:11]};
			end
		end
		if (pr_dec[2].v)
		case ({pr_dec[2].carry_mod[9],pr_dec[2].carry_mod[0]})
		2'd0:	;
		2'd1:	pr_dec[2].decbus.Rci = pr_dec[1].carry_mod[25:24]|7'd40;
		2'd2:	pr_dec[2].decbus.Rco = pr_dec[1].carry_mod[25:24]|7'd40;
		2'd3:
			begin
				pr_dec[2].decbus.Rci = pr_dec[1].carry_mod[25:24]|7'd40;
				pr_dec[2].decbus.Rco = pr_dec[1].carry_mod[25:24]|7'd40;
			end
		endcase
		if (dec[2].carry && pr_dec[2].v) begin
			pr_dec[3].carry_mod = insm[2].op.uop;
		end
		else begin
			pr_dec[3].carry_mod = pr_dec[2].carry_mod;
			if (!pr_dec[2].ssm) begin
				pr_dec[3].carry_mod[0] = pr_dec[2].carry_mod[10];
				pr_dec[3].carry_mod[23:9] = {2'd0,pr_dec[2].carry_mod[23:11]};
			end
		end
		if (pr_dec[3].v)
		case ({pr_dec[3].carry_mod[9],pr_dec[3].carry_mod[0]})
		2'd0:	;
		2'd1:	pr_dec[3].decbus.Rci = pr_dec[2].carry_mod[25:24]|7'd40;
		2'd2:	pr_dec[3].decbus.Rco = pr_dec[2].carry_mod[25:24]|7'd40;
		2'd3:
			begin
				pr_dec[3].decbus.Rci = pr_dec[2].carry_mod[25:24]|7'd40;
				pr_dec[3].decbus.Rco = pr_dec[2].carry_mod[25:24]|7'd40;
			end
		endcase
		if (dec[3].carry & pr_dec[3].v) begin
			carry_mod_o = insm[3].op.uop;
		end
		else begin
			carry_mod_o = pr_dec[3].carry_mod;
			if (!pr_dec[3].ssm) begin
				carry_mod_o[0] = pr_dec[3].carry_mod[10];
				carry_mod_o[23:9] = {2'd0,pr_dec[3].carry_mod[23:11]};
			end
		end
	end

	// Detect FREGS/REGS register additions
	/*
	if (fregs_i.v)
		pr_dec[0].decbus.Rs3 = fregs_i.Rs3;
	if (dec[0].xregs.v & pr_dec[0].v)
		pr_dec[1].decbus.Rs3 = dec[0].xregs.Rs3;
	if (dec[1].xregs.v & pr_dec[1].v)
		pr_dec[2].decbus.Rs3 = dec[1].xregs.Rs3;
	if (dec[2].xregs.v & pr_dec[2].v)
		pr_dec[3].decbus.Rs3 = dec[2].xregs.Rs3;
	if (dec[3].xregs.v & pr_dec[3].v)
		fregs_o = dec[3].xregs;
*/
/* insx_d_inv was always false in mainline
	if (ins1_d_inv) pr_dec[1].v = FALSE;
	if (ins2_d_inv) pr_dec[2].v = FALSE;
	if (ins3_d_inv) pr_dec[3].v = FALSE;
*/
	pr_dec[0].om = sr.om;
	pr_dec[1].om = sr.om;
	pr_dec[2].om = sr.om;
	pr_dec[3].om = sr.om;

	// Instructions following a BSR / JSR in the same pipeline group are never
	// executed, whether predicted correctly or not.
	// If correctly predicted, the incoming MUX stage will begin with the
	// correct address.
	if (pr_dec[0].decbus.bsr|pr_dec[0].decbus.jsr) begin
		pr_dec[1].v = INV;
		pr_dec[1].uop.opcode = Qupls4_pkg::OP_NOP;
		pr_dec[1].decbus.nop = TRUE;
		pr_dec[2].v = INV;
		pr_dec[2].uop.opcode = Qupls4_pkg::OP_NOP;
		pr_dec[2].decbus.nop = TRUE;
		pr_dec[3].v = INV;
		pr_dec[3].uop.opcode = Qupls4_pkg::OP_NOP;
		pr_dec[3].decbus.nop = TRUE;
	end
	else if (pr_dec[1].decbus.bsr|pr_dec[1].decbus.jsr) begin
		pr_dec[2].v = INV;
		pr_dec[2].uop.opcode = Qupls4_pkg::OP_NOP;
		pr_dec[2].decbus.nop = TRUE;
		pr_dec[3].v = INV;
		pr_dec[3].uop.opcode = Qupls4_pkg::OP_NOP;
		pr_dec[3].decbus.nop = TRUE;
	end
	else if (pr_dec[2].decbus.bsr|pr_dec[2].decbus.jsr) begin
		pr_dec[3].v = INV;
		pr_dec[3].uop.opcode = Qupls4_pkg::OP_NOP;
		pr_dec[3].decbus.nop = TRUE;
	end
end

always_comb prd[0] = pr_dec[0];
always_comb prd[1] = pr_dec[1];
always_comb prd[2] = pr_dec[2];
always_comb prd[3] = pr_dec[3];

always_comb inso = prd;

reg [63:0] bsr0_tgt, bsr1_tgt, bsr2_tgt;
reg [63:0] jsr0_tgt, jsr1_tgt, jsr2_tgt;
reg [63:0] new_address;
always_comb bsr0_tgt = {{29{pr_dec[0].uop.imm[34]}},pr_dec[0].uop.imm,1'b0} + pg_dec2.hdr.ip.pc + {pg_dec2.pr[0].ip_offs,1'b0};
always_comb bsr1_tgt = {{29{pr_dec[1].uop.imm[34]}},pr_dec[1].uop.imm,1'b0} + pg_dec2.hdr.ip.pc + {pg_dec2.pr[1].ip_offs,1'b0};
always_comb bsr2_tgt = {{29{pr_dec[2].uop.imm[34]}},pr_dec[2].uop.imm,1'b0} + pg_dec2.hdr.ip.pc + {pg_dec2.pr[2].ip_offs,1'b0};
always_comb jsr0_tgt = {{29{pr_dec[0].uop.imm[34]}},pr_dec[0].uop.imm,1'b0};
always_comb jsr1_tgt = {{29{pr_dec[1].uop.imm[34]}},pr_dec[1].uop.imm,1'b0};
always_comb jsr2_tgt = {{29{pr_dec[2].uop.imm[34]}},pr_dec[2].uop.imm,1'b0};

reg predicted_correctly;

always_comb
begin
	new_address_o = Qupls4_pkg::RSTPC;
	predicted_correctly_o = TRUE;
	if (pr_dec[0].decbus.bsr|pr_dec[0].decbus.jsr) begin
		predicted_correctly_o = FALSE;
		new_address_o = pr_dec[0].decbus.bsr ? bsr0_tgt : jsr0_tgt;
		if (pg_dec.hdr.ip.pc + {pg_dec.pr[0].ip_offs,1'b0}==pg_mot.hdr.ip.pc + {pg_mot.pr[0].ip_offs,1'b0})
			predicted_correctly_o = TRUE;
	end
	else if (pr_dec[1].decbus.bsr|pr_dec[1].decbus.jsr) begin
		predicted_correctly_o = FALSE;
		new_address_o = pr_dec[1].decbus.bsr ? bsr1_tgt : jsr1_tgt;
		if (pg_dec.hdr.ip.pc + {pg_dec.pr[1].ip_offs,1'b0}==pg_mot.hdr.ip.pc + {pg_mot.pr[1].ip_offs,1'b0})
			predicted_correctly_o = TRUE;
	end
	else if (pr_dec[2].decbus.bsr|pr_dec[2].decbus.jsr) begin
		predicted_correctly_o = FALSE;
		new_address_o = pr_dec[2].decbus.bsr ? bsr2_tgt : jsr2_tgt;
		if (pg_dec.hdr.ip.pc + {pg_dec.pr[2].ip_offs,1'b0}==pg_mot.hdr.ip.pc + {pg_mot.pr[2].ip_offs,1'b0})
			predicted_correctly_o = TRUE;
	end
end

always_ff @(posedge clk)
if (rst) begin
	pg_dec <= {$bits(pipeline_group_reg_t){1'b0}};
	foreach (pg_dec.pr[n10])
		pg_dec.pr[n10] <= nopi2;
end
else begin
	if (en) begin
		pg_dec <= pg_mot;
//		if (stomp_dec)
//			pg_dec.hdr.v <= INV;
		pg_dec.pr[0].op.hwi_level <= pg_mot.hdr.irq.level;
		if (hwi_ignore) begin
			if (pg_dec.hdr.irq.level != 6'd63) begin
				pg_dec.hdr.hwi <= 1'b0;
				pg_dec.pr[0].op.hwi <= 1'b0;
			end
		end
		foreach (pg_dec.pr[n10]) begin
//			pg_dec.pr[n10].v <= stomp_dec ? 5'd0 : pg_mot.pr[n10].v;
			pg_dec.pr[n10].op <= inso[n10];
			if (stomp_dec||inso[n10].decbus.nop) begin
				pg_dec.pr[n10].stomped <= TRUE;
				pg_dec.pr[n10].done <= 2'b11;
			end
			if (inso[n10].uop.opcode==Qupls4_pkg::OP_NOP && !inso[n10].decbus.nop) begin
				$display("Missed flagging NOP as NOP");
				$finish;
			end
		end
	end
end

endmodule

