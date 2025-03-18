// There could be multiple cores that are able to process the interrupt. The
// core running at the lowest priority level is selected.

// 7 core = 50 LUTs
// 15 cores = 129 LUTs
// 31 cores = 330 LUTs
// 63 cores = 1444 LUTs

module Qupls_msi_coreno_filter(ack,ipl,sel);
parameter NCORES = 64;
input [NCORES-1:1] ack;				// From the CPU, indicating it could process the IRQ
input [5:0] ipl [NCORES-1:1];	// From the CPU, its current interrupt level
output reg [NCORES-1:0] sel;	// To the CPU, select for IRQ processing.

integer jj;
reg [5:0] ipl_min;

always_comb
begin
	sel = 64'd0;
	ipl_min = 6'd63;
	for (jj = 1; jj < NCORES; jj = jj + 1)
		if (ack[jj]) begin
			if (ipl[jj] < ipl_min) begin
				ipl_min = ipl[jj];
				sel = 64'd1 << jj;
			end
		end
end

endmodule
