	Qupls4_pkg::OP_FLTPH,Qupls4_pkg::OP_FLTPS,Qupls4_pkg::OP_FLTPD,Qupls4_pkg::OP_FLTPQ:
		if (SUPPORT_FLOAT&SUPPORT_SIMD) begin
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
			next_uop[0].op3 = instr.op3;
			next_uop[0].ms = instr.ms;
			next_uop[0].func = instr.func;
		end
		// Should really exception here.
		else begin
			next_count = 4'd1;
			next_uop[0] = nopi;
		end
