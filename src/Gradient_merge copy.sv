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
    input  wire data_in_valid [N-1:0], // Valid signal for each input
    
    // input  wire gradient_ready,
    output reg  gradient_out_valid,

    output reg  [data_size - 1 : 0] data_out [N - 1:0]// Gradient output
);

    // Local parameters for levels
    // localparam int LEVELS = $clog2(N);

    // Signals for intermediate levels
    // logic [data_size - 1 : 0] intermediate_data [LEVELS:0][N-1:0][N-1:0]; // Data stoage for each level [레벨][토너먼트 몇 번째 경기][데이터 크기]
    // logic level_valid [LEVELS:0][LEVELS-1:0]; // Valid signal for each level [레벨][토너먼트 몇 번째 경기]
    
    // genvar l;
    // generate
    //     for (l = 0 ; l < N; l = l + 1) begin
    //         assign level_valid[0][l] = data_in_valid[l]; // Start from initial ready signal

    //         assign intermediate_data[0][l] = data_in[l];  // Initial level data
    //     end
    //     // assign level_valid[0] = data_in_valid; // Start from initial ready signal
    //     // assign intermediate_data[0] = data_in;  // Initial level data
    // endgenerate

    localparam int LEVELS = $clog2(N);
    
    wire [data_size - 1 : 0] intermediate_data [LEVELS-1:0]; // Data stoage for each level

    genvar level, i, j;
    generate
        // Generate tournament levels
        for (level = 1; level <= LEVELS; level = level + 1) begin : gen_levels
            // Number of comparisons per level
            // localparam int NUM_COMPS = N / (2 ** level); 
            localparam NUM_COMPS = N >> level; // N / 2^level 16개 input이어도 8개를 비교하므로 처음부터 level 1 기입.
            localparam NUM_INPUTS = 1 << (level-1); // 16개 Pixel 데이터 input시 첫 단계에서는 1개, 최종 단계에서도 8개가 2번 합쳐져야 하므로 level-1 만큼 shift

            wire [data_size - 1 : 0] intermediate_data [NUM_COMPS - 1 : 0][NUM_INPUTS - 1 : 0]; // Data stoage for each level
            wire level_valid [NUM_INPUTS - 1 : 0]; // Valid signal for each level


            for (i = 0; i < NUM_COMPS; i = i + 1) begin : gen_comps
                // Select inputs for this level's comparison

                wire [data_size - 1 : 0] data_A_in [NUM_INPUTS - 1 : 0];
                wire [data_size - 1 : 0] data_B_in [NUM_INPUTS - 1 : 0];

                wire data_A_in_valid;
                wire data_B_in_valid;
                
                // Assign inputs from intermediate_data
                for (j = 0; j < NUM_INPUTS; j++) begin
                    assign data_A_in[j] = intermediate_data[level-1][2 * i * NUM_INPUTS + j];
                    assign data_B_in[j] = intermediate_data[level-1][(2 * i + 1) * NUM_INPUTS + j];
                end
                
                assign data_A_in_valid = level_valid[level-1][2 * i];
                assign data_B_in_valid = level_valid[level-1][2 * i + 1];

                // Comparison unit instantiation
                gradient_id_compare_unit #(
                    .precision(precision),
                    .mantissa_bit(mantissa_bit),
                    .exponent_bit(exponent_bit),
                    .data_size(data_size),
                    .N((1 << (level-1)))
                )

                compare_inst (
                    .clk(clk),
                    .rst_n(rst_n),

                    .data_A_in_valid(data_A_in_valid),
                    .data_B_in_valid(data_B_in_valid),
                    .data_A_in(data_A_in),   // Array of inputs for data_A_in
                    .data_B_in(data_B_in),   // Array of inputs for data_B_in
                    
                    // .data_out(intermediate_data[level][((2 * i + 1) * NUM_INPUTS) - 1 : 2 * i * NUM_INPUTS]), // Single output for this level
                    .data_out(intermediate_data[level][i]), // Single output for this level

                    .data_out_valid(level_valid[level][i])
                );
            end


        end
    endgenerate

    // Output result from final level
    always_ff @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gradient_out_valid <= 1'b0;
            for (int k = 0; k < N; k = k + 1) begin
                data_out[k] <= 0;
            end
        end 

        else begin

            // if (level_valid[LEVELS]) begin // handshake 조건으로 변경
                gradient_out_valid <= level_valid[LEVELS][0];
            for (int k = 0; k < N; k = k + 1) begin
                data_out[k] <= intermediate_data[LEVELS][k]; // Extract precision data
            end
                
        end 

    end

endmodule
