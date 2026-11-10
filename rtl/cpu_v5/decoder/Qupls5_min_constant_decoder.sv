// 380 LUTs

import const_pkg::*;
import Qupls5_pkg::*;

// Figures out where constants begin on the cache line based on the sequence
// of instructions beginning with the first on the cache line. A value of
// 63 means there were no constants on the cache line. Constants are placed
// starting at the of the cache line and working backwards.

module Qupls5_min_constant_decoder(ip, cline_aligned, nops, ip_inc);
parameter MWIDTH = 4;
input cpu_types_pkg::pc_address_t ip;
input [1023:0] cline_aligned;	// cache line in terms of instructions
output reg [9:0] nops;
output reg [6:0] ip_inc;

genvar g;
integer n1;
reg [2:0] ms;
reg [2:0] m;
reg [5:0] max;
reg [6:0] sz;
reg [47:0] inst [0:9];

generate begin : gInst
	for (g = 0; g < 10; g = g + 1)
	   always_comb
		inst[g] = cline_aligned[g*48+47:g*48];
end
endgenerate

function fnMax;
input [6:0] a;
input [6:0] b;
begin
	if (a > b)
		fnMax = 0;
	else
		fnMax = 1;
end
endfunction

function [2:0] fnMs;
input [47:0] inst;
begin
	case(Qupls5_pkg::opcode_e'(inst[6:0]))
	Qupls5_pkg::OP_R3B,Qupls5_pkg::OP_R3W,Qupls5_pkg::OP_R3T,Qupls5_pkg::OP_R3O,
	Qupls5_pkg::OP_R3BP,Qupls5_pkg::OP_R3WP,Qupls5_pkg::OP_R3TP,Qupls5_pkg::OP_R3OP,
	Qupls5_pkg::OP_R3P,
	Qupls5_pkg::OP_FLTH,Qupls5_pkg::OP_FLTS,Qupls5_pkg::OP_FLTD,Qupls5_pkg::OP_FLTQ,
	Qupls5_pkg::OP_FLTPH,Qupls5_pkg::OP_FLTPS,Qupls5_pkg::OP_FLTPD,Qupls5_pkg::OP_FLTPQ,
	Qupls5_pkg::OP_FLTP:
		fnMs = inst[40:38];
	Qupls5_pkg::OP_LDB,Qupls5_pkg::OP_LDBZ,Qupls5_pkg::OP_LDW,Qupls5_pkg::OP_LDWZ,
	Qupls5_pkg::OP_LDT,Qupls5_pkg::OP_LDTZ,Qupls5_pkg::OP_LOAD,
	Qupls5_pkg::OP_STB,Qupls5_pkg::OP_STW,Qupls5_pkg::OP_STT,Qupls5_pkg::OP_STORE:
		fnMs = {inst[44],2'b00};
	Qupls5_pkg::OP_BCC8,Qupls5_pkg::OP_BCC16,Qupls5_pkg::OP_BCC32,Qupls5_pkg::OP_BCC64,
	Qupls5_pkg::OP_BCCU8,Qupls5_pkg::OP_BCCU16,Qupls5_pkg::OP_BCCU32,Qupls5_pkg::OP_BCCU64:
		fnMs = {1'b0,inst[12:11]};
	default:
		fnMs = 3'd0;
	endcase
end
endfunction

function [2:0] fnM;
input [47:0] inst;
begin
	case(Qupls5_pkg::opcode_e'(inst[6:0]))
	Qupls5_pkg::OP_R3B,Qupls5_pkg::OP_R3W,Qupls5_pkg::OP_R3T,Qupls5_pkg::OP_R3O,
	Qupls5_pkg::OP_R3BP,Qupls5_pkg::OP_R3WP,Qupls5_pkg::OP_R3TP,Qupls5_pkg::OP_R3OP,
	Qupls5_pkg::OP_R3P,
	Qupls5_pkg::OP_FLTH,Qupls5_pkg::OP_FLTS,Qupls5_pkg::OP_FLTD,Qupls5_pkg::OP_FLTQ,
	Qupls5_pkg::OP_FLTPH,Qupls5_pkg::OP_FLTPS,Qupls5_pkg::OP_FLTPD,Qupls5_pkg::OP_FLTPQ,
	Qupls5_pkg::OP_FLTP:
		fnM = inst[34:32];
	Qupls5_pkg::OP_LDB,Qupls5_pkg::OP_LDBZ,Qupls5_pkg::OP_LDW,Qupls5_pkg::OP_LDWZ,
	Qupls5_pkg::OP_LDT,Qupls5_pkg::OP_LDTZ,Qupls5_pkg::OP_LOAD,
	Qupls5_pkg::OP_STB,Qupls5_pkg::OP_STW,Qupls5_pkg::OP_STT,Qupls5_pkg::OP_STORE:
		fnM = {1'b1,2'b00};
	Qupls5_pkg::OP_BCC8,Qupls5_pkg::OP_BCC16,Qupls5_pkg::OP_BCC32,Qupls5_pkg::OP_BCC64,
	Qupls5_pkg::OP_BCCU8,Qupls5_pkg::OP_BCCU16,Qupls5_pkg::OP_BCCU32,Qupls5_pkg::OP_BCCU64:
		fnM = {1'b0,inst[47:46]};
	default:
		fnM = 3'd0;
	endcase
end
endfunction

function [3:0] fnSz;
input [1:0] sz;
begin
	case(sz)
	2'd0:	fnSz = 4'd2;
	2'd1:	fnSz = 4'd4;
	2'd2:	fnSz = 4'd6;
	2'd3:	fnSz = 4'd8;
	endcase
end
endfunction

always_comb
begin
	nops = 10'h000;
	for (n1 = 0; n1 < MWIDTH; n1 = n1 + 1) begin
		if (!nops[n1]) begin
			ms = fnMs(inst[n1]);
			m = fnM(inst[n1]);
			max = {2'b00,inst[n1][10: 7],1'b0} + 6'd6;
			sz = 0;
			if (|ms) begin
				if (ms[0] & m[0])
					sz = sz + fnSz(inst[n1][12:11]);
				if (ms[1] & m[1]) begin
					if (fnMax(max,{2'b00,inst[n1][16:13],1'b0}+6'd6)) begin
						max = {2'b00,inst[n1][16:13],1'b0}+6'd6;
						sz = sz + fnSz(inst[n1][18:17]);
					end
				end
				if (ms[2] & m[2]) begin
					if (fnMax(max,{2'b00,inst[n1][22:19],1'b0}+6'd6)) begin
						max = {2'b00,inst[n1][22:19],1'b0}+6'd6;
						sz = sz + fnSz(inst[n1][24:23]);
					end
				end
				case(1'b1)
				sz > 7'd23:	begin nops[n1+1] = TRUE; nops[n1+2] = TRUE; nops[n1+3] = TRUE; nops[n1+4] = TRUE; end
				sz > 7'd17:	begin nops[n1+1] = TRUE; nops[n1+2] = TRUE; nops[n1+3] = TRUE; end
				sz > 7'd11:	begin nops[n1+1] = TRUE; nops[n1+2] = TRUE; end
				sz > 7'd5:	begin nops[n1+1] = TRUE; end
				endcase
			end
		end
	end

	// Figure out the IP increment
	casez(nops[7:0])
	8'b1111????:	ip_inc = 7'd48;
	8'b0111????:	ip_inc = 7'd42;
	8'b0011????:	ip_inc = 7'd36;
	8'b0001????:	ip_inc = 7'd30;
	8'b00001???:	ip_inc = 7'd24;
	8'b000001??:	ip_inc = MWIDTH<=3 ? 7'd18 : 7'd24;
	8'b0000001?:	ip_inc = MWIDTH<=2 ? 7'd12 : MWIDTH==3 ? 7'd18 : 7'd24;
	8'b0000000?:	ip_inc = MWIDTH==1 ? 7'd6 : MWIDTH==2 ? 7'd12 : MWIDTH==3 ? 7'd18 : 7'd24;
	default:	ip_inc = 7'd6;
	endcase
end

endmodule
