// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2024  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	region_tbl.sv
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
import Stark_pkg::*;
import mmu_pkg::*;

module region_tbl(rst, clk, cs_rgn, rgn0, rgn1, rgn2, ftas_req, region_dat,
	region_num, region0, region1, region2, sel0, sel1, sel2, err0, err1, err2);
input rst;
input clk;
input cs_rgn;
input [2:0] rgn0;
input [2:0] rgn1;
input [2:0] rgn2;
input fta_cmd_request256_t ftas_req;
output reg [255:0] region_dat;
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

integer n;
REGION [7:0] pma_regions;

initial begin
	// ROM
	pma_regions[7].pam	= 48'h00000000;
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
	pma_regions[6].pam	= 48'h00000000;
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
	pma_regions[5].pam	= 48'h00000000;
	pma_regions[5].pmt	= 48'h00000000;
	pma_regions[5].cta	= 48'h00000000;
	pma_regions[5].at 	= 'h0;
	pma_regions[5].at[0].rwx = 4'h6;
	pma_regions[5].at[1].rwx = 4'h6;
	pma_regions[5].at[2].rwx = 4'h6;
	pma_regions[5].at[3].rwx = 4'h6;
	pma_regions[5].lock = "LOCK";

	// Scratchpad RAM
	pma_regions[4].pam	= 48'h00000000;
	pma_regions[4].pmt	= 48'h00002300;
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
	pma_regions[3].pam	= 48'h00000000;
	pma_regions[3].pmt	 = 48'h00000000;
	pma_regions[3].cta	= 48'h00000000;
	pma_regions[3].at 	= 'h0;
	pma_regions[3].at[0].dev_type = 8'hFF;		// no access
	pma_regions[3].at[1].dev_type = 8'hFF;		// no access
	pma_regions[3].at[2].dev_type = 8'hFF;		// no access
	pma_regions[3].at[3].dev_type = 8'hFF;		// no access
	pma_regions[3].lock = "LOCK";

	// vacant
	pma_regions[2].pam	= 48'h00000000;
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
	pma_regions[1].pam	= 48'h00000000;
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
	pma_regions[0].pam	= 48'h00000000;
	pma_regions[0].pmt	 = 48'h00000000;
	pma_regions[0].cta	= 48'h00000000;
	pma_regions[0].at 	= 32'h0;
	pma_regions[0].lock = "LOCK";
	pma_regions[0].at[0].dev_type = 8'hFF;		// no access
	pma_regions[0].at[1].dev_type = 8'hFF;		// no access
	pma_regions[0].at[2].dev_type = 8'hFF;		// no access
	pma_regions[0].at[3].dev_type = 8'hFF;		// no access

end

fta_cmd_request256_t sreq;
fta_cmd_response256_t sresp;
wire sack;
wire [255:0] cfg_out;
wire cs_bar0;

always_comb
	sreq <= ftas_req;

always_ff @(posedge clk)
	if (cs_rgn && sreq.we && sreq.cyc && (sreq.adr[13:8]==6'h3C || sreq.adr[13:8]==6'h3D)) begin
		if (pma_regions[sreq.adr[8:6]].lock=="UNLK" || sreq.adr[5:3]==3'h5) begin
			case(sreq.adr[5])
			1'd0:	
				begin
					if (&sreq.sel[7:0]) pma_regions[sreq.adr[8:6]].start_adr[ABITS-1: 0] <= sreq.data1[ABITS-1:0];
					if (&sreq.sel[15:8]) pma_regions[sreq.adr[8:6]].end_adr[ABITS-1: 0] <= sreq.data1[ABITS-1+64:64];
					if (&sreq.sel[23:16]) pma_regions[sreq.adr[8:6]].pam[ABITS-1: 0] <= sreq.data1[ABITS-1+128:128];
					if (&sreq.sel[31:24]) pma_regions[sreq.adr[8:6]].pmt[ABITS-1: 0] <= sreq.data1[ABITS-1+192:192];
				end
			1'd1:
				begin
					if (&sreq.sel[7:0])	pma_regions[sreq.adr[8:6]].cta[ABITS-1: 0] <= sreq.data1[ABITS-1:0];
					if (&sreq.sel[11:8]) pma_regions[sreq.adr[8:6]].lock <= sreq.data1[95:64];
					if (&sreq.sel[19:16]) pma_regions[sreq.adr[8:6]].at[0] <= sreq.data1[159:128];
					if (&sreq.sel[23:20]) pma_regions[sreq.adr[8:6]].at[1] <= sreq.data1[191:160];
					if (&sreq.sel[27:24]) pma_regions[sreq.adr[8:6]].at[2] <= sreq.data1[223:192];
					if (&sreq.sel[31:28]) pma_regions[sreq.adr[8:6]].at[3] <= sreq.data1[255:224];
				end
			endcase
		end
	end

always_ff @(posedge clk)
	if (cs_rgn && sreq.cyc) begin
		region_dat <= 64'd0;
		case(sreq.adr[5])
		1'd0:
			begin
				region_dat[63:0] <= pma_regions[sreq.adr[8:6]].start_adr;
				region_dat[127:64] <= pma_regions[sreq.adr[8:6]].end_adr;
				region_dat[191:128] <= pma_regions[sreq.adr[8:6]].pam;
				region_dat[255:192] <= pma_regions[sreq.adr[8:6]].pmt;
			end
		1'd1:
			begin
				region_dat[63:0] <= pma_regions[sreq.adr[8:6]].cta;
				region_dat[127:64] <= {32'h0,pma_regions[sreq.adr[8:6]].lock};
				region_dat[191:128] <= {pma_regions[sreq.adr[8:6]].at[1],pma_regions[sreq.adr[8:6]].at[0]};
				region_dat[255:192] <= {pma_regions[sreq.adr[8:6]].at[3],pma_regions[sreq.adr[8:6]].at[2]};
			end
		endcase
	end
	else
		region_dat <= 256'd0;

always_comb
begin
	err0 = 1'b1;
	region_num = 4'd0;
	region0 = pma_regions[0];
	sel0 = 1'd0;
	region0 = pma_regions[rgn0];
	region_num = rgn0;
	sel0[rgn0] = 1'b1;
	err0 = 1'b0;

	err1 = 1'b1;
	region1 = pma_regions[0];
	sel1 = 1'd0;
	region1 = pma_regions[rgn1];
	sel1[rgn1] = 1'b1;
	err1 = 1'b0;

	err2 = 1'b1;
	region2 = pma_regions[0];
	sel2 = 1'd0;
	region2 = pma_regions[rgn2];
	sel2[rgn2] = 1'b1;
	err2 = 1'b0;
end    	
    	
endmodule

