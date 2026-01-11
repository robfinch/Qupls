// ============================================================================
//        __
//   \\__/ o\    (C) 2024-2026  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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
// Allocate up to four registers per clock.
// We need to be able to free many more registers than are allocated in the 
// event of a pipeline flush. Normally up to four register values will be
// committed to the register file.
//
// A bitmap of available registers is used, which is divided into four equal 
// parts. 
// One available register is selected "popped" from each part of the bitmap
// when needed using a find-first-one module.
// The parts of the bitmap are rotated after a register is "popped" so that
// registers are not reused too soon. This prevents pipelining issues.
// Freeing the register, a "push", is simple, the register is just marked
// available in the bitmap.
// For a checkpoint restore, the available register map is simply copied from
// the checkpoint.
// 
// 300 LUTs / 310 FFs / 2 BRAMs / 350 MHz (512 regs)
// ============================================================================
//
import const_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;

module Qupls4_reg_name_supplier7(rst,clk,en,tags2free,freevals,
	o, ov,
	ns_alloc_req, ns_whrndx, ns_cndx, ns_rndx, ns_dstreg, ns_dstregv,
	avail,stall,rst_busy
);
parameter NFTAGS = Qupls4_pkg::MWIDTH;	// Number of register freed per clock.
parameter NNAME = Qupls4_pkg::MWIDTH;
input rst;
input clk;
input en;
input cpu_types_pkg::pregno_t [NFTAGS-1:0] tags2free;		// register tags to free
input [NFTAGS-1:0] freevals;					// bitmnask indicating which tags to free
output pregno_t [NNAME-1:0] o;
output reg [NNAME-1:0] ov;
input [NNAME-1:0] ns_alloc_req;
input rob_ndx_t [NNAME-1:0] ns_whrndx;
input checkpt_ndx_t [NNAME-1:0] ns_cndx;
output rob_ndx_t [NNAME-1:0] ns_rndx;
output cpu_types_pkg::pregno_t [NNAME-1:0] ns_dstreg;
output reg [NNAME-1:0] ns_dstregv;
output reg [Qupls4_pkg::PREGS-1:0] avail = {Qupls4_pkg::PREGS{1'b1}};
output reg stall;											// stall enqueue while waiting for register availability
output reg rst_busy;									// not used

typedef struct packed {
	logic [1:0] port;
	logic [9:0] count;
} port_t;

port_t pa [4];

integer n1,n2,n3,n4,n5,n6,n7,n8;
reg [3:0] jj;
genvar g;
wire wr_clk = clk;

wire [NNAME-1:0] data_valid;
wire [NNAME-1:0] empty;
wire [NNAME-1:0] full;
wire [6:0] dout [0:NNAME-1];
/*
wire data_valid;
wire empty;
wire full;
wire [39:0] dout;
*/
reg [6:0] din [0:NNAME-1];
//reg [9:0] din;
//wire rd_rst_busy;
//wire wr_rst_busy;
wire [NNAME-1:0] rd_rst_busy;
wire [NNAME-1:0] wr_rst_busy;
wire [8:0] wr_data_count [0:NNAME-1];
wire [8:0] rd_data_count [0:NNAME-1];
//wire [8:0] wr_data_count;
reg [NNAME-1:0] rd_en, wr_en;
wire [16:0] lfsro;
reg rst_rd;

cpu_types_pkg::pregno_t [NFTAGS-1:0] rtags2free;
reg [NNAME-1:0] fpop = 4'd0;
reg [NNAME-1:0] stalla = {NNAME{1'b0}};
reg [Qupls4_pkg::PREGS-1:0] next_avail;
reg [Qupls4_pkg::PREGS-1:0] availv;
reg [NNAME-1:0] freevals1;

reg [7:0] rstcnt;
reg irst;
reg [$clog2(Qupls4_pkg::PREGS)-3:0] freeCnt;
reg [2:0] ffreeCnt;
reg [Qupls4_pkg::PREGS-1:0] next_toFreeList;
reg [Qupls4_pkg::PREGS-1:0] toFreeList;
reg [NNAME-1:0] ffree;

reg [NNAME-1:0] fpush;
reg [NNAME-1:0] ovr;

always_comb irst = ~rstcnt[7];
always_comb stall = |stalla;
always_comb rst_busy = irst;

always_comb
if (Qupls4_pkg::PREGS != 512 && Qupls4_pkg::PREGS != 256) begin
	$display("Qupls4 CPU renamer: number of registers must be 256 or 512");
	$finish;
end

always_comb
begin
	foreach (stalla[n4]) begin
		// Not a stall if not allocating.
		stalla[n4] = ~data_valid[n4] & ns_alloc_req[n4];
		ov[n4] = ((data_valid[n4] & ns_alloc_req[n4]) | (ovr[n4] & ~en)) && ns_cndx[n4]==ns_cndx[n4];
	end
end

// Do not do a pop if stalling on another slot.
// Do a pop only if allocating
always_comb
	foreach (fpop[n5])
		fpop[n5] = (data_valid[n5] & ns_alloc_req[n5] & en & ~stall) | (data_valid[n5] & stalla[n5]);

always_comb
	foreach (rd_en[n8])
		rd_en[n8] = fpop[n8]|{NNAME{rst_rd}};

always_ff @(posedge clk)
begin
	if (en) begin
		ovr <= 4'h0;
	end
	else begin
		ovr <= ov;
	end
end

lfsr17 ulfsr1
(
	.rst(rst),
	.clk(clk),
	.ce(1'b1),
	.cyc(1'b0),
	.o(lfsro)
);


generate begin : gFIFOs
	for (g = 0; g < NNAME; g = g + 1)
   // xpm_fifo_sync: Synchronous FIFO
   // Xilinx Parameterized Macro, version 2025.1

   xpm_fifo_sync #(
      .CASCADE_HEIGHT(0),            // DECIMAL
      .DOUT_RESET_VALUE("0"),        // String
      .ECC_MODE("no_ecc"),           // String
      .EN_SIM_ASSERT_ERR("warning"), // String
      .FIFO_MEMORY_TYPE("auto"),     // String
      .FIFO_READ_LATENCY(1),         // DECIMAL
      .FIFO_WRITE_DEPTH(512),     	// DECIMAL
      .FULL_RESET_VALUE(0),          // DECIMAL
      .PROG_EMPTY_THRESH(10),        // DECIMAL
      .PROG_FULL_THRESH(10),         // DECIMAL
      .RD_DATA_COUNT_WIDTH($clog2(512)),      // DECIMAL
      .READ_DATA_WIDTH(7),          // DECIMAL
      .READ_MODE("fwft"),             // String
      .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      .USE_ADV_FEATURES("1F07"),     // String
      .WAKEUP_TIME(0),               // DECIMAL
      .WRITE_DATA_WIDTH(7),         // DECIMAL
      .WR_DATA_COUNT_WIDTH($clog2(512))        // DECIMAL
   )
   name_fifo (
      .almost_empty(),   // 1-bit output: Almost Empty : When asserted, this signal indicates that only one more read can be performed
                                     // before the FIFO goes to empty.

      .almost_full(),     // 1-bit output: Almost Full: When asserted, this signal indicates that only one more write can be performed
                                     // before the FIFO is full.

      .data_valid(data_valid[g]),       // 1-bit output: Read Data Valid: When asserted, this signal indicates that valid data is available on the
                                     // output bus (dout).

      .dbiterr(),             // 1-bit output: Double Bit Error: Indicates that the ECC decoder detected a double-bit error and data in the
                                     // FIFO core is corrupted.

      .dout(dout[g]),                   // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven when reading the FIFO.
      .empty(empty[g]),                 // 1-bit output: Empty Flag: When asserted, this signal indicates that the FIFO is empty. Read requests are
                                     // ignored when the FIFO is empty, initiating a read while empty is not destructive to the FIFO.

      .full(full[g]),                   // 1-bit output: Full Flag: When asserted, this signal indicates that the FIFO is full. Write requests are
                                     // ignored when the FIFO is full, initiating a write when the FIFO is full is not destructive to the contents of
                                     // the FIFO.

      .overflow(),           // 1-bit output: Overflow: This signal indicates that a write request (wren) during the prior clock cycle was
                                     // rejected, because the FIFO is full. Overflowing the FIFO is not destructive to the contents of the FIFO.

      .prog_empty(),       // 1-bit output: Programmable Empty: This signal is asserted when the number of words in the FIFO is less than
                                     // or equal to the programmable empty threshold value. It is de-asserted when the number of words in the FIFO
                                     // exceeds the programmable empty threshold value.

      .prog_full(),         // 1-bit output: Programmable Full: This signal is asserted when the number of words in the FIFO is greater than
                                     // or equal to the programmable full threshold value. It is de-asserted when the number of words in the FIFO is
                                     // less than the programmable full threshold value.

      .rd_data_count(rd_data_count[g]), // RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates the number of words read from the FIFO.
      .rd_rst_busy(rd_rst_busy[g]),     // 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read domain is currently in a reset state.
      .sbiterr(),             // 1-bit output: Single Bit Error: Indicates that the ECC decoder detected and fixed a single-bit error.
      .underflow(),         // 1-bit output: Underflow: Indicates that the read request (rd_en) during the previous clock cycle was rejected
                                     // because the FIFO is empty. Under flowing the FIFO is not destructive to the FIFO.

      .wr_ack(),               // 1-bit output: Write Acknowledge: This signal indicates that a write request (wr_en) during the prior clock
                                     // cycle is succeeded.

      .wr_data_count(wr_data_count[g]), // WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates the number of words written into the
                                     // FIFO.

      .wr_rst_busy(wr_rst_busy[g]),     // 1-bit output: Write Reset Busy: Active-High indicator that the FIFO write domain is currently in a reset
                                     // state.

      .din(din[g]),                     // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when writing the FIFO.
      .injectdbiterr(1'b0), // 1-bit input: Double Bit Error Injection: Injects a double bit error if the ECC feature is used on block RAMs
                                     // or UltraRAM macros.

      .injectsbiterr(1'b0), // 1-bit input: Single Bit Error Injection: Injects a single bit error if the ECC feature is used on block RAMs
                                     // or UltraRAM macros.

      .rd_en(rd_en[g] & ~rd_rst_busy[g]),       // 1-bit input: Read Enable: If the FIFO is not empty, asserting this signal causes data (on dout) to be read
                                     // from the FIFO. Must be held active-low when rd_rst_busy is active high.

      .rst(rst),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be unstable at the time of applying
                                     // reset, but reset must be released only after the clock(s) is/are stable.

      .sleep(1'b0),                 // 1-bit input: Dynamic power saving- If sleep is High, the memory/fifo block is in power saving mode.
      .wr_clk(wr_clk),               	// 1-bit input: Write clock: Used for write operation. wr_clk must be a free running clock.
      .wr_en(wr_en[g] & ~rd_rst_busy[g] & ~wr_rst_busy[g])                  // 1-bit input: Write Enable: If the FIFO is not full, asserting this signal causes data (on din) to be written
                                     // to the FIFO Must be held active-low when rst or wr_rst_busy or rd_rst_busy is active high

   );

   // End of xpm_fifo_sync_inst instantiation
end
endgenerate
		

// The following checks should always fail as it is not possible in properly
// running hardware to get the same register on a different port.
always_comb
if (0) begin
	if (o[0]==o[1] || o[0]==o[2] || o[0]==o[3]) begin
		$display("Qupls4CPU: matching rename registers");
		$finish;
	end
	if (o[1]==o[2] || o[1]==o[3]) begin
		$display("Qupls4CPU: matching rename registers");
		$finish;
	end
	if (o[2]==o[3]) begin
		$display("Qupls4CPU: matching rename registers");
		$finish;
	end
end

// Freed tags cannot be reused for 15 clock cycles.
generate begin : gFree
	for (g = 0; g < NNAME; g = g + 1)
		vtdl #(.WID($bits(cpu_types_pkg::pregno_t)), .DEP(16)) uaramp1 (.clk(clk), .ce(1'b1), .a(15), .d(tags2free[g]), .q(rtags2free[g]));
end
endgenerate

vtdl #(.WID(NNAME), .DEP(16)) uarampfv1 (.clk(clk), .ce(1'b1), .a(15), .d(freevals), .q(fpush));

always_ff @(posedge clk)
if (rst|rd_rst_busy| (|wr_rst_busy))
	rstcnt <= 8'd0;
else begin
	if (!rstcnt[7])
		rstcnt <= rstcnt + 2'd1;
end

always_ff @(posedge clk)
if (rst)
	rst_rd <= 1'b0;
else begin
	if (&rstcnt[6:2])
		rst_rd <= 1'b1;
	else if (data_valid)
		rst_rd <= 1'b0;
end

always_comb
begin
	pa[0].count = wr_data_count[0];
	pa[1].count = wr_data_count[1];
	pa[2].count = wr_data_count[2];
	pa[3].count = wr_data_count[3];
	pa[0].port = 2'd0;
	pa[1].port = 2'd1;
	pa[2].port = 2'd2;
	pa[3].port = 2'd3;
	pa.sort with (item.count);
end

always_ff @(posedge clk)
if (rst|rd_rst_busy| (|wr_rst_busy)) begin
	for (n7 = 0; n7 < NNAME; n7 = n7 + 1)
		din[n7] <= 10'd0;
	wr_en <= {NNAME{1'b0}};
	jj <= 4'd0;
end
else begin
	wr_en <= 4'd0;
	if (irst) begin
		for (n7 = 0; n7 < NNAME; n7 = n7 + 1)
			din[n7] <= (rstcnt * NNAME) + n7;
		wr_en <= {NNAME{1'b1}};
		jj <= 4'd0;
	end
	else begin
		if (fpush[0]) begin
			wr_en[pa[0].port] <= VAL;
			din[pa[0].port] <= rtags2free[0];
			if (fpush[1]) begin
				wr_en[pa[1].port] <= VAL;
				din[pa[1].port] <= rtags2free[1];
				if (fpush[2]) begin
					wr_en[pa[2].port] <= VAL;
					din[pa[2].port] <= rtags2free[2];
					if (fpush[3]) begin
						wr_en[pa[3].port] <= VAL;
						din[pa[3].port] <= rtags2free[3];
					end
				end
			end
		end
		else if (fpush[1]) begin
			wr_en[pa[0].port] <= VAL;
			din[pa[0].port] <= rtags2free[1];
			if (fpush[2]) begin
				wr_en[pa[1].port] <= VAL;
				din[pa[1].port] <= rtags2free[2];
				if (fpush[3]) begin
					wr_en[pa[2].port] <= VAL;
					din[pa[2].port] <= rtags2free[3];
				end
			end
		end
		else if (fpush[2]) begin
			wr_en[pa[0].port] <= VAL;
			din[pa[0].port] <= rtags2free[2];
			if (fpush[3]) begin
				wr_en[pa[1].port] <= VAL;
				din[pa[1].port] <= rtags2free[3];
			end
		end
		else if (fpush[3]) begin
			wr_en[pa[0].port] <= VAL;
			din[pa[0].port] <= rtags2free[3];
		end
/*
		foreach (din[n7]) begin
			if (fpush[0]) begin din[wrport[0]] <= rtags2free[0]; wr_en[wrport[0]] <= fpush[0]; end
			if (fpush[1]) begin din[wrport[1]] <= rtags2free[1]; wr_en[wrport[1]] <= fpush[1]; end
			if (fpush[2]) begin din[wrport[2]] <= rtags2free[2]; wr_en[wrport[2]] <= fpush[2]; end
			if (fpush[3]) begin din[wrport[3]] <= rtags2free[3]; wr_en[wrport[3]] <= fpush[3]; end
			// Select FIFO data input from a random tag being freed.
			din[n7] <= rtags2free[(jj+n7)%NNAME];//rtags2free[n7][6:0];//
			// Use write enable for tag being freed.
			wr_en[n7] <= fpush[(jj+n7)%NNAME];//fpush[n7];//
		end
		jj <= jj + 4'd1;
*/
	end
	
end

checkpt_ndx_t last_cndx;
generate begin : gOut
	for (g = 0; g < NNAME; g = g + 1)
always_comb
begin
	last_cndx = ns_cndx[0];
	ns_dstregv[g] = INV;
	ns_dstreg[g] = 9'd0;
	ns_rndx[g] = 6'd0;
	if (ns_alloc_req[g]) begin
//		if (last_cndx==ns_cndx[n1]) begin
			ns_rndx[g] = ns_whrndx[g];
			ns_dstreg[g] = {g[1:0],dout[g][6:0]};
			ns_dstregv[g] = data_valid;
//		end
	end
end
end
endgenerate

endmodule
