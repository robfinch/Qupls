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
// 3100 LUTs / 3600 FFs / 19 DSPs
// ============================================================================

import const_pkg::*;
import Qupls5_pkg::*;

module Qupls5_expipe45(rst, clk, clk3x, idle, stomp, rse_i, rse_o, rm, ddc,
	z, cptgt, o, sto, ust, otag, we_o, done, exc,
	tlb_v, adr, adrv, agen_rse,
	mem_rse_i, mem_done_i, mem_res_i, mem_flags_i);
parameter SUPPORT_CAPABILITIES = Qupls5_pkg::SUPPORT_CAPABILITIES;
parameter SUPPORT_VECTOR = Qupls5_pkg::SUPPORT_VECTOR;
parameter SUPPORT_GRAPHICS = Qupls5_pkg::SUPPORT_GRAPHICS;
parameter WID=Qupls5_pkg::SUPPORT_QUAD_PRECISION|Qupls5_pkg::SUPPORT_CAPABILITIES ? 128 : 64;
parameter PIPE = 3'd4;
parameter SUPPORT_ISQRT = (PIPE==3'd4 && Qupls5_pkg::SUPPORT_ISQRT4) || (PIPE==3'd5 && Qupls5_pkg::SUPPORT_ISQRT5);
parameter SUPPORT_FMA = (PIPE==3'd4 && Qupls5_pkg::SUPPORT_FMA4) || (PIPE==3'd5 && Qupls5_pkg::SUPPORT_FMA5);
parameter SUPPORT_IDIV = (PIPE==3'd4 && Qupls5_pkg::SUPPORT_IDIV4) || (PIPE==3'd5 && Qupls5_pkg::SUPPORT_IDIV5);
input rst;
input clk;
input clk3x;
input idle;
input Qupls5_pkg::rob_bitmask_t stomp;
input Qupls5_pkg::reservation_station_entry_t rse_i;
output Qupls5_pkg::reservation_station_entry_t rse_o;
input [2:0] rm;
input uc64_capability_t ddc;
input z;
input [WID-1:0] cptgt;
output reg [WID-1:0] o;
output reg otag;
output reg [WID-1:0] sto;
output reg ust;
output reg [WID/8:0] we_o;
output reg done;
output Qupls5_pkg::cause_code_t exc;
input tlb_v;
output cpu_types_pkg::address_t adr;
output reg adrv;
output Qupls5_pkg::reservation_station_entry_t agen_rse;
input Qupls5_pkg::reservation_station_entry_t mem_rse_i;
input mem_done_i;
input [WID-1:0] mem_res_i;
input cpu_types_pkg::flags_t mem_flags_i;

integer n;
Qupls5_pkg::reservation_station_entry_t rse1,rse2;
Qupls5_pkg::operating_mode_t om;
Qupls5_pkg::memsz_t prc,prc5;
Qupls5_pkg::micro_op_t ir,ir5;
reg [WID-1:0] a;
reg [WID-1:0] b,bi;
reg [WID-1:0] c;
reg [WID-1:0] d;
reg [WID*4-1:0] lastarg, lastargd;
reg [WID-1:0] t;
reg [WID-1:0] s;
reg [WID-1:0] i;
aregno_t aRd_i;
reg [1:0] stomp_con;	// stomp conveyor
reg [WID/8:0] we,we1,we2;
wire [WID-1:0] alu_o64, alu_o64d, fma_o64, fma_o16, fma_o32;
wire [WID-1:0] isqrt_o, idiv_o, tex_o;
wire [WID/8:0] alu_we, isqrt_we, idiv_we;
wire [WID-1:0] alu_exc, div_exc;
reg [WID/8-1:0] exc_mask;
reg idiv_ld, tex_ld;
wire idiv_done, tex_done1;
reg tex_done;

reg excv = INV;
cpu_types_pkg::address_t as, bs, bsv;
cpu_types_pkg::address_t res1;
reg [63:0] base;
reg [64:0] top;
reg [5:0] shift;
reg [4:0] state;

always_ff @(posedge clk)
if (rst) begin
	state <= 5'd0;
	done <= TRUE;
	rse_o <= {$bits(reservation_station_entry_t){1'b0}};
end
else begin
	case(state)
	5'd0:
		if (rse_i.v) begin
			state <= 5'd1;
			rse_o <= rse_i;
			done <= FALSE;
		end
	5'd1:
		state <= 5'd2;
	5'd2:
		begin
			if (rse_i.mem) begin
				if (mem_done_i)
					done <= TRUE;
					state <= 5'd7;
			end
			else begin
				state <= 5'd3;
			end
		end
	5'd3:
		state <= 5'd4;
	5'd4:
		state <= 5'd5;
	5'd5:
		state <= 5'd6;
	5'd6:
		begin
			done <= TRUE;
			state <= 5'd7;
		end
	// Wait a couple of clock cycles after done asserted for rse to clear.
	5'd7:	state <= 5'd8;
	5'd8:
		begin
			state <= 5'd9;
			rse_o <= {$bits(reservation_station_entry_t){1'b0}};
		end
	5'd9:	state <= 5'd0;
	default:	state <= 5'd0;
	endcase
end


always_ff @(posedge clk)
	lastarg <= {a,b,bi,c};
always_ff @(posedge clk)
	lastargd <= {a,b,c,d};
always_ff @(posedge clk)
	idiv_ld <= lastarg != {a,b,bi,c};
always_ff @(posedge clk)
	tex_ld <= lastargd != {a,b,c,d};
	
always_comb om = rse_o.om;
always_comb ir = rse_o.uop;
always_comb a = rse_o.arg[0].val;
always_comb b = rse_o.arg[1].val;
always_comb c = rse_o.arg[2].val;
always_comb d = rse_o.arg[3].val;
always_comb t = rse_o.arg[4].val;
always_comb s = rse_o.arg[5].val;
always_comb i = rse_o.argI;
always_comb bi = rse_o.arg[1].val|rse_o.argI;
always_comb aRd_i = rse_o.aRd;
always_comb prc = rse_o.prc;

reg [WID/8-1:0] exc128,exc64;
reg [WID-1:0] o1;
wire [WID-1:0] o16, o32, o64, o128;
wire [WID-1:0] sto64;
wire [0:0] ust64;
wire [7:0] sr64, sr128;
reg done16, done32, done64, done128;
wire isqrt_done;
wire alu_did_op, alu_did_opd;
genvar g,mm;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// AGEN logic
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

reg resv1;
reg [23:0] perms;
reg tags_bad;

always_ff @(posedge clk) 
	rse1 <= rse_o;
always_ff @(posedge clk)
	rse2 <= rse1;
always_comb
	rse_o = rse2;

//generate begin : gAgen
//	if (PIPE==3'd4 || PIPE==3'd5) begin
always_ff @(posedge clk)
casez({rse_o.pc.cap.flags[0] || !SUPPORT_CAPABILITIES,rse_o.uop.iprel,rse_o.Rs1z})
3'b??1:	as <= value_zero;
3'b?10:	as <= rse_o.pc.cap.offset + rse_o.pc.cap.base;
3'b100:	as <= rse_o.arg[0].val + ddc.base;
3'b000:	as <= rse_o.cap_arg.val.offset + rse_o.cap_arg.val.base;
endcase

reg [8:0] scale;
always_comb
	scale = 9'd1 << rse_o.uop.sc;
always_ff @(posedge clk)
	bs <= rse_o.Rs2z ? value_zero : (rse_o.arg[1].val * scale[8:1]);

// imm2 = vlen
always_ff @(posedge clk)
	bsv <= rse_o.Rs2z ? value_zero : (rse_o.arg[1].val * {rse_o.uop.vlen,3'b0});

always_ff @(posedge clk)
	base <= rse_o.Rs1z ? 64'd0 : rse_o.pc.cap.flags[0] || !SUPPORT_CAPABILITIES ? ddc.base : rse_o.cap_arg.val.base;
always_ff @(posedge clk)
	top <= rse_o.Rs1z ? 65'h10000000000000000 : rse_o.pc.cap.flags[0] || !SUPPORT_CAPABILITIES  ? ddc.top : rse_o.cap_arg.val.top;
always_ff @(posedge clk)
	perms <= rse_o.Rs1z ? 24'h0 : rse_o.pc.cap.flags[0] || !SUPPORT_CAPABILITIES  ? ddc.perms : rse_o.cap_arg.val.perms;
always_ff @(posedge clk)
	tags_bad <= !rse_o.cap_arg.flags.cap || rse_o.arg[2].flags.cap;

always_comb
	case(rse1.velesz)
	2'd0:	shift = {rse1.laneno,3'd0};
	2'd1:	shift = {rse1.laneno,4'd0};
	2'd2:	shift = {rse1.laneno,5'd0};
	2'd3:	shift = 6'd0;
	endcase

always_comb
begin
	// Vector indexed vector load / store.
	if (SUPPORT_VECTOR && rse1.vlsndx)
		res1 = as + (bs >> shift) + rse1.argI;
	// A vector load/store address is calculated almost the same way as an
	// ordinary load/store except that the offset associated with the set
	// of lanes to load/store must be added in. This is done when the 
	// micro-op is built by modifying the immediate constant.
	else if (SUPPORT_VECTOR && rse1.vls)
		res1 = as + bsv + rse1.argI;
	else if (rse1.amo)
		res1 = as;				// just [Rs1]
	// Lane number is 1 for non-vector load/store
	else if (rse1.load|rse1.store)
		res1 = as + bs + rse1.argI;
	else
		res1 = 64'd0;
end


always_ff @(posedge clk)
	if (resv1)
		adr <= res1;

always_ff @(posedge clk)
if (rst) begin
	excv <= INV;
	exc <= Qupls5_pkg::FLT_NONE;
	agen_rse <= {$bits(Qupls5_pkg::reservation_station_entry_t){1'b0}};
end
else begin
	if (rse1.vlsndx|rse1.vls|rse1.amo|rse1.load|rse1.store) begin
		agen_rse <= rse1;
		excv <= INV;
		exc <= Qupls5_pkg::FLT_NONE;
		// If Rs1 is not a capability, or if Rs2 is)
		if (tags_bad) begin
			excv <= VAL;
			exc <= Qupls5_pkg::FLT_CTAG;
			agen_rse.excv <= VAL;
			agen_rse.exc <= Qupls5_pkg::FLT_CTAG;
		end
		else if (res1 < base || res1 >= top) begin
			excv <= VAL;
			exc <= Qupls5_pkg::FLT_CBOUNDS;
			agen_rse.excv <= VAL;
			agen_rse.exc <= Qupls5_pkg::FLT_CBOUNDS;
		end
		else if ((rse1.load && !perms[2]) || (rse1.store && !perms[3])) begin	// permit load(2) or store(3)
			excv <= VAL;
			exc <= Qupls5_pkg::FLT_CPERMS;
			agen_rse.excv <= VAL;
			agen_rse.exc <= Qupls5_pkg::FLT_CPERMS;
		end
	end
end

// Make Agen valid sticky
// The agen takes a clock cycle to compute after the out signal is valid.
always_ff @(posedge clk) 
if (rst) begin
	resv1 <= INV;
end
else begin
	if (rse_o.vlsndx|rse_o.vls|rse_o.amo|rse_o.load|rse_o.store)
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

//end
//end
//endgenerate

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Qupls5_meta_alu #(.PIPE(PIPE)) umalu1
(
	.rst(rst),
	.clk(clk),
	.rse_i(rse_o),
	.rse_o(),
	.lane(rse_o.uop.num),
	.cptgt(8'h00),
	.z(1'b0),
	.stomp(stomp),
	.qres(),
	.cs(),
	.csr(csr),
	.cpl(cpl),
	.canary(canary),
	.o(alu_o64),
	.cp_o(),
	.we_o(alu_we),
	.exc(alu_exc),
	.fcu_rse_o(),
	.cr0(64'd0),
	.ic_irq(6'd0),
	.irq_sn(8'h00),
	.takb(),
	.adr()
);


generate begin : gPrec
if (Qupls5_pkg::SUPPORT_PREC) begin
		for (g = 0; g < WID/16; g = g + 1)
			if (PIPE==3'd3 || PIPE==3'd4)
			/*
			fpFMA16LN ufma16 (
				.clk(clk),
				.op(ir[30]),		// 0=add,1=sub c
				.rm(rse_o.rm),
				.a(a[g*16+15:g*16]),
				.b(b[g*16+15:g*16]),
				.c(c[g*16+15:g*16]),
				.o(fma_o16[g*16+15:g*16]),
				.inf(),
				.zero(), 
				.overflow(),
				.underflow(),
				.inexact()
			)
			*/
			;
			for (g = 0; g < WID/32; g = g + 1)
				if (SUPPORT_FMA)
				fpFMA32LN ufma32 (
					.clk(clk),
					.op(ir[30]),		// 0=add,1=sub c
					.rm(rse_o.rm),
					.a(a[g*32+31:g*32]),
					.b(b[g*32+31:g*32]),
					.c(c[g*32+31:g*32]),
					.o(fma_o32[g*32+31:g*32]),
					.inf(),
					.zero(), 
					.overflow(),
					.underflow(),
					.inexact()
				);
			for (g = 0; g < WID/64; g = g + 1)
				if (SUPPORT_FMA)
					fpFMA64LN ufma64 (
						.clk(clk),
						.op(ir[30]),		// 0=add,1=sub c
						.rm(rse_o.rm),
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
else begin
	for (g = 0; g < WID/64; g = g + 1) begin
	if (SUPPORT_FMA)
	fpFMA64LN ufma64 (
		.clk(clk),
		.op(ir[30]),		// 0=add,1=sub c
		.rm(rse_o.rm),
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

generate begin : gIDiv
if (SUPPORT_IDIV)
Qupls5_meta_idiv uidiv0
(
	.rst(irst),
	.clk(clk),
	.clk2x(clk3x),
	.ld(idiv_ld),
	.rse_i(rse_o),
	.rse_o(),
	.cptgt(8'h00),
	.z(1'b0),
	.o(idiv_o),
	.we_o(idiv_we),
	.div_done(idiv_done),
	.div_dbz(idiv_dbz),
	.exc(div_exc)
	/*
	.q_rst(q_rst),
	.q_trigger(q_trigger),
	.q_rd(q_rd),
	.q_wr(q_wr),
	.q_addr(q_addr),
	.q_rd_data(q_rd_data),
	.q_wr_data(q_wr_data)
	*/
);
else begin
	assign idiv0_done = TRUE;
	assign idiv0_dbz = FALSE;
	assign idiv0_res = value_zero;
	assign q_rst = 16'd0;
	assign q_trigger = 16'd0;
	assign q_rd = 16'd0;
	assign q_wr = 16'd0;
	assign q_addr = 16'd0;
	assign q_wr_data = 64'd0;
end
end
endgenerate

generate begin : gISqrt
if (SUPPORT_ISQRT)
	Qupls5_meta_isqrt uimul0
	(
		.rst(irst),
		.clk(clk),
		.stomp(stomp),
		.rse_i(rse_o),
		.rse_o(),
		.lane(rse_o.uop.num),
		.cptgt(cptgt),
		.z(1'b0),//isqrt_predz),
		.o(isqrt_o),
		.we_o(),
		.done(isqrt_done)
	);
else begin
	assign isqrt_we = FALSE;
	assign isqrt_res = value_zero;
end
end
endgenerate

generate begin : gGraphics
	if (SUPPORT_GRAPHICS) begin
		Qupls5_tex utex1
		(
			.clk(clk),
			.ce(TRUE),
			.a(a),
			.b(b),
			.c(c),
			.d(d),
			.o(tex_o)
		);
	ft_delay #(.WID(1), .DEP(24)) utex2 (.clk(clk), .ce(ce), .i(tex_ld), .o(tex_done1));
	Qupls5_blend ublend1
	(
		.a(a),
		.b(b),
		.c(c),
		.o(blend_o)
	);
end
end
endgenerate

always_comb
	tex_done = !tex_ld ? lastargd=={a,b,c,d} : tex_done1;

always_comb
begin
	done64 = FALSE;
	exc64 = {8{Qupls5_pkg::FLT_NONE}};
	case(ir.opcode)
	Qupls5_pkg::OP_PPC_ADDI,Qupls5_pkg::OP_PPC_ADDIS,
	Qupls5_pkg::OP_PPC_ANDI,Qupls5_pkg::OP_PPC_ANDIS,
	Qupls5_pkg::OP_PPC_ORI,Qupls5_pkg::OP_PPC_ORIS,
	Qupls5_pkg::OP_PPC_XORI,Qupls5_pkg::OP_PPC_XORIS:
		begin
			done64 = done;
			o1 = alu_o64;
		end
	Qupls5_pkg::OP_31:
		begin
			done64 = done;
			o1 = o64;
		end
	/*
	Qupls5_pkg::OP_DIVI,Qupls5_pkg::OP_DIVUI:
		if (SUPPORT_IDIV) begin
			o1 = idiv_o;
			done64 = idiv_done;
			exc64 = div_exc;
		end
		else begin
			o1 = value_zero;
			done64 = TRUE;
		end
	*/
	Qupls5_pkg::OP_PPC_LWZ:
		begin
			o1 = mem_res_i;
			done64 = done;
		end
	default:
		begin
			o1 = alu_o64d;
			done64 = alu_did_opd;
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
    	if (stomp_con[1]||rse_o.uop.opcode==Qupls5_pkg::fnNop())
        o[mm*8+7:mm*8] = t[mm*8+7:mm*8];
//      else if (cptgt[mm])
//        o[mm*8+7:mm*8] = z ? 8'h00 : t[mm*8+7:mm*8];
      else
        o[mm*8+7:mm*8] = o1[mm*8+7:mm*8];
    end
end
endgenerate

always_comb
	we = rse_o.vlsndx|rse_o.vls ? {rse_o.uop.ble & {9{rse_o.we}}} : {9{rse_o.we}};

always_ff @(posedge clk)
begin
	if (~|aRd_i || stomp[rse_o.rndx])
		stomp_con[0] <= 1'b1;
	else
		stomp_con[0] <= 1'b0;
	if (stomp[rse1.rndx])
		stomp_con[1] <= 1'b1;
	else
		stomp_con[1] <= stomp_con[0];
end

// Do not allow exceptioned lanes to update the register file.
always_comb
	we_o = rse_o.v && state==5'd7 ? we & {1'b1,exc_mask} : 9'h000;

// Detect the first exception from the ALU.
always_comb
begin
	exc = Qupls5_pkg::FLT_NONE;
	exc_mask = {WID/8{1'b1}};
	for (n = WID-8; n >= 0; n = n - 8)
		if (Qupls5_pkg::cause_code_t'(exc64 >> n) != Qupls5_pkg::FLT_NONE) begin
			exc = Qupls5_pkg::cause_code_t'(exc64 >> n);
			exc_mask = ~((32'd2 << (n >> 3)) - 32'd1);
		end
end


endmodule
