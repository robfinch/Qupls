import cpu_types_pkg::*;
import wishbone_pkg::*;

module Qupls4_copro_tb();
parameter LOG_PAGESIZE = 13;
reg rst;
reg clk;
reg vclk;
integer state;

integer n1;
wb_bus_interface #(.DATA_WIDTH(64)) bus();
wb_bus_interface #(.DATA_WIDTH(64)) sbus();
wb_bus_interface #(.DATA_WIDTH(256)) mbus();
wb_bus_interface #(.DATA_WIDTH(256)) vmbus();
asid_t asid = 16'h0000;
reg [7:0] id = 8'h00;
address_t vadr;
reg vadr_v;
reg store;
address_t padr;
wire padr_v;
wire tlb_v;
wire missack;
wire idle;
reg cs_tlb;
reg [3:0] iv_count = 4'h0;
wire miss;
address_t miss_adr;
asid_t miss_asid;
wire [7:0] miss_id;
wire paging_en;
wire page_fault;
wire rst_busy;
reg hsync = 1'b0;
reg vsync = 1'b0;
reg gfx_que_empty = 1'b1;

pte_t test_pte;

reg [255:0] mem [0:8191];
initial begin
	test_pte = {$bits(pte_t){1'b0}};
	test_pte.v = VAL;
	test_pte.u = $urandom() & 1;
	test_pte.rwx = $urandom() & 7;
	test_pte.ppn = 32'h21000 >> 13;
	mem[0] = {8{test_pte}};
	for (n1 = 0; n1 < $size(mem); n1 = n1 + 1)
		mem[n1] = {8{$urandom()|32'h80000000}};
end


initial begin
	rst = 0;
	clk = 0;
	vclk = 0;
	#1 rst = 1;
	#100 rst = 0;
end

always
	#5 clk = ~clk;
always
	#12.5 vclk = ~vclk;

assign bus.rst = rst;
assign bus.clk = clk;
assign sbus.rst = rst;
assign sbus.clk = clk;
assign mbus.rst = rst;
assign mbus.clk = clk;
assign bus.req.cyc = mbus.req.cyc;
assign bus.req.stb = mbus.req.stb;
assign bus.req.we = mbus.req.we;
assign bus.req.sel = mbus.req.sel >> {mbus.req.adr[4:3],3'b0};
assign bus.req.adr = mbus.req.adr;
assign bus.req.dat = mbus.req.dat >> {mbus.req.adr[4:3],6'b0};
//assign mbus.resp.ack = bus.resp.ack;
//assign mbus.resp.dat = {4{bus.resp.dat}};

always_comb
	cs_tlb = mbus.req.cyc & mbus.req.stb & mbus.req.adr[31:16]==16'hFFF4;

tlb
#(
	.LOG_PAGESIZE(LOG_PAGESIZE)
)
utlb1
(
	.clk(clk),
	.bus(bus),
	.idle(idle),
	.stall(1'b0),
	.paging_en(paging_en),
	.cs_tlb(cs_tlb),
	.iv_count(iv_count),
	.store_i(store),
	.id(id),
	.asid(asid),
	.vadr(vadr),
	.vadr_v(vadr_v),
	.padr(padr),
	.padr_v(padr_v),
	.tlb_v(tlb_v),
	.missack(missack),
	.miss_adr_o(miss_adr),
	.miss_asid_o(miss_asid),
	.miss_id_o(miss_id),
	.miss_o(miss),
	.rst_busy(rst_busy)
);

Qupls4_copro ucopro1
(
	.rst(rst),
	.clk(clk),
	.sbus(sbus),
	.mbus(mbus),
	.vmbus(vmbus),
	.cs_copro(1'b0),
	.miss(miss),
	.miss_adr(miss_adr),
	.miss_asid(miss_asid),
	.missack(missack),
	.idle(idle),
  .paging_en(paging_en),
  .page_fault(page_fault),
  .iv_count(4'h0),
  .vclk(vclk),
  .hsync_i(hsync),
  .vsync_i(vsync),
  .gfx_que_empty_i(gfx_que_empty)
);

always_ff @(posedge clk)
if (rst) begin
	state <= 1;
end
else begin
	case(state)
	1:
		begin
			vadr <= 32'h12340000;
			vadr_v <= VAL;
			store <= FALSE;
		end
	default:	state <= 1;
	endcase
end

reg [7:0] mbus_state;
always_ff @(posedge clk)
if (rst|rst_busy) begin
	mbus_state <= 0;
end
else begin
	case(mbus_state)
	0:
		if (mbus.req.cyc & mbus.req.stb) begin
			if (mbus.req.we)
				mem[mbus.req.adr[17:5]] <= {4{mbus.req.dat}};
			else
				mbus.resp.dat <= mem[mbus.req.adr[17:5]];
			mbus.resp.ack <= HIGH;
			mbus_state <= 1;
		end
	1:
		if (!(mbus.req.cyc & mbus.req.stb)) begin
			mbus.resp.ack <= LOW;
			mbus_state <= 0;
		end
	default:	mbus_state <= 0;
	endcase
end


endmodule
