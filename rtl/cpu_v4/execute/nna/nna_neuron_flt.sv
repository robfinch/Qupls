// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2026  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	nna_neuron_flt.sv
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
// Values are represented as sign-magnitude fix point numbers for performance
// reasons.
//
// Core Parameters:
// Name:	 Default
// pInputs	  1024		number of inputs to neuron (should be a power of two).
// pAmsb		 9		most significant bit of memory address
//
// Data is fed to the neurons in a serial fashion.
// The adder tree propagation would limit the clock cycle time anyway. So we get
// rid of the adder tree by using serial addition and a faster clock. This
// allows us to have many more inputs per neuron. There is one block ram per
// neuron in order to store weights. There is a second block ram for the
// activation function.

import const_pkg::*;
import fp32Pkg::*;

module nna_neuron_flt(rst, clk, sync, wr, wa, wrb, wf, wrx, wrm, wrbc, i, o, done);
parameter pInputs = 1024;	// power of 2, 1024 or less
parameter pAmsb = 9;
input rst;
input clk;
input sync;						// begin calc
input wr;							// write to weights array
input [pAmsb:0] wa;		// write address
input wrb;						// write to bias value
input wf;							// write to feedback value
input wrx;						// write external input value
input wrm;						// write max count register
input wrbc;						// write base count register
input FP32 i;	// input
output FP32 o;
output reg done;

FP32 wmem [0:pInputs-1];
FP32 xmem [0:pInputs-1];
FP32 bias;
FP32 feedback;
FP32 sum,next_sum,sum_start;
FP32 sig_o;
reg [14:0] cnt;
reg [3:0] latcnt;
FP32 wb,xb;

reg [16:0] base_count = 17'd0;
reg [16:0] max_count = pInputs;

always_ff @(posedge clk)
	if (wr) wmem[wa[pAmsb:0]] <= i;
always_ff @(posedge clk)
	if (wrx) xmem[wa[pAmsb:0]] <= i;
always_ff @(posedge clk)
	if (wrb) bias <= i;
always_ff @(posedge clk)
	if (wf) feedback <= i;
always_ff @(posedge clk)
	if (wrbc) base_count <= i;
always_ff @(posedge clk)
	if (wrm) max_count <= i;

always_ff @(posedge clk)
begin
	wb <= wmem[cnt];
	xb <= xmem[cnt];
end

fpFMA32LN
(
	.clk(clk),
	.op(1'b0),
	.rm(3'b000),
	.a(o),
	.b(feedback),
	.c(bias),
	.o(sum_start),
	.inf(),
	.zero(),
	.overflow(),
	.underflow(),
	.inexact()
);

fpFMA32LN
(
	.clk(clk),
	.op(1'b0),
	.rm(3'b000),
	.a(wb),
	.b(xb),
	.c(sum),
	.o(next_sum),
	.inf(),
	.zero(),
	.overflow(),
	.underflow(),
	.inexact()
);

fpSigmoid32 usigm1
(
	.clk(clk),
	.ce(1'b1),
	.a(sum),
	.o(sig_o)
);

reg [2:0] state;
always_ff @(posedge clk)
begin
	if (rst) begin
		state <= 3'd0;
		o <= 32'd0;
		done <= TRUE;
	end
	if (sync) begin
		done <= FALSE;
		cnt <= base_count;
		latcnt <= 4'd5;
		state <= 3'd1;
	end
case(state)
3'd0:	;
3'd1:
	begin
		latcnt <= latcnt - 4'd1;
		if (latcnt==4'd0) begin
			latcnt <= 4'd5;
			sum <= sum_start;
			state <= 3'd2;
		end
	end
// Compute activation level.
3'd2:
	begin
		latcnt <= latcnt - 4'd1;
		if (latcnt==4'd0) begin
			cnt <= cnt + 2'd1;
			sum <= next_sum;
			if (cnt < max_count) begin
				latcnt <= 4'd5;
				state <= 3'd2;
			end
			else begin
				latcnt <= 4'd3;
				state <= 3'd3;
			end
		end
	end
3'd3:
	begin
		latcnt <= latcnt - 4'd1;
		if (latcnt==4'd0) begin
			done <= TRUE;
			o <= sig_o;
			state <= 3'd0;
		end
	end
endcase
end

endmodule
