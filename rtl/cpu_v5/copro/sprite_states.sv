// Data is fetched only for the sprites that are displayed on the scan line.
st_hsync:
	begin
		spriteno <= 5'd0;
		spriteActiveB <= spriteActive;
		for (n = 0; n < NSPR; n = n + 1)
			m_spriteBmp[n] <= 64'd0;
		tGoto(st_sprite_acc);
	end
st_sprite_acc:
	if (spriteActiveB[spriteno]) begin
		spriteActiveB[spriteno] <= FALSE;
		tMemRead(spriteWaddr[spriteno], st_sprite_nack);
	end
	else begin
		spriteno <= nxtSprite;
		if (nxtSprite == 6'd63) begin
			local_sel <= FALSE;
			mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
			tRet();
		end
	end
st_sprite_nack:
	if (~imresp.ack||local_sel) begin
		local_sel <= FALSE;
		if (tocnt==8'd1)
			m_spriteBmp[spriteno] <= 64'hFFFFFFFFFFFFFFFF;
		else
			m_spriteBmp[spriteno] <= latched_data;
		spriteno <= nxtSprite;
		if (nxtSprite==6'd63) begin
			local_sel <= FALSE;
			mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
			tRet();
		end
		else
			tGoto (st_sprite_acc);
	end
