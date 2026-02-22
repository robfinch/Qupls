// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// Line draw states
// Line drawing may also be done by the blitter.
// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

// State to setup invariants for DRAWLINE
st_dl_precalc:
	begin
		if (!ctrl[14]) begin
			ctrl[14] <= 1'b1;
			gcx <= fixToInt(p0x);
			gcy <= fixToInt(p0y);
			dx <= fixToInt(absx1mx0);
			dy <= fixToInt(absy1my0);
			if (p0x < p1x) sx <= 16'h0001; else sx <= 16'hFFFF;
			if (p0y < p1y) sy <= 16'h0001; else sy <= 16'hFFFF;
			err <= fixToInt(absx1mx0-absy1my0);
		end
		else if (IsBinaryROP(ctrl[11:8]) || zbuf)
			tCall(st_delay2,st_dl_get_pixel);
		else
			tCall(st_delay2,st_dl_set_pixel);
	end
st_dl_get_pixel:
	tMemRead(zbuf ? ma[19:3] : ma,st_dl_set_pixel);
st_dl_set_pixel:
	begin
		tocnt <= busto;
		color <= pen_color;
		tCall(st_set_pixel,(gcx==fixToInt(p1x) && gcy==fixToInt(p1y)) ? st_dl_ret : st_dl_test);
		if (gcx==fixToInt(p1x) && gcy==fixToInt(p1y)) begin
			if (ctrl[7:0]==8'd2)	// drawline
				ctrl[14] <= 1'b0;
		end
	end
st_dl_test:
	if (~imresp.ack|local_sel) begin
		err <= err - ((e2 > -dy) ? dy : 16'd0) + ((e2 < dx) ? dx : 16'd0);
		if (e2 > -dy)
			gcx <= gcx + sx;
		if (e2 <  dx)
			gcy <= gcy + sy;
		tPause(st_dl_precalc);
	end
st_dl_ret:
	if (~imresp.ack) begin
		tPause(st_ifetch);
	end
