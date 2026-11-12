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
// 25 LUTs
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls5_pkg::*;

module Qupls5_decode_Rd(om, instr, instr_raw, Rd, Rdv, Rdz, we);
input Qupls5_pkg::operating_mode_t om;
input Qupls5_pkg::micro_op_t instr;
input [431:0] instr_raw;
output aregno_t Rd;
output reg Rdv;
output reg Rdz;
output reg we;

function aregno_t fnRd;
input Qupls5_pkg::micro_op_t instr;
input [431:0] instr_raw;
Qupls5_pkg::micro_op_t ir;
begin
	ir = instr;
	case(ir.opcode)
	// Integer instructions
	Qupls5_pkg::OP_R3B,Qupls5_pkg::OP_R3W,Qupls5_pkg::OP_R3T,Qupls5_pkg::OP_R3O:
		fnRd = {2'b00,ir.Rd};
	Qupls5_pkg::OP_VR3B,Qupls5_pkg::OP_VR3W,Qupls5_pkg::OP_VR3T,Qupls5_pkg::OP_VR3O:
		fnRd = {1'b1,ir.Rd[4:0],2'b00};
	Qupls5_pkg::OP_VSR3B,Qupls5_pkg::OP_VSR3W,Qupls5_pkg::OP_VSR3T,Qupls5_pkg::OP_VSR3O:
		fnRd = {1'b1,ir.Rd[4:0],2'b00};
	Qupls5_pkg::OP_CSR:
		fnRd = {2'd0,ir.Rd};
	Qupls5_pkg::OP_ADDI,Qupls5_pkg::OP_SUBFI,Qupls5_pkg::OP_CMPI,Qupls5_pkg::OP_CMPUI,
	Qupls5_pkg::OP_ANDI,Qupls5_pkg::OP_ORI,Qupls5_pkg::OP_XORI,
	Qupls5_pkg::OP_MULI,Qupls5_pkg::OP_MULUI,Qupls5_pkg::OP_DIVI,Qupls5_pkg::OP_DIVUI,
	Qupls5_pkg::OP_SHIFT:
		fnRd = {2'd0,ir.Rd};
	// FLoating-point instructions
	Qupls5_pkg::OP_FLTH,Qupls5_pkg::OP_FLTS,Qupls5_pkg::OP_FLTD,Qupls5_pkg::OP_FLTQ:
		case(ir.func)
		Qupls5_pkg::FLT_CLASS,
		Qupls5_pkg::FLT_FINITE,
		Qupls5_pkg::FLT_RM,
		Qupls5_pkg::FLT_SEQ,
		Qupls5_pkg::FLT_SLE,
		Qupls5_pkg::FLT_SLT,
		Qupls5_pkg::FLT_SNE,
		Qupls5_pkg::FLT_SIG,
		Qupls5_pkg::FLT_FTOI,
		Qupls5_pkg::FLT_ISNAN,
		Qupls5_pkg::FLT_CMP:
			fnRd = {2'd0,ir.Rd};
		default: fnRd = {2'd1,ir.Rd};
		endcase
	Qupls5_pkg::OP_VFLTH,Qupls5_pkg::OP_VFLTS,Qupls5_pkg::OP_VFLTD,Qupls5_pkg::OP_VFLTQ,
	Qupls5_pkg::OP_VSFLTH,Qupls5_pkg::OP_VSFLTS,Qupls5_pkg::OP_VSFLTD,Qupls5_pkg::OP_VSFLTQ:
		case(ir.func)
		Qupls5_pkg::FLT_CLASS,
		Qupls5_pkg::FLT_FINITE,
		Qupls5_pkg::FLT_RM,
		Qupls5_pkg::FLT_SEQ,
		Qupls5_pkg::FLT_SLE,
		Qupls5_pkg::FLT_SLT,
		Qupls5_pkg::FLT_SNE,
		Qupls5_pkg::FLT_SIG,
		Qupls5_pkg::FLT_FTOI,
		Qupls5_pkg::FLT_ISNAN,
		Qupls5_pkg::FLT_CMP:
			fnRd = {1'd1,ir.Rd[4:0],2'd0};
		default: fnRd = {1'd1,ir.Rd[4:0],2'd0};
		endcase
	// Branch instructions
	Qupls5_pkg::OP_BSR,Qupls5_pkg::OP_JSR:
		fnRd = {2'd0,ir.Rd};
	Qupls5_pkg::OP_BCCU,Qupls5_pkg::OP_BCC,Qupls5_pkg::OP_MBCC:
		fnRd = ir.inc ? {2'd0,ir.Rs1} : 8'd0;
	Qupls5_pkg::OP_FBCC:
		fnRd = {2'd1,ir.Rs1};
	// Load / store instructions
	Qupls5_pkg::OP_LDB,Qupls5_pkg::OP_LDBZ,Qupls5_pkg::OP_LDW,Qupls5_pkg::OP_LDWZ,
	Qupls5_pkg::OP_LDT,Qupls5_pkg::OP_LDTZ,Qupls5_pkg::OP_LOAD,Qupls5_pkg::OP_LOADA,
	Qupls5_pkg::OP_AMO,Qupls5_pkg::OP_CMPSWAP:
		fnRd = ir.Rd;
	Qupls5_pkg::OP_LDV:
		fnRd = {1'b1,ir.Rd[4:0],2'd0};
	default:
		fnRd = 8'd0;
	endcase
end
endfunction

// ToDo: Fix these
function aregno_t fnRdv;
input Qupls5_pkg::micro_op_t instr;
input [431:0] instr_raw;
Qupls5_pkg::micro_op_t ir;
begin
	fnRdv = INV;
	ir = instr;
	case(ir.opcode)
	// Integer instructions
	Qupls5_pkg::OP_R3B,Qupls5_pkg::OP_R3W,Qupls5_pkg::OP_R3T,Qupls5_pkg::OP_R3O:
		fnRdv = VAL;
	Qupls5_pkg::OP_VR3B,Qupls5_pkg::OP_VR3W,Qupls5_pkg::OP_VR3T,Qupls5_pkg::OP_VR3O:
		fnRdv = VAL;
	Qupls5_pkg::OP_VSR3B,Qupls5_pkg::OP_VSR3W,Qupls5_pkg::OP_VSR3T,Qupls5_pkg::OP_VSR3O:
		fnRdv = VAL;
	Qupls5_pkg::OP_CSR:
		fnRdv = VAL;
	Qupls5_pkg::OP_ADDI,Qupls5_pkg::OP_SUBFI,Qupls5_pkg::OP_CMPI,Qupls5_pkg::OP_CMPUI,
	Qupls5_pkg::OP_ANDI,Qupls5_pkg::OP_ORI,Qupls5_pkg::OP_XORI,
	Qupls5_pkg::OP_MULI,Qupls5_pkg::OP_MULUI,Qupls5_pkg::OP_DIVI,Qupls5_pkg::OP_DIVUI,
	Qupls5_pkg::OP_SHIFT:
		fnRdv = VAL;

	Qupls5_pkg::OP_FLTH,Qupls5_pkg::OP_FLTS,Qupls5_pkg::OP_FLTD,Qupls5_pkg::OP_FLTQ:
		fnRdv = VAL;
	Qupls5_pkg::OP_VFLTH,Qupls5_pkg::OP_VFLTS,Qupls5_pkg::OP_VFLTD,Qupls5_pkg::OP_VFLTQ,
	Qupls5_pkg::OP_VSFLTH,Qupls5_pkg::OP_VSFLTS,Qupls5_pkg::OP_VSFLTD,Qupls5_pkg::OP_VSFLTQ:
		fnRdv = VAL;

	Qupls5_pkg::OP_BSR,Qupls5_pkg::OP_JSR:
		fnRdv = ~&ir.Rd;
	Qupls5_pkg::OP_BCCU,Qupls5_pkg::OP_BCC,Qupls5_pkg::OP_MBCC:
		fnRdv = ir.inc ? VAL : INV;

	Qupls5_pkg::OP_LDB,Qupls5_pkg::OP_LDBZ,Qupls5_pkg::OP_LDW,Qupls5_pkg::OP_LDWZ,
	Qupls5_pkg::OP_LDT,Qupls5_pkg::OP_LDTZ,Qupls5_pkg::OP_LOAD,Qupls5_pkg::OP_LOADA,
	Qupls5_pkg::OP_LDV,
	Qupls5_pkg::OP_AMO,Qupls5_pkg::OP_CMPSWAP:
		fnRdv = VAL;
	default:
		fnRdv = INV;
	endcase
end
endfunction

always_comb
begin
	Rd = fnRd(instr, instr_raw);
	Rdv = fnRdv(instr, instr_raw);
	Rdz = ~|Rd[5:0];
	we = |Rd[5:0] & Rdv;
end

endmodule
