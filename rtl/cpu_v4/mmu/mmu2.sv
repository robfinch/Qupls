// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2026  Robert Finch, Waterloo
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
// FOR ANY DIRECT, INDIRECT, INCHANNELENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// 5110 LUTs / 6300 FFs / 28 BRAMs
// ============================================================================

import cpu_types_pkg::*;
import wishbone_pkg::*;

module mmu2 (rst, clk, g_paging_en, nsc_tlb_base_adr, sc_tlb_base_adr,
	sc_flush_en, nsc_flush_en, sc_flush_done, nsc_flush_done, pt_attr, ptbr,
	cs_sc_tlb, cs_nsc_tlb, cs_rgn, store, region_dat, cpl, om,
	sbus, mbus, vadr, vadr_v, asid, iv_count, clear_fault,
	padr, padr_v, tlb_v, page_fault, all_ways_locked, priv_err, rst_busy);
parameter SHORTCUT = 0;
parameter TLB_ENTRIES = 512;
parameter TLB_ASSOC = 4;
parameter LOG_PAGESIZE = 13;
parameter TLB2_ENTRIES = 128;
parameter TLB2_ASSOC = 2;
parameter LOG_PAGESIZE2 = 23;
input rst;
input clk;
input g_paging_en;
input address_t nsc_tlb_base_adr;
input address_t sc_tlb_base_adr;
input ptattr_t pt_attr;
input ptbr_t ptbr;
input sc_flush_en;
input nsc_flush_en;
output sc_flush_done;
output nsc_flush_done;
input store;
input clear_fault;
output [255:0] region_dat;
input cs_sc_tlb;
input cs_nsc_tlb;
input cs_rgn;
wb_bus_interface.slave sbus;
wb_bus_interface.master mbus;
input address_t vadr;
input vadr_v;
input asid_t asid;
input [3:0] iv_count;
output address_t padr;
output reg padr_v;
output tlb_v;
output page_fault;
output all_ways_locked;
output priv_err;
input [7:0] cpl;
input [1:0] om;
input rst_busy;

tlb_entry_t tlb_entry;
reg paging_en;
region_t region;
wb_cmd_request256_t sreqd;
wire [7:0] rgn_sel;
wire [2:0] grant;

always_ff @(posedge clk)
	sreqd <= sbus.req;

region_tbl urgnt1
(
	.rst(rst),
	.clk(clk),
	.cs_rgn(cs_rgn),
	.rgn(tlb_entry.pte.rgn),
	.req(sreqd),
	.region_dat(region_dat),
	.region_num(),
	.region(region),
	.sel(rgn_sel),
	.err()
);

//`ifdef 0
mmu_attr_check ummatd1
(
	.id(1'b0),
	.cpl(cpl),
	.tlb_entry(tlb_entry),
	.om(om),				// fix these inputs
	.we(store),			// fix these inputs
	.region(region),
	.priv_err(priv_err)
);

page_table_walker
#(
	.SHORTCUT(SHORTCUT),
	.TLB_ENTRIES(TLB_ENTRIES),
	.LOG_PAGESIZE(LOG_PAGESIZE),
	.TLB_ASSOC(TLB_ASSOC),
	.TLB2_ENTRIES(TLB2_ENTRIES),
	.LOG_PAGESIZE2(LOG_PAGESIZE2),
	.TLB2_ASSOC(TLB2_ASSOC)
)
uptw1
(
	.rst(rst),
	.clk(clk),
	.flush_cnt(nsc_flush_cnt),
	.flush_en(nsc_flush_en),
	.flush_done(nsc_flush_done),
	.flush2_cnt(sc_flush_cnt),
	.flush2_en(sc_flush_en),
	.flush2_done(sc_flush_done),
	.iv_asid(iv_asid),
	.iv_all(iv_all),
	.iv_count(iv_count),
	.g_paging_en(g_paging_en),
	.cs_tlb(cs_nsc_tlb),
	.cs_tlb2(cs_sc_tlb),
	.tlb_base_adr(nsc_tlb_base_adr),
	.tlb2_base_adr(sc_tlb_base_adr),
	.ptbr(ptbr),
	.pt_attr(pt_attr),
	.sbus(sbus),
	.mbus(mbus),
	.store(store),
	.vadr(vadr),
	.vadr_v(vadr_v),
	.asid(asid),
	.padr(padr),
	.padr_v(padr_v),
	.clear_fault(clear_fault),
	.page_fault(page_fault),
	.all_ways_locked(all_ways_locked),
	.tlb_entry(tlb_entry),
	.tlb_v(tlb_v),
	.rst_busy(rst_busy)
);

endmodule
