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
//
// Work to do: fix register fields, check widths, make sure thread included.
// ============================================================================

import const_pkg::*;
import Qupls4_pkg::*;

module Qupls4_microop_mem(rst, clk, en, om, ir, num, carry_reg, carry_out, carry_in,
	vlen_reg, velsz, count, uop, thread);
parameter UOP_ARRAY_SIZE = 32;
parameter COMB = 1;
input rst;
input clk;
input en;
input Qupls4_pkg::operating_mode_t om;
input Qupls4_pkg::micro_op_t ir;
input [4:0] num;
input [8:0] carry_reg;
input carry_out;
input carry_in;
input [63:0] vlen_reg;
input [63:0] velsz;
input [2:0] thread;
output reg [5:0] count;
output Qupls4_pkg::micro_op_t [31:0] uop;

integer nn, kk, n1;
reg [6:0] head0;
reg [6:0] tail0, tail1, tail2, tail3;
reg [5:0] next_count;
Qupls4_pkg::micro_op_t [31:0] next_uop;

reg insert_boi;
reg [7:0] boi_count = 8'd0;
Qupls4_pkg::micro_op_t nopi, uop_boi;
Qupls4_pkg::micro_op_t floadi1;
Qupls4_pkg::micro_op_t push1,push2,push3,push4,push5,push6,push7;
Qupls4_pkg::micro_op_t pop1,pop2,pop3,pop4,pop5,pop6,pop7;
Qupls4_pkg::micro_op_t decsp8,decsp16,decsp24,decsp32,decsp40,decsp48,decsp56,decsp64,decsp72,decsp80,decsp88,decsp96;
Qupls4_pkg::micro_op_t incsp8,incsp16,incsp24,incsp32,incsp40,incsp48,incsp56,incsp64,incsp72,incsp80,incsp88,incsp96;
Qupls4_pkg::micro_op_t incssp64,decssp64,incssp32,decssp32;
Qupls4_pkg::micro_op_t enter_st_fp, exit_ld_fp;
Qupls4_pkg::micro_op_t enter_st_lr, exit_ld_lr;
Qupls4_pkg::micro_op_t fp_eq_sp, sp_eq_fp;
Qupls4_pkg::micro_op_t instr;
Qupls4_pkg::micro_op_t vsins;
Qupls4_pkg::micro_op_t vls;
reg is_vector;
reg is_reduction;
reg is_vs, is_masked;
reg [9:0] vlen, fvlen, xvlen, cvlen, avlen;
reg [3:0] vlen1;
//wire [8:0] mo0 = 9'd40;		// micro-op temporary
wire [8:0] sp = 9'd31;
wire [8:0] ssp = 9'd32;
wire [8:0] fp = 9'd36;
wire [8:0] fp_status_reg = 9'd33;
wire [8:0] lr1 = 9'd38;
wire [8:0] ip_reg = 9'd62;
wire [8:0] zero_reg = 9'd63;
wire [8:0] num_scalar_reg = 9'd25;
wire [8:0] mot0_reg = 9'd34;
reg [8:0] vRd, vRs1, vRs2, vRs3;
reg [8:0] Rd, Rs1, Rs2, Rs3;
reg vRdi, vRs1i, vRs2i, vRs3i;		// whether to increment the register spec or not.

// Copy instruction to micro-op verbatium. The register fields need to be
// expanded by two bits each.
Qupls4_pkg::micro_op_t uop0;
always_comb
begin
  uop0 = instr;
  uop0.lead = 1'b1;
end
Qupls4_pkg::micro_op_t uop1;
always_comb
begin
  uop1 = instr;
  uop1.num = 5'd1;
end

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
	floadi1 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	floadi1.v = VAL;
	floadi1[30:29] = 3'd1;
//	floadi1.op4 = 4'd10;
	floadi1.Rd = 5'd15;
	floadi1.Rs2 = 5'd19;
	floadi1.Rs1 = 5'd1;
	floadi1.opcode = Qupls4_pkg::OP_FLTD;
end
always_comb
begin
	nopi = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	nopi.v = 1'b1;
	nopi.lead = 1'b1;
	nopi.num = 5'd0;
	nopi.opcode = Qupls4_pkg::OP_NOP;
end
always_comb
begin
	uop_boi = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	uop_boi.v = VAL;
	uop_boi.opcode = Qupls4_pkg::OP_BCCU64;
	uop_boi.cnd = Qupls4_pkg::CND_BOI;
	uop_boi.lead = 1'd1;
end

always_comb
begin
	push1 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	push1.v = VAL;
	push1.opcode = Qupls4_pkg::OP_STORE;
	push1.Rd = {3'b0,ir[18:13]};
	push1.Rs1 = {3'b0,ir[12:7]};
	push1.Rs2 = zero_reg;
	push1.imm = -64'd8;
	push1.sc = 3'd0;

	push2 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	push2.v = VAL;
	push2.opcode = Qupls4_pkg::OP_STORE;
	push2.Rd = {3'b0,ir[24:19]};
	push2.Rs1 = {3'b0,ir[12:7]};
	push2.Rs2 = zero_reg;
	push2.imm = -64'd16;
	push2.sc = 3'd0;

	push3 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	push3.v = VAL;
	push3.opcode = Qupls4_pkg::OP_STORE;
	push3.Rd = {3'b0,ir[30:25]};
	push3.Rs1 = {3'b0,ir[12:7]};
	push3.Rs2 = zero_reg;
	push3.imm = -64'd24;
	push3.sc = 3'd0;

	push4 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	push4.v = VAL;
	push4.opcode = Qupls4_pkg::OP_STORE;
	push4.Rd = {3'b0,ir[36:31]};
	push4.Rs1 = {3'b0,ir[12:7]};
	push4.Rs2 = zero_reg;
	push4.imm = -64'd32;
	push4.sc = 3'd0;

	push5 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	push5.v = VAL;
	push5.opcode = Qupls4_pkg::OP_STORE;
	push5.Rd = {3'b0,ir[42:37]};
	push5.Rs1 = {3'b0,ir[12:7]};
	push5.Rs2 = zero_reg;
	push5.imm = -64'd40;
	push5.sc = 3'd0;

end
always_comb
begin
	pop1 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	pop1.v = VAL;
	pop1.opcode = Qupls4_pkg::OP_LOAD;
	pop1.Rd = {3'b0,ir[18:13]};
	pop1.Rs1 = {3'b0,ir[12:7]};
	pop1.Rs2 = zero_reg;
	pop1.imm = 64'd0;
	pop1.sc = 3'd0;
	
	pop2 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	pop2.v = VAL;
	pop2.opcode = Qupls4_pkg::OP_LOAD;
	pop2.Rd = {3'b0,ir[24:19]};
	pop2.Rs1 = {3'b0,ir[12:7]};
	pop2.Rs2 = zero_reg;
	pop2.imm = 64'd8;
	pop2.sc = 3'd0;
	
	pop3 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	pop3.v = VAL;
	pop3.opcode = Qupls4_pkg::OP_LOAD;
	pop3.Rd = {3'b0,ir[30:25]};
	pop3.Rs1 = {3'b0,ir[12:7]};
	pop3.Rs2 = zero_reg;
	pop3.imm = 64'd16;
	pop3.sc = 3'd0;
	
	pop4 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	pop4.v = VAL;
	pop4.opcode = Qupls4_pkg::OP_LOAD;
	pop4.Rd = {3'b0,ir[36:31]};
	pop4.Rs1 = {3'b0,ir[12:7]};
	pop4.Rs2 = zero_reg;
	pop4.imm = 64'd24;
	pop4.sc = 3'd0;
	
	pop5 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	pop5.v = VAL;
	pop5.opcode = Qupls4_pkg::OP_LOAD;
	pop5.Rd = {3'b0,ir[42:37]};
	pop5.Rs1 = {3'b0,ir[12:7]};
	pop5.Rs2 = zero_reg;
	pop5.imm = 64'd32;
	pop5.sc = 3'd0;
	
end

always_comb
begin
	decsp8 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	decsp8.v = VAL;
	decsp8.opcode = Qupls4_pkg::OP_ADDI;
	decsp8.Rd = sp;
	decsp8.Rs1 = sp;
	decsp8.Rs2 = zero_reg;
	decsp8.Rs3 = zero_reg;
	decsp8.imm = -64'd8;
	decsp8.prc = 2'd3;

	decsp16 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	decsp16.v = VAL;
	decsp16.opcode = Qupls4_pkg::OP_ADDI;
	decsp16.Rd = sp;
	decsp16.Rs1 = sp;
	decsp16.Rs2 = zero_reg;
	decsp16.Rs3 = zero_reg;
	decsp16.imm = -64'd16;
	decsp16.prc = 2'd3;

	decsp24 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	decsp24.v = VAL;
	decsp24.opcode = Qupls4_pkg::OP_ADDI;
	decsp24.Rd = sp;
	decsp24.Rs1 = sp;
	decsp24.Rs2 = zero_reg;
	decsp24.Rs3 = zero_reg;
	decsp24.imm = -64'd24;
	decsp24.prc = 2'd3;

	decsp32 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	decsp32.v = VAL;
	decsp32.opcode = Qupls4_pkg::OP_ADDI;
	decsp32.Rd = sp;
	decsp32.Rs1 = sp;
	decsp32.Rs2 = zero_reg;
	decsp32.Rs3 = zero_reg;
	decsp32.imm = -64'd32;
	decsp32.prc = 2'd3;

	decsp40 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	decsp40.v = VAL;
	decsp40.opcode = Qupls4_pkg::OP_ADDI;
	decsp40.Rd = sp;
	decsp40.Rs1 = sp;
	decsp40.Rs2 = zero_reg;
	decsp40.Rs3 = zero_reg;
	decsp40.imm = -64'd40;
	decsp40.prc = 2'd3;

	decsp48 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	decsp48.v = VAL;
	decsp48.opcode = Qupls4_pkg::OP_ADDI;
	decsp48.Rd = sp;
	decsp48.Rs1 = sp;
	decsp48.Rs2 = zero_reg;
	decsp48.Rs3 = zero_reg;
	decsp48.imm = -64'd48;
	decsp48.prc = 2'd3;

	decsp56 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	decsp56.v = VAL;
	decsp56.opcode = Qupls4_pkg::OP_ADDI;
	decsp56.Rd = sp;
	decsp56.Rs1 = sp;
	decsp56.Rs2 = zero_reg;
	decsp56.Rs3 = zero_reg;
	decsp56.imm = -64'd56;
	decsp56.prc = 2'd3;

	decsp64 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	decsp64.v = VAL;
	decsp64.opcode = Qupls4_pkg::OP_ADDI;
	decsp64.Rd = sp;
	decsp64.Rs1 = sp;
	decsp64.Rs2 = zero_reg;
	decsp64.Rs3 = zero_reg;
	decsp64.imm = -64'd64;
	decsp64.prc = 2'd3;

	decsp72 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	decsp72.v = VAL;
	decsp72.opcode = Qupls4_pkg::OP_ADDI;
	decsp72.Rd = sp;
	decsp72.Rs1 = sp;
	decsp72.Rs2 = zero_reg;
	decsp72.Rs3 = zero_reg;
	decsp72.imm = -64'd72;
	decsp72.prc = 2'd3;

	decsp80 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	decsp80.v = VAL;
	decsp80.opcode = Qupls4_pkg::OP_ADDI;
	decsp80.Rd = sp;
	decsp80.Rs1 = sp;
	decsp80.Rs2 = zero_reg;
	decsp80.Rs3 = zero_reg;
	decsp80.imm = -64'd80;
	decsp80.prc = 2'd3;

	decsp88 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	decsp88.v = VAL;
	decsp88.opcode = Qupls4_pkg::OP_ADDI;
	decsp88.Rd = sp;
	decsp88.Rs1 = sp;
	decsp88.Rs2 = zero_reg;
	decsp88.Rs3 = zero_reg;
	decsp88.imm = -64'd88;
	decsp88.prc = 2'd3;

	decsp96 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	decsp96.v = VAL;
	decsp96.opcode = Qupls4_pkg::OP_ADDI;
	decsp96.Rd = sp;
	decsp96.Rs1 = sp;
	decsp96.Rs2 = zero_reg;
	decsp96.Rs3 = zero_reg;
	decsp96.imm = -64'd96;
	decsp96.prc = 2'd3;
end

always_comb
begin
	incsp8 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	incsp8.v = VAL;
	incsp8.opcode = Qupls4_pkg::OP_ADDI;
	incsp8.Rd = sp;
	incsp8.Rs1 = sp;
	incsp8.Rs2 = zero_reg;
	incsp8.Rs3 = zero_reg;
	incsp8.imm = 64'd8;
	incsp8.prc = 2'd3;

	incsp16 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	incsp16.v = VAL;
	incsp16.opcode = Qupls4_pkg::OP_ADDI;
	incsp16.Rd = sp;
	incsp16.Rs1 = sp;
	incsp16.Rs2 = zero_reg;
	incsp16.Rs3 = zero_reg;
	incsp16.imm = 64'd16;
	incsp16.prc = 2'd3;

	incsp24 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	incsp24.v = VAL;
	incsp24.opcode = Qupls4_pkg::OP_ADDI;
	incsp24.Rd = sp;
	incsp24.Rs1 = sp;
	incsp24.Rs2 = zero_reg;
	incsp24.Rs3 = zero_reg;
	incsp24.imm = 64'd24;
	incsp24.prc = 2'd3;

	incsp32 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	incsp32.v = VAL;
	incsp32.opcode = Qupls4_pkg::OP_ADDI;
	incsp32.Rd = sp;
	incsp32.Rs1 = sp;
	incsp32.Rs2 = zero_reg;
	incsp32.Rs3 = zero_reg;
	incsp32.imm = 64'd32;
	incsp32.prc = 2'd3;

	incsp40 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	incsp40.v = VAL;
	incsp40.opcode = Qupls4_pkg::OP_ADDI;
	incsp40.Rd = sp;
	incsp40.Rs1 = sp;
	incsp40.Rs2 = zero_reg;
	incsp40.Rs3 = zero_reg;
	incsp40.imm = 64'd40;
	incsp40.prc = 2'd3;

	incsp48 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	incsp48.v = VAL;
	incsp48.opcode = Qupls4_pkg::OP_ADDI;
	incsp48.Rd = sp;
	incsp48.Rs1 = sp;
	incsp48.Rs2 = zero_reg;
	incsp48.Rs3 = zero_reg;
	incsp48.imm = 64'd48;
	incsp48.prc = 2'd3;

	incsp56 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	incsp56.v = VAL;
	incsp56.opcode = Qupls4_pkg::OP_ADDI;
	incsp56.Rd = sp;
	incsp56.Rs1 = sp;
	incsp56.Rs2 = zero_reg;
	incsp56.Rs3 = zero_reg;
	incsp56.imm = 64'd56;
	incsp56.prc = 2'd3;

	incsp64 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	incsp64.v = VAL;
	incsp64.opcode = Qupls4_pkg::OP_ADDI;
	incsp64.Rd = sp;
	incsp64.Rs1 = sp;
	incsp64.Rs2 = zero_reg;
	incsp64.Rs3 = zero_reg;
	incsp64.imm = 64'd64;
	incsp64.prc = 2'd3;

	incsp72 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	incsp72.v = VAL;
	incsp72.opcode = Qupls4_pkg::OP_ADDI;
	incsp72.Rd = sp;
	incsp72.Rs1 = sp;
	incsp72.Rs2 = zero_reg;
	incsp72.Rs3 = zero_reg;
	incsp72.imm = 64'd72;
	incsp72.prc = 2'd3;

	incsp80 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	incsp80.v = VAL;
	incsp80.opcode = Qupls4_pkg::OP_ADDI;
	incsp80.Rd = sp;
	incsp80.Rs1 = sp;
	incsp80.Rs2 = zero_reg;
	incsp80.Rs3 = zero_reg;
	incsp80.imm = 64'd80;
	incsp80.prc = 2'd3;

	incsp88 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	incsp88.v = VAL;
	incsp88.opcode = Qupls4_pkg::OP_ADDI;
	incsp88.Rd = sp;
	incsp88.Rs1 = sp;
	incsp88.Rs2 = zero_reg;
	incsp88.Rs3 = zero_reg;
	incsp88.imm = 64'd88;
	incsp88.prc = 2'd3;

	incsp96 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	incsp96.v = VAL;
	incsp96.opcode = Qupls4_pkg::OP_ADDI;
	incsp96.Rd = sp;
	incsp96.Rs1 = sp;
	incsp96.Rs2 = zero_reg;
	incsp96.Rs3 = zero_reg;
	incsp96.imm = 64'd96;
	incsp96.prc = 2'd3;
end

// ENTER instructions
always_comb
begin
	enter_st_fp = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	enter_st_fp.v = VAL;
	enter_st_fp.opcode = Qupls4_pkg::OP_STORE;
	enter_st_fp.Rd = fp;
	enter_st_fp.Rs1 = ssp;
	enter_st_fp.Rs2 = zero_reg;
	enter_st_fp.imm = -64'd32;
	enter_st_fp.sc = 3'd0;

	enter_st_lr = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	enter_st_lr.v = VAL;
	enter_st_lr.opcode = Qupls4_pkg::OP_STORE;
	enter_st_lr.Rd = lr1;
	enter_st_lr.Rs1 = ssp;
	enter_st_lr.Rs2 = zero_reg;
	enter_st_lr.imm = -64'd24;
	enter_st_lr.sc = 3'd0;

	fp_eq_sp = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	fp_eq_sp.v = VAL;
	fp_eq_sp.opcode = Qupls4_pkg::OP_ORI;
	fp_eq_sp.Rd = {3'b0,ir[18:13]};
	fp_eq_sp.Rs1 = {3'b0,ir[12:7]};
	fp_eq_sp.RS2 = zero_reg;
	fp_eq_sp.imm = 64'd0;
	fp_eq_sp.prc = 2'd3;

	decssp32 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	decssp32.v = VAL;
	decssp32.opcode = Qupls4_pkg::OP_ADDI;
	decssp32.Rd = ssp;
	decssp32.Rs1 = ssp;
	decssp32.Rs2 = zero_reg;
	decssp32.Rs3 = zero_reg;
	decssp32.imm = -64'd32;
	decssp32.prc = 2'd3;

	incssp32 = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	incssp32.v = VAL;
	incssp32.opcode = Qupls4_pkg::OP_ADDI;
	incssp32.Rd = ssp;
	incssp32.Rs1 = ssp;
	incssp32.Rs2 = zero_reg;
	incssp32.Rs3 = zero_reg;
	incssp32.imm = 64'd32;
	incssp32.prc = 2'd3;

	sp_eq_fp = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	sp_eq_fp.v = VAL;
	sp_eq_fp.opcode = Qupls4_pkg::OP_ORI;
	sp_eq_fp.Rd = {3'b0,ir[12:7]};
	sp_eq_fp.Rs1 = {3'b0,ir[18:13]};
	sp_eq_fp.Rs2 = zero_reg;
	sp_eq_fp.imm = 64'd0;
	sp_eq_fp.prc = 2'd3;

	exit_ld_fp = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	exit_ld_fp.v = VAL;
	exit_ld_fp.opcode = Qupls4_pkg::OP_LOAD;
	exit_ld_fp.Rd = fp;
	exit_ld_fp.Rs1 = ssp;
	exit_ld_fp.Rs2 = zero_reg;
	exit_ld_fp.imm = 64'd0;
	exit_ld_fp.sc = 3'd0;
	
	exit_ld_lr = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
	exit_ld_lr.v = VAL;
	exit_ld_lr.opcode = Qupls4_pkg::OP_LOAD;
	exit_ld_lr.Rd = lr1;
	exit_ld_lr.Rs1 = ssp;
	exit_ld_lr.Rs2 = zero_reg;
	exit_ld_lr.imm = 64'd8;
	exit_ld_lr.sc = 3'd0;
end

always_comb
begin
	case (instr.opcode)
	Qupls4_pkg::OP_R3VS,Qupls4_pkg::OP_FLTVS:
		is_vs = ir.op3==3'd1;
	default:	is_vs = 1'b0;
	endcase
end

always_comb
begin
	case (instr.opcode)
	Qupls4_pkg::OP_R3P,Qupls4_pkg::OP_R3VS,Qupls4_pkg::OP_FLTVS:
		is_masked = ir.op3==3'd6;
	default:	is_masked = 1'b0;
	endcase
end

always_comb
begin
	case (instr.opcode)
	Qupls4_pkg::OP_R3P,Qupls4_pkg::OP_R3VS:
		case(ir.func)
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
	case (instr.opcode)
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
	vsins = ir;
	vsins.opcode = Qupls4_pkg::opcode_e'(ir[6:0]);
	vsins.v = VAL;
	vsins.Rd = thread*40+ir.Rd;
	vsins.Rs1 = thread*40+ir.Rs1;
	vsins.Rs2 = thread*40+ir.Rs2;
	vsins.Rs3 = thread*40+ir.Rs3;
	vls = ir;
	vls.v = VAL;
	vls.opcode = ir.opcode;
	vls.Rd = thread*40+ir.Rd;
	vls.Rs1 = thread*40+ir.Rs1;
	vls.Rs2 = thread*40+ir.Rs2;
	vls.Rs3 = thread*40+ir.Rs3;
	instr = ir;
	instr.v = VAL;
	instr.opcode = ir.opcode;
	instr.Rd = {thread*40+ir.Rd};
	instr.Rs1 = {thread*40+ir.Rs1};
	instr.Rs2 = {thread*40+ir.Rs2};
	instr.Rs3 = {thread*40+ir.Rs3};
	case(ir.opcode)
	Qupls4_pkg::OP_EXTD:
		begin
			vlen1 = vlen;	// use integer length
			case(instr.op3)
			Qupls4_pkg::EX_VSHLV:	vsins.op3 = Qupls4_pkg::EX_ASLC;
			Qupls4_pkg::EX_VSHRV:	vsins.op3 = Qupls4_pkg::EX_LSRC;
			default:	;
			endcase
		end
	Qupls4_pkg::OP_R3P:
		begin
			instr.opcode = Qupls4_pkg::OP_R3BP | velsz[1:0];
			instr.vn = ir.vn;
			instr.op3 = ir.op3;
			instr.func = ir.func;
			vlen1 = vlen;
		end
	Qupls4_pkg::OP_FLTP:
		begin
			instr.opcode = Qupls4_pkg::OP_FLTPH | velsz[9:8];
			instr.vn = ir.vn;
			instr.rmd = ir.rmd;
			instr.func = ir.func;
			vlen1 = fvlen;
		end
	Qupls4_pkg::OP_R3BP,Qupls4_pkg::OP_R3WP,Qupls4_pkg::OP_R3TP,Qupls4_pkg::OP_R3OP:
		begin
			instr.opcode = ir.opcode;
			instr.vn = ir.vn;
			instr.op3 = ir.op3;
			instr.func = ir.func;
			vlen1 = vlen;
		end
	Qupls4_pkg::OP_FLTPH,Qupls4_pkg::OP_FLTPS,Qupls4_pkg::OP_FLTPD,Qupls4_pkg::OP_FLTPQ:
		begin
			instr.opcode = ir[6:0];
			instr.vn = ir.vn;
			instr.rmd = ir.rmd;
			instr.func = ir.func;
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

always_comb vRd = (instr.vn[0] & is_vector) ? (VREGS > 4 ? {1'b0,instr.Rd,3'b00}: {1'b0,instr.Rd,2'b00}) + num_scalar_reg : {3'b0,instr.Rd};
always_comb vRs1 = (instr.vn[1] & is_vector) ? (VREGS > 4 ? {1'b0,instr.Rs1,3'b00} : {1'b0,instr.Rs1,2'b00}) + num_scalar_reg : {3'b0,instr.Rs1};
always_comb vRs2 = (instr.vn[2] & is_vector) ? (VREGS > 4 ? {1'b0,instr.Rs2,3'b00} : {1'b0,instr.Rs2,2'b00}) + num_scalar_reg : {3'b0,instr.Rs2};
always_comb vRs3 = (instr.vn[3] & is_vector) ? (VREGS > 4 ? {1'b0,instr.Rs3,3'b00} : {1'b0,instr.Rs3,2'b00}) + num_scalar_reg : {3'b0,instr.Rs3};
always_comb vRdi = (instr.vn[0] & is_vector);
// Don't increment a constant field.
always_comb vRs1i = (instr.vn[1] & ~instr.ms[0] & is_vector);
always_comb vRs2i = (instr.vn[2] & ~instr.ms[1] & is_vector);
always_comb vRs3i = (instr.vn[3] & ~instr.ms[2] & is_vector);

always_comb
begin
	next_count = 3'd0;
	for (n1 = 0; n1 < UOP_ARRAY_SIZE; n1 = n1 + 1) begin
		next_uop[n1] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
		next_uop[n1].lead = n1==0;
		next_uop[n1].opcode = Qupls4_pkg::OP_NOP;
		next_uop[n1].v = VAL;
	end

	case(ir.opcode)
	Qupls4_pkg::OP_BRK:
		begin
			next_uop[0] = ir;
			next_uop[0].lead = TRUE;
			next_count = 3'd1;
		end
	Qupls4_pkg::OP_MOVMR:
		begin
			if (insert_boi) begin
				kk = 1;
				next_uop[0] = uop_boi;
				if (ir[47:46] > 2'd0) begin
					next_uop[kk] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
					next_uop[kk].opcode = Qupls4_pkg::OP_R3H;
					next_uop[kk].Rd = {9'(thread*40+ir.Rd)};
					next_uop[kk].Rs1 = {9'(thread*40+ir.Rs1)};
					next_uop[kk].func = Qupls4_pkg::FN_MOVE;
					kk = kk + 1;
				end
				if (ir[47:46] > 2'd1) begin
					next_uop[kk] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
					next_uop[kk].opcode = Qupls4_pkg::OP_R3H;
					next_uop[kk].Rd = {9'(thread*40+ir.Rd2)};
					next_uop[kk].Rs1 = {9'(thread*40+ir.Rs2)};
					next_uop[kk].func = Qupls4_pkg::FN_MOVE;
					kk = kk + 1;
				end
				if (ir[47:46] > 2'd2) begin
					next_uop[kk] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
					next_uop[kk].opcode = Qupls4_pkg::OP_R3H;
					next_uop[kk].Rd = {9'(thread*40+ir.Rs3)};
					next_uop[kk].Rs1 = {9'(thread*40+ir.Rs4)};
					next_uop[kk].func = Qupls4_pkg::FN_MOVE;
					kk = kk + 1;
				end
				next_count = kk[3:0];
				next_uop[0].lead = 1'd1;
				next_uop[0].num = 5'd0;
				next_uop[1].num = 5'd1;
				next_uop[2].num = 5'd2;
				next_uop[3].num = 5'd3;
			end
			else begin
				kk = 0;
				if (ir[47:46] > 2'd0) begin
					next_uop[kk] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
					next_uop[kk].opcode = Qupls4_pkg::OP_R3H;
					next_uop[kk].Rd = {9'(thread*40+ir.Rd)};
					next_uop[kk].Rs1 = {9'(thread*40+ir.Rs1)};
					next_uop[kk].func = Qupls4_pkg::FN_MOVE;
					kk = kk + 1;
				end
				if (ir[47:46] > 2'd1) begin
					next_uop[kk] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
					next_uop[kk].opcode = Qupls4_pkg::OP_R3H;
					next_uop[kk].Rd = {9'(thread*40+ir.Rd2)};
					next_uop[kk].Rs1 = {9'(thread*40+ir.Rs2)};
					next_uop[kk].func = Qupls4_pkg::FN_MOVE;
					kk = kk + 1;
				end
				if (ir[47:46] > 2'd2) begin
					next_uop[kk] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
					next_uop[kk].opcode = Qupls4_pkg::OP_R3H;
					next_uop[kk].Rd = {9'(thread*40+ir.Rs3)};
					next_uop[kk].Rs1 = {9'(thread*40+ir.Rs4)};
					next_uop[kk].func = Qupls4_pkg::FN_MOVE;
					kk = kk + 1;
				end
				next_count = kk[3:0];
				next_uop[0].lead = 1'd1;
				next_uop[0].num = 5'd0;
				next_uop[1].num = 5'd1;
				next_uop[2].num = 5'd2;
			end
		end
	Qupls4_pkg::OP_EXTD:
		begin
			if (SUPPORT_VECTOR) begin
				case(instr.op3)
				EX_VSHLV,EX_VSHRV:
					case({VREGS > 4,vlen1[3:0]})
					5'd1:	
						begin
							next_count = 4'd1;
							next_uop[0] = vsins;
							next_uop[0].lead = TRUE;
							next_uop[0].Rd = vRd;
							next_uop[0].Rs1 = vRs1;
							next_uop[0].Rs4 = mot0_reg;
						end
					5'd2:	
						begin
							next_count = 4'd2;
							next_uop[0] = vsins;
							next_uop[0].lead = TRUE;
							next_uop[0].Rd = vRd;
							next_uop[0].Rs1 = vRs1;
							next_uop[0].Rs4 = mot0_reg;
							next_uop[1].num = 5'd1;
							next_uop[1].Rd = vRd + 2'd1;
							next_uop[1].Rs1 = vRs1 + 2'd1;
							next_uop[1].Rs3 = mot0_reg;
							next_uop[1].Rs4 = vsins.Rs4;
						end
					5'd3:	
						begin
							next_count = 4'd3;
							next_uop[0] = vsins;
							next_uop[0].lead = TRUE;
							next_uop[0].Rd = vRd;
							next_uop[0].Rs1 = vRs1;
							next_uop[0].Rs4 = mot0_reg;
							next_uop[1].num = 5'd1;
							next_uop[1].Rd = vRd + 2'd1;
							next_uop[1].Rs1 = vRs1 + 2'd1;
							next_uop[1].Rs3 = mot0_reg;
							next_uop[1].Rs4 = mot0_reg;
							next_uop[2].num = 5'd2;
							next_uop[2].Rd = vRd + 2'd2;
							next_uop[2].Rs1 = vRs1 + 2'd2;
							next_uop[2].Rs3 = mot0_reg;
							next_uop[2].Rs4 = vsins.Rs4;
						end
					5'd4:	
						begin
							next_count = 4'd4;
							next_uop[0] = vsins;
							next_uop[0].lead = TRUE;
							next_uop[0].Rd = vRd;
							next_uop[0].Rs1 = vRs1;
							next_uop[0].Rs4 = mot0_reg;
							next_uop[1].num = 5'd1;
							next_uop[1].Rd = vRd + 2'd1;
							next_uop[1].Rs1 = vRs1 + 2'd1;
							next_uop[1].Rs3 = mot0_reg;
							next_uop[1].Rs4 = mot0_reg;
							next_uop[2].num = 5'd2;
							next_uop[2].Rd = vRd + 2'd2;
							next_uop[2].Rs1 = vRs1 + 2'd2;
							next_uop[2].Rs3 = mot0_reg;
							next_uop[2].Rs4 = mot0_reg;
							next_uop[3].num = 5'd3;
							next_uop[3].Rd = vRd + 2'd3;
							next_uop[3].Rs1 = vRs1 + 2'd3;
							next_uop[3].Rs3 = mot0_reg;
							next_uop[3].Rs4 = vsins.Rs4;
						end
					5'd21:	
						begin
							next_count = 4'd5;
							next_uop[0] = vsins;
							next_uop[0].lead = TRUE;
							next_uop[0].Rd = vRd;
							next_uop[0].Rs1 = vRs1;
							next_uop[0].Rs4 = mot0_reg;
							next_uop[1].num = 5'd1;
							next_uop[1].Rd = vRd + 2'd1;
							next_uop[1].Rs1 = vRs1 + 2'd1;
							next_uop[1].Rs3 = mot0_reg;
							next_uop[1].Rs4 = mot0_reg;
							next_uop[2].num = 5'd2;
							next_uop[2].Rd = vRd + 2'd2;
							next_uop[2].Rs1 = vRs1 + 2'd2;
							next_uop[2].Rs3 = mot0_reg;
							next_uop[2].Rs4 = mot0_reg;
							next_uop[3].num = 5'd3;
							next_uop[3].Rd = vRd + 2'd3;
							next_uop[3].Rs1 = vRs1 + 2'd3;
							next_uop[3].Rs3 = mot0_reg;
							next_uop[3].Rs4 = mot0_reg;
							next_uop[4].num = 5'd4;
							next_uop[4].Rd = vRd + 3'd4;
							next_uop[4].Rs1 = vRs1 + 3'd4;
							next_uop[4].Rs3 = mot0_reg;
							next_uop[4].Rs4 = vsins.Rs4;
						end
					5'd22:	
						begin
							next_count = 4'd6;
							next_uop[0].lead = TRUE;
							next_uop[0].Rd = vRd;
							next_uop[0].Rs1 = vRs1;
							next_uop[0].Rs4 = mot0_reg;
							next_uop[1].num = 5'd1;
							next_uop[1].Rd = vRd + 2'd1;
							next_uop[1].Rs1 = vRs1 + 2'd1;
							next_uop[1].Rs3 = mot0_reg;
							next_uop[1].Rs4 = mot0_reg;
							next_uop[2].num = 5'd2;
							next_uop[2].Rd = vRd + 2'd2;
							next_uop[2].Rs1 = vRs1 + 2'd2;
							next_uop[2].Rs3 = mot0_reg;
							next_uop[2].Rs4 = mot0_reg;
							next_uop[3].num = 5'd3;
							next_uop[3].Rd = vRd + 2'd3;
							next_uop[3].Rs1 = vRs1 + 2'd3;
							next_uop[3].Rs3 = mot0_reg;
							next_uop[3].Rs4 = mot0_reg;
							next_uop[4].num = 5'd4;
							next_uop[4].Rd = vRd + 3'd4;
							next_uop[4].Rs1 = vRs1 + 3'd4;
							next_uop[4].Rs3 = mot0_reg;
							next_uop[4].Rs4 = mot0_reg;
							next_uop[5].num = 5'd5;
							next_uop[5].Rd = vRd + 3'd5;
							next_uop[5].Rs1 = vRs1 + 3'd5;
							next_uop[5].Rs3 = mot0_reg;
							next_uop[5].Rs4 = vsins.Rs4;
						end
					5'd23:	
						begin
							next_count = 4'd7;
							next_uop[0].lead = TRUE;
							next_uop[0].Rd = vRd;
							next_uop[0].Rs1 = vRs1;
							next_uop[0].Rs4 = mot0_reg;
							next_uop[1].num = 5'd1;
							next_uop[1].Rd = vRd + 2'd1;
							next_uop[1].Rs1 = vRs1 + 2'd1;
							next_uop[1].Rs3 = mot0_reg;
							next_uop[1].Rs4 = mot0_reg;
							next_uop[2].num = 5'd2;
							next_uop[2].Rd = vRd + 2'd2;
							next_uop[2].Rs1 = vRs1 + 2'd2;
							next_uop[2].Rs3 = mot0_reg;
							next_uop[2].Rs4 = mot0_reg;
							next_uop[3].num = 5'd3;
							next_uop[3].Rd = vRd + 2'd3;
							next_uop[3].Rs1 = vRs1 + 2'd3;
							next_uop[3].Rs3 = mot0_reg;
							next_uop[3].Rs4 = mot0_reg;
							next_uop[4].num = 5'd4;
							next_uop[4].Rd = vRd + 3'd4;
							next_uop[4].Rs1 = vRs1 + 3'd4;
							next_uop[4].Rs3 = mot0_reg;
							next_uop[4].Rs4 = mot0_reg;
							next_uop[5].num = 5'd5;
							next_uop[5].Rd = vRd + 3'd5;
							next_uop[5].Rs1 = vRs1 + 3'd5;
							next_uop[5].Rs3 = mot0_reg;
							next_uop[5].Rs4 = mot0_reg;
							next_uop[6].num = 5'd6;
							next_uop[6].Rd = vRd + 3'd6;
							next_uop[6].Rs1 = vRs1 + 3'd6;
							next_uop[6].Rs3 = mot0_reg;
							next_uop[6].Rs4 = vsins.Rs4;
						end
					5'd24:
						begin
							next_count = 4'd8;
							next_uop[0].lead = TRUE;
							next_uop[0].Rd = vRd;
							next_uop[0].Rs1 = vRs1;
							next_uop[0].Rs4 = mot0_reg;
							next_uop[1].num = 5'd1;
							next_uop[1].Rd = vRd + 2'd1;
							next_uop[1].Rs1 = vRs1 + 2'd1;
							next_uop[1].Rs3 = mot0_reg;
							next_uop[1].Rs4 = mot0_reg;
							next_uop[2].num = 5'd2;
							next_uop[2].Rd = vRd + 2'd2;
							next_uop[2].Rs1 = vRs1 + 2'd2;
							next_uop[2].Rs3 = mot0_reg;
							next_uop[2].Rs4 = mot0_reg;
							next_uop[3].num = 5'd3;
							next_uop[3].Rd = vRd + 2'd3;
							next_uop[3].Rs1 = vRs1 + 2'd3;
							next_uop[3].Rs3 = mot0_reg;
							next_uop[3].Rs4 = mot0_reg;
							next_uop[4].num = 5'd4;
							next_uop[4].Rd = vRd + 3'd4;
							next_uop[4].Rs1 = vRs1 + 3'd4;
							next_uop[4].Rs3 = mot0_reg;
							next_uop[4].Rs4 = mot0_reg;
							next_uop[5].num = 5'd5;
							next_uop[5].Rd = vRd + 3'd5;
							next_uop[5].Rs1 = vRs1 + 3'd5;
							next_uop[5].Rs3 = mot0_reg;
							next_uop[5].Rs4 = mot0_reg;
							next_uop[6].num = 5'd6;
							next_uop[6].Rd = vRd + 3'd6;
							next_uop[6].Rs1 = vRs1 + 3'd6;
							next_uop[6].Rs3 = mot0_reg;
							next_uop[6].Rs4 = mot0_reg;
							next_uop[7].num = 5'd7;
							next_uop[7].Rd = vRd + 3'd7;
							next_uop[7].Rs1 = vRs1 + 3'd7;
							next_uop[7].Rs3 = mot0_reg;
							next_uop[7].Rs4 = vsins.Rs4;
						end
					default:
						begin
							next_count = 4'd1;
							next_uop[0] = nopi;
						end
					endcase
				default:
					begin
						next_count = 4'd1;
						next_uop[0] = uop0;
					end
				endcase
			end
			else begin
				next_count = 4'd1;
				next_uop[0] = uop0;
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
			next_count = 4'd1;
			next_uop[0] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[0].v = VAL;
			next_uop[0].lead = TRUE;
			next_uop[0].num = 5'd0;
			next_uop[0].opcode = instr.opcode;
			next_uop[0].Rd = vRd;
			next_uop[0].Rs1 = vRs1;
			next_uop[0].Rs2 = vRs2;
			next_uop[0].Rs3 = vRs3;
			next_uop[0].op3 = instr.op3;
			next_uop[0].ms = instr.ms;
			next_uop[0].func = instr.func;
			     end
			5'd2:
				begin
			next_count = 4'd2;
			next_uop[0] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[0].v = VAL;
			next_uop[0].lead = TRUE;
			next_uop[0].num = 5'd0;
			next_uop[0].opcode = instr.opcode;
			next_uop[0].Rd = vRd;
			next_uop[0].Rs1 = vRs1;
			next_uop[0].Rs2 = vRs2;
			next_uop[0].Rs3 = vRs3;
			next_uop[0].op3 = instr.op3;
			next_uop[0].ms = instr.ms;
			next_uop[0].func = instr.func;
			next_uop[1] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[1].v = VAL;
			next_uop[1].lead = FALSE;
			next_uop[1].num = 5'd1;
			next_uop[1].opcode = instr.opcode;
			next_uop[1].Rd = vRd+vRdi;
			next_uop[1].Rs1 = vRs1+vRs1i;
			next_uop[1].Rs2 = vRs2+vRs2i;
			next_uop[1].Rs3 = vRs3+vRs3i;
			next_uop[1].op3 = instr.op3;
			next_uop[1].ms = instr.ms;
			next_uop[1].func = instr.func;
				end
			5'd3:
				begin
			next_count = 4'd3;
			next_uop[0] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[0].v = VAL;
			next_uop[0].lead = TRUE;
			next_uop[0].num = 5'd0;
			next_uop[0].opcode = instr.opcode;
			next_uop[0].Rd = vRd;
			next_uop[0].Rs1 = vRs1;
			next_uop[0].Rs2 = vRs2;
			next_uop[0].Rs3 = vRs3;
			next_uop[0].op3 = instr.op3;
			next_uop[0].ms = instr.ms;
			next_uop[0].func = instr.func;
			next_uop[1] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[1].v = VAL;
			next_uop[1].lead = FALSE;
			next_uop[1].num = 5'd1;
			next_uop[1].opcode = instr.opcode;
			next_uop[1].Rd = vRd+vRdi;
			next_uop[1].Rs1 = vRs1+vRs1i;
			next_uop[1].Rs2 = vRs2+vRs2i;
			next_uop[1].Rs3 = vRs3+vRs3i;
			next_uop[1].op3 = instr.op3;
			next_uop[1].ms = instr.ms;
			next_uop[1].func = instr.func;
			next_uop[2] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[2].v = VAL;
			next_uop[2].lead = FALSE;
			next_uop[2].num = 5'd2;
			next_uop[2].opcode = instr.opcode;
			next_uop[2].Rd = vRd+(vRdi?9'd2:9'd0);
			next_uop[2].Rs1 = vRs1+(vRs1i?9'd2:9'd0);
			next_uop[2].Rs2 = vRs2+(vRs2i?9'd2:9'd0);
			next_uop[2].Rs3 = vRs3+(vRs3i?9'd2:9'd0);
			next_uop[2].op3 = instr.op3;
			next_uop[2].ms = instr.ms;
			next_uop[2].func = instr.func;
				end
			5'd4:
				begin
			next_count = 4'd4;
			next_uop[0] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[0].v = VAL;
			next_uop[0].lead = TRUE;
			next_uop[0].num = 5'd0;
			next_uop[0].opcode = instr.opcode;
			next_uop[0].Rd = vRd;
			next_uop[0].Rs1 = vRs1;
			next_uop[0].Rs2 = vRs2;
			next_uop[0].Rs3 = vRs3;
			next_uop[0].op3 = instr.op3;
			next_uop[0].ms = instr.ms;
			next_uop[0].func = instr.func;
			next_uop[1] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[1].v = VAL;
			next_uop[1].lead = FALSE;
			next_uop[1].num = 5'd1;
			next_uop[1].opcode = instr.opcode;
			next_uop[1].Rd = vRd+vRdi;
			next_uop[1].Rs1 = vRs1+vRs1i;
			next_uop[1].Rs2 = vRs2+vRs2i;
			next_uop[1].Rs3 = vRs3+vRs3i;
			next_uop[1].op3 = instr.op3;
			next_uop[1].ms = instr.ms;
			next_uop[1].func = instr.func;
			next_uop[2] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[2].v = VAL;
			next_uop[2].lead = FALSE;
			next_uop[2].num = 5'd2;
			next_uop[2].opcode = instr.opcode;
			next_uop[2].Rd = vRd+(vRdi?9'd2:9'd0);
			next_uop[2].Rs1 = vRs1+(vRs1i?9'd2:9'd0);
			next_uop[2].Rs2 = vRs2+(vRs2i?9'd2:9'd0);
			next_uop[2].Rs3 = vRs3+(vRs3i?9'd2:9'd0);
			next_uop[2].op3 = instr.op3;
			next_uop[2].ms = instr.ms;
			next_uop[2].func = instr.func;
			next_uop[3] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[3].v = VAL;
			next_uop[3].lead = FALSE;
			next_uop[3].num = 5'd3;
			next_uop[3].opcode = instr.opcode;
			next_uop[3].Rd = vRd+(vRdi?9'd3:9'd0);
			next_uop[3].Rs1 = vRs1+(vRs1i?9'd3:9'd0);
			next_uop[3].Rs2 = vRs2+(vRs2i?9'd3:9'd0);
			next_uop[3].Rs3 = vRs3+(vRs3i?9'd3:9'd0);
			next_uop[3].op3 = instr.op3;
			next_uop[3].ms = instr.ms;
			next_uop[3].func = instr.func;
				end
			5'd21:
				begin
			next_count = 4'd5;
			next_uop[0] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[0].v = VAL;
			next_uop[0].lead = TRUE;
			next_uop[0].num = 5'd0;
			next_uop[0].opcode = instr.opcode;
			next_uop[0].Rd = vRd;
			next_uop[0].Rs1 = vRs1;
			next_uop[0].Rs2 = vRs2;
			next_uop[0].Rs3 = vRs3;
			next_uop[0].op3 = instr.op3;
			next_uop[0].ms = instr.ms;
			next_uop[0].func = instr.func;
			next_uop[1] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[1].v = VAL;
			next_uop[1].lead = FALSE;
			next_uop[1].num = 5'd1;
			next_uop[1].opcode = instr.opcode;
			next_uop[1].Rd = vRd+vRdi;
			next_uop[1].Rs1 = vRs1+vRs1i;
			next_uop[1].Rs2 = vRs2+vRs2i;
			next_uop[1].Rs3 = vRs3+vRs3i;
			next_uop[1].op3 = instr.op3;
			next_uop[1].ms = instr.ms;
			next_uop[1].func = instr.func;
			next_uop[2] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[2].v = VAL;
			next_uop[2].lead = FALSE;
			next_uop[2].num = 5'd2;
			next_uop[2].opcode = instr.opcode;
			next_uop[2].Rd = vRd+(vRdi?9'd2:9'd0);
			next_uop[2].Rs1 = vRs1+(vRs1i?9'd2:9'd0);
			next_uop[2].Rs2 = vRs2+(vRs2i?9'd2:9'd0);
			next_uop[2].Rs3 = vRs3+(vRs3i?9'd2:9'd0);
			next_uop[2].op3 = instr.op3;
			next_uop[2].ms = instr.ms;
			next_uop[2].func = instr.func;
			next_uop[3] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[3].v = VAL;
			next_uop[3].lead = FALSE;
			next_uop[3].num = 5'd3;
			next_uop[3].opcode = instr.opcode;
			next_uop[3].Rd = vRd+(vRdi?9'd3:9'd0);
			next_uop[3].Rs1 = vRs1+(vRs1i?9'd3:9'd0);
			next_uop[3].Rs2 = vRs2+(vRs2i?9'd3:9'd0);
			next_uop[3].Rs3 = vRs3+(vRs3i?9'd3:9'd0);
			next_uop[3].op3 = instr.op3;
			next_uop[3].ms = instr.ms;
			next_uop[3].func = instr.func;
			next_uop[4] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[4].v = VAL;
			next_uop[4].lead = FALSE;
			next_uop[4].num = 5'd4;
			next_uop[4].opcode = instr.opcode;
			next_uop[4].Rd = vRd+(vRdi?9'd4:9'd0);
			next_uop[4].Rs1 = vRs1+(vRs1i?9'd4:9'd0);
			next_uop[4].Rs2 = vRs2+(vRs2i?9'd4:9'd0);
			next_uop[4].Rs3 = vRs3+(vRs3i?9'd4:9'd0);
			next_uop[4].op3 = instr.op3;
			next_uop[4].ms = instr.ms;
			next_uop[4].func = instr.func;
				end
			5'd22:
				begin
			next_count = 4'd6;
			next_uop[0] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[0].v = VAL;
			next_uop[0].lead = TRUE;
			next_uop[0].num = 5'd0;
			next_uop[0].opcode = instr.opcode;
			next_uop[0].Rd = vRd;
			next_uop[0].Rs1 = vRs1;
			next_uop[0].Rs2 = vRs2;
			next_uop[0].Rs3 = vRs3;
			next_uop[0].op3 = instr.op3;
			next_uop[0].ms = instr.ms;
			next_uop[0].func = instr.func;
			next_uop[1] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[1].v = VAL;
			next_uop[1].lead = FALSE;
			next_uop[1].num = 5'd1;
			next_uop[1].opcode = instr.opcode;
			next_uop[1].Rd = vRd+vRdi;
			next_uop[1].Rs1 = vRs1+vRs1i;
			next_uop[1].Rs2 = vRs2+vRs2i;
			next_uop[1].Rs3 = vRs3+vRs3i;
			next_uop[1].op3 = instr.op3;
			next_uop[1].ms = instr.ms;
			next_uop[1].func = instr.func;
			next_uop[2] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[2].v = VAL;
			next_uop[2].lead = FALSE;
			next_uop[2].num = 5'd2;
			next_uop[2].opcode = instr.opcode;
			next_uop[2].Rd = vRd+(vRdi?9'd2:9'd0);
			next_uop[2].Rs1 = vRs1+(vRs1i?9'd2:9'd0);
			next_uop[2].Rs2 = vRs2+(vRs2i?9'd2:9'd0);
			next_uop[2].Rs3 = vRs3+(vRs3i?9'd2:9'd0);
			next_uop[2].op3 = instr.op3;
			next_uop[2].ms = instr.ms;
			next_uop[2].func = instr.func;
			next_uop[3] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[3].v = VAL;
			next_uop[3].lead = FALSE;
			next_uop[3].num = 5'd3;
			next_uop[3].opcode = instr.opcode;
			next_uop[3].Rd = vRd+(vRdi?9'd3:9'd0);
			next_uop[3].Rs1 = vRs1+(vRs1i?9'd3:9'd0);
			next_uop[3].Rs2 = vRs2+(vRs2i?9'd3:9'd0);
			next_uop[3].Rs3 = vRs3+(vRs3i?9'd3:9'd0);
			next_uop[3].op3 = instr.op3;
			next_uop[3].ms = instr.ms;
			next_uop[3].func = instr.func;
			next_uop[4] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[4].v = VAL;
			next_uop[4].lead = FALSE;
			next_uop[4].num = 5'd4;
			next_uop[4].opcode = instr.opcode;
			next_uop[4].Rd = vRd+(vRdi?9'd4:9'd0);
			next_uop[4].Rs1 = vRs1+(vRs1i?9'd4:9'd0);
			next_uop[4].Rs2 = vRs2+(vRs2i?9'd4:9'd0);
			next_uop[4].Rs3 = vRs3+(vRs3i?9'd4:9'd0);
			next_uop[4].op3 = instr.op3;
			next_uop[4].ms = instr.ms;
			next_uop[4].func = instr.func;
			next_uop[5] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[5].v = VAL;
			next_uop[5].lead = FALSE;
			next_uop[5].num = 5'd5;
			next_uop[5].opcode = instr.opcode;
			next_uop[5].Rd = vRd+(vRdi?9'd5:9'd0);
			next_uop[5].Rs1 = vRs1+(vRs1i?9'd5:9'd0);
			next_uop[5].Rs2 = vRs2+(vRs2i?9'd5:9'd0);
			next_uop[5].Rs3 = vRs3+(vRs3i?9'd5:9'd0);
			next_uop[5].op3 = instr.op3;
			next_uop[5].ms = instr.ms;
			next_uop[5].func = instr.func;
				end
			5'd23:
				begin
			next_count = 4'd7;
			next_uop[0] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[0].v = VAL;
			next_uop[0].lead = TRUE;
			next_uop[0].num = 5'd0;
			next_uop[0].opcode = instr.opcode;
			next_uop[0].Rd = vRd;
			next_uop[0].Rs1 = vRs1;
			next_uop[0].Rs2 = vRs2;
			next_uop[0].Rs3 = vRs3;
			next_uop[0].op3 = instr.op3;
			next_uop[0].ms = instr.ms;
			next_uop[0].func = instr.func;
			next_uop[1] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[1].v = VAL;
			next_uop[1].lead = FALSE;
			next_uop[1].num = 5'd1;
			next_uop[1].opcode = instr.opcode;
			next_uop[1].Rd = vRd+vRdi;
			next_uop[1].Rs1 = vRs1+vRs1i;
			next_uop[1].Rs2 = vRs2+vRs2i;
			next_uop[1].Rs3 = vRs3+vRs3i;
			next_uop[1].op3 = instr.op3;
			next_uop[1].ms = instr.ms;
			next_uop[1].func = instr.func;
			next_uop[2] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[2].v = VAL;
			next_uop[2].lead = FALSE;
			next_uop[2].num = 5'd2;
			next_uop[2].opcode = instr.opcode;
			next_uop[2].Rd = vRd+(vRdi?9'd2:9'd0);
			next_uop[2].Rs1 = vRs1+(vRs1i?9'd2:9'd0);
			next_uop[2].Rs2 = vRs2+(vRs2i?9'd2:9'd0);
			next_uop[2].Rs3 = vRs3+(vRs3i?9'd2:9'd0);
			next_uop[2].op3 = instr.op3;
			next_uop[2].ms = instr.ms;
			next_uop[2].func = instr.func;
			next_uop[3] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[3].v = VAL;
			next_uop[3].lead = FALSE;
			next_uop[3].num = 5'd3;
			next_uop[3].opcode = instr.opcode;
			next_uop[3].Rd = vRd+(vRdi?9'd3:9'd0);
			next_uop[3].Rs1 = vRs1+(vRs1i?9'd3:9'd0);
			next_uop[3].Rs2 = vRs2+(vRs2i?9'd3:9'd0);
			next_uop[3].Rs3 = vRs3+(vRs3i?9'd3:9'd0);
			next_uop[3].op3 = instr.op3;
			next_uop[3].ms = instr.ms;
			next_uop[3].func = instr.func;
			next_uop[4] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[4].v = VAL;
			next_uop[4].lead = FALSE;
			next_uop[4].num = 5'd4;
			next_uop[4].opcode = instr.opcode;
			next_uop[4].Rd = vRd+(vRdi?9'd4:9'd0);
			next_uop[4].Rs1 = vRs1+(vRs1i?9'd4:9'd0);
			next_uop[4].Rs2 = vRs2+(vRs2i?9'd4:9'd0);
			next_uop[4].Rs3 = vRs3+(vRs3i?9'd4:9'd0);
			next_uop[4].op3 = instr.op3;
			next_uop[4].ms = instr.ms;
			next_uop[4].func = instr.func;
			next_uop[5] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[5].v = VAL;
			next_uop[5].lead = FALSE;
			next_uop[5].num = 5'd5;
			next_uop[5].opcode = instr.opcode;
			next_uop[5].Rd = vRd+(vRdi?9'd5:9'd0);
			next_uop[5].Rs1 = vRs1+(vRs1i?9'd5:9'd0);
			next_uop[5].Rs2 = vRs2+(vRs2i?9'd5:9'd0);
			next_uop[5].Rs3 = vRs3+(vRs3i?9'd5:9'd0);
			next_uop[5].op3 = instr.op3;
			next_uop[5].ms = instr.ms;
			next_uop[5].func = instr.func;
			next_uop[6] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[6].v = VAL;
			next_uop[6].lead = FALSE;
			next_uop[6].num = 5'd6;
			next_uop[6].opcode = instr.opcode;
			next_uop[6].Rd = vRd+(vRdi?9'd6:9'd0);
			next_uop[6].Rs1 = vRs1+(vRs1i?9'd6:9'd0);
			next_uop[6].Rs2 = vRs2+(vRs2i?9'd6:9'd0);
			next_uop[6].Rs3 = vRs3+(vRs3i?9'd6:9'd0);
			next_uop[6].op3 = instr.op3;
			next_uop[6].ms = instr.ms;
			next_uop[6].func = instr.func;
				end
			5'd24:
				begin
			next_count = 4'd8;
			next_uop[0] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[0].v = VAL;
			next_uop[0].lead = TRUE;
			next_uop[0].num = 5'd0;
			next_uop[0].opcode = instr.opcode;
			next_uop[0].Rd = vRd;
			next_uop[0].Rs1 = vRs1;
			next_uop[0].Rs2 = vRs2;
			next_uop[0].Rs3 = vRs3;
			next_uop[0].op3 = instr.op3;
			next_uop[0].ms = instr.ms;
			next_uop[0].func = instr.func;
			next_uop[1] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[1].v = VAL;
			next_uop[1].lead = FALSE;
			next_uop[1].num = 5'd1;
			next_uop[1].opcode = instr.opcode;
			next_uop[1].Rd = vRd+vRdi;
			next_uop[1].Rs1 = vRs1+vRs1i;
			next_uop[1].Rs2 = vRs2+vRs2i;
			next_uop[1].Rs3 = vRs3+vRs3i;
			next_uop[1].op3 = instr.op3;
			next_uop[1].ms = instr.ms;
			next_uop[1].func = instr.func;
			next_uop[2] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[2].v = VAL;
			next_uop[2].lead = FALSE;
			next_uop[2].num = 5'd2;
			next_uop[2].opcode = instr.opcode;
			next_uop[2].Rd = vRd+(vRdi?9'd2:9'd0);
			next_uop[2].Rs1 = vRs1+(vRs1i?9'd2:9'd0);
			next_uop[2].Rs2 = vRs2+(vRs2i?9'd2:9'd0);
			next_uop[2].Rs3 = vRs3+(vRs3i?9'd2:9'd0);
			next_uop[2].op3 = instr.op3;
			next_uop[2].ms = instr.ms;
			next_uop[2].func = instr.func;
			next_uop[3] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[3].v = VAL;
			next_uop[3].lead = FALSE;
			next_uop[3].num = 5'd3;
			next_uop[3].opcode = instr.opcode;
			next_uop[3].Rd = vRd+(vRdi?9'd3:9'd0);
			next_uop[3].Rs1 = vRs1+(vRs1i?9'd3:9'd0);
			next_uop[3].Rs2 = vRs2+(vRs2i?9'd3:9'd0);
			next_uop[3].Rs3 = vRs3+(vRs3i?9'd3:9'd0);
			next_uop[3].op3 = instr.op3;
			next_uop[3].ms = instr.ms;
			next_uop[3].func = instr.func;
			next_uop[4] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[4].v = VAL;
			next_uop[4].lead = FALSE;
			next_uop[4].num = 5'd4;
			next_uop[4].opcode = instr.opcode;
			next_uop[4].Rd = vRd+(vRdi?9'd4:9'd0);
			next_uop[4].Rs1 = vRs1+(vRs1i?9'd4:9'd0);
			next_uop[4].Rs2 = vRs2+(vRs2i?9'd4:9'd0);
			next_uop[4].Rs3 = vRs3+(vRs3i?9'd4:9'd0);
			next_uop[4].op3 = instr.op3;
			next_uop[4].ms = instr.ms;
			next_uop[4].func = instr.func;
			next_uop[5] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[5].v = VAL;
			next_uop[5].lead = FALSE;
			next_uop[5].num = 5'd5;
			next_uop[5].opcode = instr.opcode;
			next_uop[5].Rd = vRd+(vRdi?9'd5:9'd0);
			next_uop[5].Rs1 = vRs1+(vRs1i?9'd5:9'd0);
			next_uop[5].Rs2 = vRs2+(vRs2i?9'd5:9'd0);
			next_uop[5].Rs3 = vRs3+(vRs3i?9'd5:9'd0);
			next_uop[5].op3 = instr.op3;
			next_uop[5].ms = instr.ms;
			next_uop[5].func = instr.func;
			next_uop[6] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[6].v = VAL;
			next_uop[6].lead = FALSE;
			next_uop[6].num = 5'd6;
			next_uop[6].opcode = instr.opcode;
			next_uop[6].Rd = vRd+(vRdi?9'd6:9'd0);
			next_uop[6].Rs1 = vRs1+(vRs1i?9'd6:9'd0);
			next_uop[6].Rs2 = vRs2+(vRs2i?9'd6:9'd0);
			next_uop[6].Rs3 = vRs3+(vRs3i?9'd6:9'd0);
			next_uop[6].op3 = instr.op3;
			next_uop[6].ms = instr.ms;
			next_uop[6].func = instr.func;
			next_uop[7] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[7].v = VAL;
			next_uop[7].lead = FALSE;
			next_uop[7].num = 5'd7;
			next_uop[7].opcode = instr.opcode;
			next_uop[7].Rd = vRd+(vRdi?9'd7:9'd0);
			next_uop[7].Rs1 = vRs1+(vRs1i?9'd7:9'd0);
			next_uop[7].Rs2 = vRs2+(vRs2i?9'd7:9'd0);
			next_uop[7].Rs3 = vRs3+(vRs3i?9'd7:9'd0);
			next_uop[7].op3 = instr.op3;
			next_uop[7].ms = instr.ms;
			next_uop[7].func = instr.func;
				end
			default:	
				begin
			next_count = 4'd1;
			next_uop[0] = nopi;
				end
			endcase
		end
		// Should really exception here.
		else begin
			next_count = 4'd1;
			next_uop[0] = nopi;
		end

	Qupls4_pkg::OP_LDV,Qupls4_pkg::OP_STV:
		if (SUPPORT_VECTOR) begin
			case({VREGS > 4,vlen1[3:0]})
			5'd1:
				begin
			next_count = 4'd1;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
				end
			5'd2:
				begin
			next_count = 4'd2;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rd = vls.Rd + 2'd1;
			next_uop[1].imm = vls.imm + 6'd8;
				end
			5'd3:
				begin
			next_count = 4'd3;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rd = vls.Rd + 2'd1;
			next_uop[1].imm = vls.imm + 6'd8;
			next_uop[2] = vls;
			next_uop[2].num = 5'd2;
			next_uop[2].Rd = vls.Rd + 2'd2;
			next_uop[2].imm = vls.imm + 6'd16;
				end
			5'd4:
				begin
			next_count = 4'd4;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rd = vls.Rd + 2'd1;
			next_uop[1].imm = vls.imm + 6'd8;
			next_uop[2] = vls;
			next_uop[2].num = 5'd2;
			next_uop[2].Rd = vls.Rd + 2'd2;
			next_uop[2].imm = vls.imm + 6'd16;
			next_uop[3] = vls;
			next_uop[3].num = 5'd3;
			next_uop[3].Rd = vls.Rd + 2'd3;
			next_uop[3].imm = vls.imm + 6'd24;
				end
			5'd21:
				begin
			next_count = 4'd5;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rd = vls.Rd + 2'd1;
			next_uop[1].imm = vls.imm + 6'd8;
			next_uop[2] = vls;
			next_uop[2].num = 5'd2;
			next_uop[2].Rd = vls.Rd + 2'd2;
			next_uop[2].imm = vls.imm + 6'd16;
			next_uop[3] = vls;
			next_uop[3].num = 5'd3;
			next_uop[3].Rd = vls.Rd + 2'd3;
			next_uop[3].imm = vls.imm + 6'd24;
			next_uop[4] = vls;
			next_uop[4].num = 5'd4;
			next_uop[4].Rd = vls.Rd + 3'd4;
			next_uop[4].imm = vls.imm + 6'd32;
				end
			5'd22:
				begin
			next_count = 4'd6;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rd = vls.Rd + 2'd1;
			next_uop[1].imm = vls.imm + 6'd8;
			next_uop[2] = vls;
			next_uop[2].num = 5'd2;
			next_uop[2].Rd = vls.Rd + 2'd2;
			next_uop[2].imm = vls.imm + 6'd16;
			next_uop[3] = vls;
			next_uop[3].num = 5'd3;
			next_uop[3].Rd = vls.Rd + 2'd3;
			next_uop[3].imm = vls.imm + 6'd24;
			next_uop[4] = vls;
			next_uop[4].num = 5'd4;
			next_uop[4].Rd = vls.Rd + 3'd4;
			next_uop[4].imm = vls.imm + 6'd32;
			next_uop[5] = vls;
			next_uop[5].num = 5'd5;
			next_uop[5].Rd = vls.Rd + 3'd5;
			next_uop[5].imm = vls.imm + 6'd40;
				end
			5'd23:
				begin
			next_count = 4'd7;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rd = vls.Rd + 2'd1;
			next_uop[1].imm = vls.imm + 6'd8;
			next_uop[2] = vls;
			next_uop[2].num = 5'd2;
			next_uop[2].Rd = vls.Rd + 2'd2;
			next_uop[2].imm = vls.imm + 6'd16;
			next_uop[3] = vls;
			next_uop[3].num = 5'd3;
			next_uop[3].Rd = vls.Rd + 2'd3;
			next_uop[3].imm = vls.imm + 6'd24;
			next_uop[4] = vls;
			next_uop[4].num = 5'd4;
			next_uop[4].Rd = vls.Rd + 3'd4;
			next_uop[4].imm = vls.imm + 6'd32;
			next_uop[5] = vls;
			next_uop[5].num = 5'd5;
			next_uop[5].Rd = vls.Rd + 3'd5;
			next_uop[5].imm = vls.imm + 6'd40;
			next_uop[6] = vls;
			next_uop[6].num = 5'd6;
			next_uop[6].Rd = vls.Rd + 3'd6;
			next_uop[6].imm = vls.imm + 6'd48;
				end
			5'd24:
				begin
			next_count = 4'd8;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rd = vls.Rd + 2'd1;
			next_uop[1].imm = vls.imm + 6'd8;
			next_uop[2] = vls;
			next_uop[2].num = 5'd2;
			next_uop[2].Rd = vls.Rd + 2'd2;
			next_uop[2].imm = vls.imm + 6'd16;
			next_uop[3] = vls;
			next_uop[3].num = 5'd3;
			next_uop[3].Rd = vls.Rd + 2'd3;
			next_uop[3].imm = vls.imm + 6'd24;
			next_uop[4] = vls;
			next_uop[4].num = 5'd4;
			next_uop[4].Rd = vls.Rd + 3'd4;
			next_uop[4].imm = vls.imm + 6'd32;
			next_uop[5] = vls;
			next_uop[5].num = 5'd5;
			next_uop[5].Rd = vls.Rd + 3'd5;
			next_uop[5].imm = vls.imm + 6'd40;
			next_uop[6] = vls;
			next_uop[6].num = 5'd6;
			next_uop[6].Rd = vls.Rd + 3'd6;
			next_uop[6].imm = vls.imm + 6'd48;
			next_uop[7] = vls;
			next_uop[7].num = 5'd7;
			next_uop[7].Rd = vls.Rd + 3'd7;
			next_uop[7].imm = vls.imm + 6'd56;
				end
			default:	
				begin
			next_count = 4'd1;
			next_uop[0] = nopi;
				end
			endcase
		end
		// Should really exception here.
		else begin
			next_count = 4'd1;
			next_uop[0] = nopi;
		end

	Qupls4_pkg::OP_LDVN,Qupls4_pkg::OP_STVN:
		if (SUPPORT_VECTOR) begin
			case({VREGS > 4,vlen1[3:0]})
			5'd1:
				begin
			next_count = 4'd1;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
				end
			5'd2:
				begin
			next_count = 4'd2;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rd = vls.Rd + 2'd1;
			next_uop[1].Rs2 = vls.Rs2 + 2'd1;
				end
			5'd3:
				begin
			next_count = 4'd3;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rd = vls.Rd + 2'd1;
			next_uop[1].Rs2 = vls.Rs2 + 2'd1;
			next_uop[2] = vls;
			next_uop[2].num = 5'd2;
			next_uop[2].Rd = vls.Rd + 2'd2;
			next_uop[2].Rs2 = vls.Rs2 + 2'd2;
				end
			5'd4:
				begin
			next_count = 4'd4;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rd = vls.Rd + 2'd1;
			next_uop[1].Rs2 = vls.Rs2 + 2'd1;
			next_uop[2] = vls;
			next_uop[2].num = 5'd2;
			next_uop[2].Rd = vls.Rd + 2'd2;
			next_uop[2].Rs2 = vls.Rs2 + 2'd2;
			next_uop[3] = vls;
			next_uop[3].num = 5'd3;
			next_uop[3].Rd = vls.Rd + 2'd3;
			next_uop[3].Rs2 = vls.Rs2 + 2'd3;
				end
			5'd21:
				begin
			next_count = 4'd5;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rd = vls.Rd + 2'd1;
			next_uop[1].Rs2 = vls.Rs2 + 2'd1;
			next_uop[2] = vls;
			next_uop[2].num = 5'd2;
			next_uop[2].Rd = vls.Rd + 2'd2;
			next_uop[2].Rs2 = vls.Rs2 + 2'd2;
			next_uop[3] = vls;
			next_uop[3].num = 5'd3;
			next_uop[3].Rd = vls.Rd + 2'd3;
			next_uop[3].Rs2 = vls.Rs2 + 2'd3;
			next_uop[4] = vls;
			next_uop[4].num = 5'd4;
			next_uop[4].Rd = vls.Rd + 4'd4;
			next_uop[4].Rs2 = vls.Rs2 + 4'd4;
				end
			5'd22:
				begin
			next_count = 4'd6;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rd = vls.Rd + 2'd1;
			next_uop[1].Rs2 = vls.Rs2 + 2'd1;
			next_uop[2] = vls;
			next_uop[2].num = 5'd2;
			next_uop[2].Rd = vls.Rd + 2'd2;
			next_uop[2].Rs2 = vls.Rs2 + 2'd2;
			next_uop[3] = vls;
			next_uop[3].num = 5'd3;
			next_uop[3].Rd = vls.Rd + 2'd3;
			next_uop[3].Rs2 = vls.Rs2 + 2'd3;
			next_uop[4] = vls;
			next_uop[4].num = 5'd4;
			next_uop[4].Rd = vls.Rd + 4'd4;
			next_uop[4].Rs2 = vls.Rs2 + 4'd4;
			next_uop[5] = vls;
			next_uop[5].num = 5'd5;
			next_uop[5].Rd = vls.Rd + 4'd5;
			next_uop[5].Rs2 = vls.Rs2 + 4'd5;
				end
			5'd23:
				begin
			next_count = 4'd7;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rd = vls.Rd + 2'd1;
			next_uop[1].Rs2 = vls.Rs2 + 2'd1;
			next_uop[2] = vls;
			next_uop[2].num = 5'd2;
			next_uop[2].Rd = vls.Rd + 2'd2;
			next_uop[2].Rs2 = vls.Rs2 + 2'd2;
			next_uop[3] = vls;
			next_uop[3].num = 5'd3;
			next_uop[3].Rd = vls.Rd + 2'd3;
			next_uop[3].Rs2 = vls.Rs2 + 2'd3;
			next_uop[4] = vls;
			next_uop[4].num = 5'd4;
			next_uop[4].Rd = vls.Rd + 4'd4;
			next_uop[4].Rs2 = vls.Rs2 + 4'd4;
			next_uop[5] = vls;
			next_uop[5].num = 5'd5;
			next_uop[5].Rd = vls.Rd + 4'd5;
			next_uop[5].Rs2 = vls.Rs2 + 4'd5;
			next_uop[6] = vls;
			next_uop[6].num = 5'd6;
			next_uop[6].Rd = vls.Rd + 4'd6;
			next_uop[6].Rs2 = vls.Rs2 + 4'd6;
				end
			5'd24:
				begin
			next_count = 4'd8;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rd = vls.Rd + 2'd1;
			next_uop[1].Rs2 = vls.Rs2 + 2'd1;
			next_uop[2] = vls;
			next_uop[2].num = 5'd2;
			next_uop[2].Rd = vls.Rd + 2'd2;
			next_uop[2].Rs2 = vls.Rs2 + 2'd2;
			next_uop[3] = vls;
			next_uop[3].num = 5'd3;
			next_uop[3].Rd = vls.Rd + 2'd3;
			next_uop[3].Rs2 = vls.Rs2 + 2'd3;
			next_uop[4] = vls;
			next_uop[4].num = 5'd4;
			next_uop[4].Rd = vls.Rd + 4'd4;
			next_uop[4].Rs2 = vls.Rs2 + 4'd4;
			next_uop[5] = vls;
			next_uop[5].num = 5'd5;
			next_uop[5].Rd = vls.Rd + 4'd5;
			next_uop[5].Rs2 = vls.Rs2 + 4'd5;
			next_uop[6] = vls;
			next_uop[6].num = 5'd6;
			next_uop[6].Rd = vls.Rd + 4'd6;
			next_uop[6].Rs2 = vls.Rs2 + 4'd6;
			next_uop[7] = vls;
			next_uop[7].num = 5'd7;
			next_uop[7].Rd = vls.Rd + 4'd7;
			next_uop[7].Rs2 = vls.Rs2 + 4'd7;
				end
			default:	
				begin
			next_count = 4'd1;
			next_uop[0] = nopi;
				end
			endcase
		end
		// Should really exception here.
		else begin
			next_count = 4'd1;
			next_uop[0] = nopi;
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
					next_count = 3'd2;
					next_uop[0] = {1'b1,1'b0,3'd1,3'd0,5'h00,4'd0,ir};
					next_uop[1] = {1'b1,1'b0,3'd1,3'd0,5'h01,4'd0,ir & ~48'hFFFFFFFFE000};
				end
			endcase
		end
	*/
	Qupls4_pkg::OP_ADDI,
	Qupls4_pkg::OP_SUBFI,
	Qupls4_pkg::OP_CMPI,
	Qupls4_pkg::OP_CMPUI,
	Qupls4_pkg::OP_CSR,
	Qupls4_pkg::OP_ANDI,
	Qupls4_pkg::OP_ORI,
	Qupls4_pkg::OP_XORI,
	Qupls4_pkg::OP_LOADI,
	Qupls4_pkg::OP_LDB,Qupls4_pkg::OP_LDBZ,Qupls4_pkg::OP_LDW,Qupls4_pkg::OP_LDWZ,
	Qupls4_pkg::OP_LDT,Qupls4_pkg::OP_LDTZ,Qupls4_pkg::OP_LDO,Qupls4_pkg::OP_LDOZ,
	Qupls4_pkg::OP_LOADA,
	Qupls4_pkg::OP_AMO,Qupls4_pkg::OP_CMPSWAP:
		begin
			if (insert_boi) begin
				next_count = 4'd2;
				next_uop[0] = uop_boi;
				next_uop[1] = uop1;
			end
			else begin
				next_count = 4'd1;
				next_uop[0] = uop0;
			end
		end

	Qupls4_pkg::OP_LOAD:
		if (insert_boi) begin
			next_count = 4'd3;
			next_uop[0] = uop_boi;
			next_uop[1] = uop1;
			next_uop[2] = uop1;
			next_uop[2].num = 5'd2;
			next_uop[2].Rd[0] = 1'b1;
			next_uop[2].imm = next_uop[1].imm + 4'd8;
		end
		else begin
			next_count = 4'd2;
			next_uop[0] = uop0;
			next_uop[1] = uop0;
			next_uop[1].num = 5'd2;
			next_uop[1].Rd[0] = 1'b1;
			next_uop[1].imm = next_uop[0].imm + 4'd8;
		end

	Qupls4_pkg::OP_CHK,
	Qupls4_pkg::OP_STB,Qupls4_pkg::OP_STW,
	Qupls4_pkg::OP_STT,Qupls4_pkg::OP_STO,
	Qupls4_pkg::OP_STI,
	Qupls4_pkg::OP_FENCE:
		if (insert_boi) begin
			next_count = 4'd2;
			next_uop[0] = uop_boi;
			next_uop[1] = uop1;
		end
		else begin
			next_count = 4'd1;
			next_uop[0] = uop0;
		end

	Qupls4_pkg::OP_STORE,Qupls4_pkg::OP_STPTR:
		if (insert_boi) begin
			next_count = 4'd3;
			next_uop[0] = uop_boi;
			next_uop[1] = uop1;
			next_uop[2] = uop1;
			next_uop[2].num = 5'd2;
			next_uop[2].Rd[0] = 1'b1;
			next_uop[2].imm = next_uop[1].imm + 4'd8;
		end
		else begin
			next_count = 4'd2;
			next_uop[0] = uop0;
			next_uop[1] = uop0;
			next_uop[1].num = 5'd2;
			next_uop[1].Rd[0] = 1'b1;
			next_uop[1].imm = next_uop[0].imm + 4'd8;
		end

/*		
	Qupls4_pkg::OP_MOV:
		begin
			next_count = 4'd1;
			next_uop[0] = {1'b1,1'b0,3'd1,3'd0,4'd0,ir};
		end
*/			
	Qupls4_pkg::OP_ENTER:
		begin
			next_count = 4'd5;
			next_uop[0] = enter_st_fp;
			next_uop[0].lead = TRUE;
			next_uop[1] = fp_eq_sp;
			next_uop[1].num = 5'd1;
			next_uop[2] = enter_st_lr;
			next_uop[2].num = 5'd2;
			next_uop[3] = decssp64;
			next_uop[3].num = 5'd3;
			next_uop[4].opcode = Qupls4_pkg::OP_ENTER;
			next_uop[4].num = 5'd4;
		end

	Qupls4_pkg::OP_EXIT:
		begin
			next_count = 4'd5;
			next_uop[0] = sp_eq_fp;
			next_uop[0].lead = TRUE;
			next_uop[1] = exit_ld_fp;
			next_uop[1].num = 5'd1;
			next_uop[2] = exit_ld_lr;
			next_uop[2].num = 5'd2;
			next_uop[3] = incssp64;
			next_uop[3].num = 5'd3;
			next_uop[4].opcode = Qupls4_pkg::OP_RTD;	// change LEAVE into RTD
			next_uop[4].Rd = ir[12:7];
			next_uop[4].Rs1 = ir[24:19];					// link register
			next_uop[4].imm = {ir[47:25],3'h0};
			next_uop[4].num = 5'd4;
		end

	Qupls4_pkg::OP_PUSH:
		begin
			next_count = {1'b0,ir[47:45]} + 2'd1;
			case(ir[47:45])
			4'd1:	
				begin
					next_uop[0] = push1;
					next_uop[0].lead = TRUE;
					next_uop[1] = decsp16;
					next_uop[1].num = 5'd1;
				end
			4'd2:
				begin
					next_uop[0] = push1;
					next_uop[0].lead = TRUE;
					next_uop[1] = push2;
					next_uop[1].num = 5'd1;
					next_uop[2] = decsp32;
					next_uop[2].num = 5'd2;
				end
			4'd3:
				begin
					next_uop[0] = push1;
					next_uop[0].lead = TRUE;
					next_uop[1] = push2;
					next_uop[1].num = 5'd1;
					next_uop[2] = push3;
					next_uop[2].num = 5'd2;
					next_uop[3] = decsp48;
					next_uop[3].num = 5'd3;
				end
			4'd4:
				begin
					next_uop[0] = push1;
					next_uop[0].lead = TRUE;
					next_uop[1] = push2;
					next_uop[1].num = 5'd1;
					next_uop[2] = push3;
					next_uop[2].num = 5'd2;
					next_uop[3] = push4;
					next_uop[3].num = 5'd3;
					next_uop[4] = decsp64;
					next_uop[4].num = 5'd4;
				end
			4'd5:
				begin
					next_uop[0] = push1;
					next_uop[0].lead = TRUE;
					next_uop[1] = push2;
					next_uop[1].num = 5'd1;
					next_uop[2] = push3;
					next_uop[2].num = 5'd2;
					next_uop[3] = push4;
					next_uop[3].num = 5'd3;
					next_uop[4] = push5;
					next_uop[4].num = 5'd4;
					next_uop[5] = decsp80;
					next_uop[5].num = 5'd5;
				end
			default:	
				begin
					next_count = 4'd1;
					next_uop[0] = nopi;
				end
			endcase
		end

	Qupls4_pkg::OP_POP:
		begin
			next_count = {1'b0,ir[47:45]} + 2'd1;
			case(ir[47:45])
			4'd1:	
				begin
					next_uop[0] = pop1;
					next_uop[0].lead = TRUE;
					next_uop[1] = incsp16;
					next_uop[1].num = 5'd1;
				end
			4'd2:
				begin
					next_uop[0] = pop1;
					next_uop[0].lead = TRUE;
					next_uop[1] = pop2;
					next_uop[1].num = 5'd1;
					next_uop[2] = incsp32;
					next_uop[2].num = 5'd2;
				end
			4'd3:
				begin
					next_uop[0] = pop1;
					next_uop[0].lead = TRUE;
					next_uop[1] = pop2;
					next_uop[1].num = 5'd1;
					next_uop[2] = pop3;
					next_uop[2].num = 5'd2;
					next_uop[3] = incsp48;
					next_uop[3].num = 5'd3;
				end
			4'd4:
				begin
					next_uop[0] = pop1;
					next_uop[0].lead = TRUE;
					next_uop[1] = pop2;
					next_uop[1].num = 5'd1;
					next_uop[2] = pop3;
					next_uop[2].num = 5'd2;
					next_uop[3] = pop4;
					next_uop[3].num = 5'd3;
					next_uop[4] = incsp64;
					next_uop[4].num = 5'd4;
				end
			4'd5:
				begin
					next_uop[0] = pop1;
					next_uop[0].lead = TRUE;
					next_uop[1] = pop2;
					next_uop[1].num = 5'd1;
					next_uop[2] = pop3;
					next_uop[2].num = 5'd2;
					next_uop[3] = pop4;
					next_uop[3].num = 5'd3;
					next_uop[4] = pop5;
					next_uop[4].num = 5'd4;
					next_uop[5] = incsp80;
					next_uop[5].num = 5'd5;
				end
			default:	
				begin
					next_count = 4'd1;
					next_uop[0] = nopi;
				end
			endcase
		end

	Qupls4_pkg::OP_FLTH,Qupls4_pkg::OP_FLTS,Qupls4_pkg::OP_FLTD,Qupls4_pkg::OP_FLTQ:
		begin
			// Add postfix for second write port if status recording is set.
			if (instr.func[6]) begin
				next_count = 4'd2;
				next_uop[0] = uop0;
				// Select value 0 for all source regs.
				next_uop[1] = uop1;
				next_uop[1].ms = 3'b111;
				next_uop[1].Rs1 = 9'd00;
				next_uop[1].Rs2 = 9'd00;
				next_uop[1].Rs3 = 9'd00;
				next_uop[1].Rd = fp_status_reg;		// FP status reg
				next_uop[1].opcode = Qupls4_pkg::OP_REXT;
			end
			else begin
				next_count = 4'd1;
				next_uop[0] = uop0;
			end
			/*
			case(ir.op4)
			FOP4_FMUL:
				// Tranlate FMUL Rd,Fs1,Fs2 to FMA Fd,Rs1,Fs2,F0.
				begin
					next_uop[0] = {1'b1,1'b0,3'd2,3'd0,8'b10101010,4'd0,ir};
					next_uop[0].ins[31]=1'b1;
					next_uop[0].ins[30]=1'b0;
					next_uop[0].ins[29:27] = ir.fpurm.rm;
					next_uop[0].ins.fma.Rs3 = 5'd0;
					if (ir[16]) begin
						next_count = 3'd2;
						next_uop[0].next_count = 3'd2;
						next_uop[1] = {1'b1,1'b0,3'd0,3'd1,8'b10101001,4'd0,fcmp};
					end
					else begin
						next_count = 3'd1;
						next_uop[0].next_count = 3'd1;
					end	
				end
			FOP4_FADD,FOP4_FSUB:
				// Translate FADD Fd,Fs1,Fs2 into FMA Fd,Fs1,r47,Fs2
				// Translate FSUB Fd,Fs1,Fs2 into FMS Fd,Fs1,r47,Fs2
				begin
					next_uop[0] = {1'b1,1'b0,3'd0,3'd0,6'd0,2'd1,4'd0,floadi1};	// Load 1.0 into r47
					next_uop[0].xRd = 2'd1;	// r47 = 32+15
					next_uop[1] = {1'b1,1'b0,3'd0,3'd1,8'b10101010,4'd0,ir};
					next_uop[1].ins[31]=1'b1;
					next_uop[1].ins[30]=ir.op4==FOP4_FSUB;
					next_uop[1].ins[29:27] = ir.fpurm.rm;
					next_uop[1].ins.fma.Rs3 = ir.Rs2;
					next_uop[1].ins.fma.Rs2 = 5'd15;
					next_uop[1].xRs2 = 2'd1;
					if (ir[16]) begin
						next_count = 3'd3;
						next_uop[0].next_count = 3'd3;
						next_uop[2] = {1'b1,1'b0,3'd0,3'd2,8'b10101001,4'd0,fcmp};
					end
					else begin
						next_count = 3'd2;
						next_uop[0].next_count = 3'd2;
						next_uop[1].num = 3'd1;
					end	
				end
			default:
				next_uop[0] = {1'b1,1'b0,3'd1,3'd0,8'b10101010,4'd0,ir};
			endcase
			// ToDo: exceptions on Rd,Rs1,Rs2
			//next_uop[0].exc = fnRegExc(om, {2'b10,ir.Rs1}) | fnRegExc(om, {2'b10,ir.Rd});
			*/
		end
	Qupls4_pkg::OP_MOD,Qupls4_pkg::OP_NOP:
		begin
			if (insert_boi) begin
				next_count = 4'd2;
				next_uop[0] = uop_boi;
				next_uop[1] = uop1;
			end
			else begin
				next_count = 4'd1;
				next_uop[0] = uop0;
			end
		end

	Qupls4_pkg::OP_R3H:
		begin
			case(ir.func)
			// Note the use of the OR instruction instead of MOVE.
			// MOVES are done by renaming registers which is not what we want in 
			// this case. Reading and writing of the same register is taking place
			// as far as rename is concerned.
			FN_EXG:
				if (insert_boi) begin
					next_count = 4'd4;
					next_uop[0] = uop_boi;
					// mot0 = Rd
					next_uop[1] = uop1;
					next_uop[1].func = Qupls4_pkg::FN_MOVE;
					next_uop[1].Rd = mot0_reg;	
					next_uop[1].Rs1 = uop1.Rd;
					next_uop[1].Rs2 = zero_reg;
					next_uop[1].Rs3 = zero_reg;
					// Rd = Rs1
					next_uop[2] = uop1;
					next_uop[2].func = Qupls4_pkg::FN_MOVE;
					next_uop[2].Rs2 = zero_reg;
					next_uop[2].Rs3 = zero_reg;
					// Rs1 = mot0
					next_uop[3] = uop1;
					next_uop[3].func = Qupls4_pkg::FN_MOVE;
					next_uop[3].Rd = uop1.Rs1;
					next_uop[3].Rs1 = mot0_reg;
					next_uop[3].Rs2 = zero_reg;
					next_uop[3].Rs3 = zero_reg;
				end
				else begin
					next_count = 4'd3;
					// mot0 = Rd
					next_uop[0] = uop1;
					next_uop[0].func = Qupls4_pkg::FN_MOVE;
					next_uop[0].Rd = mot0_reg;	
					next_uop[0].Rs1 = uop1.Rd;
					next_uop[0].Rs2 = zero_reg;
					next_uop[0].Rs3 = zero_reg;
					// Rd = Rs1
					next_uop[1] = uop1;
					next_uop[1].func = Qupls4_pkg::FN_MOVE;
					next_uop[1].Rs2 = zero_reg;
					next_uop[1].Rs3 = zero_reg;
					// Rs1 = mot0
					next_uop[2] = uop1;
					next_uop[2].func = Qupls4_pkg::FN_MOVE;
					next_uop[2].Rd = uop1.Rs1;
					next_uop[2].Rs1 = mot0_reg;
					next_uop[2].Rs2 = zero_reg;
					next_uop[2].Rs3 = zero_reg;
				end
			default:
				if (insert_boi) begin
					next_count = 4'd2;
					next_uop[0] = uop_boi;
					next_uop[1] = uop1;
				end
				else begin
					next_count = 4'd1;
					next_uop[0] = uop0;
				end
			endcase
		end
	default:
		begin
			if (insert_boi) begin
				next_count = 4'd2;
				next_uop[0] = uop_boi;
				next_uop[1] = uop1;
			end
			else begin
				next_count = 4'd1;
				next_uop[0] = uop0;
			end
		end
	endcase
	for (nn = 0; nn < 32; nn = nn + 1) begin
		if (nn >= next_count)
			next_uop[nn].v = 1'b0;
	end	
end

generate begin : gComb
	if (COMB) begin
		always_comb
		if (rst) begin
			count = 3'd0;
			foreach (uop[n1]) begin
				uop[n1] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
				uop[n1].opcode = Qupls4_pkg::OP_NOP;
				uop[n1].v = VAL;
			end
		end
		else begin
			count = next_count;
			foreach (uop[n1])
				uop[n1] = next_uop[n1];
		end
	end
	else begin
		always_ff @(posedge clk)
		if (rst) begin
			count <= 3'd0;
			foreach (uop[n1]) begin
				uop[n1] <= {$bits(Qupls4_pkg::micro_op_t){1'b0}};
				uop[n1].opcode <= Qupls4_pkg::OP_NOP;
				uop[n1].v = VAL;
			end
		end
		else if (en) begin
			count <= next_count;
			foreach (uop[n1])
				uop[n1] <= next_uop[n1];
		end
	end
end
endgenerate


endmodule
