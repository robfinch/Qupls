// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
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
import const_pkg::*;
import QuplsPkg::*;

module Qupls_rename_fifo3 (rst, clk, wr, din, rd, dout, full, empty);
parameter WID=6;
parameter DEP=64;
input rst;
input clk;
input wr;
input [WID-1:0] din;
input rd;
output reg [WID-1:0] dout;
output reg full;
output reg empty;

reg [$clog2(DEP)-1:0] head, tail;

   // xpm_memory_dpdistram: Dual Port Distributed RAM
   // Xilinx Parameterized Macro, version 2022.2

   xpm_memory_dpdistram #(
      .ADDR_WIDTH_A($clog2(DEP)),               // DECIMAL
      .ADDR_WIDTH_B($clog2(DEP)),               // DECIMAL
      .BYTE_WRITE_WIDTH_A(WID),        // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .MEMORY_INIT_FILE("Qupls_rename_fifo_init.mem"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_SIZE(WID*DEP),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_A(WID),         // DECIMAL
      .READ_DATA_WIDTH_B(WID),         // DECIMAL
      .READ_LATENCY_A(2),             // DECIMAL
      .READ_LATENCY_B(0),             // DECIMAL
      .READ_RESET_VALUE_A("01"),       // String
      .READ_RESET_VALUE_B("01"),       // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WRITE_DATA_WIDTH_A(WID)         // DECIMAL
   )
   xpm_memory_dpdistram_inst (
      .douta(),   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(dout),   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .addra(tail),   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .addrb(head),   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
      .clka(clk),     // 1-bit input: Clock signal for port A. Also clocks port B when parameter CLOCKING_MODE
                       // is "common_clock".

      .clkb(clk),     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                       // "independent_clock". Unused when parameter CLOCKING_MODE is "common_clock".

      .dina(din),     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(wr & !full),// 1-bit input: Memory enable signal for port A. Must be high on clock cycles when read
                       // or write operations are initiated. Pipelined internally.

      .enb(rd & !empty),       // 1-bit input: Memory enable signal for port B. Must be high on clock cycles when read
                       // or write operations are initiated. Pipelined internally.

      .regcea(1'b1), // 1-bit input: Clock Enable for the last register stage on the output data path.
      .regceb(1'b1), // 1-bit input: Do not change from the provided value.
      .rsta(rst),     // 1-bit input: Reset signal for the final port A output register stage. Synchronously
                       // resets output port douta to the value specified by parameter READ_RESET_VALUE_A.

      .rstb(rst),     // 1-bit input: Reset signal for the final port B output register stage. Synchronously
                       // resets output port doutb to the value specified by parameter READ_RESET_VALUE_B.

      .wea(wr)        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector for port A input
                       // data port dina. 1 bit wide when word-wide writes are used. In byte-wide write
                       // configurations, each bit controls the writing one byte of dina to address addra. For
                       // example, to synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A is
                       // 32, wea would be 4'b0010.

   );

   // End of xpm_memory_dpdistram_inst instantiation
				
always_ff @(posedge clk)
if (rst) begin
	head <= {$clog2(DEP){1'b0}};
	tail <= DEP;
	full <= FALSE;
	empty <= FALSE;
end
else begin
	if (wr & !full) begin
		if (!rd)
			empty <= FALSE;
		tail <= tail + 1;
		if (!rd && tail==(head+DEP-1) % DEP)
			full <= TRUE;
	end		
	if (rd & !empty) begin
		if (!wr)
			full <= FALSE;
		head <= head + 1;
		if (!wr && head==(tail+DEP-1) % DEP)
			empty <= TRUE;
	end
end

endmodule
