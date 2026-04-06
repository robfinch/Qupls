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
	z, cptgt, o, csr, cpl, canary, sto, ust, otag, we_o, done, exc,
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
output reg done;
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
reg [1:0] prc;
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

generate begin : gFCU
	if (PIPE==3'd1)
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
end
	assign fcu_rse = {$bits(Qupls4_pkg::reservation_station_entry_t){1'b0}};
	assign fcu_adr = 64'd0;
	assign fcu_we = 9'd0;
	assign takb = 1'b0;
end
endgenerate

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

generate begin : gPrec
if (Qupls4_pkg::SUPPORT_PREC) begin
for (g = 0; g < WID/64; g = g + 1)
	Qupls4_alu #(
		.WID(64), .PIPE(PIPE)
	) ualu4
	(
		.rst(rst),
		.clk(clk),
		.clk2x(clk3x),
		.chunk(rse_i.uop.num),
		.om(rse_i.om),
		.ld(),
		.ir(ir),
		.div(1'b0),
		.Ra(),
		.a(a[g*64+63:g*64]),
		.b(b[g*64+63:g*64]),
		.c(c[g*64+63:g*64]),
		.t(t[g*64+63:g*64]),
		.bi(bi[g*64+63:g*64]),
		.i(i),
		.qres(),
		.mask(c), 
		.cs(),
		.pc(64'd0),
		.pcc(128'd0),
		.csr(csr),
		.cpl(cpl),
		.coreno(64'd0),
		.canary(canary),
		.velsz(velsz),
		.o(alu_o64),
		.exc_o(),
		.did_op(did_op)
	);
end
else begin
	for (g = 0; g < WID/64; g = g + 1) begin
	Qupls4_alu #(
		.WID(64), .PIPE(PIPE)
	)
	ualu4
	(
		.rst(rst),
		.clk(clk),
		.clk2x(clk3x),
		.chunk(rse_i.uop.num),
		.om(rse_i.om),
		.ld(),
		.ir(ir),
		.div(1'b0),
		.Ra(),
		.a(a[g*64+63:g*64]),
		.b(b[g*64+63:g*64]),
		.c(c[g*64+63:g*64]),
		.t(t[g*64+63:g*64]),
		.bi(bi[g*64+63:g*64]),
		.i(i),
		.qres(),
		.mask(c), 
		.cs(),
		.pc(64'd0),
		.pcc(128'd0),
		.csr(csr),
		.cpl(cpl),
		.coreno(64'd0),
		.canary(canary),
		.velsz(velsz),
		.o(alu_o64),
		.exc_o(),
		.did_op(did_op)
	);
	if (PIPE==3'd3 || PIPE==3'd4)
	fpFMA64LN ufma64 (
		.clk(clk),
		.op(ir[30]),		// 0=add,1=sub c
		.rm(rse_i.rm),
		.a(a[g*64+63:g*64]),
		.b(b[g*64+63:g*64]),
		.c(c[g*64+63:g*64]),
		.o(fma_o64[g*64+63:g*64]),
		.inf(),
		.zero(), 
		.overflow(),
		.underflow(),
		.inexact()
	);
end
end
end
endgenerate

always_comb
if (Qupls4_pkg::SUPPORT_PREC)
	case(prc)
	2'd0:	o1 = o16;
	2'd1:	o1 = o32;
	2'd2:	o1 = o64;
	2'd3:	o1 = o128;
	endcase
else if (Qupls4_pkg::SUPPORT_CAPABILITIES)
	o1 = o128;
else begin
	done64 = FALSE;
	case(ir.opcode)
	Qupls4_pkg::OP_FLTH,Qupls4_pkg::OP_FLTS,Qupls4_pkg::OP_FLTD,
	Qupls4_pkg::OP_FLTPH,Qupls4_pkg::OP_FLTPS,Qupls4_pkg::OP_FLTPD,
	Qupls4_pkg::OP_FLTVVV,Qupls4_pkg::OP_FLTVVS:
		case(ir.func)
		Qupls4_pkg::FLT_FMA,Qupls4_pkg::FLT_FMS,Qupls4_pkg::FLT_FNMA,Qupls4_pkg::FLT_FNMS:
			begin
				o1 = fma_o64;
				done64 = TRUE;
			end
		default:
			begin
				o1 = alu_o64d;
				done64 = alu_did_opd;
			end
		endcase
	Qupls4_pkg::OP_LDB,Qupls4_pkg::OP_LDBZ,Qupls4_pkg::OP_LDW,Qupls4_pkg::OP_LDWZ,
	Qupls4_pkg::OP_LDT,Qupls4_pkg::OP_LDTZ,Qupls4_pkg::OP_LOAD,
	Qupls4_pkg::OP_STB,Qupls4_pkg::OP_STW,
	Qupls4_pkg::OP_STT,Qupls4_pkg::OP_STORE,
	Qupls4_pkg::OP_STI,
	Qupls4_pkg::OP_STPTR,
	Qupls4_pkg::OP_V2P,
	Qupls4_pkg::OP_VV2P,
	Qupls4_pkg::OP_AMO:
		done64 = FALSE;
	default:
		begin
			o1 = alu_o64;
			done64 = alu_did_op;
		end
	endcase
end

always_comb done16 = TRUE;
always_comb done32 = TRUE;
always_comb done128 = TRUE;

// Copy only the lanes specified in the mask to the target.

generate begin : gCptgt
	for (mm = 0; mm < WID/8; mm = mm + 1) begin
    always_comb
    	if (stomp_con[1]||rse2.uop.opcode==Qupls4_pkg::OP_NOP)
        o[mm*8+7:mm*8] = t[mm*8+7:mm*8];
      else if (cptgt[mm])
        o[mm*8+7:mm*8] = z ? 8'h00 : t[mm*8+7:mm*8];
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
if (Qupls4_pkg::SUPPORT_PREC)
	case(prc)
	2'd0:	done = done16;
	2'd1:	done = done32;
	2'd2:	done = done64|fcu_rse.v;
	2'd3: done = done128;
	endcase
else if (Qupls4_pkg::SUPPORT_CAPABILITIES)
	done = done128;
else
	done = done64|fcu_rse.v;
//	done = ~sr64[6];
always_comb
	exc = exc64;

endmodule
