// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2026  Robert Finch, Waterloo
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
// 8500 LUTs / 2950 FFs / 27 BRAMs / 170 MHz (Tiny 3 way)
// 9568 LUTs / 2474 FFs / 31.5 BRAMs (Small 3 way)
// ============================================================================

import const_pkg::*;
import wishbone_pkg::*;
import mmu_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

// The lowest 11 bits of the VPN are not needed for comparison at L2. They are
// stored because they are needed at L1.
`define VPN_BITS	19:11
`define VADR_BITS	31:24
`define L1_VPN_BITS	19:0
`define L1_VADR_BITS	31:13
`define L1_VPN_BITS_LVL2	19:11
`define L1_VADR_BITS_LVL2	31:24
`define L2_VPN_BITS		18:17
`define L2_VADR_BITS	31:30

// These bits are used to select the TLB entry
`define VADR_MBITS 23:13
`undef VADR_L2_MBITS
`define VADR_L2_MBITS 30:23
// These bits are passed through verbatium
`define VADR_PBITS_LVL1 12:0
`define VADR_PBITS_LVL2 22:0

module tlb3way(rst, clk, paging_en,
	wr, way, entry_no, entry_i, entry_o, vadr0, vadr1, vadr2,
	omd0, omd1, pc_omd,
	asid0, asid1, asid2, entry0_o, entry1_o, entry2_o,
	miss_o, missadr_o, missasid_o, missid_o, missqn_o, missack, missswt_o,
	padr0_v, padr1_v, padr2_v, pswt_v, op0, op1, tlb0_op, tlb1_op, padr0, padr1, padr2,
	load0_i, load1_i, store0_i, store1_i, load0_o, load1_o, store0_o, store1_o,
	stall_tlb0, stall_tlb1, swt_i, swt_o,
	agen0_rndx_i, agen1_rndx_i, agen2_rndx_i,
	agen0_rndx_o, agen1_rndx_o, agen2_rndx_o,
	agen0_v, agen1_v, agen2_v, swt_v);
parameter WAYS=3;
parameter TLB_ENTRIES = 2048;
parameter TLB_L2_ENTRIES = 128;
parameter MISSQ_ENTRIES = 16;
localparam TLB_ABITS = $clog2(TLB_ENTRIES);
localparam TLB_L2_ABITS = $clog2(TLB_L2_ENTRIES);
localparam AMSB = $bits(pc_address_t)-1;
localparam BMSB = LOG_PAGE_SIZE;
localparam VMSB = $bits(virtual_address_t)-1;
input rst;
input clk;
input paging_en;
input wr;
input [1:0] way;
input [10:0] entry_no;
input tlb_entry_t entry_i;
output tlb_entry_t entry_o;
input address_t vadr0;
input address_t vadr1;
input address_t vadr2;
input Qupls4_pkg::operating_mode_t omd0;
input Qupls4_pkg::operating_mode_t omd1;
input Qupls4_pkg::operating_mode_t omd2;
input asid_t asid0;
input asid_t asid1;
input asid_t asid2;
output tlb_entry_t entry0_o;
output tlb_entry_t entry1_o;
output tlb_entry_t entry2_o;
output reg miss_o;
output address_t missadr_o;
output asid_t missasid_o;
output rob_ndx_t missid_o;
output reg [1:0] missqn_o;
output reg missswt_o;
input missack;
output reg padr0_v;
output reg padr1_v;
output reg padr2_v;
output reg pswt_v;
input Qupls4_pkg::micro_op_t op0;
input Qupls4_pkg::micro_op_t op1;
output Qupls4_pkg::micro_op_t tlb0_op;
output Qupls4_pkg::micro_op_t tlb1_op;
output physical_address_t padr0;
output physical_address_t padr1;
output physical_address_t padr2;
output pc_padr_v;
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
input rob_ndx_t agen2_rndx_i;
input swt_i;
output rob_ndx_t agen0_rndx_o;
output rob_ndx_t agen1_rndx_o;
output rob_ndx_t agen2_rndx_o;
output reg swt_o;
input agen0_v;
input agen1_v;
input agen2_v;
input swt_v;

reg [2:0] grant;
address_t L1_miss_adr;
asid_t L1_miss_asid;
reg [2:0] wway;
address_t vadr0r;
address_t vadr1r;
address_t vadr2r;
reg [10:0] entryno, entryno_rst;
tlb_entry_t entryi, entryi_rst;
reg [1:0] wayi;
reg wri;
tlb_entry_t entry0;
tlb_entry_t entry1;
tlb_entry_t t0a, t0b, t0c, t0d, t0aw, t0bw, t0cw;
tlb_entry_t t1a, t1b, t1c, t1d, t1aw, t1bw, t1cw;
tlb_entry_t t2a, t2b, t2c, t2d, t2aw, t2bw, t2cw;
tlb_entry_t t0aL2, t0bL2, t0cL2, t0dL2, t0awL2, t0bwL2, t0cwL2;
tlb_entry_t t1aL2, t1bL2, t1cL2, t1dL2, t1awL2, t1bwL2, t1cwL2;
tlb_entry_t t2aL2, t2bL2, t2cL2, t2dL2, t2awL2, t2bwL2, t2cwL2;
tlb_entry_t entry_oa, entry_ob, entry_oc, entry_od;
reg [3:0] head, tail;
reg [MISSQ_ENTRIES-1:0] missswt;
address_t [MISSQ_ENTRIES-1:0] missadr;
asid_t [MISSQ_ENTRIES-1:0] missasid;
reg [1:0] missqn [0:MISSQ_ENTRIES-1];
rob_ndx_t [MISSQ_ENTRIES-1:0] missid;
REGION region0, region1, region2;
wire [7:0] sel0, sel1, sel2;
Qupls4_pkg::operating_mode_t omd0a, omd1a, pc_omda;
reg [10:0] rstcnt;
reg web0a=1'b0, web0b=1'b0, web0c=1'b0;
reg web1a=1'b0, web1b=1'b0, web1c=1'b0;
reg web2a=1'b0, web2b=1'b0, web2c=1'b0;
reg web0aL2=1'b0, web0bL2=1'b0, web0cL2=1'b0;
reg web1aL2=1'b0, web1bL2=1'b0, web1cL2=1'b0;
reg web2aL2=1'b0, web2bL2=1'b0, web2cL2=1'b0;
reg store0r, store1r;
tlb_entry_t [7:0] L1tlb;
virtual_address_t miss0_adr, miss1_adr, miss2_adr, miss_adr, miss_adr_r;
asid_t miss_asid;
wire miss0_v, miss1_v, miss2_v;

integer n,m,n1,n2,n3,n4;
initial begin
	for (n2 = 0; n2 < 8; n2 = n2 + 1)
		L1tlb[n2] = {$bits(tlb_entry_t){1'b0}};
end

always_ff @(posedge clk) miss_adr_r <= miss_adr;
always_ff @(posedge clk) store0r <= store0_i;
always_ff @(posedge clk) store1r <= store1_i;


   // xpm_memory_tdpram: True Dual Port RAM
   // Xilinx Parameterized Macro, version 2022.2

   xpm_memory_tdpram #(
      .ADDR_WIDTH_A(TLB_ABITS),               // DECIMAL
      .ADDR_WIDTH_B(TLB_ABITS),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A($bits(tlb_entry_t)),        // DECIMAL
      .BYTE_WRITE_WIDTH_B($bits(tlb_entry_t)),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("auto"),      // String
      .MEMORY_SIZE(TLB_ENTRIES*$bits(tlb_entry_t)),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_A($bits(tlb_entry_t)),         // DECIMAL
      .READ_DATA_WIDTH_B($bits(tlb_entry_t)),         // DECIMAL
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
      .WRITE_DATA_WIDTH_A($bits(tlb_entry_t)),        // DECIMAL
      .WRITE_DATA_WIDTH_B($bits(tlb_entry_t)),        // DECIMAL
      .WRITE_MODE_A("read_first"),     // String
      .WRITE_MODE_B("read_first"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   xpm_memory_tdpram_inst00 (
      .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .douta(entry_oa),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(t0a),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port A.

      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(entryno),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .addrb(L1_miss_adr[`VADR_MBITS]),                   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
      .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(entryi),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .dinb(t0aw),                     // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
      .ena(wayi==2'd0 && entryi.pte.l1.lvl==3'd1), 	// 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when read or write operations are initiated. Pipelined
                                       // internally.

      .enb(1'b1),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
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

      .regcea(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rsta(rst),                     // 1-bit input: Reset signal for the final port A output register stage.
                                       // Synchronously resets output port douta to the value specified by
                                       // parameter READ_RESET_VALUE_A.

      .rstb(rst),                     // 1-bit input: Reset signal for the final port B output register stage.
                                       // Synchronously resets output port doutb to the value specified by
                                       // parameter READ_RESET_VALUE_B.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(wri),                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

      .web(web0a)                      // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector
                                       // for port B input data port dinb. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dinb to address addrb. For example, to
                                       // synchronously write only bits [15-8] of dinb when WRITE_DATA_WIDTH_B
                                       // is 32, web would be 4'b0010.

   );

   xpm_memory_tdpram #(
      .ADDR_WIDTH_A(TLB_ABITS),               // DECIMAL
      .ADDR_WIDTH_B(TLB_ABITS),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A($bits(tlb_entry_t)),        // DECIMAL
      .BYTE_WRITE_WIDTH_B($bits(tlb_entry_t)),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("auto"),      // String
      .MEMORY_SIZE(TLB_ENTRIES*$bits(tlb_entry_t)),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_A($bits(tlb_entry_t)),         // DECIMAL
      .READ_DATA_WIDTH_B($bits(tlb_entry_t)),         // DECIMAL
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
      .WRITE_DATA_WIDTH_A($bits(tlb_entry_t)),        // DECIMAL
      .WRITE_DATA_WIDTH_B($bits(tlb_entry_t)),        // DECIMAL
      .WRITE_MODE_A("read_first"),     // String
      .WRITE_MODE_B("read_first"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   xpm_memory_tdpram_inst01 (
      .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .douta(entry_ob),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(t0b),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port A.

      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(entryno),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .addrb(L1_miss_adr[`VADR_MBITS]),                   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
      .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(entryi),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .dinb(t0bw),                     // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
      .ena(wayi==2'd1 && entryi.pte.l1.lvl==3'd1), 	// 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when read or write operations are initiated. Pipelined
                                       // internally.

      .enb(1'b1),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
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

      .regcea(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rsta(rst),                     // 1-bit input: Reset signal for the final port A output register stage.
                                       // Synchronously resets output port douta to the value specified by
                                       // parameter READ_RESET_VALUE_A.

      .rstb(rst),                     // 1-bit input: Reset signal for the final port B output register stage.
                                       // Synchronously resets output port doutb to the value specified by
                                       // parameter READ_RESET_VALUE_B.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(wri),                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

      .web(web0b)                      // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector
                                       // for port B input data port dinb. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dinb to address addrb. For example, to
                                       // synchronously write only bits [15-8] of dinb when WRITE_DATA_WIDTH_B
                                       // is 32, web would be 4'b0010.

   );

   xpm_memory_tdpram #(
      .ADDR_WIDTH_A(TLB_ABITS),               // DECIMAL
      .ADDR_WIDTH_B(TLB_ABITS),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A($bits(tlb_entry_t)),        // DECIMAL
      .BYTE_WRITE_WIDTH_B($bits(tlb_entry_t)),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("auto"),      // String
      .MEMORY_SIZE(TLB_ENTRIES*$bits(tlb_entry_t)),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_A($bits(tlb_entry_t)),         // DECIMAL
      .READ_DATA_WIDTH_B($bits(tlb_entry_t)),         // DECIMAL
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
      .WRITE_DATA_WIDTH_A($bits(tlb_entry_t)),        // DECIMAL
      .WRITE_DATA_WIDTH_B($bits(tlb_entry_t)),        // DECIMAL
      .WRITE_MODE_A("read_first"),     // String
      .WRITE_MODE_B("read_first"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   xpm_memory_tdpram_inst02 (
      .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .douta(entry_oc),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(t0c),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port A.

      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(entryno),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .addrb(L1_miss_adr[`VADR_MBITS]),                   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
      .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(entryi),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .dinb(t0cw),                     // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
      .ena(wayi==2'd2 && entryi.pte.l1.lvl==3'd1), 	// 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when read or write operations are initiated. Pipelined
                                       // internally.

      .enb(1'b1),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
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

      .regcea(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rsta(rst),                     // 1-bit input: Reset signal for the final port A output register stage.
                                       // Synchronously resets output port douta to the value specified by
                                       // parameter READ_RESET_VALUE_A.

      .rstb(rst),                     // 1-bit input: Reset signal for the final port B output register stage.
                                       // Synchronously resets output port doutb to the value specified by
                                       // parameter READ_RESET_VALUE_B.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(wri),                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

      .web(web0c)                        // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector
                                       // for port B input data port dinb. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dinb to address addrb. For example, to
                                       // synchronously write only bits [15-8] of dinb when WRITE_DATA_WIDTH_B
                                       // is 32, web would be 4'b0010.

   );


   // Level 2 entries
generate begin : gTLBLVL2
if (Qupls4_pkg::SUPPORT_TLBLVL2) begin
   xpm_memory_tdpram #(
      .ADDR_WIDTH_A(TLB_L2_ABITS),               // DECIMAL
      .ADDR_WIDTH_B(TLB_L2_ABITS),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A($bits(tlb_entry_t)),        // DECIMAL
      .BYTE_WRITE_WIDTH_B($bits(tlb_entry_t)),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("auto"),      // String
      .MEMORY_SIZE(TLB_L2_ENTRIES*$bits(tlb_entry_t)),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_A($bits(tlb_entry_t)),         // DECIMAL
      .READ_DATA_WIDTH_B($bits(tlb_entry_t)),         // DECIMAL
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
      .WRITE_DATA_WIDTH_A($bits(tlb_entry_t)),        // DECIMAL
      .WRITE_DATA_WIDTH_B($bits(tlb_entry_t)),        // DECIMAL
      .WRITE_MODE_A("read_first"),     // String
      .WRITE_MODE_B("read_first"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   xpm_memory_tdpram_inst30 (
      .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .douta(entry_oa),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(t0aL2),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port A.

      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(entryno),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .addrb(L1_miss_adr[`VADR_L2_MBITS]),                   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
      .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(entryi),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .dinb(t0awL2),                     // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
      .ena(wayi==2'd0 && entryi.pte.l2.lvl==3'd2), 	// 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when read or write operations are initiated. Pipelined
                                       // internally.

      .enb(1'b1),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
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

      .regcea(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rsta(rst),                     // 1-bit input: Reset signal for the final port A output register stage.
                                       // Synchronously resets output port douta to the value specified by
                                       // parameter READ_RESET_VALUE_A.

      .rstb(rst),                     // 1-bit input: Reset signal for the final port B output register stage.
                                       // Synchronously resets output port doutb to the value specified by
                                       // parameter READ_RESET_VALUE_B.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(wri),                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

      .web(web0aL2)                      // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector
                                       // for port B input data port dinb. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dinb to address addrb. For example, to
                                       // synchronously write only bits [15-8] of dinb when WRITE_DATA_WIDTH_B
                                       // is 32, web would be 4'b0010.

   );

   xpm_memory_tdpram #(
      .ADDR_WIDTH_A(TLB_L2_ABITS),               // DECIMAL
      .ADDR_WIDTH_B(TLB_L2_ABITS),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A($bits(tlb_entry_t)),        // DECIMAL
      .BYTE_WRITE_WIDTH_B($bits(tlb_entry_t)),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("auto"),      // String
      .MEMORY_SIZE(TLB_L2_ENTRIES*$bits(tlb_entry_t)),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_A($bits(tlb_entry_t)),         // DECIMAL
      .READ_DATA_WIDTH_B($bits(tlb_entry_t)),         // DECIMAL
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
      .WRITE_DATA_WIDTH_A($bits(tlb_entry_t)),        // DECIMAL
      .WRITE_DATA_WIDTH_B($bits(tlb_entry_t)),        // DECIMAL
      .WRITE_MODE_A("read_first"),     // String
      .WRITE_MODE_B("read_first"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   xpm_memory_tdpram_inst31 (
      .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .douta(entry_ob),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(t0bL2),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port A.

      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(entryno),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .addrb(L1_miss_adr[`VADR_L2_MBITS]),                   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
      .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(entryi),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .dinb(t0bwL2),                     // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
      .ena(wayi==2'd1 && entryi.pte.l2.lvl==3'd2), 	// 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when read or write operations are initiated. Pipelined
                                       // internally.

      .enb(1'b1),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
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

      .regcea(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rsta(rst),                     // 1-bit input: Reset signal for the final port A output register stage.
                                       // Synchronously resets output port douta to the value specified by
                                       // parameter READ_RESET_VALUE_A.

      .rstb(rst),                     // 1-bit input: Reset signal for the final port B output register stage.
                                       // Synchronously resets output port doutb to the value specified by
                                       // parameter READ_RESET_VALUE_B.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(wri),                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

      .web(web0bL2)                      // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector
                                       // for port B input data port dinb. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dinb to address addrb. For example, to
                                       // synchronously write only bits [15-8] of dinb when WRITE_DATA_WIDTH_B
                                       // is 32, web would be 4'b0010.

   );

   xpm_memory_tdpram #(
      .ADDR_WIDTH_A(TLB_L2_ABITS),               // DECIMAL
      .ADDR_WIDTH_B(TLB_L2_ABITS),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A($bits(tlb_entry_t)),        // DECIMAL
      .BYTE_WRITE_WIDTH_B($bits(tlb_entry_t)),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("auto"),      // String
      .MEMORY_SIZE(TLB_L2_ENTRIES*$bits(tlb_entry_t)),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_A($bits(tlb_entry_t)),         // DECIMAL
      .READ_DATA_WIDTH_B($bits(tlb_entry_t)),         // DECIMAL
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
      .WRITE_DATA_WIDTH_A($bits(tlb_entry_t)),        // DECIMAL
      .WRITE_DATA_WIDTH_B($bits(tlb_entry_t)),        // DECIMAL
      .WRITE_MODE_A("read_first"),     // String
      .WRITE_MODE_B("read_first"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   xpm_memory_tdpram_inst32 (
      .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .douta(entry_oc),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(t0cL2),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port A.

      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(entryno),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .addrb(L1_miss_adr[`VADR_L2_MBITS]),                   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
      .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(entryi),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .dinb(t0cwL2),                     // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
      .ena(wayi==2'd2 && entryi.pte.l2.lvl==3'd2), 	// 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when read or write operations are initiated. Pipelined
                                       // internally.

      .enb(1'b1),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
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

      .regcea(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rsta(rst),                     // 1-bit input: Reset signal for the final port A output register stage.
                                       // Synchronously resets output port douta to the value specified by
                                       // parameter READ_RESET_VALUE_A.

      .rstb(rst),                     // 1-bit input: Reset signal for the final port B output register stage.
                                       // Synchronously resets output port doutb to the value specified by
                                       // parameter READ_RESET_VALUE_B.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(wri),                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

      .web(web0cL2)                        // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector
                                       // for port B input data port dinb. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dinb to address addrb. For example, to
                                       // synchronously write only bits [15-8] of dinb when WRITE_DATA_WIDTH_B
                                       // is 32, web would be 4'b0010.

   );

end
end
endgenerate

reg miss0, miss1, miss2;
reg inq;

always_comb
begin
	inq = 1'b0;
	for (n = 0; n < MISSQ_ENTRIES; n = n + 1)
		if (miss_adr==missadr[n] && miss_asid==missasid[n])
			inq = 1'b1;
end

wire cd_miss_adr;
reg miss_en_miss_adr;
reg tlb_v0a, tlb_v0b;
reg tlb_v1a, tlb_v1b;
reg tlb_v2a, tlb_v2b;
reg [5:0] cdrstcnt;
always_ff @(posedge clk)
if (rst) cdrstcnt <= 6'd0;
else cdrstcnt <= cdrstcnt + 2'd1;
change_det #(.WID($bits(virtual_address_t)-LOG_PAGE_SIZE)) ucd1 (.rst(rst), .clk(clk), .ce(1'b1), .i(miss_adr[VMSB:BMSB]), .cd(cd_miss_adr));
always_ff @(posedge clk) miss_en_miss_adr <= cd_miss_adr|cdrstcnt[4:0]==5'h1f;

wire hit0aL2 =(t0aL2.vpn.vpn[`L2_VPN_BITS]==miss_adr_r[`L2_VADR_BITS] && t0aL2.vpn.asid==miss_asid && t0aL2.pte.l2.v && t0aL2.pte.l2.s && Qupls4_pkg::SUPPORT_TLBLVL2);
wire hit0a =	(t0a.vpn.vpn[`VPN_BITS]==miss_adr_r[`VADR_BITS] && t0a.vpn.asid==miss_asid && t0a.pte.l1.v);
wire hit0bL2 =(t0bL2.vpn.vpn[`L2_VPN_BITS]==miss_adr_r[`L2_VADR_BITS] && t0bL2.vpn.asid==miss_asid && t0bL2.pte.l2.v && t0bL2.pte.l2.s && Qupls4_pkg::SUPPORT_TLBLVL2);
wire hit0b = 	(t0b.vpn.vpn[`VPN_BITS]==miss_adr_r[`VADR_BITS] && t0b.vpn.asid==miss_asid && t0b.pte.l1.v);
wire hit0cL2=	(t0cL2.vpn.vpn[`L2_VPN_BITS]==miss_adr_r[`L2_VADR_BITS] && t0cL2.vpn.asid==miss_asid && t0cL2.pte.l2.v && t0cL2.pte.l2.s && Qupls4_pkg::SUPPORT_TLBLVL2);
wire hit0c = 	(t0c.vpn.vpn[`VPN_BITS]==miss_adr_r[`VADR_BITS] && t0c.vpn.asid==miss_asid && t0c.pte.l1.v);

always_comb web0a = hit0a & !cd_miss_adr;
always_comb web0b = hit0b & !cd_miss_adr;
always_comb web0c = hit0c & !cd_miss_adr;
always_comb web0aL2 = hit0aL2 & !cd_miss_adr;
always_comb web0bL2 = hit0bL2 & !cd_miss_adr;
always_comb web0cL2 = hit0cL2 & !cd_miss_adr;
reg L1hit0, L1hit1, L1hit2;
reg [2:0] ndx0, ndx1, ndx2;
reg [7:0] hits [0:2];

always_ff @(posedge clk)
	cd_pc1 <= cd_pc;

genvar g1;

generate begin : gL1tlb
	for (g1 = 0; g1 < 8; g1 = g1 + 1)
		always_comb
			begin
				hits[0][g1] = ((L1tlb[g1].vpn.vpn[`L1_VPN_BITS]==vadr0[`L1_VADR_BITS] && L1tlb[g1].pte.l1.lvl==3'd1) ||	// Level1 hit or
											 (L1tlb[g1].vpn.vpn[`L1_VPN_BITS_LVL2]==vadr0[`L1_VADR_BITS_LVL2] && L1tlb[g1].pte.l2.lvl==3'd2 && L1tlb[g1].pte.l2.s==1'd1 && Qupls4_pkg::SUPPORT_TLBLVL2)) &&	// Level2 shortcut hit
											L1tlb[g1].vpn.asid==asid0;
				hits[1][g1] = ((L1tlb[g1].vpn.vpn[`L1_VPN_BITS]==vadr1[`L1_VADR_BITS] && L1tlb[g1].pte.l1.lvl==3'd1) ||	// Level1 hit or
											 (L1tlb[g1].vpn.vpn[`L1_VPN_BITS_LVL2]==vadr1[`L1_VADR_BITS_LVL2] && L1tlb[g1].pte.l2.lvl==3'd2 && L1tlb[g1].pte.l2.s==1'd1 && Qupls4_pkg::SUPPORT_TLBLVL2)) &&	// Level2 shortcut hit
											L1tlb[g1].vpn.asid==asid1;
				hits[2][g1] = ((L1tlb[g1].vpn.vpn[`L1_VPN_BITS]==vadr2[`L1_VADR_BITS] && L1tlb[g1].pte.l1.lvl==3'd1) ||	// Level1 hit or
											 (L1tlb[g1].vpn.vpn[`L1_VPN_BITS_LVL2]==vadr2[`L1_VADR_BITS_LVL2] && L1tlb[g1].pte.l2.lvl==3'd2 && L1tlb[g1].pte.l2.s==1'd1 && Qupls4_pkg::SUPPORT_TLBLVL2)) &&	// Level2 shortcut hit
											L1tlb[g1].vpn.asid==asid2;
			end
end
endgenerate

function [2:0] fnHitNdx;
input [7:0] hiti;
begin
	casez(hiti)
	8'b1???????:	fnHitNdx = 3'd7;
	8'b01??????:	fnHitNdx = 3'd6;
	8'b001?????:	fnHitNdx = 3'd5;
	8'b0001????:	fnHitNdx = 3'd4;
	8'b00001???:	fnHitNdx = 3'd3;
	8'b000001??:	fnHitNdx = 3'd2;
	8'b0000001?:	fnHitNdx = 3'd1;
	8'b00000001:	fnHitNdx = 3'd0;
	default:	fnHitNdx = 3'd0;
	endcase
end
endfunction

always_comb
begin
	L1hit0 = |hits[0];
	L1hit1 = |hits[1];
	L1hit2 = |hits[2];
	ndx0 = fnHitNdx(hits[0]);
	ndx1 = fnHitNdx(hits[1]);
	ndx2 = fnHitNdx(hits[2]);
end

wire [8:0] vpnbits = t2a.vpn.vpn[`VPN_BITS];
wire [8:0] pc_bits = vadr2r[`VADR_BITS];

always_comb
	begin
		tlb_v2b = FALSE;
		if (hit2a|hit2aL2)
			tlb_v2b = 1'd1;
		else if (hit2b)
			tlb_v2b = 1'd1;
		else if (hit2c)
			tlb_v2b = 1'd1;
	end
	
always_comb
	begin
		tlb_v0b = FALSE;
		if (!stall_tlb0) begin
			if (hit0a|hit0aL2)
				tlb_v0b = agen0_v;
			else if (hit0b|hit0bL2)
				tlb_v0b = agen0_v;
			else if (hit0c|hit0cL2)
				tlb_v0b = agen0_v;
		end
	end

always_comb
//	if (NAGEN > 1 && !stall_tlb1) begin
	begin
		tlb_v1b = FALSE;
		if (!stall_tlb1) begin
			if (hit1a|hit1aL2)
				tlb_v1b = agen1_v;
			else if (hit1b|hit1bL2)
				tlb_v1b = agen1_v;
			else if (hit1c|hit1cL2)
				tlb_v1b = agen1_v;
		end
	end
		
//	padr0_v = (tlb_v0a & tlb_v0b) & !cd_vadr0 & miss_en_vadr0;
//always_comb
//	padr1_v = (tlb_v1a & tlb_v1b) & !cd_vadr1 & miss_en_vadr1;
//	padr1_v = L1hit1;

always_comb
begin
	miss0 = 'd0;
	miss1 = 'd0;
	miss2 = 'd0;
	if (hit0a|hit0aL2) begin
	end
	else if (hit0b|hit0bL2) begin
	end
	else if (hit0c|hit0cL2) begin
	end
	else
		miss0 = !inq && agen0_v && miss_en_vadr0;
	if (hit1a|hit1aL2) begin
	end
	else if (hit1b|hit1bL2) begin
	end
	else if (hit1c|hit1cL2) begin
	end
	else
		miss1 = !inq && agen1_v && miss_en_vadr1;
	if (hit2a|hit2aL2) begin
	end
	else if (hit2b|hit2bL2) begin
	end
	else if (hit2c|hit2cL2) begin
	end
	else
		miss2 = !inq && miss_en_vadr2;
end

// update access counts, count is saturating, and shifted right every so often.
task tCount;
input tlb_entry_t i;
output tlb_entry_t o;
input hit;
input store;
reg of;
begin
	o = i;
	o.pte.l1.a = 1'b1;
	if (hit & store)
		o.pte.l1.m = 1'b1;
end
endtask

always_comb
begin
tCount(t0a,t0aw,hit0a,store0r);
tCount(t0b,t0bw,hit0b,store0r);
tCount(t0c,t0cw,hit0c,store0r);
tCount(t1a,t1aw,hit1a,store1r);
tCount(t1b,t1bw,hit1b,store1r);
tCount(t1c,t1cw,hit1c,store1r);
tCount(t2a,t2aw,hit2a,1'b0);
tCount(t2b,t2bw,hit2b,1'b0);
tCount(t2c,t2cw,hit2c,1'b0);
end
generate begin : gTLBLVL2Count
if (Qupls4_pkg::SUPPORT_TLBLVL2) begin
always_comb
begin
tCount(t0aL2,t0awL2,hit0aL2,store0r);
tCount(t0bL2,t0bwL2,hit0bL2,store0r);
tCount(t0cL2,t0cwL2,hit0cL2,store0r);
tCount(t1aL2,t1awL2,hit1aL2,store1r);
tCount(t1bL2,t1bwL2,hit1bL2,store1r);
tCount(t1cL2,t1cwL2,hit1cL2,store1r);
tCount(t2aL2,t2awL2,hit2aL2,1'b0);
tCount(t2bL2,t2bwL2,hit2bL2,1'b0);
tCount(t2cL2,t2cwL2,hit2cL2,1'b0);
end
end
end
endgenerate

always_ff @(posedge clk)
if (rst) begin
	entry0 <= 'd0;
	tlb_v0a <= 'd0;
	tlb0_op <= 'd0;
	padr0 <= {$bits(physical_address_t){1'd0}};
	load0_o <= 'd0;
	store0_o <= 'd0;

	entry1 <= 'd0;
	tlb_v1a <= 'd0;
	tlb1_op <= 'd0;
	load1_o <= 'd0;
	store1_o <= 'd0;
	
	pc_padr <= RSTPC;
	pc_padr_v1 <= TRUE;
	pc_tlb_entry_o <= {$bits(tlb_entry_t){1'b0}};
	
	omd0a <= Qupls4_pkg::OM_SECURE;
	omd1a <= Qupls4_pkg::OM_SECURE;
	
	agen0_rndx_o <= 'd0;
	agen1_rndx_o <= 'd0;
	swt_o <= 1'b0;
	
	head <= 4'd0;
	tail <= 4'd0;
	for (m = 0; m < MISSQ_ENTRIES; m = m + 1) begin
		missqn[m] <= 2'd0;
		missadr[m] <= {$bits(address_t){1'b0}};
		missasid[m] <= {$bits(asid_t){1'b0}};
	end
	wway <= 3'd0;
	pswt_v <= 1'b0;
end
else begin
	wway <= wway + 3'd1;
	miss_o <= 1'b0;
	tlb_v0a <= 1'd0;
	tlb_v1a <= 1'd0;
	tlb_v2a <= 1'b0;
	entry0 <= L1tlb[ndx0];
	entry1 <= L1tlb[ndx1];
	entry2 <= L1tlb[ndx2];

	// Update L1 TLB
	if (!stall_tlb) begin
		if (hit0a & agen0_v)
			L1tlb[wway] <= t0a;
		else if (hit0b & agen0_v)
			L1tlb[wway] <= t0b;
		else if (hit0c & agen0_v)
			L1tlb[wway] <= t0c;
		else if (hit0aL2 & agen0_v && Qupls4_pkg::SUPPORT_TLBLVL2)
			L1tlb[wway] <= t0aL2;
		else if (hit0bL2 & agen0_v && Qupls4_pkg::SUPPORT_TLBLVL2)
			L1tlb[wway] <= t0bL2;
		else if (hit0cL2 & agen0_v && Qupls4_pkg::SUPPORT_TLBLVL2)
			L1tlb[wway] <= t0cL2;
	end

	// Delay a few cycles to prevent a false PC miss. It takes a couple of cycles
	// for the PC to reset.

	if (|rstcnt[10:6] && (head != (tail - 1) % MISSQ_ENTRIES))
		case (L2_miss_v & ~stall_tlb & ~inq)
		1'b0:	;
		1'b1:
			begin
				missqn[tail] <= 2'd0;
				missadr[tail] <= L2_miss_adr;
				missasid[tail] <= L2_miss_asid;
				tail <= (tail + 1) % MISSQ_ENTRIES;
			end
		endcase
	if (missack) begin
		head <= (head + 1) % MISSQ_ENTRIES;
	end
	if (head != tail && !missack) begin
		missqn_o <= missqn[head];
		missadr_o <= missadr[head];
		missasid_o <= missasid[head];
		missid_o <= missid[head];
		missswt_o <= missswt[head];
		miss_o <= 1'b1;
	end
end

tlb_adr utlbadr0
(
	.rst(rst),
	.clk(clk),
	.paging_en(paging_en),
	.stall(stall_tlb0),
	.L1tlb(L1tlb),
	.ndx(ndx0),
	.agen_v(agen0_v),
	.L1hit(L1hit0), 
	.asid(asid0),
	.vadr(vadr0),
	.padr(padr0),
	.padrv(padr0_v),
	.tlb_v(tlb_v0a),
	.op_i(op0),
	.op_o(tlb0_op),
	.load_i(load0_i),
	.load_o(load0_o),
	.store_i(store0_i),
	.store_o(store0_o),
	.omd_i(omd0),
	.omd_o(omd0a),
	.agen_rndx_i(agen0_rndx_i),
	.agen_rndx_o(agen0_rndx_o),
	,miss_asid(miss0_asid),
	.miss_adr(miss0_adr),
	.miss_v(miss0_v)
);

tlb_adr utlbadr1
(
	.rst(rst),
	.clk(clk),
	.paging_en(paging_en),
	.stall(stall_tlb1),
	.L1tlb(L1tlb),
	.ndx(ndx1),
	.agen_v(agen1_v),
	.L1hit(L1hit1), 
	.asid(asid1),
	.vadr(vadr1),
	.padr(padr1),
	.padrv(padr1_v),
	.tlb_v(tlb_v1a),
	.op_i(op1),
	.op_o(tlb1_op),
	.load_i(load1_i),
	.load_o(load1_o),
	.store_i(store1_i),
	.store_o(store1_o),
	.omd_i(omd1),
	.omd_o(omd1a),
	.agen_rndx_i(agen1_rndx_i),
	.agen_rndx_o(agen1_rndx_o),
	,miss_asid(miss1_asid),
	.miss_adr(miss1_adr),
	.miss_v(miss1_v)
);

tlb_adr utlbadr2
(
	.rst(rst),
	.clk(clk),
	.paging_en(paging_en),
	.stall(stall_tlb2),
	.L1tlb(L1tlb),
	.ndx(ndx2),
	.agen_v(agen2_v),
	.L1hit(L1hit2), 
	.asid(asid2),
	.vadr(vadr2),
	.padr(padr2),
	.padrv(padr2_v),
	.tlb_v(tlb_v1a),
	.op_i(op2),
	.op_o(tlb2_op),
	.load_i(load2_i),
	.load_o(load2_o),
	.store_i(store2_i),
	.store_o(store2_o),
	.omd_i(omd2),
	.omd_o(omd2a),
	.agen_rndx_i(agen2_rndx_i),
	.agen_rndx_o(agen2_rndx_o),
	,miss_asid(miss2_asid),
	.miss_adr(miss2_adr),
	.miss_v(miss2_v)
);

RoundRobinArbiter #(
  .NumRequests(3)
)
urr1
(
  .rst(rst),
  .clk(clk),
  .ce(1'b1),
  .hold(1'b1),
  .req({miss2_v,miss1_v,miss0_v} & {3{paging_en}}),
  .grant(grant),
  .grant_enc()
);

always_comb
begin
	if (grant[0]) begin
		L1_miss_adr = miss0_adr;
		L1_miss_asid = miss0_asid;
		L1_miss_v = miss0_v;
	end
	else if (grant[1]) begin
		L1_miss_adr = miss1_adr;
		L1_miss_asid = miss1_asid;
		L1_miss_v = miss1_v;
	end
	else if (grant[2]) begin
		L1_miss_adr = miss2_adr;
		L1_miss_asidd = miss2_asid;
		L1_miss_v = miss2_v;
	end
end


always_comb
begin
	entry0_o = entry0;
	entry1_o = entry1;
	entry2_o = entry2;
end

assign pc_padr_v = pc_padr_v1 && !cd_pc && !cd_pc1;
assign entry_o = way ? entry_ob : entry_oa;

always_ff @(posedge clk) entryno = rstcnt[10] ? entry_no : entryno_rst;
always_ff @(posedge clk) entryi = rstcnt[10] ? entry_i : entryi_rst;
always_ff @(posedge clk) wayi = rstcnt[10] ? way : 2'd0;
always_ff @(posedge clk) wri = rstcnt[10] ? wr : 1'b1;

// This little machine sets up sixty-four entries in the TLB to point to the
// system RAM/ROM area.

always_ff @(posedge clk)
if (rst) begin
	rstcnt <= 11'd960;	
	entryno_rst <= 10'd960;
	entryi_rst <= {$bits(tlb_entry_t){1'd0}};
	entryi_rst.pte.l1.rwx <= 3'd7;
	entryi_rst.vpn.vpn <= 48'h7FFC0;	// Bits 13 to 31/77 of address
	entryi_rst.pte.l1.v <= 1'b1;
	entryi_rst.pte.l1.lvl <= 5'd0;
	entryi_rst.pte.l1.ppn <= 44'h7FFC0;
end
else begin
	if (!rstcnt[10]) begin
		rstcnt <= rstcnt + 1;
		entryno_rst <= entryno_rst + 1;
		entryi_rst.pte.l1.ppn <= entryi_rst.pte.l1.ppn + 1;
		entryi_rst.vpn.vpn <= entryi_rst.vpn.vpn + 1;
	end
end

endmodule
