package ptw_pkg::*;

typedef enum logic [5:0]
{
	st_idle = 0,
	st_read_lev1,
	st_read_lev1_2,
	st_read_lev1_3,
	st_read_lev1_4,
	st_read_lev2,
	st_read_lev2_2,
	st_read_lev2_3,
	st_read_lev2_4,
	st_readwrite_pte,
	st_readwrite_pte2,
	st_read_tlb,
	st_read_tlb2,
	st_read_tlb3,
	st_read_tlb4,
	st_read_tlb5,
	st_read_tlb2a,
	st_read_tlb2a2,
	st_read_tlb2a3,
	st_read_tlb2a4,
	st_read_tlb2a5,
	st_store_pte,
	st_store_pte2,
	st_store_pte3,
	st_update_tlb,
	st_update_tlb2,
	st_update_tlb3,
	st_update_tlb4,
	st_update_tlb2a,
	st_update_tlb2a2,
	st_update_tlb2a3,
	st_update_tlb2a4,
	st_flush_tlb,
	st_flush_tlb2,
	st_flush_tlb2a,
	st_flush_tlb2a2,
	st_flush_asid,
	st_flush_asid2
} state_t;
ptw_state_t state;

endpackage
