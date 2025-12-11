// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Qupls4_mpu.sv
//	- processing unit
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

import wishbone_pkg::*;
import const_pkg::*;
import Qupls4_pkg::*;

module Qupls4_mpu(rst_i, clk_i, clk2x_i, clk3x_i, clk5x_i, ftam_req, ftam_resp,
	irq_bus,
	clk0, gate0, out0, clk1, gate1, out1, clk2, gate2, out2, clk3, gate3, out3
	);
parameter CPU="OOO";
parameter MPUNO = 6'd1;				// MPU number
parameter BUS_PROTOCOL = 0;
input rst_i;
input clk_i;
input clk2x_i;
input clk3x_i;
input clk5x_i;
output wb_cmd_request256_t ftam_req;
input wb_cmd_response256_t ftam_resp;
input [31:0] irq_bus;
input clk0;
input gate0;
output out0;
input clk1;
input gate1;
output out1;
input clk2;
input gate2;
output out2;
input clk3;
input gate3;
output out3;

genvar g;
integer n1;
wire cs_config, cs_io;
assign cs_config = ftam_req.adr[31:28]==4'hD;
assign cs_io = ftam_req.adr[31:24]==8'hFE;

wire snoop_v = 1'b0;
cpu_types_pkg::address_t snoop_adr = 32'd0;
wire [5:0] snoop_cid = 6'd0;
reg [31:0] iirq;

wire [5:0] ipl;
wire [31:0] ivect;
wire [63:0] irq;
wire [2:0] swstk;
wire irq_ack;
wire [7:0] pic_cause;
wire [5:0] pic_core;
wire [31:0] tlbmiss_irq;
wire [3:0] pic_irq;
wire [5:0] ipri;
wire [31:0] pit_irq;
wire pic_ack,pit_ack;
wire [31:0] pic_dato;
wire [63:0] pit_dato;
wire [31:0] page_fault;
wb_cmd_response256_t [0:0] fan256_resp;
wb_cmd_request64_t [1:0] fan64_req;
wb_cmd_response64_t [1:0] fan64_resp;
wb_cmd_request64_t msi64_req;
wb_cmd_response64_t msi_resp;
wb_cmd_response256_t pic256_resp;
wb_cmd_request64_t pit64_req;
wb_cmd_response64_t pit_resp;
wb_cmd_response256_t wb256_resp;

Qupls4_pit #(.BUS_PROTOCOL(BUS_PROTOCOL)) utmr1
(
	.rst_i(rst_i),
	.clk_i(clk_i),
	.cs_config_i(cs_config),
	.sreq(pit64_req),
	.sresp(pit_resp),
	.clk0(clk0),
	.gate0(gate0),
	.out0(out0),
	.clk1(clk1),
	.gate1(gate1),
	.out1(out1),
	.clk2(clk2),
	.gate2(gate2),
	.out2(out2),
	.clk3(clk3),
	.gate3(gate3),
	.out3(out3)
);

Qupls4_msi_controller #(.BUS_PROTOCOL(BUS_PROTOCOL)) umsi
(
	.coreno(MPUNO),
	.rst(rst_i),
	.clk(clk_i),
	.cs_config_i(cs_config),
	.req(msi64_req),
	.resp(msi_resp),
	.ipl(ipl),
	.irq_resp_i(wb256_resp),
	.irq(irq),
	.irq_ack(irq_ack),
	.swstk(swstk),
	.ivect_o(ivect),
	.ipri(ipri)
);

/*
always_comb
begin
	pic_resp.tid = wbm32_req.tid;
	pic_resp.ack = pic_ack;
	pic_resp.err = fta_bus_pkg::OKAY;
	pic_resp.rty = 1'b0;
	pic_resp.stall = 1'b0;
	pic_resp.next = 1'b0;
	pic_resp.dat = pic_dato;
	pic_resp.adr = wbm32_req.adr;
	pic_resp.pri = wbm32_req.pri;
end
*/

Qupls4
#(
	.CORENO(6'd1),
	.CHANNEL(6'd1)
)
ucpu1
(
	.coreno_i(64'd1),
	.rst_i(rst_i),
	.clk_i(clk_i),
	.clk2x_i(clk2x_i),
	.clk3x_i(clk3x_i),
	.clk5x_i(clk5x_i),
	.ipl(ipl),
	.irq(irq[1]),
	.irq_ack(irq_ack),
	.irq_i(ipri),
	.ivect_i(ivect),
	.swstk_i(swstk),
	.om_i(2'd3),
	.fta_req(fan256_req),
	.fta_resp(wb256_resp),
	.snoop_v(snoop_v),
	.snoop_adr(snoop_adr),
	.snoop_cid(snoop_cid)
);

wb_slave_fanout #(.FANOUT64(2), .FANOUT256(1))
ufo1
(
	.rst_i(rst_i),
	.clk_i(clk_i),
	.wb_req(fan256_req),
	.wb_resp(wb256_resp),
	.fan64_req(fan64_req),
	.fan64_resp(fan64_resp),
	.fan256_req(ftam_req),
	.fan256_resp(fan256_resp)
);

assign fan64_resp[0] = msi_resp;
assign fan64_resp[1] = pit_resp;
assign fan256_resp[0] = ftam_resp;
assign msi64_req = fan64_req[0];
assign pit64_req = fan64_req[1];

always_comb
	iirq = irq_bus|pit_irq;

/*
reg [15:0] ecc_ext_dat [0:15];
always_comb
	for (n1 = 0; n1 < 16; n1 = n1 + 1)
		ecc_ext_dat[n1] = {ecc_chkbits[n1],ecc_ext_data[n1]};

generate begin : gECC
	for (g = 0; g < 16; g = g + 1) begin
		ecc_data_out[g] = ftam_req.data1[g*11+10:g*11];
		ecc_encode uecce1 (
			.ecc_clk(clk_i),
			.ecc_reset(rst_i),
			.ecc_clken(1'b1),
			.ecc_data_in(ecc_data_out[g]),
			.ecc_data_out(ecc_ext_data[g]),
			.ecc_chkbits_out(ecc_ext_chkbits[g])
		);
		always_comb
		begin
			ftam_xreq = ftam_req;
			ftam_xreq.data1[g*16+15:g*16] = ecc_ext_dat[g];
		end
	end
end
endgenerate
*/

endmodule
