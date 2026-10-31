// ============================================================================
//        __
//   \\__/ o\    (C) 2026  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// Qupls4_cap_instruction_dispatcher.sv
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
// 2200 LUTs / 2400 FFs / 205 MHz (old)
//	LUTs / FFs / 120 MHz
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import capability_pkg::*;
import Qupls4_pkg::*;

module Qupls4_cap_instruction_dispatcher(rst, clk, pgh, rob, stomp, busy, rse_o,
	rob_dispatched_o, rob_unimplemented_o);
parameter DISPATCH_COUNT=1;
parameter MWIDTH=Qupls4_pkg::MWIDTH;
input rst;
input clk;
input Qupls4_pkg::pipeline_group_hdr_t [Qupls4_pkg::ROB_ENTRIES/MWIDTH-1:0] pgh;
input Qupls4_pkg::rob_entry_t [Qupls4_pkg::ROB_ENTRIES-1:0] rob;
input [Qupls4_pkg::ROB_ENTRIES-1:0] stomp;
input busy;
output Qupls4_pkg::cap_reservation_station_entry_t rse_o;
output Qupls4_pkg::rob_bitmask_t rob_dispatched_o;
output Qupls4_pkg::rob_bitmask_t rob_unimplemented_o;

typedef struct packed
{
	reg [7:0] rob;
	reg [2:0] rse;
	reg [2:0] fu;
} cpy_t;

integer nn,mm,pipe;
Qupls4_pkg::cap_reservation_station_entry_t [Qupls4_pkg::ROB_ENTRIES:0] rse;
Qupls4_pkg::rob_bitmask_t rob_dispatched, rob_dispatched2, rob_unimplemented;
reg dispatch_slot_v;
cpy_t cpy;

always_comb
begin
	rob_dispatched = {$bits(rob_bitmask_t){1'b0}};
	rob_unimplemented = {$bits(rob_bitmask_t){1'b0}};
	dispatch_slot_v = 1'b0;
	rse = {$bits(Qupls4_pkg::cap_reservation_station_entry_t){1'b0}};

	rse[Qupls4_pkg::ROB_ENTRIES] = {$bits(rob_entry_t){1'b0}};
	cpy.rse = Qupls4_pkg::ROB_ENTRIES;
	cpy.rob = rob_ndx_t'(0);
	cpy.fu = 4'd0;

	foreach (rob[nn]) begin
		// If valid ...
		if (rob[nn].cap_dispatchable &&
			// and was not dispatched in the last cycle
			// It takes a clock cycle to set flags.
			!rob_dispatched[nn] &&
			!rob_dispatched_o[nn] &&
			!rob_dispatched2[nn]
		) begin
			if ((SUPPORT_CAPABILITIES && rob[nn].op.decbus.cap) && !busy && !dispatch_slot_v && !rob_dispatched[nn]) begin
				cpy.rob = nn;
				cpy.rse = 0;
				cpy.fu = 0;
				// rse[0].funcunit = 4'd0; set to zero already above
				rob_dispatched[nn] = VAL;
				dispatch_slot_v = VAL;
			end
		end
	end

	foreach (rob[nn])
		tLoadRse(nn,nn);
end

always_ff @(posedge clk)
if (rst) begin
	foreach (rse_o[mm])
		rse_o[mm] <= {$bits(Qupls4_pkg::cap_reservation_station_entry_t){1'b0}};
end
else begin
	rse_o <= rse[cpy.rob];
	rse_o.funcunit <= cpy.fu;
end
always_ff @(posedge clk)
	rob_dispatched_o <= rob_dispatched;
always_ff @(posedge clk)
	rob_dispatched2 <= rob_dispatched_o;
always_ff @(posedge clk)
	rob_unimplemented_o <= rob_unimplemented;

task tLoadRse;
input integer kk;
input cpu_types_pkg::rob_ndx_t nn;
integer xx,mm;
begin
	mm = rob[nn].pghn;
	rse[kk] = {$bits(Qupls4_pkg::cap_reservation_station_entry_t){1'b0}};
	rse[kk].v = rob_dispatched[nn];
	rse[kk].exc = rob[nn].exc;
	rse[kk].excv = rob[nn].excv;
	rse[kk].om = rob[nn].om;
	rse[kk].rm = rob[nn].rm;
	rse[kk].pc.pc = pgh[mm].ip + rob[nn].ip_offs;
	rse[kk].pc.stream = rob[nn].ip_stream;
	rse[kk].prc = rob[nn].op.decbus.prc;
	rse[kk].cndx = pgh[mm].cndx;
	rse[kk].rndx = nn;
	rse[kk].irq_sn = pgh[mm].irq_sn;
	rse[kk].aRd = rob[nn].op.uop.Rd;
	rse[kk].aRdv = rob[nn].op.decbus.Rdv;
	rse[kk].nRd = rob[nn].op.nRd;
	rse[kk].we = rob[nn].op.decbus.we;
	rse[kk].fclass = rob[nn].op.decbus.fclass;
	// mem specific
	rse[kk].load = rob[nn].op.decbus.load|rob[nn].op.decbus.loadz|rob[nn].op.decbus.vload;
	rse[kk].store = rob[nn].op.decbus.store|rob[nn].op.decbus.vstore;
	rse[kk].mem = rob[nn].op.decbus.mem;
	// branch specific
	rse[kk].bt = rob[nn].bt;
	rse[kk].bcc = rob[nn].op.decbus.br;
	rse[kk].mbcc = rob[nn].op.decbus.br & rob[nn].op.uop.opcode==Qupls4_pkg::OP_MBCC;
	rse[kk].ibcc = rob[nn].op.decbus.ibr;
	rse[kk].dbcc = rob[nn].op.decbus.dbr;
	rse[kk].cjb = rob[nn].op.decbus.cjb;
	rse[kk].bsr = rob[nn].op.decbus.bsr;
	rse[kk].jsr = rob[nn].op.decbus.jsr;
	rse[kk].sys = rob[nn].op.decbus.sys;
	if (rob[nn].op.decbus.cpytgt|stomp[nn]) begin
		rse[kk].copydst = 8'hFF;
		rse[kk].uop = {41'd0,Qupls4_pkg::OP_NOP};
		rse[kk].store = FALSE;
		for (xx = 0; xx < 4; xx = xx + 1) begin
			rse[kk].arg[xx].v = VAL;
			rse[kk].arg[xx].aRnv = INV;
//					rse[kk].argH[xx].v = VAL;
		end
	end
	else begin
		rse[kk].copydst = 8'h00;
		rse[kk].uop = rob[nn].op.uop;
		rse[kk].store = rob[nn].op.decbus.store;
		rse[kk].rext = rob[nn].op.decbus.rext;

		rse[kk].arg[0].v = rob[nn].argA_v;
		rse[kk].arg[1].v = rob[nn].argB_v;
		rse[kk].arg[2].v = rob[nn].argC_v;
		rse[kk].arg[3].v = rob[nn].argT_v;
		rse[kk].arg[4].v = rob[nn].argD_v;
		rse[kk].arg[5].v = rob[nn].argS_v;
		rse[kk].arg[6].v = rob[nn].argT2_v;
		rse[kk].arg[0].aRnv = rob[nn].op.uop.src[0];
		rse[kk].arg[1].aRnv = rob[nn].op.uop.src[1];
		rse[kk].arg[2].aRnv = rob[nn].op.uop.src[2];
		rse[kk].arg[3].aRnv = rob[nn].op.uop.src[3];
		rse[kk].arg[4].aRnv = rob[nn].op.uop.src[4];
		rse[kk].arg[5].aRnv = rob[nn].op.uop.src[5];
		rse[kk].arg[6].aRnv = rob[nn].op.uop.src[6];
		
		rse[kk].arg[0].aRn = rob[nn].op.uop.Rs1;
		rse[kk].arg[1].aRn = rob[nn].op.uop.Rs2;
		rse[kk].arg[2].aRn = rob[nn].op.uop.Rs3;
		rse[kk].arg[3].aRn = rob[nn].op.uop.Rd;
		rse[kk].arg[4].aRn = rob[nn].op.uop.Rs4;
		rse[kk].arg[5].aRn = rob[nn].op.uop.Rm;
		rse[kk].arg[6].aRn = rob[nn].op.uop.Rd2;

		rse[kk].arg[0].z = rob[nn].op.decbus.Rs1z;
		rse[kk].arg[1].z = rob[nn].op.decbus.Rs2z;
		rse[kk].arg[2].z = rob[nn].op.decbus.Rs3z;
		rse[kk].arg[4].z = rob[nn].op.Rs4z;

		rse[kk].arg[0].pRn = rob[nn].op.pRs1;
		rse[kk].arg[1].pRn = rob[nn].op.pRs2;
		rse[kk].arg[2].pRn = rob[nn].op.pRs3;
		rse[kk].arg[3].pRn = rob[nn].op.pRd;
		rse[kk].arg[4].pRn = rob[nn].op.pRs4;
		rse[kk].arg[5].pRn = rob[nn].op.pRm;
		rse[kk].arg[6].pRn = rob[nn].op.pRd2;
		/*
		rse[kk].argAh_v = !rob[nn].op.decbus.b128;
		rse[kk].argBh_v = !rob[nn].op.decbus.b128;
		rse[kk].argCh_v = !rob[nn].op.decbus.b128;
		*/
	end
	rse[kk].arg[3].aRnv = rob[nn].op.uop.src[3];
	rse[kk].arg[3].v = rob[nn].argT_v;
	/*
	if (!rob[nn].argAh_v) begin rse[kk].argAh[8:0] = rob[nn].op.pRs1; rse[kk].argA[23:16] = rob[nn].op.uop.Rs1; end
	if (!rob[nn].argBh_v) begin rse[kk].argBh[8:0] = rob[nn].op.pRs2; rse[kk].argB[23:16] = rob[nn].op.uop.Rs2; end
	if (!rob[nn].argCh_v) begin rse[kk].argCh[8:0] = rob[nn].op.pRs3; rse[kk].argC[23:16] = rob[nn].op.uop.Rs3; end
	if (!rob[nn].argDh_v) begin rse[kk].argDh[8:0] = rob[nn].op.pRd; rse[kk].argD[23:16] = rob[nn].op.uop.Rd; end
	*/
//	rse[kk].argI = rob[nn].op.decbus.has_immb ? rob[nn].op.decbus.immb : rob[nn].op.decbus.immc;
	rse[kk].argI = rob[nn].op.uop.imm;
	if (rob[nn].op.decbus.has_imma) begin
		rse[kk].arg[0].is_const = TRUE;
		rse[kk].arg[0].val.offset = rob[nn].op.decbus.imma;
	end
	if (rob[nn].op.decbus.has_immb) begin
		rse[kk].arg[1].is_const = TRUE;
		rse[kk].arg[1].val.offset = rob[nn].op.decbus.immb;
	end
	if (rob[nn].op.decbus.has_immc) begin
		rse[kk].arg[2].is_const = TRUE;
		rse[kk].arg[2].val.offset = rob[nn].op.decbus.immc;
	end
	if (rob[nn].op.decbus.has_immd) begin
		rse[kk].arg[4].is_const = TRUE;
		rse[kk].arg[4].val.offset = rob[nn].op.decbus.immd;
	end
//	rse[kk].funcunit = 4'd15;???
end
endtask

endmodule
