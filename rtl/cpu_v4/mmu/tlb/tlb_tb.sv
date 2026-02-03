import const_pkg::*;
import cpu_types_pkg::*;

module tlb_tb();
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
	st_add_xlat7
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

tlb utlb1
(
	.clk(clk),
	.bus(bus),
	.stall(1'b0),
	.paging_en(paging_en),
	.cs_tlb(cs_tlb),
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
		if (padr_v) begin
			count <= count + 1;
			if (count < 20)
				state <= st_reset;
			else begin
				count <= 0;
				state <= st_2;
			end
		end
	st_2:
		begin
			vadr <= $urandom();
			vadr_v <= VAL;
			state <= st_2a;
		end
	st_2a:
		state <= st_3;
	st_2b:
		begin
			vadr[15:0] <= $urandom() & 32'hffff;
			vadr_v <= VAL;
			state <= st_2a;
		end
	st_3:
		begin
			count <= count + 1;
			if (padr_v) begin
				padrv_cnt <= padrv_cnt + 1;
				if (padrv_cnt > 30)
					$finish;
				if (count < 40000) begin
					if (($random() & 32'hff) > 13)
						state <= st_2b;
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
			paging_en <= FALSE;
			tlbe <= {$bits(tlb_entry_t){1'b0}};
			tlbe.vpn.vpn <= miss_adr[31:16];
			tlbe.vpn.asid <= asid;
			// pick a page at random
			tlbe.pte.v <= VAL;
			tlbe.pte.rgn <= $random() & 7;
			tlbe.pte.g <= FALSE;
			tlbe.pte.a <= FALSE;
			tlbe.pte.m <= FALSE;
			tlbe.pte.s <= FALSE;
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
			bus.req.adr <= mmu_adr | ({(miss_adr >> 16),4'b0000} & 32'h01FFF);
			bus.req.dat <= tlbe[63:0];
			vadr <= mmu_adr | ({(miss_adr >> 16),4'b0000} & 32'h01FFF);
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
			bus.req.adr <= mmu_adr | ({(miss_adr >> 16),4'b1000} & 32'h01FFF);
			bus.req.dat <= tlbe[127:64];
			vadr <= mmu_adr | ({(miss_adr >> 16),4'b1000} & 32'h01FFF);
			state <= st_add_xlat5;
		end
	st_add_xlat5:
		if (bus.resp.ack) begin
			cs_tlb <= LOW;
			bus.req <= {$bits(wb_cmd_request64_t){1'b0}};
			vadr <= 32'd0;
			state <= st_add_xlat6;
		end
	st_add_xlat6:
		begin
			paging_en <= TRUE;
			vadr <= miss_adr;
			state <= st_add_xlat7;
		end
	st_add_xlat7:
		state <= st_3;
	default:	state <= st_reset;
	endcase
end
	
endmodule
