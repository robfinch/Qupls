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

// To request a map:
//	Write register number to 0xBB00
//  Read 0xBB00, check that bit 31 is a one
//	If bit 31 is a one, physical regno is in bits 0 to 8.

import const_pkg::*;
import cpu_types_pkg::*;
import Stark_pkg::*;

module Stark_copro_reg_map_req(rst, clk, cs, cyc, wr, adr, din, dout, ack,
	aRn, aRn_req, pRn, pRn_ack);
input rst;
input clk;
input cs;
input cyc;
input wr;
input [7:0] adr;
input [31:0] din;
output reg [31:0] dout;
output reg ack;
output aregno_t aRn;
output reg aRn_req;
input pregno_t pRn;
input pRn_ack;

always_ff @(posedge clk)
if (rst) begin
	aRn_req <= 1'b0;
	dout <= 32'd0;
	ack <= 1'b0;
end
else begin
	ack <= 1'b0;
	if (cs & cyc) begin
		if (wr) begin
			aRn_req <= 1'b1;
			aRn <= din[7:0];
			dout <= 32'd0;
		end
  	ack <= 1'b1;
	end
	if (pRn_ack & aRn_req) begin
		aRn_req <= 1'b0;
		dout <= {1'b1,22'd0,pRn};
	end
end

endmodule

