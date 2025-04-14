// ============================================================================
//        __
//   \\__/ o\    (C) 2022-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	cache_pkg.sv
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

package cache_pkg;

parameter ITAG_BIT = 14;
parameter DCacheLineWidth = 512;
localparam DCacheTagLoBit = $clog2((DCacheLineWidth/8));
parameter ICacheBundleWidth = 256;
parameter ICacheLineWidth = ICacheBundleWidth*2;
localparam ICacheTagLoBit = $clog2((ICacheLineWidth/8));

`define TAG_ASID $bits(cpu_types_pkg::asid_t) + $bits(cpu_types_pkg::address_t)-ITAG_BIT-1:$bits(cpu_types_pkg::address_t)-ITAG_BIT

typedef logic [$bits(cpu_types_pkg::address_t)-1:ITAG_BIT] cache_tag_t;

typedef struct packed
{
	logic v;		// valid indicator
	logic m;		// modified indicator
	cpu_types_pkg::asid_t asid;
	logic [$bits(cpu_types_pkg::address_t)-1:0] vtag;	// virtual tag
	logic [$bits(cpu_types_pkg::address_t)-1:0] ptag;	// physical tag
	logic [DCacheLineWidth-1:0] data;
} DCacheLine;

typedef struct packed
{
	logic [ICacheLineWidth/ICacheBundleWidth-1:0] v;	// 1 valid bit per 128 bits data
	logic m;		// modified indicator
	cpu_types_pkg::asid_t asid;
	logic [$bits(cpu_types_pkg::address_t)-1:0] vtag;	// virtual tag
	logic [$bits(cpu_types_pkg::address_t)-1:0] ptag;	// physical tag
	logic [ICacheLineWidth-1:0] data;
} ICacheLine;

typedef struct packed
{
	logic v;
	logic is_load;
	logic is_dump;
	logic [1:0] active;
	logic [1:0] done;
	logic [1:0] out;
	logic [1:0] loaded;
	logic write_allocate;
	cpu_types_pkg:rob_ndx_t rndx;
	fta_bus_pkg::fta_cmd_request512_t cpu_req;
	fta_bus_pkg::fta_cmd_request256_t [1:0] tran_req;
} dcache_req_queue_t;

endpackage
