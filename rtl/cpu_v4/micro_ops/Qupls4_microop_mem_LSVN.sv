	// Indexed loads / stores need to handle the register in pieces.
	// For example, the second load may still belong in the first register if
	// the element size is less than the register width. We cannot simply
	// increment the register number between loads.
	Qupls4_pkg::OP_LDVN,Qupls4_pkg::OP_STVN:
		if (SUPPORT_VECTOR) begin
			next_uop[0].imm2 = vln;
			next_uop[1].imm2 = vln;
			next_uop[2].imm2 = vln;
			next_uop[3].imm2 = vln;
			next_uop[4].imm2 = vln;
			next_uop[5].imm2 = vln;
			next_uop[6].imm2 = vln;
			next_uop[7].imm2 = vln;
			case({VREGS > 4,vlen1[3:0]})
			5'd0:	next_uop[0].ble = 8'b00000000;
			5'd1:
				begin
			next_count = 4'd1;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[0].byteno = 6'd0;
			case(velsz1)
			4'd1:	next_uop[0].ble = 8'b1;
			4'd2:	next_uop[0].ble = 8'b11;
			4'd4:	next_uop[0].ble = 8'b1111;
			4'd8:	next_uop[0].ble = 8'b11111111;
			endcase
				end
			5'd2:
				begin
			next_count = 4'd2;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[0].byteno = 6'd0;
			case(velsz1)
			4'd1:	next_uop[0].ble = 8'b1;
			4'd2:	next_uop[0].ble = 8'b11;
			4'd4:	next_uop[0].ble = 8'b1111;
			4'd8:	next_uop[0].ble = 8'b11111111;
			endcase
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rs2 = vls.Rs2 + 2'd1;
			case(velsz1)
			4'd1:
				begin
					next_uop[1].Rd = vls.Rd;
					next_uop[1].ble = 8'b00000010;
					next_uop[1].byteno = 6'd1;
				end
			4'd2:
				begin
					next_uop[1].Rd = vls.Rd;
					next_uop[1].ble = 8'b00001100;
					next_uop[1].byteno = 6'd2;
				end
			4'd4:
				begin
					next_uop[1].Rd = vls.Rd;
					next_uop[1].ble = 8'b11110000;
					next_uop[1].byteno = 6'd4;
				end
			4'd8:
				begin
					next_uop[1].Rd = vls.Rd + 2'd1;
					next_uop[1].ble = 8'b11111111;
					next_uop[1].byteno = 6'd8;
				end
			endcase
				end
			5'd3:
				begin
			next_count = 4'd3;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[0].byteno = 6'd0;
			case(velsz1)
			4'd1:	next_uop[0].ble = 8'b1;
			4'd2:	next_uop[0].ble = 8'b11;
			4'd4:	next_uop[0].ble = 8'b1111;
			4'd8:	next_uop[0].ble = 8'b11111111;
			endcase
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rs2 = vls.Rs2 + 2'd1;
			case(velsz1)
			4'd1:
				begin
					next_uop[1].Rd = vls.Rd;
					next_uop[1].ble = 8'b00000010;
					next_uop[1].byteno = 6'd1;
				end
			4'd2:
				begin
					next_uop[1].Rd = vls.Rd;
					next_uop[1].ble = 8'b00001100;
					next_uop[1].byteno = 6'd2;
				end
			4'd4:
				begin
					next_uop[1].Rd = vls.Rd;
					next_uop[1].ble = 8'b11110000;
					next_uop[1].byteno = 6'd4;
				end
			4'd8:
				begin
					next_uop[1].Rd = vls.Rd + 2'd1;
					next_uop[1].ble = 8'b11111111;
					next_uop[1].byteno = 6'd8;
				end
			endcase
			next_uop[2] = vls;
			next_uop[2].num = 5'd2;
			next_uop[2].Rs2 = vls.Rs2 + 2'd2;
			case(velsz1)
			4'd1:
				begin
					next_uop[2].Rd = vls.Rd;
					next_uop[2].ble = 8'b00000100;
					next_uop[2].byteno = 6'd2;
				end
			4'd2:
				begin
					next_uop[2].Rd = vls.Rd;
					next_uop[2].ble = 8'b00110000;
					next_uop[2].byteno = 6'd4;
				end
			4'd4:
				begin
					next_uop[2].Rd = vls.Rd + 2'd1;
					next_uop[2].ble = 8'b00001111;
					next_uop[2].byteno = 6'd8;
				end
			4'd8:
				begin
					next_uop[2].Rd = vls.Rd + 2'd2;
					next_uop[2].ble = 8'b11111111;
					next_uop[2].byteno = 6'd16;
				end
			endcase
				end
			5'd4:
				begin
			next_count = 4'd4;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[0].byteno = 6'd0;
			case(velsz1)
			4'd1:	next_uop[0].ble = 8'b1;
			4'd2:	next_uop[0].ble = 8'b11;
			4'd4:	next_uop[0].ble = 8'b1111;
			4'd8:	next_uop[0].ble = 8'b11111111;
			endcase
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rs2 = vls.Rs2 + 2'd1;
			case(velsz1)
			4'd1:
				begin
					next_uop[1].Rd = vls.Rd;
					next_uop[1].ble = 8'b00000010;
					next_uop[1].byteno = 6'd1;
				end
			4'd2:
				begin
					next_uop[1].Rd = vls.Rd;
					next_uop[1].ble = 8'b00001100;
					next_uop[1].byteno = 6'd2;
				end
			4'd4:
				begin
					next_uop[1].Rd = vls.Rd;
					next_uop[1].ble = 8'b11110000;
					next_uop[1].byteno = 6'd4;
				end
			4'd8:
				begin
					next_uop[1].Rd = vls.Rd + 2'd1;
					next_uop[1].ble = 8'b11111111;
					next_uop[1].byteno = 6'd8;
				end
			endcase
			next_uop[2] = vls;
			next_uop[2].num = 5'd2;
			next_uop[2].Rs2 = vls.Rs2 + 2'd2;
			case(velsz1)
			4'd1:
				begin
					next_uop[2].Rd = vls.Rd;
					next_uop[2].ble = 8'b00000100;
					next_uop[2].byteno = 6'd2;
				end
			4'd2:
				begin
					next_uop[2].Rd = vls.Rd;
					next_uop[2].ble = 8'b00110000;
					next_uop[2].byteno = 6'd4;
				end
			4'd4:
				begin
					next_uop[2].Rd = vls.Rd + 2'd1;
					next_uop[2].ble = 8'b00001111;
					next_uop[2].byteno = 6'd8;
				end
			4'd8:
				begin
					next_uop[2].Rd = vls.Rd + 2'd2;
					next_uop[2].ble = 8'b11111111;
					next_uop[2].byteno = 6'd16;
				end
			endcase
			next_uop[3] = vls;
			next_uop[3].num = 5'd3;
			next_uop[3].Rs2 = vls.Rs2 + 2'd3;
			case(velsz1)
			4'd1:
				begin
					next_uop[3].Rd = vls.Rd;
					next_uop[3].ble = 8'b00001000;
					next_uop[3].byteno = 6'd3;
				end
			4'd2:
				begin
					next_uop[3].Rd = vls.Rd;
					next_uop[3].ble = 8'b11000000;
					next_uop[3].byteno = 6'd6;
				end
			4'd4:
				begin
					next_uop[3].Rd = vls.Rd + 2'd1;
					next_uop[3].ble = 8'b11110000;
					next_uop[3].byteno = 6'd12;
				end
			4'd8:
				begin
					next_uop[3].Rd = vls.Rd + 2'd3;
					next_uop[3].ble = 8'b11111111;
					next_uop[3].byteno = 6'd24;
				end
			endcase
				end
			
			5'd21:	// 5
				begin
			next_count = 4'd5;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[0].byteno = 6'd0;
			case(velsz1)
			4'd1:	next_uop[0].ble = 8'b1;
			4'd2:	next_uop[0].ble = 8'b11;
			4'd4:	next_uop[0].ble = 8'b1111;
			4'd8:	next_uop[0].ble = 8'b11111111;
			endcase
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rs2 = vls.Rs2 + 2'd1;
			case(velsz1)
			4'd1:
				begin
					next_uop[1].Rd = vls.Rd;
					next_uop[1].ble = 8'b00000010;
					next_uop[1].byteno = 6'd1;
				end
			4'd2:
				begin
					next_uop[1].Rd = vls.Rd;
					next_uop[1].ble = 8'b00001100;
					next_uop[1].byteno = 6'd2;
				end
			4'd4:
				begin
					next_uop[1].Rd = vls.Rd;
					next_uop[1].ble = 8'b11110000;
					next_uop[1].byteno = 6'd4;
				end
			4'd8:
				begin
					next_uop[1].Rd = vls.Rd + 2'd1;
					next_uop[1].ble = 8'b11111111;
					next_uop[1].byteno = 6'd8;
				end
			endcase
			next_uop[2] = vls;
			next_uop[2].num = 5'd2;
			next_uop[2].Rs2 = vls.Rs2 + 2'd2;
			case(velsz1)
			4'd1:
				begin
					next_uop[2].Rd = vls.Rd;
					next_uop[2].ble = 8'b00000100;
					next_uop[2].byteno = 6'd2;
				end
			4'd2:
				begin
					next_uop[2].Rd = vls.Rd;
					next_uop[2].ble = 8'b00110000;
					next_uop[2].byteno = 6'd4;
				end
			4'd4:
				begin
					next_uop[2].Rd = vls.Rd + 2'd1;
					next_uop[2].ble = 8'b00001111;
					next_uop[2].byteno = 6'd8;
				end
			4'd8:
				begin
					next_uop[2].Rd = vls.Rd + 2'd2;
					next_uop[2].ble = 8'b11111111;
					next_uop[2].byteno = 6'd16;
				end
			endcase
			next_uop[3] = vls;
			next_uop[3].num = 5'd3;
			next_uop[3].Rs2 = vls.Rs2 + 2'd3;
			case(velsz1)
			4'd1:
				begin
					next_uop[3].Rd = vls.Rd;
					next_uop[3].ble = 8'b00001000;
					next_uop[3].byteno = 6'd3;
				end
			4'd2:
				begin
					next_uop[3].Rd = vls.Rd;
					next_uop[3].ble = 8'b11000000;
					next_uop[3].byteno = 6'd6;
				end
			4'd4:
				begin
					next_uop[3].Rd = vls.Rd + 2'd1;
					next_uop[3].ble = 8'b11110000;
					next_uop[3].byteno = 6'd12;
				end
			4'd8:
				begin
					next_uop[3].Rd = vls.Rd + 2'd3;
					next_uop[3].ble = 8'b11111111;
					next_uop[3].byteno = 6'd24;
				end
			endcase
			next_uop[4] = vls;
			next_uop[4].num = 5'd4;
			next_uop[4].Rs2 = vls.Rs2 + 4'd4;
			case(velsz1)
			4'd1:
				begin
					next_uop[4].Rd = vls.Rd;
					next_uop[4].ble = 8'b00010000;
					next_uop[4].byteno = 6'd4;
				end
			4'd2:
				begin
					next_uop[4].Rd = vls.Rd + 2'd1;
					next_uop[4].ble = 8'b00000011;
					next_uop[4].byteno = 6'd8;
				end
			4'd4:
				begin
					next_uop[4].Rd = vls.Rd + 2'd2;
					next_uop[4].ble = 8'b00001111;
					next_uop[4].byteno = 6'd16;
				end
			4'd8:
				begin
					next_uop[4].Rd = vls.Rd + 3'd4;
					next_uop[4].ble = 8'b11111111;
					next_uop[4].byteno = 6'd32;
				end
			endcase
				end

			5'd22:	// 6
				begin
			next_count = 4'd6;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[0].byteno = 6'd0;
			case(velsz1)
			4'd1:	next_uop[0].ble = 8'b1;
			4'd2:	next_uop[0].ble = 8'b11;
			4'd4:	next_uop[0].ble = 8'b1111;
			4'd8:	next_uop[0].ble = 8'b11111111;
			endcase
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rs2 = vls.Rs2 + 2'd1;
			case(velsz1)
			4'd1:
				begin
					next_uop[1].Rd = vls.Rd;
					next_uop[1].ble = 8'b00000010;
					next_uop[1].byteno = 6'd1;
				end
			4'd2:
				begin
					next_uop[1].Rd = vls.Rd;
					next_uop[1].ble = 8'b00001100;
					next_uop[1].byteno = 6'd2;
				end
			4'd4:
				begin
					next_uop[1].Rd = vls.Rd;
					next_uop[1].ble = 8'b11110000;
					next_uop[1].byteno = 6'd4;
				end
			4'd8:
				begin
					next_uop[1].Rd = vls.Rd + 2'd1;
					next_uop[1].ble = 8'b11111111;
					next_uop[1].byteno = 6'd8;
				end
			endcase
			next_uop[2] = vls;
			next_uop[2].num = 5'd2;
			next_uop[2].Rs2 = vls.Rs2 + 2'd2;
			case(velsz1)
			4'd1:
				begin
					next_uop[2].Rd = vls.Rd;
					next_uop[2].ble = 8'b00000100;
					next_uop[2].byteno = 6'd2;
				end
			4'd2:
				begin
					next_uop[2].Rd = vls.Rd;
					next_uop[2].ble = 8'b00110000;
					next_uop[2].byteno = 6'd4;
				end
			4'd4:
				begin
					next_uop[2].Rd = vls.Rd + 2'd1;
					next_uop[2].ble = 8'b00001111;
					next_uop[2].byteno = 6'd8;
				end
			4'd8:
				begin
					next_uop[2].Rd = vls.Rd + 2'd2;
					next_uop[2].ble = 8'b11111111;
					next_uop[2].byteno = 6'd16;
				end
			endcase
			next_uop[3] = vls;
			next_uop[3].num = 5'd3;
			next_uop[3].Rs2 = vls.Rs2 + 2'd3;
			case(velsz1)
			4'd1:
				begin
					next_uop[3].Rd = vls.Rd;
					next_uop[3].ble = 8'b00001000;
					next_uop[3].byteno = 6'd3;
				end
			4'd2:
				begin
					next_uop[3].Rd = vls.Rd;
					next_uop[3].ble = 8'b11000000;
					next_uop[3].byteno = 6'd6;
				end
			4'd4:
				begin
					next_uop[3].Rd = vls.Rd + 2'd1;
					next_uop[3].ble = 8'b11110000;
					next_uop[3].byteno = 6'd12;
				end
			4'd8:
				begin
					next_uop[3].Rd = vls.Rd + 2'd3;
					next_uop[3].ble = 8'b11111111;
					next_uop[3].byteno = 6'd24;
				end
			endcase
			next_uop[4] = vls;
			next_uop[4].num = 5'd4;
			next_uop[4].Rs2 = vls.Rs2 + 4'd4;
			case(velsz1)
			4'd1:
				begin
					next_uop[4].Rd = vls.Rd;
					next_uop[4].ble = 8'b00010000;
					next_uop[4].byteno = 6'd4;
				end
			4'd2:
				begin
					next_uop[4].Rd = vls.Rd + 2'd1;
					next_uop[4].ble = 8'b00000011;
					next_uop[4].byteno = 6'd8;
				end
			4'd4:
				begin
					next_uop[4].Rd = vls.Rd + 2'd2;
					next_uop[4].ble = 8'b00001111;
					next_uop[4].byteno = 6'd16;
				end
			4'd8:
				begin
					next_uop[4].Rd = vls.Rd + 3'd4;
					next_uop[4].ble = 8'b11111111;
					next_uop[4].byteno = 6'd32;
				end
			endcase
			next_uop[5] = vls;
			next_uop[5].num = 5'd5;
			next_uop[5].Rs2 = vls.Rs2 + 4'd5;
			case(velsz1)
			4'd1:
				begin
					next_uop[5].Rd = vls.Rd;
					next_uop[5].ble = 8'b00100000;
					next_uop[5].byteno = 6'd5;
				end
			4'd2:
				begin
					next_uop[5].Rd = vls.Rd + 2'd1;
					next_uop[5].ble = 8'b00001100;
					next_uop[5].byteno = 6'd10;
				end
			4'd4:
				begin
					next_uop[5].Rd = vls.Rd + 2'd2;
					next_uop[5].ble = 8'b11110000;
					next_uop[5].byteno = 6'd20;
				end
			4'd8:
				begin
					next_uop[5].Rd = vls.Rd + 3'd5;
					next_uop[5].ble = 8'b11111111;
					next_uop[5].byteno = 6'd40;
				end
			endcase
				end

			5'd23:	// 7
				begin
			next_count = 4'd7;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[0].byteno = 6'd0;
			case(velsz1)
			4'd1:	next_uop[0].ble = 8'b1;
			4'd2:	next_uop[0].ble = 8'b11;
			4'd4:	next_uop[0].ble = 8'b1111;
			4'd8:	next_uop[0].ble = 8'b11111111;
			endcase
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rs2 = vls.Rs2 + 2'd1;
			case(velsz1)
			4'd1:
				begin
					next_uop[1].Rd = vls.Rd;
					next_uop[1].ble = 8'b00000010;
					next_uop[1].byteno = 6'd1;
				end
			4'd2:
				begin
					next_uop[1].Rd = vls.Rd;
					next_uop[1].ble = 8'b00001100;
					next_uop[1].byteno = 6'd2;
				end
			4'd4:
				begin
					next_uop[1].Rd = vls.Rd;
					next_uop[1].ble = 8'b11110000;
					next_uop[1].byteno = 6'd4;
				end
			4'd8:
				begin
					next_uop[1].Rd = vls.Rd + 2'd1;
					next_uop[1].ble = 8'b11111111;
					next_uop[1].byteno = 6'd8;
				end
			endcase
			next_uop[2] = vls;
			next_uop[2].num = 5'd2;
			next_uop[2].Rs2 = vls.Rs2 + 2'd2;
			case(velsz1)
			4'd1:
				begin
					next_uop[2].Rd = vls.Rd;
					next_uop[2].ble = 8'b00000100;
					next_uop[2].byteno = 6'd2;
				end
			4'd2:
				begin
					next_uop[2].Rd = vls.Rd;
					next_uop[2].ble = 8'b00110000;
					next_uop[2].byteno = 6'd4;
				end
			4'd4:
				begin
					next_uop[2].Rd = vls.Rd + 2'd1;
					next_uop[2].ble = 8'b00001111;
					next_uop[2].byteno = 6'd8;
				end
			4'd8:
				begin
					next_uop[2].Rd = vls.Rd + 2'd2;
					next_uop[2].ble = 8'b11111111;
					next_uop[2].byteno = 6'd16;
				end
			endcase
			next_uop[3] = vls;
			next_uop[3].num = 5'd3;
			next_uop[3].Rs2 = vls.Rs2 + 2'd3;
			case(velsz1)
			4'd1:
				begin
					next_uop[3].Rd = vls.Rd;
					next_uop[3].ble = 8'b00001000;
					next_uop[3].byteno = 6'd3;
				end
			4'd2:
				begin
					next_uop[3].Rd = vls.Rd;
					next_uop[3].ble = 8'b11000000;
					next_uop[3].byteno = 6'd6;
				end
			4'd4:
				begin
					next_uop[3].Rd = vls.Rd + 2'd1;
					next_uop[3].ble = 8'b11110000;
					next_uop[3].byteno = 6'd12;
				end
			4'd8:
				begin
					next_uop[3].Rd = vls.Rd + 2'd3;
					next_uop[3].ble = 8'b11111111;
					next_uop[3].byteno = 6'd24;
				end
			endcase
			next_uop[4] = vls;
			next_uop[4].num = 5'd4;
			next_uop[4].Rs2 = vls.Rs2 + 4'd4;
			case(velsz1)
			4'd1:
				begin
					next_uop[4].Rd = vls.Rd;
					next_uop[4].ble = 8'b00010000;
					next_uop[4].byteno = 6'd4;
				end
			4'd2:
				begin
					next_uop[4].Rd = vls.Rd + 2'd1;
					next_uop[4].ble = 8'b00000011;
					next_uop[4].byteno = 6'd8;
				end
			4'd4:
				begin
					next_uop[4].Rd = vls.Rd + 2'd2;
					next_uop[4].ble = 8'b00001111;
					next_uop[4].byteno = 6'd16;
				end
			4'd8:
				begin
					next_uop[4].Rd = vls.Rd + 3'd4;
					next_uop[4].ble = 8'b11111111;
					next_uop[4].byteno = 6'd32;
				end
			endcase
			next_uop[5] = vls;
			next_uop[5].num = 5'd5;
			next_uop[5].Rs2 = vls.Rs2 + 4'd5;
			case(velsz1)
			4'd1:
				begin
					next_uop[5].Rd = vls.Rd;
					next_uop[5].ble = 8'b00100000;
					next_uop[5].byteno = 6'd5;
				end
			4'd2:
				begin
					next_uop[5].Rd = vls.Rd + 2'd1;
					next_uop[5].ble = 8'b00001100;
					next_uop[5].byteno = 6'd10;
				end
			4'd4:
				begin
					next_uop[5].Rd = vls.Rd + 2'd2;
					next_uop[5].ble = 8'b11110000;
					next_uop[5].byteno = 6'd20;
				end
			4'd8:
				begin
					next_uop[5].Rd = vls.Rd + 3'd5;
					next_uop[5].ble = 8'b11111111;
					next_uop[5].byteno = 6'd40;
				end
			endcase
			next_uop[6] = vls;
			next_uop[6].num = 5'd6;
			next_uop[6].Rs2 = vls.Rs2 + 4'd6;
			case(velsz1)
			4'd1:
				begin
					next_uop[6].Rd = vls.Rd;
					next_uop[6].ble = 8'b01000000;
					next_uop[6].byteno = 6'd6;
				end
			4'd2:
				begin
					next_uop[6].Rd = vls.Rd + 2'd1;
					next_uop[6].ble = 8'b00110000;
					next_uop[6].byteno = 6'd12;
				end
			4'd4:
				begin
					next_uop[6].Rd = vls.Rd + 2'd3;
					next_uop[6].ble = 8'b00001111;
					next_uop[6].byteno = 6'd24;
				end
			4'd8:
				begin
					next_uop[6].Rd = vls.Rd + 3'd6;
					next_uop[6].ble = 8'b11111111;
					next_uop[6].byteno = 6'd48;
				end
			endcase
				end

			5'd24:
				begin
			next_count = 4'd8;
			next_uop[0] = vls;
			next_uop[0].lead = TRUE;
			next_uop[0].byteno = 6'd0;
			case(velsz1)
			4'd1:	next_uop[0].ble = 8'b1;
			4'd2:	next_uop[0].ble = 8'b11;
			4'd4:	next_uop[0].ble = 8'b1111;
			4'd8:	next_uop[0].ble = 8'b11111111;
			endcase
			next_uop[1] = vls;
			next_uop[1].num = 5'd1;
			next_uop[1].Rs2 = vls.Rs2 + 2'd1;
			case(velsz1)
			4'd1:
				begin
					next_uop[1].Rd = vls.Rd;
					next_uop[1].ble = 8'b00000010;
					next_uop[1].byteno = 6'd1;
				end
			4'd2:
				begin
					next_uop[1].Rd = vls.Rd;
					next_uop[1].ble = 8'b00001100;
					next_uop[1].byteno = 6'd2;
				end
			4'd4:
				begin
					next_uop[1].Rd = vls.Rd;
					next_uop[1].ble = 8'b11110000;
					next_uop[1].byteno = 6'd4;
				end
			4'd8:
				begin
					next_uop[1].Rd = vls.Rd + 2'd1;
					next_uop[1].ble = 8'b11111111;
					next_uop[1].byteno = 6'd8;
				end
			endcase
			next_uop[2] = vls;
			next_uop[2].num = 5'd2;
			next_uop[2].Rs2 = vls.Rs2 + 2'd2;
			case(velsz1)
			4'd1:
				begin
					next_uop[2].Rd = vls.Rd;
					next_uop[2].ble = 8'b00000100;
					next_uop[2].byteno = 6'd2;
				end
			4'd2:
				begin
					next_uop[2].Rd = vls.Rd;
					next_uop[2].ble = 8'b00110000;
					next_uop[2].byteno = 6'd4;
				end
			4'd4:
				begin
					next_uop[2].Rd = vls.Rd + 2'd1;
					next_uop[2].ble = 8'b00001111;
					next_uop[2].byteno = 6'd8;
				end
			4'd8:
				begin
					next_uop[2].Rd = vls.Rd + 2'd2;
					next_uop[2].ble = 8'b11111111;
					next_uop[2].byteno = 6'd16;
				end
			endcase
			next_uop[3] = vls;
			next_uop[3].num = 5'd3;
			next_uop[3].Rs2 = vls.Rs2 + 2'd3;
			case(velsz1)
			4'd1:
				begin
					next_uop[3].Rd = vls.Rd;
					next_uop[3].ble = 8'b00001000;
					next_uop[3].byteno = 6'd3;
				end
			4'd2:
				begin
					next_uop[3].Rd = vls.Rd;
					next_uop[3].ble = 8'b11000000;
					next_uop[3].byteno = 6'd6;
				end
			4'd4:
				begin
					next_uop[3].Rd = vls.Rd + 2'd1;
					next_uop[3].ble = 8'b11110000;
					next_uop[3].byteno = 6'd12;
				end
			4'd8:
				begin
					next_uop[3].Rd = vls.Rd + 2'd3;
					next_uop[3].ble = 8'b11111111;
					next_uop[3].byteno = 6'd24;
				end
			endcase
			next_uop[4] = vls;
			next_uop[4].num = 5'd4;
			next_uop[4].Rs2 = vls.Rs2 + 4'd4;
			case(velsz1)
			4'd1:
				begin
					next_uop[4].Rd = vls.Rd;
					next_uop[4].ble = 8'b00010000;
					next_uop[4].byteno = 6'd4;
				end
			4'd2:
				begin
					next_uop[4].Rd = vls.Rd + 2'd1;
					next_uop[4].ble = 8'b00000011;
					next_uop[4].byteno = 6'd8;
				end
			4'd4:
				begin
					next_uop[4].Rd = vls.Rd + 2'd2;
					next_uop[4].ble = 8'b00001111;
					next_uop[4].byteno = 6'd16;
				end
			4'd8:
				begin
					next_uop[4].Rd = vls.Rd + 3'd4;
					next_uop[4].ble = 8'b11111111;
					next_uop[4].byteno = 6'd32;
				end
			endcase
			next_uop[5] = vls;
			next_uop[5].num = 5'd5;
			next_uop[5].Rs2 = vls.Rs2 + 4'd5;
			case(velsz1)
			4'd1:
				begin
					next_uop[5].Rd = vls.Rd;
					next_uop[5].ble = 8'b00100000;
					next_uop[5].byteno = 6'd5;
				end
			4'd2:
				begin
					next_uop[5].Rd = vls.Rd + 2'd1;
					next_uop[5].ble = 8'b00001100;
					next_uop[5].byteno = 6'd10;
				end
			4'd4:
				begin
					next_uop[5].Rd = vls.Rd + 2'd2;
					next_uop[5].ble = 8'b11110000;
					next_uop[5].byteno = 6'd20;
				end
			4'd8:
				begin
					next_uop[5].Rd = vls.Rd + 3'd5;
					next_uop[5].ble = 8'b11111111;
					next_uop[5].byteno = 6'd40;
				end
			endcase
			next_uop[6] = vls;
			next_uop[6].num = 5'd6;
			next_uop[6].Rs2 = vls.Rs2 + 4'd6;
			case(velsz1)
			4'd1:
				begin
					next_uop[6].Rd = vls.Rd;
					next_uop[6].ble = 8'b01000000;
					next_uop[6].byteno = 6'd6;
				end
			4'd2:
				begin
					next_uop[6].Rd = vls.Rd + 2'd1;
					next_uop[6].ble = 8'b00110000;
					next_uop[6].byteno = 6'd12;
				end
			4'd4:
				begin
					next_uop[6].Rd = vls.Rd + 2'd3;
					next_uop[6].ble = 8'b00001111;
					next_uop[6].byteno = 6'd24;
				end
			4'd8:
				begin
					next_uop[6].Rd = vls.Rd + 3'd6;
					next_uop[6].ble = 8'b11111111;
					next_uop[6].byteno = 6'd48;
				end
			endcase
			next_uop[7] = vls;
			next_uop[7].num = 5'd7;
			next_uop[7].Rs2 = vls.Rs2 + 4'd7;
			case(velsz1)
			4'd1:
				begin
					next_uop[7].Rd = vls.Rd;
					next_uop[7].ble = 8'b10000000;
					next_uop[7].byteno = 6'd7;
				end
			4'd2:
				begin
					next_uop[7].Rd = vls.Rd + 2'd1;
					next_uop[7].ble = 8'b11000000;
					next_uop[7].byteno = 6'd14;
				end
			4'd4:
				begin
					next_uop[7].Rd = vls.Rd + 2'd3;
					next_uop[7].ble = 8'b11110000;
					next_uop[7].byteno = 6'd28;
				end
			4'd8:
				begin
					next_uop[7].Rd = vls.Rd + 3'd7;
					next_uop[7].ble = 8'b11111111;
					next_uop[7].byteno = 6'd56;
				end
			endcase
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
