// ============================================================================
//        __
//   \\__/ o\    (C) 2024-2026  Robert Finch, Waterloo
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
// 25500 LUTs / 2400 FFs / 120 MHz
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_instruction_dispatcher(rst, clk, pgh, rob, stomp, busy, rse_o,
	rob_dispatched_o);
parameter DISPATCH_COUNT=6;
parameter MWIDTH=Qupls4_pkg::MWIDTH;
input rst;
input clk;
input Qupls4_pkg::pipeline_group_hdr_t [Qupls4_pkg::ROB_ENTRIES/MWIDTH-1:0] pgh;
input Qupls4_pkg::rob_entry_t [Qupls4_pkg::ROB_ENTRIES-1:0] rob;
input [Qupls4_pkg::ROB_ENTRIES-1:0] stomp;
input [15:0] busy;
output Qupls4_pkg::reservation_station_entry_t [DISPATCH_COUNT-1:0] rse_o;
output Qupls4_pkg::rob_bitmask_t rob_dispatched_o;

genvar g;
integer nn,mm;
Qupls4_pkg::reservation_station_entry_t [DISPATCH_COUNT-1:0] rse;
Qupls4_pkg::rob_bitmask_t rob_dispatched;
reg [3:0] dbf_dispatched;
reg [DISPATCH_COUNT-1:0] dispatch_slot_v;
Qupls4_pkg::rob_entry_t [5:0] dbf;

always_ff @(posedge clk)
if (rst)
	mm <= 0;
else begin
	if (&dbf_dispatched) begin
		if (mm + 4 >= Qupls4_pkg::ROB_ENTRIES)
			mm <= 0;
		else
			mm <= mm + 4;
	end
end

generate begin : gSel
	for (g = 0; g < Qupls4_pkg::ROB_ENTRIES; g = g + 4) begin
		if (g==mm) begin
			dbf[0] <= rob[g+0];
			dbf[1] <= rob[g+1];
			dbf[2] <= rob[g+2];
			dbf[3] <= rob[g+3];
		end
	end
end
endgenerate

always_comb
begin
	rob_dispatched = {$bits(rob_bitmask_t){1'b0}};
	dbf_dispatched = 4'h0;
	dispatch_slot_v = {DISPATCH_COUNT{1'b0}};
	rse[0] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	rse[1] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	rse[2] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	rse[3] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	rse[4] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	rse[5] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};

	foreach (dbf[nn]) begin
		// If valid ...
		if (dbf[nn].dispatchable &&
			// and was not dispatched in the last cycle
			// It takes a clock cycle to set flags.
			!dbf_dispatched[nn];
		) begin
			if (dbf[nn].op.decbus.sau && !busy[4'd0] && !dispatch_slot_v[0]) begin
				tLoadRse(0,dbf[nn]);
				// rse[0].funcunit = 4'd0; set to zero already above
				rse[0].rndx = nn;
				dbf_dispatched[nn] = VAL;
				dispatch_slot_v[0] = VAL;
			end
			if (dbf[nn].op.decbus.sau && !busy[4'd1] && !dispatch_slot_v[5] && !dbf[nn].op.decbus.sau0) begin
				tLoadRse(5,dbf[nn]);
				rse[5].funcunit = 4'd1;
				rse[5].rndx = nn;
				dbf_dispatched[nn] = VAL;
				dispatch_slot_v[5] = VAL;
			end
			if (dbf[nn].op.decbus.mul && !busy[2] && !dispatch_slot_v[1]) begin
				tLoadRse(1,nn);
				rse[1].funcunit = 4'd2;
				rse[1].rndx = nn;
				dbf_dispatched[nn] = VAL;
				dispatch_slot_v[1] = VAL;
			end
			if ((rob[nn].op.decbus.div|rob[nn].op.decbus.sqrt) && !busy[3] && !dispatch_slot_v[1]) begin
				tLoadRse(1,nn);
				rse[1].funcunit = 4'd3;
				rse[1].rndx = nn;
				rob_dispatched[nn] = VAL;
				dispatch_slot_v[1] = VAL;
			end
			if (rob[nn].op.decbus.fc && !busy[7] && !dispatch_slot_v[2]) begin
				tLoadRse(2,nn);
				rse[2].funcunit = 4'd7; 
				rse[2].rndx = nn;
				rob_dispatched[nn] = VAL;
				dispatch_slot_v[2] = VAL;
			end
			if (rob[nn].op.decbus.mem && !busy[4'd8] & !dispatch_slot_v[3]) begin
				tLoadRse(3,nn);
				rse[3].funcunit = 4'd8; 
				rse[3].rndx = nn;
				rob_dispatched[nn] = VAL;
				dispatch_slot_v[3] = VAL;
			end
			if (rob[nn].op.decbus.mem && !busy[4'd9] & !dispatch_slot_v[3]) begin
				tLoadRse(3,nn);
				rse[3].funcunit = 4'd9; 
				rse[3].rndx = nn;
				rob_dispatched[nn] = VAL;
				dispatch_slot_v[3] = VAL;
			end
			if (Qupls4_pkg::SUPPORT_FLOAT && rob[nn].op.decbus.fma && !busy[4'd4] && !dispatch_slot_v[4]) begin
				tLoadRse(4,nn);
				rse[4].funcunit = 4'd4; 
				rse[4].rndx = nn;
				rob_dispatched[nn] = VAL;
				dispatch_slot_v[4] = VAL;
			end
			if (Qupls4_pkg::SUPPORT_FLOAT && rob[nn].op.decbus.fma && !busy[4'd5] && !dispatch_slot_v[1]) begin
				tLoadRse(1,nn);
				rse[1].funcunit = 4'd5; 
				rse[1].rndx = nn;
				rob_dispatched[nn] = VAL;
				dispatch_slot_v[1] = VAL;
			end
			if (Qupls4_pkg::SUPPORT_TRIG && rob[nn].op.decbus.trig && !busy[4'd6] && !dispatch_slot_v[4]) begin
				tLoadRse(4,nn);
				rse[4].funcunit = 4'd6; 
				rse[4].rndx = nn;
				rob_dispatched[nn] = VAL;
				dispatch_slot_v[4] = VAL;
			end
			if (Qupls4_pkg::SUPPORT_FLOAT && rob[nn].op.decbus.fpu && !busy[4'd12] && !dispatch_slot_v[4]) begin
				tLoadRse(4,nn);
				rse[4].funcunit = 4'd12;
				rse[4].rndx = nn;
				rob_dispatched[nn] = VAL;
				dispatch_slot_v[4] = VAL;
			end
		end
	end
end

always_ff @(posedge clk)
	rse_o <= rse;
always_ff @(posedge clk)
	rob_dispatched_o <= rob_dispatched;

task tLoadRse;
input integer kk;
input cpu_types_pkg::rob_entry_t dbf;
integer xx,mm;
begin
	mm = dbfe.pghn;
	rse[kk] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	rse[kk].om = dbfe.om;
	rse[kk].rm = dbfe.rm;
	rse[kk].pc.pc = pgh[mm].ip + dbfe.ip_offs;
	rse[kk].pc.stream = dbfe.ip_stream;
	rse[kk].prc = dbfe.op.decbus.prc;
	rse[kk].cndx = pgh[mm].cndx;
	rse[kk].rndx = nn;
	rse[kk].irq_sn = pgh[mm].irq_sn;
	rse[kk].aRd = dbfe.op.uop.Rd;
	rse[kk].aRdv = dbfe.op.decbus.Rdv;
	rse[kk].nRd = dbfe.op.nRd;
	// mem specific
	rse[kk].virt2phys = dbfe.op.decbus.v2p;
	rse[kk].load = dbfe.op.decbus.load|dbfe.op.decbus.loadz;
	rse[kk].store = dbfe.op.decbus.store;
	rse[kk].amo = dbfe.op.decbus.amo;
	// branch specific
	rse[kk].bt = dbfe.bt;
	rse[kk].bcc = dbfe.op.decbus.br;
	rse[kk].ibcc = dbfe.op.decbus.ibr;
	rse[kk].dbcc = dbfe.op.decbus.dbr;
	rse[kk].cjb = dbfe.op.decbus.cjb;
	rse[kk].bsr = dbfe.op.decbus.bsr;
	rse[kk].jsr = dbfe.op.decbus.jsr;
	rse[kk].sys = dbfe.op.decbus.sys;
	if (dbfe.op.decbus.cpytgt|stomp[nn]|~dbfe.pred_bit) begin
		rse[kk].uop = {41'd0,Qupls4_pkg::OP_NOP};
		rse[kk].store = FALSE;
		for (xx = 0; xx < 4; xx = xx + 1) begin
			rse[kk].arg[xx].v = VAL;
			rse[kk].arg[xx].aRnv = INV;
//					rse[kk].argH[xx].v = VAL;
		end
	end
	else begin
		rse[kk].uop = dbfe.op.uop;
		rse[kk].store = dbfe.op.decbus.store;
		rse[kk].rext = dbfe.op.decbus.rext;

		rse[kk].arg[0].v = dbfe.argA_v;
		rse[kk].arg[1].v = dbfe.argB_v;
		rse[kk].arg[2].v = dbfe.argC_v;
		rse[kk].arg[3].v = dbfe.argT_v;
		rse[kk].arg[4].v = dbfe.argD_v;
		rse[kk].arg[5].v = dbfe.argS_v;
		rse[kk].arg[6].v = dbfe.argT2_v;
		rse[kk].arg[0].aRnv = dbfe.op.uop.src[0];
		rse[kk].arg[1].aRnv = dbfe.op.uop.src[1];
		rse[kk].arg[2].aRnv = dbfe.op.uop.src[2];
		rse[kk].arg[3].aRnv = dbfe.op.uop.src[3];
		rse[kk].arg[4].aRnv = dbfe.op.uop.src[4];
		rse[kk].arg[5].aRnv = dbfe.op.uop.src[5];
		rse[kk].arg[6].aRnv = dbfe.op.uop.src[6];
		
		rse[kk].arg[0].aRn = dbfe.op.uop.Rs1;
		rse[kk].arg[1].aRn = dbfe.op.uop.Rs2;
		rse[kk].arg[2].aRn = dbfe.op.uop.Rs3;
		rse[kk].arg[3].aRn = dbfe.op.uop.Rd;
		rse[kk].arg[4].aRn = dbfe.op.uop.Rs4;
		rse[kk].arg[5].aRn = 8'd33;
		rse[kk].arg[6].aRn = dbfe.op.uop.Rd2;

		rse[kk].arg[0].z = dbfe.op.decbus.Rs1z;
		rse[kk].arg[1].z = dbfe.op.decbus.Rs2z;
		rse[kk].arg[2].z = dbfe.op.decbus.Rs3z;
		rse[kk].arg[4].z = dbfe.op.Rs4z;

		rse[kk].arg[0].pRn = dbfe.op.pRs1;
		rse[kk].arg[1].pRn = dbfe.op.pRs2;
		rse[kk].arg[2].pRn = dbfe.op.pRs3;
		rse[kk].arg[3].pRn = dbfe.op.pRd;
		rse[kk].arg[4].pRn = dbfe.op.pRs4;
		rse[kk].arg[5].pRn = dbfe.op.pS;
		rse[kk].arg[6].pRn = dbfe.op.pRd2;
		/*
		rse[kk].argAh_v = !dbfe.op.decbus.b128;
		rse[kk].argBh_v = !dbfe.op.decbus.b128;
		rse[kk].argCh_v = !dbfe.op.decbus.b128;
		*/
	end
	rse[kk].arg[3].aRnv = dbfe.op.uop.src[3];
	rse[kk].arg[3].v = dbfe.argT_v;
	/*
	if (!dbfe.argAh_v) begin rse[kk].argAh[8:0] = dbfe.op.pRs1; rse[kk].argA[23:16] = dbfe.op.uop.Rs1; end
	if (!dbfe.argBh_v) begin rse[kk].argBh[8:0] = dbfe.op.pRs2; rse[kk].argB[23:16] = dbfe.op.uop.Rs2; end
	if (!dbfe.argCh_v) begin rse[kk].argCh[8:0] = dbfe.op.pRs3; rse[kk].argC[23:16] = dbfe.op.uop.Rs3; end
	if (!dbfe.argDh_v) begin rse[kk].argDh[8:0] = dbfe.op.pRd; rse[kk].argD[23:16] = dbfe.op.uop.Rd; end
	*/
	rse[kk].argI = dbfe.op.decbus.has_immb ? dbfe.op.decbus.immb : dbfe.op.decbus.immc;
//	rse[kk].funcunit = 4'd15;???
end
endtask

endmodule
