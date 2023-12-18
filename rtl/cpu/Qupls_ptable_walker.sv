// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2023  Robert Finch, Waterloo
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
// 1200 LUTs / 2720 FFs                                                                          
// ============================================================================

import fta_bus_pkg::*;
import QuplsMmupkg::*;
import QuplsPkg::*;

module Qupls_ptable_walker(rst, clk, 
	tlbmiss, tlb_missadr, tlb_missasid, tlb_missid, tlb_missqn,
	commit0_id, commit0_idv, commit1_id, commit1_idv, commit2_id, commit2_idv,
	commit3_id, commit3_idv,
	in_que, ftas_req, ftas_resp,
	ftam_req, ftam_resp, fault_o, faultq_o, tlb_wr, tlb_way, tlb_entryno, tlb_entry);
parameter CID = 6'd3;

parameter IO_ADDR = 32'hFFF40001;	//32'hFEFC0001;
parameter IO_ADDR_MASK = 32'h00FF0000;

parameter CFG_BUS = 8'd0;
parameter CFG_DEVICE = 5'd14;
parameter CFG_FUNC = 3'd0;
parameter CFG_VENDOR_ID	=	16'h0;
parameter CFG_DEVICE_ID	=	16'h0;
parameter CFG_SUBSYSTEM_VENDOR_ID	= 16'h0;
parameter CFG_SUBSYSTEM_ID = 16'h0;
parameter CFG_ROM_ADDR = 32'hFFFFFFF0;

parameter CFG_REVISION_ID = 8'd0;
parameter CFG_PROGIF = 8'd1;
parameter CFG_SUBCLASS = 8'h00;					// 00 = RAM
parameter CFG_CLASS = 8'h05;						// 05 = memory controller
parameter CFG_CACHE_LINE_SIZE = 8'd8;		// 32-bit units
parameter CFG_MIN_GRANT = 8'h00;
parameter CFG_MAX_LATENCY = 8'h00;
parameter CFG_IRQ_LINE = 8'd27;

localparam CFG_HEADER_TYPE = 8'h00;			// 00 = a general device

parameter MISSQ_SIZE = 8;

input rst;
input clk;
input tlbmiss;
input address_t tlb_missadr;
input asid_t tlb_missasid;
input rob_ndx_t tlb_missid;
input [1:0] tlb_missqn;
input rob_ndx_t commit0_id;
input commit0_idv;
input rob_ndx_t commit1_id;
input commit1_idv;
input rob_ndx_t commit2_id;
input commit2_idv;
input rob_ndx_t commit3_id;
input commit3_idv;
output reg in_que;
input fta_cmd_request128_t ftas_req;
output fta_cmd_response128_t ftas_resp;
output fta_cmd_request128_t ftam_req;
input fta_cmd_response128_t ftam_resp;
output [31:0] fault_o;
output reg [1:0] faultq_o;
output reg tlb_wr;
output reg tlb_way;
output reg [6:0] tlb_entryno;
output tlb_entry_t tlb_entry;

integer nn,n1,n2,n3,n4;

typedef enum logic [1:0] {
	IDLE = 2'd0,
	FAULT = 2'd1
} state_t;
state_t req_state;

typedef struct packed {
	logic v;					// valid
	logic [2:0] lvl;	// level begin processed
	logic o;					// out
	logic bc;					// 1=bus cycle complete
	logic [1:0] qn;
	rob_ndx_t id;
	asid_t asid;
	address_t adr;		// address to translate
	address_t tadr;		// temporary address
} miss_queue_t;

typedef struct packed {
	logic v;
	logic rdy;
	fta_tranid_t id;
	logic [3:0] stk;
	asid_t asid;
	address_t vadr;
	address_t padr;
	SHPTE pte;
	logic [127:0] dat;
} tran_buf_t;

ptbr_t ptbr;
pt_attr_t pt_attr;
wire sack;
reg [63:0] fault_adr;
asid_t fault_asid;
reg tlbmiss_ip;		// miss processing in progress.
reg fault;
reg upd_req;
tran_buf_t [15:0] tranbuf;
fta_tranid_t tid;
miss_queue_t [MISSQ_SIZE-1:0] miss_queue;
reg [31:0] miss_adr;
asid_t miss_asid;
reg wr1,wr2;
reg [63:0] stlb_adr;
reg [10:0] addrb;
reg cs_config, cs_hwtw;

reg way;
SHPTE pte;
reg tlbmiss_v;

fta_cmd_request128_t sreq;
fta_cmd_response128_t sresp;
wire irq_en;
wire cs_tw;
wire [127:0] cfg_out;

always_ff @(posedge clk)
	sreq <= ftas_req;
always_ff @(posedge clk)
begin
	ftas_resp <= sresp;
	ftas_resp.ack <= sack;
end

always_ff @(posedge clk)
	cs_config <= ftas_req.cyc && ftas_req.stb &&
		ftas_req.padr[31:28]==4'hD &&
		ftas_req.padr[27:20]==CFG_BUS &&
		ftas_req.padr[19:15]==CFG_DEVICE &&
		ftas_req.padr[14:12]==CFG_FUNC;

always_comb
	cs_hwtw <= cs_tw && sreq.cyc && sreq.stb;

vtdl #(.WID(1), .DEP(16)) urdyd1 (.clk(clk), .ce(1'b1), .a(4'd1), .d(cs_hwtw|cs_config), .q(sack));

pci128_config #(
	.CFG_BUS(CFG_BUS),
	.CFG_DEVICE(CFG_DEVICE),
	.CFG_FUNC(CFG_FUNC),
	.CFG_VENDOR_ID(CFG_VENDOR_ID),
	.CFG_DEVICE_ID(CFG_DEVICE_ID),
	.CFG_BAR0(IO_ADDR),
	.CFG_BAR0_MASK(IO_ADDR_MASK),
	.CFG_BAR1('d0),
	.CFG_BAR1_MASK('d0),
	.CFG_SUBSYSTEM_VENDOR_ID(CFG_SUBSYSTEM_VENDOR_ID),
	.CFG_SUBSYSTEM_ID(CFG_SUBSYSTEM_ID),
	.CFG_ROM_ADDR(CFG_ROM_ADDR),
	.CFG_REVISION_ID(CFG_REVISION_ID),
	.CFG_PROGIF(CFG_PROGIF),
	.CFG_SUBCLASS(CFG_SUBCLASS),
	.CFG_CLASS(CFG_CLASS),
	.CFG_CACHE_LINE_SIZE(CFG_CACHE_LINE_SIZE),
	.CFG_MIN_GRANT(CFG_MIN_GRANT),
	.CFG_MAX_LATENCY(CFG_MAX_LATENCY),
	.CFG_IRQ_LINE(CFG_IRQ_LINE)
)
upci
(
	.rst_i(rst),
	.clk_i(clk),
	.irq_i(fault & irq_en),
	.irq_o(fault_o),
	.cs_config_i(cs_config),
	.we_i(sreq.we),
	.sel_i(sreq.sel),
	.adr_i(sreq.padr),
	.dat_i(sreq.data1),
	.dat_o(cfg_out),
	.cs_bar0_o(cs_tw),
	.cs_bar1_o(),
	.cs_bar2_o(),
	.irq_en_o(irq_en)
);

always_ff @(posedge clk, posedge rst)
if (rst) begin
	ptbr <= 'd0;
	pt_attr <= 'd0;
end
else begin
	if (cs_hwtw && sreq.we)
		casez(sreq.padr[15:0])
		16'hFF20:	ptbr <= sreq.data1[63:0];
		16'hFF30: pt_attr <= sreq.data1[5:0];
		default:	;
		endcase
end

always_ff @(posedge clk, posedge rst)
if (rst) begin
	sresp <= 'd0;
end
else begin
	if (cs_config)
		sresp.dat <= cfg_out;
	else if (cs_hwtw) begin
		sresp.dat <= 'd0;
		casez(sreq.padr[15:0])
		16'hFF00:	sresp.dat[63: 0] <= fault_adr;
		16'hFF10:	sresp.dat[63:48] <= fault_asid;
		16'hFF20:	sresp.dat[63: 0] <= ptbr;
		16'hFF30:	sresp.dat <= pt_attr;
		default:	sresp.dat <= 'd0;
		endcase
	end
	else
		sresp.dat <= 'd0;
end

// Find out if the tlb miss is already in the miss queue.
always_comb
begin
	in_que = 1'b0;
	for (n1 = 0; n1 < MISSQ_SIZE; n1 = n1 + 1) begin
		if (miss_queue[n1].v) begin
			if (tlb_missasid==miss_queue[n1].asid && tlb_missadr==miss_queue[n1].adr)
				in_que = 1'b1;
		end
	end
end

// Find an empty queue entry.
integer empty_qe;
always_comb
begin
	empty_qe = -1;
	if (tlbmiss && !in_que) begin
		for (n2 = 0; n2 < MISSQ_SIZE; n2 = n2 + 1)
			if (~miss_queue[n2].v && empty_qe < 0)
				empty_qe = n2;
	end
end

// Select a miss queue entry to process.
integer sel_qe;
always_comb
begin
	sel_qe = -1;
	for (n3 = 0; n3 < MISSQ_SIZE; n3 = n3 + 1)
		if (miss_queue[n3].v && miss_queue[n3].bc && sel_qe < 0 &&
			(miss_queue[n3].id==commit0_id && commit0_idv) ||
			(miss_queue[n3].id==commit1_id && commit1_idv) ||
			(miss_queue[n3].id==commit2_id && commit2_idv) ||
			(miss_queue[n3].id==commit3_id && commit3_idv)
		)	
			sel_qe = n3;
end

integer sel_tran;
always_comb
begin
	sel_tran = -1;
	for (n4 = 0; n4 < 16; n4 = n4 + 1)
		if (tranbuf[n4].rdy)
			sel_tran = n4;
end

// Computer page index for a given page level.
reg [12:0] pindex;
always_comb
	pindex = miss_queue[tranbuf[sel_tran].stk].adr[31:16] >> (miss_queue[tranbuf[sel_tran].stk].lvl * 13);

always_ff @(posedge clk)
if (rst) begin
	tlbmiss_ip <= 'd0;
	ftam_req <= 'd0;
	ftam_req.cid <= CID;
	ftam_req.bte <= fta_bus_pkg::LINEAR;
	ftam_req.cti <= fta_bus_pkg::CLASSIC;
	tid <= 8'd1;
	upd_req <= 'd0;
	for (nn = 0; nn < MISSQ_SIZE; nn = nn + 1)
		miss_queue[nn] <= 'd0;
	way <= 'd0;
	tlb_wr <= 1'b0;
	tlb_way <= 1'b0;
end
else begin

	tlb_wr <= 1'b0;
	way <= ~way;

	// Capture miss
	if (empty_qe >= 0) begin
		if (!in_que) begin
			miss_queue[empty_qe].v <= 1'b1;
			miss_queue[empty_qe].o <= 1'b0;
			miss_queue[empty_qe].bc <= 1'b1;
			miss_queue[empty_qe].lvl <= ptbr.level;
			miss_queue[empty_qe].asid <= tlb_missasid;
			miss_queue[empty_qe].id <= tlb_missid;
			miss_queue[empty_qe].adr <= tlb_missadr;
			miss_queue[empty_qe].qn <= tlb_missqn;
			
			case(ptbr.level)
			3'd0:	miss_queue[empty_qe].tadr <= {ptbr.adr,3'd0} + {tlb_missadr[28:16],3'h0};
			3'd1:	miss_queue[empty_qe].tadr <= {ptbr.adr,3'd0} + {tlb_missadr[31:29],3'h0};
			default:	miss_queue[empty_qe].tadr <= 'd0;
			endcase
		end
	end

	case(req_state)
	IDLE:
		begin
			// Check for update to TLB.
			// Update the TLB by writing TLB registers with the translation.
			// Advance to the next miss.
			if (upd_req) begin
				upd_req <= 'd0;
				tlb_wr <= 1'b1;
				tlb_way <= way;
				tlb_entryno <= miss_adr[22:16];
				tlb_entry.pte <= pte;
				tlb_entry.vpn.vpn <= miss_adr[31:23];
				tlb_entry.vpn.asid <= miss_asid;
			end
			// Run a bus cycle.
			if (sel_qe >= 0) begin
				miss_queue[sel_qe].bc <= 1'b0;
				miss_queue[sel_qe].o <= 1'b1;
				miss_queue[sel_qe].lvl <= miss_queue[sel_qe].lvl - 1;
				ftam_req <= 'd0;		// clear all fields.
				ftam_req.cyc <= 1'b1;
				ftam_req.stb <= 1'b1;
				ftam_req.we <= 1'b0;
				ftam_req.sel <= 64'h0FF << {miss_queue[sel_qe].tadr[5:3],3'b0};
				ftam_req.asid <= miss_queue[sel_qe].asid;
				ftam_req.vadr <= {miss_queue[sel_qe].tadr[31:3],3'b0};
				ftam_req.tid <= tid;
				ftam_req.cid <= CID;
				// Record outstanding transaction.
				tranbuf[tid & 15].v <= 1'b1;
				tranbuf[tid & 15].rdy <= 1'b0;
				tranbuf[tid & 15].asid <= miss_queue[sel_qe].asid;
				tranbuf[tid & 15].vadr <= {miss_queue[sel_qe].tadr[31:3],3'b0};
				tranbuf[tid & 15].stk <= sel_qe;
				tid <= tid + 2'd1;
				if (&tid)
					tid <= 8'd1;
			end
		end
		// Remain in fault state until cleared by accessing the table-walker register.
	FAULT:
		begin
			fault <= 'd0;
			if (cs_hwtw && sreq.padr[15:0]==16'hFF00) begin
				tlbmiss_ip <= 'd0;
				req_state <= IDLE;		
			end
		end
	default:
		req_state <= IDLE;	
	endcase

	// Capture responses.
	if (ftam_resp.ack) begin
		tranbuf[ftam_resp.tid & 15].dat <= ftam_resp.dat;
		tranbuf[ftam_resp.tid & 15].pte <= ftam_resp.dat[63:0];
		tranbuf[ftam_resp.tid & 15].padr <= ftam_resp.adr;
		tranbuf[ftam_resp.tid & 15].rdy <= 1'b1;
	end

	// Search for ready translations and update the TLB.
	if (sel_tran >= 0) begin
		miss_queue[tranbuf[sel_tran].stk].bc <= 1'b1;
		// We're done if level zero processed.
		if (miss_queue[tranbuf[sel_tran].stk].lvl==3'd0) begin
			// Allow capture of new TLB misses.
			miss_queue[tranbuf[sel_tran].stk].v <= 1'b0;
			miss_queue[tranbuf[sel_tran].stk].o <= 1'b0;
		end
		tranbuf[sel_tran].v <= 1'b0;
		tranbuf[sel_tran].rdy <= 1'b0;
		miss_asid <= miss_queue[tranbuf[sel_tran].stk].asid;
		miss_adr <= miss_queue[tranbuf[sel_tran].stk].adr;
		miss_queue[tranbuf[sel_tran].stk].tadr <= {tranbuf[sel_tran].pte.ppn,pindex,3'b0};
		pte <= tranbuf[sel_tran].pte;
		// If translation is not valid, cause a page fault.
		if (~tranbuf[sel_tran].pte.v) begin
			faultq_o <= miss_queue[tranbuf[sel_tran].stk].qn;
			fault <= 1'b1;
			fault_asid <= tranbuf[sel_tran].asid;
			fault_adr <= tranbuf[sel_tran].vadr;
			req_state <= FAULT;
		end
		// Otherwise translation was valid, update it in the TLB.
		else if (miss_queue[tranbuf[sel_tran].stk].lvl==3'd0)
			upd_req <= 1'b1;
	end
end

endmodule
