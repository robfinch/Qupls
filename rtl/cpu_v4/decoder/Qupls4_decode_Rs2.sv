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
// 50 LUTs
// ============================================================================

import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_decode_Rs2(om, instr, instr_raw, has_immb, Rs2, Rs2z, has_Rs2, exc);
input Qupls4_pkg::operating_mode_t om;
input Qupls4_pkg::micro_op_t instr;
input [431:0] instr_raw;
input has_immb;
output aregno_t Rs2;
output reg Rs2z;
output reg exc;
output reg has_Rs2;

function aregno_t fnHas_Rs2;
input Qupls4_pkg::micro_op_t instr;
input has_immb;
Qupls4_pkg::micro_op_t ir;
begin
	ir = instr;
	fnHas_Rs2 = 1'b0;
	if (has_immb)
		fnHas_Rs2 = 1'b0;
	else
		case(ir.opcode)
/*		
		Qupls4_pkg::OP_MOV:
			if (ir[31]) begin
				case(ir.move.op3)
				3'd1:
					if (ir[25]==1'b1)		// XCHGMD
						fnHas_Rs2 = 1'b1;	// Rd
					else
						fnHas_Rs2 = 1'b0;
				3'd0:
					if (ir[25:21]==5'd1)	// XCHG
						fnHas_Rs2 = 1'b1;	// Rd
					else
						fnHas_Rs2 = 1'd0;
				default:
					fnHas_Rs2 = 1'd0;
				endcase
			end
			else
				fnHas_Rs2 = 1'd0;
*/				
		Qupls4_pkg::OP_FLTH,Qupls4_pkg::OP_FLTS,Qupls4_pkg::OP_FLTD,Qupls4_pkg::OP_FLTQ:
			fnHas_Rs2 = 1'b1;
		Qupls4_pkg::OP_CSR:
			fnHas_Rs2 = ir[31:29]==3'd0 ? 1'b1 : 1'b0;
		Qupls4_pkg::OP_BCC8,Qupls4_pkg::OP_BCC16,Qupls4_pkg::OP_BCC32,Qupls4_pkg::OP_BCC64,
		Qupls4_pkg::OP_BCCU8,Qupls4_pkg::OP_BCCU16,Qupls4_pkg::OP_BCCU32,Qupls4_pkg::OP_BCCU64:
			fnHas_Rs2 = 1'b1;
		Qupls4_pkg::OP_ADDI,Qupls4_pkg::OP_SUBFI,Qupls4_pkg::OP_CMPI,Qupls4_pkg::OP_CMPUI,
		Qupls4_pkg::OP_ANDI,Qupls4_pkg::OP_ORI,Qupls4_pkg::OP_XORI,
		Qupls4_pkg::OP_MULI,Qupls4_pkg::OP_MULUI,Qupls4_pkg::OP_DIVI,Qupls4_pkg::OP_DIVUI:
			fnHas_Rs2 = 1'b0;
		Qupls4_pkg::OP_SHIFT:
			fnHas_Rs2 = 1'b1;
		Qupls4_pkg::OP_LDB,Qupls4_pkg::OP_LDBZ,Qupls4_pkg::OP_LDW,Qupls4_pkg::OP_LDWZ,
		Qupls4_pkg::OP_LDT,Qupls4_pkg::OP_LDTZ,Qupls4_pkg::OP_LOAD,Qupls4_pkg::OP_LOADA,
		Qupls4_pkg::OP_STB,Qupls4_pkg::OP_STW,
		Qupls4_pkg::OP_STT,Qupls4_pkg::OP_STORE,
		Qupls4_pkg::OP_STPTR:
			fnHas_Rs2 = 1'b1;
		Qupls4_pkg::OP_AMO,
		Qupls4_pkg::OP_CMPSWAP:	fnHas_Rs2 = 1'b1;
		default:
			begin
				fnHas_Rs2 = 1'b0;
			end
		endcase
end
endfunction

function aregno_t fnRs2;
input Qupls4_pkg::micro_op_t instr;
input [335:0] instr_raw;
input has_immb;
Qupls4_pkg::micro_op_t ir;
begin
	ir = instr;
	if (has_immb)
		fnRs2 = 8'd0;
	else
		case(ir.opcode)
		Qupls4_pkg::OP_FLTH,Qupls4_pkg::OP_FLTS,Qupls4_pkg::OP_FLTD,Qupls4_pkg::OP_FLTQ:
			fnRs2 = {2'b01,ir.Rs2};
		Qupls4_pkg::OP_BCC8,Qupls4_pkg::OP_BCC16,Qupls4_pkg::OP_BCC32,Qupls4_pkg::OP_BCC64,
		Qupls4_pkg::OP_BCCU8,Qupls4_pkg::OP_BCCU16,Qupls4_pkg::OP_BCCU32,Qupls4_pkg::OP_BCCU64:
			fnRs2 = {1'b0,ir.Rs2};
		Qupls4_pkg::OP_ADDI,Qupls4_pkg::OP_SUBFI,Qupls4_pkg::OP_CMPI,Qupls4_pkg::OP_CMPUI,
		Qupls4_pkg::OP_ANDI,Qupls4_pkg::OP_ORI,Qupls4_pkg::OP_XORI,
		Qupls4_pkg::OP_MULI,Qupls4_pkg::OP_MULUI,Qupls4_pkg::OP_DIVI,Qupls4_pkg::OP_DIVUI,
		Qupls4_pkg::OP_SHIFT:
			fnRs2 = {1'b0,ir.Rs2};
		Qupls4_pkg::OP_LDB,Qupls4_pkg::OP_LDBZ,Qupls4_pkg::OP_LDW,Qupls4_pkg::OP_LDWZ,
		Qupls4_pkg::OP_LDT,Qupls4_pkg::OP_LDTZ,Qupls4_pkg::OP_LOAD,Qupls4_pkg::OP_LOADA,
		Qupls4_pkg::OP_AMO,Qupls4_pkg::OP_CMPSWAP,
		Qupls4_pkg::OP_STB,Qupls4_pkg::OP_STW,
		Qupls4_pkg::OP_STT,Qupls4_pkg::OP_STORE,Qupls4_pkg::OP_STI,
		Qupls4_pkg::OP_STPTR:
			fnRs2 = {1'b0,ir.Rs2};
		default:
			begin
				fnRs2 = 7'd0;
			end
		endcase
end
endfunction

always_comb
begin
	has_Rs2 = fnHas_Rs2(instr, has_immb);
	Rs2 = fnRs2(instr, instr_raw, has_immb);
	Rs2z = ~|Rs2;
//	tRegmap(om, Rs2, Rs2, exc);
end

endmodule
