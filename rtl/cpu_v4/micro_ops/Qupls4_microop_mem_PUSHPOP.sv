	Qupls4_pkg::OP_PUSH:
		begin
			next_count = {1'b0,ir[47:45]} + 2'd1;
			case(ir[47:45])
			4'd1:	
				begin
					next_uop[0] = push1;
					next_uop[0].lead = TRUE;
					next_uop[1] = decsp8;
					next_uop[1].num = 5'd1;
				end
			4'd2:
				begin
					next_uop[0] = push1;
					next_uop[0].lead = TRUE;
					next_uop[1] = push2;
					next_uop[1].num = 5'd1;
					next_uop[2] = decsp16;
					next_uop[2].num = 5'd2;
				end
			4'd3:
				begin
					next_uop[0] = push1;
					next_uop[0].lead = TRUE;
					next_uop[1] = push2;
					next_uop[1].num = 5'd1;
					next_uop[2] = push3;
					next_uop[2].num = 5'd2;
					next_uop[3] = decsp24;
					next_uop[3].num = 5'd3;
				end
			4'd4:
				begin
					next_uop[0] = push1;
					next_uop[0].lead = TRUE;
					next_uop[1] = push2;
					next_uop[1].num = 5'd1;
					next_uop[2] = push3;
					next_uop[2].num = 5'd2;
					next_uop[3] = push4;
					next_uop[3].num = 5'd3;
					next_uop[4] = decsp32;
					next_uop[4].num = 5'd4;
				end
			default:	
				begin
					next_count = 4'd1;
					next_uop[0] = nopi;
				end
			endcase
		end

	Qupls4_pkg::OP_POP:
		begin
			next_count = {1'b0,ir[47:45]} + 2'd1;
			case(ir[47:45])
			4'd1:	
				begin
					next_uop[0] = pop1;
					next_uop[0].lead = TRUE;
					next_uop[1] = incsp8;
					next_uop[1].num = 5'd1;
				end
			4'd2:
				begin
					next_uop[0] = pop1;
					next_uop[0].lead = TRUE;
					next_uop[1] = pop2;
					next_uop[1].num = 5'd1;
					next_uop[2] = incsp16;
					next_uop[2].num = 5'd2;
				end
			4'd3:
				begin
					next_uop[0] = pop1;
					next_uop[0].lead = TRUE;
					next_uop[1] = pop2;
					next_uop[1].num = 5'd1;
					next_uop[2] = pop3;
					next_uop[2].num = 5'd2;
					next_uop[3] = incsp24;
					next_uop[3].num = 5'd3;
				end
			4'd4:
				begin
					next_uop[0] = pop1;
					next_uop[0].lead = TRUE;
					next_uop[1] = pop2;
					next_uop[1].num = 5'd1;
					next_uop[2] = pop3;
					next_uop[2].num = 5'd2;
					next_uop[3] = pop4;
					next_uop[3].num = 5'd3;
					next_uop[4] = incsp32;
					next_uop[4].num = 5'd4;
				end
			default:	
				begin
					next_count = 4'd1;
					next_uop[0] = nopi;
				end
			endcase
		end
