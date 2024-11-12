// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2024  Robert Finch, Waterloo
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
// 63000 LUTs / 4096 FFs	16 checkpints
// 20600 LUTs / 1024 FFs   4 checkpoints
// 11000 LUTs / 768 FFs    3 checkpoints (256 regs)
// 6200 LUTs / 500 FFs 3 checkpoints (150 regs)
// ============================================================================

import QuplsPkg::*;

module Qupls_checkpoint_valid_ram3(rst, clka, en, wr, wc, wa, awa, setall, i, clkb, rc, ra, o);
parameter BANKS=1;
parameter NPORT=8;
parameter NRDPORT=17;
input rst;
input clka;
input en;
input [NPORT-1:0] wr;
input checkpt_ndx_t [NPORT-1:0] wc;
input pregno_t [NPORT-1:0] wa;
input aregno_t [NPORT-1:0] awa;		// debugging
input setall;
input [NPORT-1:0] i;
input clkb;
input checkpt_ndx_t [NRDPORT-1:0] rc;
input pregno_t [NRDPORT-1:0] ra;
output reg [NRDPORT-1:0] o;

reg [NCHECK-1:0] mem [0:PREGS-1];

genvar g;

integer n,m;
initial begin
	for (m = 0; m < PREGS; m = m + 1)
		mem[m] = {NCHECK{1'b1}};
end

always_ff @(posedge clka)
for (n = 0; n < NPORT; n = n + 1)
if (en|1'b1) begin
	if (wr[n]) begin
		if (setall)
			mem[wa[n]] <= {NCHECK{1'b1}};
		else
		begin
			mem[wa[n]][wc[n]] <= i[n];
			/*
			if (awa[n]==9'd68 && i[n]) begin
				$display("Q+ RAT: chkpt ram wrote a 1 to r%d/%d", awa[n], wa[n]);
				$finish;
			end
			*/
		end
	end
end

generate begin : gMem
	for (g = 0; g < NRDPORT; g = g + 1) begin
		always_ff @(posedge clkb)
		if (rst)
			o[g] <= 1'b1;
		else begin
			o[g] <= mem[ra[g]][rc[g]];
		end
	end
end
endgenerate

endmodule
