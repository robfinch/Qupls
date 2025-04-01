import const_pkg::*;
import Qupls3_pkg::*;

module pipe_aln(rst, clk, en, mc_en, hwi, hwi_ins, mc_ins, cline_i, pc_i, cline_o, pr_o);
input rst;
input clk;
input en;
input mc_en;
input hwi;
input instruction_t hwi_ins;
input instruction_t [3:0] mc_ins;
input [511:0] cline_i;
input pc_address_t [4:0] pc_i;
output [511:0] cline_o;
output pipeline_reg_t pr_o;

integer n1,n2;

instruction_t [4:0] ins;

always_comb
begin	
	for (n1 = 0; n1 < 5; n1 = n1 + 1)
		if (rst)
			ins[n1] = NOP_INSN;
		else if (hwi0) begin
			ins[0] = hwi_insn;
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
		else if (en)
			ins[n1] = cline_i >> {pc_i[n1][5:2],5'b0};
		else
			ins[n1] = NOP_INSN;
end

always_ff @(posedge clk)
if (rst)
	cline_o <= {16{NOP_INSN}};
else begin
	if (en)
		cline_o <= cline_i;
end

always_ff @(posedge clk)
if (rst) begin
	for (n2 = 0; n2 < 4; n2 = n2 + 1)
		pr_o <= {$bits(pipeline_reg){1'b0}};
end
else begin	
	if (en)
		pr_o.v <= TRUE;
	for (n1 = 0; n1 < 5; n1 = n1 + 1)
		if (en) begin
			pr_o.pc[n1] <= pc_i[n1];
			pr_o.db[n1] <= {$bits(decode_bus_t){1'b0}};
			pr_o.ins[n1] <= ins[n1];
		end
end

endmodule
