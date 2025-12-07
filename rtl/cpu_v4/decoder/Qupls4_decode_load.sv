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

import Qupls4_pkg::*;

module Qupls4_decode_load(instr, load, vload, vload_ndx);
input Qupls4_pkg::micro_op_t instr;
output load;
output vload;
output vload_ndx;

function fnIsLoad;
input Qupls4_pkg::micro_op_t op;
begin
	case(op.any.opcode)
	Qupls4_pkg::OP_LDB,Qupls4_pkg::OP_LDBZ,Qupls4_pkg::OP_LDW,Qupls4_pkg::OP_LDWZ,
	Qupls4_pkg::OP_LDT,Qupls4_pkg::OP_LDTZ,Qupls4_pkg::OP_LOAD,Qupls4_pkg::OP_LDIP:
		fnIsLoad = 1'b1;
	default:
		fnIsLoad = 1'b0;
	endcase
end
endfunction

function fnIsVLoad;
input Qupls4_pkg::micro_op_t op;
begin
	case(op.any.opcode)
	Qupls4_pkg::OP_LDV:
		fnIsVLoad = 1'b1;
	default:
		fnIsVLoad = 1'b0;
	endcase
end
endfunction

function fnIsVLoadNdx;
input Qupls4_pkg::micro_op_t op;
begin
	case(op.any.opcode)
	Qupls4_pkg::OP_LDVN:
		fnIsVLoadNdx = 1'b1;
	default:
		fnIsVLoadNdx = 1'b0;
	endcase
end
endfunction

assign load = fnIsLoad(instr);
assign vload = fnIsVLoad(instr);
assign vload_ndx = fnIsVLoadNdx(instr);

endmodule
