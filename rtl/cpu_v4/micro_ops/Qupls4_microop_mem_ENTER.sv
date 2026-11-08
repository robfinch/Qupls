	Qupls4_pkg::OP_ENTER:
		begin
			// ENTER:
			if (instr.byteno==6'd0) begin
				next_count = 4'd5;
				cap_sz = pg_ext.ip.cap.flags[0] || !SUPPORT_CAPABILITIES ? 2'd2 : pg_ext.ip.cap.flags[2:1];
				st_opcode = pg_ext.ip.cap.flags[0] || !SUPPORT_CAPABILITIES ? OP_STORE : OP_CSTORE;
				// store fp
				next_uop[0] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
				next_uop[0].lead = TRUE;
				next_uop[0].v = VAL;
				next_uop[0].opcode = st_opcode;
				next_uop[0].Rd = fp;
				next_uop[0].Rs1 = ssp;
				next_uop[0].imm = -64'd128 >>> cap_sz;
				next_uop[0].ms = 3'b110;
				next_uop[0].sc = 4'd0;
				// move fp,sp
				next_uop[1] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
				next_uop[1].v = VAL;
				next_uop[1].num = 5'd1;
				next_uop[1].opcode = pg_ext.ip.cap.flags[0] || !SUPPORT_CAPABILITIES ? OP_R3O : OP_CAP;
				next_uop[1].func = pg_ext.ip.cap.flags[0] || !SUPPORT_CAPABILITIES ? FN_MOVE : CAP_CMOVE;
				next_uop[1].Rd = {2'b0,ir[20:14]};
				next_uop[1].Rs1 = {2'b0,ir[13:7]};
				next_uop[1].ms = 3'b110;
				// store lr
				next_uop[2] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
				next_uop[2].v = VAL;
				next_uop[1].num = 5'd2;
				next_uop[2].opcode = st_opcode;
				next_uop[2].Rd = lr;
				next_uop[2].Rs1 = ssp;
				next_uop[2].imm = -64'd96 >>> cap_sz;
				next_uop[2].ms = 3'b110;
				next_uop[2].sc = 4'd0;
				// dec ssp,$frame_size
				next_uop[3] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
				next_uop[3].v = VAL;
				next_uop[3].num = 5'd3;
				next_uop[3].opcode = pg_ext.ip.cap.flags[0] || !SUPPORT_CAPABILITIES ? Qupls4_pkg::OP_ADDI : Qupls4_pkg::OP_CAP;
				next_uop[3].func = Qupls4_pkg::CAP_INCOFFSETI;
				next_uop[3].Rd = ssp;
				next_uop[3].Rs1 = ssp;
				next_uop[3].ms = 3'b110;
				next_uop[3].imm = -64'd128 >>> cap_sz;
				// addi sp,$n
				next_uop[4] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
				next_uop[4].v = VAL;
				next_uop[4].num = 5'd4;
				next_uop[4].opcode = pg_ext.ip.cap.flags[0] || !SUPPORT_CAPABILITIES ? Qupls4_pkg::OP_ADDI : Qupls4_pkg::OP_CAP;
				next_uop[4].func = Qupls4_pkg::CAP_INCOFFSETI;
				next_uop[4].Rd = ir[13:7];
				next_uop[4].Rs1 = ir[13:7];
				next_uop[4].ms = 3'b110;
				next_uop[4].imm = instr.imm;
			end

			// EXIT:
			else begin
				ld_opcode = pg_ext.ip.cap.flags[0] || !SUPPORT_CAPABILITIES ? OP_LOAD : OP_CLOAD;
				cap_sz = pg_ext.ip.cap.flags[0] || !SUPPORT_CAPABILITIES ? 2'd2 : pg_ext.ip.cap.flags[2:1];
				next_count = 4'd6;
				// move sp,fp
				next_uop[0] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
				next_uop[0].lead = TRUE;
				next_uop[0].v = VAL;
				next_uop[0].opcode = pg_ext.ip.cap.flags[0] || !SUPPORT_CAPABILITIES ? OP_R3O : OP_CAP;
				next_uop[0].func = pg_ext.ip.cap.flags[0] || !SUPPORT_CAPABILITIES ? FN_MOVE : CAP_CMOVE;
				next_uop[0].Rd = {2'b0,ir[13:7]};
				next_uop[0].Rs1 = {2'b0,ir[20:14]};
				next_uop[0].ms = 3'b110;
				// load fp
				next_uop[1] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
				next_uop[1].num = 5'd1;
				next_uop[1].v = VAL;
				next_uop[1].opcode = ld_opcode;
				next_uop[1].Rd = {2'b0,ir[20:14]};
				next_uop[1].Rs1 = ssp;
				next_uop[1].imm = 64'd0;
				next_uop[1].ms = 3'b110;
				next_uop[1].sc = 4'd0;
				// load lr
				next_uop[2] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
				next_uop[2].num = 5'd2;
				next_uop[2].v = VAL;
				next_uop[2].opcode = ld_opcode;
				next_uop[2].Rd = {2'b0,ir[27:21]};
				next_uop[2].Rs1 = ssp;
				next_uop[2].imm = 64'd32 >> cap_sz;
				next_uop[2].ms = 3'b110;
				next_uop[2].sc = 4'd0;
				// inc ssp,$frame_size
				next_uop[3] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
				next_uop[3].v = VAL;
				next_uop[3].num = 5'd3;
				next_uop[3].opcode = pg_ext.ip.cap.flags[0] || !SUPPORT_CAPABILITIES ? Qupls4_pkg::OP_ADDI : Qupls4_pkg::OP_CAP;
				next_uop[3].func = Qupls4_pkg::CAP_INCOFFSETI;
				next_uop[3].Rd = ssp;
				next_uop[3].Rs1 = ssp;
				next_uop[3].ms = 3'b110;
				next_uop[3].imm = 64'd128 >> cap_sz;
				// rtd
				next_uop[4] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
				next_uop[4].v = VAL;
				next_uop[4].num = 5'd4;
				next_uop[4].opcode = Qupls4_pkg::OP_CAP;
				next_uop[4].func = pg_ext.ip.cap.flags[0] || !SUPPORT_CAPABILITIES ? 7'd0 : 7'd1;
				next_uop[4].Rd = ir[13:7];
				next_uop[4].Rs1 = ir[20:14];					// link register
				next_uop[4].Rs2 = ir[27:21];
				next_uop[4].ms = 3'b100;
				// addi sp,$n
				next_uop[5] = {$bits(Qupls4_pkg::micro_op_t){1'b0}};
				next_uop[5].v = VAL;
				next_uop[5].num = 5'd5;
				if (instr.has_immc) begin
					next_uop[5].opcode = pg_ext.ip.cap.flags[0] || !SUPPORT_CAPABILITIES ? Qupls4_pkg::OP_ADDI : Qupls4_pkg::OP_CAP;
					next_uop[5].func = Qupls4_pkg::CAP_INCOFFSETI;
					next_uop[5].Rd = ir[13:7];
					next_uop[5].Rs1 = ir[13:7];
					next_uop[5].ms = 3'b110;
					next_uop[5].imm = instr.imm;
				end
				else begin
					next_uop[5].opcode = pg_ext.ip.cap.flags[0] || !SUPPORT_CAPABILITIES ? Qupls4_pkg::OP_R3O : Qupls4_pkg::OP_CAP;
					next_uop[5].func = pg_ext.ip.cap.flags[0] || !SUPPORT_CAPABILITIES ? Qupls4_pkg::FN_ADD : Qupls4_pkg::CAP_INCOFFSET;
					next_uop[5].Rd = ir[13:7];
					next_uop[5].Rs1 = ir[13:7];
					next_uop[5].Rs2 = ir[34:28];
					next_uop[5].ms = 3'b100;
				end
			end
		end
