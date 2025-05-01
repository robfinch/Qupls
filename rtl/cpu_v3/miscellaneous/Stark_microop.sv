// ============================================================================
//        __
//   \\__/ o\    (C) 2025  Robert Finch, Waterloo
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
//  180 LUTs / 0 FFs
// ============================================================================

import const_pkg::*;
import Stark_pkg::*;

module Stark_microop(om, ir, num, carry_reg, carry_out, carry_in, count, uop);
input Stark_pkg::operating_mode_t om;
input Stark_pkg::instruction_t ir;
input [2:0] num;
input [7:0] carry_reg;
input carry_out;
input carry_in;
output reg [2:0] count;
output Stark_pkg::micro_op_t [7:0] uop;

integer nn;
Stark_pkg::cmp_inst_t icmp,fcmp;
Stark_pkg::instruction_t nopi;

always_comb
begin
	icmp = cmp_inst_t'(32'd0);
	icmp.Rs2 = 5'd0;		// compare to zero
	icmp.Rs1 = ir.alu.Rd;
	icmp.op2 = 2'd0;		// signed integer compare
	icmp.CRd = 3'd0;		// CR0
	icmp.opcode = Stark_pkg::OP_CMP;
end
always_comb
begin
	fcmp = cmp_inst_t'(32'd0);
	fcmp.Rs2 = 5'd0;		// compare to zero
	fcmp.Rs1 = ir.fpu.Rd;
	fcmp.op2 = 2'd2;		// float compare
	fcmp.CRd = 3'd1;		// CR1
	fcmp.opcode = Stark_pkg::OP_CMP;
end
always_comb
begin
	nopi = {26'd0,Stark_pkg::OP_NOP};
end

always_comb
begin
	count = 3'd0;
	uop[0] = {$bits(Stark_pkg::micro_op_t){1'b0}};
	uop[1] = {$bits(Stark_pkg::micro_op_t){1'b0}};
	uop[2] = {$bits(Stark_pkg::micro_op_t){1'b0}};
	uop[3] = {$bits(Stark_pkg::micro_op_t){1'b0}};
	uop[4] = {$bits(Stark_pkg::micro_op_t){1'b0}};
	uop[5] = {$bits(Stark_pkg::micro_op_t){1'b0}};
	uop[6] = {$bits(Stark_pkg::micro_op_t){1'b0}};
	uop[7] = {$bits(Stark_pkg::micro_op_t){1'b0}};
	case(ir.any.opcode)
	Stark_pkg::OP_BRK:	begin uop[0] = {1'b1,1'b0,3'd1,3'd0,6'd0,4'd0,ir}; count = 3'd1; end
	Stark_pkg::OP_SHIFT:
		begin
			if (ir[16]) begin
				count = 3'd2;
				uop[0] = {1'b1,1'b0,3'd2,3'd0,6'd0,4'd0,ir};
				uop[1] = {1'b1,1'b0,3'd0,3'd1,6'd0,4'd0,icmp};
			end
			else begin
				count = 3'd1;
				uop[0] = {1'b1,1'b0,3'd1,3'd0,6'd0,4'd0,ir};
			end
		end
	Stark_pkg::OP_CMP:
		begin
			count = 3'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,6'd0,4'd0,ir};
		end
	Stark_pkg::OP_ADD,
	Stark_pkg::OP_ADB,
	Stark_pkg::OP_SUBF:
		begin
			case({carry_out,carry_in,ir[16]})
			3'b000:
				begin
					count = 3'd1;
					uop[0] = {1'b1,1'b0,3'd1,3'd0,6'd0,4'd0,ir};
				end
			3'b001:
				begin
					count = 3'd2;
					uop[0] = {1'b1,1'b0,3'd2,3'd0,6'd0,4'd0,ir};
					uop[1] = {1'b1,1'b0,3'd0,3'd1,6'd0,4'd0,icmp};
				end
			3'b010:
				begin
					tAddCarryIn(3'd2);
				end
			3'b011:
				begin
					tAddCarryIn(3'd3);
					uop[2] = {1'b1,1'b0,3'd0,3'd2,6'd0,4'd0,icmp};
				end
			3'b100:	
				begin
					if (ir[31]) begin
						count = 3'd2;
						uop[0] = {
							1'b1,
							1'b0,
							3'd2,
							3'd0,
							6'd0,
							4'd1,		// xop4 = AGC
							ir
						};
						uop[0].xRd = carry_reg[6:5];
						uop[0].ins.alu.Rd = carry_reg[4:0];
						uop[1] = {
							1'b1,
							1'b0,
							3'd0,
							3'd1,
							6'd0,
							4'd0,
							ir
						};
					end
					else begin
						count = 3'd2;
						uop[0] = {
							1'b1,
							1'b0,
							3'd2,
							3'd0,
							6'd0,
							4'd1,
							ir
						};
						uop[0].xRd = carry_reg[6:5];
						uop[0].ins.alu.Rd = carry_reg[4:0];
						uop[0].ins.alu.op4 = 4'd1;	// AGC
						uop[1] = {1'b1,1'b0,3'd0,3'd1,6'd0,4'd0,ir};
					end
				end
			3'b101:	
				begin
					if (ir[31]) begin
						count = 3'd3;
						uop[0] = {
							1'b1,
							1'b0,
							3'd2,
							3'd0,
							6'd0,
							4'd1,		// xop4 = AGC
							ir
						};
						uop[0].xRd = carry_reg[6:5];
						uop[0].ins.alu.Rd = carry_reg[4:0];
						uop[1] = {
							1'b1,
							1'b0,
							3'd0,
							3'd1,
							6'd0,
							4'd0,
							ir
						};
					end
					else begin
						count = 3'd3;
						uop[0] = {
							1'b1,
							1'b0,
							3'd2,
							3'd0,
							6'd0,
							4'd1,
							ir
						};
						uop[0].xRd = carry_reg[6:5];
						uop[0].ins.alu.Rd = carry_reg[4:0];
						uop[0].ins.alu.op4 = 4'd1;	// AGC
						uop[1] = {1'b1,1'b0,3'd0,3'd1,6'd0,4'd0,ir};
					end
					uop[2] = {1'b1,1'b0,3'd0,3'd2,6'd0,4'd0,icmp};
				end
			3'b110:	tAddCarryInOut(3'd5);
			3'b111:
				begin
					tAddCarryInOut(3'd6);
					uop[5] = {1'b1,1'b0,3'd0,3'd5,6'd0,4'd0,icmp};
				end
			endcase
		end
	Stark_pkg::OP_CSR,
	Stark_pkg::OP_AND,
	Stark_pkg::OP_OR,
	Stark_pkg::OP_XOR,
	Stark_pkg::OP_LDB,Stark_pkg::OP_LDBZ,Stark_pkg::OP_LDW,Stark_pkg::OP_LDWZ,
	Stark_pkg::OP_LDT,Stark_pkg::OP_LDTZ,Stark_pkg::OP_LOAD,Stark_pkg::OP_LOADA,
	Stark_pkg::OP_AMO,Stark_pkg::OP_CMPSWAP:
		if (ir[16]) begin
			count = 3'd2;
			uop[0] = {1'b1,1'b0,3'd2,3'd0,6'd0,4'd0,ir};
			uop[1] = {1'b1,1'b0,3'd0,3'd1,6'd0,4'd0,icmp};
		end
		else begin
			count = 3'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,6'd0,4'd0,ir};
		end	
	Stark_pkg::OP_MOV:
		if (ir[16]) begin
			count = 3'd2;
			uop[0] = {1'b1,1'b0,3'd2,3'd0,6'd0,4'd0,ir};
			uop[1] = {1'b1,1'b0,3'd0,3'd1,6'd0,4'd0,icmp};
			uop[0].exc = fnRegExc(om, {ir.move.Rs1h,ir.move.Rs1}) | fnRegExc(om, {ir.move.Rdh,ir.move.Rd});
		end
		else begin
			count = 3'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,6'd0,4'd0,ir};
		end	
	Stark_pkg::OP_B0,
	Stark_pkg::OP_B1:
		begin
			count = 3'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,6'd0,4'd0,ir};
		end
	Stark_pkg::OP_BCC0,		
	Stark_pkg::OP_BCC1:
		begin
			if (ir.bccld.cnd==3'd2 || ir.bccld.cnd==3'd5) begin	// no decrement
				count = 3'd1;
				uop[0] = {1'b1,1'b0,3'd1,3'd0,6'd0,4'd0,ir};
			end
			else begin
				count = 3'd2;
				// Decrement loop counter
				// ADD LC,LC,-1
				uop[0] = {1'b1,1'b0,3'd2,3'd0,6'h0A,4'd0,1'b1,14'h3FFF,1'b0,5'd12,5'd12,Stark_pkg::OP_ADD};
				uop[1] = {1'b1,1'b0,3'd0,3'd1,6'd0,4'd0,ir};
			end
		end
	Stark_pkg::OP_TRAP,
	Stark_pkg::OP_CHK,
	Stark_pkg::OP_POP,
	Stark_pkg::OP_PUSH,
	Stark_pkg::OP_STB,Stark_pkg::OP_STBI,Stark_pkg::OP_STW,Stark_pkg::OP_STWI,
	Stark_pkg::OP_STT,Stark_pkg::OP_STTI,Stark_pkg::OP_STORE,Stark_pkg::OP_STOREI,
	Stark_pkg::OP_STPTR,
	Stark_pkg::OP_FENCE:
		begin
			count = 3'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,6'd0,4'd0,ir};
		end
	Stark_pkg::OP_FLT:
		begin
			if (ir[16]) begin
				count = 3'd2;
				uop[0] = {1'b1,1'b0,3'd2,3'd0,6'd0,4'd0,ir};
				uop[1] = {1'b1,1'b0,3'd0,3'd1,6'd0,4'd0,fcmp};
			end
			else begin
				count = 3'd1;
				uop[0] = {1'b1,1'b0,3'd1,3'd0,6'd0,4'd0,ir};
			end	
			// ToDo: exceptions on Rd,Rs1,Rs2
			//uop[0].exc = fnRegExc(om, {2'b10,ir.fpu.Rs1}) | fnRegExc(om, {2'b10,ir.fpu.Rd});
		end
	Stark_pkg::OP_MOD,Stark_pkg::OP_NOP:
		begin
			count = 3'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,6'd0,4'd0,ir};
		end
	default:
		begin
			count = 3'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,6'd0,4'd0,ir};
		end
	endcase
	for (nn = 0; nn < 8; nn = nn + 1) begin
		if (nn < num)
			uop[nn].v = 1'b0;
	end	
end

task tAddCarryIn;
input [3:0] cnt;
begin
	count = cnt;
	// ADD Rd,Rs1,carry_reg
	uop[0] = {
		1'b1,
		1'b0,
		count[2:0],
		3'd0,
		carry_reg[6:5],
		4'd0,
		4'd0,
		10'd0,
		carry_reg[4:0],
		1'b0,
		ir.alu.Rs1,
		ir.alu.Rd,
		ir.any.opcode
	};
	// ADD Rd,Rd,Rs2 or immediate
	uop[1] = {
		1'b1,
		1'b0,
		3'd0,
		3'd1,
		6'd0,
		4'd0,
		ir[31],
		ir[31] ? ir[30:17] : {9'd0,ir.alu.Rs2},
		ir.alu.Rd,
		ir.alu.Rd,
		ir.any.opcode
	};
end
endtask

task tAddCarryInOut;
input [3:0] cnt;
begin
	count = cnt;
	// ADD R47,Rs1,carry_reg
	uop[0] = {
		1'b1,
		1'b0,
		count[2:0],
		3'd0,
		carry_reg[6:5],
		2'd0,
		2'b01,
		4'd0,
		10'd0,
		carry_reg[4:0],
		1'b0,
		ir.alu.Rs1,
		5'd15,
		ir.any.opcode
	};
	// ADD R47,R47,Rs2 or immediate
	uop[1] = {
		1'b1,
		1'b0,
		3'd0,
		3'd1,
		2'd0,
		2'b01,
		2'b01,
		4'd0,
		ir[31],
		ir[31] ? ir[30:17] : {9'd0,ir.alu.Rs2},
		5'd15,
		5'd15,
		ir.any.opcode
	};
	// ADD Rd,Rs1,carry_reg
	uop[2] = {
		1'b1,
		1'b0,
		count[2:0],
		3'd2,
		carry_reg[6:5],
		4'd0,
		4'd0,
		10'd0,
		carry_reg[4:0],
		1'b0,
		ir.alu.Rs1,
		ir.alu.Rd,
		ir.any.opcode
	};
	// AGC carry_out,Rd,Rs2 or immediate
	uop[3] = {
		1'b1,
		1'b0,
		3'd0,
		3'd3,
		4'd0,
		carry_reg[6:5],
		4'd1,				// AGC
		ir[31],
		ir[31] ? ir[30:17] : {9'd0,ir.alu.Rs2},
		ir.alu.Rd,
		carry_reg[4:0],
		ir.any.opcode
	};
	// MOVE Rd,R47
	uop[4] = {
		1'b1,
		1'b0,
		3'd0,
		3'd4,
		6'd0,
		4'd0,
		1'b1,
		10'd0,
		2'b01,
		2'b00,
		1'b0,
		5'd15,
		ir.alu.Rd,
		Stark_pkg::OP_MOV
	};
end
endtask

endmodule
