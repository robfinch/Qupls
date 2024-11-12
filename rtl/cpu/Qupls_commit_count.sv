// ============================================================================
//        __
//   \\__/ o\    (C) 2024  Robert Finch, Waterloo
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
// LUTs / FFs
// ============================================================================

import const_pkg::*;
import QuplsPkg::*;

module Qupls_commit_count(rst, next_cqd, rob,
	head0, head1, head2, head3, head4, head5,
	tail0, tail1, tail2, tail3, tail4, tail5,
	cmtcnt, do_commit);
parameter XWID = 4;
input rst;
input [XWID-1:0] next_cqd;
input rob_entry_t [ROB_ENTRIES-1:0] rob;
input rob_ndx_t head0;
input rob_ndx_t head1;
input rob_ndx_t head2;
input rob_ndx_t head3;
input rob_ndx_t head4;
input rob_ndx_t head5;
input rob_ndx_t tail0;
input rob_ndx_t tail1;
input rob_ndx_t tail2;
input rob_ndx_t tail3;
input rob_ndx_t tail4;
input rob_ndx_t tail5;
output reg [2:0] cmtcnt;
output reg do_commit;

reg cmt0,cmt1,cmt2,cmt3,cmt4,cmt5;
reg htcolls;

always_comb cmt0 = (rob[head0].v && &rob[head0].done) || (!rob[head0].v && ((head0 != tail0) || &next_cqd));
always_comb cmt1 = XWID > 1 && ((rob[head1].v && &rob[head1].done) || (!rob[head1].v && head0 != tail0 && head0 != tail1)) &&
										!rob[head0].decbus.oddball && !rob[head0].excv
										;
always_comb cmt2 = XWID > 2 && ((rob[head2].v && &rob[head2].done) || (!rob[head2].v && head0 != tail0 && head0 != tail1 && head0 != tail2)) &&
										!rob[head0].decbus.oddball && !rob[head1].decbus.oddball &&
										!rob[head0].excv && !rob[head1].excv
										;
always_comb cmt3 = XWID > 3 && ((rob[head3].v && &rob[head3].done) || (!rob[head3].v && head0 != tail0 && head0 != tail1 && head0 != tail2 && head0 != tail3)) &&
										!rob[head0].decbus.oddball && !rob[head1].decbus.oddball && !rob[head2].decbus.oddball &&
										!rob[head0].excv && !rob[head1].excv && !rob[head2].excv
										;
always_comb	cmt4 = !rob[head4].v && (head0 != tail0 && head0 != tail1 && head0 != tail2 && head0 != tail3 && head0 != tail4);
always_comb	cmt5 = !rob[head5].v && (head0 != tail0 && head0 != tail1 && head0 != tail2 && head0 != tail3 && head0 != tail4 && head0 != tail5);

// Figure out how many instructions can be committed.
// If there is an oddball instruction (eg. CSR, RTE) then only commit up until
// the oddball. Also, if there is an exception, commit only up until the 
// exception. Otherwise commit instructions that are not valid or are valid
// and done. Do not commit invalid instructions at the tail of the queue.

function fnColls;
input rob_ndx_t head;
input rob_ndx_t tail;
begin
	case(XWID)
	1:
		if (head > tail)
			fnColls = head - tail > (ROB_ENTRIES-2);
		else
			fnColls = ROB_ENTRIES + head - tail > (ROB_ENTRIES-2);
	2:
		if (head > tail)
			fnColls = head - tail > (ROB_ENTRIES-3);
		else
			fnColls = ROB_ENTRIES + head - tail > (ROB_ENTRIES-3);
	3:
		if (head > tail)
			fnColls = head - tail > (ROB_ENTRIES-4);
		else
			fnColls = ROB_ENTRIES + head - tail > (ROB_ENTRIES-4);
	4:
		if (head > tail)
			fnColls = head - tail > (ROB_ENTRIES-7);
		else
			fnColls = ROB_ENTRIES + head - tail > (ROB_ENTRIES-7);
	default:
			fnColls = FALSE;
	endcase
end
endfunction

always_comb htcolls = fnColls(head0, tail0);

// Commit only by instructions with the same checkpoint index. The RAT can
// currently handle only one checkpoint index spec for update.

always_comb//ff @(posedge clk)
if (rst) begin
	cmtcnt = 3'd0;
	do_commit = FALSE;
end
else begin
	cmtcnt = 3'd0;
	if (!htcolls) begin
		casez({cmt0,
			cmt1 && rob[head1].cndx==rob[head0].cndx,
			cmt2 && rob[head2].cndx==rob[head0].cndx,
			cmt3 && rob[head3].cndx==rob[head0].cndx,
			cmt4 && rob[head4].cndx==rob[head0].cndx,
			cmt5 && rob[head5].cndx==rob[head0].cndx})
		6'b111111:	cmtcnt = 3'd6;
		6'b111110:	cmtcnt = 3'd5;
		6'b11110?:	cmtcnt = 3'd4;
		6'b1110??:	cmtcnt = 3'd3;
		6'b110???:	cmtcnt = 3'd2;
		6'b10????:	cmtcnt = 3'd1;
		default:	cmtcnt = 3'd0;
		endcase
		do_commit = cmt0;
	end
	else
		do_commit = FALSE;
end

endmodule
