// ============================================================================
//        __
//   \\__/ o\    (C) 2025  Robert Finch, Waterloo
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
// ============================================================================
//
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_lsq(rst, clk, cmd, pgh, rob, lsq);
parameter MWIDTH = Qupls4_pkg::MWIDTH;
parameter CMD_NONE = 3'd0;
parameter CMD_INV = 3'd1;
parameter CMD_ENQ = 3'd2;
parameter CMD_SETADR = 3'd3;
input rst;
input clk;
input lsq_cmd_t [7:0] cmd;
input Qupls4_pkg::pipeline_group_hdr_t [Qupls4_pkg::ROB_ENTRIES/MWIDTH-1:0] pgh;
input Qupls4_pkg::rob_entry_t [Qupls4_pkg::ROB_ENTRIES-1:0] rob;
output Qupls4_pkg::lsq_entry_t [1:0] lsq [0:Qupls4_pkg::LSQ_ENTRIES-1];

integer n;

always_ff @(posedge clk)
begin
	foreach (cmd[n]) begin
		case(cmd[n].cmd)
		CMD_INV:	tInvalidateLSQ(cmd[n].rndx, cmd[n].can, cmd[n].cmt, cmd[n].data);
		CMD_ENQ:	tEnqueLSE(cmd[n].n==2'd1 ? 7'h7F : 7'h7E,cmd[n].lndx,cmd[n].rndx,rob[cmd[n].rndx],cmd[n].n,cmd[n].data);
		CMD_SETADR:	tSetLSQ(cmd[n].rndx,cmd[n].data);
		CMD_INCADR: tIncLSQAddr(cmd[n].rndx);
		CMD_SETRES:
			begin
				lsq[cmd[n].lndx.row][cmd[n].lndx.col].res <= {cmd[n].flags,cmd[n].data};
				lsq[cmd[n].lndx.row][cmd[n].lndx.col].datav <= cmd[n].datav;
			end
		default:	;
		endcase
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
begin
	lsq[ndx.row][ndx.col] <= {$bits(Qupls4_pkg::lsq_entry_t){1'b0}};
	lsq[ndx.row][ndx.col].rndx <= id;
	lsq[ndx.row][ndx.col].v <= VAL;
	lsq[ndx.row][ndx.col].state <= 2'b00;
	lsq[ndx.row][ndx.col].agen <= FALSE;
	lsq[ndx.row][ndx.col].pc <= pgh[rob.pghn].ip + {rob.ip_offs,1'b0};
	lsq[ndx.row][ndx.col].loadv <= INV;
	lsq[ndx.row][ndx.col].load <= rob.op.decbus.load|rob.excv;
	lsq[ndx.row][ndx.col].loadz <= rob.op.decbus.loadz|rob.excv;
	lsq[ndx.row][ndx.col].cload <= rob.excv;
	lsq[ndx.row][ndx.col].cload_tags <= rob.excv;
	lsq[ndx.row][ndx.col].store <= rob.op.decbus.store;
	lsq[ndx.row][ndx.col].stptr <= rob.op.decbus.stptr;
	lsq[ndx.row][ndx.col].cstore <= 1'b0;
	lsq[ndx.row][ndx.col].vload <= rob.op.decbus.vload;
	lsq[ndx.row][ndx.col].vload_ndx <= rob.op.decbus.vload_ndx;
	lsq[ndx.row][ndx.col].vstore <= rob.op.decbus.vstore;
	lsq[ndx.row][ndx.col].vstore_ndx <= rob.op.decbus.vstore_ndx;
	lsq[ndx.row][ndx.col].vadr <= vadr;
	lsq[ndx.row][ndx.col].padr <= {$bits(cpu_types_pkg::physical_address_t){1'b0}};
	lsq[ndx.row][ndx.col].shift <= 7'd0;
//	store_argC_reg <= rob.pRc;
	lsq[ndx.row][ndx.col].aRc <= rob.op.decbus.Rs3;
//	lsq[ndx.row][ndx.col].pRc <= rob.op.pRs3;
	lsq[ndx.row][ndx.col].cndx <= rob.cndx;
	lsq[ndx.row][ndx.col].Rt <= rob.op.nRd;
	lsq[ndx.row][ndx.col].aRt <= rob.op.decbus.Rd;
	lsq[ndx.row][ndx.col].aRtz <= !rob.op.decbus.Rdv;
	lsq[ndx.row][ndx.col].om <= rob.om;
	lsq[ndx.row][ndx.col].memsz <= Qupls4_pkg::fnMemsz(rob.op);
	for (n12r = 0; n12r < Qupls4_pkg::LSQ_ENTRIES; n12r = n12r + 1)
		for (n12c = 0; n12c < 2; n12c = n12c + 1)
			lsq[n12r][n12c].sn <= lsq[n12r][n12c].sn - n;
	lsq[ndx.row][ndx.col].sn <= sn;
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
integer n18r, n18c, n18b;
begin
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
				/*
				if (dram0_work.rndx==lsq[n18r][n18c].rndx)
					dram0_stomp <= TRUE;
				if (Qupls4_pkg::NDATA_PORTS > 1 && dram0_work.rndx==lsq[n18r][n18c].rndx)
					dram1_stomp <= TRUE;
				if (can[n18b])
					cpu_request_cancel[lsq[n18r][n18c].rndx] <= 1'b1;
				*/
			end
		end
	end
end
endtask


// Increment LSQ virtual address to next page and trigger agen again.

task tIncLSQAddr;
input rob_ndx_t id;
integer n18r, n18c;
begin
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
end
endtask


endmodule
