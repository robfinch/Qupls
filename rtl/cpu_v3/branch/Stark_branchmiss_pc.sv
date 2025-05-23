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

module Stark_branchmiss_pc(instr, brclass, pc, pc_stack, micro_ip, bt, takb, BRs, argA, argB, argI, misspc, missgrp, miss_mcip, dstpc, stomp_bno);
parameter ABITS=32;
input Stark_pkg::pipeline_reg_t instr;
input Stark_pkg::brclass_t brclass;
input pc_address_ex_t pc;
input mc_address_t micro_ip;
input pc_address_ex_t [8:0] pc_stack;
input bt;
input takb;
input [2:0] BRs;
input value_t argA;
input value_t argB;
input value_t argI;
output pc_address_ex_t misspc;
output reg [2:0] missgrp;
output mc_address_t miss_mcip;
output pc_address_ex_t dstpc;
output reg [4:0] stomp_bno;

Stark_pkg::instruction_t ir;

always_comb
	ir = instr.uop.ins;

reg [5:0] ino;
reg [5:0] ino5;
reg [63:0] disp;
reg [ABITS-1:0] rg;

always_comb
begin
//	disp = {{38{instr.ins.br.dispHi[3]}},instr.ins.br.dispHi,instr.ins.br.dispLo};
	miss_mcip = 12'h1A0;
	misspc.pc = Stark_pkg::RSTPC;
	misspc.bno_t = 6'd1;
	misspc.bno_f = 6'd1;
	dstpc = pc;					// copy bno fields
	stomp_bno = 6'd0;

	case (brclass)
	Stark_pkg::BRC_BCCD:
		begin
			disp = {{51{ir[30]}},ir[30:29],ir[16:9],ir[0],2'b00};
			case(BRs)
			3'd0:	rg = {ABITS{1'b0}};
			3'd7:	rg = pc.pc;
			default:	rg = argA;
			endcase
			dstpc.pc = rg + disp;
		end
	Stark_pkg::BRC_BCCR:
		begin
			disp = {argB[ABITS-1:2],2'b00};
			case(BRs)
			3'd0:	rg = {ABITS{1'b0}};
			3'd7:	rg = pc.pc;
			default:	rg = argA;
			endcase
			dstpc.pc = rg + disp;
		end
	Stark_pkg::BRC_BCCC:
		begin
			disp = ir[30] ? {argI[ABITS-1:2],2'b00} : {{32{argI[31]}},argI[31:2],2'b00};
			case(BRs)
			3'd0:	rg = {ABITS{1'b0}};
			3'd7:	rg = pc.pc;
			default:	rg = argA;
			endcase
			dstpc.pc = rg + disp;
		end
	Stark_pkg::BRC_BL:
		begin
			disp = {{39{instr.uop.ins.bl.disp[21]}},instr.uop.ins.bl.disp,instr.uop.ins.bl.d0};
			dstpc.pc = pc.pc + disp;
		end
	Stark_pkg::BRC_BLRLR:
		begin
			disp = {argB[ABITS-1:2],2'b00};
			case(BRs)
			3'd0:	rg = {ABITS{1'b0}};
			3'd7:	rg = pc.pc;
			default:	rg = argA;
			endcase
			dstpc.pc = rg + disp;
		end
	Stark_pkg::BRC_BLRLC:
		begin
			disp = ir[30] ? {argI[ABITS-1:2],2'b00} : {{32{argI[31]}},argI[31:2],2'b00};
			case(BRs)
			3'd0:	rg = {ABITS{1'b0}};
			3'd7:	rg = pc.pc;
			default:	rg = argA;
			endcase
			dstpc.pc = rg + disp;
		end	
	Stark_pkg::BRC_RETR,
	Stark_pkg::BRC_RETC:
		begin
			case(BRs)
			3'd0:	rg = {ABITS{1'b0}};
			3'd7:	rg = pc.pc;			// SB unimplemented
			default:	rg = argA;
			endcase
			dstpc.pc = rg;
		end
	// Must be tested before Ret
	Stark_pkg::BRC_ERET:
		begin
			dstpc.pc = (instr.uop.ins[28:17]==12'd3 ? pc_stack[1].pc : pc_stack[0].pc) + (instr.uop.ins[10:6] * 3'd4);
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
	Stark_pkg::BRC_BCCR,
	Stark_pkg::BRC_BCCD,
	Stark_pkg::BRC_BCCC:
		begin
			case({bt,takb})
			2'b00:
				begin
					misspc = dstpc;
					miss_mcip = {1'b0,instr.uop.ins.mcb.disphi,instr.uop.ins.mcb.displo,instr.uop.ins.mcb.d0};
					stomp_bno = pc.bno_t;
					stomp_bno = 5'd0;
				end
			2'b01:
				begin
					misspc = dstpc;
					miss_mcip = {1'b0,instr.uop.ins.mcb.disphi,instr.uop.ins.mcb.displo,instr.uop.ins.mcb.d0};
					stomp_bno = pc.bno_t;
					stomp_bno = 5'd0;
				end
			2'b10:
				begin
					misspc = pc + 4'd4;
					miss_mcip = micro_ip + 3'd4;
					stomp_bno = dstpc.bno_t;
					stomp_bno = 5'd0;
				end
			2'b11:
				begin
					misspc = pc + 4'd4;
					miss_mcip = micro_ip + 3'd4;
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
