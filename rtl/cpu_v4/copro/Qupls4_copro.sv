`timescale 1ns / 1ps
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
//    contributors may be used to endorse or pnext_irte products derived from
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
// 7250 LUTs / 10500 FFs / 8 BRAMs / 170 MHz	(default synth)
// 6850 LUTs / 10500 FFs / 8 BRAMs / 145 MHz	(area synth)
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import wishbone_pkg::*;
import mmu_pkg::*;
import Qupls4_copro_pkg::*;

module Qupls4_copro(rst, clk, sbus, mbus, cs_copro, miss, miss_adr, miss_asid,
  missack, paging_en, page_fault, iv_count, missack, idle,
  vclk, hsync_i, vsync_i, gfx_que_empty_i,
  flush_en, flush_trig, flush_asid, flush_done, cmd_done);
parameter UNALIGNED_CONSTANTS = 0;
parameter JUMP_INDIRECT = 0;
parameter NUM_PAGESIZES = 1;
parameter LOG_PAGESIZE = 13;	// log2 of size of page
parameter LOG_TLB_ENTRIES = 9;
input rst;
input clk;
wb_bus_interface.slave sbus;
wb_bus_interface.master mbus;
input cs_copro;
input [2:0] miss;
input address_t [2:0] miss_adr;
input asid_t [2:0] miss_asid;
output reg missack;
output reg idle;
output reg paging_en;
output reg page_fault;
output reg flush_en;
output asid_t flush_asid;
output reg flush_trig;
input flush_done;
output reg cmd_done;
input [3:0] iv_count [0:2];
input vclk;
input hsync_i;
input vsync_i;
input gfx_que_empty_i;

integer n1;
copro_state_t state;
copro_state_t [3:0] state_stack;

copro_instruction_t ir,ir2;

// register file
reg [63:0] r1=0,r2=0,r3=0,r4=0,r5=0,r6=0,r7=0;
reg [63:0] r8=0,r9=0,r10=0,r11=0,r12=0,r13=0,r14=0,r15=0,tmp=0;
// Operands
reg [31:0] imm;
reg [63:0] a,b;
reg [63:0] res;
wire [17:2] next_ip;
reg [17:2] ip,ipr;					// instruction pointer
reg ip2;
(* ram_style="distributed" *)
reg [512+17:0] stack [0:15];
reg [3:0] sp;
reg [31:0] roma;
reg local_sel;// = (state==st_mem_load|state==st_mem_store) & roma[31:16]==16'h0000;
wire rsta = rst;
wire rstb = sbus.rst;
wire clka = clk;
wire clkb = sbus.clk;
wire ena = 1'b1;
wire enb = sbus.req.cyc & sbus.req.stb & cs_copro & ~sbus.req.adr[16];
wire wea = mbus.req.we & local_sel & ~mbus.req.adr[16];
wire web = sbus.req.we & cs_copro & ~sbus.req.adr[16];
wire [11:0] addra = local_sel ? roma[14:3] : ip[14:3];
wire [11:0] addrb = sbus.req.adr[14:3];
wire [63:0] dina = mbus.req.dat;
wire [63:0] dinb = sbus.req.dat;
wire [63:0] douta;
wire [63:0] doutb;
reg [31:0] next_ir;
reg [63:0] mem_val;
always_comb
	next_ir = ip2 ? douta[63:32] : douta[31:0];
reg sleep;
reg rfwr;
reg cs;
wire dly2;
wire takb;

reg [31:0] entry_no;
reg [63:0] cmd,stat;
tlb_entry_t tlbe,tlbe2;
ptattr_t [2:0] ptattr;
address_t [2:0] ptbr;
reg clear_page_fault;
reg [2:0] miss1;
address_t [2:0] miss_adr1;
asid_t [2:0] miss_asid1;
reg [3:0] flush_trig1;
reg [63:0] arg_dat;
reg wait_active;
reg [3:0] wait_cond;
wire [31:0] icnt;			// count with one decimal point
reg [31:0] icnta;			// How much to increment by
wire [31:0] tick;			// running count of clocks since reset

// Validate parameters
always_comb
begin
	if (NUM_PAGESIZES < 1) begin
		$display("Q4 Copro: must have at least one page size.");
		$finish;
	end
	if (NUM_PAGESIZES > 8) begin
		$display("Q4 Copro: too many page sizes.");
		$finish;
	end
	if (LOG_TLB_ENTRIES > 16) begin
		$display("Q4 Copro: too many TLB entries.");
		$finish;
	end
end

always_ff @(posedge clk)
	ip2 <= ip[2];

always_comb
	cs = cs_copro & sbus.req.cyc & sbus.req.stb;
delay2 udly2 (.clk(clk), .ce(1'b1), .i(cs), .o(dly2));

always_ff @(posedge sbus.clk)
if (sbus.rst) begin
	ptbr[0] <= 64'hFFFFFFFFFF800000;
	ptbr[1] <= 64'hFFFFFFFFFF802000;
	ptattr[0] <= 64'd0;
	ptattr[0].level <= 3'd1;
	ptattr[0].pgsz <= LOG_PAGESIZE;
	ptattr[0].log_te <= LOG_TLB_ENTRIES;
	ptattr[1] <= 64'd0;
	ptattr[1].level <= 3'd1;
	ptattr[1].pgsz <= 5'd23;
	ptattr[1].log_te <= 5'd7;
	ptattr[2] <= 64'd0;
	ptattr[2].level <= 3'd1;
	ptattr[2].pgsz <= 5'd23;
	ptattr[2].log_te <= 5'd7;
	sbus.resp <= {$bits(wb_cmd_response64_t){1'b0}};
	clear_page_fault <= FALSE;
	entry_no <= 32'd0;
	cmd <= 64'd0;
end
else begin
	clear_page_fault <= FALSE;
	if (cs_copro & sbus.req.cyc & sbus.req.stb) begin
		sbus.resp.tid <= sbus.req.tid;	
		sbus.resp.pri <= sbus.req.pri;
		if (sbus.req.we)
			casez(sbus.req.adr[14:3])
			// FC0 to FCF read-only
			12'hFA0:	clear_page_fault <= TRUE;
			12'hFC0:	ptbr[0] <= sbus.req.dat;
			12'hFC2:	ptattr[0] <= sbus.req.dat;
			12'hFC4:	ptbr[1] <= sbus.req.dat;
			12'hFC6:	ptattr[1] <= sbus.req.dat;
			12'hFC8:	ptbr[2] <= sbus.req.dat;
			12'hFCA:	ptattr[2] <= sbus.req.dat;
			default:	;
			endcase
		ptattr[0].pgsz <= LOG_PAGESIZE;
		ptattr[0].log_te <= LOG_TLB_ENTRIES;
		casez(sbus.req.adr[14:3])
		// To 12'hFDF
		12'hFC0:	sbus.resp.dat <= ptbr[0];
		12'hFC2:	sbus.resp.dat <= ptattr[0];
		12'hFC4:	sbus.resp.dat <= ptbr[1];
		12'hFC6:	sbus.resp.dat <= ptattr[1];
		12'hFC8:	sbus.resp.dat <= ptbr[2];
		12'hFCA:	sbus.resp.dat <= ptattr[2];
		12'hFE0:	sbus.resp.dat <= miss_adr1[0];
		12'hFE1:	sbus.resp.dat <= miss_asid1[0];
		12'hFE2:	sbus.resp.dat <= miss_adr1[1];
		12'hFE3:	sbus.resp.dat <= miss_asid1[1];
		12'hFE4:	sbus.resp.dat <= miss_adr1[2];
		12'hFE5:	sbus.resp.dat <= miss_asid1[2];
		default:	sbus.resp.dat <= doutb;
		endcase
		sbus.resp.ack <= dly2;
	end
	else
		sbus.resp.ack <= LOW;
end

wire [15:0] hpos, vpos;
wire [15:0] hpos_mask = b[15: 0];
wire [15:0] vpos_mask = b[31:16];
wire [15:0] hpos_masked = hpos & hpos_mask;
wire [15:0] vpos_masked = vpos & vpos_mask;
wire [15:0] hpos_wait = a[15: 0];
wire [15:0] vpos_wait = a[31:16];
			
wire pe_hsync;
wire pe_vsync;
wire pe_vsync2;
edge_det edh1
(
	.rst(rst),
	.clk(vclk),
	.ce(1'b1),
	.i(hsync_i),
	.pe(pe_hsync),
	.ne(),
	.ee()
);

edge_det edv1
(
	.rst(rst),
	.clk(vclk),
	.ce(1'b1),
	.i(vsync_i),
	.pe(pe_vsync),
	.ne(),
	.ee()
);

edge_det edv2
(
	.rst(rst),
	.clk(clk),
	.ce(1'b1),
	.i(vsync_i),
	.pe(pe_vsync2),
	.ne(),
	.ee()
);

// Raw scanline counter
vid_counter #(16) u_vctr (.rst(sym_rst), .clk(vclk), .ce(pe_hsync), .ld(pe_vsync), .d(16'd0), .q(vpos), .tc());
vid_counter #(16) u_hctr (.rst(sym_rst), .clk(vclk), .ce(1'b1), .ld(pe_hsync), .d(16'd0), .q(hpos), .tc());

// xpm_memory_tdpram: True Dual Port RAM
// Xilinx Parameterized Macro, version 2025.1

xpm_memory_tdpram #(
  .ADDR_WIDTH_A(12),              // DECIMAL
  .ADDR_WIDTH_B(12),              // DECIMAL
  .AUTO_SLEEP_TIME(0),            // DECIMAL
  .BYTE_WRITE_WIDTH_A(64),        // DECIMAL
  .BYTE_WRITE_WIDTH_B(64),        // DECIMAL
  .CASCADE_HEIGHT(0),             // DECIMAL
  .CLOCKING_MODE("independent_clock"), // String
  .ECC_BIT_RANGE("7:0"),          // String
  .ECC_MODE("no_ecc"),            // String
  .ECC_TYPE("none"),              // String
  .IGNORE_INIT_SYNTH(0),          // DECIMAL
  .MEMORY_INIT_FILE("ptw.mem"),   // String
  .MEMORY_INIT_PARAM("0"),        // String
  .MEMORY_OPTIMIZATION("true"),   // String
  .MEMORY_PRIMITIVE("auto"),      // String
  .MEMORY_SIZE(4096*64),          // DECIMAL
  .MESSAGE_CONTROL(0),            // DECIMAL
  .RAM_DECOMP("auto"),            // String
  .READ_DATA_WIDTH_A(64),         // DECIMAL
  .READ_DATA_WIDTH_B(64),         // DECIMAL
  .READ_LATENCY_A(1),             // DECIMAL
  .READ_LATENCY_B(1),             // DECIMAL
  .READ_RESET_VALUE_A("0"),       // String
  .READ_RESET_VALUE_B("0"),       // String
  .RST_MODE_A("SYNC"),            // String
  .RST_MODE_B("SYNC"),            // String
  .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
  .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
  .USE_MEM_INIT(1),               // DECIMAL
  .USE_MEM_INIT_MMI(0),           // DECIMAL
  .WAKEUP_TIME("disable_sleep"),  // String
  .WRITE_DATA_WIDTH_A(64),        // DECIMAL
  .WRITE_DATA_WIDTH_B(64),        // DECIMAL
  .WRITE_MODE_A("no_change"),     // String
  .WRITE_MODE_B("no_change"),     // String
  .WRITE_PROTECT(1)               // DECIMAL
)
urom1 (
  .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence on the data output of port A.
  .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence on the data output of port A.
  .douta(douta),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
  .doutb(doutb),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
  .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence on the data output of port A.
  .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence on the data output of port B.
  .addra(addra),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
  .addrb(addrb),                   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
  .clka(clka),                     // 1-bit input: Clock signal for port A. Also clocks port B when parameter CLOCKING_MODE is "common_clock".
  .clkb(clkb),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is "independent_clock". Unused when
  .dina(dina),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
  .dinb(dinb),                     // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
  .ena(ena),                       // 1-bit input: Memory enable signal for port A. Must be high on clock cycles when read or write operations
  .enb(enb),                       // 1-bit input: Memory enable signal for port B. Must be high on clock cycles when read or write operations
  .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when ECC enabled (Error injection capability
  .injectdbiterrb(1'b0), // 1-bit input: Controls double bit error injection on input data when ECC enabled (Error injection capability
  .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when ECC enabled (Error injection capability
  .injectsbiterrb(1'b0), // 1-bit input: Controls single bit error injection on input data when ECC enabled (Error injection capability
  .regcea(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output data path.
  .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output data path.
  .rsta(rsta),                     // 1-bit input: Reset signal for the final port A output register stage. Synchronously resets output port
  .rstb(rstb),                     // 1-bit input: Reset signal for the final port B output register stage. Synchronously resets output port
  .sleep(sleep),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
  .wea(wea),                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector for port A input data port dina. 1 bit
  .web(web)                        // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector for port B input data port dinb. 1 bit
);

// End of xpm_memory_tdpram_inst instantiation
				
// Source operand multiplexers.
always_comb
	case(ir.Rs1)
	4'd1:	a = r1;
	4'd2:	a = r2;
	4'd3:	a = r3;
	4'd4:	a = r4;
	4'd5:	a = r5;
	4'd6:	a = r6;
	4'd7:	a = r7;
	4'd8:	a = r8;
	4'd9:	a = r9;
	4'd10:	a = r10;
	4'd11:	a = r11;
	4'd12:	a = r12;
	4'd13:	a = r13;
	4'd14:  a = r14;
	4'd15:	a = r15;
	default:	a = 64'd0;
	endcase

always_comb
	case(ir.Rs2)
	4'd1:	b = r1;
	4'd2:	b = r2;
	4'd3:	b = r3;
	4'd4:	b = r4;
	4'd5:	b = r5;
	4'd6:	b = r6;
	4'd7:	b = r7;
	4'd8:	b = r8;
	4'd9:	b = r9;
	4'd10:	b = r10;
	4'd11:	b = r11;
	4'd12:	b = r12;
	4'd13:	b = r13;
	4'd14:  b = r14;
	4'd15:	b = r15;
	default:	b = 64'd0;
	endcase

wire scan_is_before_pos = hpos_masked <= hpos_wait && vpos_masked <= vpos_wait && (b[48] ? gfx_que_empty_i : 1'b1);
wire scan_is_after_pos = hpos_masked >= hpos_wait && vpos_masked >= vpos_wait && (b[48] ? gfx_que_empty_i : 1'b1);

// Evaluate branch condition
Qupls4_copro_branch_eval ube1
(
	.ir(ir),
	.a(a),
	.b(b),
	.after_pos(scan_is_after_pos),
	.before_pos(scan_is_before_pos),
	.takb(takb)
);

// Determine the next IP
Qupls4_copro_next_ip
#(
	.UNALIGNED_CONSTANTS(UNALIGNED_CONSTANTS)
)
unip1
(
	.rst(rst),
	.state(state),
	.wait_active(wait_active),
	.pe_vsync(pe_vsync2),
	.miss(miss),
	.paging_en(paging_en),
	.ir(ir),
	.takb(takb),
	.after_pos(scan_is_after_pos),
	.adr_hit(ir.Rd != 4'd0 && sbus.req.cyc && sbus.req.stb && sbus.req.we && sbus.req.adr[13:3]==ir.imm[14:4] && cs_copro),
	.a(a),
	.stack(stack),
	.sp(sp),
	.req(mbus.req),
	.resp(mbus.resp),
	.local_sel(local_sel),
	.roma(roma),
	.douta(douta),
	.arg_dat(arg_dat),
	.ip(ip),
	.next_ip(next_ip)
);

counter #(.WID(32)) utck1
(
	.rst(rst),
	.clk(clk),
	.ce(1'b1),
	.ld(1'b0),
	.d(32'd0),
	.q(tick),
	.tc()
);

count_accum #(.WID(32)) uca1
(
	.rst(rst),
	.clk(clk),
	.ce(1'b1),
	.ld(1'b0),
	.d(32'd0),
	.a(icnta),
	.q(icnt),
	.tc()
);

always_ff @(posedge clk)
if (rst)
	ip <= 16'd0;
else
	ip <= next_ip;

always_comb
	flush_trig = flush_trig1[0];

always @(posedge clk)
if (rst) begin
	ir <= {$bits(copro_instruction_t){1'b0}};
	stat <= 64'd0;
	miss_asid1 <= 16'h0;
	miss_adr1 <= {$bits(address_t){1'b0}};
	mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
	local_sel <= FALSE;
	missack <= FALSE;
	idle <= FALSE;
	paging_en <= TRUE;
	flush_en <= FALSE;
	rfwr <= FALSE;
	foreach(stack[n1])
		stack[n1] <= 530'd0;
	sp <= 4'd0;
	icnta <= 32'd0;
	wait_active <= FALSE;
	wait_cond <= 4'h0;
	flush_trig1 <= 4'h0;
  tGoto(st_reset);
end
else begin
	icnta <= 32'd0;
	missack <= FALSE;
	flush_trig1 <= {1'b0,flush_trig1[3:1]};
	if (clear_page_fault)
		page_fault <= FALSE;
	
	if (local_sel) begin
		if (state==st_mem_store)
			case(roma[12:3])
			default:	;
			endcase
		case(roma[12:3])
		10'h3E2:	arg_dat <= tlbe[63:0];
		10'h3E3:	arg_dat <= tlbe[127:64];
		default:	arg_dat <= 64'd0;
		endcase
	end

case(state)
st_reset:
	begin
		ir <= next_ir;
		tGoto(st_reset2);
	end
st_reset2:
	begin
		ir <= next_ir;
		tGoto(st_execute);
	end

// Check for interrupts and handle WAIT logic.
st_ifetch:
	begin
		icnta <= 2;
		ipr <= ip;
		rfwr <= FALSE;
		local_sel <= FALSE;
		ir <= next_ir;
		tGoto(st_execute);
		if (pe_vsync2) begin
			sleep <= FALSE;
			stack[(sp+15) % 16] <= {2'b01,ipr,r8,r7,r6,r5,r4,r3,r2,r1};
			sp <= sp - 1;
			wait_active <= FALSE;
			if (sleep)
				tCall(st_wakeup,st_ifetch);
			else
				tGoto(st_ifetch);
		end
		else if (|miss & paging_en) begin
			sleep <= FALSE;
			miss1 <= miss;
			miss_adr1 <= miss_adr[0];
			miss_asid1 <= miss_asid[0];
			paging_en <= FALSE;
			missack <= TRUE;
			stack[(sp+15) % 16] <= {2'b10,ipr,r8,r7,r6,r5,r4,r3,r2,r1};
			sp <= sp - 1;
			wait_active <= FALSE;
			if (sleep)
				tCall(st_wakeup,st_ifetch);
			else
				tGoto(st_ifetch);
		end
		else if (wait_active) begin
		// WAIT
		// WAIT stops waiting when:
		// a) the scan address is greater than the specified one (if this condition is set)
		// b) an interrupt occurred
		// c) a write cycle to a specified location occurred.
		// While waiting the local memory is put in low power mode.
			case(wait_cond)
			JGEP:
				if (hpos_masked >= hpos_wait && vpos_masked >= vpos_wait && (b[48] ? gfx_que_empty_i : 1'b1)) begin
					idle <= TRUE;
					sleep <= TRUE;
					icnta <= 1;
				end
				else begin
					wait_active <= FALSE;
					tCall(st_wakeup,st_ifetch);
				end
			default:
				// Wait at address
				if (ir.Rd != 4'd0 && 
					sbus.req.cyc && sbus.req.stb && sbus.req.we &&
					sbus.req.adr[13:3]==ir.imm[14:4] && cs_copro
				) begin
					rfwr <= TRUE;
					res <= sbus.req.dat;
					wait_active <= FALSE;
					tCall(st_wakeup,st_ifetch);
				end
				else begin
					ir <= ir;
					idle <= TRUE;
					sleep <= TRUE;
					icnta <= 1;
				end
			endcase
		end
	end

st_execute:	
	begin
		tGoto(st_writeback);
		case(ir.opcode)
		// The guts of wait needs to be in the ifetch state.
		// This is just a trigger here.
		OP_WAIT:
			begin
				wait_active <= TRUE;
				wait_cond <= ir.imm[3:0];
				tGoto(st_ifetch);
			end
		OP_LOAD_CONFIG:
			begin
				tmp = a[2:0]|imm[2:0];
				// Which TLB missed?
				r2 <= ptbr[tmp];
				r3 <= ptattr[tmp].pgsz;
				r4 <= ptattr[tmp].level;
				r1 <= miss_adr1[tmp];
				r5 <= miss_asid1[tmp];
				r6 <= iv_count[tmp];
			end

		// Conditional jumps
		// Conditional jumps need an exta state to allow the BRAM to be accessed
		// after the address change. So, we go to prefetch instead of ifetch.
		// We also do not want to go through writeback which would increment the
		// address.
		OP_JCC:
			case(ir.Rd)
			JEQ:	if (takb) tGoto(st_prefetch);
			JNE:	if (takb) tGoto(st_prefetch);
			JLT:	if (takb) tGoto(st_prefetch);
			JLE:	if (takb) tGoto(st_prefetch);
			JGE:	if (takb) tGoto(st_prefetch);
			JGT:	if (takb) tGoto(st_prefetch);
			DJNE:
				begin
					// Ugh, this update must be done here.
					tWriteback(ir.Rs1,a-1);
					if (takb)
						tGoto(st_prefetch);
				end
			JGEP:	if (takb) tGoto(st_prefetch);
			JLEP:	if (takb) tGoto(st_prefetch);
			default:	;
			endcase

		// Unconditional jumps / calls / return.
		OP_JMP:
			begin
				tGoto(st_prefetch);
				case(ir.Rd)
				4'd1:	// JSR
					begin
						stack[(sp+15) % 16] <= {2'b00,ip,r8,r7,r6,r5,r4,r3,r2,r1};
						sp <= sp - 1;
					end
				4'd2:	// RET
					begin
						case(stack[sp][529:528])
						2'b10:	begin paging_en <= TRUE; idle <= TRUE; end
						default:	;
						endcase
						if (ir.imm[0]) r1 <= stack[sp][ 63:  0];
						if (ir.imm[1]) r2 <= stack[sp][127: 64];
						if (ir.imm[2]) r3 <= stack[sp][191:128];
						if (ir.imm[3]) r4 <= stack[sp][255:192];
						if (ir.imm[4]) r5 <= stack[sp][319:256];
						if (ir.imm[5]) r6 <= stack[sp][383:320];
						if (ir.imm[6]) r7 <= stack[sp][447:384];
						if (ir.imm[7]) r8 <= stack[sp][511:448];
						sp <= sp + 1;
					end

				4'd8:	// JMP [d[Rn]]	(memory indirect)
					if (JUMP_INDIRECT) begin
						tmp = a + {{17{ir.imm[14]}},ir.imm};
						local_sel <= tmp[31:16]==16'h0000;
						mbus.req.cyc <= tmp[31:16]!=16'h0000;
						mbus.req.stb <= tmp[31:16]!=16'h0000;
						mbus.req.we <= LOW;
						mbus.req.sel <= 32'hFF << {tmp[4:3],3'b0};
						mbus.req.adr <= tmp;
						roma <= tmp;
						tGoto (st_ip_load);
					end

				default:	;
				endcase
			end

		// Accelerator instructions
		// We writeback results here to trim a clock cycle off of timing.
		OP_CALC_INDEX:
			begin
				tmp = ptattr[0].pgsz - 64'd3;
				tmp = tmp[5:0] * a[2:0] + ptattr[0].pgsz;
				tWriteback(ir.Rd,miss_adr1 >> tmp);
				tGoto(st_ifetch);
			end
		OP_CALC_ADR:
			begin
				tmp = (64'd1 << ptattr[0].pgsz) - 1;	// tmp = page size mask
				tmp = b & tmp;										// tmp = PTE index masked for 1024 entries in page
				tmp = tmp << 3;										// tmp = word index
				tWriteback(ir.Rd,a|tmp);
				tGoto(st_ifetch);
			end
		OP_BUILD_ENTRY_NO:
			begin
				tmp = {56'd0,b[7:0]} << 16;					// put way into position
				tmp = tmp | (64'h1 << ir.imm[5:0]);	// set TLBE set bit
				tmp = tmp | a[15:0];								// put read_adr into position
				tWriteback(ir.Rd,tmp);
				tGoto(st_ifetch);
			end
		OP_BUILD_VPN:
			begin
				tmp = miss_adr1 >> (ptattr[0].pgsz + ptattr[0].log_te);	// VPN = miss_adr >> (LOG_PAGESIZE + TLB_ABITS)
				tmp = tmp | ({64'd0,miss_asid1} << 48);// put ASID into position
				tmp = tmp | ({64'd0,iv_count[0]} << 42);	// put count into position
				tWriteback(ir.Rd,tmp);
				tGoto(st_ifetch);
			end
		OP_FLUSH:
			begin
				flush_asid <= a[15:0];
				flush_en <= ir.imm[0];
				flush_trig1 <= {4{ir.imm[1]}};
				rfwr <= TRUE;
				tWriteback(ir.Rd,{flush_done,63'd0});
				tGoto(st_ifetch);
			end

		// Memory ops
		OP_LOAD:
			begin
				tmp = a + {{17{ir.imm[14]}},ir.imm};
				local_sel <= tmp[31:16]==16'h0000;
				// ToDo fix cyc/stb
				mbus.req.cyc <= tmp[31:16]!=16'h0000;
				mbus.req.stb <= tmp[31:16]!=16'h0000;
				mbus.req.we <= LOW;
				mbus.req.sel <= 32'hFF << {tmp[4:3],3'b0};
				mbus.req.adr <= tmp;
				roma <= tmp;
				tGoto (st_mem_load);
			end
		OP_STORE:
			begin
				tmp = a + {{17{ir.imm[14]}},ir.imm};
				local_sel <= tmp[31:16]==16'h0000;
				mbus.req.cyc <= tmp[31:16]!=16'h0000;
				mbus.req.stb <= tmp[31:16]!=16'h0000;
				mbus.req.we <= HIGH;
				mbus.req.sel <= 32'hFF << {tmp[4:3],3'b0};
				mbus.req.adr <= tmp;
				mbus.req.dat <= {4{b}};
				roma <= tmp;
				if (tmp[31:16]!=16'h0000) begin
				  tGoto(st_mem_store);
				end
			end
		OP_STOREI:
			begin
				tmp = a + {{17{ir.imm[14]}},ir.imm};
				local_sel <= tmp[31:16]==16'h0000;
				mbus.req.cyc <= tmp[31:16]!=16'h0000;
				mbus.req.stb <= tmp[31:16]!=16'h0000;
				mbus.req.we <= HIGH;
				mbus.req.sel <= 32'hFF << {tmp[4:3],3'b0};
				mbus.req.adr <= tmp;
				mbus.req.dat <= {4{60'd0,ir.Rd}};
				roma <= tmp;
				if (tmp[31:16]!=16'h0000) begin
				  tGoto(st_mem_store);
				end
			end
		OP_STOREI64:
			begin
				// Was instruction at an odd address?
				if (ip[0] & UNALIGNED_CONSTANTS)
					tGoto(st_even64);
				else
					tGoto(st_odd64);
			end
		OP_BMP:
			begin
				tmp = (a >> 4'd6) + {{17{ir.imm[14]}},ir.imm};
				local_sel <= tmp[31:16]==16'h0000;
				mbus.req.cyc <= tmp[31:16]!=16'h0000;
				mbus.req.stb <= tmp[31:16]!=16'h0000;
				mbus.req.we <= LOW;
				mbus.req.sel <= 32'hFF << {tmp[4:3],3'b0};
				mbus.req.adr <= tmp;
				roma <= tmp;
				tGoto (st_mem_load);
			end

		// ALU ops
		// ALU ops also writeback here to trim a cycle from timing.
		OP_SHL: begin tWriteback(ir.Rd, a << (b[4:0]+ir.imm[4:0])); tGoto(st_ifetch); end
		OP_SHR:	begin tWriteback(ir.Rd, a >> (b[4:0]+ir.imm[4:0])); tGoto(st_ifetch); end
		OP_ADD: begin tWriteback(ir.Rd, a + b + {{17{ir.imm[14]}},ir.imm}); tGoto(st_ifetch); end
		OP_ADD64,OP_AND64:
			begin
				// Was instruction at an odd address?
				if (ip[0] & UNALIGNED_CONSTANTS)
					tGoto(st_even64);
				else
					tGoto(st_odd64);
			end
		OP_AND: begin tWriteback(ir.Rd, a & b & {{17{ir.imm[14]}},ir.imm}); tGoto(st_ifetch); end
		OP_OR:	begin tWriteback(ir.Rd, a | b | {{17{ir.imm[14]}},ir.imm}); tGoto(st_ifetch); end
		OP_XOR:	begin tWriteback(ir.Rd, a ^ b ^ {{17{ir.imm[14]}},ir.imm}); tGoto(st_ifetch); end
		default:;
		endcase
	end

// This state will be stripped out unless unaligned constants are allowed.
st_even64:
	begin
		imm <= douta[63:32];
		tGoto(st_even64a);
	end
st_even64a:
	begin
		tGoto(st_writeback);
		case(ir.opcode)
		OP_ADD64:	begin rfwr <= TRUE; res <= a + b + {douta[31:0],imm}; end
		OP_AND64:	begin rfwr <= TRUE; res <= a & b & {douta[31:0],imm}; end
		OP_STOREI:
			begin
				tmp = a + {{17{ir.imm[14]}},ir.imm};
				local_sel <= tmp[31:16]==16'h0000;
				mbus.req.cyc <= tmp[31:16]!=16'h0000;
				mbus.req.stb <= tmp[31:16]!=16'h0000;
				mbus.req.we <= HIGH;
				mbus.req.sel <= 32'hFF << {tmp[4:3],3'b0};
				mbus.req.adr <= tmp;
				mbus.req.dat <= {4{douta[31:0],imm}};
				if (tmp[31:16]!=16'h0000)
					tGoto(st_mem_store);
			end
		default:	;
		endcase
	end

st_odd64:
	tGoto(st_odd64a);
st_odd64a:
	begin
		tGoto(st_writeback);
		case(ir.opcode)
		OP_ADD64:	begin rfwr <= TRUE; res <= a + b + douta; end
		OP_AND64:	begin rfwr <= TRUE; res <= a & b & douta; end
		OP_STOREI:
			begin
				tmp = a + {{17{ir.imm[14]}},ir.imm};
				local_sel <= tmp[31:16]==16'h0000;
				mbus.req.cyc <= tmp[31:16]!=16'h0000;
				mbus.req.stb <= tmp[31:16]!=16'h0000;
				mbus.req.we <= HIGH;
				mbus.req.sel <= 32'hFF << {tmp[4:3],3'b0};
				mbus.req.adr <= tmp;
				mbus.req.dat <= {4{douta}};
				if (tmp[31:16]!=16'h0000)
					tGoto(st_mem_store);
			end
		default:	;
		endcase
	end
st_writeback:
	begin
		if (rfwr)
			tWriteback(ir.Rd,res);
		rfwr <= FALSE;
		tGoto(st_ifetch);
	end
st_prefetch:
	tGoto(st_ifetch);

// Wakeup stages for the BRAM after a WAIT operation.
st_wakeup:
	begin
		idle <= FALSE;
		tGoto(st_wakeup2);
	end
st_wakeup2:
	tRet();
st_jmp:
	tGoto(st_writeback);

// Memory states
st_ip_load:
	begin
		if (mbus.resp.ack) begin
			mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
			tGoto (st_jmp);
		end
	end

st_mem_load:
	begin
		if (mbus.resp.ack) begin
			tGoto (st_writeback);
			mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
			case(ir.opcode)
			OP_BMP:
				case(ir.Rs2)
				4'd0:	// BMCLR
					begin
						if (local_sel) begin
							casez(roma[14:3])
							12'hF??:	
								begin
									mem_val <= arg_dat & ~(64'd1 << mbus.req.adr[5:0]);
						  		rfwr <= TRUE;
									res <= arg_dat >> mbus.req.adr[5:0] & 64'd1;
									tGoto(st_bit_store);
								end
						  default:
						  	begin
						  		mem_val <= douta & ~(64'd1 << mbus.req.adr[5:0]);
						  		rfwr <= TRUE;
						  		res <= mbus.req.adr[5:0] & 64'd1;
									tGoto(st_bit_store);
						  	end
							endcase
						end
						else begin
							mem_val <= (mbus.resp.dat >> {mbus.req.adr[7:6],6'd0}) & ~(64'd1 << mbus.req.adr[5:0]);
							res <= mbus.resp.dat >> mbus.req.adr[7:0] & 64'd1;
							tGoto(st_bit_store);
						end
					end
				4'd1:	// BMSET
					begin
						if (local_sel) begin
							casez(roma[14:3])
							12'hF??:	
								begin
									mem_val <= arg_dat | (64'd1 << mbus.req.adr[5:0]);
						  		rfwr <= TRUE;
									res <= arg_dat >> mbus.req.adr[5:0] & 64'd1;
									tGoto(st_bit_store);
								end
						  default:
						  	begin
						  		mem_val <= douta | (64'd1 << mbus.req.adr[5:0]);
						  		rfwr <= TRUE;
						  		res <= mbus.req.adr[5:0] & 64'd1;
									tGoto(st_bit_store);
						  	end
							endcase
						end
						else begin
							mem_val <= mbus.resp.dat >> {mbus.req.adr[7:6],6'd0} | (64'd1 << mbus.req.adr[5:0]);
							res <= mbus.resp.dat >> mbus.req.adr[7:0] & 64'd1;
							tGoto(st_bit_store);
						end
					end
				4'd2:	// BMTST
					begin
						if (local_sel) begin
							casez(roma[14:3])
							12'hF??:	
								begin
									mem_val <= arg_dat | (64'd1 << mbus.req.adr[5:0]);
						  		rfwr <= TRUE;
									res <= arg_dat >> mbus.req.adr[5:0] & 64'd1;
								end
						  default:
						  	begin
						  		mem_val <= douta | (64'd1 << mbus.req.adr[5:0]);
						  		rfwr <= TRUE;
						  		res <= mbus.req.adr[5:0] & 64'd1;
						  	end
							endcase
						end
						else begin
							mem_val <= mbus.resp.dat >> {mbus.req.adr[7:6],6'd0} | (64'd1 << mbus.req.adr[5:0]);
							res <= mbus.resp.dat >> mbus.req.adr[7:0] & 64'd1;
						end
					end
				4'd3:	// BMCHG
					begin
						if (local_sel) begin
							casez(roma[14:3])
							12'hF??:	
								begin
									mem_val <= arg_dat ^ (64'd1 << mbus.req.adr[5:0]);
						  		rfwr <= TRUE;
									res <= arg_dat >> mbus.req.adr[5:0] & 64'd1;
									tGoto(st_bit_store);
								end
						  default:
						  	begin
						  		mem_val <= douta ^ (64'd1 << mbus.req.adr[5:0]);
						  		rfwr <= TRUE;
						  		res <= mbus.req.adr[5:0] & 64'd1;
									tGoto(st_bit_store);
						  	end
							endcase
						end
						else begin
							mem_val <= mbus.resp.dat >> {mbus.req.adr[7:6],6'd0} ^ (64'd1 << mbus.req.adr[5:0]);
							res <= mbus.resp.dat >> mbus.req.adr[7:0] & 64'd1;
							tGoto(st_bit_store);
						end
					end
				default:	tGoto(st_ifetch);
				endcase
			default:
				if (local_sel) begin
					casez(roma[14:3])
					12'hF??:	begin rfwr <= TRUE; res <= arg_dat; end
				  default:	begin rfwr <= TRUE; res <= douta; end
					endcase
				end
				else begin
					rfwr <= TRUE;
				  res <= mbus.resp.dat >> {mbus.req.adr[5:4],6'd0};
				end
			endcase
		end
	end
	
st_bit_store:
	if (!mbus.resp.ack) begin
		tmp = (a >> 4'd6) + {{17{ir.imm[14]}},ir.imm};
		local_sel <= tmp[31:16]==16'h0000;
		mbus.req.cyc <= tmp[31:16]!=16'h0000;
		mbus.req.stb <= tmp[31:16]!=16'h0000;
		mbus.req.we <= HIGH;
		mbus.req.sel <= 32'hFF << {tmp[4:3],3'b0};
		mbus.req.adr <= tmp;
		mbus.req.dat <= {4{mem_val}};
		if (tmp[31:0]==32'h00007ff8) begin
			page_fault <= mem_val[0];
			cmd_done <= mem_val[1];
		end
		roma <= tmp;
		if (tmp[31:16]!=16'h0000) begin
		  tGoto(st_mem_store);
		end
	end

st_mem_store:
	begin
		if (mbus.resp.ack) begin
			mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
			tGoto (st_writeback);
		end
	end
default:	tGoto(st_execute);
endcase
$display("Tick: %d I-count: %d  %f instructions per clock", tick, icnt>>1, real'(icnt>>1)/real'(tick));
end

task tGoto;
input copro_state_t dst;
begin
	if (dst==st_execute)
		ir <= next_ir;
	state <= dst;
end
endtask

task tCall;
input copro_state_t dst;
input copro_state_t rst;
begin
	state <= dst;
	state_stack[0] <= rst;
	state_stack[1] <= state_stack[0];
	state_stack[2] <= state_stack[1];
	state_stack[3] <= state_stack[2];
end
endtask

task tRet;
begin
	state <= state_stack[0];
	state_stack[0] <= state_stack[1];
	state_stack[1] <= state_stack[2];
	state_stack[2] <= state_stack[3];
end
endtask

task tWriteback;
input [3:0] rg;
input [63:0] res;
begin
	case(rg)
	4'd1:	r1 <= res;
	4'd2:	r2 <= res;
	4'd3:	r3 <= res;
	4'd4:	r4 <= res;
	4'd5:	r5 <= res;
	4'd6:	r6 <= res;
	4'd7:	r7 <= res;
	4'd8:	r8 <= res;
	4'd9:	r9 <= res;
	4'd10:	r10 <= res;
	4'd11:	r11 <= res;
	4'd12:	r12 <= res;
	4'd13:	r13 <= res;
	4'd14:  r14 <= res;
	4'd15:  r15 <= res;
	default:	;
	endcase
end
endtask

endmodule
