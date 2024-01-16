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

module Qupls_checkpoint_valid_ram4(rst, clka, en, wr, wc, wa, awa, setall, i, clkb, rc, ra, o);
parameter BANKS=1;
parameter NPORT=8;
parameter NRDPORT=24;
localparam ABIT=$clog2(PREGS);
input rst;
input clka;
input en;
input [NPORT-1:0] wr;
input checkpt_ndx_t [NPORT-1:0] wc;
input pregno_t [NPORT-1:0] wa;
input aregno_t [NPORT-1:0] awa;		// debugging
input setall;
input [NPORT-1:0] i;
input clkb;
input checkpt_ndx_t [NRDPORT-1:0] rc;
input pregno_t [NRDPORT-1:0] ra;
output reg [NRDPORT-1:0] o;

reg [NPORT-1:0] wr1;
reg [NPORT-1:0] i1;
checkpt_ndx_t [NPORT-1:0] wc1;
wire [NPORT-1:0] cda;
reg [NPORT-1:0] cdar;
reg [NPORT-1:0] wea;
reg [ABIT-1:0] addra [0:NPORT-1];
reg [ABIT:0] addrb [0:NPORT-1][0:2];
wire [15:0] douta [0:NPORT-1];
wire [127:0] doutb [0:NPORT-1][0:2];
reg [15:0] dina [0:NPORT-1];
reg [2:0] lvt [0:PREGS-1];

genvar g,q,r;

integer n,m,p;
initial begin
	for (m = 0; m < PREGS; m = m + 1)
		lvt[m] = 3'd0;
end

always_comb
for (p = 0; p < NPORT; p = p + 1) begin
	addra[p] = wa[p];
	addrb[p][0] = ra[p];
	addrb[p][1] = ra[p+8];
	addrb[p][2] = ra[p+16];
end

always_ff @(posedge clka)
for (n = 0; n < NPORT; n = n + 1)
begin
	if (wr[n])
		lvt[wa[n]] <= n;
end

generate begin : gChkptRAM
	
   // xpm_memory_tdpram: True Dual Port RAM
   // Xilinx Parameterized Macro, version 2022.2
for (g = 0; g < NPORT; g = g + 1) begin
	change_det #(.WID($bits(addra[g]))) ucd (.rst(rst), .clk(clka), .ce(1'b1), .i(addra[g]), .cd(cda[g]));
	always_ff @(posedge clka) cdar[g] <= cda[g];
	always_ff @(posedge clka) wc1[g] <= wc[g];
	always_ff @(posedge clka) i1[g] <= i[g];
	always_ff @(posedge clka) wr1[g] <= wr[g];
	always_comb wea[g] <= wr1[g] & cdar[g];
	for (q = 0; q < 16; q = q + 1) begin
		always_comb
			begin
				dina[g][q] <= douta[g][q];
				dina[g][wc1[q]] <= i1[q];
			end
	end

	for (r = 0; r < 3; r = r + 1) begin
   xpm_memory_tdpram #(
      .ADDR_WIDTH_A(ABIT),           // DECIMAL
      .ADDR_WIDTH_B(ABIT),           // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A(16),        // DECIMAL
      .BYTE_WRITE_WIDTH_B(16),       // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("independent_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("Qupls_checkpoint_valid_ram_init.mem"),      // String
      .MEMORY_INIT_PARAM(""), // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("auto"),      // String
      .MEMORY_SIZE(PREGS*16),          // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_A(16),        // DECIMAL
      .READ_DATA_WIDTH_B(16),        // DECIMAL
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
      .WRITE_DATA_WIDTH_A(16),        // DECIMAL
      .WRITE_DATA_WIDTH_B(16),       // DECIMAL
      .WRITE_MODE_A("no_change"),     // String
      .WRITE_MODE_B("no_change"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   xpm_memory_tdpram_inst1 (
      .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .douta(douta[g]),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(doutb[g][r]),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port A.

      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(addra[g]),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .addrb(addrb[g][r]),                   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
      .clka(clka),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clkb),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(dina[g]),                  // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .dinb(16'd0),                     // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
      .ena(1'b1),                      // 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when read or write operations are initiated. Pipelined
                                       // internally.

      .enb(1'b1),                      // 1-bit input: Memory enable signal for port B. Must be high on clock
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

      .rsta(1'b0),                     // 1-bit input: Reset signal for the final port A output register stage.
                                       // Synchronously resets output port douta to the value specified by
                                       // parameter READ_RESET_VALUE_A.

      .rstb(1'b0),                     // 1-bit input: Reset signal for the final port B output register stage.
                                       // Synchronously resets output port doutb to the value specified by
                                       // parameter READ_RESET_VALUE_B.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(wea[g]),                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

      .web(1'b0)                        // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector
                                       // for port B input data port dinb. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dinb to address addrb. For example, to
                                       // synchronously write only bits [15-8] of dinb when WRITE_DATA_WIDTH_B
                                       // is 32, web would be 4'b0010.

   );
   // End of xpm_memory_tdpram_inst instantiation
	end	
end
end
endgenerate
			
generate begin : gMem
	for (g = 0; g < NRDPORT; g = g + 1) begin
		always_comb
		if (rst)
			o[g] <= 1'b1;
		else begin
			if (g < 8)
				o[g] <= doutb[lvt[g]][0][rc[g]];
			else if (g < 16)
				o[g] <= doutb[lvt[g]][1][rc[g]];
			else
				o[g] <= doutb[lvt[g]][2][rc[g]];
		end
	end
end
endgenerate

endmodule
