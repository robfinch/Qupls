// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// Filled Triangle drawing
// Uses the standard method for drawing filled triangles.
// Requires some fixed point math and division / multiplication.
// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

// Save off the original set of points defining the triangle. The points are
// manipulated later by the anti-aliasing outline draw.

st_dt_start:								// allows p?? to update
  begin
    up0xs <= up0x;
    up0ys <= up0y;
    up0zs <= up0z;
    up1xs <= up1x;
    up1ys <= up1y;
    up1zs <= up1z;
    up2xs <= up2x;
    up2ys <= up2y;
    up2zs <= up2z;
		tGoto(st_dt_sort);
	end

// First step - sort vertices
// Sort points in order of Y coordinate. Also find the minimum and maximum
// extent of the triangle.
st_dt_sort:
	begin
		ctrl[14] <= 1'b1;				// set busy indicator
		// Just draw a horizontal line if all vertices have the same y co-ord.
		if (p0y == p1y && p0y == p2y) begin
		   if (p0x < p1x && p0x < p2x)
	       curx0 <= p0x;
		   else if (p1x < p2x)
	       curx0 <= p1x;
		   else
	       curx0 <= p2x;
		   if (p0x > p1x && p0x > p2x)
	       curx1 <= p0x;
		   else if (p1x > p2x)
	       curx1 <= p1x;
		   else
	       curx1 <= p2x;
		   gcy <= fixToInt(p0y);
       tGoto(st_hl_line);
		end
		else if (p0y <= p1y && p0y <= p2y) begin
		  minY <= p0y;
			v0x <= p0x;
			v0y <= p0y;
			if (p1y <= p2y) begin
				v1x <= p1x;
				v1y <= p1y;
				v2x <= p2x;
				v2y <= p2y;
				maxY <= p2y;
			end
			else begin
				v1x <= p2x;
				v1y <= p2y;
				v2x <= p1x;
				v2y <= p1y;
				maxY <= p1y;
			end
		end
		else if (p1y <= p2y) begin
		  minY <= p1y;
			v0y <= p1y;
			v0x <= p1x;
			if (p0y <= p2y) begin
				v1y <= p0y;
				v1x <= p0x;
				v2y <= p2y;
				v2x <= p2x;
				maxY <= p2y;
			end
			else begin
				v1y <= p2y;
				v1x <= p2x;
				v2y <= p0y;
				v2x <= p0x;
				maxY <= p0y;
			end
		end
		// y2 < y0 && y2 < y1
		else begin
			v0y <= p2y;
			v0x <= p2x;
			minY <= p2y;
			if (p0y <= p1y) begin
				v1y <= p0y;
				v1x <= p0x;
				v2y <= p1y;
				v2x <= p1x;
				maxY <= p1y;
			end
			else begin
				v1y <= p1y;
				v1x <= p1x;
				v2y <= p0y;
				v2x <= p0x;
				maxY <= p0y;
			end
		end
		// Determine minium and maximum X coord.
		if (p0x <= p1x && p0x <= p2x) begin
	    minX <= p0x;
	    if (p1x <= p2x)
        maxX <= p2x;
	    else
        maxX <= p1x;
		end
		else if (p1x <= p2x) begin
	    minX <= p1x;
	    if (p0x <= p2x)
        maxX <= p2x;
	    else
        maxX <= p0x;
		end
		else begin
	    minX <= p2x;
	    if (p0x < p1x)
        maxX <= p1x;
	    else
        maxX <= p0x;
		end
		    
		tGoto(st_dt1);
	end

// Flat bottom (FB) or flat top (FT) triangle drawing
// Calc inv slopes
st_dt_slope1:
	begin
		div_ld <= TRUE;
		if (fbt) begin
			div_a <= w1x - w0x;
			div_b <= w1y - w0y;
		end
		else begin
			div_a <= w2x - w0x;
			div_b <= w2y - w0y;
		end
		tPause(st_dt_slope1a);
	end
st_dt_slope1a:
	if (div_idle) begin
		invslope0 <= div_qo[31:0];
		if (fbt) begin
			div_a <= w2x - w0x;
			div_b <= w2y - w0y;
		end
		else begin
			div_a <= w2x - w1x;
			div_b <= w2y - w1y;
		end
		div_ld <= TRUE;
		tPause(st_dt_slope2);
	end
st_dt_slope2:
	if (div_idle) begin
		invslope1 <= div_qo[31:0];
    if (fbt) begin
	    curx0 <= w0x;
 	    curx1 <= w0x;
			gcy <= fixToInt(w0y);
			tCall(st_hl_line,st_dt_incy);
		end
		else begin
	    curx0 <= w2x;
      curx1 <= w2x;
      gcy <= fixToInt(w2y);
			tCall(st_hl_line,st_dt_incy);
		end
	end
st_dt_incy:
	begin
		if (fbt) begin
	    if (curx0 + invslope0 < minX)
        curx0 <= minX;
	    else if (curx0 + invslope0 > maxX)
        curx0 <= maxX;
	    else
		    curx0 <= curx0 + invslope0;
			if (curx1 + invslope1 < minX)
		    curx1 <= minX;
			else if (curx1 + invslope1 > maxX)
		    curx1 <= maxX;
			else
		    curx1 <= curx1 + invslope1;
			gcy <= gcy + 16'd1;
			if (gcy>=fixToInt(w1y))
				tRet();
			else
				tCall(st_hl_line,st_dt_incy);
		end
		else begin
	    if (curx0 - invslope0 < minX)
        curx0 <= minX;
      else if (curx0 - invslope0 > maxX)
        curx0 <= maxX;
      else
        curx0 <= curx0 - invslope0;
      if (curx1 - invslope1 < minX)
        curx1 <= minX;
      else if (curx1 - invslope1 > maxX)
        curx1 <= maxX;
      else
        curx1 <= curx1 - invslope1;
			gcy <= gcy - 16'd1;
			if (gcy<fixToInt(w0y))
				tRet();
			else
				tCall(st_hl_line,st_dt_incy);
		end
	end

st_dt1:
	begin
		// Simple case of flat bottom
		if (v1y==v2y) begin
			fbt <= 1'b1;
			w0x <= v0x;
			w0y <= v0y;
			w1x <= v1x;
			w1y <= v1y;
			w2x <= v2x;
			w2y <= v2y;
			tCall(st_dt_slope1,st_dt6);
		end
		// Simple case of flat top
		else if (v0y==v1y) begin
			fbt <= 1'b0;
			w0x <= v0x;
			w0y <= v0y;
			w1x <= v1x;
			w1y <= v1y;
			w2x <= v2x;
			w2y <= v2y;
			tCall(st_dt_slope1,st_dt6);
		end
		// Need to calculte 4th vertice
		else begin
			div_ld <= TRUE;
			div_a <= v1y - v0y;
			div_b <= v2y - v0y;
			tPause(st_dt2);
		end
	end
st_dt2:
	if (div_idle) begin
		trimd <= 8'b11111111;
		v3y <= v1y;
		tGoto(st_dt3);
	end
st_dt3:
	begin
		trimd <= {trimd[6:0],1'b0};
		if (trimd==8'h00) begin
			v3x <= trimult[47:16];
			v3x[15:0] <= 16'h0000;
			tGoto(st_dt4);
		end
	end
st_dt4:
	begin
		fbt <= 1'b1;
		w0x <= v0x;
		w0y <= v0y;
		w1x <= v1x;
		w1y <= v1y;
		w2x <= v3x;
		w2y <= v3y;
		tCall(st_dt_slope1,st_dt5);
	end
st_dt5:
	begin
		fbt <= 1'b0;
		w0x <= v1x;
		w0y <= v1y;
		w1x <= v3x;
		w1y <= v3y;
		w2x <= v2x;
		w2y <= v2y;
		tCall(st_dt_slope1,st_dt6);
	end
st_dt6:
	begin
		ngs <= st_ifetch;
		if (retstacko==st_ifetch) begin
      ctrl[14] <= 1'b0;
      tRet();
	    //tGoto(DT7);
		end
		else
	    tRet();
	end
