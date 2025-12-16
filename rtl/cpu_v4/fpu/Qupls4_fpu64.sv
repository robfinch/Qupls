// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2025 Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//
// Qupls4_fpu64.sv
//	- FPU ops with a two cycle latency, resulting in a unit with a three
//    cycle latency.
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

import const_pkg::*;
import Qupls4_pkg::*;
import fp64Pkg::*;

module Qupls4_fpu64(rst, clk, clk3x, om, idle, ir, rm, a, b, c, t, s, i, o, sto, ust, done, exc);
parameter WID=64;
input rst;
input clk;
input clk3x;
input Qupls4_pkg::operating_mode_t om;
input idle;
input Qupls4_pkg::micro_op_t ir;
input [2:0] rm;
input [WID-1:0] a;
input [WID-1:0] b;
input [WID-1:0] c;
input [WID-1:0] t;
input fp_status_reg_t s;
input [WID-1:0] i;
output reg [WID-1:0] o;
output fp_status_reg_t sto;
output reg ust;			// update status
output reg done;
output Qupls4_pkg::cause_code_t exc;

Qupls4_pkg::micro_op_t ird;
Qupls4_pkg::fp_status_reg_t sd;
reg [11:0] cnt;
reg sincos_done, scale_done, f2i_done, i2f_done, sqrt_done, fres_done, trunc_done;
wire div_done;
reg [WID-1:0] bus;
fp_status_reg_t stbus;
FP64 fmao1, fmao2, fmao3, fmao4, fmao5, fmao6, fmao7;
FP64 scaleo, f2io, i2fo, signo2, cmpo2, divo, sqrto, freso, trunco;
FP64 fsgnj2,fsgnjn2,fsgnjx2;
FP64 fsgnj1,fsgnjn1,fsgnjx1;
FP64 fsgnj,fsgnjn,fsgnjx;
reg [WID-1:0] cmpo,cmpo1;
FP64 signo,signo1;
FP64 cvtS2Do2;
FP64 cvtS2Do,cvtS2Do1;
reg [WID-1:0] ando2,oro2,xoro2,addo2;
reg [WID-1:0] ando1,oro1,xoro1,addo1;
reg [WID-1:0] ando,oro,xoro,addo;
reg [WID-1:0] subfo2,movo2;
reg [WID-1:0] subfo,subfo1,movo,movo1,loadao,loadao1;
wire scaleb_over, scaleb_under;
wire f2iover;
wire i2f_inexact;
wire ce = 1'b1;
wire cd_args;
reg [WID-1:0] tmp;
wire [WID-1:0] ad,bd,id,cd,td;
wire [WID-1:0] zero = {WID{1'b0}};
reg [51:0] sigo;

FP64 fa,fb;
wire a_dn, b_dn;
wire az, bz;
wire aInf,bInf;
wire aNan,bNan;
wire asNan,bsNan;
wire aqNan,bqNan;
wire [2:0] a3;
wire fa_hidden,fb_hidden;

// Can issue every cycle, so...
always_comb
	done = 1'b1;

delay3 #(1) udlyust1 (.clk(clk), .ce(1'b1), .i(ir.f3.rc), .o(ust));
delay2 #(3) udlyrm2 (.clk(clk), .ce(1'b1), .i(a[2:0]), .o(a3));
delay2 #($bits(Qupls4_pkg::micro_op_t)) udlymo3 (.clk(clk), .ce(1'b1), .i(ir), .o(ird));
delay2 #($bits(Qupls4_pkg::fp_status_reg_t)) udlysd4 (.clk(clk), .ce(1'b1), .i(s), .o(sd));
delay2 #(WID) udlya5 (.clk(clk), .ce(1'b1), .i(a), .o(ad));
delay2 #(WID) udlyb6 (.clk(clk), .ce(1'b1), .i(b), .o(bd));
delay2 #(WID) udlyi7 (.clk(clk), .ce(1'b1), .i(i), .o(id));
delay2 #(WID) udlyc8 (.clk(clk), .ce(1'b1), .i(c), .o(cd));
delay2 #(WID) udlyt9 (.clk(clk), .ce(1'b1), .i(t), .o(td));

fpDecomp64Reg udc1a (
	.clk(clk),
	.ce(ce),
	.i(a),
	.sgn(fa.sign),
	.exp(fa.exp),
	.fract({fa_hidden,fa.sig}),
	.xz(a_dn),
	.vz(az),
	.inf(aInf),
	.nan(aNan),
	.snan(asNan),
	.qnan(aqNan)
);

always_ff @(posedge clk)
	if (ce)
		sigo <= fa.sig;


fpDecomp64 udc1b (
	.i(b),
	.sgn(fb.sign),
	.exp(fb.exp),
	.fract({fb_hidden,fb.sig}),
	.xz(b_dn),
	.vz(bz),
	.inf(bInf),
	.nan(bNan),
	.snan(bsNan),
	.qnan(bqNan)
);


Qupls4_cmp #(.WID(WID)) ualu_cmp
(
	.ir(ir),
	.om(om),
	.cr(64'd0),
	.a(a),
	.b(b),
	.i(i),
	.o(cmpo2)
);

always_ff @(posedge clk)
	if (ce)
		cmpo1 <= cmpo2;
always_ff @(posedge clk)
	if (ce)
		cmpo <= cmpo1;

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
	.o(scaleo),
	.over(scaleb_over),
	.under(scaleb_under)
);

fpCvt64ToI64 uf2i641
(
	.clk(clk),
	.ce(ce), 
	.op(1'b1),	// 1= signed, 0=unsigned
	.i(a),
	.o(f2io),
	.overflow(f2iover)
);

fpCvtI64To64 ui2f1
(
	.clk(clk),
	.ce(ce),
	.op(1'b1),	//1=signed, 0=unsigned
	.rm(rm),
	.i(a),
	.o(i2fo),
	.inexact(i2f_inexact)
);

fpSign64 usign1
(
	.a(a),
	.o(signo2)
);

always_ff @(posedge clk)
	if (ce)
		signo1 <= signo2;
always_ff @(posedge clk)
	if (ce)
		signo <= signo1;

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
	.i(a[31:0]),
	.o(cvtS2Do2)
);

always_ff @(posedge clk)
	if (ce)
		cvtS2Do1 <= cvtS2Do2;
always_ff @(posedge clk)
	if (ce)
		cvtS2Do <= cvtS2Do1;

// FSGNJ
always_ff @(posedge clk)
	if (ce)
		fsgnj1 <= {a[63],b[62:0]};
always_ff @(posedge clk)
	if (ce)
		fsgnj <= fsgnj1;
// FSGNJN
always_ff @(posedge clk)
	if (ce)
		fsgnjn1 <= {~a[63],b[62:0]};
always_ff @(posedge clk)
	if (ce)
		fsgnjn <= fsgnjn1;
// FSGNJX
always_ff @(posedge clk)
	if (ce)
		fsgnjx1 <= {a[63]^b[63],b[62:0]};
always_ff @(posedge clk)
	if (ce)
		fsgnjx <= fsgnjx1;

always_ff @(posedge clk)
	if (ce)
		movo1 <= movo2;
always_ff @(posedge clk)
	if (ce)
		movo <= movo1;

always_ff @(posedge clk)
	if (ce)
		loadao1 <= a + i + (b << ir[23:22]);
always_ff @(posedge clk)
	if (ce)
		loadao <= loadao1;

always_comb
begin
	bus = {WID{1'd0}};
	case(ird.any.opcode)
	Qupls4_pkg::OP_ADDI:	if (PERFORMANCE) bus = ad + id; else bus = zero;
	Qupls4_pkg::OP_SUBFI:	if (PERFORMANCE) bus = id - ad; else bus = zero;
	Qupls4_pkg::OP_ANDI:	if (PERFORMANCE) bus = ad & id; else bus = zero;
	Qupls4_pkg::OP_ORI:		if (PERFORMANCE) bus = ad | id; else bus = zero;
	Qupls4_pkg::OP_XORI:	if (PERFORMANCE) bus = ad ^ id; else bus = zero;
	Qupls4_pkg::OP_CMPI:	if (PERFORMANCE) bus = cmpo; else bus = zero;
	Qupls4_pkg::OP_R3O:
		if (PERFORMANCE)
			case(ird.r3.func)
			Qupls4_pkg::FN_ADD:
				case(ird.r3.op3)
				3'd0: bus = (ad + bd) & cd;
				3'd1: bus = (ad + bd) | cd;
				3'd2: bus = (ad + bd) ^ cd;
				3'd3:	bus = (ad + bd) + cd;
				3'd4:	bus = (ad + bd) << cd;
				3'd6:	bus = cd ? (ad + bd) : td;
				3'd7:	bus = cd ? (ad + bd) : bd;
				default:	bus = zero;
				endcase
			Qupls4_pkg::FN_CMP,
			Qupls4_pkg::FN_CMPU:
				case(ird.r3.op3)
				3'd0: bus = cmpo & cd;
				3'd1: bus = cmpo | cd;
				3'd2: bus = cmpo ^ cd;
				3'd3:	bus = cmpo + cd;
				3'd4:	bus = cmpo << cd;
				3'd6:	bus = cd ? cmpo : td;
				3'd7:	bus = cd ? cmpo : bd;
				default:	bus = zero;
				endcase
			Qupls4_pkg::FN_AND:
				case(ird.r3.op3)
				3'd0: bus = (ad & bd) & cd;
				3'd1: bus = (ad & bd) | cd;
				3'd2: bus = (ad & bd) ^ cd;
				3'd3:	bus = (ad & bd) + cd;
				3'd4:	bus = (ad & bd) << cd;
				3'd6:	bus = cd ? (ad & bd) : td;
				3'd7:	bus = cd ? (ad & bd) : bd;
				default:	bus = zero;
				endcase
			Qupls4_pkg::FN_OR:
				case(ird.r3.op3)
				3'd0: bus = (ad | bd) & cd;
				3'd1: bus = (ad | bd) | cd;
				3'd2: bus = (ad | bd) ^ cd;
				3'd3:	bus = (ad | bd) + cd;
				3'd4:	bus = (ad | bd) << cd;
				3'd6:	bus = cd ? (ad | bd) : td;
				3'd7:	bus = cd ? (ad | bd) : bd;
				default:	bus = zero;
				endcase
			Qupls4_pkg::FN_XOR:
				case(ird.r3.op3)
				3'd0: bus = (ad ^ bd) & cd;
				3'd1: bus = (ad ^ bd) | cd;
				3'd2: bus = (ad ^ bd) ^ cd;
				3'd3:	bus = (ad ^ bd) + cd;
				3'd4:	bus = (ad ^ bd) << cd;
				3'd6:	bus = cd ? (ad ^ bd) : td;
				3'd7:	bus = cd ? (ad ^ bd) : bd;
				default:	bus = zero;
				endcase
			default:	bus = zero;
			endcase
	Qupls4_pkg::OP_FLTH,Qupls4_pkg::OP_FLTS,Qupls4_pkg::OP_FLTD,Qupls4_pkg::OP_FLTQ,
	Qupls4_pkg::OP_FLTPH,Qupls4_pkg::OP_FLTPS,Qupls4_pkg::OP_FLTPD,Qupls4_pkg::OP_FLTPQ,
	Qupls4_pkg::OP_FLTP:
		case(ird.f3.func)
		Qupls4_pkg::FLT_SCALEB:	bus = scaleo;
		Qupls4_pkg::FLT_SGNJ:		bus = fsgnj;
		Qupls4_pkg::FLT_SGNJN:	bus = fsgnjn;
		Qupls4_pkg::FLT_SGNJX:	bus = fsgnjx;
		Qupls4_pkg::FLT_SIGN:		bus = signo;
		Qupls4_pkg::FLT_SIG:		bus = sigo;
		Qupls4_pkg::FLT_FTOI:		bus = f2io;
		Qupls4_pkg::FLT_ITOF:		bus = i2fo;
		Qupls4_pkg::FLT_TRUNC:	bus = trunco;
		Qupls4_pkg::FLT_RM:			bus = {61'd0,s.rm};
		default:	bus = zero;
		endcase
	/*
	OP_FLT:
		case(ir.fpu.op4)
		FOP4_G8:
		  case(ir.fpu.op3)
      FG8_FSGNJ:	bus = fsgnj;
      FG8_FSGNJN:	bus = fsgnjn;
      FG8_FSGNJX:	bus = fsgnjx;
  		FG8_FSCALEB:	bus = scaleo;
      default:	bus = 64'd0;
      endcase
    FOP4_G10:
      case (ir.fpu.Rs2)
			FG10_FCVTF2I:	 bus = f2io;
			FG10_FCVTI2F:	 bus = i2fo;
			FG10_FSIGN:    bus = signo;
			FG10_FTRUNC:	 bus = trunco;
      default:  bus = 64'd0;
      endcase
    default:  bus = 64'd0;
    endcase  
  */
  /*
	Qupls4_pkg::OP_ADD:	bus = addo;
	Qupls4_pkg::OP_AND:	bus = ando;
	Qupls4_pkg::OP_OR:		bus = oro;
	Qupls4_pkg::OP_XOR:	bus = xoro;
	Qupls4_pkg::OP_SUBF:	bus = subfo;
	Qupls4_pkg::OP_MOV:	bus = movo;
    */
	Qupls4_pkg::OP_LOADA:	bus = loadao;
	Qupls4_pkg::OP_NOP:		bus = t;	// in case of copy target
	default:	bus = 64'd0;
	endcase
end

always_comb
begin
	stbus = sd;
	case(ird.any.opcode)
	Qupls4_pkg::OP_FLTH,Qupls4_pkg::OP_FLTS,Qupls4_pkg::OP_FLTD,Qupls4_pkg::OP_FLTQ,
	Qupls4_pkg::OP_FLTPH,Qupls4_pkg::OP_FLTPS,Qupls4_pkg::OP_FLTPD,Qupls4_pkg::OP_FLTPQ,
	Qupls4_pkg::OP_FLTP:
		case(ird.f3.func)
		Qupls4_pkg::FLT_SGNJ:
			begin
				stbus.inexact = FALSE;
				stbus.dbz = FALSE;
				stbus.under = FALSE;
				stbus.over = FALSE;
				stbus.invop = FALSE;
				stbus.fractie = FALSE;
				stbus.rawayz = FALSE;
				stbus.c =
					(fsgnj.exp==11'd0 && fsgnj.sig != 52'd0) |	// denormal
					(fsgnj.sign && fsgnj[62:0]==63'd0) |				// negative zero
					(fsgnj.exp==11'h7ff && fsgnj.sig[51])				// quiet NaN
					;
				stbus.neg = fsgnj[WID-1] && fsgnj[WID-2:0]!=63'd0;
				stbus.pos = ~fsgnj[WID-1] && fsgnj[WID-2:0]!=63'd0;
				stbus.zero = fsgnj[WID-2:0]==63'd0;
				stbus.inf = fsgnj.exp==11'h7FF && fsgnj[WID-2:0]==63'd0;
				stbus.dbzx = FALSE;
				stbus.underx = FALSE;
				stbus.overx = FALSE;
				stbus.giopx = FALSE;
				stbus.gx = FALSE;
				stbus.sumx = FALSE;									
				stbus.nan_cause = 4'd0;
				stbus.cvt = FALSE;
				stbus.sqrtx = FALSE;
				stbus.nancmp = FALSE;
				stbus.infzero = FALSE;
				stbus.zerozero = FALSE;
				stbus.infdiv = FALSE;
				stbus.subinfx = FALSE;
				stbus.snanx = FALSE;
			end
		Qupls4_pkg::FLT_SGNJN:
			begin
				stbus.inexact = FALSE;
				stbus.dbz = FALSE;
				stbus.under = FALSE;
				stbus.over = FALSE;
				stbus.invop = FALSE;
				stbus.fractie = FALSE;
				stbus.rawayz = FALSE;
				stbus.c =
					(fsgnjn.exp==11'd0 && fsgnjn.sig != 52'd0) |	// denormal
					(fsgnjn.sign && fsgnjn[62:0]==63'd0) |				// negative zero
					(fsgnjn.exp==11'h7ff && fsgnjn.sig[51])				// quiet NaN
					;
				stbus.neg = fsgnjn[WID-1] && fsgnjn[WID-2:0]!=63'd0;
				stbus.pos = ~fsgnjn[WID-1] && fsgnjn[WID-2:0]!=63'd0;
				stbus.zero = fsgnjn[WID-2:0]==63'd0;
				stbus.inf = fsgnjn.exp==11'h7FF && fsgnjn[WID-2:0]==63'd0;
				stbus.dbzx = FALSE;
				stbus.underx = FALSE;
				stbus.overx = FALSE;
				stbus.giopx = FALSE;
				stbus.gx = FALSE;
				stbus.sumx = FALSE;									
				stbus.nan_cause = 4'd0;
				stbus.cvt = FALSE;
				stbus.sqrtx = FALSE;
				stbus.nancmp = FALSE;
				stbus.infzero = FALSE;
				stbus.zerozero = FALSE;
				stbus.infdiv = FALSE;
				stbus.subinfx = FALSE;
				stbus.snanx = FALSE;
			end
		Qupls4_pkg::FLT_SGNJX:
			begin
				stbus.inexact = FALSE;
				stbus.dbz = FALSE;
				stbus.under = FALSE;
				stbus.over = FALSE;
				stbus.invop = FALSE;
				stbus.fractie = FALSE;
				stbus.rawayz = FALSE;
				stbus.c =
					(fsgnjx.exp==11'd0 && fsgnjx.sig != 52'd0) |	// denormal
					(fsgnjx.sign && fsgnjx[62:0]==63'd0) |				// negative zero
					(fsgnjx.exp==11'h7ff && fsgnjx.sig[51])				// quiet NaN
					;
				stbus.neg = fsgnjx[WID-1] && fsgnjx[WID-2:0]!=63'd0;
				stbus.pos = ~fsgnjx[WID-1] && fsgnjx[WID-2:0]!=63'd0;
				stbus.zero = fsgnjx[WID-2:0]==63'd0;
				stbus.inf = fsgnjx.exp==11'h7FF && fsgnjx[WID-2:0]==63'd0;
				stbus.dbzx = FALSE;
				stbus.underx = FALSE;
				stbus.overx = FALSE;
				stbus.giopx = FALSE;
				stbus.gx = FALSE;
				stbus.sumx = FALSE;									
				stbus.nan_cause = 4'd0;
				stbus.cvt = FALSE;
				stbus.sqrtx = FALSE;
				stbus.nancmp = FALSE;
				stbus.infzero = FALSE;
				stbus.zerozero = FALSE;
				stbus.infdiv = FALSE;
				stbus.subinfx = FALSE;
				stbus.snanx = FALSE;
			end
		Qupls4_pkg::FLT_SCALEB:
			begin
				stbus.inexact = FALSE;
				stbus.dbz = FALSE;
				stbus.under = scaleb_under;
				stbus.over = scaleb_over;
				stbus.invop = FALSE;
				stbus.fractie = FALSE;
				stbus.rawayz = FALSE;
				stbus.c =
					(scaleo.exp==11'd0 && scaleo.sig != 52'd0) |	// denormal
					(scaleo.sign && scaleo[62:0]==63'd0) |				// negative zero
					(scaleo.exp==11'h7ff && scaleo.sig[51])				// quiet NaN
					;
				stbus.neg = scaleo[WID-1] && scaleo[WID-2:0]!=63'd0;
				stbus.pos = ~scaleo[WID-1] && scaleo[WID-2:0]!=63'd0;
				stbus.zero = scaleo[WID-2:0]==63'd0;
				stbus.inf = scaleo.exp==11'h7FF && scaleo[WID-2:0]==63'd0;
				stbus.dbzx = FALSE;
				stbus.underx = s.underxe & scaleb_under;
				stbus.overx = s.overxe & scaleb_over;
				stbus.giopx = FALSE;
				stbus.gx = FALSE;
				stbus.sumx = FALSE;									
				stbus.nan_cause = 4'd0;
				stbus.cvt = FALSE;
				stbus.sqrtx = FALSE;
				stbus.nancmp = FALSE;
				stbus.infzero = FALSE;
				stbus.zerozero = FALSE;
				stbus.infdiv = FALSE;
				stbus.subinfx = FALSE;
				stbus.snanx = FALSE;
			end
		Qupls4_pkg::FLT_SIGN:
			begin
				stbus.inexact = FALSE;
				stbus.dbz = FALSE;
				stbus.under = FALSE;
				stbus.over = FALSE;
				stbus.invop = FALSE;
				stbus.fractie = FALSE;
				stbus.rawayz = FALSE;
				stbus.c =
					(signo.exp==11'd0 && signo.sig != 52'd0) |	// denormal
					(signo.sign && signo[62:0]==63'd0) |				// negative zero
					(signo.exp==11'h7ff && signo.sig[51])				// quiet NaN
					;
				stbus.neg = signo[WID-1] && signo[WID-2:0]!=63'd0;
				stbus.pos = ~signo[WID-1] && signo[WID-2:0]!=63'd0;
				stbus.zero = signo[WID-2:0]==63'd0;
				stbus.inf = signo.exp==11'h7FF && signo[WID-2:0]==63'd0;
				stbus.dbzx = FALSE;
				stbus.underx = FALSE;
				stbus.overx = FALSE;
				stbus.giopx = FALSE;
				stbus.gx = FALSE;
				stbus.sumx = FALSE;									
				stbus.nan_cause = 4'd0;
				stbus.cvt = FALSE;
				stbus.sqrtx = FALSE;
				stbus.nancmp = FALSE;
				stbus.infzero = FALSE;
				stbus.zerozero = FALSE;
				stbus.infdiv = FALSE;
				stbus.subinfx = FALSE;
				stbus.snanx = FALSE;
			end
		Qupls4_pkg::FLT_FTOI:
			begin
				stbus.inexact = FALSE;
				stbus.dbz = FALSE;
				stbus.under = FALSE;
				stbus.over = f2iover;
				stbus.invop = FALSE;
				stbus.fractie = FALSE;
				stbus.rawayz = FALSE;
				stbus.c = FALSE;
				stbus.neg = f2io[WID-1];
				stbus.pos = ~f2io[WID-1];
				stbus.zero = f2io[WID-2:0]==64'd0;
				stbus.inf = FALSE;
				stbus.dbzx = FALSE;
				stbus.underx = FALSE;
				stbus.overx = s.overxe & f2iover;
				stbus.giopx = FALSE;
				stbus.gx = FALSE;
				stbus.sumx = FALSE;									
				stbus.nan_cause = 4'd0;
				stbus.cvt = FALSE;
				stbus.sqrtx = FALSE;
				stbus.nancmp = FALSE;
				stbus.infzero = FALSE;
				stbus.zerozero = FALSE;
				stbus.infdiv = FALSE;
				stbus.subinfx = FALSE;
				stbus.snanx = FALSE;
			end
		Qupls4_pkg::FLT_ITOF:
			begin
				stbus.inexact = i2f_inexact;
				stbus.dbz = FALSE;
				stbus.under = FALSE;
				stbus.over = f2iover;
				stbus.invop = FALSE;
				stbus.fractie = FALSE;
				stbus.rawayz = FALSE;
				stbus.c = FALSE;
				stbus.neg = i2fo[WID-1] && i2fo[WID-2:0]!=63'd0;
				stbus.pos = ~i2fo[WID-1] && i2fo[WID-2:0]!=63'd0;
				stbus.zero = i2fo[WID-2:0]==63'd0;
				stbus.inf = FALSE;
				stbus.dbzx = FALSE;
				stbus.underx = FALSE;
				stbus.overx = FALSE;
				stbus.giopx = FALSE;
				stbus.gx = FALSE;
				stbus.sumx = FALSE;									
				stbus.nan_cause = 4'd0;
				stbus.cvt = FALSE;
				stbus.sqrtx = FALSE;
				stbus.nancmp = FALSE;
				stbus.infzero = FALSE;
				stbus.zerozero = FALSE;
				stbus.infdiv = FALSE;
				stbus.subinfx = FALSE;
				stbus.snanx = FALSE;
			end
		Qupls4_pkg::FLT_RM:
			begin
				stbus.rm = fround_t'(a3[2:0]);
			end
		default:
			stbus = sd;
		endcase
	default:	;
	endcase
end

always_ff @(posedge clk)
	o <= bus;
always_ff @(posedge clk)
	sto <= stbus;

always_ff @(posedge clk)
	if (stbus.overx|stbus.underx|stbus.dbzx|stbus.giopx|stbus.gx|stbus.sumx)
		exc <= Qupls4_pkg::FLT_FLOAT;
	else
		exc <= Qupls4_pkg::FLT_NONE;

task tMove;
input Qupls4_pkg::micro_op_t ir;
output [WID-1:0] bus;
begin
	if (ir[31]) begin
		case(ir.move.op3)
		3'd0:	// MOVE / XCHG
			begin
				bus = a;	// MOVE
			end
		3'd1:	// XCHGMD / MOVEMD
			begin	
				bus = a;
			end
		3'd2:	bus = zero;		// MOVSX
		3'd3:	bus = zero;		// MOVZX
		3'd4:	bus = ~|a ? i : t;	// CMOVZ
		3'd5:	bus =  |a ? i : t;	// CMOVNZ
		3'd6:	bus = zero;		// BMAP
		default:
			begin
				bus = zero;
			end
		endcase
	end
	else
		case(ir.move.op3)
		3'd4:	bus = ~|a ? b : t;	// CMOVZ
		3'd5:	bus =  |a ? b : t;	// CMOVNZ
		default:
			begin
				bus = zero;
			end
		endcase
end
endtask

endmodule
