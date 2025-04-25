// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2025  Robert Finch, Waterloo
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
// 3600 LUTs / 1100 FFs	ALU0
// 3100 LUTs / 700 FFs
// 13.5k LUTs	/ 710 FFs ALU0 with capabilities
//  7.5 kLUTs / 710 FFs ALU0 without capabilities
// 14.5k LUTs / 1420 FFs ALU0 128-bit without capabilities
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Stark_pkg::*;

module Stark_alu(rst, clk, clk2x, om, ld, ir, div, a, b, bi, c, i, t, qres,
	cs, pc, pcc, csr, cpl, coreno, canary, o, o2, o3, mul_done, div_done, div_dbz, exc_o);
parameter ALU0 = 1'b1;
parameter WID=64;
parameter LANE=0;
input rst;
input clk;
input clk2x;
input Stark_pkg::operating_mode_t om;
input ld;
input Stark_pkg::instruction_t ir;
input div;
input [WID-1:0] a;
input [WID-1:0] b;
input [WID-1:0] bi;
input [WID-1:0] c;
input [WID-1:0] i;
input [WID-1:0] t;
input [WID-1:0] qres;
input [2:0] cs;
input cpu_types_pkg::pc_address_ex_t pc;
input capability32_t pcc;
input [WID-1:0] csr;
input [7:0] cpl;
input [WID-1:0] coreno;
input [WID-1:0] canary;
output reg [WID-1:0] o;
output reg [WID-1:0] o2;
output reg [WID-1:0] o3;
output reg mul_done;
output div_done;
output div_dbz;
output Stark_pkg::cause_code_t exc_o;

genvar g;
integer nn,kk,jj;
Stark_pkg::cause_code_t exc;
wire [WID:0] zero = {WID+1{1'b0}};
wire [WID:0] dead = {1'b0,{WID/16{16'hdead}}};
wire cd_args;
value_t cc;
reg [3:0] mul_cnt;
reg [WID*2-1:0] prod, prod1, prod2;
reg [WID*2-1:0] produ, produ1, produ2;
reg [WID*2-1:0] shl, shr, asr;
wire [WID-1:0] div_q, div_r;
wire [WID-1:0] cmpo;
reg [WID:0] bus;
reg [WID-1:0] bus2, bus3;
reg [WID-1:0] busx;
reg [WID-1:0] blendo;
reg [22:0] ii;
reg [WID-1:0] sd;
reg [WID-1:0] sum_ab;
reg [WID+1:0] sum_gc;
reg [WID-1:0] chndx;
reg [WID-1:0] chndx2;
reg [WID-1:0] chrndxv;
wire [WID-1:0] info;
wire [WID-1:0] vmasko;
reg [WID-1:0] tmp;

always_comb
	ii = {{6{i[WID-1]}},i};
always_comb
	sum_ab = a + b;
always_comb
	sum_gc = a + b + c;

always_comb
	shl = {{WID{1'b0}},a} << (ir[31] ? ir.shi.amt : b[5:0]);
always_comb
	shr = {a,{WID{1'b0}}} >> (ir[31] ? ir.shi.amt : b[5:0]);
always_comb
	asr = {{64{a[63]}},a,64'd0} >> (ir[31] ? ir.srai.amt : b[5:0]);

always_ff @(posedge clk)
begin
	prod2 <= $signed(a) * $signed(bi);
	prod1 <= prod2;
	prod <= prod1;
end
always_ff @(posedge clk)
begin
	produ2 <= a * bi;
	produ1 <= produ2;
	produ <= produ1;
end

always_ff @(posedge clk)
if (rst) begin
	mul_cnt <= 4'hF;
	mul_done <= 1'b0;
end
else begin
	mul_cnt <= {mul_cnt[2:0],1'b1};
	if (ld)
		mul_cnt <= 4'd0;
	mul_done <= mul_cnt[3];
end

Stark_cmp #(.WID(WID)) ualu_cmp(ir, a, b, i, cmpo);

Stark_divider #(.WID(WID)) udiv0(
	.rst(rst),
	.clk(clk2x),
	.ld(ld),
	.sgn(div),
	.sgnus(1'b0),
	.a(a),
	.b(ir[31] ? i : bi),
	.qo(div_q),
	.ro(div_r),
	.dvByZr(div_dbz),
	.done(div_done),
	.idle()
);

reg [WID-1:0] locnt,lzcnt,popcnt,tzcnt;
reg loz, lzz, tzz;
reg [WID-1:0] t1;
reg [WID-1:0] exto, extzo;

// Handle ext, extz
always_comb
begin
	t1 = a >> (ir[31] ? ir[22:17] : b[5:0]);	// srl
	for (jj = 0; jj < WID; jj = jj + 1)
		if (ir[31:29]==3'b110)		// extz
			extzo[jj] = jj > ir[28:23] ? 1'b0 : t1[jj];
		else if (ir[31:25]==7'd6)	// extz
			extzo[jj] = jj > b[13:8] ? 1'b0 : t1[jj];
		else if (ir[31:29]==3'b111)
			exto[jj] = jj > ir[28:23] ? t1[ir[28:23]] : t1[jj];
		else if (ir[31:25]==7'd7)	// extz
			exto[jj] = jj > b[13:8] ? t1[b[13:8]] : t1[jj];
end

	
generate begin : gffz
	for (g = WID-1; g >= 0; g = g - 1)
  case(WID)
  16:	
  	begin
  	wire [4:0] popcnt;
  	popcnt24 upopcnt16 (.i({8'h00,a[WID-1:0]}),.o(popcnt));
  	end
  32:
  	begin
  	wire [5:0] popcnt;
  	popcnt48 upopcnt32 (.i({16'h0000,a[WID-1:0]}),.o(popcnt));
  	end
  64:
  	begin
  	wire [6:0] popcnt;
  	popcnt96 upopcnt64 (.i({32'h00000000,a[WID-1:0]}),.o(popcnt));
  	end
  128:
  	begin
  	wire [7:0] popcnt;
  	popcnt144 upopcnt128 (.i({16'h0000,a[WID-1:0]}),.o(popcnt));
  	end
	endcase
  case(WID)
  16:	
  	begin
  	wire [4:0] locnt;
  	ffz24 uffz16 (.i({8'hFF,a[WID-1:0]}),.o(locnt));
  	end
  32:
  	begin
  	wire [5:0] locnt;
  	ffz48 uffz32 (.i({16'hFFFF,a[WID-1:0]}),.o(locnt));
  	end
  64:
  	begin
  	wire [6:0] locnt;
  	ffz96 uffo64 (.i({32'hFFFFFFFF,a[WID-1:0]}),.o(locnt));
  	end
  128:
  	begin
  	wire [7:0] locnt;
  	ffz144 uffo128 (.i({16'hFFFF,a[WID-1:0]}),.o(locnt));
  	end
	endcase
  case(WID)
  16:	
  	begin
  	wire [4:0] lzcnt;
  	ffo24 uffo16 (.i({8'h00,a[WID-1:0]}),.o(lzcnt));
  	end
  32:
  	begin
  	wire [5:0] lzcnt;
  	ffo48 uffo32 (.i({16'h0000,a[WID-1:0]}),.o(lzcnt));
  	end
  64:
  	begin
  	wire [6:0] lzcnt;
  	ffo96 uffo64 (.i({32'h00000000,a[WID-1:0]}),.o(lzcnt));
  	end
  128:
  	begin
  	wire [7:0] lzcnt;
  	ffo144 uffo128 (.i({16'h0000,a[WID-1:0]}),.o(lzcnt));
  	end
	endcase
  case(WID)
  16:	
  	begin
  	wire [4:0] tzcnt;
  	flo24 uflo16 (.i({8'hFF,a[WID-1:0]}),.o(tzcnt));
  	end
  32:
  	begin
  	wire [5:0] tzcnt;
  	flo48 uflo32 (.i({16'hFFFF,a[WID-1:0]}),.o(tzcnt));
  	end
  64:
  	begin
  	wire [6:0] tzcnt;
  	flo96 uflo64 (.i({32'hFFFFFFFF,a[WID-1:0]}),.o(tzcnt));
  	end
  128:
  	begin
  	wire [7:0] tzcnt;
  	flo144 uflo128 (.i({16'hFFFF,a[WID-1:0]}),.o(tzcnt));
  	end
	endcase
end
endgenerate

// XPM_FIFO instantiation template for Synchronous FIFO configurations
// Refer to the targeted device family architecture libraries guide for XPM_FIFO documentation
// =======================================================================================================================

// +---------------------------------------------------------------------------------------------------------------------+
// | USE_ADV_FEATURES     | String             | Default value = 0707.                                                   |
// |---------------------------------------------------------------------------------------------------------------------|
// | Enables data_valid, almost_empty, rd_data_count, prog_empty, underflow, wr_ack, almost_full, wr_data_count,         |
// | prog_full, overflow features.                                                                                       |
// |                                                                                                                     |
// |   Setting USE_ADV_FEATURES[0] to 1 enables overflow flag; Default value of this bit is 1                            |
// |   Setting USE_ADV_FEATURES[1] to 1 enables prog_full flag; Default value of this bit is 1                           |
// |   Setting USE_ADV_FEATURES[2] to 1 enables wr_data_count; Default value of this bit is 1                            |
// |   Setting USE_ADV_FEATURES[3] to 1 enables almost_full flag; Default value of this bit is 0                         |
// |   Setting USE_ADV_FEATURES[4] to 1 enables wr_ack flag; Default value of this bit is 0                              |
// |   Setting USE_ADV_FEATURES[8] to 1 enables underflow flag; Default value of this bit is 1                           |
// |   Setting USE_ADV_FEATURES[9] to 1 enables prog_empty flag; Default value of this bit is 1                          |
// |   Setting USE_ADV_FEATURES[10] to 1 enables rd_data_count; Default value of this bit is 1                           |
// |   Setting USE_ADV_FEATURES[11] to 1 enables almost_empty flag; Default value of this bit is 0                       |
// |   Setting USE_ADV_FEATURES[12] to 1 enables data_valid flag; Default value of this bit is 0                         |

reg ld1, ld2;
reg [5:0] beb_handle = 6'd1;
wire bebfifo_rd_rst_busy;
wire bebfifo_wr_rst_busy;
wire bebfifo_data_valid;
wire bebfifo_empty;
wire bebfifo_full;
wire bebfifo_overflow;
wire bebfifo_prog_full;
reg bebfifo_wr_en;
Stark_pkg::beb_entry_t bebfifo_din;
Stark_pkg::beb_entry_t bebfifo_dout;

/* Under construction */
generate begin : gBeb
if (0) begin
always_ff @(posedge clk)
if (rst) begin
	ld1 <= 1'b0;
	ld2 <= 1'b0;
	bebfifo_wr_en <= 1'b0;
	beb_handle <= 6'd1;
	bebfifo_din <= {$bits(beb_entry_t){1'b0}};
end
else begin
	bebfifo_wr_en <= 1'b0;
	ld1 <= 1'b0;
	ld2 <= ld1;
	bebfifo_din.v <= INV;
	if (ld) begin
		ld1 <= 1'b1;
		bebfifo_din.v <= VAL;
		bebfifo_din.handle <= beb_handle;
		bebfifo_din.state <= 2'd0;
		bebfifo_din.pc <= pc;
		bebfifo_din.argA <= a;
		bebfifo_din.argB <= b;
		bebfifo_din.argC <= c;
		bebfifo_wr_en <= 1'b1;
	end
	// Increment BEB handle
	if (ld2) begin
		if (!bebfifo_overflow) begin
			beb_handle <= beb_handle + 2'd1;
			if (beb_handle==6'd63)
				beb_handle <= 6'd1;
		end
	end
end

   // xpm_fifo_sync: Synchronous FIFO
   // Xilinx Parameterized Macro, version 2024.1

   xpm_fifo_sync #(
      .CASCADE_HEIGHT(0),            // DECIMAL
      .DOUT_RESET_VALUE("0"),        // String
      .ECC_MODE("no_ecc"),           // String
      .EN_SIM_ASSERT_ERR("warning"), // String
      .FIFO_MEMORY_TYPE("distributed"),	// String
      .FIFO_READ_LATENCY(1),         // DECIMAL
      .FIFO_WRITE_DEPTH(32),         // DECIMAL
      .FULL_RESET_VALUE(0),          // DECIMAL
      .PROG_EMPTY_THRESH(5),         // DECIMAL
      .PROG_FULL_THRESH(28),         // DECIMAL
      .RD_DATA_COUNT_WIDTH(6),       // DECIMAL
      .READ_DATA_WIDTH($bits(beb_entry_t)),          // DECIMAL
      .READ_MODE("std"),             // String
      .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_ADV_FEATURES("1707"),     // String
      .WAKEUP_TIME(0),               // DECIMAL
      .WRITE_DATA_WIDTH($bits(beb_entry_t)),         // DECIMAL
      .WR_DATA_COUNT_WIDTH(6)        // DECIMAL
   )
   xpm_fifo_sync_inst (
      .almost_empty(),   						 // 1-bit output: Almost Empty : When asserted, this signal indicates that
                                     // only one more read can be performed before the FIFO goes to empty.

      .almost_full(),     					 // 1-bit output: Almost Full: When asserted, this signal indicates that
                                     // only one more write can be performed before the FIFO is full.

      .data_valid(bebfifo_data_valid), // 1-bit output: Read Data Valid: When asserted, this signal indicates
                                     // that valid data is available on the output bus (dout).

      .dbiterr(),				             // 1-bit output: Double Bit Error: Indicates that the ECC decoder detected
                                     // a double-bit error and data in the FIFO core is corrupted.

      .dout(bebfifo_dout),           // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
                                     // when reading the FIFO.

      .empty(bebfifo_empty),         // 1-bit output: Empty Flag: When asserted, this signal indicates that the
                                     // FIFO is empty. Read requests are ignored when the FIFO is empty,
                                     // initiating a read while empty is not destructive to the FIFO.

      .full(bebfifo_full),           // 1-bit output: Full Flag: When asserted, this signal indicates that the
                                     // FIFO is full. Write requests are ignored when the FIFO is full,
                                     // initiating a write when the FIFO is full is not destructive to the
                                     // contents of the FIFO.

      .overflow(bebfifo_overflow),   // 1-bit output: Overflow: This signal indicates that a write request
                                     // (wren) during the prior clock cycle was rejected, because the FIFO is
                                     // full. Overflowing the FIFO is not destructive to the contents of the
                                     // FIFO.

      .prog_empty(),					       // 1-bit output: Programmable Empty: This signal is asserted when the
                                     // number of words in the FIFO is less than or equal to the programmable
                                     // empty threshold value. It is de-asserted when the number of words in
                                     // the FIFO exceeds the programmable empty threshold value.

      .prog_full(bebfifo_prog_full), // 1-bit output: Programmable Full: This signal is asserted when the
                                     // number of words in the FIFO is greater than or equal to the
                                     // programmable full threshold value. It is de-asserted when the number of
                                     // words in the FIFO is less than the programmable full threshold value.

      .rd_data_count(), 						 // RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates the
                                     // number of words read from the FIFO.

			// 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read
			// domain is currently in a reset state.
      .rd_rst_busy(bebfifo_rd_rst_busy),

      .sbiterr(),				             // 1-bit output: Single Bit Error: Indicates that the ECC decoder detected
                                     // and fixed a single-bit error.

      .underflow(bebfifo_underflow), // 1-bit output: Underflow: Indicates that the read request (rd_en) during
                                     // the previous clock cycle was rejected because the FIFO is empty. Under
                                     // flowing the FIFO is not destructive to the FIFO.

      .wr_ack(),			               // 1-bit output: Write Acknowledge: This signal indicates that a write
                                     // request (wr_en) during the prior clock cycle is succeeded.

      .wr_data_count(), 						// WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates
                                     // the number of words written into the FIFO.

      .wr_rst_busy(bebfifo_wr_rst_busy),	// 1-bit output: Write Reset Busy: Active-High indicator that the FIFO
                                     // write domain is currently in a reset state.

      .din(bebfifo_din),             // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
                                     // writing the FIFO.

      .injectdbiterr(1'b0), 				// 1-bit input: Double Bit Error Injection: Injects a double bit error if
                                     // the ECC feature is used on block RAMs or UltraRAM macros.

      .injectsbiterr(1'b0),					 // 1-bit input: Single Bit Error Injection: Injects a single bit error if
                                     // the ECC feature is used on block RAMs or UltraRAM macros.

			// 1-bit input: Read Enable: If the FIFO is not empty, asserting this
			// signal causes data (on dout) to be read from the FIFO. Must be held
			// active-low when rd_rst_busy is active high.
      .rd_en(bebfifo_rd_en & ~bebfifo_rd_rst_busy),

      .rst(irst),                    // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
                                     // unstable at the time of applying reset, but reset must be released only
                                     // after the clock(s) is/are stable.

      .sleep(1'b0),                 // 1-bit input: Dynamic power saving- If sleep is High, the memory/fifo
                                     // block is in power saving mode.

      .wr_clk(clk),		               // 1-bit input: Write clock: Used for write operation. wr_clk must be a
                                     // free running clock.

			// 1-bit input: Write Enable: If the FIFO is not full, asserting this
			// signal causes data (on din) to be written to the FIFO Must be held
			// active-low when rst or wr_rst_busy or rd_rst_busy is active high
      .wr_en(bebfifo_wr_en & ~rst & ~bebfifo_wr_rst_busy & ~bebfifo_rd_rst_busy)

   );
end
end
endgenerate

generate begin : gInfoBlend
	if (WID != 64) begin
		assign blendo = {WID{1'b0}};
		assign info = {WID{1'b0}};
	end
	else begin
		if (ALU0) begin
			Stark_info uinfo1 (
				.ndx(a[4:0]+b[4:0]+ir[26:22]),
				.coreno(coreno),
				.o(info)
			);
		end
	end
end
endgenerate
/*
always_comb
	case(ir[32:31])
	2'd0:	chrndxv = a;
	2'd1:	chrndxv = {8{i[7:0]}} & a;
	2'd2:	chrndxv = {8{i[7:0]}} | a;
	2'd3:	chrndxv = {8{i[7:0]}} ^ a;
	endcase

generate begin : gChrndx
	for (g = WID/8-1; g >= 0; g = g - 1) begin
		always_comb
		begin
			if (g==WID/8-1)
				chndx[g] = 1'b0;
			if (b[g*8+7:g*8]==chrndxv[g*8+7:g*8])
				chndx[g] = 1'b1;
		end
	end
end
endgenerate

flo96 uflo1 (.i({96'd0,chndx[WID/8-1:0]}), .o(chndx2[6:0]));
*/
/*
typedef enum logic [3:0] {
	FOP4_ADD = 4'd4,
	FOP4_SUB = 4'd5,
	FOP4_MUL = 4'd6,
	FOP4_DIV = 4'd7,
	FOP4_G8 = 4'd8,
	FOP4_G10 = 4'd10,
	FOP4_TRIG = 4'd11
} float_t;

typedef enum logic [2:0] {
	FG8_FSNGJ = 3'd0,
	FG8_FSGNJN = 3'd1,
	FG8_FSGNJX = 3'd2,
	FG8_SCALEB = 3'd3
} float_g8_t;

typedef enum logic [4:0] {
	FG10_FCVTF2I = 5'd0,
	FG10_FCVTI2F = 5'd1,
	FG8_FSIGN = 5'd16,
	FG8_FSQRT = 5'd17
} float_g10_t;
*/

always_comb
begin
	exc = Stark_pkg::FLT_NONE;
	bus = {(WID/16){16'h0000}};
	bus2 = {(WID/16){16'h0000}};
	case(ir.any.opcode)
	Stark_pkg::OP_FLT:
		case(ir.fpu.op4)
		FOP4_G8:	
			case (ir.fpu.op3)
			FG8_FSGNJ:	bus = {b[WID-1],a[WID-2:0]};
			FG8_FSGNJN:	bus = {~b[WID-1],a[WID-2:0]};
			FG8_FSGNJX:	bus = {b[WID-1]^a[WID-1],a[WID-2:0]};
			default:	 bus = zero;
			endcase
		default:	bus = zero;
		endcase
	Stark_pkg::OP_CHK:
		case(ir.chk.op4)
		4'd0:	if (!(a >= b && a < c)) exc = Stark_pkg::FLT_CHK;
		4'd1: if (!(a >= b && a <= c)) exc = Stark_pkg::FLT_CHK;
		4'd2: if (!(a > b && a < c)) exc = Stark_pkg::FLT_CHK;
		4'd3: if (!(a > b && a <= c)) exc = Stark_pkg::FLT_CHK;
		4'd4:	if (a >= b && a < c) exc = Stark_pkg::FLT_CHK;
		4'd5: if (a >= b && a <= c) exc = Stark_pkg::FLT_CHK;
		4'd6: if (a > b && a < c) exc = Stark_pkg::FLT_CHK;
		4'd7: if (a > b && a <= c) exc = Stark_pkg::FLT_CHK;
		4'd8:	if (!(a >= cpl)) exc = Stark_pkg::FLT_CHK;
		4'd9:	if (!(a <= cpl)) exc = Stark_pkg::FLT_CHK;
		4'd10:	if (!(a==canary)) exc = Stark_pkg::FLT_CHK;
		default:	exc = Stark_pkg::FLT_UNIMP;
		endcase
	Stark_pkg::OP_CSR:		bus = csr;

	Stark_pkg::OP_ADD:
		begin
			if (ir[31])
				bus = a + i;
			else
				case(ir.alu.op3)
				3'd0:		// ADD
					case(ir.alu.lx)
					2'd0:	bus = a + b;
					default:	bus = a + i;
					endcase
				3'd2:		// ABS
					case(ir.alu.lx)
					2'd0:
						begin
							tmp = a + b;
							bus = tmp[WID-1] ? -tmp : tmp;
						end
					default:
						begin
							tmp = a + i;
							bus = tmp[WID-1] ? -tmp : tmp;
						end
					endcase
				3'd3:	bus = &locnt ? WID : locnt;
				3'd4:	bus = &lzcnt ? WID : lzcnt;
				3'd5:	bus = popcnt;
				3'd6:	bus = &tzcnt ? WID : tzcnt;
				default:	bus = zero;
				endcase
		end
	Stark_pkg::OP_ADB:
		if (ir[31])
			bus = a + i;
		else
			case(ir.alu.lx)
			2'd0:	bus = a + b;
			default:	bus = a + i;
			endcase
	Stark_pkg::OP_MUL:
		if (ir[31])
			bus = produ[WID-1:0];
		else
			case (ir.alu.op3)
			3'd0:	bus = produ[WID-1:0];
			3'd1: bus = prod[WID-1:0];
			3'd4:	bus = prod[WID*2-1:WID];
			default:	bus = zero;
			endcase
	Stark_pkg::OP_DIV:
		if (ir[31])
			bus = div_q[WID-1:0];
		else
			case (ir.alu.op3)
			3'd0:	bus = div_q[WID-1:0];
			3'd1: bus = div_q[WID-1:0];
			3'd4:	bus = div_r[WID-1:0];
			default:	bus = zero;
			endcase
	Stark_pkg::OP_AND:
		if (ir[31])
			bus = a & i;
		else
			case(ir.alu.op3)
			3'd0:	bus = a & bi;
			3'd1:	bus = ~(a & bi);
			3'd2:	bus = a & ~bi;
			default:	bus = zero;	
			endcase
	Stark_pkg::OP_OR:
		if (ir[31])
			bus = a | i;
		else
			case(ir.alu.op3)
			3'd0:	bus = a | bi;
			3'd1:	bus = ~(a | bi);
			3'd2:	bus = a | ~bi;
			default:	bus = zero;	
			endcase
	Stark_pkg::OP_XOR:
		if (ir[31])
			bus = a ^ i;
		else
			case(ir.alu.op3)
			3'd0:	bus = a ^ bi;
			3'd1:	bus = ~(a ^ bi);
			3'd2:	bus = a ^ ~bi;
			default:	bus = zero;	
			endcase
	Stark_pkg::OP_SUBF:
		if (ir[31])
			bus = i - a;
		else
			case(ir.alu.op3)
			3'd0:	bus = bi - a;
			3'd2:									// PTRDIF
				begin
					tmp = bi - a;
					tmp = tmp[WID-1] ? -tmp : tmp;
					bus = tmp >> ir[25:22];
				end
			default:	bus = zero;	
			endcase
	Stark_pkg::OP_CMP:	bus = cmpo;
	Stark_pkg::OP_SHIFT:
		if (ir[31])
			case(ir.shi.op2)
			2'd0:	
				case(ir[28:26])
				3'd0:	bus = ir.shi.h ? shl[WID*2-1:WID] : shl[WID-1:0];
				3'd1:	bus = ir.shi.h ? shr[WID-1:0] : shr[WID*2-1:WID];
				3'd2:	
					case(ir.srai.rm)
					default:
						bus = asr[WID*2-1:WID];
					endcase
				3'd3:	bus = ir[25] ? exto : extzo;
				3'd4:	
					if (ir[25])	// ROL?
						bus = shl[WID*2-1:WID]|shl[WID-1:0];
					else
						bus = shr[WID*2-1:WID]|shr[WID-1:0];
				default:	bus = zero;
				endcase
			3'd2:	bus = extzo;
			3'd3: bus = exto;
			default: bus = zero;
			endcase
		else
			case(ir.shi.op2)
			2'd0:	
				case(ir[28:26])
				3'd0:	bus = ir.shi.h ? shl[WID*2-1:WID] : shl[WID-1:0];
				3'd1:	bus = ir.shi.h ? shr[WID-1:0] : shr[WID*2-1:WID];
				3'd2:	
					case(ir.srai.rm)
					default:
						bus = asr[WID*2-1:WID];
					endcase
				3'd3:	bus = ir[25] ? exto : extzo;
				3'd4:	
					if (ir[25])	// ROL?
						bus = shl[WID*2-1:WID]|shl[WID-1:0];
					else
						bus = shr[WID*2-1:WID]|shr[WID-1:0];
				default:	bus = zero;
				endcase
			3'd2:	bus = extzo;
			3'd3: bus = exto;
			default: bus = zero;
			endcase
	Stark_pkg::OP_MOV:
		if (ir[31]) begin
			case(ir.move.op3)
			3'd0:	// MOVE / XCHG
				begin
					bus = a;	// MOVE
					bus2 = b;	// not updated by MOVE
				end
			3'd1:	// XCHGMD / MOVEMD
				begin	
					bus = a;
					bus2 = b;	// not updated by MOVEMD
				end
			3'd2:	bus = zero;		// MOVSX
			3'd3:	bus = zero;		// MOVZX
			3'd4:	bus = ~|a ? i : t;	// CMOVZ
			3'd5:	bus =  |a ? i : t;	// CMOVNZ
			3'd6:	bus = zero;		// BMAP
			default:
				begin
					bus = zero;
				end
			endcase
		end
		else
			case(ir.move.op3)
			3'd4:	bus = ~|a ? b : t;	// CMOVZ
			3'd5:	bus =  |a ? b : t;	// CMOVNZ
			default:
				begin
					bus = zero;
				end
			endcase
	Stark_pkg::OP_LOADA:	bus = a + i + (b << ir[23:22]);
	Stark_pkg::OP_PFX:		bus = zero;
	Stark_pkg::OP_NOP:		bus = t;	// in case of copy target
	/*
	Stark_pkg::OP_BLOCK:
		case(ir.block.op)
		default:	bus = 64'd0;
		endcase
    */
	default:	bus = {(WID/16){16'hDEAD}};
	endcase
end

always_comb
begin
	bus3 = zero;
	bus3[0] = bus==zero;
	bus3[1] = 1'b1;
	bus3[2] = bus==zero;
	bus3[3] = bus[WID-1];
	bus3[4] = bus[WID-1]||bus==zero;
	bus3[5] = bus[WID];
	bus3[6] = 1'b0;
	bus3[7] = 1'b0;
end

always_ff @(posedge clk)
	o = bus;
always_ff @(posedge clk)
	o2 = bus2;
always_ff @(posedge clk)
	o3 = bus3 << {om,3'b0};
always_ff @(posedge clk)
	exc_o = exc;

endmodule
