`timescale 1ns / 10ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2024  Robert Finch, Waterloo
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
// ============================================================================

import fta_bus_pkg::*;
import wishbone_pkg::*;
import QuplsPkg::SIM;

//import nic_pkg::*;

//`define USE_GATED_CLOCK	1'b1
//`define HAS_MMU 1'b1
//`define HAS_FRAME_BUFFER 1'b1

module Qupls_soc(cpu_reset_n, sysclk_p, sysclk_n, led, sw, btnl, btnr, btnc, btnd, btnu, 
  ps2_clk, ps2_data, uart_rx_out, uart_tx_in,
  hdmi_tx_clk_p, hdmi_tx_clk_n, hdmi_tx_p, hdmi_tx_n,
//  ac_mclk, ac_adc_sdata, ac_dac_sdata, ac_bclk, ac_lrclk,
//  rtc_clk, rtc_data,
//  spiClkOut, spiDataIn, spiDataOut, spiCS_n,
//  sd_cmd, sd_dat, sd_clk, sd_cd, sd_reset,
//  pti_clk, pti_rxf, pti_txe, pti_rd, pti_wr, pti_siwu, pti_oe, pti_dat, spien,
  oled_sdin, oled_sclk, oled_dc, oled_res, oled_vbat, oled_vdd
  ,ddr3_ck_p,ddr3_ck_n,ddr3_cke,ddr3_reset_n,ddr3_ras_n,ddr3_cas_n,ddr3_we_n,
  ddr3_ba,ddr3_addr,ddr3_dq,ddr3_dqs_p,ddr3_dqs_n,ddr3_dm,ddr3_odt
//    gtp_clk_p, gtp_clk_n,
//    dp_tx_hp_detect, dp_tx_aux_p, dp_tx_aux_n, dp_rx_aux_p, dp_rx_aux_n,
//    dp_tx_lane0_p, dp_tx_lane0_n, dp_tx_lane1_p, dp_tx_lane1_n
);
input cpu_reset_n;
input sysclk_p;
input sysclk_n;
output reg [7:0] led;
input [7:0] sw;
input btnl;
input btnr;
input btnc;
input btnd;
input btnu;
inout [1:0] ps2_clk;
tri [1:0] ps2_clk;
inout [1:0] ps2_data;
tri [1:0] ps2_data;
output uart_rx_out;
input uart_tx_in;
output hdmi_tx_clk_p;
output hdmi_tx_clk_n;
output [2:0] hdmi_tx_p;
output [2:0] hdmi_tx_n;
/*
output ac_mclk;
input ac_adc_sdata;
output reg ac_dac_sdata;
inout reg ac_bclk;
inout reg ac_lrclk;
inout rtc_clk;
tri rtc_clk;
inout rtc_data;
tri rtc_data;
output spiCS_n;
output spiClkOut;
output spiDataOut;
input spiDataIn;
inout sd_cmd;
tri sd_cmd;
inout [3:0] sd_dat;
tri [3:0] sd_dat;
output sd_clk;
input sd_cd;
output sd_reset;
*/
/*
input pti_clk;
input pti_rxf;
input pti_txe;
output pti_rd;
output pti_wr;
input spien;
output pti_siwu;
output pti_oe;
inout [7:0] pti_dat;
*/
output oled_sdin;
output oled_sclk;
output oled_dc;
output oled_res;
output oled_vbat;
output oled_vdd;

output [0:0] ddr3_ck_p;
output [0:0] ddr3_ck_n;
output [0:0] ddr3_cke;
output [0:0] ddr3_reset_n;
output [0:0] ddr3_ras_n;
output [0:0] ddr3_cas_n;
output [0:0] ddr3_we_n;
output [2:0] ddr3_ba;
output [14:0] ddr3_addr;
inout [31:0] ddr3_dq;
inout [3:0] ddr3_dqs_p;
inout [3:0] ddr3_dqs_n;
output [3:0] ddr3_dm;
output [0:0] ddr3_odt;

//input gtp_clk_p;
//input gtp_clk_n;
//input dp_tx_hp_detect;
//output dp_tx_aux_p;
//output dp_tx_aux_n;
//input dp_rx_aux_p;
//input dp_rx_aux_n;
//output dp_tx_lane0_p;
//output dp_tx_lane0_n;
//output dp_tx_lane1_p;
//output dp_tx_lane1_n;

wire rst, rstn;
wire xrst = ~cpu_reset_n;
wire locked,locked2;
wire clk10, clk20, clk25, clk17, clk40, clk50, clk67, clk100, clk200;
wire sysclk_p_bufg;
wire clk50, clk75, clk125;
wire node_clk = clk25;
fta_cmd_request256_t cpu_req;
fta_cmd_response256_t cpu_resp;
fta_cmd_request256_t rom_req;
fta_cmd_response256_t rom_resp;
fta_cmd_request256_t ch7req;
fta_cmd_request256_t ch7dreq;	// DRAM request
fta_cmd_request256_t ch7_areq;	// DRAM request
fta_cmd_response256_t ch7resp;
fta_cmd_response256_t ch7_aresp;
fta_cmd_request256_t fb_req;
fta_cmd_response256_t fb_resp, fb_resp1;
fta_cmd_request256_t fba_req;
fta_cmd_response256_t fba_resp;
reg [31:0] irq_bus;
fta_cycle_type_t cpu_cti;	// cycle type indicator
wire [3:0] cpu_cid;
wire [7:0] cpu_tid;
fta_burst_len_t cpu_blen;	// length of burst-1
wire cpu_cyc;
wire cpu_stb;
wire cpu_we;
wire [31:0] cpu_adr;
reg [31:0] cpu_adri;
wire [255:0] cpu_dato;
reg [3:0] cidi;
reg [7:0] tidi;
reg ack;
reg next;
wire vpa;
wire [15:0] sel;
reg [255:0] dati;
wire [255:0] dato;
wire mmus, ios, iops;
wire mmu_ack;
wire [31:0] mmu_dato;
fta_cmd_request256_t br1_req;
fta_cmd_response256_t br1_resp;
fta_cmd_request64_t br1_mreq;
wire br1_cyc;
wire br1_stb;
reg br1_ack;
wire br1_we;
wire [3:0] br1_sel;
wire [31:0] br1_adr;
wire [255:0] br1_cdato;
reg [31:0] br1_dati;
wire [31:0] br1_dato;
wire br1_cack;
wire [3:0] br1_cido;
wire [7:0] br1_tido;
fta_cmd_request256_t br3_req;
fta_cmd_response256_t br3_resp;
fta_cmd_response256_t br3_resp_o;
fta_cmd_request64_t br3_mreq;
wire br3_cyc;
wire br3_stb;
reg br3_ack;
wire br3_we;
wire [3:0] br3_sel;
wire [31:0] br3_adr;
wire [255:0] br3_cdato;
reg [31:0] br3_dati;
wire [31:0] br3_dato;
wire [3:0] br3_cido;
wire [7:0] br3_tido;
wire br3_cack;
fta_cmd_response256_t br4_resp;
fta_cmd_request32_t br4_mreq;

fta_cmd_response64_t fb_cresp;
fta_cmd_response64_t tc_cresp;
fta_cmd_response64_t leds_cresp;
wire fb_ack;
wire [31:0] fb_irq;
wire [31:0] fb_dato;
wire tc_ack;
wire [31:0] tc_dato;
wire kclk_en;
wire kdat_en;
wire kbd_ack;
wire [31:0] kbd_irq;
wire [31:0] kbd_dato;
wire rand_ack;
wire [31:0] rand_dato;
wire sema_ack;
wire [31:0] sema_dato;
wire scr_ack;
wire scr_next;
wire [255:0] scr_dato;
wire [31:0] scr_adro;
fta_tranid_t scr_tido;
wire [3:0] scr_cido;
wire acia_ack;
wire [31:0] acia_dato;
wire [31:0] acia_irq;
wire i2c2_ack;
wire [31:0] i2c2_dato;
wire [31:0] i2c2_irq;
wire pic_ack;
wire [3:0] pic_irq;
wire [31:0] pic_dato;
wire [7:0] pic_cause;
wire [5:0] pic_core;
wire mem_ui_clk;
wire [4:0] dram_state;
wire [7:0] asid;
wire io_ack;
wire [31:0] io_dato;
wire io_gate, io_gate_en;
wire config_to;
wire node_clk1, node_clk2, node_clk3;

wire leds_ack;
reg [7:0] rst_reg;
wire rst_ack;

wire hSync, vSync;
wire blank, border;
wire [9:0] red, blue, green;
wire [31:0] fb_rgb, tc_rgb;
assign red = tc_rgb[29:20];
assign green = tc_rgb[19:10];
assign blue = tc_rgb[9:0];

// -----------------------------------------------------------------------------
// Input debouncing
// -----------------------------------------------------------------------------

wire btnu_db, btnd_db, btnl_db, btnr_db, btnc_db;
BtnDebounce udbu (clk20, btnu, btnu_db);
BtnDebounce udbd (clk20, btnd, btnd_db);
BtnDebounce udbl (clk20, btnl, btnl_db);
BtnDebounce udbr (clk20, btnr, btnr_db);
BtnDebounce udbc (clk20, btnc, btnc_db);

// -----------------------------------------------------------------------------
// Clock generation
// -----------------------------------------------------------------------------

/*
IBUFG #(.IBUF_LOW_PWR("FALSE"),.IOSTANDARD("DEFAULT")) ubg1
(
  .I(sysclk_p),
  .O(sysclk_p_bufg)
);
*/

NexysVideoClkgen ucg1
(
  // Clock out ports
  .clk200(clk200),	// display / ddr3
  .clk100(clk100),
  .clk50(),		// cpu 4x
  .clk40(clk40),		// cpu 4x
  .clk20(clk20),		// cpu
  .clk10(clk10),
  .clk17(clk17),
//  .clk14(clk14),		// 16x baud clock
  // Status and control signals
  .reset(xrst), 
  .locked(locked),       // output locked
 // Clock in ports
  .clk_in1_p(sysclk_p),
  .clk_in1_n(sysclk_n)
);

cpuClkgen ucg2
(
  // Clock out ports
  .clk100(clk125),	// display / ddr3
  .clk60(clk75),
  .clk40(clk50),
  .clk20(clk25),		// cpu 4x
//  .clk14(clk14),		// 16x baud clock
  // Status and control signals
  .reset(xrst), 
  .locked(locked2),       // output locked
 // Clock in ports
  .clk_in1(clk100)
);

assign rst = !locked|!locked2;


rgb2dvi ur2d1
(
	.rst(rst),
	.PixelClk(clk40),
	.SerialClk(clk200),
	.red(red[9:2]),
	.green(green[9:2]),
	.blue(blue[9:2]),
	.de(~blank),
	.hSync(hSync),
	.vSync(vSync),
	.TMDS_Clk_p(hdmi_tx_clk_p),
	.TMDS_Clk_n(hdmi_tx_clk_n),
	.TMDS_Data_p(hdmi_tx_p),
	.TMDS_Data_n(hdmi_tx_n)
);

/*
generate begin : gRgb2dvi
if (!SIM) begin	
rgb2dvi #(
	.kGenerateSerialClk(1'b0),
	.ps2_clkPrimitive("MMCM"),
	.ps2_clkRange(3),
	.kRstActiveHigh(1'b1)
)
ur2d1 
(
	.TMDS_Clk_p(hdmi_tx_clk_p),
	.TMDS_Clk_n(hdmi_tx_clk_n),
	.TMDS_Data_p(hdmi_tx_p),
	.TMDS_Data_n(hdmi_tx_n),
	.aRst(rst),
	.aRst_n(~rst),
	.vid_pData({red[9:2],blue[9:2],green[9:2]}),
	.vid_pVDE(~blank),
	.vid_pHSync(hSync),    // hSync is neg going for 1366x768
	.vid_pVSync(vSync),
	.PixelClk(clk40),
	.SerialClk(clk200)
);
end
end
endgenerate
*/
wire cs_io;
assign cs_io = ios;//ch7req.adr[31:20]==12'hFD0;
wire cs_io2 = ch7req.padr[31:20]==12'hFD0;
// These two decodes outside the IO area.
wire cs_iobitmap;
assign cs_iobitmap = iops;	//ch7req.adr[31:16]==16'hFC10;
wire cs_mmu;
assign cs_mmu = mmus;	//cpu_adr[31:16]==16'hFC00 || cpu_adr[31:16]==16'hFC01;

wire cs_config = ch7req.padr[31:28]==4'hD;

wire cs_leds = ch7req.padr[19:8]==12'hFFF && ch7req.stb && cs_io2;
wire cs_br3_leds = br3_mreq.padr[31:8]==24'hFEDFFF && br3_mreq.stb;
wire cs_br3_rst  = br3_adr[19:8]==12'hFFC && br3_stb && cs_io2;
wire cs_sema = ch7req.padr[19:16]==4'h5 && ch7req.stb && cs_io2;
wire cs_scr = ch7req.padr[31:20]==12'h001;
wire cs_dram = ch7req.padr[31:29]==3'b001 && !cs_mmu && !cs_iobitmap && !cs_io;

assign io_gate_en = ch7req.padr[31:20]==12'hFEC
								 || ch7req.padr[31:20]==12'hFED
								 || ch7req.padr[31:20]==12'hFEE
								 || ch7req.padr[31:20]==12'hFEF
								 ;

`ifdef HAS_FRAME_BUFFER
rfFrameBuffer_fta64 uframebuf1
(
	.rst_i(rst),
	.irq_o(fb_irq),
	.cs_config_i(br1_mreq.padr[31:28]==4'hD),
	.cs_io_i(br1_mreq.padr[31:20]==12'hFED),
	.s_clk_i(node_clk),
	.s_req(br1_mreq),
	.s_resp(fb_cresp),
	.m_clk_i(clk40),
	.m_fst_o(), 
	.m_req(fb_req),
	.m_resp(sw[2] ? fb_resp1 : fb_resp),
	.dot_clk_i(clk40),
	.rgb_i('d0),
	.rgb_o(fb_rgb),
	.xonoff_i(sw[0]),
	.xal_o(),
	.hsync_o(hSync),
	.vsync_o(vSync),
	.blank_o(blank),
	.border_o(border),
	.hctr_o(),
	.vctr_o(),
	.fctr_o(),
	.vblank_o()
);
`else
parameter phSyncOn  = 40;		//   40 front porch
parameter phSyncOff = 168;		//  128 sync
parameter phBlankOff = 252;	//256	//   88 back porch
//parameter phBorderOff = 336;	//   80 border
parameter phBorderOff = 256;	//   80 border
//parameter phBorderOn = 976;		//  640 display
parameter phBorderOn = 1056;		//  800 display
parameter phBlankOn = 1052;		//   4 border
parameter phTotal = 1056;		// 1056 total clocks
parameter pvSyncOn  = 1;		//    1 front porch
parameter pvSyncOff = 5;		//    4 vertical sync
parameter pvBlankOff = 28;		//   23 back porch
parameter pvBorderOff = 28;		//   44 border	0
//parameter pvBorderOff = 72;		//   44 border	0
parameter pvBorderOn = 628;		//  600 display
//parameter pvBorderOn = 584;		//  512 display
parameter pvBlankOn = 628;  	//   44 border	0
parameter pvTotal = 628;		//  628 total scan lines

VGASyncGen usg1
(
	.rst(rst),
	.clk(clk40),
	.eol(),
	.eof(),
	.hSync(hSync),
	.vSync(vSync),
	.hCtr(),
	.vCtr(),
  .blank(blank),
  .vblank(),
  .vbl_int(),
  .border(border),
  .hTotal_i(phTotal),
  .vTotal_i(pvTotal),
  .hSyncOn_i(phSyncOn),
  .hSyncOff_i(phSyncOff),
  .vSyncOn_i(pvSyncOn),
  .vSyncOff_i(pvSyncOff),
  .hBlankOn_i(phBlankOn),
  .hBlankOff_i(phBlankOff),
  .vBlankOn_i(pvBlankOn),
  .vBlankOff_i(pvBlankOff),
  .hBorderOn_i(phBorderOn),
  .hBorderOff_i(phBorderOff),
  .vBorderOn_i(pvBorderOn),
  .vBorderOff_i(pvBorderOff)
);
assign fb_req = {$bits(fb_req){1'b0}};
`endif

VideoTPG uvtpg1
(
	.rst(rst),
	.clk(clk40),
	.en(sw[2]),
	.vSync(vSync),
	.req(fb_req),
	.resp(fb_resp1),
	.ex_resp()
);

fta_asynch2sync128 usas1
(
	.rst(rst),
	.clk(clk40),
	.req_i(fb_req),
	.resp_o(fb_resp),
	.req_o(fba_req),
	.resp_i(fba_resp)
);

rfTextController_fta64 utc1
(
	.rst_i(rst),
	.clk_i(node_clk),
	.cs_config_i(br1_mreq.padr[31:28]==4'hD),
	.cs_io_i(br1_mreq.padr[31:20]==12'hFEC),
	.req(br1_mreq),
	.resp(tc_cresp),
	.dot_clk_i(clk40),
	.hsync_i(hSync),
	.vsync_i(vSync),
	.blank_i(blank),
	.border_i(border),
	.zrgb_i(fb_rgb),
	.zrgb_o(tc_rgb),
	.xonoff_i(sw[1])
);


//assign fb_cresp = 'd0;
//assign tc_cresp = 'd0;

always_comb
begin
	br1_req = ch7req;
	br1_req.cyc = ch7req.cyc & io_gate_en;
	br1_req.stb = ch7req.stb & io_gate_en;
	br1_req.we = ch7req.we & io_gate_en;
end

IOBridge256to64fta ubridge1
(
	.rst_i(rst),
	.clk_i(node_clk),
	.clk5x_i(clk125),
	.s1_req(br1_req),
	.s1_resp(br1_resp),
	.m_req(br1_mreq),
	.ch0resp(tc_cresp),
	.ch1resp(fb_cresp)
);

fta_cmd_response32_t [3:0] br4_chresp;
assign br4_chresp[3] = 'd0;

PS2kbd_fta32 #(.pClkFreq(33333333)) ukbd1
(
	.rst_i(rst),
	.clk_i(node_clk),	// system clock
	.cs_config_i(br4_mreq.padr[31:28]==4'hD),
	.cs_io_i(br4_mreq.padr[31:20]==12'hFED),
	.req(br4_mreq),
	.resp(br4_chresp[0]),
	//-------------
	.kclk_i(ps2_clk[0]),	// keyboard clock from keyboard
	.kclk_en(ps2_clk_en),	// 1 = drive clock low
	.kdat_i(ps2_data[0]),	// keyboard data
	.kdat_en(kd_en)	// 1 = drive data low
);

assign ps2_clk[0] = kclk_en ? 1'b0 : 'bz;
assign ps2_data[0] = kdat_en ? 1'b0 : 'bz;
assign ps2_clk[1] = 'bz;
assign ps2_data[1] = 'bz;

random_fta32 urnd2
(
	.rst_i(rst),
	.clk_i(node_clk),
	.cs_config_i(br4_mreq.padr[31:28]==4'hD),
	.cs_io_i(br4_mreq.padr[31:20]==12'hFEE),
	.req(br4_mreq),
	.resp(br4_chresp[1])
);
/*
random urnd1
(
	.rst_i(rst),
	.clk_i(node_clk),
	.cs_config_i(cs_config),
	.cs_io_i(cs_io),
	.cyc_i(br3_cyc),
	.stb_i(br3_stb),
	.ack_o(rand_ack),
	.we_i(br3_we),
	.adr_i(br3_adr[31:0]),
	.dat_i(br3_dato),
	.dat_o(rand_dato)
);
*/
uart6551pci_fta32 #(.pClkFreq(25), .pClkDiv(24'd217)) uuart
(
	.rst_i(rst),
	.clk_i(node_clk),
	.cs_config_i(br4_mreq.padr[31:28]==4'hD),
	.cs_io_i(br4_mreq.padr[31:20]==12'hFED),
	.irq_o(acia_irq),
	.req(br4_mreq),
	.resp(br4_chresp[2]),
	.cts_ni(1'b0),
	.rts_no(),
	.dsr_ni(1'b0),
	.dcd_ni(1'b0),
	.dtr_no(),
	.ri_ni(1'b1),
	.rxd_i(uart_tx_in),
	.txd_o(uart_rx_out),
	.data_present(),
	.rxDRQ_o(),
	.txDRQ_o(),
	.xclk_i(clk20),
	.RxC_i(clk20)
);

wire rtc_clko, rtc_clkoen;
wire rtc_datao, rtc_dataoen;

i2c_master_top_pci32 ui2cm1
(
	.wb_clk_i(node_clk),
	.wb_rst_i(rst),
	.arst_i(~rst),
	.cs_config_i(cs_config),
	.cs_io_i(cs_io),
	.wb_sel_i(br3_sel),
	.wb_adr_i(br3_adr[31:0]),
	.wb_dat_i(br3_dato),
	.wb_dat_o(i2c2_dato),
	.wb_we_i(br3_we),
	.wb_stb_i(br3_stb),
	.wb_cyc_i(br3_cyc),
	.wb_ack_o(i2c2_ack),
	.wb_inta_o(i2c2_irq),
	.scl_pad_i(rtc_clk),
	.scl_pad_o(rtc_clko),
	.scl_padoen_o(rtc_clkoen),
	.sda_pad_i(rtc_data),
	.sda_pad_o(rtc_datao), 
	.sda_padoen_o(rtc_dataoen)
);
assign rtc_clk = rtc_clkoen ? 'bz : rtc_clko;
assign rtc_data = rtc_dataoen ? 'bz : rtc_datao;

/*
always_comb
begin
	br3_req = ch7req;
	br3_req.cyc = ch7req.cyc & io_gate_en;
	br3_req.stb = ch7req.stb & io_gate_en;
	br3_req.we = ch7req.we & io_gate_en;
end
*/
always_comb
begin
	br3_req = cpu_req;
end
/*
mem_gate #(
	.SIZE(64),
	.FUNC(2),
	.IO_ADDR_MASK(32'hFFFFFFC0),
	.IO_ADDR(32'hFEFFFF80)
) umemg1
(
	.rst(rst),
	.clk(node_clk),
	.age(1'b0),
	.cs(br3_req.padr[31:22]==10'b1111_1110_11),
	.fta_req_i(cpu_req),
	.fta_resp_o(br3_resp_o),
	.fta_req_o(br3_req),
	.fta_resp_i(br3_resp)
);
*/

IOBridge256to64fta ubridge3
(
	.rst_i(rst),
	.clk_i(node_clk),
	.clk5x_i(clk125),
	.s1_req(br3_req),
	.s1_resp(br3_resp),
	.m_req(br3_mreq),
	.ch0resp(leds_cresp),
	.ch1resp('d0)
);

IOBridge256to32fta #(.CHANNELS(4)) ubridge4
(
	.rst_i(rst),
	.clk_i(node_clk),
	.s1_req(br3_req),
	.s1_resp(br4_resp),
	.m_req(br4_mreq),
	.chresp(br4_chresp)
);

/*
IOBridge128wb ubridge3wb
(
	.rst_i(rst),
	.clk_i(node_clk),
	.s1_req(br3_req),
	.s1_resp(br3_resp),
	.s2_req('d0),
	.s2_resp(),
	.m_cyc_o(br3_cyc),
	.m_stb_o(br3_stb),
	.m_we_o(br3_we),
	.m_adr_o(br3_adr),
	.m64_ack_i(1'b0),
	.m64_sel_o(),
	.m64_dat_i('d0),
	.m64_dat_o(),
	.m32_ack_i(br3_ack),
	.m32_sel_o(br3_sel),
	.m32_dat_i(br3_dati),
	.m32_dat_o(br3_dato)
);
*/

always_ff @(posedge node_clk)
	casez(cs_br3_leds)
	1'b1:	br3_dati <= led;
	1'b0:	br3_dati <= i2c2_dato;
	default:	br3_dati <= 'd0;
	endcase

always_ff @(posedge node_clk, posedge rst)
if (rst)
	br3_ack <= 'd0;
else
	br3_ack <= i2c2_ack;

ledport_fta64 uleds1
(
	.rst(rst),
	.clk(node_clk),
	.cs(cs_br3_leds),
	.req(br3_mreq),
	.resp(leds_cresp),
	.led(led)
);

//assign leds_ack = cs_br3_leds;
//always_ff @(posedge node_clk)
//	if (cs_br3_leds & br3_we)
//		led <= br3_dato[7:0];

wire mem_ui_rst;
wire calib_complete;
wire [28:0] mem_addr;
wire [2:0] mem_cmd;
wire mem_en;
wire [127:0] mem_wdf_data;
wire [15:0] mem_wdf_mask;
wire mem_wdf_end;
wire mem_wdf_wren;
wire [127:0] mem_rd_data;
wire mem_rd_data_valid;
wire mem_rd_data_end;
wire mem_rdy;
wire mem_wdf_rdy;

mig_7series_0 uddr3
(
	.ddr3_dq(ddr3_dq),
	.ddr3_dqs_p(ddr3_dqs_p),
	.ddr3_dqs_n(ddr3_dqs_n),
	.ddr3_addr(ddr3_addr),
	.ddr3_ba(ddr3_ba),
	.ddr3_ras_n(ddr3_ras_n),
	.ddr3_cas_n(ddr3_cas_n),
	.ddr3_we_n(ddr3_we_n),
	.ddr3_ck_p(ddr3_ck_p),
	.ddr3_ck_n(ddr3_ck_n),
	.ddr3_cke(ddr3_cke),
	.ddr3_dm(ddr3_dm),
	.ddr3_odt(ddr3_odt),
	.ddr3_reset_n(ddr3_reset_n),
	// Inputs
	.sys_clk_i(clk100),
//    .clk_ref_i(clk200),
	.sys_rst(rstn),
	// user interface signals
	.app_addr(mem_addr),
	.app_cmd(mem_cmd),
	.app_en(mem_en),
	.app_wdf_data(mem_wdf_data),
	.app_wdf_end(mem_wdf_end),
	.app_wdf_mask(mem_wdf_mask),
	.app_wdf_wren(mem_wdf_wren),
	.app_rd_data(mem_rd_data),
	.app_rd_data_end(mem_rd_data_end),
	.app_rd_data_valid(mem_rd_data_valid),
	.app_rdy(mem_rdy),
	.app_wdf_rdy(mem_wdf_rdy),
	.app_sr_req(1'b0),
	.app_sr_active(),
	.app_ref_req(1'b0),
	.app_ref_ack(),
	.app_zq_req(1'b0),
	.app_zq_ack(),
	.ui_clk(mem_ui_clk),
	.ui_clk_sync_rst(mem_ui_rst),
	.init_calib_complete(calib_complete)
);

always_comb
begin
	ch7dreq <= ch7req;
//	ch7dreq.cid <= 4'd7;
	ch7dreq.cyc <= ch7req.cyc & cs_dram;
	ch7dreq.stb <= ch7req.stb & cs_dram;
end

fta_cmd_request256_t mr_req = 'd0;
/*
MemoryRandomizer umr1
(
	.rst(rst),
	.clk(node_clk),
	.req(mr_req)
);
*/

mpmc11_fta umpmc1
(
	.rst(rst),
	.clk100MHz(clk100),
	.mem_ui_rst(mem_ui_rst),
	.mem_ui_clk(mem_ui_clk),
	.calib_complete(calib_complete),
	.rstn(rstn),
	.app_waddr(),
	.app_rdy(mem_rdy),
	.app_en(mem_en),
	.app_cmd(mem_cmd),
	.app_addr(mem_addr),
	.app_rd_data_valid(mem_rd_data_valid),
	.app_wdf_mask(mem_wdf_mask),
	.app_wdf_data(mem_wdf_data),
	.app_wdf_rdy(mem_wdf_rdy),
	.app_wdf_wren(mem_wdf_wren),
	.app_wdf_end(mem_wdf_end),
	.app_rd_data(mem_rd_data),
	.app_rd_data_end(mem_rd_data_end),
	.ch0clk(clk40),
	.ch1clk(1'b0),
	.ch2clk(1'b0),
	.ch3clk(1'b0),
	.ch4clk(1'b0),
	.ch5clk(1'b0),
	.ch6clk(1'b0),
	.ch7clk(node_clk),
	.ch0i(fba_req),
	.ch0o(fba_resp),
	.ch1i(mr_req),
	.ch1o(),
	.ch2i('d0),
	.ch2o(),
	.ch3i('d0),
	.ch3o(),
	.ch4i('d0),
	.ch4o(),
	.ch5i('d0),
	.ch5o(),
	.ch6i('d0),
	.ch6o(),
	.ch7i(ch7_areq),
	.ch7o(ch7_aresp),
	.state(dram_state)
);

fta_asynch2sync256 usas7
(
	.rst(rst),
	.clk(node_clk),
	.req_i(ch7dreq),
	.resp_o(ch7resp),
	.req_o(ch7_areq),
	.resp_i(ch7_aresp)
);

fta_cmd_response256_t [1:0] resps;
fta_cmd_response256_t [3:0] resps1;
fta_cmd_response256_t [3:0] resps2;

binary_semamem_pci32 usema1
(
	.rst_i(rst),
	.clk_i(node_clk),
	.cs_config_i(cs_config),
	.cs_io_i(cs_io),
	.cyc_i(ch7req.cyc),
	.stb_i(ch7req.stb),
	.ack_o(sema_ack),
	.sel_i(ch7req.sel[15:12]|ch7req.sel[11:8]|ch7req.sel[7:4]|ch7req.sel[3:0]),
	.we_i(ch7req.we),
	.adr_i(ch7req.padr[31:0]),
	.dat_i(dato[31:0]),
	.dat_o(sema_dato)
);
/*
mem_gate #(
	.SIZE(8),
	.FUNC(1),
	.IO_ADDR_MASK(32'hFFFFFFF0),
	.IO_ADDR(32'hFEFFFFF0)
) umemg2
(
	.rst(rst),
	.clk(node_clk),
	.age(1'b0),
	.cs(cpu_req.padr[31:20]==12'hFFF),
	.fta_req_i(cpu_req),
	.fta_resp_o(resps2[0]),
	.fta_req_o(rom_req),
	.fta_resp_i(rom_resp)
);
*/
scratchmem256_fta
#(
	.IO_ADDR(32'hFFF80001),
	.CFG_FUNC(3'd0)
)
uscr1
(
	.rst_i(rst),
	.cs_config_i(cpu_req.padr[31:28]==4'hD),
	.cs_ram_i(cpu_req.padr[31:24]==8'hFF),
	.clk_i(node_clk),
	.req(cpu_req),
	.resp(resps2[0]),
	.ip('d0),
	.sp('d0)
);
/*
scratchmem128pci_fta
#(
	.IO_ADDR(32'hFFF80001),
	.CFG_FUNC(3'd1)
)
uscr2
(
	.rst_i(rst),
	.cs_config_i(cs_config),
	.cs_ram_i(cpu_req.padr[31:24]==8'hFF),
	.clk_i(node_clk),
	.req(cpu_req),
	.resp(resps[6]),
	.ip('d0),
	.sp('d0)
);
*/
/*
io_bitmap uiob1
(
	.clk_i(node_clk),
	.cs_i(cs_iobitmap),
	.cyc_i(ch7req.cyc),
	.stb_i(ch7req.stb),
	.ack_o(io_ack),
	.we_i(ch7req.we),
	.asid_i(asid),
	.adr_i(ch7req.adr[19:0]),
	.dat_i(dato),
	.dat_o(io_dato),
	.iocs_i(cs_io),
	.gate_o(cs_io2),
	.gate_en(io_gate_en)
);
*/
//assign io_irq = cs_io & ~cs_io2 & io_gate_en;

//packet_t [5:0] packet;
//packet_t [5:0] rpacket;
//ipacket_t [5:0] ipacket;

// Generate 100Hz interrupt
reg [23:0] icnt;
reg tmr_irq;

always @(posedge clk125)
if (rst) begin
	icnt <= 24'd1;
	tmr_irq <= 1'b0;
end
else begin
	icnt <= icnt + 2'd1;
	if (icnt==24'd150)
		tmr_irq <= 1'b1;
	else if (icnt==24'd200)
		tmr_irq <= 1'b0;
	else if (icnt==24'd1250000)
		icnt <= 24'd1;
end

always_comb
	irq_bus = fb_irq|acia_irq|kbd_irq|i2c2_irq;

wire bus_err;
BusError ube1
(
	.rst_i(rst),
	.clk_i(node_clk),
	.cyc_i(ch7req.cyc),
	.ack_i(1'b1),
	.stb_i(ch7req.stb),
	.adr_i(ch7req.padr),
	.err_o(bus_err)
);

reg [6:0] rst_cnt;
reg [15:0] rsts;
reg [15:0] clken_reg;

`ifdef HAS_MMU
mmu ummu1
(
	.rst_i(rst),
	.clk_i(node_clk),
	.cs_config_i(cs_config),
	.cs_io_i(cs_io),
	.s_seg_i(ch7req.seg),
	.s_cyc_i(cpu_cyc),
	.s_stb_i(cpu_stb),
	.s_ack_o(mmu_ack),
	.s_we_i(cpu_we),
	.s_asid_i(asid),
	.s_adr_i(cpu_adr),
	.s_dat_i(cpu_dato),
	.s_dat_o(mmu_dato),
  .pea_o(ch7req.padr),
  .pdat_o(dato),
  .cyc_o(ch7req.cyc),
  .stb_o(ch7req.stb),
  .we_o(ch7req.we),
  .exv_o(),
  .rdv_o(),
  .wrv_o()
);
`else
assign dato = cpu_dato;
assign ch7req = cpu_req;
/*
assign ch7req.blen = cpu_blen;
assign ch7req.cti = cpu_cti;
assign ch7req.cid = cpu_cid;
assign ch7req.tid = cpu_tid;
assign ch7req.cyc = cpu_cyc;
assign ch7req.stb = cpu_stb;
assign ch7req.we = cpu_we;
assign ch7req.padr = cpu_adr;
*/
assign mmu_ack = 1'b0;
assign mmu_dato = 'd0;
`endif

/*
rf68000_nic unic1
(
	.id(6'd62),			// system node id
	.rst_i(rst),
	.clk_i(node_clk),

	.s_cti_i(3'd0),
	.s_atag_o(),
	.s_cyc_i(1'b0),
	.s_stb_i(1'b0),
	.s_ack_o(),
	.s_aack_o(),
	.s_rty_o(),
	.s_err_o(),
	.s_vpa_o(),
	.s_we_i(1'b0),
	.s_sel_i(4'h0),
	.s_adr_i(32'h0),
	.s_dat_i(32'h0),
	.s_dat_o(),
	.s_asid_i('d0),
	.s_mmus_i(1'b0),
	.s_ios_i(1'b0),
	.s_iops_i(1'b0),

	.m_cyc_o(cpu_cyc),
	.m_stb_o(cpu_stb),
	.m_ack_i(ack),
	.m_err_i(bus_err),
	.m_vpa_i(vpa),
	.m_we_o(cpu_we),
	.m_sel_o(sel),
	.m_asid_o(asid),
	.m_mmus_o(mmus),
	.m_ios_o(ios),
	.m_iops_o(iops),
	.m_adr_o(cpu_adr),
	.m_dat_o(cpu_dato),
	.m_dat_i(dati),

	.packet_i(packet[0]),//clken_reg[3] ? packet[2] : clken_reg[2] ? packet[1] : packet[0]),
	.packet_o(packet[3]),
	.ipacket_i(ipacket[0]),//clken_reg[3] ? ipacket[2] : clken_reg[2] ? ipacket[1] : ipacket[0]),
	.ipacket_o(ipacket[3]),
	.rpacket_i(rpacket[0]),//clken_reg[3] ? rpacket[2] : clken_reg[2] ? rpacket[1] : rpacket[0]),
	.rpacket_o(rpacket[3]),

	.irq_i(pic_irq[2:0]),
	.firq_i(1'b0),
	.cause_i(pic_cause),
	.iserver_i(pic_core),
	.irq_o(),
	.firq_o(),
	.cause_o()
);

nic_ager uager1
(
	.clk_i(node_clk),
	.packet_i(packet[3]),
	.packet_o(packet[4]),
	.ipacket_i(ipacket[3]),
	.ipacket_o(ipacket[4]), 
	.rpacket_i(rpacket[3]),
	.rpacket_o(rpacket[4])
);
*/
/*
ila_0 uila1 (
	.clk(clk100), // input wire clk
	.probe0(umpu1.ucpu1.pc), // input wire [15:0]  probe0  
	.probe1('d0), // input wire [31:0]  probe1 
	.probe2('d0),
	.probe3('d0),
	.probe4({
		umpu1.ucpu1.excmiss,
		utc1.rwr_i,
		io_gate_en}
	),
	.probe5('d0),
	.probe6('d0)
);
*/
/*
ila_0 your_instance_name (
	.clk(clk100), // input wire clk

	.probe0(unode1.ucpu1.ir), // input wire [15:0]  probe0  
	.probe1(cpu_adr), // input wire [31:0]  probe1 
	.probe2(dato), // input wire [31:0]  probe2 
	.probe3({cpu_cyc,cpu_stb,ack,cs_io2,cs_io,ch7req.stb,cpu_we}), // input wire [7:0]  probe3
	.probe4(unode1.ucpu1.pc),
	.probe5({dram_state,unode1.ucpu1.ios_o,ios}),
	.probe6(unode1.ucpu1.state),
	.probe7(mem_wdf_mask),
	.probe8({umpmc1.req_fifoo.stb,umpmc1.req_fifoo.we}),
	.probe9(umpmc1.req_fifoo.sel),
	.probe10(unode1.ucpu1.dfdivo[95:64])
);
*/
config_timout_ctr ucfgtoctr1
(
	.rst(rst),
	.clk(node_clk),
	.cs(cs_config),
	.o(config_to)
);

fta_respbuf256 #(.CHANNELS(4)) urspbuf1
(
	.rst(rst),
	.clk(node_clk),
	.clk5x(clk125),
	.resp(resps1),
	.resp_o(resps[0])
);

fta_respbuf256 #(.CHANNELS(4)) urspbuf2
(
	.rst(rst),
	.clk(node_clk),
	.clk5x(clk125),
	.resp(resps2),
	.resp_o(resps[1])
);

fta_respbuf256 #(.CHANNELS(2)) urspbuf3
(
	.rst(rst),
	.clk(node_clk),
	.clk5x(clk125),
	.resp(resps),
	.resp_o(cpu_resp)
);

assign resps1[0] = fta_cmd_response256_t'(ch7resp);
assign resps1[1] = br1_resp;
assign resps1[2] = br3_resp;
assign resps1[3].tid = cpu_tid;
assign resps1[3].ack = sema_ack;
assign resps1[3].next = 1'b0;
assign resps1[3].dat = {4{sema_dato}};
assign resps1[3].adr = cpu_adr;
assign resps2[1] = br4_resp;
assign resps2[2] = {$bits(fta_cmd_response256_t){1'b0}};
assign resps2[3] = {$bits(fta_cmd_response256_t){1'b0}};

//assign ch7req.sel = ch7req.we ? sel << {ch7req.padr[3:2],2'b0} : 16'hFFFF;
//assign ch7req.data1 = {4{dato}};
/*
always_ff @(posedge node_clk)
if (config_to)
	dati <= {128{1'b1}};
else if (cs_dram)
	dati <= ch7resp.dat;
else
	dati <= br1_cdato|br3_cdato|{4{sema_dato}}|scr_dato|mmu_dato;
*/
//always_ff @(posedge node_clk)
//	cpu_adri <= scr_adro;
/*
always_ff @(posedge node_clk)
	ack <= ch7resp.ack|br1_cack|br3_cack|sema_ack|scr_ack|mmu_ack|config_to;
*/
always_ff @(posedge node_clk)
	next <= scr_next;
//always_ff @(posedge node_clk)
//	tidi <= scr_tido|br1_tido|br3_tido;
always_ff @(posedge node_clk)
if (rst) begin
	rst_cnt <= 'd0;
	rst_reg <= 16'h0000;
	clken_reg <= 16'h00000006;
end
else begin
	if (cs_br3_rst) begin
		if (|sel[1:0]) begin
			rst_reg <= br3_dato[15:0];
			rst_cnt <= 'd0;
			clken_reg[2] <= clken_reg[2] | |br3_dato[5:4];
			//clken_reg[3] <= clken_reg[3] | |br3_dato[7:6];
		end
		if (|sel[3:2])
			clken_reg[2:0] <= br3_dato[18:16];
	end
	if (~rst_cnt[6])
		rst_cnt <= rst_cnt + 2'd1;
	else
		rst_reg <= 'd0;
end
assign rst_ack = cs_br3_rst;
always_comb
	rsts <= {16{~rst_cnt[6]}} & rst_reg;

assign node_clk1 = node_clk;
`ifdef USE_GATED_CLOCK
BUFGCE uce2 (.CE(clken_reg[2]), .I(node_clk), .O(node_clk2));
BUFGCE uce3 (.CE(clken_reg[3]), .I(node_clk), .O(node_clk3));
`else
assign node_clk2 = node_clk;
assign node_clk3 = node_clk;
`endif

Qupls_mpu umpu1
(
	.rst_i(rst),
	.clk_i(node_clk),
	.clk2x_i(clk50),
	.clk3x_i(clk75),
	.clk5x_i(clk125),
	.ftam_req(cpu_req),
	.ftam_resp(cpu_resp),
	.irq_bus(irq_bus),
	.clk0(1'b0),
	.gate0(1'b0),
	.out0(),
	.clk1(1'b0),
	.gate1(1'b0),
	.out1(),
	.clk2(1'b0),
	.gate2(1'b0),
	.out2(),
	.clk3(1'b0),
	.gate3(1'b0),
	.out3()
);

assign cpu_blen = cpu_req.blen;
assign cpu_cti = cpu_req.cti;
assign cpu_tid = cpu_req.tid;
assign cpu_cyc = cpu_req.cyc;
assign cpu_stb = cpu_req.stb;
assign cpu_we = cpu_req.we;
assign sel = cpu_req.sel;
assign asid = cpu_req.asid;
assign cpu_adr = cpu_req.padr;
assign cpu_dato = cpu_req.data1;

/*
ila_0 uila1 (
	.clk(clk100), // input wire clk
	.probe0(umpu1.ucpu1.pc), // input wire [31:0]  probe0  
	.probe1(umpu1.ucpu1.ir2), // input wire [47:0]  probe1 
	.probe2(umpu1.ucpu1.fta_req.padr),		// 32
	.probe3(umpu1.ucpu1.state),	// 8
	.probe4(umpu1.ucpu1.fta_req.data1),		// 32
	.probe5(umpu1.ucpu1.fta_resp.dat)							// 8
);
*/
/*
assign cpu_resp.tid = tidi;
assign cpu_resp.cid = cidi;
assign cpu_resp.err = bus_err;
assign cpu_resp.ack = ack;
assign cpu_resp.next = next;
assign cpu_resp.rty = 1'b0;
assign cpu_resp.stall = 1'b0;
assign cpu_resp.adr = cpu_adri;
assign cpu_resp.dat = dati;
*/
endmodule
