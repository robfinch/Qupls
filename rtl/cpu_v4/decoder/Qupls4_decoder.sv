// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2026  Robert Finch, Waterloo
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

module Qupls4_decoder(rst, clk, regFPCSR, en, ip, om, ipl, instr, instr_raw, dbo);
input rst;
input clk;
input aregno_t regFPCSR;
input en;
input cpu_types_pkg::pc_address_t ip;
input Qupls4_pkg::operating_mode_t om;
input [5:0] ipl;
input Qupls4_pkg::micro_op_t instr;
input [431:0] instr_raw;
output Qupls4_pkg::decode_bus_t dbo;

Qupls4_pkg::decode_bus_t db;
wire excRs1, excRs2, excRs3, excRd, excRd2, excRd3;
wire [3:0] pred_shadow_count;


Qupls4_decode_expipe uexpipe1
(
	.instr(instr),
	.expipe(dbo.expipe)
);

Qupls4_decode_const udcimm
(
	.ins(instr),
	.instr_raw(instr_raw),
	.ip(ip),
	.imma(dbo.imma),
	.immb(dbo.immb),
	.immc(dbo.immc),
	.immd(dbo.immd),
	.has_imma(dbo.has_imma),
	.has_immb(dbo.has_immb),
	.has_immc(dbo.has_immc),
	.has_immd(dbo.has_immd)
);

Qupls4_decode_Rs1 udcra
(
	.om(om),
	.instr(instr),
	.instr_raw(instr_raw),
	.has_imma(dbo.has_imma),
	.Rs1(dbo.Rs1),
	.Rs1z(dbo.Rs1z),
	.Rs1ip(dbo.Rs1ip)
);

Qupls4_decode_Rs2 udcrb
(
	.om(om),
	.instr(instr),
	.instr_raw(instr_raw),
	.has_immb(dbo.has_immb),
	.Rs2(dbo.Rs2),
	.Rs2z(dbo.Rs2z),
	.has_Rs2(dbo.has_Rs2)
);

Qupls4_decode_Rs3 udcrc
(
	.om(om),
	.instr(instr),
	.instr_raw(instr_raw),
	.has_immc(dbo.has_immc),
	.Rs3(dbo.Rs3),
	.Rs3z(dbo.Rs3z)
);

Qupls4_decode_Rs4 udcr4
(
	.om(om),
	.instr(instr),
	.instr_raw(instr_raw),
	.has_immd(dbo.has_immd),
	.Rs4(dbo.Rs4),
	.Rs4z(dbo.Rs4z)
);

Qupls4_decode_Rm udcrt
(
	.instr(instr),
	.Rm(dbo.Rm),
	.Rmz(dbo.Rmz)
);

Qupls4_decode_Rd udcrm
(
	.om(om),
	.instr(instr),
	.instr_raw(instr_raw),
	.Rd(dbo.Rd),
	.Rdv(dbo.Rdv),
	.Rdz(dbo.Rdz),
	.we(dbo.we)
);

Qupls4_decode_Rd2 udcrd2
(
	.om(om),
	.regFPCSR(regFPCSR),
	.instr(instr),
	.instr_raw(instr_raw),
	.Rd2(dbo.Rd2),
	.Rd2v(dbo.Rd2v),
	.Rd2z(dbo.Rd2z)
);

Qupls4_decode_has_imm uhi
(
	.instr(instr),
	.has_imm(dbo.has_imm)
);

Qupls4_decode_nop unop1
(
	.instr(instr),
	.nop(dbo.nop)
);

Qupls4_decode_move umv1
(
	.instr(instr),
	.move(dbo.move)
);

Qupls4_decode_fc ufc1
(
	.instr(instr),
	.fc(dbo.fc)
);

Qupls4_decode_cjb ucjb1
(
	.instr(instr),
	.cjb(dbo.cjb)
);

Qupls4_decode_conditional_branch udecbr
(
	.instr(instr),
	.branch(dbo.br),
	.ibranch(dbo.ibr),
	.dbranch(dbo.dbr)
);

Qupls4_decode_pred upred1
(
	.instr(instr),
	.pred(dbo.pred),
	.pred_mask(dbo.pred_mask)
);

/*
Stark_decode_predicate_branch udecpbr
(
	.instr(instr),
	.branch(dbo.pbr),
	.mask(dbo.pred_mask),
	.atom_mask(dbo.pred_atom_mask),
	.count(pred_shadow_count)
);
*/
/*
Stark_decode_mcb udecmcb
(
	.instr(instr),
	.mcb(dbo.mcb)
);
*/
/*
Stark_decode_backbr ubkbr1
(
	.instr(instr),
	.backbr(dbo.backbr)
);
*/
/*
Stark_decode_branch_tgt_src udbts1
(
	.ins(instr),
	.bts(dbo.bts)
);
*/

Qupls4_decode_sau usaudec1
(
	.instr(instr),
	.sau(dbo.sau)
);

Qupls4_decode_sau0 udcsau0
(
	.instr(instr),
	.sau0(dbo.sau0)
);

/*
Stark_decode_alu_pair udcalup0
(
	.instr(instr),
	.alu_pair(dbo.alu_pair)
);
*/
Qupls4_decode_bitwise udcbitwise
(
	.instr(instr),
	.bitwise(dbo.bitwise)
);

Qupls4_decode_mul umul1
(
	.instr(instr),
	.mul(dbo.mul)
);

Qupls4_decode_mulu umulu1
(
	.instr(instr),
	.mulu(dbo.mula)
);

Qupls4_decode_div udiv1
(
	.instr(instr),
	.div(dbo.div)
);

Qupls4_decode_divu udivu1
(
	.instr(instr),
	.divu(dbo.diva)
);

Qupls4_decode_load udecld1
(
	.instr(instr),
	.load(dbo.load),
	.vload(dbo.vload),
	.vload_ndx(dbo.vload_ndx)
);

Qupls4_decode_loadz udecldz1
(
	.instr(instr),
	.loadz(dbo.loadz)
);

Qupls4_decode_store udecst1
(
	.instr(instr),
	.store(dbo.store),
	.vstore(dbo.vstore),
	.vstore_ndx(dbo.vstore_ndx)
);

Qupls4_decode_loada udeclda1
(
	.instr(instr),
	.loada(dbo.loada)
);

Qupls4_decode_mem umem1
(
	.instr(instr),
	.mem(dbo.mem)
);

Qupls4_decode_fence udfence1
(
	.instr(instr),
	.fence(dbo.fence),
	.atom(dbo.atom)
);

Qupls4_decode_fma ufma
(
	.instr(instr),
	.fma(dbo.fma)
);

Qupls4_decode_fpu ufpu
(
	.instr(instr),
	.fpu(dbo.fpu)
);

Qupls4_decode_fpu0 ufpu0
(
	.instr(instr),
	.fpu0(dbo.fpu0)
);

Qupls4_decode_rmd urmd0
(
	.instr(instr),
	.rmd(dbo.rm)
);

Qupls4_decode_prc uprc0
(
	.instr(instr),
	.prc(dbo.prc)
);

Qupls4_decode_oddball uob0
(
	.instr(instr),
	.oddball(dbo.oddball)
);
/*
Stark_decode_regs uregs0
(
	.instr(instr),
	.regs(dbo.regs)
);

Stark_decode_multicycle udmc1
(
	.instr(instr),
	.multicycle(dbo.multicycle)
);
*/
/*
Stark_decode_irq udirq1
(
	.instr(instr),
	.irq(dbo.irq)
);
*/
Qupls4_decode_trig udtrig1
(
	.instr(instr),
	.trig(dbo.trig)
);

Qupls4_decode_eret uderet1
(
	.instr(instr),
	.eret(dbo.eret)
);

Qupls4_decode_class udecfclss
(
	.instr(instr),
	.fclass(dbo.fclass)
);
/*
Stark_decode_rex udrex1
(
	.instr(instr),
	.rex(dbo.rex)
);
*/
Qupls4_decode_macro udecmacro
(
	.instr(instr),
	.macro(dbo.macro)
);

// Some of the simpler decodes are done directly in this always block. More
// complex decodes are done by modules above.
always_comb//ff @(posedge clk)
begin
	dbo.v = VAL;
	dbo.rext = instr.opcode==Qupls4_pkg::OP_REXT;
	dbo.boi = instr.opcode==Qupls4_pkg::OP_BCCU && instr.cnd==Qupls4_pkg::CND_BOI;
	dbo.bsr = instr.opcode==Qupls4_pkg::OP_BSR;
	dbo.jsr = instr.opcode==Qupls4_pkg::OP_JSR;
	dbo.sys = instr.opcode==Qupls4_pkg::OP_SYS;
	dbo.brk = instr.opcode==Qupls4_pkg::OP_BRK;
	dbo.ret = instr.opcode==Qupls4_pkg::OP_RTD;
	dbo.stptr = instr.opcode==Qupls4_pkg::OP_STPTR;
	dbo.csr = instr.opcode==Qupls4_pkg::OP_CSR;
	dbo.iprel = FALSE;
	dbo.cause = Qupls4_pkg::FLT_NONE;
//	dbo.mem0 = db.v2p|db.vv2p|db.vvn2p;
	dbo.load_canary = SUPPORT_CANARY && instr.opcode==Qupls4_pkg::OP_LOAD && instr.byteno[2];
	dbo.cload = instr.opcode==Qupls4_pkg::OP_CLOAD;
	dbo.cload_tags = SUPPORT_CAPABILITIES && instr.opcode==Qupls4_pkg::OP_CLOAD && instr.func==Qupls4_pkg::CAP_LOADTAGS; 
	dbo.cstore = instr.opcode==Qupls4_pkg::OP_CSTORE;
	dbo.cap = instr.opcode==Qupls4_pkg::OP_CAP; 
	dbo.v2p = instr.opcode==Qupls4_pkg::OP_V2P;
	dbo.vv2p = instr.opcode==Qupls4_pkg::OP_VV2P;
	dbo.amo = instr.opcode==Qupls4_pkg::OP_AMO;
	dbo.sync = instr.opcode==Qupls4_pkg::OP_FENCE && instr.func==7'd0 && instr[15:8]==8'hFF;
	dbo.cpytgt = 1'b0;
	dbo.qfext = 1'b0;//db.alu && ins.ins[28:27]==2'b10;
	if (excRs1|excRs2|excRs3|excRd)
		dbo.cause = Qupls4_pkg::FLT_BADREG;
	dbo.rc = instr.func[6];
		dbo.cause = Qupls4_pkg::FLT_NONE;
	// Is the predicate shadow count within range?
	if (pred_shadow_count >= Qupls4_pkg::PRED_SHADOW)
		dbo.cause = Qupls4_pkg::FLT_UNIMP;
	else
		dbo.pred_shadow_size = pred_shadow_count;
	if (!instr.v) begin
		dbo = {$bits(dbo){1'd0}};	// in case a signal was missed / unused.
		dbo.nop = TRUE;
		dbo.sau = TRUE;
		dbo.cause = Qupls4_pkg::FLT_NONE;
	end
	/*
	// Check for unimplemented instruction, but not if it is being stomped on.
	// If it is stomped on, we do not care.
	if (!(db.nop|db.sau|db.fpu|db.fc|db.macro
		|db.csr|db.loada|db.fence|db.carry|db.pred|db.atom|db.regs|db.fregs
		|db.rex|db.oddball|db.qfext
		|db.boi|db.bsr|db.jsr|db.sys|db.stptr
		|db.csr|db.rext
		|db.move
		// db.mem
		|db.load|db.vload|db.vload_ndx
		|db.store|db.vstore|db.vstore_ndx
		|db.v2p|db.vv2p|db.vvn2p			
		)) begin
		dbo.cause = Qupls4_pkg::FLT_UNIMP;
	end
	*/
end

endmodule
