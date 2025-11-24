import Qupls4_pkg::*;

module Qupls4_queue_manager(rst, clk, stomp, rse_i, rse_o, ld, lane, ir, 
	o, we_o, que_done, exc,
	q_rst, q_trigger, q_rd, q_wr, q_addr, q_rd_data, q_wr_data);
parameter WID=64;
input rst;
input clk;
input Qupls4_pkg::rob_bitmask_t stomp;
input Qupls4_pkg::reservation_station_entry_t rse_i;
output Qupls4_pkg::reservation_station_entry_t rse_o;
input ld;
input [2:0] lane;
input Qupls4_pkg::instruction_t ir;
output reg [WID-1:0] o;
output reg [WID/8:0] we_o;
output reg que_done;
output reg [WID-1:0] exc;
output reg [15:0] q_rst;
output reg [15:0] q_trigger;
output reg [15:0] q_rd;
output reg [15:0] q_wr;
output reg [15:0] q_addr;
input [63:0] q_rd_data [0:15];
output reg [63:0] q_wr_data;

wire nanq_rdrdy;
delay3 #(1) u1 (.clk(clk), .ce(1'b1), .i(q_rd[4'd14]), .o(nanq_rdrdy));

always_ff @(posedge clk)
if (rst) begin
	que_done <= 1'b0;
	q_rst <= 1'b0;
	q_rd <= 1'b0;
	q_addr <= 16'd0;
	q_wr_data <= 64'd0;
end
else begin
	que_done <= 1'b0;
	q_rst <= 16'h0000;
	q_rd <= 16'h0000;
	
	case(ir.any.opcode)
	Qupls4_pkg::OP_R3O:
		case(ir.r3.func)
		Qupls4_pkg::FN_RESETQ:	q_rst[rse_i.argB[3:0]] <= 1'b1;
		Qupls4_pkg::FN_READQ:
			begin
				q_rd[rse_i.argB[3:0]] <= 1'b1;
				q_addr <= rse_i.argA[15:0];
			end
		Qupls4_pkg::FN_WRITEQ:
			begin
				q_wr[rse_i.argB[3:0]] <= 1'b1;
				q_addr <= rse_i.argA[15:0];
				q_wr_data <= rse_i.argC;
			end
		default:	;
		endcase
	endcase
end

always_ff @(posedge clk)
begin
	o <= 64'd0;
	if (nanq_rdrdy)
		o <= q_rd_data[4'd14];
end

always_ff @(posedge clk)
begin
	we_o <= 9'd0;
	if (nanq_rdrdy)
		we_o <= 9'h0ff;
end

always_ff @(posedge clk)
begin
	que_done <= 1'b0;
	if (nanq_rdrdy)
		que_done <= 1'b1;
	case(ir.any.opcode)
	Qupls4_pkg::OP_R3O:
		case(ir.r3.func)
		Qupls4_pkg::FN_RESETQ:
			case(rse_i.argB[3:0])
			4'd14:	// NaN queue
				begin
					que_done <= 1'b1;
				end
			default:	;
			endcase
		Qupls4_pkg::FN_WRITEQ:
			case(rse_i.argB[3:0])
			4'd14:	// NaN queue
				begin
					que_done <= 1'b1;
				end
			default:	;
			endcase
		default:	;
		endcase
	endcase
end

endmodule
