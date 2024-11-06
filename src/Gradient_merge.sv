module Gradient_merge #(
    parameter int precision = 32,
    parameter int N = 16, // Pixels, should be a power of 2 for simplicity
    parameter int data_size = precision * 11 + 32,
    parameter int mantissa_bit = 23,
    parameter int exponent_bit = 8
) (
    input  wire clk,
    input  wire rst_n,
    input  wire [data_size - 1 : 0] data_in [N - 1:0], // N inputs for pixel data
    input  wire gradient_ready,
    output reg  gradient_out_valid,

    output reg  [data_size - 1 : 0] data_out // Gradient output
);

    // Local parameters for levels
    localparam int LEVELS = $clog2(N);

    // Signals for intermediate levels
    wire [data_size - 1 : 0] intermediate_data [LEVELS:0][N-1:0]; // Data storage for each level
    wire level_valid [LEVELS:0]; // Valid signal for each level

    assign level_valid[0] = gradient_ready; // Start from initial ready signal
    assign intermediate_data[0] = data_in;  // Initial level data

    genvar level, i;
    generate
        // Generate tournament levels
        for (level = 0; level < LEVELS; level = level + 1) begin : gen_levels
            // Number of comparisons per level
            // localparam int NUM_COMPS = N / (2 ** level); 
            localparam NUM_COMPS = N >> level; 

            for (i = 0; i < NUM_COMPS; i = i + 1) begin : gen_comps
                // Comparison unit instantiation
                gradient_id_compare_unit #(
                    .precision(precision),
                    .mantissa_bit(mantissa_bit),
                    .exponent_bit(exponent_bit),
                    .data_size(data_size),
                    .N( 1 << level )) 

                compare_inst (
                    .clk(clk),
                    .rst_n(rst_n),

                    .data_A_in(intermediate_data[level][2*i]),      // Input from previous level
                    .data_B_in(intermediate_data[level][2*i + 1]), // Adjacent pair
                    .data_out(intermediate_data[level + 1][i])          // Output for this level
                    // ,.out_valid(level_valid[level])                   // Valid for this level
                );
            end
        end
    endgenerate

    // Output result from final level
    always_ff @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gradient_out_valid <= 1'b0;
            data_out <= 0;
        end 

        else begin
            if (level_valid[LEVELS]) begin
                gradient_out_valid <= 1;
                data_out <= intermediate_data[LEVELS][0]; // Extract precision data
            end
            else begin
                gradient_out_valid <= 0;
                data_out <= 0;
            end

        end 

    end

endmodule
