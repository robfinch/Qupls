// ============================================================================
//        __
//   \\__/ o\    (C) 2024  Robert Finch, Waterloo
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
//
// ============================================================================
//
import const_pkg::*;
import QuplsPkg::*;

module Qupls_backout_machine(rst, clk, backout, fcu_id, rob, tail,
	restore, restore_ndx,
	backout_state, backout_st2,
	bo_wr, bo_areg, bo_preg, bo_nreg, stall);
input rst;
input clk;
input backout;
input rob_ndx_t fcu_id;
input rob_entry_t [ROB_ENTRIES-1:0] rob;
input rob_ndx_t tail;
input restore;
input rob_ndx_t restore_ndx;
output reg [1:0] backout_state;
output reg [1:0] backout_st2;
output reg bo_wr;
output aregno_t bo_areg;
output pregno_t bo_preg;
output pregno_t bo_nreg;
output reg stall;

// A backout is automatically triggered one cycle after a restore.
reg restored;
always_ff @(posedge clk)
if (rst)
	restored <= FALSE;
else
	restored <= restore;

// Backout state machine. For backing out RAT changes when a mispredict
// occurs. The backout needs to happen only for the instructions following the
// branch instruction in the same instruction group. The checkpoint restore
// will handle the other register backouts.
// We go backwards (staying in the same group) to the mispredicted branch,
// updating the RAT with the old register mappings which are stored in the ROB.
// The we go forwards from the first instruction in the group to the
// mispredicted branch updating the RAT with the register mappings.
// Note if a branch mispredict occurs and the checkpoint is being restored
// to an earlier one anyway, then this backout is cancelled.

rob_ndx_t backout_id;

always_ff @(posedge clk)
if (rst) begin
	backout_id <= {$bits(rob_ndx_t){1'b0}};
	backout_state <= 2'd0;
end
else begin
	case(backout_state)
	2'd0:
		// If taking the branch, there is nothing to back-out
		// If not-taking the branch, the instructions following the branch will
		// be turned into copy-targets, so again there is nothing to back-out.
		if (backout|restored) begin
			/*			
			backout_id <= (tail + ROB_ENTRIES - 1) % ROB_ENTRIES;
			if (((tail + ROB_ENTRIES - 1) % ROB_ENTRIES) != fcu_id)
				backout_state <= 2'd1;
			*/
			/*
			if (rob[(fcu_id+3)%ROB_ENTRIES].grp==rob[fcu_id].grp) begin
				backout_id <= (fcu_id + 3) % ROB_ENTRIES;
				backout_state <= 2'd1;
			end
			else if (rob[(fcu_id+2)%ROB_ENTRIES].grp==rob[fcu_id].grp) begin
				backout_id <= (fcu_id + 2) % ROB_ENTRIES;
				backout_state <= 2'd1;
			end
			else if (rob[(fcu_id+1)%ROB_ENTRIES].grp==rob[fcu_id].grp) begin
				backout_id <= (fcu_id + 1) % ROB_ENTRIES;
				backout_state <= 2'd1;
			end
			else
			*/
			begin
				backout_id <= fcu_id;
				backout_state <= 2'd1;
			end

//		else  nothing to backout
		end
	// State 1: iterate backwards until the mispredicted branch.
	2'd1:
		/*
		if (restore)
			backout_state <= 2'd0;
		else
		*/
		if (backout_id != fcu_id)
			backout_id <= (backout_id + ROB_ENTRIES - 1) % ROB_ENTRIES;
		else begin
			if (rob[(fcu_id + ROB_ENTRIES - 3) % ROB_ENTRIES].grp==rob[fcu_id].grp) begin
				backout_id <= (fcu_id + ROB_ENTRIES - 3) % ROB_ENTRIES;
				backout_state <= 2'd2;
			end
			else if (rob[(fcu_id + ROB_ENTRIES - 2) % ROB_ENTRIES].grp==rob[fcu_id].grp) begin
				backout_id <= (fcu_id + ROB_ENTRIES - 2) % ROB_ENTRIES;
				backout_state <= 2'd2;
			end
			else if (rob[(fcu_id + ROB_ENTRIES - 1) % ROB_ENTRIES].grp==rob[fcu_id].grp) begin
				backout_id <= (fcu_id + ROB_ENTRIES - 1) % ROB_ENTRIES;
				backout_state <= 2'd2;
			end
			else begin
				backout_id <= fcu_id;
				backout_state <= 2'd2;
			end
		end
	// State 2: iterate forwards to the mispredicted branch.
	2'd2:
		if (backout_id != fcu_id)
			backout_id <= (backout_id + 1) % ROB_ENTRIES;
		else
			backout_state <= 2'd0;
	default:
		backout_state <= 2'd0;
	endcase
end

always_ff @(posedge clk)
if (rst)
	backout_st2 <= 2'd0;
else begin
	case(backout_st2)
	2'd0:
		if (restore)
			backout_st2 <= 2'd1;
	2'd1:
			if (rob[restore_ndx].sn <= rob[fcu_id].sn)
				backout_st2 <= 2'd0;
	endcase
end


always_comb stall = backout || backout_state != 2'd0 || backout_st2 != 2'd0;

always_ff @(posedge clk)
if (rst) begin
	bo_wr <= FALSE;
	bo_areg <= {$bits(aregno_t){1'b0}};
	bo_preg <= {$bits(pregno_t){1'b0}};
	bo_nreg <= {$bits(pregno_t){1'b0}};
end
else begin
	bo_wr <= FALSE;
	if (!restore && (|backout_state)) begin
		bo_wr <= TRUE;//backout_id != fcu_id;
		if (rob[backout_id].sn > rob[fcu_id].sn) begin
			bo_areg <= rob[backout_id].op.aRt;
			bo_preg <= rob[backout_id].op.pRt;
			bo_nreg <= rob[backout_id].op.nRt;
		end
		else begin
			bo_areg <= rob[backout_id].op.aRt;
			bo_preg <= rob[backout_id].op.nRt;
			bo_nreg <= rob[backout_id].op.pRt;
		end
	end
end

always_ff @(posedge clk)
begin
	if (|backout_state) begin
		$display("-  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -");
		if (rob[backout_id].sn > rob[fcu_id].sn)
			$display("Q+ RAT backout: %d -> %d/%d freed: %d", 
				rob[backout_id].op.aRt,
				rob[backout_id].op.aRt, rob[backout_id].op.pRt,
				rob[backout_id].op.nRt);
		else
			$display("Q+ RAT forward: %d -> %d/%d freed: %d", 
				rob[backout_id].op.aRt,
				rob[backout_id].op.aRt, rob[backout_id].op.nRt,
				rob[backout_id].op.pRt);
		$display("-  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -");
	end
end

endmodule
