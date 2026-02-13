import const_pkg::*;
import cpu_types_pkg::*;
import mmu_pkg::*;

module tlb_tb();
parameter LOG_PAGESIZE = 13;
reg rst;
reg clk;

typedef enum logic [7:0] {
	st_reset = 0,
	st_1, st_2, st_2a, st_2b,
	st_3, st_4,
	st_add_xlat,
	st_add_xlat2,
	st_add_xlat3,
	st_add_xlat4,
	st_add_xlat5,
	st_add_xlat6,
	st_add_xlat7,
	st_add_xlat8,
	st_add_xlat9,
	st_add_xlat10,
	st_add_xlat11,
	st_asid1,
	st_asid2,
	st_asid2a,
	st_asid3,
	st_asid4,
	st_asid5,
	st_asid6,
	st_asid7,
	st_asid8,
	st_asid9,
	st_asid10,
	st_asid11
} state_t;

integer count,padrv_cnt;
state_t state;
wb_bus_interface #(.DATA_WIDTH(64)) bus();
reg cs_tlb;
reg paging_en;
reg store;
reg [7:0] id;
asid_t asid;
virtual_address_t vadr;
reg vadr_v;
physical_address_t padr;
wire padr_v;
wire tlb_v;
reg missack;
address_t miss_adr_o;
asid_t miss_asid_o;
wire [7:0] miss_id_o;
wire miss_o;
address_t miss_adr;
tlb_entry_t tlbe;
address_t mmu_adr;
reg idle;
reg [3:0] iv_count = 4'd0;

initial begin
	rst = 0;
	clk = 0;
	#1 rst = 1;
	#100 rst = 0;
end

always
	#5 clk = ~clk;

assign bus.rst = rst;
assign bus.clk = clk;

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
	.miss_adr_o(miss_adr_o),
	.miss_asid_o(miss_asid_o),
	.miss_id_o(miss_id_o),
	.miss_o(miss_o)
);

always_ff @(posedge clk)
if (rst) begin
	state <= st_reset;
	cs_tlb <= LOW;
	paging_en <= FALSE;
	store <= FALSE;
	id <= 8'h00;
	asid <= 16'h0000;
	vadr <= 32'h0;
	mmu_adr <= 32'hFEF00000;
	vadr_v <= INV;
	missack <= FALSE;
	bus.req <= {$bits(wb_cmd_request64_t){1'b0}};
	count <= 0;
	padrv_cnt <= 0;
	idle = 1;
end
else begin
	case(state)
	// Choose a random address in the preset translations area.
	st_reset:
		begin
			paging_en <= TRUE;
			vadr <= 32'hFFFC0000 | ($urandom() & 32'h3FFFF);
			vadr_v <= VAL;
			state <= st_1;
		end
	st_1:
		if (tlb_v) begin
			count <= count + 1;
			if (count < 20) begin
				vadr <= 32'hFFFC0000 | ($urandom() & 32'h3FFFF);
				vadr_v <= VAL;
				state <= st_1;
			end
			else begin
				count <= 0;
				state <= st_2;
			end
		end
	st_2:
		begin
			vadr <= $urandom();
			vadr_v <= VAL;
			state <= st_2b;
		end
	st_2a:
		state <= st_3;
	st_2b:
		if (tlb_v) begin
			vadr[12:0] <= $urandom() & 32'h1fff;
			vadr_v <= VAL;
			state <= st_2a;
		end
		else if (miss_o) begin
			padrv_cnt <= 0;
			missack <= 1'b1;
			miss_adr <= miss_adr_o;
			state <= st_add_xlat;
		end
	st_3:
		begin
			count <= count + 1;
			if (tlb_v) begin
				padrv_cnt <= padrv_cnt + 1;
				if (padrv_cnt > 30)
					$finish;
				if (count < 40000) begin
					if (($random() & 32'hff) > 13)
						state <= st_3;
					else
						state <= st_2;
				end
				else
					state <= st_4;		
			end
			else if (miss_o) begin
				padrv_cnt <= 0;
				missack <= 1'b1;
				miss_adr <= miss_adr_o;
				state <= st_add_xlat;
			end
		end
	st_4:
		begin
			$finish;
		end
	st_add_xlat:
		begin
			missack <= 1'b0;
			idle <= 0;
			paging_en <= FALSE;
			tlbe <= {$bits(tlb_entry_t){1'b0}};
			tlbe.vpn <= miss_adr[31:LOG_PAGESIZE+9];
			tlbe.asid <= asid;
			// pick a page at random
			tlbe.pte.v <= VAL;
			tlbe.pte.rgn <= $random() & 7;
			tlbe.pte.g <= FALSE;
			tlbe.pte.a <= FALSE;
			tlbe.pte.m <= FALSE;
			tlbe.pte.typ <= PTE;
			tlbe.pte.u <= $random() & 1;
			tlbe.pte.rwx <= $random() & 7;
			tlbe.pte.ppn <= $urandom() & 16'hFFFF;
			state <= st_add_xlat2;
		end
	st_add_xlat2:
		begin
			cs_tlb <= HIGH;
			bus.req.cyc <= HIGH;
			bus.req.stb <= HIGH;
			bus.req.we <= HIGH;
			bus.req.sel <= 8'hFF;
			bus.req.adr <= 32'h0;//mmu_adr | ({(miss_adr >> LOG_PAGESIZE),4'b0000} & 32'h01FFF);
			bus.req.dat <= tlbe[63:0];
			state <= st_add_xlat3;
		end
	st_add_xlat3:
		if (bus.resp.ack) begin
			cs_tlb <= LOW;
			bus.req <= {$bits(wb_cmd_request64_t){1'b0}};
			state <= st_add_xlat4;
		end
	st_add_xlat4:
		begin
			cs_tlb <= HIGH;
			bus.req.cyc <= HIGH;
			bus.req.stb <= HIGH;
			bus.req.we <= HIGH;
			bus.req.sel <= 8'hFF;
			bus.req.adr <= 32'h8;//mmu_adr | ({(miss_adr >> LOG_PAGESIZE),4'b1000} & 32'h01FFF);
			bus.req.dat <= tlbe[127:64];
			state <= st_add_xlat5;
		end
	st_add_xlat5:
		if (bus.resp.ack) begin
			cs_tlb <= LOW;
			bus.req <= {$bits(wb_cmd_request64_t){1'b0}};
			state <= st_add_xlat6;
		end
	// Write entry number and way to update
	st_add_xlat6:
		begin
			cs_tlb <= HIGH;
			bus.req.cyc <= HIGH;
			bus.req.stb <= HIGH;
			bus.req.we <= HIGH;
			bus.req.sel <= 8'hFF;
			bus.req.adr <= 32'h20;//mmu_adr | ({(miss_adr >> LOG_PAGESIZE),4'b1000} & 32'h01FFF);
			bus.req.dat <= ((miss_adr >> LOG_PAGESIZE) & 32'h1ff) | 32'h80030000;	// way 3
			state <= st_add_xlat7;
		end
	st_add_xlat7:
		if (bus.resp.ack) begin
			cs_tlb <= LOW;
			bus.req <= {$bits(wb_cmd_request64_t){1'b0}};
			state <= st_add_xlat10;
		end
	// Write trigger register (defunct)
	st_add_xlat8:
		begin
			cs_tlb <= HIGH;
			bus.req.cyc <= HIGH;
			bus.req.stb <= HIGH;
			bus.req.we <= HIGH;
			bus.req.sel <= 8'hFF;
			bus.req.adr <= 32'h38;//mmu_adr | ({(miss_adr >> LOG_PAGESIZE),4'b1000} & 32'h01FFF);
			bus.req.dat <= 32'h00000;	// way 0
			state <= st_add_xlat9;
		end
	st_add_xlat9:
		if (bus.resp.ack) begin
			cs_tlb <= LOW;
			bus.req <= {$bits(wb_cmd_request64_t){1'b0}};
			state <= st_add_xlat10;
		end
	st_add_xlat10:
		begin
			idle <= 1;
			paging_en <= TRUE;
//			vadr <= miss_adr;
			state <= st_add_xlat11;
		end
	st_add_xlat11:
		state <= st_asid1;
	st_asid1:
		if (tlb_v) begin
			$display("Test ASID matching.");
			vadr <= 32'hFFF80025;
			asid <= 16'h1234;
			state <= st_asid2;
		end
		else if (miss_o)
				miss_adr <= miss_adr_o;
	st_asid2a:
		state <= st_asid2;
	st_asid2:
		begin
			if (tlb_v) begin
				$display("ASID should not have matched.");
				$finish;
			end
			if (miss_o) begin
				state <= st_asid3;
			end
		end
	// Unlock the entries
	st_asid3:
		begin
			$display("Test unlock entries.");
			paging_en <= FALSE;
			cs_tlb <= HIGH;
			bus.req.cyc <= HIGH;
			bus.req.stb <= HIGH;
			bus.req.we <= HIGH;
			bus.req.sel <= 8'hFF;
			bus.req.adr <= 32'h28;//mmu_adr | ({(miss_adr >> LOG_PAGESIZE),4'b1000} & 32'h01FFF);
			bus.req.dat <= 32'h00000;	// way 0
			state <= st_asid4;
		end
	// Add an entry with a matching asid
	st_asid4:
		if (bus.resp.ack) begin
			bus.req <= {$bits(wb_cmd_request64_t){1'b0}};
			tlbe <= {$bits(tlb_entry_t){1'b0}};
			tlbe.vpn <= vadr[31:LOG_PAGESIZE+9];
			tlbe.asid <= 16'h1234;
			// pick a page at random
			tlbe.pte.v <= VAL;
			tlbe.pte.rgn <= $random() & 7;
			tlbe.pte.g <= FALSE;
			tlbe.pte.a <= FALSE;
			tlbe.pte.m <= FALSE;
			tlbe.pte.typ <= PTE;
			tlbe.pte.u <= $random() & 1;
			tlbe.pte.rwx <= $random() & 7;
			tlbe.pte.ppn <= 32'hFFF80000 >> LOG_PAGESIZE;
			state <= st_asid5;
		end
	st_asid5:
		begin
			bus.req.cyc <= HIGH;
			bus.req.stb <= HIGH;
			bus.req.we <= HIGH;
			bus.req.sel <= 8'hFF;
			bus.req.adr <= 32'h00;//mmu_adr | ({(miss_adr >> LOG_PAGESIZE),4'b1000} & 32'h01FFF);
			bus.req.dat <= tlbe[63:0];
			state <= st_asid6;
		end
	st_asid6:
		if (bus.resp.ack) begin
			bus.req <= {$bits(wb_cmd_request64_t){1'b0}};
			state <= st_asid7;
		end
	st_asid7:
		begin
			bus.req.cyc <= HIGH;
			bus.req.stb <= HIGH;
			bus.req.we <= HIGH;
			bus.req.sel <= 8'hFF;
			bus.req.adr <= 32'h08;//mmu_adr | ({(miss_adr >> LOG_PAGESIZE),4'b1000} & 32'h01FFF);
			bus.req.dat <= tlbe[127:64];
			state <= st_asid8;
		end
	st_asid8:
		if (bus.resp.ack) begin
			bus.req <= {$bits(wb_cmd_request64_t){1'b0}};
			state <= st_asid9;
		end
	st_asid9:
		begin
			cs_tlb <= HIGH;
			bus.req.cyc <= HIGH;
			bus.req.stb <= HIGH;
			bus.req.we <= HIGH;
			bus.req.sel <= 8'hFF;
			bus.req.adr <= 32'h20;//mmu_adr | ({(miss_adr >> LOG_PAGESIZE),4'b1000} & 32'h01FFF);
			bus.req.dat <= ((vadr >> LOG_PAGESIZE) & 32'h1ff) | 32'h80030000;	// way 3
			state <= st_asid10;
		end
	st_asid10:
		if (bus.resp.ack) begin
			paging_en <= TRUE;
			cs_tlb <= LOW;
			bus.req <= {$bits(wb_cmd_request64_t){1'b0}};
			state <= st_asid11;
		end
	st_asid11:
		begin
			if (tlb_v)
				state <= st_3;
		end
	default:	state <= st_reset;
	endcase
end
	
endmodule
