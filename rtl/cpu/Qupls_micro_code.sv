// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
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
// ============================================================================

module Qupls_micro_code(micro_ip, micro_ir, next_ip, instr, regx);
input [11:0] micro_ip;
input instruction_t micro_ir;
output reg [11:0] next_ip;
output instruction_t instr;
output reg [3:0] regx;
parameter SP = 6'd63;
parameter FP = 6'd62;
parameter LR1 = 6'd57;
// Do not use 6'd0 as some logic will detect this as a zero.
parameter MC0 = 6'd1;
parameter MC1 = 6'd2;
parameter MC2 = 6'd3;
parameter MC3 = 6'd4;

always_comb
begin
	regx = 'd0;
case(micro_ip)
12'h000:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h001:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h002:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h003:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
// ENTER
12'h004:	begin next_ip = 12'h008; instr = {'d0,21'h1FFFC0,SP,SP,OP_ADDI}; end				// SP = SP - 64
12'h005:	begin next_ip = 12'h008; instr = {'d0,21'h000000,SP,FP,OP_STO};	end		// Mem[SP] = FP
12'h006:	begin next_ip = 12'h008; instr = {'d0,21'h000010,SP,LR1,OP_STO};	end	// Mem16[sp] = LR1
12'h007:	begin next_ip = 12'h008; instr = {'d0,21'h000020,SP,6'd0,OP_STO}; end		// Mem32[sp] = 0
12'h008:	begin next_ip = 12'h000; instr = {'d0,21'h000030,SP,6'd0,OP_STO}; end		// Mem48[sp] = 0
12'h009:	begin next_ip = 12'h000; instr = {'d0,FN_OR,1'd0,6'd0,SP,FP,OP_R2};	end // FP = SP
12'h00A:	begin next_ip = 12'h000; instr = {'d0,13'h0000,SP,SP,OP_ADDI}; end				// SP = SP + const
12'h00B:	begin next_ip = 12'h000; instr = {micro_ir[39:8],1'b0,OP_PFXB32};	end	
12'h00C:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h00D:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h00E:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h00F:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
// LEAVE
12'h010:	begin next_ip = 12'h014; instr = {'d0,13'h0000,6'd0,FP,SP,OP_ORI}; end		// SP = FP
12'h011:	begin next_ip = 12'h014; instr = {'d0,13'h0000,SP,FP,OP_LDO};	end			// FP = Mem[SP]
12'h012:	begin next_ip = 12'h014; instr = {'d0,13'h0010,SP,LR1,OP_LDO};	end		// LR1 = Mem16[sp]
12'h013:	begin next_ip = 12'h014; instr = {'d0,13'h0040,SP,SP,OP_ADDI}; end					// SP = SP + 64
12'h014:	begin next_ip = 12'h000; instr = {'d0,13'h0000,SP,SP,OP_ADDI}; end				// SP = SP + const
12'h015:	begin next_ip = 12'h000; instr = {'d0,micro_ir[31:13],4'h0,1'b0,OP_PFXB32};	end	
12'h016:	begin next_ip = 12'h000; instr = {'d0,7'h00,micro_ir[12:7],LR1,6'd0,OP_JSR}; end	// PC = LR1 + const
12'h017:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
// PUSH
12'h020:	begin next_ip = 12'h024; instr = {'d0,-{6'h00,micro_ir[39:37],4'h0},SP,SP,OP_ADDI}; end				// SP = SP - N * 16
12'h021:	begin next_ip = 12'h024; instr = micro_ir[39:37] > 3'd0 ? {'d0,9'h0,4'h0,SP,micro_ir[12: 7],OP_STO} : {'d0,OP_NOP};	end		// Mem[SP] = Rs
12'h022:	begin next_ip = 12'h024; instr = micro_ir[39:37] > 3'd1 ? {'d0,9'h1,4'h0,SP,micro_ir[18:13],OP_STO} : {'d0,OP_NOP};	end		// Mem[SP] = Ra
12'h023:	begin next_ip = 12'h024; instr = micro_ir[39:37] > 3'd2 ? {'d0,9'h2,4'h0,SP,micro_ir[24:19],OP_STO} : {'d0,OP_NOP};	end		// Mem[SP] = Rb
12'h024:	begin next_ip = 12'h000; instr = micro_ir[39:37] > 3'd3 ? {'d0,9'h3,4'h0,SP,micro_ir[30:25],OP_STO} : {'d0,OP_NOP};	end		// Mem[SP] = Rc
12'h025:	begin next_ip = 12'h000; instr = micro_ir[39:37] > 3'd4 ? {'d0,9'h4,4'h0,SP,micro_ir[36:31],OP_STO} : {'d0,OP_NOP};	end		// Mem[SP] = Rc
12'h026:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h027:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
// POP
12'h030:	begin next_ip = 12'h034; instr = micro_ir[39:37] > 3'd0 ? {'d0,9'h0,4'h0,SP,micro_ir[12: 7],OP_LDO} : {33'd0,OP_NOP};	end		// Rt = Mem[SP]
12'h031:	begin next_ip = 12'h034; instr = micro_ir[39:37] > 3'd1 ? {'d0,9'h1,4'h0,SP,micro_ir[18:13],OP_LDO} : {33'd0,OP_NOP};	end		// Ra = Mem[SP]
12'h032:	begin next_ip = 12'h034; instr = micro_ir[39:37] > 3'd2 ? {'d0,9'h2,4'h0,SP,micro_ir[24:19],OP_LDO} : {33'd0,OP_NOP};	end		// Rb = Mem[SP]
12'h033:	begin next_ip = 12'h034; instr = micro_ir[39:37] > 3'd3 ? {'d0,9'h3,4'h0,SP,micro_ir[30:25],OP_LDO} : {33'd0,OP_NOP};	end		// Rc = Mem[SP]
12'h034:	begin next_ip = 12'h000; instr = micro_ir[39:37] > 3'd4 ? {'d0,9'h4,4'h0,SP,micro_ir[36:31],OP_LDO} : {33'd0,OP_NOP};	end		// Rc = Mem[SP]
12'h035:	begin next_ip = 12'h000; instr = {'d0,6'h00,micro_ir[39:37],4'h0,SP,SP,OP_ADDI}; end				// SP = SP + N * 16
12'h036:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h037:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
// FDIV
12'h040:	begin next_ip = 12'h044; instr = {'d0,2'd1,FN_FLT1,3'd0,1'b0,FN_FRES,micro_ir[18:13],micro_ir[12:7],OP_FLT2}; end
12'h041:	begin next_ip = 12'h044; instr = {'d0,FN_FLT1,4'b0,FN_FNEG,micro_ir[18:13],micro_ir[18:13],OP_FLT2}; end
12'h042:	begin next_ip = 12'h044; instr = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd2,6'd58,OP_FLT2}; end
12'h043:	begin next_ip = 12'h044; instr = {'d0,FN_FMA,6'd58,micro_ir[18:13],micro_ir[12:7],6'd47,OP_FLT3}; end
12'h044:	begin next_ip = 12'h048; instr = {'d0,FN_FMA,6'd0,6'd47,micro_ir[12:7],micro_ir[12:7],OP_FLT3}; end
12'h045:	begin next_ip = 12'h048; instr = {'d0,FN_FMA,6'd58,micro_ir[18:13],micro_ir[12:7],6'd47,OP_FLT3}; end
12'h046:	begin next_ip = 12'h048; instr = {'d0,FN_FMA,6'd0,6'd47,micro_ir[12:7],micro_ir[12:7],OP_FLT3}; end
12'h047:	begin next_ip = 12'h048; instr = {'d0,FN_FMA,6'd58,micro_ir[18:13],micro_ir[12:7],6'd47,OP_FLT3}; end
12'h048:	begin next_ip = 12'h04C; instr = {'d0,FN_FMA,6'd0,6'd47,micro_ir[12:7],micro_ir[12:7],OP_FLT3}; end
12'h049:	begin next_ip = 12'h04C; instr = {'d0,FN_FMA,6'd58,micro_ir[18:13],micro_ir[12:7],6'd47,OP_FLT3}; end
12'h04A:	begin next_ip = 12'h04C; instr = {'d0,FN_FMA,6'd0,6'd47,micro_ir[12:7],micro_ir[12:7],OP_FLT3}; end
12'h04B:	begin next_ip = 12'h04C; instr = {'d0,FN_FLT1,4'b0,FN_FNEG,micro_ir[18:13],micro_ir[18:13],OP_FLT2}; end
12'h04C:	begin next_ip = 12'h000; instr = {'d0,FN_FMA,6'd0,micro_ir[18:13],micro_ir[12:7],micro_ir[12:7],OP_FLT3}; end
12'h04D:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h04E:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h04F:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end

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
12'h050:	begin next_ip = 12'h054; instr = {3'd0,12'h068,6'd0,micro_ir[18:13],3'd2,2'd0,1'b0,OP_MCB};	end		// if -tive
12'h051:	begin next_ip = 12'h054; instr = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd57,MC0,OP_FLT2}; regx = 4'h1; end	// MC0 = infinity
12'h052:	begin next_ip = 12'h054; instr = {3'd0,12'h06C,MC0,micro_ir[18:13],3'd0,2'd0,1'b0,OP_MCB}; regx = 4'h4; end			// if = infinity
12'h053:	begin next_ip = 12'h054; instr = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd0,MC0,OP_FLT2};  regx = 4'h1; end	// MC0 = 0.5
12'h054:	begin next_ip = 12'h058; instr = {'d0,FN_MUL,4'b0,MC0,micro_ir[18:13],MC1,OP_FLT2}; regx = 4'h5; end	// MC1 = x * MC0
12'h055:	begin next_ip = 12'h058; instr = {'d0,1'b0,1'b1,OP_LSR,7'd1,micro_ir[18:13],MC2,OP_SHIFT}; regx = 4'h1; end	// MC2 = i>>1
12'h056:	begin next_ip = 12'h058; instr = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd4,MC0,OP_FLT2}; regx = 4'h1; end			// MC0 = MAGIC
12'h057:	begin next_ip = 12'h058; instr = {'d0,FN_SUB,4'b00,MC2,MC0,MC2,OP_FLT2}; regx = 4'h7; end							// MC2 = MAGIC - MC2
12'h058:	begin next_ip = 12'h05C; instr = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,OP_FLT2}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h059:	begin next_ip = 12'h05C; instr = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd3,MC0,OP_FLT2}; regx = 4'h1; end			// MC0 = 1.5
12'h05A:	begin next_ip = 12'h05C; instr = {'d0,FN_FNMS,MC0,MC3,MC1,micro_ir[12:7],OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h05B:	begin next_ip = 12'h05C; instr = {'d0,FN_MUL,4'b0,MC2,micro_ir[12:7],MC2,OP_FLT2}; regx = 4'h5; end		// MC2 = MC2 * Rt
12'h05C:	begin next_ip = 12'h060; instr = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,OP_FLT2}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h05D:	begin next_ip = 12'h060; instr = {'d0,FN_FNMS,MC0,MC3,MC1,micro_ir[12:7],OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h05E:	begin next_ip = 12'h060; instr = {'d0,FN_MUL,4'b0,MC2,micro_ir[12:7],MC2,OP_FLT2}; regx = 4'h5; end		// MC2 = MC2 * Rt
12'h05F:	begin next_ip = 12'h060; instr = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,OP_FLT2}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h060:	begin next_ip = 12'h064; instr = {'d0,FN_FNMS,MC0,MC3,MC1,micro_ir[12:7],OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h061:	begin next_ip = 12'h064; instr = {'d0,FN_MUL,4'b0,MC2,micro_ir[12:7],MC2,OP_FLT2}; regx = 4'h5; end		// MC2 = MC2 * Rt
12'h062:	begin next_ip = 12'h064; instr = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,OP_FLT2}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h063:	begin next_ip = 12'h064; instr = {'d0,FN_FNMS,MC0,MC3,MC1,micro_ir[12:7],OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h064:	begin next_ip = 12'h000; instr = {'d0,FN_MUL,4'b0,MC2,micro_ir[12:7],micro_ir[12:7],OP_FLT2}; regx = 4'h4; end		// Rt = MC2 * Rt
12'h065:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h066:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h067:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h068:	begin next_ip = 12'h000; instr = {'d0,FN_FLT1,2'b0,FN_FCONST,6'd63,micro_ir[12:7],OP_FLT2}; end		// Rt = Nan (square root of negative)
12'h069:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h06A:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h06B:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h06C:	begin next_ip = 12'h000; instr = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd62,micro_ir[12:7],OP_FLT2}; end		// Rt = Nan (square root of infinity)
12'h06D:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h06E:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h06F:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end

// FRSQRTE9
// Approximately 46 clock cycles.
12'h070:	begin next_ip = 12'h074; instr = {3'd0,12'h068,6'd0,micro_ir[18:13],3'd2,2'd0,1'b0,OP_MCB};	end		// if -tive
12'h071:	begin next_ip = 12'h074; instr = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd57,MC0,OP_FLT2}; regx = 4'h1; end	// MC0 = infinity
12'h072:	begin next_ip = 12'h074; instr = {3'd0,12'h06C,MC0,micro_ir[18:13],3'd0,2'd0,1'b0,OP_MCB}; regx = 4'h4; end			// if = infinity
12'h073:	begin next_ip = 12'h074; instr = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd0,MC0,OP_FLT2}; regx = 4'h1; end	// MC0 = 0.5
12'h074:	begin next_ip = 12'h078; instr = {'d0,FN_MUL,4'b0,MC0,micro_ir[18:13],MC1,OP_FLT2}; regx = 4'h5; end	// MC1 = x * MC0
12'h075:	begin next_ip = 12'h078; instr = {'d0,1'b0,1'b1,OP_LSR,7'd1,micro_ir[18:13],MC2,OP_SHIFT}; regx = 4'h1; end	// MC2 = i>>1
12'h076:	begin next_ip = 12'h078; instr = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd4,MC0,OP_FLT2}; regx = 4'h1; end			// MC0 = MAGIC
12'h077:	begin next_ip = 12'h078; instr = {'d0,FN_SUB,4'b00,MC2,MC0,MC2,OP_FLT2}; regx = 4'h7; end							// MC2 = MAGIC - MC2
12'h078:	begin next_ip = 12'h000; instr = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,OP_FLT2}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h079:	begin next_ip = 12'h000; instr = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd3,MC0,OP_FLT2}; regx = 4'h1; end			// MC0 = 1.5
12'h07A:	begin next_ip = 12'h000; instr = {'d0,FN_FNMS,MC0,MC3,MC1,micro_ir[12:7],OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h07B:	begin next_ip = 12'h000; instr = {'d0,FN_MUL,4'b0,MC2,micro_ir[12:7],micro_ir[12:7],OP_FLT2}; regx = 4'h4; end		// MC2 = MC2 * Rt
12'h07C:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h07D:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h07E:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h07F:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end

// FRSQRTE17
// Approximately 70 clock cycles
12'h080:	begin next_ip = 12'h084; instr = {3'd0,12'h068,6'd0,micro_ir[18:13],3'd2,2'd0,1'b0,OP_MCB};	end		// if -tive
12'h081:	begin next_ip = 12'h084; instr = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd57,MC0,OP_FLT2}; regx = 4'h1; end	// MC0 = infinity
12'h082:	begin next_ip = 12'h084; instr = {3'd0,12'h06C,MC0,micro_ir[18:13],3'd0,2'd0,1'b0,OP_MCB}; regx = 4'h4; end			// if = infinity
12'h083:	begin next_ip = 12'h084; instr = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd0,MC0,OP_FLT2}; regx = 4'h1; end	// MC0 = 0.5
12'h084:	begin next_ip = 12'h088; instr = {'d0,FN_MUL,4'b0,MC0,micro_ir[18:13],MC1,OP_FLT2}; regx = 4'h5; end	// MC1 = x * MC0
12'h085:	begin next_ip = 12'h088; instr = {'d0,1'b0,1'b1,OP_LSR,7'd1,micro_ir[18:13],MC2,OP_SHIFT}; regx = 4'h1; end	// MC2 = i>>1
12'h086:	begin next_ip = 12'h088; instr = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd4,MC0,OP_FLT2}; regx = 4'h1; end			// MC0 = MAGIC
12'h087:	begin next_ip = 12'h088; instr = {'d0,FN_SUB,4'b00,MC2,MC0,MC2,OP_FLT2}; regx = 4'h7; end							// MC2 = MAGIC - MC2
12'h088:	begin next_ip = 12'h08C; instr = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,OP_FLT2}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h089:	begin next_ip = 12'h08C; instr = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd3,MC0,OP_FLT2}; regx = 4'h1; end			// MC0 = 1.5
12'h08A:	begin next_ip = 12'h08C; instr = {'d0,FN_FNMS,MC0,MC3,MC1,micro_ir[12:7],OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h08B:	begin next_ip = 12'h08C; instr = {'d0,FN_MUL,4'b0,MC2,micro_ir[12:7],MC2,OP_FLT2}; regx = 4'h5; end		// MC2 = MC2 * Rt
12'h08C:	begin next_ip = 12'h000; instr = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,OP_FLT2}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h08D:	begin next_ip = 12'h000; instr = {'d0,FN_FNMS,MC0,MC3,MC1,micro_ir[12:7],OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h08E:	begin next_ip = 12'h000; instr = {'d0,FN_MUL,4'b0,MC2,micro_ir[12:7],micro_ir[12:7],OP_FLT2}; regx = 4'h4; end		// Rt = MC2 * Rt
12'h08F:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end

// FRSQRTE34
// Approximately 94 clock cycles
12'h0A0:	begin next_ip = 12'h0A4; instr = {3'd0,12'h068,6'd0,micro_ir[18:13],3'd2,2'd0,1'b0,OP_MCB};	end		// if -tive
12'h0A1:	begin next_ip = 12'h0A4; instr = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd57,MC0,OP_FLT2}; regx = 4'h1; end	// MC0 = infinity
12'h0A2:	begin next_ip = 12'h0A4; instr = {3'd0,12'h06C,MC0,micro_ir[18:13],3'd0,2'd0,1'b0,OP_MCB}; regx = 4'h4; end			// if = infinity
12'h0A3:	begin next_ip = 12'h0A4; instr = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd0,MC0,OP_FLT2}; regx = 4'h1; end	// MC0 = 0.5
12'h0A4:	begin next_ip = 12'h0A8; instr = {'d0,FN_MUL,4'b0,MC0,micro_ir[18:13],MC1,OP_FLT2}; regx = 4'h5; end	// MC1 = x * MC0
12'h0A5:	begin next_ip = 12'h0A8; instr = {'d0,1'b0,1'b1,OP_LSR,7'd1,micro_ir[18:13],MC2,OP_SHIFT}; regx = 4'h1; end	// MC2 = i>>1
12'h0A6:	begin next_ip = 12'h0A8; instr = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd4,MC0,OP_FLT2}; regx = 4'h1; end			// MC0 = MAGIC
12'h0A7:	begin next_ip = 12'h0A8; instr = {'d0,FN_SUB,4'b00,MC2,MC0,MC2,OP_FLT2}; regx = 4'h7; end							// MC2 = MAGIC - MC2
12'h0A8:	begin next_ip = 12'h0AC; instr = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,OP_FLT2}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h0A9:	begin next_ip = 12'h0AC; instr = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd3,MC0,OP_FLT2}; regx = 4'h1; end			// MC0 = 1.5
12'h0AA:	begin next_ip = 12'h0AC; instr = {'d0,FN_FNMS,MC0,MC3,MC1,micro_ir[12:7],OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h0AB:	begin next_ip = 12'h0AC; instr = {'d0,FN_MUL,4'b0,MC2,micro_ir[12:7],MC2,OP_FLT2}; regx = 4'h5; end		// MC2 = MC2 * Rt
12'h0AC:	begin next_ip = 12'h0B0; instr = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,OP_FLT2}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h0AD:	begin next_ip = 12'h0B0; instr = {'d0,FN_FNMS,MC0,MC3,MC1,micro_ir[12:7],OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h0AE:	begin next_ip = 12'h0B0; instr = {'d0,FN_MUL,4'b0,MC2,micro_ir[12:7],MC2,OP_FLT2}; regx = 4'h5; end		// MC2 = MC2 * Rt
12'h0AF:	begin next_ip = 12'h0B0; instr = {'d0,FN_MUL,4'b0,MC2,MC2,MC3,OP_FLT2}; regx = 4'h7; end							// MC3 = MC2 * MC2
12'h0B0:	begin next_ip = 12'h000; instr = {'d0,FN_FNMS,MC0,MC3,MC1,micro_ir[12:7],OP_FLT3}; regx = 4'hE; end		// Rt = -(MC3 * MC1 - MC0)
12'h0B1:	begin next_ip = 12'h000; instr = {'d0,FN_MUL,4'b0,MC2,micro_ir[12:7],micro_ir[12:7],OP_FLT2}; regx = 4'h4; end		// Rt = MC2 * Rt
12'h0B2:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h0B3:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end

// FRES16
// 22 clocks
// x[i+1] = x[i]*(2 - x[i]*a)
12'h0C0:	begin next_ip = 12'h0C4; instr = {'d0,FN_FLT1,4'b0,FN_ISNAN,micro_ir[18:13],micro_ir[12:7],OP_FLT2}; end
12'h0C1:	begin next_ip = 12'h0C4; instr = {3'd0,12'h0C8,6'd0,micro_ir[12:7],3'd1,2'd0,1'b0,OP_MCB}; end
12'h0C2:	begin next_ip = 12'h0C4; instr = {'d0,FN_FLT1,4'b0,FN_FRES,micro_ir[18:13],micro_ir[12:7],OP_FLT2}; end
12'h0C3:	begin next_ip = 12'h0C4; instr = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd2,MC0,OP_FLT2}; regx = 4'h1; end
12'h0C4:	begin next_ip = 12'h000; instr = {'d0,FN_FNMS,MC0,micro_ir[18:13],micro_ir[12:7],MC1,OP_FLT3}; regx = 4'h9; end
12'h0C5:	begin next_ip = 12'h000; instr = {'d0,FN_FMA,6'd0,MC1,micro_ir[12:7],micro_ir[12:7],OP_FLT3}; regx = 4'h4; end
12'h0C6:	begin next_ip = 12'h000; instr = {'d0,FN_OR,1'b0,6'd0,micro_ir[18:13],micro_ir[12:7],OP_R2}; end		// Rt = Ra = NaN
12'h0C7:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h0C8:	begin next_ip = 12'h000; instr = {'d0,FN_OR,1'b0,6'd0,micro_ir[18:13],micro_ir[12:7],OP_R2}; end		// Rt = Ra = NaN
12'h0C9:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h0CA:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h0CB:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end

// FRES32
// 38 clocks
12'h0D0:	begin next_ip = 12'h0D4; instr = {'d0,FN_FLT1,4'b0,FN_ISNAN,micro_ir[18:13],micro_ir[12:7],OP_FLT2}; end
12'h0D1:	begin next_ip = 12'h0D4; instr = {3'd0,12'h0C8,6'd0,micro_ir[12:7],3'd1,2'd0,1'b0,OP_MCB}; end
12'h0D2:	begin next_ip = 12'h0D4; instr = {'d0,FN_FLT1,4'b0,FN_FRES,micro_ir[18:13],micro_ir[12:7],OP_FLT2}; end
12'h0D3:	begin next_ip = 12'h0D4; instr = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd2,MC0,OP_FLT2}; regx = 4'h1; end
12'h0D4:	begin next_ip = 12'h0E8; instr = {'d0,FN_FNMS,MC0,micro_ir[18:13],micro_ir[12:7],MC1,OP_FLT3}; regx = 4'h9; end
12'h0D5:	begin next_ip = 12'h0E8; instr = {'d0,FN_FMA,6'd0,MC1,micro_ir[12:7],micro_ir[12:7],OP_FLT3}; regx = 4'h4; end
12'h0D6:	begin next_ip = 12'h0E8; instr = {'d0,OP_NOP};	end
12'h0D7:	begin next_ip = 12'h0E8; instr = {'d0,OP_NOP};	end

// FRES64
// 54 clocks
12'h0E0:	begin next_ip = 12'h0E4; instr = {'d0,FN_FLT1,4'b0,FN_ISNAN,micro_ir[18:13],micro_ir[12:7],OP_FLT2}; end
12'h0E1:	begin next_ip = 12'h0E4; instr = {3'd0,12'h0C8,6'd0,micro_ir[12:7],3'd1,2'd0,1'b0,OP_MCB}; end
12'h0E2:	begin next_ip = 12'h0E4; instr = {'d0,FN_FLT1,4'b0,FN_FRES,micro_ir[18:13],micro_ir[12:7],OP_FLT2}; end
12'h0E3:	begin next_ip = 12'h0E4; instr = {'d0,FN_FLT1,4'b0,FN_FCONST,6'd2,MC0,OP_FLT2}; regx = 4'h1; end
12'h0E4:	begin next_ip = 12'h0E8; instr = {'d0,FN_FNMS,MC0,micro_ir[18:13],micro_ir[12:7],MC1,OP_FLT3}; regx = 4'h9; end
12'h0E5:	begin next_ip = 12'h0E8; instr = {'d0,FN_FMA,6'd0,MC1,micro_ir[12:7],micro_ir[12:7],OP_FLT3}; regx = 4'h4; end
12'h0E6:	begin next_ip = 12'h0E8; instr = {'d0,FN_FNMS,MC0,micro_ir[18:13],micro_ir[12:7],MC1,OP_FLT3}; regx = 4'h9; end
12'h0E7:	begin next_ip = 12'h0E8; instr = {'d0,FN_FMA,6'd0,MC1,micro_ir[12:7],micro_ir[12:7],OP_FLT3}; regx = 4'h4; end
12'h0E8:	begin next_ip = 12'h000; instr = {'d0,FN_FNMS,MC0,micro_ir[18:13],micro_ir[12:7],MC1,OP_FLT3}; regx = 4'h9; end
12'h0E9:	begin next_ip = 12'h000; instr = {'d0,FN_FMA,6'd0,MC1,micro_ir[12:7],micro_ir[12:7],OP_FLT3}; regx = 4'h4; end
12'h0EA:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h0EB:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end

// STCTX
12'h100:	begin next_ip = 12'h104; instr = {3'd0,2'd0,CSR_CTX,6'h00,MC0,OP_CSR}; regx = 4'h1; end	// MC0 = CTX address
12'h101:	begin next_ip = 12'h104; instr = {'d0,OP_NOP}; end
12'h102:	begin next_ip = 12'h104; instr = {'d0,13'h0010,MC0,6'h01,OP_STH}; regx = 4'h2; end
12'h103:	begin next_ip = 12'h104; instr = {'d0,13'h0020,MC0,6'h02,OP_STH}; regx = 4'h2; end
12'h104:	begin next_ip = 12'h108; instr = {'d0,13'h0030,MC0,6'h03,OP_STH}; regx = 4'h2; end
12'h105:	begin next_ip = 12'h108; instr = {'d0,13'h0040,MC0,6'h04,OP_STH}; regx = 4'h2; end
12'h106:	begin next_ip = 12'h108; instr = {'d0,13'h0050,MC0,6'h05,OP_STH}; regx = 4'h2; end
12'h107:	begin next_ip = 12'h108; instr = {'d0,13'h0060,MC0,6'h06,OP_STH}; regx = 4'h2; end
12'h108:	begin next_ip = 12'h10C; instr = {'d0,13'h0070,MC0,6'h07,OP_STH}; regx = 4'h2; end
12'h109:	begin next_ip = 12'h10C; instr = {'d0,13'h0080,MC0,6'h08,OP_STH}; regx = 4'h2; end
12'h10A:	begin next_ip = 12'h10C; instr = {'d0,13'h0090,MC0,6'h09,OP_STH}; regx = 4'h2; end
12'h10B:	begin next_ip = 12'h10C; instr = {'d0,13'h00A0,MC0,6'h0A,OP_STH}; regx = 4'h2; end
12'h10C:	begin next_ip = 12'h110; instr = {'d0,13'h00B0,MC0,6'h0B,OP_STH}; regx = 4'h2; end
12'h10D:	begin next_ip = 12'h110; instr = {'d0,13'h00C0,MC0,6'h0C,OP_STH}; regx = 4'h2; end
12'h10E:	begin next_ip = 12'h110; instr = {'d0,13'h00D0,MC0,6'h0D,OP_STH}; regx = 4'h2; end
12'h10F:	begin next_ip = 12'h110; instr = {'d0,13'h00E0,MC0,6'h0E,OP_STH}; regx = 4'h2; end
12'h110:	begin next_ip = 12'h114; instr = {'d0,13'h00F0,MC0,6'h0F,OP_STH}; regx = 4'h2; end
12'h111:	begin next_ip = 12'h114; instr = {'d0,13'h0100,MC0,6'h10,OP_STH}; regx = 4'h2; end
12'h112:	begin next_ip = 12'h114; instr = {'d0,13'h0110,MC0,6'h11,OP_STH}; regx = 4'h2; end
12'h113:	begin next_ip = 12'h114; instr = {'d0,13'h0120,MC0,6'h12,OP_STH}; regx = 4'h2; end
12'h114:	begin next_ip = 12'h118; instr = {'d0,13'h0130,MC0,6'h13,OP_STH}; regx = 4'h2; end
12'h115:	begin next_ip = 12'h118; instr = {'d0,13'h0140,MC0,6'h14,OP_STH}; regx = 4'h2; end
12'h116:	begin next_ip = 12'h118; instr = {'d0,13'h0150,MC0,6'h15,OP_STH}; regx = 4'h2; end
12'h117:	begin next_ip = 12'h118; instr = {'d0,13'h0160,MC0,6'h16,OP_STH}; regx = 4'h2; end
12'h118:	begin next_ip = 12'h11C; instr = {'d0,13'h0170,MC0,6'h17,OP_STH}; regx = 4'h2; end
12'h119:	begin next_ip = 12'h11C; instr = {'d0,13'h0180,MC0,6'h18,OP_STH}; regx = 4'h2; end
12'h11A:	begin next_ip = 12'h11C; instr = {'d0,13'h0190,MC0,6'h19,OP_STH}; regx = 4'h2; end
12'h11B:	begin next_ip = 12'h11C; instr = {'d0,13'h01A0,MC0,6'h1A,OP_STH}; regx = 4'h2; end
12'h11C:	begin next_ip = 12'h120; instr = {'d0,13'h01B0,MC0,6'h1B,OP_STH}; regx = 4'h2; end
12'h11D:	begin next_ip = 12'h120; instr = {'d0,13'h01C0,MC0,6'h1C,OP_STH}; regx = 4'h2; end
12'h11E:	begin next_ip = 12'h120; instr = {'d0,13'h01D0,MC0,6'h1D,OP_STH}; regx = 4'h2; end
12'h11F:	begin next_ip = 12'h120; instr = {'d0,13'h01E0,MC0,6'h1E,OP_STH}; regx = 4'h2; end
12'h120:	begin next_ip = 12'h124; instr = {'d0,13'h01F0,MC0,6'h1F,OP_STH}; regx = 4'h2; end
12'h121:	begin next_ip = 12'h124; instr = {'d0,13'h0200,MC0,6'h20,OP_STH}; regx = 4'h2; end
12'h122:	begin next_ip = 12'h124; instr = {'d0,13'h0210,MC0,6'h21,OP_STH}; regx = 4'h2; end
12'h123:	begin next_ip = 12'h124; instr = {'d0,13'h0220,MC0,6'h22,OP_STH}; regx = 4'h2; end
12'h124:	begin next_ip = 12'h128; instr = {'d0,13'h0230,MC0,6'h23,OP_STH}; regx = 4'h2; end
12'h125:	begin next_ip = 12'h128; instr = {'d0,13'h0240,MC0,6'h24,OP_STH}; regx = 4'h2; end
12'h126:	begin next_ip = 12'h128; instr = {'d0,13'h0250,MC0,6'h25,OP_STH}; regx = 4'h2; end
12'h127:	begin next_ip = 12'h128; instr = {'d0,13'h0260,MC0,6'h26,OP_STH}; regx = 4'h2; end
12'h128:	begin next_ip = 12'h12C; instr = {'d0,13'h0270,MC0,6'h27,OP_STH}; regx = 4'h2; end
12'h129:	begin next_ip = 12'h12C; instr = {'d0,13'h0280,MC0,6'h28,OP_STH}; regx = 4'h2; end
12'h12A:	begin next_ip = 12'h12C; instr = {'d0,13'h0290,MC0,6'h29,OP_STH}; regx = 4'h2; end
12'h12B:	begin next_ip = 12'h12C; instr = {'d0,13'h02A0,MC0,6'h2A,OP_STH}; regx = 4'h2; end
12'h12C:	begin next_ip = 12'h130; instr = {'d0,13'h02B0,MC0,6'h2B,OP_STH}; regx = 4'h2; end
12'h12D:	begin next_ip = 12'h130; instr = {'d0,13'h02C0,MC0,6'h2C,OP_STH}; regx = 4'h2; end
12'h12E:	begin next_ip = 12'h130; instr = {'d0,13'h02D0,MC0,6'h2D,OP_STH}; regx = 4'h2; end
12'h12F:	begin next_ip = 12'h130; instr = {'d0,13'h02E0,MC0,6'h2E,OP_STH}; regx = 4'h2; end
12'h130:	begin next_ip = 12'h134; instr = {'d0,13'h02F0,MC0,6'h2F,OP_STH}; regx = 4'h2; end
12'h131:	begin next_ip = 12'h134; instr = {'d0,13'h0300,MC0,6'h30,OP_STH}; regx = 4'h2; end
12'h132:	begin next_ip = 12'h134; instr = {'d0,13'h0310,MC0,6'h31,OP_STH}; regx = 4'h2; end
12'h133:	begin next_ip = 12'h134; instr = {'d0,13'h0320,MC0,6'h32,OP_STH}; regx = 4'h2; end
12'h134:	begin next_ip = 12'h138; instr = {'d0,13'h0330,MC0,6'h33,OP_STH}; regx = 4'h2; end
12'h135:	begin next_ip = 12'h138; instr = {'d0,13'h0340,MC0,6'h34,OP_STH}; regx = 4'h2; end
12'h136:	begin next_ip = 12'h138; instr = {'d0,13'h0350,MC0,6'h35,OP_STH}; regx = 4'h2; end
12'h137:	begin next_ip = 12'h138; instr = {'d0,13'h0360,MC0,6'h36,OP_STH}; regx = 4'h2; end
12'h138:	begin next_ip = 12'h13C; instr = {'d0,13'h0370,MC0,6'h37,OP_STH}; regx = 4'h2; end
12'h139:	begin next_ip = 12'h13C; instr = {'d0,13'h0380,MC0,6'h38,OP_STH}; regx = 4'h2; end
12'h13A:	begin next_ip = 12'h13C; instr = {'d0,13'h0390,MC0,6'h39,OP_STH}; regx = 4'h2; end
12'h13B:	begin next_ip = 12'h13C; instr = {'d0,13'h03A0,MC0,6'h3A,OP_STH}; regx = 4'h2; end
12'h13C:	begin next_ip = 12'h140; instr = {'d0,13'h03B0,MC0,6'h3B,OP_STH}; regx = 4'h2; end
12'h13D:	begin next_ip = 12'h140; instr = {'d0,13'h03C0,MC0,6'h3C,OP_STH}; regx = 4'h2; end
12'h13E:	begin next_ip = 12'h140; instr = {'d0,13'h03D0,MC0,6'h3D,OP_STH}; regx = 4'h2; end
12'h13F:	begin next_ip = 12'h140; instr = {'d0,13'h03E0,MC0,6'h3E,OP_STH}; regx = 4'h2; end
12'h140:	begin next_ip = 12'h000; instr = {'d0,13'h03F0,MC0,6'h3F,OP_STH}; regx = 4'h2; end
12'h141:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h142:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h143:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end

// LDCTX
12'h150:	begin next_ip = 12'h154; instr = {3'd0,2'd0,CSR_CTX,6'h00,MC0,OP_CSR}; regx = 4'h1; end	// MC0 = CTX address
12'h151:	begin next_ip = 12'h154; instr = {'d0,OP_NOP}; end
12'h152:	begin next_ip = 12'h154; instr = {'d0,13'h0010,MC0,6'h01,OP_LDH}; regx = 4'h2; end
12'h153:	begin next_ip = 12'h154; instr = {'d0,13'h0020,MC0,6'h02,OP_LDH}; regx = 4'h2; end
12'h154:	begin next_ip = 12'h158; instr = {'d0,13'h0030,MC0,6'h03,OP_LDH}; regx = 4'h2; end
12'h155:	begin next_ip = 12'h158; instr = {'d0,13'h0040,MC0,6'h04,OP_LDH}; regx = 4'h2; end
12'h156:	begin next_ip = 12'h158; instr = {'d0,13'h0050,MC0,6'h05,OP_LDH}; regx = 4'h2; end
12'h157:	begin next_ip = 12'h158; instr = {'d0,13'h0060,MC0,6'h06,OP_LDH}; regx = 4'h2; end
12'h158:	begin next_ip = 12'h15C; instr = {'d0,13'h0070,MC0,6'h07,OP_LDH}; regx = 4'h2; end
12'h159:	begin next_ip = 12'h15C; instr = {'d0,13'h0080,MC0,6'h08,OP_LDH}; regx = 4'h2; end
12'h15A:	begin next_ip = 12'h15C; instr = {'d0,13'h0090,MC0,6'h09,OP_LDH}; regx = 4'h2; end
12'h15B:	begin next_ip = 12'h15C; instr = {'d0,13'h00A0,MC0,6'h0A,OP_LDH}; regx = 4'h2; end
12'h15C:	begin next_ip = 12'h160; instr = {'d0,13'h00B0,MC0,6'h0B,OP_LDH}; regx = 4'h2; end
12'h15D:	begin next_ip = 12'h160; instr = {'d0,13'h00C0,MC0,6'h0C,OP_LDH}; regx = 4'h2; end
12'h15E:	begin next_ip = 12'h160; instr = {'d0,13'h00D0,MC0,6'h0D,OP_LDH}; regx = 4'h2; end
12'h15F:	begin next_ip = 12'h160; instr = {'d0,13'h00E0,MC0,6'h0E,OP_LDH}; regx = 4'h2; end
12'h160:	begin next_ip = 12'h164; instr = {'d0,13'h00F0,MC0,6'h0F,OP_LDH}; regx = 4'h2; end
12'h161:	begin next_ip = 12'h164; instr = {'d0,13'h0100,MC0,6'h10,OP_LDH}; regx = 4'h2; end
12'h162:	begin next_ip = 12'h164; instr = {'d0,13'h0110,MC0,6'h11,OP_LDH}; regx = 4'h2; end
12'h163:	begin next_ip = 12'h164; instr = {'d0,13'h0120,MC0,6'h12,OP_LDH}; regx = 4'h2; end
12'h164:	begin next_ip = 12'h168; instr = {'d0,13'h0130,MC0,6'h13,OP_LDH}; regx = 4'h2; end
12'h165:	begin next_ip = 12'h168; instr = {'d0,13'h0140,MC0,6'h14,OP_LDH}; regx = 4'h2; end
12'h166:	begin next_ip = 12'h168; instr = {'d0,13'h0150,MC0,6'h15,OP_LDH}; regx = 4'h2; end
12'h167:	begin next_ip = 12'h168; instr = {'d0,13'h0160,MC0,6'h16,OP_LDH}; regx = 4'h2; end
12'h168:	begin next_ip = 12'h16C; instr = {'d0,13'h0170,MC0,6'h17,OP_LDH}; regx = 4'h2; end
12'h169:	begin next_ip = 12'h16C; instr = {'d0,13'h0180,MC0,6'h18,OP_LDH}; regx = 4'h2; end
12'h16A:	begin next_ip = 12'h16C; instr = {'d0,13'h0190,MC0,6'h19,OP_LDH}; regx = 4'h2; end
12'h16B:	begin next_ip = 12'h16C; instr = {'d0,13'h01A0,MC0,6'h1A,OP_LDH}; regx = 4'h2; end
12'h16C:	begin next_ip = 12'h170; instr = {'d0,13'h01B0,MC0,6'h1B,OP_LDH}; regx = 4'h2; end
12'h16D:	begin next_ip = 12'h170; instr = {'d0,13'h01C0,MC0,6'h1C,OP_LDH}; regx = 4'h2; end
12'h16E:	begin next_ip = 12'h170; instr = {'d0,13'h01D0,MC0,6'h1D,OP_LDH}; regx = 4'h2; end
12'h16F:	begin next_ip = 12'h170; instr = {'d0,13'h01E0,MC0,6'h1E,OP_LDH}; regx = 4'h2; end
12'h170:	begin next_ip = 12'h174; instr = {'d0,13'h01F0,MC0,6'h1F,OP_LDH}; regx = 4'h2; end
12'h171:	begin next_ip = 12'h174; instr = {'d0,13'h0200,MC0,6'h20,OP_LDH}; regx = 4'h2; end
12'h172:	begin next_ip = 12'h174; instr = {'d0,13'h0210,MC0,6'h21,OP_LDH}; regx = 4'h2; end
12'h173:	begin next_ip = 12'h174; instr = {'d0,13'h0220,MC0,6'h22,OP_LDH}; regx = 4'h2; end
12'h174:	begin next_ip = 12'h178; instr = {'d0,13'h0230,MC0,6'h23,OP_LDH}; regx = 4'h2; end
12'h175:	begin next_ip = 12'h178; instr = {'d0,13'h0240,MC0,6'h24,OP_LDH}; regx = 4'h2; end
12'h176:	begin next_ip = 12'h178; instr = {'d0,13'h0250,MC0,6'h25,OP_LDH}; regx = 4'h2; end
12'h177:	begin next_ip = 12'h178; instr = {'d0,13'h0260,MC0,6'h26,OP_LDH}; regx = 4'h2; end
12'h178:	begin next_ip = 12'h17C; instr = {'d0,13'h0270,MC0,6'h27,OP_LDH}; regx = 4'h2; end
12'h179:	begin next_ip = 12'h17C; instr = {'d0,13'h0280,MC0,6'h28,OP_LDH}; regx = 4'h2; end
12'h17A:	begin next_ip = 12'h17C; instr = {'d0,13'h0290,MC0,6'h29,OP_LDH}; regx = 4'h2; end
12'h17B:	begin next_ip = 12'h17C; instr = {'d0,13'h02A0,MC0,6'h2A,OP_LDH}; regx = 4'h2; end
12'h17C:	begin next_ip = 12'h180; instr = {'d0,13'h02B0,MC0,6'h2B,OP_LDH}; regx = 4'h2; end
12'h17D:	begin next_ip = 12'h180; instr = {'d0,13'h02C0,MC0,6'h2C,OP_LDH}; regx = 4'h2; end
12'h17E:	begin next_ip = 12'h180; instr = {'d0,13'h02D0,MC0,6'h2D,OP_LDH}; regx = 4'h2; end
12'h17F:	begin next_ip = 12'h180; instr = {'d0,13'h02E0,MC0,6'h2E,OP_LDH}; regx = 4'h2; end
12'h180:	begin next_ip = 12'h184; instr = {'d0,13'h02F0,MC0,6'h2F,OP_LDH}; regx = 4'h2; end
12'h181:	begin next_ip = 12'h184; instr = {'d0,13'h0300,MC0,6'h30,OP_LDH}; regx = 4'h2; end
12'h182:	begin next_ip = 12'h184; instr = {'d0,13'h0310,MC0,6'h31,OP_LDH}; regx = 4'h2; end
12'h183:	begin next_ip = 12'h184; instr = {'d0,13'h0320,MC0,6'h32,OP_LDH}; regx = 4'h2; end
12'h184:	begin next_ip = 12'h188; instr = {'d0,13'h0330,MC0,6'h33,OP_LDH}; regx = 4'h2; end
12'h185:	begin next_ip = 12'h188; instr = {'d0,13'h0340,MC0,6'h34,OP_LDH}; regx = 4'h2; end
12'h186:	begin next_ip = 12'h188; instr = {'d0,13'h0350,MC0,6'h35,OP_LDH}; regx = 4'h2; end
12'h187:	begin next_ip = 12'h188; instr = {'d0,13'h0360,MC0,6'h36,OP_LDH}; regx = 4'h2; end
12'h188:	begin next_ip = 12'h18C; instr = {'d0,13'h0370,MC0,6'h37,OP_LDH}; regx = 4'h2; end
12'h189:	begin next_ip = 12'h18C; instr = {'d0,13'h0380,MC0,6'h38,OP_LDH}; regx = 4'h2; end
12'h18A:	begin next_ip = 12'h18C; instr = {'d0,13'h0390,MC0,6'h39,OP_LDH}; regx = 4'h2; end
12'h18B:	begin next_ip = 12'h18C; instr = {'d0,13'h03A0,MC0,6'h3A,OP_LDH}; regx = 4'h2; end
12'h18C:	begin next_ip = 12'h190; instr = {'d0,13'h03B0,MC0,6'h3B,OP_LDH}; regx = 4'h2; end
12'h18D:	begin next_ip = 12'h190; instr = {'d0,13'h03C0,MC0,6'h3C,OP_LDH}; regx = 4'h2; end
12'h18E:	begin next_ip = 12'h190; instr = {'d0,13'h03D0,MC0,6'h3D,OP_LDH}; regx = 4'h2; end
12'h18F:	begin next_ip = 12'h190; instr = {'d0,13'h03E0,MC0,6'h3E,OP_LDH}; regx = 4'h2; end
12'h190:	begin next_ip = 12'h000; instr = {'d0,13'h03F0,MC0,6'h3F,OP_LDH}; regx = 4'h2; end
12'h191:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h192:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h193:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end

// RESET...
// This to prime the renamer.
12'h1A0:	begin next_ip = 12'h1A4; instr = {'d0,21'h123456,6'd0,MC0,OP_ADDI}; regx = 4'h1; end
12'h1A1:	begin next_ip = 12'h1A4; instr = {'d0,21'h123456,6'd0,MC0,OP_ADDI}; regx = 4'h1; end
12'h1A2:	begin next_ip = 12'h1A4; instr = {'d0,21'h123456,6'd0,MC0,OP_ADDI}; regx = 4'h1; end
12'h1A3:	begin next_ip = 12'h1A4; instr = {'d0,21'h123456,6'd0,MC0,OP_ADDI}; regx = 4'h1; end
12'h1A4:	begin next_ip = 12'h1A8; instr = {'d0,21'h123456,6'd0,MC0,OP_ADDI}; regx = 4'h1; end
12'h1A5:	begin next_ip = 12'h1A8; instr = {'d0,21'h123456,6'd0,MC0,OP_ADDI}; regx = 4'h1; end
12'h1A6:	begin next_ip = 12'h1A8; instr = {'d0,21'h123456,6'd0,MC0,OP_ADDI}; regx = 4'h1; end
12'h1A7:	begin next_ip = 12'h1A8; instr = {'d0,21'h123456,6'd0,MC0,OP_ADDI}; regx = 4'h1; end
12'h1A8:	begin next_ip = 12'h1AC; instr = {'d0,21'h123456,6'd0,MC0,OP_ADDI}; regx = 4'h1; end
12'h1A9:	begin next_ip = 12'h1AC; instr = {'d0,21'h123456,6'd0,MC0,OP_ADDI}; regx = 4'h1; end
12'h1AA:	begin next_ip = 12'h1AC; instr = {'d0,21'h123456,6'd0,MC0,OP_ADDI}; regx = 4'h1; end
12'h1AB:	begin next_ip = 12'h1AC; instr = {'d0,21'h123456,6'd0,MC0,OP_ADDI}; regx = 4'h1; end
12'h1AC:	begin next_ip = 12'h1B0; instr = {'d0,21'h123456,6'd0,MC0,OP_ADDI}; regx = 4'h1; end
12'h1AE:	begin next_ip = 12'h1B0; instr = {'d0,21'h123456,6'd0,MC0,OP_ADDI}; regx = 4'h1; end
12'h1AE:	begin next_ip = 12'h1B0; instr = {'d0,21'h123456,6'd0,MC0,OP_ADDI}; regx = 4'h1; end
12'h1AF:	begin next_ip = 12'h1B0; instr = {'d0,21'h123456,6'd0,MC0,OP_ADDI}; regx = 4'h1; end

12'h1B0:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end
12'h1B1:	begin next_ip = 12'h000; instr = {'d0,21'h1FFFE0,6'd0,SP,OP_LDO};	end			// SP = Mem[FFFFFFE0]
12'h1B2:	begin next_ip = 12'h000; instr = {'d0,21'h1FFFF0,6'd0,MC0,OP_LDO}; regx = 4'h1; end			// PC = Mem[FFFFFFF0]
12'h1B3:	begin next_ip = 12'h000; instr = {'d0,21'h000000,MC0,6'd0,OP_JSR}; regx = 4'h2; end
12'h1B4:	begin next_ip = 12'h000; instr = {'d0,OP_NOP};	end

default:	begin next_ip = 12'h000; instr = 40'hFFFFFFFFFF; end	// NOP      regx = 4'h2; 
endcase
end

endmodule
