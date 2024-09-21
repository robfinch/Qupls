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
// 23.5k LUTs / 1700 FFs / 80 BRAMs
// 5100 LUTs / 650 FFs / 20 BRAMs	(6x write clock)
// ============================================================================

import QuplsPkg::*;

module Qupls_checkpoint_valid_ram4(rst, clk5x, ph4, clka, en, wr, wc, wa, awa, setall, i, clkb, rc, ra, o);
parameter BANKS=1;
parameter NPORT=8;
parameter NRDPORT=20;
parameter NPREGS=PREGS;
localparam ABIT=$clog2(NPREGS);
input rst;
input clk5x;
input ph4;
input clka;
input en;
input [NPORT-1:0] wr;
input checkpt_ndx_t [NPORT-1:0] wc;
input cpu_types_pkg::pregno_t [NPORT-1:0] wa;
input cpu_types_pkg::aregno_t [NPORT-1:0] awa;		// debugging
input setall;
input [NPORT-1:0] i;
input clkb;
input checkpt_ndx_t [NRDPORT-1:0] rc;
input cpu_types_pkg::pregno_t [NRDPORT-1:0] ra;
output reg [NRDPORT-1:0] o;


cpu_types_pkg::pregno_t [NPORT/4-1:0] wam;
reg [NPORT/4-1:0] wr1,wrm;
reg [NPORT/4-1:0] i1,im;
checkpt_ndx_t [NPORT/4-1:0] wc1,wcm;
wire [NPORT/4-1:0] cda;
reg [NPORT/4-1:0] cdar;
reg [NPORT/4-1:0] wea;
reg [ABIT-1:0] addra [0:NPORT/4-1];
reg [ABIT-1:0] addrb [0:NRDPORT-1][0:NPORT/4-1];
wire [NCHECK-1:0] douta [0:NRDPORT-1][0:NPORT/4-1];
wire [NCHECK-1:0] doutb [0:NRDPORT-1][0:NPORT/4-1];
reg [NCHECK-1:0] dina [0:NRDPORT-1][0:NPORT/4-1];
reg [$clog2(NPORT/4):0] lvt [0:PREGS-1];
reg [NCHECK-1:0] slice;
reg [2:0] wcnt;

always_ff @(posedge clk5x)
if (rst) begin
	wcnt <= 3'd0;
end
else begin
	if (ph4)
		wcnt <= 3'd0;
	else if (wcnt < 3'd4)
		wcnt <= wcnt + 2'd1;
end

genvar g,q,r;

integer n,m,p,jj,kk;
initial begin
	for (m = 0; m < PREGS; m = m + 1)
		lvt[m] = 3'd0;
end

always_ff @(posedge clk5x)
begin
	for (jj = 0; jj < NPORT/4; jj = jj + 1) begin
		addra[jj] = wa[wcnt*(NPORT/4)+jj];
		wcm[jj] = wc[wcnt*(NPORT/4)+jj];
		im[jj] = i[wcnt*(NPORT/4)+jj];
		wrm[jj] = wr[wcnt*(NPORT/4)+jj];
	end
end

always_comb
for (p = 0; p < NRDPORT; p = p + 1) begin
	for (kk = 0; kk < NPORT/4; kk = kk + 1) begin
		addrb[p][kk] = ra[p];
	end
end

always_ff @(posedge clk5x)
for (n = 0; n < NPORT/4; n = n + 1)
begin
	if (wrm[n])
		lvt[addra[n]] <= n;
end

generate begin : gChkptRAM
	
   // xpm_memory_tdpram: True Dual Port RAM
   // Xilinx Parameterized Macro, version 2022.2
for (g = 0; g < NPORT/4; g = g + 1) begin
	change_det #(.WID($bits(addra[g]))) ucd (.rst(rst), .clk(clk5x), .ce(1'b1), .i(addra[g]), .cd(cda[g]));
	always_ff @(posedge clka) cdar[g] <= cda[g];
	always_ff @(posedge clka) wc1[g] <= wcm[g];
	always_ff @(posedge clka) i1[g] <= im[g];
	always_ff @(posedge clka) wr1[g] <= wrm[g];
	always_comb wea[g] <= wr1[g] & cdar[g];
	always_comb
	if (addra[g]==10'd263) begin
		$display("write addra=%h 263=%d douta=%h dina=%h i1=%d wc1=%d", addra[g], i1[g], douta[g], dina[g], i1[g], wc1[g]);
	end

	for (r = 0; r < NRDPORT; r = r + 1) begin
		for (q = 0; q < NCHECK; q = q + 1) begin
			always_comb
				begin
					if (q==wc1[g])
						dina[r][g][q] <= i1[g];
					else
						dina[r][g][q] <= douta[r][g][q];
				end
		end
		always_ff @(posedge clkb)
		if (addrb[r][g]==10'd263) begin
			$display("port=%d, read addrb=%h 263, doutb=%h", r[4:0], addrb[r][g], doutb[r][g]);
		end
   xpm_memory_tdpram #(
      .ADDR_WIDTH_A(ABIT),           // DECIMAL
      .ADDR_WIDTH_B(ABIT),          // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A(16),        // DECIMAL
      .BYTE_WRITE_WIDTH_B(16),       // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("independent_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("Qupls_checkpoint_valid_ram_init.mem"),   // All ones   // String
      .MEMORY_INIT_PARAM(""), // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("auto"),      // String
      .MEMORY_SIZE(NPREGS*16),        // DECIMAL
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

      .douta(douta[r][g]),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(doutb[r][g]),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port A.

      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(addra[g]),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .addrb(addrb[r][g]),                   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
      .clka(clk5x),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clkb),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(dina[r][g]),                // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .dinb(64'd0),                     // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
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
			o[g] = 1'b1;
		else begin
//			slice = doutb[g[7:3]][lvt[g[2:0]]];
			o[g] = doutb[g][lvt[ra[g]]][rc[g]];
		end
	end
end
endgenerate

endmodule
