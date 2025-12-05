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
// 620 LUTs / 1150 FFs / BRAMS
// ============================================================================
//
import const_pkg::*;
import fta_bus_pkg::*;
import QuplsPkg::*;
import msi_pkg::*;

module Qupls4_msi_logger(rst, clk, cs_config_i, iresp, sreq, sresp, mreq, mresp);
input rst;
input clk;
input cs_config_i;
input fta_cmd_response256_t iresp;	// bus to snoop
input fta_cmd_request64_t sreq;			// slave
output fta_cmd_response64_t sresp;
output fta_cmd_request256_t mreq;		// master
input fta_cmd_response256_t mresp;

parameter MSI_LOGGER_ADDR = 32'hFEE20001;
parameter MSI_LOGGER_ADDR_MASK = 32'hFFFFE000;

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

typedef enum logic [1:0] {
	IMSIC_IDLE = 2'd0,
	IMSIC_LOGDONE1
} state_t;

state_t state;
reg log_en;
reg [63:0] log_ndx;
reg [63:0] log_adr;
reg [63:0] log_ndxmask;
reg [127:0] log_data;
fta_imessage_t imsg, fifo_din, fifo_dout;
reg imsg_pending;
reg [63:0] filter_cores;
reg [63:0] filter_priority;
reg [7:0] filter_err;
reg [5:0] rty_wait;
// Fifo control
reg wr_en1;
reg rd_en1;
wire full;
wire overflow;
wire empty;
wire valid;
wire underflow;
wire [4:0] data_count;

fta_cmd_request64_t reqd;
fta_cmd_response64_t cfg_resp;
reg cs_config;
wire cs_msi_logger;
reg erc;
reg [63:0] dat_o;

always_comb
	imsg = {iresp.adr[39:0],iresp.dat[31:0]};
always_comb
	imsg_pending = log_en
		&& filter_err[iresp.err]
		&& filter_cores[imsg.irq_coreno]
		&& filter_priority[imsg.pri]
		;
// zero extend imsg
always_comb
	log_data = {64'd0,fifo_dout};

always_ff @(posedge clk)
	reqd <= sreq;

always_ff @(posedge clk)
	cs_config <= cs_config_i;

always_ff @(posedge clk_i)
	erc <= sreq.cti==fta_bus_pkg::ERC;

vtdl #(.WID(1), .DEP(16)) urdyd2 (.clk(clk_i), .ce(1'b1), .a(4'd0), .d((cs_msi_logger)&(erc|~reqd.we)), .q(respack));
always_ff @(posedge clk)
if (rst)
	sresp <= {$bits(fta_cmd_response64_t){1'b0}};
else begin
	if (cfg_resp.ack)
		sresp <= cfg_resp;
	else if (cs_msi_logger) begin
		sresp.ack <= respack ? reqd.cyc : 1'b0;
		sresp.tid <= respack ? reqd.tid : 13'd0;
		sresp.next <= 1'b0;
		sresp.stall <= 1'b0;
		sresp.err <= fta_bus_pkg::OKAY;
		sresp.rty <= 1'b0;
		sresp.pri <= 4'd5;
		sresp.adr <= respack ? reqd.padr : 40'd0;
		sresp.dat <= respack ? dat_o : 64'd0;
	end
end


ddbb64_config #(
	.CFG_BUS(CFG_BUS),
	.CFG_DEVICE(CFG_DEVICE),
	.CFG_FUNC(CFG_FUNC),
	.CFG_VENDOR_ID(CFG_VENDOR_ID),
	.CFG_DEVICE_ID(CFG_DEVICE_ID),
	.CFG_BAR0(MSI_LOGGER_ADDR),
	.CFG_BAR0_MASK(MSI_LOGGER_ADDR_MASK),
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
	.cs_bar0_o(cs_msi_logger),
	.cs_bar1_o(),
	.cs_bar2_o()
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

always_ff @(posedge clk)
if (rst) begin
	state <= IMSIC_IDLE;
	log_en <= 1'b0;
	filter_cores <= 64'h02;										// core 1
	filter_priority <= 64'hFFFFFFFFFFFFFFFE;	// all priorities
	filter_err <= fta_bus_pkg::IRQ;
	log_adr <= 64'h00010000;
	log_ndx <= 64'd0;
	log_ndxmask <= 64'h0FFE0;
	mreq <= {$bits(fta_cmd_request256_t){1'b0}};
	mreq.blen <= 6'd0;
	mreq.tid <= 13'd0;
	mreq.cmd <= fta_bus_pkg::CMD_NONE;
	mreq.cyc <= LOW;
	mreq.stb <= LOW;
	mreq.we <= LOW;
	mreq.sel <= 32'd0;
	mreq.data1 <= 256'd0;
	rd_en1 <= 1'b1;
	rty_wait <= 6'd0;
end
else begin
	// Grab the bus for only 1 clock.
	if (mreq.cyc && !mresp.rty)
		tBusClear();

	if (cs_msi_logger & reqd.we)
		case(reqd.padr[9:3])
		7'd00:	filter_cores <= reqd.dat[63:0];			// core 1
		7'd01:	filter_priority <= reqd.dat[63:0];	// all priorities
		7'd02:	filter_err <= reqd.dat[7:0];
		7'd08:	log_en <= reqd.dat[0];
		7'd16:	
			begin
				log_adr <= reqd.dat[63:0];
				log_ndx <= 64'd0;
			end
		7'd17:	log_ndxmask <= reqd.dat[63:0] & 64'hFFFFFFFFFFFFFFE0;
		default:	;
		endcase

	case (state)
	IMSIC_IDLE:
		if (!empty & log_en) begin
			rd_en1 <= 1'b0;
			mreq.tid <= {6'd62,3'd1,4'h1};
			mreq.cmd <= fta_bus_pkg::CMD_STORE;
			mreq.cyc <= HIGH;
			mreq.stb <= HIGH;
			mreq.we <= HIGH;
			mreq.sel <= 32'hFFFFFFFF;
			mreq.padr <= log_adr + (log_ndx & log_ndxmask);
			mreq.data1 <= {64'd0,log_ndx,log_data};
			rty_wait <= 6'd0;
			state <= IMSIC_LOGDONE1;
		end
	IMSIC_LOGDONE1:
		if (!mresp.rty) begin
			log_ndx <= log_ndx + 8'h20;
			rd_en1 <= 1'b1;
			state <= IMSIC_IDLE;
		end
		else begin
			rty_wait <= rty_wait + 2'd1;
			if (rty_wait == 5'd31) begin
				mreq.tid <= {6'd62,3'd1,4'h2};
				mreq.cmd <= fta_bus_pkg::CMD_STORE;
				mreq.cyc <= HIGH;
				mreq.stb <= HIGH;
				mreq.we <= HIGH;
				mreq.sel <= 32'hFFFFFFFF;
				mreq.padr <= log_adr + (log_ndx & log_ndxmask);
			end
		end
	endcase
end

always_ff @(posedge clk)
if (rst)
	dat_o <= 64'd0;
else begin
	if (cs_msi_logger)
		case(reqd.padr[9:3])
		7'd00:	dat_o <= filter_cores;
		7'd01:	dat_o <= filter_priority;
		7'd16:	dat_o <= log_adr;
		7'd17:	dat_o <= log_ndxmask;
		default:	;
		endcase
	else
		dat_o <= 64'd0;
end

// Always writing interrupts into the queue.
always_ff @(posedge clk)
	fifo_din <= imsg;
always_ff @(posedge clk)
	wr_en1 <= imsg_pending;

// Always reading the queue output until an IRQ is detected.
assign rd_en = rd_en1;
assign wr_en = wr_en1 & ~rst;

msi_fifo inst_fifo (
  .clk(clk),                // input wire clk
  .srst(rst),              // input wire srst
  .din(fifo_din),          // input wire [71 : 0] din
  .wr_en(wr_en),            // input wire wr_en
  .rd_en(rd_en),            // input wire rd_en
  .dout(fifo_dout),            // output wire [71 : 0] dout
  .full(full),              // output wire full
  .overflow(overflow),      // output wire overflow
  .empty(empty),            // output wire empty
  .valid(valid),            // output wire valid
  .underflow(underflow),    // output wire underflow
  .data_count(data_count)  // output wire [4 : 0] data_count
);

task tBusClear;
begin
	mreq.cmd <= fta_bus_pkg::CMD_NONE;
	mreq.blen <= 6'd0;
	mreq.bte <= fta_bus_pkg::LINEAR;
	mreq.cti <= fta_bus_pkg::CLASSIC;
	mreq.cyc <= 1'b0;
	mreq.stb <= 1'b0;
	mreq.sel <= 32'h0000;
	mreq.we <= 1'b0;
end
endtask

endmodule
