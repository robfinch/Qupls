`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2026  Robert Finch, Waterloo
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
//
// 1025 LUTs / 1225 FFs / 15 BRAMs / 230 MHz

import const_pkg::*;
import wishbone_pkg::*;
import hash_table_pkg::*;

module hash_table(rst,clk,cs,req,resp,vreq,vresp,asid,padr,padrv,
	max_bounce,page_fault,fault_adr,fault_asid,fault_group);
input rst;
input clk;
input cs;
input wb_cmd_request64_t req;
output wb_cmd_response64_t resp;
input wb_cmd_request64_t vreq;
output wb_cmd_response64_t vresp;
input [9:0] asid;
output reg [31:0] padr;
output reg padrv;
input [7:0] max_bounce;
output reg page_fault;
output reg [31:0] fault_adr;
output reg [9:0] fault_asid;
output reg [17:0] fault_group;

integer n,n1;
wire [2:0] state;
wire [8191:0] vb;
reg xlat;
reg found;
wire wea,ena;
reg enb;
wire web;
ptg_t dina, dinb;
ptg_t douta,doutb;
reg [3:0] fnd;
ptg_t hold;
ptg_t rec;
wire [9:0] page_group;
wire [9:0] hash;
wire [7:0] bounce;
reg [7:0] empty;
wire free_asid;
// ASID free FIFO
wire data_valid;
wire rd_rst_busy, wr_rst_busy;
wire [9:0] asid_to_free;
reg rd_en, wr_en;

// xpm_memory_tdpram: True Dual Port RAM
// Xilinx Parameterized Macro, version 2025.1

xpm_memory_tdpram #(
  .ADDR_WIDTH_A(10),               // DECIMAL
  .ADDR_WIDTH_B(10),               // DECIMAL
  .AUTO_SLEEP_TIME(0),            // DECIMAL
  .BYTE_WRITE_WIDTH_A(512),        // DECIMAL
  .BYTE_WRITE_WIDTH_B(512),        // DECIMAL
  .CASCADE_HEIGHT(0),             // DECIMAL
  .CLOCKING_MODE("common_clock"), // String
  .ECC_BIT_RANGE("7:0"),          // String
  .ECC_MODE("no_ecc"),            // String
  .ECC_TYPE("none"),              // String
  .IGNORE_INIT_SYNTH(0),          // DECIMAL
  .MEMORY_INIT_FILE("none"),      // String
  .MEMORY_INIT_PARAM("0"),        // String
  .MEMORY_OPTIMIZATION("true"),   // String
  .MEMORY_PRIMITIVE("auto"),      // String
  .MEMORY_SIZE(512*1024),          // DECIMAL
  .MESSAGE_CONTROL(0),            // DECIMAL
  .RAM_DECOMP("auto"),            // String
  .READ_DATA_WIDTH_A(512),         // DECIMAL
  .READ_DATA_WIDTH_B(512),         // DECIMAL
  .READ_LATENCY_A(1),             // DECIMAL
  .READ_LATENCY_B(1),             // DECIMAL
  .READ_RESET_VALUE_A("0"),       // String
  .READ_RESET_VALUE_B("0"),       // String
  .RST_MODE_A("SYNC"),            // String
  .RST_MODE_B("SYNC"),            // String
  .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
  .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
  .USE_MEM_INIT(1),               // DECIMAL
  .USE_MEM_INIT_MMI(0),           // DECIMAL
  .WAKEUP_TIME("disable_sleep"),  // String
  .WRITE_DATA_WIDTH_A(512),        // DECIMAL
  .WRITE_DATA_WIDTH_B(512),        // DECIMAL
  .WRITE_MODE_A("no_change"),     // String
  .WRITE_MODE_B("no_change"),     // String
  .WRITE_PROTECT(1)               // DECIMAL
)
xpm_memory_tdpram_inst (
  .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence on the data output of port A.
  .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence on the data output of port A.
  .douta(douta),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
  .doutb(doutb),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
  .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence on the data output of port A.
  .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence on the data output of port B.
  .addra(req.adr[15:6]),          // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
  .addrb(hash),                   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
  .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when parameter CLOCKING_MODE is "common_clock".
  .clkb(clk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is "independent_clock". Unused when
                                   // parameter CLOCKING_MODE is "common_clock".

  .dina(dina),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
  .dinb(dinb),                     // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
  .ena(ena),                     // 1-bit input: Memory enable signal for port A. Must be high on clock cycles when read or write operations
                                   // are initiated. Pipelined internally.

  .enb(enb),                       // 1-bit input: Memory enable signal for port B. Must be high on clock cycles when read or write operations
                                   // are initiated. Pipelined internally.

  .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when ECC enabled (Error injection capability
                                   // is not available in "decode_only" mode).

  .injectdbiterrb(1'b0), // 1-bit input: Controls double bit error injection on input data when ECC enabled (Error injection capability
                                   // is not available in "decode_only" mode).

  .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when ECC enabled (Error injection capability
                                   // is not available in "decode_only" mode).

  .injectsbiterrb(1'b0), // 1-bit input: Controls single bit error injection on input data when ECC enabled (Error injection capability
                                   // is not available in "decode_only" mode).

  .regcea(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output data path.
  .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output data path.
  .rsta(rst),                     // 1-bit input: Reset signal for the final port A output register stage. Synchronously resets output port
                                   // douta to the value specified by parameter READ_RESET_VALUE_A.

  .rstb(rst),                     // 1-bit input: Reset signal for the final port B output register stage. Synchronously resets output port
                                   // doutb to the value specified by parameter READ_RESET_VALUE_B.

  .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
  .wea(wea),                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector for port A input data port dina. 1 bit
                                   // wide when word-wide writes are used. In byte-wide write configurations, each bit controls the writing one
                                   // byte of dina to address addra. For example, to synchronously write only bits [15-8] of dina when
                                   // WRITE_DATA_WIDTH_A is 32, wea would be 4'b0010.

  .web(web)                        // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector for port B input data port dinb. 1 bit
                                   // wide when word-wide writes are used. In byte-wide write configurations, each bit controls the writing one
                                   // byte of dinb to address addrb. For example, to synchronously write only bits [15-8] of dinb when
                                   // WRITE_DATA_WIDTH_B is 32, web would be 4'b0010.

);

// End of xpm_memory_tdpram_inst instantiation

always_comb
	enb = vreq.cyc & vreq.stb;

always_ff @(posedge clk)
	fnd <= fnFind(doutb,vreq.adr,asid) & {xlat,3'b0};
always_comb
	for (n = 0; n < 8; n = n + 1)
		empty[n] = ~doutb.ptge[n].v;

always_comb
	xlat = ~vreq.adr[31];
always_comb
	found = ~fnd[3];
always_ff @(posedge clk)
if (rst)
	fault_adr <= 32'd0;
else begin
	if (page_fault)
		fault_adr <= {1'b0,vreq.adr[30:0]};
end
always_ff @(posedge clk)
if (rst)
	fault_asid <= 10'd0;
else begin
	if (page_fault)
		fault_asid <= asid;
end

// Update state machine
ht_state ustate1
(
	.rst(rst), 
	.clk(clk),
	.free_asid(free_asid),
	.cs(cs),
	.req(req),
	.state(state)
);

ht_wb_resp uresp1
(
	.rst(rst),
	.clk(clk),
	.state(state),
	.douta(douta),
	.cs(cs),
	.req(req),
	.resp(resp)
);

ht_ena uena1(
	.rst(rst),
	.clk(clk),
	.state(state),
	.cs(cs),
	.req(req),
	.ena(ena)
);

ht_wea uwea1
(
	.rst(rst),
	.clk(clk),
	.state(state),
	.cs(cs),
	.req(req),
	.wea(wea)
);

// table record to update, CPU side
ht_dina udina1
(
	.rst(rst),
	.clk(clk),
	.state(state),
	.asid_to_free(asid_to_free),
	.req(req),
	.douta(douta),
	.dina(dina)
);

// write strobe to update a,m
ht_web uws1
(
	.rst(rst),
	.clk(clk),
	.xlat(xlat),
	.found(found),
	.req(vreq),
	.web(web)
);


// table record to update, hash Table side
ht_dinb udinb1
(
	.rst(rst),
	.clk(clk),
	.xlat(xlat),
	.found(found),
	.which(fnd[2:0]),
	.req(vreq),
	.doutb(doutb),
	.dinb(dinb)
);

ht_padr upa1
(
	.rst(rst),
	.clk(clk),
	.xlat(xlat),
	.found(found),
	.which(fnd[2:0]),
	.rec(doutb),
	.vadr(vreq.adr),
	.padr(padr),
	.padrv(padrv)
);

// Page fault logic
ht_page_fault upf1
(
	.rst(rst),
	.clk(clk),
	.max_bounce(max_bounce),
	.xlat(xlat),
	.found(found),
	.empty(empty),
	.bounce(bounce),
	.current_group(hash),
	.page_group(page_group),
	.fault_group(fault_group),
	.page_fault(page_fault)
);

// Compute hash, page group (also hash)
ht_hash uhash1
(
	.rst(rst),
	.clk(clk),
	.xlat(xlat),
	.found(found),
	.empty(empty),
	.vadr(vreq.adr),
	.asid(asid),
	.bounce(bounce),
	.hash(hash),
	.page_group(page_group)
);

// Bounce counter
ht_bounce_counter uhtbc1
(
	.rst(rst),
	.clk(clk),
	.max_bounce(max_bounce),
	.xlat(xlat),
	.found(found| (|empty)),
	.vadr(vreq.adr),
	.count(bounce)
);

ht_valid uhtv1
(
	.rst(rst),
	.clk(clk),
	.state(state),
	.req(req),
	.vb(vb)
);

ht_free_asid ufa1
(
	.rst(rst),
	.clk(clk),
	.state(state),
	.max_count(10'hf),
	.free_asid(free_asid)
);

always_comb
	rd_en = free_asid && state==3'd7 && !rd_rst_busy && req.adr[12:3]==10'h3ff;
always_comb
	wr_en = !rst && !rd_rst_busy && !wr_rst_busy &&
		req.cyc && req.stb && req.we && cs && req.adr[31:4]==28'h1000;

// +---------------------------------------------------------------------------------------------------------------------+
// | USE_ADV_FEATURES     | String             | Default value = 0707.                                                   |
// |---------------------------------------------------------------------------------------------------------------------|
// | Enables data_valid, almost_empty, rd_data_count, prog_empty, underflow, wr_ack, almost_full, wr_data_count,         |
// | prog_full, overflow features.                                                                                       |
// |                                                                                                                     |
// |   Setting USE_ADV_FEATURES[0] to 1 enables overflow flag; Default value of this bit is 1                            |
// |   Setting USE_ADV_FEATURES[1] to 1 enables prog_full flag; Default value of this bit is 1                           |
// |   Setting USE_ADV_FEATURES[2] to 1 enables wr_data_count; Default value of this bit is 1                            |
// |   Setting USE_ADV_FEATURES[3] to 1 enables almost_full flag; Default value of this bit is 0                         |
// |   Setting USE_ADV_FEATURES[4] to 1 enables wr_ack flag; Default value of this bit is 0                              |
// |   Setting USE_ADV_FEATURES[8] to 1 enables underflow flag; Default value of this bit is 1                           |
// |   Setting USE_ADV_FEATURES[9] to 1 enables prog_empty flag; Default value of this bit is 1                          |
// |   Setting USE_ADV_FEATURES[10] to 1 enables rd_data_count; Default value of this bit is 1                           |
// |   Setting USE_ADV_FEATURES[11] to 1 enables almost_empty flag; Default value of this bit is 0                       |
// |   Setting USE_ADV_FEATURES[12] to 1 enables data_valid flag; Default value of this bit is 0                         |

// xpm_fifo_sync: Synchronous FIFO
// Xilinx Parameterized Macro, version 2025.1

xpm_fifo_sync #(
  .CASCADE_HEIGHT(0),            // DECIMAL
  .DOUT_RESET_VALUE("0"),        // String
  .ECC_MODE("no_ecc"),           // String
  .EN_SIM_ASSERT_ERR("warning"), // String
  .FIFO_MEMORY_TYPE("auto"),     // String
  .FIFO_READ_LATENCY(1),         // DECIMAL
  .FIFO_WRITE_DEPTH(1024),       // DECIMAL
  .FULL_RESET_VALUE(0),          // DECIMAL
  .PROG_EMPTY_THRESH(10),        // DECIMAL
  .PROG_FULL_THRESH(10),         // DECIMAL
  .RD_DATA_COUNT_WIDTH(10),       // DECIMAL
  .READ_DATA_WIDTH(10),          // DECIMAL
  .READ_MODE("fwft"),             // String
  .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
  .USE_ADV_FEATURES("1000"),     // String	// data valid
  .WAKEUP_TIME(0),               // DECIMAL
  .WRITE_DATA_WIDTH(10),         // DECIMAL
  .WR_DATA_COUNT_WIDTH(10)        // DECIMAL
)
xpm_fifo_sync_inst (
  .almost_empty(),   // 1-bit output: Almost Empty : When asserted, this signal indicates that only one more read can be performed
                                 // before the FIFO goes to empty.
  .almost_full(),     // 1-bit output: Almost Full: When asserted, this signal indicates that only one more write can be performed
                                 // before the FIFO is full.
  .data_valid(data_valid),       // 1-bit output: Read Data Valid: When asserted, this signal indicates that valid data is available on the
                                 // output bus (dout).
  .dbiterr(),             // 1-bit output: Double Bit Error: Indicates that the ECC decoder detected a double-bit error and data in the
                                 // FIFO core is corrupted.
  .dout(asid_to_free),                   // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven when reading the FIFO.
  .empty(),                 // 1-bit output: Empty Flag: When asserted, this signal indicates that the FIFO is empty. Read requests are
                                 // ignored when the FIFO is empty, initiating a read while empty is not destructive to the FIFO.

  .full(),                   // 1-bit output: Full Flag: When asserted, this signal indicates that the FIFO is full. Write requests are
                                 // ignored when the FIFO is full, initiating a write when the FIFO is full is not destructive to the contents of
                                 // the FIFO.

  .overflow(),           // 1-bit output: Overflow: This signal indicates that a write request (wren) during the prior clock cycle was
                                 // rejected, because the FIFO is full. Overflowing the FIFO is not destructive to the contents of the FIFO.

  .prog_empty(),       // 1-bit output: Programmable Empty: This signal is asserted when the number of words in the FIFO is less than
                                 // or equal to the programmable empty threshold value. It is de-asserted when the number of words in the FIFO
                                 // exceeds the programmable empty threshold value.

  .prog_full(),         // 1-bit output: Programmable Full: This signal is asserted when the number of words in the FIFO is greater than
                                 // or equal to the programmable full threshold value. It is de-asserted when the number of words in the FIFO is
                                 // less than the programmable full threshold value.

  .rd_data_count(), // RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates the number of words read from the FIFO.
  .rd_rst_busy(rd_rst_busy),     // 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read domain is currently in a reset state.
  .sbiterr(),             // 1-bit output: Single Bit Error: Indicates that the ECC decoder detected and fixed a single-bit error.
  .underflow(),         // 1-bit output: Underflow: Indicates that the read request (rd_en) during the previous clock cycle was rejected
                                 // because the FIFO is empty. Under flowing the FIFO is not destructive to the FIFO.

  .wr_ack(),               // 1-bit output: Write Acknowledge: This signal indicates that a write request (wr_en) during the prior clock
                                 // cycle is succeeded.

  .wr_data_count(), // WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates the number of words written into the
                                 // FIFO.

  .wr_rst_busy(wr_rst_busy),     // 1-bit output: Write Reset Busy: Active-High indicator that the FIFO write domain is currently in a reset
                                 // state.

  .din(req.dat[9:0]),                     // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when writing the FIFO.
  .injectdbiterr(1'b0), // 1-bit input: Double Bit Error Injection: Injects a double bit error if the ECC feature is used on block RAMs
                                 // or UltraRAM macros.

  .injectsbiterr(1'b0), // 1-bit input: Single Bit Error Injection: Injects a single bit error if the ECC feature is used on block RAMs
                                 // or UltraRAM macros.

  .rd_en(rd_en),	// 1-bit input: Read Enable: If the FIFO is not empty, asserting this signal causes data (on dout) to be read
                                 // from the FIFO. Must be held active-low when rd_rst_busy is active high.

  .rst(rst),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be unstable at the time of applying
                                 // reset, but reset must be released only after the clock(s) is/are stable.

  .sleep(1'b0),                 // 1-bit input: Dynamic power saving- If sleep is High, the memory/fifo block is in power saving mode.
  .wr_clk(clk),               // 1-bit input: Write clock: Used for write operation. wr_clk must be a free running clock.
  .wr_en(wr_en)     // 1-bit input: Write Enable: If the FIFO is not full, asserting this signal causes data (on din) to be written
                                 // to the FIFO Must be held active-low when rst or wr_rst_busy or rd_rst_busy is active high

);

endmodule

