import const_pkg::*;
import Stark_pkg::*;

module Stark_microop(ir, carry_reg, carry_out, carry_in, count, uop);
input Stark_pkg::instruction_t ir;
input [7:0] carry_reg;
input carry_out;
input carry_in;
output reg [2:0] count;
output Stark_pkg::micro_op_t [7:0] uop;

Stark_pkg::cmp_inst_t icmp,fcmp;
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
	Stark_pkg::OP_BRK:	begin uop[0] = {3'd1,ir}; count = 3'd1; end
	Stark_pkg::OP_SHIFT:
		begin
			if (ir[16]) begin
				count = 3'd2;
				uop[0] = {3'd2,ir};
				uop[1] = {3'd0,icmp};
			end
			else begin
				count = 3'd1;
				uop[0] = {3'd1,ir};
			end
		end
	Stark_pkg::OP_CMP:
		begin
			count = 3'd1;
			uop[0] = {3'd1,ir};
		end
	Stark_pkg::OP_ADD,
	Stark_pkg::OP_ADB,
	Stark_pkg::OP_SUBF:
		begin
			case({carry_out,carry_in,ir[16]})
			3'b000:
				begin
					count = 3'd1;
					uop[0] = {3'd1,ir};
				end
			3'b001:
				begin
					count = 3'd2;
					uop[0] = {3'd2,ir};
					uop[1] = {3'd0,icmp};
				end
			3'b010:
				begin
					tAddCarryIn(3'd2);
				end
			3'd011:
				begin
					tAddCarryIn(3'd3);
					if (carry_reg > 8'd32)
						uop[5] = {3'd0,icmp};
					else
						uop[2] = {3'd0,icmp};
				end
			3'b100:	
				begin
					if (ir[31]) begin
					end
					else begin
						count = 3'd2;
						uop[0] = {
							3'd4,
							1'b1,
							2'd0,
							3'd0,
							5'd1,			// XCHG
							2'b00,		// frame pointer
							carry_reg[6:5],
							5'd30,		// frame pointer
							carry_reg[4:0],
							Stark_pkg::OP_MOV
						};
						uop[1] = {
							3'd0,
							1'b0,
							2'd0,
							4'd1,		// AGC
							3'd0,
							ir.alu.Rs2,
							1'b0,
							ir.alu.Rs1,
							ir.alu.Rd,
							Stark_pkg::OP_ADD
						};
						uop[2] = {
							3'd0,
							1'b1,
							2'd0,
							3'd0,
							5'd1,			// XCHG
							2'b00,		// frame pointer
							carry_reg[6:5],
							5'd30,		// frame pointer
							carry_reg[4:0],
							Stark_pkg::OP_MOV
						};
						uop[1] = {3'd2,ir};
					end
				end
			endcase
		end
	Stark_pkg::OP_CSR,
	Stark_pkg::OP_AND,
	Stark_pkg::OP_OR,
	Stark_pkg::OP_XOR,
	Stark_pkg::OP_MOV,
	Stark_pkg::OP_LDB,Stark_pkg::OP_LDBZ,Stark_pkg::OP_LDW,Stark_pkg::OP_LDWZ,
	Stark_pkg::OP_LDT,Stark_pkg::OP_LDTZ,Stark_pkg::OP_LOAD,Stark_pkg::OP_LOADA,
	Stark_pkg::OP_AMO,Stark_pkg::OP_CMPSWAP:
		if (ir[16]) begin
			count = 3'd2;
			uop[0] = {3'd2,ir};
			uop[1] = {3'd0,icmp};
		end
		else begin
			count = 3'd1;
			uop[0] = {3'd1,ir};
		end	
	Stark_pkg::OP_B0,
	Stark_pkg::OP_B1:
		begin
			count = 3'd1;
			uop[0] = {3'd1,ir};
		end
	Stark_pkg::OP_BCC0,		
	Stark_pkg::OP_BCC1:
		begin
			if (ir.bccld.cnd==3'd2 || ir.bccld.cnd==3'd5) begin	// no decrement
				count = 3'd1;
				uop[0] = {3'd1,ir};
			end
			else begin
				count = 3'd2;
				// Decrement loop counter
				uop[1] = {3'd0,ir};
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
			uop[0] = {3'd1,ir};
		end
	Stark_pkg::OP_FLT:
		if (ir[16]) begin
			count = 3'd2;
			uop[0] = {3'd2,ir};
			uop[1] = {3'd0,fcmp};
		end
		else begin
			count = 3'd1;
			uop[0] = {3'd1,ir};
		end	
	Stark_pkg::OP_PFX,Stark_pkg::OP_MOD,Stark_pkg::OP_NOP:
		begin
			count = 3'd1;
			uop[0] = {3'd1,ir};
		end
	default:
		begin
			count = 3'd1;
			uop[0] = {3'd1,ir};
		end
	endcase	
end

task tAddCarryIn;
input [3:0] cnt;
begin
	if (carry_reg > 8'd32) begin
		count = cnt + 3'd3;
		uop[0] = {
			count[2:0],
			1'b1,
			2'd0,
			3'd0,
			5'd0,			// MOVE
			2'b00,		// frame pointer
			2'b01,		
			5'd30,		// frame pointer
			5'd15,		// R47 = FP
			Stark_pkg::OP_MOV
		};
		uop[1] = {
			3'd0,
			1'b1,
			2'd0,
			3'd0,
			5'd0,			// MOVE
			carry_reg[6:5],
			2'b00,
			carry_reg[4:0],
			5'd30,		// FP = carry_reg
			Stark_pkg::OP_MOV
		};
		// ADD Rd,Rs1,FP
		uop[2] = {
			3'd0,
			10'd0,
			5'd30,
			1'b0,
			ir.alu.Rs1,
			ir.alu.Rd,
			ir.any.opcode
		};
		// ADD Rd,Rd,Rs2 or immediate
		uop[3] = {
			3'd0,
			ir[31],
			ir[31] ? ir[30:17] : {9'd0,ir.alu.Rs2},
			ir.alu.Rd,
			ir.alu.Rd,
			ir.any.opcode
		};
		uop[4] = {
			3'd0,
			1'b1,
			2'd0,
			3'd0,
			5'd0,			// MOVE
			2'b01,		
			2'b00,		// frame pointer
			5'd15,
			5'd30,		// FP = r47
			Stark_pkg::OP_MOV
		};
	end
	else begin
		count = cnt;
		// ADD Rd,Rs1,carry_reg
		uop[0] = {
			count[2:0],
			10'd0,
			carry_reg[4:0],
			1'b0,
			ir.alu.Rs1,
			ir.alu.Rd,
			ir.any.opcode
		};
		// ADD Rd,Rd,Rs2 or immediate
		uop[1] = {
			3'd0,
			ir[31],
			ir[31] ? ir[30:17] : {9'd0,ir.alu.Rs2},
			ir.alu.Rd,
			ir.alu.Rd,
			ir.any.opcode
		};
	end
end
endtask

endmodule
