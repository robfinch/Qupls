
module Qupls5_dsp_alu(clk, rst, ce, op, a, b, o);
parameter USE_MULT = "NONE";
input clk;
input rst;
input ce;
input [3:0] op;
input [47:0] a;
input [47:0] b;
output [47:0] o;

wire CLK = clk;
wire RSTA = rst;
wire RSTB = rst;
wire RSTC = rst;
wire RSTD = rst;

wire [29:0] ACOUT;
wire [17:0] BCOUT;
wire [47:0] P;

assign o = P;
reg [29:0] A;
reg [17:0] B;
reg [47:0] C;
reg [24:0] D;

reg CARRYIN;
reg [4:0] INMODE;
reg [6:0] OPMODE;
reg [3:0] ALUMODE;
reg [2:0] CARRYINSEL;

always_comb
	A = a[29:0];
always_comb
	B = a[47:30];
always_comb
	C = b;
always_comb
	D = 25'd0;	

always_comb
	CARRYIN = 1'b0;

always_comb
	INMODE = 5'b00000;

always_comb
	CARRYINSEL = 3'b000;

always_comb
begin
	OPMODE = 7'b0000000;
	case(op)
	4'd0:	begin OPMODE[3:2]=2'b00; ALUMODE = 4'b1100;	end // AND
	4'd1:	begin OPMODE[3:2]=2'b10; ALUMODE = 4'b1100; end	// OR
	4'd2:	begin OPMODE[3:2]=2'b00; ALUMODE = 4'b0111;	end // XOR
	4'd3:	begin OPMODE[3:2]=2'b00; ALUMODE = 4'b1101;	end // ANDC
	4'd4:	begin OPMODE[3:2]=2'b00; ALUMODE = 4'b1110;	end // NAND
	4'd5:	begin OPMODE[3:2]=2'b10; ALUMODE = 4'b1110; end // NOR
	4'd6:	begin OPMODE[3:2]=2'b00; ALUMODE = 4'b0101; end // XNOR
	4'd7:	begin OPMODE[3:2]=2'b10; ALUMODE = 4'b1101;	end // ORC
	4'd8:	begin OPMODE[3:2]=2'b00; ALUMODE = 4'b0000; end // ADD
	4'd9:	begin OPMODE[3:2]=2'b00; ALUMODE = 4'b0011; end // SUB
	default:	begin OPMODE[3:2]=2'b00; ALUMODE = 4'b0000; end
	endcase
end

reg CEA1,CEA2,CEAD;
reg CEALUMODE;
reg CEB1,CEB2,CEC;
reg CECARRYIN;
reg CECTRL;
reg CED;
reg CEINMODE;
reg CECEM;
reg CEP;

always_comb
begin
	CEA1 = ce;
	CEA2 = ce;
	CEAD = ce;
	CEALUMODE = ce;
	CEB1 = ce;
	CEB2 = ce;
	CEC = ce;
	CECARRYIN = ce;
	CECTRL = ce;
	CED = ce;
	CEINMODE = ce;
	CECEM = ce;
	CEP = ce;
end

reg RSTALLCARRYIN;
reg RSTALUMODE;
reg RSTCTRL;
reg RSTINMODE;
reg RSTM;
reg RSTP;

always_comb
begin
	RSTALLCARRYIN = rst;
	RSTALUMODE = rst;
	RSTCTRL = rst;
	RSTINMODE = rst;
	RSTM = rst;
	RSTP = rst;
end

//   DSP48E1   : In order to incorporate this function into the design,
//   Verilog   : the following instance declaration needs to be placed
//  instance   : in the body of the design code.  The instance name
// declaration : (DSP48E1_inst) and/or the port declarations within the
//    code     : parenthesis may be changed to properly reference and
//             : connect this function to the design.  All inputs
//             : and outputs must be connected.

//  <-----Cut code below this line---->

   // DSP48E1: 48-bit Multi-Functional Arithmetic Block
   //          Kintex-7
   // Xilinx HDL Language Template, version 2025.1

   DSP48E1 #(
      // Feature Control Attributes: Data Path Selection
      .A_INPUT("DIRECT"),               // Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
      .B_INPUT("DIRECT"),               // Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
      .USE_DPORT("FALSE"),              // Select D port usage (TRUE or FALSE)
      .USE_MULT(USE_MULT),            // was MULTIPLY Select multiplier usage ("MULTIPLY", "DYNAMIC", or "NONE")
      .USE_SIMD("ONE48"),               // SIMD selection ("ONE48", "TWO24", "FOUR12")
      // Pattern Detector Attributes: Pattern Detection Configuration
      .AUTORESET_PATDET("NO_RESET"),    // "NO_RESET", "RESET_MATCH", "RESET_NOT_MATCH" 
      .MASK(48'h3fffffffffff),          // 48-bit mask value for pattern detect (1=ignore)
      .PATTERN(48'h000000000000),       // 48-bit pattern match for pattern detect
      .SEL_MASK("MASK"),                // "C", "MASK", "ROUNDING_MODE1", "ROUNDING_MODE2" 
      .SEL_PATTERN("PATTERN"),          // Select pattern value ("PATTERN" or "C")
      .USE_PATTERN_DETECT("NO_PATDET"), // Enable pattern detect ("PATDET" or "NO_PATDET")
      // Register Control Attributes: Pipeline Register Configuration
      .ACASCREG(1),                     // Number of pipeline stages between A/ACIN and ACOUT (0, 1 or 2)
      .ADREG(1),                        // Number of pipeline stages for pre-adder (0 or 1)
      .ALUMODEREG(1),                   // Number of pipeline stages for ALUMODE (0 or 1)
      .AREG(1),                         // Number of pipeline stages for A (0, 1 or 2)
      .BCASCREG(1),                     // Number of pipeline stages between B/BCIN and BCOUT (0, 1 or 2)
      .BREG(1),                         // Number of pipeline stages for B (0, 1 or 2)
      .CARRYINREG(1),                   // Number of pipeline stages for CARRYIN (0 or 1)
      .CARRYINSELREG(1),                // Number of pipeline stages for CARRYINSEL (0 or 1)
      .CREG(1),                         // Number of pipeline stages for C (0 or 1)
      .DREG(1),                         // Number of pipeline stages for D (0 or 1)
      .INMODEREG(1),                    // Number of pipeline stages for INMODE (0 or 1)
      .MREG(1),                         // Number of multiplier pipeline stages (0 or 1)
      .OPMODEREG(1),                    // Number of pipeline stages for OPMODE (0 or 1)
      .PREG(1)                          // Number of pipeline stages for P (0 or 1)
   )
   DSP48E1_inst (
      // Cascade: 30-bit (each) output: Cascade Ports
      .ACOUT(),                   // 30-bit output: A port cascade output
      .BCOUT(),                   // 18-bit output: B port cascade output
      .CARRYCASCOUT(),     // 1-bit output: Cascade carry output
      .MULTSIGNOUT(),       // 1-bit output: Multiplier sign cascade output
      .PCOUT(),                   // 48-bit output: Cascade output
      // Control: 1-bit (each) output: Control Inputs/Status Bits
      .OVERFLOW(),             // 1-bit output: Overflow in add/acc output
      .PATTERNBDETECT(), // 1-bit output: Pattern bar detect output
      .PATTERNDETECT(),   // 1-bit output: Pattern detect output
      .UNDERFLOW(),           // 1-bit output: Underflow in add/acc output
      // Data: 4-bit (each) output: Data Ports
      .CARRYOUT(),             // 4-bit output: Carry output
      .P(P),                           // 48-bit output: Primary data output
      // Cascade: 30-bit (each) input: Cascade Ports
      .ACIN(30'd0),                     // 30-bit input: A cascade data input
      .BCIN(18'd0),                     // 18-bit input: B cascade input
      .CARRYCASCIN(1'b0),       // 1-bit input: Cascade carry input
      .MULTSIGNIN(1'b0),         // 1-bit input: Multiplier sign input
      .PCIN(48'd0),                     // 48-bit input: P cascade input
      // Control: 4-bit (each) input: Control Inputs/Status Bits
      .ALUMODE(ALUMODE),               // 4-bit input: ALU control input
      .CARRYINSEL(CARRYINSEL),         // 3-bit input: Carry select input
      .CLK(CLK),                       // 1-bit input: Clock input
      .INMODE(INMODE),                 // 5-bit input: INMODE control input
      .OPMODE(OPMODE),                 // 7-bit input: Operation mode input
      // Data: 30-bit (each) input: Data Ports
      .A(A),                           // 30-bit input: A data input
      .B(B),                           // 18-bit input: B data input
      .C(C),                           // 48-bit input: C data input
      .CARRYIN(CARRYIN),               // 1-bit input: Carry input signal
      .D(D),                           // 25-bit input: D data input
      // Reset/Clock Enable: 1-bit (each) input: Reset/Clock Enable Inputs
      .CEA1(CEA1),                     // 1-bit input: Clock enable input for 1st stage AREG
      .CEA2(CEA2),                     // 1-bit input: Clock enable input for 2nd stage AREG
      .CEAD(CEAD),                     // 1-bit input: Clock enable input for ADREG
      .CEALUMODE(CEALUMODE),           // 1-bit input: Clock enable input for ALUMODE
      .CEB1(CEB1),                     // 1-bit input: Clock enable input for 1st stage BREG
      .CEB2(CEB2),                     // 1-bit input: Clock enable input for 2nd stage BREG
      .CEC(CEC),                       // 1-bit input: Clock enable input for CREG
      .CECARRYIN(CECARRYIN),           // 1-bit input: Clock enable input for CARRYINREG
      .CECTRL(CECTRL),                 // 1-bit input: Clock enable input for OPMODEREG and CARRYINSELREG
      .CED(CED),                       // 1-bit input: Clock enable input for DREG
      .CEINMODE(CEINMODE),             // 1-bit input: Clock enable input for INMODEREG
      .CEM(CEM),                       // 1-bit input: Clock enable input for MREG
      .CEP(CEP),                       // 1-bit input: Clock enable input for PREG
      .RSTA(RSTA),                     // 1-bit input: Reset input for AREG
      .RSTALLCARRYIN(RSTALLCARRYIN),   // 1-bit input: Reset input for CARRYINREG
      .RSTALUMODE(RSTALUMODE),         // 1-bit input: Reset input for ALUMODEREG
      .RSTB(RSTB),                     // 1-bit input: Reset input for BREG
      .RSTC(RSTC),                     // 1-bit input: Reset input for CREG
      .RSTCTRL(RSTCTRL),               // 1-bit input: Reset input for OPMODEREG and CARRYINSELREG
      .RSTD(RSTD),                     // 1-bit input: Reset input for DREG and ADREG
      .RSTINMODE(RSTINMODE),           // 1-bit input: Reset input for INMODEREG
      .RSTM(RSTM),                     // 1-bit input: Reset input for MREG
      .RSTP(RSTP)                      // 1-bit input: Reset input for PREG
   );

   // End of DSP48E1_inst instantiation

endmodule
				
			