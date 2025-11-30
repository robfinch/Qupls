package Qupls3_pkg;

typedef logic [31:0] pc_address_t;

typedef enum logic [5:0] {
	OP_BRK = 6'd0,
	OP_SHIFT = 6'd2,
	OP_CMP = 6'd3,
	OP_ADD = 6'd4,
	OP_ADB = 6'd5,
	OP_MUL = 6'd6,
	OP_CSR = 6'd7,
	OP_AND = 6'd8,
	OP_OR = 6'd9,
	OP_XOR = 6'd10,
	OP_CR = 6'd11,
	OP_SUBF = 6'd12,
	OP_DIV = 6'd14,
	OP_MOV = 6'd15,
	OP_BCC0 = 6'd24,
	OP_BCC1 = 6'd25,
	OP_B0 = 6'd26,
	OP_B1 = 6'd27,
	OP_TRAP = 6'd28,
	OP_CHK = 6'd29,
	OP_XJMP = 6'd30,
	OP_ELPP = 6'd31,
	OP_LDB = 6'd32,
	OP_LDBZ = 6'd33,
	OP_LDW = 6'd34,
	OP_LDWZ = 6'd35,
	OP_LDT = 6'd36,
	OP_LDTZ = 6'd37,
	OP_LOAD = 6'd38,
	OP_LOADA = 6'd39,
	OP_STB = 6'd40,
	OP_STBI = 6'd41,
	OP_STW = 6'd42,
	OP_STWI = 6'd43,
	OP_STT = 6'd44,
	OP_STTI = 6'd45,
	OP_STORE = 6'd46,
	OP_STOREI = 6'd47,
	OP_FENCE = 6'd51,
	OP_BLOCK = 6'd53,
	OP_FLOAT = 6'd54,
	OP_AMO = 6'd59,
	OP_MOD = 6'd60,
	OP_PFX = 6'd61,
	OP_NOP = 6'd63
} opcode_e;

parameter NOP_INSN = {26'd0,OP_NOP};

typedef struct packed
{
	logic [25:0] payload;
	logic [5:0] opcode;
} anyinst_t;

typedef union packed
{
	anyinst_t any;
} instruction_t;

typedef struct packed
{
	logic v;
	logic pfxa;
	logic pfxb;
	logic pfxc;
	logic pfxd;
	logic has_imma;
	logic has_immb;
	logic has_immc;
	logic [31:0] imma;
	logic [31:0] immb;
	logic [31:0] immc;		// for store immediate
} decode_bus_t;

typedef struct packed
{
	logic v;
	pc_address_t pc;
	instruction_t ins;
	decode_bus_t db;
} pipeline_reg_t;

function fnHasExConst;
input instruction_t ins;
begin
	case(ins.any.opcode)
	OP_BRK,OP_SHIFT,OP_CSR,OP_CR,OP_CHK,
	OP_ELPP,	// ENTER,LEAVE,PUSH,POP
	OP_FENCE,OP_BLOCK,OP_FLOAT,
	OP_AMO,	// AMO
	OP_MOD:	// modifiers
		fnHasExConst = 1'b0;
	default:	fnHasExConst = 1'b1;
	endcase
end
endfunction

function fnIsStimm;
input instruction_t ins;
begin
	case(ins.any.opcode)
	OP_STBI,OP_STWI,OP_STTI,OP_STOREI:
		fnIsStimm = 1'b0;
	default:
		fnIsStimm = 1'b1;
	endcase
end
endfunction

function fnIsBccCsr;
input instruction_t ins;
begin
	fnIsBccCsr = ins.any.opcode==OP_BCC0 || ins.any.opcode==OP_BCC1 || ins.any.opcode==OP_CSR;
end
endfunction


// Decodes the constant position from an instruction.
// Two positions are returned. The lower four bits are the base constant
// position, and the upper four bits are the location of a store immediate
// constant.

function [7:0] fnConstPos;
input instruction_t ins;
begin
	fnConstPos = 8'd0;
	if (fnHasExConst(ins))					// does instruction have an extendable constant?
	if (ins[31]!=1'b0)							// and is the constant extended on the cache line?
	if (ins[30:29]!=2'b00) begin		// and it is not a register spec
		if (fnIsBccCsr(ins))
			fnConstPos[3:0] = {1'b1,ins[13:11]};
		else
			fnConstPos[3:0] = {1'b1,ins[19:17]};
	end
	if (fnIsStimm(ins))
		fnConstPos[7:4] = {1'b1,ins[8:6]};
end
endfunction

// Only 32-bit extended constants are supported.

function [3:0] fnConstSize;
input instruction_t ins;
begin
	fnConstSize = 4'd0;
	if (fnHasExConst(ins))					// does instruction have an extendable constant?
	if (ins[31]!=1'b0)							// and is the constant extended on the cache line?
		fnConstSize[1:0] = ins[30:29];
	if (fnIsStimm(ins))
		fnConstSize[3:2] = 2'b01;
end
endfunction

endpackage
