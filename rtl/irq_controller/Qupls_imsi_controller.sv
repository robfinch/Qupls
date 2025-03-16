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
//
//  550 LUTs / 610 FFs /  BRAMs
// ============================================================================
//
import const_pkg::*;
import fta_bus_pkg::*;
import QuplsPkg::*;

module Qupls_imsi_controller(rst, clk, cs_config_i, req, resp);
input rst;
input clk;
input cs_config_i;
input fta_cmd_request64_t req;
output fta_cmd_response64_t resp;

parameter IMSI_ADDR = 32'hFEE20001;
parameter IMSI_ADDR_MASK = 32'hFFFF0000;
parameter IMSI_IRQ = 32'hFEE20001;
parameter IMSI_IRQ_MASK = 32'hFFFF0000;

parameter CFG_BUS = 8'd0;
parameter CFG_DEVICE = 5'd6;
parameter CFG_FUNC = 3'd0;
parameter CFG_VENDOR_ID	=	16'h0;
parameter CFG_DEVICE_ID	=	16'h0;
parameter CFG_SUBSYSTEM_VENDOR_ID	= 16'h0;
parameter CFG_SUBSYSTEM_ID = 16'h0;
parameter CFG_ROM_ADDR = 32'hFFFFFFF0;

parameter CFG_REVISION_ID = 8'd0;
parameter CFG_PROGIF = 8'h40;
parameter CFG_SUBCLASS = 8'h00;					// 00 = PIC
parameter CFG_CLASS = 8'h08;						// 08 = base system controller
parameter CFG_CACHE_LINE_SIZE = 8'd8;		// 32-bit units
parameter CFG_MIN_GRANT = 8'h00;
parameter CFG_MAX_LATENCY = 8'h00;
parameter CFG_IRQ_LINE = 8'hFF;

localparam CFG_HEADER_TYPE = 8'h00;			// 00 = a general device

integer nn,n1;

fta_cmd_request64_t reqd;
fta_cmd_response64_t cfg_resp;
fta_imessage_t imsg;
reg [63:0] dat_o;
reg cs_config, cs_io;
reg irqo;
wire cs_irq;
reg global_enable;
reg [5:0] irq_threshold;
(* ram_style="distributed" *)
reg [63:0] irq_pending [0:31];
(* ram_style="distributed" *)
reg [63:0] irq_enable [0:31];

always_ff @(posedge clk)
	reqd <= req;

always_ff @(posedge clk)
	cs_config <= cs_config_i;

wire cs_imsi;
always_comb
	cs_io = cs_imsi;

always_ff @(posedge clk)
	resp.ack <= cfg_resp.ack ? 1'b1 : cs_io ? reqd.cyc : irqo & reqd.cyc;
always_ff @(posedge clk)
	resp.adr <= cfg_resp.ack ? cfg_resp.adr : cs_io ? reqd.padr : irqo ? imsg[71:32] : 40'd0;
always_ff @(posedge clk)
	resp.tid <= cfg_resp.ack ? cfg_resp.tid : cs_io ? reqd.tid : 13'd0;//irqa ? {irq_o[21:16],irq_o[14:12],4'd0} : 13'd0;	// core,channel
always_ff @(posedge clk)
	resp.err <= cfg_resp.ack ? cfg_resp.err : cs_io ? fta_bus_pkg::OKAY : irqo ? fta_bus_pkg::IRQ : fta_bus_pkg::OKAY;
always_ff @(posedge clk)
	resp.pri <= cfg_resp.ack ? cfg_resp.pri : cs_io ? 4'd5 : 4'd5;//irqa ? irq_o[11:8] : 4'd5;		// priority
always_ff @(posedge clk)
	resp.dat <= cfg_resp.ack ? cfg_resp.dat : cs_io ? dat_o : irqo ? imsg[31:0] : 64'd0;//irqa ? {24'h00,irq_o[7:0]} : 32'd0;
assign resp.next = 1'b0;
assign resp.stall = 1'b0;
assign resp.rty = 1'b0;


ddbb64_config #(
	.CFG_BUS(CFG_BUS),
	.CFG_DEVICE(CFG_DEVICE),
	.CFG_FUNC(CFG_FUNC),
	.CFG_VENDOR_ID(CFG_VENDOR_ID),
	.CFG_DEVICE_ID(CFG_DEVICE_ID),
	.CFG_BAR0(IMSI_ADDR),
	.CFG_BAR0_MASK(IMSI_ADDR_MASK),
	.CFG_BAR1(IMSI_IRQ),
	.CFG_BAR1_MASK(IMSI_IRQ_MASK),
	.CFG_SUBSYSTEM_VENDOR_ID(CFG_SUBSYSTEM_VENDOR_ID),
	.CFG_SUBSYSTEM_ID(CFG_SUBSYSTEM_ID),
	.CFG_ROM_ADDR(CFG_ROM_ADDR),
	.CFG_REVISION_ID(CFG_REVISION_ID),
	.CFG_PROGIF(CFG_PROGIF),
	.CFG_SUBCLASS(CFG_SUBCLASS),
	.CFG_CLASS(CFG_CLASS),
	.CFG_CACHE_LINE_SIZE(CFG_CACHE_LINE_SIZE),
	.CFG_MIN_GRANT(CFG_MIN_GRANT),
	.CFG_MAX_LATENCY(CFG_MAX_LATENCY),
	.CFG_IRQ_LINE(CFG_IRQ_LINE)
)
ucfg1
(
	.rst_i(rst),
	.clk_i(clk),
	.irq_i(2'b0),
	.cs_i(cs_config), 
	.req_i(reqd),
	.resp_o(cfg_resp),
	.cs_bar0_o(cs_imsi),
	.cs_bar1_o(cs_irq),
	.cs_bar2_o()
);

// register read path
always_ff @(posedge clk)
if (cs_io) begin
	case(reqd.padr[9:3])
	7'h70:	dat_o <= {63'd0,global_enable};
	7'h72:	dat_o <= {58'd0,irq_threshold};
	// 0x80 tp 0xBF = interrupt pending bits
	7'b10?????:	dat_o <= irq_pending[reqd.padr[7:3]];
	// 0xC0 to 0xFF = interrupt endable bits
	7'b11?????:	dat_o <= irq_enable[reqd.padr[7:3]];
	default:	dat_o <= 64'd0;
	endcase
end
else
	dat_o <= 64'd0;

// write registers	
always_ff @(posedge clk)
if (rst) begin
	for (n1 = 0; n1 < 32; n1 = n1 + 1)
		irq_enable[n1] <= 64'd0;
end
else begin
	if (cs_io & reqd.we)
		case(reqd.padr[9:3])
		7'h70:	global_enable <= reqd.dat[0];
		7'h72:	irq_threshold <= reqd.dat[5:0];
		7'b11?????:	irq_enable[reqd.padr[7:3]] <= reqd.dat;
		default:	;
		endcase
end

always_comb
begin
	imsg.pri = reqd.dat[5:0];
	imsg.stkndx = reqd.dat[9:8];
	imsg.segment = 16'd0;
	imsg.bus = CFG_BUS;
	imsg.device = CFG_DEVICE;
	imsg.func = CFG_FUNC;
	imsg.irq_coreno = 6'd1;	//reqd.padr[17:12]
	imsg.om = reqd.dat[11:10];
	imsg.vecno = reqd.padr[11:0];
end

always_comb
begin
	irqo = cs_irq & global_enable & irq_enable[reqd.padr[10:6]][reqd.padr[5:0]] && imsg.pri > irq_threshold;
end

always_ff @(posedge clk)
if (rst) begin
	for (nn = 0; nn < 32; nn = nn + 1)
		irq_pending[nn] <= 64'd0;
end
else begin
	if (cs_io & reqd.we) begin
		if (reqd.padr[9:8]==2'b10)
			irq_pending[reqd.padr[7:3]] <= irq_pending[reqd.padr[7:3]] & ~reqd.dat;
	end
	else if (cs_irq)
		irq_pending[reqd.padr[10:6]] <= irq_pending[reqd.padr[10:6]] | (64'd1 << reqd.padr[5:0]);
end

endmodule
