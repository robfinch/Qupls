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
// 15 LUTs
// ============================================================================

import cpu_types_pkg::*;
import Qupls5_pkg::*;

module Qupls5_decode_Rs3(om, instr, instr_raw, has_immc, Rs3, Rs3z);
input Qupls5_pkg::operating_mode_t om;
input Qupls5_pkg::micro_op_t instr;
input [431:0] instr_raw;
input has_immc;
output aregno_t Rs3;
output reg Rs3z;

function aregno_t fnRs3;
input Qupls5_pkg::micro_op_t instr;
input [335:0] instr_raw;
input has_immc;
Qupls5_pkg::micro_op_t ir;
reg has_rext;
begin
	ir = instr;
	has_rext = instr_raw[54:48]==Qupls5_pkg::OP_REXT;
	if (has_immc)
		fnRs3 = 8'd0;
	else
		case(ir.opcode)
		// Integer
		Qupls5_pkg::OP_R3B,Qupls5_pkg::OP_R3W,Qupls5_pkg::OP_R3T,Qupls5_pkg::OP_R3O:
			fnRs3 = has_rext ? instr_raw[48+34:48+28] : {2'b00,ir.Rs3};
		Qupls5_pkg::OP_VR3B,Qupls5_pkg::OP_VR3W,Qupls5_pkg::OP_VR3T,Qupls5_pkg::OP_VR3O:
			fnRs3 = has_rext ? instr_raw[48+34:48+28] : {2'b00,ir.Rs3[5:0]};
		Qupls5_pkg::OP_VSR3B,Qupls5_pkg::OP_VSR3W,Qupls5_pkg::OP_VSR3T,Qupls5_pkg::OP_VSR3O:
			fnRs3 = has_rext ? instr_raw[48+34:48+28] : {2'b00,ir.Rs3[5:0]};
		// Floating-point
		Qupls5_pkg::OP_FLTH,Qupls5_pkg::OP_FLTS,Qupls5_pkg::OP_FLTD,Qupls5_pkg::OP_FLTQ:
			case(ir.func)
			Qupls5_pkg::FLT_FMA,Qupls5_pkg::FLT_FMS,Qupls5_pkg::FLT_FNMA,Qupls5_pkg::FLT_FNMS:
				fnRs3 = {2'b01,ir.Rs3};
			default:
				fnRs3 = {2'b00,ir.Rs3};
			endcase
		Qupls5_pkg::OP_VFLTH,Qupls5_pkg::OP_VFLTS,Qupls5_pkg::OP_VFLTD,Qupls5_pkg::OP_VFLTQ,
		Qupls5_pkg::OP_VSFLTH,Qupls5_pkg::OP_VSFLTS,Qupls5_pkg::OP_VSFLTD,Qupls5_pkg::OP_VSFLTQ:
			case(ir.func)
			Qupls5_pkg::FLT_FMA,Qupls5_pkg::FLT_FMS,Qupls5_pkg::FLT_FNMA,Qupls5_pkg::FLT_FNMS:
				fnRs3 = {2'b01,ir.Rs3};
			default:
				fnRs3 = {2'b00,ir.Rs3};
			endcase
		// Load / store
		Qupls5_pkg::OP_STB,Qupls5_pkg::OP_STW,
		Qupls5_pkg::OP_STT,Qupls5_pkg::OP_STORE,Qupls5_pkg::OP_CSTORE,
		Qupls5_pkg::OP_STPTR:
			fnRs3 = has_rext ? instr_raw[48+34:48+28] : {2'b00,ir.Rd};
		default:
			fnRs3 = 8'd0;
		endcase
end
endfunction

always_comb
begin
	Rs3 = fnRs3(instr, instr_raw, has_immc);
	Rs3z = ~|Rs3[5:0];
end

endmodule
