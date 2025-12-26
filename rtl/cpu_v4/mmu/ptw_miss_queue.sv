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
// 1400 LUTs / 750 FFs
// ============================================================================

import const_pkg::*;
import wishbone_pkg::*;
import mmu_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;
import ptable_walker_pkg::*;

module ptw_miss_queue(rst, clk, state, ptbr, ptattr,
	commit0_id, commit0_idv, commit1_id, commit1_idv, commit2_id, commit2_idv,
	commit3_id, commit3_idv,
	tlb_miss, tlb_missadr, tlb_miss_oadr, tlb_missasid, tlb_missid, tlb_missqn,
	in_que, ptw_vv, ptw_pv, ptw_ppv, tranbuf, miss_queue, sel_tran, transfer_ready,
	sel_qe, walk_level);

input rst;
input clk;
input ptable_walker_pkg::ptw_state_t state;
input ptbr_t ptbr;
input ptattr_t ptattr;
input rob_ndx_t commit0_id;
input commit0_idv;
input rob_ndx_t commit1_id;
input commit1_idv;
input rob_ndx_t commit2_id;
input commit2_idv;
input rob_ndx_t commit3_id;
input commit3_idv;
input tlb_miss;
input address_t tlb_missadr;
input address_t tlb_miss_oadr;
input asid_t tlb_missasid;
input rob_ndx_t tlb_missid;
input [1:0] tlb_missqn;
output reg in_que;
input ptw_vv;
input ptw_pv;
input ptw_ppv;
input ptw_tran_buf_t [15:0] tranbuf;
output ptw_miss_queue_t [MISSQ_SIZE-1:0] miss_queue;
input [5:0] sel_tran;
input transfer_ready;
output reg [5:0] sel_qe;
input walk_level;

integer nn,n1,n2,n3,n4,n5;
reg [2:0] lvla;
reg [19:0] pindex;
reg in_que1;
reg [5:0] shft_amt;
integer empty_qe;
integer dump_qe;

// Find out if the tlb miss is already in the miss queue.
always_comb
begin
	in_que1 = 1'b0;
	for (n1 = 0; n1 < MISSQ_SIZE; n1 = n1 + 1) begin
		if (miss_queue[n1].v) begin
			if (tlb_missasid==miss_queue[n1].asid && tlb_missadr==miss_queue[n1].adr)
				in_que1 = 1'b1;
		end
	end
end

// Find an empty queue entry.
always_comb
begin
	empty_qe = -1;
	if (tlb_miss && !in_que1) begin
		for (n2 = 0; n2 < MISSQ_SIZE; n2 = n2 + 1)
			if (~miss_queue[n2].v && empty_qe < 0)
				empty_qe = n2;
	end
end

// Select a miss queue entry to process.
always_comb
begin
	sel_qe = 6'h3f;
	for (n3 = 0; n3 < MISSQ_SIZE; n3 = n3 + 1)
		if (miss_queue[n3].v && miss_queue[n3].bc < 2'd2 && sel_qe[5] &&
			(miss_queue[n3].id==commit0_id && commit0_idv) ||
			(miss_queue[n3].id==commit1_id && commit1_idv) ||
			(miss_queue[n3].id==commit2_id && commit2_idv) ||
			(miss_queue[n3].id==commit3_id && commit3_idv)
		)	
			sel_qe = n3;
end

// Select a miss queue entry to remove.
always_comb
begin
	dump_qe = -1;
	for (n5 = 0; n5 < MISSQ_SIZE; n5 = n5 + 1)
		if (miss_queue[n5].v && miss_queue[n5].bc==2'd2 && dump_qe < 0)
			dump_qe = n5;
		else if (miss_queue[n3].v && miss_queue[n3].bc < 2'd2 && sel_qe[5] &&
			(miss_queue[n5].id==commit0_id && ~commit0_idv) ||
			(miss_queue[n5].id==commit1_id && ~commit1_idv) ||
			(miss_queue[n5].id==commit2_id && ~commit2_idv) ||
			(miss_queue[n5].id==commit3_id && ~commit3_idv)
		)	
			dump_qe = n5;
end

// Computer page index for a given page level.

always_comb
if (transfer_ready)
	lvla = miss_queue[tranbuf[sel_tran].mqndx].lvl+3'd1;
else
	lvla = 3'd0;

always_comb
if (transfer_ready) begin
	case(ptattr.pgsz)
`ifdef MMU_SUPPORT_4k_PAGES				
	4'd6:	// 4k
		case(ptattr.pte_size)
		_4B_PTE:	pindex = miss_queue[tranbuf[sel_tran].mqndx].adr[31:12] >> (lvla * 6'd10);
		_8B_PTE:	pindex = miss_queue[tranbuf[sel_tran].mqndx].adr[31:12] >> (lvla * 6'd9);
		_16B_PTE:	pindex = miss_queue[tranbuf[sel_tran].mqndx].adr[31:12] >> (lvla * 6'd8);
		default:	pindex = miss_queue[tranbuf[sel_tran].mqndx].adr[31:12] >> (lvla * 6'd9);
		endcase
`endif				
`ifdef MMU_SUPPORT_8k_PAGES				
	4'd7:	// 8k
		case(ptattr.pte_size)
		_4B_PTE:	pindex = miss_queue[tranbuf[sel_tran].mqndx].adr[31:13] >> (lvla * 6'd11);
		_8B_PTE:	pindex = miss_queue[tranbuf[sel_tran].mqndx].adr[31:13] >> (lvla * 6'd10);
		_16B_PTE:	pindex = miss_queue[tranbuf[sel_tran].mqndx].adr[31:13] >> (lvla * 6'd9);
		default:	pindex = miss_queue[tranbuf[sel_tran].mqndx].adr[31:13] >> (lvla * 6'd10);
		endcase
`endif
`ifdef MMU_SUPPORT_16k_PAGES				
	4'd8:	// 16k
		case(ptattr.pte_size)
		_4B_PTE:	pindex = miss_queue[tranbuf[sel_tran].mqndx].adr[31:14] >> (lvla * 6'd12);
		_8B_PTE:	pindex = miss_queue[tranbuf[sel_tran].mqndx].adr[31:14] >> (lvla * 6'd11);
		_16B_PTE:	pindex = miss_queue[tranbuf[sel_tran].mqndx].adr[31:14] >> (lvla * 6'd10);
		default:	pindex = miss_queue[tranbuf[sel_tran].mqndx].adr[31:14] >> (lvla * 6'd11);
		endcase
`endif				
`ifdef MMU_SUPPORT_64k_PAGES
	4'd10:	// 64k
		case(ptattr.pte_size)
		_4B_PTE:	pindex = miss_queue[tranbuf[sel_tran].mqndx].adr[31:16] >> (lvla * 6'd14);
		_8B_PTE:	pindex = miss_queue[tranbuf[sel_tran].mqndx].adr[31:16] >> (lvla * 6'd13);
		_16B_PTE:	pindex = miss_queue[tranbuf[sel_tran].mqndx].adr[31:16] >> (lvla * 6'd12);
		default:    pindex = miss_queue[tranbuf[sel_tran].mqndx].adr[31:16] >> (lvla * 6'd13);
		endcase
`endif
    default:		pindex = miss_queue[tranbuf[sel_tran].mqndx].adr[31:13] >> (lvla * 6'd10);
	endcase
end
else
	pindex = 20'd0;


always_ff @(posedge clk)
if (rst) begin
	for (nn = 0; nn < MISSQ_SIZE; nn = nn + 1)
		miss_queue[nn] <= {$bits(ptw_miss_queue_t){1'd0}};
	in_que <= FALSE;
end
else begin

	in_que <= FALSE;
	if (in_que1 && !in_que && tlb_miss)
		in_que <= 1'b1;

	// Capture miss
	if (empty_qe >= 0) begin
		if (!in_que1) begin
			$display("PTW: miss queue loaded, adr=%h", tlb_missadr);
			miss_queue[empty_qe].v <= 1'b1;
			miss_queue[empty_qe].o <= 1'b0;
			miss_queue[empty_qe].bc <= 2'b0;
			miss_queue[empty_qe].lvl <= ptbr.level;
			miss_queue[empty_qe].asid <= tlb_missasid;
			miss_queue[empty_qe].id <= tlb_missid;
			miss_queue[empty_qe].adr <= tlb_miss_oadr;
			miss_queue[empty_qe].adr <= tlb_missadr;
			miss_queue[empty_qe].qn <= tlb_missqn;

			case(ptattr.pgsz)
`ifdef MMU_SUPPORT_4k_PAGES				
			4'd6:	// 4k
				case(ptattr.pte_size)
				_4B_PTE:
					case(ptbr.level)
					3'd0:	miss_queue[empty_qe].tadr <= {ptbr[31:12],12'd0} + {tlb_missadr[21:12],2'h0};
					3'd1:	miss_queue[empty_qe].tadr <= {ptbr[31:12],12'd0} + {tlb_missadr[31:22],2'h0};
					default:	miss_queue[empty_qe].tadr <= 'd0;
					endcase
				_8B_PTE:
					case(ptbr.level)
					3'd0:	miss_queue[empty_qe].tadr <= {ptbr[31:12],12'd0} + {tlb_missadr[20:12],3'h0};
					3'd1:	miss_queue[empty_qe].tadr <= {ptbr[31:12],12'd0} + {tlb_missadr[29:21],3'h0};
					3'd2:	miss_queue[empty_qe].tadr <= {ptbr[31:12],12'd0} + {tlb_missadr[31:30],3'h0};
					default:	miss_queue[empty_qe].tadr <= 'd0;
					endcase
				_16B_PTE:
					case(ptbr.level)
					3'd0:	miss_queue[empty_qe].tadr <= {ptbr[31:12],12'd0} + {tlb_missadr[19:12],4'h0};
					3'd1:	miss_queue[empty_qe].tadr <= {ptbr[31:12],12'd0} + {tlb_missadr[27:20],4'h0};
					3'd2:	miss_queue[empty_qe].tadr <= {ptbr[31:12],12'd0} + {tlb_missadr[31:28],4'h0};
					default:	miss_queue[empty_qe].tadr <= 'd0;
					endcase
				default:	;
				endcase
`endif				
`ifdef MMU_SUPPORT_8k_PAGES				
			4'd7:	// 8k
				case(ptattr.pte_size)
				_4B_PTE:
					case(ptbr.level)
					3'd0:	miss_queue[empty_qe].tadr <= {ptbr[31:13],13'd0} + {tlb_missadr[23:13],2'h0};
					3'd1:	miss_queue[empty_qe].tadr <= {ptbr[31:13],13'd0} + {tlb_missadr[31:24],2'h0};
					default:	miss_queue[empty_qe].tadr <= 'd0;
					endcase
				_8B_PTE:
					case(ptbr.level)
					3'd0:	miss_queue[empty_qe].tadr <= {ptbr[31:13],13'd0} + {tlb_missadr[22:13],3'h0};
					3'd1:	miss_queue[empty_qe].tadr <= {ptbr[31:13],13'd0} + {tlb_missadr[31:23],3'h0};
					default:	miss_queue[empty_qe].tadr <= 'd0;
					endcase
				_16B_PTE:
					case(ptbr.level)
					3'd0:	miss_queue[empty_qe].tadr <= {ptbr[31:13],13'd0} + {tlb_missadr[21:13],4'h0};
					3'd1:	miss_queue[empty_qe].tadr <= {ptbr[31:13],13'd0} + {tlb_missadr[30:22],4'h0};
					3'd2:	miss_queue[empty_qe].tadr <= {ptbr[31:13],13'd0} + {tlb_missadr[31],4'h0};
					default:	miss_queue[empty_qe].tadr <= 'd0;
					endcase
				default:	;
				endcase
`endif				
`ifdef MMU_SUPPORT_16k_PAGES				
			4'd8:	// 16k
				case(ptattr.pte_size)
				_4B_PTE:
					case(ptbr.level)
					3'd0:	miss_queue[empty_qe].tadr <= {ptbr[31:14],14'd0} + {tlb_missadr[25:14],2'h0};
					3'd1:	miss_queue[empty_qe].tadr <= {ptbr[31:14],14'd0} + {tlb_missadr[31:26],2'h0};
					default:	miss_queue[empty_qe].tadr <= 'd0;
					endcase
				_8B_PTE:
					case(ptbr.level)
					3'd0:	miss_queue[empty_qe].tadr <= {ptbr[31:14],14'd0} + {tlb_missadr[24:14],3'h0};
					3'd1:	miss_queue[empty_qe].tadr <= {ptbr[31:14],14'd0} + {tlb_missadr[31:25],3'h0};
					default:	miss_queue[empty_qe].tadr <= 'd0;
					endcase
				_16B_PTE:
					case(ptbr.level)
					3'd0:	miss_queue[empty_qe].tadr <= {ptbr[31:14],14'd0} + {tlb_missadr[23:14],4'h0};
					3'd1:	miss_queue[empty_qe].tadr <= {ptbr[31:14],14'd0} + {tlb_missadr[31:24],4'h0};
					default:	miss_queue[empty_qe].tadr <= 'd0;
					endcase
				default:	;
				endcase
`endif				
`ifdef MMU_SUPPORT_64k_PAGES
			4'd10:	// 64k
				case(ptattr.pte_size)
				_4B_PTE:
					case(ptbr.level)
					3'd0:	miss_queue[empty_qe].tadr <= {ptbr[31:16],16'd0} + {tlb_missadr[29:16],2'h0};
					3'd1:	miss_queue[empty_qe].tadr <= {ptbr[31:16],16'd0} + {tlb_missadr[31:30],2'h0};
					default:	miss_queue[empty_qe].tadr <= 'd0;
					endcase
				_8B_PTE:
					case(ptbr.level)
					3'd0:	miss_queue[empty_qe].tadr <= {ptbr[31:16],16'd0} + {tlb_missadr[28:16],3'h0};
					3'd1:	miss_queue[empty_qe].tadr <= {ptbr[31:16],16'd0} + {tlb_missadr[31:29],3'h0};
					default:	miss_queue[empty_qe].tadr <= 'd0;
					endcase
				_16B_PTE:
					case(ptbr.level)
					3'd0:	miss_queue[empty_qe].tadr <= {ptbr[31:16],16'd0} + {tlb_missadr[27:16],4'h0};
					3'd1:	miss_queue[empty_qe].tadr <= {ptbr[31:16],16'd0} + {tlb_missadr[31:28],4'h0};
					default:	miss_queue[empty_qe].tadr <= 'd0;
					endcase
				default:	;
				endcase
`endif				
			// 8k pages with 8B PTEs
			default:
				case(ptbr.level)
				3'd0:	miss_queue[empty_qe].tadr <= {ptbr.adr,3'd0} + {tlb_missadr[22:13],3'h0};
				3'd1:	miss_queue[empty_qe].tadr <= {ptbr.adr,3'd0} + {tlb_missadr[31:23],3'h0};
				default:	miss_queue[empty_qe].tadr <= 'd0;
				endcase
			endcase
		end
	end

	case(state)
	ptable_walker_pkg::IDLE:
		begin
			if (dump_qe >= 0) begin
				miss_queue[dump_qe].v <= 1'b0;
				miss_queue[dump_qe].o <= 1'b0;
				miss_queue[dump_qe].bc <= 2'b0;
			end
			if (walk_level) begin
				if (miss_queue[sel_qe].lvl != 3'd0) begin
					$display("PTW: walk level=%d", miss_queue[sel_qe].lvl);
					miss_queue[sel_qe].o <= 1'b1;
					miss_queue[sel_qe].lvl <= miss_queue[sel_qe].lvl - 1;
					if (tranbuf[sel_tran].pte.l1.s==1'b1 && Qupls4_pkg::SUPPORT_TLBLVL2)
						miss_queue[sel_qe].lvl <= 3'd0;
				end
				else if (miss_queue[sel_qe].bc < 3'd2) begin
					miss_queue[sel_qe].bc <= miss_queue[sel_qe].bc + 1;
				end
			end
		end
	default:
		;
	endcase
	
	// Search for ready translations and update the TLB.
	if (transfer_ready) begin
		$display("PTW: selected tran:%d", sel_tran[4:0]);
		// We're done if level one processed.
		if (miss_queue[tranbuf[sel_tran].mqndx].lvl==3'd0
			&& miss_queue[tranbuf[sel_tran].mqndx].bc>=3'd1) begin
				;
		end
		// For a level one page the upper bit come from the translated address.
		// Which means the lower bits of the translated address need to be cleared
		// then updated with the bits from the PTE's PPN.
		// This does not need to be done for higher level pages.
		else if (miss_queue[tranbuf[sel_tran].mqndx].lvl==3'd1 || tranbuf[sel_tran].pte.l1.s==1'b1) begin
			case(ptattr.pgsz)
`ifdef MMU_SUPPORT_4k_PAGES				
			4'd6:	// 4k
				case(ptattr.pte_size)
				_4B_PTE:	miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l1.ppn,pindex[9:0],2'b0} | (miss_queue[tranbuf[sel_tran].mqndx].tadr & {$bits({tranbuf[sel_tran].pte.l1.ppn,pindex[9:0],2'b0}){1'b0}});
				_8B_PTE:	miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l1.ppn,pindex[8:0],3'b0} | (miss_queue[tranbuf[sel_tran].mqndx].tadr & {$bits({tranbuf[sel_tran].pte.l1.ppn,pindex[8:0],3'b0}){1'b0}});
				_16B_PTE:	miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l1.ppn,pindex[7:0],4'b0} | (miss_queue[tranbuf[sel_tran].mqndx].tadr & {$bits({tranbuf[sel_tran].pte.l1.ppn,pindex[7:0],4'b0}){1'b0}});
				default:	;
				endcase
`endif				
`ifdef MMU_SUPPORT_8k_PAGES
			4'd7:	// 8k
				case(ptattr.pte_size)
				_4B_PTE:	miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l1.ppn,pindex[10:0],2'b0} | (miss_queue[tranbuf[sel_tran].mqndx].tadr & {$bits({tranbuf[sel_tran].pte.l1.ppn,pindex[10:0],2'b0}){1'b0}});
				_8B_PTE:	miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l1.ppn,pindex[9:0],3'b0} | (miss_queue[tranbuf[sel_tran].mqndx].tadr & {$bits({tranbuf[sel_tran].pte.l1.ppn,pindex[9:0],3'b0}){1'b0}});
				_16B_PTE:	miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l1.ppn,pindex[8:0],4'b0} | (miss_queue[tranbuf[sel_tran].mqndx].tadr & {$bits({tranbuf[sel_tran].pte.l1.ppn,pindex[8:0],4'b0}){1'b0}});
				default:	;
				endcase
`endif				
`ifdef MMU_SUPPORT_8k_PAGES
			4'd8:	// 16k
				case(ptattr.pte_size)
				_4B_PTE:	miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l1.ppn,pindex[11:0],2'b0} | (miss_queue[tranbuf[sel_tran].mqndx].tadr & {$bits({tranbuf[sel_tran].pte.l1.ppn,pindex[11:0],2'b0}){1'b0}});
				_8B_PTE:	miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l1.ppn,pindex[10:0],3'b0} | (miss_queue[tranbuf[sel_tran].mqndx].tadr & {$bits({tranbuf[sel_tran].pte.l1.ppn,pindex[10:0],3'b0}){1'b0}});
				_16B_PTE:	miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l1.ppn,pindex[9:0],4'b0} | (miss_queue[tranbuf[sel_tran].mqndx].tadr & {$bits({tranbuf[sel_tran].pte.l1.ppn,pindex[9:0],4'b0}){1'b0}});
				default:	;
				endcase
`endif				
`ifdef MMU_SUPPORT_64k_PAGES
			4'd10:	// 64k
				case(ptattr.pte_size)
				_4B_PTE:	miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l1.ppn,pindex[13:0],2'b0} | (miss_queue[tranbuf[sel_tran].mqndx].tadr & {$bits({tranbuf[sel_tran].pte.l1.ppn,pindex[13:0],2'b0}){1'b0}});
				_8B_PTE:	miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l1.ppn,pindex[12:0],3'b0} | (miss_queue[tranbuf[sel_tran].mqndx].tadr & {$bits({tranbuf[sel_tran].pte.l1.ppn,pindex[12:0],3'b0}){1'b0}});
				_16B_PTE:	miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l1.ppn,pindex[11:0],4'b0} | (miss_queue[tranbuf[sel_tran].mqndx].tadr & {$bits({tranbuf[sel_tran].pte.l1.ppn,pindex[11:0],4'b0}){1'b0}});
				default:	;
				endcase
`endif				
			// 8k pages, 8B pte
			default:
				miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l1.ppn,pindex[9:0],3'b0} | (miss_queue[tranbuf[sel_tran].mqndx].tadr & {$bits({tranbuf[sel_tran].pte.l1.ppn,pindex[9:0],3'b0}){1'b0}});
			endcase
		end
		else begin
			case(ptattr.pgsz)
`ifdef MMU_SUPPORT_4k_PAGES				
			4'd6:	// 4k
				case(ptattr.pte_size)
				_4B_PTE:	miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l2.ppn,pindex[9:0],2'b0};
				_8B_PTE:	miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l2.ppn,pindex[8:0],3'b0};
				_16B_PTE:	miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l2.ppn,pindex[7:0],4'b0};
				default:	;
				endcase
`endif				
`ifdef MMU_SUPPORT_8k_PAGES
			4'd7:	// 8k
				case(ptattr.pte_size)
				_4B_PTE:	miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l2.ppn,pindex[10:0],2'b0};
				_8B_PTE:	miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l2.ppn,pindex[9:0],3'b0};
				_16B_PTE:	miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l2.ppn,pindex[8:0],4'b0};
				default:	;
				endcase
`endif				
`ifdef MMU_SUPPORT_8k_PAGES
			4'd8:	// 16k
				case(ptattr.pte_size)
				_4B_PTE:	miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l2.ppn,pindex[11:0],2'b0};
				_8B_PTE:	miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l2.ppn,pindex[10:0],3'b0};
				_16B_PTE:	miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l2.ppn,pindex[9:0],4'b0};
				default:	;
				endcase
`endif				
`ifdef MMU_SUPPORT_64k_PAGES
			4'd10:	// 64k
				case(ptattr.pte_size)
				_4B_PTE:	miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l2.ppn,pindex[13:0],2'b0};
				_8B_PTE:	miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l2.ppn,pindex[12:0],3'b0};
				_16B_PTE:	miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l2.ppn,pindex[11:0],4'b0};
				default:	;
				endcase
`endif				
			// 8k pages, 8B pte
			default:
				miss_queue[tranbuf[sel_tran].mqndx].tadr <= {tranbuf[sel_tran].pte.l2.ppn,pindex[9:0],3'b0};
			endcase
		end
	end
end

endmodule
