`timescale 1ns / 1ps

module Qupls5_tb();

reg rst;
reg clk;
reg [7:0] rstcnt = 8'd0;
wire [6:0] state;
wire [7:0] led;

initial begin
	clk = 1'b0;
end
always
 #2.5 clk = ~clk;
 
always_ff @(posedge clk)
if (!rstcnt[6])
	rstcnt <= rstcnt + 2'd1;
always_comb
	rst = rstcnt < 8'd64;

Qupls5_soc usoc1
(
	.cpu_reset_n(~rst),
	.sysclk_p(clk),
	.sysclk_n(~clk),
	.led(led),
	.sw(8'h0F),
	.btnl(1'b0),
	.btnr(1'b0),
	.btnc(1'b0),
	.btnd(1'b0),
	.btnu(1'b0), 
  .ps2_clk_0(),
  .ps2_data_0(),
  .uart_tx_in(1'b0),
  .uart_rx_out(),
	.hdmi_tx_clk_p(),
	.hdmi_tx_clk_n(),
	.hdmi_tx_p(),
	.hdmi_tx_n(),
  /*
  .ac_mclk(),
	.ac_adc_sdata(),
	.ac_dac_sdata(),
	.ac_bclk(),
	.ac_lrclk(),
  .rtc_clk(),
  .rtc_data(),
  .spiClkOut(),
  .spiDataIn(1'b0),
  .spiDataOut(),
  .spiCS_n(),
  .sd_cmd(),
  .sd_dat(),
  .sd_clk(),
  .sd_cd(),
  .sd_reset(),
  
  .pti_clk(),
  .pti_rxf(),
  .pti_txe(),
  .pti_rd(),
  .pti_wr(),
  .pti_siwu(),
  .pti_oe(),
  .pti_dat(),
  .spien(),
  */
  .oled_sdin(),
  .oled_sclk(),
  .oled_dc(),
  .oled_res(),
  .oled_vbat(),
  .oled_vdd(),
  .ddr3_ck_p(),
  .ddr3_ck_n(),
  .ddr3_cke(),
  .ddr3_reset_n(),
  .ddr3_ras_n(),
  .ddr3_cas_n(),
  .ddr3_we_n(),
  .ddr3_ba(),
  .ddr3_addr(),
  .ddr3_dq(),
  .ddr3_dqs_p(),
  .ddr3_dqs_n(),
  .ddr3_dm(),
  .ddr3_odt()
//    gtp_clk_p, gtp_clk_n,
//    dp_tx_hp_detect, dp_tx_aux_p, dp_tx_aux_n, dp_rx_aux_p, dp_rx_aux_n,
//    dp_tx_lane0_p, dp_tx_lane0_n, dp_tx_lane1_p, dp_tx_lane1_n
);

endmodule
