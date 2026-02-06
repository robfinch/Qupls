import const_pkg::*;
import wishbone_pkg::*;
import hash_table_pkg::*;

module hash_table_tb();
reg rst;
reg clk;
integer state;
reg [12:0] count;
integer cnt,ecnt,bcnt,bncnt,ma,pcnt;
real f,fb;
reg cs;
wire [31:0] padr;
reg [9:0] asid;
wire page_fault;
wire [31:0] fault_adr;
wire [9:0] fault_asid;
reg [9:0] fault_group;
reg [7:0] fault_valid;
reg [31:0] vadr;
wb_bus_interface #(.DATA_WIDTH(32)) bus();
hte_t hte;
wire [63:0] vb [0:127];

initial begin
	clk = 1'b0;
	rst = 1'b0;
	#10 rst = 1'b1;
	#100 rst = 1'b0;
end

always
	#2.5 clk = ~clk;

assign bus.clk = clk;
assign bus.rst = rst;

wire [3:0] ffo;
ffo12 uffo1 (.i({4'h0,~fault_valid}), .o(ffo));

hash_table #(.SIM(1)) uht1
(
	.cs(cs),
	.bus(bus),
	.padr(padr),
	.padrv(padrv),
	.page_fault(page_fault)
);

always_ff @(posedge clk)
if (rst) begin
	state <= 6'd0;
	count <= 10'd0;
	cs <= LOW;
	bus.req <= {$bits(wb_cmd_request32_t){1'b0}};
	hte <= {$bits(hte_t){1'b0}};
	asid <= 10'h0;
	cnt <= $urandom(0);
	cnt <= 0;
	bcnt <= 0;
	ecnt <= 0;
	bncnt <= 0;
	ma <= 0;
end
else begin
	// First fill table with 1:1 translation
	case(state)
	6'd0:
		begin
			cs <= LOW;
			hte.v <= VAL;
			hte.a <= FALSE;
			hte.m <= FALSE;
			hte.s <= FALSE;
			hte.u <= count[9];
			hte.rwx <= count[2:0];
			hte.ppn <= count >> 21;
			hte.vpn <= count >> 21;
			hte.cache <= $urandom() & 3;
			hte.rgn <= $urandom() & 7;
			hte.asid <= 0;//count;
			ecnt <= ecnt + 1;
			state <= 6'd1;
		end
	6'd1:
		begin
			cs <= HIGH;
			bus.req.cyc <= HIGH;
			bus.req.stb <= HIGH;
			bus.req.we <= HIGH;
			bus.req.sel <= 4'hF;
			bus.req.dat <= hte[31:0];
			bus.req.adr <= {count,3'b0};
			state <= 6'd2;
		end
	6'd2:
		if (bus.resp.ack) begin
			cs <= LOW;
			bus.req.cyc <= LOW;
			bus.req.stb <= LOW;
			bus.req.we <= LOW;
			count <= count + 1;
			state <= 6'd20;
		end
	6'd20:
		begin
			cs <= HIGH;
			bus.req.cyc <= HIGH;
			bus.req.stb <= HIGH;
			bus.req.we <= HIGH;
			bus.req.dat <= hte[63:32];
			bus.req.adr <= {count,3'b100};
			state <= 6'd21;
		end
	6'd21:
		if (bus.resp.ack) begin
			cs <= LOW;
			bus.req.cyc <= LOW;
			bus.req.stb <= LOW;
			bus.req.we <= LOW;
			count <= count + 1;
			if (count==10'h3FF)
				state <= 6'd3;
			else
				state <= 6'd0;
		end
	6'd3:
		begin
			if (page_fault) begin
				state <= 6'd6;
			end
			else begin
				// pick a random address
				ma <= ma + 1;
				bus.req.cyc <= HIGH;
				bus.req.stb <= HIGH;
				vadr = (($urandom() & 10'h1ff) << 18) | ($urandom() & 18'h3FFFF);
				bus.req.adr <= vadr;
				bus.req.we <= $urandom() & 1;
//				asid <= $urandom() & 10'h3ff;
				// First ten addresses should not be translated.
				if (cnt < 10)
					bus.req.adr[31] <= 1'b1;
				state <= 6'd4;
			end
		end
	6'd4:
		if (padrv) begin
			bus.req.cyc <= LOW;
			bus.req.stb <= LOW;
			bus.req.we <= LOW;
			cnt <= cnt + 1;
			state <= 6'd3;
		end
		else if (page_fault)
			state <= 6'd6;
	// pick completely random address
	6'd5:
		begin
			if (!page_fault) begin
				cnt <= cnt + 1;
				// stay on the same page for a while
				if (cnt < 50) begin
					ma <= ma + 1;
					bus.req.cyc <= HIGH;
					bus.req.stb <= HIGH;
					bus.req.adr[17:0] <= $urandom() & 32'h3ffff;
				end
				else begin
					ma <= ma + 1;
					bus.req.cyc <= HIGH;
					bus.req.stb <= HIGH;
					bus.req.adr <= $urandom() & 32'h1fffffff;
//					asid <= $urandom() & 10'h3ff;
				end
			end
			state <= 6'd6;
		end
	// On a page fault, add the page.
	6'd6:
		begin
			vadr <= bus.req.adr;
			bus.req.cyc <= LOW;
			bus.req.stb <= LOW;
			if (page_fault) begin
				bncnt <= bncnt + uht1.bounce;
				cs <= LOW;
				hte.v <= VAL;
				hte.a <= FALSE;
				hte.m <= FALSE;
				hte.s <= FALSE;
				hte.u <= $urandom() & 1;
				hte.rwx <= $urandom() & 7;
				hte.ppn <= $urandom() >> 18;
				hte.vpn <= vadr >> 18;
				hte.cache <= $urandom() & 3;
				hte.rgn <= $urandom() & 7;
				hte.asid <= 0;//asid;
				ecnt <= ecnt + 1;
				state <= 13;
				bus.req.adr[31] <= 1'b1;	// clear page fault
			end
			else if (padrv)
				state <= 6'd5;
		end
	// read the fault group, fault group is not valid until a cycle later
	13:	state <= 70;
	70:
		begin
			cs <= HIGH;
			bus.req.cyc <= HIGH;
			bus.req.stb <= HIGH;
			bus.req.we <= LOW;
			bus.req.sel <= 8'hFF;
			bus.req.adr <= 32'hFFF10408;	// fault group register
			state <= 71;
		end
	71:
		if (bus.resp.ack) begin
			cs <= LOW;
			bus.req.cyc <= LOW;
			bus.req.stb <= LOW;
			bus.req.we <= LOW;
			fault_group <= bus.resp.dat[17:8];
			fault_valid <= bus.resp.dat[7:0];
			state <= 7;
		end
	7:
		begin
			if (&fault_valid[7:0]) begin
				state <= 59;	// table full
			end
			else begin
				cs <= HIGH;
				bus.req.cyc <= HIGH;
				bus.req.stb <= HIGH;
				bus.req.we <= LOW;
				bus.req.sel <= 8'hFF;
				bus.req.adr <= {16'hFFFE,fault_group,ffo[2:0],3'b000};
				state <= 8;
			end
		end
	8:
		if (bus.resp.ack) begin
			cs <= LOW;
			bus.req.cyc <= LOW;
			bus.req.stb <= LOW;
			bus.req.we <= LOW;
//			hte[31:0] <= bus.resp.dat;
			/*
			ptge.v <= VAL;
			ptge.a <= FALSE;
			ptge.m <= FALSE;
			ptge.s <= FALSE;
			ptge.u <= $urandom() & 1;
			ptge.rwx <= $urandom() & 7;
			ptge.ppn <= $urandom() >> 18;
			ptge.vpn <= (vreq.adr & 32'h3fffffff) >> 18;
			ptge.cache <= $urandom() & 3;
			ptge.rgn <= $urandom() & 7;
			ptge.asid <= asid;
			*/
			state <= 81;
		end
	81:
		begin
			cs <= HIGH;
			bus.req.cyc <= HIGH;
			bus.req.stb <= HIGH;
			bus.req.we <= LOW;
			bus.req.sel <= 8'hFF;
			bus.req.adr <= {16'hFFFE,fault_group,ffo[2:0],3'b100};
			state <= 82;
		end
	82:
		if (bus.resp.ack) begin
			cs <= LOW;
			bus.req.cyc <= LOW;
			bus.req.stb <= LOW;
			bus.req.we <= LOW;
//			hte[63:32] <= bus.resp.dat;
			/*
			ptge.v <= VAL;
			ptge.a <= FALSE;
			ptge.m <= FALSE;
			ptge.s <= FALSE;
			ptge.u <= $urandom() & 1;
			ptge.rwx <= $urandom() & 7;
			ptge.ppn <= $urandom() >> 18;
			ptge.vpn <= (vreq.adr & 32'h3fffffff) >> 18;
			ptge.cache <= $urandom() & 3;
			ptge.rgn <= $urandom() & 7;
			ptge.asid <= asid;
			*/
			state <= 9;
		end
	9:
		begin
			cs <= HIGH;
			bus.req.cyc <= HIGH;
			bus.req.stb <= HIGH;
			bus.req.we <= HIGH;
			bus.req.dat <= hte[31:0];
			bus.req.sel <= 8'hFF;
			bus.req.adr <= {16'hFFFE,fault_group,ffo[2:0],3'b000};
			state <= 90;
		end		
	90:
		if (bus.resp.ack) begin
			cs <= LOW;
			bus.req.cyc <= LOW;
			bus.req.stb <= LOW;
			bus.req.we <= LOW;
			state <= 91;
		end
	91:
		begin
			cs <= HIGH;
			bus.req.cyc <= HIGH;
			bus.req.stb <= HIGH;
			bus.req.we <= HIGH;
			bus.req.dat <= hte[63:32];
			bus.req.adr <= {16'hFFFE,fault_group,ffo[2:0],3'b100};
			state <= 10;
		end		
	10:
		if (bus.resp.ack) begin
			cs <= LOW;
			bus.req.cyc <= LOW;
			bus.req.stb <= LOW;
			bus.req.we <= LOW;
			state <= 11;
		end
	// It takes a couple of cycle to  update
	11:
		begin
			state <= 12;
		end
	12:
		begin
			state <= 121;
		end
	121:
		begin
			state <= 122;
		end
	122:
		begin
			state <= 123;
		end
	// Retry faulted address.
	123:
		begin
			// pick a random address
			ma <= ma + 1;
			bus.req.cyc <= HIGH;
			bus.req.stb <= HIGH;
			bus.req.adr <= vadr;
			bus.req.adr[31] <= 1'b0;
			bus.req.we <= $urandom() & 1;
//				asid <= $urandom() & 10'h3ff;
			// First ten addresses should not be translated.
			state <= 120;
		end
	120:
		if (bus.resp.ack) begin
			bus.req.cyc <= LOW;
			bus.req.stb <= LOW;
			bus.req.we <= LOW;
		end
		else if (page_fault) begin
			state <= 6;
		end
		else
			state <= 5;
	59:
		begin
			bcnt = 0;
			for (cnt = 0; cnt < 128; cnt = cnt + 1)
				for (pcnt = 0; pcnt < 64; pcnt = pcnt + 1)
					bcnt = bcnt + uht1.vb[cnt][pcnt];
			state <= 60;
		end
	60:
		begin
			$display("Used entries: %d", bcnt);
			$display("Bounces per accesss: %f", real'(bncnt)/real'(ma));
			$finish;
		end
	default:	;
	endcase
end

always_ff @(posedge clk)
	f = real'(ecnt)/real'(8192) * 100.0;
always_ff @(posedge clk)
	fb = real'(bcnt)/real'(8192) * 100.0;
	
endmodule
