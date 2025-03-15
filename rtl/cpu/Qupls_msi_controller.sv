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
// 7000 LUTs / 4000 FFs / 5 BRAMs
// ============================================================================
//
import const_pkg::*;
import fta_bus_pkg::*;
import QuplsPkg::*;

typedef struct packed
{
	logic [23:0] timestamp;
	fta_imessage_t msg;
} irq_hist_t;

typedef struct packed
{
	logic [6:0] resv;
	logic mask;					// 1=interrupt masked
	logic [31:0] dat;		// data for ISR
	logic [39:0] adr;		// ISR address
} msi_svec_t;

typedef struct packed
{
	logic [30:0] resv;
	logic mask;					// 1=interrupt masked
	logic [31:0] dat;		// data for ISR
	logic [63:0] adr;		// ISR address
} msi_vec_t;

module Qupls_msi_controller(coreno, rst, clk, cs_config_i, req, resp, ipl, irq_resp_i, irq, ivect_o, ipri, irq_ack);
input [5:0] coreno;
input rst;
input clk;
input cs_config_i;
input fta_cmd_request64_t req;
output fta_cmd_response64_t resp;
// CPU interface
input [5:0] ipl;
input fta_cmd_response256_t irq_resp_i;
output reg irq;
output reg [39:0] ivect_o;
output reg [5:0] ipri;
input irq_ack;

parameter NQUES = 63;
parameter PIC_ADDR = 32'hFEE20001;
parameter PIC_ADDR_MASK = 32'hFFFF0000;

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


integer nn,jj,n0,n1;

reg [63:0] uvtbl_base_adr;			// user mode vector table
reg [63:0] svtbl_base_adr;			// supervisor mode
reg [63:0] hvtbl_base_adr;			// hypervisor mode
reg [63:0] mvtbl_base_adr;			// machine mode
reg [63:0] vtbl_limit;
fta_imessage_t que_dout;
fta_imessage_t imsg;
reg que_full;
reg stuck, stuck_ack;
wire wr_clk = clk;
wire clka = clk;
wire clkb = clk;
reg ena,enb;
reg [8:0] wea,web;
reg [10:0] addra, addrb;
msi_svec_t douta, doutb;
msi_svec_t dina, dinb;
reg irq1,irq2;
reg [5:0] ipri2;
wire [NQUES:1] rd_rst_busy;
wire [NQUES:1] wr_rst_busy;
wire [NQUES:1] rd_en;
wire [NQUES:1] wr_en;
reg [NQUES:1] rd_en1;
reg [NQUES:1] wr_en1;
wire [NQUES:1] almost_full;
wire [NQUES:1] valid;
wire [NQUES:1] empty;
wire [NQUES:1] full;
wire [NQUES:1] overflow;
wire [NQUES:1] underflow;
wire [4:0] data_count [1:NQUES];
wire [5:0] wr_data_count [1:NQUES];
fta_imessage_t [NQUES:1] fifo_din;
fta_imessage_t [NQUES:1] fifo_dout;
irq_hist_t [15:0] irq_hist;
reg [24:0] timestamp_dif;
wire [6:0] que_sel;
reg [6:0] qsel;
reg [NQUES:1] empty1,empty_rev;
reg [23:0] timer;
reg invert_pri;
reg rdy1;
reg [63:0] dat_o;
// Register inputs
fta_cmd_request64_t reqd;
fta_cmd_response64_t cfg_resp;
reg cs_config, cs_io;

always_comb
	imsg = {irq_resp_i.adr[39:0],irq_resp_i.dat[31:0]};

always_ff @(posedge clk)
	reqd <= req;

always_ff @(posedge clk)
	cs_config <= cs_config_i;

wire cs_pic;
always_comb
	cs_io = cs_pic;

always_ff @(posedge clk)
	resp.ack <= cfg_resp.ack ? 1'b1 : cs_io & reqd.cyc & reqd.stb;
always_ff @(posedge clk)
	resp.adr <= cfg_resp.ack ? cfg_resp.adr : cs_io ? reqd.padr : 32'd0;
always_ff @(posedge clk)
	resp.tid <= cfg_resp.ack ? cfg_resp.tid : cs_io ? reqd.tid : 13'd0;//irqa ? {irq_o[21:16],irq_o[14:12],4'd0} : 13'd0;	// core,channel
always_ff @(posedge clk)
	resp.err <= cfg_resp.ack ? cfg_resp.err : cs_io ? fta_bus_pkg::OKAY : fta_bus_pkg::OKAY;
always_ff @(posedge clk)
	resp.pri <= cfg_resp.ack ? cfg_resp.pri : cs_io ? 4'd5 : 4'd5;//irqa ? irq_o[11:8] : 4'd5;		// priority
always_ff @(posedge clk)
	resp.adr <= cfg_resp.ack ? cfg_resp.adr : cs_io ? reqd.padr : 32'd0;
always_ff @(posedge clk)
	resp.dat <= cfg_resp.ack ? cfg_resp.dat : cs_io ? dat_o : 64'd0;//irqa ? {24'h00,irq_o[7:0]} : 32'd0;
assign resp.next = 1'b0;
assign resp.stall = 1'b0;
assign resp.rty = 1'b0;


ddbb64_config #(
	.CFG_BUS(CFG_BUS),
	.CFG_DEVICE(CFG_DEVICE),
	.CFG_FUNC(CFG_FUNC),
	.CFG_VENDOR_ID(CFG_VENDOR_ID),
	.CFG_DEVICE_ID(CFG_DEVICE_ID),
	.CFG_BAR0(PIC_ADDR),
	.CFG_BAR0_MASK(PIC_ADDR_MASK),
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
	.cs_bar0_o(cs_pic),
	.cs_bar1_o(),
	.cs_bar2_o()
);

// register read path
always_ff @(posedge clk)
if (cs_io) begin
	if (reqd.padr[15:14]==2'd3)
		case(reqd.padr[7:3])
		5'd0:	dat_o <= uvtbl_base_adr;
		5'd1:	dat_o <= svtbl_base_adr;
		5'd2:	dat_o <= hvtbl_base_adr;
		5'd3:	dat_o <= mvtbl_base_adr;
		5'd4:	dat_o <= vtbl_limit;
		5'd5:	
			begin
				dat_o[0] <= que_full;
				dat_o[1] <= stuck;
				dat_o[62:2] <= 61'd0;
				dat_o[63] <= irq;
			end
		5'd6:	dat_o <= que_dout[31:0];
		5'd7:	dat_o <= que_dout[39:32];
		5'd8:	dat_o <= empty;
		5'd9:	dat_o <= overflow;
		default:	dat_o <= 64'd0;
		endcase
	else
		case(reqd.padr[3])
		1'd0:	dat_o <= {{24{&douta.adr[39:38]}},douta.adr};
		1'd1:	dat_o <= {31'd0,douta.mask,douta.dat};
		endcase
end
else
	dat_o <= 64'd0;

// write registers	
always_ff @(posedge clk)
if (rst) begin
	que_full <= 1'b0;
end
else begin
	if (|full)
		que_full <= 1'b1;
	if (cs_io & reqd.we)
		case(reqd.padr[7:3])
		5'd0:	uvtbl_base_adr <= reqd.dat[63:0];
		5'd1:	svtbl_base_adr <= reqd.dat[63:0];
		5'd2:	hvtbl_base_adr <= reqd.dat[63:0];
		5'd3:	mvtbl_base_adr <= reqd.dat[63:0];
		5'd4:	vtbl_limit <= {53'd0,reqd.dat[10:0]};
		5'd5:
			begin
				if (reqd.dat[0]==1'b0)
					que_full <= 1'b0;
			end
		default:	;
		endcase
end

always_comb
	addra = reqd.padr[14:4];
always_comb
	addrb = {que_dout.om,que_dout.vecno[8:0]};
always_comb
	dina = reqd.padr[3] ? {reqd.dat[39:32],reqd.dat[31:0],40'd0} : {8'h0,32'h0,reqd.dat[39:0]};
always_comb
	dinb = 72'd0;
always_comb
	ena = cs_io && reqd.padr[15]==1'b0;
always_comb
	enb = 1'b1;
always_comb
	wea = {10{reqd.we}} & {reqd.padr[3] ? {reqd.sel[4],reqd.sel[3:0],5'h0} : {1'b0,4'h0,reqd.sel[4:0]}};
always_comb
	web = 9'b0;
always_comb
	ivect_o = doutb.adr;

always_ff @(posedge clk)
if (rst)
	timer <= 24'h00;
else
	timer <= timer + 24'd1;
always_comb
	invert_pri <= timer[5:0]==6'd63;

always_comb
	for (n1 = 1; n1 <= NQUES; n1 = n1 + 1)
		empty_rev[NQUES-n1+1] = empty[n1];

always_comb
	if (invert_pri)
		empty1 = empty_rev;
	else
		empty1 = empty;

ffz96 uffz1 ({33'h1FFFFFFFF,empty1},que_sel);

always_comb
	qsel <= invert_pri ? 7'd64-que_sel : que_sel;

always_ff @(posedge clk)
	que_dout <= (qsel==7'd127) ? 64'd0 : fifo_dout[qsel];
always_ff @(posedge clk)
	irq2 <= ~&empty && (qsel != 7'd127) && (qsel > ipl || qsel==6'd63);
always_ff @(posedge clk)
	irq1 <= irq2;
always_comb
	irq <= irq1 & ~doutb.mask;
always_ff @(posedge clk)
	ipri2 <= que_sel;
always_ff @(posedge clk)
	ipri <= ipri2;

// Always writing interrupts into the queue.
always_ff @(posedge clk)
	for (nn = 1; nn < NQUES; nn = nn + 1)
		if (irq_resp_i.pri==nn)
			wr_en1[nn] <= irq_resp_i.err==fta_bus_pkg::IRQ && (imsg.irq_coreno==coreno || &imsg.irq_coreno);
		else
			wr_en1[nn] <= 1'b0;

always_ff @(posedge clk)
	for (n0 = 1; n0 < NQUES; n0 = n0 + 1)
		fifo_din[n0] <= imsg;

always_ff @(posedge clk)
if (rst) begin
	for (jj = 0; jj < 16; jj = jj + 1)
		irq_hist[jj] <= 72'd0;
end
else begin
	if (irq_ack) begin
		irq_hist[0] <= {timer,que_dout};
		irq_hist[1] <= irq_hist[0];
		irq_hist[2] <= irq_hist[1];
		irq_hist[3] <= irq_hist[2];
		irq_hist[4] <= irq_hist[3];
		irq_hist[5] <= irq_hist[4];
		irq_hist[6] <= irq_hist[5];
		irq_hist[7] <= irq_hist[6];
		irq_hist[8] <= irq_hist[7];
		irq_hist[9] <= irq_hist[8];
		irq_hist[10] <= irq_hist[9];
		irq_hist[11] <= irq_hist[10];
		irq_hist[12] <= irq_hist[11];
		irq_hist[13] <= irq_hist[12];
		irq_hist[14] <= irq_hist[13];
		irq_hist[15] <= irq_hist[14];
	end
end

always_comb
	timestamp_dif = irq_hist[0].timestamp-irq_hist[15].timestamp;
	
always_ff @(posedge clk)
if (rst)
	stuck <= 1'b0;
else begin
	if (cs_io & reqd.we)
		case(reqd.padr[7:3])
		5'd5:
			if (reqd.dat[1]==1'b0)
				stuck <= 1'b0;
		default:	;
		endcase
	if (irq_hist[0].msg==irq_hist[15].msg && |irq_hist[0]) begin
		if (timestamp_dif[24]) begin
			if (-timestamp_dif[23:0] < 24'd1000)
				stuck <= 1'b1;
		end
		else begin
			if (timestamp_dif[23:0] < 24'd1000)
				stuck <= 1'b1;
		end
	end
end

genvar g;

generate begin : gQues
	for (g = 1; g <= NQUES; g = g + 1) begin
		// Always reading the queue output until an IRQ is detected.
		assign rd_en[g] = ~(irq & ~irq_ack) & ~rd_rst_busy[g];
		assign wr_en[g] = wr_en1[g] & ~rd_rst_busy[g] & ~wr_rst_busy[g] & ~rst;

		msi_fifo inst_fifo (
		  .clk(clk),                // input wire clk
		  .srst(rst),              // input wire srst
		  .din(fifo_din[g]),                // input wire [63 : 0] din
		  .wr_en(wr_en[g]),            // input wire wr_en
		  .rd_en(rd_en[g]),            // input wire rd_en
		  .dout(fifo_dout[g]),              // output wire [63 : 0] dout
		  .full(full[g]),              // output wire full
		  .overflow(overflow[g]),      // output wire overflow
		  .empty(empty[g]),            // output wire empty
		  .valid(valid[g]),            // output wire valid
		  .underflow(underflow[g]),    // output wire underflow
		  .data_count(data_count[g])  // output wire [4 : 0] data_count
		);
/*
// +---------------------------------------------------------------------------------------------------------------------+
// | USE_ADV_FEATURES     | String             | Default value = 0707.                                                   |
// |---------------------------------------------------------------------------------------------------------------------|
// | Enables data_valid, almost_empty, data_count, prog_empty, underflow, wr_ack, almost_full, wr_data_count,         |
// | prog_full, overflow features.                                                                                       |
// |                                                                                                                     |
// |   Setting USE_ADV_FEATURES[0] to 1 enables overflow flag; Default value of this bit is 1                            |
// |   Setting USE_ADV_FEATURES[1] to 1 enables prog_full flag; Default value of this bit is 1                           |
// |   Setting USE_ADV_FEATURES[2] to 1 enables wr_data_count; Default value of this bit is 1                            |
// |   Setting USE_ADV_FEATURES[3] to 1 enables almost_full flag; Default value of this bit is 0                         |
// |   Setting USE_ADV_FEATURES[4] to 1 enables wr_ack flag; Default value of this bit is 0                              |
// |   Setting USE_ADV_FEATURES[8] to 1 enables underflow flag; Default value of this bit is 1                           |
// |   Setting USE_ADV_FEATURES[9] to 1 enables prog_empty flag; Default value of this bit is 1                          |
// |   Setting USE_ADV_FEATURES[10] to 1 enables data_count; Default value of this bit is 1                           |
// |   Setting USE_ADV_FEATURES[11] to 1 enables almost_empty flag; Default value of this bit is 0                       |
// |   Setting USE_ADV_FEATURES[12] to 1 enables data_valid flag; Default value of this bit is 0                         |


   // xpm_fifo_sync: Synchronous FIFO
   // Xilinx Parameterized Macro, version 2024.1

   xpm_fifo_sync #(
      .CASCADE_HEIGHT(0),            // DECIMAL
      .DOUT_RESET_VALUE("0"),        // String
      .ECC_MODE("no_ecc"),           // String
      .EN_SIM_ASSERT_ERR("warning"), // String
      .FIFO_MEMORY_TYPE("distributed"),	// String
      .FIFO_READ_LATENCY(1),         // DECIMAL
      .FIFO_WRITE_DEPTH(32),	       // DECIMAL
      .FULL_RESET_VALUE(0),          // DECIMAL
      .PROG_EMPTY_THRESH(10),        // DECIMAL
      .PROG_FULL_THRESH(10),         // DECIMAL
      .RD_DATA_COUNT_WIDTH(5),      // DECIMAL
      .READ_DATA_WIDTH($bits(address_data_t)),
      .READ_MODE("std"),             // String
      .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_ADV_FEATURES("0707"),     // String
      .WAKEUP_TIME(0),               // DECIMAL
      .WRITE_DATA_WIDTH($bits(address_data_t)),
      .WR_DATA_COUNT_WIDTH(5)       // DECIMAL
   )
   xpm_fifo_sync_inst (
      .almost_empty(),   						 // 1-bit output: Almost Empty : When asserted, this signal indicates that
                                     // only one more read can be performed before the FIFO goes to empty.
      .almost_full(almost_full[g]),  // 1-bit output: Almost Full: When asserted, this signal indicates that
                                     // only one more write can be performed before the FIFO is full.

      .data_valid(data_valid[g]),    // 1-bit output: Read Data Valid: When asserted, this signal indicates
                                     // that valid data is available on the output bus (dout).

      .dbiterr(),					           // 1-bit output: Double Bit Error: Indicates that the ECC decoder detected
                                     // a double-bit error and data in the FIFO core is corrupted.

      .dout(fifo_dout[g]),           // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
                                     // when reading the FIFO.

      .empty(empty[g]),              // 1-bit output: Empty Flag: When asserted, this signal indicates that the
                                     // FIFO is empty. Read requests are ignored when the FIFO is empty,
                                     // initiating a read while empty is not destructive to the FIFO.

      .full(full[g]),                // 1-bit output: Full Flag: When asserted, this signal indicates that the
                                     // FIFO is full. Write requests are ignored when the FIFO is full,
                                     // initiating a write when the FIFO is full is not destructive to the
                                     // contents of the FIFO.

      .overflow(overflow[g]),        // 1-bit output: Overflow: This signal indicates that a write request
                                     // (wren) during the prior clock cycle was rejected, because the FIFO is
                                     // full. Overflowing the FIFO is not destructive to the contents of the
                                     // FIFO.

      .prog_empty(),					       // 1-bit output: Programmable Empty: This signal is asserted when the
                                     // number of words in the FIFO is less than or equal to the programmable
                                     // empty threshold value. It is de-asserted when the number of words in
                                     // the FIFO exceeds the programmable empty threshold value.

      .prog_full(),					         // 1-bit output: Programmable Full: This signal is asserted when the
                                     // number of words in the FIFO is greater than or equal to the
                                     // programmable full threshold value. It is de-asserted when the number of
                                     // words in the FIFO is less than the programmable full threshold value.

      .data_count(data_count[g]), // RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates the
                                     // number of words read from the FIFO.

      .rd_rst_busy(rd_rst_busy[g]),  // 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read
                                     // domain is currently in a reset state.

      .sbiterr(),				             // 1-bit output: Single Bit Error: Indicates that the ECC decoder detected
                                     // and fixed a single-bit error.

      .underflow(underflow[g]),      // 1-bit output: Underflow: Indicates that the read request (rd_en) during
                                     // the previous clock cycle was rejected because the FIFO is empty. Under
                                     // flowing the FIFO is not destructive to the FIFO.

      .wr_ack(),               			// 1-bit output: Write Acknowledge: This signal indicates that a write
                                     // request (wr_en) during the prior clock cycle is succeeded.

      .wr_data_count(wr_data_count[g]),	// WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates
                                     // the number of words written into the FIFO.

      .wr_rst_busy(wr_rst_busy[g]),  // 1-bit output: Write Reset Busy: Active-High indicator that the FIFO
                                     // write domain is currently in a reset state.

      .din(fifo_din[g]),             // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
                                     // writing the FIFO.

      .injectdbiterr(1'b0), 				// 1-bit input: Double Bit Error Injection: Injects a double bit error if
                                     // the ECC feature is used on block RAMs or UltraRAM macros.

      .injectsbiterr(1'b0), 				// 1-bit input: Single Bit Error Injection: Injects a single bit error if
                                     // the ECC feature is used on block RAMs or UltraRAM macros.

      .rd_en(rd_en[g]),              // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
                                     // signal causes data (on dout) to be read from the FIFO. Must be held
                                     // active-low when rd_rst_busy is active high.

      .rst(rst),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
                                     // unstable at the time of applying reset, but reset must be released only
                                     // after the clock(s) is/are stable.

      .sleep(1'b0),	                 // 1-bit input: Dynamic power saving- If sleep is High, the memory/fifo
                                     // block is in power saving mode.

      .wr_clk(wr_clk),               // 1-bit input: Write clock: Used for write operation. wr_clk must be a
                                     // free running clock.

      .wr_en(wr_en[g])               // 1-bit input: Write Enable: If the FIFO is not full, asserting this
                                     // signal causes data (on din) to be written to the FIFO Must be held
                                     // active-low when rst or wr_rst_busy or rd_rst_busy is active high

   );
*/
	end
end
endgenerate

ivtbl_ram ivtram1 (
  .clka(clka),    // input wire clka
  .ena(ena),      // input wire ena
  .wea(wea),      // input wire [8 : 0] wea
  .addra(addra),  // input wire [9 : 0] addra
  .dina(dina),    // input wire [71 : 0] dina
  .douta(douta),  // output wire [71 : 0] douta
  .clkb(clkb),    // input wire clkb
  .enb(enb),      // input wire enb
  .web(web),      // input wire [8 : 0] web
  .addrb(addrb),  // input wire [9 : 0] addrb
  .dinb(dinb),    // input wire [71 : 0] dinb
  .doutb(doutb)  // output wire [71 : 0] doutb
);

endmodule
