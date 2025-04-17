import const_pkg::*;
import Qupls3_pkg::*;

module pipe_dec(rst,clk,en,cline_i,pr_i,pr_o);
input rst;
input clk;
input en;
input [511:0] cline_i;
input Qupls3_pkg::pipeline_reg_t [4:0] pr_i;
output Qupls3_pkg::pipeline_reg_t [3:0] pr_o;

integer n1,n2;

Qupls3_pkg::pipeline_reg_t [4:0] pr;
Qupls3_pkg::pipeline_reg_t [3:0] pr2;
wire [3:0] min_pos;

min_constant_decoder umind1(cline_i, min_pos);

ins_decoder uid0 (min_pos,cline,pr_i[0],pr[0]);
ins_decoder uid1 (min_pos,cline,pr_i[1],pr[1]);
ins_decoder uid2 (min_pos,cline,pr_i[2],pr[2]);
ins_decoder uid3 (min_pos,cline,pr_i[3],pr[3]);
ins_decoder uid4 (min_pos,cline,pr_i[4],pr[4]);

always_comb
begin
	for (n2 = 0; n2 < 4; n2 = n2 + 1)
		pr2[n2] = pr[n2];
	for (n2 = 1; n2 < 5; n2 = n2 + 1) begin
		if (pr[n2].db.pfxa) begin
			pr2[n2-1].db.imma = {pr[n2].db.imma|pr2[n2-1][15:11]};
			pr2[n2-1].db.has_imma = 1'b1;
		end
		if (pr[n2].db.pfxb) begin
			pr2[n2-1].db.immb = {pr[n2].db.immb|pr2[n2-1][21:17]};
			pr2[n2-1].db.has_immb = 1'b1;
		end
		if (pr[n2].db.pfxc) begin
			pr2[n2-1].db.immc = {pr[n2].db.immc|pr2[n2-1][26:22]};
			pr2[n2-1].db.has_immc = 1'b1;
		end
	end
end


always_ff @(posedge clk)
if (rst)
	for (n1 = 0; n1 < 4; n1 = n1 + 1)
		pr_o[n1] <= {$bits(Qupls3_pkg::pipeline_reg_t){1'b0}};
else begin
	for (n1 = 0; n1 < 4; n1 = n1 + 1)
		if (en) begin
			pr_o[n1] <= pr_i[n1];
			pr_o[n1].db <= pr2[n1].db;
		end
end

endmodule
