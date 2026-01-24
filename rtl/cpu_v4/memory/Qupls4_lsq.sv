// ============================================================================
//        __
//   \\__/ o\    (C) 2025-2026  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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
// 11200 LUTs / 4250 FFs / 225 MHz (no store forwarding)                                                                          
// ============================================================================
//
import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_lsq(rst, clk, cmd, pgh, rob, lsq, lsq_tail);
parameter MWIDTH = Qupls4_pkg::MWIDTH;
input rst;
input clk;
input lsq_cmd_t [14:0] cmd;
input Qupls4_pkg::pipeline_group_hdr_t [Qupls4_pkg::ROB_ENTRIES/MWIDTH-1:0] pgh;
input Qupls4_pkg::rob_entry_t [Qupls4_pkg::ROB_ENTRIES-1:0] rob;
(* keep *)
output Qupls4_pkg::lsq_entry_t [1:0] lsq [0:Qupls4_pkg::LSQ_ENTRIES-1];
output Qupls4_pkg::lsq_ndx_t lsq_tail;

integer n;
integer n14r, n14c, n1r, n1c;

initial begin
	for (n1r = 0; n1r < Qupls4_pkg::LSQ_ENTRIES; n1r = n1r + 1)
		for (n1c = 0; n1c < 2; n1c = n1c + 1)
			lsq[n1r][n1c] = {$bits(lsq_entry_t){1'b0}};
end

always_ff @(posedge clk)
if (rst) begin
	lsq_tail <= {$bits(Qupls4_pkg::lsq_ndx_t){1'b0}};
	for (n14r = 0; n14r < Qupls4_pkg::LSQ_ENTRIES; n14r = n14r + 1) begin
		for (n14c = 0; n14c < Qupls4_pkg::NDATA_PORTS; n14c = n14c + 1) begin
			lsq[n14r][n14c] <= {$bits(Qupls4_pkg::lsq_entry_t){1'd0}};
		end
	end
end
else begin
	if (cmd[0]!=Qupls4_pkg::LSQ_CMD_NONE)	//LSQ_CMD_ENQ
		begin
		 	tEnqueLSE(
		 		.sn(7'h7F),
		 		.ndx(cmd[0].lndx),
		 		.id(cmd[0].rndx),
		 		.rob(rob[cmd[0].rndx]),
		 		.n(cmd[0].n),
		 		.vadr(cmd[0].data)
		 	);
			lsq_tail.row <= (lsq_tail.row + 2'd1) % Qupls4_pkg::LSQ_ENTRIES;
			lsq_tail.col <= 3'd0;
		end
	if (cmd[1]!=Qupls4_pkg::LSQ_CMD_NONE)	//==LSQ_CMD_ENQ) begin
		 	tEnqueLSE(
		 		.sn(7'h7F),
		 		.ndx(cmd[1].lndx),
		 		.id(cmd[1].rndx),
		 		.rob(rob[cmd[1].rndx]),
		 		.n(cmd[1].n),
		 		.vadr(cmd[1].data)
		 	);
//		tEnqueLSE(7'h7F,cmd[1].lndx,cmd[1].rndx,rob[cmd[1].rndx],cmd[1].n,cmd[1].data);
	if (cmd[2]!=Qupls4_pkg::LSQ_CMD_NONE)	// SETRES
			begin
				lsq[cmd[2].lndx.row][cmd[2].lndx.col].res <= {cmd[2].flags,cmd[2].data};
				lsq[cmd[2].lndx.row][cmd[2].lndx.col].datav <= cmd[2].datav;
			end
	if (cmd[3]!=Qupls4_pkg::LSQ_CMD_NONE)	// SETRES
			begin
				lsq[cmd[3].lndx.row][cmd[3].lndx.col].res <= {cmd[3].flags,cmd[3].data};
				lsq[cmd[3].lndx.row][cmd[3].lndx.col].datav <= cmd[3].datav;
			end
	if (cmd[4]!=Qupls4_pkg::LSQ_CMD_NONE)	// SETADR
		tSetLSQ(cmd[4].rndx,cmd[4].data);
	if (cmd[5]!=Qupls4_pkg::LSQ_CMD_NONE)	// SETADR
		tSetLSQ(cmd[5].rndx,cmd[5].data);
	if (cmd[6]!=Qupls4_pkg::LSQ_CMD_NONE)	// INCADR
		tIncLSQAddr(cmd[6].rndx);
	if (cmd[7]!=Qupls4_pkg::LSQ_CMD_NONE)	// INCADR
		tIncLSQAddr(cmd[7].rndx);
	if (cmd[8]!=Qupls4_pkg::LSQ_CMD_NONE)
		begin
			tInvalidateLSQ(cmd[8].rndx, cmd[8].can, cmd[8].cmt, cmd[8].data);
			if (cmd[8].cmt && SUPPORT_STORE_FORWARDING)
				tForwardStore(cmd[8].rndx);
		end
	if (cmd[9]!=Qupls4_pkg::LSQ_CMD_NONE)
		begin
			tInvalidateLSQ(cmd[9].rndx, cmd[9].can, cmd[9].cmt, cmd[9].data);
			if (cmd[9].cmt && SUPPORT_STORE_FORWARDING)
				tForwardStore(cmd[9].rndx);
		end
	if (cmd[10]!=Qupls4_pkg::LSQ_CMD_NONE)
		begin
			tInvalidateLSQ(cmd[10].rndx, cmd[10].can, cmd[10].cmt, cmd[10].data);
			if (cmd[10].cmt && SUPPORT_STORE_FORWARDING)
				tForwardStore(cmd[10].rndx);
		end
	if (cmd[11]!=Qupls4_pkg::LSQ_CMD_NONE)
		begin
			tInvalidateLSQ(cmd[11].rndx, cmd[11].can, cmd[11].cmt, cmd[11].data);
			if (cmd[11].cmt && SUPPORT_STORE_FORWARDING)
				tForwardStore(cmd[11].rndx);
		end
	if (cmd[12]!=Qupls4_pkg::LSQ_CMD_NONE)
		begin
			tInvalidateLSQ(cmd[12].rndx, cmd[12].can, cmd[12].cmt, cmd[12].data);
			if (cmd[12].cmt && SUPPORT_STORE_FORWARDING)
				tForwardStore(cmd[12].rndx);
		end
	if (cmd[13]!=Qupls4_pkg::LSQ_CMD_NONE)
		begin
			tInvalidateLSQ(cmd[13].rndx, cmd[13].can, cmd[13].cmt, cmd[13].data);
			if (cmd[13].cmt && SUPPORT_STORE_FORWARDING)
				tForwardStore(cmd[13].rndx);
		end
	if (cmd[14]!=Qupls4_pkg::LSQ_CMD_NONE)
		begin
			tInvalidateLSQ(cmd[14].rndx, cmd[14].can, cmd[14].cmt, cmd[14].data);
			if (cmd[14].cmt && SUPPORT_STORE_FORWARDING)
				tForwardStore(cmd[14].rndx);
		end
end

// Queue to the load / store queue.

task tEnqueLSE;
input seqnum_t sn;
input Qupls4_pkg::lsq_ndx_t ndx;
input rob_ndx_t id;
input Qupls4_pkg::rob_entry_t rob;
input [1:0] n;
input cpu_types_pkg::virtual_address_t vadr;
integer n12r, n12c;
integer n13r, n13c;
begin
	n12r = ndx.row;
	n12c = ndx.col;
	lsq[n12r][n12c] <= {$bits(Qupls4_pkg::lsq_entry_t){1'b0}};
	lsq[n12r][n12c].rndx <= id;
	lsq[n12r][n12c].v <= VAL;
	lsq[n12r][n12c].state <= 2'b00;
	lsq[n12r][n12c].agen <= FALSE;
	lsq[n12r][n12c].pc <= pgh[rob.pghn].ip + {rob.ip_offs,1'b0};
	lsq[n12r][n12c].loadv <= INV;
	lsq[n12r][n12c].load <= rob.op.decbus.load|rob.excv;
	lsq[n12r][n12c].loadz <= rob.op.decbus.loadz|rob.excv;
	lsq[n12r][n12c].cload <= rob.excv;
	lsq[n12r][n12c].cload_tags <= rob.excv;
	lsq[n12r][n12c].store <= rob.op.decbus.store;
	lsq[n12r][n12c].stptr <= rob.op.decbus.stptr;
	lsq[n12r][n12c].cstore <= 1'b0;
	lsq[n12r][n12c].vload <= rob.op.decbus.vload;
	lsq[n12r][n12c].vload_ndx <= rob.op.decbus.vload_ndx;
	lsq[n12r][n12c].vstore <= rob.op.decbus.vstore;
	lsq[n12r][n12c].vstore_ndx <= rob.op.decbus.vstore_ndx;
	lsq[n12r][n12c].vadr <= vadr;
	lsq[n12r][n12c].padr <= {$bits(cpu_types_pkg::physical_address_t){1'b0}};
	lsq[n12r][n12c].shift <= 7'd0;
//	store_argC_reg <= rob.pRc;
	lsq[n12r][n12c].aRc <= rob.op.decbus.Rs3;
	lsq[n12r][n12c].pRc <= rob.op.pRs3;
	lsq[n12r][n12c].cndx <= rob.cndx;
	lsq[n12r][n12c].Rt <= rob.op.nRd;
	lsq[n12r][n12c].aRt <= rob.op.decbus.Rd;
	lsq[n12r][n12c].aRtz <= !rob.op.decbus.Rdv;
	lsq[n12r][n12c].om <= rob.om;
	lsq[n12r][n12c].memsz <= Qupls4_pkg::fnMemsz(rob.op);
	for (n13r = 0; n13r < Qupls4_pkg::LSQ_ENTRIES; n13r = n13r + 1)
		for (n13c = 0; n13c < 2; n13c = n13c + 1)
			lsq[n13r][n13c].sn <= lsq[n13r][n13c].sn - n;
	lsq[n12r][n12c].sn <= sn;
	if (n==2'd2)
		lsq[n12r][n12c].sn <= sn - 2'd1;
	/*
	if (Qupls4_pkg::PERFORMANCE) begin
		// This seems not to work
		if (agen0_argC_v) begin
			lsq[ndx.row][ndx.col].res <= {agen0_argC_flags,agen0_argC};
			lsq[ndx.row][ndx.col].flags <= agen0_argC_flags;
			lsq[ndx.row][ndx.col].datav <= VAL;
		end
	end
	*/
end
endtask

// Update the address fields in the LSQ entries.
// Invoked once the address has been translated.

task tSetLSQ;
input rob_ndx_t id;
input address_t padr;
integer n18r, n18c;
begin
	n18r = rob[id].lsqndx.row;
	n18c = rob[id].lsqndx.col;
	lsq[n18r][n18c].agen <= TRUE;
	lsq[n18r][n18c].padr <= padr;
	case(lsq[n18r][n18c].state)
	2'b00:	
		begin
			lsq[n18r][n18c].shift <= padr[5:0];
			lsq[n18r][n18c].shift2 <= 7'd64 - padr[5:0];
		end
	default:	;
	endcase	
/*	
	for (n18r = 0; n18r < Qupls4_pkg::LSQ_ENTRIES; n18r = n18r + 1) begin
		for (n18c = 0; n18c < 2; n18c = n18c + 1) begin
			if (lsq[n18r][n18c].rndx==id && lsq[n18r][n18c].v) begin
				lsq[n18r][n18c].agen <= TRUE;
				lsq[n18r][n18c].padr <= padr;//{tlbe.pte.ppn,adr[12:0]};
				case(lsq[n18r][n18c].state)
				2'b00:	
					begin
						lsq[n18r][n18c].shift <= padr[5:0];
						lsq[n18r][n18c].shift2 <= 7'd64 - padr[5:0];
					end
				default:	;
				endcase	
			end
		end
	end
*/
end
endtask

// Invalidate LSQ entries associated with a ROB entry. This searches the LSQ
// which is small in case multiple LSQ entries are associated. This is an
// issue in the core's current operation.
// Note that only valid entries are invalidated as invalid entries may be
// about to be used by enqueue logic.

task tInvalidateLSQ;
input rob_ndx_t id;
input can;
input cmt;
input value_t data;
integer n18r, n18c;
begin
	n18r = rob[id].lsqndx.row;
	n18c = rob[id].lsqndx.col;
	if (cmt)
		lsq[n18r][n18c].v <= INV;
	lsq[n18r][n18c].state <= 2'b00;
	lsq[n18r][n18c].agen <= FALSE;
	lsq[n18r][n18c].datav <= INV;
	lsq[n18r][n18c].store <= FALSE;
	lsq[n18r][n18c].vstore <= FALSE;
	lsq[n18r][n18c].vstore_ndx <= FALSE;
	lsq[n18r][n18c].load <= FALSE;
	lsq[n18r][n18c].vload <= FALSE;
	lsq[n18r][n18c].vload_ndx <= FALSE;
	// If it was a load, then cache the data in the LSQ
	if (!cmt & !rob[lsq[n18r][n18c].rndx].excv)
		case(lsq[n18r][n18c].memsz)
		Qupls4_pkg::byt,Qupls4_pkg::wyde,Qupls4_pkg::tetra,Qupls4_pkg::octa:
			if (lsq[n18r][n18c].load)
				lsq[n18r][n18c].loadv <= VAL;
			else
				lsq[n18r][n18c].loadv <= INV;
		default:	lsq[n18r][n18c].loadv <= INV;
		endcase
	else
		lsq[n18r][n18c].loadv <= INV;
	lsq[n18r][n18c].res <= data;

	/*	
	for (n18r = 0; n18r < Qupls4_pkg::LSQ_ENTRIES; n18r = n18r + 1) begin
		for (n18c = 0; n18c < 2; n18c = n18c + 1) begin
			if (lsq[n18r][n18c].rndx==id[n18b] && lsq[n18r][n18c].v==VAL) begin
				lsq[n18r][n18c].v <= INV;
				lsq[n18r][n18c].state <= 2'b00;
				lsq[n18r][n18c].agen <= FALSE;
				lsq[n18r][n18c].datav <= INV;
				lsq[n18r][n18c].store <= FALSE;
				lsq[n18r][n18c].vstore <= FALSE;
				lsq[n18r][n18c].vstore_ndx <= FALSE;
				lsq[n18r][n18c].load <= FALSE;
				lsq[n18r][n18c].vload <= FALSE;
				lsq[n18r][n18c].vload_ndx <= FALSE;
				// If it was a load, then cache the data in the LSQ
				if (!cmt & !rob[lsq[n18r][n18c].rndx].excv)
					case(lsq[n18r][n18c].memsz)
					Qupls4_pkg::byt,Qupls4_pkg::wyde,Qupls4_pkg::tetra,Qupls4_pkg::octa:
						if (lsq[n18r][n18c].load)
							lsq[n18r][n18c].loadv <= VAL;
						else
							lsq[n18r][n18c].loadv <= INV;
					default:	lsq[n18r][n18c].loadv <= INV;
					endcase
				else
					lsq[n18r][n18c].loadv <= INV;
				lsq[n18r][n18c].res <= data[n18b];
				// It is possible that a load operation already in progress got
				// cancelled.
				*/
				/*
				if (dram0_work.rndx==lsq[n18r][n18c].rndx)
					dram0_stomp <= TRUE;
				if (Qupls4_pkg::NDATA_PORTS > 1 && dram0_work.rndx==lsq[n18r][n18c].rndx)
					dram1_stomp <= TRUE;
				if (can[n18b])
					cpu_request_cancel[lsq[n18r][n18c].rndx] <= 1'b1;
				*/
				/*
			end
		end
	end
	*/
end
endtask


// Increment LSQ virtual address to next page and trigger agen again.

task tIncLSQAddr;
input rob_ndx_t id;
integer n18r, n18c;
begin
	n18r = rob[id].lsqndx.row;
	n18c = rob[id].lsqndx.col;
	lsq[n18r][n18c].agen <= FALSE;	// cause agen again
	lsq[n18r][n18c].vadr <= {lsq[n18r][n18c].vadr[$bits(virtual_address_t)-1:6]+2'd1,6'd0};
	lsq[n18r][n18c].state <= 2'b01;
/*	
	for (n18r = 0; n18r < Qupls4_pkg::LSQ_ENTRIES; n18r = n18r + 1) begin
		for (n18c = 0; n18c < 2; n18c = n18c + 1) begin
			if (lsq[n18r][n18c].rndx==id && lsq[n18r][n18c].v==VAL) begin
				lsq[n18r][n18c].agen <= FALSE;	// cause agen again
				lsq[n18r][n18c].vadr <= {lsq[n18r][n18c].vadr[$bits(virtual_address_t)-1:6]+2'd1,6'd0};
				lsq[n18r][n18c].state <= 2'b01;
//				lsq[n18r][n18c].shift <= lsq[n18r][n18c].shift2;
			end
		end
	end
*/
end
endtask

// When a store commits, search the LSQ for corresponding loads, and forward
// the store value. The load must be valid and come after the store. It must
// have the same size data and the same address.

task tForwardStore;
input rob_ndx_t id;
integer n17r, n17c;
integer n18r, n18c;
lsq_ndx_t sid;
seqnum_t ssn;
reg dis;
begin
	n18r = rob[id].lsqndx.row;
	n18c = rob[id].lsqndx.col;
	ssn = 0;
	sid.row = 0;
	sid.col = 0;
	dis = FALSE;
	if (lsq[n18r][n18c].store) begin
		// Find the store closest to the load that has the same memory size
		// and address.
		for (n17r = 0; n17r < Qupls4_pkg::LSQ_ENTRIES; n17r = n17r + 1) begin
			for (n17c = 0; n17c < 2; n17c = n17c + 1) begin
				// If there is a load or a store in the same address range coming
				// after the store commnitted.
				if (
					lsq[n17r][n17c].v==VAL &&
					lsq[n17r][n17c].sn > lsq[n18r][n18c].sn &&
					((lsq[n17r][n17c].padr[$bits(cpu_types_pkg::physical_address_t)-1:4] == lsq[n18r][n18c].padr[$bits(cpu_types_pkg::physical_address_t)-1:4]) || !lsq[n17r][n17c].agen)
				)
				begin
					// If another later store was found in the same address range, then
					// we do not want to forward yet, disable. The later store will 
					// update the loads.
					if (lsq[n17r][n17c].store)
						dis = TRUE;
					// Else if we found a load, ensure the operation size is the same.
					else if (lsq[n17r][n17c].load) begin
						if (lsq[n17r][n17c].memsz != lsq[n18r][n18c].memsz)
							dis = TRUE;
					end
				end
			end
		end
		for (n17r = 0; n17r < Qupls4_pkg::LSQ_ENTRIES; n17r = n17r + 1) begin
			for (n17c = 0; n17c < 2; n17c = n17c + 1) begin
				// Forward to the load(s) if criteria met.
				if (
				 	!dis &&
					lsq[n17r][n17c].v==VAL &&
					lsq[n17r][n17c].load &&
					lsq[n17r][n17c].sn > lsq[n18r][n18c].sn &&
					lsq[n17r][n17c].padr == lsq[n18r][n18c].padr
				)
				begin
					lsq[n17r][n17c].res <= lsq[sid.row][sid.col].res;
					lsq[n17r][n17c].state <= 2'b11;
				end
			end
		end
	end
end
endtask

endmodule
