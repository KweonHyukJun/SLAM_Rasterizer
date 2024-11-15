module Pixel_group_controller #(
    parameter NUM_UNITS = 16
) (
    input wire clk,
    input wire rst_n,

    input wire [7:0] mem_data_in,
    output reg [7:0] mem_data_out,

    input wire [15:0] mem_addr_in,
    output reg [15:0] mem_addr_out,
    input wire mem_read,
    input wire mem_write,

    output reg [NUM_UNITS-1:0][3:0] rasterizer_unit_id,
    output reg [NUM_UNITS-1:0][7:0] rasterizer_data_out,
    input wire [NUM_UNITS-1:0][7:0] rasterizer_data_in,

    output reg valid,
    input wire ready
);

    // Internal signals
    logic [NUM_UNITS-1:0][3:0] current_unit;
    typedef enum logic [1:0] {
        IDLE,
        READ_MEM,
        WRITE_RASTERIZER,
        READ_RASTERIZER
    } state_t;

    state_t state, next_state;

    // FSM state transition
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end


    // FSM next state logic
    always_comb begin
        next_state = state;
        valid = 1'b0;
        case (state)
            IDLE: begin
                if (mem_read) begin
                    next_state = READ_MEM;
                end else if (mem_write) begin
                    next_state = WRITE_RASTERIZER;
                end
            end
            READ_MEM: begin
                next_state = WRITE_RASTERIZER;
            end
            WRITE_RASTERIZER: begin
                if (ready) begin
                    next_state = READ_RASTERIZER;
                end
                valid = 1'b1;
            end
            READ_RASTERIZER: begin
                if (ready) begin
                    next_state = IDLE;
                end
                valid = 1'b1;
            end
        endcase
    end


    // FSM output logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_data_out <= 8'b0;
            current_unit <= '{default: 4'b0};
        end else begin
            case (state)
                IDLE: begin
                    // Do nothing
                end
                READ_MEM: begin
                    mem_data_out <= mem_data_in;
                end
                WRITE_RASTERIZER: begin
                    if (ready) begin
                        for (int i = 0; i < NUM_UNITS; i++) begin
                            current_unit[i] <= i;
                            rasterizer_data_out[i] <= mem_data_out;
                        end
                    end
                end
                READ_RASTERIZER: begin
                    if (ready) begin
                        for (int i = 0; i < NUM_UNITS; i++) begin
                            mem_data_out <= rasterizer_data_in[i];
                        end
                    end
                end
            endcase
        end
    end

    // Assign outputs to rasterizer units
    for (genvar i = 0; i < NUM_UNITS; i++) begin
        assign rasterizer_unit_id[i] = current_unit[i];
    end

endmodule