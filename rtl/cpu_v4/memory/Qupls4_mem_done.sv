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
//
// ============================================================================
//
import const_pkg::*;
import cpu_types_pkg::*;
import cache_pkg::*;
import mmu_pkg::*;
import Qupls4_pkg::*;

module Qupls4_mem_done(rst, clk, load, store, cload, cstore, cload_tags,
	dram_oper, dram_idv, dram_id, stomp, dram_stomp, done);
input rst;
input clk;
input load;
input store;
input cload;
input cstore;
input cload_tags;
input Qupls4_pkg::dram_oper_t dram_oper;
input dram_idv;
input rob_ndx_t dram_id;
input Qupls4_pkg::rob_bitmask_t stomp;
input dram_stomp;
output reg done;

// Stores are done as soon as they issue.
// Loads are done when there is an ack back from the memory system.
always_ff @(posedge clk)
if (rst)
	done <= FALSE;
else begin
	if (!(store|cstore|load|cload) && dram_idv)
		done <= TRUE;
	else if (~(load|cload) ? !stomp[dram_id] && dram_idv :
		(dram_oper.state==2'b11) && dram_oper.v)
		done <= TRUE;
	else
		done <= FALSE;
end

endmodule
