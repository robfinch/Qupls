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
import Qupls4_pkg::*;

module Qupls4_branchmiss_pc(instr, brclass, pc, pc_stack, bt, takb, argA, argB, argC, argI, misspc, missgrp, dstpc, stomp_bno);
parameter ABITS=32;
input Qupls4_pkg::pipeline_reg_t instr;
input Qupls4_pkg::brclass_t brclass;
input pc_address_ex_t pc;
input pc_address_ex_t [8:0] pc_stack;
input bt;
input takb;
input value_t argA;
input value_t argB;
input value_t argC;
input value_t argI;
output pc_address_ex_t misspc;
output reg [2:0] missgrp;
output pc_address_ex_t dstpc;
output reg [4:0] stomp_bno;

Qupls4_pkg::micro_op_t ir;

always_comb
	ir = instr.uop;

reg [5:0] ino;
reg [5:0] ino5;
reg [63:0] disp;
reg [ABITS-1:0] rg;

always_comb
begin
//	disp = {{38{instr.ins.br.dispHi[3]}},instr.ins.br.dispHi,instr.ins.br.dispLo};
	misspc.pc = Qupls4_pkg::RSTPC;
	misspc.bno_t = 6'd1;
	misspc.bno_f = 6'd1;
	dstpc = pc;					// copy bno fields
	stomp_bno = 6'd0;

	case (brclass)
	Qupls4_pkg::BRC_BCCD:
		begin
			disp = {{44{ir.br.disp[19]}},ir.br.disp,1'b0};
			dstpc.pc = pc.pc + disp;
		end
	Qupls4_pkg::BRC_BCCR:
		dstpc.pc = argC;
	Qupls4_pkg::BRC_JSR:
		begin
			disp = {{23{instr.uop[47]}},instr.uop[47:7],1'b0};
			dstpc.pc = pc.pc + disp;
		end
	Qupls4_pkg::BRC_RTD:
		dstpc.pc = argA;
	// Must be tested before Ret
	Qupls4_pkg::BRC_ERET:
		begin
			dstpc.pc = (instr.uop[28:17]==12'd3 ? pc_stack[1].pc : pc_stack[0].pc) + (instr.uop[10:6] * 3'd6);
		end
	default:
		dstpc.pc = RSTPC;
	endcase

	case(brclass)
	/*
	BTS_REG:
		 begin
			misspc = bt ? tpc : argC + {{53{instr[39]}},instr[39:31],instr[12:11]};
		end
	*/
	Qupls4_pkg::BRC_BCCR,
	Qupls4_pkg::BRC_BCCD:
		begin
			case({bt,takb})
			2'b00:
				begin
					misspc = dstpc;
					stomp_bno = pc.bno_t;
					stomp_bno = 5'd0;
				end
			2'b01:
				begin
					misspc = dstpc;
					stomp_bno = pc.bno_t;
					stomp_bno = 5'd0;
				end
			2'b10:
				begin
					misspc = pc + 4'd6;
					stomp_bno = dstpc.bno_t;
					stomp_bno = 5'd0;
				end
			2'b11:
				begin
					misspc = pc + 4'd6;
					stomp_bno = dstpc.bno_t;
					stomp_bno = 5'd0;
				end
			endcase
//			misspc = bt ? pc + 4'd5 : pc + {{47{instr[39]}},instr[39:25],instr[12:11]};
		end
	default:
		begin
			misspc = dstpc;
			stomp_bno = dstpc.bno_t;
			stomp_bno = 5'd0;
		end
	endcase
end

always_comb
begin
	/*
	if (misspc[5:0] >= ibh.offs[3])
		missgrp = 3'd4;
	else if (misspc[5:0] >= ibh.offs[2])
		missgrp = 3'd3;
	else if (misspc[5:0] >= ibh.offs[1])
		missgrp = 3'd2;
	else if (misspc[5:0] >= ibh.offs[0])
		missgrp = 3'd1;
	else
	*/
		missgrp = 3'd0;
end

endmodule
