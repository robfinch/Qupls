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

package Qupls4_copro_pkg;

typedef enum logic [4:0]
{
	OP_NOP = 5'd0,
	OP_WAIT,
	OP_SKIP,
	OP_LOAD_CONFIG,
	OP_JCC,
	OP_ADD64,
	OP_STOREI64,
	OP_JMP = 9,
	OP_CALC_INDEX = 12,
	OP_CALC_ADR,
	OP_BUILD_ENTRY_NO,
	OP_BUILD_VPN,
	OP_LOAD = 16,
	OP_STORE,
	OP_STOREI,
	OP_MOVE,
	OP_SHL = 20,
	OP_SHR,
	OP_ADD,
	OP_AND64,
	OP_AND,
	OP_OR,
	OP_XOR
} copro_opcode_t;

typedef enum logic [3:0] {
	JEQ = 0,
	JNE,
	JLT,
	JLE,
	JGE,
	JGT,
	DJNE,
	JLEP = 8,
	JGEP,
	GQE,
	GQNE
} copro_jcc_t;

typedef struct packed 
{
	logic [14:0] imm;
	logic [3:0] Rs2;
	logic [3:0] Rs1;
	logic [3:0] Rd;
	copro_opcode_t opcode;
} copro_instruction_t;

typedef enum logic [4:0]
{
	st_reset,
	st_reset2,
	st_prefetch,
	st_ifetch,
	st_execute,
	st_writeback,
	st_jmp,
	st_jmp2,
	st_ip_load,
	st_mem_load,
	st_mem_store,
	st_wakeup,
	st_wakeup2,
	st_even64,
	st_even64a,
	st_odd64,
	st_odd64a
} copro_state_t;

endpackage
