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
// 1300 LUTs / 128 FFs / 1 block RAM
// ============================================================================

import QuplsPkg::*;

module Qupls_checkpoint_valid_ram2(rst, clka, wr, wc, wa, setall, i, clkb, rc, ra, o);
parameter BANKS=1;
parameter NPORT=8;
parameter NRDPORT=16;
input rst;
input clka;
input [NPORT-1:0] wr;
input checkpt_ndx_t wc [0:NPORT-1];
input pregno_t [NPORT-1:0] wa;
input [NPORT-1:0] setall;
input [NPORT-1:0] i;
input clkb;
input checkpt_ndx_t rc [0:NRDPORT-1];
input pregno_t [NRDPORT-1:0] ra;
output reg [NRDPORT-1:0] o;

typedef struct packed
{
	logic [2:0] num;
} portno_t;

typedef struct packed
{
	logic [NCHECK-1:0] cp;
} checkpt_bitmask_t;

(* ram_style="distributed" *)
portno_t [NCHECK*PREGS-1:0] lvt;
checkpt_bitmask_t [NRDPORT-1:0] o1;
checkpt_bitmask_t [NPORT-1:0] ix;

integer n,m;
always_ff @(posedge clka)
if (rst) begin
/*
	if (SIM)
		for (n = 0; n < NCHECK*PREGS; n = n + 1)
			lvt[n] <= 3'd0
*/
	;
end
else begin
	for (n = 0; n < NPORT; n = n + 1)
		if (wr[n]) lvt[{wc[n],wa[n]}] <= n;
end

always_comb
for (m = 0; m < NPORT; m = m + 1)
	if (setall[m])
		ix[m] <= 16'hFFFF;
	else begin
		ix[m] <= o1[m];
		ix[m].cp[wc[m]] <= i[m];
	end


genvar g;
generate begin : gMem
	for (g = 0; g < NPORT; g = g + 1) begin

   // xpm_memory_sdpram: Simple Dual Port RAM
   // Xilinx Parameterized Macro, version 2022.2

   xpm_memory_sdpram #(
      .ADDR_WIDTH_A(8),               // DECIMAL
      .ADDR_WIDTH_B(8),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A($bits(checkpt_bitmask_t)),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("independent_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("FFFF"),     // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("auto"),      // String
      .MEMORY_SIZE(4096),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_B($bits(checkpt_bitmask_t)),         // DECIMAL
      .READ_LATENCY_B(1),             // DECIMAL
      .READ_RESET_VALUE_B("FFFF"),    // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WAKEUP_TIME("disable_sleep"),  // String
      .WRITE_DATA_WIDTH_A($bits(checkpt_bitmask_t)),        // DECIMAL
      .WRITE_MODE_B("no_change"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   xpm_memory_sdpram_instA (
      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port B.

      .doutb(o1[g]),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(wa[g]),                   // ADDR_WIDTH_A-bit input: Address for port A write operations.
      .addrb(ra[g]),                   // ADDR_WIDTH_B-bit input: Address for port B read operations.
      .clka(clka),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clkb),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(ix[g]),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
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

      .rstb(rst),                     // 1-bit input: Reset signal for the final port B output register stage.
                                       // Synchronously resets output port doutb to the value specified by
                                       // parameter READ_RESET_VALUE_B.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(wr[g])                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

   );

   // End of xpm_memory_sdpram_inst instantiation
				
   xpm_memory_sdpram #(
      .ADDR_WIDTH_A(8),               // DECIMAL
      .ADDR_WIDTH_B(8),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A($bits(checkpt_bitmask_t)),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("independent_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("FFFF"),     // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("auto"),      // String
      .MEMORY_SIZE(4096),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_B($bits(checkpt_bitmask_t)),         // DECIMAL
      .READ_LATENCY_B(1),             // DECIMAL
      .READ_RESET_VALUE_B("FFFF"),    // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WAKEUP_TIME("disable_sleep"),  // String
      .WRITE_DATA_WIDTH_A($bits(checkpt_bitmask_t)),        // DECIMAL
      .WRITE_MODE_B("no_change"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   xpm_memory_sdpram_instB (
      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port B.

      .doutb(o1[g+NRDPORT/2]),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(wa[g]),                   // ADDR_WIDTH_A-bit input: Address for port A write operations.
      .addrb(ra[g+NRDPORT/2]),                   // ADDR_WIDTH_B-bit input: Address for port B read operations.
      .clka(clka),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clkb),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(ix[g]),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
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

      .rstb(rst),                     // 1-bit input: Reset signal for the final port B output register stage.
                                       // Synchronously resets output port doutb to the value specified by
                                       // parameter READ_RESET_VALUE_B.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(wr[g])                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

   );

   // End of xpm_memory_sdpram_inst instantiation
				
		always_comb
		begin
			o[g] <= o1[lvt[{rc[g],ra[g]}]].cp[g];
			o[g+NRDPORT/2] <= o1[lvt[{rc[g+NRDPORT/2],ra[g+NRDPORT/2]}]+NRDPORT/2].cp[g+NRDPORT/2];
		end
	end
end
endgenerate

endmodule
