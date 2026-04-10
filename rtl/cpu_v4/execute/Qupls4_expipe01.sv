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
import Qupls4_pkg::*;

module Qupls4_expipe01(rst, clk, clk3x, idle, stomp, rse_i, rse_o, rm,
	z, cptgt, o, csr, cpl, canary, sto, ust, otag, we_o, exc,
	tlb_v, adr, adrv, agen_rse,
	fcu_rse, sr, ic_irq, irq_sn, takb, fcu_adr);
parameter WID=Qupls4_pkg::SUPPORT_QUAD_PRECISION|Qupls4_pkg::SUPPORT_CAPABILITIES ? 128 : 64;
parameter PIPE = 3'd0;
input rst;
input clk;
input clk3x;
input idle;
input Qupls4_pkg::rob_bitmask_t stomp;
input Qupls4_pkg::reservation_station_entry_t rse_i;
output Qupls4_pkg::reservation_station_entry_t rse_o;
input [2:0] rm;
input z;
input [WID-1:0] cptgt;
input [WID-1:0] csr;
input [7:0] cpl;
input [WID-1:0] canary;
output reg [WID-1:0] o;
output reg otag;
output reg [WID-1:0] sto;
output reg ust;
output reg [WID/8:0] we_o;
output Qupls4_pkg::cause_code_t exc;
input tlb_v;
output cpu_types_pkg::address_t adr;
output reg adrv;
output Qupls4_pkg::reservation_station_entry_t agen_rse;
output Qupls4_pkg::reservation_station_entry_t fcu_rse;
input status_reg_t sr;
input [5:0] ic_irq;
input [7:0] irq_sn;
output takb;
output cpu_types_pkg::value_t fcu_adr;

Qupls4_pkg::reservation_station_entry_t rse1,rse2;
Qupls4_pkg::operating_mode_t om;
Qupls4_pkg::micro_op_t ir;
reg [WID-1:0] a;
reg [WID-1:0] b,bi;
reg [WID-1:0] c;
reg [WID-1:0] t;
reg [WID-1:0] s;
reg [WID-1:0] i;
aregno_t aRd_i;
reg [1:0] stomp_con;	// stomp conveyor
reg [WID/8:0] we,we1,we2;
wire [WID-1:0] alu_o64, alu_o64d, fma_o64;
wire [127:0] alu_o;
wire [WID/8:0] alu_we;
wire [WID/8-1:0] alu_exc;
Qupls4_pkg::memsz_t prc;

cpu_types_pkg::address_t as, bs;
cpu_types_pkg::address_t res1;
reg [5:0] shift;

always_comb om = rse_i.om;
always_comb ir = rse_i.uop;
always_comb a = rse_i.arg[0].val;
always_comb b = rse_i.arg[1].val;
always_comb c = rse_i.arg[2].val;
always_comb t = rse_i.arg[4].val;
always_comb s = rse_i.arg[5].val;
always_comb i = rse_i.argI;
always_comb bi = rse_i.arg[1].val|rse_i.argI;
always_comb aRd_i = rse_i.aRd;
always_comb prc = Qupls4_pkg::memsz_t'(rse_i.prc);

Qupls4_pkg::cause_code_t exc128,exc64;
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
// AGEN logic
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

reg resv1;

/*
always_ff @(posedge clk)
	rse2 <= rse1;
always_comb
	rse_o = rse2;
*/
generate begin : gAgen
	if (PIPE==3'd4 || PIPE==3'd5) begin
always_ff @(posedge clk)
	as <= rse_i.Rs1z ? value_zero : rse_i.Rs1ip ? rse_i.pc : rse_i.arg[0].val;

always_ff @(posedge clk)
	bs <= rse_i.Rs2z ? value_zero : (rse_i.arg[1].val * ({rse_i.uop.sc==3'd0,rse_i.uop.sc}));

always_comb
	case(rse_i.velesz)
	2'd0:	shift = {rse_i.laneno,3'd0};
	2'd1:	shift = {rse_i.laneno,4'd0};
	2'd2:	shift = {rse_i.laneno,5'd0};
	2'd3:	shift = 6'd0;
	endcase

always_comb
begin
	if (rse1.vlsndx)
		res1 = as + (bs >> shift) + rse1.argI;
	else if (rse1.amo)
		res1 = as;				// just [Rs1]
	// Lane number is 1 for non-vector load/store
	else if (rse1.load|rse1.store)
		res1 = as + bs * rse1.laneno + rse1.argI;
	else
		res1 = 64'd0;
end

always_ff @(posedge clk)
	if (resv1)
		adr <= res1;

always_ff @(posedge clk)
	if (rse1.vlsndx|rse1.amo|rse1.load|rse1.store)
		agen_rse <= rse1;

// Make Agen valid sticky
// The agen takes a clock cycle to compute after the out signal is valid.
always_ff @(posedge clk) 
if (rst) begin
	resv1 <= INV;
end
else begin
	if (rse_i.vlsndx|rse_i.amo|rse_i.load|rse_i.store)
		resv1 <= VAL;
	if (tlb_v)
		resv1 <= INV;
end

always_ff @(posedge clk) 
if (rst)
	adrv <= INV;
else begin
	adrv <= resv1;
	if (tlb_v)
		adrv <= INV;
end

end
end
endgenerate

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// FCU logic
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

always_comb
	if (SUPPORT_BRANCH0==0 && SUPPORT_BRANCH1==0) begin
		$display("Qupls4 CPU: At least one unit must have branch logic.");
		$finish;
	end

generate begin : gFCU
	if (PIPE==3'd1 ? SUPPORT_BRANCH1 : SUPPORT_BRANCH0)
Qupls4_meta_fcu ufcu1
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
	assign fcu_rse = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	assign fcu_adr = 64'd0;
	assign fcu_we = 9'd0;
	assign takb = 1'b0;
end
end
endgenerate

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Qupls4_meta_alu #(.PIPE(PIPE)) umalu1
(
	.rst(rst),
	.clk(clk),
	.rse_i(rse_i),
	.rse_o(),
	.lane(rse_i.uop.num),
	.cptgt(8'h00),
	.z(1'b0),
	.stomp(stomp),
	.qres(),
	.cs(),
	.csr(csr),
	.cpl(cpl),
	.canary(canary),
	.o(alu_o),
	.cp_o(),
	.we_o(alu_we),
	.exc(alu_exc),
	.fcu_rse_o(),
	.sr(64'd0),
	.ic_irq(6'd0),
	.irq_sn(8'h00),
	.takb(),
	.adr()
);

always_comb
	o1 = alu_o;

// Copy only the lanes specified in the mask to the target.

generate begin : gCptgt
	for (mm = 0; mm < WID/8; mm = mm + 1) begin
    always_comb
    	if (stomp_con[1]||rse2.uop.opcode==Qupls4_pkg::OP_NOP)
        o[mm*8+7:mm*8] = t[mm*8+7:mm*8];
//      else if (cptgt[mm])
//        o[mm*8+7:mm*8] = z ? 8'h00 : t[mm*8+7:mm*8];
      else
        o[mm*8+7:mm*8] = o1[mm*8+7:mm*8];
    end
end
endgenerate

always_ff @(posedge clk)
	we = {9{rse_i.we}};

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
	we_o = rse_o.v ? we|fcu_we : 9'h000;

always_comb
	exc = cause_code_t'(alu_exc);

endmodule
