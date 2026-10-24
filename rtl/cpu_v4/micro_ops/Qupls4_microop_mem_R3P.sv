	Qupls4_pkg::OP_R3BP,Qupls4_pkg::OP_R3WP,Qupls4_pkg::OP_R3TP,Qupls4_pkg::OP_R3OP:
		if (SUPPORT_SIMD) begin
			next_count = 4'd1;
			next_uop[0] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
			next_uop[0].v = VAL;
			next_uop[0].lead = TRUE;
			next_uop[0].num = 5'd0;
			next_uop[0].opcode = instr.opcode;
			next_uop[0].Rd = instr.Rd;
			next_uop[0].Rs1 = instr.Rs1;
			next_uop[0].Rs2 = instr.Rs2;
			next_uop[0].Rs3 = instr.Rs3;
			next_uop[0].Rs4 = instr.Rs4;
			next_uop[0].op3 = instr.op3;
			next_uop[0].ms = instr.ms;
			next_uop[0].func = instr.func;
		end
		else begin
			next_count = 4'd1;
			next_uop[0] = nopi;
		end

