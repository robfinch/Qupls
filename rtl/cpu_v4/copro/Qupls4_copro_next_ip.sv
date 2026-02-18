`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2026  Robert Finch, Waterloo
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

import const_pkg::*;
import cpu_types_pkg::*;
import wishbone_pkg::*;
import Qupls4_copro_pkg::*;

module Qupls4_copro_next_ip(rst, state, pe_vsync, miss, paging_en, ir,
	takb, after_pos, adr_hit, a, stack, sp, wait_active,
	req, resp, local_sel, roma, douta, arg_dat,
	ip, ipr, tblit_ip, cmdq_empty, next_ip);
parameter UNALIGNED_CONSTANTS = 0;
input rst;
input copro_state_t state;
input pe_vsync;
input [1:0] miss;
input paging_en;
input copro_instruction_t ir;
input takb;
input after_pos;
input adr_hit;
input [63:0] a;
input [19:2] ip;
input [19:2] ipr;
input [529:0] stack [0:15];
input [3:0] sp;
input cmdq_empty;
input wait_active;
input wb_cmd_request256_t req;
input wb_cmd_response256_t resp;
input local_sel;
input [12:0] roma;
input [63:0] douta;
input [63:0] arg_dat;
input address_t tblit_ip;
output reg [19:2] next_ip;

always_comb
if (rst)
	next_ip = 19'd0;
else begin
	next_ip = ip;
	case(state)
st_tblit_iret:
	next_ip = tblit_ip;
st_ifetch:
	begin
		if (!wait_active)
			next_ip = ip + 1;
		if (pe_vsync)
			next_ip = 19'h0080;
		else if (|miss & paging_en)
			next_ip = 19'h0004;
//		else if (!cmdq_empty)
//			next_ip <= ip;
	end
st_execute:	
	begin
		// WAIT
		// WAIT stops waiting when:
		// a) the scan address is greater than the specified one (if this condition is set)
		// b) an interrupt occurred
		// c) a write cycle to a specified location occurred.
		// While waiting the local memory is put in low power mode.
		case(ir.opcode)
		OP_WAIT:
			begin
				case(ir.imm[3:0])
				JGEP:
					if (after_pos)
						next_ip = ip;
				default:
					// Wait at address
					if (!adr_hit)
						next_ip = ip;
				endcase
			end

		// Conditional jumps
		OP_JCC:
			if (takb)
				next_ip = ir.imm;

		// Unconditional jumps / calls / return.
		OP_JMP:
			case(ir.Rd)
			4'd0:	next_ip = a + {{17{ir.imm[14]}},ir.imm};	// JMP
			4'd1:	next_ip = a + {{17{ir.imm[14]}},ir.imm};	// CALL
			4'd2:	next_ip = stack[sp][527:512];	//RET
			default:	;
			endcase
		OP_ADD64,OP_AND64,OP_STOREI64:
			begin
				if (~ipr[2] & UNALIGNED_CONSTANTS)
					;
				else
					next_ip = ip + 0;
			end
		default:;
		endcase
	end

// This state will be stripped out unless unaligned constants are allowed.
st_even64:
	next_ip = ip + 1;
st_even64a:
	next_ip = ip + 1;

st_odd64:
	next_ip = ip + 2;

// Memory states
st_ip_load:
	begin
		if (resp.ack) begin
			if (local_sel) begin
				casez(roma[12:3])
				10'h3??:	next_ip = arg_dat;
			  default:	next_ip = douta;
				endcase
			end
			else
				next_ip = resp.dat;
		end
	end
endcase
end

endmodule
