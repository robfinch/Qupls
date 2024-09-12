`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2013-2024  Robert Finch, Waterloo
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
// 6kLUTs / 3kFFs / 23 BRAMs (4w20r)
// The register file is time multiplexed and accessed four times using a six
// times CPU clock.
// ============================================================================
//
import QuplsPkg::*;

module Qupls_regfile4wNr(rst, clk, clk5x, ph4,
	wr0, wr1, wr2, wr3, we0, we1, we2, we3,
	wa0, wa1, wa2, wa3, i0, i1, i2, i3, 
	wt0, wt1, wt2, wt3, ti0, ti1, ti2, ti3,
	ra, o, to);
parameter WID = $bits(cpu_types_pkg::value_t);
parameter DEP = PREGS;
parameter RBIT = $clog2(DEP)-1;
parameter RPORTS = 20;
input rst;
input clk;
input clk5x;
input ph4;
input wr0;
input wr1;
input wr2;
input wr3;
input we0;
input we1;
input we2;
input we3;
input [RBIT:0] wa0;
input [RBIT:0] wa1;
input [RBIT:0] wa2;
input [RBIT:0] wa3;
input cpu_types_pkg::value_t i0;
input cpu_types_pkg::value_t i1;
input cpu_types_pkg::value_t i2;
input cpu_types_pkg::value_t i3;
input wt0;
input wt1;
input wt2;
input wt3;
input ti0;
input ti1;
input ti2;
input ti3;
input cpu_types_pkg::pregno_t [RPORTS-1:0] ra;
output cpu_types_pkg::value_t [RPORTS-1:0] o;
output reg [RPORTS-1:0] to;

cpu_types_pkg::value_t [RPORTS-1:0] o0;
reg [RPORTS-1:0] to0;

cpu_types_pkg::value_t [RPORTS/4-1:0] mo0;
reg [RPORTS/4-1:0] mto0;

reg wr;
reg we;
reg [RBIT:0] wa;
cpu_types_pkg::value_t i;
reg wt;
reg ti;

genvar g;
integer nn,mm,qq;

cpu_types_pkg::pregno_t [RPORTS/4-1:0] mra;
reg [1:0] cnt, cntd, cntd2;
reg [2:0] wcnt;

always_ff @(posedge clk5x)
if (rst) begin
	cnt <= 2'd0;
	cntd <= 2'd0;
end
else begin
	if (ph4)
		cnt <= 2'd0;
	else if (cnt < 2'd3)
		cnt <= cnt + 2'd1;
	cntd <= cnt;
	cntd2 <= cntd;
end

always_ff @(posedge clk5x)
if (rst) begin
	wcnt <= 3'd0;
end
else begin
	if (ph4)
		wcnt <= 3'd0;
	else if (wcnt < 3'd4)
		wcnt <= wcnt + 2'd1;
end

always_ff @(posedge clk5x)
begin
	for (nn = 0; nn < RPORTS/4; nn = nn + 1)	
		mra[nn] <= ra[(cnt*(RPORTS/4))+nn];
end

/*
always_ff @(posedge clk5x)
begin
	for (qq = 0; qq < RPORTS/4; qq = qq + 1)	begin
		o0[(cntd*(RPORTS/4))+qq] <= mo0[qq];
		to0[(cntd*(RPORTS/4))+qq] <= mto0[qq];
	end
end
*/

always_ff @(posedge clk5x)
begin
	for (mm = 0; mm < 4; mm = mm + 1) begin
		case(wcnt)
		3'd0:	begin wr <= wr0; we <= we0 && wa0!=10'd0; wa <= wa0; i <= i0; wt <= wt0; ti <= ti0; end
		3'd1:	begin wr <= wr1; we <= we1 && wa1!=10'd0; wa <= wa1; i <= i1; wt <= wt1; ti <= ti1;  end
		3'd2: begin wr <= wr2; we <= we2 && wa2!=10'd0; wa <= wa2; i <= i2; wt <= wt2; ti <= ti2;  end
		3'd3:	begin wr <= wr3; we <= we3 && wa3!=10'd0; wa <= wa3; i <= i3; wt <= wt3; ti <= ti3;  end
		default:	begin wr <= 1'b1; we <= 1'b1; wa <= {RBIT+1{1'd0}}; i <= {WID{1'b0}}; wt <= 1'b1; ti <= 1'b0; end
		endcase
	end
end

generate begin : gRF
	for (g = 0; g < RPORTS; g = g + 1) begin
		Qupls_regfileRam #(.WID(WID)) urf0 (
		  .clka(clk5x),
		  .ena(wr),
		  .wea(we),
		  .addra(wa),
		  .dina(i),
		  .clkb(~clk),
		  .enb(1'b1),
		  .addrb(ra[g]),
		  .doutb(o0[g])
		);
		/*
		Qupls_regfileRam #(.WID(1)) utrf0 (
		  .clka(clk5x),
		  .ena(wr),
		  .wea(wt),
		  .addra(wa),
		  .dina(ti),
		  .clkb(clk5x),
		  .enb(1'b1),
		  .addrb(mra[g]),
		  .doutb(mto0[g])
		);
		*/
	end
end
endgenerate

integer n;

generate begin : gRFO
	for (g = 0; g < RPORTS; g = g + 1) begin
		always_comb
			o[g] =
				(wr3 && we3 && wa3 != 10'd0 && (ra[g]==wa3)) ? i3 :
				(wr2 && we2 && wa2 != 10'd0 && (ra[g]==wa2)) ? i2 :
				(wr1 && we1 && wa1 != 10'd0 && (ra[g]==wa1)) ? i1 :
				(wr0 && we0 && wa0 != 10'd0 && (ra[g]==wa0)) ? i0 :
					o0[g];
		always_comb
			to[g] = (wt3 && we3 && wa3 != 10'd0 && (ra[g]==wa3)) ? ti3 :
							(wt2 && we2 && wa2 != 10'd0 && (ra[g]==wa2)) ? ti2 :
							(wt1 && we1 && wa1 != 10'd0 && (ra[g]==wa1)) ? ti1 :
							(wt0 && we0 && wa0 != 10'd0 && (ra[g]==wa0)) ? ti0 :
					to0[g];
		always_ff @(posedge clk)
			if (o[g] != cpu_types_pkg::value_zero && ra[g]==10'd0) begin
				$display("Q+: r0 is not zero.");
				$finish;
			end
	end
end
endgenerate

endmodule
