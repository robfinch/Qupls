// ============================================================================
//        __
//   \\__/ o\    (C) 2023-2026  Robert Finch, Waterloo
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
// Filters operands into a set of operand latches. Once all operands for an
// instruction are valid, then the instruction is issued  to a pipeline.
//
// 9424 LUTs / 3200 FFs (RL_STRATEGY 1)
// 5101 LUTs / 1975 FFs (RL_STRATEGY 0)
// ============================================================================

import const_pkg::*;
import cpu_types_pkg::*;
import Qupls5_pkg::*;

module Qupls5_reservation_station(rst, clk, available, busy, issue, stall,
	ipl_setting_i, rcg_ipl_o,
	rse_i, rse_o, stomp, rf_oper_i, cap_rf_oper_i,
	bypass_i, wp_oper_tap_i, cap_wp_oper_tap_i,
	req_pRn, req_pRnv,
	fp_sync, req_FPCSRndx, req_FPCSRv, FPCSR, FPCSRv,
	lfa, rob
);
parameter MWIDTH = Qupls5_pkg::MWIDTH;
// The number of reservation station entries should be fourteen or less or
// code will need to be modified.
parameter NRSE = Qupls5_pkg::NRSE;
parameter FUNCUNIT = 4'd0;
parameter NBPI = 4;			// number of bypasssing inputs
// Number of source operands (1 to 4). More than four operands are not supported.
// It is assumed there is always at least one operand.
parameter NSARG = 3;
parameter RL_STRATEGY = 1;	// register lookup strategy
parameter NREG_RPORTS = RL_STRATEGY==0 ? Qupls5_pkg::NREG_RPORTS: 12;
parameter NREG_WPORTS = 13;
parameter RC = 1'b0;
parameter DISPATCH_COUNT=6;	// number of lanes of dispatching
// The following parameter is defunct.
// The following controls which lanes to look at. It depends on which lanes are
// setup in the instruction dispatcher. Specific lanes target specific functional
// unit types. For instance lane #4 is used for floating-point.
parameter DISPATCH_MAP=6'b100001;
parameter FPUNIT = FALSE;
parameter SUPPORT_CAPABILITIES = Qupls5_pkg::SUPPORT_CAPABILITIES;
input rst;
input clk;
input available;
input stall;
input [5:0] ipl_setting_i;
output reg [5:0] rcg_ipl_o;				// recognized ipl
input Qupls5_pkg::reservation_station_entry_t [DISPATCH_COUNT-1:0] rse_i;
input Qupls5_pkg::rob_bitmask_t stomp;
input Qupls5_pkg::operand_t [NREG_RPORTS-1:0] rf_oper_i;
input Qupls5_pkg::cap_operand_t [NREG_RPORTS-1:0] cap_rf_oper_i;
input Qupls5_pkg::operand_t [NBPI-1:0] bypass_i;
input Qupls5_pkg::operand_t [NREG_WPORTS-1:0] wp_oper_tap_i [0:4];
input Qupls5_pkg::cap_operand_t [0:0] cap_wp_oper_tap_i [0:4];
output reg busy;	// 1=The station is busy, all entries in progress.
output reg issue;	// 1=An entry has been issued to a pipeline
output Qupls5_pkg::reservation_station_entry_t rse_o;
// The following are to support register request logic for RL_STRATEGY 1
output pregno_t [3:0] req_pRn;
output reg [3:0] req_pRnv;
output rob_ndx_t req_FPCSRndx;
output reg req_FPCSRv;
// A sync instruction is in the pipeline.
input fp_sync;
// Defunct input for status register
input Qupls5_pkg::fp_status_reg_t FPCSR;
input FPCSRv;
// Bitmap of ROB entries that need to supply an operand for the station.
// May want to re-think this approach for a large number of ROB entries.
output Qupls5_pkg::rob_bitmask_t lfa;	// looking for args
// Allows access to the operand valid flags.
input Qupls5_pkg::rob_entry_t [Qupls5_pkg::ROB_ENTRIES-1:0] rob;

integer kk,jj,nn,mm,pp,qq,n1,n2,n3,n4,n5;
wire [3:0] rdy;
genvar g;
reg idle;
reg dispatch;
reg pstall;	// If there is a stall, causes a 1 cycle delay.
// PLaceholder for args (not a register)
Qupls5_pkg::operand_t [NRSE-1:0] arg [0:5];
Qupls5_pkg::cap_operand_t [NRSE-1:0] cap_arg;
pregno_t [3:0] req_pRnu;
reg [3:0] req_pRnuv;

// In case we need some randomness.
wire [16:0] lfsro;
// The reservation station entry registers.
Qupls5_pkg::reservation_station_entry_t [NRSE-1:0] rse;
Qupls5_pkg::operand_t [NRSE-1:0] rse_argA;
Qupls5_pkg::operand_t [NRSE-1:0] rse_argB;
Qupls5_pkg::operand_t [NRSE-1:0] rse_argC;
Qupls5_pkg::operand_t [NRSE-1:0] rse_argD;
Qupls5_pkg::operand_t [NRSE-1:0] rse_argT;
Qupls5_pkg::operand_t [NRSE-1:0] rse_argS;		// status (for round mode)
Qupls5_pkg::reservation_station_entry_t rsei;
Qupls5_pkg::operand_t [NREG_RPORTS-1:0] rf_fpcsr_i;
Qupls5_pkg::cap_operand_t [NRSE-1:0] rse_cap_arg;
reg [3:0] last_issued;	// last issued RSE

always_comb
begin
	if (NSARG < 1 || NSARG > 4) begin
		$display("Qupls5: Too few <1 or too many >4 operands for reservation station.");
		$finish;
	end
	if (NRSE < 1 || NRSE > 14) begin
		$display("Qupls5: Too few <1 or too many >14 reservation station entries. Station: %d", FUNCUNIT);
		$finish;
	end
	if (RL_STRATEGY < 0 || RL_STRATEGY > 1)
		$display("WARNING Qupls5: Bad register lookup strategy. Strategy zero assumed.");
end

// Not used anymore.
always_comb
foreach (rf_fpcsr_i[n4]) begin
	rf_fpcsr_i[n4].val = FPCSR;
	rf_fpcsr_i[n4].pRn = 9'd0;
	rf_fpcsr_i[n4].fpcsr = TRUE;
	rf_fpcsr_i[n4].v = FPCSRv;
end

// Operand renames.
always_comb
foreach (rse[nn])
begin
	rse_argA[nn] = rse[nn].arg[0];
	rse_argB[nn] = rse[nn].arg[1];
	rse_argC[nn] = rse[nn].arg[2];
	rse_argD[nn] = rse[nn].arg[3];
	rse_argT[nn] = rse[nn].arg[4];
	rse_argS[nn] = rse[nn].arg[5];
end

// If all of the entries are busy, then the station is busy.
always_comb
begin
	busy = 1'b1;
	foreach (rse[n2])
		busy = busy & rse[n2].busy;
end
// Opposite of busy.
always_comb
	idle = !busy;

//always_comb
//	next_cptgt <= {8{cpytgt|rob.decbus.cpytgt}} | ~{8{rob.pred_bit}};

lfsr17 ulfsr1
(
	.rst(rst),
	.clk(clk),
	.ce(1'b1), 
	.cyc(1'b0),
	.o(lfsro)
);

// Always assume at least one source operand. Many instructions have one operand.

Qupls5_validate_operand #(
	.NBPI(NBPI), .NENTRY(NRSE), .NREG_PORTS(NREG_RPORTS),
	.NREG_WPORTS(NREG_WPORTS)) uvsrcA
(
	.wp_hist_i(wp_oper_tap_i),
	.rf_oper_i(rf_oper_i),
	.oper_i(rse_argA),
	.oper_o(arg[0]),
	.operh_i(rse_argA),
	.operh_o(),
	.bypass_i(bypass_i)
);

generate begin : gCapvo
	if (SUPPORT_CAPABILITIES)
Qupls5_validate_cap_operand #(
	.NBPI(NBPI), .NENTRY(NRSE), .NREG_PORTS(NREG_RPORTS),
	.NREG_WPORTS(1)) uvsrcA
(
	.wp_hist_i(cap_wp_oper_tap_i),
	.rf_oper_i(cap_rf_oper_i),
	.oper_i(rse_cap_arg),
	.oper_o(cap_arg),
	.bypass_i()
);
end
endgenerate

// Include only useful operand filters.
// Operands not used are automatically valid so that remaining logic may be
// simplified.
generate begin : gOperands

if (NSARG > 1)
Qupls5_validate_operand #(
	.NBPI(NBPI), .NENTRY(NRSE),
	.NREG_PORTS(NREG_RPORTS),
	.NREG_WPORTS(NREG_WPORTS)
) uvsrcB
(
	.wp_hist_i(wp_oper_tap_i),
	.rf_oper_i(rf_oper_i),
	.oper_i(rse_argB),
	.oper_o(arg[1]),
	.operh_i(rse_argB),
	.operh_o(),
	.bypass_i(bypass_i)
);
else begin
	for (g = 0; g < NRSE; g = g + 1) begin
		assign arg[1][g].v = VAL;
		assign arg[1][g].val = value_zero;
		assign arg[1][g].flags = 8'd0;
	end
end

if (NSARG > 2)
Qupls5_validate_operand #(
	.NBPI(NBPI), .NENTRY(NRSE), .NREG_PORTS(NREG_RPORTS),
	.NREG_WPORTS(NREG_WPORTS)) uvsrcC
(
	.wp_hist_i(wp_oper_tap_i),
	.rf_oper_i(rf_oper_i),
	.oper_i(rse_argC),
	.oper_o(arg[2]),
	.operh_i(rse_argC),
	.operh_o(),
	.bypass_i(bypass_i)
);
else begin
	for (g = 0; g < NRSE; g = g + 1) begin
		assign arg[2][g].v = VAL;
		assign arg[2][g].val = value_zero;
		assign arg[2][g].flags = 8'd0;
	end
end

if (NSARG > 3)
Qupls5_validate_operand #(
	.NBPI(NBPI), .NENTRY(NRSE), .NREG_PORTS(NREG_RPORTS),
	.NREG_WPORTS(NREG_WPORTS)
) uvsrcD
(
	.wp_hist_i(wp_oper_tap_i),
	.rf_oper_i(rf_oper_i),
	.oper_i(rse_argD),
	.oper_o(arg[3]),
	.operh_i(rse_argD),
	.operh_o(),
	.bypass_i(bypass_i)
);
else begin
	for (g = 0; g < NRSE; g = g + 1) begin
		assign arg[3][g].v = VAL;
		assign arg[3][g].val = value_zero;
		assign arg[3][g].flags = 8'd0;
	end
end

end
endgenerate

// Destination operand which sometimes needs to be read.

Qupls5_validate_operand #(
	.NBPI(NBPI), .NENTRY(NRSE), .NREG_PORTS(NREG_RPORTS),
	.NREG_WPORTS(NREG_WPORTS)
) uvsrcT
(
	.wp_hist_i(wp_oper_tap_i),
	.rf_oper_i(rf_oper_i),
	.oper_i(rse_argT),
	.oper_o(arg[4]),
	.operh_i(rse_argT),
	.operh_o(),
	.bypass_i(bypass_i)
);

// Status operand which sometimes needs to be read.
generate begin : gStat
	if (RC > 0)
Qupls5_validate_operand #(
	.NBPI(NBPI), .NENTRY(NRSE), .NREG_PORTS(NREG_RPORTS),
	.NREG_WPORTS(NREG_WPORTS),
	.pFPCSR(TRUE)
) uvsrcS
(
	.wp_hist_i(),
	.rf_oper_i(rf_fpcsr_i),
	.oper_i(rse_argS),
	.oper_o(arg[5]),
	.operh_i(rse_argS),
	.operh_o(),
	.bypass_i(bypass_i)
);
end
endgenerate

// Check for instruction dispatches. Select dispatch input and set dispatch
// flags if dispatch is available.
// Ensure selection is zeroed out for invalid inputs.

always_ff @(posedge clk)
if (rst) begin
	rsei <= {$bits(Qupls5_pkg::reservation_station_entry_t){1'b0}};
	dispatch <= FALSE;
end
else begin
	rsei <= {$bits(Qupls5_pkg::reservation_station_entry_t){1'b0}};
	dispatch <= FALSE;
	foreach (rse_i[n1])
		if (rse_i[n1].funcunit==FUNCUNIT && rse_i[n1].v) begin
			rsei <= rse_i[n1];
			dispatch <= TRUE;
		end
end

// The RSE is ready when all operands are valid.
// This helper function detects the state.
function fnIsReady;
input Qupls5_pkg::reservation_station_entry_t rs;
begin
	fnIsReady = (rs.arg[0].v) &&
				(rs.arg[1].v) &&
				(rs.arg[2].v) &&
				(rs.arg[3].v) &&
				(rs.arg[4].v) &&
				(rs.arg[5].v);
end
endfunction

// Pick an idle RSE in prep for loading operand registers.
always_comb
	qq = fnChooseIdle(rse);

always_ff @(posedge clk)
if (rst) begin
	last_issued <= 4'd15;
	// Clear the operand registers
	foreach (rse[pp])
  	rse[pp] <= {$bits(Qupls5_pkg::reservation_station_entry_t){1'b0}};
  // And the output register
  rse_o <= {$bits(Qupls5_pkg::reservation_station_entry_t){1'b0}};
	issue <= FALSE;
  pstall <= FALSE;
	rcg_ipl_o <= 6'd0;
	lfa <= 64'd0;
end
else begin
	issue <= FALSE;
	pstall <= stall;
	// Clear the last issued entry to allow it to be loaded for subsequent
	// operations.
	if (last_issued != 4'd15 && rse[last_issued].vcount==6'd0) begin
		rse[last_issued].busy <= FALSE;
		rse[last_issued].ready <= FALSE;
		rse[last_issued].v <= FALSE;
		rse[last_issued].arg[0].v <= INV;
		rse[last_issued].arg[1].v <= INV;
		rse[last_issued].arg[2].v <= INV;
		rse[last_issued].arg[3].v <= INV;
		rse[last_issued].arg[4].v <= INV;
		rse[last_issued].arg[5].v <= INV;
		last_issued <= 4'd15;
	end
	if (available && dispatch && idle & rsei.v) begin
		// Load up the selected reservation station.
		if (qq >= 0) begin
			// Age the entries every time a new one comes in.
			foreach (rse[mm])
				rse[mm].age <= rse[mm].age + 2'd1;
			// Copy input to selected entry. This will set an initial value for
			// operands.
			rse[qq] <= rsei;
			// Some of the operands might have been automatically valid. So, we only
			// set the arguments valid, not invalid. They will have been set invalid
			// already at the dispatcher.
			begin
				/*
				if (rob[rsei.rndx].argA_v) rse[qq].arg[0].v <= VAL;
				if (rob[rsei.rndx].argB_v) rse[qq].arg[1].v <= VAL;
				if (rob[rsei.rndx].argC_v) rse[qq].arg[2].v <= VAL;
				if (rob[rsei.rndx].argD_v) rse[qq].arg[3].v <= VAL;
				if (rob[rsei.rndx].argT_v) rse[qq].arg[4].v <= VAL;
				if (rob[rsei.rndx].argDRM_v) rse[qq].arg[5].v <= VAL;
				*/
				// A little less logic to just copy operand valid status from the ROB.
				// It may have changed in the time between dispatch and queue here.
				/*
				rse[qq].arg[0].v <= rob[rsei.rndx].argA_v;
				rse[qq].arg[1].v <= rob[rsei.rndx].argB_v;
				rse[qq].arg[2].v <= rob[rsei.rndx].argC_v;
				rse[qq].arg[3].v <= rob[rsei.rndx].argD_v;
				rse[qq].arg[4].v <= rob[rsei.rndx].argT_v;
				rse[qq].arg[5].v <= rob[rsei.rndx].argDRM_v;
				*/
			end
			// This entry was just loaded so it is the youngest.
			rse[qq].age <= 3'd0;
			// And the RSE is now busy.
			rse[qq].busy <= TRUE;
			// But if we got stomped on, turn into a NOP operation.
			if (stomp[rsei.rndx])
				rse[qq].uop.opcode <= Qupls5_pkg::fnNop();
		end
	end
	// Set look-for-arg flags. There could be multiple RS entries waiting for
	// args from different ROB entries.
	lfa <= 64'd0;
	foreach (rse[mm]) begin
		if (rse[mm].v & ~fnIsReady(rse[mm]))//.ready)
			lfa[rse[mm].rndx] <= TRUE;
	end

	// Check the incoming operands to see if more operands were supplied.
	// These come from the register-file operands (rf_oper inputs) or
	// the register write history (wp_hist inputs).
	for (pp = 0; pp < 6; pp = pp + 1) begin
		foreach (rse[mm]) begin
			if (rse[mm].v & ~rse[mm].ready) begin	// Look at only valid RSEs
				// Do not reset operands already supplied.
				if (~rse[mm].arg[pp].v & arg[pp][mm].v)
					rse[mm].arg[pp] <= arg[pp][mm];
			end
		end
	end
	
	// Detect when the RSE is ready to be issued to a pipe.
	foreach (rse[mm]) begin
		rse[mm].ready <= FALSE;
		if (fnIsReady(rse[mm]))
			rse[mm].ready <= rse[mm].v;
	end

	// Issue scheduling: if there is only one ready easy: pick the ready one.
	// If there are ties: pick oldest one.
	// Once choosen, the RSE entry is no longer valid.
	// If it is an FP unit and there is an FP sync instruction in the pipeline,
	// then refuse to issue.
	// If there is a stall request do not select an entry for output. Delay
	// selection for one cycle after the stall clears to allow the stall
	// requestor to be become ready again.
  rse_o <= {$bits(Qupls5_pkg::reservation_station_entry_t){1'b0}};
	case({pstall,stall})
	2'b10:	;
	2'b01:	;
	2'b11:	;
	default:
		begin
			// All the bits are set in rdy if there are no ready rses.
			// Otherwise rdy holds the index of the selected ready rse.
			// The number of rses supported is limited to 2^n-1
			if (~&rdy) begin
				last_issued <= rdy;
				if (!(fp_sync && rse[rdy].fclass==3'd2)) begin
					// For a vector load / store only issue for when mask indicates so.
					if (rse[rdy].vls) begin
						if (rse[rdy].arg[2][rse[rdy].laneno]) begin
							issue <= TRUE;
							rse_o <= rse[rdy];
							rse_o.v <= !stomp[rse[rdy].rndx] & rse[rdy].v;
							rse[rdy].arg[2][rse[rdy].laneno] <= 1'b0;
						end
						if (rse[rdy].arg[2]==value_zero) begin
							rse[rdy].v <= INV;
							rse_o.uop <= {26'd0,Qupls5_pkg::OP_NOP};
						end
					end
					// Else other operation.
					else begin
						issue <= TRUE;
						// Copy entry to the output register.
						rse_o <= rse[rdy];
						//rse[rdy].v <= INV;
						// Clearing the valid status on a stomp will likely cause the output
						// to be ignored by the pipe.
						rse_o.v <= !stomp[rse[rdy].rndx] & rse[rdy].v;
						// Marking the arg invalid will cause the entry to no longer be ready
						// and cause a fetch of the next register value.
						// Note the renamer only sees the first destination chunk for a vector
						// register. It will leave the next seven physical registers unassigned
						// as the destination is a multiple of eight. Also, essentially a block
						// of 32 regs is assigned for the vector. The increment is by the group
						// number because the renamer will choose the next register of a group.
						// Cannot just increment by one because the reg no would be overlapping
						// with other operands.
						if (Qupls5_pkg::VECTOR_STRATEGY==1) begin
							if (rse[rdy].uop.vn[0]) begin rse[rdy].arg[4].v <= INV; rse[rdy].arg[4].pRn[4:3] <= rse[rdy].arg[4].pRn[4:3] + 2'd1; end
							if (rse[rdy].uop.vn[1]) begin rse[rdy].arg[0].v <= INV; rse[rdy].arg[0].pRn[4:3] <= rse[rdy].arg[0].pRn[4:3] + 2'd1; end
							if (rse[rdy].uop.vn[2]) begin rse[rdy].arg[1].v <= INV; rse[rdy].arg[1].pRn[4:3] <= rse[rdy].arg[1].pRn[4:3] + 2'd1; end
							if (rse[rdy].uop.vn[3]) begin rse[rdy].arg[2].v <= INV; rse[rdy].arg[2].pRn[4:3] <= rse[rdy].arg[2].pRn[4:3] + 2'd1; end
						end
					end
					// For a vector instruction, if finished clear the RSE. Otherwise setup
					// to process the next chunk.
					if (|rse[rdy].uop.vn) begin
						if (rse[rdy].vcount==6'd0) begin
							rse[rdy].busy <= FALSE;
							rse[rdy].ready <= FALSE;
							rse[rdy].v <= FALSE;
							rse[rdy].arg[0].v <= INV;
							rse[rdy].arg[1].v <= INV;
							rse[rdy].arg[2].v <= INV;
							rse[rdy].arg[3].v <= INV;
							rse[rdy].arg[4].v <= INV;
							rse[rdy].arg[5].v <= INV;
						end
						else begin
							rse[rdy].vcount <= rse[rdy].vcount - 6'd1;
							rse[rdy].laneno <= rse[rdy].laneno + 6'd1;
						end
					end
					if (stomp[rse[rdy].rndx])
						rse_o.uop.opcode = Qupls5_pkg::fnNop();
				end
			end
		end
	endcase
end

// Request register reads for missing arguments.
// For RL_STRATEGY=0 register reads do not need to be requested. The requests
// are tracked according to the ROB argument valid flags in the mainline RTL
// code. That means the request logic can be removed from every reservation
// station. But, then there is request logic in the mainline. TBD which is
// smaller and which is faster.

always_comb
begin
	kk = 0;
	req_pRnu[0] = 8'd0;
	req_pRnu[1] = 8'd0;
	req_pRnu[2] = 8'd0;
	req_pRnu[3] = 8'd0;
	req_pRnuv = 4'd0;
	req_FPCSRv = INV;
//	if (RL_STRATEGY==1)
	begin
		for (jj = 0; jj < NRSE; jj = jj + 1) begin
			for (pp = 0; pp < 7; pp = pp + 1) begin
				if (fnSrc(rse[jj].uop,pp)) begin
					if (rse[jj].busy && !rse[jj].arg[pp].v) begin
						if(kk < 4) begin
							req_pRnu[kk] = rse[jj].arg[pp].pRn;
							req_pRnuv[kk] = VAL;
							kk = kk + 1;
						end
						/* Dead code: 
							From when the FP status register was updated in the ROB.
						if (pp==5) begin
							req_FPCSRndx = rse[jj].rndx;
							req_FPCSRv = VAL;
						end
						*/
					end
				end
			end
		end
	end
end

// Register the request signals.
always_ff @(posedge clk)
	req_pRn <= req_pRnu;
always_ff @(posedge clk)
	req_pRnv <= req_pRnuv;

// Helper function, determine if a source is needed.
function fnSrc;
input Qupls5_pkg::micro_op_t op;
input [2:0] n;
begin
	case(n)
	3'd0:	fnSrc = op.src[0];
	3'd1:	fnSrc = op.src[1];
	3'd2:	fnSrc = op.src[2];
	3'd3:	fnSrc = op.src[4];
	3'd4:	fnSrc = op.src[3];
	3'd5:	fnSrc = op.src[5];
	default:	fnSrc = 1'b0;
	endcase
end
endfunction

Qupls5_choose_ready_rse #(.NRSE(NRSE)) uchrdy1
(
	.rse(rse),
	.rdy(rdy)
);

// Helper function, choose the idle RSE. Any one will do.
function integer fnChooseIdle;
input Qupls5_pkg::reservation_station_entry_t [NRSE-1:0] rse;
integer nn;
begin
	fnChooseIdle = -1;
	foreach (rse[nn]) begin
		if (!rse[nn].busy)
			fnChooseIdle = nn;
	end
end
endfunction

endmodule
