// ============================================================================
//        __
//   \\__/ o\    (C) 2024-2025  Robert Finch, Waterloo
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
// Write-back cache with write allocate
//	2200 LUTs / 1400 FFs / 4 BRAMs          
// ============================================================================

import const_pkg::*;
import fta_bus_pkg::*;

module tag_cache(rst, clk, wr, wr_cap, adr, load_tags, hit, tagi, tago, tagso, req, resp);
parameter WID=64;
input rst;
input clk;
input wr;
input wr_cap;
input [31:0] adr;
input load_tags;
output reg hit;
input [3:0] tagi;
output reg [3:0] tago;
output reg [WID-1:0] tagso;
output fta_cmd_request256_t req;
input fta_cmd_response256_t resp;
parameter CORENO = 6'd1;
parameter CID = 3'd4;
localparam dram_tags = 32'h3FE00000;
localparam rom_tags  = 32'hFFF9F800;

typedef enum logic [3:0]
{
	RESET = 4'd0,
	IDLE,
	DUMP, DUMP_ACK,
	LOAD, LOAD_ACK,
	WRITE,
	LOAD_TAGS1
} e_state;
e_state state;
wire rsta = rst;
wire rstb = rst;
wire clka = clk;
wire clkb = clk;
reg ena;
reg enb;
reg wea;
reg web;
reg [8:0] addraa;
reg [12:0] adrh;
reg [8:0] addra;
reg [31:0] addrb;
reg wr_capb;
reg tagib;
reg [31:0] adr1;
wire [127:0] douta, doutb;
reg [127:0] dinb;
fta_cmd_request128_t reqw;
fta_tranid_t tid;
reg modified;
reg ihit;
reg m_next;
reg v_next;
reg set_v;
reg set_m;
reg set_mem;
reg [127:0] tagsoh;

reg [12:0] tag [0:511];
reg [0:511] v;
reg [0:511] m;
reg is_ior;

wire is_dram = adr[31:29]==3'b001;
wire is_rom = adr[31:19]==13'h1FFF;
wire is_io = adr[31:22]==10'b1111_1110_11;

always_comb
begin
	if (load_tags) begin
		addraa = adr[12:4];
		adrh = adr[25:13];
	end
	else begin
		addraa = adr[18:10];
		adrh = adr[31:19];
	end
end

always_comb
	ihit = is_io || (tag[addraa]==adrh && v[addraa] && state==IDLE);

always_comb
	tago = is_io ? 1'b0 : douta[adr[9:3]];

always_comb
	modified = m[addraa];

always_ff @(posedge clk)
if (rst) begin
	hit <= 1'b0;
	ena <= 1'b1;
	enb <= 1'b0;
	wea <= 1'b0;
	web <= 1'b0;
	addrb <= 32'd0;
	addra <= 9'd0;
	v_next <= 1'b0;
	m_next <= 1'b0;
	set_v <= 1'b1;
	set_m <= 1'b1;
	set_mem <= 1'b0;
	// Default fields for the bus.
	reqw <= {$bits(fta_cmd_request128_t){1'b0}};
	reqw.om <= fta_bus_pkg::MACHINE;
	reqw.asid <= 16'h0;
	reqw.seg <= fta_bus_pkg::DATA;
	reqw.blen <= 6'd0;
	reqw.bte <= fta_bus_pkg::LINEAR;
	reqw.cti <= fta_bus_pkg::CLASSIC;
	reqw.sz <= fta_bus_pkg::hexi;
	reqw.csr <= LOW;
	reqw.pri <= 4'd7;
	reqw.key[0] <= 20'd0;
	reqw.key[1] <= 20'd0;
	reqw.key[2] <= 20'd0;
	reqw.key[3] <= 20'd0;
	reqw.pl <= 8'hFF;
	reqw.cache <= fta_bus_pkg::NC_NB;
	tid.core <= CORENO;
	tid.channel <= CID;
	tid.tranid <= 4'd1;
	is_ior <= 1'b0;
	state <= RESET;
end
else begin
	set_v <= 1'b0;
	set_m <= 1'b0;
	set_m <= 1'b0;
	enb <= 1'b0;
	web <= 1'b0;
	req <= {$bits(fta_cmd_request128_t){1'b0}};
	hit <= ihit;
	// We want to use addrb to write to the m file so there is only a single
	// write port. Test to see if the contents changed.
	if (set_m)
		m[addrb[18:10]] <= m_next;
	if (set_v)
		v[addrb[18:10]] <= v_next;
	if (set_mem) begin
		enb <= 1'b1;
		web <= 1'b1;
		dinb <= douta;	// There was a hit so douta is valid.
		dinb[addrb[9:3]] <= wr_cap ? tagi : 1'b0;
		m_next <= 1'b1;
		set_m <= 1'b1;
	end

case(state)
// Reset: 512 cycles
RESET:
 	begin
 		web <= 1'b1;
 		enb <= 1'b1;
 		addrb[18:10] <= addrb[18:10] + 2'd1;
 		set_v <= 1'b1;
 		set_m <= 1'b1;
 		m_next <= 1'b0;
 		v_next <= 1'b0;
 		tag[addrb[18:10]] <= 13'd0;
 		dinb <= 128'd0;
 		if (addrb[19])
 			state <= IDLE;
 	end
IDLE:
	if (ihit) begin
		// Writing data clears the capability tag bit.
		if (wr|wr_cap) begin
			addrb <= adr;
			addra <= adr[18:10];
			set_mem <= 1'b1;
		end
		else if (load_tags) begin
			addra <= adr[12:4];
			is_ior <= is_io;
			state <= LOAD_TAGS1;
		end
	end
	else begin
		addra <= adr[15:7];
		if (is_dram)
			reqw.vadr <= dram_tags + {adr[28:10],4'h0};
		else if (is_rom)
			reqw.vadr <= rom_tags + {adr[18:10],4'h0};
		if (modified)
			state <= DUMP;
		else
			state <= LOAD;
	end

// Dump the cache line back to memory.
DUMP:
	begin
		req <= reqw;
		req.cmd <= fta_bus_pkg::CMD_STORE;
		req.cyc <= HIGH;
		req.stb <= HIGH;
		req.we <= HIGH;
		req.padr <= reqw.vadr;
		req.sel <= 16'hFFFF;
		req.data1 <= douta;
		req.tid <= tid;
		tid.tranid <= tid.tranid + 2'd1;
		if (&tid.tranid)
			tid.tranid <= 4'd1;
		addrb <= reqw.vadr;
		m_next <= 1'b0;
		set_m <= 1'b1;
		state <= DUMP_ACK;
	end
DUMP_ACK:
	if (resp.rty) begin
		req <= reqw;
		req.cmd <= fta_bus_pkg::CMD_STORE;
		req.cyc <= HIGH;
		req.stb <= HIGH;
		req.we <= HIGH;
		req.padr <= reqw.vadr;
		req.sel <= 16'hFFFF;
		req.data1 <= douta;
		req.tid <= tid;
		tid.tranid <= tid.tranid + 2'd1;
		if (&tid.tranid)
			tid.tranid <= 4'd1;
	end
	else
		state <= LOAD;

LOAD:
	begin
		req <= reqw;
		req.cmd <= fta_bus_pkg::CMD_LOADZ;
		req.cyc <= HIGH;
		req.stb <= HIGH;
		req.we <= LOW;
		req.sel <= 16'hFFFF;
		req.padr <= reqw.vadr;
		req.tid <= tid;
		tid.tranid <= tid.tranid + 2'd1;
		if (&tid.tranid)
			tid.tranid <= 4'd1;
		state <= LOAD_ACK;
	end
LOAD_ACK:
	if (resp.ack) begin
		tag[resp.adr[18:10]] <= resp.adr[31:19];
		web <= 1'b1;
		enb <= 1'b1;
		addrb <= resp.adr[18:10];
		dinb <= resp.dat;
		m_next <= 1'b0;
		v_next <= 1'b1;
		set_v <= 1'b1;
		set_m <= 1'b1;
		state <= IDLE;
	end
	else if (resp.rty) begin
		req <= reqw;
		req.cmd <= fta_bus_pkg::CMD_LOADZ;
		req.cyc <= HIGH;
		req.stb <= HIGH;
		req.we <= LOW;
		req.sel <= 16'hFFFF;
		req.padr <= reqw.vadr;
		req.tid <= tid;
		tid.tranid <= tid.tranid + 2'd1;
		if (&tid.tranid)
			tid.tranid <= 4'd1;
	end

LOAD_TAGS1:
	begin
		if (WID==64)
			tagso <= is_ior ? 64'd0 : douta >> addra[6:0];
		else
			tagso <= is_ior ? 128'd0 : douta;
		state <= IDLE;
	end	
default:
	state <= RESET;
endcase

end

// xpm_memory_tdpram: True Dual Port RAM
// Xilinx Parameterized Macro, version 2022.2

xpm_memory_tdpram #(
  .ADDR_WIDTH_A(9),               // DECIMAL
  .ADDR_WIDTH_B(9),               // DECIMAL
  .AUTO_SLEEP_TIME(0),            // DECIMAL
  .BYTE_WRITE_WIDTH_A(128),        // DECIMAL
  .BYTE_WRITE_WIDTH_B(128),        // DECIMAL
  .CASCADE_HEIGHT(0),             // DECIMAL
  .CLOCKING_MODE("common_clock"), // String
  .ECC_MODE("no_ecc"),            // String
  .MEMORY_INIT_FILE("none"),      // String
  .MEMORY_INIT_PARAM("0"),        // String
  .MEMORY_OPTIMIZATION("true"),   // String
  .MEMORY_PRIMITIVE("auto"),      // String
  .MEMORY_SIZE(512*128),             // DECIMAL
  .MESSAGE_CONTROL(0),            // DECIMAL
  .READ_DATA_WIDTH_A(128),         // DECIMAL
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
  .WRITE_DATA_WIDTH_A(128),        // DECIMAL
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

  .douta(douta),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
  .doutb(doutb),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
  .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                   // on the data output of port A.

  .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                   // on the data output of port B.

  .addra(addra),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
  .addrb(addrb[18:10]),                   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
  .clka(~clka),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                   // parameter CLOCKING_MODE is "common_clock".

  .clkb(~clkb),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                   // "independent_clock". Unused when parameter CLOCKING_MODE is
                                   // "common_clock".

  .dina(dina),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
  .dinb(dinb),                     // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
  .ena(ena),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
                                   // cycles when read or write operations are initiated. Pipelined
                                   // internally.

  .enb(enb),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
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

  .rsta(rsta),                     // 1-bit input: Reset signal for the final port A output register stage.
                                   // Synchronously resets output port douta to the value specified by
                                   // parameter READ_RESET_VALUE_A.

  .rstb(rstb),                     // 1-bit input: Reset signal for the final port B output register stage.
                                   // Synchronously resets output port doutb to the value specified by
                                   // parameter READ_RESET_VALUE_B.

  .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
  .wea(wea),                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                   // for port A input data port dina. 1 bit wide when word-wide writes are
                                   // used. In byte-wide write configurations, each bit controls the
                                   // writing one byte of dina to address addra. For example, to
                                   // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                   // is 32, wea would be 4'b0010.

  .web(web)                        // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector
                                   // for port B input data port dinb. 1 bit wide when word-wide writes are
                                   // used. In byte-wide write configurations, each bit controls the
                                   // writing one byte of dinb to address addrb. For example, to
                                   // synchronously write only bits [15-8] of dinb when WRITE_DATA_WIDTH_B
                                   // is 32, web would be 4'b0010.

);

			
endmodule
