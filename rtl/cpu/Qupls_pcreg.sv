// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// Qupls_pcreg.sv
// - program counter
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
// ============================================================================

import QuplsPkg::*;

module Qupls_pcreg(rst, clk, irq, hit, next_pc, next_micro_ip, backpc,
	branchmiss, branchmiss_state, misspc, branchback, fetchbuf_flag,
	fetchbuf, backbr[8], pc
);
input rst;
input clk;
input irq;
input hit;
input pc_address_t next_pc;
input [11:0] next_micro_ip;
input pc_address_t backpc;
input branchmiss;
input [2:0] branchmiss_state;
input pc_address_t misspc;
input branchback;
input fetchbuf_flag;
input instruction_fetchbuf_t [7:0] fetchbuf;
input [7:0] backbr;
output pc_address_t pc;

reg did_branchback;
always_ff @(posedge clk)
if (rst)
	did_branchback <= 1'b0;
else
	did_branchback <= branchback;

always_ff @(posedge clk)
if (rst)
	pc <= RSTPC;
else begin

	if (branchmiss) begin
		if (branchmiss_state==3'd2)
    	pc <= misspc;
  end
	else begin
		if (branchback) begin

	    // update the fetchbuf valid bits as well as fetchbuf itself
	    // ... this must be based on which things are backwards branches, how many things
	    // will get enqueued (0, 1, or 2), and how old the instructions are
	    if (fetchbuf_flag == 1'b0) case ({fetchbuf[0].v, fetchbuf[1].v, fetchbuf[2].v, fetchbuf[3].v, fetchbuf[4].v, fetchbuf[5].v, fetchbuf[6].v, fetchbuf[7].v})

			8'b00010000:
				if (backbr[3])
					tUpdatePC();
					
			8'b00100000:
				if (backbr[2])
					tUpdatePC();
			
			// if fbB has the branchback, can't immediately tell which of the following scenarios it is:
			//   cycle 0 - fetched a pair of instructions, one or both of which is a branchback
			//   cycle 1 - where we are now.  stomp, enqueue, and update pc0/pc1
			// or
			//   cycle 0 - fetched a INSTR+BEQ, with fbB holding a branchback
			//   cycle 1 - could not enqueue fbA or fbB, stalled fetch + updated pc0/pc1
			//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufX_v appropriately
			// if fbA has the branchback, then it is scenario 1.
			// if fbB has it: if pc0 == fbB_pc, then it is the former scenario, else it is the latter
			8'b00110000:
				if (backbr[2])
			    // has to be first scenario
			    pc <= backpc;
				else if (backbr[3]) begin
			    if (did_branchback)
			    	tUpdatePC();
			    else
						pc <= backpc;
				end

			8'b01000000:
				if (backbr[1])
					tUpdatePC();
			
			8'b01010000:
				if (backbr[1])
			    // has to be first scenario
			    pc <= backpc;
				else if (backbr[3]) begin
			    if (did_branchback)
			    	tUpdatePC();
			    else
						pc <= backpc;
				end

			8'b01100000:
				if (backbr[1])
			    // has to be first scenario
			    pc <= backpc;
				else if (backbr[2]) begin
			    if (did_branchback)
			    	tUpdatePC();
			    else
						pc <= backpc;
				end

			8'b01110000:
				if (backbr[1]|backbr[2])
			    pc <= backpc;
				else if (backbr[3]) begin
			    if (did_branchback)
			    	tUpdatePC();
			    else
						pc <= backpc;
				end

			8'b10000000:
				if (backbr[0])
					tUpdatePC();
			
			8'b10010000:
				if (backbr[0])
			    // has to be first scenario
			    pc <= backpc;
				else if (backbr[3]) begin
			    if (did_branchback)
			    	tUpdatePC();
			    else
						pc <= backpc;
				end

			8'b10100000:
				if (backbr[0])
			    // has to be first scenario
			    pc <= backpc;
				else if (backbr[2]) begin
			    if (did_branchback)
			    	tUpdatePC();
			    else
						pc <= backpc;
				end

			8'b10110000:
				if (backbr[0]|backbr[2])
			    pc <= backpc;
				else if (backbr[3]) begin
			    if (did_branchback)
			    	tUpdatePC();
			    else
						pc <= backpc;
				end

			8'b11000000:
				if (backbr[0])
			    // has to be first scenario
			    pc <= backpc;
				else if (backbr[1]) begin
			    if (did_branchback)
			    	tUpdatePC();
			    else
						pc <= backpc;
				end

			8'b11010000:
				if (backbr[0]|backbr[1])
			    pc <= backpc;
				else if (backbr[3]) begin
			    if (did_branchback)
			    	tUpdatePC();
			    else
						pc <= backpc;
				end

			8'b11100000:
				if (backbr[0]|backbr[1])
			    pc <= backpc;
				else if (backbr[2]) begin
			    if (did_branchback)
			    	tUpdatePC();
			    else
						pc <= backpc;
				end

			8'b11110000:
				if (backbr[0]|backbr[1]|backbr[2])
			    pc <= backpc;
				else if (backbr[3]) begin
			    if (did_branchback)
			    	tUpdatePC();
			    else
						pc <= backpc;
				end

			default	: ;	// do nothing

		  endcase
	    else
	    case ({fetchbuf[4].v, fetchbuf[5].v, fetchbuf[6].v, fetchbuf[7].v, fetchbuf[0].v, fetchbuf[1].v, fetchbuf[2].v, fetchbuf[3].v})

			8'b00010000:
				if (backbr[7])
					tUpdatePC();
					
			8'b00100000:
				if (backbr[6])
					tUpdatePC();
			
			// if fbB has the branchback, can't immediately tell which of the following scenarios it is:
			//   cycle 0 - fetched a pair of instructions, one or both of which is a branchback
			//   cycle 1 - where we are now.  stomp, enqueue, and update pc0/pc1
			// or
			//   cycle 0 - fetched a INSTR+BEQ, with fbB holding a branchback
			//   cycle 1 - could not enqueue fbA or fbB, stalled fetch + updated pc0/pc1
			//   cycle 2 - where we are now ... fetch the two instructions & update fetchbufX_v appropriately
			// if fbA has the branchback, then it is scenario 1.
			// if fbB has it: if pc0 == fbB_pc, then it is the former scenario, else it is the latter
			8'b00110000:
				if (backbr[6])
			    // has to be first scenario
			    pc <= backpc;
				else if (backbr[7]) begin
			    if (did_branchback)
			    	tUpdatePC();
			    else
						pc <= backpc;
				end

			8'b01000000:
				if (backbr[5])
					tUpdatePC();
			
			8'b01010000:
				if (backbr[5])
			    // has to be first scenario
			    pc <= backpc;
				else if (backbr[7]) begin
			    if (did_branchback)
			    	tUpdatePC();
			    else
						pc <= backpc;
				end

			8'b01100000:
				if (backbr[5])
			    // has to be first scenario
			    pc <= backpc;
				else if (backbr[6]) begin
			    if (did_branchback)
			    	tUpdatePC();
			    else
						pc <= backpc;
				end

			8'b01110000:
				if (backbr[5]|backbr[6])
			    pc <= backpc;
				else if (backbr[7]) begin
			    if (did_branchback)
			    	tUpdatePC();
			    else
						pc <= backpc;
				end

			8'b10000000:
				if (backbr[4])
					tUpdatePC();
			
			8'b10010000:
				if (backbr[4])
			    // has to be first scenario
			    pc <= backpc;
				else if (backbr[7]) begin
			    if (did_branchback)
			    	tUpdatePC();
			    else
						pc <= backpc;
				end

			8'b10100000:
				if (backbr[4])
			    // has to be first scenario
			    pc <= backpc;
				else if (backbr[6]) begin
			    if (did_branchback)
			    	tUpdatePC();
			    else
						pc <= backpc;
				end

			8'b10110000:
				if (backbr[4]|backbr[6])
			    pc <= backpc;
				else if (backbr[7]) begin
			    if (did_branchback)
			    	tUpdatePC();
			    else
						pc <= backpc;
				end

			8'b11000000:
				if (backbr[4])
			    // has to be first scenario
			    pc <= backpc;
				else if (backbr[5]) begin
			    if (did_branchback)
			    	tUpdatePC();
			    else
						pc <= backpc;
				end

			8'b11010000:
				if (backbr[4]|backbr[5])
			    pc <= backpc;
				else if (backbr[7]) begin
			    if (did_branchback)
			    	tUpdatePC();
			    else
						pc <= backpc;
				end

			8'b11100000:
				if (backbr[4]|backbr[5])
			    pc <= backpc;
				else if (backbr[6]) begin
			    if (did_branchback)
			    	tUpdatePC();
			    else
						pc <= backpc;
				end

			8'b11110000:
				if (backbr[4]|backbr[5]|backbr[6])
			    pc <= backpc;
				else if (backbr[7]) begin
			    if (did_branchback)
			    	tUpdatePC();
			    else
						pc <= backpc;
				end

			default	: ;	// do nothing

		  endcase

		end // if branchback

		else begin	// there is no branchback in the system
	    //
	    // get data iff the fetch buffers are empty
	    //
		  if (fetchbuf[0].v==INV && fetchbuf[1].v==INV && fetchbuf[2].v==INV && fetchbuf[3].v==INV)
		  	tUpdatePC();
		  else if (fetchbuf[4].v==INV && fetchbuf[5].v==INV && fetchbuf[6].v==INV && fetchbuf[7].v==INV)
	    	tUpdatePC();
		end
	end
end

task tUpdatePC;
begin
	if (|pc[11:0]) begin
	  if (~irq) begin
	  	if (~|next_micro_ip)
	  		pc <= pc + 16'h5000;
  		pc[11:0] <= next_micro_ip;
		end
	end
	else if (hit) begin
	  if (~irq) begin
		  pc <= next_pc;
		end
	end
end
endtask

endmodule
