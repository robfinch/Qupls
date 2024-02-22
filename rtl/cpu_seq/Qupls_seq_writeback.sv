// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2024  Robert Finch, Waterloo
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

import const_pkg::*;
import fta_bus_pkg::*;
import Qupls_cache_pkg::*;
import QuplsMmupkg::*;
import QuplsPkg::*;

module Qupls_seq_writeback(rst, clk, state, next_state, db,
	alu_res, fpu_res, dram_bus, pc, fpu_done, div_done, mul_done, rfwr, res);
input rst;
input clk;
input e_seq_state state;
output e_seq_state next_state;
input decode_bus_t db;
input value_t alu_res;
input value_t fpu_res;
input value_t dram_bus;
input pc_address_t pc;
input fpu_done;
input div_done;
input mul_done;
output reg rfwr;
output value_t res;

always_ff @(posedge clk)
if (rst) begin
	next_state <= IFETCH;
	res <= 64'd0;
	rfwr <= FALSE;
end
else begin
	rfwr <= FALSE;
	if (state==QuplsPkg::WRITEBACK) begin
		next_state <= state;
		if (db.alu) begin
			rfwr <= !db.Rtz;
			case({db.Rtn,db.bitwise})
			2'b00:	res <= alu_res;
			2'b01:	res <= alu_res;
			2'b10:	res <= -alu_res;
			2'b11:	res <= ~alu_res;
			endcase
		end
		else if (db.load) begin
			rfwr <= !db.Rtz;
			case({db.Rtn,db.bitwise})
			2'b00:	res <= dram_bus;
			2'b01:	res <= dram_bus;
			2'b10:	res <= -dram_bus;
			2'b11:	res <= ~dram_bus;
			endcase
		end
		else if (db.cjb) begin
			rfwr <= !db.Rtz;
			res <= pc + 4'd6;
		end
		else if (db.bts==BTS_RET) begin
			rfwr <= !db.Rtz;
			case({db.Rtn,db.bitwise})
			2'b00:	res <= alu_res;
			2'b01:	res <= alu_res;
			2'b10:	res <= -alu_res;
			2'b11:	res <= ~alu_res;
			endcase
		end
		if (db.div) begin
			if (div_done)
				next_state <= IFETCH;
		end
		else if (db.mul) begin
			if (mul_done)
				next_state <= IFETCH;
		end
		else if(db.fpu) begin
			if (fpu_done) begin
				next_state <= IFETCH;
				rfwr <= !db.Rtz;
				case({db.Rtn,db.bitwise})
				2'b00:	res <= fpu_res;
				2'b01:	res <= fpu_res;
				2'b10:	res <= {~fpu_res[$bits(value_t)-1],fpu_res[$bits(value_t)-2:0]};
				2'b11:	res <= ~fpu_res;
				endcase
			end
		end
		else
			next_state <= IFETCH;
	end
end

endmodule
