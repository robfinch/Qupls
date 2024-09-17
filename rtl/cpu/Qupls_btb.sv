// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2024  Robert Finch, Waterloo
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
// ============================================================================

import QuplsPkg::*;

module Qupls_btb(rst, clk, en, clk_en, rclk, micro_code_active, block_header,
	igrp, length_byte,
	pc, pc0, pc1, pc2, pc3, pc4, next_pc, alt_pc, alt_next_pc,
	takb, do_bsr, bsr_tgt, pe_bsdone,
	branchmiss, branch_state, misspc,
	mip0v, mip1v, mip2v, mip3v,
	commit_pc0, commit_brtgt0, commit_takb0, commit_grp0,
	commit_pc1, commit_brtgt1, commit_takb1, commit_grp1,
	commit_pc2, commit_brtgt2, commit_takb2, commit_grp2,
	commit_pc3, commit_brtgt3, commit_takb3, commit_grp3
	);
parameter DEP=1024;
input rst;
input clk;
input en;
input clk_en;										// enable group to advance
input rclk;
input ibh_t block_header;
input micro_code_active;
output reg [2:0] igrp;
input [7:0] length_byte;
input cpu_types_pkg::pc_address_t pc;
input cpu_types_pkg::pc_address_t pc0;
input cpu_types_pkg::pc_address_t pc1;
input cpu_types_pkg::pc_address_t pc2;
input cpu_types_pkg::pc_address_t pc3;
input cpu_types_pkg::pc_address_t pc4;
output cpu_types_pkg::pc_address_t next_pc;
input cpu_types_pkg::pc_address_t alt_pc;
output cpu_types_pkg::pc_address_t alt_next_pc;
output reg takb;
input mip0v;
input mip1v;
input mip2v;
input mip3v;
input pe_bsdone;
input do_bsr;
input cpu_types_pkg::pc_address_t bsr_tgt;
input branchmiss;
input branch_state_t branch_state;
input cpu_types_pkg::pc_address_t misspc;
input cpu_types_pkg::pc_address_t commit_pc0;
input cpu_types_pkg::pc_address_t commit_brtgt0;
input commit_takb0;
input [2:0] commit_grp0;
input cpu_types_pkg::pc_address_t commit_pc1;
input cpu_types_pkg::pc_address_t commit_brtgt1;
input commit_takb1;
input [2:0] commit_grp1;
input cpu_types_pkg::pc_address_t commit_pc2;
input cpu_types_pkg::pc_address_t commit_brtgt2;
input commit_takb2;
input [2:0] commit_grp2;
input cpu_types_pkg::pc_address_t commit_pc3;
input cpu_types_pkg::pc_address_t commit_brtgt3;
input commit_takb3;
input [2:0] commit_grp3;

typedef struct packed {
	logic takb;
	logic [2:0] grp;
	cpu_types_pkg::pc_address_t pc;
	cpu_types_pkg::pc_address_t tgt;
} btb_entry_t;


reg [9:0] addrb0;
reg [9:0] addra;
btb_entry_t doutb0;
btb_entry_t doutb1;
btb_entry_t doutb2;
btb_entry_t doutb3;
reg w;
btb_entry_t tmp0, tmp1, tmp2, tmp3;

   // xpm_memory_sdpram: Simple Dual Port RAM
   // Xilinx Parameterized Macro, version 2022.2

   xpm_memory_sdpram #(
      .ADDR_WIDTH_A($clog2(DEP)),               // DECIMAL
      .ADDR_WIDTH_B($clog2(DEP)),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A($bits(btb_entry_t)),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("independent_clock"), // String
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
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
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
      .wea(w)                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
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
      .CLOCKING_MODE("independent_clock"), // String
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
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
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
      .wea(w)                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
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
      .CLOCKING_MODE("independent_clock"), // String
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
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
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
      .wea(w)                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
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
      .CLOCKING_MODE("independent_clock"), // String
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
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
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
      .wea(w)                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

   );

always_ff @(posedge clk)
	addrb0 <= pc0[21:12];

always_comb
begin
	// On a branch miss the misspc will have the correct block so the
	// cache line can be fetched, but the group will not be valid yet.
	// The group is loaded at state 1 below.
	if (branch_state==BS_DONE) begin
		next_pc <= misspc;
		alt_next_pc <= misspc;
		takb <= 1'b1;
	end
	else if (do_bsr) begin
		next_pc <= bsr_tgt;
		alt_next_pc <= bsr_tgt;
		takb <= 1'b1;
	end
	else if (en && pc0==doutb0.pc && doutb0.takb) begin
		next_pc <= doutb0.tgt;
		alt_next_pc <= pc0 + 5'd6;
		takb <= 1'b1;
	end
	else if (en && pc1==doutb1.pc && doutb1.takb) begin
		next_pc <= doutb1.tgt;
		alt_next_pc <= pc1 + 5'd6;
		takb <= 1'b1;
	end
	else if (en && pc2==doutb2.pc && doutb2.takb) begin
		next_pc <= doutb2.tgt;
		alt_next_pc <= pc2 + 5'd6;
		takb <= 1'b1;
	end
	else if (en && pc3==doutb3.pc && doutb3.takb) begin
		next_pc <= doutb3.tgt;
		alt_next_pc <= pc3 + 5'd6;
		takb <= 1'b1;
	end
	else begin
		if (SUPPORT_IBH) begin
			// Advance to the next group? We know the address of the start of the
			// group, it is always the same, offset 0.
			if (igrp >= 3'd3/* || block_header.offs[igrp]=='d0*/)
				next_pc <= {pc[$bits(pc_address_t)-1:6]+2'd1,6'd0};
			else
				next_pc <= {pc[$bits(pc_address_t)-1:6],block_header[21:16]};
		end
		else if (SUPPORT_VLI) begin
			if (SUPPORT_VLIB)
				next_pc <= pc + length_byte;
			else begin
				if (pc0[5:0] >= block_header[21:16])
					next_pc <= {pc[$bits(pc_address_t)-1:6]+2'd1,6'd0};
				else if (pc1[5:0] >= block_header[21:16])
					next_pc <= {pc[$bits(pc_address_t)-1:6]+2'd1,6'd0};
				else if (pc2[5:0] >= block_header[21:16])
					next_pc <= {pc[$bits(pc_address_t)-1:6]+2'd1,6'd0};
				else if (pc3[5:0] >= block_header[21:16])
					next_pc <= {pc[$bits(pc_address_t)-1:6]+2'd1,6'd0};
				else if (pc4[5:0] >= block_header[21:16]|| pc4[7:6]!=pc[7:6])
					next_pc <= {pc[$bits(pc_address_t)-1:6]+2'd1,6'd0};
				else
					next_pc <= {pc[$bits(pc_address_t)-1:6],pc4[5:0]};
			end
		end
		else begin
			/*
			if (pc0[5:0] >= block_header[21:16])
				next_pc <= {pc[$bits(pc_address_t)-1:6]+2'd1,6'd0};
			else if (pc1[5:0] >= block_header[21:16])
				next_pc <= {pc[$bits(pc_address_t)-1:6]+2'd1,6'd0};
			else if (pc2[5:0] >= block_header[21:16])
				next_pc <= {pc[$bits(pc_address_t)-1:6]+2'd1,6'd0};
			else if (pc3[5:0] >= block_header[21:16])
				next_pc <= {pc[$bits(pc_address_t)-1:6]+2'd1,6'd0};
			else if (pc4[5:0] >= block_header[21:16]|| pc4[7:6]!=pc[7:6])
				next_pc <= {pc[$bits(pc_address_t)-1:6]+2'd1,6'd0};
			else
				next_pc <= {pc[$bits(pc_address_t)-1:6],pc4[5:0]};
			*/
			if (micro_code_active) begin
				next_pc <= pc;
				alt_next_pc <= pc;
			end
			else begin
				case(1'b1)
				mip0v:	begin next_pc <= pc + 5'd6; alt_next_pc <= pc + 5'd6; end
				mip1v:	begin next_pc <= pc + 5'd12; alt_next_pc <= pc + 5'd12; end
				mip2v:	begin next_pc <= pc + 5'd18; alt_next_pc <= pc + 5'd18; end
				mip3v:	begin next_pc <= pc + 5'd24; alt_next_pc <= pc + 5'd24; end
				default:	begin next_pc <= pc + 5'd24;	alt_next_pc <= alt_pc + 5'd24; end	// four instructions
				endcase
			end
		end
		takb <= 1'b0;
	end
end

generate begin : giGrp
if (SUPPORT_IBH) begin
	always_ff @(posedge clk)
	if (rst)
		igrp <= 3'd0;
	else begin
		if (clk_en) begin
			/*
			// Instruction block header should be valid again at this state.
			if (branchmiss_state==3'd4) begin
				if (pc[5:0] >= ibh[21:16])
					igrp <= 3'd4;
				else if (pc[5:0] >= ibh.offs[2])
					igrp <= 3'd3;
				else if (pc[5:0] >= ibh.offs[1])
					igrp <= 3'd2;
				else if (pc[5:0] >= ibh.offs[0])
					igrp <= 3'd1;
				else
					igrp <= 3'd0;
			end
			else if (pc0==doutb0.pc && doutb0.takb)
				igrp <= doutb0.grp;
			else if (pc1==doutb1.pc && doutb1.takb)
				igrp <= doutb1.grp;
			else if (pc2==doutb2.pc && doutb2.takb)
				igrp <= doutb2.grp;
			else if (pc3==doutb3.pc && doutb3.takb)
				igrp <= doutb3.grp;
			else begin
				igrp <= igrp + 2'd1;
				if (igrp>=3'd3 || block_header.offs[igrp]=='d0)
					igrp <= 'd0;
			end
			*/
		end
	end
end
end
endgenerate

always_ff @(posedge clk)
if (rst) begin
	w <= 1'd0;
	addra <= 10'd0;
	tmp0 <= 'd0;
	tmp1 <= 'd0;
	tmp2 <= 'd0;
	tmp3 <= 'd0;
end
else begin
	tmp0.pc <= commit_pc0;
	tmp0.takb <= commit_takb0;
	tmp0.tgt <= commit_brtgt0;
	tmp0.grp <= commit_grp0;
	tmp1.pc <= commit_pc1;
	tmp1.takb <= commit_takb1;
	tmp1.tgt <= commit_brtgt1;
	tmp1.grp <= commit_grp1;
	tmp2.pc <= commit_pc2;
	tmp2.takb <= commit_takb2;
	tmp2.tgt <= commit_brtgt2;
	tmp2.grp <= commit_grp2;
	tmp3.pc <= commit_pc3;
	tmp3.takb <= commit_takb3;
	tmp3.tgt <= commit_brtgt3;
	tmp3.grp <= commit_grp3;
	addra <= commit_pc0[21:12];
	w <= commit_takb0|commit_takb1|commit_takb2|commit_takb3;
end

endmodule
