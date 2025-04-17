import const_pkg::*;
import Qupls3_pkg::*;

module pipe_mux(rst, clk, en, mc_en, hwi, hwi_ins, mc_ins, cline_i, pc_i, cline_o, pr_o);
input rst;
input clk;
input en;
input mc_en;
input hwi;
input Qupls3_pkg::instruction_t hwi_ins;
input Qupls3_pkg::instruction_t [3:0] mc_ins;
input [511:0] cline_i;
input Qupls3_pkg::pc_address_t [4:0] pc_i;
output reg [511:0] cline_o;
output Qupls3_pkg::pipeline_reg_t [4:0] pr_o;

integer n1;

Qupls3_pkg::instruction_t [4:0] ins;

// Multiplex in for three sources: cache line, hardware interrupts and micro-code.

always_comb
begin	
	if (rst) begin
		ins[0] = NOP_INSN;
		ins[1] = NOP_INSN;
		ins[2] = NOP_INSN;
		ins[3] = NOP_INSN;
		ins[4] = NOP_INSN;
	end
	else if (hwi) begin
		ins[0] = hwi_ins;
		ins[1] = NOP_INSN;
		ins[2] = NOP_INSN;
		ins[3] = NOP_INSN;
		ins[4] = NOP_INSN;
	end
	else if (mc_en) begin
		case(n1)
		0:	ins[0] = mc_ins[0];
		1:	ins[1] = mc_ins[1];
		2:	ins[2] = mc_ins[2];
		3:	ins[3] = mc_ins[3];
		4:	ins[4] = NOP_INSN;
		endcase
	end
	else if (en) begin
		ins[0] = cline_i >> {pc_i[0][5:2],5'b0};
		ins[1] = cline_i >> {pc_i[1][5:2],5'b0};
		ins[2] = cline_i >> {pc_i[2][5:2],5'b0};
		ins[3] = cline_i >> {pc_i[3][5:2],5'b0};
		ins[4] = cline_i >> {pc_i[4][5:2],5'b0};
	end
	else begin
		ins[0] = NOP_INSN;
		ins[1] = NOP_INSN;
		ins[2] = NOP_INSN;
		ins[3] = NOP_INSN;
		ins[4] = NOP_INSN;
	end
end

// Propagate the cache line for decode.

always_ff @(posedge clk)
if (rst)
	cline_o <= {16{NOP_INSN}};
else begin
	if (en)
		cline_o <= cline_i;
end

// Set the pipeline register

always_ff @(posedge clk)
if (rst) begin
	for (n1 = 0; n1 < 5; n1 = n1 + 1)
		pr_o[n1] <= {$bits(Qupls3_pkg::pipeline_reg_t){1'b0}};
end
else begin	
	for (n1 = 0; n1 < 5; n1 = n1 + 1)
		if (en) begin
			pr_o[n1].v <= TRUE;
			pr_o[n1].pc <= pc_i[n1];
			pr_o[n1].db <= {$bits(Qupls3_pkg::decode_bus_t){1'b0}};
			pr_o[n1].ins <= ins[n1];
		end
end

endmodule
