import const_pkg::*;
import Qupls3_pkg::*;

// Decode the constant from the cache line given the position. Currently only
// 32-bit constants are supported.

module constant_decoder(pos,sz,cline,cnst);
input [3:0] pos;
input [1:0] sz;
input [511:0] cline;
output reg [31:0] cnst;

always_comb
begin
	cnst = cline >> {pos,5'b0};
end

endmodule
