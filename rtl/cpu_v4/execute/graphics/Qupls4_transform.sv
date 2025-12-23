// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2025  Robert Finch, Waterloo
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
// 12725 LUTs / 15200 FFs / 20 DSPs	(Float32)
// 1020 LUTs / 1020 FFs / 36 DSPs 	(fixed point)
// ============================================================================

/*

Input matrix M:
    | aa ab ac tx |
M = | ba bb bc ty |
    | ca cb cc tz |

Input point X:
    | x |
X = | y |
    | z |
    | 1 |

Output point X':
     | x' |        | aa*x + ab*y + ac*z + tx |
X' = | y' | = MX = | ba*x + bb*y + bc*z + ty |
     | z' |        | ca*x + cb*y + cc*z + tz |

*/

import cpu_types_pkg::*;
import fp32Pkg::*;

module Qupls4_transform(rst, clk, op, ld, wr, a, b, o, done);
input rst;
input clk;
input [1:0] op;
input ld;
input wr;
input cpu_types_pkg::value_t a;
input cpu_types_pkg::value_t b;
output cpu_types_pkg::value_t o;
output reg done;
parameter FLOAT = 1'b1;

reg [7:0] dnp;	// done pipe
parameter point_width = 18;
parameter subpixel_width = 18;

reg signed [point_width-1:-subpixel_width] p0_x_o;
reg signed [point_width-1:-subpixel_width] p0_y_o;
reg signed               [point_width-1:0] p0_z_o;
reg signed [point_width-1:-subpixel_width] p1_x_o;
reg signed [point_width-1:-subpixel_width] p1_y_o;
reg signed               [point_width-1:0] p1_z_o;
reg signed [point_width-1:-subpixel_width] p2_x_o;
reg signed [point_width-1:-subpixel_width] p2_y_o;
reg signed               [point_width-1:0] p2_z_o;

wire [subpixel_width-1:0] zeroes = 1'b0;

/*
wire signed [2*point_width-1:-subpixel_width*2] x_prime = aax + aby + acz + {tx,zeroes};
wire signed [2*point_width-1:-subpixel_width*2] y_prime = bax + bby + bcz + {ty,zeroes};
wire signed [2*point_width-1:-subpixel_width*2] z_prime = cax + cby + ccz + {tz,zeroes};
*/
/*
wire signed [point_width-1:-subpixel_width] x_prime_trunc = x_prime[point_width-1:-subpixel_width];
wire signed [point_width-1:-subpixel_width] y_prime_trunc = y_prime[point_width-1:-subpixel_width];
wire signed [point_width-1:-subpixel_width] z_prime_trunc = z_prime[point_width-1:-subpixel_width];
*/
reg upd1;

reg signed [point_width-1:-subpixel_width] x_i;
reg signed [point_width-1:-subpixel_width] y_i;
reg signed [point_width-1:-subpixel_width] z_i;

reg signed [point_width-1:-subpixel_width] x_o;
reg signed [point_width-1:-subpixel_width] y_o;
reg signed [point_width-1:-subpixel_width] z_o;

reg signed [point_width-1:-subpixel_width] aa;
reg signed [point_width-1:-subpixel_width] ab;
reg signed [point_width-1:-subpixel_width] ac;
reg signed [point_width-1:-subpixel_width] tx;
reg signed [point_width-1:-subpixel_width] ba;
reg signed [point_width-1:-subpixel_width] bb;
reg signed [point_width-1:-subpixel_width] bc;
reg signed [point_width-1:-subpixel_width] ty;
reg signed [point_width-1:-subpixel_width] ca;
reg signed [point_width-1:-subpixel_width] cb;
reg signed [point_width-1:-subpixel_width] cc;
reg signed [point_width-1:-subpixel_width] tz;

reg signed [2*point_width-1:-subpixel_width*2] aax;
reg signed [2*point_width-1:-subpixel_width*2] aby;
reg signed [2*point_width-1:-subpixel_width*2] acz;
reg signed [2*point_width-1:-subpixel_width*2] bax;
reg signed [2*point_width-1:-subpixel_width*2] bby;
reg signed [2*point_width-1:-subpixel_width*2] bcz;
reg signed [2*point_width-1:-subpixel_width*2] cax;
reg signed [2*point_width-1:-subpixel_width*2] cby;
reg signed [2*point_width-1:-subpixel_width*2] ccz;

wire signed [2*point_width-1:-subpixel_width*2] x_prime = aax + aby + acz + {tx,zeroes};
wire signed [2*point_width-1:-subpixel_width*2] y_prime = bax + bby + bcz + {ty,zeroes};
wire signed [2*point_width-1:-subpixel_width*2] z_prime = cax + cby + ccz + {tz,zeroes};

wire signed [point_width-1:-subpixel_width] x_prime_trunc = x_prime[point_width-1:-subpixel_width];
wire signed [point_width-1:-subpixel_width] y_prime_trunc = y_prime[point_width-1:-subpixel_width];
wire signed [point_width-1:-subpixel_width] z_prime_trunc = z_prime[point_width-1:-subpixel_width];

FP32 fx_i, fy_i, fz_i;
FP32 fx_o, fy_o, fz_o;
FP32 faa,fab,fac,ftx;
FP32 fba,fbb,fbc,fty;
FP32 fca,fcb,fcc,ftz;
FP32 faax, faby, facz;
FP32 fbax, fbby, fbcz;
FP32 fcax, fcby, fccz;
FP32 s1,s2,s4,s5,s7,s8;
FP32 fx_prime, fy_prime, fz_prime;

fpAddsub32nr uaax_p_aby	(.clk(clk), .ce(1'b1), .rm(3'd0), .op(1'b0), .a(faax), .b(faby),	.o(s1));
fpAddsub32nr uacz_p_txz	(.clk(clk), .ce(1'b1), .rm(3'd0), .op(1'b0), .a(facz), .b(ftx),	.o(s2));
fpAddsub32nr us1_p_s2		(.clk(clk), .ce(1'b1), .rm(3'd0), .op(1'b0), .a(s1),  .b(s2),	  .o(fx_prime));

fpAddsub32nr ubax_p_bby	(.clk(clk), .ce(1'b1), .rm(3'd0), .op(1'b0), .a(fbax), .b(fbby),	.o(s4));
fpAddsub32nr ubcz_p_tyz	(.clk(clk), .ce(1'b1), .rm(3'd0), .op(1'b0), .a(fbcz), .b(fty),	.o(s5));
fpAddsub32nr us4_p_s5		(.clk(clk), .ce(1'b1), .rm(3'd0), .op(1'b0), .a(s4),  .b(s5),	  .o(fy_prime));

fpAddsub32nr ucax_p_cby	(.clk(clk), .ce(1'b1), .rm(3'd0), .op(1'b0), .a(fcax), .b(fcby),	.o(s7));
fpAddsub32nr uccz_p_tzz	(.clk(clk), .ce(1'b1), .rm(3'd0), .op(1'b0), .a(fccz), .b(ftz),	.o(s8));
fpAddsub32nr us7_p_s8		(.clk(clk), .ce(1'b1), .rm(3'd0), .op(1'b0), .a(s7),  .b(s8),	  .o(fz_prime));

fpMultiply32nr um1 (.clk(clk), .ce(1'b1), .a(faa), .b(fx_i), .o(faax), .rm(3'd0), .sign_exe(), .inf(), .overflow(), .underflow());
fpMultiply32nr um2 (.clk(clk), .ce(1'b1), .a(fab), .b(fy_i), .o(faby), .rm(3'd0), .sign_exe(), .inf(), .overflow(), .underflow());
fpMultiply32nr um3 (.clk(clk), .ce(1'b1), .a(fac), .b(fz_i), .o(facz), .rm(3'd0), .sign_exe(), .inf(), .overflow(), .underflow());
fpMultiply32nr um4 (.clk(clk), .ce(1'b1), .a(fba), .b(fx_i), .o(fbax), .rm(3'd0), .sign_exe(), .inf(), .overflow(), .underflow());
fpMultiply32nr um5 (.clk(clk), .ce(1'b1), .a(fbb), .b(fy_i), .o(fbby), .rm(3'd0), .sign_exe(), .inf(), .overflow(), .underflow());
fpMultiply32nr um6 (.clk(clk), .ce(1'b1), .a(fbc), .b(fz_i), .o(fbcz), .rm(3'd0), .sign_exe(), .inf(), .overflow(), .underflow());
fpMultiply32nr um7 (.clk(clk), .ce(1'b1), .a(fca), .b(fx_i), .o(fcax), .rm(3'd0), .sign_exe(), .inf(), .overflow(), .underflow());
fpMultiply32nr um8 (.clk(clk), .ce(1'b1), .a(fcb), .b(fy_i), .o(fcby), .rm(3'd0), .sign_exe(), .inf(), .overflow(), .underflow());
fpMultiply32nr um9 (.clk(clk), .ce(1'b1), .a(fcc), .b(fz_i), .o(fccz), .rm(3'd0), .sign_exe(), .inf(), .overflow(), .underflow());

always_comb
	done <= FLOAT ? dnp==8'd100 : dnp==8'd003;

always_ff @(posedge clk)
if (rst) begin
	upd1 <= 'd0;
  p0_x_o <= 32'b0;
  p0_y_o <= 32'b0;
  p0_z_o <= 32'b0;
  p1_x_o <= 32'b0;
  p1_y_o <= 32'b0;
  p1_z_o <= 32'b0;
  p2_x_o <= 32'b0;
  p2_y_o <= 32'b0;
  p2_z_o <= 32'b0;
  aax <= 32'b0;
  aby <= 32'b0;
  acz <= 32'b0;
  bax <= 32'b0;
  bby <= 32'b0;
  bcz <= 32'b0;
  cax <= 32'b0;
  cby <= 32'b0;
  ccz <= 32'b0;

	dnp <= FLOAT ? 8'd100 : 8'd003;
end
else begin
	if (dnp < 8'd100)
		dnp <= dnp + 8'd1;
	upd1 <= op==2'd3;
	if (wr && op==2'd3) begin
		if (FLOAT)
			case(a[3:0])
			4'd0:	faa <= b[31:0];
			4'd1:	fab <= b[31:0];
			4'd2:	fac <= b[31:0];
			4'd3:	ftx <= b[31:0];
			4'd4:	fba <= b[31:0];
			4'd5:	fbb <= b[31:0];
			4'd6:	fbc <= b[31:0];
			4'd7:	fty <= b[31:0];
			4'd8:	fca <= b[31:0];
			4'd9:	fcb <= b[31:0];
			4'd10:	fcc <= b[31:0];
			4'd11:	ftz <= b[31:0];
			default:	;
			endcase
		else
			case(a[3:0])
			4'd0:	aa <= b[35:0];
			4'd1:	ab <= b[35:0];
			4'd2:	ac <= b[35:0];
			4'd3:	tx <= b[35:0];
			4'd4:	ba <= b[35:0];
			4'd5:	bb <= b[35:0];
			4'd6:	bc <= b[35:0];
			4'd7:	ty <= b[35:0];
			4'd8:	ca <= b[35:0];
			4'd9:	cb <= b[35:0];
			4'd10:	cc <= b[35:0];
			4'd11:	tz <= b[35:0];
			default:	;
			endcase
	end
	if (op==2'd3) begin
		if (FLOAT)
			case(a[3:0])
			4'd0:	o <= faa;
			4'd1:	o <= fab;
			4'd2:	o <= fac;
			4'd3:	o <= ftx;
			4'd4:	o <= fba;
			4'd5:	o <= fbb;
			4'd6:	o <= fbc;
			4'd7:	o <= fty;
			4'd8:	o <= fca;
			4'd9:	o <= fcb;
			4'd10:	o <= fcc;
			4'd11:	o <= ftz;
			default:	o <= 'd0;
			endcase
		else
			case(a[3:0])
			4'd0:	o <= aa;
			4'd1:	o <= ab;
			4'd2:	o <= ac;
			4'd3:	o <= tx;
			4'd4:	o <= ba;
			4'd5:	o <= bb;
			4'd6:	o <= bc;
			4'd7:	o <= ty;
			4'd8:	o <= ca;
			4'd9:	o <= cb;
			4'd10:	o <= cc;
			4'd11:	o <= tz;
			default:	o <= 'd0;
			endcase
	end
	if (op!=3'd3) begin
		if (FLOAT)
			case(op)
			2'd0:	o <= fx_o;
			2'd1:	o <= fy_o;
			2'd2:	o <= fz_o;
			default:	o <= 'd0;
			endcase
		else
			case(op)
			2'd0:	o <= x_o;
			2'd1:	o <= y_o;
			2'd2:	o <= z_o;
			default:	o <= 'd0;
			endcase
	end
	
	if (ld) begin
		if (FLOAT) begin
			fx_i = a[31: 0];
			fy_i = a[63:32];
			fz_i = b[31: 0];
		end
		else begin
			x_i = a[31: 0];
			y_i = a[63:32];
			z_i = b[31: 0];
		end
		dnp <= 8'd0;
	end

	if (!FLOAT) begin
	  aax <= aa * x_i;
	  aby <= ab * y_i;
	  acz <= ac * z_i;
	  bax <= ba * x_i;
	  bby <= bb * y_i;
	  bcz <= bc * z_i;
	  cax <= ca * x_i;
	  cby <= cb * y_i;
	  ccz <= cc * z_i;
		x_o <= x_prime_trunc;
		y_o <= y_prime_trunc;
		z_o <= z_prime_trunc;
	end
	else begin
		fx_o <= fx_prime;
		fy_o <= fy_prime;
		fz_o <= fz_prime;
	end
end

endmodule
