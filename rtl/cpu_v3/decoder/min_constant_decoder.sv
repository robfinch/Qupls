import const_pkg::*;
import Stark_pkg::*;

// Figures out where constants begin on the cache line based on the sequence
// of instructions beginning with the first on the cache line. A value of
// zero means there were no constants on the cache line. Constants are placed
// starting at the of the cache line and working backwards.

module min_constant_decoder(cline, min, nops);
input Stark_pkg::instruction_t [15:0] cline;	// cache line in terms of instructions
output reg [15:0] nops;

integer n1;
reg [3:0] min;

always_comb
begin
	first = TRUE;
	min = 4'd0;
	nops = 16'h0000;
	for (n1 = 0; n1 < 16; n1 = n1 + 1)
		if (!nops[n1]) begin								// if not a NOP already
		if (fnHasExConst(cline[n1])) begin	// does instruction have an extendable constant?
		if (cline[n1][31]!=1'b0) begin			// and is the constant extended on the cache line?
		if (cline[n1][30:29]!=2'b00) begin	// and it is not a register spec
			min = fnConstPos(cline[n1]);
			nops[min] = 1'b1;
		end end end
		if (fnIsStimm(cline[n1])) begin
			min = fnConstPos(cline[n1]) >> 4'd4;
			nops[min] = 1'b1;
		end
		end
end

endmodule
