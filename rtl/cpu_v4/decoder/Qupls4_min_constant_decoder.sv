// 380 LUTs

import const_pkg::*;
import Qupls4_pkg::*;

// Figures out where constants begin on the cache line based on the sequence
// of instructions beginning with the first on the cache line. A value of
// 63 means there were no constants on the cache line. Constants are placed
// starting at the of the cache line and working backwards.

module Qupls4_min_constant_decoder(cline, nops);
input Qupls4_pkg::instruction_t [9:0] cline;	// cache line in terms of instructions
output reg [9:0] nops;

integer n1;
reg [2:0] ms;
reg [5:0] min;
reg [5:0] min1;
reg [1:0] sz;

always_comb
begin
	min = 6'd63;		// last byte of line
	nops = 10'h000;
	for (n1 = 0; n1 < 10; n1 = n1 + 1)
	begin
		ms = fnDecMs(cline[n1]);
		if (Qupls4_pkg::fnHasConstRs1(cline[n1])) begin	// does instruction have an extendable constant?
			if (ms[0]) begin
				min1 = {1'b1,cline[n1].alu.Rs1[3:0],1'b0};
				if (min1 < min)
					min = min1;
			end
		end
		if (Qupls4_pkg::fnHasConstRs2(cline[n1])) begin	// does instruction have an extendable constant?
			if (ms[1]) begin
				min1 = {1'b1,cline[n1].alu.Rs2[3:0],1'b0};
				if (min1 < min)
					min = min1;
			end
		end
		if (Qupls4_pkg::fnHasConstRs3(cline[n1])) begin	// does instruction have an extendable constant?
			if (ms[2]) begin
				min1 = {1'b1,cline[n1].alu.Rs3[3:0],1'b0};
				if (min1 < min)
					min = min1;
			end
		end
		// Store immediate may have a second constant
		if (Qupls4_pkg::fnIsStimm(cline[n1])) begin
			min1 = {1'b1,cline[n1].alu.Rd[3:0],1'b0};
			if (min1 < min)
				min = min1;
		end
	end
	// Once the minimum constant position is determined, all instructions after
	// that point are marked as NOPs.
	for (n1 = 0; n1 < 10; n1 = n1 + 1)
		nops[n1] = ((n1*6)+5) >= min;
end

endmodule
