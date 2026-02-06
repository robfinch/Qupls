// ============================================================================
//        __
//   \\__/ o\    (C) 2026  Robert Finch, Waterloo
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
import wishbone_pkg::*;
import mmu_pkg::*;
import cpu_types_pkg::*;

module tlb_adr_mux(rst, clk, idle, paging_en, hit, id, asid, vadr, vadr_v, padr, padr_v,
	tlbe, tlb_v, miss_id, miss_adr, miss_asid, miss_v);
parameter TLB_ASSOC=3;
parameter LOG_PAGESIZE=13;
input rst;
input clk;
input idle;
input paging_en;
input [TLB_ASSOC-1:0] hit;
input tlb_entry_t [TLB_ASSOC-1:0] tlbe;
input [7:0] id;
input asid_t asid;
input virtual_address_t vadr;
input vadr_v;
output physical_address_t padr;
output reg padr_v;
output reg tlb_v;
output reg [7:0] miss_id;
output virtual_address_t miss_adr = 32'h0;
output asid_t miss_asid;
output reg miss_v;

reg miss1;
reg pe;
reg pe_ne, pe_pe;
reg padrv;
wire cd_vadr;
physical_address_t adr;
wire pe_vadr_v;

// If the address is changing we do not want to trigger a miss until the 
// translation has had time to be looked up (1 cycle). This only effects things
// when the page changes. Changing addresses within a page or not affected.

change_det
	#($bits(virtual_address_t)-LOG_PAGESIZE)
ucd1
	(.rst(rst), .clk(clk), .ce(1'b1), .i(vadr[$bits(virtual_address_t)-1:LOG_PAGESIZE]), .cd(cd_vadr));

edge_det ued1 (.rst(rst), .clk(clk), .i(vadr_v), .pe(pe_vadr_v), .ne(), .ee());

// There are transient invalid addresses when paging is enabled or disabled.
// The edge detectors detect this and prevent the address from being indicated
// valid.

always_ff @(posedge clk)
	pe <= paging_en;

always_comb
	pe_ne = (~paging_en & pe);
always_comb
	pe_pe = (paging_en & ~pe);
	
always_comb
	padr_v = padrv & !pe_pe;

// The TLB is multi-way associative. The address comes from whichever way has
// a valid translation.
integer n1;
always_comb
begin
	adr = {$bits(physical_address_t){1'b0}};
	for (n1 = 0; n1 < TLB_ASSOC; n1 = n1 + 1)
		if (hit[n1])
			adr = {tlbe[n1].pte.ppn,vadr[LOG_PAGESIZE-1:0]};
end

always_ff @(posedge clk)
if (rst) begin
	padr <= {$bits(physical_address_t){1'd0}};
	padrv <= 1'b0;
	miss_id <= 8'd0;
	miss_asid <= 16'h0;
	miss_adr <= {$bits(virtual_address_t){1'd0}};
	miss1 <= INV;
	tlb_v <= VAL;
end
else begin
	miss_adr <= miss_adr;
	if (paging_en) begin
		tlb_v <= INV;
		padr <= adr;
		$display("adr=%h", adr); 
		padrv <= |hit & vadr_v & !cd_vadr;
		if (!(|hit & vadr_v & !cd_vadr)) begin
			miss_adr <= vadr;
			miss_asid <= asid;
			miss_id <= id;
		end
		miss1 <= !cd_vadr;
		if (|hit & vadr_v & !cd_vadr) begin
			tlb_v <= idle;
			miss1 <= INV;
		end
	end
	else begin
		padr <= vadr;
 		padrv <= vadr_v & !pe_ne;
		tlb_v <= idle;
		miss1 <= INV;
	end

end

always_comb
	miss_v = miss1 & !cd_vadr;

endmodule
