// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// card_table.sv
// - upper level card table
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
// 125 LUTs / 140 FFs / 1 BRAMs
// ============================================================================
//
import fta_bus_pkg::*;

module card_table(rst_i, clk_i, cs_config_i, cs_io_i, wbs_req, wbs_resp);
parameter UPDATE_VALUE = 1'b1;
input rst_i;
input clk_i;
input cs_config_i;
input cs_io_i;
input fta_cmd_request32_t wbs_req;
output fta_cmd_response32_t wbs_resp;

parameter IO_ADDR = 32'hFEE00001;
parameter IO_ADDR_MASK = 32'h00FF8000;
parameter IO_ADDR2 = 32'hFEE80001;
parameter IO_ADDR_MASK2 = 32'h00FF8000;

parameter CFG_BUS = 8'd0;
parameter CFG_DEVICE = 5'd13;
parameter CFG_FUNC = 3'd0;
parameter CFG_VENDOR_ID	=	16'h0;
parameter CFG_DEVICE_ID	=	16'h0;
parameter CFG_SUBSYSTEM_VENDOR_ID	= 16'h0;
parameter CFG_SUBSYSTEM_ID = 16'h0;
parameter CFG_ROM_ADDR = 32'hFFFFFFF0;

parameter CFG_REVISION_ID = 8'd0;
parameter CFG_PROGIF = 8'd1;
parameter CFG_SUBCLASS = 8'h80;					// 80 = Other
parameter CFG_CLASS = 8'h03;						// 03 = display controller
parameter CFG_CACHE_LINE_SIZE = 8'd8;		// 32-bit units
parameter CFG_MIN_GRANT = 8'h00;
parameter CFG_MAX_LATENCY = 8'h00;
parameter CFG_IRQ_LINE = 8'd16;

localparam CFG_HEADER_TYPE = 8'h00;			// 00 = a general device

wire cs_cards;
wire cs_master_card;
wire [31:0] douta;
fta_cmd_request32_t wbs_reqd;
fta_cmd_response32_t cfg_resp;
reg we;
reg [3:0] sel;
reg [31:0] adr;
reg [31:0] dati;
reg [31:0] master_card_table;
reg cs_config;
reg cs_io_id;

always_ff @(posedge clk_i)
	cs_io_id <= cs_io_i;
always_ff @(posedge clk_i)
	cs_config = cs_config_i & wbs_req.cyc &&
	wbs_req.adr[27:20]==CFG_BUS &&
	wbs_req.adr[19:15]==CFG_DEVICE &&
	wbs_req.adr[14:12]==CFG_FUNC;
wire cs_io = cs_io_id & wbs_reqd.cyc & cs_cards;
wire cs_io2 = cs_io_id & wbs_reqd.cyc & cs_master_card;
wire ena = cs_io;
wire enb = wbs_reqd.adr[31:29]==3'b000 && wbs_reqd.cyc;
wire wea = wbs_reqd.we;
wire web = wbs_reqd.cmd==wishbone_pkg::CMD_STOREPTR;

always_ff @(posedge clk_i)
	wbs_reqd <= wbs_req;

always_ff @(posedge clk_i)
begin
	if (web && enb)
		master_card_table[wbs_reqd.adr[29:25]] <= UPDATE_VALUE;
	if (cs_io2 & wea)
		master_card_table <= wbs_reqd.dat;
end

ack_gen #(
	.READ_STAGES(1),
	.WRITE_STAGES(0),
	.REGISTER_OUTPUT(1)
) uag1
(
	.rst_i(rst_i),
	.clk_i(clk_i),
	.ce_i(1'b1),
	.rid_i('d0),
	.wid_i('d0),
	.i((cs_config|cs_io) & ~wbs_reqd.we),
	.we_i((cs_config|cs_io) & wbs_reqd.we),
	.o(wbs_resp.ack),
	.rid_o(),
	.wid_o()
);

ddbb32_config  #(
	.CFG_BUS(CFG_BUS),
	.CFG_DEVICE(CFG_DEVICE),
	.CFG_FUNC(CFG_FUNC),
	.CFG_VENDOR_ID(CFG_VENDOR_ID),
	.CFG_DEVICE_ID(CFG_DEVICE_ID),
	.CFG_BAR0(IO_ADDR),
	.CFG_BAR0_MASK(IO_ADDR_MASK),
	.CFG_BAR1(IO_ADDR2),
	.CFG_BAR1_MASK(IO_ADDR_MASK2),
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
	.rst_i(rst_i),
	.clk_i(clk_i),
	.irq_i(1'b0),
	.cs_i(cs_config),
	.resp_busy_i(),
	.req_i(wbs_reqd),
	.resp_o(cfg_resp),
	.cs_bar0_o(cs_cards),
	.cs_bar1_o(cs_master_card),
	.cs_bar2_o(),
	.irq_chain_i(8'd0),
	.irq_chain_o()
);
	
   // xpm_memory_tdpram: True Dual Port RAM
   // Xilinx Parameterized Macro, version 2022.2

   xpm_memory_tdpram #(
      .ADDR_WIDTH_A(10),               // DECIMAL
      .ADDR_WIDTH_B(15),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A(32),        // DECIMAL
      .BYTE_WRITE_WIDTH_B(1),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("auto"),      // String
      .MEMORY_SIZE(32768),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_A(32),         // DECIMAL
      .READ_DATA_WIDTH_B(1),         // DECIMAL
      .READ_LATENCY_A(2),             // DECIMAL
      .READ_LATENCY_B(2),             // DECIMAL
      .READ_RESET_VALUE_A("0"),       // String
      .READ_RESET_VALUE_B("0"),       // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WAKEUP_TIME("disable_sleep"),  // String
      .WRITE_DATA_WIDTH_A(32),        // DECIMAL
      .WRITE_DATA_WIDTH_B(1),        	// DECIMAL
      .WRITE_MODE_A("no_change"),     // String
      .WRITE_MODE_B("no_change"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   xpm_memory_tdpram_inst (
      .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .douta(douta),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port A.

      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(wbs_reqd.adr[11:2]),
      .addrb(wbs_reqd.adr[29:15]),
      .clka(clk_i),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clk_i),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(wbs_req.dat),               // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .dinb(UPDATE_VALUE),              // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
      .ena(ena),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when read or write operations are initiated. Pipelined
                                       // internally.

      .enb(enb),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
                                       // cycles when read or write operations are initiated. Pipelined
                                       // internally.

      .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectdbiterrb(1'b0), // 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterrb(1'b0), // 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .regcea(ena),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .regceb(enb),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rsta(1'b0),                     // 1-bit input: Reset signal for the final port A output register stage.
                                       // Synchronously resets output port douta to the value specified by
                                       // parameter READ_RESET_VALUE_A.

      .rstb(1'b0),                     // 1-bit input: Reset signal for the final port B output register stage.
                                       // Synchronously resets output port doutb to the value specified by
                                       // parameter READ_RESET_VALUE_B.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(wea),                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

      .web(web)                        // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector
                                       // for port B input data port dinb. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dinb to address addrb. For example, to
                                       // synchronously write only bits [15-8] of dinb when WRITE_DATA_WIDTH_B
                                       // is 32, web would be 4'b0010.

   );

   // End of xpm_memory_tdpram_inst instantiation

// Fill in the response bus. Note the response bus may be wire or'd with other
// responses, hence is forced to zero if not selected.
				
// mux the reg outputs
always_comb
	if (cs_config)
		wbs_resp = cfg_resp;
	else begin
		wbs_resp.dat = cs_io ? douta : cs_io2 ? master_card_table : 32'd0;
		wbs_resp.adr = (cs_io|cs_io2) ? wbs_reqd.adr : 32'd0;
		wbs_resp.err = fta_bus_pkg::OKAY;
		wbs_resp.rty = 1'b0;
		wbs_resp.stall = 1'b0;
		wbs_resp.next = 1'b0;
		wbs_resp.pri = (cs_io|cs_io2) ? 4'd7 : 4'd0;
		wbs_resp.tid = (cs_io|cs_io2) ? wbs_reqd.tid : 13'd0;
	end
			
endmodule
