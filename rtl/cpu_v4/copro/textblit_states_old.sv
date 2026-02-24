// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// Character draw acceleration states
//
// Font Table - An entry for each font
// fwwwwwhhhhh-aaaa		- width and height
// aaaaaaaaaaaaaaaa		- char bitmap address
// ------------aaaa		- address offset of gylph width table
// aaaaaaaaaaaaaaaa		- low order address offset bits
//
// 10100001000-aaaa_aaaaaaaaaaaaaaaa_------------aaaaaaaaaaaaaaaaaaaa
// A1008008
//
// Glyph Table Entry
// ---wwwww---wwwww		- width
// ---wwwww---wwwww
// ---wwwww---wwwww
// ---wwwww---wwwww
// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

st_read_font_tbl:
	begin
		pixhc <= 6'd0;
		pixvc <= 6'd0;
		charBoxX0 <= p0x;
		charBoxY0 <= p0y;
		tMemRead({font_tbl_adr[31:3],3'b0} + {font_id,4'b00},st_read_font_tbl_nack);
		tblit_adr <= {font_tbl_adr[31:3],3'b0} + {font_id,4'b00};
	end
st_read_font_tbl_nack:
	if (~imresp.ack|local_sel) begin
		charBmpBase <= latched_data[63:32];
		glyph_tbl_adr <= latched_data[31:0];
		tGoto(st_read_font_tbl2);
	end
st_read_font_tbl2:
	begin
		pixhc <= 6'd0;
		pixvc <= 6'd0;
		tMemRead({font_tbl_adr[31:3],3'b0} + {font_id,4'd8},st_read_font_tbl2_nack);
		tblit_adr <= {font_tbl_adr[31:3],3'b0} + {font_id,4'd8};
	end
st_read_font_tbl2_nack:
	if (~imresp.ack|local_sel) begin
		font_fixed <= latched_data[63];
		font_width <= latched_data[61:56];
		font_height <= latched_data[53:48];
		tblit_state <= st_read_glyph_entry;
		tRet();
	end
st_read_glyph_entry:
	begin
		charBmpBase <= charBmpBase + charndx;
		if (font_fixed)
			tGoto(st_read_char_bitmap);
		else
			tMemRead({glyph_tbl_adr[31:3],3'h0} + {charcode[8:3],3'h0},st_read_glyph_entry_nack);
	end
st_read_glyph_entry_nack:
	if (~imresp.ack|local_sel) begin
		font_width <= latched_data >> {charcode[2:0],3'b0};
		tblit_state <= st_read_char_bitmap;
		tRet();
	end
st_read_char_bitmap:
	tMemRead(charBmpBase + (16'(pixvc) << font_width[4:3]),st_read_char_bitmap_nack);
st_read_char_bitmap_nack:
	if (~imresp.ack|local_sel) begin
		case(font_width[4:3])
		2'd0:	charbmp <= (latched_data >> {mbus.req.adr[2:0],3'b0}) & 32'h0ff;
		2'd1:	charbmp <= (latched_data >> {mbus.req.adr[2:1],4'b0}) & 32'h0ffff;
		2'd2:	charbmp <= latched_data >> {mbus.req.adr[2],5'b0} & 32'hffffffff;
		2'd3:	charbmp <= latched_data;
		endcase
		tgtaddr <= fixToInt(charBoxY0) * {TargetWidth,1'b0} + TargetBase + {fixToInt(charBoxX0),1'b0};
		tgtindex <= {TargetWidth,1'b0} * pixvc + {pixhc,1'b0};
		tblit_state <= fill_color[31] ? st_read_char : st_write_char;
		tRet();
	end
st_read_char:
	begin
		tgtadr <= tgtaddr + tgtindex;
		tGoto(st_read_char2);
	end
st_read_char2:
	tMemRead(tgtadr,st_write_char);
st_write_char:
	if (~imresp.ack|local_sel) begin
		latched_data <= latched_data >> {tgtadr[2:1],4'b0};
		tGoto(st_write_char1);
	end
st_write_char1:
	begin
		tgtadr <= tgtaddr + tgtindex;
		tGoto(st_write_char2);
	end
st_write_char2:
	begin
		// Assign default destination state, will be overridden later.
		tGoto(st_write_char2_nack);
		if (~fill_color[`A]) begin
			if ((clipEnable && (fixToInt(charBoxX0) + pixhc < clipX0) || (fixToInt(charBoxX0) + pixhc >= clipX1) || (fixToInt(charBoxY0) + pixvc < clipY0)))
				;
			else if (fixToInt(charBoxX0) + pixhc >= TargetWidth)
				;
			else begin
				tMemWrite(
					tgtadr,
					8'd3 << {tgtadr[2:1],1'b0},
					{4{charbmp[0] ? pen_color[15:0] :
						fill_color[31] ? latched_data[15:0] :
						fill_color[15:0]}},
					st_write_char2_nack
				);
			end
		end
		else begin
			if (charbmp[0]) begin
				if (zbuf) begin
					if (clipEnable && (fixToInt(charBoxX0) + pixhc < clipX0 || fixToInt(charBoxX0) + pixhc >= clipX1 || fixToInt(charBoxY0) + pixvc < clipY0))
						;
					else if (fixToInt(charBoxX0) + pixhc >= TargetWidth)
						;
					else begin
						local_sel <= TRUE;
						mbus.req.cyc <= HIGH;
						mbus.req.stb <= HIGH;
						mbus.req.sel <= 8'd3 << {tgtadr[2:1],1'b0};
/*
						mbus.req.we <= HIGH;
						mbus.req.adr <= tgtadr;
						mbus.req.dat <= {32{zlayer}};
*/				
						tocnt <= busto;
					end
				end
				else begin
					if (clipEnable && (fixToInt(charBoxX0) + pixhc < clipX0 || fixToInt(charBoxX0) + pixhc >= clipX1 || fixToInt(charBoxY0) + pixvc < clipY0))
						;
					else if (fixToInt(charBoxX0) + pixhc >= TargetWidth)
						;
					else begin
						tMemWrite(
							tgtadr,
							8'd3 << {tgtadr[2:1],1'b0},
							{4{pen_color[15:0]}},
							st_write_char2_nack
						);
					end
				end
			end
		end
		charbmp <= {1'b0,charbmp[63:1]};
		pixhc <= pixhc + 6'd1;
		if (pixhc==font_width) begin
			tblit_state <= st_read_char_bitmap;
	    pixhc <= 6'd0;
	    pixvc <= pixvc + 6'd1;
			tgtindex <= ({TargetWidth,1'b0}) * (pixvc + 6'd1);
	    if (clipEnable && (fixToInt(charBoxY0) + pixvc + 16'd1 >= clipY1))
	    	tblit_active <= FALSE;
	    else if (fixToInt(charBoxY0) + pixvc + 16'd1 >= TargetHeight)
	    	tblit_active <= FALSE;
	    else if (pixvc==font_height)
	    	tblit_active <= FALSE;
		end
		else begin
			tblit_state <= fill_color[31] ? st_read_char : st_write_char;
			tgtindex <= {TargetWidth,1'b0} * pixvc + {pixhc+6'd1,1'b0};
		end
	end
st_write_char2_nack:
	if (~imresp.ack|local_sel) begin
		if (!tblit_active)
			tblit_state <= st_ifetch;
		tRet();
	end
