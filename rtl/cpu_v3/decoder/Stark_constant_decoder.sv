import const_pkg::*;
import Stark_pkg::*;

// Decode the constant from the cache line given the position. Currently only
// 32-bit constants are supported.

module Stark_constant_decoder(pos,sz,cline,cnst);
input [3:0] pos;
input [1:0] sz;
input [511:0] cline;
output reg [63:0] cnst;

reg [63:0] cnst1;

always_comb
begin
	case(sz)
	2'd0:
		begin
			cnst1 = cline >> {pos,5'b0};
			cnst = {{32{cnst1[31]}},cnst1[31:0]};
		end
	2'd1: cnst = cline >> {pos,5'b0};
	default:	cnst = {{32{cnst1[31]}},cnst1[31:0]};
	endcase
end

endmodule
