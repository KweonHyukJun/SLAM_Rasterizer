module Gradient_merge #(
    parameter int precision = 32,
    parameter int N = 2, // Pixels, should be a power of 2 for simplicity
    parameter int data_size = precision * 11 + 32, 
    parameter int mantissa_bit = 23,
    parameter int exponent_bit = 8
) (
    input  wire clk,
    input  wire rst_n,
    input  wire [data_size - 1 : 0] data_in [N - 1:0], // N inputs for pixel data 
    input  wire data_in_valid [N-1:0],                 // Valid signal for each input
    
    output reg  gradient_out_valid,
    output reg  [data_size - 1 : 0] data_out [N - 1:0] // Gradient output
);

    // Local parameter for tree depth
    localparam int LEVELS = $clog2(N);

    // Connect initial level data and valid signals
    wire [data_size - 1 : 0] level0_data_in [N-1:0];
    wire level0_valid_in [N-1:0];
    assign level0_data_in = data_in;
    assign level0_valid_in = data_in_valid;

    // Tournament tree generator
    genvar level, i, j;
    generate
        // Start from level 1 and create each level's computation
        for (level = 1; level <= LEVELS; level = level + 1) begin : gen_levels
            localparam int NUM_COMPS = N >> level;              // Number of comparisons at this level
            localparam int NUM_INPUTS = 1 << (level - 1);       // Inputs per comparison in this level
            
            // Intermediate signals for this level only
            wire [data_size - 1 : 0] level_data_out [(2 * NUM_INPUTS) - 1:0];
            wire level_valid_out [NUM_COMPS - 1:0];

            // Instantiate compare units at this level
            for (i = 0; i < NUM_COMPS; i = i + 1) begin : gen_comps
                // Define data input arrays for A and B for each comparison
                wire [data_size - 1 : 0] data_A_in [NUM_INPUTS - 1 : 0];
                wire [data_size - 1 : 0] data_B_in [NUM_INPUTS - 1 : 0];
                wire data_A_in_valid, data_B_in_valid;

                // Map data and valid signals from the previous level
                for (j = 0; j < NUM_INPUTS; j++) begin
                    assign data_A_in[j] = gen_levels[level-1].gen_comps[2 * i].level_data_out[j];
                    assign data_B_in[j] = gen_levels[level-1].gen_comps[2 * i + 1].level_data_out[j];
                end

                assign data_A_in_valid = gen_levels[level-1].level_valid_out[2 * i];
                assign data_B_in_valid = gen_levels[level-1].level_valid_out[2 * i + 1];

                // Instantiate the comparison unit for this pair
                gradient_id_compare_unit #(
                    .precision(precision),
                    .mantissa_bit(mantissa_bit),
                    .exponent_bit(exponent_bit),
                    .data_size(data_size),
                    .N(NUM_INPUTS)
                ) compare_inst (
                    .clk(clk),
                    .rst_n(rst_n),
                    .data_A_in_valid(data_A_in_valid),
                    .data_B_in_valid(data_B_in_valid),
                    .data_A_in(data_A_in),
                    .data_B_in(data_B_in),
                    .data_out(level_data_out[i]),     // Single output for this level
                    .data_out_valid(level_valid_out[i]) // Valid signal output
                );
            end

            // Assign the final output at the last level
            if (level == LEVELS) begin
                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        gradient_out_valid <= 1'b0;
                        for (int k = 0; k < N; k = k + 1) begin
                            data_out[k] <= '0;
                        end
                    end else begin
                        gradient_out_valid <= level_valid_out[0];  // Final level valid signal
                        for (int k = 0; k < N; k = k + 1) begin
                            data_out[k] <= level_data_out[0]; // Final computed data
                        end
                    end
                end
            end
        end
    endgenerate
    
endmodule
