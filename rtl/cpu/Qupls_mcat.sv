// ============================================================================
//        __
//   \\__/ o\    (C) 2024-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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
// micro-code address table (mcat)
//
// ============================================================================
//
import QuplsPkg::*;

module Qupls_mcat(stomp, ir, mip);
input stomp;
input pipeline_reg_t ir;
output cpu_types_pkg::mc_address_t mip;

always_comb
if (stomp)
	mip = 12'h000;
else begin
	casez(ir.ins.any.opcode)
	OP_CHK:		mip = 12'h130;
	OP_ENTER:	mip = 12'h01C;
	OP_LEAVE:	mip = 12'h1E4;
	OP_JSRI:	mip = 12'h128;
//	OP_BSTORE:	mip = 12'h390;
//	OP_BMOV:	mip = 12'h3A0;
	OP_BCMP:	mip = 12'h3B0;
	OP_BFND:	mip = 12'h3C0;
	OP_PUSH:
		case(ir.ins[39:37])
		3'd7:	mip = 12'h260;			// pushv
		3'd0:	mip = 12'h300;			// pusha
		default:	mip = 12'h028;	// push	
		endcase
	OP_POP:
		case(ir.ins[39:37])
		3'd7:	mip = 12'h280;			// popv
		3'd0: mip = 12'h360;			// popa
		default:	mip = 12'h038;	// pop
		endcase
	OP_FLT3H,OP_FLT3S,OP_FLT3D,OP_FLT3Q:
		case(ir.ins.f3.func)
		FN_FLT1:
			case(ir.ins.f1.func)
			FN_FRES:
				case(ir.ins[26:25])
				2'd0: mip = 12'h0C0;
				2'd1:	mip = 12'h0D0;
				2'd2:	mip = 12'h0E0;
				2'd3: mip = 12'h0E0;
				endcase
			FN_RSQRTE:
				case(ir.ins[26:25])
				2'd0:	mip = 12'h050;
				2'd1:	mip = 12'h0A0;
				2'd2:	mip = 12'h080;
				2'd3: mip = 12'h070;
				endcase
			default:	mip = 12'h000;			
			endcase
		FN_FDIV:	mip = 12'h040;
		default:	mip = 12'h000;
		endcase
	OP_BFI:
		if (ir.ins[33]==1'b1)
			mip = 12'h220;
		else
			mip = 12'h000;
	7'b11???:	mip = 12'h220;
	default:	mip = 12'h000;
	endcase
end

endmodule
