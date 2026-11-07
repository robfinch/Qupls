	Qupls4_pkg::OP_CJSR:
		begin
			next_count = 4'd1;
			next_uop[0].v = VAL;
			next_uop[0].lead = TRUE;
			next_uop[0].num = 5'd0;
			next_uop[0].opcode = instr.opcode;
			next_uop[0].func = instr.func;
			next_uop[0].Rd = instr.Rd;
			next_uop[0].vn = 4'b0000;
			next_uop[0].op3 = instr.op3;
			next_uop[0].ms = instr.ms;
		end
	Qupls4_pkg::OP_CAP:
		if (SUPPORT_CAPABILITIES) begin
			next_uop[0] = instr;
			case(instr.func)
			Qupls4_pkg::CAP_SWAP,
			Qupls4_pkg::CAP_SEAL,
			Qupls4_pkg::CAP_SEALENTRY,
			Qupls4_pkg::CAP_UNSEAL,
			Qupls4_pkg::CAP_RET,
			Qupls4_pkg::CAP_MOVE,
			Qupls4_pkg::CAP_BUILDCAP,
			Qupls4_pkg::CAP_COPYTYPE,
			Qupls4_pkg::CAP_INCOFFSETI,
			Qupls4_pkg::CAP_INVOKE:
				begin
					next_count = 4'd1;
					next_uop[0].v = VAL;
					next_uop[0].lead = TRUE;
					next_uop[0].num = 5'd0;
					next_uop[0].opcode = instr.opcode;
					next_uop[0].func = instr.func;
					next_uop[0].Rd = instr.Rd;
					next_uop[0].Rs1 = instr.Rs1;
					next_uop[0].Rs2 = instr.Rs2;
					next_uop[0].vn = 4'b0000;
					next_uop[0].op3 = instr.op3;
					next_uop[0].ms = instr.ms;
				end
			Qupls4_pkg::CAP_CLEARTAG:
				begin
					// Do the test into a cap register.
					next_count = 4'd1;
					next_uop[0].v = VAL;
					next_uop[0].lead = TRUE;
					next_uop[0].num = 5'd0;
					next_uop[0].opcode = instr.opcode;
					next_uop[0].func = instr.func;
					next_uop[0].Rd = instr.Rd;
					next_uop[0].Rs1 = instr.Rs1;
					next_uop[0].vn = 4'b0000;
					next_uop[0].op3 = instr.op3;
					next_uop[0].ms = instr.ms;
				end
			Qupls4_pkg::CAP_ROUNDLEN,
			Qupls4_pkg::CAP_ALGNMASK,
			Qupls4_pkg::CAP_COMPARE,
			Qupls4_pkg::CAP_SETEQUALSEXACT,
			Qupls4_pkg::CAP_TESTSUBSET,
			Qupls4_pkg::CAP_GETADDR,
			Qupls4_pkg::CAP_GETBASE,
			Qupls4_pkg::CAP_GETLENGTH,
			Qupls4_pkg::CAP_GETOFFSET,
			Qupls4_pkg::CAP_GETPERMS,
			Qupls4_pkg::CAP_GETSEALED,
			Qupls4_pkg::CAP_GETTAG,
			Qupls4_pkg::CAP_GETTOP,
			Qupls4_pkg::CAP_GETTYPE,
			Qupls4_pkg::CAP_GETFLAGS,
			Qupls4_pkg::CAP_LOADTAGS:
				begin
					// Do the test into a cap register.
					next_count = 4'd2;
					next_uop[0].v = VAL;
					next_uop[0].lead = TRUE;
					next_uop[0].num = 5'd0;
					next_uop[0].opcode = instr.opcode;
					next_uop[0].func = instr.func;
					next_uop[0].Rd = mot0_reg;
					next_uop[0].Rs1 = instr.Rs1;
					next_uop[0].Rs2 = instr.Rs2;
					next_uop[0].op3 = instr.op3;
					next_uop[0].ms = instr.ms;
					// Transfer cap register to GPR.
					next_uop[1] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
					next_uop[1].v = VAL;
					next_uop[1].lead = FALSE;
					next_uop[1].num = 5'd1;
					next_uop[1].opcode = Qupls4_pkg::OP_R3O;
					next_uop[1].func = Qupls4_pkg::FN_MOVE;
					next_uop[1].Rd = instr.Rd;
					next_uop[1].Rs1 = mot0_reg;
					next_uop[1].vn = 4'b0010;			// move from cap reg
					next_uop[1].op3 = 3'd6;				// move low order X to R
					next_uop[1].ms = instr.ms;
				end
			Qupls4_pkg::CAP_SETFLAGS,
			Qupls4_pkg::CAP_SETADDR,
			Qupls4_pkg::CAP_SETOFFSET,
			Qupls4_pkg::CAP_ANDPERM,
			Qupls4_pkg::CAP_INCOFFSET:
				begin
					// Do the test into a cap register.
					next_count = 4'd1;
					next_uop[0].v = VAL;
					next_uop[0].lead = TRUE;
					next_uop[0].num = 5'd0;
					next_uop[0].opcode = instr.opcode;
					next_uop[0].func = instr.func;
					next_uop[0].Rd = instr.Rd;
					next_uop[0].Rs1 = instr.Rs1;
					next_uop[0].Rs2 = instr.Rs2;
					next_uop[0].vn = 4'b0100;			// read from R reg
					next_uop[0].op3 = instr.op3;
					next_uop[0].ms = instr.ms;
				end
			Qupls4_pkg::CAP_SETBOUNDS:
				begin
					// Do the test into a cap register.
					next_count = 4'd1;
					next_uop[0].v = VAL;
					next_uop[0].lead = TRUE;
					next_uop[0].num = 5'd0;
					next_uop[0].opcode = instr.opcode;
					next_uop[0].func = instr.func;
					next_uop[0].Rd = instr.Rd;
					next_uop[0].Rs1 = instr.Rs1;
					next_uop[0].Rs2 = instr.Rs2;
					next_uop[0].vn = 4'b1100;			// read from R reg
					next_uop[0].op3 = instr.op3;
					next_uop[0].ms = instr.ms;
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

