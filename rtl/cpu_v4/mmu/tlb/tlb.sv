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
// 1050 LUTs / 850 FFs / 8 BRAMs / 190 MHz
// ============================================================================

import const_pkg::*;
import wishbone_pkg::*;
import mmu_pkg::*;
import cpu_types_pkg::*;

module tlb (clk, bus, stall, paging_en, cs_tlb, iv_count, store_i, id, asid, vadr, vadr_v, padr, padr_v, tlb_v,
	missack, miss_adr_o, miss_asid_o, miss_id_o, miss_o);
parameter TLB_ENTRIES=512;
parameter TLB_ASSOC=4;
parameter LOG_PAGESIZE=13;
localparam TLB_ABITS=$clog2(TLB_ENTRIES);
localparam TLB_WBITS=$clog2(TLB_ASSOC);
input clk;
wb_bus_interface.slave bus;
input stall;
input paging_en;
input cs_tlb;
input [5:0] iv_count;
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


genvar g;

wire [TLB_ABITS:0] rstcnt;
wire [TLB_ABITS-1:0] rst_entry_no;
tlb_entry_t rst_entry;
reg [1:0] way;
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

delay2 #(.WID(1)) udly1 (.clk(clk), .ce(1'b1), .i(cs_tlb & bus.req.cyc & bus.req.stb), .o(dly));

always_ff @(posedge clk)
	bus.resp.dat <= bus.req.adr[3] ? douta[0][127:64] : douta[0][63:0];
always_ff @(posedge clk)
	bus.resp.ack <= cs_tlb & bus.req.cyc & bus.req.stb & dly;

change_det #(.WID($bits(virtual_address_t)-LOG_PAGESIZE+1))
	ucd1 (.rst(rst), .clk(clk), .ce(1'b1), .i({vadr[$bits(virtual_address_t)-1:LOG_PAGESIZE-1],paging_en}), .cd(cd_vadr));

always_comb
	way = bus.req.adr[TLB_ABITS+TLB_WBITS-1:TLB_ABITS];

generate begin : gAssoc
	for (g = 0; g < TLB_ASSOC; g = g + 1) begin

always_comb
	addra[g] = rstcnt[TLB_ABITS] ? (paging_en ? addrb[g] : bus.req.adr[TLB_ABITS+3:4]): rst_entry_no;
always_comb
	dina[g] = rstcnt[TLB_ABITS] ? (paging_en ? dinb[g] : {bus.req.dat,bus.req.dat}) : rst_entry;
always_comb
	wea[g] = rstcnt[TLB_ABITS] ? (paging_en ? {16{web[g]}} : {
		{8{bus.req.we &  bus.req.adr[3]}} & bus.req.sel,
		{8{bus.req.we & ~bus.req.adr[3]}} & bus.req.sel}) :
		{16{1'b1}};
always_comb
	ena[g] = rstcnt[TLB_ABITS] ? (paging_en ? enb[g] : bus.req.cyc & bus.req.stb & cs_tlb && g==way) : g==0;

always_comb
	addrb[g] = vadr[LOG_PAGESIZE+TLB_ABITS-1:LOG_PAGESIZE];
always_comb
	tam(.hit(hit[g]), .store(store_i), .i(douta[g]), .o(dinb[g]));
always_comb
	enb[g] = 1'b1;
always_comb
	web[g] = hit[g] & !cd_vadr;

always_comb
	hit[g] = (douta[g].vpn.vpn[$bits(virtual_address_t)-LOG_PAGESIZE-TLB_ABITS-1:0]==miss_adr[$bits(virtual_address_t)-1:LOG_PAGESIZE+TLB_ABITS] &&
		(douta[g].pte.g ? TRUE : douta[g].vpn.asid==miss_asid) && douta[g].pte.v && douta[g].count==iv_count);



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
  .WRITE_MODE_A("read_first"),   // String
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
	.rst(rst),
	.clk(clk),
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
	.TLB_ENTRIES(TLB_ENTRIES)
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
