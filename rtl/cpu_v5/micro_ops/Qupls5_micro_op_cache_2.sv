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
// 20700 LUTs / 15700 FFs / 86 MHz	(4 microops per instruction)
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
	logic [31:0] whole;
	logic [4:0] fract;
} uop_ip_t;

// Note the address in the header is used as the tag. It is the same value so,
// there is no point in having an explicit tag.
typedef struct packed {
	logic [31:0] next_ip;									// next bundle prediction
	Qupls5_pkg::pipeline_group_hdr_t hdr;	// pipeline header, contains address
	count_t [MWIDTH-1:0] count;						// how many micro-ops in the instr.
	uop_t [MWIDTH-1:0] uop;								// array of micro-ops for instr.
} uop_cache_line_t;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// Variables.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

// Generic integers used in foreach() loops
integer n,n1,n2,n3,n4,n5,n6,n7,n8,n9,n10,n11,n12,n13,n14,n15,n16,n17,n18;

// The micro-op cache itself.
uop_cache_line_t [MICROOP_CACHE_SIZE-1:0] cache;
reg [2:0] fcl;				// index of first choosen cache line
reg [2:0] cl [0:3];		// indexes of cache lines instructions are on
Qupls5_pkg::rob_entry_t nopi;		// A NOP instruction (constant)
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
// Just for wiring convenience.
reg [27:0] tag [0:3];
// Signal that indicates a cache line must be evicted so new data can be placed.
reg evict;
integer ev;		// for the foreach() loop


// Lets make sure our micro-op is sane. If it is too large it will take forever to
// compile and simulate.
always_comb
	if ($bits(Qupls5_pkg::micro_op_t) > 256) begin
		$display("Micro-op too large.");
		$finish;
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
	fcl = 3'd7;			// Used to select pipeline group header.
	foreach(cl[n6])
		cl[n6] = 3'd0;
	foreach(uop[n6]) begin
		iuop[n6] = {$bits(micro_op_t){1'b0}};
		iuop[n6].v = VAL;
		iuop[n6].opcode = Qupls5_pkg::fnNop();
		iuop[n6].lead = TRUE;
		iuop[n6].last = TRUE;
	end
	foreach(valid[n6])
		valid[n6] = INV;
	foreach(tag[n6])
		tag[n6] = fnUcGetAddress(cache[n6].hdr.ip.cap) >> 4;
	// Reset micro-op IP on a branch
	/*
	if (rd_more2) begin
		uop_ip[0].whole = fnUcGetAddress(pg_trn.hdr.ip.cap);
		uop_ip[0].fract = 5'd0;
	end
	else
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
//	foreach (cache[n6]) unrolled
	begin
		// Set the first index: easy, just point to a cache line with a tag match.
		if (uop_ip[0].whole[31:4]==tag[0] && cache[0].hdr.v) begin
			fcl = 0;
			cl[0] = 0;
			cl[1] = 0;
			cl[2] = 0;
			cl[3] = 0;
			valid[0] = VAL;
		end
		else if (uop_ip[0].whole[31:4]==tag[1] && cache[1].hdr.v) begin
			fcl = 1;
			cl[0] = 1;
			cl[1] = 1;
			cl[2] = 1;
			cl[3] = 1;
			valid[0] = VAL;
		end
		else if (uop_ip[0].whole[31:4]==tag[2] && cache[2].hdr.v) begin
			fcl = 2;
			cl[0] = 2;
			cl[1] = 2;
			cl[2] = 2;
			cl[3] = 2;
			valid[0] = VAL;
		end
		else if (uop_ip[0].whole[31:4]==tag[3] && cache[3].hdr.v) begin
			fcl = 3;
			cl[0] = 3;
			cl[1] = 3;
			cl[2] = 3;
			cl[3] = 3;
			valid[0] = VAL;
		end
		// First index pointing at last uop of instruction? If so, we want to
		// set the next index to the start of the next instruction.
		if (cache[cl[0]].uop[uop_ip[0].whole[3:2]][uop_ip[0].fract].last) begin
			// point to index at next whole instruction
			uop_ip[1].whole = uop_ip[0].whole + 4'd4;
			uop_ip[1].fract = 5'd0;		// start of instruction
			// cache line may have changed...
//			foreach(cache[n])
			begin
				if (uop_ip[1].whole[31:4]==tag[0] && cache[0].hdr.v) begin
					cl[1] = 0;
					cl[2] = 0;
					cl[3] = 0;
					valid[1] = valid[0];
				end
				else if (uop_ip[1].whole[31:4]==tag[1] && cache[1].hdr.v) begin
					cl[1] = 1;
					cl[2] = 1;
					cl[3] = 1;
					valid[1] = valid[0];
				end
				else if (uop_ip[1].whole[31:4]==tag[2] && cache[2].hdr.v) begin
					cl[1] = 2;
					cl[2] = 2;
					cl[3] = 2;
					valid[1] = valid[0];
				end
				else if (uop_ip[1].whole[31:4]==tag[3] && cache[3].hdr.v) begin
					cl[1] = 3;
					cl[2] = 3;
					cl[3] = 3;
					valid[1] = valid[0];
				end
			end
			// Was the second index pointing at the last uop of the instruction?
			// If so update the third indexx to point at the next instruction,
			// otherwise the third index will just be an increment.
			if (cache[cl[1]].uop[uop_ip[1].whole[3:2]][uop_ip[1].fract].last) begin
				uop_ip[2].whole = uop_ip[1].whole + 4'd4;
				uop_ip[2].fract = 5'd0;
//				foreach(cache[n17])
				begin
					if (uop_ip[2].whole[31:4]==tag[0] && cache[0].hdr.v) begin
						cl[2] = 0;
						cl[3] = 0;
						valid[2] = valid[1];
					end
					else if (uop_ip[2].whole[31:4]==tag[1] && cache[1].hdr.v) begin
						cl[2] = 1;
						cl[3] = 1;
						valid[2] = valid[1];
					end
					else if (uop_ip[2].whole[31:4]==tag[2] && cache[2].hdr.v) begin
						cl[2] = 2;
						cl[3] = 2;
						valid[2] = valid[1];
					end
					else if (uop_ip[2].whole[31:4]==tag[3] && cache[3].hdr.v) begin
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
						if (uop_ip[3].whole[31:4]==tag[0] && cache[0].hdr.v) begin
							cl[3] = 0;
							valid[3] = valid[2];
						end
						else if (uop_ip[3].whole[31:4]==tag[1] && cache[1].hdr.v) begin
							cl[3] = 1;
							valid[3] = valid[2];
						end
						else if (uop_ip[3].whole[31:4]==tag[2] && cache[2].hdr.v) begin
							cl[3] = 2;
							valid[3] = valid[2];
						end
						else if (uop_ip[3].whole[31:4]==tag[3] && cache[3].hdr.v) begin
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
						if (uop_ip[3].whole[31:4]==tag[0] && cache[0].hdr.v) begin
							cl[3] = 0;
							valid[3] = valid[2];
						end
						else if (uop_ip[3].whole[31:4]==tag[1] && cache[1].hdr.v) begin
							cl[3] = 1;
							valid[3] = valid[2];
						end
						else if (uop_ip[3].whole[31:4]==tag[2] && cache[2].hdr.v) begin
							cl[3] = 2;
							valid[3] = valid[2];
						end
						else if (uop_ip[3].whole[31:4]==tag[3] && cache[3].hdr.v) begin
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
		// Here index was not pointing at last micro-op so we can just add one
		// to it to generate the index of the next uop.
		else begin
			valid[1] = valid[0];
			uop_ip[1].fract = uop_ip[0].fract + 5'd1;
			if (cache[cl[1]].uop[uop_ip[1].whole[3:2]][uop_ip[1].fract].last) begin
				uop_ip[2].whole = uop_ip[1].whole + 4'd4;
				uop_ip[2].fract = 5'd0;
//				foreach(cache[n17])
				begin
					if (uop_ip[2].whole[31:4]==tag[0] && cache[0].hdr.v) begin
						cl[2] = 0;
						cl[3] = 0;
						valid[2] = valid[1];
					end
					else if (uop_ip[2].whole[31:4]==tag[1] && cache[1].hdr.v) begin
						cl[2] = 1;
						cl[3] = 1;
						valid[2] = valid[1];
					end
					else if (uop_ip[2].whole[31:4]==tag[2] && cache[2].hdr.v) begin
						cl[2] = 2;
						cl[3] = 2;
						valid[2] = valid[1];
					end
					else if (uop_ip[2].whole[31:4]==tag[3] && cache[3].hdr.v) begin
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
						if (uop_ip[3].whole[31:4]==tag[0] && cache[0].hdr.v) begin
							cl[3] = 0;
							valid[3] = valid[2];
						end
						else if (uop_ip[3].whole[31:4]==tag[1] && cache[1].hdr.v) begin
							cl[3] = 1;
							valid[3] = valid[2];
						end
						else if (uop_ip[3].whole[31:4]==tag[2] && cache[2].hdr.v) begin
							cl[3] = 2;
							valid[3] = valid[2];
						end
						else if (uop_ip[3].whole[31:4]==tag[3] && cache[3].hdr.v) begin
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
						if (uop_ip[3].whole[31:4]==tag[0] && cache[0].hdr.v) begin
							cl[3] = 0;
							valid[3] = valid[2];
						end
						else if (uop_ip[3].whole[31:4]==tag[1] && cache[1].hdr.v) begin
							cl[3] = 1;
							valid[3] = valid[2];
						end
						else if (uop_ip[3].whole[31:4]==tag[2] && cache[2].hdr.v) begin
							cl[3] = 2;
							valid[3] = valid[2];
						end
						else if (uop_ip[3].whole[31:4]==tag[3] && cache[3].hdr.v) begin
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
	// Pull four micro-ops from the cache using the calculated indexes.
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
				last_uop_ip <= uop_ip[0];
				last_uop_ip.whole = fnUcGetAddress(pg_trn.hdr.ip.cap);
				last_uop_ip.fract = 5'd0;
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
	foreach(cache[ev])
		if (fnUcGetAddress(cache[ev].hdr.ip.cap)==fnUcGetAddress(pg_trn.hdr.ip.cap))
			evict = FALSE;	// we can overwrite
end

// Cache update
// Cache is managed as a LRU cache with 4 fully associative entries.
// Accomplished by shifting cache lines down when loading due to amiss.
always_ff @(posedge clk)
if (rst) begin
	foreach (cache[n8])
		cache[n8] <= {$bits(uop_cache_line_t){1'b0}};
end
else begin
	if (en) begin
		if (invalidate)
			foreach (cache[n8])
				cache[n8].hdr.v <= INV;
		// Incming from the pipe valid?
		if (pg_trn.hdr.v & ~pg_trn.pr[0].stomped) begin
			if (evict) begin
				// Open up a space in the cache by shifting lines down.
				foreach (cache[n8])
					if (n8 < $size(cache)-1)
						cache[n8] <= cache[n8+1];
				// And insert the new data
				tSetCacheLine($size(cache)-1);
			end
			// Not evicting a line, overwrite existing data.
			else begin
				foreach (cache[n8])
					if (fnUcGetAddress(cache[n8].hdr.ip.cap)==fnUcGetAddress(pg_trn.hdr.ip.cap))
						tSetCacheLine(n8);
			end
		end
		// Not valid, nothing to update but, check for branch resolutions.
		else
			foreach(cache[n8])
				// If a branch resolved, kill all the streams except the live one for the thread.
				if (branch_resolved)
					if (cache[n8].hdr.ip.stream.thread==live_stream.thread && cache[n8].hdr.ip.stream.stream != live_stream.stream)
						cache[n8].hdr.v <= INV;
	end
end

// Set the cache line with new data.
task tSetCacheLine;
input integer n;
integer n8;
begin
	// pc_fet because trn and ext are the same stage
	cache[n].next_ip <= fnUcGetAddress(pc_fet.cap);
	cache[n].hdr <= pg_trn.hdr;
	// Copy new cache line values from incoming extract stage output.
	foreach (uop_count[n8])
		cache[n].count[n8] <= uop_count[n8];
	foreach (uop[n8])
		cache[n].uop[n8] <= uop[n8];
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
		if (fcl < 3'd7) begin
			pg_moq2.hdr <= cache[fcl].hdr;
			pg_moq2.hdr.v <= &valid;
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
			if (branch_resolved && fcl < 3'd7) begin
				if (cache[fcl].hdr.ip.stream.thread==live_stream.thread && cache[fcl].hdr.ip.stream.stream != live_stream.stream) begin
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
//	if (en2)
	begin
//		rd_more <= miss;
		rd_more2 <= miss;
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
