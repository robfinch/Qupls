// ============================================================================
//        __
//   \\__/ o\    (C) 2022-2026  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	mmu_pkg.sv
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

package mmu_pkg;

typedef enum logic [1:0] {
    _4B_PTE,
    _8B_PTE,
    _16B_PTE
} e_pte_size;

typedef enum logic [2:0] {
	NAT_HIERARCHIAL = 3'd0,
	NAT_HASH,
	NAT_TINYHIER,
	I386 = 3'd7
} e_pt_type;

typedef struct packed
{
	logic [63:3] adr;		// page table address, bits 3 to 63
	logic [2:0] zero;		// reserved, should be zero
} ptbr_t;

typedef struct packed
{
	logic [31:0] adr_hi;	// page table address, bits 64 to 95
	logic [15:0] limit;	// root page table limit (# of entries)
	logic [2:0] level;	// entry level of hierarchical page table
	logic [1:0] al;			// replacement algorithm, 0=fixed,1=LRU,2=random
	logic s;						// 1=software,0=hardware managed TLB
	logic pa;						// 1=physical addressing,0=virtual (page table location)
	e_pte_size pte_size;	// size of PTEs (0=4,1=8,2=16)
	logic [3:0] pgsz;		// page size, 6+pgsz bits (6 to 21 bits).
	e_pt_type typ;			// 0=native hierarchical,1=native hash,2=i386
} ptattr_t;						// 64 bits

typedef struct packed
{
	logic [7:0] resv3;
	logic [7:0] dev_type;
	logic resv2;
	logic [2:0] s;
	logic resv1;
	logic [2:0] gran;
	logic [3:0] cache;
	logic [3:0] rwx;
} region_attr_t;

typedef struct packed
{
	logic [31:0] lock;
	region_attr_t [3:0] at;
	cpu_types_pkg::physical_address_t cta;
	cpu_types_pkg::physical_address_t pmt;
	cpu_types_pkg::physical_address_t pam;
	cpu_types_pkg::physical_address_t end_adr;
	cpu_types_pkg::physical_address_t start_adr;
} region_t;

typedef struct packed {
	logic v;								// valid
	logic resv;							// reserved
	logic [2:0] lvl;
	logic [2:0] rgn;
	logic m;
	logic a;
	logic t;
	logic s;								// shortcut page
	logic g;								// shortcut page
	logic [2:0] sw;
	logic [1:0] cache;
	logic u;
	logic [2:0] rwx;
	logic [41:0] ppn;				// 42+13 = 55 bit physical address
} pte_t;									// 64 bits

typedef struct packed {
	cpu_types_pkg::asid_t asid;	// 16 bits
	logic [39:0] vpn;       // 40+9+13 = 62 bit virtual address space
} vpn_t;									// 56 bits

typedef struct packed
{
	logic [5:0] count;		// 6
	logic nru;						// 1
	logic lock;						// 1=entry locked
	vpn_t vpn;						// 56
	pte_t pte;						// 64
} tlb_entry_t;					// 128 bits

typedef struct packed {
	logic [63:0] adr;
	pte_t pte;
} pte_adr_t;

// Hash Table Entry
typedef struct packed
{
	logic v;							// entry valid
	logic d;							// deleted entry
	logic [3:0] resv;			// reserved bits
	logic [2:0] rgn;
	logic m;							// modified
	logic a;							// accessed
	logic t;							// type (not used)
	logic s;							// shortcut
	logic g;							// global page
	logic [2:0] sw;				// available for software
	logic [1:0] cache;
	logic [7:0] asid;
	logic u;							// 1=user page
	logic [2:0] rwx;
	logic [15:0] vpn;			// virtual pag number
	logic [15:0] ppn;			// physical page number
} hte_t;								// 64 bits

typedef struct packed
{
	hte_t [7:0] htes;
} htg_t;								// 512 bits


endpackage
