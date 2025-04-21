// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2025 Robert Finch, Waterloo
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

import Stark_pkg::*;
//import fp64Pkg::*;

module Stark_fpu64(rst, clk, clk3x, idle, ir, rm, a, b, c, t, i, p, o, done, exc);
parameter WID=64;
input rst;
input clk;
input clk3x;
input idle;
input Stark_pkg::instruction_t ir;
input [2:0] rm;
input [WID-1:0] a;
input [WID-1:0] b;
input [WID-1:0] c;
input [WID-1:0] t;
input [WID-1:0] i;
input [WID-1:0] p;
output reg [WID-1:0] o;
output reg done;
output Stark_pkg::cause_code_t exc;

reg [11:0] cnt;
reg sincos_done, scale_done, f2i_done, i2f_done, sqrt_done, fres_done, trunc_done;
wire div_done;
reg [WID-1:0] bus;
reg [WID-1:0] fmao1, fmao2, fmao3, fmao4, fmao5, fmao6, fmao7;
wire [WID-1:0] scaleo, f2io, i2fo, signo, cmpo, divo, sqrto, freso, trunco;
wire [WID-1:0] cvtS2Do;
wire ce = 1'b1;
wire cd_args;

Stark_cmp #(.WID(WID)) ualu_cmp(ir, a, b, i, cmpo);

// A change in arguments is used to load the divider.
change_det #(.WID(128)) uargcd0 (
	.rst(rst),
	.clk(clk),
	.ce(ce),
	.i({a,b}),
	.cd(cd_args)
);

fpScaleb64 uscal1
(
	.clk(clk),
	.ce(ce),
	.a(a),
	.b(b),
	.o(scaleo)
);

wire [WID-1:0] sino, coso;

fpSincos64 usincos1
(
	.rst(rst),
	.clk(clk),
	.rm(rm),
	.ld(cd_args),
	.a(a),
	.sin(sino),
	.cos(coso)
);

reg fmaop, fma_done;
reg [WID-1:0] fmac;
reg [WID-1:0] fmab;
reg [WID-1:0] fmao;
/*
always_comb
	if (ir.f3.func==FN_FMS || ir.f3.func==FN_FNMS)
		fmaop = 1'b1;
	else
		fmaop = 1'b0;
*/
always_comb
	if (ir.fpu.op4==Stark_pkg::FOP4_FADD || ir.fpu.op4==Stark_pkg::FOP4_FSUB)
		fmab <= 64'h3FF0000000000000;	// 1,0
	else
		fmab <= b;

always_comb
	if (ir.fpu.op4==FOP4_FMUL || ir.fpu.op4==FOP4_FDIV)
		fmac = 64'd0;
	else
		fmac = c;

fpFMA64nrL8 ufma1
(
	.clk(clk),
	.ce(ce),
	.op(fmaop),
	.rm(rm),
	.a(a),
	.b(fmab),
	.c(fmac),
	.o(fmao),
	.inf(),
	.zero(),
	.overflow(),
	.underflow(),
	.inexact()
);

/*
fpFMA64nrCombo ufma1
(
	.op(fmaop),
	.rm(rm),
	.a(a),
	.b(fmab),
	.c(fmac),
	.o(fmao1),
	.inf(),
	.zero(),
	.overflow(),
	.underflow(),
	.inexact()
);

// Retiming pipeline
always_ff @(posedge clk, posedge rst)
if (rst) begin
	fmao2 <= 'd0;
	fmao3 <= 'd0;
	fmao4 <= 'd0;
	fmao5 <= 'd0;
	fmao6 <= 'd0;
	fmao7 <= 'd0;
	fmao <= 'd0;
end
else if (ce) begin
	fmao2 <= fmao1;
	fmao3 <= fmao2;
	fmao4 <= fmao3;
	fmao5 <= fmao4;
	fmao6 <= fmao5;
	fmao7 <= fmao6;
	fmao <= fmao7;
end
*/

/*
fpDivide64nr udiv1
(
	.rst(rst),
	.clk(clk),
	.clk4x(clk),
	.ce(ce),
	.ld(cd_args),
	.op(1'b0),			// not used
	.a(a),
	.b(b),
	.o(divo),
	.rm(rm),
	.done(div_done),
	.sign_exe(),
	.inf(),
	.overflow(),
	.underflow()
);
*/

f2i64 uf2i641
(
	.clk(clk),
	.ce(ce), 
	.op(1'b1),	// 1= signed, 0=unsigned
	.i(a),
	.o(f2io),
	.overflow()
);

fpCvtI64To64 ui2f1
(
	.clk(clk),
	.ce(ce),
	.op(1'b1),	//1=signed, 0=unsigned
	.rm(rm),
	.i(a),
	.o(i2fo),
	.inexact()
);

fpSign64 usign1
(
	.a(a),
	.o(signo)
);

/*
fpCompare64 ucmp1
(
	.a(a),
	.b(b),
	.o(cmpo),
	.inf(),
	.nan(),
	.snan()
);
*/

fpSqrt64nr usqrt1
(
	.rst(rst),
	.clk(clk),
	.ce(ce),
	.ld(cd_args),
	.a(a),
	.o(sqrto),
	.rm(rm),
	.done(),
	.inf(),
	.sqrinf(),
	.sqrneg()
);


fpRes64 ufre1
(
	.clk(clk),
	.ce(ce),
	.a(a),
	.o(freso)
);

fpTrunc64 utrunc1
(	
	.clk(clk),
	.ce(ce),
	.i(a),
	.o(trunco)
);

fpCvt32To64 ucvtS2D1
(
	.i(a),
	.o(cvtS2Do)
);

always_ff @(posedge clk)
if (rst) begin
	cnt <= 'd0;
	sincos_done <= 1'b0;
	fma_done <= 1'b0;
	scale_done <= 1'b0;
	f2i_done <= 'd0;
	i2f_done <= 'd0;
	sqrt_done <= 'd0;
	fres_done <= 'd0;
	trunc_done <= 'd0;
end
else begin
	if (cd_args)
		cnt <= 'd0;
	else
		cnt <= cnt + 2'd1;
	sincos_done <= cnt>=12'd64;
	fma_done <= cnt>=12'h8;
	scale_done <= cnt>=12'h3;
	f2i_done <= cnt>=12'h2;
	i2f_done <= cnt>=12'h2;
	sqrt_done <= cnt >= 12'd121;
	fres_done <= cnt >= 12'h002;
	trunc_done <= cnt >= 12'h001;
end

always_comb
begin
	bus = 'd0;
	case(ir.any.opcode)
	OP_FLT:
		case(ir.fpu.op4)
		/*
		FN_FLT1:
			case(ir.f1.func)
			FN_ISNAN:	bus = &a[62:52] && |a[51:0];
			FN_FINITE:	bus = ~&a[62:52];
			FN_FRES:	bus = freso;
			FN_FCVTS2D:	bus = cvtS2Do;
			default:	bus = 'd0;
			endcase
		*/
		FOP4_FADD,FOP4_FSUB,FOP4_FMUL:
			bus = fmao;
		/*
		FN_FDIV:
			bus = divo;
		*/
		FOP4_G8:
		  case(ir.fpu.op3)
      FG8_FSGNJ:	bus = {a[63],b[62:0]};
      FG8_FSGNJN:	bus = {~a[63],b[62:0]};
      FG8_FSGNJX:	bus = {a[63]^b[63],b[62:0]};
  		FG8_FSCALEB:	bus = scaleo;
      default:	bus = 64'd0;
      endcase
    FOP4_G10:
      case (ir.fpu.op3)
			FG10_FCVTF2I:	 bus = f2io;
			FG10_FCVTI2F:	 bus = i2fo;
			FG10_FSIGN:    bus = signo;
			FG10_FSQRT:	   bus = sqrto;
			FG10_FTRUNC:	 bus = trunco;
      default:  bus = 64'd0;
      endcase
    FOP4_TRIG:
      case(ir.fpu.op3)
			FTRIG_FSIN:	bus = sino;
			FTRIG_FCOS:	bus = coso;
      default:  bus = 64'd0;
      endcase
    default:  bus = 64'd0;
    endcase  
	OP_ADD:	 bus = a + i;
	OP_CMP:	 bus = cmpo;
	OP_AND:	 bus = a & i;
	OP_OR:		bus = a | i;
	OP_XOR:	   bus = a ^ i;
	OP_MOV:		bus = a;
	OP_NOP:		bus = 64'd0;
	default:	bus = 64'd0;
	endcase
end

always_ff @(posedge clk)
	case(ir.any.opcode)
	OP_FLT:
		case(ir.fpu.op4)
		/*
		FN_FLT1:
			case(ir.f1.func)
//			FN_FSQRT: done = sqrt_done;
			FN_FRES:	done = fres_done;
			default:	done = 1'b1;
			endcase
		*/
		FOP4_G8:
		  case(ir.fpu.op3)
		  FG8_FSCALEB: done = scale_done;
		  default: done = 1'b1;
			endcase
		FOP4_G10:
		  case (ir.fpu.op3)
			FG10_FCVTF2I: done = f2i_done;
			FG10_FCVTI2F: done = i2f_done;
			FG10_FTRUNC:	done = trunc_done;
			default: done = 1'b1;
		  endcase
		FOP4_TRIG:
		  case(ir.fpu.op3)
			FTRIG_FSIN:	done = sincos_done;
			FTRIG_FCOS:	done = sincos_done;
		  endcase
		FOP4_FADD,FOP4_FSUB,FOP4_FMUL:
			done = fma_done;
		/*
		FN_FDIV:
			done = div_done;
		*/
		default:	done = 1'b1;
		endcase
	OP_ADD:	done = 1'b1;
	OP_CMP:	done = 1'b1;
	OP_AND:	done = 1'b1;
	OP_OR:		done = 1'b1;
	OP_XOR:	done = 1'b1;
	OP_MOV:		done = 1'b1;
	OP_NOP:		done = 1'b1;
	default:	done = 1'b1;
	endcase

always_ff @(posedge clk)
	o = bus;
	/*
	if (p[0])
		o = bus;
	else
		o = t;
	*/
always_comb
	exc = Stark_pkg::FLT_NONE;

endmodule
