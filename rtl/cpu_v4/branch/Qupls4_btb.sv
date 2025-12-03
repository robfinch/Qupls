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
// ============================================================================

import Qupls4_pkg::*;

module Qupls4_btb(rst, clk, en, clk_en, nmi, nmi_addr, irq, irq_addr,
	rclk, micro_machine_active,
	igrp, length_byte, predicted_correctly_dec, new_address_dec,
	pc, pc0, pc1, pc2, pc3, pc4, next_pc, p_override, po_bno,
	takb0, takb1, takb2, takb3, do_bsr, bsr_tgt, pe_bsdone, do_ret, ret_pc,
	do_call,
	branchmiss, bs_done_oh, misspc,
	mip0v, mip1v, mip2v, mip3v,
	commit_pc0, commit_brtgt0, commit_takb0, commit_grp0,
	commit_pc1, commit_brtgt1, commit_takb1, commit_grp1,
	commit_pc2, commit_brtgt2, commit_takb2, commit_grp2,
	commit_pc3, commit_brtgt3, commit_takb3, commit_grp3,
	bno_bitmap, act_bno
	);
parameter DEP=1024;
input rst;
input clk;
input en;
input clk_en;										// enable group to advance
input nmi;											// non-maskable interrupt
input pc_address_t nmi_addr;
input irq;
input pc_address_t irq_addr;
input rclk;
input micro_machine_active;
output reg [2:0] igrp;
input [7:0] length_byte;
input cpu_types_pkg::pc_address_ex_t pc;
input cpu_types_pkg::pc_address_ex_t pc0;
input cpu_types_pkg::pc_address_ex_t pc1;
input cpu_types_pkg::pc_address_ex_t pc2;
input cpu_types_pkg::pc_address_ex_t pc3;
input cpu_types_pkg::pc_address_ex_t pc4;
output cpu_types_pkg::pc_address_ex_t next_pc;
input [3:0] p_override;
input [4:0] po_bno [0:3];
output reg takb0;
output reg takb1;
output reg takb2;
output reg takb3;
input predicted_correctly_dec;
input pc_address_t new_address_dec;
input mip0v;
input mip1v;
input mip2v;
input mip3v;
input pe_bsdone;
input do_bsr;
input do_ret;
input do_call;
input pc_address_t ret_pc;
input cpu_types_pkg::pc_address_ex_t bsr_tgt;
input branchmiss;
input bs_done_oh;
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
output reg [31:0] bno_bitmap;
output reg [4:0] act_bno;

typedef struct packed {
	logic takb;
	logic [2:0] grp;
	cpu_types_pkg::pc_address_t pc;
	cpu_types_pkg::pc_address_t tgt;
} btb_entry_t;

pc_address_t [31:0] ras;
reg [4:0] ras_sp;

pc_address_ex_t [31:0] pcs;
pc_address_ex_t [31:0] next_pcs;
reg [4:0] next_act_bno;
reg [4:0] next_alt_bno;
reg [63:0] next_bno_bitmap;
reg [4:0] alt_bno;
reg [4:0] prev_act_bno;
reg next_is_alt;
reg is_alt;
reg [9:0] addrb0;
reg [9:0] addra;
btb_entry_t doutb0;
btb_entry_t doutb1;
btb_entry_t doutb2;
btb_entry_t doutb3;
reg w0,w1,w2,w3;
btb_entry_t tmp0, tmp1, tmp2, tmp3;
integer nn,mm,jj;
genvar g;

wire [5:0] ffz0,ffz1;
ffz48 uffz0 (.i({16'hFFFF,bno_bitmap}), .o(ffz0));
ffz48 uffz1 (.i({16'hFFFF,bno_bitmap | (32'd1 << ffz0)}), .o(ffz1));

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
	
// Make BS_DONE sticky
reg bs_done1, bs_done;
always_ff @(posedge clk)
if (rst)
	bs_done1 <= FALSE;
else begin
	if (pe_bsdone)
		bs_done1 <= TRUE;
	else if (clk_en)
		bs_done1 <= FALSE;
end
always_comb
	bs_done = pe_bsdone|bs_done1;

always_comb
if (rst) begin
	next_bno_bitmap = 32'h3;
	next_act_bno = ffz0;
	next_alt_bno = ffz1;
	next_is_alt = 1'b0;
	for (nn = 0; nn < 32; nn = nn + 1) begin
		next_pcs[nn].bno_t = 6'd1;
		next_pcs[nn].bno_f = 6'd1;
		next_pcs[nn].pc = RSTPC;
	end
	takb0 = 1'b0;
	takb1 = 1'b0;
	takb2 = 1'b0;
	takb3 = 1'b0;
end
else begin
//	next_act_bno = is_alt ? prev_act_bno : act_bno;
	next_act_bno = 5'd1;//act_bno;
	next_alt_bno = alt_bno;
	next_bno_bitmap = bno_bitmap;
	next_bno_bitmap[0] = 1'b1;
	next_is_alt = 1'b0;
	takb0 = 1'b0;
	takb1 = 1'b0;
	takb2 = 1'b0;
	takb3 = 1'b0;
	for (nn = 0; nn < 32; nn = nn + 1)
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

	// On a branch miss the misspc will have the correct block so the
	// cache line can be fetched, but the group will not be valid yet.
	// The group is loaded at state 1 below.
	/*
	if (nmi) begin
		next_pcs[pc.bno_t] = nmi_addr;
	end
	else if (irq) begin
		next_pcs[pc.bno_t] = irq_addr;
	end
	else
	*/
	// Under construction: RAS
	if (do_ret) begin
		next_act_bno = act_bno;
		next_pcs[next_act_bno].pc = ras[ras_sp];
		next_pcs[next_act_bno].bno_t = act_bno;
		next_pcs[next_act_bno].bno_f = 6'd0;
	end
	else if (!predicted_correctly_dec) begin
		next_act_bno = act_bno;
		next_pcs[act_bno] = new_address_dec;
	end
	else if (do_bsr) begin
		next_pcs[bsr_tgt.bno_t] = bsr_tgt;
	end
	else if (branchmiss) begin//(bs_done_oh||bs_done) begin
		next_act_bno = misspc.bno_t;
		next_alt_bno = 6'd0;
		next_pcs[next_act_bno].pc = misspc;
		next_pcs[next_act_bno].bno_t = next_act_bno;
		next_pcs[next_act_bno].bno_f = 6'd0;
		// The branch resolved, so free up alternate PC stream
		next_bno_bitmap[misspc.bno_f] = 1'b0;
	end
	else if (en && pc0.pc==doutb0.pc && doutb0.takb) begin
		next_act_bno = pc0.bno_t;//ffz1;
		next_alt_bno = ffz0;
		next_pcs[next_act_bno].pc = doutb0.tgt;
		next_pcs[next_act_bno].bno_t = next_act_bno;
		next_pcs[next_act_bno].bno_f = ffz0;
		// Alocate two streams, one for true, one for false
		next_bno_bitmap[ffz0] = 1'b1;
		/*
		next_bno_bitmap[ffz0] = 1'b1;
		next_pcs[ffz0].pc = pc0.pc + 5'd8;
		next_pcs[ffz0].bno_t = ffz0;
		next_pcs[ffz0].bno_f = 6'd0;
		*/
		takb0 = 1'b1;
	end
	else if (en && pc1.pc==doutb1.pc && doutb1.takb) begin
		next_act_bno = pc1.bno_t;//ffz0;
		next_alt_bno = ffz0;
		next_pcs[next_act_bno].pc = doutb1.tgt;
		next_pcs[next_act_bno].bno_t = next_act_bno;
		next_pcs[next_act_bno].bno_f = ffz0;
		next_bno_bitmap[ffz0] = 1'b1;
		/*
		next_bno_bitmap[ffz0] = 1'b1;
		next_pcs[ffz0].pc = pc1.pc + 5'd8;
		next_pcs[ffz0].bno_t = ffz1;
		next_pcs[ffz0].bno_f = 6'd0;
		*/
		takb1 = 1'b1;
	end
	else if (en && pc2.pc==doutb2.pc && doutb2.takb) begin
		next_act_bno = pc2.bno_t;//ffz0;
		next_alt_bno = ffz0;
		next_pcs[next_act_bno].pc = doutb2.tgt;
		next_pcs[next_act_bno].bno_t = next_act_bno;
		next_pcs[next_act_bno].bno_f = ffz0;
		next_bno_bitmap[ffz0] = 1'b1;
		/*
		next_bno_bitmap[ffz0] = 1'b1;
		next_pcs[ffz0].pc = pc2.pc + 5'd8;
		next_pcs[ffz0].bno_t = ffz0;
		next_pcs[ffz0].bno_f = 6'd0;
		*/
		takb2 = 1'b1;
	end
	else if (en && pc3.pc==doutb3.pc && doutb3.takb) begin
		next_act_bno = pc3.bno_t;//ffz0;
		next_alt_bno = ffz0;
		next_pcs[next_act_bno].pc = doutb3.tgt;
		next_pcs[next_act_bno].bno_t = next_act_bno;
		next_pcs[next_act_bno].bno_f = ffz0;
		next_bno_bitmap[ffz0] = 1'b1;
		/*
		next_bno_bitmap[ffz0] = 1'b1;
		next_pcs[ffz0].pc = pc3.pc + 5'd8;
		next_pcs[ffz0].bno_t = ffz0;
		next_pcs[ffz0].bno_f = 6'd0;
		*/
		takb3 = 1'b1;
	end
	else begin
		begin
			/*
			if (pc0[5:0] >= block_header[21:16])
				next_pc = {pc[$bits(pc_address_t)-1:6]+2'd1,6'd0};
			else if (pc1[5:0] >= block_header[21:16])
				next_pc = {pc[$bits(pc_address_t)-1:6]+2'd1,6'd0};
			else if (pc2[5:0] >= block_header[21:16])
				next_pc = {pc[$bits(pc_address_t)-1:6]+2'd1,6'd0};
			else if (pc3[5:0] >= block_header[21:16])
				next_pc = {pc[$bits(pc_address_t)-1:6]+2'd1,6'd0};
			else if (pc4[5:0] >= block_header[21:16]|| pc4[7:6]!=pc[7:6])
				next_pc = {pc[$bits(pc_address_t)-1:6]+2'd1,6'd0};
			else
				next_pc = {pc[$bits(pc_address_t)-1:6],pc4[5:0]};
			*/
			if (micro_machine_active) begin
				next_pcs[next_act_bno] = pc;
			end
			else begin
				case(1'b1)
				mip0v:	begin next_pcs[next_act_bno] = pc; next_pcs[next_act_bno].pc = fnAddToIP(pc.pc,6'd6); end
				mip1v:	begin next_pcs[next_act_bno] = pc; next_pcs[next_act_bno].pc = fnAddToIP(pc.pc,6'd12); end
				mip2v:	begin next_pcs[next_act_bno] = pc; next_pcs[next_act_bno].pc = fnAddToIP(pc.pc,6'd18); end
				mip3v:	begin next_pcs[next_act_bno] = pc; next_pcs[next_act_bno].pc = fnAddToIP(pc.pc,6'd24); end
				default:	begin next_pcs[next_act_bno] = pc; next_pcs[next_act_bno].pc = fnAddToIP(pc.pc,6'd24); end	// four instructions
				endcase
			end
		end
		// If stuck on the same PC, fetch alternate path
		if (next_pcs[next_act_bno].pc==pc.pc) begin
//			next_is_alt = 1'b1;
//			next_act_bno = alt_bno;
		end
	end
end

generate begin : gPCs
	for (g = 0; g < 32; g = g + 1) begin
		always_ff @(posedge clk)
		if (rst) begin
			pcs[g].bno_t <= 6'd1;
			pcs[g].bno_f <= 6'd1;
			pcs[g].pc <= RSTPC;
		end
		else
			pcs[g] <= next_pcs[g];
	end
end
endgenerate

always_ff @(posedge clk)
if (rst) begin
	prev_act_bno <= 6'd1;
	act_bno <= 6'd1;
	alt_bno <= 6'd1;
end
else begin
	if (clk_en) begin
		prev_act_bno <= act_bno;
		act_bno <= next_act_bno;
		alt_bno <= next_alt_bno;
	end
end

always_ff @(posedge clk)
if (rst)
	ras_sp <= 5'd0;
else begin
	if (do_ret)
		ras_sp <= ras_sp + 2'd1;
	else if (do_call)
		ras_sp <= ras_sp - 2'd1;
end

always_ff @(posedge clk)
if (rst) begin
	for (jj = 0; jj < 32; jj = jj + 1)
		ras[jj] <= RSTPC;
end
else begin
	if (do_call)
		ras[ras_sp - 2'd1] <= ret_pc;
end

always_ff @(posedge clk)
if (rst) is_alt = 1'b0;
else begin
	if (clk_en)
		is_alt <= next_is_alt;
end
always_ff @(posedge clk)
if (rst)
	bno_bitmap <= 64'h3;
else begin
	if (clk_en)
		bno_bitmap <= next_bno_bitmap;
end

assign next_pc = next_pcs[next_act_bno];

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
