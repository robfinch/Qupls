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
// 7850 LUTs / 2150 FFs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Stark_pkg::*;

module Stark_pipeline_dec(rst_i, rst, clk, en, clk5x, ph4, new_cline_mux, cline,
	restored, restore_list, unavail_list, sr,
	tags2free, freevals, bo_wr, bo_preg,
	ins0_d_inv, ins1_d_inv, ins2_d_inv, ins3_d_inv,
	stomp_dec, stomp_mux, stomp_bno, pg0_mux, pg1_mux,
	Rt0_dec, Rt1_dec, Rt2_dec, Rt3_dec, Rt0_decv, Rt1_decv, Rt2_decv, Rt3_decv,
	micro_machine_active_mux, micro_machine_active_dec,
	pg_dec,
	ren_stallq, ren_rst_busy, avail_reg
);
input rst_i;
input rst;
input clk;
input en;
input clk5x;
input [4:0] ph4;
input new_cline_mux;
input [1023:0] cline;
input restored;
input [Stark_pkg::PREGS-1:0] restore_list;
input [Stark_pkg::PREGS-1:0] unavail_list;
input Stark_pkg::status_reg_t sr;
input stomp_dec;
input stomp_mux;
input [4:0] stomp_bno;
input Stark_pkg::pipeline_group_reg_t pg0_mux;
input Stark_pkg::pipeline_group_reg_t pg1_mux;
input pregno_t [3:0] tags2free;
input [3:0] freevals;
input bo_wr;
input pregno_t bo_preg;
input ins0_d_inv;
input ins1_d_inv;
input ins2_d_inv;
input ins3_d_inv;
output pregno_t Rt0_dec;
output pregno_t Rt1_dec;
output pregno_t Rt2_dec;
output pregno_t Rt3_dec;
output Rt0_decv;
output Rt1_decv;
output Rt2_decv;
output Rt3_decv;
output Stark_pkg::pipeline_group_reg_t pg_dec;
output ren_stallq;
output ren_rst_busy;
input micro_machine_active_mux;
output reg micro_machine_active_dec;
output [PREGS-1:0] avail_reg;

integer n1,n2,n3;
Stark_pkg::pipeline_group_reg_t pg0_mux_r;
reg [31:0] carry_mod_i;
reg [31:0] carry_mod_o;
reg [11:0] atom_mask_i;
reg [11:0] atom_mask_o;
reg [31:0] nops;
reg hilo;
reg hwi_ignore;
regs_t fregs_i;
regs_t fregs_o;

always @(posedge clk)
if (rst)
	carry_mod_i <= 32'h0;
else begin
	if (en)
		carry_mod_i <= carry_mod_o;
end
always @(posedge clk)
if (rst)
	atom_mask_i <= 12'd0;
else begin
	if (en)
		atom_mask_i <= atom_mask_o;
end
always @(posedge clk)
if (rst)
	fregs_i <= 15'h0;
else begin
	if (en)
		fregs_i <= fregs_o;
end

Stark_pkg::pipeline_reg_t ins0m;
Stark_pkg::pipeline_reg_t ins1m;
Stark_pkg::pipeline_reg_t ins2m;
Stark_pkg::pipeline_reg_t ins3m;
Stark_pkg::pipeline_reg_t ins4d;
Stark_pkg::pipeline_reg_t nopi;
Stark_pkg::decode_bus_t dec0,dec1,dec2,dec3,dec4;
Stark_pkg::pipeline_reg_t pr0_dec,pr1_dec,pr2_dec,pr3_dec;
Stark_pkg::pipeline_reg_t [3:0] prd, inso;
pregno_t Rt0_dec1;
pregno_t Rt1_dec1;
pregno_t Rt2_dec1;
pregno_t Rt3_dec1;

always @(posedge clk)
	pg0_mux_r <= pg0_mux;

Stark_min_constant_decoder umcd1 (cline[511:0], nops[15:0]);
Stark_min_constant_decoder umcd2 (cline[1023:512], nops[31:16]);

//reg stomp_dec;

// Define a NOP instruction.
always_comb
begin
	nopi = {$bits(Stark_pkg::pipeline_reg_t){1'b0}};
	nopi.pc.pc = RSTPC;
	nopi.mcip = 12'h1A0;
	nopi.ins = {26'd0,OP_NOP};
	nopi.v = 1'b1;
	nopi.decbus.Rdz = 1'b1;
	nopi.decbus.nop = 1'b1;
	nopi.decbus.alu = 1'b1;
end

generate begin : gRenamer
	if (SUPPORT_RENAMER) begin
	if (RENAMER==3) begin
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
	.stall(ren_stallq)
);
assign ren_rst_busy = FALSE;
end
else if (RENAMER==4)
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
	.alloc0(inso[0].decbus.Rd!=8'd0 && inso[0].v ),// & ~stomp0),
	.alloc1(inso[1].decbus.Rd!=8'd0 && inso[1].v && !inso[0].decbus.bl),// & ~stomp1),
	.alloc2(inso[2].decbus.Rd!=8'd0 && inso[2].v && !inso[0].decbus.bl && !inso[1].decbus.bl),// & ~stomp2),
	.alloc3(inso[3].decbus.Rd!=8'd0 && inso[3].v && !inso[0].decbus.bl && !inso[1].decbus.bl && !inso[2].decbus.bl),// & ~stomp3),
	.o0(Rt0_dec1),
	.o1(Rt1_dec1),
	.o2(Rt2_dec1),
	.o3(Rt3_dec1),
	.ov0(Rt0_decv),
	.ov1(Rt1_decv),
	.ov2(Rt2_decv),
	.ov3(Rt3_decv),
	.avail(avail_reg),
	.stall(ren_stallq),
	.rst_busy(ren_rst_busy)
);
assign Rt0_dec = inso[0].decbus.Rd==8'd0 ? 9'd0 : Rt0_dec1;
assign Rt1_dec = inso[1].decbus.Rd==8'd0 ? 9'd0 : Rt1_dec1;
assign Rt2_dec = inso[2].decbus.Rd==8'd0 ? 9'd0 : Rt2_dec1;
assign Rt3_dec = inso[3].decbus.Rd==8'd0 ? 9'd0 : Rt3_dec1;
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
	ins0m <= {$bits(Stark_pkg::pipeline_reg_t){1'b0}};
end
else begin
	if (en)
	begin
		ins0m <= pg0_mux.pr0;
		if (stomp_mux && FALSE) begin
			if (pg0_mux.pr0.pc.bno_t!=stomp_bno) begin
				ins0m <= nopi;
				ins0m.pc.bno_t <= pg0_mux.pr0.pc.bno_t;
			end
		end
	end
end

always_ff @(posedge clk)
if (rst) begin
	ins1m <= {$bits(Stark_pkg::pipeline_reg_t){1'b0}};
end
else begin
	if (en)
	begin
		ins1m <= pg0_mux.pr1;
		if (stomp_mux && FALSE) begin
			if (pg0_mux.pr1.pc.bno_t!=stomp_bno) begin
				ins1m <= nopi;
				ins1m.pc.bno_t <= pg0_mux.pr1.pc.bno_t;
			end
		end
	end
end

always_ff @(posedge clk)
if (rst) begin
	ins2m <= {$bits(Stark_pkg::pipeline_reg_t){1'b0}};
end
else begin
	if (en)
	begin
		ins2m <= pg0_mux.pr2;
		if (stomp_mux && FALSE) begin
			if (pg0_mux.pr2.pc.bno_t!=stomp_bno) begin
				ins2m <= nopi;
				ins2m.pc.bno_t <= pg0_mux.pr2.pc.bno_t;
			end
		end
	end
end

always_ff @(posedge clk)
if (rst) begin
	ins3m <= {$bits(Stark_pkg::pipeline_reg_t){1'b0}};
end
else begin
	if (en)
	begin
		ins3m <= pg0_mux.pr3;
		if (stomp_mux && FALSE) begin
			if (pg0_mux.pr3.pc.bno_t!=stomp_bno) begin
				ins3m <= nopi;
				ins3m.pc.bno_t <= pg0_mux.pr3.pc.bno_t;
			end
		end
	end
end

/* An extra decoder is needed to catch any postfix instruction for the last
	 instruction.
*/
Stark_decoder udeci0
(
	.rst(rst),
	.clk(clk),
	.en(en),
	.cline(cline),
	.om(sr.om),
	.ipl(sr.ipl),
	.instr(pg0_mux.pr0),
	.dbo(dec0)
);

Stark_decoder udeci1
(
	.rst(rst),
	.clk(clk),
	.en(en),
	.cline(cline),
	.om(sr.om),
	.ipl(sr.ipl),
	.instr(pg0_mux.pr1),
	.dbo(dec1)
);

Stark_decoder udeci2
(
	.rst(rst),
	.clk(clk),
	.en(en),
	.cline(cline),
	.om(sr.om),
	.ipl(sr.ipl),
	.instr(pg0_mux.pr2),
	.dbo(dec2)
);

Stark_decoder udeci3
(
	.rst(rst),
	.clk(clk),
	.en(en),
	.cline(cline),
	.om(sr.om),
	.ipl(sr.ipl),
	.instr(pg0_mux.pr3),
	.dbo(dec3)
);

Stark_decoder udeci4
(
	.rst(rst),
	.clk(clk),
	.en(en),
	.cline(cline),
	.om(sr.om),
	.ipl(sr.ipl),
	.instr(pg1_mux.pr0),
	.dbo(dec4)
);
/*
always_ff @(posedge clk)
if (rst_i) begin
	ins3m <= {$bits(pipeline_reg_t){1'b0}};
end
else begin
	if (en_i)
		ins2m <= (stomp_dec && ((pg0_mux.pr0.bt|pg0_mux.pr1.bt|pg0_mux.pr2.bt|pg0_mux.pr3.bt) && branchmiss ? pg0_mux.pr3.pc.bno_t==stomp_bno : pg0_mux.pr3.pc.bno_f==stomp_bno )) ? nopi : pg0_mux.pr3;
//		ins3m <= (stomp_dec && pg0_mux.pr3.pc.bno_t==stomp_bno) ? nopi : pg0_mux.pr3;
end
*/

always_comb
begin
	fregs_o = 15'd0;
	
	pr0_dec = ins0m;
	pr1_dec = ins1m;
	pr2_dec = ins2m;
	pr3_dec = ins3m;
	
	pr0_dec.v = !stomp_dec;
	pr1_dec.v = !stomp_dec;
	pr2_dec.v = !stomp_dec;
	pr3_dec.v = !stomp_dec;
	if (stomp_dec) begin
		// Clear the branch flags so that a new checkpoint is not assigned and
		// the checkpoint will not be freed.
		/*
		pr0_dec.decbus.br = FALSE;
		pr0_dec.decbus.cjb = FALSE;
		pr1_dec.decbus.br = FALSE;
		pr1_dec.decbus.cjb = FALSE;
		pr2_dec.decbus.br = FALSE;
		pr2_dec.decbus.cjb = FALSE;
		pr3_dec.decbus.br = FALSE;
		pr3_dec.decbus.cjb = FALSE;
		*/
		pr0_dec.decbus.Rci = dec0.Rci;
		pr0_dec.decbus.Rs1 = dec0.Rs1;
		pr0_dec.decbus.Rs2 = dec0.Rs2;
		pr0_dec.decbus.Rs3 = dec0.Rs3;
		pr0_dec.decbus.Rd = dec0.Rd;
		pr1_dec.decbus.Rs1 = dec1.Rs1;
		pr1_dec.decbus.Rs2 = dec1.Rs2;
		pr1_dec.decbus.Rs3 = dec1.Rs3;
		pr1_dec.decbus.Rd = dec1.Rd;
		pr1_dec.decbus.Rci = dec1.Rci;
		pr2_dec.decbus.Rs1 = dec2.Rs1;
		pr2_dec.decbus.Rs2 = dec2.Rs2;
		pr2_dec.decbus.Rs3 = dec2.Rs3;
		pr2_dec.decbus.Rd = dec2.Rd;
		pr2_dec.decbus.Rci = dec2.Rci;
		pr3_dec.decbus.Rs1 = dec3.Rs1;
		pr3_dec.decbus.Rs2 = dec3.Rs2;
		pr3_dec.decbus.Rs3 = dec3.Rs3;
		pr3_dec.decbus.Rd = dec3.Rd;
		pr3_dec.decbus.Rci = dec3.Rci;
	end
	else begin
		pr0_dec.decbus.Rs1 = dec0.Rs1;
		pr0_dec.decbus.Rs2 = dec0.Rs2;
		pr0_dec.decbus.Rs3 = dec0.Rs3;
		pr0_dec.decbus.Rd = dec0.Rd;
		pr0_dec.decbus.Rci = dec0.Rci;
		pr1_dec.decbus.Rs1 = dec1.Rs1;
		pr1_dec.decbus.Rs2 = dec1.Rs2;
		pr1_dec.decbus.Rs3 = dec1.Rs3;
		pr1_dec.decbus.Rd = dec1.Rd;
		pr1_dec.decbus.Rci = dec1.Rci;
		pr2_dec.decbus.Rs1 = dec2.Rs1;
		pr2_dec.decbus.Rs2 = dec2.Rs2;
		pr2_dec.decbus.Rs3 = dec2.Rs3;
		pr2_dec.decbus.Rd = dec2.Rd;
		pr2_dec.decbus.Rci = dec2.Rci;
		pr3_dec.decbus.Rs1 = dec3.Rs1;
		pr3_dec.decbus.Rs2 = dec3.Rs2;
		pr3_dec.decbus.Rs3 = dec3.Rs3;
		pr3_dec.decbus.Rd = dec3.Rd;
		pr3_dec.decbus.Rci = dec3.Rci;
	end
	pr0_dec.decbus = dec0;
	if (dec1.pfxa) begin pr0_dec.decbus.imma = {dec1.imma[63:5],dec0.Rs1[4:0]}; pr0_dec.decbus.has_imma = 1'b1; end
	if (dec1.pfxb) begin 
		pr0_dec.decbus.immb = dec0.mem ? {dec1.immb[63:5],dec0.immb[4:0]} : {dec1.immb[63:5],dec0.Rs2[4:0]};
		pr0_dec.decbus.has_immb = 1'b1;
	end
	if (dec1.pfxc) begin pr0_dec.decbus.immc = {dec1.immc[63:5],dec0.Rs3[4:0]}; pr0_dec.decbus.has_immc = 1'b1; end
	pr1_dec.decbus = dec1;
	if (dec2.pfxa) begin 
		pr1_dec.decbus.imma = {dec2.imma[63:5],dec1.Rs1[4:0]};
		pr1_dec.decbus.has_imma = 1'b1;
	end
	if (dec2.pfxb) begin
		pr1_dec.decbus.immb = dec1.mem ? {dec2.immb[63:5],dec1.immb[4:0]} : {dec2.immb[63:5],dec1.Rs2[4:0]};
		pr1_dec.decbus.has_immb = 1'b1;
	end
	if (dec2.pfxc) begin pr1_dec.decbus.immc = {dec2.immc[63:5],dec1.Rs3[4:0]}; pr1_dec.decbus.has_immc = 1'b1; end
	pr2_dec.decbus = dec2;
	if (dec3.pfxa) begin pr2_dec.decbus.imma = {dec3.imma[63:5],dec2.Rs1[4:0]}; pr2_dec.decbus.has_imma = 1'b1; end
	if (dec3.pfxb) begin 
		pr2_dec.decbus.immb = dec2.mem ? {dec3.immb[63:5],dec2.immb[4:0]} : {dec3.immb[63:5],dec2.Rs2[4:0]};
		pr2_dec.decbus.has_immb = 1'b1;
	end
	if (dec3.pfxc) begin pr2_dec.decbus.immc = {dec3.immc[63:5],dec2.Rs3[4:0]}; pr2_dec.decbus.has_immc = 1'b1; end
	pr3_dec.decbus = dec3;
	if (dec4.pfxa) begin pr3_dec.decbus.imma = {dec4.imma[63:5],dec3.Rs1[4:0]}; pr3_dec.decbus.has_imma = 1'b1; end
	if (dec4.pfxb) begin
		pr3_dec.decbus.immb = dec3.mem ? {dec4.immb[63:5],dec3.immb[4:0]} : {dec4.immb[63:5],dec3.Rs2[4:0]};
		pr3_dec.decbus.has_immb = 1'b1;
	end
	if (dec4.pfxc) begin pr3_dec.decbus.immc = {dec4.immc[63:5],dec3.Rs3[4:0]}; pr3_dec.decbus.has_immc = 1'b1; end

	// Mark instructions invalid according to where constants are located.
	hilo = pr0_dec.pc.pc[6];
	for (n3 = 0; n3 < 32; n3 = n3 + 1) begin
		if (nops[{~hilo,pr0_dec.pc.pc[5:2]}])
			pr0_dec.v <= INV;
		if (nops[{hilo^pr1_dec.pc.pc[6],pr1_dec.pc.pc[5:2]}])
			pr1_dec.v <= INV;
		if (nops[{hilo^pr2_dec.pc.pc[6],pr2_dec.pc.pc[5:2]}])
			pr2_dec.v <= INV;
		if (nops[{hilo^pr3_dec.pc.pc[6],pr3_dec.pc.pc[5:2]}])
			pr3_dec.v <= INV;
	end

	// Apply interrupt masking.
	// Done by clearing the hardware interrupt flag.
	// Hardware interrupts are recognized only for a group since all instructions 
	// in the group are processed in the same clock cycle. An interrupt cannot
	// happen in the middle of a group. This means we only need check the masking
	// of the first instruction of the group. If the first instruction was not
	// masked, and a later one was, then the interrupt will still occur, but the
	// later instructions will not be executed.
	pr0_dec.atom_mask = atom_mask_i;
	hwi_ignore = FALSE;
	if ((pr0_dec.atom_mask[0]|fregs_i.v) && pr0_dec.v) begin
		hwi_ignore = TRUE;
	end

	if (dec0.pred && pr0_dec.v)
		pr1_dec.atom_mask = dec0.pred_atom_mask;
	else if (dec0.atom && pr0_dec.v)
		pr1_dec.atom_mask = {ins0m.ins[23:9],ins0m.ins[0]};
	else
		pr1_dec.atom_mask = pr0_dec.atom_mask >> 12'd1;
	if (pr0_dec.hwi & ~hwi_ignore)
		pr1_dec.v = INV;

	if (dec1.pred && pr1_dec.v)
		pr2_dec.atom_mask = dec1.pred_atom_mask;
	else if (dec1.atom && pr1_dec.v)
		pr2_dec.atom_mask = {ins1m.ins[23:9],ins1m.ins[0]};
	else
		pr2_dec.atom_mask = pr1_dec.atom_mask >> 12'd1;
	if (pr0_dec.hwi & ~hwi_ignore)
		pr2_dec.v = INV;

	if (dec2.pred && pr2_dec.v)
		pr3_dec.atom_mask = dec2.pred_atom_mask;
	else if (dec2.atom && pr2_dec.v)
		pr3_dec.atom_mask = {ins2m.ins[23:9],ins2m.ins[0]};
	else
		pr3_dec.atom_mask = pr2_dec.atom_mask >> 12'd1;
	if (pr0_dec.hwi & ~hwi_ignore)
		pr3_dec.v = INV;

	if (dec3.pred && pr3_dec.v)
		atom_mask_o = dec3.pred_atom_mask;
	else if (dec3.atom && pr3_dec.v)
		atom_mask_o = {ins3m.ins[23:9],ins3m.ins[0]};
	else
		atom_mask_o = pr3_dec.atom_mask >> 12'd1;

	// Apply carry mod to instructions in same group, and adjust
	pr0_dec.carry_mod = carry_mod_i;
	if (pr0_dec.v)
	case ({pr0_dec.carry_mod[9],pr0_dec.carry_mod[0]})
	2'd0:	;
	2'd1:	pr0_dec.decbus.Rci = pr0_dec.carry_mod[25:24]|7'd40;
	2'd2:	pr0_dec.decbus.Rco = pr0_dec.carry_mod[25:24]|7'd40;
	2'd3:
		begin
			pr0_dec.decbus.Rci = pr0_dec.carry_mod[25:24]|7'd40;
			pr0_dec.decbus.Rco = pr0_dec.carry_mod[25:24]|7'd40;
		end
	endcase
	if (dec0.carry && pr0_dec.v) begin
		pr1_dec.carry_mod = ins0m.ins;
	end
	else begin
		pr1_dec.carry_mod = pr0_dec.carry_mod;
		pr1_dec.carry_mod[0] = pr0_dec.carry_mod[10];
		pr1_dec.carry_mod[23:9] = {2'd0,pr0_dec.carry_mod[23:11]};
	end
	if (pr1_dec.v)
	case ({pr1_dec.carry_mod[9],pr1_dec.carry_mod[0]})
	2'd0:	;
	2'd1:	pr1_dec.decbus.Rci = pr1_dec.carry_mod[25:24]|7'd40;
	2'd2:	pr1_dec.decbus.Rco = pr1_dec.carry_mod[25:24]|7'd40;
	2'd3:
		begin
			pr1_dec.decbus.Rci = pr1_dec.carry_mod[25:24]|7'd40;
			pr1_dec.decbus.Rco = pr1_dec.carry_mod[25:24]|7'd40;
		end
	endcase
	if (dec1.carry && pr1_dec.v) begin
		pr2_dec.carry_mod = ins1m.ins;
	end
	else begin
		pr2_dec.carry_mod = pr1_dec.carry_mod;
		pr2_dec.carry_mod[0] = pr1_dec.carry_mod[10];
		pr2_dec.carry_mod[23:9] = {2'd0,pr1_dec.carry_mod[23:11]};
	end
	if (pr2_dec.v)
	case ({pr2_dec.carry_mod[9],pr2_dec.carry_mod[0]})
	2'd0:	;
	2'd1:	pr2_dec.decbus.Rci = pr1_dec.carry_mod[25:24]|7'd40;
	2'd2:	pr2_dec.decbus.Rco = pr1_dec.carry_mod[25:24]|7'd40;
	2'd3:
		begin
			pr2_dec.decbus.Rci = pr1_dec.carry_mod[25:24]|7'd40;
			pr2_dec.decbus.Rco = pr1_dec.carry_mod[25:24]|7'd40;
		end
	endcase
	if (dec2.carry && pr2_dec.v) begin
		pr3_dec.carry_mod = ins2m.ins;
	end
	else begin
		pr3_dec.carry_mod = pr2_dec.carry_mod;
		pr3_dec.carry_mod[0] = pr2_dec.carry_mod[10];
		pr3_dec.carry_mod[23:9] = {2'd0,pr2_dec.carry_mod[23:11]};
	end
	if (pr3_dec.v)
	case ({pr3_dec.carry_mod[9],pr3_dec.carry_mod[0]})
	2'd0:	;
	2'd1:	pr3_dec.decbus.Rci = pr2_dec.carry_mod[25:24]|7'd40;
	2'd2:	pr3_dec.decbus.Rco = pr2_dec.carry_mod[25:24]|7'd40;
	2'd3:
		begin
			pr3_dec.decbus.Rci = pr2_dec.carry_mod[25:24]|7'd40;
			pr3_dec.decbus.Rco = pr2_dec.carry_mod[25:24]|7'd40;
		end
	endcase
	if (dec3.carry & pr3_dec.v) begin
		carry_mod_o = ins3m.ins;
	end
	else begin
		carry_mod_o = pr3_dec.carry_mod;
		carry_mod_o[0] = pr3_dec.carry_mod[10];
		carry_mod_o[23:9] = {2'd0,pr3_dec.carry_mod[23:11]};
	end

	// Detect FREGS/REGS register additions
	if (fregs_i.v)
		pr0_dec.decbus.Rs3 = fregs_i.Rs3;
	if (dec0.xregs.v & pr0_dec.v)
		pr1_dec.decbus.Rs3 = dec0.xregs.Rs3;
	if (dec1.xregs.v & pr1_dec.v)
		pr2_dec.decbus.Rs3 = dec1.xregs.Rs3;
	if (dec2.xregs.v & pr2_dec.v)
		pr3_dec.decbus.Rs3 = dec2.xregs.Rs3;
	if (dec3.xregs.v & pr3_dec.v)
		fregs_o = dec3.xregs;

	pr0_dec.mcip = ins0m.mcip;
	pr1_dec.mcip = ins1m.mcip;
	pr2_dec.mcip = ins2m.mcip;
	pr3_dec.mcip = ins3m.mcip;
	
	if (ins1_d_inv) pr1_dec.v = FALSE;
	if (ins1_d_inv) pr2_dec.v = FALSE;
	if (ins3_d_inv) pr3_dec.v = FALSE;
	pr0_dec.om = sr.om;
	pr1_dec.om = sr.om;
	pr2_dec.om = sr.om;
	pr3_dec.om = sr.om;
end

always_comb prd[0] = pr0_dec;
always_comb prd[1] = pr1_dec;
always_comb prd[2] = pr2_dec;
always_comb prd[3] = pr3_dec;

always_comb inso = prd;

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
	pg_dec = pg0_mux_r;
	if (hwi_ignore) begin
		if (pg0_mux_r.hdr.irq.level != 6'd63) begin
			pg_dec.hdr.hwi = 1'b0;
		end
	end
	pg_dec.pr0 = inso[0];
	pg_dec.pr1 = inso[1];
	pg_dec.pr2 = inso[2];
	pg_dec.pr3 = inso[3];
end
always_comb
begin
/*
	if (pr0_dec.ins.any.opcode==OP_Bcc)
		$finish;
	if (pr1_dec.ins.any.opcode==OP_Bcc)
		$finish;
	if (pr2_dec.ins.any.opcode==OP_Bcc)
		$finish;
	if (pr3_dec.ins.any.opcode==OP_Bcc)
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

endmodule

