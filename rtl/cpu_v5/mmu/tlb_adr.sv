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

import const_pkg::*;
import wishbone_pkg::*;
import mmu_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

// These bits are passed through verbatium
`define VADR_PBITS_LVL1 12:0
`define VADR_PBITS_LVL2 22:0

module tlb_adr(rst, clk, paging_en, stall, L1tlb, ndx, agen_v, L1hit,
	asid, miss_asid, 
	vadr, padr, padrv, tlb_v, op_i, op_o, load_i, load_o, store_i, store_o,
	omd_i, omd_o, agen_rndx_i, agen_rndx_o, miss_adr, miss_v);
input rst;
input clk;
input paging_en;
input stall;
input tlb_entry_t [7:0] L1tlb;
input [2:0] ndx;
input agen_v;
input L1hit;
input asid_t asid;
output asid_t miss_asid;
input virtual_address_t vadr;
output physical_address_t padr;
output reg padrv;
output reg tlb_v;
input Qupls4_pkg::micro_op_t op_i;
output Qupls4_pkg::micro_op_t op_o;
output virtual_address_t miss_adr;
output reg miss_v;

always_ff @(posedge clk)
if (rst) begin
	padr <= {$bits(physical_address_t){1'd0}};
	padr_v <= 1'b0;
	miss_asid <= 16'h0;
	miss_adr <= {$bits(virtual_address_t){1'd0}};
	miss_v <= INV;
	tlb_v <= VAL;
end
else begin

	if (paging_en) begin
		padr_v <= L1hit;
		tlb_v <= INV;
		op_o.opcode <= Qupls4_pkg::OP_NOP;
		load_o <= FALSE;
		store_o <= FALSE;
		omd_o <= Qupls4_pkg::OM_SECURE;
		agen_rndx_o <= 6'd63;
		if (L1tlb[ndx].pte.l2.lvl==3'd2)
			padr <= {L1tlb[ndx].pte.l2.ppn,vadr[`VADR_PBITS_LVL2]};
		else
			padr <= {L1tlb[ndx].pte.l1.ppn,vadr[`VADR_PBITS_LVL1]};
		padr_v <= L1hit & agen_v;
		miss_v <= VAL;
		miss_asid <= 16'h0;
		miss_adr <= vadr;
		if (L1hit & agen_v) begin
			tlb_v <= VAL;
			op_o <= op_i;
			load_o <= load_i;
			store_o <= store_i;
			omd_o <= omd_i;
			agen_rndx_o <= agen_rndx_i;
			miss_v <= INV;
			miss_asid <= asid;
			miss_adr <= vadr;
		end
	end
	else begin
		padr <= vadr;
		padr_v <= agen_v;
		tlb_v <= VAL;
		op_o <= op_i;
		load_o <= load_i;
		store_o <= store_i;
		omd_o <= omd_i;
		agen_rndx_o <= agen_rndx_i;
		miss_v <= INV;
		miss_asid <= asid;
		miss_adr <= vadr;
	end

end

endmodule
