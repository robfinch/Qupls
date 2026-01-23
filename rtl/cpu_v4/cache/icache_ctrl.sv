// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2026  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	icache_ctrl.sv
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
// FOR ANY DIRECT, INDIRECT, INCHANNELENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// 1000 LUTs / 2100 FFs
// ============================================================================

import wishbone_pkg::*;
import cpu_types_pkg::*;
import cache_pkg::*;

module icache_ctrl(rst, clk, wbm_req, wbm_resp, ftam_full,
	hit, tlb_v, miss_v, miss_vadr, miss_padr, miss_asid, port, port_o,
	wr_ic, way, line_o, snoop_adr, snoop_v, snoop_cid);
parameter WAYS = 4;
parameter CORENO = 6'd1;
parameter CHANNEL = 6'd0;
localparam LOG_WAYS = $clog2(WAYS);
input rst;
input clk;
output wb_cmd_request256_t wbm_req;
input wb_cmd_response256_t wbm_resp;
input ftam_full;
input hit;
input tlb_v;
input miss_v;
input cpu_types_pkg::virtual_address_t miss_vadr;
input cpu_types_pkg::physical_address_t miss_padr;
input cpu_types_pkg::asid_t miss_asid;
input port;
output wr_ic;
output [LOG_WAYS-1:0] way;
output ICacheLine line_o;
input cpu_types_pkg::physical_address_t snoop_adr;
input snoop_v;
input [5:0] snoop_cid;
output reg port_o;

wire cpu_types_pkg::virtual_address_t [15:0] vtags;
wire cpu_types_pkg::physical_address_t [15:0] ptags;
wire ack;
assign port_o = 1'b0;

// Generate memory requests to fill cache line.
// Filter out IRQs coming back.

icache_req_generator
#(
	.CORENO(CORENO),
	.CHANNEL(CHANNEL)
)
icrq1
(
	.rst(rst),
	.clk(clk),
	.hit(hit), 
	.tlb_v(tlb_v),
	.miss_v(miss_v),
	.miss_vadr(miss_vadr),
	.miss_padr(miss_padr),
	.wbm_req(wbm_req),
	.ack_i(wbm_resp.ack && wbm_resp.err!=wishbone_pkg::IRQ),
	.vtags(vtags),
	.ptags(ptags),
	.ack(wr_ic)
);

// Process ACK responses coming back.

icache_ack_processor 
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
	.ptags(ptags),
	.way(way)
);

endmodule
