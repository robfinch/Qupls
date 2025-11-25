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
//  1100 LUTs / 12 FFs / 1 DSP (with vectors)
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
Qupls4_pkg::micro_op_t icmp,fcmp;
Qupls4_pkg::micro_op_t nopi;
Qupls4_pkg::fpu_inst_t floadi1;
Qupls4_pkg::micro_op_t push1,push2,push3,push4,push5,push6;
Qupls4_pkg::micro_op_t pop1,pop2,pop3,pop4,pop5,pop6;
Qupls4_pkg::micro_op_t decsp8,decsp16,decsp24,decsp32,decsp40,decsp48;
Qupls4_pkg::micro_op_t incsp8,incsp16,incsp24,incsp32,incsp40,incsp48;
Qupls4_pkg::micro_op_t incssp32,decssp32;
Qupls4_pkg::micro_op_t enter_st_fp, exit_ld_fp;
Qupls4_pkg::micro_op_t enter_st_lr, exit_ld_lr;
Qupls4_pkg::micro_op_t fp_eq_sp, sp_eq_fp;
Qupls4_pkg::micro_op_t instr;
Qupls4_pkg::micro_op_t vsins;
Qupls4_pkg::vls_uop_t vls;
reg is_vector;
reg is_reduction;
reg is_vs, is_masked;
reg [9:0] vlen, fvlen, xvlen, cvlen, avlen;
reg [3:0] vlen1;
wire [7:0] mo0 = 8'd40;		// micro-op temporary
wire [7:0] sp = 8'd37;
wire [7:0] fp = 8'd36;
wire [7:0] lr1 = 8'd33;
reg [7:0] vRd, vRs1, vRs2, vRs3;
Qupls4_pkg::micro_op_t uop0 = {1'b1,1'b0,3'd1,3'd0,4'd0,ir.any.payload[40:24],{2'b00,ir.r3.Rs3},{2'b00,ir.r3.Rs2},{2'b00,ir.r3.Rs1},{2'b00,ir.r3.Rd},ir.any.opcode};

always_ff @(posedge clk)
	vlen = (vlen_reg[7:0] * (7'd1 << velsz[1:0])) >> 4'd6;
always_ff @(posedge clk)
	fvlen = (vlen_reg[15:8] * (7'd2 << velsz[9:8])) >> 4'd6;
always_ff @(posedge clk)
	xvlen = (vlen_reg[23:16] * (7'd1 << velsz[17:16])) >> 4'd6;
always_ff @(posedge clk)
	cvlen = (vlen_reg[23:16] * (7'd1 << velsz[17:16])) >> 4'd6;
always_ff @(posedge clk)
	avlen = (vlen_reg[31:24] * (7'd1 << velsz[25:24])) >> 4'd6;

always_comb
begin
	icmp = Qupls4_pkg::micro_op_t'(52'd0);
	icmp.Rs2 = 8'd0;		// compare to zero
	icmp.Rs1 = ir.alu.Rd;
	icmp.opcode = Qupls4_pkg::OP_CMPI;
end
always_comb
begin
	fcmp = Qupls4_pkg::cmp_inst_t'(52'd0);
	fcmp.Rs2 = 8'd0;		// compare to zero
	fcmp.Rs1 = ir.fpu.Rd;
	fcmp.Rs4 = Qupls4_pkg::FLT_CMP;
	fcmp.opcode = Qupls4_pkg::OP_FLTD;
end
always_comb
begin
	floadi1 = Qupls4_pkg::fpu_inst_t'(52'd0);
	floadi1[30:29] = 3'd1;
//	floadi1.op4 = 4'd10;
	floadi1.Rd = 5'd15;
	floadi1.Rs2 = 5'd19;
	floadi1.Rs1 = 5'd1;
	floadi1.opcode = Qupls4_pkg::OP_FLTD;
end
always_comb
begin
	nopi = {1'b1,1'b0,3'd1,3'd0,4'd0,45'd0,Qupls4_pkg::OP_NOP};
end
always_comb
begin
	push1 = {4'd0,16'hFFE0,9'd0,sp+ir[44:43],2'b00,ir[12: 7],Qupls4_pkg::OP_STORE};
	push2 = {4'd0,16'hFFC0,9'd0,sp+ir[44:43],2'b00,ir[18:13],Qupls4_pkg::OP_STORE};
	push3 = {4'd0,16'hFFA0,9'd0,sp+ir[44:43],2'b00,ir[24:19],Qupls4_pkg::OP_STORE};
	push4 = {4'd0,16'hFF80,9'd0,sp+ir[44:43],2'b00,ir[30:25],Qupls4_pkg::OP_STORE};
	push5 = {4'd0,16'hFF60,9'd0,sp+ir[44:43],2'b00,ir[36:31],Qupls4_pkg::OP_STORE};
	push6 = {4'd0,16'hFF40,9'd0,sp+ir[44:43],2'b00,ir[42:37],Qupls4_pkg::OP_STORE};
end
always_comb
begin
	pop1 = {4'd0,16'h0000,9'd0,sp+ir[44:43],2'b00,ir[12: 7],Qupls4_pkg::OP_LOAD};
	pop2 = {4'd0,16'h0020,9'd0,sp+ir[44:43],2'b00,ir[18:13],Qupls4_pkg::OP_LOAD};
	pop3 = {4'd0,16'h0040,9'd0,sp+ir[44:43],2'b00,ir[24:19],Qupls4_pkg::OP_LOAD};
	pop4 = {4'd0,16'h0060,9'd0,sp+ir[44:43],2'b00,ir[30:25],Qupls4_pkg::OP_LOAD};
	pop5 = {4'd0,16'h0080,9'd0,sp+ir[44:43],2'b00,ir[36:31],Qupls4_pkg::OP_LOAD};
	pop6 = {4'd0,16'h00A0,9'd0,sp+ir[44:43],2'b00,ir[42:37],Qupls4_pkg::OP_LOAD};
end
always_comb
begin
	decsp8 = {2'd3,25'h1FFFFF8,2'd0,sp,sp,Qupls4_pkg::OP_ADDI};
	decsp16 = {2'd3,25'h1FFFFF0,2'd0,sp,sp,Qupls4_pkg::OP_ADDI};
	decsp24 = {2'd3,25'h1FFFFE8,2'd0,sp,sp,Qupls4_pkg::OP_ADDI};
	decsp32 = {2'd3,25'h1FFFFE0,2'd0,sp,sp,Qupls4_pkg::OP_ADDI};
	decsp40 = {2'd3,25'h1FFFFD8,2'd0,sp,sp,Qupls4_pkg::OP_ADDI};
	decsp48 = {2'd3,25'h1FFFFD0,2'd0,sp,sp,Qupls4_pkg::OP_ADDI};
end
always_comb
begin
	incsp8 = {2'd3,25'h0000008,2'd0,sp,sp,Qupls4_pkg::OP_ADDI};
	incsp16 = {2'd3,25'h0000010,2'd0,sp,sp,Qupls4_pkg::OP_ADDI};
	incsp24 = {2'd3,25'h0000018,2'd0,sp,sp,Qupls4_pkg::OP_ADDI};
	incsp32 = {2'd3,25'h0000020,2'd0,sp,sp,Qupls4_pkg::OP_ADDI};
	incsp40 = {2'd3,25'h0000028,2'd0,sp,sp,Qupls4_pkg::OP_ADDI};
	incsp48 = {2'd3,25'h0000030,2'd0,sp,sp,Qupls4_pkg::OP_ADDI};
end
// ENTER instructions
always_comb
begin
	enter_st_fp = {4'd0,16'hFFE0,9'd0,sp,fp,Qupls4_pkg::OP_STORE};
	enter_st_lr = {4'd0,16'hFFE8,9'd0,sp,lr1,Qupls4_pkg::OP_STORE};
	fp_eq_sp = {2'd0,25'h0,sp,fp,Qupls4_pkg::OP_ORI};
	decssp32 = {2'd3,25'h1FFFFE0,sp,sp,Qupls4_pkg::OP_ADDI};
	incssp32 = {2'd3,25'h0000020,sp,sp,Qupls4_pkg::OP_ADDI};
	sp_eq_fp = {2'd0,25'h0,fp,sp,Qupls4_pkg::OP_ORI};
	exit_ld_fp = {4'd0,16'h0000,9'd0,sp,fp,Qupls4_pkg::OP_LOAD};
	exit_ld_lr = {4'd0,16'h0008,9'd0,sp,lr1,Qupls4_pkg::OP_LOAD};
end

always_comb
begin
	case (ir.any.opcode)
	Qupls4_pkg::OP_R3VS,Qupls4_pkg::OP_FLTVS:
		is_vs = ir.r3.op3==3'd1;
	default:	is_vs = 1'b0;
	endcase
end

always_comb
begin
	case (ir.any.opcode)
	Qupls4_pkg::OP_R3P,Qupls4_pkg::OP_R3VS,Qupls4_pkg::OP_FLTVS:
		is_masked = ir.r3.op3==3'd6;
	default:	is_masked = 1'b0;
	endcase
end

always_comb
begin
	case (ir.any.opcode)
	Qupls4_pkg::OP_R3P,Qupls4_pkg::OP_R3VS:
		case(ir.r3.func)
		Qupls4_pkg::FN_REDSUM,Qupls4_pkg::FN_REDAND,Qupls4_pkg::FN_REDOR,Qupls4_pkg::FN_REDEOR,
		Qupls4_pkg::FN_REDMIN,Qupls4_pkg::FN_REDMAX,Qupls4_pkg::FN_REDMINU,Qupls4_pkg::FN_REDMAXU:
			is_reduction = 1'b1;
		default:	is_reduction = 1'b0;
		endcase
	default:	is_reduction = 1'b0;
	endcase
end

always_comb
begin
	case (ir.any.opcode)
	Qupls4_pkg::OP_R3P,Qupls4_pkg::OP_FLTP:
		is_vector = 1'b1;
	default:	is_vector = 1'b0;
	endcase
end

always_comb
begin
	instr = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	vsins = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	vls = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	vsins.opcode = ir.any.opcode;
	vsins.Rd = ir.r3.Rd;
	vsins.Rs1 = ir.r3.Rs1;
	vsins.Rs2 = ir.r3.Rs2;
	vsins.Rs3 = ir.r3.Rs3;
	vsins.vn = ir.r3.vn;
	vsins.op3 = ir.r3.op3;
	vsins.ms = ir.r3.ms;
	vsins.Rs4 = ir.r3.func;
	vls.opcode = ir.any.opcode;
	vls.Rd = ir.r3.Rd;
	vls.Rs1 = ir.r3.Rs1;
	vls.Rs2 = ir.r3.Rs2;
	vls.Rs3 = ir.r3.Rs3;
	vls.dt = ir[37:35];
	vls.disp = ir[43:38];
	vls.ms = ir[44];
	vls.sc = ir[47:45];
	instr.opcode = ir.any.opcode;
	instr.Rd = ir.r3.Rd;
	instr.Rs1 = ir.r3.Rs1;
	instr.Rs2 = ir.r3.Rs2;
	instr.Rs3 = ir.r3.Rs3;
	instr.vn = ir.r3.vn;
	instr.op3 = ir.r3.op3;
	instr.ms = ir.r3.ms;
	instr.Rs4 = ir.r3.func;
	case(ir.any.opcode)
	Qupls4_pkg::OP_EXTD:
		begin
			vlen1 = vlen;	// use integer length
			case(ir.extd.op3)
			Qupls4_pkg::EX_VSHLV:	vsins.op3 = Qupls4_pkg::EX_ASLC;
			Qupls4_pkg::EX_VSHRV:	vsins.op3 = Qupls4_pkg::EX_LSRC;
			default:	;
			endcase
		end
	Qupls4_pkg::OP_R3P:
		begin
			instr.opcode = Qupls4_pkg::OP_R3BP | velsz[1:0];
			instr.Rd = ir.r3.Rd;
			instr.Rs1 = ir.r3.Rs1;
			instr.Rs2 = ir.r3.Rs2;
			instr.Rs3 = ir.r3.Rs3;
			instr.vn = ir.r3.vn;
			instr.op3 = ir.r3.op3;
			instr.Rs4 = ir.r3.func;
			vlen1 = vlen;
		end
	Qupls4_pkg::OP_FLTP:
		begin
			instr.opcode = Qupls4_pkg::OP_FLTPH | velsz[9:8];
			instr.Rd = ir.r3.Rd;
			instr.Rs1 = ir.r3.Rs1;
			instr.Rs2 = ir.r3.Rs2;
			instr.Rs3 = ir.r3.Rs3;
			instr.vn = ir.r3.vn;
			instr.op3 = ir.r3.op3;
			instr.Rs4 = ir.r3.func;
			vlen1 = fvlen;
		end
	Qupls4_pkg::OP_R3BP,Qupls4_pkg::OP_R3WP,Qupls4_pkg::OP_R3TP,Qupls4_pkg::OP_R3OP:
		begin
			instr.opcode = ir.any.opcode;
			instr.Rd = ir.r3.Rd;
			instr.Rs1 = ir.r3.Rs1;
			instr.Rs2 = ir.r3.Rs2;
			instr.Rs3 = ir.r3.Rs3;
			instr.vn = ir.r3.vn;
			instr.op3 = ir.r3.op3;
			instr.Rs4 = ir.r3.func;
			vlen1 = vlen;
		end
	Qupls4_pkg::OP_FLTPH,Qupls4_pkg::OP_FLTPS,Qupls4_pkg::OP_FLTPD,Qupls4_pkg::OP_FLTPQ:
		begin
			instr.opcode = ir.any.opcode;
			instr.Rd = ir.r3.Rd;
			instr.Rs1 = ir.r3.Rs1;
			instr.Rs2 = ir.r3.Rs2;
			instr.Rs3 = ir.r3.Rs3;
			instr.vn = ir.r3.vn;
			instr.op3 = ir.r3.op3;
			instr.Rs4 = ir.r3.func;
			vlen1 = fvlen;
		end
	Qupls4_pkg::OP_LDV,Qupls4_pkg::OP_STV,
	Qupls4_pkg::OP_LDVN,Qupls4_pkg::OP_STVN:
		case(vls.dt)
		3'd0:	vlen1 = vlen;
		3'd1:	vlen1 = fvlen;
		3'd2:	vlen1 = xvlen;
		3'd3:	vlen1 = cvlen;
		3'd4:	vlen1 = avlen;
		default:	vlen1 = vlen;
		endcase
	default:
		vlen1 = 10'd0;
	endcase
end

always_comb vRd = (instr.vn[0] & is_vector) ? ({1'b0,instr.Rd,2'b00} << vlen1[3]) + 8'd128 : {2'b0,instr.Rd};
always_comb vRs1 = (instr.vn[1] & is_vector) ? ({1'b0,instr.Rs1,2'b00} << vlen1[3]) + 8'd128 : {2'b0,instr.Rs1};
always_comb vRs2 = (instr.vn[2] & is_vector) ? ({1'b0,instr.Rs2,2'b00} << vlen1[3]) + 8'd128 : {2'b0,instr.Rs2};
always_comb vRs3 = (instr.vn[3] & is_vector) ? ({1'b0,instr.Rs3,2'b00} << vlen1[3]) + 8'd128 : {2'b0,instr.Rs3};

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
							uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,mo0,vsins.ms,vsins.op3,{2'b00,vsins.Rs3},{2'b00,vsins.Rs2},vRs1,vRd,vsins.opcode};
						end
					4'd2:	
						begin
							count = 4'd2;
							uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,mo0,vsins.ms,vsins.op3,{2'b00,vsins.Rs3},{2'b00,vsins.Rs2},vRs1,vRd,vsins.opcode};
							uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,{2'b0,vsins.Rs4},vsins.ms,vsins.op3,mo0,{2'b00,vsins.Rs2},vRs1+7'd1,vRd+7'd1,vsins.opcode};
						end
					4'd4:	
						begin
							count = 4'd4;
							uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,mo0,vsins.ms,vsins.op3,{2'b00,vsins.Rs3},{2'b00,vsins.Rs2},vRs1,vRd,vsins.opcode};
							uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,mo0,vsins.ms,vsins.op3,mo0,{2'b00,vsins.Rs2},vRs1+7'd1,vRd+7'd1,vsins.opcode};
							uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,mo0,vsins.ms,vsins.op3,mo0,{2'b00,vsins.Rs2},vRs1+7'd2,vRd+7'd2,vsins.opcode};
							uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,{2'b00,vsins.Rs4},vsins.ms,vsins.op3,mo0,{2'b00,vsins.Rs2},vRs1+7'd2,vRd+7'd2,vsins.opcode};
						end
					4'd8:	
						begin
							count = 4'd8;
							uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,mo0,vsins.ms,vsins.op3,{2'b00,vsins.Rs3},{2'b00,vsins.Rs2},vRs1,vRd,vsins.opcode};
							uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,mo0,vsins.ms,vsins.op3,mo0,{2'b00,vsins.Rs2},vRs1+7'd1,vRd+7'd1,vsins.opcode};
							uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,mo0,vsins.ms,vsins.op3,mo0,{2'b00,vsins.Rs2},vRs1+7'd2,vRd+7'd2,vsins.opcode};
							uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,mo0,vsins.ms,vsins.op3,mo0,{2'b00,vsins.Rs2},vRs1+7'd3,vRd+7'd3,vsins.opcode};
							uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,mo0,vsins.ms,vsins.op3,mo0,{2'b00,vsins.Rs2},vRs1+7'd4,vRd+7'd4,vsins.opcode};
							uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,mo0,vsins.ms,vsins.op3,mo0,{2'b00,vsins.Rs2},vRs1+7'd5,vRd+7'd5,vsins.opcode};
							uop[6] = {1'b1,1'b0,3'd0,3'd6,4'd0,mo0,vsins.ms,vsins.op3,mo0,{2'b00,vsins.Rs2},vRs1+7'd6,vRd+7'd6,vsins.opcode};
							uop[7] = {1'b1,1'b0,3'd0,3'd7,4'd0,{2'b00,vsins.Rs4},vsins.ms,vsins.op3,mo0,{2'b00,vsins.Rs2},vRs1+7'd7,vRd+7'd7,vsins.opcode};
						end
					default:
						begin
							count = 4'd1;
							uop[0] = nopi;
						end
					endcase
				default:
					begin
						count = 4'd1;
						uop[0] = uop0;
					end
				endcase
			end
			else begin
				count = 4'd1;
				uop[0] = uop0;
			end
		end
	Qupls4_pkg::OP_CMPI,
	Qupls4_pkg::OP_CMPUI:
		begin
			count = 4'd1;
			uop[0] = uop0;
		end
	Qupls4_pkg::OP_ADDI,
	Qupls4_pkg::OP_SUBFI:
		begin
			count = 4'd1;
			uop[0] = uop0;
		end

	Qupls4_pkg::OP_R3P,Qupls4_pkg::OP_R3VS,
	Qupls4_pkg::OP_FLTP,Qupls4_pkg::OP_FLTVS,
	Qupls4_pkg::OP_R3BP,Qupls4_pkg::OP_R3WP,Qupls4_pkg::OP_R3TP,Qupls4_pkg::OP_R3OP,
	Qupls4_pkg::OP_FLTPH,Qupls4_pkg::OP_FLTPS,Qupls4_pkg::OP_FLTPD,Qupls4_pkg::OP_FLTPQ:
		if (SUPPORT_VECTOR) begin
			case(vlen1[3:0])
			4'd1:
				begin
			count = 4'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1,vRd,instr.opcode};
			     end
			4'd2:
				begin
			count = 4'd2;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1,vRd,instr.opcode};
			casez({is_reduction,is_vs,is_masked})
			3'b000:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+8'd1,vRs2+8'd1,vRs1+8'd1,vRd+8'd1,instr.opcode};
				end
			3'b001:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd1,vRs1+7'd1,vRd+7'd1,instr.opcode};
				end
			3'b010:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd1,vRs2,vRs1+7'd1,vRd+7'd1,instr.opcode};
				end
			3'b011:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd1,vRd+7'd1,instr.opcode};
				end
			3'b1??:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd1,vRd,instr.opcode};
				end
			endcase
				end
			4'd3:
				begin
			count = 4'd3;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1,vRd,instr.opcode};
			casez({is_reduction,is_vs,is_masked})
			3'b000:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd1,vRs2+7'd1,vRs1+7'd1,vRd+7'd1,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd2,vRs2+7'd2,vRs1+7'd2,vRd+7'd2,instr.opcode};
				end
			3'b001:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd1,vRs1+7'd1,vRd+7'd1,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd2,vRs1+7'd2,vRd+7'd2,instr.opcode};
				end
			3'b010:
					begin
						uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd1,vRs2,vRs1+7'd1,vRd+7'd1,instr.opcode};
						uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd2,vRs2,vRs1+7'd2,vRd+7'd2,instr.opcode};
					end
			3'b011:
					begin
						uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd1,vRd+7'd1,instr.opcode};
						uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd2,vRd+7'd2,instr.opcode};
					end
			3'b1??:
					begin
						uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd1,vRd,instr.opcode};
						uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd2,vRd,instr.opcode};
					end
			endcase
				end
			4'd4:
				begin
			count = 4'd4;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1,vRd,instr.opcode};
			casez({is_reduction,is_vs,is_masked})
			3'b000:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd1,vRs2+7'd1,vRs1+7'd1,vRd+7'd1,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd2,vRs2+7'd2,vRs1+7'd2,vRd+7'd2,instr.opcode};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd3,vRs2+7'd3,vRs1+7'd3,vRd+7'd3,instr.opcode};
				end
			3'b001:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd1,vRs1+7'd1,vRd+7'd1,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd2,vRs1+7'd2,vRd+7'd2,instr.opcode};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd3,vRs1+7'd3,vRd+7'd3,instr.opcode};
				end
			3'b010:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd1,vRs2,vRs1+7'd1,vRd+7'd1,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd2,vRs2,vRs1+7'd2,vRd+7'd2,instr.opcode};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd3,vRs2,vRs1+7'd3,vRd+7'd3,instr.opcode};
				end
			3'b011:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd1,vRd+7'd1,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd2,vRd+7'd2,instr.opcode};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd3,vRd+7'd3,instr.opcode};
				end
			3'b1??:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd1,vRd,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd2,vRd,instr.opcode};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd3,vRd,instr.opcode};
				end
			endcase
				end
			4'd5:
				begin
			count = 4'd5;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1,vRd,instr.opcode};
			casez({is_reduction,is_vs,is_masked})
			3'b000:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd1,vRs2+7'd1,vRs1+7'd1,vRd+7'd1,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd2,vRs2+7'd2,vRs1+7'd2,vRd+7'd2,instr.opcode};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd3,vRs2+7'd3,vRs1+7'd3,vRd+7'd3,instr.opcode};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd4,vRs2+7'd4,vRs1+7'd4,vRd+7'd4,instr.opcode};
				end
			3'b001:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd1,vRs1+7'd1,vRd+7'd1,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd2,vRs1+7'd2,vRd+7'd2,instr.opcode};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd3,vRs1+7'd3,vRd+7'd3,instr.opcode};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd4,vRs1+7'd4,vRd+7'd4,instr.opcode};
				end
			3'b010:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd1,vRs2,vRs1+7'd1,vRd+7'd1,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd2,vRs2,vRs1+7'd2,vRd+7'd2,instr.opcode};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd3,vRs2,vRs1+7'd3,vRd+7'd3,instr.opcode};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd4,vRs2,vRs1+7'd4,vRd+7'd4,instr.opcode};
				end
			3'b011:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd1,vRd+7'd1,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd2,vRd+7'd2,instr.opcode};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd3,vRd+7'd3,instr.opcode};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd4,vRd+7'd4,instr.opcode};
				end
			3'b1??:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd1,vRd,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd2,vRd,instr.opcode};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd3,vRd,instr.opcode};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd4,vRd,instr.opcode};
				end
			endcase
				end
			4'd6:
				begin
			count = 4'd6;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1,vRd,instr.opcode};
			casez({is_reduction,is_vs,is_masked})
			3'b000:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd1,vRs2+7'd1,vRs1+7'd1,vRd+7'd1,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd2,vRs2+7'd2,vRs1+7'd2,vRd+7'd2,instr.opcode};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd3,vRs2+7'd3,vRs1+7'd3,vRd+7'd3,instr.opcode};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd4,vRs2+7'd4,vRs1+7'd4,vRd+7'd4,instr.opcode};
					uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd5,vRs2+7'd5,vRs1+7'd5,vRd+7'd5,instr.opcode};
				end
			3'b001:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd1,vRs1+7'd1,vRd+7'd1,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd2,vRs1+7'd2,vRd+7'd2,instr.opcode};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd3,vRs1+7'd3,vRd+7'd3,instr.opcode};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd4,vRs1+7'd4,vRd+7'd4,instr.opcode};
					uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd5,vRs1+7'd5,vRd+7'd5,instr.opcode};
				end
			3'b010:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd1,vRs2,vRs1+7'd1,vRd+7'd1,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd2,vRs2,vRs1+7'd2,vRd+7'd2,instr.opcode};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd3,vRs2,vRs1+7'd3,vRd+7'd3,instr.opcode};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd4,vRs2,vRs1+7'd4,vRd+7'd4,instr.opcode};
					uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd5,vRs2,vRs1+7'd5,vRd+7'd5,instr.opcode};
				end
			3'b011:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd1,vRd+7'd1,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd2,vRd+7'd2,instr.opcode};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd3,vRd+7'd3,instr.opcode};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd4,vRd+7'd4,instr.opcode};
					uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd5,vRd+7'd5,instr.opcode};
				end
			3'b1??:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd1,vRd,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd2,vRd,instr.opcode};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd3,vRd,instr.opcode};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd4,vRd,instr.opcode};
					uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd5,vRd,instr.opcode};
				end
			endcase
				end
			4'd7:
				begin
			count = 4'd7;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1,vRd,instr.opcode};
			casez({is_reduction,is_vs,is_masked})
			3'b000:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd1,vRs2+7'd1,vRs1+7'd1,vRd+7'd1,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd2,vRs2+7'd2,vRs1+7'd2,vRd+7'd2,instr.opcode};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd3,vRs2+7'd3,vRs1+7'd3,vRd+7'd3,instr.opcode};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd4,vRs2+7'd4,vRs1+7'd4,vRd+7'd4,instr.opcode};
					uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd5,vRs2+7'd5,vRs1+7'd5,vRd+7'd5,instr.opcode};
					uop[6] = {1'b1,1'b0,3'd0,3'd6,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd6,vRs2+7'd6,vRs1+7'd6,vRd+7'd6,instr.opcode};
				end
			3'b001:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd1,vRs1+7'd1,vRd+7'd1,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd2,vRs1+7'd2,vRd+7'd2,instr.opcode};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd3,vRs1+7'd3,vRd+7'd3,instr.opcode};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd4,vRs1+7'd4,vRd+7'd4,instr.opcode};
					uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd5,vRs1+7'd5,vRd+7'd5,instr.opcode};
					uop[6] = {1'b1,1'b0,3'd0,3'd6,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd6,vRs1+7'd6,vRd+7'd6,instr.opcode};
				end
			3'b010:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd1,vRs2,vRs1+7'd1,vRd+7'd1,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd2,vRs2,vRs1+7'd2,vRd+7'd2,instr.opcode};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd3,vRs2,vRs1+7'd3,vRd+7'd3,instr.opcode};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd4,vRs2,vRs1+7'd4,vRd+7'd4,instr.opcode};
					uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd5,vRs2,vRs1+7'd5,vRd+7'd5,instr.opcode};
					uop[6] = {1'b1,1'b0,3'd0,3'd6,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd6,vRs2,vRs1+7'd6,vRd+7'd6,instr.opcode};
				end
			3'b011:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd1,vRd+7'd1,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd2,vRd+7'd2,instr.opcode};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd3,vRd+7'd3,instr.opcode};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd4,vRd+7'd4,instr.opcode};
					uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd5,vRd+7'd5,instr.opcode};
					uop[6] = {1'b1,1'b0,3'd0,3'd6,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd6,vRd+7'd6,instr.opcode};
				end
			3'b1??:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd1,vRd,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd2,vRd,instr.opcode};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd3,vRd,instr.opcode};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd4,vRd,instr.opcode};
					uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd5,vRd,instr.opcode};
					uop[6] = {1'b1,1'b0,3'd0,3'd6,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd6,vRd,instr.opcode};
				end
			endcase
				end
			4'd8:
				begin
			count = 4'd8;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1,vRd,instr.opcode};
			casez({is_reduction,is_vs,is_masked})
			3'b000:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd1,vRs2+7'd1,vRs1+7'd1,vRd+7'd1,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd2,vRs2+7'd2,vRs1+7'd2,vRd+7'd2,instr.opcode};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd3,vRs2+7'd3,vRs1+7'd3,vRd+7'd3,instr.opcode};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd4,vRs2+7'd4,vRs1+7'd4,vRd+7'd4,instr.opcode};
					uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd5,vRs2+7'd5,vRs1+7'd5,vRd+7'd5,instr.opcode};
					uop[6] = {1'b1,1'b0,3'd0,3'd6,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd6,vRs2+7'd6,vRs1+7'd6,vRd+7'd6,instr.opcode};
					uop[7] = {1'b1,1'b0,3'd0,3'd7,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd7,vRs2+7'd7,vRs1+7'd7,vRd+7'd7,instr.opcode};
				end
			3'b001:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd1,vRs1+7'd1,vRd+7'd1,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd2,vRs1+7'd2,vRd+7'd2,instr.opcode};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd3,vRs1+7'd3,vRd+7'd3,instr.opcode};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd4,vRs1+7'd4,vRd+7'd4,instr.opcode};
					uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd5,vRs1+7'd5,vRd+7'd5,instr.opcode};
					uop[6] = {1'b1,1'b0,3'd0,3'd6,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd6,vRs1+7'd6,vRd+7'd6,instr.opcode};
					uop[7] = {1'b1,1'b0,3'd0,3'd7,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2+7'd7,vRs1+7'd7,vRd+7'd7,instr.opcode};
				end
			3'b010:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd1,vRs2,vRs1+7'd1,vRd+7'd1,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd2,vRs2,vRs1+7'd2,vRd+7'd2,instr.opcode};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd3,vRs2,vRs1+7'd3,vRd+7'd3,instr.opcode};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd4,vRs2,vRs1+7'd4,vRd+7'd4,instr.opcode};
					uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd5,vRs2,vRs1+7'd5,vRd+7'd5,instr.opcode};
					uop[6] = {1'b1,1'b0,3'd0,3'd6,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd6,vRs2,vRs1+7'd6,vRd+7'd6,instr.opcode};
					uop[7] = {1'b1,1'b0,3'd0,3'd7,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3+7'd7,vRs2,vRs1+7'd7,vRd+7'd7,instr.opcode};
				end
			3'b011:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd1,vRd+7'd1,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd2,vRd+7'd2,instr.opcode};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd3,vRd+7'd3,instr.opcode};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd4,vRd+7'd4,instr.opcode};
					uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd5,vRd+7'd5,instr.opcode};
					uop[6] = {1'b1,1'b0,3'd0,3'd6,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd6,vRd+7'd6,instr.opcode};
					uop[7] = {1'b1,1'b0,3'd0,3'd7,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRs2,vRs1+7'd7,vRd+7'd7,instr.opcode};
				end
			3'b1??:
				begin
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd1,vRd,instr.opcode};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd2,vRd,instr.opcode};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd3,vRd,instr.opcode};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd4,vRd,instr.opcode};
					uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd5,vRd,instr.opcode};
					uop[6] = {1'b1,1'b0,3'd0,3'd6,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd6,vRd,instr.opcode};
					uop[7] = {1'b1,1'b0,3'd0,3'd7,4'd0,instr.Rs4,instr.ms,instr.op3,vRs3,vRd,vRs1+7'd7,vRd,instr.opcode};
				end
			endcase
				end
			default:	
				begin
			count = 4'd1;
			uop[0] = nopi;
				end
			endcase
		end
		// Should really exception here.
		else begin
			count = 4'd1;
			uop[0] = nopi;
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
			uop[7] = {1'b1,1'b0,3'd0,3'd7,4'd0,vls.sc,vls.ms,vls.disp+6'd56,vls.dt,vls.Rs3,vls.Rs2,vls.Rs1,vls.Rd+7'd7,vls.opcode};
				end
			default:	
				begin
			count = 4'd1;
			uop[0] = nopi;
				end
			endcase
		end
		// Should really exception here.
		else begin
			count = 4'd1;
			uop[0] = nopi;
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
			uop[0] = nopi;
				end
			endcase
		end
		// Should really exception here.
		else begin
			count = 4'd1;
			uop[0] = nopi;
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
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,2'd3,25'h1FFFFF8,7'd61+ir[37:35],7'd61+ir[37:35],Qupls4_pkg::OP_ADDI};
				end
			4'd3:
				begin
					uop[0] = {1'b1,1'b0,3'd3,3'd0,4'd0,push1};
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,push2};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,2'd3,25'h1FFFFF0,7'd61+ir[37:35],7'd61+ir[37:35],Qupls4_pkg::OP_ADDI};
				end
			4'd4:
				begin
					uop[0] = {1'b1,1'b0,3'd4,3'd0,4'd0,push1};
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,push2};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,push3};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,2'd3,25'h1FFFFE8,7'd61+ir[37:35],7'd61+ir[37:35],Qupls4_pkg::OP_ADDI};
				end
			4'd5:
				begin
					uop[0] = {1'b1,1'b0,3'd5,3'd0,4'd0,push1};
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,push2};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,push3};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,push4};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,2'd3,25'h1FFFFE0,7'd61+ir[37:35],7'd61+ir[37:35],Qupls4_pkg::OP_ADDI};
				end
			4'd6:
				begin
					uop[0] = {1'b1,1'b0,3'd6,3'd0,4'd0,push1};
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,push2};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,push3};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,push4};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,push5};
					uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,2'd3,25'h1FFFFD8,7'd61+ir[37:35],7'd61+ir[37:35],Qupls4_pkg::OP_ADDI};
				end
			default:	
				begin
					count = 4'd1;
					uop[0] = nopi;
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
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,2'd3,25'h08,7'd61+ir[37:35],7'd61+ir[37:35],Qupls4_pkg::OP_ADDI};
				end
			4'd3:
				begin
					uop[0] = {1'b1,1'b0,3'd3,3'd0,4'd0,pop1};
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,pop2};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,2'd3,25'h10,7'd61+ir[37:35],7'd61+ir[37:35],Qupls4_pkg::OP_ADDI};
				end
			4'd4:
				begin
					uop[0] = {1'b1,1'b0,3'd4,3'd0,4'd0,pop1};
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,pop2};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,pop3};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,2'd3,25'h18,7'd61+ir[37:35],7'd61+ir[37:35],Qupls4_pkg::OP_ADDI};
				end
			4'd5:
				begin
					uop[0] = {1'b1,1'b0,3'd5,3'd0,4'd0,pop1};
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,pop2};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,pop3};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,pop4};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,2'd3,25'h20,7'd61+ir[37:35],7'd61+ir[37:35],Qupls4_pkg::OP_ADDI};
				end
			4'd6:
				begin
					uop[0] = {1'b1,1'b0,3'd6,3'd0,4'd0,pop1};
					uop[1] = {1'b1,1'b0,3'd0,3'd1,4'd0,pop2};
					uop[2] = {1'b1,1'b0,3'd0,3'd2,4'd0,pop3};
					uop[3] = {1'b1,1'b0,3'd0,3'd3,4'd0,pop4};
					uop[4] = {1'b1,1'b0,3'd0,3'd4,4'd0,pop5};
					uop[5] = {1'b1,1'b0,3'd0,3'd5,4'd0,2'd3,25'h28,7'd61+ir[37:35],7'd61+ir[37:35],Qupls4_pkg::OP_ADDI};
				end
			default:	
				begin
					count = 4'd1;
					uop[0] = nopi;
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
			uop[0] = uop0;
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
			uop[0] = uop0;
		end
	default:
		begin
			count = 4'd1;
			uop[0] = uop0;
		end
	endcase
	for (nn = 0; nn < 8; nn = nn + 1) begin
		if (nn < num)
			uop[nn].v = 1'b0;
	end	
end


endmodule
