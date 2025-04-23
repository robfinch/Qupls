import const_pkg::*;
import Stark_pkg::*;

module Stark_checkpoint_manager(rst, clk, clk5x, ph4, backout_st2, fcu_id,
	pgh, setcp, setcp_grp, cndx, freecp, freecp_grp, alloc_chkpt, restore, miss_cp);
input rst;
input clk;
input clk5x;
input [4:0] ph4;
input [1:0] backout_st2;
input rob_ndx_t fcu_id;
input pipeline_group_hdr_t [ROB_ENTRIES/4-1:0] pgh;
output reg setcp;
output reg [5:0] setcp_grp;
output wire freecp;
output wire [5:0] freecp_grp;
output reg alloc_chkpt;

// Checkpoint index. Allocates with a new conditional branch. Future
// instructions will read from the checkpoint files at cndx.
// This is the index used to read the checkpoint RAMs.
// Want the checkpoint to take effect for the next group of instructions.
output checkpt_ndx_t cndx;
input restore;
input checkpt_ndx_t miss_cp;

reg ialloc_chkpt;
wire free_chkpt;
assign freecp = free_chkpt;
reg free_chkpt2;
checkpt_ndx_t fchkpt2;
checkpt_ndx_t [3:0] avail_chkpt;

integer n1;
reg alloc_chkpt = 1'b0;
wire chkpt_stall;
reg [5:0] gndx;
reg [5:0] gndx2;

reg [2:0] wcnt;
always_ff @(posedge clk5x)
if (rst)
	wcnt <= 3'd0;
else begin
	if (ph4[1])
		wcnt <= 3'd0;
	else if (wcnt < 3'd4)
		wcnt <= wcnt + 2'd1;
end

typedef enum logic [1:0] 
{
	CHKPT_IDLE = 2'd0,
	CHKPT_ALLOC1 = 2'd1,
	CHKPT_ALLOC2 = 2'd2,
	CHKPT_SET = 2'd3
} state_t;
state_t state;

// Set checkpoint index
// Backup the checkpoint on a branch miss.
// Allocate checkpoint on a branch queue

always_ff @(posedge clk)
if (rst) begin
	state <= CHKPT_IDLE;
	alloc_chkpt <= FALSE;
	ialloc_chkpt <= FALSE;
	setcp <= FALSE;
	cndx <= {$bits(checkpt_ndx_t){1'b0}};
end
else begin
	ialloc_chkpt <= FALSE;
	alloc_chkpt <= FALSE;
	setcp <= FALSE;
	case (state)
	CHKPT_IDLE:
		begin
			if (restore) begin
				$display("Restoring checkpint %d.", miss_cp);
				cndx <= miss_cp;
			end
			for (n1 = 0; n1 < ROB_ENTRIES/4; n1 = n1 + 1) begin
				if (pgh[n1].v && pgh[n1].has_branch && !pgh[n1].cndxv) begin
					ialloc_chkpt <= TRUE;
					setcp_grp <= n1;
					state <= CHKPT_ALLOC1;
				end
				else if (pgh[n1].v && !pgh[n1].cndxv) begin
					setcp_grp <= n1;
					state <= CHKPT_SET;
				end
			end
		end
	CHKPT_ALLOC1:
		state <= CHKPT_ALLOC2;
	CHKPT_ALLOC2:
		if (!chkpt_stall) begin
			$display("Setting new checkpoint %d.", avail_chkpt[0]);
			alloc_chkpt <= TRUE;
			cndx <= avail_chkpt[0];
			setcp <= TRUE;
			state <= CHKPT_IDLE;
		end
	CHKPT_SET:
		begin
			$display("Setting checkpoint %d.", cndx);
			setcp <= TRUE;
			state <= CHKPT_IDLE;
		end
	default:
		state <= CHKPT_IDLE;
	endcase
end

reg [3:0] free_chkpt_is;
reg [3:0] free_chkpt2s;
checkpt_ndx_t fchkpt2,fchkpt;
checkpt_ndx_t [3:0] fchkpt_is;
checkpt_ndx_t [3:0] fchkpt2s;
always_comb free_chkpt_is[0] = free_chkpt;
always_comb free_chkpt_is[1] = free_chkpt;
always_comb free_chkpt_is[2] = free_chkpt;
always_comb free_chkpt_is[3] = free_chkpt;
always_comb fchkpt_is[0] = fchkpt;
always_comb fchkpt_is[1] = fchkpt;
always_comb fchkpt_is[2] = fchkpt;
always_comb fchkpt_is[3] = fchkpt;
always_comb free_chkpt2s[0] = free_chkpt2;
always_comb free_chkpt2s[1] = free_chkpt2;
always_comb free_chkpt2s[2] = free_chkpt2;
always_comb free_chkpt2s[3] = free_chkpt2;
always_comb fchkpt2s[0] = fchkpt2;
always_comb fchkpt2s[1] = fchkpt2;
always_comb fchkpt2s[2] = fchkpt2;
always_comb fchkpt2s[3] = fchkpt2;

// Checkpoint allocator / deallocator
// GROUP_ALLOC if (TRUE) allocates a single checkpoint for the instruction group.

Stark_checkpoint_allocator
#(.GROUP_ALLOC(TRUE))
uchkpta1
(
	.rst(rst),
	.clk(clk),
	.clk5x(clk5x),
	.ph4(ph4),
	.alloc_chkpt(ialloc_chkpt),
	.br(4'h0),
	.chkptn(avail_chkpt),
	.free_chkpt_i(free_chkpt_is),
	.fchkpt_i(fchkpt_is),
	.free_chkpt2(free_chkpt2s),
	.fchkpt2(fchkpt2s),
	.stall(chkpt_stall)
);

// Free branch checkpoints once the branch is done.

Stark_checkpoint_freer uchkptfr1
(
	.rst(rst),
	.clk(clk),
	.pgh(pgh),
	.free(free_chkpt),
	.chkpt(fchkpt),
	.chkpt_gndx(freecp_grp)
);

// Free all the branch checkpoints coming after a restore.

always_ff @(posedge clk)
if (rst) begin
	gndx <= 6'd0;
	free_chkpt2 <= FALSE;
end
else begin
	free_chkpt2 <= FALSE;
	case(backout_st2)
	2'd0:
		if (restore) begin
			gndx <= ((fcu_id + 3'd4) % Stark_pkg::ROB_ENTRIES) >> 2;
		end
	2'd1:
		begin
			if (pgh[gndx].cndx != pgh[fcu_id>>2].cndx && pgh[gndx].sn > pgh[fcu_id>>2].sn) begin
				free_chkpt2 <= TRUE;
				fchkpt2 <= pgh[gndx].cndx;
			end 
			gndx <= (gndx + 3'd1) % (Stark_pkg::ROB_ENTRIES/4);
		end
	endcase
end

endmodule
