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

module Qupls4_branchmiss_pc(rse, pc_stack, bt, takb,
	misspc, missgrp, dstpc, vector, kept_stream, new_stream, alloc_new_stream,
	syscall_vector, kernel_vector);
parameter ABITS=32;
input Qupls4_pkg::reservation_station_entry_t rse;
input pc_address_ex_t [Qupls4_pkg::ISTACK_DEPTH-1:0] pc_stack;
input [63:0] vector;
input bt;
input takb;
input pc_address_t [4:0] syscall_vector;
input pc_address_t [4:0] kernel_vector;
output pc_address_ex_t misspc;
output reg [2:0] missgrp;
output pc_address_ex_t dstpc;
output pc_stream_t kept_stream;
input pc_stream_t new_stream;
output reg alloc_new_stream;

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
	misspc.pc = Qupls4_pkg::RSTPC;
	misspc.stream = 7'd1;
//	misspc.bno_f = 6'd1;
	dstpc = pc;					// copy bno fields
	kept_stream = 7'd0;
	alloc_new_stream = 1'b0;

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
			disp = {{44{ir.imm[19]}},ir.imm,1'b0};
			dstpc.pc = pc.pc + disp;
			dstpc.stream = rse.pc.stream;
		end

	rse.bcc:
		/*
		if (ir.md) begin
			dstpc.pc = argC;
			dstpc.stream = rse.pc.stream;
		end
		else
		*/
		begin
			disp = {{44{ir.imm[19]}},ir.imm,1'b0};
			dstpc.pc = pc.pc + disp;
			dstpc.stream = rse.pc.stream;
		end

	rse.bsr:
		begin
			disp = {{29{ir.imm[34]}},ir.imm,1'b0};
			dstpc.pc = pc.pc + disp;
			dstpc.stream = new_stream;
			alloc_new_stream = 1'b1;
		end
	rse.jsr:
		begin
			disp = {{29{ir.imm[34]}},ir.imm,1'b0};
			dstpc.pc = disp;
			dstpc.stream = new_stream;
			alloc_new_stream = 1'b1;
		end
	rse.sys:
		begin
			case(ir.Rd)
			6'h02,6'h22:
				begin
					dstpc.pc = syscall_vector[Qupls4_pkg::fnNextOm(rse.om)];
					dstpc.stream = new_stream;
					alloc_new_stream = 1'b1;
				end
			6'h03,6'h23:
				begin
					dstpc.pc = kernel_vector[Qupls4_pkg::fnNextOm(rse.om)];
					dstpc.stream = new_stream;
					alloc_new_stream = 1'b1;
				end
			default:
				begin
					dstpc.pc = kernel_vector[Qupls4_pkg::fnNextOm(rse.om)];
					dstpc.stream = new_stream;
					alloc_new_stream = 1'b1;
				end
			endcase
		end
	// Must be tested before Ret
	rse.eret:
		dstpc.pc = (ir[28:17]==12'd3 ? pc_stack[1].pc : pc_stack[0].pc) + (ir[10:7] * 3'd6);
	rse.ret:
		dstpc.pc = argA;
	default:
		dstpc.pc = RSTPC;
	endcase

	case(1'b1)
	/*
	BTS_REG:
		 begin
			misspc = bt ? tpc : argC + {{53{instr[39]}},instr[39:31],instr[12:11]};
		end
	*/
	rse.boi,rse.bcc:
		begin
			case({bt,takb})
			2'b00:
				begin
					misspc.pc = dstpc;
//					kept_stream = pc.bno_t;
					kept_stream = 7'd0;
				end
			2'b01:
				begin
					misspc.pc = dstpc;
					misspc.stream = new_stream;
					alloc_new_stream = 1'b1;
					kept_stream = pc.stream;
//					kept_stream = 5'd0;
				end
			2'b10:
				begin
					misspc.pc = pc + 4'd6;
					misspc.stream = new_stream;
					alloc_new_stream = 1'b1;
					kept_stream = dstpc.stream;
//					kept_stream = 5'd0;
				end
			2'b11:
				begin
					misspc.pc = pc + 4'd6;
					misspc.stream = pc.stream;
//					kept_stream = dstpc.bno_t;
					kept_stream = 7'd0;
				end
			endcase
//			misspc = bt ? pc + 4'd5 : pc + {{47{instr[39]}},instr[39:25],instr[12:11]};
		end
	default:
		begin
			misspc = dstpc;
//			kept_stream = dstpc.bno_t;
			kept_stream = 7'd0;
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
