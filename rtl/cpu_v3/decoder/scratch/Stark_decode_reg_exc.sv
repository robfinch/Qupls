import const_pkg::*;
import Stark_pkg::*;

module Stark_decode_reg_exc(om, rg, exc);
input Stark_pkg::operating_mode_t om;
input [6:0] rg;
output reg exc;

always_comb
begin
	exc = FALSE;
	if (rg== 7'd45 && && om < OM_SUPERVISOR)
		exc = TRUE;
	if (rg >= 7'd50 && rg <= 7'd55 && om != OM_SECURE)
		exc = TRUE;
	if (rg >= 7'd64 && rg <= 7'd95 && om != OM_USER)
		exc = TRUE;
end

endmodule
