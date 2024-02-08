// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2024  Robert Finch, Waterloo
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

module Qupls_micro_code(om, ipl, micro_ip, micro_ir, next_ip, instr, regx);
input operating_mode_t om;
input [2:0] ipl;
input mc_address_t micro_ip;
input ex_instruction_t micro_ir;
output mc_address_t next_ip;
output ex_instruction_t instr;
output reg [3:0] regx;
parameter R0 = 5'd0;
parameter S0 = 5'd18;
parameter S1 = 5'd19;
parameter S2 = 5'd20;
parameter S3 = 5'd21;
parameter S4 = 5'd22;
parameter S5 = 5'd23;
parameter S6 = 5'd24;
parameter S7 = 5'd25;
parameter S8 = 5'd26;
parameter SP = 5'd31;
parameter FP = 5'd30;
parameter SUSP = 9'd32;
parameter SSSP = 9'd33;
parameter SHSP = 9'd34;
parameter MSP = 9'd33;
parameter LR0 = SSSP;
parameter LR1 = SHSP;
// Do not use 6'd0 as some logic will detect this as a zero.
// 1 to 4 are the stack pointers.
parameter MC0 = 6'd48;
parameter MC1 = 6'd49;
parameter MC2 = 6'd50;
parameter MC3 = 6'd51;
parameter LC = 9'd28;
parameter VRM = 9'd54;
parameter VERR = 9'd55;

instruction_t ir;
always_comb ir = micro_ir.ins;

reg [21:0] bamt;
always_comb
begin
	case(micro_ir[28:25])
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
instr.element = 3'd0;
instr.aRa = ir.r3.Ra;
instr.aRb = ir.r3.Rb;
instr.aRc = ir.r3.Rc;
instr.aRt = ir.r3.Rt;
instr.pred_btst = 6'd0;
case(micro_ip)
12'h000:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end
12'h001:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end
12'h002:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end
12'h003:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end

// -----------------------------------------------------------------------------
// ENTER
//
//	enter 5,32		; save s0 to s4 and allocate 32 words
// -----------------------------------------------------------------------------
12'h004:
	begin
		next_ip=12'h005;
		instr.ins={20'h1FFFE0,2'd2,SP,SP,1'b0,OP_ADDI};
		case(om)
		2'd0: begin instr.aRa=SUSP; instr.aRt=SUSP; end
		2'd1: begin instr.aRa=SSSP; instr.aRt=SSSP; end
		2'd2: begin instr.aRa=SHSP; instr.aRt=SHSP; end
		2'd3: begin instr.aRa=MSP; instr.aRt=MSP; end
		endcase
	end
12'h005:
	begin
		next_ip=12'h006;
		instr.ins={20'h00000,2'd2,SP,FP,1'b0,OP_STO};
		case(om)
		2'd0: instr.aRa=SUSP;
		2'd1: instr.aRa=SSSP;
		2'd2: instr.aRa=SHSP;
		2'd3: instr.aRa=MSP;
		endcase
		instr.aRc=FP;
		instr.aRt=9'd0;
	end
12'h006:
	begin
		next_ip=12'h007;
		instr.ins={21'h00008,2'd2,SP,5'd1,OP_STO};
		case(om)
		2'd0: instr.aRa=SUSP;
		2'd1: instr.aRa=SSSP;
		2'd2: instr.aRa=SHSP;
		2'd3: instr.aRa=MSP;
		endcase
		instr.aRc=LR0;
		instr.aRt=9'd0;
	end
12'h007:
	begin
		next_ip=12'h008;
		instr.ins={21'h00010,2'd2,SP,5'd0,OP_STO};
		case(om)
		2'd0: instr.aRa=SUSP;
		2'd1: instr.aRa=SSSP;
		2'd2: instr.aRa=SHSP;
		2'd3: instr.aRa=MSP;
		endcase
		instr.aRc=9'd0;
		instr.aRt=9'd0;
	end
12'h008:
	begin
		next_ip=12'h009;
		instr.ins={21'h00018,2'd2,SP,5'd0,OP_STO};
		case(om)
		2'd0: instr.aRa=SUSP;
		2'd1: instr.aRa=SSSP;
		2'd2: instr.aRa=SHSP;
		2'd3: instr.aRa=MSP;
		endcase
		instr.aRc=9'd0;
		instr.aRt=9'd0;
	end
12'h009:
	begin
		next_ip=12'h00A;
		instr.ins={FN_OR,2'd2,4'd0,5'd0,5'd0,SP,FP,OP_R2};
		case(om)
		2'd0: instr.aRa=SUSP;
		2'd1: instr.aRa=SSSP;
		2'd2: instr.aRa=SHSP;
		2'd3: instr.aRa=MSP;
		endcase
		instr.aRt=FP;
	end
12'h00A:
	begin
		next_ip=12'h00B;
		instr.ins={-{14'd0,ir[11:8],3'd0},2'd2,SP,SP,OP_ADDI};
		case(om)
		2'd0: begin instr.aRa=SUSP; instr.aRt=SUSP; end
		2'd1: begin instr.aRa=SSSP; instr.aRt=SSSP; end
		2'd2: begin instr.aRa=SHSP; instr.aRt=SHSP; end
		2'd3: begin instr.aRa=MSP; instr.aRt=MSP; end
		endcase
	end
12'h00B:
	begin
		if (ir[11:8]>4'd0) begin
			next_ip=12'h00C;
			instr.ins={21'h00000,2'd2,SP,S0,OP_STO};
			case(om)
			2'd0: instr.aRa=SUSP;
			2'd1: instr.aRa=SSSP;
			2'd2: instr.aRa=SHSP;
			2'd3: instr.aRa=MSP;
			endcase
			instr.aRc=S0;
			instr.aRt=9'd0;
		end
		else begin
			next_ip=12'h014;
			instr.ins={41'd0,OP_NOP};
		end
	end
12'h00C:
	begin
		if (ir[11:8]>4'd1) begin
			next_ip=12'h00D;
			instr.ins={21'h00008,2'd2,SP,S1,OP_STO};
			case(om)
			2'd0: instr.aRa=SUSP;
			2'd1: instr.aRa=SSSP;
			2'd2: instr.aRa=SHSP;
			2'd3: instr.aRa=MSP;
			endcase
			instr.aRc=S1;
			instr.aRt=9'd0;
		end
		else begin
			next_ip=12'h014;
			instr.ins={41'd0,OP_NOP};
		end
	end
12'h00D:
	begin
		if (ir[11:8]>4'd2) begin
			next_ip=12'h00E;
			instr.ins={21'h00010,2'd2,SP,S2,OP_STO};
			case(om)
			2'd0: instr.aRa=SUSP;
			2'd1: instr.aRa=SSSP;
			2'd2: instr.aRa=SHSP;
			2'd3: instr.aRa=MSP;
			endcase
			instr.aRc=S2;
			instr.aRt=9'd0;
		end
		else begin
			next_ip=12'h014;
			instr.ins={41'd0,OP_NOP};
		end
	end
12'h00E:
	begin
		if (ir[11:8]>4'd3) begin
			next_ip=12'h00F;
			instr.ins={21'h00018,2'd2,SP,S3,OP_STO};
			case(om)
			2'd0: instr.aRa=SUSP;
			2'd1: instr.aRa=SSSP;
			2'd2: instr.aRa=SHSP;
			2'd3: instr.aRa=MSP;
			endcase
			instr.aRc=S3;
			instr.aRt=9'd0;
		end
		else begin
			next_ip=12'h014;
			instr.ins={41'd0,OP_NOP};
		end
	end
12'h00F:
	begin
		if (ir[11:8]>4'd4) begin
			next_ip=12'h010;
			instr.ins={21'h00020,2'd2,SP,S4,OP_STO};
			case(om)
			2'd0: instr.aRa=SUSP;
			2'd1: instr.aRa=SSSP;
			2'd2: instr.aRa=SHSP;
			2'd3: instr.aRa=MSP;
			endcase
			instr.aRc=S4;
			instr.aRt=9'd0;
		end
		else begin
			next_ip=12'h014;
			instr.ins={41'd0,OP_NOP};
		end
	end
12'h010:
	begin
		if (ir[11:8]>4'd5) begin
			next_ip=12'h011;
			instr.ins={21'h00028,2'd2,SP,S5,OP_STO};
			case(om)
			2'd0: instr.aRa=SUSP;
			2'd1: instr.aRa=SSSP;
			2'd2: instr.aRa=SHSP;
			2'd3: instr.aRa=MSP;
			endcase
			instr.aRc=S5;
			instr.aRt=9'd0;
		end
		else begin
			next_ip=12'h014;
			instr.ins={41'd0,OP_NOP};
		end
	end
12'h011:
	begin
		if (ir[11:8]>4'd6) begin
			next_ip=12'h012;
			instr.ins={21'h00030,2'd2,SP,S6,OP_STO};
			case(om)
			2'd0: instr.aRa=SUSP;
			2'd1: instr.aRa=SSSP;
			2'd2: instr.aRa=SHSP;
			2'd3: instr.aRa=MSP;
			endcase
			instr.aRc=S6;
			instr.aRt=9'd0;
		end
		else begin
			next_ip=12'h014;
			instr.ins={41'd0,OP_NOP};
		end
	end
12'h012:
	begin
		if (ir[11:8]>4'd7) begin
			next_ip=12'h013;
			instr.ins={21'h00038,2'd2,SP,S7,OP_STO};
			case(om)
			2'd0: instr.aRa=SUSP;
			2'd1: instr.aRa=SSSP;
			2'd2: instr.aRa=SHSP;
			2'd3: instr.aRa=MSP;
			endcase
			instr.aRc=S7;
			instr.aRt=9'd0;
		end
		else begin
			next_ip=12'h014;
			instr.ins={41'd0,OP_NOP};
		end
	end
12'h013:
	begin
		if (ir[11:8]>4'd8) begin
			next_ip=12'h014;
			instr.ins={21'h00040,2'd2,SP,S8,OP_STO};
			case(om)
			2'd0: instr.aRa=SUSP;
			2'd1: instr.aRa=SSSP;
			2'd2: instr.aRa=SHSP;
			2'd3: instr.aRa=MSP;
			endcase
			instr.aRc=S8;
			instr.aRt=9'd0;
		end
		else begin
			next_ip=12'h014;
			instr.ins={41'd0,OP_NOP};
		end
	end
12'h014:
	begin
		next_ip=12'h015;
		instr.ins={ir[32:12],2'd2,SP,SP,OP_ADDI};
		case(om)
		2'd0: begin instr.aRa=SUSP; instr.aRt=SUSP; end
		2'd1: begin instr.aRa=SSSP; instr.aRt=SSSP; end
		2'd2: begin instr.aRa=SHSP; instr.aRt=SHSP; end
		2'd3: begin instr.aRa=MSP; instr.aRt=MSP; end
		endcase
	end
12'h015:
	begin
		next_ip=12'h016;
		instr.ins={16'd0,ir[39:33],2'd2,3'd1,SP,OP_ADDSI};
		case(om)
		2'd0: begin instr.aRa=SUSP; instr.aRt=SUSP; end
		2'd1: begin instr.aRa=SSSP; instr.aRt=SSSP; end
		2'd2: begin instr.aRa=SHSP; instr.aRt=SHSP; end
		2'd3: begin instr.aRa=MSP; instr.aRt=MSP; end
		endcase
	end
12'h016:
	begin
		next_ip = 12'h017;
		instr.ins = {30'h5,3'd0,OP_BSR};
		instr.aRa = 9'd0;
		instr.aRb = 9'd0;
		instr.aRc = 9'd0;
		instr.aRt = 9'd0;
	end
12'h017:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,OP_NOP};
	end
12'h018:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,OP_NOP};
	end
12'h019:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,OP_NOP};
	end
12'h01A:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,OP_NOP};
	end
12'h01B:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,OP_NOP};
	end
12'h01C:
	begin
		next_ip=12'h01D;
		instr.ins={41'd0,OP_NOP};
	end
12'h01D:
	begin
		next_ip=12'h01E;
		instr.ins={41'd0,OP_NOP};
	end
12'h01E:
	begin
		next_ip=12'h01F;
		instr.ins={41'd0,OP_NOP};
	end
12'h01F:
	begin
		next_ip=12'h004;
		instr.ins={41'd0,OP_NOP};
	end

// -----------------------------------------------------------------------------
// PUSH
// -----------------------------------------------------------------------------
12'h020:
	begin
		next_ip = 12'h021;
		instr.ins = {-{15'h00,ir[39:37],3'h0},2'd2,SP,SP,OP_ADDI};
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
	end				// SP = SP - N * 16
12'h021:
	begin
		next_ip = 12'h022;
		instr.ins = ir[39:37] > 3'd0 ? {18'd0,3'h0,2'd2,SP,ir[11: 7],OP_STO} : {41'd0,OP_NOP};
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRc = {4'd0,ir[11:7]};
		instr.aRt = 9'd0;
	end		// Mem[SP] = Rs
12'h022:
	begin
		next_ip = 12'h023;
		instr.ins = ir[39:37] > 3'd1 ? {18'h1,3'h0,2'd2,SP,ir[16:12],OP_STO} : {41'd0,OP_NOP};
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRc = {4'd0,ir[16:12]};
		instr.aRt = 9'd0;
	end		// Mem[SP] = Ra
12'h023:
	begin
		next_ip = 12'h024;
		instr.ins = ir[39:37] > 3'd2 ? {18'h2,3'h0,2'd2,SP,ir[21:17],OP_STO} : {41'd0,OP_NOP};
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRc = {4'd0,ir[21:17]};
		instr.aRt = 9'd0;
	end		// Mem[SP] = Rb
12'h024:
	begin
		next_ip = 12'h025;
		instr.ins = ir[39:37] > 3'd3 ? {18'h3,3'h0,2'd2,SP,ir[26:22],OP_STO} : {41'd0,OP_NOP};
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRc = {4'd0,ir[26:22]};
		instr.aRt = 9'd0;
	end		// Mem[SP] = Rc
12'h025:	
	begin
		next_ip = 12'h026;
		instr.ins = ir[39:37] > 3'd4 ? {18'h4,3'h0,2'd2,SP,ir[31:27],OP_STO} : {41'd0,OP_NOP};
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRc = {3'd0,ir[31:27]};
		instr.aRt = 9'd0;
	end		// Mem[SP] = Rc
12'h026:	
	begin
		next_ip = 12'h027;
		instr.ins = ir[39:37] > 3'd5 ? {18'h4,3'h0,2'd2,SP,ir[36:32],OP_STO} : {41'd0,OP_NOP};
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRc = {3'd0,ir[36:32]};
		instr.aRt = 9'd0;
	end		// Mem[SP] = Rc
12'h027:
	begin
		next_ip = 12'h000;
		instr.ins = {30'h5,3'd0,OP_BSR};
		instr.aRa = 9'd0;
		instr.aRb = 9'd0;
		instr.aRc = 9'd0;
		instr.aRt = 9'd0;
	end

12'h028:	begin next_ip = 12'h029; instr.ins = {41'd0,OP_NOP};	end
12'h029:	begin next_ip = 12'h02A; instr.ins = {41'd0,OP_NOP};	end
12'h02A:	begin next_ip = 12'h02B; instr.ins = {41'd0,OP_NOP};	end
12'h02B:	begin next_ip = 12'h020; instr.ins = {41'd0,OP_NOP};	end

// -----------------------------------------------------------------------------
// POP
// -----------------------------------------------------------------------------
12'h030:
	begin
		next_ip = 12'h031;
		instr.ins = ir[39:37] > 3'd0 ? {21'd0,2'd2,SP,ir[11: 7],OP_LDO} : {41'd0,OP_NOP};
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRt = {4'd0,ir[11:7]};
	end		// Rt = Mem[SP]
12'h031:
	begin
		next_ip = 12'h032;
		instr.ins = ir[39:37] > 3'd1 ? {18'h1,3'h0,2'd2,SP,ir[16:12],OP_LDO} : {41'd0,OP_NOP};
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRt = {4'd0,ir[16:12]};
	end		// Ra = Mem[SP]
12'h032:
	begin
		next_ip = 12'h033;
		instr.ins = ir[39:37] > 3'd2 ? {18'h2,3'h0,2'd2,SP,ir[21:17],OP_LDO} : {41'd0,OP_NOP};
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRt = {4'd0,ir[21:17]};
	end		// Rb = Mem[SP]
12'h033:	
	begin
		next_ip = 12'h034;
		instr.ins = ir[39:37] > 3'd3 ? {18'h3,3'h0,2'd2,SP,ir[26:22],OP_LDO} : {41'd0,OP_NOP};
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRt = {4'd0,ir[26:22]};
	end		// Rc = Mem[SP]
12'h034:
	begin
		next_ip = 12'h035;
		instr.ins = ir[39:37] > 3'd4 ? {18'h4,3'h0,2'd2,SP,ir[31:27],OP_LDO} : {41'd0,OP_NOP};
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRt = {4'd0,ir[31:27]};
	end		// Rc = Mem[SP]
12'h035:
	begin
		next_ip = 12'h036;
		instr.ins = ir[39:37] > 3'd5 ? {18'h4,3'h0,2'd2,SP,ir[36:32],OP_LDO} : {41'd0,OP_NOP};
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRt = {4'd0,ir[36:32]};
	end		// Rc = Mem[SP]
12'h036:
	begin
		next_ip = 12'h037;
		instr.ins = {15'h00,ir[39:37],3'h0,SP,SP,OP_ADDI};
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		case(om)
		2'd0:	instr.aRt = SUSP;
		2'd1:	instr.aRt = SSSP;
		2'd2: instr.aRt = SHSP;
		2'd3:	instr.aRt = MSP;
		endcase
	end				// SP = SP + N * 16
12'h037:
	begin
		next_ip = 12'h000;
		instr.ins = {30'h5,3'd0,OP_BSR};
		instr.aRa = 9'd0;
		instr.aRb = 9'd0;
		instr.aRc = 9'd0;
		instr.aRt = 9'd0;
	end

12'h038:	begin next_ip = 12'h039; instr.ins = {41'd0,OP_NOP};	end
12'h039:	begin next_ip = 12'h03A; instr.ins = {41'd0,OP_NOP};	end
12'h03A:	begin next_ip = 12'h03B; instr.ins = {41'd0,OP_NOP};	end
12'h03B:	begin next_ip = 12'h030; instr.ins = {41'd0,OP_NOP};	end


// -----------------------------------------------------------------------------
// FDIV
// -----------------------------------------------------------------------------
12'h040:	begin next_ip = 12'h044; instr.ins = {'d0,FN_FLT1,2'd0,3'd0,FN_FLT1,FN_FRES,ir[18:13],ir[12:7],OP_FLT3}; end
12'h041:	begin next_ip = 12'h044; instr.ins = {'d0,FN_FLT1,2'd0,3'd0,FN_FLT1,FN_FNEG,ir[18:13],ir[18:13],OP_FLT3}; end
12'h042:	begin next_ip = 12'h044; instr.ins = {'d0,FN_FLT1,5'b0,FN_FLT1,FN_FCONST,6'd2,6'd58,OP_FLT3}; end
12'h043:	begin next_ip = 12'h044; instr.ins = {'d0,FN_FMA,5'd0,6'd58,ir[18:13],ir[12:7],6'd47,OP_FLT3}; end
12'h044:	begin next_ip = 12'h048; instr.ins = {'d0,FN_FMA,5'd0,6'd0,6'd47,ir[12:7],ir[12:7],OP_FLT3}; end
12'h045:	begin next_ip = 12'h048; instr.ins = {'d0,FN_FMA,5'd0,6'd58,ir[18:13],ir[12:7],6'd47,OP_FLT3}; end
12'h046:	begin next_ip = 12'h048; instr.ins = {'d0,FN_FMA,5'd0,6'd0,6'd47,ir[12:7],ir[12:7],OP_FLT3}; end
12'h047:	begin next_ip = 12'h048; instr.ins = {'d0,FN_FMA,5'd0,6'd58,ir[18:13],ir[12:7],6'd47,OP_FLT3}; end
12'h048:	begin next_ip = 12'h04C; instr.ins = {'d0,FN_FMA,5'd0,6'd0,6'd47,ir[12:7],ir[12:7],OP_FLT3}; end
12'h049:	begin next_ip = 12'h04C; instr.ins = {'d0,FN_FMA,5'd0,6'd58,ir[18:13],ir[12:7],6'd47,OP_FLT3}; end
12'h04A:	begin next_ip = 12'h04C; instr.ins = {'d0,FN_FMA,5'd0,6'd0,6'd47,ir[12:7],ir[12:7],OP_FLT3}; end
12'h04B:	begin next_ip = 12'h04C; instr.ins = {'d0,FN_FLT1,5'b0,FN_FLT1,FN_FNEG,ir[18:13],ir[18:13],OP_FLT3}; end
12'h04C:	begin next_ip = 12'h000; instr.ins = {'d0,FN_FMA,5'd0,6'd0,ir[18:13],ir[12:7],ir[12:7],OP_FLT3}; end
12'h04D:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end
12'h04E:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end
12'h04F:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end

// Lomont Reciprocal Square Root
// float RcpSqrt1 (float x)
// {
//   float xhalf = 0.5f*x;
//   int i = *(int*)&x; // represent float as an integer  ()
//	 i = 0x5f375a86 – (i >> 1);// integer division by two and change in sign
//	 float y = *(float*)&i; // represent integer as a float  ()
//
// initial approximation 0
//   y = y*(1.5f – xhalf *y*y); // first NR iteration			9.16 bits accurate
//	 y = y*(1.5f – xhalf *y*y); // second NR iteration	 17.69 bits accurate
//	 y = y*(1.5f – xhalf *y*y); // third NR iteration	   35 bits accurate
//   y = y*(1.5f – xhalf *y*y); // fourth NR iteration	 70 bits accurate
//	 return y;
// }
//64-bit magic used:
//0x5FE6EB50C7B537A9
// Approximately 119 clock cycles.
// ToDo: Fix for new float format instructions.
12'h050:	begin next_ip = 12'h054; instr.ins = {3'd0,12'h068,6'd0,ir[18:13],3'd2,2'd0,1'b0,OP_MCB};	end		// if -tive
12'h051:	begin next_ip = 12'h054; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd57,MC0,OP_FLT3}; regx = 4'h1; end	// MC0 = infinity
12'h052:	begin next_ip = 12'h054; instr.ins = {3'd0,12'h06C,MC0,ir[18:13],3'd0,2'd0,1'b0,OP_MCB}; regx = 4'h4; end			// if = infinity
12'h053:	begin next_ip = 12'h054; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd0,MC0,OP_FLT3};  regx = 4'h1; end	// MC0 = 0.5
12'h054:	begin next_ip = 12'h058; instr.ins = {'d0,FN_MUL,4'b0,MC0,ir[18:13],MC1,OP_FLT3}; regx = 4'h5; end	// MC1 = x * MC0
12'h055:	begin next_ip = 12'h058; instr.ins = {'d0,1'b0,1'b1,OP_LSR,7'd1,ir[18:13],MC2,OP_SHIFT}; regx = 4'h1; end	// MC2 = i>>1
12'h056:	begin next_ip = 12'h058; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd4,MC0,OP_FLT3}; regx = 4'h1; end			// MC0 = MAGIC
12'h057:	begin next_ip = 12'h058; instr.ins = {'d0,FN_SUB,4'b00,MC2,MC0,MC2,OP_FLT3}; regx = 4'h7; end							// MC2 = MAGIC - MC2
12'h058:	begin next_ip = 12'h05C; instr.ins = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,OP_FLT3}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h059:	begin next_ip = 12'h05C; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd3,MC0,OP_FLT3}; regx = 4'h1; end			// MC0 = 1.5
12'h05A:	begin next_ip = 12'h05C; instr.ins = {'d0,FN_FNMS,MC0,MC3,MC1,ir[12:7],OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h05B:	begin next_ip = 12'h05C; instr.ins = {'d0,FN_MUL,4'b0,MC2,ir[12:7],MC2,OP_FLT3}; regx = 4'h5; end		// MC2 = MC2 * Rt
12'h05C:	begin next_ip = 12'h060; instr.ins = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,OP_FLT3}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h05D:	begin next_ip = 12'h060; instr.ins = {'d0,FN_FNMS,MC0,MC3,MC1,ir[12:7],OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h05E:	begin next_ip = 12'h060; instr.ins = {'d0,FN_MUL,4'b0,MC2,ir[12:7],MC2,OP_FLT3}; regx = 4'h5; end		// MC2 = MC2 * Rt
12'h05F:	begin next_ip = 12'h060; instr.ins = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,OP_FLT3}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h060:	begin next_ip = 12'h064; instr.ins = {'d0,FN_FNMS,MC0,MC3,MC1,ir[12:7],OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h061:	begin next_ip = 12'h064; instr.ins = {'d0,FN_MUL,4'b0,MC2,ir[12:7],MC2,OP_FLT3}; regx = 4'h5; end		// MC2 = MC2 * Rt
12'h062:	begin next_ip = 12'h064; instr.ins = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,OP_FLT3}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h063:	begin next_ip = 12'h064; instr.ins = {'d0,FN_FNMS,MC0,MC3,MC1,ir[12:7],OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h064:	begin next_ip = 12'h000; instr.ins = {'d0,FN_MUL,4'b0,MC2,ir[12:7],ir[12:7],OP_FLT3}; regx = 4'h4; end		// Rt = MC2 * Rt
12'h065:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end
12'h066:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end
12'h067:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end
12'h068:	begin next_ip = 12'h000; instr.ins = {'d0,FN_FLT1,2'b0,FN_FCONST,6'd63,ir[12:7],OP_FLT3}; end		// Rt = Nan (square root of negative)
12'h069:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end
12'h06A:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end
12'h06B:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end
12'h06C:	begin next_ip = 12'h000; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd62,ir[12:7],OP_FLT3}; end		// Rt = Nan (square root of infinity)
12'h06D:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end
12'h06E:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end
12'h06F:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end

// FRSQRTE9
// Approximately 46 clock cycles.
12'h070:	begin next_ip = 12'h074; instr.ins = {3'd0,12'h068,6'd0,ir[18:13],3'd2,2'd0,1'b0,OP_MCB};	end		// if -tive
12'h071:	begin next_ip = 12'h074; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd57,MC0,OP_FLT3}; regx = 4'h1; end	// MC0 = infinity
12'h072:	begin next_ip = 12'h074; instr.ins = {3'd0,12'h06C,MC0,ir[18:13],3'd0,2'd0,1'b0,OP_MCB}; regx = 4'h4; end			// if = infinity
12'h073:	begin next_ip = 12'h074; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd0,MC0,OP_FLT3}; regx = 4'h1; end	// MC0 = 0.5
12'h074:	begin next_ip = 12'h078; instr.ins = {'d0,FN_MUL,4'b0,MC0,ir[18:13],MC1,OP_FLT3}; regx = 4'h5; end	// MC1 = x * MC0
12'h075:	begin next_ip = 12'h078; instr.ins = {'d0,1'b0,1'b1,OP_LSR,7'd1,ir[18:13],MC2,OP_SHIFT}; regx = 4'h1; end	// MC2 = i>>1
12'h076:	begin next_ip = 12'h078; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd4,MC0,OP_FLT3}; regx = 4'h1; end			// MC0 = MAGIC
12'h077:	begin next_ip = 12'h078; instr.ins = {'d0,FN_SUB,4'b00,MC2,MC0,MC2,OP_FLT3}; regx = 4'h7; end							// MC2 = MAGIC - MC2
12'h078:	begin next_ip = 12'h000; instr.ins = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,OP_FLT3}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h079:	begin next_ip = 12'h000; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd3,MC0,OP_FLT3}; regx = 4'h1; end			// MC0 = 1.5
12'h07A:	begin next_ip = 12'h000; instr.ins = {'d0,FN_FNMS,MC0,MC3,MC1,ir[12:7],OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h07B:	begin next_ip = 12'h000; instr.ins = {'d0,FN_MUL,4'b0,MC2,ir[12:7],ir[12:7],OP_FLT3}; regx = 4'h4; end		// MC2 = MC2 * Rt
12'h07C:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end
12'h07D:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end
12'h07E:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end
12'h07F:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end

// FRSQRTE17
// Approximately 70 clock cycles
12'h080:	begin next_ip = 12'h084; instr.ins = {3'd0,12'h068,6'd0,ir[18:13],3'd2,2'd0,1'b0,OP_MCB};	end		// if -tive
12'h081:	begin next_ip = 12'h084; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd57,MC0,OP_FLT3}; regx = 4'h1; end	// MC0 = infinity
12'h082:	begin next_ip = 12'h084; instr.ins = {3'd0,12'h06C,MC0,ir[18:13],3'd0,2'd0,1'b0,OP_MCB}; regx = 4'h4; end			// if = infinity
12'h083:	begin next_ip = 12'h084; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd0,MC0,OP_FLT3}; regx = 4'h1; end	// MC0 = 0.5
12'h084:	begin next_ip = 12'h088; instr.ins = {'d0,FN_MUL,4'b0,MC0,ir[18:13],MC1,OP_FLT3}; regx = 4'h5; end	// MC1 = x * MC0
12'h085:	begin next_ip = 12'h088; instr.ins = {'d0,1'b0,1'b1,OP_LSR,7'd1,ir[18:13],MC2,OP_SHIFT}; regx = 4'h1; end	// MC2 = i>>1
12'h086:	begin next_ip = 12'h088; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd4,MC0,OP_FLT3}; regx = 4'h1; end			// MC0 = MAGIC
12'h087:	begin next_ip = 12'h088; instr.ins = {'d0,FN_SUB,4'b00,MC2,MC0,MC2,OP_FLT3}; regx = 4'h7; end							// MC2 = MAGIC - MC2
12'h088:	begin next_ip = 12'h08C; instr.ins = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,OP_FLT3}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h089:	begin next_ip = 12'h08C; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd3,MC0,OP_FLT3}; regx = 4'h1; end			// MC0 = 1.5
12'h08A:	begin next_ip = 12'h08C; instr.ins = {'d0,FN_FNMS,MC0,MC3,MC1,ir[12:7],OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h08B:	begin next_ip = 12'h08C; instr.ins = {'d0,FN_MUL,4'b0,MC2,ir[12:7],MC2,OP_FLT3}; regx = 4'h5; end		// MC2 = MC2 * Rt
12'h08C:	begin next_ip = 12'h000; instr.ins = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,OP_FLT3}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h08D:	begin next_ip = 12'h000; instr.ins = {'d0,FN_FNMS,MC0,MC3,MC1,ir[12:7],OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h08E:	begin next_ip = 12'h000; instr.ins = {'d0,FN_MUL,4'b0,MC2,ir[12:7],ir[12:7],OP_FLT3}; regx = 4'h4; end		// Rt = MC2 * Rt
12'h08F:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end

// FRSQRTE34
// Approximately 94 clock cycles
12'h0A0:	begin next_ip = 12'h0A4; instr.ins = {3'd0,12'h068,6'd0,ir[18:13],3'd2,2'd0,1'b0,OP_MCB};	end		// if -tive
12'h0A1:	begin next_ip = 12'h0A4; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd57,MC0,OP_FLT3}; regx = 4'h1; end	// MC0 = infinity
12'h0A2:	begin next_ip = 12'h0A4; instr.ins = {3'd0,12'h06C,MC0,ir[18:13],3'd0,2'd0,1'b0,OP_MCB}; regx = 4'h4; end			// if = infinity
12'h0A3:	begin next_ip = 12'h0A4; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd0,MC0,OP_FLT3}; regx = 4'h1; end	// MC0 = 0.5
12'h0A4:	begin next_ip = 12'h0A8; instr.ins = {'d0,FN_MUL,4'b0,MC0,ir[18:13],MC1,OP_FLT3}; regx = 4'h5; end	// MC1 = x * MC0
12'h0A5:	begin next_ip = 12'h0A8; instr.ins = {'d0,1'b0,1'b1,OP_LSR,7'd1,ir[18:13],MC2,OP_SHIFT}; regx = 4'h1; end	// MC2 = i>>1
12'h0A6:	begin next_ip = 12'h0A8; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd4,MC0,OP_FLT3}; regx = 4'h1; end			// MC0 = MAGIC
12'h0A7:	begin next_ip = 12'h0A8; instr.ins = {'d0,FN_SUB,4'b00,MC2,MC0,MC2,OP_FLT3}; regx = 4'h7; end							// MC2 = MAGIC - MC2
12'h0A8:	begin next_ip = 12'h0AC; instr.ins = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,OP_FLT3}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h0A9:	begin next_ip = 12'h0AC; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd3,MC0,OP_FLT3}; regx = 4'h1; end			// MC0 = 1.5
12'h0AA:	begin next_ip = 12'h0AC; instr.ins = {'d0,FN_FNMS,MC0,MC3,MC1,ir[12:7],OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h0AB:	begin next_ip = 12'h0AC; instr.ins = {'d0,FN_MUL,4'b0,MC2,ir[12:7],MC2,OP_FLT3}; regx = 4'h5; end		// MC2 = MC2 * Rt
12'h0AC:	begin next_ip = 12'h0B0; instr.ins = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,OP_FLT3}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h0AD:	begin next_ip = 12'h0B0; instr.ins = {'d0,FN_FNMS,MC0,MC3,MC1,ir[12:7],OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h0AE:	begin next_ip = 12'h0B0; instr.ins = {'d0,FN_MUL,4'b0,MC2,ir[12:7],MC2,OP_FLT3}; regx = 4'h5; end		// MC2 = MC2 * Rt
12'h0AF:	begin next_ip = 12'h0B0; instr.ins = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,OP_FLT3}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h0B0:	begin next_ip = 12'h000; instr.ins = {'d0,FN_FNMS,MC0,MC3,MC1,ir[12:7],OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h0B1:	begin next_ip = 12'h000; instr.ins = {'d0,FN_MUL,4'b0,MC2,ir[12:7],ir[12:7],OP_FLT3}; regx = 4'h4; end		// Rt = MC2 * Rt
12'h0B2:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end
12'h0B3:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end

// FRES16
// 22 clocks
// x[i+1] = x[i]*(2 - x[i]*a)
12'h0C0:	begin next_ip = 12'h0C4; instr.ins = {'d0,FN_FLT1,4'b0,FN_ISNAN,ir[18:13],ir[12:7],OP_FLT3}; end
12'h0C1:	begin next_ip = 12'h0C4; instr.ins = {3'd0,12'h0C8,6'd0,ir[12:7],3'd1,2'd0,1'b0,OP_MCB}; end
12'h0C2:	begin next_ip = 12'h0C4; instr.ins = {'d0,FN_FLT1,4'b0,FN_FRES,ir[18:13],ir[12:7],OP_FLT3}; end
12'h0C3:	begin next_ip = 12'h0C4; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd2,MC0,OP_FLT3}; regx = 4'h1; end
12'h0C4:	begin next_ip = 12'h000; instr.ins = {'d0,FN_FNMS,MC0,ir[18:13],ir[12:7],MC1,OP_FLT3}; regx = 4'h9; end
12'h0C5:	begin next_ip = 12'h000; instr.ins = {'d0,FN_FMA,6'd0,MC1,ir[12:7],ir[12:7],OP_FLT3}; regx = 4'h4; end
12'h0C6:	begin next_ip = 12'h000; instr.ins = {'d0,FN_OR,1'b0,6'd0,ir[18:13],ir[12:7],OP_R2}; end		// Rt = Ra = NaN
12'h0C7:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end
12'h0C8:	begin next_ip = 12'h000; instr.ins = {'d0,FN_OR,1'b0,6'd0,ir[18:13],ir[12:7],OP_R2}; end		// Rt = Ra = NaN
12'h0C9:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end
12'h0CA:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end
12'h0CB:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end

// FRES32
// 38 clocks
12'h0D0:	begin next_ip = 12'h0D4; instr.ins = {'d0,FN_FLT1,4'b0,FN_ISNAN,ir[18:13],ir[12:7],OP_FLT3}; end
12'h0D1:	begin next_ip = 12'h0D4; instr.ins = {3'd0,12'h0C8,6'd0,ir[12:7],3'd1,2'd0,1'b0,OP_MCB}; end
12'h0D2:	begin next_ip = 12'h0D4; instr.ins = {'d0,FN_FLT1,4'b0,FN_FRES,ir[18:13],ir[12:7],OP_FLT3}; end
12'h0D3:	begin next_ip = 12'h0D4; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd2,MC0,OP_FLT3}; regx = 4'h1; end
12'h0D4:	begin next_ip = 12'h0E8; instr.ins = {'d0,FN_FNMS,MC0,ir[18:13],ir[12:7],MC1,OP_FLT3}; regx = 4'h9; end
12'h0D5:	begin next_ip = 12'h0E8; instr.ins = {'d0,FN_FMA,6'd0,MC1,ir[12:7],ir[12:7],OP_FLT3}; regx = 4'h4; end
12'h0D6:	begin next_ip = 12'h0E8; instr.ins = {'d0,OP_NOP};	end
12'h0D7:	begin next_ip = 12'h0E8; instr.ins = {'d0,OP_NOP};	end

// FRES64
// 54 clocks
12'h0E0:	begin next_ip = 12'h0E4; instr.ins = {'d0,FN_FLT1,4'b0,FN_ISNAN,ir[18:13],ir[12:7],OP_FLT3}; end
12'h0E1:	begin next_ip = 12'h0E4; instr.ins = {3'd0,12'h0C8,6'd0,ir[12:7],3'd1,2'd0,1'b0,OP_MCB}; end
12'h0E2:	begin next_ip = 12'h0E4; instr.ins = {'d0,FN_FLT1,4'b0,FN_FRES,ir[18:13],ir[12:7],OP_FLT3}; end
12'h0E3:	begin next_ip = 12'h0E4; instr.ins = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd2,MC0,OP_FLT3}; regx = 4'h1; end
12'h0E4:	begin next_ip = 12'h0E8; instr.ins = {'d0,FN_FNMS,MC0,ir[18:13],ir[12:7],MC1,OP_FLT3}; regx = 4'h9; end
12'h0E5:	begin next_ip = 12'h0E8; instr.ins = {'d0,FN_FMA,6'd0,MC1,ir[12:7],ir[12:7],OP_FLT3}; regx = 4'h4; end
12'h0E6:	begin next_ip = 12'h0E8; instr.ins = {'d0,FN_FNMS,MC0,ir[18:13],ir[12:7],MC1,OP_FLT3}; regx = 4'h9; end
12'h0E7:	begin next_ip = 12'h0E8; instr.ins = {'d0,FN_FMA,6'd0,MC1,ir[12:7],ir[12:7],OP_FLT3}; regx = 4'h4; end
12'h0E8:	begin next_ip = 12'h000; instr.ins = {'d0,FN_FNMS,MC0,ir[18:13],ir[12:7],MC1,OP_FLT3}; regx = 4'h9; end
12'h0E9:	begin next_ip = 12'h000; instr.ins = {'d0,FN_FMA,6'd0,MC1,ir[12:7],ir[12:7],OP_FLT3}; regx = 4'h4; end
12'h0EA:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end
12'h0EB:	begin next_ip = 12'h000; instr.ins = {'d0,OP_NOP};	end

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
		instr.ins = {3'd0,2'd0,CSR_CTX,5'h00,5'h00,OP_CSR};
		instr.pred_btst=6'd0;
	end
12'h101:
	begin
		next_ip=12'h102;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd1;
		instr.aRt=9'd0;
		instr.ins={21'h00008,2'd2,5'd0,5'd1,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h102:
	begin
		next_ip=12'h103;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd2;
		instr.aRt=9'd0;
		instr.ins={21'h00010,2'd2,5'd0,5'd2,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h103:
	begin
		next_ip=12'h104;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd3;
		instr.aRt=9'd0;
		instr.ins={21'h00018,2'd2,5'd0,5'd3,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h104:
	begin
		next_ip=12'h105;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd4;
		instr.aRt=9'd0;
		instr.ins={21'h00020,2'd2,5'd0,5'd4,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h105:
	begin
		next_ip=12'h106;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd5;
		instr.aRt=9'd0;
		instr.ins={21'h00028,2'd2,5'd0,5'd5,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h106:
	begin
		next_ip=12'h107;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd6;
		instr.aRt=9'd0;
		instr.ins={21'h00030,2'd2,5'd0,5'd6,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h107:
	begin
		next_ip=12'h108;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd7;
		instr.aRt=9'd0;
		instr.ins={21'h00038,2'd2,5'd0,5'd7,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h108:
	begin
		next_ip=12'h109;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd8;
		instr.aRt=9'd0;
		instr.ins={21'h00040,2'd2,5'd0,5'd8,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h109:
	begin
		next_ip=12'h10A;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd9;
		instr.aRt=9'd0;
		instr.ins={21'h00048,2'd2,5'd0,5'd9,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h10A:
	begin
		next_ip=12'h10B;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd10;
		instr.aRt=9'd0;
		instr.ins={21'h00050,2'd2,5'd0,5'd10,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h10B:
	begin
		next_ip=12'h10C;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd11;
		instr.aRt=9'd0;
		instr.ins={21'h00058,2'd2,5'd0,5'd11,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h10C:
	begin
		next_ip=12'h10D;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd12;
		instr.aRt=9'd0;
		instr.ins={21'h00060,2'd2,5'd0,5'd12,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h10D:
	begin
		next_ip=12'h10E;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd13;
		instr.aRt=9'd0;
		instr.ins={21'h00068,2'd2,5'd0,5'd13,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h10E:
	begin
		next_ip=12'h10F;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd14;
		instr.aRt=9'd0;
		instr.ins={21'h00070,2'd2,5'd0,5'd14,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h10F:
	begin
		next_ip=12'h110;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd15;
		instr.aRt=9'd0;
		instr.ins={21'h00078,2'd2,5'd0,5'd15,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h110:
	begin
		next_ip=12'h111;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd16;
		instr.aRt=9'd0;
		instr.ins={21'h00080,2'd2,5'd0,5'd16,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h111:
	begin
		next_ip=12'h112;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd17;
		instr.aRt=9'd0;
		instr.ins={21'h00088,2'd2,5'd0,5'd17,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h112:
	begin
		next_ip=12'h113;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd18;
		instr.aRt=9'd0;
		instr.ins={21'h00090,2'd2,5'd0,5'd18,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h113:
	begin
		next_ip=12'h114;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd19;
		instr.aRt=9'd0;
		instr.ins={21'h00098,2'd2,5'd0,5'd19,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h114:
	begin
		next_ip=12'h115;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd20;
		instr.aRt=9'd0;
		instr.ins={21'h000A0,2'd2,5'd0,5'd20,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h115:
	begin
		next_ip=12'h116;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd21;
		instr.aRt=9'd0;
		instr.ins={21'h000A8,2'd2,5'd0,5'd21,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h116:
	begin
		next_ip=12'h117;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd22;
		instr.aRt=9'd0;
		instr.ins={21'h000B0,2'd2,5'd0,5'd22,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h117:
	begin
		next_ip=12'h118;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd23;
		instr.aRt=9'd0;
		instr.ins={21'h000B8,2'd2,5'd0,5'd23,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h118:
	begin
		next_ip=12'h119;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd24;
		instr.aRt=9'd0;
		instr.ins={21'h000C0,2'd2,5'd0,5'd24,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h119:
	begin
		next_ip=12'h11A;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd25;
		instr.aRt=9'd0;
		instr.ins={21'h000C8,2'd2,5'd0,5'd25,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h11A:
	begin
		next_ip=12'h11B;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd26;
		instr.aRt=9'd0;
		instr.ins={21'h000D0,2'd2,5'd0,5'd26,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h11B:
	begin
		next_ip=12'h11C;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd27;
		instr.aRt=9'd0;
		instr.ins={21'h000D8,2'd2,5'd0,5'd27,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h11C:
	begin
		next_ip=12'h11D;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd28;
		instr.aRt=9'd0;
		instr.ins={21'h000E0,2'd2,5'd0,5'd28,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h11D:
	begin
		next_ip=12'h11E;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd29;
		instr.aRt=9'd0;
		instr.ins={21'h000E8,2'd2,5'd0,5'd29,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h11E:
	begin
		next_ip=12'h11F;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd30;
		instr.aRt=9'd0;
		instr.ins={21'h000F0,2'd2,5'd0,5'd30,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h11F:
	begin
		next_ip=12'h120;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd31;
		instr.aRt=9'd0;
		instr.ins={21'h000F8,2'd2,5'd0,5'd31,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h120:	begin next_ip = 12'h000; instr.ins = {'d0,13'h03F0,MC0,6'h3F,OP_STO}; regx = 4'h2; end
12'h121:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h122:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h123:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end

// -----------------------------------------------------------------------------
// JSRI
// -----------------------------------------------------------------------------
12'h128:
	begin
		next_ip=12'h129;
		instr.ins=micro_ir;
		case(micro_ir[18:17])
		2'd0:	instr.ins.any.opcode = OP_LDWU;
		2'd1: instr.ins.any.opcode = OP_LDTU;
		2'd2: instr.ins.any.opcode = OP_LDO;
		2'd3: instr.ins.any.opcode = OP_LDO;
		endcase
		instr.aRa=9'd0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=MC0;
		instr.pred_btst=6'd0;
	end
12'h129:
	begin
		next_ip=12'h12A;
		instr.ins=micro_ir;
		instr.ins.any.opcode = OP_JSR;
		instr.ins[39:19]=21'd0;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.pred_btst=6'd0;
	end
12'h12A:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h12B:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end

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
		instr.ins={3'd0,6'd0,14'h3033,5'd0,5'd0,OP_CSR};		// MC0=TVEC[3]
	end
12'h131:
	begin
		next_ip=12'h000;
		instr.aRa=9'd0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={3'd0,MC1};
		instr.ins={3'd0,6'd0,14'h3006,5'd0,5'd0,OP_CSR};		// MC1=Cause
	end
12'h132:
	begin
		next_ip=12'h000;
		instr.aRa={3'd0,MC0};
		instr.aRb={3'd0,MC1};
		instr.aRc=9'd0;
		instr.aRt={3'd0,MC0};
		instr.ins={FN_LDOX,11'd0,2'd3,5'd0,5'd0,5'd0,OP_LDX};	// ldo mc0,[mc0+mc1]
	end
12'h133:
	begin
		next_ip=12'h000;
		instr.aRa={3'd0,MC0};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd0;
		instr.ins={21'd0,2'd2,5'd0,2'd3,3'd0,OP_RTD};	// jmpx [mc0]
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
		instr.ins={3'd0,6'd0,14'h3033,5'd0,5'd0,OP_CSR};		// MC0=TVEC[3]
	end
12'h141:
	begin
		next_ip=12'h142;
		instr.aRa=9'd0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={3'd0,MC1};
		instr.ins={3'd0,6'd0,14'h3006,5'd0,5'd0,OP_CSR};		// MC1=Cause
	end
12'h142:
	begin
		next_ip=12'h143;
		instr.aRa={3'd0,MC0};
		instr.aRb={3'd0,MC1};
		instr.aRc=9'd0;
		instr.aRt={3'd0,MC0};
		instr.ins={FN_LDOX,11'd0,2'd3,5'd0,5'd0,5'd0,OP_LDX};	// ldo mc0,[mc0+mc1*]
	end
12'h143:
	begin
		next_ip=12'h144;
		instr.aRa={3'd0,MC0};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={3'd0,MC1};
		instr.ins={21'h0FF,2'd2,5'd0,5'd0,OP_ANDI};	// and mc1,mc0,255
	end
12'h144:
	begin
		next_ip=12'h145;
		instr.aRa={3'd0,MC1};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd0;
		instr.ins={4'h8,1'b0,8'd8,5'd0,5'd0,5'd0,5'd0,OP_CHK};		// MC1=Cause
	end
12'h145:
	begin
		next_ip=12'h146;
		instr.aRa={3'd0,MC0};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={3'd0,MC1};
		instr.ins={21'h1FFF00,2'd2,5'd0,5'd0,OP_ANDI};	// and mc1,mc0,-256
	end
12'h146:
	begin
		next_ip=12'h000;
		instr.aRa={3'd0,MC1};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd0;
		instr.ins={21'd0,2'd2,5'd0,2'd3,3'd0,OP_RTD};	// jmpx [mc1]
	end
12'h147:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end

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
		instr.ins = {3'd0,2'd0,CSR_CTX,5'd0,5'd0,OP_CSR};
		instr.pred_btst=6'd0;
	end
12'h151:
	begin
		next_ip=12'h152;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd1;
		instr.ins={21'h00008,2'd2,5'd0,5'd1,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h152:
	begin
		next_ip=12'h153;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd2;
		instr.ins={21'h00010,2'd2,5'd0,5'd2,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h153:
	begin
		next_ip=12'h154;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd3;
		instr.ins={21'h00018,2'd2,5'd0,5'd3,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h154:
	begin
		next_ip=12'h155;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd4;
		instr.ins={21'h00020,2'd2,5'd0,5'd4,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h155:
	begin
		next_ip=12'h156;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd5;
		instr.ins={21'h00028,2'd2,5'd0,5'd5,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h156:
	begin
		next_ip=12'h157;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd6;
		instr.ins={21'h00030,2'd2,5'd0,5'd6,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h157:
	begin
		next_ip=12'h158;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd7;
		instr.ins={21'h00038,2'd2,5'd0,5'd7,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h158:
	begin
		next_ip=12'h159;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd8;
		instr.ins={21'h00040,2'd2,5'd0,5'd8,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h159:
	begin
		next_ip=12'h15A;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd9;
		instr.ins={21'h00048,2'd2,5'd0,5'd9,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h15A:
	begin
		next_ip=12'h15B;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd10;
		instr.ins={21'h00050,2'd2,5'd0,5'd10,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h15B:
	begin
		next_ip=12'h15C;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd11;
		instr.ins={21'h00058,2'd2,5'd0,5'd11,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h15C:
	begin
		next_ip=12'h15D;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd12;
		instr.ins={21'h00060,2'd2,5'd0,5'd12,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h15D:
	begin
		next_ip=12'h15E;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd13;
		instr.ins={21'h00068,2'd2,5'd0,5'd13,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h15E:
	begin
		next_ip=12'h15F;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd14;
		instr.ins={21'h00070,2'd2,5'd0,5'd14,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h15F:
	begin
		next_ip=12'h160;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd15;
		instr.ins={21'h00078,2'd2,5'd0,5'd15,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h160:
	begin
		next_ip=12'h161;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd16;
		instr.ins={21'h00080,2'd2,5'd0,5'd16,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h161:
	begin
		next_ip=12'h162;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd17;
		instr.ins={21'h00088,2'd2,5'd0,5'd17,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h162:
	begin
		next_ip=12'h163;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd18;
		instr.ins={21'h00090,2'd2,5'd0,5'd18,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h163:
	begin
		next_ip=12'h164;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd19;
		instr.ins={21'h00098,2'd2,5'd0,5'd19,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h164:
	begin
		next_ip=12'h165;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd20;
		instr.ins={21'h000A0,2'd2,5'd0,5'd20,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h165:
	begin
		next_ip=12'h166;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd21;
		instr.ins={21'h000A8,2'd2,5'd0,5'd21,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h166:
	begin
		next_ip=12'h167;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd22;
		instr.ins={21'h000B0,2'd2,5'd0,5'd22,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h167:
	begin
		next_ip=12'h168;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd23;
		instr.ins={21'h000B8,2'd2,5'd0,5'd23,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h168:
	begin
		next_ip=12'h169;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd24;
		instr.ins={21'h000C0,2'd2,5'd0,5'd24,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h169:
	begin
		next_ip=12'h16A;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd25;
		instr.ins={21'h000C8,2'd2,5'd0,5'd25,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h16A:
	begin
		next_ip=12'h16B;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd26;
		instr.ins={21'h000D0,2'd2,5'd0,5'd26,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h16B:
	begin
		next_ip=12'h16C;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd27;
		instr.ins={21'h000D8,2'd2,5'd0,5'd27,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h16C:
	begin
		next_ip=12'h16D;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd28;
		instr.ins={21'h000E0,2'd2,5'd0,5'd28,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h16D:
	begin
		next_ip=12'h16E;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd29;
		instr.ins={21'h000E8,2'd2,5'd0,5'd29,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h16E:
	begin
		next_ip=12'h16F;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd30;
		instr.ins={21'h000F0,2'd2,5'd0,5'd30,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h16F:
	begin
		next_ip=12'h170;
		instr.aRa=MC0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd31;
		instr.ins={21'h000F8,2'd2,5'd0,5'd31,OP_LDO};
		instr.pred_btst=6'd0;
	end
12'h170:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h171:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h172:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h173:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end

// -----------------------------------------------------------------------------
// RESET...
// This to prime the renamer and TLB.
// -----------------------------------------------------------------------------
12'h1A0:	
	begin
		next_ip = 12'h1A1;
		instr.ins = {24'h123456,2'd2,7'h40,7'h40,1'b1,OP_ADDI};
		instr.aRt = MC0;
		regx = 4'h1;
	end
12'h1A1:
	begin
		next_ip = 12'h1A2;
		instr.ins = {24'h123456,2'd2,7'd0,7'd0,1'b0,OP_ADDI};
		instr.aRt = MC0;
		regx = 4'h1;
	end
12'h1A2:
	begin
		next_ip = 12'h1A3;
		instr.ins = {24'h123456,2'd2,7'd0,7'd0,1'b0,OP_ADDI};
		instr.aRt = MC0;
		regx = 4'h1;
	end
12'h1A3:
	begin
		next_ip = 12'h1A4;
		instr.ins = {24'h123456,2'd2,7'd0,7'd0,1'b0,OP_ADDI};
		instr.aRt = MC0;
		regx = 4'h1;
	end
12'h1A4:
	begin
		next_ip = 12'h1A5;
		instr.ins = {24'h123456,2'd2,7'd0,7'd0,1'b0,OP_ADDI};
		instr.aRt = MC0;
		regx = 4'h1;
	end
12'h1A5:
	begin
		next_ip = 12'h1A6;
		instr.ins = {24'h123456,2'd2,7'd0,7'd0,1'b0,OP_ADDI};
		instr.aRt = MC0;
		regx = 4'h1;
	end
12'h1A6:
	begin
		next_ip = 12'h1A7;
		instr.ins = {24'h123456,2'd2,7'd0,7'd0,1'b0,OP_ADDI};
		instr.aRt = MC0;
		regx = 4'h1;
	end
12'h1A7:
	begin
		next_ip = 12'h1A8;
		instr.ins = {24'h123456,2'd2,7'd0,7'd0,1'b0,OP_ADDI};
		instr.aRt = MC0;
		regx = 4'h1;
	end
12'h1A8:
	begin
		next_ip = 12'h1A9;
		instr.ins = {24'h123456,2'd2,7'd0,7'd0,1'b0,OP_ADDI};
		instr.aRt = MC0;
		regx = 4'h1;
	end
12'h1A9:
	begin
		next_ip = 12'h1AA;
		instr.ins = {24'h123456,2'd2,7'd0,7'd0,1'b0,OP_ADDI};
		instr.aRt = MC0;
		regx = 4'h1;
	end
12'h1AA:
	begin
		next_ip = 12'h1AB;
		instr.ins = {24'h123456,2'd2,7'd0,7'd0,1'b0,OP_ADDI};
		instr.aRt = MC0;
		regx = 4'h1;
	end
12'h1AB:
	begin
		next_ip = 12'h1AC;
		instr.ins = {24'h123456,2'd2,7'd0,7'd0,1'b0,OP_ADDI};
		instr.aRt = MC0;
		regx = 4'h1;
	end
12'h1AC:
	begin
		next_ip = 12'h1AD;
		instr.ins = {24'h123456,2'd2,7'd0,7'd0,1'b0,OP_ADDI};
		instr.aRt = MC0;
		regx = 4'h1;
	end
12'h1AD:
	begin
		next_ip = 12'h1AE;
		instr.ins = {24'h123456,2'd2,7'd0,7'd0,1'b0,OP_ADDI};
		instr.aRt = MC0;
		regx = 4'h1;
	end
12'h1AE:
	begin
		next_ip = 12'h1AF;
		instr.ins = {24'h123456,2'd2,7'd0,7'd0,1'b0,OP_ADDI};
		instr.aRt = MC0;
		regx = 4'h1;
	end
12'h1AF:
	begin
		next_ip = 12'h1B0;
		instr.ins = {24'h123456,2'd2,7'd0,7'd0,1'b0,OP_ADDI};
		instr.aRt = MC0;
		regx = 4'h1;
	end
12'h1B0:
	begin
		next_ip = 12'h1B1;
		instr.ins = {24'h123456,2'd2,7'd0,7'd0,1'b0,OP_ADDI};
		instr.aRt = MC0;
		regx = 4'h1;
	end
12'h1B1:
	begin
		next_ip = 12'h1B2;
		instr.ins = {24'h123456,2'd2,7'd0,7'd0,1'b0,OP_ADDI};
		instr.aRt = MC0;
		regx = 4'h1;
	end
12'h1B2:
	begin
		next_ip = 12'h1B3;
		instr.ins = {24'h123456,2'd2,7'd0,7'd0,1'b0,OP_ADDI};
		instr.aRt = MC0;
		regx = 4'h1;
	end
12'h1B3:
	begin
		next_ip = 12'h1B4;
		instr.ins = {24'h123456,2'd2,7'd0,7'd0,1'b0,OP_ADDI};
		instr.aRt = MC0;
		regx = 4'h1;
	end
12'h1B4:
	begin
		next_ip = 12'h1B5;
		instr.ins = {24'h123456,2'd2,7'd0,7'd0,1'b0,OP_ADDI};
		instr.aRt = MC0;
		regx = 4'h1;
	end
12'h1B5:
	begin
		next_ip = 12'h1B6;
		instr.ins = {24'h123456,2'd2,7'd0,7'd0,1'b0,OP_ADDI};
		instr.aRt = MC0;
		regx = 4'h1;
	end
12'h1B6:
	begin
		next_ip = 12'h1B7;
		instr.ins = {24'h123456,2'd2,7'd0,7'd0,1'b0,OP_ADDI};
		instr.aRt = MC0;
		regx = 4'h1;
	end
12'h1B7:
	begin
		next_ip = 12'h1B8;
		instr.ins = {24'h123456,2'd2,7'd0,7'd0,1'b0,OP_ADDI};
		instr.aRt = MC0;
		regx = 4'h1;
	end
12'h1B8:	
	begin
		next_ip = 12'h1B9;
		instr.ins = {41'd0,OP_NOP};
	end
/*
12'h1B9:	
	begin 
		next_ip = 12'h1BA;
		instr.ins = {20'hFFFE0,2'd2,5'd0,SP,1'b0,OP_LDO};
		instr.aRt = MSP;
	end			// SP = Mem[FFFFFFE0]
12'h1BA:
	begin
		next_ip = 12'h1BB;
		instr.ins = {20'hFFFE8,2'd2,5'd0,5'd1,1'b0,OP_LDO};
		instr.aRt = MC0;
	end			// PC = Mem[FFFFFFE8]
*/
12'h1B9:	
	begin
		next_ip = 12'h1BA;
		instr.ins = {24'hFFFBC0,2'd2,7'd0,7'd0,1'b0,OP_JSR};
		instr.aRa = 9'd0;
		instr.aRt = 9'd0;
	end
12'h1BA:	
	begin
		next_ip = 12'h1BB;
		instr.ins = {41'd0,OP_NOP};
	end
12'h1BB:	
	begin
		next_ip = 12'h1BC;
		instr.ins = {41'd0,OP_NOP};
	end
12'h1BC:	
	begin
		next_ip = 12'h000;
		instr.ins = {41'd0,OP_NOP};
	end
12'h1BD:	
	begin
		next_ip = 12'h000;
		instr.ins = {41'd0,OP_NOP};
	end
12'h1BE:	
	begin
		next_ip = 12'h000;
		instr.ins = {41'd0,OP_NOP};
	end
12'h1BF:	
	begin
		next_ip = 12'h000;
		instr.ins = {41'd0,OP_NOP};
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
12'h1D0:
	begin
		next_ip = 12'h1D1;
		instr.ins = {-{14'd0,ir[16:13],3'd0},2'd2,FP,SP,OP_ADDI};
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
			instr.ins = {21'h000000,2'd2,SP,S0,OP_LDO};
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
			instr.ins = {41'd0,OP_NOP};
		end
	end
12'h1D2:
	begin
		if (ir[16:13]>4'd1) begin
			next_ip = 12'h1D3;
			instr.ins = {21'h000008,2'd2,SP,S1,OP_LDO};
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
			instr.ins = {41'd0,OP_NOP};
		end
	end
12'h1D3:
	begin
		if (ir[16:13]>4'd2) begin
			next_ip = 12'h1D4;
			instr.ins = {21'h000010,2'd2,SP,S2,OP_LDO};
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
			instr.ins = {41'd0,OP_NOP};
		end
	end
12'h1D4:
	begin
		if (ir[16:13]>4'd3) begin
			next_ip = 12'h1D5;
			instr.ins = {21'h000018,2'd2,SP,S3,OP_LDO};
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
			instr.ins = {41'd0,OP_NOP};
		end
	end
12'h1D5:
	begin
		if (ir[16:13]>4'd4) begin
			next_ip = 12'h1D6;
			instr.ins = {21'h000020,2'd2,SP,S4,OP_LDO};
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
			instr.ins = {41'd0,OP_NOP};
		end
	end
12'h1D6:
	begin
		if (ir[16:13]>4'd5) begin
			next_ip = 12'h1D7;
			instr.ins = {21'h000028,2'd2,SP,S5,OP_LDO};
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
			instr.ins = {41'd0,OP_NOP};
		end
	end
12'h1D7:
	begin
		if (ir[16:13]>4'd6) begin
			next_ip = 12'h1D8;
			instr.ins = {21'h000030,2'd2,SP,S6,OP_LDO};
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
			instr.ins = {41'd0,OP_NOP};
		end
	end
12'h1D8:
	begin
		if (ir[16:13]>4'd7) begin
			next_ip = 12'h1D9;
			instr.ins = {21'h000038,2'd2,SP,S7,OP_LDO};
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
			instr.ins = {41'd0,OP_NOP};
		end
	end
12'h1D9:
	begin
		if (ir[16:13]>4'd8) begin
			next_ip = 12'h1DA;
			instr.ins = {21'h000040,2'd2,SP,S8,OP_LDO};
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
			instr.ins = {41'd0,OP_NOP};
		end
	end
12'h1DA:
	begin
		if (ir[16:13]>4'd9) begin
			next_ip = 12'h1DB;
			instr.ins = {21'h000048,2'd2,SP,S8,OP_LDO};
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
			instr.ins = {41'd0,OP_NOP};
		end
	end

12'h1DB:	// mov sp,fp
	begin
		next_ip = 12'h1DC;
		instr.ins = {21'h000000,2'd2,FP,SP,OP_ORI};
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
		instr.ins = {21'h000000,2'd2,SP,FP,OP_LDO};
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
		instr.ins = {21'h000008,2'd2,SP,5'd1,OP_LDO};
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
		instr.ins = {21'h000020,2'd2,SP,SP,OP_ADDI};
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
		instr.ins = {ir[37:17],2'd2,SP,SP,OP_ADDI};
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
		instr.ins = {21'd0,ir[39:38],2'd3,3'd1,SP,OP_ADDSI};
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
		instr.ins = {16'd0,ir[11:7],2'd2,5'd1,5'd0,OP_JSR};
		instr.aRa = LR0;
		instr.aRt = 9'd0;
	end
12'h1E2:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h1E3:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h1E4:	begin next_ip = 12'h1E5; instr.ins = {41'd0,OP_NOP};	end
12'h1E5:	begin next_ip = 12'h1E6; instr.ins = {41'd0,OP_NOP};	end
12'h1E6:	begin next_ip = 12'h1E7; instr.ins = {41'd0,OP_NOP};	end
12'h1E7:	begin next_ip = 12'h1D0; instr.ins = {41'd0,OP_NOP};	end

// -----------------------------------------------------------------------------
// R3V
// R3 Vector Instructions
// - setup so that a PRED modifier may precede the instruction.
// -----------------------------------------------------------------------------
12'h200:
	begin
		next_ip = 12'h201; 
		instr.element = 3'd0;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd0};
		instr.aRb = ~|ir.r3.Rb ? 9'd0 : {ir.r3.Rb,3'd0};
		instr.aRc = ~|ir.r3.Rc ? 9'd0 : {ir.r3.Rc,3'd0};
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd0};
		instr.ins = ir;
		instr.pred_btst = 6'd0;
	end
12'h201:
	begin
		next_ip = 12'h202; 
		instr.element = 3'd1;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd1};
		instr.aRb = ~|ir.r3.Rb ? 9'd0 : {ir.r3.Rb,3'd1};
		instr.aRc = ~|ir.r3.Rc ? 9'd0 : {ir.r3.Rc,3'd1};
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd1};
		instr.ins = ir;
		instr.pred_btst = 6'd8;
	end
12'h202:
	begin
		next_ip = 12'h203; 
		instr.element = 3'd2;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd2};
		instr.aRb = ~|ir.r3.Rb ? 9'd0 : {ir.r3.Rb,3'd2};
		instr.aRc = ~|ir.r3.Rc ? 9'd0 : {ir.r3.Rc,3'd2};
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd2};
		instr.ins = ir;
		instr.pred_btst = 6'd16;
	end
12'h203:
	begin
		next_ip = 12'h204; 
		instr.element = 3'd3;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd3};
		instr.aRb = ~|ir.r3.Rb ? 9'd0 : {ir.r3.Rb,3'd3};
		instr.aRc = ~|ir.r3.Rc ? 9'd0 : {ir.r3.Rc,3'd3};
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd3};
		instr.ins = ir;
		instr.pred_btst = 6'd24;
	end
12'h204:
	begin
		next_ip = 12'h205; 
		instr.element = 3'd4;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd4};
		instr.aRb = ~|ir.r3.Rb ? 9'd0 : {ir.r3.Rb,3'd4};
		instr.aRc = ~|ir.r3.Rc ? 9'd0 : {ir.r3.Rc,3'd4};
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd4};
		instr.ins = ir;
		instr.pred_btst = 6'd32;
	end
12'h205:
	begin
		next_ip = 12'h206; 
		instr.element = 3'd5;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd5};
		instr.aRb = ~|ir.r3.Rb ? 9'd0 : {ir.r3.Rb,3'd5};
		instr.aRc = ~|ir.r3.Rc ? 9'd0 : {ir.r3.Rc,3'd5};
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd5};
		instr.ins = ir;
		instr.pred_btst = 6'd40;
	end
12'h206:
	begin
		next_ip = 12'h207; 
		instr.element = 3'd6;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd6};
		instr.aRb = ~|ir.r3.Rb ? 9'd0 : {ir.r3.Rb,3'd6};
		instr.aRc = ~|ir.r3.Rc ? 9'd0 : {ir.r3.Rc,3'd6};
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd6};
		instr.ins = ir;
		instr.pred_btst = 6'd48;
	end
12'h207:
	begin
		next_ip = 12'h208;
		instr.element = 3'd7;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd7};
		instr.aRb = ~|ir.r3.Rb ? 9'd0 : {ir.r3.Rb,3'd7};
		instr.aRc = ~|ir.r3.Rc ? 9'd0 : {ir.r3.Rc,3'd7};
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd7};
		instr.ins = ir;
		instr.pred_btst = 6'd56;
	end
12'h208:
	begin
		next_ip = 12'h209;
		instr.aRa = {ir.r3.Rt,3'd7};
		instr.aRb = 9'd0;
		instr.aRc = 9'd0;
		instr.aRt = VERR;
		instr.ins = {FN_MVVR,2'd2,4'd0,5'd0,5'd0,5'd0,OP_R2};
		instr.pred_btst = 6'd0;
	end
12'h209:
	begin
		next_ip = 12'h20A;
		instr.aRa = {ir.r3.Rt,3'd7};
		instr.aRb = 9'd0;
		instr.aRc = 9'd0;
		instr.aRt = VRM;
		instr.ins = {FN_MVVR,2'd2,4'd0,5'd0,5'd0,5'd0,OP_R2};
		instr.pred_btst = 6'd0;
	end
12'h20A:
	begin
		next_ip = 12'h20A;
		instr.ins = {28'h5,5'd0,OP_BSR};
		instr.aRa = 9'd0;
		instr.aRb = 9'd0;
		instr.aRc = 9'd0;
		instr.aRt = 9'd0;
	end

//12'h208:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
//12'h209:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
//12'h20A:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h20B:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end

// -----------------------------------------------------------------------------
// R3VS
// R3 Vector Scalar Instructions
// - setup so that a PRED modifier may precede the instruction.
// -----------------------------------------------------------------------------
12'h210:
	begin
		next_ip = 12'h211; 
		instr.element = 3'd0;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd0};
		instr.aRb = {3'b0,ir.r3.Rb};
		instr.aRc = ~|ir.r3.Rc ? 9'd0 : {ir.r3.Rc,3'd0};
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd0};
		instr.ins = ir;
		instr.pred_btst = 6'd0;
	end
12'h211:
	begin
		next_ip = 12'h212; 
		instr.element = 3'd1;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd1};
		instr.aRb = {3'b0,ir.r3.Rb};
		instr.aRc = ~|ir.r3.Rc ? 9'd0 : {ir.r3.Rc,3'd1};
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd1};
		instr.ins = ir;
		instr.pred_btst = 6'd8;
	end
12'h212:
	begin
		next_ip = 12'h213; 
		instr.element = 3'd2;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd2};
		instr.aRb = {3'b0,ir.r3.Rb};
		instr.aRc = ~|ir.r3.Rc ? 9'd0 : {ir.r3.Rc,3'd2};
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd2};
		instr.ins = ir;
		instr.pred_btst = 6'd16;
	end
12'h213:
	begin
		next_ip = 12'h214; 
		instr.element = 3'd3;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd3};
		instr.aRb = {3'b0,ir.r3.Rb};
		instr.aRc = ~|ir.r3.Rc ? 9'd0 : {ir.r3.Rc,3'd3};
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd3};
		instr.ins = ir;
		instr.pred_btst = 6'd24;
	end
12'h214:
	begin
		next_ip = 12'h215; 
		instr.element = 3'd4;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd4};
		instr.aRb = {3'b0,ir.r3.Rb};
		instr.aRc = ~|ir.r3.Rc ? 9'd0 : {ir.r3.Rc,3'd4};
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd4};
		instr.ins = ir;
		instr.pred_btst = 6'd32;
	end
12'h215:
	begin
		next_ip = 12'h216; 
		instr.element = 3'd5;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd5};
		instr.aRb = {3'b0,ir.r3.Rb};
		instr.aRc = ~|ir.r3.Rc ? 9'd0 : {ir.r3.Rc,3'd5};
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd5};
		instr.ins = ir;
		instr.pred_btst = 6'd40;
	end
12'h216:
	begin
		next_ip = 12'h217; 
		instr.element = 3'd6;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd6};
		instr.aRb = {3'b0,ir.r3.Rb};
		instr.aRc = ~|ir.r3.Rc ? 9'd0 : {ir.r3.Rc,3'd6};
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd6};
		instr.ins = ir;
		instr.pred_btst = 6'd48;
	end
12'h217:
	begin
		next_ip = 12'h208; 
		instr.element = 3'd7;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd7};
		instr.aRb = {3'b0,ir.r3.Rb};
		instr.aRc = ~|ir.r3.Rc ? 9'd0 : {ir.r3.Rc,3'd7};
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd7};
		instr.ins = ir;
		instr.pred_btst = 6'd56;
	end

12'h218:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h219:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h21A:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h21B:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end

// -----------------------------------------------------------------------------
// VANDI / VORI / VEORI / VCMPI / VADDI / VDIVI / VMULI
// -----------------------------------------------------------------------------
12'h220:
	begin
		next_ip = 12'h221;
		instr.element = 3'd0;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd0};
		instr.aRb = 9'd0;
		instr.aRc = 9'd0;
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd0};
		instr.ins = ir;
		instr.pred_btst = 6'd0;
	end
12'h221:
	begin
		next_ip = 12'h222; 
		instr.element = 3'd1;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd1};
		instr.aRb = 9'd0;
		instr.aRc = 9'd0;
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd1};
		instr.ins = ir;
		instr.pred_btst = 6'd8;
	end
12'h222:
	begin
		next_ip = 12'h223; 
		instr.element = 3'd2;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd2};
		instr.aRb = 9'd0;
		instr.aRc = 9'd0;
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd2};
		instr.ins = ir;
		instr.pred_btst = 6'd16;
	end
12'h223:
	begin
		next_ip = 12'h224; 
		instr.element = 3'd3;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd3};
		instr.aRb = 9'd0;
		instr.aRc = 9'd0;
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd3};
		instr.ins = ir;
		instr.pred_btst = 6'd24;
	end
12'h224:
	begin
		next_ip = 12'h225; 
		instr.element = 3'd4;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd4};
		instr.aRb = 9'd0;
		instr.aRc = 9'd0;
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd4};
		instr.ins = ir;
		instr.pred_btst = 6'd32;
	end
12'h225:
	begin
		next_ip = 12'h226; 
		instr.element = 3'd5;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd5};
		instr.aRb = 9'd0;
		instr.aRc = 9'd0;
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd5};
		instr.ins = ir;
		instr.pred_btst = 6'd40;
	end
12'h226:
	begin
		next_ip = 12'h227; 
		instr.element = 3'd6;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd6};
		instr.aRb = 9'd0;
		instr.aRc = 9'd0;
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd6};
		instr.ins = ir;
		instr.pred_btst = 6'd48;
	end
12'h227:
	begin
		next_ip = 12'h208; 
		instr.element = 3'd7;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd7};
		instr.aRb = 9'd0;
		instr.aRc = 9'd0;
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd7};
		instr.ins = ir;
		instr.pred_btst = 6'd56;
	end

12'h228:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h229:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h22A:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h22B:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end

// -----------------------------------------------------------------------------
// VANDSI / VORSI / VEORSI / VADDSI
// -----------------------------------------------------------------------------
12'h230:
	begin
		next_ip = 12'h231; 
		instr.element = 3'd0;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd0};
		instr.aRb = 9'd0;
		instr.aRc = 9'd0;
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd0};
		instr.ins = ir;
		instr.pred_btst = 6'd0;
	end
12'h231:
	begin
		next_ip = 12'h232; 
		instr.element = 3'd1;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd1};
		instr.aRb = 9'd0;
		instr.aRc = 9'd0;
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd1};
		instr.ins = ir;
		instr.pred_btst = 6'd8;
	end
12'h232:
	begin
		next_ip = 12'h233; 
		instr.element = 3'd2;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd2};
		instr.aRb = 9'd0;
		instr.aRc = 9'd0;
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd2};
		instr.ins = ir;
		instr.pred_btst = 6'd16;
	end
12'h233:
	begin
		next_ip = 12'h234; 
		instr.element = 3'd3;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd3};
		instr.aRb = 9'd0;
		instr.aRc = 9'd0;
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd3};
		instr.ins = ir;
		instr.pred_btst = 6'd24;
	end
12'h234:
	begin
		next_ip = 12'h235; 
		instr.element = 3'd4;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd4};
		instr.aRb = 9'd0;
		instr.aRc = 9'd0;
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd4};
		instr.ins = ir;
		instr.pred_btst = 6'd32;
	end
12'h235:
	begin
		next_ip = 12'h236; 
		instr.element = 3'd5;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd5};
		instr.aRb = 9'd0;
		instr.aRc = 9'd0;
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd5};
		instr.ins = ir;
		instr.pred_btst = 6'd40;
	end
12'h236:
	begin
		next_ip = 12'h237; 
		instr.element = 3'd6;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd6};
		instr.aRb = 9'd0;
		instr.aRc = 9'd0;
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd6};
		instr.ins = ir;
		instr.pred_btst = 6'd48;
	end
12'h237:
	begin
		next_ip = 12'h208; 
		instr.element = 3'd7;
		instr.aRa = ~|ir.r3.Ra ? 9'd0 : {ir.r3.Ra,3'd7};
		instr.aRb = 9'd0;
		instr.aRc = 9'd0;
		instr.aRt = ~|ir.r3.Rt ? 9'd0 : {ir.r3.Rt,3'd7};
		instr.ins = ir;
		instr.pred_btst = 6'd56;
	end

12'h238:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h239:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h23A:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h23B:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end

// -----------------------------------------------------------------------------
// sto s0s4
// -----------------------------------------------------------------------------
12'h240:
	begin
		next_ip = 12'h244;
		instr.aRa = {4'd0,ir.ls.Ra};
		instr.aRb = 10'd0;
		instr.aRc = {4'd0,S0};
		instr.aRt = 10'd0;
		instr.ins = {21'h000000,ir.ls.Ra,S0,OP_STO};
		instr.pred_btst = 6'd0;
	end
12'h241:
	begin
		next_ip = 12'h244;
		instr.aRa = {4'd0,ir.ls.Ra};
		instr.aRb = 10'd0;
		instr.aRc = {4'd0,S1};
		instr.aRt = 10'd0;
		instr.ins = {21'h000008,ir.ls.Ra,S1,OP_STO};
		instr.pred_btst = 6'd0;
	end
12'h242:
	begin
		next_ip = 12'h244;
		instr.aRa = {4'd0,ir.ls.Ra};
		instr.aRb = 10'd0;
		instr.aRc = {4'd0,S2};
		instr.aRt = 10'd0;
		instr.ins = {21'h000010,ir.ls.Ra,S2,OP_STO};
		instr.pred_btst = 6'd0;
	end
12'h243:
	begin
		next_ip = 12'h244;
		instr.aRa = {4'd0,ir.ls.Ra};
		instr.aRb = 10'd0;
		instr.aRc = {4'd0,S3};
		instr.aRt = 10'd0;
		instr.ins = {21'h000018,ir.ls.Ra,S3,OP_STO};
		instr.pred_btst = 6'd0;
	end
12'h244:
	begin
		next_ip = 12'h000;
		instr.aRa = {4'd0,ir.ls.Ra};
		instr.aRb = 10'd0;
		instr.aRc = {4'd0,S4};
		instr.aRt = 10'd0;
		instr.ins = {21'h000018,ir.ls.Ra,S4,OP_STO};
		instr.pred_btst = 6'd0;
	end
12'h245:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h246:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h247:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end

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
		instr.ins = {19'h7FFC0,2'd2,SP,SP,OP_ADDI};
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
		instr.ins = {19'h000000,2'd2,SP,6'd0,OP_STO};
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
		instr.ins = {19'h00008,2'd2,SP,6'd1,OP_STO};
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
		instr.ins = {19'h00010,2'd2,SP,6'd2,OP_STO};
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
		instr.ins = {19'h00018,2'd2,SP,6'd3,OP_STO};
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
		instr.ins = {19'h00020,2'd2,SP,6'd4,OP_STO};
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
		instr.ins = {19'h00028,2'd2,SP,6'd5,OP_STO};
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
		instr.ins = {19'h00030,2'd2,SP,6'd6,OP_STO};
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
		instr.ins = {19'h00038,2'd2,SP,6'd7,OP_STO};
		instr.pred_btst = 6'd0;
	end
12'h269:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h26A:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h26B:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end

// -----------------------------------------------------------------------------
// stv vn,[Ra+Rb*Sc]
// -----------------------------------------------------------------------------
12'h270:
	begin
		next_ip = 12'h274;
		instr.aRa = {3'd0,ir[18:13]};
		instr.aRb = 9'd0;
		instr.aRc = 9'd0;
		instr.aRt = {3'd0,ir[18:13]};
		instr.ins = {8'd0,ir[39:27],ir[18:13],ir[18:13],OP_ADDI};
		instr.pred_btst = 6'd0;
	end
12'h271:
	begin
		next_ip = 12'h274;
		instr.aRa = {3'd0,ir[18:13]};
		instr.aRb = {3'd0,ir[24:19]};
		instr.aRc = {ir[12:7],3'd0};
		instr.aRt = 9'd0;
		instr.ins = {FN_STOX,8'h00,ir[26:13],6'd0,OP_STX};
		instr.pred_btst = 6'd0;
	end
12'h272:
	begin
		next_ip = 12'h274;
		instr.aRa = {3'd0,ir[18:13]};
		instr.aRb = {3'd0,ir[24:19]};
		instr.aRc = {ir[12:7],3'd1};
		instr.aRt = 9'd0;
		instr.ins = {FN_STOX,8'h08,ir[26:13],6'd1,OP_STX};
		instr.pred_btst = 6'd0;
	end
12'h273:
	begin
		next_ip = 12'h274;
		instr.aRa = {3'd0,ir[18:13]};
		instr.aRb = {3'd0,ir[24:19]};
		instr.aRc = {ir[12:7],3'd2};
		instr.aRt = 9'd0;
		instr.ins = {FN_STOX,8'h10,ir[26:13],6'd2,OP_STX};
		instr.pred_btst = 6'd0;
	end
12'h274:
	begin
		next_ip = 12'h278;
		instr.aRa = {3'd0,ir[18:13]};
		instr.aRb = {3'd0,ir[24:19]};
		instr.aRc = {ir[12:7],3'd3};
		instr.aRt = 9'd0;
		instr.ins = {FN_STOX,8'h18,ir[26:13],6'd3,OP_STX};
		instr.pred_btst = 6'd0;
	end
12'h275:
	begin
		next_ip = 12'h278;
		instr.aRa = {3'd0,ir[18:13]};
		instr.aRb = {3'd0,ir[24:19]};
		instr.aRc = {ir[12:7],3'd4};
		instr.aRt = 9'd0;
		instr.ins = {FN_STOX,8'h20,ir[26:13],6'd4,OP_STX};
		instr.pred_btst = 6'd0;
	end
12'h276:
	begin
		next_ip = 12'h278;
		instr.aRa = {3'd0,ir[18:13]};
		instr.aRb = {3'd0,ir[24:19]};
		instr.aRc = {ir[12:7],3'd5};
		instr.aRt = 9'd0;
		instr.ins = {FN_STOX,8'h28,ir[26:13],6'd5,OP_STX};
		instr.pred_btst = 6'd0;
	end
12'h277:
	begin
		next_ip = 12'h278;
		instr.aRa = {3'd0,ir[18:13]};
		instr.aRb = {3'd0,ir[24:19]};
		instr.aRc = {ir[12:7],3'd6};
		instr.aRt = 9'd0;
		instr.ins = {FN_STOX,8'h30,ir[26:13],6'd6,OP_STX};
		instr.pred_btst = 6'd0;
	end
12'h278:
	begin
		next_ip = 12'h000;
		instr.aRa = {3'd0,ir[18:13]};
		instr.aRb = {3'd0,ir[24:19]};
		instr.aRc = {ir[12:7],3'd7};
		instr.aRt = 9'd0;
		instr.ins = {FN_STOX,8'h38,ir[26:13],6'd7,OP_STX};
		instr.pred_btst = 6'd0;
	end
12'h279:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h27A:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h27B:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end

// -----------------------------------------------------------------------------
// pop vn
// -----------------------------------------------------------------------------
12'h280:
	begin
		next_ip = 12'h284;
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRb = 10'd0;
		instr.aRc = {1'd0,ir[12:7],3'd0};
		instr.aRt = 10'd0;
		instr.ins = {19'h00000,2'd1,SP,6'd0,OP_LDO};
		instr.pred_btst = 6'd0;
	end
12'h281:
	begin
		next_ip = 12'h284;
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRb = 10'd0;
		instr.aRc = {1'd0,ir[12:7],3'd1};
		instr.aRt = 10'd0;
		instr.ins = {19'h00008,2'd2,SP,6'd1,OP_LDO};
		instr.pred_btst = 6'd0;
	end
12'h282:
	begin
		next_ip = 12'h284;
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRb = 10'd0;
		instr.aRc = {1'd0,ir[12:7],3'd2};
		instr.aRt = 10'd0;
		instr.ins = {19'h00010,2'd2,SP,6'd2,OP_LDO};
		instr.pred_btst = 6'd0;
	end
12'h283:
	begin
		next_ip = 12'h284;
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRb = 10'd0;
		instr.aRc = {1'd0,ir[12:7],3'd3};
		instr.aRt = 10'd0;
		instr.ins = {19'h00018,2'd2,SP,6'd3,OP_LDO};
		instr.pred_btst = 6'd0;
	end
12'h284:
	begin
		next_ip = 12'h288;
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRb = 10'd0;
		instr.aRc = {1'd0,ir[12:7],3'd4};
		instr.aRt = 10'd0;
		instr.ins = {21'h000020,2'd2,SP,6'd4,OP_LDO};
		instr.pred_btst = 6'd0;
	end
12'h285:
	begin
		next_ip = 12'h288;
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRb = 10'd0;
		instr.aRc = {1'd0,ir[12:7],3'd5};
		instr.aRt = 10'd0;
		instr.ins = {19'h00028,2'd2,SP,6'd5,OP_LDO};
		instr.pred_btst = 6'd0;
	end
12'h286:
	begin
		next_ip = 12'h288;
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRb = 10'd0;
		instr.aRc = {1'd0,ir[12:7],3'd6};
		instr.aRt = 10'd0;
		instr.ins = {19'h00030,2'd2,SP,6'd6,OP_LDO};
		instr.pred_btst = 6'd0;
	end
12'h287:
	begin
		next_ip = 12'h288;
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		instr.aRb = 10'd0;
		instr.aRc = {1'd0,ir[12:7],3'd7};
		instr.aRt = 10'd0;
		instr.ins = {19'h00038,2'd2,SP,6'd7,OP_LDO};
		instr.pred_btst = 6'd0;
	end
12'h288:
	begin
		next_ip = 12'h000;
		case(om)
		2'd0:	instr.aRa = SUSP;
		2'd1:	instr.aRa = SSSP;
		2'd2: instr.aRa = SHSP;
		2'd3:	instr.aRa = MSP;
		endcase
		case(om)
		2'd0:	instr.aRt = SUSP;
		2'd1:	instr.aRt = SSSP;
		2'd2: instr.aRt = SHSP;
		2'd3:	instr.aRt = MSP;
		endcase
		instr.aRb = 10'd0;
		instr.aRc = {4'd0,6'd1};
		instr.ins = {19'h00040,2'd2,SP,SP,OP_ADDI};
		instr.pred_btst = 6'd0;
	end
12'h289:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h28A:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h28B:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end

// -----------------------------------------------------------------------------
// ldv vn,[Ra+Rb*Sc],n
// -----------------------------------------------------------------------------
12'h290:
	begin
		next_ip = 12'h294;
		instr.aRa = {3'd0,ir[18:13]};
		instr.aRb = {3'd0,ir[24:19]};
		instr.aRt = {1'd0,ir[12:7],3'd0};
		instr.aRc = 9'd0;
		instr.ins = {FN_LDOX,8'h00,ir[26:13],6'd0,OP_LDO};
		instr.pred_btst = 6'd0;
	end
12'h291:
	begin
		next_ip = 12'h294;
		instr.aRa = {3'd0,ir[18:13]};
		instr.aRb = {3'd0,ir[24:19]};
		instr.aRt = {1'd0,ir[12:7],3'd1};
		instr.aRc = 9'd0;
		instr.ins = {FN_LDOX,8'h08,ir[26:13],6'd1,OP_LDO};
		instr.pred_btst = 6'd0;
	end
12'h292:
	begin
		next_ip = 12'h294;
		instr.aRa = {3'd0,ir[18:13]};
		instr.aRb = {3'd0,ir[24:19]};
		instr.aRt = {1'd0,ir[12:7],3'd2};
		instr.aRc = 9'd0;
		instr.ins = {FN_LDOX,8'h10,ir[26:13],6'd2,OP_LDO};
		instr.pred_btst = 6'd0;
	end
12'h293:
	begin
		next_ip = 12'h294;
		instr.aRa = {3'd0,ir[18:13]};
		instr.aRb = {3'd0,ir[24:19]};
		instr.aRt = {1'd0,ir[12:7],3'd3};
		instr.aRc = 9'd0;
		instr.ins = {FN_LDOX,8'h18,ir[26:13],6'd3,OP_LDO};
		instr.pred_btst = 6'd0;
	end
12'h294:
	begin
		next_ip = 12'h298;
		instr.aRa = {3'd0,ir[18:13]};
		instr.aRb = {3'd0,ir[24:19]};
		instr.aRt = {1'd0,ir[12:7],3'd4};
		instr.aRc = 9'd0;
		instr.ins = {FN_LDOX,8'h20,ir[26:13],6'd4,OP_LDO};
		instr.pred_btst = 6'd0;
	end
12'h295:
	begin
		next_ip = 12'h298;
		instr.aRa = {3'd0,ir[18:13]};
		instr.aRb = {3'd0,ir[24:19]};
		instr.aRt = {1'd0,ir[12:7],3'd5};
		instr.aRc = 9'd0;
		instr.ins = {FN_LDOX,8'h28,ir[26:13],6'd5,OP_LDO};
		instr.pred_btst = 6'd0;
	end
12'h296:
	begin
		next_ip = 12'h298;
		instr.aRa = {3'd0,ir[18:13]};
		instr.aRb = {3'd0,ir[24:19]};
		instr.aRt = {1'd0,ir[12:7],3'd6};
		instr.aRc = 9'd0;
		instr.ins = {FN_LDOX,8'h30,ir[26:13],6'd6,OP_LDO};
		instr.pred_btst = 6'd0;
	end
12'h297:
	begin
		next_ip = 12'h298;
		instr.aRa = {3'd0,ir[18:13]};
		instr.aRb = {3'd0,ir[24:19]};
		instr.aRt = {1'd0,ir[12:7],3'd7};
		instr.aRc = 9'd0;
		instr.ins = {FN_LDOX,8'h38,ir[26:13],6'd7,OP_LDO};
		instr.pred_btst = 6'd0;
	end
12'h298:
	begin
		next_ip = 12'h000;
		instr.aRa = {3'd0,ir[18:13]};
		instr.aRb = 9'd0;
		instr.aRc = 9'd0;
		instr.aRt = {3'd0,ir[18:13]};
		instr.ins = {8'd0,ir[39:27],ir[18:13],ir[18:13],OP_ADDI};
		instr.pred_btst = 6'd0;
	end
12'h299:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h29A:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end
12'h29B:	begin next_ip = 12'h000; instr.ins = {41'd0,OP_NOP};	end

// -----------------------------------------------------------------------------
// pusha
// -----------------------------------------------------------------------------
12'h300:
	begin
		next_ip=12'h301;
		instr.ins={41'd0,OP_NOP};
	end
12'h301:
	begin
		next_ip=12'h302;
		instr.ins={41'd0,OP_NOP};
	end
12'h302:
	begin
		next_ip=12'h303;
		instr.ins={41'd0,OP_NOP};
	end
12'h303:
	begin
		next_ip=12'h304;
		instr.ins={41'd0,OP_NOP};
	end
12'h304:
	begin
		next_ip=12'h305;
		instr.aRa=9'd32|om;
		instr.aRt=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.ins={21'h1FFF00,2'd2,SP,SP,OP_ADDI};
		instr.pred_btst=6'd0;
	end
12'h306:
	begin
		next_ip=12'h307;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd1;
		if (micro_ir[0])
			instr.ins={21'h00008,2'd2,SP,5'd1,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h307:
	begin
		next_ip=12'h308;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd2;
		if (micro_ir[1])
			instr.ins={21'h00010,2'd2,SP,5'd2,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h308:
	begin
		next_ip=12'h309;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd3;
		if (micro_ir[2])
			instr.ins={21'h00018,2'd2,SP,5'd3,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h309:
	begin
		next_ip=12'h30A;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd4;
		if (micro_ir[3])
			instr.ins={21'h00020,2'd2,SP,5'd4,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h30A:
	begin
		next_ip=12'h30B;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd5;
		if (micro_ir[4])
			instr.ins={21'h00028,2'd2,SP,5'd5,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h30B:
	begin
		next_ip=12'h30C;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd6;
		if (micro_ir[5])
			instr.ins={21'h00030,2'd2,SP,5'd6,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h30C:
	begin
		next_ip=12'h30D;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd7;
		if (micro_ir[6])
			instr.ins={21'h00038,2'd2,SP,5'd7,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h30D:
	begin
		next_ip=12'h30E;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd8;
		if (micro_ir[7])
			instr.ins={21'h00040,2'd2,SP,5'd8,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h30E:
	begin
		next_ip=12'h30F;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd9;
		if (micro_ir[8])
			instr.ins={21'h00048,2'd2,SP,5'd9,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h30F:
	begin
		next_ip=12'h310;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd10;
		if (micro_ir[9])
			instr.ins={21'h00050,2'd2,SP,5'd10,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h310:
	begin
		next_ip=12'h311;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd11;
		if (micro_ir[10])
			instr.ins={21'h00058,2'd2,SP,5'd11,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h311:
	begin
		next_ip=12'h312;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd12;
		if (micro_ir[11])
			instr.ins={21'h00060,2'd2,SP,5'd12,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h312:
	begin
		next_ip=12'h313;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd13;
		if (micro_ir[12])
			instr.ins={21'h00068,2'd2,SP,5'd13,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h313:
	begin
		next_ip=12'h314;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd14;
		if (micro_ir[13])
			instr.ins={21'h00070,2'd2,SP,5'd14,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h314:
	begin
		next_ip=12'h315;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd15;
		if (micro_ir[14])
			instr.ins={21'h00078,2'd2,SP,5'd15,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h315:
	begin
		next_ip=12'h316;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd16;
		if (micro_ir[15])
			instr.ins={21'h00080,2'd2,SP,5'd16,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h316:
	begin
		next_ip=12'h317;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd17;
		if (micro_ir[16])
			instr.ins={21'h00088,2'd2,SP,5'd17,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h317:
	begin
		next_ip=12'h318;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd18;
		if (micro_ir[17])
			instr.ins={21'h00090,2'd2,SP,5'd18,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h318:
	begin
		next_ip=12'h319;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd19;
		if (micro_ir[18])
			instr.ins={21'h00098,2'd2,SP,5'd19,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h319:
	begin
		next_ip=12'h31A;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd20;
		if (micro_ir[19])
			instr.ins={21'h000A0,2'd2,SP,5'd20,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h31A:
	begin
		next_ip=12'h31B;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd21;
		if (micro_ir[20])
			instr.ins={21'h000A8,2'd2,SP,5'd21,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h31B:
	begin
		next_ip=12'h31C;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd22;
		if (micro_ir[21])
			instr.ins={21'h000B0,2'd2,SP,5'd22,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h31C:
	begin
		next_ip=12'h31D;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd23;
		if (micro_ir[22])
			instr.ins={21'h000B8,2'd2,SP,5'd23,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h31D:
	begin
		next_ip=12'h31E;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd24;
		if (micro_ir[23])
			instr.ins={21'h000C0,2'd2,SP,5'd24,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h31E:
	begin
		next_ip=12'h31F;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd25;
		if (micro_ir[24])
			instr.ins={21'h000C8,2'd2,SP,5'd25,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h31F:
	begin
		next_ip=12'h320;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd26;
		if (micro_ir[25])
			instr.ins={21'h000D0,2'd2,SP,5'd26,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h320:
	begin
		next_ip=12'h321;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd27;
		if (micro_ir[26])
			instr.ins={21'h000D8,2'd2,SP,5'd27,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h321:
	begin
		next_ip=12'h322;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd28;
		if (micro_ir[27])
			instr.ins={21'h000E0,2'd2,SP,5'd28,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h322:
	begin
		next_ip=12'h323;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd29;
		if (micro_ir[28])
			instr.ins={21'h000E8,2'd2,SP,5'd29,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h323:
	begin
		next_ip=12'h324;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd30;
		if (micro_ir[29])
			instr.ins={21'h000F0,2'd2,SP,5'd30,OP_STO};
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h324:
	begin
		next_ip=12'h325;
		instr.ins={30'd5,3'd0,OP_BSR};
	end
12'h325:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,OP_NOP};
	end
12'h326:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,OP_NOP};
	end
12'h327:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,OP_NOP};
	end
12'h328:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,OP_NOP};
	end

// -----------------------------------------------------------------------------
// pushi
// -----------------------------------------------------------------------------
12'h330:
	begin
		next_ip=12'h331;
		instr.ins={41'd0,OP_NOP};
	end
12'h331:
	begin
		next_ip=12'h332;
		instr.ins={41'd0,OP_NOP};
	end
12'h332:
	begin
		next_ip=12'h333;
		instr.ins={41'd0,OP_NOP};
	end
12'h333:
	begin
		next_ip=12'h334;
		instr.ins={41'd0,OP_NOP};
	end
12'h334:
	begin
		next_ip=12'h335;
		instr.aRa=9'd32|om;
		instr.aRt=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.ins={21'h1FFFF8,2'd2,SP,SP,OP_ADDI};
	end
12'h335:
	begin
		next_ip=12'h336;
		instr.aRa=9'd0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=MC0;
		instr.ins={micro_ir[26:8],2'd2,5'd0,5'd1,OP_ORI};
	end
12'h336:
	begin
		next_ip=12'h337;
		instr.aRa=9'd0;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=MC0;
		instr.ins={{{10{micro_ir[39]}},micro_ir[39:27]},2'd2,3'd1,5'd1,OP_ADDSI};
	end
12'h337:
	begin
		next_ip=12'h338;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=MC0;
		instr.aRt=9'd0;
		instr.ins={21'h00000,2'd2,SP,5'd1,OP_STO};
		instr.pred_btst=6'd0;
	end
12'h338:
	begin
		next_ip=12'h339;
		instr.ins={30'd5,3'd0,OP_BSR};
	end
12'h339:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,OP_NOP};
	end
12'h33A:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,OP_NOP};
	end
12'h33B:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,OP_NOP};
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
		if (micro_ir[0]) begin
			instr.aRt=9'd1;
			instr.ins={21'h00008,2'd2,SP,5'd1,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h361:
	begin
		next_ip=12'h362;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[1]) begin
			instr.aRt=9'd2;
			instr.ins={21'h00010,2'd2,SP,5'd2,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h362:
	begin
		next_ip=12'h363;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[2]) begin
			instr.aRt=9'd3;
			instr.ins={21'h00018,2'd2,SP,5'd3,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h363:
	begin
		next_ip=12'h364;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[3]) begin
			instr.aRt=9'd4;
			instr.ins={21'h00020,2'd2,SP,5'd4,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h364:
	begin
		next_ip=12'h365;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[4]) begin
			instr.aRt=9'd5;
			instr.ins={21'h00028,2'd2,SP,5'd5,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h365:
	begin
		next_ip=12'h366;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[5]) begin
			instr.aRt=9'd6;
			instr.ins={21'h00030,2'd2,SP,5'd6,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h366:
	begin
		next_ip=12'h367;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[6]) begin
			instr.aRt=9'd7;
			instr.ins={21'h00038,2'd2,SP,5'd7,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h367:
	begin
		next_ip=12'h368;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[7]) begin
			instr.aRt=9'd8;
			instr.ins={21'h00040,2'd2,SP,5'd8,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h368:
	begin
		next_ip=12'h369;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[8]) begin
			instr.aRt=9'd9;
			instr.ins={21'h00048,2'd2,SP,5'd9,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h369:
	begin
		next_ip=12'h36A;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[9]) begin
			instr.aRt=9'd10;
			instr.ins={21'h00050,2'd2,SP,5'd10,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h36A:
	begin
		next_ip=12'h36B;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[10]) begin
			instr.aRt=9'd11;
			instr.ins={21'h00058,2'd2,SP,5'd11,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h36B:
	begin
		next_ip=12'h36C;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[11]) begin
			instr.aRt=9'd12;
			instr.ins={21'h00060,2'd2,SP,5'd12,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h36C:
	begin
		next_ip=12'h36D;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[12]) begin
			instr.aRt=9'd13;
			instr.ins={21'h00068,2'd2,SP,5'd13,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h36D:
	begin
		next_ip=12'h36E;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[13]) begin
			instr.aRt=9'd14;
			instr.ins={21'h00070,2'd2,SP,5'd14,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h36E:
	begin
		next_ip=12'h36F;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[14]) begin
			instr.aRt=9'd15;
			instr.ins={21'h00078,2'd2,SP,5'd15,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h36F:
	begin
		next_ip=12'h370;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[15]) begin
			instr.aRt=9'd16;
			instr.ins={21'h00080,2'd2,SP,5'd16,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h370:
	begin
		next_ip=12'h371;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[16]) begin
			instr.aRt=9'd17;
			instr.ins={21'h00088,2'd2,SP,5'd17,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h371:
	begin
		next_ip=12'h372;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[17]) begin
			instr.aRt=9'd18;
			instr.ins={21'h00090,2'd2,SP,5'd18,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h372:
	begin
		next_ip=12'h373;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[18]) begin
			instr.aRt=9'd19;
			instr.ins={21'h00098,2'd2,SP,5'd19,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h373:
	begin
		next_ip=12'h374;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[19]) begin
			instr.aRt=9'd20;
			instr.ins={21'h000A0,2'd2,SP,5'd20,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h374:
	begin
		next_ip=12'h375;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[20]) begin
			instr.aRt=9'd21;
			instr.ins={21'h000A8,2'd2,SP,5'd21,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h375:
	begin
		next_ip=12'h376;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[21]) begin
			instr.aRt=9'd22;
			instr.ins={21'h000B0,2'd2,SP,5'd22,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h376:
	begin
		next_ip=12'h377;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[22]) begin
			instr.aRt=9'd23;
			instr.ins={21'h000B8,2'd2,SP,5'd23,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h377:
	begin
		next_ip=12'h378;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[23]) begin
			instr.aRt=9'd24;
			instr.ins={21'h000C0,2'd2,SP,5'd24,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h378:
	begin
		next_ip=12'h379;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[24]) begin
			instr.aRt=9'd25;
			instr.ins={21'h000C8,2'd2,SP,5'd25,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h379:
	begin
		next_ip=12'h37A;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[25]) begin
			instr.aRt=9'd26;
			instr.ins={21'h000D0,2'd2,SP,5'd26,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h37A:
	begin
		next_ip=12'h37B;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[26]) begin
			instr.aRt=9'd27;
			instr.ins={21'h000D8,2'd2,SP,5'd27,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h37B:
	begin
		next_ip=12'h37C;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[27]) begin
			instr.aRt=9'd28;
			instr.ins={21'h000E0,2'd2,SP,5'd28,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h37C:
	begin
		next_ip=12'h37D;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[28]) begin
			instr.aRt=9'd29;
			instr.ins={21'h000E8,2'd2,SP,5'd29,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h37D:
	begin
		next_ip=12'h37E;
		instr.aRa=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		if (micro_ir[29]) begin
			instr.aRt=9'd30;
			instr.ins={21'h000F0,2'd2,SP,5'd30,OP_LDO};
		end
		else
			instr.ins={41'd0,OP_NOP};
		instr.pred_btst=6'd0;
	end
12'h37E:
	begin
		next_ip=12'h37F;
		instr.aRa=9'd32|om;
		instr.aRt=9'd32|om;
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.ins={21'h00100,2'd2,SP,SP,OP_ADDI};
		instr.pred_btst=6'd0;
	end
12'h37F:
	begin
		next_ip=12'h000;
		instr.ins={30'd5,3'd0,OP_BSR};
	end
12'h380:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,OP_NOP};
	end
12'h381:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,OP_NOP};
	end
12'h382:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,OP_NOP};
	end
12'h383:
	begin
		next_ip=12'h000;
		instr.ins={41'd0,OP_NOP};
	end

// -----------------------------------------------------------------------------
// BSET
// -----------------------------------------------------------------------------
12'h390:
	begin
		next_ip=12'h391;
		instr.aRa={4'd0,micro_ir[26:22]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd0;
		instr.ins = {18'd5,5'd0,5'd1,1'b0,4'd0,OP_Bcc};
	end
12'h391:
	begin
		next_ip=12'h392;
		instr.aRa={4'd0,micro_ir[16:12]};
		instr.aRb=9'd0;
		instr.aRc={4'd0,micro_ir[11:7]};
		instr.aRt=9'd0;
		instr.ins = {21'd0,2'd2,micro_ir[16:12],micro_ir[11:7],OP_STO};
		case(micro_ir[18:17])
		2'd0:	instr.ins.any.opcode = OP_STW;
		2'd1: instr.ins.any.opcode = OP_STT;
		2'd2:	instr.ins.any.opcode = OP_STO;
		2'd4:	instr.ins.any.opcode = OP_STB;
		default:	instr.ins.any.opcode = OP_STO;
		endcase	
	end
12'h392:
	begin
		next_ip=12'h393;
		instr.ins = {{{15{micro_ir[38]}},micro_ir[38:33]},2'd2,micro_ir[16:12],micro_ir[16:12],OP_ADDI};
		instr.aRa={4'd0,micro_ir[16:12]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={4'd0,micro_ir[16:12]};
	end
12'h393:
	begin
		next_ip=12'h390;
		instr.ins = {21'h1FFFFF,2'd2,5'd1,5'd1,OP_ADDI};
		instr.aRa={4'd0,micro_ir[26:22]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={4'd0,micro_ir[26:22]};
	end
12'h394:	begin next_ip = 12'h390; instr.ins = {41'd0,OP_NOP};	end
12'h395:	begin next_ip = 12'h390; instr.ins = {41'd0,OP_NOP};	end
12'h396:	begin next_ip = 12'h390; instr.ins = {41'd0,OP_NOP};	end
12'h397:	begin next_ip = 12'h390; instr.ins = {41'd0,OP_NOP};	end

// -----------------------------------------------------------------------------
// BMOV
// -----------------------------------------------------------------------------
12'h3A0:
	begin
		next_ip=12'h3A1;
		instr.aRa={4'd0,micro_ir[26:22]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd0;
		instr.ins = {18'd5,5'd0,5'd1,1'b0,4'd0,OP_Bcc};
	end
12'h3A1:
	begin
		next_ip=12'h3A2;
		instr.ins = {21'd0,2'd2,micro_ir[16:12],2'd1,OP_LDO};
		instr.aRa={4'd0,micro_ir[16:12]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=MC0;
		case(micro_ir[9:7])
		2'd0:	instr.ins.any.opcode = OP_LDW;
		2'd1: instr.ins.any.opcode = OP_LDT;
		2'd2:	instr.ins.any.opcode = OP_LDO;
		2'd4:	instr.ins.any.opcode = OP_LDB;
		default:	instr.ins.any.opcode = OP_LDO;
		endcase	
	end
12'h3A2:
	begin
		next_ip=12'h3A3;
		instr.ins = {21'd0,2'd2,micro_ir[21:17],2'd1,OP_STO};
		instr.aRa={3'd0,micro_ir[21:17]};
		instr.aRb=9'd0;
		instr.aRc=MC0;
		instr.aRt=9'd0;
		case(micro_ir[9:7])
		2'd0:	instr.ins.any.opcode = OP_STW;
		2'd1: instr.ins.any.opcode = OP_STT;
		2'd2:	instr.ins.any.opcode = OP_STO;
		2'd4:	instr.ins.any.opcode = OP_STB;
		default:	instr.ins.any.opcode = OP_STO;
		endcase	
	end
12'h3A3:
	begin
		next_ip=12'h3A4;
		instr.ins = {{{15{micro_ir[38]}},micro_ir[38:33]},2'd2,micro_ir[16:12],micro_ir[16:12],OP_ADDI};
		instr.aRa={4'd0,micro_ir[16:12]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={4'd0,micro_ir[16:12]};
	end
12'h3A4:
	begin
		next_ip=12'h3A5;
		instr.ins = {{{15{micro_ir[32]}},micro_ir[32:27]},2'd2,micro_ir[21:17],micro_ir[21:17],OP_ADDI};
		instr.aRa={4'd0,micro_ir[21:17]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={4'd0,micro_ir[21:17]};
	end
12'h3A5:
	begin
		next_ip=12'h3A0;
		instr.ins = {21'h1FFFFF,2'd2,5'd1,5'd1,OP_ADDI};
		instr.aRa={4'd0,micro_ir[26:22]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={4'd0,micro_ir[26:22]};
	end
12'h3A6:	begin next_ip = 12'h3A0; instr.ins = {41'd0,OP_NOP};	end
12'h3A7:	begin next_ip = 12'h3A0; instr.ins = {41'd0,OP_NOP};	end

// -----------------------------------------------------------------------------
// BCMP
// -----------------------------------------------------------------------------
12'h3B0:
	begin
		next_ip=12'h3B1;
		instr.aRa={4'd0,micro_ir[26:22]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd0;
		instr.ins = {18'd5,5'd0,5'd1,1'b0,4'd0,OP_Bcc};
	end
12'h3B1:
	begin
		next_ip=12'h3B2;
		instr.ins = {21'd0,2'd2,micro_ir[16:12],2'd1,OP_LDO};
		instr.aRa={4'd0,micro_ir[16:12]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=MC0;
		case(micro_ir[9:7])
		2'd0:	instr.ins.any.opcode = OP_LDW;
		2'd1: instr.ins.any.opcode = OP_LDT;
		2'd2:	instr.ins.any.opcode = OP_LDO;
		2'd4:	instr.ins.any.opcode = OP_LDB;
		default:	instr.ins.any.opcode = OP_LDO;
		endcase	
	end
12'h3B2:
	begin
		next_ip=12'h3B3;
		instr.ins = {21'd0,2'd2,micro_ir[21:17],2'd1,OP_LDO};
		instr.aRa={4'd0,micro_ir[21:17]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=MC1;
		case(micro_ir[9:7])
		2'd0:	instr.ins.any.opcode = OP_LDW;
		2'd1: instr.ins.any.opcode = OP_LDT;
		2'd2:	instr.ins.any.opcode = OP_LDO;
		2'd4:	instr.ins.any.opcode = OP_LDB;
		default:	instr.ins.any.opcode = OP_LDO;
		endcase	
	end
12'h3B3:
	begin
		next_ip=12'h3B4;
		instr.aRa={4'd0,micro_ir[16:12]};
		instr.aRb={4'd0,micro_ir[21:17]};
		instr.aRc=9'd0;
		instr.aRt=9'd0;
		instr.ins = {18'd5,micro_ir[21:17],micro_ir[16:12],1'b0,4'h0,OP_Bcc};
		case({micro_ir[39],micro_ir[11:10]})
		3'd0:	begin instr.ins.any.opcode = OP_Bcc; instr.ins.br.fn = EQ; end
		3'd1:	begin instr.ins.any.opcode = OP_Bcc; instr.ins.br.fn = NE; end
		3'd2:	begin instr.ins.any.opcode = OP_Bcc; instr.ins.br.fn = LT; end
		3'd3:	begin instr.ins.any.opcode = OP_Bcc; instr.ins.br.fn = LE; end
		3'd4:	begin instr.ins.any.opcode = OP_BccU; instr.ins.br.fn = LT; end
		3'd5:	begin instr.ins.any.opcode = OP_BccU; instr.ins.br.fn = LE; end
		default:	begin instr.ins.any.opcode = OP_Bcc; instr.ins.br.fn = EQ; end
		endcase	
	end
12'h3B4:
	begin
		next_ip=12'h3B5;
		instr.ins = {{{15{micro_ir[38]}},micro_ir[38:33]},2'd2,micro_ir[16:12],micro_ir[16:12],OP_ADDI};
		instr.aRa={4'd0,micro_ir[16:12]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={4'd0,micro_ir[16:12]};
	end
12'h3B5:
	begin
		next_ip=12'h3B6;
		instr.ins = {{{15{micro_ir[32]}},micro_ir[32:27]},2'd2,micro_ir[21:17],micro_ir[21:17],OP_ADDI};
		instr.aRa={4'd0,micro_ir[21:17]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={4'd0,micro_ir[21:17]};
	end
12'h3B6:
	begin
		next_ip=12'h3B0;
		instr.ins = {21'h1FFFFF,2'd2,5'd1,5'd1,OP_ADDI};
		instr.aRa={4'd0,micro_ir[26:22]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={4'd0,micro_ir[26:22]};
	end
12'h3B7:	begin next_ip = 12'h3B0; instr.ins = {41'd0,OP_NOP};	end

// -----------------------------------------------------------------------------
// BFND
// -----------------------------------------------------------------------------
12'h3C0:
	begin
		next_ip=12'h3C1;
		instr.aRa={4'd0,micro_ir[26:22]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=9'd0;
		instr.ins = {18'd5,5'd0,5'd1,1'b0,4'd0,OP_Bcc};
	end
12'h3C1:
	begin
		next_ip=12'h3C2;
		instr.ins = {21'd0,2'd2,micro_ir[21:17],2'd1,OP_LDO};
		instr.aRa={4'd0,micro_ir[21:17]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt=MC0;
		case(micro_ir[9:7])
		2'd0:	instr.ins.any.opcode = OP_LDW;
		2'd1: instr.ins.any.opcode = OP_LDT;
		2'd2:	instr.ins.any.opcode = OP_LDO;
		2'd4:	instr.ins.any.opcode = OP_LDB;
		default:	instr.ins.any.opcode = OP_LDO;
		endcase	
	end
12'h3C2:
	begin
		next_ip=12'h3C3;
		instr.ins = {18'd5,micro_ir[21:17],micro_ir[16:12],1'b0,4'h0,micro_ir[39] ? OP_Bcc: OP_BccU};
		instr.aRa={4'd0,micro_ir[16:12]};
		instr.aRb=MC0;
		instr.aRc=9'd0;
		instr.aRt=9'd0;
		instr.ins.br.fn = branch_fn_t'(micro_ir[36:33]);
	end
12'h3C3:
	begin
		next_ip=12'h3C4;
		instr.ins = {{{15{micro_ir[32]}},micro_ir[32:27]},2'd2,micro_ir[21:17],micro_ir[21:17],OP_ADDI};
		instr.aRa={4'd0,micro_ir[21:17]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={4'd0,micro_ir[21:17]};
	end
12'h3C4:
	begin
		next_ip=12'h3C0;
		instr.ins = {21'h1FFFFF,2'd2,5'd1,5'd1,OP_ADDI};
		instr.aRa={4'd0,micro_ir[26:22]};
		instr.aRb=9'd0;
		instr.aRc=9'd0;
		instr.aRt={4'd0,micro_ir[26:22]};
	end
12'h3C5:	begin next_ip = 12'h3C0; instr.ins = {41'd0,OP_NOP};	end
12'h3C6:	begin next_ip = 12'h3C0; instr.ins = {41'd0,OP_NOP};	end
12'h3C7:	begin next_ip = 12'h3C0; instr.ins = {41'd0,OP_NOP};	end

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
		instr.ins={21'h000000,ir[18:13],ir[12:7],OP_STO};
	end
	else begin
		next_ip = 12'h000;
		instr.ins = {41'd0,OP_NOP};
	end
12'h3C1:	// sub lc,lc,1
	begin
		lc_o = lc_i - 2'd1;
		next_ip = 12'h3C0;
		instr.ins={21'h1FFFFF,6'd55,6'd55,OP_ADDI};
	end
12'h3C2:
	begin
		next_ip = 12'h3C0;
		instr.ins={bamt,2'b0,ir[18:13],ir[18:13],OP_ADDI};		
	end
12'h3C3:
	begin
		next_ip = 12'h3C0;
		instr.ins = {5'd32,10'h0F0,6'd0,6'd55,2'd0,NE,OP_Bcc};
	end
*/
default:	begin next_ip = 12'h000; instr.ins = 40'hFFFFFFFFFF; end	// NOP      regx = 4'h2; 
endcase
end

endmodule
