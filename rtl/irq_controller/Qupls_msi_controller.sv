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
// 7700 LUTs / 8000 FFs / 6/11 BRAMs	(63 priority levels)
// 1900 LUTs / 2200 FFs / 6/11 BRAMS (7 priority levels)
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
	logic [5:0] resv;
	logic [5:0] cpu_coreno;
	logic [2:0] swstk;
	logic mask;					// 1=interrupt masked
	logic [31:0] dat;		// data for ISR
	logic [39:0] adr;		// ISR address
} msi_svec_t;					// 88 bits

typedef struct packed
{
	logic [21:0] resv;
	logic [5:0] cpu_coreno;
	logic [2:0] swstk;
	logic mask;					// 1=interrupt masked
	logic [31:0] dat;		// data for ISR
	logic [63:0] adr;		// ISR address
} msi_vec_t;

module Qupls_msi_controller(coreno, rst, clk, cs_config_i, req, resp,
	ipl, irq_resp_i, irq, ivect_o, ipri, swstk, irq_ack);
input [5:0] coreno;
input rst;
input clk;
input cs_config_i;
input fta_cmd_request64_t req;
output fta_cmd_response64_t resp;
// CPU interface
input [5:0] ipl;
input fta_cmd_response256_t irq_resp_i;
output reg [63:0] irq;
output reg [39:0] ivect_o;
output reg [5:0] ipri;
output reg [2:0] swstk;
input irq_ack;

parameter NQUES = 7;
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


integer nn,jj,n0,n1,n2,n3;

reg erc;
reg [63:0] uvtbl_base_adr;			// user mode vector table
reg [63:0] svtbl_base_adr;			// supervisor mode
reg [63:0] hvtbl_base_adr;			// hypervisor mode
reg [63:0] mvtbl_base_adr;			// machine mode
reg [63:0] vtbl_limit;
fta_imessage_t que_dout;
fta_imessage_t imsg,imsg2;
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
wire respack;
wire [12:0] resptid;
reg [1:0] oma;
(* ram_style="distributed" *)
reg [63:0] coreset [0:63];

always_comb
	imsg = {irq_resp_i.adr[39:0],irq_resp_i.dat[31:0]};

always_ff @(posedge clk)
	reqd <= req;

always_ff @(posedge clk)
	cs_config <= cs_config_i;

wire cs_pic;
always_comb
	cs_io = cs_pic;

always_ff @(posedge clk_i)
	erc <= req.cti==fta_bus_pkg::ERC;

vtdl #(.WID(1), .DEP(16)) urdyd2 (.clk(clk_i), .ce(1'b1), .a(4'd0), .d((cs_io)&(erc|~reqd.we)), .q(respack));
always_ff @(posedge clk)
if (rst)
	resp <= {$bits(fta_cmd_response64_t){1'b0}};
else begin
	if (cfg_resp.ack)
		resp <= cfg_resp;
	else if (cs_io) begin
		resp.ack <= respack ? reqd.cyc : 1'b0;
		resp.tid <= respack ? reqd.tid : 13'd0;
		resp.next <= 1'b0;
		resp.stall <= 1'b0;
		resp.err <= fta_bus_pkg::OKAY;
		resp.rty <= 1'b0;
		resp.pri <= 4'd5;
		resp.adr <= respack ? reqd.padr : 40'd0;
		resp.dat <= respack ? dat_o : 64'd0;
	end
end


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
		casez(reqd.padr[9:3])
		7'd0:	dat_o <= uvtbl_base_adr;
		7'd1:	dat_o <= svtbl_base_adr;
		7'd2:	dat_o <= hvtbl_base_adr;
		7'd3:	dat_o <= mvtbl_base_adr;
		7'd4:	dat_o <= vtbl_limit;
		7'd5:	
			begin
				dat_o[0] <= que_full;
				dat_o[1] <= stuck;
				dat_o[62:2] <= 61'd0;
				dat_o[63] <= irq;
			end
		7'd6:	dat_o <= que_dout[31:0];
		7'd7:	dat_o <= que_dout[39:32];
		7'd8:	dat_o <= empty;
		7'd9:	dat_o <= overflow;
		7'b1??????:	dat_o <= coreset[reqd.padr[8:3]];
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
	
initial begin
	// Default to 1:1 mapping
	for (n2 = 0; n2 < 64; n2 = n2 + 1)
		case(n2)
		0: coreset[n2] = 64'd0;
		63:	coreset[n2] = 64'hFFFFFFFFFFFFFFFF;
		default:	coreset[n2] = 64'd1 << n2;
		endcase
end

// write registers	
always_ff @(posedge clk)
if (rst) begin
	uvtbl_base_adr <= 64'd0;
	svtbl_base_adr <= 64'd0;
	hvtbl_base_adr <= 64'd0;
	mvtbl_base_adr <= 64'd0;
	que_full <= 1'b0;
end
else begin
	if (|full)
		que_full <= 1'b1;
	if (cs_io & reqd.we)
		casez(reqd.padr[9:3])
		7'd0:	uvtbl_base_adr <= reqd.dat[63:0];
		7'd1:	svtbl_base_adr <= reqd.dat[63:0];
		7'd2:	hvtbl_base_adr <= reqd.dat[63:0];
		7'd3:	mvtbl_base_adr <= reqd.dat[63:0];
		7'd4:	vtbl_limit <= {53'd0,reqd.dat[10:0]};
		7'd5:
			begin
				if (reqd.dat[0]==1'b0)
					que_full <= 1'b0;
			end
		7'b1??????:	coreset[reqd.padr[8:3]] <= reqd.dat[63:0];
		default:	;
		endcase
end

always_comb
	case(que_dout.om)
	2'd0:	oma = uvtbl_base_adr[1:0];
	2'd1:	oma = svtbl_base_adr[1:0];
	2'd2:	oma = hvtbl_base_adr[1:0];
	2'd3:	oma = mvtbl_base_adr[1:0];
	endcase
always_comb
	addra = reqd.padr[14:4];
always_comb
	addrb = {oma,9'd0} + que_dout.vecno[10:0];
always_comb
	dina = reqd.padr[3] ? {reqd.dat[47:0],40'd0} : {48'h0,reqd.dat[39:0]};
always_comb
	dinb = 88'd0;
always_comb
	ena = cs_io && reqd.padr[15]==1'b0;
always_comb
	enb = 1'b1;
always_comb
	wea = {11{reqd.we}} & {reqd.padr[3] ? {reqd.sel[5:0],5'h0} : {6'h0,reqd.sel[4:0]}};
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
	que_dout <= (que_sel==7'd127) ? 80'd0 : fifo_dout[qsel];
always_ff @(posedge clk)
	irq2 <= ~&empty && (que_sel != 7'd127) && (qsel > ipl || qsel==6'd63);
always_ff @(posedge clk)
	irq1 <= irq2;
always_comb
	irq = {64{irq1 & ~doutb.mask}} & coreset[doutb.cpu_coreno];
always_comb
	swstk = doutb.swstk;
always_ff @(posedge clk)
	ipri2 <= que_sel;
always_ff @(posedge clk)
	ipri <= ipri2;

// Always writing interrupts into the queue.
always_ff @(posedge clk)
	for (nn = 1; nn <= NQUES; nn = nn + 1)
		if (irq_resp_i.pri==nn)
			wr_en1[nn] <= irq_resp_i.err==fta_bus_pkg::IRQ && imsg.irq_coreno==coreno;
		else
			wr_en1[nn] <= 1'b0;

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
		always_ff @(posedge clk)
			fifo_din[g] <= imsg;

		msi_fifo inst_fifo (
		  .clk(clk),                // input wire clk
		  .srst(rst),              // input wire srst
		  .din(fifo_din[g]),                // input wire [71 : 0] din
		  .wr_en(wr_en[g]),            // input wire wr_en
		  .rd_en(rd_en[g]),            // input wire rd_en
		  .dout(fifo_dout[g]),              // output wire [71 : 0] dout
		  .full(full[g]),              // output wire full
		  .overflow(overflow[g]),      // output wire overflow
		  .empty(empty[g]),            // output wire empty
		  .valid(valid[g]),            // output wire valid
		  .underflow(underflow[g]),    // output wire underflow
		  .data_count(data_count[g])  // output wire [4 : 0] data_count
		);
	end
end
endgenerate

ivtbl_ram ivtram1 (
  .clka(clka),    // input wire clka
  .ena(ena),      // input wire ena
  .wea(wea),      // input wire [9 : 0] wea
  .addra(addra),  // input wire [10 : 0] addra
  .dina(dina),    // input wire [79 : 0] dina
  .douta(douta),  // output wire [79 : 0] douta
  .clkb(clkb),    // input wire clkb
  .enb(enb),      // input wire enb
  .web(web),      // input wire [9 : 0] web
  .addrb(addrb),  // input wire [10 : 0] addrb
  .dinb(dinb),    // input wire [79 : 0] dinb
  .doutb(doutb)  // output wire [79 : 0] doutb
);

endmodule
