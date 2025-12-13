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
// 21200 LUTs / 5800 FFs / 2 BRAMs	- 32 uops per instruction.
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_pipeline_dec(rst_i, rst, clk, en, clk5x, ph4, new_cline_mux, cline,
	restored, restore_list, unavail_list, sr, uop_num, flush_mux, flush_dec,
	tags2free, freevals, bo_wr, bo_preg,
	stomp_dec, stomp_mux, kept_stream, pg_mux,
	Rt0_dec, Rt1_dec, Rt2_dec, Rt3_dec, Rt0_decv, Rt1_decv, Rt2_decv, Rt3_decv,
	micro_machine_active_mux, micro_machine_active_dec,
	pg_dec,
	mux_stallq, ren_stallq, ren_rst_busy, avail_reg,
	predicted_correctly_o, new_address_o
);
parameter MWIDTH = 4;		// Machine width, under construction
parameter MAX_MICROOPS = 12;
parameter MICROOPS_PER_INSTR = 32;
input rst_i;
input rst;
input clk;
input en;
input flush_mux;
output reg flush_dec;
input clk5x;
input [4:0] ph4;
input new_cline_mux;
input [1023:0] cline;
input restored;
input [Qupls4_pkg::PREGS-1:0] restore_list;
input [Qupls4_pkg::PREGS-1:0] unavail_list;
input Qupls4_pkg::status_reg_t sr;
input [4:0] uop_num;
input stomp_dec;
input stomp_mux;
input pc_stream_t kept_stream;
input Qupls4_pkg::pipeline_group_reg_t pg_mux;
input pregno_t [3:0] tags2free;
input [3:0] freevals;
input bo_wr;
input pregno_t bo_preg;
output pregno_t Rt0_dec;
output pregno_t Rt1_dec;
output pregno_t Rt2_dec;
output pregno_t Rt3_dec;
output Rt0_decv;
output Rt1_decv;
output Rt2_decv;
output Rt3_decv;
output Qupls4_pkg::pipeline_group_reg_t pg_dec;
output reg mux_stallq;
output ren_stallq;
output ren_rst_busy;
input micro_machine_active_mux;
output reg micro_machine_active_dec;
output [Qupls4_pkg::PREGS-1:0] avail_reg;
output reg predicted_correctly_o;
output reg [63:0] new_address_o;

genvar g;
integer n1,n2,n3,n4,n5,n6,n7,n8,n9;
Qupls4_pkg::pipeline_group_reg_t pg_mux_r;
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
reg rd_more;

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

Qupls4_pkg::pipeline_reg_t [MWIDTH-1:0] insm;
Qupls4_pkg::pipeline_reg_t ins4d;
Qupls4_pkg::pipeline_reg_t nopi;
Qupls4_pkg::decode_bus_t [MWIDTH-1:0] dec;
Qupls4_pkg::pipeline_reg_t [MWIDTH-1:0] pr_dec;
Qupls4_pkg::pipeline_reg_t [MWIDTH-1:0] prd, inso;
pregno_t Rt0_dec1;
pregno_t Rt1_dec1;
pregno_t Rt2_dec1;
pregno_t Rt3_dec1;
Qupls4_pkg::pipeline_reg_t [MWIDTH-1:0] tpr;

always_ff @(posedge clk)
	pg_mux_r <= pg_mux;

wire [5:0] uop_count [0:MWIDTH-1];
Qupls4_pkg::micro_op_t [MICROOPS_PER_INSTR-1:0] uop [0:MWIDTH-1];
Qupls4_pkg::micro_op_t [MAX_MICROOPS-1:0] uop_buf;

generate begin : gMicroopMem
	for (g = 0; g < MWIDTH; g = g + 1)
Qupls4_microop_mem uuop1
(
	.om(pg_mux.pr[g].op.om),
	.ir(pg_mux.pr[g].op.uop),
	.num(5'd0), 
	.carry_reg(8'd0),
	.carry_out(1'b0),
	.carry_in(1'b0),
	.count(uop_count[g]),
	.uop(uop[g]),
	.thread(pg_mux.pr[g].op.pc.thread)
);
end
endgenerate

/*
Qupls4_microop_mem uuop2
(
	.om(pg_mux.pr[1].op.om),
	.ir(pg_mux.pr[1].op.uop), 
	.num(5'd0), 
	.carry_reg(8'd0),
	.carry_out(1'b0),
	.carry_in(1'b0),
	.count(uop_count[1]),
	.uop(uop[1])
);

Qupls4_microop_mem uuop3
(
	.om(pg_mux.pr[2].op.om),
	.ir(pg_mux.pr[2].op.uop), 
	.num(5'd0), 
	.carry_reg(8'd0),
	.carry_out(1'b0),
	.carry_in(1'b0),
	.count(uop_count[2]),
	.uop(uop[2])
);

Qupls4_microop_mem uuop4
(
	.om(pg_mux.pr[3].op.om),
	.ir(pg_mux.pr[3].op.uop), 
	.num(5'd0), 
	.carry_reg(8'd0),
	.carry_out(1'b0),
	.carry_in(1'b0),
	.count(uop_count[3]),
	.uop(uop[3])
);
*/

reg rd_mux;
reg [2:0] uop_mark [0:MAX_MICROOPS-1];
reg [3:0] head [0:MWIDTH-1];
reg [3:0] tail;
reg [7:0] room;
reg [7:0] sum_of_count;
reg [7:0] rc_uop_count [0:MWIDTH-1];
integer kk,jj;

always_comb
	if (head[0] > tail)
		room = head[0] - tail;
	else
		room = MAX_MICROOPS + head[0] - tail;

always_comb
begin
	for (n8 = 1; n8 < MWIDTH; n8 = n8 + 1)
		head[n8] = head[n8-1] + 2'd1;
end


// Copy micro-ops from the micro-op decoders into a buffer for further
// processing. The micro-ops are in program order in the buffer. Which
// instruction the micro-op belongs to is stored in an array called uop_mark.

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


// rd_more is a flag set when there is room in the buffer.
assign mux_stallq = !rd_more;

always_comb
begin
	for (n7 = 0; n7 < MWIDTH; n7 = n7 + 1) begin
		tpr[n7] = pg_mux.pr[uop_mark[n7]].op;
		tpr[n7].uop = uop_buf[head[n7]];
	end
end

//reg stomp_dec;

// Define a NOP instruction.
always_comb
begin
	nopi = {$bits(Qupls4_pkg::pipeline_reg_t){1'b0}};
	nopi.pc.pc = Qupls4_pkg::RSTPC;
	nopi.uop = {26'd0,Qupls4_pkg::OP_NOP};
	nopi.uop.any.lead = 3'd1;
	nopi.v = 1'b1;
	nopi.decbus.Rdz = 1'b1;
	nopi.decbus.nop = 1'b1;
	nopi.decbus.alu = 1'b1;
end

generate begin : gRenamer
	if (Qupls4_pkg::SUPPORT_RENAMER) begin
	if (Qupls4_pkg::RENAMER==3) begin
Stark_reg_renamer3 utrn2
(
	.rst(rst_i),		// rst_i here not irst!
	.clk(clk),
	.clk5x(clk5x),
	.ph4(ph4),
	.en(en),
	.restore(restored),
	.restore_list(restore_list & ~unavail_list),
	.tags2free(tags2free),
	.freevals(freevals),
	.alloc0(inso[0].op.decbus.Rd!=8'd0 && inso[0].v),// & ~stomp0),
	.alloc1(inso[1].op.decbus.Rd!=8'd0 && inso[1].v),// & ~stomp1),
	.alloc2(inso[2].op.decbus.Rd!=8'd0 && inso[2].v),// & ~stomp2),
	.alloc3(inso[3].op.decbus.Rd!=8'd0 && inso[3].v),// & ~stomp3),
	.wo0(Rt0_dec),
	.wo1(Rt1_dec),
	.wo2(Rt2_dec),
	.wo3(Rt3_dec),
	.wv0(Rt0_decv),
	.wv1(Rt1_decv),
	.wv2(Rt2_decv),
	.wv3(Rt3_decv),
	.avail(avail_reg),
	.stall(ren_stallq)
);
assign ren_rst_busy = FALSE;
end
else if (Qupls4_pkg::RENAMER==4)
Stark_reg_renamer4 utrn1
(
	.rst(rst_i),		// rst_i here not irst!
	.clk(clk),
//	.clk5x(clk5x),
//	.ph4(ph4),
	.en(en),
	.restore(restored),
	.restore_list(restore_list & ~unavail_list),
	.tags2free(tags2free),
	.freevals(freevals),
	.alloc0(inso[0].decbus.Rd!=8'd0 && inso[0].v),// & ~stomp0),
	.alloc1(inso[1].decbus.Rd!=8'd0 && inso[1].v),// & ~stomp1),
	.alloc2(inso[2].decbus.Rd!=8'd0 && inso[2].v),// & ~stomp2),
	.alloc3(inso[3].decbus.Rd!=8'd0 && inso[3].v),// & ~stomp3),
	.wo0(Rt0_dec),
	.wo1(Rt1_dec),
	.wo2(Rt2_dec),
	.wo3(Rt3_dec),
	.wv0(Rt0_decv),
	.wv1(Rt1_decv),
	.wv2(Rt2_decv),
	.wv3(Rt3_decv),
	.avail(avail_reg),
	.stall(ren_stallq),
	.rst_busy(ren_rst_busy)
);
else
/*
Stark_reg_name_supplier2 utrn1
(
	.rst(rst_i),		// rst_i here not irst!
	.clk(clk),
//	.clk5x(clk5x),
//	.ph4(ph4),
	.en(en),
	.restore(restored),
	.restore_list(restore_list & ~unavail_list),
	.tags2free(tags2free),
	.freevals(freevals),
	.bo_wr(bo_wr),
	.bo_preg(bo_preg),
	.alloc0(inso[0].op.decbus.Rd!=8'd0 && inso[0].v ),// & ~stomp0),
	.alloc1(inso[1].op.decbus.Rd!=8'd0 && inso[1].v && !inso[0].op.decbus.bl),// & ~stomp1),
	.alloc2(inso[2].op.decbus.Rd!=8'd0 && inso[2].v && !inso[0].op.decbus.bl && !inso[1].op.decbus.bl),// & ~stomp2),
	.alloc3(inso[3].op.decbus.Rd!=8'd0 && inso[3].v && !inso[0].op.decbus.bl && !inso[1].op.decbus.bl && !inso[2].op.decbus.bl),// & ~stomp3),
	.o0(Rt0_dec[1]),
	.o1(Rt1_dec[1]),
	.o2(Rt2_dec[1]),
	.o3(Rt3_dec[1]),
	.ov0(Rt0_decv),
	.ov1(Rt1_decv),
	.ov2(Rt2_decv),
	.ov3(Rt3_decv),
	.avail(avail_reg),
	.stall(ren_stallq),
	.rst_busy(ren_rst_busy)
);
assign Rt0_dec = inso[0].op.decbus.Rd==8'd0 ? 9'd0 : Rt0_dec[1];
assign Rt1_dec = inso[1].op.decbus.Rd==8'd0 ? 9'd0 : Rt1_dec[1];
assign Rt2_dec = inso[2].op.decbus.Rd==8'd0 ? 9'd0 : Rt2_dec[1];
assign Rt3_dec = inso[3].op.decbus.Rd==8'd0 ? 9'd0 : Rt3_dec[1];
*/
	assign Rt0_dec = inso[0].decbus.Rd;
	assign Rt1_dec = inso[1].decbus.Rd;
	assign Rt2_dec = inso[2].decbus.Rd;
	assign Rt3_dec = inso[3].decbus.Rd;
	assign Rt0_decv = TRUE;
	assign Rt1_decv = TRUE;
	assign Rt2_decv = TRUE;
	assign Rt3_decv = TRUE;
	assign ren_stallq = FALSE;
	assign ren_rst_busy = FALSE;
end
else begin
	assign Rt0_dec = inso[0].decbus.Rd;
	assign Rt1_dec = inso[1].decbus.Rd;
	assign Rt2_dec = inso[2].decbus.Rd;
	assign Rt3_dec = inso[3].decbus.Rd;
	assign Rt0_decv = TRUE;
	assign Rt1_decv = TRUE;
	assign Rt2_decv = TRUE;
	assign Rt3_decv = TRUE;
	assign ren_stallq = FALSE;
	assign ren_rst_busy = FALSE;
end
//assign ren_rst_busy = 1'b0;
end
endgenerate

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
always_ff @(posedge clk)
if (rst)
	micro_machine_active_dec <= FALSE;
else begin
	if (en)
		micro_machine_active_dec <= micro_machine_active_mux;
end

/*
always_ff @(posedge clk)
if (rst)
	stomp_dec <= FALSE;
else begin
	if (en)
		stomp_dec <= stomp_mux;
end
*/

always_ff @(posedge clk)
if (rst) begin
	for (n9 = 0; n9 < MWIDTH; n9 = n9 + 1)
		insm[n9] <= {$bits(Qupls4_pkg::pipeline_reg_t){1'b0}};
end
else begin
	if (en) begin
		for (n9 = 0; n9 < MWIDTH; n9 = n9 + 1) begin
			insm[n9] <= tpr[n9];
			if (stomp_mux && FALSE) begin
				if (tpr[n9].pc.stream!=kept_stream) begin
					insm[n9] <= nopi;
					insm[n9].pc.stream <= tpr[n9].pc.stream;
				end
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
	.ip(tpr[g].pc.pc),
	.om(sr.om),
	.ipl(sr.ipl),
	.instr(tpr[g].uop),
	.instr_raw(cline >> {tpr[g].cli,4'b0}),
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
		insm[2] <= (stomp_dec && ((pg_mux.pr[0].bt|pg_mux.pr[1].bt|pg_mux.pr[2].bt|pg_mux.pr[3].bt) && branchmiss ? pg_mux.pr[3].pc.bno_t==stomp_bno : pg_mux.pr[3].pc.bno_f==stomp_bno )) ? nopi : pg_mux.pr[3];
//		insm[3] <= (stomp_dec && pg_mux.pr[3].pc.bno_t==stomp_bno) ? nopi : pg_mux.pr[3];
end
*/

always_comb
begin
	fregs_o = 15'd0;
	
	pr_dec[0] = insm[0];
	pr_dec[1] = insm[1];
	pr_dec[2] = insm[2];
	pr_dec[3] = insm[3];
	
	pr_dec[0].v = !stomp_dec;
	pr_dec[1].v = !stomp_dec;
	pr_dec[2].v = !stomp_dec;
	pr_dec[3].v = !stomp_dec;
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
		pr_dec[0].decbus.Rs1 = dec[0].Rs1;
		pr_dec[0].decbus.Rs2 = dec[0].Rs2;
		pr_dec[0].decbus.Rs3 = dec[0].Rs3;
		pr_dec[0].decbus.Rd = dec[0].Rd;
		pr_dec[1].decbus.Rs1 = dec[1].Rs1;
		pr_dec[1].decbus.Rs2 = dec[1].Rs2;
		pr_dec[1].decbus.Rs3 = dec[1].Rs3;
		pr_dec[1].decbus.Rd = dec[1].Rd;
		pr_dec[1].decbus.Rci = dec[1].Rci;
		pr_dec[2].decbus.Rs1 = dec[2].Rs1;
		pr_dec[2].decbus.Rs2 = dec[2].Rs2;
		pr_dec[2].decbus.Rs3 = dec[2].Rs3;
		pr_dec[2].decbus.Rd = dec[2].Rd;
		pr_dec[2].decbus.Rci = dec[2].Rci;
		pr_dec[3].decbus.Rs1 = dec[3].Rs1;
		pr_dec[3].decbus.Rs2 = dec[3].Rs2;
		pr_dec[3].decbus.Rs3 = dec[3].Rs3;
		pr_dec[3].decbus.Rd = dec[3].Rd;
		pr_dec[3].decbus.Rci = dec[3].Rci;
	end
	else begin
		pr_dec[0].decbus.Rs1 = dec[0].Rs1;
		pr_dec[0].decbus.Rs2 = dec[0].Rs2;
		pr_dec[0].decbus.Rs3 = dec[0].Rs3;
		pr_dec[0].decbus.Rd = dec[0].Rd;
		pr_dec[0].decbus.Rci = dec[0].Rci;
		pr_dec[1].decbus.Rs1 = dec[1].Rs1;
		pr_dec[1].decbus.Rs2 = dec[1].Rs2;
		pr_dec[1].decbus.Rs3 = dec[1].Rs3;
		pr_dec[1].decbus.Rd = dec[1].Rd;
		pr_dec[1].decbus.Rci = dec[1].Rci;
		pr_dec[2].decbus.Rs1 = dec[2].Rs1;
		pr_dec[2].decbus.Rs2 = dec[2].Rs2;
		pr_dec[2].decbus.Rs3 = dec[2].Rs3;
		pr_dec[2].decbus.Rd = dec[2].Rd;
		pr_dec[2].decbus.Rci = dec[2].Rci;
		pr_dec[3].decbus.Rs1 = dec[3].Rs1;
		pr_dec[3].decbus.Rs2 = dec[3].Rs2;
		pr_dec[3].decbus.Rs3 = dec[3].Rs3;
		pr_dec[3].decbus.Rd = dec[3].Rd;
		pr_dec[3].decbus.Rci = dec[3].Rci;
	end
	pr_dec[0].decbus = dec[0];
	pr_dec[1].decbus = dec[1];
	pr_dec[2].decbus = dec[2];
	pr_dec[3].decbus = dec[3];

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
			pr_dec[1].atom_count = insm[0].uop.atom.count;
		// Note to mask instructions not micro-ops, by detecting the lead micro-op
		// of the instruction.
		else if (!pr_dec[0].ssm && pr_dec[0].uop.any.lead && |pr_dec[0].atom_count)
			pr_dec[1].atom_count = pr_dec[0].atom_count - 4'd1;
		else
			pr_dec[1].atom_count = pr_dec[0].atom_count;
		if (pr_dec[0].hwi & ~hwi_ignore)
			pr_dec[1].v = INV;

		if (dec[1].atom && pr_dec[1].v)
			pr_dec[2].atom_count = insm[1].uop.atom.count;
		else if (!pr_dec[1].ssm && pr_dec[1].uop.any.lead && |pr_dec[1].atom_count)
			pr_dec[2].atom_count = pr_dec[1].atom_count - 4'd1;
		else
			pr_dec[2].atom_count = pr_dec[1].atom_count;
		if (pr_dec[0].hwi & ~hwi_ignore)
			pr_dec[2].v = INV;

		if (dec[2].atom && pr_dec[2].v)
			pr_dec[3].atom_count = insm[2].uop.atom.count;
		else if (!pr_dec[2].ssm && pr_dec[2].uop.any.lead && |pr_dec[2].atom_count)
			pr_dec[3].atom_count = pr_dec[2].atom_count - 4'd1;
		else
			pr_dec[3].atom_count = pr_dec[2].atom_count;
		if (pr_dec[0].hwi & ~hwi_ignore)
			pr_dec[3].v = INV;

		if (dec[3].atom && pr_dec[3].v)
			atom_count_o = insm[3].uop.atom.count;
		else if (!pr_dec[3].ssm && pr_dec[3].uop.any.lead && |pr_dec[3].atom_count)
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
			pr_dec[1].decbus.pred_mask = insm[0].uop.pred.mask;
			pr_dec[1].decbus.pred_no = pr_dec[0].decbus.pred_no;
		end
		else if (!pr_dec[0].ssm && pr_dec[0].uop.any.lead && |pr_dec[0].pred_mask) begin
			pr_dec[1].decbus.pred_mask = pr_dec[0].decbus.pred_mask >> 2'd2;
			pr_dec[1].decbus.pred_no = pr_dec[0].decbus.pred_no;
		end
		else begin
			pr_dec[1].decbus.pred_mask = pr_dec[0].decbus.pred_mask;
			pr_dec[1].decbus.pred_no = pr_dec[0].decbus.pred_no;
		end

		if (dec[1].pred && pr_dec[1].v) begin
			pr_dec[1].decbus.pred_no = pr_dec[1].decbus.pred_no + 5'd1;
			pr_dec[2].decbus.pred_mask = insm[1].uop.pred.mask;
			pr_dec[2].decbus.pred_no = pr_dec[1].decbus.pred_no;
		end
		else if (!pr_dec[1].ssm && pr_dec[1].uop.any.lead && |pr_dec[1].pred_mask) begin
			pr_dec[2].decbus.pred_mask = pr_dec[1].decbus.pred_mask >> 2'd2;
			pr_dec[2].decbus.pred_no = pr_dec[1].decbus.pred_no;
		end
		else begin
			pr_dec[2].decbus.pred_mask = pr_dec[1].decbus.pred_mask;
			pr_dec[2].decbus.pred_no = pr_dec[1].decbus.pred_no;
		end

		if (dec[2].pred && pr_dec[2].v) begin
			pr_dec[2].decbus.pred_no = pr_dec[2].decbus.pred_no + 5'd1;
			pr_dec[3].decbus.pred_mask = insm[2].uop.pred.mask;
			pr_dec[3].decbus.pred_no = pr_dec[2].decbus.pred_no;
		end
		else if (!pr_dec[2].ssm && pr_dec[2].uop.any.lead && |pr_dec[2].pred_mask) begin
			pr_dec[3].decbus.pred_mask = pr_dec[2].decbus.pred_mask >> 2'd2;
			pr_dec[3].decbus.pred_no = pr_dec[2].decbus.pred_no;
		end
		else begin
			pr_dec[3].decbus.pred_mask = pr_dec[2].decbus.pred_mask;
			pr_dec[3].decbus.pred_no = pr_dec[2].decbus.pred_no;
		end

		if (dec[3].pred && pr_dec[3].v) begin
			pred_no_o = pr_dec[3].decbus.pred_no + 5'd1;
			pred_mask_o = insm[3].uop.pred.mask;
		end
		else if (!pr_dec[3].ssm && pr_dec[3].uop.any.lead && |pr_dec[3].pred_mask) begin
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
			pr_dec[1].carry_mod = insm[0].uop;
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
			pr_dec[2].carry_mod = insm[1].uop;
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
			pr_dec[3].carry_mod = insm[2].uop;
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
			carry_mod_o = insm[3].uop;
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
		pr_dec[1].uop.any.opcode = Qupls4_pkg::OP_NOP;
		pr_dec[2].v = INV;
		pr_dec[2].uop.any.opcode = Qupls4_pkg::OP_NOP;
		pr_dec[3].v = INV;
		pr_dec[3].uop.any.opcode = Qupls4_pkg::OP_NOP;
	end
	else if (pr_dec[1].decbus.bsr|pr_dec[1].decbus.jsr) begin
		pr_dec[2].v = INV;
		pr_dec[2].uop.any.opcode = Qupls4_pkg::OP_NOP;
		pr_dec[3].v = INV;
		pr_dec[3].uop.any.opcode = Qupls4_pkg::OP_NOP;
	end
	else if (pr_dec[2].decbus.bsr|pr_dec[2].decbus.jsr) begin
		pr_dec[3].v = INV;
		pr_dec[3].uop.any.opcode = Qupls4_pkg::OP_NOP;
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
always_comb bsr0_tgt = {{23{pr_dec[0].uop.bsr.disp[40]}},pr_dec[0].uop.bsr.disp,1'b0} + pr_dec[0].pc.pc;
always_comb bsr1_tgt = {{23{pr_dec[1].uop.bsr.disp[40]}},pr_dec[1].uop.bsr.disp,1'b0} + pr_dec[1].pc.pc;
always_comb bsr2_tgt = {{23{pr_dec[2].uop.bsr.disp[40]}},pr_dec[2].uop.bsr.disp,1'b0} + pr_dec[2].pc.pc;
always_comb jsr0_tgt = {{23{pr_dec[0].uop.bsr.disp[40]}},pr_dec[0].uop.bsr.disp,1'b0};
always_comb jsr1_tgt = {{23{pr_dec[1].uop.bsr.disp[40]}},pr_dec[1].uop.bsr.disp,1'b0};
always_comb jsr2_tgt = {{23{pr_dec[2].uop.bsr.disp[40]}},pr_dec[2].uop.bsr.disp,1'b0};

reg predicted_correctly;

always_comb
begin
	new_address_o = Qupls4_pkg::RSTPC;
	predicted_correctly_o = TRUE;
	if (pr_dec[0].decbus.bsr|pr_dec[0].decbus.jsr) begin
		predicted_correctly_o = FALSE;
		new_address_o = pr_dec[0].decbus.bsr ? bsr0_tgt : jsr0_tgt;
		if (pg_dec.pr[0].op.pc.pc==pg_mux.pr[0].op.pc.pc)
			predicted_correctly_o = TRUE;
	end
	else if (pr_dec[1].decbus.bsr|pr_dec[1].decbus.jsr) begin
		predicted_correctly_o = FALSE;
		new_address_o = pr_dec[1].decbus.bsr ? bsr1_tgt : jsr1_tgt;
		if (pg_dec.pr[1].op.pc.pc==pg_mux.pr[0].op.pc.pc)
			predicted_correctly_o = TRUE;
	end
	else if (pr_dec[2].decbus.bsr|pr_dec[2].decbus.jsr) begin
		predicted_correctly_o = FALSE;
		new_address_o = pr_dec[2].decbus.bsr ? bsr2_tgt : jsr2_tgt;
		if (pg_dec.pr[2].op.pc.pc==pg_mux.pr[0].op.pc.pc)
			predicted_correctly_o = TRUE;
	end
end

/* under construction
Stark_space_branches uspb1
(
	.rst(rst_i),
	.clk(clk),
	.en(en_i),
	.get(get),
	.ins_i(prd),
	.ins_o(inso),
	.stall(stall)
);
*/
always_comb
begin
	pg_dec = pg_mux_r;
	pg_dec.pr[0].op.hwi_level = pg_mux_r.hdr.irq.level;
	if (hwi_ignore) begin
		if (pg_mux_r.hdr.irq.level != 6'd63) begin
			pg_dec.hdr.hwi = 1'b0;
			pg_dec.pr[0].op.hwi = 1'b0;
		end
	end
	pg_dec.pr[0].op = inso[0];
	pg_dec.pr[1].op = inso[1];
	pg_dec.pr[2].op = inso[2];
	pg_dec.pr[3].op = inso[3];
end
always_comb
begin
/*
	if (pr_dec[0].ins.any.opcode==OP_Bcc)
		$finish;
	if (pr_dec[1].ins.any.opcode==OP_Bcc)
		$finish;
	if (pr_dec[2].ins.any.opcode==OP_Bcc)
		$finish;
	if (pr_dec[3].ins.any.opcode==OP_Bcc)
		$finish;
*/
end

always_comb
begin
/*
	if (inso[0]_o.ins.any.opcode==OP_Bcc)
		$finish;
	if (inso[1]_o.ins.any.opcode==OP_Bcc)
		$finish;
	if (inso[2]_o.ins.any.opcode==OP_Bcc)
		$finish;
	if (inso[3]_o.ins.any.opcode==OP_Bcc)
		$finish;
*/
end

always_ff @(posedge clk)
if (rst)
	flush_dec <= 1'b0;
else begin
	if (en)
		flush_dec <= flush_mux;
end

endmodule

