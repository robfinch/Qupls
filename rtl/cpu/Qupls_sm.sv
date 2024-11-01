import const_pkg::*;
import fta_bus_pkg::*;

module Qupls_sm (
   input clk_i,
   input rst_i,
   output fta_cmd_request64_t req_o,
   input fta_cmd_response64_t resp_i
);

	reg [2:0] state;		// external bus state machine
  reg [31:0] insn;
  reg ext_bus;
  wire [31:0] immediate = {insn[30],insn[30:0]};

	reg stall;
	reg mem_done;
	reg [63:0] dat_in;
  reg [63:0] ramrd;

  reg [5:0] dsp;  // Data stack pointer
  reg [5:0] _dsp;
  reg [63:0] st0; // Return stack pointer
  reg [63:0] _st0;
  wire _dstkW;     // D stack write

  reg [15:0] pc;
  reg [15:0] _pc;
  reg [5:0] rsp;
  reg [5:0] _rsp;
  reg _rstkW;     // R stack write
  reg [63:0] _rstkD;
  wire _ramWE;     // RAM write enable

  wire [15:0] pc_plus_4;
  assign pc_plus_4 = pc + 3'd4;

  // The D and R stacks
  reg [63:0] dstack[0:63];
  reg [63:0] rstack[0:63];
  always @(posedge clk_i)
  begin
    if (_dstkW)
      dstack[_dsp] = st0;
    if (_rstkW)
      rstack[_rsp] = _rstkD;
  end
  wire [63:0] st1 = dstack[dsp];
  wire [63:0] rst0 = rstack[rsp];

  // st0sel is the ALU operation.  For branch and call the operation
  // is T, for 0branch it is N.  For ALU ops it is loaded from the instruction
  // field.
  reg [4:0] st0sel;
  always_comb
  begin
    case (insn[30:29])
    2'b00: st0sel = 0;          	// ubranch
    2'b10: st0sel = 0;          	// call
    2'b01: st0sel = 1;          	// 0branch
    2'b11: st0sel = insn[28:24]; 	// ALU
    endcase
  end

reg rsta, rstb;
wire clka, clkb;
reg ena, enb;
reg wea, web;
reg [13:0] addra;
reg [12:0] addrb;
reg [31:0] dina;
reg [63:0] dinb;
wire [31:0] douta;
wire [63:0] doutb;

always_comb rsta = rst_i;
assign clka = clk_i;
always_comb ena = 1'b1;
always_comb wea = 1'b0;
always_comb addra = _pc[15:2];
always_comb dina = 32'd0;
always_comb insn = douta;

always_comb rstb = rst_i;
assign clkb = clk_i;
always_comb enb = 1'b1;
always_comb web = {8{_ramWE & (_st0[31:24] == 8'hFF)}};
always_comb addrb = _st0[15:3];
always_comb dinb = st1;
always_comb ramrd = doutb;

   // xpm_memory_tdpram: True Dual Port RAM
   // Xilinx Parameterized Macro, version 2022.2

   xpm_memory_tdpram #(
      .ADDR_WIDTH_A(14),               // DECIMAL
      .ADDR_WIDTH_B(13),               // DECIMAL
      .AUTO_SLEEP_TIME(0),            // DECIMAL
      .BYTE_WRITE_WIDTH_A(32),        // DECIMAL
      .BYTE_WRITE_WIDTH_B(64),        // DECIMAL
      .CASCADE_HEIGHT(0),             // DECIMAL
      .CLOCKING_MODE("common_clock"), // String
      .ECC_MODE("no_ecc"),            // String
      .MEMORY_INIT_FILE("Qupls_sm.mem"),      // String
      .MEMORY_INIT_PARAM("0"),        // String
      .MEMORY_OPTIMIZATION("true"),   // String
      .MEMORY_PRIMITIVE("auto"),      // String
      .MEMORY_SIZE(8*65536),          // DECIMAL
      .MESSAGE_CONTROL(0),            // DECIMAL
      .READ_DATA_WIDTH_A(32),         // DECIMAL
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
      .WRITE_DATA_WIDTH_A(32),        // DECIMAL
      .WRITE_DATA_WIDTH_B(64),        // DECIMAL
      .WRITE_MODE_A("no_change"),     // String
      .WRITE_MODE_B("no_change"),     // String
      .WRITE_PROTECT(1)               // DECIMAL
   )
   xpm_memory_tdpram_inst (
      .dbiterra(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .dbiterrb(),             // 1-bit output: Status signal to indicate double bit error occurrence
                                       // on the data output of port A.

      .douta(douta),                   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(doutb),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .sbiterra(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port A.

      .sbiterrb(),             // 1-bit output: Status signal to indicate single bit error occurrence
                                       // on the data output of port B.

      .addra(addra),                   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .addrb(addrb),                   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
      .clka(clka),                     // 1-bit input: Clock signal for port A. Also clocks port B when
                                       // parameter CLOCKING_MODE is "common_clock".

      .clkb(clkb),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                       // "independent_clock". Unused when parameter CLOCKING_MODE is
                                       // "common_clock".

      .dina(dina),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .dinb(dinb),                     // WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
      .ena(ena),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
                                       // cycles when read or write operations are initiated. Pipelined
                                       // internally.

      .enb(enb),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
                                       // cycles when read or write operations are initiated. Pipelined
                                       // internally.

      .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectdbiterrb(1'b0), // 1-bit input: Controls double bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .injectsbiterrb(1'b0), // 1-bit input: Controls single bit error injection on input data when
                                       // ECC enabled (Error injection capability is not available in
                                       // "decode_only" mode).

      .regcea(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                       // data path.

      .rsta(rsta),                     // 1-bit input: Reset signal for the final port A output register stage.
                                       // Synchronously resets output port douta to the value specified by
                                       // parameter READ_RESET_VALUE_A.

      .rstb(rstb),                     // 1-bit input: Reset signal for the final port B output register stage.
                                       // Synchronously resets output port doutb to the value specified by
                                       // parameter READ_RESET_VALUE_B.

      .sleep(1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
      .wea(1'b0),                       // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                                       // for port A input data port dina. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dina to address addra. For example, to
                                       // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                       // is 32, wea would be 4'b0010.

      .web(web)   										// WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector
                                       // for port B input data port dinb. 1 bit wide when word-wide writes are
                                       // used. In byte-wide write configurations, each bit controls the
                                       // writing one byte of dinb to address addrb. For example, to
                                       // synchronously write only bits [15-8] of dinb when WRITE_DATA_WIDTH_B
                                       // is 32, web would be 4'b0010.

   );

  // Compute the new value of T.
  always_comb
  begin
  	case(insn[31])
  	1'b1:    _st0 = immediate;
    default:
      case (st0sel)
      5'b00000: _st0 = st0;
      5'b00001: _st0 = st1;
      5'b00011:	// CMP
      	begin
      		_st0[0] = st1==st0;
      		_st0[1] = st1!=st0;
      		_st0[2] = $signed(st1) < $signed(st0);
      		_st0[3] = $signed(st1) >= $signed(st0);
      		_st0[4] = $signed(st1) <= $signed(st0);
      		_st0[5] = $signed(st1) > $signed(st0);
      		_st0[6] = st1 < st0;
      		_st0[7] = st1 >= st0;
      		_st0[8] = st1 <= st0;
      		_st0[9] = st1 > st0;
      	end
      5'b00100: _st0 = st0 + st1;		// ADD
      5'b00101:	_st0 = st0 - st1;		// SUB
//      5'b00110:	_st0 = st0 * st1;		// MUL
      5'b01000: _st0 = st0 & st1;		// AND
      5'b01001: _st0 = st0 | st1;		// OR
      5'b01010: _st0 = st0 ^ st1;		// EOR
      5'b01011: _st0 = ~st0;				// COM
      5'b01100: _st0 = st1 << st0[5:0];		// ASL
      5'b01101:	_st0 = st1 >> st0[5:0];		// LSR
      5'b01110:	_st0 = st1 >>> st0[5:0];	// ASR
      5'b01111: _st0 = st0 - 1;
      5'b10000:	_st0 = (st0 << 6'd30) | st1[30:0];
      5'b10001: _st0 = rst0;
      5'b11010: _st0 = ext_bus ? dat_in : ramrd;
      5'b11111: _st0 = {rsp, 2'b00, dsp};
      default: _st0 = 64'hxxxxxxxxxxxxxxxx;
      endcase
    endcase
  end

  wire is_alu = insn[31:29] == 3'b011;
  wire is_lit = insn[31];

	always_comb ext_bus = st1[31:24]!=8'hFF;

  assign _ramWE = is_alu & insn[5];
  assign _dstkW = is_lit | (is_alu & insn[7]);

  wire [1:0] dd = insn[1:0];  // D stack delta
  wire [1:0] rd = insn[3:2];  // R stack delta

  always_comb
  begin
    if (is_lit) begin                       // literal
      _dsp = dsp + 6'd1;
      _rsp = rsp;
      _rstkW = 0;
      _rstkD = _pc;
    end else if (is_alu) begin
      _dsp = dsp + {dd[1], dd[1], dd[1], dd[1], dd};
      _rsp = rsp + {rd[1], rd[1], rd[1], rd[1], rd};
      _rstkW = insn[6];
      _rstkD = st0;
    end else begin                          // jump/call
      // predicated jump is like DROP
      if (insn[31:29] == 3'b001) begin
        _dsp = dsp - 6'd1;
      end else begin
        _dsp = dsp;
      end
      if (insn[31:29] == 3'b010) begin // call
        _rsp = rsp + 1;
        _rstkW = 1;
        _rstkD = pc_plus_4[15:0];
      end else begin
        _rsp = rsp;
        _rstkW = 0;
        _rstkD = _pc;
      end
    end
  end

  always_comb
  begin
    if (rst_i)
      _pc = pc;
    else
      if ((insn[31:29] == 3'b000) || (insn[31:29] == 3'b010))
        _pc = {insn[15:2],2'b00};
      else if ((insn[31:29] == 3'b001) & (st0[28:25] == 1'b1))
        _pc = {insn[15:2],2'b00};
      else if (is_alu & insn[12])
        _pc = {rst0[15:2],2'b00};
      else
        _pc = pc_plus_4;
  end

  always_ff @(posedge clk_i)
  begin
    if (rst_i) begin
      pc <= 16'hFFF0;
      dsp <= 6'd0;
      st0 <= 64'd0;
      rsp <= 6'd0;
    end else begin
      dsp <= _dsp;
      pc <= _pc;
      st0 <= _st0;
      rsp <= _rsp;
    end
  end

always_comb stall = ext_bus && (st0sel==5'b11010 || _ramWE) && !mem_done;

  always_ff @(posedge clk_i)
  if (rst_i)
  	mem_done <= FALSE;
  else begin
  	mem_done <= FALSE;
  	if (_ramWE) begin
  		if (req_o.cti==fta_bus_pkg::ERC)
  			mem_done <= state==3'd3 && resp_i.ack;
  		else
  			mem_done <= state==3'd2 && resp_i.rty==1'b0;
  	end
  	else if (st0sel==5'b11010)
 			mem_done <= state==3'd3 && resp_i.ack;
	end

  always_ff @(posedge clk_i)
  if (rst_i)
  	req_o <= {$bits(fta_cmd_request64_t){1'b0}};
  else begin
  	req_o <= {$bits(fta_cmd_request64_t){1'b0}};
  	case(state)
  	3'd0:
  		if (ext_bus) begin
				if (st0sel==5'b11010) begin
					req_o.cyc <= HIGH;
					req_o.stb <= HIGH;
					req_o.we <= LOW;
					req_o.sel <= insn[23:16];
					req_o.vadr <= {_st0[31:3],3'b0};
					req_o.padr <= {_st0[31:3],3'b0};
					state <= 3'd1;
				end
				else if (_ramWE) begin
					req_o.cyc <= HIGH;
					req_o.stb <= HIGH;
					req_o.we <= HIGH;
					req_o.sel <= insn[23:16];
					req_o.vadr <= {_st0[31:3],3'd0};
					req_o.padr <= {_st0[31:3],3'd0};
					req_o.dat <= st1;
					state <= 3'd2;
				end
			end
  	3'd1:
			if (resp_i.rty) begin
				req_o.cyc <= HIGH;
				req_o.stb <= HIGH;
				req_o.we <= LOW;
				req_o.sel <= insn[23:16];
				req_o.vadr <= _st0;
				req_o.padr <= _st0;
			end
			else
				state <= 3'd3;
  	3'd2:
			if (resp_i.rty) begin
				req_o.cyc <= HIGH;
				req_o.stb <= HIGH;
				req_o.we <= HIGH;
				req_o.sel <= insn[19:16];
				req_o.vadr <= _st0;
				req_o.padr <= _st0;
				req_o.dat <= st1;
			end
			else begin
				if (req_o.cti==fta_bus_pkg::ERC)
					state <= 3'd3;
				else
					state <= 3'd4;
			end
  	3'd3:
  		begin
  			if (resp_i.ack) begin
  				dat_in <= resp_i.dat;
  				state <= 3'd4;
  			end
  		end
  	3'd4:
  		state <= 3'd0;
  	default:
  		state <= 3'd0;
	  endcase
	end

endmodule
