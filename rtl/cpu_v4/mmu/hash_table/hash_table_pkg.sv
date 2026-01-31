// ============================================================================
//        __
//   \\__/ o\    (C) 2026  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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
//
package hash_table_pkg;

typedef struct packed {
	logic v;							// valid entry
	logic [4:0] resv;
	logic [2:0] rgn;			// memory region (DRAM)
	logic m;							// modified
	logic a;							// accessed
	logic t;							//
	logic s;							// shared
	logic [2:0] sw;
	logic [1:0] cache;		// 0=none,1=L1,2=L2,3=LLC
	logic [9:0] asid;
	logic u;							// 1= user space
	logic [2:0] rwx;
	logic [15:0] ppn;			// physcial page number
	logic [15:0] vpn;			// virtual page number
} ptge_t;

typedef struct packed {
	ptge_t [7:0] ptge;
} ptg_t;

function [9:0] fnHash;
input [31:0] vadr;
input [9:0] asid;
begin
	fnHash = vadr[27:18]^asid;
end
endfunction

// Find an entry in a page table group register.

function [3:0] fnFind;
input ptg_t rec;
input [31:0] vadr;
input [9:0] asid;
integer n;
begin
	fnFind = 4'hF;
	for (n = 0; n < 8; n = n + 1) begin
		if (rec.ptge[n].v && rec.ptge[n].vpn==vadr[29:18] && rec.ptge[n].asid == asid)
			fnFind = {1'b0,n[2:0]};
	end
end
endfunction

endpackage

