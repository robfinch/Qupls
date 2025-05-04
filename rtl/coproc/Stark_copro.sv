// ============================================================================
//        __
//   \\__/ o\    (C) 2025  Robert Finch, Waterloo
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
// 1150 LUTs / 580 FFs / 4 BRAMS / 6 DSP
// ============================================================================

import const_pkg::*;
import Stark_pkg::*;

module Stark_coproc(rst, clk, cyc, wr, adr, din, dout, ack);
input rst;
input clk;
output reg cyc;
output reg wr;
output [15:0] adr;
input [63:0] din;
output reg [63:0] dout;
input ack;

reg [31:0] regfile [0:31];
reg [7:0] cr [0:7];
reg [15:0] br [0:7];
reg [15:0] pc,if_pc,dc_pc;
reg [15:0] mar,marx;
Stark_pkg::instruction_t ir,rf_ir,mf_ir,ex_ir;
reg [2:0] CRd,CRdr,CRdm,CRdx,CRs1;
reg [2:0] BRd,BRdr,BRdm;
reg [2:0] BRs1;
reg [2:0] crbit,crbitr;
reg [4:0] Rd,Rdr,Rdm,Rdx;
reg ir_v,dc_v,rf_v,mf_v,ex_v;
reg [4:0] Rs1;
reg [4:0] Rs2;
reg [31:0] a,a1,b,b1,imm;
reg [31:0] res,res1;
reg [7:0] crres;
reg [15:0] brres;
reg [31:0] ldres;
reg [31:0] prod,produ;
reg [7:0] cra,cra1;
reg is_imm,is_cli;
reg wr_cr,wr_br;
reg wr_rf,wr_rflo, wr_rfhi;
wire rsta,rstb;
wire clka,clkb;
wire ena,enb;
reg [31:0] dina;
wire [31:0] douta, doutb;
wire sleep;
reg wea;
wire web;
assign rsta = rst;
assign rstb = rst;
assign clka = ~clk;
assign clkb = ~clk;
assign ena = 1'b1;
assign enb = 1'b1;
assign web = 1'b0;
assign sleep = 1'b0;
assign adr = mar;

typedef enum logic [2:0] {
	COPRO_IFETCH = 3'd0,
	COPRO_DECODE = 3'd1,
	COPRO_RFETCH = 3'd2,
	COPRO_MEMORY = 3'd3,
	COPRO_EXECUTE = 3'd4
} state_e;
state_e state;

// xpm_memory_tdpram: True Dual Port RAM
// Xilinx Parameterized Macro, version 2024.1

xpm_memory_tdpram #(
  .ADDR_WIDTH_A(12),               // DECIMAL
  .ADDR_WIDTH_B(12),               // DECIMAL
  .AUTO_SLEEP_TIME(0),            // DECIMAL
  .BYTE_WRITE_WIDTH_A(32),        // DECIMAL
  .BYTE_WRITE_WIDTH_B(32),        // DECIMAL
  .CASCADE_HEIGHT(0),             // DECIMAL
  .CLOCKING_MODE("common_clock"), // String
  .ECC_BIT_RANGE("7:0"),          // String
  .ECC_MODE("no_ecc"),            // String
  .ECC_TYPE("none"),              // String
  .IGNORE_INIT_SYNTH(0),          // DECIMAL
  .MEMORY_INIT_FILE("none"),      // String
  .MEMORY_INIT_PARAM("0"),        // String
  .MEMORY_OPTIMIZATION("true"),   // String
  .MEMORY_PRIMITIVE("auto"),      // String
  .MEMORY_SIZE(4096*32),          // DECIMAL
  .MESSAGE_CONTROL(0),            // DECIMAL
  .RAM_DECOMP("auto"),            // String
  .READ_DATA_WIDTH_A(32),         // DECIMAL
  .READ_DATA_WIDTH_B(32),         // DECIMAL
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
  .WRITE_DATA_WIDTH_A(32),        // DECIMAL
  .WRITE_DATA_WIDTH_B(32),        // DECIMAL
  .WRITE_MODE_A("no_change"),     // String
  .WRITE_MODE_B("no_change"),     // String
  .WRITE_PROTECT(1)               // DECIMAL
)
ram_rom (
  .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                   // on the data output of port A.

  .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                   // on the data output of port A.

  .douta(douta),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
  .doutb(doutb),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
  .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                   // on the data output of port A.

  .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                   // on the data output of port B.

  .addra(mar[13:2]),               // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
  .addrb(pc[13:2]),                // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
  .clka(clka),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                   // parameter CLOCKING_MODE is "common_clock".

  .clkb(clkb),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                   // "independent_clock". Unused when parameter CLOCKING_MODE is
                                   // "common_clock".

  .dina(dina),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
  .dinb(32'h0),                    // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
  .ena(ena),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
                                   // cycles when read or write operations are initiated. Pipelined
                                   // internally.

  .enb(enb),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
                                   // cycles when read or write operations are initiated. Pipelined
                                   // internally.

  .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
                                   // ECC enabled (Error injection capability is not available in
                                   // "decode_only" mode).

  .injectdbiterrb(1'b0), // 1-bit input: Controls double bit error injection on input data when
                                   // ECC enabled (Error injection capability is not available in
                                   // "decode_only" mode).

  .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
                                   // ECC enabled (Error injection capability is not available in
                                   // "decode_only" mode).

  .injectsbiterrb(1'b0), // 1-bit input: Controls single bit error injection on input data when
                                   // ECC enabled (Error injection capability is not available in
                                   // "decode_only" mode).

  .regcea(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                   // data path.

  .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                   // data path.

  .rsta(rsta),                     // 1-bit input: Reset signal for the final port A output register stage.
                                   // Synchronously resets output port douta to the value specified by
                                   // parameter READ_RESET_VALUE_A.

  .rstb(rstb),                     // 1-bit input: Reset signal for the final port B output register stage.
                                   // Synchronously resets output port doutb to the value specified by
                                   // parameter READ_RESET_VALUE_B.

  .sleep(sleep),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
  .wea(wea),                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                   // for port A input data port dina. 1 bit wide when word-wide writes are
                                   // used. In byte-wide write configurations, each bit controls the
                                   // writing one byte of dina to address addra. For example, to
                                   // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                   // is 32, wea would be 4'b0010.

  .web(web)                        // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector
                                   // for port B input data port dinb. 1 bit wide when word-wide writes are
                                   // used. In byte-wide write configurations, each bit controls the
                                   // writing one byte of dinb to address addrb. For example, to
                                   // synchronously write only bits [15-8] of dinb when WRITE_DATA_WIDTH_B
                                   // is 32, web would be 4'b0010.

);

always_ff @(posedge clk)
if (rst) begin
	pc <= 14'h1000;
	ir <= {26'd0,Stark_pkg::OP_NOP};
	dc_v <= 1'b0;
	rf_v <= 1'b0;
	mf_v <= 1'b0;
	Rd <= 5'd0;
	tGoto(COPRO_IFETCH);
end
else if (cyc ? ack : 1'b1) begin
case (state)
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Instruction fetch
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
COPRO_IFETCH:
begin
  if_pc <= pc;
	pc <= pc + 16'd4;
	ir <= doutb >> {pc[2],5'b0};
	ir_v <= 1'b1;
	tGoto(COPRO_DECODE);
end
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Decode
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
COPRO_DECODE:
begin
	tGoto (COPRO_RFETCH);
	dc_v <= ir_v;
	dc_pc <= if_pc;
	rf_ir <= ir;
	is_imm <= 1'b0;
	is_cli <= 1'b0;
	Rd <= 5'd0;
	case(ir.any.opcode)
	Stark_pkg::OP_CMP:
		begin
			CRd <= ir.cmp.CRd;
			Rs1 <= ir.cmp.Rs1;
			Rs2 <= ir.cmp.Rs2;
			if (ir[31]) begin
				imm <= {{18{ir[30]}},ir[30:17]};
				is_imm <= 1'b1;
			end
			else
				case(ir.cmpcl.lx)
				2'd0:	;		// Rs2
				2'd1:	begin mar <= {pc[15:6],ir.cmpcl.cl,2'b00}; is_cli <= 1'b1; end
				default:	;
				endcase
		end
	Stark_pkg::OP_LOAD,Stark_pkg::OP_STORE,
	Stark_pkg::OP_ADD,Stark_pkg::OP_SUBF:
		begin
			Rd <= ir.alu.Rd;
			Rs1 <= ir.alu.Rs1;
			Rs2 <= ir.alu.Rs2;
			if (ir[31]) begin
				is_imm <= 1'b1;
				imm <= {{18{ir[30]}},ir[30:17]};
			end
			else
				case(ir.alu.lx)
				2'd0:	;		// Rs2
				2'd1:	begin mar <= {pc[15:6],ir.alucli.cl,2'b00}; is_cli <= 1'b1; end
				default:	;
				endcase
		end
	Stark_pkg::OP_AND:
		begin
			Rd <= ir.alu.Rd;
			Rs1 <= ir.alu.Rs1;
			Rs2 <= ir.alu.Rs2;
			if (ir[31]) begin
				is_imm <= 1'b1;
				imm <= {{18{1'b1}},ir[30:17]};
			end
			else
				case(ir.alu.lx)
				2'd0:	;		// Rs2
				2'd1:	begin mar <= {pc[15:6],ir.alucli.cl,2'b00}; is_cli <= 1'b1; end
				default:	;
				endcase
		end
	Stark_pkg::OP_OR,
	Stark_pkg::OP_XOR:
		begin
			Rd <= ir.alu.Rd;
			Rs1 <= ir.alu.Rs1;
			Rs2 <= ir.alu.Rs2;
			if (ir[31]) begin
				is_imm <= 1'b1;
				imm <= {{18{1'b0}},ir[30:17]};
			end
			else
				case(ir.alu.lx)
				2'd0:	;		// Rs2
				2'd1:	begin mar <= {pc[15:6],ir.alucli.cl,2'b00}; is_cli <= 1'b1; end
				default:	;
				endcase
		end
	Stark_pkg::OP_SHIFT:
	  begin
			Rd <= ir.sh.Rd;
			Rs1 <= ir.sh.Rs1;
			Rs2 <= ir.sh.Rs2;
	    if (ir[31]) begin
	    	is_imm <= 1'b1;
	    	imm <= {26'd0,ir.shi.amt};
	    end
	  end
	Stark_pkg::OP_MUL,
	Stark_pkg::OP_DIV:
		begin
			Rd <= ir.sh.Rd;
			Rs1 <= ir.sh.Rs1;
			Rs2 <= ir.sh.Rs2;
	    if (ir[31]) begin
	    	is_imm <= 1'b1;
				imm <= {{18{1'b1}},ir[30:17]};
	    end
			else
				case(ir.alu.lx)
				2'd0:	;		// Rs2
				2'd1:	begin mar <= {pc[15:6],ir.alucli.cl,2'b00}; is_cli <= 1'b1; end
				default:	;
				endcase
		end
	Stark_pkg::OP_B0,Stark_pkg::OP_B1:
		begin
			/*
			ir_v <= 1'b0;
			dc_v <= 1'b0;
			*/
			wr_br <= 1'b1;
			brres <= pc + 16'd4;
			if (ir[31]) begin
				BRd <= ir.bl.BRd;
				pc <= {ir.bl.disp,ir.bl.d0,2'b00};
				tGoto(COPRO_IFETCH);
			end
			else begin
				BRd <= ir.blrlr.BRd;
				BRs1 <= ir.blrlr.BRs;
			end
		end
	Stark_pkg::OP_BCC0,Stark_pkg::OP_BCC1:
		begin
			CRs1 <= ir.bccld.CRs[5:3];
			crbit <= ir.bccld.CRs[2:0];
			BRs1 <= ir.bccld.BRs; 
			imm <= {{19{ir.bccld.disphi[1]}},ir.bccld.disphi,ir.bccld.displo,ir.bccld.d0,2'b00};
			is_imm <= 1'b1;
		end
	endcase
end
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Regfetch
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
COPRO_RFETCH:
begin
	tGoto(COPRO_MEMORY);
	rf_v <= dc_v;
	Rdr <= Rd;
	CRdr <= CRd;
	cyc <= 1'b0;
	wea <= 1'b0;
	wr <= 1'b0;
	mf_ir <= rf_ir;
	a1 = regfile[Rs1];
	b1 = regfile[Rs2];
	if (Rs1==5'd0)
		a1 = 32'd0;
	if (Rs2==5'd0)
		b1 = 32'd0;
	cra1 = cr[CRs1][crbit];
	if (is_cli)
		b1 = douta;
	else if (is_imm)
		b1 = imm;
	mar = a1 + imm;
	dina <= b1;
	case(rf_ir.any.opcode)
	Stark_pkg::OP_LOAD:
		cyc <= mar[15:14]!=2'b11;
	Stark_pkg::OP_STORE:
		begin
			cyc <= mar[15:14]!=2'b11;
			wea <= mar[15:14]==2'b11 && mar[13:12]==2'd3;
			wr <= mar[15:14]!=2'b11 && mar[3];
	    if (mar[3])
	      dout[63:32] <= b1;
	    else
	      dout[31:0] <= b1;
    end
  Stark_pkg::OP_BCC0,Stark_pkg::OP_BCC1:
  	begin
  		if (BRs1==3'd7)
  			b1 = dc_pc + imm;
  		else
  			b1 = br[BRs1] + imm;
  	end
  default:	;
  endcase
end
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Memory
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
COPRO_MEMORY:
begin
	tGoto(COPRO_EXECUTE);
  marx <= mar;
  if (mar[3])
    ldres <= din[63:32];
  else
    ldres <= din[31: 0];
	mf_v <= rf_v;
	Rdm <= Rdr;
	CRdm <= CRdr;
	ex_ir <= mf_ir;
	a <= a1;
	b <= b1;
	cra <= cra1;
	produ <= a1 * b1;
	prod <= $signed(a1) * $signed(b1);
	case(mf_ir.any.opcode)
	Stark_pkg::OP_BCC0,Stark_pkg::OP_BCC1:
		begin
			case (mf_ir.bccld.cnd)
			3'd2:
				if (~cra) begin
					/*
					ir_v <= 1'b0;
					dc_v <= 1'b0;
					rf_v <= 1'b0;
					mf_v <= 1'b0;
					*/
			 		pc <= b1;
			 		tGoto(COPRO_IFETCH);
			 	end
			3'd5:
				if ( cra) begin
					/*
					ir_v <= 1'b0;
					dc_v <= 1'b0;
					rf_v <= 1'b0;
					mf_v <= 1'b0;
					*/
					pc <= b1;
			 		tGoto(COPRO_IFETCH);
				end
			endcase
		end
	default:	;
	endcase
end
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Execute
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
COPRO_EXECUTE:
begin
	tGoto(COPRO_IFETCH);
	Rdx <= Rdm;
	CRdx <= CRdm;
	wr_cr <= 1'b0;
	wr_rf <= 1'b0;
	wr_rflo <= 1'b0;
	wr_rfhi <= 1'b0;
	res = 32'd0;
	crres <= 8'd0;
	case(ex_ir.any.opcode)
	Stark_pkg::OP_CMP:
		begin
			crres[0] <= a == b;
			crres[1] <= ~(|a & |b);
			crres[2] <= ~(|a | |b);
			if (ir.cmp.op2==2'b01) begin	// CMPA
				crres[3] <= a < b;
				crres[4] <= a <= b;
			end
			else begin
				crres[3] <= $signed(a) < $signed(b);
				crres[4] <= $signed(a) <= $signed(b);
			end
			crres[7:5] <= 3'd0;
			wr_cr <= 1'b1;
		end
	Stark_pkg::OP_ADD:
		begin
			res = a + b;
			tCrres(ex_ir,res,CRdx,crres,wr_cr);
			wr_rf <= 1'b1;
		end
	Stark_pkg::OP_SUBF:
		begin
			res = b - a;
			tCrres(ex_ir,res,CRdx,crres,wr_cr);
			wr_rf <= 1'b1;
		end
	Stark_pkg::OP_AND:
		begin
			res = a & b;
			tCrres(ex_ir,res,CRdx,crres,wr_cr);
			wr_rf <= 1'b1;
		end
	Stark_pkg::OP_OR:
		begin
			res = a | b;
			tCrres(ex_ir,res,CRdx,crres,wr_cr);
			wr_rf <= 1'b1;
		end
	Stark_pkg::OP_XOR:
		begin
			res = a ^ b;
			tCrres(ex_ir,res,CRdx,crres,wr_cr);
			wr_rf <= 1'b1;
		end
	Stark_pkg::OP_MUL:
		begin
			if (ex_ir[31])
				res = produ;		// MULA
			else
				case(ex_ir.alu.op4)
				4'd0:	res = produ;	// MULA
				4'd1:	res = prod;	// MUL
				default:	res = produ;
				endcase
			tCrres(ex_ir,res,CRdx,crres,wr_cr);
			wr_rf <= 1'b1;
		end
	Stark_pkg::OP_SHIFT:
		begin
			case(ex_ir.sh.op2)
			2'd0:
				begin
					if (ex_ir[31] && ex_ir.sh.op2==2'd3) begin
//						res1 = a >> ex_ir[21:17];
					end
					else
						case(ex_ir.sh.op3)
						3'd0:	begin res = a << b[4:0]; wr_rf <= 1'b1; end
						3'd1:	begin res = a >> b[4:0]; wr_rf <= 1'b1; end
						3'd2: begin res = {{32{a[31]}},a[31:0]} >> b[4:0]; wr_rf <= 1'b1; end
						default:	;
						endcase
				end
			2'd2:
				begin
				end
			default:	;
			endcase
			tCrres(ex_ir,res,CRdx,crres,wr_cr);
		end
	Stark_pkg::OP_LOAD:
		begin
		  if (marx[15:14]==2'b11)
  			res = douta;
			else
		    res = ldres[31:0];
			tCrres(ex_ir,res,CRdx,crres,wr_cr);
			wr_rf <= 1'b1;
		end
	endcase
	if (~mf_v) begin
		wr_cr <= 1'b0;
		wr_rf <= 1'b0;
	end
end
endcase
end

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Writeback
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
always_ff @(posedge clk)
begin
	if (wr_rf)
		regfile[Rdx] <= res;
end

always_ff @(posedge clk)
	if (wr_cr)
		cr[CRdx] <= crres;

always_ff @(posedge clk)
	if (wr_br)
		br[BRd] <= brres;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Support tasks
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

task tGoto;
input state_e nst;
begin
	state <= nst;
end
endtask

task tCrres;
input instruction_t ex_ir;
input [31:0] res;
output [2:0] CRdx;
output [7:0] crres;
output wr_cr;
begin
	CRdx <= 3'd0;
	wr_cr <= ex_ir[16];
	crres[0] <= res==32'd0;
	crres[1] <= 1'b1;
	crres[2] <= ~|res;
	crres[3] <= $signed(res) < $signed(32'd0);
	crres[4] <= $signed(res) <= $signed(32'd0);
	crres[7:5] <= 3'd0;
end
endtask

endmodule
