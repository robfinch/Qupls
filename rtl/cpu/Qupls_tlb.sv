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
// ============================================================================

import QuplsMmupkg::*;

module Qupls_tlb(clk, wr, way, entry_no, entry_i, entry_o, vadr0, vadr1,
	asid0, asid1, entry0, entry1, miss_o, missadr_o, missasid_o, missack);
parameter TLB_ENTRIES = 128;
input clk;
input wr;
input way;
input [6:0] entry_no;
input tlb_entry_t entry_i;
output tlb_entry_t entry_o;
input address_t vadr0;
input address_t vadr1;
input asid_t asid0;
input asid_t asid1;
output tlb_entry_t entry0;
output tlb_entry_t entry1;
output reg miss_o;
output address_t missadr_o;
output asid_t missasid_o;
input missack;

tlb_entry_t t0a, t0b, t1a, t1b;
reg [3:0] head, tail;
address_t [15:0] missadr;
asid_t [15:0] missasid;

integer n;


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

reg miss0, miss1;

always_comb
begin
	miss0 = 'd0;
	miss1 = 'd0;
	if (t0a.vpn.vpn[15:0]==vadr0[31:16] && t0a.vpn.asid==asid0) begin
	end
	else if (t0b.vpn.vpn[15:0]==vadr0[31:16] && t0b.vpn.asid==asid0) begin
	end
	else
		miss0 = 1'b1;
	if (t1a.vpn.vpn[15:0]==vadr1[31:16] && t1a.vpn.asid==asid1) begin
	end
	else if (t1b.vpn.vpn[15:0]==vadr1[31:16] && t1b.vpn.asid==asid1) begin
	end
	else
		miss1 = 1'b1;
end

always_ff @(posedge clk)
begin
	miss_o <= 1'b0;
	entry0 <= 'd0;
	entry1 <= 'd0;
	if (t0a.vpn.vpn[15:0]==vadr0[31:16] && t0a.vpn.asid==asid0) begin
		entry0 <= t0a;
	end
	else if (t0b.vpn.vpn[15:0]==vadr0[31:16] && t0b.vpn.asid==asid0) begin
		entry0 <= t0b;
	end
	if (t1a.vpn.vpn[15:0]==vadr1[31:16] && t1a.vpn.asid==asid1) begin
		entry1 <= t1a;
	end
	else if (t1b.vpn.vpn[15:0]==vadr1[31:16] && t1b.vpn.asid==asid1) begin
		entry1 <= t1b;
	end
	if ((head != (tail - 1) % 16) && (head != (tail - 2) % 16))
		case ({miss1,miss0})
		2'b00:	;
		2'b01:
			begin
				missadr[tail] <= vadr0;
				missasid[tail] <= asid0;
				tail <= tail + 1;
			end
		2'b10:
			begin
				missadr[tail] <= vadr1;
				missasid[tail] <= asid1;
				tail <= tail + 1;
			end
		2'b11:
			begin
				missadr[tail] <= vadr0;
				missasid[tail] <= asid0;
				missadr[tail+1] <= vadr1;
				missasid[tail+1] <= asid1;
				tail <= tail + 2;
			end
		endcase
	if (missack) begin
		head <= head + 1;
	end
	if (head != tail) begin
		missadr_o <= missadr[head];
		missasid_o <= missasid[head];
		miss_o <= 1'b1;
	end
end

assign entry_o = way ? entry_ob : entry_oa;

endmodule
