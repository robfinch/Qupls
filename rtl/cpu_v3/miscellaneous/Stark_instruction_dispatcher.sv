import const_pkg::*;
import Stark_pkg::*;

module Stark_instruction_dispatcher(rst, clk, rob, busy, rse_o, rob_dispatched,
	rob_dispatched_v);
input rst;
input clk;
input Stark_pkg::robentry_t [ROB_ENTRIES-1:0] rob;
input [15:0] busy;
output Stark_pkg::reservation_station_entry_t [3:0] rse_o;
output Stark_pkg::rob_entry_t [3:0] rob_dispatched;
output reg [3:0] rob_dispatched_v;

integer nn, kk;
reg [3:0] sau_cnt, mul_cnt, div_cnt, fma_cnt, trig_cnt, fcu_cnt, agen_cnt;
reg [3:0] mem_cnt, fpu_cnt;

always_ff @(posedge clk)
begin
	kk = 0;
	sau_cnt = 4'd0;
	rob_dispatched_v = 4'd0;
	for (nn = 0; nn < ROB_ENTRIES; nn = nn + 1) begin
		// If valid ...
		if (rob[nn].v &&
			// and not out already...
			!(|rob[nn].out) &&
			// and registers are mapped
			rob[nn].op.decbus.pRs1v &&
			rob[nn].op.decbus.pRs2v &&
			rob[nn].op.decbus.pRs3v &&
			rob[nn].op.decbus.pRdv &&
			rob[nn].op.decbus.pRnv &&
			// and dispatched fewer than four
			kk < 4
		) begin
			rse_o[kk] = {$bits(reservation_station_entry_t){1'b0}};
			rse_o[kk].ins = rob[nn].op.ins;
			rse_o[kk].argA_v = rob[nn].argA_v;
			rse_o[kk].argB_v = rob[nn].argB_v;
			rse_o[kk].argC_v = rob[nn].argC_v;
			rse_o[kk].argD_v = rob[nn].argD_v;
			if (!rob[nn].argA_v) rse_o[kk].argA = rob[nn].pRs1;
			if (!rob[nn].argB_v) rse_o[kk].argB = rob[nn].pRs2;
			if (!rob[nn].argC_v) rse_o[kk].argC = rob[nn].pRs3;
			if (!rob[nn].argD_v) rse_o[kk].argD = rob[nn].pRd;
			rse_o.argI = rob[nn].op.decbus.has_immb ? rob[nn].op.decbus.immb : rob[nn].op.decbus.immc;
			rse_o.funcunit = 4'd15;
			if (rob[nn].op.decbus.sau && sau_cnt < NSAU && !busy[sau_cnt]) begin
				rse_o[kk].funcunit = sau_cnt;
				sau_cnt = sau_cnt + 1;
				rob_dispatchd[kk] = nn;
				rob_disatched_v[kk] = VAL;
				kk = kk + 1;
			end
			if (rob[nn].op.decbus.mul && mul_cnt < 1 && !busy[2]) begin
				rse_o.funcunit = 4'd2;
				mul_cnt = mul_cnt + 1;
				rob_dispatchd[kk] = nn;
				rob_disatched_v[kk] = VAL;
				kk = kk + 1;
			end
			if (rob[nn].op.decbus.div && div_cnt < 1 && !busy[3]) begin
				rse_o.funcunit = 4'd3;
				div_cnt = div_cnt + 1;
				rob_dispatchd[kk] = nn;
				rob_disatched_v[kk] = VAL;
				kk = kk + 1;
			end
			if (rob[nn].op.decbus.sqrt && sqrt_cnt < 1 && !busy[3]) begin
				rse_o.funcunit = 4'd3;
				sqrt_cnt = sqrt_cnt + 1;
				rob_dispatchd[kk] = nn;
				rob_disatched_v[kk] = VAL;
				kk = kk + 1;
			end
			if (rob[nn].op.decbus.fma && fma_cnt < NFMA && !busy[4'd4+fma_cnt]) begin
				rse_o.funcunit <= 4'd4 + fma_cnt; 
				fma_cnt = fma_cnt + 1;
				rob_dispatchd[kk] = nn;
				rob_disatched_v[kk] = VAL;
				kk = kk + 1;
			end
			if (rob[nn].op.decbus.trig && trig_cnt < 1 && !busy[6]) begin
				rse_o.funcunit <= 4'd6; 
				trig_cnt = trig_cnt + 1;
				rob_dispatchd[kk] = nn;
				rob_disatched_v[kk] = VAL;
				kk = kk + 1;
			end
			if (rob[nn].op.decbus.fcu && fcu_cnt < 1 && !busy[7]) begin
				rse_o.funcunit <= 4'd7; 
				fcu_cnt = fcu_cnt + 1;
				rob_dispatchd[kk] = nn;
				rob_disatched_v[kk] = VAL;
				kk = kk + 1;
			end
			if (rob[nn].op.decbus.agen && agen_cnt < NAGEN && !busy[4'd8 + agen_cnt]) begin
				rse_o.funcunit <= 4'd8 + agen_cnt; 
				agen_cnt = agen_cnt + 1;
				rob_dispatchd[kk] = nn;
				rob_disatched_v[kk] = VAL;
				kk = kk + 1;
			end
			if (rob[nn].op.decbus.mem && mem_cnt < NDATA_PORTS && !busy[4'd10+mem_cnt]) begin
				rse_o.funcunit <= 4'd10 + mem_cnt;
				mem_cnt = mem_cnt + 1;
				rob_dispatchd[kk] = nn;
				rob_disatched_v[kk] = VAL;
				kk = kk + 1;
			end
			if (rob[nn].op.decbus.fpu && fpu_cnt < 1 && !busy[4'd12]) begin
				rse_o.funcunit <= 4'd12;
				fpu_cnt = fpu_cnt + 1;
				rob_dispatchd[kk] = nn;
				rob_disatched_v[kk] = VAL;
				kk = kk + 1;
			end
		end
	end
end

endmodule
