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
import Qupls_cache_pkg::*;
import QuplsMmupkg::*;
import QuplsPkg::*;

module Qupls_seq_memory2_ack(rst, clk, db_i, mem_ack_i, agen_v_o, state_o,
	dram_state_o, hi_o, Rt_i, Rt_o, Rtz_i, Rtz_o, aRt_i, aRt_o, aRtz_i, aRtz_o,
	store_o, sel_o, pc, instr_i, instr_o, cpu_resp_i, shift_amt_i, bus_i, bus_o
);
input rst;
input clk;
input decode_bus_t db_i;
input mem_ack_i;
output reg agen_v_o;
output dram_state_t dram_state_o;
output e_seq_state state_o;
output reg hi_o;
input pregno_t Rt_i;
output pregno_t Rt_o;
input aregno_t aRt_i;
output aregno_t aRt_o;
output reg [79:0] sel_o;
input pc_address_t pc;
input ex_instruction_t instr_i;
input fta_response512_t cpu_resp_i;
input [9:0] shift_amt_i;
output value_t bus_o;

always_ff @(posedge clk)
if (rst) begin
	state_o <= IFETCH;
	agen_v_o <= FALSE;
	hi_o <= FALSE;
	Rt_o <= 8'd0;
	Rtz_o <= TRUE;
	aRt_o <= 8'd0;
	aRtz_o <= TRUE;
	store_o <= 1'd0;
	sel_o <= 80'd0;
end
else begin
	state_o <= MEMORY2_ACK;
	if (mem_ack_i) begin
		agen_v_o <= FALSE;
		dram_state_o <= DRAMSLOT_AVAIL;
    Rt_o <= Rt_i;
    Rtz_o <= Rtz_i;
    aRt_o <= aRt_i;
    aRtz_o <= aRtz_i;
  	bus_o <= fnDati(1'b0,instr_i,(cpu_resp_i[0].dat << shift_amt_i)|bus_i, pc);
		state_o <= db.load ? WRITEBACK : IFETCH;
	end
end

endmodule
