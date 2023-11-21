module Qupls_ins_length(ins, len);
input instruction_t ins;
output reg [4:0] len;					// length in bytes

always_comb
	casez(ins.any.opcode)
	7'h2?:	len = 5'd5;			// Branches
	OP_LDX:	len = 5'd5;
	OP_STX:	len = 5'd5;
	OP_PFXA,OP_PFXB,OP_PFXC:
		case(ins.pfx.len)
		2'd0:	len = 5'd4;
		2'd1:	len = 5'd6;
		2'd2:	len = 5'd10;
		2'd3:	len = 5'd18;
		endcase
	default:	len = 5'd4;
	endcase

endmodule
