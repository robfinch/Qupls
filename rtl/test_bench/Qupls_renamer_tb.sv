`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2014-2024  Robert Finch, Stratford
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// Qupls_renamer_tb.v
//  - Test Bench for register name supplier
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
import cpu_types_pkg::*;
import QuplsPkg::*;

module Qupls_renamer_tb();

reg clk;
reg rst;
reg [7:0] state;
reg [7:0] freestate;
reg [7:0] value;
reg [7:0] count;

reg restore;
reg [PREGS-1:0] restore_list;
pregno_t [3:0] tags2free;
reg [3:0] freevals;
reg alloc0;
reg alloc1;
reg alloc2;
reg alloc3;
pregno_t wo0;
pregno_t wo1;
pregno_t wo2;
pregno_t wo3;
wire wv0;
wire wv1;
wire wv2;
wire wv3;
wire stall;
wire rst_busy;

initial begin
	#1 clk <= 1'b0;
	#5 rst <= 1'b1;
	#100 rst <= 1'b0;
end

always #2.5 clk <= ~clk;

Qupls_reg_renamer4 uren1
(
	.rst(rst),
	.clk(clk),
	.en(!stall),
	.restore(restore),
	.restore_list(restore_list),
	.tags2free(tags2free),
	.freevals(freevals),
	.alloc0(alloc0),
	.alloc1(alloc1),
	.alloc2(alloc2),
	.alloc3(alloc3),
	.wo0(wo0),
	.wo1(wo1),
	.wo2(wo2),
	.wo3(wo3),
	.wv0(wv0),
	.wv1(wv1),
	.wv2(wv2),
	.wv3(wv3),
	.avail(),
	.stall(stall),
	.rst_busy(rst_busy)
);

always @(posedge clk)
if (rst) begin
	state <= 8'h00;
	freestate <= 8'd0;
	alloc0 <= 1'b0;
	alloc1 <= 1'b0;
	alloc2 <= 1'b0;
	alloc3 <= 1'b0;
	restore <= 1'b0;
	restore_list <= {PREGS{1'b0}};
	freevals <= 4'h0;
	tags2free[0] <= 9'd0;
	tags2free[1] <= 9'd0;
	tags2free[2] <= 9'd0;
	tags2free[3] <= 9'd0;
	value <= $urandom(0);
	count <= 8'd0;
end
else begin
// Just pulse the alloc signals.
alloc0 <= 1'b0;
alloc1 <= 1'b0;
alloc2 <= 1'b0;
alloc3 <= 1'b0;
case(state)
8'h00:
		if (!rst_busy)
			state <= state + 1;
8'h01:
		state <= state + 1;
8'h02:
	begin
		alloc0 <= 1'b1;
		state <= state + 1;
	end
8'd3:
	begin
		alloc0 <= 1'b1;
		alloc1 <= 1'b1;
		alloc2 <= 1'b1;
		alloc3 <= 1'b1;
		state <= state + 1;
	end
8'd4:
	begin
		// Try and empty out the fifo to see what happens.
		if (count < 25) begin
			alloc0 <= 1'b1;
			count <= count + 1;
		end
		else
			state <= state + 1;
	end
8'd5:
	if (!stall) begin
		{alloc3,alloc2,alloc1,alloc0} <= $urandom();
	end
endcase

case(freestate)
8'd0:
	if (state > 8'd4) begin
		tags2free[0] <= wo0;
		tags2free[1] <= wo1;
		tags2free[2] <= wo2;
		tags2free[3] <= wo3;
		freevals <= 4'hF;
	end
endcase

end

endmodule
