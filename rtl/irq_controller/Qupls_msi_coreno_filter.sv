module Qupls_msi_coreno_filter(ack,ipl,sel);
parameter NCORES = 8;
input [NCORES-1:1] ack;
input [5:0] ipl [NCORES-1:1];
output reg [NCORES-1:0] sel;

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
