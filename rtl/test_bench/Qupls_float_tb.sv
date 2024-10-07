`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2014-2024  Robert Finch, Stratford
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// Qupls_float_tb.v
//  - Test Bench for tfloating point accelerator
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU Lesser General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or     
// (at your option) any later version.                                      
//                                                                          
// This source file is distributed in the hope that it will be useful,      
// but WITHOUT ANY WARRANTY; without even the implied warranty of           
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            
// GNU General Public License for more details.                             
//                                                                          
// You should have received a copy of the GNU General Public License        
// along with this program.  If not, see <http://www.gnu.org/licenses/>.    
//                                                                          
// ============================================================================
//
import const_pkg::*;

module Qupls_float_tb();
parameter PREC="S";
localparam WID=PREC=="Q" ? 128 : PREC=="D" ? 64 : PREC=="S" ? 32:16;

reg clk;
reg rst;
reg [7:0] state;
reg [7:0] retstate;
reg fix2flt;
reg [7:0] op;
reg [WID-1:0] a,b;
wire [WID-1:0] ao, bo;
wire [7:0] sr;
reg [WID-1:0] value;
reg start;

initial begin
	#1 clk <= 1'b0;
	#5 rst <= 1'b1;
	#100 rst <= 1'b0;
end

always #2.5 clk <= ~clk;

Qupls_float #(.PREC(PREC)) u1 (
	.rst(rst),
	.clk(clk),
	.start(start),
	.op(op),
	.a(a),
	.b(b),
	.ao(ao),
	.bo(bo),
	.sr(sr)
);


always @(posedge clk)
if (rst) begin
	state <= 8'h00;
	op <= 8'h00;
	a <= {WID{1'b0}};
	b <= {WID{1'b0}};
end
else begin
state <= state + 8'd1;
start <= FALSE;
case(state)
8'h00:	begin
			case(PREC)
			"S":	value <= 32'h00038;
			"D":	value <= 64'h0000A;
			"Q": 	value <= 128'h0000000000000000000000004D20000;	// MAXINT
			endcase
			fix2flt <= 1'b1;
			state <= 8'h80;
			retstate <= 8'h01;
		end
8'h02:  begin op <= 8'd17;	start <= TRUE; end	// SWAP
8'h05:	if (sr[7]) state <= state;
8'h06:	
	begin
			a <= ao;
			b <= bo;
			case (PREC)
			"S":	value <= 32'h00015;
			"D":	value <= 64'h000A;
			"Q":	value <= 128'h00000000000000000000000004D20000;	// MAXINT
			endcase
			fix2flt <= 1'b1;
			state <= 8'h80;
			retstate <= 8'h07;
		end
8'h07:
		begin
			a <= ao;
			b <= bo;
			case(PREC)
			"S":	value <= 32'hFFFFFFFF;
			"D":	value <= 64'h0000A;
			"Q": 	value <= 128'h0000000000000000000000004D20000;	// MAXINT
			endcase
			fix2flt <= 1'b1;
			state <= 8'h80;
			retstate <= 8'h08;
		end
8'h08:	start <= TRUE;
8'h0A:	if (sr[7]) state <= state; else begin a <= ao; b <= bo; end

8'h0B:  begin op <= 8'h03; start <= TRUE; end	// MUL
8'h0F:	if (sr[7]) state <= state; else begin a <= ao; b <= bo; end
8'h10:	begin op <= 8'h06; start <= TRUE; end	// FLT2FIX
8'h14:	if (sr[7]) state <= state; else begin a <= ao; b <= bo; end
8'h15:	begin op <= 8'h00; start <= TRUE; end
8'h17:	state <= state;
// This subroutine writes a value to FAC1.
8'h80:	a <= value;
8'h81:  if (fix2flt) state <= 8'h90; else state <= retstate;
8'h90:  begin op <= 8'h05; b <= bo; start <= TRUE; end	// FIX2FLT
8'h94:	
	begin
		if (sr[7])
			state <= state;
		else begin
			a <= ao;
			b <= bo;
			state <= retstate;
		end
	end
endcase
end

endmodule
