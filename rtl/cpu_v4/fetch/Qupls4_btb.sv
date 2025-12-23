// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
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
// 6500 LUTs / 350 FFs / 8 BRAMs    
// 17200 / 3200                                                                      
// ============================================================================

import Qupls4_pkg::*;

module Qupls4_btb(rst, clk, en, clk_en, nmi, nmi_addr, irq, irq_addr,
	rclk, micro_machine_active, get_next_pc, advance_pc,
	igrp, length_byte, predicted_correctly_dec, new_address_dec,
	new_address_ext,
	pc, pc0, pc1, pc2, pc3, pc4, next_pc, p_override, po_bno,
	takb0, takb1, takb2, takb3, do_bsr, bsr_tgt, do_ret, ret_pc,
	do_call,
	branchmiss, misspc, excret, excretpc,
	commit_pc0, commit_brtgt0, commit_takb0, commit_grp0,
	commit_pc1, commit_brtgt1, commit_takb1, commit_grp1,
	commit_pc2, commit_brtgt2, commit_takb2, commit_grp2,
	commit_pc3, commit_brtgt3, commit_takb3, commit_grp3,
	strm_bitmap, act_stream, pcs,
	new_stream, alloc_stream, free_stream, thread_probability, dep_stream,
	is_buffered
);
parameter DEP=1024;
parameter MWIDTH = 4;
input rst;
input clk;
input en;
input clk_en;										// enable group to advance
input nmi;											// non-maskable interrupt
input pc_address_t nmi_addr;
input irq;
input pc_address_t irq_addr;
input rclk;
input advance_pc;
input micro_machine_active;
output reg [2:0] igrp;
input get_next_pc;
input [7:0] length_byte;
input cpu_types_pkg::pc_address_ex_t pc;
input cpu_types_pkg::pc_address_ex_t pc0;
input cpu_types_pkg::pc_address_ex_t pc1;
input cpu_types_pkg::pc_address_ex_t pc2;
input cpu_types_pkg::pc_address_ex_t pc3;
input cpu_types_pkg::pc_address_ex_t pc4;
output cpu_types_pkg::pc_address_ex_t next_pc;
input excret;
input pc_address_ex_t excretpc;
input [3:0] p_override;
input [6:0] po_bno [0:3];
output reg takb0;
output reg takb1;
output reg takb2;
output reg takb3;
input pc_address_ex_t new_address_ext;
input predicted_correctly_dec;
input pc_address_ex_t new_address_dec;
input do_bsr;
input do_ret;
input do_call;
input pc_address_ex_t ret_pc;
input cpu_types_pkg::pc_address_ex_t bsr_tgt;
input branchmiss;
input cpu_types_pkg::pc_address_ex_t misspc;
input cpu_types_pkg::pc_address_ex_t commit_pc0;
input cpu_types_pkg::pc_address_ex_t commit_brtgt0;
input commit_takb0;
input [2:0] commit_grp0;
input cpu_types_pkg::pc_address_ex_t commit_pc1;
input cpu_types_pkg::pc_address_ex_t commit_brtgt1;
input commit_takb1;
input [2:0] commit_grp1;
input cpu_types_pkg::pc_address_ex_t commit_pc2;
input cpu_types_pkg::pc_address_ex_t commit_brtgt2;
input commit_takb2;
input [2:0] commit_grp2;
input cpu_types_pkg::pc_address_ex_t commit_pc3;
input cpu_types_pkg::pc_address_ex_t commit_brtgt3;
input commit_takb3;
input [2:0] commit_grp3;

output [XSTREAMS*THREADS-1:0] strm_bitmap;
output pc_stream_t act_stream;
output pc_stream_t [THREADS-1:0] new_stream;
input alloc_stream;
input [XSTREAMS*THREADS-1:0] free_stream;
output pc_address_ex_t [XSTREAMS*THREADS-1:0] pcs;

input [7:0] thread_probability [0:7];
output [XSTREAMS-1:0] dep_stream [0:XSTREAMS-1];
input is_buffered;

typedef struct packed {
	logic takb;
	logic [2:0] grp;
	cpu_types_pkg::pc_address_t pc;
	cpu_types_pkg::pc_address_t tgt;
} btb_entry_t;

pc_address_ex_t [31:0] ras;
reg [4:0] ras_sp;

pc_address_ex_t [XSTREAMS*THREADS-1:0] next_pcs;
pc_stream_t next_act_stream;
pc_stream_t next_alt_strm;
reg [XSTREAMS*THREADS-1:0] next_strm_bitmap;
pc_stream_t prev_act_stream;
reg [9:0] addrb0;
reg [9:0] addra;
btb_entry_t doutb0;
btb_entry_t doutb1;
btb_entry_t doutb2;
btb_entry_t doutb3;
reg w0,w1,w2,w3;
btb_entry_t tmp0, tmp1, tmp2, tmp3;
integer nn,mm,jj,n1,n2,n3;
genvar g;

wire [5:0] ffz0,ffz1,ffz2,ffz3,ffz4;
generate begin : gFFZ
	if (XSTREAMS==32) begin
ffz48 uffz0 (.i({16'hFFFF,strm_bitmap[ 31: 0]}), .o(ffz0));
if (THREADS > 1) ffz48 uffz1 (.i({16'hFFFF,strm_bitmap[ 63:32]}), .o(ffz1));
if (THREADS > 2) ffz48 uffz2 (.i({16'hFFFF,strm_bitmap[ 95:64]}), .o(ffz2));
if (THREADS > 3) ffz48 uffz3 (.i({16'hFFFF,strm_bitmap[127:96]}), .o(ffz3));
if (THREADS > 4) ffz48 uffz4 (.i({16'hFFFF,strm_bitmap[159:128]}), .o(ffz4));
end
else if (XSTREAMS==16) begin
wire [4:0] ffz0a,ffz1a,ffz2a,ffz3a,ffz4a;
ffz24 uffz0 (.i({8'hFF,strm_bitmap[ 15: 0]}), .o(ffz0a));
if (THREADS > 1) ffz24 uffz1 (.i({8'hFF,strm_bitmap[ 31:16]}), .o(ffz1a));
if (THREADS > 2) ffz24 uffz2 (.i({8'hFF,strm_bitmap[ 47:32]}), .o(ffz2a));
if (THREADS > 3) ffz24 uffz3 (.i({8'hFF,strm_bitmap[ 63:48]}), .o(ffz3a));
if (THREADS > 4) ffz24 uffz4 (.i({8'hFF,strm_bitmap[ 79:64]}), .o(ffz4a));
assign ffz0 = {1'b0,ffz0a};
assign ffz1 = {1'b0,ffz1a};
assign ffz2 = {1'b0,ffz2a};
assign ffz3 = {1'b0,ffz3a};
assign ffz4 = {1'b0,ffz4a};
end
end
endgenerate

//ffz48 uffz1 (.i({16'hFFFF,strm_bitmap | (144'd1 << ffz0)}), .o(ffz1));

// BTB tables.

   // xpm_memory_sdpram: Simple Dual Port RAM
   // Xilinx Parameterized Macro, version 2022.2

   xpm_memory_sdpram #(
      .ADDR_WIDTH_A($clog2(DEP)),               // DECIMAL
      .ADDR_WIDTH_B($clog2(DEP)),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A($bits(btb_entry_t)),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("block"),      // String
      .MEMORY_SIZE(DEP*$bits(btb_entry_t)),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_B($bits(btb_entry_t)),         // DECIMAL
      .READ_LATENCY_B(1),             // DECIMAL
      .READ_RESET_VALUE_B("0"),       // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WAKEUP_TIME("disable_sleep"),  // String
      .WRITE_DATA_WIDTH_A($bits(btb_entry_t)),        // DECIMAL
      .WRITE_MODE_B("no_change"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   xpm_memory_sdpram_inst0 (
      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port B.

      .doutb(doutb0),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(addra),                   // ADDR_WIDTH_A-bit input: Address for port A write operations.
      .addrb(addrb0),                   // ADDR_WIDTH_B-bit input: Address for port B read operations.
      .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(rclk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "common_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(tmp0),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(1'b1),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when write operations are initiated. Pipelined internally.

      .enb(1'b1),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
                                       // cycles when read operations are initiated. Pipelined internally.

      .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rstb(1'b0),                     // 1-bit input: Reset signal for the final port B output register stage.
                                       // Synchronously resets output port doutb to the value specified by
                                       // parameter READ_RESET_VALUE_B.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(w0)                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

   );

   // xpm_memory_sdpram: Simple Dual Port RAM
   // Xilinx Parameterized Macro, version 2022.2

   xpm_memory_sdpram #(
      .ADDR_WIDTH_A($clog2(DEP)),               // DECIMAL
      .ADDR_WIDTH_B($clog2(DEP)),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A($bits(btb_entry_t)),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("block"),      // String
      .MEMORY_SIZE(DEP*$bits(btb_entry_t)),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_B($bits(btb_entry_t)),         // DECIMAL
      .READ_LATENCY_B(1),             // DECIMAL
      .READ_RESET_VALUE_B("0"),       // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WAKEUP_TIME("disable_sleep"),  // String
      .WRITE_DATA_WIDTH_A($bits(btb_entry_t)),        // DECIMAL
      .WRITE_MODE_B("no_change"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   xpm_memory_sdpram_inst1 (
      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port B.

      .doutb(doutb1),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(addra),                   // ADDR_WIDTH_A-bit input: Address for port A write operations.
      .addrb(addrb0),                   // ADDR_WIDTH_B-bit input: Address for port B read operations.
      .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(rclk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "common_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(tmp1),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(1'b1),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when write operations are initiated. Pipelined internally.

      .enb(1'b1),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
                                       // cycles when read operations are initiated. Pipelined internally.

      .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rstb(1'b0),                     // 1-bit input: Reset signal for the final port B output register stage.
                                       // Synchronously resets output port doutb to the value specified by
                                       // parameter READ_RESET_VALUE_B.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(w1)                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

   );

   // xpm_memory_sdpram: Simple Dual Port RAM
   // Xilinx Parameterized Macro, version 2022.2

   xpm_memory_sdpram #(
      .ADDR_WIDTH_A($clog2(DEP)),               // DECIMAL
      .ADDR_WIDTH_B($clog2(DEP)),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A($bits(btb_entry_t)),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("block"),      // String
      .MEMORY_SIZE(DEP*$bits(btb_entry_t)),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_B($bits(btb_entry_t)),         // DECIMAL
      .READ_LATENCY_B(1),             // DECIMAL
      .READ_RESET_VALUE_B("0"),       // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WAKEUP_TIME("disable_sleep"),  // String
      .WRITE_DATA_WIDTH_A($bits(btb_entry_t)),        // DECIMAL
      .WRITE_MODE_B("no_change"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   xpm_memory_sdpram_inst2 (
      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port B.

      .doutb(doutb2),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(addra),                   // ADDR_WIDTH_A-bit input: Address for port A write operations.
      .addrb(addrb0),                   // ADDR_WIDTH_B-bit input: Address for port B read operations.
      .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(rclk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "common_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(tmp2),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(1'b1),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when write operations are initiated. Pipelined internally.

      .enb(1'b1),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
                                       // cycles when read operations are initiated. Pipelined internally.

      .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rstb(1'b0),                     // 1-bit input: Reset signal for the final port B output register stage.
                                       // Synchronously resets output port doutb to the value specified by
                                       // parameter READ_RESET_VALUE_B.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(w2)                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

   );

   // xpm_memory_sdpram: Simple Dual Port RAM
   // Xilinx Parameterized Macro, version 2022.2

   xpm_memory_sdpram #(
      .ADDR_WIDTH_A($clog2(DEP)),               // DECIMAL
      .ADDR_WIDTH_B($clog2(DEP)),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A($bits(btb_entry_t)),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("block"),      // String
      .MEMORY_SIZE(DEP*$bits(btb_entry_t)),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_B($bits(btb_entry_t)),         // DECIMAL
      .READ_LATENCY_B(1),             // DECIMAL
      .READ_RESET_VALUE_B("0"),       // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WAKEUP_TIME("disable_sleep"),  // String
      .WRITE_DATA_WIDTH_A($bits(btb_entry_t)),        // DECIMAL
      .WRITE_MODE_B("no_change"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   xpm_memory_sdpram_inst3 (
      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port B.

      .doutb(doutb3),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(addra),                   // ADDR_WIDTH_A-bit input: Address for port A write operations.
      .addrb(addrb0),                   // ADDR_WIDTH_B-bit input: Address for port B read operations.
      .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(rclk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "common_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(tmp3),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(1'b1),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when write operations are initiated. Pipelined internally.

      .enb(1'b1),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
                                       // cycles when read operations are initiated. Pipelined internally.

      .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rstb(1'b0),                     // 1-bit input: Reset signal for the final port B output register stage.
                                       // Synchronously resets output port doutb to the value specified by
                                       // parameter READ_RESET_VALUE_B.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(w3)                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

   );

always_comb//ff @(posedge clk)
	addrb0 = pc0.pc[10:1];


Qupls4_btb_stream_bitmap usb1
(
	.rst(rst),
	.clk(clk),
	.clk_en(clk_en),
	.ffz0(ffz0),
	.act_stream(act_stream),
	.free_stream(free_stream),
	.alloc_stream(alloc_stream),
	.new_stream(new_stream),
	.dep_stream(dep_stream),
	.strm_bitmap(strm_bitmap),
	.next_strm_bitmap(next_strm_bitmap)
);

// Choose a fetch stream
// Threads may be disabled by setting the probability to zero.
Qupls4_btb_choose_stream ucs1
(
	.rst(rst), 
	.clk(clk),
	.thread_probability(thread_probability),
	.is_buffered(is_buffered),
	.act_stream(act_stream),
	.next_act_stream(next_act_stream),
	.strm_bitmap(strm_bitmap),
	.pcs(pcs)
);

	
always_comb
if (rst) begin
	for (nn = 0; nn < XSTREAMS*THREADS; nn = nn + 1) begin
		next_pcs[nn].stream.thread = (nn >> $clog2(XSTREAMS));
		next_pcs[nn].stream.stream = 5'd1;
		next_pcs[nn].pc = RSTPC;
	end
	takb0 = 1'b0;
	takb1 = 1'b0;
	takb2 = 1'b0;
	takb3 = 1'b0;
end
else begin
	takb0 = 1'b0;
	takb1 = 1'b0;
	takb2 = 1'b0;
	takb3 = 1'b0;
	for (nn = 0; nn < XSTREAMS*THREADS; nn = nn + 1)
		next_pcs[nn] = pcs[nn];
	/* Under construction
	if (p_override[0])
		next_bno_bitmap[po_bno[0]] = 1'b0;
	if (p_override[1])
		next_bno_bitmap[po_bno[1]] = 1'b0;
	if (p_override[2])
		next_bno_bitmap[po_bno[2]] = 1'b0;
	if (p_override[3])
		next_bno_bitmap[po_bno[3]] = 1'b0;
	*/

	// Assign alternate branch path if not already assigned.
	/* under construction
	if (pr0.decbus.br && pr0.pc.bno_f==5'd0) begin
		dec_pc0 = pr.pc;
		dec_pc0.bno_f = ffz0a;
		next_bno_bitmap[ffz0a] = 1'b0;
	end
	if (pr1.decbus.br && pr1.pc.bno_f==5'd0) begin
		dec_pc1 = pr.pc;
		dec_pc1.bno_f = ffz0b;
		next_bno_bitmap[ffz0b] = 1'b0;
	end
	if (pr2.decbus.br && pr2.pc.bno_f==5'd0) begin
		dec_pc2 = pr.pc;
		dec_pc2.bno_f = ffz0c;
		next_bno_bitmap[ffz0c] = 1'b0;
	end
	if (pr3.decbus.br && pr3.pc.bno_f==5'd0) begin
		dec_pc3 = pr.pc;
		dec_pc3.bno_f = ffz0d;
		next_bno_bitmap[ffz0d] = 1'b0;
	end
	*/

	// Handle change of flow on interrupt.
	if (nmi) begin
		next_pcs[act_stream].pc = nmi_addr;
		next_pcs[act_stream].stream = next_act_stream;
	end
	else if (irq) begin
		next_pcs[act_stream].pc = irq_addr;
		next_pcs[act_stream].stream = next_act_stream;
	end
	else
	if (excret)
		next_pcs[act_stream] = excretpc;
	// Under construction: RAS
	else if (do_ret)
		next_pcs[act_stream] = ras[ras_sp];
	// Decode stage corrections override mux stage.
	else if (!predicted_correctly_dec)
		next_pcs[act_stream] = new_address_dec;
	else if (|p_override)
		next_pcs[act_stream] = new_address_ext;
	// bsr/jsr
	else if (do_bsr)
		next_pcs[bsr_tgt.stream] = bsr_tgt;
	else if (branchmiss)	//(bs_done_oh||bs_done) begin
		next_pcs[misspc.stream] = misspc;
	// Now the target predictions
	// Note the stream cannot be recorded in the BTB table.
	else if (en && pc0.pc==doutb0.pc && doutb0.takb) begin
		next_pcs[pc0.stream].pc = doutb0.tgt;
		next_pcs[pc0.stream].stream = next_act_stream;
		takb0 = 1'b1;		// record branch taken fact (for bt)
	end
	else if (en && pc1.pc==doutb1.pc && doutb1.takb) begin
		next_pcs[pc1.stream].pc = doutb1.tgt;
		next_pcs[pc1.stream].stream = next_act_stream;
		takb1 = 1'b1;
	end
	else if (en && pc2.pc==doutb2.pc && doutb2.takb) begin
		next_pcs[pc2.stream].pc = doutb2.tgt;
		next_pcs[pc2.stream].stream = next_act_stream;
		takb2 = 1'b1;
	end
	else if (en && pc3.pc==doutb3.pc && doutb3.takb) begin
		next_pcs[pc3.stream].pc = doutb3.tgt;
		next_pcs[pc3.stream].stream = next_act_stream;
		takb3 = 1'b1;
	end
	// Advance program counter.
	else begin
		next_pcs[act_stream] = pc;
		next_pcs[act_stream].pc = pc.pc + MWIDTH*6;	// four instructions
	end
end

// Program Counters
// One for every stream of each possible thread.
generate begin : gPCs
	for (g = 0; g < XSTREAMS*THREADS; g = g + 1) begin
		always_ff @(posedge clk)
		if (rst) begin
			pcs[g].stream.stream <= 5'd1;
			pcs[g].stream.thread = g >> $clog2(XSTREAMS);
			pcs[g].pc <= RSTPC;
		end
		else if (advance_pc) begin
			if (get_next_pc)
				pcs[g] <= next_pcs[g];
		end
	end
end
endgenerate

// Manage thread updates.
always_ff @(posedge clk)
if (rst) begin
	prev_act_stream.stream <= 5'd1;
	prev_act_stream.thread <= 2'd0;
	act_stream.stream <= 5'd1;
	act_stream.thread <= 2'd0;
end
else begin
	if (clk_en) begin
		prev_act_stream <= act_stream;
		act_stream <= next_act_stream;
	end
end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// The RAS
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

always_ff @(posedge clk)
if (rst)
	ras_sp <= 5'd0;
else begin
	case({do_ret,do_call})
	2'b00:	;
	2'b01:	ras_sp <= ras_sp - 2'd1;
	2'b10:	ras_sp <= ras_sp + 2'd1;
	2'b11:	;
	endcase
end

always_ff @(posedge clk)
if (rst) begin
	for (jj = 0; jj < 32; jj = jj + 1) begin
		ras[jj].pc <= RSTPC;
		ras[jj].stream.thread <= 2'd0;
		ras[jj].stream.stream <= 5'd1;
	end
end
else begin
	if (do_call)
		ras[ras_sp - 2'd1] <= ret_pc;
end


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

assign next_pc = next_pcs[next_act_stream];

always_ff @(posedge clk)
if (rst) begin
	w0 <= 1'd0;
	w1 <= 1'd0;
	w2 <= 1'd0;
	w3 <= 1'd0;
	addra <= 10'd0;
	tmp0 <= 'd0;
	tmp1 <= 'd0;
	tmp2 <= 'd0;
	tmp3 <= 'd0;
end
else begin
	tmp0.pc <= commit_pc0.pc;
	tmp0.takb <= commit_takb0;
	tmp0.tgt <= commit_brtgt0.pc;
	tmp0.grp <= commit_grp0;
	tmp1.pc <= commit_pc1.pc;
	tmp1.takb <= commit_takb1;
	tmp1.tgt <= commit_brtgt1.pc;
	tmp1.grp <= commit_grp1;
	tmp2.pc <= commit_pc2.pc;
	tmp2.takb <= commit_takb2;
	tmp2.tgt <= commit_brtgt2.pc;
	tmp2.grp <= commit_grp2;
	tmp3.pc <= commit_pc3.pc;
	tmp3.takb <= commit_takb3;
	tmp3.tgt <= commit_brtgt3.pc;
	tmp3.grp <= commit_grp3;
	addra <= commit_pc0.pc[10:1];
	w0 <= commit_takb0;
	w1 <= commit_takb1;
	w2 <= commit_takb2;
	w3 <= commit_takb3;
//	w <= commit_takb0|commit_takb1|commit_takb2|commit_takb3;
end

endmodule
