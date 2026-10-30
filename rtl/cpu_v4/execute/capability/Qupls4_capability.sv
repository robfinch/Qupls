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
import Qupls4_pkg::*;

module Qupls4_capability(ir, a, b, c, c_flags, d, d_flags, i, o, flags);
input Qupls4_pkg::micro_op_t ir;
input [63:0] a;
input [63:0] b;
input [63:0] c;
input [63:0] d;
input [63:0] i;
input cpu_types_pkg::flags_t c_flags;
input cpu_types_pkg::flags_t d_flags;
output cpu_types_pkg::[63:0] o;
output cpu_types_pkg::flags_t flags;

cpu_types_pkg::capability_high64_t dh = capability_high64_t'(d);

always_comb
begin
	o = 64'd0;
	case(ir.func)
	CAP_ANDPERM:
		begin
			if (ir.byteno==6'd1) begin
				flags = c_flags;
				o[44:27] = 18'h3fffe;						// seal
				o[63:48] = c[63:48] & b[15:0];	// and perms
				if (fnIsSealed(c))
					flags.cap = 1'b0;
			end
			else begin
				o = a;
				flags = 8'h00;
			end
		end
	CAP_CLEARTAG:
		if (ir.byteno==6'd1) begin
			flags = c_flags;
			flags.cap = FALSE;
			o = c;
		end
		else begin
			flags = 8'h00;
			o = a;
		end
	CAP_COPYTYPE:
		if (ir.byteno==6'd1) begin
			flags = c_flags;
			if (fnIsSealedOrReserved(d))
				flags.cap = FALSE;
			o = c;		// copy Rs1.cap_high to Rd.cap_high
		end
		else begin
			flags = 8'h00;
			o = {46'd0,d[44:27]};	// copy Rs2.otype to Rd.address
		end
	CAP_GETFLAGS:
		begin
			flags = 8'h00;
			o = c[47];
		end
	CAP_GETHIGH:
		begin
			flags = 8'h00;
			o = c;
		end
	CAP_GETOFFSET:
		begin
			flags = 8'h00;
			o = a;
		end
	CAP_GETPERMS:
		begin
			flags = 8'h00;
			o = {48'd0,c[63:48]};
		end
	CAP_GETSEALED:
		begin
			flags = 8'h00;
			o = {63'd0,fnIsSealed(c)};
		end
	CAP_GETTAG:
		begin
			flags = 8'h00;
			o = {63'd0,c_flags.cap};
		end
	CAP_GETTYPE:
		begin
			flags = 8'h00;
			o = fnGetOtype(c);
		end
	CAP_INCOFFSET:
		if (ir.byteno==6'd1) begin
			flags = c_flags;
			if (fnIsSealed(c) || !fnIsRepresentable(c,b))
				flags.cap = FALSE:
			o = c;
		end
		else begin
			flags = 8'h00;
			o = a + b;
		end
	CAP_INCOFFSETI:
		if (ir.byteno==6'd1) begin
			flags = c_flags;
			if (fnIsSealed(c) || !fnIsRepresentable(c,i))
				flags.cap = FALSE:
			o = c;
		end
		else begin
			flags = 8'h00;
			o = a + i;
		end
	CAP_MOVE:
		if (ir.byteno==6'd1) begin
			flags = c_flags;
			o = c;
		end
		else begin
			flags = 8'h00;
			o = a;
		end
	CAP_ALGNMASK:
		begin
			flags = 8'h00;
			o = fnAlignMask(a);
		end
	CAP_SEAL:
		if (ir.byteno==6'd1) begin
			flags = c_flags;
			if (fnIsSealed(c) || !dh.perms[7])	// permit seal?
				flags.cap = FALSE;
			o = c;
			o[44:27] = b[17:0];
		end
		else begin
			flags = 8'h00;
			o = a;
		end
	CAP_SEALENTRY:
		if (ir.byteno==6'd1) begin
			flags = c_flags;
			if (fnIsSealed(c))		// already sealed?
				flags.cap = FALSE;
			o = c;
			o[44:27] = 18'h3FFFE;	// SENTRY value
		end
		else begin
			flags = 8'h00;
			o = a;
		end
	CAP_SETADDR:
		if (ir.byteno==6'd1) begin
			flags = c_flags;
			if (fnIsSealed(c) || !fnIsRepresentable(c,b-a))
				flags.cap = FALSE:
			o = c;
		end
		else begin
			flags = 8'h00;
			o = b;
		end
	CAP_SETFLAGS:
		if (ir.byteno==6'd1) begin
			flags = c_flags;
			if (fnIsSealed(c))
				flags.cap = FALSE:
			o = c;
			o[47] = b[0];	// flags
		end
		else begin
			flags = 8'h00;
			o = a;
		end
	default:
		begin
			flags = 8'h00;
			o = 64'd0;
		end
	endcase
end

endmodule
