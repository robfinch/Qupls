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

module Qupls_reg_renamer_fifo(rst, clk, en, wlist2free, alloc, freeval, 
	tag2free, o, wo, o0, stall, headreg);
parameter FIFONO = 0;
parameter ENTRIES = 64;
input rst;
input clk;
input en;
input [63:0] wlist2free;
input alloc;
input freeval;
input pregno_t tag2free;
output pregno_t o;				// register that is allocated
output pregno_t wo;				// next value to be assigned to o
output [6:0] o0;					// register to free from free list
output reg v;							// indicates o0 is valid
output reg stall;					// stall because no regs are available
output reg [7:0] headreg;	// register at head of fifo

reg [7:0] fifo [0:ENTRIES-1];
reg [5:0] head,tail;

initial begin
	for (m = 0; m < ENTRIES; m = m + 1)
		fifo[m] = m+ENTRIES*FIFONO;
end

ffo96 uffo({32'd0,wlist2free}, o0);

always_comb v = o0!=7'd127;

always_comb stall = (head + 1 == tail) && alloc && !(freeval|v);
always_comb headreg = fifo[head];

always_ff @(posedge clk)
if (rst) begin
	o <= 'd0;
	head <= 'd0;
	tail <= 'd0;
end
else begin
	if (en) begin
		if (alloc & ~(freeval|v) & ~stall) begin
			o <= fifo[head];
			head <= head + 1;
		end
		else if (freeval && alloc)
			o <= tag2free;
		else if (v && alloc)
			o <= {FIFONO[1:0],o0[5:0]};
		else if (freeval) begin
			fifo[tail] <= tag2free;
			tail <= tail + 1;
		end
		else if (v) begin
			fifo[tail] <= {FIFONO[1:0],o0[5:0]};
			tail <= tail + 1;
		end
	end
end

always_comb
if (rst)
	wo = 'd0;
else begin
	wo = o;
	if (en) begin
		if (alloc & ~(freeval|v) & ~stall)
			wo = fifo[head];
		else if (freeval && alloc)
			wo = tag2free;
		else if (v && alloc)
			wo = {FIFONO[1:0],o0[5:0]};
	end
end

endmodule
