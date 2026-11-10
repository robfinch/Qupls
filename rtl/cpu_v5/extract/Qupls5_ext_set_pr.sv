import const_pkg::*;
import Qupls5_pkg::*;

module Qupls5_ext_set_pr(rst, clk, en, irq, stomp, carry_mod,
	ic_line, ssm_flag, pc, pr);
parameter MWIDTH = Qupls5_pkg::MWIDTH;
input rst;
input clk;
input en;
input irq;
input stomp;
input [47:0] carry_mod;
input [MWIDTH*48-1:0] ic_line;
input ssm_flag;
input Qupls5_pkg::pc_address_ex_t [MWIDTH-1:0] pc;
output Qupls5_pkg::rob_entry_t [MWIDTH-1:0] pr;

integer n1,n2,n4;
Qupls5_pkg::rob_entry_t [MWIDTH-1:0] lpr;

Qupls5_pkg::rob_entry_t nopi;
reg prev_ssm_flag;

// Define a NOP instruction.
always_comb
begin
	nopi = {$bits(Qupls5_pkg::rob_entry_t){1'b0}};
	nopi.op.exc = Qupls5_pkg::FLT_NONE;
	nopi.op.uop = {41'd0,Qupls5_pkg::OP_NOP};
	nopi.op.decbus.nop = TRUE;
	nopi.op.decbus.cause = Qupls5_pkg::FLT_NONE;
	nopi.op.uop.lead = 1'd1;
	nopi.op.v = 1'b1;
	nopi.v = 5'd1;
	nopi.exc = Qupls5_pkg::FLT_NONE;
	nopi.excv = INV;
	nopi.done = 2'b11;
	nopi.stomped = TRUE;
	/* NOP will be decoded later
	nopi.decbus.Rdz = 1'b1;
	nopi.decbus.nop = 1'b1;
	nopi.decbus.alu = 1'b1;
	*/
end

always_ff @(posedge clk)
if (rst)
	prev_ssm_flag <= 1'b0;
else begin
	if (en)
		prev_ssm_flag <= ssm_flag;
end

always_comb
if (rst) begin
	foreach (pr[n1]) begin
		pr[n1] = {$bits(Qupls5_pkg::rob_entry_t){1'b0}};
		pr[n1].op = {$bits(Qupls5_pkg::pipeline_reg_t){1'b0}};
		pr[n1].op.exc = Qupls5_pkg::FLT_NONE;
		pr[n1].op.uop.opcode = Qupls5_pkg::OP_NOP;
		pr[n1].op.decbus.nop = TRUE;
		pr[n1].op.decbus.cause = Qupls5_pkg::FLT_NONE;
		pr[n1].op.uop.lead = 1'd1;
		pr[n1].op.v = 1'b1;
		pr[n1].exc = Qupls5_pkg::FLT_NONE;
		pr[n1].excv = INV;
		pr[n1].done = 2'b11;
		pr[n1].stomped = TRUE;
		pr[n1].v = VAL;
		pr[n1].ip_stream = pc[n1].stream.stream;
	end
end
else begin
	n1 = 0;
	pr = lpr;
	if (en) begin
		// Allow only one instruction through when single stepping.
		if (ssm_flag & ~prev_ssm_flag) begin
			pr[0].op.cli = pc[0].cap.offset[6:1];
			pr[0].op.uop = Qupls5_pkg::fnMapRawToUop(ic_line[ 47:  0]);
			for (n1 = 1; n1 < MWIDTH; n1 = n1 + 1) begin
				pr[n1] = {$bits(Qupls5_pkg::rob_entry_t){1'b0}};
				pr[n1].op = {$bits(Qupls5_pkg::pipeline_reg_t){1'b0}};
				pr[n1].op.exc = Qupls5_pkg::FLT_NONE;
				pr[n1].op.uop = {41'd0,Qupls5_pkg::OP_NOP};
				pr[n1].op.decbus.nop = TRUE;
				pr[n1].op.decbus.cause = Qupls5_pkg::FLT_NONE;
				pr[n1].op.uop.lead = 1'd1;
				pr[n1].op.v = 1'b1;
				pr[n1].exc = Qupls5_pkg::FLT_NONE;
				pr[n1].excv = INV;
				pr[n1].done = 2'b11;
				pr[n1].stomped = TRUE;
//				pr[n1] = nopi;
				pr[n1].op.ssm = TRUE;
				pr[n1].done = 2'b11;
			end
		end
		else if (ssm_flag) begin
			foreach(pr[n1]) begin
				pr[n1] = {$bits(Qupls5_pkg::rob_entry_t){1'b0}};
				pr[n1].op = {$bits(Qupls5_pkg::pipeline_reg_t){1'b0}};
				pr[n1].op.exc = Qupls5_pkg::FLT_NONE;
				pr[n1].op.uop = {41'd0,Qupls5_pkg::OP_NOP};
				pr[n1].op.decbus.nop = TRUE;
				pr[n1].op.decbus.cause = Qupls5_pkg::FLT_NONE;
				pr[n1].op.uop.lead = 1'd1;
				pr[n1].op.v = 1'b1;
				pr[n1].exc = Qupls5_pkg::FLT_NONE;
				pr[n1].excv = INV;
				pr[n1].done = 2'b11;
				pr[n1].stomped = TRUE;
//				pr[n1] = nopi;
				pr[n1].op.ssm = TRUE;
				pr[n1].done = 2'b11;
			end
		end
		else begin
			// Compute index of instruction on cache-line.
			// Note! the index is in terms of 16-bit parcels.
			foreach(pr[n1]) begin
				pr[n1].op.cli = pc[n1].cap.offset[6:1];
				pr[n1].op.uop = Qupls5_pkg::fnMapRawToUop(48'(ic_line >> (n1*48)));
				pr[n1].done <= 2'b00;
				pr[n1].stomped <= FALSE;
			end
		end
	end
/*
	pr[0].hwi_level = irq_fet;
	pr[1].hwi_level = irq_fet;
	pr[2].hwi_level = irq_fet;
	pr[3].hwi_level = irq_fet;
	pr4_ext.hwi_level = irq_fet;
*/	
// If an NMI or IRQ is happening, invalidate instruction and mark as
// interrupted by external hardware.
	if (!(!(irq) && !stomp && !(ssm_flag && !(ssm_flag && !prev_ssm_flag)))) begin
		pr[0].v = INV;
		pr[0].stomped = TRUE;
		pr[0].done = 2'b11;
	end
	for (n4 = 1; n4 < MWIDTH; n4 = n4 + 1)
		if (!(!irq && !stomp && !ssm_flag)) begin
			pr[n4].v = INV;
			pr[n4].stomped = TRUE;
			pr[n4].done = 2'b11;
		end
/*	
	pr[0].hwi = nmi_i||irqf_fet;
	pr[1].hwi = nmi_i||irqf_fet;
	pr[2].hwi = nmi_i||irqf_fet;
	pr[3].hwi = nmi_i||irqf_fet;
	pr4_ext.hwi = nmi_i||irqf_fet;
*/
	pr[0].op.carry_mod = carry_mod;
end

always_ff @(posedge clk)
if (rst) begin
	for (n2 = 0; n2 < MWIDTH; n2 = n2 + 1) begin
		lpr[n2] <= {$bits(Qupls5_pkg::rob_entry_t){1'b0}};
		lpr[n2].op <= {$bits(Qupls5_pkg::pipeline_reg_t){1'b0}};
	end
end
else begin
	lpr <= pr;
end

endmodule
