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
// 1560 LUTs / 160 FFs
// ============================================================================
//
// The selector is organized around having seven functional units requesting
// up to five registers each, or 35 register selections. Since most of the
// time instructions will require 3 registers or less, it is wasteful to 
// have a separate register file port for every possible register an 
// instruction might need. Instead the selector goes with enough ports to
// keep everybody happy most of the time.
//
// The first seven port selections are fixed 1:1. This is to reduce the amount
// of logic required by the selector. Many instructions use a at least one
// source register, so they are simply allocated one all the time. Instead
// of requiring dynamic mapping for all 30 inputs, it is reduced to 24
// inputs. This cuts the size of the component in half (1900 LUTs instead
// of 4000) and likely helps with the timing as well.
//
// The port selection rotates for the 24 dynamically assigned ports to
// ensure that no port goes unserviced.
// ============================================================================

import cpu_types_pkg::aregno_t;
import cpu_types_pkg::pc_address_t;

module Qupls4_read_port_select(rst, clk, pReg_i, pRegv_i, pReg_o, regAck_o);
parameter NPORTI=64;
parameter NPORTO=16;
parameter FIXEDPORTS = 0;
input rst;
input clk;
input pregno_t [NPORTI-1:0] pReg_i;
input [NPORTI-1:0] pRegv_i;
output pregno_t [NPORTO-1:0] pReg_o;
output reg [NPORTI-1:0] regAck_o;

integer j,k,h,x;
reg [5:0] m;

// m used to rotate the port selections every clock cycle.
always_ff @(posedge clk)
if (rst)
	m <= 6'd0;
else begin
	if (m==NPORTI-FIXEDPORTS-1)
		m <= 6'd0;
	else
		m <= m + 6'd1;
end

always_ff @(posedge clk)
if (rst) begin
	for (j = 0; j < NPORTI; j = j + 1)
		regAck_o[j] = 1'b0;
end
else begin
	k = FIXEDPORTS;
	for (h = 0; h < FIXEDPORTS; h = h + 1) begin
		regAck_o[h] = 1'b1;
		pReg_o[h] = pReg_i[h];
	end
	for (h = 0; h < NPORTO; h = h + 1) begin
		if (h >= FIXEDPORTS) begin
			regAck_o[h] = 1'b0;
			pReg_o[h] = 8'd0;
		end
	end
	for (j = 0; j < NPORTI-FIXEDPORTS; j = j + 1) begin
		regAck_o[j+FIXEDPORTS] = 1'b0;
		if (k < NPORTO) begin
			if (pRegv_i[((j+m)%(NPORTI-FIXEDPORTS))+FIXEDPORTS]) begin
				regAck_o[((j+m)%(NPORTI-FIXEDPORTS))+FIXEDPORTS] = 1'b1;
				pReg_o[k] = pReg_i[((j+m)%(NPORTI-FIXEDPORTS))+FIXEDPORTS];
				k = k + 1;
			end
		end
	end
end

endmodule
