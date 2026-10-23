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
// ============================================================================

import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_branchmiss_pc(clk, rse, pc_stack, bt, takb, current_pc,
	misspc, missgrp, dstpc, vector, live_stream, new_stream,
	syscall_vector, kernel_vector);
parameter ABITS=32;
input clk;
input Qupls4_pkg::reservation_station_entry_t rse;
input pc_address_ex_t [Qupls4_pkg::ISTACK_DEPTH-1:0] pc_stack;
input [63:0] vector;
input bt;
input takb;
input pc_address_ex_t current_pc;
input pc_address_t [4:0] syscall_vector;
input pc_address_t [4:0] kernel_vector;
output pc_address_ex_t misspc;
output reg [2:0] missgrp;
output pc_address_ex_t dstpc;
output pc_stream_t live_stream;
input pc_stream_t new_stream;

Qupls4_pkg::micro_op_t ir;
pc_address_ex_t pc = rse.pc;
value_t argA = rse.arg[0].val;
value_t argB = rse.arg[1].val;
value_t argC = rse.arg[2].val;
value_t argI = rse.argI;

always_comb
	ir = rse.uop;

reg [5:0] ino;
reg [5:0] ino5;
reg [63:0] disp;
reg [ABITS-1:0] rg;

always_comb
begin
//	disp = {{38{instr.ins.immHi[3]}},instr.ins.immHi,instr.ins.immLo};
//	misspc.bno_f = 6'd1;
	dstpc = pc;					// copy bno fields

	case(1'b1)

	rse.boi:
		/* ToDo:
		if (ir.md) begin
			dstpc.pc = ir.brr.Rs3==8'h00 ? vector : argC;
			dstpc.stream = rse.pc.stream;
		end
		else
		*/
		begin
			dstpc.pc = pc.pc + {{47{ir.imm[16]}},ir.imm[16:0]};
			dstpc.stream = rse.pc.stream;
		end

	// Note: zero has already been appended to the imm constant for branches by
	// the raw micro-op translation code.
	rse.mbcc:
		if (ir.ms[2]) begin
			dstpc.pc = argC;
			dstpc.stream = rse.pc.stream;
		end
		else begin
			dstpc.pc = pc.pc + {{51{ir.imm[12]}},ir.imm[12:0]};
			dstpc.stream = rse.pc.stream;
		end

	rse.bcc:
		if (ir.ms[2]) begin
			dstpc.pc = argC;
			dstpc.stream = rse.pc.stream;
		end
		else begin
			dstpc.pc = pc.pc + {{47{ir.imm[16]}},ir.imm[16:0]};
			dstpc.stream = rse.pc.stream;
		end

	rse.bsr:
		begin
			dstpc.pc = pc.pc + {{29{ir.imm[34]}},ir.imm[34:0]};
			dstpc.stream = rse.pc.stream;
		end
	rse.jsr:
		begin
			dstpc.pc = {{29{ir.imm[34]}},ir.imm[34:0]};
			dstpc.stream = rse.pc.stream;
		end

	rse.sys:
		begin
			case(ir.Rd)
			6'h02,6'h22:
				begin
					dstpc.pc = syscall_vector[Qupls4_pkg::fnNextOm(rse.om)];
					dstpc.stream = rse.pc.stream;
				end
			6'h03,6'h23:
				begin
					dstpc.pc = kernel_vector[Qupls4_pkg::fnNextOm(rse.om)];
					dstpc.stream = rse.pc.stream;
				end
			default:
				begin
					dstpc.pc = kernel_vector[Qupls4_pkg::fnNextOm(rse.om)];
					dstpc.stream = rse.pc.stream;
				end
			endcase
		end
	// Must be tested before Ret
	rse.eret:
		begin
			dstpc.pc = (ir[28:17]==12'd3 ? pc_stack[1].pc : pc_stack[0].pc) + (ir[10:7] * 3'd6);
			dstpc.stream = rse.pc.stream;
		end
	rse.ret:
		begin
			dstpc.pc = argA;
			dstpc.stream = rse.pc.stream;
		end
	default:
		begin
			dstpc.pc = RSTPC;
			dstpc.stream = 5'd1;
		end
	endcase
end

always_ff @(posedge clk)
begin
	live_stream <= 7'd0;
	misspc.pc <= Qupls4_pkg::RSTPC;
	misspc.stream <= 7'd1;
	case(1'b1)
	/*+
	BTS_REG:
		 begin
			misspc = bt ? tpc : argC + {{53{instr[39]}},instr[39:31],instr[12:11]};
		end
	*/
	// rse.bcc also includes rse.mbcc
	rse.boi,rse.bcc:
		begin
			case({bt,takb})
			// Predicted as not taken, and resolved as not taken:
			// 		stay in the same stream. We had the right stream to begin with. No
			//    branch is taking place. Nothing missed.
			// Predicted as taken, and resolved as taken:
			//   Nothing missed.
			//	 it was a branch so it will have been assigned a new stream. We will
			//   not be keeping the current stream. We want the next PC along the 
			//   taken path.
			// Transition the current PC from unknown to live.
			2'b00,2'b11:
				begin
					live_stream <= current_pc.stream;
				end
			// Predicted as not taken, but resolved as taken:
			//	 we need to update the PC to the new destination and allocate a new
			//   stream. We are not keeping the current stream.
			//   Consumed a new stream, so allocate the next one.
			2'b01:
				begin
					misspc <= dstpc;
					live_stream <= dstpc.stream;
				end
			// Predicted as taken, but resolved as not taken:
			//   we need to back up to the last PC (the instruction after the branch).
			//   Switch stream back to the old one. The stream of the current PC which
			//   was assigned as a new stream for the branch is no longer valid.
			2'b10:
				begin
					misspc.pc <= pc.pc + 4'd6;
					misspc.stream <= dstpc.stream;
					live_stream <= dstpc.stream;
				end
			endcase
//			misspc = bt ? pc + 4'd5 : pc + {{47{instr[39]}},instr[39:25],instr[12:11]};
		end
	// Unconditional branches will always allocate a new stream.
	default:
		begin
			misspc.pc <= dstpc.pc;
			misspc.stream = dstpc.stream;
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
