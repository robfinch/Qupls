// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// Pixel plot acceleration states
// For binary raster operations a back-to-back read then write is performed.
// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

st_plot:
	begin
		ngs <= st_ifetch;
		gcx <= fixToInt(p0x);
		gcy <= fixToInt(p0y);
		if (IsBinaryROP(ctrl[11:8]))
			tCall(st_delay3,st_plot_read);
		else
			tCall(st_delay3,st_plot_write);
	end
st_plot_read:
	tMemRead(ma,st_plot_write);
st_plot_write:
	begin
		rop <= ctrl[11:8];
		color <= pen_color;
		dst <= st_delay1;
		tGoto(st_set_pixel);
	end

