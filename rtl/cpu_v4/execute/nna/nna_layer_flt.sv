// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2026  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	nna_layer_flt.sv
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

import cpu_types_pkg::*;
import Qupls4_pkg::*;

module nna_layer_flt(rst, clk, ir, a, b, o);
parameter N=8;
input rst;
input clk;
input micro_op_t ir;
input value_t a;
input value_t b;
output value_t o;

reg [31:0] wr;
reg [31:0] wrb;
reg [31:0] wf;
reg [31:0] wrx;
reg [31:0] wrm;
reg [31:0] wrbc;

wire [31:0] oa [0:63];
wire [63:0] done;
reg [63:0] sync;

always_ff @(posedge clk)
begin
if (rst) begin
	o <= 64'd0;
	sync <= 64'd0;
	wrbc <= 64'd0;
	wrm <= 64'd0;
	wf <= 64'd0;
	wrx <= 64'd0;
	wr <= 64'd0;
	wrb <= 32'd0;
end
	sync <= 64'd0;
case(ir.opcode)
OP_R3T:
	case(ir.func)
	FN_R1:
		case(ir.Rs2)
		R1_NNA_MFACT:	o <= oa[a[5:0]];
		R1_NNA_TRIG:	sync <= a;
		R1_NNA_STAT:	o <= done;
		default:	;
		endcase
	FN_NNA_MTBC:		wrbc <= b[31:0];
	FN_NNA_MTBIAS:	wrb <= b[31:0];
	FN_NNA_MTMC:		wrm <= b[31:0];	
	FN_NNA_MTFB:		wf <= b[31:0];
	FN_NNA_MTIN:		wrx <= b[63:32];
	FN_NNA_MTWT:		wr <= b[63:32];
	default:	;
	endcase
default:	;
endcase
end

genvar g;

generate begin : gLayer

for (g = 0; g < N; g = g + 1)	
nna_neuron_flt u1
(
	.rst(rst),
	.clk(clk),
	.sync(sync[g]),
	.wr(wr[g]),
	.wa(b[9:0]),
	.wrb(wrb[g]),
	.wf(wf[g]),
	.wrx(wrx[g]),
	.wrm(wrm[g]),
	.wrbc(wrbc[g]),
	.i(a[31:0]),
	.o(oa[g]),
	.done(done[g])
);
end
endgenerate

endmodule
