// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2026  Robert Finch, Waterloo
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
// 50 LUTs
// ============================================================================

import cpu_types_pkg::*;
import Qupls5_pkg::*;

module Qupls5_decode_Rs2(om, instr, instr_raw, has_immb, Rs2, Rs2z, has_Rs2);
input Qupls5_pkg::operating_mode_t om;
input Qupls5_pkg::micro_op_t instr;
input [431:0] instr_raw;
input has_immb;
output aregno_t Rs2;
output reg Rs2z;
output reg has_Rs2;

function aregno_t fnHas_Rs2;
input Qupls5_pkg::micro_op_t instr;
input has_immb;
Qupls5_pkg::micro_op_t ir;
begin
	ir = instr;
	fnHas_Rs2 = 1'b0;
	if (has_immb)
		fnHas_Rs2 = 1'b0;
	else
		case(ir.opcode)
		// Integer
		Qupls5_pkg::OP_R3B,Qupls5_pkg::OP_R3W,Qupls5_pkg::OP_R3T,Qupls5_pkg::OP_R3O:
			fnHas_Rs2 = 1'b1;
		Qupls5_pkg::OP_VR3B,Qupls5_pkg::OP_VR3W,Qupls5_pkg::OP_VR3T,Qupls5_pkg::OP_VR3O:
			fnHas_Rs2 = 1'b1;
		Qupls5_pkg::OP_VSR3B,Qupls5_pkg::OP_VSR3W,Qupls5_pkg::OP_VSR3T,Qupls5_pkg::OP_VSR3O:
			fnHas_Rs2 = 1'b1;
		Qupls5_pkg::OP_ADDI,Qupls5_pkg::OP_SUBFI,Qupls5_pkg::OP_CMPI,Qupls5_pkg::OP_CMPUI,
		Qupls5_pkg::OP_ANDI,Qupls5_pkg::OP_ORI,Qupls5_pkg::OP_XORI,
		Qupls5_pkg::OP_MULI,Qupls5_pkg::OP_MULUI,Qupls5_pkg::OP_DIVI,Qupls5_pkg::OP_DIVUI:
			fnHas_Rs2 = 1'b0;
		Qupls5_pkg::OP_SHIFT:
			fnHas_Rs2 = 1'b1;
		Qupls5_pkg::OP_CSR:
			fnHas_Rs2 = ir[31:29]==3'd0 ? 1'b1 : 1'b0;
		// Floating-point
		Qupls5_pkg::OP_FLTH,Qupls5_pkg::OP_FLTS,Qupls5_pkg::OP_FLTD,Qupls5_pkg::OP_FLTQ,
		Qupls5_pkg::OP_VFLTH,Qupls5_pkg::OP_VFLTS,Qupls5_pkg::OP_VFLTD,Qupls5_pkg::OP_VFLTQ,
		Qupls5_pkg::OP_VSFLTH,Qupls5_pkg::OP_VSFLTS,Qupls5_pkg::OP_VSFLTD,Qupls5_pkg::OP_VSFLTQ:
			case(ir.func)
			Qupls5_pkg::FLT_CLASS,
			Qupls5_pkg::FLT_FINITE,
			Qupls5_pkg::FLT_SIGN,
			Qupls5_pkg::FLT_FTOI,
			Qupls5_pkg::FLT_ITOF,
			Qupls5_pkg::FLT_TRUNC,
			Qupls5_pkg::FLT_ISNAN,
			Qupls5_pkg::FLT_ABS:
				fnHas_Rs2 = 1'b0;
			default:
				fnHas_Rs2 = 1'b1;
			endcase
		// Branch
		Qupls5_pkg::OP_MBCC,
		Qupls5_pkg::OP_FBCC,
		Qupls5_pkg::OP_BCC,
		Qupls5_pkg::OP_BCCU:
			fnHas_Rs2 = 1'b1;
		// Load / store
		Qupls5_pkg::OP_LDB,Qupls5_pkg::OP_LDBZ,Qupls5_pkg::OP_LDW,Qupls5_pkg::OP_LDWZ,
		Qupls5_pkg::OP_LDT,Qupls5_pkg::OP_LDTZ,Qupls5_pkg::OP_LOAD,Qupls5_pkg::OP_LOADA,
		Qupls5_pkg::OP_STB,Qupls5_pkg::OP_STW,Qupls5_pkg::OP_CLOAD,
		Qupls5_pkg::OP_STT,Qupls5_pkg::OP_STORE,Qupls5_pkg::OP_CSTORE,
		Qupls5_pkg::OP_STPTR:
			fnHas_Rs2 = 1'b1;
		Qupls5_pkg::OP_AMO,
		Qupls5_pkg::OP_CMPSWAP:	fnHas_Rs2 = 1'b1;
		default:
			begin
				fnHas_Rs2 = 1'b0;
			end
		endcase
end
endfunction

function aregno_t fnRs2;
input Qupls5_pkg::micro_op_t instr;
input [335:0] instr_raw;
input has_immb;
Qupls5_pkg::micro_op_t ir;
begin
	ir = instr;
	if (has_immb)
		fnRs2 = 8'd0;
	else
		case(ir.opcode)
		// Integer
		Qupls5_pkg::OP_R3B,Qupls5_pkg::OP_R3W,Qupls5_pkg::OP_R3T,Qupls5_pkg::OP_R3O:
			fnRs2 = {2'b00,ir.Rs2};
		Qupls5_pkg::OP_VR3B,Qupls5_pkg::OP_VR3W,Qupls5_pkg::OP_VR3T,Qupls5_pkg::OP_VR3O:
			fnRs2 = {1'b1,ir.Rs2[4:0],2'b00};
		Qupls5_pkg::OP_VSR3B,Qupls5_pkg::OP_VSR3W,Qupls5_pkg::OP_VSR3T,Qupls5_pkg::OP_VSR3O:
			fnRs2 = {1'b1,ir.Rs2[4:0],2'b00};
		Qupls5_pkg::OP_ADDI,Qupls5_pkg::OP_SUBFI,Qupls5_pkg::OP_CMPI,Qupls5_pkg::OP_CMPUI,
		Qupls5_pkg::OP_ANDI,Qupls5_pkg::OP_ORI,Qupls5_pkg::OP_XORI,
		Qupls5_pkg::OP_MULI,Qupls5_pkg::OP_MULUI,Qupls5_pkg::OP_DIVI,Qupls5_pkg::OP_DIVUI,
		Qupls5_pkg::OP_SHIFT:
			fnRs2 = {1'b0,ir.Rs2};
		// Floating-point
		Qupls5_pkg::OP_FLTH,Qupls5_pkg::OP_FLTS,Qupls5_pkg::OP_FLTD,Qupls5_pkg::OP_FLTQ:
			if (ir.func==Qupls5_pkg::FLT_SCALEB)
				fnRs2 = {2'b00,ir.Rs2};
			else
				fnRs2 = {2'b01,ir.Rs2};
		Qupls5_pkg::OP_VFLTH,Qupls5_pkg::OP_VFLTS,Qupls5_pkg::OP_VFLTD,Qupls5_pkg::OP_VFLTQ:
			fnRs2 = {1'b1,ir.Rs2[4:0],2'd00};
		Qupls5_pkg::OP_VSFLTH,Qupls5_pkg::OP_VSFLTS,Qupls5_pkg::OP_VSFLTD,Qupls5_pkg::OP_VSFLTQ:
			if (ir.func==Qupls5_pkg::FLT_SCALEB)
				fnRs2 = {2'b00,ir.Rs2};
			else
				fnRs2 = {2'b01,ir.Rs2};
		// Branch
		Qupls5_pkg::OP_BCC,
		Qupls5_pkg::OP_BCCU:
			fnRs2 = {2'b0,ir.Rs2};
		// Load / store
		Qupls5_pkg::OP_LDB,Qupls5_pkg::OP_LDBZ,Qupls5_pkg::OP_LDW,Qupls5_pkg::OP_LDWZ,
		Qupls5_pkg::OP_LDT,Qupls5_pkg::OP_LDTZ,Qupls5_pkg::OP_LOAD,Qupls5_pkg::OP_LOADA,
		Qupls5_pkg::OP_AMO,Qupls5_pkg::OP_CMPSWAP,Qupls5_pkg::OP_CLOAD,
		Qupls5_pkg::OP_STB,Qupls5_pkg::OP_STW,
		Qupls5_pkg::OP_STT,Qupls5_pkg::OP_STORE,Qupls5_pkg::OP_CSTORE,
		Qupls5_pkg::OP_STPTR:
			fnRs2 = {2'b0,ir.Rs2};
		default:
			begin
				fnRs2 = 8'd0;
			end
		endcase
end
endfunction

always_comb
begin
	has_Rs2 = fnHas_Rs2(instr, has_immb);
	Rs2 = fnRs2(instr, instr_raw, has_immb);
	Rs2z = ~|Rs2[5:0];
end

endmodule
