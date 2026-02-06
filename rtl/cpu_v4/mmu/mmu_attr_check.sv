import const_pkg::*;
import mmu_pkg::*;

module mmu_attr_check(id, cpl, tlb_entry, om, we, region, priv_err);
input id;		// instruction(1) or data(0))
input [7:0] cpl;
input tlb_entry_t tlb_entry;
input [1:0] om;
input we;
input region_t region;
output reg priv_err;

always_comb
begin
priv_err = FALSE;
case(om)
2'd0:
	begin
		// Proper level of privilege?
//		if (~id && cpl < tlb_entry.pte.l1.pl)
//			priv_err = TRUE;
//		if (id && cpl >= tlb_entry.pte.l1.pl)
//			priv_err = TRUE;
		// Fetching an instruction and writing?
		if (id && we)
			priv_err = TRUE;
		// Check attributes from region table
		// Writing a read-only page?
		if (((region.at[0].rwx & 3'b100) == 3'b100) & we)
			priv_err = TRUE;
		// Data access to executable page?
		if (region.at[0].rwx & 3'b001 & ~id)
			priv_err = TRUE;
		// Check attributes from TLB
		// User page?
		if (!tlb_entry.pte.u)
			priv_err = TRUE;
		// Writing a read-only page?
		if (((tlb_entry.pte.rwx & 3'b110) == 3'b100) && we)
			priv_err = TRUE;
		// Data access to executable page?
		if (tlb_entry.pte.rwx & 3'b001 & ~id)
			priv_err = TRUE;
	end
2'd1:
	begin
		// Proper level of privilege?
//		if (~id && cpl < tlb_entry.pte.l1.pl)
//			priv_err = TRUE;
//		if (id && cpl >= tlb_entry.pte.l1.pl)
//			priv_err = TRUE;
		// Fetching an instruction and writing?
		if (id && we)
			priv_err = TRUE;
		// Check attributes from region table
		// Writing a read-only page?
		if (((region.at[1].rwx & 3'b100) == 3'b100) & we)
			priv_err = TRUE;
		// Data access to executable page?
		if (region.at[1].rwx & 3'b001 & ~id)
			priv_err = TRUE;
		// Check attributes from TLB
		// Writing a read-only page?
		if (((tlb_entry.pte.rwx & 3'b110) == 3'b100) && we)
			priv_err = TRUE;
		// Data access to executable page?
		if (tlb_entry.pte.rwx & 3'b001 & ~id)
			priv_err = TRUE;
	end	
2'd2:
	begin
		// Fetching an instruction and writing?
		if (id && we)
			priv_err = TRUE;
		// Check attributes from region table
		// Writing a read-only page?
		if (((region.at[2].rwx & 3'b100) == 3'b100) & we)
			priv_err = TRUE;
	end
2'd3:
	begin
		// Check attributes from region table
		// Writing a read-only page?
		if (((region.at[3].rwx & 3'b100) == 3'b100) & we)
			priv_err = TRUE;
	end
endcase
end

endmodule
