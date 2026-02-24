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
		charBoxX0 <= up0x;
		charBoxY0 <= up0y;
		tblit_up0x <= up0x;
		tblit_up0y <= up0y;
		tblit_color <= pen_color;
		tMemRead({font_tbl_adr[31:3],3'b0} + {font_id,4'b00},st_read_font_tbl_nack);
		tblit_adr <= {font_tbl_adr[31:3],3'b0} + {font_id,4'b00};
	end
st_read_font_tbl_nack:
	if (~imresp.ack) begin
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
	if (~imresp.ack) begin
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
	if (~imresp.ack) begin
		font_width <= latched_data >> {charcode[2:0],3'b0};
		tblit_state <= st_read_char_bitmap;
		tRet();
	end
st_read_char_bitmap:
	tMemRead(charBmpBase + (16'(pixvc) << font_width[4:3]),st_read_char_bitmap_nack);
st_read_char_bitmap_nack:
	if (~imresp.ack) begin
		case(font_width[4:3])
		2'd0:	charbmp <= (latched_data >> {mbus.req.adr[2:0],3'b0}) & 32'h0ff;
		2'd1:	charbmp <= (latched_data >> {mbus.req.adr[2:1],4'b0}) & 32'h0ffff;
		2'd2:	charbmp <= latched_data >> {mbus.req.adr[2],5'b0} & 32'hffffffff;
		2'd3:	charbmp <= latched_data;
		endcase
		tblit_state <= st_read_char;
		tRet();
	end
st_read_char:
	begin
		up0x <= tblit_up0x + pixhc;
		up0y <= tblit_up0y + pixvc;
		tGoto(st_read_char2);
	end
st_read_char2:
	begin
		if (charbmp[0]) begin
			pen_color <= tblit_color;
			tCall(st_plot,st_write_char2);
		end
		else begin
			if (!fill_color[31]) begin
				pen_color <= fill_color;
				tCall(st_plot,st_write_char2);
			end
			else
				tGoto(st_write_char2);
		end
	end
st_write_char2:
	begin
		tGoto(st_write_char2_nack);
  	tblit_state <= st_write_char2;
		charbmp <= {1'b0,charbmp[63:1]};
		pixhc <= pixhc + 6'd1;
		if (pixhc==font_width) begin
			tblit_state <= st_read_char_bitmap;
	    pixhc <= 6'd0;
	    pixvc <= pixvc + 6'd1;
	    if (pixvc==font_height) begin
	    	tblit_active <= FALSE;
	    	tblit_state <= st_write_char2_nack;
	    end
		end
		else
			tblit_state <= st_read_char;
	end
st_write_char2_nack:
	if (~imresp.ack|local_sel) begin
		if (!tblit_active) begin
			up0x <= tblit_up0x;
			up0y <= tblit_up0y;
			pen_color <= tblit_color;
			tblit_state <= st_ifetch;
		end
		tRet();
	end
