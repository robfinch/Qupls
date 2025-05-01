import Stark_pkg::*;

module Stark_decode_branch_tgt_src(ins, bts);
input Stark_pkg::instruction_t ins;
output Stark_pkg::bts_t bts;

always_comb
	if (Stark_pkg::fnIsBccR(ins))	
		bts = BTS_REG;
	else if (Stark_pkg::fnIsBranch(ins))
		bts = BTS_DISP;
	else if (Stark_pkg::fnIsBsr(ins))
		bts = BTS_BSR;
	else if (Stark_pkg::fnIsCall(ins))
		bts = BTS_CALL;
	else if (Stark_pkg::fnIsRti(ins))
		bts = BTS_RTI;
	else if (Stark_pkg::fnIsRet(ins))
		bts = BTS_RET;
	else
		bts = BTS_DISP;

endmodule
