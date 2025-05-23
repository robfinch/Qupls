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
import Stark_pkg::*;

module Stark_decode_Rs2(om, instr, has_immb, Rs2, Rs2z, has_Rs2, exc);
input Stark_pkg::operating_mode_t om;
input Stark_pkg::micro_op_t instr;
input has_immb;
output aregno_t Rs2;
output reg Rs2z;
output reg exc;
output reg has_Rs2;

function aregno_t fnHas_Rs2;
input Stark_pkg::micro_op_t instr;
input has_immb;
Stark_pkg::instruction_t ir;
begin
	ir = instr.ins;
	fnHas_Rs2 = 1'b0;
	if (has_immb)
		fnHas_Rs2 = 1'b0;
	else
		case(ir.any.opcode)
		Stark_pkg::OP_MOV:
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
		Stark_pkg::OP_FLT:	fnHas_Rs2 = 1'b1;
		Stark_pkg::OP_CSR:
			fnHas_Rs2 = ir[31:29]==3'd0 ? 1'b1 : 1'b0;
		Stark_pkg::OP_B0,Stark_pkg::OP_B1,Stark_pkg::OP_BCC0,Stark_pkg::OP_BCC1:
			if (ir[30:29]==2'b00 && ir[8:6]!=3'd7)
				fnHas_Rs2 = 1'b1;
			else
				fnHas_Rs2 = 1'b0;
		Stark_pkg::OP_ADD,Stark_pkg::OP_SUBF,Stark_pkg::OP_CMP,
		Stark_pkg::OP_AND,Stark_pkg::OP_OR,Stark_pkg::OP_XOR,
		Stark_pkg::OP_MUL,Stark_pkg::OP_DIV,
		Stark_pkg::OP_SHIFT:
			fnHas_Rs2 = ir[31:29]==3'd0;
		Stark_pkg::OP_LDB,Stark_pkg::OP_LDBZ,Stark_pkg::OP_LDW,Stark_pkg::OP_LDWZ,
		Stark_pkg::OP_LDT,Stark_pkg::OP_LDTZ,Stark_pkg::OP_LOAD,Stark_pkg::OP_LOADA,
		Stark_pkg::OP_STB,Stark_pkg::OP_STBI,Stark_pkg::OP_STW,Stark_pkg::OP_STWI,
		Stark_pkg::OP_STT,Stark_pkg::OP_STTI,Stark_pkg::OP_STORE,Stark_pkg::OP_STOREI,
		Stark_pkg::OP_STPTR:
			fnHas_Rs2 = ir[31:29]==3'd0;
		Stark_pkg::OP_AMO,
		Stark_pkg::OP_CMPSWAP:	fnHas_Rs2 = 1'b1;
		default:
			begin
				fnHas_Rs2 = 1'b0;
			end
		endcase
end
endfunction

function aregno_t fnRs2;
input Stark_pkg::micro_op_t instr;
input has_immb;
Stark_pkg::instruction_t ir;
begin
	ir = instr.ins;
	if (has_immb)
		fnRs2 = 8'd0;
	else
		case(ir.any.opcode)
		Stark_pkg::OP_FLT:
			fnRs2 = {2'b01,ir.fpu.Rs2};
		Stark_pkg::OP_CSR:
			fnRs2 = ir[31:29]==3'd0 ? {2'b00,ir.csrr.Rs2} : 7'd0;
		Stark_pkg::OP_B0,Stark_pkg::OP_B1,Stark_pkg::OP_BCC0,Stark_pkg::OP_BCC1:
			if (ir[30:29]==2'b00 && ir[8:6]!=3'd7)
				fnRs2 = {2'b00,ir[15:11]};
			else
				fnRs2 = 7'd0;
		Stark_pkg::OP_ADD,Stark_pkg::OP_SUBF,Stark_pkg::OP_CMP,
		Stark_pkg::OP_AND,Stark_pkg::OP_OR,Stark_pkg::OP_XOR,
		Stark_pkg::OP_MUL,Stark_pkg::OP_DIV,
		Stark_pkg::OP_SHIFT:
			fnRs2 = {instr.xRs2,ir.alu.Rs2};
		Stark_pkg::OP_LDB,Stark_pkg::OP_LDBZ,Stark_pkg::OP_LDW,Stark_pkg::OP_LDWZ,
		Stark_pkg::OP_LDT,Stark_pkg::OP_LDTZ,Stark_pkg::OP_LOAD,Stark_pkg::OP_LOADA,
		Stark_pkg::OP_AMO,Stark_pkg::OP_CMPSWAP,
		Stark_pkg::OP_STB,Stark_pkg::OP_STBI,Stark_pkg::OP_STW,Stark_pkg::OP_STWI,
		Stark_pkg::OP_STT,Stark_pkg::OP_STTI,Stark_pkg::OP_STORE,Stark_pkg::OP_STOREI,
		Stark_pkg::OP_STPTR:
			fnRs2 = {instr.xRs2,ir.lsscn.Rs2};
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
	Rs2 = fnRs2(instr, has_immb);
	Rs2z = ~|Rs2;
	tRegmap(om, Rs2, Rs2, exc);
end

endmodule
