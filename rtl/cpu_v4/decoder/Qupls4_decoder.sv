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

import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_decoder(rst, clk, en, ip, om, ipl, instr, instr_raw, dbo);
input rst;
input clk;
input en;
input cpu_types_pkg::pc_address_t ip;
input Qupls4_pkg::operating_mode_t om;
input [5:0] ipl;
input Qupls4_pkg::micro_op_t instr;
input [335:0] instr_raw;
output Qupls4_pkg::decode_bus_t dbo;

Qupls4_pkg::decode_bus_t db;
wire [11:0] const_pos;
wire [5:0] isz;
wire excRs1, excRs2, excRs3, excRd, excRd2, excRd3;
wire [3:0] pred_shadow_count;

assign db.v = 1'b1;

Qupls4_decode_const udcimm
(
	.ins(instr),
	.instr_raw(instr_raw),
	.ip(ip),
	.imma(db.imma),
	.immb(db.immb),
	.immc(db.immc),
	.immd(db.immd),
	.has_imma(db.has_imma),
	.has_immb(db.has_immb),
	.has_immc(db.has_immc),
	.has_immd(db.has_immd),
	.pos(const_pos),
	.isz(isz)
);

Qupls4_decode_Rs1 udcra
(
	.om(om),
	.instr(instr),
	.instr_raw(instr_raw),
	.has_imma(db.has_imma),
	.Rs1(db.Rs1),
	.Rs1z(db.Rs1z),
	.exc(excRs1)
);

Qupls4_decode_Rs2 udcrb
(
	.om(om),
	.instr(instr),
	.instr_raw(instr_raw),
	.has_immb(db.has_immb),
	.Rs2(db.Rs2),
	.Rs2z(db.Rs2z),
	.has_Rs2(db.has_Rs2),
	.exc(excRs2)
);

Qupls4_decode_Rs3 udcrc
(
	.om(om),
	.instr(instr),
	.instr_raw(instr_raw),
	.has_immc(db.has_immc),
	.Rs3(db.Rs3),
	.Rs3z(db.Rs3z),
	.exc(excRs3)
);

Qupls4_decode_Rd udcrt
(
	.om(om),
	.instr(instr),
	.instr_raw(instr_raw),
	.Rd(db.Rd),
	.Rdz(db.Rdz),
	.exc(excRd)
);
/*
Stark_decode_Rd2 udcrd2
(
	.om(om),
	.instr(instr),
	.Rd2(db.Rd2),
	.Rd2z(db.Rd2z),
	.exc(excRd2)
);

Stark_decode_Rd3 udcrd3
(
	.om(om),
	.instr(instr),
	.Rd3(db.Rd3),
	.Rd3z(db.Rd3z),
	.exc(excRd3)
);
*/
/*
Stark_decode_macro umacro1
(
	.instr(instr),
	.macro(db.macro)
);
*/

Qupls4_decode_has_imm uhi
(
	.instr(instr),
	.has_imm(db.has_imm)
);

Qupls4_decode_nop unop1
(
	.instr(instr),
	.nop(db.nop)
);

Qupls4_decode_fc ufc1
(
	.instr(instr),
	.fc(db.fc)
);

Qupls4_decode_cjb ucjb1
(
	.instr(instr),
	.cjb(db.cjb)
);

Qupls4_decode_conditional_branch udecbr
(
	.instr(instr),
	.branch(db.br)
);

Qupls4_decode_pred
(
	.instr(instr),
	.pred(db.pred),
	.pred_mask(db.pred_mask)
);

/*
Stark_decode_predicate_branch udecpbr
(
	.instr(instr),
	.branch(db.pbr),
	.mask(db.pred_mask),
	.atom_mask(db.pred_atom_mask),
	.count(pred_shadow_count)
);
*/
/*
Stark_decode_mcb udecmcb
(
	.instr(instr),
	.mcb(db.mcb)
);
*/
/*
Stark_decode_backbr ubkbr1
(
	.instr(instr),
	.backbr(db.backbr)
);
*/
/*
Stark_decode_branch_tgt_src udbts1
(
	.ins(instr),
	.bts(db.bts)
);
*/
/*
Stark_decode_alu udcalu
(
	.instr(instr),
	.alu(db.alu)
);

Stark_decode_alu0 udcalu0
(
	.instr(instr),
	.alu0(db.alu0)
);
*/
Qupls4_decode_sau usaudec1
(
	.instr(instr),
	.sau(db.sau)
);

Qupls4_decode_sau0 udcsau0
(
	.instr(instr),
	.sau0(db.sau0)
);

/*
Stark_decode_alu_pair udcalup0
(
	.instr(instr),
	.alu_pair(db.alu_pair)
);
*/
Qupls4_decode_bitwise udcbitwise
(
	.instr(instr),
	.bitwise(db.bitwise)
);

Qupls4_decode_mul umul1
(
	.instr(instr),
	.mul(db.mul)
);

Qupls4_decode_mulu umulu1
(
	.instr(instr),
	.mulu(db.mula)
);

Qupls4_decode_div udiv1
(
	.instr(instr),
	.div(db.div)
);

Qupls4_decode_divu udivu1
(
	.instr(instr),
	.divu(db.diva)
);

Qupls4_decode_load udecld1
(
	.instr(instr),
	.load(db.load),
	.vload(db.vload),
	.vload_ndx(db.vload_ndx)
);

Qupls4_decode_loadz udecldz1
(
	.instr(instr),
	.loadz(db.loadz)
);

Qupls4_decode_store udecst1
(
	.instr(instr),
	.store(db.store),
	.vstore(db.vstore),
	.vstore_ndx(db.vstore_ndx)
);

Qupls4_decode_loada udeclda1
(
	.instr(instr),
	.loada(db.loada)
);

Qupls4_decode_fence udfence1
(
	.instr(instr),
	.fence(db.fence),
	.atom(db.atom)
);

/*
Stark_decode_pfx udecpfx1
(
	.instr(instr),
	.pfx(db.pfx)
);
*/
Qupls4_decode_fma ufma
(
	.instr(instr),
	.fma(db.fma)
);

Stark_decode_fpu ufpu
(
	.instr(instr),
	.fpu(db.fpu)
);

Stark_decode_fpu0 ufpu0
(
	.instr(instr),
	.fpu0(db.fpu0)
);

Stark_decode_oddball uob0
(
	.instr(instr),
	.oddball(db.oddball)
);

Stark_decode_regs uregs0
(
	.instr(instr),
	.regs(db.regs)
);

Stark_decode_brk ubrk1
(
	.instr(instr),
	.brk(db.brk)
);

Stark_decode_csr ucsr1
(
	.instr(instr),
	.csr(db.csr)
);

Stark_decode_multicycle udmc1
(
	.instr(instr),
	.multicycle(db.multicycle)
);
/*
Stark_decode_irq udirq1
(
	.instr(instr),
	.irq(db.irq)
);
*/

Stark_decode_eret uderet1
(
	.instr(instr),
	.eret(db.eret)
);

Stark_decode_rex udrex1
(
	.instr(instr),
	.rex(db.rex)
);
/*
Stark_decode_prec udprec1
(
	.instr(instr),
	.prec(db.prc)
);
*/


always_ff @(posedge clk)
if (rst) begin
	dbo <= {$bits(dbo){1'd0}};
	dbo.cause <= Qupls4_pkg::FLT_NONE;
	dbo.nop <= 1'b1;
	dbo.Rdz <= 1'b1;
	dbo.alu <= 1'b1;
end
else begin
	if (en) begin
		dbo <= {$bits(dbo){1'd0}};	// in case a signal was missed / unused.
		dbo <= db;
		if (!instr.any.v) begin
			dbo.nop <= TRUE;
			dbo.alu <= TRUE;
			dbo.fpu <= FALSE;
			dbo.load <= FALSE;
			dbo.store <= FALSE;
			dbo.vload <= FALSE;
			dbo.vstore <= FALSE;
			dbo.vload_ndx <= FALSE;
			dbo.vstore_ndx <= FALSE;
			dbo.v2p = FALSE;
			dbo.vv2p = FALSE;
			dbo.vvn2p = FALSE;
			dbo.mem <= FALSE;
		end
		dbo.boi <= instr.any.opcode==Qupls4_pkg::OP_BCCU64 && instr.br.cnd==Qupls4_pkg::CND_BOI;
		dbo.bsr <= instr.any.opcode==Qupls4_pkg::OP_BSR;
		dbo.jsr <= instr.any.opcode==Qupls4_pkg::OP_JSR;
		dbo.stptr <= instr.any.opcode==Qupls4_pkg::OP_STPTR;
		dbo.iprel <= 1'b0;//db.Rs1==8'd31;
		dbo.cause <= Qupls4_pkg::FLT_NONE;
		dbo.mem <= 
			 db.load|db.vload|db.vload_ndx
			|db.store|db.vstore|db.vstore_ndx
			|db.v2p|db.vv2p|db.vvn2p;
		dbo.sync <= db.fence && instr[15:8]==8'hFF;
		dbo.cpytgt <= 1'b0;
		dbo.qfext <= 1'b0;//db.alu && ins.ins[28:27]==2'b10;
		if (excRs1|excRs2|excRs3|excRd)
			dbo.cause <= Qupls4_pkg::FLT_BADREG;
		// Is the predicate shadow count within range?
		if (pred_shadow_count >= Qupls4_pkg::PRED_SHADOW)
			dbo.cause <= Qupls4_pkg::FLT_UNIMP;
		else
			dbo.pred_shadow_size <= pred_shadow_count;
		// Check for unimplemented instruction, but not if it is being stomped on.
		// If it is stomped on, we do not care.
		if (!(db.nop|db.alu|db.fpu|db.fc|db.mem|db.macro
			|db.csr|db.loada|db.fence|db.carry|db.pred|db.atom|db.regs|db.fregs
			|db.rex|db.oddball|db.qfext
			)) begin
			dbo.cause <= Qupls4_pkg::FLT_UNIMP;
		end
	end
end

endmodule
