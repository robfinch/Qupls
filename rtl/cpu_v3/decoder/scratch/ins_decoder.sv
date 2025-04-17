import const_pkg::*;
import Qupls3_pkg::*;

module ins_decoder(min_pos,cline,pr_i,pr_o);
input [3:0] min_pos;
input [511:0] cline;
input Qupls3_pkg::pipeline_reg_t pr_i;
output Qupls3_pkg::pipeline_reg_t pr_o;

integer n1;

Qupls3_pkg::decode_bus_t db;
reg [7:0] pos;
reg [3:0] isz;
wire pfxa, pfxb, pfxc;

always_comb pos = fnConstPos(pr_i.ins);
always_comb isz = fnConstSize(pr_i.ins);

always_comb
begin
    pr_o = pr_i;
    pr_o.db = db;
    pr_o.db.v = TRUE;
    if (pr_i.pc[5:2] >= min_pos && |min_pos) begin
        pr_o.db.v = FALSE;
        pr_o.ins.any.opcode = OP_NOP;
        pr_o.ins.any.payload = 26'd0;
    end
end

decode_const u1 (
	cline, pr_i.ins, db.imma, db.immb, db.immc, db.has_imma, db.has_immb, db.has_immc,
	db.pfxa, db.pfxb, db.pfxc);

endmodule
