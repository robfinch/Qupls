// ============================================================================
//        __
//   \\__/ o\    (C) 2026  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
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
// 12000 LUTs / 7500 FFs / 125 MHz	(4 microops per instruction)
// ============================================================================

import const_pkg::*;
import Qupls5_pkg::*;

module Qupls5_micro_op_cache(rst, clk, en, addr, rd_more, uop, uop_addr, uop_count,
	stomp_moq1, stomp_moq2, pc_fet, pg_ext, pg_trn, pg_moq1, pg_moq2,
	branch_resolved, live_stream, invalidate);
parameter MWIDTH = Qupls5_pkg::MWIDTH;
parameter MAX_MICROOPS = 8;
parameter MICROOPS_PER_INSTR = Qupls5_pkg::MICROOPS_PER_INSTR;
parameter MICROOP_CACHE_SIZE = 4;
input rst;
input clk;
input en;
input pc_address_t addr;
output reg rd_more;
input Qupls5_pkg::micro_op_t [MICROOPS_PER_INSTR-1:0] uop [MWIDTH-1:0];
input pc_address_t [MWIDTH-1:0] uop_addr;
input [5:0] uop_count [0:MWIDTH-1];
input stomp_moq1;
input stomp_moq2;
input Qupls5_pkg::pc_address_ex_t pc_fet;
input Qupls5_pkg::pipeline_group_reg_t pg_ext;
input Qupls5_pkg::pipeline_group_reg_t pg_trn;
output Qupls5_pkg::pipeline_group_reg_t pg_moq1;
output Qupls5_pkg::pipeline_group_reg_t pg_moq2;
input branch_resolved;
input pc_stream_t live_stream;
input invalidate;

typedef logic [4:0] count_t;
typedef Qupls5_pkg::micro_op_t [MICROOPS_PER_INSTR:0] uop_t; 

typedef struct packed {
	logic [31:0] whole;
	logic [4:0] fract;
} uop_ip_t;

typedef struct packed {
	logic v;
	logic [31:0] next_ip;
	Qupls5_pkg::pipeline_group_hdr_t hdr;
	logic [31:4] tag;
	count_t [MWIDTH-1:0] count;
	uop_t [MWIDTH-1:0] uop;
} uop_cache_line_t;

integer n,n1,n2,n3,n4,n5,n6,n7,n8,n9,n10,n11,n12,n13,n14,n15,n16,n17,n18;
uop_cache_line_t [MICROOP_CACHE_SIZE-1:0] cache;
uop_cache_line_t fcl;
reg [2:0] cl [0:3];
Qupls5_pkg::rob_entry_t nopi;
uop_ip_t last_uop_ip, hold_ip;
uop_ip_t [4:0] uop_ip;
Qupls5_pkg::micro_op_t [3:0] iuop, uop_o;
reg [3:0] valid;
reg miss;
reg rd_more2,did_rd_more;

integer nc;

always_comb
	if ($bits(Qupls5_pkg::micro_op_t) > 256) begin
		$display("Micro-op too large.");
		$finish;
	end

// Define a NOP instruction.
always_comb
begin
	nopi = {$bits(Qupls5_pkg::rob_entry_t){1'b0}};
	nopi.op.exc = Qupls5_pkg::FLT_NONE;
	nopi.op.uop.opcode = Qupls5_pkg::fnNop();
	nopi.op.decbus.nop = TRUE;
	nopi.op.decbus.cause = Qupls5_pkg::FLT_NONE;
	nopi.op.uop.lead = 1'd1;
	nopi.op.v = 1'b1;
	nopi.v = 5'd1;
	nopi.exc = Qupls5_pkg::FLT_NONE;
	nopi.excv = INV;
	nopi.done = 2'b11;
	/* NOP will be decoded later
	nopi.decbus.Rdz = 1'b1;
	nopi.decbus.nop = 1'b1;
	nopi.decbus.alu = 1'b1;
	*/
end

// Fetch up to four micro-ops from the cache.
always_comb
begin
	fcl = {$bits(uop_cache_line_t){1'b0}};
	foreach(cl[n6])
		cl[n6] = 3'd0;
	foreach(uop[n6]) begin
		iuop[n6] = {$bits(micro_op_t){1'b0}};
		iuop[n6].opcode = Qupls5_pkg::fnNop();
	end
	foreach(valid[n6])
		valid[n6] = FALSE;
	// Reset micro-op IP on a branch
	/*
	if (rd_more2) begin
		uop_ip[0].whole = fnUcGetAddress(pg_trn.hdr.ip.cap);
		uop_ip[0].fract = 5'd0;
	end
	else
	*/
	if (miss)
		uop_ip[0] = hold_ip;
	else
		uop_ip[0] = last_uop_ip;
	uop_ip[1] = uop_ip[0];
	uop_ip[2] = uop_ip[0];
	uop_ip[3] = uop_ip[0];
	uop_ip[4] = uop_ip[0];
//	foreach (cache[n6])
	begin
		if (uop_ip[0].whole[31:4]==cache[0].tag && cache[0].v) begin
			cl[0] = 0;
			cl[1] = 0;
			cl[2] = 0;
			cl[3] = 0;
			valid[0] = VAL;
		end
		else if (uop_ip[0].whole[31:4]==cache[1].tag && cache[1].v) begin
			cl[0] = 1;
			cl[1] = 1;
			cl[2] = 1;
			cl[3] = 1;
			valid[0] = VAL;
		end
		else if (uop_ip[0].whole[31:4]==cache[2].tag && cache[2].v) begin
			cl[0] = 2;
			cl[1] = 2;
			cl[2] = 2;
			cl[3] = 2;
			valid[0] = VAL;
		end
		else if (uop_ip[0].whole[31:4]==cache[3].tag && cache[3].v) begin
			cl[0] = 3;
			cl[1] = 3;
			cl[2] = 3;
			cl[3] = 3;
			valid[0] = VAL;
		end
		if (cache[cl[0]].uop[uop_ip[0].whole[3:2]][uop_ip[0].fract].last) begin
			uop_ip[1].whole = uop_ip[0].whole + 4'd4;
			uop_ip[1].fract = 5'd0;
//			foreach(cache[n])
			begin
				if (uop_ip[1].whole[31:4]==cache[0].tag && cache[0].v) begin
					cl[1] = 0;
					cl[2] = 0;
					cl[3] = 0;
					valid[1] = valid[0];
				end
				else if (uop_ip[1].whole[31:4]==cache[1].tag && cache[1].v) begin
					cl[1] = 1;
					cl[2] = 1;
					cl[3] = 1;
					valid[1] = valid[0];
				end
				else if (uop_ip[1].whole[31:4]==cache[2].tag && cache[2].v) begin
					cl[1] = 2;
					cl[2] = 2;
					cl[3] = 2;
					valid[1] = valid[0];
				end
				else if (uop_ip[1].whole[31:4]==cache[3].tag && cache[3].v) begin
					cl[1] = 3;
					cl[2] = 3;
					cl[3] = 3;
					valid[1] = valid[0];
				end
			end
			if (cache[cl[1]].uop[uop_ip[1].whole[3:2]][uop_ip[1].fract].last) begin
				uop_ip[2].whole = uop_ip[1].whole + 4'd4;
				uop_ip[2].fract = 5'd0;
//				foreach(cache[n17])
				begin
					if (uop_ip[2].whole[31:4]==cache[0].tag && cache[0].v) begin
						cl[2] = 0;
						cl[3] = 0;
						valid[2] = valid[1];
					end
					else if (uop_ip[2].whole[31:4]==cache[1].tag && cache[1].v) begin
						cl[2] = 1;
						cl[3] = 1;
						valid[2] = valid[1];
					end
					else if (uop_ip[2].whole[31:4]==cache[2].tag && cache[2].v) begin
						cl[2] = 2;
						cl[3] = 2;
						valid[2] = valid[1];
					end
					else if (uop_ip[2].whole[31:4]==cache[3].tag && cache[3].v) begin
						cl[2] = 3;
						cl[3] = 3;
						valid[2] = valid[1];
					end
				end
				if (cache[cl[2]].uop[uop_ip[2].whole[3:2]][uop_ip[2].fract].last) begin
					uop_ip[3].whole = uop_ip[2].whole + 4'd4;
					uop_ip[3].fract = 5'd0;
//					foreach(cache[n])
					begin
						if (uop_ip[3].whole[31:4]==cache[0].tag && cache[0].v) begin
							cl[3] = 0;
							valid[3] = valid[2];
						end
						else if (uop_ip[3].whole[31:4]==cache[1].tag && cache[1].v) begin
							cl[3] = 1;
							valid[3] = valid[2];
						end
						else if (uop_ip[3].whole[31:4]==cache[2].tag && cache[2].v) begin
							cl[3] = 2;
							valid[3] = valid[2];
						end
						else if (uop_ip[3].whole[31:4]==cache[3].tag && cache[3].v) begin
							cl[3] = 3;
							valid[3] = valid[2];
						end
					end
					if (cache[cl[3]].uop[uop_ip[3].whole[3:2]][uop_ip[3].fract].last) begin
						uop_ip[4].whole = uop_ip[3].whole + 4'd4;
						uop_ip[4].fract = 5'd0;
					end
					else
						uop_ip[4].fract = uop_ip[3].fract + 5'd1;
				end
				else begin
					valid[3] = valid[2];
					uop_ip[3].fract = uop_ip[2].fract + 5'd1;
					if (cache[cl[3]].uop[uop_ip[3].whole[3:2]][uop_ip[3].fract].last) begin
						uop_ip[4].whole = uop_ip[3].whole + 4'd4;
						uop_ip[4].fract = 5'd0;
					end
					else
						uop_ip[4].fract = uop_ip[3].fract + 5'd1;
				end
			end
			else begin
				valid[2] = valid[1];
				uop_ip[2].fract = uop_ip[1].fract + 5'd1;
				if (cache[cl[2]].uop[uop_ip[2].whole[3:2]][uop_ip[2].fract].last) begin
					uop_ip[3].whole = uop_ip[2].whole + 4'd4;
					uop_ip[3].fract = 5'd0;
//					foreach(cache[n])
					begin
						if (uop_ip[3].whole[31:4]==cache[0].tag && cache[0].v) begin
							cl[3] = 0;
							valid[3] = valid[2];
						end
						else if (uop_ip[3].whole[31:4]==cache[1].tag && cache[1].v) begin
							cl[3] = 1;
							valid[3] = valid[2];
						end
						else if (uop_ip[3].whole[31:4]==cache[2].tag && cache[2].v) begin
							cl[3] = 2;
							valid[3] = valid[2];
						end
						else if (uop_ip[3].whole[31:4]==cache[3].tag && cache[3].v) begin
							cl[3] = 3;
							valid[3] = valid[2];
						end
					end
					if (cache[cl[3]].uop[uop_ip[3].whole[3:2]][uop_ip[3].fract].last) begin
						uop_ip[4].whole = uop_ip[3].whole + 4'd4;
						uop_ip[4].fract = 5'd0;
					end
					else
						uop_ip[4].fract = uop_ip[3].fract + 5'd1;
				end
				else begin
					valid[3] = valid[2];
					uop_ip[3].fract = uop_ip[2].fract + 5'd1;
					if (cache[cl[3]].uop[uop_ip[3].whole[3:2]][uop_ip[3].fract].last) begin
						uop_ip[4].whole = uop_ip[3].whole + 4'd4;
						uop_ip[4].fract = 5'd0;
					end
					else
						uop_ip[4].fract = uop_ip[3].fract + 5'd1;
				end
			end
		end
		else begin
			valid[1] = valid[0];
			uop_ip[1].fract = uop_ip[0].fract + 5'd1;
			if (cache[cl[1]].uop[uop_ip[1].whole[3:2]][uop_ip[1].fract].last) begin
				uop_ip[2].whole = uop_ip[1].whole + 4'd4;
				uop_ip[2].fract = 5'd0;
//				foreach(cache[n17])
				begin
					if (uop_ip[2].whole[31:4]==cache[0].tag && cache[0].v) begin
						cl[2] = 0;
						cl[3] = 0;
						valid[2] = valid[1];
					end
					else if (uop_ip[2].whole[31:4]==cache[1].tag && cache[1].v) begin
						cl[2] = 1;
						cl[3] = 1;
						valid[2] = valid[1];
					end
					else if (uop_ip[2].whole[31:4]==cache[2].tag && cache[2].v) begin
						cl[2] = 2;
						cl[3] = 2;
						valid[2] = valid[1];
					end
					else if (uop_ip[2].whole[31:4]==cache[3].tag && cache[3].v) begin
						cl[2] = 3;
						cl[3] = 3;
						valid[2] = valid[1];
					end
				end
				if (cache[cl[2]].uop[uop_ip[2].whole[3:2]][uop_ip[2].fract].last) begin
					uop_ip[3].whole = uop_ip[2].whole + 4'd4;
					uop_ip[3].fract = 5'd0;
//					foreach(cache[n])
					begin
						if (uop_ip[3].whole[31:4]==cache[0].tag && cache[0].v) begin
							cl[3] = 0;
							valid[3] = valid[2];
						end
						else if (uop_ip[3].whole[31:4]==cache[1].tag && cache[1].v) begin
							cl[3] = 1;
							valid[3] = valid[2];
						end
						else if (uop_ip[3].whole[31:4]==cache[2].tag && cache[2].v) begin
							cl[3] = 2;
							valid[3] = valid[2];
						end
						else if (uop_ip[3].whole[31:4]==cache[3].tag && cache[3].v) begin
							cl[3] = 3;
							valid[3] = valid[2];
						end
					end
					if (cache[cl[3]].uop[uop_ip[3].whole[3:2]][uop_ip[3].fract].last) begin
						uop_ip[4].whole = uop_ip[3].whole + 4'd4;
						uop_ip[4].fract = 5'd0;
					end
					else
						uop_ip[4].fract = uop_ip[3].fract + 5'd1;
				end
				else begin
					valid[3] = valid[2];
					uop_ip[3].fract = uop_ip[2].fract + 5'd1;
					if (cache[cl[3]].uop[uop_ip[3].whole[3:2]][uop_ip[3].fract].last) begin
						uop_ip[4].whole = uop_ip[3].whole + 4'd4;
						uop_ip[4].fract = 5'd0;
					end
					else
						uop_ip[4].fract = uop_ip[3].fract + 5'd1;
				end
			end
			else begin
				valid[2] = valid[1];
				uop_ip[2].fract = uop_ip[1].fract + 5'd1;
				if (cache[cl[2]].uop[uop_ip[2].whole[3:2]][uop_ip[2].fract].last) begin
					uop_ip[3].whole = uop_ip[2].whole + 4'd4;
					uop_ip[3].fract = 5'd0;
//					foreach(cache[n])
					begin
						if (uop_ip[3].whole[31:4]==cache[0].tag && cache[0].v) begin
							cl[3] = 0;
							valid[3] = valid[2];
						end
						else if (uop_ip[3].whole[31:4]==cache[1].tag && cache[1].v) begin
							cl[3] = 1;
							valid[3] = valid[2];
						end
						else if (uop_ip[3].whole[31:4]==cache[2].tag && cache[2].v) begin
							cl[3] = 2;
							valid[3] = valid[2];
						end
						else if (uop_ip[3].whole[31:4]==cache[3].tag && cache[3].v) begin
							cl[3] = 3;
							valid[3] = valid[2];
						end
					end
					if (cache[cl[3]].uop[uop_ip[3].whole[3:2]][uop_ip[3].fract].last) begin
						uop_ip[4].whole = uop_ip[3].whole + 4'd4;
						uop_ip[4].fract = 5'd0;
					end
					else
						uop_ip[4].fract = uop_ip[3].fract + 5'd1;
				end
				else begin
					valid[3] = valid[2];
					uop_ip[3].fract = uop_ip[2].fract + 5'd1;
					if (cache[cl[3]].uop[uop_ip[3].whole[3:2]][uop_ip[3].fract].last) begin
						uop_ip[4].whole = uop_ip[3].whole + 4'd4;
						uop_ip[4].fract = 5'd0;
					end
					else
						uop_ip[4].fract = uop_ip[3].fract + 5'd1;
				end
			end
		end
	end
	iuop[0] = cache[cl[0]].uop[uop_ip[0].whole[3:2]][uop_ip[0].fract];
	iuop[1] = cache[cl[1]].uop[uop_ip[1].whole[3:2]][uop_ip[1].fract];
	iuop[2] = cache[cl[2]].uop[uop_ip[2].whole[3:2]][uop_ip[2].fract];
	iuop[3] = cache[cl[3]].uop[uop_ip[3].whole[3:2]][uop_ip[3].fract];
	miss = ~&valid;
end


// Micro-op instruction pointer.
always_ff @(posedge clk)
if (rst) begin
	last_uop_ip.whole <= Qupls5_pkg::RSTPC;
	last_uop_ip.fract <= 5'd0;
	hold_ip.whole <= Qupls5_pkg::RSTPC;
	hold_ip.fract <= 5'd0;
end
else begin
	if (en) begin
	// If not a miss continue the counter from the last location. Otherwise
	// use the value of the miss address.
	if (~miss)
		last_uop_ip <= uop_ip[4];
	// If we got a miss the entire bundle is not in the cache. It will need to
	// be read. The pipeline will advance until the bundle is placed in the 
	// cache.
	else begin
		hold_ip <= uop_ip[0];
		last_uop_ip <= uop_ip[0];
		last_uop_ip.whole = fnUcGetAddress(pg_trn.hdr.ip.cap);
		last_uop_ip.fract = 5'd0;
	end
	end
end

// Cache update
// Cache is managed as a LRU cache with 8 fully associative entries.
always_ff @(posedge clk)
if (rst) begin
	foreach (cache[n8])
		cache[n8] <= {$bits(uop_cache_line_t){1'b0}};
end
else begin
	if (en) begin
		if (invalidate)
			foreach (cache[n8])
				cache[n8].v <= INV;
		if (did_rd_more & pg_ext.hdr.v) begin
			cache[MICROOP_CACHE_SIZE-1].next_ip <= fnUcGetAddress(pc_fet.cap);
			cache[MICROOP_CACHE_SIZE-1].hdr <= pg_trn.hdr;
			cache[MICROOP_CACHE_SIZE-1].tag <= fnUcGetAddress(pg_ext.hdr.ip.cap) >> 3'd4;
			cache[MICROOP_CACHE_SIZE-1].v <= VAL;
			foreach (uop_count[n8])
				cache[MICROOP_CACHE_SIZE-1].count[n8] <= uop_count[n8];
			foreach (uop[n8])
				cache[MICROOP_CACHE_SIZE-1].uop[n8] <= uop[n8];
			foreach (cache[n8])
				if (n8 < MICROOP_CACHE_SIZE-1)
					cache[n8] <= cache[n8+1];
		end
		else
			foreach(cache[n8])
				if (branch_resolved)
					if (cache[n8].hdr.ip.stream.thread==live_stream.thread && cache[n8].hdr.ip.stream.stream != live_stream.stream)
						cache[n8].v <= INV;
	end
end


always_ff @(posedge clk)
if (rst) begin
	pg_moq2 <= {$bits(Qupls5_pkg::pipeline_group_reg_t){1'b0}};
	foreach(pg_moq1.pr[n1])
		pg_moq2.pr[n1] <= nopi;
end
else begin
	if (en) begin
		pg_moq2.hdr <= fcl.hdr;
		if (stomp_moq2)
			pg_moq2.hdr.v <= INV;
		foreach (pg_moq2.pr[n1]) begin
			pg_moq2.pr[n1].v <= VAL;
			pg_moq2.pr[n1].op.uop <= iuop[n1];
			if (stomp_moq2) begin
				pg_moq2.pr[n1].stomped <= TRUE;
				pg_moq2.pr[n1].done <= 2'b11;
			end
			if (branch_resolved) begin
				if (fcl.hdr.ip.stream.thread==live_stream.thread && fcl.hdr.ip.stream.stream != live_stream.stream) begin
					pg_moq2.pr[n1].stomped <= TRUE;
					pg_moq2.pr[n1].done <= 2'b11;
				end
			end
		end
	end
end


always_ff @(posedge clk)
if (rst) begin
	rd_more <= TRUE;
	rd_more2 <= TRUE;
	did_rd_more <= FALSE;
end
else begin
	rd_more <= FALSE;
	if (en) begin
		rd_more <= miss;
		rd_more2 <= miss;
		did_rd_more <= rd_more2;
	end
end

endmodule
