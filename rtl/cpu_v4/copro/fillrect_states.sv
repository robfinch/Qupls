// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// Draw a filled rectangle, uses the blitter.
// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

st_fillrect:
	begin
		// Switching the points around will have the side effect
		// of switching the transformed points around as well.
		if (p1y < p0y) up0y <= up1y;
		if (p1x < p0x) up0x <= up1x;
		dx <= fixToInt(absx1mx0) + 16'd1;	// Order of points doesn't matter here.
		dy <= fixToInt(absy1my0) + 16'd1;
		// Wait for previous blit to finish
		// then delay 1 cycle for point switching
		if (bltCtrlx[13]||!(bltCtrlx[15]||bltCtrlx[14]))
			tCall(st_delay1,st_fillrect_clip);
		else begin
			ctrl[14] <= 1'b1;
			ngs <= st_fillrect;
			tRet();
		end
	end
st_fillrect_clip:
	begin
		if (fixToInt(p0x) + dx > TargetWidth)
			dx <= TargetWidth - fixToInt(p0x);
		if (fixToInt(p0y) + dy > TargetHeight)
			dy <= TargetHeight - fixToInt(p0y);
		tGoto(st_fillrect2);
	end
st_fillrect2:
	begin
		bltD_badrx <= {8'h00,fixToInt(p0y)} * {TargetWidth,1'b0} + TargetBase + {fixToInt(p0x),1'b0};
		bltD_modx <= {TargetWidth - dx,1'b0};
		bltD_cntx <= dx * dy;
		bltDstWidx <= dx;
		bltD_datx <= {4{fill_color[15:0]}};
		bltCtrlx[15:0] <= 16'h8080;
		ngs <= st_ifetch;
		ctrl[14] <= 1'b0;
		tRet();
	end

