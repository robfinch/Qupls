always_ff @(posedge clk)
if (rst) begin
	state <= IMSIC_IDLE;
	log_adr <= 64'h00010000;
	mreq.blen <= 6'd0;
	mreq.tid <= 13'd0;
	mreq.cmd <= fta_bus_pkg::CMD_NONE;
	mreq.cyc <= LOW;
	mreq.stb <= LOW;
	mreq.we <= LOW;
	mreq.sel <= 32'd0;
	mreq.data1 <= 256'd0;
end
else begin
	if (cs_io & reqd.we)
		case(reqd.padr[9:3])
		7'd16:	log_adr <= reqd.dat[63:0];
		default:	;
		endcase
	case (state)
	IMSIC_IDLE:
		begin
			if (irqo) begin
				mreq.tid <= {6'd62,3'd1,4'h1};
				mreq.cmd <= fta_bus_pkg::CMD_STORE;
				mreq.cyc <= HIGH;
				mreq.stb <= HIGH;
				mreq.we <= HIGH;
				mreq.sel <= log_adr[5] ? 32'hFFFF0000 : 32'h0000FFFF;
				mreq.adr <= (log_adr & log_adrmask) | (log_adr & ~log_adrmask);
				mreq.data1 <= {2{log_data}};
			end
		end
	endcase
end

