import const_pkg::*;
import cpu_types_pkg::*;
import wishbone_pkg::*;

module mmu2_tb();
reg rst;
reg clk;

initial begin
	rst = 0;
	clk = 0;
	#1 rst = 1;
	#100 rst = 0;
end

always
	#5 clk = ~clk;

typedef enum logic [7:0] {
	st_idle = 0,
	st_xlat1,
	st_xlat1a,
	st_xlat2,
	st_xlat3,
	st_xlat4,
	st_xlat5
} state_t;

state_t state;
integer count,n1;
reg g_paging_en = 1'b1;
address_t nsc_tlb_base_adr = 32'hFFF40000;
address_t sc_tlb_base_adr  = 32'hFFF44000;
reg sc_flush_en = 1'b0;
reg nsc_flush_en = 1'b0;
wire sc_flush_done;
wire nsc_flush_done;
reg cs_sc_tlb = 1'b0;
reg cs_nsc_tlb = 1'b0;
reg cs_rgn = 1'b0;
reg store = 1'b0;
wire [255:0] region_dat;
reg [7:0] cpl = 8'h00;
reg [1:0] om;
wb_bus_interface #(.DATA_WIDTH(256)) sbus();
wb_bus_interface #(.DATA_WIDTH(256)) mbus();
address_t vadr;
reg vadr_v = 1'b0;
asid_t asid;
address_t padr;
wire padr_v;
reg clear_fault = 1'b0;
wire page_fault;
wire all_ways_locked;
wire priv_err;
reg [5:0] iv_count = 6'd0;
wire rst_busy;
ptbr_t ptbr;
ptattr_t pt_attr;
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

assign sbus.rst = rst;
assign mbus.rst = rst;
assign sbus.clk = clk;
assign mbus.clk = clk;

mmu2
#(
	.SHORTCUT(1),
	.TLB_ENTRIES(512),
	.LOG_PAGESIZE(13)
)
ummu21
(
	.rst(rst),
	.clk(clk),
	.g_paging_en(g_paging_en),
	.nsc_tlb_base_adr(nsc_tlb_base_adr),
	.sc_tlb_base_adr(sc_tlb_base_adr),
	.pt_attr(pt_attr),
	.ptbr(ptbr),
	.sc_flush_en(sc_flush_en),
	.nsc_flush_en(nsc_flush_en),
	.sc_flush_done(sc_flush_done),
	.nsc_flush_done(nsc_flush_done),
	.cs_sc_tlb(cs_sc_tlb),
	.cs_nsc_tlb(cs_nsc_tlb),
	.cs_rgn(cs_rgn),
	.store(store),
	.region_dat(region_dat),
	.cpl(cpl),
	.om(om),
	.sbus(sbus),
	.mbus(mbus),
	.vadr(vadr),
	.vadr_v(vadr_v),
	.asid(asid),
	.iv_count(iv_count),
	.padr(padr),
	.padr_v(padr_v),
	.tlb_v(tlb_v),
	.clear_fault(clear_fault),
	.page_fault(page_fault),
	.all_ways_locked(all_ways_locked),
	.priv_err(priv_err),
	.rst_busy(rst_busy)
);

always_ff @(posedge clk)
if (rst|rst_busy) begin
	pt_attr = {$bits(ptattr_t){1'b0}};
	pt_attr.level = 3'd2;
	asid <= 0;//$urandom(0) & 16'hffff;
	sbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
	mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
	count <= 0;
	vadr <= 32'h0;
	vadr_v <= INV;
	ptbr <= 32'hFFF80000;
	tGoto(st_idle);
end
else begin
	case(state)
	// Try an easy translation that should be present after a reset.
	st_idle:
		begin
			vadr <= 32'hFFF80000;
			vadr_v <= VAL;
			tGoto(st_xlat1);
		end
	// This translation should use a shortcut page.
	st_xlat1:
		if (padr_v & tlb_v) begin
			vadr <= 32'hD0000000;
			vadr_v <= VAL;
			tGoto(st_xlat1a);
		end
		else if (page_fault) begin
			$finish;
		end
	st_xlat1a:
		begin
			tGoto(st_xlat2);
		end
	st_xlat2:
		if (padr_v & tlb_v) begin
			vadr = 32'hFFF80000 | ($urandom() & 32'h7ffff);
			vadr_v <= VAL;
			count <= count + 1;
			if (count > 30) begin
				count <= 0;
				tGoto(st_xlat3);
			end
		end
		else if (page_fault) begin
			$finish;
		end
	st_xlat3:
		if (padr_v & tlb_v) begin
			vadr = $urandom();
			vadr_v <= VAL;
			count <= count + 1;
			if (count > 30)
				tGoto(st_xlat5);
			else
				tGoto(st_xlat4);
		end
		else if (page_fault) begin
			$finish;
		end
	st_xlat4:
		tGoto(st_xlat3);
	st_xlat5:
		if (padr_v & tlb_v) begin
			$finish;
		end
		else if (page_fault) begin
			$finish;
		end
	default:	state <= st_idle;
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

task tGoto;
input state_t nst;
begin
	state <= nst;
end
endtask


endmodule
