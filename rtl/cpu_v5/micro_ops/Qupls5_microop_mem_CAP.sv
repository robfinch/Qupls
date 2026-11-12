	Qupls5_pkg::OP_CJSR:
		begin
			next_count = 4'd1;
			next_uop[0] = instr;
			next_uop[0].v = VAL;
			next_uop[0].lead = TRUE;
			next_uop[0].num = 5'd0;
		end
	Qupls5_pkg::OP_CAP:
		if (SUPPORT_CAPABILITIES) begin
			next_uop[0] = instr;
			case(instr.func)
			Qupls5_pkg::CAP_SWAP,
			Qupls5_pkg::CAP_SEAL,
			Qupls5_pkg::CAP_SEALENTRY,
			Qupls5_pkg::CAP_UNSEAL,
			Qupls5_pkg::CAP_RET,
			Qupls5_pkg::CAP_MOVE,
			Qupls5_pkg::CAP_BUILDCAP,
			Qupls5_pkg::CAP_COPYTYPE,
			Qupls5_pkg::CAP_INCOFFSETI,
			Qupls5_pkg::CAP_INVOKE:
				begin
					next_count = 4'd1;
					next_uop[0] = instr;
					next_uop[0].v = VAL;
					next_uop[0].lead = TRUE;
				end
			Qupls5_pkg::CAP_CLEARTAG:
				begin
					// Do the test into a cap register.
					next_count = 4'd1;
					next_uop[0] = instr;
					next_uop[0].v = VAL;
					next_uop[0].lead = TRUE;
				end
			Qupls5_pkg::CAP_ROUNDLEN,
			Qupls5_pkg::CAP_ALGNMASK,
			Qupls5_pkg::CAP_COMPARE,
			Qupls5_pkg::CAP_SETEQUALSEXACT,
			Qupls5_pkg::CAP_TESTSUBSET,
			Qupls5_pkg::CAP_GETADDR,
			Qupls5_pkg::CAP_GETBASE,
			Qupls5_pkg::CAP_GETLENGTH,
			Qupls5_pkg::CAP_GETOFFSET,
			Qupls5_pkg::CAP_GETPERMS,
			Qupls5_pkg::CAP_GETSEALED,
			Qupls5_pkg::CAP_GETTAG,
			Qupls5_pkg::CAP_GETTOP,
			Qupls5_pkg::CAP_GETTYPE,
			Qupls5_pkg::CAP_GETFLAGS,
			Qupls5_pkg::CAP_LOADTAGS:
				begin
					// Do the test into a cap register.
					next_count = 4'd2;
					next_uop[0] = instr;
					next_uop[0].v = VAL;
					next_uop[0].lead = TRUE;
					next_uop[0].Rd = mot0_reg;
					// Transfer cap register to GPR.
					next_uop[1] = {$bits(Qupls5_pkg::micro_op_t){1'b0}};
					next_uop[1].v = VAL;
					next_uop[1].lead = FALSE;
					next_uop[1].num = 5'd1;
					next_uop[1].opcode = Qupls5_pkg::OP_R3O;
					next_uop[1].func = Qupls5_pkg::FN_MOVE;
					next_uop[1].Rd = instr.Rd;
					next_uop[1].Rs1 = mot0_reg;
					next_uop[1].vn = 4'b0010;			// move from cap reg
					next_uop[1].op3 = 3'd6;				// move low order X to R
					next_uop[1].ms = instr.ms;
				end
			Qupls5_pkg::CAP_SETFLAGS,
			Qupls5_pkg::CAP_SETADDR,
			Qupls5_pkg::CAP_SETOFFSET,
			Qupls5_pkg::CAP_ANDPERM,
			Qupls5_pkg::CAP_INCOFFSET:
				begin
					// Do the test into a cap register.
					next_count = 4'd1;
					next_uop[0] = instr;
					next_uop[0].v = VAL;
					next_uop[0].lead = TRUE;
				end
			Qupls5_pkg::CAP_SETBOUNDS:
				begin
					// Do the test into a cap register.
					next_count = 4'd1;
					next_uop[0] = instr;
					next_uop[0].v = VAL;
					next_uop[0].lead = TRUE;
				end
			default:
				begin
					next_count = 4'd1;
					next_uop[0] = instr;
					next_uop[0].v = VAL;
					next_uop[0].lead = TRUE;
					next_uop[0].num = 5'd0;
				end
			endcase
		end
		else begin
			next_count = 4'd1;
			next_uop[0] = nopi;
		end

