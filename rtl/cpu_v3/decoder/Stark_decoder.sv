// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2025  Robert Finch, Waterloo
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

import Stark_pkg::*;

module Stark_decoder(rst, clk, en, cline, om, ipl, instr, dbo, consts_pos, mark_nops);
input rst;
input clk;
input en;
input [511:0] cline;
input Stark_pkg::operating_mode_t om;
input [5:0] ipl;
input Stark_pkg::micro_op_t instr;
output Stark_pkg::decode_bus_t dbo;
output reg [3:0] consts_pos [0:3];
output reg [3:0] mark_nops;

Stark_pkg::ex_instruction_t ins;
Stark_pkg::decode_bus_t db;
wire [7:0] const_pos;
wire [3:0] isz;
wire excRs1, excRs2, excRs3, excRd, excRd2, excRd3;
wire [3:0] pred_shadow_count;

// There could be four 32-bit constant positions used up on the cache line.
// The decode stage needs to be able to mark the constant positions as NOPs.
always_comb
begin
	mark_nops[0] = isz[1:0]!=2'b00;
	mark_nops[1] = isz[1:0]==2'b10;
	mark_nops[2] = isz[1:0]!=2'b00;
	mark_nops[3] = isz[1:0]==2'b10;
end

always_comb
begin
	consts_pos[0] = const_pos[3:0];
	consts_pos[1] = isz[1:0]==2'b10 ? const_pos[3:0] + 4'd1 : const_pos[3:0];
	consts_pos[2] = const_pos[7:4];
	consts_pos[3] = isz[3:2]==2'b10 ? const_pos[7:4] + 4'd1 : const_pos[7:4];
end

always_comb
	ins = instr.ins;

assign db.v = 1'b1;

Stark_decode_const udcimm
(
	.ins(ins.ins),
	.cline(cline),
	.imma(db.imma),
	.immb(db.immb),
	.immc(db.immc),
	.has_imma(db.has_imma),
	.has_immb(db.has_immb),
	.has_immc(db.has_immc),
	.pfxa(db.pfxa),
	.pfxb(db.pfxb),
	.pfxc(db.pfxc),
	.pos(const_pos),
	.isz(isz)
);

Stark_decode_Rs1 udcra
(
	.om(om),
	.instr(instr),
	.has_imma(db.has_imma),
	.Rs1(db.Rs1),
	.Rs1z(db.Rs1z),
	.exc(ecxRs1)
);

Stark_decode_Rs2 udcrb
(
	.om(om),
	.instr(instr),
	.has_immb(db.has_immb),
	.Rs2(db.Rs2),
	.Rs2z(db.Rs2z),
	.has_Rs2(db.has_Rs2),
	.exc(ecxRs2)
);

Stark_decode_Rs3 udcrc
(
	.om(om),
	.instr(instr),
	.has_immc(db.has_immc),
	.Rs3(db.Rs3),
	.Rs3z(db.Rs3z),
	.exc(ecxRs3)
);

Stark_decode_Rd udcrt
(
	.om(om),
	.instr(instr),
	.Rd(db.Rd),
	.Rdz(db.Rdz),
	.exc(ecxRd)
);
/*
Stark_decode_Rd2 udcrd2
(
	.om(om),
	.instr(ins.ins),
	.Rd2(db.Rd2),
	.Rd2z(db.Rd2z),
	.exc(excRd2)
);

Stark_decode_Rd3 udcrd3
(
	.om(om),
	.instr(ins.ins),
	.Rd3(db.Rd3),
	.Rd3z(db.Rd3z),
	.exc(excRd3)
);
*/
Stark_decode_macro umacro1
(
	.instr(ins.ins),
	.macro(db.macro)
);

Stark_decode_has_imm uhi
(
	.instr(ins.ins),
	.has_imm(db.has_imm)
);

Stark_decode_nop unop1
(
	.instr(ins.ins),
	.nop(db.nop)
);

Stark_decode_fc ufc1
(
	.instr(ins.ins),
	.fc(db.fc)
);

Stark_decode_cjb ucjb1
(
	.instr(ins.ins),
	.cjb(db.cjb)
);

Stark_decode_bl ubsr1
(
	.instr(ins.ins),
	.bl(db.bl)
);

Stark_decode_conditional_branch udecbr
(
	.instr(ins.ins),
	.branch(db.br)
);

Stark_decode_predicate_branch udecpbr
(
	.instr(ins.ins),
	.branch(db.pbr),
	.mask(db.pred_mask),
	.atom_mask(db.pred_atom_mask),
	.count(pred_shadow_count)
);

Stark_decode_brclass ubrc1
(
	.instr(ins.ins),
	.brclass(db.brclass)
);

/*
Stark_decode_mcb udecmcb
(
	.instr(ins.ins),
	.mcb(db.mcb)
);
*/
/*
Stark_decode_backbr ubkbr1
(
	.instr(ins.ins),
	.backbr(db.backbr)
);
*/
/*
Stark_decode_branch_tgt_src udbts1
(
	.ins(ins.ins),
	.bts(db.bts)
);
*/
/*
Stark_decode_alu udcalu
(
	.instr(ins.ins),
	.alu(db.alu)
);

Stark_decode_alu0 udcalu0
(
	.instr(ins.ins),
	.alu0(db.alu0)
);
*/
Stark_decode_sau usaudec1
(
	.instr(ins),
	.sau(db.sau)
);

Stark_decode_sau0 udcsau0
(
	.instr(ins),
	.sau0(db.sau0)
);

/*
Stark_decode_alu_pair udcalup0
(
	.instr(ins.ins),
	.alu_pair(db.alu_pair)
);
*/
Stark_decode_bitwise udcbitwise
(
	.instr(ins.ins),
	.bitwise(db.bitwise)
);

Stark_decode_mul umul1
(
	.instr(ins.ins),
	.mul(db.mul)
);

Stark_decode_mula umulu1
(
	.instr(ins.ins),
	.mul(db.mula)
);

Stark_decode_div udiv1
(
	.instr(ins.ins),
	.div(db.div)
);

Stark_decode_diva udivu1
(
	.instr(ins.ins),
	.div(db.diva)
);

Stark_decode_load udecld1
(
	.instr(ins.ins),
	.load(db.load)
);

Stark_decode_loadz udecldz1
(
	.instr(ins.ins),
	.loadz(db.loadz)
);

Stark_decode_store udecst1
(
	.instr(ins.ins),
	.store(db.store)
);

Stark_decode_loada udeclda1
(
	.instr(ins.ins),
	.loada(db.loada)
);

Stark_decode_fence udfence1
(
	.instr(ins.ins),
	.fence(db.fence)
);

Stark_decode_pfx udecpfx1
(
	.instr(ins.ins),
	.pfx(db.pfx)
);

Stark_decode_fpu ufpu
(
	.instr(ins.ins),
	.fpu(db.fpu)
);

Stark_decode_fpu0 ufpu0
(
	.instr(ins.ins),
	.fpu0(db.fpu0)
);

Stark_decode_oddball uob0
(
	.instr(ins.ins),
	.oddball(db.oddball)
);

Stark_decode_regs uregs0
(
	.instr(ins.ins),
	.regs(db.regs)
);

Stark_decode_brk ubrk1
(
	.instr(ins.ins),
	.brk(db.brk)
);

Stark_decode_csr ucsr1
(
	.instr(ins.ins),
	.csr(db.csr)
);

Stark_decode_multicycle udmc1
(
	.instr(ins.ins),
	.multicycle(db.multicycle)
);
/*
Stark_decode_irq udirq1
(
	.instr(ins.ins),
	.irq(db.irq)
);
*/

Stark_decode_eret uderet1
(
	.instr(ins.ins),
	.eret(db.eret)
);

Stark_decode_rex udrex1
(
	.instr(ins.ins),
	.rex(db.rex)
);
/*
Stark_decode_prec udprec1
(
	.instr(ins.ins),
	.prec(db.prc)
);
*/


always_ff @(posedge clk)
if (rst) begin
	dbo <= {$bits(dbo){1'd0}};
	dbo.cause <= Stark_pkg::FLT_NONE;
	dbo.nop <= 1'b1;
	dbo.Rdz <= 1'b1;
	dbo.alu <= 1'b1;
end
else begin
	if (en) begin
		dbo <= {$bits(dbo){1'd0}};	// in case a signal was missed / unused.
		dbo <= db;
		if (!instr.v) begin
			dbo.nop <= TRUE;
			dbo.alu <= TRUE;
			dbo.fpu <= FALSE;
			dbo.load <= FALSE;
			dbo.store <= FALSE;
			dbo.mem <= FALSE;
		end
		dbo.cause <= Stark_pkg::FLT_NONE;
		dbo.mem <= db.load|db.store|db.v2p;
		dbo.sync <= db.fence && ins[15:8]==8'hFF;
		dbo.cpytgt <= 1'b0;
		dbo.qfext <= db.alu && ins.ins[28:27]==2'b10;
		if (excRs1|excRs2|excRs3|excRd)
			dbo.cause <= Stark_pkg::FLT_BADREG;
		// Is the predicate shadow count within range?
		if (pred_shadow_count >= PRED_SHADOW)
			dbo.cause <= Stark_pkg::FLT_UNIMP;
		else
			dbo.pred_shadow_size <= pred_shadow_count;
		// Check for unimplemented instruction, but not if it is being stomped on.
		// If it is stomped on, we do not care.
		if (!(db.nop|db.alu|db.fpu|db.fc|db.mem|db.macro
			|db.csr|db.loada|db.fence|db.carry|db.atom|db.regs|db.fregs
			|db.rex|db.oddball|db.pred|db.qfext
			)) begin
			dbo.cause <= Stark_pkg::FLT_UNIMP;
		end
	end
end

endmodule
