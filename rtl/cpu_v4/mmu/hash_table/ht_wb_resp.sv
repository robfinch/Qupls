`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2026  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
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
//
import const_pkg::*;
import wishbone_pkg::*;
import hash_table_pkg::*;

module ht_wb_resp(bus, state, douta, cs, asid, max_bounce,
	fault_adr, fault_asid, fault_group, fault_valid, vb);
parameter WID=32;
parameter TAB_SIZE=8192;
wb_bus_interface.slave bus;
input [1:0] state;
input htg_t douta;
input cs;
input [9:0] asid;
input [7:0] max_bounce;
input [31:0] fault_adr;
input [7:0] fault_asid;
input [9:0] fault_group;
input [7:0] fault_valid;
input [WID-1:0] vb [0:TAB_SIZE/WID-1];

always_ff @(posedge bus.clk)
if (bus.rst)
	bus.resp <= {$bits(wb_cmd_response64_t){1'b0}};
else begin
	case(state)
	2'd0:	;
	2'd1:
		begin
			bus.resp.tid <= bus.req.tid;
			bus.resp.pri <= bus.req.pri;
			bus.resp.dat <= 64'd0;
			bus.resp.ack <= TRUE;
			bus.resp.err <= wishbone_pkg::OKAY;
		end
	2'd2:
		begin
			bus.resp.tid <= bus.req.tid;
			bus.resp.pri <= bus.req.pri;
			casez(bus.req.adr[16:0])
			17'b0?????????????000:	bus.resp.dat <= douta.hte[bus.req.adr[5:3]][31: 0];
			17'b0?????????????100:	bus.resp.dat <= douta.hte[bus.req.adr[5:3]][63:32];
			17'b1000000????????00:	bus.resp.dat <= vb[bus.req.adr[9:2]];
			17'b10000010000000000:	bus.resp.dat <= fault_adr;
			17'b10000010000000100:	bus.resp.dat <= fault_asid;
			17'b10000_0100_0000_1000:	bus.resp.dat <= {fault_group,fault_valid};
			17'b10000010000001100:	bus.resp.dat <= asid;
			17'b10000010000010000:	bus.resp.dat <= max_bounce;
			default:	;
			endcase
			bus.resp.ack <= TRUE;
			bus.resp.err <= wishbone_pkg::OKAY;
		end
	2'd3:
		if (~(cs & bus.req.cyc & bus.req.stb))
			bus.resp <= {$bits(wb_cmd_response64_t){1'b0}};
	endcase
end

endmodule
