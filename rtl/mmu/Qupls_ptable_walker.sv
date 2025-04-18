// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2024  Robert Finch, Waterloo
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

import const_pkg::*;
import fta_bus_pkg::*;
import QuplsMmupkg::*;
import QuplsPkg::*;
import Qupls_ptable_walker_pkg::*;

module Qupls_ptable_walker(rst, clk, paging_en,
	tlbmiss, tlb_missadr, tlb_missasid, tlb_missid, tlb_missqn,
	commit0_id, commit0_idv, commit1_id, commit1_idv, commit2_id, commit2_idv,
	commit3_id, commit3_idv,
	in_que, ftas_req, ftas_resp,
	ftam_req, ftam_resp, fault_o, faultq_o, pe_fault_o,
	tlb_wr, tlb_way, tlb_entryno, tlb_entry,
	ptw_vadr, ptw_vv, ptw_padr, ptw_pv);
parameter CORENO = 6'd1;
parameter CID = 3'd3;
parameter WAYS = 4;

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

input rst;
input clk;
input paging_en;
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
output reg pe_fault_o;
output reg tlb_wr;
output reg [WAYS-1:0] tlb_way;
output reg [6:0] tlb_entryno;
output tlb_entry_t tlb_entry;
output virtual_address_t ptw_vadr;
output reg ptw_vv;
input physical_address_t ptw_padr;
input ptw_pv;

ptw_state_t req_state;
ptbr_t ptbr;
pt_attr_t pt_attr;
wire sack;
reg [63:0] fault_adr;
asid_t fault_asid;
reg tlbmiss_ip;		// miss processing in progress.
reg fault;
reg upd_req;
ptw_tran_buf_t [15:0] tranbuf;
fta_tranid_t tid;
ptw_miss_queue_t [MISSQ_SIZE-1:0] miss_queue;
reg [31:0] miss_adr;
asid_t miss_asid;
reg [63:0] stlb_adr;
reg cs_config, cs_hwtw;
reg ptw_ppv;
reg [5:0] sel_tran;
wire [5:0] sel_qe;

reg [WAYS-1:0] way;
spte_t pte;

integer nn,n4;
fta_cmd_request128_t sreq;
fta_cmd_response128_t sresp;
wire irq_en;
wire cs_tw;
wire [127:0] cfg_out;
reg erc;

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
always_comb
	erc <= sreq.cti==fta_bus_pkg::ERC;

vtdl #(.WID(1), .DEP(16)) urdyd1 (.clk(clk), .ce(1'b1), .a(4'd1),
	.d(sreq.we?(erc?cs_hwtw|cs_config : 1'b0): cs_hwtw|cs_config), .q(sack));

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

always_ff @(posedge clk)
if (rst) begin
	ptbr <= 64'hFFFFFFFFFFF80000;
	pt_attr <= 64'h1FFF081;
end
else begin
	if (cs_hwtw && sreq.we)
		casez(sreq.padr[15:0])
		16'hFF20:	
			begin
				ptbr <= sreq.data1[63:0];
				$display("Q+ PTW: PTBR=%h",sreq.data1[63:0]);
			end
		16'hFF30: pt_attr <= sreq.data1[5:0];
		default:	;
		endcase
end

always_ff @(posedge clk)
if (rst) begin
	sresp <= 'd0;
end
else begin
	sresp.dat <= 128'd0;
	sresp.tid <= sreq.tid;
	sresp.pri <= sreq.pri;
	if (cs_config)
		sresp.dat <= cfg_out;
	else if (cs_hwtw) begin
		sresp.dat <= 128'd0;
		casez(sreq.padr[15:0])
		16'hFF00:	sresp.dat[63: 0] <= fault_adr;
		16'hFF10:	sresp.dat[63:48] <= fault_asid;
		16'hFF20:	sresp.dat[63: 0] <= ptbr;
		16'hFF30:	sresp.dat <= pt_attr;
		default:	sresp.dat <= 128'd0;
		endcase
	end
	else
		sresp.dat <= 128'd0;
end

always_comb
begin
	sel_tran = 6'h3f;
	for (n4 = 0; n4 < 16; n4 = n4 + 1)
		if (tranbuf[n4].rdy)
			sel_tran = n4;
end

Qupls_ptw_miss_queue umsq1
(
	.rst(rst),
	.clk(clk),
	.state(req_state),
	.ptbr(ptbr),
	.commit0_id(commit0_id),
	.commit0_idv(commit0_idv),
	.commit1_id(commit1_id),
	.commit1_idv(commit1_idv),
	.commit2_id(commit2_id),
	.commit2_idv(commit2_idv),
	.commit3_id(commit3_id),
	.commit3_idv(commit3_idv),
	.tlb_miss(tlbmiss & paging_en),
	.tlb_missadr(tlb_missadr),
	.tlb_missasid(tlb_missasid),
	.tlb_missid(tlb_missid),
	.tlb_missqn(tlb_missqn),
	.in_que(in_que),
	.ptw_vv(ptw_vv),
	.ptw_pv(ptw_pv),
	.ptw_ppv(ptw_ppv),
	.tranbuf(tranbuf),
	.miss_queue(miss_queue),
	.sel_tran(sel_tran),
	.sel_qe(sel_qe)
);

Qupls_ptw_tran_buffer utrbf1
(
	.rst(rst),
	.clk(clk),
	.state(req_state),
	.ptw_pv(ptw_pv),
	.ptw_ppv(ptw_ppv),
	.tranbuf(tranbuf),
	.miss_queue(miss_queue),
	.sel_tran(sel_tran),
	.sel_qe(sel_qe),
	.ftam_resp(ftam_resp),
	.tid(tid),
	.ptw_vadr(ptw_vadr),
	.ptw_padr(ptw_padr)
);

always_ff @(posedge clk)
if (rst) begin
	tlbmiss_ip <= 'd0;
	ftam_req <= 'd0;
//	ftam_req.cid <= CID;
	ftam_req.bte <= fta_bus_pkg::LINEAR;
	ftam_req.cti <= fta_bus_pkg::CLASSIC;
	upd_req <= 'd0;
	way <= 'd0;
	tlb_wr <= 1'b0;
	tlb_way <= 'd0;
	ptw_vadr <= {$bits(virtual_address_t){1'b0}};
	fault <= 1'b0;
	faultq_o <= 'd0;
	pe_fault_o <= 1'b0;
	fault_asid <= {$bits(asid_t){1'b0}};
	fault_adr <= {$bits(virtual_address_t){1'b0}};
	miss_adr <= {$bits(virtual_address_t){1'b0}};
	miss_asid <= {$bits(asid_t){1'b0}};
	pte <= {$bits(spte_t){1'b0}};
	tlb_entryno <= 7'd0;
	tlb_entry <= {$bits(tlb_entry_t){1'b0}};
	ptw_vv <= FALSE;
	ptw_ppv <= TRUE;
end
else begin

	pe_fault_o <= 1'b0;
	if (ptw_pv)
		ptw_vv <= FALSE;
	tlb_wr <= 1'b0;
	way <= way + 2'd1;

	// Grab the bus for only 1 clock.
	if (ftam_req.cyc && !ftam_resp.rty)
		tBusClear();

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
				tlb_entry.vpn.vpn <= {{11{miss_adr[31]}},miss_adr[31:23]};
				tlb_entry.vpn.asid <= miss_asid;
			end
			if (~sel_qe[5]) begin
				ptw_vadr <= {miss_queue[sel_qe].tadr[31:3],3'b0};
				ptw_vv <= TRUE;
				ptw_ppv <= TRUE;
			end
			if (ptw_pv & ptw_ppv & ~sel_qe[5]) begin
				$display("PTW: table walk triggered.");
				ptw_ppv <= FALSE;
				if (miss_queue[sel_qe].lvl != 3'd7) begin
					$display("PTW: walk level=%d", miss_queue[sel_qe].lvl);
					ftam_req <= 'd0;		// clear all fields.
					ftam_req.cyc <= 1'b1;
					ftam_req.stb <= 1'b1;
					ftam_req.we <= 1'b0;
					ftam_req.sel <= 16'h0FF << {miss_queue[sel_qe].tadr[3],3'd0};
					ftam_req.asid <= miss_queue[sel_qe].asid;
					ftam_req.vadr <= ptw_vadr;
					ftam_req.padr <= ptw_padr;
					ftam_req.tid <= tid;
//					ftam_req.cid <= CID;
				end
			end
		end
	// Remain in fault state until cleared by accessing the table-walker register.
	FAULT:
		begin
			fault <= 1'd0;
			if (cs_hwtw && sreq.padr[15:0]==16'hFF00) begin
				tlbmiss_ip <= 'd0;
				req_state <= IDLE;		
			end
		end
	default:
		req_state <= IDLE;	
	endcase

	// Search for ready translations and update the TLB.
	if (~sel_tran[5]) begin
		$display("PTW: selected tran:%d", sel_tran[4:0]);
		// We're done if level zero processed.
		miss_asid <= miss_queue[tranbuf[sel_tran].stk].asid;
		miss_adr <= miss_queue[tranbuf[sel_tran].stk].adr;
		pte <= tranbuf[sel_tran].pte;
		// If translation is not valid, cause a page fault.
		if (~tranbuf[sel_tran].pte.v) begin
			$display("PTW: page fault");
			faultq_o <= miss_queue[tranbuf[sel_tran].stk].qn;
			fault <= 1'b1;
			pe_fault_o <= 1'b1;
			fault_asid <= tranbuf[sel_tran].asid;
			fault_adr <= tranbuf[sel_tran].vadr;
			req_state <= FAULT;
		end
		// Otherwise translation was valid, update it in the TLB.
		else if (miss_queue[tranbuf[sel_tran].stk].lvl==3'd7) begin
			upd_req <= 1'b1;
			$display("PTW: TLB update request triggered.");
		end
	end
end

task tBusClear;
begin
	ftam_req.cyc <= 1'b0;
	ftam_req.stb <= 1'b0;
	ftam_req.sel <= 16'h0000;
	ftam_req.we <= 1'b0;
end
endtask

endmodule
