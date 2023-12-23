// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
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
import QuplsPkg::*;

module Qupls_regfile_valid(rst, clk, branchmiss, branchmiss_state, Rt0, Rt1, Rt2, Rt3,
	livetarget, iq, rob_source,
	commit0_v, commit1_v, commit0_Rt, commit1_Rt, commit2_Rt, commit3_Rt,
	commit0_id, commit1_id, commit2_id, commit3_id,
	rf_source, rf_v);
input rst;
input clk;
input branchmiss;
input [2:0] branchmiss_state;
input aregno_t Rt0;			// target register allocated
input aregno_t Rt1;
input aregno_t Rt2;
input aregno_t Rt3;
input reg_bitmask_t livetarget;
input rob_entry_t [ROB_ENTRIES-1:0] rob;
input [QENTRIES-1:0] rob_source;
input commit0_v;
input commit1_v;
input commit2_v;
input commit3_v;
input aregno_t commit0_Rt;
input aregno_t commit1_Rt;
input aregno_t commit2_Rt;
input aregno_t commit3_Rt;
input rob_ndx_t commit0_id;
input rob_ndx_t commit1_id;
input rob_ndx_t commit2_id;
input rob_ndx_t commit3_id;
input [4:0] rf_source [0:63];
output reg [63:0] rf_v;
parameter LR0 = 6'd56;

integer n, n1;
reg [63:0] rf_vr;

initial begin
	for (n = 0; n < AREGS; n = n + 1) begin
	  rf_vr[n] = 1'b1;
	end
end

always_ff @(posedge clk, posedge rst)
if (rst) begin
	for (n1 = 0; n1 < AREGS; n1 = n1 + 1)
	  rf_vr[n1] <= 1'b1;
end
else begin
	rf_vr <= rf_v;
	if (branchmiss) begin
		if (branchmiss_state==3'd4) begin
			for (n1 = 1; n1 < AREGS; n1 = n1 + 1)
			  if (rf_vr[n1] == INV && ~livetarget[n1])
			  	rf_vr[n1] <= VAL;
		end
	end
	//
	// COMMIT PHASE (register-file update only ... dequeue is elsewhere)
	//
	// look at head0 and head1 and let 'em write the register file if they are ready
	//
	// why is it happening here and not in another phase?
	// want to emulate a pass-through register file ... i.e. if we are reading
	// out of r3 while writing to r3, the value read is the value written.
	// requires BLOCKING assignments, so that we can read from rf[i] later.
	//
	if (commit0_v) begin
    if (!rf_vr[ commit0_Rt ]) 
			rf_vr[ commit0_Rt ] <= rf_source[ commit0_Rt ] == commit0_id || (branchmiss && rob_source[ commit0_id ]);
	end
	if (commit1_v) begin
    if (!rf_vr[ commit1_Rt ]) 
			rf_vr[ commit1_Rt ] <= rf_source[ commit1_Rt ] == commit1_id || (branchmiss && rob_source[ commit1_id ]);
	end
	if (commit2_v) begin
    if (!rf_vr[ commit2_Rt ]) 
			rf_vr[ commit2_Rt ] <= rf_source[ commit2_Rt ] == commit2_id || (branchmiss && rob_source[ commit2_id ]);
	end
	if (commit3_v) begin
    if (!rf_vr[ commit3_Rt ]) 
			rf_vr[ commit3_Rt ] <= rf_source[ commit3_Rt ] == commit3_id || (branchmiss && rob_source[ commit3_id ]);
	end

	rf_vr[Rt0] <= INV;
	rf_vr[Rt1] <= INV;
	rf_vr[Rt2] <= INV;
	rf_vr[Rt3] <= INV;
	
end

always_comb
begin

	rf_v = rf_vr;
	if (commit0_v) begin
    if (!rf_v[ commit0_Rt ]) 
			rf_v[ commit0_Rt ] = rf_source[ commit0_Rt ] == commit0_id || (branchmiss && rob_source[ commit0_id ]);
	end
	if (commit1_v) begin
    if (!rf_v[ commit1_Rt ]) 
			rf_v[ commit1_Rt ] = rf_source[ commit1_Rt ] == commit1_id || (branchmiss && rob_source[ commit1_id ]);
	end
	if (commit2_v) begin
    if (!rf_v[ commit2_Rt ]) 
			rf_v[ commit2_Rt ] = rf_source[ commit2_Rt ] == commit2_id || (branchmiss && rob_source[ commit2_id ]);
	end
	if (commit3_v) begin
    if (!rf_v[ commit3_Rt ]) 
			rf_v[ commit3_Rt ] = rf_source[ commit3_Rt ] == commit3_id || (branchmiss && rob_source[ commit3_id ]);
	end

	rf_v[0] = 1;
end

endmodule
