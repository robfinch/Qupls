// 100 LUTs / 225 FFs

import Stark_pkg::*;

module Stark_FuncResultQueue(rst_i, clk_i, rd_i, we_i, pRt_i, aRt_i, tag_i, res_i, we_o, pRt_o, aRt_o, tag_o, res_o, empty);
input rst_i;
input clk_i;
input rd_i;
input [8:0] we_i;
input cpu_types_pkg::pregno_t pRt_i;
input cpu_types_pkg::aregno_t aRt_i;
input [7:0] tag_i;
input [63:0] res_i;
output reg [8:0] we_o;
output cpu_types_pkg::pregno_t pRt_o;
output cpu_types_pkg::aregno_t aRt_o;
output reg [7:0] tag_o;
output reg [71:0] res_o;
output empty;

wire full;
wire almost_full;
wire data_valid;
wire rd_rst_busy;
wire wr_rst_busy;
wire wr_clk = clk_i;
wire rst = rst_i;
wire [95:0] din = {
	we_i,
	pRt_i,
	aRt_i,
	tag_i,
	res_i
};
wire [95:0] dout;

reg wr_en1, wr_en;
reg rd_en;

always_comb
	{we_o,pRt_o,aRt_o,tag_o,res_o} = dout;
always_comb
	rd_en = rd_i & ~rd_rst_busy;
always_comb
	wr_en1 = |we_i;
always_comb
	wr_en = wr_en1 & ~wr_rst_busy & ~rd_rst_busy & ~rst;

// xpm_fifo_sync: Synchronous FIFO
// Xilinx Parameterized Macro, version 2024.1

xpm_fifo_sync #(
  .CASCADE_HEIGHT(0),            // DECIMAL
  .DOUT_RESET_VALUE("0"),        // String
  .ECC_MODE("no_ecc"),           // String
  .EN_SIM_ASSERT_ERR("warning"), // String
  .FIFO_MEMORY_TYPE("distributed"),     // String
  .FIFO_READ_LATENCY(0),         // DECIMAL
  .FIFO_WRITE_DEPTH(32),       // DECIMAL
  .FULL_RESET_VALUE(0),          // DECIMAL
  .PROG_EMPTY_THRESH(10),        // DECIMAL
  .PROG_FULL_THRESH(10),         // DECIMAL
  .RD_DATA_COUNT_WIDTH(5),       // DECIMAL
  .READ_DATA_WIDTH(96),          // DECIMAL
  .READ_MODE("fwft"),             // String
  .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
  .USE_ADV_FEATURES("0000"),     // String
  .WAKEUP_TIME(0),               // DECIMAL
  .WRITE_DATA_WIDTH(96),         // DECIMAL
  .WR_DATA_COUNT_WIDTH(5)        // DECIMAL
)
xpm_fifo_sync_inst (
  .almost_empty(),   // 1-bit output: Almost Empty : When asserted, this signal indicates that
  .almost_full(almost_full),     // 1-bit output: Almost Full: When asserted, this signal indicates that
  .data_valid(data_valid),       // 1-bit output: Read Data Valid: When asserted, this signal indicates
  .dbiterr(),             // 1-bit output: Double Bit Error: Indicates that the ECC decoder detected
  .dout(dout),                   // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
  .empty(empty),                 // 1-bit output: Empty Flag: When asserted, this signal indicates that the
  .full(full),                   // 1-bit output: Full Flag: When asserted, this signal indicates that the
  .overflow(),           // 1-bit output: Overflow: This signal indicates that a write request
  .prog_empty(),       // 1-bit output: Programmable Empty: This signal is asserted when the
  .prog_full(),         // 1-bit output: Programmable Full: This signal is asserted when the
  .rd_data_count(), // RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates the
  .rd_rst_busy(rd_rst_busy),     // 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read
  .sbiterr(),             // 1-bit output: Single Bit Error: Indicates that the ECC decoder detected
  .underflow(),         // 1-bit output: Underflow: Indicates that the read request (rd_en) during
  .wr_ack(),               // 1-bit output: Write Acknowledge: This signal indicates that a write
  .wr_data_count(), // WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates
  .wr_rst_busy(wr_rst_busy),     // 1-bit output: Write Reset Busy: Active-High indicator that the FIFO
  .din(din),                     // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
  .injectdbiterr(1'b0), // 1-bit input: Double Bit Error Injection: Injects a double bit error if
  .injectsbiterr(1'b0), // 1-bit input: Single Bit Error Injection: Injects a single bit error if
  .rd_en(rd_en),                 // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
  .rst(rst),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
  .sleep(1'b0),                 // 1-bit input: Dynamic power saving- If sleep is High, the memory/fifo
  .wr_clk(wr_clk),               // 1-bit input: Write clock: Used for write operation. wr_clk must be a
  .wr_en(wr_en)                  // 1-bit input: Write Enable: If the FIFO is not full, asserting this
);
			
endmodule
