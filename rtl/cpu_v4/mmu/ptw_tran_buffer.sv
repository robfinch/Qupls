// ============================================================================
//        __
//   \\__/ o\    (C) 2024-2025  Robert Finch, Waterloo
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
// 300 LUTs / 4400 FFs
// ============================================================================

import const_pkg::*;
import fta_bus_pkg::*;
import mmu_pkg::*;
import cpu_types_pkg::*;
import QuplsPkg::*;
import ptable_walker_pkg::*;

module ptw_tran_buffer(rst, clk, ptattr, state, access_state, ptw_vv, ptw_pv, ptw_ppv, tranbuf,
	miss_queue, sel_tran, sel_qe, ftam_resp, ftam_resp_ack, tid, ptw_vadr, ptw_padr);
parameter CORENO = 6'd1;
parameter CID = 3'd4;
input rst;
input clk;
input ptattr_t ptattr;
input ptable_walker_pkg::ptw_state_t state;
input ptw_access_state_t access_state;
input ptw_vv;
input ptw_pv;
input ptw_ppv;
output ptw_tran_buf_t [15:0] tranbuf;
input ptw_miss_queue_t [MISSQ_SIZE-1:0] miss_queue;
input [5:0] sel_tran;
input [5:0] sel_qe;
input fta_cmd_response256_t ftam_resp;
input ftam_resp_ack;
output fta_tranid_t tid;
input virtual_address_t ptw_vadr;
input physical_address_t ptw_padr;

integer nn;

always_ff @(posedge clk)
if (rst) begin
	tid.core <= CORENO;
	tid.channel <= CID;
	tid.tranid <= 4'd1;
	for (nn = 0; nn < 16; nn = nn + 1)
		tranbuf[nn] <= {$bits(ptw_tran_buf_t){1'b0}};
end
else begin

	case(access_state)
	INACTIVE:	;
	SEG_BASE_FETCH:
		tAssignTranbuf(5'd16,16'd0,access_state,ptw_vadr,ptw_padr);
	SEG_LIMIT_FETCH:
		if (!ftam_resp.rty)
			tAssignTranbuf(5'd16,16'd0,access_state,ptw_vadr,ptw_padr);
	TLB_PTE_FETCH:
		if (~sel_qe[5] & ptw_pv & ptw_ppv) begin
			if (miss_queue[sel_qe].lvl != 3'd0)
				tAssignTranbuf(sel_qe[4:0], miss_queue[sel_qe].asid,access_state,ptw_vadr,ptw_padr);
		end
	/*
	TLB_PMT_FETCH:
		if (!sel_qe[5] && !ftam_resp.rty) begin
			if (miss_queue[sel_qe].lvl != 3'd7)
				tAssignTranbuf(miss_queue[sel_qe].asid);
		end
	*/				
	endcase

	// Capture responses.
	// a tid of zero is not valid, and the tran should not be marked ready.
	// The tran coming back should match the one in the tran buffer.
	if (ftam_resp_ack & |(ftam_resp.tid & 15)) begin
		if (ftam_resp.tid==tranbuf[ftam_resp.tid & 15].tid) begin
			tranbuf[ftam_resp.tid & 15].dat <= ftam_resp.dat;
			tranbuf[ftam_resp.tid & 15].rdy <= 1'b1;
			case(tranbuf[ftam_resp.tid & 15].access_state)
			INACTIVE:	;
			SEG_BASE_FETCH:
				;
			SEG_LIMIT_FETCH:
				;
			TLB_PTE_FETCH:
				case(ptattr.pte_size)
				_4B_PTE:	tranbuf[ftam_resp.tid & 15].pte <= ftam_resp.dat >> {tranbuf[ftam_resp.tid & 15].padr[4:2],5'b0};
				_8B_PTE:	tranbuf[ftam_resp.tid & 15].pte <= ftam_resp.dat >> {tranbuf[ftam_resp.tid & 15].padr[4:3],6'b0};
				_16B_PTE:	tranbuf[ftam_resp.tid & 15].pte <= ftam_resp.dat >> {tranbuf[ftam_resp.tid & 15].padr[4],7'b0};
				default:	;
				endcase
//			TLB_PMT_FETCH:
//				;
			endcase
		end
	end

	// Search for ready translations and update the TLB.
	if (~sel_tran[5]) begin
		tranbuf[sel_tran].v <= 1'b0;
		tranbuf[sel_tran].rdy <= 1'b0;
	end
end

task tAssignTranbuf;
input [4:0] mqndx;
input asid_t asid;
input ptw_access_state_t access_state;
input virtual_address_t ptw_vadr;
input physical_address_t ptw_padr;
begin
	tranbuf[tid & 15].mqndx <= mqndx;
	tranbuf[tid & 15].v <= 1'b1;
	tranbuf[tid & 15].tid <= tid;
	tranbuf[tid & 15].rdy <= 1'b0;
	tranbuf[tid & 15].asid <= asid;
	tranbuf[tid & 15].vadr <= ptw_vadr;
	tranbuf[tid & 15].padr <= ptw_padr;
	tranbuf[tid & 15].access_state <= access_state;
	tid.tranid <= tid.tranid + 2'd1;
	if (&tid.tranid)
		tid.tranid <= 4'd1;
end
endtask

endmodule
