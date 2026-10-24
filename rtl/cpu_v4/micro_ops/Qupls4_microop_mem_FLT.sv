	Qupls4_pkg::OP_FLTH,Qupls4_pkg::OP_FLTS,Qupls4_pkg::OP_FLTD,Qupls4_pkg::OP_FLTQ:
		if (SUPPORT_FLOAT) begin
			// Add postfix for second write port if status recording is set.
			if (instr.func[6]) begin
				next_count = 4'd2;
				next_uop[0] = uop0;
				// Select value 0 for all source regs.
				next_uop[1] = uop1;
				next_uop[1].ms = 3'b111;
				next_uop[1].Rs1 = 9'd00;
				next_uop[1].Rs2 = 9'd00;
				next_uop[1].Rs3 = 9'd00;
				next_uop[1].Rd = fp_status_reg;		// FP status reg
				next_uop[1].opcode = Qupls4_pkg::OP_REXT;
			end
			else begin
				next_count = 4'd1;
				next_uop[0] = uop0;
			end
			case(instr.func[5:0])
			FLT_DIV:
				begin
					next_count = 4'd13;
					next_uop[0].lead = TRUE;
					next_uop[0].num = 5'd0;
					next_uop[0].opcode = instr.opcode;
					next_uop[0].Rd = instr.Rd;					
					next_uop[0].Rs1 = instr.Rs1;					
					next_uop[0].Rs2 = instr.Rs2;	
					next_uop[0].func = FLT_RCPA;

					next_uop[1].num = 5'd1;
					next_uop[1].opcode = instr.opcode;
					next_uop[1].Rd = instr.Rs2;					
					next_uop[1].Rs1 = instr.Rs2;					
					next_uop[1].Rs2 = zero_reg;	
					next_uop[1].func = FLT_NEG;

					next_uop[2].num = 5'd2;
					next_uop[2].opcode = instr.opcode;
					next_uop[2].Rd = mot0_reg;
					next_uop[2].Rs1 = 8'd2;			// 2.0
					next_uop[2].Rs2 = zero_reg;
					next_uop[2].func = FLT_CONST;
					
					// NR Iter #1
					// FMA tmp2,Rd,Rs2,tmp1
					next_uop[3].num = 5'd3;
					next_uop[3].opcode = instr.opcode;
					next_uop[3].Rd = mot1_reg;
					next_uop[3].Rs1 = instr.Rd;
					next_uop[3].Rs2 = instr.Rs2;
					next_uop[3].Rs3 = mot0_reg;
					next_uop[3].func = FLT_FMA;

					next_uop[4].num = 5'd4;
					next_uop[4].opcode = instr.opcode;
					next_uop[4].Rd = instr.Rd;
					next_uop[4].Rs1 = instr.Rd;
					next_uop[4].Rs2 = mot1_reg;
					next_uop[4].Rs3 = zero_reg;
					next_uop[4].func = FLT_FMA;

					// NR Iter #2
					next_uop[5].num = 5'd5;
					next_uop[5].opcode = instr.opcode;
					next_uop[5].Rd = mot1_reg;
					next_uop[5].Rs1 = instr.Rd;
					next_uop[5].Rs2 = instr.Rs2;
					next_uop[5].Rs3 = mot0_reg;
					next_uop[5].func = FLT_FMA;

					next_uop[6].num = 5'd6;
					next_uop[6].opcode = instr.opcode;
					next_uop[6].Rd = instr.Rd;
					next_uop[6].Rs1 = instr.Rd;
					next_uop[6].Rs2 = mot1_reg;
					next_uop[6].Rs3 = zero_reg;
					next_uop[6].func = FLT_FMA;

					// NR Iter #3
					next_uop[7].num = 5'd7;
					next_uop[7].opcode = instr.opcode;
					next_uop[7].Rd = mot1_reg;
					next_uop[7].Rs1 = instr.Rd;
					next_uop[7].Rs2 = instr.Rs2;
					next_uop[7].Rs3 = mot0_reg;
					next_uop[7].func = FLT_FMA;

					next_uop[8].num = 5'd8;
					next_uop[8].opcode = instr.opcode;
					next_uop[8].Rd = instr.Rd;
					next_uop[8].Rs1 = instr.Rd;
					next_uop[8].Rs2 = mot1_reg;
					next_uop[8].Rs3 = zero_reg;
					next_uop[8].func = FLT_FMA;

					next_uop[9].num = 5'd9;
					next_uop[9].opcode = instr.opcode;
					next_uop[9].Rd = instr.Rs2;					
					next_uop[9].Rs1 = instr.Rs2;					
					next_uop[9].Rs2 = zero_reg;	
					next_uop[9].func = FLT_NEG;

					next_uop[10].num = 5'd10;
					next_uop[10].opcode = instr.opcode;
					next_uop[10].Rd = instr.Rd;
					next_uop[10].Rs1 = instr.Rd;
					next_uop[10].Rs2 = instr.Rs2;
					next_uop[10].Rs3 = zero_reg;
					next_uop[10].func = FLT_FMA;

				end
			FLT_RSQRTA:
				case(ir.opcode)
				OP_FLTD:
					begin
						// t2 = i>>1;
						next_count = 4'd3;
						next_uop[0].lead = TRUE;
						next_uop[0].num = 5'd0;
						next_uop[0].opcode = OP_R3O;
						next_uop[0].func = FN_LSR;
						next_uop[0].Rd = mot2_reg;
						next_uop[0].Rs1 = instr.Rs1;
						next_uop[0].Rs2 = 7'd1;
						next_uop[0].ms = 3'b010;
						
						// t0 = lomont magic number
						next_uop[1].num = 5'd1;
						next_uop[1].opcode = OP_FLTD;
						next_uop[1].func = FLT_CONST;
						next_uop[1].Rd = mot0_reg;
						next_uop[1].Rs1 = 7'd4;			// Lomont reciprocal square root magic number
						next_uop[1].ms = 3'b001;
						
						// y = MAGIC * 1.0 - t2
						next_uop[2].num = 5'd2;
						next_uop[2].opcode = OP_FLTD;
						next_uop[2].func = FLT_FMS;
						next_uop[2].Rd = instr.Rd;
						next_uop[2].Rs1 = mot0_reg;	
						next_uop[2].Rs2 = 7'b0011000;	// +1.0
						next_uop[2].Rs3 = mot2_reg;
						next_uop[2].ms = 3'b010;
					end
				endcase
			FLT_RM:
				begin
					next_count = 4'd2;
					next_uop[0] = uop0;
					// Select value 0 for all source regs.
					next_uop[1] = uop1;
					next_uop[1].ms = 3'b111;
					next_uop[1].Rs1 = 9'd00;
					next_uop[1].Rs2 = 9'd00;
					next_uop[1].Rs3 = 9'd00;
					next_uop[1].Rd = 9'd000;
					next_uop[1].opcode = Qupls4_pkg::OP_FENCE;
					next_uop[1].imm = 8'h22;	// FP sync
				end
			FLT_POLY:
				begin
					next_count = ((uop0.Rs3 & 5'd7) +2'd1);
					next_uop[0].lead = 1'b1;
					next_uop[0].num = 5'd0;
					next_uop[0].opcode = uop0.Rs3[6] ? Qupls4_pkg::OP_NOP : Qupls4_pkg::OP_R3O;
					next_uop[0].func = FN_OR;
					next_uop[0].Rd = uop0.Rd;
					next_uop[0].Rs1 = uop0.Rs2;	// a0
					next_uop[0].Rs2 = 7'd0;
					next_uop[0].Rs3 = 7'd0;
					next_uop[0].op3 = 3'd1;			// OR_OR
					next_uop[0].ms = 3'd6;			// Rs2,Rs3 are constants
					
					next_uop[1].num = 5'd1;
					next_uop[1].opcode = uop0.opcode;
					next_uop[1].func = FLT_FMA;
					next_uop[1].Rd = uop0.Rd;
					next_uop[1].Rs1 = uop0.Rd;
					next_uop[1].Rs2 = uop0.Rs1;
					next_uop[1].Rs3 = uop0.Rs2+2'd1;	// a1
					next_uop[1].ms = 3'd0;
					next_uop[1].rmd = uop0.rmd;

					next_uop[2].num = 5'd2;
					next_uop[2].opcode = uop0.opcode;
					next_uop[2].func = FLT_FMA;
					next_uop[2].Rd = uop0.Rd;
					next_uop[2].Rs1 = uop0.Rd;
					next_uop[2].Rs2 = uop0.Rs1;
					next_uop[2].Rs3 = uop0.Rs2+2'd2;	// a2
					next_uop[2].ms = 3'd0;
					next_uop[2].rmd = uop0.rmd;

					next_uop[3].num = 5'd3;
					next_uop[3].opcode = uop0.opcode;
					next_uop[3].func = FLT_FMA;
					next_uop[3].Rd = uop0.Rd;
					next_uop[3].Rs1 = uop0.Rd;
					next_uop[3].Rs2 = uop0.Rs1;
					next_uop[3].Rs3 = uop0.Rs2+2'd3;	// a3
					next_uop[3].ms = 3'd0;
					next_uop[3].rmd = uop0.rmd;

					next_uop[4].num = 5'd4;
					next_uop[4].opcode = uop0.opcode;
					next_uop[4].func = FLT_FMA;
					next_uop[4].Rd = uop0.Rd;
					next_uop[4].Rs1 = uop0.Rd;
					next_uop[4].Rs2 = uop0.Rs1;
					next_uop[4].Rs3 = uop0.Rs2+3'd4;	// a3
					next_uop[4].ms = 3'd0;
					next_uop[4].rmd = uop0.rmd;

					next_uop[5].num = 5'd5;
					next_uop[5].opcode = uop0.opcode;
					next_uop[5].func = FLT_FMA;
					next_uop[5].Rd = uop0.Rd;
					next_uop[5].Rs1 = uop0.Rd;
					next_uop[5].Rs2 = uop0.Rs1;
					next_uop[5].Rs3 = uop0.Rs2+3'd5;	// a3
					next_uop[5].ms = 3'd0;
					next_uop[5].rmd = uop0.rmd;

					next_uop[6].num = 5'd6;
					next_uop[6].opcode = uop0.opcode;
					next_uop[6].func = FLT_FMA;
					next_uop[6].Rd = uop0.Rd;
					next_uop[6].Rs1 = uop0.Rd;
					next_uop[6].Rs2 = uop0.Rs1;
					next_uop[6].Rs3 = uop0.Rs2+3'd6;	// a3
					next_uop[6].ms = 3'd0;
					next_uop[6].rmd = uop0.rmd;

					next_uop[7].num = 5'd7;
					next_uop[7].opcode = uop0.opcode;
					next_uop[7].func = FLT_FMA;
					next_uop[7].Rd = uop0.Rd;
					next_uop[7].Rs1 = uop0.Rd;
					next_uop[7].Rs2 = uop0.Rs1;
					next_uop[7].Rs3 = uop0.Rs2+3'd7;	// a3
					next_uop[7].ms = 3'd0;
					next_uop[7].rmd = uop0.rmd;

					next_uop[8].num = 5'd8;
					next_uop[8].opcode = uop0.opcode;
					next_uop[8].func = FLT_FMA;
					next_uop[8].Rd = uop0.Rd;
					next_uop[8].Rs1 = uop0.Rd;
					next_uop[8].Rs2 = uop0.Rs1;
					next_uop[8].Rs3 = uop0.Rs2+4'd8;	// a3
					next_uop[8].ms = 3'd0;
					next_uop[8].rmd = uop0.rmd;
				end
			endcase
			/*
			case(ir.op4)
			FOP4_FMUL:
				// Tranlate FMUL Rd,Fs1,Fs2 to FMA Fd,Rs1,Fs2,F0.
				begin
					next_uop[0] = {1'b1,1'b0,3'd2,3'd0,8'b10101010,4'd0,ir};
					next_uop[0].ins[31]=1'b1;
					next_uop[0].ins[30]=1'b0;
					next_uop[0].ins[29:27] = ir.fpurm.rm;
					next_uop[0].ins.fma.Rs3 = 5'd0;
					if (ir[16]) begin
						next_count = 3'd2;
						next_uop[0].next_count = 3'd2;
						next_uop[1] = {1'b1,1'b0,3'd0,3'd1,8'b10101001,4'd0,fcmp};
					end
					else begin
						next_count = 3'd1;
						next_uop[0].next_count = 3'd1;
					end	
				end
			FOP4_FADD,FOP4_FSUB:
				// Translate FADD Fd,Fs1,Fs2 into FMA Fd,Fs1,r47,Fs2
				// Translate FSUB Fd,Fs1,Fs2 into FMS Fd,Fs1,r47,Fs2
				begin
					next_uop[0] = {1'b1,1'b0,3'd0,3'd0,6'd0,2'd1,4'd0,floadi1};	// Load 1.0 into r47
					next_uop[0].xRd = 2'd1;	// r47 = 32+15
					next_uop[1] = {1'b1,1'b0,3'd0,3'd1,8'b10101010,4'd0,ir};
					next_uop[1].ins[31]=1'b1;
					next_uop[1].ins[30]=ir.op4==FOP4_FSUB;
					next_uop[1].ins[29:27] = ir.fpurm.rm;
					next_uop[1].ins.fma.Rs3 = ir.Rs2;
					next_uop[1].ins.fma.Rs2 = 5'd15;
					next_uop[1].xRs2 = 2'd1;
					if (ir[16]) begin
						next_count = 3'd3;
						next_uop[0].next_count = 3'd3;
						next_uop[2] = {1'b1,1'b0,3'd0,3'd2,8'b10101001,4'd0,fcmp};
					end
					else begin
						next_count = 3'd2;
						next_uop[0].next_count = 3'd2;
						next_uop[1].num = 3'd1;
					end	
				end
			default:
				next_uop[0] = {1'b1,1'b0,3'd1,3'd0,8'b10101010,4'd0,ir};
			endcase
			// ToDo: exceptions on Rd,Rs1,Rs2
			//next_uop[0].exc = fnRegExc(om, {2'b10,ir.Rs1}) | fnRegExc(om, {2'b10,ir.Rd});
			*/
		end
		else begin
			if (insert_boi) begin
				next_count = 4'd2;
				next_uop[0] = uop_boi;
				next_uop[1] = uop1;
			end
			else begin
				next_count = 4'd1;
				next_uop[0] = uop0;
			end
		end
