// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	icache_req_generator.sv
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
// FOR ANY DIRECT, INDIRECT, INCHANNELENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// 212 LUTs / 348 FFs
// ============================================================================

import cpu_types_pkg::*;
import wishbone_pkg::*;
import cache_pkg::*;

module icache_req_generator(rst, clk, hit, tlb_v, miss_vadr, miss_padr,
	wbm_req, ack_i, vtags, ptags, ack);
parameter CORENO = 6'd1;
parameter CHANNEL = 6'd0;
parameter WAIT = 6'd6;
input rst;
input clk;
input hit;
input tlb_v;
input cpu_types_pkg::virtual_address_t miss_vadr;
input cpu_types_pkg::physical_address_t miss_padr;
output wb_cmd_request256_t wbm_req;
input ack_i;
output cpu_types_pkg::virtual_address_t [15:0] vtags;
output cpu_types_pkg::physical_address_t [15:0] ptags;
input ack;

typedef enum logic [3:0] {
	RESET = 0,
	WAIT4MISS,STATE2,STATE3,STATE3a,STATE4,STATE4a,STATE5,STATE5a,DELAY1,
	WAIT_ACK,WAIT_UPD1,WAIT_UPD2
} state_t;
state_t req_state;

cpu_types_pkg::address_t madr, vadr, padr;
reg [7:0] lfsr_cnt;
wire [16:0] lfsr_o;
reg [1:0] tid;

lfsr17 #(.WID(17)) ulfsr1
(
	.rst(rst),
	.clk(clk),
	.ce(req_state != RESET),
	.cyc(1'b0),
	.o(lfsr_o)
);

always_ff @(posedge clk)
if (rst) begin
	req_state <= RESET;
	wbm_req <= 'd0;
	lfsr_cnt <= 'd0;
	vtags <= 'd0;
	tid <= 4'd0;
	madr <= {$bits(wb_address_t){1'b0}};
	padr <= {$bits(wb_address_t){1'b0}};
	vadr <= {$bits(wb_address_t){1'b0}};
end
else begin
	case(req_state)
	RESET:
		begin
			wbm_req.cmd <= wishbone_pkg::CMD_ICACHE_LOAD;
			wbm_req.sz  <= wishbone_pkg::dhexi;
			wbm_req.blen <= 8'd0;
//			wbm_req.cid <= 3'd7;					// CPU channel id
			wbm_req.tid <= 13'd0;
			wbm_req.csr  <= 1'd0;					// clear/set reservation
			wbm_req.pl	<= 8'd0;						// privilege level
			wbm_req.pri	<= 4'h7;					// average priority (higher is better).
			wbm_req.cache <= wishbone_pkg::CACHEABLE;
			wbm_req.seg <= wishbone_pkg::CODE;
			wbm_req.bte <= wishbone_pkg::LINEAR;
			wbm_req.cti <= wishbone_pkg::CLASSIC;
			wbm_req.cyc <= 1'b0;
			wbm_req.sel <= 32'h00000000;
			wbm_req.we <= 1'b0;
			if (lfsr_cnt=={CHANNEL,2'b0})
				req_state <= WAIT4MISS;
			lfsr_cnt <= lfsr_cnt + 2'd1;
			tid <= 4'h0;
		end
	WAIT4MISS:
		if (!hit & tlb_v) begin
			wbm_req.tid.core = CORENO;
			wbm_req.tid.channel = CHANNEL;			
			wbm_req.tid.tranid <= {tid,2'd0};
			wbm_req.blen <= 6'd1;
			wbm_req.cti <= wishbone_pkg::FIXED;
			wbm_req.cyc <= 1'b1;
			wbm_req.sel <= 32'hFFFFFFFF;
			wbm_req.we <= 1'b0;
//			wbm_req.vadr <= {miss_vadr[$bits(fta_address_t)-1:cache_pkg::ICacheTagLoBit],{cache_pkg::ICacheTagLoBit{1'h0}}};
      wbm_req.pv <= 1'b0;
			wbm_req.adr <= {miss_padr[$bits(cpu_types_pkg::physical_address_t)-1:cache_pkg::ICacheTagLoBit],{cache_pkg::ICacheTagLoBit{1'h0}}};
			vtags[{tid,2'd0}] <= {miss_vadr[$bits(cpu_types_pkg::virtual_address_t)-1:cache_pkg::ICacheTagLoBit],{cache_pkg::ICacheTagLoBit{1'h0}}};
			ptags[{tid,2'd0}] <= {miss_padr[$bits(cpu_types_pkg::physical_address_t)-1:cache_pkg::ICacheTagLoBit],{cache_pkg::ICacheTagLoBit{1'h0}}};
			vadr <= {miss_vadr[$bits(wb_address_t)-1:cache_pkg::ICacheTagLoBit],{cache_pkg::ICacheTagLoBit{1'h0}}};
			padr <= {miss_padr[$bits(wb_address_t)-1:cache_pkg::ICacheTagLoBit],{cache_pkg::ICacheTagLoBit{1'h0}}};
			madr <= {miss_vadr[$bits(wb_address_t)-1:cache_pkg::ICacheTagLoBit],{cache_pkg::ICacheTagLoBit{1'h0}}};
			req_state <= STATE3;
		end
	STATE3:
		if (ack_i) begin
			wbm_req.cyc <= 1'b0;
			req_state <= STATE3a;
		end
	STATE3a:
		begin
			wbm_req.tid.tranid <= {tid,2'd1};
			wbm_req.cyc <= 1'b1;
//			wbm_req.vadr <= vadr + 6'd32;
			wbm_req.adr <= padr + 6'd32;
			vtags[{tid,2'd1}] <= madr + 6'd32;
			vadr <= vadr + 6'd32;
			padr <= padr + 6'd32;
			madr <= madr + 6'd32;
			req_state <= WAIT_ACK;
//				req_state <= STATE4;
		end
	/*
	STATE4:
		begin
			wbm_req.cyc <= 1'b0;
			req_state <= STATE4a;
		end
	STATE4a:
		begin
			wbm_req.tid.core = CORENO;
			wbm_req.tid.channel = CHANNEL;			
			wbm_req.tid.tranid <= {tid,2'd2};
			wbm_req.cti <= fta_bus_pkg::FIXED;
			wbm_req.cyc <= 1'b1;
			wbm_req.stb <= 1'b1;
			wbm_req.sel <= 32'hFFFFFFFF;
			wbm_req.vadr <= vadr + 5'd32;
			wbm_req.padr <= padr + 5'd32;
			vtags[{tid,2'd2}] <= madr + 5'd32;
			if (!full) begin
				vadr <= vadr + 5'd16;
				padr <= padr + 5'd16;
				madr <= madr + 5'd16;
				req_state <= STATE5;
			end
		end
	STATE5:
		begin
			wbm_req.cyc <= 1'b0;
			req_state <= STATE5a;
		end
	STATE5a:
		begin
			wbm_req.tid.core = CORENO;
			wbm_req.tid.channel = CHANNEL;			
			wbm_req.tid.tranid <= {tid,2'd3};
			wbm_req.cti <= fta_bus_pkg::EOB;
			wbm_req.cyc <= 1'b1;
			wbm_req.stb <= 1'b1;
			wbm_req.sel <= 16'hFFFF;
			wbm_req.vadr <= vadr + 5'd16;
			wbm_req.padr <= padr + 5'd16;
			vtags[{tid,2'd3}] <= madr + 5'd16;
			if (!full) begin
				wait_cnt <= 'd0;
				vadr <= vadr + 5'd16;
				padr <= padr + 5'd16;
				madr <= madr + 5'd16;
				req_state <= WAIT_ACK;
			end
		end
	*/
	DELAY1:
		begin
			tBusClear();
			req_state <= WAIT4MISS;
		end
	// Wait some random number of clocks before trying again.
	WAIT_ACK:
		if (ack_i) begin
			tBusClear();
			req_state <= WAIT_UPD1;
		end
	WAIT_UPD1:
		req_state <= WAIT_UPD2;
	WAIT_UPD2:
		begin
			tid <= tid + 2'd1;
			if (&tid)
				tid <= 2'd1;
			req_state <= WAIT4MISS;
		end
	default:
		req_state <= RESET;
	endcase
end

task tBusClear;
begin
	wbm_req.cti <= wishbone_pkg::CLASSIC;
	wbm_req.cyc <= 1'b0;
	wbm_req.sel <= 32'h00000000;
	wbm_req.we <= 1'b0;
end
endtask

endmodule
