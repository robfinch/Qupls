// ============================================================================
//        __
//   \\__/ o\    (C) 2025-2026  Robert Finch, Waterloo
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

import const_pkg::*;
import Qupls4_pkg::*;

module Qupls4_set_dram_oper(rst_i, clk_i, cpu_dat_i, lsq_i, cndx_i,
	dram_more_i, dram_state_i, dram_ack_i, dram_work_i, dram_stomp_i, dram_oper_o);
parameter CORENO = 6'd1;
parameter LSQNO = 2'd0;
input rst_i;
input clk_i;
input [511:0] cpu_dat_i;
input Qupls4_pkg::lsq_entry_t lsq_i;
input checkpt_ndx_t cndx_i;
input dram_more_i;
input Qupls4_pkg::dram_state_t dram_state_i;
input dram_ack_i;
input dram_work_t dram_work_i;
input dram_stomp_i;
(* keep *)
output dram_oper_t dram_oper_o;


always_ff @(posedge clk_i)
if (rst_i) begin
	dram_oper_o <= {$bits(Qupls4_pkg::dram_oper_t){1'b0}};
	dram_oper_o.exc <= Qupls4_pkg::FLT_NONE;
	dram_oper_o.oper.aRnv <= FALSE;
end
else begin
	// grab requests that have finished and put them on the dram_bus
	// .hi runs the high half bus cycle for an unaligned access that does not cross a page boundary
	case(dram_state_i)
	Qupls4_pkg::DRAMSLOT_ACTIVE2:
		if (dram_ack_i && dram_work_i.hi && Qupls4_pkg::SUPPORT_UNALIGNED_MEMORY) begin
	    dram_oper_o.oper.v <= (dram_work_i.load|dram_work_i.cload|dram_work_i.cload_tags) & ~dram_stomp_i;
	    dram_oper_o.state <= 2'b11;
	    dram_oper_o.rndx <= dram_work_i.rndx;
	    dram_oper_o.oper.pRn <= dram_work_i.pRd;
	    dram_oper_o.oper.aRn <= dram_work_i.aRd;
	    dram_oper_o.oper.aRnv <= dram_work_i.aRdv;
	    dram_oper_o.om <= dram_work_i.om;
	    dram_oper_o.cndx <= dram_work_i.cndx;
	    dram_oper_o.rndx <= dram_work_i.rndx;
	    dram_oper_o.exc <= dram_work_i.exc;
	  	dram_oper_o.oper.val <= Qupls4_pkg::fnDati(1'b0,dram_work_i.op,(cpu_dat_i << {lsq_i.shift2,3'b0})|dram_oper_o.oper.val);
	  	dram_oper_o.oper.flags <= 8'h00;//dram_work_i.flags;
	    if (dram_work_i.store)
	    	$display("m[%h] <- %h", dram_work_i.vaddr, dram_work_i.data);
		end
	Qupls4_pkg::DRAMSLOT_ACTIVE:
		if (dram_ack_i) begin
			// If there is more to do, trigger a second instruction issue.
	    dram_oper_o.oper.v <= (dram_work_i.load|dram_work_i.cload|dram_work_i.cload_tags) & ~dram_more_i & ~dram_stomp_i;
	    dram_oper_o.state <= dram_more_i ? 2'b01 : 2'b11;
	    dram_oper_o.rndx <= dram_work_i.rndx;
	    dram_oper_o.oper.pRn <= dram_work_i.pRd;
	    dram_oper_o.oper.aRn <= dram_work_i.aRd;
	    dram_oper_o.oper.aRnv <= dram_work_i.aRdv;
	    dram_oper_o.om <= dram_work_i.om;
	    dram_oper_o.cndx <= dram_work_i.cndx;
	    dram_oper_o.exc <= dram_work_i.exc;
	    // Note shift gets switched for second bus cycle.
	    if (dram_oper_o.state==2'b01)
		  	dram_oper_o.oper.val <= Qupls4_pkg::fnDati(1'b0,dram_work_i.op,(cpu_dat_i << {lsq_i.shift2,3'b0})|dram_oper_o.oper.val);
	    else
	  		dram_oper_o.oper.val <= Qupls4_pkg::fnDati(dram_more_i,dram_work_i.op,cpu_dat_i >> {lsq_i.shift,3'b0});
	    if (dram_work_i.store)
	    	$display("m[%h] <- %h", dram_work_i.vaddr, dram_work_i.data);
		end
	Qupls4_pkg::DRAMSLOT_AVAIL:
		// If just performing a virtual to physical translation....
		// This is done only on port #0
		if (LSQNO==2'd0 && lsq_i.v2p && lsq_i.v) begin
			if (lsq_i.agen) begin
				dram_oper_o.oper.val <= lsq_i.padr;
				dram_oper_o.oper.flags <= 8'h00;//lsq_i.flags;
				dram_oper_o.oper.pRn <= lsq_i.Rt;
				dram_oper_o.oper.v <= VAL;
				dram_oper_o.om <= lsq_i.om;
				dram_oper_o.cndx <= cndx_i;
		    dram_oper_o.rndx <= lsq_i.rndx;
		    dram_oper_o.state <= 2'b11;
			end
		end
		// Has the a load already been done by store-to-load forwarding?
		else if (Qupls4_pkg::SUPPORT_STORE_FORWARDING && lsq_i.load && lsq_i.state==2'b11) begin
			dram_oper_o.oper.val <= Qupls4_pkg::fnDati(1'b0,dram_work_i.op,lsq_i.res);
			dram_oper_o.oper.flags <= 8'h00;//lsq_i.flags;
			dram_oper_o.oper.pRn <= lsq_i.Rt;
			dram_oper_o.oper.v <= lsq_i.v;
			dram_oper_o.om	<= lsq_i.om;
			dram_oper_o.cndx <= cndx_i;
	    dram_oper_o.rndx <= lsq_i.rndx;
	    dram_oper_o.state <= 2'b11;
		end
	  else
			dram_oper_o.oper.v <= INV;
	Qupls4_pkg::DRAMSLOT_DELAY,
	Qupls4_pkg::DRAMSLOT_DELAY2:
		dram_oper_o.oper.v <= INV;
	default:	;
	endcase
end

endmodule
