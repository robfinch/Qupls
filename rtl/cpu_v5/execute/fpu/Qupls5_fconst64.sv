module Qupls5_fconst(a, o);
input [6:0] a;
output FP64 o;

always_comb
case(a)
7'd0:	o = 64'd0;
7'd1:	o = $realtobits(1.0);
7'd2:	o = $realtobits(2.0);

endcase

endmodule
