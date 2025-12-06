// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2024  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Qupls_active_region.sv
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
// 2500 LUTs / 2500 FFs                                                                          
// ============================================================================

import fta_bus_pkg::*;
import QuplsPkg::*;
import QuplsMmupkg::*;

module Qupls_active_region(rst, clk, rgn0, rgn1, rgn2, ftas_req, ftas_resp,
	region_num, region0, region1, region2, sel0, sel1, sel2, err0, err1, err2);
input rst;
input clk;
input [2:0] rgn0;
input [2:0] rgn1;
input [2:0] rgn2;
input fta_cmd_request128_t ftas_req;
output fta_cmd_response128_t ftas_resp;
output reg [3:0] region_num;
output REGION region0;
output REGION region1;
output REGION region2;
output reg [7:0] sel0;
output reg [7:0] sel1;
output reg [7:0] sel2;
output reg err0;
output reg err1;
output reg err2;
localparam ABITS = $bits(fta_address_t);

parameter IO_ADDR = 32'hFEEF0001;
parameter IO_ADDR_MASK = 32'h00FF0000;

parameter CFG_BUS = 8'd0;
parameter CFG_DEVICE = 5'd12;
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
parameter CFG_IRQ_LINE = 8'hFF;

localparam CFG_HEADER_TYPE = 8'h00;			// 00 = a general device


integer n;
REGION [7:0] pma_regions;
reg cs_rgn, cs_config;

initial begin
	// ROM
	pma_regions[7].pmt	= 48'h00000000;
	pma_regions[7].cta	= 48'h00000000;
	pma_regions[7].at 	= 'h0;			// rom, byte address table, cache-read-execute
	pma_regions[7].at[0].rwx = 4'hD;
	pma_regions[7].at[1].rwx = 4'hD;
	pma_regions[7].at[2].rwx = 4'hD;
	pma_regions[7].at[3].rwx = 4'hD;
	pma_regions[7].at[3].cache = fta_bus_pkg::WT_READ_ALLOCATE;
	pma_regions[7].lock = "LOCK";

	// IO
	pma_regions[6].pmt	 = 48'h00000300;
	pma_regions[6].cta	= 48'h00000000;
	pma_regions[6].at 	= 'h0;
	pma_regions[6].at[0].rwx = 4'hE;
	pma_regions[6].at[1].rwx = 4'hE;
	pma_regions[6].at[2].rwx = 4'hE;
	pma_regions[6].at[3].rwx = 4'hE;
	pma_regions[6].at[3].cache = fta_bus_pkg::NC_NB;
//	pma_regions[6].at = 20'h00206;		// io, (screen) byte address table, read-write
	pma_regions[6].lock = "LOCK";

	// Config space
	pma_regions[5].pmt	 = 48'h00000000;
	pma_regions[5].cta	= 48'h00000000;
	pma_regions[5].at 	= 'h0;
	pma_regions[5].at[0].rwx = 4'h6;
	pma_regions[5].at[1].rwx = 4'h6;
	pma_regions[5].at[2].rwx = 4'h6;
	pma_regions[5].at[3].rwx = 4'h6;
	pma_regions[5].lock = "LOCK";

	// Scratchpad RAM
	pma_regions[4].pmt	 = 48'h00002300;
	pma_regions[4].cta	= 48'h00000000;
	pma_regions[4].at 	= 'h0;
	pma_regions[4].at[0].rwx = 4'hF;
	pma_regions[4].at[1].rwx = 4'hF;
	pma_regions[4].at[2].rwx = 4'hF;
	pma_regions[4].at[3].rwx = 4'hF;
	pma_regions[4].at[3].cache = fta_bus_pkg::WT_READ_ALLOCATE;
//	pma_regions[4].at = 20'h0020F;		// byte address table, read-write-execute cacheable
	pma_regions[4].lock = "LOCK";

	// vacant
	pma_regions[3].pmt	 = 48'h00000000;
	pma_regions[3].cta	= 48'h00000000;
	pma_regions[3].at 	= 'h0;
	pma_regions[3].at[0].dev_type = 8'hFF;		// no access
	pma_regions[3].at[1].dev_type = 8'hFF;		// no access
	pma_regions[3].at[2].dev_type = 8'hFF;		// no access
	pma_regions[3].at[3].dev_type = 8'hFF;		// no access
	pma_regions[3].lock = "LOCK";

	// vacant
	pma_regions[2].pmt	 = 48'h00000000;
	pma_regions[2].cta	= 48'h00000000;
	pma_regions[2].at 	= 'h0;
//	pma_regions[2].at = 20'h0FF00;		// no access
	pma_regions[3].at[0].dev_type = 8'hFF;		// no access
	pma_regions[3].at[1].dev_type = 8'hFF;		// no access
	pma_regions[3].at[2].dev_type = 8'hFF;		// no access
	pma_regions[3].at[3].dev_type = 8'hFF;		// no access
	pma_regions[2].lock = "LOCK";

	// DRAM
	pma_regions[1].pmt	 = 48'h00002400;
	pma_regions[1].cta	= 48'h00000000;
	pma_regions[1].at 	= 'h0;
	pma_regions[1].at[0].rwx = 4'hF;
	pma_regions[1].at[1].rwx = 4'hF;
	pma_regions[1].at[2].rwx = 4'hF;
	pma_regions[1].at[3].rwx = 4'hF;
	pma_regions[1].at[0].dev_type = 8'h01;		// no access
	pma_regions[1].at[1].dev_type = 8'h01;		// no access
	pma_regions[1].at[2].dev_type = 8'h01;		// no access
	pma_regions[1].at[3].dev_type = 8'h01;		// no access
	pma_regions[1].at[3].cache = fta_bus_pkg::WT_READ_ALLOCATE;
//	pma_regions[1].at = 20'h0010F;	// ram, byte address table, cache-read-write-execute
	pma_regions[1].lock = "LOCK";

	// vacant
	pma_regions[0].pmt	 = 48'h00000000;
	pma_regions[0].cta	= 48'h00000000;
	pma_regions[0].at 	= 'h0;
	pma_regions[0].at[0].dev_type = 8'hFF;		// no access
	pma_regions[0].at[1].dev_type = 8'hFF;		// no access
	pma_regions[0].at[2].dev_type = 8'hFF;		// no access
	pma_regions[0].at[3].dev_type = 8'hFF;		// no access
	pma_regions[0].lock = "LOCK";

end

fta_cmd_request128_t sreq;
fta_cmd_response128_t sresp;
wire sack;
wire [127:0] cfg_out;
wire cs_bar0;

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
	cs_rgn <= cs_bar0 && sreq.cyc && sreq.stb;

vtdl #(.WID(1), .DEP(16)) urdyd1 (.clk(clk), .ce(1'b1), .a(4'd1), .d(cs_rgn|cs_config), .q(sack));

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
	.irq_i(1'b0),
	.irq_o(),
	.cs_config_i(cs_config),
	.we_i(sreq.we),
	.sel_i(sreq.sel),
	.adr_i(sreq.padr),
	.dat_i(sreq.data1),
	.dat_o(cfg_out),
	.cs_bar0_o(cs_bar0),
	.cs_bar1_o(),
	.cs_bar2_o(),
	.irq_en_o()
);

always_ff @(posedge clk)
	if (cs_rgn && sreq.we && sreq.cyc && sreq.stb) begin
		if (pma_regions[sreq.padr[8:6]].lock=="UNLK" || sreq.padr[5:4]==2'h3) begin
			case(sreq.padr[5:4])
			2'd0:	pma_regions[sreq.padr[8:6]].pmt[ABITS-1: 0] <= sreq.data1[ABITS-1:0];
			2'd1:	pma_regions[sreq.padr[8:6]].cta[ABITS-1: 0] <= sreq.data1[ABITS-1:0];
			2'd2:	pma_regions[sreq.padr[8:6]].at <= sreq.data1;
			2'd3: pma_regions[sreq.padr[8:6]].lock <= sreq.data1;
			endcase
		end
	end

always_ff @(posedge clk)
	if (cs_config)
		sresp.dat <= cfg_out;
	else if (cs_rgn && sreq.cyc && sreq.stb) begin
		sresp.dat <= 'd0;
		case(sreq.padr[5:4])
		2'd0:	sresp.dat <= pma_regions[sreq.padr[8:6]].pmt;
		2'd1:	sresp.dat <= pma_regions[sreq.padr[8:6]].cta;
		2'd2:	sresp.dat <= pma_regions[sreq.padr[8:6]].at;
		2'd3:	sresp.dat <= pma_regions[sreq.padr[8:6]].lock;
		endcase
	end
	else
		sresp.dat <= 'd0;

always_comb
begin
	err0 = 1'b1;
	region_num = 4'd0;
	region0 = pma_regions[0];
	sel0 = 'd0;
	region0 = pma_regions[rgn0];
	region_num = rgn0;
	sel0[rgn0] = 1'b1;
	err0 = 1'b0;

	err1 = 1'b1;
	region1 = pma_regions[0];
	sel1 = 'd0;
	region1 = pma_regions[rgn1];
	sel1[rgn1] = 1'b1;
	err1 = 1'b0;

	err2 = 1'b1;
	region2 = pma_regions[0];
	sel2 = 'd0;
	region2 = pma_regions[rgn2];
	sel2[rgn2] = 1'b1;
	err2 = 1'b0;
end    	
    	
endmodule

