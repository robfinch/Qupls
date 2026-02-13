`timescale 1ns / 1ps
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
// 3000 LUTs / 500 FFs / 8 BRAMs / 205 MHz RANDOM
// 2900 LUTs / 500 FFs / 8 BRAMs / 205 MHz LRU
// 2000 LUTs / 475 FFs / 8 BRAMs / 205 MHz NRU
// ============================================================================

import const_pkg::*;
import wishbone_pkg::*;
import mmu_pkg::*;
import cpu_types_pkg::*;

module tlb (clk, bus, stall, idle, paging_en, cs_tlb, iv_count, store_i, id,
	asid, vadr, vadr_v, padr, padr_v, tlb_v,
	missack, miss_adr_o, miss_asid_o, miss_id_o, miss_o, tlb_entry, rst_busy, empty);
parameter TLB_ENTRIES=512;
parameter TLB_ASSOC=4;
parameter LOG_PAGESIZE=13;
parameter UPDATE_STRATEGY = 2;
localparam TLB_ABITS=$clog2(TLB_ENTRIES);
localparam TLB_WBITS=$clog2(TLB_ASSOC);
localparam LFSR_MASK = (16'd1 << (TLB_ASSOC-1)) - 1;
localparam LRU = UPDATE_STRATEGY==1;
localparam NRU = UPDATE_STRATEGY==2;
input clk;
wb_bus_interface.slave bus;
input stall;
input idle;
input paging_en;
input cs_tlb;
input [3:0] iv_count;
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
output reg [7:0] miss_id_o;
output reg miss_o;
output tlb_entry_t tlb_entry;
output reg rst_busy;
output reg [TLB_ASSOC-1:0] empty;

integer n1;
genvar g;

wire [TLB_ABITS:0] rstcnt;
wire [TLB_ABITS-1:0] rst_entry_no;
wire [TLB_ABITS-1:0] hold_entry_no;
tlb_entry_t rst_entry, hold_entry;
reg [7:0] way;
wire [7:0] hold_way;
reg dly;
virtual_address_t miss_adr;
asid_t miss_asid;
wire [7:0] miss_id;

wire rst = bus.rst;
wire rsta = bus.rst;
wire rstb = bus.rst;
wire clka = clk;
wire clkb = clk;

wire cd_vadr;
reg [TLB_ASSOC-1:0] hit;
reg [TLB_ASSOC-1:0] nru;
reg nru_reset;
reg [TLB_ASSOC-1:0] ena,enb;
reg [15:0] wea [0:TLB_ASSOC-1];
reg [15:0] web [0:TLB_ASSOC-1];

reg [TLB_ABITS-1:0] addra [0:TLB_ASSOC-1];
reg [TLB_ABITS-1:0] addrb [0:TLB_ASSOC-1];
tlb_entry_t [TLB_ASSOC-1:0] douta;
tlb_entry_t [TLB_ASSOC-1:0] doutb;
tlb_entry_t [TLB_ASSOC-1:0] dina;
tlb_entry_t [TLB_ASSOC-1:0] dinb;
wire update_bit;
wire [63:0] lock_map;
wire [3:0] nrun;

wire [26:0] lfsro;

always_comb
begin
	tlb_entry = {$bits(tlb_entry_t){1'b0}};
	foreach(douta[n1])
		if (hit[n1])
			tlb_entry = douta[n1];
end

// update access counts, count is saturating, and shifted right every so often.
task tam;
input hit;
input nru_reset;
input store;
input tlb_entry_t i;
output tlb_entry_t o;
reg of;
begin
	o = i;
	if (nru_reset)
		o.nru = 1'b0;
	o.pte.a = 1'b1;
	if (hit & store)
		o.pte.m = 1'b1;
end
endtask

tlb_bi
#(
	.TLB_ASSOC(TLB_ASSOC)
)
ubi1
(
	.clk(clk),
	.cs_tlb(cs_tlb),
	.bus(bus),
	.dly(dly),
	.douta(douta),
	.hold_entry(hold_entry),
	.hold_entry_no(hold_entry_no),
	.hold_way(hold_way),
	.lock_map(lock_map)
);

always_comb
	rst_busy = ~rstcnt[TLB_ABITS];

delay2 #(.WID(1)) udly1 (.clk(clk), .ce(1'b1), .i(cs_tlb & bus.req.cyc & bus.req.stb), .o(dly));

lfsr27 #(.WID(27)) ulfsr1(rst, clk, 1'b1, 1'b0, lfsro);

change_det #(.WID($bits(virtual_address_t)-LOG_PAGESIZE+1))
	ucd1 (.rst(rst), .clk(clk), .ce(1'b1), .i({vadr[$bits(virtual_address_t)-1:LOG_PAGESIZE-1],paging_en}), .cd(cd_vadr));

always_comb
	way = hold_way;
always_comb
	nru_reset = &nru;

generate begin : gAssoc
    
	for (g = 0; g < TLB_ASSOC; g = g + 1) begin

always_comb
	addra[g] = rstcnt[TLB_ABITS] ? (paging_en ? addrb[g] : hold_entry_no): rst_entry_no;

tlb_dina_mux
#(
	.UPDATE_STRATEGY(UPDATE_STRATEGY),
	.TLB_ASSOC(TLB_ASSOC),
	.TLB_ABITS(TLB_ABITS),
	.LFSR_MASK(LFSR_MASK)
)
udinam1
(
	.rstcnt(rstcnt),
	.paging_en(paging_en),
	.lfsro(lfsro),
	.dinb(dinb),
	.hold_entry(hold_entry),
	.rst_entry(rst_entry),
	.nru(nru),
	.nrun(nrun),
	.dina(dina),
	.lock(lock_map[hold_entry_no[TLB_ABITS-1:TLB_ABITS-6 < 0 ? 0 : TLB_ABITS-6]])
);

always_comb
	wea[g] = rstcnt[TLB_ABITS] ? (paging_en ? {16{web[g]}} :
			{16{bus.req.we && bus.req.adr[5:3]==3'd4 && bus.req.dat[31] && cs_tlb &&
			!(lock_map[hold_entry_no[TLB_ABITS-1:TLB_ABITS-6 < 0 ? 0 : TLB_ABITS-6]] && g==TLB_ASSOC-1)}}) :
		{16{1'b1}};
always_comb
	ena[g] = rstcnt[TLB_ABITS] ? (paging_en ? enb[g] : bus.req.cyc & bus.req.stb & cs_tlb && (
		LRU ? !(lock_map[hold_entry_no[TLB_ABITS-1:TLB_ABITS-6 < 0 ? 0 : TLB_ABITS-6]] && g==TLB_ASSOC-1) :
		NRU ? g[3:0]==nrun :
		g==way)) : g==TLB_ASSOC-1;

always_comb
	addrb[g] = vadr[LOG_PAGESIZE+TLB_ABITS-1:LOG_PAGESIZE];
always_comb
	tam(.hit(hit[g]), .nru_reset(nru_reset), .store(store_i), .i(douta[g]), .o(dinb[g]));
always_comb
	enb[g] = 1'b1;
always_comb
	web[g] = hit[g] & !cd_vadr;

always_comb
	hit[g] = douta[g].pte.v &&
		(douta[g].vpn[$bits(virtual_address_t)-LOG_PAGESIZE-TLB_ABITS-1:0]==vadr[$bits(virtual_address_t)-1:LOG_PAGESIZE+TLB_ABITS] &&
		(douta[g].pte.g ? TRUE : douta[g].asid==asid && douta[g].count==iv_count));

always_comb
	empty[g] = ~douta[g].pte.v;
always_comb
	nru[g] = douta[g].nru;
	
always_ff @(posedge clk)
begin
	$display("vadr=%h", vadr);	
  $display("%d: hit[]=%d douta[]=%h", g, hit[g], douta[g]);
end

// xpm_memory_spram: Single Port RAM
// Xilinx Parameterized Macro, version 2025.1

xpm_memory_spram #(
  .ADDR_WIDTH_A(TLB_ABITS),              // DECIMAL
  .AUTO_SLEEP_TIME(0),           // DECIMAL
  .BYTE_WRITE_WIDTH_A(8),       // DECIMAL
  .CASCADE_HEIGHT(0),            // DECIMAL
  .ECC_BIT_RANGE("7:0"),         // String
  .ECC_MODE("no_ecc"),           // String
  .ECC_TYPE("none"),             // String
  .IGNORE_INIT_SYNTH(0),         // DECIMAL
  .MEMORY_INIT_FILE("none"),     // String
  .MEMORY_INIT_PARAM("0"),       // String
  .MEMORY_OPTIMIZATION("true"),  // String
  .MEMORY_PRIMITIVE("auto"),     // String
  .MEMORY_SIZE(TLB_ENTRIES*$bits(tlb_entry_t)),            // DECIMAL
  .MESSAGE_CONTROL(0),           // DECIMAL
  .RAM_DECOMP("auto"),           // String
  .READ_DATA_WIDTH_A($bits(tlb_entry_t)),        // DECIMAL
  .READ_LATENCY_A(1),            // DECIMAL
  .READ_RESET_VALUE_A("0"),      // String
  .RST_MODE_A("SYNC"),           // String
  .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
  .USE_MEM_INIT(1),              // DECIMAL
  .USE_MEM_INIT_MMI(0),          // DECIMAL
  .WAKEUP_TIME("disable_sleep"), // String
  .WRITE_DATA_WIDTH_A($bits(tlb_entry_t)),       // DECIMAL
  .WRITE_MODE_A("write_first"),   // String
  .WRITE_PROTECT(1)              // DECIMAL
)
xpm_memory_spram_inst (
  .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence on the data output of port A.
  .douta(douta[g]),                // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
  .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence on the data output of port A.
  .addra(addra[g]),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
  .clka(clka),                     // 1-bit input: Clock signal for port A.
  .dina(dina[g]),                  // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
  .ena(ena[g]),                    // 1-bit input: Memory enable signal for port A. Must be high on clock cycles when read or write operations
  .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when ECC enabled (Error injection capability
  .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when ECC enabled (Error injection capability
  .regcea(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output data path.
  .rsta(rsta),                     // 1-bit input: Reset signal for the final port A output register stage. Synchronously resets output port
  .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
  .wea(wea[g])                    // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector for port A input data port dina. 1 bit
);

end
end
endgenerate

tlb_adr_mux
#(
	.TLB_ASSOC(TLB_ASSOC),
	.LOG_PAGESIZE(LOG_PAGESIZE)
)
utlba1
(
	.rst(rst|rst_busy),
	.clk(clk),
	.idle(idle),
	.paging_en(paging_en), 
	.hit(hit),
	.tlbe(douta),
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

tlb_reset_machine
#(
	.WID(TLB_ABITS),
	.TLB_ENTRIES(TLB_ENTRIES),
	.LOG_PAGESIZE(LOG_PAGESIZE)
)
utrst1
(
	.rst(rst),
	.clk(clk),
	.rstcnt(rstcnt),
	.entry_no(rst_entry_no),
	.entry(rst_entry)
);
/*
tlb_miss_queue
#(
	.WID(TLB_ABITS)
)
umq1
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
*/
always_comb
	miss_adr_o = miss_adr;
always_comb
	miss_id_o = miss_id;
always_comb
	miss_asid_o = miss_asid;
always_comb
	miss_o = miss_v;

endmodule
