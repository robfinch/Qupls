import Thor2025Pkg::*;

genvar g;
rndx_t alu0_re;

op_src_t alu0_argA_src;
op_src_t alu0_argB_src;
op_src_t alu0_argC_src;
op_src_t alu0_argT_src;
op_src_t alu0_argP_src;

value_t rfo_alu0_argA;
value_t rfo_alu0_argB;
value_t rfo_alu0_argC;
value_t rfo_alu0_argT;
value_t rfo_alu0_argP;
value_t alu0_res;
value_t alu1_res;
value_t fpu0_res;
value_t fcu_res;
value_t load_res;
value_t ma0,ma1;				// memory address

pregno_t alu0_argA_reg;
pregno_t alu0_argB_reg;
pregno_t alu0_argC_reg;
pregno_t alu0_argT_reg;
pregno_t alu0_argP_reg;

pregno_t alu1_argA_reg;
pregno_t alu1_argB_reg;
pregno_t alu1_argC_reg;
pregno_t alu1_argT_reg;
pregno_t alu1_argP_reg;

pregno_t fpu0_argA_reg;
pregno_t fpu0_argB_reg;
pregno_t fpu0_argC_reg;
pregno_t fpu0_argT_reg;
pregno_t fpu0_argP_reg;

pregno_t fcu_argA_reg;
pregno_t fcu_argB_reg;
pregno_t fcu_argT_reg;

pregno_t load_argA_reg;
pregno_t load_argB_reg;
pregno_t load_argC_reg;
pregno_t load_argT_reg;
pregno_t load_argP_reg;

pregno_t store_argA_reg;
pregno_t store_argB_reg;
pregno_t store_argC_reg;
pregno_t store_argP_reg;

pregno_t [26:0] rf_reg;
value_t [26:0] rfo;

assign rf_reg[0] = alu0_argA_reg;
assign rf_reg[1] = alu0_argB_reg;
assign rf_reg[2] = alu0_argC_reg;
assign rf_reg[3] = alu0_argT_reg;
assign rf_reg[4] = alu0_argP_reg;

assign rf_reg[5] = alu1_argA_reg;
assign rf_reg[6] = alu1_argB_reg;
assign rf_reg[7] = alu1_argC_reg;
assign rf_reg[8] = alu1_argT_reg;
assign rf_reg[9] = alu1_argP_reg;

assign rf_reg[10] = fpu0_argA_reg;
assign rf_reg[11] = fpu0_argB_reg;
assign rf_reg[12] = fpu0_argC_reg;
assign rf_reg[13] = fpu0_argT_reg;
assign rf_reg[14] = fpu0_argP_reg;

assign rf_reg[15] = fcu_argA_reg;
assign rf_reg[16] = fcu_argB_reg;
assign rf_reg[17] = fcu_argT_reg;

assign rf_reg[18] = load_argA_reg;
assign rf_reg[19] = load_argB_reg;
assign rf_reg[20] = load_argC_reg;
assign rf_reg[21] = load_argT_reg;
assign rf_reg[22] = load_argP_reg;

assign rf_reg[23] = store_argA_reg;
assign rf_reg[24] = store_argB_reg;
assign rf_reg[25] = store_argC_reg;
assign rf_reg[26] = store_argP_reg;

assign rfo_alu0_argA = rfo[0];
assign rfo_alu0_argB = rfo[1];
assign rfo_alu0_argC = rfo[2];
assign rfo_alu0_argT = rfo[3];
assign rfo_alu0_argP = rfo[4];

assign rfo_alu1_argA = rfo[5];
assign rfo_alu1_argB = rfo[6];
assign rfo_alu1_argC = rfo[7];
assign rfo_alu1_argT = rfo[8];
assign rfo_alu1_argP = rfo[9];

assign rfo_fpu0_argA = rfo[10];
assign rfo_fpu0_argB = rfo[11];
assign rfo_fpu0_argC = rfo[12];
assign rfo_fpu0_argT = rfo[13];
assign rfo_fpu0_argP = rfo[14];

assign rfo_fcu_argA = rfo[15];
assign rfo_fcu_argB = rfo[16];
assign rfo_fcu_argT = rfo[17];

assign rfo_load_argA = rfo[18];
assign rfo_load_argB = rfo[19];
assign rfo_load_argC = rfo[20];
assign rfo_load_argT = rfo[21];
assign rfo_load_argP = rfo[22];

assign rfo_store_argA = rfo[23];
assign rfo_store_argB = rfo[24];
assign rfo_store_argC = rfo[25];
assign rfo_store_argP = rfo[26];


	alu0_argA_reg <= rob[alu0_re].Ra;
	alu0_argB_reg <= rob[alu0_re].Rb;
	alu0_argC_reg <= rob[alu0_re].Rc;
	alu0_argT_reg <= rob[alu0_re].Rt;
	alu0_argP_reg <= rob[alu0_re].Rp;

	alu1_argA_reg <= rob[alu1_re].Ra;
	alu1_argB_reg <= rob[alu1_re].Rb;
	alu1_argC_reg <= rob[alu1_re].Rc;
	alu1_argT_reg <= rob[alu1_re].Rt;
	alu1_argP_reg <= rob[alu1_re].Rp;

	fpu0_argA_reg <= rob[fpu0_re].Ra;
	fpu0_argB_reg <= rob[fpu0_re].Rb;
	fpu0_argC_reg <= rob[fpu0_re].Rc;
	fpu0_argT_reg <= rob[fpu0_re].Rt;
	fpu0_argP_reg <= rob[fpu0_re].Rp;

	fcu_argA_reg <= rob[fcu_re].Ra;
	fcu_argB_reg <= rob[fcu_re].Rb;
	fcu_argT_reg <= rob[fcu_re].Rt;

	load_argA_reg <= rob[load_re].Ra;
	load_argB_reg <= rob[load_re].Rb;
	load_argC_reg <= rob[load_re].Rc;
	load_argT_reg <= rob[load_re].Rt;
	load_argP_reg <= rob[load_re].Rp;

	store_argA_reg <= rob[store_re].Ra;
	store_argB_reg <= rob[store_re].Rb;
	store_argC_reg <= rob[store_re].Rc;
	store_argP_reg <= rob[store_re].Rp;

assign wrport0_res = alu0_res;
assign wrport1_res = alu1_res;
always_comb
	case(wrport2_src)
	WP2_SRC_LOAD:	wrport2_res = load_res;
	WP2_SRC_FPU:	wrport2_res = fpu_res;
	WP2_SRC_FCU:	wrport2_res = fcu_res;
	WP2_SRC_DEF:	wrport2_res = {2{32'hDEAD_BEEF}};
	endcase

Thor2025_regfile3w32r urf1 (
	.rst(rst),
	.clk(clk), 
	.wr0(wrport0_v),
	.wr1(wrport1_v),
	.wr2(wrport2_v),
	.we0(),
	.we1(),
	.we2(),
	.wa0(wrport0_Rt),
	.wa1(wrport1_Rt),
	.wa2(wrport2_Rt),
	.i0(wrport0_res),
	.i1(wrport1_res),
	.i2(wrport2_res),
	.rclk(clk),
	.ra(rf_reg),
	.o(rfo)
);
//
// additional logic for ISSUE
//
// for the moment, we look at ALU-input buffers to allow back-to-back issue of 
// dependent instructions ... we do not, however, look ahead for DRAM requests 
// that will become valid in the next cycle.  instead, these have to propagate
// their results into the IQ entry directly, at which point it becomes issue-able
//

// note that, for all intents & purposes, iqentry_done == iqentry_agen ... no need to duplicate

rob_bitmask_t args_valid;
rob_bitmask_t could_issue;

generate begin : issue_logic
for (g = 0; g < ROB_ENTRIES; g = g + 1)
begin
assign args_valid[g] = (rob[g].argA_v
						// Or forwarded
				    || (rob[g].decbus.Ra == alu0_Rt && alu0_v)
				    || (rob[g].decbus.Ra == alu1_Rt && alu1_v)
				    || (rob[g].decbus.Ra == fpu0_Rt && fpu0_v)
				    || (rob[g].decbus.Ra == fcu_Rt && fcu_v)
				    || (rob[g].decbus.Ra == load_Rt && load_v))
				    && (rob[g].argB_v
						// Or forwarded
				    || (rob[g].decbus.Rb == alu0_Rt && alu0_v)
				    || (rob[g].decbus.Rb == alu1_Rt && alu1_v)
				    || (rob[g].decbus.Rb == fpu0_Rt && fpu0_v)
				    || (rob[g].decbus.Rb == fcu_Rt && fcu_v)
				    || (rob[g].decbus.Rb == load_Rt && load_v))
				    && (rob[g].argC_v
						// Or forwarded
				    || (rob[g].decbus.Rc == alu0_Rt && alu0_v)
				    || (rob[g].decbus.Rc == alu1_Rt && alu1_v)
				    || (rob[g].decbus.Rc == fpu0_Rt && fpu0_v)
				    || (rob[g].decbus.Rc == fcu_Rt && fcu_v)
				    || (rob[g].decbus.Rc == load_Rt && load_v)
				    || (rob[g].mem & ~rob[g].agen))
				    && (rob[g].argT_v
						// Or forwarded
				    || (rob[g].decbus.Rt == alu0_Rt && alu0_v)
				    || (rob[g].decbus.Rt == alu1_Rt && alu1_v)
				    || (rob[g].decbus.Rt == fpu0_Rt && fpu0_v)
				    || (rob[g].decbus.Rt == fcu_Rt && fcu_v)
				    || (rob[g].decbus.Rt == load_Rt && load_v))
				    && (rob[g].argP_v
						// Or forwarded
				    || (rob[g].decbus.Rp == alu0_Rt && alu0_v)
				    || (rob[g].decbus.Rp == alu1_Rt && alu1_v)
				    || (rob[g].decbus.Rp == fpu0_Rt && fpu0_v)
				    || (rob[g].decbus.Rp == fcu_Rt && fcu_v)
				    || (rob[g].decbus.Rp == load_Rt && load_v))
				    ;
assign could_issue[g] = rob_v[g] && !rob[g].done 
												&& !rob[g].out
												&& args_valid[g]
                        && (rob[g].mem ? !rob[g].agen : 1'b1);
end                                 
end
endgenerate


	//
	// see if anybody wants the results ... look at lots of buses:
	//  - alu0_bus
	//  - alu1_bus
	//  - fpu bus
	//	- fcu_bus
	//  - dram_bus0
	//  - dram_bus1
	//

	for (nn = 0; nn < ROB_ENTRIES; nn = nn + 1) begin

		if (rob[nn].argA_v == INV && rob[nn].decbus.Ra == wrport0_Rt && rob_v[nn] == VAL && wrport0_v == VAL)
	    rob[nn].argA_v <= VAL;
		if (rob[nn].argB_v == INV && rob[nn].decbus.Rb == wrport0_Rt && rob_v[nn] == VAL && wrport0_v == VAL)
	    rob[nn].argB_v <= VAL;
		if (rob[nn].argC_v == INV && rob[nn].decbus.Rc == wrport0_Rt && rob_v[nn] == VAL && wrport0_v == VAL)
	    rob[nn].argC_v <= VAL;
		if (rob[nn].argT_v == INV && rob[nn].decbus.Rt == wrport0_Rt && rob_v[nn] == VAL && wrport0_v == VAL)
	    rob[nn].argT_v <= VAL;
		if (rob[nn].argP_v == INV && rob[nn].decbus.Rp == wrport0_Rt && rob_v[nn] == VAL && wrport0_v == VAL)
	    rob[nn].argP_v <= VAL;

		if (NALU > 1) begin
			if (rob[nn].argA_v == INV && rob[nn].decbus.Ra == wrport1_Rt && rob_v[nn] == VAL && wrport1_v == VAL)
		    rob[nn].argA_v <= VAL;
			if (rob[nn].argB_v == INV && rob[nn].decbus.Rb == wrport1_Rt && rob_v[nn] == VAL && wrport1_v == VAL)
		    rob[nn].argB_v <= VAL;
			if (rob[nn].argC_v == INV && rob[nn].decbus.Rc == wrport1_Rt && rob_v[nn] == VAL && wrport1_v == VAL)
		    rob[nn].argC_v <= VAL;
			if (rob[nn].argT_v == INV && rob[nn].decbus.Rt == wrport1_Rt && rob_v[nn] == VAL && wrport1_v == VAL)
		    rob[nn].argT_v <= VAL;
			if (rob[nn].argP_v == INV && rob[nn].decbus.Rp == wrport1_Rt && rob_v[nn] == VAL && wrport1_v == VAL)
		    rob[nn].argP_v <= VAL;
		end

		if (rob[nn].argA_v == INV && rob[nn].decbus.Ra == wrport2_Rt && rob_v[nn] == VAL && wrport2_v == VAL)
	    rob[nn].argA_v <= VAL;
		if (rob[nn].argB_v == INV && rob[nn].decbus.Rb == wrport2_Rt && rob_v[nn] == VAL && wrport2_v == VAL)
	    rob[nn].argB_v <= VAL;
		if (rob[nn].argC_v == INV && rob[nn].decbus.Rc == wrport2_Rt && rob_v[nn] == VAL && wrport2_v == VAL)
	    rob[nn].argC_v <= VAL;
		if (rob[nn].argT_v == INV && rob[nn].decbus.Rt == wrport2_Rt && rob_v[nn] == VAL && wrport2_v == VAL)
	    rob[nn].argT_v <= VAL;
		if (rob[nn].argP_v == INV && rob[nn].decbus.Rp == wrport2_Rt && rob_v[nn] == VAL && wrport2_v == VAL)
	    rob[nn].argP_v <= VAL;

	end


// Operand source muxes
					if (alu0_available) begin
						case(alu0_argA_src)
						OP_SRC_REG:	alu0_argA <= rfo_alu0_argA;
						OP_SRC_ALU0: alu0_argA <= alu0_res;
						OP_SRC_ALU1: alu0_argA <= alu1_res;
						OP_SRC_FPU0: alu0_argA <= fpu0_res;
						OP_SRC_FCU:	alu0_argA <= fcu_res;
						OP_SRC_LOAD:	alu0_argA <= load_res;
						OP_SRC_IMM:	alu0_argA <= rob[alu0_re].imma;
						default:	alu0_argA <= {2{32'hDEADBEEF}};
						endcase
						case(alu0_argB_src)
						OP_SRC_REG:	alu0_argB <= rfo_alu0_argB;
						OP_SRC_ALU0: alu0_argB <= alu0_res;
						OP_SRC_ALU1: alu0_argB <= alu1_res;
						OP_SRC_FPU0: alu0_argB <= fpu0_res;
						OP_SRC_FCU:	alu0_argB <= fcu_res;
						OP_SRC_LOAD:	alu0_argB <= load_res;
						OP_SRC_IMM:	alu0_argB <= rob[alu0_re].immb;
						default:	alu0_arga <= {2{32'hDEADBEEF}};
						endcase
						case(alu0_argC_src)
						OP_SRC_REG:	alu0_argC <= rfo_alu0_argC;
						OP_SRC_ALU0: alu0_argC <= alu0_res;
						OP_SRC_ALU1: alu0_argC <= alu1_res;
						OP_SRC_FPU0: alu0_argC <= fpu0_res;
						OP_SRC_FCU:	alu0_argC <= fcu_res;
						OP_SRC_LOAD:	alu0_argC <= load_res;
						OP_SRC_IMM:	alu0_argC <= rob[alu0_re].immc;
						default:	alu0_argC <= {2{32'hDEADBEEF}};
						endcase
						case(alu0_argT_src)
						OP_SRC_REG:	alu0_argT <= rfo_alu0_argT;
						OP_SRC_ALU0: alu0_argT <= alu0_res;
						OP_SRC_ALU1: alu0_argT <= alu1_res;
						OP_SRC_FPU0: alu0_argT <= fpu0_res;
						OP_SRC_FCU:	alu0_argT <= fcu_res;
						OP_SRC_LOAD:	alu0_argT <= load_res;
						default:	alu0_argT <= {2{32'hDEADBEEF}};
						endcase
						case(alu0_argP_src)
						OP_SRC_REG:	alu0_argP <= rfo_alu0_argP;
						OP_SRC_ALU0: alu0_argP <= alu0_res;
						OP_SRC_ALU1: alu0_argP <= alu1_res;
						OP_SRC_LOAD:	alu0_argP <= load_res;
						default:	alu0_argP <= {2{32'hDEADBEEF}};
						endcase
						alu0_argI	<= rob[alu0_re].a0;
						alu0_ld <= 1'b1;
						alu0_instr <= rob[alu0_re].op;
						alu0_div <= rob[alu0_re].div;
						alu0_pc <= rob[alu0_re].pc;
				    rob[alu0_re].out <= VAL;
				    rob[alu0_re].owner <= Thor2025pkg::ALU0;
			    end

	//
	// enqueue fetchbuf0 and fetchbuf1, but only if there is room, 
	// and ignore fetchbuf1 if fetchbuf0 has a backwards branch in it.
	//
	// also, do some instruction-decode ... set the operand_valid bits in the IQ
	// appropriately so that the DATAINCOMING stage does not have to look at the opcode
	//
	if (!branchmiss) 	// don't bother doing anything if there's been a branch miss

		case ({fetchbuf0_v, fetchbuf1_v})

    2'b00: ; // do nothing

    2'b01:
    	if (rob_v[tail0] == INV) begin
				did_branchback1 <= branchback & ~did_branchback;
				for (n12 = 0; n12 < ROB_ENTRIES; n12 = n12 + 1)
					rob[n12].sn <= rob[n12].sn - 2'd1;
//					rob[n12].sn <= |rob[n12].sn ? rob[n12].sn - 2'd1 : rob[n12].sn;
				rob[tail0].sn <= 6'h3F;
				rob[tail0].owner <= Thor2025pkg::NONE;
				rob[tail0].done <= db1.nop;
				rob[tail0].out <= INV;
				rob[tail0].op <= fetchbuf1_instr[0]; 
				rob[tail0].bt <= pt1;
				rob[tail0].agen <= INV;
				rob[tail0].pc <= fetchbuf1_pc;
				rob[tail0].decbus <= db1;
				rob[tail0].exc <= FLT_NONE;
				rob[tail0].takb <= 1'b0;
				rob[tail0].brtgt <= 'd0;
				rob[tail0].argA_v <= fnSourceAv(fetchbuf1_instr[0]) || rf_v[ db1.Ra ];
				rob[tail0].argB_v <= fnSourceBv(fetchbuf1_instr[0]) || rf_v[ db1.Rb ];
				rob[tail0].argC_v <= fnSourceCv(fetchbuf1_instr[0]) || rf_v[ db1.Rc ];
				rob[tail0].argT_v <= fnSourceTv(fetchbuf1_instr[0]) || rf_v[ db1.Rt ];
				rob[tail0].argP_v <= fnSourcePv(fetchbuf1_instr[0]) || rf_v[ db1.Rp ];
				lastq0 <= {1'b0,tail0};
				lastq1 <= {1'b1,tail0};
				if (!db1.pfx) begin
					atom_mask <= atom_mask >> 4'd3;
					pred_mask <= {4'hF,pred_mask} >> 4'd4;
					postfix_mask <= 'd0;
				end
				else
					postfix_mask <= {postfix_mask[4:0],1'b1};
				if (postfix_mask[5])
					rob[tail0].exc <= FLT_PFX;
				if (fnIsPred(fetchbuf1_instr[0])) begin
					pred_mask <= fetchbuf1_instr[0][34:7];
				end
				iqentry_issue_reg[tail0] <= 1'b0;
			end
    2'b10:
    	begin
	    	if (rob_v[tail0] == INV && (~^pred_mask[1:0] || pred_mask[1:0]==pred_val)) begin
					if (!db0.br) panic <= `PANIC_FETCHBUFBEQ;
					if (!pt0)	panic <= `PANIC_FETCHBUFBEQ;
					//
					// this should only happen when the first instruction is a BEQ-backwards and the IQ
					// happened to be full on the previous cycle (thus we deleted fetchbuf1 but did not
					// enqueue fetchbuf0) ... probably no need to check for LW -- sanity check, just in case
					//
					did_branchback1 <= branchback & ~did_branchback;
					for (n12 = 0; n12 < ROB_ENTRIES; n12 = n12 + 1)
						rob[n12].sn <= rob[n12].sn - 2'd1;
//						rob[n12].sn <= |rob[n12].sn ? rob[n12].sn - 2'd1 : rob[n12].sn;
					rob[tail0].sn <= 6'h3F;
					rob[tail0].owner <= Thor2025pkg::NONE;
					rob[tail0].done <= db0.nop;
					rob[tail0].out	<= INV;
					rob[tail0].op <= fetchbuf0_instr[0]; 			// BEQ
					rob[tail0].bt <= VAL;
					rob[tail0].agen <= INV;
					rob[tail0].pc <= fetchbuf0_pc;
					rob[tail0].decbus = db0;
					rob[tail0].exc    <=	FLT_NONE;
					rob[tail0].takb <= 1'b0;
					rob[tail0].brtgt <= 'd0;
					rob[tail0].argA_v <= fnSourceAv(fetchbuf0_instr[0]) || rf_v[ db0.Ra ];
					rob[tail0].argB_v <= fnSourceBv(fetchbuf0_instr[0]) || rf_v[ db0.Rb ];
					rob[tail0].argC_v <= fnSourceCv(fetchbuf0_instr[0]) || rf_v[ db0.Rc ];
					rob[tail0].argT_v <= fnSourceTv(fetchbuf0_instr[0]) || rf_v[ db0.Rt ];
					rob[tail0].argP_v <= fnSourcePv(fetchbuf0_instr[0]) || rf_v[ db0.Rp ];
					lastq0 <= {1'b0,tail0};
					lastq1 <= {1'b1,tail0};
					if (!db0.pfx) begin
						atom_mask <= atom_mask >> 4'd3;
						pred_mask <= {4'hF,pred_mask} >> 4'd4;
						postfix_mask <= 'd0;
					end
					else
						postfix_mask <= {postfix_mask[4:0],1'b1};
					if (postfix_mask[5])
						rob[tail0].exc <= FLT_PFX;
					if (fnIsPred(fetchbuf0_instr[0]))
						pred_mask <= fetchbuf0_instr[0][34:7];
					iqentry_issue_reg[tail0] <= 1'b0;
		    end
	  	end

    2'b11:
    	if (rob_v[tail0] == INV) begin

				//
				// if the first instruction is a backwards branch, enqueue it & stomp on all following instructions
				//
				if (pt0) begin
					did_branchback1 <= branchback & ~did_branchback;
					for (n12 = 0; n12 < ROB_ENTRIES; n12 = n12 + 1)
						rob[n12].sn <= rob[n12].sn - 2'd1;
//						rob[n12].sn <= |rob[n12].sn ? rob[n12].sn - 2'd1 : rob[n12].sn;
					rob[tail0].sn <= 6'h3F;
					rob[tail0].owner <= Thor2025pkg::NONE;
			    rob[tail0].done <= db0.nop;
			    rob[tail0].out <=	INV;
			    rob[tail0].op <=	fetchbuf0_instr[0]; 			// BEQ
			    rob[tail0].bt <= VAL;
			    rob[tail0].agen <= INV;
			    rob[tail0].pc <=	fetchbuf0_pc;
			    rob[tail0].decbus <= db0;
			    rob[tail0].exc    <=	FLT_NONE;
					rob[tail0].takb <= 1'b0;
					rob[tail0].brtgt <= 'd0;
					rob[tail0].argA_v <= fnSourceAv(fetchbuf0_instr[0]) || rf_v[ db0.Ra ];
					rob[tail0].argB_v <= fnSourceBv(fetchbuf0_instr[0]) || rf_v[ db0.Rb ];
					rob[tail0].argC_v <= fnSourceCv(fetchbuf0_instr[0]) || rf_v[ db0.Rc ];
					rob[tail0].argT_v <= fnSourceTv(fetchbuf0_instr[0]) || rf_v[ db0.Rt ];
					rob[tail0].argP_v <= fnSourcePv(fetchbuf0_instr[0]) || rf_v[ db0.Rp ];
					lastq0 <= {1'b0,tail0};
					lastq1 <= {1'b1,tail0};
					if (!db0.pfx) begin
						atom_mask <= atom_mask >> 4'd3;
						pred_mask <= {4'hF,pred_mask} >> 4'd4;
						postfix_mask <= 'd0;
					end
					else
						postfix_mask <= {postfix_mask[4:0],1'b1};
					if (postfix_mask[5])
						rob[tail0].exc <= FLT_PFX;
					if (fnIsPred(fetchbuf0_instr[0]))
						pred_mask <= fetchbuf0_instr[0][34:7];
					iqentry_issue_reg[tail0] <= 1'b0;
				end

				else begin	// fetchbuf0 doesn't contain a backwards branch
					if (!db0.pfx)
						pred_mask <= {8'hFF,pred_mask} >> 4'd8;
			    //
			    // so -- we can enqueue 1 or 2 instructions, depending on space in the IQ
			    // update tail0/tail1 separately (at top)
			    // update the rf_v and rf_source bits separately (at end)
			    //   the problem is that if we do have two instructions, 
			    //   they may interact with each other, so we have to be
			    //   careful about where things point.
			    //

			    //
			    // enqueue the first instruction ...
			    //
					did_branchback1 <= branchback & ~did_branchback;
					for (n12 = 0; n12 < ROB_ENTRIES; n12 = n12 + 1)
						rob[n12].sn <= rob[n12].sn - 2'd1;
//						rob[n12].sn <= |rob[n12].sn ? rob[n12].sn - 2'd1 : rob[n12].sn;
					rob[tail0].sn <= 6'h3F;
					rob[tail0].owner <= Thor2025pkg::NONE;
			    rob[tail0].done <= db0.nop;
			    rob[tail0].out <= INV;
			    rob[tail0].op <= fetchbuf0_instr[0]; 
			    rob[tail0].bt <= INV;//ptakb;
			    rob[tail0].agen <= INV;
			    rob[tail0].pc <= fetchbuf0_pc;
			    rob[tail0].exc    <=   FLT_NONE;
					rob[tail0].br <= db0.br;
					rob[tail0].bts <= db0.bts;
					rob[tail0].takb <= 1'b0;
					rob[tail0].brtgt <= 'd0;
					rob[tail0].argA_v <= fnSourceAv(fetchbuf0_instr[0]) || rf_v[ db0.Ra ];
					rob[tail0].argB_v <= fnSourceBv(fetchbuf0_instr[0]) || rf_v[ db0.Rb ];
					rob[tail0].argC_v <= fnSourceCv(fetchbuf0_instr[0]) || rf_v[ db0.Rc ];
					rob[tail0].argT_v <= fnSourceTv(fetchbuf0_instr[0]) || rf_v[ db0.Rt ];
					rob[tail0].argP_v <= fnSourcePv(fetchbuf0_instr[0]) || rf_v[ db0.Rp ];
					lastq0 <= {1'b0,tail0};
					lastq1 <= {1'b1,tail0};
					if (!db0.pfx) begin
						atom_mask <= atom_mask >> 4'd3;
						pred_mask <= {4'hF,pred_mask} >> 4'd4;
						postfix_mask <= 'd0;
					end
					else
						postfix_mask <= {postfix_mask[4:0],1'b1};
					if (postfix_mask[5])
						rob[tail0].exc <= FLT_PFX;
					if (fnIsPred(fetchbuf0_instr[0]))
						pred_mask <= fetchbuf0_instr[0][34:7];
					iqentry_issue_reg[tail0] <= 1'b0;

			    //
			    // if there is room for a second instruction, enqueue it
			    //
			    if (rob_v[tail1] == INV && SUPPORT_Q2) begin

						for (n12 = 0; n12 < ROB_ENTRIES; n12 = n12 + 1)
							rob[n12].sn <= rob[n12].sn - 2'd2;
//							rob[n12].sn <= |rob[n12].sn ? rob[n12].sn - 2'd2 : rob[n12].sn;
						rob[tail0].sn <= 6'h3E;	// <- this needs be done again here
						rob[tail1].sn <= 6'h3F;
						rob[tail1].owner <= Thor2025pkg::NONE;
						rob[tail1].done <= db1.nop;
						rob[tail1].out <= INV;
						rob[tail1].res <= `ZERO;
						rob[tail1].op <= fetchbuf1_instr[0]; 
						rob[tail1].bt <= pt1;
						rob[tail1].agen <= INV;
						rob[tail1].pc <= fetchbuf1_pc;
						rob[tail1].exc <= FLT_NONE;
						rob[tail1].br <= db1.br;
						rob[tail1].bts <= db1.bts;
						rob[tail1].takb <= 1'b0;
						rob[tail1].brtgt <= 'd0;
						lastq1 <= {1'b0,tail1};
						if (!db1.pfx) begin
							atom_mask <= atom_mask >> 4'd6;
							pred_mask <= {8'hFF,pred_mask} >> 4'd8;
							postfix_mask <= 'd0;
						end
						else if (!db0.pfx) begin
							postfix_mask <= 'd0;
						end
						else
							postfix_mask <= {postfix_mask[4:0],1'b1};
						if (postfix_mask[5])
							rob[tail1].exc <= FLT_PFX;
						if (fnIsPred(fetchbuf1_instr[0]))
							pred_mask <= fetchbuf1_instr[0][34:7];
						iqentry_issue_reg[tail1] <= 1'b0;

						// If the first instruction targets a register of the second, then
						// the register for the second instruction should be marked invalid.

						// if the argument is an immediate or not needed, we're done
						if (fnSourceAv(fetchbuf1_instr[0]))
					    rob[tail1].argA_v <= VAL;
						// otherwise, if previous instruction does write to RF ... see if overlap
						else if (db0.Rt != 'd0 && db1.Ra == db0.Rt)
					    rob[tail1].argA_v <= INV;
						// if no overlap, get info from rf_v and rf_source
						else
					    rob[tail1].argA_v <= rf_v [ db1.Ra ];

						// if the argument is an immediate or not needed, we're done
						if (fnSourceBv(fetchbuf1_instr[0]))
					    rob[tail1].argB_v <= VAL;
						// otherwise, if previous instruction does write to RF ... see if overlap
						else if (db0.Rt0 != 'd0 && db1.Rb == db0.Rt)
					    rob[tail1].argB_v <= INV;
						end
						// if no overlap, get info from rf_v and rf_source
						else
					    rob[tail1].argB_v <= rf_v [ db1.Rb ];

						//
						// SOURCE 3 ... 
						//
						// if the argument is an immediate or not needed, we're done
						if (fnSourceCv(fetchbuf1_instr[0]))
					    rob[tail1].argC_v <= VAL;
						// otherwise, previous instruction does write to RF ... see if overlap
						else if (db0.Rt != 'd0 && db1.Rc == db0.Rt)
					    rob[tail1].argC_v <= INV;
						// if no overlap, get info from rf_v and rf_source
						else
					    rob[tail1].argC_v <= rf_v [ db1.Rc ];

						//
						// SOURCE T ... 
						//
						// if the argument is an immediate or not needed, we're done
						if (fnSourceTv(fetchbuf1_instr[0]))
					    rob[tail1].argT_v <= VAL;
						// otherwise, if previous instruction does write to RF ... see if overlap
						else if (db0.Rt != 'd0 && db1.Rt == db0.Rt)
					    rob[tail1].argT_v <= INV;
						// if no overlap, get info from rf_v and rf_source
						else
					    rob[tail1].argT_v <= rf_v [ db1.Rt ];

						//
						// SOURCE P ... 
						//
						// if the argument is an immediate or not needed, we're done
						if (fnSourcePv(fetchbuf1_instr[0]))
					    rob[tail1].argP_v <= VAL;
						// otherwise, previous instruction does write to RF ... see if overlap
						else if (db0.Rt != 'd0 && db1.Rp == db0.Rt)
					    rob[tail1].argP_v <= INV;
						// if no overlap, get info from rf_v and rf_source
						else
					    rob[tail1].argP_v <= rf_v [ db1.Rp ];
					end	
	    	end// ends the "else fetchbuf0 doesn't have a backwards branch" clause
	    end
		endcase

