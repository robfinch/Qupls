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
//  1170 LUTs / 12 FFs / 1 DSP (with 512-bit vectors)
//  790 LUTs / 12 FFs / 1 DSP (with 256-bit vectors)
//	200 LUTs / 0 FFs (no vectors)
// ============================================================================

import const_pkg::*;
import Qupls4_pkg::*;

module Qupls4_microop_mem(clk, om, ir, num, carry_reg, carry_out, carry_in,
	vlen_reg, velsz, count, uop);
input clk;
input Qupls4_pkg::operating_mode_t om;
input [47:0] ir;
input [4:0] num;
input [7:0] carry_reg;
input carry_out;
input carry_in;
input [63:0] vlen_reg;
input [63:0] velsz;
output reg [5:0] count;
output Qupls4_pkg::micro_op_t [31:0] uop;

integer nn, kk;
reg [6:0] head0;
reg [6:0] tail0, tail1, tail2, tail3;

reg insert_boi;
reg [7:0] boi_count = 8'd0;
Qupls4_pkg::micro_op_t nopi, uop_boi;
Qupls4_pkg::fpu_inst_t floadi1;
reg [55:0] push1,push2,push3,push4,push5,push6,push7;
reg [55:0] pop1,pop2,pop3,pop4,pop5,pop6,pop7;
reg [55:0] decsp8,decsp16,decsp24,decsp32,decsp40,decsp48,decsp56;
reg [55:0] incsp8,incsp16,incsp24,incsp32,incsp40,incsp48,incsp56;
reg [55:0] incssp32,decssp32;
reg [55:0] enter_st_fp, exit_ld_fp;
reg [55:0] enter_st_lr, exit_ld_lr;
reg [55:0] fp_eq_sp, sp_eq_fp;
Qupls4_pkg::micro_op_t instr;
Qupls4_pkg::micro_op_t vsins;
Qupls4_pkg::micro_op_t vls;
reg is_vector;
reg is_reduction;
reg is_vs, is_masked;
reg [9:0] vlen, fvlen, xvlen, cvlen, avlen;
reg [3:0] vlen1;
wire [7:0] mo0 = 8'd40;		// micro-op temporary
wire [7:0] sp = 8'd31;
wire [7:0] ssp = 8'd32;
wire [7:0] fp = 8'd36;
wire [7:0] lr1 = 8'd33;
wire [7:0] num_scalar_reg = 8'd35;
reg [7:0] vRd, vRs1, vRs2, vRs3;
reg vRdi, vRs1i, vRs2i, vRs3i;		// whether to increment the register spec or not.

// Copy instruction to micro-op verbatium. The register fields need to be
// expanded by two bits each.
Qupls4_pkg::micro_op_t uop0 = {1'b1,1'b0,1'd1,5'd0,4'd0,instr};
Qupls4_pkg::micro_op_t uop1 = {1'b1,1'b0,1'd0,5'd1,4'd0,instr};

always_ff @(posedge clk)
	boi_count <= boi_count + 2'd1;
always_comb
	insert_boi = SUPPORT_IRQ_POLLING ? boi_count[4] : 1'b0;

// Compute vector lengths in bits based on the selected element size and data type.
// Convert the length in bits to a number of registers by shifting right by the
// register width in bits. The values then reflect the number of registers or
// chunks of the vector to process.
// These values are essentially static, so they can be registered to improve
// timing.
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
	floadi1 = Qupls4_pkg::fpu_inst_t'($bits(Qupls4_pkg::micro_op_t));
	floadi1[30:29] = 3'd1;
//	floadi1.op4 = 4'd10;
	floadi1.Rd = 5'd15;
	floadi1.Rs2 = 5'd19;
	floadi1.Rs1 = 5'd1;
	floadi1.opcode = Qupls4_pkg::OP_FLTD;
end
always_comb
begin
	nopi = {1'b1,1'b0,1'd1,5'd0,4'd0,45'd0,Qupls4_pkg::OP_NOP};
end
always_comb
begin
	uop_boi = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	uop_boi.br.opcode = Qupls4_pkg::OP_BCCU64;
	uop_boi.br.cnd = Qupls4_pkg::CND_BOI;
	uop_boi.any.lead = 3'd1;
end
always_comb
begin
	push1 = {6'd0,19'h7FFF8,8'd0,3'b0,sp[4:0],3'b0,ir[11: 7],Qupls4_pkg::OP_STORE};
	push2 = {6'd0,19'h7FFF0,8'd0,3'b0,sp[4:0],3'b0,ir[16:12],Qupls4_pkg::OP_STORE};
	push3 = {6'd0,19'h7FFE8,8'd0,3'b0,sp[4:0],3'b0,ir[21:17],Qupls4_pkg::OP_STORE};
	push4 = {6'd0,19'h7FFE0,8'd0,3'b0,sp[4:0],3'b0,ir[26:22],Qupls4_pkg::OP_STORE};
	push5 = {6'd0,19'h7FFD8,8'd0,3'b0,sp[4:0],3'b0,ir[31:27],Qupls4_pkg::OP_STORE};
	push6 = {6'd0,19'h7FFD0,8'd0,3'b0,sp[4:0],3'b0,ir[36:32],Qupls4_pkg::OP_STORE};
	push7 = {6'd0,19'h7FFC8,8'd0,3'b0,sp[4:0],3'b0,ir[41:37],Qupls4_pkg::OP_STORE};
end
always_comb
begin
	pop1 = {6'd0,19'h00000,8'd0,3'b0,sp[4:0],3'b0,ir[11: 7],Qupls4_pkg::OP_LOAD};
	pop2 = {6'd0,19'h00008,8'd0,3'b0,sp[4:0],3'b0,ir[16:12],Qupls4_pkg::OP_LOAD};
	pop3 = {6'd0,19'h00010,8'd0,3'b0,sp[4:0],3'b0,ir[21:17],Qupls4_pkg::OP_LOAD};
	pop4 = {6'd0,19'h00018,8'd0,3'b0,sp[4:0],3'b0,ir[26:22],Qupls4_pkg::OP_LOAD};
	pop5 = {6'd0,19'h00020,8'd0,3'b0,sp[4:0],3'b0,ir[31:27],Qupls4_pkg::OP_LOAD};
	pop6 = {6'd0,19'h00028,8'd0,3'b0,sp[4:0],3'b0,ir[36:32],Qupls4_pkg::OP_LOAD};
	pop7 = {6'd0,19'h00030,8'd0,3'b0,sp[4:0],3'b0,ir[41:37],Qupls4_pkg::OP_LOAD};
end
always_comb
begin
	decsp8 = {2'd3,4'd0,27'h7FFFFF8,sp,sp,Qupls4_pkg::OP_ADDI};
	decsp16 = {2'd3,4'd0,27'h7FFFFF0,sp,sp,Qupls4_pkg::OP_ADDI};
	decsp24 = {2'd3,4'd0,27'h7FFFFE8,sp,sp,Qupls4_pkg::OP_ADDI};
	decsp32 = {2'd3,4'd0,27'h7FFFFE0,sp,sp,Qupls4_pkg::OP_ADDI};
	decsp40 = {2'd3,4'd0,27'h7FFFFD8,sp,sp,Qupls4_pkg::OP_ADDI};
	decsp48 = {2'd3,4'd0,27'h7FFFFD0,sp,sp,Qupls4_pkg::OP_ADDI};
	decsp56 = {2'd3,4'd0,27'h7FFFFC8,sp,sp,Qupls4_pkg::OP_ADDI};
end
always_comb
begin
	incsp8 = {2'd3,4'd0,27'h0000008,sp,sp,Qupls4_pkg::OP_ADDI};
	incsp16 = {2'd3,4'd0,27'h0000010,sp,sp,Qupls4_pkg::OP_ADDI};
	incsp24 = {2'd3,4'd0,27'h0000018,sp,sp,Qupls4_pkg::OP_ADDI};
	incsp32 = {2'd3,4'd0,27'h0000020,sp,sp,Qupls4_pkg::OP_ADDI};
	incsp40 = {2'd3,4'd0,27'h0000028,sp,sp,Qupls4_pkg::OP_ADDI};
	incsp48 = {2'd3,4'd0,27'h0000030,sp,sp,Qupls4_pkg::OP_ADDI};
	incsp56 = {2'd3,4'd0,27'h0000038,sp,sp,Qupls4_pkg::OP_ADDI};
end
// ENTER instructions
always_comb
begin
	enter_st_fp = {6'd0,19'h7FFE0,8'd0,ssp,fp,Qupls4_pkg::OP_STORE};
	enter_st_lr = {6'd0,19'h7FFE8,8'd0,ssp,lr1,Qupls4_pkg::OP_STORE};
	fp_eq_sp = {6'd0,27'h0,8'b0,ir[11:7],3'b0,ir[17:13],Qupls4_pkg::OP_ORI};
	decssp32 = {2'd3,2'd0,27'h7FFFFE0,ssp,ssp,Qupls4_pkg::OP_ADDI};
	incssp32 = {2'd3,2'd0,27'h0000020,ssp,ssp,Qupls4_pkg::OP_ADDI};
	sp_eq_fp = {2'd0,2'd0,27'h0,3'd0,ir[17:13],3'd0,ir[11:7],Qupls4_pkg::OP_ORI};
	exit_ld_fp = {6'd0,19'h00000,8'd0,ssp,fp,Qupls4_pkg::OP_LOAD};
	exit_ld_lr = {6'd0,19'h00008,8'd0,ssp,lr1,Qupls4_pkg::OP_LOAD};
end

always_comb
begin
	case (instr.any.opcode)
	Qupls4_pkg::OP_R3VS,Qupls4_pkg::OP_FLTVS:
		is_vs = ir[37:35]==3'd1;
	default:	is_vs = 1'b0;
	endcase
end

always_comb
begin
	case (instr.any.opcode)
	Qupls4_pkg::OP_R3P,Qupls4_pkg::OP_R3VS,Qupls4_pkg::OP_FLTVS:
		is_masked = ir[37:35]==3'd6;
	default:	is_masked = 1'b0;
	endcase
end

always_comb
begin
	case (instr.any.opcode)
	Qupls4_pkg::OP_R3P,Qupls4_pkg::OP_R3VS:
		case(ir[47:41])
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
	case (instr.any.opcode)
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
	vsins.extd.opcode = Qupls4_pkg::opcode_e'(ir[6:0]);
	vsins.extd.Rd = ir[12:7];
	vsins.extd.Rs1 = ir[18:13];
	vsins.extd.Rs2 = ir[24:19];
	vsins.extd.Rs3 = ir[30:25];
	vsins.extd.vn = ir[34:31];
	vsins.extd.op3 = ir[37:35];
	vsins.extd.ms = ir[40:38];
	vsins.extd.Rs4 = ir[47:41];
	vls.vls.opcode = Qupls4_pkg::opcode_e'(ir[6:0]);
	vls.vls.Rd = ir[12:7];
	vls.vls.Rs1 = ir[18:13];
	vls.vls.Rs2 = ir[24:19];
	vls.vls.Rs3 = ir[30:25];
	vls.vls.dt = ir[37:35];
	vls.vls.disp = ir[43:38];
	vls.vls.ms = ir[44];
	vls.vls.sc = ir[47:45];
	instr.any.opcode = Qupls4_pkg::opcode_e'(ir[6:0]);
	instr.r3.Rd = ir[12:7];
	instr.r3.Rs1 = ir[18:13];
	instr.r3.Rs2 = ir[24:19];
	instr.r3.Rs3 = ir[30:25];
	instr.r3.vn = ir[34:31];
	instr.r3.op3 = ir[37:35];
	instr.r3.ms = ir[40:38];
	instr.extd.Rs4 = ir[47:41];
	case(ir[6:0])
	Qupls4_pkg::OP_EXTD:
		begin
			vlen1 = vlen;	// use integer length
			case(instr.extd.op3)
			Qupls4_pkg::EX_VSHLV:	vsins.extd.op3 = Qupls4_pkg::EX_ASLC;
			Qupls4_pkg::EX_VSHRV:	vsins.extd.op3 = Qupls4_pkg::EX_LSRC;
			default:	;
			endcase
		end
	Qupls4_pkg::OP_R3P:
		begin
			instr.any.opcode = Qupls4_pkg::OP_R3BP | velsz[1:0];
			instr.r3.Rd = ir[12:7];
			instr.r3.Rs1 = ir[18:13];
			instr.r3.Rs2 = ir[24:19];
			instr.r3.Rs3 = ir[30:25];
			instr.r3.vn = ir[34:31];
			instr.r3.op3 = ir[37:35];
			instr.r3.func = Qupls4_pkg::func_e'(ir[47:41]);
			vlen1 = vlen;
		end
	Qupls4_pkg::OP_FLTP:
		begin
			instr.any.opcode = Qupls4_pkg::OP_FLTPH | velsz[9:8];
			instr.f3.Rd = ir[12:7];
			instr.f3.Rs1 = ir[18:13];
			instr.f3.Rs2 = ir[24:19];
			instr.f3.Rs3 = ir[30:25];
			instr.f3.vn = ir[34:31];
			instr.f3.rm = ir[37:35];
			instr.f3.func = Qupls4_pkg::flt_e'(ir[47:41]);
			vlen1 = fvlen;
		end
	Qupls4_pkg::OP_R3BP,Qupls4_pkg::OP_R3WP,Qupls4_pkg::OP_R3TP,Qupls4_pkg::OP_R3OP:
		begin
			instr.any.opcode = ir[6:0];
			instr.r3.Rd = ir[12:7];
			instr.r3.Rs1 = ir[18:13];
			instr.r3.Rs2 = ir[24:19];
			instr.r3.Rs3 = ir[30:25];
			instr.r3.vn = ir[34:31];
			instr.r3.op3 = ir[37:35];
			instr.r3.func = Qupls4_pkg::func_e'(ir[47:41]);
			vlen1 = vlen;
		end
	Qupls4_pkg::OP_FLTPH,Qupls4_pkg::OP_FLTPS,Qupls4_pkg::OP_FLTPD,Qupls4_pkg::OP_FLTPQ:
		begin
			instr.any.opcode = ir[6:0];
			instr.f3.Rd = ir[12:7];
			instr.f3.Rs1 = ir[18:13];
			instr.f3.Rs2 = ir[24:19];
			instr.f3.Rs3 = ir[30:25];
			instr.f3.vn = ir[34:31];
			instr.f3.rm = ir[37:35];
			instr.f3.func = Qupls4_pkg::flt_e'(ir[47:41]);
			vlen1 = fvlen;
		end
	Qupls4_pkg::OP_LDV,Qupls4_pkg::OP_STV,
	Qupls4_pkg::OP_LDVN,Qupls4_pkg::OP_STVN:
		case(vls.vls.dt)
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

always_comb vRd = (instr.r3.vn[0] & is_vector) ? ({1'b0,instr.r3.Rd,2'b00}) + num_scalar_reg : {2'b0,instr.r3.Rd};
always_comb vRs1 = (instr.r3.vn[1] & is_vector) ? ({1'b0,instr.r3.Rs1,2'b00}) + num_scalar_reg : {2'b0,instr.r3.Rs1};
always_comb vRs2 = (instr.r3.vn[2] & is_vector) ? ({1'b0,instr.r3.Rs2,2'b00}) + num_scalar_reg : {2'b0,instr.r3.Rs2};
always_comb vRs3 = (instr.r3.vn[3] & is_vector) ? ({1'b0,instr.r3.Rs3,2'b00}) + num_scalar_reg : {2'b0,instr.r3.Rs3};
always_comb vRdi = (instr.r3.vn[0] & is_vector);
// Don't increment a constant field.
always_comb vRs1i = (instr.r3.vn[1] & ~instr.r3.ms[0] & is_vector);
always_comb vRs2i = (instr.r3.vn[2] & ~instr.r3.ms[1] & is_vector);
always_comb vRs3i = (instr.r3.vn[3] & ~instr.r3.ms[2] & is_vector);

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
	
	case(ir[6:0])
	Qupls4_pkg::OP_BRK:	begin uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,ir}; count = 3'd1; end
	Qupls4_pkg::OP_MOVMR:
		begin
			if (insert_boi) begin
				kk = 1;
				uop[0] = uop_boi;
				if (ir[11: 7]!=5'd0) begin uop[kk] = {1'b1,1'b0,1'd0,5'd0,4'd0,Qupls4_pkg::FN_MOVE,3'd0,3'd4,4'd0,8'h00,8'h00,{3'd0,ir[16:12]},{3'd0,ir[11: 7]},Qupls4_pkg::OP_R3O}; kk = kk + 1; end
				if (ir[21:17]!=5'd0) begin uop[kk] = {1'b1,1'b0,1'd0,5'd0,4'd0,Qupls4_pkg::FN_MOVE,3'd0,3'd4,4'd0,8'h00,8'h00,{3'd0,ir[26:22]},{3'd0,ir[21:17]},Qupls4_pkg::OP_R3O}; kk = kk + 1; end
				if (ir[31:27]!=5'd0) begin uop[kk] = {1'b1,1'b0,1'd0,5'd0,4'd0,Qupls4_pkg::FN_MOVE,3'd0,3'd4,4'd0,8'h00,8'h00,{3'd0,ir[36:32]},{3'd0,ir[31:27]},Qupls4_pkg::OP_R3O}; kk = kk + 1; end
				if (ir[41:37]!=5'd0) begin uop[kk] = {1'b1,1'b0,1'd0,5'd0,4'd0,Qupls4_pkg::FN_MOVE,3'd0,3'd4,4'd0,8'h00,8'h00,{3'd0,ir[46:42]},{3'd0,ir[41:37]},Qupls4_pkg::OP_R3O}; kk = kk + 1; end
				count = kk[3:0];
				uop[0].any.lead = 1'd1;
				uop[0].any.num = 5'd0;
				uop[1].any.num = 5'd1;
				uop[2].any.num = 5'd2;
				uop[3].any.num = 5'd3;
				uop[4].any.num = 5'd4;
			end
			else begin
				kk = 0;
				if (ir[11: 7]!=5'd0) begin uop[kk] = {1'b1,1'b0,1'd0,5'd0,4'd0,Qupls4_pkg::FN_MOVE,3'd0,3'd4,4'd0,8'h00,8'h00,{3'd0,ir[16:12]},{3'd0,ir[11: 7]},Qupls4_pkg::OP_R3O}; kk = kk + 1; end
				if (ir[21:17]!=5'd0) begin uop[kk] = {1'b1,1'b0,1'd0,5'd0,4'd0,Qupls4_pkg::FN_MOVE,3'd0,3'd4,4'd0,8'h00,8'h00,{3'd0,ir[26:22]},{3'd0,ir[21:17]},Qupls4_pkg::OP_R3O}; kk = kk + 1; end
				if (ir[31:27]!=5'd0) begin uop[kk] = {1'b1,1'b0,1'd0,5'd0,4'd0,Qupls4_pkg::FN_MOVE,3'd0,3'd4,4'd0,8'h00,8'h00,{3'd0,ir[36:32]},{3'd0,ir[31:27]},Qupls4_pkg::OP_R3O}; kk = kk + 1; end
				if (ir[41:37]!=5'd0) begin uop[kk] = {1'b1,1'b0,1'd0,5'd0,4'd0,Qupls4_pkg::FN_MOVE,3'd0,3'd4,4'd0,8'h00,8'h00,{3'd0,ir[46:42]},{3'd0,ir[41:37]},Qupls4_pkg::OP_R3O}; kk = kk + 1; end
				count = kk[3:0];
				uop[0].any.lead = 1'd1;
				uop[0].any.num = 5'd0;
				uop[1].any.num = 5'd1;
				uop[2].any.num = 5'd2;
				uop[3].any.num = 5'd3;
			end
		end
	Qupls4_pkg::OP_EXTD:
		begin
			if (SUPPORT_VECTOR) begin
				case(instr.extd.op3)
				EX_VSHLV,EX_VSHRV:
					case({VREGS > 4,vlen1[3:0]})
					5'd1:	
						begin
							count = 4'd1;
							uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,{2'b00,vsins.extd.Rs3},{2'b00,vsins.extd.Rs2},vRs1,vRd,vsins.extd.opcode};
						end
					5'd2:	
						begin
							count = 4'd2;
							uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,{2'b00,vsins.extd.Rs3},{2'b00,vsins.extd.Rs2},vRs1,vRd,vsins.extd.opcode};
							uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,{2'b0,vsins.extd.Rs4},vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd1,vRd+7'd1,vsins.extd.opcode};
						end
					5'd3:	
						begin
							count = 4'd3;
							uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,{2'b00,vsins.extd.Rs3},{2'b00,vsins.extd.Rs2},vRs1,vRd,vsins.extd.opcode};
							uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd1,vRd+7'd1,vsins.extd.opcode};
							uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,{2'b0,vsins.extd.Rs4},vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd2,vRd+7'd2,vsins.extd.opcode};
						end
					5'd4:	
						begin
							count = 4'd4;
							uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,{2'b00,vsins.extd.Rs3},{2'b00,vsins.extd.Rs2},vRs1,vRd,vsins.extd.opcode};
							uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd1,vRd+7'd1,vsins.extd.opcode};
							uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd2,vRd+7'd2,vsins.extd.opcode};
							uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,{2'b00,vsins.extd.Rs4},vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd3,vRd+7'd3,vsins.extd.opcode};
						end
					5'd21:	
						begin
							count = 4'd5;
							uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,{2'b00,vsins.extd.Rs3},{2'b00,vsins.extd.Rs2},vRs1,vRd,vsins.extd.opcode};
							uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd1,vRd+7'd1,vsins.extd.opcode};
							uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd2,vRd+7'd2,vsins.extd.opcode};
							uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd3,vRd+7'd3,vsins.extd.opcode};
							uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,{2'b00,vsins.extd.Rs4},vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd4,vRd+7'd4,vsins.extd.opcode};
						end
					5'd22:	
						begin
							count = 4'd6;
							uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,{2'b00,vsins.extd.Rs3},{2'b00,vsins.extd.Rs2},vRs1,vRd,vsins.extd.opcode};
							uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd1,vRd+7'd1,vsins.extd.opcode};
							uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd2,vRd+7'd2,vsins.extd.opcode};
							uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd3,vRd+7'd3,vsins.extd.opcode};
							uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd4,vRd+7'd4,vsins.extd.opcode};
							uop[5] = {1'b1,1'b0,1'd0,5'd5,4'd0,{2'b00,vsins.extd.Rs4},vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd5,vRd+7'd5,vsins.extd.opcode};
						end
					5'd23:	
						begin
							count = 4'd7;
							uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,{2'b00,vsins.extd.Rs3},{2'b00,vsins.extd.Rs2},vRs1,vRd,vsins.extd.opcode};
							uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd1,vRd+7'd1,vsins.extd.opcode};
							uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd2,vRd+7'd2,vsins.extd.opcode};
							uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd3,vRd+7'd3,vsins.extd.opcode};
							uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd4,vRd+7'd4,vsins.extd.opcode};
							uop[5] = {1'b1,1'b0,1'd0,5'd5,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd5,vRd+7'd5,vsins.extd.opcode};
							uop[6] = {1'b1,1'b0,1'd0,5'd6,4'd0,{2'b00,vsins.extd.Rs4},vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd6,vRd+7'd6,vsins.extd.opcode};
						end
					5'd24:
						begin
							count = 4'd8;
							uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,{2'b00,vsins.extd.Rs3},{2'b00,vsins.extd.Rs2},vRs1,vRd,vsins.extd.opcode};
							uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd1,vRd+7'd1,vsins.extd.opcode};
							uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd2,vRd+7'd2,vsins.extd.opcode};
							uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd3,vRd+7'd3,vsins.extd.opcode};
							uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd4,vRd+7'd4,vsins.extd.opcode};
							uop[5] = {1'b1,1'b0,1'd0,5'd5,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd5,vRd+7'd5,vsins.extd.opcode};
							uop[6] = {1'b1,1'b0,1'd0,5'd6,4'd0,mo0,vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd6,vRd+7'd6,vsins.extd.opcode};
							uop[7] = {1'b1,1'b0,1'd0,5'd7,4'd0,{2'b00,vsins.extd.Rs4},vsins.extd.ms,vsins.extd.op3,mo0,{2'b00,vsins.extd.Rs2},vRs1+7'd7,vRd+7'd7,vsins.extd.opcode};
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
			if (insert_boi) begin
				count = 4'd2;
				uop[0] = uop_boi;
				uop[1] = uop1;
			end
			else begin
				count = 4'd1;
				uop[0] = uop0;
			end
		end
	Qupls4_pkg::OP_ADDI,
	Qupls4_pkg::OP_SUBFI:
		begin
			if (insert_boi) begin
				count = 4'd2;
				uop[0] = uop_boi;
				uop[1] = uop1;
			end
			else begin
				count = 4'd1;
				uop[0] = uop0;
			end
		end

	Qupls4_pkg::OP_R3P,Qupls4_pkg::OP_R3VS,
	Qupls4_pkg::OP_FLTP,Qupls4_pkg::OP_FLTVS,
	Qupls4_pkg::OP_R3BP,Qupls4_pkg::OP_R3WP,Qupls4_pkg::OP_R3TP,Qupls4_pkg::OP_R3OP,
	Qupls4_pkg::OP_FLTPH,Qupls4_pkg::OP_FLTPS,Qupls4_pkg::OP_FLTPD,Qupls4_pkg::OP_FLTPQ:
		if (SUPPORT_VECTOR) begin
			case({VREGS > 4,vlen1[3:0]})
			5'd1:
				begin
			count = 4'd1;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,vRs3,vRs2,vRs1,vRd,instr.any.opcode};
			     end
			5'd2:
				begin
			count = 4'd2;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,vRs3,vRs2,vRs1,vRd,instr.any.opcode};
			uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,vRs3+vRs3i,vRs2+vRs2i,vRs1+vRs1i,vRd+vRdi,instr.any.opcode};
				end
			5'd3:
				begin
			count = 4'd3;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,vRs3,vRs2,vRs1,vRd,instr.any.opcode};
			uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,vRs3+vRs3i,vRs2+vRs2i,vRs1+vRs1i,vRd+vRdi,instr.any.opcode};
			uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,
				vRs3+(vRs3i?8'd2:8'd0),vRs2+(vRs2i?8'd2:8'd0),vRs1+(vRs1i?8'd2:8'd0),vRd+(vRdi?8'd2:8'd0),instr.any.opcode};
				end
			5'd4:
				begin
			count = 4'd4;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,vRs3,vRs2,vRs1,vRd,instr.any.opcode};
			uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,vRs3+vRs3i,vRs2+vRs2i,vRs1+vRs1i,vRd+vRdi,instr.any.opcode};
			uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,
				vRs3+(vRs3i?8'd2:8'd0),vRs2+(vRs2i?8'd2:8'd0),vRs1+(vRs1i?8'd2:8'd0),vRd+(vRdi?8'd2:8'd0),instr.any.opcode};
			uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,
				vRs3+(vRs3i?8'd3:8'd0),vRs2+(vRs2i?8'd3:8'd0),vRs1+(vRs1i?8'd3:8'd0),vRd+(vRdi?8'd3:8'd0),instr.any.opcode};
				end
			5'd21:
				begin
			count = 4'd5;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,vRs3,vRs2,vRs1,vRd,instr.any.opcode};
			uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,vRs3+vRs3i,vRs2+vRs2i,vRs1+vRs1i,vRd+vRdi,instr.any.opcode};
			uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,
				vRs3+(vRs3i?8'd2:8'd0),vRs2+(vRs2i?8'd2:8'd0),vRs1+(vRs1i?8'd2:8'd0),vRd+(vRdi?8'd2:8'd0),instr.any.opcode};
			uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,
				vRs3+(vRs3i?8'd3:8'd0),vRs2+(vRs2i?8'd3:8'd0),vRs1+(vRs1i?8'd3:8'd0),vRd+(vRdi?8'd3:8'd0),instr.any.opcode};
			uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,
				vRs3+(vRs3i?8'd4:8'd0),vRs2+(vRs2i?8'd4:8'd0),vRs1+(vRs1i?8'd4:8'd0),vRd+(vRdi?8'd4:8'd0),instr.any.opcode};
				end
			5'd22:
				begin
			count = 4'd6;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,vRs3,vRs2,vRs1,vRd,instr.any.opcode};
			uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,vRs3+vRs3i,vRs2+vRs2i,vRs1+vRs1i,vRd+vRdi,instr.any.opcode};
			uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,
				vRs3+(vRs3i?8'd2:8'd0),vRs2+(vRs2i?8'd2:8'd0),vRs1+(vRs1i?8'd2:8'd0),vRd+(vRdi?8'd2:8'd0),instr.any.opcode};
			uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,
				vRs3+(vRs3i?8'd3:8'd0),vRs2+(vRs2i?8'd3:8'd0),vRs1+(vRs1i?8'd3:8'd0),vRd+(vRdi?8'd3:8'd0),instr.any.opcode};
			uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,
				vRs3+(vRs3i?8'd4:8'd0),vRs2+(vRs2i?8'd4:8'd0),vRs1+(vRs1i?8'd4:8'd0),vRd+(vRdi?8'd4:8'd0),instr.any.opcode};
			uop[5] = {1'b1,1'b0,1'd0,5'd5,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,
				vRs3+(vRs3i?8'd5:8'd0),vRs2+(vRs2i?8'd5:8'd0),vRs1+(vRs1i?8'd5:8'd0),vRd+(vRdi?8'd5:8'd0),instr.any.opcode};
				end
			5'd23:
				begin
			count = 4'd7;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,vRs3,vRs2,vRs1,vRd,instr.any.opcode};
			uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,vRs3+vRs3i,vRs2+vRs2i,vRs1+vRs1i,vRd+vRdi,instr.any.opcode};
			uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,
				vRs3+(vRs3i?8'd2:8'd0),vRs2+(vRs2i?8'd2:8'd0),vRs1+(vRs1i?8'd2:8'd0),vRd+(vRdi?8'd2:8'd0),instr.any.opcode};
			uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,
				vRs3+(vRs3i?8'd3:8'd0),vRs2+(vRs2i?8'd3:8'd0),vRs1+(vRs1i?8'd3:8'd0),vRd+(vRdi?8'd3:8'd0),instr.any.opcode};
			uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,
				vRs3+(vRs3i?8'd4:8'd0),vRs2+(vRs2i?8'd4:8'd0),vRs1+(vRs1i?8'd4:8'd0),vRd+(vRdi?8'd4:8'd0),instr.any.opcode};
			uop[5] = {1'b1,1'b0,1'd0,5'd5,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,
				vRs3+(vRs3i?8'd5:8'd0),vRs2+(vRs2i?8'd5:8'd0),vRs1+(vRs1i?8'd5:8'd0),vRd+(vRdi?8'd5:8'd0),instr.any.opcode};
			uop[6] = {1'b1,1'b0,1'd0,5'd6,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,
				vRs3+(vRs3i?8'd6:8'd0),vRs2+(vRs2i?8'd6:8'd0),vRs1+(vRs1i?8'd6:8'd0),vRd+(vRdi?8'd6:8'd0),instr.any.opcode};
				end
			5'd24:
				begin
			count = 4'd8;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,vRs3,vRs2,vRs1,vRd,instr.any.opcode};
			uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,vRs3+vRs3i,vRs2+vRs2i,vRs1+vRs1i,vRd+vRdi,instr.any.opcode};
			uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,
				vRs3+(vRs3i?8'd2:8'd0),vRs2+(vRs2i?8'd2:8'd0),vRs1+(vRs1i?8'd2:8'd0),vRd+(vRdi?8'd2:8'd0),instr.any.opcode};
			uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,
				vRs3+(vRs3i?8'd3:8'd0),vRs2+(vRs2i?8'd3:8'd0),vRs1+(vRs1i?8'd3:8'd0),vRd+(vRdi?8'd3:8'd0),instr.any.opcode};
			uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,
				vRs3+(vRs3i?8'd4:8'd0),vRs2+(vRs2i?8'd4:8'd0),vRs1+(vRs1i?8'd4:8'd0),vRd+(vRdi?8'd4:8'd0),instr.any.opcode};
			uop[5] = {1'b1,1'b0,1'd0,5'd5,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,
				vRs3+(vRs3i?8'd5:8'd0),vRs2+(vRs2i?8'd5:8'd0),vRs1+(vRs1i?8'd5:8'd0),vRd+(vRdi?8'd5:8'd0),instr.any.opcode};
			uop[6] = {1'b1,1'b0,1'd0,5'd6,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,
				vRs3+(vRs3i?8'd6:8'd0),vRs2+(vRs2i?8'd6:8'd0),vRs1+(vRs1i?8'd6:8'd0),vRd+(vRdi?8'd6:8'd0),instr.any.opcode};
			uop[7] = {1'b1,1'b0,1'd0,5'd7,4'd0,instr.r3.func,instr.r3.ms,instr.r3.op3,
				vRs3+(vRs3i?8'd7:8'd0),vRs2+(vRs2i?8'd7:8'd0),vRs1+(vRs1i?8'd7:8'd0),vRd+(vRdi?8'd7:8'd0),instr.any.opcode};
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
			case({VREGS > 4,vlen1[3:0]})
			5'd1:
				begin
			count = 4'd1;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,vls};
				end
			5'd2:
				begin
			count = 4'd2;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd8,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd1,vls.vls.opcode};
				end
			5'd3:
				begin
			count = 4'd3;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd8,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd1,vls.vls.opcode};
			uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd16,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd2,vls.vls.opcode};
				end
			5'd4:
				begin
			count = 4'd4;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd8,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd1,vls.vls.opcode};
			uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd16,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd2,vls.vls.opcode};
			uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd24,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd3,vls.vls.opcode};
				end
			5'd21:
				begin
			count = 4'd5;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd8,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd1,vls.vls.opcode};
			uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd16,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd2,vls.vls.opcode};
			uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd24,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd3,vls.vls.opcode};
			uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd32,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd4,vls.vls.opcode};
				end
			5'd22:
				begin
			count = 4'd6;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd8,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd1,vls.vls.opcode};
			uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd16,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd2,vls.vls.opcode};
			uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd24,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd3,vls.vls.opcode};
			uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd32,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd4,vls.vls.opcode};
			uop[5] = {1'b1,1'b0,1'd0,5'd5,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd40,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd5,vls.vls.opcode};
				end
			5'd23:
				begin
			count = 4'd7;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd8,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd1,vls.vls.opcode};
			uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd16,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd2,vls.vls.opcode};
			uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd24,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd3,vls.vls.opcode};
			uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd32,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd4,vls.vls.opcode};
			uop[5] = {1'b1,1'b0,1'd0,5'd5,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd40,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd5,vls.vls.opcode};
			uop[6] = {1'b1,1'b0,1'd0,5'd6,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd48,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd6,vls.vls.opcode};
				end
			5'd24:
				begin
			count = 4'd8;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd8,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd1,vls.vls.opcode};
			uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd16,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd2,vls.vls.opcode};
			uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd24,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd3,vls.vls.opcode};
			uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd32,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd4,vls.vls.opcode};
			uop[5] = {1'b1,1'b0,1'd0,5'd5,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd40,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd5,vls.vls.opcode};
			uop[6] = {1'b1,1'b0,1'd0,5'd6,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd48,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd6,vls.vls.opcode};
			uop[7] = {1'b1,1'b0,1'd0,5'd7,4'd0,vls.vls.sc,vls.vls.ms,vls.vls.disp+6'd56,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2,vls.vls.Rs1,vls.vls.Rd+7'd7,vls.vls.opcode};
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
			case({VREGS > 4,vlen1[3:0]})
			5'd1:
				begin
			count = 4'd1;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,vls};
				end
			5'd2:
				begin
			count = 4'd2;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd1,vls.vls.Rs1,vls.vls.Rd+7'd1,vls.vls.opcode};
				end
			5'd3:
				begin
			count = 4'd3;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd1,vls.vls.Rs1,vls.vls.Rd+7'd1,vls.vls.opcode};
			uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd2,vls.vls.Rs1,vls.vls.Rd+7'd2,vls.vls.opcode};
				end
			5'd4:
				begin
			count = 4'd4;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd1,vls.vls.Rs1,vls.vls.Rd+7'd1,vls.vls.opcode};
			uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd2,vls.vls.Rs1,vls.vls.Rd+7'd2,vls.vls.opcode};
			uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd3,vls.vls.Rs1,vls.vls.Rd+7'd3,vls.vls.opcode};
				end
			5'd21:
				begin
			count = 4'd5;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd1,vls.vls.Rs1,vls.vls.Rd+7'd1,vls.vls.opcode};
			uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd2,vls.vls.Rs1,vls.vls.Rd+7'd2,vls.vls.opcode};
			uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd3,vls.vls.Rs1,vls.vls.Rd+7'd3,vls.vls.opcode};
			uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd4,vls.vls.Rs1,vls.vls.Rd+7'd4,vls.vls.opcode};
				end
			5'd22:
				begin
			count = 4'd6;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd1,vls.vls.Rs1,vls.vls.Rd+7'd1,vls.vls.opcode};
			uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd2,vls.vls.Rs1,vls.vls.Rd+7'd2,vls.vls.opcode};
			uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd3,vls.vls.Rs1,vls.vls.Rd+7'd3,vls.vls.opcode};
			uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd4,vls.vls.Rs1,vls.vls.Rd+7'd4,vls.vls.opcode};
			uop[5] = {1'b1,1'b0,1'd0,5'd5,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd5,vls.vls.Rs1,vls.vls.Rd+7'd5,vls.vls.opcode};
				end
			5'd23:
				begin
			count = 4'd7;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd1,vls.vls.Rs1,vls.vls.Rd+7'd1,vls.vls.opcode};
			uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd2,vls.vls.Rs1,vls.vls.Rd+7'd2,vls.vls.opcode};
			uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd3,vls.vls.Rs1,vls.vls.Rd+7'd3,vls.vls.opcode};
			uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd4,vls.vls.Rs1,vls.vls.Rd+7'd4,vls.vls.opcode};
			uop[5] = {1'b1,1'b0,1'd0,5'd5,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd5,vls.vls.Rs1,vls.vls.Rd+7'd5,vls.vls.opcode};
			uop[6] = {1'b1,1'b0,1'd0,5'd6,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd6,vls.vls.Rs1,vls.vls.Rd+7'd6,vls.vls.opcode};
				end
			5'd24:
				begin
			count = 4'd8;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,vls};
			uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd1,vls.vls.Rs1,vls.vls.Rd+7'd1,vls.vls.opcode};
			uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd2,vls.vls.Rs1,vls.vls.Rd+7'd2,vls.vls.opcode};
			uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd3,vls.vls.Rs1,vls.vls.Rd+7'd3,vls.vls.opcode};
			uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd4,vls.vls.Rs1,vls.vls.Rd+7'd4,vls.vls.opcode};
			uop[5] = {1'b1,1'b0,1'd0,5'd5,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd5,vls.vls.Rs1,vls.vls.Rd+7'd5,vls.vls.opcode};
			uop[6] = {1'b1,1'b0,1'd0,5'd6,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd6,vls.vls.Rs1,vls.vls.Rd+7'd6,vls.vls.opcode};
			uop[7] = {1'b1,1'b0,1'd0,5'd7,4'd0,vls.vls.sc,1'b0,6'd0,vls.vls.dt,vls.vls.Rs3,vls.vls.Rs2+7'd7,vls.vls.Rs1,vls.vls.Rd+7'd7,vls.vls.opcode};
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
			case(ir[47:41])
			Qupls4_pkg::FN_ADD,Qupls4_pkg::FN_SUB,Qupls4_pkg::FN_MUL,Qupls4_pkg::FN_DIV,
			Qupls4_pkg::FN_MULU,Qupls4_pkg::FN_DIVU,Qupls4_pkg::FN_MULSU,Qupls4_pkg::FN_DIVSU,
			Qupls4_pkg::FN_AND,Qupls4_pkg::FN_OR,Qupls4_pkg::FN_XOR:
				begin
			endcase
		*/
	/*
	Qupls4_pkg::OP_R3B,Qupls4_pkg::OP_R3W,Qupls4_pkg::OP_R3T,Qupls4_pkg::OP_R3O:
		begin
			case(ir[47:41])
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
			if (insert_boi) begin
				count = 4'd2;
				uop[0] = uop_boi;
				uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,instr};
			end
			else begin
				count = 4'd1;
				uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,instr};
			end
		end
/*		
	Qupls4_pkg::OP_MOV:
		begin
			count = 4'd1;
			uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,ir};
		end
*/			
	Qupls4_pkg::OP_ENTER:
		begin
			count = 4'd5;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,enter_st_fp};
			uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,fp_eq_sp};
			uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,enter_st_lr};
			uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,decssp32};
			uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,instr};
		end
	Qupls4_pkg::OP_EXIT:
		begin
			count = 4'd5;
			uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,sp_eq_fp};
			uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,exit_ld_fp};
			uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,exit_ld_lr};
			uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,incssp32};
			uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,2'd3,ir[45:21],7'd57,ir[13:7],Qupls4_pkg::OP_RTD};	// change LEAVE into RTD
		end
	Qupls4_pkg::OP_PUSH:
		begin
			count = {1'b0,ir[47:45]} + 2'd1;
			case(ir[47:45])
			4'd1:	
				begin
					uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,push1};
					uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,2'd3,4'd0,27'h7FFFFF8,sp+ir[37:35],sp+ir[44:42],Qupls4_pkg::OP_ADDI};
				end
			4'd2:
				begin
					uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,push1};
					uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,push2};
					uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,2'd3,4'd0,27'h7FFFFF0,sp+ir[37:35],sp+ir[44:42],Qupls4_pkg::OP_ADDI};
				end
			4'd3:
				begin
					uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,push1};
					uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,push2};
					uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,push3};
					uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,2'd3,4'd0,27'h7FFFFE8,sp+ir[37:35],sp+ir[44:42],Qupls4_pkg::OP_ADDI};
				end
			4'd4:
				begin
					uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,push1};
					uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,push2};
					uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,push3};
					uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,push4};
					uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,2'd3,4'd0,27'h7FFFFE0,sp+ir[37:35],sp+ir[44:42],Qupls4_pkg::OP_ADDI};
				end
			4'd5:
				begin
					uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,push1};
					uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,push2};
					uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,push3};
					uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,push4};
					uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,push5};
					uop[5] = {1'b1,1'b0,1'd0,5'd5,4'd0,2'd3,4'd0,27'h7FFFFD8,sp+ir[37:35],sp+ir[44:42],Qupls4_pkg::OP_ADDI};
				end
			4'd6:
				begin
					uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,push1};
					uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,push2};
					uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,push3};
					uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,push4};
					uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,push5};
					uop[5] = {1'b1,1'b0,1'd0,5'd5,4'd0,push6};
					uop[6] = {1'b1,1'b0,1'd0,5'd6,4'd0,2'd3,4'd0,27'h7FFFFD0,sp+ir[37:35],sp+ir[44:42],Qupls4_pkg::OP_ADDI};
				end
			4'd7:
				begin
					uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,push1};
					uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,push2};
					uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,push3};
					uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,push4};
					uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,push5};
					uop[5] = {1'b1,1'b0,1'd0,5'd5,4'd0,push6};
					uop[6] = {1'b1,1'b0,1'd0,5'd6,4'd0,push7};
					uop[7] = {1'b1,1'b0,1'd0,5'd7,4'd0,2'd3,4'd0,27'h7FFFFC8,sp+ir[37:35],sp+ir[44:42],Qupls4_pkg::OP_ADDI};
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
			count = {1'b0,ir[47:45]} + 2'd1;
			case(ir[47:45])
			4'd1:	
				begin
					uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,pop1};
					uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,2'd3,31'h08,sp+ir[44:42],sp+ir[44:42],Qupls4_pkg::OP_ADDI};
				end
			4'd2:
				begin
					uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,pop1};
					uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,pop2};
					uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,2'd3,31'h10,sp+ir[44:42],sp+ir[44:42],Qupls4_pkg::OP_ADDI};
				end
			4'd3:
				begin
					uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,pop1};
					uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,pop2};
					uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,pop3};
					uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,2'd3,31'h18,sp+ir[44:42],sp+ir[44:42],Qupls4_pkg::OP_ADDI};
				end
			4'd4:
				begin
					uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,pop1};
					uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,pop2};
					uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,pop3};
					uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,pop4};
					uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,2'd3,31'h20,sp+ir[44:42],sp+ir[44:42],Qupls4_pkg::OP_ADDI};
				end
			4'd5:
				begin
					uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,pop1};
					uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,pop2};
					uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,pop3};
					uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,pop4};
					uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,pop5};
					uop[5] = {1'b1,1'b0,1'd0,5'd5,4'd0,2'd3,31'h28,sp+ir[44:42],sp+ir[44:42],Qupls4_pkg::OP_ADDI};
				end
			4'd6:
				begin
					uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,pop1};
					uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,pop2};
					uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,pop3};
					uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,pop4};
					uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,pop5};
					uop[5] = {1'b1,1'b0,1'd0,5'd5,4'd0,pop6};
					uop[6] = {1'b1,1'b0,1'd0,5'd6,4'd0,2'd3,31'h30,sp+ir[44:42],sp+ir[44:42],Qupls4_pkg::OP_ADDI};
				end
			4'd7:
				begin
					uop[0] = {1'b1,1'b0,1'd1,5'd0,4'd0,pop1};
					uop[1] = {1'b1,1'b0,1'd0,5'd1,4'd0,pop2};
					uop[2] = {1'b1,1'b0,1'd0,5'd2,4'd0,pop3};
					uop[3] = {1'b1,1'b0,1'd0,5'd3,4'd0,pop4};
					uop[4] = {1'b1,1'b0,1'd0,5'd4,4'd0,pop5};
					uop[5] = {1'b1,1'b0,1'd0,5'd5,4'd0,pop6};
					uop[6] = {1'b1,1'b0,1'd0,5'd6,4'd0,pop6};
					uop[7] = {1'b1,1'b0,1'd0,5'd7,4'd0,2'd3,31'h38,sp+ir[44:42],sp+ir[44:42],Qupls4_pkg::OP_ADDI};
				end
			default:	
				begin
					count = 4'd1;
					uop[0] = nopi;
				end
			endcase
		end
	Qupls4_pkg::OP_CHK,
	Qupls4_pkg::OP_STB,Qupls4_pkg::OP_STW,
	Qupls4_pkg::OP_STT,Qupls4_pkg::OP_STORE,Qupls4_pkg::OP_STI,
	Qupls4_pkg::OP_STPTR,
	Qupls4_pkg::OP_FENCE:
		begin
			if (insert_boi) begin
				count = 4'd2;
				uop[0] = uop_boi;
				uop[1] = uop1;
			end
			else begin
				count = 4'd1;
				uop[0] = uop0;
			end
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
			if (insert_boi) begin
				count = 4'd2;
				uop[0] = uop_boi;
				uop[1] = uop1;
			end
			else begin
				count = 4'd1;
				uop[0] = uop0;
			end
		end
	default:
		begin
			if (insert_boi) begin
				count = 4'd2;
				uop[0] = uop_boi;
				uop[1] = uop1;
			end
			else begin
				count = 4'd1;
				uop[0] = uop0;
			end
		end
	endcase
	for (nn = 0; nn < 32; nn = nn + 1) begin
		if (nn < num)
			uop[nn].any.v = 1'b0;
	end	
end


endmodule
