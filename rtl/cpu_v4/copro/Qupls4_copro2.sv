`timescale 1ns / 1ps
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
//    contributors may be used to endorse or pnext_irte products derived from
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
// 7250 LUTs / 10500 FFs / 8 BRAMs / 170 MHz	(default synth)
// 6850 LUTs / 10500 FFs / 8 BRAMs / 145 MHz	(area synth)
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import wishbone_pkg::*;
import mmu_pkg::*;
import Qupls4_copro_pkg::*;

`define ABITS	$bits(address_t)-1:0
`define A		15
`define R		14:10
`define G		9:5
`define B		4:0

`define CMDDAT  31:0

module Qupls4_copro2(rst, clk, sbus, mbus, cs_copro, miss, miss_adr, miss_asid,
  missack, paging_en, page_fault, iv_count, missack, idle,
  vclk, hsync_i, vsync_i, blank_i, border_i, gfx_que_empty_i,
  aud0_out, aud1_out, aud2_out, aud3_out, aud_in,
  vid_out, de,
  flush_en, flush_trig, flush_asid, flush_done, cmd_done);
parameter UNALIGNED_CONSTANTS = 0;
parameter JUMP_INDIRECT = 0;
parameter NUM_PAGESIZES = 1;
parameter LOG_PAGESIZE = 13;	// log2 of size of page
parameter LOG_TLB_ENTRIES = 9;
parameter BUSTO = 8'd9;
parameter NSPR = 32;
parameter CMD_FIFO_DEPTH = 1024;
parameter phTotal = 1056;
input rst;
input clk;
wb_bus_interface.slave sbus;
wb_bus_interface.master mbus;
input cs_copro;
input [2:0] miss;
input address_t [2:0] miss_adr;
input asid_t [2:0] miss_asid;
output reg missack;
output reg idle;
output reg paging_en;
output reg page_fault;
output reg flush_en;
output asid_t flush_asid;
output reg flush_trig;
input flush_done;
output reg cmd_done;
input [3:0] iv_count [0:2];
input vclk;
input hsync_i;
input vsync_i;
input blank_i;
input border_i;
input gfx_que_empty_i;
output reg [15:0] aud0_out;
output reg [15:0] aud1_out;
output reg [15:0] aud2_out;
output reg [15:0] aud3_out;
input [15:0] aud_in;
output reg [23:0] vid_out;
output reg de;

integer n,n1,n2,n3,n4,n5,n6,n7,n8;
// The bus timeout depends on the clock frequency (clk) of the core
// relative to the memory controller's clock frequency (100MHz). So it's
// been made a core parameter.
reg [7:0] busto = BUSTO;
reg [7:0] tocnt;

reg [`ABITS] TargetBase = 32'h00100000;
reg [15:0] TargetWidth = 16'd400;
reg [15:0] TargetHeight = 16'd300;
reg [23:0] offset;

reg [31:0] ctrl = 32'd0;
reg [15:0] alpha;
reg [31:0] pen_color;
reg [31:0] fill_color;
reg [31:0] missColor = 43'h007c0000;	// med red
reg clipEnable;
reg [15:0] clipX0, clipY0, clipX1, clipY1;
reg zbuf;
reg [3:0] zlayer;

copro_state_t pushstate;
reg [11:0] retsp;
reg [11:0] pointsp;
copro_state_t retstack [0:4095];
reg [31:0] pointstack [0:4095];
copro_state_t retstacko;

reg [5:0] flashcnt;

reg [3:0] htask;
reg [1:0] lowres = 2'b01;
reg [23:0] borderColor = 24'h000000;
reg [23:0] rgb;
wire [23:0] rgb_i;
reg lrst;						// line reset

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

wire [15:0] pixel_i = (mbus.resp.dat >> {mbus.req.adr[2:1],4'b0});

reg [31:0] pointToPush;
reg rstst, pushst, popst;
reg rstpt, pushpt, poppt;

function [15:0] fixToInt;
input [31:0] nn;
	fixToInt = nn[31:16];
endfunction

function [20:0] blend1;
input [4:0] comp;
input [15:0] alpha;
	blend1 = comp * alpha;
endfunction

function [15:0] blend;
input [15:0] color1;
input [15:0] color2;
input [15:0] alpha;
reg [20:0] blendR;
reg [20:0] blendG;
reg [20:0] blendB;
begin
	blendR = blend1(color1[`R],alpha) + blend1(color2[`R],(16'hFFFF-alpha));
	blendG = blend1(color1[`G],alpha) + blend1(color2[`G],(16'hFFFF-alpha));
	blendB = blend1(color1[`B],alpha) + blend1(color2[`B],(16'hFFFF-alpha));
	blend = {blendR[20:16],blendG[20:16],blendB[20:16]};
end
endfunction

function IsBinaryROP;
input [3:0] rop;
IsBinaryROP =  (((rop != 4'h1) &&
			(rop != 4'h0) &&
			(rop != 4'hF)));
endfunction

copro_state_t state, ngs = st_ifetch;
copro_state_t [3:0] state_stack;

copro_instruction_t ir,ir2,next_ir;
wb_cmd_response64_t imresp;
reg rdy1, rdy2, rdy3, rdy4;
reg csc;
reg [7:0] sel;
reg we;
reg [63:0] dat,dato;
address_t adr;

reg cs;
reg mcs,gr_cmdq_cs;
reg [63:0] idat;
always_comb
	mcs = mbus.req.cyc && mbus.req.stb && (
		mbus.req.adr[31:20]==12'h000 ||
		mbus.req.adr[31:20]==12'h001 ||
		mbus.req.adr[31:16]==16'hFE00
	);
always_comb
	gr_cmdq_cs = cs && adr[31:0]==32'hFE000DC0;

delay2 udly3 (.clk(clk), .ce(1'b1), .i(mcs), .o(mdly2));

always_comb
begin
	if (!mcs) begin
		imresp.ack = mbus.resp.ack;
		imresp.dat = mbus.resp.dat;
		imresp.tid = mbus.resp.tid;
	end
	else begin
		imresp.ack = mdly2 & mcs;
		imresp.tid = mbus.req.tid;
		imresp.dat = idat;
	end
end

wire [30:0] lfsro;
lfsr31 #(.WID(31)) ulfsr1(rst, vclk, 1'b1, 1'b0, lfsro);

// register file
reg [63:0] r1=0,r2=0,r3=0,r4=0,r5=0,r6=0,r7=0;
reg [63:0] r8=0,r9=0,r10=0,r11=0,r12=0,r13=0,r14=0,r15=0,tmp=0;
// Operands
reg [63:0] imm;
reg [63:0] a,b;
reg [63:0] res;
wire [19:2] next_ip;
reg [19:2] ip,ipr;					// instruction pointer
reg ip2;
(* ram_style="distributed" *)
reg [512+17:0] stack [0:15];
reg [3:0] sp;
reg [31:0] roma;
reg local_sel;// = (state==st_mem_load|state==st_mem_store) & roma[31:16]==16'h0000;
wire rsta = rst;
wire clka = clk;

wire rstb = sbus.rst;
wire clkb = sbus.clk;
wire rsta2 = rst;
wire rstb2 = sbus.rst;
wire clka2 = clk;
wire clkb2 = sbus.clk;
wire ena = 1'b1;
wire ena2 = 1'b1;
wire enb = sbus.req.cyc && sbus.req.stb && cs_copro && sbus.req.adr[31:20]==12'hD00;
wire wea = 1'b0;//mbus.req.cyc && mbus.req.stb && mbus.req.we && mbus.req.adr[31:20]==12'h000;
wire wea2 = mbus.req.we && mbus.req.adr[31:16]==16'hFE00;
wire web = sbus.req.we && cs_copro && sbus.req.adr[31:20]==12'hD00;
wire web2 = sbus.req.we && cs_copro && sbus.req.adr[31:16]==16'hFE00;
wire [16:0] addra = local_sel ? mbus.req.adr[19:3] : ip[19:3];
wire [9:0] addra2 = mbus.req.adr[12:3];
wire [16:0] addrb = sbus.req.adr[19:3];
wire [9:0] addrb2 = sbus.req.adr[12:3];
wire [63:0] dina = mbus.req.dat;
wire [63:0] dina2 = mbus.req.dat;
wire [63:0] dinb = sbus.req.dat;
wire [63:0] dinb2 = sbus.req.dat;
wire [63:0] douta;
wire [63:0] doutb;
wire [63:0] douta2;
wire [63:0] doutb2;

reg vid_por;
wire [5:0] frame;
always_ff @(posedge clk)
if (rst)
	vid_por <= TRUE;
else begin
	if (frame > 6'd30)
		vid_por <= FALSE;
end

wire vid_rsta = rst;
wire vid_clka = clk;
wire vid_rstb = rst;
wire vid_clkb = vclk;

wire vid_ena = mbus.req.cyc && mbus.req.stb && mbus.req.adr[31:20]==12'h001;
wire [7:0] vid_wea = {8{mbus.req.we}} & mbus.req.sel;
wire [16:0] vid_addra = mbus.req.adr[19:3];
wire [63:0] vid_dina = mbus.req.dat;
wire [63:0] vid_douta;

wire vid_enb = 1'b1;
wire [1:0] vid_web = 2'b00;//{2{vid_por}};
reg [18:0] vid_addrb;
wire [15:0] vid_dinb = lfsro[15:0];
wire [15:0] vid_doutb;

reg [63:0] mem_val;
always_comb
	next_ir = ip2 ? douta[63:32] : douta[31:0];
reg sleep;
reg rfwr;
wire dly2;
wire takb;

address_t ma;
reg [63:0] latched_data;
reg [31:0] irq_status;

reg [31:0] entry_no;
reg [63:0] cmd,stat;
tlb_entry_t tlbe,tlbe2;
ptattr_t [2:0] ptattr;
address_t [2:0] ptbr;
reg clear_page_fault;
reg [2:0] miss1;
address_t [2:0] miss_adr1;
asid_t [2:0] miss_asid1;
reg [3:0] flush_trig1;
reg [63:0] arg_dat;
reg wait_active;
reg [3:0] wait_cond;
wire [31:0] icnt;			// count with one decimal point
reg [31:0] icnta;			// How much to increment by
wire [31:0] tick;			// running count of clocks since reset

// -----------------------------------------------------------------------------
// Audio Variables
// -----------------------------------------------------------------------------
//     i3210   31 i3210
// -t- rrrrr p mm eeeee
//  |    |   |  |   +--- channel enables
//  |    |   |  +------- mix channels 1 into 0, 3 into 2
//  |    |   +---------- input plot mode
//  |    +-------------- chennel reset
//  +------------------- test mode
//
// The channel needs to be reset for use as this loads the working address
// register with the audio sample base address.
//
reg [31:0] aud_ctrl;
wire aud_mix1 = aud_ctrl[5];
wire aud_mix3 = aud_ctrl[6];
//
//           3210 3210
// ---- ---- -fff -aaa
//             |    +--- amplitude modulate next channel
//             +-------- frequency modulate next channel
//
address_t aud0_adr;
address_t aud0_eadr;
reg [15:0] aud0_length;
reg [19:0] aud0_period;
reg [15:0] aud0_volume;
reg signed [15:0] aud0_dat;
reg signed [15:0] aud0_dat2;		// double buffering
address_t aud1_adr;
address_t aud1_eadr;
reg [15:0] aud1_length;
reg [19:0] aud1_period;
reg [15:0] aud1_volume;
reg signed [15:0] aud1_dat;
reg signed [15:0] aud1_dat2;
address_t aud2_adr;
address_t aud2_eadr;
reg [15:0] aud2_length;
reg [19:0] aud2_period;
reg [15:0] aud2_volume;
reg signed [15:0] aud2_dat;
reg signed [15:0] aud2_dat2;
address_t aud3_adr;
address_t aud3_eadr;
reg [15:0] aud3_length;
reg [19:0] aud3_period;
reg [15:0] aud3_volume;
reg signed [15:0] aud3_dat;
reg signed [15:0] aud3_dat2;
address_t audi_adr;
address_t audi_eadr;
reg [19:0] audi_length;
reg [19:0] audi_period;
reg [15:0] audi_volume;
reg signed [15:0] audi_dat;
reg wr_aud0;
reg wr_aud1;
reg wr_aud2;
reg wr_aud3;
reg rd_aud0;
reg rd_aud1;
reg rd_aud2;
reg rd_aud3;
wire aud0_fifo_empty;
wire aud1_fifo_empty;
wire aud2_fifo_empty;
wire aud3_fifo_empty;

wire [15:0] aud0_fifo_o;
wire [15:0] aud1_fifo_o;
wire [15:0] aud2_fifo_o;
wire [15:0] aud3_fifo_o;

reg [23:0] aud_test;
address_t aud0_wadr, aud1_wadr, aud2_wadr, aud3_wadr, audi_wadr;
reg [19:0] ch0_cnt, ch1_cnt, ch2_cnt, ch3_cnt, chi_cnt;
// The request counter keeps track of the number of times a request was issued
// without being serviced. There may be the occasional request missed by the
// timing budget. The counter allows the sample to remain on-track and in
// sync with other samples being read.
reg [5:0] aud0_req, aud1_req, aud2_req, aud3_req, audi_req;
// The following request signals pulse for 1 clock cycle only.
reg aud0_req2, aud1_req2, aud2_req2, aud3_req2, audi_req2;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Command queue vars.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
reg [5:0] cmdq_ndx;
reg [63:0] cmdq_in;
wire [63:0] cmdq_out;
wire cmdp;				// command pulse
wire cmdpe;				// command pulse edge
reg rst_cmdq;
wire [9:0] cmdq_cnt;
wire cmdq_empty = cmdq_cnt==10'd0;
wire cmdq_wr_ack = rdy1;
//wire cs = cs_i & sbus.req.cyc & sbus.req.stb;
//wire cs_cmdq = cs && sbus.req.adr[11:3]==9'b1101_1101_0 && sbus.req.we;
wire wr_cmd_fifo = gr_cmdq_cs && we && !cmdq_wr_ack;

reg rd_cmd_fifo = 1'b0;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Text Blitting
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
address_t font_tbl_adr;
reg [15:0] font_id;
address_t glyph_tbl_adr;
reg font_fixed;
reg [5:0] font_width;
reg [5:0] font_height;
reg tblit_active;
copro_state_t tblit_state;
address_t tblit_adr;
address_t tgtaddr, tgtadr;
reg [23:0] tgtindex;
reg [15:0] charcode;
reg [31:0] charndx;
reg [63:0] charbmp;
reg [63:0] charbmpr;
address_t charBmpBase;
reg [5:0] pixhc, pixvc;
reg [31:0] charBoxX0, charBoxY0;
copro_instruction_t tblit_ir, hsync_ir;
address_t tblit_ip, hsync_ip;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Drawing
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

reg [15:0] gcx,gcy;

// Untransformed points
reg [31:0] up0x, up0y, up0z;
reg [31:0] up1x, up1y, up1z;
reg [31:0] up2x, up2y, up2z;
reg [31:0] up0xs, up0ys, up0zs;
reg [31:0] up1xs, up1ys, up1zs;
reg [31:0] up2xs, up2ys, up2zs;
// Points after transform
reg [31:0] p0x, p0y, p0z;
reg [31:0] p1x, p1y, p1z;
reg [31:0] p2x, p2y, p2z;

wire signed [31:0] absx1mx0 = (p1x < p0x) ? p0x-p1x : p1x-p0x;
wire signed [31:0] absy1my0 = (p1y < p0y) ? p0y-p1y : p1y-p0y;
reg [4:0] loopcnt;

// Triangle draw
reg fbt;	// flat bottom=1 or top=0 triangle
reg [7:0] trimd;	// timer for mult
reg [31:0] v0x, v0y, v1x, v1y, v2x, v2y, v3x, v3y;
reg [31:0] w0x, w0y, w1x, w1y, w2x, w2y;
reg signed [31:0] invslope0, invslope1;
reg [31:0] curx0, curx1, cdx, endx;
reg [31:0] minY, minX, maxY, maxX;
reg div_ld;

// Bezier Curves
reg [1:0] fillCurve;
reg [31:0] bv0x, bv0y, bv1x, bv1y, bv2x, bv2y;
reg [31:0] bezierT, bezier1mT, bezierInc = 32'h0010;
reg [63:0] bezier1mTP0xw, bezier1mTP1xw;
reg [63:0] bezier1mTP0yw, bezier1mTP1yw;
reg [63:0] bezierTP1x, bezierTP2x;
reg [63:0] bezierTP1y, bezierTP2y;
reg [31:0] bezierP0plusP1x, bezierP1plusP2x;
reg [31:0] bezierP0plusP1y, bezierP1plusP2y;
reg [63:0] bezierBxw, bezierByw;

// Point Transform
reg transform, otransform;
reg [31:0] aa, ab, ac, at;
reg [31:0] ba, bb, bc, bt;
reg [31:0] ca, cb, cc, ct;
wire signed [63:0] aax0 = aa * up0x;
wire signed [63:0] aby0 = ab * up0y;
wire signed [63:0] acz0 = ac * up0z;
wire signed [63:0] bax0 = ba * up0x;
wire signed [63:0] bby0 = bb * up0y;
wire signed [63:0] bcz0 = bc * up0z;
wire signed [63:0] cax0 = ca * up0x;
wire signed [63:0] cby0 = cb * up0y;
wire signed [63:0] ccz0 = cc * up0z;
wire signed [63:0] aax1 = aa * up1x;
wire signed [63:0] aby1 = ab * up1y;
wire signed [63:0] acz1 = ac * up1z;
wire signed [63:0] bax1 = ba * up1x;
wire signed [63:0] bby1 = bb * up1y;
wire signed [63:0] bcz1 = bc * up1z;
wire signed [63:0] cax1 = ca * up1x;
wire signed [63:0] cby1 = cb * up1y;
wire signed [63:0] ccz1 = cc * up1z;
wire signed [63:0] aax2 = aa * up2x;
wire signed [63:0] aby2 = ab * up2y;
wire signed [63:0] acz2 = ac * up2z;
wire signed [63:0] bax2 = ba * up2x;
wire signed [63:0] bby2 = bb * up2y;
wire signed [63:0] bcz2 = bc * up2z;
wire signed [63:0] cax2 = ca * up2x;
wire signed [63:0] cby2 = cb * up2y;
wire signed [63:0] ccz2 = cc * up2z;

wire signed [63:0] x0_prime = aax0 + aby0 + acz0 + {at,16'h0000};
wire signed [63:0] y0_prime = bax0 + bby0 + bcz0 + {bt,16'h0000};
wire signed [63:0] z0_prime = cax0 + cby0 + ccz0 + {ct,16'h0000};
wire signed [63:0] x1_prime = aax1 + aby1 + acz1 + {at,16'h0000};
wire signed [63:0] y1_prime = bax1 + bby1 + bcz1 + {bt,16'h0000};
wire signed [63:0] z1_prime = cax1 + cby1 + ccz1 + {ct,16'h0000};
wire signed [63:0] x2_prime = aax2 + aby2 + acz2 + {at,16'h0000};
wire signed [63:0] y2_prime = bax2 + bby2 + bcz2 + {bt,16'h0000};
wire signed [63:0] z2_prime = cax2 + cby2 + ccz2 + {ct,16'h0000};

always_ff @(posedge clk)
	p0x <= transform ? x0_prime[47:16] : up0x;
always_ff @(posedge clk)
	p0y <= transform ? y0_prime[47:16] : up0y;
always_ff @(posedge clk)
	p0z <= transform ? z0_prime[47:16] : up0z;
always_ff @(posedge clk)
	p1x <= transform ? x1_prime[47:16] : up1x;
always_ff @(posedge clk)
	p1y <= transform ? y1_prime[47:16] : up1y;
always_ff @(posedge clk)
	p1z <= transform ? z1_prime[47:16] : up1z;
always_ff @(posedge clk)
	p2x <= transform ? x2_prime[47:16] : up2x;
always_ff @(posedge clk)
	p2y <= transform ? y2_prime[47:16] : up2y;
always_ff @(posedge clk)
	p2z <= transform ? z2_prime[47:16] : up2z;

always_ff @(posedge clk)
	offset <= {{({16'd0,gcy} * TargetWidth) + gcx},1'b0};
always_ff @(posedge clk)
	ma <= TargetBase + offset;

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// Cursor related registers
reg [31:0] collision;
reg [4:0] spriteno;
reg sprite;
reg [31:0] spriteEnable;
reg [31:0] spriteActive, spriteActiveB;
wire [5:0] nxtSprite;
reg [11:0] sprite_pv [0:31];
reg [11:0] sprite_ph [0:31];
reg [3:0] sprite_pz [0:31];
reg [31:0] sprite_color [0:255];
reg [31:0] sprite_on;
reg [31:0] sprite_on_d1;
reg [31:0] sprite_on_d2;
reg [31:0] sprite_on_d3;
address_t spriteAddr [0:31];
address_t spriteWaddr [0:31];
reg [15:0] spriteMcnt [0:31];
reg [15:0] spriteWcnt [0:31];
reg [63:0] m_spriteBmp [0:31];
reg [63:0] spriteBmp [0:31];
reg [15:0] spriteColor [0:31];
reg [31:0] spriteLink1;
reg [7:0] spriteColorNdx [0:31];

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

reg [27:0] vndx;
// Line draw vars
reg signed [15:0] dx,dy;
reg signed [15:0] sx,sy;
reg signed [15:0] err;
wire signed [15:0] e2 = err << 1;
// Anti-aliased line draw
reg steep;
reg [31:0] openColor;
reg [31:0] xend, yend, gradient, xgap;
reg [31:0] xpxl1, ypxl1, xpxl2, ypxl2;
reg [31:0] intery;
reg signed [31:0] dxa,dya;

reg [`ABITS] rdadr;


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// blitter vars
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

reg [7:0] blit_state;
reg [31:0] bltSrcWid, bltSrcWidx;
reg [31:0] bltDstWid, bltDstWidx;
//  ch  321033221100       
//  TBDzddddebebebeb
//  |||   |       |+- bitmap mode
//  |||   |       +-- channel enabled
//  |||   +---------- direction 0=normal,1=decrement
//  ||+-------------- done indicator
//  |+--------------- busy indicator
//  +---------------- trigger bit
reg [15:0] bltCtrlx;
reg [15:0] bltA_shift, bltB_shift, bltC_shift;
reg [15:0] bltLWMask = 16'hFFFF;
reg [15:0] bltFWMask = 16'hFFFF;

reg [`ABITS] bltA_badr;               // base address
reg [31:0] bltA_mod;                // modulo
reg [31:0] bltA_cnt;
reg [7:0] bltA_inc;
reg [`ABITS] bltA_badrx;               // base address
reg [31:0] bltA_modx;                // modulo
reg [31:0] bltA_cntx;
reg [7:0] bltA_incx;
reg [`ABITS] bltA_wadr;				// working address
reg [31:0] bltA_wcnt;				// working count
reg [31:0] bltA_dcnt;				// working count
reg [31:0] bltA_hcnt;

reg [`ABITS] bltB_badr;
reg [31:0] bltB_mod;
reg [31:0] bltB_cnt;
reg [7:0] bltB_inc;
reg [`ABITS] bltB_badrx;
reg [31:0] bltB_modx;
reg [31:0] bltB_cntx;
reg [7:0] bltB_incx;
reg [`ABITS] bltB_wadr;				// working address
reg [31:0] bltB_wcnt;				// working count
reg [31:0] bltB_dcnt;				// working count
reg [31:0] bltB_hcnt;

reg [`ABITS] bltC_badr;
reg [31:0] bltC_mod;
reg [31:0] bltC_cnt;
reg [7:0] bltC_inc;
reg [`ABITS] bltC_badrx;
reg [31:0] bltC_modx;
reg [31:0] bltC_cntx;
reg [7:0] bltC_incx;
reg [`ABITS] bltC_wadr;				// working address
reg [31:0] bltC_wcnt;				// working count
reg [31:0] bltC_dcnt;				// working count
reg [31:0] bltC_hcnt;

reg [`ABITS] bltD_badr;
reg [31:0] bltD_mod;
reg [31:0] bltD_cnt;
reg [7:0] bltD_inc;
reg [`ABITS] bltD_badrx;
reg [31:0] bltD_modx;
reg [31:0] bltD_cntx;
reg [7:0] bltD_incx;
reg [`ABITS] bltD_wadr;				// working address
reg [31:0] bltD_wcnt;				// working count
reg [31:0] bltD_hcnt;

reg [15:0] blt_op;
reg [15:0] blt_opx;
reg [6:0] bitcnt;
reg [3:0] bitinc;
reg [1:0] blt_nch;

// May need to set the pipeline depth to zero if copying neighbouring pixels
// during a blit. So the app is allowed to control the pipeline depth. Depth
// should not be set >28.
reg [4:0] bltPipedepth = 5'd15;
reg [4:0] bltPipedepthx;
reg [31:0] bltinc;
reg [4:0] bltAa,bltBa,bltCa;
reg wrA, wrB, wrC;
reg [15:0] blt_bmpA;
reg [15:0] blt_bmpB;
reg [15:0] blt_bmpC;
reg [15:0] bltA_residue;
reg [15:0] bltB_residue;
reg [15:0] bltC_residue;
reg [15:0] bltD_residue;

wire [15:0] bltA_out, bltB_out, bltC_out;
wire [15:0] bltA_out1, bltB_out1, bltC_out1;
reg  [63:0] bltA_dat, bltB_dat, bltC_dat, bltD_dat;
reg  [63:0] bltA_datx, bltB_datx, bltC_datx, bltD_datx;
// Convert an input bit into a color (black or white) to allow use as a mask.
wire [15:0] bltA_in = bltCtrlx[0] ? (blt_bmpA[bitcnt] ? 16'h7FFF : 16'h0000) : blt_bmpA;
wire [15:0] bltB_in = bltCtrlx[2] ? (blt_bmpB[bitcnt] ? 16'h7FFF : 16'h0000) : blt_bmpB;
wire [15:0] bltC_in = bltCtrlx[4] ? (blt_bmpC[bitcnt] ? 16'h7FFF : 16'h0000) : blt_bmpC;
assign bltA_out = bltA_datx;
assign bltB_out = bltB_datx;
assign bltC_out = bltC_datx;

reg [15:0] bltab;
reg [15:0] bltabc;

// Perform alpha blending between the two colors.
wire [13:0] blndR = (bltB_out[`R] * bltA_out[7:0]) + (bltC_out[`R]* ~bltA_out[7:0]);
wire [13:0] blndG = (bltB_out[`G] * bltA_out[7:0]) + (bltC_out[`G]* ~bltA_out[7:0]);
wire [13:0] blndB = (bltB_out[`B] * bltA_out[7:0]) + (bltC_out[`B]* ~bltA_out[7:0]);

always_comb
	case(blt_opx[3:0])
	4'h1:	bltab <= bltA_out;
	4'h2:	bltab <= bltB_out;
	4'h3:	bltab <= ~bltA_out;
	4'h4:	bltab <= ~bltB_out;
	4'h8:	bltab <= bltA_out & bltB_out;
	4'h9:	bltab <= bltA_out | bltB_out;
	4'hA:	bltab <= bltA_out ^ bltB_out;
	4'hB:	bltab <= bltA_out & ~bltB_out;
	4'hF:	bltab <= 16'h7fff;   // WHITE
	default:bltab <= 16'h0000;   // BLACK
	endcase
always_comb
	case(blt_opx[7:4])
	4'h1:	bltabc <= bltab;
	4'h2:	bltabc <= bltC_out;
	4'h3:	if (bltab[`A]) begin
				bltabc[`R] <= bltC_out[`R] >> bltab[2:0];
				bltabc[`G] <= bltC_out[`G] >> bltab[5:3];
				bltabc[`B] <= bltC_out[`B] >> bltab[8:6];
			end
			else
				bltabc <= bltab;
	4'h4:	bltabc <= {blndR[12:8],blndG[12:8],blndB[12:8]};
	4'h7:   bltabc <= (bltC_out & ~bltB_out) | bltA_out; 
	4'h8:	bltabc <= bltab & bltC_out;
	4'h9:	bltabc <= bltab | bltC_out;
	4'hA:	bltabc <= bltab ^ bltC_out;
	4'hB:	bltabc <= bltab & ~bltC_out;
	4'hF:	bltabc <= 16'h7fff;  // WHITE
	default:bltabc <= 16'h0000;  // BLACK
	endcase

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Register blitter controls across clock domain.
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
always_ff @(posedge clk)
	bltA_badrx <= bltA_badr;
always_ff @(posedge clk)
	bltA_modx <= bltA_mod;
always_ff @(posedge clk)
	bltA_cntx <= bltA_cnt;
always_ff @(posedge clk)
	bltB_badrx <= bltB_badr;
always_ff @(posedge clk)
	bltB_modx <= bltB_mod;
always_ff @(posedge clk)
	bltB_cntx <= bltB_cnt;
always_ff @(posedge clk)
	bltC_badrx <= bltC_badr;
always_ff @(posedge clk)
	bltC_modx <= bltC_mod;
always_ff @(posedge clk)
	bltC_cntx <= bltC_cnt;
always_ff @(posedge clk)
	bltSrcWidx <= bltSrcWid;
always_ff @(posedge clk)
	blt_opx <= blt_op;
always_ff @(posedge clk)
	bltPipedepthx <= bltPipedepth;

reg [63:0] dat_ix;
wire peBltCtrl;
wire peBltAdatx;
wire peBltBdatx;
wire peBltCdatx;
wire peBltDdatx;
wire peBltDbadrx,peBltDmodx,peBltDcntx;
wire peBltDstWidx;
wire cs_bltCtrl = (cs & sbus.req.we & (rdy2|rdy3) & ~rdy4) && sbus.req.adr[14:3]==12'b00_0110_1100_11 && |sbus.req.sel[1:0];
wire cs_bltAdatx = (cs & sbus.req.we & (rdy2|rdy3) & ~rdy4) && sbus.req.adr[14:3]==12'b00_0110_1000_11 && |sbus.req.sel[1:0];
wire cs_bltBdatx = (cs & sbus.req.we & (rdy2|rdy3) & ~rdy4) && sbus.req.adr[14:3]==12'b00_0110_1001_11 && |sbus.req.sel[1:0];
wire cs_bltCdatx = (cs & sbus.req.we & (rdy2|rdy3) & ~rdy4) && sbus.req.adr[14:3]==12'b00_0110_1010_11 && |sbus.req.sel[1:0];
wire cs_bltDdatx = (cs & sbus.req.we & (rdy2|rdy3) & ~rdy4) && sbus.req.adr[14:3]==12'b00_0110_1011_11 && |sbus.req.sel[1:0];
wire cs_bltDbadrx = (cs & sbus.req.we & (rdy2|rdy3) & ~rdy4) && sbus.req.adr[14:3]==12'b00_0110_1011_00 && |sbus.req.sel[1:0];
wire cs_bltDbmodx = (cs & sbus.req.we & (rdy2|rdy3) & ~rdy4) && sbus.req.adr[14:3]==12'b00_0110_1011_01 && |sbus.req.sel[1:0];
wire cs_bltDbcntx = (cs & sbus.req.we & (rdy2|rdy3) & ~rdy4) && sbus.req.adr[14:3]==12'b00_0110_1011_10 && |sbus.req.sel[1:0];
wire cs_bltDstWidx = (cs & sbus.req.we & (rdy2|rdy3) & ~rdy4) && sbus.req.adr[14:3]==12'b00_0110_1100_01 && |sbus.req.sel[1:0];
edge_det ed2(.rst(rst), .clk(clk), .ce(1'b1), .i(cs_bltCtrl), .pe(peBltCtrl), .ne(), .ee());
edge_det ed3(.rst(rst), .clk(clk), .ce(1'b1), .i(cs_bltAdatx), .pe(peBltAdatx), .ne(), .ee());
edge_det ed4(.rst(rst), .clk(clk), .ce(1'b1), .i(cs_bltBdatx), .pe(peBltBdatx), .ne(), .ee());
edge_det ed5(.rst(rst), .clk(clk), .ce(1'b1), .i(cs_bltCdatx), .pe(peBltCdatx), .ne(), .ee());
edge_det ed6(.rst(rst), .clk(clk), .ce(1'b1), .i(cs_bltDdatx), .pe(peBltDdatx), .ne(), .ee());
edge_det ed7(.rst(rst), .clk(clk), .ce(1'b1), .i(cs_bltDbadrx), .pe(peBltDbadrx), .ne(), .ee());
edge_det ed8(.rst(rst), .clk(clk), .ce(1'b1), .i(cs_bltDmodx), .pe(peBltDmodx), .ne(), .ee());
edge_det ed9(.rst(rst), .clk(clk), .ce(1'b1), .i(cs_bltDcntx), .pe(peBltDcntx), .ne(), .ee());
edge_det ed10(.rst(rst), .clk(clk), .ce(1'b1), .i(cs_bltDstWidx), .pe(peBltDstWidx), .ne(), .ee());

always_ff @(posedge clk)
	dat_ix <= sbus.req.dat;

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

wire [15:0] hpos, vpos;
wire [15:0] hpos_mask = b[15: 0];
wire [15:0] vpos_mask = b[31:16];
wire [15:0] hpos_masked = hpos & hpos_mask;
wire [15:0] vpos_masked = vpos & vpos_mask;
wire [15:0] hpos_wait = a[15: 0];
wire [15:0] vpos_wait = a[31:16];

reg [15:0] vid_row,vid_col;
always_ff @(posedge vclk)
	vid_row <= (vpos - 16'd28) >> 1; 
always_ff @(posedge vclk)
	vid_col <= (hpos - 16'd212) >> 1;
always_ff @(posedge vclk)
	vid_addrb <= {4'd0,vid_row} * 16'd400 + vid_col;
always_ff @(posedge vclk)
	vid_out <= rgb;

function fnClip;
input [15:0] x;
input [15:0] y;
begin
	fnClip = (x >= TargetWidth || y >= TargetHeight)
			 || (clipEnable && (x < clipX0 || x >= clipX1 || y < clipY0 || y >= clipY1))
			;
end
endfunction

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

// Validate parameters
always_comb
begin
	if (NUM_PAGESIZES < 1) begin
		$display("Q4 Copro: must have at least one page size.");
		$finish;
	end
	if (NUM_PAGESIZES > 8) begin
		$display("Q4 Copro: too many page sizes.");
		$finish;
	end
	if (LOG_TLB_ENTRIES > 16) begin
		$display("Q4 Copro: too many TLB entries.");
		$finish;
	end
end

reg signed [31:0] div_a, div_b;
wire signed [63:0] div_qo;
wire div_idle;

AVICDivider #(.WID(64)) udiv1
(
	.rst(rst),
	.clk(clk),
	.ld(div_ld),
	.abort(1'b0),
	.sgn(1'b1),
	.sgnus(1'b0),
	.a({{16{div_a[31]}},div_a,16'h0}),
	.b({{32{div_b[31]}},div_b}),
	.qo(div_qo),
	.ro(),
	.dvByZr(),
	.done(),
	.idle(div_idle)
);

wire [63:0] trimult;
AVICTriMult umul3
(
  .CLK(clk),
  .A(div_qo[31:0]),
  .B(v2x-v0x),
  .P(trimult)
);

always_comb
	ip2 = ip[2];

always_comb
	csc = cs_copro & sbus.req.cyc & sbus.req.stb;
always_comb
	cs = csc | mcs;
always_comb
	we = mcs ? mbus.req.we : sbus.req.we;
always_comb
	sel = mcs ? mbus.req.sel : sbus.req.sel;
always_comb
	adr = mcs ? mbus.req.adr : sbus.req.adr;
always_comb
	dat = mcs ? mbus.req.dat : sbus.req.dat;
always_comb
	sbus.resp.dat = csc ? dato : 64'd0;

delay2 udly2 (.clk(clk), .ce(1'b1), .i(cs), .o(dly2));

always_ff @(posedge clk)
if (rst) begin
	ptbr[0] <= 64'hFFFFFFFFFF800000;
	ptbr[1] <= 64'hFFFFFFFFFF802000;
	ptattr[0] <= 64'd0;
	ptattr[0].level <= 3'd1;
	ptattr[0].pgsz <= LOG_PAGESIZE;
	ptattr[0].log_te <= LOG_TLB_ENTRIES;
	ptattr[1] <= 64'd0;
	ptattr[1].level <= 3'd1;
	ptattr[1].pgsz <= 5'd23;
	ptattr[1].log_te <= 5'd7;
	ptattr[2] <= 64'd0;
	ptattr[2].level <= 3'd1;
	ptattr[2].pgsz <= 5'd23;
	ptattr[2].log_te <= 5'd7;
	sbus.resp <= {$bits(wb_cmd_response64_t){1'b0}};
	clear_page_fault <= FALSE;
	entry_no <= 32'd0;
	cmd <= 64'd0;
	idat <= 64'd0;
	spriteEnable <= 32'hFFFFFFFF;
	foreach (sprite_color[n1])
		sprite_color[n1] <= {2{lfsro}};
	foreach (spriteAddr[n1])
		spriteAddr[n1] <= 32'h00101000 + 256 * n1;
	foreach (sprite_ph[n1])
		sprite_ph[n1] <= 16'd208 + (n1 % 8) * 34;
	foreach (sprite_pv[n1])
		sprite_pv[n1] <= 16'd128 + (n1 >> 3) * 34;
	foreach (sprite_pv[n1])
		sprite_pz[n1] <= 16'h0;
	foreach (spriteMcnt[n1])
		spriteMcnt[n1] <= 32*32;
	lowres <= 2'b01;
	cmdq_in <= 64'd0;
	bltA_inc <= 8'd2;
	bltB_inc <= 8'd2;
	bltC_inc <= 8'd2;
	bltD_inc <= 8'd2;
end
else begin
	clear_page_fault <= FALSE;
	if (cs) begin
		if (csc) begin
			sbus.resp.tid <= sbus.req.tid;	
			sbus.resp.pri <= sbus.req.pri;
		end
		if (we && adr[31:16]==16'hFE00) begin// 31:16==16'hFE00
			casez(adr[14:3])
			// Sprite color palette $000 to $7F8
			12'b000_0???_????_?:	sprite_color[adr[10:3]] <= dat;
			// Sprite $800 to $9F8
			12'b000_100?_????_0:	spriteAddr[adr[8:4]] <= dat[`ABITS];
			12'b000_100?_????_1:
				begin
					if (&sel[1:0]) spriteMcnt[adr[8:4]] <= dat[15:0];
					if ( sel[3]) sprite_pz[adr[8:4]] <= dat[31:24];
					if (&sel[5:4]) sprite_ph[adr[8:4]] <= dat[43:32];
					if (&sel[7:6]) sprite_pv[adr[8:4]] <= dat[59:48];
				end
			// Reserved Area $A00 to $BF8
			12'b000_101?_????_?:	;
							
			// Audio $C00 to $CB8
	    12'b000_1100_0000_0:   aud0_adr <= dat[`ABITS];
	    12'b000_1100_0000_1:
	    	begin 
	    		if (&sel[1:0]) aud0_length <= dat[15:0];
	    		if (&sel[7:4]) aud0_period <= dat[41:32];
	    	end
	    12'b000_1100_0001_0:
	      begin
		      if (&sel[1:0]) aud0_volume <= dat[15:0];
		      if (&sel[3:2]) aud0_dat <= dat[31:16];
	      end
	    12'b000_1100_0010_0:   aud1_adr <= dat[`ABITS];
	    12'b000_1100_0010_1:
	    	begin
	    		if (&sel[1:0]) aud1_length <= dat[15:0];
	    		if (&sel[7:4]) aud1_period <= dat[41:32];
	    	end
	    12'b000_1100_0011_0:
	       begin
	        if (&sel[1:0]) aud1_volume <= dat[15:0];
	        if (&sel[3:2]) aud1_dat <= dat[31:16];
	      end
	    12'b000_1100_0100_0:   aud2_adr <= dat[`ABITS];
	    12'b000_1100_0100_1:
	    	begin
	    		if (&sel[1:0]) aud2_length <= dat[15:0];
	    		if (&sel[7:4]) aud2_period <= dat[41:32];
	    	end
	    12'b000_1100_0101_0:
	      begin
	        if (&sel[1:0]) aud2_volume <= dat[15:0];
	        if (&sel[3:2]) aud2_dat <= dat[31:16];
	      end
	    12'b000_1100_0110_0:   aud3_adr <= dat[`ABITS];
	    12'b000_1100_0110_1:
	    	begin
	    		if (&sel[1:0]) aud3_length <= dat[15:0];
	    		if (&sel[7:4]) aud3_period <= dat[41:32];
	    	end
	    12'b000_1100_0111_0:
	      begin
	        if (&sel[1:0]) aud3_volume <= dat[15:0];
	        if (&sel[3:2]) aud3_dat <= dat[31:16];
	      end
	    12'b000_1100_1000_0:   audi_adr <= dat[`ABITS];
	    12'b000_1100_1000_1:
	    	begin
	    		if (&sel[1:0]) audi_length <= dat[15:0];
	    		if (&sel[7:4]) audi_period <= dat[41:32];
	    	end
	    12'b000_1100_1001_0:
				begin
	        if (&sel[1:0]) audi_volume <= dat[15:0];
	        //if (|sel[3:2]) audi_dat <= dat[31:16];
	      end
	    12'b000_1100_1010_0:    aud_ctrl <= dat;

			// Blitter: $D00 to $D98
			12'b000_1101_0000_0:	bltA_badr <= dat[`ABITS];
			12'b000_1101_0000_1:	bltA_mod <= dat;
			12'b000_1101_0001_0:	bltA_cnt <= dat;
			12'b000_1101_0010_0:	bltB_badr <= dat[`ABITS];
			12'b000_1101_0010_1:	bltB_mod <= dat;
			12'b000_1101_0011_0:	bltB_cnt <= dat;
			12'b000_1101_0100_0:	bltC_badr <= dat[`ABITS];
			12'b000_1101_0100_1:	bltC_mod <= dat;
			12'b000_1101_0101_0:	bltC_cnt <= dat;
			12'b000_1101_0110_0:	bltD_badr <= dat[`ABITS];
			12'b000_1101_0110_1:	bltD_mod <= dat;
			12'b000_1101_0111_0:	bltD_cnt <= dat;
			12'b000_1101_0111_1:	bltD_dat <= dat;

			12'b000_1101_1000_0:	bltSrcWid <= dat;
			12'b000_1101_1000_1:	bltDstWid <= dat;

			12'b000_1101_1001_0:	blt_op <= dat[15:0];
			12'b000_1101_1001_1:	
								begin
//								if (sel[3]) bltPipedepth <= dat[29:24];
								if (sel[4]) bltA_inc <= dat[39:32];
								if (sel[5]) bltB_inc <= dat[47:40];
								if (sel[6]) bltC_inc <= dat[55:48];
								if (sel[7]) bltD_inc <= dat[63:56];
								end
			// Command queue $DC0
			12'b000_1101_1100_0:	
				begin
					if (&sel[5:4]) cmdq_in[47:32] <= dat[47:32];
					if (sel[0]) cmdq_in[7:0] <= dat[7:0];
					if (sel[1]) cmdq_in[15:8] <= dat[15:8];
					if (sel[2]) cmdq_in[23:16] <= dat[23:16];
					if (sel[3]) cmdq_in[31:24] <= dat[31:24];
				end

			12'b000_1111_0110_0:	spriteEnable <= dat[31:0];
			12'b000_1111_0110_1:	spriteLink1 <= dat[31:0];

	    12'b000_1111_0111_0:
	     	begin
					if (sel[0]) lowres <= dat[1:0];   
				end
			// FC0 to FCF read-only
			12'b001_1101_0000_0:	clear_page_fault <= TRUE;
			12'b001_0000_0000_0:	ptbr[0] <= dat;
			12'b001_0000_0001_0:	ptattr[0] <= dat;
			12'b001_0000_0010_0:	ptbr[1] <= dat;
			12'b001_0000_0011_0:	ptattr[1] <= dat;
			12'b001_0000_0100_0:	ptbr[2] <= dat;
			12'b001_0000_0101_0:	ptattr[2] <= dat;
			default:	;
			endcase
			sbus.resp.ack <= dly2;
		end
		ptattr[0].pgsz <= LOG_PAGESIZE;
		ptattr[0].log_te <= LOG_TLB_ENTRIES;
		if (adr[31:16]==16'hFE00) begin
			casez(adr[14:3])
			12'b000_1101_1100_1:	dato <= CMD_FIFO_DEPTH-cmdq_cnt;
			12'hF00:	dato <= lfsro;
			// To 12'hFDF
			12'b111_1110_0000_0:	dato <= ptbr[0];
			12'b111_1110_0001_0:	dato <= ptattr[0];
			12'b111_1110_0010_0:	dato <= ptbr[1];
			12'b111_1110_0011_0:	dato <= ptattr[1];
			12'b111_1110_0100_0:	dato <= ptbr[2];
			12'b111_1110_0101_0:	dato <= ptattr[2];
			12'b111_1111_0000_0:	dato <= miss_adr1[0];
			12'b111_1111_0000_1:	dato <= miss_asid1[0];
			12'b111_1111_0001_0:	dato <= miss_adr1[1];
			12'b111_1111_0001_1:	dato <= miss_asid1[1];
			12'b111_1111_0010_0:	dato <= miss_adr1[2];
			12'b111_1111_0010_1:	dato <= miss_asid1[2];
			default:	dato <= doutb2;
			endcase
			sbus.resp.ack <= dly2;
		end
	end
	else
		sbus.resp.ack <= LOW;
	if (mcs) begin
		if (adr[31:16]==16'hFE00) begin
			casez(adr[14:3])
			12'b000_1101_1001_1:	idat <= bltCtrlx;
			12'b000_1101_1100_1:	idat <= CMD_FIFO_DEPTH-cmdq_cnt;
			12'b000_1111_0111_0:	idat <= collision;
			12'b111_1000_0000_0:	idat <= lfsro;
			// To 12'hFDF
			12'b111_1110_0000_0:	idat <= ptbr[0];
			12'b111_1110_0001_0:	idat <= ptattr[0];
			12'b111_1110_0010_0:	idat <= ptbr[1];
			12'b111_1110_0011_0:	idat <= ptattr[1];
			12'b111_1110_0100_0:	idat <= ptbr[2];
			12'b111_1110_0101_0:	idat <= ptattr[2];
			12'b111_1111_0000_0:	idat <= miss_adr1[0];
			12'b111_1111_0000_1:	idat <= miss_asid1[0];
			12'b111_1111_0001_0:	idat <= miss_adr1[1];
			12'b111_1111_0001_1:	idat <= miss_asid1[1];
			12'b111_1111_0010_0:	idat <= miss_adr1[2];
			12'b111_1111_0010_1:	idat <= miss_asid1[2];
			default:	idat <= douta2;
			endcase
		end
		else if (adr[31:20]==12'h001)
			idat <= vid_douta;
		else if (adr[31:20]==12'h000)
			idat <= douta;
	end
end

always_ff @(posedge clk)
	rdy1 <= gr_cmdq_cs;
always_ff @(posedge clk)
	rdy2 <= rdy1 & gr_cmdq_cs;
always_ff @(posedge clk)
	rdy3 <= rdy2 & gr_cmdq_cs;
always_ff @(posedge clk)
	rdy4 <= rdy3 & gr_cmdq_cs;

// xpm_memory_tdpram: True Dual Port RAM
// Xilinx Parameterized Macro, version 2025.1

xpm_memory_tdpram #(
  .ADDR_WIDTH_A(10),               // DECIMAL
  .ADDR_WIDTH_B(10),               // DECIMAL
  .AUTO_SLEEP_TIME(0),            // DECIMAL
  .BYTE_WRITE_WIDTH_A(8),        // DECIMAL
  .BYTE_WRITE_WIDTH_B(8),        // DECIMAL
  .CASCADE_HEIGHT(0),             // DECIMAL
  .CLOCKING_MODE("independent_clock"), // String
  .ECC_BIT_RANGE("7:0"),          // String
  .ECC_MODE("no_ecc"),            // String
  .ECC_TYPE("none"),              // String
  .IGNORE_INIT_SYNTH(0),          // DECIMAL
  .MEMORY_INIT_FILE("none"),      // String
  .MEMORY_INIT_PARAM("0"),        // String
  .MEMORY_OPTIMIZATION("true"),   // String
  .MEMORY_PRIMITIVE("auto"),      // String
  .MEMORY_SIZE(1024*64),           // DECIMAL
  .MESSAGE_CONTROL(0),            // DECIMAL
  .RAM_DECOMP("auto"),            // String
  .READ_DATA_WIDTH_A(64),         // DECIMAL
  .READ_DATA_WIDTH_B(64),         // DECIMAL
  .READ_LATENCY_A(1),             // DECIMAL
  .READ_LATENCY_B(1),             // DECIMAL
  .READ_RESET_VALUE_A("0"),       // String
  .READ_RESET_VALUE_B("0"),       // String
  .RST_MODE_A("SYNC"),            // String
  .RST_MODE_B("SYNC"),            // String
  .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
  .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
  .USE_MEM_INIT(1),               // DECIMAL
  .USE_MEM_INIT_MMI(0),           // DECIMAL
  .WAKEUP_TIME("disable_sleep"),  // String
  .WRITE_DATA_WIDTH_A(64),        // DECIMAL
  .WRITE_DATA_WIDTH_B(64),        // DECIMAL
  .WRITE_MODE_A("no_change"),     // String
  .WRITE_MODE_B("no_change"),     // String
  .WRITE_PROTECT(1)               // DECIMAL
)
ureg_shadow1
(
  .dbiterra(),
  .dbiterrb(),
  .douta(douta2),
  .doutb(doutb2),
  .sbiterra(),
  .sbiterrb(),
  .addra(addra2),
  .addrb(addrb2),
  .clka(clka2),
  .clkb(clkb2),
  .dina(dina2),
  .dinb(dinb2),
  .ena(ena2),
  .enb(enb2),
  .injectdbiterra(1'b0),
  .injectdbiterrb(1'b0),
  .injectsbiterra(1'b0),
  .injectsbiterrb(1'b0),
  .regcea(1'b1),
  .regceb(1'b1),
  .rsta(rsta2),
  .rstb(rstb2),
  .sleep(1'b0),
  .wea(wea2),
  .web(web2)
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Command queue
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

fifo
#(
	.WIDTH(64),
	.DEPTH(CMD_FIFO_DEPTH)
)
ucmdfifo1
(
	.rst(rst_cmdq),
	.clk(clk),
	.wr(wr_cmd_fifo),
	.din(cmdq_in),
	.rd(rd_cmd_fifo),
	.dout(cmdq_out),
	.cnt(cmdq_cnt)
);

edge_det ued20 (.rst(rst), .clk(clk), .ce(1'b1), .i(rdy1), .pe(cmdp), .ne(), .ee());

wire pe_hsync;
wire pe_hsync2;
wire pe_vsync;
wire pe_vsync2;
edge_det edh1
(
	.rst(rst),
	.clk(vclk),
	.ce(1'b1),
	.i(hsync_i),
	.pe(pe_hsync),
	.ne(),
	.ee()
);

edge_det edh2
(
	.rst(rst),
	.clk(clk),
	.ce(1'b1),
	.i(hsync_i),
	.pe(pe_hsync2),
	.ne(),
	.ee()
);

edge_det edv1
(
	.rst(rst),
	.clk(vclk),
	.ce(1'b1),
	.i(vsync_i),
	.pe(pe_vsync),
	.ne(),
	.ee()
);

edge_det edv2
(
	.rst(rst),
	.clk(clk),
	.ce(1'b1),
	.i(vsync_i),
	.pe(pe_vsync2),
	.ne(),
	.ee()
);

// Raw scanline counter
vid_counter #(16) u_vctr (.rst(rst), .clk(vclk), .ce(pe_hsync), .ld(pe_vsync), .d(16'd0), .q(vpos), .tc());
vid_counter #(16) u_hctr (.rst(rst), .clk(vclk), .ce(1'b1), .ld(pe_hsync), .d(16'd0), .q(hpos), .tc());
vid_counter #(6) u_fctr (.rst(rst), .clk(vclk), .ce(pe_vsync), .ld(1'b0), .d(6'd0), .q(frame), .tc());

// xpm_memory_tdpram: True Dual Port RAM
// Xilinx Parameterized Macro, version 2025.1

xpm_memory_tdpram #(
  .ADDR_WIDTH_A(13),              // DECIMAL
  .ADDR_WIDTH_B(13),              // DECIMAL
  .AUTO_SLEEP_TIME(0),            // DECIMAL
  .BYTE_WRITE_WIDTH_A(64),        // DECIMAL
  .BYTE_WRITE_WIDTH_B(64),        // DECIMAL
  .CASCADE_HEIGHT(0),             // DECIMAL
  .CLOCKING_MODE("independent_clock"), // String
  .ECC_BIT_RANGE("7:0"),          // String
  .ECC_MODE("no_ecc"),            // String
  .ECC_TYPE("none"),              // String
  .IGNORE_INIT_SYNTH(0),          // DECIMAL
  .MEMORY_INIT_FILE("ptw.mem"),   // String
  .MEMORY_INIT_PARAM("0"),        // String
  .MEMORY_OPTIMIZATION("true"),   // String
  .MEMORY_PRIMITIVE("auto"),      // String
  .MEMORY_SIZE(8192*64),          // DECIMAL
  .MESSAGE_CONTROL(0),            // DECIMAL
  .RAM_DECOMP("auto"),            // String
  .READ_DATA_WIDTH_A(64),         // DECIMAL
  .READ_DATA_WIDTH_B(64),         // DECIMAL
  .READ_LATENCY_A(1),             // DECIMAL
  .READ_LATENCY_B(1),             // DECIMAL
  .READ_RESET_VALUE_A("0"),       // String
  .READ_RESET_VALUE_B("0"),       // String
  .RST_MODE_A("SYNC"),            // String
  .RST_MODE_B("SYNC"),            // String
  .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
  .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
  .USE_MEM_INIT(1),               // DECIMAL
  .USE_MEM_INIT_MMI(0),           // DECIMAL
  .WAKEUP_TIME("disable_sleep"),  // String
  .WRITE_DATA_WIDTH_A(64),        // DECIMAL
  .WRITE_DATA_WIDTH_B(64),        // DECIMAL
  .WRITE_MODE_A("no_change"),     // String
  .WRITE_MODE_B("no_change"),     // String
  .WRITE_PROTECT(1)               // DECIMAL
)
urom1 (
  .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence on the data output of port A.
  .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence on the data output of port A.
  .douta(douta),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
  .doutb(doutb),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
  .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence on the data output of port A.
  .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence on the data output of port B.
  .addra(addra),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
  .addrb(addrb),                   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
  .clka(clka),                     // 1-bit input: Clock signal for port A. Also clocks port B when parameter CLOCKING_MODE is "common_clock".
  .clkb(clkb),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is "independent_clock". Unused when
  .dina(dina),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
  .dinb(dinb),                     // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
  .ena(ena),                       // 1-bit input: Memory enable signal for port A. Must be high on clock cycles when read or write operations
  .enb(enb),                       // 1-bit input: Memory enable signal for port B. Must be high on clock cycles when read or write operations
  .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when ECC enabled (Error injection capability
  .injectdbiterrb(1'b0), // 1-bit input: Controls double bit error injection on input data when ECC enabled (Error injection capability
  .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when ECC enabled (Error injection capability
  .injectsbiterrb(1'b0), // 1-bit input: Controls single bit error injection on input data when ECC enabled (Error injection capability
  .regcea(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output data path.
  .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output data path.
  .rsta(rsta),                     // 1-bit input: Reset signal for the final port A output register stage. Synchronously resets output port
  .rstb(rstb),                     // 1-bit input: Reset signal for the final port B output register stage. Synchronously resets output port
  .sleep(sleep),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
  .wea(wea),                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector for port A input data port dina. 1 bit
  .web(web)                        // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector for port B input data port dinb. 1 bit
);

// End of xpm_memory_tdpram_inst instantiation
				
xpm_memory_tdpram #(
  .ADDR_WIDTH_A(17),              // DECIMAL
  .ADDR_WIDTH_B(19),              // DECIMAL
  .AUTO_SLEEP_TIME(0),            // DECIMAL
  .BYTE_WRITE_WIDTH_A(8),        // DECIMAL
  .BYTE_WRITE_WIDTH_B(8),        // DECIMAL
  .CASCADE_HEIGHT(0),             // DECIMAL
  .CLOCKING_MODE("independent_clock"), // String
  .ECC_BIT_RANGE("7:0"),          // String
  .ECC_MODE("no_ecc"),            // String
  .ECC_TYPE("none"),              // String
  .IGNORE_INIT_SYNTH(0),          // DECIMAL
  .MEMORY_INIT_FILE("none"),   		// String
  .MEMORY_INIT_PARAM("0"),        // String
  .MEMORY_OPTIMIZATION("true"),   // String
  .MEMORY_PRIMITIVE("auto"),      // String
  .MEMORY_SIZE(131072*64),          // DECIMAL
  .MESSAGE_CONTROL(0),            // DECIMAL
  .RAM_DECOMP("auto"),            // String
  .READ_DATA_WIDTH_A(64),         // DECIMAL
  .READ_DATA_WIDTH_B(16),         // DECIMAL
  .READ_LATENCY_A(1),             // DECIMAL
  .READ_LATENCY_B(1),             // DECIMAL
  .READ_RESET_VALUE_A("0"),       // String
  .READ_RESET_VALUE_B("0"),       // String
  .RST_MODE_A("SYNC"),            // String
  .RST_MODE_B("SYNC"),            // String
  .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
  .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
  .USE_MEM_INIT(1),               // DECIMAL
  .USE_MEM_INIT_MMI(0),           // DECIMAL
  .WAKEUP_TIME("disable_sleep"),  // String
  .WRITE_DATA_WIDTH_A(64),        // DECIMAL
  .WRITE_DATA_WIDTH_B(16),        // DECIMAL
  .WRITE_MODE_A("no_change"),     // String
  .WRITE_MODE_B("no_change"),     // String
  .WRITE_PROTECT(1)               // DECIMAL
)
uvidram1 (
  .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence on the data output of port A.
  .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence on the data output of port A.
  .douta(vid_douta),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
  .doutb(vid_doutb),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
  .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence on the data output of port A.
  .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence on the data output of port B.
  .addra(vid_addra),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
  .addrb(vid_addrb),                   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
  .clka(vid_clka),                     // 1-bit input: Clock signal for port A. Also clocks port B when parameter CLOCKING_MODE is "common_clock".
  .clkb(vid_clkb),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is "independent_clock". Unused when
  .dina(vid_dina),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
  .dinb(vid_dinb),                     // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
  .ena(vid_ena),                       // 1-bit input: Memory enable signal for port A. Must be high on clock cycles when read or write operations
  .enb(vid_enb),                       // 1-bit input: Memory enable signal for port B. Must be high on clock cycles when read or write operations
  .injectdbiterra(1'b0),
  .injectdbiterrb(1'b0),
  .injectsbiterra(1'b0),
  .injectsbiterrb(1'b0),
  .regcea(1'b1),
  .regceb(1'b1),
  .rsta(vid_rsta),
  .rstb(vid_rstb),
  .sleep(1'b0),
  .wea(vid_wea),
  .web(vid_web)
);

// Source operand multiplexers.
always_comb
	case(ir.Rs1)
	4'd1:	a = r1;
	4'd2:	a = r2;
	4'd3:	a = r3;
	4'd4:	a = r4;
	4'd5:	a = r5;
	4'd6:	a = r6;
	4'd7:	a = r7;
	4'd8:	a = r8;
	4'd9:	a = r9;
	4'd10:	a = r10;
	4'd11:	a = r11;
	4'd12:	a = r12;
	4'd13:	a = r13;
	4'd14:  a = r14;
	4'd15:	a = r15;
	default:	a = 64'd0;
	endcase

always_comb
	case(ir.Rs2)
	4'd1:	b = r1;
	4'd2:	b = r2;
	4'd3:	b = r3;
	4'd4:	b = r4;
	4'd5:	b = r5;
	4'd6:	b = r6;
	4'd7:	b = r7;
	4'd8:	b = r8;
	4'd9:	b = r9;
	4'd10:	b = r10;
	4'd11:	b = r11;
	4'd12:	b = r12;
	4'd13:	b = r13;
	4'd14:  b = r14;
	4'd15:	b = r15;
	default:	b = 64'd0;
	endcase

wire scan_is_before_pos = hpos_masked <= hpos_wait && vpos_masked <= vpos_wait && (b[48] ? gfx_que_empty_i : 1'b1);
wire scan_is_after_pos = hpos_masked >= hpos_wait && vpos_masked >= vpos_wait && (b[48] ? gfx_que_empty_i : 1'b1);

// Evaluate branch condition
Qupls4_copro_branch_eval ube1
(
	.ir(ir),
	.a(a),
	.b(b),
	.after_pos(scan_is_after_pos),
	.before_pos(scan_is_before_pos),
	.takb(takb)
);

// Determine the next IP
Qupls4_copro_next_ip
#(
	.UNALIGNED_CONSTANTS(UNALIGNED_CONSTANTS)
)
unip1
(
	.rst(rst),
	.state(state),
	.wait_active(wait_active),
	.pe_vsync(pe_vsync2),
	.miss(miss),
	.paging_en(paging_en),
	.ir(ir),
	.takb(takb),
	.after_pos(scan_is_after_pos),
	.adr_hit(ir.Rd != 4'd0 && sbus.req.cyc && sbus.req.stb && sbus.req.we && sbus.req.adr[13:3]==ir.imm[14:4] && cs_copro),
	.a(a),
	.stack(stack),
	.sp(sp),
	.req(mbus.req),
	.resp(imresp),
	.local_sel(local_sel),
	.roma(roma),
	.douta(douta),
	.arg_dat(arg_dat),
	.ip(ip),
	.ipr(ipr),
	.tblit_ip(tblit_ip),
	.hsync_ip(hsync_ip),
	.cmdq_empty(cmdq_empty),
	.next_ip(next_ip)
);

counter #(.WID(32)) utck1
(
	.rst(rst),
	.clk(clk),
	.ce(1'b1),
	.ld(1'b0),
	.d(32'd0),
	.q(tick),
	.tc()
);

count_accum #(.WID(32)) uca1
(
	.rst(rst),
	.clk(clk),
	.ce(1'b1),
	.ld(1'b0),
	.d(32'd0),
	.a(icnta),
	.q(icnt),
	.tc()
);

always_ff @(posedge clk)
if (rst)
	ip <= 19'd0;
else
	ip <= next_ip;

always_comb
	flush_trig = flush_trig1[0];

reg hsync_det,vsync_det;

always @(posedge clk)
if (rst) begin
	tmp = 64'd0;
	ir <= {$bits(copro_instruction_t){1'b0}};
	stat <= 64'd0;
	miss_asid1 <= 16'h0;
	miss_adr1 <= {$bits(address_t){1'b0}};
	mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
	local_sel <= FALSE;
	missack <= FALSE;
	idle <= FALSE;
	paging_en <= TRUE;
	flush_en <= FALSE;
	rfwr <= FALSE;
	foreach(stack[n1])
		stack[n1] <= 530'd0;
	sp <= 4'd0;
	rstst <= TRUE;
	pushst <= FALSE;
	popst <= FALSE;
	icnta <= 32'd0;
	wait_active <= FALSE;
	wait_cond <= 4'h0;
	flush_trig1 <= 4'h0;
	rd_cmd_fifo <= FALSE;
	rst_cmdq <= TRUE;
	clipEnable <= FALSE;
	clipX0 <= 16'd0;
	clipY0 <= 16'd0;
	clipX1 <= 16'd400;
	clipY1 <= 16'd300;
	transform <= FALSE;
	aa <= 32'h00010000;
	ab <= 32'h00000000;
	ac <= 32'h00000000;
	at <= 32'h00000000;
	ba <= 32'h00000000;
	bb <= 32'h00010000;
	bc <= 32'h00000000;
	bt <= 32'h00000000;
	ca <= 32'h00000000;
	cb <= 32'h00000000;
	cc <= 32'h00010000;
	ct <= 32'h00000000;
	alpha <= 16'h8000;
	bltCtrlx <= 16'd0;
	bltCtrlx[13] <= 1'b1;	// Blitter is "done" to begin with.
	pen_color <= 24'h0003e0;
	fill_color <= 24'h007c00;
	font_tbl_adr <= 32'h00008000;
	font_id <= 16'h0000;
	tblit_active <= FALSE;
	tblit_state <= st_ifetch;
	hsync_det <= FALSE;
	vsync_det <= FALSE;
	spriteno <= 5'd31;
	div_ld <= FALSE;
	zbuf <= FALSE;
  tGoto(st_reset);
end
else begin
	tmp = 64'd0;
	rstst <= FALSE;
	pushst <= FALSE;
	popst <= FALSE;
	rd_cmd_fifo <= FALSE;
	rst_cmdq <= FALSE;
	icnta <= 32'd0;
	missack <= FALSE;
	flush_trig1 <= {1'b0,flush_trig1[3:1]};
	div_ld <= FALSE;
	if (clear_page_fault)
		page_fault <= FALSE;
	if (pe_hsync2)
		hsync_det <= TRUE;
	if (pe_vsync2)
		vsync_det <= TRUE;
	
	wr_aud0 <= FALSE;
	wr_aud1 <= FALSE;
	wr_aud2 <= FALSE;
	wr_aud3 <= FALSE;

	if (peBltCtrl)
		bltCtrlx <= dat_ix;
	if (peBltAdatx)
		bltA_datx <= dat_ix;
	if (peBltBdatx)
		bltB_datx <= dat_ix;
	if (peBltCdatx)
		bltC_datx <= dat_ix;
	if (peBltDdatx)
		bltD_datx <= dat_ix;
	if (peBltDbadrx)
		bltD_badrx <= dat_ix;
	if (peBltDmodx)
		bltD_modx <= dat_ix;
	if (peBltDcntx)
		bltD_cntx <= dat_ix;
	if (peBltDstWidx)
		bltDstWidx <= dat_ix;

	// Channel reset
	if (aud_ctrl[8])
		aud0_wadr <= aud0_adr;
	if (aud_ctrl[9])
		aud1_wadr <= aud1_adr;
	if (aud_ctrl[10])
		aud2_wadr <= aud2_adr;
	if (aud_ctrl[11])
		aud3_wadr <= aud3_adr;
	if (aud_ctrl[12])
		audi_wadr <= audi_adr;

	// Audio test mode generates about a 600Hz signal for 0.5 secs on all the
	// audio channels.
	if (aud_ctrl[14])
    aud_test <= aud_test + 24'd1;
	if (aud_test==24'hFFFFFF) begin
    aud_test <= 24'h0;
	end

	if (audi_req2)
		audi_dat <= aud_in;

	// Pipeline the vertical calc.
	vndx <= (vid_row >> lowres) * {TargetWidth,1'b0};
	charndx <= (charcode << font_width[4:3]) * (font_height + 6'd1);

	if (local_sel) begin
		if (state==st_mem_store)
			case(roma[12:3])
			default:	;
			endcase
		case(roma[12:3])
		10'h3E2:	arg_dat <= tlbe[63:0];
		10'h3E3:	arg_dat <= tlbe[127:64];
		default:	arg_dat <= 64'd0;
		endcase
	end

case(state)
st_reset:
	begin
		ir <= next_ir;
		tGoto(st_reset2);
	end
st_reset2:
	begin
		ir <= next_ir;
		tGoto(st_execute);
	end
st_hsync_iret:
	begin
		ir <= hsync_ir;
		tGoto(st_execute);
	end
st_tblit_iret:
	begin
		ir <= tblit_ir;
		tGoto(st_execute);
	end

// Check for interrupts and handle WAIT logic.
st_ifetch:
	begin
		icnta <= 2;
		ipr <= ip;
		rfwr <= FALSE;
		local_sel <= FALSE;
		ir <= next_ir;
		tGoto(st_execute);
		// Audio takes precedence to avoid audio distortion.
		// Fortunately audio DMA is fast and infrequent.
		if (aud0_fifo_empty & aud_ctrl[0]) begin
			sleep <= FALSE;
	    mbus.req.cyc <= HIGH;
	    mbus.req.stb <= HIGH;
	    mbus.req.sel <= 8'hFF;
			mbus.req.adr <= {aud0_wadr[31:3],3'h0};
//			tocnt <= busto;
			aud0_wadr <= aud0_wadr + 32'd8;
			if (aud0_wadr + 32'd8 >= aud0_eadr) begin
				aud0_wadr <= aud0_adr;
				irq_status[8] <= 1'b1;
			end
			if (aud0_wadr < (aud0_eadr >> 1) &&
				(aud0_wadr + 32'd8 >= (aud0_eadr >> 1)))
				irq_status[4] <= 1'b1;
			tCall(st_latch_data,st_aud0);
		end
		else if (aud1_fifo_empty & aud_ctrl[1])	begin
			sleep <= FALSE;
	    mbus.req.cyc <= HIGH;
	    mbus.req.stb <= HIGH;
	    mbus.req.sel <= 8'hFF;
			mbus.req.adr <= {aud1_wadr[31:3],3'h0};
//			tocnt <= busto;
			aud1_wadr <= aud1_wadr + 32'd8;
			if (aud1_wadr + 32'd8 >= aud1_eadr) begin
				aud1_wadr <= aud1_adr;
				irq_status[9] <= 1'b1;
			end
			if (aud1_wadr < (aud1_eadr >> 1) &&
				(aud1_wadr + 32'd8 >= (aud1_eadr >> 1)))
				irq_status[5] <= 1'b1;
			tCall(st_latch_data,st_aud1);
		end
		else if (aud2_fifo_empty & aud_ctrl[2]) begin
			sleep <= FALSE;
	    mbus.req.cyc <= HIGH;
	    mbus.req.stb <= HIGH;
	    mbus.req.sel <= 8'hFF;
			mbus.req.adr <= {aud2_wadr[31:3],3'h0};
//			tocnt <= busto;
			aud2_wadr <= aud2_wadr + 32'd8;
			if (aud2_wadr + 32'd8 >= aud2_eadr) begin
				aud2_wadr <= aud2_adr;
				irq_status[10] <= 1'b1;
			end
			if (aud2_wadr < (aud2_eadr >> 1) &&
				(aud2_wadr + 32'd8 >= (aud2_eadr >> 1)))
				irq_status[6] <= 1'b1;
			tCall(st_latch_data,st_aud2);
		end
		else if (aud3_fifo_empty & aud_ctrl[3])	begin
			sleep <= FALSE;
	    mbus.req.cyc <= HIGH;
	    mbus.req.stb <= HIGH;
	    mbus.req.sel <= 8'hFF;
			mbus.req.adr <= {aud3_wadr[31:3],3'h0};
//			tocnt <= busto;
			aud3_wadr <= aud3_wadr + 32'd8;
			aud3_req <= 6'd0;
			if (aud3_wadr + 32'd8 >= aud3_eadr) begin
				aud3_wadr <= aud3_adr;
				irq_status[11] <= 1'b1;
			end
			if (aud3_wadr < (aud3_eadr >> 1) &&
				(aud3_wadr + 32'd8 >= (aud3_eadr >> 1)))
				irq_status[7] <= 1'b1;
			tCall(st_latch_data,st_aud3);
		end
		else if (|audi_req) begin
			sleep <= FALSE;
	    mbus.req.cyc <= HIGH;
	    mbus.req.stb <= HIGH;
	    mbus.req.we <= HIGH;
	    mbus.req.sel <= 8'd3 << {audi_wadr[2:1],1'b0};
			mbus.req.adr <= {audi_wadr[31:3],3'h0};
			mbus.req.dat <= {4{audi_dat}};
//			tocnt <= busto;
			audi_wadr <= audi_wadr + audi_req;
			if (audi_wadr + audi_req >= audi_eadr) begin
				audi_wadr <= audi_adr + (audi_wadr + audi_req - audi_eadr);
				irq_status[12] <= 1'b1;
			end
			if (audi_wadr < (audi_eadr >> 1) &&
				(audi_wadr + audi_req >= (audi_eadr >> 1)))
				irq_status[3] <= 1'b1;
			tGoto(st_audi);
		end
		else if (hsync_det) begin
			hsync_det <= FALSE;
			hsync_ir <= ir;
			hsync_ip <= ip;
			sleep <= FALSE;
			tCall(st_hsync,st_hsync_iret);
		end
		else if (vsync_det) begin
			vsync_det <= FALSE;
			sleep <= FALSE;
			stack[(sp+15) % 16] <= {2'b01,ip,r8,r7,r6,r5,r4,r3,r2,r1};
			sp <= sp - 1;
			wait_active <= FALSE;
			if (sleep)
				tCall(st_wakeup,st_ifetch);
			else
				tGoto(st_ifetch);
		end
		else if (|miss & paging_en) begin
			sleep <= FALSE;
			miss1 <= miss;
			miss_adr1 <= miss_adr[0];
			miss_asid1 <= miss_asid[0];
			paging_en <= FALSE;
			missack <= TRUE;
			stack[(sp+15) % 16] <= {2'b10,ip,r8,r7,r6,r5,r4,r3,r2,r1};
			sp <= sp - 1;
			wait_active <= FALSE;
			if (sleep)
				tCall(st_wakeup,st_ifetch);
			else
				tGoto(st_ifetch);
		end
		else if (tblit_active) begin
			tblit_ir <= ir;
			tblit_ip <= ip;
			tCall(tblit_state,st_tblit_iret);
		end
		else if (bltCtrlx[14]) begin
			if ((bltCtrlx[7:0] & 8'hAA)!=8'h00)
				case(blt_nch)
				2'd0:	tGoto(st_bltdma2);
				2'd1:	tGoto(st_bltdma4);
				2'd2:	tGoto(st_bltdma6);
				2'd3:	tGoto(st_bltdma8);
				endcase
			else begin // no channels are enabled
				bltCtrlx[14] <= 1'b0;
				bltCtrlx[13] <= 1'b1;
				tGoto(st_ifetch);
			end
		end
		else if (bltCtrlx[15]) begin
			bltCtrlx[15] <= 1'b0;
			bltCtrlx[14] <= 1'b1;
			bltCtrlx[13] <= 1'b0;
			bltA_wadr <= bltA_badrx;
			bltB_wadr <= bltB_badrx;
			bltC_wadr <= bltC_badrx;
			bltD_wadr <= bltD_badrx;
			bltA_wcnt <= 32'd1;
			bltB_wcnt <= 32'd1;
			bltC_wcnt <= 32'd1;
			bltD_wcnt <= 32'd1;
			bltA_dcnt <= 32'd1;
			bltB_dcnt <= 32'd1;
			bltC_dcnt <= 32'd1;
			bltA_hcnt <= 32'd1;
			bltB_hcnt <= 32'd1;
			bltC_hcnt <= 32'd1;
			bltD_hcnt <= 32'd1;
			if (bltCtrlx[1])
				blt_nch <= 2'b00;
			else if (bltCtrlx[3])
				blt_nch <= 2'b01;
			else if (bltCtrlx[5])
				blt_nch <= 2'b10;
			else if (bltCtrlx[7])
				blt_nch <= 2'b11;
			else begin
				bltCtrlx[15] <= 1'b0;
				bltCtrlx[14] <= 1'b0;
				bltCtrlx[13] <= 1'b1;
			end
			tGoto(st_ifetch);
		end
		else if (ctrl[14]) begin
//		else if (ngs != st_ifetch) begin
			tGoto(ngs);
		end
		// Command queue is read only if a previous blitter or shape draw operation
		// is complete.
		else if (!cmdq_empty) begin
			rd_cmd_fifo <= TRUE;
			tCall(st_gr_cmd,st_execute);
		end
		else if (wait_active) begin
		// WAIT
		// WAIT stops waiting when:
		// a) the scan address is greater than the specified one (if this condition is set)
		// b) an interrupt occurred
		// c) a write cycle to a specified location occurred.
		// While waiting the local memory is put in low power mode.
			case(wait_cond)
			JGEP:
				if (hpos_masked >= hpos_wait && vpos_masked >= vpos_wait && (b[48] ? gfx_que_empty_i : 1'b1)) begin
					idle <= TRUE;
					sleep <= TRUE;
					icnta <= 1;
				end
				else begin
					wait_active <= FALSE;
					tCall(st_wakeup,st_ifetch);
				end
			default:
				// Wait at address
				if (ir.Rd != 4'd0 && 
					sbus.req.cyc && sbus.req.stb && sbus.req.we &&
					sbus.req.adr[13:3]==ir.imm[14:4] && cs_copro
				) begin
					rfwr <= TRUE;
					res <= sbus.req.dat;
					wait_active <= FALSE;
					tCall(st_wakeup,st_ifetch);
				end
				else begin
					ir <= ir;
					idle <= TRUE;
					sleep <= TRUE;
					icnta <= 1;
				end
			endcase
		end
	end

st_execute:	
	begin
		tGoto(st_writeback);
		case(ir.opcode)
		// The guts of wait needs to be in the ifetch state.
		// This is just a trigger here.
		OP_WAIT:
			begin
				wait_active <= TRUE;
				wait_cond <= ir.imm[3:0];
				tGoto(st_ifetch);
			end
		OP_LOAD_CONFIG:
			begin
				tmp = a[2:0]|ir.imm[2:0];
				// Which TLB missed?
				r2 <= ptbr[tmp];
				r3 <= ptattr[tmp].pgsz;
				r4 <= ptattr[tmp].level;
				r1 <= miss_adr1[tmp];
				r5 <= miss_asid1[tmp];
				r6 <= iv_count[tmp];
			end

		// Conditional jumps
		// Conditional jumps need an exta state to allow the BRAM to be accessed
		// after the address change. So, we go to prefetch instead of ifetch but
		// only if the branch is taken. Branches thus take 2 clock cycles if not
		// taken, and 3 clock cycles if taken.
		OP_JCC:
			case(ir.Rd)
			JEQ:	if (takb) tGoto(st_prefetch); else tGoto(st_ifetch);
			JNE:	if (takb) tGoto(st_prefetch); else tGoto(st_ifetch);
			JLT:	if (takb) tGoto(st_prefetch); else tGoto(st_ifetch);
			JLE:	if (takb) tGoto(st_prefetch); else tGoto(st_ifetch);
			JGE:	if (takb) tGoto(st_prefetch); else tGoto(st_ifetch);
			JGT:	if (takb) tGoto(st_prefetch); else tGoto(st_ifetch);
			DJNE:
				begin
					// Ugh, this update must be done here.
					// We also do not want to exit through the writeback state.
					tWriteback(ir.Rs1,a-1);
					tGoto(st_prefetch);
				end
			JGEP:	if (takb) tGoto(st_prefetch); else tGoto(st_ifetch);
			JLEP:	if (takb) tGoto(st_prefetch); else tGoto(st_ifetch);
			default:	;
			endcase

		// Unconditional jumps / calls / return.
		OP_JMP:
			begin
				tGoto(st_prefetch);
				case(ir.Rd)
				4'd1:	// JSR
					begin
						stack[(sp+15) % 16] <= {2'b00,ip,r8,r7,r6,r5,r4,r3,r2,r1};
						sp <= sp - 1;
					end
				4'd2:	// RET
					begin
						case(stack[sp][529:528])
						2'b10:	begin paging_en <= TRUE; idle <= TRUE; end
						default:	;
						endcase
						if (ir.imm[0]) r1 <= stack[sp][ 63:  0];
						if (ir.imm[1]) r2 <= stack[sp][127: 64];
						if (ir.imm[2]) r3 <= stack[sp][191:128];
						if (ir.imm[3]) r4 <= stack[sp][255:192];
						if (ir.imm[4]) r5 <= stack[sp][319:256];
						if (ir.imm[5]) r6 <= stack[sp][383:320];
						if (ir.imm[6]) r7 <= stack[sp][447:384];
						if (ir.imm[7]) r8 <= stack[sp][511:448];
						sp <= sp + 1;
					end

				4'd8:	// JMP [d[Rn]]	(memory indirect)
					if (JUMP_INDIRECT) begin
						tmp = a + {{17{ir.imm[14]}},ir.imm};
						mbus.req.cyc <= tmp[31:16]!=16'h0000;
						mbus.req.stb <= tmp[31:16]!=16'h0000;
						mbus.req.we <= LOW;
						mbus.req.sel <= 8'hFF;
						mbus.req.adr <= tmp;
						roma <= tmp;
						tGoto (st_ip_load);
					end

				default:	;
				endcase
			end

		// Accelerator instructions
		// We writeback results here to trim a clock cycle off of timing.
		OP_CALC_INDEX:
			begin
				tmp = ptattr[0].pgsz - 64'd3;
				tmp = tmp[5:0] * a[2:0] + ptattr[0].pgsz;
				tWriteback(ir.Rd,miss_adr1 >> tmp);
				tGoto(st_ifetch);
			end
		OP_CALC_ADR:
			begin
				tmp = (64'd1 << ptattr[0].pgsz) - 1;	// tmp = page size mask
				tmp = b & tmp;										// tmp = PTE index masked for 1024 entries in page
				tmp = tmp << 3;										// tmp = word index
				tWriteback(ir.Rd,a|tmp);
				tGoto(st_ifetch);
			end
		OP_BUILD_ENTRY_NO:
			begin
				tmp = {56'd0,b[7:0]} << 16;					// put way into position
				tmp = tmp | (64'h1 << ir.imm[5:0]);	// set TLBE set bit
				tmp = tmp | a[15:0];								// put read_adr into position
				tWriteback(ir.Rd,tmp);
				tGoto(st_ifetch);
			end
		OP_BUILD_VPN:
			begin
				tmp = miss_adr1 >> (ptattr[0].pgsz + ptattr[0].log_te);	// VPN = miss_adr >> (LOG_PAGESIZE + TLB_ABITS)
				tmp = tmp | ({64'd0,miss_asid1} << 48);// put ASID into position
				tmp = tmp | ({64'd0,iv_count[0]} << 42);	// put count into position
				tWriteback(ir.Rd,tmp);
				tGoto(st_ifetch);
			end
		OP_FLUSH:
			begin
				flush_asid <= a[15:0];
				flush_en <= ir.imm[0];
				flush_trig1 <= {4{ir.imm[1]}};
				rfwr <= TRUE;
				tWriteback(ir.Rd,{flush_done,63'd0});
				tGoto(st_ifetch);
			end

		// Memory ops
		Qupls4_copro_pkg::OP_LOAD:
			begin
				tmp = a + {{17{ir.imm[14]}},ir.imm};
				// ToDo fix cyc/stb
				mbus.req.cyc <= tmp[31:16]!=16'h0000;
				mbus.req.stb <= tmp[31:16]!=16'h0000;
				mbus.req.we <= LOW;
				mbus.req.sel <= 8'hFF;// << {tmp[4:3],3'b0};
				mbus.req.adr <= tmp;
				roma <= tmp;
				tGoto (st_mem_load);
			end
		Qupls4_copro_pkg::OP_STORE:
			begin
				tmp = a + {{17{ir.imm[14]}},ir.imm};
				mbus.req.cyc <= tmp[31:16]!=16'h0000;
				mbus.req.stb <= tmp[31:16]!=16'h0000;
				mbus.req.we <= HIGH;
				mbus.req.sel <= 8'hFF;// << {tmp[4:3],3'b0};
				mbus.req.adr <= tmp;
				mbus.req.dat <= b;
				roma <= tmp;
				if (tmp[31:16]!=16'h0000 && tmp[31:20]!=12'h001)
				  tGoto(st_mem_store);
				else
					tGoto(st_prefetch);
			end
		OP_STOREW:
			begin
				tmp = a + {{17{ir.imm[14]}},ir.imm};
				mbus.req.cyc <= tmp[31:16]!=16'h0000;
				mbus.req.stb <= tmp[31:16]!=16'h0000;
				mbus.req.we <= HIGH;
				mbus.req.sel <= 8'h03 << {tmp[2:1],1'b0};
				mbus.req.adr <= tmp;
				mbus.req.dat <= {4{b[15:0]}};
				roma <= tmp;
				if (tmp[31:16]!=16'h0000 && tmp[31:20]!=12'h001)
				  tGoto(st_mem_store);
				else
					tGoto(st_prefetch);
			end
		OP_STOREI:
			begin
				tmp = a + {{17{ir.imm[14]}},ir.imm};
				mbus.req.cyc <= tmp[31:16]!=16'h0000;
				mbus.req.stb <= tmp[31:16]!=16'h0000;
				mbus.req.we <= HIGH;
				mbus.req.sel <= 8'hFF;// << {tmp[4:3],3'b0};
				mbus.req.adr <= tmp;
				mbus.req.dat <= {4{60'd0,ir.Rd}};
				roma <= tmp;
				if (tmp[31:16]!=16'h0000 && tmp[31:20]!=12'h001)
				  tGoto(st_mem_store);
				else
					tGoto(st_prefetch);
			end
		OP_STOREI64:
			begin
				// Was instruction at an odd address?
				if (~ipr[2] & UNALIGNED_CONSTANTS)
					tGoto(st_even64);
				else
					tGoto(st_odd64);
			end
		OP_BMP:
			begin
				tmp = (a >> 4'd6) + {{17{ir.imm[14]}},ir.imm};
				mbus.req.cyc <= tmp[31:16]!=16'h0000;
				mbus.req.stb <= tmp[31:16]!=16'h0000;
				mbus.req.we <= LOW;
				mbus.req.sel <= 8'hFF;// << {tmp[4:3],3'b0};
				mbus.req.adr <= tmp;
				roma <= tmp;
				tGoto (st_mem_load);
			end

		// ALU ops
		// ALU ops also writeback here to trim a cycle from timing.
		OP_SHL: begin tWriteback(ir.Rd, a << (b[4:0]+ir.imm[4:0])); tGoto(st_ifetch); end
		OP_SHR:	begin tWriteback(ir.Rd, a >> (b[4:0]+ir.imm[4:0])); tGoto(st_ifetch); end
		OP_ADD: begin tWriteback(ir.Rd, a + b + {{17{ir.imm[14]}},ir.imm}); tGoto(st_ifetch); end
		OP_ADD64,OP_AND64:
			begin
				// Was instruction at an odd address?
				if (~ipr[2] & UNALIGNED_CONSTANTS)
					tGoto(st_even64);
				else
					tGoto(st_odd64);
			end
		OP_AND: begin tWriteback(ir.Rd, a & b & {{17{ir.imm[14]}},ir.imm}); tGoto(st_ifetch); end
		OP_OR:	begin tWriteback(ir.Rd, a | b | {{17{ir.imm[14]}},ir.imm}); tGoto(st_ifetch); end
		OP_XOR:	begin tWriteback(ir.Rd, a ^ b ^ {{17{ir.imm[14]}},ir.imm}); tGoto(st_ifetch); end
		default:;
		endcase
	end

// This state will be stripped out unless unaligned constants are allowed.
st_even64:
	begin
		imm <= douta[63:32];
		tGoto(st_even64a);
	end
st_even64a:
	begin
		tGoto(st_writeback);
		case(ir.opcode)
		OP_ADD64:	begin rfwr <= TRUE; res <= a + b + {douta[31:0],imm}; end
		OP_AND64:	begin rfwr <= TRUE; res <= a & b & {douta[31:0],imm}; end
		OP_STOREI:
			begin
				tmp = a + {{17{ir.imm[14]}},ir.imm};
				mbus.req.cyc <= tmp[31:16]!=16'h0000;
				mbus.req.stb <= tmp[31:16]!=16'h0000;
				mbus.req.we <= HIGH;
				mbus.req.sel <= 8'hFF;// << {tmp[4:3],3'b0};
				mbus.req.adr <= tmp;
				mbus.req.dat <= {4{douta[31:0],imm}};
				if (tmp[31:16]!=16'h0000 && tmp[31:20]!=12'h001)
					tGoto(st_mem_store);
				else
					tGoto(st_prefetch);
			end
		default:	;
		endcase
	end

st_odd64:
	begin
		tGoto(st_odd64a);
	end
st_odd64a:
	begin
		tGoto(st_writeback);
		case(ir.opcode)
		OP_ADD64:	begin rfwr <= TRUE; res <= a + b + douta; end
		OP_AND64:	begin rfwr <= TRUE; res <= a & b & douta; end
		OP_STOREI:
			begin
				tmp = a + {{17{ir.imm[14]}},ir.imm};
				mbus.req.cyc <= tmp[31:16]!=16'h0000;
				mbus.req.stb <= tmp[31:16]!=16'h0000;
				mbus.req.we <= HIGH;
				mbus.req.sel <= 8'hFF;// << {tmp[4:3],3'b0};
				mbus.req.adr <= tmp;
				mbus.req.dat <= douta;
				if (tmp[31:16]!=16'h0000 && tmp[31:20]!=12'h001)
					tGoto(st_mem_store);
				else
					tGoto(st_prefetch);
			end
		default:	;
		endcase
	end
st_writeback:
	begin
		if (rfwr)
			tWriteback(ir.Rd,res);
		rfwr <= FALSE;
		tGoto(st_ifetch);
	end
st_prefetch:
	begin
		mbus.req <= {$bits(wb_cmd_request64_t){1'b0}};
		tGoto(st_ifetch);
	end

// Wakeup stages for the BRAM after a WAIT operation.
st_wakeup:
	begin
		idle <= FALSE;
		tGoto(st_wakeup2);
	end
st_wakeup2:
	tRet();
st_jmp:
	tGoto(st_writeback);

// Memory states
st_ip_load:
	begin
		local_sel <= mbus.req.adr[31:16]==16'h0000;
		tocnt <= tocnt - 1;
		if (imresp.ack||tocnt==0) begin
			tocnt <= busto;
			local_sel <= FALSE;
			mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
			tGoto (st_jmp);
		end
	end

st_mem_load:
	begin
		local_sel <= mbus.req.adr[31:16]==16'h0000;
		tocnt <= tocnt - 1;
		if (imresp.ack||tocnt==0) begin
			tocnt <= busto;
			local_sel <= FALSE;
			tGoto (st_writeback);
			mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
			case(ir.opcode)
			OP_BMP:
				case(ir.Rs2)
				4'd0:	// BMCLR
					begin
						if (mbus.req.adr[31:16]==16'h0000) begin
							casez(roma[14:3])
							12'hF??:	
								begin
									mem_val <= arg_dat & ~(64'd1 << mbus.req.adr[5:0]);
						  		rfwr <= TRUE;
									res <= arg_dat >> mbus.req.adr[5:0] & 64'd1;
									tGoto(st_bit_store);
								end
						  default:
						  	begin
						  		mem_val <= douta & ~(64'd1 << mbus.req.adr[5:0]);
						  		rfwr <= TRUE;
						  		res <= mbus.req.adr[5:0] & 64'd1;
									tGoto(st_bit_store);
						  	end
							endcase
						end
						else begin
							mem_val <= imresp.dat & ~(64'd1 << mbus.req.adr[5:0]);
							res <= imresp.dat >> mbus.req.adr[5:0] & 64'd1;
							tGoto(st_bit_store);
						end
					end
				4'd1:	// BMSET
					begin
						if (mbus.req.adr[31:16]==16'h0000) begin
							casez(roma[14:3])
							12'hF??:	
								begin
									mem_val <= arg_dat | (64'd1 << mbus.req.adr[5:0]);
						  		rfwr <= TRUE;
									res <= arg_dat >> mbus.req.adr[5:0] & 64'd1;
									tGoto(st_bit_store);
								end
						  default:
						  	begin
						  		mem_val <= douta | (64'd1 << mbus.req.adr[5:0]);
						  		rfwr <= TRUE;
						  		res <= mbus.req.adr[5:0] & 64'd1;
									tGoto(st_bit_store);
						  	end
							endcase
						end
						else begin
							mem_val <= imresp.dat | (64'd1 << mbus.req.adr[5:0]);
							res <= imresp.dat >> mbus.req.adr[5:0] & 64'd1;
							tGoto(st_bit_store);
						end
					end
				4'd2:	// BMTST
					begin
						if (mbus.req.adr[31:16]==16'h0000) begin
							casez(roma[14:3])
							12'hF??:	
								begin
									mem_val <= arg_dat | (64'd1 << mbus.req.adr[5:0]);
						  		rfwr <= TRUE;
									res <= arg_dat >> mbus.req.adr[5:0] & 64'd1;
								end
						  default:
						  	begin
						  		mem_val <= douta | (64'd1 << mbus.req.adr[5:0]);
						  		rfwr <= TRUE;
						  		res <= mbus.req.adr[5:0] & 64'd1;
						  	end
							endcase
						end
						else begin
							mem_val <= imresp.dat | (64'd1 << mbus.req.adr[5:0]);
							res <= imresp.dat >> mbus.req.adr[5:0] & 64'd1;
						end
					end
				4'd3:	// BMCHG
					begin
						if (mbus.req.adr[31:16]==16'h0000) begin
							casez(roma[14:3])
							12'hF??:	
								begin
									mem_val <= arg_dat ^ (64'd1 << mbus.req.adr[5:0]);
						  		rfwr <= TRUE;
									res <= arg_dat >> mbus.req.adr[5:0] & 64'd1;
									tGoto(st_bit_store);
								end
						  default:
						  	begin
						  		mem_val <= douta ^ (64'd1 << mbus.req.adr[5:0]);
						  		rfwr <= TRUE;
						  		res <= mbus.req.adr[5:0] & 64'd1;
									tGoto(st_bit_store);
						  	end
							endcase
						end
						else begin
							mem_val <= imresp.dat ^ (64'd1 << mbus.req.adr[5:0]);
							res <= imresp.dat >> mbus.req.adr[5:0] & 64'd1;
							tGoto(st_bit_store);
						end
					end
				default:	tGoto(st_ifetch);
				endcase
			default:
				if (mbus.req.adr[31:16]==16'h0000) begin
					casez(roma[14:3])
					12'hF??:	begin rfwr <= TRUE; res <= arg_dat; end
				  default:	begin rfwr <= TRUE; res <= douta; end
					endcase
				end
				else begin
					rfwr <= TRUE;
				  res <= imresp.dat;
				end
			endcase
		end
	end
	
st_bit_store:
	if (!imresp.ack) begin
		tmp = (a >> 4'd6) + {{17{ir.imm[14]}},ir.imm};
		local_sel <= tmp[31:20] <= 12'h001;
		mbus.req.cyc <= HIGH;
		mbus.req.stb <= HIGH;
		mbus.req.we <= HIGH;
		mbus.req.sel <= 8'hFF;// << {tmp[4:3],3'b0};
		mbus.req.adr <= tmp;
		mbus.req.dat <= {4{mem_val}};
		if (tmp[31:0]==32'h00007ff8) begin
			page_fault <= mem_val[0];
			cmd_done <= mem_val[1];
		end
		roma <= tmp;
		if (tmp[31:20]>12'h001)
		  tGoto(st_mem_store);
		else
			tGoto(st_prefetch);
	end

st_mem_store:
	begin
		tocnt <= tocnt - 1;
		local_sel <= mbus.req.adr[31:16]==16'h0000;
		if (imresp.ack||cmdq_wr_ack||tocnt==0) begin
			tocnt <= busto;
			local_sel <= FALSE;
			mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
			tGoto (st_writeback);
		end
	end

st_aud0:
	if (~imresp.ack) begin
		wr_aud0 <= TRUE;
		tRet();
	end
st_aud1:
	if (~imresp.ack) begin
		wr_aud1 <= TRUE;
		tRet();
	end
st_aud2:
	if (~imresp.ack) begin
		wr_aud2 <= TRUE;
		tRet();
	end
st_aud3:
	if (~imresp.ack) begin
		wr_aud3 <= TRUE;
		tRet();
	end
st_audi:
	begin
		tocnt <= tocnt - 8'd1;
		if (imresp.ack||!mbus.req.cyc||tocnt==0) begin
			tocnt <= busto;
			mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
			tRet();
		end
	end

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

st_gr_cmd:
	begin
	   rd_cmd_fifo <= FALSE;
/*		if (!cmdq_valid) begin
			$display("Command not valid.");
			tRet();
		end
		else
*/		begin
				ctrl[7:0] <= cmdq_out[39:32];
//		ctrl[14] <= 1'b0;
		case(cmdq_out[39:32])
		8'd0:	begin
				$display("Text blitting");
				tblit_active <= TRUE;
				charcode <= cmdq_out[15:0];
				tblit_state <= st_read_font_tbl;	// draw character
				tRet();
				end
		8'd1:	begin
				$display("Point plot");
				ctrl[11:8] <= cmdq_out[7:4];	// raster op
				tGoto(st_plot);
				end
		8'd2:	begin
				ctrl[11:8] <= cmdq_out[7:4];	// raster op
				tGoto(st_dl_precalc);				// draw line
				end
		8'd3:	begin
				ctrl[11:8] <= cmdq_out[7:4];	// raster op
				tGoto(st_fillrect);
				end
/*
		8'd4:	begin
				wrtx <= 1'b1;
				hwTexture <= cmdq_out[`TXHANDLE];
				state <= ST_IDLE;
				end
		8'd5:	begin
				hrTexture <= cmdq_out[`TXHANDLE];
				ctrl[11:8] <= cmdq_out[7:4];	// raster op
				state <= ST_TILERECT;
				end
*/
		8'd6:	begin	// Draw triangle
				ctrl[11:8] <= cmdq_out[7:4];	// raster op
				tGoto(st_dt_start);
				end
`ifdef BEZIER_CURVE
		8'd8:	begin	// Bezier Curve
				ctrl[11:8] <= cmdq_out[7:4];	// raster op
				fillCurve <= cmdq_out[1:0];
				tGoto(st_bc0);
				end
`else
		8'd8:	tRet();
`endif
`ifdef FLOOD_FILL
		8'd9:	tGoto(st_ff1);
`else
		8'd9:	tRet();
`endif
/*
		8'd11:	transform <= cmdq_out[0];
*/
		8'd12:	begin pen_color <= cmdq_out[`CMDDAT]; tRet(); end
		8'd13:	begin fill_color <= cmdq_out[`CMDDAT]; tRet(); end
		8'd14:	begin alpha <= cmdq_out[`CMDDAT]; tRet(); end
		8'd16:	begin up0x <= cmdq_out[`CMDDAT]; tRet(); end
		8'd17:	begin up0y <= cmdq_out[`CMDDAT]; tRet(); end
		8'd18:	begin up0z <= cmdq_out[`CMDDAT]; tRet(); end
		8'd19:	begin up1x <= cmdq_out[`CMDDAT]; tRet(); end
		8'd20:	begin up1y <= cmdq_out[`CMDDAT]; tRet(); end
		8'd21:	begin up1z <= cmdq_out[`CMDDAT]; tRet(); end
		8'd22:	begin up2x <= cmdq_out[`CMDDAT]; tRet(); end
		8'd23:	begin up2y <= cmdq_out[`CMDDAT]; tRet(); end
		8'd24:	begin up2z <= cmdq_out[`CMDDAT]; tRet(); end
		
		8'd25:	begin clipX0 <= cmdq_out[15:0]; tRet(); end
		8'd26:	begin clipY0 <= cmdq_out[15:0]; tRet(); end
		8'd27:	begin clipX1 <= cmdq_out[15:0]; tRet(); end
		8'd28:	begin clipY1 <= cmdq_out[15:0]; tRet(); end
		8'd29:	begin clipEnable <= cmdq_out[0]; tRet(); end

		8'd32:	begin aa <= cmdq_out[`CMDDAT]; tRet(); end
		8'd33:	begin ab <= cmdq_out[`CMDDAT]; tRet(); end
		8'd34:	begin ac <= cmdq_out[`CMDDAT]; tRet(); end
		8'd35:	begin at <= cmdq_out[`CMDDAT]; tRet(); end
		8'd36:	begin ba <= cmdq_out[`CMDDAT]; tRet(); end
		8'd37:	begin bb <= cmdq_out[`CMDDAT]; tRet(); end
		8'd38:	begin bc <= cmdq_out[`CMDDAT]; tRet(); end
		8'd39:	begin bt <= cmdq_out[`CMDDAT]; tRet(); end
		8'd40:	begin ca <= cmdq_out[`CMDDAT]; tRet(); end
		8'd41:	begin cb <= cmdq_out[`CMDDAT]; tRet(); end
		8'd42:	begin cc <= cmdq_out[`CMDDAT]; tRet(); end
		8'd43:	begin ct <= cmdq_out[`CMDDAT]; tRet(); end

		8'd44:	begin font_tbl_adr <= cmdq_out[`CMDDAT]; tRet(); end
		8'd45:	begin font_id <= cmdq_out[`CMDDAT]; tRet(); end

		8'd254:	begin rst_cmdq <= TRUE; tRet(); end
		8'd255:	tRet();	// NOP
		default:	tRet();
		endcase
		end
	end

// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// Character draw acceleration states
//
// Font Table - An entry for each font
// fwwwwwhhhhh-aaaa		- width and height
// aaaaaaaaaaaaaaaa		- char bitmap address
// ------------aaaa		- address offset of gylph width table
// aaaaaaaaaaaaaaaa		- low order address offset bits
//
// 10100001000-aaaa_aaaaaaaaaaaaaaaa_------------aaaaaaaaaaaaaaaaaaaa
// A1008008
//
// Glyph Table Entry
// ---wwwww---wwwww		- width
// ---wwwww---wwwww
// ---wwwww---wwwww
// ---wwwww---wwwww
// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

st_read_font_tbl:
	begin
		pixhc <= 6'd0;
		pixvc <= 6'd0;
		charBoxX0 <= p0x;
		charBoxY0 <= p0y;
		local_sel <= TRUE;
    mbus.req.cyc <= HIGH;
    mbus.req.stb <= HIGH;
    mbus.req.sel <= 8'hFF;
		mbus.req.adr <= {font_tbl_adr[31:3],3'b0} + {font_id,4'b00};
		tocnt <= busto;
		tblit_adr <= {font_tbl_adr[31:3],3'b0} + {font_id,4'b00};
		tCall(st_latch_data,st_read_font_tbl_nack);
	end
st_read_font_tbl_nack:
	if (~imresp.ack) begin
		charBmpBase <= latched_data[63:32];
		glyph_tbl_adr <= latched_data[31:0];
		tblit_state <= st_read_font_tbl2;
		tRet();
	end
st_read_font_tbl2:
	begin
		pixhc <= 6'd0;
		pixvc <= 6'd0;
		local_sel <= TRUE;
    mbus.req.cyc <= HIGH;
    mbus.req.stb <= HIGH;
    mbus.req.sel <= 8'hFF;
		mbus.req.adr <= {font_tbl_adr[31:3],3'b0} + {font_id,4'b00} + 8'd8;
		tocnt <= busto;
		tblit_adr <= {font_tbl_adr[31:3],3'b0} + {font_id,4'b00} + 8'd8;
		tCall(st_latch_data,st_read_font_tbl2_nack);
	end
st_read_font_tbl2_nack:
	if (~imresp.ack) begin
		font_fixed <= latched_data[63];
		font_width <= latched_data[61:56];
		font_height <= latched_data[53:48];
		tblit_state <= st_read_glyph_entry;
		tRet();
	end
st_read_glyph_entry:
	begin
		charBmpBase <= charBmpBase + charndx;
		if (font_fixed) begin
			tblit_state <= st_read_char_bitmap;
			tRet();
		end
		else begin
			local_sel <= TRUE;
			mbus.req.cyc <= HIGH;
		  mbus.req.sel <= 8'hFF;
			mbus.req.adr <= {glyph_tbl_adr[31:3],3'h0} + {charcode[8:3],3'h0};
			tocnt <= busto;
			tCall(st_latch_data,st_read_glyph_entry_nack);
		end
	end
st_read_glyph_entry_nack:
	if (~imresp.ack) begin
		font_width <= latched_data >> {charcode[2:0],3'b0};
		tblit_state <= st_read_char_bitmap;
		tRet();
	end
st_read_char_bitmap:
	begin
		local_sel <= TRUE;
		mbus.req.cyc <= HIGH;
	  mbus.req.sel <= 8'hFF;
		mbus.req.adr <= charBmpBase + (16'(pixvc) << font_width[4:3]);
		tocnt <= busto;
		tCall(st_latch_data,st_read_char_bitmap_nack);
	end
st_read_char_bitmap_nack:
	if (~imresp.ack) begin
		case(font_width[4:3])
		2'd0:	charbmp <= (latched_data >> {mbus.req.adr[2:0],3'b0}) & 32'h0ff;
		2'd1:	charbmp <= (latched_data >> {mbus.req.adr[2:1],4'b0}) & 32'h0ffff;
		2'd2:	charbmp <= latched_data >> {mbus.req.adr[2],5'b0} & 32'hffffffff;
		2'd3:	charbmp <= latched_data;
		endcase
		tgtaddr <= fixToInt(charBoxY0) * {TargetWidth,1'b0} + TargetBase + {fixToInt(charBoxX0),1'b0};
		tgtindex <= {TargetWidth,1'b0} * pixvc + {pixhc,1'b0};
		tblit_state <= fill_color[31] ? st_read_char : st_write_char;
		tRet();
	end
st_read_char:
	begin
		tgtadr <= tgtaddr + tgtindex;
		tGoto(st_read_char2);
	end
st_read_char2:
	begin
		local_sel <= TRUE;
		mbus.req.cyc <= HIGH;
		mbus.req.stb <= HIGH;
		mbus.req.we <= LOW;
		mbus.req.sel <= 8'd3 << {tgtadr[2:1],1'b0};
		mbus.req.adr <= tgtadr;
		mbus.req.dat <= 64'd0;
		tocnt <= busto;
		tCall(st_latch_data,st_write_char);
	end
st_write_char:
	begin
		latched_data <= latched_data >> {tgtadr[2:1],4'b0};
		tGoto(st_write_char1);
	end
st_write_char1:
	begin
		tgtadr <= tgtaddr + tgtindex;
		tGoto(st_write_char2);
	end
st_write_char2:
	begin
		if (~fill_color[`A]) begin
			if ((clipEnable && (fixToInt(charBoxX0) + pixhc < clipX0) || (fixToInt(charBoxX0) + pixhc >= clipX1) || (fixToInt(charBoxY0) + pixvc < clipY0)))
				;
			else if (fixToInt(charBoxX0) + pixhc >= TargetWidth)
				;
			else begin
				local_sel <= TRUE;
				mbus.req.cyc <= HIGH;
				mbus.req.stb <= HIGH;
				mbus.req.we <= HIGH;
				mbus.req.sel <= 8'd3 << {tgtadr[2:1],1'b0};
				mbus.req.adr <= tgtadr;
				mbus.req.dat <= {4{charbmp[0] ? pen_color[15:0] :
					fill_color[31] ? latched_data[15:0] :
					fill_color[15:0]}};
				tocnt <= busto;
			end
		end
		else begin
			if (charbmp[0]) begin
				if (zbuf) begin
					if (clipEnable && (fixToInt(charBoxX0) + pixhc < clipX0 || fixToInt(charBoxX0) + pixhc >= clipX1 || fixToInt(charBoxY0) + pixvc < clipY0))
						;
					else if (fixToInt(charBoxX0) + pixhc >= TargetWidth)
						;
					else begin
						local_sel <= TRUE;
						mbus.req.cyc <= HIGH;
						mbus.req.stb <= HIGH;
						mbus.req.sel <= 8'd3 << {tgtadr[2:1],1'b0};
/*
						mbus.req.we <= HIGH;
						mbus.req.adr <= tgtadr;
						mbus.req.dat <= {32{zlayer}};
*/				
						tocnt <= busto;
					end
				end
				else begin
					if (clipEnable && (fixToInt(charBoxX0) + pixhc < clipX0 || fixToInt(charBoxX0) + pixhc >= clipX1 || fixToInt(charBoxY0) + pixvc < clipY0))
						;
					else if (fixToInt(charBoxX0) + pixhc >= TargetWidth)
						;
					else begin
						local_sel <= TRUE;
						mbus.req.cyc <= HIGH;
						mbus.req.stb <= HIGH;
						mbus.req.sel <= 8'd3 << {tgtadr[2:1],1'b0};
						mbus.req.we <= HIGH;
						mbus.req.adr <= tgtadr;
						mbus.req.dat <= {4{pen_color[15:0]}};
						tocnt <= busto;
					end
				end
			end
		end
		charbmp <= {1'b0,charbmp[63:1]};
		pixhc <= pixhc + 6'd1;
		if (pixhc==font_width) begin
			tblit_state <= st_read_char_bitmap;
	    pixhc <= 6'd0;
	    pixvc <= pixvc + 6'd1;
			tgtindex <= ({TargetWidth,1'b0}) * (pixvc + 6'd1);
	    if (clipEnable && (fixToInt(charBoxY0) + pixvc + 16'd1 >= clipY1))
	    	tblit_active <= FALSE;
	    else if (fixToInt(charBoxY0) + pixvc + 16'd1 >= TargetHeight)
	    	tblit_active <= FALSE;
	    else if (pixvc==font_height)
	    	tblit_active <= FALSE;
		end
		else begin
			tblit_state <= fill_color[31] ? st_read_char : st_write_char;
			tgtindex <= {TargetWidth,1'b0} * pixvc + {pixhc+6'd1,1'b0};
		end
		tCall(st_wait_ack,st_write_char2_nack);
	end
st_write_char2_nack:
	if (~imresp.ack) begin
		if (!tblit_active)
			tblit_state <= st_ifetch;
		tRet();
	end

// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// Pixel plot acceleration states
// For binary raster operations a back-to-back read then write is performed.
// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

st_plot:
	begin
		gcx <= fixToInt(p0x);
		gcy <= fixToInt(p0y);
		if (IsBinaryROP(ctrl[11:8]))
			tCall(st_delay3,st_plot_read);
		else
			tCall(st_delay3,st_plot_write);
	end
st_plot_read:
	begin
		local_sel <= TRUE;
		mbus.req.cyc <= HIGH;
		mbus.req.stb <= HIGH;
		mbus.req.sel <= 8'hFF;
		mbus.req.adr <= ma;
		// The memory address doesn't change from read to write so
		// there's no need to wait for it to update, it's already
		// correct.
		tCall(st_latch_data,st_plot_write);
	end
st_plot_write:
	begin
		tGoto(st_wait_ack);
		t_set_pixel(pen_color[15:0],alpha,ctrl[11:8]);
	end

st_wait_ack:
	begin
		tocnt <= tocnt - 1;
		// If setpixel avoided the bus transaction cyc and stb will not be present.
		if (imresp.ack || !(mbus.req.cyc & mbus.req.stb) || tocnt==8'd0) begin
			tocnt <= busto;
			local_sel <= FALSE;
			mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
			tGoto(st_delay1);
		end
	end

// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// Draw horizontal line
// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

// Swap the x-coordinate so that the line is always drawn left to right.
st_hl_line:
	begin
		if (curx0 <= curx1) begin
  		gcx <= fixToInt(curx0);
  		endx <= curx1;
  	end
  	else begin
	    gcx <= fixToInt(curx1);
	    endx <= curx0;
  	end
		if (IsBinaryROP(ctrl[11:8]))
      tCall(st_delay2,st_hl_getpixel);
    else
      tCall(st_delay2,st_hl_setpixel);
	end
st_hl_getpixel:
  begin
  	mbus.req.cyc <= HIGH;
  	mbus.req.stb <= HIGH;
    mbus.req.sel <= 8'h03 << {ma[2:1],1'b0};
    mbus.req.adr <= ma;
    tCall(st_latch_data,st_hl_getpixel_nack);
  end
st_hl_getpixel_nack:
	if (~mbus.resp.ack|local_sel)
		tGoto(st_hl_setpixel);
st_hl_setpixel:
	begin
		t_set_pixel(fill_color,0,ctrl[11:8]);
		gcx <= gcx + 16'd1;
		tCall(st_wait_ack,st_hl_setpixel_nack);
	end
st_hl_setpixel_nack:
	if (~mbus.resp.ack|local_sel) begin
		if (gcx>=fixToInt(endx)) begin
			ngs <= st_ifetch;
			tRet();
		end
		else begin
      if (IsBinaryROP(ctrl[11:8]))
        tPause(st_hl_getpixel);
      else
      	tPause(st_hl_setpixel);
		end
	end

// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// Draw a filled rectangle, uses the blitter.
// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

st_fillrect:
	begin
		// Switching the points around will have the side effect
		// of switching the transformed points around as well.
		if (p1y < p0y) up0y <= up1y;
		if (p1x < p0x) up0x <= up1x;
		dx <= fixToInt(absx1mx0) + 16'd1;	// Order of points doesn't matter here.
		dy <= fixToInt(absy1my0) + 16'd1;
		// Wait for previous blit to finish
		// then delay 1 cycle for point switching
		if (bltCtrlx[13]||!(bltCtrlx[15]||bltCtrlx[14]))
			tCall(st_delay1,st_fillrect_clip);
		else begin
			ngs <= st_fillrect;
			tRet();
		end
	end
st_fillrect_clip:
	begin
		if (fixToInt(p0x) + dx > TargetWidth)
			dx <= TargetWidth - fixToInt(p0x);
		if (fixToInt(p0y) + dy > TargetHeight)
			dy <= TargetHeight - fixToInt(p0y);
		tGoto(st_fillrect2);
	end
st_fillrect2:
	begin
		bltD_badrx <= {8'h00,fixToInt(p0y)} * {TargetWidth,1'b0} + TargetBase + {fixToInt(p0x),1'b0};
		bltD_modx <= {TargetWidth - dx,1'b0};
		bltD_cntx <= dx * dy;
		bltDstWidx <= dx;
		bltD_datx <= {4{fill_color[15:0]}};
		bltCtrlx[15:0] <= 16'h8080;
		ngs <= st_ifetch;
		tRet();
	end

// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// Filled Triangle drawing
// Uses the standard method for drawing filled triangles.
// Requires some fixed point math and division / multiplication.
// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

// Save off the original set of points defining the triangle. The points are
// manipulated later by the anti-aliasing outline draw.

st_dt_start:								// allows p?? to update
  begin
    up0xs <= up0x;
    up0ys <= up0y;
    up0zs <= up0z;
    up1xs <= up1x;
    up1ys <= up1y;
    up1zs <= up1z;
    up2xs <= up2x;
    up2ys <= up2y;
    up2zs <= up2z;
		tGoto(st_dt_sort);
	end

// First step - sort vertices
// Sort points in order of Y coordinate. Also find the minimum and maximum
// extent of the triangle.
st_dt_sort:
	begin
		ctrl[14] <= 1'b1;				// set busy indicator
		// Just draw a horizontal line if all vertices have the same y co-ord.
		if (p0y == p1y && p0y == p2y) begin
		   if (p0x < p1x && p0x < p2x)
		       curx0 <= p0x;
		   else if (p1x < p2x)
		       curx0 <= p1x;
		   else
		       curx0 <= p2x;
		   if (p0x > p1x && p0x > p2x)
		       curx1 <= p0x;
		   else if (p1x > p2x)
		       curx1 <= p1x;
		   else
		       curx1 <= p2x;
		   gcy <= fixToInt(p0y);
       tGoto(st_hl_line);
		end
		else if (p0y <= p1y && p0y <= p2y) begin
		  minY <= p0y;
			v0x <= p0x;
			v0y <= p0y;
			if (p1y <= p2y) begin
				v1x <= p1x;
				v1y <= p1y;
				v2x <= p2x;
				v2y <= p2y;
				maxY <= p2y;
			end
			else begin
				v1x <= p2x;
				v1y <= p2y;
				v2x <= p1x;
				v2y <= p1y;
				maxY <= p1y;
			end
		end
		else if (p1y <= p2y) begin
		  minY <= p1y;
			v0y <= p1y;
			v0x <= p1x;
			if (p0y <= p2y) begin
				v1y <= p0y;
				v1x <= p0x;
				v2y <= p2y;
				v2x <= p2x;
				maxY <= p2y;
			end
			else begin
				v1y <= p2y;
				v1x <= p2x;
				v2y <= p0y;
				v2x <= p0x;
				maxY <= p0y;
			end
		end
		// y2 < y0 && y2 < y1
		else begin
			v0y <= p2y;
			v0x <= p2x;
			minY <= p2y;
			if (p0y <= p1y) begin
				v1y <= p0y;
				v1x <= p0x;
				v2y <= p1y;
				v2x <= p1x;
				maxY <= p1y;
			end
			else begin
				v1y <= p1y;
				v1x <= p1x;
				v2y <= p0y;
				v2x <= p0x;
				maxY <= p0y;
			end
		end
		// Determine minium and maximum X coord.
		if (p0x <= p1x && p0x <= p2x) begin
		    minX <= p0x;
		    if (p1x <= p2x)
		        maxX <= p2x;
		    else
		        maxX <= p1x;
		end
		else if (p1x <= p2x) begin
		    minX <= p1x;
		    if (p0x <= p2x)
		        maxX <= p2x;
		    else
		        maxX <= p0x;
		end
		else begin
		    minX <= p2x;
		    if (p0x < p1x)
		        maxX <= p1x;
		    else
		        maxX <= p0x;
		end
		    
		tGoto(st_dt1);
	end

// Flat bottom (FB) or flat top (FT) triangle drawing
// Calc inv slopes
st_dt_slope1:
	begin
		div_ld <= TRUE;
		if (fbt) begin
			div_a <= w1x - w0x;
			div_b <= w1y - w0y;
		end
		else begin
			div_a <= w2x - w0x;
			div_b <= w2y - w0y;
		end
		tPause(st_dt_slope1a);
	end
st_dt_slope1a:
	if (div_idle) begin
		invslope0 <= div_qo[31:0];
		if (fbt) begin
			div_a <= w2x - w0x;
			div_b <= w2y - w0y;
		end
		else begin
			div_a <= w2x - w1x;
			div_b <= w2y - w1y;
		end
		div_ld <= TRUE;
		tPause(st_dt_slope2);
	end
st_dt_slope2:
	if (div_idle) begin
		invslope1 <= div_qo[31:0];
	    if (fbt) begin
		    curx0 <= w0x;
	   	    curx1 <= w0x;
			gcy <= fixToInt(w0y);
			tCall(st_hl_line,st_dt_incy);
		end
		else begin
		    curx0 <= w2x;
	        curx1 <= w2x;
	        gcy <= fixToInt(w2y);
			tCall(st_hl_line,st_dt_incy);
		end
	end
st_dt_incy:
	begin
		if (fbt) begin
		    if (curx0 + invslope0 < minX)
		        curx0 <= minX;
		    else if (curx0 + invslope0 > maxX)
		        curx0 <= maxX;
		    else
			    curx0 <= curx0 + invslope0;
			if (curx1 + invslope1 < minX)
			    curx1 <= minX;
			else if (curx1 + invslope1 > maxX)
			    curx1 <= maxX;
			else
			    curx1 <= curx1 + invslope1;
			gcy <= gcy + 16'd1;
			if (gcy>=fixToInt(w1y))
				tRet();
			else
				tCall(st_hl_line,st_dt_incy);
		end
		else begin
	    if (curx0 - invslope0 < minX)
        curx0 <= minX;
      else if (curx0 - invslope0 > maxX)
        curx0 <= maxX;
      else
        curx0 <= curx0 - invslope0;
      if (curx1 - invslope1 < minX)
        curx1 <= minX;
      else if (curx1 - invslope1 > maxX)
        curx1 <= maxX;
      else
        curx1 <= curx1 - invslope1;
			gcy <= gcy - 16'd1;
			if (gcy<fixToInt(w0y))
				tRet();
			else
				tCall(st_hl_line,st_dt_incy);
		end
	end

st_dt1:
	begin
		// Simple case of flat bottom
		if (v1y==v2y) begin
			fbt <= 1'b1;
			w0x <= v0x;
			w0y <= v0y;
			w1x <= v1x;
			w1y <= v1y;
			w2x <= v2x;
			w2y <= v2y;
			tCall(st_dt_slope1,st_dt6);
		end
		// Simple case of flat top
		else if (v0y==v1y) begin
			fbt <= 1'b0;
			w0x <= v0x;
			w0y <= v0y;
			w1x <= v1x;
			w1y <= v1y;
			w2x <= v2x;
			w2y <= v2y;
			tCall(st_dt_slope1,st_dt6);
		end
		// Need to calculte 4th vertice
		else begin
			div_ld <= TRUE;
			div_a <= v1y - v0y;
			div_b <= v2y - v0y;
			tPause(st_dt2);
		end
	end
st_dt2:
	if (div_idle) begin
		trimd <= 8'b11111111;
		v3y <= v1y;
		tGoto(st_dt3);
	end
st_dt3:
	begin
		trimd <= {trimd[6:0],1'b0};
		if (trimd==8'h00) begin
			v3x <= v0x + trimult[47:16];
			v3x[15:0] <= 16'h0000;
			tGoto(st_dt4);
		end
	end
st_dt4:
	begin
		fbt <= 1'b1;
		w0x <= v0x;
		w0y <= v0y;
		w1x <= v1x;
		w1y <= v1y;
		w2x <= v3x;
		w2y <= v3y;
		tCall(st_dt_slope1,st_dt5);
	end
st_dt5:
	begin
		fbt <= 1'b0;
		w0x <= v1x;
		w0y <= v1y;
		w1x <= v3x;
		w1y <= v3y;
		w2x <= v2x;
		w2y <= v2y;
		tCall(st_dt_slope1,st_dt6);
	end
st_dt6:
	begin
		ngs <= st_ifetch;
		if (retstacko==st_ifetch) begin
      ctrl[14] <= 1'b0;
      tRet();
	    //tGoto(DT7);
		end
		else
	    tRet();
	end

// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// Blitter DMA
// Blitter has four DMA channels, three source channels and one destination
// channel.
// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

	// Blit channel A
st_bltdma2:
	begin
	  mbus.req.cyc <= HIGH;
	  mbus.req.stb <= HIGH;
		mbus.req.adr <= bltA_wadr;
		bltinc <= bltCtrlx[8] ? -32'(bltA_inc) : bltA_inc;
		tCall(st_latch_data,st_bltdma2_nack);
    end
st_bltdma2_nack:
	if (~mbus.resp.ack) begin
		bltA_datx <= latched_data >> {bltA_wadr[2:1],4'h0};
		bltA_wadr <= bltA_wadr + bltinc;
    bltA_hcnt <= bltA_hcnt + 32'd1;
    if (bltA_hcnt==bltSrcWid) begin
	    bltA_hcnt <= 32'd1;
	    bltA_wadr <= bltA_wadr + {bltA_modx[31:1],1'b0} + bltinc;
		end
    bltA_wcnt <= bltA_wcnt + 32'd1;
    bltA_dcnt <= bltA_dcnt + 32'd1;
    if (bltA_wcnt>=bltA_cntx) begin
      bltA_wadr <= bltA_badrx;
      bltA_wcnt <= 32'd1;
      bltA_hcnt <= 32'd1;
    end
		if (bltA_dcnt>=bltD_cntx)
			bltCtrlx[1] <= 1'b0;
		if (bltCtrlx[3])
			blt_nch <= 2'b01;
		else if (bltCtrlx[5])
			blt_nch <= 2'b10;
		else if (bltCtrlx[7])
			blt_nch <= 2'b11;
		else
			blt_nch <= 2'b00;
		tRet();
	end

	// Blit channel B
st_bltdma4:
	begin
		mbus.req.cyc <= HIGH;
		mbus.req.stb <= HIGH;
		mbus.req.sel <= 8'h03 << {bltB_wadr[2:1],1'b0};
		mbus.req.adr <= bltB_wadr;
		bltinc <= bltCtrlx[9] ? -32'(bltB_inc) : bltB_inc;
		tCall(st_latch_data,st_bltdma4_nack);
	end
st_bltdma4_nack:
	if (~mbus.resp.ack) begin
		bltB_datx <= latched_data >> {bltB_wadr[2:1],4'h0};
    bltB_wadr <= bltB_wadr + bltinc;
    bltB_hcnt <= bltB_hcnt + 32'd1;
    if (bltB_hcnt>=bltSrcWidx) begin
      bltB_hcnt <= 32'd1;
      bltB_wadr <= bltB_wadr + {bltB_modx[31:1],1'b0} + bltinc;
    end
    bltB_wcnt <= bltB_wcnt + 32'd1;
    bltB_dcnt <= bltB_dcnt + 32'd1;
    if (bltB_wcnt>=bltB_cntx) begin
      bltB_wadr <= bltB_badrx;
      bltB_wcnt <= 32'd1;
      bltB_hcnt <= 32'd1;
    end
		if (bltB_dcnt==bltD_cntx)
			bltCtrlx[3] <= 1'b0;
		if (bltCtrlx[5])
			blt_nch <= 2'b10;
		else if (bltCtrlx[7])
			blt_nch <= 2'b11;
		else if (bltCtrlx[1])
			blt_nch <= 2'b00;
		else
			blt_nch <= 2'b01;
		tRet();
	end

	// Blit channel C
st_bltdma6:
	begin
		mbus.req.cyc <= HIGH;
		mbus.req.stb <= HIGH;
		mbus.req.sel <= 8'h3 << {bltC_wadr[2:1],1'b0};
		mbus.req.adr <= bltC_wadr;
		bltinc <= bltCtrlx[10] ? -32'(bltC_inc) : bltC_inc;
		tCall(st_latch_data,st_bltdma6_nack);		
	end
st_bltdma6_nack:
	if (~mbus.resp.ack) begin
		bltC_datx <= latched_data >> {bltC_wadr[2:1],4'h0};
    bltC_wadr <= bltC_wadr + bltinc;
    bltC_hcnt <= bltC_hcnt + 32'd1;
    if (bltC_hcnt==bltSrcWidx) begin
      bltC_hcnt <= 32'd1;
      bltC_wadr <= bltC_wadr + {bltC_modx[31:1],1'b0} + bltinc;
    end
    bltC_wcnt <= bltC_wcnt + 32'd1;
    bltC_dcnt <= bltC_dcnt + 32'd1;
    if (bltC_wcnt>=bltC_cntx) begin
      bltC_wadr <= bltC_badrx;
      bltC_wcnt <= 32'd1;
      bltC_hcnt <= 32'd1;
    end
		if (bltC_dcnt>=bltD_cntx)
			bltCtrlx[5] <= 1'b0;
		if (bltCtrlx[7])
			blt_nch <= 2'b11;
		else if (bltCtrlx[1])
			blt_nch <= 2'b00;
		else if (bltCtrlx[3])
			blt_nch <= 2'b01;
		else
			blt_nch <= 2'b10;
		tRet();
	end

	// Blit channel D
st_bltdma8:
	begin
		if (bltD_wadr[31:20] <= 12'h001) begin
			local_sel <= TRUE;
			tGoto(st_bltdma8_nack);
		end
		else
			tCall(st_wait_ack,st_bltdma8_nack);
		mbus.req.cyc <= HIGH;
		mbus.req.stb <= HIGH;
		mbus.req.we <= HIGH;
		case(bltD_inc)
		8'd1:	mbus.req.sel <= 8'h01 << bltD_wadr[2:0];
		8'd2:	mbus.req.sel <= 8'h03 << {bltD_wadr[2:1],1'b0};
		8'd4:	mbus.req.sel <= 8'h0F << {bltD_wadr[2],2'b0};
		default:	mbus.req.sel <= 8'hFF;
		endcase
		mbus.req.adr <= bltD_wadr;
		// If there's no source then a fill operation must be taking place.
		if (bltCtrlx[1]|bltCtrlx[3]|bltCtrlx[5])
			mbus.req.dat <= {4{bltabc}};
		else
			mbus.req.dat <= bltD_datx;	// fill color
		bltinc <= bltCtrlx[11] ? -32'(bltD_inc) : bltD_inc;
	end
st_bltdma8_nack:
	if (~imresp.ack|local_sel) begin
		local_sel <= FALSE;
		mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
		bltD_wadr <= bltD_wadr + bltinc;
		bltD_wcnt <= bltD_wcnt + 32'd1;
		bltD_hcnt <= bltD_hcnt + 32'd1;
		if (bltD_hcnt>=bltDstWidx) begin
			bltD_hcnt <= 32'd1;
			bltD_wadr <= bltD_wadr + {bltD_modx[31:1],1'b0} + bltinc;
		end
		if (bltD_wcnt>=bltD_cntx) begin
			bltCtrlx[14] <= 1'b0;
			bltCtrlx[13] <= 1'b1;
			bltCtrlx[7] <= 1'b0;
		end
		if (bltCtrlx[1])
			blt_nch <= 2'b00;
		else if (bltCtrlx[3])
			blt_nch <= 2'b01;
		else if (bltCtrlx[5])
			blt_nch <= 2'b10;
		else
			blt_nch <= 2'b11;
		tRet();
	end
/*
st_line_reset:
	begin
		lrst <= FALSE;
//		strip_cnt <= 8'd0;
		rac <= 8'd0;
		if (rst_fifo)
			tGoto(st_line_reset);
		else if (vblank)
			tCall(OTHERS,st_line_reset);
		else begin
			mbus.req.cyc <= LOW;
			mbus.req.stb <= LOW;
			mbus.req.sel <= 8'h00;
			mbus.req.adr <= TargetBase + vndx;
			rdadr <= TargetBase + vndx;
			tGoto(READ_ACC);
		end
	end
	// Add a couple of extra cycles to the bus timeout since the memory
	// controller is fetching four lines on a cache miss rather than
	// just a single line for other accesses.
READ_ACC:
	begin
		mbus.req.cyc <= HIGH;
		mbus.req.stb <= HIGH;
		mbus.req.sel <= 8'hFF;
		mbus.req.adr <= rdadr;
		tocnt <= busto + 8'd2;
		tCall(ST_LATCH_DATA,READ_NACK);
	end
READ_NACK:
	if (~mbus.resp.ack) begin
		strip_cnt <= strip_cnt + 8'd1;
		rac <= rac + 8'd1;
		rdadr <= rdadr + 32'd8;
		// If we read all the strips we needed to, then start reading sprite
		// data.
		tGoto(READ_ACC);
		if (strip_cnt==num_strips) begin
			spriteno <= 5'd0;
			for (n = 0; n < NSPR; n = n + 1)
				m_spriteBmp[n] <= 64'd0;
			tGoto(SPRITE_ACC);
		end
		// Check for too many consecutive memory accesses. Be nice to other
		// bus masters.
//			else if (rac < rac_limit)
//				tGoto(READ_ACC);
//			else begin
//				rac <= 8'd0;
//				tCall(OTHERS,READ_ACC);
//			end
	end
*/

// Assume the sprite data is in high-speed RAM accessible in a single clock.
// Data is fetched only for the sprites that are displayed on the scan line.
st_hsync:
	begin
		spriteno <= 5'd0;
		spriteActiveB <= spriteActive;
		for (n = 0; n < NSPR; n = n + 1)
			m_spriteBmp[n] <= 64'd0;
		tGoto(st_sprite_acc);
	end
st_sprite_acc:
	if (spriteActiveB[spriteno]) begin
		spriteActiveB[spriteno] <= FALSE;
		tGoto(st_sprite_nack);
		local_sel <= TRUE;
		mbus.req.cyc <= HIGH;
		mbus.req.stb <= HIGH;
		mbus.req.sel <= 8'hFF;
		mbus.req.adr <= spriteWaddr[spriteno];
	end
	else begin
		spriteno <= nxtSprite;
		if (nxtSprite == 6'd63) begin
			local_sel <= FALSE;
			mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
			tRet();
		end
	end
st_sprite_nack:
	begin
		local_sel <= FALSE;
		if (tocnt==8'd1)
			m_spriteBmp[spriteno] <= 64'hFFFFFFFFFFFFFFFF;
		else			
			m_spriteBmp[spriteno] <= imresp.dat;
		spriteno <= nxtSprite;
		if (nxtSprite==6'd63) begin
			local_sel <= FALSE;
			mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
			tRet();
		end
		else
			tGoto (st_sprite_acc);
	end

// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// Generic data latching state.
// Implemented as a subroutine.
// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

st_latch_data:
	begin
		tocnt <= tocnt - 1;
		if (imresp.ack|tocnt==0) begin
			tocnt <= busto;
			local_sel <= FALSE;
			latched_data <= imresp.dat;
			mbus.req <= {$bits(wb_cmd_request256_t){1'b0}};
			tGoto(st_delay1);
		end
	end

st_delay3:
	tGoto(st_delay2);
st_delay2:
	tGoto(st_delay1);
st_delay1:
	tRet();

default:	tGoto(st_execute);
endcase
	case(sprite_on)
	32'b00000000000000000000000000000000,
	32'b00000000000000000000000000000001,
	32'b00000000000000000000000000000010,
	32'b00000000000000000000000000000100,
	32'b00000000000000000000000000001000,
	32'b00000000000000000000000000010000,
	32'b00000000000000000000000000100000,
	32'b00000000000000000000000001000000,
	32'b00000000000000000000000010000000,
	32'b00000000000000000000000100000000,
	32'b00000000000000000000001000000000,
	32'b00000000000000000000010000000000,
	32'b00000000000000000000100000000000,
	32'b00000000000000000001000000000000,
	32'b00000000000000000010000000000000,
	32'b00000000000000000100000000000000,
	32'b00000000000000001000000000000000,
	32'b00000000000000010000000000000000,
	32'b00000000000000100000000000000000,
	32'b00000000000001000000000000000000,
	32'b00000000000010000000000000000000,
	32'b00000000000100000000000000000000,
	32'b00000000001000000000000000000000,
	32'b00000000010000000000000000000000,
	32'b00000000100000000000000000000000,
	32'b00000001000000000000000000000000,
	32'b00000010000000000000000000000000,
	32'b00000100000000000000000000000000,
	32'b00001000000000000000000000000000,
	32'b00010000000000000000000000000000,
	32'b00100000000000000000000000000000,
	32'b01000000000000000000000000000000,
	32'b10000000000000000000000000000000:   ;
	default:	collision <= collision | sprite_on;
	endcase

	$display("Tick: %d I-count: %d  %f instructions per clock", tick, icnt>>1, real'(icnt>>1)/real'(tick));
end

// +---------------------------------------------------------------------------------------------------------------------+
// | USE_ADV_FEATURES     | String             | Default value = 0707.                                                   |
// |---------------------------------------------------------------------------------------------------------------------|
// | Enables data_valid, almost_empty, rd_data_count, prog_empty, underflow, wr_ack, almost_full, wr_data_count,         |
// | prog_full, overflow features.                                                                                       |
// |                                                                                                                     |
// |   Setting USE_ADV_FEATURES[0] to 1 enables overflow flag; Default value of this bit is 1                            |
// |   Setting USE_ADV_FEATURES[1] to 1 enables prog_full flag; Default value of this bit is 1                           |
// |   Setting USE_ADV_FEATURES[2] to 1 enables wr_data_count; Default value of this bit is 1                            |
// |   Setting USE_ADV_FEATURES[3] to 1 enables almost_full flag; Default value of this bit is 0                         |
// |   Setting USE_ADV_FEATURES[4] to 1 enables wr_ack flag; Default value of this bit is 0                              |
// |   Setting USE_ADV_FEATURES[8] to 1 enables underflow flag; Default value of this bit is 1                           |
// |   Setting USE_ADV_FEATURES[9] to 1 enables prog_empty flag; Default value of this bit is 1                          |
// |   Setting USE_ADV_FEATURES[10] to 1 enables rd_data_count; Default value of this bit is 1                           |
// |   Setting USE_ADV_FEATURES[11] to 1 enables almost_empty flag; Default value of this bit is 0                       |
// |   Setting USE_ADV_FEATURES[12] to 1 enables data_valid flag; Default value of this bit is 0                         |

// xpm_fifo_sync: Synchronous FIFO
// Xilinx Parameterized Macro, version 2025.1

xpm_fifo_sync #(
  .CASCADE_HEIGHT(0),            // DECIMAL
  .DOUT_RESET_VALUE("0"),        // String
  .ECC_MODE("no_ecc"),           // String
  .EN_SIM_ASSERT_ERR("warning"), // String
  .FIFO_MEMORY_TYPE("auto"),     // String
  .FIFO_READ_LATENCY(1),         // DECIMAL
  .FIFO_WRITE_DEPTH(512),       // DECIMAL
  .FULL_RESET_VALUE(0),          // DECIMAL
  .PROG_EMPTY_THRESH(10),        // DECIMAL
  .PROG_FULL_THRESH(10),         // DECIMAL
  .RD_DATA_COUNT_WIDTH(11),      // DECIMAL
  .READ_DATA_WIDTH(16),          // DECIMAL
  .READ_MODE("std"),             // String
  .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
  .USE_ADV_FEATURES("0707"),     // String
  .WAKEUP_TIME(0),               // DECIMAL
  .WRITE_DATA_WIDTH(64),         // DECIMAL
  .WR_DATA_COUNT_WIDTH(9)        // DECIMAL
)
aud0_fifo (
  .almost_empty(aud0_almost_empty),
  .almost_full(),
  .data_valid(aud0_data_valid),
  .dbiterr(),
  .dout(aud0_fifo_o),
  .empty(),
  .full(),
  .overflow(),
  .prog_empty(),
  .prog_full(), 
  .rd_data_count(),
  .rd_rst_busy(),
  .sbiterr(),
  .underflow(),
  .wr_ack(),
  .wr_data_count(),
  .wr_rst_busy(),
  .din(douta),
  .injectdbiterr(1'b0),
  .injectsbiterr(1'b0),
  .rd_en(aud_ctrl[0] & rd_aud0),
  .rst(rst),
  .sleep(aud0_sleep),
  .wr_clk(clk),
  .wr_en(aud0_wr_en)
);

xpm_fifo_sync #(
  .CASCADE_HEIGHT(0),            // DECIMAL
  .DOUT_RESET_VALUE("0"),        // String
  .ECC_MODE("no_ecc"),           // String
  .EN_SIM_ASSERT_ERR("warning"), // String
  .FIFO_MEMORY_TYPE("auto"),     // String
  .FIFO_READ_LATENCY(1),         // DECIMAL
  .FIFO_WRITE_DEPTH(512),       // DECIMAL
  .FULL_RESET_VALUE(0),          // DECIMAL
  .PROG_EMPTY_THRESH(10),        // DECIMAL
  .PROG_FULL_THRESH(10),         // DECIMAL
  .RD_DATA_COUNT_WIDTH(11),      // DECIMAL
  .READ_DATA_WIDTH(16),          // DECIMAL
  .READ_MODE("std"),             // String
  .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
  .USE_ADV_FEATURES("0707"),     // String
  .WAKEUP_TIME(0),               // DECIMAL
  .WRITE_DATA_WIDTH(64),         // DECIMAL
  .WR_DATA_COUNT_WIDTH(9)        // DECIMAL
)
aud1_fifo (
  .almost_empty(aud1_almost_empty),
  .almost_full(),
  .data_valid(aud1_data_valid),
  .dbiterr(),
  .dout(aud1_fifo_o),
  .empty(),
  .full(),
  .overflow(),
  .prog_empty(),
  .prog_full(), 
  .rd_data_count(),
  .rd_rst_busy(),
  .sbiterr(),
  .underflow(),
  .wr_ack(),
  .wr_data_count(),
  .wr_rst_busy(),
  .din(douta),
  .injectdbiterr(1'b0),
  .injectsbiterr(1'b0),
  .rd_en(aud_ctrl[1] & rd_aud1),
  .rst(rst),
  .sleep(aud1_sleep),
  .wr_clk(clk),
  .wr_en(aud1_wr_en)
);

xpm_fifo_sync #(
  .CASCADE_HEIGHT(0),            // DECIMAL
  .DOUT_RESET_VALUE("0"),        // String
  .ECC_MODE("no_ecc"),           // String
  .EN_SIM_ASSERT_ERR("warning"), // String
  .FIFO_MEMORY_TYPE("auto"),     // String
  .FIFO_READ_LATENCY(1),         // DECIMAL
  .FIFO_WRITE_DEPTH(512),       // DECIMAL
  .FULL_RESET_VALUE(0),          // DECIMAL
  .PROG_EMPTY_THRESH(10),        // DECIMAL
  .PROG_FULL_THRESH(10),         // DECIMAL
  .RD_DATA_COUNT_WIDTH(11),      // DECIMAL
  .READ_DATA_WIDTH(16),          // DECIMAL
  .READ_MODE("std"),             // String
  .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
  .USE_ADV_FEATURES("0707"),     // String
  .WAKEUP_TIME(0),               // DECIMAL
  .WRITE_DATA_WIDTH(64),         // DECIMAL
  .WR_DATA_COUNT_WIDTH(9)        // DECIMAL
)
aud2_fifo (
  .almost_empty(aud2_almost_empty),
  .almost_full(),
  .data_valid(aud2_data_valid),
  .dbiterr(),
  .dout(aud2_fifo_o),
  .empty(),
  .full(),
  .overflow(),
  .prog_empty(),
  .prog_full(), 
  .rd_data_count(),
  .rd_rst_busy(),
  .sbiterr(),
  .underflow(),
  .wr_ack(),
  .wr_data_count(),
  .wr_rst_busy(),
  .din(douta),
  .injectdbiterr(1'b0),
  .injectsbiterr(1'b0),
  .rd_en(aud_ctrl[2] & rd_aud2),
  .rst(rst),
  .sleep(aud2_sleep),
  .wr_clk(clk),
  .wr_en(aud2_wr_en)
);

xpm_fifo_sync #(
  .CASCADE_HEIGHT(0),            // DECIMAL
  .DOUT_RESET_VALUE("0"),        // String
  .ECC_MODE("no_ecc"),           // String
  .EN_SIM_ASSERT_ERR("warning"), // String
  .FIFO_MEMORY_TYPE("auto"),     // String
  .FIFO_READ_LATENCY(1),         // DECIMAL
  .FIFO_WRITE_DEPTH(512),       // DECIMAL
  .FULL_RESET_VALUE(0),          // DECIMAL
  .PROG_EMPTY_THRESH(10),        // DECIMAL
  .PROG_FULL_THRESH(10),         // DECIMAL
  .RD_DATA_COUNT_WIDTH(11),      // DECIMAL
  .READ_DATA_WIDTH(16),          // DECIMAL
  .READ_MODE("std"),             // String
  .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
  .USE_ADV_FEATURES("0707"),     // String
  .WAKEUP_TIME(0),               // DECIMAL
  .WRITE_DATA_WIDTH(64),         // DECIMAL
  .WR_DATA_COUNT_WIDTH(9)        // DECIMAL
)
aud3_fifo (
  .almost_empty(aud3_almost_empty),
  .almost_full(),
  .data_valid(aud3_data_valid),
  .dbiterr(),
  .dout(aud3_fifo_o),
  .empty(),
  .full(),
  .overflow(),
  .prog_empty(),
  .prog_full(), 
  .rd_data_count(),
  .rd_rst_busy(),
  .sbiterr(),
  .underflow(),
  .wr_ack(),
  .wr_data_count(),
  .wr_rst_busy(),
  .din(douta),
  .injectdbiterr(1'b0),
  .injectsbiterr(1'b0),
  .rd_en(aud_ctrl[3] & rd_aud3),
  .rst(rst),
  .sleep(aud3_sleep),
  .wr_clk(clk),
  .wr_en(aud3_wr_en)
);

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Audio
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

always_ff @(posedge clk)
	if (ch0_cnt>=aud0_period || aud_ctrl[8])
		ch0_cnt <= 20'd1;
	else if (aud_ctrl[0])
		ch0_cnt <= ch0_cnt + 20'd1;
always_ff @(posedge clk)
	if (ch1_cnt>= aud1_period || aud_ctrl[9])
		ch1_cnt <= 20'd1;
	else if (aud_ctrl[1])
		ch1_cnt <= ch1_cnt + (aud_ctrl[20] ? aud0_out[15:8] + 20'd1 : 20'd1);
always_ff @(posedge clk)
	if (ch2_cnt>= aud2_period || aud_ctrl[10])
		ch2_cnt <= 20'd1;
	else if (aud_ctrl[2])
		ch2_cnt <= ch2_cnt + (aud_ctrl[21] ? aud1_out[15:8] + 20'd1 : 20'd1);
always_ff @(posedge clk)
	if (ch3_cnt>= aud3_period || aud_ctrl[11])
		ch3_cnt <= 20'd1;
	else if (aud_ctrl[3])
		ch3_cnt <= ch3_cnt + (aud_ctrl[22] ? aud2_out[15:8] + 20'd1 : 20'd1);
always_ff @(posedge clk)
	if (chi_cnt>=audi_period || aud_ctrl[12])
		chi_cnt <= 20'd1;
	else if (aud_ctrl[4])
		chi_cnt <= chi_cnt + 20'd1;

always_ff @(posedge clk)
	aud0_dat2 <= aud0_fifo_o;
always_ff @(posedge clk)
	aud1_dat2 <= aud1_fifo_o;
always_ff @(posedge clk)
	aud2_dat2 <= aud2_fifo_o;
always_ff @(posedge clk)
	aud3_dat2 <= aud3_fifo_o;

always_ff @(posedge clk)
begin
	rd_aud0 <= FALSE;
	rd_aud1 <= FALSE;
	rd_aud2 <= FALSE;
	rd_aud3 <= FALSE;
	audi_req2 <= FALSE;
// IF channel count == 1
// A count value of zero is not possible so there will be no requests unless
// the audio channel is enabled.
	if (ch0_cnt==aud_ctrl[0] && ~aud_ctrl[8])
		rd_aud0 <= TRUE;
	if (ch1_cnt==aud_ctrl[1] && ~aud_ctrl[9])
		rd_aud1 <= TRUE;
	if (ch2_cnt==aud_ctrl[2] && ~aud_ctrl[10])
		rd_aud2 <= TRUE;
	if (ch3_cnt==aud_ctrl[3] && ~aud_ctrl[11])
		rd_aud3 <= TRUE;
	if (chi_cnt==aud_ctrl[4] && ~aud_ctrl[12]) begin
		audi_req <= audi_req + 6'd2;
		audi_req2 <= TRUE;
	end
	if (state==st_audi)
		audi_req <= 6'd0;
end

// Compute end of buffer address
always_ff @(posedge clk)
begin
	aud0_eadr <= aud0_adr + aud0_length;
	aud1_eadr <= aud1_adr + aud1_length;
	aud2_eadr <= aud2_adr + aud2_length;
	aud3_eadr <= aud3_adr + aud3_length;
	audi_eadr <= audi_adr + audi_length;
end

reg signed [31:0] aud0_tmp;
reg signed [31:0] aud1_tmp;
reg signed [31:0] aud2_tmp;
reg signed [31:0] aud3_tmp;
reg signed [31:0] aud1_tmp1;
reg signed [31:0] aud3_tmp1;
reg signed [31:0] aud2_dat3;
reg signed [31:0] aud2_datr;
reg signed [31:0] aud0_vol1a;	// mixed channels 0,1
reg signed [31:0] aud0_vol1b;	// channel 0
reg signed [31:0] aud1_vol1a;	// mixed channels 1,2
reg signed [31:0] aud1_vol1b;	// channel 1
reg signed [31:0] aud1_vol1c;
reg signed [31:0] aud1_vol1d;
reg signed [31:0] aud2_vol1a;	// mixed channels 1,2
reg signed [31:0] aud2_vol1b;	// channel 1
reg signed [31:0] aud2_vol1c;
reg signed [31:0] aud2_vol1d;
reg signed [31:0] aud3_vol1a;	// mixed channels 2,3
reg signed [31:0] aud3_vol1b;	// channel 3
reg signed [31:0] aud3_vol1c;
reg signed [31:0] aud3_vol1d;
always_ff @(posedge clk)
	aud2_datr <= aud2_dat;
always_ff @(posedge clk)
	aud2_vol1a <= aud2_dat2 * aud2_volume;
always_ff @(posedge clk)
	aud2_vol1c <= aud2_vol1a * aud1_dat2;
always_ff @(posedge clk)
	aud2_vol1b <= aud2_dat2 * aud2_volume;
always_ff @(posedge clk)
	aud2_vol1d <= aud2_vol1b;	
always_ff @(posedge clk)
	aud2_dat3 <= aud_ctrl[17] ? aud2_vol1c : aud2_vol1d;
always_ff @(posedge clk)
	aud0_vol1a <= ((aud0_dat2 * aud0_volume + aud1_tmp1) >> 1);
always_ff @(posedge clk)
	aud0_vol1b <= aud0_dat2 * aud0_volume;	
always_ff @(posedge clk)
	aud0_tmp <= aud_mix1 ? aud0_vol1a : aud0_vol1b;
always_ff @(posedge clk)
	aud1_vol1a <= aud1_dat2 * aud1_volume;
always_ff @(posedge clk)
	aud1_vol1c <= aud1_vol1a * aud0_dat2;
always_ff @(posedge clk)
	aud1_vol1b <= aud1_dat2 * aud1_volume;
always_ff @(posedge clk)
	aud1_vol1d <= aud1_vol1b;
always_ff @(posedge clk)
	aud1_tmp1 <= aud_ctrl[16] ? aud1_vol1c : aud1_vol1d;
always_ff @(posedge clk)
	aud1_tmp <= aud1_tmp1;
always_ff @(posedge clk)
	aud2_tmp <= aud_mix3 ? ((aud2_dat3 + aud3_tmp1) >> 1): aud2_dat3;
always_ff @(posedge clk)
	aud3_vol1a <= aud3_dat2 * aud3_volume;
always_ff @(posedge clk)
	aud3_vol1c <= aud3_vol1a * aud2_dat2;
always_ff @(posedge clk)
	aud3_vol1b <= aud3_dat2 * aud3_volume;
always_ff @(posedge clk)
	aud3_vol1d <= aud3_vol1b;
always_ff @(posedge clk)
	aud3_tmp1 <= aud_ctrl[18] ? aud3_vol1c : aud3_vol1d;
always_ff @(posedge clk)
	aud3_tmp <= aud3_tmp1;

always_ff @(posedge clk)
begin
	aud0_out <= aud_ctrl[14] ? aud_test[15:0] : aud_ctrl[0] ? aud0_tmp >> 16 : 16'h0000;
	aud1_out <= aud_ctrl[14] ? aud_test[15:0] : aud_ctrl[1] ? aud1_tmp >> 16 : 16'h0000;
	aud2_out <= aud_ctrl[14] ? aud_test[15:0] : aud_ctrl[2] ? aud2_tmp >> 16 : 16'h0000;
	aud3_out <= aud_ctrl[14] ? aud_test[15:0] : aud_ctrl[3] ? aud3_tmp >> 16 : 16'h0000;
end

// End of xpm_fifo_sync_inst instantiation
				
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// Video
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

always_ff @(posedge clk)
  if (pushst)
    retstack[retsp-12'd1] <= pushstate;
always_comb
	retstacko = pushst ? pushstate : retstack[retsp];

always_ff @(posedge clk)
  if (pushpt)
    pointstack[pointsp-12'd1] <= pointToPush;
wire [31:0] pointstacko = pushpt ? pointToPush : pointstack[pointsp];
wire [15:0] lgcx = pointstacko[31:16];
wire [15:0] lgcy = pointstacko[15:0];

always_ff @(posedge clk)
  if (rstst)
    retsp <= 12'd0;
  else if (pushst)
    retsp <= retsp - 12'd1;
  else if (popst)
    retsp <= retsp + 12'd1;

always_ff @(posedge clk)
  if (rstpt)
    pointsp <= 12'd0;
  else if (pushpt)
    pointsp <= pointsp - 12'd1;
  else if (poppt)
    pointsp <= pointsp + 12'd1;

// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// clock edge #-1
// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// Compute when to shift sprite bitmaps.
// Set sprite active flag
// Increment working count and address

reg [31:0] spriteShift;
always_ff @(posedge vclk)
for (n = 0; n < NSPR; n = n + 1)
  begin
  	spriteShift[n] <= FALSE;
	  case(lowres)
	  2'd0,2'd3:	if (hpos >= sprite_ph[n]) spriteShift[n] <= TRUE;
		2'd1:		if (hpos[11:1] >= sprite_ph[n]) spriteShift[n] <= TRUE;
		2'd2:		if (hpos[11:2] >= sprite_ph[n]) spriteShift[n] <= TRUE;
		endcase
	end

always_ff @(posedge vclk)
for (n = 0; n < NSPR; n = n + 1)
	case(lowres)
	2'd0,2'd3:	spriteActive[n] <= (spriteWcnt[n] <= spriteMcnt[n]) && spriteEnable[n] && vpos >= sprite_pv[n];
	2'd1:	spriteActive[n] <= (spriteWcnt[n] <= spriteMcnt[n]) && spriteEnable[n] && vpos[11:1] >= sprite_pv[n];
	2'd2:	spriteActive[n] <= (spriteWcnt[n] <= spriteMcnt[n]) && spriteEnable[n] && vpos[11:2] >= sprite_pv[n];
	endcase

ffo48 uffospr1 (.i({16'd0,spriteActiveB}), .o(nxtSprite));

always_ff @(posedge vclk)
for (n = 0; n < NSPR; n = n + 1)
	begin
	  case(lowres)
	  2'd0,2'd3:	if ((vpos == sprite_pv[n]) && (hpos == 12'h005)) spriteWcnt[n] <= 16'd0;
		2'd1:		if ((vpos[11:1] == sprite_pv[n]) && (hpos == 12'h005)) spriteWcnt[n] <= 16'd0;
		2'd2:		if ((vpos[11:2] == sprite_pv[n]) && (hpos == 12'h005)) spriteWcnt[n] <= 16'd0;
		endcase
		if (hpos==phTotal-12'd4)	// must be after image data fetch
    		if (spriteActive[n])
    		case(lowres)
    		2'd0,2'd3:	spriteWcnt[n] <= spriteWcnt[n] + 16'd32;
    		2'd1:		if (vpos[0]) spriteWcnt[n] <= spriteWcnt[n] + 16'd32;
    		2'd2:		if (vpos[1:0]==2'b11) spriteWcnt[n] <= spriteWcnt[n] + 16'd32;
    		endcase
	end

always_ff @(posedge vclk)
for (n = 0; n < NSPR; n = n + 1)
	begin
    case(lowres)
    2'd0,2'd3:	if ((vpos == sprite_pv[n]) && (hpos == 12'h005)) spriteWaddr[n] <= spriteAddr[n];
		2'd1:		if ((vpos[11:1] == sprite_pv[n]) && (hpos == 12'h005)) spriteWaddr[n] <= spriteAddr[n];
		2'd2:		if ((vpos[11:2] == sprite_pv[n]) && (hpos == 12'h005)) spriteWaddr[n] <= spriteAddr[n];
		endcase
	if (hpos==phTotal-12'd4)	// must be after image data fetch
		case(lowres)
   		2'd0,2'd3:	spriteWaddr[n] <= spriteWaddr[n] + 32'd8;
   		2'd1:		if (vpos[0]) spriteWaddr[n] <= spriteWaddr[n] + 32'd8;
   		2'd2:		if (vpos[1:0]==2'b11) spriteWaddr[n] <= spriteWaddr[n] + 32'd8;
   		endcase
	end

// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// clock edge #0
// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// Get the sprite display status
// Load the sprite bitmap from ram
// Determine when sprite output should appear
// Shift the sprite bitmap
// Compute color indexes for all sprites

always_ff @(posedge vclk)
begin
  for (n = 0; n < NSPR; n = n + 1)
    if (spriteActive[n] & spriteShift[n]) begin
      sprite_on[n] <=
        spriteLink1[n] ? |{ spriteBmp[(n+1)&31][63:62],spriteBmp[n][63:62]} : 
        |spriteBmp[n][63:62];
    end
    else
        sprite_on[n] <= 1'b0;
end

// Load / shift sprite bitmap
// Register sprite data back to vclk domain
always_ff @(posedge vclk)
begin
	if (hpos==12'h5)
		for (n = 0; n < NSPR; n = n + 1)
			spriteBmp[n] <= m_spriteBmp[n];
    for (n = 0; n < NSPR; n = n + 1)
      if (spriteShift[n])
      	case(lowres)
      	2'd0,2'd3:	spriteBmp[n] <= {spriteBmp[n][61:0],2'h0};
      	2'd1:	if (hpos[0]) spriteBmp[n] <= {spriteBmp[n][61:0],2'h0};
      	2'd2:	if (&hpos[1:0]) spriteBmp[n] <= {spriteBmp[n][61:0],2'h0};
  		endcase
end

always_ff @(posedge vclk)
for (n = 0; n < NSPR; n = n + 1)
if (spriteLink1[n])
    spriteColorNdx[n] <= {n[3:0],spriteBmp[(n+1)&31][63:62],spriteBmp[n][63:62]};
else
    spriteColorNdx[n] <= {n[4:0],spriteBmp[n][63:62]};

// Compute index into sprite color palette
// If none of the sprites are linked, each sprite has it's own set of colors.
// If the sprites are linked once the colors are available in groups.
// If the sprites are linked twice they all share the same set of colors.
// Pipelining register
reg blank1, blank2, blank3, blank4;
reg border1, border2, border3, border4;
reg any_sprite_on2, any_sprite_on3, any_sprite_on4;
reg [14:0] rgb_i3, rgb_i4;
reg [3:0] zb_i3, zb_i4;
reg [3:0] sprite_z1, sprite_z2, sprite_z3, sprite_z4;
reg [3:0] sprite_pzx;
// The color index from each sprite can be mux'ed into a single value used to
// access the color palette because output color is a priority chain. This
// saves having mulriple read ports on the color palette.
reg [31:0] spriteColorOut2; 
reg [31:0] spriteColorOut3;
reg [7:0] spriteClrNdx;

// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// clock edge #1
// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// Mux color index
// Fetch sprite Z order

always_ff @(posedge vclk)
  sprite_on_d1 <= sprite_on;
always_ff @(posedge vclk)
  blank1 <= blank_i;
always_ff @(posedge vclk)
  border1 <= border_i;

always_ff @(posedge vclk)
begin
	spriteClrNdx <= 8'd0;
	for (n = NSPR-1; n >= 0; n = n -1)
		if (sprite_on[n])
			spriteClrNdx <= spriteColorNdx[n];
end
        
always_ff @(posedge vclk)
begin
	sprite_z1 <= 4'hF;
	for (n = NSPR-1; n >= 0; n = n -1)
		if (sprite_on[n])
			sprite_z1 <= sprite_pz[n]; 
end

// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// clock edge #2
// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// Lookup color from palette

always_ff @(posedge vclk)
  sprite_on_d2 <= sprite_on_d1;
always_ff @(posedge vclk)
  any_sprite_on2 <= |sprite_on_d1;
always_ff @(posedge vclk)
  blank2 <= blank1;
always_ff @(posedge vclk)
  border2 <= border1;
always_ff @(posedge vclk)
  spriteColorOut2 <= sprite_color[spriteClrNdx];
always_ff @(posedge vclk)
  sprite_z2 <= sprite_z1;

// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// clock edge #3
// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// Compute alpha blending

wire [12:0] alphaRed = (rgb_i[`R] * spriteColorOut2[31:24]) + (spriteColorOut2[`R] * (9'h100 - spriteColorOut2[31:24]));
wire [12:0] alphaGreen = (rgb_i[`G] * spriteColorOut2[31:24]) + (spriteColorOut2[`G]  * (9'h100 - spriteColorOut2[31:24]));
wire [12:0] alphaBlue = (rgb_i[`B] * spriteColorOut2[31:24]) + (spriteColorOut2[`B]  * (9'h100 - spriteColorOut2[31:24]));
reg [14:0] alphaOut;

always_ff @(posedge vclk)
  alphaOut <= {alphaRed[12:8],alphaGreen[12:8],alphaBlue[12:8]};
always_ff @(posedge vclk)
  sprite_z3 <= sprite_z2;
always_ff @(posedge vclk)
  any_sprite_on3 <= any_sprite_on2;
always_ff @(posedge vclk)
	rgb_i3 <= vid_doutb;
//  rgb_i3 <= rgb_i;
always_ff @(posedge vclk)
  zb_i3 <= 4'hF;//zb_i;
always_ff @(posedge vclk)
  blank3 <= blank2;
always_ff @(posedge vclk)
  border3 <= border2;
always_ff @(posedge vclk)
  spriteColorOut3 <= spriteColorOut2;

reg [14:0] flashOut;
wire [14:0] reverseVideoOut = spriteColorOut2[21] ? alphaOut ^ 15'h7FFF : alphaOut;

// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// clock edge #4
// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// Compute flash output

always_ff @(posedge vclk)
  flashOut <= spriteColorOut3[20] ? (((flashcnt[5:2] & spriteColorOut3[19:16])!=4'b000) ? reverseVideoOut : rgb_i3) : reverseVideoOut;
always_ff @(posedge vclk)
  rgb_i4 <= rgb_i3;
always_ff @(posedge vclk)
  sprite_z4 <= sprite_z3;
always_ff @(posedge vclk)
  any_sprite_on4 <= any_sprite_on3;
always_ff @(posedge vclk)
  zb_i4 <= zb_i3;
always_ff @(posedge vclk)
  blank4 <= blank3;
always_ff @(posedge vclk)
  border4 <= border3;

// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// clock edge #5
// -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
// final output registration

always_ff @(posedge vclk)
	casez({blank4,border4,any_sprite_on4})
	3'b1??:		rgb <= 24'h0000;
	3'b01?:		rgb <= borderColor;
	3'b001:		rgb <= ((zb_i4 < sprite_z4) ? {rgb_i4[14:10],3'b0,rgb_i4[9:5],3'b0,rgb_i4[4:0],3'b0} :
											{flashOut[14:10],3'b0,flashOut[9:5],3'b0,flashOut[4:0],3'b0});
	3'b000:		rgb <= {rgb_i4[14:10],3'b0,rgb_i4[9:5],3'b0,rgb_i4[4:0],3'b0};
	endcase
always_ff @(posedge vclk)
    de <= ~blank4;

// -----------------------------------------------------------------------------
// Support tasks
// -----------------------------------------------------------------------------

task tGoto;
input copro_state_t dst;
begin
//	if (dst==st_execute)
//		ir <= next_ir;
	if (dst==st_ifetch)
		rstst <= TRUE;
	state <= dst;
end
endtask

task tCall;
input copro_state_t dst;
input copro_state_t rst;
begin
	if (retsp==12'd1) begin	// stack overflow ?
    rstst <= TRUE;
//		ctrl[14] <= 1'b0;
        tGoto(st_ifetch);   // abort operation, go back to idle
	end
	else begin
    pushstate <= rst;
    pushst <= TRUE;
		tGoto(dst);
	end
/*
	state <= dst;
	state_stack[0] <= rst;
	state_stack[1] <= state_stack[0];
	state_stack[2] <= state_stack[1];
	state_stack[3] <= state_stack[2];
*/
end
endtask

task tRet;
begin
	state <= retstacko;
	popst <= TRUE;
/*
	state <= state_stack[0];
	state_stack[0] <= state_stack[1];
	state_stack[1] <= state_stack[2];
	state_stack[2] <= state_stack[3];
*/
end
endtask

task tPause;
input copro_state_t st;
begin
	ngs <= st;
	tGoto(st_ifetch);
end
endtask


/*
task tGoto;
input gr_state_t dst;
begin
	gr_state <= dst;
end
endtask

task call;
input gr_state_t st;
input gr_state_t nst;
begin
	if (retsp==12'd1) begin	// stack overflow ?
    rstst <= TRUE;
//		ctrl[14] <= 1'b0;
		state <= st_gr_idle;	// abort operation, go back to idle
	end
	else begin
    pushstate <= st;
    pushst <= TRUE;
		tGoto(nst);
	end
end
endtask

task return;
begin
	state <= retstacko;
	popst <= TRUE;
end
endtask
*/
task tWriteback;
input [3:0] rg;
input [63:0] res;
begin
	case(rg)
	4'd1:	r1 <= res;
	4'd2:	r2 <= res;
	4'd3:	r3 <= res;
	4'd4:	r4 <= res;
	4'd5:	r5 <= res;
	4'd6:	r6 <= res;
	4'd7:	r7 <= res;
	4'd8:	r8 <= res;
	4'd9:	r9 <= res;
	4'd10:	r10 <= res;
	4'd11:	r11 <= res;
	4'd12:	r12 <= res;
	4'd13:	r13 <= res;
	4'd14:  r14 <= res;
	4'd15:  r15 <= res;
	default:	;
	endcase
end
endtask

task t_set_pixel;
input [15:0] color;
input [15:0] alpha;
input [3:0] rop;
begin
	mbus.req.cyc <= LOW;
	mbus.req.stb <= LOW;
	mbus.req.we <= LOW;
	mbus.req.sel <= 8'h00;
	if (fnClip(gcx,gcy))
		;
/*
	else if (zbuf) begin
		m_cyc_o <= `HIGH;
		m_we_o <= `HIGH;
		m_sel_o <= 16'hFFFF;
		m_adr_o <= ma[31:1];
		m_dat_o <= latched_data & ~{128'b1111 << {ma[4:0],2'b0}} | ({124'b0,zlayer} << {ma[4:0],2'b0});
	end
*/
	else
	begin
		// The same operation is performed on all pixels, however the
		// data mask is set so that only the desired pixel is updated
		// in memory.
   	local_sel <= TRUE;
		mbus.req.cyc <= HIGH;
		mbus.req.stb <= HIGH;
		mbus.req.we <= HIGH;
		mbus.req.sel <= 8'b11 << {ma[2:1],1'b0};
		mbus.req.adr <= ma;
		case(rop)
		4'd0:	mbus.req.dat <= {4{16'h0000}};
		4'd1:	mbus.req.dat <= {4{color}};
		4'd3:	mbus.req.dat <= {4{blend(color,latched_data>>{ma[2:1],4'h0},alpha)}};
		4'd4:	mbus.req.dat <= {4{color}} & latched_data;
		4'd5:	mbus.req.dat <= {4{color}} | latched_data;
		4'd6:	mbus.req.dat <= {4{color}} ^ latched_data;
		4'd7:	mbus.req.dat <= {4{color}} & ~latched_data;
		4'hF:	mbus.req.dat <= {4{16'h7FFF}};
		default:	mbus.req.dat <= {4{16'h0000}};
		endcase
	end
end
endtask

endmodule
