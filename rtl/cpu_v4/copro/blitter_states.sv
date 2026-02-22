// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// Blitter DMA
// Blitter has four DMA channels, three source channels and one destination
// channel.
// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

	// Blit channel A
st_bltdma2:
	begin
		tMemRead(bltA_wadr,st_bltdma2_nack);
		bltinc <= bltCtrlx[8] ? -32'(bltA_inc) : bltA_inc;
    end
st_bltdma2_nack:
	if (imresp.ack|local_sel) begin
		bltA_datx <= latched_data >> {bltA_wadr[2:1],4'h0};
		bltA_wadr <= bltA_wadr + bltinc;
    bltA_hcnt <= bltA_hcnt + 32'd1;
    if (bltA_hcnt==bltSrcWid) begin
	    bltA_hcnt <= 32'd1;
	    bltA_wadr <= bltA_wadr + {bltA_modx[31:1],1'b0} + bltinc;
		end
    bltA_wcnt <= bltA_wcnt + 32'd1;
    bltA_dcnt <= bltA_dcnt + 32'd1;
    if (bltA_wcnt>=bltA_cntx) begin
      bltA_wadr <= bltA_badrx;
      bltA_wcnt <= 32'd1;
      bltA_hcnt <= 32'd1;
    end
		if (bltA_dcnt>=bltD_cntx)
			bltCtrlx[1] <= 1'b0;
		if (bltCtrlx[3])
			blt_nch <= 2'b01;
		else if (bltCtrlx[5])
			blt_nch <= 2'b10;
		else if (bltCtrlx[7])
			blt_nch <= 2'b11;
		else
			blt_nch <= 2'b00;
		tRet();
	end

	// Blit channel B
st_bltdma4:
	begin
		tMemRead(bltB_wadr,st_bltdma4_nack);
		bltinc <= bltCtrlx[9] ? -32'(bltB_inc) : bltB_inc;
	end
st_bltdma4_nack:
	if (~imresp.ack|local_sel) begin
		bltB_datx <= latched_data >> {bltB_wadr[2:1],4'h0};
    bltB_wadr <= bltB_wadr + bltinc;
    bltB_hcnt <= bltB_hcnt + 32'd1;
    if (bltB_hcnt>=bltSrcWidx) begin
      bltB_hcnt <= 32'd1;
      bltB_wadr <= bltB_wadr + {bltB_modx[31:1],1'b0} + bltinc;
    end
    bltB_wcnt <= bltB_wcnt + 32'd1;
    bltB_dcnt <= bltB_dcnt + 32'd1;
    if (bltB_wcnt>=bltB_cntx) begin
      bltB_wadr <= bltB_badrx;
      bltB_wcnt <= 32'd1;
      bltB_hcnt <= 32'd1;
    end
		if (bltB_dcnt==bltD_cntx)
			bltCtrlx[3] <= 1'b0;
		if (bltCtrlx[5])
			blt_nch <= 2'b10;
		else if (bltCtrlx[7])
			blt_nch <= 2'b11;
		else if (bltCtrlx[1])
			blt_nch <= 2'b00;
		else
			blt_nch <= 2'b01;
		tRet();
	end

	// Blit channel C
st_bltdma6:
	begin
		tMemRead(bltC_wadr,st_bltdma6_nack);
		bltinc <= bltCtrlx[10] ? -32'(bltC_inc) : bltC_inc;
	end
st_bltdma6_nack:
	if (~imresp.ack|local_sel) begin
		bltC_datx <= latched_data >> {bltC_wadr[2:1],4'h0};
    bltC_wadr <= bltC_wadr + bltinc;
    bltC_hcnt <= bltC_hcnt + 32'd1;
    if (bltC_hcnt==bltSrcWidx) begin
      bltC_hcnt <= 32'd1;
      bltC_wadr <= bltC_wadr + {bltC_modx[31:1],1'b0} + bltinc;
    end
    bltC_wcnt <= bltC_wcnt + 32'd1;
    bltC_dcnt <= bltC_dcnt + 32'd1;
    if (bltC_wcnt>=bltC_cntx) begin
      bltC_wadr <= bltC_badrx;
      bltC_wcnt <= 32'd1;
      bltC_hcnt <= 32'd1;
    end
		if (bltC_dcnt>=bltD_cntx)
			bltCtrlx[5] <= 1'b0;
		if (bltCtrlx[7])
			blt_nch <= 2'b11;
		else if (bltCtrlx[1])
			blt_nch <= 2'b00;
		else if (bltCtrlx[3])
			blt_nch <= 2'b01;
		else
			blt_nch <= 2'b10;
		tRet();
	end

	// Blit channel D
st_bltdma8:
	begin
		case(bltD_inc)
		8'd1:	
			tMemWrite(
				bltD_wadr,
				8'h01 << bltD_wadr[2:0],
				(bltCtrlx[1]|bltCtrlx[3]|bltCtrlx[5]) ? {4{bltabc}} : bltD_datx,
				st_bltdma8_nack
			);
		8'd2:
			tMemWrite(
				bltD_wadr,
				8'h03 << {bltD_wadr[2:1],1'b0},
				(bltCtrlx[1]|bltCtrlx[3]|bltCtrlx[5]) ? {4{bltabc}} : bltD_datx,
				st_bltdma8_nack
			);
		8'd4:
			tMemWrite(
				bltD_wadr,
				8'h0F << {bltD_wadr[2],2'b0},
				(bltCtrlx[1]|bltCtrlx[3]|bltCtrlx[5]) ? {4{bltabc}} : bltD_datx,
				st_bltdma8_nack
			);
		default:
			tMemWrite(
				bltD_wadr,
				8'hFF,
				(bltCtrlx[1]|bltCtrlx[3]|bltCtrlx[5]) ? {4{bltabc}} : bltD_datx,
				st_bltdma8_nack
			);
		endcase
		bltinc <= bltCtrlx[11] ? -32'(bltD_inc) : 32'(bltD_inc);
	end
st_bltdma8_nack:
	if (~imresp.ack|local_sel) begin
		local_sel <= FALSE;
		mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
		bltD_wadr <= bltD_wadr + bltinc;
		bltD_wcnt <= bltD_wcnt + 32'd1;
		bltD_hcnt <= bltD_hcnt + 32'd1;
		if (bltD_hcnt>=bltDstWidx) begin
			bltD_hcnt <= 32'd1;
			bltD_wadr <= bltD_wadr + {bltD_modx[31:1],1'b0} + bltinc;
		end
		if (bltD_wcnt>=bltD_cntx) begin
			bltCtrlx[14] <= 1'b0;
			bltCtrlx[13] <= 1'b1;
			bltCtrlx[7] <= 1'b0;
		end
		if (bltCtrlx[1])
			blt_nch <= 2'b00;
		else if (bltCtrlx[3])
			blt_nch <= 2'b01;
		else if (bltCtrlx[5])
			blt_nch <= 2'b10;
		else
			blt_nch <= 2'b11;
		tRet();
	end

