// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2025  Robert Finch, Waterloo
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
//
// There are four copies of this micro-code so that four instructions may be
// queued at the same time.
// The micro-code pointer only points to a row of micro-code, so it advances
// by four. Micro-code branch targets must be addressed at a multiple of four.
//
// 800 LUTs
// ============================================================================

import Qupls4_pkg::*;

module Qupls4_micro_machine(om, ipl, micro_ip, micro_ir, next_ip, instr, regx);
input Qupls4_pkg::operating_mode_t om;
input [5:0] ipl;
input cpu_types_pkg::mc_address_t micro_ip;
input Qupls4_pkg::pipeline_reg_t micro_ir;
output cpu_types_pkg::mc_address_t next_ip;
output Qupls4_pkg::ex_instruction_t instr;
output reg [3:0] regx;
parameter R0 = 8'd0;
parameter S0 = 8'd18;
parameter S1 = 8'd19;
parameter S2 = 8'd20;
parameter S3 = 8'd21;
parameter S4 = 8'd22;
parameter S5 = 8'd23;
parameter S6 = 8'd24;
parameter S7 = 8'd25;
parameter S8 = 8'd26;
parameter SP = 5'd31;
parameter FP = 8'd30;
parameter SUSP = 8'd32;
parameter SSSP = 8'd33;
parameter SHSP = 8'd34;
parameter MSP = 8'd35;
parameter LR0 = SSSP;
parameter LR1 = SHSP;
// Do not use 6'd0 as some logic will detect this as a zero.
// 1 to 4 are the stack pointers.
parameter MC0 = 8'd68;
parameter MC1 = 8'd69;
parameter MC2 = 8'd70;
parameter MC3 = 8'd71;
parameter LC = 8'd28;
parameter VRM = 8'd54;
parameter VERR = 8'd55;
Qupls4_pkg::instruction_t ir;
always_comb ir = micro_ir.uop.ins;
reg [15:0] mask;
reg [6:0] regno;
reg [4:0] savecnt;
reg [4:0] cnt;
reg [21:0] bamt;
always_comb
begin
	case(ir[28:25])
	4'd1:	bamt = 21'd1;
	4'd2:	bamt = 21'd2;
	4'd3:	bamt = 21'd4;
	4'd4:	bamt = 21'd8;
	4'd15:	bamt = 21'h1FFFFF;
	4'd14:	bamt = 21'h1FFFFE;
	4'd13:	bamt = 21'h1FFFFC;
	4'd12:	bamt = 21'h1FFFF8;
	default:	bamt = 21'h0;
	endcase
	regx = 'd0;
/*
instr.aRs1 = ir.Rs1;
instr.aRs2 = ir.Rs2;
instr.aRs3 = ir.Rd;
instr.aRd = ir.Rd;
*/
instr.mcip = micro_ip;
case(micro_ip)
12'h000:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
12'h001:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
12'h002:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
12'h003:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end

// -----------------------------------------------------------------------------
// ENTER
//
//	enter %s0-%s4		# save s0 to s4 and allocate 32 words
// Process is:
//	sub sp,sp,32
//	store fp,[sp]		# optional
//  move mc0,a0
//  move a0,br1
//  store a0,8[sp]	# optional
//  store r0,16[sp]
//  store r0,24[sp]
//	move fp,sp
// -----------------------------------------------------------------------------
12'h004:
	begin		// sub sp,sp,32
		next_ip=ir[28] ? 12'h005 : ir[27] ? 12'h006 : ir[26] ? 12'h009 : 12'h00B;
		instr.ins={1'b1,14'h3FE0,1'b0,SP,SP,Qupls4_pkg::OP_ADD};
		savecnt = ir[15:11]==5'd0 ? 5'd0 : ir[15:11] - ir[10:6];
		cnt = 5'd0;
	end
12'h005:
	begin		// store fp,[sp]
		next_ip=ir[27] ? 12'h006 : ir[26] ? 12'h009 : 12'h00B;
		instr.ins={1'b1,14'h0000,1'b0,SP,FP,Qupls4_pkg::OP_STORE};
	end
12'h006:
	begin		// move mc0,a0
		next_ip=12'h007;
		instr.ins={1'b1,10'h00,2'b00,2'b10,1'b0,5'd1,5'd4,Qupls4_pkg::OP_MOV};
	end
12'h007:
	begin		// move a0,br1
		next_ip=12'h008;
		instr.ins={1'b1,10'h00,2'b10,2'b00,1'b0,5'd9,5'd1,Qupls4_pkg::OP_MOV};
	end
12'h008:
	begin		// store a0,8[sp]
		next_ip=12'h009;
		instr.ins={1'b1,14'h0008,1'b0,SP,5'd1,Qupls4_pkg::OP_STORE};
	end
12'h009:
	begin		// store r0,16[sp]
		next_ip=12'h00A;
		instr.ins={1'b1,14'h0010,1'b0,SP,5'd0,Qupls4_pkg::OP_STORE};
	end
12'h00A:
	begin		// store r0,24[sp]
		next_ip=12'h00B;
		instr.ins={1'b1,14'h0018,1'b0,SP,5'd0,Qupls4_pkg::OP_STORE};
	end
12'h00B:
	begin		// move fp,sp
		next_ip=12'h00C;
		instr.ins={1'b1,10'h00,2'b00,2'b00,1'b0,5'd31,5'd30,Qupls4_pkg::OP_MOV};
	end
12'h00C:
	begin		// sp = sp - saved count * 8
		next_ip=12'h00D;
		instr.ins={1'b1,6'h3F,-savecnt,3'b0,1'b0,SP,SP,Qupls4_pkg::OP_ADD};
	end
12'h00D:
	begin		// store r0,24[sp]
		next_ip=cnt==savecnt ? (ir[27] ? 12'h00E : 12'h00F) : 12'h00D;
		instr.ins={1'b1,6'd0,cnt,3'd0,1'b0,SP,ir[10:6]+cnt,Qupls4_pkg::OP_STORE};
		cnt = cnt + 5'd1;
	end
12'h00E:
	begin		// move a0,mc0
		next_ip=12'h000;
		instr.ins={1'b1,10'h00,2'b10,2'b00,1'b0,5'd4,5'd1,Qupls4_pkg::OP_MOV};
	end
12'h00F,12'h010,12'h011,12'h012,12'h013:
	begin
		next_ip=12'h000;
		instr.ins={26'd0,Qupls4_pkg::OP_NOP};
	end

// -----------------------------------------------------------------------------
// PUSH
// -----------------------------------------------------------------------------
12'h018:
	begin
		regno = {ir[28:27],ir[15:14],3'd0};
		mask = {ir[26:17],ir[13:6]};
		next_ip = |mask ? 12'h019 : 12'h01E;
	end
12'h019:
	begin		// move mc0,a0
		next_ip=12'h01A;
		instr.ins={1'b1,10'h00,2'b00,2'b10,1'b0,5'd1,5'd4,Qupls4_pkg::OP_MOV};
	end
12'h01A:
	begin
		// if bit set, store register
		if (mask[0]) begin	// move a0,reg
			instr.ins={1'b1,10'h00,regno[6:5],2'b00,1'b0,regno[4:0],5'd1,Qupls4_pkg::OP_MOV};
			next_ip = 12'h01B;
		end
		mask = mask >> 1;
		regno = regno + 1;
		if (~|mask)
			next_ip = 12'h01D;
	end
12'h01B:
	begin
		instr.ins = {1'b0,14'h3ff8,1'b0,5'd31,5'd31,Qupls4_pkg::OP_ADD};	// sub sp,sp,8
		next_ip = 12'h01C;
	end
12'h01C:
	begin
		instr.ins = {16'h0,5'd31,5'd1,Qupls4_pkg::OP_STORE};			// store a0,[sp]
		next_ip = 12'h01A;
	end
12'h01D:
	begin		// move a0,mc0
		next_ip=12'h000;
		instr.ins={1'b1,10'h00,2'b10,2'b00,1'b0,5'd4,5'd1,Qupls4_pkg::OP_MOV};
	end
12'h01E:	begin next_ip = 12'h000; instr.ins = {26'd0,Qupls4_pkg::OP_NOP};	end
12'h01F:	begin next_ip = 12'h000; instr.ins = {26'd0,Qupls4_pkg::OP_NOP};	end
12'h020:	begin next_ip = 12'h000; instr.ins = {26'd0,Qupls4_pkg::OP_NOP};	end
12'h021:	begin next_ip = 12'h000; instr.ins = {26'd0,Qupls4_pkg::OP_NOP};	end
12'h022:	begin next_ip = 12'h000; instr.ins = {26'd0,Qupls4_pkg::OP_NOP};	end
12'h023:	begin next_ip = 12'h000; instr.ins = {26'd0,Qupls4_pkg::OP_NOP};	end

// -----------------------------------------------------------------------------
// POP
// -----------------------------------------------------------------------------
12'h028:
	begin
		regno = {ir[28:27],ir[15:14],3'd0};
		mask = {ir[26:17],ir[13:6]};
		next_ip = |mask ? 12'h029 : 12'h02D;
	end
12'h029:
	begin		// move mc0,a0
		next_ip=12'h02A;
		instr.ins={1'b1,10'h00,2'b00,2'b10,1'b0,5'd1,5'd4,Qupls4_pkg::OP_MOV};
	end
12'h02A:
	begin
		instr.ins = {16'h0,5'd31,5'd1,Qupls4_pkg::OP_LOAD};			// load a0,[sp]
		next_ip = 12'h01A;
	end
12'h02B:
	begin
		// if bit set, load register
		if (mask[0]) begin	// move reg,a0
			if (regno==7'd1)	// loading a0? -> move to mc0
				instr.ins={1'b1,10'h00,2'b10,regno[6:5],1'b0,5'd4,regno[4:0],Qupls4_pkg::OP_MOV};
			else
				instr.ins={1'b1,10'h00,2'b00,regno[6:5],1'b0,5'd1,regno[4:0],Qupls4_pkg::OP_MOV};
			next_ip = 12'h02C;
		end
		mask = mask >> 1;
		regno = regno + 1;
		if (~|mask)
			next_ip = 12'h02E;
	end
12'h02C:
	begin
		instr.ins = {1'b0,14'h0008,1'b0,5'd31,5'd31,Qupls4_pkg::OP_ADD};	// add sp,sp,8
		next_ip = 12'h02A;
	end
12'h02D:
	begin		// move a0,mc0
		next_ip=12'h000;
		instr.ins={1'b1,10'h00,2'b10,2'b00,1'b0,5'd4,5'd1,Qupls4_pkg::OP_MOV};
	end
12'h02E:	begin next_ip = 12'h000; instr.ins = {26'd0,Qupls4_pkg::OP_NOP};	end
12'h02F:	begin next_ip = 12'h000; instr.ins = {26'd0,Qupls4_pkg::OP_NOP};	end
12'h030:	begin next_ip = 12'h000; instr.ins = {26'd0,Qupls4_pkg::OP_NOP};	end
12'h031:	begin next_ip = 12'h000; instr.ins = {26'd0,Qupls4_pkg::OP_NOP};	end
12'h032:	begin next_ip = 12'h000; instr.ins = {26'd0,Qupls4_pkg::OP_NOP};	end
12'h033:	begin next_ip = 12'h000; instr.ins = {26'd0,Qupls4_pkg::OP_NOP};	end

// -----------------------------------------------------------------------------
// FDIV
// -----------------------------------------------------------------------------
/*
12'h040:	begin next_ip = 12'h044; instr.ins = {'d0,FN_FLT1,2'd0,3'd0,FN_FLT1,FN_FRES,ir[18:13],ir[12:7],Qupls4_pkg::OP_FLT3}; end
12'h041:	begin next_ip = 12'h044; instr.ins = {'d0,FN_FLT1,2'd0,3'd0,FN_FLT1,FN_FNEG,ir[18:13],ir[18:13],Qupls4_pkg::OP_FLT3}; end
12'h042:	begin next_ip = 12'h044; instr.ins = {'d0,FN_FLT1,5'b0,FN_FLT1,FN_FCONST,6'd2,6'd58,Qupls4_pkg::OP_FLT3}; end
12'h043:	begin next_ip = 12'h044; instr.ins = {'d0,FN_FMA,5'd0,6'd58,ir[18:13],ir[12:7],6'd47,Qupls4_pkg::OP_FLT3}; end
12'h044:	begin next_ip = 12'h048; instr.ins = {'d0,FN_FMA,5'd0,6'd0,6'd47,ir[12:7],ir[12:7],Qupls4_pkg::OP_FLT3}; end
12'h045:	begin next_ip = 12'h048; instr.ins = {'d0,FN_FMA,5'd0,6'd58,ir[18:13],ir[12:7],6'd47,Qupls4_pkg::OP_FLT3}; end
12'h046:	begin next_ip = 12'h048; instr.ins = {'d0,FN_FMA,5'd0,6'd0,6'd47,ir[12:7],ir[12:7],Qupls4_pkg::OP_FLT3}; end
12'h047:	begin next_ip = 12'h048; instr.ins = {'d0,FN_FMA,5'd0,6'd58,ir[18:13],ir[12:7],6'd47,Qupls4_pkg::OP_FLT3}; end
12'h048:	begin next_ip = 12'h04C; instr.ins = {'d0,FN_FMA,5'd0,6'd0,6'd47,ir[12:7],ir[12:7],Qupls4_pkg::OP_FLT3}; end
12'h049:	begin next_ip = 12'h04C; instr.ins = {'d0,FN_FMA,5'd0,6'd58,ir[18:13],ir[12:7],6'd47,Qupls4_pkg::OP_FLT3}; end
12'h04A:	begin next_ip = 12'h04C; instr.ins = {'d0,FN_FMA,5'd0,6'd0,6'd47,ir[12:7],ir[12:7],Qupls4_pkg::OP_FLT3}; end
12'h04B:	begin next_ip = 12'h04C; instr.ins = {'d0,FN_FLT1,5'b0,FN_FLT1,FN_FNEG,ir[18:13],ir[18:13],Qupls4_pkg::OP_FLT3}; end
12'h04C:	begin next_ip = 12'h000; instr.ins = {'d0,FN_FMA,5'd0,6'd0,ir[18:13],ir[12:7],ir[12:7],Qupls4_pkg::OP_FLT3}; end
12'h04D:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
12'h04E:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
12'h04F:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
*/
// Lomont Reciprocal Square Root
// float RcpSqrt1 (float x)
// {
//   float xhalf = 0.5f*x;
//   int i = *(int*)&x; // represent float as an integer  ()
//	 i = 0x5f375a86 � (i >> 1);// integer division by two and change in sign
//	 float y = *(float*)&i; // represent integer as a float  ()
//
// initial approximation 0
//   y = y*(1.5f � xhalf *y*y); // first NR iteration			9.16 bits accurate
//	 y = y*(1.5f � xhalf *y*y); // second NR iteration	 17.69 bits accurate
//	 y = y*(1.5f � xhalf *y*y); // third NR iteration	   35 bits accurate
//   y = y*(1.5f � xhalf *y*y); // fourth NR iteration	 70 bits accurate
//	 return y;
// }
//64-bit magic used:
//0x5FE6EB50C7B537A9
// Approximately 119 clock cycles.
// ToDo: Fix for new float format instructions.
/*
12'h050:	begin next_ip = 12'h054; instr.ins = {3'd0,12'h068,6'd0,ir[18:13],3'd2,2'd0,1'b0,Qupls4_pkg::OP_MCB};	end		// if -tive
12'h051:	begin next_ip = 12'h054; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd57,MC0,Qupls4_pkg::OP_FLT3}; regx = 4'h1; end	// MC0 = infinity
12'h052:	begin next_ip = 12'h054; instr.ins = {3'd0,12'h06C,MC0,ir[18:13],3'd0,2'd0,1'b0,Qupls4_pkg::OP_MCB}; regx = 4'h4; end			// if = infinity
12'h053:	begin next_ip = 12'h054; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd0,MC0,Qupls4_pkg::OP_FLT3};  regx = 4'h1; end	// MC0 = 0.5
12'h054:	begin next_ip = 12'h058; instr.ins = {'d0,FN_MUL,4'b0,MC0,ir[18:13],MC1,Qupls4_pkg::OP_FLT3}; regx = 4'h5; end	// MC1 = x * MC0
12'h055:	begin next_ip = 12'h058; instr.ins = {'d0,1'b0,1'b1,Qupls4_pkg::OP_LSR,7'd1,ir[18:13],MC2,Qupls4_pkg::OP_SHIFTO}; regx = 4'h1; end	// MC2 = i>>1
12'h056:	begin next_ip = 12'h058; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd4,MC0,Qupls4_pkg::OP_FLT3}; regx = 4'h1; end			// MC0 = MAGIC
12'h057:	begin next_ip = 12'h058; instr.ins = {'d0,FN_SUB,4'b00,MC2,MC0,MC2,Qupls4_pkg::OP_FLT3}; regx = 4'h7; end							// MC2 = MAGIC - MC2
12'h058:	begin next_ip = 12'h05C; instr.ins = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,Qupls4_pkg::OP_FLT3}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h059:	begin next_ip = 12'h05C; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd3,MC0,Qupls4_pkg::OP_FLT3}; regx = 4'h1; end			// MC0 = 1.5
12'h05A:	begin next_ip = 12'h05C; instr.ins = {'d0,FN_FNMS,MC0,MC3,MC1,ir[12:7],Qupls4_pkg::OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h05B:	begin next_ip = 12'h05C; instr.ins = {'d0,FN_MUL,4'b0,MC2,ir[12:7],MC2,Qupls4_pkg::OP_FLT3}; regx = 4'h5; end		// MC2 = MC2 * Rt
12'h05C:	begin next_ip = 12'h060; instr.ins = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,Qupls4_pkg::OP_FLT3}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h05D:	begin next_ip = 12'h060; instr.ins = {'d0,FN_FNMS,MC0,MC3,MC1,ir[12:7],Qupls4_pkg::OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h05E:	begin next_ip = 12'h060; instr.ins = {'d0,FN_MUL,4'b0,MC2,ir[12:7],MC2,Qupls4_pkg::OP_FLT3}; regx = 4'h5; end		// MC2 = MC2 * Rt
12'h05F:	begin next_ip = 12'h060; instr.ins = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,Qupls4_pkg::OP_FLT3}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h060:	begin next_ip = 12'h064; instr.ins = {'d0,FN_FNMS,MC0,MC3,MC1,ir[12:7],Qupls4_pkg::OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h061:	begin next_ip = 12'h064; instr.ins = {'d0,FN_MUL,4'b0,MC2,ir[12:7],MC2,Qupls4_pkg::OP_FLT3}; regx = 4'h5; end		// MC2 = MC2 * Rt
12'h062:	begin next_ip = 12'h064; instr.ins = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,Qupls4_pkg::OP_FLT3}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h063:	begin next_ip = 12'h064; instr.ins = {'d0,FN_FNMS,MC0,MC3,MC1,ir[12:7],Qupls4_pkg::OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h064:	begin next_ip = 12'h000; instr.ins = {'d0,FN_MUL,4'b0,MC2,ir[12:7],ir[12:7],Qupls4_pkg::OP_FLT3}; regx = 4'h4; end		// Rt = MC2 * Rt
12'h065:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
12'h066:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
12'h067:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
12'h068:	begin next_ip = 12'h000; instr.ins = {'d0,FN_FLT1,2'b0,FN_FCONST,6'd63,ir[12:7],Qupls4_pkg::OP_FLT3}; end		// Rt = Nan (square root of negative)
12'h069:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
12'h06A:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
12'h06B:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
12'h06C:	begin next_ip = 12'h000; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd62,ir[12:7],Qupls4_pkg::OP_FLT3}; end		// Rt = Nan (square root of infinity)
12'h06D:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
12'h06E:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
12'h06F:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
*/
// FRSQRTE9
// Approximately 46 clock cycles.
/*
12'h070:	begin next_ip = 12'h074; instr.ins = {3'd0,12'h068,6'd0,ir[18:13],3'd2,2'd0,1'b0,Qupls4_pkg::OP_MCB};	end		// if -tive
12'h071:	begin next_ip = 12'h074; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd57,MC0,Qupls4_pkg::OP_FLT3}; regx = 4'h1; end	// MC0 = infinity
12'h072:	begin next_ip = 12'h074; instr.ins = {3'd0,12'h06C,MC0,ir[18:13],3'd0,2'd0,1'b0,Qupls4_pkg::OP_MCB}; regx = 4'h4; end			// if = infinity
12'h073:	begin next_ip = 12'h074; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd0,MC0,Qupls4_pkg::OP_FLT3}; regx = 4'h1; end	// MC0 = 0.5
12'h074:	begin next_ip = 12'h078; instr.ins = {'d0,FN_MUL,4'b0,MC0,ir[18:13],MC1,Qupls4_pkg::OP_FLT3}; regx = 4'h5; end	// MC1 = x * MC0
12'h075:	begin next_ip = 12'h078; instr.ins = {'d0,1'b0,1'b1,Qupls4_pkg::OP_LSR,7'd1,ir[18:13],MC2,Qupls4_pkg::OP_SHIFTO}; regx = 4'h1; end	// MC2 = i>>1
12'h076:	begin next_ip = 12'h078; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd4,MC0,Qupls4_pkg::OP_FLT3}; regx = 4'h1; end			// MC0 = MAGIC
12'h077:	begin next_ip = 12'h078; instr.ins = {'d0,FN_SUB,4'b00,MC2,MC0,MC2,Qupls4_pkg::OP_FLT3}; regx = 4'h7; end							// MC2 = MAGIC - MC2
12'h078:	begin next_ip = 12'h000; instr.ins = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,Qupls4_pkg::OP_FLT3}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h079:	begin next_ip = 12'h000; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd3,MC0,Qupls4_pkg::OP_FLT3}; regx = 4'h1; end			// MC0 = 1.5
12'h07A:	begin next_ip = 12'h000; instr.ins = {'d0,FN_FNMS,MC0,MC3,MC1,ir[12:7],Qupls4_pkg::OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h07B:	begin next_ip = 12'h000; instr.ins = {'d0,FN_MUL,4'b0,MC2,ir[12:7],ir[12:7],Qupls4_pkg::OP_FLT3}; regx = 4'h4; end		// MC2 = MC2 * Rt
12'h07C:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
12'h07D:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
12'h07E:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
12'h07F:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
*/
// FRSQRTE17
// Approximately 70 clock cycles
/*
12'h080:	begin next_ip = 12'h084; instr.ins = {3'd0,12'h068,6'd0,ir[18:13],3'd2,2'd0,1'b0,Qupls4_pkg::OP_MCB};	end		// if -tive
12'h081:	begin next_ip = 12'h084; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd57,MC0,Qupls4_pkg::OP_FLT3}; regx = 4'h1; end	// MC0 = infinity
12'h082:	begin next_ip = 12'h084; instr.ins = {3'd0,12'h06C,MC0,ir[18:13],3'd0,2'd0,1'b0,Qupls4_pkg::OP_MCB}; regx = 4'h4; end			// if = infinity
12'h083:	begin next_ip = 12'h084; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd0,MC0,Qupls4_pkg::OP_FLT3}; regx = 4'h1; end	// MC0 = 0.5
12'h084:	begin next_ip = 12'h088; instr.ins = {'d0,FN_MUL,4'b0,MC0,ir[18:13],MC1,Qupls4_pkg::OP_FLT3}; regx = 4'h5; end	// MC1 = x * MC0
12'h085:	begin next_ip = 12'h088; instr.ins = {'d0,1'b0,1'b1,Qupls4_pkg::OP_LSR,7'd1,ir[18:13],MC2,Qupls4_pkg::OP_SHIFTO}; regx = 4'h1; end	// MC2 = i>>1
12'h086:	begin next_ip = 12'h088; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd4,MC0,Qupls4_pkg::OP_FLT3}; regx = 4'h1; end			// MC0 = MAGIC
12'h087:	begin next_ip = 12'h088; instr.ins = {'d0,FN_SUB,4'b00,MC2,MC0,MC2,Qupls4_pkg::OP_FLT3}; regx = 4'h7; end							// MC2 = MAGIC - MC2
12'h088:	begin next_ip = 12'h08C; instr.ins = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,Qupls4_pkg::OP_FLT3}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h089:	begin next_ip = 12'h08C; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd3,MC0,Qupls4_pkg::OP_FLT3}; regx = 4'h1; end			// MC0 = 1.5
12'h08A:	begin next_ip = 12'h08C; instr.ins = {'d0,FN_FNMS,MC0,MC3,MC1,ir[12:7],Qupls4_pkg::OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h08B:	begin next_ip = 12'h08C; instr.ins = {'d0,FN_MUL,4'b0,MC2,ir[12:7],MC2,Qupls4_pkg::OP_FLT3}; regx = 4'h5; end		// MC2 = MC2 * Rt
12'h08C:	begin next_ip = 12'h000; instr.ins = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,Qupls4_pkg::OP_FLT3}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h08D:	begin next_ip = 12'h000; instr.ins = {'d0,FN_FNMS,MC0,MC3,MC1,ir[12:7],Qupls4_pkg::OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h08E:	begin next_ip = 12'h000; instr.ins = {'d0,FN_MUL,4'b0,MC2,ir[12:7],ir[12:7],Qupls4_pkg::OP_FLT3}; regx = 4'h4; end		// Rt = MC2 * Rt
12'h08F:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
*/
// FRSQRTE34
// Approximately 94 clock cycles
/*
12'h0A0:	begin next_ip = 12'h0A4; instr.ins = {3'd0,12'h068,6'd0,ir[18:13],3'd2,2'd0,1'b0,Qupls4_pkg::OP_MCB};	end		// if -tive
12'h0A1:	begin next_ip = 12'h0A4; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd57,MC0,Qupls4_pkg::OP_FLT3}; regx = 4'h1; end	// MC0 = infinity
12'h0A2:	begin next_ip = 12'h0A4; instr.ins = {3'd0,12'h06C,MC0,ir[18:13],3'd0,2'd0,1'b0,Qupls4_pkg::OP_MCB}; regx = 4'h4; end			// if = infinity
12'h0A3:	begin next_ip = 12'h0A4; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd0,MC0,Qupls4_pkg::OP_FLT3}; regx = 4'h1; end	// MC0 = 0.5
12'h0A4:	begin next_ip = 12'h0A8; instr.ins = {'d0,FN_MUL,4'b0,MC0,ir[18:13],MC1,Qupls4_pkg::OP_FLT3}; regx = 4'h5; end	// MC1 = x * MC0
12'h0A5:	begin next_ip = 12'h0A8; instr.ins = {'d0,1'b0,1'b1,Qupls4_pkg::OP_LSR,7'd1,ir[18:13],MC2,Qupls4_pkg::OP_SHIFTO}; regx = 4'h1; end	// MC2 = i>>1
12'h0A6:	begin next_ip = 12'h0A8; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd4,MC0,Qupls4_pkg::OP_FLT3}; regx = 4'h1; end			// MC0 = MAGIC
12'h0A7:	begin next_ip = 12'h0A8; instr.ins = {'d0,FN_SUB,4'b00,MC2,MC0,MC2,Qupls4_pkg::OP_FLT3}; regx = 4'h7; end							// MC2 = MAGIC - MC2
12'h0A8:	begin next_ip = 12'h0AC; instr.ins = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,Qupls4_pkg::OP_FLT3}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h0A9:	begin next_ip = 12'h0AC; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd3,MC0,Qupls4_pkg::OP_FLT3}; regx = 4'h1; end			// MC0 = 1.5
12'h0AA:	begin next_ip = 12'h0AC; instr.ins = {'d0,FN_FNMS,MC0,MC3,MC1,ir[12:7],Qupls4_pkg::OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h0AB:	begin next_ip = 12'h0AC; instr.ins = {'d0,FN_MUL,4'b0,MC2,ir[12:7],MC2,Qupls4_pkg::OP_FLT3}; regx = 4'h5; end		// MC2 = MC2 * Rt
12'h0AC:	begin next_ip = 12'h0B0; instr.ins = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,Qupls4_pkg::OP_FLT3}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h0AD:	begin next_ip = 12'h0B0; instr.ins = {'d0,FN_FNMS,MC0,MC3,MC1,ir[12:7],Qupls4_pkg::OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h0AE:	begin next_ip = 12'h0B0; instr.ins = {'d0,FN_MUL,4'b0,MC2,ir[12:7],MC2,Qupls4_pkg::OP_FLT3}; regx = 4'h5; end		// MC2 = MC2 * Rt
12'h0AF:	begin next_ip = 12'h0B0; instr.ins = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,Qupls4_pkg::OP_FLT3}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h0B0:	begin next_ip = 12'h000; instr.ins = {'d0,FN_FNMS,MC0,MC3,MC1,ir[12:7],Qupls4_pkg::OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h0B1:	begin next_ip = 12'h000; instr.ins = {'d0,FN_MUL,4'b0,MC2,ir[12:7],ir[12:7],Qupls4_pkg::OP_FLT3}; regx = 4'h4; end		// Rt = MC2 * Rt
12'h0B2:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
12'h0B3:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
*/
// FRES16
// 22 clocks
// x[i+1] = x[i]*(2 - x[i]*a)
/*
12'h0C0:	begin next_ip = 12'h0C4; instr.ins = {'d0,FN_FLT1,4'b0,FN_ISNAN,ir[18:13],ir[12:7],Qupls4_pkg::OP_FLT3}; end
12'h0C1:	begin next_ip = 12'h0C4; instr.ins = {3'd0,12'h0C8,6'd0,ir[12:7],3'd1,2'd0,1'b0,Qupls4_pkg::OP_MCB}; end
12'h0C2:	begin next_ip = 12'h0C4; instr.ins = {'d0,FN_FLT1,4'b0,FN_FRES,ir[18:13],ir[12:7],Qupls4_pkg::OP_FLT3}; end
12'h0C3:	begin next_ip = 12'h0C4; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd2,MC0,Qupls4_pkg::OP_FLT3}; regx = 4'h1; end
12'h0C4:	begin next_ip = 12'h000; instr.ins = {'d0,FN_FNMS,MC0,ir[18:13],ir[12:7],MC1,Qupls4_pkg::OP_FLT3}; regx = 4'h9; end
12'h0C5:	begin next_ip = 12'h000; instr.ins = {'d0,FN_FMA,6'd0,MC1,ir[12:7],ir[12:7],Qupls4_pkg::OP_FLT3}; regx = 4'h4; end
12'h0C6:	begin next_ip = 12'h000; instr.ins = {'d0,FN_OR,1'b0,6'd0,ir[18:13],ir[12:7],Qupls4_pkg::OP_R3O}; end		// Rt = Ra = NaN
12'h0C7:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
12'h0C8:	begin next_ip = 12'h000; instr.ins = {'d0,FN_OR,1'b0,6'd0,ir[18:13],ir[12:7],Qupls4_pkg::OP_R3O}; end		// Rt = Ra = NaN
12'h0C9:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
12'h0CA:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
12'h0CB:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
*/
// FRES32
// 38 clocks
/*
12'h0D0:	begin next_ip = 12'h0D4; instr.ins = {'d0,FN_FLT1,4'b0,FN_ISNAN,ir[18:13],ir[12:7],Qupls4_pkg::OP_FLT3}; end
12'h0D1:	begin next_ip = 12'h0D4; instr.ins = {3'd0,12'h0C8,6'd0,ir[12:7],3'd1,2'd0,1'b0,Qupls4_pkg::OP_MCB}; end
12'h0D2:	begin next_ip = 12'h0D4; instr.ins = {'d0,FN_FLT1,4'b0,FN_FRES,ir[18:13],ir[12:7],Qupls4_pkg::OP_FLT3}; end
12'h0D3:	begin next_ip = 12'h0D4; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd2,MC0,Qupls4_pkg::OP_FLT3}; regx = 4'h1; end
12'h0D4:	begin next_ip = 12'h0E8; instr.ins = {'d0,FN_FNMS,MC0,ir[18:13],ir[12:7],MC1,Qupls4_pkg::OP_FLT3}; regx = 4'h9; end
12'h0D5:	begin next_ip = 12'h0E8; instr.ins = {'d0,FN_FMA,6'd0,MC1,ir[12:7],ir[12:7],Qupls4_pkg::OP_FLT3}; regx = 4'h4; end
12'h0D6:	begin next_ip = 12'h0E8; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
12'h0D7:	begin next_ip = 12'h0E8; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
*/
// FRES64
// 54 clocks
/*
12'h0E0:	begin next_ip = 12'h0E4; instr.ins = {'d0,FN_FLT1,4'b0,FN_ISNAN,ir[18:13],ir[12:7],Qupls4_pkg::OP_FLT3}; end
12'h0E1:	begin next_ip = 12'h0E4; instr.ins = {3'd0,12'h0C8,6'd0,ir[12:7],3'd1,2'd0,1'b0,Qupls4_pkg::OP_MCB}; end
12'h0E2:	begin next_ip = 12'h0E4; instr.ins = {'d0,FN_FLT1,4'b0,FN_FRES,ir[18:13],ir[12:7],Qupls4_pkg::OP_FLT3}; end
12'h0E3:	begin next_ip = 12'h0E4; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd2,MC0,Qupls4_pkg::OP_FLT3}; regx = 4'h1; end
12'h0E4:	begin next_ip = 12'h0E8; instr.ins = {'d0,FN_FNMS,MC0,ir[18:13],ir[12:7],MC1,Qupls4_pkg::OP_FLT3}; regx = 4'h9; end
12'h0E5:	begin next_ip = 12'h0E8; instr.ins = {'d0,FN_FMA,6'd0,MC1,ir[12:7],ir[12:7],Qupls4_pkg::OP_FLT3}; regx = 4'h4; end
12'h0E6:	begin next_ip = 12'h0E8; instr.ins = {'d0,FN_FNMS,MC0,ir[18:13],ir[12:7],MC1,Qupls4_pkg::OP_FLT3}; regx = 4'h9; end
12'h0E7:	begin next_ip = 12'h0E8; instr.ins = {'d0,FN_FMA,6'd0,MC1,ir[12:7],ir[12:7],Qupls4_pkg::OP_FLT3}; regx = 4'h4; end
12'h0E8:	begin next_ip = 12'h000; instr.ins = {'d0,FN_FNMS,MC0,ir[18:13],ir[12:7],MC1,Qupls4_pkg::OP_FLT3}; regx = 4'h9; end
12'h0E9:	begin next_ip = 12'h000; instr.ins = {'d0,FN_FMA,6'd0,MC1,ir[12:7],ir[12:7],Qupls4_pkg::OP_FLT3}; regx = 4'h4; end
12'h0EA:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
12'h0EB:	begin next_ip = 12'h000; instr.ins = {'d0,Qupls4_pkg::OP_NOP};	end
*/
/*
// -----------------------------------------------------------------------------
// STCTX
// -----------------------------------------------------------------------------
12'h100:
	begin
		next_ip=12'h101;
		instr.aRa=9'd0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=MC0;
		instr.ins = {3'd0,2'd0,CSR_CTX,5'h00,5'h00,Qupls4_pkg::OP_CSR};
		instr.pred_btst=6'd0;
	end
12'h101:
	begin
		next_ip=12'h102;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd1;
		instr.aRt=9'd0;
		instr.ins={21'h00008,2'd2,5'd0,5'd1,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h102:
	begin
		next_ip=12'h103;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd2;
		instr.aRt=9'd0;
		instr.ins={21'h00010,2'd2,5'd0,5'd2,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h103:
	begin
		next_ip=12'h104;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd3;
		instr.aRt=9'd0;
		instr.ins={21'h00018,2'd2,5'd0,5'd3,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h104:
	begin
		next_ip=12'h105;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd4;
		instr.aRt=9'd0;
		instr.ins={21'h00020,2'd2,5'd0,5'd4,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h105:
	begin
		next_ip=12'h106;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd5;
		instr.aRt=9'd0;
		instr.ins={21'h00028,2'd2,5'd0,5'd5,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h106:
	begin
		next_ip=12'h107;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd6;
		instr.aRt=9'd0;
		instr.ins={21'h00030,2'd2,5'd0,5'd6,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h107:
	begin
		next_ip=12'h108;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd7;
		instr.aRt=9'd0;
		instr.ins={21'h00038,2'd2,5'd0,5'd7,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h108:
	begin
		next_ip=12'h109;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd8;
		instr.aRt=9'd0;
		instr.ins={21'h00040,2'd2,5'd0,5'd8,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h109:
	begin
		next_ip=12'h10A;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd9;
		instr.aRt=9'd0;
		instr.ins={21'h00048,2'd2,5'd0,5'd9,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h10A:
	begin
		next_ip=12'h10B;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd10;
		instr.aRt=9'd0;
		instr.ins={21'h00050,2'd2,5'd0,5'd10,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h10B:
	begin
		next_ip=12'h10C;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd11;
		instr.aRt=9'd0;
		instr.ins={21'h00058,2'd2,5'd0,5'd11,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h10C:
	begin
		next_ip=12'h10D;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd12;
		instr.aRt=9'd0;
		instr.ins={21'h00060,2'd2,5'd0,5'd12,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h10D:
	begin
		next_ip=12'h10E;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd13;
		instr.aRt=9'd0;
		instr.ins={21'h00068,2'd2,5'd0,5'd13,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h10E:
	begin
		next_ip=12'h10F;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd14;
		instr.aRt=9'd0;
		instr.ins={21'h00070,2'd2,5'd0,5'd14,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h10F:
	begin
		next_ip=12'h110;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd15;
		instr.aRt=9'd0;
		instr.ins={21'h00078,2'd2,5'd0,5'd15,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h110:
	begin
		next_ip=12'h111;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd16;
		instr.aRt=9'd0;
		instr.ins={21'h00080,2'd2,5'd0,5'd16,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h111:
	begin
		next_ip=12'h112;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd17;
		instr.aRt=9'd0;
		instr.ins={21'h00088,2'd2,5'd0,5'd17,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h112:
	begin
		next_ip=12'h113;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd18;
		instr.aRt=9'd0;
		instr.ins={21'h00090,2'd2,5'd0,5'd18,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h113:
	begin
		next_ip=12'h114;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd19;
		instr.aRt=9'd0;
		instr.ins={21'h00098,2'd2,5'd0,5'd19,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h114:
	begin
		next_ip=12'h115;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd20;
		instr.aRt=9'd0;
		instr.ins={21'h000A0,2'd2,5'd0,5'd20,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h115:
	begin
		next_ip=12'h116;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd21;
		instr.aRt=9'd0;
		instr.ins={21'h000A8,2'd2,5'd0,5'd21,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h116:
	begin
		next_ip=12'h117;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd22;
		instr.aRt=9'd0;
		instr.ins={21'h000B0,2'd2,5'd0,5'd22,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h117:
	begin
		next_ip=12'h118;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd23;
		instr.aRt=9'd0;
		instr.ins={21'h000B8,2'd2,5'd0,5'd23,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h118:
	begin
		next_ip=12'h119;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd24;
		instr.aRt=9'd0;
		instr.ins={21'h000C0,2'd2,5'd0,5'd24,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h119:
	begin
		next_ip=12'h11A;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd25;
		instr.aRt=9'd0;
		instr.ins={21'h000C8,2'd2,5'd0,5'd25,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h11A:
	begin
		next_ip=12'h11B;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd26;
		instr.aRt=9'd0;
		instr.ins={21'h000D0,2'd2,5'd0,5'd26,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h11B:
	begin
		next_ip=12'h11C;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd27;
		instr.aRt=9'd0;
		instr.ins={21'h000D8,2'd2,5'd0,5'd27,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h11C:
	begin
		next_ip=12'h11D;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd28;
		instr.aRt=9'd0;
		instr.ins={21'h000E0,2'd2,5'd0,5'd28,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h11D:
	begin
		next_ip=12'h11E;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd29;
		instr.aRt=9'd0;
		instr.ins={21'h000E8,2'd2,5'd0,5'd29,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h11E:
	begin
		next_ip=12'h11F;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd30;
		instr.aRt=9'd0;
		instr.ins={21'h000F0,2'd2,5'd0,5'd30,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h11F:
	begin
		next_ip=12'h120;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd31;
		instr.aRt=9'd0;
		instr.ins={21'h000F8,2'd2,5'd0,5'd31,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h120:	begin next_ip = 12'h000; instr.ins = {'d0,13'h03F0,MC0,6'h3F,Qupls4_pkg::OP_STx}; regx = 4'h2; end
12'h121:	begin next_ip = 12'h000; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end
12'h122:	begin next_ip = 12'h000; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end
12'h123:	begin next_ip = 12'h000; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end

// -----------------------------------------------------------------------------
// JSRI
// -----------------------------------------------------------------------------
12'h128:
	begin
		next_ip=12'h129;
		instr.ins=micro_ir.ins;
		instr.ins.opcode = Qupls4_pkg::OP_LDx;
		instr.ins.prc = ir[18:17];
		instr.aRa=9'd0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=MC0;
		instr.pred_btst=6'd0;
	end
12'h129:
	begin
		next_ip=12'h12A;
		instr.ins=micro_ir.ins;
		instr.ins.opcode = Qupls4_pkg::OP_JSR;
		instr.ins[39:19]=21'd0;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.pred_btst=6'd0;
	end
12'h12A:	begin next_ip = 12'h000; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end
12'h12B:	begin next_ip = 12'h000; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end

// -----------------------------------------------------------------------------
// SYS
// -----------------------------------------------------------------------------
12'h130:
	begin
		next_ip=12'h000;
		instr.aRa=9'd0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={3'd0,MC0};
		instr.ins={3'd0,6'd0,14'h3033,5'd0,5'd0,Qupls4_pkg::OP_CSR};		// MC0=TVEC[3]
	end
12'h131:
	begin
		next_ip=12'h000;
		instr.aRa=9'd0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={3'd0,MC1};
		instr.ins={3'd0,6'd0,14'h3006,5'd0,5'd0,Qupls4_pkg::OP_CSR};		// MC1=Cause
	end
12'h132:
	begin
		next_ip=12'h000;
		instr.aRa={3'd0,MC0};
		instr.aRb={3'd0,MC1};
		instr.aRc=9'd0;
		instr.aRt={3'd0,MC0};
		instr.ins={FN_LDOX,11'd0,2'd3,5'd0,5'd0,5'd0,Qupls4_pkg::OP_LDx};	// ldo mc0,[mc0+mc1]
	end
12'h133:
	begin
		next_ip=12'h000;
		instr.aRa={3'd0,MC0};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd0;
		instr.ins={21'd0,2'd2,5'd0,2'd3,3'd0,Qupls4_pkg::OP_RTD};	// jmpx [mc0]
	end

// -----------------------------------------------------------------------------
// IRQ
// -----------------------------------------------------------------------------
12'h140:
	begin
		next_ip=12'h141;
		instr.aRa=9'd0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={3'd0,MC0};
		instr.ins={3'd0,6'd0,14'h3033,5'd0,5'd0,Qupls4_pkg::OP_CSR};		// MC0=TVEC[3]
	end
12'h141:
	begin
		next_ip=12'h142;
		instr.aRa=9'd0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={3'd0,MC1};
		instr.ins={3'd0,6'd0,14'h3006,5'd0,5'd0,Qupls4_pkg::OP_CSR};		// MC1=Cause
	end
12'h142:
	begin
		next_ip=12'h143;
		instr.aRa={3'd0,MC0};
		instr.aRb={3'd0,MC1};
		instr.aRc=9'd0;
		instr.aRt={3'd0,MC0};
		instr.ins={FN_LDOX,11'd0,2'd3,5'd0,5'd0,5'd0,Qupls4_pkg::OP_LDx};	// ldo mc0,[mc0+mc1*]
	end
12'h143:
	begin
		next_ip=12'h144;
		instr.aRa={3'd0,MC0};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={3'd0,MC1};
		instr.ins={21'h0FF,2'd2,5'd0,5'd0,Qupls4_pkg::OP_ANDI};	// and mc1,mc0,255
	end
12'h144:
	begin
		next_ip=12'h145;
		instr.aRa={3'd0,MC1};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd0;
		instr.ins={4'h8,1'b0,8'd8,5'd0,5'd0,5'd0,5'd0,Qupls4_pkg::OP_CHK};		// MC1=Cause
	end
12'h145:
	begin
		next_ip=12'h146;
		instr.aRa={3'd0,MC0};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={3'd0,MC1};
		instr.ins={21'h1FFF00,2'd2,5'd0,5'd0,Qupls4_pkg::OP_ANDI};	// and mc1,mc0,-256
	end
12'h146:
	begin
		next_ip=12'h000;
		instr.aRa={3'd0,MC1};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd0;
		instr.ins={21'd0,2'd2,5'd0,2'd3,3'd0,Qupls4_pkg::OP_RTD};	// jmpx [mc1]
	end
12'h147:	begin next_ip = 12'h000; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end

// -----------------------------------------------------------------------------
// LDCTX
// -----------------------------------------------------------------------------
12'h150:
	begin
		next_ip=12'h151;
		instr.aRa=9'd0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=MC0;
		instr.ins = {3'd0,2'd0,CSR_CTX,5'd0,5'd0,Qupls4_pkg::OP_CSR};
		instr.pred_btst=6'd0;
	end
12'h151:
	begin
		next_ip=12'h152;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd1;
		instr.ins={21'h00008,2'd2,5'd0,5'd1,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h152:
	begin
		next_ip=12'h153;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd2;
		instr.ins={21'h00010,2'd2,5'd0,5'd2,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h153:
	begin
		next_ip=12'h154;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd3;
		instr.ins={21'h00018,2'd2,5'd0,5'd3,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h154:
	begin
		next_ip=12'h155;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd4;
		instr.ins={21'h00020,2'd2,5'd0,5'd4,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h155:
	begin
		next_ip=12'h156;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd5;
		instr.ins={21'h00028,2'd2,5'd0,5'd5,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h156:
	begin
		next_ip=12'h157;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd6;
		instr.ins={21'h00030,2'd2,5'd0,5'd6,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h157:
	begin
		next_ip=12'h158;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd7;
		instr.ins={21'h00038,2'd2,5'd0,5'd7,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h158:
	begin
		next_ip=12'h159;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd8;
		instr.ins={21'h00040,2'd2,5'd0,5'd8,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h159:
	begin
		next_ip=12'h15A;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd9;
		instr.ins={21'h00048,2'd2,5'd0,5'd9,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h15A:
	begin
		next_ip=12'h15B;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd10;
		instr.ins={21'h00050,2'd2,5'd0,5'd10,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h15B:
	begin
		next_ip=12'h15C;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd11;
		instr.ins={21'h00058,2'd2,5'd0,5'd11,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h15C:
	begin
		next_ip=12'h15D;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd12;
		instr.ins={21'h00060,2'd2,5'd0,5'd12,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h15D:
	begin
		next_ip=12'h15E;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd13;
		instr.ins={21'h00068,2'd2,5'd0,5'd13,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h15E:
	begin
		next_ip=12'h15F;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd14;
		instr.ins={21'h00070,2'd2,5'd0,5'd14,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h15F:
	begin
		next_ip=12'h160;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd15;
		instr.ins={21'h00078,2'd2,5'd0,5'd15,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h160:
	begin
		next_ip=12'h161;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd16;
		instr.ins={21'h00080,2'd2,5'd0,5'd16,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h161:
	begin
		next_ip=12'h162;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd17;
		instr.ins={21'h00088,2'd2,5'd0,5'd17,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h162:
	begin
		next_ip=12'h163;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd18;
		instr.ins={21'h00090,2'd2,5'd0,5'd18,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h163:
	begin
		next_ip=12'h164;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd19;
		instr.ins={21'h00098,2'd2,5'd0,5'd19,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h164:
	begin
		next_ip=12'h165;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd20;
		instr.ins={21'h000A0,2'd2,5'd0,5'd20,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h165:
	begin
		next_ip=12'h166;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd21;
		instr.ins={21'h000A8,2'd2,5'd0,5'd21,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h166:
	begin
		next_ip=12'h167;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd22;
		instr.ins={21'h000B0,2'd2,5'd0,5'd22,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h167:
	begin
		next_ip=12'h168;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd23;
		instr.ins={21'h000B8,2'd2,5'd0,5'd23,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h168:
	begin
		next_ip=12'h169;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd24;
		instr.ins={21'h000C0,2'd2,5'd0,5'd24,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h169:
	begin
		next_ip=12'h16A;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd25;
		instr.ins={21'h000C8,2'd2,5'd0,5'd25,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h16A:
	begin
		next_ip=12'h16B;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd26;
		instr.ins={21'h000D0,2'd2,5'd0,5'd26,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h16B:
	begin
		next_ip=12'h16C;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd27;
		instr.ins={21'h000D8,2'd2,5'd0,5'd27,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h16C:
	begin
		next_ip=12'h16D;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd28;
		instr.ins={21'h000E0,2'd2,5'd0,5'd28,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h16D:
	begin
		next_ip=12'h16E;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd29;
		instr.ins={21'h000E8,2'd2,5'd0,5'd29,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h16E:
	begin
		next_ip=12'h16F;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd30;
		instr.ins={21'h000F0,2'd2,5'd0,5'd30,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h16F:
	begin
		next_ip=12'h170;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd31;
		instr.ins={21'h000F8,2'd2,5'd0,5'd31,Qupls4_pkg::OP_LDx};
		instr.pred_btst=6'd0;
	end
12'h170:	begin next_ip = 12'h000; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end
12'h171:	begin next_ip = 12'h000; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end
12'h172:	begin next_ip = 12'h000; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end
12'h173:	begin next_ip = 12'h000; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end
*/
// -----------------------------------------------------------------------------
// RESET...
// This to prime the renamer and TLB.
// -----------------------------------------------------------------------------
12'h1A0:	
	begin
		next_ip = 12'h1A1;
		instr.ins = {1'b1,14'd1,1'b0,5'h00,MC0[4:0],Qupls4_pkg::OP_ADD};
	end
12'h1A1:
	begin
		next_ip = 12'h1A2;
		instr.ins = {1'b1,14'd2,1'b0,5'h00,MC0[4:0],Qupls4_pkg::OP_ADD};
	end
12'h1A2:
	begin
		next_ip = 12'h1A3;
		instr.ins = {1'b1,14'd3,1'b0,5'h00,MC0[4:0],Qupls4_pkg::OP_ADD};
	end
12'h1A3:
	begin
		next_ip = 12'h1A4;
		instr.ins = {1'b1,14'd4,1'b0,5'h00,MC0[4:0],Qupls4_pkg::OP_ADD};
	end
12'h1A4:
	begin
		next_ip = 12'h1A5;
		instr.ins = {1'b1,14'd5,1'b0,5'h00,MC0[4:0],Qupls4_pkg::OP_ADD};
	end
12'h1A5:
	begin
		next_ip = 12'h1A6;
		instr.ins = {1'b1,14'd6,1'b0,5'h00,MC0[4:0],Qupls4_pkg::OP_ADD};
	end
12'h1A6:
	begin
		next_ip = 12'h1A7;
		instr.ins = {1'b1,14'd7,1'b0,5'h00,MC0[4:0],Qupls4_pkg::OP_ADD};
	end
12'h1A7:
	begin
		next_ip = 12'h1A8;
		instr.ins = {1'b1,14'd8,1'b0,5'h00,MC0[4:0],Qupls4_pkg::OP_ADD};
	end
12'h1A8:
	begin
		next_ip = 12'h1A9;
		instr.ins = {1'b1,14'd9,1'b0,5'h00,MC0[4:0],Qupls4_pkg::OP_ADD};
	end
12'h1A9:
	begin
		next_ip = 12'h1AA;
		instr.ins = {1'b1,14'd10,1'b0,5'h00,MC0[4:0],Qupls4_pkg::OP_ADD};
	end
12'h1AA:
	begin
		next_ip = 12'h1AB;
		instr.ins = {1'b1,14'd11,1'b0,5'h00,MC0[4:0],Qupls4_pkg::OP_ADD};
	end
12'h1AB:
	begin
		next_ip = 12'h1AC;
		instr.ins = {1'b1,14'd12,1'b0,5'h00,MC0[4:0],Qupls4_pkg::OP_ADD};
	end
12'h1AC:
	begin
		next_ip = 12'h1AD;
		instr.ins = {1'b1,14'd13,1'b0,5'h00,MC0[4:0],Qupls4_pkg::OP_ADD};
	end
12'h1AD:
	begin
		next_ip = 12'h1AE;
		instr.ins = {1'b1,14'd14,1'b0,5'h00,MC0[4:0],Qupls4_pkg::OP_ADD};
	end
12'h1AE:
	begin
		next_ip = 12'h1AF;
		instr.ins = {1'b1,14'd15,1'b0,5'h00,MC0[4:0],Qupls4_pkg::OP_ADD};
	end
12'h1AF:
	begin
		next_ip = 12'h1B0;
		instr.ins = {1'b1,14'd16,1'b0,5'h00,MC0[4:0],Qupls4_pkg::OP_ADD};
	end
12'h1B0:
	begin
		next_ip = 12'h1B1;
		instr.ins = {1'b1,14'd17,1'b0,5'h00,MC0[4:0],Qupls4_pkg::OP_ADD};
	end
12'h1B1:
	begin
		next_ip = 12'h1B2;
		instr.ins = {1'b1,14'd18,1'b0,5'h00,MC0[4:0],Qupls4_pkg::OP_ADD};
	end
12'h1B2:
	begin
		next_ip = 12'h1B3;
		instr.ins = {1'b1,14'd19,1'b0,5'h00,MC0[4:0],Qupls4_pkg::OP_ADD};
	end
12'h1B3:
	begin
		next_ip = 12'h1B4;
		instr.ins = {1'b1,14'd20,1'b0,5'h00,MC0[4:0],Qupls4_pkg::OP_ADD};
	end
12'h1B4:
	begin
		next_ip = 12'h1B5;
		instr.ins = {1'b1,14'd21,1'b0,5'h00,MC0[4:0],Qupls4_pkg::OP_ADD};
	end
12'h1B5:
	begin
		next_ip = 12'h1B6;
		instr.ins = {1'b1,14'd22,1'b0,5'h00,MC0[4:0],Qupls4_pkg::OP_ADD};
	end
12'h1B6:
	begin
		next_ip = 12'h1B7;
		instr.ins = {1'b1,14'd23,1'b0,5'h00,MC0[4:0],Qupls4_pkg::OP_ADD};
	end
12'h1B7:
	begin
		next_ip = 12'h1B8;
		instr.ins = {1'b1,14'd24,1'b0,5'h00,MC0[4:0],Qupls4_pkg::OP_ADD};
	end
12'h1B8:	
	begin
		next_ip = 12'h1B9;
		instr.ins = {26'd0,Qupls4_pkg::OP_NOP};
	end
/*
12'h1B9:	
	begin 
		next_ip = 12'h1BA;
		instr.ins = {20'hFFFE0,2'd2,5'd0,SP,1'b0,Qupls4_pkg::OP_LDx};
		instr.aRt = MSP;
	end			// SP = Mem[FFFFFFE0]
12'h1BA:
	begin
		next_ip = 12'h1BB;
		instr.ins = {20'hFFFE8,2'd2,5'd0,5'd1,1'b0,Qupls4_pkg::OP_LDx};
		instr.aRt = MC0;
	end			// PC = Mem[FFFFFFE8]
*/
12'h1B9:	
	begin
		next_ip = 12'h1BA;
		instr.ins = {1'b1,22'h3FFEC0,3'd0,Qupls4_pkg::OP_B0};	// FFFFFD80
	end
12'h1BA:	
	begin
		next_ip = 12'h1BB;
		instr.ins = {26'd0,Qupls4_pkg::OP_NOP};
	end
12'h1BB:	
	begin
		next_ip = 12'h1BC;
		instr.ins = {26'd0,Qupls4_pkg::OP_NOP};
	end
12'h1BC:	
	begin
		next_ip = 12'h000;
		instr.ins = {26'd0,Qupls4_pkg::OP_NOP};
	end
12'h1BD:	
	begin
		next_ip = 12'h000;
		instr.ins = {26'd0,Qupls4_pkg::OP_NOP};
	end
12'h1BE:	
	begin
		next_ip = 12'h000;
		instr.ins = {26'd0,Qupls4_pkg::OP_NOP};
	end
12'h1BF:	
	begin
		next_ip = 12'h000;
		instr.ins = {26'd0,Qupls4_pkg::OP_NOP};
	end

// -----------------------------------------------------------------------------
// LEAVE
// - reverses out the ENTER operation
//	leave 5,32		; leave <saved regs>,stack deallocate
//
// Implements the following instructions:
//	sub sp,sp,NS*8
//	if (NS>0) ldo s0,[sp]
//	if (NS>1) ldo s1,8[sp]
//	...
//	if (NS>9) ldo s9,72[sp]
//  mov sp,fp
//  ldo fp[sp]
//	ldo lr0,8[sp]
//  add sp,sp,32
//	add sp,sp,<constant23
//	addm sp,sp,?constant23
//  jmp const6[lr0]
//
// -----------------------------------------------------------------------------
/*
12'h1D0:
	begin
		next_ip = 12'h1D1;
		instr.ins = {-{14'd0,ir[16:13],3'd0},2'd2,FP,SP,Qupls4_pkg::OP_ADDI};
		instr.aRa = {4'd0,FP};
		case(om)
		2'd0:	instr.aRt = SUSP;
		2'd1:	instr.aRt = SSSP;
		2'd2:	instr.aRt = SHSP;
		2'd3:	instr.aRt = MSP;
		endcase
	end		// SP = FP-NS*8
12'h1D1:
	begin
		if (ir[16:13]>4'd0) begin
			next_ip = 12'h1D2;
			instr.ins = {21'h000000,2'd2,SP,S0,Qupls4_pkg::OP_LDx};
			case(om)
			2'd0:	instr.aRa = SUSP;
			2'd1:	instr.aRa = SSSP;
			2'd2:	instr.aRa = SHSP;
			2'd3:	instr.aRa = MSP;
			endcase
			instr.aRc = 9'd0;
			instr.aRt = S0;
		end
		else begin
			next_ip = 12'h1DB;
			instr.ins = {41'd0,Qupls4_pkg::OP_NOP};
		end
	end
12'h1D2:
	begin
		if (ir[16:13]>4'd1) begin
			next_ip = 12'h1D3;
			instr.ins = {21'h000008,2'd2,SP,S1,Qupls4_pkg::OP_LDx};
			case(om)
			2'd0:	instr.aRa = SUSP;
			2'd1:	instr.aRa = SSSP;
			2'd2:	instr.aRa = SHSP;
			2'd3:	instr.aRa = MSP;
			endcase
			instr.aRc = 9'd0;
			instr.aRt = S1;
		end
		else begin
			next_ip = 12'h1DB;
			instr.ins = {41'd0,Qupls4_pkg::OP_NOP};
		end
	end
12'h1D3:
	begin
		if (ir[16:13]>4'd2) begin
			next_ip = 12'h1D4;
			instr.ins = {21'h000010,2'd2,SP,S2,Qupls4_pkg::OP_LDx};
			case(om)
			2'd0:	instr.aRa = SUSP;
			2'd1:	instr.aRa = SSSP;
			2'd2:	instr.aRa = SHSP;
			2'd3:	instr.aRa = MSP;
			endcase
			instr.aRc = 9'd0;
			instr.aRt = S2;
		end
		else begin
			next_ip = 12'h1DB;
			instr.ins = {41'd0,Qupls4_pkg::OP_NOP};
		end
	end
12'h1D4:
	begin
		if (ir[16:13]>4'd3) begin
			next_ip = 12'h1D5;
			instr.ins = {21'h000018,2'd2,SP,S3,Qupls4_pkg::OP_LDx};
			case(om)
			2'd0:	instr.aRa = SUSP;
			2'd1:	instr.aRa = SSSP;
			2'd2:	instr.aRa = SHSP;
			2'd3:	instr.aRa = MSP;
			endcase
			instr.aRc = 9'd0;
			instr.aRt = S3;
		end
		else begin
			next_ip = 12'h1DB;
			instr.ins = {41'd0,Qupls4_pkg::OP_NOP};
		end
	end
12'h1D5:
	begin
		if (ir[16:13]>4'd4) begin
			next_ip = 12'h1D6;
			instr.ins = {21'h000020,2'd2,SP,S4,Qupls4_pkg::OP_LDx};
			case(om)
			2'd0:	instr.aRa = SUSP;
			2'd1:	instr.aRa = SSSP;
			2'd2:	instr.aRa = SHSP;
			2'd3:	instr.aRa = MSP;
			endcase
			instr.aRc = 9'd0;
			instr.aRt = S4;
		end
		else begin
			next_ip = 12'h1DB;
			instr.ins = {41'd0,Qupls4_pkg::OP_NOP};
		end
	end
12'h1D6:
	begin
		if (ir[16:13]>4'd5) begin
			next_ip = 12'h1D7;
			instr.ins = {21'h000028,2'd2,SP,S5,Qupls4_pkg::OP_LDx};
			case(om)
			2'd0:	instr.aRa = SUSP;
			2'd1:	instr.aRa = SSSP;
			2'd2:	instr.aRa = SHSP;
			2'd3:	instr.aRa = MSP;
			endcase
			instr.aRc = 9'd0;
			instr.aRt = S5;
		end
		else begin
			next_ip = 12'h1DB;
			instr.ins = {41'd0,Qupls4_pkg::OP_NOP};
		end
	end
12'h1D7:
	begin
		if (ir[16:13]>4'd6) begin
			next_ip = 12'h1D8;
			instr.ins = {21'h000030,2'd2,SP,S6,Qupls4_pkg::OP_LDx};
			case(om)
			2'd0:	instr.aRa = SUSP;
			2'd1:	instr.aRa = SSSP;
			2'd2:	instr.aRa = SHSP;
			2'd3:	instr.aRa = MSP;
			endcase
			instr.aRc = 9'd0;
			instr.aRt = S6;
		end
		else begin
			next_ip = 12'h1DB;
			instr.ins = {41'd0,Qupls4_pkg::OP_NOP};
		end
	end
12'h1D8:
	begin
		if (ir[16:13]>4'd7) begin
			next_ip = 12'h1D9;
			instr.ins = {21'h000038,2'd2,SP,S7,Qupls4_pkg::OP_LDx};
			case(om)
			2'd0:	instr.aRa = SUSP;
			2'd1:	instr.aRa = SSSP;
			2'd2:	instr.aRa = SHSP;
			2'd3:	instr.aRa = MSP;
			endcase
			instr.aRc = 9'd0;
			instr.aRt = S7;
		end
		else begin
			next_ip = 12'h1DB;
			instr.ins = {41'd0,Qupls4_pkg::OP_NOP};
		end
	end
12'h1D9:
	begin
		if (ir[16:13]>4'd8) begin
			next_ip = 12'h1DA;
			instr.ins = {21'h000040,2'd2,SP,S8,Qupls4_pkg::OP_LDx};
			case(om)
			2'd0:	instr.aRa = SUSP;
			2'd1:	instr.aRa = SSSP;
			2'd2:	instr.aRa = SHSP;
			2'd3:	instr.aRa = MSP;
			endcase
			instr.aRc = 9'd0;
			instr.aRt = S8;
		end
		else begin
			next_ip = 12'h1DB;
			instr.ins = {41'd0,Qupls4_pkg::OP_NOP};
		end
	end
12'h1DA:
	begin
		if (ir[16:13]>4'd9) begin
			next_ip = 12'h1DB;
			instr.ins = {21'h000048,2'd2,SP,S8,Qupls4_pkg::OP_LDx};
			case(om)
			2'd0:	instr.aRa = SUSP;
			2'd1:	instr.aRa = SSSP;
			2'd2:	instr.aRa = SHSP;
			2'd3:	instr.aRa = MSP;
			endcase
			instr.aRc = 9'd0;
			instr.aRt = S8;
		end
		else begin
			next_ip = 12'h1DB;
			instr.ins = {41'd0,Qupls4_pkg::OP_NOP};
		end
	end

12'h1DB:	// mov sp,fp
	begin
		next_ip = 12'h1DC;
		instr.ins = {21'h000000,2'd2,FP,SP,Qupls4_pkg::OP_ORI};
		instr.aRa = FP;
		case(om)
		2'd0:	instr.aRt = SUSP;
		2'd1:	instr.aRt = SSSP;
		2'd2:	instr.aRt = SHSP;
		2'd3:	instr.aRt = MSP;
		endcase
	end
12'h1DC:	// ldo fp,[sp]
	begin
		next_ip = 12'h1DD;
		instr.ins = {21'h000000,2'd2,SP,FP,Qupls4_pkg::OP_LDx};
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRt = FP;
	end
12'h1DD:	// ldo lr0,8[sp]
	begin
		next_ip = 12'h1DE;
		instr.ins = {21'h000008,2'd2,SP,5'd1,Qupls4_pkg::OP_LDx};
		instr.aRt = LR0;
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
	end
12'h1DE:	// add sp,sp,32
	begin
		next_ip = 12'h1DF;
		instr.ins = {21'h000020,2'd2,SP,SP,Qupls4_pkg::OP_ADDI};
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		case(om)
		2'd0:	instr.aRt = SUSP;
		2'd1:	instr.aRt = SSSP;
		2'd2:	instr.aRt = SHSP;
		2'd3:	instr.aRt = MSP;
		endcase
	end
12'h1DF:	// add sp,sp,Constant23
	begin 
		next_ip = 12'h1E0;
		instr.ins = {ir[37:17],2'd2,SP,SP,Qupls4_pkg::OP_ADDI};
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		case(om)
		2'd0:	instr.aRt = SUSP;
		2'd1:	instr.aRt = SSSP;
		2'd2:	instr.aRt = SHSP;
		2'd3:	instr.aRt = MSP;
		endcase
	end	
12'h1E0:	// add sp,sp,constant23
	begin 
		next_ip = 12'h1E1;
		instr.ins = {21'd0,ir[39:38],2'd3,3'd1,SP,Qupls4_pkg::OP_NOP};
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		case(om)
		2'd0:	instr.aRt = SUSP;
		2'd1:	instr.aRt = SSSP;
		2'd2:	instr.aRt = SHSP;
		2'd3:	instr.aRt = MSP;
		endcase
	end	
12'h1E1:	// jmp Const6[lr0]
	begin
		next_ip = 12'h1E2;
		instr.ins = {16'd0,ir[11:7],2'd2,5'd1,5'd0,Qupls4_pkg::OP_JSR};
		instr.aRa = LR0;
		instr.aRt = 9'd0;
	end
12'h1E2:	begin next_ip = 12'h000; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end
12'h1E3:	begin next_ip = 12'h000; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end
12'h1E4:	begin next_ip = 12'h1E5; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end
12'h1E5:	begin next_ip = 12'h1E6; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end
12'h1E6:	begin next_ip = 12'h1E7; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end
12'h1E7:	begin next_ip = 12'h1D0; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end
*/
/*
// -----------------------------------------------------------------------------
// sto s0s4
// -----------------------------------------------------------------------------
12'h240:
	begin
		next_ip = 12'h244;
		instr.aRa = {4'd0,ir.Ra};
		instr.aRb = 10'd0;
		instr.aRc = {4'd0,S0};
		instr.aRt = 10'd0;
		instr.ins = {21'h000000,ir.Ra,S0,Qupls4_pkg::OP_STx};
		instr.pred_btst = 6'd0;
	end
12'h241:
	begin
		next_ip = 12'h244;
		instr.aRa = {4'd0,ir.Ra};
		instr.aRb = 10'd0;
		instr.aRc = {4'd0,S1};
		instr.aRt = 10'd0;
		instr.ins = {21'h000008,ir.Ra,S1,Qupls4_pkg::OP_STx};
		instr.pred_btst = 6'd0;
	end
12'h242:
	begin
		next_ip = 12'h244;
		instr.aRa = {4'd0,ir.Ra};
		instr.aRb = 10'd0;
		instr.aRc = {4'd0,S2};
		instr.aRt = 10'd0;
		instr.ins = {21'h000010,ir.Ra,S2,Qupls4_pkg::OP_STx};
		instr.pred_btst = 6'd0;
	end
12'h243:
	begin
		next_ip = 12'h244;
		instr.aRa = {4'd0,ir.Ra};
		instr.aRb = 10'd0;
		instr.aRc = {4'd0,S3};
		instr.aRt = 10'd0;
		instr.ins = {21'h000018,ir.Ra,S3,Qupls4_pkg::OP_STx};
		instr.pred_btst = 6'd0;
	end
12'h244:
	begin
		next_ip = 12'h000;
		instr.aRa = {4'd0,ir.Ra};
		instr.aRb = 10'd0;
		instr.aRc = {4'd0,S4};
		instr.aRt = 10'd0;
		instr.ins = {21'h000018,ir.Ra,S4,Qupls4_pkg::OP_STx};
		instr.pred_btst = 6'd0;
	end
12'h245:	begin next_ip = 12'h000; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end
12'h246:	begin next_ip = 12'h000; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end
12'h247:	begin next_ip = 12'h000; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end

// -----------------------------------------------------------------------------
// push vn
// -----------------------------------------------------------------------------
12'h260:
	begin
		next_ip = 12'h264;
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		case(om)
		2'd0:	instr.aRt = SUSP;
		2'd1:	instr.aRt = SSSP;
		2'd2:	instr.aRt = SHSP;
		2'd3:	instr.aRt = MSP;
		endcase
		instr.aRb = 10'd0;
		instr.aRc = {4'd0,6'd1};
		instr.ins = {19'h7FFC0,2'd2,SP,SP,Qupls4_pkg::OP_ADDI};
		instr.pred_btst = 6'd0;
	end
12'h261:
	begin
		next_ip = 12'h264;
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRb = 10'd0;
		instr.aRc = {1'd0,ir[12:7],3'd0};
		instr.aRt = 10'd0;
		instr.ins = {19'h000000,2'd2,SP,6'd0,Qupls4_pkg::OP_STx};
		instr.pred_btst = 6'd0;
	end
12'h262:
	begin
		next_ip = 12'h264;
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRb = 10'd0;
		instr.aRc = {1'd0,ir[12:7],3'd1};
		instr.aRt = 10'd0;
		instr.ins = {19'h00008,2'd2,SP,6'd1,Qupls4_pkg::OP_STx};
		instr.pred_btst = 6'd0;
	end
12'h263:
	begin
		next_ip = 12'h264;
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRb = 10'd0;
		instr.aRc = {1'd0,ir[12:7],3'd2};
		instr.aRt = 10'd0;
		instr.ins = {19'h00010,2'd2,SP,6'd2,Qupls4_pkg::OP_STx};
		instr.pred_btst = 6'd0;
	end
12'h264:
	begin
		next_ip = 12'h268;
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRb = 10'd0;
		instr.aRc = {1'd0,ir[12:7],3'd3};
		instr.aRt = 10'd0;
		instr.ins = {19'h00018,2'd2,SP,6'd3,Qupls4_pkg::OP_STx};
		instr.pred_btst = 6'd0;
	end
12'h265:
	begin
		next_ip = 12'h268;
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRb = 10'd0;
		instr.aRc = {1'd0,ir[12:7],3'd4};
		instr.aRt = 10'd0;
		instr.ins = {19'h00020,2'd2,SP,6'd4,Qupls4_pkg::OP_STx};
		instr.pred_btst = 6'd0;
	end
12'h266:
	begin
		next_ip = 12'h268;
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRb = 10'd0;
		instr.aRc = {1'd0,ir[12:7],3'd5};
		instr.aRt = 10'd0;
		instr.ins = {19'h00028,2'd2,SP,6'd5,Qupls4_pkg::OP_STx};
		instr.pred_btst = 6'd0;
	end
12'h267:
	begin
		next_ip = 12'h268;
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRb = 10'd0;
		instr.aRc = {1'd0,ir[12:7],3'd6};
		instr.aRt = 10'd0;
		instr.ins = {19'h00030,2'd2,SP,6'd6,Qupls4_pkg::OP_STx};
		instr.pred_btst = 6'd0;
	end
12'h268:
	begin
		next_ip = 12'h000;
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRb = 10'd0;
		instr.aRc = {1'd0,ir[12:7],3'd7};
		instr.aRt = 10'd0;
		instr.ins = {19'h00038,2'd2,SP,6'd7,Qupls4_pkg::OP_STx};
		instr.pred_btst = 6'd0;
	end
12'h269:	begin next_ip = 12'h000; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end
12'h26A:	begin next_ip = 12'h000; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end
12'h26B:	begin next_ip = 12'h000; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end

// -----------------------------------------------------------------------------
// pusha
// -----------------------------------------------------------------------------
12'h300:
	begin
		next_ip=12'h301;
		instr.ins={41'd0,Qupls4_pkg::OP_NOP};
	end
12'h301:
	begin
		next_ip=12'h302;
		instr.ins={41'd0,Qupls4_pkg::OP_NOP};
	end
12'h302:
	begin
		next_ip=12'h303;
		instr.ins={41'd0,Qupls4_pkg::OP_NOP};
	end
12'h303:
	begin
		next_ip=12'h304;
		instr.ins={41'd0,Qupls4_pkg::OP_NOP};
	end
12'h304:
	begin
		next_ip=12'h305;
		instr.aRa=9'd32|om;
		instr.aRt=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.ins={21'h1FFF00,2'd2,SP,SP,Qupls4_pkg::OP_ADDI};
		instr.pred_btst=6'd0;
	end
12'h306:
	begin
		next_ip=12'h307;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd1;
		if (ir[0])
			instr.ins={21'h00008,2'd2,SP,5'd1,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h307:
	begin
		next_ip=12'h308;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd2;
		if (ir[1])
			instr.ins={21'h00010,2'd2,SP,5'd2,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h308:
	begin
		next_ip=12'h309;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd3;
		if (ir[2])
			instr.ins={21'h00018,2'd2,SP,5'd3,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h309:
	begin
		next_ip=12'h30A;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd4;
		if (ir[3])
			instr.ins={21'h00020,2'd2,SP,5'd4,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h30A:
	begin
		next_ip=12'h30B;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd5;
		if (ir[4])
			instr.ins={21'h00028,2'd2,SP,5'd5,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h30B:
	begin
		next_ip=12'h30C;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd6;
		if (ir[5])
			instr.ins={21'h00030,2'd2,SP,5'd6,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h30C:
	begin
		next_ip=12'h30D;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd7;
		if (ir[6])
			instr.ins={21'h00038,2'd2,SP,5'd7,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h30D:
	begin
		next_ip=12'h30E;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd8;
		if (ir[7])
			instr.ins={21'h00040,2'd2,SP,5'd8,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h30E:
	begin
		next_ip=12'h30F;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd9;
		if (ir[8])
			instr.ins={21'h00048,2'd2,SP,5'd9,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h30F:
	begin
		next_ip=12'h310;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd10;
		if (ir[9])
			instr.ins={21'h00050,2'd2,SP,5'd10,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h310:
	begin
		next_ip=12'h311;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd11;
		if (ir[10])
			instr.ins={21'h00058,2'd2,SP,5'd11,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h311:
	begin
		next_ip=12'h312;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd12;
		if (ir[11])
			instr.ins={21'h00060,2'd2,SP,5'd12,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h312:
	begin
		next_ip=12'h313;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd13;
		if (ir[12])
			instr.ins={21'h00068,2'd2,SP,5'd13,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h313:
	begin
		next_ip=12'h314;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd14;
		if (ir[13])
			instr.ins={21'h00070,2'd2,SP,5'd14,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h314:
	begin
		next_ip=12'h315;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd15;
		if (ir[14])
			instr.ins={21'h00078,2'd2,SP,5'd15,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h315:
	begin
		next_ip=12'h316;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd16;
		if (ir[15])
			instr.ins={21'h00080,2'd2,SP,5'd16,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h316:
	begin
		next_ip=12'h317;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd17;
		if (ir[16])
			instr.ins={21'h00088,2'd2,SP,5'd17,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h317:
	begin
		next_ip=12'h318;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd18;
		if (ir[17])
			instr.ins={21'h00090,2'd2,SP,5'd18,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h318:
	begin
		next_ip=12'h319;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd19;
		if (ir[18])
			instr.ins={21'h00098,2'd2,SP,5'd19,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h319:
	begin
		next_ip=12'h31A;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd20;
		if (ir[19])
			instr.ins={21'h000A0,2'd2,SP,5'd20,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h31A:
	begin
		next_ip=12'h31B;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd21;
		if (ir[20])
			instr.ins={21'h000A8,2'd2,SP,5'd21,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h31B:
	begin
		next_ip=12'h31C;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd22;
		if (ir[21])
			instr.ins={21'h000B0,2'd2,SP,5'd22,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h31C:
	begin
		next_ip=12'h31D;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd23;
		if (ir[22])
			instr.ins={21'h000B8,2'd2,SP,5'd23,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h31D:
	begin
		next_ip=12'h31E;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd24;
		if (ir[23])
			instr.ins={21'h000C0,2'd2,SP,5'd24,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h31E:
	begin
		next_ip=12'h31F;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd25;
		if (ir[24])
			instr.ins={21'h000C8,2'd2,SP,5'd25,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h31F:
	begin
		next_ip=12'h320;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd26;
		if (ir[25])
			instr.ins={21'h000D0,2'd2,SP,5'd26,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h320:
	begin
		next_ip=12'h321;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd27;
		if (ir[26])
			instr.ins={21'h000D8,2'd2,SP,5'd27,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h321:
	begin
		next_ip=12'h322;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd28;
		if (ir[27])
			instr.ins={21'h000E0,2'd2,SP,5'd28,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h322:
	begin
		next_ip=12'h323;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd29;
		if (ir[28])
			instr.ins={21'h000E8,2'd2,SP,5'd29,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h323:
	begin
		next_ip=12'h324;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd30;
		if (ir[29])
			instr.ins={21'h000F0,2'd2,SP,5'd30,Qupls4_pkg::OP_STx};
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h324:
	begin
		next_ip=12'h325;
		instr.ins={30'd5,3'd0,Qupls4_pkg::OP_BSR};
	end
12'h325:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,Qupls4_pkg::OP_NOP};
	end
12'h326:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,Qupls4_pkg::OP_NOP};
	end
12'h327:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,Qupls4_pkg::OP_NOP};
	end
12'h328:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,Qupls4_pkg::OP_NOP};
	end

// -----------------------------------------------------------------------------
// pushi
// -----------------------------------------------------------------------------
12'h330:
	begin
		next_ip=12'h331;
		instr.ins={41'd0,Qupls4_pkg::OP_NOP};
	end
12'h331:
	begin
		next_ip=12'h332;
		instr.ins={41'd0,Qupls4_pkg::OP_NOP};
	end
12'h332:
	begin
		next_ip=12'h333;
		instr.ins={41'd0,Qupls4_pkg::OP_NOP};
	end
12'h333:
	begin
		next_ip=12'h334;
		instr.ins={41'd0,Qupls4_pkg::OP_NOP};
	end
12'h334:
	begin
		next_ip=12'h335;
		instr.aRa=9'd32|om;
		instr.aRt=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.ins={21'h1FFFF8,2'd2,SP,SP,Qupls4_pkg::OP_ADDI};
	end
12'h335:
	begin
		next_ip=12'h336;
		instr.aRa=9'd0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=MC0;
		instr.ins={ir[26:8],2'd2,5'd0,5'd1,Qupls4_pkg::OP_ORI};
	end
12'h336:
	begin
		next_ip=12'h337;
		instr.aRa=9'd0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=MC0;
		instr.ins={{{10{ir[39]}},ir[39:27]},2'd2,3'd1,5'd1,Qupls4_pkg::OP_NOP};
	end
12'h337:
	begin
		next_ip=12'h338;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=MC0;
		instr.aRt=9'd0;
		instr.ins={21'h00000,2'd2,SP,5'd1,Qupls4_pkg::OP_STx};
		instr.pred_btst=6'd0;
	end
12'h338:
	begin
		next_ip=12'h339;
		instr.ins={30'd5,3'd0,Qupls4_pkg::OP_BSR};
	end
12'h339:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,Qupls4_pkg::OP_NOP};
	end
12'h33A:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,Qupls4_pkg::OP_NOP};
	end
12'h33B:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,Qupls4_pkg::OP_NOP};
	end

// -----------------------------------------------------------------------------
// popa
// -----------------------------------------------------------------------------
12'h360:
	begin
		next_ip=12'h361;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[0]) begin
			instr.aRt=9'd1;
			instr.ins={21'h00008,2'd2,SP,5'd1,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h361:
	begin
		next_ip=12'h362;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[1]) begin
			instr.aRt=9'd2;
			instr.ins={21'h00010,2'd2,SP,5'd2,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h362:
	begin
		next_ip=12'h363;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[2]) begin
			instr.aRt=9'd3;
			instr.ins={21'h00018,2'd2,SP,5'd3,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h363:
	begin
		next_ip=12'h364;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[3]) begin
			instr.aRt=9'd4;
			instr.ins={21'h00020,2'd2,SP,5'd4,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h364:
	begin
		next_ip=12'h365;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[4]) begin
			instr.aRt=9'd5;
			instr.ins={21'h00028,2'd2,SP,5'd5,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h365:
	begin
		next_ip=12'h366;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[5]) begin
			instr.aRt=9'd6;
			instr.ins={21'h00030,2'd2,SP,5'd6,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h366:
	begin
		next_ip=12'h367;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[6]) begin
			instr.aRt=9'd7;
			instr.ins={21'h00038,2'd2,SP,5'd7,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h367:
	begin
		next_ip=12'h368;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[7]) begin
			instr.aRt=9'd8;
			instr.ins={21'h00040,2'd2,SP,5'd8,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h368:
	begin
		next_ip=12'h369;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[8]) begin
			instr.aRt=9'd9;
			instr.ins={21'h00048,2'd2,SP,5'd9,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h369:
	begin
		next_ip=12'h36A;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[9]) begin
			instr.aRt=9'd10;
			instr.ins={21'h00050,2'd2,SP,5'd10,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h36A:
	begin
		next_ip=12'h36B;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[10]) begin
			instr.aRt=9'd11;
			instr.ins={21'h00058,2'd2,SP,5'd11,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h36B:
	begin
		next_ip=12'h36C;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[11]) begin
			instr.aRt=9'd12;
			instr.ins={21'h00060,2'd2,SP,5'd12,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h36C:
	begin
		next_ip=12'h36D;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[12]) begin
			instr.aRt=9'd13;
			instr.ins={21'h00068,2'd2,SP,5'd13,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h36D:
	begin
		next_ip=12'h36E;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[13]) begin
			instr.aRt=9'd14;
			instr.ins={21'h00070,2'd2,SP,5'd14,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h36E:
	begin
		next_ip=12'h36F;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[14]) begin
			instr.aRt=9'd15;
			instr.ins={21'h00078,2'd2,SP,5'd15,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h36F:
	begin
		next_ip=12'h370;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[15]) begin
			instr.aRt=9'd16;
			instr.ins={21'h00080,2'd2,SP,5'd16,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h370:
	begin
		next_ip=12'h371;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[16]) begin
			instr.aRt=9'd17;
			instr.ins={21'h00088,2'd2,SP,5'd17,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h371:
	begin
		next_ip=12'h372;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[17]) begin
			instr.aRt=9'd18;
			instr.ins={21'h00090,2'd2,SP,5'd18,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h372:
	begin
		next_ip=12'h373;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[18]) begin
			instr.aRt=9'd19;
			instr.ins={21'h00098,2'd2,SP,5'd19,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h373:
	begin
		next_ip=12'h374;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[19]) begin
			instr.aRt=9'd20;
			instr.ins={21'h000A0,2'd2,SP,5'd20,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h374:
	begin
		next_ip=12'h375;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[20]) begin
			instr.aRt=9'd21;
			instr.ins={21'h000A8,2'd2,SP,5'd21,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h375:
	begin
		next_ip=12'h376;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[21]) begin
			instr.aRt=9'd22;
			instr.ins={21'h000B0,2'd2,SP,5'd22,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h376:
	begin
		next_ip=12'h377;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[22]) begin
			instr.aRt=9'd23;
			instr.ins={21'h000B8,2'd2,SP,5'd23,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h377:
	begin
		next_ip=12'h378;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[23]) begin
			instr.aRt=9'd24;
			instr.ins={21'h000C0,2'd2,SP,5'd24,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h378:
	begin
		next_ip=12'h379;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[24]) begin
			instr.aRt=9'd25;
			instr.ins={21'h000C8,2'd2,SP,5'd25,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h379:
	begin
		next_ip=12'h37A;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[25]) begin
			instr.aRt=9'd26;
			instr.ins={21'h000D0,2'd2,SP,5'd26,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h37A:
	begin
		next_ip=12'h37B;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[26]) begin
			instr.aRt=9'd27;
			instr.ins={21'h000D8,2'd2,SP,5'd27,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h37B:
	begin
		next_ip=12'h37C;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[27]) begin
			instr.aRt=9'd28;
			instr.ins={21'h000E0,2'd2,SP,5'd28,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h37C:
	begin
		next_ip=12'h37D;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[28]) begin
			instr.aRt=9'd29;
			instr.ins={21'h000E8,2'd2,SP,5'd29,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h37D:
	begin
		next_ip=12'h37E;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (ir[29]) begin
			instr.aRt=9'd30;
			instr.ins={21'h000F0,2'd2,SP,5'd30,Qupls4_pkg::OP_LDx};
		end
		else
			instr.ins={41'd0,Qupls4_pkg::OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h37E:
	begin
		next_ip=12'h37F;
		instr.aRa=9'd32|om;
		instr.aRt=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.ins={21'h00100,2'd2,SP,SP,Qupls4_pkg::OP_ADDI};
		instr.pred_btst=6'd0;
	end
12'h37F:
	begin
		next_ip=12'h000;
		instr.ins={30'd5,3'd0,Qupls4_pkg::OP_BSR};
	end
12'h380:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,Qupls4_pkg::OP_NOP};
	end
12'h381:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,Qupls4_pkg::OP_NOP};
	end
12'h382:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,Qupls4_pkg::OP_NOP};
	end
12'h383:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,Qupls4_pkg::OP_NOP};
	end

// -----------------------------------------------------------------------------
// BSET
// -----------------------------------------------------------------------------
12'h390:
	begin
		next_ip=12'h391;
		instr.aRa={4'd0,ir[26:22]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd0;
		instr.ins = {18'd5,5'd0,5'd1,1'b0,4'd0,Qupls4_pkg::OP_Bcc};
	end
12'h391:
	begin
		next_ip=12'h392;
		instr.aRa={4'd0,ir[16:12]};
		instr.aRb=9'd0;
		instr.aRc={4'd0,ir[11:7]};
		instr.aRt=9'd0;
		instr.ins = {21'd0,2'd2,ir[16:12],ir[11:7],Qupls4_pkg::OP_STx};
		instr.ins.prc = ir[18:17];
	end
12'h392:
	begin
		next_ip=12'h393;
		instr.ins = {{{15{ir[38]}},ir[38:33]},2'd2,ir[16:12],ir[16:12],Qupls4_pkg::OP_ADDI};
		instr.aRa={4'd0,ir[16:12]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={4'd0,ir[16:12]};
	end
12'h393:
	begin
		next_ip=12'h390;
		instr.ins = {21'h1FFFFF,2'd2,5'd1,5'd1,Qupls4_pkg::OP_ADDI};
		instr.aRa={4'd0,ir[26:22]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={4'd0,ir[26:22]};
	end
12'h394:	begin next_ip = 12'h390; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end
12'h395:	begin next_ip = 12'h390; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end
12'h396:	begin next_ip = 12'h390; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end
12'h397:	begin next_ip = 12'h390; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end

// -----------------------------------------------------------------------------
// BMOV
// -----------------------------------------------------------------------------
12'h3A0:
	begin
		next_ip=12'h3A1;
		instr.aRa={4'd0,ir[26:22]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd0;
		instr.ins = {18'd5,5'd0,5'd1,1'b0,4'd0,Qupls4_pkg::OP_Bcc};
	end
12'h3A1:
	begin
		next_ip=12'h3A2;
		instr.ins = {21'd0,2'd2,ir[16:12],2'd1,Qupls4_pkg::OP_LDx};
		instr.aRa={4'd0,ir[16:12]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=MC0;
		instr.ins.opcode = Qupls4_pkg::OP_LDx;
		instr.ins.prc = ir[9:7];
	end
12'h3A2:
	begin
		next_ip=12'h3A3;
		instr.ins = {21'd0,2'd2,ir[21:17],2'd1,Qupls4_pkg::OP_STx};
		instr.aRa={3'd0,ir[21:17]};
		instr.aRb=9'd0;
		instr.aRc=MC0;
		instr.aRt=9'd0;
		instr.ins.opcode = Qupls4_pkg::OP_STx;
		instr.ins.prc = ir[9:7];
	end
12'h3A3:
	begin
		next_ip=12'h3A4;
		instr.ins = {{{15{ir[38]}},ir[38:33]},2'd2,ir[16:12],ir[16:12],Qupls4_pkg::OP_ADDI};
		instr.aRa={4'd0,ir[16:12]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={4'd0,ir[16:12]};
	end
12'h3A4:
	begin
		next_ip=12'h3A5;
		instr.ins = {{{15{ir[32]}},ir[32:27]},2'd2,ir[21:17],ir[21:17],Qupls4_pkg::OP_ADDI};
		instr.aRa={4'd0,ir[21:17]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={4'd0,ir[21:17]};
	end
12'h3A5:
	begin
		next_ip=12'h3A0;
		instr.ins = {21'h1FFFFF,2'd2,5'd1,5'd1,Qupls4_pkg::OP_ADDI};
		instr.aRa={4'd0,ir[26:22]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={4'd0,ir[26:22]};
	end
12'h3A6:	begin next_ip = 12'h3A0; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end
12'h3A7:	begin next_ip = 12'h3A0; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end

// -----------------------------------------------------------------------------
// BCMP
// -----------------------------------------------------------------------------
12'h3B0:
	begin
		next_ip=12'h3B1;
		instr.aRa={4'd0,ir[26:22]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd0;
		instr.ins = {18'd5,5'd0,5'd1,1'b0,4'd0,Qupls4_pkg::OP_Bcc};
	end
12'h3B1:
	begin
		next_ip=12'h3B2;
		instr.ins = {21'd0,2'd2,ir[16:12],2'd1,Qupls4_pkg::OP_LDx};
		instr.aRa={4'd0,ir[16:12]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=MC0;
		instr.ins.opcode = Qupls4_pkg::OP_LDx;
		instr.ins.prc = ir[9:7];
	end
12'h3B2:
	begin
		next_ip=12'h3B3;
		instr.ins = {21'd0,2'd2,ir[21:17],2'd1,Qupls4_pkg::OP_LDx};
		instr.aRa={4'd0,ir[21:17]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=MC1;
		instr.ins.opcode = Qupls4_pkg::OP_LDx;
		instr.ins.prc = ir[9:7];
	end
12'h3B3:
	begin
		next_ip=12'h3B4;
		instr.aRa={4'd0,ir[16:12]};
		instr.aRb={4'd0,ir[21:17]};
		instr.aRc=9'd0;
		instr.aRt=9'd0;
		instr.ins = {18'd5,ir[21:17],ir[16:12],1'b0,4'h0,Qupls4_pkg::OP_Bcc};
		case({ir[39],ir[11:10]})
		3'd0:	begin instr.ins.opcode = Qupls4_pkg::OP_Bcc; instr.ins.fn = EQ; end
		3'd1:	begin instr.ins.opcode = Qupls4_pkg::OP_Bcc; instr.ins.fn = NE; end
		3'd2:	begin instr.ins.opcode = Qupls4_pkg::OP_Bcc; instr.ins.fn = LT; end
		3'd3:	begin instr.ins.opcode = Qupls4_pkg::OP_Bcc; instr.ins.fn = LE; end
		3'd4:	begin instr.ins.opcode = Qupls4_pkg::OP_BccU; instr.ins.fn = LT; end
		3'd5:	begin instr.ins.opcode = Qupls4_pkg::OP_BccU; instr.ins.fn = LE; end
		default:	begin instr.ins.opcode = Qupls4_pkg::OP_Bcc; instr.ins.fn = EQ; end
		endcase	
	end
12'h3B4:
	begin
		next_ip=12'h3B5;
		instr.ins = {{{15{ir[38]}},ir[38:33]},2'd2,ir[16:12],ir[16:12],Qupls4_pkg::OP_ADDI};
		instr.aRa={4'd0,ir[16:12]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={4'd0,ir[16:12]};
	end
12'h3B5:
	begin
		next_ip=12'h3B6;
		instr.ins = {{{15{ir[32]}},ir[32:27]},2'd2,ir[21:17],ir[21:17],Qupls4_pkg::OP_ADDI};
		instr.aRa={4'd0,ir[21:17]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={4'd0,ir[21:17]};
	end
12'h3B6:
	begin
		next_ip=12'h3B0;
		instr.ins = {21'h1FFFFF,2'd2,5'd1,5'd1,Qupls4_pkg::OP_ADDI};
		instr.aRa={4'd0,ir[26:22]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={4'd0,ir[26:22]};
	end
12'h3B7:	begin next_ip = 12'h3B0; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end

// -----------------------------------------------------------------------------
// BFND
// -----------------------------------------------------------------------------
12'h3C0:
	begin
		next_ip=12'h3C1;
		instr.aRa={4'd0,ir[26:22]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd0;
		instr.ins = {18'd5,5'd0,5'd1,1'b0,4'd0,Qupls4_pkg::OP_Bcc};
	end
12'h3C1:
	begin
		next_ip=12'h3C2;
		instr.ins = {21'd0,2'd2,ir[21:17],2'd1,Qupls4_pkg::OP_LDx};
		instr.aRa={4'd0,ir[21:17]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=MC0;
		instr.ins.opcode = Qupls4_pkg::OP_LDx;
		instr.ins.prc = ir[9:7];
	end
12'h3C2:
	begin
		next_ip=12'h3C3;
		instr.ins = {18'd5,ir[21:17],ir[16:12],1'b0,4'h0,ir[39] ? Qupls4_pkg::OP_Bcc: Qupls4_pkg::OP_BccU};
		instr.aRa={4'd0,ir[16:12]};
		instr.aRb=MC0;
		instr.aRc=9'd0;
		instr.aRt=9'd0;
		instr.ins.fn = branch_fn_t'(ir[36:33]);
	end
12'h3C3:
	begin
		next_ip=12'h3C4;
		instr.ins = {{{15{ir[32]}},ir[32:27]},2'd2,ir[21:17],ir[21:17],Qupls4_pkg::OP_ADDI};
		instr.aRa={4'd0,ir[21:17]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={4'd0,ir[21:17]};
	end
12'h3C4:
	begin
		next_ip=12'h3C0;
		instr.ins = {21'h1FFFFF,2'd2,5'd1,5'd1,Qupls4_pkg::OP_ADDI};
		instr.aRa={4'd0,ir[26:22]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={4'd0,ir[26:22]};
	end
12'h3C5:	begin next_ip = 12'h3C0; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end
12'h3C6:	begin next_ip = 12'h3C0; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end
12'h3C7:	begin next_ip = 12'h3C0; instr.ins = {41'd0,Qupls4_pkg::OP_NOP};	end

12'h3D0:
	begin
		regno = {ir[28:27],ir[15:14],3'd0};
		mask = {ir[25:17],ir[13:6]};
		next_ip = |mask ? 12'h3D1 : 12'h3D8;
	end
12'h3D1:
	begin
		// if bit set, store register
		if (mask[0]) begin
			instr.ins = {regno,7'd1,Qupls4_pkg::OP_MOV};		// move a0,reg
			next_ip = 12'h3D2;
		end
		mask = mask >> 1;
		regno = regno + 1;
		if (~|mask)
			next_ip = 12'h3D8;
	end
12'h3D2:
	begin
		instr.ins = {1'b0,14'h3ff8,1'b0,5'd31,5'd31,Qupls4_pkg::OP_ADD};	// sub sp,sp,8
		next_ip = 12'h3D3;
	end
12'h3D3:
	begin
		instr.ins = {16'h0,5'd31,5'd1,Qupls4_pkg::OP_STORE};			// store a0,[sp]
		next_ip = 12'h3D1;
	end
12'h3D4:	begin next_ip = 12'h3D1; instr.ins = {26'd0,Qupls4_pkg::OP_NOP};	end
12'h3D5:	begin next_ip = 12'h3D1; instr.ins = {26'd0,Qupls4_pkg::OP_NOP};	end
12'h3D6:	begin next_ip = 12'h3D1; instr.ins = {26'd0,Qupls4_pkg::OP_NOP};	end
12'h3D7:	begin next_ip = 12'h3D1; instr.ins = {26'd0,Qupls4_pkg::OP_NOP};	end
12'h3D8:	begin next_ip = 12'h000; instr.ins = {26'd0,Qupls4_pkg::OP_NOP};	end
12'h3D9:	begin next_ip = 12'h000; instr.ins = {26'd0,Qupls4_pkg::OP_NOP};	end
12'h3DA:	begin next_ip = 12'h000; instr.ins = {26'd0,Qupls4_pkg::OP_NOP};	end
12'h3DB:	begin next_ip = 12'h000; instr.ins = {26'd0,Qupls4_pkg::OP_NOP};	end
*/
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
/*
12'h3C0:
	if (lc_i > 64'd0) begin
		next_ip = 12'h3C0;
		if (ir[18:13]==6'd63) begin
			case(om)
			2'd0:	instr.aRa=9'd72;
			2'd1:	instr.aRa=9'd73;
			2'd2:	instr.aRa=9'd74;
			2'd3:	instr.aRa=9'd64;
			endcase
		end
		else
			instr.aRa = {3'd0,ir[18:13]};
		instr.aRb = 9'd0;
		if (ir[12:7]==6'd63) begin
			case(om)
			2'd0:	instr.aRc=9'd72;
			2'd1:	instr.aRc=9'd73;
			2'd2:	instr.aRc=9'd74;
			2'd3:	instr.aRc=9'd64;
			endcase
		end
		else
			instr.aRc = {3'd0,ir[12:7]};
		instr.ins={21'h000000,ir[18:13],ir[12:7],Qupls4_pkg::OP_STx};
	end
	else begin
		next_ip = 12'h000;
		instr.ins = {41'd0,Qupls4_pkg::OP_NOP};
	end
12'h3C1:	// sub lc,lc,1
	begin
		lc_o = lc_i - 2'd1;
		next_ip = 12'h3C0;
		instr.ins={21'h1FFFFF,6'd55,6'd55,Qupls4_pkg::OP_ADDI};
	end
12'h3C2:
	begin
		next_ip = 12'h3C0;
		instr.ins={bamt,2'b0,ir[18:13],ir[18:13],Qupls4_pkg::OP_ADDI};		
	end
12'h3C3:
	begin
		next_ip = 12'h3C0;
		instr.ins = {5'd32,10'h0F0,6'd0,6'd55,2'd0,NE,Qupls4_pkg::OP_Bcc};
	end
*/
default:	begin next_ip = 12'h000; instr.ins = 40'hFFFFFFFFFF; end	// NOP      regx = 4'h2; 
endcase
end

endmodule
