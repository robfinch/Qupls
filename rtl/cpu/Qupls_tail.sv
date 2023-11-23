// ============================================================================
//        __
//   \\__/ o\    (C) 2023  Robert Finch, Waterloo
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
// ============================================================================

import const_pkg::*;
import QuplsPkg::*;

module Qupls_tail(rst, clk, branchmiss, branchmiss_state, ins0_v, ins1_v, ins2_v, ins3_v,
	pt0, pt1, pt2, pt3, robentry_stomp, rob, tail0, tail1, tail2, tail3);
input rst;
input clk;
input branchmiss;
input [2:0] branchmiss_state;
input ins0_v;
input ins1_v;
input ins2_v;
input ins3_v;
input pt0;
input pt1;
input pt2;
input pt3;
input [ROB_ENTRIES-1:0] robentry_stomp;
input rob_entry_t [ROB_ENTRIES-1:0] rob;
output rob_ndx_t tail0;
output rob_ndx_t tail1;
output rob_ndx_t tail2;
output rob_ndx_t tail3;

always_ff @(posedge clk)
if (rst) begin
	tail0 <= 'd0;
	tail1 <= 4'd1;
	tail2 <= 4'd2;
	tail3 <= 4'd3;
end
else begin
	// Reset tail pointers on a branch miss, not strictly necessary but improves
	// performance.
	if (branchmiss) begin	// if branchmiss
		if (branchmiss_state==3'd4) begin
	    if (robentry_stomp[0] & ~robentry_stomp[7]) begin
				tail0 <= 0;
				tail1 <= 1;
				tail2 <= 2;
				tail3 <= 3;
	    end
	    else if (robentry_stomp[1] & ~robentry_stomp[0]) begin
				tail0 <= 1;
				tail1 <= 2;
				tail2 <= 3;
				tail3 <= 4;
	    end
	    else if (robentry_stomp[2] & ~robentry_stomp[1]) begin
				tail0 <= 2;
				tail1 <= 3;
				tail2 <= 4;
				tail3 <= 5;
	    end
	    else if (robentry_stomp[3] & ~robentry_stomp[2]) begin
				tail0 <= 3;
				tail1 <= 4;
				tail2 <= 5;
				tail3 <= 6;
	    end
	    else if (robentry_stomp[4] & ~robentry_stomp[3]) begin
				tail0 <= 4;
				tail1 <= 5;
				tail2 <= 6;
				tail3 <= 7;
	    end
	    else if (robentry_stomp[5] & ~robentry_stomp[4]) begin
				tail0 <= 5;
				tail1 <= 6;
				tail2 <= 7;
				tail3 <= 8;
	    end
	    else if (robentry_stomp[6] & ~robentry_stomp[5]) begin
				tail0 <= 6;
				tail1 <= 7;
				tail2 <= 8;
				tail3 <= 9;
	    end
	    else if (robentry_stomp[7] & ~robentry_stomp[6]) begin
				tail0 <= 7;
				tail1 <= 8;
				tail2 <= 9;
				tail3 <= 10;
	    end
	    else if (robentry_stomp[8] & ~robentry_stomp[7]) begin
				tail0 <= 8;
				tail1 <= 9;
				tail2 <= 10;
				tail3 <= 11;
	    end
	    else if (robentry_stomp[9] & ~robentry_stomp[8]) begin
				tail0 <= 9;
				tail1 <= 10;
				tail2 <= 11;
				tail3 <= 12;
	    end
	    else if (robentry_stomp[10] & ~robentry_stomp[9]) begin
				tail0 <= 10;
				tail1 <= 11;
				tail2 <= 12;
				tail3 <= 13;
	    end
	    else if (robentry_stomp[11] & ~robentry_stomp[10]) begin
				tail0 <= 11;
				tail1 <= 12;
				tail2 <= 13;
				tail3 <= 14;
	    end
	    else if (robentry_stomp[12] & ~robentry_stomp[11]) begin
				tail0 <= 12;
				tail1 <= 13;
				tail2 <= 14;
				tail3 <= 15;
	    end
	    else if (robentry_stomp[13] & ~robentry_stomp[12]) begin
				tail0 <= 13;
				tail1 <= 14;
				tail2 <= 15;
				tail3 <= 0;
	    end
	    else if (robentry_stomp[14] & ~robentry_stomp[13]) begin
				tail0 <= 14;
				tail1 <= 15;
				tail2 <= 0;
				tail3 <= 1;
	    end
	    else if (robentry_stomp[15] & ~robentry_stomp[14]) begin
				tail0 <= 15;
				tail1 <= 0;
				tail2 <= 1;
				tail3 <= 2;
	    end
		end
	end
	else begin
		case ({ins0_v, ins1_v, ins2_v, ins3_v})
		4'b0000:	;
		4'b0001:
			if (rob[tail0].v == INV) begin
				tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
				tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
				tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
				tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
			end
		4'b0010:
			if (rob[tail0].v == INV) begin
				tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
				tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
				tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
				tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
			end
		4'b0011:
			if (rob[tail0].v == INV) begin
				if (pt2) begin
					tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
					tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
					tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
					tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
				end
				else begin
			    if (rob[tail1].v == INV) begin
						tail0 <= (tail0 + 2'd2) % ROB_ENTRIES;
						tail1 <= (tail1 + 2'd2) % ROB_ENTRIES;
						tail2 <= (tail2 + 2'd2) % ROB_ENTRIES;
						tail3 <= (tail3 + 2'd2) % ROB_ENTRIES;
			    end
			    else begin
						tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
						tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
						tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
						tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
					end				
				end
			end
		4'b0100:
			if (rob[tail0].v == INV) begin
				tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
				tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
				tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
				tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
			end
		4'b0101:
			if (rob[tail0].v == INV) begin
				if (pt1) begin
					tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
					tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
					tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
					tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
				end
				else begin
			    if (rob[tail1].v == INV) begin
						tail0 <= (tail0 + 2'd2) % ROB_ENTRIES;
						tail1 <= (tail1 + 2'd2) % ROB_ENTRIES;
						tail2 <= (tail2 + 2'd2) % ROB_ENTRIES;
						tail3 <= (tail3 + 2'd2) % ROB_ENTRIES;
			    end
			    else begin
						tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
						tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
						tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
						tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
					end				
				end
			end
		4'b0110:
			if (rob[tail0].v == INV) begin
				if (pt1) begin
					tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
					tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
					tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
					tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
				end
				else begin
			    if (rob[tail1].v == INV) begin
						tail0 <= (tail0 + 2'd2) % ROB_ENTRIES;
						tail1 <= (tail1 + 2'd2) % ROB_ENTRIES;
						tail2 <= (tail2 + 2'd2) % ROB_ENTRIES;
						tail3 <= (tail3 + 2'd2) % ROB_ENTRIES;
			    end
			    else begin
						tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
						tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
						tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
						tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
					end				
				end
			end
		4'b0111:
			if (rob[tail0].v == INV) begin
				if (pt1) begin
					tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
					tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
					tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
					tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
				end
				else begin
			    if (rob[tail1].v == INV) begin
			    	if (pt2) begin
							tail0 <= (tail0 + 2'd2) % ROB_ENTRIES;
							tail1 <= (tail1 + 2'd2) % ROB_ENTRIES;
							tail2 <= (tail2 + 2'd2) % ROB_ENTRIES;
							tail3 <= (tail3 + 2'd2) % ROB_ENTRIES;
			    	end
			    	else if (rob[tail2].v==INV) begin
							tail0 <= (tail0 + 2'd3) % ROB_ENTRIES;
							tail1 <= (tail1 + 2'd3) % ROB_ENTRIES;
							tail2 <= (tail2 + 2'd3) % ROB_ENTRIES;
							tail3 <= (tail3 + 2'd3) % ROB_ENTRIES;
						end
						else begin
							tail0 <= (tail0 + 2'd2) % ROB_ENTRIES;
							tail1 <= (tail1 + 2'd2) % ROB_ENTRIES;
							tail2 <= (tail2 + 2'd2) % ROB_ENTRIES;
							tail3 <= (tail3 + 2'd2) % ROB_ENTRIES;
						end
			    end
			    else begin
						tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
						tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
						tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
						tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
					end				
				end
			end
		4'b1000:
			if (rob[tail0].v == INV) begin
				tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
				tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
				tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
				tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
			end
		4'b1001:
			if (rob[tail0].v == INV) begin
				if (pt0) begin
					tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
					tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
					tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
					tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
				end
				else begin
			    if (rob[tail1].v == INV) begin
						tail0 <= (tail0 + 2'd2) % ROB_ENTRIES;
						tail1 <= (tail1 + 2'd2) % ROB_ENTRIES;
						tail2 <= (tail2 + 2'd2) % ROB_ENTRIES;
						tail3 <= (tail3 + 2'd2) % ROB_ENTRIES;
			    end
			    else begin
						tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
						tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
						tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
						tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
					end				
				end
			end
		4'b1010:
			if (rob[tail0].v == INV) begin
				if (pt0) begin
					tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
					tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
					tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
					tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
				end
				else begin
			    if (rob[tail1].v == INV) begin
						tail0 <= (tail0 + 2'd2) % ROB_ENTRIES;
						tail1 <= (tail1 + 2'd2) % ROB_ENTRIES;
						tail2 <= (tail2 + 2'd2) % ROB_ENTRIES;
						tail3 <= (tail3 + 2'd2) % ROB_ENTRIES;
			    end
			    else begin
						tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
						tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
						tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
						tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
					end				
				end
			end
		4'b1011:
			if (rob[tail0].v == INV) begin
				if (pt0) begin
					tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
					tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
					tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
					tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
				end
				else begin
			    if (rob[tail1].v == INV) begin
			    	if (pt2) begin
							tail0 <= (tail0 + 2'd2) % ROB_ENTRIES;
							tail1 <= (tail1 + 2'd2) % ROB_ENTRIES;
							tail2 <= (tail2 + 2'd2) % ROB_ENTRIES;
							tail3 <= (tail3 + 2'd2) % ROB_ENTRIES;
			    	end
			    	else if (rob[tail2].v==INV) begin
							tail0 <= (tail0 + 2'd3) % ROB_ENTRIES;
							tail1 <= (tail1 + 2'd3) % ROB_ENTRIES;
							tail2 <= (tail2 + 2'd3) % ROB_ENTRIES;
							tail3 <= (tail3 + 2'd3) % ROB_ENTRIES;
						end
						else begin
							tail0 <= (tail0 + 2'd2) % ROB_ENTRIES;
							tail1 <= (tail1 + 2'd2) % ROB_ENTRIES;
							tail2 <= (tail2 + 2'd2) % ROB_ENTRIES;
							tail3 <= (tail3 + 2'd2) % ROB_ENTRIES;
						end
			    end
			    else begin
						tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
						tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
						tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
						tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
					end				
				end
			end
		4'b1100:
			if (rob[tail0].v == INV) begin
				if (pt0) begin
					tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
					tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
					tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
					tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
				end
				else begin
			    if (rob[tail1].v == INV) begin
						tail0 <= (tail0 + 2'd2) % ROB_ENTRIES;
						tail1 <= (tail1 + 2'd2) % ROB_ENTRIES;
						tail2 <= (tail2 + 2'd2) % ROB_ENTRIES;
						tail3 <= (tail3 + 2'd2) % ROB_ENTRIES;
			    end
			    else begin
						tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
						tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
						tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
						tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
					end				
				end
			end
		4'b1101:
			if (rob[tail0].v == INV) begin
				if (pt0) begin
					tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
					tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
					tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
					tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
				end
				else begin
			    if (rob[tail1].v == INV) begin
			    	if (pt1) begin
							tail0 <= (tail0 + 2'd2) % ROB_ENTRIES;
							tail1 <= (tail1 + 2'd2) % ROB_ENTRIES;
							tail2 <= (tail2 + 2'd2) % ROB_ENTRIES;
							tail3 <= (tail3 + 2'd2) % ROB_ENTRIES;
			    	end
			    	else if (rob[tail2].v==INV) begin
							tail0 <= (tail0 + 2'd3) % ROB_ENTRIES;
							tail1 <= (tail1 + 2'd3) % ROB_ENTRIES;
							tail2 <= (tail2 + 2'd3) % ROB_ENTRIES;
							tail3 <= (tail3 + 2'd3) % ROB_ENTRIES;
						end
						else begin
							tail0 <= (tail0 + 2'd2) % ROB_ENTRIES;
							tail1 <= (tail1 + 2'd2) % ROB_ENTRIES;
							tail2 <= (tail2 + 2'd2) % ROB_ENTRIES;
							tail3 <= (tail3 + 2'd2) % ROB_ENTRIES;
						end
			    end
			    else begin
						tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
						tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
						tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
						tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
					end				
				end
			end
		4'b1110:
			if (rob[tail0].v == INV) begin
				if (pt0) begin
					tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
					tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
					tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
					tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
				end
				else begin
			    if (rob[tail1].v == INV) begin
			    	if (pt1) begin
							tail0 <= (tail0 + 2'd2) % ROB_ENTRIES;
							tail1 <= (tail1 + 2'd2) % ROB_ENTRIES;
							tail2 <= (tail2 + 2'd2) % ROB_ENTRIES;
							tail3 <= (tail3 + 2'd2) % ROB_ENTRIES;
			    	end
			    	else if (rob[tail2].v==INV) begin
							tail0 <= (tail0 + 2'd3) % ROB_ENTRIES;
							tail1 <= (tail1 + 2'd3) % ROB_ENTRIES;
							tail2 <= (tail2 + 2'd3) % ROB_ENTRIES;
							tail3 <= (tail3 + 2'd3) % ROB_ENTRIES;
						end
						else begin
							tail0 <= (tail0 + 2'd2) % ROB_ENTRIES;
							tail1 <= (tail1 + 2'd2) % ROB_ENTRIES;
							tail2 <= (tail2 + 2'd2) % ROB_ENTRIES;
							tail3 <= (tail3 + 2'd2) % ROB_ENTRIES;
						end
			    end
			    else begin
						tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
						tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
						tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
						tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
					end				
				end
			end
		4'b1111:
			if (rob[tail0].v == INV) begin
				if (pt0) begin
					tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
					tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
					tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
					tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
				end
				else begin
			    if (rob[tail1].v == INV) begin
			    	if (pt1) begin
							tail0 <= (tail0 + 2'd2) % ROB_ENTRIES;
							tail1 <= (tail1 + 2'd2) % ROB_ENTRIES;
							tail2 <= (tail2 + 2'd2) % ROB_ENTRIES;
							tail3 <= (tail3 + 2'd2) % ROB_ENTRIES;
			    	end
			    	else begin
			    		if (rob[tail2].v==INV) begin
			    			if (pt2) begin
									tail0 <= (tail0 + 2'd3) % ROB_ENTRIES;
									tail1 <= (tail1 + 2'd3) % ROB_ENTRIES;
									tail2 <= (tail2 + 2'd3) % ROB_ENTRIES;
									tail3 <= (tail3 + 2'd3) % ROB_ENTRIES;
			    			end
				    		else begin
									if (rob[tail2].v==INV) begin
										tail0 <= (tail0 + 3'd4) % ROB_ENTRIES;
										tail1 <= (tail1 + 3'd4) % ROB_ENTRIES;
										tail2 <= (tail2 + 3'd4) % ROB_ENTRIES;
										tail3 <= (tail3 + 3'd4) % ROB_ENTRIES;
									end
									else begin
										tail0 <= (tail0 + 2'd3) % ROB_ENTRIES;
										tail1 <= (tail1 + 2'd3) % ROB_ENTRIES;
										tail2 <= (tail2 + 2'd3) % ROB_ENTRIES;
										tail3 <= (tail3 + 2'd3) % ROB_ENTRIES;
									end
								end
							end
							else begin
								tail0 <= (tail0 + 2'd2) % ROB_ENTRIES;
								tail1 <= (tail1 + 2'd2) % ROB_ENTRIES;
								tail2 <= (tail2 + 2'd2) % ROB_ENTRIES;
								tail3 <= (tail3 + 2'd2) % ROB_ENTRIES;
							end
						end
			    end
			    else begin
						tail0 <= (tail0 + 2'd1) % ROB_ENTRIES;
						tail1 <= (tail1 + 2'd1) % ROB_ENTRIES;
						tail2 <= (tail2 + 2'd1) % ROB_ENTRIES;
						tail3 <= (tail3 + 2'd1) % ROB_ENTRIES;
					end				
				end
			end
		endcase
	end
end

endmodule
