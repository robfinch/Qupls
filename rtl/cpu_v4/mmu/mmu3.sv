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
// FOR ANY DIRECT, INDIRECT, INCHANNELENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// 5110 LUTs / 6300 FFs / 28 BRAMs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import mmu_pkg::*;
import wishbone_pkg::*;

module mmu3 (rst, clk, sw, btnu, btnd, btnl, btnr, btnc,
	g_paging_en, nsc_tlb_base_adr, sc_tlb_base_adr,
	sc_flush_en, nsc_flush_en, sc_flush_done, nsc_flush_done, pt_attr, ptbr,
	cs_sc_tlb, cs_nsc_tlb, cs_rgn, store, region_dat, cpl, om,
	sbus, mbus, vadr, vadr_v, asid, iv_count, clear_fault,
	padr, padr_v, tlb_v, page_fault, all_ways_locked, priv_err,
	vclk, hsync, vsync, border, blank,
	aud0_out, aud1_out, aud2_out, aud3_out, aud_in, vid_out, de,
	rst_busy);
parameter SHORTCUT = 0;
parameter TLB_ENTRIES = 512;
parameter LOG_TLB_ENTRIES = 9;
parameter TLB_ASSOC = 4;
parameter LOG_PAGESIZE = 13;
parameter TLB2_ENTRIES = 128;
parameter TLB2_ASSOC = 2;
parameter LOG_PAGESIZE2 = 23;
input rst;
input clk;
input [7:0] sw;
input btnu;
input btnd;
input btnl;
input btnr;
input btnc;
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
input vclk;
input hsync;
input vsync;
input border;
input blank;
output [15:0] aud0_out;
output [15:0] aud1_out;
output [15:0] aud2_out;
output [15:0] aud3_out;
input [15:0] aud_in;
output [23:0] vid_out;
output de;
input rst_busy;

tlb_entry_t tlb_entry;
mmu_pkg::region_t region;
wb_cmd_request256_t sreqd;
wire [7:0] rgn_sel;
wire [2:0] grant;
wire idle;
wire [2:0] miss;
address_t [2:0] miss_adr;
asid_t [2:0] miss_asid;
wire [7:0] miss_id [0:2];
wire missack;
address_t [2:0] padr1;
wire [2:0] padr1_v;
wire [3:0] iv_count1 [0:2];

wire flush_en;
reg [63:0] flags;
wire paging_en;
wire flush_trig;
asid_t flush_asid;
wire flush_done;
reg flags_ack;

reg [63:0] flags_dat;
wb_bus_interface #(.DATA_WIDTH(64)) imbus();
wb_bus_interface #(.DATA_WIDTH(64)) bus();
assign iv_count1[0] = iv_count;

assign bus.rst = mbus.rst;
assign bus.clk = mbus.clk;

assign imbus.rst = mbus.rst;
assign imbus.clk = mbus.clk;
assign imbus.req = mbus.req;
always_comb
	if (flags_ack) begin
		mbus.resp.tid = imbus.req.tid;
		mbus.resp.ack = TRUE;
		mbus.resp.dat = flags_dat;
	end
	else begin
		mbus.resp.tid = imbus.req.tid;
		mbus.resp.ack = imbus.resp.ack;
		mbus.resp.dat = imbus.resp.dat;
	end

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

tlb
#(
	.LOG_PAGESIZE(LOG_PAGESIZE),
	.LOG_TLB_ENTRIES(LOG_TLB_ENTRIES)
)
utlb1
(
	.clk(clk),
	.bus(bus),
	.idle(idle),
	.stall(1'b0),
	.paging_en(paging_en),
	.cs_tlb(cs_tlb),
	.iv_count(iv_count[0]),
	.store_i(store),
	.id(id),
	.asid(asid),
	.vadr(vadr),
	.vadr_v(vadr_v),
	.padr(padr),
	.padr_v(padr_v),
	.tlb_v(tlb_v),
	.missack(missack),
	.miss_adr_o(miss_adr[0]),
	.miss_asid_o(miss_asid[0]),
	.miss_id_o(miss_id[0]),
	.miss_o(miss[0]),
	.rst_busy(rst_busy),
	.flush_en(flush_en),
	.flush_trig(flush_trig),
	.flush_asid(flush_asid),
	.flush_done(flush_done)
);
assign miss[1] = 1'b0;
assign miss[2] = 1'b0;

always_ff @(posedge clk)
if (rst) begin
	flags <= 64'd0;
	flags_ack <= FALSE;
	flush_asid <= 16'h0;
end
else begin
	if (imbus.req.cyc && imbus.req.stb && imbus.req.adr[31:16]==16'hF800) begin
		if (imbus.req.we)
			casez(imbus.req.adr[15:0])
			16'b00000000_00??????:	flags[imbus.req.adr[5:0]] <= imbus.req.dat >> {imbus.req.adr[4:3],6'd0};
			16'b00000000_01000???:	flush_asid <= imbus.req.dat >> {imbus.req.adr[4:3],6'd0};
			default:	;
			endcase
		casez(imbus.req.adr[15:0])
		16'b00000000_01001???:	flags_dat <= {4{flush_done,63'd0}};
		default:	flags_dat <= 256'd0;
		endcase
		flags_ack <= TRUE;
	end
	else begin
		flags_ack <= FALSE;
	end
end

Qupls4_copro2
#(
	.LOG_PAGESIZE(LOG_PAGESIZE),
	.LOG_TLB_ENTRIES(LOG_TLB_ENTRIES)
)
ucopro1
(
	.rst(rst),
	.clk(clk),
	.btnu(btnu),
	.btnd(btnd),
	.btnl(btnl),
	.btnr(btnr),
	.btnc(btnc),
	.sw(sw),
	.sbus(sbus),
	.mbus(imbus),
	.cs_copro(),
	.miss(miss),
	.miss_adr(miss_adr),
	.miss_asid(miss_asid),
  .missack(missack),
  .paging_en(paging_en),
  .page_fault(page_fault),
  .iv_count(iv_count1),
  .idle(idle),
  .vclk(vclk),
  .hsync_i(hsync),
  .vsync_i(vsync),
  .border_i(border),
  .blank_i(blank),
  .gfx_que_empty_i(),
  .flush_en(flush_en),
  .flush_trig(flush_trig),
  .flush_asid(flush_asid),
  .aud0_out(aud0_out),
  .aud1_out(aud1_out),
  .aud2_out(aud2_out),
  .aud3_out(aud3_out),
  .aud_in(aud_in),
  .vid_out(vid_out),
  .de(de)
);

endmodule
