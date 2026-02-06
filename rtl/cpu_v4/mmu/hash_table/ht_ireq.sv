import wishbone_pkg::*;
import hash_table_pkg::*;

module ht_ireq(rst, clk, state, free_asid, req, ireq);
input rst;
input clk;
input [2:0] state;
input free_asid;
input wb_cmd_request64_t req;
output wb_cmd_request64_t ireq;

reg [31:0] adr;
ptge_t ptge;

always_ff @(posedge clk)
if (rst) begin
	adr <= 32'd0;
	ptge <= {$bits(ptge_t){1'b0}};
end
else begin
	case(state)
	3'd1:	ireq <= req;
	3'd5:
		begin
			ireq.adr <= adr;
			ireq.cyc <= 1'b1;
			ireq.stb <= 1'b1;
			ireq.we <= 1'b1;
			ireq.dat <= ptge;				
		end
	3'd7:	adr[12:0] <= adr[12:0] + 32'd8;
	default:	;
	endcase
end

endmodule
