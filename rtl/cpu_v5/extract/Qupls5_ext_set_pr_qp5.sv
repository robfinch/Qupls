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
// ============================================================================

import const_pkg::*;
import Qupls5_pkg::*;

module Qupls5_ext_set_pr(rst, clk, en, irq, stomp, carry_mod,
	ic_line, ssm_flag, prev_xop_v, prev_xop, pc, pr);
parameter MWIDTH = Qupls5_pkg::MWIDTH;
input rst;
input clk;
input en;
input irq;
input stomp;
input [47:0] carry_mod;
input [MWIDTH*32-1:0] ic_line;
input ssm_flag;
input prev_xop_v;
input Qupls5_pkg::micro_op_t prev_xop;
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
	nopi.op.uop.opcode = fnNop();
	nopi.op.uop.last = TRUE;
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

reg [3:0] len40;
reg [31:0] insn;

always_comb
if (rst) begin
	len40 = 4'h0;
	foreach (pr[n1]) begin
		pr[n1] = {$bits(Qupls5_pkg::rob_entry_t){1'b0}};
		pr[n1].op = {$bits(Qupls5_pkg::pipeline_reg_t){1'b0}};
		pr[n1].op.exc = Qupls5_pkg::FLT_NONE;
		pr[n1].op.uop.opcode = fnNop();
		pr[n1].op.decbus.nop = TRUE;
		pr[n1].op.decbus.cause = Qupls5_pkg::FLT_NONE;
		pr[n1].op.uop.lead = 1'd1;
		pr[n1].op.uop.last = TRUE;
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
	len40 = 4'h0;
	/*
	len40[0] = fnIs40Bit(ic_line[6:0]);
	if (len40[0])
		len40[1] = fnIs40Bit(ic_line[46:40]);
	else
		len40[1] = fnIs40Bit(ic_line[53:48]);
	case(len40[1:0])
	2'b00:	len40[2] = fnIs40Bit(ic_line[102:96]);
	2'b01:	len40[2] = fnIs40Bit(ic_line[94:88]);
	2'b10:	len40[2] = fnIs40Bit(ic_line[94:88]);
	2'b11:	len40[2] = fnIs40Bit(ic_line[86:80]);
	endcase
	case(len40[2:0])
	3'b000:	len40[3] = fnIs40Bit(ic_line[150:144]);
	3'b001:	len40[3] = fnIs40Bit(ic_line[142:136]);
	3'b010:	len40[3] = fnIs40Bit(ic_line[142:136]);
	3'b011:	len40[3] = fnIs40Bit(ic_line[134:128]);
	3'b100:	len40[3] = fnIs40Bit(ic_line[142:136]);
	3'b101:	len40[3] = fnIs40Bit(ic_line[134:128]);
	3'b110:	len40[3] = fnIs40Bit(ic_line[134:128]);
	3'b101:	len40[3] = fnIs40Bit(ic_line[126:120]);
	endcase
	*/
	if (en) begin
		foreach (pr[n1]) begin
			pr[n1] = {$bits(Qupls5_pkg::rob_entry_t){1'b0}};
			pr[n1].op = {$bits(Qupls5_pkg::pipeline_reg_t){1'b0}};
			pr[n1].op.exc = Qupls5_pkg::FLT_NONE;
			pr[n1].op.uop.opcode = fnNop();
			pr[n1].op.decbus.nop = TRUE;
			pr[n1].op.decbus.cause = Qupls5_pkg::FLT_NONE;
			pr[n1].op.uop.lead = 1'd1;
			pr[n1].op.uop.last = TRUE;
			pr[n1].op.v = 1'b1;
			pr[n1].exc = Qupls5_pkg::FLT_NONE;
			pr[n1].excv = INV;
			pr[n1].done = 2'b11;
			pr[n1].stomped = TRUE;
			pr[n1].v = VAL;
			pr[n1].ip_stream = pc[n1].stream.stream;
		end
		// Allow only one instruction through when single stepping.
		// ToDo: fix single stepping to allow prefixes.
		if (ssm_flag & ~prev_ssm_flag) begin
			pr[0].op.cli = pc[0].cap.offset[6:0];
			pr[0].ip_offs = 8'd0;
			pr[0].op.uop = Qupls5_pkg::fnMapRawToUop(fnRibo(32'(ic_line >> ({4'd0,pr[0].ip_offs}<<3'd3))));
			for (n1 = 1; n1 < MWIDTH; n1 = n1 + 1) begin
				pr[n1] = {$bits(Qupls5_pkg::rob_entry_t){1'b0}};
				pr[n1].op = {$bits(Qupls5_pkg::pipeline_reg_t){1'b0}};
				pr[n1].op.exc = Qupls5_pkg::FLT_NONE;
				pr[n1].op.uop.opcode = fnNop();
				pr[n1].op.decbus.nop = TRUE;
				pr[n1].op.decbus.cause = Qupls5_pkg::FLT_NONE;
				pr[n1].op.uop.lead = 1'd1;
				pr[n1].op.uop.last = TRUE;
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
				pr[n1].v = VAL;
				pr[n1].op.exc = Qupls5_pkg::FLT_NONE;
				pr[n1].op.uop.opcode = fnNop();
				pr[n1].op.decbus.nop = TRUE;
				pr[n1].op.decbus.cause = Qupls5_pkg::FLT_NONE;
				pr[n1].op.uop.lead = 1'd1;
				pr[n1].op.uop.last = TRUE;
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
			// Note! the index is in terms of 32-bit parcels.
			foreach(pr[n1]) begin
				pr[n1].v = VAL;
				pr[n1].op.cli = fnUcGetAddress(pc[0].cap) + (n1 * 4);
				pr[n1].ip_offs = n1 * 4;
				// note ic_line is pre-aligned to the first instruction address. Need 
				// to use the offset from that address to shift some more.
				insn = ic_line >> {4'd0,pr[n1].ip_offs,3'b0};
				pr[n1].op.uop = Qupls5_pkg::fnMapRawToUop(Qupls5_pkg::fnRibo(insn));
				pr[n1].op.uop.v = VAL;
				pr[n1].done = 2'b00;
				pr[n1].stomped = FALSE;
			end
			if (prev_xop.prefix && prev_xop_v)
				tPrefix(prev_xop,0);
			// Fuse an XOP prefix into the next instruction.
			foreach(pr[n1]) begin
				if (n1 < MWIDTH-1 && pr[n1].op.uop.prefix) begin
					tPrefix(pr[n1].op.uop,n1+1);
					pr[n1].done = 2'b11;
				end
				// Prefix was last in bundle. Cannot fuse into next, but it will be
				// fetched for the next bundle. So, just mark done in this bundle.
				else if (pr[n1].op.uop.prefix) begin
					pr[n1].done = 2'b11;
				end
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
	if (en)
		lpr <= pr;
end

task tPrefix;
input Qupls5_pkg::micro_op_t prefix;
input integer ndx;
begin
	case(prefix.opcode)
`ifdef PowerISA
	Qupls5_pkg::OP_PPC_PREFIX:
		begin
			pr[ndx].op.uop.R = prefix.R;
			pr[ndx].op.uop.imm[33:16] = prefix.imm;
		end
`else
	Qupls5_pkg::OP_EXTOP:
	begin
		pr[ndx].op.uop.Rs3 = prefix.Rs3;
		pr[ndx].op.uop.Rs4 = prefix.Rs4;
		pr[ndx].op.uop.vlen = prefix.vlen;
		pr[ndx].op.uop.vn[3:2] = prefix.vn[3:2];
		pr[ndx].op.uop.sc = prefix.sc;
		pr[ndx].op.uop.op3 = prefix.op3;
		pr[ndx].op.uop.ms[3:2] = prefix.ms[3:2];
		pr[ndx].op.uop.src[2] = prefix.src[2];
		pr[ndx].op.uop.src[4] = prefix.src[4];
	end
	Qupls5_pkg::OP_NDX:
	begin
		pr[ndx].op.uop.Rs2 = prefix.Rs2;
		pr[ndx].op.uop.Rs3 = prefix.Rs3;
		pr[ndx].op.uop.vlen = prefix.vlen;
		pr[ndx].op.uop.vn[2:1] = prefix.vn[2:1];
		pr[ndx].op.uop.sc = prefix.sc;
		pr[ndx].op.uop.op3 = prefix.op3;
		pr[ndx].op.uop.ms[2:1] = prefix.ms[2:1];
		pr[ndx].op.uop.src[1] = prefix.src[1];
		pr[ndx].op.uop.src[2] = prefix.src[2];
	end
`endif	
	default:	;
	endcase
end
endtask

endmodule
