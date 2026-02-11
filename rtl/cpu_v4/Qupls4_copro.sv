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
// 4650 LUTs / 2500 FFs / 8 BRAMs / 160 MHz
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import wishbone_pkg::*;

module Qupls4_copro(rst, clk, sbus, mbus, vmbus, cs_copro, miss, miss_adr, miss_asid,
  paging_en, page_fault, iv_count,
  vclk, hsync_i, vsync_i, gfx_que_empty_i);
input rst;
input clk;
wb_bus_interface.slave sbus;
wb_bus_interface.master mbus;
wb_bus_interface.master vmbus;
input cs_copro;
input [1:0] miss;
input address_t miss_adr;
input asid_t miss_asid;
output reg paging_en;
output reg page_fault;
input [3:0] iv_count;
input vclk;
input hsync_i;
input vsync_i;
input gfx_que_empty_i;

typedef enum logic [4:0]
{
	OP_NOP = 5'd0,
	OP_WAIT,
	OP_SKIP,
	OP_LOAD_CONFIG,
	OP_JCC,
	OP_JMP = 9,
	OP_RET = 11,
	OP_CALC_INDEX,
	OP_CALC_ADR,
	OP_BUILD_ENTRY_NO,
	OP_BUILD_VPN,
	OP_LOAD = 16,
	OP_STORE,
	OP_STOREI,
	OP_MOVE,
	OP_SHL = 20,
	OP_SHR,
	OP_ADD,
	OP_AND64,
	OP_AND,
	OP_OR,
	OP_XOR,
	OP_SET_PAGE_FAULT
} opcode_t;

typedef enum logic [3:0] {
	JEQ = 0,
	JNE,
	JLT,
	JLE,
	JGE,
	JGT,
	DJNE,
	JLEP = 8,
	JGEP,
	GQE,
	GQNE
} jcc_t;

typedef struct packed 
{
	logic [13:0] imm;
	logic i;
	logic [3:0] Rs2;
	logic [3:0] Rs1;
	logic [3:0] Rd;
	opcode_t opcode;
} instruction_t;

typedef enum logic [3:0]
{
	st_reset,
	st_execute,
	st_jmp,
	st_ip_load,
	st_mem_load,
	st_mem_store,
	st_wakeup,
	st_wakeup2
} state_t;

state_t state;

instruction_t ir;
instruction_t vir;

// register file
reg [63:0] r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r13,r14,r15,tmp;
reg [63:0] ir1,ir2,ir3,ir4,ir5,ir6,ir7;
reg [63:0] vir1,vir2,vir3,vir4,vir5,vir6,vir7;
// Operands
reg [63:0] a,b;
reg [12:0] ip;						// instruction pointer
reg [12:0] stack [0:7];
reg [3:0] sp;
reg [14:0] roma;
wire local_sel = (state==st_mem_load|state==st_mem_store) & roma[14:8]==7'h7F;
wire rsta = rst;
wire rstb = sbus.rst;
wire clka = clk;
wire clkb = sbus.clk;
wire ena = 1'b1;
wire enb = sbus.req.cyc & sbus.req.stb & cs_copro & ~sbus.req.adr[16];
wire wea = mbus.req.we & local_sel & ~mbus.req.adr[16];
wire web = sbus.req.we & cs_copro & ~sbus.req.adr[16];
wire [11:0] addra = local_sel ? roma : ip[12:1];
wire [11:0] addrb = sbus.req.adr[14:3];
wire [63:0] dina = mbus.req.dat;
wire [63:0] dinb = sbus.req.dat;
wire [63:0] douta;
wire [63:0] doutb;
wire [31:0] romo = ip[0] ? douta[63:32] : douta[31:0];
reg in_irq;
reg sleep;
reg cs;
wire dly2;

reg [31:0] entry_no;
reg [63:0] cmd,stat;
tlb_entry_t tlbe,tlbe2;
ptattr_t [1:0] ptattr;
address_t [1:0] ptbr;
reg clear_page_fault;
address_t miss_adr1;
asid_t miss_asid1;
reg [63:0] arg_dat;

always_comb
	cs = cs_copro & sbus.req.cyc & sbus.req.stb;
delay2 udly2 (.clk(clk), .ce(1'b1), .i(cs), .o(dly2));

always_ff @(posedge sbus.clk)
if (sbus.rst) begin
	ptbr[0] <= 64'hFFFFFFFFFF800000;
	ptbr[1] <= 64'hFFFFFFFFFF802000;
	ptattr[0] <= 64'd0;
	ptattr[0].level <= 3'd1;
	ptattr[0].pgsz <= 5'd13;
	ptattr[1] <= 64'd0;
	ptattr[1].level <= 3'd1;
	ptattr[1].pgsz <= 5'd23;
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
			casez(sbus.req.adr[12:3])
			10'h3E0:	entry_no <= sbus.req.dat[31:0];
			10'h3E1:	cmd <= sbus.req.dat;
			10'h3E2:	tlbe[63:0] <= sbus.req.dat;
			10'h3E3:	tlbe[127:64] <= sbus.req.dat;
			10'h3F0:	ptbr[0] <= sbus.req.dat;
			10'h3F2:	ptattr[0] <= sbus.req.dat;
			10'h3F4:	ptbr[1] <= sbus.req.dat;
			10'h3F6:	ptattr[1] <= sbus.req.dat;
			10'h3FC:	clear_page_fault <= TRUE;
			default:	;
			endcase
		casez(sbus.req.adr[12:3])
		10'h3E1:	sbus.resp.dat <= stat;
		10'h3E2:	sbus.resp.dat <= tlbe2[63:0];
		10'h3E3:	sbus.resp.dat <= tlbe2[127:64];
		10'h3E4:	sbus.resp.dat <= miss_adr1;
		10'h3E5:	sbus.resp.dat <= miss_asid1;
		10'h3F0:	sbus.resp.dat <= ptbr[0];
		10'h3F2:	sbus.resp.dat <= ptattr[1];
		10'h3F4:	sbus.resp.dat <= ptbr[1];
		10'h3F6:	sbus.resp.dat <= ptattr[1];
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
  .MEMORY_INIT_FILE("none"),      // String
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

always_ff @(posedge clk)
if (rst) begin
	ip <= 10'd0;
	ir <= {$bits(instruction_t){1'b0}};
	ir.opcode <= OP_NOP;
	stat <= 64'd0;
	miss_asid1 <= 16'h0;
	miss_adr1 <= {$bits(address_t){1'b0}};
	mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
	in_irq <= FALSE;
  tGoto(st_execute);
end
else begin
	ir <= romo;
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
st_execute:	
	begin
		ip <= ip + 1;
		if (pe_vsync2) begin
			sleep <= FALSE;
			in_irq <= TRUE;
			stack[sp-1] <= ip;
			sp <= sp - 1;
			ip <= 13'h10;
			r1 <= vir1;
			r2 <= vir2;
			r3 <= vir3;
			r4 <= vir4;
			r5 <= vir5;
			r6 <= vir6;
			r7 <= vir7;
			vir1 <= r1;
			vir2 <= r2;
			vir3 <= r3;
			vir4 <= r4;
			vir5 <= r5;
			vir6 <= r6;
			vir7 <= r7;
			if (sleep)
				tGoto(st_wakeup);
		end
		else if (|miss & paging_en) begin
			sleep <= FALSE;
			in_irq <= TRUE;
			miss_adr1 <= miss_adr;
			miss_asid1 <= miss_asid;
			paging_en <= FALSE;
			stack[sp-1] <= ip;
			sp <= sp - 1;
			ip <= 13'h8;
			r1 <= ir1;
			r2 <= ir2;
			r3 <= ir3;
			r4 <= ir4;
			r5 <= ir5;
			r6 <= ir6;
			r7 <= ir7;
			ir1 <= r1;
			ir2 <= r2;
			ir3 <= r3;
			ir4 <= r4;
			ir5 <= r5;
			ir6 <= r6;
			ir7 <= r7;
			if (sleep)
				tGoto(st_wakeup);
		end
		else
		case(ir.opcode)
		OP_WAIT:
			begin
				case(ir.Rd)
				JGEP:
					if (hpos_masked >= hpos_wait && vpos_masked >= vpos_wait && (b[48] ? gfx_que_empty_i : 1'b1)) begin
						ip <= ip;
						sleep <= TRUE;
					end
					else
						tGoto(st_wakeup);
				default:
					begin
						ip <= ip;
						sleep <= TRUE;
					end
				endcase
			end
		OP_LOAD_CONFIG:
			begin
				r1 <= miss_adr;
				r2 <= ptbr[0];
				r3 <= ptattr[0].pgsz;
				r4 <= ptattr[0].level;
				r5 <= miss_asid;
				r6 <= iv_count;
			end
		OP_JCC:
			case(ir.Rd)
			JEQ:
				if (a==b) begin
					ip <= ir.imm;
					tGoto(st_jmp);
				end
			JNE:
				if (a!=b) begin
					ip <= ir.imm;
					tGoto(st_jmp);
				end
			JLT:
				if ($signed(a) > $signed(b)) begin
					ip <= ir.imm;
					tGoto(st_jmp);
				end
			JLE:
				if ($signed(a) <= $signed(b)) begin
					ip <= ir.imm;
					tGoto(st_jmp);
				end
			JGE:
				if ($signed(a) >= $signed(b)) begin
					ip <= ir.imm;
					tGoto(st_jmp);
				end
			JGT:
				if ($signed(a) > $signed(b)) begin
					ip <= ir.imm;
					tGoto(st_jmp);
				end
			DJNE:
				begin
					tWriteback(a-1);
					if (a-1!=b)
						ip <= ir.imm;
					tGoto(st_jmp);
				end
			JGEP:
				if (hpos_masked >= hpos_wait && vpos_masked >= vpos_wait && (b[48] ? gfx_que_empty_i : 1'b1))
					ip <= ir.imm;
			JLEP:
				if (hpos_masked <= hpos_wait && vpos_masked <= vpos_wait && (b[48] ? gfx_que_empty_i : 1'b1))
					ip <= ir.imm;
			default:	;
			endcase

		OP_JMP:
			begin
				if (|ir.Rd) begin	// JSR?
					stack[sp-1] <= ip;
					sp <= sp - 1;
				end
				if (ir.Rd[3]) begin
					tmp = a + {{17{ir.imm[14]}},ir.imm};
					mbus.req.cyc <= ~&tmp[11:4];
					mbus.req.stb <= ~&tmp[11:4];
					mbus.req.we <= LOW;
					mbus.req.sel <= 32'hFF << {tmp[4:3],3'b0};
					mbus.req.adr <= tmp;
					roma <= tmp;
					tGoto (st_ip_load);
				end
				else
					ip <= a + {{17{ir.imm[14]}},ir.imm};
				tGoto(st_jmp);
			end

		OP_RET:
			begin
				ip <= stack[sp];
				sp <= sp + 1;
				if (ir.Rd==1) begin
					in_irq <= FALSE;
					r1 <= vir1;
					r2 <= vir2;
					r3 <= vir3;
					r4 <= vir4;
					r5 <= vir5;
					r6 <= vir6;
					r7 <= vir7;
				end
				else if (ir.Rd==2) begin
					in_irq <= FALSE;
					r1 <= ir1;
					r2 <= ir2;
					r3 <= ir3;
					r4 <= ir4;
					r5 <= ir5;
					r6 <= ir6;
					r7 <= ir7;
					paging_en <= TRUE;
				end
				tGoto(st_jmp);
			end

		OP_CALC_INDEX:
			begin
				tmp = ptattr[0].pgsz - 64'd3;
				tmp = tmp[5:0] * a[2:0] + ptattr[0].pgsz;
				tWriteback(miss_adr1 >> tmp);
			end
		OP_CALC_ADR:
			begin
				tmp = (64'd1 << ptattr[0].pgsz) - 1;	// tmp = page size mask
				tmp = b & tmp;										// tmp = PTE index masked for 1024 entries in page
				tmp = tmp << 3;										// tmp = word index
				tWriteback(a | tmp);							// r8 = page table address plus index
			end
		OP_BUILD_ENTRY_NO:
			begin
				tmp = {56'd0,b[7:0]} << 16;					// put way into position
				tmp = tmp | (64'h1 << ir.imm[5:0]);	// set TLBE set bit
				tmp = tmp | a[15:0];								// put read_adr into position
				tWriteback(tmp);
			end
		OP_BUILD_VPN:
			begin
				tmp = miss_adr >> (ptattr[0].pgsz + ptattr[0].log_te);	// VPN = miss_adr >> (LOG_PAGESIZE + TLB_ABITS)
				tmp = tmp | ({64'd0,miss_asid} << 48);// put ASID into position
				tmp = tmp | ({64'd0,iv_count} << 42);	// put count into position
				tWriteback(tmp);
			end
		OP_LOAD:
			begin
				tmp = a + {{17{ir.imm[14]}},ir.imm};
				mbus.req.cyc <= ~&tmp[11:4];
				mbus.req.stb <= ~&tmp[11:4];
				mbus.req.we <= LOW;
				mbus.req.sel <= 32'hFF << {tmp[4:3],3'b0};
				mbus.req.adr <= tmp;
				roma <= tmp;
				tGoto (st_mem_load);
			end
		OP_STORE:
			begin
				tmp = a + {{17{ir.imm[14]}},ir.imm};
				mbus.req.cyc <= ~&tmp[11:4];
				mbus.req.stb <= ~&tmp[11:4];
				mbus.req.we <= HIGH;
				mbus.req.sel <= 32'hFF << {tmp[4:3],3'b0};
				mbus.req.adr <= tmp;
				mbus.req.dat <= {4{b}};
				roma <= tmp;
				if (!local_sel)
				    tGoto(st_mem_store);
			end
		OP_STOREI:
			begin
				ip <= ip + 3;
				tmp = a + {{17{ir.imm[14]}},ir.imm};
				mbus.req.cyc <= HIGH;
				mbus.req.stb <= HIGH;
				mbus.req.we <= HIGH;
				mbus.req.sel <= 32'hFF << {tmp[4:3],3'b0};
				mbus.req.adr <= tmp;
				mbus.req.dat <= {4{romo}};
				if (!local_sel)
					tGoto(st_mem_store);
			end
//		OP_MOVE: tWriteback(a);
		OP_SHL:
			tWriteback(a << (b[4:0]|ir.imm[4:0]));
		OP_SHR:
			tWriteback(a >> (b[4:0]|ir.imm[4:0]));
		OP_ADD:
			tWriteback(a + b + {{17{ir.imm[14]}},ir.imm});
		OP_AND64:
			begin
				tWriteback(a & b & romo);
				ip <= ip + 3;
			end
		OP_AND:
			tWriteback(a & b & {{17{ir.imm[14]}},ir.imm});
		OP_OR:
			tWriteback(a | b | {{17{ir.imm[14]}},ir.imm});
		OP_XOR:
			tWriteback(a ^ b ^ {{17{ir.imm[14]}},ir.imm});
		OP_SET_PAGE_FAULT:	page_fault <= 1;
		default:;
		endcase
	end

st_wakeup:
	tGoto(st_wakeup2);
st_wakeup2:
	tGoto(st_jmp);
st_jmp:
	begin
		tGoto(st_execute);
	end

st_ip_load:
	if (mbus.resp.ack) begin
		mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
		if (local_sel) begin
			casez(roma[12:3])
			10'h3??:	ip <= arg_dat;
		  default:	ip <= douta;
			endcase
		end
		else
			ip <= mbus.resp.dat >> {mbus.req.adr[5:4],6'd0};
		tGoto (st_jmp);
	end

st_mem_load:
	if (mbus.resp.ack) begin
		mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
		if (local_sel) begin
			casez(roma[12:3])
			10'h3??:	tWriteback(arg_dat);
		  default:	tWriteback(douta);
			endcase
		end
		else
		  tWriteback(mbus.resp.dat >> {mbus.req.adr[5:4],6'd0});
		tGoto (st_execute);
	end
	
st_mem_store:
	if (mbus.resp.ack) begin
		mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
		tGoto (st_execute);
	end
endcase
end

task tGoto;
input state_t dst;
begin
	state <= dst;
end
endtask

task tWriteback;
input [63:0] res;
begin
	case(ir.Rd)
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
