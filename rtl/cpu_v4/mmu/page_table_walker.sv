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
// 1100 LUTs / 780 FFs / 8 BRAMs / 140 MHz
// 2100 LUTs / 1600 FFs / 12 BRAMs / 140 MHz	- with shortcut pages
// ============================================================================

import cpu_types_pkg::*;
import mmu_pkg::*;

module page_table_walker (rst, clk,
	flush_cnt, flush_en, flush_done,
	flush2_cnt, flush2_en, flush2_done,
	iv_asid, iv_all, iv_count,
	g_paging_en, cs_tlb, cs_tlb2,
	tlb_base_adr, tlb2_base_adr, sbus, mbus,
	ptbr, pt_attr,
	store, vadr, vadr_v, asid, padr, padr_v,
	page_fault, all_ways_locked, clear_fault,
	tlb_entry, tlb_v,
	rst_busy);
parameter SHORTCUT = 1;
parameter LRU = 1;
parameter TLB_ENTRIES = 512;
parameter TLB2_ENTRIES = 128;
parameter LOG_PAGESIZE = 13;
parameter LOG_PAGESIZE2 = 23;
parameter TLB_ASSOC = 4;
parameter TLB2_ASSOC = 2;
localparam TLB_ABITS=$clog2(TLB_ENTRIES);
localparam TLB2_ABITS=$clog2(TLB2_ENTRIES);
// Log2 of the number of PTE entries per page of memory.
localparam LOG_PTE_ENTRIES = LOG_PAGESIZE-3;
localparam TLB_NDX_MASK = ((32'd1 << LOG_PAGESIZE)-1);
localparam TLB2_NDX_MASK = ((32'd1 << LOG_PAGESIZE2)-1);
input rst;
input clk;
input [11:0] flush_cnt;
input flush_en;
output reg flush_done;
input [11:0] flush2_cnt;
input flush2_en;
output reg flush2_done;
input asid_t iv_asid;
input iv_all;
input [5:0] iv_count;
input g_paging_en;
input cs_tlb;
input cs_tlb2;
input address_t tlb_base_adr;
input address_t tlb2_base_adr;
input ptbr_t ptbr;
input ptattr_t pt_attr;
wb_bus_interface.slave sbus;
wb_bus_interface.master mbus;
input store;
input address_t vadr;
input vadr_v;
input asid_t asid;
output address_t padr;
output reg padr_v;
output reg page_fault;
output reg all_ways_locked;
input clear_fault;
output tlb_entry_t tlb_entry;
output reg tlb_v;
output reg rst_busy;

typedef enum logic [5:0]
{
	st_idle = 0,
	st_search2,
	st_search3,
	st_search4,
	st_read_lev1,
	st_read_lev1_2,
	st_read_lev1_3,
	st_read_lev1_4,
	st_read_lev2,
	st_read_lev2_2,
	st_read_lev2_3,
	st_read_lev2_4,
	st_readwrite_pte,
	st_readwrite_pte2,
	st_read_tlb,
	st_read_tlb2,
	st_read_tlb3,
	st_read_tlb4,
	st_read_tlb5,
	st_read_tlb2a,
	st_read_tlb2a2,
	st_read_tlb2a3,
	st_read_tlb2a4,
	st_read_tlb2a5,
	st_store_pte,
	st_store_pte2,
	st_store_pte3,
	st_update_tlb,
	st_update_tlb2,
	st_update_tlb3,
	st_update_tlb4,
	st_update_tlb5,
	st_update_tlb2a,
	st_update_tlb2a2,
	st_update_tlb2a3,
	st_update_tlb2a4,
	st_flush_tlb,
	st_flush_tlb2,
	st_flush_tlb2a,
	st_flush_tlb2a2,
	st_flush_asid,
	st_flush_asid2
} ptw_state_t;
ptw_state_t state;

integer n1;
ptw_state_t [3:0] state_stack;
reg [2:0] state_sp;
reg paging_en;
reg ics_tlb;
reg ics_tlb2;
reg missack,sc_missack;
reg [23:0] pt_index,next_pt_index;
address_t pt_adr;
address_t read_adr;
address_t sc_read_adr;
address_t nsc_padr;
reg nsc_padr_v;
address_t sc_padr;
reg sc_padr_v;
pte_t pte;
address_t pte_adr;
tlb_entry_t tlbe,tlbe_tmp;
address_t pt_start_adr;
reg [2:0] pt_start_level;
reg [2:0] level;
wb_bus_interface #(.DATA_WIDTH(64)) tlb_bus();
wb_bus_interface #(.DATA_WIDTH(64)) tlb2_bus();
address_t miss_adr1;
address_t miss_adr;
address_t sc_miss_adr;
asid_t miss_asid;
asid_t sc_miss_asid;
wire [7:0] miss_id_o;
wire [7:0] sc_miss_id_o;
address_t update_adr;
address_t sc_update_adr;
address_t flush_adr;
wire flush,flush2;
reg [2:0] flush_way;
wire [26:0] lfsro;
reg [1:0] way;
reg [5:0] iv_count;
reg [2:0] fndLevel1;
wire nsc_miss_o;
wire sc_miss_o;
wire cd_vadr;
tlb_entry_t nsc_tlb_entry;
tlb_entry_t sc_tlb_entry;
wire sc_rst_busy;
wire nsc_rst_busy;
wire sc_tlb_v;
wire nsc_tlb_v;
reg [2:0] retry;
address_t pt_adr_plus_index;
wire [TLB_ASSOC-1:0] nsc_empty;
wire [TLB2_ASSOC-1:0] sc_empty;
address_t cmp_mask;
address_t pg_offset;

pte_adr_t [3:0] level1;
pte_adr_t level2;

function [2:0] fnFindLevel1;
input address_t adr;
integer n;
begin
	fnFindLevel1 = 0;
	for (n = 0; n < 4; n = n + 1)
		if (adr==level1[n].adr)
			fnFindLevel1 = {1'b1,n[1:0]};
end
endfunction

always_comb
	rst_busy = sc_rst_busy|nsc_rst_busy;

always_comb
	fndLevel1 = fnFindLevel1(pt_adr + pt_index);

assign tlb_bus.rst = rst;
assign tlb_bus.clk = clk;
assign tlb2_bus.rst = rst;
assign tlb2_bus.clk = clk;

lfsr27 #(.WID(27)) ulfsr1(rst, clk, 1'b1, 1'b0, lfsro);

tlb
#(
	.LRU(LRU),
	.TLB_ENTRIES(TLB_ENTRIES),
	.TLB_ASSOC(TLB_ASSOC),
	.LOG_PAGESIZE(LOG_PAGESIZE)
)
utlb1
(
	.clk(clk),
	.bus(tlb_bus),
	.stall(1'b0),
	.idle(state==st_idle),
	.paging_en(paging_en),
	.cs_tlb(ics_tlb),
	.iv_count(iv_count),
	.store_i(store),
	.id(id),
	.asid(asid),
	.vadr(vadr),
	.vadr_v(vadr_v),
	.padr(nsc_padr),
	.padr_v(nsc_padr_v),
	.tlb_v(nsc_tlb_v),
	.missack(missack),
	.miss_adr_o(miss_adr),
	.miss_asid_o(miss_asid),
	.miss_id_o(miss_id_o),
	.miss_o(nsc_miss_o),
	.tlb_entry(nsc_tlb_entry),
	.rst_busy(nsc_rst_busy),
	.empty(nsc_empty)
);

generate begin : gTLB2
if (SHORTCUT) begin
tlb
#(
	.TLB_ENTRIES(TLB2_ENTRIES),
	.TLB_ASSOC(TLB2_ASSOC),
	.LOG_PAGESIZE(LOG_PAGESIZE2)
)
utlb2
(
	.clk(clk),
	.bus(tlb2_bus),
	.stall(1'b0),
	.idle(state==st_idle),
	.paging_en(paging_en),
	.cs_tlb(ics_tlb2),
	.iv_count(iv_count),
	.store_i(store),
	.id(id),
	.asid(asid),
	.vadr(vadr),
	.vadr_v(vadr_v),
	.padr(sc_padr),
	.padr_v(sc_padr_v),
	.tlb_v(sc_tlb_v),
	.missack(sc_missack),
	.miss_adr_o(sc_miss_adr),
	.miss_asid_o(sc_miss_asid),
	.miss_id_o(sc_miss_id_o),
	.miss_o(sc_miss_o),
	.tlb_entry(sc_tlb_entry),
	.rst_busy(sc_rst_busy),
	.empty(sc_empty)
);

counter #(.WID(12)) uflctr2 (
	.rst(~flush2_en|flush2_done), .clk(clk), .ce(state==st_idle), .ld(flush2), .d(flush2_cnt), .q(), .tc(flush2));
end
else begin
	assign sc_padr_v = FALSE;
	assign sc_padr = 32'h0;
	assign sc_missack = 1'b0;
	assign sc_tlb_v = 1'b0;
	assign sc_miss_adr = 32'h0;
	assign sc_miss_asid = 16'h0;
	assign sc_miss_id_o = 8'h0;
	assign sc_miss_o = 1'b1;
	assign sc_tlb_entry = {$bits(tlb_entry_t){1'b0}};
	assign sc_rst_busy = FALSE;
end
end
endgenerate

always_comb
	padr_v = sc_padr_v | nsc_padr_v;
always_comb
	padr = sc_padr_v ? sc_padr : nsc_padr;
always_comb
	tlb_entry = sc_padr_v ? sc_tlb_entry : nsc_tlb_entry;
always_comb
	tlb_v = nsc_tlb_v|sc_tlb_v;

//always_comb
//	pg_offset = miss_adr & (sc ? TLB2_NDX_MASK:TLB_NDX_MASK);
always_comb
	pt_index = (((miss_adr1 >> (LOG_PTE_ENTRIES * level + LOG_PAGESIZE)) % TLB_ENTRIES) << 4'h3);
always_comb
	pt_adr_plus_index = pt_adr + pt_index;
always_comb
	next_pt_index = (((miss_adr1 >> (LOG_PTE_ENTRIES * (level-1)) + LOG_PAGESIZE) % TLB_ENTRIES) << 4'h3);
always_comb
	pte = mbus.resp.dat;

counter #(.WID(12)) uflctr1 (
	.rst(~flush_en|flush_done), .clk(clk), .ce(state==st_idle), .ld(flush), .d(flush_cnt), .q(), .tc(flush));

change_det #(.WID($bits(address_t)+1)) ucd1 (.rst(rst), .clk(clk), .ce(1'b1), .i({vadr_v,vadr}), .cd(cd_vadr));

always_ff @(posedge clk)
if (rst|rst_busy) begin
	mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
	tlb_bus.req <= {$bits(wb_cmd_request64_t){1'b0}}; 
	missack <= FALSE;
	state <= st_idle;
	paging_en <= TRUE;
	state_sp <= 3'd0;
	foreach (state_stack[n1])
		state_stack[n1] <= st_idle;
	foreach (level1[n1])
		level1[n1] <= {$bits(pte_adr_t){1'b0}};
	level2 <= {$bits(pte_adr_t){1'b0}};
	flush_way <= 3'd0;
	flush_adr <= 32'd0;
	page_fault <= FALSE;
	all_ways_locked <= FALSE;
end
else begin
	missack <= FALSE;
	if (!flush_en)
		flush_done <= FALSE;
	if (!flush2_en)
		flush2_done <= FALSE;
	if (clear_fault) begin
		page_fault <= FALSE;
		all_ways_locked <= FALSE;
	end

	case (state)

	// Wait for a miss, then walk.
	st_idle:
		begin
			state_sp <= 3'd0;
			if (nsc_miss_o & sc_miss_o & vadr_v) begin
				pt_adr <= ptbr;
				level <= pt_attr.level;
				miss_adr1 <= miss_adr;
				missack <= TRUE;
				case(pt_attr.level)
				0:	tCall(st_read_lev1,st_idle);
				1:	tCall(st_read_lev2,st_idle);
	//			3:	state <= st_read_lev3;
				// ToDo implement other levels
				default:	;
				endcase
			end
			else if ((cs_tlb|cs_tlb2) & sbus.req.cyc & sbus.req.stb) begin
				paging_en <= FALSE;
				ics_tlb <= cs_tlb;
				ics_tlb2 <= cs_tlb2;
				tlb_bus.req.cyc <= cs_tlb;
				tlb_bus.req.stb <= cs_tlb;
				tlb_bus.req.we <= sbus.req.we;
				tlb_bus.req.sel <= 8'hFF;
				tlb_bus.req.adr <= tlb_base_adr + {sbus.req.adr[15:3],3'b0};
				tlb_bus.req.dat <= sbus.req.dat >> {sbus.req.adr[4:3],6'b0};
				if (SHORTCUT) begin
					tlb2_bus.req.cyc <= cs_tlb2;
					tlb2_bus.req.stb <= cs_tlb2;
					tlb2_bus.req.we <= sbus.req.we;
					tlb2_bus.req.sel <= 8'hFF;
					tlb2_bus.req.adr <= tlb2_base_adr + {sbus.req.adr[15:3],3'b0};
					tlb2_bus.req.dat <= sbus.req.dat >> {sbus.req.adr[4:3],6'b0};
					tGosub(st_readwrite_pte);
				end
			end
			else if (flush)
				tGosub(st_flush_tlb);
			else if (flush2 & SHORTCUT)
				tGosub(st_flush_tlb2a);
		end

	// read or write a specific TLB entry.
	st_readwrite_pte:
		// aborted cycle?
		if (!((cs_tlb|cs_tlb2) & sbus.req.cyc & sbus.req.stb)) begin
			paging_en <= TRUE;
			ics_tlb <= LOW;
			ics_tlb2 <= LOW;
			tlb_bus.req <= {$bits(wb_cmd_request64_t){1'b0}}; 
			tlb2_bus.req <= {$bits(wb_cmd_request64_t){1'b0}}; 
			sbus.resp <= {$bits(wb_cmd_response256_t){1'b0}};
		end
		else if (tlb_bus.resp.ack|tlb2_bus.resp.ack) begin
			paging_en <= TRUE;
			ics_tlb <= LOW;
			ics_tlb2 <= LOW;
			tlb_bus.req <= {$bits(wb_cmd_request64_t){1'b0}}; 
			tlb2_bus.req <= {$bits(wb_cmd_request64_t){1'b0}}; 
			sbus.resp <= {$bits(wb_cmd_response256_t){1'b0}};
			sbus.resp.tid <= sbus.req.tid;
			sbus.resp.pri <= sbus.req.pri;
			if (cs_tlb2)
				sbus.resp.dat <= {4{tlb2_bus.resp.dat}};
			else
				sbus.resp.dat <= {4{tlb_bus.resp.dat}};
			sbus.resp.ack <= HIGH;
			sbus.resp.err <= wishbone_pkg::OKAY;
			state <= st_readwrite_pte2;
		end
	st_readwrite_pte2:
		if (!((cs_tlb|cs_tlb2) && sbus.req.cyc & sbus.req.stb)) begin
			sbus.resp <= {$bits(wb_cmd_response256_t){1'b0}};
			tRet();
		end

	// Read lowest level page table.
	st_read_lev1:
		begin
			$display("PTW: miss address=%h", miss_adr);
			if (fndLevel1[2] && level1[fndLevel1[1:0]].pte.v) begin
				$display("PTW: Level2 cached read of %h", level1[fndLevel1[1:0]].adr);
				pt_adr <= (level1[fndLevel1[1:0]].pte.ppn << LOG_PAGESIZE) + next_pt_index;
				tlbe <= {$bits(tlb_entry_t){1'b0}};
				tlbe.pte <= level1[fndLevel1[1:0]].pte;
				tlbe.pte.a <= FALSE;
				tlbe.pte.m <= FALSE;
				tlbe.vpn <= miss_adr >> (LOG_PAGESIZE + TLB_ABITS);
				tlbe.asid <= miss_asid;
				tlbe.count <= iv_count;
				read_adr <= (((miss_adr1 >> LOG_PAGESIZE) % TLB_ENTRIES) << 4'd4) + tlb_base_adr;
				pte_adr <= level1[fndLevel1[1:0]].adr;
				way <= LRU ? 0 : lfsro[7:0];
				retry <= 3'd0;
				all_ways_locked <= FALSE;
				tCall(st_read_tlb,st_read_lev1_4);
			end
			else begin
				$display("PTW: Level1 read of %h", pt_adr_plus_index);
				mbus.req.cyc <= HIGH;
				mbus.req.stb <= HIGH;
				mbus.req.sel <= 32'hFF << {pt_index[4:3],3'h0};
				mbus.req.adr <= pt_adr_plus_index;
				pte_adr <= pt_adr_plus_index;
				tGoto(st_read_lev1_2);
			end
			level <= 3'd0;
		end
	st_read_lev1_2:
		if (mbus.resp.ack) begin
			mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
			$display("PTW: Level1 PTE=%h", pte);
			if (pte.v) begin
				tlbe <= {$bits(tlb_entry_t){1'b0}};
				tlbe.pte <= pte;
				tlbe.pte.a <= FALSE;
				tlbe.pte.m <= FALSE;
				tlbe.vpn <= miss_adr1 >> (LOG_PAGESIZE + TLB_ABITS);
				tlbe.asid <= miss_asid;
				tlbe.count <= iv_count;
				// Cache lookup
				level1[3].pte <= pte;
				level1[3].pte.a <= FALSE;
				level1[3].pte.m <= FALSE;
				level1[3].adr <= pte_adr;
				level1[2] <= level1[3];
				level1[1] <= level1[2];
				level1[0] <= level1[1];
				read_adr <= (((miss_adr1 >> LOG_PAGESIZE) % TLB_ENTRIES) << 4'd4) + tlb_base_adr;
				way <= LRU ? 8'd0 : lfsro[7:0];
				retry <= 3'd0;
				all_ways_locked <= FALSE;
				tCall(st_read_tlb,st_read_lev1_4);
			end
			else begin
				page_fault <= TRUE;
				tGoto(st_read_lev1_3);
			end
		end
	st_read_lev1_3:
		tRet();
	st_read_lev1_4:
		begin
			if (page_fault)
				tRet();
			else begin
				update_adr <= read_adr;
				// Switch to highest way for LRU updates
				if (LRU)
					way <= TLB_ASSOC-1;
				tCall(st_update_tlb,st_idle);
			end
		end

	// Read level 2 of the page tables.
	st_read_lev2:
		begin
			$display("PTW: miss address=%h", miss_adr1);
			if (level2.adr==pt_adr + pt_index && level2.pte.v) begin
				$display("PTW: Level2 cached read of %h", level2.adr);
				tlbe <= {$bits(tlb_entry_t){1'b0}};
				tlbe.pte <= pte;
				tlbe.pte.a <= FALSE;
				tlbe.pte.m <= FALSE;
				tlbe.asid <= miss_asid;
				tlbe.count <= iv_count;
				pte_adr <= level2.adr;
				pt_adr <= (level2.pte.ppn << LOG_PAGESIZE) + next_pt_index;
				if (level2.pte.typ==PTP_SHORTCUT & SHORTCUT) begin
					$display("PTW: Setting VPN=%h for %h", (miss_adr & 64'hFFFFFFFFFF800000) >> (LOG_PAGESIZE + TLB_ABITS), miss_adr);
					tlbe.vpn <= (miss_adr1 & 64'hFFFFFFFFFF800000) >> (LOG_PAGESIZE + TLB_ABITS);
					read_adr <= (((miss_adr1 >> LOG_PAGESIZE2) % TLB2_ENTRIES) << 4'd4) + tlb2_base_adr;
					way <= LRU ? 0 : lfsro[7:0];
					retry <= 3'd0;
					all_ways_locked <= FALSE;
					tCall(st_read_tlb2a,st_read_lev2_4);
				end
				else begin
					$display("PTW: Setting VPN=%h for %h", miss_adr >> (LOG_PAGESIZE + TLB_ABITS), miss_adr);
					tlbe.vpn <= miss_adr >> (LOG_PAGESIZE + TLB_ABITS);
					tGoto(st_read_lev1);
				end
			end
			else begin
				mbus.req.cyc <= HIGH;
				mbus.req.stb <= HIGH;
				mbus.req.sel <= 32'hFF << {pt_index[4:3],3'h0};
				mbus.req.adr <= pt_adr_plus_index;
				pte_adr <= pt_adr_plus_index;
				$display("PTW: Level2 read of %h", pt_adr_plus_index);
				tGoto(st_read_lev2_2);
			end
			level <= level - 2'd1;
		end
	st_read_lev2_2:
		if (mbus.resp.ack) begin
			mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
			$display("PTW: Level2 PTE=%h", pte);
			if (pte.v) begin
				// Cache lookup
				level2.pte <= pte;
				level2.pte.a <= FALSE;
				level2.pte.m <= FALSE;
				level2.adr <= pte_adr;
				pt_adr <= (pte.ppn << LOG_PAGESIZE);// + pt_index;
				way <= lfsro[1:0];
				if (pte.typ==PTP_SHORTCUT & SHORTCUT) begin
					read_adr <= ((((miss_adr1 & 64'hFFFFFFFFFF800000)>> LOG_PAGESIZE2) % TLB2_ENTRIES) << 4'd4) + tlb2_base_adr;
					tlbe <= {$bits(tlb_entry_t){1'b0}};
					tlbe.pte <= pte;
					tlbe.pte.a <= FALSE;
					tlbe.pte.m <= FALSE;
					tlbe.vpn <= (miss_adr & 64'hFFFFFFFFFF800000)>> (LOG_PAGESIZE + TLB2_ABITS);
					$display("PTW: Setting VPN=%h for %h", miss_adr1 >> (LOG_PAGESIZE2 + TLB2_ABITS), miss_adr1);
					tlbe.asid <= miss_asid;
					tlbe.count <= iv_count;
					way <= lfsro[1:0];
					retry <= 3'd0;
					all_ways_locked <= FALSE;
					tCall(st_read_tlb2a,st_read_lev2_4);
				end
				else begin
					read_adr <= (((miss_adr1 >> LOG_PAGESIZE) % TLB_ENTRIES) << 4'd4) + tlb_base_adr;
					$display("PTW: Setting VPN=%h for %h", miss_adr >> (LOG_PAGESIZE + TLB_ABITS), miss_adr1);
					tlbe <= {$bits(tlb_entry_t){1'b0}};
					tlbe.pte <= pte;
					tlbe.pte.a <= FALSE;
					tlbe.pte.m <= FALSE;
					tlbe.vpn <= miss_adr >> (LOG_PAGESIZE + TLB_ABITS);
					$display("PTW: Setting VPN=%h for %h", miss_adr1 >> (LOG_PAGESIZE + TLB_ABITS), miss_adr1);
					tlbe.asid <= miss_asid;
					tlbe.count <= iv_count;
					tGoto(st_read_lev2_3);
				end
			end
			else begin
				$display("PTE: Level2 Page fault");
				page_fault <= TRUE;
				tRet();
			end
		end
	st_read_lev2_3:
		tGoto(st_read_lev1);
	st_read_lev2_4:
		begin
			if (page_fault)
				tRet();
			else begin
				update_adr <= read_adr;
				// Switch to highest way for LRU updates
				if (LRU)
					way <= TLB2_ASSOC-1;
				tCall(st_update_tlb2a,st_idle);
			end
		end

	// Read the TLB to see if the entry being overwritten should be flushed to
	// memory first.
	st_read_tlb:
		begin
			$display("PTW: ReadTLB: %h:%h", read_adr, way);
			ics_tlb <= HIGH;
			tlb_bus.req.cyc <= HIGH;
			tlb_bus.req.stb <= HIGH;
			tlb_bus.req.we <= LOW;
			tlb_bus.req.sel <= 8'hFF;
			tlb_bus.req.adr <= read_adr;
			tGoto(st_read_tlb2);
		end
	st_read_tlb2:
		if (tlb_bus.resp.ack) begin
			tlbe_tmp[63:0] <= tlb_bus.resp.dat;
			tlb_bus.req <= {$bits(wb_cmd_request64_t){1'b0}}; 
			tGoto(st_read_tlb3);
		end
	st_read_tlb3:
		begin
			tlb_bus.req.cyc <= HIGH;
			tlb_bus.req.stb <= HIGH;
			tlb_bus.req.we <= LOW;
			tlb_bus.req.sel <= 8'hFF;
			tlb_bus.req.adr <= read_adr + 4'h8;
			tGoto(st_read_tlb4);
		end
	st_read_tlb4:
		if (tlb_bus.resp.ack) begin
			tlbe_tmp[127:64] <= tlb_bus.resp.dat;
			ics_tlb <= LOW;
			tlb_bus.req <= {$bits(wb_cmd_request64_t){1'b0}}; 
			tGoto(st_read_tlb5);
		end
	st_read_tlb5:
		begin
			// For LRU the way will not be locked as way zero is read.
			$display("PTW: ReadTLB TLBE=%h", tlbe_tmp);
			if (tlbe_tmp.lock) begin
				retry <= retry + 1;
				way <= way - 1;
				if (retry==TLB_ASSOC-1) begin
					all_ways_locked <= TRUE;
					page_fault <= TRUE;
					tRet();
				end
				else
					tGoto(st_read_tlb);
			end
			// Was there valid data in the PTE? If not, no need to store.
			else if (tlbe_tmp.pte.v & tlbe_tmp.pte.a)
				tGoto(st_store_pte);
			else
				tRet();
		end

	// Read the TLB2 to see if the entry being overwritten should be copied to
	// memory first.
	st_read_tlb2a:
		begin
			$display("PTW: ReadTLB2: %h:%h", read_adr, way);
			ics_tlb2 <= HIGH;
			tlb2_bus.req.cyc <= HIGH;
			tlb2_bus.req.stb <= HIGH;
			tlb2_bus.req.we <= LOW;
			tlb2_bus.req.sel <= 8'hFF;
			tlb2_bus.req.adr <= read_adr;
			tGoto(st_read_tlb2a2);
		end
	st_read_tlb2a2:
		if (tlb2_bus.resp.ack) begin
			tlbe_tmp[63:0] <= tlb2_bus.resp.dat;
			tlb2_bus.req <= {$bits(wb_cmd_request64_t){1'b0}}; 
			tGoto(st_read_tlb2a3);
		end
	st_read_tlb2a3:
		begin
			tlb2_bus.req.cyc <= HIGH;
			tlb2_bus.req.stb <= HIGH;
			tlb2_bus.req.we <= LOW;
			tlb2_bus.req.sel <= 8'hFF;
			tlb2_bus.req.adr <= read_adr + 4'h8;
			tGoto(st_read_tlb2a4);
		end
	st_read_tlb2a4:
		if (tlb2_bus.resp.ack) begin
			tlbe_tmp[127:64] <= tlb2_bus.resp.dat;
			ics_tlb2 <= LOW;
			tlb2_bus.req <= {$bits(wb_cmd_request64_t){1'b0}}; 
			tGoto(st_read_tlb2a5);
		end
	st_read_tlb2a5:
		begin
			// For LRU the way will not be locked as way zero is read.
			$display("PTW: ReadTLB2 TLBE=%h", tlbe_tmp);
			if (tlbe_tmp.lock) begin
				retry <= retry + 1;
				way <= way - 1;
				if (retry==3'd3) begin
					all_ways_locked <= TRUE;
					page_fault <= TRUE;
					tRet();
				end
				else
					tGoto(st_read_tlb2a);
			end
			// Was there valid data in the PTE? If not, no need to store.
			else if (tlbe_tmp.pte.v & tlbe_tmp.pte.a)
				tGoto(st_store_pte);
			else
				tRet();
		end

	// Store PTE to memory.
	// The modified / accessed bits may have been set.
	st_store_pte:
		begin
			$display("PTW: Store PTE: adr=%h pte=%h", pte_adr, tlbe_tmp.pte);
			mbus.req.cyc <= HIGH;
			mbus.req.stb <= HIGH;
			mbus.req.we <= HIGH;
			mbus.req.sel <= 32'hFF << {pte_adr[4:3],3'b0};
			mbus.req.adr <= pte_adr;
			mbus.req.dat <= {4{tlbe_tmp.pte}};
			tGoto(st_store_pte2);
		end
	st_store_pte2:
		if (mbus.resp.ack) begin
			mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
			tGoto(st_store_pte3);
		end
	st_store_pte3:
		tRet();

	// Write the TLB entry to the TLB
	st_update_tlb:
		begin
			$display("PTW: Update TLB: adr=%h tlbe=%h", update_adr, tlbe);
			paging_en <= FALSE;
			ics_tlb <= HIGH;
			tlb_bus.req.cyc <= HIGH;
			tlb_bus.req.stb <= HIGH;
			tlb_bus.req.we <= HIGH;
			tlb_bus.req.sel <= 8'hFF;
			tlb_bus.req.adr <= update_adr;
			tlb_bus.req.dat <= tlbe[63:0];
			tGoto(st_update_tlb2);
		end
	st_update_tlb2:
		if (tlb_bus.resp.ack) begin
			tlb_bus.req <= {$bits(wb_cmd_request64_t){1'b0}}; 
			tGoto(st_update_tlb3);
		end
	st_update_tlb3:
		begin
			tlb_bus.req.cyc <= HIGH;
			tlb_bus.req.stb <= HIGH;
			tlb_bus.req.we <= HIGH;
			tlb_bus.req.sel <= 8'hFF;
			tlb_bus.req.adr <= update_adr | 4'h8;
			tlb_bus.req.dat <= tlbe[127:64];
			tGoto(st_update_tlb4);
		end
	st_update_tlb4:
		if (tlb_bus.resp.ack) begin
			ics_tlb <= LOW;
			paging_en <= g_paging_en;
			tlb_bus.req <= {$bits(wb_cmd_request64_t){1'b0}}; 
			tGoto(st_update_tlb5);
		end
	st_update_tlb5:
		tRet();

	// Write the TLB entry to the TLB
	st_update_tlb2a:
		begin
			$display("PTW: Update TLB2: adr=%h tlbe=%h", update_adr, tlbe);
			paging_en <= FALSE;
			ics_tlb2 <= HIGH;
			tlb2_bus.req.cyc <= HIGH;
			tlb2_bus.req.stb <= HIGH;
			tlb2_bus.req.we <= HIGH;
			tlb2_bus.req.sel <= 8'hFF;
			tlb2_bus.req.adr <= update_adr;
			tlb2_bus.req.dat <= tlbe[63:0];
			tGoto(st_update_tlb2a2);
		end
	st_update_tlb2a2:
		if (tlb2_bus.resp.ack) begin
			tlb2_bus.req <= {$bits(wb_cmd_request64_t){1'b0}}; 
			tGoto(st_update_tlb2a3);
		end
	st_update_tlb2a3:
		begin
			tlb2_bus.req.cyc <= HIGH;
			tlb2_bus.req.stb <= HIGH;
			tlb2_bus.req.we <= HIGH;
			tlb2_bus.req.sel <= 8'hFF;
			tlb2_bus.req.adr <= update_adr | 4'h8;
			tlb2_bus.req.dat <= tlbe[127:64];
			tGoto(st_update_tlb2a4);
		end
	st_update_tlb2a4:
		if (tlb2_bus.resp.ack) begin
			ics_tlb2 <= LOW;
			paging_en <= g_paging_en;
			tlb2_bus.req <= {$bits(wb_cmd_request64_t){1'b0}}; 
			tGoto(st_update_tlb5);
		end

	// Perform a flush cycle.
	st_flush_tlb:
		begin
			$display("PTW: Flush TLB %h", flush_adr);
			read_adr <= flush_adr;
			way <= flush_way;
			tCall(st_read_tlb,st_flush_tlb2);
		end
	st_flush_tlb2:
		begin
			if ((~iv_all ? iv_asid == tlbe_tmp.asid : tlbe_tmp.count != iv_count) &&
				tlbe_tmp.pte.v && !tlbe_tmp.pte.g) begin
				tlbe <= tlbe_tmp;
				tlbe.pte.v <= INV;
				update_adr <= read_adr;
				tGoto(st_update_tlb);
			end
			else
				tRet();
			flush_way <= flush_way + 2'd1;
			if (flush_way==TLB_ASSOC-1) begin
				flush_way <= 3'd0;
				flush_adr[13:0] <= flush_adr[13:0] + 5'h10;
				if (flush_adr[13:0]=={TLB_ENTRIES-1,4'h0})
					flush_done <= TRUE;
			end
		end

	st_flush_tlb2a:
		begin
			$display("PTW: Flush TLB2 %h", flush_adr);
			read_adr <= flush_adr;
			way <= flush_way;
			tCall(st_read_tlb2a,st_flush_tlb2a2);			
		end
	st_flush_tlb2a2:
		begin
			if ((~iv_all ? iv_asid == tlbe_tmp.asid : tlbe_tmp.count != iv_count) &&
				tlbe_tmp.pte.v && !tlbe_tmp.pte.g) begin
				tlbe <= tlbe_tmp;
				tlbe.pte.v <= INV;
				update_adr <= read_adr;
				tGoto(st_update_tlb2a);
			end
			else
				tRet();
			flush_way <= flush_way + 2'd1;
			if (flush_way==TLB2_ASSOC-1) begin
				flush_way <= 3'd0;
				flush_adr[13:0] <= flush_adr[13:0] + 5'h10;
				if (flush_adr[13:0]=={TLB2_ENTRIES-1,4'h0})
					flush2_done <= TRUE;
			end
		end

	default:   state <= st_idle;
	endcase
end

task tGoto;
input ptw_state_t dst;
begin
	state <= dst;
end
endtask

task tGosub;
input ptw_state_t dst;
begin
	state_stack[0] <= state;
	state_stack[1] <= state_stack[0];
	state_stack[2] <= state_stack[1];
	state_stack[3] <= state_stack[2];
	state <= dst;
end
endtask

task tCall;
input ptw_state_t dst;
input ptw_state_t nst;
begin
	state_stack[0] <= nst;
	state_stack[1] <= state_stack[0];
	state_stack[2] <= state_stack[1];
	state_stack[3] <= state_stack[2];
	state <= dst;
end
endtask

task tRet;
begin
	state <= state_stack[0];
	state_stack[0] <= state_stack[1];
	state_stack[1] <= state_stack[2];
	state_stack[2] <= state_stack[3];
	state_stack[3] <= st_idle;
end
endtask

endmodule
