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
//
// Split groups containing branches into multiple groups.
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import QuplsPkg::*;

module Qupls_space_branches(rst, clk, en, get, ins_i, ins_o, stall);
input rst;
input clk;
input en;
input get;
input pipeline_reg_t [3:0] ins_i;
output pipeline_reg_t [3:0] ins_o;
output reg stall;

reg ld;
reg [2:0] count;
reg [2:0] got;
pipeline_reg_t [3:0] buff [4:0];
pipeline_reg_t nopi;
integer nn, mm;

// Define a NOP instruction.
always_comb
begin
	nopi = {$bits(pipeline_reg_t){1'b0}};
	nopi.exc = FLT_NONE;
	nopi.pc.pc = RSTPC;
	nopi.mcip = 12'h1A0;
	nopi.len = 4'd8;
	nopi.ins = {57'd0,OP_NOP};
	nopi.pred_btst = 6'd0;
	nopi.element = 'd0;
	nopi.aRa = 8'd0;
	nopi.aRb = 8'd0;
	nopi.aRc = 8'd0;
	nopi.aRt = 8'd0;
	nopi.v = 1'b1;
	nopi.decbus.Rtz = 1'b1;
	nopi.decbus.nop = 1'b1;
	nopi.decbus.alu = 1'b1;
end

always_ff @(posedge clk)
if (rst) begin
	for (nn = 0; nn < 5; nn = nn + 1) begin
		for (mm = 0; mm < 4; mm = mm + 1) begin
			buff[nn][mm] = nopi;
		end
	end
	count = 3'd0;
	got = 3'd0;
	ld = 1'b1;
end
else begin
	if (ld & en) begin
		got = 3'd0;
		for (nn = 0; nn < 4; nn = nn + 1) begin
			for (mm = 0; mm < 4; mm = mm + 1) begin
				buff[nn][mm] = nopi;
			end
		end
		case({ins_i[3].decbus.br,ins_i[2].decbus.br,ins_i[1].decbus.br,ins_i[0].decbus.br})
		// No branches, copy across and we're done.
		4'b0000:
			begin
				buff[0] = ins_i;
				count = 4'd1;
			end
		// One branch, slot 0
		4'b0001:
			begin
				buff[0][0] = ins_i[0];
				buff[1][1] = ins_i[1];
				buff[1][2] = ins_i[2];
				buff[1][3] = ins_i[3];
				count = 4'd2;
			end
		// One branch, slot 1
		4'b0010:
			begin
				buff[0][0] = ins_i[0];
				buff[0][1] = ins_i[1];
				buff[1][2] = ins_i[2];
				buff[1][3] = ins_i[3];
				count = 4'd2;
			end
		4'b0011:
			begin
				buff[0][0] = ins_i[0];
				buff[1][1] = ins_i[1];
				buff[2][2] = ins_i[2];
				buff[2][3] = ins_i[3];
				count = 4'd3;
			end
		4'b0100:
			begin
				buff[0][0] = ins_i[0];
				buff[0][1] = ins_i[1];
				buff[0][2] = ins_i[2];
				buff[1][3] = ins_i[3];
				count = 4'd2;
			end
		4'b0101:
			begin
				buff[0][0] = ins_i[0];
				buff[1][1] = ins_i[1];
				buff[1][2] = ins_i[2];
				buff[2][3] = ins_i[3];
				count = 4'd3;
			end
		4'b0110:
			begin
				buff[0][0] = ins_i[0];
				buff[0][1] = ins_i[1];
				buff[1][2] = ins_i[2];
				buff[2][3] = ins_i[3];
				count = 4'd3;
			end
		4'b0111:
			begin
				buff[0][0] = ins_i[0];
				buff[1][1] = ins_i[1];
				buff[2][2] = ins_i[2];
				buff[3][3] = ins_i[3];
				count = 4'd4;
			end
		4'b1000:
			begin
				buff[0][0] = ins_i[0];
				buff[0][1] = ins_i[1];
				buff[0][2] = ins_i[2];
				buff[1][3] = ins_i[3];
				count = 4'd2;
			end
		4'b1001:
			begin
				buff[0][0] = ins_i[0];
				buff[1][1] = ins_i[1];
				buff[1][2] = ins_i[2];
				buff[1][3] = ins_i[3];
				count = 4'd2;
			end
		4'b1010:
			begin
				buff[0][0] = ins_i[0];
				buff[0][1] = ins_i[1];
				buff[1][2] = ins_i[2];
				buff[2][3] = ins_i[3];
				count = 4'd3;
			end
		4'b1011:
			begin
				buff[0][0] = ins_i[0];
				buff[1][1] = ins_i[1];
				buff[2][2] = ins_i[2];
				buff[3][3] = ins_i[3];
				count = 4'd4;
			end
		4'b1100:
			begin
				buff[0][0] = ins_i[0];
				buff[0][1] = ins_i[1];
				buff[0][2] = ins_i[2];
				buff[1][3] = ins_i[3];
				count = 4'd2;
			end
		4'b1101:
			begin
				buff[0][0] = ins_i[0];
				buff[1][1] = ins_i[1];
				buff[1][2] = ins_i[2];
				buff[2][3] = ins_i[3];
				count = 4'd3;
			end
		4'b1110:
			begin
				buff[0][0] = ins_i[0];
				buff[0][1] = ins_i[1];
				buff[1][2] = ins_i[2];
				buff[2][3] = ins_i[3];
				count = 4'd3;
			end
		4'b1111:
			begin
				buff[0][0] = ins_i[0];
				buff[1][1] = ins_i[1];
				buff[2][2] = ins_i[2];
				buff[3][3] = ins_i[3];
				count = 4'd4;
			end
		endcase
	end
	if (get) begin
		if (got==count)
			ins_o = buff[4];
		else begin
			ins_o = buff[got];
			got = got + 3'd1;
		end
	end

	ld = got==count;
	stall = got != count; 
	if (ld & en) got = 3'd0;
end

endmodule
