import const_pkg::*;
import wishbone_pkg::*;
import hash_table_pkg::*;

module hash_table_tb();
reg rst;
reg clk;
reg [5:0] state;
reg [12:0] count;
integer cnt,ecnt,bcnt,ma,bncnt;
integer asid_cnt;
real f,fb;
reg cs;
wire [31:0] padr;
reg [9:0] asid;
wire page_fault;
wire [31:0] fault_adr;
wire [9:0] fault_asid;
wire [17:0] fault_group;
wb_cmd_request64_t req;
wb_cmd_response64_t resp;
wb_cmd_request64_t vreq;
wb_cmd_response64_t vresp;
ptge_t ptge;
reg [9:0] asid_to_free;

initial begin
	clk = 1'b0;
	rst = 1'b0;
	#1 rst = 1'b1;
	#100 rst = 1'b0;
end

always
	#2.5 clk = ~clk;

wire [3:0] ffo;
ffo12 uffo1 (.i({4'h0,fault_group[7:0]}), .o(ffo));

hash_table uht1
(
	.rst(rst),
	.clk(clk),
	.cs(cs),
	.req(req),
	.resp(resp),
	.asid(asid),
	.vreq(vreq),
	.vresp(vresp),
	.padr(padr),
	.padrv(padrv),
	.max_bounce(8'd63),
	.page_fault(page_fault),
	.fault_group(fault_group),
	.fault_adr(fault_adr),
	.fault_asid(fault_asid)
);

always_ff @(posedge clk)
if (rst) begin
	state <= 6'd0;
	count <= 10'd0;
	cs <= LOW;
	req <= {$bits(wb_cmd_request64_t){1'b0}};
	vreq <= {$bits(wb_cmd_request64_t){1'b0}};
	ptge <= {$bits(ptge_t){1'b0}};
	asid <= 10'h0;
	asid_cnt <= 0;
	asid_to_free <= 0;
	cnt <= $urandom(0);
	cnt <= 0;
	bcnt <= 0;
	bncnt <= 0;
	ecnt <= 0;
	ma <= 0;
end
else begin
	// First fill table with 1:1 translation
	case(state)
	6'd0:
		begin
			cs <= LOW;
			ptge.v <= VAL;
			ptge.a <= FALSE;
			ptge.m <= FALSE;
			ptge.s <= FALSE;
			ptge.u <= count[9];
			ptge.rwx <= count[2:0];
			ptge.ppn <= count >> 21;
			ptge.vpn <= count >> 21;
			ptge.cache <= $urandom() & 3;
			ptge.rgn <= $urandom() & 7;
			ptge.asid <= count;
			ecnt <= ecnt + 1;
			state <= 6'd1;
		end
	6'd1:
		begin
			cs <= HIGH;
			req.cyc <= HIGH;
			req.stb <= HIGH;
			req.we <= HIGH;
			req.dat <= ptge;
			req.sel <= 8'hFF;
			req.adr <= {count,3'b0};
			state <= 6'd2;
		end
	6'd2:
		if (resp.ack) begin
			cs <= LOW;
			req.cyc <= LOW;
			req.stb <= LOW;
			req.we <= LOW;
			req.sel <= 8'h00;
			count <= count + 1;
			state <= 6'd16;
		end
	6'd16:
		if (!resp.ack) begin
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
				vreq.cyc <= HIGH;
				vreq.stb <= HIGH;
				vreq.adr <= (($urandom() & 10'h3ff) << 18) | ($urandom() & 18'h3FFFF);
				vreq.we <= $urandom() & 1;
				asid <= $urandom() & 10'h3ff;
				// First ten addresses should not be translated.
				if (cnt < 10)
					vreq.adr[31] <= 1'b1;
				state <= 6'd4;
			end
		end
	6'd4:
		if (padrv) begin
			vreq.cyc <= LOW;
			vreq.stb <= LOW;
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
					vreq.cyc <= HIGH;
					vreq.stb <= HIGH;
					vreq.adr[17:0] <= $urandom() & 32'h3ffff;
				end
				else begin
					ma <= ma + 1;
					vreq.cyc <= HIGH;
					vreq.stb <= HIGH;
					vreq.adr <= $urandom() & 32'h1fffffff;
					asid <= $urandom() & 10'h3ff;
				end
			end
			state <= 6'd6;
		end
	// On a page fault, add the page.
	6'd6:
		begin
			req.cyc <= LOW;
			req.stb <= LOW;
			vreq.cyc <= LOW;
			vreq.stb <= LOW;
			if (page_fault) begin
				bncnt <= bncnt + uht1.bounce;
				cs <= LOW;
				ptge.v <= VAL;
				ptge.a <= FALSE;
				ptge.m <= FALSE;
				ptge.s <= FALSE;
				ptge.u <= $urandom() & 1;
				ptge.rwx <= $urandom() & 7;
				ptge.ppn <= $urandom() >> 18;
				ptge.vpn <= vreq.adr >> 18;
				ptge.cache <= $urandom() & 3;
				ptge.rgn <= $urandom() & 7;
				ptge.asid <= 0;//asid;
				ecnt <= ecnt + 1;
				state <= 6'd13;
				vreq.adr[31] <= 1'b1;	// clear page fault
			end
			else if (padrv)
				state <= 6'd5;
			asid_to_free <= $urandom() & 10'h3ff;
			asid_cnt <= asid_cnt + 1;
			if (asid_cnt>=10) begin
				state <= 6'd15;				
				asid_cnt <= 0;
			end
		end
	6'd15:
		begin
			cs <= HIGH;
			req.cyc <= HIGH;
			req.stb <= HIGH;
			req.we <= HIGH;
			req.adr <= 32'h10000;
			req.dat <= asid_to_free;
			state <= 6'd6;
		end
	// read the fault group, fault group is not valid until a cycle later
	6'd13:	
		begin
			state <= 6'd7;
		end
	6'd7:
		begin
			if (~|fault_group[7:0]) begin
				state <= 6'd59;	// table full
			end
			else begin
				cs <= HIGH;
				req.cyc <= HIGH;
				req.stb <= HIGH;
				req.we <= LOW;
				req.sel <= 8'hFF;
				req.adr <= {fault_group[17:8],ffo[2:0],3'b0};
				state <= 6'd8;
			end
		end
	6'd8:
		if (resp.ack) begin
			cs <= LOW;
			req.cyc <= LOW;
			req.stb <= LOW;
			req.we <= LOW;
			req.sel <= 8'h00;
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
			state <= 6'd17;
		end
	6'd17:
		if (!resp.ack)
			state <= 6'd9;
	6'd9:
		begin
			cs <= HIGH;
			req.cyc <= HIGH;
			req.stb <= HIGH;
			req.we <= HIGH;
			req.dat <= ptge;
			req.sel <= 8'hFF;
			req.adr <= {fault_group[17:8],ffo[2:0],3'b0};
			state <= 6'd10;
		end		
	6'd10:
		if (resp.ack) begin
			cs <= LOW;
			req.cyc <= LOW;
			req.stb <= LOW;
			req.we <= LOW;
			req.sel <= 8'h00;
			state <= 6'd18;
		end
	6'd18:
		if (!resp.ack)
			state <= 6'd11;
	6'd11:
		begin
			vreq.adr[31] <= 1'b0;
			state <= 6'd12;
		end
	6'd12:
		begin
			if (page_fault)
				state <= 6'd6;
			else if (padrv)
				state <= 6'd5;
		end
	6'd59:
		begin
			bcnt = 0;
			for (cnt = 0; cnt < 8192; cnt = cnt + 1)
				bcnt = bcnt + uht1.vb[cnt];
			state <= 6'd60;
		end
	6'd60:
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
