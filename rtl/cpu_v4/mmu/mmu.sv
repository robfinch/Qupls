// ============================================================================
//        __
//   \\__/ o\    (C) 2021-2026  Robert Finch, Waterloo
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
// FOR ANY DIRECT, INDIRECT, INCHANNELENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// 5110 LUTs / 6300 FFs / 28 BRAMs
// ============================================================================

import const_pkg::*;
import wishbone_pkg::*;
import mmu_pkg::*;
import cpu_types_pkg::*;
import Qupls4_pkg::*;
import ptable_walker_pkg::*;

//`define SEGMENTATION 1'b1
`define VADR_LBITS 	12:0
// These bits are used to select the TLB entry
`define VADR_MBITS		22:13
`define VADR_L2_MBITS	29:23
`define VADR_HBITS		31:16

module mmu(rst, clk, paging_en, pebble_en, cpl,
	tlb_pmt_base,	ic_miss_adr, ic_miss_asid, ic_miss_om,
	vadr_ir, vadr, vadr_v, vadr_asid, vadr_id, vadr_om, vadr_we,
	vadr2_ir, vadr2, vadr2_v, vadr2_asid, vadr2_id, vadr2_om, vadr2_we,
	padr, padr2,
	tlb_pc_entry, tlb0_v, pc_padr_v, pc_padr,
	commit0_id, commit0_idv, commit1_id, commit1_idv, commit2_id, commit2_idv,
	commit3_id, commit3_idv,
	ftas_req, ftas_resp,
	ftam_req, ftam_resp, fault_o, faultq_o, pe_fault_o
);
parameter CORENO = 6'd1;
parameter CHANNEL = 3'd3;
parameter WAYS = 3;

parameter IO_ADDR = 32'hFFF40001;	//32'hFEFC0001;
parameter IO_ADDR_MASK = 32'hFFFF0000;
parameter RGN_ADDR = 32'hFFF403C1;	//32'hFEFC0001;
parameter RGN_ADDR_MASK = 32'hFFFFFC00;

parameter CFG_BUS = 8'd0;
parameter CFG_DEVICE = 5'd14;
parameter CFG_FUNC = 3'd0;
parameter CFG_VENDOR_ID	=	16'h0;
parameter CFG_DEVICE_ID	=	16'h0;
parameter CFG_SUBSYSTEM_VENDOR_ID	= 16'h0;
parameter CFG_SUBSYSTEM_ID = 16'h0;
parameter CFG_ROM_ADDR = 32'hFFFFFFF0;

parameter CFG_REVISION_ID = 8'd0;
parameter CFG_PROGIF = 8'd1;
parameter CFG_SUBCLASS = 8'h00;					// 00 = RAM
parameter CFG_CLASS = 8'h05;						// 05 = memory controller
parameter CFG_CACHE_LINE_SIZE = 8'd8;		// 32-bit units
parameter CFG_MIN_GRANT = 8'h00;
parameter CFG_MAX_LATENCY = 8'h00;
parameter CFG_IRQ_LINE = 8'd27;

localparam CFG_HEADER_TYPE = 8'h00;			// 00 = a general device

parameter BUS_PROTOCOL = 0;
parameter BUS_WIDTH = 256;

input rst;
input clk;
input paging_en;
input pebble_en;
input [7:0] cpl;
input physical_address_t tlb_pmt_base;

input pc_address_t ic_miss_adr;
input asid_t ic_miss_asid;
input Qupls4_pkg::operating_mode_t ic_miss_om;
output pc_padr_v;
output physical_address_t pc_padr;

input Qupls4_pkg::micro_op_t vadr_ir;
input physical_address_t vadr;
input asid_t vadr_asid;
input Qupls4_pkg::operating_mode_t vadr_om;
input vadr_we;
input vadr_v;
input rob_ndx_t vadr_id;
output physical_address_t padr;

input Qupls4_pkg::micro_op_t vadr2_ir;
input physical_address_t vadr2;
input asid_t vadr2_asid;
input Qupls4_pkg::operating_mode_t vadr2_om;
input vadr2_we;
input vadr2_v;
input rob_ndx_t vadr2_id;
output physical_address_t padr2;

output tlb_entry_t tlb_pc_entry;
output tlb0_v;

input rob_ndx_t commit0_id;
input commit0_idv;
input rob_ndx_t commit1_id;
input commit1_idv;
input rob_ndx_t commit2_id;
input commit2_idv;
input rob_ndx_t commit3_id;
input commit3_idv;

// Bus slave
input wb_cmd_request256_t ftas_req;
output wb_cmd_response256_t ftas_resp;
// Bus master
output wb_cmd_request256_t ftam_req;
input wb_cmd_response256_t ftam_resp;

output [31:0] fault_o;
output reg [1:0] faultq_o;
output reg pe_fault_o;

tlb_entry_t tlb_entry0;
reg tlb_wr;
reg [WAYS-1:0] tlb_way;
reg [9:0] tlb_entryno;
tlb_entry_t tlb_entry;

virtual_address_t ptw_vadr, swt_vadr;
reg ptw_vv;
physical_address_t tmp_padr, sadr;
wire ptw_pv;
wire tlb_miss;

wire [4:0] pbl_regset;
pebble_t pbl_outa;
pebble_t pbl_outb;
pebble_t pbl_outc;

reg tlb_miss_r;
reg tlb_missadr_r;
asid_t tlb_missasid_r;
rob_ndx_t tlb_missid_r;
reg [1:0] tlb_missqn_r;

address_t tlb_missadr;
address_t tlb_pmtadr;
asid_t tlb_missasid;
rob_ndx_t tlb_missid;
wire [1:0] tlb_missqn;
wire tlb_missack;
reg bound_exc;

virtual_address_t vadrd;					// vadr delayed one cycle.
virtual_address_t pebbled_adr;
reg vadr_vd;
reg pebbled_v;

always_ff @(posedge clk)
	vadr_vd <= vadr_v;
always_ff @(posedge clk)
	vadrd <= vadr;
always_comb
if (pebble_en)
	pebbled_adr = {pbl_outb + vadrd[$bits(virtual_address_t)-1:13],vadrd[12:0]};
else
	pebbled_adr = vadr;
always_comb
if (pebble_en)
	pebbled_v = vadr_vd;
else
	pebbled_v = vadr_v;

always_comb
	bound_exc = pebble_en && vadrd > {pbl_outb.limit,13'h1fff};

//	bound_exc = tlb_missadr > {pbl[tlb_missadr[31:28]].limit,{(5'd6 + ptattr.pgsz){1'h1}}};

reg seg_base_v, pc_seg_base_v;
reg seg_limit_v, pc_seg_limit_v;
tlb_entry_t tlb_entry1, tlb_replaced_entry, tlb_replaced_entry2;
ptw_access_state_t access_state;
ptable_walker_pkg::ptw_state_t req_state;
ptbr_t ptbr;
ptattr_t ptattr;
wire sack,sack_desc;
reg [63:0] fault_adr;
reg [63:0] fault_seg;
asid_t fault_asid;
reg tlbmiss_ip;		// miss processing in progress.
reg fault;
reg upd_req, upd_req2, upd_req3;
ptw_tran_buf_t [15:0] tranbuf;
wb_tranid_t tid;
ptw_miss_queue_t [MISSQ_SIZE-1:0] miss_queue;
reg [31:0] miss_adr;
asid_t miss_asid;
reg [63:0] stlb_adr;
reg cs_config, cs_configd, cs_hwtw, cs_hwtwd;
reg ptw_ppv;
reg [5:0] sel_tran;
reg transfer_ready;
wire [5:0] sel_qe;
wire virt_adr_cd;
reg virt_adr_cdd;
reg [31:16] pmtadr;
reg [63:0] virt_adr, virt_adrd;
reg [63:0] phys_adr;
reg phys_adr_v;
reg [WAYS-1:0] way;
pte_t pte;
pmte_t pmt;
reg pte_v;
reg [4:0] rty_wait;
reg swt;			// software translation request
wire pswt_v;	// physical software translation valid
wire cs_rgn;
wire [255:0] region_dat;
region_t region0, region1, region2;
wire [7:0] rgn_sel0, rgn_sel1, rgn_sel2;
reg priv_err0, priv_err1,priv_err2;
Qupls4_pkg::operating_mode_t om;

integer nn,n4;
wb_cmd_request256_t sreq, sreqd;
wb_cmd_response256_t sresp;
wire irq_en;
wire cs_tw;
wire [15:0] cfg_tid;
wire cfg_ack;
wire [255:0] cfg_out;

e_pte_size pte_size;

always_comb
	sadr <= 32'd0;

always_ff @(posedge clk)
	sreq <= ftas_req;
always_ff @(posedge clk)
	sreqd <= sreq;

// Latch slave response until ACKd by master
always_ff @(posedge clk)
if (rst) begin
	ftas_resp <= {$bits(wb_cmd_response256_t){1'b0}};
end
else begin
	if (BUS_PROTOCOL==0) begin
		if (ftas_resp.ack & ~ftas_req.cyc)
			ftas_resp <= {$bits(wb_cmd_response256_t){1'b0}};
	end
	if (BUS_PROTOCOL==1)
		ftas_resp <= {$bits(wb_cmd_response256_t){1'b0}};
	if (sack|sack_desc) begin
		ftas_resp <= sresp;
		ftas_resp.ack <= ACK;
	end
end

always_ff @(posedge clk)
	cs_config <= ftas_req.cyc &&
		ftas_req.adr[31:28]==4'hD &&
		ftas_req.adr[27:21]==CFG_BUS &&
		ftas_req.adr[20:16]==CFG_DEVICE &&
		ftas_req.adr[15:13]==CFG_FUNC;

always_comb
	cs_hwtw <= cs_tw && sreq.cyc;
always_ff @(posedge clk)
	cs_hwtwd <= cs_hwtw;
always_ff @(posedge clk)
	cs_configd <= cs_config;

vtdl #(.WID(1), .DEP(16)) urdyd1 (.clk(clk), .ce(1'b1), .a(4'd2), .d(cs_hwtw|cs_config), .q(sack));

ddbb256_config #(
	.CFG_BUS(CFG_BUS),
	.CFG_DEVICE(CFG_DEVICE),
	.CFG_FUNC(CFG_FUNC),
	.CFG_VENDOR_ID(CFG_VENDOR_ID),
	.CFG_DEVICE_ID(CFG_DEVICE_ID),
	.CFG_BAR0(IO_ADDR),
	.CFG_BAR0_MASK(IO_ADDR_MASK),
	.CFG_BAR1(RGN_ADDR),
	.CFG_BAR1_MASK(RGN_ADDR_MASK),
	.CFG_SUBSYSTEM_VENDOR_ID(CFG_SUBSYSTEM_VENDOR_ID),
	.CFG_SUBSYSTEM_ID(CFG_SUBSYSTEM_ID),
	.CFG_ROM_ADDR(CFG_ROM_ADDR),
	.CFG_REVISION_ID(CFG_REVISION_ID),
	.CFG_PROGIF(CFG_PROGIF),
	.CFG_SUBCLASS(CFG_SUBCLASS),
	.CFG_CLASS(CFG_CLASS),
	.CFG_CACHE_LINE_SIZE(CFG_CACHE_LINE_SIZE),
	.CFG_MIN_GRANT(CFG_MIN_GRANT),
	.CFG_MAX_LATENCY(CFG_MAX_LATENCY),
	.CFG_IRQ_LINE(CFG_IRQ_LINE),
	.BUS_PROTOCOL(BUS_PROTOCOL)
)
uddbb1
(
	.rst_i(rst),
	.clk_i(clk),
	.irq_i({priv_err0|priv_err1|priv_err2,fault} & {2{irq_en}}),
	.irq_o(fault_o),
	.cs_config_i(cs_configd),
	.tid_i(sreqd.tid),
	.tid_o(cfg_tid),
	.cyc_i(sreqd.cyc),
	.ack_o(cfg_ack),
	.we_i(sreqd.we),
	.sel_i(sreqd.sel),
	.adr_i(sreqd.adr),
	.dat_i(sreqd.dat),
	.dat_o(cfg_out),
	.cs_bar0_o(cs_tw),
	.cs_bar1_o(cs_rgn),
	.cs_bar2_o(),	// cs_lot
	.irq_en_o(irq_en)
);

wire [26:0] lfsr_o;
lfsr27 #(.WID(27)) ulfsr1(rst, clk, 1'b1, 1'b0, lfsr_o);


// Pipelined signals to match BRAM access
always_ff @(posedge clk)
	tlb_miss_r <= tlb_miss;
always_ff @(posedge clk)
	tlb_missadr_r <= tlb_missadr;
always_ff @(posedge clk)
	tlb_missasid_r <= tlb_missasid;
always_ff @(posedge clk)
	tlb_missid_r <= tlb_missid;
always_ff @(posedge clk)
	tlb_missqn_r <= tlb_missqn;


 // xpm_memory_tdpram: True Dual Port RAM
 // Xilinx Parameterized Macro, version 2024.1

 xpm_memory_tdpram #(
    .ADDR_WIDTH_A(9),               // DECIMAL
    .ADDR_WIDTH_B(9),               // DECIMAL
    .AUTO_SLEEP_TIME(0),            // DECIMAL
    .BYTE_WRITE_WIDTH_A(8),        // DECIMAL
    .BYTE_WRITE_WIDTH_B(8),        // DECIMAL
    .CASCADE_HEIGHT(0),             // DECIMAL
    .CLOCKING_MODE("common_clock"), // String
    .ECC_BIT_RANGE("7:0"),          // String
    .ECC_MODE("no_ecc"),            // String
    .ECC_TYPE("none"),              // String
    .IGNORE_INIT_SYNTH(0),          // DECIMAL
    .MEMORY_INIT_FILE("pbl_init.mem"),      // String
    .MEMORY_INIT_PARAM("0"),        // String
    .MEMORY_OPTIMIZATION("true"),   // String
    .MEMORY_PRIMITIVE("block"),     // String
    .MEMORY_SIZE(64*512),           // DECIMAL
    .MESSAGE_CONTROL(0),            // DECIMAL
    .RAM_DECOMP("auto"),            // String
    .READ_DATA_WIDTH_A(64),         // DECIMAL
    .READ_DATA_WIDTH_B(64),         // DECIMAL
    .READ_LATENCY_A(1),             // DECIMAL
    .READ_LATENCY_B(1),             // DECIMAL
    .READ_RESET_VALUE_A("FFFFFFFF00000000"),       // String
    .READ_RESET_VALUE_B("FFFFFFFF00000000"),	// String
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
 ubndregs (
    .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence
    .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
    .douta(pbl_outa),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
    .doutb(pbl_outb),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
    .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence
    .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
    .addra(sreq.adr[11:3]),          // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
    .addrb({pbl_regset,vadr[31:28]}),    // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
    .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when
    .clkb(clk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
    .dina(sreq.dat >> {sreq.adr[4:3],6'b0}),	// WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
    .dinb(64'd0),                     // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
    .ena(sreq.adr[14:12]==3'b0 && cs_hwtw),  // 1-bit input: Memory enable signal for port A. Must be high on clock
    .enb(1'b1),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
    .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
    .injectdbiterrb(1'b0), // 1-bit input: Controls double bit error injection on input data when
    .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
    .injectsbiterrb(1'b0), // 1-bit input: Controls single bit error injection on input data when
    .regcea(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
    .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
    .rsta(rst),                     // 1-bit input: Reset signal for the final port A output register stage.
    .rstb(rst),                     // 1-bit input: Reset signal for the final port B output register stage.
    .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
    .wea({8{sreq.we}} & (sreq.sel >> {sreq.adr[4:3],3'b0}) ),
    .web(1'b0)                        // WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector
 );



   // xpm_memory_sdpram: Simple Dual Port RAM
   // Xilinx Parameterized Macro, version 2024.1
// ??? dead code
/*
xpm_memory_sdpram #(
  .ADDR_WIDTH_A(9),               // DECIMAL
  .ADDR_WIDTH_B(9),               // DECIMAL
  .AUTO_SLEEP_TIME(0),            // DECIMAL
  .BYTE_WRITE_WIDTH_A(8),        // DECIMAL
  .CASCADE_HEIGHT(0),             // DECIMAL
  .CLOCKING_MODE("common_clock"), // String
  .ECC_BIT_RANGE("7:0"),          // String
  .ECC_MODE("no_ecc"),            // String
  .ECC_TYPE("none"),              // String
  .IGNORE_INIT_SYNTH(0),          // DECIMAL
  .MEMORY_INIT_FILE("pbl_init.mem"), // String
  .MEMORY_INIT_PARAM("0"),        // String
  .MEMORY_OPTIMIZATION("true"),   // String
  .MEMORY_PRIMITIVE("block"),     // String
  .MEMORY_SIZE(64*512),           // DECIMAL
  .MESSAGE_CONTROL(0),            // DECIMAL
  .RAM_DECOMP("auto"),            // String
  .READ_DATA_WIDTH_B(64),         // DECIMAL
  .READ_LATENCY_B(1),             // DECIMAL
  .READ_RESET_VALUE_B("0"),       // String
  .RST_MODE_A("SYNC"),            // String
  .RST_MODE_B("SYNC"),            // String
  .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
  .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
  .USE_MEM_INIT(1),               // DECIMAL
  .USE_MEM_INIT_MMI(0),           // DECIMAL
  .WAKEUP_TIME("disable_sleep"),  // String
  .WRITE_DATA_WIDTH_A(64),        // DECIMAL
  .WRITE_MODE_B("no_change"),     // String
  .WRITE_PROTECT(1)               // DECIMAL
)
upbl2 (
  .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
  .doutb(pbl_outc),              // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
  .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
  .addra(sreq.adr[11:3]),          // ADDR_WIDTH_A-bit input: Address for port A write operations.
  .addrb({pbl_regset,virt_adr[31:28]}), // ADDR_WIDTH_B-bit input: Address for port B read operations.
  .clka(clk),                     // 1-bit input: Clock signal for port A. Also clocks port B when
  .clkb(clk),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
  .dina(sreq.dat >> {sreq.adr[4:3],6'b0}),	// WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
  .ena(sreq.adr[14:12]==3'b0 && cs_hwtw), // 1-bit input: Memory enable signal for port A. Must be high on clock
  .enb(1'b1),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
  .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
  .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
  .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
  .rstb(rst),                     // 1-bit input: Reset signal for the final port B output register stage.
  .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
  .wea({8{sreq.we}} & (sreq.sel >> {sreq.adr[4:3],3'b0}) ) 	// WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
);
*/

				
change_det #(.WID(64)) cd3
(
	.rst(rst),
	.clk(clk),
	.ce(req_state==IDLE),
	.i(virt_adr),
	.cd(virt_adr_cd)
);

always_ff @(posedge clk)
	virt_adr_cdd <= virt_adr_cd;
always_ff @(posedge clk)
	virt_adrd <= virt_adr;

mmu_reg_write ummurwr
(
	.rst(rst),
	.clk(clk),
	.cs_hwtw(cs_hwtw),
	.sreq(sreq),
	.ptbr(ptbr),
	.ptattr(ptattr),
	.virt_adr(virt_adr),
	.pbl_regset(pbl_regset)
);

mmu_read_reg ummurdrg
(
	.rst(rst),
	.clk(clk),
	.cs_config(cs_configd),
	.cs_regs(cs_hwtwd),
	.sreq(sreqd),
	.sresp(sresp),
	.cfg_out(cfg_out),
	.cfg_tid(cfg_tid),
	.cfg_ack(cfg_ack),
	.fault_adr(fault_adr),
	.fault_seg(fault_seg),
	.fault_asid(fault_asid),
	.ptbr(ptbr),
	.ptattr(ptattr),
	.virt_adr(virt_adr),
	.phys_adr(phys_adr),
	.phys_adr_v(phys_adr_v),
	.pbl(pbl_outa),
	.pte_size(pte_size),
	.pbl_regset(pbl_regset),
	.region_dat(region_dat)
);

always_comb
begin
	sel_tran = 6'h3f;
	for (n4 = 0; n4 < 16; n4 = n4 + 1)
		if (tranbuf[n4].rdy)
			sel_tran = n4;
end
always_comb
	transfer_ready = ~sel_tran[5];

region_tbl urgnt1
(
	.rst(rst),
	.clk(clk),
	.cs_rgn(cs_rgn),
	.rgn(tlb_entry0.pte.l1.rgn),
	.ftas_req(sreqd),
	.region_dat(region_dat),
	.region_num(),
	.region(region0),
	.sel(rgn_sel0),
	.err()
);

region_tbl urgnt2
(
	.rst(rst),
	.clk(clk),
	.cs_rgn(cs_rgn),
	.rgn(tlb_entry1.pte.l1.rgn),
	.ftas_req(sreqd),
	.region_dat(),
	.region_num(),
	.region(region1),
	.sel(rgn_sel1),
	.err()
);

region_tbl urgnt3
(
	.rst(rst),
	.clk(clk),
	.cs_rgn(cs_rgn),
	.rgn(tlb_pc_entry.pte.l1.rgn),
	.ftas_req(sreqd),
	.region_dat(),
	.region_num(),
	.region(region2),
	.sel(rgn_sel2),
	.err()
);

//`ifdef 0
mmu_attr_check ummatd1
(
	.id(1'b0),
	.cpl(cpl),
	.tlb_entry(tlb_entry0),
	.om(om),				// fix these inputs
	.we(vadr_we),		// fix these inputs
	.region(region0),
	.priv_err(priv_err0)
);

mmu_attr_check ummatd2
(
	.id(1'b0),
	.cpl(cpl),
	.tlb_entry(tlb_entry1),
	.om(om),
	.we(vadr2_we),
	.region(region1),
	.priv_err(priv_err1)
);

mmu_attr_check ummati1
(
	.id(1'b1),
	.cpl(cpl),
	.tlb_entry(tlb_pc_entry),
	.om(om),
	.we(1'b0),
	.region(region2),
	.priv_err(priv_err2)
);
//`endif

ptw_miss_queue umsq1
(
	.rst(rst),
	.clk(clk),
	.state(req_state),
	.ptbr(ptbr),
	.ptattr(ptattr),
	.commit0_id(commit0_id),
	.commit0_idv(commit0_idv),
	.commit1_id(commit1_id),
	.commit1_idv(commit1_idv),
	.commit2_id(commit2_id),
	.commit2_idv(commit2_idv),
	.commit3_id(commit3_id),
	.commit3_idv(commit3_idv),
	.tlb_miss(tlb_miss_r & paging_en),
	.tlb_missadr(tlb_missadr_r),
	.tlb_missasid(tlb_missasid_r),
	.tlb_missid(tlb_missid_r),
	.tlb_missqn(tlb_missqn_r),
	.in_que(tlb_missack),
	.ptw_vv(ptw_vv),
	.ptw_pv(ptw_pv),
	.ptw_ppv(ptw_ppv),
	.tranbuf(tranbuf),
	.miss_queue(miss_queue),
	.transfer_ready(transfer_ready),
	.sel_tran(sel_tran),
	.sel_qe(sel_qe)
);

ptw_tran_buffer #(.CORENO(CORENO), .CHANNEL(CHANNEL)) utrbf1
(
	.rst(rst),
	.clk(clk),
	.ptattr(ptattr),
	.state(req_state),
	.access_state(access_state),
	.ptw_vv(ptw_vv),
	.ptw_pv(ptw_pv),
	.ptw_ppv(ptw_ppv),
	.tranbuf(tranbuf),
	.miss_queue(miss_queue),
	.sel_tran(sel_tran),
	.sel_qe(sel_qe),
	.ftam_resp(ftam_resp),
	.ftam_resp_ack(ftam_resp.ack),
	.tid(tid),
	.ptw_vadr(ptw_vadr),
	.ptw_padr(padr2)
);

wire padr0_v;
assign tlb0_v = padr0_v & ~pswt_v;

tlb3way utlb1
(
	.rst(rst),
	.clk(clk),
	.paging_en(paging_en),
	.wr(tlb_wr),
	.way(tlb_way),
	.entry_no(tlb_entryno),
	.entry_i(tlb_entry),
	.entry_o(tlb_replaced_entry),
	.stall_tlb0(1'b0),
	.stall_tlb1(1'b0),
	.vadr0(pebbled_v ? pebbled_adr : swt_vadr),
	.vadr1(ptw_vv ? ptw_vadr : vadr2),
	.swt_i(swt & ~vadr_v),
	.swt_o(),
	.pc_ladr(ic_miss_adr),
	.pc_asid(ic_miss_asid),
	.op0(vadr_ir),
	.op1(vadr2_ir),
	.agen0_rndx_i(vadr_id),
	.agen1_rndx_i(vadr2_id),
	.agen0_rndx_o(),
	.agen1_rndx_o(),
	.agen0_v(pebbled_v),
	.agen1_v(ptw_vv),
	.swt_v(swt & ~pebbled_v),
	.load0_i(),
	.load1_i(),
	.store0_i(),
	.store1_i(),
	.asid0(vadr_asid),
	.asid1(16'h0),
	.entry0_o(tlb_entry0),
	.entry1_o(tlb_entry1),
	.pc_tlb_entry_o(tlb_pc_entry),
	.padr0_v(padr0_v),
	.padr0(padr),
	.padr1(padr2),
	.padr1_v(ptw_pv),
	.pswt_v(pswt_v),
	.pc_padr(pc_padr),
	.pc_padr_v(pc_padr_v),
	.tlb0_op(),
	.tlb1_op(),
	.load0_o(),
	.load1_o(),
	.store0_o(),
	.store1_o(),
	.miss_o(tlb_miss),
	.missadr_o(tlb_missadr),
	.missasid_o(tlb_missasid),
	.missid_o(tlb_missid),
	.missqn_o(tlb_missqn),
	.missack(tlb_missack)
);

always_ff @(posedge clk)
if (rst) begin
	tlbmiss_ip <= 'd0;
	ftam_req <= {$bits(wb_cmd_request256_t){1'd0}};		// clear all fields.
	upd_req <= 'd0;
	upd_req2 <= 1'b0;
	upd_req3 <= 1'b0;
	way <= 'd0;
	tlb_wr <= 1'b0;
	tlb_way <= 'd0;
	ptw_vadr <= {$bits(virtual_address_t){1'b0}};
	fault <= 1'b0;
	faultq_o <= 'd0;
	pe_fault_o <= 1'b0;
	fault_asid <= {$bits(asid_t){1'b0}};
	fault_adr <= {$bits(virtual_address_t){1'b0}};
	fault_seg <= {64{1'b0}};
	miss_adr <= {$bits(virtual_address_t){1'b0}};
	miss_asid <= {$bits(asid_t){1'b0}};
	pte <= {$bits(pte_t){1'b0}};
	pte_v <= FALSE;
	tlb_entryno <= 10'd0;
	tlb_entry <= {$bits(tlb_entry_t){1'b0}};
	ptw_vv <= FALSE;
	ptw_ppv <= TRUE;
	access_state <= INACTIVE;
	phys_adr <= 64'd0;
	phys_adr_v <= FALSE;
	pmtadr <= 16'h0;
	rty_wait <= 5'd0;
	swt <= FALSE;
end
else begin

	pe_fault_o <= 1'b0;
	if (ptw_pv)
		ptw_vv <= FALSE;
	tlb_wr <= 1'b0;
	way <= way + 2'd1;
	if (way >= WAYS-1)
		way <= 2'd0;


	// If swt is valid copy translation to phys_adr reg and flag as valid.
//	if (padr_v & swt) begin
//		phys_adr <= padr;
//		phys_adr_v <= TRUE;
//		swt <= FALSE;
//	end

	// If the virtual address register changed, the physical address is no longer
	// valid.
	if (virt_adr_cdd)
		phys_adr_v <= FALSE;

	// Check for update to TLB.
	// Update the TLB by writing TLB registers with the translation.
	// Advance to the next miss.
	if (upd_req) begin
		upd_req <= 'd0;
		upd_req2 <= 1'b1;
		tlb_wr <= 1'b1;
		tlb_way <= way;
		if (pte.l2.lvl==3'd2 && Qupls4_pkg::SUPPORT_TLBLVL2)
			tlb_entryno <= {3'd0,miss_adr[`VADR_L2_MBITS]};
		else
			tlb_entryno <= miss_adr[`VADR_MBITS];
		tlb_entry.pte <= pte;
		tlb_entry.vpn.vpn <= {{48{miss_adr[31]}},miss_adr[`VADR_HBITS]};
		tlb_entry.vpn.asid <= miss_asid;
	end
	if (upd_req2) begin
		upd_req2 <= 1'b0;
		upd_req3 <= 1'b1;
		tlb_replaced_entry2 <= tlb_replaced_entry;
	end

	// FTA bus: clear all fields after one cycle.
	if (BUS_PROTOCOL==1 && ftam_resp.rty==FALSE)
			ftam_req <= {$bits(wb_cmd_request256_t){1'd0}};

	case(req_state)
	IDLE:
		begin
			if (upd_req3) begin
				upd_req3 <= 1'b0;
//				access_state <= TLB_PMT_STORE;
				req_state <= ptable_walker_pkg::WAIT;
			end
			// If the physical address register is invalid, make it match corresponding
			// to the virtual address. It is a software translation request.
			// Stay in the idle state to handle subsequent requests.
			else if (!phys_adr_v && !swt) begin
				swt_vadr <= virt_adr;
				ptw_vv <= TRUE;		// causes the address to be fed to the TLB
				ptw_ppv <= TRUE;
				swt <= TRUE;			// Trigger swt and prevent repeat
			end
			else if (~sel_qe[5] && access_state==INACTIVE && !swt) begin
				ptw_vadr <= miss_queue[sel_qe].tadr[31:0];
				ptw_vv <= TRUE;
				ptw_ppv <= TRUE;
				access_state <= ptable_walker_pkg::TLB_PTE_FETCH;
				req_state <= ptable_walker_pkg::WAIT;
			end
		end
	WAIT:
		;
	// Remain in fault state until cleared by accessing the table-walker register.
	FAULT:
		begin
			fault <= 1'd0;
			if (cs_hwtw && sreq.adr[13:0]==14'h3F00) begin
				tlbmiss_ip <= 'd0;
				req_state <= ptable_walker_pkg::IDLE;		
			end
		end
	default:
		req_state <= ptable_walker_pkg::IDLE;	
	endcase
	
	case(access_state)
	INACTIVE:	;
	VIRT_ADR_XLAT:
		if (ptw_pv & ptw_ppv) begin
			ptw_ppv <= FALSE;
			phys_adr <= padr2;
			phys_adr_v <= TRUE;
			access_state <= ptable_walker_pkg::INACTIVE;
			req_state <= ptable_walker_pkg::IDLE;
		end
	ptable_walker_pkg::TLB_PTE_FETCH:
		if (~sel_qe[5] & ptw_pv & ptw_ppv) begin
			$display("PTW: table walk triggered.");
			if (miss_queue[sel_qe].lvl != 3'd0) begin
				$display("PTW: walk level=%d", miss_queue[sel_qe].lvl);
				ptw_ppv <= FALSE;
				ftam_req <= {$bits(wb_cmd_request256_t){1'd0}};		// clear all fields.
				ftam_req.cmd <= wishbone_pkg::CMD_LOAD;
				ftam_req.blen <= 6'd0;
				ftam_req.bte <= wishbone_pkg::LINEAR;
				ftam_req.cti <= wishbone_pkg::CLASSIC;
				ftam_req.cyc <= 1'b1;
				ftam_req.stb <= 1'b1;
				ftam_req.we <= 1'b0;
				tSetSel(padr2);
//				ftam_req.asid <= miss_queue[sel_qe].asid;
				ftam_req.pv <= 1'b0;
				ftam_req.adr <= padr2;
				ftam_req.tid <= tid;
				rty_wait <= 5'd0;
				if (BUS_PROTOCOL==0)
					access_state <= ptable_walker_pkg::TLB_PTE_ACK;
				else
					access_state <= ptable_walker_pkg::TLB_PTE_FETCH_DONE;
			end
		end
	TLB_PTE_FETCH_DONE:
		if (ftam_resp.rty) begin
			ftam_req <= {$bits(wb_cmd_request256_t){1'd0}};		// clear all fields.
			ftam_req.cmd <= wishbone_pkg::CMD_LOAD;
			ftam_req.blen <= 6'd0;
			ftam_req.bte <= wishbone_pkg::LINEAR;
			ftam_req.cti <= wishbone_pkg::CLASSIC;
			ftam_req.cyc <= 1'b1;
			ftam_req.stb <= 1'b1;
			ftam_req.we <= 1'b0;
			ftam_req.pv <= 1'b0;
			tSetSel(padr2);
			ftam_req.adr <= padr2;
			ftam_req.tid <= tid;
		end
		else begin
			access_state <= ptable_walker_pkg::INACTIVE;
			req_state <= ptable_walker_pkg::IDLE;
		end
	// Store old PMT back to memory. The access count or modified may have been updated.
	/*
	TLB_PTE_STORE:
		if (~sel_qe[5] & ptw_pv & ptw_ppv) begin
		begin
			ftam_req <= 'd0;		// clear all fields.
			ftam_req.cmd <= wishbone_pkg::CMD_STORE;
			ftam_req.blen <= 6'd0;
			ftam_req.bte <= wishbone_pkg::LINEAR;
			ftam_req.cti <= wishbone_pkg::CLASSIC;
			ftam_req.cyc <= 1'b1;
			ftam_req.stb <= 1'b1;
			ftam_req.we <= 1'b1;
			ftam_req.sel <= 16'hF000;	// Only the upper 32-bits of the PMTE are stored.
			ftam_req.asid <= tlb_replaced_entry2.vpn.asid;
			ftam_req.vadr <= {tlb_pmt_base[$bits(physical_address_t)-1:4],4'b0} + {tlb_replaced_entry2.pmtadr[31:16],4'b0};
			ftam_req.padr <= {tlb_pmt_base[$bits(physical_address_t)-1:4],4'b0} + {tlb_replaced_entry2.pmtadr[31:16],4'b0};
			ftam_req.dat <= tlb_replaced_entry2.pmte;
			ftam_req.tid <= tid;
			ftam_req.cid <= CHANNEL;
			access_state <= TLB_PTE_STORE_DONE;
		end
	TLB_PTE_STORE_DONE:
		if (ftam_resp.rty) begin
			ftam_req <= 'd0;		// clear all fields.
			ftam_req.cmd <= wishbone_pkg::CMD_STORE;
			ftam_req.blen <= 6'd0;
			ftam_req.bte <= wishbone_pkg::LINEAR;
			ftam_req.cti <= wishbone_pkg::CLASSIC;
			ftam_req.cyc <= 1'b1;
			ftam_req.stb <= 1'b1;
			ftam_req.we <= 1'b1;
			ftam_req.sel <= 16'hF000;	// Only the upper 32-bits of the PMTE are stored.
			ftam_req.asid <= tlb_replaced_entry2.vpn.asid;
			ftam_req.vadr <= {tlb_pmt_base[$bits(physical_address_t)-1:4],4'b0} + {tlb_replaced_entry2.pmtadr[31:16],4'b0};
			ftam_req.padr <= {tlb_pmt_base[$bits(physical_address_t)-1:4],4'b0} + {tlb_replaced_entry2.pmtadr[31:16],4'b0};
			ftam_req.dat <= tlb_replaced_entry2.pmte;
			ftam_req.tid <= tid;
			ftam_req.cid <= CHANNEL;
		end
		else begin
			access_state <= INACTIVE;
			req_state <= IDLE;
		end
	*/
	ptable_walker_pkg::TLB_PTE_ACK:
		if (ftam_resp.ack)
			access_state <= ptable_walker_pkg::TLB_PTE_NACK;
	ptable_walker_pkg::TLB_PTE_NACK:
		begin
			ftam_req <= {$bits(wb_cmd_request256_t){1'd0}};		// clear all fields.
			access_state <= ptable_walker_pkg::INACTIVE;
			req_state <= ptable_walker_pkg::IDLE;
		end
	default:	access_state <= ptable_walker_pkg::INACTIVE;
	endcase

	// Search for ready transfers and update the TLB.
	if (transfer_ready) begin
		$display("PTW: selected tran:%d", sel_tran[4:0]);
		case(tranbuf[sel_tran].access_state)
		ptable_walker_pkg::INACTIVE:	;
		ptable_walker_pkg::TLB_PTE_FETCH:
			begin
				miss_asid <= miss_queue[tranbuf[sel_tran].mqndx].asid;
				miss_adr <= miss_queue[tranbuf[sel_tran].mqndx].oadr;
				pte <= tranbuf[sel_tran].pte;
				pte_v <= TRUE;
				// If translation is not valid, cause a page fault.
				if (~tranbuf[sel_tran].pte.l1.v) begin
					$display("PTW: page fault");
					faultq_o <= miss_queue[tranbuf[sel_tran].mqndx].qn;
					fault <= 1'b1;
					pe_fault_o <= 1'b1;
					fault_asid <= tranbuf[sel_tran].asid;
					fault_adr <= tranbuf[sel_tran].vadr;
					req_state <= ptable_walker_pkg::FAULT;
				end
				// Otherwise translation was valid, update it in the TLB
				// when level zero reached, or a shortcut page.
				else if (miss_queue[tranbuf[sel_tran].mqndx].lvl==3'd0 ||
					(tranbuf[sel_tran].pte.l2.s==1'b1 && Qupls4_pkg::SUPPORT_TLBLVL2)) begin
					upd_req <= 1'b1;
					$display("PTW: TLB update request triggered.");
				end
			end
		default:	;
		endcase
	end
end

task tBusClear;
begin
	ftam_req.cmd <= wishbone_pkg::CMD_NONE;
	ftam_req.blen <= 6'd0;
	ftam_req.bte <= wishbone_pkg::LINEAR;
	ftam_req.cti <= wishbone_pkg::CLASSIC;
	ftam_req.cyc <= 1'b0;
	ftam_req.sel <= 32'h0000;
	ftam_req.we <= 1'b0;
end
endtask

task tSetSel;
input physical_address_t adr;
begin
	case (BUS_WIDTH)
	32:
		case(pte_size)
		_4B_PTE:	ftam_req.sel <= 4'hF;
		default: ftam_req.sel <= 4'hF;
		endcase
	64:
		case(pte_size)
		_4B_PTE:	ftam_req.sel <= 8'h000F << {adr[2],2'd0};
		_8B_PTE:	ftam_req.sel <= 8'h00FF;
		default: ftam_req.sel <= 8'h00FF;
		endcase
	128:
		case(pte_size)
		_4B_PTE:	ftam_req.sel <= 16'h000F << {adr[3:2],2'd0};//{miss_queue[sel_qe].tadr[3:2],2'd0};
		_8B_PTE:	ftam_req.sel <= 16'h00FF << {adr[3],3'd0};
		_16B_PTE:	ftam_req.sel <= 16'hFFFF;
		default: ftam_req.sel <= 16'h00FF << {adr[3],3'd0};
		endcase
	256:
		case(pte_size)
		_4B_PTE:	ftam_req.sel <= 32'h000F << {adr[4:2],2'd0};
		_8B_PTE:	ftam_req.sel <= 32'h00FF << {adr[4:3],3'd0};
		_16B_PTE:	ftam_req.sel <= 32'hFFFF << {adr[4],4'd0};
		default: ftam_req.sel <= 32'h00FF << {adr[4:3],3'd0};
		endcase
	512:
		case(pte_size)
		_4B_PTE:	ftam_req.sel <= 64'h000F << {adr[5:2],2'd0};
		_8B_PTE:	ftam_req.sel <= 64'h00FF << {adr[5:3],3'd0};
		_16B_PTE:	ftam_req.sel <= 64'hFFFF << {adr[5:4],4'd0};
		default: ftam_req.sel <= 64'h00FF << {adr[5:3],3'd0};
		endcase
	// 256
	default:
		case(pte_size)
		_4B_PTE:	ftam_req.sel <= 32'h000F << {adr[4:2],2'd0};
		_8B_PTE:	ftam_req.sel <= 32'h00FF << {adr[4:3],3'd0};
		_16B_PTE:	ftam_req.sel <= 32'hFFFF << {adr[4],4'd0};
		default: ftam_req.sel <= 32'h00FF << {adr[4:3],3'd0};
		endcase
	endcase
end
endtask

endmodule
