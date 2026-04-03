import const_pkg::*;
import Qupls4_pkg::*;

module Qupls4_ext_set_pr(rst, clk, en, irq, stomp, carry_mod,
	ic_line, redundant_group, ssm_flag, pc, pr);
parameter MWIDTH = Qupls4_pkg::MWIDTH;
input rst;
input clk;
input en;
input irq;
input stomp;
input [47:0] carry_mod;
input [MWIDTH*48-1:0] ic_line;
input redundant_group;
input ssm_flag;
input cpu_types_pkg::pc_address_ex_t [MWIDTH-1:0] pc;
output Qupls4_pkg::rob_entry_t [MWIDTH-1:0] pr;

integer n1,n4;

Qupls4_pkg::rob_entry_t nopi;
reg prev_ssm_flag;

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
begin
	for (n1 = 0; n1 < MWIDTH; n1 = n1 + 1) begin
		pr[n1] = nopi;
		pr[n1].v = pc[n1].stream.stream;
	end
	if (!redundant_group) begin
		// Allow only one instruction through when single stepping.
		if (ssm_flag & ~prev_ssm_flag) begin
			pr[0].op.cli = pc[0].pc[6:1];
			pr[0].op.uop = fnMapRawToUop(ic_line[ 47:  0]);
			for (n1 = 1; n1 < MWIDTH; n1 = n1 + 1) begin
				pr[n1] = nopi;
				pr[n1].op.ssm = TRUE;
				pr[n1].done = 2'b11;
			end
		end
		else if (ssm_flag) begin
			for (n1 = 0; n1 < MWIDTH; n1 = n1 + 1) begin
				pr[n1] = nopi;
				pr[n1].op.ssm = TRUE;
				pr[n1].done = 2'b11;
			end
		end
		else begin
			// Compute index of instruction on cache-line.
			// Note! the index is in terms of 16-bit parcels.
			for (n1 = 0; n1 < MWIDTH; n1 = n1 + 1) begin
				pr[n1].op.cli = pc[n1].pc[6:1];
				pr[n1].op.uop = fnMapRawToUop(48'(ic_line >> (n1*48)));
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
		pr[0].v = 5'd0;
		pr[0].stomped = TRUE;
		pr[0].done = 2'b11;
	end
	for (n4 = 1; n4 < MWIDTH; n4 = n4 + 1)
		if (!(!irq && !stomp && !ssm_flag)) begin
			pr[n4].v = 5'd0;
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

endmodule
