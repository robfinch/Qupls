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
// 1550 LUTs / 800 FFs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Stark_pkg::*;

module Stark_agen_station(rst, clk, idle_i, issue, rndx, rndxv, rob,
	rfo, rfo_tag, rfo_argC_ctag, prn, prnv, all_args_valid,
	argC_v, beb_issue, bndx, beb,
	id, om, we, argA, argB, argC, argI, argA_tag, argB_tag, argC_tag,
	aRa, aRb, aRc, aRt, pRa, pRb, pRc, pRt,
	instr, pc, op, virt2phys, load, store, amo,
	cp, excv, ldip, idle_o, store_argC_v, store_argI,
	store_argC_aReg,  store_argC_pReg, store_argC_cndx
);
input rst;
input clk;
input idle_i;
input issue;
input rob_ndx_t rndx;
input rndxv;
input Stark_pkg::rob_entry_t rob;
input value_t [15:0] rfo;
input [15:0] rfo_tag;
input pregno_t [15:0] prn;
input [15:0] prnv;
input rfo_argC_ctag;
input beb_issue;
input beb_ndx_t bndx;
input beb_entry_t beb;

output rob_ndx_t id;
output Stark_pkg::operating_mode_t om;
output Stark_pkg::ex_instruction_t instr;
output reg we;
output address_t argA;
output address_t argB;
output value_t argC;
output reg argA_tag;
output reg argB_tag;
output reg argC_tag;
output reg argC_v;
output reg all_args_valid;
output address_t argI;
output aregno_t aRa;
output aregno_t aRb;
output aregno_t aRc;
output aregno_t aRt;
output pregno_t pRa;
output pregno_t pRb;
output pregno_t pRc;
output pregno_t pRt;
output pc_address_ex_t pc;
output pipeline_reg_t op;
output reg virt2phys;
output reg load;
output reg store;
output reg amo;
output checkpt_ndx_t cp;
output reg excv;
output reg ldip;
output reg idle_o;
output reg store_argC_v;
output address_t store_argI;
output aregno_t store_argC_aReg;
output pregno_t store_argC_pReg;
output checkpt_ndx_t store_argC_cndx;

reg [2:0] valid;
wire [2:0] valid_o;

always_comb
	all_args_valid = &valid;

Stark_validate_Rn uvRs1
(
	.prn(prn),
	.prnv(prnv),
	.rfo(rfo),
	.rfo_tag(rfo_tag),
	.pRn(rob.op.pRs1),
	.val(argA),
	.val_tag(argA_tag),
	.valid_i(valid[0]),
	.valid_o(valid_o[0])
);

Stark_validate_Rn uvRs2
(
	.prn(prn),
	.prnv(prnv),
	.rfo(rfo),
	.rfo_tag(rfo_tag),
	.pRn(rob.op.pRs2),
	.val(argB),
	.val_tag(argB_tag),
	.valid_i(valid[1]),
	.valid_o(valid_o[1])
);

Stark_validate_Rn uvRs3
(
	.prn(prn),
	.prnv(prnv),
	.rfo(rfo),
	.rfo_tag(rfo_tag),
	.pRn(rob.op.pRs3),
	.val(argC),
	.val_tag(argC_tag),
	.valid_i(valid[2]),
	.valid_o(valid_o[2])
);

always_ff @(posedge clk)
if (rst) begin
	id <= 5'd0;
	argA <= {$bits(address_t){1'b0}};
	argB <= {$bits(address_t){1'b0}};
	argC <= {$bits(value_t){1'b0}};
	argI <= {$bits(address_t){1'b0}};
	argA_tag <= 1'b0;
	argB_tag <= 1'b0;
	argC_tag <= 1'b0;
	aRa <= 8'd0;
	aRb <= 8'd0;
	aRc <= 8'd0;
	instr = {$bits(ex_instruction_t){1'b0}};
	pc <= RSTPC;
	pc.bno_t <= 6'd1;
	pc.bno_f <= 6'd1;
	op <= {26'd0,OP_NOP};
	virt2phys <= 1'b0;
	load <= 1'b0;
	store <= 1'b0;
	amo <= 1'b0;
	cp <= 4'd0;
	aRt <= 9'd0;
	pRa <= 9'd0;
	pRb <= 9'd0;
	pRc <= 9'd0;
	pRt <= 9'd0;
	excv <= 1'b0;	
	ldip <= FALSE;
	idle_o <= 1'b0;
	store_argC_v <= FALSE;
	store_argI <= {$bits(address_t){1'b0}};
	store_argC_aReg <= 8'd0;
	store_argC_pReg <= 10'd0;
	store_argC_cndx <= 4'd0;
	valid <= 3'h0;
end
else begin
	idle_o <= idle_i;
	if (issue && rndxv && idle_i) begin
		valid <= 4'd0;
		id <= rndx;
		om <= rob.om;
		we <= rob.op.decbus.store;
		instr = rob.op.uop.ins;
		if (rob.op.decbus.jsri)
			ldip <= TRUE;
		else
			ldip <= FALSE;
		argC_tag <= rfo_argC_ctag;
		argI <= address_t'(rob.op.decbus.immb);
		pRt <= rob.op.nRd;
		aRt <= rob.op.decbus.Rd;
		op <= rob.op;
		virt2phys <= rob.op.decbus.v2p;
		load <= rob.op.decbus.load|rob.op.decbus.loadz;
		store <= rob.op.decbus.store;
		amo <= rob.op.decbus.amo;
		pc <= rob.op.pc;
		aRa <= rob.op.decbus.Rs1;
		aRb <= rob.op.decbus.Rs2;
		aRc <= rob.op.decbus.Rs3;
		pRa <= rob.op.pRs1;
		pRb <= rob.op.pRs2;
		pRc <= rob.op.pRs3;
		argC_v <= rob.argC_v;
		cp <= rob.cndx;
		excv <= rob.excv;
		store_argC_aReg <= rob.op.decbus.Rs3;
		store_argC_pReg <= rob.op.pRs3;
		store_argC_cndx <= rob.cndx;
		store_argC_v <= rob.argC_v;
		store_argI <= address_t'(rob.op.decbus.immb);
	end
	/*
	else if (beb_issue & idle_i) begin
		ldip <= FALSE;
		argA <= beb.argA;
		argB <= beb.argB;
		argI <= address_t'(beb.decbus.immb);
		aRt <= beb.decbus.Rt;
		op <= beb.op;
		virt2phys <= 1'b0;
		load <= 1'b0;
		store <= 1'b0;
		amo <= 1'b0;
		pc <= beb.pc;
		aRa <= beb.decbus.Rs1;
		aRb <= beb.decbus.Rs2;
		aRc <= beb.decbus.Rs3;
		cp <= beb.cndx;
		excv <= beb.excv;
		store_argC_aReg <= beb.decbus.Rs3;
		store_argC_pReg <= beb.pRs3;
		store_argC_cndx <= beb.cndx;
		store_argC_v <= beb.argC_v;
		store_argI <= address_t'(beb.decbus.immb);
	end
	*/
	valid <= valid_o;
end

endmodule
