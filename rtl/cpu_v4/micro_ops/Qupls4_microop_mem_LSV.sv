	Qupls4_pkg::OP_LDV,Qupls4_pkg::OP_STV:
		if (SUPPORT_VECTOR) begin
			next_uop[0].imm2[5:0] = vlen;
			next_uop[1].imm2[5:0] = vlen;
			next_uop[2].imm2[5:0] = vlen;
			next_uop[3].imm2[5:0] = vlen;
			next_uop[4].imm2[5:0] = vlen;
			next_uop[5].imm2[5:0] = vlen;
			next_uop[6].imm2[5:0] = vlen;
			next_uop[7].imm2[5:0] = vlen;
			case(velsz1)
			4'd1:
				case(vlen3)
				3'd1:	ble = 8'b00000001;
				3'd2:	ble = 8'b00000011;
				3'd3:	ble = 8'b00000111;
				3'd4:	ble = 8'b00001111;
				3'd5:	ble = 8'b00011111;
				3'd6:	ble = 8'b00111111;
				3'd7:	ble = 8'b01111111;
				3'd0:	ble = 8'b11111111;
				endcase
			4'd2:
				case(vlen3[2:1])
				2'd1:	ble = 8'b00000011;
				2'd2:	ble = 8'b00001111;
				2'd3:	ble = 8'b00111111;
				2'd0:	ble = 8'b11111111;
				endcase
			4'd4:	ble = vlen3[2] ? 8'b00001111: 8'b11111111;
			4'd8:	ble = 8'b11111111;
			endcase
			case({VREGS > 4,vlen1})
			5'd0:	next_uop[0].ble = 8'b00000000;
			5'd1:
				begin
			next_count = 4'd1;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[0].ble = ble;
			next_uop[0].byteno = 6'd0;
				end
			5'd2:
				begin
			next_count = 4'd2;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[0].ble = 8'b11111111;
			next_uop[0].byteno = 6'd0;
			next_uop[0].imm2[5:0] = vlen;
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rd = vls.Rd + 2'd1;
			next_uop[1].imm = vls.imm + 6'd8;
			next_uop[1].ble = ble;
			next_uop[1].byteno = 6'd8;
				end
			5'd3:
				begin
			next_count = 4'd3;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[0].ble = 8'b11111111;
			next_uop[0].byteno = 6'd0;
			next_uop[0].imm2[5:0] = vlen;
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rd = vls.Rd + 2'd1;
			next_uop[1].imm = vls.imm + 6'd8;
			next_uop[1].ble = 8'b11111111;
			next_uop[1].byteno = 6'd8;
			next_uop[2] = vls;
			next_uop[2].num = 5'd2;
			next_uop[2].Rd = vls.Rd + 2'd2;
			next_uop[2].imm = vls.imm + 6'd16;
			next_uop[2].ble = ble;
			next_uop[2].byteno = 6'd16;
				end
			5'd4:
				begin
			next_count = 4'd4;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[0].ble = 8'b11111111;
			next_uop[0].byteno = 6'd0;
			next_uop[0].imm2[5:0] = vlen;
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rd = vls.Rd + 2'd1;
			next_uop[1].imm = vls.imm + 6'd8;
			next_uop[1].ble = 8'b11111111;
			next_uop[1].byteno = 6'd8;
			next_uop[2] = vls;
			next_uop[2].num = 5'd2;
			next_uop[2].Rd = vls.Rd + 2'd2;
			next_uop[2].imm = vls.imm + 6'd16;
			next_uop[2].ble = 8'b11111111;
			next_uop[2].byteno = 6'd16;
			next_uop[3] = vls;
			next_uop[3].num = 5'd3;
			next_uop[3].Rd = vls.Rd + 2'd3;
			next_uop[3].imm = vls.imm + 6'd24;
			next_uop[3].ble = ble;
			next_uop[3].byteno = 6'd24;
				end
			5'd21:
				begin
			next_count = 4'd5;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[0].ble = 8'b11111111;
			next_uop[0].byteno = 6'd0;
			next_uop[0].imm2[5:0] = vlen;
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rd = vls.Rd + 2'd1;
			next_uop[1].imm = vls.imm + 6'd8;
			next_uop[1].ble = 8'b11111111;
			next_uop[1].byteno = 6'd8;
			next_uop[2] = vls;
			next_uop[2].num = 5'd2;
			next_uop[2].Rd = vls.Rd + 2'd2;
			next_uop[2].imm = vls.imm + 6'd16;
			next_uop[2].ble = 8'b11111111;
			next_uop[2].byteno = 6'd16;
			next_uop[3] = vls;
			next_uop[3].num = 5'd3;
			next_uop[3].Rd = vls.Rd + 2'd3;
			next_uop[3].imm = vls.imm + 6'd24;
			next_uop[3].ble = 8'b11111111;
			next_uop[3].byteno = 6'd24;
			next_uop[4] = vls;
			next_uop[4].num = 5'd4;
			next_uop[4].Rd = vls.Rd + 3'd4;
			next_uop[4].imm = vls.imm + 6'd32;
			next_uop[4].ble = ble;
			next_uop[4].byteno = 6'd32;
				end
			5'd22:
				begin
			next_count = 4'd6;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[0].ble = 8'b11111111;
			next_uop[0].byteno = 6'd0;
			next_uop[0].imm2[5:0] = vlen;
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rd = vls.Rd + 2'd1;
			next_uop[1].imm = vls.imm + 6'd8;
			next_uop[1].ble = 8'b11111111;
			next_uop[1].byteno = 6'd8;
			next_uop[2] = vls;
			next_uop[2].num = 5'd2;
			next_uop[2].Rd = vls.Rd + 2'd2;
			next_uop[2].imm = vls.imm + 6'd16;
			next_uop[2].ble = 8'b11111111;
			next_uop[2].byteno = 6'd16;
			next_uop[3] = vls;
			next_uop[3].num = 5'd3;
			next_uop[3].Rd = vls.Rd + 2'd3;
			next_uop[3].imm = vls.imm + 6'd24;
			next_uop[3].ble = 8'b11111111;
			next_uop[3].byteno = 6'd24;
			next_uop[4] = vls;
			next_uop[4].num = 5'd4;
			next_uop[4].Rd = vls.Rd + 3'd4;
			next_uop[4].imm = vls.imm + 6'd32;
			next_uop[4].ble = 8'b11111111;
			next_uop[4].byteno = 6'd32;
			next_uop[5] = vls;
			next_uop[5].num = 5'd5;
			next_uop[5].Rd = vls.Rd + 3'd5;
			next_uop[5].imm = vls.imm + 6'd40;
			next_uop[5].ble = ble;
			next_uop[5].byteno = 6'd40;
				end
			5'd23:
				begin
			next_count = 4'd7;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[0].ble = 8'b11111111;
			next_uop[0].byteno = 6'd0;
			next_uop[0].imm2[5:0] = vlen;
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rd = vls.Rd + 2'd1;
			next_uop[1].imm = vls.imm + 6'd8;
			next_uop[1].ble = 8'b11111111;
			next_uop[1].byteno = 6'd8;
			next_uop[2] = vls;
			next_uop[2].num = 5'd2;
			next_uop[2].Rd = vls.Rd + 2'd2;
			next_uop[2].imm = vls.imm + 6'd16;
			next_uop[2].ble = 8'b11111111;
			next_uop[2].byteno = 6'd16;
			next_uop[3] = vls;
			next_uop[3].num = 5'd3;
			next_uop[3].Rd = vls.Rd + 2'd3;
			next_uop[3].imm = vls.imm + 6'd24;
			next_uop[3].ble = 8'b11111111;
			next_uop[3].byteno = 6'd24;
			next_uop[4] = vls;
			next_uop[4].num = 5'd4;
			next_uop[4].Rd = vls.Rd + 3'd4;
			next_uop[4].imm = vls.imm + 6'd32;
			next_uop[4].ble = 8'b11111111;
			next_uop[4].byteno = 6'd32;
			next_uop[5] = vls;
			next_uop[5].num = 5'd5;
			next_uop[5].Rd = vls.Rd + 3'd5;
			next_uop[5].imm = vls.imm + 6'd40;
			next_uop[5].ble = 8'b11111111;
			next_uop[5].byteno = 6'd40;
			next_uop[6] = vls;
			next_uop[6].num = 5'd6;
			next_uop[6].Rd = vls.Rd + 3'd6;
			next_uop[6].imm = vls.imm + 6'd48;
			next_uop[6].ble = ble;
			next_uop[6].byteno = 6'd48;
				end
			5'd24:
				begin
			next_count = 4'd8;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[0].ble = 8'b11111111;
			next_uop[0].byteno = 6'd0;
			next_uop[0].imm2[5:0] = vlen;
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rd = vls.Rd + 2'd1;
			next_uop[1].imm = vls.imm + 6'd8;
			next_uop[1].ble = 8'b11111111;
			next_uop[1].byteno = 6'd8;
			next_uop[2] = vls;
			next_uop[2].num = 5'd2;
			next_uop[2].Rd = vls.Rd + 2'd2;
			next_uop[2].imm = vls.imm + 6'd16;
			next_uop[2].ble = 8'b11111111;
			next_uop[2].byteno = 6'd16;
			next_uop[3] = vls;
			next_uop[3].num = 5'd3;
			next_uop[3].Rd = vls.Rd + 2'd3;
			next_uop[3].imm = vls.imm + 6'd24;
			next_uop[3].ble = 8'b11111111;
			next_uop[3].byteno = 6'd24;
			next_uop[4] = vls;
			next_uop[4].num = 5'd4;
			next_uop[4].Rd = vls.Rd + 3'd4;
			next_uop[4].imm = vls.imm + 6'd32;
			next_uop[4].ble = 8'b11111111;
			next_uop[4].byteno = 6'd32;
			next_uop[5] = vls;
			next_uop[5].num = 5'd5;
			next_uop[5].Rd = vls.Rd + 3'd5;
			next_uop[5].imm = vls.imm + 6'd40;
			next_uop[5].ble = 8'b11111111;
			next_uop[5].byteno = 6'd40;
			next_uop[6] = vls;
			next_uop[6].num = 5'd6;
			next_uop[6].Rd = vls.Rd + 3'd6;
			next_uop[6].imm = vls.imm + 6'd48;
			next_uop[6].ble = 8'b11111111;
			next_uop[6].byteno = 6'd48;
			next_uop[7] = vls;
			next_uop[7].num = 5'd7;
			next_uop[7].Rd = vls.Rd + 3'd7;
			next_uop[7].imm = vls.imm + 6'd56;
			next_uop[7].ble = ble;
			next_uop[7].byteno = 6'd56;
				end
			default:	
				begin
			next_count = 4'd1;
			next_uop[0] = nopi;
				end
			endcase
		end
		// Should really exception here.
		else begin
			next_count = 4'd1;
			next_uop[0] = nopi;
		end
