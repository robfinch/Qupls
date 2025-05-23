`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2017-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	- Stark programmable interval timer
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
// ============================================================================
//
//	Reg	Description
//	000	current count   (read only)
//	008	max count	    (read-write)
//  010  on time			(read-write)
//	018	control
//		byte 0 for counter 0, byte 1 for counter 1, byte 2 for counter 2
//		bit in byte
//		0 = 1 = load, automatically clears
//	    1 = 1 = enable counting, 0 = disable counting
//		2 = 1 = auto-reload on terminal count, 0 = no reload
//		3 = 1 = use external clock, 0 = internal clk_i
//      4 = 1 = use gate to enable count, 0 = ignore gate
//	020	current count 1
//	028  max count 1
//	030  on time 1
//	040	current count 2
//	048	max count 2
//	050	on time 2
//	060	current count 3
//	068	max count 3
//	070	on time 3
//	...
//	800	underflow status
//  808 synchronization register
//  810 interrupt enable
//	818 temporary register
//	820 output status
//	828 internal gate
//	830 internal gate on
//	838 internal gate off
//
//	- all counter controls can be written at the same time with a
//    single instruction allowing synchronization of the counters.
//
// Timer block supports up to 64 64-bit timers
//
// 8k556 LUTs 10k730 FF's (32x64 bit timers)
// 8430 LUTs 16472 FF's (64x48 bit timers)
// 1255 LUTs / 2120 FFs (8x48 bit timers)
// ============================================================================
//
import fta_bus_pkg::*;
import msi_pkg::*;

module Stark_pit(rst_i, clk_i, cs_config_i, sreq, sresp,
	clk0, gate0, out0, clk1, gate1, out1, clk2, gate2, out2, clk3, gate3, out3
);
parameter NTIMER=8;
parameter BITS=48;
input rst_i;
input clk_i;
input cs_config_i;
input fta_cmd_request64_t sreq;
output fta_cmd_response64_t sresp;
input clk0;
input gate0;
output out0;
input clk1;
input gate1;
output out1;
input clk2;
input gate2;
output out2;
input clk3;
input gate3;
output out3;

parameter PIT_ADDR = 32'hFEE40001;
parameter PIT_ADDR_MASK = 32'hFFFF0000;
// 1000_0000_0000_1000_0000_0000_0000_0000
// IRQ registers: 0x80080040 and 0x80080048
parameter CFG_BUS = 8'd0;
parameter CFG_DEVICE = 5'd4;
parameter CFG_FUNC = 3'd0;
parameter CFG_VENDOR_ID	=	16'h0;
parameter CFG_DEVICE_ID	=	16'h0;
parameter CFG_SUBSYSTEM_VENDOR_ID	= 16'h0;
parameter CFG_SUBSYSTEM_ID = 16'h0;
parameter CFG_ROM_ADDR = 32'hFFFFFFF0;

parameter CFG_REVISION_ID = 8'd0;
parameter CFG_PROGIF = 8'd1;
parameter CFG_SUBCLASS = 8'h80;					// 80 = Other
parameter CFG_CLASS = 8'h03;						// 03 = display controller
parameter CFG_CACHE_LINE_SIZE = 8'd8;		// 32-bit units
parameter CFG_MIN_GRANT = 8'h00;
parameter CFG_MAX_LATENCY = 8'h00;
parameter CFG_IRQ_LINE = 8'd29;

localparam CFG_HEADER_TYPE = 8'h00;			// 00 = a general device

parameter MSIX = 1'b0;

integer n,n1;
wire irq;
wire cs_io;
fta_cmd_response64_t cfg_resp;
fta_cmd_request64_t reqd;
reg erc;
reg cs_config;
wire respack;
reg [63:0] dat_o;
reg [5:0] irq_coreno;
reg [2:0] irq_channel;
reg [5:0] irq_pri;
reg [1:0] irq_swstk;
reg [1:0] irq_om;
reg [11:0] irq_vecno;
reg [15:0] irq_data;

reg [BITS-1:0] maxcounth [0:NTIMER-1];
reg [BITS-1:0] maxcount [0:NTIMER-1];
reg [BITS-1:0] count [0:NTIMER-1];
reg [BITS-1:0] onth [0:NTIMER-1];
reg [BITS-1:0] ont [0:NTIMER-1];
wire [NTIMER-1:0] gate;
reg [NTIMER-1:0] igate;
wire [NTIMER-1:0] pulse;
reg ldh [0:NTIMER-1];
reg ceh [0:NTIMER-1];
reg arh [0:NTIMER-1];
reg geh [0:NTIMER-1];
reg xch [0:NTIMER-1];
reg ieh [0:NTIMER-1];
reg ld [0:NTIMER-1];
reg ce [0:NTIMER-1];
reg ar [0:NTIMER-1];
reg ge [0:NTIMER-1];
reg xc [0:NTIMER-1];
reg [NTIMER-1:0] ie;
reg [NTIMER-1:0] out;
reg [NTIMER-1:0] underflow;
reg [NTIMER-1:0] tmp;
reg [NTIMER-1:0] irqf;

wire cs_qit = reqd.cyc && cs_io;

always_ff @(posedge clk)
	reqd <= sreq;

always_ff @(posedge clk)
	cs_config <= cs_config_i;

always_ff @(posedge clk_i)
	erc <= sreq.cti==fta_bus_pkg::ERC;

vtdl #(.WID(1), .DEP(16)) urdyd2 (.clk(clk_i), .ce(1'b1), .a(4'd0), .d((cs_qit)&(erc|~reqd.we)), .q(respack));
always_ff @(posedge clk)
if (rst)
	sresp <= {$bits(fta_cmd_response64_t){1'b0}};
else begin
	if (cfg_resp.ack)
		sresp <= cfg_resp;
	else if (respack) begin
		sresp.ack <= respack ? reqd.cyc : 1'b0;
		sresp.tid <= respack ? reqd.tid : 13'd0;
		sresp.next <= 1'b0;
		sresp.stall <= 1'b0;
		sresp.err <= fta_bus_pkg::OKAY;
		sresp.rty <= 1'b0;
		sresp.pri <= 4'd5;
		sresp.adr <= respack ? reqd.adr : 40'd0;
		sresp.dat <= respack ? dat_o : 64'd0;
	end
end

ddbb64_config #(
	.CFG_BUS(CFG_BUS),
	.CFG_DEVICE(CFG_DEVICE),
	.CFG_FUNC(CFG_FUNC),
	.CFG_VENDOR_ID(CFG_VENDOR_ID),
	.CFG_DEVICE_ID(CFG_DEVICE_ID),
	.CFG_BAR0(PIT_ADDR),
	.CFG_BAR0_MASK(PIT_ADDR_MASK),
	.CFG_SUBSYSTEM_VENDOR_ID(CFG_SUBSYSTEM_VENDOR_ID),
	.CFG_SUBSYSTEM_ID(CFG_SUBSYSTEM_ID),
	.CFG_ROM_ADDR(CFG_ROM_ADDR),
	.CFG_REVISION_ID(CFG_REVISION_ID),
	.CFG_PROGIF(CFG_PROGIF),
	.CFG_SUBCLASS(CFG_SUBCLASS),
	.CFG_CLASS(CFG_CLASS),
	.CFG_CACHE_LINE_SIZE(CFG_CACHE_LINE_SIZE),
	.CFG_MIN_GRANT(CFG_MIN_GRANT),
	.CFG_MAX_LATENCY(CFG_MAX_LATENCY),
	.CFG_IRQ_LINE(CFG_IRQ_LINE)
)
ucfg1
(
	.rst_i(rst),
	.clk_i(clk),
	.irq_i({3'd0,irq}),
	.cs_i(cs_config), 
	.req_i(reqd),
	.resp_o(cfg_resp),
	.cs_bar0_o(cs_io),
	.cs_bar1_o(),
	.cs_bar2_o()
);

assign out0 = out[0];
assign out1 = out[1];
assign out2 = out[2];
assign out3 = out[3];
assign gate[0] = gate0;
assign gate[1] = gate1;
assign gate[2] = gate2;
assign gate[3] = gate3;

edge_det ued0 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(clk0), .pe(pulse[0]), .ne(), .ee());
edge_det ued1 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(clk1), .pe(pulse[1]), .ne(), .ee());
edge_det ued2 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(clk2), .pe(pulse[2]), .ne(), .ee());
edge_det ued3 (.rst(rst_i), .clk(clk_i), .ce(1'b1), .i(clk3), .pe(pulse[3]), .ne(), .ee());

genvar g;
generate
	for (g = 4; g < NTIMER; g = g + 1) begin
assign gate[g] = 1'b1;
assign pulse[g] = 1'b0;
	end
endgenerate

initial begin
	for (n = 0; n < NTIMER; n = n + 1) begin
		maxcount[n] <= 'd0;
		maxcounth[n] <= 'd0;
		count[n] <= 'd0;
		ont[n] <= 'd0;
		onth[n] <= 'd0;
		igate[n] <= 1'b0;
		ld[n] <= 1'b0;
		ce[n] <= 1'b0;
		ar[n] <= 1'b0;
		ge[n] <= 1'b0;
		xc[n] <= 1'b0;
		ldh[n] <= 1'b0;
		ceh[n] <= 1'b0;
		arh[n] <= 1'b0;
		geh[n] <= 1'b0;
		xch[n] <= 1'b0;
		out[n] <= 1'b0;
		irqf[n] <= 1'b0;
	end
end

always_ff @(posedge clk_i)
if (rst_i) begin
	ie <= 'd0;
	for (n1 = 0; n1 < NTIMER; n1 = n1 + 1) begin
		maxcount[n1] <= 'd0;
		maxcounth[n1] <= 'd0;
		count[n1] <= 'd0;
		ont[n1] <= 'd0;
		onth[n1] <= 'd0;
		igate[n1] <= 1'b0;
		ld[n1] <= 1'b0;
		ce[n1] <= 1'b0;
		ar[n1] <= 1'b1;
		ge[n1] <= 1'b0;
		ldh[n1] <= 1'b0;
		ceh[n1] <= 1'b0;
		arh[n1] <= 1'b1;
		geh[n1] <= 1'b0;
		out[n1] <= 1'b0;
		irqf[n1] <= 1'b0;
	end	
end
else begin
	for (n1 = 0; n1 < NTIMER; n1 = n1 + 1) begin
		ld[n1] <= 1'b0;
		if (cs_qit && reqd.we && reqd.adr[11:5]==n1)
		case(reqd.adr[4:3])
		2'd1:
			begin
				if (|reqd.sel[3:0])	
					maxcounth[n1][31:0] <= reqd.dat[31:0];
				if (|reqd.sel[7:4])	
					maxcounth[n1][47:32] <= reqd.dat[47:32];
			end
		2'd2:
			begin
				if (|reqd.sel[3:0])
					onth[n1][31:0] <= reqd.dat[31:0];
				if (|reqd.sel[7:4])
					onth[n1][47:32] <= reqd.dat[47:32];
			end
		2'd3:	begin
						ldh[n1] <= reqd.dat[0];
						ceh[n1] <= reqd.dat[1];
						arh[n1] <= reqd.dat[2];
						xch[n1] <= reqd.dat[3];
						geh[n1] <= reqd.dat[4];
						if (reqd.dat[7]) begin
							ld[n1] <= reqd.dat[0];
							ce[n1] <= reqd.dat[1];
							ar[n1] <= reqd.dat[2];
							xc[n1] <= reqd.dat[3];
							ge[n1] <= reqd.dat[4];
							maxcount[n1] <= maxcounth[n1];
							ont[n1] <= onth[n1];
						end
					end
		default:	;
		endcase
		// Writing the underflow register clears the underflows and disable further
		// interrupts where bits are set in the incoming data.
		// Interrupt processing should read the underflow register to determine
		// which timers underflowed, then write back the value to the underflow
		// register.
		if (cs_qit && reqd.we && reqd.adr[11:3]==9'h100) begin
			if (reqd.dat[n1]) begin
				ie[n1] <= 1'b0;
				underflow[n1] <= 1'b0;
				irqf[n1] <= 1'b0;
			end
		end
		// The timer synchronization register indicates which timer's registers to
		// update. All timers may have their registers updated synchronously.
		if (cs_qit && reqd.we && reqd.adr[11:3]==9'h101)
			if (reqd.dat[n1]) begin
				ld[n1] <= ldh[n1];
				ce[n1] <= ceh[n1];
				ar[n1] <= arh[n1];
				xc[n1] <= xch[n1];
				ge[n1] <= geh[n1];
				ldh[n1] <= 1'b0;
				maxcount[n1] <= maxcounth[n1];
				ont[n1] <= onth[n1];
			end
		if (cs_qit & reqd.we)
			case(reqd.adr[11:3])
			9'h102:	ie <= reqd.dat;
			9'h103:	tmp <= reqd.dat;
			9'h105:	igate <= reqd.dat;
			9'h106:	igate <= igate | reqd.dat;
			9'h107:	igate <= igate & ~reqd.dat;
			default:	;
			endcase
		if (cs_config)
			dat_o <= cfg_resp.dat;
		else if (cs_qit) begin
			case(reqd.adr[11:3])
			9'h100:	dat_o <= underflow;
			9'h101:	dat_o <= 'd0;
			9'h102:	dat_o <= ie;
			9'h103:	dat_o <= tmp;
			9'h104:	dat_o <= out;
			9'h105:	dat_o <= igate;
			9'h106:	dat_o <= 'd0;
			9'h107:	dat_o <= 'd0;
			default:
				if (reqd.adr[11:5]==n1)
					case(reqd.adr[4:3])
					2'd0:	dat_o <= count[n1];
					2'd1:	dat_o <= maxcount[n1];
					2'd2:	dat_o <= ont[n1];
					2'd3:	dat_o <= {56'd0,3'b0,ge[n1],xc[n1],ar[n1],ce[n1],1'b0};
					endcase
				else
					dat_o <= 'd0;
			endcase
		end
		else
			dat_o <= 'd0;
		
		if (ld[n1]) begin
			count[n1] <= maxcount[n1];
		end
		else if ((xc[n1] ? pulse[n1] & ce[n1] : ce[n1]) & (ge[n1] ? igate[n1] & gate[n1] : 1'b1)) begin
			count[n1] <= count[n1] - 2'd1;
			if (count[n1]==ont[n1]) begin
				out[n1] <= 1'b1;
			end
			else if (count[n1]=='d0) begin
				underflow[n1] <= 1'b1;
				if (ie[n1])
					irqf[n1] <= 1'b1;
				out[n1] <= 1'b0;
				if (ar[n1]) begin
					count[n1] <= maxcount[n1];
				end
				else begin
					ce[n1] <= 1'b0;
				end
			end
		end
	end
end

assign irq = |irqf;

endmodule
