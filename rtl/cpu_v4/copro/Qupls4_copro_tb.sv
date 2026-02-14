`timescale 1ns / 1ps
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
//    contributors may be used to endorse or pnext_irte products derived from
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

import cpu_types_pkg::*;
import wishbone_pkg::*;

module Qupls4_copro_tb();
parameter LOG_PAGESIZE = 13;
parameter LOG_TLB_ENTRIES = 9;
reg rst;
reg clk;
reg vclk;
integer state;

integer n1;
integer count;
wb_bus_interface #(.DATA_WIDTH(64)) bus();
wb_bus_interface #(.DATA_WIDTH(64)) sbus();
wb_bus_interface #(.DATA_WIDTH(256)) mbus();
wb_bus_interface #(.DATA_WIDTH(256)) vmbus();
asid_t asid = 16'h0000;
reg [7:0] id = 8'h00;
address_t vadr;
reg vadr_v;
reg store;
address_t [2:0] padr;
wire [2:0] padr_v;
wire [2:0] tlb_v;
wire missack;
wire idle;
reg cs_tlb;
reg [3:0] iv_count [0:2];
wire [2:0] miss;
address_t [2:0] miss_adr;
asid_t [2:0] miss_asid;
wire [7:0] miss_id [0:2];
wire paging_en;
wire page_fault;
wire rst_busy;
reg hsync = 1'b0;
reg vsync = 1'b0;
reg gfx_que_empty = 1'b1;

pte_t test_pte;

reg [255:0] mem [0:8191];
initial begin
	test_pte = {$bits(pte_t){1'b0}};
	test_pte.v = VAL;
	test_pte.u = $urandom() & 1;
	test_pte.rwx = $urandom() & 7;
	test_pte.ppn = 32'h21000 >> 13;
	mem[0] = {8{test_pte}};
	for (n1 = 0; n1 < $size(mem); n1 = n1 + 1)
		mem[n1] = {8{$urandom()|32'h80000000}};
	foreach (iv_count[n1])
		iv_count[n1] = 4'h0;
end


initial begin
	rst = 0;
	clk = 0;
	vclk = 0;
	#1 rst = 1;
	#100 rst = 0;
end

always
	#5 clk = ~clk;
always
	#12.5 vclk = ~vclk;

assign bus.rst = rst;
assign bus.clk = clk;
assign sbus.rst = rst;
assign sbus.clk = clk;
assign mbus.rst = rst;
assign mbus.clk = clk;
assign bus.req.cyc = mbus.req.cyc;
assign bus.req.stb = mbus.req.stb;
assign bus.req.we = mbus.req.we;
assign bus.req.sel = mbus.req.sel >> {mbus.req.adr[4:3],3'b0};
assign bus.req.adr = mbus.req.adr;
assign bus.req.dat = mbus.req.dat >> {mbus.req.adr[4:3],6'b0};
//assign mbus.resp.ack = bus.resp.ack;
//assign mbus.resp.dat = {4{bus.resp.dat}};

always_comb
	cs_tlb = mbus.req.cyc & mbus.req.stb & mbus.req.adr[31:16]==16'hFFF4;

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
	.padr(padr[0]),
	.padr_v(padr_v[0]),
	.tlb_v(tlb_v[0]),
	.missack(missack),
	.miss_adr_o(miss_adr[0]),
	.miss_asid_o(miss_asid[0]),
	.miss_id_o(miss_id[0]),
	.miss_o(miss[0]),
	.rst_busy(rst_busy)
);

Qupls4_copro
#(
	.LOG_PAGESIZE(LOG_PAGESIZE),
	.LOG_TLB_ENTRIES(LOG_TLB_ENTRIES)
)
ucopro1
(
	.rst(rst),
	.clk(clk),
	.sbus(sbus),
	.mbus(mbus),
	.cs_copro(1'b0),
	.miss(miss),
	.miss_adr(miss_adr),
	.miss_asid(miss_asid),
	.missack(missack),
	.idle(idle),
  .paging_en(paging_en),
  .page_fault(page_fault),
  .iv_count(iv_count),
  .vclk(vclk),
  .hsync_i(hsync),
  .vsync_i(vsync),
  .gfx_que_empty_i(gfx_que_empty)
);

always_ff @(posedge clk)
if (rst) begin
	state <= 1;
	count <= 0;
end
else begin
	case(state)
	1:
		begin
			vadr <= 32'h12340000;
			vadr_v <= VAL;
			store <= FALSE;
			state <= 2;
		end
	2:
		begin
			if (tlb_v[0]) begin
				vadr_v <= FALSE;
			end
			count <= count + 1;
			if (count > 200) begin
				count <= 0;
				state <= 3;
				vadr <= 32'h8887654;
				vadr_v <= VAL;
				store <= FALSE;
			end
		end
	3:
		begin
			count <= 0;
			vadr[12:0] <= $urandom();
			state <= 4;
		end
	4:
		begin
			count <= count + 1;
			if (count > 0) begin
				if (tlb_v[0])
					state <= 3;
				else begin
					if (!miss[0]) begin
						if (paging_en)
							$finish;
					end
					else
						state <= 5;
					count <= 0;
				end
			end
		end
	5:
		begin
			count <= count + 1;
			if (count > ($urandom() % 200) + 50) begin
				state <= 3;
			end
		end
	default:	state <= 1;
	endcase
end

reg [7:0] mbus_state;
always_ff @(posedge clk)
if (rst|rst_busy) begin
	mbus_state <= 0;
end
else begin
	case(mbus_state)
	0:
		if (mbus.req.cyc & mbus.req.stb) begin
			if (mbus.req.we)
				mem[mbus.req.adr[17:5]] <= {4{mbus.req.dat}};
			else
				mbus.resp.dat <= mem[mbus.req.adr[17:5]];
			mbus.resp.ack <= HIGH;
			mbus_state <= 1;
		end
	1:
		if (!(mbus.req.cyc & mbus.req.stb)) begin
			mbus.resp.ack <= LOW;
			mbus_state <= 0;
		end
	default:	mbus_state <= 0;
	endcase
end


endmodule
