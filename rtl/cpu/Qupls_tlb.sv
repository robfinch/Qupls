// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
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
// 8500 LUTs / 4100 FFs
// ============================================================================

import fta_bus_pkg::*;
import QuplsMmupkg::*;

module Qupls_tlb(rst, clk, ftas_req, ftas_resp,
	wr, way, entry_no, entry_i, entry_o, vadr0, vadr1, pc_vadr, omd0, omd1, pc_omd,
	asid0, asid1, pc_asid, entry0_o, entry1_o, pc_entry_o,
	miss_o, missadr_o, missasid_o, missack,
	tlb0_v, tlb1_v, pc_tlb_v, op0, op1, tlb0_op, tlb1_op, tlb0_res, tlb1_res, pc_tlb_res,
	load0_i, load1_i, store0_i, store1_i, load0_o, load1_o, store0_o, store1_o,
	stall_tlb0, stall_tlb1,
	agen0_rndx_i, agen1_rndx_i, agen0_rndx_o, agen1_rndx_o);
parameter TLB_ENTRIES = 128;
parameter MISSQ_ENTRIES = 16;
input rst;
input clk;
input fta_cmd_request128_t ftas_req;
output fta_cmd_response128_t ftas_resp;
input wr;
input way;
input [6:0] entry_no;
input tlb_entry_t entry_i;
output tlb_entry_t entry_o;
input address_t vadr0;
input address_t vadr1;
input pc_address_t pc_vadr;
input operating_mode_t omd0;
input operating_mode_t omd1;
input operating_mode_t pc_omd;
input asid_t asid0;
input asid_t asid1;
input asid_t pc_asid;
output tlb_entry_t entry0_o;
output tlb_entry_t entry1_o;
output tlb_entry_t pc_entry_o;
output reg miss_o;
output address_t missadr_o;
output asid_t missasid_o;
input missack;
output reg tlb0_v;
output reg tlb1_v;
output reg pc_tlb_v;
input instruction_t op0;
input instruction_t op1;
output instruction_t tlb0_op;
output instruction_t tlb1_op;
output address_t tlb0_res;
output address_t tlb1_res;
output pc_address_t pc_tlb_res;
input load0_i;
input store0_i;
input load1_i;
input store1_i;
output reg load0_o;
output reg store0_o;
output reg load1_o;
output reg store1_o;
input stall_tlb0;
input stall_tlb1;
input rob_ndx_t agen0_rndx_i;
input rob_ndx_t agen1_rndx_i;
output rob_ndx_t agen0_rndx_o;
output rob_ndx_t agen1_rndx_o;

tlb_entry_t entry0;
tlb_entry_t entry1;
tlb_entry_t pc_entry;
tlb_entry_t t0a, t0b, t1a, t1b, t2a, t2b, entry_oa, entry_ob;
reg [3:0] head, tail;
address_t [MISSQ_ENTRIES-1:0] missadr;
asid_t [MISSQ_ENTRIES-1:0] missasid;
REGION region0, region1, region2;
wire [7:0] sel0, sel1, sel2;
operating_mode_t omd0a, omd1a, pc_omda;

integer n;

Qupls_active_region uar1
(
	.rst(rst),
	.clk(clk),
	.rgn0(entry0.pte.rgn),
	.rgn1(entry1.pte.rgn),
	.rgn2(pc_entry.pte.rgn),
	.ftas_req(ftas_req),
	.ftas_resp(ftas_resp),
	.region_num(),
	.region0(region0),
	.region1(region1),
	.region2(region2),
	.sel0(sel0),
	.sel1(sel1),
	.sel2(sel2),
	.err0(),
	.err1(),
	.err2()
);

   // xpm_memory_dpdistram: Dual Port Distributed RAM
   // Xilinx Parameterized Macro, version 2022.2

   xpm_memory_dpdistram #(
      .ADDR_WIDTH_A(7),               // DECIMAL
      .ADDR_WIDTH_B(7),               // DECIMAL
      .BYTE_WRITE_WIDTH_A($bits(tlb_entry_t)),        // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_SIZE($bits(tlb_entry_t)*128),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_A($bits(tlb_entry_t)),         // DECIMAL
      .READ_DATA_WIDTH_B($bits(tlb_entry_t)),         // DECIMAL
      .READ_LATENCY_A(0),             // DECIMAL
      .READ_LATENCY_B(0),             // DECIMAL
      .READ_RESET_VALUE_A("0"),       // String
      .READ_RESET_VALUE_B("0"),       // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WRITE_DATA_WIDTH_A($bits(tlb_entry_t))         // DECIMAL
   )
   xpm_memory_dpdistram_inst0 (
      .douta(entry_oa),   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(t0a),   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .addra(entry_no),   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .addrb(vadr0[22:16]),   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
      .clka(clk),     // 1-bit input: Clock signal for port A. Also clocks port B when parameter CLOCKING_MODE
                       // is "common_clock".

      .clkb(clk),     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                       // "independent_clock". Unused when parameter CLOCKING_MODE is "common_clock".

      .dina(entry_i),     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(~way),       // 1-bit input: Memory enable signal for port A. Must be high on clock cycles when read
                       // or write operations are initiated. Pipelined internally.

      .enb(1'b1),       // 1-bit input: Memory enable signal for port B. Must be high on clock cycles when read
                       // or write operations are initiated. Pipelined internally.

      .regcea(1'b1), // 1-bit input: Clock Enable for the last register stage on the output data path.
      .regceb(1'b1), // 1-bit input: Do not change from the provided value.
      .rsta(1'b0),     // 1-bit input: Reset signal for the final port A output register stage. Synchronously
                       // resets output port douta to the value specified by parameter READ_RESET_VALUE_A.

      .rstb(1'b0),     // 1-bit input: Reset signal for the final port B output register stage. Synchronously
                       // resets output port doutb to the value specified by parameter READ_RESET_VALUE_B.

      .wea(wr)        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector for port A input
                       // data port dina. 1 bit wide when word-wide writes are used. In byte-wide write
                       // configurations, each bit controls the writing one byte of dina to address addra. For
                       // example, to synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A is
                       // 32, wea would be 4'b0010.

   );

   xpm_memory_dpdistram #(
      .ADDR_WIDTH_A(7),               // DECIMAL
      .ADDR_WIDTH_B(7),               // DECIMAL
      .BYTE_WRITE_WIDTH_A($bits(tlb_entry_t)),        // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_SIZE($bits(tlb_entry_t)*128),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_A($bits(tlb_entry_t)),         // DECIMAL
      .READ_DATA_WIDTH_B($bits(tlb_entry_t)),         // DECIMAL
      .READ_LATENCY_A(0),             // DECIMAL
      .READ_LATENCY_B(0),             // DECIMAL
      .READ_RESET_VALUE_A("0"),       // String
      .READ_RESET_VALUE_B("0"),       // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WRITE_DATA_WIDTH_A($bits(tlb_entry_t))         // DECIMAL
   )
   xpm_memory_dpdistram_inst1 (
      .douta(entry_ob),   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(t0b),   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .addra(entry_no),   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .addrb(vadr0[22:16]),   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
      .clka(clk),     // 1-bit input: Clock signal for port A. Also clocks port B when parameter CLOCKING_MODE
                       // is "common_clock".

      .clkb(clk),     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                       // "independent_clock". Unused when parameter CLOCKING_MODE is "common_clock".

      .dina(entry_i),     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(way),       // 1-bit input: Memory enable signal for port A. Must be high on clock cycles when read
                       // or write operations are initiated. Pipelined internally.

      .enb(1'b1),       // 1-bit input: Memory enable signal for port B. Must be high on clock cycles when read
                       // or write operations are initiated. Pipelined internally.

      .regcea(1'b1), // 1-bit input: Clock Enable for the last register stage on the output data path.
      .regceb(1'b1), // 1-bit input: Do not change from the provided value.
      .rsta(1'b0),     // 1-bit input: Reset signal for the final port A output register stage. Synchronously
                       // resets output port douta to the value specified by parameter READ_RESET_VALUE_A.

      .rstb(1'b0),     // 1-bit input: Reset signal for the final port B output register stage. Synchronously
                       // resets output port doutb to the value specified by parameter READ_RESET_VALUE_B.

      .wea(wr)        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector for port A input
                       // data port dina. 1 bit wide when word-wide writes are used. In byte-wide write
                       // configurations, each bit controls the writing one byte of dina to address addra. For
                       // example, to synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A is
                       // 32, wea would be 4'b0010.

   );

   xpm_memory_dpdistram #(
      .ADDR_WIDTH_A(7),               // DECIMAL
      .ADDR_WIDTH_B(7),               // DECIMAL
      .BYTE_WRITE_WIDTH_A($bits(tlb_entry_t)),        // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_SIZE($bits(tlb_entry_t)*128),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_A($bits(tlb_entry_t)),         // DECIMAL
      .READ_DATA_WIDTH_B($bits(tlb_entry_t)),         // DECIMAL
      .READ_LATENCY_A(0),             // DECIMAL
      .READ_LATENCY_B(0),             // DECIMAL
      .READ_RESET_VALUE_A("0"),       // String
      .READ_RESET_VALUE_B("0"),       // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WRITE_DATA_WIDTH_A($bits(tlb_entry_t))         // DECIMAL
   )
   xpm_memory_dpdistram_inst2 (
      .douta(),   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(t1a),   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .addra(entry_no),   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .addrb(vadr1[22:16]),   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
      .clka(clk),     // 1-bit input: Clock signal for port A. Also clocks port B when parameter CLOCKING_MODE
                       // is "common_clock".

      .clkb(clk),     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                       // "independent_clock". Unused when parameter CLOCKING_MODE is "common_clock".

      .dina(entry_i),     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(~way),       // 1-bit input: Memory enable signal for port A. Must be high on clock cycles when read
                       // or write operations are initiated. Pipelined internally.

      .enb(1'b1),       // 1-bit input: Memory enable signal for port B. Must be high on clock cycles when read
                       // or write operations are initiated. Pipelined internally.

      .regcea(1'b1), // 1-bit input: Clock Enable for the last register stage on the output data path.
      .regceb(1'b1), // 1-bit input: Do not change from the provided value.
      .rsta(1'b0),     // 1-bit input: Reset signal for the final port A output register stage. Synchronously
                       // resets output port douta to the value specified by parameter READ_RESET_VALUE_A.

      .rstb(1'b0),     // 1-bit input: Reset signal for the final port B output register stage. Synchronously
                       // resets output port doutb to the value specified by parameter READ_RESET_VALUE_B.

      .wea(wr)        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector for port A input
                       // data port dina. 1 bit wide when word-wide writes are used. In byte-wide write
                       // configurations, each bit controls the writing one byte of dina to address addra. For
                       // example, to synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A is
                       // 32, wea would be 4'b0010.

   );

   xpm_memory_dpdistram #(
      .ADDR_WIDTH_A(7),               // DECIMAL
      .ADDR_WIDTH_B(7),               // DECIMAL
      .BYTE_WRITE_WIDTH_A($bits(tlb_entry_t)),        // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_SIZE($bits(tlb_entry_t)*128),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_A($bits(tlb_entry_t)),         // DECIMAL
      .READ_DATA_WIDTH_B($bits(tlb_entry_t)),         // DECIMAL
      .READ_LATENCY_A(0),             // DECIMAL
      .READ_LATENCY_B(0),             // DECIMAL
      .READ_RESET_VALUE_A("0"),       // String
      .READ_RESET_VALUE_B("0"),       // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WRITE_DATA_WIDTH_A($bits(tlb_entry_t))         // DECIMAL
   )
   xpm_memory_dpdistram_inst3 (
      .douta(),   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(t1b),   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .addra(entry_no),   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .addrb(vadr1[22:16]),   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
      .clka(clk),     // 1-bit input: Clock signal for port A. Also clocks port B when parameter CLOCKING_MODE
                       // is "common_clock".

      .clkb(clk),     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                       // "independent_clock". Unused when parameter CLOCKING_MODE is "common_clock".

      .dina(entry_i),     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(way),       // 1-bit input: Memory enable signal for port A. Must be high on clock cycles when read
                       // or write operations are initiated. Pipelined internally.

      .enb(1'b1),       // 1-bit input: Memory enable signal for port B. Must be high on clock cycles when read
                       // or write operations are initiated. Pipelined internally.

      .regcea(1'b1), // 1-bit input: Clock Enable for the last register stage on the output data path.
      .regceb(1'b1), // 1-bit input: Do not change from the provided value.
      .rsta(1'b0),     // 1-bit input: Reset signal for the final port A output register stage. Synchronously
                       // resets output port douta to the value specified by parameter READ_RESET_VALUE_A.

      .rstb(1'b0),     // 1-bit input: Reset signal for the final port B output register stage. Synchronously
                       // resets output port doutb to the value specified by parameter READ_RESET_VALUE_B.

      .wea(wr)        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector for port A input
                       // data port dina. 1 bit wide when word-wide writes are used. In byte-wide write
                       // configurations, each bit controls the writing one byte of dina to address addra. For
                       // example, to synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A is
                       // 32, wea would be 4'b0010.

   );

   xpm_memory_dpdistram #(
      .ADDR_WIDTH_A(7),               // DECIMAL
      .ADDR_WIDTH_B(7),               // DECIMAL
      .BYTE_WRITE_WIDTH_A($bits(tlb_entry_t)),        // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_SIZE($bits(tlb_entry_t)*128),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_A($bits(tlb_entry_t)),         // DECIMAL
      .READ_DATA_WIDTH_B($bits(tlb_entry_t)),         // DECIMAL
      .READ_LATENCY_A(0),             // DECIMAL
      .READ_LATENCY_B(0),             // DECIMAL
      .READ_RESET_VALUE_A("0"),       // String
      .READ_RESET_VALUE_B("0"),       // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WRITE_DATA_WIDTH_A($bits(tlb_entry_t))         // DECIMAL
   )
   xpm_memory_dpdistram_inst4 (
      .douta(),   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(t2a),   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .addra(entry_no),   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .addrb(pc_vadr[34:28]),   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
      .clka(clk),     // 1-bit input: Clock signal for port A. Also clocks port B when parameter CLOCKING_MODE
                       // is "common_clock".

      .clkb(clk),     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                       // "independent_clock". Unused when parameter CLOCKING_MODE is "common_clock".

      .dina(entry_i),     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(~way),       // 1-bit input: Memory enable signal for port A. Must be high on clock cycles when read
                       // or write operations are initiated. Pipelined internally.

      .enb(1'b1),       // 1-bit input: Memory enable signal for port B. Must be high on clock cycles when read
                       // or write operations are initiated. Pipelined internally.

      .regcea(1'b1), // 1-bit input: Clock Enable for the last register stage on the output data path.
      .regceb(1'b1), // 1-bit input: Do not change from the provided value.
      .rsta(1'b0),     // 1-bit input: Reset signal for the final port A output register stage. Synchronously
                       // resets output port douta to the value specified by parameter READ_RESET_VALUE_A.

      .rstb(1'b0),     // 1-bit input: Reset signal for the final port B output register stage. Synchronously
                       // resets output port doutb to the value specified by parameter READ_RESET_VALUE_B.

      .wea(wr)        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector for port A input
                       // data port dina. 1 bit wide when word-wide writes are used. In byte-wide write
                       // configurations, each bit controls the writing one byte of dina to address addra. For
                       // example, to synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A is
                       // 32, wea would be 4'b0010.

   );

   xpm_memory_dpdistram #(
      .ADDR_WIDTH_A(7),               // DECIMAL
      .ADDR_WIDTH_B(7),               // DECIMAL
      .BYTE_WRITE_WIDTH_A($bits(tlb_entry_t)),        // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_SIZE($bits(tlb_entry_t)*128),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_A($bits(tlb_entry_t)),         // DECIMAL
      .READ_DATA_WIDTH_B($bits(tlb_entry_t)),         // DECIMAL
      .READ_LATENCY_A(0),             // DECIMAL
      .READ_LATENCY_B(0),             // DECIMAL
      .READ_RESET_VALUE_A("0"),       // String
      .READ_RESET_VALUE_B("0"),       // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WRITE_DATA_WIDTH_A($bits(tlb_entry_t))         // DECIMAL
   )
   xpm_memory_dpdistram_inst5 (
      .douta(),   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(t2b),   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .addra(entry_no),   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .addrb(pc_vadr[34:28]),   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
      .clka(clk),     // 1-bit input: Clock signal for port A. Also clocks port B when parameter CLOCKING_MODE
                       // is "common_clock".

      .clkb(clk),     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                       // "independent_clock". Unused when parameter CLOCKING_MODE is "common_clock".

      .dina(entry_i),     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(way),       // 1-bit input: Memory enable signal for port A. Must be high on clock cycles when read
                       // or write operations are initiated. Pipelined internally.

      .enb(1'b1),       // 1-bit input: Memory enable signal for port B. Must be high on clock cycles when read
                       // or write operations are initiated. Pipelined internally.

      .regcea(1'b1), // 1-bit input: Clock Enable for the last register stage on the output data path.
      .regceb(1'b1), // 1-bit input: Do not change from the provided value.
      .rsta(1'b0),     // 1-bit input: Reset signal for the final port A output register stage. Synchronously
                       // resets output port douta to the value specified by parameter READ_RESET_VALUE_A.

      .rstb(1'b0),     // 1-bit input: Reset signal for the final port B output register stage. Synchronously
                       // resets output port doutb to the value specified by parameter READ_RESET_VALUE_B.

      .wea(wr)        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector for port A input
                       // data port dina. 1 bit wide when word-wide writes are used. In byte-wide write
                       // configurations, each bit controls the writing one byte of dina to address addra. For
                       // example, to synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A is
                       // 32, wea would be 4'b0010.

   );

reg miss0, miss1, pc_miss;
reg inq0, inq1, pc_inq;

always_comb
begin
	inq0 = 1'b0;
	inq1 = 1'b0;
	pc_inq = 1'b0;
	for (n = 0; n < MISSQ_ENTRIES; n = n + 1)
		if (vadr0==missadr[n] && asid0==missasid[n])
			inq0 = 1'b1;
	for (n = 0; n < MISSQ_ENTRIES-1; n = n + 1)
		if (vadr1==missadr[n] && asid1==missasid[n])
			inq1 = 1'b1;
	for (n = 0; n < MISSQ_ENTRIES-1; n = n + 1)
		if (pc_vadr[43:12]==missadr[n] && pc_asid==missasid[n])
			pc_inq = 1'b1;
end

always_comb
begin
	miss0 = 'd0;
	miss1 = 'd0;
	pc_miss = 'd0;
	if (t0a.vpn.vpn[8:0]==vadr0[31:23] && t0a.vpn.asid==asid0) begin
	end
	else if (t0b.vpn.vpn[8:0]==vadr0[31:23] && t0b.vpn.asid==asid0) begin
	end
	else
		miss0 = !inq0;
	if (t1a.vpn.vpn[8:0]==vadr1[31:23] && t1a.vpn.asid==asid1) begin
	end
	else if (t1b.vpn.vpn[8:0]==vadr1[31:23] && t1b.vpn.asid==asid1) begin
	end
	else
		miss1 = !inq1;
	if (t2a.vpn.vpn[8:0]==pc_vadr[43:35] && t2a.vpn.asid==pc_asid) begin
	end
	else if (t2b.vpn.vpn[8:0]==pc_vadr[43:35] && t2b.vpn.asid==pc_asid) begin
	end
	else
		pc_miss = !pc_inq;
end

always_ff @(posedge clk)
if (rst) begin
	entry0 <= 'd0;
	tlb0_v <= 'd0;
	tlb0_op <= 'd0;
	tlb0_res <= 'd0;
	load0_o <= 'd0;
	store0_o <= 'd0;

	entry1 <= 'd0;
	tlb1_v <= 'd0;
	tlb1_op <= 'd0;
	tlb1_res <= 'd0;
	load1_o <= 'd0;
	store1_o <= 'd0;
	
	pc_entry <= 'd0;
	
	omd0a <= OM_MACHINE;
	omd1a <= OM_MACHINE;
	
	agen0_rndx_o <= 'd0;
	agen1_rndx_o <= 'd0;
end
else begin
	miss_o <= 1'b0;
	if (!stall_tlb0) begin
		if (t0a.vpn.vpn[8:0]==vadr0[31:23] && t0a.vpn.asid==asid0) begin
			entry0 <= t0a;
			tlb0_op <= op0;
			tlb0_res <= vadr0;
			load0_o <= load0_i;
			store0_o <= store0_i;
			agen0_rndx_o <= agen0_rndx_i;
			tlb0_v <= 1'd1;
			omd0a <= omd0;
		end
		else if (t0b.vpn.vpn[8:0]==vadr0[31:23] && t0b.vpn.asid==asid0) begin
			entry0 <= t0b;
			tlb0_op <= op0;
			tlb0_res <= vadr0;
			load0_o <= load0_i;
			store0_o <= store0_i;
			agen0_rndx_o <= agen0_rndx_i;
			tlb0_v <= 1'd1;
			omd0a <= omd0;
		end
		else begin
			entry0 <= 'd0;
			tlb0_v <= 'd0;
			tlb0_op <= 'd0;
			tlb0_res <= 'd0;
			load0_o <= 'd0;
			store0_o <= 'd0;
		end
	end

	if (!stall_tlb1) begin
		if (t1a.vpn.vpn[8:0]==vadr1[31:23] && t1a.vpn.asid==asid1) begin
			entry1 <= t1a;
			tlb1_op <= op1;
			tlb1_res <= vadr1;
			load1_o <= load1_i;
			store1_o <= store1_i;
			agen1_rndx_o <= agen1_rndx_i;
			tlb1_v <= 1'd1;
			omd1a <= omd1;
		end
		else if (t1b.vpn.vpn[8:0]==vadr1[31:23] && t1b.vpn.asid==asid1) begin
			entry1 <= t1b;
			tlb1_op <= op1;
			tlb1_res <= vadr1;
			load1_o <= load1_i;
			store1_o <= store1_i;
			agen1_rndx_o <= agen1_rndx_i;
			tlb1_v <= 1'd1;
			omd1a <= omd1;
		end
		else begin
			entry1 <= 'd0;
			tlb1_v <= 'd0;
			tlb1_op <= 'd0;
			tlb1_res <= 'd0;
			load1_o <= 'd0;
			store1_o <= 'd0;
		end
	end

	if (t2a.vpn.vpn[8:0]==pc_vadr[43:35] && t2a.vpn.asid==pc_asid) begin
		pc_entry <= t2a;
		pc_tlb_res <= {pc_vadr,12'h0};
		pc_omda <= pc_omd;
		pc_tlb_v <= 'd1;
	end
	else if (t2b.vpn.vpn[8:0]==pc_vadr[43:35] && t2b.vpn.asid==pc_asid) begin
		pc_entry <= t2b;
		pc_tlb_res <= {pc_vadr,12'h0};
		pc_omda <= pc_omd;
		pc_tlb_v <= 'd1;
	end
	else begin
		pc_entry <= 'd0;
		pc_tlb_v <= 'd0;
		pc_tlb_res <= 'd0;
	end

	if ((head != (tail - 1) % MISSQ_ENTRIES) && (head != (tail - 2) % MISSQ_ENTRIES) && (head != (tail - 3) % MISSQ_ENTRIES))
		case ({miss1,miss0,pc_miss})
		3'b000:	;
		3'b001:
			begin
				missadr[tail] <= pc_vadr[43:12];
				missasid[tail] <= pc_asid;
				tail <= (tail + 1) % MISSQ_ENTRIES;
			end
		3'b010:
			begin
				missadr[tail] <= vadr0;
				missasid[tail] <= asid0;
				tail <= (tail + 1) % MISSQ_ENTRIES;
			end
		3'b011:
			begin
				missadr[tail] <= pc_vadr[43:12];
				missasid[tail] <= pc_asid;
				missadr[(tail+1) % MISSQ_ENTRIES] <= vadr0;
				missasid[(tail+1) % MISSQ_ENTRIES] <= asid0;
				tail <= (tail + 2) % MISSQ_ENTRIES;
			end
		3'b100:
			begin
				missadr[tail] <= vadr1;
				missasid[tail] <= asid1;
				tail <= (tail + 1) % MISSQ_ENTRIES;
			end
		3'b101:
			begin
				missadr[tail] <= pc_vadr[43:12];
				missasid[tail] <= pc_asid;
				missadr[(tail+1) % MISSQ_ENTRIES] <= vadr1;
				missasid[(tail+1) % MISSQ_ENTRIES] <= asid1;
				tail <= (tail + 2) % MISSQ_ENTRIES;
			end
		3'b110:
			begin
				missadr[tail] <= vadr0;
				missasid[tail] <= asid0;
				missadr[(tail+1) % MISSQ_ENTRIES] <= vadr1;
				missasid[(tail+1) % MISSQ_ENTRIES] <= asid1;
				tail <= (tail + 2) % MISSQ_ENTRIES;
			end
		3'b111:
			begin
				missadr[tail] <= pc_vadr[43:12];
				missasid[tail] <= pc_asid;
				missadr[(tail+1) % MISSQ_ENTRIES] <= vadr0;
				missasid[(tail+1) % MISSQ_ENTRIES] <= asid0;
				missadr[(tail+2) % MISSQ_ENTRIES] <= vadr1;
				missasid[(tail+2) % MISSQ_ENTRIES] <= asid1;
				tail <= (tail + 3) % MISSQ_ENTRIES;
			end
		endcase
	if (missack) begin
		head <= (head + 1) % MISSQ_ENTRIES;
	end
	if (head != tail) begin
		missadr_o <= missadr[head];
		missasid_o <= missasid[head];
		miss_o <= 1'b1;
	end
end

always_comb
begin
	entry0_o = entry0;
	entry0_o.pte.urwx = |entry0.pte.urwx ? entry0.pte.urwx : region0.at[0].rwx;
	entry0_o.pte.srwx = |entry0.pte.srwx ? entry0.pte.srwx : region0.at[1].rwx;
	entry0_o.pte.hrwx = |entry0.pte.hrwx ? entry0.pte.hrwx : region0.at[2].rwx;
	entry0_o.pte.mrwx = |entry0.pte.mrwx ? entry0.pte.mrwx : region0.at[3].rwx;

	entry1_o = entry1;
	entry1_o.pte.urwx = |entry1.pte.urwx ? entry1.pte.urwx : region1.at[0].rwx;
	entry1_o.pte.srwx = |entry1.pte.srwx ? entry1.pte.srwx : region1.at[1].rwx;
	entry1_o.pte.hrwx = |entry1.pte.hrwx ? entry1.pte.hrwx : region1.at[2].rwx;
	entry1_o.pte.mrwx = |entry1.pte.mrwx ? entry1.pte.mrwx : region1.at[3].rwx;

	pc_entry_o = pc_entry;
	pc_entry_o.pte.urwx = |pc_entry.pte.urwx ? pc_entry.pte.urwx : region2.at[0].rwx;
	pc_entry_o.pte.srwx = |pc_entry.pte.srwx ? pc_entry.pte.srwx : region2.at[1].rwx;
	pc_entry_o.pte.hrwx = |pc_entry.pte.hrwx ? pc_entry.pte.hrwx : region2.at[2].rwx;
	pc_entry_o.pte.mrwx = |pc_entry.pte.mrwx ? pc_entry.pte.mrwx : region2.at[3].rwx;

	// Cache-ability output. Region takes precedence.
	case(fta_cache_t'(region0.at[omd0a].cache))
	fta_bus_pkg::NC_NB:					entry0_o.pte.cache = fta_bus_pkg::NC_NB;
	fta_bus_pkg::NON_CACHEABLE:	entry0_o.pte.cache = fta_bus_pkg::NON_CACHEABLE;
	fta_bus_pkg::CACHEABLE_NB:
		case(fta_cache_t'(entry0.pte.cache))
		fta_bus_pkg::NC_NB:					entry0_o.pte.cache = fta_bus_pkg::NC_NB;
		fta_bus_pkg::NON_CACHEABLE:	entry0_o.pte.cache = fta_bus_pkg::NON_CACHEABLE;
		fta_bus_pkg::CACHEABLE_NB:		entry0_o.pte.cache = fta_bus_pkg::CACHEABLE_NB;
		fta_bus_pkg::CACHEABLE:			entry0_o.pte.cache = fta_bus_pkg::CACHEABLE_NB;
		default:				entry0_o.pte.cache = entry0.pte.cache;
		endcase
	fta_bus_pkg::CACHEABLE:
		case(fta_cache_t'(entry0.pte.cache))
		fta_bus_pkg::NC_NB:					entry0_o.pte.cache = fta_bus_pkg::NC_NB;
		fta_bus_pkg::NON_CACHEABLE:	entry0_o.pte.cache = fta_bus_pkg::NON_CACHEABLE;
		fta_bus_pkg::CACHEABLE_NB:		entry0_o.pte.cache = fta_bus_pkg::CACHEABLE_NB;
		default:				entry0_o.pte.cache = entry0.pte.cache;
		endcase
	fta_bus_pkg::WT_NO_ALLOCATE,fta_bus_pkg::WT_READ_ALLOCATE,fta_bus_pkg::WT_WRITE_ALLOCATE,fta_bus_pkg::WT_READWRITE_ALLOCATE,
	fta_bus_pkg::WB_NO_ALLOCATE,fta_bus_pkg::WB_READ_ALLOCATE,fta_bus_pkg::WB_WRITE_ALLOCATE,fta_bus_pkg::WB_READWRITE_ALLOCATE:
		case(fta_cache_t'(entry0.pte.cache))
		fta_bus_pkg::NC_NB:					entry0_o.pte.cache = fta_bus_pkg::NC_NB;
		fta_bus_pkg::NON_CACHEABLE:	entry0_o.pte.cache = fta_bus_pkg::NON_CACHEABLE;
		default:				entry0_o.pte.cache = region0.at[omd0a].cache;
		endcase
	default:	entry0_o.pte.cache = fta_bus_pkg::NC_NB;
	endcase

	case(fta_cache_t'(region1.at[omd1a].cache))
	fta_bus_pkg::NC_NB:					entry1_o.pte.cache = fta_bus_pkg::NC_NB;
	fta_bus_pkg::NON_CACHEABLE:	entry1_o.pte.cache = fta_bus_pkg::NON_CACHEABLE;
	fta_bus_pkg::CACHEABLE_NB:
		case(fta_cache_t'(entry1.pte.cache))
		fta_bus_pkg::NC_NB:					entry1_o.pte.cache = fta_bus_pkg::NC_NB;
		fta_bus_pkg::NON_CACHEABLE:	entry1_o.pte.cache = fta_bus_pkg::NON_CACHEABLE;
		fta_bus_pkg::CACHEABLE_NB:		entry1_o.pte.cache = fta_bus_pkg::CACHEABLE_NB;
		fta_bus_pkg::CACHEABLE:			entry1_o.pte.cache = fta_bus_pkg::CACHEABLE_NB;
		default:				entry1_o.pte.cache = entry1.pte.cache;
		endcase
	fta_bus_pkg::CACHEABLE:
		case(fta_cache_t'(entry1.pte.cache))
		fta_bus_pkg::NC_NB:					entry1_o.pte.cache = fta_bus_pkg::NC_NB;
		fta_bus_pkg::NON_CACHEABLE:	entry1_o.pte.cache = fta_bus_pkg::NON_CACHEABLE;
		fta_bus_pkg::CACHEABLE_NB:		entry1_o.pte.cache = fta_bus_pkg::CACHEABLE_NB;
		default:				entry1_o.pte.cache = entry1.pte.cache;
		endcase
	fta_bus_pkg::WT_NO_ALLOCATE,fta_bus_pkg::WT_READ_ALLOCATE,fta_bus_pkg::WT_WRITE_ALLOCATE,fta_bus_pkg::WT_READWRITE_ALLOCATE,
	fta_bus_pkg::WB_NO_ALLOCATE,fta_bus_pkg::WB_READ_ALLOCATE,fta_bus_pkg::WB_WRITE_ALLOCATE,fta_bus_pkg::WB_READWRITE_ALLOCATE:
		case(fta_cache_t'(entry1.pte.cache))
		fta_bus_pkg::NC_NB:					entry1_o.pte.cache = fta_bus_pkg::NC_NB;
		fta_bus_pkg::NON_CACHEABLE:	entry1_o.pte.cache = fta_bus_pkg::NON_CACHEABLE;
		default:				entry1_o.pte.cache = region1.at[omd1a].cache;
		endcase
	default:	entry1_o.pte.cache = fta_bus_pkg::NC_NB;
	endcase

	case(fta_cache_t'(region2.at[pc_omda].cache))
	fta_bus_pkg::NC_NB:					pc_entry_o.pte.cache = fta_bus_pkg::NC_NB;
	fta_bus_pkg::NON_CACHEABLE:	pc_entry_o.pte.cache = fta_bus_pkg::NON_CACHEABLE;
	fta_bus_pkg::CACHEABLE_NB:
		case(fta_cache_t'(pc_entry.pte.cache))
		fta_bus_pkg::NC_NB:					pc_entry_o.pte.cache = fta_bus_pkg::NC_NB;
		fta_bus_pkg::NON_CACHEABLE:	pc_entry_o.pte.cache = fta_bus_pkg::NON_CACHEABLE;
		fta_bus_pkg::CACHEABLE_NB:		pc_entry_o.pte.cache = fta_bus_pkg::CACHEABLE_NB;
		fta_bus_pkg::CACHEABLE:			pc_entry_o.pte.cache = fta_bus_pkg::CACHEABLE_NB;
		default:				pc_entry_o.pte.cache = pc_entry.pte.cache;
		endcase
	fta_bus_pkg::CACHEABLE:
		case(fta_cache_t'(pc_entry.pte.cache))
		fta_bus_pkg::NC_NB:					pc_entry_o.pte.cache = fta_bus_pkg::NC_NB;
		fta_bus_pkg::NON_CACHEABLE:	pc_entry_o.pte.cache = fta_bus_pkg::NON_CACHEABLE;
		fta_bus_pkg::CACHEABLE_NB:		pc_entry_o.pte.cache = fta_bus_pkg::CACHEABLE_NB;
		default:				pc_entry_o.pte.cache = pc_entry.pte.cache;
		endcase
	fta_bus_pkg::WT_NO_ALLOCATE,fta_bus_pkg::WT_READ_ALLOCATE,fta_bus_pkg::WT_WRITE_ALLOCATE,fta_bus_pkg::WT_READWRITE_ALLOCATE,
	fta_bus_pkg::WB_NO_ALLOCATE,fta_bus_pkg::WB_READ_ALLOCATE,fta_bus_pkg::WB_WRITE_ALLOCATE,fta_bus_pkg::WB_READWRITE_ALLOCATE:
		case(fta_cache_t'(pc_entry.pte.cache))
		fta_bus_pkg::NC_NB:					pc_entry_o.pte.cache = fta_bus_pkg::NC_NB;
		fta_bus_pkg::NON_CACHEABLE:	pc_entry_o.pte.cache = fta_bus_pkg::NON_CACHEABLE;
		default:				pc_entry_o.pte.cache = region2.at[pc_omda].cache;
		endcase
	default:	pc_entry_o.pte.cache = fta_bus_pkg::NC_NB;
	endcase
end

assign entry_o = way ? entry_ob : entry_oa;

endmodule
