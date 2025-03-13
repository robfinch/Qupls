// ============================================================================
//        __
//   \\__/ o\    (C) 2022-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	bigfoot_mmupkg.sv
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
import fta_bus_pkg::*;
import cpu_types_pkg::*;

`define SMALL_MMU 1'b1
//`define MMU_SUPPORT_4k_PAGES	1'b1
`define MMU_SUPPORT_8k_PAGES	1'b1
//`define MMU_SUPPORT_16k_PAGES	1'b1
//`define MMU_SUPPORT_64k_PAGES	1'b1

package mmu_pkg;

`ifdef TINY_MMU
parameter PAGE_SIZE = 65536;
parameter ENTRIES = 1024;
`endif
`ifdef SMALL_MMU
parameter PAGE_SIZE = 8192;
parameter ENTRIES = 1024;
`endif
`ifdef BIG_MMU
parameter PAGE_SIZE = 16384;
parameter ENTRIES = 1024;
`endif
parameter LOG_PAGE_SIZE = $clog2(PAGE_SIZE);
parameter LOG_ENTRIES = $clog2(ENTRIES);

parameter ITAG_BIT = 12;
parameter DCacheLineWidth = 512;
localparam DCacheTagLoBit = $clog2((DCacheLineWidth/8))-1;
parameter ICacheLineWidth = 256;
localparam ICacheTagLoBit = $clog2((ICacheLineWidth/8))-1;

`define TAG_ASID $bits(cpu_types_pkg::asid_t) + $bits(cpu_types_pkg::address_t)-ITAG_BIT-1:$bits(cpu_types_pkg::address_t)-ITAG_BIT

typedef logic [5:0] tlb_count_t;
typedef logic [2:0] rwx_t;

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
	logic [7:0] pl;
	logic [11:0] ndx;
} selector_t;

typedef struct packed
{
	logic v;
	logic [2:0] rfu2;
	logic [63:0] limit;
	logic [1:0] rfu1;
	logic [3:0] gran;
	logic [1:0] typ;
	logic d;
	logic [2:0] urwx;
} descriptor_limit_t;

typedef logic [79:0] descriptor_base_t;

typedef logic [19:0] lot_key_t;

typedef struct packed
{
	cpu_types_pkg::asid_t asid;
	cpu_types_pkg::virtual_address_t vadr;
} stlb_request_t;

typedef struct packed
{
	logic [3:0] rwx;
	fta_bus_pkg::fta_cache_t cache;
	cpu_types_pkg::virtual_address_t vadr;
	cpu_types_pkg::physical_address_t padr;
} stlb_response_t;

typedef struct packed
{
	logic [63:3] adr;		// page table address, bits 3 to 63
	logic [2:0] level;	// entry level of hierarchical page table
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
} REGION_ATTR;

typedef struct packed
{
	REGION_ATTR [3:0] at;
	cpu_types_pkg::physical_address_t cta;
	cpu_types_pkg::physical_address_t pmt;
	cpu_types_pkg::physical_address_t end_adr;
	cpu_types_pkg::physical_address_t start_adr;
	logic [31:0] lock;
} REGION;

typedef struct packed
{
	logic vm;						// 
	logic pm;						//page modified 1=modified
	logic [29:0] access_count;

	logic compressed;		// 1= compressed
	logic e;						// 1= encrypted
	logic [1:0] al;
	
	logic [3:0] cache;
	logic [2:0] mrwx;		// w=1 = conforming executable page when x=1
	logic [2:0] hrwx;
	logic [2:0] srwx;
	logic [2:0] urwx;

	logic [9:0] resv1;
	logic [1:0] content;	// 0=data,2=stack,3=executable
	logic [15:0] acl;
	logic [15:0] share_count;
	logic [7:0] pl;
	logic [23:0] key;
} pmte_t;	// 128 bits

// Small Hash Page Table Entry
// Used to map 36-bit virtual addresses into a 32-bit physical address space.
typedef struct packed
{
	cpu_types_pkg::asid_t asid;
	logic [19:0] vpn;
	logic [15:0] ppn;
	logic v;
	logic [4:0] bc;
	logic [2:0] rgn;
	logic m;
	logic a;
	logic t;
	logic s;
	logic g;
	logic sw;
} shpte_t;	// 64 bits

typedef struct packed
{
	logic [10:0] rfu;					// reserved for future use
	logic [2:0] rgn;					// region table index
	logic [2:0] c_algorithm;	// compression algorithm
	logic [2:0] e_algorithm;	// encryption algorithm
	logic [3:0] cache;				// cacheability
	logic mw;									// machine mode write enable
	logic hw;									// hypervisor write enable
	logic [2:0] srwx;					// supervisor read-write-execute
	logic [2:0] urwx;					// user read-write-execute
	logic [7:0] pl;						// privilege level
	logic [23:0] key;					// access key
	logic v;									// valid bit
	logic [2:0] lvl;					// level, 0=leaf
	logic m;									// 1=modified
	logic a;									// 1=accessed
	logic t;									// 0=PTE, 1=PTP
	logic [2:0] avl;					// available for software
	logic [53:0] ppn;					// physical page number
} hpte_t;										// 128-bit

// Page table entry. Physical memory <= 2^57B.
`ifdef BIG_MMU
typedef struct packed
{
	logic v;									// 1=valid
	logic [2:0] lvl;					//
	logic s;									// 1=shortcut
	logic [2:0] rgn;					// memory region
	logic m;									// 1=modified
	logic a;									// 1=accessed
	logic [2:0] avl;					// available for OS use
	logic [2:0] cache;				// cache location
	logic u;									// 1=user page
	logic [2:0] rwx;					// read-write-execute
	logic [43:0] ppn;					// 57 bit address space (44 bit page number)
} pte_t;										// 64 bits

// Big VPN, Virtual memory <= 2^64B
typedef struct packed
{
	cpu_types_pkg::asid_t asid;	// 16 bits
	logic [50:0] vpn;						// bits 13 to 63 of address
} vpn_t;											// 67 bits

`endif

// Small page table entry. Physical memory <= 2^35B.
typedef struct packed
{
	logic v;									// 1=valid
	logic [1:0] lvl;					// valid
	logic s;									// 1=shortcut
	logic [2:0] rgn;					// memory region
	logic m;									// 1=modified
	logic a;									// 1=accessed
	logic [2:0] avl;					// available for OS use
	logic [1:0] cache;				// cache location (none,L1,L2,LLC)
	logic u;									// 1=user page
	logic [2:0] rwx;					// read-write-execute
	logic [21:0] ppn;					// 35 bit address space (22 bit page number)
} spte_lvl1_t;							// 40 bits

// Small page table entry. Physical memory <= 2^35B.
typedef struct packed
{
	logic v;									// 1=valid
	logic [1:0] lvl;					// valid
	logic s;									// 1=shortcut
	logic [2:0] rgn;					// memory region
	logic m;									// 1=modified
	logic a;									// 1=accessed
	logic [2:0] avl;					// available for OS use
	logic [1:0] cache;				// cache location (none,L1,L2,LLC)
	logic u;									// 1=user page
	logic [2:0] rwx;					// read-write-execute
	logic [11:0] ppn;					// 35 bit address space (22 bit page number)
	logic [9:0] limit;
} spte_lvl2_t;							// 40 bits

`ifdef SMALL_MMU
typedef union packed {
	spte_lvl1_t l1;
	spte_lvl2_t l2;
} pte_t;
// Small VPN, Virtual memory <= 2^40B
typedef struct packed
{
	cpu_types_pkg::asid_t asid;	// 16 bits
	logic [26:0] vpn;						// bits 13 to 39 of address
} vpn_t;											// 43 bits
`endif

// Tiny page table entry. Physical memory <= 2^23B.
`ifdef TINY_MMU
typedef struct packed
{
	logic v;									// 1=valid
	logic lvl;								//
	logic [2:0] rgn;					// memory region
	logic m;									// 1=modified
	logic a;									// 1=accessed
	logic [1:0] avl;					// available for OS use
	logic cache;							// cache location (none,L1)
	logic u;									// 1=user page
	logic [2:0] rwx;					// read-write-execute
	logic [9:0] ppn;					// 26 bit address space (10 bit page number)
} pte_t;										// 24 bits
// Tiny VPN, Virtual memory <= 2^32B
typedef struct packed
{
	cpu_types_pkg::asid_t asid;	// 16 bits
	logic [18:0] vpn;						// bits 13 to 31 of address
} vpn_t;											// 35 bits

`endif

typedef struct packed
{
	tlb_count_t count;		// 6
	logic nru;						// 1
	pte_t pte;						// 128
	vpn_t vpn;						// 64
} tlb_entry_t;					// 199 bits

// Hash Page Table Entry
typedef struct packed
{
	logic [31:0] vpnhi;
	logic [31:0] ppnhi;
	logic [11:0] asid;
	logic [4:0] bc;
	logic [17:0] vpn;
	logic [21:0] ppn;
	logic sw;
	logic m;
	logic a;
	logic g;
	logic c;
	logic [2:0] rwx;
} hshpte_t;	// 128 bits

/*
typedef struct packed
{
	logic v;
	cpu_types_pkg::address_t adr;
	PDE pde;
} PDCE;
*/
`define PtePerPtg 8
`define PtgSize 2048
`define StripsPerPtg	10

integer PtePerPtg = `PtePerPtg;
integer PtgSize = `PtgSize;

typedef struct packed
{
	hpte_t [`PtePerPtg-1:0] ptes;
} ptg_t;	// 1024 bits

typedef struct packed
{
	shpte_t [`PtePerPtg-1:0] ptes;
} sptg_t;	// 512 bits

typedef struct packed
{
	logic v;
	cpu_types_pkg::address_t dadr;
	ptg_t ptg;
} PTGCE;
parameter PTGC_DEP = 8;

typedef enum logic [6:0] {
	MEMORY_INIT = 7'd0,
	MEMORY_IDLE = 7'd1,
	MEMORY_DISPATCH = 7'd2,
	MEMORY3 = 7'd3,
	MEMORY4 = 7'd4,
	MEMORY5 = 7'd5,
	MEMORY_ACK = 7'd6,
	MEMORY_NACK = 7'd7,
	MEMORY8 = 7'd8,
	MEMORY9 = 7'd9,
	MEMORY10 = 7'd10,
	MEMORY11 = 7'd11,
	MEMORY_ACKHI = 7'd12,
	MEMORY13 = 7'd13,
	DATA_ALIGN = 7'd14,
	MEMORY_KEYCHK1 = 7'd15,
	MEMORY_KEYCHK2 = 7'd16,
	KEYCHK_ERR = 7'd17,
	TLB1 = 7'd21,
	TLB2 = 7'd22,
	TLB3 = 7'd23,
	RGN1 = 7'd25,
	RGN2 = 7'd26,
	RGN3 = 7'd27,
	IFETCH0 = 7'd30,
	IFETCH1 = 7'd31,
	IFETCH2 = 7'd32,
	IFETCH3 = 7'd33,
	IFETCH4 = 7'd34,
	IFETCH5 = 7'd35,
	IFETCH6 = 7'd36,
	IFETCH1a = 7'd37,
	IFETCH1b = 7'd38,
	IFETCH3a = 7'd39,
	DFETCH2 = 7'd42,
	DFETCH5 = 7'd43,
	DFETCH6 = 7'd44,
	DFETCH7 = 7'd45,
	DSTORE1 = 7'd46,
	DSTORE2 = 7'd47,
	DSTORE3 = 7'd48,
	KYLD = 7'd51,
	KYLD2 = 7'd52,
	KYLD3 = 7'd53,
	KYLD4 = 7'd54,
	KYLD5 = 7'd55,
	KYLD6 = 7'd56,
	KYLD7 = 7'd57,
	MEMORY1 = 7'd60,
	MFSEL1 = 7'd61,
	MEMORY_ACTIVATE = 7'd62,
	MEMORY_ACTIVATE_HI = 7'd63,
	IPT_FETCH1 = 7'd64,
	IPT_FETCH2 = 7'd65,
	IPT_FETCH3 = 7'd66,
	IPT_FETCH4 = 7'd67,
	IPT_FETCH5 = 7'd68,
	IPT_RW_PTG2 = 7'd69,
	IPT_RW_PTG3 = 7'd70,
	IPT_RW_PTG4 = 7'd71,
	IPT_RW_PTG5 = 7'd72,
	IPT_RW_PTG6 = 7'd73,
	IPT_WRITE_PTE = 7'd75,
	IPT_IDLE = 7'd76,
	MEMORY5a = 7'd77,
	PT_FETCH1 = 7'd81,
	PT_FETCH2 = 7'd82,
	PT_FETCH3 = 7'd83,
	PT_FETCH4 = 7'd84,
	PT_FETCH5 = 7'd85,
	PT_FETCH6 = 7'd86,
	PT_RW_PTE1 = 7'd92,
	PT_RW_PTE2 = 7'd93,
	PT_RW_PTE3 = 7'd94,
	PT_RW_PTE4 = 7'd95,
	PT_RW_PTE5 = 7'd96,
	PT_RW_PTE6 = 7'd97,
	PT_RW_PTE7 = 7'd98,
	PT_WRITE_PTE = 7'd99,
	PMT_FETCH1 = 7'd101,
	PMT_FETCH2 = 7'd102,
	PMT_FETCH3 = 7'd103,
	PMT_FETCH4 = 7'd104,
	PMT_FETCH5 = 7'd105,
	PT_RW_PDE1 = 7'd108,
	PT_RW_PDE2 = 7'd109,
	PT_RW_PDE3 = 7'd110,
	PT_RW_PDE4 = 7'd111,
	PT_RW_PDE5 = 7'd112,
	PT_RW_PDE6 = 7'd113,
	PT_RW_PDE7 = 7'd114,
	PTG1 = 7'd115,
	PTG2 = 7'd116,
	PTG3 = 7'd117,
	MEMORY_UPD1 = 7'd118,
	MEMORY_UPD2 = 7'd119
} mem_state_t;

parameter IPT_CLOCK1 = 7'd1;
parameter IPT_CLOCK2 = 7'd2;
parameter IPT_CLOCK3 = 7'd3;

endpackage
