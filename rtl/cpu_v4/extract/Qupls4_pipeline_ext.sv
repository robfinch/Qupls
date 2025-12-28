// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2025  Robert Finch, Waterloo
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
//
// Multiplex a hardware interrupt into the instruction stream.s
// Multiplex micro-code instructions into the instruction stream.
// Modify instructions for register bit lists.
//
// 1800 LUTs / 1200 FFs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_pipeline_ext(rst_i, clk_i, rstcnt, ihit, en_i,
	kept_stream, stomp_ext, nop_o, carry_mod_fet, ssm_flag, hwipc_fet,
	irq_fet, irq_in_fet, irq_sn_fet, ipl_fet, sr, pt_ext, pt_dec, p_override, po_bno,
	branchmiss, misspc_fet, flush_fet, flush_ext,
	micro_machine_active, cline_fet, cline_ext, new_cline_ext,
	reglist_active, grp_i, grp_o,
	takb_fet, vl,
	pc0_fet, uop_num_fet, uop_num_ext,
	ls_bmf_i, pack_regs_i, scale_regs_i, regcnt_i,
	pg_ext, new_stream, alloc_stream,
	do_bsr, bsr_tgt, do_ret, ret_pc, do_call, get, mux_stallq, fet_stallq);
parameter MWIDTH = Qupls4_pkg::MWIDTH;
input rst_i;
input clk_i;
input [2:0] rstcnt;
input ihit;
input irq_fet;
input Qupls4_pkg::irq_info_packet_t irq_in_fet;
input cpu_types_pkg::seqnum_t irq_sn_fet;
input [5:0] ipl_fet;
input en_i;
input pc_stream_t kept_stream;
input stomp_ext;
output reg nop_o;
input [31:0] carry_mod_fet;
input ssm_flag;
input cpu_types_pkg::pc_address_ex_t hwipc_fet;
input micro_machine_active;
input Qupls4_pkg::status_reg_t sr;
input reglist_active;
input branchmiss;
input cpu_types_pkg::pc_address_ex_t misspc_fet;
input flush_fet;
output reg flush_ext;
input [1023:0] cline_fet;
output reg [1023:0] cline_ext;
output reg new_cline_ext;
input [2:0] grp_i;
output reg [2:0] grp_o;
input cpu_types_pkg::pc_address_ex_t pc0_fet;
input [2:0] uop_num_fet;
output reg [2:0] uop_num_ext;
input [3:0] takb_fet;
input [3:0] pt_ext;
output reg [3:0] pt_dec;
output reg [3:0] p_override;
output reg [6:0] po_bno [0:3];
input [4:0] vl;
input ls_bmf_i;
input pack_regs_i;
input [2:0] scale_regs_i;
input cpu_types_pkg::aregno_t regcnt_i;
output Qupls4_pkg::pipeline_group_reg_t pg_ext;
/*
output cpu_types_pkg::mc_address_t mcip0_o;
output cpu_types_pkg::mc_address_t mcip1_o;
output cpu_types_pkg::mc_address_t mcip2_o;
output cpu_types_pkg::mc_address_t mcip3_o;
*/
output reg do_bsr;
output cpu_types_pkg::pc_address_ex_t bsr_tgt;
output reg do_ret;
output pc_address_ex_t ret_pc;
output reg do_call;
input get;
input mux_stallq;
output reg fet_stallq;
input pc_stream_t [THREADS-1:0] new_stream;
output reg alloc_stream;

genvar g;
integer nn,hh,n1,n2,n3,n4,n5,n6;
cpu_types_pkg::pc_address_ex_t [MWIDTH-1:0] pc_fet;
cpu_types_pkg::pc_address_ex_t [MWIDTH-1:0] pc_ext;
reg [5:0] ipl_ext;
Qupls4_pkg::irq_info_packet_t irq_in_ext;
cpu_types_pkg::seqnum_t irq_sn_ext;
reg irq_ext;
Qupls4_pkg::rob_entry_t [MWIDTH-1:0] ins_ext_o;
reg [1023:0] cline_fet;
wire [5:0] jj;
reg [5:0] kk;
wire clk = clk_i;
wire en = en_i;// & !mux_stallq;
wire ls_bmf = ls_bmf_i;
wire pack_regs = pack_regs_i;
cpu_types_pkg::aregno_t regcnt;
Qupls4_pkg::rob_entry_t [MWIDTH-1:0] ins_ext;
Qupls4_pkg::rob_entry_t [MWIDTH-1:0] ins_fet;
reg [319:0] ic_line_aligned;
reg [319:0] prev_ic_line_aligned;
reg ld;
reg prev_ssm_flag;

Qupls4_pkg::pipeline_reg_t nopi;

always_comb
begin
	foreach (pc_fet[n5])
		pc_fet[n5].pc = pc0_fet.pc + n5*6;
end

always_ff @(posedge clk)
	foreach(pc_ext[n6])
		if (en) pc_ext[n6] <= pc_fet[n6];

// Define a NOP instruction.
always_comb
begin
	nopi = {$bits(Qupls4_pkg::pipeline_reg_t){1'b0}};
	nopi.exc = Qupls4_pkg::FLT_NONE;
	nopi.uop = {41'd0,Qupls4_pkg::OP_NOP};
	nopi.uop.lead = 1'd1;
	nopi.v = 1'b1;
	/* NOP will be decoded later
	nopi.decbus.Rdz = 1'b1;
	nopi.decbus.nop = 1'b1;
	nopi.decbus.alu = 1'b1;
	*/
end

always_comb regcnt = regcnt_i;

always_comb 
	ic_line_aligned = {{64{1'd1,Qupls4_pkg::OP_NOP}},cline_fet} >> {pc0_fet.pc[5:1],4'd0};

pc_address_ex_t prev_pc0_fet;
always_ff @(posedge clk_i)
if (rst_i) begin
	prev_ic_line_aligned <= 160'd0;
	prev_pc0_fet <= {$bits(pc_address_ex_t){1'b0}};
end
else begin
	if (en) begin
		prev_ic_line_aligned <= ic_line_aligned;
		prev_pc0_fet <= pc0_fet;
	end
end

reg [1023:0] cline_ext_r;
always_ff @(posedge clk_i)
if (rst_i) begin
	cline_ext <= 1024'd0;
	cline_ext_r <= 1024'd0;
end
else begin
	if (en) begin
		cline_ext_r <= cline_ext;
		cline_ext <= cline_fet;
	end
end
always_comb
	new_cline_ext = cline_ext_r != cline_ext;

reg redundant_group;
always_comb
if (prev_pc0_fet==pc0_fet && prev_ic_line_aligned==ic_line_aligned)
	redundant_group = TRUE;
else
	redundant_group = FALSE;
//wire redundant_group = {prev_pc0_fet,prev_ic_line_aligned}=={pc0_fet,ic_line_aligned};

// Map instructions to micro-ops
// Set instruction valid bit.

Qupls4_pkg::pipeline_reg_t [MWIDTH-1:0] pr_ext;
always_comb
begin
	for (n1 = 0; n1 < MWIDTH; n1 = n1 + 1)
		pr_ext[n1] = nopi;
	if (!redundant_group) begin
		// Allow only one instruction through when single stepping.
		if (ssm_flag & ~prev_ssm_flag) begin
			pr_ext[0].cli = pc_fet[0].pc[5:1];
			pr_ext[0].uop = fnMapRawToUop(ic_line_aligned[ 47:  0]);
			for (n1 = 1; n1 < MWIDTH; n1 = n1 + 1) begin
				pr_ext[n1] = nopi;
				pr_ext[n1].ssm = TRUE;
			end
		end
		else if (ssm_flag) begin
			for (n1 = 0; n1 < MWIDTH; n1 = n1 + 1) begin
				pr_ext[n1] = nopi;
				pr_ext[n1].ssm = TRUE;
			end
		end
		else begin
			// Compute index of instruction on cache-line.
			// Note! the index is in terms of 16-bit parcels.
			for (n1 = 0; n1 < MWIDTH; n1 = n1 + 1) begin
				pr_ext[n1].cli = pc_fet[n1].pc[5:1];
				pr_ext[n1].uop = fnMapRawToUop(48'(ic_line_aligned >> (n1*48)));
			end
		end
	end
/*
	pr_ext[0].hwi_level = irq_fet;
	pr_ext[1].hwi_level = irq_fet;
	pr_ext[2].hwi_level = irq_fet;
	pr_ext[3].hwi_level = irq_fet;
	pr4_ext.hwi_level = irq_fet;
*/	
// If an NMI or IRQ is happening, invalidate instruction and mark as
// interrupted by external hardware.
	pr_ext[0].v = !(irq_fet) && !stomp_ext && !(ssm_flag && !(ssm_flag && !prev_ssm_flag));
	for (n4 = 1; n4 < MWIDTH; n4 = n4 + 1)
		pr_ext[n4].v = !(irq_fet) && !stomp_ext && !ssm_flag;
/*	
	pr_ext[0].hwi = nmi_i||irqf_fet;
	pr_ext[1].hwi = nmi_i||irqf_fet;
	pr_ext[2].hwi = nmi_i||irqf_fet;
	pr_ext[3].hwi = nmi_i||irqf_fet;
	pr4_ext.hwi = nmi_i||irqf_fet;
*/
	pr_ext[0].carry_mod = carry_mod_fet;
end

/* Under construction
reg [3:0] p_override1, p_override2;
reg [4:0] po_bno1 [0:3];
reg [4:0] po_bno2 [0:3];
*/
reg p_override_dummy;
reg [6:0] po_bno_dummy;

generate begin : gExtins
	for (g = 0; g < MWIDTH; g = g + 1)
		always_comb tExtractIns(g, stomp_ext, pc0_fet, pt_ext[g], takb_fet[g], pr_ext[g], ins_fet[g], p_override[g], po_bno[g]);
end
endgenerate

/* under construction
always_ff @(posedge clk_i)
if (rst_i)
else begin
	if (en_i) begin
		p_override1 <= p_override && ;
		p_override2 <= p_override1;
		po_bno1 <= po_bno;
		po_bno2 <= po_bno1;
	end
end
*/

// If there was a branch miss, instructions before the miss PC should not be
// executed.
reg [MWIDTH-1:0] nop;
/*
always_comb nop0 = (stomp_fet && pc0_fet.bno_t!=stomp_bno) || (branchmiss && misspc_fet.pc > pc0_fet.pc);
always_comb nop1 = (stomp_fet && pc1_fet.bno_t!=stomp_bno) || (branchmiss && misspc_fet.pc > pc1_fet.pc);
always_comb nop2 = (stomp_fet && pc2_fet.bno_t!=stomp_bno) || (branchmiss && misspc_fet.pc > pc2_fet.pc);
always_comb nop3 = (stomp_fet && pc3_fet.bno_t!=stomp_bno) || (branchmiss && misspc_fet.pc > pc3_fet.pc);
*/
generate begin : gNop
	for (g = 0; g < MWIDTH; g = g + 1)
		always_comb nop[g] = (branchmiss && misspc_fet.pc > pc_fet[g].pc);
end
endgenerate
/*
always_comb nop0 = FALSE;
always_comb nop1 = FALSE;
always_comb nop2 = FALSE;
always_comb nop3 = FALSE;
*/
wire [MWIDTH-1:0] bsr;
wire [MWIDTH-1:0] jsr;
wire [MWIDTH-1:0] bra;
wire [MWIDTH-1:0] jmp;
wire [MWIDTH-1:0] bcc;
wire [MWIDTH-1:0] rtd;
reg bsr02,bsr12,bsr22,bsr32;
reg jsrr0,jsrr1,jsrr2,jsrr3;
reg jsri0,jsri1,jsri2,jsri3;
reg jmpr0,jmpr1,jmpr2,jmpr3;
reg jmpi0,jmpi1,jmpi2,jmpi3;
reg do_bsr1;
cpu_types_pkg::pc_address_ex_t [MWIDTH-1:0] bsr_tgts,jsr_tgts,bcc_tgts,btgts;

generate begin : gExtDecode
	for (g = 0; g < MWIDTH; g = g + 1) begin
		Qupls4_ext_decode usd1
			(
				.pc(pc_ext[g]),
				.instr(ic_line_aligned[g*48+47:g*48]),
				.bsr(bsr[g]),
				.jsr(jsr[g]),
				.bra(bra[g]),
				.jmp(jmp[g]),
				.bcc(bcc[g]),
				.rtd(rtd[g]),
				.bsr_tgt(bsr_tgts[g]),
				.jsr_tgt(jsr_tgts[g]),
				.bcc_tgt(bcc_tgts[g])
			);
			
		always_comb
			case(1'b1)
			bsr[g]:	btgts[g] = bsr_tgts[g];
			jsr[g]: btgts[g] = jsr_tgts[g];
			bcc[g]: btgts[g] = bcc_tgts[g];
			default:	btgts[g] = RSTPC;
			endcase
	end
end
endgenerate


always_comb bsr02 = Qupls4_pkg::fnDecBsr2(ins_ext[0].op);
always_comb bsr12 = Qupls4_pkg::fnDecBsr2(ins_ext[1].op);
always_comb bsr22 = Qupls4_pkg::fnDecBsr2(ins_ext[2].op);
always_comb bsr32 = Qupls4_pkg::fnDecBsr2(ins_ext[3].op);
always_comb jmpr0 = Qupls4_pkg::fnDecJmpr(ins_ext[0].op);
always_comb jmpr1 = Qupls4_pkg::fnDecJmpr(ins_ext[1].op);
always_comb jmpr2 = Qupls4_pkg::fnDecJmpr(ins_ext[2].op);
always_comb jmpr3 = Qupls4_pkg::fnDecJmpr(ins_ext[3].op);
always_comb jsrr0 = Qupls4_pkg::fnDecJsrr(ins_ext[0].op);
always_comb jsrr1 = Qupls4_pkg::fnDecJsrr(ins_ext[1].op);
always_comb jsrr2 = Qupls4_pkg::fnDecJsrr(ins_ext[2].op);
always_comb jsrr3 = Qupls4_pkg::fnDecJsrr(ins_ext[3].op);
/*
always_comb jmpi0 = ins_ext[0].ins.opcode==OP_JSRI && ins_ext[0].ins.Rt==3'd0;
always_comb jmpi1 = ins_ext[1].ins.opcode==OP_JSRI && ins_ext[1].ins.Rt==3'd0;
always_comb jmpi2 = ins_ext[2].ins.opcode==OP_JSRI && ins_ext[2].ins.Rt==3'd0;
always_comb jmpi3 = ins_ext[3].ins.opcode==OP_JSRI && ins_ext[3].ins.Rt==3'd0;
always_comb jsri0 = ins_ext[0].ins.opcode==OP_JSRI && ins_ext[0].ins.Rt!=3'd0;
always_comb jsri1 = ins_ext[1].ins.opcode==OP_JSRI && ins_ext[1].ins.Rt!=3'd0;
always_comb jsri2 = ins_ext[2].ins.opcode==OP_JSRI && ins_ext[2].ins.Rt!=3'd0;
always_comb jsri3 = ins_ext[3].ins.opcode==OP_JSRI && ins_ext[3].ins.Rt!=3'd0;
*/

// Figure whether a subroutine call, or return is being performed. Note
// precedence. Only the first one to be performed is detected.

always_comb
begin
	do_bsr = FALSE;
	do_ret = FALSE;
	do_call = FALSE;
	if (~stomp_ext) begin
		if (bsr[0]|jsr[0]|bcc[0]) begin
			do_bsr = TRUE;
			if (bsr[0]|jsr[0])
				do_call = TRUE;
		end
		else if (rtd[0])
			do_ret = TRUE;

		else if (bsr[1]|jsr[1]|bcc[1]) begin
			do_bsr = TRUE;
			if (bsr[1]|jsr[1])
				do_call = TRUE;
		end
		else if (rtd[1])
			do_ret = TRUE;

		else if (bsr[2]|jsr[2]|bcc[2]) begin
			do_bsr = TRUE;
			if (bsr[2]|jsr[2])
				do_call = TRUE;
		end
		else if (rtd[2])
			do_ret = TRUE;

		else if (bsr[3]|jsr[3]|bcc[3]) begin
			do_bsr = TRUE;
			if (bsr[3]|jsr[3])
				do_call = TRUE;
		end
		else if (rtd[3])
			do_ret = TRUE;
	end
end

// Compute target PC for subroutine call or jump.
always_comb
begin
	alloc_stream = 1'b0;
	if (bsr[0]|jsr[0]|bcc[0]) begin
		bsr_tgt.pc = btgts[0].pc;
		if (pt_ext[0] || ~bcc[0])
			bsr_tgt.stream = pc0_fet.stream;
		else begin
			bsr_tgt.stream = new_stream[bsr_tgt.stream.thread].stream;
			alloc_stream = 1'b1;
		end
	end
	else if (bsr[1]|jsr[1]|bcc[1]) begin
		bsr_tgt = btgts[1];
		if (pt_ext[1] || ~bcc[1])
			bsr_tgt.stream = pc0_fet.stream;
		else begin
			bsr_tgt.stream = new_stream[bsr_tgt.stream.thread].stream;
			alloc_stream = 1'b1;
		end
	end
	else if (bsr[2]|jsr[2]|bcc[2]) begin
		bsr_tgt = btgts[2];
		if (pt_ext[2] || ~bcc[2])
			bsr_tgt.stream = pc0_fet.stream;
		else begin
			bsr_tgt.stream = new_stream[bsr_tgt.stream.thread].stream;
			alloc_stream = 1'b1;
		end
	end
	else if (bsr[3]|jsr[3]|bcc[3]) begin
		bsr_tgt = btgts[3];
		if (pt_ext[3] || ~bcc[3])
			bsr_tgt.stream = pc0_fet.stream;
		else begin
			bsr_tgt.stream = new_stream[bsr_tgt.stream.thread].stream;
			alloc_stream = 1'b1;
		end
	end
	else begin
		bsr_tgt.pc = RSTPC;
		bsr_tgt.stream = 5'd1;
	end
end

// Compute return PC for subroutine call.
always_comb
begin
	ret_pc.stream = pc0_fet.stream;
	ret_pc.pc = RSTPC;
	ret_pc.stream = 5'd1;
	for (n3 = MWIDTH-1; n3 >= 0; n3 = n3 - 1)
		if (bsr[n3]|jsr[n3])
			ret_pc.pc = pc_ext[n3].pc + 4'd6;
end

always_comb
	fet_stallq = mux_stallq;

generate begin : gInsExtMux
	for (g = 0; g < MWIDTH;	g = g + 1)
		Qupls4_ins_extract_mux umux0
		(
			.rst(rst_i),
			.clk(clk_i),
			.en(en),
			.nop(nop[g]),
			.ins0(ins_fet[0]),
			.insi(ins_fet[g]),
			.ins(ins_ext[g])
		);
end
endgenerate

generate begin : gInsMux
	for (g = 0; g < MWIDTH; g = g + 1)
		always_comb ins_ext_o[g] = ins_ext[g];
end
endgenerate

always_comb 
begin
	pg_ext.hdr = {$bits(Qupls4_pkg::pipeline_group_hdr_t){1'b0}};
	pg_ext.hdr.v = !stomp_ext;
	pg_ext.hdr.irq_sn = irq_sn_ext;
	pg_ext.hdr.irq = irq_in_ext;
	pg_ext.hdr.old_ipl = ipl_ext;
	pg_ext.hdr.hwi = irq_ext;
	pg_ext.hdr.ip = pc_ext[0].pc;
end
always_comb
begin
	foreach (pg_ext.pr[n2]) begin
		pg_ext.pr[n2] = {$bits(Qupls4_pkg::pipeline_reg_t){1'b0}};
		pg_ext.pr[n2] = ins_ext[n2];
		pg_ext.pr[n2].ip_stream = pc_ext[n2].stream.stream;
		pg_ext.pr[n2].ip_offs = n2 * 3;	// wyde offset
	end
end

always_ff @(posedge clk) if (en) irq_sn_ext <= irq_sn_fet;
always_ff @(posedge clk) if (en) irq_in_ext <= irq_in_fet;
always_ff @(posedge clk) if (en) irq_ext <= irq_fet;
always_ff @(posedge clk) if (en) ipl_ext <= ipl_fet;
always_ff @(posedge clk) if (en) nop_o <= stomp_ext;
always_ff @(posedge clk)
if (rst_i)
	prev_ssm_flag <= 1'b0;
else begin
	if (en)
		prev_ssm_flag <= ssm_flag;
end

always_ff @(posedge clk)
if (rst_i)
	uop_num_ext <= 3'b0;
else begin
	if (en)
		uop_num_ext <= uop_num_fet;
end

always_ff @(posedge clk)
if (rst_i)
	pt_dec <= 4'h0;
else begin
	if (en)
		pt_dec <= pt_ext;
end

always_ff @(posedge clk)
if (rst_i)
	flush_ext <= 1'b0;
else begin
	if (en)
		flush_ext <= flush_fet;
end

/*
always_comb mcip0_o <= mcip0;
always_comb mcip1_o <= |mcip0 ? mcip0 | 12'h001 : 12'h000;
always_comb mcip2_o <= |mcip1 ? mcip1 | 12'h002 : 12'h000;
always_comb mcip3_o <= |mcip2 ? mcip2 | 12'h003 : 12'h000;
*/
task tExtractIns;
input integer g;
input stomp_ext;
input pc_address_ex_t pc;
input pt_ext;
input takb;
input Qupls4_pkg::pipeline_reg_t ins_i;
output Qupls4_pkg::rob_entry_t ins_o;
output p_override;
output [6:0] bno;
begin
	p_override = 1'b0;
	ins_o.v = !stomp_ext;
	ins_o.op.v = !stomp_ext;
	ins_o.op = ins_i;
	ins_o.op.bt = takb;
	ins_o.ip_stream = pc.stream.stream;
	ins_o.ip_offs = g * 3;
	/*
  ins_o.aRs1 = {ins_i.uop.Rs1};
  ins_o.aRs2 = {ins_i.uop.Rs2};
  ins_o.aRs3 = {ins_i.uop.Rs3};
//  ins_o.aRs3 = {ins_i.ins.Rs3};
  ins_o.aRd = {ins_i.uop.Rd};
  */
//	ins_o.decbus.Rtz = ins_o.aRt==8'd0;
	// Under construction
	// If BTB did not match next predictor, invalidate instruction.
	/*
	if (pt_ext != takb) begin
		ins_o.v = 1'b0;
		ins_o.aRt = 8'd0;
		ins_o.ins.opcode = OP_NOP;
		p_override = 1'b1;
	end
	*/
//	bno = takb ? ins_o.pc.stream : ins_o.pc.bno_f;
	bno = pc.stream.stream;
end
endtask

endmodule
