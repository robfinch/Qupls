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
// Cache is four lines of four instructions (16 total instructions)
// Each instruction can have up to four micro-ops. So 64 total micro-ops.
// 7100 LUTs / 4800 FFs / 200 MHz	(4 microops per instruction)
// ============================================================================

import const_pkg::*;
import Qupls5_pkg::*;

module Qupls5_micro_op_cache(rst, clk, en, en2, rd_more,
	uop, uop_count,
	miss_o, stomp_moq2, pc_fet, pg_trn, pg_moq2,
	branch_resolved, live_stream, invalidate);
parameter MWIDTH = Qupls5_pkg::MWIDTH;
parameter MAX_MICROOPS = 8;
parameter MICROOPS_PER_INSTR = Qupls5_pkg::MICROOPS_PER_INSTR;
parameter MICROOP_CACHE_SIZE = 4;
parameter CACHE_LINES = 4;
input rst;
input clk;
input en;							// enable front-end micro-op cache loading
input en2;						// enable pipeline segment #2 output
output reg rd_more;		// used in pipeline enable logic
// Incoming micro-ops and thier counts from extract stage
input Qupls5_pkg::micro_op_t [MICROOPS_PER_INSTR-1:0] uop [MWIDTH-1:0];
input [5:0] uop_count [0:MWIDTH-1];
input stomp_moq2;
output reg miss_o;		// used in seg2 pipeline enable
input Qupls5_pkg::pc_address_ex_t pc_fet;
input Qupls5_pkg::pipeline_group_reg_t pg_trn;
output Qupls5_pkg::pipeline_group_reg_t pg_moq2;
input branch_resolved;
// Which instruction stream is the one in use.
input pc_stream_t live_stream;
input invalidate;			// invalidate the micro-op cache

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// Variable type declarations.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

// Types defined so an array can be put in a struct.
typedef logic [4:0] count_t;
typedef Qupls5_pkg::micro_op_t [MICROOPS_PER_INSTR-1:0] uop_t; 

// micro-op pointer type. Has a whole and a fractional portion. The whole portion
// indexes according to instructions. The fractional portion indexes according to
// the micro-op within an instruction.
typedef struct packed {
	logic v;
	logic [2:0] row;
	logic [4:0] col;
} uop_ip_t;

// Note the address in the header is used as the tag. It is the same value so,
// there is no point in having an explicit tag.
typedef struct packed {
	logic [31:0] next_ip;									// next bundle prediction
	Qupls5_pkg::pipeline_group_hdr_t hdr;	// pipeline header, contains address tag
	Qupls5_pkg::micro_op_t [15:0] uop;		// array of micro-ops for instr.
} uop_cache_line_t;

typedef struct packed {
	uop_ip_t [CACHE_LINES-1:0] cookies;
	uop_cache_line_t [CACHE_LINES-1:0] line;
} uop_cache_t;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// Constants.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

Qupls5_pkg::micro_op_t uop_nop;
Qupls5_pkg::rob_entry_t nopi;		// A NOP instruction (constant)

always_comb
begin
	uop_nop = {$bits(Qupls5_pkg::micro_op_t){1'b0}};
	uop_nop.opcode = Qupls5_pkg::fnNop();
	uop_nop.v = VAL;
end

// Define a constant NOP instruction.
always_comb
begin
	nopi = {$bits(Qupls5_pkg::rob_entry_t){1'b0}};
	nopi.op.exc = Qupls5_pkg::FLT_NONE;
	nopi.op.uop.opcode = Qupls5_pkg::fnNop();
	nopi.op.decbus.nop = TRUE;
	nopi.op.decbus.cause = Qupls5_pkg::FLT_NONE;
	nopi.op.uop.lead = 1'd1;
	nopi.op.uop.last = 1'd1;
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

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// Variables.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

// Generic integers used in foreach() loops
integer n,n1,n2,n3,n4,n5,n6,n7,n8,n9,n10,n11,n12,n13,n14,n15,n16,n17,n18;

// The micro-op cache itself.
uop_cache_t cache;
// Micro-op instruction pointers.
uop_ip_t [4:0] uop_ip;
uop_ip_t last_uop_ip, hold_ip;
// micro-ops selected from the cache destined for pipeline.
Qupls5_pkg::micro_op_t [3:0] iuop;
// Which selected micro-ops are valid. Note as soon as an invalid micro-op is
// detected, the following ones are also considered invalid. There cannot be
// an instruction which has invalid micro-ops in the middle.
reg [3:0] valid;
// Signals to advance or stall the pipeline.
reg rd_more2,did_rd_more,did_rd_more2;
reg miss, rmiss;			// micro-op cache miss and registered miss signals.
// Signal that indicates a cache line must be evicted so new data can be placed.
reg evict;
integer ev;		// for the foreach() loop
integer row1,row2;

// Lets make sure our micro-op is sane. If it is too large it will take forever to
// compile and simulate.
always_comb
	if ($bits(Qupls5_pkg::micro_op_t) > 256) begin
		$display("Micro-op too large.");
		$finish;
	end

// Fetch up to four micro-ops from the cache.
// The complicated part is calculating the indexes into the cache of each micro-op.
// Getting the first index value is not too bad. It is just the first cache line
// with a matching address. After that indexes need to be greater than the previous
// one, skipping over empty micro-op slots. More difficult than it sounds as the
// matching cache line might change.
// Setting the indexes is organized in a trisngular waterfall structure. Things are
// unrolled. Each index depends on the previous one. This would not be workable if
// there were a lot of them Fortunately there are only four.
// Note the way valid is set. As soon as there is an invalid, the remaining status
// are set to invalid. That means the next valid depends on the previous one.
always_comb
begin
	// Step 1: initialize all the vars to known values. Since this is combo code it
	// should prevent latches. We guarentee the vars are always going to have some
	// sort of value.
	/*
	foreach(uop[n6]) begin
		iuop[n6] = {$bits(micro_op_t){1'b0}};
		iuop[n6].v = INV;
		iuop[n6].opcode = Qupls5_pkg::fnNop();
		iuop[n6].lead = TRUE;
		iuop[n6].last = TRUE;
	end
	*/
	// If there was a miss, we want to repeat the last access until there is a hit,
	// at which point the index can advance to just past the last index value.
	// An "extra" index is used to record the position.
	if (miss) begin
		uop_ip[0] = hold_ip;			// registered signal, see below.
		uop_ip[1] = hold_ip;
		uop_ip[2] = hold_ip;
		uop_ip[3] = hold_ip;
		uop_ip[4] = hold_ip;
	end
	else begin
		uop_ip[0] = last_uop_ip;	// registered signal 
		uop_ip[1] = last_uop_ip;
		uop_ip[2] = last_uop_ip;
		uop_ip[3] = last_uop_ip;
		uop_ip[4] = last_uop_ip;
	end

	if (cache.line[uop_ip[0].row].hdr.v)
		iuop[0] = cache.line[uop_ip[0].row].uop[uop_ip[0].col];
	else
		iuop[0].v = INV;
	if (cache.line[uop_ip[0].row].uop[uop_ip[0].col].last)
		uop_ip[1] = cache.cookies[uop_ip[0].row];
	else begin
		uop_ip[1].row = uop_ip[0].row;
		uop_ip[1].col = uop_ip[0].col + 1;
	end
	if (uop_ip[1].v) begin
		if (cache.line[uop_ip[1].row].hdr.v)
			iuop[1] = cache.line[uop_ip[1].row][uop_ip[1].col];
		else
			iuop[1].v = INV;
		if (cache.line[uop_ip[1].row].uop[uop_ip[1].col].last)
			uop_ip[2] = cache.cookies[uop_ip[1].row];
		else begin
			uop_ip[2].row = uop_ip[1].row;
			uop_ip[2].col = uop_ip[1].col + 1;
		end
		if (uop_ip[2].v) begin
			if (cache.line[uop_ip[1].row].hdr.v)
				iuop[2] = cache.line[uop_ip[2].row][uop_ip[2].col];
			else
				iuop[2].v = INV;
			if (cache.line[uop_ip[2].row].uop[uop_ip[2].col].last)
				uop_ip[3] = cache.cookies[uop_ip[2].row];
			else begin
				uop_ip[3].row = uop_ip[2].row;
				uop_ip[3].col = uop_ip[2].col + 1;
			end
			if (uop_ip[3].v) begin
				if (cache.line[uop_ip[3].row].hdr.v)
					iuop[3] = cache.line[uop_ip[3].row].uop[uop_ip[3].col];
				else
					iuop[3].v = INV;
			end
			else
				iuop[3] = uop_nop;
		end
		else begin
			iuop[2] = uop_nop;
			iuop[3] = uop_nop;
		end
	end
	else begin
		iuop[1] = uop_nop;
		iuop[2] = uop_nop;
		iuop[3] = uop_nop;
	end
	// If the uop IP's are not valid set following micro-ops to NOPs.
	// Likely hit a missing cookie at the last micro-op.
	if (!uop_ip[1].v) begin
		iuop[1] = uop_nop;
		iuop[2] = uop_nop;
		iuop[3] = uop_nop;
	end
	if (!uop_ip[2].v) begin
		iuop[2] = uop_nop;
		iuop[3] = uop_nop;
	end
	if (!uop_ip[3].v)
		iuop[3] = uop_nop;
	valid = {iuop[3].v,iuop[2].v,iuop[1].v,iuop[0].v};
	miss = ~(iuop[0].v & iuop[1].v & iuop[2].v & iuop[3].v);
end

// Micro-op instruction pointer.
always_ff @(posedge clk)
if (rst) begin
	last_uop_ip.row <= 3'd3;
	last_uop_ip.col <= 5'd0;
	last_uop_ip.v <= VAL;
	hold_ip.row <= 3'd3;
	hold_ip.col <= 5'd0;
	hold_ip.v <= VAL;
	rmiss <= FALSE;
end
else begin
	if (en2) begin
		rmiss <= miss;
		// If we got a miss the entire bundle is not in the cache. It will need to
		// be read. The pipeline will advance until the bundle is placed in the 
		// cache.
		if (miss||rmiss) begin
			hold_ip <= uop_ip[0];
			if (pg_trn.hdr.v & ~pg_trn.pr[0].stomped) begin
//				last_uop_ip <= uop_ip[0];
				last_uop_ip.row = CACHE_LINES-1;
				last_uop_ip.col = 5'd0;
				last_uop_ip.v = VAL;
			end
		end
		// If not a miss continue the counter from the last location. Otherwise
		// use the value of the miss address.
		else
			last_uop_ip <= uop_ip[4];
	end
end

always_comb
	miss_o = miss|rmiss;

// Detect if a line needs to be evicted from the cache to allow new data.
always_comb
begin
	evict = TRUE;	// Assume needed
	foreach(cache.line[ev])
		if (fnUcGetAddress(cache.line[ev].hdr.ip.cap)==fnUcGetAddress(pg_trn.hdr.ip.cap))
			evict = FALSE;	// we can overwrite
end

// Cache update
// Cache is managed as a LRU cache with 4 fully associative entries.
// Accomplished by shifting cache lines down when loading due to amiss.
always_ff @(posedge clk)
if (rst) begin
	foreach (cache.line[n8])
		cache.line[n8] <= {$bits(uop_cache_line_t){1'b0}};
	foreach (cache.cookies[n8])
		cache.cookies[n8] <= {$bits(uop_ip_t){1'b0}};
end
else begin
	if (en) begin
		if (invalidate)
			foreach (cache.line[n8])
				cache.line[n8].hdr.v <= INV;
		// Incming from the pipe valid?
		if (pg_trn.hdr.v & ~pg_trn.pr[0].stomped) begin
			if (evict) begin
				// Open up a space in the cache by shifting lines down.
				foreach (cache.line[n8]) begin
					cache.cookies[n8].v <= INV;
					if (n8 < CACHE_LINES-1)
						cache.line[n8] <= cache.line[n8+1];
				end
				// And insert the new data
				tSetCacheLine(CACHE_LINES-1);
			end
			// Not evicting a line, overwrite existing data.
			else begin
				foreach (cache.line[n8])
					if (fnUcGetAddress(cache.line[n8].hdr.ip.cap)==fnUcGetAddress(pg_trn.hdr.ip.cap))
						tSetCacheLine(n8);
			end
		end
		// Not valid, nothing to update but, check for branch resolutions.
		else
			foreach(cache.line[n8])
				// If a branch resolved, kill all the streams except the live one for the thread.
				if (branch_resolved)
					if (cache.line[n8].hdr.ip.stream.thread==live_stream.thread && cache.line[n8].hdr.ip.stream.stream != live_stream.stream)
						cache.line[n8].hdr.v <= INV;

		// Set cache cookies
		// After inserting a new cache line, the cookies won't be valid. They will
		// be made valid in the next clock cycle.
		foreach(cache.line[row1]) begin
			cache.cookies[row1].v <= INV;
			cache.cookies[row1].row <= 3'd0;
			cache.cookies[row1].col <= 3'd0;
			foreach(cache.line[row2])
				if (fnUcGetAddress(cache.line[row1].hdr.ip.cap)==cache.line[row2].next_ip) begin
					cache.cookies[row2].v <= VAL;
					cache.cookies[row2].row <= row1;
					cache.cookies[row2].col <= 3'd0;
				end
		end
	end
end

// Set the cache line with new data.
task tSetCacheLine;
input integer n;
integer n8;
begin
	// pc_fet because trn and ext are the same stage
	cache.line[n].next_ip <= fnUcGetAddress(pc_fet.cap);
	cache.line[n].hdr <= pg_trn.hdr;
	// Pack micro-ops at load time.
	for (n8 = 0; n8 < 16; n8 = n8 + 1)
		cache.line[n].uop[n8] <= uop_nop;
	// copy first four micro-ops
	for (n8 = 0; n8 < 4; n8 = n8 + 1)
		cache.line[n].uop[n8] <= uop[0][n8];
	// copy second four micro-ops
	for (n8 = 0; n8 < 4; n8 = n8 + 1)
		cache.line[n].uop[n8+uop_count[0]] <= uop[1][n8];
	// copy third four micro-ops
	for (n8 = 0; n8 < 4; n8 = n8 + 1)
		cache.line[n].uop[n8+uop_count[0]+uop_count[1]] <= uop[2][n8];
	// copy fourth four micro-ops
	for (n8 = 0; n8 < 4; n8 = n8 + 1)
		cache.line[n].uop[n8+uop_count[0]+uop_count[1]+uop_count[2]] <= uop[3][n8];
end
endtask

// Setup the output pipeline register. Pass selected instructions down the pipe.
always_ff @(posedge clk)
if (rst) begin
	pg_moq2 <= {$bits(Qupls5_pkg::pipeline_group_reg_t){1'b0}};
	foreach(pg_moq2.pr[n1])
		pg_moq2.pr[n1] <= nopi;
end
else begin
	if (en2) begin	// segment 2 enable.
		// If selected first cache line valid...
		if (uop_ip[0].v) begin
			pg_moq2.hdr <= cache.line[uop_ip[0].row].hdr;
			pg_moq2.hdr.v <= ~miss;
		end
		// If selected first cache line not valid, set pipeline reg invalid.
		else begin
			pg_moq2.hdr <= {$bits(Qupls5_pkg::pipeline_group_hdr_t){1'b0}};
			pg_moq2.hdr.v <= INV;
			pg_moq2.hdr.irq_sn <= 8'h00;
			pg_moq2.hdr.irq <= 6'd0;
			pg_moq2.hdr.old_ipl <= 6'd0;
			pg_moq2.hdr.hwi <= FALSE;
			pg_moq2.hdr.ip <= {$bits(pc_address_ex_t){1'b0}};
		end
		if (stomp_moq2)
			pg_moq2.hdr.v <= INV;
		foreach (pg_moq2.pr[n1]) begin
			pg_moq2.pr[n1].v <= VAL;
			pg_moq2.pr[n1].op.uop <= iuop[n1];	// copy selected micro-op into pipe reg.
			if (stomp_moq2) begin
				pg_moq2.pr[n1].stomped <= TRUE;
				pg_moq2.pr[n1].done <= 2'b11;			// If it got stomped on it's finished.
			end
			// Finally, did a branch resolve?
			if (branch_resolved && uop_ip[0].v) begin
				if (cache.line[uop_ip[0].row].hdr.ip.stream.thread==live_stream.thread &&
				 cache.line[uop_ip[0].row].hdr.ip.stream.stream != live_stream.stream) begin
					pg_moq2.pr[n1].stomped <= TRUE;
					pg_moq2.pr[n1].done <= 2'b11;
				end
			end
		end
	end
end


// Reading more signal used to advance the front end so the cache can be loaded.
// We need to read more only if there was a cache miss. Otherwise we could 
// probably shut down the front-end (ToDo).
always_ff @(posedge clk)
if (rst) begin
//	rd_more <= TRUE;
	rd_more2 <= TRUE;
	did_rd_more <= FALSE;
	did_rd_more2 <= FALSE;
end
else begin
//	rd_more <= FALSE;
	if (en2)
	begin
//		rd_more <= miss;
//		rd_more2 <= miss;
		did_rd_more <= rd_more;
		did_rd_more2 <= did_rd_more;
	end
end

// It takes two clock cycles for the front-end to supply data to this
// pipeline stage. So wait a couple of clocks after asserting rd_more
// before asserting it again.
always_comb
	rd_more = miss & ~did_rd_more & ~did_rd_more2;

endmodule

