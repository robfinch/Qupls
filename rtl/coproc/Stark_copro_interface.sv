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
// Address
//	0xBA00	processor control
//	0xBB00	request map of architectural to physical register
//	0xBC00	read/write physical register
//	0xBC10 	physical register value, bits 0 to 31
//	0xBC14	physical register value, bits 32 to 63
//	0xBD00	inject cache line command
//	0xBE00 to oxBE3F	cache line
//
// 1500 LUTs / 1110 FFs / 4 BRAMS / 6 DSP
// ============================================================================

import const_pkg::*;
import Stark_pkg::*;

module Stark_copro_interface(rst, clk, inject_cl, cline, pc,
	rd_reg, wr_reg, pRn_o, Rn_val, Rn_wack, prn, prnv, rfo,
	aRn_o, aRn_req_o, pRn_i, pRn_ack_i,
	ssm_o, stall_o, flush_o,
	rxd, txd);
input rst;
input clk;
output reg inject_cl;
output reg [511:0] cline;
output reg [31:0] pc;
input rxd;
output reg txd;
output rd_reg;
output wr_reg;
output pregno_t pRn_o;
output value_t Rn_val;
input Rn_wack;
input pregno_t [15:0] prn;
input [15:0] prnv;
input value_t [15:0] rfo;
output aregno_t aRn_o;
output aRn_req_o;
input pregno_t pRn_i;
input pRn_ack_i;
output reg ssm_o;
output reg stall_o;
output reg flush_o;


integer n1;

wire cyc;
wire wr;
wire [15:0] adr;
wire [31:0] dat;
reg [31:0] cpu_dati;
reg cpu_acki;

reg cs_ctrl;
reg ctrl_ack;
reg [31:0] ctrl_reg;

reg cs_uart;
wire uart_ack;
wire [31:0] uart_dato;
reg uart_rxd;
wire uart_txd;

reg cs_cline;
reg cline_ack;
reg [31:0] cline_dat;
reg cs_cline_inj;
reg cs_cline_injd;

reg cs_rw_reg;
wire rw_reg_ack;
value_t reg_val;
value_t rw_rego;

reg cs_map;
wire map_ack;
wire [31:0] map_out;

always_comb
	ssm_o = ctrl_reg[0];
always_comb
	stall_o = ctrl_reg[1];
always_comb
	flush_o = ctrl_reg[2];
	
always_comb
	cs_uart = adr[15:8]==8'hBF;
always_comb
	uart_rxd = rxd;
always_comb
	txd = uart_txd;

uart6551 uuart1
(
	.rst_i(rst),
	.clk_i(clk),
	.cs_i(cs_uart),
	.irq_o(),
	.cyc_i(cyc),
	.stb_i(cyc),
	.ack_o(uart_ack),
	.we_i(wr),
	.sel_i(4'hF),
	.adr_i(adr[3:2]),
	.dat_i(dat),
	.dat_o(uart_dato),
	.cts_ni(1'b0),
	.rts_no(),
	.dsr_ni(1'b0),
	.dcd_ni(1'b0),
	.dtr_no(),
	.ri_ni(1'b1),
	.rxd_i(uart_rxd),
	.txd_o(uart_txd),
	.data_present(),
	.rxDRQ_o(),
	.txDRQ_o(),
	.xclk_i(1'b0),
	.RxC_i()
);

always_comb
	cs_ctrl = adr[15:8]==8'hBA;

always_ff @(posedge clk)
if (rst) begin
	ctrl_reg <= 32'h0;
	ctrl_ack <= 1'b0;
end
else begin
	ctrl_ack <= 1'b0;
	if (cs_ctrl & cyc) begin
		if (wr)
			ctrl_reg <= dat;
		ctrl_ack <= 1'b1;
	end
end

always_comb
	cs_cline = adr[15:8]==8'hBE;
always_comb
	cs_cline_inj = adr[15:8]==8'hBD;

// Inject a cache line:
//	Write PC value to 0xBE80
//  Write cache line to 0xBE00 to 0xBE3C
//	Write to 0xBD00 (triggers injection)

always_ff @(posedge clk)
begin
	cline_ack <= 1'b0;
	inject_cl <= 1'b0;
	cs_cline_injd <= cs_cline_inj & cyc;
	if (cs_cline & cyc) begin
		if (wr) begin
			if (adr[7])
				pc <= dat;
			else
				cline[adr[5:2]] <= dat;
		end
		cline_dat <= adr[7] ? pc : cline[adr[5:2]];
		cline_ack <= 1'b1;
	end
	// Pulse inject signal for only one clock
	else if (cs_cline_inj & cyc) begin
		if (~cs_cline_injd)
			inject_cl <= 1'b1;
		cline_ack <= 1'b1;
	end
end

always_comb
	cs_map = adr[15:8]==8'hBB;

Stark_copro_reg_map_req ucpmnaprg1
(
	.rst(rst),
	.clk(clk),
	.cs(cs_map),
	.cyc(cyc),
	.wr(wr),
	.adr(adr[7:0]),
	.din(dat),
	.dout(map_out),
	.ack(map_ack),
	.aRn(aRn_o),
	.aRn_req(aRn_req_o),
	.pRn(pRn_i),
	.pRn_ack(pRn_ack_i)
);

// Register read:
//	Write register number with bit 31=1 to 0xBC00
//  Read 0xBC00, check that bit 31 is a zero
//	Read 0xBC10,0xBC14 for the value
// Register write:
//	Write value of register to 0xBC10,0xBC14
//  Write register number with bit 31=0 to 0xBC00

always_comb
	cs_rw_reg = adr[15:8]==8'hBC;

Stark_copro_reg_rw ucprwreg1
(
	.rst(rst),
	.clk(clk),
	.cs(cs_rw_reg),
	.cyc(cyc),
	.wr(wr),
	.adr(adr[7:0]),
	.din(dat),
	.dout(rw_rego),
	.ack(rw_reg_ack),
	.rd_reg(rd_reg),
	.wr_reg(wr_reg),
	.pRn(pRn_o),
	.pRn_wack(pRn_wack),
	.prn(prn),
	.prnv(prnv),
	.rfo(rfo)
);

always_comb
	cpu_acki = uart_ack|cline_ack|rw_reg_ack|map_ack|ctrl_ack;

always_comb
begin
	casez({cs_uart,cs_cline,cs_rw_reg,cs_map,cs_ctrl})
	5'b1????:	cpu_dati <= uart_dato;
	5'b01???:	cpu_dati <= cline_dat;
	5'b001??:	cpu_dati <= rw_rego;
	5'b0001?:	cpu_dati <= map_out;
	5'b00001:	cpu_dati <= ctrl_reg;
	default:	cpu_dati <= 32'd0;
	endcase
end

Stark_coproc ucopro1
(
	.rst(rst),
	.clk(clk),
	.cyc(cyc),
	.wr(wr),
	.adr(adr),
	.din(cpu_dati),
	.dout(dat),
	.ack(cpu_acki)
);

endmodule
