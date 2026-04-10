`timescale 1ns / 1ps

import const_pkg::*;

module dram_bridge(rst, clk200, ui_rst_sync, ui_clk, sys_rst, init_calib_complete,
	mem_cyc, mem_stb, mem_ack, mem_we, mem_sel, mem_adr, mem_din, mem_dout,
	app_sr_active, app_ref_ack, app_zq_ack, app_en, app_rdy, app_cmd, app_addr,
	app_rd_data, app_wdf_wren, app_wdf_data, app_wdf_end, app_wdf_mask,
	app_wdf_rdy, app_rd_data_end, app_rd_data_valid, device_temp);
input rst;
input clk200;
input ui_rst_sync;
input ui_clk;
output sys_rst;
input init_calib_complete;

input mem_cyc;
input mem_stb;
output reg mem_ack;
input mem_we;
input [31:0] mem_sel;
input [31:0] mem_adr;
input [255:0] mem_din;
output reg [255:0] mem_dout;

input app_sr_active;
input app_ref_ack;
input app_zq_ack;
output app_en;
input app_rdy;
output [2:0] app_cmd;
output [29:0] app_addr;
input [255:0] app_rd_data;
output app_wdf_wren;
output [255:0] app_wdf_data;
output app_wdf_end;
output [31:0] app_wdf_mask;
input app_wdf_rdy;
input app_rd_data_end;
input app_rd_data_valid;
input [11:0] device_temp;

localparam CMD_READ = 3'b1;
localparam CMD_WRITE = 3'b0;

reg reading;

wire mem_cs = mem_adr[31:30]==2'b01 && mem_cyc && mem_stb;

assign sys_rst = ~rst;
wire write_ready = (mem_we & mem_cs) & app_wdf_rdy & app_rdy;
assign app_addr = {mem_adr[29:5],5'h00};
assign app_cmd = (mem_we|~mem_cs) ? CMD_WRITE : CMD_READ;
assign app_en = write_ready | (mem_cs & ~reading);
assign app_wdf_mask = mem_we ? ~(mem_sel & {32{mem_cs}}) : 32'd0;
assign app_wdf_data = mem_din;
assign app_wdf_wren = write_ready;
assign app_wdf_end = write_ready;

always_ff @(posedge clk200)
if (rst|ui_rst_sync)
	mem_dout <= 256'd0;
else begin
	if (init_calib_complete) begin
	  if (mem_cs) begin
		  if (app_rd_data_valid)
		    mem_dout <= app_rd_data;
		end
		else
			mem_dout <= 256'd0;
  end
  else
		mem_dout <= 256'd0;
end

always_ff @(posedge clk200)
if (rst|ui_rst_sync)
	mem_ack <= FALSE;
else begin
	if (init_calib_complete) begin
	  if (mem_cs) begin
	  	if (mem_we & write_ready)
	  		mem_ack <= TRUE;
		  else if (app_rd_data_valid)
				mem_ack <= TRUE;
		end
		else
			mem_ack <= FALSE;
  end
  else
		mem_ack <= FALSE;
end

always_ff @(posedge clk200)
if (rst|ui_rst_sync)
	reading <= FALSE;
else begin
	if (init_calib_complete) begin
	  if (~mem_we & mem_cs & ~reading & app_rdy)
	    reading <= TRUE;
	  if (reading & app_rd_data_valid)
	    reading <= FALSE;
  end
  else
		reading <= FALSE;
end

endmodule
