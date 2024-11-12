`timescale 1ns / 1ps
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
// 88k LUTs / 4k FFs		(512 phys. regs)
// ============================================================================

import QuplsPkg::SIM;

module Qupls_checkpoint_valid_ram6(rst,
	clka, ena, wea, cpa, prega, dina,
	clkb, enb, cpb, pregb, doutb, ncp, ncp_ra, ncp_wa);
//	ncp, ncp_ra);
parameter NWRPORTS = 9;
parameter NRDPORTS = 24;
localparam RBIT=$clog2(PREGS);
localparam QBIT=$bits(cpu_types_pkg::pregno_t);
localparam WID=$bits(checkpoint_t);
localparam AWID=$clog2(NCHECK);
input rst;
input clka;
input ena;
input [NWRPORTS-1:0] wea;
input checkpt_ndx_t [NWRPORTS-1:0] cpa;
input pregno_t [NWRPORTS-1:0] prega;
input [NWRPORTS-1:0] dina;
input clkb;
input enb;
input checkpt_ndx_t [NRDPORTS-1:0] cpb;
input pregno_t [NRDPORTS-1:0] pregb;
output reg [NRDPORTS-1:0] doutb;
input ncp;
input [AWID-1:0] ncp_ra;
input [AWID-1:0] ncp_wa;

integer n,nr;
(* RAM_STYLE="distributed" *)
reg [PREGS-1:0] mem [0:NCHECK-1];
reg [NRDPORTS-1:0] doutb1;

always_ff @(posedge clka)
// At reset, all regs are valid.
if (rst) begin
	for (n = 0; n < NCHECK; n = n + 1)
		mem[n] <= {PREGS{1'b1}};
end
else begin
	// For a new checkpoint, copy all bits across.
	if (ncp)
		mem[ncp_wa] <= mem[ncp_ra];
	// Otherwise, update individual bits
	for (n = 0; n < NWRPORTS; n = n + 1)
		if (ena & wea[n]) begin
			mem[cpa[n]][prega[n]] <= dina[n];
		end
end

always_comb
begin
//	for (nw = 0; nw < NWRPORTS; nw = nw + 1) begin
	for (nr = 0; nr < NRDPORTS; nr = nr + 1) begin
		doutb1[nr] = (pregb[nr]==9'd0) ? 1'b1 : 
//			pregb[nr]==prega[nw] && cpb[nr]==cpa[nw] ? dina[nw] :
			mem[cpb[nr]][pregb[nr]];
	end
//	end
end
always_comb//ff @(posedge clkb)
if (rst)
	doutb <= {NRDPORTS{1'b0}};
else begin
//	if (enb)
		doutb <= doutb1;
end

endmodule
