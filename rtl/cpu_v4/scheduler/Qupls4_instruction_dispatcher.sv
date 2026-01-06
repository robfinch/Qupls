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
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_instruction_dispatcher(rst, clk, pgh, dbf, stomp, busy, rse_o,
	rob_dispatched_o, rob_dispatched_v_o);
parameter DISPATCH_COUNT=6;
parameter MWIDTH=4;
input rst;
input clk;
input Qupls4_pkg::pipeline_group_hdr_t [Qupls4_pkg::ROB_ENTRIES/MWIDTH-1:0] pgh;
input Qupls4_pkg::rob_entry_t [Qupls4_pkg::DBF_ENTRIES-1:0] dbf;
input [Qupls4_pkg::DBF_ENTRIES-1:0] stomp;
input [15:0] busy;
output Qupls4_pkg::reservation_station_entry_t [DISPATCH_COUNT-1:0] rse_o;
output cpu_types_pkg::rob_ndx_t [DISPATCH_COUNT-1:0] rob_dispatched_o;
output reg [DISPATCH_COUNT-1:0] rob_dispatched_v_o;

integer nn,mm;
Qupls4_pkg::reservation_station_entry_t [DISPATCH_COUNT-1:0] rse;
cpu_types_pkg::rob_ndx_t [DISPATCH_COUNT-1:0] rob_dispatched;
reg [DISPATCH_COUNT-1:0] rob_dispatched_v;
reg [3:0] prevNonNop;

// Find the next non-NOP. Used to skip over constant zones.

function rob_ndx_t fnFindPrevNonNop;
input rob_ndx_t st;
integer p1,p2,p3,p4,p5,p6;
begin
	p1 = (st + Qupls4_pkg::DBF_ENTRIES - 1) % Qupls4_pkg::DBF_ENTRIES;
	p2 = (st + Qupls4_pkg::DBF_ENTRIES - 2) % Qupls4_pkg::DBF_ENTRIES;
	p3 = (st + Qupls4_pkg::DBF_ENTRIES - 3) % Qupls4_pkg::DBF_ENTRIES;
	p4 = (st + Qupls4_pkg::DBF_ENTRIES - 4) % Qupls4_pkg::DBF_ENTRIES;
	p5 = (st + Qupls4_pkg::DBF_ENTRIES - 5) % Qupls4_pkg::DBF_ENTRIES;
	p6 = (st + Qupls4_pkg::DBF_ENTRIES - 6) % Qupls4_pkg::DBF_ENTRIES;
	if (!dbf[p1].op.decbus.nop)
		fnFindPrevNonNop = p1;
	else if (!dbf[p2].op.decbus.nop)
		fnFindPrevNonNop = p2;
	else if (!dbf[p3].op.decbus.nop)
		fnFindPrevNonNop = p3;
	else if (!dbf[p4].op.decbus.nop)
		fnFindPrevNonNop = p4;
	else if (!dbf[p5].op.decbus.nop)
		fnFindPrevNonNop = p5;
	else
		fnFindPrevNonNop = p6;
end
endfunction


always_comb
if (rst) begin
	rob_dispatched[0] = 8'd255;
	rob_dispatched[1] = 8'd255;
	rob_dispatched[2] = 8'd255;
	rob_dispatched[3] = 8'd255;
	rob_dispatched[4] = 8'd255;
	rob_dispatched[5] = 8'd255;
	nn = 0;
	rob_dispatched_v = 6'd0;
	rse[0] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	rse[1] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	rse[2] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	rse[3] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	rse[4] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	rse[5] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
end
else begin
	rob_dispatched[0] = 8'd255;
	rob_dispatched[1] = 8'd255;
	rob_dispatched[2] = 8'd255;
	rob_dispatched[3] = 8'd255;
	rob_dispatched[4] = 8'd255;
	rob_dispatched[5] = 8'd255;
	rob_dispatched_v = 6'd0;
	rse[0] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	rse[1] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	rse[2] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	rse[3] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	rse[4] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	rse[5] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};

	foreach (dbf[nn]) begin
		mm = nn/MWIDTH;
		prevNonNop = fnFindPrevNonNop(nn);
		// If valid ...
		if (dbf[nn].v &&
			// and checkpoint index valid...
			pgh[mm].cndxv &&
			// and not done already...
		  !(&dbf[nn].done) &&
			// and not out already...
			!(|dbf[nn].out) &&
			// and predicate is valid...
			dbf[nn].pred_bitv &&
			// and register must have been read
//			(RL_STRATEGY==0 ? dbf[nn].reg_read_done : TRUE) &&
			// and no sync dependency
			!dbf[nn].sync_dep &&
			// and not a register prefix or nop
			!dbf[nn].op.decbus.nop &&
			// if a store, then no previous flow control dependency
//			(dbf[nn].op.decbus.store ? !dbf[nn].fc_depv : TRUE) &&
			// if serializing the previous instruction must be done...
			(Qupls4_pkg::SERIALIZE ? &dbf[(nn + Qupls4_pkg::ROB_ENTRIES-1)%Qupls4_pkg::ROB_ENTRIES].done || !dbf[(nn + Qupls4_pkg::ROB_ENTRIES-1)%Qupls4_pkg::ROB_ENTRIES].v : TRUE) &&
			// and was not dispatched in the last cycle
			// It takes a clock cycle to set flags.

			(nn != rob_dispatched_o[0] || !rob_dispatched_v_o[0]) &&
			(nn != rob_dispatched_o[1] || !rob_dispatched_v_o[1]) &&
			(nn != rob_dispatched_o[2] || !rob_dispatched_v_o[2]) &&
			(nn != rob_dispatched_o[3] || !rob_dispatched_v_o[3]) &&
			(nn != rob_dispatched_o[4] || !rob_dispatched_v_o[4]) &&
			(nn != rob_dispatched_o[5] || !rob_dispatched_v_o[5])
			
		) begin
			if (!dbf[prevNonNop].op.decbus.rext || (&dbf[prevNonNop].done)) begin
				if (dbf[nn].op.decbus.sau && !busy[4'd0] && !rob_dispatched_v[0]) begin
					tLoadRse(0,nn,mm);
					// rse[0].funcunit = 4'd0; set to zero already above
					rse[0].rndx = dbf[nn].this_ndx;
					rob_dispatched[0] = dbf[nn].this_ndx;
					rob_dispatched_v[0] = VAL;
				end
				if (dbf[nn].op.decbus.sau && !busy[4'd1] && !rob_dispatched_v[5]) begin
					tLoadRse(5,nn,mm);
					rse[5].funcunit = 4'd1;
					rse[5].rndx = dbf[nn].this_ndx;
					rob_dispatched[5] = dbf[nn].this_ndx;
					rob_dispatched_v[5] = VAL;
				end
				if (dbf[nn].op.decbus.mul && !busy[2] && !rob_dispatched_v[1]) begin
					tLoadRse(1,nn,mm);
					rse[1].funcunit = 4'd2;
					rse[1].rndx = dbf[nn].this_ndx;
					rob_dispatched[1] = dbf[nn].this_ndx;
					rob_dispatched_v[1] = VAL;
				end
				if ((dbf[nn].op.decbus.div|dbf[nn].op.decbus.sqrt) && !busy[3] && !rob_dispatched_v[1]) begin
					tLoadRse(1,nn,mm);
					rse[1].funcunit = 4'd3;
					rse[1].rndx = dbf[nn].this_ndx;
					rob_dispatched[1] = dbf[nn].this_ndx;
					rob_dispatched_v[1] = VAL;
				end
				if (dbf[nn].op.decbus.fc && !busy[7] && !rob_dispatched_v[2]) begin
					tLoadRse(2,nn,mm);
					rse[2].funcunit = 4'd7; 
					rse[2].rndx = dbf[nn].this_ndx;
					rob_dispatched[2] = dbf[nn].this_ndx;
					rob_dispatched_v[2] = VAL;
				end
				if (dbf[nn].op.decbus.mem && !busy[4'd8] & !rob_dispatched_v[3]) begin
					tLoadRse(3,nn,mm);
					rse[3].funcunit = 4'd8; 
					rse[3].rndx = dbf[nn].this_ndx;
					rob_dispatched[3] = dbf[nn].this_ndx;
					rob_dispatched_v[3] = VAL;
				end
				if (dbf[nn].op.decbus.mem && !busy[4'd9] & !rob_dispatched_v[3]) begin
					tLoadRse(3,nn,mm);
					rse[3].funcunit = 4'd9; 
					rse[3].rndx = dbf[nn].this_ndx;
					rob_dispatched[3] = dbf[nn].this_ndx;
					rob_dispatched_v[3] = VAL;
				end
				if (Qupls4_pkg::SUPPORT_FLOAT && dbf[nn].op.decbus.fma && !busy[4'd4] && !rob_dispatched_v[4]) begin
					tLoadRse(4,nn,mm);
					rse[4].funcunit = 4'd4; 
					rse[4].rndx = dbf[nn].this_ndx;
					rob_dispatched[4] = dbf[nn].this_ndx;
					rob_dispatched_v[4] = VAL;
				end
				if (Qupls4_pkg::SUPPORT_FLOAT && dbf[nn].op.decbus.fma && !busy[4'd5] && !rob_dispatched_v[4]) begin
					tLoadRse(4,nn,mm);
					rse[4].funcunit = 4'd5; 
					rse[4].rndx = dbf[nn].this_ndx;
					rob_dispatched[4] = dbf[nn].this_ndx;
					rob_dispatched_v[4] = VAL;
				end
				if (Qupls4_pkg::SUPPORT_TRIG && dbf[nn].op.decbus.trig && !busy[4'd6] && !rob_dispatched_v[4]) begin
					tLoadRse(4,nn,mm);
					rse[4].funcunit = 4'd6; 
					rse[4].rndx = dbf[nn].this_ndx;
					rob_dispatched[4] = dbf[nn].this_ndx;
					rob_dispatched_v[4] = VAL;
				end
				if (Qupls4_pkg::SUPPORT_FLOAT && dbf[nn].op.decbus.fpu && !busy[4'd12] && !rob_dispatched_v[4]) begin
					tLoadRse(4,nn,mm);
					rse[4].funcunit = 4'd12;
					rse[4].rndx = dbf[nn].this_ndx;
					rob_dispatched[4] = dbf[nn].this_ndx;
					rob_dispatched_v[4] = VAL;
				end
			end
		end
	end
end

always_ff @(posedge clk)
	rse_o <= rse;
always_ff @(posedge clk)
	rob_dispatched_o <= rob_dispatched;
always_ff @(posedge clk)
	rob_dispatched_v_o <= rob_dispatched_v;

task tLoadRse;
input integer kk;
input cpu_types_pkg::rob_ndx_t nn;
input [5:0] mm;
integer xx;
begin
	rse[kk] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	rse[kk].om = dbf[nn].om;
	rse[kk].rm = dbf[nn].rm;
	rse[kk].pc.pc = pgh[mm].ip + dbf[nn].ip_offs;
	rse[kk].pc.stream = dbf[nn].ip_stream;
	rse[kk].prc = dbf[nn].op.decbus.prc;
	rse[kk].cndx = pgh[mm].cndx;
	rse[kk].rndx = nn;
	rse[kk].irq_sn = pgh[mm].irq_sn;
	rse[kk].aRd = dbf[nn].op.uop.Rd;
	rse[kk].nRd = dbf[nn].op.nRd;
	// mem specific
	rse[kk].virt2phys = dbf[nn].op.decbus.v2p;
	rse[kk].load = dbf[nn].op.decbus.load|dbf[nn].op.decbus.loadz;
	rse[kk].store = dbf[nn].op.decbus.store;
	rse[kk].amo = dbf[nn].op.decbus.amo;
	// branch specific
	rse[kk].bt = dbf[nn].bt;
	rse[kk].bcc = dbf[nn].op.decbus.br;
	rse[kk].cjb = dbf[nn].op.decbus.cjb;
	rse[kk].bsr = dbf[nn].op.decbus.bsr;
	rse[kk].jsr = dbf[nn].op.decbus.jsr;
	rse[kk].sys = dbf[nn].op.decbus.sys;
	if (dbf[nn].op.decbus.cpytgt|stomp[nn]|~dbf[nn].pred_bit) begin
		rse[kk].uop = {41'd0,Qupls4_pkg::OP_NOP};
		rse[kk].store = FALSE;
		for (xx = 0; xx < 4; xx = xx + 1) begin
			rse[kk].arg[xx].v = VAL;
			rse[kk].arg[xx].aRnv = INV;
//					rse[kk].argH[xx].v = VAL;
		end
	end
	else begin
		rse[kk].uop = dbf[nn].op.uop;
		rse[kk].store = dbf[nn].op.decbus.store;
		rse[kk].rext = dbf[nn].op.decbus.rext;

		rse[kk].arg[0].v = dbf[nn].argA_v;
		rse[kk].arg[1].v = dbf[nn].argB_v;
		rse[kk].arg[2].v = dbf[nn].argC_v;
		rse[kk].arg[3].v = dbf[nn].argT_v;
		rse[kk].arg[4].v = dbf[nn].argD_v;
		rse[kk].arg[5].v = dbf[nn].argS_v;
		rse[kk].arg[6].v = dbf[nn].argT2_v;
		rse[kk].arg[0].aRnv = dbf[nn].op.uop.src[0];
		rse[kk].arg[1].aRnv = dbf[nn].op.uop.src[1];
		rse[kk].arg[2].aRnv = dbf[nn].op.uop.src[2];
		rse[kk].arg[3].aRnv = dbf[nn].op.uop.src[3];
		rse[kk].arg[4].aRnv = dbf[nn].op.uop.src[4];
		rse[kk].arg[5].aRnv = dbf[nn].op.uop.src[5];
		rse[kk].arg[6].aRnv = dbf[nn].op.uop.src[6];
		
		rse[kk].arg[0].aRn = dbf[nn].op.uop.Rs1;
		rse[kk].arg[1].aRn = dbf[nn].op.uop.Rs2;
		rse[kk].arg[2].aRn = dbf[nn].op.uop.Rs3;
		rse[kk].arg[3].aRn = dbf[nn].op.uop.Rd;
		rse[kk].arg[4].aRn = dbf[nn].op.uop.Rs4;
		rse[kk].arg[5].aRn = 8'd33;
		rse[kk].arg[6].aRn = dbf[nn].op.uop.Rd2;

		rse[kk].arg[0].z = dbf[nn].op.decbus.Rs1z;
		rse[kk].arg[1].z = dbf[nn].op.decbus.Rs2z;
		rse[kk].arg[2].z = dbf[nn].op.decbus.Rs3z;
		rse[kk].arg[4].z = dbf[nn].op.Rs4z;

		rse[kk].arg[0].pRn = dbf[nn].op.pRs1;
		rse[kk].arg[1].pRn = dbf[nn].op.pRs2;
		rse[kk].arg[2].pRn = dbf[nn].op.pRs3;
		rse[kk].arg[3].pRn = dbf[nn].op.pRd;
		rse[kk].arg[4].pRn = dbf[nn].op.pRs4;
		rse[kk].arg[5].pRn = dbf[nn].op.pS;
		rse[kk].arg[6].pRn = dbf[nn].op.pRd2;
		/*
		rse[kk].argAh_v = !dbf[nn].op.decbus.b128;
		rse[kk].argBh_v = !dbf[nn].op.decbus.b128;
		rse[kk].argCh_v = !dbf[nn].op.decbus.b128;
		*/
	end
	rse[kk].arg[3].aRnv = dbf[nn].op.uop.src[3];
	rse[kk].arg[3].v = dbf[nn].argT_v;
	/*
	if (!dbf[nn].argAh_v) begin rse[kk].argAh[8:0] = dbf[nn].op.pRs1; rse[kk].argA[23:16] = dbf[nn].op.uop.Rs1; end
	if (!dbf[nn].argBh_v) begin rse[kk].argBh[8:0] = dbf[nn].op.pRs2; rse[kk].argB[23:16] = dbf[nn].op.uop.Rs2; end
	if (!dbf[nn].argCh_v) begin rse[kk].argCh[8:0] = dbf[nn].op.pRs3; rse[kk].argC[23:16] = dbf[nn].op.uop.Rs3; end
	if (!dbf[nn].argDh_v) begin rse[kk].argDh[8:0] = dbf[nn].op.pRd; rse[kk].argD[23:16] = dbf[nn].op.uop.Rd; end
	*/
	rse[kk].argI = dbf[nn].op.decbus.has_immb ? dbf[nn].op.decbus.immb : dbf[nn].op.decbus.immc;
//	rse[kk].funcunit = 4'd15;???
end
endtask

endmodule
