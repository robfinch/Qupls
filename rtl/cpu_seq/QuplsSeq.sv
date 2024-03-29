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

import const_pkg::*;
import fta_bus_pkg::*;
import Qupls_cache_pkg::*;
import QuplsMmupkg::*;
import QuplsPkg::*;

//`define IS_SIM	1
`define ZERO		64'd0

module QuplsSeq(coreno_i, rst_i, clk_i, clk2x_i, irq_i, vect_i,
	fta_req, fta_resp, snoop_adr, snoop_v, snoop_cid);
parameter CORENO = 6'd1;
parameter CID = 6'd1;
input [63:0] coreno_i;
input rst_i;
input clk_i;
input clk2x_i;
input [2:0] irq_i;
input [8:0] vect_i;
output fta_cmd_request128_t fta_req;
input fta_cmd_response128_t fta_resp;
input QuplsPkg::address_t snoop_adr;
input snoop_v;
input [5:0] snoop_cid;

fta_cmd_request128_t ftatm_req;
fta_cmd_response128_t ftatm_resp;
fta_cmd_request128_t ftaim_req;
fta_cmd_response128_t ftaim_resp;
fta_cmd_request128_t [1:0] ftadm_req;
fta_cmd_response128_t [1:0] ftadm_resp;
fta_cmd_response128_t fta_resp1;
fta_cmd_response128_t ptable_resp;

wire rst = rst_i;
wire clk = clk_i;

genvar g;
reg [63:0] regfile [0:255];
reg [7:0] Ra,Rb,Rc,Rt;
value_t argA,argB,argC,argT,argI;
value_t brdisp;

reg [5:0] rstcnt;
reg [4:0] vele;
reg pc_valid;
pc_address_t pc,mc_adr,fpc;
mc_address_t micro_ip,mip,next_micro_ip,fmicro_ip;
ex_instruction_t ir,ir2;
ex_instruction_t micro_ir, fmicro_ir;
status_reg_t sr;
wire [2:0] im = sr.ipl;
reg vector_active;
value_t res;

pc_address_t icpc;
address_t icdp = 64'd0;
wire ihito;
wire ihit;
reg [1023:0] ic_line, ic_line_x;
ICacheLine ic_line_hi, ic_line_lo, ic_dline;
ICacheLine ic_line_o;
wire ic_valid, ic_dvalid;
wire [1:0] ic_wway;
wire ic_port;
wire wr_ic;
pc_address_t ic_miss_adr;
wire [15:0] ic_miss_asid;
reg [7:0] vl = 8'd8;
reg agen_next;
reg [3:0] tid;

reg invce = 1'b0;
address_t snoop_adr;
wire snoop_v;
wire [5:0] snoop_cid;
reg ic_invall = 1'b0;
reg ic_invline = 1'b0;
wire brtgtv = 1'b0;
wire icnop = 1'b0;

asid_t ip_asid = 16'h0;
asid_t asid;
pc_address_t [3:0] kvec;
value_t tick;
value_t canary = 64'd0;
status_reg_t sr_stack [0:8];
pc_address_t [8:0] pc_stack;
mc_stack_t [8:0] mc_stack;			// micro-code exception stack
cause_code_t [3:0] cause;
reg paging_en = 1'b1;
reg erc_stores = 1'b0;

wire pc_tlb_v;
address_t pc_tlb_res;
tlb_entry_t tlb_pc_entry;
reg micro_code_active = 1'b0;

decode_bus_t db;

dram_state_t dram0;	// state of the DRAM request
reg [639:0] dram0_data, dram0_datah;
virtual_address_t dram0_vaddr, dram0_vaddrh;
physical_address_t dram0_paddr, dram0_paddrh;
reg [79:0] dram0_sel, dram0_selh;
ex_instruction_t dram0_op;
memsz_t dram0_memsz;
rob_ndx_t dram0_id;
reg dram0_stomp;
reg dram0_load;
reg dram0_loadz;
reg dram0_store;
pregno_t dram0_Rt, dram_Rt0;
aregno_t dram0_aRt, dram_aRt0;
reg dram0_aRtz, dram_aRtz0;
reg dram0_bank;
cause_code_t dram0_exc;
reg dram0_ack;
fta_tranid_t dram0_tid;
wire dram0_more;
reg dram0_hi;
reg dram0_erc;
reg [9:0] dram0_shift;
reg [11:0] dram0_tocnt;
reg dram0_done;
reg dram0_idv;
reg [3:0] dram0_cp;
value_t dram0_argT;
value_t dram_bus0;
pc_address_t dram0_pc;
reg dram0_ldip;

reg [2:0] dramN [0:NDATA_PORTS-1];
reg [511:0] dramN_data [0:NDATA_PORTS-1];
reg [63:0] dramN_sel [0:NDATA_PORTS-1];
address_t dramN_addr [0:NDATA_PORTS-1];
address_t dramN_vaddr [0:NDATA_PORTS-1];
address_t dramN_paddr [0:NDATA_PORTS-1];
reg [NDATA_PORTS-1:0] dramN_load;
reg [NDATA_PORTS-1:0] dramN_loadz;
reg [NDATA_PORTS-1:0] dramN_store;
reg [NDATA_PORTS-1:0] dramN_ack;
reg [NDATA_PORTS-1:0] dramN_erc;
fta_tranid_t dramN_tid [0:NDATA_PORTS-1];
memsz_t dramN_memsz;
reg dc_invline = 1'b0;
reg dc_invall = 1'b0;

wire rfwr;
value_t rfoA;
value_t rfoB;
value_t rfoC;
value_t rfoT;

   // xpm_memory_sdpram: Simple Dual Port RAM
   // Xilinx Parameterized Macro, version 2022.2

   xpm_memory_sdpram #(
      .ADDR_WIDTH_A(8),               // DECIMAL
      .ADDR_WIDTH_B(8),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A(64),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("auto"),      // String
      .MEMORY_SIZE(256*64),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_B(64),         // DECIMAL
      .READ_LATENCY_B(1),             // DECIMAL
      .READ_RESET_VALUE_B("0"),       // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WAKEUP_TIME("disable_sleep"),  // String
      .WRITE_DATA_WIDTH_A(64),        // DECIMAL
      .WRITE_MODE_B("no_change"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   regfileA (
      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port B.

      .doutb(rfoA),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(Rt),                   // ADDR_WIDTH_A-bit input: Address for port A write operations.
      .addrb(Ra),                   // ADDR_WIDTH_B-bit input: Address for port B read operations.
      .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(res),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
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
      .wea(rfwr)                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

   );

   xpm_memory_sdpram #(
      .ADDR_WIDTH_A(8),               // DECIMAL
      .ADDR_WIDTH_B(8),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A(64),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("auto"),      // String
      .MEMORY_SIZE(256*64),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_B(64),         // DECIMAL
      .READ_LATENCY_B(1),             // DECIMAL
      .READ_RESET_VALUE_B("0"),       // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WAKEUP_TIME("disable_sleep"),  // String
      .WRITE_DATA_WIDTH_A(64),        // DECIMAL
      .WRITE_MODE_B("no_change"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   regfileB (
      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port B.

      .doutb(rfoB),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(Rt),                   // ADDR_WIDTH_A-bit input: Address for port A write operations.
      .addrb(Rb),                   // ADDR_WIDTH_B-bit input: Address for port B read operations.
      .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(res),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
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
      .wea(rfwr)                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

   );
				
   xpm_memory_sdpram #(
      .ADDR_WIDTH_A(8),               // DECIMAL
      .ADDR_WIDTH_B(8),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A(64),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("auto"),      // String
      .MEMORY_SIZE(256*64),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_B(64),         // DECIMAL
      .READ_LATENCY_B(1),             // DECIMAL
      .READ_RESET_VALUE_B("0"),       // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WAKEUP_TIME("disable_sleep"),  // String
      .WRITE_DATA_WIDTH_A(64),        // DECIMAL
      .WRITE_MODE_B("no_change"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   regfileC (
      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port B.

      .doutb(rfoC),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(Rt),                   // ADDR_WIDTH_A-bit input: Address for port A write operations.
      .addrb(Rc),                   // ADDR_WIDTH_B-bit input: Address for port B read operations.
      .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(res),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
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
      .wea(rfwr)                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

   );
				
   xpm_memory_sdpram #(
      .ADDR_WIDTH_A(8),               // DECIMAL
      .ADDR_WIDTH_B(8),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A(64),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("auto"),      // String
      .MEMORY_SIZE(256*64),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_B(64),         // DECIMAL
      .READ_LATENCY_B(1),             // DECIMAL
      .READ_RESET_VALUE_B("0"),       // String
      .RST_MODE_A("SYNC"),            // String
      .RST_MODE_B("SYNC"),            // String
      .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
      .USE_MEM_INIT(1),               // DECIMAL
      .USE_MEM_INIT_MMI(0),           // DECIMAL
      .WAKEUP_TIME("disable_sleep"),  // String
      .WRITE_DATA_WIDTH_A(64),        // DECIMAL
      .WRITE_MODE_B("no_change"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   regfileT (
      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port B.

      .doutb(rfoT),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(Rt),                   // ADDR_WIDTH_A-bit input: Address for port A write operations.
      .addrb(Rt),                   // ADDR_WIDTH_B-bit input: Address for port B read operations.
      .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(res),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
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
      .wea(rfwr)                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

   );

Qupls_icache
#(.CORENO(CORENO),.CID(0))
uic1
(
	.rst(rst),
	.clk(clk),
	.ce(1'b1),
	.invce(invce),
	.snoop_adr(snoop_adr),
	.snoop_v(snoop_v),
	.snoop_cid(snoop_cid),
	.invall(ic_invall),
	.invline(ic_invline),
	.nop(brtgtv),
	.nop_o(icnop),
	.ip_asid(ip_asid),
	.ip(pc),
	.ip_o(icpc),
	.ihit_o(ihito),
	.ihit(ihit),
	.ic_line_hi_o(ic_line_hi),
	.ic_line_lo_o(ic_line_lo),
	.ic_valid(ic_valid),
	.miss_vadr(ic_miss_adr),
	.miss_asid(ic_miss_asid),
	.ic_line_i(ic_line_o),
	.wway(ic_wway),
	.wr_ic(wr_ic),
	.dp(icdp),
	.dp_asid(ip_asid),
	.dhit_o(),//ic_dhit),
	.dc_line_o(ic_dline),
	.dc_valid(ic_dvalid),
	.port(ic_port),
	.port_i(1'b0)
);
assign ic_dhit = 1'b1;

always_ff @(posedge clk)
if (rst)
	rstcnt <= 6'd0;
else begin
	if (!rstcnt[4])
		rstcnt <= rstcnt + 2'd1;
end

always_comb
	ic_line = {ic_line_hi.data,ic_line_lo.data};
always_ff @(posedge clk)
if (rst)
	ic_line_x <= {22{41'd0,OP_NOP}};
else begin
	if (!rstcnt[4])
		ic_line_x <= {22{41'd0,OP_NOP}};
	else if (1'b1) 
		ic_line_x <= ic_line;
end

Qupls_icache_ctrl
#(.CORENO(CORENO),.CID(0))
icctrl1
(
	.rst(rst),
	.clk(clk),
	.wbm_req(ftaim_req),
	.wbm_resp(ftaim_resp),
	.ftam_full(ftaim_resp.rty),
	.hit(ihit),
	.tlb_v(pc_tlb_v),
	.miss_vadr(ic_miss_adr),
	.miss_padr(pc_tlb_res),
	.miss_asid(tlb_pc_entry.vpn.asid),
	.wr_ic(wr_ic),
	.way(ic_wway),
	.line_o(ic_line_o),
	.snoop_adr(snoop_adr),
	.snoop_v(snoop_v),
	.snoop_cid(snoop_cid)
);

ex_instruction_t mc_ins;

Qupls_micro_code umc0 (
	.om(sr.om),
	.ipl(sr.ipl),
	.micro_ip(micro_ip),
	.micro_ir(micro_ir),
	.next_ip(next_micro_ip),
	.instr(mc_ins),
	.regx()
);

ex_instruction_t [5:0] ins;

Qupls_mcat umcat0 (
	(!ihito && !micro_code_active),
	ins[0],
	mip
);

Qupls_decoder udec1
(
	.rst(rst),
	.clk(clk),
	.en(1'b1),
	.om(sr.om),
	.ipl(sr.ipl),
	.instr(ins),
	.dbo(db)
);

Qupls_branch_eval ube1
(
	.instr(ir2),
	.a(argA),
	.b(argB|db.immb),
	.takb(takb)
);

e_seq_state state, wb_next_state;

// ----------------------------------------------------------------------------
// EXECUTE stage combo logic
// ----------------------------------------------------------------------------

reg ld;
reg [7:0] cptgt;
value_t csr_res;
wire div_dbz;
value_t fpu_resH;
value_t alu_res;
value_t fpu_res;
wire fpu_done;
wire mul_done;
wire div_done;
wire div_dbz;
wire [7:0] alu_exc;

always_comb
	tReadCSR(csr_res,db.immb[15:0]);

Qupls_meta_alu #(.ALU0(1'b1)) ualu0
(
	.rst(rst),
	.clk(clk),
	.clk2x(clk2x_i),
	.ld(ld),
	.prc(db.prc),
	.ir(ir2.ins),
	.div(db.div),
	.cptgt(cptgt),
	.z(db.predz),
	.a(argA),
	.b(argB),
	.bi(db.immb|argB),
	.c(argC),
	.i(db.immb),
	.t(argT),
	.cs(3'd0),
	.pc(fpc),
	.csr(csr_res),
	.canary(canary),
	.cpl(sr.pl),
	.qres(fpu_resH),
	.o(alu_res),
	.mul_done(mul_done),
	.div_done(div_done),
	.div_dbz(div_dbz),
	.exc(alu_exc)
);

Qupls_meta_fpu ufpu1 (
	.rst(rst),
	.clk(clk2x_i),
	.idle(),
	.prc(2'd2),
	.ir(ir2.ins),
	.rm(3'b0),
	.a(argA),
	.b(argB),
	.c(argC),
	.t(argT),
	.i(argI),
	.p(),
	.o(fpu_res),
	.done(fpu_done)
);

// ----------------------------------------------------------------------------
// MEMORY stage combo logic
// ----------------------------------------------------------------------------

wire pmt_ena = ((vadr[31:16]==16'hFFF0)||(vadr[31:6]==16'hFFF1))
	&& (state==QuplsPkg::PMTACCESS1 || state==QuplsPkg::PMTACCESS2 || state==QuplsPkg::MEMORY);
wire pmt_wea = db.store;
wire pmt_enb = 1'b1;
wire pmt_web = state==QuplsPkg::MEMORY_ACK;
wire [13:0] pmt_addra = vadr[16: 3];
wire [12:0] pmt_addrb = vadr[28:16];
wire [63:0] pmt_douta;
PMTE pmt_doutb;
wire [63:0] pmt_dina = argC;
PMTE pmt_dinb;

always_comb
begin
	pmt_dinb = pmt_doutb;
	pmt_dinb.pm = db.store;
	pmt_dinb.access_count = pmt_doutb.access_count + 1;
end

   // xpm_memory_tdpram: True Dual Port RAM
   // Xilinx Parameterized Macro, version 2022.2

   xpm_memory_tdpram #(
      .ADDR_WIDTH_A(14),               // DECIMAL
      .ADDR_WIDTH_B(13),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A(64),        // DECIMAL
      .BYTE_WRITE_WIDTH_B(128),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("none"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("auto"),      // String
      .MEMORY_SIZE(8192*16),             // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_A(64),         // DECIMAL
      .READ_DATA_WIDTH_B(128),         // DECIMAL
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
      .WRITE_DATA_WIDTH_A(64),        // DECIMAL
      .WRITE_DATA_WIDTH_B(128),        // DECIMAL
      .WRITE_MODE_A("no_change"),     // String
      .WRITE_MODE_B("no_change"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   xpm_memory_tdpram_inst (
      .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .douta(pmt_douta),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(pmt_doutb),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port A.

      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(pmt_addra),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .addrb(pmt_addrb),                   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
      .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(pmt_dina),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .dinb(pmt_dinb),                     // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
      .ena(pmt_ena),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when read or write operations are initiated. Pipelined
                                       // internally.

      .enb(pmt_enb),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
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
      .wea(pmt_wea),                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

      .web(pmt_web)                        // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector
                                       // for port B input data port dinb. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dinb to address addrb. For example, to
                                       // synchronously write only bits [15-8] of dinb when WRITE_DATA_WIDTH_B
                                       // is 32, web would be 4'b0010.

   );

   // End of xpm_memory_tdpram_inst instantiation

address_t agen_res;
wire tlb_wr;
wire [1:0] tlb_way;
wire [6:0] tlb_entryno;
tlb_entry_t tlb_entry0, tlb_entry1, tlb_entry;
pc_address_t pc_tlb_res;
address_t ptw_vadr;
address_t ptw_padr,padr,vadr;
address_t tlb_missadr;
asid_t tlb_missasid;
wire ptw_vv;
reg agen_v;
wire tlb0_v,ptw_pv,pc_tlb_v;
wire tlb_missack;
wire tlb_miss;
wire [1:0] tlb_missqn;
reg stall_tlb0 =1'd0, stall_tlb1=1'd0;
wire [31:0] pg_fault;
wire [1:0] pg_faultq;
wire pe_fault_o;

wire en_ptw;
vtdl udly1 (.clk(clk), .ce(1'b1), .a(3), .d(state==MEMORY), .q(en_ptw));

Qupls_agen uag0
(
	.clk(clk),
	.ir(ir2),
	.next(agen_next),
	.Ra(Ra),
	.Rb(Rb),
	.pc(fpc),
	.a(argA),
	.b(argB),
	.i(argI),
	.res(vadr)
);

Qupls_tlb4way utlb1
(
	.rst(rst),
	.clk(clk),
	.ftas_req(fta_req),
	.ftas_resp(),
	.wr(tlb_wr),
	.way(tlb_way),
	.entry_no(tlb_entryno),
	.entry_i(tlb_entry),
	.entry_o(),
	.stall_tlb0(stall_tlb0),
	.stall_tlb1(stall_tlb1),
	.vadr0(vadr),
	.vadr1(ptw_vadr),
	.pc_vadr(ic_miss_adr),
	.op0(ir2),
	.op1({41'd0,OP_NOP}),
	.agen0_rndx_i(5'd0),
	.agen1_rndx_i(5'd0),
	.agen0_rndx_o(),
	.agen1_rndx_o(),
	.agen0_v(agen_v),
	.agen1_v(ptw_vv),
	.pc_valid(pc_valid),
	.load0_i(),
	.load1_i(),
	.store0_i(),
	.store1_i(),
	.asid0(asid),
	.asid1(12'h0),
	.pc_asid(ic_miss_asid),
	.entry0_o(tlb_entry0),
	.entry1_o(tlb_entry1),
	.pc_entry_o(tlb_pc_entry),
	.tlb0_v(tlb0_v),
	.tlb1_v(ptw_pv),
	.pc_tlb_v(pc_tlb_v),
	.tlb0_res(padr),
	.tlb1_res(ptw_padr),
	.pc_tlb_res(pc_tlb_res),
	.tlb0_op(),
	.tlb1_op(),
	.load0_o(),
	.load1_o(),
	.store0_o(),
	.store1_o(),
	.miss_o(tlb_miss),
	.missadr_o(tlb_missadr),
	.missasid_o(tlb_missasid),
	.missid_o(),
	.missqn_o(tlb_missqn),
	.missack(tlb_missack)
);

Qupls_ptable_walker #(.CID(3),.WAYS(4)) uptw1
(
	.rst(rst),
	.clk(clk),
	.paging_en(paging_en),
	.tlbmiss(tlb_miss),
	.tlb_missadr(tlb_missadr),
	.tlb_missasid(tlb_missasid),
	.tlb_missqn(tlb_missqn),
	.tlb_missid(5'd0),
	.commit0_id(5'd0),
	.commit0_idv(en_ptw),
	.commit1_id(8'd0),
	.commit1_idv(FALSE),
	.commit2_id(8'd0),
	.commit2_idv(FALSE),
	.commit3_id(8'd0),
	.commit3_idv(FALSE),
	.in_que(tlb_missack),
	.ftas_req(ftadm_req[0]),
	.ftas_resp(ptable_resp),
	.ftam_req(ftatm_req),
	.ftam_resp(ftatm_resp),
	.fault_o(pg_fault),
	.faultq_o(pg_faultq),
	.pe_fault_o(pe_fault_o),
	.tlb_wr(tlb_wr),
	.tlb_way(tlb_way),
	.tlb_entryno(tlb_entryno),
	.tlb_entry(tlb_entry),
	.ptw_vadr(ptw_vadr),
	.ptw_vv(ptw_vv),
	.ptw_padr(ptw_padr),
	.ptw_pv(ptw_pv)
);

wire [NDATA_PORTS-1:0] dcache_load;
wire [NDATA_PORTS-1:0] dhit;
wire [NDATA_PORTS-1:0] modified;
wire [1:0] uway [0:NDATA_PORTS-1];
fta_cmd_request512_t [NDATA_PORTS-1:0] cpu_request_i;
fta_cmd_request512_t [NDATA_PORTS-1:0] cpu_request_i2;
fta_cmd_response512_t [NDATA_PORTS-1:0] cpu_resp_o;
fta_cmd_response512_t [NDATA_PORTS-1:0] update_data_i;
wire [NDATA_PORTS-1:0] dump;
wire DCacheLine dump_o[0:NDATA_PORTS-1];
wire [NDATA_PORTS-1:0] dump_ack;
wire [NDATA_PORTS-1:0] dwr;
wire [1:0] dway [0:NDATA_PORTS-1];

generate begin : gDcache
for (g = 0; g < NDATA_PORTS; g = g + 1) begin

	always_comb
	begin
		cpu_request_i[g].cid = g + 1;
		cpu_request_i[g].tid = dramN_tid[g];
		cpu_request_i[g].om = fta_bus_pkg::MACHINE;
		cpu_request_i[g].cmd = dramN_store[g] ? fta_bus_pkg::CMD_STORE : dramN_loadz[g] ? fta_bus_pkg::CMD_LOADZ : dramN_load[g] ? fta_bus_pkg::CMD_LOAD : fta_bus_pkg::CMD_NONE;
		cpu_request_i[g].bte = fta_bus_pkg::LINEAR;
//		cpu_request_i[g].cti = (dramN_erc[g] || ERC) ? fta_bus_pkg::ERC : fta_bus_pkg::CLASSIC;
		cpu_request_i[g].cti = (dramN_store[g] && erc_stores) ? fta_bus_pkg::ERC : fta_bus_pkg::CLASSIC;
		cpu_request_i[g].blen = 6'd0;
		cpu_request_i[g].seg = fta_bus_pkg::DATA;
		cpu_request_i[g].asid = asid;
		cpu_request_i[g].cyc = dramN[g]==DRAMSLOT_READY;
		cpu_request_i[g].stb = dramN[g]==DRAMSLOT_READY;
		cpu_request_i[g].we = dramN_store[g];
		cpu_request_i[g].vadr = dramN_vaddr[g];
		cpu_request_i[g].padr = dramN_paddr[g];
		cpu_request_i[g].sz = fta_bus_pkg::fta_size_t'(dramN_memsz[g]);
		cpu_request_i[g].dat = dramN_data[g];
		cpu_request_i[g].sel = dramN_sel[g];
		cpu_request_i[g].pl = 8'h00;
		cpu_request_i[g].pri = 4'd7;
		cpu_request_i[g].cache = fta_bus_pkg::WT_NO_ALLOCATE;
		dramN_ack[g] = cpu_resp_o[g].ack;
	end

	Qupls_dcache
	#(.CORENO(CORENO), .CID(g+1))
	udc1
	(
		.rst(rst),
		.clk(clk),
		.dce(1'b0),
		.snoop_adr(snoop_adr),
		.snoop_v(snoop_v),
		.snoop_cid(snoop_cid),
		.cache_load(dcache_load[g]),
		.hit(dhit[g]),
		.modified(modified[g]),
		.uway(uway[g]),
		.cpu_req_i(cpu_request_i2[g]),
		.cpu_resp_o(cpu_resp_o[g]),
		.update_data_i(update_data_i[g]),
		.dump(dump[g]),
		.dump_o(dump_o[g]),
		.dump_ack_i(dump_ack[g]),
		.wr(dwr[g]),
		.way(dway[g]),
		.invce(invce),
		.dc_invline(dc_invline),
		.dc_invall(dc_invall)
	);

	Qupls_dcache_ctrl
	#(.CORENO(CORENO), .CID(g+1))
	udcctrl1
	(
		.rst_i(rst),
		.clk_i(clk),
		.dce(1'b0),
		.ftam_req(ftadm_req[g]),
//		.ftam_req(),
		.ftam_resp(ftadm_resp[g]),
		.ftam_full(ftadm_resp[g].rty),
		.acr(),
		.hit(dhit[g]),
		.modified(modified[g]),
		.cache_load(dcache_load[g]),
		.cpu_request_i(cpu_request_i[g]),
		.cpu_request_i2(cpu_request_i2[g]),
		.data_to_cache_o(update_data_i[g]),
		.response_from_cache_i(cpu_resp_o[g]),
		.wr(dwr[g]),
		.uway(uway[g]),
		.way(dway[g]),
		.dump(dump[g]),
		.dump_i(dump_o[g]),
		.dump_ack(dump_ack[g]),
		.snoop_adr(snoop_adr),
		.snoop_v(snoop_v),
		.snoop_cid(snoop_cid)
	);

end
end
endgenerate

always_comb
begin
	dramN[0] = dram0;
	dramN_paddr[0] = dram0_paddr;
	dramN_vaddr[0] = dram0_vaddr;
	dramN_data[0] = dram0_data[511:0];
	dramN_sel[0] = dram0_sel[63:0];
	dramN_store[0] = dram0_store;
	dramN_erc[0] = dram0_erc;
	dramN_load[0] = dram0_load;
	dramN_loadz[0] = dram0_loadz;
	dramN_memsz[0] = dram0_memsz;
	dramN_tid[0] = dram0_tid;
	dram0_ack = dramN_ack[0];
end


Qupls_seq_writeback uwb1
(
	.rst(rst),
	.clk(clk),
	.state(state),
	.next_state(wb_next_state),
	.db(db),
	.alu_res(alu_res),
	.fpu_res(fpu_res),
	.dram_bus(dram_bus0),
	.pc(fpc),
	.fpu_done(fpu_done),
	.div_done(div_done),
	.mul_done(mul_done),
	.rfwr(rfwr),
	.res(res)
);

// ----------------------------------------------------------------------------
// Sequential CPU state machine.
// ----------------------------------------------------------------------------

always_ff @(posedge clk)
if (rst)
	tReset();
else begin
tOnce();
case(state)
QuplsPkg::RESET:	
	tReset();
QuplsPkg::IFETCH:
	tFetch();	
QuplsPkg::EXTRACT:
	tExtract();
QuplsPkg::DECODE1:
	tGoto(DECODE2);
QuplsPkg::DECODE2:
	tDecode2();
QuplsPkg::REGREAD1:
	tGoto(REGREAD2);
QuplsPkg::REGREAD2:
	tRegread2();
QuplsPkg::EXECUTE:
	tExecute();
QuplsPkg::PMTACCESS1:
	tPMTAccess1();
QuplsPkg::PMTACCESS2:
	tPMTAccess2();
QuplsPkg::MEMORY:
	tMemory1();
QuplsPkg::MEMORY_ACK:
	tMemoryAck(1'd0);
QuplsPkg::MEMORY2:
	tMemory2();
QuplsPkg::MEMORY2_ACK:
	tMemoryAck(1'd1);
QuplsPkg::WRITEBACK:
	tGoto(wb_next_state);
default:
	tGoto(QuplsPkg::RESET);
endcase
end

`ifdef IS_SIM
function value_t fnArchRegVal;
input [7:0] regno;
begin
	fnArchRegVal = regfileA.xpm_memory_base_inst.mem[regno];
end
endfunction

always_ff @(posedge clk)
begin
	integer i;
	integer j;

	$display("\n\n\n\n\n\n\n\n");
	$display("TIME %0d", $time);
	$display("----- Fetch %c -----", ihito ? "h" : " ");
	$display("i$ pc input:  %h #", pc);
	$display("ir2: %h", ir2);
	$display("cache: %x", ic_line[511:0]);

	$display("----- Architectural Registers -----");
	for (i = 0; i < AREGS; i = i + 8)
		if (i > 48)
			$display("v%d -> %d: %h %d: %h %d: %h %d: %h %d: %h %d: %h %d: %h %d: %h #",
			i[7:0] >> 3'd3,
			8'd0, fnArchRegVal(i+0), 8'd1, fnArchRegVal(i+1), 8'd2, fnArchRegVal(i+2), 8'd3,  fnArchRegVal(i+3), 
			8'd4, fnArchRegVal(i+4), 8'd5, fnArchRegVal(i+5), 8'd6, fnArchRegVal(i+6), 8'd7,  fnArchRegVal(i+7)
			);
		else
			$display("v%d -> %d: %h %d: %h %d: %h %d: %h %d: %h %d: %h %d: %h %d: %h #",
			i[7:0] >> 3'd3,
			i[7:0]+8'd0, fnArchRegVal(i+0), i[7:0]+8'd1, fnArchRegVal(i+1), i[7:0]+8'd2, fnArchRegVal(i+2), i[7:0]+8'd3, fnArchRegVal(i+3), 
			i[7:0]+8'd4, fnArchRegVal(i+4), i[7:0]+8'd5, fnArchRegVal(i+5), i[7:0]+8'd6, fnArchRegVal(i+6), i[7:0]+8'd7, fnArchRegVal(i+7)
			);
	$display("----- Memory -----");
	$display("%d%c v%h p%h, %h %c%d #",
	    dram0, dram0_ack?"A":" ", dram0_vaddr, dram0_paddr, dram0_data, ((dram0_load || dram0_store) ? 109 : 97), dram0_op);
	$display("%h #", dram_bus0);

	$display("----- FCU -----");
	$display("eval:%c A=%h B=%h I=%h", takb?"T":"F", argA, argB, argI);

	$display("----- ALU -----");
	$display("I=%h T=%h A=%h B=%h C=%h %c%d pc:%h #",
		argI, argT, argA, argB, argC,
		 ((fnIsLoad(ir2) || fnIsStore(ir2)) ? 109 : 97),
		ir2, pc);
	$display("res:%h #", alu_res);

end
`endif

// External bus arbiter. Simple priority encoded.

always_comb
begin
	
	ftatm_resp = {$bits(fta_cmd_response128_t){1'd0}};
	ftaim_resp = {$bits(fta_cmd_response128_t){1'd0}};
	ftadm_resp[0] = {$bits(fta_cmd_response128_t){1'd0}};
	ftadm_resp[1] = {$bits(fta_cmd_response128_t){1'd0}};

	// Setup to retry.
	ftatm_resp.rty = 1'b1;
	ftaim_resp.rty = 1'b1;
	ftadm_resp[0].rty = 1'b1;
	ftadm_resp[1].rty = 1'b1;
	ftadm_resp[0].tid = ftadm_req[0].tid;
	ftadm_resp[1].tid = ftadm_req[1].tid;
		
	// Cancel retry if bus aquired.
	if (ftatm_req.cyc)
		ftatm_resp.rty = 1'b0;
	else if (ftaim_req.cyc)
		ftaim_resp.rty = 1'b0;
	else if (ftadm_req[0].cyc)
		ftadm_resp[0].rty = 1'b0;
	else if (ftadm_req[1].cyc)
		ftadm_resp[1].rty = 1'b0;

	// Route bus responses.
	case(fta_resp1.tid.channel)
	3'd0:	ftaim_resp = fta_resp1;
	3'd1:	ftadm_resp[0] = fta_resp1;
//	3'd2:	ftadm_resp[1] <= fta_resp1;
	3'd3:	ftatm_resp = fta_resp1;
	default:	;	// response was not for us
	endcase
	
end

always_ff @(posedge clk)
	if (ftatm_req.cyc)
		fta_req <= ftatm_req;
	else if (ftaim_req.cyc)
		fta_req <= ftaim_req;
	else if (ftadm_req[0].cyc)
		fta_req <= ftadm_req[0];
	else if (ftadm_req[1].cyc)
		fta_req <= ftadm_req[1];
	else
		fta_req <= {$bits(fta_cmd_request128_t){1'd0}};


fta_cmd_response128_t [1:0] resp_ch;

fta_respbuf #(.CHANNELS(2))
urb1
(
	.rst(rst),
	.clk(clk),
	.resp(resp_ch),
	.resp_o(fta_resp1)
);

always_ff @(posedge clk)
begin
	if (fta_req.cyc) begin
		if (fta_req.we) begin
			$display("Q+: Bus Write: %h <= %h", fta_req.padr, fta_req.data1);
		end
	end
	if (fta_resp.ack) begin
		$display("Q+: Bus ack: %h = %h", fta_resp.adr, fta_resp.dat);
	end
end

assign resp_ch[0] = fta_resp;
assign resp_ch[1] = ptable_resp;

task tGoto;
input e_seq_state nst;
begin
	state <= nst;
end
endtask

task tReset;
begin
	ir <= {41'd0,OP_NOP};
	micro_ir <= {41'd0,OP_NOP};
	ins[0].ins <= {41'd0,OP_NOP};
	ins[1].ins <= {41'd0,OP_NOP};
	ins[2].ins <= {41'd0,OP_NOP};
	ins[3].ins <= {41'd0,OP_NOP};
	ins[4].ins <= {41'd0,OP_NOP};
	pc <= RSTPC;
	pc_valid <= FALSE;
	micro_ip <= 12'h1A0;
	micro_code_active <= TRUE;
	vector_active <= FALSE;
	vele <= 5'd0;
	asid <= 16'h0;
	sr <= 64'd0;
	sr.pl <= 8'hFF;				// highest priority
	sr.om <= OM_MACHINE;
	sr.dbg <= TRUE;
	sr.ipl <= 3'd7;				// non-maskable interrupts only
	ld <= FALSE;
	agen_v <= FALSE;
	agen_next <= FALSE;
	tid <= 4'd1;
	dram0_stomp <= 32'd0;
	dram0_vaddr <= 64'd0;
	dram0_paddr <= 64'd0;
	dram0_data <= 512'd0;
	dram0_exc <= FLT_NONE;
	dram0_id <= 5'd0;
	dram0_load <= 1'd0;
	dram0_loadz <= 1'd0;
	dram0_store <= 1'd0;
	dram0_erc <= 1'd0;
	dram0_op <= OP_NOP;
	dram0_pc <= RSTPC;
	dram0_Rt <= 8'd0;
	dram0_tid.core <= CORENO;
	dram0_tid.channel <= 4'd1;
	dram0_tid.tranid <= 4'd1;
	dram0_hi <= 1'd0;
	dram0_shift <= 1'd0;
	dram0_tocnt <= 12'd0;
	dram0_cp <= 4'd0;
	dram0_argT <= 64'd0;
	dram0 <= DRAMSLOT_AVAIL;
	argA <= 64'd0;
	argB <= 64'd0;
	argC <= 64'd0;
	argT <= 64'd0;
	argI <= 64'd0;
	agen_next <= FALSE;
	tGoto(QuplsPkg::IFETCH);
end
endtask

task tOnce();
begin
	ld <= FALSE;
//	ftadm_req[0] <= {$bits(fta_cmd_request128_t){1'b0}};
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tFetch;
begin
	$display("rfwr=%d Rt=%d res=%h", rfwr, Rt, res);
	agen_next <= FALSE;
	if (irq_i > sr.ipl || &irq_i)
		tException(&irq_i ? FLT_NMI : FLT_IRQ, pc);
	else begin
		if (vector_active) begin
			if (vele < vl) begin
				ins[0] <= ir;
				tGoto(QuplsPkg::EXTRACT);
			end
			else
				vector_active <= FALSE;
		end
		else if (micro_code_active) begin
			ins[0] <= mc_ins;
			fmicro_ip <= micro_ip;
			micro_ip <= next_micro_ip;
			tGoto(QuplsPkg::EXTRACT);
		end
		else if (ihito) begin
			vele <= 5'd0;
			ins[0].ins <= ic_line >> {pc[5:0],3'b0};
			fpc <= pc;
			pc <= pc + 4'd6;
			tGoto(QuplsPkg::EXTRACT);
		end
		ins[1].ins <= {41'd0,OP_NOP};
		ins[2].ins <= {41'd0,OP_NOP};
		ins[3].ins <= {41'd0,OP_NOP};
		ins[4].ins <= {41'd0,OP_NOP};
	end
	if (rstcnt[4])
		pc_valid <= TRUE;
end
endtask

task tExtract;
begin
	tGoto(DECODE1);
	if (!vector_active) begin
		if (!micro_code_active) begin
			ins[0].aRa <= {3'd0,ins[0].ins.r3.Ra.num};
			ins[0].aRb <= {3'd0,ins[0].ins.r3.Rb.num};
			ins[0].aRc <= {3'd0,ins[0].ins.r3.Rc.num};
			ins[0].aRt <= {3'd0,ins[0].ins.r3.Rt.num};
		end
		ins[0].pred_btst = 6'd0;
		// If a vector instruction is detected, record the ir set the vector fetch
		// flag and go back to fetch.
		if (ins[0].ins.any.vec) begin
			vector_active <= TRUE;
			ir <= ins[0];
			tGoto(QuplsPkg::IFETCH);
		end
	end
	else begin
		vele <= vele + 2'd1;
		if (micro_code_active) begin
			ins[0].aRa <= ir.ins.r3.Ra.v ? {ir.aRa,vele[2:0]} : {3'd0,ir.aRa};
			ins[0].aRb <= ir.ins.r3.Rb.v ? {ir.aRb,vele[2:0]} : {3'd0,ir.aRb};
			ins[0].aRc <= ir.ins.r3.Rc.v ? {ir.aRc,vele[2:0]} : {3'd0,ir.aRc};
			ins[0].aRt <= ir.ins.r3.Rt.v ? {ir.aRt,vele[2:0]} : {3'd0,ir.aRt};
		end
		else begin
			ins[0].aRa <= ir.ins.r3.Ra.v ? {ir.ins.r3.Ra.num,vele[2:0]} : {3'd0,ir.ins.r3.Ra.num};
			ins[0].aRb <= ir.ins.r3.Rb.v ? {ir.ins.r3.Rb.num,vele[2:0]} : {3'd0,ir.ins.r3.Rb.num};
			ins[0].aRc <= ir.ins.r3.Rc.v ? {ir.ins.r3.Rc.num,vele[2:0]} : {3'd0,ir.ins.r3.Rc.num};
			ins[0].aRt <= ir.ins.r3.Rt.v ? {ir.ins.r3.Rt.num,vele[2:0]} : {3'd0,ir.ins.r3.Rt.num};
		end
		ins[0].pred_btst = 6'd0;
	end
	if (~|micro_ip)
		micro_code_active <= FALSE;
	if (|mip) begin
		micro_ir <= ins[0];
		micro_code_active <= TRUE;
		tGoto(QuplsPkg::IFETCH);
	end
	brdisp <= {{45{ins[0].ins.br.disp[16]}},ins[0].ins.br.disp,2'b0}
					 + {{46{ins[0].ins.br.disp[16]}},ins[0].ins.br.disp,1'b0};
end
endtask

task tDecode2;
begin
	ir2 <= ins[0];
	argI <= db.immb;
	cptgt <= {8{db.cpytgt}};
	Ra = db.Ra;
	Rb = db.Rb;
	Rc = db.Rc;
	Rt = db.Rt;
	if (db.rti) begin
		tProcessRti(ins[0].ins[12:11]==2'd2);
		tGoto(QuplsPkg::IFETCH);
	end
	else
		tGoto(QuplsPkg::REGREAD1);
end
endtask

/*
task tArg;
input Rn;
input bitwise;
input fpu;
input value_t rfo;
output value_t arg;
begin
	case({Rn,bitwise})
	2'b00:	arg = rfo;
	2'b01:	arg = rfo;
	2'b10:	arg = fpu ? {~rfo[$bits(value_t)-1],rfo[$bits(value_t)-2:0]} : -rfo;
	2'b11:	arg = ~rfo;
	endcase
end
endtask
*/
task tRegread2;
begin
	case({db.Ran,db.bitwise})
	2'b00:	argA <= rfoA;
	2'b01:	argA <= rfoA;
	2'b10:	argA <= db.fpu ? {~rfoA[$bits(value_t)-1],rfoA[$bits(value_t)-2:0]} : -rfoA;
	2'b11:	argA <= ~rfoA;
	endcase
	case({db.Rbn,db.bitwise})
	2'b00:	argB <= rfoB;
	2'b01:	argB <= rfoB;
	2'b10:	argB <= db.fpu ? {~rfoB[$bits(value_t)-1],rfoB[$bits(value_t)-2:0]} : -rfoB;
	2'b11:	argB <= ~rfoB;
	endcase
	case({db.Rcn,db.bitwise})
	2'b00:	argC <= rfoC;
	2'b01:	argC <= rfoC;
	2'b10:	argC <= db.fpu ? {~rfoC[$bits(value_t)-1],rfoC[$bits(value_t)-2:0]} : -rfoC;
	2'b11:	argC <= ~rfoC;
	endcase
//	tArg(db.Ran,db.bitwise,db.fpu,rfoA,argA);
//	tArg(db.Rbn,db.bitwise,db.fpu,rfoB,argB);
//	tArg(db.Rcn,db.bitwise,db.fpu,rfoC,argC);
	argT <= rfoT;
	tGoto(QuplsPkg::EXECUTE);
end
endtask

task tExecute;
begin
	ld <= TRUE;
	agen_v <= db.mem;
	if (db.br & takb)
		pc <= fpc + brdisp;
	else if (db.bsr)
		pc <= fpc + {{27{ins[0].ins.bsr.disp[36]}},ins[0].ins.bsr.disp};
	else if (db.bts==BTS_RET)
		pc <= argA + {ins[0].ins[10:8],2'd0} + {ins[0].ins[10:8],1'd0};
	else if (db.cjb) begin
		case(ins[0].ins[23:22])
		2'd0:	pc = {pc[$bits(pc_address_t)-1:16],argA[15:0]+argI[15:0]};
//			2'd1:	tgtpc = {pc[$bits(pc_address_t)-1:32],argA[31:0]+argI[31:0]};
		default: pc = argA + argI;
		endcase
	end
	tGoto(db.mem ? QuplsPkg::PMTACCESS1 : QuplsPkg::WRITEBACK);
end
endtask

task tPMTAccess1;
begin
	tGoto(vadr[31:16] > 16'hFFF8 ? QuplsPkg::MEMORY : QuplsPkg::PMTACCESS2);
end
endtask

task tPMTAccess2;
begin
	if ((vadr[31:16]==16'hFFF0)||(vadr[31:16]==16'hFFF1)) begin
		dram_bus0 <= pmt_douta;
		tGoto(db.load ? QuplsPkg::WRITEBACK : QuplsPkg::IFETCH);
	end
	else
		tGoto(QuplsPkg::MEMORY);
end
endtask

task tMemory1nc;

	ftadm_req[0].cid <= CID;
	ftadm_req[0].tid.core <= CORENO;
	ftadm_req[0].tid.channel <= 3'd1;
	ftadm_req[0].tid.tranid <= tid;
	tid <= tid + 2'd1;
	if (&tid)
		tid <= 4'd1;
	ftadm_req[0].om <= fta_bus_pkg::MACHINE;
	ftadm_req[0].cmd <= db.store ? fta_bus_pkg::CMD_STORE : db.loadz ? fta_bus_pkg::CMD_LOADZ : db.load ? fta_bus_pkg::CMD_LOAD : fta_bus_pkg::CMD_NONE;
	ftadm_req[0].bte <= fta_bus_pkg::LINEAR;
	ftadm_req[0].cti <= db.store && erc_stores ? fta_bus_pkg::ERC : fta_bus_pkg::CLASSIC;
	ftadm_req[0].blen <= 6'd0;
	ftadm_req[0].seg <= fta_bus_pkg::DATA;
	ftadm_req[0].asid <= asid;
	ftadm_req[0].cyc <= HIGH;
	ftadm_req[0].stb <= HIGH;
	ftadm_req[0].we <= db.store;
	ftadm_req[0].vadr <= vadr;
	ftadm_req[0].padr <= vadr;
	ftadm_req[0].sz <= fta_bus_pkg::fta_size_t'(fnMemsz(ins[0]));
	ftadm_req[0].data1 <= argC;
	ftadm_req[0].sel <= fnSel(ins[0]) << vadr[3:0];
	ftadm_req[0].pl <= 8'h00;
	ftadm_req[0].pri <= 4'd7;
	ftadm_req[0].cache <= fta_bus_pkg::NC_NB;

	tGoto(QuplsPkg::MEMORY_ACK);
endtask

task tMemory1;
begin
	//tMemory1nc();
	if (TRUE) begin
	if (paging_en) begin
		if (tlb0_v) begin
			dram0 <= DRAMSLOT_READY;
			dram0_exc <= FLT_NONE;
			dram0_stomp <= 1'b0;
			dram0_id <= 5'd0;
			dram0_idv <= VAL;
			dram0_op <= ins[0];
			dram0_ldip <= FALSE;
			dram0_pc <= fpc;
			dram0_load <= db.load;
			dram0_loadz <= db.loadz;
			dram0_store <= db.store;
			dram0_erc <= TRUE;//db.erc;
			dram0_Rt	<= Rt;
			dram0_aRt	<= Rt;
			dram0_aRtz <= ~|Rt;
			dram0_bank <= 1'b0;
			dram0_cp <= 4'd0;
			dram0_hi <= 1'b0;
			dram0_sel <= {64'h0,fnSel(ins[0])} << padr[5:0];
			dram0_selh <= {64'h0,fnSel(ins[0])} << padr[5:0];
			dram0_vaddr <= vadr;
			dram0_paddr <= padr;
			dram0_vaddrh <= vadr;
			dram0_paddrh <= padr;
			dram0_data <= {640'd0,argC} << {padr[5:0],3'b0};
			dram0_datah <= {640'd0,argC} << {padr[5:0],3'b0};
			dram0_shift <= {padr[5:0],3'd0};
			dram0_memsz <= fnMemsz(ins[0]);
			dram0_tid.core <= CORENO;
			dram0_tid.channel <= 3'd1;
			dram0_tid.tranid <= dram0_tid.tranid + 2'd1;
			if (dram0_tid.tranid==4'd15)
				dram0_tid.tranid <= 4'd1;
	    dram0_tocnt <= 12'd0;
	    tGoto(QuplsPkg::MEMORY_ACK);
		end
		else if (pe_fault_o) begin
			tException(FLT_PAGE,fpc);
			tGoto(QuplsPkg::IFETCH);
		end
	end
	else begin
		dram0 <= DRAMSLOT_READY;
		dram0_exc <= FLT_NONE;
		dram0_stomp <= 1'b0;
		dram0_id <= 5'd0;
		dram0_idv <= VAL;
		dram0_op <= ins[0];
		dram0_ldip <= FALSE;
		dram0_pc <= fpc;
		dram0_load <= db.load;
		dram0_loadz <= db.loadz;
		dram0_store <= db.store;
		dram0_erc <= TRUE;//db.erc;
		dram0_Rt	<= Rt;
		dram0_aRt	<= Rt;
		dram0_aRtz <= ~|Rt;
		dram0_bank <= 1'b0;
		dram0_cp <= 4'd0;
		dram0_hi <= 1'b0;
		dram0_sel <= {64'h0,fnSel(ins[0])} << vadr[5:0];
		dram0_selh <= {64'h0,fnSel(ins[0])} << vadr[5:0];
		dram0_vaddr <= vadr;
		dram0_paddr <= vadr;
		dram0_vaddrh <= vadr;
		dram0_paddrh <= vadr;
		dram0_data <= {640'd0,argC} << {vadr[5:0],3'b0};
		dram0_datah <= {640'd0,argC} << {vadr[5:0],3'b0};
		dram0_shift <= {vadr[5:0],3'd0};
		dram0_memsz <= fnMemsz(ins[0]);
		dram0_tid.core <= CORENO;
		dram0_tid.channel <= 3'd1;
		dram0_tid.tranid <= dram0_tid.tranid + 2'd1;
		if (dram0_tid.tranid==4'd15)
			dram0_tid.tranid <= 4'd1;
    dram0_tocnt <= 12'd0;
    tGoto(QuplsPkg::MEMORY_ACK);
	end
	if (vadr[31:16] < 16'h2000)
		case(sr.om)
		OM_APP:
			begin
				// write violation?
				if (~pmt_doutb.urwx[1] && db.store) begin
					dram0 <= DRAMSLOT_AVAIL;
					dram0_load <= FALSE;
					dram0_loadz <= FALSE;
					dram0_store <= FALSE;
					tGoto(IFETCH);
				end
				// read violation?
				if (~pmt_doutb.urwx[2] && (db.load|db.loadz)) begin
					dram0 <= DRAMSLOT_AVAIL;
					dram0_load <= FALSE;
					dram0_loadz <= FALSE;
					dram0_store <= FALSE;
					dram_bus0 <= 64'hFFFFFFFFFFFFFFFF;
					tGoto(WRITEBACK);
				end
			end
		default:	;
		endcase
	end
end
endtask

task tMemory2;
begin
	if (paging_en) begin
		if (tlb0_v) begin
			agen_next <= FALSE;
			dram0 <= DRAMSLOT_READY;
			dram0_hi <= 1'b1;
			dram0_sel <= dram0_selh >> 8'd64;
			dram0_vaddr <= {dram0_vaddrh[$bits(virtual_address_t)-1:6] + 2'd1,6'h0};
			dram0_paddr <= {dram0_paddrh[$bits(physical_address_t)-1:6] + 2'd1,6'h0};
			dram0_data <= dram0_datah >> 12'd512;
			dram0_shift <= {7'd64-dram0_paddrh[5:0],3'b0};
			dram0_tid.tranid <= dram0_tid.tranid + 2'd1;
			if (&dram0_tid.tranid)
				dram0_tid.tranid <= 4'd1;
			tGoto(QuplsPkg::MEMORY2_ACK);
		end
		else if (pe_fault_o) begin
			tException(FLT_PAGE,fpc);
			tGoto(QuplsPkg::IFETCH);
		end
	end
	else begin
		agen_next <= FALSE;
		dram0 <= DRAMSLOT_READY;
		dram0_hi <= 1'b1;
		dram0_sel <= dram0_selh >> 8'd64;
		dram0_vaddr <= {dram0_vaddrh[$bits(virtual_address_t)-1:6] + 2'd1,6'h0};
		dram0_paddr <= {dram0_paddrh[$bits(physical_address_t)-1:6] + 2'd1,6'h0};
		dram0_data <= dram0_datah >> 12'd512;
		dram0_shift <= {7'd64-dram0_paddrh[5:0],3'b0};
		dram0_tid.tranid <= dram0_tid.tranid + 2'd1;
		if (&dram0_tid.tranid)
			dram0_tid.tranid <= 4'd1;
		tGoto(QuplsPkg::MEMORY2_ACK);
	end
end
endtask

task tMemoryAckNc;
input which;
begin
	if (ftadm_resp[0].ack || (db.store && !erc_stores)) begin
		agen_v <= FALSE;
    if (which==1'd0)
  		dram_bus0 <= fnDati(1'b0,ins[0].ins,ftadm_resp[0].dat >> {vadr[3:0],3'd0}, fpc);
  	else
	  	dram_bus0 <= fnDati(1'b0,ins[0].ins,(ftadm_resp[0].dat << 128-{vadr[3:0],3'd0})|dram_bus0, fpc);
		// If the data is spanning a cache line, run second bus cycle.
		tGoto(db.load ? QuplsPkg::WRITEBACK : QuplsPkg::IFETCH);
	end
	else if (ftadm_resp[0].rty)
		tGoto(QuplsPkg::MEMORY);
end
endtask

task tMemoryAck;
input which;
begin
	//tMemoryAckNc(1'b0);
	if (TRUE) begin
		if (dram0_ack || (db.store && !erc_stores && !cpu_resp_o[0].rty)) begin
			if (dram0_tid==cpu_resp_o[0].tid || (db.store && !erc_stores)) begin
				agen_v <= FALSE;
				dram0 <= DRAMSLOT_AVAIL;
				dram0_hi <= 1'b0;
		    dram_Rt0 <= dram0_Rt;
		    dram_aRt0 <= dram0_aRt;
		    dram_aRtz0 <= dram0_aRtz;
		    if (which==1'd0)
		  		dram_bus0 <= fnDati(dram0_more,dram0_op,cpu_resp_o[0].dat >> dram0_shift, dram0_pc);
		  	else
			  	dram_bus0 <= fnDati(1'b0,dram0_op,(cpu_resp_o[0].dat << dram0_shift)|dram_bus0, dram0_pc);
		   	dram0_store <= 1'd0;
		   	dram0_sel <= 80'd0;
				// If the data is spanning a cache line, run second bus cycle.
				if (which==1'd0 && |dram0_selh[79:64]) begin
					agen_v <= TRUE;
					agen_next <= TRUE;
					tGoto(QuplsPkg::MEMORY2);
				end
				else
					tGoto(db.load ? QuplsPkg::WRITEBACK : QuplsPkg::IFETCH);
			end
			else if (cpu_resp_o[0].rty)
				tGoto(which ? QuplsPkg::MEMORY2 : QuplsPkg::MEMORY);
		end
		// Tid did not match requested, outstanding store?
		// Wait for the next ack
		else begin
			;
		end
	end
end
endtask


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Exception processing tasks.
//
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tException;
input cause_code_t cause;
input pc_address_t retpc;
integer nn;
begin
	//vecno = rob[id].imm ? rob[id].a0[8:0] : rob[id].a1[8:0];
	//vecno <= rob[id].exc;
	for (nn = 1; nn < 8; nn = nn + 1)
		sr_stack[nn] <= sr_stack[nn-1];
	sr_stack[0] <= sr;
	for (nn = 1; nn < 8; nn = nn + 1)
		pc_stack[nn] <= pc_stack[nn-1];
	pc_stack[0] <= retpc;
	for (nn = 1; nn < 8; nn = nn + 1)
		mc_stack[nn] <= mc_stack[nn-1];
	mc_stack[0].ir <= fmicro_ir;
	mc_stack[0].ip <= fmicro_ip;
	sr.ipl <= 3'd7;
	sr.pl <= 8'hFF;
	sr.mcip <= micro_ip;
	if (cause < 8'd16)
		pc <= {kvec[sr.dbg ? 4 : 3][$bits(pc_address_t)-1:4] + cause,4'h0};
	else
		pc <= {kvec[sr.dbg ? 4 : 3][$bits(pc_address_t)-1:4] + 4'd13,4'h0};
//		excmisspc <= {avec[$bits(pc_address_t)-1:16] + vecno,3'h0};
end
endtask

task tRex;
input ex_instruction_t ir;
begin
	if (sr.om > ir.ins[9:8] || sr.dbg) begin
		sr.om <= operating_mode_t'(ir.ins[9:8]);
		if (cause[3][7:0] < 8'd16)
			pc <= {kvec[ir.ins[9:8]][$bits(pc_address_t)-1:4] + cause[3][3:0],4'h0};
		else
			pc <= {kvec[ir.ins[9:8]][$bits(pc_address_t)-1:4] + 4'd13,4'h0};
	end
end
endtask

task tProcessRti;
input twoup;
integer nn;
begin
//	err_mask <= 64'd0;
	sr <= twoup ? sr_stack[1] : sr_stack[0];
	for (nn = 0; nn < 7; nn = nn + 1)
		sr_stack[nn] <= sr_stack[nn+1+twoup];
	sr_stack[7].ipl <= 3'd7;
	sr_stack[8].ipl <= 3'd7;
	sr_stack[7].om <= OM_MACHINE;
	sr_stack[8].om <= OM_MACHINE;
	for (nn = 0; nn < 7; nn = nn + 1)
		pc_stack[nn] <=	pc_stack[nn+1+twoup];
	pc_stack[7] <= RSTPC;
	pc_stack[8] <= RSTPC;
	pc <= twoup ? pc_stack[1] : pc_stack[0];
	// Unstack the micro-code instruction register
//	micro_ir <= twoup ? mc_stack[1].ir : mc_stack[0].ir;
//	exc_mcip <= twoup ? mc_stack[1].ip : mc_stack[0].ip;
	for (nn = 0; nn < 7; nn = nn + 1)
		mc_stack[nn] <=	mc_stack[nn+1+twoup];
	mc_stack[7].ir <= {41'd0,OP_NOP};
	mc_stack[8].ir <= {41'd0,OP_NOP};
	mc_stack[7].ip <= 12'h0;
	mc_stack[8].ip <= 12'h0;
	micro_ip <= twoup ? mc_stack[1].ip : mc_stack[0].ip;
	micro_ir <= twoup ? mc_stack[1].ir : mc_stack[0].ir;
end
endtask

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// CSR Read / Update tasks
//
// Important to use the correct assignment type for the following, otherwise
// The read won't happen until the clock cycle.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tReadCSR;
output value_t res;
input [15:0] regno;
begin
	if (operating_mode_t'(regno[13:12]) <= sr.om) begin
		$display("regno: %h, om=%d", regno, sr.om);
		casez(regno[15:0])
		CSR_MCORENO:	res = coreno_i;
		CSR_SR:		res = sr;
		CSR_TICK:	res = tick;
		CSR_ASID:	res = asid;
		CSR_KVEC3: res = kvec[3];
		16'h303C:	res = {sr_stack[1],sr_stack[0]};
		16'h303D:	res = {sr_stack[3],sr_stack[2]};
		16'h303E:	res = {sr_stack[5],sr_stack[4]};
		16'h303F:	res = {sr_stack[7],sr_stack[6]};
		(CSR_MEPC+0):	res = pc_stack[0];
		(CSR_MEPC+1):	res = pc_stack[1];
		(CSR_MEPC+2):	res = pc_stack[2];
		(CSR_MEPC+3):	res = pc_stack[3];
		(CSR_MEPC+4):	res = pc_stack[4];
		(CSR_MEPC+5):	res = pc_stack[5];
		(CSR_MEPC+6):	res = pc_stack[6];
		(CSR_MEPC+7):	res = pc_stack[7];
		/*
		CSR_SCRATCH:	res = scratch[regno[13:12]];
		CSR_MHARTID: res = hartid_i;
		CSR_MCR0:	res = cr0|(dce << 5'd30);
		CSR_PTBR:	res = ptbr;
		CSR_HMASK:	res = hmask;
		CSR_KEYS:	res = keys2[regno[0]];
		CSR_SEMA: res = sema;
//		CSR_FSTAT:	res = fpscr;
		CSR_MBADADDR:	res = badaddr[regno[13:12]];
		CSR_CAUSE:	res = cause[regno[13:12]];
		CSR_MTVEC:	res = tvec[regno[1:0]];
		CSR_UCA:
			if (regno[3:0]==4'd7)
				res = xip.offs;
			else if (regno[3:0] < 4'd8)
				res = xca.offs;
			else
				res = 64'd0;
		CSR_MCA,CSR_HCA,CSR_SCA:
			if (regno[3:0]==4'd7)
				res = xip.offs;
			else
				res = xca.offs;
		CSR_MPLSTACK:	res = plStack;
		CSR_MPMSTACK:	res = pmStack;
		CSR_MVSTEP:	res = estep;
		CSR_MVTMP:	res = vtmp;
		CSR_TIME:	res = wc_time;
		CSR_MSTATUS:	res = status[3];
		CSR_MTCB:	res = tcbptr;
//		CSR_DSTUFF0:	res = stuff0;
//		CSR_DSTUFF1:	res = stuff1;
		*/
		default:	res = 64'd0;
		endcase
	end
	else
		res = 64'd0;
end
endtask

task tWriteCSR;
input value_t val;
input [15:0] regno;
begin
	if (operating_mode_t'(regno[13:12]) <= sr.om) begin
		casez(regno[15:0])
		CSR_SR:		sr <= val;
		CSR_ASID: 	asid <= val;
		CSR_KVEC3:	kvec[3] <= val;
		16'h303C: {sr_stack[1],sr_stack[0]} <= val;
		16'h303D:	{sr_stack[3],sr_stack[2]} <= val;
		16'h303E:	{sr_stack[5],sr_stack[4]} <= val;
		16'h303F:	{sr_stack[7],sr_stack[6]} <= val;
		CSR_MEPC+0:	pc_stack[0] <= val;
		CSR_MEPC+1:	pc_stack[1] <= val;
		CSR_MEPC+2:	pc_stack[2] <= val;
		CSR_MEPC+3:	pc_stack[3] <= val;
		CSR_MEPC+4:	pc_stack[4] <= val;
		CSR_MEPC+5:	pc_stack[5] <= val;
		CSR_MEPC+6:	pc_stack[6] <= val;
		CSR_MEPC+7:	pc_stack[7] <= val;
		/*
		CSR_SCRATCH:	scratch[regno[13:12]] <= val;
		CSR_MCR0:		cr0 <= val;
		CSR_PTBR:		ptbr <= val;
		CSR_HMASK:	hmask <= val;
		CSR_SEMA:		sema <= val;
		CSR_KEYS:		keys2[regno[0]] <= val;
//		CSR_FSTAT:	fpscr <= val;
		CSR_MBADADDR:	badaddr[regno[13:12]] <= val;
		CSR_CAUSE:	cause[regno[13:12]] <= val[11:0];
		CSR_MTVEC:	tvec[regno[1:0]] <= val;
		CSR_MPLSTACK:	plStack <= val;
		CSR_MPMSTACK:	pmStack <= val;
		CSR_MVSTEP:	estep <= val;
		CSR_MVTMP:	begin new_vtmp <= val; ld_vtmp <= TRUE; end
//		CSR_DSP:	dsp <= val;
		CSR_MTIME:	begin wc_time_dat <= val; ld_time <= TRUE; end
		CSR_MTIMECMP:	begin clr_wc_time_irq <= TRUE; mtimecmp <= val; end
		CSR_MSTATUS:	status[3] <= val;
		CSR_MTCB:	tcbptr <= val;
//		CSR_DSTUFF0:	stuff0 <= val;
//		CSR_DSTUFF1:	stuff1 <= val;
		*/
		default:	;
		endcase
	end
end
endtask

task tSetbitCSR;
input value_t val;
input [15:0] regno;
begin
	if (operating_mode_t'(regno[13:12]) <= sr.om) begin
		casez(regno[15:0])
		CSR_SR:				sr <= sr | val;
		/*
		CSR_MCR0:			cr0[val[5:0]] <= 1'b1;
		CSR_SEMA:			sema[val[5:0]] <= 1'b1;
		CSR_MPMSTACK:	pmStack <= pmStack | val;
		CSR_MSTATUS:	status[3] <= status[3] | val;
		*/
		default:	;
		endcase
	end
end
endtask

task tClrbitCSR;
input value_t val;
input [15:0] regno;
begin
	if (operating_mode_t'(regno[13:12]) <= sr.om) begin
		casez(regno[15:0])
		CSR_SR:				sr <= sr & ~val;
		/*
		CSR_MCR0:			cr0[val[5:0]] <= 1'b0;
		CSR_SEMA:			sema[val[5:0]] <= 1'b0;
		CSR_MPMSTACK:	pmStack <= pmStack & ~val;
		CSR_MSTATUS:	status[3] <= status[3] & ~val;
		*/
		default:	;
		endcase
	end
end
endtask


endmodule

