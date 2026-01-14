// ============================================================================
//        __
//   \\__/ o\    (C) 2026  Robert Finch, Waterloo
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
import Qupls4_pkg::*;


module Qupls4_meta_fcu(rst, clk, rse_i, rse_o, sr, ic_irq, irq_sn, takb, res, we_o);
parameter WID = 64;
input rst;
input clk;
input Qupls4_pkg::reservation_station_entry_t rse_i;
output Qupls4_pkg::reservation_station_entry_t rse_o;
input status_reg_t sr;
input [5:0] ic_irq;
input [7:0] irq_sn;
output takb;
output cpu_types_pkg::value_t res;
output reg [8:0] we_o;

reg [WID-1:0] a;
reg [WID-1:0] b;
reg [WID-1:0] c;
reg [WID-1:0] i;
reg [WID-1:0] t;
cpu_types_pkg::pc_address_t pc;
Qupls4_pkg::micro_op_t ir;

always_comb ir = rse_i.uop;
always_comb a = rse_i.arg[0].val;
always_comb b = rse_i.arg[1].val;
always_comb c = rse_i.arg[2].val;
always_comb t = rse_i.arg[3].val;
always_comb i = rse_i.argI;
always_comb pc = rse_i.pc;

Qupls4_meta_branch_eval ube1
(
	.rst(rst),
	.clk(clk),
	.instr(ir),
	.a(a),
	.b(b),
	.c(ic_irq > sr.ipl && sr.mie && irq_sn!=rse_i.irq_sn || ic_irq==6'd63),
	.takb(takb)
);

always_comb
	case(1'b1)
	rse_i.bsr:	res = rse_i.pc.pc + 4'd6;
	rse_i.jsr:	res = rse_i.pc.pc + 4'd6;
	rse_i.cjb:	res = rse_i.pc.pc + 4'd6;
	rse_i.ibcc:	res = a + 2'd1;		// destination is Rs1
	rse_i.dbcc:	res = a - 2'd1;		// destination is Rs1
	rse_i.ret:	res = t + i;			// destination is Rd	(SP)
	default:	res = value_zero;
	endcase

always_ff @(posedge clk)
	rse_o <= rse_i;

always_ff @(posedge clk)
begin
	case(1'b1)
	rse_i.ibcc:	we_o <= {9{TRUE}};
	rse_i.dbcc:	we_o <= {9{TRUE}};
	rse_i.ret:	we_o <= {9{TRUE}};
	rse_i.bsr:	we_o <= {9{rse_i.aRdv}};
	rse_i.jsr:	we_o <= {9{rse_i.aRdv}};
	rse_i.cjb:	we_o <= {9{rse_i.aRdv}};
	default:	we_o <= {9{FALSE}};
	endcase
end

endmodule

