// ============================================================================
//        __
//   \\__/ o\    (C) 2024  Robert Finch, Waterloo
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
// 70 LUTs / 500 FFs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import QuplsPkg::*;

module Qupls_agen_station(rst, clk, idle_i, issue, rndx, rndxv, rob,
	rfo_argA, rfo_argB, rfo_argC, rfo_argM, argA_reg, argB_reg, argC_reg,
	beb_issue, bndx, beb,
	id, argA, argB, argC, argI, argM,
	aRa, aRb, aRc, aRt, pRa, pRb, pRc, pRt,
	pc, op, cp, excv, ldip, idle_o, store_argC_v, store_argI,
	store_argC_aReg,  store_argC_pReg, store_argC_cndx
);
input rst;
input clk;
input idle_i;
input issue;
input rob_ndx_t rndx;
input rndxv;
input rob_entry_t rob;
input value_t rfo_argA;
input value_t rfo_argB;
input value_t rfo_argC;
input value_t rfo_argM;
input pregno_t argA_reg;
input pregno_t argB_reg;
input pregno_t argC_reg;
input beb_issue;
input beb_ndx_t bndx;
input beb_entry_t beb;

output rob_ndx_t id;
output address_t argA;
output address_t argB;
output value_t argC;
output address_t argI;
output value_t argM;
output aregno_t aRa;
output aregno_t aRb;
output aregno_t aRc;
output aregno_t aRt;
output pregno_t pRa;
output pregno_t pRb;
output pregno_t pRc;
output pregno_t pRt;
output pc_address_t pc;
output pipeline_reg_t op;
output checkpt_ndx_t cp;
output reg excv;
output reg ldip;
output reg idle_o;
output reg store_argC_v;
output address_t store_argI;
output aregno_t store_argC_aReg;
output pregno_t store_argC_pReg;
output checkpt_ndx_t store_argC_cndx;

always_ff @(posedge clk)
if (rst) begin
	id <= 5'd0;
	argA <= {$bits(address_t){1'b0}};
	argB <= {$bits(address_t){1'b0}};
	argC <= {$bits(value_t){1'b0}};
	argI <= {$bits(address_t){1'b0}};
	argM <= 64'd0;
	aRa <= 8'd0;
	aRb <= 8'd0;
	aRc <= 8'd0;
	pc <= RSTPC;
	op <= {41'd0,OP_NOP};
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
end
else begin
	idle_o <= idle_i;
	if (issue && rndxv && idle_i) begin
		id <= rndx;
		if (rob.decbus.jsri)
			ldip <= TRUE;
		else
			ldip <= FALSE;
		case(rob.decbus.Ran)
		1'd0:	argA <= address_t'(rfo_argA);
		1'd1:	argA <= -address_t'(rfo_argA);
		endcase
		case(rob.decbus.Rbn)
		1'd0:	argB <= address_t'(rfo_argB);
		1'd1:	argB <= -address_t'(rfo_argB);
		endcase
		case(rob.decbus.Rcn)
		1'd0:	argC <= rfo_argC;
		1'd1:	argC <= -rfo_argC;
		endcase
		argI <= address_t'(rob.decbus.immb);
		argM <= rfo_argM;
		pRt <= rob.nRt;
		aRt <= rob.decbus.Rt;
		op <= rob.op;
		pc <= rob.pc;
		aRa <= rob.decbus.Ra;
		aRb <= rob.decbus.Rb;
		aRc <= rob.decbus.Rc;
		pRa <= argA_reg;
		pRb <= argB_reg;
		pRc <= argC_reg;
		cp <= rob.cndx;
		excv <= rob.excv;
		store_argC_aReg <= rob.decbus.Rc;
		store_argC_pReg <= rob.pRc;
		store_argC_cndx <= rob.cndx;
		store_argC_v <= rob.argC_v;
		store_argI <= address_t'(rob.decbus.immb);
	end
	else if (beb_issue & idle_i) begin
		ldip <= FALSE;
		argA <= beb.argA;
		argB <= beb.argB;
		argI <= address_t'(beb.decbus.immb);
		argM <= beb.argM;
		aRt <= beb.decbus.Rt;
		op <= beb.op;
		pc <= beb.pc;
		aRa <= beb.decbus.Ra;
		aRb <= beb.decbus.Rb;
		aRc <= beb.decbus.Rc;
		cp <= beb.cndx;
		excv <= beb.excv;
		store_argC_aReg <= beb.decbus.Rc;
		store_argC_pReg <= beb.pRc;
		store_argC_cndx <= beb.cndx;
		store_argC_v <= beb.argC_v;
		store_argI <= address_t'(beb.decbus.immb);
	end
end

endmodule
