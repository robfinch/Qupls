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

// Register read:
//	Write register number with bit 31=1 to 0xBC00
//  Read 0xBC00, check that bit 31 is a zero
//	Read 0xBC10,0xBC14 for the value
// Register write:
//	Write value of register to 0xBC10,0xBC14
//  Write register number with bit 31=0 to 0xBC00

import const_pkg::*;
import cpu_types_pkg::*;
import Stark_pkg::*;

module Stark_copro_reg_rw(rst, clk, cs, cyc, wr, adr, din, dout, ack,
	rd_reg, wr_reg, pRn, pRn_wack, prn, prnv, rfo);
input rst;
input clk;
input cs;
input cyc;
input wr;
input [7:0] adr;
input [31:0] din;
output reg [31:0] dout;
output reg ack;
output reg rd_reg;
output reg wr_reg;
output pregno_t pRn;
input pRn_wack;
input pregno_t [15:0] prn;
input [15:0] prnv;
input value_t [15:0] rfo;

integer n1;
reg rd_regf;
reg [63:0] reg_val;

always_ff @(posedge clk)
if (rst) begin
	pRn <= 9'h000;
	ack <= 1'b0;
	rd_reg <= 1'b0;
	wr_reg <= 1'b0;
	rd_regf <= 1'b0;
	reg_val <= 64'd0;
	dout <= 32'd0;
end
else begin
	ack <= 1'b0;
	if (pRn_wack)
		wr_reg <= 1'b0;
	if (cs & cyc) begin
		if (wr) begin
			if (adr[7:4]==4'h0) begin
				pRn <= din[8:0];
				rd_reg <= din[31];
				wr_reg <= ~din[31];
				rd_regf <= din[31];
			end
			else if (adr[7:4]==4'h1) begin
				if (adr[2])
					reg_val[63:32] <= din;
				else
					reg_val[31: 0] <= din;
			end
		end
		else begin
			if (adr[7:4]==4'h0)
				dout <= {rd_regf,22'd0,pRn};
			else if (adr[7:4]==4'h1)
				dout <= adr[2] ? reg_val[63:32] : reg_val[31:0];
			else
				dout <= 32'd0;
		end
		ack <= 1'b1;
	end
	for (n1 = 0; n1 < 16; n1 = n1 + 1) begin
		if (prn[n1]==pRn && prnv[n1] && rd_regf) begin
			reg_val <= rfo;
			rd_regf <= 1'b0;
		end
	end
end

endmodule
