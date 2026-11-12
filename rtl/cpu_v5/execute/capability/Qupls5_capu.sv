// ============================================================================
//        __
//   \\__/ o\    (C) 2026  Robert Finch, Waterloo
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
// THI+S SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
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
// LUTs / FFs / 0 DSPs ( MHz) 
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import capability_pkg::*;
import Qupls5_pkg::*;

module Qupls5_capu(rst, clk, ir, ip, ac, bc, ac_flags, bc_flags, agp, bgp, i,
	o, o_flags, csr, excv, exc, done);
input rst;
input clk;
input Qupls5_pkg::micro_op_t ir;
input pc_address_ex_t ip;
input uc64_capability_t ac;
input uc64_capability_t bc;
input uc64_capability_t csr;
input cpu_types_pkg::flags_t ac_flags;
input cpu_types_pkg::flags_t bc_flags;
input cpu_types_pkg::value_t agp;
input cpu_types_pkg::value_t bgp;
input cpu_types_pkg::value_t i;
output uc64_capability_t o;
output cpu_types_pkg::flags_t o_flags;
output reg excv;
output Qupls5_pkg::cause_code_t exc;
output reg done;

reg [63:0] jmp_dst;

reg chg;
reg [11:0] donef;
wire [63:0] base;
wire [64:0] top;
wire [7:0] E;
wire done8;
Qupls5_pkg::micro_op_t iro;
wire invoke = ir.func==Qupls5_pkg::CAP_INVOKE;
wire setbounds = ir.func==Qupls5_pkg::CAP_SETBOUNDS;
reg isInvokeInBounds, isInBounds;
capability_pkg::uc64_capability_t cc,dc,tc;
capability_pkg::uc64_capability_t ao,bo,co,dco;		// older versions
cpu_types_pkg::flags_t cc_flags;
cpu_types_pkg::flags_t dc_flags;
reg bcz;

always_comb bcz = bc==256'd0;
always_ff @(posedge clk) ao <= ac;
always_ff @(posedge clk) bo <= bc;
always_ff @(posedge clk) co <= cc;
always_ff @(posedge clk) dco <= dc;
always_ff @(posedge clk) iro <= ir;

always_comb
	chg = {ir,ac,bc} != {iro,ao,bo};

// Create a delayed done signal.
always_ff @(posedge clk)
begin
	if (chg)
		donef <= {11'b0,1'b1};
	else
		donef <= {donef[10:0],1'b1};
end

// Currently the only thing requireing multiple clocks is compress/decompress.
always_ff @(posedge clk)
begin
	if (chg)
		done <= FALSE;
	else begin
		case(ir.func)
		Qupls5_pkg::CAP_DECOMP64:	done <= donef[5];
		Qupls5_pkg::CAP_COMP64: done <= donef[5];
		Qupls5_pkg::CAP_DECOMP32:	done <= donef[5];
		Qupls5_pkg::CAP_COMP32: done <= donef[5];
		default:	done <= TRUE;
		endcase
	end
end

delay4 #(.WID(64)) udly1 (.clk(clk), .ce(1'b1), .i(c64), .o(c64d));
delay4 #(.WID(64)) udly2 (.clk(clk), .ce(1'b1), .i(d), .o(dh4));
assign ch4 = c64d;
/*
modCalcBase ucb1
(
	.rst(rst),
	.clk(clk),
	.cap(invoke ? pcch : c),
	.adr(invoke ? pcc : a),
	.base(base),
	.Eo()
);

modCalcTop uct1
(
	.rst(rst),
	.clk(clk),
	.cap(invoke ? pcch : c),
	.adr(invoke ? pcc : a),
	.top(top),
	.Eo(E)
);

modCalcHigh uch1
(
	.base(setbounds ? a : base),
	.length(setbounds ? b : top-base),
	.otype(c64d4.otype),
	.flag(c64d4.flag),
	.perm(c64d4.perms),
	.high(higho)
);
*/
always_comb
	isInvokeInBounds = ip.offset >= base && ip.offset <= top - 6;
always_comb
	isInBounds = bc.offset+bc.base >= base && bc.offset+bc.base <= top - 6;

always_comb
	jmp_dst = {{29{rse.uop.imm[34]}},rse.uop.imm[34:0]};

// None of the following operations processing require writing the GPR file.
always_ff @(posedge clk)
if (rst) begin
	excv <= FALSE;
	exc <= Qupls5_pkg::FLT_NONE;
	o_flags <= 8'h00;
	o <= {$bits(uc64_capability_t){1'b0}};
end
else begin
	excv <= FALSE;
	exc <= Qupls5_pkg::FLT_NONE;
	o_flags <= 8'h00;
	o <= {$bits(uc64_capability_t){1'b0}};
	case(ir.func)
	Qupls5_pkg::CAP_ANDPERM:
		begin
			o_flags = ac_flags;
			if (fnIsSealed(ac))
				o_flags.cap = 1'b0;
			o.otype = 24'hfffffe;						// seal
			o.perms = ac.perms & bc.offset;	// and perms
		end
	Qupls5_pkg::CAP_BUILDCAP:
		begin
			if (fnIsSealed(ac) ||
				((bc.perms & ac.perms) != bc.perms)	||	// perms must be subset
				(!(bc.base >= ac.base && bc.top <= ac.top)) ||	// bounds must be within
				!ac_flags.cap)
			begin
				o_flags.cap <= 1'b0;
				o <= bc;
			end
			else begin
				o_flags <= ac_flags;
				o <= ac;
				o.base <= bc.base;
				o.top <= bc.top;
				o.offset <= bc.offset;
				o.perms <= bc.perms;
				o.flag <= bc.flag;
				if (fnIsSentry(bc))
					o.otype <= 24'hfffffe;				// seal as sentry
			end
		end
	Qupls5_pkg::CAP_CLEARTAG:
		begin
			o_flags = ac_flags;
			o_flags.cap = FALSE;
			o = ac;
		end
	Qupls5_pkg::CAP_CHKBOUNDS:
		if (~ac_flags.cap) begin
			excv <= TRUE;
			exc <= Qupls5_pkg::FLT_CTAG;
		end
		else if (bc.offset < ac.base || bc.offset + bc.base >= ac.top - 6) begin
			excv <= TRUE;
			exc <= Qupls5_pkg::FLT_CBOUNDS;
		end
	Qupls5_pkg::CAP_COPYTYPE:
		begin
			o <= ac;
			o.offset <= bc.otype;
			o_flags <= ac_flags;
			if (fnIsSealed(ac) || fnIsReserved(bc))
				o_flags.cap <= FALSE;
		end
/* Done in ALU
	CAP_GETFLAGS:
		begin
			o.offset <= ac.flag;
			wrgpr <= TRUE;
		end
	CAP_GETBASE:
		begin
			o.offset <= ac.base;
			wrgpr <= TRUE;
		end
	CAP_GETLENGTH:
		begin
			if (ac_top[64])
				o_flags.ovf <= TRUE;
			o.offset <= ac.top - ac.base;
			wrgpr <= TRUE;
		end
	CAP_GETOFFSET:
		begin
			o.offset = ac.offset;
			wrgpr <= TRUE;
		end
	CAP_GETADDR:
		begin
			o.offset = ac.offset + ac.base;
			wrgpr <= TRUE;
		end
	CAP_GETPERMS:
		begin
			o.offset = ac.perms;
			wrgpr <= TRUE;
		end
	CAP_GETSEALED:
		begin
			o.offset = fnUcIsSealed(ac);
			wrgpr <= TRUE;
		end
	CAP_GETTAG:
		begin
			o.offset = ac_flags.cap;
			wrgpr <= TRUE;
		end
	CAP_GETTOP:
		begin
			o_flags.ovf <= ac.top[64];
			o.offset <= ac.top;
			wrgpr <= TRUE;
		end
	CAP_GETTYPE:
		begin
			o.offset <= ac.otype;
			wrgpr <= TRUE;
		end
*/
	Qupls5_pkg::CAP_INCOFFSET:
		case(ir.op3)
		3'd0:
			begin
				o_flags <= ac_flags;
				if (fnUcIsSealed(ac))
					o_flags.cap <= FALSE;
				o <= ac;
				o.offset <= ac.offset + bc.offset;
			end
		3'd1:
			begin
				o_flags <= ac_flags;
				if (fnUcIsSealed(ac))
					o_flags.cap <= FALSE;
				o <= ac;
				o.offset <= ac.offset + agp;
			end
		endcase
	Qupls5_pkg::CAP_INCOFFSETI:
		begin
			o_flags <= ac_flags;
			if (fnUcIsSealed(ac))
				o_flags.cap <= FALSE;
			o <= ac;
			o.offset <= ac.offset + i;
		end
	Qupls5_pkg::CAP_CHKINVOKE:
		if (~ac_flags.cap|~bc_flags.cap) begin
			excv <= TRUE;
			exc <= Qupls5_pkg::FLT_CTAG;
		end
		else if (fnUcIsReserved(ac) || fnUcIsReserved(bc)) begin
			excv <= TRUE;
			exc <= Qupls5_pkg::FLT_CSEAL;
		end
		else if (ac.otype != bc.otype) begin
			excv <= TRUE;
			exc <= Qupls5_pkg::FLT_CTYPE;
		end
		else if (~ac.perms[8]|~bc.perms[8]) begin
			excv <= TRUE;
			exc <= Qupls5_pkg::FLT_CPINVOKE;
		end
		else if (~ac.perms[1]|bc.perms[1]) begin
			excv <= TRUE;
			exc <= Qupls5_pkg::FLT_CPEXEC;
		end
		else if (ac.offset[0]) begin
			excv <= TRUE;
			exc <= Qupls5_pkg::FLT_CALGN;
		end 
		else if (ac.offset < ac.base || ac.offset > ac.top - 6) begin
			excv <= TRUE;
			exc <= Qupls5_pkg::FLT_CBOUNDS;
		end
	Qupls5_pkg::CAP_INVOKE:
		begin
			if (~ac_flags.cap|~bc_flags.cap) begin
				excv <= TRUE;
				exc <= Qupls5_pkg::FLT_CTAG;
			end
			else if (fnUcIsReserved(ac) || fnUcIsReserved(bc)) begin
				excv <= TRUE;
				exc <= Qupls5_pkg::FLT_CSEAL;
			end
			else if (ac.otype != bc.otype) begin
				excv <= TRUE;
				exc <= Qupls5_pkg::FLT_CTYPE;
			end
			else if (~ac.perms[8]|~bc.perms[8]) begin
				excv <= TRUE;
				exc <= Qupls5_pkg::FLT_CPINVOKE;
			end
			else if (~ac.perms[1]|bc.perms[1]) begin
				excv <= TRUE;
				exc <= Qupls5_pkg::FLT_CPEXEC;
			end
			else if (ac.offset[0]) begin
				excv <= TRUE;
				exc <= Qupls5_pkg::FLT_CALGN;
			end 
			else if (ac.offset < ac.base || ac.offset > ac.top - 6) begin
				excv <= TRUE;
				exc <= Qupls5_pkg::FLT_CBOUNDS;
			end
			else begin
				o <= bc;
				o.otype <= 24'hffffff;	// unsealed
				rse_o.pc.pc <= ac;
				rse_o.pc.pc.otype <= 24'hffffff;	// unsealed
			end
		end
	Qupls5_pkg::CAP_MOVE:
		begin
			o <= ac;
		end
/* Done in ALU
	CAP_ALGNMASK:
		begin
			o.offset <= fnUcAlignMask(ac);
			wrgpr <= TRUE;
		end
*/
	Qupls5_pkg::CAP_RET:
		begin
			if (~ac_flags.cap|(~bc_flags.cap & !bcz)) begin
				excv <= TRUE;
				exc <= Qupls5_pkg::FLT_CTAG;
			end
			else if (fnUcIsReserved(ac) || (fnUcIsReserved(bc) & !bcz)) begin
				excv <= TRUE;
				exc <= Qupls5_pkg::FLT_CSEAL;
			end
			else if (ac.otype != bc.otype && !bcz) begin
				excv <= TRUE;
				exc <= Qupls5_pkg::FLT_CTYPE;
			end
			else if (~ac.perms[1]|(bc.perms[1] & ~bcz)) begin
				excv <= TRUE;
				exc <= Qupls5_pkg::FLT_CPEXEC;
			end
			else if (ac.offset[0]) begin
				excv <= TRUE;
				exc <= Qupls5_pkg::FLT_CALGN;
			end 
			else if (ac.offset < ac.base || ac.offset > ac.top - 6) begin
				excv <= TRUE;
				exc <= Qupls5_pkg::FLT_CBOUNDS;
			end
			else begin
				o <= bc;
				o.otype <= 24'hffffff;	// unsealed
				rse_o.pc.pc <= ac;
				rse_o.pc.pc.otype <= 24'hffffff;	// unsealed
			end
		end
	Qupls5_pkg::CAP_SEAL:
		begin
			o_flags <= ac_flags;
			if (fnUcIsSealed(ac) || !bc.perms[7])	// permit seal?
				o_flags.cap = FALSE;
			o <= ac;
			o.otype <= bc.offset;
		end
	Qupls5_pkg::CAP_SEALENTRY:
		begin
			o_flags <= ac_flags;
			if (fnUcIsSealed(ac))	// permit seal?
				o_flags.cap = FALSE;
			o <= ac;
			o.otype <= 24'hFFFFFE;	// SENTRY value
		end
	Qupls5_pkg::CAP_SETADDR:
		begin
			o_flags <= ac_flags;
			if (fnUcIsSealed(ac) || !fnUsIsRepresentable(ac,bc.offset-ac.base))	// permit seal?
				o_flags.cap = FALSE;
			o <= ac;
			o.offset <= bc.offset - ac.base;
		end
	Qupls5_pkg::CAP_CHKBOUNDS:
		if (!ac_flags.cap) begin
			excv <= TRUE;
			exc <= Qupls5_pkg::FLT_CTAG;
		end
		else if (bc.offset < ac.base || bc.offset + bc.base > ac.top - 6) begin
			excv <= TRUE;
			exc <= Qupls5_pkg::FLT_CBOUNDS;
		end
	Qupls5_pkg::CAP_SETBOUNDS:
		begin
			o_flags <= ac_flags;
			if (fnUcIsSealed(ac))
				o_flags.cap <= FALSE;
			else if (agp < ac.base || agp > ac.top - 6)
				o_flags.cap <= FALSE;
			else if (bgp < ac.base || bgp > ac.top - 6)
				o_flags.cap <= FALSE;
			o <= ac;
			o.base <= agp;
			o.top <= bgp;
		end
	// See the testsub operation for a description of implementation.
	Qupls5_pkg::CAP_SETEQUALSEXACT:
		begin
			if (ac.otype==24'hffffff)	// is unsealed
				o_flags.ovf <= FALSE;
			else
				o_flags.ovf <= TRUE;
			o.offset <= ac==bc && ac_flags.cap==bc_flags.cap;
		end
	Qupls5_pkg::CAP_SETFLAGS:
		begin
			o_flags = ac_flags;
			if (fnUcIsSealed(ac))
				o_flags.cap = FALSE;
			o <= ac;
			o.flag <= bc.offset[0];
		end
	Qupls5_pkg::CAP_SETHIGH:
		begin
			o <= ac;
			o[255:192] <= bc.offset;
			o_flags <= ac_flags;
			o_flags.cap <= FALSE;
		end
	Qupls5_pkg::CAP_SETOFFSET:
		begin
			o_flags <= ac_flags;
			if (fnUcIsSealed(ac) || !fnUsIsRepresentable(ac,bc.offset-ac.offset))	// permit seal?
				o_flags.cap = FALSE;
			o <= ac;
			o.offset <= bc.offset;
		end
	// Test subset will be converted in micro-ops to this testsubset plus a read
	// of the capability offset field. Reading the offset can be done by the ALU.
	// This case will be writing to a MOT (micro-op temporary) register.
	// Using this mechanism the capabilities unit does not need to update the
	// general-purpose register file.
	Qupls5_pkg::CAP_TESTSUBSET:
		begin
			if (ac_flags.cap==bc_flags.cap &&						// tags are the same
				(ac.perms & bc.perms==ac.perms) &&				// permissions are a subset
				(ac.base >= bc.base && ac.top <= bc.top))	// bounds are a subset
				o.offset <= TRUE;
			if (ac.otype==24'hffffff)	// is unsealed
				o_flags.ovf <= FALSE;
			else
				o_flags.ovf <= TRUE;
		end
	Qupls5_pkg::CAP_UNSEAL:
		begin
			o <= ac;
			o.otype <= 24'hfffff;		// unsealed
			if (!bc.perms[0])
				o.perms[0] <= FALSE;
			o_flags <= ac_flags;
			if (!bc_flags.cap ||	// Rs2==capability?
				!bc.perms[9] || 		// permit unseal?
				!fnUcSealed(bc) ||	// Rs2 sealed?
				 fnUcIsReserved(bc) || // Rs2 a reserved otype?
				 bc.offset!=ac.otype || // otype match?
				 ((bc.offset + bc.base) < bc.base) ||	// cursor out of bounds?
				 ((bc.offset + bc.base) >= bc.top)
				)					
				o_flags.cap <= FALSE;
		end
	endcase
	case(ir.opcode)
	// Operation is done by branchmiss_pc, but we still need to save the return
	// address.
	Qupls5_pkg::OP_CJSR:
		begin
			if (jmp_dst < rse.pc.base || jmp_dst > rse.pc.top - 6) begin
				excv <= TRUE;
				exc <= Qupls5_pkg::FLT_CBOUNDS;
			end
			else if (jmp_dst[0]) begin
				excv <= TRUE;
				exc <= Qupls5_pkg::FLT_CALGN;
			end
			o <= rse.pc;
			o.offset <= rse.pc.offset + 4'd6;
		end
	Qupls5_pkg::OP_CSR:
		if (ir.Rs2==9'd1) begin	// cap CSR functionality
			case(ir.op3)
			3'd0:						// just read CSR
				begin
					o <= csr;
					o_flags <= 8'h00;
				end
			3'd1:						// read-write CSR
				begin
					o <= csr;
					o_flags <= 8'h00;
				end
			default:
				begin
					excv <= TRUE;
					exc <= Qupls5_pkg::FLT_UNIMP;
				end
			endcase
		end
	endcase
end

endmodule
