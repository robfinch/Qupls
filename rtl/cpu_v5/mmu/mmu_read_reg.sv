import const_pkg::*;
import mmu_pkg::*;
import wishbone_pkg::*;

module mmu_read_reg(rst, clk, cs_config, cs_regs, sreq, sresp, cfg_out,
	cfg_tid, cfg_ack, fault_adr, fault_seg, fault_asid, ptbr, ptattr,
	virt_adr, phys_adr, phys_adr_v, pbl_regset, pbl, pte_size, region_dat
);
input rst;
input clk;
input cs_config;
input cs_regs;
input wb_cmd_request256_t sreq;
output wb_cmd_response256_t sresp;
input [255:0] cfg_out;
input [15:0] cfg_tid;
input cfg_ack;
input address_t fault_adr;
input [63:0] fault_seg;
input asid_t fault_asid;
input ptbr_t ptbr;
input ptattr_t ptattr;
input virtual_address_t virt_adr;
input physical_address_t phys_adr;
input phys_adr_v;
input [4:0] pbl_regset;
input pebble_t [15:0] pbl;
output reg [1:0] pte_size;
input [255:0] region_dat;

always_ff @(posedge clk)
if (rst) begin
	sresp <= 256'd0;
end
else begin
	sresp.dat <= 256'd0;
	if (sreq.cyc) begin
		sresp.tid <= sreq.tid;
		sresp.pri <= sreq.pri;
	end
	if (cs_config) begin
		sresp.dat <= cfg_out;
		sresp.tid <= cfg_tid;
		sresp.ack <= cfg_ack;
	end
	else if (cs_regs) begin
		sresp.dat <= 256'd0;
		casez(sreq.adr[13:0])
		14'b11_1111_000?_????:
			begin
				sresp.dat[ 63:  0] <= fault_adr;
				sresp.dat[127: 64] <= 64'd0;
				sresp.dat[191:128] <= fault_seg;
				sresp.dat[255:192] <= 64'd0;
			end
		14'b11_1111_001?_????:
			begin
				sresp.dat[47: 0] <= 48'd0;
				sresp.dat[63:48] <= fault_asid;
				sresp.dat[127:64] <= ptbr;
				sresp.dat[191:128] <= 64'd0;
				sresp.dat[255:192] <= ptattr;
  		  case(ptattr.typ)
  		  I386:   pte_size <= _4B_PTE;
  		  default:    pte_size <= _8B_PTE;
  		  endcase
			end
		14'b11_1111_010?_????:	
		  begin	
		  	sresp.dat[63:0] <= virt_adr;
		  	sresp.dat[127:64] <= 64'd0;
		  	sresp.dat[191:128] <= phys_adr;
		  	sresp.dat[255:192] <= 64'd0;
		  end
		14'b11_1111_011?_????:
			begin
				sresp.dat[255:1] <= 255'd0;
				sresp.dat[0] <= phys_adr_v;
				sresp.dat[127:64] <= {59'd0,pbl_regset};
			end
		14'b11_1011_0???_????:
			begin
				sresp.dat <= {4{pbl[6:3]}};
			end
		14'b11_1100_00??_????:
			begin
				sresp.dat <= region_dat;
			end
		default:	sresp.dat <= 256'd0;
		endcase
	end
	else
		sresp.dat <= 256'd0;
end

endmodule
