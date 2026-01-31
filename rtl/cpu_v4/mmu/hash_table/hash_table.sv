`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2026  Robert Finch, Waterloo
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
// 1025 LUTs / 1225 FFs / 15 BRAMs / 230 MHz

import const_pkg::*;
import wishbone_pkg::*;
import hash_table_pkg::*;

module hash_table(rst,clk,cs,req,resp,vreq,vresp,asid,padr,padrv,
	page_fault,fault_adr,fault_asid,fault_group);
input rst;
input clk;
input cs;
input wb_cmd_request64_t req;
output wb_cmd_response64_t resp;
input wb_cmd_request64_t vreq;
output wb_cmd_response64_t vresp;
input [9:0] asid;
output reg [31:0] padr;
output reg padrv;
output reg page_fault;
output reg [31:0] fault_adr;
output reg [9:0] fault_asid;
output reg [17:0] fault_group;

integer n;
wire [1:0] state;
reg xlat;
reg found;
wire wea,ena;
wire web;
ptg_t dina, dinb;
ptg_t douta,doutb;
reg [3:0] fnd;
ptg_t hold;
ptg_t rec;
wire [9:0] page_group;
wire [9:0] hash;
wire [4:0] bounce;
reg [7:0] empty;

// xpm_memory_tdpram: True Dual Port RAM
// Xilinx Parameterized Macro, version 2025.1

xpm_memory_tdpram #(
  .ADDR_WIDTH_A(10),               // DECIMAL
  .ADDR_WIDTH_B(10),               // DECIMAL
  .AUTO_SLEEP_TIME(0),            // DECIMAL
  .BYTE_WRITE_WIDTH_A(512),        // DECIMAL
  .BYTE_WRITE_WIDTH_B(512),        // DECIMAL
  .CASCADE_HEIGHT(0),             // DECIMAL
  .CLOCKING_MODE("common_clock"), // String
  .ECC_BIT_RANGE("7:0"),          // String
  .ECC_MODE("no_ecc"),            // String
  .ECC_TYPE("none"),              // String
  .IGNORE_INIT_SYNTH(0),          // DECIMAL
  .MEMORY_INIT_FILE("none"),      // String
  .MEMORY_INIT_PARAM("0"),        // String
  .MEMORY_OPTIMIZATION("true"),   // String
  .MEMORY_PRIMITIVE("auto"),      // String
  .MEMORY_SIZE(512*1024),          // DECIMAL
  .MESSAGE_CONTROL(0),            // DECIMAL
  .RAM_DECOMP("auto"),            // String
  .READ_DATA_WIDTH_A(512),         // DECIMAL
  .READ_DATA_WIDTH_B(512),         // DECIMAL
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
  .WRITE_DATA_WIDTH_A(512),        // DECIMAL
  .WRITE_DATA_WIDTH_B(512),        // DECIMAL
  .WRITE_MODE_A("no_change"),     // String
  .WRITE_MODE_B("no_change"),     // String
  .WRITE_PROTECT(1)               // DECIMAL
)
xpm_memory_tdpram_inst (
  .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence on the data output of port A.
  .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence on the data output of port A.
  .douta(douta),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
  .doutb(doutb),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
  .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence on the data output of port A.
  .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence on the data output of port B.
  .addra(req.adr[15:6]),          // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
  .addrb(hash),                   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
  .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when parameter CLOCKING_MODE is "common_clock".
  .clkb(clk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is "independent_clock". Unused when
                                   // parameter CLOCKING_MODE is "common_clock".

  .dina(dina),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
  .dinb(dinb),                     // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
  .ena(ena),                     // 1-bit input: Memory enable signal for port A. Must be high on clock cycles when read or write operations
                                   // are initiated. Pipelined internally.

  .enb(1'b1),                       // 1-bit input: Memory enable signal for port B. Must be high on clock cycles when read or write operations
                                   // are initiated. Pipelined internally.

  .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when ECC enabled (Error injection capability
                                   // is not available in "decode_only" mode).

  .injectdbiterrb(1'b0), // 1-bit input: Controls double bit error injection on input data when ECC enabled (Error injection capability
                                   // is not available in "decode_only" mode).

  .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when ECC enabled (Error injection capability
                                   // is not available in "decode_only" mode).

  .injectsbiterrb(1'b0), // 1-bit input: Controls single bit error injection on input data when ECC enabled (Error injection capability
                                   // is not available in "decode_only" mode).

  .regcea(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output data path.
  .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output data path.
  .rsta(rst),                     // 1-bit input: Reset signal for the final port A output register stage. Synchronously resets output port
                                   // douta to the value specified by parameter READ_RESET_VALUE_A.

  .rstb(rst),                     // 1-bit input: Reset signal for the final port B output register stage. Synchronously resets output port
                                   // doutb to the value specified by parameter READ_RESET_VALUE_B.

  .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
  .wea(wea),                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector for port A input data port dina. 1 bit
                                   // wide when word-wide writes are used. In byte-wide write configurations, each bit controls the writing one
                                   // byte of dina to address addra. For example, to synchronously write only bits [15-8] of dina when
                                   // WRITE_DATA_WIDTH_A is 32, wea would be 4'b0010.

  .web(web)                        // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector for port B input data port dinb. 1 bit
                                   // wide when word-wide writes are used. In byte-wide write configurations, each bit controls the writing one
                                   // byte of dinb to address addrb. For example, to synchronously write only bits [15-8] of dinb when
                                   // WRITE_DATA_WIDTH_B is 32, web would be 4'b0010.

);

// End of xpm_memory_tdpram_inst instantiation

always_ff @(posedge clk)
	fnd <= fnFind(doutb,vreq.adr,asid) & {xlat,3'b0};
always_comb
	for (n = 0; n < 8; n = n + 1)
		empty[n] = ~doutb.ptge[n].v;

always_comb
	xlat = ~vreq.adr[31];
always_comb
	found = ~fnd[3];
always_ff @(posedge clk)
	if (page_fault)
		fault_adr <= {1'b0,vreq.adr[30:0]};
always_ff @(posedge clk)
	if (page_fault)
		fault_asid <= asid;

// Update state machine
ht_state ustate1
(
	.rst(rst), 
	.clk(clk),
	.cs(cs),
	.req(req),
	.state(state)
);

ht_wb_resp uresp1
(
	.rst(rst),
	.clk(clk),
	.state(state),
	.douta(douta),
	.cs(cs),
	.req(req),
	.resp(resp)
);

ht_ena uena1(
	.rst(rst),
	.clk(clk),
	.state(state),
	.cs(cs),
	.req(req),
	.ena(ena)
);

ht_wea uwea1
(
	.rst(rst),
	.clk(clk),
	.state(state),
	.cs(cs),
	.req(req),
	.wea(wea)
);

// table record to update, CPU side
ht_dina udina1
(
	.rst(rst),
	.clk(clk),
	.state(state),
	.req(req),
	.douta(douta),
	.dina(dina)
);

// write strobe to update a,m
ht_web uws1
(
	.rst(rst),
	.clk(clk),
	.xlat(xlat),
	.found(found),
	.req(vreq),
	.web(web)
);


// table record to update, hash Table side
ht_dinb udinb1
(
	.rst(rst),
	.clk(clk),
	.xlat(xlat),
	.found(found),
	.which(fnd[2:0]),
	.req(vreq),
	.doutb(doutb),
	.dinb(dinb)
);

ht_padr upa1
(
	.rst(rst),
	.clk(clk),
	.xlat(xlat),
	.found(found),
	.which(fnd[2:0]),
	.rec(doutb),
	.vadr(vreq.adr),
	.padr(padr),
	.padrv(padrv)
);

// Page fault logic
ht_page_fault upf1
(
	.rst(rst),
	.clk(clk),
	.xlat(xlat),
	.found(found),
	.empty(empty),
	.bounce(bounce),
	.current_group(hash),
	.page_group(page_group),
	.fault_group(fault_group),
	.page_fault(page_fault)
);

// Compute hash, page group (also hash)
ht_hash uhash1
(
	.rst(rst),
	.clk(clk),
	.xlat(xlat),
	.found(found),
	.empty(empty),
	.vadr(vreq.adr),
	.asid(asid),
	.bounce(bounce),
	.hash(hash),
	.page_group(page_group)
);

// Bounce counter
ht_bounce_counter uhtbc1
(
	.rst(rst),
	.clk(clk),
	.xlat(xlat),
	.found(found| (|empty)),
	.vadr(vreq.adr),
	.count(bounce)
);

endmodule
