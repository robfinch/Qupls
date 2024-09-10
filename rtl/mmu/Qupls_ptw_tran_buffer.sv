// ============================================================================
//        __
//   \\__/ o\    (C) 2024  Robert Finch, Waterloo
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
import fta_bus_pkg::*;
import QuplsMmupkg::*;
import QuplsPkg::*;
import Qupls_ptable_walker_pkg::*;

module Qupls_ptw_tran_buffer(rst, clk, state, ptw_pv, ptw_ppv, tranbuf,
	miss_queue, sel_tran, sel_qe, ftam_resp, tid, ptw_vadr, ptw_padr);
parameter CORENO = 6'd1;
parameter CID = 3'd3;
input rst;
input clk;
input Qupls_ptable_walker_pkg::ptw_state_t state;
input ptw_pv;
input ptw_ppv;
output ptw_tran_buf_t [15:0] tranbuf;
input ptw_miss_queue_t [MISSQ_SIZE-1:0] miss_queue;
input [5:0] sel_tran;
input [5:0] sel_qe;
input fta_cmd_response128_t ftam_resp;
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

	case(state)
	IDLE:
		begin
			if (ptw_pv & ~ptw_ppv & ~sel_qe[5]) begin
				if (miss_queue[sel_qe].lvl != 3'd7) begin
					// Record outstanding transaction.
					tranbuf[tid & 15].v <= 1'b1;
					tranbuf[tid & 15].tid <= tid;
					tranbuf[tid & 15].rdy <= 1'b0;
					tranbuf[tid & 15].asid <= miss_queue[sel_qe].asid;
					tranbuf[tid & 15].vadr <= ptw_vadr;
					tranbuf[tid & 15].padr <= ptw_padr;
					tranbuf[tid & 15].stk <= sel_qe;
					tid.tranid <= tid.tranid + 2'd1;
					if (&tid.tranid)
						tid.tranid <= 4'd1;
				end
			end
		end
	default:
		;	
	endcase

	// Capture responses.
	// a tid of zero is not valid, and the tran should not be marked ready.
	// The tran coming back should match the one in the tran buffer.
	if (ftam_resp.ack & |(ftam_resp.tid & 15)) begin
		if (ftam_resp.tid==tranbuf[ftam_resp.tid & 15].tid) begin
			tranbuf[ftam_resp.tid & 15].dat <= ftam_resp.dat;
			tranbuf[ftam_resp.tid & 15].pte <= ftam_resp.dat >> {tranbuf[ftam_resp.tid & 15].padr[3],6'b0};
//		tranbuf[ftam_resp.tid & 15].padr <= ftam_resp.adr;
			tranbuf[ftam_resp.tid & 15].rdy <= 1'b1;
		end
	end

	// Search for ready translations and update the TLB.
	if (~sel_tran[5]) begin
		tranbuf[sel_tran].v <= 1'b0;
		tranbuf[sel_tran].rdy <= 1'b0;
	end
end

endmodule
