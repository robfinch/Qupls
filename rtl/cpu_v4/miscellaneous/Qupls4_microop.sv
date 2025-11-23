// ============================================================================
//        __
//   \\__/ o\    (C) 2025-2026  Robert Finch, Waterloo
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
//  800 LUTs / 0 FFs (with vectors)
//	200 LUTs / 0 FFs (no vectors)
// ============================================================================

import const_pkg::*;
import Qupls4_pkg::*;

module Qupls4_microop(clk, om, ir, num, carry_reg, carry_out, carry_in, vlen_reg, velsz, count, uop);
input clk;
input Qupls4_pkg::operating_mode_t om;
input Qupls4_pkg::instruction_t ir;
input [2:0] num;
input [7:0] carry_reg;
input carry_out;
input carry_in;
input [63:0] vlen_reg;
input [63:0] velsz;
output reg [3:0] count;
output Qupls4_pkg::micro_op_t [7:0] uop;

integer nn;
Qupls4_pkg::cmp_inst_t icmp,fcmp;
Qupls4_pkg::instruction_t nopi;
Qupls4_pkg::fpu_inst_t floadi1;
Qupls4_pkg::push_inst_t push1,push2,push3,push4,push5;
Qupls4_pkg::push_inst_t pop1,pop2,pop3,pop4,pop5;
Qupls4_pkg::alui_inst_t decsp8,decsp16,decsp24,decsp32,decsp40;
Qupls4_pkg::alui_inst_t incsp8,incsp16,incsp24,incsp32,incsp40;
Qupls4_pkg::alui_inst_t incssp32,decssp32;
Qupls4_pkg::anyinst_t enter_st_fp, exit_ld_fp;
Qupls4_pkg::anyinst_t enter_st_lr, exit_ld_lr;
Qupls4_pkg::anyinst_t fp_eq_sp, sp_eq_fp;
Qupls4_pkg::r3_inst_t instr;
Qupls4_pkg::instruction_t ins2;
Qupls4_pkg::extd_inst_t vsins;
Qupls4_pkg::vls_inst_t vls;
reg [9:0] vlen, fvlen, vlen1;
wire [6:0] mo0 = 7'd48;		// micro-op temporary

always_ff @(posedge clk)
	vlen = (vlen_reg[7:0] * (7'd1 << velsz[1:0])) >> 4'd6;
always_ff @(posedge clk)
	fvlen = (vlen_reg[15:8] * (7'd2 << velsz[9:8])) >> 4'd6;

always_comb
begin
	icmp = Qupls4_pkg::cmp_inst_t'(32'd0);
	icmp.Rs2 = 5'd0;		// compare to zero
	icmp.Rs1 = ir.alu.Rd;
	icmp.op2 = 2'd0;		// signed integer compare
	icmp.CRd = 3'd0;		// CR0
	icmp.opcode = Qupls4_pkg::OP_CMPI;
end
always_comb
begin
	fcmp = Qupls4_pkg::cmp_inst_t'(32'd0);
	fcmp.Rs2 = 5'd0;		// compare to zero
	fcmp.Rs1 = ir.fpu.Rd;
	fcmp.op2 = 2'd2;		// float compare
	fcmp.CRd = 3'd1;		// CR1
	fcmp.opcode = Qupls4_pkg::OP_FLTD;
end
always_comb
begin
	floadi1 = Qupls4_pkg::fpu_inst_t'(32'd0);
	floadi1[30:29] = 3'd1;
//	floadi1.op4 = 4'd10;
	floadi1.Rd = 5'd15;
	floadi1.Rs2 = 5'd19;
	floadi1.Rs1 = 5'd1;
	floadi1.opcode = Qupls4_pkg::OP_FLTD;
end
always_comb
begin
	nopi = {26'd0,Qupls4_pkg::OP_NOP};
end
always_comb
begin
	push1 = {3'd0,16'hFFE0,7'd0,7'd61+ir[37:35],ir[13: 7],Qupls4_pkg::OP_STORE};
	push2 = {3'd0,16'hFFC0,7'd0,7'd61+ir[37:35],ir[20:14],Qupls4_pkg::OP_STORE};
	push3 = {3'd0,16'hFFA0,7'd0,7'd61+ir[37:35],ir[27:21],Qupls4_pkg::OP_STORE};
	push4 = {3'd0,16'hFF80,7'd0,7'd61+ir[37:35],ir[34:28],Qupls4_pkg::OP_STORE};
	push5 = {3'd0,16'hFF60,7'd0,7'd61+ir[37:35],ir[47:41],Qupls4_pkg::OP_STORE};
end
always_comb
begin
	pop1 = {3'd0,16'h0000,7'd0,7'd61+ir[37:35],ir[13: 7],Qupls4_pkg::OP_LOAD};
	pop2 = {3'd0,16'h0020,7'd0,7'd61+ir[37:35],ir[20:14],Qupls4_pkg::OP_LOAD};
	pop3 = {3'd0,16'h0040,7'd0,7'd61+ir[37:35],ir[27:21],Qupls4_pkg::OP_LOAD};
	pop4 = {3'd0,16'h0060,7'd0,7'd61+ir[37:35],ir[34:28],Qupls4_pkg::OP_LOAD};
	pop5 = {3'd0,16'h0080,7'd0,7'd61+ir[37:35],ir[47:41],Qupls4_pkg::OP_LOAD};
end
always_comb
begin
	decsp8 = {2'd3,25'h1FFFFF8,7'd61,7'd61,Qupls4_pkg::OP_ADDI};
	decsp16 = {2'd3,25'h1FFFFF0,7'd61,7'd61,Qupls4_pkg::OP_ADDI};
	decsp24 = {2'd3,25'h1FFFFE8,7'd61,7'd61,Qupls4_pkg::OP_ADDI};
	decsp32 = {2'd3,25'h1FFFFE0,7'd61,7'd61,Qupls4_pkg::OP_ADDI};
	decsp40 = {2'd3,25'h1FFFFD8,7'd61,7'd61,Qupls4_pkg::OP_ADDI};
end
always_comb
begin
	incsp8 = {2'd3,25'h0000008,7'd61,7'd61,Qupls4_pkg::OP_ADDI};
	incsp16 = {2'd3,25'h0000010,7'd61,7'd61,Qupls4_pkg::OP_ADDI};
	incsp24 = {2'd3,25'h0000018,7'd61,7'd61,Qupls4_pkg::OP_ADDI};
	incsp32 = {2'd3,25'h0000020,7'd61,7'd61,Qupls4_pkg::OP_ADDI};
	incsp40 = {2'd3,25'h0000028,7'd61,7'd61,Qupls4_pkg::OP_ADDI};
end
// ENTER instructions
always_comb
begin
	enter_st_fp = {3'd0,16'hFFE0,7'd0,7'd62,7'd56,Qupls4_pkg::OP_STORE};
	enter_st_lr = {3'd0,16'hFFE8,7'd0,7'd62,7'd57,Qupls4_pkg::OP_STORE};
	fp_eq_sp = {2'd0,25'h0,7'd61,7'd56,Qupls4_pkg::OP_ORI};
	decssp32 = {2'd3,25'h1FFFFE0,7'd62,7'd62,Qupls4_pkg::OP_ADDI};
	incssp32 = {2'd3,25'h0000020,7'd62,7'd62,Qupls4_pkg::OP_ADDI};
	sp_eq_fp = {2'd0,25'h0,7'd56,7'd61,Qupls4_pkg::OP_ORI};
	exit_ld_fp = {3'd0,16'h0000,7'd0,7'd62,7'd56,Qupls4_pkg::OP_LOAD};
	exit_ld_lr = {3'd0,16'h0008,7'd0,7'd62,7'd57,Qupls4_pkg::OP_LOAD};
end

always_comb
begin
	ins2 = ir;
	vsins = ir;
	vls = ir;
	case(ir.any.opcode)
	Qupls4_pkg::OP_EXTD:
		begin
			ins2 = ir;
			vlen1 = vlen;	// use integer length
			case(ir.extd.op3)
			Qupls4_pkg::EX_VSHLV:	vsins.extdop = Qupls4_pkg::EXT_ASLC;
			Qupls4_pkg::EX_VSHRV:	vsins.extdop = Qupls4_pkg::EXT_LSRC;
			default:	;
			endcase
		end
	Qupls4_pkg::OP_R3P:
		begin
			instr = (ir & ~48'h7F) | Qupls4_pkg::OP_R3BP | velsz[1:0];
			vlen1 = vlen;
		end
	Qupls4_pkg::OP_FLTP:
		begin
			instr = (ir & ~48'h7F) | Qupls4_pkg::OP_FLTPH | velsz[9:8];
			vlen1 = fvlen;
		end
	Qupls4_pkg::OP_R3BP,Qupls4_pkg::OP_R3WP,Qupls4_pkg::OP_R3TP,Qupls4_pkg::OP_R3OP:
		begin
			instr = ir;
			vlen1 = vlen;
		end
	Qupls4_pkg::OP_FLTPH,Qupls4_pkg::OP_FLTPS,Qupls4_pkg::OP_FLTPD,Qupls4_pkg::OP_FLTPQ:
		begin
			instr = ir;
			vlen1 = fvlen;
		end
	Qupls4_pkg::OP_LDV,Qupls4_pkg::OP_STV:
		vlen1 = vlen;
	Qupls4_pkg::OP_FLDV,Qupls4_pkg::OP_FSTV:
		vlen1 = fvlen;
	Qupls4_pkg::OP_LDG,Qupls4_pkg::OP_STG:
		vlen1 = vlen;
	Qupls4_pkg::OP_FLDG,Qupls4_pkg::OP_FSTG:
		vlen1 = fvlen;
	default:
		vlen1 = 10'd0;
	endcase
end

always_comb
begin
	count = 3'd0;
	uop[0] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	uop[1] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	uop[2] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	uop[3] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	uop[4] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	uop[5] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	uop[6] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	uop[7] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	instr = ir;

	case(ir.any.opcode)
	Qupls4_pkg::OP_BRK:	begin uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,ir}; count = 3'd1; end
	Qupls4_pkg::OP_EXTD:
		begin
			if (SUPPORT_VECTOR) begin
				case(ir.extd.op3)
				EX_VSHLV,EX_VSHRV:
					case(vlen1[3:0])
					4'd1:	
						begin
							count = 4'd1;
							uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,vsins};
						end
					4'd2:	
						begin
							count = 4'd2;
							uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,mo0,vsins.ms,vsins.exdop,vsins.Rs3,vsins.Rs2,vsins.Rs1,vsins.Rd,vsins.opcode};
							uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,vsins.Rs4,vsins.ms,vsins.exdop,mo0,vsins.Rs2,vsins.Rs1+7'd1,vsins.Rd+7'd1,vsins.opcode};
						end
					4'd4:	
						begin
							count = 4'd4;
							uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,mo0,vsins.ms,vsins.exdop,vsins.Rs3,vsins.Rs2,vsins.Rs1,vsins.Rd,vsins.opcode};
							uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,mo0,vsins.ms,vsins.exdop,mo0,vsins.Rs2,vsins.Rs1+7'd1,vsins.Rd+7'd1,vsins.opcode};
							uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,mo0,vsins.ms,vsins.exdop,mo0,vsins.Rs2,vsins.Rs1+7'd2,vsins.Rd+7'd2,vsins.opcode};
							uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,vsins.Rs4,vsins.ms,vsins.exdop,mo0,vsins.Rs2,vsins.Rs1+7'd3,vsins.Rd+7'd3,vsins.opcode};
						end
					4'd8:	
						begin
							count = 4'd8;
							uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,mo0,vsins.ms,vsins.exdop,vsins.Rs3,vsins.Rs2,vsins.Rs1,vsins.Rd,vsins.opcode};
							uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,mo0,vsins.ms,vsins.exdop,mo0,vsins.Rs2,vsins.Rs1+7'd1,vsins.Rd+7'd1,vsins.opcode};
							uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,mo0,vsins.ms,vsins.exdop,mo0,vsins.Rs2,vsins.Rs1+7'd2,vsins.Rd+7'd2,vsins.opcode};
							uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,mo0,vsins.ms,vsins.exdop,mo0,vsins.Rs2,vsins.Rs1+7'd3,vsins.Rd+7'd3,vsins.opcode};
							uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,mo0,vsins.ms,vsins.exdop,mo0,vsins.Rs2,vsins.Rs1+7'd4,vsins.Rd+7'd4,vsins.opcode};
							uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,mo0,vsins.ms,vsins.exdop,mo0,vsins.Rs2,vsins.Rs1+7'd5,vsins.Rd+7'd5,vsins.opcode};
							uop[6] = {1'b1,1'b0,3'd0,3'd6,4'd0,mo0,vsins.ms,vsins.exdop,mo0,vsins.Rs2,vsins.Rs1+7'd6,vsins.Rd+7'd6,vsins.opcode};
							uop[7] = {1'b1,1'b0,3'd0,3'd7,4'd0,vsins.Rs4,vsins.ms,vsins.exdop,mo0,vsins.Rs2,vsins.Rs1+7'd7,vsins.Rd+7'd7,vsins.opcode};
						end
					default:
						count = 4'd1;
						uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,nopi};
				end
					endcase
				default:
					begin
						count = 4'd1;
						uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,ir};
					end
				endcase
			end
			else begin
				count = 4'd1;
				uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,ir};
			end
		end
	Qupls4_pkg::OP_CMPI,
	Qupls4_pkg::OP_CMPUI:
		begin
			count = 4'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,ir};
		end
	Qupls4_pkg::OP_ADDI,
	Qupls4_pkg::OP_SUBFI:
		begin
			count = 4'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,ir};
		end

	Qupls4_pkg::OP_R3P,
	Qupls4_pkg::OP_FLTP,
	Qupls4_pkg::OP_R3BP,Qupls4_pkg::OP_R3WP,Qupls4_pkg::OP_R3TP,Qupls4_pkg::OP_R3OP,
	Qupls4_pkg::OP_FLTPH,Qupls4_pkg::OP_FLTPS,Qupls4_pkg::OP_FLTPD,Qupls4_pkg::OP_FLTPQ:
		if (SUPPORT_VECTOR) begin
			case(vlen1[3:0])
			4'd1:
				begin
			count = 4'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,instr};
				end
			4'd2:
				begin
			count = 4'd2;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,instr};
			uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd1,instr.Rs2+7'd1,instr.Rs1+7'd1,instr.Rd+7'd1,instr.opcode};
				end
			4'd3:
				begin
			count = 4'd3;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,instr};
			uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd1,instr.Rs2+7'd1,instr.Rs1+7'd1,instr.Rd+7'd1,instr.opcode};
			uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd2,instr.Rs2+7'd2,instr.Rs1+7'd2,instr.Rd+7'd2,instr.opcode};
				end
			4'd4:
				begin
			count = 4'd4;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,instr};
			uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd1,instr.Rs2+7'd1,instr.Rs1+7'd1,instr.Rd+7'd1,instr.opcode};
			uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd2,instr.Rs2+7'd2,instr.Rs1+7'd2,instr.Rd+7'd2,instr.opcode};
			uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd3,instr.Rs2+7'd3,instr.Rs1+7'd3,instr.Rd+7'd3,instr.opcode};
				end
			4'd5:
				begin
			count = 4'd5;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,instr};
			uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd1,instr.Rs2+7'd1,instr.Rs1+7'd1,instr.Rd+7'd1,instr.opcode};
			uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd2,instr.Rs2+7'd2,instr.Rs1+7'd2,instr.Rd+7'd2,instr.opcode};
			uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd3,instr.Rs2+7'd3,instr.Rs1+7'd3,instr.Rd+7'd3,instr.opcode};
			uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd4,instr.Rs2+7'd4,instr.Rs1+7'd4,instr.Rd+7'd4,instr.opcode};
				end
			4'd6:
				begin
			count = 4'd6;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,instr};
			uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd1,instr.Rs2+7'd1,instr.Rs1+7'd1,instr.Rd+7'd1,instr.opcode};
			uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd2,instr.Rs2+7'd2,instr.Rs1+7'd2,instr.Rd+7'd2,instr.opcode};
			uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd3,instr.Rs2+7'd3,instr.Rs1+7'd3,instr.Rd+7'd3,instr.opcode};
			uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd4,instr.Rs2+7'd4,instr.Rs1+7'd4,instr.Rd+7'd4,instr.opcode};
			uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd5,instr.Rs2+7'd5,instr.Rs1+7'd5,instr.Rd+7'd5,instr.opcode};
				end
			4'd7:
				begin
			count = 4'd7;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,instr};
			uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd1,instr.Rs2+7'd1,instr.Rs1+7'd1,instr.Rd+7'd1,instr.opcode};
			uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd2,instr.Rs2+7'd2,instr.Rs1+7'd2,instr.Rd+7'd2,instr.opcode};
			uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd3,instr.Rs2+7'd3,instr.Rs1+7'd3,instr.Rd+7'd3,instr.opcode};
			uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd4,instr.Rs2+7'd4,instr.Rs1+7'd4,instr.Rd+7'd4,instr.opcode};
			uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd5,instr.Rs2+7'd5,instr.Rs1+7'd5,instr.Rd+7'd5,instr.opcode};
			uop[6] = {1'b1,1'b0,3'd0,3'd6,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd6,instr.Rs2+7'd6,instr.Rs1+7'd6,instr.Rd+7'd6,instr.opcode};
				end
			4'd8:
				begin
			count = 4'd8;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,instr};
			uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd1,instr.Rs2+7'd1,instr.Rs1+7'd1,instr.Rd+7'd1,instr.opcode};
			uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd2,instr.Rs2+7'd2,instr.Rs1+7'd2,instr.Rd+7'd2,instr.opcode};
			uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd3,instr.Rs2+7'd3,instr.Rs1+7'd3,instr.Rd+7'd3,instr.opcode};
			uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd4,instr.Rs2+7'd4,instr.Rs1+7'd4,instr.Rd+7'd4,instr.opcode};
			uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd5,instr.Rs2+7'd5,instr.Rs1+7'd5,instr.Rd+7'd5,instr.opcode};
			uop[6] = {1'b1,1'b0,3'd0,3'd6,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd6,instr.Rs2+7'd6,instr.Rs1+7'd6,instr.Rd+7'd6,instr.opcode};
			uop[7] = {1'b1,1'b0,3'd0,3'd7,4'd0,instr.func,instr.ms,instr.op3,instr.Rs3+7'd7,instr.Rs2+7'd7,instr.Rs1+7'd7,instr.Rd+7'd7,instr.opcode};
				end
			default:	
				begin
			count = 4'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,nopi};
				end
			endcase
		end
		// Should really exception here.
		else begin
			count = 4'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,nopi};
		end
	Qupls4_pkg::OP_LDV,Qupls4_pkg::OP_STV:
		if (SUPPORT_VECTOR) begin
			case(vlen1[3:0])
			4'd1:
				begin
			count = 4'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,vls};
				end
			4'd2:
				begin
			count = 4'd2;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,vls.sc,vls.ms,vls.disp+6'd8,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd1,vls.opcode};
				end
			4'd3:
				begin
			count = 4'd3;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,vls.sc,vls.ms,vls.disp+6'd8,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd1,vls.opcode};
			uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,vls.sc,vls.ms,vls.disp+6'd16,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd2,vls.opcode};
				end
			4'd4:
				begin
			count = 4'd4;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,vls.sc,vls.ms,vls.disp+6'd8,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd1,vls.opcode};
			uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,vls.sc,vls.ms,vls.disp+6'd16,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd2,vls.opcode};
			uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,vls.sc,vls.ms,vls.disp+6'd24,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd3,vls.opcode};
				end
			4'd5:
				begin
			count = 4'd5;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,vls.sc,vls.ms,vls.disp+6'd8,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd1,vls.opcode};
			uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,vls.sc,vls.ms,vls.disp+6'd16,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd2,vls.opcode};
			uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,vls.sc,vls.ms,vls.disp+6'd24,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd3,vls.opcode};
			uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,vls.sc,vls.ms,vls.disp+6'd32,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd4,vls.opcode};
				end
			4'd6:
				begin
			count = 4'd6;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,vls.sc,vls.ms,vls.disp+6'd8,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd1,vls.opcode};
			uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,vls.sc,vls.ms,vls.disp+6'd16,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd2,vls.opcode};
			uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,vls.sc,vls.ms,vls.disp+6'd24,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd3,vls.opcode};
			uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,vls.sc,vls.ms,vls.disp+6'd32,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd4,vls.opcode};
			uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,vls.sc,vls.ms,vls.disp+6'd40,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd5,vls.opcode};
				end
			4'd7:
				begin
			count = 4'd7;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,vls.sc,vls.ms,vls.disp+6'd8,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd1,vls.opcode};
			uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,vls.sc,vls.ms,vls.disp+6'd16,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd2,vls.opcode};
			uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,vls.sc,vls.ms,vls.disp+6'd24,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd3,vls.opcode};
			uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,vls.sc,vls.ms,vls.disp+6'd32,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd4,vls.opcode};
			uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,vls.sc,vls.ms,vls.disp+6'd40,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd5,vls.opcode};
			uop[6] = {1'b1,1'b0,3'd0,3'd6,4'd0,vls.sc,vls.ms,vls.disp+6'd48,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd6,vls.opcode};
				end
			4'd8:
				begin
			count = 4'd8;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,vls.sc,vls.ms,vls.disp+6'd8,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd1,vls.opcode};
			uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,vls.sc,vls.ms,vls.disp+6'd16,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd2,vls.opcode};
			uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,vls.sc,vls.ms,vls.disp+6'd24,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd3,vls.opcode};
			uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,vls.sc,vls.ms,vls.disp+6'd32,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd4,vls.opcode};
			uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,vls.sc,vls.ms,vls.disp+6'd40,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd5,vls.opcode};
			uop[6] = {1'b1,1'b0,3'd0,3'd6,4'd0,vls.sc,vls.ms,vls.disp+6'd48,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd6,vls.opcode};
			uop[6] = {1'b1,1'b0,3'd0,3'd7,4'd0,vls.sc,vls.ms,vls.disp+6'd56,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd7,vls.opcode};
				end
			default:	
				begin
			count = 4'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,nopi};
				end
			endcase
		end
		// Should really exception here.
		else begin
			count = 4'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,nopi};
		end

	Qupls4_pkg::OP_LDVN,Qupls4_pkg::OP_STVN:
		if (SUPPORT_VECTOR) begin
			case(vlen1[3:0])
			4'd1:
				begin
			count = 4'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,vls};
				end
			4'd2:
				begin
			count = 4'd2;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd1,vls.Rs1,vls.Rd+7'd1,vls.opcode};
				end
			4'd3:
				begin
			count = 4'd3;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd1,vls.Rs1,vls.Rd+7'd1,vls.opcode};
			uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd2,vls.Rs1,vls.Rd+7'd2,vls.opcode};
				end
			4'd4:
				begin
			count = 4'd4;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd1,vls.Rs1,vls.Rd+7'd1,vls.opcode};
			uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd2,vls.Rs1,vls.Rd+7'd2,vls.opcode};
			uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd3,vls.Rs1,vls.Rd+7'd3,vls.opcode};
				end
			4'd5:
				begin
			count = 4'd5;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd1,vls.Rs1,vls.Rd+7'd1,vls.opcode};
			uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd2,vls.Rs1,vls.Rd+7'd2,vls.opcode};
			uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd3,vls.Rs1,vls.Rd+7'd3,vls.opcode};
			uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd4,vls.Rs1,vls.Rd+7'd4,vls.opcode};
				end
			4'd6:
				begin
			count = 4'd6;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd1,vls.Rs1,vls.Rd+7'd1,vls.opcode};
			uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd2,vls.Rs1,vls.Rd+7'd2,vls.opcode};
			uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd3,vls.Rs1,vls.Rd+7'd3,vls.opcode};
			uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd4,vls.Rs1,vls.Rd+7'd4,vls.opcode};
			uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd5,vls.Rs1,vls.Rd+7'd5,vls.opcode};
				end
			4'd7:
				begin
			count = 4'd7;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd1,vls.Rs1,vls.Rd+7'd1,vls.opcode};
			uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd2,vls.Rs1,vls.Rd+7'd2,vls.opcode};
			uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd3,vls.Rs1,vls.Rd+7'd3,vls.opcode};
			uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd4,vls.Rs1,vls.Rd+7'd4,vls.opcode};
			uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd5,vls.Rs1,vls.Rd+7'd5,vls.opcode};
			uop[6] = {1'b1,1'b0,3'd0,3'd6,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd6,vls.Rs1,vls.Rd+7'd6,vls.opcode};
				end
			4'd8:
				begin
			count = 4'd8;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd1,vls.Rs1,vls.Rd+7'd1,vls.opcode};
			uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd2,vls.Rs1,vls.Rd+7'd2,vls.opcode};
			uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd3,vls.Rs1,vls.Rd+7'd3,vls.opcode};
			uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd4,vls.Rs1,vls.Rd+7'd4,vls.opcode};
			uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd5,vls.Rs1,vls.Rd+7'd5,vls.opcode};
			uop[6] = {1'b1,1'b0,3'd0,3'd6,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd6,vls.Rs1,vls.Rd+7'd6,vls.opcode};
			uop[7] = {1'b1,1'b0,3'd0,3'd7,4'd0,vls.sc,1'b0,6'd0,vls.dt,vls.Rs3,vls.Rs2+7'd7,vls.Rs1,vls.Rd+7'd7,vls.opcode};
				end
			default:	
				begin
			count = 4'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,nopi};
				end
			endcase
		end
		// Should really exception here.
		else begin
			count = 4'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,nopi};
		end
		/*
			case(ir.r3.func)
			Qupls4_pkg::FN_ADD,Qupls4_pkg::FN_SUB,Qupls4_pkg::FN_MUL,Qupls4_pkg::FN_DIV,
			Qupls4_pkg::FN_MULU,Qupls4_pkg::FN_DIVU,Qupls4_pkg::FN_MULSU,Qupls4_pkg::FN_DIVSU,
			Qupls4_pkg::FN_AND,Qupls4_pkg::FN_OR,Qupls4_pkg::FN_XOR:
				begin
			endcase
		*/
	/*
	Qupls4_pkg::OP_R3B,Qupls4_pkg::OP_R3W,Qupls4_pkg::OP_R3T,Qupls4_pkg::OP_R3O:
		begin
			case(ir.r3.func)
			Qupls4_pkg::FN_AND,Qupls4_pkg::FN_OR,Qupls4_pkg::FN_XOR:
				begin
					count = 3'd2;
					uop[0] = {1'b1,1'b0,3'd1,3'd0,5'h00,4'd0,ir};
					uop[1] = {1'b1,1'b0,3'd1,3'd0,5'h01,4'd0,ir & ~48'hFFFFFFFFE000};
				end
			endcase
		end
	*/
	Qupls4_pkg::OP_CSR,
	Qupls4_pkg::OP_ANDI,
	Qupls4_pkg::OP_ORI,
	Qupls4_pkg::OP_XORI,
	Qupls4_pkg::OP_LDB,Qupls4_pkg::OP_LDBZ,Qupls4_pkg::OP_LDW,Qupls4_pkg::OP_LDWZ,
	Qupls4_pkg::OP_LDT,Qupls4_pkg::OP_LDTZ,Qupls4_pkg::OP_LOAD,Qupls4_pkg::OP_LOADA,
	Qupls4_pkg::OP_AMO,Qupls4_pkg::OP_CMPSWAP:
		begin
			count = 4'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,ir};
		end
	Qupls4_pkg::OP_MOV:
		begin
			count = 4'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,ir};
		end	
	Qupls4_pkg::OP_B0,
	Qupls4_pkg::OP_B1:
		begin
			count = 4'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,ir};
		end
	Qupls4_pkg::OP_BCC0,
	Qupls4_pkg::OP_BCC1:
		begin
			if (ir.bccld.cnd==3'd2 || ir.bccld.cnd==3'd5) begin	// no decrement
				count = 4'd1;
				uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,ir};
			end
			else begin
				count = 4'd2;
				// Decrement loop counter
				// ADD LC,LC,-1
				uop[0] = {1'b1,1'b0,3'd2,3'd0,4'd0,1'b1,14'h3FFF,1'b0,5'd12,5'd12,Qupls4_pkg::OP_ADDI};
				uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,ir};
			end
		end
	Qupls4_pkg::OP_ENTER:
		begin
			count = 4'd5;
			uop[0] = {1'b1,1'b0,3'd5,3'd0,4'd0,enter_st_fp};
			uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,fp_eq_sp};
			uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,enter_st_lr};
			uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,decssp32};
			uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,ir};
		end
	Qupls4_pkg::OP_EXIT:
		begin
			count = 4'd5;
			uop[0] = {1'b1,1'b0,3'd5,3'd0,4'd0,sp_eq_fp};
			uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,exit_ld_fp};
			uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,exit_ld_lr};
			uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,incssp32};
			uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,2'd3,ir[45:21],7'd57,ir[13:7],Qupls4_pkg::OP_RTD};	// change LEAVE into RTD
		end
	Qupls4_pkg::OP_PUSH:
		begin
			count = {1'b0,ir[40:38]} + 2'd1;
			case(count)
			4'd2:	
				begin
					uop[0] = {1'b1,1'b0,3'd2,3'd0,4'd0,push1};
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,2'd4,25'h1FFFFF8,7'd61+ir[37:35],7'd61+ir[37:35],Qupls4_pkg::OP_ADDI};
				end
			4'd3:
				begin
					uop[0] = {1'b1,1'b0,3'd3,3'd0,4'd0,push1};
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,push2};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,2'd4,25'h1FFFFF0,7'd61+ir[37:35],7'd61+ir[37:35],Qupls4_pkg::OP_ADDI};
				end
			4'd4:
				begin
					uop[0] = {1'b1,1'b0,3'd4,3'd0,4'd0,push1};
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,push2};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,push3};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,2'd4,25'h1FFFFE8,7'd61+ir[37:35],7'd61+ir[37:35],Qupls4_pkg::OP_ADDI};
				end
			4'd5:
				begin
					uop[0] = {1'b1,1'b0,3'd5,3'd0,4'd0,push1};
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,push2};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,push3};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,push4};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,2'd4,25'h1FFFFE0,7'd61+ir[37:35],7'd61+ir[37:35],Qupls4_pkg::OP_ADDI};
				end
			4'd6:
				begin
					uop[0] = {1'b1,1'b0,3'd6,3'd0,4'd0,push1};
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,push2};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,push3};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,push4};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,push5};
					uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,2'd4,25'h1FFFFD8,7'd61+ir[37:35],7'd61+ir[37:35],Qupls4_pkg::OP_ADDI};
				end
			default:	
				begin
					count = 4'd1;
					uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,nopi};
				end
			endcase
		end
	Qupls4_pkg::OP_POP:
		begin
			count = {1'b0,ir[40:38]} + 2'd1;
			case(count)
			4'd2:	
				begin
					uop[0] = {1'b1,1'b0,3'd2,3'd0,4'd0,pop1};
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,2'd4,25'h08,7'd61+ir[37:35],7'd61+ir[37:35],Qupls4_pkg::OP_ADDI};
				end
			4'd3:
				begin
					uop[0] = {1'b1,1'b0,3'd3,3'd0,4'd0,pop1};
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,pop2};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,2'd4,25'h10,7'd61+ir[37:35],7'd61+ir[37:35],Qupls4_pkg::OP_ADDI};
				end
			4'd4:
				begin
					uop[0] = {1'b1,1'b0,3'd4,3'd0,4'd0,pop1};
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,pop2};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,pop3};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,2'd4,25'h18,7'd61+ir[37:35],7'd61+ir[37:35],Qupls4_pkg::OP_ADDI};
				end
			4'd5:
				begin
					uop[0] = {1'b1,1'b0,3'd5,3'd0,4'd0,pop1};
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,pop2};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,pop3};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,pop4};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,2'd4,25'h20,7'd61+ir[37:35],7'd61+ir[37:35],Qupls4_pkg::OP_ADDI};
				end
			4'd6:
				begin
					uop[0] = {1'b1,1'b0,3'd6,3'd0,4'd0,pop1};
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,pop2};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,pop3};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,pop4};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,pop5};
					uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,2'd4,25'h28,7'd61+ir[37:35],7'd61+ir[37:35],Qupls4_pkg::OP_ADDI};
				end
			default:	
				begin
					count = 4'd1;
					uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,nopi};
				end
			endcase
		end
	Qupls4_pkg::OP_TRAP,
	Qupls4_pkg::OP_CHK,
	Qupls4_pkg::OP_STB,Qupls4_pkg::OP_STW,
	Qupls4_pkg::OP_STT,Qupls4_pkg::OP_STORE,Qupls4_pkg::OP_STI,
	Qupls4_pkg::OP_STPTR,
	Qupls4_pkg::OP_FENCE:
		begin
			count = 4'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,ir};
		end
	Qupls4_pkg::OP_FLTH,Qupls4_pkg::OP_FLTS,Qupls4_pkg::OP_FLTD,Qupls4_pkg::OP_FLTQ:
		begin
			/*
			case(ir.fpu.op4)
			FOP4_FMUL:
				// Tranlate FMUL Rd,Fs1,Fs2 to FMA Fd,Rs1,Fs2,F0.
				begin
					uop[0] = {1'b1,1'b0,3'd2,3'd0,8'b10101010,4'd0,ir};
					uop[0].ins[31]=1'b1;
					uop[0].ins[30]=1'b0;
					uop[0].ins[29:27] = ir.fpurm.rm;
					uop[0].ins.fma.Rs3 = 5'd0;
					if (ir[16]) begin
						count = 3'd2;
						uop[0].count = 3'd2;
						uop[1] = {1'b1,1'b0,3'd0,3'd1,8'b10101001,4'd0,fcmp};
					end
					else begin
						count = 3'd1;
						uop[0].count = 3'd1;
					end	
				end
			FOP4_FADD,FOP4_FSUB:
				// Translate FADD Fd,Fs1,Fs2 into FMA Fd,Fs1,r47,Fs2
				// Translate FSUB Fd,Fs1,Fs2 into FMS Fd,Fs1,r47,Fs2
				begin
					uop[0] = {1'b1,1'b0,3'd0,3'd0,6'd0,2'd1,4'd0,floadi1};	// Load 1.0 into r47
					uop[0].xRd = 2'd1;	// r47 = 32+15
					uop[1] = {1'b1,1'b0,3'd0,3'd1,8'b10101010,4'd0,ir};
					uop[1].ins[31]=1'b1;
					uop[1].ins[30]=ir.fpu.op4==FOP4_FSUB;
					uop[1].ins[29:27] = ir.fpurm.rm;
					uop[1].ins.fma.Rs3 = ir.fpu.Rs2;
					uop[1].ins.fma.Rs2 = 5'd15;
					uop[1].xRs2 = 2'd1;
					if (ir[16]) begin
						count = 3'd3;
						uop[0].count = 3'd3;
						uop[2] = {1'b1,1'b0,3'd0,3'd2,8'b10101001,4'd0,fcmp};
					end
					else begin
						count = 3'd2;
						uop[0].count = 3'd2;
						uop[1].num = 3'd1;
					end	
				end
			default:
				uop[0] = {1'b1,1'b0,3'd1,3'd0,8'b10101010,4'd0,ir};
			endcase
			// ToDo: exceptions on Rd,Rs1,Rs2
			//uop[0].exc = fnRegExc(om, {2'b10,ir.fpu.Rs1}) | fnRegExc(om, {2'b10,ir.fpu.Rd});
			*/
		end
	Qupls4_pkg::OP_MOD,Qupls4_pkg::OP_NOP:
		begin
			count = 4'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,ir};
		end
	default:
		begin
			count = 4'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,ir};
		end
	endcase
	for (nn = 0; nn < 8; nn = nn + 1) begin
		if (nn < num)
			uop[nn].v = 1'b0;
	end	
end


endmodule
