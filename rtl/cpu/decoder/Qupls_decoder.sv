// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2024  Robert Finch, Waterloo
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

import QuplsPkg::*;

module Qupls_decoder(rst, clk, en, om, instr, regx, dbo);
input rst;
input clk;
input en;
input operating_mode_t om;
input ex_instruction_t [5:0] instr;
input [3:0] regx;
output decode_bus_t dbo;

ex_instruction_t ins;
decode_bus_t db;

always_comb
	ins = instr[0];

assign db.v = 1'b1;

Qupls_decode_imm udcimm
(
	.ins(instr),
	.imma(db.imma),
	.immb(db.immb),
	.immc(db.immc),
	.has_imma(db.has_imma),
	.has_immb(db.has_immb),
	.has_immc(db.has_immc)
);

Qupls_decode_Ra udcra
(
	.om(om),
	.instr(ins),
	.regx(regx[1]),
	.has_imma(db.has_imma),
	.Ra(db.Ra)
);

Qupls_decode_Rb udcrb
(
	.om(om),
	.instr(ins),
	.regx(regx[2]),
	.has_immb(db.has_immb),
	.Rb(db.Rb)
);

Qupls_decode_Rc udcrc
(
	.om(om),
	.instr(instr),
	.regx(regx),
	.has_immc(db.has_immc),
	.Rc(db.Rc),
	.Rcc(db.Rcc)
);

Qupls_decode_Rt udcrt
(
	.om(om),
	.instr(ins),
	.regx(regx[0]),
	.Rt(db.Rt),
	.Rtz(db.Rtz)
);

Qupls_decode_r2 ur2
(
	.instr(ins.ins),
	.r2(db.r2)
);

Qupls_decode_has_imm uhi
(
	.instr(ins.ins),
	.has_imm(db.has_imm)
);

Qupls_decode_nop unop1
(
	.instr(ins.ins),
	.nop(db.nop)
);

Qupls_decode_fc ufc1
(
	.instr(ins.ins),
	.fc(db.fc)
);

Qupls_decode_cjb ucjb1
(
	.instr(ins.ins),
	.cjb(db.cjb)
);

Qupls_decode_bsr ubsr1
(
	.instr(ins.ins),
	.bsr(db.bsr)
);

Qupls_decode_branch udecbr
(
	.instr(ins.ins),
	.branch(db.br)
);

Qupls_decode_mcb udecmcb
(
	.instr(ins.ins),
	.mcb(db.mcb)
);

Qupls_decode_backbr ubkbr1
(
	.instr(ins.ins),
	.backbr(db.backbr)
);

Qupls_decode_branch_tgt_src udbts1
(
	.ins(ins.ins),
	.bts(db.bts)
);

Qupls_decode_alu udcalu
(
	.instr(ins.ins),
	.alu(db.alu)
);

Qupls_decode_alu0 udcalu0
(
	.instr(ins.ins),
	.alu0(db.alu0)
);

Qupls_decode_mul umul1
(
	.instr(ins.ins),
	.mul(db.mul)
);

Qupls_decode_mulu umulu1
(
	.instr(ins.ins),
	.mulu(db.mulu)
);

Qupls_decode_div udiv1
(
	.instr(ins.ins),
	.div(db.div)
);

Qupls_decode_divu udivu1
(
	.instr(ins.ins),
	.divu(db.divu)
);

Qupls_decode_load udecld1
(
	.instr(ins.ins),
	.load(db.load)
);

Qupls_decode_loadz udecldz1
(
	.instr(ins.ins),
	.loadz(db.loadz)
);

Qupls_decode_store udecst1
(
	.instr(ins.ins),
	.store(db.store)
);

Qupls_decode_lda udeclda1
(
	.instr(ins.ins),
	.lda(db.lda)
);

Qupls_decode_cls ucls1
(
	.instr(ins.ins),
	.cls(db.cls)
);

Qupls_decode_fence udfence1
(
	.instr(ins.ins),
	.fence(db.fence)
);

Qupls_decode_erc udecerc1
(
	.instr(ins.ins),
	.erc(db.erc)
);

Qupls_decode_pfx udecpfx1
(
	.instr(ins.ins),
	.pfx(db.pfx)
);

Qupls_decode_fpu ufpu
(
	.instr(ins.ins),
	.fpu(db.fpu)
);

Qupls_decode_fpu0 ufpu0
(
	.instr(ins.ins),
	.fpu0(db.fpu0)
);

Qupls_decode_oddball uob0
(
	.instr(ins.ins),
	.oddball(db.oddball)
);

Qupls_decode_regs uregs0
(
	.instr(ins.ins),
	.regs(db.regs)
);

Qupls_decode_brk ubrk1
(
	.instr(ins.ins),
	.brk(db.brk)
);

Qupls_decode_csr ucsr1
(
	.instr(ins.ins),
	.csr(db.csr)
);

Qupls_decode_multicycle udmc1
(
	.instr(ins.ins),
	.multicycle(db.multicycle)
);

Qupls_decode_irq udirq1
(
	.instr(ins.ins),
	.irq(db.irq)
);

Qupls_decode_rti udrti1
(
	.instr(ins.ins),
	.rti(db.rti)
);

Qupls_decode_rex udrex1
(
	.instr(ins.ins),
	.rex(db.rex)
);

/*
Qupls_decode_swap uswp1
(
	.instr(ins.ins),
	.swap(db.swap)
);
*/

always_ff @(posedge clk)
if (rst)
	dbo <= {$bits(dbo){1'd0}};
else begin
	if (en) begin
		dbo <= {$bits(dbo){1'd0}};	// in case a signal was missed / unused.
		dbo <= db;
		dbo.mem <= db.load|db.store;
		dbo.sync <= db.fence && ins[15:8]==8'hFF;
		dbo.pred <= ins.ins.any.opcode==OP_PRED;
		dbo.predz <= ins.ins[39];
	end
end

endmodule
