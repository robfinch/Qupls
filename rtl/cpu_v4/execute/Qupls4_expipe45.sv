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
import Qupls4_pkg::*;

module Qupls4_expipe45(rst, clk, clk3x, idle, stomp, rse_i, rse_o, rm,
	z, cptgt, o, sto, ust, otag, we_o, done, exc,
	tlb_v, adr, adrv, agen_rse,
	mem_rse_i, mem_done_i, mem_res_i, mem_flags_i);
parameter WID=Qupls4_pkg::SUPPORT_QUAD_PRECISION|Qupls4_pkg::SUPPORT_CAPABILITIES ? 128 : 64;
parameter PIPE = 3'd4;
parameter SUPPORT_ISQRT = (PIPE==3'd4 && SUPPORT_ISQRT4) || (PIPE==3'd5 && SUPPORT_ISQRT5);
parameter SUPPORT_FMA = (PIPE==3'd4 && SUPPORT_FMA4) || (PIPE==3'd5 && SUPPORT_FMA5);
parameter SUPPORT_IDIV = (PIPE==3'd4 && SUPPORT_IDIV4) || (PIPE==3'd5 && SUPPORT_IDIV5);
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
input Qupls4_pkg::reservation_station_entry_t mem_rse_i;
input mem_done_i;
input [WID-1:0] mem_res_i;
input Qupls4_pkg::flags_t mem_flags_i;

Qupls4_pkg::reservation_station_entry_t rse1,rse2;
Qupls4_pkg::operating_mode_t om;
Qupls4_pkg::memsz_t prc,prc5;
Qupls4_pkg::micro_op_t ir,ir5;
reg [WID-1:0] a;
reg [WID-1:0] b,bi;
reg [WID-1:0] c;
reg [WID*4-1:0] lastarg;
reg [WID-1:0] t;
reg [WID-1:0] s;
reg [WID-1:0] i;
aregno_t aRd_i;
reg [1:0] stomp_con;	// stomp conveyor
reg [WID/8:0] we,we1,we2;
wire [WID-1:0] alu_o64, alu_o64d, fma_o64, fma_o16, fma_o32;
wire [WID-1:0] isqrt_o, idiv_o;
wire [WID/8:0] alu_we, isqrt_we, idiv_we;
wire [WID/8-1:0] alu_exc;
reg idiv_ld;
wire idiv_done;

cpu_types_pkg::address_t as, bs;
cpu_types_pkg::address_t res1;
reg [5:0] shift;

always_ff @(posedge clk)
	lastarg <= {a,b,bi,c};
always_ff @(posedge clk)
	idiv_ld <= lastarg != {a,b,bi,c};
	
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
always_comb prc = rse_i.prc;

Qupls4_pkg::cause_code_t exc128,exc64;
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

always_ff @(posedge clk) 
	rse1 <= rse_i;
always_ff @(posedge clk)
	rse2 <= rse1;
always_comb
	rse_o = rse2;

//generate begin : gAgen
//	if (PIPE==3'd4 || PIPE==3'd5) begin
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

//end
//end
//endgenerate

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
	.o(alu_o64),
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


generate begin : gPrec
if (Qupls4_pkg::SUPPORT_PREC) begin
		for (g = 0; g < WID/16; g = g + 1)
			if (PIPE==3'd3 || PIPE==3'd4)
			/*
			fpFMA16LN ufma16 (
				.clk(clk),
				.op(ir[30]),		// 0=add,1=sub c
				.rm(rse_i.rm),
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
					.rm(rse_i.rm),
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
else begin
	for (g = 0; g < WID/64; g = g + 1) begin
	if (SUPPORT_FMA)
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

generate begin : gIDiv
if (SUPPORT_IDIV)
Qupls4_meta_idiv uidiv0
(
	.rst(irst),
	.clk(clk),
	.clk2x(clk3x),
	.ld(idiv_ld),
	.rse_i(rse_i),
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
	Qupls4_meta_isqrt uimul0
	(
		.rst(irst),
		.clk(clk),
		.stomp(stomp),
		.rse_i(rse_i),
		.rse_o(),
		.lane(rse_i.uop.num),
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

delay4 #(.WID(WID)) udly1 (.clk(clk), .ce(1'b1), .i(alu_o64), .o(aluo_64d));
delay5 #(.WID($bits(Qupls4_pkg::micro_op_t))) udly3 (.clk(clk), .ce(1'b1), .i(ir), .o(ir5));
delay5 #(.WID($bits(Qupls4_pkg::memsz_t))) udly4 (.clk(clk), .ce(1'b1), .i(prc), .o(prc5));


always_comb
begin
	done64 = FALSE;
	case(ir5.opcode)
	Qupls4_pkg::OP_R3BP,Qupls4_pkg::OP_R3WP,Qupls4_pkg::OP_R3TP,Qupls4_pkg::OP_R3OP,
	Qupls4_pkg::OP_R3VVV,Qupls4_pkg::OP_R3VVS,
	Qupls4_pkg::OP_R3B,Qupls4_pkg::OP_R3W,Qupls4_pkg::OP_R3T,Qupls4_pkg::OP_R3O:
		case(ir5.func)
		Qupls4_pkg::FN_DIV,Qupls4_pkg::FN_DIVU:
			if (SUPPORT_IDIV) begin
				o1 = idiv_o;
				done64 = idiv_done;
			end
			else begin
				o1 = value_zero;
				done64 = TRUE;
			end
		Qupls4_pkg::FN_R1:
			case(ir5.Rs2)
			R1_SQRT:
				begin
					o1 = isqrt_o;
					done64 = isqrt_done;
				end
			default:	
				begin
					o1 = value_zero;
					done64 = TRUE;
				end
			endcase
		default:	
			begin
				o1 = value_zero;
				done64 = TRUE;
			end
		endcase

	Qupls4_pkg::OP_FLTH,Qupls4_pkg::OP_FLTS,Qupls4_pkg::OP_FLTD,
	Qupls4_pkg::OP_FLTPH,Qupls4_pkg::OP_FLTPS,Qupls4_pkg::OP_FLTPD,
	Qupls4_pkg::OP_FLTVVV,Qupls4_pkg::OP_FLTVVS:
		case(ir5.func)
		Qupls4_pkg::FLT_FMA,Qupls4_pkg::FLT_FMS,Qupls4_pkg::FLT_FNMA,Qupls4_pkg::FLT_FNMS:
			begin
				case(prc)
				2'd0:	 o1 = fma_o16;
				2'd1:	 o1 = fma_o32;
				2'd2:	 o1 = fma_o64;
				2'd3:   ;
				endcase
				done64 = TRUE;
			end
		default:
			begin
				o1 = alu_o64d;
				done64 = TRUE;
			end
		endcase
	Qupls4_pkg::OP_DIVI,Qupls4_pkg::OP_DIVUI:
		if (SUPPORT_IDIV) begin
			o1 = idiv_o;
			done64 = idiv_done;
		end
		else begin
			o1 = value_zero;
			done64 = TRUE;
		end
	Qupls4_pkg::OP_LDB,Qupls4_pkg::OP_LDBZ,Qupls4_pkg::OP_LDW,Qupls4_pkg::OP_LDWZ,
	Qupls4_pkg::OP_LDT,Qupls4_pkg::OP_LDTZ,Qupls4_pkg::OP_LOAD,
	Qupls4_pkg::OP_STB,Qupls4_pkg::OP_STW,
	Qupls4_pkg::OP_STT,Qupls4_pkg::OP_STORE,
	Qupls4_pkg::OP_STI,
	Qupls4_pkg::OP_STPTR,
	Qupls4_pkg::OP_V2P,
	Qupls4_pkg::OP_VV2P,
	Qupls4_pkg::OP_AMO:
		begin
			o1 = mem_res_i;
			done64 = mem_done_i;
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
    	if (stomp_con[1]||rse2.uop.opcode==Qupls4_pkg::OP_NOP)
        o[mm*8+7:mm*8] = t[mm*8+7:mm*8];
//      else if (cptgt[mm])
//        o[mm*8+7:mm*8] = z ? 8'h00 : t[mm*8+7:mm*8];
      else
        o[mm*8+7:mm*8] = o1[mm*8+7:mm*8];
    end
end
endgenerate

delay5 #(.WID(WID/8+1)) udly6 (.clk(clk), .ce(1'b1), .i(we), .o(we2));

always_comb
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
	we_o = rse_o.v ? we2 : 9'h000;


always_comb
	done = done64;
//	done = ~sr64[6];
always_comb
	exc = exc64;

endmodule
