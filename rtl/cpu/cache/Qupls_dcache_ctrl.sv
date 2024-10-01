// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2024  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	Qupls_dcache_ctrl.sv
//
// BSD 3-Clause License
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// 212 LUTs / 348 FFs
//
// Dcache_ctrl always sends an ack pulse back to the core even for .erc stores.
// ============================================================================

import const_pkg::*;
import fta_bus_pkg::*;
import QuplsPkg::*;
import Qupls_cache_pkg::*;

module Qupls_dcache_ctrl(rst_i, clk_i, dce, ftam_req, ftam_resp, ftam_full, acr, hit, modified,
	cache_load, cpu_request_cancel, cpu_request_rndx,
	cpu_request_i, cpu_request_busy_o,
	cpu_request_i2, data_to_cache_o, response_from_cache_i, wr, uway, way,
	dump, dump_i, dump_ack, snoop_adr, snoop_v, snoop_cid);
parameter CID = 3'd1;
parameter CORENO = 6'd1;
parameter WAYS = 4;
parameter NSEL = 32;
parameter WAIT = 6'd0;
localparam LOG_WAYS = $clog2(WAYS)-1;
input rst_i;
input clk_i;
input dce;
output fta_cmd_request256_t ftam_req;
input fta_cmd_response256_t ftam_resp;
input ftam_full;
input [3:0] acr;
input hit;
input modified;
output reg cache_load;
input rob_bitmask_t cpu_request_cancel;
input rob_ndx_t cpu_request_rndx;
input fta_cmd_request512_t cpu_request_i;
output reg cpu_request_busy_o;
output fta_cmd_request512_t cpu_request_i2;
output fta_cmd_response512_t data_to_cache_o;
input fta_cmd_response512_t response_from_cache_i;
output reg wr;
input [LOG_WAYS:0] uway;
output reg [LOG_WAYS:0] way;
input dump;
input DCacheLine dump_i;
output reg dump_ack;
input fta_address_t snoop_adr;
input snoop_v;
input [5:0] snoop_cid;

genvar g;
integer nn,nn1,cpu_req_select,nn3,output_tran,nn5,free_queue_entry,nn7,nn8,nn9,nn10,nn11;

typedef enum logic [3:0] {
	RESET = 0,
	IDLE,
	DUMP1,LOAD1,RW1,
	RWPOST,STATE3,STATE4,STATE5,RAND_DELAY
} state_t;
state_t req_state;

typedef enum logic [2:0] {
	NONE = 0,
	ACTIVE = 1,
	LOADED = 2,
	ALLOCATE = 3,
	DONE = 4
} tran_state_t;

typedef struct packed
{
	logic v;
	logic is_load;
	logic is_dump;
	logic [1:0] active;
	logic [1:0] done;
	logic [1:0] out;
	logic [1:0] loaded;
	logic write_allocate;
	rob_ndx_t rndx;
	fta_cmd_request512_t cpu_req;
	fta_cmd_request256_t [1:0] tran_req;
} req_queue_t;

reg [LOG_WAYS:0] iway;
fta_cmd_response512_t cache_load_data;
reg cache_dump;
reg load_cache;
reg [10:0] to_cnt;
reg [3:0] tid_cnt;
wire [16:0] lfsr_o;
reg [2:0] dump_cnt;
reg [511:0] upd_dat;
//reg we_r;
reg [1:0] active_req;
reg [1:0] queued_req;
reg [1:0] tran_cnt [0:15];
reg [7:0] completed_tran;
reg previous_done;
req_queue_t cpu_req_queue [0:3];
fta_cmd_response512_t tran_load_data [0:3];
fta_tranid_t [15:0] tranids;
reg [6:0] last_out;
reg req_load, loaded;
reg [2:0] acc_cnt;
reg [2:0] load_cnt;
reg [5:0] wait_cnt;
reg [3:0] wr_cnt;
reg cpu_trans_queued;
fta_tranid_t lasttid, lasttid2;
reg bus_busy;
reg [3:0] tidcnt;
reg in_que;
integer which_tran;

always_comb
	bus_busy = ftam_resp.rty;

lfsr17 #(.WID(17)) ulfsr1
(
	.rst(rst_i),
	.clk(clk_i),
	.ce(1'b1),
	.cyc(1'b0),
	.o(lfsr_o)
);

fta_cache_t cache_type;
reg non_cacheable;
reg allocate;

always_comb
	cache_type = cpu_request_i2.cache;
always_comb
	non_cacheable =
	!dce ||
	cache_type==fta_bus_pkg::NC_NB ||
	cache_type==fta_bus_pkg::NON_CACHEABLE
	;
always_comb
	allocate = fnFtaAllocate(cpu_request_i2.cache);

// Comb logic so that hits do not take an extra cycle.
always_comb
	if (hit) begin
		way = uway;
		data_to_cache_o = response_from_cache_i;
		data_to_cache_o.ack = 1'b1;
	end
	else begin
		way = iway;
		data_to_cache_o = cache_load_data;
		data_to_cache_o.dat = upd_dat;
	end

// Selection of data used to update cache.
// For a write request the data includes data from the CPU.
// Otherwise it is just a cache line load, all data comes from the response.
// Note data is passed in 512-bit chunks.
generate begin : gCacheLineUpdate
	for (g = 0; g < 64; g = g + 1) begin : gFor
		always_comb
			if (cpu_req_queue[completed_tran[1:0]].cpu_req.we) begin
				if (cpu_req_queue[completed_tran[1:0]].cpu_req.sel[g])
					upd_dat[g*8+7:g*8] <= cpu_req_queue[completed_tran[1:0]].cpu_req.dat[g*8+7:g*8];
				else
//					upd_dat[g*8+7:g*8] <= data_to_cache_o.dat[g*8+7:g*8];
					upd_dat[g*8+7:g*8] <= response_from_cache_i.dat[g*8+7:g*8];
			end
			else
				upd_dat[g*8+7:g*8] <= cache_load_data[g*8+7:g*8];
	end
end
endgenerate				

// Select a CPU request to work on.
always_comb
begin
	cpu_req_select = 3'd4;
	for (nn1 = 0; nn1 < 4; nn1 = nn1 + 1)
		if (cpu_req_queue[nn1].v
			// The previous set must be done before a new one will be selected.
			&& previous_done
			&& req_state==IDLE
		)
			cpu_req_select = nn1;
end

// Select a transaction to output
always_comb
begin
	output_tran = 5'd8;
	if (req_state==IDLE) begin
		for (nn3 = 0; nn3 < 8; nn3 = nn3 + 1) begin
			if (cpu_req_queue[nn3>>1].active[nn3[0]]
				&& !cpu_req_queue[nn3>>1].out[nn3[0]] 
				&& !cpu_req_queue[nn3>>1].done[nn3[0]]
				&& cpu_req_queue[nn3>>1].tran_req[nn3 & 2'd1].cyc	// there must be a valid tran
	//			&& !tran_load_data[nn3>>2].ack
				&& output_tran==5'd8)
				output_tran = nn3;
		end
	end
end

// Get index of completed CPU transaction. The CPU transacation will be complete
// only if all the bus transactions are complete.
always_comb
begin
	completed_tran = 3'd4;
	for (nn5 = 0; nn5 < 4; nn5 = nn5 + 1)
		if (cpu_req_queue[nn5].done[1:0]==2'b11)
			completed_tran = nn5;
end

// Detect if a request is already queued.
always_comb
begin
	in_que = FALSE;
	for (nn9 = 0; nn9 < 4; nn9 = nn9 + 1)
		if (cpu_req_queue[nn9].cpu_req.tid==cpu_request_i.tid)
			in_que = TRUE;
end

// Get index of free queue entry.
always_comb
begin
	free_queue_entry = 3'd4;
	for (nn7 = 0; nn7 < 4; nn7 = nn7 + 1)
		if (~cpu_req_queue[nn7].v && free_queue_entry==3'd4)
			free_queue_entry = nn7;
end


always_comb
begin
	which_tran = 5'd8;
	for (nn8 = 0; nn8 < 8; nn8 = nn8 + 1)
		if (cpu_req_queue[nn8[2:1]].tran_req[nn8[0]].tid==ftam_resp.tid
			&& cpu_req_queue[nn8[2:1]].tran_req[nn8[0]].cmd!=CMD_NONE)
			which_tran = nn8;
end
//			|| (cpu_req_queue[nn8[3:2]].active[nn8[1:0]] && !cpu_req_queue[nn8[3:2]].tran_req[nn8[1:0]].cyc)

always_comb
	cpu_request_busy_o = free_queue_entry >= 4;

fta_tranid_t tmptid;
always_comb
begin
	tmptid.core = CORENO;
	tmptid.channel = CID;
	tmptid.tranid = tidcnt;
end

always_ff @(posedge clk_i)
if (rst_i) begin
	req_state <= RESET;
	to_cnt <= 'd0;
	tidcnt <= 4'd1;
	tid_cnt <= 4'd0;
	lasttid <= 4'd0;
	lasttid2 <= 4'd0;
	dump_ack <= 1'd0;
	wr <= 1'b0;
	cache_load_data <= {$bits(fta_cmd_response512_t){1'd0}};
	ftam_req <= 'd0;
	dump_cnt <= 3'd0;
	load_cnt <= 3'd0;
	cache_load <= 'd0;
	load_cache <= 'd0;
	cache_dump <= 'd0;
	for (nn = 0; nn < 8; nn = nn + 1) begin
		tran_cnt[nn] <= 'd0;
		tranids[nn] <= 'd0;
	end
	for (nn = 0; nn < 4; nn = nn + 1) begin
		tran_load_data[nn] <= 'd0;
		cpu_req_queue[nn] <= {$bits(req_queue_t){1'd0}};
	end
	req_load <= 1'd0;
	loaded <= 1'd0;
	load_cnt <= 3'd0;
	wait_cnt <= 3'd0;
	wr_cnt <= 4'd0;
	cpu_trans_queued <= 1'd0;
	cpu_request_i2 <= 'd0;
	last_out <= 5'd16;
	iway <= 2'b00;
	queued_req <= 2'd3;
	previous_done <= 1'd1;
end
else begin
	dump_ack <= 1'd0;
	cache_load <= 1'b0;
	cache_load_data.stall <= 1'b0;
	cache_load_data.next <= 1'b0;
	cache_load_data.ack <= 1'b0;
	cache_load_data.pri <= 4'd7;
	wr <= 1'b0;
	// Grab the bus for only 1 clock.
	if (ftam_req.cyc && !ftam_full) begin
		lasttid <= ftam_req.tid;
		tBusClear();
	end
	// Ack pulses for only 1 clock.
	for (nn = 0; nn < 4; nn = nn + 1)
		tran_load_data[nn].ack <= 1'b0;

	// Queue a CPU request in an empty slot. Does not block if there is no slot
	// available. If there is no slot available eventually the memory op will
	// time out on the CPU.
	if (cpu_request_i.cyc && !in_que) begin
		if (free_queue_entry < 3'd4) begin
			cpu_req_queue[free_queue_entry[1:0]].v <= 1'b1;
			cpu_req_queue[free_queue_entry[1:0]].done <= 2'b00;
			cpu_req_queue[free_queue_entry[1:0]].active <= 2'b00;
			cpu_req_queue[free_queue_entry[1:0]].out <= 2'b00;
			cpu_req_queue[free_queue_entry[1:0]].cpu_req <= cpu_request_i;
			cpu_req_queue[free_queue_entry[1:0]].rndx <= cpu_request_rndx;
		end
	end

	if (|cpu_request_cancel) begin
		for (nn10 = 0; nn10 < ROB_ENTRIES; nn10 = nn10 + 1) begin
			if (cpu_request_cancel[nn10]) begin
				for (nn11 = 0; nn11 < 3'd4; nn11 = nn11 + 1) begin
					if (cpu_req_queue[nn11].rndx==nn10) begin
						cpu_req_queue[nn11].v <= INV;
						cpu_req_queue[nn11].done <= 2'b11;
						cpu_req_queue[nn11].out <= 2'b00;
						cpu_req_queue[nn11].active <= 2'b00;
						if (cpu_req_queue[nn11].tran_req[0].tid==tmptid && req_state==RW1) begin
						  cpu_trans_queued <= 1'b1;
						  cpu_req_queue[nn11].tran_req[0].cyc <= 1'b0;
							lasttid2 <= 4'd0;
							previous_done <= 1'b1;
						end
						if (cpu_req_queue[nn11].tran_req[1].tid==tmptid && req_state==RW1) begin
						  cpu_trans_queued <= 1'b1;
						  cpu_req_queue[nn11].tran_req[1].cyc <= 1'b0;
							lasttid2 <= 4'd0;
							previous_done <= 1'b1;
						end
					end
				end
			end
		end
	end

	case(req_state)
	RESET:
		begin
			ftam_req.cmd <= fta_bus_pkg::CMD_DCACHE_LOAD;
			ftam_req.sz  <= fta_bus_pkg::dhexi;
			ftam_req.blen <= 6'd0;
//			ftam_req.cid <= CID;					// CPU channel id
			ftam_req.tid.core <= CORENO;
			ftam_req.tid.channel <= CID;
			ftam_req.tid.tranid <= 4'd0;		// transaction id
			ftam_req.csr  <= 1'd0;						// clear/set reservation
			ftam_req.pl	<= 8'd0;						// privilege level
			ftam_req.pri	<= 4'h7;					// average priority (higher is better).
			ftam_req.cache <= fta_bus_pkg::CACHEABLE;
			ftam_req.seg <= fta_bus_pkg::DATA;
			ftam_req.bte <= fta_bus_pkg::LINEAR;
			ftam_req.cti <= fta_bus_pkg::CLASSIC;
			tBusClear();
			wr_cnt <= 4'd0;
			req_state <= IDLE;
		end
	IDLE:
		begin
			if (~|cpu_request_cancel) begin
				// Select a CPU request to process.
				if (cpu_req_select < 3'd4 && cpu_req_queue[cpu_req_select[1:0]].cpu_req.tid != lasttid2) begin
					queued_req <= cpu_req_select[1:0];
					cpu_request_i2 <= cpu_req_queue[cpu_req_select[1:0]].cpu_req;
					lasttid2 <= cpu_req_queue[cpu_req_select[1:0]].cpu_req.tid;
					cpu_req_queue[cpu_req_select[1:0]].active <= 2'b11;
					cpu_req_queue[cpu_req_select[1:0]].done <= 2'b00;
					previous_done <= FALSE;
					lasttid <= lasttid2;
				end
			end
			//tBusClear();
			wr_cnt <= 4'd0;
			acc_cnt <= 3'd0;
			load_cnt <= 3'd0;
			dump_cnt <= 3'd0;
			if (cpu_request_i2.cyc && cpu_request_i2.tid != lasttid) begin
//				lasttid <= cpu_request_i2.tid;
				if (!hit & dce) begin
					if (allocate) begin
						if (modified)
							req_state <= DUMP1;
						else
							req_state <= LOAD1;
					end
					else if (!cpu_trans_queued)
						req_state <= RW1;
				end
				else if (!cpu_trans_queued) begin
					if (cpu_request_i2.we)
						req_state <= RW1;
					else if (non_cacheable || !dce)
						req_state <= RW1;
				end
			end
		end
	DUMP1:
		begin
			if (dump_cnt==3'd2) begin
				wr_cnt <= 4'd0;
				cache_dump <= 1'b0;
				req_state <= LOAD1;
			end
			else begin
				//tBusClear();
				cache_dump <= 1'b1;
				cpu_req_queue[queued_req].is_dump <= 1'b1;
				tAddr(
					cpu_request_i2.om,
					1'b1,
					!non_cacheable,
					dump_i.asid,
					{dump_i.vtag[$bits(fta_address_t)-1:Qupls_cache_pkg::DCacheTagLoBit],dump_cnt[0],{Qupls_cache_pkg::DCacheTagLoBit-1{1'h0}}},
					{dump_i.ptag[$bits(fta_address_t)-1:Qupls_cache_pkg::DCacheTagLoBit],dump_cnt[0],{Qupls_cache_pkg::DCacheTagLoBit-1{1'h0}}},
					32'hFFFFFFFF,
					dump_i.data >> {dump_cnt,8'd0},
					CID,
					tmptid,
					dump_cnt[0],
					1'b0
				);
				dump_cnt <= dump_cnt + 2'd1;
				tidcnt <= tidcnt + 2'd1;
				if (&tidcnt)
					tidcnt <= 4'd1;
			end
		end
	LOAD1:
		begin
			if (load_cnt==3'd2) begin
				wr_cnt <= 4'd0;
				load_cache <= 1'd0;
				req_state <= RW1;
			end
			else begin
				//tBusClear();
				load_cache <= 1'b1;
				cpu_req_queue[queued_req].is_load <= 1'b1;
				tAddr(
					cpu_request_i2.om,
					1'b0,
					!non_cacheable,
					cpu_request_i2.asid,
					{cpu_request_i2.vadr[$bits(fta_address_t)-1:Qupls_cache_pkg::DCacheTagLoBit],load_cnt[0],{Qupls_cache_pkg::DCacheTagLoBit-1{1'h0}}},
					{cpu_request_i2.padr[$bits(fta_address_t)-1:Qupls_cache_pkg::DCacheTagLoBit],load_cnt[0],{Qupls_cache_pkg::DCacheTagLoBit-1{1'h0}}},
					32'hFFFFFFFF,
					1'd0,
					CID,
					tmptid,
					load_cnt[0],
					1'b1
				);
				load_cnt <= load_cnt + 2'd1;
				tidcnt <= tidcnt + 2'd1;
				if (&tidcnt)
					tidcnt <= 4'd1;
			end
		end
	// This state splits the CPU read or write request into multiple separate
	// transactions for the bus access.
	RW1:
		if (cpu_trans_queued)
			req_state <= RWPOST;
		// tAccess will set cpu_trans_queued once all transactions have been
		// queued.
		else begin
			tAccess(tmptid);
			tidcnt <= tidcnt + 2'd1;
			if (&tidcnt)
				tidcnt <= 4'd1;
		end
	RWPOST:
		begin
			cpu_trans_queued <= FALSE;
			cpu_request_i2.cyc <= LOW;
			req_state <= IDLE;
		end
	STATE5:
		begin
			to_cnt <= to_cnt + 2'd1;
			if (ftam_resp.ack) begin
				tBusClear();
				req_state <= RAND_DELAY;
			end
			else if (ftam_resp.rty) begin
				//tBusClear();
				req_state <= IDLE;
			end
			if (to_cnt[10]) begin
				tBusClear();
				req_state <= RAND_DELAY;
			end
		end
	// Wait some random number of clocks before trying again.
	RAND_DELAY:
		begin
			tBusClear();
			if (lfsr_o[1:0]==2'b11)
				req_state <= IDLE;
		end
	default:	req_state <= RESET;
	endcase

	// Process responses.
	// Could have a string of ack's coming back due to a string of requests.
	if (ftam_resp.ack) begin
		if (which_tran < 5'd8) begin
			// Got an ack back so the tran no longer needs to be performed.
			cpu_req_queue[which_tran[2:1]].active[which_tran[0]] <= 1'b0;
			cpu_req_queue[which_tran[2:1]].out[which_tran[0]] <= 1'b0;
			cpu_req_queue[which_tran[2:1]].done[which_tran[0]] <= 1'b1;
			cpu_req_queue[which_tran[2:1]].tran_req[which_tran[0]].cmd <= fta_bus_pkg::CMD_NONE;
			tran_load_data[which_tran[2:1]].ack <= 1'b1;
			//tran_req[ftam_resp.tid & 4'hF].cyc <= 1'b0;
//			tran_load_data[which_tran[3:2]].cid <= ftam_resp.cid;
			tran_load_data[which_tran[2:1]].tid <= cpu_req_queue[which_tran[2:1]].cpu_req.tid;
			tran_load_data[which_tran[2:1]].pri <= ftam_resp.pri;
			tran_load_data[which_tran[2:1]].adr <= {ftam_resp.adr[$bits(fta_address_t)-1:6],6'd0};
			case(ftam_resp.adr[5])
			1'd0: begin tran_load_data[which_tran[2:1]].dat[255:  0] <= ftam_resp.dat; end
			1'd1:	begin tran_load_data[which_tran[2:1]].dat[511:256] <= ftam_resp.dat; end
			endcase
//			we_r <= ftam_req.we;
			tran_load_data[which_tran[2:1]].rty <= 1'b0;
			tran_load_data[which_tran[2:1]].err <= fta_bus_pkg::OKAY;
		end
	end
	// Retry or error (only if transaction active)
	// Abort the memory request. Go back and try again.
	else if ((ftam_resp.rty|ftam_resp.err) && ftam_resp.tid.tranid==last_out[3:0]) begin
		if (which_tran < 5'd8) begin
			tran_load_data[which_tran[2:1]].rty <= ftam_resp.rty;
			tran_load_data[which_tran[2:1]].err <= ftam_resp.err;
			tran_load_data[which_tran[2:1]].ack <= 1'b0;
			//cpu_req_queue[which_tran[3:2]].out[which_tran[3:2]] <= 1'b0;
			//cpu_req_queue[which_tran[3:2]].tran_req[output_tran[1:0]].cyc <= 1'b1;
			// If the tran was not output, mark it done.
			/*
			if (!cpu_req_queue[which_tran[3:2]].tran_req[which_tran[1:0]].cyc) begin
				cpu_req_queue[which_tran[3:2]].active[which_tran[1:0]] <= 1'b0;
				cpu_req_queue[which_tran[3:2]].done[which_tran[1:0]] <= 1'b1;
			end
			*/
		end
	end
	// Acknowledge completed transactions.
	// Write allocate transactions must be done twice, once to load the cache
	// and a second time to update it.
	// completed_tran selected based on tran_done[].
	if (completed_tran < 3'd4) begin
		active_req <= completed_tran[1:0];
		if (cpu_req_queue[completed_tran[1:0]].is_dump) begin
			cpu_req_queue[completed_tran[1:0]].active[1'd0] <= 1'b1;
			cpu_req_queue[completed_tran[1:0]].active[1'd1] <= 1'b1;
			cpu_req_queue[completed_tran[1:0]].is_dump <= 1'b0;
			dump_ack <= 1'b1;
		end
		else if (cpu_req_queue[completed_tran[1:0]].is_load) begin
			cpu_req_queue[completed_tran[1:0]].is_load <= 1'd0;
			cache_load_data <= tran_load_data[completed_tran[1:0]];
			wr <= dce & allocate & ~non_cacheable;
			cache_load <= dce & allocate & ~non_cacheable;
//				cache_load_data.ack <= 1'b1;
			cache_load_data.tid <= cpu_req_queue[completed_tran[1:0]].cpu_req.tid;
			if (!cpu_req_queue[completed_tran[1:0]].write_allocate) begin
				tran_load_data[completed_tran[1:0]].ack <= 1'b1;
				cache_load_data.ack <= 1'b1;
				cpu_req_queue[completed_tran[1:0]].v <= INV;
				cpu_req_queue[completed_tran[1:0]].cpu_req.tid <= 'd0;
			end
			else begin
				cpu_req_queue[completed_tran[1:0]].active[1'd0] <= 1'b1;
				cpu_req_queue[completed_tran[1:0]].active[1'd1] <= 1'b1;
				cache_load_data.ack <= 1'b0;
			end
		end
		// At the end of a completed CPU transaction, send back an ack.
		// Copy the data from the tran buffer.
		else begin
			tran_load_data[completed_tran[1:0]].ack <= 1'b1;
			cache_load_data <= tran_load_data[completed_tran[1:0]];
			cache_load_data.ack <= 1'b1;
			wr <= dce & allocate & ~non_cacheable;
			cache_load_data.tid <= cpu_req_queue[completed_tran[1:0]].cpu_req.tid;
			cpu_req_queue[completed_tran[1:0]].v <= INV;
			//cpu_req_queue[completed_tran[1:0]].cpu_req.tid <= {$bits(fta_tranid_t){1'd0}};
		end
		cpu_req_queue[completed_tran[1:0]].done[1'd0] <= 1'b0;
		cpu_req_queue[completed_tran[1:0]].done[1'd1] <= 1'b0;
		previous_done <= 1'b1;
		iway <= lfsr_o[LOG_WAYS:0];
	end

	// We want to update the cache, but if its allocate on write the
	// cache needs to be loaded with data from RAM first before its
	// updated. Request a cache load.

	// If not a hit, and read allocate and the transaction is done:
	// 	 update the cache.
	// If not a hit, and write allocate and the load is done
	// 	 update the cache.
	/*
	if (completed_tran < 8'd16) begin
		// If we have a hit on the cache line, write the data to the cache if
		// it is a writeable cacheable transaction.
		if (hit) begin
			wr <= (~non_cacheable & dce & cpu_request_i2.we & allocate);
			cache_load_data.ack <= !cache_dump;
			cache_dump <= 'd0;
			cache_load <= 'd0;
	//		resp_state <= STATE1;
		end
		// No hit on the cache line and not allocating, we're done.
		else if (!allocate) begin
			cache_load_data.ack <= !cache_dump;
			cache_load <= 'd0;
	//		resp_state <= STATE1;
		end
	end
	*/

	// Look for outstanding transactions to execute.
	if (output_tran < 5'd8) begin
//		if (!ftam_full) begin
		active_req <= output_tran[2:1];
		last_out <= cpu_req_queue[output_tran[2:1]].tran_req[output_tran[0]].tid.tranid;
		if (!cpu_req_queue[output_tran[2:1]].tran_req[output_tran[0]].we || cpu_req_queue[output_tran[2:1]].tran_req[output_tran[0]].cti==fta_bus_pkg::ERC)
			cpu_req_queue[output_tran[2:1]].out[output_tran[0]] <= 1'b1;
		else begin
			cpu_req_queue[output_tran[2:1]].active[output_tran[0]] <= 1'b0;
			cpu_req_queue[output_tran[2:1]].out[output_tran[0]] <= 1'b0;
			cpu_req_queue[output_tran[2:1]].done[output_tran[0]] <= 1'b1;
		end
		ftam_req <= cpu_req_queue[output_tran[2:1]].tran_req[output_tran[0]];
		cpu_req_queue[output_tran[2:1]].tran_req[output_tran[0]].cyc <= 1'b0;
//		wait_cnt <= 3'd0;
//			req_state <= RAND_DELAY;
//		end
	end

	// Only the cache index need be compared for snoop hit.
	if (snoop_v && snoop_adr[Qupls_cache_pkg::ITAG_BIT:Qupls_cache_pkg::ICacheTagLoBit]==
		cpu_request_i2.vadr[Qupls_cache_pkg::ITAG_BIT:Qupls_cache_pkg::ICacheTagLoBit] && snoop_cid==CID) begin
		/*
		tBusClear();
		wr <= 1'b0;
		// Force any transactions matching the snoop address to retry.
		for (nn = 0; nn < 16; nn = nn + 1) begin
			// Note: the tag bits are compared only for the addresses that would match
			// between the virtual and physical. The cache line number. Need to match on 
			// the physical address returning from snoop, but only have the virtual
			// address available.
			if (cpu_request_i2.vadr[Qupls_cache_pkg::ITAG_BIT:Qupls_cache_pkg::ICacheTagLoBit] ==
				tran_load_data[nn].adr[Qupls_cache_pkg::ITAG_BIT:Qupls_cache_pkg::ICacheTagLoBit]) begin
				v[nn] <= 'd0;
				tran_load_data[nn].rty <= 1'b1;
			end
			if (cpu_request_i2.vadr[Qupls_cache_pkg::ITAG_BIT:Qupls_cache_pkg::ICacheTagLoBit]==
				cpu_req_queue[nn].vadr[Qupls_cache_pkg::ITAG_BIT:Qupls_cache_pkg::ICacheTagLoBit])
				cpu_req_queue[nn] <= 'd0;
		end
		*/
		req_state <= IDLE;		
	end
end

task tBusClear;
begin
	ftam_req.cyc <= 1'b0;
	ftam_req.stb <= 1'b0;
	ftam_req.sel <= 32'h00000000;
	ftam_req.we <= 1'b0;
end
endtask

task tAddr;
input fta_operating_mode_t om;
input wr;
input cache;
input cpu_types_pkg::asid_t asid;
input cpu_types_pkg::virtual_address_t vadr;
input cpu_types_pkg::physical_address_t padr;
input [31:0] sel;
input [255:0] data;
input [3:0] cid;
input fta_tranid_t tid;
input [0:0] which;
input ack;
begin
	tranids[which] <= tid;
	to_cnt <= 'd0;
	if (!cpu_req_queue[queued_req].tran_req[which].cyc) begin
		cpu_req_queue[queued_req].tran_req[which].om <= om;
		cpu_req_queue[queued_req].tran_req[which].cmd <= wr ? fta_bus_pkg::CMD_STORE : 
			cache ? fta_bus_pkg::CMD_DCACHE_LOAD : fta_bus_pkg::CMD_LOADZ;
		cpu_req_queue[queued_req].tran_req[which].sz <= fta_bus_pkg::dhexi;
		cpu_req_queue[queued_req].tran_req[which].blen <= 6'd0;
//		cpu_req_queue[queued_req].tran_req[which].cid <= cid;
		cpu_req_queue[queued_req].tran_req[which].tid <= tid;
		cpu_req_queue[queued_req].tran_req[which].bte <= cpu_request_i2.bte;
		cpu_req_queue[queued_req].tran_req[which].cti <= cpu_request_i2.cti;
		cpu_req_queue[queued_req].tran_req[which].cyc <= 1'b1;
		cpu_req_queue[queued_req].tran_req[which].stb <= 1'b1;
		cpu_req_queue[queued_req].tran_req[which].sel <= sel;
		cpu_req_queue[queued_req].tran_req[which].we <= wr;
		cpu_req_queue[queued_req].tran_req[which].csr <= 1'd0;
		cpu_req_queue[queued_req].tran_req[which].asid <= asid;
		cpu_req_queue[queued_req].tran_req[which].vadr <= vadr;
		cpu_req_queue[queued_req].tran_req[which].padr <= padr;
		cpu_req_queue[queued_req].tran_req[which].data1 <= data;
		cpu_req_queue[queued_req].tran_req[which].csr <= 1'd0;
		cpu_req_queue[queued_req].tran_req[which].pl <= 8'd0;
		cpu_req_queue[queued_req].tran_req[which].pri <= 4'h7;
		cpu_req_queue[queued_req].tran_req[which].cache <= cpu_request_i2.cache;//fta_bus_pkg::CACHEABLE;
		cpu_req_queue[queued_req].tran_req[which].seg <= fta_bus_pkg::DATA;
		cpu_req_queue[queued_req].active[which] <= 1'b1;
	end
//	tran_done[completed_tran] <= 1'b0;
	tran_load_data[which].adr <= padr;
	cpu_req_queue[queued_req].write_allocate <= wr & allocate;
	if (wr && !allocate && cpu_request_i2.cti!=fta_bus_pkg::ERC) begin
		cpu_req_queue[queued_req].done[which] <= 1'b1;
	end
	if (~|cpu_request_i2.sel[31:0])
		cpu_req_queue[queued_req].done[0] <= 1'b1;
	if (~|cpu_request_i2.sel[63:32])
		cpu_req_queue[queued_req].done[1] <= 1'b1;
	/*
	if (~|cpu_request_i2.sel[47:32])
		cpu_req_queue[queued_req].done[2'd2] <= 1'b1;
	if (~|cpu_request_i2.sel[63:48])
		cpu_req_queue[queued_req].done[2'd3] <= 1'b1;
	*/
end
endtask

task tAccess;
input fta_tranid_t tid;
fta_address_t ta;
begin
	if (wr_cnt == 4'd1) begin
		cpu_trans_queued <= 1'b1;
		loaded <= 1'b0;
		wr_cnt <= 4'd0;
	end
	// Access only the strip of memory requested. It could be an I/O device.
	ta = {cpu_request_i2.vadr[$bits(fta_address_t)-1:Qupls_cache_pkg::DCacheTagLoBit],wr_cnt[0],{Qupls_cache_pkg::DCacheTagLoBit-1{1'h0}}};
	case(wr_cnt[1:0])
	2'd0:	
		begin
			wr_cnt <= 4'd1;
			if (|cpu_request_i2.sel[31: 0]) begin
				tAddr(
					cpu_request_i2.om,
					cpu_request_i2.we,
					!non_cacheable,
					cpu_request_i2.asid,
					{cpu_request_i2.vadr[$bits(fta_address_t)-1:6],1'd0,5'h0},
					{cpu_request_i2.padr[$bits(fta_address_t)-1:6],1'd0,5'h0},
					cpu_request_i2.sel[31:0],
					cpu_request_i2.dat[255:0],
					CID,
					{tmptid.core,tmptid.channel,4'd1},
					1'd0,
					cpu_request_i2.cti==fta_bus_pkg::ERC || !cpu_request_i2.we
				);
//				req_state <= RAND_DELAY;
			end
			else begin
				cpu_req_queue[queued_req].done[0] <= 1'b1;
				wr_cnt <= 4'd0;
				cpu_trans_queued <= 1'b1;
				loaded <= 1'b0;
				if (|cpu_request_i2.sel[63:32]) begin
					tAddr(
						cpu_request_i2.om,
						cpu_request_i2.we,
						!non_cacheable,
						cpu_request_i2.asid,
						{cpu_request_i2.vadr[$bits(fta_address_t)-1:6],1'd1,5'h0},
						{cpu_request_i2.padr[$bits(fta_address_t)-1:6],1'd1,5'h0},
						cpu_request_i2.sel[63:32],
						cpu_request_i2.dat[511:256],
						CID,
						{tmptid.core,tmptid.channel,4'd2},
						1'd1,
						cpu_request_i2.cti==fta_bus_pkg::ERC || !cpu_request_i2.we
					);
//					req_state <= RAND_DELAY;
				end
				/*
				else begin
					cpu_req_queue[queued_req].done[2'd1] <= 1'b1;
					wr_cnt <= 4'd3;
					if (|cpu_request_i2.sel[47:32]) begin
						tAddr(
							cpu_request_i2.om,
							cpu_request_i2.we,
							!non_cacheable,
							cpu_request_i2.asid,
							{cpu_request_i2.vadr[$bits(fta_address_t)-1:6],2'd2,4'h0},
							{cpu_request_i2.padr[$bits(fta_address_t)-1:6],2'd2,4'h0},
							cpu_request_i2.sel[47:32],
							cpu_request_i2.dat[383:256],
							CID,
							{tmptid.core,tmptid.channel,4'd3},
							2'd2,
							cpu_request_i2.cti==fta_bus_pkg::ERC || !cpu_request_i2.we
						);
//						req_state <= RAND_DELAY;
					end
					else begin
						cpu_req_queue[queued_req].done[2'd2] <= 1'b1;
						wr_cnt <= 4'd0;
						cpu_trans_queued <= 1'b1;
						loaded <= 1'b0;
						if (|cpu_request_i2.sel[63:48]) begin
							tAddr(
								cpu_request_i2.om,
								cpu_request_i2.we,
								!non_cacheable,
								cpu_request_i2.asid,
								{cpu_request_i2.vadr[$bits(fta_address_t)-1:6],2'd3,4'h0},
								{cpu_request_i2.padr[$bits(fta_address_t)-1:6],2'd3,4'h0},
								cpu_request_i2.sel[63:48],
								cpu_request_i2.dat[511:384],
								CID,
								{tmptid.core,tmptid.channel,4'd4},
								2'd3,
								cpu_request_i2.cti==fta_bus_pkg::ERC || !cpu_request_i2.we
							);
//							req_state <= RAND_DELAY;
						end
						else
							cpu_req_queue[queued_req].done[2'd3] <= 1'b1;
					end
				end
				*/
			end
		end
	2'd1:	
		begin
			wr_cnt <= 4'd0;
			if (|cpu_request_i2.sel[63:32]) begin
				tAddr(
					cpu_request_i2.om,
					cpu_request_i2.we,
					!non_cacheable,
					cpu_request_i2.asid,
					{cpu_request_i2.vadr[$bits(fta_address_t)-1:6],1'd1,5'h0},
					{cpu_request_i2.padr[$bits(fta_address_t)-1:6],1'd1,5'h0},
					cpu_request_i2.sel[63:32],
					cpu_request_i2.dat[511:256],
					CID,
					{tmptid.core,tmptid.channel,4'd5},
					1'd1,
					cpu_request_i2.cti==fta_bus_pkg::ERC || !cpu_request_i2.we
				);
//				req_state <= RAND_DELAY;
			end
			/*
			else begin
				cpu_req_queue[queued_req].done[2'd1] <= 1'b1;
				wr_cnt <= 4'd3;
				if (|cpu_request_i2.sel[47:32]) begin
					tAddr(
						cpu_request_i2.om,
						cpu_request_i2.we,
						!non_cacheable,
						cpu_request_i2.asid,
						{cpu_request_i2.vadr[$bits(fta_address_t)-1:6],2'd2,4'h0},
						{cpu_request_i2.padr[$bits(fta_address_t)-1:6],2'd2,4'h0},
						cpu_request_i2.sel[47:32],
						cpu_request_i2.dat[383:256],
						CID,
						{tmptid.core,tmptid.channel,4'd6},
						2'd2,
						cpu_request_i2.cti==fta_bus_pkg::ERC || !cpu_request_i2.we
					);
//					req_state <= RAND_DELAY;
				end
				else begin
					cpu_req_queue[queued_req].done[2'd2] <= 1'b1;
					wr_cnt <= 4'd0;
					cpu_trans_queued <= 1'b1;
					loaded <= 1'b0;
					if (|cpu_request_i2.sel[63:48]) begin
						tAddr(
							cpu_request_i2.om,
							cpu_request_i2.we,
							!non_cacheable,
							cpu_request_i2.asid,
							{cpu_request_i2.vadr[$bits(fta_address_t)-1:6],2'd3,4'h0},
							{cpu_request_i2.padr[$bits(fta_address_t)-1:6],2'd3,4'h0},
							cpu_request_i2.sel[63:48],
							cpu_request_i2.dat[511:384],
							CID,
							{tmptid.core,tmptid.channel,4'd7},
							2'd3,
							cpu_request_i2.cti==fta_bus_pkg::ERC || !cpu_request_i2.we
						);
//						req_state <= RAND_DELAY;
					end
					else
						cpu_req_queue[queued_req].done[2'd3] <= 1'b1;
				end
			end
			*/
		end
	/*
	2'd2:
		begin
			wr_cnt <= 4'd3;
			if (|cpu_request_i2.sel[47:32]) begin
				tAddr(
					cpu_request_i2.om,
					cpu_request_i2.we,
					!non_cacheable,
					cpu_request_i2.asid,
					{cpu_request_i2.vadr[$bits(fta_address_t)-1:6],2'd2,4'h0},
					{cpu_request_i2.padr[$bits(fta_address_t)-1:6],2'd2,4'h0},
					cpu_request_i2.sel[47:32],
					cpu_request_i2.dat[383:256],
					CID,
					{tmptid.core,tmptid.channel,4'd8},
					2'd2,
					cpu_request_i2.cti==fta_bus_pkg::ERC || !cpu_request_i2.we
				);
//				req_state <= RAND_DELAY;
			end
			else begin
				cpu_req_queue[queued_req].done[2'd2] <= 1'b1;
				wr_cnt <= 4'd0;
				cpu_trans_queued <= 1'b1;
				loaded <= 1'b0;
				if (|cpu_request_i2.sel[63:48]) begin
					tAddr(
						cpu_request_i2.om,
						cpu_request_i2.we,
						!non_cacheable,
						cpu_request_i2.asid,
						{cpu_request_i2.vadr[$bits(fta_address_t)-1:6],2'd3,4'h0},
						{cpu_request_i2.padr[$bits(fta_address_t)-1:6],2'd3,4'h0},
						cpu_request_i2.sel[63:48],
						cpu_request_i2.dat[511:384],
						CID,
						{tmptid.core,tmptid.channel,4'd9},
						2'd3,
						cpu_request_i2.cti==fta_bus_pkg::ERC || !cpu_request_i2.we
					);
//					req_state <= RAND_DELAY;
				end
				else
					cpu_req_queue[queued_req].done[2'd3] <= 1'b1;
			end
		end
	2'd3: 
		begin
			wr_cnt <= 4'd0;
			cpu_trans_queued <= 1'b1;
			loaded <= 1'b0;
			if (|cpu_request_i2.sel[63:48]) begin
				tAddr(
					cpu_request_i2.om,
					cpu_request_i2.we,
					!non_cacheable,
					cpu_request_i2.asid,
					{cpu_request_i2.vadr[$bits(fta_address_t)-1:6],2'd3,4'h0},
					{cpu_request_i2.padr[$bits(fta_address_t)-1:6],2'd3,4'h0},
					cpu_request_i2.sel[63:48],
					cpu_request_i2.dat[511:384],
					CID,
					{tmptid.core,tmptid.channel,4'd10},
					2'd3,
					cpu_request_i2.cti==fta_bus_pkg::ERC || !cpu_request_i2.we
				);
//				req_state <= RAND_DELAY;
			end
			else
				cpu_req_queue[queued_req].done[2'd3] <= 1'b1;
		end
	*/
	endcase
end
endtask

endmodule
