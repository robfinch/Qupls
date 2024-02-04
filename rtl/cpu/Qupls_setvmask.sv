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
// ============================================================================

module Qupls_setvmask(max_ele_sz, numlanes, lanesz, mask);
input [7:0] max_ele_sz;	// 8/16 bytes
input [6:0] numlanes;		// 0 to 64
input [5:0] lanesz;			// size of lane in bytes
output reg [63:0] mask;

reg [64:0] mask1;
reg [3:0] bits_per_element;

always_comb
	bits_per_element = max_ele_sz >> $clog2(lanesz);

// Bitmask according to lanes
always_comb
	mask1 = (65'd1 << numlanes) - 64'd1;

always_comb
	case(bits_per_element)
	4'd1:	mask = {
		7'd0,mask1[7],
		7'd0,mask1[6],
		7'd0,mask1[5],
		7'd0,mask1[4],
		7'd0,mask1[3],
		7'd0,mask1[2],
		7'd0,mask1[1],
		7'd0,mask1[0]
		};
	4'd2:	mask = {
		6'd0,mask[15:14],
		6'd0,mask[13:12],
		6'd0,mask[11:10],
		6'd0,mask[9:8],
		6'd0,mask[7:6],
		6'd0,mask[5:4],
		6'd0,mask[3:2],
		6'd0,mask[1:0]
		};
	4'd4:	mask = {
		4'd0,mask[31:28],
		4'd0,mask[27:24],
		4'd0,mask[23:20],
		4'd0,mask[19:16],
		4'd0,mask[15:12],
		4'd0,mask[11:8],
		4'd0,mask[7:4],
		4'd0,mask[3:0]
		};
	default:	// 8
		mask = mask1;		
	endcase

endmodule
