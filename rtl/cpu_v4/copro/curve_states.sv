// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// Bezier Curve
// B(t) = (1-t)[(1-t)P0+tP1] + t[(1-t)P1 + tP2], 0 <= t <= 1.
// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

st_bc0:
	begin
		ctrl[14] <= 1'b1;
		bv0x <= p0x;
		bv0y <= p0y;
		bv1x <= p1x;
		bv1y <= p1y;
		bv2x <= p2x;
		bv2y <= p2y;
		bezierT <= bezierInc;
		otransform <= transform;
		transform <= FALSE;
		up0x <= p0x;
		up0y <= p0y;
		tGoto(st_bc1);
	end
st_bc1:
	begin
		bezier1mT <= fixed_one - bezierT;
		tGoto(st_bc2);
	end
st_bc2:
	begin
		bezier1mTP0xw <= bezier1mT * bv0x;
		bezier1mTP1xw <= bezier1mT * bv1x;
		bezierTP1x <= bezierT * bv1x;
		bezierTP2x <= bezierT * bv2x;
		bezier1mTP0yw <= bezier1mT * bv0y;
		bezier1mTP1yw <= bezier1mT * bv1y;
		bezierTP1y <= bezierT * bv1y;
		bezierTP2y <= bezierT * bv2y;
		tGoto(st_bc3);
	end
st_bc3:
	begin
		bezierP0plusP1x <= bezier1mTP0xw[47:16] + bezierTP1x[47:16];
		bezierP1plusP2x <= bezier1mTP1xw[47:16] + bezierTP2x[47:16];
		bezierP0plusP1y <= bezier1mTP0yw[47:16] + bezierTP1y[47:16];
		bezierP1plusP2y <= bezier1mTP1yw[47:16] + bezierTP2y[47:16];
		tGoto(st_bc4);
	end
st_bc4:
	begin
		bezierBxw <= bezier1mT * bezierP0plusP1x + bezierT * bezierP1plusP2x;
		bezierByw <= bezier1mT * bezierP0plusP1y + bezierT * bezierP1plusP2y;
		tCall(st_delay2,st_bc5);
	end
st_bc5:
	begin
		up1x <= bezierBxw[47:16];
		up1y <= bezierByw[47:16];
	  if (fillCurve[1]) begin
	    up2x <= bv1x;
	    up2y <= bv1y;
	  end
		tGoto(st_bc6);
	end
st_bc6:
	begin
		ctrl[14] <= 1'b0;
		tCall(st_dl_precalc,|fillCurve ? st_bc7 : st_bc8);
	end
st_bc7:
  begin
		ctrl[14] <= 1'b0;
		tCall(st_dt_start,st_bc7);
  end
st_bc8:
	begin
		tGoto(st_bc1);
	  up0x <= up1x;
	  up0y <= up1y;
	  bezierT <= bezierT + bezierInc;
	  if (bezierT >= fixed_one) begin
	  	up1x <= up2x;
	  	up1y <= up2y;
			ctrl[14] <= 1'b0;
	  	tCall(|fillCurve ? st_dt_start : st_dl_precalc,st_bc9);
	  end
	end
st_bc9:
	begin
    ctrl[14] <= 1'b0;
    //call(BC9,DL_PRECALC);
    tGoto(st_bc10);
  end
st_bc10:
	begin
    ctrl[14] <= 1'b0;
    transform <= otransform;
    tRet();
	end
	