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
//	3100 LUTs / 1800 FFs / 7.5 BRAMs          
// ============================================================================

import const_pkg::*;
import wishbone_pkg::*;

module cap_cache(rst, clk, wr, wr_tag, adr, load_tags, hit, tagi, tago, tagso, req, resp);
parameter WID=64;
parameter LINEWID = 256;
parameter DEP=1024;
input rst;
input clk;
input wr;						// set for write to any memory area
input wr_tag;				// set for capability or pointer store.
input [31:0] adr;
input load_tags;
output reg hit;
input tagi;
output reg tago;
output reg [WID-1:0] tagso;
output wb_cmd_request256_t req;
input wb_cmd_response256_t resp;
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

integer n1;
wire rsta = rst;
wire rstb = rst;
wire clka = clk;
wire clkb = clk;
reg ena;
reg enb;
reg wea;
reg web;
reg [8:0] addraa;
reg [11:0] adrh;
reg [8:0] addra;
reg [31:0] addrb;
wire [LINEWID-1:0] douta;
reg [LINEWID-1:0] dina, dinb;
wb_cmd_request256_t reqw;
wb_tranid_t tid;
reg modified;
reg ihit;
reg m_next;
reg v_next;
reg set_v;
reg set_m;
reg set_mem;

reg [11:0] tag [0:DEP-1];
reg [DEP-1:0] v;
reg [DEP-1:0] m;
reg is_ior;

wire is_dram = adr[31:30]==2'b01;
wire is_rom = adr[31:19]==13'h1FFF;
wire is_io = adr[31:22]==10'b1111_1110_11;
wire is_tag_area = adr[31:24]==8'h3F;	// highest 16MB of DRAM

// Looking up the tag for every 64-bits (8 bytes)
// The tag lookup address is bits 31 to 3.
// Since there are 256 tags on a line, that uses eight bits
// so we want to feed bits 3 to 10 to select the byte on the line,
// and bits 11 to 31 to select the cache line.
// +----------------------+--------+---------+
// |                      |        | 10    3 |
// To load a line full of tags, there are 32 bytes per line
// so the line address is bits 5 to 16.

always_comb
begin
	if (load_tags) begin
		addraa = adr[16:5];
		adrh = adr[28:17];
	end
	else begin
		addraa = adr[20:11];
		adrh = adr[31:21];
	end
end

always_comb
	ihit = is_io || (tag[addraa]==adrh && v[addraa] && state==IDLE);

always_comb
	tago = is_io ? 1'b0 : (douta >> adr[10:3]) & 1'b1;

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
	dina <= 256'd0;
	dinb <= 256'd0;
	v_next <= 1'b0;
	m_next <= 1'b0;
	m <= 512'd0;
	v <= 512'd0;
	set_v <= 1'b1;
	set_m <= 1'b1;
	set_mem <= 1'b0;
	// Default fields for the bus.
	reqw <= {$bits(wb_cmd_request256_t){1'b0}};
	reqw.om <= wishbone_pkg::MACHINE;
	reqw.seg <= wishbone_pkg::DATA;
	reqw.blen <= 6'd0;
	reqw.bte <= wishbone_pkg::LINEAR;
	reqw.cti <= wishbone_pkg::CLASSIC;
	reqw.sz <= wishbone_pkg::hexi;
	reqw.csr <= LOW;
	reqw.pri <= 4'd7;
	/*
	reqw.key[0] <= 20'd0;
	reqw.key[1] <= 20'd0;
	reqw.key[2] <= 20'd0;
	reqw.key[3] <= 20'd0;
	*/
	reqw.pl <= 8'hFF;
	reqw.cache <= wishbone_pkg::NC_NB;
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
	req <= {$bits(wb_cmd_request256_t){1'b0}};
	hit <= ihit;
	// We want to use addrb to write to the m file so there is only a single
	// write port. Test to see if the contents changed.
	if (set_m)
		m[addrb] <= m_next;
	if (set_v)
		v[addrb] <= v_next;
	if (set_mem) begin
		enb <= 1'b1;
		web <= 1'b1;
		// There was a hit so douta is valid.
		dinb <= wr_tag ? 
			(douta & ~(256'b1 << adr[10:3]))	| // clear tag bits and
			({256'd0,tagi} << adr[10:3]) :			// insert new tag bits
			douta;
		m_next <= 1'b1;
		set_m <= 1'b1;
	end

case(state)
// Reset: 512 cycles
RESET:
 	begin
 		web <= !Qupls4_pkg::SIM;
 		enb <= !Qupls4_pkg::SIM;
 		// It is a pita to wait 512 cycles during simulation
 		if (Qupls4_pkg::SIM) begin
 			for (n1 = 0; n1 < DEP; n1 = n1 + 1)
 				tag[n1] = 12'd0;
			state <= IDLE;
 		end
 		else begin
	 		addrb[20:11] <= addrb[20:11] + 2'd1;
	// 		set_v <= 1'b1;
	// 		set_m <= 1'b1;
	 		m_next <= 1'b0;
	 		v_next <= 1'b0;
	 		m <= 512'd0;
	 		v <= 512'd0;
	 		tag[addrb[20:11]] <= 13'd0;
	 		dinb <= {LINEWID{1'b0}};
			if (addrb[20])
				state <= IDLE;
		end
 	end
IDLE:
	if (ihit) begin
		// Writing data clears the capability tag bit.
		casez({wr,wr_tag,load_tags})
		3'b000:	// reading tags
			begin
				addrb <= adr[20:11];
				addra <= adr[20:11];
			end
		// Doing a write cycle to the tag memory area?:
		// Clear the valid bit to cause a reload of the tags.
		// The memory will be updated by the data cache controller.
		// No need to update it here (we do not have the data to
		// store.)
		3'b1??:
			if (is_tag_area) begin
				addrb <= adr[16:5];
				addra <= adr[16:5];
				set_v <= 1'b1;
				v_next <= 1'b0;
			end
		// Doing a tag update?
		3'b01?:
			begin
				addrb <= adr[20:11];
				addra <= adr[20:11];
				set_mem <= 1'b1;
			end
		3'b001:
			begin
				addra <= adr[16:5];
				is_ior <= is_io;
				state <= LOAD_TAGS1;
			end
		endcase
	end
	// If there is a miss, the tags need to be loaded from memory.
	else begin
		addra <= adr[20:11];
		if (is_dram)
			reqw.adr <= dram_tags + {adr[30:11],5'h0};
		else if (is_rom)
			reqw.adr <= rom_tags + {adr[20:11],5'h0};
		if (modified)
			state <= DUMP;
		else
			state <= LOAD;
	end

// Dump the cache line back to memory.
DUMP:
	begin
		req <= reqw;
		req.cmd <= wishbone_pkg::CMD_STORE;
		req.cyc <= HIGH;
		req.we <= HIGH;
		req.adr <= reqw.adr;
		req.sel <= 32'hFFFFFFFF;
		req.dat <= douta;
		req.tid <= tid;
		tid.tranid <= tid.tranid + 2'd1;
		if (&tid.tranid)
			tid.tranid <= 4'd1;
		addrb <= reqw.adr[16:5];
		m_next <= 1'b0;
		set_m <= 1'b1;
		state <= DUMP_ACK;
	end
DUMP_ACK:
	if (resp.ack) begin
		req.cmd <= wishbone_pkg::CMD_NONE;
		req.cyc <= LOW;
		req.we <= LOW;
		req.adr <= reqw.adr;
		req.sel <= 32'h0;
		req.dat <= douta;
		req.tid <= tid;
		tid.tranid <= tid.tranid + 2'd1;
		if (&tid.tranid)
			tid.tranid <= 4'd1;
		state <= LOAD;
	end

LOAD:
	begin
		req <= reqw;
		req.cmd <= wishbone_pkg::CMD_LOADZ;
		req.cyc <= HIGH;
		req.we <= LOW;
		req.sel <= 32'hFFFFFFFF;
		req.adr <= reqw.adr;
		req.tid <= tid;
		tid.tranid <= tid.tranid + 2'd1;
		if (&tid.tranid)
			tid.tranid <= 4'd1;
		state <= LOAD_ACK;
	end
LOAD_ACK:
	if (resp.ack) begin
		req.cyc <= LOW;
		req.we <= LOW;
		req.adr <= reqw.adr;
		req.sel <= 32'h0;
		tag[reqw.adr[20:11]] <= reqw.adr[31:21]; // tags will be for address range
		web <= 1'b1;
		enb <= 1'b1;
		addrb <= reqw.adr[16:5];
		dinb <= resp.dat;
		m_next <= 1'b0;
		v_next <= 1'b1;
		set_v <= 1'b1;
		set_m <= 1'b1;
		state <= IDLE;
	end

LOAD_TAGS1:
	begin
		if (WID==64)
			tagso <= is_ior ? 64'd0 : douta >> {addra[5:0],3'b0};
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
  .ADDR_WIDTH_A($clog2(DEP)),               // DECIMAL
  .ADDR_WIDTH_B($clog2(DEP)),               // DECIMAL
  .AUTO_SLEEP_TIME(0),            // DECIMAL
  .BYTE_WRITE_WIDTH_A(LINEWID),        // DECIMAL
  .BYTE_WRITE_WIDTH_B(LINEWID),        // DECIMAL
  .CASCADE_HEIGHT(0),             // DECIMAL
  .CLOCKING_MODE("common_clock"), // String
  .ECC_MODE("no_ecc"),            // String
  .MEMORY_INIT_FILE("none"),      // String
  .MEMORY_INIT_PARAM("0"),        // String
  .MEMORY_OPTIMIZATION("true"),   // String
  .MEMORY_PRIMITIVE("auto"),      // String
  .MEMORY_SIZE(DEP*LINEWID),             // DECIMAL
  .MESSAGE_CONTROL(0),            // DECIMAL
  .READ_DATA_WIDTH_A(LINEWID),         // DECIMAL
  .READ_DATA_WIDTH_B(LINEWID),         // DECIMAL
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
  .WRITE_DATA_WIDTH_A(LINEWID),   // DECIMAL
  .WRITE_DATA_WIDTH_B(LINEWID),   // DECIMAL
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
  .doutb(),                   			// READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
  .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                   // on the data output of port A.

  .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                   // on the data output of port B.

  .addra(addra),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
  .addrb(addrb[20:11]),                   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
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
