	Qupls4_pkg::OP_CAP:
		if (SUPPORT_CAPABILITIES) begin
			next_uop[0] = instr;
			case(instr.func)
			Qupls4_pkg::CAP_SETEQUALSEXACT,
			Qupls4_pkg::CAP_TESTSUBSET:
				begin
					// Do the test into a cap register.
					next_count = 4'd2;
					next_uop[0].v = VAL;
					next_uop[0].lead = TRUE;
					next_uop[0].num = 5'd0;
					next_uop[0].opcode = instr.opcode;
					next_uop[0].Rd = mot0_reg;
					next_uop[0].Rs1 = instr.Rs1;
					next_uop[0].Rs2 = instr.Rs2;
					next_uop[0].op3 = instr.op3;
					next_uop[0].ms = instr.ms;
					next_uop[0].func = instr.func;
					// Transfer cap register to GPR.
					next_uop[1] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
					next_uop[1].v = VAL;
					next_uop[1].lead = FALSE;
					next_uop[1].num = 5'd1;
					next_uop[1].opcode = instr.opcode;
					next_uop[1].Rd = instr.Rd;
					next_uop[1].Rs1 = mot0_reg;
					next_uop[1].op3 = instr.op3;
					next_uop[1].ms = instr.ms;
					next_uop[1].func = Qupls4_pkg::CAP_GETOFFSET;
				end
			default:
				begin
					next_count = 4'd1;
					next_uop[0].v = VAL;
					next_uop[0].lead = TRUE;
					next_uop[0].num = 5'd0;
					next_uop[0].opcode = instr.opcode;
					next_uop[0].Rd = mot0_reg;
					next_uop[0].Rs1 = instr.Rs1;
					next_uop[0].Rs2 = instr.Rs2;
					next_uop[0].Rs3 = instr.Rs3;
					next_uop[0].op3 = instr.op3;
					next_uop[0].ms = instr.ms;
					next_uop[0].func = instr.func;
				end
			endcase
		end
		else begin
			next_count = 4'd1;
			next_uop[0] = nopi;
		end

