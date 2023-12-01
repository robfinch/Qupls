// ============================================================================
//        __
//   \\__/ o\    (C) 2014-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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
// Allocate up to four registers per clock.
// We need to be able to free many more registers than are allocated in the 
// event of a pipeline flush. Normally up to four register values will be
// committed to the register file.
// ============================================================================
//
import QuplsPkg::*;

module Qupls_reg_renamer(rst,clk,list2free,tags2free,freevals,
	alloc0,alloc1,alloc2,alloc3,wo0,wo1,wo2,wo3,avail);
parameter NFTAGS = 4;
input rst;
input clk;
input [PREGS-1:0] list2free;
input pregno_t [NFTAGS-1:0] tags2free;		// register tags to free
input [NFTAGS-1:0] freevals;					// bitmnask indicating which tags to free
input alloc0;					// allocate target register 0
input alloc1;
input alloc2;
input alloc3;
output pregno_t wo0;	// target register tag
output pregno_t wo1;
output pregno_t wo2;
output pregno_t wo3;
output reg [PREGS-1:0] avail;				// recorded in ROB

integer n;
reg [PREGS-1:0] availy;
reg [PREGS-1:0] availx [0:NFTAGS-1];

wire [5:0] o0, o1, o2, o3;
wire v0, v1, v2, v3;

ffo48 uffo0(avail[ 47:  0], o0);
ffo48 uffo1(avail[ 95: 48], o1);
ffo48 uffo2(avail[143: 96], o2);
ffo48 uffo3(avail[191:144], o3);

wire [47:0] unavail0 = 48'd1 << o0;
wire [47:0] unavail1 = 48'd1 << o1;
wire [47:0] unavail2 = 48'd1 << o2;
wire [47:0] unavail3 = 48'd1 << o3;
assign v0 = o0!=6'd63;
assign v1 = o1!=6'd63;
assign v2 = o2!=6'd63;
assign v3 = o3!=6'd63;

genvar g;
generate begin : gAvailx
	for (g = 0; g < NFTAGS; g = g + 1) begin
		always_comb
			availx[g] <= {191'd0,freevals[g]} << tags2free[g];
	end
end
endgenerate

always_comb
begin
	availy = 'd0;
	for (n = 0; n < NFTAGS; n = n + 1)
		availy = availy | availx[n];
	availy = availy | list2free;
end

always_ff @(posedge clk)
if (rst) begin
	avail <= {PREGS{1'b1}};
	wo0 <= 'd0;
	wo1 <= 'd0;
	wo2 <= 'd0;
	wo2 <= 'd0;
end
else begin
	case({alloc3,alloc2,alloc1,alloc0} & {v3,v2,v1,v0})
	4'b0000:
		begin
	 		avail <= avail | availy;
	 	end
	4'b0001:
		begin
			wo0 <= {2'b00,o0};
			avail <= avail & ~{144'd0,unavail0} | availy;
		end
	4'b0010:
		begin
			wo1 <= {2'b01,o1};
			avail <= avail & ~{96'd0,unavail1,48'd0} | availy;
		end
	4'b0011:
		begin
			wo0 <= {2'b00,o0};
			wo1 <= {2'b01,o1};
			avail <= avail & ~{96'd0,unavail1,unavail0} | availy;
		end
	4'b0100:
		begin
			wo2 <= {2'b10,o2};
			avail <= avail & ~{48'd0,unavail2,96'd0} | availy;
		end
	4'b0101:
		begin
			wo0 <= {2'b00,o0};
			wo2 <= {2'b10,o2};
			avail <= avail & ~{48'd0,unavail2,48'd0,unavail0} | availy;
		end
	4'b0110:
		begin
			wo1 <= {2'b01,o1};
			wo2 <= {2'b10,o2};
			avail <= avail & ~{48'd0,unavail2,unavail1,48'd0} | availy;
		end
	4'b0111:
		begin
			wo0 <= {2'b00,o0};
			wo1 <= {2'b01,o1};
			wo2 <= {2'b10,o2};
			avail <= avail & ~{48'd0,unavail2,unavail1,unavail0} | availy;
		end
	4'b1000:
		begin
			wo3 <= {2'b11,o3};
			avail <= avail & ~{unavail3,144'd0} | availy;
		end
	4'b1001:
		begin
			wo0 <= {2'b00,o0};
			wo3 <= {2'b11,o3};
			avail <= avail & ~{unavail3,96'd0,unavail0} | availy;
		end
	4'b1010:
		begin
			wo1 <= {2'b01,o1};
			wo3 <= {2'b11,o3};
			avail <= avail & ~{unavail3,48'd0,unavail1,48'd0} | availy;
		end
	4'b1011:
		begin
			wo0 <= {2'b00,o0};
			wo1 <= {2'b01,o1};
			wo3 <= {2'b11,o3};
			avail <= avail & ~{unavail3,48'd0,unavail1,unavail0} | availy;
		end
	4'b1100:
		begin
			wo2 <= {2'b10,o2};
			wo3 <= {2'b11,o3};
			avail <= avail & ~{unavail3,unavail2,96'd0} | availy;
		end
	4'b1101:
		begin
			wo0 <= {2'b00,o0};
			wo2 <= {2'b10,o2};
			wo3 <= {2'b11,o3};
			avail <= avail & ~{unavail3,unavail2,48'd0,unavail0} | availy;
		end
	4'b1110:
		begin
			wo1 <= {2'b01,o1};
			wo2 <= {2'b10,o2};
			wo3 <= {2'b11,o3};
			avail <= avail & ~{unavail3,unavail2,unavail1,48'd0} | availy;
		end
	4'b1111:
		begin
			wo0 <= {2'b00,o0};
			wo1 <= {2'b01,o1};
			wo2 <= {2'b10,o2};
			wo3 <= {2'b11,o3};
			avail <= avail & ~{unavail3,unavail2,unavail1,unavail0} | availy;
		end
	endcase
end

endmodule

