`timescale 1ns / 1ps
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
import const_pkg::*;

module ht_page_fault(rst, clk, xlat, found, empty, bounce,
	current_group, page_group, fault_group, page_fault);
input rst;
input clk;
input xlat;
input found;
input [7:0] empty;
input [4:0] bounce;
input [9:0] current_group;
input [9:0] page_group;
output reg [17:0] fault_group;
output reg page_fault;

reg [17:0] fault_group1;

always_ff @(posedge clk)
if (rst)
	fault_group <= 18'h0ff;
else begin
	if (xlat) begin
		if (!found & ~|empty) begin	// and not found and no empty slot
			if (bounce==5'd30) begin	// and bounced too many times
				fault_group <= {page_group,8'h00};
			end
		end
		if (!found & |empty) begin
			fault_group <= {current_group,empty};
		end
	end
end
/*
always_ff @(posedge clk)
	if (page_fault)
		fault_group <= fault_group1;
*/
always_comb//ff @(posedge clk)
/*
if (rst) begin
	page_fault <= FALSE;
end
else 
*/
begin
	if (xlat) begin
		page_fault = FALSE;
		if (!found & ~|empty) begin	// and not found and no empty slot
			if (bounce==5'd30) begin	// and bounced too many times
				page_fault = TRUE;
			end
		end
		if (!found & |empty) begin
			page_fault = TRUE;
		end
	end
	else begin
		page_fault = FALSE;
	end
end

endmodule
