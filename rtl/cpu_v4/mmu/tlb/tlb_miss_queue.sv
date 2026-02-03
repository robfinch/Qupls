// Delay a few cycles to prevent a false PC miss. It takes a couple of cycles
// for the PC to reset.

import cpu_types_pkg::*;

module tlb_miss_queue(rst, clk, stall, rstcnt,
	miss_adr, miss_asid, miss_id, miss_v,
	missack, miss_adr_o, miss_asid_o, miss_id_o, miss_o);
parameter MISSQ_ENTRIES=16;
parameter WID=10;
input rst;
input clk;
input stall;
input [WID:0] rstcnt;
input address_t miss_adr;
input asid_t miss_asid;
input [7:0] miss_id;
input miss_v;
input missack;
output address_t miss_adr_o;
output asid_t miss_asid_o;
output reg [7:0] miss_id_o;
output reg miss_o;

integer n,n2;
reg inq;
reg [3:0] head, tail;
address_t [MISSQ_ENTRIES-1:0] missadr;
asid_t [MISSQ_ENTRIES-1:0] missasid;
reg [1:0] missqn [0:MISSQ_ENTRIES-1];
rob_ndx_t [MISSQ_ENTRIES-1:0] missid;

always_comb
begin
	inq = 1'b0;
	for (n = 0; n < MISSQ_ENTRIES; n = n + 1)
		if (miss_adr==missadr[n] && miss_asid==missasid[n])
			inq = 1'b1;
end

always_ff @(posedge clk)
if (rst) begin
	tail <= 4'd0;
	head <= 4'd0;
	miss_o <= 1'b0;
	miss_adr_o <= 32'd0;
	miss_asid_o <= 16'd0;
	miss_id_o <= 8'h00;
	foreach(missadr[n2]) begin
		missadr[n2] <= 32'd0;
		missasid[n2] <= 16'h0;
		missid[n2] <= 8'h00;
	end
end
else begin
	miss_o <= 1'b0;
	if (|rstcnt[WID:6] && (head != (tail - 1) % MISSQ_ENTRIES))
		case (miss_v & ~stall & ~inq)
		1'b0:	;
		1'b1:
			begin
				missadr[tail] <= miss_adr;
				missasid[tail] <= miss_asid;
				missid[tail] <= miss_id;
				tail <= (tail + 1) % MISSQ_ENTRIES;
			end
		endcase
	if (missack) begin
		head <= (head + 1) % MISSQ_ENTRIES;
	end
	if (head != tail && !missack) begin
		miss_adr_o <= missadr[head];
		miss_asid_o <= missasid[head];
		miss_id_o <= missid[head];
		miss_o <= 1'b1;
	end
end

endmodule
