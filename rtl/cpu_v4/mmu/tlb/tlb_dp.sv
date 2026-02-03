// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2026  Robert Finch, Waterloo
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
// 404 LUTs / 440 FFs / 13 BRAMs / 210 MHz
// ============================================================================

import const_pkg::*;
import wishbone_pkg::*;
import mmu_pkg::*;
import cpu_types_pkg::*;

module tlb (clk, bus, stall, paging_en, store_i, id, asid, vadr, vadr_v, padr, padr_v, tlb_v,
	missack, miss_adr_o, miss_asid_o, miss_id_o, miss_o);
parameter TLB_ENTRIES=2048;
parameter TLB_ASSOC=4;
parameter LOG_PAGESIZE=13;
localparam TLB_ABITS=$clog2(TLB_ENTRIES);
localparam TLB_WBITS=$clog2(TLB_ASSOC);
input clk;
wb_bus_interface.slave bus;
input stall;
input paging_en;
input store_i;
input [7:0] id;
input asid_t asid;
input virtual_address_t vadr;
input vadr_v;
output physical_address_t padr;
output padr_v;
output tlb_v;
input missack;
output address_t miss_adr_o;
output asid_t miss_asid_o;
output [7:0] miss_id_o;
output miss_o;


genvar g;

wire [10:0] rstcnt;
wire [9:0] rst_entry_no;
tlb_entry_t rst_entry;
reg [1:0] way;
reg dly;
virtual_address_t miss_adr_r;

wire rst = bus.rst;
wire rsta = bus.rst;
wire rstb = bus.rst;
wire clka = clk;
wire clkb = clk;

wire cd_vadr;
reg [TLB_ASSOC-1:0] hit;
reg [TLB_ASSOC-1:0] ena,enb;
reg [15:0] wea [0:TLB_ASSOC-1];
reg [15:0] web [0:TLB_ASSOC-1];

reg [TLB_ABITS-1:0] addra [0:TLB_ASSOC-1];
reg [TLB_ABITS-1:0] addrb [0:TLB_ASSOC-1];
tlb_entry_t [TLB_ASSOC-1:0] douta;
tlb_entry_t [TLB_ASSOC-1:0] doutb;
tlb_entry_t [TLB_ASSOC-1:0] dina;
tlb_entry_t [TLB_ASSOC-1:0] dinb;

// update access counts, count is saturating, and shifted right every so often.
task tam;
input hit;
input store;
input tlb_entry_t i;
output tlb_entry_t o;
reg of;
begin
	o = i;
	o.pte.a = 1'b1;
	if (hit & store)
		o.pte.m = 1'b1;
end
endtask

always_ff @(posedge clk)
	miss_adr_r <= miss_adr;

delay2 #(.WID(1)) udly1 (.clk(clk), .ce(1'b1), .i(cs_tlb & bus.req.cyc & bus.req.stb), .o(dly));

always_ff @(posedge clk)
	bus.resp.dat <= bus.req.adr[3] ? douta[0][127:64] : douta[0][63:0];
always_ff @(posedge clk)
	bus.resp.ack <= cs_tlb & bus.req.cyc & bus.req.stb & dly;

change_det #(.WID($bits(virtual_address_t)-LOG_PAGESIZE))
	ucd1 (.rst(rst), .clk(clk), .ce(1'b1), .i(vadr[31:13]), .cd(cd_vadr));

always_comb
	way = bus.req.adr[TLB_ABITS+TLB_WBITS-1:TLB_ABITS];

generate begin : gAssoc
	for (g = 0; g < TLB_ASSOC; g = g + 1) begin

always_ff @(posedge clk)
	addra[g] = rstcnt[10] ? bus.req.adr[TLB_ABITS+3:4] : rst_entry_no;
always_ff @(posedge clk)
	dina[g] = rstcnt[10] ? {bus.req.dat,bus.req.dat} : rst_entry;
always_ff @(posedge clk)
	wea[g] = rstcnt[10] ? {
		{8{bus.req.we &  bus.req.adr[3]}} & bus.req.sel,
		{8{bus.req.we & ~bus.req.adr[3]}} & bus.req.sel} :
		{16{1'b1}};
always_ff @(posedge clk)
	ena[g] = rstcnt[10] ? bus.req.cyc & bus.req.stb & cs_tlb && g==way : g==0;

always_comb
	addrb[g] = vadr[13+TLB_ABITS-1:13];
always_comb
	tam(.hit(hit[g]), .store(store_i), .i(doutb[g]), .o(dinb[g]));
always_comb
	enb[g] = 1'b1;
always_comb
	web[g] = hit[g] & !cd_vadr;

always_comb
	hit[g] = (doutb[g].vpn.vpn[18:0]==miss_adr_r[31:13] && doutb[g].vpn.asid==miss_asid && doutb[g].pte.v);

// xpm_memory_tdpram: True Dual Port RAM
// Xilinx Parameterized Macro, version 2022.2

xpm_memory_tdpram #(
  .ADDR_WIDTH_A(TLB_ABITS),               // DECIMAL
  .ADDR_WIDTH_B(TLB_ABITS),               // DECIMAL
  .AUTO_SLEEP_TIME(0),            // DECIMAL
  .BYTE_WRITE_WIDTH_A(8),        	// DECIMAL
  .BYTE_WRITE_WIDTH_B($bits(tlb_entry_t)),	// DECIMAL
  .CASCADE_HEIGHT(0),             // DECIMAL
  .CLOCKING_MODE("common_clock"), // String
  .ECC_MODE("no_ecc"),            // String
  .MEMORY_INIT_FILE("none"),      // String
  .MEMORY_INIT_PARAM("0"),        // String
  .MEMORY_OPTIMIZATION("true"),   // String
  .MEMORY_PRIMITIVE("auto"),      // String
  .MEMORY_SIZE(TLB_ENTRIES*$bits(tlb_entry_t)),             // DECIMAL
  .MESSAGE_CONTROL(0),            // DECIMAL
  .READ_DATA_WIDTH_A($bits(tlb_entry_t)),         // DECIMAL
  .READ_DATA_WIDTH_B($bits(tlb_entry_t)),         // DECIMAL
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
  .WRITE_DATA_WIDTH_A($bits(tlb_entry_t)),        // DECIMAL
  .WRITE_DATA_WIDTH_B($bits(tlb_entry_t)),        // DECIMAL
  .WRITE_MODE_A("read_first"),     // String
  .WRITE_MODE_B("read_first"),     // String
  .WRITE_PROTECT(1)               // DECIMAL
)
xpm_memory_tdpram_inst (
  .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence
  .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
  .douta(douta[g]),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
  .doutb(doutb[g]),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
  .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence
  .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
  .addra(addra[g]),  	// ADDR_WIDTH_A-bit input: Address for port A write and read operations.
  .addrb(addrb[g]),                // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
  .clka(clka),                     // 1-bit input: Clock signal for port A. Also clocks port B when
  .clkb(clkb),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
  .dina(dina[g]),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
  .dinb(dinb[g]),                     // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
  .ena(ena[g]), 			// 1-bit input: Memory enable signal for port A. Must be high on clock
  .enb(enb[g]),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
  .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
  .injectdbiterrb(1'b0), // 1-bit input: Controls double bit error injection on input data when
  .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
  .injectsbiterrb(1'b0), // 1-bit input: Controls single bit error injection on input data when
  .regcea(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
  .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
  .rsta(rsta),                     // 1-bit input: Reset signal for the final port A output register stage.
  .rstb(rstb),                     // 1-bit input: Reset signal for the final port B output register stage.
  .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
  .wea(wea[g]),                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
  .web(web[g])                      // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector
);
end
end
endgenerate

tlb_adr_mux #(.TLB_ASSOC(TLB_ASSOC)) utlba1
(
	.rst(rst),
	.clk(clk),
	.paging_en(paging_en), 
	.hit(hit),
	.tlbe(doutb),
	.id(id),
	.asid(asid),
	.vadr(vadr),
	.vadr_v(vadr_v),
	.padr(padr),
	.padr_v(padr_v),
	.tlb_v(tlb_v),
	.miss_id(miss_id),
	.miss_adr(miss_adr),
	.miss_asid(miss_asid),
	.miss_v(miss_v)
);

tlb_reset_machine utrst1
(
	.rst(rst),
	.clk(clk),
	.rstcnt(rstcnt),
	.entry_no(rst_entry_no),
	.entry(rst_entry)
);

tlb_miss_queue umq1
(
	.rst(rst),
	.clk(clk),
	.stall(stall),
	.rstcnt(rstcnt),
	.miss_adr(miss_adr),
	.miss_asid(miss_asid),
	.miss_id(miss_id),
	.miss_v(miss_v),
	.missack(missack),
	.miss_adr_o(miss_adr_o),
	.miss_asid_o(miss_asid_o),
	.miss_id_o(miss_id_o),
	.miss_o(miss_o)
);

endmodule
