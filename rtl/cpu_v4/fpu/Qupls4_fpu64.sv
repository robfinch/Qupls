// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2025 Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//
// Qupls4_fpu64.sv
//	- FPU ops with a two cycle latency
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

import Qupls4_pkg::*;
//import fp64Pkg::*;

module Qupls4_fpu64(rst, clk, clk3x, om, idle, ir, rm, a, b, c, t, i, p, o, done, exc);
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
input [WID-1:0] i;
input [WID-1:0] p;
output reg [WID-1:0] o;
output reg done;
output Qupls4_pkg::cause_code_t exc;

reg [11:0] cnt;
reg sincos_done, scale_done, f2i_done, i2f_done, sqrt_done, fres_done, trunc_done;
wire div_done;
reg [WID-1:0] bus;
reg [WID-1:0] fmao1, fmao2, fmao3, fmao4, fmao5, fmao6, fmao7;
wire [WID-1:0] scaleo, f2io, i2fo, signo2, cmpo2, divo, sqrto, freso, trunco;
wire [WID-1:0] fsgnj2,fsgnjn2,fsgnjx2;
reg [WID-1:0] fsgnj1,fsgnjn1,fsgnjx1;
reg [WID-1:0] fsgnj,fsgnjn,fsgnjx;
reg [WID-1:0] cmpo,cmpo1;
reg [WID-1:0] signo,signo1;
wire [WID-1:0] cvtS2Do2;
reg [WID-1:0] cvtS2Do,cvtS2Do1;
reg [WID-1:0] ando2,oro2,xoro2,addo2;
reg [WID-1:0] ando1,oro1,xoro1,addo1;
reg [WID-1:0] ando,oro,xoro,addo;
reg [WID-1:0] subfo2,movo2;
reg [WID-1:0] subfo,subfo1,movo,movo1,loadao,loadao1;
wire ce = 1'b1;
wire cd_args;
reg [WID-1:0] tmp;
wire [WID-1:0] zero = {WID{1'b0}};

FP64 fa,fb;
wire a_dn, b_dn;
wire az, bz;
wire aInf,bInf;
wire aNan,bNan;
wire asNan,bsNan;
wire aqNan,bqNan;

fpDecomp64 udc1a (
	.i(a),
	.sgn(fa.sign),
	.exp(fa.exp),
	.fract(fa.sig),
	.xz(a_dn),
	.vz(az),
	.inf(aInf),
	.nan(aNan),
	.snan(asNan),
	.qnan(aqNan)
);

fpDecomp64 udc1b (
	.i(b),
	.sgn(fb.sign),
	.exp(fb.exp),
	.fract(fb.sig),
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
	.o(scaleo)
);

fpCvt64ToI64 uf2i641
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
		fsgnj1 <= {~a[63],b[62:0]};
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

always_comb
	tAdd(ir,addo2);
always_ff @(posedge clk)
	if (ce)
		addo1 <= addo2;
always_ff @(posedge clk)
	if (ce)
		addo <= addo1;

always_comb
	tSubf(ir,subfo2);
always_ff @(posedge clk)
	if (ce)
		subfo1 <= subfo2;
always_ff @(posedge clk)
	if (ce)
		subfo <= subfo1;

always_comb
	tAnd(ir,ando2);
always_ff @(posedge clk)
	if (ce)
		ando1 <= ando2;
always_ff @(posedge clk)
	if (ce)
		ando <= ando1;

always_comb
	tOr(ir,oro2);
always_ff @(posedge clk)
	if (ce)
		oro1 <= oro2;
always_ff @(posedge clk)
	if (ce)
		oro <= oro1;

always_comb
	tXor(ir,xoro2);
always_ff @(posedge clk)
	if (ce)
		xoro1 <= xoro2;
always_ff @(posedge clk)
	if (ce)
		xoro <= xoro1;

always_comb
	tMove(ir,movo2);
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
	case(ir.any.opcode)
	Qupls4_pkg::OP_FLTH,Qupls4_pkg::OP_FLTS,Qupls4_pkg::OP_FLTD,Qupls4_pkg::OP_FLTQ,
	Qupls4_pkg::OP_FLTPH,Qupls4_pkg::OP_FLTPS,Qupls4_pkg::OP_FLTPD,Qupls4_pkg::OP_FLTPQ,
	Qupls4_pkg::OP_FLTP:
		case(ir.f3.func)
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
	Qupls4_pkg::OP_CMP:	bus = cmpo;
	Qupls4_pkg::OP_MOV:	bus = movo;
    */
	Qupls4_pkg::OP_LOADA:	bus = loadao;
	Qupls4_pkg::OP_NOP:		bus = t;	// in case of copy target
	default:	bus = 64'd0;
	endcase
end

always_ff @(posedge clk)
	o = bus;
always_comb
	exc = Qupls4_pkg::FLT_NONE;

task tAdd;
input Qupls4_pkg::micro_op_t ir;
output [WID-1:0] bus;
begin
	if (Qupls4_pkg::PERFORMANCE) begin
		if (ir[31])
			bus = a + i;
		else
			case(ir.alu.op3)
			3'd0:		// ADD
				case(ir.alu.lx)
				2'd0:	bus = a + b;
				default:	bus = a + i;
				endcase
			3'd2:		// ABS
				case(ir.alu.lx)
				2'd0:
					begin
						tmp = a + b;
						bus = tmp[WID-1] ? -tmp : tmp;
					end
				default:
					begin
						tmp = a + i;
						bus = tmp[WID-1] ? -tmp : tmp;
					end
				endcase
			default:	bus = zero;
			endcase
	end
end
endtask

task tSubf;
input Qupls4_pkg::micro_op_t ir;
output [WID-1:0] bus;
begin
	if (Qupls4_pkg::PERFORMANCE) begin
		if (ir[31])
			bus = i - a;
		else
			case(ir.alu.op3)
			3'd0:	bus = b - a;
			default:	bus = zero;	
			endcase
	end
end
endtask

task tAnd;
input Qupls4_pkg::micro_op_t ir;
output [WID-1:0] bus;
begin
	if (Qupls4_pkg::PERFORMANCE) begin
		if (ir[31])
			bus = a & i;
		else
			case(ir.alu.op3)
			3'd0:	bus = a & b;
			3'd1:	bus = ~(a & b);
			3'd2:	bus = a & ~b;
			default:	bus = zero;	
			endcase
	end
end
endtask

task tOr;
input Qupls4_pkg::micro_op_t ir;
output [WID-1:0] bus;
begin
	if (Qupls4_pkg::PERFORMANCE) begin
		if (ir[31])
			bus = a | i;
		else
			case(ir.alu.op3)
			3'd0:	bus = a | b;
			3'd1:	bus = ~(a | b);
			3'd2:	bus = a | ~b;
			default:	bus = zero;	
			endcase
	end
end
endtask

task tXor;
input Qupls4_pkg::micro_op_t ir;
output [WID-1:0] bus;
begin
	if (Qupls4_pkg::PERFORMANCE) begin
		if (ir[31])
			bus = a ^ i;
		else
			case(ir.alu.op3)
			3'd0:	bus = a ^ b;
			3'd1:	bus = ~(a ^ b);
			3'd2:	bus = a ^ ~b;
			default:	bus = zero;	
			endcase
	end
end
endtask

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
