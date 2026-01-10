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

import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_decode_Rs1(om, instr, instr_raw, has_imma, Rs1, Rs1z, Rs1ip);
input Qupls4_pkg::operating_mode_t om;
input Qupls4_pkg::micro_op_t instr;
input [431:0] instr_raw;
input has_imma;
output aregno_t Rs1;
output reg Rs1z;
output reg Rs1ip;

Qupls4_pkg::operating_mode_t om1;

function aregno_t fnRs1;
input Qupls4_pkg::micro_op_t ins;
input [431:0] instr_raw;
input has_imma;
Qupls4_pkg::micro_op_t ir;
reg has_rext;
begin
	ir = ins;
	has_rext = instr_raw[54:48] == OP_REXT;
	if (has_imma)
		fnRs1 = 8'd0;
	else
		case(ir.opcode)
/*			
		Qupls4_pkg::OP_MOV:
			if (ir[28:26] < 3'd4)
				fnRs1 = {ir[20:19],ir[15:11]};
			else
				fnRs1 = {2'b00,ir[15:11]};
*/				
		Qupls4_pkg::OP_FLTH,Qupls4_pkg::OP_FLTS,Qupls4_pkg::OP_FLTD,Qupls4_pkg::OP_FLTQ:
			fnRs1 = has_rext ? instr_raw[61:55] : {1'b0,ir.Rs1};
		Qupls4_pkg::OP_CSR:
			fnRs1 = has_rext ? instr_raw[61:55] : {1'b0,ir.Rs1};
		Qupls4_pkg::OP_ADDI,Qupls4_pkg::OP_SUBFI,Qupls4_pkg::OP_CMPI,Qupls4_pkg::OP_CMPUI,
		Qupls4_pkg::OP_ANDI,Qupls4_pkg::OP_ORI,Qupls4_pkg::OP_XORI,
		Qupls4_pkg::OP_MULI,Qupls4_pkg::OP_MULUI,Qupls4_pkg::OP_DIVI,Qupls4_pkg::OP_DIVUI,
		Qupls4_pkg::OP_SHIFT:
			fnRs1 = has_rext ? instr_raw[61:55] : {1'b0,ir.Rs1};
		Qupls4_pkg::OP_BCC8,Qupls4_pkg::OP_BCC16,Qupls4_pkg::OP_BCC32,Qupls4_pkg::OP_BCC64,
		Qupls4_pkg::OP_BCCU8,Qupls4_pkg::OP_BCCU16,Qupls4_pkg::OP_BCCU32,Qupls4_pkg::OP_BCCU64:
			fnRs1 = has_rext ? instr_raw[61:55] : {1'b0,ir.Rs1};
		Qupls4_pkg::OP_LDB,Qupls4_pkg::OP_LDBZ,
		Qupls4_pkg::OP_LDW,Qupls4_pkg::OP_LDWZ,
		Qupls4_pkg::OP_LDT,Qupls4_pkg::OP_LDTZ,
		Qupls4_pkg::OP_LOAD,Qupls4_pkg::OP_LOADA,
		Qupls4_pkg::OP_AMO,Qupls4_pkg::OP_CMPSWAP,
		Qupls4_pkg::OP_STB,Qupls4_pkg::OP_STW,Qupls4_pkg::OP_STT,Qupls4_pkg::OP_STORE,Qupls4_pkg::OP_STI,
		Qupls4_pkg::OP_STPTR:
			fnRs1 = has_rext ? instr_raw[61:55] : {1'b0,ir.Rs1};

		Qupls4_pkg::OP_PUSH,Qupls4_pkg::OP_POP:
			fnRs1 = 7'd0;
		default:
			fnRs1 = 7'd0;
		endcase
end
endfunction

always_comb
begin
	Rs1 = fnRs1(instr, instr_raw, has_imma);
	/*
	if (instr.ins.opcode==Qupls4_pkg::OP_MOV && instr.ins[28:26]==3'd1)	// MOVEMD?
		om1 = Qupls4_pkg::operating_mode_t'(instr.ins[24:23]);
    else
        om1 = om;
  */
	Rs1z = &Rs1[5:0];
	Rs1ip = Rs1==6'd62;
end

endmodule
