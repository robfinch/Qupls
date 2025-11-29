// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2025  Robert Finch, Waterloo
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

import Qupls4_pkg::*;

module Qupls4_cmp(ir, om, cr, a, b, i, o);
parameter WID=64;
input Qupls4_pkg::micro_op_t ir;
input Qupls4_pkg::operating_mode_t om;
input [WID-1:0] cr;
input [WID-1:0] a;
input [WID-1:0] b;
input [WID-1:0] i;
output reg [WID-1:0] o;

reg [WID-1:0] o1;
Qupls4_pkg::condition_byte_t cb, cbi;
wire inf, nan, snan;
wire [15:0] fcmpo;
wire [WID:0] cmpi = a - i;
wire [WID:0] cmpr = a - b;

generate begin : gFCmp
	case(WID)
	16:	fpCompare16 u1 (a, b, fcmpo, inf, nan, snan);
	32:	fpCompare32 u2 (a, b, fcmpo, inf, nan, snan);
	64:	fpCompare64 u3 (a, b, fcmpo, inf, nan, snan);
	128:	fpCompare128 u4 (a, b, fcmpo, inf, nan, snan);
	endcase
end
endgenerate

always_comb
begin
	cb = 8'h00;
	case(ir.any.opcode)
	Qupls4_pkg::OP_R3B,Qupls4_pkg::OP_R3W,Qupls4_pkg::OP_R3T,Qupls4_pkg::OP_R3O,
	Qupls4_pkg::OP_R3BP,Qupls4_pkg::OP_R3WP,Qupls4_pkg::OP_R3TP,Qupls4_pkg::OP_R3OP:
		begin
			case(ir.r3.func)
			FN_CMP:
				begin
					cb.eq = a == b;
					cb.ne = a != b;
					cb.lt = $signed(a) < $signed(b);
					cb.le = $signed(a) <= $signed(b);
					cb.gt = $signed(a) > $signed(b);
					cb.ge = $signed(a) >= $signed(b);
				end
			FN_CMPU:
				begin
					cb.eq = a == b;
					cb.ne = a != b;
					cb.lt = a < b;
					cb.le = a <= b;
					cb.gt = a > b;
					cb.ge = a >= b;
				end
			default:	;
			endcase
		end
	Qupls4_pkg::OP_CMPUI:	
		begin
			cb.eq = a == i;
			cb.ne = a != i;
			cb.lt = a < i;
			cb.le = a <= i;
			cb.gt = a > i;
			cb.ge = a >= i;
		end
	Qupls4_pkg::OP_CMPI:	
		begin
			cb.eq = a == i;
			cb.ne = a != i;
			cb.lt = $signed(a) < $signed(i);
			cb.le = $signed(a) <= $signed(i);
			cb.gt = $signed(a) > $signed(i);
			cb.ge = $signed(a) >= $signed(i);
		end
		/*
			if (ir[31]) begin
				case(ir.cmpi.op2)
				2'd0:	// CMPI
					begin
						cb.eq = a == i;
						cb._nand = ~(a & i);
						cb._nor = ~(a | i);
						cb.lt = $signed(a) < $signed(i);
						cb.le = $signed(a) <= $signed(i);
						cb.ca = cmpi[WID];
						cb.so = cbi.so;
						cb.resv = cbi.resv;
					end
				2'd1:	// CMPAI
					begin
						cb.eq = a == i;
						cb._nand = ~(a & i);
						cb._nor = ~(a | i);
						cb.lt = a < i;
						cb.le = a <= i;
						cb.ca = cmpi[WID];
						cb.so = cbi.so;
						cb.resv = cbi.resv;
					end
				2'd2:	// FCMP
					begin
						cb.eq = fcmpo[0];
						cb._nand = ~(a & i);
						cb._nor = ~(a | i);
						cb.lt = fcmpo[1];
						cb.le = fcmpo[2];
						cb.ca = inf;
						if (cbi.so|nan|snan)
							cb.so = 1'b1;
						else
							cb.so = cbi.so;
						cb.resv = cbi.resv;
					end
				default:	;
				endcase			
			end
			else begin
				case(ir.cmpi.op2)
				2'd0:	// CMP
					begin
						cb.eq = a == b;
						cb._nand = ~(a & b);
						cb._nor = ~(a | b);
						cb.lt = $signed(a) < $signed(b);
						cb.le = $signed(a) <= $signed(b);
						cb.ca = cmpr[WID];
						cb.so = cbi.so;
						cb.resv = 1'b0;
					end
				2'd1:	// CMPA
					begin
						cb.eq = a == b;
						cb._nand = ~(a & b);
						cb._nor = ~(a | b);
						cb.lt = a < b;
						cb.le = a <= b;
						cb.ca = cmpr[WID];
						cb.so = cbi.so;
						cb.resv = 1'b0;
					end
				2'd2:	// FCMP
					begin
						cb.eq = fcmpo[0];
						cb._nand = ~(a & b);
						cb._nor = ~(a | b);
						cb.lt = fcmpo[1];
						cb.le = fcmpo[2];
						cb.ca = inf;
						if (cbi.so|nan|snan)
							cb.so = 1'b1;
						else
							cb.so = cbi.so;
						cb.resv = nan|snan;
					end
				endcase			
			end
		end
	*/
	default:
		cb = 8'd0;
	endcase
	o = cb;
end

endmodule
