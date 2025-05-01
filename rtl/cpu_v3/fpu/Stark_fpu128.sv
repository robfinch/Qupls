// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2025  Robert Finch, Waterloo
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
// 7500 LUTs / 0 FFs (capabilities only)
// ============================================================================

import cpu_types_pkg::*;
import Stark_pkg::*;
//import fp128Pkg::*;

module Stark_fpu128(rst, clk, om, idle, ir, rm, a, b, c, t, i, p, atag, btag, o, otag, done, exc);
parameter FPU0 = 1'b1;
parameter WID=128;
input rst;
input clk;
input Stark_pkg::operating_mode_t om;
input idle;
input Stark_pkg::instruction_t ir;
input [2:0] rm;
input [WID-1:0] a;
input [WID-1:0] b;
input [WID-1:0] c;
input [WID-1:0] t;
input [WID-1:0] i;
input [WID-1:0] p;
input atag;
input btag;
output reg otag;
output reg [WID-1:0] o;
output reg done;
output Stark_pkg::cause_code_t exc;

reg [11:0] cnt;
reg sincos_done, scale_done, f2i_done, i2f_done, sqrt_done, fres_done, trunc_done;
wire div_done;
reg [WID-1:0] bus;
reg [WID-1:0] fmao1, fmao2, fmao3, fmao4, fmao5, fmao6, fmao7;
wire [WID-1:0] scaleo, f2io, i2fo, signo, cmpo, divo, sqrto, freso, trunco;
wire [WID-1:0] cvtD2Qo;
wire ce = 1'b1;
wire cd_args;
reg [WID-1:0] tmp;
wire [WID-1:0] zero = {WID{1'b0}};

reg [64:0] base,bbase;
reg [64:0] top,btop;
reg [64:0] obase,otop;
wire [95:0] length = top - base;
wire [5:0] Lmsb,Lmsba,Lmsbb;
reg [5:0] E;
ffo96 uffo1 (.i(length), .o(Lmsb));
ffo96 uffo2 (.i({32'd0,a[63:0]}), .o(Lmsba));
ffo96 uffo3 (.i({32'd0,b[63:0]}), .o(Lmsbb));

capability64_t Ca = capability64_t'(a);
capability64_t Cb = capability64_t'(b);
capability64_t Ct;

Stark_cmp #(.WID(WID)) ualu_cmp
(
	.ir(ir),
	.om(om),
	.cr(64'd0),
	.a(a),
	.b(b),
	.i(i),
	.o(cmpo)
);

// A change in arguments is used to load the divider.
change_det #(.WID(256)) uargcd0 (
	.rst(rst),
	.clk(clk),
	.ce(ce),
	.i({a,b}),
	.cd(cd_args)
);

fpScaleb128 uscal1
(
	.clk(clk),
	.ce(ce),
	.a(a),
	.b(b),
	.o(scaleo)
);

/*
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
*/
reg fmaop, fma_done;
reg [WID-1:0] fmac;
reg [WID-1:0] fmab;
reg [WID-1:0] fmao;

always_comb
	if (ir.f3.func==FN_FMS || ir.f3.func==FN_FNMS)
		fmaop = 1'b1;
	else
		fmaop = 1'b0;

always_comb
	if (ir.f2.func==FN_FADD || ir.f2.func==FN_FSUB)
		fmab <= 128'h3FFF0000000000000000000000000000;	// 1,0
	else
		fmab <= b;

always_comb
	if (ir.f2.func==FN_FMUL || ir.f2.func==FN_FDIV)
		fmac = 64'd0;
	else
		fmac = c;

fpFMA128nrCombo ufma1
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

f2i128 uf2i1281
(
	.clk(clk),
	.ce(ce), 
	.op(1'b1),	// 1= signed, 0=unsigned
	.i(a),
	.o(f2io),
	.overflow()
);

fpCvtI128To128 ui2f1
(
	.clk(clk),
	.ce(ce),
	.op(1'b1),	//1=signed, 0=unsigned
	.rm(rm),
	.i(a),
	.o(i2fo),
	.inexact()
);

fpSign128 usign1
(
	.a(a),
	.o(signo)
);

fpCompare128 ucmp1
(
	.a(a),
	.b(b),
	.o(cmpo),
	.inf(),
	.nan(),
	.snan()
);

fpSqrt128nr usqrt1
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

/*
fpRes64 ufre1
(
	.clk(clk),
	.ce(ce),
	.a(a),
	.o(freso)
);
*/
fpTrunc128 utrunc1
(	
	.clk(clk),
	.ce(ce),
	.i(a),
	.o(trunco)
);

fpCvt64To128 ucvtS2D1
(
	.i(a),
	.o(cvtD2Qo)
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
	bus = 128'd0;
	exc = FLT_NONE;
	case(ir.any.opcode)
	/*
	OP_FLT3:
		if (Stark_pkg::SUPPORT_QUAD_PRECISION) begin
			case(ir.f3.func)
			FN_FLT1:
				case(ir.f1.func)
				FN_FABS:	bus = {1'b0,a[126:0]};
				FN_FNEG:	bus = {a[127]^1'b1,a[126:0]};
				FN_FTOI:	bus = f2io;
				FN_ITOF:	bus = i2fo;
				FN_FSIGN:	bus = signo;
				FN_ISNAN:	bus = &a[126:112] && |a[111:0];
				FN_FINITE:	bus = ~&a[126:112];
	//				FN_FSIN:	bus = sino;
	//				FN_FCOS:	bus = coso;
				FN_FSQRT:	bus = sqrto;
	//				FN_FRES:	bus = freso;
				FN_FTRUNC:	bus = trunco;
				FN_FCVTD2Q:	bus = cvtD2Qo;
				default:	bus = 'd0;
				endcase
			FN_FSCALEB:
				bus = scaleo;
			FN_FADD,FN_FSUB,FN_FMUL:
				bus = fmao;
			FN_FSEQ:	bus = cmpo[0];
			FN_FSNE:	bus = ~cmpo[0];
			FN_FSLT:	bus = cmpo[1];
			FN_FSLE:	bus = cmpo[2];
			FN_FCMP:	bus = cmpo;
			FN_SGNJ:	bus = {a[127],b[126:0]};
			FN_SGNJN:	bus = {~a[127],b[126:0]};
			FN_SGNJX:	bus = {a[127]^b[127],b[126:0]};
			default:	bus = 128'd0;
			endcase
		end
		else
			exc = FLT_UNIMP;
	FN_FMA,FN_FMS,FN_FNMA,FN_FNMS:
		if (Stark_pkg::SUPPORT_QUAD_PRECISION)
			bus = fmao;
		else
			exc = FLT_UNIMP;

	Stark_pkg::OP_ADD:
		if (Stark_pkg::PERFORMANCE) begin
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
	Stark_pkg::OP_AND:
		if (Stark_pkg::PERFORMANCE) begin
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
	Stark_pkg::OP_OR:
		if (Stark_pkg::PERFORMANCE) begin
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
	Stark_pkg::OP_XOR:
		if (Stark_pkg::PERFORMANCE) begin
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
	Stark_pkg::OP_SUBF:
		if (Stark_pkg::PERFORMANCE) begin
			if (ir[31])
				bus = i - a;
			else
				case(ir.alu.op3)
				3'd0:	bus = b - a;
				default:	bus = zero;	
				endcase
		end
	Stark_pkg::OP_CMP:	bus = cmpo;
	Stark_pkg::OP_MOV:
		if (Stark_pkg::PERFORMANCE) begin
			bus = a;
		end
	Stark_pkg::OP_LOADA:
		if (Stark_pkg::PERFORMANCE) begin
			bus = a + i + (b << ir[23:22]);
		end
	Stark_pkg::OP_NOP:		bus = t;	// in case of copy target

	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -	
	// Capabilities logic
	// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -	
	OP_CAP:
		if (SUPPORT_CAPABILITIES && FPU0)
			case(ir.cap.func)
			FN_CANDPERMS:
				begin
					if (Ca.otype==18'h3FFFE)	// sealed?
						otag = 1'b0;
					else
						otag = atag;
					Ct = Ca;
					Ct.perms = Ct.perms & b;
					bus = Ct;
				end
			FN_CBUILDCAP:
				begin
					Ct = Cb;
					if (atag==1'b0 || Ca.otype==18'h3FFFE)
						otag = 1'b0;
					else begin
						Ct.flags = Ca.flags;
						Ct.otype = Ca.otype;
						if (Cb.otype==18'h3FFFE)
							Ct.otype = 18'h3FFFE;
					end
					bus = Ct;
				end
			FN_CCMP:
				begin
					bus = value_zero;
					if (Ca==Cb && atag==btag)
						bus[0] = 1'b1;	// set equals flag
					else if (atag==btag) begin
						// Is Ca.perms a subset of Cb.perms?
						if ((Ca.perms|Cb.perms)==Cb.perms) begin
							tCapGetBaseTop(Ca, base, top);
							tCapGetBaseTop(Cb, bbase, btop);
							if (base >= bbase && top <= btop) begin
								bus[0] = 1'b1;	// set EQ flag
								bus[2] = 1'b1;	// set LT flag
								bus[3] = 1'b1;	// set LE flag
							end
						end
					end
					// if Ca is unsealed...
					if (Ca.otype==18'h3FFFF)
						bus[15] = 1'b1;
				end
			FN_CCOPYTYPE:
				begin
					Ct = Ca;
					Ct.a = Cb.otype;
					// If Ca is sealed or Cb type is reserved.
					if (Ca.otype==18'h3FFFE || Cb.otype < 18'h3FFFE)
						;	// otag is cleared
					else
						otag = atag;
					bus = Ct;
				end
			FN_CCLEARTAG:	bus = Ca;
			FN_CGETFLAGS:	bus = Ca.flags;
			FN_CGETPERMS:	bus = Ca.perms;
			FN_CGETHIGH:		bus = Ca[127:64];
			FN_CGETBASE:	tCapGetBaseTop(Ca, bus, top);
			FN_CGETTOP:	tCapGetBaseTop(Ca, base, bus);
			FN_CGETLEN:
				begin
					tCapGetBaseTop(Ca, base, top);
					bus = top - base;
				end
			FN_CGETTYPE:
				begin
					if (Ca.otype >= 18'h3FFFE)
						bus = Ca.otype;
					else
						bus = {{46{Ca.otype[18]}},Ca.otype};
				end
			FN_CGETOFFS:	bus = Ca.a;
			FN_CGETTAG:	bus = atag;
			FN_CINCOFFS:
				begin
					tCapGetBaseTop(Ca, base, top);
					obase = base;
					otop = top;
					tCapEncodeBaseTop(Ca.a + b, base, top, Lmsb, Ct);
					Ct.perms = Ca.perms;
					Ct.flags = Ca.flags;
					tCapGetBaseTop(Ct, base, top);
					// new base, top matches old, and not sealed.
					if (base == obase && top == otop && Ca.otype==18'h3FFFF)
						otag = atag;
					bus = Ct;
				end
			FN_CINCOFFSIMM:
				begin
					tCapGetBaseTop(Ca, base, top);
					obase = base;
					otop = top;
					tCapEncodeBaseTop(Ca.a + i, base, top, Lmsb, Ct);
					Ct.perms = Ca.perms;
					Ct.flags = Ca.flags;
					tCapGetBaseTop(Ct, base, top);
					// new base, top matches old, and not sealed.
					if (base == obase && top == otop && Ca.otype==18'h3FFFF)
						otag = atag;
					bus = Ct;
				end
			FN_CINVOKE:
				begin
					bus = t;
					tCapGetBaseTop(Ca, base, top);
					if (atag==1'b0 || btag==1'b0)
						exc = FLT_CAPTAG;
					else if (Ca.otype < 18'h3FFFE || Cb.otype < 18'h3FFFE)
						exc = FLT_CAPOTYPE;
					else if (Ca.otype != Cb.otype)
						exc = FLT_CAPOTYPE;
					else if ((Ca.perms & PERMIT_INVOKE)==1'b0 || (Cb.perms & PERMIT_INVOKE)==1'b0)
						exc = FLT_CAPPERMS;
					else if ((Ca.perms & PERMIT_EXECUTE)==1'b0)
						exc = FLT_CAPPERMS;
					else if ((Cb.perms & PERMIT_EXECUTE)==1'b1)
						exc = FLT_CAPPERMS;
					else if (Ca.a < base || Ca.a + 5'd6 > top)
						exc = FLT_CAPBOUNDS;
				end
			FN_CLOADTAGS:
				begin
					bus = t;
					tCapGetBaseTop(Ca, base, top);
					if (atag==1'b0)
						exc = FLT_CAPTAG;
					else if (Ca.otype<=18'h3FFFE)
						exc = FLT_CAPSEALED;
					else if ((Ca.perms & PERMIT_LOAD)==1'b0)
						exc = FLT_CAPPERMS;
					else if ((Ca.perms & PERMIT_LOAD_CAP)==1'b0)
						exc = FLT_CAPPERMS;
					else if (Ca.a < base || Ca.a + 5'd8 > top)
						exc = FLT_CAPBOUNDS;
				end
			FN_CMOVE:
				begin
					Ct = Ca;
					otag = atag;
					bus = Ct;
				end
			FN_CALIGNMSK:			
				begin
					tCapEncodeBaseTop(0, 0, a, Lmsba, Ct);
					E = {Ct.Te,Ct.Be};
					bus = (64'hFFFFFFFFFFFFFFFF >> E) << E;
				end
			FN_CROUNDLEN:
				begin
					tCapEncodeBaseTop(0, 0, a, Lmsba, Ct);
					tCapGetBaseTop(Ct, base, top);
					bus = top;
				end
			FN_CSEAL:
				begin
					bus = t;
					tCapGetBaseTop(Cb, base, top);
					if (btag==1'b1 && (Cb.otype & PERMIT_SEAL)!=16'd0) begin
						if (Cb.a >= base && Cb.a < top && Cb.a <= 18'h3FFFF) begin
							if (Ca.otype>18'h3FFFE) begin
								Ct = Ca;
								otag = atag;
								Ct.otype = Cb.a;
								bus = Ct;
							end
						end
					end
				end
			FN_CSEALENTRY:
				begin
					bus = t;
					if (Ca.otype==18'h3FFFF) begin
						otag = atag;
						Ct = Ca;
						Ct.otype = 18'h3FFFE;
						bus = Ct;
					end
				end
			FN_CSETADDR:
				begin
					bus = t;
					tCapGetBaseTop(Ca, base, top);
					obase = base;
					otop = top;
					tCapEncodeBaseTop(b, base, top, Lmsb, Ct);
					tCapGetBaseTop(Ct, base, top);
					if (Ca.otype==18'h3FFFF && base==obase && top==otop) begin
						otag = atag;
						Ct.flags = Ca.flags;
						Ct.perms = Ca.perms;
						bus = Ct;
					end
				end
			FN_CSETBOUNDS:
				begin
					bus = t;
					tCapGetBaseTop(Ca, base, top);
					tCapEncodeBaseTop(Ca.a, Ca.a, Ca.a+b, Lmsbb, Ct);
					if (Ca.otype==18'h3FFFE && Ct.a >= base && Ct.a + b < top) begin
						bus = Ct;
						otag = atag;
					end
				end
			FN_CSETBOUNDSEXACT:
				begin
					bus = t;
					tCapGetBaseTop(Ca, base, top);
					obase = base;
					otop = top;
					tCapEncodeBaseTop(Ca.a, Ca.a, Ca.a+b, Lmsbb, Ct);
					tCapGetBaseTop(Ct, base, top);
					if (Ca.otype==18'h3FFFE && Ct.a >= base && Ct.a + b < top) begin
						bus = Ct;
						if (base==obase && top==otop)
							otag = atag;
					end
				end
			FN_CSETFLAGS:
				begin
					bus = t;
					if (Ca.otype==18'h3FFFF) begin
						Ct = Ca;
						Ct.flags = b;
						otag = atag;
						bus = Ct;
					end
				end
			FN_CSETHIGH:
				begin
					Ct = Ca;
					Ct[127:64] = b;
					bus = Ct;
				end
			FN_CSETOFFS:
				begin
					bus = t;
					tCapGetBaseTop(Ca, base, top);
					obase = base;
					otop = top;
					tCapEncodeBaseTop(Ca.a+b, base, top, Lmsb, Ct);
					Ct.flags = Ca.flags;
					Ct.perms = Ca.perms;
					tCapGetBaseTop(Ct, base, top);
					if (Ca.otype==18'h3FFFF && base==obase && top==otop) begin
						otag = atag;
						bus = Ct;
					end
				end
			FN_CUNSEAL:
				begin
					bus = t;
					Ct = Ca;
					if (Cb.perms & PERMIT_UNSEAL) begin
						Ct.otype = 18'h3FFFF;
						if ((Cb.perms & GLOBAL)==16'd0)
							Ct.perms = Ct.perms & ~GLOBAL;
						otag = atag;
						bus = Ct;
					end
				end
			FN_CRETD:
				begin
					tCapGetBaseTop(Cb, base, top);
					obase = base;
					otop = top;
					tCapEncodeBaseTop(Cb.a + i, base, top, Lmsb, Ct);
					Ct.perms = Cb.perms;
					Ct.flags = Cb.flags;
					tCapGetBaseTop(Ct, base, top);
					// new base, top matches old, and not sealed.
					if (base == obase && top == otop)
						otag = atag;
					Ct.otype = 4'hF;	// unseal
					bus = Ct;
				end
			default:	bus = {8{16'hDEAD}};
			endcase
		else begin
			bus = {8{16'hDEAD}};
			exc = FLT_UNIMP;
		end
	*/
	default:	bus = 128'd0;
	endcase
end

always_comb
	case(ir.any.opcode)
	/*
	OP_CAP:	done = 1'b1;
	OP_FLT3:
		if (SUPPORT_QUAD_PRECISION) begin
			case(ir.f3.func)
			FN_FLT1:
				case(ir.f1.func)
				FN_FTOI: done = f2i_done;
				FN_ITOF: done = i2f_done;
				FN_FSIN:	done = sincos_done;
				FN_FCOS:	done = sincos_done;
	//			FN_FSQRT: done = sqrt_done;
				FN_FRES:	done = fres_done;
				FN_FTRUNC:	done = trunc_done;
				default:	done = 1'b1;
				endcase
			FN_FSCALEB:
				done = scale_done;
			FN_FADD,FN_FSUB,FN_FMUL:
				done = fma_done;
			default:	done = 1'b1;
			endcase
		end
		else
			done = 1'b1;
	FN_FMA,FN_FMS,FN_FNMA,FN_FNMS:
		if (SUPPORT_QUAD_PRECISION)
			done = fma_done;
		else
			done = 1'b1;
	OP_R3B:		done = 1'b1;
	OP_R3W:		done = 1'b1;
	OP_R3T:		done = 1'b1;
	OP_R3O:		done = 1'b1;
	OP_ADDI:	done = 1'b1;
	OP_CMPI:	done = 1'b1;
	OP_CMPUI:	done = 1'b1;
	OP_ANDI:	done = 1'b1;
	OP_ORI:		done = 1'b1;
	OP_EORI:	done = 1'b1;
	OP_MOV:		done = 1'b1;
	OP_NOP:		done = 1'b1;
	*/
	default:	done = 1'b1;
	endcase

always_comb
	o = bus;
	/*
	if (p[0])
		o = bus;
	else
		o = t;
	*/

task tCapGetBaseTop;
input capability32_t Ca;
output [64:0] base;
output [64:0] top;
integer ct, cb;
reg [5:0] E;
reg [13:0] T;
reg [13:0] B;
reg Lcarryout;
reg Lmsb;
reg [2:0] A3;
reg [2:0] B3;
reg [2:0] T3;
reg [3:0] R;
reg [64:0] atop, amid, abot;
begin
	T[11:3] = Ca.T;
	B[13:3] = Ca.B;
	if (Ca.Ie) begin
		E = {Ca.Te,Ca.Be};
		T[2:0] = 0;
		B[2:0] = 0;
		Lcarryout = T[11:3] < B[11:3];
		Lmsb = 1;
	end
	else begin
		E = 6'd0;
		T[2:0] = Ca.Te;
		B[2:0] = Ca.Be;
		Lcarryout = T[11:0] < B[11:0];
		Lmsb = 0;
	end				
	T[13:12] = B[13:12] + Lcarryout + Lmsb;
	A3 = (Ca.a >> E+5'd11) & 3'd7;
	B3 = B[13:11];
	T3 = T[13:11];
	R = B3 - 1;
	if (R[3])
		ct = 0;
	else begin
		case({A3 < R[2:0],T3 < R[2:0]})
		2'd0:	ct = 0;
		2'd1:	ct = 1;
		2'd2:	ct = -1;
		2'd3:	ct = 0;
		endcase
	end
	if (R[3])
		cb = 0;
	else begin
		case({A3 < R[2:0],B3 < R[2:0]})
		2'd0:	cb = 0;
		2'd1:	cb = 1;
		2'd2:	cb = -1;
		2'd3:	cb = 0;
		endcase
	end
	atop = (Ca.a >> (E+4'd14));
	amid = (Ca.a >> E) & 14'h3FFF;
	abot = Ca.a & ~(64'hFFFFFFFFFFFFFFFF << E);
	top = {atop + ct,T[13:0]} << E;
	base = {atop + cb,B[13:0]} << E;
end
endtask

task tCapEncodeBaseTop;
input [63:0] a;
input [64:0] base;
input [64:0] top;
input [5:0] Lmsb;
output capability32_t cap;
reg [5:0] E;
reg [64:0] B;
reg [64:0] T;
reg [128:0] T1;
reg [64:0] L;
begin
	cap.a = a;
	if (Lmsb < 14) begin
		E = 6'd0;
		cap.Ie = 1'b0;
	end
	else begin
		E = 6'd52 - Lmsb;
		cap.Ie = 1'b1;
	end
	B = base[64:0] >> E;
	// Detect if any bits shifted out the bottom of top are non-zero.
	T1 = {top,64'b0} >> E;
	// Round Top up.
	T = (top[64:0] >> E) + |T1[63:0];
	// Recalculate length
	L = T - B;
	// If the length increased in MSB recalc.
	if (L[Lmsb+1])
		Lmsb = Lmsb + 2'd1;
	if (Lmsb < 14) begin
		E = 6'd0;
		cap.Ie = 1'b0;
		cap.Be = base[3:0];
		cap.Te = top[3:0];
	end
	else begin
		E = 6'd52 - Lmsb;
		cap.Ie = 1'b1;
		cap.Be = E[2:0];
		cap.Te = E[5:3];
	end
	B = base[64:0] >> E;
	T = top[64:0] >> E;
	cap.B = T[11:3];
	cap.T = B[13:3];
end
endtask

endmodule
