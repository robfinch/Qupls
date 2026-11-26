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
input [335:0] instr_raw;
output aregno_t Rd;
output reg Rdv;
output reg Rdz;
output reg we;

function aregno_t fnRd;
input Qupls5_pkg::micro_op_t instr;
input [335:0] instr_raw;
Qupls5_pkg::micro_op_t ir;
begin
	ir = instr;
	fnRd = 6'd0;
	case(ir.opcode)
	// Integer instructions
	Qupls5_pkg::OP_PPC_ADDI,Qupls5_pkg::OP_PPC_ADDIS:
		fnRd = {2'd0,ir.Rd};
	Qupls5_pkg::OP_PPC_ANDI,Qupls5_pkg::OP_PPC_ANDIS,
	Qupls5_pkg::OP_PPC_ORI,Qupls5_pkg::OP_PPC_ORIS,
	Qupls5_pkg::OP_PPC_XORI,Qupls5_pkg::OP_PPC_XORIS:
		fnRd = {2'd0,ir.Rd};
	Qupls5_pkg::OP_PPC_CMPI,Qupls5_pkg::OP_PPC_CMPLI:
		fnRd = {2'd0,6'd32};
	Qupls5_pkg::OP_PPC_RLWINM,
	Qupls5_pkg::OP_PPC_RLWNM,
	Qupls5_pkg::OP_PPC_RLWIMI,
	Qupls5_pkg::OP_PPC_RLDIC:
		fnRd = {2'd0,ir.Rd};
	// Branch instructions
	Qupls5_pkg::OP_PPC_B:
		fnRd = 6'd33;
	// Load / store instructions
	Qupls5_pkg::OP_PPC_LBZ,Qupls5_pkg::OP_PPC_LWZ,Qupls5_pkg::OP_PPC_LHZ,Qupls5_pkg::OP_PPC_LHA,Qupls5_pkg::OP_PPC_LQ:
		fnRd = ir.Rd;
	Qupls5_pkg::OP_31:
		case(ir.func)
		Qupls5_pkg::FN31_MTSPR:
			case(ir.spr)
			10'd256:	fnRd = 6'd33;		// LR
			10'd288:	fnRd = 6'd34;		// CTR
			10'd815:	fnRd = 6'd35;	// TAR
			endcase
	Qupls5_pkg::OP_19:
		case(ir.func)
		Qupls5_pkg::FN19_BCLR:
			fnRd = 6'd33;
		Qupls5_pkg::FN19_BCCTR:
			fnRd = 6'd33;
		Qupls5_pkg::FN19_BCTAR:
			fnRd = 6'd33;
		default:
			fnRd = 6'd0;
		endcase
		Qupls5_pkg::FN31_CMP,
		Qupls5_pkg::FN31_SUBFC,
		Qupls5_pkg::FN31_ADDC,
		Qupls5_pkg::FN31_MULHWU,
		Qupls5_pkg::FN31_MFCR,
		Qupls5_pkg::FN31_LDX,
		Qupls5_pkg::FN31_LWZX,
		Qupls5_pkg::FN31_SLW,
		Qupls5_pkg::FN31_CNTLZW,
		Qupls5_pkg::FN31_SLD,
		Qupls5_pkg::FN31_AND,
		Qupls5_pkg::FN31_CMPL,
		Qupls5_pkg::FN31_SUBF,
		Qupls5_pkg::FN31_LDUX,
		Qupls5_pkg::FN31_LWZUX,
		Qupls5_pkg::FN31_CNTLZD,
		Qupls5_pkg::FN31_CNTLZDM,
		Qupls5_pkg::FN31_ANDC,
		Qupls5_pkg::FN31_MULHW,
		Qupls5_pkg::FN31_LBZX,
		Qupls5_pkg::FN31_NEG,
		Qupls5_pkg::FN31_LBZUX,
		Qupls5_pkg::FN31_POPCNTB,
		Qupls5_pkg::FN31_NOR,
		Qupls5_pkg::FN31_SUBFE,
		Qupls5_pkg::FN31_ADDE,
	//	Qupls5_pkg::FN31_STDX,
	//	Qupls5_pkg::FN31_STWX,
		Qupls5_pkg::FN31_PRTYW,
		Qupls5_pkg::FN31_BRW,
		Qupls5_pkg::FN31_PDEPD,
		Qupls5_pkg::FN31_ADDEX,
		Qupls5_pkg::FN31_STWUX,
		Qupls5_pkg::FN31_PRTYD,
		Qupls5_pkg::FN31_BRD,
		Qupls5_pkg::FN31_PEXTD,
		Qupls5_pkg::FN31_SUBFZE,
		Qupls5_pkg::FN31_ADDZE,
	//	Qupls5_pkg::FN31_STBX,
		Qupls5_pkg::FN31_BRH,
		Qupls5_pkg::FN31_CFUGED,
		Qupls5_pkg::FN31_SUBFME,
		Qupls5_pkg::FN31_ADDME,
		Qupls5_pkg::FN31_MULLW,
		Qupls5_pkg::FN31_STBUX,
		Qupls5_pkg::FN31_BPERMD,
		Qupls5_pkg::FN31_ADD,
		Qupls5_pkg::FN31_LHZX,
		Qupls5_pkg::FN31_EQV,
		Qupls5_pkg::FN31_LHZUX,
		Qupls5_pkg::FN31_XOR,
		Qupls5_pkg::FN31_MFSPR,
		Qupls5_pkg::FN31_LWAX,
		Qupls5_pkg::FN31_LHAX,
		Qupls5_pkg::FN31_LWAUX,
		Qupls5_pkg::FN31_LHAUX,
		Qupls5_pkg::FN31_POPCNTW,
		Qupls5_pkg::FN31_DIVWEU,
	//	Qupls5_pkg::FN31_STHX,
		Qupls5_pkg::FN31_ORC,
		Qupls5_pkg::FN31_SRADI,
		Qupls5_pkg::FN31_DIVWE,
		Qupls5_pkg::FN31_STHUX,
		Qupls5_pkg::FN31_OR,
		Qupls5_pkg::FN31_EXTSWSLI,
		Qupls5_pkg::FN31_DIVWU,
		Qupls5_pkg::FN31_MTSPR,
		Qupls5_pkg::FN31_NAND,
		Qupls5_pkg::FN31_DIVW,
		Qupls5_pkg::FN31_POPCNTD,
		Qupls5_pkg::FN31_CMPB,
		Qupls5_pkg::FN31_SUBFCO,
		Qupls5_pkg::FN31_ADDCO,
		Qupls5_pkg::FN31_SRW,
		Qupls5_pkg::FN31_SRD,
		Qupls5_pkg::FN31_CNTTZW,
		Qupls5_pkg::FN31_SUBFO,
		Qupls5_pkg::FN31_CNTTZD,
		Qupls5_pkg::FN31_CNTTZDM,
		Qupls5_pkg::FN31_NEGO,
		Qupls5_pkg::FN31_SUBFEO,
		Qupls5_pkg::FN31_ADDEO,
		Qupls5_pkg::FN31_SUBFZEO,
		Qupls5_pkg::FN31_ADDZEO,
		Qupls5_pkg::FN31_SUBFMEO,
		Qupls5_pkg::FN31_ADDMEO,
		Qupls5_pkg::FN31_MULLWO,
		Qupls5_pkg::FN31_ADDO,
		Qupls5_pkg::FN31_SRAW,
		Qupls5_pkg::FN31_SRAD,
		Qupls5_pkg::FN31_SRAWI,
		Qupls5_pkg::FN31_DIVWEUO,
		Qupls5_pkg::FN31_EXTSH,
		Qupls5_pkg::FN31_DIVWEO,
		Qupls5_pkg::FN31_EXTSB,
		Qupls5_pkg::FN31_DIVWUO,
		Qupls5_pkg::FN31_EXTSW,
		Qupls5_pkg::FN31_DIVWO:
			fnRd = ir.Rd;
		default:;
		endcase
	default:
		fnRd = 8'd0;
	endcase
end
endfunction

// ToDo: Fix these
function aregno_t fnRdv;
input Qupls5_pkg::micro_op_t instr;
input [335:0] instr_raw;
Qupls5_pkg::micro_op_t ir;
begin
	fnRdv = INV;
	ir = instr;
	case(ir.opcode)
	// Integer instructions
	Qupls5_pkg::OP_PPC_ADDI,Qupls5_pkg::OP_PPC_ADDIS,
	Qupls5_pkg::OP_PPC_ORI,Qupls5_pkg::OP_PPC_ORIS:
		fnRdv = |ir.Rd ? VAL : INV;
	Qupls5_pkg::OP_PPC_ANDI,Qupls5_pkg::OP_PPC_ANDIS,
	Qupls5_pkg::OP_PPC_XORI,Qupls5_pkg::OP_PPC_XORIS:
		fnRdv = VAL;
	Qupls5_pkg::OP_PPC_CMPI,Qupls5_pkg::OP_PPC_CMPLI:
		fnRdv = VAL;
	Qupls5_pkg::OP_PPC_RLWINM,
	Qupls5_pkg::OP_PPC_RLWNM,
	Qupls5_pkg::OP_PPC_RLWIMI,
	Qupls5_pkg::OP_PPC_RLDIC:
		fnRdv = VAL;
	// Load / store instructions
	Qupls5_pkg::OP_31:
		case(ir.func)
		Qupls5_pkg::FN31_MTSPR:
			case(ir.spr)
			10'd256:	fnRdv = VAL;		// LR
			10'd288:	fnRdv = VAL;		// CTR
			10'd815:	fnRdv = VAL;	// TAR
			endcase
		Qupls5_pkg::FN31_CMP,
		Qupls5_pkg::FN31_SUBFC,
		Qupls5_pkg::FN31_ADDC,
		Qupls5_pkg::FN31_MULHWU,
		Qupls5_pkg::FN31_MFCR,
		Qupls5_pkg::FN31_LDX,
		Qupls5_pkg::FN31_LWZX,
		Qupls5_pkg::FN31_SLW,
		Qupls5_pkg::FN31_CNTLZW,
		Qupls5_pkg::FN31_SLD,
		Qupls5_pkg::FN31_AND,
		Qupls5_pkg::FN31_CMPL,
		Qupls5_pkg::FN31_SUBF,
		Qupls5_pkg::FN31_LDUX,
		Qupls5_pkg::FN31_LWZUX,
		Qupls5_pkg::FN31_CNTLZD,
		Qupls5_pkg::FN31_CNTLZDM,
		Qupls5_pkg::FN31_ANDC,
		Qupls5_pkg::FN31_MULHW,
		Qupls5_pkg::FN31_LBZX,
		Qupls5_pkg::FN31_NEG,
		Qupls5_pkg::FN31_LBZUX,
		Qupls5_pkg::FN31_POPCNTB,
		Qupls5_pkg::FN31_NOR,
		Qupls5_pkg::FN31_SUBFE,
		Qupls5_pkg::FN31_ADDE,
	//	Qupls5_pkg::FN31_STDX,
	//	Qupls5_pkg::FN31_STWX,
		Qupls5_pkg::FN31_PRTYW,
		Qupls5_pkg::FN31_BRW,
		Qupls5_pkg::FN31_PDEPD,
		Qupls5_pkg::FN31_ADDEX,
		Qupls5_pkg::FN31_STWUX,
		Qupls5_pkg::FN31_PRTYD,
		Qupls5_pkg::FN31_BRD,
		Qupls5_pkg::FN31_PEXTD,
		Qupls5_pkg::FN31_SUBFZE,
		Qupls5_pkg::FN31_ADDZE,
	//	Qupls5_pkg::FN31_STBX,
		Qupls5_pkg::FN31_BRH,
		Qupls5_pkg::FN31_CFUGED,
		Qupls5_pkg::FN31_SUBFME,
		Qupls5_pkg::FN31_ADDME,
		Qupls5_pkg::FN31_MULLW,
		Qupls5_pkg::FN31_STBUX,
		Qupls5_pkg::FN31_BPERMD,
		Qupls5_pkg::FN31_ADD,
		Qupls5_pkg::FN31_LHZX,
		Qupls5_pkg::FN31_EQV,
		Qupls5_pkg::FN31_LHZUX,
		Qupls5_pkg::FN31_XOR,
		Qupls5_pkg::FN31_MFSPR,
		Qupls5_pkg::FN31_LWAX,
		Qupls5_pkg::FN31_LHAX,
		Qupls5_pkg::FN31_LWAUX,
		Qupls5_pkg::FN31_LHAUX,
		Qupls5_pkg::FN31_POPCNTW,
		Qupls5_pkg::FN31_DIVWEU,
	//	Qupls5_pkg::FN31_STHX,
		Qupls5_pkg::FN31_ORC,
		Qupls5_pkg::FN31_SRADI,
		Qupls5_pkg::FN31_DIVWE,
		Qupls5_pkg::FN31_STHUX,
		Qupls5_pkg::FN31_OR,
		Qupls5_pkg::FN31_EXTSWSLI,
		Qupls5_pkg::FN31_DIVWU,
		Qupls5_pkg::FN31_MTSPR,
		Qupls5_pkg::FN31_NAND,
		Qupls5_pkg::FN31_DIVW,
		Qupls5_pkg::FN31_POPCNTD,
		Qupls5_pkg::FN31_CMPB,
		Qupls5_pkg::FN31_SUBFCO,
		Qupls5_pkg::FN31_ADDCO,
		Qupls5_pkg::FN31_SRW,
		Qupls5_pkg::FN31_SRD,
		Qupls5_pkg::FN31_CNTTZW,
		Qupls5_pkg::FN31_SUBFO,
		Qupls5_pkg::FN31_CNTTZD,
		Qupls5_pkg::FN31_CNTTZDM,
		Qupls5_pkg::FN31_NEGO,
		Qupls5_pkg::FN31_SUBFEO,
		Qupls5_pkg::FN31_ADDEO,
		Qupls5_pkg::FN31_SUBFZEO,
		Qupls5_pkg::FN31_ADDZEO,
		Qupls5_pkg::FN31_SUBFMEO,
		Qupls5_pkg::FN31_ADDMEO,
		Qupls5_pkg::FN31_MULLWO,
		Qupls5_pkg::FN31_ADDO,
		Qupls5_pkg::FN31_SRAW,
		Qupls5_pkg::FN31_SRAD,
		Qupls5_pkg::FN31_SRAWI,
		Qupls5_pkg::FN31_DIVWEUO,
		Qupls5_pkg::FN31_EXTSH,
		Qupls5_pkg::FN31_DIVWEO,
		Qupls5_pkg::FN31_EXTSB,
		Qupls5_pkg::FN31_DIVWUO,
		Qupls5_pkg::FN31_EXTSW,
		Qupls5_pkg::FN31_DIVWO:
			fnRdv = VAL;
		default:;
		endcase
	// Branch instructions
	Qupls5_pkg::OP_PPC_B:
		fnRdv = ir.lk;
	Qupls5_pkg::OP_19:
		case(ir.func)
		Qupls5_pkg::FN19_BCLR,
		Qupls5_pkg::FN19_BCCTR,
		Qupls5_pkg::FN19_BCTAR:
			fnRdv = ir.lk;
		default:
			fnRdv = FALSE;
		endcase
	// Load / store instructions
	Qupls5_pkg::OP_PPC_LBZ,Qupls5_pkg::OP_PPC_LWZ,Qupls5_pkg::OP_PPC_LHZ,Qupls5_pkg::OP_PPC_LHA,Qupls5_pkg::OP_PPC_LQ:
		fnRdv = VAL;
	default:
		fnRdv = INV;
	endcase
end
endfunction

// Detect when Rd should be treated as not updateable.
function fnRdz;
input Qupls5_pkg::micro_op_t instr;
begin
	case(instr.opcode)
	// Integer instructions
	Qupls5_pkg::OP_PPC_ADDI,Qupls5_pkg::OP_PPC_ADDIS,
	Qupls5_pkg::OP_PPC_ORI,Qupls5_pkg::OP_PPC_ORIS:
		fnRdz = TRUE;
	default:	fnRdz = FALSE;
	endcase
end
endfunction

always_comb
begin
	Rd = fnRd(instr, instr_raw);
	Rdv = fnRdv(instr, instr_raw);
	Rdz = fnRdz(instr);
	we = Rdv;
end

endmodule
