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
// 1100 LUTs / 780 FFs / 8 BRAMs / 150 MHz
// ============================================================================

import cpu_types_pkg::*;

module page_table_walker (rst, clk, g_paging_en, cs_tlb, tlb_base_adr, sbus, mbus,
	store, vadr, vadr_v, asid, padr, padr_v, page_fault);
parameter TLB_ENTRIES = 512;
parameter LOG_PAGESIZE = 13;
parameter TLB_ASSOC = 4;
localparam TLB_ABITS=$clog2(TLB_ENTRIES);
input rst;
input clk;
input g_paging_en;
input cs_tlb;
input address_t tlb_base_adr;
wb_bus_interface.slave sbus;
wb_bus_interface.master mbus;
input store;
input address_t vadr;
input vadr_v;
input asid_t asid;
output address_t padr;
output padr_v;
output reg page_fault;

typedef enum logic [5:0]
{
	st_idle = 0,
	st_read_lev1,
	st_read_lev1_2,
	st_read_lev1_3,
	st_read_lev2,
	st_read_lev2_2,
	st_read_lev2_3,
	st_readwrite_pte,
	st_readwrite_pte2,
	st_read_tlb,
	st_read_tlb2,
	st_read_tlb3,
	st_read_tlb4,
	st_read_tlb5,
	st_store_pte,
	st_store_pte2,
	st_store_pte3,
	st_update_tlb,
	st_update_tlb2,
	st_update_tlb3,
	st_update_tlb4
} state_t;
state_t state;

reg paging_en;
reg ics_tlb;
reg missack;
reg [15:0] pt_index,next_pt_index;
address_t miss_adr1;
address_t pt_adr;
pte_t pte;
address_t pte_adr;
tlb_entry_t tlbe,tlbe_tmp;
address_t pt_start_adr;
reg [2:0] pt_start_level;
reg [2:0] level;
wb_bus_interface #(.DATA_WIDTH(64)) tlb_bus();
address_t miss_adr;
asid_t miss_asid;
wire [26:0] lfsro;
reg [1:0] way;
reg [5:0] iv_count;
reg [2:0] fndLevel1;

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
	fndLevel1 = fnFindLevel1(pt_adr + pt_index);

assign tlb_bus.rst = rst;
assign tlb_bus.clk = clk;

lfsr27 #(.WID(27)) ulfsr1(rst, clk, 1'b1, 1'b0, lfsro);

tlb
#(
	.TLB_ENTRIES(TLB_ENTRIES),
	.TLB_ASSOC(TLB_ASSOC),
	.LOG_PAGESIZE(LOG_PAGESIZE)
)
utlb1
(
	.clk(clk),
	.bus(tlb_bus),
	.stall(1'b0),
	.paging_en(paging_en),
	.cs_tlb(cs_tlb),
	.iv_count(iv_count),
	.store_i(store),
	.id(id),
	.asid(asid),
	.vadr(vadr),
	.vadr_v(vadr_v),
	.padr(padr),
	.padr_v(padr_v),
	.tlb_v(tlb_v),
	.missack(missack),
	.miss_adr_o(miss_adr),
	.miss_asid_o(miss_asid),
	.miss_id_o(miss_id_o),
	.miss_o(miss_o)
);

always_comb
	pt_index = (((miss_adr >> (LOG_PAGESIZE * level)) % TLB_ENTRIES) << 4'h3);
always_comb
	next_pt_index = (((miss_adr >> (LOG_PAGESIZE * (level-1))) % TLB_ENTRIES) << 4'h3);
always_comb
	pte = mbus.resp.dat;

always_ff @(posedge clk)
if (rst) begin
	mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
	tlb_bus.req <= {$bits(wb_cmd_request64_t){1'b0}}; 
	missack <= FALSE;
	state <= st_idle;
	paging_en <= TRUE;
	level1[0] <= {$bits(pte_adr_t){1'b0}};
	level1[1] <= {$bits(pte_adr_t){1'b0}};
	level1[2] <= {$bits(pte_adr_t){1'b0}};
	level1[3] <= {$bits(pte_adr_t){1'b0}};
	level2 <= {$bits(pte_adr_t){1'b0}};
end
else begin
	missack <= FALSE;

	case (state)

	// Wait for a miss, then walk.
	st_idle:
		if (miss_o) begin
			pt_adr <= pt_start_adr;
			level <= pt_start_level;
			miss_adr1 <= miss_adr;
			missack <= TRUE;
			case(pt_start_level)
			1:	state <= st_read_lev1;
			2:	state <= st_read_lev2;
//			3:	state <= st_read_lev3;
			// ToDo implement other levels
			default:	;
			endcase
		end
		else if (cs_tlb & sbus.req.cyc & sbus.req.stb) begin
			paging_en <= FALSE;
			ics_tlb <= HIGH;
			tlb_bus.req.cyc <= HIGH;
			tlb_bus.req.stb <= HIGH;
			tlb_bus.req.we <= sbus.req.we;
			tlb_bus.req.sel <= 8'hFF;
			tlb_bus.req.adr <= tlb_base_adr + {sbus.req.adr[15:3],3'b0};
			tlb_bus.req.dat <= sbus.req.dat >> {sbus.req.adr[4:3],6'b0};
			state <= st_readwrite_pte;
		end
	st_readwrite_pte:
		if (tlb_bus.resp.ack || (!(cs_tlb & sbus.req.cyc & sbus.req.stb))) begin
			ics_tlb <= LOW;
			paging_en <= TRUE;
			tlb_bus.req <= {$bits(wb_cmd_request64_t){1'b0}}; 
			sbus.resp.tid <= sbus.req.tid;
			sbus.resp.dat <= {4{tlb_bus.resp.dat}};
			sbus.resp.ack <= sbus.req.cyc & sbus.req.stb;
			sbus.resp.err <= wishbone_pkg::OKAY;
			state <= st_readwrite_pte2;
		end
	st_readwrite_pte2:
		if (!(cs_tlb && sbus.req.cyc & sbus.req.stb))
			state <= st_idle;

	// Read lowest level page table.
	st_read_lev1:
		begin
			if (fndLevel1[2] && level1[fndLevel1[1:0]].pte.v) begin
				pt_adr <= (level1[fndLevel1[1:0]].pte.ppn << LOG_PAGESIZE) + next_pt_index;
				tlbe <= {$bits(tlb_entry_t){1'b0}};
				tlbe.pte <= level1[fndLevel1[1:0]].pte;
				tlbe.pte.a <= TRUE;
				tlbe.pte.m <= FALSE;
				tlbe.vpn.vpn <= miss_adr >> (LOG_PAGESIZE + TLB_ABITS);
				tlbe.vpn.asid <= miss_asid;
				tlbe.count <= iv_count;
				state <= st_read_tlb;
			end
			else begin
				mbus.req.cyc <= HIGH;
				mbus.req.stb <= HIGH;
				mbus.req.sel <= 32'hFF << {pt_index[4:3],3'h0};
				mbus.req.adr <= pt_adr + pt_index;
				pte_adr <= pt_adr + pt_index;
				state <= st_read_lev1_2;
			end
			level <= 3'd0;
		end
	st_read_lev1_2:
		if (mbus.resp.ack) begin
			mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
			if (pte.v) begin
				tlbe <= {$bits(tlb_entry_t){1'b0}};
				tlbe.pte <= pte;
				tlbe.pte.a <= TRUE;
				tlbe.pte.m <= FALSE;
				tlbe.vpn.vpn <= miss_adr >> (LOG_PAGESIZE + TLB_ABITS);
				tlbe.vpn.asid <= miss_asid;
				tlbe.count <= iv_count;
				// Cache lookup
				level1[3].pte <= pte;
				level1[3].pte.a <= TRUE;
				level1[3].pte.m <= FALSE;
				level1[3].adr <= pte_adr;
				level1[2] <= level1[3];
				level1[1] <= level1[2];
				level1[0] <= level1[1];
				state <= st_read_tlb;
			end
			else begin
				page_fault <= TRUE;
				state <= st_read_lev1_3;
			end
		end
	st_read_lev1_3:
		state <= st_idle;

	// Read level 2 of the page tables.
	st_read_lev2:
		begin
			if (level2.adr==pt_adr + pt_index && level2.pte.v) begin
				pt_adr <= (level2.pte.ppn << LOG_PAGESIZE) + next_pt_index;
				state <= st_read_lev1;
			end
			else begin
				mbus.req.cyc <= HIGH;
				mbus.req.stb <= HIGH;
				mbus.req.sel <= 32'hFF << {pt_index[4:3],3'h0};
				mbus.req.adr <= pt_adr + pt_index;
				state <= st_read_lev2_2;
			end
			level <= level - 2'd1;
		end
	st_read_lev2_2:
		if (mbus.resp.ack) begin
			mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
			if (pte.v) begin
				// Cache lookup
				level2.pte <= pte;
				level2.pte.a <= TRUE;
				level2.pte.m <= FALSE;
				level2.adr <= pte_adr;
				pt_adr <= (pte.ppn << LOG_PAGESIZE) + pt_index;
				state <= st_read_lev2_3;
			end
			else begin
				page_fault <= TRUE;
				state <= st_idle;
			end
		end
	st_read_lev2_3:
		state <= st_read_lev1;

	// Read the TLB to see if the entry being overwritten should be copied to
	// memory first.
	st_read_tlb:
		begin
			ics_tlb <= HIGH;
			tlb_bus.req.cyc <= HIGH;
			tlb_bus.req.stb <= HIGH;
			tlb_bus.req.we <= LOW;
			tlb_bus.req.sel <= 8'hFF;
			tlb_bus.req.adr <= (((miss_adr >> LOG_PAGESIZE) % TLB_ENTRIES) << 4'd4) + tlb_base_adr;
			way <= lfsro[1:0];
			state <= st_read_tlb2;
		end
	st_read_tlb2:
		if (tlb_bus.resp.ack) begin
			tlbe_tmp[63:0] <= tlb_bus.resp.dat;
			ics_tlb <= LOW;
			tlb_bus.req <= {$bits(wb_cmd_request64_t){1'b0}}; 
			state <= st_read_tlb3;
		end
	st_update_tlb3:
		begin
			ics_tlb <= HIGH;
			tlb_bus.req.cyc <= HIGH;
			tlb_bus.req.stb <= HIGH;
			tlb_bus.req.we <= LOW;
			tlb_bus.req.sel <= 8'hFF;
			tlb_bus.req.adr <= (((miss_adr >> LOG_PAGESIZE) % TLB_ENTRIES) << 4'd4) + tlb_base_adr + 4'h8;
			state <= st_read_tlb4;
		end
	st_read_tlb4:
		if (tlb_bus.resp.ack) begin
			tlbe_tmp[127:64] <= tlb_bus.resp.dat;
			ics_tlb <= LOW;
			tlb_bus.req <= {$bits(wb_cmd_request64_t){1'b0}}; 
			state <= st_read_tlb5;
		end
	st_read_tlb5:
		begin
			// Was there valid data in the PTE? If not, no need to store.
			if (tlbe.pte.v)
				state <= st_store_pte;
			else
				state <= st_update_tlb;
		end

	// Store PTE to memory.
	// The modified / accessed bits may have been set.
	st_store_pte:
		begin
			mbus.req.cyc <= HIGH;
			mbus.req.stb <= HIGH;
			mbus.req.we <= HIGH;
			mbus.req.sel <= 32'hFF << {pte_adr[4:3],3'b0};
			mbus.req.adr <= pte_adr;
			mbus.req.dat <= {4{tlbe_tmp.pte}};
			state <= st_store_pte2;
		end
	st_store_pte2:
		if (mbus.resp.ack) begin
			mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
			state <= st_store_pte3;
		end
	st_store_pte3:
		state <= st_update_tlb;

	// Write the TLB entry to the TLB
	st_update_tlb:
		begin
			paging_en <= FALSE;
			ics_tlb <= HIGH;
			tlb_bus.req.cyc <= HIGH;
			tlb_bus.req.stb <= HIGH;
			tlb_bus.req.we <= HIGH;
			tlb_bus.req.sel <= 8'hFF;
			tlb_bus.req.adr <= (((miss_adr >> LOG_PAGESIZE) % TLB_ENTRIES) << 4'd4) + tlb_base_adr;
			tlb_bus.req.dat <= tlbe[63:0];
			state <= st_update_tlb2;
		end
	st_update_tlb2:
		if (tlb_bus.resp.ack) begin
			ics_tlb <= LOW;
			tlb_bus.req <= {$bits(wb_cmd_request64_t){1'b0}}; 
			state <= st_update_tlb3;
		end
	st_update_tlb3:
		begin
			ics_tlb <= HIGH;
			tlb_bus.req.cyc <= HIGH;
			tlb_bus.req.stb <= HIGH;
			tlb_bus.req.we <= HIGH;
			tlb_bus.req.sel <= 8'hFF;
			tlb_bus.req.adr <= (((miss_adr >> LOG_PAGESIZE) % TLB_ENTRIES) << 4'd4) + tlb_base_adr + 4'h8;
			tlb_bus.req.dat <= tlbe[127:64];
			state <= st_update_tlb4;
		end
	st_update_tlb4:
		if (tlb_bus.resp.ack) begin
			ics_tlb <= LOW;
			paging_en <= g_paging_en;
			tlb_bus.req <= {$bits(wb_cmd_request64_t){1'b0}}; 
			state <= st_idle;
		end

	default:   state <= st_idle;
	endcase
end

endmodule
