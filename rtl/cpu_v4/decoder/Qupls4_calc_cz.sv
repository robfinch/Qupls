import Qupls4_pkg::*;

// 100 LUTs

module Qupls4_calc_cz(instr, pc_inc, nop);
input Qupls4_pkg::micro_op_t [3:0] instr;
output reg [5:0] pc_inc;
output reg [7:0] nop;

integer n1;
reg [5:0] isz [0:7];
reg [6:0] sz0 [0:7];
reg [6:0] sz1 [0:7];
reg [6:0] sz2 [0:7];

function [6:0] fnCnstSizeInBits;
input [1:0] cd;
	case(cd)
	2'd0:	fnCnstSizeInBits = 7'd16;
	2'd1:	fnCnstSizeInBits = 7'd32;
	2'd2:	fnCnstSizeInBits = 7'd48;
	2'd3:	fnCnstSizeInBits = 7'd64;
	endcase
endfunction

function [2:0] fnWordsNeeded;
input [6:0] sz0;
input [6:0] sz1;
input [6:0] sz2;
reg [7:0] totsz;
begin
// sum the constant sizes
//
		totsz = {2'd0,sz2} + {2'd0,sz1} + {2'd0,sz0};
		if (totsz == 8'd0)
			fnWordsNeeded = 4'd0;
		else if (totsz < 8'd49)
			fnWordsNeeded = 3'd1;
		else if (totsz < 8'd97)
			fnWordsNeeded = 3'd2;
		else if (totsz < 8'd145)
			fnWordsNeeded = 3'd3;
		else
			fnWordsNeeded = 3'd4;
end
endfunction

always_comb
begin
	for (n1 = 0; n1 < 8; n1 = n1 + 1) begin
		nop[n1] = 1'b0;
		sz0[n1] = 7'd0;
		sz1[n1] = 7'd0;
		sz2[n1] = 7'd0;
		isz[n1] = 6'd0;
	end

	for (n1 = 0; n1 < 4; n1 = n1 + 1) begin
		isz[n1] = Qupls4_pkg::fnConstSize(instr[n1]);
		if (Qupls4_pkg::fnHasConstRs1(instr[n1]))
			sz0[n1] = fnCnstSizeInBits(isz[n1][1:0]);
		if (Qupls4_pkg::fnHasConstRs2(instr[n1]))
			sz1[n1] = fnCnstSizeInBits(isz[n1][3:2]);
		if (Qupls4_pkg::fnHasConstRs3(instr[n1]))
			sz2[n1] = fnCnstSizeInBits(isz[n1][5:4]);
	end

	for (n1 = 0; n1 < 4; n1 = n1 + 1) begin
		if (fnWordsNeeded(sz0[n1],sz1[n1],sz2[n1]) > 3'd0) begin
			sz0[n1+1] = 8'd0;
			sz1[n1+1] = 8'd0;
			sz2[n1+1] = 8'd0;
			nop[n1+1] = 1'b1;
		end
		if (fnWordsNeeded(sz0[n1],sz1[n1],sz2[n1]) > 3'd1) begin
			sz0[n1+2] = 8'd0;
			sz1[n1+2] = 8'd0;
			sz2[n1+2] = 8'd0;
			nop[n1+2] = 1'b1;
		end
		if (fnWordsNeeded(sz0[n1],sz1[n1],sz2[n1]) > 3'd2) begin
			sz0[n1+3] = 8'd0;
			sz1[n1+3] = 8'd0;
			sz2[n1+3] = 8'd0;
			nop[n1+3] = 1'b1;
		end
		if (fnWordsNeeded(sz0[n1],sz1[n1],sz2[n1]) > 3'd3) begin
			sz0[n1+4] = 8'd0;
			sz1[n1+4] = 8'd0;
			sz2[n1+4] = 8'd0;
			nop[n1+4] = 1'b1;
		end
	end
		
	if (nop[4] & nop[5] & nop[6] & nop[7])
		pc_inc = 6'd48;
	else if (nop[4] & nop[5] & nop[6])
		pc_inc = 6'd42;
	else if (nop[4] & nop[5])
		pc_inc = 6'd36;
	else if (nop[4])
		pc_inc = 6'd30;
	else
		pc_inc = 6'd24;
end

endmodule
