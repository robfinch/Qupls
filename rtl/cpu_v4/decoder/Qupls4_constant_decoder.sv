import const_pkg::*;
import Qupls4_pkg::*;

// Decode the constant from the cache line given the position.
// 225 LUTs

module Qupls4_constant_decoder(pos,sz,cline,cnst);
input [3:0] pos;
input [1:0] sz;
input [511:0] cline;
output reg [63:0] cnst;

reg [63:0] cnst1;

always_comb
begin
	case(sz)
	2'd0,2'd1:
		begin
			cnst1 = cline >> {1'b1,pos,4'b0};
			cnst = {{48{cnst1[15]}},cnst1[15:0]};
		end
	2'd2:
		begin
			cnst1 = cline >> {1'b1,pos,4'b0};
			cnst = {{32{cnst1[31]}},cnst1[31:0]};
		end
	2'd3: cnst = cline >> {1'b1,pos,4'b0};
	endcase
end

endmodule
