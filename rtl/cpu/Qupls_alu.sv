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
// 3600 LUTs / 1100 FFs	ALU0
// 3100 LUTs / 700 FFs
// 13.5k LUTs	/ 710 FFs ALU0 with capabilities
//  7.5 kLUTs / 710 FFs ALU0 without capabilities
// 14.5k LUTs / 1420 FFs ALU0 128-bit without capabilities
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import QuplsPkg::*;

module Qupls_alu(rst, clk, clk2x, ld, ir, div, a, b, bi, c, i, t, qres,
	cs, pc, pcc, csr, cpl, coreno, canary, o, mul_done, div_done, div_dbz, exc_o);
parameter ALU0 = 1'b1;
parameter WID=64;
parameter LANE=0;
input rst;
input clk;
input clk2x;
input ld;
input instruction_t ir;
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
output reg mul_done;
output div_done;
output div_dbz;
output cause_code_t exc_o;

genvar g;
integer nn,kk;
cause_code_t exc;
wire [WID-1:0] zero = {WID{1'b0}};
wire [WID-1:0] dead = {WID/16{16'hdead}};
wire cd_args;
value_t cc;
reg [3:0] mul_cnt;
reg [WID*2-1:0] prod, prod1, prod2;
reg [WID*2-1:0] produ, produ1, produ2;
reg [WID*2-1:0] shl, shr, asr;
wire [WID-1:0] div_q, div_r;
wire [WID-1:0] cmpo;
reg [WID-1:0] bus;
reg [WID-1:0] busx;
reg [WID-1:0] blendo;
reg [WID-1:0] immc8;
reg [22:0] ii;
reg [WID-1:0] sd;
reg [WID-1:0] sum_ab;
reg [WID+1:0] sum_gc;
reg [WID-1:0] chndx;
reg [WID-1:0] chndx2;
reg [WID-1:0] chrndxv;
wire [WID-1:0] info;
wire [WID-1:0] vmasko;

always_comb
	ii = {{6{i[WID-1]}},i};
always_comb
	sum_ab = a + b;
always_comb
	sum_gc = a + b + c;

always_comb
	immc8 = {{WID{ir[41]}},ir[41:34]};
always_comb
	shl = {b,a} << (ir.lshifti.func[3] ? ir.lshifti.imm : c[5:0]);
always_comb
	shr = {b,a} >> (ir.rshifti.func[3] ? ir.rshifti.mb : c[5:0]);
always_comb
	asr = {{64{a[63]}},a,64'd0} >> (ir.rshifti.func[3] ? ir.rshifti.mb : c[5:0]);

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

Qupls_cmp #(.WID(WID)) ualu_cmp(ir, a, b, i, cmpo);

Qupls_divider #(.WID(WID)) udiv0(
	.rst(rst),
	.clk(clk2x),
	.ld(ld),
	.sgn(div),
	.sgnus(1'b0),
	.a(a),
	.b(bi),
	.qo(div_q),
	.ro(div_r),
	.dvByZr(div_dbz),
	.done(div_done),
	.idle()
);

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
beb_entry_t bebfifo_din;
beb_entry_t bebfifo_dout;

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
			Qupls_info uinfo1 (
				.ndx(a[4:0]+b[4:0]+ir[26:22]),
				.coreno(coreno),
				.o(info)
			);
			Qupls_setvmask usm1 (
				.max_ele_sz($bits(value_t)),
				.numlanes(a[6:0]),
				.lanesz(b[5:0]|i[4:0]),
				.mask(vmasko)
			);
		end

		Qupls_blend ublend0
		(
			.a(c),
			.c0(a),
			.c1(bi),
			.o(blendo)
		);
	end
end
endgenerate

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

always_comb
begin
	exc = FLT_NONE;
	bus = {(WID/16){16'h0000}};
	case(ir.any.opcode)
	OP_FLT3:
		case(ir.f3.func)
		FN_FCMP:	bus = cmpo;
		FN_FLT1:
			case(ir.f1.func)
			FN_FABS:	bus = {1'b0,a[WID-2:0]};
			FN_FNEG:	bus = {a[WID-1]^1'b1,a[WID-2:0]};
			default:	bus = {WID{1'd0}};
			endcase
		default:	bus = {WID{1'd0}};
		endcase
	OP_CHK:
		case(ir[47:44])
		4'd0:	if (!(a >= b && a < c)) exc = cause_code_t'(ir[34:27]);
		4'd1: if (!(a >= b && a <= c)) exc = cause_code_t'(ir[34:27]);
		4'd2: if (!(a > b && a < c)) exc = cause_code_t'(ir[34:27]);
		4'd3: if (!(a > b && a <= c)) exc = cause_code_t'(ir[34:27]);
		4'd4:	if (a >= b && a < c) exc = cause_code_t'(ir[34:27]);
		4'd5: if (a >= b && a <= c) exc = cause_code_t'(ir[34:27]);
		4'd6: if (a > b && a < c) exc = cause_code_t'(ir[34:27]);
		4'd7: if (a > b && a <= c) exc = cause_code_t'(ir[34:27]);
		4'd8:	if (!(a >= cpl)) exc = cause_code_t'(ir[34:27]);
		4'd9:	if (!(a <= cpl)) exc = cause_code_t'(ir[34:27]);
		4'd10:	if (!(a==canary)) exc = cause_code_t'(ir[34:27]);
		default:	exc = FLT_UNIMP;
		endcase
	OP_R3B,OP_R3W,OP_R3T,OP_R3O:
		case(ir.r2.func)
		FN_CPUID:	bus = ALU0 ? info : 64'd0;
		FN_ADD:
			case(ir.r2.op4)
			3'd0:	bus = (a + b) & c;
			3'd1: bus = (a + b) | c;
			3'd2: bus = (a + b) ^ c;
			3'd3:	bus = (a + b) + c;
			/*
			4'd9:	bus = (a + b) - c;
			4'd10: bus = (a + b) + c + 2'd1;
			4'd11: bus = (a + b) + c - 2'd1;
			4'd12:
				begin
					sd = (a + b) + c;
					bus = sd[WID-1] ? -sd : sd;
				end
			4'd13:
				begin
					sd = (a + b) - c;
					bus = sd[WID-1] ? -sd : sd;
				end
			*/
			default:	bus = zero;
			endcase
		FN_SUB:	bus = a - b - c;
		FN_CMP,FN_CMPU:	
			case(ir.r2.op4)
			3'd1:	bus = cmpo & c;
			3'd2:	bus = cmpo | c;
			3'd3:	bus = cmpo ^ c;
			default:	bus = cmpo;
			endcase
		FN_MUL:	bus = prod[WID-1:0];
		FN_MULU:	bus = produ[WID-1:0];
		FN_MULW:	bus = ALU0 ? prod[WID-1:0] : prod[WID*2-1:WID];
		FN_MULUW:	bus = ALU0 ? produ[WID-1:0] : produ[WID*2-1:WID];
		FN_DIV: bus = ALU0 ? div_q : dead;
		FN_MOD: bus = ALU0 ? div_r : dead;
		FN_DIVU: bus = ALU0 ? div_q : dead;
		FN_MODU: bus = ALU0 ? div_r : dead;
		FN_AND:	
			case(ir.r2.op4)
			3'd0:	bus = (a & b) & c;
			3'd1: bus = (a & b) | c;
			3'd2: bus = (a & b) ^ c;
			default:	bus = {WID{1'd0}};
			endcase
		FN_OR:
			case(ir.r2.op4)
			3'd0:	bus = (a | b) & c;
			3'd1: bus = (a | b) | c;
			3'd2: bus = (a | b) ^ c;
			3'd7:	bus = (a & b) | (a & c) | (b & c);
			default:	bus = {WID{1'd0}};
			endcase
		FN_EOR:	
			case(ir.r2.op4)
			3'd0:	bus = (a ^ b) & c;
			3'd1: bus = (a ^ b) | c;
			3'd2: bus = (a ^ b) ^ c;
			3'd7:	bus = (^a) ^ (^b) ^ (^c);
			default:	bus = {WID{1'd0}};
			endcase
		FN_CMOVZ: bus = a ? c : b;
		FN_CMOVNZ:	bus = a ? b : c;
		FN_NAND:
			case(ir.r2.op4)
			3'd0:	bus = ~(a & b) & c;
			3'd1: bus = ~(a & b) | c;
			3'd2: bus = ~(a & b) ^ c;
			default:	bus = {WID{1'd0}};
			endcase
		FN_NOR:
			case(ir.r2.op4)
			3'd0:	bus = ~(a | b) & c;
			3'd1: bus = ~(a | b) | c;
			3'd2: bus = ~(a | b) ^ c;
			default:	bus = {WID{1'd0}};
			endcase
		FN_ENOR:
			case(ir.r2.op4)
			3'd0:	bus = ~(a ^ b) & c;
			3'd1: bus = ~(a ^ b) | c;
			3'd2: bus = ~(a ^ b) ^ c;
			default:	bus = {WID{1'd0}};
			endcase
			
		FN_BYTENDX:	bus = ALU0 ? chndx2 : dead;

		FN_SEQ:	bus = a==b ? c : t;
		FN_SNE:	bus = a!=b ? c : t;
		FN_SLT:	bus = $signed(a) < $signed(b) ? c : t;
		FN_SLE:	bus = $signed(a) <= $signed(b) ? c : t;
		FN_SLTU:	bus = a < b ? c : t;
		FN_SLEU: 	bus = a <= b ? c : t;

		FN_SEQI8:	bus = a == b ? immc8 : t;
		FN_SNEI8:	bus = a != b ? immc8 : t;
		FN_SLTI8:	bus = $signed(a) < $signed(b) ? immc8 : t;
		FN_SLEI8:	bus = $signed(a) <= $signed(b) ? immc8 : t;
		FN_SLTUI8:	bus = a < b ? immc8 : t;
		FN_SLEUI8:	bus = a <= b ? immc8 : t;

		FN_ZSEQ:	bus = a==b ? c : zero;
		FN_ZSNE:	bus = a!=b ? c : zero;
		FN_ZSLT:	bus = $signed(a) < $signed(b) ? c : zero;
		FN_ZSLE:	bus = $signed(a) <= $signed(b) ? c : zero;
		FN_ZSLTU:	bus = a < b ? c : zero;
		FN_ZSLEU:	bus = a <= b ? c : zero;

		FN_ZSEQI8: bus = a==b ? immc8 : zero;
		FN_ZSNEI8:	bus = a!=b ? immc8 : zero;
		FN_ZSLTI8:	bus = $signed(a) < $signed(b) ? immc8 : zero;
		FN_ZSLEI8:	bus = $signed(a) <= $signed(b) ? immc8 : zero;
		FN_ZSLTUI8:	bus = a < b ? immc8 : zero;
		FN_ZSLEUI8:	bus = a <= b ? immc8 : zero;

		FN_MINMAX:
			case(ir.r3.op4)
			3'd0:	// MIN
				begin
					if ($signed(a) < $signed(b) && $signed(a) < $signed(c))
						bus = a;
					else if ($signed(b) < $signed(c))
						bus = b;
					else
						bus = c;
				end
			3'd1:	// MAX
				begin
					if ($signed(a) > $signed(b) && $signed(a) > $signed(c))
						bus = a;
					else if ($signed(b) > $signed(c))
						bus = b;
					else
						bus = c;
				end
			3'd2:	// MID
				begin
					if ($signed(a) > $signed(b) && $signed(a) < $signed(c))
						bus = a;
					else if ($signed(b) > $signed(a) && $signed(b) < $signed(c))
						bus = b;
					else
						bus = c;
				end
			3'd4:	// MINU
				begin
					if (a < b && a < c)
						bus = a;
					else if (b < c)
						bus = b;
					else
						bus = c;
				end
			3'd5:	// MAXU
				begin
					if (a > b && a > c)
						bus = a;
					else if (b > c)
						bus = b;
					else
						bus = c;
				end
			3'd6:	// MIDU
				begin
					if (a > b && a < c)
						bus = a;
					else if (b > a && b < c)
						bus = b;
					else
						bus = c;
				end
			default:	bus = {4{32'hDEADBEEF}};
			endcase
		FN_MVVR:	bus = a;
		FN_VSETMASK:	bus = ALU0 ? vmasko : dead;
		default:	bus = {4{32'hDEADBEEF}};
		endcase
	OP_CSR:		bus = csr;

	OP_ADDI:
		begin
			bus = a + i;
		end

	OP_SUBFI:	bus = i - a;
	OP_CMPI:
		bus = cmpo;
	OP_CMPUI:	bus = cmpo;
	OP_MULI:
		bus = prod[WID-1:0];
	OP_MULUI:	bus = produ[WID-1:0];
	OP_DIVI:
		begin
			bus = ALU0 ? div_q : dead;
			if (div_dbz)
				exc = FLT_DBZ;
		end
	OP_DIVUI:	bus = ALU0 ? div_q : dead;
	OP_ANDI:
		bus = a & i;
	OP_ORI:
		bus = a | i;
	OP_EORI:
		bus = a ^ i;
	OP_AIPUI:
		if (WID >= 32)
		 	bus = pc + ({{WID{i[36]}},i[36:0]} << (ir[23:22]*32));
		else
			bus = zero;
	OP_SHIFTB,OP_SHIFTW,OP_SHIFTT,OP_SHIFTO:
		case(ir.lshifti.func)
		OP_ASL:	bus = shl[WID*2-1:WID];
		OP_LSR:	bus = shr[WID-1:0];
		OP_ASR:	
			case(ir[46:44])
			3'd2:	bus = asr[WID*2-1:WID];
			3'd3: bus = asr[WID*2-1] ? asr[WID*2-1:WID] + asr[WID-1] : asr[WID*2-1:WID];
			3'd4: bus = asr[WID*2-1:WID] + asr[WID-1];
			default:	bus = asr[WID*2-1:WID];
			endcase
		default:	bus = {(WID/16){16'hDEAD}};
		endcase

	OP_ZSEQI:	bus = a==i;
	OP_ZSNEI:	bus = a!=i;
	OP_ZSLTI:	bus = $signed(a) < $signed(i);
	OP_ZSLEI:	bus = $signed(a) <= $signed(i);
	OP_ZSLTUI:	bus = a < i;
	OP_ZSLEUI:	bus = a <= i;
	OP_ZSGTI: bus = $signed(a) > $signed(i);
	OP_ZSGEI: bus = $signed(a) >= $signed(i);
	OP_ZSGTUI: bus = a > i;
	OP_ZSGEUI: bus = a >= i;
	OP_SEQI:	bus = a==i ? 64'd1 : t;
	OP_SNEI:	bus = a!=i ? 64'd1 : t;
	OP_SLTI:	bus = $signed(a) < $signed(i) ? 64'd1 : t;
	OP_SLEI:	bus = $signed(a) <= $signed(i) ? 64'd1 : t;
	OP_SLTUI:	bus = a < i ? 64'd1 : t;
	OP_SLEUI:	bus = a <= i ? 64'd1 : t;
	OP_SGTI: bus = $signed(a) > $signed(i) ? 64'd1 : t;
	OP_SGEI: bus = $signed(a) >= $signed(i) ? 64'd1 : t;
	OP_SGTUI: bus = a > i ? 64'd1 : t;
	OP_SGEUI: bus = a >= i ? 64'd1 : t;

	OP_MOV:		bus = a;
	OP_LDA:		bus = a + i + (b << ir[31:29]);
	OP_BLEND:	bus = ALU0 ? blendo : dead;
	OP_PFX:		bus = zero;
	OP_NOP:		bus = t;	// in case of copy target
	OP_QFEXT:	bus = qres;
	// Write the next PC to the link register.
	OP_BSR,OP_JSR:
		begin
		/*
			if (SUPPORT_CAPABILITIES) begin
				tCapGetBaseTop(pcc, base, top);
				obase = base;
				otop = top;
				tCapEncodeBaseTop(pcc.a + 4'd6, base, top, Lmsb, Ct);
				Ct.perms = pcc.perms;
				Ct.flags = pcc.flags;
				tCapGetBaseTop(Ct, base, top);
				// new base, top matches old, and not sealed.
				if (base == obase && top == otop && pcc.otype!=4'hE)
					otag = atag;
				Ct.otype = 4'hE;	// seal
				bus = Ct;
			end
			else
		*/
				bus = pc + 4'd8;
		end
	OP_RTD:
		begin
		/*
			if (SUPPORT_CAPABILITIES) begin
				tCapGetBaseTop(Cb, base, top);
				obase = base;
				otop = top;
				tCapEncodeBaseTop(Cb.a + i, base, top, Lmsb, Ct);
				Ct.perms = Cb.perms;
				Ct.flags = Cb.flags;
				tCapGetBaseTop(Ct, base, top);
				// new base, top matches old, and not sealed.
				if (base == obase && top == otop)
					otag = atag;
				Ct.otype = 4'hF;	// unseal
				bus = Ct;
			end
			else
		*/
				bus = b + i;
		end
	OP_IBcc,OP_IBccR:	bus = a + 2'd1;
	OP_DBcc,OP_DBccR:	bus = a - 2'd1;

	OP_BFND, OP_BCMP:
		bus = (bebfifo_overflow & ld2) ? 64'd0 : {58'd0,bebfifo_din.handle};

	OP_BLOCK:
		case(ir.block.op)
		default:	bus = 64'd0;
		endcase

	OP_PRED:	bus = a;

	default:	bus = {(WID/16){16'hDEAD}};
	endcase
end

always_ff @(posedge clk)
	o = bus;
always_ff @(posedge clk)
	exc_o = exc;

endmodule
