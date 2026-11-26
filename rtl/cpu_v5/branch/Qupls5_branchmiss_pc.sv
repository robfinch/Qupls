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
import capability_pkg::*;
import Qupls5_pkg::*;

module Qupls5_branchmiss_pc(clk, rse, pc_stack, takb, current_pc,
	misspc, missgrp, vector, live_stream, new_stream,
	syscall_vector, kernel_vector);
parameter ABITS=32;
//parameter RSTPC = Qupls5_pkg::RSTPC;
input clk;
input Qupls5_pkg::reservation_station_entry_t rse;
input Qupls5_pkg::pc_address_ex_t [Qupls5_pkg::ISTACK_DEPTH-1:0] pc_stack;
input [63:0] vector;
input takb;
input Qupls5_pkg::pc_address_ex_t current_pc;
input Qupls5_pkg::pc_address_ex_t  [4:0] syscall_vector;
input Qupls5_pkg::pc_address_ex_t  [4:0] kernel_vector;
output Qupls5_pkg::pc_address_ex_t misspc;
output reg [2:0] missgrp;
output cpu_types_pkg::pc_stream_t live_stream;
input cpu_types_pkg::pc_stream_t new_stream;

Qupls5_pkg::pc_address_ex_t dstpc;
Qupls5_pkg::micro_op_t ir;
value_t argA;
value_t argB;
value_t argC;
value_t argI;
uc64_capability_t capa;

always_comb
	ir = rse.uop;
always_comb argA = rse.arg[0].val;
always_comb argB = rse.arg[1].val;
always_comb argC = rse.arg[2].val;
always_comb argI = rse.argI;
always_comb capa = rse.cap_arg;

reg [5:0] ino;
reg [5:0] ino5;
reg [63:0] disp;
reg [ABITS-1:0] rg;

always_comb
if (rse.v) begin
//	disp = {{38{instr.ins.immHi[3]}},instr.ins.immHi,instr.ins.immLo};
//	misspc.bno_f = 6'd1;
	dstpc = rse.pc;					// copy bno fields

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
			dstpc.cap.offset = rse.pc.cap.offset + ir.imm;
			dstpc.stream = rse.pc.stream;
		end
	rse.bcc:
		begin
			if (rse.bcc_reg)
				dstpc.cap.offset = argA - dstpc.cap.base;
			else
				dstpc.cap.offset = rse.pc.cap.offset + ir.imm;
			$display("Qupls5: branching to: %h", dstpc.cap.offset);
			$display("  rse.pc=%h", rse.pc.cap.offset);
		end
	rse.bsr,
	rse.bra:
		begin
			dstpc.cap.offset = rse.pc.cap.offset + ir.imm;
		end
	rse.jsr,
	rse.jmp:
		begin
			dstpc.cap.offset = ir.imm - rse.pc.cap.base;
		end
	rse.cjsr:
		begin
			dstpc.cap.offset = ir.imm - rse.pc.cap.base;
		end

	rse.sys:
		begin
			case(ir.Rd)
			6'h02,6'h22:
				begin
					dstpc = syscall_vector[Qupls5_pkg::fnNextOm(rse.om)];
					dstpc.stream = rse.pc.stream;
				end
			6'h03,6'h23:
				begin
					dstpc = kernel_vector[Qupls5_pkg::fnNextOm(rse.om)];
					dstpc.stream = rse.pc.stream;
				end
			default:
				begin
					dstpc = kernel_vector[Qupls5_pkg::fnNextOm(rse.om)];
					dstpc.stream = rse.pc.stream;
				end
			endcase
		end
	// Must be tested before Ret
	rse.eret:
		begin
			dstpc.cap.offset = (ir[28:17]==12'd3 ? pc_stack[1].cap.offset : pc_stack[0].cap.offset) + (ir[10:7] * 3'd4);
			dstpc.stream = rse.pc.stream;
		end
	rse.ret:
		begin
			dstpc.cap.offset = argA;
			dstpc.stream = rse.pc.stream;
		end
	rse.cret:
		begin
			dstpc.cap.offset = capa.offset;
			dstpc.stream = rse.pc.stream;
		end
	default:
		begin
			dstpc.cap.offset = Qupls5_pkg::RSTPC;
			dstpc.stream = 5'd1;
		end
	endcase
end
else
	dstpc = current_pc;

always_ff @(posedge clk)
begin
	live_stream <= current_pc.stream.stream;
//	misspc <= {$bits(Qupls5_pkg::pc_address_ex_t){1'b0}};
//	misspc.cap.offset <= Qupls5_pkg::RSTPC;
//	misspc.stream <= 7'd1;
	misspc <= current_pc;
	misspc.cap.offset <= current_pc.cap.offset + 4'd4;
	if (rse.v)
	case(1'b1)
	/*+
	BTS_REG:
		 begin
			misspc = bt ? tpc : argC + {{53{instr[39]}},instr[39:31],instr[12:11]};
		end
	*/
	// rse.bcc also includes rse.mbcc
	rse.boi,rse.bcc,rse.bcc_reg:
		begin
			case({rse.bt,takb})
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
					misspc <= rse.pc;
					live_stream <= rse.pc.stream.stream;
				end
			// Predicted as not taken, but resolved as taken:
			//	 we need to update the PC to the new destination and allocate a new
			//   stream. We are not keeping the current stream.
			//   Consumed a new stream, so allocate the next one.
			2'b01:
				begin
					misspc <= dstpc;
					live_stream <= dstpc.stream.stream;
				end
			// Predicted as taken, but resolved as not taken:
			//   we need to back up to the last PC (the instruction after the branch).
			//   Switch stream back to the old one. The stream of the current PC which
			//   was assigned as a new stream for the branch is no longer valid.
			2'b10:
				begin
					misspc <= dstpc;
					misspc.cap.offset <= rse.pc.cap.offset + 4'd4;
					live_stream <= dstpc.stream.stream;
				end
			endcase
//			misspc = bt ? pc + 4'd5 : pc + {{47{instr[39]}},instr[39:25],instr[12:11]};
		end
	// Unconditional branches will always allocate a new stream.
	default:
		begin
			misspc <= dstpc;
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
