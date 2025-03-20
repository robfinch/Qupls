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
// ============================================================================

import cpu_types_pkg::*;
import QuplsPkg::*;

module Qupls_decode_Rc(om, ipl, ir, has_immc, Rc, Rcz, Rcn, Rcc);
input operating_mode_t om;
input [2:0] ipl;
input ex_instruction_t ir;
input has_immc;
output aregno_t Rc;
output reg Rcz;
output reg Rcn;
output reg [2:0] Rcc;

always_comb
begin
	Rc = 6'd0;
	Rcc = 3'd0;
	if (has_immc) begin
		Rc = 9'd0;
		Rcn = 1'b0;
		Rcc = 3'd0;
	end
	else
		case(ir.ins.any.opcode)
		OP_RTD:
			begin
				Rc = 6'd0;
				Rcn = 1'b0;
			end
		OP_FLT3H,OP_FLT3S,OP_FLT3D,OP_FLT3Q:
			begin
				Rc = ir.ins.f3.Rc.num;
				Rcn = ir.ins.f3.Rc.n;
			end
		OP_R3B,OP_R3W,OP_R3T,OP_R3O,OP_MOV:
			begin
				Rc = ir.ins.r3.Rc.num;
				Rcn = ir.ins.r3.Rc.n;
			end
		OP_CSR:
			begin
				Rc = 6'd0;
				Rcn = 1'b0;
			end
		OP_ADDI,OP_SUBFI,OP_CMPI,OP_CMPUI,
		OP_ANDI,OP_ORI,OP_EORI,
		OP_MULI,OP_MULUI,OP_DIVI,OP_DIVUI,
		OP_SEQI,OP_SNEI,OP_SLTI,OP_SLEI,OP_SGTI,OP_SGEI,OP_SLTUI,OP_SLEUI,OP_SGTUI,OP_SGEUI,
		OP_ADD2UI,OP_ADD4UI,OP_ADD8UI,OP_ADD16UI,
		OP_SHIFTB,OP_SHIFTW,OP_SHIFTT,OP_SHIFTO,
		OP_ZSEQI,OP_ZSNEI,OP_ZSLTI,OP_ZSLEI,OP_ZSGTI,OP_ZSGEI,OP_ZSLTUI,OP_ZSLEUI,OP_ZSGTUI,OP_ZSGEUI:
			begin
				Rc = 6'd0;
				Rcn = 1'b0;
			end
		OP_JSR,OP_CJSR:
			begin
				Rc = 6'd0;
				Rcn = 1'b0;
			end
		OP_JSRI,OP_JSRR,OP_CJSRI,OP_CJSRR:
			begin
				Rc = 6'd0;
				Rcn = 1'b0;
			end
		OP_Bcc,OP_BccU,OP_FBcc,OP_DFBcc,OP_PBcc,OP_IBcc,OP_DBcc,
		OP_BccR,OP_BccUR,OP_FBccR,OP_DFBccR,OP_PBccR,OP_CBccR,OP_IBccR,OP_DBccR:
			begin
				Rc = 6'd0;
				Rcn = 1'b0;
			end
		OP_LDxU,OP_LDx,OP_FLDx,OP_DFLDx,OP_PLDx,OP_LDCAPx,OP_CACHE,OP_LDA,OP_AMO,OP_CAS:
			begin
				Rc = 6'd0;
				Rcn = 1'b0;
			end
		// Stores use Rc to read store data, but it is encoded in Rt field.
		OP_STx,OP_STIx,OP_FSTx,OP_DFSTx,OP_PSTx,OP_STCAPx,OP_STPTR:
			begin
				Rc = ir.ins.ls.Rt.num;
				Rcn = 1'b0;
			end
		OP_ENTER,OP_LEAVE,OP_PUSH,OP_POP:
			begin
				Rc = 6'd0;
				Rcn = 1'b0;
			end
		default:
			begin
				Rc = 6'd0;
				Rcn = 1'b0;
			end
		endcase
	if (Rc==6'd31)
		Rc = 6'd32|om;
	Rcz = ~|Rc;
end

endmodule

