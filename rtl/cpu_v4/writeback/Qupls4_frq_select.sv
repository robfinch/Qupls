// ============================================================================
//        __
//   \\__/ o\    (C) 2025  Robert Finch, Waterloo
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
// ============================================================================

import const_pkg::*;
import Qupls4_pkg::*;

module Qupls4_frq_select(rst, clk, frq_empty, upd, upd_bitmap);
parameter NFRQ=13;
parameter NWRITE_PORTS=4;
input rst;
input clk;
input [NFRQ-1:0] frq_empty;
output reg [4:0] upd [0:NWRITE_PORTS-1];
output reg [NFRQ-1:0] upd_bitmap;

genvar g,k;
wire [4:0] upda [0:NWRITE_PORTS-1];
reg [4:0] fuq_rot;
reg [23:0] excl [0:NWRITE_PORTS-1];		// exclustion list

// Look for queues containing values, and select from a queue using a rotating selector.
reg [NFRQ-1:0] fuq_empty;
reg [NFRQ*2-1:0] fuq_empty_rot1;
reg [NFRQ-1:0] fuq_empty_rot;
always_comb
	fuq_empty_rot1 = ({frq_empty,frq_empty} << fuq_rot);
always_comb
	fuq_empty_rot = fuq_empty_rot1[NFRQ-1:0] | fuq_empty_rot1[NFRQ*2-1:NFRQ];

generate begin : gFFOs
	for (g = 0; g < $size(upda); g = g + 1) begin
	  always_comb
			if (g==0)
				excl[g] = 24'd0;
			else
	    	excl[g] = (24'd1 << upda[g-1]) | excl[g-1];
		ffo24 uffov1 (.i({11'h0,~fuq_empty_rot} & ~excl[g]), .o(upda[g]));
	end
end
endgenerate

// mod NFRQ counter - rotate the queue selection
always_ff @(posedge clk)
if (rst)
	fuq_rot <= 5'd0;
else begin
	fuq_rot <= fuq_rot + 2'd1;
	if (fuq_rot >= NFRQ-1)
		fuq_rot <= 5'd0;
end

// If upda did not find anything to update, then neither will any of the subsequest ones.
generate begin : gUpd
	for (g = 0; g < $size(upd); g = g + 1) begin
		always_ff @(posedge clk)
			upd[g] <= upda[g]==5'd31 ? 5'd31 : fuq_rot > upda[g] ? NFRQ + upda[g] - fuq_rot : upda[g] - fuq_rot;
		for (k = 0; k < $size(upd_bitmap); k = k + 1)
			always_ff @(posedge clk) begin
				upd_bitmap[k] <= 1'b0;
				if (k==upda[g] && upda[g]!=5'd31) upd_bitmap[k] <= 1'b1;
			end
	end
end
endgenerate

endmodule
