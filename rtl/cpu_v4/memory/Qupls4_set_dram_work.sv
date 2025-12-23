// ============================================================================
//        __
//   \\__/ o\    (C) 2025  Robert Finch, Waterloo
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
// 2300 LUTs / 1200 FFs
// ============================================================================

import const_pkg::*;
import Qupls4_pkg::*;

module Qupls4_set_dram_work(rst_i, clk_i, rob_i, stomp_i, vb_i, lsndxv_i,
	dram_state_i, dram_done_i, dram_more_i, dram_idv_i, dram_idv2_i, dram_ack_i,
	dram_stomp_i, cpu_dat_i, lsq_i, dram_oper_o, dram_work_o, page_cross_o
);
parameter CORENO = 6'd1;
parameter LSQNO = 2'd0;
input rst_i;
input clk_i;
input Qupls4_pkg::rob_entry_t [ROB_ENTRIES-1:0] rob_i;
input Qupls4_pkg::rob_bitmask_t stomp_i;
input vb_i;
input lsndxv_i;
input Qupls4_pkg::dram_state_t dram_state_i;
input dram_done_i;
input dram_more_i;
input dram_idv_i;
input dram_idv2_i;
input dram_ack_i;
input dram_stomp_i;
input [511:0] cpu_dat_i;
input Qupls4_pkg::lsq_entry_t lsq_i;
output dram_oper_t dram_oper_o;
output dram_work_t dram_work_o;
output page_cross_o;

cpu_types_pkg::virtual_address_t next_vaddr = {lsq_i.vadr[$bits(virtual_address_t)-1:6] + 2'd1,6'h0};
cpu_types_pkg::physical_address_t next_paddr = {lsq_i.padr[$bits(physical_address_t)-1:6] + 2'd1,6'h0};
// Compute and shift select lines into position.
wire [31:0] sel = Qupls4_pkg::fnSel(rob_i[lsq_i.rndx].op);
wire [79:0] selx = {64'd0,Qupls4_pkg::fnSel(rob_i[lsq_i.rndx].op)} << lsq_i.vadr[5:0];
assign page_cross_o = next_vaddr[$bits(virtual_address_t)-1:13] != lsq_i.vadr[$bits(virtual_address_t)-1:13] && |selx[79:64];

always_ff @(posedge clk_i)
if (rst_i) begin
	dram_oper_o <= {$bits(Qupls4_pkg::dram_oper_t){1'b0}};
	dram_work_o <= {$bits(Qupls4_pkg::dram_work_t){1'b0}};
	dram_oper_o.exc <= Qupls4_pkg::FLT_NONE;
	dram_oper_o.oper.aRnv <= FALSE;
end
else begin
	
	if (dram_done_i) begin
		dram_work_o.load <= FALSE;
		dram_work_o.loadz <= FALSE;
		dram_work_o.cload <= FALSE;
	end

	// Bus timeout logic.
	// If the memory access has taken too long, then it is retried. This applies
	// mainly to loads as stores will ack right away. Bit 8 of the counter is
	// used to indicate a retry so 256 clocks need to pass. Four retries are
	// allowed for by testing bit 10 of the counter. If the bus still has not
	// responded after 1024 clock cycles then a bus error exception is noted.

	if (Qupls4_pkg::SUPPORT_BUS_TO) begin
		// Increment timeout counters while memory access is taking place.
		if (dram_state_i==Qupls4_pkg::DRAMSLOT_ACTIVE || dram_state_i==Qupls4_pkg::DRAMSLOT_ACTIVE2)
			dram_work_o.tocnt <= dram_work_o.tocnt + 2'd1;

		// Bus timeout logic
		// Reset out to trigger another access
		if (dram_work_o.tocnt[10])
			dram_work_o.tocnt <= 12'd0;
	end

	// grab requests that have finished and put them on the dram_bus
	// .hi runs the high half bus cycle for an unaligned access that does not cross a page boundary
	case(dram_state_i)
	Qupls4_pkg::DRAMSLOT_ACTIVE2:
		if (dram_ack_i && dram_work_o.hi && Qupls4_pkg::SUPPORT_UNALIGNED_MEMORY) begin
			dram_work_o.hi <= 1'b0;
	    dram_oper_o.oper.v <= (dram_work_o.load|dram_work_o.cload|dram_work_o.cload_tags) & ~dram_stomp_i;
	    dram_oper_o.state <= 2'b11;
	    dram_oper_o.rndx <= dram_work_o.rndx;
	    dram_oper_o.oper.pRn <= dram_work_o.pRd;
	    dram_oper_o.oper.aRn <= dram_work_o.aRd;
	    dram_oper_o.oper.aRnv <= dram_work_o.aRdv;
	    dram_oper_o.om <= dram_work_o.om;
	    dram_oper_o.cndx <= dram_work_o.cndx;
	    dram_oper_o.rndx <= dram_work_o.rndx;
	    dram_oper_o.exc <= dram_work_o.exc;
	  	dram_oper_o.oper.val <= Qupls4_pkg::fnDati(1'b0,dram_work_o.op,(cpu_dat_i << {lsq_i.shift2,3'b0})|dram_oper_o.oper.val);
	  	dram_oper_o.oper.flags <= 8'h00;//dram_work_o.flags;
	    if (dram_work_o.store)
	    	$display("m[%h] <- %h", dram_work_o.vaddr, dram_work_o.data);
		end
	Qupls4_pkg::DRAMSLOT_ACTIVE:
		if (dram_state_i == Qupls4_pkg::DRAMSLOT_ACTIVE && dram_ack_i) begin
			// If there is more to do, trigger a second instruction issue.
	    dram_oper_o.oper.v <= (dram_work_o.load|dram_work_o.cload|dram_work_o.cload_tags) & ~dram_more_i & ~dram_stomp_i;
	    dram_oper_o.state <= dram_more_i ? 2'b01 : 2'b11;
	    dram_oper_o.rndx <= dram_work_o.rndx;
	    dram_oper_o.oper.pRn <= dram_work_o.pRd;
	    dram_oper_o.oper.aRn <= dram_work_o.aRd;
	    dram_oper_o.oper.aRnv <= dram_work_o.aRdv;
	    dram_oper_o.om <= dram_work_o.om;
	    dram_oper_o.cndx <= dram_work_o.cndx;
	    dram_oper_o.exc <= dram_work_o.exc;
	    // Note shift gets switched for second bus cycle.
	    if (dram_oper_o.state==2'b01)
		  	dram_oper_o.oper.val <= Qupls4_pkg::fnDati(1'b0,dram_work_o.op,(cpu_dat_i << {lsq_i.shift2,3'b0})|dram_oper_o.oper.val);
	    else
	  		dram_oper_o.oper.val <= Qupls4_pkg::fnDati(dram_more_i,dram_work_o.op,cpu_dat_i >> {lsq_i.shift,3'b0});
	    if (dram_work_o.store)
	    	$display("m[%h] <- %h", dram_work_o.vaddr, dram_work_o.data);
		end
	Qupls4_pkg::DRAMSLOT_AVAIL:
		dram_oper_o.oper.v <= INV;
	Qupls4_pkg::DRAMSLOT_DELAY,
	Qupls4_pkg::DRAMSLOT_DELAY2:
		dram_oper_o.oper.v <= INV;
	default:	;
	endcase

	// If just performing a virtual to physical translation....
	// This is done only on port #0
	if (LSQNO==2'd0 && lsq_i.v2p && lsq_i.v) begin
		if (lsq_i.agen) begin
			dram_oper_o.oper.val <= lsq_i.padr;
			dram_oper_o.oper.flags <= 8'h00;//lsq_i.flags;
			dram_oper_o.oper.pRn <= lsq_i.Rt;
			dram_oper_o.oper.v <= VAL;
			dram_oper_o.om <= lsq_i.om;
			dram_oper_o.cndx <= rob_i[lsq_i.rndx].cndx;
	    dram_oper_o.rndx <= lsq_i.rndx;
	    dram_oper_o.state <= 2'b11;
		end
	end
	else if (Qupls4_pkg::SUPPORT_LOAD_BYPASSING && vb_i) begin
		dram_oper_o.oper.val <= Qupls4_pkg::fnDati(1'b0,dram_work_o.op,lsq_i.res);
		dram_oper_o.oper.flags <= 8'h00;//lsq_i.flags;
		dram_oper_o.oper.pRn <= lsq_i.Rt;
		dram_oper_o.oper.v <= lsq_i.v;
		dram_oper_o.om	<= lsq_i.om;
		dram_oper_o.cndx <= rob_i[lsq_i.rndx].cndx;
    dram_oper_o.rndx <= lsq_i.rndx;
    dram_oper_o.state <= 2'b11;
	end
  else begin
  	case(dram_state_i)
  	Qupls4_pkg::DRAMSLOT_AVAIL:
  		if (lsndxv_i && !stomp_i[lsq_i.rndx] && !dram_idv_i && !dram_idv2_i) begin
				dram_work_o.exc <= Qupls4_pkg::FLT_NONE;
				dram_work_o.rndx <= lsq_i.rndx;
				dram_work_o.rndxv <= VAL;
				dram_work_o.om <= lsq_i.om;
//				dram_work_o.op <= lsq_i.op;
		//		dram0_ldip <= rob[lsq[mem0_lsndx.row][mem0_lsndx.col].rndx].excv;
				dram_work_o.pc <= lsq_i.pc;
				dram_work_o.load <= lsq_i.load;
				dram_work_o.vload <= lsq_i.vload;
				dram_work_o.vload_ndx <= lsq_i.vload_ndx;
				dram_work_o.loadz <= lsq_i.loadz;
				dram_work_o.cload <= lsq_i.cload;
				dram_work_o.cload_tags <= lsq_i.cload_tags;
				dram_work_o.store <= lsq_i.store;
				dram_work_o.stptr <= lsq_i.stptr;
				dram_work_o.vstore <= lsq_i.vstore;
				dram_work_o.vstore_ndx <= lsq_i.vstore_ndx;
				dram_work_o.cstore <= lsq_i.cstore;
				dram_work_o.erc <= rob_i[lsq_i.rndx].op.decbus.erc;
				dram_work_o.pRd	<= lsq_i.Rt;
				dram_work_o.aRd	<= lsq_i.aRt;
				dram_work_o.aRdv <= !lsq_i.aRtz;	// ToDo: fix
				dram_work_o.om <= lsq_i.om;
				dram_work_o.bank <= lsq_i.om==2'd0 ? 1'b0 : 1'b1;
				dram_work_o.cndx <= rob_i[lsq_i.rndx].cndx;
				dram_work_o.hi <= 1'b0;
				dram_work_o.vaddr <= lsq_i.vadr;	// bin recomputed.
				dram_work_o.paddr <= lsq_i.padr;
				// Did access cross page boundary?
				if (lsq_i.state==2'b01 && Qupls4_pkg::SUPPORT_UNALIGNED_MEMORY) begin
					dram_work_o.sel <= {64'd0,dram_work_o.selh[79:64]};
					dram_work_o.data <= lsq_i.res >> {lsq_i.shift2,3'b0};
				end
				else begin
					dram_work_o.sel <= {64'd0,sel} << lsq_i.shift;
					dram_work_o.selh <= {64'd0,sel} << lsq_i.shift;
					dram_work_o.vaddrh <= lsq_i.vadr;
					dram_work_o.paddrh <= lsq_i.padr;
					dram_work_o.data <= lsq_i.res << {lsq_i.shift,3'b0};
					dram_work_o.datah <= lsq_i.res << {lsq_i.shift,3'b0};
					dram_work_o.ctag <= 8'h00;//lsq_i.flags.cap;
				end
				dram_work_o.memsz <= Qupls4_pkg::fnMemsz(rob_i[lsq_i.rndx].op);
				dram_work_o.tid.core <= CORENO;
				dram_work_o.tid.channel <= 3'd1;
				dram_work_o.tid.tranid <= dram_work_o.tid.tranid + 2'd1;
		    dram_work_o.tocnt <= 12'd0;
		  end
		Qupls4_pkg::DRAMSLOT_DELAY:
			if (dram_more_i && !page_cross_o && Qupls4_pkg::SUPPORT_UNALIGNED_MEMORY) begin
				dram_work_o.hi <= 1'b1;
				dram_work_o.sel <= {64'd0,dram_work_o.selh[79:64]};
				dram_work_o.vaddr <= next_vaddr;
				dram_work_o.paddr <= next_paddr;
				dram_work_o.data <= lsq_i.res >> {lsq_i.shift2,3'b0};
				// Cross page boundary?
	//			if (page_cross)
	//				dram_work_o.exc <= Qupls4_pkg::FLT_ALN;
			end
			else begin
				dram_work_o.store <= 1'b0;
				dram_work_o.sel <= 80'h0;
			end
		// End of second bus cycle, nothing to do.
		Qupls4_pkg::DRAMSLOT_DELAY2:
			begin
				dram_work_o.store <= 1'b0;
				dram_work_o.sel <= 80'h0;
			end
		Qupls4_pkg::DRAMSLOT_ACTIVE:	;
		Qupls4_pkg::DRAMSLOT_ACTIVE2:	;
		default:	;
		endcase
  end
end

endmodule
