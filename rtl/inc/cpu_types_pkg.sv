// ============================================================================
//        __
//   \\__/ o\    (C) 2024  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	cpu_types_pkg.sv
//	- types that must be configured for a particular CPU
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

`define CPU_TYPES_PKG	1'b1
//`define TINY_MMU	1'b1
`define SMALL_MMU	1'b1
//`define BIG_MMU	1'b1

package cpu_types_pkg;

typedef logic [15:0] asid_t;
`ifdef TINY_MMU
typedef logic [31:0] address_t;
typedef logic [31:0] code_address_t;
typedef logic [31:0] pc_address_t;
typedef logic [31:0] virtual_address_t;
typedef logic [31:0] physical_address_t;
`endif
`ifdef SMALL_MMU
typedef logic [31:0] address_t;
typedef logic [31:0] code_address_t;
typedef logic [31:0] pc_address_t;
typedef logic [31:0] virtual_address_t;
typedef logic [31:0] physical_address_t;
`endif
typedef logic [11:0] mc_address_t;
typedef logic [9:0] pregno_t;
typedef logic [7:0] aregno_t;
//typedef logic [63:0] segment_reg_t;

typedef logic [127:0] value_t;
typedef struct packed {
	value_t H;
	value_t L;
} double_value_t;
typedef logic [63:0] half_value_t;
typedef logic [511:0] quad_value_t;
typedef logic [1023:0] octa_value_t;

parameter value_zero = {$bits(value_t){1'b0}};

endpackage