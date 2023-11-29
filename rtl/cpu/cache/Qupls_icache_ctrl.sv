// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Qupls_icache_ctrl.sv
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
// 41 LUTs / 358 FFs
// ============================================================================

import fta_bus_pkg::*;
import QuplsPkg::*;
import Qupls_cache_pkg::*;

module Qupls_icache_ctrl(rst, clk, wbm_req, wbm_resp, ftam_full,
	hit, tlb_v, miss_adr, miss_asid,
	wr_ic, way, line_o, snoop_adr, snoop_v, snoop_cid);
parameter WAYS = 4;
parameter CORENO = 6'd1;
parameter CID = 6'd0;
localparam LOG_WAYS = $clog2(WAYS);
input rst;
input clk;
output fta_cmd_request128_t wbm_req;
input fta_cmd_response128_t wbm_resp;
input ftam_full;
input hit;
input tlb_v;
input fta_address_t miss_adr;
input QuplsPkg::asid_t miss_asid;
output wr_ic;
output [LOG_WAYS-1:0] way;
output ICacheLine line_o;
input fta_address_t snoop_adr;
input snoop_v;
input [5:0] snoop_cid;

wire QuplsPkg::address_t [15:0] vtags;
wire ack;

// Generate memory requests to fill cache line.

Qupls_icache_req_generator
#(
	.CORENO(CORENO),
	.CID(CID)
)
icrq1
(
	.rst(rst),
	.clk(clk),
	.hit(hit), 
	.tlb_v(tlb_v),
	.miss_adr(miss_adr),
	.miss_asid(miss_asid),
	.wbm_req(wbm_req),
	.full(ftam_full),
	.vtags(vtags),
	.snoop_v(snoop_v),
	.snoop_adr(snoop_adr),
	.snoop_cid(snoop_cid),
	.ack(wr_ic)
);

// Process ACK responses coming back.

Qupls_icache_ack_processor 
#(
	.LOG_WAYS(LOG_WAYS)
)
uicap1
(
	.rst(rst),
	.clk(clk),
	.wbm_resp(wbm_resp),
	.wr_ic(wr_ic),
	.line_o(line_o),
	.vtags(vtags),
	.way(way)
);

endmodule
