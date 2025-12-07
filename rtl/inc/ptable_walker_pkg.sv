`timescale 1ns / 10ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2024-2025  Robert Finch, Waterloo
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

package ptable_walker_pkg;

parameter MISSQ_SIZE = 8;

typedef enum logic [1:0] {
	IDLE = 2'd0,
	FAULT = 2'd1,
	WAIT = 2'd2
} ptw_state_t;

typedef enum logic [3:0] {
	INACTIVE = 4'd0,
	SEG_BASE_FETCH = 4'd1,
	SEG_LIMIT_FETCH = 4'd2,
	SEG_FETCH_DONE = 4'd3,
	TLB_PTE_FETCH = 4'd4,
	TLB_PTE_FETCH_DONE = 4'd5,
	TLB_PTE_CYC = 4'd6,
	TLB_PTE_ACK = 4'd7,
	TLB_PTE_NACK = 4'd8,
	VIRT_ADR_XLAT = 4'd9
} ptw_access_state_t;

typedef struct packed {
	logic v;					// valid
	logic [2:0] lvl;	// level begin processed
	logic o;					// out
	logic [1:0] bc;		// 1=bus cycle complete
	logic [1:0] qn;
	cpu_types_pkg::rob_ndx_t id;
	cpu_types_pkg::asid_t asid;
	cpu_types_pkg::virtual_address_t oadr;	// original address to translate
	cpu_types_pkg::virtual_address_t adr;		// linear address to translate
	cpu_types_pkg::virtual_address_t tadr;	// temporary address
} ptw_miss_queue_t;

typedef struct packed {
	logic v;
	ptw_access_state_t access_state;
	logic rdy;
	fta_bus_pkg::fta_tranid_t tid;
	logic [4:0] mqndx;											// index of associated miss queue
	cpu_types_pkg::asid_t asid;
	cpu_types_pkg::virtual_address_t vadr;
	cpu_types_pkg::physical_address_t padr;
	mmu_pkg::pte_t pte;
	logic [255:0] dat;
} ptw_tran_buf_t;

endpackage
