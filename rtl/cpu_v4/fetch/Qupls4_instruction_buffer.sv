// ============================================================================
//        __
//   \\__/ o\    (C) 2025-2026  Robert Finch, Waterloo
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
//
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_instruction_buffer(rst_i, clk_i, ihit_i, stream_i, ips_i, ip_i, line_i, line_o, ip_o, is_buffered_o);
input rst_i;
input clk_i;
input ihit_i;
input cpu_types_pkg::pc_stream_t stream_i;
input cpu_types_pkg::pc_address_ex_t ip_i;
input [1023:0] line_i;
output reg [1023:0] line_o;
input pc_address_ex_t [Qupls4_pkg::XSTREAMS*Qupls4_pkg::THREADS-1:0] ips_i;
output pc_address_ex_t ip_o;
output reg is_buffered_o;

integer n1,n43;
reg [Qupls4_pkg::XSTREAMS*Qupls4_pkg::THREADS-1:0] buffered;
// Buffers the instruction cache line to allow fetching along alternate paths.
reg [1023:0] line_buf [0:3];
cpu_types_pkg::pc_address_t ip_buf [0:3];

always_comb
begin
	line_o = line_i;
	ip_o = ip_i;
	is_buffered_o = FALSE;
	foreach (ip_buf[n43])
		if (ip_i.pc >= ip_buf[n43] && ip_i.pc < ip_buf[n43] + 8'd96) begin
			line_o = line_buf[n43];
			ip_o = ip_i;
			is_buffered_o = TRUE;
		end
end

// If the cache line is not buffered, buffer it.
always_ff @(posedge clk_i)
if (rst_i) begin
	foreach (line_buf[n1]) begin
		line_buf[n1] = {1024{1'b1}};	// NOPs
		ip_buf[n1] = 32'd0;
	end
end
else begin
	if (~is_buffered_o & ihit_i) begin
		foreach (line_buf[n1]) begin
			if (n1==$size(line_buf)-1) begin
				line_buf[n1] <= line_i;
				ip_buf[n1] <= {ip_i.pc[$bits(cpu_types_pkg::pc_address_t)-1:6],6'd0};
			end
			else begin
				line_buf[n1] <= line_buf[n1+1];
				ip_buf[n1] <= ip_buf[n1+1];
			end
		end
	end
end

endmodule
