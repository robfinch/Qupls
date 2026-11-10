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
// 46500 LUTs / 11500 FFs / 210 DSPs (quad supported + prec)
// 10200 LUTs / 4020 FFs / 70 DSPs (no quad or prec, 64-bit fp only)
// ============================================================================

import const_pkg::*;
import capability_t::*;
import Qupls5_pkg::*;

module Qupls5_expipe6(rst, clk, idle, stomp, rse_i, rse_o,
	z, cptgt, o, o_flags, csr, we_o, exc,
	fcu_rse, takb, fcu_adr, done);
parameter WID=256;
parameter PIPE = 3'd6;
input rst;
input clk;
input idle;
input Qupls5_pkg::rob_bitmask_t stomp;
input Qupls5_pkg::cap_reservation_station_entry_t rse_i;
output Qupls5_pkg::cap_reservation_station_entry_t rse_o;
input z;
input [WID-1:0] cptgt;
input uc64_capability_t csr;
output reg [WID-1:0] o;
output cpu_types_pkg::flags_t o_flags;
output reg [WID/8:0] we_o;
output Qupls5_pkg::cause_code_t exc;
output Qupls5_pkg::reservation_station_entry_t fcu_rse;
output takb;
output cpu_types_pkg::value_t fcu_adr;

integer n;
Qupls5_pkg::reservation_station_entry_t rse1,rse2;
Qupls5_pkg::operating_mode_t om;
Qupls5_pkg::micro_op_t ir;
uc64_capability_t a;
uc64_capability_t b;
uc64_capability_t c;
uc64_capability_t t;
cpu_types_pkg::value_t gpra, gprb;
aregno_t aRd_i;
reg [1:0] stomp_con;	// stomp conveyor
reg [WID/8:0] we,we1,we2;
wire [WID-1:0] alu_o64, alu_o64d, fma_o64;
wire [127:0] alu_o;
wire [WID/8:0] alu_we;
wire [WID-1:0] alu_exc;
reg [WID/8-1:0] exc_mask;

cpu_types_pkg::address_t as, bs;
cpu_types_pkg::address_t res1;
reg [5:0] shift;

always_comb om = rse_i.om;
always_comb ir = rse_i.uop;
always_comb a = rse_i.arg[0].val;
always_comb b = rse_i.arg[1].val;
always_comb c = rse_i.arg[2].val;
always_comb t = rse_i.arg[4].val;
always_comb gpra = rse_i.gpr_arg[0].val;
always_comb gprb = rse_i.gpr_arg[1].val;
always_comb aRd_i = rse_i.aRd;

Qupls5_pkg::cause_code_t exc128,exc64;
reg [WID-1:0] o1;
wire [WID-1:0] o16, o32, o64, o128;
wire [WID-1:0] sto64;
wire [0:0] ust64;
wire [7:0] sr64, sr128;
reg done16, done32, done64, done128;
reg alu_did_op, alu_did_opd;
wire [8:0] fcu_we;
genvar g,mm;

always_ff @(posedge clk) 
	rse_o <= rse_i;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// FCU logic
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

generate begin : gFCU
	if (PIPE==3'd1 ? SUPPORT_BRANCH1 : SUPPORT_BRANCH0)
Qupls5_meta_fcu ufcu1
(
	.rst(rst),
	.clk(clk),
	.rse_i(rse_i),
	.rse_o(fcu_rse),
	.sr(sr),
	.ic_irq(ic_irq),
	.irq_sn(irq_sn),
	.takb(takb),
	.res(fcu_adr),
	.we_o(fcu_we)
);
else begin
	assign fcu_rse = {$bits(Qupls5_pkg::cap_reservation_station_entry_t){1'b0}};
	assign fcu_adr = 64'd0;
	assign fcu_we = 9'd0;
	assign takb = 1'b0;
end
end
endgenerate

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Qupls5_capu ucapu1
(
	.rst(rst),
	.clk(clk),
	.ir(ir),
	.ip(rse_i.pc),
	.ac(a),
	.bc(b),
	.ac_flags(a_flags),
	.bc_flags(b_flags),
	.agp(gpra),
	.bgp(gprb),
	.o(capu_o),
	.o_flags(capu_flags_o),
	.excv(excv),
	.exc(exc),
	.done(done)
);

// Copy only the lanes specified in the mask to the target.

generate begin : gCptgt
	for (mm = 0; mm < 32; mm = mm + 1) begin
    always_comb
    	if (stomp_con[1]||rse2.uop.opcode==Qupls5_pkg::OP_NOP)
        o[mm*8+7:mm*8] = t[mm*8+7:mm*8];
//      else if (cptgt[mm])
//        o[mm*8+7:mm*8] = z ? 8'h00 : t[mm*8+7:mm*8];
      else
        o[mm*8+7:mm*8] = capu_o[mm*8+7:mm*8];
    end
end
endgenerate

always_ff @(posedge clk)
	we = {33{rse_i.we}};

always_ff @(posedge clk)
begin
	if (~|aRd_i || stomp[rse_i.rndx])
		stomp_con[0] <= 1'b1;
	else
		stomp_con[0] <= 1'b0;
	if (stomp[rse1.rndx])
		stomp_con[1] <= 1'b1;
	else
		stomp_con[1] <= stomp_con[0];
end

always_comb
	we_o = rse_o.v ? we & 33'h1ffffffff : 33'h000000000;

endmodule
