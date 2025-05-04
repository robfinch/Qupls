// ============================================================================
//        __
//   \\__/ o\    (C) 2018-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	rfRiscv.sv
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
// ============================================================================

`define LOAD	7'd3
`define LB			3'd0
`define LH			3'd1
`define LW			3'd2
`define LD			3'd3
`define LBU			3'd4
`define LHU			3'd5
`define LWU			3'd6
`define FENCE	7'd15
`define ALUI	7'd19
`define AUIPC	7'd23
`define ALUWI	7'd27
`define STORE	7'd35
`define SB			3'd0
`define SH			3'd1
`define SW			3'd2
`define SD			3'd3
`define AMO		7'd47
`define ALU		7'd51
`define LUI		7'd55
`define ALUW	7'd59
`define Bcc		7'd99
`define BEQ			3'd0
`define BNE			3'd1
`define BLT			3'd4
`define BGE			3'd5
`define BLTU		3'd6
`define BGEU		3'd7
`define JALR	7'd103
`define JAL		7'd111
`define SYSTEM	7'd115
`define EBREAK	32'h00100073
`define ECALL		32'h00000073
`define ERET		32'h10000073
`define MRET		32'h30200073
`define CS_ILLEGALINST	2

module rfRiscv(rst_i, hartid_i, clk_i, wc_clk_i, nmi_i, irq_i, cause_i, vpa_o, 
	cyc_o, stb_o, ack_i, err_i, rty_i, we_o, sel_o, adr_o, dat_i, dat_o
);
parameter WID = 64;
parameter RSTPC = 32'hFFFC0100;
input rst_i;
input [31:0] hartid_i;
input clk_i;
input wc_clk_i;             // wall clock timing input
input nmi_i;
input [5:0] irq_i;
input [7:0] cause_i;
output reg vpa_o;           // valid program address
output reg cyc_o;
output reg stb_o;
input ack_i;
input err_i;
input rty_i;
output reg we_o;
output reg [WID/8-1:0] sel_o;
output reg [31:0] adr_o;
input [WID-1:0] dat_i;
output reg [WID-1:0] dat_o;
parameter HIGH = 1'b1;
parameter LOW = 1'b0;

integer n1;

wire clk_g;					// gated clock

// Non visible registers
wire MachineMode, UserMode;
reg [31:0] ir;			// instruction register
reg [31:0] upc;			// user mode pc
reg [31:0] spc;			// system mode pc
reg [4:0] Rd;
wire [4:0] Rs1 = ir[19:15];
wire [4:0] Rs2 = ir[24:20];
wire [4:0] Rs3 = ir[31:27];
reg [WID-1:0] ia, ib, ic;
reg [WID-1:0] ia2, ib2, ic2;
reg [WID-1:0] imm, res, res2;
// Decoding
wire [6:0] opcode = ir[6:0];
wire [2:0] funct3 = ir[14:12];
wire [4:0] funct5 = ir[31:27];
wire [6:0] funct7 = ir[31:25];
wire [2:0] rm3 = ir[14:12];
reg wrirf, wrfrf;

reg [4:0] rprv;
reg [WID-1:0] iregfile [0:31];		// integer
wire [7:0] zladr;
wire [31:0] to_out;
wire [7:0] zl_out;
reg [63:0] sp;
reg traceOn;
reg traceRd;
reg [9:0] traceCounter;
reg poptrace;
reg [4:0] state;
reg [31:0] pc;			// generic program counter
reg [31:0] ipc;			// pc value at instruction
wire traceWr = state==IFETCH && traceOn;
wire traceValid, traceEmpty, traceFull;
wire [9:0] traceDataCount;
wire [63:0] traceOut;
/*
TraceFifo utf1 (
  .clk(clk_g),                // input wire clk
  .srst(rst_i),              // input wire srst
  .din({sp,pc}),                // input wire [31 : 0] din
  .wr_en(traceWr),            // input wire wr_en
  .rd_en((popq && ia[3:0]==4'd14)||poptrace),            // input wire rd_en
  .dout(traceOut),              // output wire [31 : 0] dout
  .full(traceFull),              // output wire full
  .empty(traceEmpty),            // output wire empty
  .valid(traceValid),            // output wire valid
  .data_count(traceDataCount)  // output wire [9 : 0] data_count
);
*/
wire [WID-1:0] irfoa;
wire [WID-1:0] irfob;
parameter RESET = 5'd0;
parameter IFETCH = 5'd1;
parameter IFETCH2 = 5'd2;
parameter DECODE = 5'd3;
parameter RFETCH = 5'd4;
parameter EXECUTE = 5'd5;
parameter MEMORY_SETUP = 5'd6;
parameter MEMORY_WAIT = 5'd7;
parameter MEMORY2_SETUP = 5'd8;
parameter MEMORY2_WAIT = 5'd9;
parameter MEMORY_PROCESS = 5'd10;
parameter FLOAT = 5'd14;
parameter MUL1 = 5'd15;
parameter MUL2 = 5'd16;
parameter PAM	 = 5'd17;
parameter REGFETCH2 = 5'd18;
parameter TMO = 5'd21;
parameter NSIMM = 5'd22;
parameter NSIMM2 = 5'd23;
parameter REGFETCH3 = 5'd24;
parameter PAGEMAPA = 5'd25;
parameter CSR = 5'd26;
parameter CSR2 = 5'd27;
parameter MULW1 = 5'd28;
parameter MULW2 = 5'd29;

reg illegal_insn;

always_ff @(posedge clk_g)
	if (wrirf && Rd==5'd2)
		sp <= res[WID-1:0];

initial begin
	for (n1 = 0; n1 < 32; n1 = n1 + 1)
		iregfile[n1] = 64'd0;
end

always_ff @(posedge clk_g)
begin
	if (wrirf)
		iregfile[Rd] <= res;
end

// CSRs
reg [2:0] mrloc;    // mret lockout
reg [31:0] uip;     // user interrupt pending
reg [47:0] rsStack;
reg [31:0] pmStack;
reg [31:0] imStack;
wire [2:0] im_level = imStack[2:0];
reg [63:0] tick;		// cycle counter
reg [63:0] wc_time;	// wall-clock time
reg wc_time_irq;
wire clr_wc_time_irq;
reg [5:0] wc_time_irq_clr;
reg wfi;
reg set_wfi = 1'b0;
reg [63:0] mepc;
reg [31:0] mtimecmp;
reg [63:0] instret;	// instructions completed.
reg [31:0] mcpuid = 32'b000000_00_00000000_00010001_00100001;
reg [31:0] mimpid = 32'h01108000;
reg [31:0] mcause;
reg [31:0] mstatus;
reg [31:0] mtvec = 32'hFFFC0000;
reg [63:0] mscratch;
reg [31:0] mbadaddr;
wire [31:0] mip;
reg msip, ugip;
assign mip[31:8] = 24'h0;
assign mip[7] = 1'b0;
assign mip[6:4] = 3'b0;
assign mip[3] = msip;
assign mip[2:1] = 2'b0;
assign mip[0] = ugip;
wire ie = pmStack[0];
reg [31:0] mie;
wire mprv = mstatus[17];
wire [1:0] memmode;
assign MachineMode = 1'b1;
assign UserMode = 1'b0;
assign memmode = mprv ? pmStack[5:4] : pmStack[2:1];
wire MMachineMode = memmode==2'b11;
wire MUserMode = memmode==2'b00;

function [7:0] fnSelect;
input [6:0] op7;
input [2:0] fn3;
case(op7)
`LOAD:
	case(fn3)
	`LB,`LBU:	fnSelect = 8'h01;
	`LH,`LHU:	fnSelect = 8'h03;
	`LW,`LWU:	fnSelect = 8'h0F;
	`LD:			fnSelect = 8'hFF;
	default:	fnSelect = 8'h00;	
	endcase
`STORE:
	case(fn3)
	`SB:	fnSelect = 8'h01;
	`SH:	fnSelect = 8'h03;
	`SW:	fnSelect = 8'h0F;
	`SD:	fnSelect = 8'hFF;
	default:	fnSelect = 8'h00;
	endcase
default:	fnSelect = 8'h00;
endcase
endfunction

reg [31:0] ea;
reg [127:0] dati;
reg [63:0] datiL;
always_comb
  datiL <= dati >> {ea[2:0],3'b0};
reg [127:0] sdat;
always @(posedge clk_g)
	case(opcode)
	default:
		sdat <= ib << {ea[2:0],3'b0};
	endcase
reg [15:0] ssel;
always @(posedge clk_g)
  ssel <= {8'h00,fnSelect(opcode,funct3)} << ea[2:0];

wire ld = state==EXECUTE;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Multiply / Divide support logic
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
reg sgn;
wire [WID*2-1:0] prod = ia * ib;
wire [WID*2-1:0] nprod = -prod;
wire [63:0] prod32 = ia[31:0] * ib[31:0];
wire [63:0] nprod32 = -prod32;
reg ldd;
wire [WID*2-1:0] div_q;
wire [WID*2-1:0] ndiv_q = -div_q;
wire [WID-1:0] div_r = ia - (ib * div_q[WID*2-1:WID]);
wire [WID-1:0] ndiv_r = -div_r;
wire [63:0] div_q32;
wire [63:0] ndiv_q32 = -div_q32;
wire [31:0] div_r32 = ia[31:0] - (ib[31:0] * div_q32[63:32]);
wire [31:0] ndiv_r32 = -div_r32;
/*
fpdivr2 #(.FPWID(64)) u16 (
	.clk_div(clk_g),
	.ld(ldd),
	.a(ia),
	.b(ib),
	.q(div_q),
	.r(),
	.lzcnt(),
	.done()
);
fpdivr2 #(.FPWID(32)) u18 (
	.clk_div(clk_g),
	.ld(ldd),
	.a(ia[31:0]),
	.b(ib[31:0]),
	.q(div_q32),
	.r(),
	.lzcnt(),
	.done()
);
*/
reg [7:0] mathCnt;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Timers
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

always @(posedge clk_g)
if (rst_i)
	tick <= 64'd0;
else
	tick <= tick + 2'd1;

reg [5:0] ld_time;
reg [63:0] wc_time_dat;
reg [63:0] wc_times;
assign clr_wc_time_irq = wc_time_irq_clr[5];
always @(posedge wc_clk_i)
if (rst_i) begin
	wc_time <= 1'd0;
	wc_time_irq <= 1'b0;
end
else begin
	if (|ld_time)
		wc_time <= wc_time_dat;
	else
		wc_time <= wc_time + 2'd1;
	if (mtimecmp==wc_time[31:0])
		wc_time_irq <= 1'b1;
	if (clr_wc_time_irq)
		wc_time_irq <= 1'b0;
end

assign mip[7] = wc_time_irq;

wire pe_nmi;
reg nmif;
edge_det u17 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(nmi_i), .pe(pe_nmi), .ne(), .ee() );

assign clk_g = clk_i;

wire mloco = mrloc != 3'd0;

reg [4:0] cid;

always @(posedge clk_g)
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Reset
// The program counters are set at their reset values.
// System mode is activated and interrupts are masked.
// All other state is undefined.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if (rst_i) begin
	tGoto (IFETCH);
	pc <= RSTPC;
	mtvec <= 32'hFFFC0000;
	wrirf <= 1'b0;
	// Reset bus
	vpa_o <= LOW;
	cyc_o <= LOW;
	stb_o <= LOW;
	we_o <= LOW;
	adr_o <= 32'h0;
	dat_o <= 32'h0;
	instret <= 64'd0;
	ld_time <= 1'b0;
	wc_times <= 1'b0;
	wc_time_irq_clr <= 6'h3F;
	mstatus <= 12'b001001001110;
	pmStack <= 12'b001001001110;
	imStack <= 32'h77777777;
	nmif <= 1'b0;
	ldd <= 1'b0;
  ia <= 9'd0;
	mrloc <= 3'd0;
	msip <= 1'b0;
	ugip <= 1'b0;
	rprv <= 5'd0;
	poptrace <= 1'b0;
	cid <= 5'd0;
	ir <= 32'h0;
	ir[6:0] <= `ALU;
end
else begin
ldd <= 1'b0;
if (pe_nmi)
	nmif <= 1'b1;
ld_time <= {ld_time[4:0],1'b0};
wc_times <= wc_time;
if (wc_time_irq==1'b0)
	wc_time_irq_clr <= 1'd0;
poptrace <= 1'b0;
wrirf <= 1'b0;

case (state)

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Instruction Fetch and Writeback
// Get the instruction from the rom.
// Increment the program counter.
// Update the register file (actual clocking above).
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
IFETCH:
	begin
		instret <= instret + 2'd1;
		// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  - 
		// WRITEBACK
		// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  - 
		// Update CSRs
		if (!illegal_insn && opcode==`SYSTEM) begin
			case(funct3)
			3'd1,3'd5:
				if (Rs1!=5'd0)
				casez({funct7,Rs2})
			  12'h044:  uip[0] <= ia[0];
//				12'h044:	begin if (UserMode) uip <= ia; end
				12'h300:	begin mstatus <= ia; end
				12'h301:	begin mtvec <= {ia[31:2],2'b0}; end
				12'h304:	begin mie <= ia; end
				12'h321:	begin mtimecmp <= ia; end
				12'h340:	begin mscratch <= ia; end
//				12'b00??_0100_0001: begin mepc[rprv] <= ia; end
				12'h341:	begin mepc <= ia; end
				12'h342:	begin mcause <= ia; end
				12'h343:  begin mbadaddr <= ia; end
				12'h344:	begin msip <= ia[3]; end
				12'h7A0:  traceOn <= ia[0];
				12'h7C4:  begin pmStack <= ia; end
				12'h7C5:	begin imStack <= ia; end
//				12'h801:  begin if (UserMode) usema <= ia; end
				default:	;
				endcase
			3'd2,3'd6:
				if (Rs1!=5'd0)
				case({funct7,Rs2})
				// No setting CSR $000
			  12'h044:  uip[0] <= uip[0] | ia[0];
//				12'h044:	if (UserMode) uip <= uip | ia;
			  12'h300:  begin
		                mstatus <= mstatus | ia;
			            end
				12'h304:	mie <= mie | ia;
				12'h344:	msip <= msip | ia[3];
				12'h7A0:  traceOn <= traceOn | ia[0];
        12'h7C4:  if (MachineMode) pmStack <= pmStack | ia;
				12'h7C5:	if (MachineMode) imStack <= imStack | ia;
				default: ;
				endcase
			3'd3,3'd7:
				if (Rs1!=5'd0)
				case({funct7,Rs2})
			  12'h044:  uip[0] <= uip[0] & ~ia[0];
//				12'h044:	if (UserMode) uip <= uip & ~ia;
				// For the status register interrupts are allowed to be enabled from
				// user mode. Interrupts cannot be disabled from user mode.
				12'h300:  mstatus <= mstatus & ~ia;
				12'h304:	mie <= mie & ~ia;
				12'h344:	msip <= msip & ~ia[3];
				12'h7A0:  traceOn <= traceOn & ~ia[0];
//				12'h801:  if (UserMode) usema <= usema & ~ia;
        12'h7C4:  pmStack <= pmStack & ~ia;
				12'h7C5:	imStack <= imStack & ~ia;
				default: ;
				endcase
			default:	;
			endcase
		end
		// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  - 
		// IFETCH
		// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  - 
		if (cid != 5'd0)
			cid <= cid - 2'd1;
		if (traceDataCount > 10'd1020)
			poptrace <= 1'b1;
		illegal_insn <= 1'b1;
		ipc <= pc;
		vpa_o <= HIGH;
		cyc_o <= HIGH;
		stb_o <= HIGH;
		sel_o <= pc[3] ? 8'hF0 : 8'h0F;
		adr_o <= pc;
		tGoto(IFETCH2);
		if (nmif) begin
			nmif <= 1'b0;
			cyc_o <= LOW;
			tException(32'h800000FE,pc,imStack[3:0]);
			pc <= mtvec + 8'hFC;
		end
		else if (mip[7] & mie[7] & ie & ~mloco && cid==5'd0) begin
			cyc_o <= LOW;
			tException(32'h80000001,pc,imStack[3:0]);  // timer IRQ
		end
		else if (mip[3] & mie[3] & ie & ~mloco && cid==5'd0) begin
			cyc_o <= LOW;
			tException(32'h80000002, pc, imStack[3:0]); // software IRQ
		end
		else if (pc[1:0] != 2'b00) begin
			cyc_o <= LOW;
			tException(32'h00000000,pc,imStack[3:0]);
		end
		else
			pc <= pc + 3'd4;
		// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  - 
		// WRITEBACK
		// Writeback: exception return (modifies PC)
		// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  - 
		// Unaligned PC check
		if (pc[1:0]!=2'b00)
		  tException(32'd0, ipc, imStack[3:0]);
		if (illegal_insn)
		  tException(32'd2, ipc, imStack[3:0]);
		case(ir)
		`ERET,`MRET:
			begin
				pc <= mepc;
				adr_o <= mepc;
				sel_o <= mepc[3] ? 8'hF0 : 8'h0F;
				mstatus[11:0] <= {2'b00,1'b1,mstatus[11:3]};
				pmStack <= {3'b001,pmStack[29:3]};
				imStack <= {4'h7,imStack[31:4]};
				mrloc <= 3'd3;
			end
		endcase
	end
IFETCH2:
	if (err_i)
		tException(32'h00000019,ipc,imStack[3:0]);
	else if (ack_i) begin
		tClearBus();
		ir <= dat_i >> {adr_o[3],5'b0};
		tGoto(DECODE);
	end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Decode Stage
// Decode the register fields, immediate values, and branch displacement.
// Determine if instruction will update register file.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DECODE:
	begin
		state <= RFETCH;
		// Set some sensible decode defaults
		Rd <= 5'd0;
		imm <= 32'd0;
		// Override defaults
		case(opcode)
		`AUIPC,`LUI:
			begin
				illegal_insn <= 1'b0;
				Rd <= ir[11:7];
				imm <= {ir[31:12],12'd0};
			end
		`JAL:
			begin
				illegal_insn <= 1'b0;
				Rd <= ir[11:7];
				imm <= {{11{ir[31]}},ir[31],ir[19:12],ir[20],ir[30:21],1'b0};
			end
		`JALR:
			begin
				illegal_insn <= 1'b0;
				Rd <= ir[11:7];
				imm <= {{20{ir[31]}},ir[31:20]};
			end
		`LOAD:
			begin
				illegal_insn <= 1'b0;
				Rd <= ir[11:7];
				imm <= {{20{ir[31]}},ir[31:20]};
			end
		`STORE:
			begin
				illegal_insn <= 1'b0;
				imm <= {{20{ir[31]}},ir[31:25],ir[11:7]};
			end
		7'd13:
			begin
				Rd <= ir[11:7];
				case (funct3)
			  3'd3: 
			    begin
				    imm <= {{20{ir[31]}},ir[31:20]};
			    end
			  default:  ;
				endcase
			end
		`ALUI:
			begin
				case(funct3)
				3'd0:	imm <= {{20{ir[31]}},ir[31:20]};
				3'd1: imm <= ir[25:20];
				3'd2:	imm <= {{20{ir[31]}},ir[31:20]};
				3'd3: imm <= {{20{ir[31]}},ir[31:20]};
				3'd4: imm <= {{20{ir[31]}},ir[31:20]};
				3'd5: imm <= ir[25:20];
				3'd6: imm <= {{20{ir[31]}},ir[31:20]};
				3'd7: imm <= {{20{ir[31]}},ir[31:20]};
				endcase
				Rd <= ir[11:7];
			end
		`ALUWI:
			begin
				case(funct3)
				3'd0:	imm <= {{20{ir[31]}},ir[31:20]};
				3'd1: imm <= ir[24:20];
				3'd2:	imm <= {{20{ir[31]}},ir[31:20]};
				3'd3: imm <= {{20{ir[31]}},ir[31:20]};
				3'd4: imm <= {{20{ir[31]}},ir[31:20]};
				3'd5: imm <= ir[24:20];
				3'd6: imm <= {{20{ir[31]}},ir[31:20]};
				3'd7: imm <= {{20{ir[31]}},ir[31:20]};
				endcase
				Rd <= ir[11:7];
			end
		`ALU,`ALUW,7'd115:
			begin
				Rd <= ir[11:7];
			end
		`Bcc:
			imm <= {{WID-13{ir[31]}},ir[31],ir[7],ir[30:25],ir[11:8],1'b0};
		endcase
	end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Register fetch stage
// Fetch values from register file.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
RFETCH:
	begin
		ia2 = Rs1==5'd0 ? {WID{1'd0}} : iregfile[Rs1];
		ib2 = Rs2==5'd0 ? {WID{1'd0}} : iregfile[Rs2];
    ea <= ia2 + imm;
    ia <= ia2;
    ib <= ib2;
    case(opcode)
    `LOAD:	tGoto(MEMORY_SETUP);
    `STORE:	tGoto(MEMORY_SETUP);
    default:	tGoto (EXECUTE);
    endcase
	end

NSIMM:
  begin
		cyc_o <= HIGH;
		stb_o <= HIGH;
		sel_o <= pc[3] ? 8'hF0 : 8'h0F;
		adr_o <= pc;
  	pc <= pc + 3'd4;
		state <= NSIMM2;
  end
NSIMM2:
	if (ack_i) begin
		vpa_o <= LOW;
		cyc_o <= LOW;
		stb_o <= LOW;
		sel_o <= 4'h0;
		adr_o <= pc;
		imm <= dat_i[31:0];
		state <= REGFETCH3;
	end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Execute stage
// Execute the instruction.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EXECUTE:
	begin
		tGoto (IFETCH);
		case(opcode)
		`LUI:	begin res <= imm; wrirf <= 1'b1; end
		`AUIPC:	begin res <= {ipc[31:12],12'd0} + imm; wrirf <= 1'b1; end
		7'd13:	illegal_insn <= 1'b1;
		`ALU:
			case(funct3)
			3'd0:
				case(funct7)
				7'd0:		begin res <= ia + ib; wrirf <= 1'b1; illegal_insn <= 1'b0; end
				7'd1:		begin state <= MUL1; mathCnt <= 8'd0; illegal_insn <= 1'b0; end
				7'd32:	begin
				          res <= ia - ib;
				          wrirf <= 1'b1;
				          illegal_insn <= 1'b0;
				        end
				default:	;
				endcase
			3'd1:
				case(funct7)
				7'd0:	begin res <= ia << ib[5:0]; wrirf <= 1'b1; illegal_insn <= 1'b0; end
				7'd1:		begin state <= MUL1; mathCnt <= 8'd0; illegal_insn <= 1'b0; end
				default:	;
				endcase
			3'd2:
				case(funct7)
				7'd0:	begin res <= $signed(ia) < $signed(ib); wrirf <= 1'b1; illegal_insn <= 1'b0; end
				7'd1:		begin state <= MUL1; mathCnt <= 8'd0; illegal_insn <= 1'b0; end
				default:	;
				endcase
			3'd3:
				case(funct7)
				7'd0:	begin res <= ia < ib; wrirf <= 1'b1; illegal_insn <= 1'b0; end
				7'd1:		begin state <= MUL1; mathCnt <= 8'd0; illegal_insn <= 1'b0; end
				default:	;
				endcase
			3'd4:
				case(funct7)
				7'd0:	begin res <= ia ^ ib; wrirf <= 1'b1; illegal_insn <= 1'b0; end
				7'd1:		begin state <= MUL1; mathCnt <= 8'd20; illegal_insn <= 1'b0; end
				default:	;
				endcase
			3'd5:
				case(funct7)
				7'd0:	begin res <= ia >> ib[5:0]; wrirf <= 1'b1; illegal_insn <= 1'b0; end
				7'd1:		begin state <= MUL1; mathCnt <= 8'd20; illegal_insn <= 1'b0; end
				7'd32:	
					begin
						res <= {{64{ia[WID-1]}},ia} >> ib[5:0];
 						illegal_insn <= 1'b0;
 					end
				default:	;
				endcase
			3'd6:
				case(funct7)
				7'd0:	begin res <= ia | ib; wrirf <= 1'b1; illegal_insn <= 1'b0; end
				7'd1:		begin state <= MUL1; mathCnt <= 8'd20; illegal_insn <= 1'b0; end
				default:	;
				endcase
			3'd7:
				case(funct7)
				7'd0:	begin res <= ia & ib; wrirf <= 1'b1; illegal_insn <= 1'b0; end
				7'd1:		begin state <= MUL1; mathCnt <= 8'd20; illegal_insn <= 1'b0; end
				default:	;
				endcase
			endcase	
		`ALUW:
			case(funct3)
			3'd0:
				case(funct7)
				7'd0:
					begin
						res2 = ia + ib;
		        res <= {{32{res2[31]}},res2[31:0]};
		        wrirf <= 1'b1; 
						illegal_insn <= 1'b0;
					end
				7'd1:		begin state <= MULW1; mathCnt <= 8'd0; illegal_insn <= 1'b0; end
				7'd32:
					begin
	          res2 = ia - ib;
		        res <= {{32{res2[31]}},res2[31:0]};
		        wrirf <= 1'b1; 
	          illegal_insn <= 1'b0;
	        end
				default:	;
				endcase
			3'd1:
				case(funct7)
				7'd0:
					begin
						res2 = ia[31:0] << ib[4:0];
		        res <= {{32{res2[31]}},res2[31:0]};
		        wrirf <= 1'b1; 
						illegal_insn <= 1'b0;
					end
				7'd1:		begin state <= MULW1; mathCnt <= 8'd0; illegal_insn <= 1'b0; end
				default:	;
				endcase
			3'd2:
				case(funct7)
				7'd0:	begin res <= $signed(ia[31:0]) < $signed(ib[31:0]); wrirf <= 1'b1; illegal_insn <= 1'b0; end
				7'd1:		begin state <= MULW1; mathCnt <= 8'd0; illegal_insn <= 1'b0; end
				default:	;
				endcase
			3'd3:
				case(funct7)
				7'd0:	begin res <= ia[31:0] < ib[31:0]; wrirf <= 1'b1; illegal_insn <= 1'b0; end
				7'd1:		begin state <= MULW1; mathCnt <= 8'd0; illegal_insn <= 1'b0; end
				default:	;
				endcase
			3'd4:
				case(funct7)
				7'd0:
					begin
						res2 = ia ^ ib;
		        res <= {{32{res2[31]}},res2[31:0]};
		        wrirf <= 1'b1; 
						illegal_insn <= 1'b0;
					end
				7'd1:		begin state <= MULW1; mathCnt <= 8'd20; illegal_insn <= 1'b0; end
				default:	;
				endcase
			3'd5:
				case(funct7)
				7'd0:	begin res <= ia[31:0] >> ib[4:0]; wrirf <= 1'b1; illegal_insn <= 1'b0; end
				7'd1:		begin state <= MULW1; mathCnt <= 8'd20; illegal_insn <= 1'b0; end
				7'd32:	
					begin
						res <= {{64{ia[WID-1]}},ia} >> ib[5:0];
						wrirf <= 1'b1; 
 						illegal_insn <= 1'b0;
 					end
				default:	;
				endcase
			3'd6:
				case(funct7)
				7'd0:
					begin
						res2 <= ia | ib;
		        res <= {{32{res2[31]}},res2[31:0]};
		        wrirf <= 1'b1; 
						illegal_insn <= 1'b0;
					end
				7'd1:		begin state <= MULW1; mathCnt <= 8'd20; illegal_insn <= 1'b0; end
				default:	;
				endcase
			3'd7:
				case(funct7)
				7'd0:
					begin
						res2 = ia & ib;
		        res <= {{32{res2[31]}},res2[31:0]};
		        wrirf <= 1'b1; 
						illegal_insn <= 1'b0;
					end
				7'd1:		begin state <= MULW1; mathCnt <= 8'd20; illegal_insn <= 1'b0; end
				default:	;
				endcase
			endcase	
		`ALUI:
			case(funct3)
			3'd0:
				begin
	        res <= ia + imm;
	        wrirf <= 1'b1; 
	        illegal_insn <= 1'b0;
	      end
			3'd1:
				case(funct7)
				7'd0:	begin res <= ia << imm[5:0]; wrirf <= 1'b1; illegal_insn <= 1'b0; end
				default:	;
				endcase
			3'd2:	begin res <= $signed(ia) < $signed(imm); wrirf <= 1'b1; illegal_insn <= 1'b0; end
			3'd3:	begin res <= ia < imm; wrirf <= 1'b1; illegal_insn <= 1'b0; end
			3'd4:	begin res <= ia ^ imm; wrirf <= 1'b1; illegal_insn <= 1'b0; end
			3'd5:
				case(funct7)
				7'd0:	begin res <= ia >> imm[4:0]; wrirf <= 1'b1; illegal_insn <= 1'b0; end
				7'd16:
					begin
						res <= ({{64{ia[WID-1]}},ia} >> imm[5:0]);
						wrirf <= 1'b1; 
						illegal_insn <= 1'b0;
					end
				endcase
			3'd6:	begin res <= ia | imm; wrirf <= 1'b1; illegal_insn <= 1'b0; end
			3'd7:	begin res <= ia & imm; wrirf <= 1'b1; illegal_insn <= 1'b0; end
			endcase
		`ALUWI:
			case(funct3)
			3'd0:
				begin
	        res2 = ia + imm;
	        res <= {{32{res2[31]}},res2[31:0]};
	        wrirf <= 1'b1; 
	        illegal_insn <= 1'b0;
	      end
			3'd1:
				case(funct7)
				7'd0:
					begin
						res2 = ia[31:0] << imm[4:0];
		        res <= {{32{res2[31]}},res2[31:0]};
		        wrirf <= 1'b1; 
						illegal_insn <= 1'b0;
					end
				default:	;
				endcase
			3'd2:	begin res <= $signed(ia) < $signed(imm); wrirf <= 1'b1; illegal_insn <= 1'b0; end
			3'd3:	begin res <= ia < imm; wrirf <= 1'b1; illegal_insn <= 1'b0; end
			3'd4:
				begin
					res2 = ia ^ imm;
	        res <= {{32{res2[31]}},res2[31:0]};
	        wrirf <= 1'b1; 
					illegal_insn <= 1'b0;
				end
			3'd5:
				case(funct7)
				7'd0:	begin res <= ia[31:0] >> imm[4:0]; wrirf <= 1'b1; illegal_insn <= 1'b0; end
				7'd16:
					begin
						res <= ({{96{ia[31]}},ia[31:0]} >> imm[5:0]);
						wrirf <= 1'b1; 
						illegal_insn <= 1'b0;
					end
				default:	;
				endcase
			3'd6:
				begin
					res2 = ia | imm;
	        res <= {{32{res2[31]}},res2[31:0]};
	        wrirf <= 1'b1; 
					illegal_insn <= 1'b0;
				end
			3'd7:
				begin
					res2 = ia & imm;
	        res <= {{32{res2[31]}},res2[31:0]};
	        wrirf <= 1'b1; 
					illegal_insn <= 1'b0;
				end
			endcase
		`JAL:
			begin
				res <= pc;
				wrirf <= 1'b1; 
				pc <= ipc + imm;
				pc[0] <= 1'b0;
			end
		`JALR:
			begin
				res <= pc;
				wrirf <= 1'b1; 
				pc <= ia + imm;
				pc[0] <= 1'b0;
			end
		`Bcc:
			case(funct3)
			3'd0:	begin if (ia==ib) pc <= ipc + imm; illegal_insn <= 1'b0; end
			3'd1: begin if (ia!=ib) pc <= ipc + imm; illegal_insn <= 1'b0; end
			3'd4:	begin if ($signed(ia) < $signed(ib)) pc <= ipc + imm; illegal_insn <= 1'b0; end
			3'd5:	begin if ($signed(ia) >= $signed(ib)) pc <= ipc + imm; illegal_insn <= 1'b0; end
			3'd6:	begin if (ia < ib) pc <= ipc + imm; illegal_insn <= 1'b0; end
			3'd7:	begin if (ia >= ib) pc <= ipc + imm; illegal_insn <= 1'b0; end
			default:	;
			endcase
		`LOAD,`STORE:
			tGoto (MEMORY_SETUP);
		`SYSTEM:
			begin
				case(ir)
				`EBREAK:
				  tException(4'd3, pc, imStack[3:0]);
				`ECALL:
  			  tException(4'h8 + pmStack[2:1],pc, imStack[3:0]);
				`ERET,`MRET:
					if (MachineMode) begin
						illegal_insn <= 1'b0;
					end
				default:
					begin
					case(funct3)
					3'd1,3'd2,3'd3,3'd5,3'd6,3'd7:
						casez({funct7,Rs2})
						12'h044:	begin res <= uip[0]; wrirf <= 1'b1; illegal_insn <= 1'b0; end
						12'h300:	begin res <= mstatus; wrirf <= 1'b1; illegal_insn <= 1'b0; end
						12'h301:	begin res <= mtvec; wrirf <= 1'b1; illegal_insn <= 1'b0; end
						12'h304:	begin res <= mie; wrirf <= 1'b1; illegal_insn <= 1'b0; end
						12'h321:	begin res <= mtimecmp; wc_time_irq_clr <= 6'h3F; wrirf <= 1'b1; illegal_insn <= 1'b0; end
						12'h340:	begin res <= mscratch; wrirf <= 1'b1; illegal_insn <= 1'b0; end
						12'h341:	begin res <= mepc; wrirf <= 1'b1; illegal_insn <= 1'b0; end
						12'h342:	begin res <= mcause; wrirf <= 1'b1; illegal_insn <= 1'b0; end
						12'h343:	begin res <= mbadaddr; wrirf <= 1'b1; illegal_insn <= 1'b0; end
						12'h344:	begin res <= mip; wrirf <= 1'b1; illegal_insn <= 1'b0; end
						12'h7A0:  begin res <= traceOn; wrirf <= 1'b1; illegal_insn <= 1'b0; end
						12'hC00:	begin res <= tick[31: 0]; wrirf <= 1'b1; illegal_insn <= 1'b0; end
						12'hC80:	begin res <= tick[63:32]; wrirf <= 1'b1; illegal_insn <= 1'b0; end
						12'hC01,12'h701,12'hB01:	begin res <= wc_times[31: 0]; wrirf <= 1'b1; illegal_insn <= 1'b0; end
						12'hC81,12'h741,12'hB81:	begin res <= wc_times[63:32]; wrirf <= 1'b1; illegal_insn <= 1'b0; end
						12'hC02:	begin res <= instret[31: 0]; wrirf <= 1'b1; illegal_insn <= 1'b0; end
						12'hC82:	begin res <= instret[63:32]; wrirf <= 1'b1; illegal_insn <= 1'b0; end
						12'hF00:	begin res <= mcpuid; wrirf <= 1'b1; illegal_insn <= 1'b0; end	// cpu description
						12'hF01:	begin res <= mimpid; wrirf <= 1'b1; illegal_insn <= 1'b0; end // implmentation id
						12'hF10:	begin res <= hartid_i; wrirf <= 1'b1; illegal_insn <= 1'b0; end
//						12'hFC1:  begin res <= usema; illegal_insn <= 1'b0; end
						default:	;
						endcase
					default:	;
					endcase
					case(funct3)
					3'd5,3'd6,3'd7:	ia <= {27'd0,Rs1};
					default:	;
					endcase
					end
				endcase
			end
		default:	;
		endcase
	end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CSR:  tGoto (CSR2);
CSR2:
  begin
  	wrirf <= 1'b1;
    casez(ia[3:0])
    4'd13:		res <= traceOut[63:32];
    4'b1110:  res <= {traceEmpty,traceValid,traceDataCount[9:0],traceOut[19:0]};
    4'b1111:  res <= {traceEmpty,traceValid,traceDataCount[9:0],8'h00,traceOut[31:20]};
    default:  res <= 32'h0;
    endcase
    tGoto (IFETCH);
  end
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Multiply / Divide
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Adjust for sign
MUL1:
	begin
		ldd <= 1'b1;
		case(funct3)
		3'd0,3'd1,3'd4,3'd6:							// MUL / MULH / DIV / REM
			begin
				sgn <= ia[WID-1] ^ ib[WID-1];	// compute output sign
				if (ia[WID-1]) ia <= -ia;			// Make both values positive
				if (ib[WID-1]) ib <= -ib;
				state <= MUL2;
			end
		3'd2:										// MULHSU
			begin
				sgn <= ia[WID-1];
				if (ia[WID-1]) ia <= -ia;
				state <= MUL2;
			end
		3'd3,3'd5,3'd7:	state <= MUL2;		// MULHU / DIVU / REMU
		endcase
	end
// Capture result
MUL2:
	begin
		mathCnt <= mathCnt - 8'd1;
		if (mathCnt==8'd0) begin
			state <= IFETCH;
			wrirf <= 1'b1; 
			case(funct3)
			3'd0:	res <= sgn ? nprod[WID-1:0] : prod[WID-1:0];
			3'd1:	res <= sgn ? nprod[WID*2-1:WID] : prod[WID*2-1:WID];
			3'd2:	res <= sgn ? nprod[WID*2-1:WID] : prod[WID*2-1:WID];
			3'd3:	res <= prod[WID*2-1:WID];
			3'd4:	res <= sgn ? ndiv_q[WID*2-1:WID] : div_q[WID*2-1:WID];
			3'd5: res <= div_q[WID*2-1:WID];
			3'd6:	res <= sgn ? ndiv_r : div_r;
			3'd7:	res <= div_r;
			endcase
		end
	end
MULW1:
	begin
		ldd <= 1'b1;
		case(funct3)
		3'd0,3'd1,3'd4,3'd6:							// MUL / MULH / DIV / REM
			begin
				sgn <= ia[31] ^ ib[31];	// compute output sign
				if (ia[31]) ia <= -ia;			// Make both values positive
				if (ib[31]) ib <= -ib;
				state <= MULW2;
			end
		3'd2:										// MULHSU
			begin
				sgn <= ia[31];
				if (ia[31]) ia <= -ia;
				state <= MULW2;
			end
		3'd3,3'd5,3'd7:	state <= MULW2;		// MULHU / DIVU / REMU
		endcase
	end
// Capture result
MULW2:
	begin
		mathCnt <= mathCnt - 8'd1;
		if (mathCnt==8'd0) begin
			state <= IFETCH;
			wrirf <= 1'b1; 
			case(funct3)
			3'd0:	res <= sgn ? nprod32[31:0] : prod32[31:0];
			3'd1:	res <= sgn ? nprod32[63:32] : prod32[63:32];
			3'd2:	res <= sgn ? nprod32[63:32] : prod32[63:32];
			3'd3:	res <= prod32[63:32];
			3'd4:	res <= sgn ? ndiv_q32[63:32] : div_q32[63:32];
			3'd5: res <= div_q32[63:32];
			3'd6:	res <= sgn ? ndiv_r32 : div_r32;
			3'd7:	res <= div_r32;
			endcase
		end
	end
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Memory stage
// Load or store the memory value.
// Wait for operation to complete.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
MEMORY_SETUP:
  begin
		tGoto (MEMORY_WAIT);
  	case(opcode)
  	`LOAD:
  		case(funct3)
  		`LB,`LH,`LW,`LD,`LBU,`LHU,`LWU:
  			begin
					cyc_o <= HIGH;
					stb_o <= HIGH;
					sel_o <= ssel[7:0];
			 		dat_o <= sdat[63:0];
			 		adr_o <= ea;
				end
			default:
		    tGoto (IFETCH); // Illegal instruction
			endcase
		`STORE:
			begin
    		case(funct3)
    		`SB,`SH,`SW,`SD:
    		  begin
						cyc_o <= HIGH;
						stb_o <= HIGH;
    		  	we_o <= HIGH;
						sel_o <= ssel[7:0];
				 		dat_o <= sdat[63:0];
						adr_o <= ea;
    		    illegal_insn <= 1'b0;
    		  end
    		default:	
  		    tGoto (IFETCH); // Illegal instruction
    		endcase
			end
		// Hardware error - can't get here
		default:
	    tGoto (IFETCH); // Illegal instruction
    endcase
  end
MEMORY_WAIT:
	if (err_i) begin
    tClearBus();
		tException(32'h00000019,ipc,imStack[3:0]);
	end
	else if (rty_i) begin
    tClearBus();
		tGoto (MEMORY_SETUP);
	end
	else if (ack_i) begin
    tClearBus();
		if (ssel[15:8]!=8'h0)
	  	cyc_o <= HIGH;
		tGoto (MEMORY2_SETUP);
		dati[63:0] <= dat_i;
	end
// Run a second bus cycle to handle unaligned access.
// The paging unit needs a cycle for address lookup on a change of adr_o.
MEMORY2_SETUP:
	if (~ack_i) begin
		case(opcode)
		`LOAD:
			case(funct3)
			`LB:	begin res <= {{56{datiL[7]}},datiL[7:0]}; wrirf <= 1'b1; illegal_insn <= 1'b0; end
			`LH:  begin res <= {{48{datiL[15]}},datiL[15:0]}; wrirf <= 1'b1; illegal_insn <= 1'b0; end
			`LW:	begin res <= {{32{datiL[31]}},datiL[31:0]}; wrirf <= 1'b1; illegal_insn <= 1'b0; end
			`LD:	begin res <= datiL; wrirf <= 1'b1; illegal_insn <= 1'b0; end
			`LBU:	begin res <= {56'd0,datiL[7:0]}; wrirf <= 1'b1; illegal_insn <= 1'b0; end
			`LHU:	begin res <= {48'd0,datiL[15:0]}; wrirf <= 1'b1; illegal_insn <= 1'b0; end
			`LWU:	begin res <= {32'd0,datiL[31:0]}; wrirf <= 1'b1; illegal_insn <= 1'b0; end
			default:	;
			endcase
		endcase
		if (ssel[15:8]==8'h00)
		  tGoto (IFETCH);
		else begin
			cyc_o <= HIGH;
			stb_o <= HIGH;
	  	we_o <= opcode==`STORE;
			sel_o <= ssel[15:8];
	 		dat_o <= sdat[127:64];
			adr_o <= {ea[31:2]+2'd1,2'd0};
  		tGoto (MEMORY2_WAIT);
  	end
  end
MEMORY2_WAIT:
	if (err_i) begin
		tClearBus();
		tException(32'h00000019,ipc,imStack[3:0]);
	end
	else if (rty_i) begin
		tClearBus();
		cyc_o <= HIGH;
		tGoto (MEMORY2_SETUP);
	end
	else if (ack_i) begin
		tClearBus();
		dati[127:64] <= dat_i;
		tGoto (MEMORY_PROCESS);
	end
MEMORY_PROCESS:
	if (~ack_i) begin
		case(opcode)
		`LOAD:
			case(funct3)
			`LH:  begin res <= {{48{datiL[15]}},datiL[15:0]}; wrirf <= 1'b1; illegal_insn <= 1'b0; end
			`LW:	begin res <= {{32{datiL[31]}},datiL[31:0]}; wrirf <= 1'b1; illegal_insn <= 1'b0; end
			`LD:	begin res <= datiL; wrirf <= 1'b1; illegal_insn <= 1'b0; end
			`LHU:	begin res <= {48'd0,datiL[15:0]}; wrirf <= 1'b1; illegal_insn <= 1'b0; end
			`LWU:	begin res <= {32'd0,datiL[31:0]}; wrirf <= 1'b1; illegal_insn <= 1'b0; end
			default:	;
			endcase
		default:	;
		endcase
		tGoto (IFETCH);
	end
endcase
end

task tClearBus;
begin
	vpa_o <= LOW;
	cyc_o <= LOW;
	stb_o <= LOW;
	we_o <= LOW;
	sel_o <= 8'h00;
end
endtask

task tException;
input [31:0] cse;
input [31:0] tpc;
input [3:0] ml;
begin
	tClearBus();
	pc <= mtvec + {pmStack[2:1],6'h00};
	mepc <= tpc;
	pmStack <= {pmStack[28:0],2'b11,1'b0};
	mstatus[11:0] <= {mstatus[8:0],2'b11,1'b0};
	imStack <= {imStack[27:0],ml};
	mcause <= cse;
	illegal_insn <= 1'b0;
  rprv <= 5'h0;
	tGoto (IFETCH);
end
endtask

task tGoto;
input [5:0] nst;
begin
  state <= nst;
end
endtask

endmodule
