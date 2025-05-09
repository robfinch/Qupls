`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2025  Robert Finch, Waterloo
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

import const_pkg::*;
//import Stark_pkg::SIM;

module Stark_checkpointRam(rst, clka, ena, wea, addra, dina, douta, 
	clkb, enb, addrb, doutb);
parameter NRDPORTS = 4; 
localparam RBIT=$clog2(Stark_pkg::PREGS);
localparam QBIT=$bits(cpu_types_pkg::pregno_t);
localparam WID=$bits(Stark_pkg::checkpoint_t);
localparam AWID=$clog2(Stark_pkg::NCHECK);
input rst;
input clka;
input ena;
input wea;
input checkpt_ndx_t addra;
input Stark_pkg::checkpoint_t dina;
output Stark_pkg::checkpoint_t douta;
input clkb;
input enb;
input checkpt_ndx_t addrb;
output Stark_pkg::checkpoint_t doutb;

Stark_pkg::checkpoint_t doutb1;
Stark_pkg::checkpoint_t douta1;
genvar g;
integer n;
// The following outside of generate to make it easier to reference in SIM code.
// It should be stripped out for synthesis as it would not be referenced.
(* RAM_STYLE="distributed" *)
Stark_pkg::checkpoint_t mem [0:Stark_pkg::NCHECK-1];
reg ena1;
reg wea1;
Stark_pkg::checkpoint_t dina1;
reg [3:0] addra1;

initial begin
	for (n = 0; n < Stark_pkg::NCHECK; n = n + 1) begin
		mem[n] = {$bits(Stark_pkg::checkpoint_t){1'b0}};
		mem[n].avail = {Stark_pkg::PREGS{1'b1}};
		mem[n].avail[0] = 1'b0;
	end
end

// Delay the write by a clock cycle to give a chance to read current map values
// before they get updated.
always_ff @(posedge clka) ena1 <= ena;
always_ff @(posedge clka) wea1 <= wea;
always_ff @(posedge clka) addra1 <= addra;
always_ff @(posedge clka) dina1 <= dina;

generate begin : gRegfileRam
if (Stark_pkg::SIM) begin

//	for (g = 0; g < AREGS; g = g + 1)
		always_ff @(posedge clka)
			if (ena & wea) mem[addra] <= dina;
//			if (ena & wea[g]) mem[addra][g*QBIT+QBIT-1:g*QBIT] <= dina[g*QBIT+QBIT-1:g*QBIT];

//	assign doutb = (ena & wea) ? dina : mem[addrb];
		always_comb//ff @(posedge clka)
//			if (enb)
				doutb1 <= mem[addrb];
	assign douta1 = mem[addra];

end
else begin


// XPM_MEMORY instantiation template for Dual Port Distributed RAM configurations
// Refer to the targeted device family architecture libraries guide for XPM_MEMORY documentation
// =======================================================================================================================


// xpm_memory_dpdistram : In order to incorporate this function into the design,
//       Verilog        : the following instance declaration needs to be placed
//       instance       : in the body of the design code.  The instance name
//     declaration      : (xpm_memory_dpdistram_inst) and/or the port declarations within the
//         code         : parenthesis may be changed to properly reference and
//                      : connect this function to the design.  All inputs
//                      : and outputs must be connected.

//  Please reference the appropriate libraries guide for additional information on the XPM modules.

//  <-----Cut code below this line---->

   // xpm_memory_dpdistram: Dual Port Distributed RAM
   // Xilinx Parameterized Macro, version 2022.2

   xpm_memory_dpdistram #(
      .ADDR_WIDTH_A(AWID),            // DECIMAL
      .ADDR_WIDTH_B(AWID),            // DECIMAL
      .BYTE_WRITE_WIDTH_A(WID),      		// DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_SIZE(WID*Stark_pkg::NCHECK),       // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_A(WID),        // DECIMAL
      .READ_DATA_WIDTH_B(WID),        // DECIMAL
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
      .WRITE_DATA_WIDTH_A(WID)        // DECIMAL
   )
   xpm_memory_dpdistram_inst (
      .douta(douta1), 	// READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(doutb1),   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .addra(addra),   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .addrb(addrb),   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
      .clka(clka),     // 1-bit input: Clock signal for port A. Also clocks port B when parameter CLOCKING_MODE
                       // is "common_clock".

      .clkb(clkb),     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                       // "independent_clock". Unused when parameter CLOCKING_MODE is "common_clock".

      .dina(dina),     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(ena),       // 1-bit input: Memory enable signal for port A. Must be high on clock cycles when read
                       // or write operations are initiated. Pipelined internally.

      .enb(enb),       // 1-bit input: Memory enable signal for port B. Must be high on clock cycles when read
                       // or write operations are initiated. Pipelined internally.

      .regcea(ena), // 1-bit input: Clock Enable for the last register stage on the output data path.
      .regceb(enb), // 1-bit input: Do not change from the provided value.
      .rsta(rst),     // 1-bit input: Reset signal for the final port A output register stage. Synchronously
                       // resets output port douta to the value specified by parameter READ_RESET_VALUE_A.

      .rstb(rst),     // 1-bit input: Reset signal for the final port B output register stage. Synchronously
                       // resets output port doutb to the value specified by parameter READ_RESET_VALUE_B.

      .wea(wea)       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector for port A input
                       // data port dina. 1 bit wide when word-wide writes are used. In byte-wide write
                       // configurations, each bit controls the writing one byte of dina to address addra. For
                       // example, to synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A is
                       // 32, wea would be 4'b0010.

   );

   // End of xpm_memory_dpdistram_inst instantiation

//	assign doutb = (ena & wea) ? dina : doutb1;

/*
// XPM_MEMORY instantiation template for Simple Dual Port RAM configurations
// Refer to the targeted device family architecture libraries guide for XPM_MEMORY documentation
// =======================================================================================================================


   // xpm_memory_sdpram: Simple Dual Port RAM
   // Xilinx Parameterized Macro, version 2022.2

   xpm_memory_sdpram #(
      .ADDR_WIDTH_A(6),               // DECIMAL
      .ADDR_WIDTH_B(6),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A(RBIT),      // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("auto"),      // String
      .MEMORY_SIZE(64*WID),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_B(WID),         // DECIMAL
      .READ_LATENCY_B(1),             // DECIMAL
      .READ_RESET_VALUE_B("0"),       // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WAKEUP_TIME("disable_sleep"),  // String
      .WRITE_DATA_WIDTH_A(WID),        // DECIMAL
      .WRITE_MODE_B("no_change"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   xpm_memory_sdpram_inst (
      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port B.

      .doutb(doutb),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(addra),                   // ADDR_WIDTH_A-bit input: Address for port A write operations.
      .addrb(addrb),                   // ADDR_WIDTH_B-bit input: Address for port B read operations.
      .clka(clka),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clkb),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(dina),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(ena),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when write operations are initiated. Pipelined internally.

      .enb(enb),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
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

      .sleep(sleep),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(wea)                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

   );

   // End of xpm_memory_sdpram_inst instantiation
*/				
						
end
end
endgenerate

always_comb
	douta = douta1;
//	douta = ena && wea && addra==addrb ? dina : douta1;
always_comb
	doutb = doutb1;
								
endmodule

