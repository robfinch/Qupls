// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// Draw horizontal line
// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

// Swap the x-coordinate so that the line is always drawn left to right.
st_hl_line:
	begin
		if (curx0 <= curx1) begin
  		gcx <= fixToInt(curx0);
  		endx <= curx1;
  	end
  	else begin
	    gcx <= fixToInt(curx1);
	    endx <= curx0;
  	end
		if (IsBinaryROP(ctrl[11:8]))
      tCall(st_delay2,st_hl_getpixel);
    else
      tCall(st_delay2,st_hl_setpixel);
	end
st_hl_getpixel:
 	tMemRead(ma,st_hl_setpixel);
st_hl_setpixel:
	if (~imresp.ack|local_sel) begin
		rop <= ctrl[11:8];
		color <= fill_color;
		dst <= st_hl_setpixel_nack;
		tGoto(st_set_pixel);
		gcx <= gcx + 16'd1;
	end
st_hl_setpixel_nack:
	if (~imresp.ack|local_sel) begin
		if (gcx>=fixToInt(endx)) begin
			ngs <= st_ifetch;
			tRet();
		end
		else begin
      if (IsBinaryROP(ctrl[11:8]))
        tPause(st_hl_getpixel);
      else
      	tPause(st_hl_setpixel);
		end
	end

