import cpu_types_pkg::*;

module Stark_validate_Rn(prn, prnv, rfo, pRn, val, val_tag, valid_i, valid_o);
input pregno_t [15:0] prn;
input [15:0] prnv;
input value_t [15:0] rfo;
input pregno_t pRn;
output value_t val;
output reg val_tag;
input valid_i;
output reg valid_o;

integer nn;
always_comb
begin
	valid_o = valid_i;
	if (pRn==8'd0) begin
		val = value_zero;
		val_tag = 1'b0;
		valid_o = 1'b1;
	end
	else
	for (nn = 0; nn < 16; nn = nn + 1) begin
		if (pRn==prn[nn] && prnv[nn] && !valid_i) begin
			val = rfo[nn];
			val_tag = rfo_tag[nn];
			valid_o = 1'b1;
		end
	end
end
endtask

endmodule