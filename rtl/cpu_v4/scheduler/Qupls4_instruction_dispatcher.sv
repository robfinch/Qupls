// ============================================================================
//        __
//   \\__/ o\    (C) 2024-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// Qupls4_instruction_dispatcher.sv
//	- search ROB for instructions with valid physical registers that are 
//    ready to be dispatched.
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
// Qupls4_instruction_dispatch.sv:
//
// Only dispatches up to the limit of the number of functional units of a
// given type. For example there is only one flow control unit, so dispatch
// will not try and dispatch two flow controls in the same cycle.
//
// 39000 LUTs 1300 FFs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_instruction_dispatcher(rst, clk, pgh, rob, stomp, busy, rse_o,
	rob_dispatched, rob_dispatched_v);
input rst;
input clk;
input Qupls4_pkg::pipeline_group_hdr_t [Qupls4_pkg::ROB_ENTRIES/4-1:0] pgh;
input Qupls4_pkg::rob_entry_t [Qupls4_pkg::ROB_ENTRIES-1:0] rob;
input [Qupls4_pkg::ROB_ENTRIES-1:0] stomp;
input [15:0] busy;
output Qupls4_pkg::reservation_station_entry_t [3:0] rse_o;
output Qupls4_pkg::rob_entry_t [3:0] rob_dispatched;
output reg [3:0] rob_dispatched_v;

integer nn, kk, jj;
reg [3:0] sau_cnt, mul_cnt, div_cnt, fma_cnt, trig_cnt, fcu_cnt, agen_cnt;
reg [3:0] mem_cnt, fpu_cnt, sqrt_cnt;

always_ff @(posedge clk)
begin
	kk = 0;
	jj = 0;
	sau_cnt = 4'd0;
	mul_cnt = 4'd0;
	div_cnt = 4'd0;
	fma_cnt = 4'd0;
	trig_cnt = 4'd0;
	fcu_cnt = 4'd0;
	agen_cnt = 4'd0;
	mem_cnt = 4'd0;
	fpu_cnt = 4'd0;
	sqrt_cnt = 4'd0;
	rob_dispatched_v = 4'd0;
	for (nn = 0; nn < Qupls4_pkg::ROB_ENTRIES; nn = nn + 1) begin
		// If valid ...
		if (rob[nn].v &&
			// and checkpoint index valid...
			pgh[nn>>2].cndxv &&
			// and not done already...
		  !(&rob[nn].done) &&
			// and not out already...
			!(|rob[nn].out) &&
			// and predicate is valid...
			rob[nn].pred_bitv &&
			// and no sync dependency
			!rob[nn].sync_dep &&
			// if a store, then no previous flow control dependency
			(rob[nn].op.decbus.store ? !rob[nn].fc_depv : TRUE) &&
			// if serializing the previous instruction must be done...
			(Qupls4_pkg::SERIALIZE ? &rob[(nn + Qupls4_pkg::ROB_ENTRIES-1)%Qupls4_pkg::ROB_ENTRIES].done || !rob[(nn + Qupls4_pkg::ROB_ENTRIES-1)%Qupls4_pkg::ROB_ENTRIES].v : TRUE) &&
			// and registers are mapped
			rob[nn].op.pRs1v &&
			rob[nn].op.pRs2v &&
			rob[nn].op.pRs3v &&
			rob[nn].op.pRdv &&
			rob[nn].op.nRdv &&
			// and dispatched fewer than four
			kk < 4 &&
			// and was not dispatched in the last cycle
			nn != rob_dispatched[0] &&
			nn != rob_dispatched[1] &&
			nn != rob_dispatched[2] &&
			nn != rob_dispatched[3]
		) begin
			rse_o[kk] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
			rse_o[kk].om = rob[nn].om;
			rse_o[kk].rm = rob[nn].rm;
			rse_o[kk].pc = rob[nn].op.pc.pc;
			rse_o[kk].prc = rob[nn].op.decbus.prc;
			rse_o[kk].cndx = pgh[nn>>2].cndx;
			rse_o[kk].aRdz = rob[nn].op.decbus.Rdz;
			rse_o[kk].aRd = rob[nn].op.decbus.Rd;
			rse_o[kk].nRd = rob[nn].op.nRd;
			// mem specific
			rse_o[kk].virt2phys = rob[nn].op.decbus.v2p;
			rse_o[kk].load = rob[nn].op.decbus.load|rob[nn].op.decbus.loadz;
			rse_o[kk].store = rob[nn].op.decbus.store;
			rse_o[kk].amo = rob[nn].op.decbus.amo;
			rse_o[kk].push = rob[nn].op.decbus.push;
			rse_o[kk].pop = rob[nn].op.decbus.pop;
			rse_o[kk].count = rob[nn].op.decbus.count;
			// branch specific
			rse_o[kk].bt = rob[nn].bt;
			rse_o[kk].brclass = rob[nn].op.decbus.brclass;
			rse_o[kk].cjb = rob[nn].op.decbus.cjb;
			rse_o[kk].bl = rob[nn].op.decbus.bl;
			if (rob[nn].op.decbus.cpytgt|stomp[nn]|~rob[nn].pred_bit) begin
				rse_o[kk].uop.ins = {26'd0,Qupls4_pkg::OP_NOP};
				rse_o[kk].store = FALSE;
				rse_o[kk].argA_v = VAL;
				rse_o[kk].argB_v = VAL;
				rse_o[kk].argC_v = VAL;
				/*
				rse_o[kk].argAh_v = VAL;
				rse_o[kk].argBh_v = VAL;
				rse_o[kk].argCh_v = VAL;
				*/
			end
			else begin
				rse_o[kk].uop.ins = rob[nn].op.uop.ins;
				rse_o[kk].store = rob[nn].op.decbus.store;
				rse_o[kk].argA_v = rob[nn].argA_v;
				rse_o[kk].argB_v = rob[nn].argB_v;
				rse_o[kk].argC_v = rob[nn].argC_v;
				/*
				rse_o[kk].argAh_v = !rob[nn].op.decbus.b128;
				rse_o[kk].argBh_v = !rob[nn].op.decbus.b128;
				rse_o[kk].argCh_v = !rob[nn].op.decbus.b128;
				*/
			end
			rse_o[kk].argD_v = rob[nn].argD_v;
			if (!rob[nn].argA_v) begin rse_o[kk].argA[8:0] = rob[nn].op.pRs1; rse_o[kk].argA[23:16] = rob[nn].op.decbus.Rs1; end
			if (!rob[nn].argB_v) begin rse_o[kk].argB[8:0] = rob[nn].op.pRs2; rse_o[kk].argB[23:16] = rob[nn].op.decbus.Rs2; end
			if (!rob[nn].argC_v) begin rse_o[kk].argC[8:0] = rob[nn].op.pRs3; rse_o[kk].argC[23:16] = rob[nn].op.decbus.Rs3; end
			if (!rob[nn].argD_v) begin rse_o[kk].argD[8:0] = rob[nn].op.pRd; rse_o[kk].argD[23:16] = rob[nn].op.decbus.Rd; end
			/*
			if (!rob[nn].argAh_v) begin rse_o[kk].argAh[8:0] = rob[nn].op.pRs1; rse_o[kk].argA[23:16] = rob[nn].op.decbus.Rs1; end
			if (!rob[nn].argBh_v) begin rse_o[kk].argBh[8:0] = rob[nn].op.pRs2; rse_o[kk].argB[23:16] = rob[nn].op.decbus.Rs2; end
			if (!rob[nn].argCh_v) begin rse_o[kk].argCh[8:0] = rob[nn].op.pRs3; rse_o[kk].argC[23:16] = rob[nn].op.decbus.Rs3; end
			if (!rob[nn].argDh_v) begin rse_o[kk].argDh[8:0] = rob[nn].op.pRd; rse_o[kk].argD[23:16] = rob[nn].op.decbus.Rd; end
			*/
			// Search for references to the IP and fill in.
			if (rob[nn].op.decbus.Rs1==7'd63) begin
				rse_o[kk].argA = rob[nn].op.pc.pc;
//				rse_o[kk].argAh = rob[nn].op.pc.pch;
				rse_o[kk].argA_v = VAL;
//				rse_o[kk].argAh_v = VAL;
			end
			if (rob[nn].op.decbus.Rs2==7'd63) begin
				rse_o[kk].argB = rob[nn].op.pc.pc;
//				rse_o[kk].argBh = rob[nn].op.pc.pch;
				rse_o[kk].argB_v = VAL;
//				rse_o[kk].argBh_v = VAL;
			end
			if (rob[nn].op.decbus.Rs3==7'd63) begin
				rse_o[kk].argC = rob[nn].op.pc.pc;
//				rse_o[kk].argCh = rob[nn].op.pc.pch;
				rse_o[kk].argC_v = VAL;
//				rse_o[kk].argCh_v = VAL;
			end
			rse_o[kk].argI = rob[nn].op.decbus.has_immb ? rob[nn].op.decbus.immb : rob[nn].op.decbus.immc;
			rse_o[kk].funcunit = 4'd15;
			if (rob[nn].op.decbus.sau && sau_cnt < Qupls4_pkg::NSAU && !busy[{3'd0,sau_cnt[0]}]) begin
				rse_o[kk].funcunit = {3'd0,sau_cnt[0]};
				rse_o[kk].rndx = nn;
				sau_cnt = sau_cnt + 1;
				rob_dispatched[kk] = nn;
				rob_dispatched_v[kk] = VAL;
				kk = kk + 1;
			end
			if (rob[nn].op.decbus.mul && mul_cnt < 1 && !busy[2]) begin
				rse_o[kk].funcunit = 4'd2;
				rse_o[kk].rndx = nn;
				mul_cnt = mul_cnt + 1;
				rob_dispatched[kk] = nn;
				rob_dispatched_v[kk] = VAL;
				kk = kk + 1;
			end
			if (rob[nn].op.decbus.div && div_cnt < 1 && !busy[3]) begin
				rse_o[kk].funcunit = 4'd3;
				rse_o[kk].rndx = nn;
				div_cnt = div_cnt + 1;
				rob_dispatched[kk] = nn;
				rob_dispatched_v[kk] = VAL;
				kk = kk + 1;
			end
			if (rob[nn].op.decbus.sqrt && sqrt_cnt < 1 && !busy[3]) begin
				rse_o[kk].funcunit = 4'd3;
				rse_o[kk].rndx = nn;
				sqrt_cnt = sqrt_cnt + 1;
				rob_dispatched[kk] = nn;
				rob_dispatched_v[kk] = VAL;
				kk = kk + 1;
			end
			if (rob[nn].op.decbus.fma && fma_cnt < Qupls4_pkg::NFMA && !busy[4'd4+fma_cnt]) begin
				rse_o[kk].funcunit = 4'd4 + fma_cnt; 
				rse_o[kk].rndx = nn;
				fma_cnt = fma_cnt + 1;
				rob_dispatched[kk] = nn;
				rob_dispatched_v[kk] = VAL;
				kk = kk + 1;
			end
			if (rob[nn].op.decbus.trig && trig_cnt < 1 && !busy[6]) begin
				rse_o[kk].funcunit = 4'd6; 
				rse_o[kk].rndx = nn;
				trig_cnt = trig_cnt + 1;
				rob_dispatched[kk] = nn;
				rob_dispatched_v[kk] = VAL;
				kk = kk + 1;
			end
			if (rob[nn].op.decbus.fc && fcu_cnt < 1 && !busy[7]) begin
				rse_o[kk].funcunit = 4'd7; 
				rse_o[kk].rndx = nn;
				fcu_cnt = fcu_cnt + 1;
				rob_dispatched[kk] = nn;
				rob_dispatched_v[kk] = VAL;
				kk = kk + 1;
			end
			if (rob[nn].op.decbus.mem && agen_cnt < Qupls4_pkg::NAGEN && !busy[4'd8 + agen_cnt]) begin
				rse_o[kk].funcunit = 4'd8 + agen_cnt; 
				rse_o[kk].rndx = nn;
				agen_cnt = agen_cnt + 1;
				rob_dispatched[kk] = nn;
				rob_dispatched_v[kk] = VAL;
				kk = kk + 1;
			end
			/*
			if (rob[nn].op.decbus.mem && mem_cnt < NDATA_PORTS && !busy[4'd10+mem_cnt]) begin
				rse_o[kk].funcunit = 4'd10 + mem_cnt;
				rse_o[kk].rndx = nn;
				mem_cnt = mem_cnt + 1;
				rob_dispatched[kk] = nn;
				rob_dispatched_v[kk] = VAL;
				kk = kk + 1;
			end
			*/
			if (rob[nn].op.decbus.fpu && fpu_cnt < 1 && !busy[4'd12]) begin
				rse_o[kk].funcunit = 4'd12;
				rse_o[kk].rndx = nn;
				fpu_cnt = fpu_cnt + 1;
				rob_dispatched[kk] = nn;
				rob_dispatched_v[kk] = VAL;
				kk = kk + 1;
			end
		end
	end
end

endmodule
