import const_pkg::*;
import Qupls3_pkg::*;

// Figures out where constants begin on the cache line based on the sequence
// of instructions beginning with the first on the cache line. A value of
// zero means there were no constants on the cache line. Constants are placed
// only in the last half of a cache line. Since the top bit of the constant
// index is always '1' it is not stored in an instruction. It is added here if
// a constant is found.

module min_constant_decoder(cline, min);
input Qupls3_pkg::instruction_t [15:0] cline;	// cache line in terms of instructions
output reg [3:0] min;							// minimum constant offset in 32-bit words

integer n1;
reg first;

always_comb
begin
	first = TRUE;
	min = 4'd0;
	for (n1 = 0; n1 < 16; n1 = n1 + 1)
		if (fnHasExConst(cline[n1])) begin	// does instruction have an extendable constant?
		if (cline[n1][31]!=1'b0) begin			// and is the constant extended on the cache line?
		if (cline[n1][30:29]!=2'b00) begin	// and it is not a register spec
		if (first) begin										// and have we found the first constant?
			min = fnConstPos(cline[n1]);
			first = FALSE;
			if (fnIsStimm(cline[n1]))
				if (cline[n1][8:6] < min[2:0])
					min = {1'b1,cline[n1][8:6]};
		end end end end
		else if (fnIsStimm(cline[n1])) begin
			if (first) begin
				min = fnConstPos(cline[n1]) >> 4'd4;
				first = FALSE;
			end
		end
end

endmodule
