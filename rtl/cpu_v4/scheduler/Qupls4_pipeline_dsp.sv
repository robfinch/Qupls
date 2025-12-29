// ============================================================================
//        __
//   \\__/ o\    (C) 2024-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// Qupls4_pipeline_dsp.sv
//	- dispatch stage
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

module Qupls4_pipeline_dsp(rst, clk, ce, tail, pg_ren, pg_dsp, stomp, busy,
	stall_dsp, rse_o, rob_dispatched_o, rob_dispatched_v_o);
parameter DISPATCH_COUNT=6;
parameter MWIDTH=4;
input rst;
input clk;
input ce;
input rob_ndx_t [11:0] tail;
input Qupls4_pkg::pipeline_group_reg_t pg_ren;
output Qupls4_pkg::pipeline_group_reg_t pg_dsp;
input [Qupls4_pkg::ROB_ENTRIES-1:0] stomp;
input [15:0] busy;
output reg stall_dsp;
output Qupls4_pkg::reservation_station_entry_t [DISPATCH_COUNT-1:0] rse_o;
output cpu_types_pkg::rob_ndx_t [DISPATCH_COUNT-1:0] rob_dispatched_o;
output reg [DISPATCH_COUNT-1:0] rob_dispatched_v_o;

integer nn,mm,kk,jj;
Qupls4_pkg::reservation_station_entry_t [DISPATCH_COUNT-1:0] rse;
cpu_types_pkg::rob_ndx_t [DISPATCH_COUNT-1:0] rob_dispatched;
reg [DISPATCH_COUNT-1:0] rob_dispatched_v;
reg [3:0] prevNonNop;
Qupls4_pkg::pipeline_group_hdr_t pgh;
reg stall;
reg [MWIDTH-1:0] dispatch_done, dispatched;

always_comb
	pgh = pg_ren.hdr;
always_comb
	stall_dsp = |busy|stall;

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
	dispatched = {MWIDTH{1'b0}};
	stall = 1'b0;
	mm = 0;
	kk = 0;
end
else begin
	rob_dispatched_v = 6'd0;
	rob_dispatched[0] = 8'd255;
	rob_dispatched[1] = 8'd255;
	rob_dispatched[2] = 8'd255;
	rob_dispatched[3] = 8'd255;
	rob_dispatched[4] = 8'd255;
	rob_dispatched[5] = 8'd255;
	rse[0] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	rse[1] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	rse[2] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	rse[3] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	rse[4] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	rse[5] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	dispatched = dispatch_done;
	
	kk = jj;
	mm = tail[0]/MWIDTH;
	stall = 1'b0;
	foreach (pg_ren.pr[nn]) begin
		// If valid ...
		if (pg_ren.pr[nn].v &&
			// and checkpoint index valid...
			pgh.cndxv &&
			// and not a register prefix or nop
			!pg_ren.pr[nn].op.decbus.nop &&
			// if a store, then no previous flow control dependency
//			(pg_ren.pr[nn].op.decbus.store ? !pg_ren.pr[nn].fc_depv : TRUE) &&
			// if serializing the previous instruction must be done...
//			(Qupls4_pkg::SERIALIZE ? &pg_ren.pr[(nn + Qupls4_pkg::ROB_ENTRIES-1)%Qupls4_pkg::ROB_ENTRIES].done || !dbf[(nn + Qupls4_pkg::ROB_ENTRIES-1)%Qupls4_pkg::ROB_ENTRIES].v : TRUE) &&
			!dispatched[nn] &&
			!stall_dsp		
		) begin

			if (pg_ren.pr[nn].op.decbus.sau && !rob_dispatched_v[0] && !dispatched[nn] && kk < DISPATCH_COUNT) begin
				tLoadRse(0,nn,mm);
				// rse[0].funcunit = 4'd0; set to zero already above
				rse[0].rndx = tail[kk];
				rob_dispatched[0] = tail[kk];
				rob_dispatched_v[0] = VAL;
				dispatched[nn] = TRUE;
				kk = kk + 1;
			end
			else if (pg_ren.pr[nn].op.decbus.sau &&		// must be SAU instruction
				!pg_ren.pr[nn].op.decbus.sau0 &&				// can only be dispatched to sau #0
				!rob_dispatched_v[5] &&									// this slot is not already in use
				!dispatched[nn] &&											// this instruction has not been dispatched
				Qupls4_pkg::NSAU > 1 && kk < DISPATCH_COUNT) begin							// and there is an SAU available
				tLoadRse(kk,nn,mm);
				rse[5].funcunit = 4'd1;
				rse[5].rndx = tail[kk];
				rob_dispatched[5] = tail[kk];
				rob_dispatched_v[5] = VAL;
				dispatched[nn] = TRUE;
				kk = kk + 1;
			end
			// If trying to dispatch SAU instruction and no unit available
			else if (pg_ren.pr[nn].op.decbus.sau) begin
				stall = 1'b1;
			end

			if (pg_ren.pr[nn].op.decbus.mul && !rob_dispatched_v[1] && !dispatched[nn] && kk < DISPATCH_COUNT) begin
				tLoadRse(1,nn,mm);
				rse[1].funcunit = 4'd2;
				rse[1].rndx = tail[kk];
				rob_dispatched[1] = tail[kk];
				rob_dispatched_v[1] = VAL;
				dispatched[nn] = TRUE;
				kk = kk + 1;
			end
			else if (pg_ren.pr[nn].op.decbus.mul) begin
				stall = 1'b1;
			end

			if ((pg_ren.pr[nn].op.decbus.div|pg_ren.pr[nn].op.decbus.sqrt) && !rob_dispatched[1] && !dispatched[nn] && kk < DISPATCH_COUNT) begin
				tLoadRse(2,nn,mm);
				rse[1].funcunit = 4'd3;
				rse[1].rndx = tail[kk];
				rob_dispatched[1] = tail[kk];
				rob_dispatched_v[1] = VAL;
				dispatched[nn] = TRUE;
				kk = kk + 1;
			end
			else if (pg_ren.pr[nn].op.decbus.div|pg_ren.pr[nn].op.decbus.sqrt && kk < DISPATCH_COUNT) begin
				stall = 1'b1;
			end

			if (pg_ren.pr[nn].op.decbus.fc && !rob_dispatched[2] && !dispatched[nn] && kk < DISPATCH_COUNT) begin
				tLoadRse(2,nn,mm);
				rse[2].funcunit = 4'd7; 
				rse[2].rndx = tail[kk];
				rob_dispatched[2] = tail[kk];
				rob_dispatched_v[2] = VAL;
				dispatched[nn] = TRUE;
				kk = kk + 1;
			end
			else if (pg_ren.pr[nn].op.decbus.fc) begin
				stall = 1'b1;
			end

			if (pg_ren.pr[nn].op.decbus.mem && !rob_dispatched[3] && !dispatched[nn] && kk < DISPATCH_COUNT) begin
				tLoadRse(3,nn,mm);
				rse[3].funcunit = 4'd8; 
				rse[3].rndx = tail[kk];
				rob_dispatched[3] = tail[kk];
				rob_dispatched_v[3] = VAL;
				dispatched[nn] = TRUE;
				kk = kk + 1;
			end
			/*
			else if (pg_ren.pr[nn].op.decbus.mem && mem_cnt < 3'd2 && Qupls4_pkg::NDATA_PORTS > 1) begin
				tLoadRse(kk,nn,mm);
				rse[3].funcunit = 4'd9; 
				rse[3].rndx = pg_ren.pr[nn].this_ndx;
				rob_dispatched[3] = pg_ren.pr[nn].this_ndx;
				rob_dispatched_v[3] = VAL;
				mem_cnt = mem_cnt + 3'd1;
				kk = kk + 1;
			end
			*/
			else if (pg_ren.pr[nn].op.decbus.mem) begin
				stall = 1'b1;
			end

			if (Qupls4_pkg::SUPPORT_FLOAT && pg_ren.pr[nn].op.decbus.fma && !rob_dispatched[4] && !dispatched[nn] && Qupls4_pkg::NFMA>0 && kk < DISPATCH_COUNT) begin
				tLoadRse(kk,nn,mm);
				rse[4].funcunit = 4'd4; 
				rse[4].rndx = tail[kk];
				rob_dispatched[4] = tail[kk];
				rob_dispatched_v[4] = VAL;
				dispatched[nn] = TRUE;
				kk = kk + 1;
			end
			else if (pg_ren.pr[nn].op.decbus.fma) begin
				stall = 1'b1;
			end

			/*
			if (Qupls4_pkg::SUPPORT_FLOAT && pg_ren.pr[nn].op.decbus.fma && !rob_dispatched[4] && !dispatched[nn] && Qupls4_pkg::NFMA > 1) begin
				tLoadRse(4,nn,mm);
				rse[4].funcunit = 4'd5; 
				rse[4].rndx = tail[kk];
				rob_dispatched[4] = tail[kk];
				rob_dispatched_v[4] = VAL;
				fma_cnt = fma_cnt + 3'd1;
				kk = kk + 1;
			end
			else if (pg_ren.pr[nn].op.decbus.fma) begin
				stall = 1'b1;
			end
			*/
			if (Qupls4_pkg::SUPPORT_TRIG && pg_ren.pr[nn].op.decbus.trig && !rob_dispatched[4] && !dispatched[nn] && kk < DISPATCH_COUNT) begin
				tLoadRse(4,nn,mm);
				rse[4].funcunit = 4'd6; 
				rse[4].rndx = tail[kk];
				rob_dispatched[4] = tail[kk];
				rob_dispatched_v[4] = VAL;
				dispatched[nn] = TRUE;
				kk = kk + 1;
			end
			else if (pg_ren.pr[nn].op.decbus.trig) begin
				stall = 1'b1;
			end

			if (Qupls4_pkg::SUPPORT_FLOAT && pg_ren.pr[nn].op.decbus.fpu && !rob_dispatched[4] && !dispatched[nn] && Qupls4_pkg::NFPU > 0 && kk < DISPATCH_COUNT) begin
				tLoadRse(4,nn,mm);
				rse[4].funcunit = 4'd12;
				rse[4].rndx = tail[kk];
				rob_dispatched[4] = tail[kk];
				rob_dispatched_v[4] = VAL;
				dispatched[nn] = TRUE;
				kk = kk + 1;
			end
			else if (pg_ren.pr[nn].op.decbus.fpu) begin
				stall = 1'b1;
			end
		end
	end
end

always_ff @(posedge clk)
	if (ce)	rse_o <= rse;
always_ff @(posedge clk)
	if (ce) rob_dispatched_o <= rob_dispatched;
always_ff @(posedge clk)
	if (ce) rob_dispatched_v_o <= rob_dispatched_v;
always_ff @(posedge clk)
	if (ce) pg_dsp <= pg_ren;
always_ff @(posedge clk)
	if (rst)
		dispatch_done <= {MWIDTH{1'b0}};
	else begin
		if (stall)
			dispatch_done <= dispatched;
		else
			dispatch_done <= {MWIDTH{1'b0}};
	end
always_ff @(posedge clk)
	if (rst)
		jj <= 0;
	else begin
		if (stall)
			jj <= kk;
		else
			jj <= 0;
	end

task tLoadRse;
input integer kk;
input cpu_types_pkg::rob_ndx_t nn;
input [5:0] mm;
integer xx;
begin
	rse[kk] = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	rse[kk].v = !stomp[nn];
	rse[kk].om = pg_ren.pr[nn].om;
	rse[kk].rm = pg_ren.pr[nn].rm;
	rse[kk].pc.pc = pg_ren.hdr.ip + pg_ren.pr[nn].ip_offs;
	rse[kk].pc.stream = pg_ren.pr[nn].ip_stream;
	rse[kk].prc = pg_ren.pr[nn].op.decbus.prc;
	rse[kk].cndx = pgh.cndx;
	rse[kk].rndx = nn;
	rse[kk].irq_sn = pgh.irq_sn;
	rse[kk].aRd = pg_ren.pr[nn].op.uop.Rd;
	rse[kk].nRd = pg_ren.pr[nn].op.nRd;
	// mem specific
	rse[kk].virt2phys = pg_ren.pr[nn].op.decbus.v2p;
	rse[kk].load = pg_ren.pr[nn].op.decbus.load|pg_ren.pr[nn].op.decbus.loadz;
	rse[kk].store = pg_ren.pr[nn].op.decbus.store;
	rse[kk].amo = pg_ren.pr[nn].op.decbus.amo;
	// branch specific
	rse[kk].bt = pg_ren.pr[nn].bt;
	rse[kk].bcc = pg_ren.pr[nn].op.decbus.br;
	rse[kk].cjb = pg_ren.pr[nn].op.decbus.cjb;
	rse[kk].bsr = pg_ren.pr[nn].op.decbus.bsr;
	rse[kk].jsr = pg_ren.pr[nn].op.decbus.jsr;
	rse[kk].sys = pg_ren.pr[nn].op.decbus.sys;
	if (pg_ren.pr[nn].op.decbus.cpytgt|stomp[nn]|~pg_ren.pr[nn].pred_bit) begin
		rse[kk].uop = {41'd0,Qupls4_pkg::OP_NOP};
		rse[kk].store = FALSE;
		for (xx = 0; xx < 4; xx = xx + 1) begin
			rse[kk].arg[xx].v = VAL;
			rse[kk].arg[xx].aRnv = INV;
//					rse[kk].argH[xx].v = VAL;
		end
	end
	else begin
		rse[kk].uop = pg_ren.pr[nn].op.uop;
		rse[kk].store = pg_ren.pr[nn].op.decbus.store;
		rse[kk].rext = pg_ren.pr[nn].op.decbus.rext;
/*
		foreach (rse[kk].arg[xx]) begin
			rse[kk].arg[xx].v = pg_ren.pr[nn].oper[xx].v;
			rse[kk].arg[xx].aRnv = pg_ren.pr[nn].oper[xx].aRnv;
			rse[kk].arg[xx].aRn = pg_ren.pr[nn].oper[xx].aRn;
			rse[kk].arg[xx].pRn = pg_ren.pr[nn].oper[xx].pRn;
		end
*/	
//		rse[kk].arg[0].v = pg_ren.pr[nn].operandA.v;
		rse[kk].arg[0].v = pg_ren.pr[nn].argA_v;
		rse[kk].arg[1].v = pg_ren.pr[nn].argB_v;
		rse[kk].arg[2].v = pg_ren.pr[nn].argC_v;
		rse[kk].arg[3].v = pg_ren.pr[nn].argT_v;
		rse[kk].arg[4].v = pg_ren.pr[nn].argD_v;
		rse[kk].arg[5].v = pg_ren.pr[nn].argS_v;
		rse[kk].arg[6].v = pg_ren.pr[nn].argT2_v;
		rse[kk].arg[0].aRnv = pg_ren.pr[nn].op.uop.src[0];
		rse[kk].arg[1].aRnv = pg_ren.pr[nn].op.uop.src[1];
		rse[kk].arg[2].aRnv = pg_ren.pr[nn].op.uop.src[2];
		rse[kk].arg[3].aRnv = pg_ren.pr[nn].op.uop.src[3];
		rse[kk].arg[4].aRnv = pg_ren.pr[nn].op.uop.src[4];
		rse[kk].arg[5].aRnv = pg_ren.pr[nn].op.uop.src[5];
		rse[kk].arg[6].aRnv = pg_ren.pr[nn].op.uop.src[6];
		
		rse[kk].arg[0].aRn = pg_ren.pr[nn].op.uop.Rs1;
		rse[kk].arg[1].aRn = pg_ren.pr[nn].op.uop.Rs2;
		rse[kk].arg[2].aRn = pg_ren.pr[nn].op.uop.Rs3;
		rse[kk].arg[3].aRn = pg_ren.pr[nn].op.uop.Rd;
		rse[kk].arg[4].aRn = pg_ren.pr[nn].op.uop.Rs4;
		rse[kk].arg[5].aRn = 8'd33;
		rse[kk].arg[6].aRn = pg_ren.pr[nn].op.uop.Rd2;

		rse[kk].arg[0].pRn = pg_ren.pr[nn].op.pRs1;
		rse[kk].arg[1].pRn = pg_ren.pr[nn].op.pRs2;
		rse[kk].arg[2].pRn = pg_ren.pr[nn].op.pRs3;
		rse[kk].arg[3].pRn = pg_ren.pr[nn].op.pRd;
		rse[kk].arg[4].pRn = pg_ren.pr[nn].op.pRs4;
		rse[kk].arg[5].pRn = pg_ren.pr[nn].op.pS;
		rse[kk].arg[6].pRn = pg_ren.pr[nn].op.pRd2;
		
		/*
		rse[kk].argAh_v = !pg_ren.pr[nn].op.decbus.b128;
		rse[kk].argBh_v = !pg_ren.pr[nn].op.decbus.b128;
		rse[kk].argCh_v = !pg_ren.pr[nn].op.decbus.b128;
		*/
	end
	rse[kk].arg[3].aRnv = pg_ren.pr[nn].op.uop.src[3];
	rse[kk].arg[3].v = pg_ren.pr[nn].argT_v;
	/*
	if (!pg_ren.pr[nn].argAh_v) begin rse[kk].argAh[8:0] = pg_ren.pr[nn].op.pRs1; rse[kk].argA[23:16] = pg_ren.pr[nn].op.uop.Rs1; end
	if (!pg_ren.pr[nn].argBh_v) begin rse[kk].argBh[8:0] = pg_ren.pr[nn].op.pRs2; rse[kk].argB[23:16] = pg_ren.pr[nn].op.uop.Rs2; end
	if (!pg_ren.pr[nn].argCh_v) begin rse[kk].argCh[8:0] = pg_ren.pr[nn].op.pRs3; rse[kk].argC[23:16] = pg_ren.pr[nn].op.uop.Rs3; end
	if (!pg_ren.pr[nn].argDh_v) begin rse[kk].argDh[8:0] = pg_ren.pr[nn].op.pRd; rse[kk].argD[23:16] = pg_ren.pr[nn].op.uop.Rd; end
	*/
	rse[kk].argI = pg_ren.pr[nn].op.decbus.has_immb ? pg_ren.pr[nn].op.decbus.immb : pg_ren.pr[nn].op.decbus.immc;
//	rse[kk].funcunit = 4'd15;???
end
endtask

endmodule
