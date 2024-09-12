module Qupls_decode_block_header(header, offs);
input [63:0] header;
output reg [5:0] offs [0:55];

integer n, m;

always_comb
begin
	m = 0;
	for (n = 0; n < 56; n = n + 1) begin
		offs[n] = 0;
		if (header[n]==1'b1) begin
			offs[m] = n;
			m = m + 1;
		end
	end
end

endmodule
