import const_pkg::*;
import fta_bus_pkg::*;
import mmu_pkg::*;

module mmu_reg_write(rst, clk, cs_hwtw, sreq, ptbr, ptattr, virt_adr, pbl_regset);
input rst;
input clk;
input cs_hwtw;
input fta_cmd_request256_t sreq;
output ptbr_t ptbr;
output ptattr_t ptattr;
output virtual_address_t virt_adr;
output reg [4:0] pbl_regset;

always_ff @(posedge clk)
if (rst) begin
	ptbr <= 64'hFFFFFFFFFFF80000;
	ptattr <= 64'h1FFF081;
	ptattr.limit <= 16'h1fff;
	ptattr.level <= 3'd1;
	ptattr.pte_size <= _8B_PTE;	// 8B per PTE
	ptattr.pgsz <= 4'd7;		// 8kB pages
	ptattr.typ <= NAT_HIERARCHIAL;
	virt_adr <= 64'h0;
	pbl_regset <= 5'd0;
end
else begin
	if (cs_hwtw && sreq.we)
		casez(sreq.adr[13:0])
		14'b11_1111_001?_????:	
			begin
				if (&sreq.sel[15:8]) ptbr <= sreq.data1[63:0];
				if (&sreq.sel[31:24]) ptattr <= sreq.data1[191:128];
				$display("Q+ PTW: PTBR=%h",sreq.data1[63:0]);
			end
		14'b11_1111_010?_????:
			begin
				if (|sreq.sel[7:0]) virt_adr <= sreq.data1[63:0];
			end
		14'b11_1111_011?_????:
			begin
				if (|sreq.sel[15:8]) pbl_regset <= sreq.data1[127:64];
			end
		default:	;
		endcase
end

endmodule
