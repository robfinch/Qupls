import Stark_pkg::*;

module Stark_decode_mc_count(ir, count);
input Stark_pkg::instruction_t ir;

always_comb
	case(ir.any.opcode)
	OP_MUL:	count <= 8'd5;
	OP_DIV: count <= 
always_ff @(posedge clk)
if (rst) begin
	cnt <= 'd0;
	sincos_done <= 1'b0;
	fma_done <= 1'b0;
	scale_done <= 1'b0;
	f2i_done <= 'd0;
	i2f_done <= 'd0;
	sqrt_done <= 'd0;
	fres_done <= 'd0;
	trunc_done <= 'd0;
end
else begin
	if (cd_args)
		cnt <= 'd0;
	else
		cnt <= cnt + 2'd1;
	sincos_done <= cnt>=12'd64;
	fma_done <= cnt>=12'h8;
	scale_done <= cnt>=12'h3;
	f2i_done <= cnt>=12'h2;
	i2f_done <= cnt>=12'h2;
	sqrt_done <= cnt >= 12'd121;
	fres_done <= cnt >= 12'h002;
	trunc_done <= cnt >= 12'h001;
end


endmodule
