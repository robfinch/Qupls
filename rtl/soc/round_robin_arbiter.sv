// Verilog
// 8-Channel Round Robin Arbiter with Hold

module round_robin_arbiter #(
    parameter WIDTH = 8  // Number of channels
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [WIDTH-1:0] req,   // Request signals from channels
    input  wire hold,               // Hold signal to keep the current grant
    output reg  [WIDTH-1:0] grant  // Grant signals
);

    reg [WIDTH-1:0] next_grant;
    reg [WIDTH-1:0] priority_mask; // Mask to implement round-robin pointer

    integer i;

    // Initialize priority mask on reset
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            grant <= 0;
            priority_mask <= 8'b00000001; // Start with channel 0 as highest priority
        end else begin
            if (!hold) begin
                // Round-robin arbitration logic
                next_grant = 0;
                for (i = 0; i < WIDTH; i = i + 1) begin
                    if (req[i] & priority_mask[i]) begin
                        next_grant = 1 << i;
                        break; // Grant only one channel
                    end
                end

                // If no request matches current priority, wrap around
                if (next_grant == 0) begin
                    for (i = 0; i < WIDTH; i = i + 1) begin
                        if (req[i]) begin
                            next_grant = 1 << i;
                            break;
                        end
                    end
                end

                grant <= next_grant;

                // Update priority mask: next priority starts after current grant
                priority_mask <= (next_grant << 1) | (next_grant == 8'b10000000 ? 8'b00000001 : 0);
            end
        end
    end

endmodule
