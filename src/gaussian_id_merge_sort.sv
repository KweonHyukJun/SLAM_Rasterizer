module gaussian_id_merge_sort #(
    parameter precision = 32,
    parameter data_size = 11 * precision + 32,
    parameter num_pixels = 32,
    parameter ID_WIDTH = 32  // Assumes last 32 bits are used as ID for sorting
) 
(
    input wire clk,
    input wire rst_n,
    input wire [data_size-1:0] data_in [num_pixels-1:0],
    input wire data_in_valid [num_pixels-1:0],

    output reg [data_size-1:0] data_out [num_pixels-1:0],
    output reg data_out_valid [num_pixels-1:0]

    //For test
    // ,output reg [ID_WIDTH-1:0] GID_out [num_pixels-1:0]

);

    // Internal parameters for sorting stages
    localparam NUM_STAGES = $clog2(num_pixels);
    
    // Pipeline register declarations
    reg [data_size-1:0] stage_data [NUM_STAGES-1:0][num_pixels-1:0];
    reg stage_valid [NUM_STAGES-1:0][num_pixels-1:0];
    
    // next state
    reg [data_size-1:0] next_stage_data [NUM_STAGES:1][num_pixels-1:0];
    reg next_stage_valid [NUM_STAGES:1][num_pixels-1:0];


    integer k, l;
    
    // Generate merge stages
    genvar stage;
    generate
        for (stage = 1; stage <= NUM_STAGES; stage = stage + 1) begin : merge_stages

            localparam PAIR_SIZE = num_pixels >> stage;
            localparam ELEMENTS_PER_PAIR = 1 << stage;

            // Combinational block for each stage
            always_comb begin
                integer LEFT_IDX, RIGHT_IDX, FIRST_IDX;
                // integer LEFT_LIMIT, RIGHT_LIMIT;
                integer i, j;  // Use regular integers instead of genvar here
                
                for (i = 0; i < PAIR_SIZE; i = i + 1) begin : merge_pairs
                    // Define the base index for each pair
                    FIRST_IDX = i * ELEMENTS_PER_PAIR;
                    
                    // Reset LEFT_IDX and RIGHT_IDX for each new pair
                    LEFT_IDX = FIRST_IDX;
                    RIGHT_IDX = FIRST_IDX + ELEMENTS_PER_PAIR / 2;

                    
                    // LEFT_LIMIT = i * ELEMENTS_PER_PAIR + ELEMENTS_PER_PAIR / 2;
                    // RIGHT_LIMIT = i * ELEMENTS_PER_PAIR + ELEMENTS_PER_PAIR;
                    
                    // Iterate through elements in the pair
                    for (j = 0; j < ELEMENTS_PER_PAIR; j = j + 1) begin : compare_and_swap

                        next_stage_data[stage][FIRST_IDX + j] = 'h0;
                        next_stage_valid[stage][FIRST_IDX + j] = 1'b0;

                        if ((RIGHT_IDX >= FIRST_IDX + ELEMENTS_PER_PAIR) ||

                            ((LEFT_IDX < FIRST_IDX + (ELEMENTS_PER_PAIR / 2)) && 
                            ((stage_data[stage-1][LEFT_IDX][ID_WIDTH-1:0] <= stage_data[stage-1][RIGHT_IDX][ID_WIDTH-1:0] && stage_valid[stage-1][LEFT_IDX]) || (stage_valid[stage-1][LEFT_IDX] && !stage_valid[stage-1][RIGHT_IDX])))
                            ) begin
                            
                            // Assign from LEFT_IDX if it's within bounds or is smaller
                            next_stage_data[stage][FIRST_IDX + j] = stage_data[stage-1][LEFT_IDX];
                            next_stage_valid[stage][FIRST_IDX + j] = stage_valid[stage-1][LEFT_IDX];
                            LEFT_IDX = LEFT_IDX + 1;  // Move to the next element on the left side
                        end 


                        else if (
                            (LEFT_IDX >= FIRST_IDX + (ELEMENTS_PER_PAIR / 2)) || 

                            ((RIGHT_IDX < FIRST_IDX + ELEMENTS_PER_PAIR) && 
                            ((stage_data[stage-1][LEFT_IDX][ID_WIDTH-1:0] > stage_data[stage-1][RIGHT_IDX][ID_WIDTH-1:0] && stage_valid[stage-1][RIGHT_IDX]) || (!stage_valid[stage-1][LEFT_IDX] && stage_valid[stage-1][RIGHT_IDX])))
                            ) begin
                            
                            // Assign from RIGHT_IDX if it's within bounds or is smaller
                            next_stage_data[stage][FIRST_IDX + j] = stage_data[stage - 1][RIGHT_IDX];
                            next_stage_valid[stage][FIRST_IDX + j] = stage_valid[stage -1][RIGHT_IDX];
                            RIGHT_IDX = RIGHT_IDX + 1;  // Move to the next element on the right side
                        end
                        
                    end
                end
            end
        end
    endgenerate



    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < num_pixels; k = k + 1) begin

                for (l = 0; l < NUM_STAGES; l = l + 1) begin
                    stage_data[l][k] <= {data_size{1'b0}};
                    stage_valid[l][k] <= 1'b0;
                end


                data_out[k] <= {data_size{1'b0}};
                data_out_valid[k] <= 1'b0;

                //Test data
                // GID_out[k] <= 0;
            end
        end 
        else begin
            for (k = 0; k < num_pixels; k = k+ 1) begin
                stage_data[0][k] <= data_in[k];
                stage_valid[0][k] <= data_in_valid[k];

                for (l = 1; l < NUM_STAGES; l = l + 1) begin
                    stage_data[l][k] <= next_stage_data[l][k];
                    stage_valid[l][k] <= next_stage_valid[l][k];
                end

                data_out[k] <= next_stage_data[NUM_STAGES][k];
                data_out_valid[k] <= next_stage_valid[NUM_STAGES][k];


                // //Test data
                // GID_out[k] <= next_stage_data[NUM_STAGES][k][ID_WIDTH-1:0];
            end
        end
    end

endmodule
