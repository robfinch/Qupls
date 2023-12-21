// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
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
// ============================================================================
//
import QuplsPkg::*;

module Qupls_reg_renamer_fifo(rst, clk, en, wlist2free, alloc, freeval, 
	tag2free, o, ov, wo, o0, v, stall, headreg);
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
output reg ov;						// register allocated is a valid one
output pregno_t wo;				// next value to be assigned to o
output [6:0] o0;					// register to free from free list
output reg v;							// indicates o0 is valid
output reg stall;					// stall because no regs are available
output reg [7:0] headreg;	// register at head of fifo

wire empty;
wire [5:0] dout;
reg [7:0] din;
wire rd_rst_busy, wr_rst_busy;
reg rd_en, wr_en;

ffo96 uffo({32'd0,wlist2free}, o0);

always_comb v = o0!=7'd127;

always_comb stall = (empty && alloc && !(freeval|v));
// Debugging aid
always_comb headreg = {FIFONO,dout};


Qupls_rename_fifo3 ufifo1
(
  .rst(rst),
  .clk(clk),
  .din(din[5:0]),
  .wr(wr_en),
  .rd(rd_en),
  .dout(dout),
  .full(),
  .empty(empty)
);

always_ff @(posedge clk)
if (rst) begin
	o <= 8'd0;
	ov <= 1'b0;
	rd_en <= 1'b0;
	wr_en <= 1'b0;
	din <= 6'd0;
end
else begin
	rd_en <= 1'b0;
	wr_en <= 1'b0;
	ov <= 1'b0;
	if (en) begin
		if (alloc & ~(freeval|v) & ~stall) begin
			rd_en <= 1'b1;
			o <= {FIFONO[1:0],dout};
			ov <= 1'b1;
		end
		else if (freeval && alloc) begin
			o <= tag2free;
			ov <= 1'b1;
		end
		else if (v && alloc) begin
			o <= {FIFONO[1:0],o0[5:0]};
			ov <= 1'b1;
		end
		// If should not be possible to free up a register with tag zero because
		// freeval is set only for non-zero registers.
		else if (freeval) begin
			din <= tag2free;
			wr_en <= 1'b1;
			if (tag2free==8'd0) begin
				$display("Freeing zero register tag in fifo %d.", FIFONO);
				$finish;
			end
		end
		// It should not be possible to free register zero off the free list. This
		// register has a fixed status of marked as not free.
		else if (v) begin
			din <= {FIFONO[1:0],o0[5:0]};
			wr_en <= 1'b1;
			if ({FIFONO[1:0],o0[5:0]}==8'd0) begin
				$display("Freeing zero register off freelist in fifo %d.", FIFONO);
				$finish;
			end
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
			wo = {FIFONO[1:0],dout};
		else if (freeval && alloc)
			wo = tag2free;
		else if (v && alloc)
			wo = {FIFONO[1:0],o0[5:0]};
	end
end

endmodule
